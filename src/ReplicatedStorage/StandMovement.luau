-- StandMovement. Le système de déplacement propre à chaque Stand :
--   - une capacité active sur Z (bouton B à la manette) ;
--   - des différences passives : sauts en l'air (AirJumps), vol plané (Glide).
--
-- Le serveur (StandService, section "DÉPLACEMENT") gère les recharges et les
-- charges ; c'est le client (StandMovement.client.luau) qui déplace le
-- personnage, puisqu'il possède sa physique.
--
-- ─── Types de capacité ──────────────────────────────────────────────────────
-- "Leap"     bond : Forward (vitesse avant), Up (vitesse vers le haut)
-- "AirDash"  ruée dans la direction de déplacement, même en l'air :
--            Speed, Time (s)
-- "Blink"    téléportation devant soi, arrêtée par les murs : Distance
-- "Phase"    comme Blink mais traverse les murs (arrivée dans un endroit
--            libre) : Distance
-- "Recall"   retour à la position d'il y a Seconds secondes
-- "Grapple"  harpon vers le point visé (souris / centre de l'écran) qui tire
--            le joueur : Range, Speed
-- "Hover"    lévitation : Duration (s), Lift (vitesse de montée), RiseTime
-- "Jet"      propulsion vers le haut et l'avant : Up, Forward, Time (s)
--
-- Communs : Label, Cooldown (s), Charges (utilisations avant recharge, 1 par
-- défaut ; une charge revient toutes les Cooldown secondes), Color.
-- Passifs : AirJumps (sauts en l'air, 1 = double saut), JumpPower (force des
-- sauts en l'air, 1.25 par défaut), Glide (maintenir Espace en l'air pour
-- planer : vitesse de chute max en studs/s).

local DEFAULT = {
	AirJumps = 1,
}

local MOVEMENT = {
	StarPlatinum = {
		Label = "Star Leap", Type = "Leap", Cooldown = 5,
		Forward = 70, Up = 55,
		AirJumps = 1,
	},
	TheWorld = {
		Label = "Stolen Step", Type = "Blink", Cooldown = 6,
		Distance = 22,
		AirJumps = 1,
	},
	TheWorldAU = {
		Label = "Predator Pounce", Type = "Leap", Cooldown = 5,
		Forward = 85, Up = 35,
		AirJumps = 1,
	},
	CrazyDiamond = {
		Label = "Rewind Step", Type = "Recall", Cooldown = 9,
		Seconds = 2.5,
		AirJumps = 1,
	},
	SilverChariot = {
		Label = "Swift Steps", Type = "AirDash", Cooldown = 4, Charges = 2,
		Speed = 110, Time = 0.2,
		AirJumps = 1,
	},
	KillerQueen = {
		Label = "Blast Jump", Type = "Leap", Cooldown = 7,
		Forward = 45, Up = 85,
		AirJumps = 1,
	},
	GoldExperience = {
		Label = "Vine Swing", Type = "Grapple", Cooldown = 6,
		Range = 60, Speed = 90,
		AirJumps = 1,
	},
	GoldExperienceRequiem = {
		Label = "Ascension", Type = "Hover", Cooldown = 10,
		Duration = 2.5, Lift = 14, RiseTime = 0.6,
		AirJumps = 2,
	},
	KingCrimson = {
		Label = "Skipped Frames", Type = "Blink", Cooldown = 7,
		Distance = 30,
		AirJumps = 1,
	},
	HierophantGreen = {
		Label = "Tendril Grapple", Type = "Grapple", Cooldown = 5,
		Range = 75, Speed = 100,
		AirJumps = 1,
	},
	MagiciansRed = {
		Label = "Flame Jet", Type = "Jet", Cooldown = 6,
		Up = 45, Forward = 50, Time = 0.5,
		AirJumps = 1, Glide = 10,
	},
	StickyFingers = {
		Label = "Zipper Dive", Type = "Phase", Cooldown = 7,
		Distance = 20,
		AirJumps = 1,
	},
	MadeInHeaven = {
		Label = "Light Speed", Type = "AirDash", Cooldown = 5, Charges = 3,
		Speed = 170, Time = 0.25,
		AirJumps = 2,
	},
}

local StandMovement = {}

-- Profil de déplacement d'un Stand (jamais nil : valeurs par défaut sinon)
function StandMovement.Get(standId)
	return MOVEMENT[standId] or DEFAULT
end

StandMovement.Stands = MOVEMENT

return StandMovement
