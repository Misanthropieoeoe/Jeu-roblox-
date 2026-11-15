-- StandSkinModels. Les pièces de modèle des skins LÉGENDAIRES : couronnes,
-- halos, ailes, cornes, capes, épaulières, cristaux… construites en pièces
-- Roblox et soudées au squelette du Stand (R6 ou R15). Elles suivent donc
-- toutes ses animations, et apparaissent / disparaissent avec lui.
--
-- Chaque skin légendaire de StandSkins a un champ Model = "<nom>" qui
-- renvoie à une recette de ce fichier. Les tailles sont données pour un Stand
-- de taille normale (torse R6 de 2 studs de large) et s'adaptent à la taille
-- réelle du modèle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFX = require(ReplicatedStorage:WaitForChild("VFXTextures"))

local StandSkinModels = {}

local rad = math.rad
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Squelette -------------------------------------------------------------------
local ALIASES = {
	Torso = { "Torso", "UpperTorso" },
	Hips = { "LowerTorso", "Torso" },
	Head = { "Head" },
	RArm = { "Right Arm", "RightUpperArm" },
	LArm = { "Left Arm", "LeftUpperArm" },
	RHand = { "RightHand", "Right Arm" },
	LHand = { "LeftHand", "Left Arm" },
	RLeg = { "Right Leg", "RightUpperLeg" },
	LLeg = { "Left Leg", "LeftUpperLeg" },
}

local function findRig(model)
	local rig = {}
	for key, names in pairs(ALIASES) do
		for _, name in names do
			local p = model:FindFirstChild(name) or model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				rig[key] = p
				break
			end
		end
	end
	return rig
end

