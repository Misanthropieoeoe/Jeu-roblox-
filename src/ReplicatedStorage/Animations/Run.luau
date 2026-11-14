-- Run. Course au sprint (Shift, vitesse 24), jouée par
-- CoolRunSprintAnimationHook. Keyframes écrites à la main, dans le même
-- esprit que Walk : propre et dynamique sans être exagéré.
--
-- Ce qui la rend plus vivante que l'ancienne :
--   - bras pliés à ~90° qui "pompent" d'avant en arrière (pas de grands moulinets)
--   - genou qui monte devant pendant que l'autre jambe pousse derrière
--   - phase de vol : le corps remonte entre deux appuis
--   - bassin et épaules qui tournent en sens inverse
--   - tête qui reste stable et regarde devant malgré l'inclinaison
--
-- Cycle (à vitesse 16 ; au sprint 24 il est joué 1.5x plus vite) :
--   0.00  appui : pied droit qui touche le sol devant
--   0.17  vol : genou gauche qui monte, corps en haut
--   0.33  appui : pied gauche devant
--   0.50  vol : genou droit qui monte
--   0.66  = 0.00 (boucle)
-- Les poses intermédiaires sont calculées pour adoucir les transitions.
--
-- Pour revenir à l'ancienne course : SPRINT = "Cool Run Sprint" dans
-- CoolRunSprintAnimationHook.
--
-- Sens des rotations (R15, Motor6D.Transform), relevés sur Cool Run Sprint :
--   UpperLeg +X = jambe vers l'avant    LowerLeg -X = genou plié
--   UpperArm +X = bras vers l'avant     LowerArm +X = coude plié
--   Foot     +X = pointe relevée        Head     +X = regarde vers le haut
--   LowerTorso / UpperTorso : -X = penché en avant, +Y = rotation (twist)
-- R6 : Right Arm / Right Leg +Z = avant, Left Arm / Left Leg -Z = avant,
--      Torso +X = penché en avant, Head -X = regarde vers le haut.

local rad = math.rad

-- Réglages (degrés, sauf mention) --------------------------------------------
local CYCLE = 0.66 -- durée d'un cycle complet (2 foulées) à vitesse 16

-- Jambes
local LEG_REACH = 42 -- jambe avant à l'appui
local LEG_PUSH = 28 -- jambe arrière qui pousse
local KNEE_REACH = 22 -- genou avant légèrement plié à l'appui
local KNEE_PUSH = 30 -- genou arrière
local KNEE_LIFT = 58 -- cuisse qui monte pendant le vol
local KNEE_TUCK = 100 -- pied qui remonte sous les fesses pendant le vol
local FOOT_STRIKE = 8 -- pointe relevée à l'appui
local FOOT_PUSH = 25 -- pied arrière tendu à la poussée

-- Bras
local ARM_FORWARD = 45
local ARM_BACK = 38
local ELBOW = 88 -- coudes pliés (90 = angle droit)
local ELBOW_SWING = 10 -- le coude se ferme un peu devant, s'ouvre derrière
local HAND = 10

-- Corps
local LEAN = 9 -- inclinaison vers l'avant
local HIP_TWIST = 7
local SHOULDER_TWIST = 11
local HEAD_COMPENSATE = 7 -- relève la tête pour regarder devant
local BOB_LOW = -0.09 -- le corps descend à l'appui (studs)
local BOB_HIGH = 0.07 -- et remonte en vol
-------------------------------------------------------------------------------

local function rx(deg)
	return CFrame.Angles(rad(deg), 0, 0)
end

local function other(side)
	return side == "Right" and "Left" or "Right"
end

local function sign(side)
	return side == "Right" and 1 or -1
end

local function body(f, bob, step)
	-- step : 1 = pied droit devant, -1 = pied gauche devant, 0 = vol
	f["LowerTorso"] = CFrame.new(0, bob, 0) * CFrame.Angles(rad(-LEAN), rad(HIP_TWIST * step), 0)
	f["UpperTorso"] = CFrame.Angles(rad(-2), rad(-SHOULDER_TWIST * step), 0)
	f["Head"] = CFrame.Angles(rad(HEAD_COMPENSATE), rad((SHOULDER_TWIST - HIP_TWIST) * step), 0)
