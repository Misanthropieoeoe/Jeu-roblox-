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
	},
}

ItemCatalog.ById = {}
for order, item in ipairs(ItemCatalog.Items) do
	item.Order = order
	ItemCatalog.ById[item.Id] = item
end

-- Ramassage de l'argent au sol
ItemCatalog.MoneyPickup = 30
-- Nombre maximum d'achats en une fois
ItemCatalog.MaxBuy = 10

return ItemCatalog
