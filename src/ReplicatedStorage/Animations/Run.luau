-- Run. Version moins prononcée de "Cool Run Sprint", jouée au sprint (Shift)
-- par CoolRunSprintAnimationHook.
--
-- Elle reprend chaque keyframe de Cool Run Sprint et réduit l'amplitude des
-- mouvements : 1 = identique à Cool Run Sprint, 0 = aucun mouvement.
-- Pour revenir à l'ancienne course, remettre SPRINT = "Cool Run Sprint" dans
-- CoolRunSprintAnimationHook.

-- Réglages -------------------------------------------------------------------
local DEFAULT_INTENSITY = 0.6

-- Intensité par partie du corps (les parties absentes utilisent la valeur
-- par défaut). Noms R15 puis R6.
local INTENSITY = {
	-- Torse et tête : moins de rotation et de balancement
	LowerTorso = 0.45,
	UpperTorso = 0.45,
	Head = 0.5,
	Torso = 0.45,

	-- Bras : moins de grands mouvements d'avant en arrière
	RightUpperArm = 0.55,
	LeftUpperArm = 0.55,
	RightLowerArm = 0.75,
	LeftLowerArm = 0.75,
	["Right Arm"] = 0.55,
	["Left Arm"] = 0.55,

	-- Jambes : foulée plus courte, genoux moins hauts
	RightUpperLeg = 0.65,
	LeftUpperLeg = 0.65,
	RightLowerLeg = 0.7,
	LeftLowerLeg = 0.7,
	["Right Leg"] = 0.65,
	["Left Leg"] = 0.65,
}
-------------------------------------------------------------------------------

local source = require(script.Parent:WaitForChild("Cool Run Sprint"))

local function soften(clip)
	local timestamps = {}
	for t, frame in pairs(clip.Timestamps) do
		local newFrame = {}
		for part, cf in pairs(frame) do
			-- Lerp depuis la pose de repos : la rotation et le décalage
			-- sont réduits proportionnellement.
			newFrame[part] = CFrame.identity:Lerp(cf, INTENSITY[part] or DEFAULT_INTENSITY)
		end
		timestamps[t] = newFrame
	end
	return {
		Settings = table.clone(clip.Settings),
		Timestamps = timestamps,
	}
end

local rigs = {}
for rigName, clip in pairs(source.Rigs) do
	rigs[rigName] = soften(clip)
end

return { Rigs = rigs }
