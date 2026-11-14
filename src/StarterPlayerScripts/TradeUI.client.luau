local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local tradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemTrade")
local localPlayer = Players.LocalPlayer

-- Trade UI, all GUI-driven:
--   B opens a player picker; clicking a name sends a trade request.
--   The target gets an Accept/Decline prompt.
--   The trade window has a DOUBLE confirmation: Ready first, then a final
--   "Confirm Trade" modal that spells out exactly what is given/received.
--   Any offer change by either side resets both confirmations.
-- All authoritative state comes from the server via snapshots.

local TRADABLE = {
	{ id = "StandArrow", label = "Stand Arrow" },
	{ id = "RequiemArrow", label = "Requiem Arrow" },
	{ id = "Rokakaka", label = "Rokakaka" },
}

local PANEL = Color3.fromRGB(24, 24, 30)
local PANEL_LINE = Color3.fromRGB(58, 58, 68)
local ROW_BG = Color3.fromRGB(18, 18, 24)
local TEXT = Color3.fromRGB(235, 235, 240)
local MUTED = Color3.fromRGB(150, 150, 160)
local GREEN = Color3.fromRGB(70, 180, 100)
local AMBER = Color3.fromRGB(235, 165, 60)
local BTN = Color3.fromRGB(58, 58, 70)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("TradeUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TradeUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function make(class, props, parent)
	local inst = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

-- ---------- toast ----------
local toast = make("TextLabel", {
	Size = UDim2.fromOffset(440, 34),
	Position = UDim2.new(0.5, 0, 0, 60),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = ROW_BG,
	BackgroundTransparency = 0.15,
	Text = "",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	Visible = false,
	ZIndex = 60,
}, gui)
corner(toast, 8)

local toastTween
local function showToast(text)
	toast.Text = text
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.15
	if toastTween then toastTween:Cancel() end
	toastTween = TweenService:Create(
		toast,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1.8),
		{ TextTransparency = 1, BackgroundTransparency = 1 }
	)
	toastTween.Completed:Once(function()
		toast.Visible = false
	end)
	toastTween:Play()
end

-- ---------- player picker (T) ----------
local picker = make("Frame", {
	Size = UDim2.fromOffset(320, 360),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 45,
}, gui)
corner(picker, 12)
make("UIStroke", { Color = PANEL_LINE, Thickness = 1 }, picker)

make("TextLabel", {
	Size = UDim2.new(1, -56, 0, 40),
	Position = UDim2.fromOffset(18, 0),
	BackgroundTransparency = 1,
	Text = "Pick a player to trade with",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 46,
}, picker)

local pickerClose = make("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -40, 0, 6),
	BackgroundColor3 = BTN,
	Text = "X",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	ZIndex = 46,
}, picker)
corner(pickerClose, 8)

local pickerList = make("ScrollingFrame", {
	Size = UDim2.new(1, -32, 1, -76),
	Position = UDim2.fromOffset(16, 48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 46,
}, picker)
local pickerLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, pickerList)

local function refreshPicker()
	for _, child in pickerList:GetChildren() do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end
	local order = 0
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer then
			order += 1
			local btn = make("TextButton", {
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = BTN,
				Text = other.DisplayName,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamMedium,
				TextSize = 15,
				LayoutOrder = order,
				ZIndex = 47,
			}, pickerList)
			corner(btn, 8)
			btn.Activated:Connect(function()
				tradeRemote:FireServer("TradeRequest", other.UserId)
				picker.Visible = false
			end)
		end
	end
	if order == 0 then
		make("TextLabel", {
			Size = UDim2.new(1, -8, 0, 44),
			BackgroundTransparency = 1,
			Text = "No other players in this server.",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamMedium,
			TextSize = 16,
			LayoutOrder = 1,
			ZIndex = 47,
		}, pickerList)
	end
end

pickerClose.Activated:Connect(function()
	picker.Visible = false
end)

-- ---------- invite prompt ----------
local inviteFrame = make("Frame", {
	Size = UDim2.fromOffset(360, 118),
	Position = UDim2.new(0.5, 0, 1, -140),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.06,
	Visible = false,
	ZIndex = 40,
}, gui)
corner(inviteFrame, 10)
make("UIStroke", { Color = PANEL_LINE, Thickness = 1 }, inviteFrame)

