-- SpellFX. Particules des attaques de Stand (moveset de StandSpells), vues par
-- tous les joueurs : chaque client surveille l'état ("State") de tous les
-- Stands et joue les effets du type d'attaque, à la couleur de l'attaque (ou
-- de l'aura du Stand).
--
-- Textures intégrées à Roblox uniquement (étincelles, fumée, feu) : elles
-- marchent toujours, sans ID de la boutique.
--
-- Les rafales et les attaques R réutilisent aussi les effets existants du
-- Stand (bras fantômes, traînées, yeux) : voir fxState dans StandController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))

-- Réglages -----------------------------------------------------------------
local MAX_DISTANCE = 220 -- pas d'effets pour les Stands trop loin de la caméra
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FLAME = "rbxasset://textures/particles/fire_main.dds"
local DEFAULT_COLOR = Color3.fromRGB(170, 120, 255)
------------------------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "LocalSpellFX"
folder.Parent = workspace

-- ─── Outils ─────────────────────────────────────────────────────────────────
local function anchorAt(position, lifetime)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	Debris:AddItem(part, lifetime)
	return part
end

local function lighter(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function makeEmitter(parent, color, opts)
	opts = opts or {}
	local attachment = Instance.new("Attachment")
	attachment.Position = opts.offset or Vector3.zero
	attachment.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.texture or SPARKLE
	e.Color = ColorSequence.new(lighter(color, 0.35), color)
	e.LightEmission = opts.light or 1
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(opts.life or 0.5, (opts.life or 0.5) * 1.5)
	e.Speed = NumberRange.new(opts.speed or 8, (opts.speed or 8) * 1.6)
	e.SpreadAngle = Vector2.new(opts.spread or 180, opts.spread or 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.size or 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Acceleration = opts.accel or Vector3.zero
	e.Drag = opts.drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rate = opts.rate or 0
	e.Enabled = (opts.rate or 0) > 0
	e.Parent = attachment
	return e, attachment
end

-- Jet unique de particules à une position
local function burst(position, color, opts)
	opts = opts or {}
	local anchor = anchorAt(position, (opts.life or 0.5) * 2 + 0.5)
	local e = makeEmitter(anchor, color, opts)
	e:Emit(opts.count or 25)
end

-- Particules continues sur une pièce pendant `duration`
local function aura(part, color, duration, opts)
	if not part then return end
	local e, attachment = makeEmitter(part, color, opts)
	e.Enabled = true
	task.delay(duration, function()
		e.Enabled = false
		Debris:AddItem(attachment, (opts and opts.life or 0.5) * 2 + 0.2)
	end)
end

-- Anneau qui s'agrandit au sol
local function ring(position, color, size, time)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Shape = Enum.PartType.Cylinder
	part.Transparency = 0.3
	part.Size = Vector3.new(0.2, 1, 1)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = folder
	TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
	Debris:AddItem(part, time + 0.1)
end

-- Traînée lumineuse sur une pièce pendant `duration`
local function trail(part, color, duration)
	if not part then return end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(lighter(color, 0.3), color)
	t.Transparency = NumberSequence.new(0.3, 1)
	t.LightEmission = 1
	t.Lifetime = 0.25
	t.FaceCamera = true
	t.Parent = part
	task.delay(duration, function()
		t.Enabled = false
		Debris:AddItem(t, 0.3)
		Debris:AddItem(a0, 0.3)
		Debris:AddItem(a1, 0.3)
	end)
end

-- ─── Arrêt du temps : bulle qui s'étend + monde désaturé ───────────────────
local function timeStopFX(position, color, duration)
	local shell = Instance.new("Part")
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField
	shell.Color = color
	shell.Size = Vector3.new(2, 2, 2)
	shell.CFrame = CFrame.new(position)
	shell.Parent = folder
	TweenService:Create(shell, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(140, 140, 140) }):Play()
	task.delay(0.6, function()
		TweenService:Create(shell, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(shell, 0.5)
	end)

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpellFX_TimeStop"
	cc.Saturation = 0
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.4), { Saturation = -0.85, Contrast = 0.15 }):Play()
	task.delay(math.max(duration - 0.3, 0.1), function()
		local fade = TweenService:Create(cc, TweenInfo.new(0.3), { Saturation = 0, Contrast = 0 })
		fade:Play()
		fade.Completed:Once(function() cc:Destroy() end)
	end)
	burst(position, color, { count = 60, speed = 30, life = 0.8, size = 0.7 })
end

-- ─── Effets par type d'attaque ──────────────────────────────────────────────
local function partOf(model, ...)
	if not model then return nil end
	for _, name in ipairs({ ... }) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

local EFFECTS = {}

