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

-- Textures dessinées pour le jeu (assets/textures/*.png dans le dépôt).
-- Une fois importées dans Roblox (Fenêtre → Gestionnaire d'assets →
-- Importer), mettre leur ID ici, ex. "rbxassetid://123456789".
-- Tant qu'un ID est vide, la texture intégrée de Roblox est utilisée.
local TEXTURES = {
	Glow = "rbxassetid://138403917480165",
	Spark = "rbxassetid://74912473102145",
	Impact = "rbxassetid://87537987778207",
	Ring = "rbxassetid://115337750392303",
	Slash = "rbxassetid://73831602916103",
	Lightning = "rbxassetid://75208682471722",
	Smoke = "rbxassetid://137211278777046",
	Star = "rbxassetid://133511855155150",
	Shard = "rbxassetid://88905406839516",
	Flame = "rbxassetid://114860784322228",
	Petal = "rbxassetid://95473304233140",
	Gem = "rbxassetid://126447150623322",
	Zipper = "rbxassetid://113054516565882",
}
local function tex(name, fallback)
	local id = TEXTURES[name]
	if id and id ~= "" then return id end
	return fallback
end
local function hasTex(name)
	return TEXTURES[name] ~= nil and TEXTURES[name] ~= ""
end

-- Réglages -----------------------------------------------------------------
local MAX_DISTANCE = 220 -- pas d'effets pour les Stands trop loin de la caméra
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = tex("Smoke", "rbxasset://textures/particles/smoke_main.dds")
local FLAME = tex("Flame", "rbxasset://textures/particles/fire_main.dds")
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
	if opts.streak then
		-- étincelles étirées dans le sens de leur vitesse
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(opts.streak)
		e.Rotation = NumberRange.new(0)
		e.RotSpeed = NumberRange.new(0)
	end
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
	if hasTex("Ring") then
		-- onde de choc dessinée, posée à plat
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 0.05, 1)
		part.CFrame = CFrame.new(position)
		part.Parent = folder
		for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
			local decal = Instance.new("Decal")
			decal.Texture = TEXTURES.Ring
			decal.Face = face
			decal.Color3 = color
			decal.Parent = part
			TweenService:Create(decal, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
		TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(size, 0.05, size) }):Play()
		Debris:AddItem(part, time + 0.1)
		return
	end
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

-- ─── Impacts en couches ─────────────────────────────────────────────────────
-- Flash de lumière
local function flash(position, color, brightness, range, time)
	local anchor = anchorAt(position, time + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 6
	light.Range = range or 16
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(time or 0.25), { Brightness = 0 }):Play()
end

-- Impact complet. power = 1 normal, 2 gros coup
local function impact(position, color, power)
	power = power or 1
	flash(position, color, 5 * power, 14 * power, 0.25)
	-- éclair central (une grosse particule très courte)
	burst(position, lighter(color, 0.5), { count = 2, speed = 0, life = hasTex("Impact") and 0.12 or 0.08,
		size = (hasTex("Impact") and 5 or 3.5) * power, spread = 0, texture = tex("Impact", SPARKLE) })
	burst(position, color, { count = 1, speed = 0, life = 0.3, size = 6 * power, spread = 0, texture = tex("Glow", SPARKLE), light = 0.8 })
	-- étincelles étirées
	burst(position, color, { count = math.floor(28 * power), speed = 38 * power, life = 0.22,
		size = hasTex("Spark") and 0.8 or 0.35, streak = hasTex("Spark") and 1.5 or 3, drag = 4, texture = tex("Spark", SPARKLE) })
	-- éclats plus lents
	burst(position, lighter(color, 0.2), { count = math.floor(16 * power), speed = 14, life = 0.45, size = 0.5 })
	-- fumée
	burst(position, Color3.fromRGB(70, 65, 75), { count = math.floor(5 * power), texture = SMOKE, speed = 5, life = 0.8, size = 2.5 * power, light = 0 })
	-- double onde : rapide et fine, puis lente et large
	ring(position, lighter(color, 0.4), 7 * power, 0.18)
	ring(position, color, 12 * power, 0.45)
end

-- Colonne de lumière verticale (grosses attaques de zone)
local function pillar(position, color, radius, height)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Shape = Enum.PartType.Cylinder
	part.Transparency = 0.25
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = folder
	TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(height * 1.2, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.5)
end

-- Débris de roche projetés puis qui retombent
local function rockDebris(position, count)
	local rng2 = Random.new()
	for _ = 1, count or 8 do
		local rock = Instance.new("Part")
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(95, 90, 85)
		local size = rng2:NextNumber(0.5, 1.2)
		rock.Size = Vector3.new(size, size * 0.8, size)
		rock.CFrame = CFrame.new(position) * CFrame.Angles(rng2:NextNumber(0, 6), rng2:NextNumber(0, 6), 0)
		rock.Parent = folder
		local dir = Vector3.new(rng2:NextNumber(-1, 1), 0, rng2:NextNumber(-1, 1))
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis
		local far = position + dir * rng2:NextNumber(3, 7)
		local top = (position + far) / 2 + Vector3.new(0, rng2:NextNumber(2, 4), 0)
		TweenService:Create(rock, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(top) * CFrame.Angles(rng2:NextNumber(0, 6), rng2:NextNumber(0, 6), 0) }):Play()
		task.delay(0.25, function()
			TweenService:Create(rock, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = CFrame.new(far - Vector3.new(0, 0.3, 0)) }):Play()
			task.delay(0.9, function()
				TweenService:Create(rock, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end)
		end)
		Debris:AddItem(rock, 1.7)
	end
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
		-- les attaques lourdes (R, gros dégâts) frappent plus fort visuellement
		local heavy = ctx.move.Key == "R" or (ctx.move.Damage or 0) >= 15
		impact(pos, ctx.color, heavy and 1.6 or 1)
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
		impact(center + Vector3.new(0, 1, 0), ctx.color, 1.5 + size / 30)
		ring(center + Vector3.new(0, 0.3, 0), ctx.color, size, 0.5)
		pillar(center, ctx.color, math.min(size / 4, 4), 14)
		rockDebris(center + Vector3.new(0, 0.5, 0), math.floor(6 + size / 4))
		burst(center + Vector3.new(0, 1, 0), Color3.fromRGB(90, 80, 70), { count = 14, texture = SMOKE, speed = 16, life = 1, size = 4, light = 0 })
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

-- ─── Formes animées pour les signatures de Stand ────────────────────────────
local rng = Random.new()

local function shape(color, size, cframe, shapeKind)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	if shapeKind == "Ball" then part.Shape = Enum.PartType.Ball end
	part.CFrame = cframe
	part.Parent = folder
	return part
end

-- Petits morceaux projetés dans toutes les directions (éclats, gemmes, pétales)
local function debris(position, color, opts)
	opts = opts or {}
	for _ = 1, opts.count or 10 do
		local dir = rng:NextUnitVector()
		if opts.upward then dir = Vector3.new(dir.X, math.abs(dir.Y) + 0.3, dir.Z).Unit end
		local size = opts.size or Vector3.new(0.35, 0.35, 0.35)
		local s = rng:NextNumber(0.7, 1.3)
		local part = shape(opts.colors and opts.colors[rng:NextInteger(1, #opts.colors)] or color,
			size * s, CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3)),
			opts.ball and "Ball" or nil)
		local life = rng:NextNumber(0.35, 0.6) * (opts.life or 1)
		local goal = CFrame.new(position + dir * rng:NextNumber(3, 7) * (opts.spread or 1))
			* CFrame.Angles(rng:NextNumber(0, 12), rng:NextNumber(0, 12), rng:NextNumber(0, 12))
		TweenService:Create(part, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = goal, Transparency = 1, Size = part.Size * 0.3 }):Play()
		Debris:AddItem(part, life + 0.05)
	end
end

-- Lames de lumière (coups d'épée, griffes, tranchants)
local function slashes(position, color, count, length)
	for i = 1, count or 2 do
		local angle = rng:NextNumber(-0.9, 0.9) + (i - 1) * 1.2
		local part = shape(color, Vector3.new(0.15, 0.6, length or 7),
			CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6.3), angle))
		TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.05, 0.1, (length or 7) * 1.4), Transparency = 1 }):Play()
		Debris:AddItem(part, 0.3)
	end
end

-- Anneau de petites sphères qui tourne (halo, horloge)
local function orbitRing(position, color, radius, count, time)
	local parts = {}
	for i = 1, count do
		parts[i] = shape(color, Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), "Ball")
	end
	local started = os.clock()
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= time then
			connection:Disconnect()
			for _, part in parts do part:Destroy() end
			return
		end
		local fade = t / time
		for i, part in parts do
			local a = (i / count) * math.pi * 2 + t * 4
			part.CFrame = CFrame.new(position + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * (0.6 + fade * 0.6))
			part.Transparency = fade
		end
	end)
end

-- Traits de vitesse le long d'une direction
local function speedLines(position, direction, color, count)
	for _ = 1, count or 6 do
		local offset = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
		local start = position + offset
		local part = shape(color, Vector3.new(0.08, 0.08, rng:NextNumber(3, 6)), CFrame.lookAt(start, start + direction))
		TweenService:Create(part, TweenInfo.new(0.3), { CFrame = part.CFrame - direction * 6, Transparency = 1 }):Play()
		Debris:AddItem(part, 0.35)
	end
end

-- Fermeture éclair lumineuse entre deux points (maillons qui apparaissent)
local function zipper(from, to, color)
	local length = (to - from).Magnitude
	local steps = math.clamp(math.floor(length / 0.8), 3, 30)
	for i = 0, steps do
		task.delay(i * 0.015, function()
			local pos = from:Lerp(to, i / steps)
			local side = (i % 2 == 0) and 0.3 or -0.3
			local part = shape(color, Vector3.new(0.5, 0.15, 0.3), CFrame.lookAt(pos, to) * CFrame.new(side, 0, 0))
			TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			Debris:AddItem(part, 0.55)
		end)
	end
end

-- "ゴゴゴ" qui flottent autour du Stand (garde, contre, arrêt du temps)
local menacing = setmetatable({}, { __mode = "k" })
local function startMenacing(stand, color, isActive)
	if menacing[stand] then return end
	menacing[stand] = true
	task.spawn(function()
		while stand.Parent and isActive() do
			local base = stand.PrimaryPart and stand.PrimaryPart.Position
			if base then
				local anchor = anchorAt(base + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 2), rng:NextNumber(-3, 3)), 1.3)
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromOffset(46, 46)
				gui.LightInfluence = 0
				gui.MaxDistance = 90
				gui.Parent = anchor
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.GothamBlack
				label.Text = "ゴ"
				label.TextScaled = true
				label.TextColor3 = color
				label.TextStrokeColor3 = Color3.new(0, 0, 0)
				label.TextStrokeTransparency = 0
				label.Rotation = rng:NextNumber(-20, 20)
				label.Parent = gui
				TweenService:Create(anchor, TweenInfo.new(1.2), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
				TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
			task.wait(0.22)
		end
		menacing[stand] = nil
	end)
end

-- ─── Signatures visuelles de chaque Stand ───────────────────────────────────
-- Appelées en plus des effets du type d'attaque : au lancement ("start") et
-- au moment de l'impact ("impact"). `dir` = direction du joueur.
local function rubble(pos, color, n)
	debris(pos, color, { count = n or 10, size = Vector3.new(0.5, 0.5, 0.5) })
end

local SIGNATURES = {
	-- étoiles violettes et onde de choc
	StarPlatinum = function(ctx, phase, pos)
		if phase == "impact" then
			debris(pos, ctx.color, { count = 10, ball = true, size = Vector3.new(0.3, 0.3, 0.3) })
			ring(pos, Color3.fromRGB(230, 210, 255), 10, 0.3)
		end
	end,
	-- anneaux d'horloge dorés et éclats de lames
	TheWorld = function(ctx, phase, pos)
		if phase == "start" then
			orbitRing(pos, ctx.color, 4, 12, 0.6)
		else
			slashes(pos, Color3.fromRGB(255, 240, 180), 2, 6)
			debris(pos, ctx.color, { count = 8 })
		end
	end,
	-- éclats rouges et dorés, brutaux
	TheWorldAU = function(ctx, phase, pos)
		if phase == "impact" then
			debris(pos, ctx.color, { count = 14, colors = { Color3.fromRGB(255, 200, 70), Color3.fromRGB(200, 30, 30) }, spread = 1.3 })
			slashes(pos, Color3.fromRGB(220, 40, 40), 1, 8)
		end
	end,
	-- éclats de verre et diamants roses
	CrazyDiamond = function(ctx, phase, pos)
		if phase == "impact" then
			debris(pos, ctx.color, { count = 14, size = Vector3.new(0.12, 0.6, 0.45),
				colors = { Color3.fromRGB(255, 150, 210), Color3.fromRGB(190, 235, 255), Color3.fromRGB(255, 255, 255) } })
		else
			debris(pos, Color3.fromRGB(190, 235, 255), { count = 6, size = Vector3.new(0.4, 0.4, 0.4), spread = 0.6 })
		end
	end,
	-- lames de rapière argentées
	SilverChariot = function(ctx, phase, pos)
		slashes(pos, Color3.fromRGB(235, 240, 255), phase == "impact" and 3 or 1, 7)
	end,
	-- explosions roses : flammes et fumée
	KillerQueen = function(ctx, phase, pos)
		if phase == "impact" then
			burst(pos, Color3.fromRGB(255, 140, 60), { count = 30, texture = FLAME, speed = 14, life = 0.5, size = 1.4 })
			burst(pos, Color3.fromRGB(80, 60, 60), { count = 10, texture = SMOKE, speed = 8, life = 1, size = 3.5, light = 0 })
			debris(pos, Color3.fromRGB(255, 130, 200), { count = 6, ball = true })
		end
	end,
	-- pétales et feuilles qui s'envolent
	GoldExperience = function(ctx, phase, pos)
		debris(pos, ctx.color, { count = phase == "impact" and 14 or 6, upward = true, size = Vector3.new(0.5, 0.08, 0.35), life = 1.6,
			colors = { Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 160, 210) } })
	end,
	-- halo doré et pétales
	GoldExperienceRequiem = function(ctx, phase, pos)
		if phase == "start" then
			orbitRing(pos + Vector3.new(0, 3, 0), Color3.fromRGB(255, 230, 120), 2, 10, 0.8)
		else
			debris(pos, ctx.color, { count = 12, upward = true, size = Vector3.new(0.5, 0.08, 0.35), life = 1.4 })
			ring(pos, Color3.fromRGB(255, 240, 170), 9, 0.35)
		end
	end,
	-- distorsion : fragments rouges et noirs qui "sautent"
	KingCrimson = function(ctx, phase, pos)
		debris(pos, ctx.color, { count = phase == "impact" and 12 or 8, size = Vector3.new(0.6, 0.6, 0.08),
			colors = { Color3.fromRGB(220, 30, 60), Color3.fromRGB(20, 0, 5), Color3.fromRGB(255, 120, 140) }, spread = 1.2 })
	end,
	-- gemmes émeraude
	HierophantGreen = function(ctx, phase, pos)
		debris(pos, ctx.color, { count = phase == "impact" and 12 or 6, size = Vector3.new(0.45, 0.45, 0.45),
			colors = { Color3.fromRGB(60, 230, 120), Color3.fromRGB(150, 255, 190) } })
	end,
	-- flammes partout
	MagiciansRed = function(ctx, phase, pos)
		burst(pos, Color3.fromRGB(255, 120, 40), { count = phase == "impact" and 35 or 15, texture = FLAME,
			speed = 10, life = 0.6, size = 1.6, accel = Vector3.new(0, 10, 0) })
	end,
	-- fermetures éclair lumineuses
	StickyFingers = function(ctx, phase, pos)
		local from = ctx.root and ctx.root.Position or pos
		if phase == "impact" then
			zipper(pos + Vector3.new(0, 2, 0), pos - Vector3.new(0, 2, 0), Color3.fromRGB(150, 200, 255))
		else
			zipper(from, from + ctx.dir * 5, Color3.fromRGB(150, 200, 255))
		end
	end,
	-- traits de vitesse blancs
	MadeInHeaven = function(ctx, phase, pos)
		speedLines(pos, ctx.dir, Color3.fromRGB(220, 255, 255), phase == "impact" and 10 or 6)
	end,
}

-- Particules dessinées propres à chaque Stand (si la texture est importée)
local SIGNATURE_TEXTURES = {
	StarPlatinum = { "Star", 8, 0.9 },
	TheWorld = { "Slash", 2, 3.5 },
	TheWorldAU = { "Slash", 2, 3.5 },
	CrazyDiamond = { "Shard", 10, 0.9 },
	SilverChariot = { "Slash", 3, 3.2 },
	KillerQueen = { "Impact", 2, 3 },
	GoldExperience = { "Petal", 10, 0.8 },
	GoldExperienceRequiem = { "Petal", 10, 0.8 },
	KingCrimson = { "Lightning", 3, 2.5 },
	HierophantGreen = { "Gem", 10, 0.9 },
	MagiciansRed = { "Flame", 12, 1.6 },
	StickyFingers = { "Zipper", 3, 1.8 },
	MadeInHeaven = { "Spark", 14, 1.2 },
}

local function signature(ctx, phase, pos)
	local fn = SIGNATURES[ctx.standId]
	if fn and pos then
		pcall(fn, ctx, phase, pos)
	end
	local drawn = SIGNATURE_TEXTURES[ctx.standId]
	if drawn and pos and phase == "impact" and hasTex(drawn[1]) then
		burst(pos, ctx.color, { count = drawn[2], texture = TEXTURES[drawn[1]], size = drawn[3],
			speed = 12, life = 0.45, drag = 3, light = 0.9 })
	end
end

-- Où se produit "l'impact" de chaque type d'attaque
local function impactPoint(ctx)
	local move = ctx.move
	local t = move.Type
	if t == "Burst" or t == "Mine" or t == "Zone" then
		return ctx.ground(move.Offset or 0) + Vector3.new(0, 1, 0)
	elseif t == "Strike" or t == "Pull" then
		return ctx.front(move.Range and math.min(move.Range * 0.5, 6) or 4)
	elseif t == "Projectile" then
		return (ctx.handR or ctx.torso) and (ctx.handR or ctx.torso).Position
	else
		return ctx.root and ctx.root.Position
	end
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
	ctx.standId = stand:GetAttribute("StandId")
	ctx.dir = flat()
	EFFECTS[move.Type](ctx)

	-- Le Stand s'illumine (contour à sa couleur) pendant l'attaque
	local highlight = stand:FindFirstChild("SpellGlow")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "SpellGlow"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = stand
	end
	highlight.FillColor = color
	highlight.OutlineColor = lighter(color, 0.4)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.Enabled = true
	task.spawn(function()
		local endsAt = os.clock() + (move.Duration or 0.6)
		while os.clock() < endsAt and stand.Parent and stand:GetAttribute("State") == state do
			task.wait(0.05)
		end
		if highlight.Parent then
			local fade = TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 })
			fade:Play()
			fade.Completed:Once(function()
				if stand:GetAttribute("State") ~= state or not stand.Parent then highlight.Enabled = false end
			end)
		end
	end)

	-- Signature du Stand : au lancement…
	signature(ctx, "start", ctx.torso and ctx.torso.Position)
	-- …et à l'impact (plusieurs fois pendant une rafale)
	if move.Type == "Flurry" then
		task.spawn(function()
			local endsAt = os.clock() + (move.Duration or 2)
			while os.clock() < endsAt and stand.Parent and stand:GetAttribute("State") == state do
				signature(ctx, "impact", ctx.front(4))
				task.wait(0.3)
			end
		end)
	elseif move.Type ~= "TimeStop" and move.Type ~= "Erase" then
		task.delay(move.HitDelay or 0.25, function()
			signature(ctx, "impact", impactPoint(ctx))
		end)
	end

	-- "ゴゴゴ" pendant un contre ou un arrêt du temps
	if move.Type == "Counter" or move.Type == "TimeStop" then
		startMenacing(stand, color, function()
			return stand:GetAttribute("State") == state
		end)
	end
end

local function watch(stand)
	if not stand:IsA("Model") or not stand.Name:match("Stand$") then return end
	if not stand:GetAttribute("Owner") then
		-- les attributs arrivent parfois juste après le modèle
		task.wait(0.2)
		if not stand:GetAttribute("Owner") then return end
	end
	stand:GetAttributeChangedSignal("State"):Connect(function()
		if stand:GetAttribute("State") == "Block" then
			local def = StandData.GetStand(stand:GetAttribute("StandId") or "")
			local color = (def and def.Theme and def.Theme.Aura1) or DEFAULT_COLOR
			startMenacing(stand, color, function()
				return stand:GetAttribute("State") == "Block"
			end)
			return
		end
		playFor(stand)
	end)
end

-- ─── Cible touchée : flash blanc ────────────────────────────────────────────
local hitParams = OverlapParams.new()
hitParams.FilterType = Enum.RaycastFilterType.Exclude
hitParams.FilterDescendantsInstances = { folder }

local function hitFlash(position)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > MAX_DISTANCE then return end
	for _, part in workspace:GetPartBoundsInRadius(position, 2.5, hitParams) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") and not model.Name:match("Stand$") then
			local h = model:FindFirstChild("HitFlash")
			if not h then
				h = Instance.new("Highlight")
				h.Name = "HitFlash"
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.FillColor = Color3.new(1, 1, 1)
				h.OutlineColor = Color3.new(1, 1, 1)
				h.Parent = model
			end
			h.Enabled = true
			h.FillTransparency = 0.15
			h.OutlineTransparency = 0
			TweenService:Create(h, TweenInfo.new(0.15), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			return
		end
	end
end

-- ─── Effet de vitesse sur la caméra (ruées, déplacements) ───────────────────
local baseFov = nil
local function fovKick(amount, time)
	local camera = workspace.CurrentCamera
	if not camera then return end
	baseFov = baseFov or camera.FieldOfView
	camera.FieldOfView = baseFov + amount
	TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = baseFov }):Play()
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX").OnClientEvent:Connect(function(kind, a, b)
	if kind == "Hit" and typeof(b) == "Vector3" then
		hitFlash(b)
	elseif kind == "SpellDash" or kind == "Mobility" then
		fovKick(12, 0.45)
	end
end)

workspace.ChildAdded:Connect(function(child)
	task.spawn(watch, child)
end)
for _, child in workspace:GetChildren() do
	task.spawn(watch, child)
end