-- Constructeur ----------------------------------------------------------------
-- b:part(host, size, cframe, color, material, kind) : une pièce soudée à host.
-- size et la position de cframe sont multipliées par l'échelle du Stand.
local function newBuilder(model, rig)
	local folder = Instance.new("Folder")
	folder.Name = "LegendarySkin"
	folder.Parent = model
	local torso = rig.Torso
	local k = torso and (torso.Size.X / 2) or 1
	local b = { rig = rig, k = k, folder = folder }

	function b.part(host, size, cf, color, material, kind)
		if not host then return nil end
		local p
		if kind == "Wedge" then
			p = Instance.new("WedgePart")
		elseif kind == "CornerWedge" then
			p = Instance.new("CornerWedgePart")
		else
			p = Instance.new("Part")
			if kind == "Ball" then
				p.Shape = Enum.PartType.Ball
			elseif kind == "Cylinder" then
				p.Shape = Enum.PartType.Cylinder
			end
		end
		p.Name = "SkinPiece"
		p.Size = size * k
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = false
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local offset = CFrame.new(cf.Position * k) * cf.Rotation
		p.CFrame = host.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = host
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = folder
		return p
	end

	-- Pointe triangulaire (deux demi-coins dos à dos), pointe vers +Y de cf
	function b.spike(host, w, h, d, cf, color, material)
		b.part(host, Vector3.new(w, h, d / 2), cf * CFrame.new(0, 0, -d / 4), color, material, "Wedge")
		b.part(host, Vector3.new(w, h, d / 2), cf * CFrame.new(0, 0, d / 4) * CFrame.Angles(0, math.pi, 0),
			color, material, "Wedge")
	end

	-- Anneau de n segments dans le plan XY de cf (rayon r)
	function b.ring(host, cf, r, n, thick, depth, color, material)
		local seg = 2 * math.pi * r / n * 1.08
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			b.part(host, Vector3.new(seg, thick, depth), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0), color, material)
		end
	end

	-- Couronne de pointes autour de l'axe Y de cf (rayon r)
	function b.crown(host, cf, r, n, h, color, material, tilt)
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			local tall = (i == 0) and h * 1.5 or h
			b.spike(host, 0.06, tall, 0.32, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, tall / 2, -r)
				* CFrame.Angles(rad(tilt or -12), 0, 0) * CFrame.Angles(0, math.pi / 2, 0), color, material)
		end
		b.ring(host, cf * CFrame.Angles(rad(90), 0, 0), r, 14, 0.12, 0.1, color, material)
	end

	-- Aile de plumes, accrochée en haut du dos. side = 1 (droite) ou -1
	function b.wing(side, feathers, len, color, tipColor, material, sweep)
		local t = rig.Torso
		if not t then return end
		local back = t.Size.Z / 2 / k
		local root = CFrame.new(side * 0.35, 0.55, back + 0.12)
		for i = 1, feathers do
			local f = (i - 1) / math.max(feathers - 1, 1)
			local angle = 18 + f * 72
			local l = len * (0.55 + math.sin(f * math.pi) * 0.45 + (1 - f) * 0.25)
			local cf = root * CFrame.Angles(rad(sweep or 18), side * rad(-14), side * rad(-angle))
			b.part(t, Vector3.new(0.32, l, 0.06), cf * CFrame.new(0, l / 2, 0.02 * i), i % 2 == 0 and tipColor or color, material)
		end
	end

	-- Cape dans le dos
	function b.cape(color, inner, length)
		local t = rig.Torso
		if not t then return end
		local back = t.Size.Z / 2 / k
		local top = t.Size.Y / 2 / k - 0.05
		local L = length or 2.8
		b.part(t, Vector3.new(1.9, L, 0.06), CFrame.new(0, top, back + 0.05) * CFrame.Angles(rad(9), 0, 0)
			* CFrame.new(0, -L / 2, 0), color, Enum.Material.Fabric)
		b.part(t, Vector3.new(1.75, L - 0.1, 0.04), CFrame.new(0, top, back + 0.01) * CFrame.Angles(rad(9), 0, 0)
			* CFrame.new(0, -L / 2, 0), inner, Enum.Material.Fabric)
		b.part(t, Vector3.new(2.1, 0.2, 0.3), CFrame.new(0, top, back - 0.02), inner, Enum.Material.Metal)
	end

	-- Épaulière sur un bras (side 1 = droit), avec pointes facultatives
	function b.pauldron(side, color, trim, spikes, size)
		local arm = side == 1 and rig.RArm or rig.LArm
		if not arm then return end
		local s = size or 1
		local top = arm.Size.Y / 2 / k
		b.part(arm, Vector3.new(1.35, 0.42, 1.35) * s, CFrame.new(side * 0.1, top - 0.05, 0) * CFrame.Angles(0, 0, side * rad(-14)),
			color, Enum.Material.Metal)
		b.part(arm, Vector3.new(1.45, 0.12, 1.45) * s, CFrame.new(side * 0.12, top - 0.3, 0) * CFrame.Angles(0, 0, side * rad(-14)),
			trim, Enum.Material.Metal)
		for i = 1, spikes or 0 do
			local z = (i - (spikes + 1) / 2) * 0.42
			b.spike(arm, 0.08, 0.55 * s, 0.3, CFrame.new(side * 0.35, top + 0.35 * s, z) * CFrame.Angles(0, 0, side * rad(-30))
				* CFrame.Angles(0, math.pi / 2, 0), trim, Enum.Material.Metal)
		end
	end

	-- Corne courbée en 4 segments sur la tête
	function b.horn(side, color, length, curl)
		local h = rig.Head
		if not h then return end
		local top = h.Size.Y / 2 / k
		local cf = CFrame.new(side * 0.32, top - 0.05, -0.05) * CFrame.Angles(rad(-15), 0, side * rad(-30))
		local L = length or 0.5
		for i = 1, 4 do
			local w = 0.26 - i * 0.045
			b.part(h, Vector3.new(w, L, w), cf * CFrame.new(0, L / 2, 0), color, Enum.Material.Slate)
			cf = cf * CFrame.new(0, L, 0) * CFrame.Angles(rad(curl or 22), 0, side * rad(-8))
		end
	end

	-- Halo au-dessus de la tête
	function b.halo(color, r, height)
		local h = rig.Head
		if not h then return end
		local top = h.Size.Y / 2 / k
		b.ring(h, CFrame.new(0, top + (height or 0.55), 0.1) * CFrame.Angles(rad(90 - 12), 0, 0), r or 0.6, 16, 0.09, 0.09,
			color, Enum.Material.Neon)
	end

	-- Grand cercle dans le dos (cadran, roue)
	function b.backRing(color, r, ticks, tickColor, depth)
		local t = rig.Torso
		if not t then return end
		local back = t.Size.Z / 2 / k + (depth or 0.7)
		local cf = CFrame.new(0, 0.55, back)
		b.ring(t, cf, r, 28, 0.12, 0.08, color, Enum.Material.Metal)
		for i = 0, (ticks or 0) - 1 do
			local a = 2 * math.pi * i / ticks
			local big = i % 3 == 0
			b.part(t, Vector3.new(0.09, big and 0.45 or 0.25, 0.06), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r - (big and 0.3 or 0.2), 0),
				tickColor or color, big and Enum.Material.Neon or Enum.Material.Metal)
		end
		return cf
	end

	-- Cristal (cube tourné en losange)
	function b.gem(host, size, cf, color, material)
		return b.part(host, Vector3.new(size, size * 1.6, size), cf * CFrame.Angles(rad(45), rad(30), rad(45)), color,
			material or Enum.Material.Glass)
	end

	-- Emblème brillant sur la poitrine
	function b.emblem(color, size, shape)
		local t = rig.Torso
		if not t then return end
		local front = -t.Size.Z / 2 / k - 0.04
		if shape == "star" then
			for i = 0, 4 do
				b.spike(t, 0.05, 0.42 * (size or 1), 0.22 * (size or 1),
					CFrame.new(0, 0.35, front) * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, 0.18 * (size or 1), 0)
						* CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Neon)
			end
		else
			b.gem(t, 0.3 * (size or 1), CFrame.new(0, 0.35, front - 0.05), color, Enum.Material.Neon)
		end
	end

	-- Griffes / pointes sur une main
	function b.claws(side, color, n, len)
		local hand = side == 1 and rig.RHand or rig.LHand
		if not hand then return end
		local bottom = (hand.Name:find("Hand") and 0 or -hand.Size.Y / 2 / k)
		for i = 1, n or 3 do
			local x = (i - ((n or 3) + 1) / 2) * 0.28
			b.spike(hand, 0.06, len or 0.6, 0.18, CFrame.new(x, bottom - (len or 0.6) / 2 + 0.05, -0.2)
				* CFrame.Angles(rad(180 - 15), 0, 0) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Metal)
		end
	end

	-- Bracelet autour d'un bras
	function b.bracer(side, color, trim)
		local hand = side == 1 and rig.RHand or rig.LHand
		local arm = side == 1 and rig.RArm or rig.LArm
		local host = (hand and hand ~= arm) and hand or arm
		if not host then return end
		local y = host == arm and (-arm.Size.Y / 2 / k + 0.55) or 0.25
		local w = host.Size.X / k + 0.12
		b.part(host, Vector3.new(w, 0.45, host.Size.Z / k + 0.12), CFrame.new(0, y, 0), color, Enum.Material.Metal)
		b.part(host, Vector3.new(w + 0.05, 0.08, host.Size.Z / k + 0.17), CFrame.new(0, y + 0.18, 0), trim, Enum.Material.Neon)
	end

	-- Particules discrètes (peu lumineuses)
	function b.sparkle(host, texture, color, rate, size, speed)
		if not host then return end
		local e = Instance.new("ParticleEmitter")
		e.Name = "SkinSparkle"
		e.Texture = texture
		e.Color = ColorSequence.new(color)
		e.Rate = rate or 6
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.4, speed or 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (size or 0.35) * k), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.25, 1)
		e.LightEmission = 0.3
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Parent = host
		return e
	end

	return b
