-- SpellBar. Barre des attaques à droite de l'écran : une case par attaque
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
local StandMovement = require(ReplicatedStorage:WaitForChild("StandMovement"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local standAction = remotes:WaitForChild("StandAction")
local standFX = remotes:WaitForChild("StandFX")

local player = Players.LocalPlayer

-- Style (UITheme, commun à toutes les interfaces) ---------------------------
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = UITheme.Colors
local FONT_TITLE = UITheme.Title
local FONT_BOLD = UITheme.Bold
local BG = C.Night
local CARD = C.Panel
local TEXT = C.Text
local MUTED = C.Muted
local RED = C.Red
local LINE = C.Line
local GOLD = C.Gold
local READY = C.Green

local SLOT_W, SLOT_H, GAP = 214, 44, 6
------------------------------------------------------------------------------

-- Ordre d'affichage des touches. Chaque attaque du Stand équipé est placée
-- selon son champ Key (StandData / StandSpells).
local KEY_ORDER = { "E", "R", "T", "F", "G" }
local KEY_FOR = {} -- [actionName] = Enum.KeyCode, rempli par rebuild()

local cooldownEnds = {} -- [actionName] = os.clock() de fin de recharge
local barrageActive = false

-- Interface ------------------------------------------------------------------
-- Anti-doublon : si une ancienne copie de ce script traîne dans le jeu, on
-- l'arrête et on supprime sa barre (sinon deux barres se superposent et
-- chaque clic lance l'attaque deux fois). Les copies à jour ont l'attribut
-- SpellBarVersion ; on garde la plus récente.
local SPELLBAR_VERSION = 3
local playerGui = player:WaitForChild("PlayerGui")

local function isOutdated(other)
	return (other:GetAttribute("SpellBarVersion") or 0) < SPELLBAR_VERSION
end

for _, other in ipairs(script.Parent:GetChildren()) do
	if other ~= script and other.Name == script.Name and other:IsA("LocalScript") then
		if isOutdated(other) then
			other:Destroy() -- arrête l'ancienne copie
		else
			script:Destroy() -- une copie aussi récente tourne déjà
			return
		end
	end
end
script:SetAttribute("SpellBarVersion", SPELLBAR_VERSION)

local function removeOldBar(child)
	if child:IsA("ScreenGui") and child.Name == "SpellBar" and isOutdated(child) then
		child:Destroy()
	end
end
for _, child in ipairs(playerGui:GetChildren()) do
	removeOldBar(child)
end
playerGui.ChildAdded:Connect(function(child)
	task.defer(removeOldBar, child)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SpellBar"
gui:SetAttribute("SpellBarVersion", SPELLBAR_VERSION)
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local column = Instance.new("Frame")
column.Name = "Column"
column.AnchorPoint = Vector2.new(1, 0.5)
column.Position = UDim2.new(1, -12, 0.6, 0)
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

local slots = {} -- [actionName] = slot

-- Couleur d'accent de la case selon la touche
local KEY_ACCENT = {
	Q = C.Muted, M1 = C.Text, E = C.Gold, R = C.Magenta, T = Color3.fromRGB(110, 170, 255),
	F = C.Legend, G = C.Red, Z = C.Green, X = Color3.fromRGB(150, 200, 255),
}

-- Crée une case. `action` = nom envoyé au serveur ("Barrage", "LightPunch"…)
local function makeSlot(order, action, keyText, name)
	local accent = KEY_ACCENT[keyText] or GOLD
	local button = Instance.new("TextButton")
	button.Name = action
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
	button.BackgroundColor3 = CARD
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = true
	button.Parent = column
	UITheme.Corner(button, 10)
	local stroke = UITheme.Stroke(button, LINE, 1.5)
	UITheme.Gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 175), 0)

	-- liseré coloré à gauche
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = accent
	edge.BorderSizePixel = 0
	edge.Size = UDim2.new(0, 4, 1, 0)
	edge.ZIndex = 2
	edge.Parent = button

	-- Voile de recharge qui se vide de gauche à droite
	local veil = Instance.new("Frame")
	veil.Name = "Cooldown"
	veil.BackgroundColor3 = BG
	veil.BackgroundTransparency = 0.3
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(0, 1)
	veil.ZIndex = 3
	veil.Parent = button

	-- barre de progression fine en bas
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 2)
	bar.ZIndex = 5
	bar.Parent = button

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 10, 0.5, 0)
	key.Size = UDim2.fromOffset(30, 30)
	key.BackgroundColor3 = BG
	key.Font = FONT_BOLD
	key.Text = keyText
	key.TextSize = keyText:len() > 1 and 12 or 16
	key.TextColor3 = accent
	key.ZIndex = 4
	key.Parent = button
	UITheme.Corner(key, 8)
	UITheme.Stroke(key, accent, 1.5)

	local title = UITheme.Label(button, name, 18, TEXT, FONT_TITLE)
	title.Position = UDim2.fromOffset(48, 3)
	title.Size = UDim2.new(1, -100, 0, 22)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 4

	local status = UITheme.Label(button, "PRÊT", 10, READY, FONT_BOLD)
	status.Position = UDim2.fromOffset(49, 25)
	status.Size = UDim2.new(1, -100, 0, 14)
	status.ZIndex = 4

	local timer = UITheme.Label(button, "", 20, TEXT, FONT_TITLE)
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -10, 0.5, 0)
	timer.Size = UDim2.fromOffset(50, 26)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.ZIndex = 5

	local slot = {
		action = action,
		button = button,
		stroke = stroke,
		veil = veil,
		bar = bar,
		accent = accent,
		status = status,
		timer = timer,
		cooldown = 0, -- durée totale de la dernière recharge
	}
	button.Activated:Connect(function()
		-- Déplacement : géré par StandMovement.client.luau
		if action == "Mobility" and _G.StandMobility then
			_G.StandMobility()
			return
		end
		-- StandController ajoute le point visé pour les projectiles
		local fire = _G.StandFireAction
		if fire then
			fire(action)
		else
			standAction:FireServer(action)
		end
	end)
	slots[action] = slot
	return slot
