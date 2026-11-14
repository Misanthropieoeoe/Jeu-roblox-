-- StandMenu. Bouton "STANDS" à l'écran qui ouvre un menu pour choisir
-- n'importe quel Stand. Réservé aux admins : le bouton n'apparaît que si le
-- serveur a mis l'attribut "StandAdmin" sur le joueur (voir StandService,
-- STAND_ADMIN_IDS / STAND_ADMIN_NAMES). Le serveur revérifie à chaque choix.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

local player = Players.LocalPlayer

-- Style (repris du HUD des stats) ------------------------------------------
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

local function textStroke(label)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = 1.5
	s.Parent = label
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

-- Liste des Stands triée par nom affiché
local standIds = {}
for id in pairs(StandData.Stands) do
	table.insert(standIds, id)
end
table.sort(standIds, function(a, b)
	return StandData.Stands[a].DisplayName < StandData.Stands[b].DisplayName
end)

-- Interface -----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "StandMenu"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Bouton d'ouverture, en haut à gauche sous les boutons Roblox
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.AnchorPoint = Vector2.new(0, 0)
openButton.Position = UDim2.new(0, 12, 0, 64)
openButton.Size = UDim2.fromOffset(110, 40)
openButton.BackgroundColor3 = BG
openButton.AutoButtonColor = true
openButton.Font = FONT
openButton.Text = "STANDS"
openButton.TextSize = 20
openButton.TextColor3 = TEXT
openButton.Parent = gui
corner(openButton, 8)
stroke(openButton, RED, 2)
textStroke(openButton)

-- Fenêtre
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.8, 0)
panel.BackgroundColor3 = BG
panel.Visible = false
panel.Parent = gui
corner(panel, 12)
stroke(panel, RED, 3)
local panelSize = Instance.new("UISizeConstraint")
panelSize.MaxSize = Vector2.new(620, 460)
panelSize.Parent = panel

local title = label(panel, "CHOISIS TON STAND", 26, TEXT)
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

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Position = UDim2.fromOffset(12, 54)
list.Size = UDim2.new(1, -24, 1, -90)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = RED
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(180, 92)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = list
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.Parent = list

-- Cartes ---------------------------------------------------------------------
local cards = {} -- [standId] = { button, stroke, badge }

local function statsText(id)
	local g = StandData.StatGrades and StandData.StatGrades[id]
	if not g then return "" end
	return string.format("PUI %s   DUR %s   VIT %s", g.Power, g.Durability, g.Speed)
end

local function refreshCards()
	local current = player:GetAttribute("StandId")
	for id, card in pairs(cards) do
		local equipped = id == current
		card.stroke.Color = equipped and GOLD or RED_DARK
		card.stroke.Thickness = equipped and 3 or 2
		card.badge.Visible = equipped
	end
end

local pending = false

local function choose(id)
	if pending then return end
	if id == player:GetAttribute("StandId") then
		status.Text = StandData.Stands[id].DisplayName .. " est déjà équipé."
		return
	end
	pending = true
	status.Text = "Invocation de " .. StandData.Stands[id].DisplayName .. "…"
	standAction:FireServer("ChooseStand", id)
	-- Le serveur met à jour l'attribut StandId ; on ferme dès que c'est fait.
	task.delay(3, function()
		if pending then
			pending = false
			status.Text = "Pas de réponse du serveur, réessaie."
		end
	end)
end

for order, id in ipairs(standIds) do
	local def = StandData.Stands[id]
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.BackgroundColor3 = CARD
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = list
	corner(button, 10)
	local cardStroke = stroke(button, RED_DARK, 2)

	local name = label(button, def.DisplayName, 18, TEXT)
	name.Position = UDim2.fromOffset(10, 8)
	name.Size = UDim2.new(1, -20, 0, 44)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextXAlignment = Enum.TextXAlignment.Left

	local stats = label(button, statsText(id), 13, MUTED)
	stats.AnchorPoint = Vector2.new(0, 1)
	stats.Position = UDim2.new(0, 10, 1, -8)
	stats.Size = UDim2.new(1, -20, 0, 18)
	stats.TextXAlignment = Enum.TextXAlignment.Left

	local badge = label(button, "ÉQUIPÉ", 12, GOLD)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -8, 0, 6)
	badge.Size = UDim2.fromOffset(60, 16)
	badge.TextXAlignment = Enum.TextXAlignment.Right
	badge.Visible = false

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = CARD_HOVER }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = CARD }):Play()
	end)
	button.Activated:Connect(function()
		choose(id)
	end)

	cards[id] = { button = button, stroke = cardStroke, badge = badge }
end

-- Ouverture / fermeture ------------------------------------------------------
local function setOpen(open)
	panel.Visible = open
	if open then
		status.Text = ""
		refreshCards()
	end
end

openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

player:GetAttributeChangedSignal("StandId"):Connect(function()
	refreshCards()
	if pending then
		pending = false
		local id = player:GetAttribute("StandId")
		local def = id and StandData.Stands[id]
		status.Text = def and (def.DisplayName .. " équipé !") or ""
		task.delay(0.6, function()
			if not pending then setOpen(false) end
		end)
	end
end)

-- Visible seulement pour les admins
local function refreshAccess()
	local allowed = player:GetAttribute("StandAdmin") == true
	gui.Enabled = allowed
	if not allowed then setOpen(false) end
end
player:GetAttributeChangedSignal("StandAdmin"):Connect(refreshAccess)
refreshAccess()
