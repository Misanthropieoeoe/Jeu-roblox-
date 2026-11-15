-- StandSkins. Les skins de chaque Stand (onglet SKINS, voir SkinMenu).
--
-- Un skin ne change que l'apparence : les dégâts et les attaques restent les
-- mêmes. Il recolore le modèle du Stand en partant de ses couleurs d'origine,
-- pour garder tous les détails (ombres, yeux, joints) :
--   Hue      teinte visée (0..1) pour les pièces colorées ; nil = garde la teinte
--   HueShift décalage de teinte (si pas de Hue)
--   Sat      multiplicateur de saturation   SatAdd  ajout de saturation
--   Val      multiplicateur de luminosité   ValAdd  ajout de luminosité
--   Aura     couleur de l'aura, de la lueur et du contour
--   Material matière forcée sur toutes les pièces (facultatif)
--   Rarity   "Legendaire" ou "Mythique" (le rang au-dessus, très rare)
--   Model    recette de StandSkinModels : ajoute des pièces au modèle
--            (couronne, ailes, halo, cape…) ; Preview = couleurs d'aperçu
-- Le premier skin de chaque Stand est "Classique" : le Stand tel quel.
--
-- Ajouter un skin : une ligne dans SIGNATURE[<Stand>] (ou dans COMMON pour
-- tous les Stands). L'Id ne doit jamais changer (il est sauvegardé).
local StandSkins = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Skins proposés pour tous les Stands
local COMMON = {
	{ Id = "Ombre", Name = "Ombre", Sat = 0.35, Val = 0.42, Aura = rgb(150, 110, 210) },
	{ Id = "Ivoire", Name = "Ivoire", Sat = 0.18, Val = 0.75, ValAdd = 0.32, Aura = rgb(255, 245, 225) },
	{ Id = "Glace", Name = "Glace", Hue = 0.55, Sat = 0.55, SatAdd = 0.08, Val = 0.9, ValAdd = 0.12,
		Aura = rgb(150, 225, 255), Material = Enum.Material.Ice },
}

