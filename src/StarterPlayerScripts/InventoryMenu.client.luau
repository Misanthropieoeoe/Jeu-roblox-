-- InventoryMenu. Fenêtre INVENTAIRE (touche J) : les flèches et fruits du
-- joueur. Ils sont gardés à la mort et sauvegardés (serveur : Inventory).
-- "Prendre en main" donne l'objet au personnage (clic pour l'utiliser),
-- "Ranger" le remet dans l'inventaire.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))
local C = UITheme.Colors
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryAction = remotes:WaitForChild("InventoryAction")
local standAction = remotes:WaitForChild("StandAction")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("InventoryMenu", 8)
local win = UITheme.Window(root, "Inventaire", "INVENTAIRE", "Tes objets restent avec toi, même après la mort", C.Green,
	Vector2.new(700, 470))

local list = UITheme.Scroll(win.body, C.Green)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local empty = UITheme.Label(win.body, "Ton inventaire est vide.\nRamasse des flèches et des fruits sur la carte, ou achète-les à la BOUTIQUE.",
	16, C.Muted, UITheme.Body)
empty.Size = UDim2.fromScale(1, 1)
empty.TextXAlignment = Enum.TextXAlignment.Center
empty.TextWrapped = true
empty.Visible = false

local function storedCounts()
	local raw = player:GetAttribute("Inventory")
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and type(data) == "table") and data or {}
end

local function heldCount(itemId)
	local n = 0
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child.Name == itemId then n += 1 end
			end
		end
	end
	return n
end

-- Une ligne par objet du catalogue
local rows = {}
for _, item in ipairs(ItemCatalog.Items) do
	local row = Instance.new("Frame")
	row.Name = item.Id
	row.LayoutOrder = item.Order
	row.Size = UDim2.new(1, 0, 0, 92)
	row.BackgroundColor3 = C.Card
	row.Parent = list
	UITheme.Corner(row, 12)
	UITheme.Stroke(row, item.Rare and C.Legend or C.Line, item.Rare and 2 or 1.5)

	local icon = UITheme.Label(row, item.Icon, 34, C.Text, UITheme.Body)
	icon.Position = UDim2.fromOffset(12, 12)
	icon.Size = UDim2.fromOffset(68, 68)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.BackgroundColor3 = item.Color
	icon.BackgroundTransparency = 0.6
	UITheme.Corner(icon, 12)
	UITheme.Stroke(icon, item.Color, 2)

	local count = UITheme.Label(icon, "x0", 15, C.Text, UITheme.Bold)
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.new(1, 4, 1, 4)
	count.Size = UDim2.fromOffset(38, 22)
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.BackgroundColor3 = C.Night
	UITheme.Corner(count, 11)

	local name = UITheme.Label(row, item.Name, 24, C.Text, UITheme.Title)
	name.Position = UDim2.fromOffset(94, 10)
	name.Size = UDim2.new(1, -260, 0, 28)

	local desc = UITheme.Label(row, item.Description, 13, C.Muted, UITheme.Body)
	desc.Position = UDim2.fromOffset(94, 40)
	desc.Size = UDim2.new(1, -260, 0, 34)
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top

	local held = UITheme.Label(row, "", 12, C.Green, UITheme.Bold)
	held.Position = UDim2.fromOffset(94, 72)
	held.Size = UDim2.new(1, -260, 0, 14)

	local take = UITheme.Button(row, "PRENDRE EN MAIN", "primary", 13)
	take.AnchorPoint = Vector2.new(1, 0)
	take.Position = UDim2.new(1, -12, 0, 14)
	take.Size = UDim2.fromOffset(150, 32)
	local store = UITheme.Button(row, "RANGER", "ghost", 13)
	store.AnchorPoint = Vector2.new(1, 0)
	store.Position = UDim2.new(1, -12, 0, 50)
	store.Size = UDim2.fromOffset(150, 28)

	take.Activated:Connect(function()
		if not take.Active then return end
		win.status.Text = "…"
		inventoryAction:FireServer("Take", item.Id)
	end)
	store.Activated:Connect(function()
		if not store.Active then return end
		inventoryAction:FireServer("Store", item.Id)
	end)
	rows[item.Id] = { row = row, count = count, held = held, take = take, store = store }
end

local function refresh()
	local counts = storedCounts()
	local any = false
	for id, r in pairs(rows) do
		local inBag = counts[id] or 0
		local inHand = heldCount(id)
		local total = inBag + inHand
		r.row.Visible = total > 0
		any = any or total > 0
		r.count.Text = "x" .. tostring(total)
		r.held.Text = inHand > 0 and ("✋ " .. inHand .. " en main") or ""
		UITheme.SetEnabled(r.take, inBag > 0 or inHand > 0)
		UITheme.SetEnabled(r.store, inHand > 0)
	end
	empty.Visible = not any
end

-- Mises à jour
player:GetAttributeChangedSignal("Inventory"):Connect(refresh)
local function watchContainer(container)
	if not container then return end
	container.ChildAdded:Connect(function() task.defer(refresh) end)
	container.ChildRemoved:Connect(function() task.defer(refresh) end)
end
watchContainer(player:FindFirstChild("Backpack"))
watchContainer(player.Character)
player.CharacterAdded:Connect(function(character)
	watchContainer(character)
	watchContainer(player:WaitForChild("Backpack"))
	refresh()
end)
refresh()

inventoryAction.OnClientEvent:Connect(function(kind, ok, message, action)
	if kind ~= "Result" then return end
	if action == "Take" or action == "Store" then
		win.status.Text = message or ""
		win.status.TextColor3 = ok and C.Green or C.Red
		if ok and action == "Take" then
			UITheme.Close("Inventaire")
			UITheme.Toast(message, C.Green)
		end
	end
end)

-- Objet ramassé sur la carte
local PICK_NAME = { Arrow = "StandArrow", RequiemArrow = "RequiemArrow", Rokakaka = "Rokakaka" }
standAction.OnClientEvent:Connect(function(actionName, kind)
	if actionName == "ItemPicked" then
		local item = ItemCatalog.ById[PICK_NAME[kind] or kind]
		if item then
			UITheme.Toast(item.Icon .. "  " .. item.Name .. " rangé dans ton inventaire (J)", item.Color)
		end
	end
end)

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Inventaire" and open then
		win.status.Text = ""
		refresh()
	end
end)
