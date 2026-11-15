-- ShopMenu. Fenêtre BOUTIQUE (touche N) : acheter des flèches et des fruits
-- avec l'argent du jeu. Les prix sont dans ReplicatedStorage/ItemCatalog ;
-- le serveur (Inventory) vérifie l'argent et ajoute l'achat à l'inventaire.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))
local C = UITheme.Colors
local inventoryAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InventoryAction")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("ShopMenu", 8)
local win = UITheme.Window(root, "Boutique", "BOUTIQUE", "Achète des objets avec ton argent · ramasse l'argent au sol pour +"
	.. ItemCatalog.MoneyPickup .. " $", C.Gold, Vector2.new(760, 470))

-- Argent du joueur, en haut à droite de la fenêtre
local wallet = UITheme.Label(win.frame, "", 18, C.Money, UITheme.Bold)
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -60, 0, 16)
wallet.Size = UDim2.fromOffset(170, 26)
wallet.TextXAlignment = Enum.TextXAlignment.Right
wallet.ZIndex = 3

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Size = UDim2.fromScale(1, 1)
grid.Parent = win.body
local gridLayout = Instance.new("UIListLayout")
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Padding = UDim.new(0, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local function cash()
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	return value and value.Value or 0
end

local cards = {}
for _, item in ipairs(ItemCatalog.Items) do
	local qty = 1
	local card = Instance.new("Frame")
	card.Name = item.Id
	card.LayoutOrder = item.Order
	card.Size = UDim2.new(1 / #ItemCatalog.Items, -8, 1, 0)
	card.BackgroundColor3 = C.Card
	card.Parent = grid
	UITheme.Corner(card, 14)
	UITheme.Stroke(card, item.Rare and C.Legend or C.Line, item.Rare and 2.5 or 1.5)
	UITheme.Gradient(card, item.Color:Lerp(C.Card, 0.72), C.Card, 90)

	if item.Rare then
		local tag = UITheme.Label(card, "RARE", 12, C.Night, UITheme.Bold)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -10, 0, 10)
		tag.Size = UDim2.fromOffset(50, 20)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.BackgroundColor3 = C.Legend
		tag.BackgroundTransparency = 0
		UITheme.Corner(tag, 10)
	end

	local icon = UITheme.Label(card, item.Icon, 48, C.Text, UITheme.Body)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 16)
	icon.Size = UDim2.fromOffset(92, 92)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.BackgroundColor3 = item.Color
	icon.BackgroundTransparency = 0.65
	UITheme.Corner(icon, 46)
	UITheme.Stroke(icon, item.Color, 2.5)

	local name = UITheme.Label(card, item.Name, 24, C.Text, UITheme.Title)
	name.Position = UDim2.new(0, 10, 0, 116)
	name.Size = UDim2.new(1, -20, 0, 28)
	name.TextXAlignment = Enum.TextXAlignment.Center

	local desc = UITheme.Label(card, item.Description, 12, C.Muted, UITheme.Body)
	desc.Position = UDim2.new(0, 12, 0, 146)
	desc.Size = UDim2.new(1, -24, 0, 50)
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextYAlignment = Enum.TextYAlignment.Top

	-- quantité
	local qtyRow = Instance.new("Frame")
	qtyRow.BackgroundTransparency = 1
	qtyRow.AnchorPoint = Vector2.new(0.5, 1)
	qtyRow.Position = UDim2.new(0.5, 0, 1, -58)
	qtyRow.Size = UDim2.fromOffset(130, 30)
	qtyRow.Parent = card
	local minus = UITheme.Button(qtyRow, "−", "ghost", 18)
	minus.Size = UDim2.fromOffset(30, 30)
	local plus = UITheme.Button(qtyRow, "+", "ghost", 18)
	plus.AnchorPoint = Vector2.new(1, 0)
	plus.Position = UDim2.new(1, 0, 0, 0)
	plus.Size = UDim2.fromOffset(30, 30)
	local qtyLabel = UITheme.Label(qtyRow, "x1", 18, C.Text, UITheme.Bold)
	qtyLabel.Position = UDim2.fromOffset(30, 0)
	qtyLabel.Size = UDim2.new(1, -60, 1, 0)
	qtyLabel.TextXAlignment = Enum.TextXAlignment.Center

	local buy = UITheme.Button(card, "", "primary", 16)
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -14)
	buy.Size = UDim2.new(1, -24, 0, 38)

	local entry = { buy = buy, qtyLabel = qtyLabel }
	function entry.refresh()
		local total = item.Price * qty
		qtyLabel.Text = "x" .. qty
		buy.Text = "ACHETER  ·  " .. UITheme.Money(total)
		UITheme.SetEnabled(buy, cash() >= total)
	end
	minus.Activated:Connect(function()
		qty = math.max(1, qty - 1)
		entry.refresh()
	end)
	plus.Activated:Connect(function()
		qty = math.min(ItemCatalog.MaxBuy, qty + 1)
		entry.refresh()
	end)
	buy.Activated:Connect(function()
		if not buy.Active then
			win.status.Text = "Pas assez d'argent pour " .. item.Name .. "."
			win.status.TextColor3 = C.Red
			return
		end
		win.status.Text = "Achat en cours…"
		win.status.TextColor3 = C.Muted
		inventoryAction:FireServer("Buy", item.Id, qty)
	end)
	cards[item.Id] = entry
end

local function refresh()
	wallet.Text = UITheme.Money(cash())
	for _, entry in pairs(cards) do
		entry.refresh()
	end
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	stats:WaitForChild("Cash").Changed:Connect(refresh)
	refresh()
end)
refresh()

inventoryAction.OnClientEvent:Connect(function(kind, ok, message, action)
	if kind == "Result" and action == "Buy" then
		win.status.Text = message or ""
		win.status.TextColor3 = ok and C.Green or C.Red
		if ok then UITheme.Toast("🛒  " .. message, C.Gold) end
	end
end)

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Boutique" and open then
		win.status.Text = ""
		refresh()
	end
end)
