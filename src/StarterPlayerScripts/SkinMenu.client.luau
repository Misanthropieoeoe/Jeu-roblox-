-- SkinMenu. Fenêtre SKINS (touche K) : à gauche la liste des Stands, à
-- droite les skins du Stand sélectionné. Le choix est envoyé au serveur
-- (StandAction "ChooseSkin"), qui le sauvegarde et réinvoque le Stand s'il
-- est sorti. Les skins sont définis dans ReplicatedStorage/StandSkins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandSkins = require(ReplicatedStorage:WaitForChild("StandSkins"))
local C = UITheme.Colors
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("SkinMenu", 8)
local win = UITheme.Window(root, "Skins", "SKINS", "Change l'apparence de tes Stands · les légendaires changent leur modèle",
	C.Magenta, Vector2.new(780, 500))

-- Stands triés par nom
local standIds = {}
for id in pairs(StandData.Stands) do
	table.insert(standIds, id)
end
table.sort(standIds, function(a, b)
	return StandData.Stands[a].DisplayName < StandData.Stands[b].DisplayName
end)

local function equippedSkin(standId)
	local raw = player:GetAttribute("StandSkins")
	local data = {}
	if type(raw) == "string" and raw ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then data = decoded end
	end
	return data[standId] or StandSkins.DEFAULT
end

-- Colonne des Stands
local TABS_W = 190
local tabsHolder = Instance.new("Frame")
tabsHolder.BackgroundTransparency = 1
tabsHolder.Size = UDim2.new(0, TABS_W, 1, 0)
tabsHolder.Parent = win.body
local tabs = UITheme.Scroll(tabsHolder, C.Magenta)
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabs

-- Grille des skins
local gridHolder = Instance.new("Frame")
gridHolder.BackgroundTransparency = 1
gridHolder.Position = UDim2.fromOffset(TABS_W + 10, 0)
gridHolder.Size = UDim2.new(1, -(TABS_W + 10), 1, 0)
gridHolder.Parent = win.body
local grid = UITheme.Scroll(gridHolder, C.Magenta)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(170, 128)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local selected
local tabButtons = {}
local skinCards = {}
local pending

local function skinName(standId, skinId)
	return StandSkins.Get(standId, skinId).Name
end

local function refreshTabs()
	local mine = player:GetAttribute("StandId")
	for id, tab in pairs(tabButtons) do
		local active = id == selected
		tab.stroke.Color = active and C.Magenta or (tab.legend and C.Legend or C.Line)
		tab.stroke.Thickness = active and 2.5 or (tab.legend and 2 or 1.5)
		if tab.legend then continue end
		tab.mine.Visible = id == mine
		tab.sub.Text = skinName(id, equippedSkin(id))
	end
end

local LEGEND_TAB = "_Legendaires"

local function refreshCards()
	for _, card in pairs(skinCards) do
		local on = card.skinId == equippedSkin(card.standId)
		card.stroke.Color = on and C.Gold or (card.legendary and C.Legend or C.Line)
		card.stroke.Thickness = on and 3 or (card.legendary and 2 or 1.5)
		card.badge.Visible = on
	end
end

local function previewColors(standId, skin)
	if skin.Preview then
		local colors = table.clone(skin.Preview)
		table.insert(colors, skin.Aura or C.Gold)
		return colors
	end
	local theme = StandData.Stands[standId].Theme or {}
	local colors = {}
	for _, role in { "Primary", "Secondary", "Trim", "Body" } do
		if theme[role] then table.insert(colors, StandSkins.Transform(skin, theme[role])) end
	end
	table.insert(colors, skin.Aura or theme.Aura1 or C.Gold)
	return colors
end

local function choose(standId, skinId)
	if pending then return end
	if equippedSkin(standId) == skinId then
		win.status.Text = skinName(standId, skinId) .. " est déjà équipé."
		win.status.TextColor3 = C.Muted
		return
	end
	pending = { standId, skinId }
	win.status.Text = "Application du skin " .. skinName(standId, skinId) .. "…"
	win.status.TextColor3 = C.Muted
	standAction:FireServer("ChooseSkin", standId, skinId)
	task.delay(3, function()
		if pending and pending[1] == standId and pending[2] == skinId then
			pending = nil
			win.status.Text = "Pas de réponse du serveur, réessaie."
			win.status.TextColor3 = C.Red
		end
	end)
end

