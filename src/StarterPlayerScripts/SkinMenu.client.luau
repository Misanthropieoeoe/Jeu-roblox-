-- SkinMenu. Fenêtre SKINS (touche K) : à gauche la liste des Stands, à
-- droite les skins du Stand sélectionné. Le choix est envoyé au serveur
-- (StandAction "ChooseSkin"), qui le sauvegarde et réinvoque le Stand s'il
-- est sorti. Les skins sont définis dans ReplicatedStorage/StandSkins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local StandSkins = require(ReplicatedStorage:WaitForChild("StandSkins"))
local C = UITheme.Colors
local standAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandAction")
local inventoryAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InventoryAction")
local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local _, root = UITheme.Screen("SkinMenu", 8)
local win = UITheme.Window(root, "Skins", "SKINS", "Change l'apparence de tes Stands · les légendaires changent leur modèle",
	C.Magenta, Vector2.new(780, 500))

-- Stands triés par nom
local standIds = {}
for id in pairs(StandData.Stands) do
	table.insert(standIds, id)
end
table.sort(standIds, function(a, b)
	return StandData.Stands[a].DisplayName < StandData.Stands[b].DisplayName
end)

local function equippedSkin(standId)
	local raw = player:GetAttribute("StandSkins")
	local data = {}
	if type(raw) == "string" and raw ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then data = decoded end
	end
	return data[standId] or StandSkins.DEFAULT
end

-- Colonne des Stands
local TABS_W = 190
local tabsHolder = Instance.new("Frame")
tabsHolder.BackgroundTransparency = 1
tabsHolder.Size = UDim2.new(0, TABS_W, 1, 0)
tabsHolder.Parent = win.body
local tabs = UITheme.Scroll(tabsHolder, C.Magenta)
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 5)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabs

-- Grille des skins
local gridHolder = Instance.new("Frame")
gridHolder.BackgroundTransparency = 1
gridHolder.Position = UDim2.fromOffset(TABS_W + 10, 0)
gridHolder.Size = UDim2.new(1, -(TABS_W + 10), 1, 0)
gridHolder.Parent = win.body
local grid = UITheme.Scroll(gridHolder, C.Magenta)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(170, 128)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local selected
local tabButtons = {}
local skinCards = {}
local pending

local function skinName(standId, skinId)
	return StandSkins.Get(standId, skinId).Name
end

local function refreshTabs()
	local mine = player:GetAttribute("StandId")
	for id, tab in pairs(tabButtons) do
		local active = id == selected
		tab.stroke.Color = active and C.Magenta or (tab.legend and C.Legend or C.Line)
		tab.stroke.Thickness = active and 2.5 or (tab.legend and 2 or 1.5)
		if tab.legend then continue end
		tab.mine.Visible = id == mine
		tab.sub.Text = skinName(id, equippedSkin(id))
	end
end

local LEGEND_TAB = "_Legendaires"
local BOX_TAB = "_Coffres"

-- Skins débloqués : gagnés dans les coffres (attribut OwnedSkins), ou tous
-- pour les admins. Classique est toujours à tout le monde.
local function isAdmin()
	return player:GetAttribute("StandAdmin") == true
end
local function ownedSet()
	local raw = player:GetAttribute("OwnedSkins")
	local set = {}
	if type(raw) == "string" and raw ~= "" then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(list) == "table" then
			for _, key in list do set[key] = true end
		end
	end
	return set
end
local function owns(standId, skinId, set)
	if skinId == StandSkins.DEFAULT or isAdmin() then return true end
	return (set or ownedSet())[standId .. "/" .. skinId] == true
end

local function refreshCards()
	for _, card in pairs(skinCards) do
		local on = card.skinId == equippedSkin(card.standId)
		card.stroke.Color = on and C.Gold or (card.mythic and C.Purple or (card.legendary and C.Legend or C.Line))
		card.stroke.Thickness = on and 3 or (card.legendary and 2 or 1.5)
		card.badge.Visible = on
	end
end

local function previewColors(standId, skin)
	if skin.Preview then
		local colors = table.clone(skin.Preview)
		table.insert(colors, skin.Aura or C.Gold)
		return colors
	end
	local theme = StandData.Stands[standId].Theme or {}
	local colors = {}
	for _, role in { "Primary", "Secondary", "Trim", "Body" } do
		if theme[role] then table.insert(colors, StandSkins.Transform(skin, theme[role])) end
	end
	table.insert(colors, skin.Aura or theme.Aura1 or C.Gold)
	return colors
