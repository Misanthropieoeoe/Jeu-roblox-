-- ProjectileFX. Affiche en local, de façon fluide, les projectiles des
-- attaques de Stand, avec un look propre à chaque Stand.
-- Le serveur calcule seul la trajectoire et les dégâts (StandService, section
-- "Projectiles") et envoie :
--   "Projectile"     (id, départ, direction, vitesse, portée, style)
--                    style = { Size, Shape, Color, StandId, Move, Homing }
--   "ProjectileSync" (id, position, direction)  tête chercheuse, 10x/s
--   "ProjectileEnd"  (id, position d'arrêt)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local TEXTURES = require(ReplicatedStorage:WaitForChild("VFXTextures"))
local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")

-- Réglages -----------------------------------------------------------------
local LIGHT = 0.3 -- intensité lumineuse (1 = fort, comme SpellFX.LIGHT)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
------------------------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "LocalProjectiles"
folder.Parent = workspace

local active = {} -- [id] = projectile

local function tex(name)
	local id = TEXTURES[name]
	return (id and id ~= "") and id or SPARKLE
end

local function lighter(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- ─── Briques visuelles ─────────────────────────────────────────────────────
local function basePart(size, color, material)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = tint(color)
	part.Size = size
	return part
end

-- Skin équipé : la couleur du skin remplace les couleurs fixes des looks
local override = nil
local function tint(color)
	return override or color
end

local function addTrail(part, color, width, lifetime)
	color = tint(color)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(lighter(color, 0.4), color)
	trail.LightEmission = LIGHT
	trail.Lifetime = lifetime or 0.18
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.FaceCamera = true
	trail.Parent = part
end

-- Particules qui sortent du projectile en vol
local function addEmitter(part, color, opts)
	color = tint(color)
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.texture or SPARKLE
	e.Color = ColorSequence.new(lighter(color, 0.3), color)
	e.LightEmission = (opts.light or 1) * LIGHT
	e.LightInfluence = 0
	e.Rate = opts.rate or 40
	e.Lifetime = NumberRange.new(opts.life or 0.3, (opts.life or 0.3) * 1.5)
	e.Speed = NumberRange.new(opts.speed or 1, (opts.speed or 1) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.size or 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Acceleration = opts.accel or Vector3.zero
	e.Drag = 2
	e.Parent = part
	return e
end

local function addLight(part, color, range)
	color = tint(color)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 6
	light.Brightness = 1.5 * LIGHT
	light.Parent = part
end

-- Jet d'impact à la fin du projectile
local function impactBurst(position, color, texture, count, size)
	local anchor = basePart(Vector3.new(0.2, 0.2, 0.2), color)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder
	local e = addEmitter(anchor, color, { texture = texture, rate = 0, speed = 12, life = 0.35, size = size or 0.6 })
	e:Emit(count or 18)
	Debris:AddItem(anchor, 1)
end

-- ─── Looks de chaque Stand ─────────────────────────────────────────────────
-- Chaque look construit le projectile et décrit son vol : spin (rotation
-- autour de l'axe d'avancée, rad/s), tumble (tourne dans tous les sens),
-- wobble (zigzag), coin (pièce lancée), et son impact.
local LOOKS = {}

-- Bille d'acier (Star Platinum) : métal brillant, traînée d'étoiles
LOOKS.StarPlatinum = function(style, color)
	local size = style.Size or 0.6
	local part = basePart(Vector3.new(size, size, size), Color3.fromRGB(215, 220, 230), Enum.Material.Metal)
	part.Shape = Enum.PartType.Ball
	part.Reflectance = 0.3
	addTrail(part, color, size * 0.9, 0.2)
	addEmitter(part, color, { texture = tex("Star"), rate = 30, size = 0.35, life = 0.25 })
	return part, { impact = tex("Star"), impactCount = 14 }
end

-- Couteaux (The World, TWAU) : lame métallique qui tourne, éclat coloré
local function knife(style, glint)
	local size = style.Size or 0.4
	local part = basePart(Vector3.new(size * 0.25, size * 0.7, size * 3.2), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
	part.Reflectance = 0.35
	addTrail(part, glint, size * 0.6, 0.12)
	addEmitter(part, glint, { texture = tex("Spark"), rate = 25, size = 0.25, life = 0.18 })
	return part, { spin = 20, impact = tex("Slash"), impactCount = 3, impactSize = 1.6 }
end
LOOKS.TheWorld = function(style) return knife(style, Color3.fromRGB(255, 215, 110)) end
LOOKS.TheWorldAU = function(style) return knife(style, Color3.fromRGB(230, 70, 60)) end

-- Lames de rapière (Silver Chariot) : argent, traînée blanche
LOOKS.SilverChariot = function(style)
	local size = style.Size or 0.5
	local part = basePart(Vector3.new(size * 0.2, size * 0.5, size * 3.5), Color3.fromRGB(230, 235, 245), Enum.Material.Metal)
	part.Reflectance = 0.45
	addTrail(part, Color3.fromRGB(235, 240, 255), size * 0.7, 0.16)
	return part, { impact = tex("Slash"), impactCount = 2, impactSize = 1.8 }
end

-- Pièce piégée (Killer Queen) : disque doré qui tournoie, mèche qui crépite
LOOKS.KillerQueen = function(style)
	local size = style.Size or 0.7
	local part = basePart(Vector3.new(size * 0.18, size, size), Color3.fromRGB(240, 195, 70), Enum.Material.Metal)
	part.Shape = Enum.PartType.Cylinder
	part.Reflectance = 0.3
	addEmitter(part, Color3.fromRGB(255, 140, 60), { texture = tex("Flame"), rate = 45, size = 0.45, life = 0.25, accel = Vector3.new(0, 4, 0) })
	addEmitter(part, Color3.fromRGB(255, 130, 200), { texture = tex("Spark"), rate = 20, size = 0.2, speed = 4, life = 0.2 })
	addLight(part, Color3.fromRGB(255, 150, 80), 6)
	return part, { coin = 14, impact = tex("Impact"), impactCount = 3, impactSize = 2.5 }
end

-- Essaim (Gold Experience) : petite boule de vie qui zigzague, pétales
LOOKS.GoldExperience = function(style, color)
	local size = style.Size or 0.5
	local part = basePart(Vector3.new(size, size, size), Color3.fromRGB(170, 255, 140))
	part.Shape = Enum.PartType.Ball
	part.Transparency = 0.3
	addTrail(part, color, size * 0.6, 0.25)
	addEmitter(part, color, { texture = tex("Petal"), rate = 18, size = 0.35, life = 0.5, speed = 2 })
	return part, { wobble = 0.6, impact = tex("Petal"), impactCount = 10 }
end

-- Émeraudes (Hierophant Green) : gemme en verre qui tourne, traînée verte
LOOKS.HierophantGreen = function(style, color)
	local size = style.Size or 0.5
	local part = basePart(Vector3.new(size, size, size), Color3.fromRGB(70, 230, 130), Enum.Material.Glass)
	part.Transparency = 0.15
	part.Reflectance = 0.2
	addTrail(part, color, size * 0.7, 0.2)
	addEmitter(part, color, { texture = tex("Gem"), rate = 20, size = 0.3, life = 0.25 })
	return part, { tumble = true, impact = tex("Gem"), impactCount = 12 }
end

-- Oiseau de feu (Magician's Red) : boule de flammes avec braises
LOOKS.MagiciansRed = function(style)
	local size = style.Size or 1.6
	local part = basePart(Vector3.new(size * 0.6, size * 0.6, size * 0.6), Color3.fromRGB(255, 170, 70))
	part.Shape = Enum.PartType.Ball
	part.Transparency = 0.5
	addEmitter(part, Color3.fromRGB(255, 120, 40), { texture = tex("Flame"), rate = 110, size = size * 1.1, life = 0.35, speed = 2 })
	addEmitter(part, Color3.fromRGB(255, 200, 90), { texture = tex("Spark"), rate = 35, size = 0.25, speed = 6, life = 0.4, accel = Vector3.new(0, 6, 0) })
	addLight(part, Color3.fromRGB(255, 130, 50), 10)
	return part, { impact = tex("Flame"), impactCount = 26, impactSize = 1.6 }
end

-- Look par défaut : orbe ou lame lumineuse à la couleur de l'attaque
local function defaultLook(style, color)
	local size = style.Size or 0.6
	local part
	if style.Shape == "Blade" then
		part = basePart(Vector3.new(size * 0.3, size * 0.3, size * 3), color)
	else
		part = basePart(Vector3.new(size, size, size), color)
		part.Shape = Enum.PartType.Ball
	end
	part.Transparency = 0.3
	addTrail(part, color, size * 0.8, 0.15)
	addEmitter(part, color, { texture = tex("Glow"), rate = 25, size = size, life = 0.2 })
	return part, { impact = tex("Spark"), impactCount = 14 }
end

-- ─── Vie des projectiles ───────────────────────────────────────────────────
-- Les murs arrêtent le projectile visuellement ; les personnages et les
-- Stands non (c'est le serveur qui décide des touches).
local function wallParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	for _, name in ipairs({ "StandSpellFX", "LocalSpellFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(ignore, f) end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function removeProjectile(id, endPos)
	local p = active[id]
	if not p then return end
	active[id] = nil
	local part = p.part
	impactBurst(endPos or part.Position, p.color, p.look.impact, p.look.impactCount, p.look.impactSize)
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") then d.Enabled = false end
	end
	TweenService:Create(part, TweenInfo.new(0.1), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.5)
end

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

standFX.OnClientEvent:Connect(function(kind, id, a, b, c, d, e)
	if kind == "Projectile" then
		local origin, dir, speed, range, style = a, b, c, d, e
		if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(speed) ~= "number" then return end
		style = typeof(style) == "table" and style or {}
		local color = typeof(style.Color) == "Color3" and style.Color or Color3.new(1, 1, 1)
		local build = LOOKS[style.StandId] or defaultLook
		override = style.Skinned == true and color or nil
		local ok, part, look = pcall(build, style, color)
		override = nil
		if not ok then
			warn("[ProjectileFX]", part)
			return
		end
		part.CFrame = CFrame.lookAt(origin, origin + dir)
		part.Parent = folder
		playSfxAt("Projectile", origin, 0.6)
		local maxRange = typeof(range) == "number" and range or 60
		active[id] = {
			part = part, look = look, color = color,
			pos = origin, dir = dir.Unit, speed = speed,
			range = maxRange, traveled = 0, age = 0,
			homing = style.Homing == true,
			params = wallParams(),
			-- sécurité si le message de fin se perd
			expires = os.clock() + maxRange / math.max(speed, 1) + (style.Homing and 3 or 1),
		}
	elseif kind == "ProjectileSync" then
		local p = active[id]
		if p and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			-- tête chercheuse : on se recale doucement sur la position du serveur
			p.pos = p.pos:Lerp(a, 0.6)
			p.dir = b.Unit
		end
	elseif kind == "ProjectileEnd" then
		removeProjectile(id, typeof(a) == "Vector3" and a or nil)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for id, p in active do
		if now > p.expires then
			removeProjectile(id, nil)
			continue
		end
		p.age += dt
		local step = p.speed * dt
		if not p.homing then
			step = math.min(step, p.range - p.traveled)
		end
		if step > 0 then
			local result = workspace:Raycast(p.pos, p.dir * step, p.params)
			if result and result.Instance.CanCollide then
				removeProjectile(id, result.Position)
				continue
			end
			p.pos += p.dir * step
			p.traveled += step
		end
		-- orientation : avance + mouvement propre au look
		local look = p.look
		local cf = CFrame.lookAt(p.pos, p.pos + p.dir)
		if look.wobble then
			cf = cf * CFrame.new(math.sin(p.age * 18) * look.wobble, math.cos(p.age * 14) * look.wobble, 0)
		end
		if look.coin then
			-- pièce : tourne sur elle-même comme une pièce lancée
			cf = cf * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(p.age * look.coin, 0, 0)
		elseif look.tumble then
			cf = cf * CFrame.Angles(p.age * 9, p.age * 7, p.age * 5)
		elseif look.spin then
			cf = cf * CFrame.Angles(0, 0, p.age * look.spin)
		end
		p.part.CFrame = cf
	end
end)
