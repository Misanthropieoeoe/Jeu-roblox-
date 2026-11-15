-- LEMONADE_UI_SCALE_CONVERTER (managed by Lemonade, do not edit or remove)
-- Pixel (Offset) values in Lemonade UIs are authored for a 1920x1080 screen.
-- This multiplies every pixel value under the ScreenGuis this script sees by
-- the fit of that reference inside the current viewport, so phones and
-- tablets show the desktop layout scaled down instead of desktop-sized pixels.
-- Scale fractions already follow the screen and stay as they are.
local lemonadeUiScale_REFERENCE = Vector2.new(1920, 1080)
local lemonadeUiScale_ATTRIBUTE_PREFIX = "LemonadeUiScale_"
-- Roblox sizes its own PlayerGui ScreenGuis (touch controls, prompts, chat,
-- freecam) for the device already.
local lemonadeUiScale_ROBLOX_SCREEN_GUIS = {
	TouchGui = true,
	ProximityPrompts = true,
	Chat = true,
	BubbleChat = true,
	Freecam = true,
}
local lemonadeUiScale_PIXEL_PROPERTIES = {
	GuiObject = { "Size", "Position" },
	TextLabel = { "TextSize" },
	TextButton = { "TextSize" },
	TextBox = { "TextSize" },
	ImageLabel = { "TileSize" },
	ImageButton = { "TileSize" },
	ScrollingFrame = { "CanvasSize", "ScrollBarThickness" },
	UIStroke = { "Thickness" },
	UICorner = { "CornerRadius" },
	UIPadding = { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" },
	UIListLayout = { "Padding" },
	UIPageLayout = { "Padding" },
	UITableLayout = { "Padding" },
	UIGridLayout = { "CellSize", "CellPadding" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
}

local function lemonadeUiScale_factor(viewport: Vector2): number
	return math.min(viewport.X / lemonadeUiScale_REFERENCE.X, viewport.Y / lemonadeUiScale_REFERENCE.Y)
end

local function lemonadeUiScale_scaleValue(value: any, factor: number): any
	local kind = typeof(value)
	if kind == "UDim" then
		return UDim.new(value.Scale, math.round(value.Offset * factor))
	end
	if kind == "UDim2" then
		return UDim2.new(
			value.X.Scale,
			math.round(value.X.Offset * factor),
			value.Y.Scale,
			math.round(value.Y.Offset * factor)
		)
	end
	return value * factor
end

-- The authored value is kept as an attribute so repeat passes, clones and
-- viewport changes always scale from it and never compound or drift.
local function lemonadeUiScale_apply(instance: Instance, factor: number)
	local target = instance :: any
	for className, properties in lemonadeUiScale_PIXEL_PROPERTIES do
		if not instance:IsA(className) then
			continue
		end
		for _, property in properties do
			local attribute = lemonadeUiScale_ATTRIBUTE_PREFIX .. property
			local authored = instance:GetAttribute(attribute)
			if authored == nil then
				authored = target[property]
				if lemonadeUiScale_scaleValue(authored, 2) == authored then
					continue
				end
				instance:SetAttribute(attribute, authored)
			end
			target[property] = lemonadeUiScale_scaleValue(authored, factor)
		end
	end
end

local function lemonadeUiScale_hasOwnScale(screenGui: ScreenGui): boolean
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("UIScale") and not descendant.Parent:IsA("GuiButton") then
			return true
		end
	end
	return false
end

local function lemonadeUiScale_shouldScale(screenGui: ScreenGui): boolean
	return not lemonadeUiScale_ROBLOX_SCREEN_GUIS[screenGui.Name] and not lemonadeUiScale_hasOwnScale(screenGui)
end

local function lemonadeUiScale_convert(screenGui: ScreenGui, factor: number)
	-- A UIScale is the tree's own responsiveness; scaling pixels as well
	-- would shrink it twice.
	if not lemonadeUiScale_shouldScale(screenGui) then
		return
	end
	for _, descendant in screenGui:GetDescendants() do
		lemonadeUiScale_apply(descendant, factor)
	end
end

local lemonadeUiScale_RunService = game:GetService("RunService")
if lemonadeUiScale_RunService:IsRunning() and lemonadeUiScale_RunService:IsClient() then
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local managed: { [ScreenGui]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function currentFactor(): number
		return lemonadeUiScale_factor(camera.ViewportSize)
	end
	playerGui.ChildAdded:Connect(function(child)
		if not child:IsA("ScreenGui") then
			return
		end
		task.defer(function()
			lemonadeUiScale_RunService.RenderStepped:Wait()
			if not lemonadeUiScale_shouldScale(child) then
				return
			end
			managed[child] = true
			lemonadeUiScale_convert(child, currentFactor())
			-- Deferred so properties the builder sets right after parenting are
			-- read as authored.
			child.DescendantAdded:Connect(function(descendant)
				task.defer(function()
					if descendant:IsDescendantOf(child) then
						lemonadeUiScale_apply(descendant, currentFactor())
					end
				end)
			end)
		end)
	end)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local factor = currentFactor()
		for screenGui in managed do
			lemonadeUiScale_convert(screenGui, factor)
		end
	end)
end
-- END LEMONADE_UI_SCALE_CONVERTER

-- layout: hud-zone-system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")

local PURPLE = Color3.fromRGB(170, 120, 255)
local GOLD = Color3.fromRGB(255, 200, 80)
local ORANGE = Color3.fromRGB(255, 150, 60)
local RED = Color3.fromRGB(255, 80, 70)
local HEAL_GREEN = Color3.fromRGB(110, 255, 170)

local STARS_ID = "rbxassetid://92521981645530"
local FIST_ID = "rbxassetid://134595823778256"

-- Hit styles per move: number scale (world), spark count, shake power.
local HIT_STYLES = {
	light = { scale = 0.55, color = GOLD, sparks = 3, shake = 0.15, billboard = Vector2.new(72, 36) },
	barrage = { scale = 0.85, color = GOLD, sparks = 6, shake = 0.35, billboard = Vector2.new(96, 48) },
	heavy = { scale = 1.7, color = ORANGE, sparks = 26, shake = 1.1, billboard = Vector2.new(170, 88) },
	final = { scale = 2.1, color = RED, sparks = 34, shake = 1.5, billboard = Vector2.new(200, 100) },
}

-- ============ WORLD FX: damage numbers + spark bursts ============

local function sparkBurst(position, count)
	local holder = Instance.new("Part")
	holder.Name = "HitSparks"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.new(1, 1, 1), PURPLE)
	burst.LightEmission = 1
	burst.Speed = NumberRange.new(7, 15)
	burst.Lifetime = NumberRange.new(0.15, 0.4)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rotation = NumberRange.new(0, 360)
	burst.RotSpeed = NumberRange.new(-200, 200)
	burst.Size = NumberSequence.new(0.45, 0)
	burst.Transparency = NumberSequence.new(0, 1)
	burst.Enabled = false
	burst.Parent = holder
	burst:Emit(count)

	task.delay(0.7, function()
		holder:Destroy()
	end)
end

local function damageNumber(position, amount, style)
	local holder = Instance.new("Part")
	holder.Name = "DamageNumber"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	local jitter = Vector3.new((math.random() - 0.5) * 2.4, 0.6 + math.random() * 1.4, (math.random() - 0.5) * 2.4)
	holder.CFrame = CFrame.new(position + jitter)
	holder.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Number"
	billboard.Size = UDim2.fromOffset(style.billboard.X, style.billboard.Y)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.StudsOffset = Vector3.new(0, 0.6, 0)
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = style.color
	label.TextScaled = true
	label.ZIndex = 2
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 3.5
	stroke.Parent = label

	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = billboard

	TweenService:Create(pop, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = style.scale }):Play()
	TweenService:Create(billboard, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 3.6, 0) }):Play()
	task.delay(0.55, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
		end
	end)
	task.delay(0.9, function()
		holder:Destroy()
	end)
