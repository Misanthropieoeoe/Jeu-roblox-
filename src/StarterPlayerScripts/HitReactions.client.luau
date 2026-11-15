-- HitReactions. Quand notre personnage prend un coup, il joue une réaction
-- originale (PlayerPoses.Clips) selon la force du coup :
--   coup léger (M1, projectile, zone)  -> PlayerHitLight
--   coup lourd (frappe, explosion…)    -> PlayerHitHeavy
--   coup final (fin de rafale)         -> PlayerKnockdown (chute + relevé)
-- Le serveur annonce chaque coup (StandFX "Hit") avec la position de la
-- cible : si c'est la nôtre, on réagit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")

local player = Players.LocalPlayer

local REACTION = {
	light = "PlayerHitLight",
	projectile = "PlayerHitLight",
	zone = "PlayerHitLight",
	barrage = "PlayerHitLight",
	heavy = "PlayerHitHeavy",
	final = "PlayerKnockdown",
}
-- Plus la réaction est forte, plus elle est prioritaire (une chute n'est pas
-- coupée par un petit coup).
local STRENGTH = { PlayerHitLight = 1, PlayerHitHeavy = 2, PlayerKnockdown = 3 }
local MIN_GAP = 0.12 -- évite de relancer l'animation à chaque coup d'une rafale

local lastAt = 0

standFX.OnClientEvent:Connect(function(kind, moveKind, position)
	if kind ~= "Hit" or typeof(position) ~= "Vector3" then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - position).Magnitude > 3.5 then return end
	if player:GetAttribute("Blocking") then return end

	local anim = REACTION[moveKind] or "PlayerHitLight"
	local current = AnimationController.CurrentAnimation()
	if current and STRENGTH[current] and STRENGTH[current] > STRENGTH[anim] then
		return -- une réaction plus forte est en cours
	end
	if current == anim and os.clock() - lastAt < MIN_GAP then return end
	lastAt = os.clock()
	AnimationController.Play(anim)
end)
