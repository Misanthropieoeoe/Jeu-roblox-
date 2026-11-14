-- Walk. Marche normale (vitesse 16), jouée par CoolRunSprintAnimationHook
-- quand le joueur bouge sans sprinter. Keyframes écrites à la main.
--
-- Style par défaut : MAINS DANS LES POCHES (démarche décontractée : épaules
-- qui roulent un peu, tête légèrement baissée, bras collés au corps).
-- Mettre HANDS_IN_POCKETS = false pour revenir aux bras qui balancent.
--
-- Cycle (à vitesse 16) :
--   0.00  contact : jambe droite devant
--   0.25  passage : jambe gauche qui passe sous le corps (genou levé)
--   0.50  contact : jambe gauche devant
--   0.75  passage : jambe droite qui passe sous le corps
--   1.00  = 0.00 (boucle)
--
-- Sens des rotations (R15, Motor6D.Transform), relevés sur Cool Run Sprint :
--   UpperLeg  +X = jambe vers l'avant      LowerLeg  -X = genou plié
--   UpperArm  +X = bras vers l'avant       LowerArm  +X = coude plié
--   Foot      +X = pointe du pied relevée  Head      -X = tête baissée
--   UpperTorso / LowerTorso : -X = penché en avant, +Y = rotation (twist)
-- R6 : Right Arm / Right Leg +Z = avant, Left Arm / Left Leg -Z = avant.

local rad = math.rad

-- Style ----------------------------------------------------------------------
local HANDS_IN_POCKETS = true

-- Jambes ---------------------------------------------------------------------
local CYCLE = 1.0 -- durée d'un cycle complet (2 pas), en secondes
local LEG_FORWARD = 26 -- jambe avant au contact
local LEG_BACK = 20 -- jambe arrière au contact
local KNEE_CONTACT_FRONT = 6 -- genou presque tendu à l'arrivée du pied
local KNEE_CONTACT_BACK = 18 -- genou arrière qui pousse
local KNEE_PASSING = 42 -- genou levé quand la jambe passe
local FOOT_HEEL = 10 -- talon qui touche (pointe relevée)
local FOOT_PUSH = 15 -- pied arrière qui pousse (pointe baissée)

-- Corps ----------------------------------------------------------------------
local HIP_TWIST = 5 -- rotation du bassin
local SHOULDER_TWIST = 7 -- contre-rotation des épaules (le "roulé")
local SHOULDER_ROLL = 3 -- épaules qui penchent d'un côté à chaque pas
local BOB_DOWN = -0.05 -- le corps descend au contact
local BOB_UP = 0.04 -- et remonte au passage
local LEAN = 3 -- inclinaison du bassin vers l'avant
local SLOUCH = 5 -- dos un peu voûté (poches seulement)
local HEAD_DOWN = 4 -- tête un peu baissée (poches seulement)