end

local function choose(standId, skinId)
	if pending then return end
	if equippedSkin(standId) == skinId then
		win.status.Text = skinName(standId, skinId) .. " est déjà équipé."
		win.status.TextColor3 = C.Muted
		return
	end
	pending = { standId, skinId }
	win.status.Text = "Application du skin " .. skinName(standId, skinId) .. "…"
	win.status.TextColor3 = C.Muted
	standAction:FireServer("ChooseSkin", standId, skinId)
	task.delay(3, function()
		if pending and pending[1] == standId and pending[2] == skinId then
			pending = nil
			win.status.Text = "Pas de réponse du serveur, réessaie."
			win.status.TextColor3 = C.Red
		end
	end)
end

-- Remplit la grille. entries = { { standId, skin } }, withStand = afficher
-- le nom du Stand sur la carte (onglet Légendaires)
local boxView -- page des coffres (créée plus bas)
local function fill(entries, withStand)
	gridHolder.Visible = true
	if boxView then boxView.Visible = false end
	local ownedNow = ownedSet()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(skinCards)
	for order, entry in ipairs(entries) do
		local standId, skin = entry.standId, entry.skin
		local mythic = skin.Rarity == "Mythique"
		local legendary = skin.Rarity == "Legendaire" or mythic
		local card, stroke = UITheme.Card(grid)
		card.Name = standId .. "_" .. skin.Id
		card.LayoutOrder = order
		if mythic then
			UITheme.Gradient(card, Color3.fromRGB(200, 150, 255), Color3.fromRGB(110, 210, 255), 45)
		elseif legendary then
			UITheme.Gradient(card, Color3.fromRGB(255, 210, 140), Color3.fromRGB(150, 140, 170), 90)
		end

		local swatches = Instance.new("Frame")
		swatches.BackgroundTransparency = 1
		swatches.Position = UDim2.fromOffset(10, 10)
		swatches.Size = UDim2.new(1, -20, 0, withStand and 40 or 52)
		swatches.Parent = card
		local swLayout = Instance.new("UIListLayout")
		swLayout.FillDirection = Enum.FillDirection.Horizontal
		swLayout.Padding = UDim.new(0, 4)
		swLayout.Parent = swatches
		local colors = previewColors(standId, skin)
		for i, color in ipairs(colors) do
			local sw = Instance.new("Frame")
			sw.LayoutOrder = i
			sw.BackgroundColor3 = color
			sw.BorderSizePixel = 0
			sw.Size = UDim2.new(1 / #colors, -4, 1, 0)
			sw.Parent = swatches
			UITheme.Corner(sw, 6)
		end

		local nameY = withStand and 54 or 68
		local name = UITheme.Label(card, skin.Name, 15, mythic and C.Purple or (legendary and C.Legend or C.Text), UITheme.Title)
		name.Position = UDim2.fromOffset(10, nameY)
		name.Size = UDim2.new(1, -20, 0, 26)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		if withStand then
			local standLabel = UITheme.Label(card, StandData.Stands[standId].DisplayName, 12, C.Text, UITheme.Bold)
			standLabel.Position = UDim2.fromOffset(10, 80)
			standLabel.Size = UDim2.new(1, -20, 0, 16)
			standLabel.TextTruncate = Enum.TextTruncate.AtEnd
		end

		local badge = UITheme.Label(card, "✔ ÉQUIPÉ", 12, C.Gold, UITheme.Bold)
		badge.Position = UDim2.fromOffset(10, 102)
		badge.Size = UDim2.fromOffset(80, 16)
		badge.Visible = false

		if legendary then
			local tag = UITheme.Label(card, mythic and "MYTHIQUE" or "LÉGENDAIRE", 11, mythic and C.Text or C.Night, UITheme.Bold)
			tag.AnchorPoint = Vector2.new(1, 0)
			tag.Position = UDim2.new(1, -8, 0, 100)
			tag.Size = UDim2.fromOffset(82, 20)
			tag.TextXAlignment = Enum.TextXAlignment.Center
			tag.BackgroundColor3 = mythic and C.Purple or C.Legend
			tag.BackgroundTransparency = 0
			UITheme.Corner(tag, 10)
		end

		local unlocked = owns(standId, skin.Id, ownedNow)
		if not unlocked then
			-- skin bloqué : voile sombre et cadenas
			local veil = Instance.new("Frame")
			veil.BackgroundColor3 = C.Night
			veil.BackgroundTransparency = 0.35
			veil.Size = UDim2.fromScale(1, 1)
			veil.ZIndex = 5
			veil.Parent = card
			UITheme.Corner(veil, 10)
			local lock = UITheme.Label(veil, "🔒", 26, C.Text, UITheme.Body)
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position = UDim2.fromScale(0.5, 0.42)
			lock.Size = UDim2.fromOffset(40, 40)
			lock.TextXAlignment = Enum.TextXAlignment.Center
			lock.ZIndex = 6
			local hint = UITheme.Label(veil, "Dans un coffre", 11, C.Muted, UITheme.Bold)
			hint.AnchorPoint = Vector2.new(0.5, 0)
			hint.Position = UDim2.new(0.5, 0, 0.42, 22)
			hint.Size = UDim2.new(1, -10, 0, 16)
			hint.TextXAlignment = Enum.TextXAlignment.Center
			hint.ZIndex = 6
		end

		card.Activated:Connect(function()
			if not owns(standId, skin.Id) then
				win.status.Text = "🔒 " .. skin.Name .. " est bloqué : gagne-le dans un coffre (onglet 🎁 COFFRES)."
				win.status.TextColor3 = C.Gold
				return
			end
			choose(standId, skin.Id)
		end)
		skinCards[card.Name] = { stroke = stroke, badge = badge, legendary = legendary, mythic = mythic, standId = standId, skinId = skin.Id }
	end
	grid.CanvasPosition = Vector2.zero
	refreshTabs()
	refreshCards()
end

local showBoxes -- défini plus bas
local function showStand(standId)
	selected = standId
	if standId == BOX_TAB then
		showBoxes()
		return
	end
	if standId == LEGEND_TAB then
		fill(StandSkins.Legendaries(), true)
		return
	end
	local entries = {}
	for _, skin in ipairs(StandSkins.List(standId)) do
		table.insert(entries, { standId = standId, skin = skin })
	end
	fill(entries, false)
end

-- ─── Coffres de skins ─────────────────────────────────────────────────────────
local BOX = ItemCatalog.SkinBox
local RARITY_COLOR = { Commun = C.Blue, Legendaire = C.Legend, Mythique = C.Purple }
local RARITY_NAME = { Commun = "Commun", Legendaire = "Légendaire", Mythique = "Mythique" }

boxView = Instance.new("Frame")
boxView.Name = "Coffres"
boxView.BackgroundTransparency = 1
boxView.Position = gridHolder.Position
boxView.Size = gridHolder.Size
boxView.Visible = false
boxView.Parent = win.body

-- bande qui défile pendant l'ouverture
local reel = Instance.new("Frame")
reel.Name = "Reel"
reel.BackgroundColor3 = C.Night
reel.BackgroundTransparency = 0.2
reel.Size = UDim2.new(1, 0, 0, 150)
reel.ClipsDescendants = true
reel.Parent = boxView
UITheme.Corner(reel, 12)
UITheme.Stroke(reel, C.Line, 1.35, 0.23)
local strip = Instance.new("Frame")
strip.BackgroundTransparency = 1
strip.Size = UDim2.new(0, 0, 1, 0)
strip.Parent = reel
local needle = Instance.new("Frame")
needle.AnchorPoint = Vector2.new(0.5, 0)
needle.Position = UDim2.fromScale(0.5, 0)
needle.Size = UDim2.new(0, 3, 1, 0)
needle.BackgroundColor3 = C.Gold
needle.BorderSizePixel = 0
needle.ZIndex = 5
needle.Parent = reel
local reelHint = UITheme.Label(reel, "Ouvre un coffre pour gagner un skin au hasard", 14, C.Muted, UITheme.Bold)
reelHint.Size = UDim2.fromScale(1, 1)
reelHint.TextXAlignment = Enum.TextXAlignment.Center
reelHint.ZIndex = 4

local result = UITheme.Label(boxView, "", 16, C.Text, UITheme.Title)
result.Position = UDim2.fromOffset(0, 158)
result.Size = UDim2.new(1, 0, 0, 24)
result.TextXAlignment = Enum.TextXAlignment.Center

-- chances et bouton
local info = Instance.new("Frame")
info.BackgroundTransparency = 1
info.Position = UDim2.fromOffset(0, 190)
info.Size = UDim2.new(1, 0, 1, -190)
info.Parent = boxView
local oddsText = {}
for _, rarity in { "Commun", "Legendaire", "Mythique" } do
	table.insert(oddsText, RARITY_NAME[rarity] .. " " .. (BOX.Odds[rarity] or 0) .. " %")
end
local odds = UITheme.Label(info, "Chances : " .. table.concat(oddsText, "  ·  "), 13, C.Muted, UITheme.Bold)
odds.Size = UDim2.new(1, 0, 0, 18)
odds.TextXAlignment = Enum.TextXAlignment.Center
local refundText = UITheme.Label(info, string.format("Doublon : on te rend %d / %d / %d $", BOX.Refund.Commun, BOX.Refund.Legendaire, BOX.Refund.Mythique),
	12, C.Muted, UITheme.Body)
refundText.Position = UDim2.fromOffset(0, 20)
refundText.Size = UDim2.new(1, 0, 0, 16)
refundText.TextXAlignment = Enum.TextXAlignment.Center
local progress = UITheme.Label(info, "", 13, C.Text, UITheme.Bold)
progress.Position = UDim2.fromOffset(0, 42)
progress.Size = UDim2.new(1, 0, 0, 18)
progress.TextXAlignment = Enum.TextXAlignment.Center
local openButton = UITheme.Button(info, "🎁  OUVRIR UN COFFRE  ·  " .. UITheme.Money(BOX.Price), "primary", 16)
openButton.AnchorPoint = Vector2.new(0.5, 0)
openButton.Position = UDim2.new(0.5, 0, 0, 72)
openButton.Size = UDim2.fromOffset(300, 44)

local function cash()
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	return value and value.Value or 0
end

local spinning = false
local function refreshBox()
	local pool = StandSkins.Pool()
	local total, have = 0, 0
	local set = ownedSet()
	for _, list in pairs(pool) do
		for _, entry in list do
			total += 1
			if set[entry.standId .. "/" .. entry.skin.Id] then have += 1 end
		end
	end
	progress.Text = isAdmin() and "Admin : tous les skins sont débloqués pour toi"
		or string.format("Collection : %d / %d skins débloqués", have, total)
	UITheme.SetEnabled(openButton, not spinning and cash() >= BOX.Price)
end

-- une carte de la bande
local CARD_W, CARD_GAP = 120, 8
local function reelCard(entry, index)
	local rarity = StandSkins.RarityOf(entry.skin)
	local color = RARITY_COLOR[rarity] or C.Blue
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP), 12)
	f.Size = UDim2.fromOffset(CARD_W, 126)
	f.BackgroundColor3 = C.Card
	f.Parent = strip
	UITheme.Corner(f, 10)
	UITheme.Stroke(f, color, 2, 0.1)
	UITheme.Gradient(f, color:Lerp(C.Card, 0.55), C.Card, 90)
	local sw = Instance.new("Frame")
	sw.BackgroundTransparency = 1
	sw.Position = UDim2.fromOffset(8, 8)
	sw.Size = UDim2.new(1, -16, 0, 40)
	sw.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 3)
	layout.Parent = sw
	local colors = previewColors(entry.standId, entry.skin)
	for i, c in ipairs(colors) do
		local s = Instance.new("Frame")
		s.LayoutOrder = i
		s.BackgroundColor3 = c
		s.BorderSizePixel = 0
		s.Size = UDim2.new(1 / #colors, -3, 1, 0)
		s.Parent = sw
		UITheme.Corner(s, 4)
	end
	local n = UITheme.Label(f, entry.skin.Name, 13, C.Text, UITheme.Title)
	n.Position = UDim2.fromOffset(8, 54)
	n.Size = UDim2.new(1, -16, 0, 32)
	n.TextWrapped = true
	n.TextYAlignment = Enum.TextYAlignment.Top
	local st = UITheme.Label(f, StandData.Stands[entry.standId].DisplayName, 10, C.Muted, UITheme.Body)
	st.Position = UDim2.fromOffset(8, 88)
	st.Size = UDim2.new(1, -16, 0, 14)
	st.TextTruncate = Enum.TextTruncate.AtEnd
	local r = UITheme.Label(f, RARITY_NAME[rarity] or rarity, 10, color, UITheme.Bold)
	r.Position = UDim2.fromOffset(8, 104)
	r.Size = UDim2.new(1, -16, 0, 14)
	return f
end

local function randomEntry()
	local pool = StandSkins.Pool()
	local roll = math.random() * 100
	local rarity = roll < BOX.Odds.Mythique and "Mythique" or (roll < BOX.Odds.Mythique + BOX.Odds.Legendaire and "Legendaire" or "Commun")
	local list = #pool[rarity] > 0 and pool[rarity] or pool.Commun
	return list[math.random(#list)]
end

local function spin(data)
	spinning = true
	refreshBox()
	reelHint.Visible = false
	result.Text = ""
	strip:ClearAllChildren()
	strip.Position = UDim2.fromOffset(0, 0)
	local WIN_INDEX, COUNT = 34, 40
	local winner = { standId = data.standId, skin = StandSkins.Get(data.standId, data.skinId) }
	for i = 1, COUNT do
		reelCard(i == WIN_INDEX and winner or randomEntry(), i)
	end
	-- la carte gagnante finit sous l'aiguille (avec un petit décalage au hasard)
	local winCenter = (WIN_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W / 2 + math.random(-40, 40)
	local tween = TweenService:Create(strip, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -winCenter, 0, 0),
	})
	tween:Play()
	tween.Completed:Wait()
	local rarity = data.rarity
	local name = winner.skin.Name .. " (" .. StandData.Stands[data.standId].DisplayName .. ")"
	if data.duplicate then
		result.Text = "Doublon : " .. name .. "  ·  +" .. data.refund .. " $"
		result.TextColor3 = C.Muted
	else
		result.Text = (rarity == "Mythique" and "✦ MYTHIQUE ✦ " or (rarity == "Legendaire" and "★ LÉGENDAIRE ★ " or "Nouveau skin : ")) .. name
		result.TextColor3 = RARITY_COLOR[rarity] or C.Text
		UITheme.Toast("🎁 " .. name .. " débloqué !", RARITY_COLOR[rarity])
	end
	spinning = false
	refreshBox()
end

openButton.Activated:Connect(function()
	if spinning or not openButton.Active then
		if not spinning then
			win.status.Text = "Pas assez d'argent : un coffre coûte " .. UITheme.Money(BOX.Price) .. "."
			win.status.TextColor3 = C.Red
		end
		return
	end
	win.status.Text = ""
	spinning = true
	refreshBox()
	inventoryAction:FireServer("OpenSkinBox")
	task.delay(3, function()
		if spinning and reelHint.Visible then
			spinning = false
			refreshBox()
		end
	end)
end)

inventoryAction.OnClientEvent:Connect(function(kind, a, b, action)
	if kind == "BoxResult" and type(a) == "table" then
		task.spawn(spin, a)
	elseif kind == "Result" and action == "OpenSkinBox" then
		spinning = false
		win.status.Text = b or ""
		win.status.TextColor3 = C.Red
		refreshBox()
	end
end)

showBoxes = function()
	gridHolder.Visible = false
	boxView.Visible = true
	refreshTabs()
	refreshBox()
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	stats:WaitForChild("Cash").Changed:Connect(refreshBox)
end)
player:GetAttributeChangedSignal("OwnedSkins"):Connect(function()
	refreshBox()
	if selected and selected ~= BOX_TAB and gridHolder.Visible then
		showStand(selected)
	end
end)
player:GetAttributeChangedSignal("StandAdmin"):Connect(function()
	refreshBox()
	if selected and selected ~= BOX_TAB and gridHolder.Visible then showStand(selected) end
end)

-- Onglet COFFRES, tout en haut
do
	local button, stroke = UITheme.Card(tabs, C.Gold)
	button.Name = BOX_TAB
	button.LayoutOrder = -1
	button.Size = UDim2.new(1, 0, 0, 50)
	UITheme.Gradient(button, Color3.fromRGB(255, 225, 150), Color3.fromRGB(170, 140, 100), 90)
	local name = UITheme.Label(button, "🎁 COFFRES", 15, C.Gold, UITheme.Title)
	name.Position = UDim2.fromOffset(12, 4)
	name.Size = UDim2.new(1, -20, 0, 24)
	local sub = UITheme.Label(button, "Gagne des skins · " .. UITheme.Money(BOX.Price), 11, C.Text, UITheme.Body)
	sub.Position = UDim2.fromOffset(12, 28)
	sub.Size = UDim2.new(1, -20, 0, 16)
	button.Activated:Connect(function()
		showStand(BOX_TAB)
	end)
	tabButtons[BOX_TAB] = { stroke = stroke, legend = true }
end

standAction.OnClientEvent:Connect(function(actionName, standId, skinId)
	if actionName == "SkinLocked" then
		pending = nil
		win.status.Text = "🔒 Ce skin est bloqué : gagne-le dans un coffre."
		win.status.TextColor3 = C.Gold
	end
end)

-- Onglet de tous les skins légendaires, tout en haut
do
	local button, stroke = UITheme.Card(tabs)
	button.Name = LEGEND_TAB
	button.LayoutOrder = 0
	button.Size = UDim2.new(1, 0, 0, 50)
	UITheme.Gradient(button, Color3.fromRGB(255, 205, 120), Color3.fromRGB(170, 130, 90), 90)
	local name = UITheme.Label(button, "★ LÉGENDAIRES", 15, C.Legend, UITheme.Title)
	name.Position = UDim2.fromOffset(10, 4)
	name.Size = UDim2.new(1, -20, 0, 24)
	local sub = UITheme.Label(button, "Mythiques et légendaires", 11, C.Text, UITheme.Body)
	sub.Position = UDim2.fromOffset(10, 28)
	sub.Size = UDim2.new(1, -20, 0, 16)
	button.Activated:Connect(function()
		showStand(LEGEND_TAB)
	end)
	tabButtons[LEGEND_TAB] = { stroke = stroke, legend = true }
end

for order, id in ipairs(standIds) do
	local def = StandData.Stands[id]
	local button, stroke = UITheme.Card(tabs)
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 50)

	local name = UITheme.Label(button, def.DisplayName, 14, C.Text, UITheme.Bold)
	name.Position = UDim2.fromOffset(10, 6)
	name.Size = UDim2.new(1, -20, 0, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = UITheme.Label(button, "", 12, C.Muted, UITheme.Body)
	sub.Position = UDim2.fromOffset(10, 26)
	sub.Size = UDim2.new(1, -60, 0, 16)
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	local mine = UITheme.Label(button, "TOI", 10, C.Night, UITheme.Bold)
	mine.AnchorPoint = Vector2.new(1, 0)
	mine.Position = UDim2.new(1, -8, 0, 26)
	mine.Size = UDim2.fromOffset(34, 16)
	mine.TextXAlignment = Enum.TextXAlignment.Center
	mine.BackgroundColor3 = C.Magenta
	mine.BackgroundTransparency = 0
	mine.Visible = false
	UITheme.Corner(mine, 8)

	button.Activated:Connect(function()
		showStand(id)
	end)
	tabButtons[id] = { stroke = stroke, sub = sub, mine = mine }
end

UITheme.WindowChanged:Connect(function(name, open)
	if name == "Skins" and open then
		win.status.Text = ""
		local mine = player:GetAttribute("StandId")
		local ok, err = pcall(showStand, (mine and StandData.Stands[mine]) and mine or selected or standIds[1])
		if not ok then
			warn("[SkinMenu] Erreur à l'ouverture :", err)
			win.status.Text = "Erreur d'affichage des skins (voir Output)."
			win.status.TextColor3 = C.Red
		end
	end
end)

player:GetAttributeChangedSignal("StandSkins"):Connect(function()
	refreshTabs()
	refreshCards()
	if pending and equippedSkin(pending[1]) == pending[2] then
		win.status.Text = "Skin " .. skinName(pending[1], pending[2]) .. " équipé !"
		win.status.TextColor3 = C.Green
		pending = nil
	end
end)
player:GetAttributeChangedSignal("StandId"):Connect(refreshTabs)
