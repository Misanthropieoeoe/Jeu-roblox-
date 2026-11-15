local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GripUtil = require(ReplicatedStorage:WaitForChild("GripUtil"))

local ItemCatalog = require(ReplicatedStorage:WaitForChild("ItemCatalog"))
-- L'argent ramassé au sol va directement dans l'argent du joueur (+30).
-- Il est sauvegardé par Inventory.
local CASH_PER_STACK = ItemCatalog.MoneyPickup
require(script.Parent:WaitForChild("Inventory"))
local SPAWN_INTERVAL = 60 -- a new stack drops every minute
local MAX_STACKS = 6 -- cap so the map never floods
local STACK_LIFETIME = 240

local template = ServerStorage:WaitForChild("MoneyStackModel")

-- ==================== CASH (leaderstats) ====================
local function ensureCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	if not leaderstats:FindFirstChild("Cash") then
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = 0
		cash.Parent = leaderstats
	end
end

Players.PlayerAdded:Connect(ensureCash)
for _, player in Players:GetPlayers() do
	ensureCash(player)
end

-- ==================== REMOTES ====================
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	or ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local moneyEvent = remotes:FindFirstChild("MoneyEvent") or Instance.new("RemoteEvent")
moneyEvent.Name = "MoneyEvent"
moneyEvent.Parent = remotes

-- ==================== MAP PROBE (same approach as StandService items) ====================
local itemMap = nil
local mapCF, floorY
local spawnPoints = {}

local itemRay = RaycastParams.new()
itemRay.FilterType = Enum.RaycastFilterType.Include

local function refreshMapInfo()
	if mapCF then return true end
	itemMap = itemMap or workspace:FindFirstChild("OLD A BIZARRE DAY")
	if not itemMap or not itemMap:FindFirstChild("SpawnPads") then
		return false
	end
	mapCF, mapSize = itemMap:GetBoundingBox()
	local organs = itemMap:FindFirstChild("MapOrgans")
	local floorPart = organs and organs:FindFirstChild("Floor")
	floorY = floorPart and floorPart.Position.Y or mapCF.Position.Y
	itemRay.FilterDescendantsInstances = { itemMap }
	local pads = itemMap:FindFirstChild("SpawnPads")
	if pads then
		for _, pad in pads:GetChildren() do
			if pad:IsA("SpawnLocation") then
				table.insert(spawnPoints, pad.Position)
			end
		end
	end
	print("[MoneyItems] Map ready:", mapCF.Position, "| spawn points:", #spawnPoints)
	return true
end

-- Endroit au hasard sur toute la carte (MapSpots) ; repli près des spawns
local MapSpots = require(script.Parent:WaitForChild("MapSpots"))
local function findGroundSpot(others)
	local spot = MapSpots.Random(others)
	if spot then return spot end
	if not refreshMapInfo() or #spawnPoints == 0 then return nil end
	local start = math.random(#spawnPoints)
	for i = 0, #spawnPoints - 1 do
		local base = spawnPoints[(start + i - 1) % #spawnPoints + 1]
		local angle = math.rad(math.random() * 360)
		local dist = 12 + math.random() * 8
		local x = base.X + math.cos(angle) * dist
		local z = base.Z + math.sin(angle) * dist
		local hit = workspace:Raycast(Vector3.new(x, base.Y + 30, z), Vector3.new(0, -150, 0), itemRay)
		if hit and hit.Position.Y < floorY + 6 then
			return Vector3.new(x, hit.Position.Y, z)
		end
	end
	return nil
end

-- ==================== WORLD PROP + TOOL BUILDERS ====================
local moneyFolder = Instance.new("Folder")
moneyFolder.Name = "MoneyItems"
moneyFolder.Parent = workspace

local function biggestPart(model)
	local best, bestVol = nil, 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local vol = part.Size.X * part.Size.Y * part.Size.Z
			if vol > bestVol then
				bestVol = vol
				best = part
			end
		end
	end
	return best
end

local function prepareItemParts(model)
	if model:IsA("BasePart") then
		model.Anchored = true
		model.CanCollide = false
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

local function buildMoneyItem()
	local model = template:Clone()
	model.Name = "StackOfMoney"
	-- Real-world scale: size the stack to ~1.4 studs across so it reads on the map.
	local biggest = math.max(model.Size.X, model.Size.Y, model.Size.Z)
	if biggest > 0 then
		model.Size = model.Size * (1.4 / biggest)
	end
	prepareItemParts(model)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 255, 140)
	glow.Range = 8
	glow.Brightness = 1.2
	glow.Parent = model
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(140, 255, 150), Color3.fromRGB(255, 224, 130))
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.25)
	sparkle.Transparency = NumberSequence.new(0.2, 1)
	sparkle.LightEmission = 1
	sparkle.Parent = model
	return model