-- Skins LÉGENDAIRES : un par Stand, ils changent le modèle (StandSkinModels)
local LEGENDARY = {
	StarPlatinum = { Id = "EtoileSouveraine", Name = "Étoile Souveraine", Model = "EtoileSouveraine",
		Hue = 0.64, Val = 0.85, Aura = rgb(120, 150, 255),
		Preview = { rgb(28, 40, 96), rgb(205, 214, 235), rgb(255, 222, 120), rgb(70, 60, 150) } },
	TheWorld = { Id = "MonarqueZenith", Name = "Monarque du Zénith", Model = "MonarqueZenith",
		Hue = 0.12, Sat = 1.1, ValAdd = 0.05, Aura = rgb(255, 205, 90),
		Preview = { rgb(232, 182, 64), rgb(250, 242, 220), rgb(60, 170, 110), rgb(150, 108, 26) } },
	TheWorldAU = { Id = "BeteAbysses", Name = "Bête des Abysses", Model = "BeteAbysses",
		Sat = 0.3, Val = 0.35, Aura = rgb(210, 30, 45),
		Preview = { rgb(24, 20, 24), rgb(222, 210, 190), rgb(200, 30, 40), rgb(70, 10, 20) } },
	CrazyDiamond = { Id = "CoeurCristal", Name = "Cœur de Cristal", Model = "CoeurCristal",
		Hue = 0.9, Sat = 0.8, ValAdd = 0.1, Aura = rgb(255, 160, 215),
		Preview = { rgb(255, 150, 210), rgb(140, 230, 255), rgb(245, 250, 255), rgb(200, 120, 190) } },
	SilverChariot = { Id = "PaladinCeleste", Name = "Paladin Céleste", Model = "PaladinCeleste",
		Sat = 0.4, ValAdd = 0.15, Aura = rgb(180, 210, 255),
		Preview = { rgb(215, 222, 235), rgb(40, 70, 160), rgb(240, 200, 90), rgb(240, 244, 255) } },
	KillerQueen = { Id = "ReineDetonante", Name = "Reine Détonante", Model = "ReineDetonante",
		Hue = 0.93, Aura = rgb(255, 120, 190),
		Preview = { rgb(240, 120, 180), rgb(30, 26, 34), rgb(240, 200, 100), rgb(255, 190, 220) } },
	GoldExperience = { Id = "ArbreVie", Name = "Arbre de Vie", Model = "ArbreVie",
		Hue = 0.1, Sat = 1.1, Aura = rgb(150, 230, 120),
		Preview = { rgb(70, 170, 80), rgb(140, 210, 90), rgb(250, 210, 90), rgb(110, 80, 40) } },
	GoldExperienceRequiem = { Id = "ArbitreEternel", Name = "Arbitre Éternel", Model = "ArbitreEternel",
		Sat = 0.15, ValAdd = 0.35, Aura = rgb(255, 215, 110),
		Preview = { rgb(250, 250, 245), rgb(245, 200, 80), rgb(200, 220, 255), rgb(230, 230, 220) } },
	KingCrimson = { Id = "EmpereurEcarlate", Name = "Empereur Écarlate", Model = "EmpereurEcarlate",
		Hue = 0.98, Sat = 1.15, Val = 0.8, Aura = rgb(220, 30, 60),
		Preview = { rgb(170, 20, 40), rgb(30, 18, 22), rgb(240, 190, 80), rgb(60, 220, 120) } },
	HierophantGreen = { Id = "GardienEmeraude", Name = "Gardien d'Émeraude", Model = "GardienEmeraude",
		Hue = 0.4, Aura = rgb(110, 240, 160),
		Preview = { rgb(40, 160, 90), rgb(120, 240, 170), rgb(240, 210, 110), rgb(20, 90, 50) } },
	MagiciansRed = { Id = "PhenixInfernal", Name = "Phénix Infernal", Model = "PhenixInfernal",
		Hue = 0.04, Sat = 1.2, Aura = rgb(255, 130, 40),
		Preview = { rgb(255, 110, 30), rgb(255, 200, 70), rgb(150, 30, 20), rgb(90, 20, 10) } },
	StickyFingers = { Id = "FermetureCeleste", Name = "Fermeture Céleste", Model = "FermetureCeleste",
		Hue = 0.62, Sat = 0.5, ValAdd = 0.15, Aura = rgb(245, 210, 100),
		Preview = { rgb(240, 242, 250), rgb(50, 90, 200), rgb(245, 205, 90), rgb(160, 180, 230) } },
	MadeInHeaven = { Id = "HorizonInfini", Name = "Horizon Infini", Model = "HorizonInfini",
		Sat = 0.2, ValAdd = 0.3, Aura = rgb(150, 185, 255),
		Preview = { rgb(245, 245, 255), rgb(130, 170, 255), rgb(245, 210, 110), rgb(200, 210, 240) } },
}
for _, skin in LEGENDARY do
	skin.Rarity = "Legendaire"
end

-- Skins MYTHIQUES : un modèle unique, au-dessus des légendaires
local MYTHIC = {
	TheWorldAU = { Id = "ArpenteurNeant", Name = "Arpenteur du Néant", Model = "ArpenteurNeant", Rarity = "Mythique",
		Hue = 0.75, Sat = 0.3, Val = 0.3, Aura = rgb(150, 90, 255),
		Preview = { rgb(18, 14, 30), rgb(140, 70, 255), rgb(90, 230, 255), rgb(190, 190, 215) } },
}

