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

-- Fabrique une frappe M1 standard de 0.42 s à partir de 3 poses.
local function light(windup, impact, follow)
	return {
		duration = 0.42,
		keys = {
			{ 0.00, GUARD },
			{ 0.08, windup },
			{ 0.16, impact },
			{ 0.27, follow },
			{ 0.42, GUARD },
		},
	}
end

-- Fabrique un coup final de 0.45 s à partir de 3 poses.
local function finisher(windup, impact, follow)
	return {
		duration = 0.45,
		keys = {
			{ 0.00, GUARD },
			{ 0.14, windup },
			{ 0.25, impact },
			{ 0.36, follow },
			{ 0.45, GUARD },
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
		keys = {
			{ 0, a },
			{ cycle / 2, b },
			{ cycle, a },
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
			{ rise * 0.6, pose },
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
	elseif kind == "TimeStop" then
		return def.TimeStop
	elseif kind == "Heal" then
		return def.Heal
	end
	return nil
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
	local timestamps, elbows = {}, {}
	for _, key in ipairs(strike.keys) do
		local t, pose = key[1], key[2]
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