-- Bras : mains dans les poches -----------------------------------------------
local POCKET_ARM_BACK = 12 -- bras légèrement en arrière
local POCKET_ARM_OUT = 8 -- coudes écartés du corps (inverser le signe si les
--                           bras rentrent DANS le corps au lieu de s'écarter)
local POCKET_ELBOW = 32 -- avant-bras plié vers la poche
local POCKET_HAND = 12 -- poignet cassé, main qui rentre dans la poche
local POCKET_SWAY = 3 -- petit mouvement des bras à chaque pas

-- Bras : balancement (si HANDS_IN_POCKETS = false) ---------------------------
local ARM_FORWARD = 22
local ARM_BACK = 20
local ELBOW_FORWARD = 22
local ELBOW_BACK = 10
local ELBOW_PASSING = 14
-------------------------------------------------------------------------------

local function rx(deg)
	return CFrame.Angles(rad(deg), 0, 0)
end

local function other(side)
	return side == "Right" and "Left" or "Right"
end

-- side = 1 à droite, -1 à gauche (pour les rotations miroir)
local function sign(side)
	return side == "Right" and 1 or -1
end

local function pocketArm(frame, side, sway)
	frame[side .. "UpperArm"] = CFrame.Angles(rad(-POCKET_ARM_BACK + sway), 0, rad(POCKET_ARM_OUT * sign(side)))
	frame[side .. "LowerArm"] = rx(POCKET_ELBOW)
	frame[side .. "Hand"] = rx(POCKET_HAND)
end

local function torso(frame, bob, step)
	-- step = 1 (pied droit devant), -1 (pied gauche devant), 0 (passage)
	local slouch = HANDS_IN_POCKETS and SLOUCH or 0
	frame["LowerTorso"] = CFrame.new(0, bob, 0) * CFrame.Angles(rad(-LEAN), rad(HIP_TWIST * step), 0)
	frame["UpperTorso"] = CFrame.Angles(rad(-slouch), rad(-SHOULDER_TWIST * step), rad(SHOULDER_ROLL * step))
	frame["Head"] = rx(HANDS_IN_POCKETS and -HEAD_DOWN or 0)
end

-- Contact : `front` = côté de la jambe avant.
local function contact(front)
	local back = other(front)
	local f = {}
	torso(f, BOB_DOWN, sign(front))

	f[front .. "UpperLeg"] = rx(LEG_FORWARD)
	f[front .. "LowerLeg"] = rx(-KNEE_CONTACT_FRONT)
	f[front .. "Foot"] = rx(FOOT_HEEL)
	f[back .. "UpperLeg"] = rx(-LEG_BACK)
	f[back .. "LowerLeg"] = rx(-KNEE_CONTACT_BACK)
	f[back .. "Foot"] = rx(-FOOT_PUSH)

	if HANDS_IN_POCKETS then
		-- l'épaule opposée à la jambe avant avance un peu
		pocketArm(f, back, POCKET_SWAY)
		pocketArm(f, front, -POCKET_SWAY)
	else
		f[back .. "UpperArm"] = rx(ARM_FORWARD)
		f[back .. "LowerArm"] = rx(ELBOW_FORWARD)
		f[front .. "UpperArm"] = rx(-ARM_BACK)
		f[front .. "LowerArm"] = rx(ELBOW_BACK)
	end
	return f
end

-- Passage : `swing` = côté de la jambe qui passe sous le corps.
local function passing(swing)
	local planted = other(swing)
	local f = {}
	torso(f, BOB_UP, 0)

	f[planted .. "UpperLeg"] = rx(0)
	f[planted .. "LowerLeg"] = rx(-5)
	f[planted .. "Foot"] = rx(0)
	f[swing .. "UpperLeg"] = rx(10)
	f[swing .. "LowerLeg"] = rx(-KNEE_PASSING)
	f[swing .. "Foot"] = rx(5)

	if HANDS_IN_POCKETS then
		pocketArm(f, "Right", 0)
		pocketArm(f, "Left", 0)
	else
		f["RightUpperArm"] = rx(0)
		f["RightLowerArm"] = rx(ELBOW_PASSING)
		f["LeftUpperArm"] = rx(0)
		f["LeftLowerArm"] = rx(ELBOW_PASSING)
	end
	return f
end

local R15 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0] = contact("Right"),
		[CYCLE * 0.25] = passing("Left"),
		[CYCLE * 0.5] = contact("Left"),
		[CYCLE * 0.75] = passing("Right"),
		[CYCLE] = contact("Right"),
	},
}

-- R6 : bras et jambes d'un seul bloc (pas de coude), pivot sur l'axe Z.
-- Mains dans les poches = bras un peu en arrière, quasiment immobiles.
local function rz(deg)
	return CFrame.Angles(0, 0, rad(deg))
end

local function r6Arms(frame, rightForward)
	-- rightForward : avance du bras droit en degrés (négatif = arrière)
	if HANDS_IN_POCKETS then
		frame["Right Arm"] = rz(-POCKET_ARM_BACK + rightForward * 0.15)
		frame["Left Arm"] = rz(POCKET_ARM_BACK + rightForward * 0.15)
	else
		frame["Right Arm"] = rz(rightForward)
		frame["Left Arm"] = rz(rightForward)
	end
end

local function r6Frame(rightLeg, leftLeg, rightArm)
	local f = { ["Right Leg"] = rz(rightLeg), ["Left Leg"] = rz(leftLeg) }
	r6Arms(f, rightArm)
	return f
end

local R6 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0] = r6Frame(LEG_FORWARD, LEG_BACK, -ARM_BACK),
		[CYCLE * 0.25] = r6Frame(0, -10, 0),
		[CYCLE * 0.5] = r6Frame(-LEG_BACK, -LEG_FORWARD, ARM_FORWARD),
		[CYCLE * 0.75] = r6Frame(10, 0, 0),
		[CYCLE] = r6Frame(LEG_FORWARD, LEG_BACK, -ARM_BACK),
	},
}

return { Rigs = { R6 = R6, R15 = R15 } }
