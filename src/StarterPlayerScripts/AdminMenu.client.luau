-- AdminMenu. Fenêtre ADMIN (touche L, admins seulement) : donner de l'argent,
-- des objets et des skins à soi-même ou à un autre joueur, et ouvrir le menu
-- pour changer de Stand. Le serveur (Inventory, Remotes.AdminAction)
-- revérifie que le joueur est admin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))
local StandSkins = require(ReplicatedStorage:WaitForChild("StandSkins"))
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local C = UITheme.Colors
local adminAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAction")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("AdminMenu", 8)
local win = UITheme.Window(root, "Admin", "ADMIN", "Donne de l'argent, des objets et des skins · le serveur vérifie que tu es admin",
	C.Purple, Vector2.new(800, 520))

local target = player -- joueur qui reçoit

-- Cible : une pastille par joueur -------------------------------------------------
local targetRow = Instance.new("ScrollingFrame")
targetRow.BackgroundTransparency = 1
targetRow.BorderSizePixel = 0
targetRow.Size = UDim2.new(1, 0, 0, 38)
targetRow.ScrollingDirection = Enum.ScrollingDirection.X
targetRow.AutomaticCanvasSize = Enum.AutomaticSize.X
targetRow.CanvasSize = UDim2.new()
targetRow.ScrollBarThickness = 3
targetRow.Parent = win.body
local targetLayout = Instance.new("UIListLayout")
targetLayout.FillDirection = Enum.FillDirection.Horizontal
targetLayout.Padding = UDim.new(0, 6)
targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetLayout.Parent = targetRow
local targetLabel = UITheme.Label(targetRow, "Pour :", 13, C.Muted, UITheme.Bold)
targetLabel.LayoutOrder = -1
targetLabel.Size = UDim2.fromOffset(44, 32)

local chips = {}
local refreshSkins -- défini plus bas

local function refreshChips()
	for p, chip in pairs(chips) do
		local on = p == target
		chip.stroke.Color = on and C.Purple or C.Line
		chip.stroke.Transparency = on and 0 or 0.23
		chip.button.BackgroundColor3 = on and C.Purple:Lerp(C.Card, 0.6) or C.Card
	end
end

local function addChip(p)
	if chips[p] then return end
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Font = UITheme.Bold
	button.TextSize = 13
	button.TextColor3 = C.Text
	button.Text = (p == player and "Moi · " or "") .. p.DisplayName
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, 32)
	button.LayoutOrder = p == player and 0 or 1
	button.BackgroundColor3 = C.Card
	button.Parent = targetRow
	UITheme.Corner(button, 16)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = button
	local stroke = UITheme.Stroke(button, C.Line, 1.35, 0.23)
	button.Activated:Connect(function()
		target = p
		refreshChips()
		if refreshSkins then refreshSkins() end
		win.status.Text = "Cible : " .. p.Name
		win.status.TextColor3 = C.Muted
	end)
	chips[p] = { button = button, stroke = stroke }
	p:GetAttributeChangedSignal("OwnedSkins"):Connect(function()
		if p == target and refreshSkins then refreshSkins() end
	end)
	refreshChips()
end

Players.PlayerAdded:Connect(addChip)
Players.PlayerRemoving:Connect(function(p)
	if chips[p] then chips[p].button:Destroy() chips[p] = nil end
	if target == p then
		target = player
		refreshChips()
		if refreshSkins then refreshSkins() end
	end
end)
for _, p in Players:GetPlayers() do addChip(p) end

local function send(action, a, b)
	if not target or not target.Parent then
		win.status.Text = "Ce joueur est parti."
		win.status.TextColor3 = C.Red
		return
	end
	win.status.Text = "…"
	win.status.TextColor3 = C.Muted
	adminAction:FireServer(action, target.UserId, a, b)
end

-- Colonne de gauche : argent, objets, Stand --------------------------------------
local LEFT_W = 290
local left = Instance.new("Frame")
left.BackgroundTransparency = 1
left.Position = UDim2.fromOffset(0, 46)
left.Size = UDim2.new(0, LEFT_W, 1, -46)
left.Parent = win.body
local leftLayout = Instance.new("UIListLayout")
leftLayout.Padding = UDim.new(0, 8)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Parent = left

local function section(order, title, height, accent)
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundColor3 = C.Card
	f.Parent = left
	UITheme.Corner(f, 10)
	UITheme.Stroke(f, C.Line, 1.35, 0.23)
	UITheme.Accent(f, accent)
	local t = UITheme.Label(f, title, 13, C.Text, UITheme.Title)
	t.Position = UDim2.fromOffset(14, 6)
	t.Size = UDim2.new(1, -20, 0, 18)
	return f
