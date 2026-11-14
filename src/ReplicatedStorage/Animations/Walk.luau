-- Walk. Marche normale (vitesse 16), jouée par CoolRunSprintAnimationHook
-- quand le joueur bouge sans sprinter. Keyframes écrites à la main.
--
-- Cycle de 0.9 s (à vitesse 16) :
--   0.000  contact : jambe droite devant, bras gauche devant
--   0.225  passage : jambe gauche qui passe sous le corps (genou levé)
--   0.450  contact : jambe gauche devant, bras droit devant
--   0.675  passage : jambe droite qui passe sous le corps
--   0.900  = 0.000 (boucle)
--
-- Pour régler l'animation, modifie les constantes ci-dessous (en degrés).
--
-- Sens des rotations (R15, Motor6D.Transform), relevés sur Cool Run Sprint :
--   UpperLeg  +X = jambe vers l'avant      LowerLeg  -X = genou plié
--   UpperArm  +X = bras vers l'avant       LowerArm  +X = coude plié
--   Foot      +X = pointe du pied relevée
--   UpperTorso / LowerTorso : +Y = rotation (twist)
-- R6 : Right Arm / Right Leg +Z = avant, Left Arm / Left Leg -Z = avant.

local rad = math.rad

-- Réglages -------------------------------------------------------------------
local LEG_FORWARD = 28 -- jambe avant au contact
local LEG_BACK = 22 -- jambe arrière au contact
local KNEE_CONTACT_FRONT = 6 -- genou presque tendu à l'arrivée du pied
local KNEE_CONTACT_BACK = 18 -- genou arrière qui pousse
local KNEE_PASSING = 45 -- genou levé quand la jambe passe
local FOOT_HEEL = 10 -- talon qui touche (pointe relevée)
local FOOT_PUSH = 15 -- pied arrière qui pousse (pointe baissée)

local ARM_FORWARD = 22 -- bras avant
local ARM_BACK = 20 -- bras arrière
local ELBOW_FORWARD = 22 -- coude du bras avant
local ELBOW_BACK = 10 -- coude du bras arrière
local ELBOW_PASSING = 14

local HIP_TWIST = 4 -- rotation du bassin
local SHOULDER_TWIST = 5 -- contre-rotation des épaules
local BOB_DOWN = -0.05 -- le corps descend au contact
local BOB_UP = 0.04 -- et remonte au passage
local LEAN = 3 -- légère inclinaison vers l'avant
-------------------------------------------------------------------------------

local function rx(deg)
	return CFrame.Angles(rad(deg), 0, 0)
end

local function lowerTorso(bob, twist)
	return CFrame.new(0, bob, 0) * CFrame.Angles(rad(-LEAN), rad(twist), 0)
end

-- Contact : `front` = côté de la jambe avant ("Right" ou "Left").
local function contact(front)
	local back = front == "Right" and "Left" or "Right"
	local twist = front == "Right" and 1 or -1
	return {
		["LowerTorso"] = lowerTorso(BOB_DOWN, HIP_TWIST * twist),
		["UpperTorso"] = CFrame.Angles(0, rad(-SHOULDER_TWIST * twist), 0),

		[front .. "UpperLeg"] = rx(LEG_FORWARD),
		[front .. "LowerLeg"] = rx(-KNEE_CONTACT_FRONT),
		[front .. "Foot"] = rx(FOOT_HEEL),
		[back .. "UpperLeg"] = rx(-LEG_BACK),
		[back .. "LowerLeg"] = rx(-KNEE_CONTACT_BACK),
		[back .. "Foot"] = rx(-FOOT_PUSH),

		-- bras opposés aux jambes
		[back .. "UpperArm"] = rx(ARM_FORWARD),
		[back .. "LowerArm"] = rx(ELBOW_FORWARD),
		[front .. "UpperArm"] = rx(-ARM_BACK),
		[front .. "LowerArm"] = rx(ELBOW_BACK),
	}
end

-- Passage : `swing` = côté de la jambe qui passe sous le corps.
local function passing(swing)
	local planted = swing == "Right" and "Left" or "Right"
	return {
		["LowerTorso"] = lowerTorso(BOB_UP, 0),
		["UpperTorso"] = CFrame.identity,

		[planted .. "UpperLeg"] = rx(0),
		[planted .. "LowerLeg"] = rx(-5),
		[planted .. "Foot"] = rx(0),
		[swing .. "UpperLeg"] = rx(10),
		[swing .. "LowerLeg"] = rx(-KNEE_PASSING),
		[swing .. "Foot"] = rx(5),

		["RightUpperArm"] = rx(0),
		["RightLowerArm"] = rx(ELBOW_PASSING),
		["LeftUpperArm"] = rx(0),
		["LeftLowerArm"] = rx(ELBOW_PASSING),
	}
end

local R15 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.000] = contact("Right"),
		[0.225] = passing("Left"),
		[0.450] = contact("Left"),
		[0.675] = passing("Right"),
		[0.900] = contact("Right"),
	},
}

-- R6 : bras et jambes d'un seul bloc, pivot sur l'axe Z du joint.
local function rz(deg)
	return CFrame.Angles(0, 0, rad(deg))
end

local R6 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0.000] = {
			["Right Leg"] = rz(LEG_FORWARD),
			["Left Leg"] = rz(LEG_BACK),
			["Right Arm"] = rz(-ARM_BACK),
			["Left Arm"] = rz(-ARM_FORWARD),
		},
		[0.225] = {
			["Right Leg"] = rz(0),
			["Left Leg"] = rz(-10),
			["Right Arm"] = rz(0),
			["Left Arm"] = rz(0),
		},
		[0.450] = {
			["Right Leg"] = rz(-LEG_BACK),
			["Left Leg"] = rz(-LEG_FORWARD),
			["Right Arm"] = rz(ARM_FORWARD),
			["Left Arm"] = rz(ARM_BACK),
		},
		[0.675] = {
			["Right Leg"] = rz(10),
			["Left Leg"] = rz(0),
			["Right Arm"] = rz(0),
			["Left Arm"] = rz(0),
		},
		[0.900] = {
			["Right Leg"] = rz(LEG_FORWARD),
			["Left Leg"] = rz(LEG_BACK),
			["Right Arm"] = rz(-ARM_BACK),
			["Left Arm"] = rz(-ARM_FORWARD),
		},
	},
}

return { Rigs = { R6 = R6, R15 = R15 } }