function EFFECTS.Flurry(ctx)
	-- poings qui crépitent pendant toute la rafale
	aura(ctx.handR, ctx.color, ctx.move.Duration or 2, { rate = 45, speed = 6, life = 0.3, size = 0.45 })
	aura(ctx.handL, ctx.color, ctx.move.Duration or 2, { rate = 45, speed = 6, life = 0.3, size = 0.45 })
end

function EFFECTS.Strike(ctx)
	task.delay(ctx.move.HitDelay or 0.25, function()
		local pos = ctx.front(ctx.move.Range and math.min(ctx.move.Range * 0.5, 6) or 4)
		burst(pos, ctx.color, { count = 35, speed = 22, life = 0.4, size = 0.6 })
		burst(pos, ctx.color, { count = 6, texture = SMOKE, speed = 6, life = 0.6, size = 2.2, light = 0.3 })
		ring(pos, ctx.color, 8, 0.35)
	end)
	trail(ctx.handR, ctx.color, (ctx.move.HitDelay or 0.25) + 0.25)
end

function EFFECTS.Dash(ctx)
	if ctx.root then
		burst(ctx.root.Position - Vector3.new(0, 2.5, 0), ctx.color, { count = 10, texture = SMOKE, speed = 8, life = 0.6, size = 2.5, light = 0.2 })
		trail(ctx.root, ctx.color, (ctx.move.DashTime or 0.25) + 0.3)
		aura(ctx.root, ctx.color, (ctx.move.DashTime or 0.25) + 0.2, { rate = 80, speed = 3, life = 0.35, size = 0.5 })
	end
end

function EFFECTS.Projectile(ctx)
	task.delay(ctx.move.HitDelay or 0.2, function()
		local hand = ctx.handR or ctx.torso
		if hand then
			burst(hand.Position, ctx.color, { count = 25, speed = 18, life = 0.3, size = 0.5, spread = 40 })
		end
	end)
end

function EFFECTS.Burst(ctx)
	aura(ctx.torso, ctx.color, ctx.move.HitDelay or 0.5, { rate = 60, speed = 10, life = 0.4, size = 0.6 })
	task.delay(ctx.move.HitDelay or 0.5, function()
		local center = ctx.ground(ctx.move.Offset or 0)
		local size = (ctx.move.Radius or 8) * 2
		ring(center + Vector3.new(0, 0.3, 0), ctx.color, size, 0.5)
		burst(center + Vector3.new(0, 1, 0), ctx.color, { count = 70, speed = 30, life = 0.6, size = 0.8 })
		burst(center + Vector3.new(0, 1, 0), ctx.color, { count = 12, texture = SMOKE, speed = 14, life = 0.9, size = 4, light = 0.2 })
	end)
end

function EFFECTS.Buff(ctx)
	if not ctx.root then return end
	if ctx.move.Heal then
		-- particules qui montent autour du joueur
		aura(ctx.root, ctx.color, 1.2, { rate = 50, speed = 2, life = 1, size = 0.5, accel = Vector3.new(0, 8, 0), drag = 0 })
	end
	if ctx.move.SpeedBoost then
		trail(ctx.root, ctx.color, ctx.move.BuffTime or 5)
		aura(ctx.root, ctx.color, ctx.move.BuffTime or 5, { rate = 15, speed = 2, life = 0.4, size = 0.35 })
	end
	if ctx.move.Rewind then
		burst(ctx.root.Position, ctx.color, { count = 40, speed = 14, life = 0.6, size = 0.6 })
	end
	ring(ctx.root.Position - Vector3.new(0, 2.8, 0), ctx.color, 10, 0.5)
end

function EFFECTS.Teleport(ctx)
	if not ctx.root then return end
	burst(ctx.root.Position, ctx.color, { count = 14, texture = SMOKE, speed = 8, life = 0.6, size = 3, light = 0.3 })
	burst(ctx.root.Position, ctx.color, { count = 30, speed = 16, life = 0.4, size = 0.5 })
	task.delay(math.max((ctx.move.HitDelay or 0.3) - 0.05, 0.05), function()
		if ctx.root.Parent then
			burst(ctx.root.Position, ctx.color, { count = 30, speed = 16, life = 0.4, size = 0.5 })
		end
	end)
end

function EFFECTS.Counter(ctx)
	aura(ctx.torso, ctx.color, ctx.move.Duration or 1, { rate = 70, speed = 4, life = 0.4, size = 0.55 })
	if ctx.torso then ring(ctx.torso.Position, ctx.color, 9, 0.4) end
end

function EFFECTS.Pull(ctx)
	task.delay(ctx.move.HitDelay or 0.2, function()
		local hand = ctx.handR or ctx.torso
		if hand then burst(hand.Position, ctx.color, { count = 20, speed = 14, life = 0.3, size = 0.45 }) end
	end)
end

