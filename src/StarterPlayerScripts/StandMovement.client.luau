-- StandMovement (client). Capacité de déplacement du Stand équipé sur Z
-- (bouton B à la manette) + vol plané passif. Les profils sont dans
-- ReplicatedStorage.StandMovement ; le serveur valide la recharge puis
-- renvoie "Mobility" : c'est alors ici qu'on déplace le personnage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandMovement = require(ReplicatedStorage:WaitForChild("StandMovement"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local standAction = remotes:WaitForChild("StandAction")
local standFX = remotes:WaitForChild("StandFX")

-- Réglages -----------------------------------------------------------------
local MOBILITY_KEYS = {
	[Enum.KeyCode.Z] = true,
	[Enum.KeyCode.ButtonB] = true, -- manette
}
local RECALL_HISTORY = 5 -- secondes de positions gardées (Recall)
------------------------------------------------------------------------------

local player = Players.LocalPlayer

local function profile()
	local standId = player:GetAttribute("StandId") or StandData.DefaultStand
	return StandMovement.Get(standId), standId
end

local function parts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return nil end
	return character, root, humanoid
end

local function worldParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { character }
	for _, name in ipairs({ "StandSpellFX", "LocalProjectiles" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(ignore, folder) end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

-- Direction : là où le joueur se déplace, sinon devant lui
local function moveDirection(root, humanoid)
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	return dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
end

-- Point visé (souris, ou centre de l'écran)
local function aimRay()
	local camera = workspace.CurrentCamera
	local x, y
	if UserInputService.MouseEnabled and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		local mouse = UserInputService:GetMouseLocation()
		x, y = mouse.X, mouse.Y
	else
		x, y = camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
	end
	return camera:ViewportPointToRay(x, y)
end

-- Garde la vitesse donnée pendant `duration` (la physique la freinerait sinon)
local function holdVelocity(root, duration, getVelocity)
	local endsAt = os.clock() + duration
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or os.clock() >= endsAt then
			connection:Disconnect()
			return
		end
		root.AssemblyLinearVelocity = getVelocity()
	end)
end

-- Est-ce que le personnage tient à cet endroit sans être dans un mur ?
local function isFree(character, cframe)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	return #workspace:GetPartBoundsInBox(cframe, Vector3.new(2, 4.5, 1.2), params) == 0
end

local function teleportTo(character, root, position)
	local look = root.CFrame.LookVector
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- ─── Historique des positions (Recall) ─────────────────────────────────────
local history = {}
local historyAccum = 0
RunService.Heartbeat:Connect(function(dt)
	historyAccum += dt
	if historyAccum < 0.1 then return end
	historyAccum = 0
	local _, root = parts()
	if not root then return end
	table.insert(history, { t = os.clock(), cf = root.CFrame })
	while #history > 0 and os.clock() - history[1].t > RECALL_HISTORY do
		table.remove(history, 1)
	end
end)
player.CharacterAdded:Connect(function()
	table.clear(history)
end)

-- ─── Les capacités ─────────────────────────────────────────────────────────
local grappleTarget = nil -- point choisi au moment de l'appui (Grapple)

local MOVES = {}

function MOVES.Leap(p, character, root, humanoid)
	local dir = moveDirection(root, humanoid)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	task.defer(function()
		if root.Parent then
			root.AssemblyLinearVelocity = dir * (p.Forward or 60) + Vector3.new(0, p.Up or 50, 0)
		end
	end)
end

function MOVES.AirDash(p, character, root, humanoid)
	local dir = moveDirection(root, humanoid)
	local speed = p.Speed or 100
	holdVelocity(root, p.Time or 0.2, function()
		return dir * speed + Vector3.new(0, 2, 0)
	end)
	task.delay(p.Time or 0.2, function()
		if root.Parent then
			root.AssemblyLinearVelocity = dir * 20 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end)
end

function MOVES.Blink(p, character, root, humanoid)
	local dir = moveDirection(root, humanoid)
	local distance = p.Distance or 20
	local result = workspace:Raycast(root.Position, dir * distance, worldParams(character))
	local travel = result and math.max(result.Distance - 2, 0) or distance
	teleportTo(character, root, root.Position + dir * travel)
end

function MOVES.Phase(p, character, root, humanoid)
	-- Traverse les murs : on cherche le point libre le plus loin possible
	local dir = moveDirection(root, humanoid)
	local start = root.Position
	for travel = p.Distance or 20, 2, -2 do
		local pos = start + dir * travel
		local look = root.CFrame.LookVector
		if isFree(character, CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z))) then
			teleportTo(character, root, pos)
			return
		end
	end
end

function MOVES.Recall(p, character, root, humanoid)
	local wanted = os.clock() - (p.Seconds or 2.5)
	local best = history[1]
	for _, entry in ipairs(history) do
		if entry.t <= wanted then best = entry else break end
	end
	if best then
		character:PivotTo(best.cf)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function MOVES.Grapple(p, character, root, humanoid)
	local target = grappleTarget
	grappleTarget = nil
	if not target then return end
	-- Câble visible
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = target
	anchor.Parent = workspace
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 0.3, 0.3
	beam.FaceCamera = true
	beam.LightEmission = 1
	local def = StandData.GetStand(player:GetAttribute("StandId") or "")
	local color = p.Color or (def and def.Theme and def.Theme.Aura1) or Color3.fromRGB(110, 255, 140)
	beam.Color = ColorSequence.new(color)
	beam.Parent = anchor

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local endsAt = os.clock() + 1.5
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local to = target - root.Position
		local done = not root.Parent or os.clock() >= endsAt or to.Magnitude < 4
			or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		if done then
			connection:Disconnect()
			a0:Destroy()
			anchor:Destroy()
			if root.Parent then
				-- petit élan vers le haut en lâchant le câble
				root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.5 + Vector3.new(0, 25, 0)
			end
			return
		end
		root.AssemblyLinearVelocity = to.Unit * (p.Speed or 90)
	end)
end

function MOVES.Hover(p, character, root, humanoid)
	local rise = p.RiseTime or 0.6
	local started = os.clock()
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	holdVelocity(root, p.Duration or 2.5, function()
		local v = root.AssemblyLinearVelocity
		local up = (os.clock() - started < rise) and (p.Lift or 14) or 0
		return Vector3.new(v.X, up, v.Z)
	end)
end

function MOVES.Jet(p, character, root, humanoid)
	local dir = moveDirection(root, humanoid)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	holdVelocity(root, p.Time or 0.5, function()
		return dir * (p.Forward or 50) + Vector3.new(0, p.Up or 40, 0)
	end)
end

-- ─── Déclenchement ─────────────────────────────────────────────────────────
local function tryMobility()
	if player:GetAttribute("Standless") or player:GetAttribute("Blocking") then return end
	local p = profile()
	if not p.Type then return end
	local character, root = parts()
	if not character then return end
	if p.Type == "Grapple" then
		-- il faut un point d'accroche à portée, sinon on n'utilise pas la charge
		local ray = aimRay()
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, worldParams(character))
		if not result or (result.Position - root.Position).Magnitude > (p.Range or 60) then return end
		grappleTarget = result.Position
	end
	standAction:FireServer("Mobility")
end
_G.StandMobility = tryMobility -- utilisé par la case Z de SpellBar

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not MOBILITY_KEYS[input.KeyCode] then return end
	tryMobility()
end)

standFX.OnClientEvent:Connect(function(kind, value)
	if kind == "Rewind" and typeof(value) == "number" then
		-- Retour en arrière (ex. Rewind Hour de Killer Queen)
		local character, root, humanoid = parts()
		if character then
			MOVES.Recall({ Seconds = value }, character, root, humanoid)
		end
		return
	end
	if kind ~= "Mobility" then return end
	local p = profile()
	local character, root, humanoid = parts()
	if not character or not MOVES[p.Type] then return end
	MOVES[p.Type](p, character, root, humanoid)
end)

-- ─── Vol plané (passif, ex. Magician's Red) ────────────────────────────────
RunService.Heartbeat:Connect(function()
	local p = profile()
	if not p.Glide then return end
	local _, root, humanoid = parts()
	if not root or humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then return end
	if not (UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)) then return end
	local v = root.AssemblyLinearVelocity
	if v.Y < -p.Glide then
		root.AssemblyLinearVelocity = Vector3.new(v.X, -p.Glide, v.Z)
	end
end)
