-- Block. Garde du joueur (touche X) : avant-bras croisés devant le visage,
-- buste légèrement penché, jambes un peu fléchies. Jouée en boucle par
-- Guard.client.luau tant que la garde est levée (pose fixe).
--
-- Sens des rotations (R15, Motor6D.Transform), relevés sur Cool Run Sprint :
--   UpperArm +X = bras vers l'avant, +Y (droit) / -Y (gauche) = vers le centre
--   LowerArm +X = coude plié   UpperLeg +X = cuisse avant   LowerLeg -X = genou plié
-- R6 : Right Arm +Z = avant, Left Arm -Z = avant ; Y = vers le centre.

local rad = math.rad

-- Réglages (degrés) ------------------------------------------------------------
local ARM_UP = 80 -- bras levés devant
local ARM_IN = 38 -- bras ramenés vers le centre (croisement)
local ELBOW = 105 -- avant-bras repliés vers le haut
local LEAN = 8 -- buste penché en avant
local KNEE = 18 -- jambes fléchies
---------------------------------------------------------------------------------

local function pose()
	return {
		["LowerTorso"] = CFrame.new(0, -0.1, 0) * CFrame.Angles(rad(-LEAN * 0.4), 0, 0),
		["UpperTorso"] = CFrame.Angles(rad(-LEAN * 0.6), 0, 0),
		["Head"] = CFrame.Angles(rad(LEAN * 0.5), 0, 0),
		["RightUpperArm"] = CFrame.Angles(rad(ARM_UP), rad(ARM_IN), 0),
		["RightLowerArm"] = CFrame.Angles(rad(ELBOW), 0, 0),
		["LeftUpperArm"] = CFrame.Angles(rad(ARM_UP), rad(-ARM_IN), 0),
		["LeftLowerArm"] = CFrame.Angles(rad(ELBOW), 0, 0),
		["RightUpperLeg"] = CFrame.Angles(rad(KNEE * 0.6), 0, 0),
		["RightLowerLeg"] = CFrame.Angles(rad(-KNEE), 0, 0),
		["LeftUpperLeg"] = CFrame.Angles(rad(KNEE * 0.6), 0, 0),
		["LeftLowerLeg"] = CFrame.Angles(rad(-KNEE), 0, 0),
	}
end

local function poseR6()
	return {
		["Right Arm"] = CFrame.Angles(0, rad(ARM_IN), rad(ARM_UP + 20)),
		["Left Arm"] = CFrame.Angles(0, rad(-ARM_IN), rad(-(ARM_UP + 20))),
	}
end

-- Boucle sur une pose fixe : le moteur arrêterait un clip non bouclé à la fin.
local R15 = {
	Settings = { Loop = true, Priority = Enum.AnimationPriority.Action, CounterRotateLegs = false },
	Timestamps = { [0] = pose(), [0.5] = pose() },
}
local R6 = {
	Settings = { Loop = true, Priority = Enum.AnimationPriority.Action, CounterRotateLegs = false },
	Timestamps = { [0] = poseR6(), [0.5] = poseR6() },
}

return { Rigs = { R6 = R6, R15 = R15 } }
