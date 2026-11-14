-- DoubleJump. Jouée par DoubleJump.client.luau au deuxième saut : le joueur
-- regarde en l'air, le dos se cambre, les bras montent vers le ciel et une
-- jambe se replie. Keyframes écrites à la main.
--
-- Déroulé (non bouclé) :
--   0.00  départ
--   0.12  impulsion : jambes repliées, la tête commence à monter
--   0.30  sommet : tête en l'air, dos cambré, bras levés
--   0.60  on reste en l'air, regard toujours vers le haut
--   0.90  relâchement vers la pose de chute (Roblox reprend la main ensuite)
--
-- Sens des rotations (R15, Motor6D.Transform), relevés sur Cool Run Sprint :
--   Head       +X = regarde vers le haut
--   UpperTorso +X = penché en arrière (cambré)
--   UpperArm   +X = bras vers l'avant / le haut   LowerArm +X = coude plié
--   UpperLeg   +X = jambe vers l'avant            LowerLeg -X = genou plié
-- R6 : Head / Torso -X = vers le haut / en arrière,
--      Right Arm / Right Leg +Z = avant, Left Arm / Left Leg -Z = avant.

local rad = math.rad

-- Réglages (en degrés) -------------------------------------------------------
local HEAD_UP = 35 -- regard vers le ciel au sommet
local ARCH_BACK = 14 -- dos cambré au sommet
local ARMS_UP = 125 -- bras levés (90 = à l'horizontale devant, 180 = tout droit en haut)
local ELBOW_BEND = 15
local KNEE_TUCK = 85 -- genou replié au sommet
local LEG_TUCK = 50 -- cuisse remontée au sommet
-------------------------------------------------------------------------------

local function rx(deg)
	return CFrame.Angles(rad(deg), 0, 0)
end

local function r15Pose(head, arch, arms, rightLeg, rightKnee, leftLeg, leftKnee)
	return {
		["Head"] = rx(head),
		["UpperTorso"] = rx(arch),
		["RightUpperArm"] = rx(arms),
		["LeftUpperArm"] = rx(arms),
		["RightLowerArm"] = rx(ELBOW_BEND),
		["LeftLowerArm"] = rx(ELBOW_BEND),
		["RightUpperLeg"] = rx(rightLeg),
		["RightLowerLeg"] = rx(-rightKnee),
		["LeftUpperLeg"] = rx(leftLeg),
		["LeftLowerLeg"] = rx(-leftKnee),
	}
end

local R15 = {
	Settings = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.00] = r15Pose(0, 0, 0, 0, 0, 0, 0),
		[0.12] = r15Pose(HEAD_UP * 0.5, ARCH_BACK * 0.3, ARMS_UP * 0.45, LEG_TUCK * 0.8, KNEE_TUCK * 0.9, 20, 45),
		[0.30] = r15Pose(HEAD_UP, ARCH_BACK, ARMS_UP, LEG_TUCK, KNEE_TUCK, 8, 30),
		[0.60] = r15Pose(HEAD_UP * 0.9, ARCH_BACK * 0.8, ARMS_UP * 0.85, LEG_TUCK * 0.6, KNEE_TUCK * 0.6, 5, 20),
		[0.90] = r15Pose(HEAD_UP * 0.4, ARCH_BACK * 0.2, ARMS_UP * 0.3, 10, 20, 0, 10),
	},
}

-- R6 : pas de coudes ni de genoux, on lève les bras et on monte une jambe.
local function r6Pose(head, arch, arms, rightLeg, leftLeg)
	return {
		["Head"] = rx(-head),
		["Torso"] = rx(-arch),
		["Right Arm"] = CFrame.Angles(0, 0, rad(arms)),
		["Left Arm"] = CFrame.Angles(0, 0, rad(-arms)),
		["Right Leg"] = CFrame.Angles(0, 0, rad(rightLeg)),
		["Left Leg"] = CFrame.Angles(0, 0, rad(-leftLeg)),
	}
end

local R6 = {
	Settings = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.00] = r6Pose(0, 0, 0, 0, 0),
		[0.12] = r6Pose(HEAD_UP * 0.5, ARCH_BACK * 0.3, ARMS_UP * 0.45, LEG_TUCK * 0.8, 15),
		[0.30] = r6Pose(HEAD_UP, ARCH_BACK, ARMS_UP, LEG_TUCK, 5),
		[0.60] = r6Pose(HEAD_UP * 0.9, ARCH_BACK * 0.8, ARMS_UP * 0.85, LEG_TUCK * 0.6, 0),
		[0.90] = r6Pose(HEAD_UP * 0.4, ARCH_BACK * 0.2, ARMS_UP * 0.3, 10, 0),
	},
}

return { Rigs = { R6 = R6, R15 = R15 } }
