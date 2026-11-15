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

-- ─── Animations en séquence (originales) ───────────────────────────────────
-- { loop, keys = { { temps, pose, courbe? }, ... } }. Pose vide = repos.
-- Courbes : "out" (rapide puis lent), "in", "inout" (doux), rien = linéaire.
local REST = {}

PlayerPoses.Clips = {
	-- Attente : main sur la hanche, poids qui passe d'une jambe à l'autre
	Idle = {
		loop = true,
		keys = {
			{ 0, { R = { pitch = -12, abduct = 32, swing = -12, elbow = 100 }, L = { pitch = 4, abduct = 8, elbow = 15 },
				twist = 6, legR = { hip = 4, knee = 2 }, legL = { hip = -4, knee = 10 } } },
			{ 1.6, { R = { pitch = -12, abduct = 34, swing = -12, elbow = 104 }, L = { pitch = 6, abduct = 9, elbow = 20 },
				twist = 3, lean = 1, drop = 0.04, headPitch = 2, legR = { hip = 4, knee = 6 }, legL = { hip = -4, knee = 6 } }, "inout" },
			{ 3.2, { R = { pitch = -12, abduct = 32, swing = -12, elbow = 100 }, L = { pitch = 4, abduct = 8, elbow = 15 },
				twist = 6, legR = { hip = 4, knee = 2 }, legL = { hip = -4, knee = 10 } }, "inout" },
		},
	},
	-- Saut : petite flexion puis extension, bras qui montent
	Jump = {
		keys = {
			{ 0, REST },
			{ 0.08, { R = { pitch = -25, abduct = 12, elbow = 20 }, L = { pitch = -25, abduct = 12, elbow = 20 },
				lean = 10, drop = 0.25, legR = { hip = 30, knee = 50 }, legL = { hip = 30, knee = 50 } }, "out" },
			{ 0.3, { R = { pitch = 45, abduct = 20, elbow = 30 }, L = { pitch = 45, abduct = 20, elbow = 30 },
				lean = -4, headPitch = 6, legR = { hip = 10, knee = 25 }, legL = { hip = -5, knee = 10 } }, "out" },
			{ 0.45, REST, "inout" },
		},
	},
	-- Atterrissage : les genoux absorbent
	Land = {
		keys = {
			{ 0, { R = { pitch = 30, abduct = 20, elbow = 40 }, L = { pitch = 30, abduct = 20, elbow = 40 },
				lean = 18, drop = 0.5, legR = { hip = 40, knee = 70 }, legL = { hip = 40, knee = 70 } } },
			{ 0.4, REST, "inout" },
		},
	},
	-- Coup léger reçu : la tête et le buste partent en arrière
	HitLight = {
		keys = {
			{ 0, REST },
			{ 0.06, { R = { pitch = 20, abduct = 25, elbow = 50 }, L = { pitch = 15, abduct = 25, elbow = 60 },
				lean = -14, twist = 8, headPitch = 15 }, "out" },
			{ 0.35, REST, "inout" },
		},
	},
	-- Coup lourd reçu : gros recul, bras écartés, un pas en arrière
	HitHeavy = {
		keys = {
			{ 0, REST },
			{ 0.08, { R = { pitch = 30, abduct = 50, elbow = 30 }, L = { pitch = 25, abduct = 50, elbow = 35 },
				lean = -28, drop = 0.2, headPitch = 25, legR = { hip = -15, knee = 20 }, legL = { hip = 20, knee = 30 } }, "out" },
			{ 0.3, { R = { pitch = 15, abduct = 35, elbow = 40 }, L = { pitch = 15, abduct = 35, elbow = 40 },
				lean = -16, drop = 0.1, headPitch = 12 }, "inout" },
			{ 0.6, REST, "inout" },
		},
	},
	-- Coup final reçu : chute en arrière, au sol, puis on se relève
	Knockdown = {
		keys = {
			{ 0, REST },
			{ 0.15, { R = { pitch = 30, abduct = 70, elbow = 20 }, L = { pitch = 30, abduct = 70, elbow = 20 },
				lean = -40, headPitch = 30 }, "out" },
			{ 0.4, { R = { pitch = 40, abduct = 80, elbow = 15 }, L = { pitch = 40, abduct = 80, elbow = 15 },
				lean = -80, drop = 2.3, headPitch = 10, legR = { hip = 40, knee = 20 }, legL = { hip = 25, knee = 35 } }, "in" },
			{ 1.0, { R = { pitch = 35, abduct = 75, elbow = 25 }, L = { pitch = 35, abduct = 75, elbow = 25 },
				lean = -80, drop = 2.3, headPitch = 5, legR = { hip = 45, knee = 30 }, legL = { hip = 25, knee = 40 } } },
			{ 1.3, { R = { pitch = 45, abduct = 25, elbow = 60 }, L = { pitch = 45, abduct = 25, elbow = 60 },
				lean = 25, drop = 1.2, legR = { hip = 80, knee = 110 }, legL = { hip = 20, knee = 100 } }, "inout" },
			{ 1.65, REST, "inout" },
		},
	},
	-- Flèche : on la lève au-dessus de la tête, puis on se la plante (0.7 s)
	StabArrow = {
		keys = {
			{ 0, REST },
			{ 0.3, { R = { pitch = 170, abduct = 10, elbow = 40 }, L = { pitch = 40, abduct = 20, elbow = 30 },
				lean = -6, headPitch = 15 }, "inout" },
			{ 0.6, { R = { pitch = 175, abduct = 8, elbow = 50 }, L = { pitch = 45, abduct = 20, elbow = 30 },
				lean = -8, headPitch = 18 } },
			{ 0.72, { R = { pitch = 40, swing = 30, elbow = 110 }, L = { pitch = 35, swing = 30, elbow = 100 },
				lean = 25, drop = 0.3, headPitch = -10 }, "out" },
			{ 1.0, { R = { pitch = 30, abduct = 50, elbow = 30 }, L = { pitch = 30, abduct = 50, elbow = 30 },
				lean = -15, headPitch = 20 }, "out" },
			{ 1.3, REST, "inout" },
		},
	},
	-- Flèche Requiem : plus lent et plus solennel (plongée à 1.0 s)
	StabRequiem = {
		keys = {
			{ 0, REST },
			{ 0.4, { R = { pitch = 170, abduct = 10, elbow = 35 }, L = { pitch = 140, abduct = 15, elbow = 40 },
				lean = -10, headPitch = 25 }, "inout" },
			{ 0.85, { R = { pitch = 178, abduct = 6, elbow = 45 }, L = { pitch = 150, abduct = 12, elbow = 45 },
				lean = -12, headPitch = 30, drop = -0.1 } },
			{ 1.0, { R = { pitch = 40, swing = 30, elbow = 110 }, L = { pitch = 40, swing = 30, elbow = 110 },
				lean = 28, drop = 0.4, headPitch = -15 }, "out" },
			{ 1.4, { R = { pitch = 60, abduct = 75, elbow = 15 }, L = { pitch = 60, abduct = 75, elbow = 15 },
				lean = -22, headPitch = 35, drop = -0.15 }, "out" },
			{ 1.8, REST, "inout" },
		},
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
		-- RootJoint R6 tourné de 90° : son axe Z local est la verticale
		Torso = CFrame.new(0, 0, -(p.drop or 0)) * angles(p.lean, 0, 0),
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
	local clip = PlayerPoses.Clips[name]
	if clip then
		-- séquence : une image par clé (+ courbes pour l'AnimationController
		-- et StandController qui les lisent)
		local settings = { Loop = clip.loop == true, Priority = Enum.AnimationPriority.Action, CounterRotateLegs = false }
		local r15, r6, easings = {}, {}, {}
		for _, key in ipairs(clip.keys) do
			r15[key[1]] = r15Frame(key[2])
			r6[key[1]] = r6Frame(key[2])
			easings[key[1]] = key[3]
		end
		return {
			Rigs = {
				R15 = { Settings = settings, Timestamps = r15, Easings = easings },
				R6 = { Settings = settings, Timestamps = r6, Easings = easings },
			},
		}
	end
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