end

local useMoney -- forward declaration; defined below

local function buildMoneyTool(player)
	local tool = Instance.new("Tool")
	tool.Name = "StackOfMoney"
	tool.ToolTip = "Stack of Money - use to bank $" .. CASH_PER_STACK
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = template:Clone()
	local biggest = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
	if biggest > 0 then
		handle.Size = handle.Size * (1.0 / biggest)
	end
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Grip = GripUtil.buildGrip(handle, "axe")
	-- Clicking with the stack equipped banks it (server-side Activated).
	tool.Activated:Connect(function()
		useMoney(player, tool)
	end)
	return tool
end

-- Gentle bob + spin for every live stack (one shared Heartbeat loop).
local spinBases = {}
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for item, base in pairs(spinBases) do
		if item.Parent then
			item:PivotTo(base
				* CFrame.new(0, math.sin(t * 2 + base.X * 0.7) * 0.22, 0)
				* CFrame.Angles(0, t * 1.6, 0))
		else
			spinBases[item] = nil
		end
	end
end)

local function consumeItem(item)
	if item:IsA("BasePart") then
		TweenService:Create(item, TweenInfo.new(0.35), {
			Transparency = 1,
			CFrame = item.CFrame + Vector3.new(0, 3, 0),
		}):Play()
	end
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.35), {
				Transparency = 1,
				CFrame = part.CFrame + Vector3.new(0, 3, 0),
			}):Play()
		end
	end
	task.delay(0.4, function() item:Destroy() end)
end

-- ==================== PICKUP ====================
local function onItemTouched(item, hit)
	if item:GetAttribute("Claimed") then return end
	local character = hit and hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then return end
	item:SetAttribute("Claimed", true)
	spinBases[item] = nil

	cash.Value += CASH_PER_STACK
	moneyEvent:FireClient(player, "Gained", CASH_PER_STACK, cash.Value)
	print("[MoneyItems]", player.Name, "ramasse +" .. CASH_PER_STACK, "(total " .. cash.Value .. ")")

	consumeItem(item)
end

-- ==================== USE (bank the cash) ====================
useMoney = function(player, tool)
	if not tool or not tool:IsA("Tool") or not tool.Parent then return end
	if tool:GetAttribute("Consuming") then return end
	-- Server re-verifies ownership instead of trusting the client.
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	if tool.Parent ~= backpack and tool.Parent ~= character then return end
	if player:GetAttribute("Trading") then
		moneyEvent:FireClient(player, "Denied", "You can't use items while trading.")
		return
	end
	tool:SetAttribute("Consuming", true)

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += CASH_PER_STACK
	end
	moneyEvent:FireClient(player, "Used", CASH_PER_STACK, cash and cash.Value or 0)
	print("[MoneyItems]", player.Name, "banked a Stack of Money (+$" .. CASH_PER_STACK .. ")")
	task.delay(0.3, function()
		if tool and tool.Parent then tool:Destroy() end
	end)
end

-- ==================== SPAWN LOOP: one stack every minute ====================
local function spawnMoney()
	local spot = findGroundSpot(moneyFolder:GetChildren())
	if not spot then return end
	local model = buildMoneyItem()
	local baseCF = CFrame.new(spot + Vector3.new(0, 1.4, 0))
	model:PivotTo(baseCF)
	spinBases[model] = baseCF
	model.Parent = moneyFolder

	model.Touched:Connect(function(hit)
		onItemTouched(model, hit)
	end)

	task.delay(STACK_LIFETIME, function()
		if model.Parent and not model:GetAttribute("Claimed") then
			spinBases[model] = nil
			model:Destroy()
		end
	end)
end

task.spawn(function()
	local readyDeadline = os.clock() + 30
	while not refreshMapInfo() and os.clock() < readyDeadline do
		task.wait(0.5)
	end
	if not mapCF then
		warn("[MoneyItems] Map never became ready; money spawns disabled")
		return
	end
	spawnMoney() -- seed one immediately
	print("[MoneyItems] Seeded first Stack of Money")
	while true do
		task.wait(SPAWN_INTERVAL)
		local live = 0
		for _, child in moneyFolder:GetChildren() do
			if child.Name == "StackOfMoney" then
				live += 1
			end
		end
		if live < MAX_STACKS then
			spawnMoney()
			print("[MoneyItems] Stack of Money spawned (every-" .. SPAWN_INTERVAL .. "s tick)")
		end
	end
end)

print("[MoneyService] Ready")
