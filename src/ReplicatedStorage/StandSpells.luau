-- StandSpells. Les attaques spéciales ajoutées à chaque Stand pour qu'il ait
-- 5 attaques : E (Barrage) et R (Heavy) existent déjà dans StandData ; ce
-- fichier ajoute les autres sur T, F et G (les Time Stop F et le Life
-- Channel T de GER existants comptent dans les 5).
--
-- StandData fusionne ce fichier dans StandData.Stands[id].Moves au
-- chargement. Le serveur (StandService, section "SORTS") exécute chaque
-- attaque selon son Type, et le Stand joue l'animation `Anim`
-- (StandStrikes.SpellAnims).
--
-- ─── Types d'attaque et leurs réglages ─────────────────────────────────────
-- Communs : Label, Key, Cooldown (s), Duration (durée de l'animation / de
--   l'état du Stand, s), Anim, Color (couleur des effets, sinon l'aura du
--   Stand), HitDelay (moment de l'impact, s).
--
-- "Strike"     frappe devant : Damage, Knockback, Range, BoxSize, Stun (s)
--              + bombe optionnelle : BombDelay, BombDamage, BombRadius
-- "Dash"       le joueur fonce : DashSpeed, DashTime, Damage, Knockback,
--              Stun, BoxSize (zone touchée pendant la ruée)
-- "Projectile" Count (nombre), Spread (éventail en degrés), Speed, Range,
--              Damage, Knockback, Stun, Size, Shape ("Ball" | "Blade"),
--              Pierce (traverse les cibles), Explode = { Radius, Damage },
--              Homing (vitesse de virage, tête chercheuse), HomingRange
--              Le projectile part vers la souris (centre de l'écran sur
--              mobile) et s'arrête contre les murs.
-- "Burst"      zone : Radius, Offset (distance devant, 0 = autour de soi),
--              Damage, Knockback, Launch (projection vers le haut), Stun
-- "Buff"       sur soi : Heal (PV), SpeedBoost (multiplicateur), BuffTime (s)
-- "Teleport"   derrière l'ennemi le plus proche à moins de Range studs,
--              puis frappe : Damage, Knockback, Stun, BoxSize

local SILVER = Color3.fromRGB(220, 225, 235)
local GOLD = Color3.fromRGB(255, 200, 70)
local GREEN = Color3.fromRGB(110, 255, 140)
local EMERALD = Color3.fromRGB(60, 220, 120)
local FIRE = Color3.fromRGB(255, 120, 40)
local PINK = Color3.fromRGB(255, 130, 200)
local CRIMSON = Color3.fromRGB(220, 30, 60)
local GLASS = Color3.fromRGB(170, 230, 255)
local BLUE = Color3.fromRGB(90, 160, 255)

return {
	StarPlatinum = {
		StarFinger = {
			Label = "Star Finger", Key = "T", Cooldown = 8, Type = "Strike",
			Duration = 0.6, HitDelay = 0.25, Anim = "Point", Color = Color3.fromRGB(170, 120, 255),
			Damage = 18, Knockback = 25, Range = 16, BoxSize = Vector3.new(4, 4, 18),
		},
		BearingShot = {
			Label = "Bearing Shot", Key = "G", Cooldown = 7, Type = "Projectile",
			Duration = 0.5, HitDelay = 0.2, Anim = "Flick", Color = SILVER,
			Count = 1, Speed = 170, Range = 100, Damage = 15, Knockback = 15, Size = 0.6,
		},
	},

	TheWorld = {
		KnifeThrow = {
			Label = "Knife Throw", Key = "T", Cooldown = 9, Type = "Projectile",
			Duration = 0.55, HitDelay = 0.22, Anim = "Throw", Color = SILVER,
			Count = 5, Spread = 14, Speed = 120, Range = 70, Damage = 6, Size = 0.4, Shape = "Blade",
		},
		RoadRoller = {
			Label = "Road Roller", Key = "G", Cooldown = 18, Type = "Burst",
			Duration = 0.9, HitDelay = 0.55, Anim = "Slam", Color = GOLD,
			Offset = 8, Radius = 10, Damage = 30, Knockback = 60, Stun = 0.8,
		},
	},

	TheWorldAU = {
		KnifeBarrage = {
			Label = "Knife Barrage", Key = "T", Cooldown = 10, Type = "Projectile",
			Duration = 0.6, HitDelay = 0.22, Anim = "Throw", Color = SILVER,
			Count = 8, Spread = 25, Speed = 125, Range = 70, Damage = 4, Size = 0.4, Shape = "Blade",
		},
		BrutalDash = {
			Label = "Brutal Dash", Key = "G", Cooldown = 9, Type = "Dash",
			Duration = 0.6, HitDelay = 0.1, Anim = "Dash",
			DashSpeed = 90, DashTime = 0.25, Damage = 20, Knockback = 40, BoxSize = Vector3.new(8, 7, 8),
		},
	},

	CrazyDiamond = {
		Restoration = {
			Label = "Restoration", Key = "T", Cooldown = 20, Type = "Buff",
			Duration = 0.8, HitDelay = 0.35, Anim = "Raise", Color = PINK,
			Heal = 35,
		},
		GlassShards = {
			Label = "Glass Shards", Key = "F", Cooldown = 10, Type = "Projectile",
			Duration = 0.55, HitDelay = 0.22, Anim = "Throw", Color = GLASS,
			Count = 6, Spread = 30, Speed = 110, Range = 60, Damage = 5, Size = 0.5, Shape = "Blade",
		},
		RageDash = {
			Label = "Rage Dash", Key = "G", Cooldown = 10, Type = "Dash",
			Duration = 0.6, HitDelay = 0.1, Anim = "Dash",
			DashSpeed = 85, DashTime = 0.25, Damage = 22, Knockback = 45, BoxSize = Vector3.new(8, 7, 8),
		},
	},

	SilverChariot = {
		ArmorOff = {
			Label = "Armor Off", Key = "T", Cooldown = 25, Type = "Buff",
			Duration = 0.7, HitDelay = 0.3, Anim = "Raise", Color = SILVER,
			SpeedBoost = 1.5, BuffTime = 8,
		},
		RapierLaunch = {
			Label = "Rapier Launch", Key = "F", Cooldown = 9, Type = "Projectile",
			Duration = 0.5, HitDelay = 0.2, Anim = "Point", Color = SILVER,
			Count = 1, Speed = 150, Range = 80, Damage = 20, Knockback = 20, Size = 0.5, Shape = "Blade",
		},
		LungePierce = {
			Label = "Lunge Pierce", Key = "G", Cooldown = 8, Type = "Dash",
			Duration = 0.55, HitDelay = 0.1, Anim = "Dash",
			DashSpeed = 95, DashTime = 0.22, Damage = 18, Stun = 1, BoxSize = Vector3.new(6, 6, 8),
		},
	},

	KillerQueen = {
		SheerHeartAttack = {
			Label = "Sheer Heart Attack", Key = "T", Cooldown = 14, Type = "Projectile",
			Duration = 0.55, HitDelay = 0.25, Anim = "Throw", Color = FIRE,
			Count = 1, Speed = 45, Range = 70, Damage = 10, Size = 1.4,
			Explode = { Radius = 9, Damage = 22 },
			Homing = 3, HomingRange = 30, -- poursuit la cible la plus proche devant lui
		},
		ContactBomb = {
			Label = "Contact Bomb", Key = "F", Cooldown = 12, Type = "Strike",
			Duration = 0.55, HitDelay = 0.2, Anim = "Touch", Color = FIRE,
			Damage = 8, Range = 9, BoxSize = Vector3.new(6, 6, 9),
			BombDelay = 1.0, BombDamage = 22, BombRadius = 7,
		},
		BitesTheDust = {
			Label = "Bites the Dust", Key = "G", Cooldown = 30, Type = "Buff",
			Duration = 0.9, HitDelay = 0.4, Anim = "Raise", Color = PINK,
			Heal = 40,
		},
	},

	GoldExperience = {
		LifeShot = {
			Label = "Life Shot", Key = "T", Cooldown = 9, Type = "Projectile",
			Duration = 0.5, HitDelay = 0.2, Anim = "Flick", Color = GREEN,
			Count = 3, Spread = 12, Speed = 110, Range = 70, Damage = 8, Size = 0.6,
		},
		TreeGrowth = {
			Label = "Tree Growth", Key = "F", Cooldown = 14, Type = "Burst",
			Duration = 0.8, HitDelay = 0.45, Anim = "Slam", Color = GREEN,
			Offset = 6, Radius = 8, Damage = 20, Launch = 60, Stun = 1,
		},
		LifeSense = {
			Label = "Life Sense", Key = "G", Cooldown = 22, Type = "Buff",
			Duration = 0.8, HitDelay = 0.35, Anim = "Raise", Color = GREEN,
			Heal = 30,
		},
	},

	GoldExperienceRequiem = {
		ReturnToZero = {
			Label = "Return to Zero", Key = "F", Cooldown = 25, Type = "Burst",
			Duration = 1.0, HitDelay = 0.6, Anim = "Raise", Color = GOLD,
			Offset = 0, Radius = 14, Damage = 25, Knockback = 50, Stun = 2,
		},
		RequiemDash = {
			Label = "Requiem Dash", Key = "G", Cooldown = 9, Type = "Dash",
			Duration = 0.6, HitDelay = 0.1, Anim = "Dash", Color = GOLD,
			DashSpeed = 95, DashTime = 0.25, Damage = 22, Knockback = 40, BoxSize = Vector3.new(8, 7, 8),
		},
	},

	KingCrimson = {
		Epitaph = {
			Label = "Epitaph", Key = "T", Cooldown = 18, Type = "Buff",
			Duration = 0.7, HitDelay = 0.3, Anim = "Point", Color = CRIMSON,
			SpeedBoost = 1.4, BuffTime = 5,
		},
		TimeSkip = {
			Label = "Time Skip", Key = "G", Cooldown = 15, Type = "Teleport",
			Duration = 0.7, HitDelay = 0.3, Anim = "Strike", Color = CRIMSON,
			Range = 40, Damage = 25, Knockback = 30, BoxSize = Vector3.new(8, 7, 10),
		},
	},

	HierophantGreen = {
		FullSplash = {
			Label = "20m Emerald Splash", Key = "T", Cooldown = 14, Type = "Projectile",
			Duration = 0.7, HitDelay = 0.3, Anim = "ChargeBlast", Color = EMERALD,
			Count = 12, Spread = 60, Speed = 100, Range = 100, Damage = 3, Size = 0.5,
		},
		TentacleBind = {
			Label = "Tentacle Bind", Key = "F", Cooldown = 12, Type = "Strike",
			Duration = 0.6, HitDelay = 0.25, Anim = "Point", Color = EMERALD,
			Damage = 6, Range = 22, BoxSize = Vector3.new(5, 5, 24), Stun = 2.5,
		},
		BarrierField = {
			Label = "Barrier Field", Key = "G", Cooldown = 18, Type = "Burst",
			Duration = 0.9, HitDelay = 0.6, Anim = "ChargeBlast", Color = EMERALD,
			Offset = 0, Radius = 16, Damage = 15, Knockback = 20,
		},
	},

	MagiciansRed = {
		RedBind = {
			Label = "Red Bind", Key = "T", Cooldown = 12, Type = "Strike",
			Duration = 0.6, HitDelay = 0.25, Anim = "Point", Color = FIRE,
			Damage = 10, Range = 18, BoxSize = Vector3.new(5, 5, 20), Stun = 2,
		},
		FireAnkh = {
			Label = "Crossfire Special", Key = "F", Cooldown = 12, Type = "Projectile",
			Duration = 0.6, HitDelay = 0.25, Anim = "ChargeBlast", Color = FIRE,
			Count = 5, Spread = 30, Speed = 90, Range = 70, Damage = 7, Size = 0.9,
		},
		FlamePillar = {
			Label = "Flame Pillar", Key = "G", Cooldown = 16, Type = "Burst",
			Duration = 0.9, HitDelay = 0.5, Anim = "Raise", Color = FIRE,
			Offset = 0, Radius = 12, Damage = 22, Knockback = 40, Launch = 30,
		},
	},

	StickyFingers = {
		ZipperEscape = {
			Label = "Zipper Escape", Key = "T", Cooldown = 7, Type = "Dash",
			Duration = 0.5, HitDelay = 0.1, Anim = "Dash", Color = BLUE,
			DashSpeed = 110, DashTime = 0.25, Damage = 10, BoxSize = Vector3.new(6, 6, 8),
		},
		ZipperTrap = {
			Label = "Zipper Trap", Key = "F", Cooldown = 12, Type = "Strike",
			Duration = 0.55, HitDelay = 0.2, Anim = "Touch", Color = BLUE,
			Damage = 12, Range = 10, BoxSize = Vector3.new(6, 6, 10), Stun = 2,
		},
		Arrivederci = {
			Label = "Arrivederci", Key = "G", Cooldown = 18, Type = "Strike",
			Duration = 0.8, HitDelay = 0.45, Anim = "Uppercut", Color = BLUE,
			Damage = 35, Knockback = 70, Range = 10, BoxSize = Vector3.new(8, 8, 11),
		},
	},

	MadeInHeaven = {
		SpeedBlitz = {
			Label = "Speed Blitz", Key = "T", Cooldown = 7, Type = "Dash",
			Duration = 0.55, HitDelay = 0.1, Anim = "Dash", Color = Color3.fromRGB(200, 255, 255),
			DashSpeed = 140, DashTime = 0.3, Damage = 18, BoxSize = Vector3.new(8, 7, 10),
		},
		UniverseReset = {
			Label = "Universe Reset", Key = "G", Cooldown = 30, Type = "Burst",
			Duration = 1.1, HitDelay = 0.8, Anim = "Raise", Color = Color3.fromRGB(200, 255, 255),
			Offset = 0, Radius = 20, Damage = 30, Knockback = 60, Stun = 1.5,
		},
	},
}
