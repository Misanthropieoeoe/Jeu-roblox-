-- StandStrikes. Les coups M1 de chaque Stand (main droite, main gauche et
-- coup final du combo), décrits en "langage simple" puis convertis
-- automatiquement pour le squelette du Stand (R6 ou R15).
--
-- Utilisé par StandController : StandStrikes.Compile(standId, kind, joints)
--   kind = "LightR" | "LightL"   M1 main droite / gauche
--          "Heavy"               touche R (et 4e coup du combo M1)
--          "Barrage"             touche E (en boucle)
--          "TimeStop"            touche F (King Crimson, Made in Heaven)
--          "Heal"                touche T (Gold Experience Requiem)
--          "Idle"                pose d'attente (Stands R15, qui n'en avaient pas)
--          "Block"               garde du joueur (touche X) : bras croisés devant
--          "Anim:<Nom>"          attaques T / F / G (StandSpells, champ Anim) :
--                                StandStrikes.SpellAnims[Nom], ou la version
--                                propre au Stand si Stands[id][Nom] existe
--   joints = { [nom de la pièce] = Motor6D } (les vraies articulations du Stand)
--
-- ─── Comment écrire une pose ──────────────────────────────────────────────
-- Tous les angles sont en degrés. Valeurs absentes = 0.
--   R / L        bras droit / gauche :
--     pitch      bras vers l'avant (90 = à l'horizontale devant, 180 = en haut)
--     abduct     bras écarté sur le côté (90 = à l'horizontale sur le côté)
--     swing      bras qui balaie vers le centre du corps (crochet)
--     elbow      coude plié (R15 + coudes de Star Platinum)
--     wrist      poignet plié (R15)
--   twist        rotation du buste (+ = l'épaule droite avance)
--   lean         buste penché en avant (négatif = en arrière)
--   lunge        avancée du corps (studs)
--   drop         le corps descend (studs)
--   headPitch    tête qui regarde vers le haut / headYaw tête qui tourne
--   legR / legL  jambes : { hip = cuisse vers l'avant, knee = genou plié }
--
-- Une frappe = { duration = durée, loop = true/false, keys = { { temps, pose }, ... } }.
-- "LightL" est automatiquement le miroir de "LightR", sauf si le Stand
-- définit son propre LightL. Le M1 dure 0.42 s (le serveur touche à 0.16 s),
-- le coup final 0.45 s (le serveur touche à 0.25 s).

local StandStrikes = {}

local rad = math.rad

-- ─── Poses de base ──────────────────────────────────────────────────────────
local GUARD = {
	R = { pitch = 55, abduct = 12, swing = 10, elbow = 105 },
	L = { pitch = 55, abduct = 12, swing = 10, elbow = 105 },
}
local GUARD_ARM = GUARD.L

-- ─── Courbes et dépassement ────────────────────────────────────────────────
-- Chaque clé peut avoir une courbe (3e valeur) pour le trajet qui y MÈNE :
--   "in"    lent puis rapide        "out"   rapide puis lent (coup sec)
--   "inout" doux aux deux bouts     (rien)  linéaire
-- Les frappes utilisent : armement "inout", impact "out" (le coup part d'un
-- coup sec), léger dépassement après l'impact, retour en garde "inout".

-- Pose d'impact "poussée un peu plus loin" : bras plus tendu, buste plus
-- engagé. Donne du poids au coup avant le retour.
local function overshoot(pose)
	local o = {}
	for k, v in pairs(pose) do o[k] = v end
	local function arm(a)
		if not a then return nil end
		local c = {}
		for k, v in pairs(a) do c[k] = v end
		if (c.pitch or 0) > 60 then c.pitch = c.pitch + 4 end
		c.elbow = (c.elbow or 0) * 0.8
		return c
	end
	o.R, o.L = arm(pose.R), arm(pose.L)
	o.lean = (pose.lean or 0) * 1.2 + 2
	o.lunge = (pose.lunge or 0) * 1.2 + 0.15
	o.twist = (pose.twist or 0) * 1.12
	return o
end

-- Fabrique une frappe M1 standard de 0.42 s à partir de 3 poses.
local function light(windup, impact, follow)
	return {
		duration = 0.42,
		keys = {
			{ 0.00, GUARD },
			{ 0.08, windup, "inout" },
			{ 0.16, impact, "out" },
			{ 0.20, overshoot(impact), "out" },
			{ 0.28, follow, "inout" },
			{ 0.42, GUARD, "inout" },
		},
	}
end

-- Fabrique un coup final de 0.45 s à partir de 3 poses.
local function finisher(windup, impact, follow)
	return {
		duration = 0.45,
		keys = {
			{ 0.00, GUARD },
			{ 0.14, windup, "inout" },
			{ 0.25, impact, "out" },
			{ 0.30, overshoot(impact), "out" },
			{ 0.37, follow, "inout" },
			{ 0.45, GUARD, "inout" },
		},
	}
end

-- Coup final par défaut : gros crochet du droit qui traverse.
local DEFAULT_FINISHER = finisher(
	{ R = { pitch = 35, abduct = 65, swing = -45, elbow = 120 }, L = GUARD_ARM, twist = -45, lean = -5, drop = 0.1 },
	{ R = { pitch = 95, abduct = 10, swing = 15, elbow = 0 }, L = { pitch = 20, abduct = 20, elbow = 90 }, twist = 45, lean = 18, lunge = 1.0 },
	{ R = { pitch = 90, abduct = 8, swing = 20, elbow = 10 }, L = { pitch = 20, abduct = 20, elbow = 90 }, twist = 40, lean = 14, lunge = 0.8 }
)

-- Coup lourd "direct" (variante pour les Stands qui frappent droit).
local STRAIGHT_HEAVY = finisher(
	{ R = { pitch = 40, abduct = 30, swing = -15, elbow = 130 }, L = GUARD_ARM, twist = -40, lean = 0, drop = 0.1 },
	{ R = { pitch = 93, abduct = 4, swing = 10, elbow = 0 }, L = { pitch = 20, abduct = 20, elbow = 95 }, twist = 40, lean = 16, lunge = 1.0 },
	{ R = { pitch = 90, abduct = 4, swing = 10, elbow = 8 }, L = { pitch = 20, abduct = 20, elbow = 95 }, twist = 36, lean = 13, lunge = 0.85 }
)

-- Barrage en boucle : les deux bras alternent entre `ext` (frappe) et `ret`
-- (bras ramené). `cycle` = durée d'un aller-retour des deux bras.
local function barrage(ext, ret, opts)
	opts = opts or {}
	local cycle = opts.cycle or 0.16
	local twist, lean, lunge = opts.twist or 15, opts.lean or 10, opts.lunge or 0.2
	local a = { R = ext, L = ret, twist = twist, lean = lean, lunge = lunge }
	local b = { R = ret, L = ext, twist = -twist, lean = lean, lunge = lunge }
	return {
		duration = cycle,
		loop = true,
		-- chaque jab part sec et ralentit en fin de course
		keys = {
			{ 0, a },
			{ cycle / 2, b, "out" },
			{ cycle, a, "out" },
		},
	}
end

-- Pose tenue : on passe de la garde à `pose` en `rise` secondes et on y reste
-- jusqu'à la fin de l'attaque.
local function hold(pose, rise)
	rise = rise or 0.35
	return {
		duration = rise,
		keys = {
			{ 0, GUARD },
			{ rise * 0.6, pose, "out" },
			{ rise, pose },
		},
	}
end

local DEFAULT_BARRAGE = barrage(
	{ pitch = 90, abduct = 5, swing = 10, elbow = 5 },
	{ pitch = 50, abduct = 15, swing = 5, elbow = 110 }
)

-- Respiration en garde, pour les Stands R15 qui restaient raides.
local IDLE_BREATH = {
	R = { pitch = 58, abduct = 14, swing = 10, elbow = 110 },
	L = { pitch = 58, abduct = 14, swing = 10, elbow = 110 },
	lean = 4,
	drop = -0.06,
}
local DEFAULT_IDLE = {
	duration = 2.4,
	loop = true,
	keys = {
		{ 0, { R = GUARD.R, L = GUARD.L, lean = 2 } },
		{ 1.2, IDLE_BREATH },
		{ 2.4, { R = GUARD.R, L = GUARD.L, lean = 2 } },
	},
}

-- ─── Les Stands ─────────────────────────────────────────────────────────────
StandStrikes.Stands = {
	-- Star Platinum garde ses animations d'origine (Stand Right / Left Punch).

	-- The World : crochets larges et arrogants (MUDA).
	TheWorld = {
		Barrage = barrage(
			{ pitch = 88, abduct = 25, swing = 30, elbow = 20 },
			{ pitch = 55, abduct = 35, swing = -10, elbow = 105 },
			{ twist = 20 }
		),
		LightR = light(
			{ R = { pitch = 70, abduct = 60, swing = -25, elbow = 95 }, L = GUARD_ARM, twist = -20, lean = 5 },
			{ R = { pitch = 82, abduct = 70, swing = 70, elbow = 70 }, L = GUARD_ARM, twist = 30, lean = 10, lunge = 0.4 },
			{ R = { pitch = 78, abduct = 60, swing = 85, elbow = 85 }, L = GUARD_ARM, twist = 35, lean = 8, lunge = 0.3 }
		),
	},

	-- The World AU : uppercuts brutaux.
	TheWorldAU = {
		Barrage = barrage(
			{ pitch = 115, abduct = 10, swing = 12, elbow = 30 },
			{ pitch = 30, abduct = 15, elbow = 115 },
			{ twist = 18, lean = 6 }
		),
		LightR = light(
			{ R = { pitch = -10, abduct = 12, elbow = 115 }, L = GUARD_ARM, twist = -15, lean = 14, drop = 0.3 },
			{ R = { pitch = 150, abduct = 10, swing = 15, elbow = 35 }, L = GUARD_ARM, twist = 25, lean = -12, drop = -0.15, headPitch = 10 },
			{ R = { pitch = 140, abduct = 10, swing = 10, elbow = 45 }, L = GUARD_ARM, twist = 20, lean = -8 }
		),
		Finisher = finisher(
			{ R = { pitch = -20, abduct = 15, elbow = 120 }, L = GUARD_ARM, twist = -25, lean = 20, drop = 0.45 },
			{ R = { pitch = 170, abduct = 5, swing = 10, elbow = 10 }, L = { pitch = 10, abduct = 25, elbow = 80 }, twist = 30, lean = -18, drop = -0.4, headPitch = 20, lunge = 0.6 },
			{ R = { pitch = 165, abduct = 5, elbow = 15 }, L = { pitch = 10, abduct = 25, elbow = 80 }, twist = 25, lean = -14, drop = -0.3, headPitch = 15 }
		),
	},

	-- Crazy Diamond : directs puissants avec pas en avant (DORA).
	CrazyDiamond = {
		Barrage = barrage(
			{ pitch = 92, abduct = 4, swing = 12, elbow = 0 },
			{ pitch = 45, abduct = 18, swing = 5, elbow = 120 },
			{ twist = 22, lean = 12, lunge = 0.35 }
		),
		LightR = light(
			{ R = { pitch = 40, abduct = 20, swing = -10, elbow = 125 }, L = GUARD_ARM, twist = -25, lean = 5, drop = 0.1,
				legR = { hip = -15, knee = 20 }, legL = { hip = 20, knee = 25 } },
			{ R = { pitch = 92, abduct = 5, swing = 12, elbow = 5, wrist = -5 }, L = { pitch = 45, abduct = 15, elbow = 115 }, twist = 35, lean = 12, lunge = 0.6,
				legR = { hip = -25, knee = 15 }, legL = { hip = 30, knee = 20 } },
			{ R = { pitch = 88, abduct = 6, swing = 10, elbow = 25 }, L = GUARD_ARM, twist = 30, lean = 10, lunge = 0.4,
				legR = { hip = -20, knee = 15 }, legL = { hip = 25, knee = 20 } }
		),
		Finisher = finisher(
			{ R = { pitch = 30, abduct = 25, swing = -20, elbow = 130 }, L = GUARD_ARM, twist = -40, lean = 0, drop = 0.25,
				legR = { hip = -20, knee = 35 }, legL = { hip = 25, knee = 40 } },
			{ R = { pitch = 95, abduct = 4, swing = 10, elbow = 0 }, L = { pitch = 15, abduct = 25, elbow = 95 }, twist = 50, lean = 20, lunge = 1.2,
				legR = { hip = -35, knee = 10 }, legL = { hip = 45, knee = 25 } },
			{ R = { pitch = 92, abduct = 4, swing = 10, elbow = 8 }, L = { pitch = 15, abduct = 25, elbow = 95 }, twist = 45, lean = 16, lunge = 1.0,
				legR = { hip = -30, knee = 10 }, legL = { hip = 40, knee = 25 } }
		),
	},

	-- Silver Chariot : escrimeur. Droite = estoc à la rapière, gauche = taillade
	-- (toujours avec le bras droit, qui tient la rapière).
	SilverChariot = {
		-- Rapid Stabs : seul le bras droit (la rapière) pique, très vite, en
		-- visant un peu à gauche puis un peu à droite.
		Barrage = {
			duration = 0.24,
			loop = true,
			keys = {
				{ 0.00, { R = { pitch = 90, swing = -8, elbow = 0 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 18, lean = 8, lunge = 0.5 } },
				{ 0.06, { R = { pitch = 70, swing = 0, elbow = 85 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 5, lean = 6, lunge = 0.3 } },
				{ 0.12, { R = { pitch = 92, swing = 12, elbow = 0 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 22, lean = 8, lunge = 0.5 } },
				{ 0.18, { R = { pitch = 70, swing = 0, elbow = 85 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 5, lean = 6, lunge = 0.3 } },
				{ 0.24, { R = { pitch = 90, swing = -8, elbow = 0 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 18, lean = 8, lunge = 0.5 } },
			},
		},
		LightR = light(
			{ R = { pitch = 60, abduct = 5, swing = -5, elbow = 110, wrist = -10 }, L = { pitch = -15, abduct = 40, elbow = 60 }, twist = -30, lunge = -0.2,
				legR = { hip = 10, knee = 15 }, legL = { hip = -10, knee = 10 } },
			{ R = { pitch = 90, abduct = 0, swing = 5, elbow = 0 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 25, lean = 8, lunge = 0.9,
				legR = { hip = 45, knee = 35 }, legL = { hip = -30, knee = 8 } },
			{ R = { pitch = 88, swing = 5, elbow = 10 }, L = { pitch = -25, abduct = 45, elbow = 50 }, twist = 22, lean = 6, lunge = 0.7,
				legR = { hip = 40, knee = 30 }, legL = { hip = -25, knee = 8 } }
		),
		LightL = light(
			{ R = { pitch = 85, abduct = 65, swing = -40, elbow = 20 }, L = { pitch = -15, abduct = 40, elbow = 60 }, twist = -25, lean = 4 },
			{ R = { pitch = 85, abduct = 20, swing = 75, elbow = 10 }, L = { pitch = -20, abduct = 45, elbow = 55 }, twist = 30, lean = 8, lunge = 0.4 },
			{ R = { pitch = 80, abduct = 15, swing = 85, elbow = 15 }, L = { pitch = -20, abduct = 45, elbow = 55 }, twist = 32, lean = 6, lunge = 0.3 }
		),
		Finisher = finisher(
			{ R = { pitch = 50, abduct = 5, swing = -10, elbow = 130, wrist = -15 }, L = { pitch = -20, abduct = 45, elbow = 55 }, twist = -40, lunge = -0.4, drop = 0.15,
				legR = { hip = 15, knee = 30 }, legL = { hip = -15, knee = 25 } },
			{ R = { pitch = 92, elbow = 0 }, L = { pitch = -35, abduct = 50, elbow = 30 }, twist = 30, lean = 14, lunge = 1.5, drop = 0.25,
				legR = { hip = 60, knee = 45 }, legL = { hip = -40, knee = 5 } },
			{ R = { pitch = 90, elbow = 5 }, L = { pitch = -35, abduct = 50, elbow = 30 }, twist = 28, lean = 12, lunge = 1.3, drop = 0.2,
				legR = { hip = 55, knee = 40 }, legL = { hip = -35, knee = 5 } }
		),
	},

	-- Killer Queen : précis et élégant. Droite = direct net,
	-- gauche = paume qui "touche" (pour poser une bombe).
	KillerQueen = {
		Barrage = barrage(
			{ pitch = 90, abduct = 5, swing = 10, elbow = 3 },
			{ pitch = 50, abduct = 15, elbow = 115 },
			{ twist = 14, lean = 9 }
		),
		-- Bomb Punch : grosse frappe, la main gauche reste ouverte (détonateur).
		Heavy = finisher(
			{ R = { pitch = 35, abduct = 30, swing = -15, elbow = 135 }, L = { pitch = 60, abduct = 20, elbow = 90, wrist = 40 }, twist = -40, drop = 0.1 },
			{ R = { pitch = 93, abduct = 4, swing = 10, elbow = 0 }, L = { pitch = 60, abduct = 20, elbow = 90, wrist = 40 }, twist = 40, lean = 16, lunge = 1.0 },
			{ R = { pitch = 90, abduct = 4, swing = 10, elbow = 8 }, L = { pitch = 60, abduct = 20, elbow = 90, wrist = 40 }, twist = 36, lean = 13, lunge = 0.85 }
		),
		LightR = light(
			{ R = { pitch = 50, abduct = 15, elbow = 115 }, L = GUARD_ARM, twist = -15, lean = 3 },
			{ R = { pitch = 92, abduct = 4, swing = 8, elbow = 0 }, L = GUARD_ARM, twist = 22, lean = 8, lunge = 0.4 },
			{ R = { pitch = 88, abduct = 4, swing = 8, elbow = 15 }, L = GUARD_ARM, twist = 18, lean = 6, lunge = 0.3 }
		),
		LightL = light(
			{ L = { pitch = 45, abduct = 15, elbow = 110, wrist = 20 }, R = GUARD_ARM, twist = 15, lean = 3 },
			{ L = { pitch = 95, abduct = 5, swing = 10, elbow = 5, wrist = 60 }, R = GUARD_ARM, twist = -20, lean = 10, lunge = 0.5 },
			{ L = { pitch = 92, abduct = 5, swing = 10, elbow = 10, wrist = 55 }, R = GUARD_ARM, twist = -18, lean = 8, lunge = 0.45 }
		),
	},

	-- Gold Experience : direct du droit, coup de pied du gauche (MUDA).
	GoldExperience = {
		Barrage = DEFAULT_BARRAGE,
		Heavy = STRAIGHT_HEAVY, -- Life Punch
		LightR = light(
			{ R = { pitch = 45, abduct = 15, elbow = 120 }, L = GUARD_ARM, twist = -18, lean = 4 },
			{ R = { pitch = 90, abduct = 5, swing = 10, elbow = 5 }, L = GUARD_ARM, twist = 28, lean = 10, lunge = 0.5 },
			{ R = { pitch = 86, abduct = 5, swing = 10, elbow = 18 }, L = GUARD_ARM, twist = 24, lean = 8, lunge = 0.4 }
		),
		LightL = light(
			{ R = GUARD_ARM, L = GUARD_ARM, twist = 10, lean = -6, legL = { hip = 60, knee = 90 } },
			{ R = { pitch = 40, abduct = 30, elbow = 100 }, L = { pitch = 30, abduct = 35, elbow = 90 }, twist = -15, lean = -14, lunge = 0.3, legL = { hip = 100, knee = 5 } },
			{ R = GUARD_ARM, L = GUARD_ARM, twist = -10, lean = -10, legL = { hip = 85, knee = 25 } }
		),
	},

	-- Gold Experience Requiem : paume tendue et coup de pied haut.
	GoldExperienceRequiem = {
		Barrage = barrage(
			{ pitch = 92, abduct = 5, swing = 8, elbow = 0, wrist = 60 },
			{ pitch = 45, abduct = 18, elbow = 115, wrist = 20 },
			{ twist = 14, lean = 8 }
		),
		-- Requiem Punch : paume ouverte projetée.
		Heavy = finisher(
			{ R = { pitch = 35, abduct = 25, elbow = 130, wrist = 25 }, L = GUARD_ARM, twist = -35 },
			{ R = { pitch = 93, abduct = 4, swing = 8, elbow = 0, wrist = 70 }, L = { pitch = 20, abduct = 25, elbow = 90 }, twist = 35, lean = 14, lunge = 1.0 },
			{ R = { pitch = 90, abduct = 4, swing = 8, elbow = 5, wrist = 65 }, L = { pitch = 20, abduct = 25, elbow = 90 }, twist = 32, lean = 12, lunge = 0.9 }
		),
		-- Life Channel : le bras droit se lève devant la poitrine, avant-bras
		-- replié, paume ouverte, et "pulse" pendant la canalisation.
		Heal = {
			duration = 1.3,
			keys = {
				{ 0.00, GUARD },
				{ 0.14, { R = { pitch = 42, abduct = -10, swing = 10, elbow = 50, wrist = 10 }, L = GUARD_ARM, headPitch = 5, headYaw = -8 } },
				{ 0.34, { R = { pitch = 58, abduct = -15, swing = 15, elbow = 104, wrist = 20 }, L = GUARD_ARM, headPitch = 8, headYaw = -12 } },
				{ 0.62, { R = { pitch = 54, abduct = -12, swing = 12, elbow = 92, wrist = 15 }, L = GUARD_ARM, headPitch = 6, headYaw = -10 } },
				{ 0.88, { R = { pitch = 58, abduct = -15, swing = 15, elbow = 106, wrist = 20 }, L = GUARD_ARM, headPitch = 8, headYaw = -12 } },
				{ 1.08, { R = { pitch = 26, abduct = -5, swing = 5, elbow = 34, wrist = 5 }, L = GUARD_ARM, headPitch = 3, headYaw = -5 } },
				{ 1.30, GUARD },
			},
		},
		LightR = light(
			{ R = { pitch = 40, abduct = 20, elbow = 120, wrist = 20 }, L = GUARD_ARM, twist = -20, lean = 2 },
			{ R = { pitch = 92, abduct = 5, swing = 8, elbow = 0, wrist = 65 }, L = GUARD_ARM, twist = 25, lean = 8, lunge = 0.5 },
			{ R = { pitch = 90, abduct = 5, swing = 8, elbow = 8, wrist = 60 }, L = GUARD_ARM, twist = 22, lean = 6, lunge = 0.45 }
		),
		LightL = light(
			{ R = GUARD_ARM, L = GUARD_ARM, twist = 15, lean = -8, legL = { hip = 70, knee = 100 } },
			{ R = { pitch = 30, abduct = 40, elbow = 80 }, L = { pitch = 20, abduct = 45, elbow = 70 }, twist = -20, lean = -20, lunge = 0.3, legL = { hip = 125, knee = 5 } },
			{ R = GUARD_ARM, L = GUARD_ARM, twist = -12, lean = -14, legL = { hip = 105, knee = 20 } }
		),
	},

	-- King Crimson : main-lance qui transperce, et tranchant de la main.
	KingCrimson = {
		-- CRIMSON Barrage : directs main-lance.
		Barrage = barrage(
			{ pitch = 92, abduct = 3, swing = 8, elbow = 0 },
			{ pitch = 40, abduct = 15, elbow = 125 },
			{ twist = 18, lean = 12, lunge = 0.3 }
		),
		-- Time Erase : un bras levé vers le ciel, l'autre en garde, tête haute.
		TimeStop = hold({
			R = { pitch = 160, abduct = 10, elbow = 30, wrist = 10 },
			L = { pitch = 40, abduct = 30, elbow = 90 },
			lean = -10, headPitch = 15,
		}, 0.45),
		LightR = light(
			{ R = { pitch = 35, abduct = 15, elbow = 130, wrist = 0 }, L = GUARD_ARM, twist = -25, lean = 4, lunge = -0.1 },
			{ R = { pitch = 92, abduct = 3, swing = 6, elbow = 0, wrist = 0 }, L = { pitch = 30, abduct = 20, elbow = 100 }, twist = 30, lean = 15, lunge = 0.8 },
			{ R = { pitch = 90, abduct = 3, swing = 6, elbow = 5 }, L = { pitch = 30, abduct = 20, elbow = 100 }, twist = 28, lean = 13, lunge = 0.7 }
		),
		LightL = light(
			{ L = { pitch = 165, abduct = 15, elbow = 20 }, R = GUARD_ARM, twist = 20, lean = -6 },
			{ L = { pitch = 55, abduct = 8, swing = 20, elbow = 10 }, R = GUARD_ARM, twist = -20, lean = 16, lunge = 0.5 },
			{ L = { pitch = 40, abduct = 8, swing = 25, elbow = 15 }, R = GUARD_ARM, twist = -18, lean = 14, lunge = 0.4 }
		),
		Finisher = finisher(
			{ R = { pitch = 25, abduct = 20, elbow = 135 }, L = GUARD_ARM, twist = -40, lean = 0, lunge = -0.3 },
			{ R = { pitch = 93, elbow = 0 }, L = { pitch = 15, abduct = 30, elbow = 90 }, twist = 40, lean = 22, lunge = 1.5 },
			{ R = { pitch = 90, elbow = 3 }, L = { pitch = 15, abduct = 30, elbow = 90 }, twist = 38, lean = 20, lunge = 1.4 }
		),
	},

	-- Hierophant Green : gestes de lancer (Emerald Splash), pas de corps-à-corps.
	HierophantGreen = {
		-- Emerald Barrage : lancers alternés des deux mains.
		Barrage = barrage(
			{ pitch = 95, abduct = 30, swing = 35, elbow = 10, wrist = 25 },
			{ pitch = 30, abduct = 45, swing = -30, elbow = 95, wrist = -30 },
			{ cycle = 0.22, twist = 12, lean = 4, lunge = 0.1 }
		),
		LightR = light(
			{ R = { pitch = 30, abduct = 45, swing = -30, elbow = 95, wrist = -30 }, L = GUARD_ARM, twist = -15, lean = -3 },
			{ R = { pitch = 95, abduct = 30, swing = 35, elbow = 10, wrist = 25 }, L = GUARD_ARM, twist = 15, lean = 4, lunge = 0.2 },
			{ R = { pitch = 90, abduct = 28, swing = 40, elbow = 15, wrist = 20 }, L = GUARD_ARM, twist = 15, lean = 3 }
		),
		Finisher = finisher(
			{ R = { pitch = 30, abduct = 50, swing = -35, elbow = 100, wrist = -30 }, L = { pitch = 30, abduct = 50, swing = -35, elbow = 100, wrist = -30 }, lean = -8, drop = 0.1 },
			{ R = { pitch = 95, abduct = 15, swing = 25, elbow = 5, wrist = 35 }, L = { pitch = 95, abduct = 15, swing = 25, elbow = 5, wrist = 35 }, lean = 8, lunge = 0.5 },
			{ R = { pitch = 92, abduct = 15, swing = 25, elbow = 10, wrist = 30 }, L = { pitch = 92, abduct = 15, swing = 25, elbow = 10, wrist = 30 }, lean = 6, lunge = 0.4 }
		),
	},

	-- Magician's Red : griffes de feu en diagonale.
	MagiciansRed = {
		-- Flame Barrage : griffes de feu alternées.
		Barrage = barrage(
			{ pitch = 40, abduct = 10, swing = 60, elbow = 20 },
			{ pitch = 140, abduct = 40, swing = -20, elbow = 30 },
			{ cycle = 0.2, twist = 20, lean = 10 }
		),
		-- Crossfire Hurricane : les deux mains partent de la poitrine et
		-- projettent les flammes devant.
		Heavy = finisher(
			{ R = { pitch = 20, abduct = 30, elbow = 120 }, L = { pitch = 20, abduct = 30, elbow = 120 }, lean = -8, drop = 0.1 },
			{ R = { pitch = 90, abduct = 10, swing = 20, elbow = 10, wrist = 40 }, L = { pitch = 90, abduct = 10, swing = 20, elbow = 10, wrist = 40 }, lean = 10, lunge = 0.4 },
			{ R = { pitch = 88, abduct = 10, swing = 20, elbow = 15, wrist = 35 }, L = { pitch = 88, abduct = 10, swing = 20, elbow = 15, wrist = 35 }, lean = 8, lunge = 0.3 }
		),
		LightR = light(
			{ R = { pitch = 150, abduct = 40, swing = -20, elbow = 30 }, L = GUARD_ARM, twist = -20, lean = -5 },
			{ R = { pitch = 40, abduct = 10, swing = 60, elbow = 20 }, L = GUARD_ARM, twist = 30, lean = 15, lunge = 0.4 },
			{ R = { pitch = 20, abduct = 8, swing = 70, elbow = 25 }, L = GUARD_ARM, twist = 30, lean = 12, lunge = 0.3 }
		),
	},

	-- Sticky Fingers : direct du droit, crochet du gauche (ARRIVEDERCI).
	StickyFingers = {
		Barrage = barrage(
			{ pitch = 92, abduct = 4, swing = 10, elbow = 0 },
			{ pitch = 50, abduct = 15, elbow = 115 },
			{ twist = 18, lean = 10 }
		),
		-- Zipper Punch : direct qui va très loin (le bras se "dézippe").
		Heavy = finisher(
			{ R = { pitch = 40, abduct = 25, swing = -15, elbow = 130 }, L = GUARD_ARM, twist = -40 },
			{ R = { pitch = 92, abduct = 3, swing = 8, elbow = 0 }, L = { pitch = 20, abduct = 20, elbow = 95 }, twist = 40, lean = 18, lunge = 1.4 },
			{ R = { pitch = 90, abduct = 3, swing = 8, elbow = 5 }, L = { pitch = 20, abduct = 20, elbow = 95 }, twist = 36, lean = 15, lunge = 1.2 }
		),
		LightR = light(
			{ R = { pitch = 45, abduct = 15, elbow = 120 }, L = GUARD_ARM, twist = -20, lean = 4 },
			{ R = { pitch = 92, abduct = 4, swing = 10, elbow = 0 }, L = GUARD_ARM, twist = 30, lean = 10, lunge = 0.5 },
			{ R = { pitch = 88, abduct = 4, swing = 10, elbow = 15 }, L = GUARD_ARM, twist = 26, lean = 8, lunge = 0.4 }
		),
		LightL = light(
			{ L = { pitch = 70, abduct = 60, swing = -25, elbow = 95 }, R = GUARD_ARM, twist = 20, lean = 5 },
			{ L = { pitch = 82, abduct = 65, swing = 70, elbow = 85 }, R = GUARD_ARM, twist = -32, lean = 10, lunge = 0.4 },
			{ L = { pitch = 78, abduct = 60, swing = 80, elbow = 90 }, R = GUARD_ARM, twist = -34, lean = 8, lunge = 0.3 }
		),
	},

	-- Made in Heaven : tranchants de la main ultra-rapides (bras seulement).
	MadeInHeaven = {
		-- Heaven Barrage : tranchants très rapides.
		Barrage = barrage(
			{ pitch = 75, abduct = 5, swing = 15, elbow = 0 },
			{ pitch = 150, abduct = 15, elbow = 20 },
			{ cycle = 0.12, twist = 12, lean = 10 }
		),
		-- Time Acceleration : bras grands ouverts, tête vers le ciel.
		TimeStop = hold({
			R = { pitch = 25, abduct = 80, elbow = 15 },
			L = { pitch = 25, abduct = 80, elbow = 15 },
			lean = -15, headPitch = 25,
		}, 0.5),
		LightR = light(
			{ R = { pitch = 160, abduct = 15, elbow = 10 }, L = GUARD_ARM, twist = -10, lean = -6 },
			{ R = { pitch = 60, abduct = 5, swing = 10, elbow = 0 }, L = GUARD_ARM, twist = 20, lean = 12, lunge = 0.5 },
			{ R = { pitch = 45, abduct = 5, swing = 12, elbow = 5 }, L = GUARD_ARM, twist = 18, lean = 10, lunge = 0.4 }
		),
	},
}

-- ─── Personnalité de chaque Stand : pose iconique, attente, invocation ──────
-- Pose : tenue après l'invocation (état "Pose"). Attente : version détendue
-- de la pose qui "respire" (état "Idle"). Invocation : le Stand se déploie
-- (accroupi, bras croisés -> s'ouvre) et finit dans sa pose.

-- Version détendue d'une pose (angles réduits)
local function relaxed(pose, k)
	local o = {}
	for key, v in pairs(pose) do
		if type(v) == "number" then
			o[key] = v * k
		elseif type(v) == "table" then
			local c = {}
			for kk, vv in pairs(v) do c[kk] = vv * k end
			o[key] = c
		end
	end
	return o
end

local function breathe(pose)
	local a = relaxed(pose, 0.7)
	local b = relaxed(pose, 0.76)
	b.drop = (b.drop or 0) - 0.06
	b.headPitch = (b.headPitch or 0) + 2
	return {
		duration = 2.8,
		loop = true,
		keys = {
			{ 0, a },
			{ 1.4, b, "inout" },
			{ 2.8, a, "inout" },
		},
	}
end

local POSES = {
	-- Star Platinum : doigt pointé vers l'adversaire, poing sur la hanche
	StarPlatinum = { R = { pitch = 75, abduct = 5, swing = 10, elbow = 0 }, L = { pitch = -15, abduct = 35, elbow = 105 },
		twist = 15, lean = -6, headPitch = 8 },
	-- The World : bras croisés, menton levé, arrogant
	TheWorld = { R = { pitch = 85, swing = 70, elbow = 100 }, L = { pitch = 80, swing = 70, elbow = 105 },
		twist = 15, lean = -12, headPitch = 18 },
	-- The World AU : penché comme un prédateur, une griffe tendue
	TheWorldAU = { R = { pitch = 80, abduct = 15, swing = 10, elbow = 30, wrist = 40 }, L = { pitch = -25, abduct = 30, elbow = 50 },
		twist = 20, lean = 25, drop = 0.3, headPitch = 10, legR = { hip = 25, knee = 40 }, legL = { hip = -10, knee = 25 } },
	-- Crazy Diamond : poing levé sur le côté, l'autre en garde
	CrazyDiamond = { R = { pitch = 80, abduct = 70, elbow = 110 }, L = { pitch = 60, abduct = 15, swing = 20, elbow = 110 },
		twist = -15, lean = 4, headPitch = 4 },
	-- Silver Chariot : en garde d'escrimeur, rapière tendue
	SilverChariot = { R = { pitch = 92, elbow = 0 }, L = { pitch = 120, abduct = 30, elbow = 90 },
		twist = -25, lean = 4, legR = { hip = 40, knee = 30 }, legL = { hip = -25, knee = 10 } },
	-- Killer Queen : main levée paume vers le ciel, l'autre derrière le dos
	KillerQueen = { R = { pitch = 100, swing = 40, elbow = 120, wrist = 40 }, L = { pitch = -30, abduct = 10, swing = -30, elbow = 80 },
		twist = 10, lean = -4, headYaw = 15 },
	-- Gold Experience : bras ouverts, paumes vers le haut
	GoldExperience = { R = { pitch = 30, abduct = 45, elbow = 20, wrist = -20 }, L = { pitch = 30, abduct = 45, elbow = 20, wrist = -20 },
		lean = -4, headPitch = 10 },
	-- GER : un bras vers le ciel, l'autre vers le sol, en lévitation
	GoldExperienceRequiem = { R = { pitch = 165, abduct = 10, elbow = 10 }, L = { pitch = -10, abduct = 30, elbow = 10 },
		lean = -6, headPitch = 20, drop = -0.25 },
	-- King Crimson : bras croisés bas, penché en avant, menaçant
	KingCrimson = { R = { pitch = 45, swing = 60, elbow = 70 }, L = { pitch = 45, swing = 60, elbow = 75 },
		lean = 12, headPitch = -10, twist = 5 },
	-- Hierophant Green : mains levées devant, doigts écartés
	HierophantGreen = { R = { pitch = 110, abduct = 30, swing = 25, elbow = 30, wrist = 30 }, L = { pitch = 110, abduct = 30, swing = 25, elbow = 30, wrist = 30 },
		lean = -8, headPitch = 6 },
	-- Magician's Red : bras écartés comme des ailes
	MagiciansRed = { R = { pitch = 20, abduct = 85, elbow = 30 }, L = { pitch = 20, abduct = 85, elbow = 30 },
		lean = -10, headPitch = 15 },
	-- Sticky Fingers : poing bas en avant, bras en travers de la poitrine
	StickyFingers = { R = { pitch = 70, abduct = 5, elbow = 40 }, L = { pitch = 85, swing = 60, elbow = 90 },
		twist = 20, lean = 4 },
	-- Made in Heaven : penché, bras en arrière, prêt à foncer
	MadeInHeaven = { R = { pitch = -40, abduct = 15, elbow = 20 }, L = { pitch = -40, abduct = 20, elbow = 20 },
		lean = 20, headPitch = 10, drop = 0.2, legR = { hip = 30, knee = 40 }, legL = { hip = -10, knee = 30 } },
}
local DEFAULT_POSE = { R = GUARD.R, L = GUARD.L, lean = 4 }

-- Invocation : accroupi bras croisés, se relève, s'ouvre, finit en pose
local function makeSummon(pose)
	return {
		duration = 1.25,
		keys = {
			{ 0, { R = { pitch = 60, swing = 50, elbow = 120 }, L = { pitch = 60, swing = 50, elbow = 120 },
				lean = 40, drop = 1.5, headPitch = -20, legR = { hip = 60, knee = 90 }, legL = { hip = 60, knee = 90 } } },
			{ 0.45, { R = { pitch = 50, swing = 40, elbow = 110 }, L = { pitch = 50, swing = 40, elbow = 110 },
				lean = 15, drop = 0.6, legR = { hip = 25, knee = 40 }, legL = { hip = 25, knee = 40 } }, "inout" },
			{ 0.8, { R = { pitch = 40, abduct = 85, elbow = 10 }, L = { pitch = 40, abduct = 85, elbow = 10 },
				lean = -12, headPitch = 15, drop = -0.2 }, "out" },
			{ 1.25, pose, "inout" },
		},
	}
end

for standId, pose in pairs(POSES) do
	StandStrikes.Stands[standId] = StandStrikes.Stands[standId] or {}
	local def = StandStrikes.Stands[standId]
	def.Pose = def.Pose or hold(pose, 0.35)
	def.Idle = def.Idle or breathe(pose)
	def.Summon = def.Summon or makeSummon(pose)
end

-- Star Platinum : ses propres coups (remplacent les clips d'origine)
local SP = StandStrikes.Stands.StarPlatinum
SP.LightR = light(
	{ R = { pitch = 40, abduct = 15, elbow = 125 }, L = GUARD_ARM, twist = -20, lean = 4 },
	{ R = { pitch = 93, abduct = 3, swing = 10, elbow = 0 }, L = { pitch = 55, abduct = 15, elbow = 115 }, twist = 32, lean = 12, lunge = 0.55 },
	{ R = { pitch = 88, abduct = 3, swing = 10, elbow = 15 }, L = GUARD_ARM, twist = 26, lean = 9, lunge = 0.4 }
)
SP.Heavy = finisher(
	{ R = { pitch = 30, abduct = 35, swing = -20, elbow = 135 }, L = GUARD_ARM, twist = -45, lean = -4, drop = 0.15 },
	{ R = { pitch = 94, abduct = 3, swing = 10, elbow = 0 }, L = { pitch = 20, abduct = 25, elbow = 95 }, twist = 48, lean = 20, lunge = 1.2 },
	{ R = { pitch = 90, abduct = 3, swing = 10, elbow = 6 }, L = { pitch = 20, abduct = 25, elbow = 95 }, twist = 42, lean = 16, lunge = 1.0 }
)

-- Arrêts du temps : poses de commandement
SP.TimeStop = hold({ R = { pitch = 90, abduct = 10, elbow = 5, wrist = 60 }, L = { pitch = -20, abduct = 30, elbow = 100 },
	twist = 15, lean = -8, headPitch = 12 }, 0.4)
StandStrikes.Stands.TheWorld.TimeStop = hold({ R = { pitch = 60, abduct = 80, elbow = 10 }, L = { pitch = 60, abduct = 80, elbow = 10 },
	lean = -18, headPitch = 25 }, 0.45)
StandStrikes.Stands.TheWorldAU.TimeStop = hold({ R = { pitch = 165, abduct = 10, elbow = 60 }, L = { pitch = 30, abduct = 40, elbow = 90 },
	lean = -10, headPitch = 22, twist = -10 }, 0.4)

-- ─── Animations des attaques T / F / G (StandSpells) ───────────────────────
-- Communes à tous les Stands. Un Stand peut avoir sa propre version en
-- ajoutant une entrée du même nom dans StandStrikes.Stands[id].
-- La dernière pose est tenue jusqu'à la fin de l'attaque.
local function spell(windup, release, follow, tWindup, tRelease, tFollow)
	local keys = {
		{ 0, GUARD },
		{ tWindup, windup, "inout" },
		{ tRelease, release, "out" },
	}
	local tOver = tRelease + 0.05
	if tOver < tFollow - 0.05 then
		table.insert(keys, { tOver, overshoot(release), "out" })
	end
	table.insert(keys, { tFollow, follow, "inout" })
	return { duration = tFollow, keys = keys }
end

StandStrikes.SpellAnims = {
	-- Bras tendu, doigt pointé (Star Finger, Red Bind, Tentacle Bind…)
	Point = spell(
		{ R = { pitch = 40, abduct = 20, elbow = 120 }, L = GUARD_ARM, twist = -20 },
		{ R = { pitch = 92, abduct = 2, swing = 6, elbow = 0, wrist = 0 }, L = { pitch = 25, abduct = 25, elbow = 95 }, twist = 25, lean = 8, lunge = 0.4 },
		{ R = { pitch = 90, abduct = 2, swing = 6, elbow = 3 }, L = { pitch = 25, abduct = 25, elbow = 95 }, twist = 22, lean = 7, lunge = 0.35 },
		0.12, 0.25, 0.6
	),
	-- Pichenette depuis la poitrine (Bearing Shot, Life Shot)
	Flick = spell(
		{ R = { pitch = 30, abduct = 10, swing = 20, elbow = 125, wrist = -30 }, L = GUARD_ARM, twist = -10 },
		{ R = { pitch = 95, abduct = 4, swing = 8, elbow = 10, wrist = 35 }, L = GUARD_ARM, twist = 18, lean = 6, lunge = 0.3 },
		{ R = { pitch = 90, abduct = 4, swing = 8, elbow = 15, wrist = 30 }, L = GUARD_ARM, twist = 15, lean = 5 },
		0.1, 0.2, 0.5
	),
	-- Lancer par-dessus l'épaule (couteaux, éclats, Sheer Heart Attack)
	Throw = spell(
		{ R = { pitch = 160, abduct = 30, swing = -10, elbow = 90 }, L = { pitch = 60, abduct = 20, elbow = 60 }, twist = -30, lean = -8 },
		{ R = { pitch = 70, abduct = 10, swing = 25, elbow = 15, wrist = 20 }, L = { pitch = 20, abduct = 25, elbow = 80 }, twist = 32, lean = 14, lunge = 0.5 },
		{ R = { pitch = 55, abduct = 10, swing = 30, elbow = 20 }, L = { pitch = 20, abduct = 25, elbow = 80 }, twist = 30, lean = 12, lunge = 0.4 },
		0.12, 0.24, 0.6
	),
	-- Les deux bras au-dessus de la tête puis on écrase (Road Roller, Tree Growth)
	Slam = spell(
		{ R = { pitch = 170, abduct = 15, elbow = 30 }, L = { pitch = 170, abduct = 15, elbow = 30 }, lean = -14, drop = -0.4, headPitch = 15 },
		{ R = { pitch = 40, abduct = 8, swing = 10, elbow = 10 }, L = { pitch = 40, abduct = 8, swing = 10, elbow = 10 }, lean = 28, drop = 0.35, lunge = 0.6 },
		{ R = { pitch = 35, abduct = 8, swing = 10, elbow = 15 }, L = { pitch = 35, abduct = 8, swing = 10, elbow = 15 }, lean = 24, drop = 0.3, lunge = 0.5 },
		0.3, 0.5, 0.9
	),
	-- Ruée : penché en avant, poing devant (Dash)
	Dash = spell(
		{ R = { pitch = 50, abduct = 15, elbow = 120 }, L = { pitch = -20, abduct = 20, elbow = 60 }, twist = -15, lean = 15, drop = 0.15 },
		{ R = { pitch = 95, abduct = 4, swing = 8, elbow = 0 }, L = { pitch = -35, abduct = 25, elbow = 40 }, twist = 20, lean = 30, lunge = 1.0,
			legR = { hip = -25, knee = 20 }, legL = { hip = -40, knee = 30 } },
		{ R = { pitch = 92, abduct = 4, swing = 8, elbow = 5 }, L = { pitch = -30, abduct = 25, elbow = 45 }, twist = 18, lean = 26, lunge = 0.9,
			legR = { hip = -20, knee = 20 }, legL = { hip = -35, knee = 30 } },
		0.08, 0.18, 0.55
	),
	-- Bras levés, tête vers le ciel (soins, bonus, zones autour de soi)
	Raise = spell(
		{ R = { pitch = 60, abduct = 30, elbow = 80 }, L = { pitch = 60, abduct = 30, elbow = 80 }, lean = 6, drop = 0.15 },
		{ R = { pitch = 140, abduct = 40, elbow = 20, wrist = 15 }, L = { pitch = 140, abduct = 40, elbow = 20, wrist = 15 }, lean = -12, headPitch = 22, drop = -0.25 },
		{ R = { pitch = 135, abduct = 42, elbow = 25, wrist = 15 }, L = { pitch = 135, abduct = 42, elbow = 25, wrist = 15 }, lean = -10, headPitch = 20, drop = -0.2 },
		0.15, 0.35, 0.9
	),
	-- Deux mains depuis la poitrine vers l'avant (Emerald Splash, flammes)
	ChargeBlast = spell(
		{ R = { pitch = 25, abduct = 30, swing = -10, elbow = 120, wrist = -20 }, L = { pitch = 25, abduct = 30, swing = -10, elbow = 120, wrist = -20 }, lean = -8, drop = 0.1 },
		{ R = { pitch = 92, abduct = 12, swing = 22, elbow = 8, wrist = 40 }, L = { pitch = 92, abduct = 12, swing = 22, elbow = 8, wrist = 40 }, lean = 10, lunge = 0.5 },
		{ R = { pitch = 90, abduct = 12, swing = 22, elbow = 12, wrist = 35 }, L = { pitch = 90, abduct = 12, swing = 22, elbow = 12, wrist = 35 }, lean = 8, lunge = 0.4 },
		0.18, 0.3, 0.7
	),
	-- Paume qui touche (Contact Bomb, Zipper Trap)
	Touch = spell(
		{ R = { pitch = 45, abduct = 15, elbow = 110, wrist = 20 }, L = GUARD_ARM, twist = -15 },
		{ R = { pitch = 95, abduct = 5, swing = 10, elbow = 5, wrist = 60 }, L = GUARD_ARM, twist = 20, lean = 10, lunge = 0.5 },
		{ R = { pitch = 92, abduct = 5, swing = 10, elbow = 10, wrist = 55 }, L = GUARD_ARM, twist = 18, lean = 8, lunge = 0.45 },
		0.1, 0.2, 0.55
	),
	-- Uppercut énorme (Arrivederci)
	Uppercut = spell(
		{ R = { pitch = -20, abduct = 15, elbow = 120 }, L = GUARD_ARM, twist = -25, lean = 20, drop = 0.45 },
		{ R = { pitch = 170, abduct = 5, swing = 10, elbow = 10 }, L = { pitch = 10, abduct = 25, elbow = 80 }, twist = 30, lean = -18, drop = -0.4, headPitch = 20, lunge = 0.6 },
		{ R = { pitch = 165, abduct = 5, elbow = 15 }, L = { pitch = 10, abduct = 25, elbow = 80 }, twist = 25, lean = -14, drop = -0.3, headPitch = 15 },
		0.3, 0.45, 0.8
	),
	-- Tranchant de la main qui s'abat (Time Skip)
	Strike = spell(
		{ R = { pitch = 165, abduct = 15, elbow = 20 }, L = GUARD_ARM, twist = -20, lean = -6 },
		{ R = { pitch = 55, abduct = 8, swing = 20, elbow = 10 }, L = GUARD_ARM, twist = 20, lean = 16, lunge = 0.6 },
		{ R = { pitch = 40, abduct = 8, swing = 25, elbow = 15 }, L = GUARD_ARM, twist = 18, lean = 14, lunge = 0.5 },
		0.15, 0.3, 0.7
	),

	-- ─── Moveset original ───────────────────────────────────────────────────
	-- Posture de contre : main ouverte devant, l'autre armée, prêt à punir
	CounterStance = hold({
		R = { pitch = 35, abduct = 25, elbow = 125 },
		L = { pitch = 80, abduct = 5, swing = 25, elbow = 35, wrist = 50 },
		twist = -20, lean = 6, drop = 0.2,
		legR = { hip = -15, knee = 25 }, legL = { hip = 20, knee = 30 },
	}, 0.2),
	-- Harpon : bras lancé devant, puis on tire violemment vers soi
	Pull = {
		duration = 0.7,
		keys = {
			{ 0, GUARD },
			{ 0.12, { R = { pitch = 95, abduct = 3, swing = 6, elbow = 0, wrist = 0 }, L = GUARD_ARM, twist = 25, lean = 10, lunge = 0.6 } },
			{ 0.3, { R = { pitch = 92, abduct = 3, swing = 6, elbow = 5 }, L = GUARD_ARM, twist = 25, lean = 10, lunge = 0.6 } },
			{ 0.5, { R = { pitch = 40, abduct = 20, swing = -10, elbow = 120 }, L = GUARD_ARM, twist = -25, lean = -8, lunge = -0.2 } },
			{ 0.7, { R = { pitch = 45, abduct = 18, elbow = 115 }, L = GUARD_ARM, twist = -15, lean = -4 } },
		},
	},
	-- Pose au sol : accroupi, main posée devant (pièges, zones)
	Plant = spell(
		{ R = { pitch = 70, abduct = 15, elbow = 60 }, L = GUARD_ARM, lean = 15, drop = 0.3 },
		{ R = { pitch = 45, abduct = 10, swing = 10, elbow = 10, wrist = -30 }, L = { pitch = 20, abduct = 30, elbow = 80 }, lean = 40, drop = 0.9, lunge = 0.4,
			legR = { hip = 70, knee = 100 }, legL = { hip = 20, knee = 110 } },
		{ R = { pitch = 45, abduct = 10, swing = 10, elbow = 12, wrist = -25 }, L = { pitch = 20, abduct = 30, elbow = 80 }, lean = 36, drop = 0.85, lunge = 0.4,
			legR = { hip = 65, knee = 95 }, legL = { hip = 20, knee = 105 } },
		0.15, 0.35, 0.8
	),
	-- Canalisation : deux mains devant, paumes ouvertes, tenues
	Channel = hold({
		R = { pitch = 88, abduct = 20, swing = 20, elbow = 25, wrist = 45 },
		L = { pitch = 88, abduct = 20, swing = 20, elbow = 25, wrist = 45 },
		lean = 6, headPitch = 5,
	}, 0.3),
	-- Tourbillon : bras ouverts, le buste tourne d'un côté puis de l'autre
	Spin = {
		duration = 0.9,
		keys = {
			{ 0, GUARD },
			{ 0.15, { R = { pitch = 20, abduct = 85, elbow = 15 }, L = { pitch = 20, abduct = 85, elbow = 15 }, twist = -60, drop = 0.2 } },
			{ 0.4, { R = { pitch = 20, abduct = 85, elbow = 10 }, L = { pitch = 20, abduct = 85, elbow = 10 }, twist = 70, drop = 0.1 } },
			{ 0.6, { R = { pitch = 20, abduct = 85, elbow = 10 }, L = { pitch = 20, abduct = 85, elbow = 10 }, twist = -20 } },
			{ 0.9, GUARD },
		},
	},
	-- Coup de pied haut de la jambe droite
	Kick = spell(
		{ R = GUARD_ARM, L = GUARD_ARM, twist = 10, lean = -6, legR = { hip = 60, knee = 100 } },
		{ R = { pitch = 30, abduct = 40, elbow = 80 }, L = { pitch = 40, abduct = 30, elbow = 90 }, twist = -15, lean = -18, lunge = 0.5, legR = { hip = 120, knee = 5 } },
		{ R = GUARD_ARM, L = GUARD_ARM, twist = -10, lean = -12, legR = { hip = 100, knee = 20 } },
		0.15, 0.3, 0.7
	),
}

-- ─── Miroir (pour fabriquer LightL à partir de LightR) ──────────────────────
local function mirrorPose(pose)
	local m = {}
	for k, v in pairs(pose) do
		m[k] = v
	end
	m.R, m.L = pose.L, pose.R
	m.legR, m.legL = pose.legL, pose.legR
	m.twist = pose.twist and -pose.twist
	m.headYaw = pose.headYaw and -pose.headYaw
	return m
end

local function mirrorStrike(strike)
	local keys = {}
	for i, key in ipairs(strike.keys) do
		keys[i] = { key[1], mirrorPose(key[2]) }
	end
	return { duration = strike.duration, keys = keys }
end

-- Renvoie la frappe décrite (ou nil si le Stand n'en a pas pour ce coup).
function StandStrikes.Get(standId, kind)
	local animName = string.match(kind, "^Anim:(.+)$")
	if animName then
		local own = StandStrikes.Stands[standId]
		if animName == "Flurry" then
			-- La rafale reprend le barrage à thème du Stand (estocs, griffes…)
			return (own and (own.Flurry or own.Barrage)) or DEFAULT_BARRAGE
		end
		return (own and own[animName]) or StandStrikes.SpellAnims[animName]
	end
	local def = StandStrikes.Stands[standId]
	if not def then return nil end
	if kind == "LightR" then
		return def.LightR
	elseif kind == "LightL" then
		return def.LightL or (def.LightR and mirrorStrike(def.LightR))
	elseif kind == "Heavy" or kind == "Finisher" then
		return def.Heavy or def.Finisher or DEFAULT_FINISHER
	elseif kind == "Barrage" then
		return def.Barrage or DEFAULT_BARRAGE
	elseif kind == "Idle" then
		return def.Idle or DEFAULT_IDLE
	elseif kind == "Pose" then
		return def.Pose or hold(DEFAULT_POSE, 0.35)
	elseif kind == "Summon" then
		return def.Summon or makeSummon(DEFAULT_POSE)
	elseif kind == "TimeStop" then
		return def.TimeStop
	elseif kind == "Heal" then
		return def.Heal
	end
	return nil
end

-- Garde (touche X) : avant-bras croisés devant le visage, pour tous les
-- Stands (y compris Star Platinum). Un Stand peut avoir sa version (Block).
local BLOCK = hold({
	R = { pitch = 95, abduct = 0, swing = 45, elbow = 110 },
	L = { pitch = 95, abduct = 0, swing = 45, elbow = 110 },
	lean = 6, headPitch = -5,
	legR = { hip = 10, knee = 15 }, legL = { hip = 10, knee = 15 },
}, 0.15)

local getBase = StandStrikes.Get
function StandStrikes.Get(standId, kind)
	if kind == "Block" then
		local def = StandStrikes.Stands[standId]
		return (def and def.Block) or BLOCK
	end
	return getBase(standId, kind)
end

-- ─── Conversion pose → articulations ────────────────────────────────────────
-- Chaque rotation est d'abord exprimée dans les axes de la pièce parente
-- (X = droite, Y = haut, -Z = devant), puis convertie dans le repère du
-- Motor6D grâce à son C0 : les squelettes R6 (articulations tournées de 90°)
-- et R15 marchent avec les mêmes poses.

local function angles(x, y, z)
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

local function armRot(arm, side)
	arm = arm or {}
	return angles(arm.pitch, (arm.swing or 0) * side, (arm.abduct or 0) * side)
end

local function legRot(leg)
	return angles(leg and leg.hip or 0, 0, 0)
end

-- Pose → { [nom de pièce] = rotation dans les axes du parent }
local function poseToParentSpace(pose, isR15)
	local twist, lean = pose.twist or 0, pose.lean or 0
	local move = CFrame.new(0, -(pose.drop or 0), -(pose.lunge or 0))
	local head = angles(pose.headPitch, -twist + (pose.headYaw or 0), 0)
	local out = {}
	if isR15 then
		out.LowerTorso = move * angles(-lean * 0.4, twist * 0.4, 0)
		out.UpperTorso = angles(-lean * 0.6, twist * 0.6, 0)
		out.Head = head
		for _, s in ipairs({ { "Right", pose.R, 1, pose.legR }, { "Left", pose.L, -1, pose.legL } }) do
			local name, arm, side, leg = s[1], s[2] or {}, s[3], s[4] or {}
			out[name .. "UpperArm"] = armRot(arm, side)
			out[name .. "LowerArm"] = angles(arm.elbow, 0, 0)
			out[name .. "Hand"] = angles(arm.wrist, 0, 0)
			out[name .. "UpperLeg"] = legRot(leg)
			out[name .. "LowerLeg"] = angles(-(leg.knee or 0), 0, 0)
		end
	else
		out.Torso = move * angles(-lean, twist, 0)
		out.Head = head
		out["Right Arm"] = armRot(pose.R, 1)
		out["Left Arm"] = armRot(pose.L, -1)
		out["Right Leg"] = legRot(pose.legR)
		out["Left Leg"] = legRot(pose.legL)
	end
	return out
end

-- Compile une frappe pour un Stand donné.
-- Renvoie { Settings, Timestamps, Elbows } prêt pour StandController, ou nil.
--   Elbows = { { temps, coudeDroit, coudeGauche } } en radians, pour les
--   Stands R6 qui ont des coudes ajoutés (Star Platinum).
function StandStrikes.Compile(standId, kind, joints)
	local strike = StandStrikes.Get(standId, kind)
	if not strike then return nil end
	local isR15 = joints.UpperTorso ~= nil
	local timestamps, elbows, easings = {}, {}, {}
	for _, key in ipairs(strike.keys) do
		local t, pose = key[1], key[2]
		easings[t] = key[3]
		local frame = {}
		for partName, parentRot in pairs(poseToParentSpace(pose, isR15)) do
			local motor = joints[partName]
			if motor then
				local c0 = motor.C0.Rotation
				frame[partName] = c0:Inverse() * parentRot * c0
			end
		end
		timestamps[t] = frame
		local r, l = pose.R or {}, pose.L or {}
		table.insert(elbows, { t, rad(r.elbow or 0), rad(l.elbow or 0) })
	end
	return {
		Settings = { Loop = strike.loop == true },
		Timestamps = timestamps,
		Elbows = elbows,
		Easings = easings, -- courbe du trajet qui mène à chaque clé
	}
end

-- Valeur des coudes (radians) à l'instant t, interpolée entre les clés.
function StandStrikes.ElbowsAt(clip, t)
	local e = clip.Elbows
	if not e or #e == 0 then return nil end
	if clip.Settings and clip.Settings.Loop and e[#e][1] > 0 then
		t = t % e[#e][1]
	end
	if t <= e[1][1] then return e[1][2], e[1][3] end
	for i = 1, #e - 1 do
		local a, b = e[i], e[i + 1]
		if t < b[1] then
			local alpha = (t - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * alpha, a[3] + (b[3] - a[3]) * alpha
		end
	end
	local last = e[#e]
	return last[2], last[3]
end

return StandStrikes
