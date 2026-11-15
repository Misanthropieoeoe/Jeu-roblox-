-- AnimReplicator. Rejoue sur NOTRE écran les animations des AUTRES joueurs
-- (marche, course, attente, garde, poses d'attaque, coups reçus…).
-- Chaque joueur annonce l'animation qu'il lance (AnimationController →
-- Remotes.AnimSync) ; le serveur la note sur son personnage (attributs
-- SyncAnim / SyncAnimAt) ; ici on la joue sur ce personnage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))

local localPlayer = Players.LocalPlayer

-- Marche / course : la vitesse de l'animation suit la vitesse du personnage,
-- comme sur l'écran du joueur (CoolRunSprintAnimationHook).
local SPEED_SCALED = {
	Walk = { min = 0.5, max = 1.3, lean = 0 },
	Run = { min = 0.55, max = 1.6, lean = 4 },
}
local REFERENCE_SPEED = 16

local watched = {} -- [Model] = true

local function apply(character)
	local name = character:GetAttribute("SyncAnim")
	if name then
		AnimationController.PlayOn(character, name)
	else
		AnimationController.StopOn(character)
	end
end

local function watchCharacter(character)
	if watched[character] then return end
	watched[character] = true
	-- même animation relancée (ex. deux coups reçus) : SyncAnimAt change
	character:GetAttributeChangedSignal("SyncAnimAt"):Connect(function()
		apply(character)
	end)
	character:GetAttributeChangedSignal("SyncAnim"):Connect(function()
		if not character:GetAttribute("SyncAnim") then
			AnimationController.StopOn(character)
		end
	end)
	character.AncestryChanged:Connect(function()
		if not character.Parent then watched[character] = nil end
	end)
	-- animation déjà en cours quand on arrive
	task.spawn(function()
		character:WaitForChild("Humanoid", 10)
		if character:GetAttribute("SyncAnim") then apply(character) end
	end)
end

local function watchPlayer(player)
	if player == localPlayer then return end
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

RunService.Heartbeat:Connect(function()
	for character in watched do
		local root = character:FindFirstChild("HumanoidRootPart")
		local name = root and AnimationController.CurrentAnimationOn(character)
		local scaled = name and SPEED_SCALED[name]
		if scaled then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local rate = math.clamp(speed / REFERENCE_SPEED, scaled.min, scaled.max)
			local lean = math.clamp((speed - REFERENCE_SPEED) / 12, 0, 1) * math.rad(scaled.lean)
			AnimationController.SetClipSpeedOn(character, name, rate, lean)
		end
	end
end)