end

-- Green floating "+N HP" that drifts up over the healed target (GER Life Channel).
local function healNumber(position, amount)
	local holder = Instance.new("Part")
	holder.Name = "HealNumber"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	local jitter = Vector3.new((math.random() - 0.5) * 2, 1.2 + math.random() * 0.8, (math.random() - 0.5) * 2)
	holder.CFrame = CFrame.new(position + jitter)
	holder.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealNumber"
	billboard.Size = UDim2.fromOffset(120, 56)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.StudsOffset = Vector3.new(0, 0.8, 0)
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "+" .. tostring(math.floor(amount + 0.5)) .. " HP"
	label.TextColor3 = HEAL_GREEN
	label.TextScaled = true
	label.ZIndex = 2
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 3.5
	stroke.Parent = label

	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = billboard

	TweenService:Create(pop, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4.2, 0) }):Play()
	task.delay(0.7, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
		end
	end)
	task.delay(1.15, function()
		holder:Destroy()
	end)
end

-- ============ REQUIEM AWAKENING (gold burst on requiem evolution) ============

local function requiemAwaken(position)
	sparkBurst(position, 40)

	local holder = Instance.new("Part")
	holder.Name = "RequiemAwaken"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	-- Flaring golden light
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = 0
	light.Range = 28
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 8 }):Play()
	task.delay(0.9, function()
		if light.Parent then
			TweenService:Create(light, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
		end
	end)

	-- Pillar of gold light swallowing the character
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = GOLD
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Size = Vector3.new(26, 2, 2)
	pillar.CFrame = holder.CFrame * CFrame.Angles(0, 0, math.rad(90))
	pillar.Transparency = 0.35
	pillar.Parent = holder
	TweenService:Create(pillar, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(26, 6.5, 6.5),
		Transparency = 1,
	}):Play()

	-- Shockwave ring racing outward along the ground
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = holder.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = holder
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, 22, 22),
		Transparency = 1,
	}):Play()

	-- Golden motes streaming upward out of the body
	local column = Instance.new("ParticleEmitter")
	column.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	column.LightEmission = 1
	column.Speed = NumberRange.new(12, 20)
	column.Lifetime = NumberRange.new(0.8, 1.4)
	column.SpreadAngle = Vector2.new(18, 18)
	column.Rotation = NumberRange.new(0, 360)
	column.RotSpeed = NumberRange.new(-140, 140)
	column.Size = NumberSequence.new(0.55, 0)
	column.Transparency = NumberSequence.new(0, 1)
	column.Rate = 110
	column.Parent = holder
	task.delay(1.2, function()
		column.Enabled = false
	end)

	-- Radial gold burst at the plunge instant
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
	burst.LightEmission = 1
	burst.Speed = NumberRange.new(18, 30)
	burst.Lifetime = NumberRange.new(0.25, 0.55)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rotation = NumberRange.new(0, 360)
	burst.RotSpeed = NumberRange.new(-200, 200)
	burst.Size = NumberSequence.new(0.7, 0)
	burst.Transparency = NumberSequence.new(0, 1)
	burst.Enabled = false
	burst.Parent = holder
	burst:Emit(70)

	task.delay(3, function()
		holder:Destroy()
	end)
