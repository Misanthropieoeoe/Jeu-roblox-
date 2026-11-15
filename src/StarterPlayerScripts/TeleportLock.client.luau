-- TeleportLock. Après un sort de téléportation (type "Teleport"), le serveur
-- envoie StandFX "LockOn" avec la cible : pendant un court instant, le joueur
-- reste tourné vers l'adversaire et la caméra se recentre derrière lui, face
-- à la cible, pour que le coup touche (même en shift-lock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")
local player = Players.LocalPlayer

local CAMERA_SMOOTH = 0.35 -- 0..1 : vitesse du recentrage de la caméra
local lockTarget, lockUntil = nil, 0

standFX.OnClientEvent:Connect(function(kind, target, duration)
	if kind ~= "LockOn" then return end
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") then return end
	lockTarget = target
	lockUntil = os.clock() + math.clamp(tonumber(duration) or 0.5, 0.2, 2)
end)

RunService:BindToRenderStep("TeleportLock", Enum.RenderPriority.Camera.Value + 1, function()
	if not lockTarget then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if os.clock() > lockUntil or not root or not lockTarget.Parent then
		lockTarget = nil
		return
	end
	local targetPos = lockTarget.Position
	local flat = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
	if flat.Magnitude < 0.1 then return end
	local dir = flat.Unit
	-- le joueur fait face à la cible
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	-- la caméra se place derrière le joueur et regarde la cible
	local camera = workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		distance = math.clamp(distance, 6, 18)
		local height = math.clamp(distance * 0.35, 2, 6)
		local wanted = CFrame.lookAt(root.Position - dir * distance + Vector3.new(0, height, 0), targetPos)
		camera.CFrame = camera.CFrame:Lerp(wanted, CAMERA_SMOOTH)
	end
end)
