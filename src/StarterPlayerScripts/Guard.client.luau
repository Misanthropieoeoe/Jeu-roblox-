-- Guard. Parade : maintenir X pour lever la garde (le serveur gère les
-- dégâts réduits, la parade parfaite et la garde brisée, voir StandService
-- section PARADE). Joue l'animation "Block" sur le personnage tant que le
-- serveur confirme la garde (attribut "Blocking" du joueur).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")

-- Réglages -----------------------------------------------------------------
local BLOCK_KEYS = {
	[Enum.KeyCode.X] = true,
	[Enum.KeyCode.ButtonL1] = true, -- manette
}
local ANIMATION = "Block"
------------------------------------------------------------------------------

local player = Players.LocalPlayer
local holding = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not BLOCK_KEYS[input.KeyCode] then return end
	holding = true
	standAction:FireServer("Block", true)
end)

UserInputService.InputEnded:Connect(function(input)
	if not BLOCK_KEYS[input.KeyCode] or not holding then return end
	holding = false
	standAction:FireServer("Block", false)
end)

-- Si la fenêtre perd le focus, X ne sera jamais relâché : on baisse la garde.
UserInputService.WindowFocusReleased:Connect(function()
	if holding then
		holding = false
		standAction:FireServer("Block", false)
	end
end)

-- Animation pilotée par la réponse du serveur
local function refresh()
	if player:GetAttribute("Blocking") then
		if AnimationController.CurrentAnimation() ~= ANIMATION then
			AnimationController.Play(ANIMATION)
		end
	elseif AnimationController.CurrentAnimation() == ANIMATION then
		AnimationController.Stop(ANIMATION)
	end
end
player:GetAttributeChangedSignal("Blocking"):Connect(refresh)

-- Garde verrouillée pendant un combo M1 reçu (avant le 3e coup) : si X est
-- toujours maintenu quand le verrou saute, on lève la garde tout de suite.
player:GetAttributeChangedSignal("GuardLocked"):Connect(function()
	if not player:GetAttribute("GuardLocked") and holding and not player:GetAttribute("Blocking") then
		standAction:FireServer("Block", true)
	end
end)
player.CharacterAdded:Connect(function()
	holding = false
end)
