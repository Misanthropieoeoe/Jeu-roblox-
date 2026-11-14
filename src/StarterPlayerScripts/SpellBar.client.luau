-- SpellBar. Barre des attaques à gauche de l'écran : une case par attaque
-- du Stand équipé (touche, nom, temps de recharge restant). Les cases sont
-- aussi cliquables / tapables (pratique sur mobile).
--
-- Les temps de recharge viennent du serveur (StandFX "MoveStarted" et
-- "MoveDenied"). Le Barrage est un cas spécial : le serveur lance son temps
-- de recharge quand le barrage SE TERMINE, donc la case affiche "ACTIF"
-- pendant le barrage puis démarre le décompte.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local standAction = remotes:WaitForChild("StandAction")
local standFX = remotes:WaitForChild("StandFX")

local player = Players.LocalPlayer

-- Style (repris du HUD des stats) -------------------------------------------
local FONT = Enum.Font.FredokaOne
local BG = Color3.fromRGB(44, 44, 50)
local KEY_BG = Color3.fromRGB(66, 66, 72)
local TEXT = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(190, 190, 200)
local RED = Color3.fromRGB(198, 42, 42)
local RED_DARK = Color3.fromRGB(126, 20, 20)
local GOLD = Color3.fromRGB(255, 200, 80)
local READY = Color3.fromRGB(120, 220, 120)

local SLOT_W, SLOT_H, GAP = 200, 46, 8
------------------------------------------------------------------------------

-- Ordre d'affichage et touches. Les attaques absentes du Stand sont cachées.
local MOVE_ORDER = { "Barrage", "HeavyPunch", "TimeStop", "Heal" }
local KEY_FOR = {
	Barrage = Enum.KeyCode.E,
	HeavyPunch = Enum.KeyCode.R,
	TimeStop = Enum.KeyCode.F,
	Heal = Enum.KeyCode.T,
}

local cooldownEnds = {} -- [actionName] = os.clock() de fin de recharge
local barrageActive = false

-- Interface ------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SpellBar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local column = Instance.new("Frame")
column.Name = "Column"
column.AnchorPoint = Vector2.new(0, 0.5)
column.Position = UDim2.new(0, 12, 0.45, 0)
column.Size = UDim2.fromOffset(SLOT_W, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.BackgroundTransparency = 1
column.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = column

-- Taille réduite sur petit écran (mobile)
local scale = Instance.new("UIScale")
scale.Parent = column
local function updateScale()
	local camera = workspace.CurrentCamera
	local height = camera and camera.ViewportSize.Y or 720
	scale.Scale = math.clamp(height / 720, 0.7, 1)
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function addStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function addTextStroke(label)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = 1.5
	s.Parent = label
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function newLabel(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	addTextStroke(l)
	return l
end

local slots = {} -- [actionName] = slot

-- Crée une case. `action` = nom envoyé au serveur ("Barrage", "LightPunch"…)
local function makeSlot(order, action, keyText, name)
	local button = Instance.new("TextButton")
	button.Name = action
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
	button.BackgroundColor3 = BG
	button.BackgroundTransparency = 0.1
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = true
	button.Parent = column
	corner(button, 8)
	local stroke = addStroke(button, RED_DARK, 2)

	-- Voile de recharge qui se vide de gauche à droite
	local veil = Instance.new("Frame")
	veil.Name = "Cooldown"
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.45
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(0, 1)
	veil.ZIndex = 3
	veil.Parent = button

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 7, 0.5, 0)
	key.Size = UDim2.fromOffset(SLOT_H - 14, SLOT_H - 14)
	key.BackgroundColor3 = KEY_BG
	key.Font = FONT
	key.Text = keyText
	key.TextSize = keyText:len() > 1 and 14 or 18
	key.TextColor3 = TEXT
	key.ZIndex = 2
	key.Parent = button
	corner(key, 6)
	addStroke(key, RED, 1.5)
	addTextStroke(key)

	local title = newLabel(button, name, 16, TEXT)
	title.Position = UDim2.fromOffset(SLOT_H, 4)
	title.Size = UDim2.new(1, -SLOT_H - 8, 0, 22)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 2

	local status = newLabel(button, "PRÊT", 13, READY)
	status.Position = UDim2.fromOffset(SLOT_H, 24)
	status.Size = UDim2.new(1, -SLOT_H - 8, 0, 16)
	status.ZIndex = 2

	local timer = newLabel(button, "", 20, TEXT)
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -10, 0.5, 0)
	timer.Size = UDim2.fromOffset(50, 24)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.ZIndex = 4

	local slot = {
		action = action,
		button = button,
		stroke = stroke,
		veil = veil,
		status = status,
		timer = timer,
		cooldown = 0, -- durée totale de la dernière recharge
	}
	button.Activated:Connect(function()
		standAction:FireServer(action)
	end)
	slots[action] = slot
	return slot
end