end

local function arms(f, forwardSide, amount)
	-- amount : 1 = bras au maximum, 0 = bras au milieu
	local back = other(forwardSide)
	f[forwardSide .. "UpperArm"] = rx(ARM_FORWARD * amount)
	f[forwardSide .. "LowerArm"] = rx(ELBOW + ELBOW_SWING * amount)
	f[forwardSide .. "Hand"] = rx(HAND)
	f[back .. "UpperArm"] = rx(-ARM_BACK * amount)
	f[back .. "LowerArm"] = rx(ELBOW - ELBOW_SWING * amount)
	f[back .. "Hand"] = rx(HAND)
end

-- Appui : `front` = jambe qui touche le sol devant.
local function strike(front)
	local back = other(front)
	local f = {}
	body(f, BOB_LOW, sign(front))
	f[front .. "UpperLeg"] = rx(LEG_REACH)
	f[front .. "LowerLeg"] = rx(-KNEE_REACH)
	f[front .. "Foot"] = rx(FOOT_STRIKE)
	f[back .. "UpperLeg"] = rx(-LEG_PUSH)
	f[back .. "LowerLeg"] = rx(-KNEE_PUSH)
	f[back .. "Foot"] = rx(-FOOT_PUSH)
	arms(f, back, 1) -- bras opposé à la jambe avant
	return f
end

-- Vol : `lift` = jambe dont le genou monte devant.
local function flight(lift)
	local trail = other(lift)
	local f = {}
	body(f, BOB_HIGH, 0)
	f[lift .. "UpperLeg"] = rx(KNEE_LIFT)
	f[lift .. "LowerLeg"] = rx(-KNEE_TUCK * 0.75)
	f[lift .. "Foot"] = rx(5)
	f[trail .. "UpperLeg"] = rx(-LEG_PUSH * 0.6)
	f[trail .. "LowerLeg"] = rx(-KNEE_TUCK)
	f[trail .. "Foot"] = rx(-10)
	arms(f, trail, 0.35)
	return f
end

local R15 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0] = strike("Right"),
		[CYCLE * 0.25] = flight("Left"),
		[CYCLE * 0.5] = strike("Left"),
		[CYCLE * 0.75] = flight("Right"),
		[CYCLE] = strike("Right"),
	},
}

-- R6 : bras et jambes d'un seul bloc, pivot sur l'axe Z du joint.
local function rz(deg)
	return CFrame.Angles(0, 0, rad(deg))
end

-- right = avance de la jambe droite (degrés), left = avance de la jambe gauche
local function r6Frame(rightLeg, leftLeg, bob)
	local rightArm = -rightLeg * 0.9 -- bras opposé à la jambe
	return {
		-- RootJoint R6 tourné de 90° : son axe Z local est la verticale.
		["Torso"] = CFrame.new(0, 0, bob) * rx(LEAN),
		["Head"] = rx(-HEAD_COMPENSATE),
		["Right Leg"] = rz(rightLeg),
		["Left Leg"] = rz(-leftLeg),
		["Right Arm"] = rz(rightArm),
		["Left Arm"] = rz(rightArm),
	}
end

local R6 = {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		CounterRotateLegs = false,
	},
	Timestamps = {
		[0] = r6Frame(LEG_REACH, -LEG_PUSH, BOB_LOW),
		[CYCLE * 0.25] = r6Frame(-LEG_PUSH * 0.6, KNEE_LIFT * 0.6, BOB_HIGH),
		[CYCLE * 0.5] = r6Frame(-LEG_PUSH, LEG_REACH, BOB_LOW),
		[CYCLE * 0.75] = r6Frame(KNEE_LIFT * 0.6, -LEG_PUSH * 0.6, BOB_HIGH),
		[CYCLE] = r6Frame(LEG_REACH, -LEG_PUSH, BOB_LOW),
	},
}

return { Rigs = { R6 = R6, R15 = R15 } }
