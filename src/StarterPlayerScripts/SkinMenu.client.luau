-- SkinMenu. Bouton "SKINS" à l'écran (pour tout le monde) qui ouvre l'onglet
-- des skins : à gauche la liste des Stands, à droite les skins du Stand
-- sélectionné. Le choix est envoyé au serveur (StandAction "ChooseSkin"),
-- qui le sauvegarde et réinvoque le Stand s'il est sorti.
-- Les skins sont définis dans ReplicatedStorage/StandSkins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandSkins = require(ReplicatedStorage:WaitForChild("StandSkins"))
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

local player = Players.LocalPlayer

-- Style (le même que le menu des Stands) -----------------------------------
local FONT = Enum.Font.FredokaOne
local BG = Color3.fromRGB(44, 44, 50)
local CARD = Color3.fromRGB(62, 62, 70)
local CARD_HOVER = Color3.fromRGB(78, 78, 88)
local TEXT = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(190, 190, 200)
local RED = Color3.fromRGB(198, 42, 42)
local RED_DARK = Color3.fromRGB(126, 20, 20)
local GOLD = Color3.fromRGB(255, 200, 80)
-----------------------------------------------------------------------------

-- Une seule copie de l'interface (si le script est en double dans Studio)
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SkinMenu")
if old then old:Destroy() end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function textStroke(lbl)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = 1.5
	s.Parent = lbl
end

local function label(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.Parent = parent
	textStroke(l)
	return l
end

local function hover(button, base)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = CARD_HOVER }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
end

-- Stands triés par nom affiché
local standIds = {}
for id in pairs(StandData.Stands) do
	table.insert(standIds, id)
end
table.sort(standIds, function(a, b)
	return StandData.Stands[a].DisplayName < StandData.Stands[b].DisplayName
end)

local function equippedSkins()
	local raw = player:GetAttribute("StandSkins")
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and type(data) == "table") and data or {}
end

local function equippedSkin(standId)
	return equippedSkins()[standId] or StandSkins.DEFAULT
end

-- Interface ------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SkinMenu"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Bouton d'ouverture : sous le bouton STANDS (admins), sinon à sa place
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Size = UDim2.fromOffset(110, 40)
openButton.BackgroundColor3 = BG
openButton.Font = FONT
openButton.Text = "SKINS"
openButton.TextSize = 20
openButton.TextColor3 = TEXT
openButton.Parent = gui
corner(openButton, 8)
stroke(openButton, GOLD, 2)
textStroke(openButton)

local function placeOpenButton()
	local admin = player:GetAttribute("StandAdmin") == true
	openButton.Position = UDim2.fromOffset(12, admin and 112 or 64)
end
player:GetAttributeChangedSignal("StandAdmin"):Connect(placeOpenButton)
placeOpenButton()

-- Fenêtre
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.94, 0, 0.82, 0)
panel.BackgroundColor3 = BG
panel.Visible = false
panel.Parent = gui
corner(panel, 12)
stroke(panel, GOLD, 3)
local panelSize = Instance.new("UISizeConstraint")
panelSize.MaxSize = Vector2.new(720, 480)
panelSize.Parent = panel

local title = label(panel, "SKINS", 26, TEXT)
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -70, 0, 34)
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = RED
closeButton.Font = FONT
closeButton.Text = "X"
closeButton.TextSize = 20
closeButton.TextColor3 = TEXT
closeButton.Parent = panel
corner(closeButton, 8)
stroke(closeButton, RED_DARK, 2)

local status = label(panel, "", 16, MUTED)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 16, 1, -8)
status.Size = UDim2.new(1, -32, 0, 22)
status.TextXAlignment = Enum.TextXAlignment.Left

-- Colonne des Stands (onglets)
local TABS_WIDTH = 170
local tabs = Instance.new("ScrollingFrame")
tabs.Name = "Stands"
tabs.Position = UDim2.fromOffset(12, 54)
tabs.Size = UDim2.new(0, TABS_WIDTH, 1, -90)
tabs.BackgroundTransparency = 1
tabs.BorderSizePixel = 0
tabs.ScrollBarThickness = 4
tabs.ScrollBarImageColor3 = GOLD
tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabs.CanvasSize = UDim2.new()
tabs.Parent = panel
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 6)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabs
local tabsPadding = Instance.new("UIPadding")
tabsPadding.PaddingRight = UDim.new(0, 8)
tabsPadding.PaddingTop = UDim.new(0, 2)
tabsPadding.Parent = tabs

-- Grille des skins
local grid = Instance.new("ScrollingFrame")
grid.Name = "Skins"
grid.Position = UDim2.fromOffset(12 + TABS_WIDTH + 10, 54)
grid.Size = UDim2.new(1, -(12 + TABS_WIDTH + 10 + 12), 1, -90)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.ScrollBarImageColor3 = GOLD
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = panel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(150, 112)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 2)
gridPadding.PaddingLeft = UDim.new(0, 2)
gridPadding.Parent = grid