end

-- Recettes ---------------------------------------------------------------------
local M = Enum.Material
local R = {}

-- Star Platinum : Étoile Souveraine
R.EtoileSouveraine = function(b)
	local rig, navy, silver, star = b.rig, rgb(28, 40, 96), rgb(205, 214, 235), rgb(255, 222, 120)
	b.crown(rig.Head, CFrame.new(0, rig.Head.Size.Y / 2 / b.k - 0.12, 0), 0.5, 5, 0.42, silver, M.Metal, -18)
	b.gem(rig.Head, 0.16, CFrame.new(0, rig.Head.Size.Y / 2 / b.k + 0.05, -0.5), star, M.Neon)
	b.pauldron(1, navy, silver, 3)
	b.pauldron(-1, navy, silver, 3)
	b.emblem(star, 1.1, "star")
	b.cape(navy, rgb(70, 60, 150), 2.9)
	b.bracer(1, navy, star)
	b.bracer(-1, navy, star)
	b.sparkle(rig.Torso, VFX.Star, star, 5, 0.35)
end

-- The World : Monarque du Zénith
R.MonarqueZenith = function(b)
	local rig, gold, ivory, green = b.rig, rgb(232, 182, 64), rgb(250, 242, 220), rgb(60, 170, 110)
	b.backRing(gold, 1.75, 12, ivory, 0.75)
	b.crown(rig.Head, CFrame.new(0, rig.Head.Size.Y / 2 / b.k - 0.12, 0), 0.5, 7, 0.36, gold, M.Metal, -10)
	b.pauldron(1, gold, green, 2, 1.1)
	b.pauldron(-1, gold, green, 2, 1.1)
	b.emblem(green, 1.2)
	b.bracer(1, gold, green)
	b.bracer(-1, gold, green)
	b.sparkle(rig.Torso, VFX.Glow, gold, 4, 0.4)
