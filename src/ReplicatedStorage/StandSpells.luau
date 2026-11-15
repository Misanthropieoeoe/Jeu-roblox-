-- StandSpells. Le moveset ORIGINAL de chaque Stand : 5 attaques sur E, R,
-- T, F et G (en plus du combo M1). Ces attaques remplacent les anciennes
-- (Barrage, Heavy Punch, Time Stop, Life Channel) : StandData retire les
-- anciennes attaques qui utilisent ces touches au chargement.
--
-- Le serveur (StandService, section "SORTS") exécute chaque attaque selon son
-- Type ; le Stand joue l'animation `Anim` (StandStrikes.SpellAnims) et le
-- joueur la pose `PlayerAnim` (ReplicatedStorage.Animations, tenue tant que
-- l'attaque dure).
--
-- ─── Équilibrage (joueurs à 100 PV) ─────────────────────────────────────────
-- - Aucune attaque ne dépasse 25 dégâts (un quart de la vie).
-- - Combo M1 : 4 + 4 + 4 + 8 = 20. Rafale complète : ~18-24. Frappe lourde : 13-18.
-- - Projectiles multiples / zones : dégâts complets seulement si tout touche.
-- - Soins : 20-22 PV, 25-28 s de recharge.
-- - Moveset complet d'un Stand si TOUT touche : ~80-100 dégâts, donc en vrai
--   combat il en faut environ deux pour tuer.
--
-- ─── Types d'attaque et leurs réglages ─────────────────────────────────────
-- Communs : Label, Key, Cooldown (s), Duration (durée de l'animation / de
--   l'état du Stand, s), Anim (animation du Stand), PlayerAnim (pose du
--   joueur), Color (couleur des effets, sinon l'aura du Stand), HitDelay.
--
-- "Strike"     frappe devant : Damage, Knockback, Range, BoxSize, Stun (s)
--              + bombe optionnelle : BombDelay, BombDamage, BombRadius
-- "Dash"       le joueur fonce : DashSpeed, DashTime, Damage, Knockback,
--              Stun, BoxSize (zone touchée pendant la ruée)
-- "Projectile" Count, Spread (degrés), Speed, Range, Damage, Knockback,
--              Stun, Size, Shape ("Ball" | "Blade"), Pierce,
--              Explode = { Radius, Damage }, Homing, HomingRange.
--              Part vers la souris (centre de l'écran sur mobile).
-- "Burst"      zone instantanée : Radius, Offset (0 = autour de soi),
--              Damage, Knockback, Launch (vers le haut), Stun
-- "Buff"       sur soi : Heal (PV), SpeedBoost (multiplicateur), BuffTime (s)
-- "Teleport"   derrière l'ennemi le plus proche à moins de Range studs, puis
--              frappe : Damage, Knockback, Stun, BoxSize
-- "Flurry"     rafale pendant Duration : TickRate, Damage (par coup), Range,
--              BoxSize, FinalDamage, FinalKnockback (coup final)
-- "Counter"    posture pendant Duration : si on est frappé (de n'importe où),
--              le coup est annulé et l'attaquant prend CounterDamage,
--              CounterKnockback, CounterStun
-- "Pull"       harpon vers la souris : Range, Damage, Stun ; la cible est
--              tirée devant le joueur (PullTo studs) en PullTime s
-- "Zone"       champ au sol : Offset, Radius, Lifetime, TickRate, Damage
--              (par tick), Slow (immobilise à chaque tick, s)
-- "Mine"       piège posé devant : Offset, Radius (explosion),
--              TriggerRadius, ArmTime, Lifetime, Damage, Knockback, Launch, Stun
-- "TimeStop"   arrêt du temps (l'attaque doit s'appeler TimeStop) : Duration
--              (temps figé), PoseTime (durée de la pose, ensuite le lanceur
--              peut attaquer pendant que les autres restent figés),
--              TimeStopOffset, TimeStopSmoothness ; voix : TimeStopVoicePath
--              du Stand dans StandData
-- "Erase"      effacer le temps : intouchable et à moitié invisible pendant
--              EraseTime s, SpeedBoost optionnel
-- "Buff" + Rewind = s : retour à la position d'il y a Rewind secondes
--
-- Animations du Stand : Point, Flick, Throw, Slam, Dash, Raise, ChargeBlast,
--   Touch, Uppercut, Strike, Flurry, CounterStance, Pull, Plant, Channel,
--   Spin, Kick.
-- Poses du joueur : CmdPoint, CmdSummon, CmdBrace, CmdCast, CmdDash, CmdPlant.

local SILVER = Color3.fromRGB(220, 225, 235)
local GOLD = Color3.fromRGB(255, 200, 70)
local GREEN = Color3.fromRGB(110, 255, 140)
local EMERALD = Color3.fromRGB(60, 220, 120)
local FIRE = Color3.fromRGB(255, 120, 40)
local PINK = Color3.fromRGB(255, 130, 200)
local CRIMSON = Color3.fromRGB(220, 30, 60)
local BLUE = Color3.fromRGB(90, 160, 255)
local VIOLET = Color3.fromRGB(170, 120, 255)
local CYAN = Color3.fromRGB(200, 255, 255)

return {
	-- ─── Star Platinum : précision et force brute ────────────────────────────
	StarPlatinum = {
		MeteorFlurry = {
			Label = "Meteor Flurry", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.2, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = VIOLET,
			TickRate = 0.1, Damage = 0.8, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 5, FinalKnockback = 45,
		},
		Starbreaker = {
			Label = "Starbreaker", Key = "R", Cooldown = 12, Type = "Strike",
			Duration = 0.8, HitDelay = 0.45, Anim = "Uppercut", PlayerAnim = "CmdPoint", Color = VIOLET,
			Damage = 17, Knockback = 60, Range = 10, BoxSize = Vector3.new(8, 8, 11),
		},
		CometPebble = {
			Label = "Comet Pebble", Key = "T", Cooldown = 10, Type = "Projectile",
			Duration = 0.5, HitDelay = 0.2, Anim = "Flick", PlayerAnim = "CmdPoint", Color = SILVER,
			Count = 1, Speed = 180, Range = 100, Damage = 11, Knockback = 15, Size = 0.6,
		},
		StellarFinger = {
			Label = "Stellar Finger", Key = "F", Cooldown = 12, Type = "Strike",
			Duration = 0.6, HitDelay = 0.22, Anim = "Point", PlayerAnim = "CmdPoint", Color = VIOLET,
			-- le doigt s'allonge : portée longue, zone très fine
			Damage = 13, Knockback = 20, Range = 18, BoxSize = Vector3.new(3, 3, 20),
		},
		-- Arrêt du temps : fige tous les autres joueurs (pose ZA WARUDO, voix)
		TimeStop = {
			Label = "Frozen Instant", Key = "G", Cooldown = 95, Type = "TimeStop",
			Duration = 4, PlayerAnim = "CmdSummon", Color = VIOLET,
			Range = 80, TimeStopOffset = Vector3.new(0, 2, -3.2), TimeStopSmoothness = 0.25,
		},
	},

	-- ─── The World : domination et lames ─────────────────────────────────────
	TheWorld = {
		RoyalOnslaught = {
			Label = "Royal Onslaught", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.2, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = GOLD,
			TickRate = 0.1, Damage = 0.8, Range = 9, BoxSize = Vector3.new(8, 7, 10),
			FinalDamage = 5, FinalKnockback = 50,
		},
		CrownHammer = {
			Label = "Crown Hammer", Key = "R", Cooldown = 12, Type = "Burst",
			Duration = 0.9, HitDelay = 0.5, Anim = "Slam", PlayerAnim = "CmdPoint", Color = GOLD,
			Offset = 5, Radius = 7, Damage = 17, Knockback = 45, Launch = 20,
		},
		DaggerRain = {
			Label = "Dagger Rain", Key = "T", Cooldown = 12, Type = "Projectile",
			Duration = 0.6, HitDelay = 0.22, Anim = "Throw", PlayerAnim = "CmdCast", Color = SILVER,
			Count = 6, Spread = 40, Speed = 120, Range = 70, Damage = 2.5, Size = 0.4, Shape = "Blade",
		},
		-- Arrêt du temps : fige tous les autres joueurs (pose ZA WARUDO, voix)
		TimeStop = {
			Label = "World Halt", Key = "F", Cooldown = 100, Type = "TimeStop",
			Duration = 5, PlayerAnim = "CmdSummon", Color = GOLD,
			Range = 80, TimeStopOffset = Vector3.new(0, 2, -3.2), TimeStopSmoothness = 0.25,
		},
		EmperorsStep = {
			Label = "Emperor's Step", Key = "G", Cooldown = 16, Type = "Teleport",
			Duration = 0.7, HitDelay = 0.3, Anim = "Strike", PlayerAnim = "CmdDash", Color = GOLD,
			Range = 30, Damage = 14, Knockback = 30, BoxSize = Vector3.new(8, 7, 10),
		},
	},

	-- ─── The World AU : brutalité ────────────────────────────────────────────
	TheWorldAU = {
		SavageFlurry = {
			Label = "Savage Flurry", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace",
			TickRate = 0.1, Damage = 1.2, Range = 9, BoxSize = Vector3.new(8, 7, 10),
			FinalDamage = 5, FinalKnockback = 55,
		},
		SkullCrusher = {
			Label = "Skull Crusher", Key = "R", Cooldown = 13, Type = "Strike",
			Duration = 0.9, HitDelay = 0.5, Anim = "Slam", PlayerAnim = "CmdPoint",
			Damage = 18, Knockback = 50, Stun = 0.4, Range = 9, BoxSize = Vector3.new(8, 8, 10),
		},
		ShrapnelFan = {
			Label = "Shrapnel Fan", Key = "T", Cooldown = 13, Type = "Projectile",
			Duration = 0.6, HitDelay = 0.22, Anim = "Throw", PlayerAnim = "CmdCast", Color = SILVER,
			Count = 8, Spread = 50, Speed = 125, Range = 60, Damage = 2.2, Size = 0.4, Shape = "Blade",
		},
		PredatorLunge = {
			Label = "Predator Lunge", Key = "F", Cooldown = 12, Type = "Dash",
			Duration = 0.6, HitDelay = 0.1, Anim = "Dash", PlayerAnim = "CmdDash",
			DashSpeed = 100, DashTime = 0.25, Damage = 14, Knockback = 40, BoxSize = Vector3.new(8, 7, 8),
		},
		-- Arrêt du temps : fige tous les autres joueurs (pose ZA WARUDO, voix)
		TimeStop = {
			Label = "Moment Seize", Key = "G", Cooldown = 98, Type = "TimeStop",
			Duration = 4.5, PlayerAnim = "CmdSummon", Color = GOLD,
			Range = 80, TimeStopOffset = Vector3.new(0, 2, -3.2), TimeStopSmoothness = 0.25,
		},
	},

	-- ─── Crazy Diamond : réparer et briser ───────────────────────────────────
	CrazyDiamond = {
		ShatterRush = {
			Label = "Shatter Rush", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = PINK,
			TickRate = 0.1, Damage = 0.9, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 5, FinalKnockback = 50,
		},
		RebuildSmash = {
			Label = "Rebuild Smash", Key = "R", Cooldown = 12, Type = "Strike",
			Duration = 0.75, HitDelay = 0.35, Anim = "Strike", PlayerAnim = "CmdPoint", Color = PINK,
			Damage = 16, Knockback = 55, Range = 10, BoxSize = Vector3.new(8, 7, 11),
		},
		Mend = {
			Label = "Mend", Key = "T", Cooldown = 50, Type = "Buff",
			Duration = 0.8, HitDelay = 0.35, Anim = "Raise", PlayerAnim = "CmdSummon", Color = PINK,
			Heal = 15,
		},
		ShardRecall = {
			Label = "Shard Recall", Key = "F", Cooldown = 14, Type = "Pull",
			Duration = 0.7, HitDelay = 0.2, Anim = "Pull", PlayerAnim = "CmdPoint", Color = PINK,
			Range = 20, Damage = 8, Stun = 1,
		},
		FusionLock = {
			Label = "Fusion Lock", Key = "G", Cooldown = 14, Type = "Strike",
			Duration = 0.6, HitDelay = 0.22, Anim = "Touch", PlayerAnim = "CmdPoint", Color = PINK,
			-- la cible est "réparée" dans le décor : immobilisée
			Damage = 8, Stun = 2.5, Range = 9, BoxSize = Vector3.new(6, 6, 9),
		},
	},

	-- ─── Silver Chariot : vitesse et escrime ─────────────────────────────────
	SilverChariot = {
		ThousandNeedles = {
			Label = "Thousand Needles", Key = "E", Cooldown = 15, Type = "Flurry",
			Duration = 1.8, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = SILVER,
			TickRate = 0.08, Damage = 0.6, Range = 10, BoxSize = Vector3.new(6, 6, 11),
			FinalDamage = 4, FinalKnockback = 35,
		},
		PiercingArc = {
			Label = "Piercing Arc", Key = "R", Cooldown = 10, Type = "Strike",
			Duration = 0.6, HitDelay = 0.25, Anim = "Point", PlayerAnim = "CmdPoint", Color = SILVER,
			Damage = 14, Knockback = 30, Range = 14, BoxSize = Vector3.new(4, 5, 16),
		},
		AfterimageFeint = {
			Label = "Afterimage Feint", Key = "T", Cooldown = 50, Type = "Buff",
			Duration = 0.7, HitDelay = 0.3, Anim = "Spin", PlayerAnim = "CmdSummon", Color = SILVER,
			SpeedBoost = 1.75, BuffTime = 5,
		},
		BladeVolley = {
			Label = "Blade Volley", Key = "F", Cooldown = 12, Type = "Projectile",
			Duration = 0.55, HitDelay = 0.22, Anim = "Throw", PlayerAnim = "CmdCast", Color = SILVER,
			Count = 3, Spread = 10, Speed = 140, Range = 80, Damage = 4.5, Size = 0.5, Shape = "Blade",
		},
		Riposte = {
			Label = "Riposte", Key = "G", Cooldown = 25, Type = "Counter",
			Duration = 1.0, Anim = "CounterStance", PlayerAnim = "CmdBrace", Color = SILVER,
			CounterDamage = 20, CounterKnockback = 40, CounterStun = 1.5,
		},
	},

	-- ─── Killer Queen : charges et détonations ───────────────────────────────
	KillerQueen = {
		DetonationJabs = {
			Label = "Detonation Jabs", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = FIRE,
			TickRate = 0.1, Damage = 1, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 6, FinalKnockback = 50,
		},
		PrimedPalm = {
			Label = "Primed Palm", Key = "R", Cooldown = 9, Type = "Strike",
			Duration = 0.6, HitDelay = 0.22, Anim = "Touch", PlayerAnim = "CmdPoint", Color = FIRE,
			Damage = 6, Range = 9, BoxSize = Vector3.new(6, 6, 9),
			BombDelay = 1.2, BombDamage = 12, BombRadius = 7,
		},
		ProximityCharge = {
			Label = "Proximity Charge", Key = "T", Cooldown = 14, Type = "Mine",
			Duration = 0.8, HitDelay = 0.35, Anim = "Plant", PlayerAnim = "CmdPlant", Color = FIRE,
			Offset = 4, Radius = 8, TriggerRadius = 5, ArmTime = 0.6, Lifetime = 12,
			Damage = 18, Knockback = 40,
		},
		FuseCoin = {
			Label = "Fuse Coin", Key = "F", Cooldown = 13, Type = "Projectile",
			Duration = 0.5, HitDelay = 0.2, Anim = "Flick", PlayerAnim = "CmdPoint", Color = GOLD,
			Count = 1, Speed = 55, Range = 70, Damage = 4, Size = 0.7,
			Explode = { Radius = 7, Damage = 12 }, Homing = 2.5, HomingRange = 25,
		},
		RewindHour = {
			Label = "Rewind Hour", Key = "G", Cooldown = 28, Type = "Buff",
			Duration = 0.9, HitDelay = 0.4, Anim = "Raise", PlayerAnim = "CmdSummon", Color = PINK,
			-- retour à la position d'il y a 3 s, plus un petit soin
			Rewind = 3, Heal = 12,
		},
	},

	-- ─── Gold Experience : la vie ────────────────────────────────────────────
	GoldExperience = {
		BloomFlurry = {
			Label = "Bloom Flurry", Key = "E", Cooldown = 12, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = GREEN,
			TickRate = 0.1, Damage = 0.8, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 4, FinalKnockback = 45,
		},
		VitalOverload = {
			Label = "Vital Overload", Key = "R", Cooldown = 13, Type = "Strike",
			Duration = 0.6, HitDelay = 0.22, Anim = "Touch", PlayerAnim = "CmdPoint", Color = GREEN,
			Damage = 12, Stun = 1, Range = 9, BoxSize = Vector3.new(6, 6, 9),
		},
		Thornseed = {
			Label = "Thornseed", Key = "T", Cooldown = 13, Type = "Mine",
			Duration = 0.8, HitDelay = 0.35, Anim = "Plant", PlayerAnim = "CmdPlant", Color = GREEN,
			Offset = 4, Radius = 6, TriggerRadius = 4.5, ArmTime = 0.6, Lifetime = 12,
			Damage = 14, Launch = 40, Stun = 0.6,
		},
		Swarm = {
			Label = "Swarm", Key = "F", Cooldown = 12, Type = "Projectile",
			Duration = 0.7, HitDelay = 0.3, Anim = "ChargeBlast", PlayerAnim = "CmdCast", Color = GREEN,
			Count = 4, Spread = 20, Speed = 70, Range = 70, Damage = 3.5, Size = 0.5,
			Homing = 2, HomingRange = 25,
		},
		Lifespring = {
			Label = "Lifespring", Key = "G", Cooldown = 50, Type = "Buff",
			Duration = 0.8, HitDelay = 0.35, Anim = "Raise", PlayerAnim = "CmdSummon", Color = GREEN,
			Heal = 15,
		},
	},

	-- ─── Gold Experience Requiem : l'inévitable ──────────────────────────────
	GoldExperienceRequiem = {
		RequiemFlurry = {
			Label = "Requiem Flurry", Key = "E", Cooldown = 12, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = GOLD,
			TickRate = 0.1, Damage = 0.9, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 6, FinalKnockback = 55,
		},
		FinalVerdict = {
			Label = "Final Verdict", Key = "R", Cooldown = 12, Type = "Strike",
			Duration = 0.75, HitDelay = 0.35, Anim = "Strike", PlayerAnim = "CmdPoint", Color = GOLD,
			Damage = 18, Knockback = 60, Range = 10, BoxSize = Vector3.new(8, 7, 11),
		},
		UndoStep = {
			Label = "Undo Step", Key = "T", Cooldown = 25, Type = "Counter",
			Duration = 1.2, Anim = "CounterStance", PlayerAnim = "CmdBrace", Color = GOLD,
			CounterDamage = 22, CounterKnockback = 45, CounterStun = 1.5,
		},
		GoldenTide = {
			Label = "Golden Tide", Key = "F", Cooldown = 18, Type = "Burst",
			Duration = 0.9, HitDelay = 0.5, Anim = "Raise", PlayerAnim = "CmdSummon", Color = GOLD,
			Offset = 0, Radius = 12, Damage = 16, Knockback = 45,
		},
		AscendantDash = {
			Label = "Ascendant Dash", Key = "G", Cooldown = 16, Type = "Dash",
			Duration = 0.6, HitDelay = 0.1, Anim = "Dash", PlayerAnim = "CmdDash", Color = GOLD,
			DashSpeed = 95, DashTime = 0.25, Damage = 14, Knockback = 40, BoxSize = Vector3.new(8, 7, 8),
		},
	},

	-- ─── King Crimson : prédiction et coups invisibles ───────────────────────
	KingCrimson = {
		CrimsonFlurry = {
			Label = "Crimson Flurry", Key = "E", Cooldown = 12, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = CRIMSON,
			TickRate = 0.1, Damage = 1.3, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 5, FinalKnockback = 50,
		},
		HeartPiercer = {
			Label = "Heart Piercer", Key = "R", Cooldown = 13, Type = "Strike",
			Duration = 0.7, HitDelay = 0.3, Anim = "Point", PlayerAnim = "CmdPoint", Color = CRIMSON,
			Damage = 18, Knockback = 30, Range = 12, BoxSize = Vector3.new(4, 5, 14),
		},
		BlindSpot = {
			Label = "Blind Spot", Key = "T", Cooldown = 19, Type = "Teleport",
			Duration = 0.7, HitDelay = 0.3, Anim = "Strike", PlayerAnim = "CmdDash", Color = CRIMSON,
			Range = 35, Damage = 20, Knockback = 30, BoxSize = Vector3.new(8, 7, 10),
		},
		Foreseen = {
			Label = "Foreseen", Key = "F", Cooldown = 16, Type = "Counter",
			Duration = 1.5, Anim = "CounterStance", PlayerAnim = "CmdBrace", Color = CRIMSON,
			CounterDamage = 14, CounterKnockback = 35, CounterStun = 1,
		},
		ErasedTime = {
			Label = "Erased Time", Key = "G", Cooldown = 24, Type = "Erase",
			Duration = 0.8, Anim = "Channel", PlayerAnim = "CmdSummon", Color = CRIMSON,
			-- intouchable et à moitié invisible, un peu plus rapide
			EraseTime = 2.5, SpeedBoost = 1.3,
		},
	},

	-- ─── Hierophant Green : distance et filets ───────────────────────────────
	HierophantGreen = {
		GemStream = {
			Label = "Gem Stream", Key = "E", Cooldown = 12, Type = "Projectile",
			Duration = 0.7, HitDelay = 0.3, Anim = "ChargeBlast", PlayerAnim = "CmdCast", Color = EMERALD,
			Count = 6, Spread = 20, Speed = 110, Range = 90, Damage = 2.5, Size = 0.5,
		},
		CoilLash = {
			Label = "Coil Lash", Key = "R", Cooldown = 6, Type = "Strike",
			Duration = 0.6, HitDelay = 0.25, Anim = "Point", PlayerAnim = "CmdPoint", Color = EMERALD,
			Damage = 13, Knockback = 35, Range = 20, BoxSize = Vector3.new(4, 5, 22),
		},
		Tether = {
			Label = "Tether", Key = "T", Cooldown = 11, Type = "Pull",
			Duration = 0.7, HitDelay = 0.2, Anim = "Pull", PlayerAnim = "CmdPoint", Color = EMERALD,
			Range = 25, Damage = 6, Stun = 1.2,
		},
		WebSnare = {
			Label = "Web Snare", Key = "F", Cooldown = 14, Type = "Mine",
			Duration = 0.8, HitDelay = 0.35, Anim = "Plant", PlayerAnim = "CmdPlant", Color = EMERALD,
			Offset = 4, Radius = 7, TriggerRadius = 5, ArmTime = 0.6, Lifetime = 12,
			Damage = 6, Stun = 2,
		},
		PrismField = {
			Label = "Prism Field", Key = "G", Cooldown = 18, Type = "Zone",
			Duration = 0.9, HitDelay = 0.4, Anim = "Channel", PlayerAnim = "CmdCast", Color = EMERALD,
			Offset = 0, Radius = 10, Lifetime = 3, TickRate = 0.5, Damage = 3,
		},
	},

	-- ─── Magician's Red : le feu ─────────────────────────────────────────────
	MagiciansRed = {
		EmberFlurry = {
			Label = "Ember Flurry", Key = "E", Cooldown = 14, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = FIRE,
			TickRate = 0.1, Damage = 0.8, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 6, FinalKnockback = 45,
		},
		PhoenixKick = {
			Label = "Phoenix Kick", Key = "R", Cooldown = 7, Type = "Strike",
			Duration = 0.7, HitDelay = 0.3, Anim = "Kick", PlayerAnim = "CmdPoint", Color = FIRE,
			Damage = 16, Knockback = 55, Range = 9, BoxSize = Vector3.new(8, 8, 10),
		},
		FlameLasso = {
			Label = "Flame Lasso", Key = "T", Cooldown = 11, Type = "Pull",
			Duration = 0.7, HitDelay = 0.2, Anim = "Pull", PlayerAnim = "CmdPoint", Color = FIRE,
			Range = 22, Damage = 7, Stun = 1.2,
		},
		AshField = {
			Label = "Ash Field", Key = "F", Cooldown = 16, Type = "Zone",
			Duration = 0.9, HitDelay = 0.4, Anim = "Channel", PlayerAnim = "CmdCast", Color = FIRE,
			Offset = 6, Radius = 7, Lifetime = 3.5, TickRate = 0.5, Damage = 1.5,
		},
		FireBird = {
			Label = "Fire Bird", Key = "G", Cooldown = 15, Type = "Projectile",
			Duration = 0.7, HitDelay = 0.3, Anim = "ChargeBlast", PlayerAnim = "CmdCast", Color = FIRE,
			Count = 1, Speed = 60, Range = 80, Damage = 7, Size = 1.6,
			Explode = { Radius = 8, Damage = 8 }, Homing = 2.5, HomingRange = 30,
		},
	},

	-- ─── Sticky Fingers : fermetures éclair et passages ──────────────────────
	StickyFingers = {
		ZipFlurry = {
			Label = "Zip Flurry", Key = "E", Cooldown = 12, Type = "Flurry",
			Duration = 2.0, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = BLUE,
			TickRate = 0.1, Damage = 0.8, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 5, FinalKnockback = 45,
		},
		UnzipSmash = {
			Label = "Unzip Smash", Key = "R", Cooldown = 12.5, Type = "Strike",
			Duration = 0.8, HitDelay = 0.45, Anim = "Uppercut", PlayerAnim = "CmdPoint", Color = BLUE,
			Damage = 16, Knockback = 50, Range = 10, BoxSize = Vector3.new(8, 8, 11),
		},
		SeamHop = {
			Label = "Seam Hop", Key = "T", Cooldown = 15, Type = "Dash",
			Duration = 0.5, HitDelay = 0.1, Anim = "Dash", PlayerAnim = "CmdDash", Color = BLUE,
			DashSpeed = 110, DashTime = 0.25, Damage = 6, BoxSize = Vector3.new(6, 6, 8),
		},
		ZipLine = {
			Label = "Zip Line", Key = "F", Cooldown = 13, Type = "Pull",
			Duration = 0.7, HitDelay = 0.2, Anim = "Pull", PlayerAnim = "CmdPoint", Color = BLUE,
			Range = 24, Damage = 6, Stun = 1,
		},
		SplitTrap = {
			Label = "Split Trap", Key = "G", Cooldown = 14, Type = "Mine",
			Duration = 0.8, HitDelay = 0.35, Anim = "Plant", PlayerAnim = "CmdPlant", Color = BLUE,
			Offset = 4, Radius = 10, TriggerRadius = 7.5, ArmTime = 0.5, Lifetime = 12,
			Damage = 10, Stun = 1.5,
		},
	},

	-- ─── Made in Heaven : l'accélération ─────────────────────────────────────
	MadeInHeaven = {
		VelocityFlurry = {
			Label = "Velocity Flurry", Key = "E", Cooldown = 12, Type = "Flurry",
			Duration = 1.6, Anim = "Flurry", PlayerAnim = "CmdBrace", Color = CYAN,
			TickRate = 0.07, Damage = 1, Range = 9, BoxSize = Vector3.new(7, 7, 10),
			FinalDamage = 5, FinalKnockback = 45,
		},
		MachChop = {
			Label = "Mach Chop", Key = "R", Cooldown = 15, Type = "Dash",
			Duration = 0.55, HitDelay = 0.1, Anim = "Dash", PlayerAnim = "CmdDash", Color = CYAN,
			DashSpeed = 140, DashTime = 0.3, Damage = 17, BoxSize = Vector3.new(8, 7, 10),
		},
		Accelerate = {
			Label = "Accelerate", Key = "T", Cooldown = 25, Type = "Buff",
			Duration = 0.7, HitDelay = 0.3, Anim = "Raise", PlayerAnim = "CmdSummon", Color = CYAN,
			SpeedBoost = 2, BuffTime = 6,
		},
		OrbitStrike = {
			Label = "Orbit Strike", Key = "F", Cooldown = 13, Type = "Teleport",
			Duration = 0.7, HitDelay = 0.3, Anim = "Strike", PlayerAnim = "CmdDash", Color = CYAN,
			Range = 40, Damage = 20, Knockback = 30, BoxSize = Vector3.new(8, 7, 10),
		},
		EventHorizon = {
			Label = "Event Horizon", Key = "G", Cooldown = 25, Type = "Burst",
			Duration = 1.1, HitDelay = 0.9, Anim = "Raise", PlayerAnim = "CmdSummon", Color = CYAN,
			Offset = 0, Radius = 16, Damage = 30, Knockback = 55, Stun = 1.5,
		},
	},
}