function EFFECTS.Zone(ctx)
	aura(ctx.handR, ctx.color, ctx.move.HitDelay or 0.4, { rate = 50, speed = 5, life = 0.4, size = 0.5 })
	aura(ctx.handL, ctx.color, ctx.move.HitDelay or 0.4, { rate = 50, speed = 5, life = 0.4, size = 0.5 })
	task.delay(ctx.move.HitDelay or 0.4, function()
		local center = ctx.ground(ctx.move.Offset or 0)
		local texture = (ctx.color.R > 0.8 and ctx.color.G < 0.6) and FLAME or SPARKLE
		-- pièce invisible de la taille de la zone : les particules sortent de
		-- toute sa surface (l'émetteur doit être directement sur la pièce)
		local radius = ctx.move.Radius or 8
		local area = anchorAt(center + Vector3.new(0, 0.5, 0), (ctx.move.Lifetime or 3) + 1.5)
		area.Size = Vector3.new(radius * 2, 0.5, radius * 2)
		local e, attachment = makeEmitter(area, ctx.color, {
			rate = 60, texture = texture, speed = 3, life = 0.9, size = 0.9,
			accel = Vector3.new(0, 6, 0), spread = 25, drag = 0,
		})
		e.Parent = area
		attachment:Destroy()
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Enabled = true
		task.delay(ctx.move.Lifetime or 3, function() e.Enabled = false end)
	end)
end

function EFFECTS.Mine(ctx)
	task.delay(ctx.move.HitDelay or 0.35, function()
		local pos = ctx.ground(ctx.move.Offset or 4)
		burst(pos + Vector3.new(0, 0.5, 0), ctx.color, { count = 25, speed = 8, life = 0.5, size = 0.4 })
		ring(pos + Vector3.new(0, 0.2, 0), ctx.color, 6, 0.4)
	end)
end

function EFFECTS.TimeStop(ctx)
	local pos = (ctx.torso or ctx.root) and (ctx.torso or ctx.root).Position
	if pos then timeStopFX(pos, ctx.color, ctx.move.Duration or 3) end
end

function EFFECTS.Erase(ctx)
	if not ctx.root then return end
	aura(ctx.root, ctx.color, ctx.move.EraseTime or 2.5, {
		rate = 40, texture = SMOKE, speed = 2, life = 0.8, size = 2, light = 0.3,
	})
	aura(ctx.root, ctx.color, ctx.move.EraseTime or 2.5, { rate = 30, speed = 6, life = 0.4, size = 0.4 })
	burst(ctx.root.Position, ctx.color, { count = 40, speed = 18, life = 0.5, size = 0.6 })
end

-- ─── Déclenchement ─────────────────────────────────────────────────────────
local function playFor(stand)
	local state = stand:GetAttribute("State")
	local def = StandData.GetStand(stand:GetAttribute("StandId") or "")
	local move = def and def.Moves and def.Moves[state]
	if not move or not move.Type or not EFFECTS[move.Type] then return end
	local camera = workspace.CurrentCamera
	if not stand.PrimaryPart or (camera and (camera.CFrame.Position - stand.PrimaryPart.Position).Magnitude > MAX_DISTANCE) then
		return
	end
	local owner = Players:GetPlayerByUserId(stand:GetAttribute("Owner") or 0)
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local color = move.Color or (def.Theme and def.Theme.Aura1) or DEFAULT_COLOR
	local ctx = {
		move = move,
		color = color,
		stand = stand,
		root = root,
		torso = partOf(stand, "UpperTorso", "Torso"),
		handR = partOf(stand, "RightHand", "Right Arm"),
		handL = partOf(stand, "LeftHand", "Left Arm"),
	}
	local function flat()
		local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local f = Vector3.new(look.X, 0, look.Z)
		return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
	end
	-- point devant le joueur, à hauteur de poitrine
	ctx.front = function(distance)
		local base = root and root.Position or stand.PrimaryPart.Position
		return base + flat() * distance + Vector3.new(0, 1, 0)
	end
	-- point au sol devant le joueur
	ctx.ground = function(distance)
		local base = root and root.Position or stand.PrimaryPart.Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, stand, folder }
		local from = base + flat() * distance + Vector3.new(0, 3, 0)
		local result = workspace:Raycast(from, Vector3.new(0, -30, 0), params)
		return result and result.Position or (from - Vector3.new(0, 6, 0))
	end
	EFFECTS[move.Type](ctx)
end

local function watch(stand)
	if not stand:IsA("Model") or not stand.Name:match("Stand$") then return end
	if not stand:GetAttribute("Owner") then
		-- les attributs arrivent parfois juste après le modèle
		task.wait(0.2)
		if not stand:GetAttribute("Owner") then return end
	end
	stand:GetAttributeChangedSignal("State"):Connect(function()
		playFor(stand)
	end)
end

workspace.ChildAdded:Connect(function(child)
	task.spawn(watch, child)
end)
for _, child in workspace:GetChildren() do
	task.spawn(watch, child)
end