end

-- The World AU : Bête des Abysses
R.BeteAbysses = function(b)
	local rig, bone, black, red = b.rig, rgb(222, 210, 190), rgb(24, 20, 24), rgb(200, 30, 40)
	b.horn(1, bone, 0.42, 26)
	b.horn(-1, bone, 0.42, 26)
	local t = rig.Torso
	if t then
		local back = t.Size.Z / 2 / b.k
		for i = 0, 4 do
			b.spike(t, 0.07, 0.55 - i * 0.06, 0.4, CFrame.new(0, 0.85 - i * 0.42, back + 0.1) * CFrame.Angles(rad(-75), 0, 0)
				* CFrame.Angles(0, math.pi / 2, 0), black, M.Slate)
		end
	end
	b.claws(1, bone, 3, 0.7)
	b.claws(-1, bone, 3, 0.7)
	b.pauldron(1, black, red, 3, 0.9)
	b.pauldron(-1, black, red, 3, 0.9)
	b.emblem(red, 1)
	b.sparkle(rig.Torso, VFX.Smoke, rgb(70, 10, 20), 6, 0.6, 0.8)
end

-- Crazy Diamond : Cœur de Cristal
R.CoeurCristal = function(b)
	local rig, pink, cyan, white = b.rig, rgb(255, 150, 210), rgb(140, 230, 255), rgb(245, 250, 255)
	for _, side in { 1, -1 } do
		local arm = side == 1 and rig.RArm or rig.LArm
		if arm then
			local top = arm.Size.Y / 2 / b.k
			b.gem(arm, 0.42, CFrame.new(side * 0.35, top + 0.25, 0), cyan)
			b.gem(arm, 0.28, CFrame.new(side * 0.45, top + 0.05, 0.35), pink)
			b.gem(arm, 0.24, CFrame.new(side * 0.4, top + 0.1, -0.35), white)
		end
	end
	local t = rig.Torso
	if t then
		-- cristaux en lévitation autour du torse
		for i = 0, 5 do
			local a = i * math.pi / 3
			b.gem(t, 0.22, CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3 + (i % 2) * 0.5, -1.9), i % 2 == 0 and pink or cyan)
		end
	end
	b.crown(rig.Head, CFrame.new(0, rig.Head.Size.Y / 2 / b.k - 0.1, 0), 0.48, 6, 0.3, cyan, M.Glass, -6)
	b.emblem(pink, 1.2)
	b.sparkle(rig.Torso, VFX.Shard, cyan, 6, 0.3)
end

-- Silver Chariot : Paladin Céleste
R.PaladinCeleste = function(b)
	local rig, silver, blue, gold = b.rig, rgb(215, 222, 235), rgb(40, 70, 160), rgb(240, 200, 90)
	local h = rig.Head
	if h then
		local top = h.Size.Y / 2 / b.k
		-- crête de plumes sur le casque
		for i = 0, 6 do
			b.part(h, Vector3.new(0.08, 0.5 - math.abs(i - 3) * 0.06, 0.2), CFrame.new(0, top + 0.18, 0.35 - i * 0.12)
				* CFrame.Angles(rad(-20 + i * 9), 0, 0), i % 2 == 0 and blue or rgb(230, 235, 255), M.Fabric)
		end
		b.part(h, Vector3.new(1.15, 0.12, 0.12), CFrame.new(0, 0.05, -0.55), gold, M.Metal)
	end
	b.pauldron(1, silver, gold, 0, 1.2)
	b.pauldron(-1, silver, gold, 0, 1.2)
	b.cape(blue, rgb(230, 235, 255), 3)
	b.wing(1, 5, 1.1, rgb(240, 244, 255), rgb(200, 215, 240), M.SmoothPlastic, 30)
	b.wing(-1, 5, 1.1, rgb(240, 244, 255), rgb(200, 215, 240), M.SmoothPlastic, 30)
	b.emblem(gold, 1)
	b.sparkle(rig.Torso, VFX.Spark, rgb(220, 230, 255), 4, 0.3)
end