local function flash(slot)
	if not slot then return end
	slot.stroke.Color = GOLD
	TweenService:Create(slot.stroke, TweenInfo.new(0.35), { Color = RED_DARK }):Play()
end

local function clearSlots()
	for _, slot in pairs(slots) do
		slot.button:Destroy()
	end
	slots = {}
end

-- Reconstruit la barre pour le Stand équipé
local function rebuild()
	clearSlots()
	local standId = player:GetAttribute("StandId")
	local def = (standId and StandData.GetStand(standId)) or StandData.GetStand(StandData.DefaultStand)
	if player:GetAttribute("Standless") or not def then
		column.Visible = false
		return
	end
	column.Visible = true

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	makeSlot(nextOrder(), "Toggle", "Q", "Invoquer / ranger")
	local light = def.Moves and def.Moves.LightPunchR
	if light then
		makeSlot(nextOrder(), "LightPunch", "M1", light.Label or "Light Punch")
	end
	for _, action in ipairs(MOVE_ORDER) do
		local move = def.Moves and def.Moves[action]
		if move then
			local keyText = move.Key or (KEY_FOR[action] and KEY_FOR[action].Name) or "?"
			local slot = makeSlot(nextOrder(), action, keyText, move.Label or action)
			slot.cooldown = move.Cooldown or 0
		end
	end
end

-- Recharges -------------------------------------------------------------------
local function startCooldown(action, seconds)
	if not seconds or seconds <= 0 then return end
	cooldownEnds[action] = os.clock() + seconds
	local slot = slots[action]
	if slot then
		slot.cooldown = math.max(slot.cooldown, seconds)
	end
end

standFX.OnClientEvent:Connect(function(kind, action, value)
	if typeof(action) ~= "string" then return end
	if kind == "MoveStarted" then
		flash(slots[action])
		if action == "Barrage" then
			-- La recharge démarre à la fin du barrage (voir en haut du fichier)
			barrageActive = true
			cooldownEnds.Barrage = nil
		else
			local slot = slots[action]
			if slot and typeof(value) == "number" then slot.cooldown = value end
			startCooldown(action, value)
		end
	elseif kind == "MoveDenied" and typeof(value) == "number" then
		-- Le serveur donne le temps restant exact : on se recale dessus.
		cooldownEnds[action] = os.clock() + value
	end
end)

-- Suit l'état du Stand : fin du barrage (lance sa recharge) et coups M1.
local function watchStand(stand)
	local lastState = stand:GetAttribute("State")
	stand:GetAttributeChangedSignal("State"):Connect(function()
		local state = stand:GetAttribute("State")
		if barrageActive and lastState == "Barrage" and state ~= "Barrage" then
			barrageActive = false
			local slot = slots.Barrage
			startCooldown("Barrage", slot and slot.cooldown or 15)
		end
		if state == "LightPunchR" or state == "LightPunchL" then
			flash(slots.LightPunch)
		end
		lastState = state
	end)
end

local function onStandAdded(child)
	if child.Name == player.Name .. "Stand" and child:IsA("Model") then
		watchStand(child)
	end
end
workspace.ChildAdded:Connect(onStandAdded)
for _, child in workspace:GetChildren() do
	onStandAdded(child)
end

-- Rafraîchissement de l'affichage
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for action, slot in pairs(slots) do
		local ends = cooldownEnds[action]
		local remaining = ends and (ends - now) or 0
		if action == "Barrage" and barrageActive then
			slot.veil.Size = UDim2.fromScale(0, 1)
			slot.status.Text = "ACTIF"
			slot.status.TextColor3 = GOLD
			slot.timer.Text = ""
		elseif remaining > 0 then
			local total = math.max(slot.cooldown, remaining)
			slot.veil.Size = UDim2.fromScale(remaining / total, 1)
			slot.status.Text = "RECHARGE"
			slot.status.TextColor3 = MUTED
			slot.timer.Text = remaining >= 10 and string.format("%d", math.ceil(remaining))
				or string.format("%.1f", remaining)
		else
			if ends then cooldownEnds[action] = nil end
			slot.veil.Size = UDim2.fromScale(0, 1)
			slot.status.Text = "PRÊT"
			slot.status.TextColor3 = READY
			slot.timer.Text = ""
		end
	end
end)

-- Retour visuel quand on appuie sur une touche
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	for action, keyCode in pairs(KEY_FOR) do
		if input.KeyCode == keyCode and slots[action] then
			local ends = cooldownEnds[action]
			if ends and ends > os.clock() then
				-- encore en recharge : petite secousse rouge
				local slot = slots[action]
				slot.stroke.Color = RED
				TweenService:Create(slot.stroke, TweenInfo.new(0.3), { Color = RED_DARK }):Play()
			end
		end
	end
end)

player:GetAttributeChangedSignal("StandId"):Connect(rebuild)
player:GetAttributeChangedSignal("Standless"):Connect(rebuild)
rebuild()