end

-- Argent
local cashBox = section(1, "💵 ARGENT", 104, C.Green)
local amountBox = Instance.new("TextBox")
amountBox.Position = UDim2.fromOffset(14, 30)
amountBox.Size = UDim2.new(1, -126, 0, 30)
amountBox.BackgroundColor3 = C.Night
amountBox.Font = UITheme.Bold
amountBox.TextSize = 14
amountBox.TextColor3 = C.Text
amountBox.PlaceholderText = "Montant (ex. 5000)"
amountBox.PlaceholderColor3 = C.Muted
amountBox.Text = ""
amountBox.ClearTextOnFocus = false
amountBox.Parent = cashBox
UITheme.Corner(amountBox, 7)
UITheme.Stroke(amountBox, C.Line, 1.35, 0.23)
local giveCash = UITheme.Button(cashBox, "DONNER", "primary", 13)
giveCash.AnchorPoint = Vector2.new(1, 0)
giveCash.Position = UDim2.new(1, -12, 0, 30)
giveCash.Size = UDim2.fromOffset(100, 30)
giveCash.Activated:Connect(function()
	local n = tonumber((amountBox.Text:gsub("[%s$]", "")))
	if not n or n == 0 then
		win.status.Text = "Écris un montant (un nombre négatif retire de l'argent)."
		win.status.TextColor3 = C.Red
		return
	end
	send("GiveCash", n)
end)
local quick = Instance.new("Frame")
quick.BackgroundTransparency = 1
quick.Position = UDim2.fromOffset(14, 68)
quick.Size = UDim2.new(1, -26, 0, 26)
quick.Parent = cashBox
local quickLayout = Instance.new("UIListLayout")
quickLayout.FillDirection = Enum.FillDirection.Horizontal
quickLayout.Padding = UDim.new(0, 6)
quickLayout.Parent = quick
for _, n in { 100, 1000, 10000, 100000 } do
	local b = UITheme.Button(quick, "+" .. (n >= 1000 and (n // 1000) .. "k" or tostring(n)), "ghost", 12)
	b.Size = UDim2.new(0.25, -5, 1, 0)
	b.Activated:Connect(function() send("GiveCash", n) end)
end

-- Objets
local itemBox = section(2, "🎒 OBJETS", 34 + #ItemCatalog.Items * 34, C.Blue)
for i, item in ipairs(ItemCatalog.Items) do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(14, 28 + (i - 1) * 34)
	row.Size = UDim2.new(1, -26, 0, 30)
	row.Parent = itemBox
	local name = UITheme.Label(row, item.Icon .. "  " .. item.Name, 13, C.Text, UITheme.Bold)
	name.Size = UDim2.new(1, -110, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local b1 = UITheme.Button(row, "+1", "ghost", 12)
	b1.AnchorPoint = Vector2.new(1, 0.5)
	b1.Position = UDim2.new(1, -54, 0.5, 0)
	b1.Size = UDim2.fromOffset(48, 26)
	b1.Activated:Connect(function() send("GiveItem", item.Id, 1) end)
	local b5 = UITheme.Button(row, "+5", "ghost", 12)
	b5.AnchorPoint = Vector2.new(1, 0.5)
	b5.Position = UDim2.new(1, 0, 0.5, 0)
	b5.Size = UDim2.fromOffset(48, 26)
	b5.Activated:Connect(function() send("GiveItem", item.Id, 5) end)
end

-- Changer de Stand (fenêtre STANDS)
local standButton = UITheme.Button(left, "⭐  CHANGER DE STAND…", "ghost", 13)
standButton.LayoutOrder = 3
standButton.Size = UDim2.new(1, 0, 0, 36)
standButton.Activated:Connect(function()
	UITheme.Open("Stands")
end)

-- Colonne de droite : skins ------------------------------------------------------
local right = Instance.new("Frame")
right.BackgroundTransparency = 1
right.Position = UDim2.fromOffset(LEFT_W + 12, 46)
right.Size = UDim2.new(1, -(LEFT_W + 12), 1, -46)
right.Parent = win.body

local skinsTitle = UITheme.Label(right, "🎨 SKINS", 13, C.Text, UITheme.Title)
skinsTitle.Size = UDim2.new(1, -220, 0, 30)
local giveAll = UITheme.Button(right, "TOUT DONNER", "primary", 12)
giveAll.AnchorPoint = Vector2.new(1, 0)
giveAll.Position = UDim2.new(1, -108, 0, 0)
giveAll.Size = UDim2.fromOffset(104, 30)
giveAll.Activated:Connect(function() send("GiveAllSkins") end)
local takeAll = UITheme.Button(right, "TOUT RETIRER", "danger", 12)
takeAll.AnchorPoint = Vector2.new(1, 0)
takeAll.Position = UDim2.new(1, 0, 0, 0)
takeAll.Size = UDim2.fromOffset(104, 30)
local confirmUntil = 0
takeAll.Activated:Connect(function()
	-- deux clics pour confirmer
	if os.clock() > confirmUntil then
		confirmUntil = os.clock() + 3
		takeAll.Text = "SÛR ?"
		task.delay(3, function() takeAll.Text = "TOUT RETIRER" end)
		return
	end
	confirmUntil = 0
	takeAll.Text = "TOUT RETIRER"
	send("TakeAllSkins")
end)

local listHolder = Instance.new("Frame")
listHolder.BackgroundTransparency = 1
listHolder.Position = UDim2.fromOffset(0, 38)
listHolder.Size = UDim2.new(1, 0, 1, -38)
listHolder.Parent = right
local list = UITheme.Scroll(listHolder, C.Purple)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local RARITY_COLOR = { Commun = C.Blue, Legendaire = C.Legend, Mythique = C.Purple }
local RARITY_NAME = { Commun = "Commun", Legendaire = "Légendaire", Mythique = "Mythique" }
local rows = {}

local function ownedBy(p)
	local set = {}
	local raw = p:GetAttribute("OwnedSkins")
	if type(raw) == "string" and raw ~= "" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(data) == "table" then
			for _, key in data do set[key] = true end
		end
	end
	return set
end

-- une ligne par skin : mythiques, puis légendaires, puis communs
local order = 0
for _, rarity in { "Mythique", "Legendaire", "Commun" } do
	for _, entry in StandSkins.Pool()[rarity] do
		order += 1
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = C.Card
		row.Parent = list
		UITheme.Corner(row, 8)
		UITheme.Stroke(row, C.Line, 1.35, 0.35)
		UITheme.Accent(row, RARITY_COLOR[rarity])
		local name = UITheme.Label(row, entry.skin.Name, 13, C.Text, UITheme.Bold)
		name.Position = UDim2.fromOffset(12, 2)
		name.Size = UDim2.new(1, -120, 0, 18)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = UITheme.Label(row, StandData.Stands[entry.standId].DisplayName .. "  ·  " .. RARITY_NAME[rarity], 10,
			RARITY_COLOR[rarity], UITheme.Body)
		sub.Position = UDim2.fromOffset(12, 19)
		sub.Size = UDim2.new(1, -120, 0, 14)
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		local give = UITheme.Button(row, "DONNER", "ghost", 11)
		give.AnchorPoint = Vector2.new(1, 0.5)
		give.Position = UDim2.new(1, -8, 0.5, 0)
		give.Size = UDim2.fromOffset(90, 26)
		give.Activated:Connect(function()
			if give.Active then send("GiveSkin", entry.standId, entry.skin.Id) end
		end)
		rows[entry.standId .. "/" .. entry.skin.Id] = give
	end
end

refreshSkins = function()
	local set = ownedBy(target)
	local isTargetAdmin = target:GetAttribute("StandAdmin") == true
	local have, total = 0, 0
	for key, give in pairs(rows) do
		total += 1
		local owned = set[key] == true
		if owned then have += 1 end
		give.Text = owned and "✔ POSSÉDÉ" or "DONNER"
		UITheme.SetEnabled(give, not owned)
	end
	skinsTitle.Text = string.format("🎨 SKINS de %s · %d / %d%s", target.DisplayName, have, total,
		isTargetAdmin and " (admin : tout débloqué)" or "")
end
refreshSkins()

adminAction.OnClientEvent:Connect(function(kind, ok, message)
	if kind ~= "Result" then return end
	win.status.Text = message or ""
	win.status.TextColor3 = ok and C.Green or C.Red
	if ok then UITheme.Toast("🛠 " .. message, C.Purple) end
end)

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Admin" and open then
		win.status.Text = ""
		refreshChips()
		refreshSkins()
	end
end)

player:GetAttributeChangedSignal("StandAdmin"):Connect(function()
	if player:GetAttribute("StandAdmin") ~= true then UITheme.Close("Admin") end
end)