-- Killer Queen : Reine Détonante
R.ReineDetonante = function(b)
	local rig, pink, black, gold = b.rig, rgb(240, 120, 180), rgb(30, 26, 34), rgb(240, 200, 100)
	local h = rig.Head
	if h then
		local top = h.Size.Y / 2 / b.k
		for _, side in { 1, -1 } do
			b.spike(h, 0.08, 0.55, 0.42, CFrame.new(side * 0.36, top + 0.18, 0) * CFrame.Angles(0, 0, side * rad(-18))
				* CFrame.Angles(0, math.pi / 2, 0), black, M.SmoothPlastic)
			b.spike(h, 0.09, 0.32, 0.24, CFrame.new(side * 0.35, top + 0.1, -0.05) * CFrame.Angles(0, 0, side * rad(-18))
				* CFrame.Angles(0, math.pi / 2, 0), pink, M.SmoothPlastic)
		end
		b.ring(h, CFrame.new(0, top - 0.05, 0) * CFrame.Angles(rad(90), 0, 0), 0.5, 14, 0.08, 0.1, gold, M.Metal)
		b.gem(h, 0.14, CFrame.new(0, top + 0.02, -0.52), pink, M.Neon)
	end
	local t = rig.Torso
	if t then
		-- bombes en orbite
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			local orb = b.part(t, Vector3.new(0.45, 0.45, 0.45), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.4, -1.8), black, M.SmoothPlastic, "Ball")
			if orb then
				b.part(t, Vector3.new(0.1, 0.18, 0.1), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, -1.8), gold, M.Neon)
			end
		end
	end
	b.bracer(1, black, pink)
	b.bracer(-1, black, pink)
	b.emblem(pink, 1)
	b.sparkle(rig.Torso, VFX.Spark, pink, 5, 0.3)
end

-- Gold Experience : Arbre de Vie
R.ArbreVie = function(b)
	local rig, leaf, leaf2, gold = b.rig, rgb(70, 170, 80), rgb(140, 210, 90), rgb(250, 210, 90)
	b.wing(1, 7, 1.25, leaf, leaf2, M.Grass, 10)
	b.wing(-1, 7, 1.25, leaf, leaf2, M.Grass, 10)
	local h = rig.Head
	if h then
		local top = h.Size.Y / 2 / b.k
		b.ring(h, CFrame.new(0, top - 0.08, 0) * CFrame.Angles(rad(90), 0, 0), 0.5, 12, 0.1, 0.1, rgb(110, 80, 40), M.Wood)
		for i = 0, 5 do
			local a = i * math.pi / 3
			b.part(h, Vector3.new(0.28, 0.05, 0.16), CFrame.Angles(0, a, 0) * CFrame.new(0, top + 0.02, -0.52) * CFrame.Angles(rad(-35), 0, 0),
				i % 2 == 0 and leaf or leaf2, M.Grass)
		end
	end
	local t = rig.Torso
	if t then
		local front = -t.Size.Z / 2 / b.k - 0.05
		for i = 0, 4 do
			b.part(t, Vector3.new(0.2, 0.32, 0.05), CFrame.new(0, 0.35, front) * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, 0.16, 0),
				rgb(255, 240, 150), M.SmoothPlastic)
		end
		b.part(t, Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.35, front - 0.04), gold, M.Neon, "Ball")
	end
	b.sparkle(rig.Torso, VFX.Petal, rgb(255, 230, 140), 6, 0.35)
end

-- Gold Experience Requiem : Arbitre Éternel
R.ArbitreEternel = function(b)
	local rig, white, gold, sky = b.rig, rgb(250, 250, 245), rgb(245, 200, 80), rgb(200, 220, 255)
	b.halo(gold, 0.62, 0.55)
	b.wing(1, 7, 1.5, white, sky, M.SmoothPlastic, 15)
	b.wing(-1, 7, 1.5, white, sky, M.SmoothPlastic, 15)
	-- deuxième paire, plus basse
	local t = rig.Torso
	if t then
		local back = t.Size.Z / 2 / b.k
		for _, side in { 1, -1 } do
			for i = 1, 4 do
				local l = 0.8 + i * 0.12
				b.part(t, Vector3.new(0.26, l, 0.05), CFrame.new(side * 0.3, -0.2, back + 0.1) * CFrame.Angles(rad(20), 0, side * rad(-(95 + i * 14)))
					* CFrame.new(0, l / 2, 0), i % 2 == 0 and white or sky, M.SmoothPlastic)
			end
		end
	end
	b.pauldron(1, white, gold, 0, 1.1)
	b.pauldron(-1, white, gold, 0, 1.1)
	b.emblem(gold, 1.2)
	b.sparkle(rig.Torso, VFX.Glow, gold, 5, 0.4)
end

