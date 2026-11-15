local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRemote = remotes:FindFirstChild("ItemTrade")
if not tradeRemote then
	tradeRemote = Instance.new("RemoteEvent")
	tradeRemote.Name = "ItemTrade"
	tradeRemote.Parent = remotes
end

-- Item-for-item barter between players (Stand Arrow / Requiem Arrow /
-- Rokakaka, held as Backpack Tools). The server owns every decision: who may
-- trade, what each offer contains, and the final swap. The client only
-- renders state it receives back through TradeUpdated snapshots. Tools
-- never move until BOTH players pass the double confirmation (Ready, then a
-- final Confirm), so a cancel or disconnect mid-trade loses nothing.

local TRADE_RANGE = 16
local INVITE_EXPIRY = 10
local REQUEST_DEBOUNCE = 1.5

local TRADABLE = {
	StandArrow = true,
	RequiemArrow = true,
	Rokakaka = true,
}

local invites = {}     -- [targetUserId] = { from = Player, expires = t }
local sessions = {}    -- [userId] = session
local lastRequest = {} -- [userId] = t

local function backpackOf(player)
	return player:FindFirstChild("Backpack")
end

-- Objets échangeables : inventaire + objets en main (voir Inventory).
local function inventoryCounts(player)
	local counts = {}
	for kind, n in Inventory.Counts(player) do
		if TRADABLE[kind] then counts[kind] = n end
	end
	return counts
end

local function getSession(player)
	return sessions[player.UserId]
end

local function otherOf(session, player)
	return session.players[1] == player and session.players[2] or session.players[1]
end

local function snapshot(session, viewer)
	local other = otherOf(session, viewer)
	return {
		partnerName = other.Name,
		myOffer = session.offers[viewer],
		myStage = session.stage[viewer],
		partnerOffer = session.offers[other],
		partnerStage = session.stage[other],
		myInventory = inventoryCounts(viewer),
		partnerInventory = inventoryCounts(other),
	}
end

local function broadcast(session)
	for _, player in session.players do
		if player.Parent then
			tradeRemote:FireClient(player, "TradeUpdated", snapshot(session, player))
		end
	end
end

local function clearSession(session)
	for _, player in session.players do
		sessions[player.UserId] = nil
		player:SetAttribute("Trading", nil)
	end
end

local function endTrade(session, reason)
	clearSession(session)
	for _, player in session.players do
		if player.Parent then
			tradeRemote:FireClient(player, "TradeEnded", reason)
		end
	end
	print("[TradeService] Trade " .. reason .. ":", session.players[1].Name, "<->", session.players[2].Name)
end

-- Pull up to `count` tradable Tool instances of `kind` out of a player's
-- Backpack/character without moving them yet. Tools flagged Consuming
-- (mid-use) are skipped so a half-consumed item is never traded.
local function takeTools(player, kind, count)
	local taken = {}
	for _, container in { backpackOf(player), player.Character } do
		if #taken >= count then break end
		if container then
			for _, child in container:GetChildren() do
				if #taken >= count then break end
				if child:IsA("Tool") and child.Name == kind and not child:GetAttribute("Consuming") then
					table.insert(taken, child)
				end
			end
		end
	end
	return taken
end

local function commitTrade(session)
	local a, b = session.players[1], session.players[2]

	-- Final re-validation: the client's numbers are never trusted. Clamp
	-- every offer to what each player actually holds right now.
	for _, player in { a, b } do
		local counts = inventoryCounts(player)
		for kind, count in session.offers[player] do
			if (counts[kind] or 0) < count then
				print("[TradeService] Clamped", player.Name, kind, "offer to", counts[kind] or 0)
				session.offers[player][kind] = counts[kind] or 0
			end
		end
	end

	-- Les objets passent d'un inventaire à l'autre (Inventory). Un objet
	-- n'est donné que s'il a bien été retiré à son propriétaire.
	local gave = { [a] = {}, [b] = {} }
	local received = { [a] = {}, [b] = {} }
	for _, player in { a, b } do
		local partner = otherOf(session, player)
		for kind, count in session.offers[player] do
			if count > 0 and partner.Parent and Inventory.Remove(player, kind, count) then
				Inventory.Add(partner, kind, count)
				gave[player][kind] = count
				received[partner][kind] = (received[partner][kind] or 0) + count
			end
		end
	end
	task.spawn(Inventory.Save, a)
	task.spawn(Inventory.Save, b)

	clearSession(session)
	for _, player in session.players do
		if player.Parent then
			tradeRemote:FireClient(player, "TradeCompleted", {
				partnerName = otherOf(session, player).Name,
				gave = gave[player],
				received = received[player],
			})
		end
	end
	print("[TradeService] Trade complete:", a.Name, "<->", b.Name)
end