-- Onglets -------------------------------------------------------------------
local selected = nil
local tabButtons = {} -- [standId] = { button, stroke, sub }
local skinCards = {} -- [skinId] = { stroke, badge }
local pending = nil -- { standId, skinId }

local function skinName(standId, skinId)
	return StandSkins.Get(standId, skinId).Name
end

local function refreshTabs()
	local mine = player:GetAttribute("StandId")
	for id, tab in pairs(tabButtons) do
		local active = id == selected
		tab.stroke.Color = active and GOLD or RED_DARK
		tab.stroke.Thickness = active and 3 or 2
		tab.sub.Text = (id == mine and "Ton Stand · " or "") .. skinName(id, equippedSkin(id))
	end
end

local function refreshCards()
	if not selected then return end
	local current = equippedSkin(selected)
	for skinId, card in pairs(skinCards) do
		local on = skinId == current
		card.stroke.Color = on and GOLD or RED_DARK
		card.stroke.Thickness = on and 3 or 2
		card.badge.Visible = on
	end
end

-- Couleurs d'aperçu : les couleurs du Stand passées dans le skin
local function previewColors(standId, skin)
	local theme = StandData.Stands[standId].Theme or {}
	local colors = {}
	for _, role in { "Primary", "Secondary", "Trim", "Body" } do
		local c = theme[role]
		if c then table.insert(colors, StandSkins.Transform(skin, c)) end
	end
	table.insert(colors, skin.Aura or theme.Aura1 or GOLD)
	return colors
end

local function choose(standId, skinId)
	if pending then return end
	if equippedSkin(standId) == skinId then
		status.Text = skinName(standId, skinId) .. " est déjà équipé."
		return
	end
	pending = { standId, skinId }
	status.Text = "Application du skin " .. skinName(standId, skinId) .. "…"
	standAction:FireServer("ChooseSkin", standId, skinId)
	task.delay(3, function()
		if pending and pending[1] == standId and pending[2] == skinId then
			pending = nil
			status.Text = "Pas de réponse du serveur, réessaie."
		end
	end)
end

local function showStand(standId)
	selected = standId
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(skinCards)
	for order, skin in ipairs(StandSkins.List(standId)) do
		local button = Instance.new("TextButton")
		button.Name = skin.Id
		button.LayoutOrder = order
		button.BackgroundColor3 = CARD
		button.AutoButtonColor = false
		button.Text = ""
		button.Parent = grid
		corner(button, 10)
		local cardStroke = stroke(button, RED_DARK, 2)

		-- bandes de couleur
		local swatches = Instance.new("Frame")
		swatches.BackgroundTransparency = 1
		swatches.Position = UDim2.fromOffset(10, 10)
		swatches.Size = UDim2.new(1, -20, 0, 46)
		swatches.Parent = button
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
			corner(sw, 6)
		end

		local name = label(button, skin.Name, 17, TEXT)
		name.Position = UDim2.fromOffset(10, 62)
		name.Size = UDim2.new(1, -20, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local badge = label(button, "ÉQUIPÉ", 13, GOLD)
		badge.Position = UDim2.fromOffset(10, 86)
		badge.Size = UDim2.new(1, -20, 0, 16)
		badge.TextXAlignment = Enum.TextXAlignment.Left
		badge.Visible = false

		hover(button, CARD)
		button.Activated:Connect(function()
			choose(standId, skin.Id)
		end)
		skinCards[skin.Id] = { stroke = cardStroke, badge = badge }
	end
	grid.CanvasPosition = Vector2.zero
	refreshTabs()
	refreshCards()
end

for order, id in ipairs(standIds) do
	local def = StandData.Stands[id]
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 50)
	button.BackgroundColor3 = CARD
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = tabs
	corner(button, 8)
	local tabStroke = stroke(button, RED_DARK, 2)

	local name = label(button, def.DisplayName, 15, TEXT)
	name.Position = UDim2.fromOffset(8, 5)
	name.Size = UDim2.new(1, -16, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = label(button, "", 12, MUTED)
	sub.Position = UDim2.fromOffset(8, 27)
	sub.Size = UDim2.new(1, -16, 0, 16)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	hover(button, CARD)
	button.Activated:Connect(function()
		showStand(id)
	end)
	tabButtons[id] = { button = button, stroke = tabStroke, sub = sub }
end

-- Ouverture / fermeture --------------------------------------------------------
local function setOpen(open)
	panel.Visible = open
	if open then
		status.Text = ""
		local mine = player:GetAttribute("StandId")
		showStand((mine and StandData.Stands[mine]) and mine or selected or standIds[1])
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

player:GetAttributeChangedSignal("StandSkins"):Connect(function()
	refreshTabs()
	refreshCards()
	if pending and equippedSkin(pending[1]) == pending[2] then
		status.Text = "Skin " .. skinName(pending[1], pending[2]) .. " équipé !"
		pending = nil
	end
end)
player:GetAttributeChangedSignal("StandId"):Connect(refreshTabs)