-- King Crimson : Empereur Écarlate
R.EmpereurEcarlate = function(b)
	local rig, crimson, black, gold = b.rig, rgb(170, 20, 40), rgb(30, 18, 22), rgb(240, 190, 80)
	b.crown(rig.Head, CFrame.new(0, rig.Head.Size.Y / 2 / b.k - 0.12, 0), 0.5, 3, 0.5, black, M.Slate, -25)
	b.horn(1, black, 0.36, 30)
	b.horn(-1, black, 0.36, 30)
	b.cape(crimson, black, 3.1)
	b.pauldron(1, black, gold, 2)
	b.pauldron(-1, black, gold, 2)
	local t = rig.Torso
	if t then
		-- œil d'Épitaphe sur la poitrine
		local front = -t.Size.Z / 2 / b.k - 0.05
		b.part(t, Vector3.new(0.6, 0.26, 0.05), CFrame.new(0, 0.35, front), gold, M.Metal)
		b.part(t, Vector3.new(0.18, 0.18, 0.05), CFrame.new(0, 0.35, front - 0.03), rgb(60, 220, 120), M.Neon, "Ball")
	end
	b.claws(1, gold, 3, 0.45)
	b.claws(-1, gold, 3, 0.45)
	b.sparkle(rig.Torso, VFX.Smoke, rgb(120, 10, 30), 6, 0.55, 0.9)
end

-- Hierophant Green : Gardien d'Émeraude
R.GardienEmeraude = function(b)
	local rig, green, light, gold = b.rig, rgb(40, 160, 90), rgb(120, 240, 170), rgb(240, 210, 110)
	local t = rig.Torso
	if t then
		local back = t.Size.Z / 2 / b.k
		-- quatre rubans de tentacules dans le dos
		for r = 0, 3 do
			local side = r % 2 == 0 and 1 or -1
			local cf = CFrame.new(side * (0.3 + math.floor(r / 2) * 0.25), 0.4 - math.floor(r / 2) * 0.5, back + 0.05)
				* CFrame.Angles(rad(35), 0, side * rad(-40 - r * 8))
			for i = 1, 6 do
				local w = 0.22 - i * 0.025
				b.part(t, Vector3.new(w, 0.32, w), cf * CFrame.new(0, 0.16, 0), i % 2 == 0 and light or green, M.Glass, "Ball")
				cf = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(rad(10), 0, side * rad(-10))
			end
			b.gem(t, 0.14, cf, gold, M.Neon)
		end
	end
	local h = rig.Head
	if h then
		local top = h.Size.Y / 2 / b.k
		b.gem(h, 0.22, CFrame.new(0, top + 0.12, -0.25), light)
		b.gem(h, 0.14, CFrame.new(0.3, top, -0.2), gold, M.Neon)
		b.gem(h, 0.14, CFrame.new(-0.3, top, -0.2), gold, M.Neon)
	end
	b.bracer(1, green, light)
	b.bracer(-1, green, light)
	b.sparkle(rig.Torso, VFX.Gem, light, 6, 0.3)
end

-- Magician's Red : Phénix Infernal
R.PhenixInfernal = function(b)
	local rig, flame, ember, gold = b.rig, rgb(255, 110, 30), rgb(255, 200, 70), rgb(150, 30, 20)
	b.wing(1, 7, 1.45, flame, ember, M.Neon, 22)
	b.wing(-1, 7, 1.45, flame, ember, M.Neon, 22)
	local h = rig.Head
	if h then
		local top = h.Size.Y / 2 / b.k
		for i = 0, 4 do
			b.part(h, Vector3.new(0.09, 0.6 - math.abs(i - 2) * 0.1, 0.16), CFrame.new(0, top + 0.2, 0.25 - i * 0.12)
				* CFrame.Angles(rad(-35 + i * 12), 0, 0), i % 2 == 0 and flame or ember, M.Neon)
		end
	end
	b.pauldron(1, gold, ember, 2)
	b.pauldron(-1, gold, ember, 2)
	b.emblem(ember, 1.1)
	local fire = b.sparkle(rig.Torso, VFX.Flame, flame, 9, 0.55, 1.6)
	if fire then fire.Acceleration = Vector3.new(0, 3, 0) end
end

