-- PlayerPoses. Poses du joueur pendant les attaques de son Stand (champ
-- PlayerAnim dans StandSpells). Chaque pose est tenue tant que l'attaque dure
-- (SpellGestures.client.luau), puis le joueur revient à la normale.
--
-- Les modules ReplicatedStorage.Animations.Cmd* font juste
--   return require(ReplicatedStorage.PlayerPoses).Build("CmdPoint")
-- pour que l'AnimationController (Lemonade) les trouve par leur nom.
--
-- ─── Comment écrire une pose (degrés) ───────────────────────────────────────
--   R / L       bras : pitch (vers l'avant), abduct (écarté), swing (vers le
--               centre), elbow (coude plié), wrist (poignet)
--   lean        buste penché en avant ; twist (l'épaule droite avance)
--   drop        le corps descend (studs) ; headPitch (tête vers le haut)
--   legR / legL { hip = cuisse vers l'avant, knee = genou plié }
-- Sens des rotations relevés sur l'animation Cool Run Sprint (R15).

local PlayerPoses = {}

local rad = math.rad

PlayerPoses.Poses = {
	-- Ordonne au Stand : bras tendu, doigt pointé
	CmdPoint = {
		R = { pitch = 88, swing = 8, elbow = 5 },
		L = { pitch = -10, abduct = 12, elbow = 20 },
		twist = 15, lean = 4,
	},
	-- Bras levé vers le ciel (soins, bonus, grosses zones)
	CmdSummon = {
		R = { pitch = 160, abduct = 10, elbow = 15 },
		L = { pitch = -5, abduct = 10, elbow = 15 },
		headPitch = 15, lean = -6,
	},
	-- Garde basse, jambes fléchies (rafales, contres)
	CmdBrace = {
		R = { pitch = 55, abduct = 15, swing = 15, elbow = 105 },
		L = { pitch = 55, abduct = 15, swing = 15, elbow = 105 },
		lean = 10, drop = 0.3,
		legR = { hip = -10, knee = 30 }, legL = { hip = 30, knee = 40 },
	},
	-- Deux mains devant, paumes ouvertes (projectiles, zones)
	CmdCast = {
		R = { pitch = 85, abduct = 15, swing = 20, elbow = 20, wrist = 35 },
		L = { pitch = 85, abduct = 15, swing = 20, elbow = 20, wrist = 35 },
		lean = 6,
	},
	-- Penché en avant, bras en arrière (ruées, téléportations)
	CmdDash = {
		R = { pitch = -35, abduct = 15, elbow = 30 },
		L = { pitch = -35, abduct = 15, elbow = 30 },
		lean = 25, drop = 0.1,
		legR = { hip = -25, knee = 30 }, legL = { hip = 40, knee = 60 },
	},
	-- Accroupi, main vers le sol (pièges, zones au sol)
	CmdPlant = {
		R = { pitch = 55, abduct = 10, elbow = 15, wrist = -25 },
		L = { pitch = 10, abduct = 25, elbow = 70 },
		lean = 30, drop = 0.8,
		legR = { hip = 70, knee = 100 }, legL = { hip = 15, knee = 110 },
	},
}

local function angles(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

local function r15Frame(p)
	local lean, twist = p.lean or 0, p.twist or 0
	local frame = {
		LowerTorso = CFrame.new(0, -(p.drop or 0), 0) * angles(-lean * 0.4, twist * 0.4, 0),
		UpperTorso = angles(-lean * 0.6, twist * 0.6, 0),
		Head = angles(p.headPitch, -twist, 0),
	}
	for _, side in ipairs({ { "Right", p.R, 1, p.legR }, { "Left", p.L, -1, p.legL } }) do
		local name, arm, s, leg = side[1], side[2] or {}, side[3], side[4] or {}
		frame[name .. "UpperArm"] = angles(arm.pitch, (arm.swing or 0) * s, (arm.abduct or 0) * s)
		frame[name .. "LowerArm"] = angles(arm.elbow, 0, 0)
		frame[name .. "Hand"] = angles(arm.wrist, 0, 0)
		frame[name .. "UpperLeg"] = angles(leg.hip, 0, 0)
		frame[name .. "LowerLeg"] = angles(-(leg.knee or 0), 0, 0)
	end
	return frame
end

-- R6 : bras et jambes d'un seul bloc (pas de coude ni de genou)
local function r6Frame(p)
	local R, L = p.R or {}, p.L or {}
	local legR, legL = p.legR or {}, p.legL or {}
	return {
		Torso = angles(p.lean, 0, 0),
		Head = angles(-(p.headPitch or 0), 0, 0),
		["Right Arm"] = angles(0, R.swing, R.pitch),
		["Left Arm"] = angles(0, -(L.swing or 0), -(L.pitch or 0)),
		["Right Leg"] = angles(0, 0, legR.hip),
		["Left Leg"] = angles(0, 0, -(legL.hip or 0)),
	}
end

-- Clip "tenu" : deux images identiques en boucle (le moteur arrête un clip
-- non bouclé à sa fin ; c'est SpellGestures qui arrête la pose).
function PlayerPoses.Build(name)
	local pose = PlayerPoses.Poses[name]
	assert(pose, "PlayerPoses : pose inconnue " .. tostring(name))
	local settings = { Loop = true, Priority = Enum.AnimationPriority.Action, CounterRotateLegs = false }
	return {
		Rigs = {
			R15 = { Settings = settings, Timestamps = { [0] = r15Frame(pose), [0.4] = r15Frame(pose) } },
			R6 = { Settings = settings, Timestamps = { [0] = r6Frame(pose), [0.4] = r6Frame(pose) } },
		},
	}
end

return PlayerPoses