-- Remplit la grille. entries = { { standId, skin } }, withStand = afficher
-- le nom du Stand sur la carte (onglet Légendaires)
local function fill(entries, withStand)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(skinCards)
	for order, entry in ipairs(entries) do
		local standId, skin = entry.standId, entry.skin
		local legendary = skin.Rarity == "Legendaire"
		local card, stroke = UITheme.Card(grid)
		card.Name = standId .. "_" .. skin.Id
		card.LayoutOrder = order
		if legendary then
			UITheme.Gradient(card, Color3.fromRGB(255, 210, 140), Color3.fromRGB(150, 140, 170), 90)
		end

		local swatches = Instance.new("Frame")
		swatches.BackgroundTransparency = 1
		swatches.Position = UDim2.fromOffset(10, 10)
		swatches.Size = UDim2.new(1, -20, 0, withStand and 40 or 52)
		swatches.Parent = card
		local swLayout = Instance.new("UIListLayout")
		swLayout.FillDirection = Enum.FillDirection.Horizontal
		swLayout.Padding = UDim.new(0, 4)
		swLayout.Parent = swatches
		local colors = previewColors(standId, skin)
		for i, color in ipairs(colors) do
			local sw = Instance.new("Frame")
			sw.LayoutOrder = i
			sw.BackgroundColor3 = color
			sw.BorderSizePixel = 0
			sw.Size = UDim2.new(1 / #colors, -4, 1, 0)
			sw.Parent = swatches
			UITheme.Corner(sw, 6)
		end

		local nameY = withStand and 54 or 68
		local name = UITheme.Label(card, skin.Name, 15, legendary and C.Legend or C.Text, UITheme.Title)
		name.Position = UDim2.fromOffset(10, nameY)
		name.Size = UDim2.new(1, -20, 0, 26)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		if withStand then
			local standLabel = UITheme.Label(card, StandData.Stands[standId].DisplayName, 12, C.Text, UITheme.Bold)
			standLabel.Position = UDim2.fromOffset(10, 80)
			standLabel.Size = UDim2.new(1, -20, 0, 16)
			standLabel.TextTruncate = Enum.TextTruncate.AtEnd
		end

		local badge = UITheme.Label(card, "✔ ÉQUIPÉ", 12, C.Gold, UITheme.Bold)
		badge.Position = UDim2.fromOffset(10, 102)
		badge.Size = UDim2.fromOffset(80, 16)
		badge.Visible = false

		if legendary then
			local tag = UITheme.Label(card, "LÉGENDAIRE", 11, C.Night, UITheme.Bold)
			tag.AnchorPoint = Vector2.new(1, 0)
			tag.Position = UDim2.new(1, -8, 0, 100)
			tag.Size = UDim2.fromOffset(82, 20)
			tag.TextXAlignment = Enum.TextXAlignment.Center
			tag.BackgroundColor3 = C.Legend
			tag.BackgroundTransparency = 0
			UITheme.Corner(tag, 10)
		end

		card.Activated:Connect(function()
			choose(standId, skin.Id)
		end)
		skinCards[card.Name] = { stroke = stroke, badge = badge, legendary = legendary, standId = standId, skinId = skin.Id }
	end
	grid.CanvasPosition = Vector2.zero
	refreshTabs()
	refreshCards()
end

local function showStand(standId)
	selected = standId
	if standId == LEGEND_TAB then
		fill(StandSkins.Legendaries(), true)
		return
	end
	local entries = {}
	for _, skin in ipairs(StandSkins.List(standId)) do
		table.insert(entries, { standId = standId, skin = skin })
	end
	fill(entries, false)
end

-- Onglet de tous les skins légendaires, tout en haut
do
	local button, stroke = UITheme.Card(tabs)
	button.Name = LEGEND_TAB
	button.LayoutOrder = 0
	button.Size = UDim2.new(1, 0, 0, 50)
	UITheme.Gradient(button, Color3.fromRGB(255, 205, 120), Color3.fromRGB(170, 130, 90), 90)
	local name = UITheme.Label(button, "★ LÉGENDAIRES", 15, C.Legend, UITheme.Title)
	name.Position = UDim2.fromOffset(10, 4)
	name.Size = UDim2.new(1, -20, 0, 24)
	local sub = UITheme.Label(button, "Changent le modèle du Stand", 11, C.Text, UITheme.Body)
	sub.Position = UDim2.fromOffset(10, 28)
	sub.Size = UDim2.new(1, -20, 0, 16)
	button.Activated:Connect(function()
		showStand(LEGEND_TAB)
	end)
	tabButtons[LEGEND_TAB] = { stroke = stroke, legend = true }
end

for order, id in ipairs(standIds) do
	local def = StandData.Stands[id]
	local button, stroke = UITheme.Card(tabs)
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 50)

	local name = UITheme.Label(button, def.DisplayName, 14, C.Text, UITheme.Bold)
	name.Position = UDim2.fromOffset(10, 6)
	name.Size = UDim2.new(1, -20, 0, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = UITheme.Label(button, "", 12, C.Muted, UITheme.Body)
	sub.Position = UDim2.fromOffset(10, 26)
	sub.Size = UDim2.new(1, -60, 0, 16)
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	local mine = UITheme.Label(button, "TOI", 10, C.Night, UITheme.Bold)
	mine.AnchorPoint = Vector2.new(1, 0)
	mine.Position = UDim2.new(1, -8, 0, 26)
	mine.Size = UDim2.fromOffset(34, 16)
	mine.TextXAlignment = Enum.TextXAlignment.Center
	mine.BackgroundColor3 = C.Magenta
	mine.BackgroundTransparency = 0
	mine.Visible = false
	UITheme.Corner(mine, 8)

	button.Activated:Connect(function()
		showStand(id)
	end)
	tabButtons[id] = { stroke = stroke, sub = sub, mine = mine }
end

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Skins" and open then
		win.status.Text = ""
		local mine = player:GetAttribute("StandId")
		local ok, err = pcall(showStand, (mine and StandData.Stands[mine]) and mine or selected or standIds[1])
		if not ok then
			warn("[SkinMenu] Erreur à l'ouverture :", err)
			win.status.Text = "Erreur d'affichage des skins (voir Output)."
			win.status.TextColor3 = C.Red
		end
	end
end)

player:GetAttributeChangedSignal("StandSkins"):Connect(function()
	refreshTabs()
	refreshCards()
	if pending and equippedSkin(pending[1]) == pending[2] then
		win.status.Text = "Skin " .. skinName(pending[1], pending[2]) .. " équipé !"
		win.status.TextColor3 = C.Green
		pending = nil
	end
end)
player:GetAttributeChangedSignal("StandId"):Connect(refreshTabs)
