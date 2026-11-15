-- ItemCatalog. Les objets de l'inventaire et leurs prix en boutique.
-- L'Id est le nom de l'outil (Tool) que le joueur tient en main ; il est
-- sauvegardé, il ne doit donc jamais changer.
local ItemCatalog = {}

ItemCatalog.Items = {
	{
		Id = "StandArrow",
		Name = "Flèche du Stand",
		Icon = "🏹",
		Description = "Éveille un Stand au hasard. Ne marche que si tu n'as pas de Stand.",
		Price = 300,
		Color = Color3.fromRGB(255, 196, 64),
	},
	{
		Id = "Rokakaka",
		Name = "Fruit Rokakaka",
		Icon = "🍑",
		Description = "Efface ton Stand actuel pour pouvoir en éveiller un autre.",
		Price = 200,
		Color = Color3.fromRGB(240, 110, 140),
	},
	{
		Id = "RequiemArrow",
		Name = "Flèche Requiem",
		Icon = "🌟",
		Description = "Fait évoluer Gold Experience en Gold Experience Requiem.",
		Price = 2500,
		Color = Color3.fromRGB(190, 120, 255),
		Rare = true,
		NotInShop = true, -- pas vendue : seulement sur la carte (très rare) ou via ADMIN
	},
}

-- Objets vendus en boutique (ceux sans NotInShop)
ItemCatalog.ShopItems = {}
for _, item in ipairs(ItemCatalog.Items) do
	if not item.NotInShop then
		table.insert(ItemCatalog.ShopItems, item)
	end
end

ItemCatalog.ById = {}
for order, item in ipairs(ItemCatalog.Items) do
	item.Order = order
	ItemCatalog.ById[item.Id] = item
end

-- Coffre de skins (fenêtre SKINS, onglet COFFRES). Les skins sont bloqués
-- pour les joueurs (sauf admins) : on les gagne dans ces coffres.
-- Odds = chance de chaque rareté en % ; Refund = argent rendu pour un doublon.
ItemCatalog.SkinBox = {
	Name = "Coffre de skins",
	Price = 400,
	Odds = { Commun = 75, Legendaire = 22, Mythique = 3 },
	Refund = { Commun = 60, Legendaire = 200, Mythique = 600 },
}

-- Ramassage de l'argent au sol
ItemCatalog.MoneyPickup = 30
-- Nombre maximum d'achats en une fois
ItemCatalog.MaxBuy = 10

return ItemCatalog