-- Skins propres à chaque Stand
local SIGNATURE = {
	StarPlatinum = {
		{ Id = "BleuNuit", Name = "Bleu nuit", Hue = 0.62, Sat = 1.1, Val = 0.8, Aura = rgb(90, 140, 255) },
		{ Id = "Rubis", Name = "Rubis", Hue = 0.99, Sat = 1.1, Aura = rgb(255, 80, 90) },
	},
	TheWorld = {
		{ Id = "Emeraude", Name = "Émeraude", Hue = 0.38, Aura = rgb(90, 230, 140) },
		{ Id = "Empereur", Name = "Empereur noir", Sat = 0.3, Val = 0.38, Aura = rgb(255, 200, 70) },
	},
	TheWorldAU = {
		{ Id = "Cendres", Name = "Cendres", Sat = 0.12, Val = 0.7, Aura = rgb(200, 200, 210) },
		{ Id = "Sang", Name = "Sang", Hue = 0.985, Sat = 1.2, Val = 0.75, Aura = rgb(230, 40, 50) },
	},
	CrazyDiamond = {
		{ Id = "Saphir", Name = "Saphir", Hue = 0.58, Aura = rgb(110, 180, 255) },
		{ Id = "Quartz", Name = "Quartz rose", Hue = 0.92, Sat = 0.8, ValAdd = 0.08, Aura = rgb(255, 160, 210) },
	},
	SilverChariot = {
		{ Id = "Dore", Name = "Chariot doré", Hue = 0.12, Sat = 1.4, SatAdd = 0.25, Aura = rgb(255, 210, 90) },
		{ Id = "Noir", Name = "Chariot noir", Sat = 0.25, Val = 0.35, Aura = rgb(170, 180, 200) },
	},
	KillerQueen = {
		{ Id = "ReineNoire", Name = "Reine noire", Sat = 0.4, Val = 0.4, Aura = rgb(255, 100, 180) },
		{ Id = "Pourpre", Name = "Pourpre", Hue = 0.8, Sat = 1.1, Aura = rgb(190, 110, 255) },
	},
	GoldExperience = {
		{ Id = "Emeraude", Name = "Émeraude", Hue = 0.38, Aura = rgb(100, 240, 150) },
		{ Id = "Solaire", Name = "Solaire", Hue = 0.07, Sat = 1.2, ValAdd = 0.05, Aura = rgb(255, 150, 60) },
	},
	GoldExperienceRequiem = {
		{ Id = "Violet", Name = "Requiem violet", Hue = 0.78, Aura = rgb(190, 120, 255) },
		{ Id = "Blanc", Name = "Requiem blanc", Sat = 0.2, ValAdd = 0.3, Aura = rgb(255, 250, 230) },
	},
	KingCrimson = {
		{ Id = "Azur", Name = "Roi d'azur", Hue = 0.62, Aura = rgb(90, 150, 255) },
		{ Id = "Or", Name = "Roi doré", Hue = 0.12, Sat = 1.2, Aura = rgb(255, 205, 80) },
	},
	HierophantGreen = {
		{ Id = "Cyan", Name = "Cyan", Hue = 0.5, Aura = rgb(80, 240, 240) },
		{ Id = "Rouge", Name = "Rubis", Hue = 0.0, Aura = rgb(255, 90, 90) },
	},
	MagiciansRed = {
		{ Id = "FlammeBleue", Name = "Flamme bleue", Hue = 0.6, Sat = 1.1, Aura = rgb(90, 160, 255) },
		{ Id = "Charbon", Name = "Charbon", Sat = 0.3, Val = 0.4, Aura = rgb(255, 120, 40) },
	},
	StickyFingers = {
		{ Id = "Dore", Name = "Doré", Hue = 0.12, Sat = 1.3, SatAdd = 0.2, Aura = rgb(255, 210, 90) },
		{ Id = "Violet", Name = "Violet", Hue = 0.78, Sat = 1.2, SatAdd = 0.15, Aura = rgb(180, 120, 255) },
	},
	MadeInHeaven = {
		{ Id = "Nuit", Name = "Ciel de nuit", Hue = 0.66, Sat = 0.9, Val = 0.55, Aura = rgb(120, 140, 255) },
		{ Id = "Aube", Name = "Aube dorée", Hue = 0.11, Sat = 1.1, Aura = rgb(255, 215, 120) },
	},
}

