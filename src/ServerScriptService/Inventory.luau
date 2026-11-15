-- Inventory. L'inventaire des joueurs (flèches, fruits) et la boutique.
--
-- Les objets sont rangés dans l'inventaire (des compteurs, sauvegardés) et
-- ne sont plus perdus à la mort. Pour utiliser un objet, le joueur le "prend
-- en main" depuis l'onglet INVENTAIRE : il devient un outil (Tool) dans sa
-- main, comme avant. À la mort, en quittant ou avec "Ranger", les outils en
-- main retournent dans l'inventaire.
--
-- L'argent (leaderstats.Cash) est aussi sauvegardé ici.
--
-- Utilisé par StandService (ramassage et outils), TradeService (échanges)
-- et MoneyService (argent). Côté client : InventoryMenu et ShopMenu, via le
-- RemoteEvent Remotes.InventoryAction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))

local Inventory = {}

local SAVE_INTERVAL = 120
local ACTION_COOLDOWN = 0.35

local stored = {}   -- [userId] = { [itemId] = n }
local loaded = {}   -- [userId] = true quand les données sont chargées
local lastAction = {}
local toolBuilder = nil -- function(itemId) -> Tool, donné par StandService

-- Remote ---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local remote = remotes:FindFirstChild("InventoryAction") or Instance.new("RemoteEvent")
remote.Name = "InventoryAction"
remote.Parent = remotes

-- Sauvegarde -----------------------------------------------------------------
local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerInventory_v1")
	end)
	if ok then
		store = result
	else
		warn("[Inventory] DataStore indisponible :", result)
	end
end

