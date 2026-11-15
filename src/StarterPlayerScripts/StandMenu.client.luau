-- StandMenu. Fenêtre STANDS (touche L, admins seulement) pour prendre
-- n'importe quel Stand. Le bouton n'apparaît que si le serveur a mis
-- l'attribut "StandAdmin" sur le joueur (voir StandService, STAND_ADMIN_IDS /
-- STAND_ADMIN_NAMES). Le serveur revérifie à chaque choix.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local C = UITheme.Colors
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("StandMenu", 8)
local win = UITheme.Window(root, "Stands", "CHOISIS TON STAND", "Menu admin · le Stand change tout de suite", C.Purple,
	Vector2.new(760, 500))

local standIds = {}
for id in pairs(StandData.Stands) do
	table.insert(standIds, id)
end
table.sort(standIds, function(a, b)
	return StandData.Stands[a].DisplayName < StandData.Stands[b].DisplayName
end)

local grid = UITheme.Scroll(win.body, C.Purple)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(170, 104)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent = grid

local GRADE_COLOR = {
	A = C.Gold, B = C.Green, C = Color3.fromRGB(120, 180, 255), D = C.Muted, E = C.Muted,
}

local cards = {}
local pending = false

local function refreshCards()
	local current = player:GetAttribute("StandId")
	for id, card in pairs(cards) do
		local equipped = id == current
		card.stroke.Color = equipped and C.Gold or C.Line
		card.stroke.Thickness = equipped and 3 or 1.5
		card.badge.Visible = equipped
	end
end

local function choose(id)
	if pending then return end
	if id == player:GetAttribute("StandId") then
		win.status.Text = StandData.Stands[id].DisplayName .. " est déjà équipé."
		win.status.TextColor3 = C.Muted
		return
	end
	pending = true
	win.status.Text = "Invocation de " .. StandData.Stands[id].DisplayName .. "…"
	win.status.TextColor3 = C.Muted
	standAction:FireServer("ChooseStand", id)
	task.delay(3, function()
		if pending then
			pending = false
			win.status.Text = "Pas de réponse du serveur, réessaie."
			win.status.TextColor3 = C.Red
		end
	end)
end

for order, id in ipairs(standIds) do
	local def = StandData.Stands[id]
	local theme = def.Theme or {}
	local card, stroke = UITheme.Card(grid)
	card.Name = id
	card.LayoutOrder = order
	UITheme.Gradient(card, (theme.Aura1 or C.Gold):Lerp(Color3.new(1, 1, 1), 0.55), Color3.fromRGB(170, 160, 190), 90)

	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = theme.Aura1 or C.Gold
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(10, 10)
	stripe.Size = UDim2.fromOffset(5, 40)
	stripe.Parent = card
	UITheme.Corner(stripe, 3)

	local name = UITheme.Label(card, def.DisplayName, 15, C.Text, UITheme.Title)
	name.Position = UDim2.fromOffset(22, 6)
	name.Size = UDim2.new(1, -30, 0, 48)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top

	local grades = StandData.StatGrades and StandData.StatGrades[id]
	if grades then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 10, 1, -32)
		row.Size = UDim2.new(1, -20, 0, 22)
		row.Parent = card
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, 4)
		rowLayout.Parent = row
		for i, pair in ipairs({ { "PUI", grades.Power }, { "DUR", grades.Durability }, { "VIT", grades.Speed } }) do
			local grade = tostring(pair[2] or "?")
			local chip = UITheme.Label(row, pair[1] .. " " .. grade, 11, GRADE_COLOR[grade:sub(1, 1)] or C.Text, UITheme.Bold)
			chip.LayoutOrder = i
			chip.Size = UDim2.new(1 / 3, -3, 1, 0)
			chip.TextXAlignment = Enum.TextXAlignment.Center
			chip.BackgroundColor3 = C.Night
			chip.BackgroundTransparency = 0.25
			UITheme.Corner(chip, 6)
		end
	end

	local badge = UITheme.Label(card, "ÉQUIPÉ", 11, C.Night, UITheme.Bold)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -8, 0, 8)
	badge.Size = UDim2.fromOffset(58, 18)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.BackgroundColor3 = C.Gold
	badge.BackgroundTransparency = 0
	badge.Visible = false
	UITheme.Corner(badge, 9)

	card.Activated:Connect(function()
		choose(id)
	end)
	cards[id] = { stroke = stroke, badge = badge }
end

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Stands" and open then
		win.status.Text = ""
		refreshCards()
	end
end)

player:GetAttributeChangedSignal("StandId"):Connect(function()
	refreshCards()
	if pending then
		pending = false
		local id = player:GetAttribute("StandId")
		local def = id and StandData.Stands[id]
		win.status.Text = def and (def.DisplayName .. " équipé !") or ""
		win.status.TextColor3 = C.Green
		task.delay(0.6, function()
			if not pending then UITheme.Close("Stands") end
		end)
	end
end)

-- Fermé pour les non-admins (le bouton du HUD est aussi caché)
player:GetAttributeChangedSignal("StandAdmin"):Connect(function()
	if player:GetAttribute("StandAdmin") ~= true then UITheme.Close("Stands") end
end)
