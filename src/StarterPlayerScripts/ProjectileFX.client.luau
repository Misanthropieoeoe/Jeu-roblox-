-- ProjectileFX. Affiche en local, de façon fluide, les projectiles des
-- attaques de Stand (couteaux, billes, émeraudes, flammes…).
-- Le serveur calcule seul la trajectoire et les dégâts (StandService, section
-- "Projectiles") et envoie :
--   "Projectile"    (id, départ, direction, vitesse, portée, style)
--   "ProjectileEnd" (id, position d'arrêt)
-- Le client fait avancer le projectile à la même vitesse et le détruit quand
-- le serveur annonce l'impact (ou contre un mur, pour ne pas le voir
-- traverser le décor en attendant le message du serveur).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")

local folder = Instance.new("Folder")
folder.Name = "LocalProjectiles"
folder.Parent = workspace

local active = {} -- [id] = projectile

local function makePart(style)
	local size = style.Size or 0.6
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = style.Color or Color3.new(1, 1, 1)
	if style.Shape == "Blade" then
		part.Size = Vector3.new(size * 0.4, size * 0.4, size * 3)
	else
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(size, size, size)
	end

	-- Traînée lumineuse
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.25, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.25, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(part.Color)
	trail.LightEmission = 1
	trail.Lifetime = 0.15
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 8
	light.Brightness = 2
	light.Parent = part
	return part
end

-- Les murs arrêtent le projectile visuellement ; les personnages et les
-- Stands non (c'est le serveur qui décide des touches).
local function wallParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	local spellFolder = workspace:FindFirstChild("StandSpellFX")
	if spellFolder then table.insert(ignore, spellFolder) end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function removeProjectile(id, endPos)
	local p = active[id]
	if not p then return end
	active[id] = nil
	local part = p.part
	if endPos then
		part.CFrame = CFrame.lookAt(endPos, endPos + p.dir)
	end
	-- petit éclat puis disparition
	part.Anchored = true
	TweenService:Create(part, TweenInfo.new(0.12), { Transparency = 1, Size = part.Size * 2 }):Play()
	Debris:AddItem(part, 0.2)
end

standFX.OnClientEvent:Connect(function(kind, id, a, b, c, d, e)
	if kind == "Projectile" then
		local origin, dir, speed, range, style = a, b, c, d, e
		if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(speed) ~= "number" then return end
		style = typeof(style) == "table" and style or {}
		local part = makePart(style)
		part.CFrame = CFrame.lookAt(origin, origin + dir)
		part.Parent = folder
		active[id] = {
			part = part,
			pos = origin,
			dir = dir.Unit,
			speed = speed,
			range = typeof(range) == "number" and range or 60,
			traveled = 0,
			params = wallParams(),
			-- sécurité si le message de fin se perd
			expires = os.clock() + (typeof(range) == "number" and range or 60) / math.max(speed, 1) + 1,
		}
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
		local step = math.min(p.speed * dt, p.range - p.traveled)
		if step <= 0 then
			-- portée atteinte : on attend le message du serveur (ou l'expiration)
			continue
		end
		local result = workspace:Raycast(p.pos, p.dir * step, p.params)
		if result and result.Instance.CanCollide then
			removeProjectile(id, result.Position)
			continue
		end
		p.pos += p.dir * step
		p.traveled += step
		p.part.CFrame = CFrame.lookAt(p.pos, p.pos + p.dir)
	end
end)
