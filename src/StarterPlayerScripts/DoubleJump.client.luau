-- DoubleJump. Appuyer une deuxième fois sur Saut (Espace / bouton A / bouton
-- saut mobile) en l'air relance le joueur vers le haut et joue l'animation
-- "DoubleJump" (le joueur regarde en l'air) avec un petit son.
--
-- Le double saut est bloqué quand la puissance de saut est à 0 (étourdi,
-- arrêt du temps…), quand le perso est ancré, assis ou mort.
-- Il se recharge en touchant le sol (ou en nageant / grimpant).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandMovement = require(ReplicatedStorage:WaitForChild("StandMovement"))

-- Réglages -------------------------------------------------------------------
local ANIMATION = "DoubleJump"
-- Valeurs par défaut ; chaque Stand peut avoir les siennes (AirJumps,
-- JumpPower dans ReplicatedStorage.StandMovement).
local AIR_JUMPS = 1 -- nombre de sauts en l'air (1 = double saut, 2 = triple…)
local POWER = 1.25 -- force du double saut par rapport au saut normal
local MIN_AIR_TIME = 0.12 -- délai minimum après avoir quitté le sol
-- Deux demandes de saut plus proches que ça = la même touche maintenue
-- (Roblox répète la demande tant qu'on garde Espace enfoncé).
local HOLD_GAP = 0.12

-- Son du double saut. Par défaut : le son de saut intégré à Roblox, joué plus
-- aigu. Pour un autre son, mettre un ID de la boutique, par exemple
-- "rbxassetid://123456789" (il doit être public ou t'appartenir).
local SOUND_ID = require(game:GetService("ReplicatedStorage"):WaitForChild("SFX")).Get("DoubleJump", "rbxasset://sounds/action_jump.mp3")
local SOUND_VOLUME = 0.6
local SOUND_PITCH = 1.35 -- 1 = normal, plus haut = plus aigu
-------------------------------------------------------------------------------

local AIR_STATES = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}
local RESET_STATES = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Seated] = true,
}

local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local jumpSound: Sound? = nil
local jumpsUsed = 0
local airborneSince = 0
local lastRequest = 0

-- Vitesse verticale d'un saut normal, avec les réglages actuels du humanoid.
local function normalJumpVelocity(h: Humanoid): number
	if h.UseJumpPower then
		return h.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * h.JumpHeight)
end

local function tryDoubleJump()
	local h, root = humanoid, rootPart
	if not h or not root or not root.Parent then return end
	if h.Health <= 0 or h.Sit or root.Anchored then return end
	if not AIR_STATES[h:GetState()] then return end
	local standProfile = StandMovement.Get(Players.LocalPlayer:GetAttribute("StandId") or StandData.DefaultStand)
	if jumpsUsed >= (standProfile.AirJumps or AIR_JUMPS) then return end
	if os.clock() - airborneSince < MIN_AIR_TIME then return end

	local velocity = normalJumpVelocity(h) * (standProfile.JumpPower or POWER)
	if velocity <= 0 then return end -- étourdi / arrêt du temps

	jumpsUsed += 1
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, velocity, v.Z)
	AnimationController.Play(ANIMATION)
	if jumpSound then
		jumpSound:Play()
	end
end

UserInputService.JumpRequest:Connect(function()
	local now = os.clock()
	local fresh = now - lastRequest > HOLD_GAP
	lastRequest = now
	if fresh then
		tryDoubleJump()
	end
end)

local function hookCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	jumpsUsed = 0

	local sound = Instance.new("Sound")
	sound.Name = "DoubleJumpSound"
	sound.SoundId = SOUND_ID
	sound.Volume = SOUND_VOLUME
	sound.PlaybackSpeed = SOUND_PITCH
	sound.Parent = rootPart
	jumpSound = sound

	local h = humanoid :: Humanoid
	h.StateChanged:Connect(function(oldState, newState)
		if AIR_STATES[newState] and not AIR_STATES[oldState] then
			airborneSince = os.clock()
		elseif RESET_STATES[newState] then
			jumpsUsed = 0
		end
	end)
end

local player = Players.LocalPlayer
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)