end

local function flash(slot)
	if not slot then return end
	slot.stroke.Color = slot.accent
	slot.stroke.Thickness = 3
	TweenService:Create(slot.stroke, TweenInfo.new(0.35), { Color = LINE, Thickness = 1.5 }):Play()
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
	table.clear(KEY_FOR)
	for _, key in ipairs(KEY_ORDER) do
		for action, move in pairs(def.Moves or {}) do
			if move.Key == key and action ~= "LightPunchR" and action ~= "LightPunchL" then
				local slot = makeSlot(nextOrder(), action, key, move.Label or action)
				slot.cooldown = move.Cooldown or 0
				KEY_FOR[action] = Enum.KeyCode[key]
			end
		end
	end
	-- Déplacement du Stand (touche Z, StandMovement.client.luau)
	local movement = StandMovement.Get(standId or StandData.DefaultStand)
	if movement.Type then
		local slot = makeSlot(nextOrder(), "Mobility", "Z", movement.Label or "Déplacement")
		slot.cooldown = movement.Cooldown or 0
		slot.maxCharges = movement.Charges or 1
	end
	-- Parade (touche X, Guard.client.luau) : la case montre la jauge de garde
	makeSlot(nextOrder(), "Block", "X", "Parade")
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
local function setVeil(slot, fraction)
	slot.veil.Size = UDim2.fromScale(fraction, 1)
	slot.bar.Size = UDim2.new(1 - fraction, 0, 0, 2)
end

local GUARD_MAX = 60 -- même valeur que GUARD_MAX dans StandService

local function renderGuard(slot)
	local guard = player:GetAttribute("Guard") or GUARD_MAX
	local missing = math.clamp(1 - guard / GUARD_MAX, 0, 1)
	setVeil(slot, missing)
	slot.timer.Text = string.format("%d%%", math.floor(guard / GUARD_MAX * 100 + 0.5))
	if player:GetAttribute("Blocking") then
		slot.status.Text = "EN GARDE"
		slot.status.TextColor3 = GOLD
	elseif player:GetAttribute("GuardLocked") then
		-- en train de prendre un combo M1 (garde possible après le 3e coup)
		slot.status.Text = "COMBO SUBI"
		slot.status.TextColor3 = RED
	elseif guard < GUARD_MAX * 0.15 then
		slot.status.Text = "BRISÉE"
		slot.status.TextColor3 = RED
	else
		slot.status.Text = "MAINTENIR X"
		slot.status.TextColor3 = READY
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for action, slot in pairs(slots) do
		if action == "Block" then
			renderGuard(slot)
			continue
		end
		local ends = cooldownEnds[action]
		local remaining = ends and (ends - now) or 0
		if action == "Barrage" and barrageActive then
			setVeil(slot, 0)
			slot.status.Text = "ACTIF"
			slot.status.TextColor3 = GOLD
			slot.timer.Text = ""
		elseif remaining > 0 then
			local total = math.max(slot.cooldown, remaining)
			setVeil(slot, remaining / total)
			slot.status.Text = "RECHARGE"
			slot.status.TextColor3 = MUTED
			slot.timer.Text = remaining >= 10 and string.format("%d", math.ceil(remaining))
				or string.format("%.1f", remaining)
		else
			if ends then cooldownEnds[action] = nil end
			setVeil(slot, 0)
			slot.timer.Text = ""
			if action == "Mobility" and (slot.maxCharges or 1) > 1 then
				-- charges restantes (ex. x2 pour Silver Chariot)
				local charges = player:GetAttribute("MobilityCharges") or slot.maxCharges
				slot.timer.Text = "x" .. tostring(charges)
			end
			if player:GetAttribute("Hitstun") and action ~= "Toggle" then
				-- vient de prendre un coup : impossible d'attaquer un instant
				slot.status.Text = "ÉTOURDI"
				slot.status.TextColor3 = RED
			else
				slot.status.Text = "PRÊT"
				slot.status.TextColor3 = READY
			end
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
				TweenService:Create(slot.stroke, TweenInfo.new(0.3), { Color = LINE }):Play()
			end
		end
	end
end)

player:GetAttributeChangedSignal("StandId"):Connect(rebuild)
player:GetAttributeChangedSignal("Standless"):Connect(rebuild)
rebuild()