end

-- ============ CAMERA SHAKE ============

local shakePower = 0

RunService.RenderStepped:Connect(function(dt)
	if shakePower <= 0.002 then return end
	local rot = CFrame.Angles(
		(math.random() - 0.5) * shakePower * 0.05,
		(math.random() - 0.5) * shakePower * 0.05,
		(math.random() - 0.5) * shakePower * 0.03
	)
	local shift = (math.random() - 0.5) * shakePower * 0.3
	camera.CFrame = camera.CFrame * rot * CFrame.new(shift, shift, 0)
	shakePower *= math.exp(-dt * 9)
end)

-- ============ COMBO COUNTER HUD (top-right zone) ============

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local topRightZone = Instance.new("Frame")
topRightZone.Name = "TopRightZone"
topRightZone.BackgroundTransparency = 1
topRightZone.AnchorPoint = Vector2.new(1, 0)
topRightZone.Position = UDim2.new(0.975, 0, 0.02, 0)
topRightZone.Size = UDim2.new(0.22, 0, 1, 0)
topRightZone.Parent = screenGui

local zoneLayout = Instance.new("UIListLayout")
zoneLayout.FillDirection = Enum.FillDirection.Vertical
zoneLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
zoneLayout.SortOrder = Enum.SortOrder.LayoutOrder
zoneLayout.Padding = UDim.new(0.015, 0)
zoneLayout.Parent = topRightZone

-- Combo chip: bevel base + gradient face + studs pattern (theme construction).
local chip = Instance.new("Frame")
chip.Name = "ComboChip"
chip.BackgroundColor3 = Color3.fromRGB(48, 26, 80)
chip.BorderSizePixel = 0
chip.AnchorPoint = Vector2.new(1, 0)
chip.Position = UDim2.new(1, 0, 0, 0)
chip.Size = UDim2.new(0.85, 0, 0.075, 0)
chip.LayoutOrder = 1
chip.Visible = false
chip.ZIndex = 1
chip.Parent = topRightZone
local chipStroke = Instance.new("UIStroke")
chipStroke.Color = Color3.new(0, 0, 0)
chipStroke.Thickness = 4
chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
chipStroke.Parent = chip

local chipFace = Instance.new("Frame")
chipFace.Name = "Face"
chipFace.BackgroundColor3 = Color3.new(1, 1, 1)
chipFace.BorderSizePixel = 0
chipFace.Size = UDim2.new(1, 0, 0.94, 0)
chipFace.ZIndex = 2
chipFace.Parent = chip
local faceGrad = Instance.new("UIGradient")
faceGrad.Rotation = 90
faceGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 70, 210))
faceGrad.Parent = chipFace

local studs = Instance.new("ImageLabel")
studs.Name = "Studs"
studs.BackgroundTransparency = 1
studs.Size = UDim2.fromScale(1, 1)
studs.Image = STARS_ID
studs.ImageTransparency = 0.55
studs.TileSize = UDim2.fromOffset(38, 38)
studs.ZIndex = 3
studs.Parent = chipFace