make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 44),
	Position = UDim2.fromOffset(12, 8),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	TextWrapped = true,
	ZIndex = 41,
}, inviteFrame).Name = "InviteText"

local inviteFromName = nil
local inviteStamp = 0

local acceptBtn = make("TextButton", {
	Size = UDim2.fromOffset(150, 38),
	Position = UDim2.new(0, 20, 1, -50),
	BackgroundColor3 = GREEN,
	Text = "Accept",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	ZIndex = 41,
}, inviteFrame)
corner(acceptBtn, 8)

local declineBtn = make("TextButton", {
	Size = UDim2.fromOffset(150, 38),
	Position = UDim2.new(1, -170, 1, -50),
	BackgroundColor3 = BTN,
	Text = "Decline",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	ZIndex = 41,
}, inviteFrame)
corner(declineBtn, 8)

acceptBtn.Activated:Connect(function()
	if inviteFromName then
		tradeRemote:FireServer("TradeRespond", true)
	end
	inviteFromName = nil
	inviteFrame.Visible = false
end)
declineBtn.Activated:Connect(function()
	if inviteFromName then
		tradeRemote:FireServer("TradeRespond", false)
	end
	inviteFromName = nil
	inviteFrame.Visible = false
end)

-- ---------- trade window ----------
local window = make("Frame", {
	Size = UDim2.fromOffset(580, 400),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 30,
}, gui)
corner(window, 12)
make("UIStroke", { Color = PANEL_LINE, Thickness = 1 }, window)

local windowTitle = make("TextLabel", {
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.fromOffset(18, 0),
	BackgroundTransparency = 1,
	Text = "Trading",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 31,
}, window)

local closeBtn = make("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -40, 0, 6),
	BackgroundColor3 = BTN,
	Text = "X",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	ZIndex = 31,
}, window)
corner(closeBtn, 8)

local function buildColumn(xOffset, titleText)
	local column = make("Frame", {
		Size = UDim2.fromOffset(270, 268),
		Position = UDim2.fromOffset(xOffset, 46),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, window)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	}, column)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
		Text = "Offered",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	}, column)

	local offerList = make("Frame", {
		Size = UDim2.new(1, 0, 0, 94),
		Position = UDim2.fromOffset(0, 46),
		BackgroundColor3 = ROW_BG,
		BackgroundTransparency = 0.3,
		ZIndex = 31,
	}, column)
	corner(offerList, 8)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, offerList)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
	}, offerList)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 146),
		BackgroundTransparency = 1,
		Text = "Items",
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	}, column)

	local itemList = make("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		Position = UDim2.fromOffset(0, 166),
		BackgroundColor3 = ROW_BG,
		BackgroundTransparency = 0.3,
		ZIndex = 31,
	}, column)
	corner(itemList, 8)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, itemList)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
	}, itemList)

	return { offerList = offerList, itemList = itemList }
end

local myColumn = buildColumn(16, "You")
local theirColumn = buildColumn(294, "Them")

local statusLabel = make("TextLabel", {
	Size = UDim2.new(1, -220, 0, 40),
	Position = UDim2.fromOffset(18, 340),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = MUTED,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	ZIndex = 31,
}, window)

local readyBtn = make("TextButton", {
	Size = UDim2.fromOffset(180, 40),
	Position = UDim2.new(1, -198, 1, -52),
	BackgroundColor3 = BTN,
	Text = "Ready",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 16,
	ZIndex = 31,
}, window)
corner(readyBtn, 8)

-- ---------- final confirmation modal (second confirmation) ----------
local modalDim = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 50,
}, gui)

local modal = make("Frame", {
	Size = UDim2.fromOffset(380, 230),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = PANEL,
	Visible = false,
	ZIndex = 51,
}, modalDim)
corner(modal, 12)
make("UIStroke", { Color = AMBER, Thickness = 1.5 }, modal)

make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 8),
	BackgroundTransparency = 1,
	Text = "Final confirmation",
	TextColor3 = AMBER,
	Font = Enum.Font.GothamMedium,
	TextSize = 17,
	ZIndex = 52,
}, modal)