-- Sticky Fingers : Fermeture Céleste
R.FermetureCeleste = function(b)
	local rig, white, blue, gold = b.rig, rgb(240, 242, 250), rgb(50, 90, 200), rgb(245, 205, 90)
	local h = rig.Head
	if h then
		-- halo fait de dents de fermeture éclair
		local top = h.Size.Y / 2 / b.k
		local cf = CFrame.new(0, top + 0.5, 0.1) * CFrame.Angles(rad(78), 0, 0)
		for i = 0, 17 do
			local a = 2 * math.pi * i / 18
			b.part(h, Vector3.new(0.16, 0.1, 0.12), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.6 + (i % 2) * 0.06, 0), gold, M.Metal)
		end
	end
	-- fermetures éclair le long des bras et du torse
	for _, key in { "RArm", "LArm", "Torso" } do
		local p = rig[key]
		if p then
			local front = -p.Size.Z / 2 / b.k - 0.02
			local n = 6
			for i = 0, n - 1 do
				local y = p.Size.Y / 2 / b.k - 0.15 - i * (p.Size.Y / b.k - 0.3) / (n - 1)
				b.part(p, Vector3.new(0.18, 0.08, 0.05), CFrame.new((i % 2 == 0) and 0.05 or -0.05, y, front), gold, M.Metal)
			end
			b.part(p, Vector3.new(0.16, 0.24, 0.06), CFrame.new(0, p.Size.Y / 2 / b.k - 0.1, front - 0.03), white, M.Metal)
		end
	end
	b.pauldron(1, blue, gold, 0, 1.05)
	b.pauldron(-1, blue, gold, 0, 1.05)
	b.cape(blue, white, 2.7)
	b.sparkle(rig.Torso, VFX.Zipper, gold, 4, 0.35)
end

-- Made in Heaven : Horizon Infini
R.HorizonInfini = function(b)
	local rig, white, sky, gold = b.rig, rgb(245, 245, 255), rgb(130, 170, 255), rgb(245, 210, 110)
	local cf = b.backRing(gold, 1.6, 12, white, 0.8)
	local t = rig.Torso
	if t and cf then
		-- deux anneaux d'orbite inclinés
		b.ring(t, cf * CFrame.Angles(rad(60), 0, rad(25)), 2.1, 30, 0.07, 0.07, sky, M.Neon)
		b.ring(t, cf * CFrame.Angles(rad(-60), 0, rad(-25)), 2.1, 30, 0.07, 0.07, white, M.Glass)
		-- aiguilles du cadran
		b.part(t, Vector3.new(0.1, 1.2, 0.05), cf * CFrame.Angles(0, 0, rad(-40)) * CFrame.new(0, 0.55, -0.05), white, M.Metal)
		b.part(t, Vector3.new(0.12, 0.8, 0.05), cf * CFrame.Angles(0, 0, rad(70)) * CFrame.new(0, 0.38, -0.05), gold, M.Metal)
	end
	b.halo(sky, 0.5, 0.45)
	b.bracer(1, white, sky)
	b.bracer(-1, white, sky)
	b.emblem(sky, 1, "star")
	b.sparkle(rig.Torso, VFX.Star, white, 6, 0.3)
end