-- Centered content row: fist icon + big count + HITS caption (no overlaps).
local faceRow = Instance.new("Frame")
faceRow.Name = "Row"
faceRow.BackgroundTransparency = 1
faceRow.AnchorPoint = Vector2.new(0.5, 0.5)
faceRow.Position = UDim2.fromScale(0.5, 0.5)
faceRow.Size = UDim2.new(0.92, 0, 0.8, 0)
faceRow.ZIndex = 4
faceRow.Parent = chipFace
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 8)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = faceRow

local fist = Instance.new("ImageLabel")
fist.Name = "Icon"
fist.BackgroundTransparency = 1
fist.LayoutOrder = 1
fist.Size = UDim2.new(0, 46, 1, 0)
fist.Image = FIST_ID
fist.ScaleType = Enum.ScaleType.Fit
fist.ZIndex = 4
fist.Parent = faceRow
local fistAspect = Instance.new("UIAspectRatioConstraint")
fistAspect.AspectRatio = 1
fistAspect.Parent = fist

local comboCount = Instance.new("TextLabel")
comboCount.Name = "Count"
comboCount.BackgroundTransparency = 1
comboCount.LayoutOrder = 2
comboCount.Size = UDim2.new(0, 96, 1, 0)
comboCount.Font = Enum.Font.FredokaOne
comboCount.Text = "0"
comboCount.TextColor3 = Color3.new(1, 1, 1)
comboCount.TextScaled = true
comboCount.TextXAlignment = Enum.TextXAlignment.Right
comboCount.ZIndex = 4
comboCount.Parent = faceRow
local countGrad = Instance.new("UIGradient")
countGrad.Rotation = 90
countGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD)
countGrad.Parent = comboCount
local countStroke = Instance.new("UIStroke")
countStroke.Color = Color3.new(0, 0, 0)
countStroke.Thickness = 3
countStroke.Parent = comboCount

local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "HitsLabel"
comboLabel.BackgroundTransparency = 1
comboLabel.LayoutOrder = 3
comboLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
comboLabel.Font = Enum.Font.FredokaOne
comboLabel.Text = "HITS"
comboLabel.TextColor3 = Color3.new(1, 1, 1)
comboLabel.TextScaled = true
comboLabel.TextXAlignment = Enum.TextXAlignment.Left
comboLabel.ZIndex = 4
comboLabel.Parent = faceRow
local labelStroke = Instance.new("UIStroke")
labelStroke.Color = Color3.new(0, 0, 0)
labelStroke.Thickness = 2.5
labelStroke.Parent = comboLabel

local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

local combo = 0
local lastHitAt = 0
local COMBO_WINDOW = 2.5

local function updateChip()
	comboCount.Text = tostring(combo)
	if combo >= 20 then
		comboCount.TextColor3 = RED
	elseif combo >= 10 then
		comboCount.TextColor3 = ORANGE
	else
		comboCount.TextColor3 = Color3.new(1, 1, 1)
	end
end

RunService.Heartbeat:Connect(function()
	if combo > 0 and os.clock() - lastHitAt > COMBO_WINDOW then
		combo = 0
		chip.Visible = false
	end
end)

local SFX = require(game:GetService("ReplicatedStorage"):WaitForChild("SFX"))

-- Son 3D court à une position (seulement si son ID est rempli dans SFX)
local function playSfxAt(name, position, volume)
	local id = SFX.Get(name)
	if id == "" or typeof(position) ~= "Vector3" then return end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 3)
end

standFX.OnClientEvent:Connect(function(kind, moveKind, position, amount)
	if kind == "RequiemAwaken" then
		if typeof(moveKind) == "Vector3" then
			shakePower = math.max(shakePower, 1.4)
			requiemAwaken(moveKind)
		end
		return
	end
	if kind == "Healed" then
		if typeof(moveKind) == "Vector3" and typeof(position) == "number" then
			healNumber(moveKind, position)
		end
		return
	end
	if kind ~= "Hit" then return end
	if typeof(position) ~= "Vector3" or typeof(amount) ~= "number" then return end
	local style = HIT_STYLES[moveKind] or HIT_STYLES.barrage

	sparkBurst(position, style.sparks)
	damageNumber(position, amount, style)
	if moveKind == "heavy" or moveKind == "final" then
		playSfxAt("HeavyHit", position, 0.9)
	elseif moveKind == "light" then
		playSfxAt("PunchHit", position, 0.7)
	end
	shakePower = math.max(shakePower, style.shake)

	combo += 1
	lastHitAt = os.clock()
	updateChip()
	-- compteur de coups masqué (demandé) : on garde le calcul, pas l'affichage
	chip.Visible = false
	chipScale.Scale = 1.14
	TweenService:Create(chipScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)

print("[CombatFX] Ready")