local modalBody = make("TextLabel", {
	Size = UDim2.new(1, -32, 0, 108),
	Position = UDim2.fromOffset(16, 42),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = TEXT,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 52,
}, modal)

local modalConfirm = make("TextButton", {
	Size = UDim2.fromOffset(160, 40),
	Position = UDim2.new(0, 18, 1, -52),
	BackgroundColor3 = GREEN,
	Text = "Confirm Trade",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	ZIndex = 52,
}, modal)
corner(modalConfirm, 8)

local modalBack = make("TextButton", {
	Size = UDim2.fromOffset(120, 40),
	Position = UDim2.new(1, -138, 1, -52),
	BackgroundColor3 = BTN,
	Text = "Go Back",
	TextColor3 = TEXT,
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	ZIndex = 52,
}, modal)
corner(modalBack, 8)

-- ---------- rendering ----------
local currentSnap = nil

local function describe(counts)
	local parts = {}
	for _, item in TRADABLE do
		local count = counts and counts[item.id]
		if count and count > 0 then
			table.insert(parts, ("%s x%d"):format(item.label, count))
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "nothing"
end

local function clearRows(container)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function addRow(container, text, buttonText, onClick, orderIndex)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = orderIndex,
		ZIndex = 32,
	}, container)
	local label = make("TextLabel", {
		Size = UDim2.new(1, buttonText and -30 or 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 32,
	}, row)
	if buttonText then
		local btn = make("TextButton", {
			Size = UDim2.fromOffset(26, 18),
			Position = UDim2.new(1, -26, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = BTN,
			Text = buttonText,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			ZIndex = 33,
		}, row)
		corner(btn, 5)
		btn.Activated:Connect(onClick)
	end
	return label
end

local function sendOffer(kind, newCount)
	if not currentSnap then return end
	local offer = {}
	for k, v in currentSnap.myOffer do
		offer[k] = v
	end
	if newCount <= 0 then
		offer[kind] = nil
	else
		offer[kind] = newCount
	end
	tradeRemote:FireServer("TradeSetOffer", offer)
end

local function renderMySide(snap)
	clearRows(myColumn.offerList)
	local order = 0
	local any = false
	for _, item in TRADABLE do
		local count = snap.myOffer[item.id]
		if count and count > 0 then
			any = true
			order += 1
			local kind = item.id
			addRow(myColumn.offerList,
				("%s x%d"):format(item.label, count), "-",
				function() sendOffer(kind, (snap.myOffer[kind] or 0) - 1) end,
				order)
		end
	end
	if not any then
		addRow(myColumn.offerList, "Nothing offered yet", nil, nil, 1)
	end

	clearRows(myColumn.itemList)
	order = 0
	any = false
	for _, item in TRADABLE do
		local held = snap.myInventory[item.id] or 0
		if held > 0 then
			any = true
			order += 1
			local kind = item.id
			addRow(myColumn.itemList,
				("%s  (held %d)"):format(item.label, held), "+",
				function() sendOffer(kind, (snap.myOffer[kind] or 0) + 1) end,
				order)
		end
	end
	if not any then
		addRow(myColumn.itemList, "No tradable items", nil, nil, 1)
	end
end

local function renderTheirSide(snap)
	clearRows(theirColumn.offerList)
	local order = 0
	local any = false
	for _, item in TRADABLE do
		local count = snap.partnerOffer[item.id]
		if count and count > 0 then
			any = true
			order += 1
			addRow(theirColumn.offerList, ("%s x%d"):format(item.label, count), nil, nil, order)
		end
	end
	if not any then
		addRow(theirColumn.offerList, "Nothing offered yet", nil, nil, 1)
	end

	clearRows(theirColumn.itemList)
	order = 0
	any = false
	for _, item in TRADABLE do
		local held = snap.partnerInventory[item.id] or 0
		if held > 0 then
			any = true
			order += 1
			addRow(theirColumn.itemList, ("%s  (held %d)"):format(item.label, held), nil, nil, order)
		end
	end
	if not any then
		addRow(theirColumn.itemList, "No tradable items", nil, nil, 1)
	end
end

local function applySnapshot(snap)
	currentSnap = snap
	windowTitle.Text = "Trading with " .. snap.partnerName
	renderMySide(snap)
	renderTheirSide(snap)

	local mine, theirs = snap.myStage or 0, snap.partnerStage or 0
	if (snap.myStage or 0) == 0 and modalDim.Visible then
		-- The offer changed underneath the modal: confirmations were reset.
		modalDim.Visible = false
	end
	if mine == 0 then
		readyBtn.Text = "Ready"
		readyBtn.BackgroundColor3 = BTN
	elseif mine == 1 then
		readyBtn.Text = "Confirm Trade"
		readyBtn.BackgroundColor3 = AMBER
	else
		readyBtn.Text = "Confirmed"
		readyBtn.BackgroundColor3 = GREEN
	end

	if mine == 2 and theirs == 2 then
		statusLabel.Text = "Both confirmed — swapping items..."
		statusLabel.TextColor3 = GREEN
	elseif theirs == 2 then
		statusLabel.Text = snap.partnerName .. " has confirmed. Confirm to complete the trade."
		statusLabel.TextColor3 = GREEN
	elseif mine == 2 then
		statusLabel.Text = "Waiting for " .. snap.partnerName .. " to confirm..."
		statusLabel.TextColor3 = MUTED
	elseif theirs == 1 then
		statusLabel.Text = snap.partnerName .. " is ready. Double-check the deal, then Confirm."
		statusLabel.TextColor3 = GREEN
	elseif mine == 1 then
		statusLabel.Text = "You are ready. Review the deal, then press Confirm Trade."
		statusLabel.TextColor3 = MUTED
	else
		statusLabel.Text = "Add items, then Ready -> final Confirm."
		statusLabel.TextColor3 = MUTED
	end
end

local function hideWindow()
	currentSnap = nil
	window.Visible = false
	modalDim.Visible = false
end

readyBtn.Activated:Connect(function()
	if not currentSnap then return end
	local stage = currentSnap.myStage or 0
	if stage == 0 then
		tradeRemote:FireServer("TradeSetStage", 1)
	elseif stage == 1 then
		-- Second confirmation: show exactly what is being exchanged.
		modalBody.Text = ("You give: %s\nYou receive: %s\n\nThis cannot be undone.")
			:format(describe(currentSnap.myOffer), describe(currentSnap.partnerOffer))
		modalDim.Visible = true
	end
end)

modalConfirm.Activated:Connect(function()
	modalDim.Visible = false
	tradeRemote:FireServer("TradeSetStage", 2)
end)

modalBack.Activated:Connect(function()
	modalDim.Visible = false
end)

closeBtn.Activated:Connect(function()
	tradeRemote:FireServer("TradeCancel")
	hideWindow()
end)

-- ---------- remote events ----------
tradeRemote.OnClientEvent:Connect(function(event, a)
	if event == "TradeInvite" then
		inviteFromName = a
		inviteStamp = os.clock()
		inviteFrame.InviteText.Text = tostring(a) .. " wants to trade with you"
		inviteFrame.Visible = true
		task.delay(10.5, function()
			if inviteFromName == a and os.clock() - inviteStamp >= 10 then
				inviteFromName = nil
				inviteFrame.Visible = false
			end
		end)
	elseif event == "TradeSent" then
		showToast("Trade request sent to " .. tostring(a) .. ".")
	elseif event == "TradeDeclined" then
		showToast(tostring(a) .. " declined your trade request.")
	elseif event == "TradeError" then
		showToast(tostring(a))
	elseif event == "TradeOpened" then
		inviteFromName = nil
		inviteFrame.Visible = false
		picker.Visible = false
		applySnapshot(a)
		window.Visible = true
	elseif event == "TradeUpdated" then
		if window.Visible then
			applySnapshot(a)
		end
	elseif event == "TradeEnded" then
		hideWindow()
		showToast("Trade " .. tostring(a) .. ".")
	elseif event == "TradeCompleted" then
		hideWindow()
		showToast(("Traded with %s — gave %s, received %s.")
			:format(a.partnerName, describe(a.gave), describe(a.received)))
	end
end)

-- ---------- B: open the player picker ----------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.B then return end
	if window.Visible then return end
	if picker.Visible then
		picker.Visible = false
	else
		refreshPicker()
		picker.Visible = true
	end
end)

print("[TradeUI] Ready - B opens the trade player picker")
