-- Leaderboard. Tableau des scores en haut à droite (remplace celui de
-- Roblox) : chaque joueur, son Stand et son argent, triés par argent.
-- Tab l'ouvre / le replie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local C = UITheme.Colors

local localPlayer = Players.LocalPlayer

-- Cache le tableau de Roblox (réessaie : il n'est pas toujours prêt tout de suite)
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

local _, root = UITheme.Screen("Leaderboard", 4)

local WIDTH = 270
local ROW_H = 30
local MAX_ROWS = 6

local board = Instance.new("Frame")
board.Name = "Board"
board.AnchorPoint = Vector2.new(1, 0)
board.Position = UDim2.new(1, -12, 0, 8)
board.Size = UDim2.fromOffset(WIDTH, 40)
board.BackgroundColor3 = C.Night
board.BackgroundTransparency = 0.12
board.ClipsDescendants = true
board.Parent = root
UITheme.Corner(board, 12)
UITheme.Stroke(board, C.Gold, 1.35, 0.23)
UITheme.Surface(board)

local header = Instance.new("TextButton")
header.Name = "Header"
header.AutoButtonColor = false
header.Text = ""
header.BackgroundColor3 = C.Panel
header.Size = UDim2.new(1, 0, 0, 34)
header.Parent = board
UITheme.Corner(header, 12)
UITheme.Surface(header)
UITheme.Accent(header, C.Gold)

local title = UITheme.Label(header, "JOUEURS", 15, C.Text, UITheme.Title)
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(0.5, 0, 1, 0)
local count = UITheme.Label(header, "", 12, C.Muted, UITheme.Bold)
count.AnchorPoint = Vector2.new(1, 0)
count.Position = UDim2.new(1, -30, 0, 0)
count.Size = UDim2.fromOffset(80, 34)
count.TextXAlignment = Enum.TextXAlignment.Right
local arrow = UITheme.Label(header, "▾", 14, C.Text, UITheme.Bold)
arrow.AnchorPoint = Vector2.new(1, 0)
arrow.Position = UDim2.new(1, -10, 0, 0)
arrow.Size = UDim2.fromOffset(16, 34)
arrow.TextXAlignment = Enum.TextXAlignment.Center

-- en-têtes de colonnes
local columns = Instance.new("Frame")
columns.BackgroundTransparency = 1
columns.Position = UDim2.fromOffset(0, 36)
columns.Size = UDim2.new(1, 0, 0, 16)
columns.Parent = board
local colStand = UITheme.Label(columns, "STAND", 10, C.Muted, UITheme.Bold)
colStand.Position = UDim2.new(0.5, 0, 0, 0)
colStand.Size = UDim2.new(0.28, 0, 1, 0)
local colCash = UITheme.Label(columns, "ARGENT", 10, C.Muted, UITheme.Bold)
colCash.AnchorPoint = Vector2.new(1, 0)
colCash.Position = UDim2.new(1, -12, 0, 0)
colCash.Size = UDim2.new(0.25, 0, 1, 0)
colCash.TextXAlignment = Enum.TextXAlignment.Right

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 54)
list.Size = UDim2.new(1, 0, 0, ROW_H * MAX_ROWS)
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = C.Gold
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = board
local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local rows = {} -- [Player] = row

local function cashOf(player)
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function standName(player)
	if player:GetAttribute("Standless") then return "—" end
	local id = player:GetAttribute("StandId")
	local def = id and StandData.Stands[id]
	return def and def.DisplayName or "—"
end

local function standColor(player)
	local id = player:GetAttribute("StandId")
	local def = id and StandData.Stands[id]
	return def and def.Theme and def.Theme.Aura1 or C.Muted
end

local expanded = true

local function resize()
	local n = 0
	for _ in pairs(rows) do n += 1 end
	count.Text = n .. (n > 1 and " joueurs" or " joueur")
	local listH = math.min(n, MAX_ROWS) * ROW_H
	list.Size = UDim2.new(1, 0, 0, listH)
	local target = expanded and (54 + listH + 6) or 34
	TweenService:Create(board, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(WIDTH, target) }):Play()
	arrow.Text = expanded and "▾" or "▸"
end

local function sortRows()
	local players = {}
	for player in pairs(rows) do table.insert(players, player) end
	table.sort(players, function(a, b)
		local ca, cb = cashOf(a), cashOf(b)
		if ca ~= cb then return ca > cb end
		return a.Name:lower() < b.Name:lower()
	end)
	for rank, player in ipairs(players) do
		local row = rows[player]
		row.frame.LayoutOrder = rank
		row.rank.Text = tostring(rank)
		row.rank.TextColor3 = rank == 1 and C.Gold or (rank == 2 and Color3.fromRGB(210, 215, 230)
			or (rank == 3 and Color3.fromRGB(220, 150, 90) or C.Muted))
	end
end

local function refreshRow(player)
	local row = rows[player]
	if not row then return end
	row.name.Text = player.DisplayName
	row.stand.Text = standName(player)
	row.stand.TextColor3 = standColor(player):Lerp(Color3.new(1, 1, 1), 0.35)
	row.cash.Text = UITheme.Money(cashOf(player))
	sortRows()
end

local function addPlayer(player)
	if rows[player] then return end
	local frame = Instance.new("Frame")
	frame.Name = player.Name
	frame.Size = UDim2.new(1, 0, 0, ROW_H)
	frame.BackgroundColor3 = player == localPlayer and C.Gold or C.Card
	frame.BackgroundTransparency = player == localPlayer and 0.82 or 1
	frame.BorderSizePixel = 0
	frame.Parent = list

	local rank = UITheme.Label(frame, "", 13, C.Muted, UITheme.Bold)
	rank.Position = UDim2.fromOffset(8, 0)
	rank.Size = UDim2.fromOffset(18, ROW_H)
	rank.TextXAlignment = Enum.TextXAlignment.Center

	local name = UITheme.Label(frame, "", 13, C.Text, UITheme.Bold)
	name.Position = UDim2.fromOffset(30, 0)
	name.Size = UDim2.new(0.5, -32, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local stand = UITheme.Label(frame, "", 11, C.Muted, UITheme.Body)
	stand.Position = UDim2.new(0.5, 0, 0, 0)
	stand.Size = UDim2.new(0.28, 0, 1, 0)
	stand.TextTruncate = Enum.TextTruncate.AtEnd

	local cash = UITheme.Label(frame, "", 12, C.Money, UITheme.Bold)
	cash.AnchorPoint = Vector2.new(1, 0)
	cash.Position = UDim2.new(1, -12, 0, 0)
	cash.Size = UDim2.new(0.25, 0, 1, 0)
	cash.TextXAlignment = Enum.TextXAlignment.Right

	rows[player] = { frame = frame, rank = rank, name = name, stand = stand, cash = cash }
	player:GetAttributeChangedSignal("StandId"):Connect(function() refreshRow(player) end)
	player:GetAttributeChangedSignal("Standless"):Connect(function() refreshRow(player) end)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		local value = stats and stats:WaitForChild("Cash", 30)
		if value and rows[player] then
			value.Changed:Connect(function() refreshRow(player) end)
		end
		refreshRow(player)
	end)
	refreshRow(player)
	resize()
end

local function removePlayer(player)
	local row = rows[player]
	if not row then return end
	row.frame:Destroy()
	rows[player] = nil
	sortRows()
	resize()
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

local function toggle()
	expanded = not expanded
	resize()
end
header.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Tab then toggle() end
end)
