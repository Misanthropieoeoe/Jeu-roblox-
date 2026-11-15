-- StandRarity. Les chances d'obtenir chaque Stand avec une Flèche du Stand.
-- Réglé depuis le panneau "Raretés des Stands" sur Claude (dis à Claude
-- "applique les raretés").
--
--   Weight      poids du Stand : plus il est grand, plus le Stand sort souvent.
--               Chance = Weight / somme des poids des Stands obtenables.
--   Obtainable  false = la Flèche ne donne jamais ce Stand
--               (ex. Gold Experience Requiem, qui vient de la Flèche Requiem).
return {
	StarPlatinum = { Weight = 10, Obtainable = true },
	TheWorld = { Weight = 2, Obtainable = true },
	TheWorldAU = { Weight = 1, Obtainable = true },
	CrazyDiamond = { Weight = 2, Obtainable = true },
	SilverChariot = { Weight = 7, Obtainable = true },
	KillerQueen = { Weight = 1, Obtainable = true },
	GoldExperience = { Weight = 7, Obtainable = true },
	GoldExperienceRequiem = { Weight = 0, Obtainable = false },
	KingCrimson = { Weight = 1, Obtainable = true },
	HierophantGreen = { Weight = 10, Obtainable = true },
	MagiciansRed = { Weight = 10, Obtainable = true },
	StickyFingers = { Weight = 10, Obtainable = true },
	MadeInHeaven = { Weight = 1, Obtainable = false },
}
