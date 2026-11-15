-- SpellGestures. Pendant une attaque du Stand (moveset de StandSpells), le
-- joueur prend la pose PlayerAnim de l'attaque (ordonner au Stand, garde,
-- incantation…) tant que son Stand est dans l'état de cette attaque.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))

local player = Players.LocalPlayer
local playing = nil -- nom de la pose en cours

local function stopGesture()
	if playing and AnimationController.CurrentAnimation() == playing then
		AnimationController.Stop(playing)
	end
	playing = nil
end

local function onStateChanged(stand)
	local state = stand:GetAttribute("State")
	local def = StandData.GetStand(stand:GetAttribute("StandId") or "")
	local move = def and def.Moves and def.Moves[state]
	local wanted = move and move.Type and move.PlayerAnim or nil
	if wanted == playing then return end
	stopGesture()
	if wanted then
		playing = wanted
		AnimationController.Play(wanted)
	end
end

local function watch(stand)
	if stand.Name ~= player.Name .. "Stand" or not stand:IsA("Model") then return end
	stand:GetAttributeChangedSignal("State"):Connect(function()
		onStateChanged(stand)
	end)
	stand.AncestryChanged:Connect(function()
		if not stand.Parent then stopGesture() end
	end)
end

workspace.ChildAdded:Connect(watch)
for _, child in workspace:GetChildren() do
	watch(child)
end
player.CharacterAdded:Connect(function()
	playing = nil
end)