StandSkins.DEFAULT = "Classique"
local CLASSIC = { Id = "Classique", Name = "Classique" }

-- Liste des skins d'un Stand, dans l'ordre d'affichage
function StandSkins.List(standId)
	local list = { CLASSIC }
	if MYTHIC[standId] then
		table.insert(list, MYTHIC[standId])
	end
	if LEGENDARY[standId] then
		table.insert(list, LEGENDARY[standId])
	end
	for _, skin in SIGNATURE[standId] or {} do
		table.insert(list, skin)
	end
	for _, skin in COMMON do
		table.insert(list, skin)
	end
	return list
end

-- Tous les skins légendaires : { { standId, skin }, ... }
function StandSkins.Legendaries()
	local list = {}
	for standId, skin in pairs(LEGENDARY) do
		table.insert(list, { standId = standId, skin = skin })
	end
	table.sort(list, function(a, b) return a.skin.Name < b.skin.Name end)
	-- les mythiques en premier
	local mythics = {}
	for standId, skin in pairs(MYTHIC) do
		table.insert(mythics, { standId = standId, skin = skin })
	end
	table.sort(mythics, function(a, b) return a.skin.Name < b.skin.Name end)
	for i, entry in ipairs(mythics) do
		table.insert(list, i, entry)
	end
	return list
end

function StandSkins.Get(standId, skinId)
	if not skinId or skinId == StandSkins.DEFAULT then return CLASSIC end
	for _, skin in StandSkins.List(standId) do
		if skin.Id == skinId then return skin end
	end
	return CLASSIC
end

function StandSkins.IsValid(standId, skinId)
	for _, skin in StandSkins.List(standId) do
		if skin.Id == skinId then return true end
	end
	return false
end

-- Couleur d'origine -> couleur du skin
function StandSkins.Transform(skin, color)
	if not skin or skin.Id == StandSkins.DEFAULT then return color end
	local h, s, v = Color3.toHSV(color)
	if s > 0.12 then -- les gris, noirs et blancs gardent leur teinte neutre
		if skin.Hue then
			h = skin.Hue
		elseif skin.HueShift then
			h = (h + skin.HueShift) % 1
		end
	end
	s = math.clamp(s * (skin.Sat or 1) + (s > 0.12 and (skin.SatAdd or 0) or 0), 0, 1)
	v = math.clamp(v * (skin.Val or 1) + (skin.ValAdd or 0), 0, 1)
	return Color3.fromHSV(h, s, v)
end

-- Recolore un modèle de Stand fraîchement cloné
function StandSkins.Apply(model, skin)
	if not skin or skin.Id == StandSkins.DEFAULT then return end
	model:SetAttribute("Skin", skin.Id)
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") then
			if obj.Name ~= "HumanoidRootPart" then
				obj.Color = StandSkins.Transform(skin, obj.Color)
				if skin.Material and obj.Material ~= Enum.Material.Neon then
					obj.Material = skin.Material
				end
			end
		elseif obj:IsA("Decal") then -- Decal et Texture
			obj.Color3 = StandSkins.Transform(skin, obj.Color3)
		elseif obj:IsA("SurfaceAppearance") then
			-- teinte des matériaux PBR (si la version de Roblox le permet)
			pcall(function()
				obj.Color = StandSkins.Transform(skin, obj.Color)
			end)
		elseif obj:IsA("ParticleEmitter") and skin.Aura then
			obj.Color = ColorSequence.new(skin.Aura, skin.Aura:Lerp(Color3.new(), 0.4))
		elseif obj:IsA("PointLight") and skin.Aura then
			obj.Color = skin.Aura
		elseif obj:IsA("Highlight") and obj.Name == "StandHighlight" and skin.Aura then
			obj.OutlineColor = skin.Aura
		end
	end
	-- Skin légendaire : nouvelles pièces de modèle (après la recoloration)
	if skin.Model then
		local models = script.Parent:FindFirstChild("StandSkinModels")
		if models then
			require(models).Build(model, skin.Model)
		end
	end
end

return StandSkins