tradeRemote.OnServerEvent:Connect(function(sender, actionName, ...)
	local args = { ... }

	if actionName == "TradeRequest" then
		local now = os.clock()
		if (lastRequest[sender.UserId] or 0) + REQUEST_DEBOUNCE > now then return end
		lastRequest[sender.UserId] = now
		if getSession(sender) then
			tradeRemote:FireClient(sender, "TradeError", "You are already in a trade.")
			return
		end
		-- A GUI request names its target (player list, any distance); a
		-- legacy request with no target falls back to the nearest player
		-- in range.
		local targetId = tonumber(args[1])
		local target = targetId and Players:GetPlayerByUserId(targetId) or nil
		if not target then
			local hrp = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			local best, bestDist = nil, TRADE_RANGE
			for _, other in Players:GetPlayers() do
				if other ~= sender and not getSession(other) then
					local ohrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
					if ohrp then
						local dist = (ohrp.Position - hrp.Position).Magnitude
						if dist <= bestDist then
							best, bestDist = other, dist
						end
					end
				end
			end
			target = best
		end
		if not target then
			tradeRemote:FireClient(sender, "TradeError", "No player nearby to trade with.")
			return
		end
		if target == sender then
			tradeRemote:FireClient(sender, "TradeError", "You cannot trade with yourself.")
			return
		end
		if getSession(target) then
			tradeRemote:FireClient(sender, "TradeError", target.Name .. " is already trading.")
			return
		end
		invites[target.UserId] = { from = sender, expires = now + INVITE_EXPIRY }
		tradeRemote:FireClient(target, "TradeInvite", sender.Name, sender.UserId)
		tradeRemote:FireClient(sender, "TradeSent", target.Name)
		print("[TradeService]", sender.Name, "requested a trade with", target.Name)

	elseif actionName == "TradeRespond" then
		local accept = args[1] == true
		local invite = invites[sender.UserId]
		invites[sender.UserId] = nil
		if not invite then return end
		local requester = invite.from
		if not accept then
			if requester.Parent then
				tradeRemote:FireClient(requester, "TradeDeclined", sender.Name)
			end
			return
		end
		if os.clock() > invite.expires or not requester.Parent then return end
		if getSession(requester) or getSession(sender) then return end
		local session = {
			players = { requester, sender },
			offers = { [requester] = {}, [sender] = {} },
			stage = { [requester] = 0, [sender] = 0 },
		}
		for _, player in session.players do
			sessions[player.UserId] = session
			player:SetAttribute("Trading", true)
			tradeRemote:FireClient(player, "TradeOpened", snapshot(session, player))
		end
		print("[TradeService] Trade opened:", requester.Name, "<->", sender.Name)

	elseif actionName == "TradeSetOffer" then
		local session = getSession(sender)
		if not session then return end
		local offer = args[1]
		if typeof(offer) ~= "table" then return end
		local counts = inventoryCounts(sender)
		local clean = {}
		for kind, count in offer do
			if TRADABLE[kind] and type(count) == "number" and count > 0 then
				local n = math.clamp(math.floor(count), 0, counts[kind] or 0)
				if n > 0 then clean[kind] = n end
			end
		end
		local current = session.offers[sender]
		local same = true
		for kind, count in current do
			if clean[kind] ~= count then same = false break end
		end
		for kind, count in clean do
			if current[kind] ~= count then same = false break end
		end
		if same then return end
		session.offers[sender] = clean
		-- Any offer change revokes BOTH confirmations, so nobody can bait a
		-- partner into accepting a different deal.
		session.stage[session.players[1]] = 0
		session.stage[session.players[2]] = 0
		broadcast(session)

	elseif actionName == "TradeSetStage" then
		-- Two-step confirmation: 0 = editing, 1 = ready, 2 = final confirm.
		-- The swap only executes when BOTH players reach stage 2.
		local session = getSession(sender)
		if not session then return end
		local stage = tonumber(args[1]) or 0
		if stage ~= 0 and stage ~= 1 and stage ~= 2 then return end
		local other = otherOf(session, sender)
		if stage == 2 then
			local total = 0
			for _, offer in session.offers do
				for _, count in offer do total += count end
			end
			if total == 0 then
				tradeRemote:FireClient(sender, "TradeError", "Each side must offer at least one item.")
				return
			end
			-- Re-validate the own offer against reality before the final confirm.
			local counts = inventoryCounts(sender)
			for kind, count in session.offers[sender] do
				if (counts[kind] or 0) < count then
					print("[TradeService]", sender.Name, kind, "offer shrank at confirm:", counts[kind] or 0)
					session.offers[sender][kind] = counts[kind] or 0
					if session.offers[sender][kind] == 0 then
						session.offers[sender][kind] = nil
					end
					stage = 1
					tradeRemote:FireClient(sender, "TradeError", "Your offer no longer matches your items — check it again.")
				end
			end
		end
		session.stage[sender] = stage
		broadcast(session)
		if stage == 2 and session.stage[other] == 2 then
			commitTrade(session)
		end

	elseif actionName == "TradeCancel" then
		local session = getSession(sender)
		if session then
			endTrade(session, "cancelled")
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	invites[player.UserId] = nil
	lastRequest[player.UserId] = nil
	local session = sessions[player.UserId]
	if session then
		-- Nothing was escrowed while offering, so the remaining player keeps
		-- everything they own; the leaver's offer simply dies.
		endTrade(session, "player left")
	end
end)

print("[TradeService] Ready")
