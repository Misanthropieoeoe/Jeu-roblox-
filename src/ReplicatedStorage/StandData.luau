local StandData = {}

StandData.DefaultStand = "StarPlatinum"

StandData.Stands = {
	StarPlatinum = {
		DisplayName = "Star Platinum",
		TemplateName = "StarPlatinumTemplate",
		FollowOffset = Vector3.new(2.50, 1.10, 2.04), -- V14: légèrement décalé pour montrer les coudes
		SummonDuration = 2.05, -- V2 cinematic deployment / server combat lockout
		-- Verified clips sourced from the community asset "Star Platinum The
		-- World (with new sound)" (100% upvoted); both loaded without
		-- permission errors during playtest.
		SummonShoutId = "rbxassetid://5371606324", -- summon roar ("Star_Platinum_Summon" by ilo_en)
		SummonQuoteId = "rbxassetid://3052256550", -- "ORA!" quote on reveal
		-- Single one-time summon voice, same mirror pipeline as the other stands.
		SummonVoicePath = { "StarPlatinum", "SP/Summon" },
		-- ORA ORA ORA barrage loop and heavy punch SFX, both shipped unused in
		-- ServerStorage/JoJo SoundPack until now.
		BarrageVoicePath = { "StarPlatinum", "Attacks/Barrage" },
		HeavyVoicePath = { "StarPlatinum", "Attacks/Heavy" },
		Smoothness = 0.22, -- V10: smoother tracking toward the idle position
		AutoSummon = true,
		ShoutText = "ORA!",
		TimeStopCry = "Star Platinum! The World!",
		Moves = {
			Barrage = {
				Label = "ORA Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45, -- hard cap: Windup + MaxHold
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 40,
				Range = 10,
				Knockback = 55,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			TimeStop = {
				Label = "Za Warudo",
				Key = "F",
				Cooldown = 30,
				Duration = 3,
				Range = 80,
				TimeStopOffset = Vector3.new(0, 2, -3.2),
				TimeStopSmoothness = 0.25,
			},
		},
	},

	TheWorld = {
		DisplayName = "The World",
		TemplateName = "TheWorldTemplate", -- imported The World model on the shared R6 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- Voice clips resolved from ServerStorage/JoJo SoundPack and mirrored
		-- into ReplicatedStorage/StandVoices so every client can play them.
		SummonVoicePath = { "ZaWarudo", "ZW/Summon" },
		BarrageVoicePath = { "ZaWarudo", "Muda" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "MUDA!",
		TimeStopCry = "The World! Toki yo tomare!",
		Theme = {
			Primary = Color3.fromRGB(150, 108, 26),   -- deep gold plate (was plum)
			Secondary = Color3.fromRGB(206, 156, 42), -- amber plate (was purple)
			Skin = Color3.fromRGB(238, 198, 92),      -- light gold skin (was lavender)
			Trim = Color3.fromRGB(38, 110, 70),       -- emerald trim (was gold)
			TrimLight = Color3.fromRGB(120, 200, 150),
			Gem = Color3.fromRGB(232, 62, 62),        -- crimson heart gems (was pink)
			Dark = Color3.fromRGB(28, 26, 20),        -- charcoal joints
			Aura1 = Color3.fromRGB(255, 200, 70),
			Aura2 = Color3.fromRGB(160, 110, 20),
			Outline = Color3.fromRGB(255, 210, 90),
			Body = Color3.fromRGB(222, 172, 52),      -- golden body tint
		},
		Moves = {
			Barrage = {
				Label = "MUDA Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 50,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 45,
				Range = 10,
				Knockback = 60,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			TimeStop = {
				Label = "ZA WARUDO",
				Key = "F",
				Cooldown = 30,
				Duration = 6, -- The World stops time longer than Star Platinum
				Range = 120,
				TimeStopOffset = Vector3.new(0, 2, -3.2),
				TimeStopSmoothness = 0.25,
			},
		},
	},

	TheWorldAU = {
		DisplayName = "The World: Alternate Universe",
		TemplateName = "TheWorldAUTemplate", -- imported TWAU model on its own R6 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- Full Diego Brando voice set: summon cry, MUDA barrage loop, and
		-- recorded ZA WARUDO time-stop cry.
		SummonVoicePath = { "TheWorldAU", "Summon" },
		BarrageVoicePath = { "TheWorldAU", "Barrage" },
		TimeStopVoicePath = { "TheWorldAU", "TimeStop" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "MUDA!",
		TimeStopCry = "The World! Toki yo tomare!",
		Theme = {
			Primary = Color3.fromRGB(196, 186, 148),  -- cream plate
			Secondary = Color3.fromRGB(222, 208, 168), -- pale sand plate
			Skin = Color3.fromRGB(226, 216, 186),      -- pale sand skin
			Trim = Color3.fromRGB(66, 84, 62),         -- dark olive trim
			TrimLight = Color3.fromRGB(245, 240, 220),
			Gem = Color3.fromRGB(214, 80, 96),         -- heart gems
			Dark = Color3.fromRGB(40, 38, 30),
			Aura1 = Color3.fromRGB(255, 240, 200),
			Aura2 = Color3.fromRGB(170, 150, 90),
			Outline = Color3.fromRGB(250, 245, 225),
			Body = Color3.fromRGB(214, 202, 160),
		},
		Moves = {
			Barrage = {
				Label = "MUDA Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 50,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 45,
				Range = 10,
				Knockback = 60,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			TimeStop = {
				Label = "ZA WARUDO",
				Key = "F",
				Cooldown = 30,
				Duration = 6,
				Range = 120,
				TimeStopOffset = Vector3.new(0, 2, -3.2),
				TimeStopSmoothness = 0.25,
			},
		},
	},

	CrazyDiamond = {
		DisplayName = "Crazy Diamond",
		TemplateName = "CrazyDiamondTemplate", -- imported Crazy Diamond model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- User-sourced community clips: summon SFX (Nibbleicious), DORA
		-- barrage cry and heavy "DORA!" punch (Ayiroth).
		SummonVoicePath = { "CrazyDiamond", "Summon" },
		BarrageVoicePath = { "CrazyDiamond", "Barrage" },
		HeavyVoicePath = { "CrazyDiamond", "Heavy" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "DORARARA!",
		Theme = {
			Primary = Color3.fromRGB(196, 84, 130),   -- rose plate
			Secondary = Color3.fromRGB(238, 138, 176), -- bright pink plate
			Skin = Color3.fromRGB(250, 198, 220),     -- pale pink skin
			Trim = Color3.fromRGB(206, 212, 224),     -- silver trim
			TrimLight = Color3.fromRGB(255, 255, 255),
			Gem = Color3.fromRGB(120, 220, 255),      -- cyan gems
			Dark = Color3.fromRGB(70, 30, 50),
			Aura1 = Color3.fromRGB(255, 150, 200),
			Aura2 = Color3.fromRGB(180, 60, 120),
			Outline = Color3.fromRGB(255, 160, 205),
			Body = Color3.fromRGB(240, 150, 190),
		},
		Moves = {
			Barrage = {
				Label = "DORARARA Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 40,
				Range = 10,
				Knockback = 55,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
		},
	},

	SilverChariot = {
		DisplayName = "Silver Chariot",
		TemplateName = "SilverChariotTemplate", -- imported Silver Chariot OVA model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "HORA!",
		Theme = {
			Primary = Color3.fromRGB(168, 174, 190),  -- steel plate
			Secondary = Color3.fromRGB(206, 212, 224), -- bright silver plate
			Skin = Color3.fromRGB(222, 228, 238),      -- pale steel skin
			Trim = Color3.fromRGB(96, 118, 158),       -- blue-steel trim
			TrimLight = Color3.fromRGB(235, 242, 255),
			Gem = Color3.fromRGB(70, 150, 255),        -- sapphire gems
			Dark = Color3.fromRGB(42, 46, 62),
			Aura1 = Color3.fromRGB(225, 232, 245),
			Aura2 = Color3.fromRGB(130, 150, 190),
			Outline = Color3.fromRGB(220, 230, 250),
			Body = Color3.fromRGB(200, 206, 220),
		},
		Moves = {
			Barrage = {
				Label = "Rapid Stabs",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.09,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 12,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 35,
				SelfSlow = 12,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.28,
			},
			HeavyPunch = {
				Label = "Impale",
				Key = "R",
				Cooldown = 4.5,
				Damage = 32,
				Range = 11,
				Knockback = 65,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.25,
			},
		},
	},

	KillerQueen = {
		DisplayName = "Killer Queen",
		TemplateName = "KillerQueenTemplate", -- imported Killer Queen model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		SummonVoicePath = { "KillerQueen", "Summon" },
		-- Barrage voice from the community AUT Killer Queen BTD remodel.
		BarrageVoicePath = { "KillerQueen", "Barrage" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "EXPLODE!",
		Theme = {
			Primary = Color3.fromRGB(188, 74, 138),   -- magenta plate
			Secondary = Color3.fromRGB(232, 122, 176), -- pink plate
			Skin = Color3.fromRGB(248, 186, 212),      -- pale pink skin
			Trim = Color3.fromRGB(72, 58, 86),         -- dark violet trim
			TrimLight = Color3.fromRGB(255, 214, 232),
			Gem = Color3.fromRGB(70, 222, 150),        -- emerald eyes
			Dark = Color3.fromRGB(44, 32, 48),
			Aura1 = Color3.fromRGB(255, 120, 190),
			Aura2 = Color3.fromRGB(150, 40, 110),
			Outline = Color3.fromRGB(255, 140, 200),
			Body = Color3.fromRGB(226, 110, 165),
		},
		Moves = {
			Barrage = {
				Label = "Explosive Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 50,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Bomb Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 55,
				Range = 10,
				Knockback = 70,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
		},
	},

	GoldExperience = {
		DisplayName = "Gold Experience",
		TemplateName = "GoldExperienceTemplate", -- imported Gold Experience model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- Barrage voice ("Rush" cry) from the community ABD Gold Experience model.
		BarrageVoicePath = { "GoldExperience", "Barrage" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "MUDA!",
		Theme = {
			Primary = Color3.fromRGB(216, 166, 72),   -- gold plate
			Secondary = Color3.fromRGB(240, 204, 120), -- bright gold plate
			Skin = Color3.fromRGB(250, 224, 160),      -- warm gold skin
			Trim = Color3.fromRGB(250, 248, 240),      -- white trim
			TrimLight = Color3.fromRGB(255, 250, 235),
			Gem = Color3.fromRGB(255, 110, 70),        -- amber eyes
			Dark = Color3.fromRGB(74, 52, 34),
			Aura1 = Color3.fromRGB(255, 224, 140),
			Aura2 = Color3.fromRGB(140, 200, 100),
			Outline = Color3.fromRGB(255, 226, 150),
			Body = Color3.fromRGB(238, 192, 96),
		},
		Moves = {
			Barrage = {
				Label = "MUDA Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Life Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 45,
				Range = 10,
				Knockback = 55,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
		},
	},

	GoldExperienceRequiem = {
		DisplayName = "Gold Experience Requiem",
		TemplateName = "GoldExperienceRequiemTemplate", -- imported GER model on its own R15 stand rig
		ArrowObtainable = false, -- requiem stand: never granted by Stand Arrows
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- GER's own summon cry, mirrored at startup like the other stands.
		SummonVoicePath = { "GoldExperienceRequiem", "Summon" },
		-- GER's own short barrage cry, stored in ServerStorage/JoJo SoundPack
		-- and mirrored at summon time like the other barrage voices.
		BarrageVoicePath = { "GoldExperienceRequiem", "Barrage" },
		-- Strong punch SFX played on the Requiem Punch (first stand to ship one).
		HeavyVoicePath = { "GoldExperienceRequiem", "HeavyPunch" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "MUDA!",
		Theme = {
			Primary = Color3.fromRGB(238, 196, 96),   -- radiant gold plate
			Secondary = Color3.fromRGB(252, 228, 152), -- bright gold plate
			Skin = Color3.fromRGB(255, 240, 190),     -- luminous gold skin
			Trim = Color3.fromRGB(255, 255, 250),     -- white trim
			TrimLight = Color3.fromRGB(255, 255, 245),
			Gem = Color3.fromRGB(120, 255, 170),      -- emerald requiem eyes
			Dark = Color3.fromRGB(90, 68, 38),
			Aura1 = Color3.fromRGB(255, 240, 170),
			Aura2 = Color3.fromRGB(170, 230, 120),
			Outline = Color3.fromRGB(255, 245, 180),
			Body = Color3.fromRGB(248, 212, 116),
		},
		Moves = {
			Barrage = {
				Label = "REQUIEM Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 3,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 55,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Requiem Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 60,
				Range = 10,
				Knockback = 60,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			-- GER-only mercy move: channels life energy into the person the
			-- stand strikes (nearest target in the hit box). The stand lifts
			-- its right arm and folds the forearm up in front of its chest.
			Heal = {
				Label = "Life Channel",
				Key = "T",
				Cooldown = 10,
				Duration = 1.3,
				HealAmount = 40,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				HealOffset = Vector3.new(0, 1.4, -2.6),
				HealSmoothness = 0.3,
			},
		},
	},

	KingCrimson = {
		DisplayName = "King Crimson",
		TemplateName = "KingCrimsonTemplate", -- imported King Crimson model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- "KING CRIMSON!" epitaph cry, extracted from the community Diavolo
		-- stand model and stored in ServerStorage/JoJo SoundPack, then mirrored
		-- into ReplicatedStorage/StandVoices so every client can play it.
		SummonVoicePath = { "KingCrimson", "Summon" },
		BarrageVoicePath = { "KingCrimson", "Barrage" },
		TimeStopVoicePath = { "KingCrimson", "TimeStop" }, -- recorded Diavolo "this is King Crimson's ability" cry on TIME ERASE
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "CRIMSON!",
		TimeStopCry = "KING CRIMSON!",
		Theme = {
			Primary = Color3.fromRGB(172, 32, 44),    -- crimson plate
			Secondary = Color3.fromRGB(214, 58, 64),  -- bright red plate
			Skin = Color3.fromRGB(238, 126, 124),     -- pale red skin
			Trim = Color3.fromRGB(232, 230, 238),     -- bone-white trim
			TrimLight = Color3.fromRGB(255, 238, 238),
			Gem = Color3.fromRGB(90, 220, 130),       -- green eyes
			Dark = Color3.fromRGB(54, 14, 22),
			Aura1 = Color3.fromRGB(255, 84, 84),
			Aura2 = Color3.fromRGB(128, 12, 24),
			Outline = Color3.fromRGB(255, 70, 80),
			Body = Color3.fromRGB(204, 48, 58),
		},
		Moves = {
			Barrage = {
				Label = "CRIMSON Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 50,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 55,
				Range = 10,
				Knockback = 60,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			TimeStop = {
				Label = "TIME ERASE",
				Key = "F",
				Cooldown = 30,
				Duration = 5,
				Range = 120,
				TimeStopOffset = Vector3.new(0, 2, -3.2),
				TimeStopSmoothness = 0.25,
			},
		},
	},

	HierophantGreen = {
		DisplayName = "Hierophant Green",
		TemplateName = "HierophantGreenTemplate", -- imported Hierophant Green model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- User-sourced community clip: Kakyoin stand summon cry.
		SummonVoicePath = { "HierophantGreen", "Summon" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "EMERALD!",
		Theme = {
			Primary = Color3.fromRGB(24, 122, 74),    -- deep emerald plate
			Secondary = Color3.fromRGB(58, 176, 110), -- bright emerald plate
			Skin = Color3.fromRGB(168, 232, 196),     -- pale green skin
			Trim = Color3.fromRGB(244, 208, 96),      -- gold vine trim
			TrimLight = Color3.fromRGB(255, 236, 170),
			Gem = Color3.fromRGB(70, 255, 150),       -- radiant emerald eyes
			Dark = Color3.fromRGB(18, 56, 40),
			Aura1 = Color3.fromRGB(110, 255, 170),
			Aura2 = Color3.fromRGB(30, 140, 80),
			Outline = Color3.fromRGB(140, 255, 190),
			Body = Color3.fromRGB(64, 178, 116),
		},
		Moves = {
			Barrage = {
				Label = "Emerald Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 12,
				BoxSize = Vector3.new(8, 7, 13),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Emerald Splash",
				Key = "R",
				Cooldown = 5.5,
				Damage = 42,
				Range = 13,
				Knockback = 60,
				BoxSize = Vector3.new(9, 7, 13),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
		},
	},

	MagiciansRed = {
		DisplayName = "Magician's Red",
		TemplateName = "MagicianRedTemplate", -- imported Magician's Red model on its own R6 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "ABDUL!",
		Theme = {
			Primary = Color3.fromRGB(168, 44, 32),   -- deep flame plate
			Secondary = Color3.fromRGB(228, 96, 40), -- ember plate
			Skin = Color3.fromRGB(250, 176, 128),    -- warm ember skin
			Trim = Color3.fromRGB(242, 208, 110),    -- gilded trim
			TrimLight = Color3.fromRGB(255, 232, 170),
			Gem = Color3.fromRGB(255, 190, 60),      -- flame-gold eyes
			Dark = Color3.fromRGB(64, 20, 14),
			Aura1 = Color3.fromRGB(255, 140, 60),
			Aura2 = Color3.fromRGB(180, 40, 20),
			Outline = Color3.fromRGB(255, 170, 90),
			Body = Color3.fromRGB(206, 76, 44),
		},
		Moves = {
			Barrage = {
				Label = "Flame Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.35,
			},
			HeavyPunch = {
				Label = "Crossfire Hurricane",
				Key = "R",
				Cooldown = 6,
				Damage = 50,
				Range = 11,
				Knockback = 62,
				BoxSize = Vector3.new(9, 7, 12),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
		},
	},

	StickyFingers = {
		DisplayName = "Sticky Fingers",
		TemplateName = "StickyFingersTemplate", -- imported Sticky Fingers model on its own R15 stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- ARI ARI barrage cry, extracted from the imported Sticky Fingers
		-- model's bundled "Zipper Fingers Stand Barrage" clip (4139483350).
		BarrageVoicePath = { "StickyFingers", "Barrage" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "ARRIVEDERCI!",
		Theme = {
			Primary = Color3.fromRGB(32, 84, 176),   -- denim-blue plate
			Secondary = Color3.fromRGB(66, 128, 224), -- bright blue plate
			Skin = Color3.fromRGB(178, 210, 250),    -- pale blue skin
			Trim = Color3.fromRGB(230, 236, 246),    -- zipper-silver trim
			TrimLight = Color3.fromRGB(250, 252, 255),
			Gem = Color3.fromRGB(255, 214, 80),      -- gold zipper eyes
			Dark = Color3.fromRGB(20, 40, 78),
			Aura1 = Color3.fromRGB(120, 180, 255),
			Aura2 = Color3.fromRGB(40, 90, 180),
			Outline = Color3.fromRGB(150, 200, 255),
			Body = Color3.fromRGB(70, 128, 220),
		},
		Moves = {
			Barrage = {
				Label = "Zipper Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 45,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.30,
			},
			HeavyPunch = {
				Label = "Zipper Punch",
				Key = "R",
				Cooldown = 5,
				Damage = 46,
				Range = 11,
				Knockback = 58,
				BoxSize = Vector3.new(8, 7, 12),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.28,
			},
		},
	},

	MadeInHeaven = {
		DisplayName = "Made in Heaven",
		TemplateName = "MadeInHeavenTemplate", -- imported Made in Heaven model on its own R6-style stand rig
		FollowOffset = Vector3.new(2.50, 1.10, 2.04),
		SummonDuration = 2.05,
		-- Deploy cry: the community "MADE IN HEAVEN" voice clip.
		SummonVoicePath = { "MadeInHeaven", "Summon" },
		-- Unique barrage loop: the time-warp dash whoosh, matching MIH's
		-- time-acceleration gimmick (no barrage voice clip exists in any
		-- community pack sourced so far).
		BarrageVoicePath = { "MadeInHeaven", "Barrage" },
		Smoothness = 0.22,
		AutoSummon = true,
		ShoutText = "HEAVEN!",
		TimeStopCry = "Made in Heaven!",
		Theme = {
			Primary = Color3.fromRGB(140, 142, 168), -- cosmic-silver plate
			Secondary = Color3.fromRGB(208, 210, 236), -- moonlight plate
			Skin = Color3.fromRGB(238, 238, 248),    -- starlight skin
			Trim = Color3.fromRGB(96, 78, 190),      -- cosmic-violet trim
			TrimLight = Color3.fromRGB(190, 180, 255),
			Gem = Color3.fromRGB(120, 190, 255),     -- star-blue eyes
			Dark = Color3.fromRGB(38, 38, 56),
			Aura1 = Color3.fromRGB(210, 210, 255),
			Aura2 = Color3.fromRGB(110, 100, 200),
			Outline = Color3.fromRGB(230, 230, 255),
			Body = Color3.fromRGB(190, 192, 220),
		},
		Moves = {
			Barrage = {
				Label = "Heaven Barrage",
				Key = "E",
				Cooldown = 15, -- YBA: long cooldown charged when the barrage ENDS
				Duration = 3.45,
				TickRate = 0.1,
				DamagePerTick = 2,
				StunPerTick = 0.15,
				Windup = 0.45,
				MaxHold = 3.0,
				Range = 11,
				BoxSize = Vector3.new(8, 7, 12),
				FinalKnockback = 50,
				SelfSlow = 10,
				BarrageOffset = Vector3.new(0, 1.2, -3.6),
				BarrageSmoothness = 0.32,
			},
			HeavyPunch = {
				Label = "Heavy Punch",
				Key = "R",
				Cooldown = 6,
				Damage = 48,
				Range = 10,
				Knockback = 60,
				BoxSize = Vector3.new(8, 7, 11),
				HeavyOffset = Vector3.new(0, 1.6, -4.2),
				HeavySmoothness = 0.3,
			},
			TimeStop = {
				Label = "TIME ACCELERATION",
				Key = "F",
				Cooldown = 30,
				Duration = 5,
				Range = 120,
				TimeStopOffset = Vector3.new(0, 2, -3.2),
				TimeStopSmoothness = 0.25,
			},
		},
	},
}

-- Letter grades for the StandStatHUD board (JoJo stat-chart style), keyed by
-- stand id. Kept separate from the stand defs so they stay presentation-only.
StandData.StatGrades = {
	StarPlatinum = { Power = "A", Durability = "A", Speed = "A" },
	TheWorld = { Power = "A", Durability = "A", Speed = "A" },
	TheWorldAU = { Power = "A", Durability = "B", Speed = "A" },
	CrazyDiamond = { Power = "A", Durability = "B", Speed = "B" },
	SilverChariot = { Power = "C", Durability = "C", Speed = "A" },
	KillerQueen = { Power = "A", Durability = "B", Speed = "B" },
	GoldExperience = { Power = "C", Durability = "C", Speed = "A" },
	GoldExperienceRequiem = { Power = "A", Durability = "A", Speed = "A" },
	KingCrimson = { Power = "A", Durability = "B", Speed = "B" },
	HierophantGreen = { Power = "C", Durability = "C", Speed = "B" },
	MagiciansRed = { Power = "B", Durability = "C", Speed = "B" },
	StickyFingers = { Power = "B", Durability = "A", Speed = "B" },
	MadeInHeaven = { Power = "B", Durability = "A", Speed = "A+" },
}

-- M1 light punch: a quick jab shared by every stand. Two move entries —
-- LightPunchR / LightPunchL — let the server alternate hands on every click
-- while the client binds both visual states to the same gameplay move.
local LIGHT_PUNCH_DEFAULTS = {
	Label = "Light Punch",
	Key = "M1",
	Cooldown = 0.6,
	Damage = 7,
	Range = 9,
	BoxSize = Vector3.new(7, 7, 10),
	LightOffset = Vector3.new(0, 1.2, -3.2),
	LightSmoothness = 0.45,

	-- Combo : ComboLength coups, le dernier est un coup puissant qui repousse
	-- (même animation et effets que le Heavy Punch, sans toucher à son cooldown).
	ComboLength = 4,
	FinisherDamage = 15,
	FinisherKnockback = 70, -- force du recul (le Heavy Punch est à 55)
	FinisherHitDelay = 0.25, -- moment de l'impact dans l'animation
	FinisherDuration = 0.45, -- durée de l'animation
	FinisherEndLag = 1.0, -- temps avant de pouvoir relancer un M1 après le final
}
for _, def in pairs(StandData.Stands) do
	if def.Moves and not def.Moves.LightPunchR then
		def.Moves.LightPunchR = table.clone(LIGHT_PUNCH_DEFAULTS)
		def.Moves.LightPunchL = table.clone(LIGHT_PUNCH_DEFAULTS)
	end
end

function StandData.GetStand(standId)
	return StandData.Stands[standId]
end

return StandData