local function cashValue(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function publish(player)
	local items = stored[player.UserId] or {}
	player:SetAttribute("Inventory", HttpService:JSONEncode(items))
end

local function isItem(id)
	return type(id) == "string" and ItemCatalog.ById[id] ~= nil
end

-- Outils en main ----------------------------------------------------------------
local function heldTools(player, itemId)
	local list = {}
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and isItem(child.Name) and (not itemId or child.Name == itemId)
					and not child:GetAttribute("Consuming") then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

-- Range dans l'inventaire tous les objets en main (mort, départ, "Ranger")
function Inventory.StoreHeld(player, itemId)
	local items = stored[player.UserId]
	if not items then return 0 end
	local n = 0
	for _, tool in heldTools(player, itemId) do
		items[tool.Name] = (items[tool.Name] or 0) + 1
		tool:Destroy()
		n += 1
	end
	if n > 0 then publish(player) end
	return n
end

local function save(player)
	if not store or not loaded[player.UserId] then return end
	local cash = cashValue(player)
	local data = {
		Items = stored[player.UserId] or {},
		Cash = cash and cash.Value or 0,
	}
	-- les objets en main comptent aussi (ils reviennent dans l'inventaire au retour)
	local items = table.clone(data.Items)
	for _, tool in heldTools(player) do
		items[tool.Name] = (items[tool.Name] or 0) + 1
	end
	data.Items = items
	local ok, err = pcall(function()
		store:SetAsync("Inv_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Inventory] Échec de la sauvegarde pour", player.Name, err)
	end
end
Inventory.Save = save

local function load(player)
	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("Inv_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[Inventory] Échec du chargement pour", player.Name, result)
		end
	end
	local items = {}
	if type(data) == "table" and type(data.Items) == "table" then
		for id, n in pairs(data.Items) do
			if isItem(id) and type(n) == "number" and n > 0 then
				items[id] = math.floor(n)
			end
		end
	end
	stored[player.UserId] = items
	-- objets déjà ramassés pendant le chargement
	Inventory.StoreHeld(player)
	publish(player)
	if type(data) == "table" and type(data.Cash) == "number" then
		task.spawn(function()
			local stats = player:WaitForChild("leaderstats", 15)
			local cash = stats and stats:WaitForChild("Cash", 15)
			if cash then cash.Value += math.max(0, math.floor(data.Cash)) end
		end)
	end
	loaded[player.UserId] = true
end

-- API --------------------------------------------------------------------------
function Inventory.SetToolBuilder(fn)
	toolBuilder = fn
end

-- Nombre total d'un objet (inventaire + en main)
function Inventory.Count(player, itemId)
	local items = stored[player.UserId] or {}
	return (items[itemId] or 0) + #heldTools(player, itemId)
end

function Inventory.Counts(player)
	local counts = {}
	for _, item in ItemCatalog.Items do
		local n = Inventory.Count(player, item.Id)
		if n > 0 then counts[item.Id] = n end
	end
	return counts
end

function Inventory.Add(player, itemId, n)
	if not isItem(itemId) then return false end
	local items = stored[player.UserId]
	if not items then
		items = {}
		stored[player.UserId] = items
	end
	items[itemId] = (items[itemId] or 0) + (n or 1)
	publish(player)
	return true
end

-- Retire n objets (d'abord dans l'inventaire, puis en main). false si pas assez.
function Inventory.Remove(player, itemId, n)
	n = n or 1
	if Inventory.Count(player, itemId) < n then return false end
	local items = stored[player.UserId] or {}
	local fromStore = math.min(items[itemId] or 0, n)
	items[itemId] = (items[itemId] or 0) - fromStore
	if items[itemId] <= 0 then items[itemId] = nil end
	local rest = n - fromStore
	for _, tool in heldTools(player, itemId) do
		if rest <= 0 then break end
		tool:Destroy()
		rest -= 1
	end
	publish(player)
	return true
end

-- Prendre un objet en main
local function take(player, itemId)
	if player:GetAttribute("Trading") then
		return false, "Impossible pendant un échange."
	end
	local items = stored[player.UserId]
	if not items or (items[itemId] or 0) <= 0 then
		return false, "Tu n'as plus cet objet."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Attends de réapparaître."
	end
	if #heldTools(player, itemId) > 0 then
		-- déjà en main : on l'équipe simplement
		local tool = heldTools(player, itemId)[1]
		humanoid:EquipTool(tool)
		return true, ItemCatalog.ById[itemId].Name .. " en main."
	end
	if not toolBuilder then
		return false, "Objet indisponible pour l'instant."
	end
	local tool = toolBuilder(itemId)
	if not tool then
		return false, "Objet indisponible pour l'instant."
	end
	items[itemId] -= 1
	if items[itemId] <= 0 then items[itemId] = nil end
	-- range d'abord les autres objets en main pour n'en tenir qu'un
	Inventory.StoreHeld(player)
	tool.Parent = player:FindFirstChild("Backpack") or character
	humanoid:EquipTool(tool)
	publish(player)
	return true, ItemCatalog.ById[itemId].Name .. " en main. Clique pour l'utiliser."
end

local function buy(player, itemId, qty)
	local item = ItemCatalog.ById[itemId]
	if not item or not item.Price then return false, "Objet inconnu." end
	qty = math.clamp(math.floor(tonumber(qty) or 1), 1, ItemCatalog.MaxBuy)
	local cash = cashValue(player)
	local total = item.Price * qty
	if not cash or cash.Value < total then
		return false, "Pas assez d'argent."
	end
	cash.Value -= total
	Inventory.Add(player, itemId, qty)
	task.spawn(save, player)
	print("[Inventory]", player.Name, "a acheté", qty, "x", itemId, "pour", total)
	return true, string.format("%d × %s ajouté à ton inventaire.", qty, item.Name)
end

remote.OnServerEvent:Connect(function(player, action, itemId, qty)
	local now = os.clock()
	if (lastAction[player.UserId] or 0) + ACTION_COOLDOWN > now then return end
	lastAction[player.UserId] = now
	if not loaded[player.UserId] then
		remote:FireClient(player, "Result", false, "Chargement de l'inventaire…")
		return
	end
	local ok, message = false, nil
	if action == "Take" and isItem(itemId) then
		ok, message = take(player, itemId)
	elseif action == "Store" then
		local n = Inventory.StoreHeld(player, isItem(itemId) and itemId or nil)
		ok, message = n > 0, n > 0 and "Rangé dans l'inventaire." or "Rien à ranger."
	elseif action == "Buy" and isItem(itemId) then
		ok, message = buy(player, itemId, qty)
	else
		return
	end
	remote:FireClient(player, "Result", ok, message, action, itemId)
end)

-- Joueurs ------------------------------------------------------------------------
local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			Inventory.StoreHeld(player)
		end)
	end
end

local function onPlayer(player)
	task.spawn(load, player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		Inventory.StoreHeld(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	stored[player.UserId] = nil
	loaded[player.UserId] = nil
	lastAction[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
	end
end)

return Inventory