-- The World AU : Arpenteur du Néant (MYTHIQUE) — design original : un
-- voyageur venu d'une faille entre les mondes. Faille ovale dans le dos,
-- couronne en croissant, visière lumineuse, éclats en orbite, anneau de
-- lévitation à la taille, cape en lambeaux et veines d'énergie.
R.ArpenteurNeant = function(b)
	local rig = b.rig
	local obsidian, void, cyan, silver = rgb(18, 14, 30), rgb(140, 70, 255), rgb(90, 230, 255), rgb(190, 190, 215)
	local t, h = rig.Torso, rig.Head
	local back = t.Size.Z / 2 / b.k
	local front = -t.Size.Z / 2 / b.k

	-- faille ovale dans le dos : deux anneaux étirés + éclats à l'intérieur
	local riftCF = CFrame.new(0, 0.5, back + 0.85)
	for i = 0, 31 do
		local a = 2 * math.pi * i / 32
		local pos = Vector3.new(math.cos(a) * 1.35, math.sin(a) * 2.1, 0)
		local tangent = math.atan2(math.cos(a) * 2.1, -math.sin(a) * 1.35)
		b.part(t, Vector3.new(0.34, 0.1, 0.08), riftCF * CFrame.new(pos) * CFrame.Angles(0, 0, tangent),
			i % 4 == 0 and cyan or void, M.Neon)
		b.part(t, Vector3.new(0.3, 0.06, 0.05), riftCF * CFrame.new(pos * 0.82 + Vector3.new(0, 0, 0.05)) * CFrame.Angles(0, 0, tangent),
			obsidian, M.Glass)
	end
	for i = 0, 5 do
		b.gem(t, 0.16 + (i % 3) * 0.05, riftCF * CFrame.new((i % 3 - 1) * 0.45, (math.floor(i / 3) - 0.5) * 1.4, 0.05),
			i % 2 == 0 and void or cyan, M.Glass)
	end

	-- couronne en croissant : deux longues cornes qui se recourbent vers le haut
	b.horn(1, obsidian, 0.5, -14)
	b.horn(-1, obsidian, 0.5, -14)
	local top = h.Size.Y / 2 / b.k
	b.part(h, Vector3.new(0.9, 0.12, 0.12), CFrame.new(0, top - 0.02, -0.38) * CFrame.Angles(rad(-10), 0, 0), silver, M.Metal)
	b.gem(h, 0.18, CFrame.new(0, top + 0.12, -0.42), cyan, M.Neon)
	-- visière lumineuse
	b.part(h, Vector3.new(0.86, 0.08, 0.05), CFrame.new(0, 0.08, -h.Size.Z / 2 / b.k - 0.03), cyan, M.Neon)
	b.part(h, Vector3.new(0.96, 0.22, 0.04), CFrame.new(0, 0.08, -h.Size.Z / 2 / b.k - 0.01), obsidian, M.Metal)

	-- épaulières superposées
	b.pauldron(1, obsidian, void, 3, 1.15)
	b.pauldron(-1, obsidian, void, 3, 1.15)

	-- veines d'énergie le long des bras et du torse
	for _, key in { "RArm", "LArm" } do
		local p = rig[key]
		if p then
			local f = -p.Size.Z / 2 / b.k - 0.02
			b.part(p, Vector3.new(0.06, p.Size.Y / b.k * 0.8, 0.04), CFrame.new(0, 0, f), void, M.Neon)
			b.part(p, Vector3.new(0.04, p.Size.Y / b.k * 0.5, 0.04), CFrame.new(0.15, -0.1, f) * CFrame.Angles(0, 0, rad(12)), cyan, M.Neon)
		end
	end
	b.part(t, Vector3.new(0.07, 1.2, 0.04), CFrame.new(-0.22, 0.05, front - 0.03) * CFrame.Angles(0, 0, rad(-18)), void, M.Neon)
	b.part(t, Vector3.new(0.07, 1.2, 0.04), CFrame.new(0.22, 0.05, front - 0.03) * CFrame.Angles(0, 0, rad(18)), void, M.Neon)
	b.gem(t, 0.26, CFrame.new(0, 0.45, front - 0.08), cyan, M.Neon)
	b.bracer(1, obsidian, cyan)
	b.bracer(-1, obsidian, cyan)
	b.claws(1, silver, 2, 0.75)
	b.claws(-1, silver, 2, 0.75)

	-- éclats en orbite autour du torse
	for i = 0, 7 do
		local a = i * math.pi / 4
		b.gem(t, 0.2 + (i % 2) * 0.08, CFrame.Angles(0, a, 0) * CFrame.new(0, -0.3 + (i % 3) * 0.55, -2.25),
			i % 2 == 0 and void or cyan, M.Glass)
	end

	-- anneau de lévitation à la taille
	local hips = rig.Hips or t
	b.ring(hips, CFrame.new(0, -0.35, 0) * CFrame.Angles(rad(90), 0, 0), 1.25, 24, 0.07, 0.07, void, M.Neon)

	-- cape en lambeaux (bandes de longueurs différentes)
	for i = -2, 2 do
		local L = 2.4 - math.abs(i) * 0.35 + (i % 2) * 0.25
		b.part(t, Vector3.new(0.34, L, 0.05), CFrame.new(i * 0.36, t.Size.Y / 2 / b.k - 0.05, back + 0.08)
			* CFrame.Angles(rad(8 + math.abs(i) * 3), 0, rad(i * 3)) * CFrame.new(0, -L / 2, 0), obsidian, M.Fabric)
	end

	b.sparkle(t, VFX.Shard, void, 6, 0.32)
	b.sparkle(t, VFX.Smoke, rgb(40, 20, 80), 5, 0.6, 0.7)
end

-- API ------------------------------------------------------------------------------
function StandSkinModels.Has(name)
	return R[name] ~= nil
end

function StandSkinModels.Build(model, name)
	local recipe = R[name]
	if not recipe then
		warn("[StandSkinModels] Recette inconnue :", tostring(name))
		return
	end
	local rig = findRig(model)
	if not rig.Torso or not rig.Head then
		warn("[StandSkinModels] Squelette introuvable pour", model.Name)
		return
	end
	local ok, err = pcall(recipe, newBuilder(model, rig))
	if not ok then
		warn("[StandSkinModels] " .. name .. " :", err)
	end
end

return StandSkinModels
