-- LEMONADE_UI_SCALE_CONVERTER (managed by Lemonade, do not edit or remove)
-- Pixel (Offset) values in Lemonade UIs are authored for a 1920x1080 screen.
-- This multiplies every pixel value under the ScreenGuis this script sees by
-- the fit of that reference inside the current viewport, so phones and
-- tablets show the desktop layout scaled down instead of desktop-sized pixels.
-- Scale fractions already follow the screen and stay as they are.
local lemonadeUiScale_REFERENCE = Vector2.new(1920, 1080)
local lemonadeUiScale_ATTRIBUTE_PREFIX = "LemonadeUiScale_"
-- Roblox sizes its own PlayerGui ScreenGuis (touch controls, prompts, chat,
-- freecam) for the device already.
local lemonadeUiScale_ROBLOX_SCREEN_GUIS = {
	TouchGui = true,
	ProximityPrompts = true,
	Chat = true,
	BubbleChat = true,
	Freecam = true,
}
local lemonadeUiScale_PIXEL_PROPERTIES = {
	GuiObject = { "Size", "Position" },
	TextLabel = { "TextSize" },
	TextButton = { "TextSize" },
	TextBox = { "TextSize" },
	ImageLabel = { "TileSize" },
	ImageButton = { "TileSize" },
	ScrollingFrame = { "CanvasSize", "ScrollBarThickness" },
	UIStroke = { "Thickness" },
	UICorner = { "CornerRadius" },
	UIPadding = { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" },
	UIListLayout = { "Padding" },
	UIPageLayout = { "Padding" },
	UITableLayout = { "Padding" },
	UIGridLayout = { "CellSize", "CellPadding" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
}

local function lemonadeUiScale_factor(viewport: Vector2): number
	return math.min(viewport.X / lemonadeUiScale_REFERENCE.X, viewport.Y / lemonadeUiScale_REFERENCE.Y)
end

local function lemonadeUiScale_scaleValue(value: any, factor: number): any
	local kind = typeof(value)
	if kind == "UDim" then
		return UDim.new(value.Scale, math.round(value.Offset * factor))
	end
	if kind == "UDim2" then
		return UDim2.new(
			value.X.Scale,
			math.round(value.X.Offset * factor),
			value.Y.Scale,
			math.round(value.Y.Offset * factor)
		)
	end
	return value * factor
end

-- The authored value is kept as an attribute so repeat passes, clones and
-- viewport changes always scale from it and never compound or drift.
local function lemonadeUiScale_apply(instance: Instance, factor: number)
	local target = instance :: any
	for className, properties in lemonadeUiScale_PIXEL_PROPERTIES do
		if not instance:IsA(className) then
			continue
		end
		for _, property in properties do
			local attribute = lemonadeUiScale_ATTRIBUTE_PREFIX .. property
			local authored = instance:GetAttribute(attribute)
			if authored == nil then
				authored = target[property]
				if lemonadeUiScale_scaleValue(authored, 2) == authored then
					continue
				end
				instance:SetAttribute(attribute, authored)
			end
			target[property] = lemonadeUiScale_scaleValue(authored, factor)
		end
	end
end

local function lemonadeUiScale_hasOwnScale(screenGui: ScreenGui): boolean
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("UIScale") and not descendant.Parent:IsA("GuiButton") then
			return true
		end
	end
	return false
end

local function lemonadeUiScale_shouldScale(screenGui: ScreenGui): boolean
	return not lemonadeUiScale_ROBLOX_SCREEN_GUIS[screenGui.Name] and not lemonadeUiScale_hasOwnScale(screenGui)
end

local function lemonadeUiScale_convert(screenGui: ScreenGui, factor: number)
	-- A UIScale is the tree's own responsiveness; scaling pixels as well
	-- would shrink it twice.
	if not lemonadeUiScale_shouldScale(screenGui) then
		return
	end
	for _, descendant in screenGui:GetDescendants() do
		lemonadeUiScale_apply(descendant, factor)
	end
end

local lemonadeUiScale_RunService = game:GetService("RunService")
if lemonadeUiScale_RunService:IsRunning() and lemonadeUiScale_RunService:IsClient() then
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local managed: { [ScreenGui]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function currentFactor(): number
		return lemonadeUiScale_factor(camera.ViewportSize)
	end
	playerGui.ChildAdded:Connect(function(child)
		if not child:IsA("ScreenGui") then
			return
		end
		task.defer(function()
			lemonadeUiScale_RunService.RenderStepped:Wait()
			if not lemonadeUiScale_shouldScale(child) then
				return
			end
			managed[child] = true
			lemonadeUiScale_convert(child, currentFactor())
			-- Deferred so properties the builder sets right after parenting are
			-- read as authored.
			child.DescendantAdded:Connect(function(descendant)
				task.defer(function()
					if descendant:IsDescendantOf(child) then
						lemonadeUiScale_apply(descendant, currentFactor())
					end
				end)
			end)
		end)
	end)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local factor = currentFactor()
		for screenGui in managed do
			lemonadeUiScale_convert(screenGui, factor)
		end
	end)
end
-- END LEMONADE_UI_SCALE_CONVERTER

-- layout: notification-alert
-- Toasts for map item pickups: Stand Arrow (random stand granted) and
-- Rokakaka (stand erased). Fired by StandService over StandAction.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))

local RARE_STANDS = { TheWorld = true, KingCrimson = true, MadeInHeaven = true }

-- Stand icons, copied from the picker tiles so toasts match what the player
-- just received.
local STAND_ICONS = {
	StarPlatinum = "rbxassetid://112684829478873",
	TheWorld = "rbxassetid://109014091086075",
	CrazyDiamond = "rbxassetid://75581768563141",
	SilverChariot = "rbxassetid://94091032987086",
	KillerQueen = "rbxassetid://96872034340553",
	GoldExperience = "rbxassetid://122842695290895",
	KingCrimson = "rbxassetid://73214946386499",
	HierophantGreen = "rbxassetid://73150429062000",
	MagiciansRed = "rbxassetid://73214946386499",
	StickyFingers = "rbxassetid://134595823778256",
	MadeInHeaven = "rbxassetid://109014091086075",
}

local ICON_TARGET = "rbxassetid://120517988406723"
local ICON_FRUIT = "rbxassetid://120786616810420"

local CHIP_W = 460
local CHIP_H = 60
local HOLD_TIME = 4
local MAX_TOASTS = 3

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StandPickupToasts"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Transparent stack: top-center, newest toast at the TOP, growing downward.
local stack = Instance.new("Frame")
stack.Name = "ToastStack"
stack.AnchorPoint = Vector2.new(0.5, 0)
stack.Position = UDim2.new(0.5, 0, 0.03, 0)
stack.Size = UDim2.new(0, CHIP_W, 0, MAX_TOASTS * (CHIP_H + 10))
stack.BackgroundTransparency = 1
stack.Parent = screenGui
local stackLayout = Instance.new("UIListLayout")
stackLayout.FillDirection = Enum.FillDirection.Vertical
stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
stackLayout.Padding = UDim.new(0, 10)
stackLayout.Parent = stack

local toastOrder = 0
local liveToasts = {}

local function buildToast(faceColor, iconAsset, message)
	toastOrder -= 1

	-- Bevel base: dark shade + black border stroke (the outline lives here).
	local base = Instance.new("Frame")
	base.Name = "Toast"
	base.LayoutOrder = toastOrder
	base.Size = UDim2.fromOffset(CHIP_W, CHIP_H)
	base.BackgroundColor3 = faceColor:Lerp(Color3.new(0, 0, 0), 0.65)
	base.BorderSizePixel = 0
	base.ClipsDescendants = false
	base.Parent = stack
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = base

	-- Color face: white + vertical gradient carrying the type color.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 0.94, 0)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = base.ZIndex + 1
	face.Parent = base
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), faceColor)
	grad.Parent = face

	-- Stud pattern, edge to edge, tile square ~60% of chip height (clamped).
	local pattern = Instance.new("ImageLabel")
	pattern.Name = "Studs"
	pattern.Size = UDim2.new(1, 0, 1, 0)
	pattern.BackgroundTransparency = 1
	pattern.Image = "rbxassetid://92521981645530"
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(40, 40)
	pattern.ZIndex = face.ZIndex
	pattern.Parent = face

	-- Icon: square, ~65% of chip height, left margin.
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0.015, 4, 0.5, 0)
	icon.Size = UDim2.fromOffset(39, 39)
	icon.BackgroundTransparency = 1
	icon.Image = iconAsset
	icon.ScaleType = Enum.ScaleType.Fit
	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = icon
	icon.ZIndex = face.ZIndex + 1
	icon.Parent = face

	-- One-line message, white + glyph stroke, truncates at the end.
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 56, 0.5, 0)
	label.Size = UDim2.new(1, -68, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = message
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = face.ZIndex + 1
	label.Parent = face
	local glyph = Instance.new("UIStroke")
	glyph.Color = Color3.new(0, 0, 0)
	glyph.Thickness = 2.5
	glyph.Parent = label

	-- Pop in, hold, shrink out, destroy.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = base
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	task.delay(HOLD_TIME, function()
		if base.Parent then
			local out = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0,
			})
			out:Play()
			out.Completed:Wait()
			base:Destroy()
			liveToasts[base] = nil
		end
	end)
	liveToasts[base] = true

	-- Never more than 3 visible: drop the oldest.
	while #stack:GetChildren() > MAX_TOASTS + 1 do
		local oldest = nil
		for _, child in stack:GetChildren() do
			if child:IsA("Frame") and (not oldest or child.LayoutOrder > oldest.LayoutOrder) then
				oldest = child
			end
		end
		if oldest then
			liveToasts[oldest] = nil
			oldest:Destroy()
		else
			break
		end
	end
end

local function showArrowToast(standId)
	local def = StandData.GetStand(standId)
	local name = def and def.DisplayName or standId
	local rare = RARE_STANDS[standId]
	local message = rare
		and ("RARE STAND! The Arrow granted " .. string.upper(name) .. "!")
		or ("STAND ARROW! You got " .. string.upper(name) .. "!")
	buildToast(
		Color3.fromRGB(255, 200, 70),
		STAND_ICONS[standId] or ICON_TARGET,
		message
	)
end

local function showRequiemToast(standId)
	local def = StandData.GetStand(standId)
	local name = def and def.DisplayName or standId
	buildToast(
		Color3.fromRGB(120, 255, 150),
		STAND_ICONS[standId] or ICON_TARGET,
		"REQUIEM ARROW! " .. string.upper(name) .. " has awakened!"
	)
end

local function showRokakakaToast()
	buildToast(
		Color3.fromRGB(239, 28, 28),
		ICON_FRUIT,
		"ROKAKAKA! Your stand was erased - use a Stand Arrow for a new one"
	)
end

local function showDeniedToast(kind)
	if kind == "Arrow" then
		buildToast(
			Color3.fromRGB(239, 28, 28),
			ICON_TARGET,
			"You already have a Stand! Eat a Rokakaka to erase it first"
		)
		return
	end
	if kind == "RequiemArrow" then
		local standId = Players.LocalPlayer:GetAttribute("StandId")
		local message = standId and standId ~= "GoldExperience"
			and "The Requiem Arrow only answers Gold Experience!"
			or "The Requiem Arrow only answers Gold Experience - get it from a Stand Arrow first"
		buildToast(
			Color3.fromRGB(239, 28, 28),
			ICON_TARGET,
			message
		)
		return
	end
	buildToast(
		Color3.fromRGB(239, 28, 28),
		ICON_FRUIT,
		"You have no Stand to erase!"
	)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local standAction = remotes:WaitForChild("StandAction")
standAction.OnClientEvent:Connect(function(actionName, ...)
	local args = { ... }
	if actionName == "StandPicked" then
		if args[1] == "Arrow" then
			showArrowToast(tostring(args[2]))
		elseif args[1] == "RequiemArrow" then
			showRequiemToast(tostring(args[2]))
		elseif args[1] == "Rokakaka" then
			showRokakakaToast()
		end
	elseif actionName == "ItemDenied" then
		showDeniedToast(args[1])
	end
end)

print("[StandPickupToast] Ready")

-- Dev preview hook: fire this BindableEvent with ("Arrow", standId) or
-- ("Rokakaka") to preview a toast without picking an item up.
local demo = Instance.new("BindableEvent")
demo.Name = "__StandPickupToastDemo"
demo.Parent = ReplicatedStorage
demo.Event:Connect(function(kind, standId)
	if kind == "Arrow" then
		showArrowToast(standId or "StarPlatinum")
	else
		showRokakakaToast()
	end
end)

-- ==================== ITEM ACTIVATION + ROKAKAKA CONFIRM ====================
-- layout: centered-dialog
-- Inventory items are Tools: activating a Stand Arrow fires "UseArrow"
-- immediately; activating a Rokakaka first opens this confirmation dialog.

local TweenService = game:GetService("TweenService")

local PRESS_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local function addPressFeedback(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function scaleTo(target)
		TweenService:Create(scale, PRESS_TWEEN, { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function() scaleTo(1.06) end)
	button.MouseLeave:Connect(function() scaleTo(1) end)
	button.MouseButton1Down:Connect(function() scaleTo(0.94) end)
	button.MouseButton1Up:Connect(function() scaleTo(1.06) end)
end

local function applyCloseButton(titleBar)
	for _, n in { "Close", "CloseButton", "Exit", "ExitButton", "X" } do
		local old = titleBar.Parent:FindFirstChild(n, true)
		if old then old:Destroy() end
	end
	local btn = Instance.new("TextButton")
	btn.Name = "Close"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Size = UDim2.new(0.05, 0, 0.66, 0)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -6, 0.5, 0)
	btn.BackgroundColor3 = Color3.fromRGB(120, 14, 14)
	btn.BorderSizePixel = 0
	btn.Parent = titleBar
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn
	local face = Instance.new("Frame")
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 0.90, 0)
	face.ZIndex = btn.ZIndex + 1
	face.Parent = btn
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 130, 130), Color3.fromRGB(239, 28, 28))
	grad.Parent = face
	local x = Instance.new("TextLabel")
	x.BackgroundTransparency = 1
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)
	x.Size = UDim2.fromScale(0.7, 0.7)
	x.Font = Enum.Font.FredokaOne
	x.Text = "X"
	x.TextColor3 = Color3.new(1, 1, 1)
	x.TextScaled = true
	x.ZIndex = face.ZIndex + 1
	x.Parent = face
	local xs = Instance.new("UIStroke")
	xs.Color = Color3.new(0, 0, 0)
	xs.Thickness = 3
	xs.Parent = x
	addPressFeedback(btn)
	return btn
end

local STUDS_ID = "rbxassetid://92521981645530"

local localPlayer = Players.LocalPlayer

local confirmGui = Instance.new("ScreenGui")
confirmGui.Name = "RokakakaConfirm"
confirmGui.ResetOnSpawn = false
confirmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
confirmGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Panel: 45% x 55% of the screen, centered, center-y at 0.45.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.45, 0)
panel.Size = UDim2.fromScale(0.45, 0.55)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.40
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = confirmGui
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.new(0, 0, 0)
panelStroke.Thickness = 4
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent = panel

-- Title bar: dark base + FLAT solid face, icon + left-aligned title.
local TITLE_H = 0.135
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, TITLE_H, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(70, 16, 16)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
local titleBarStroke = Instance.new("UIStroke")
titleBarStroke.Color = Color3.new(0, 0, 0)
titleBarStroke.Thickness = 4
titleBarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
titleBarStroke.Parent = titleBar
local titleFace = Instance.new("Frame")
titleFace.Name = "Face"
titleFace.Size = UDim2.new(1, 0, 0.88, 0)
titleFace.BackgroundColor3 = Color3.fromRGB(178, 44, 44)
titleFace.BorderSizePixel = 0
titleFace.ZIndex = titleBar.ZIndex + 1
titleFace.Parent = titleBar
local titleIcon = Instance.new("ImageLabel")
titleIcon.Name = "Icon"
titleIcon.Size = UDim2.fromOffset(50, 50)
titleIcon.Position = UDim2.new(0.015, 0, 0.5, 0)
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = ICON_FRUIT
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.ZIndex = titleFace.ZIndex + 1
titleIcon.Parent = titleFace
local titleIconAspect = Instance.new("UIAspectRatioConstraint")
titleIconAspect.AspectRatio = 1
titleIconAspect.Parent = titleIcon
local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.new(0.085, 0, 0, 0)
titleText.Size = UDim2.new(0.8, 0, 1, 0)
titleText.Font = Enum.Font.FredokaOne
titleText.Text = "USE ROKAKAKA"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.TextScaled = true
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = titleFace.ZIndex + 1
titleText.Parent = titleFace
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.new(0, 0, 0)
titleStroke.Thickness = 3
titleStroke.Parent = titleText
local titlePattern = Instance.new("ImageLabel")
titlePattern.Name = "Studs"
titlePattern.Size = UDim2.new(1, 0, 1, 0)
titlePattern.BackgroundTransparency = 1
titlePattern.Image = STUDS_ID
titlePattern.ImageTransparency = 0.55
titlePattern.ScaleType = Enum.ScaleType.Tile
titlePattern.TileSize = UDim2.fromOffset(104, 104)
titlePattern.ZIndex = titleFace.ZIndex
titlePattern.Parent = titleFace
local closeBtn = applyCloseButton(titleBar)
closeBtn.ZIndex = 10
for _, child in closeBtn:GetChildren() do
	if child:IsA("GuiObject") then
		child.ZIndex = math.max(child.ZIndex, closeBtn.ZIndex + 1)
	end
end

-- Content region under the title bar, one vertical centered stack.
local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.new(0, 0, TITLE_H, 0)
content.Size = UDim2.new(1, 0, 1 - TITLE_H, 0)
content.BackgroundTransparency = 1
content.Parent = panel
local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0.04, 0)
contentLayout.Parent = content

-- Block 1: big fruit icon, centered.
local iconBlock = Instance.new("Frame")
iconBlock.Name = "IconBlock"
iconBlock.LayoutOrder = 1
iconBlock.Size = UDim2.new(1, 0, 0.30, 0)
iconBlock.BackgroundTransparency = 1
iconBlock.Parent = content
local bigIcon = Instance.new("ImageLabel")
bigIcon.Name = "Fruit"
bigIcon.AnchorPoint = Vector2.new(0.5, 0.5)
bigIcon.Position = UDim2.fromScale(0.5, 0.5)
bigIcon.Size = UDim2.fromOffset(120, 120)
bigIcon.BackgroundTransparency = 1
bigIcon.Image = ICON_FRUIT
bigIcon.ScaleType = Enum.ScaleType.Fit
bigIcon.ZIndex = 2
bigIcon.Parent = iconBlock
local bigIconAspect = Instance.new("UIAspectRatioConstraint")
bigIconAspect.AspectRatio = 1
bigIconAspect.Parent = bigIcon

-- Block 2: heading, bare label.
local headingBlock = Instance.new("Frame")
headingBlock.Name = "HeadingBlock"
headingBlock.LayoutOrder = 2
headingBlock.Size = UDim2.new(1, 0, 0.10, 0)
headingBlock.BackgroundTransparency = 1
headingBlock.Parent = content
local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.BackgroundTransparency = 1
heading.AnchorPoint = Vector2.new(0.5, 0.5)
heading.Position = UDim2.fromScale(0.5, 0.5)
heading.Size = UDim2.new(0.8, 0, 1, 0)
heading.Font = Enum.Font.FredokaOne
heading.Text = "Eat the Rokakaka?"
heading.TextColor3 = Color3.new(1, 1, 1)
heading.TextScaled = true
heading.ZIndex = 2
heading.Parent = headingBlock
local headingStroke = Instance.new("UIStroke")
headingStroke.Color = Color3.new(0, 0, 0)
headingStroke.Thickness = 3
headingStroke.Parent = heading

-- Block 3: warning line, centered inside the panel.
local warnBlock = Instance.new("Frame")
warnBlock.Name = "WarnBlock"
warnBlock.LayoutOrder = 3
warnBlock.Size = UDim2.new(1, 0, 0.18, 0)
warnBlock.BackgroundTransparency = 1
warnBlock.Parent = content
local warn = Instance.new("TextLabel")
warn.Name = "Warning"
warn.BackgroundTransparency = 1
warn.AnchorPoint = Vector2.new(0.5, 0)
warn.Position = UDim2.fromScale(0.5, 0)
warn.Size = UDim2.new(0.8, 0, 1, 0)
warn.Font = Enum.Font.FredokaOne
warn.Text = "Your current Stand will be ERASED!\nUse a Stand Arrow later to gain a new one."
warn.TextColor3 = Color3.fromRGB(255, 130, 120)
warn.TextScaled = true
warn.TextWrapped = true
warn.TextYAlignment = Enum.TextYAlignment.Top
warn.ZIndex = 2
warn.Parent = warnBlock
local warnStroke = Instance.new("UIStroke")
warnStroke.Color = Color3.new(0, 0, 0)
warnStroke.Thickness = 2.5
warnStroke.Parent = warn

-- Action buttons: confirm LEFT, cancel RIGHT, identical sizes.
local function buildActionButton(name, anchorX, posX, baseColor, faceTop, faceBottom, labelText)
	local base = Instance.new("TextButton")
	base.Name = name
	base.Text = ""
	base.AutoButtonColor = false
	base.AnchorPoint = Vector2.new(anchorX, 0.5)
	base.Position = UDim2.new(posX, 0, 0.82, 0)
	base.Size = UDim2.new(0.28, 0, 0.13, 0)
	base.BackgroundColor3 = baseColor
	base.BorderSizePixel = 0
	base.ZIndex = 2
	base.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = base

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0, 1)
	face.Position = UDim2.fromScale(0, 1)
	face.Size = UDim2.new(1, 0, 0.90, 0)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = base.ZIndex + 1
	face.Parent = base
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, faceTop),
		ColorSequenceKeypoint.new(0.1, faceTop),
		ColorSequenceKeypoint.new(1, faceBottom),
	})
	grad.Parent = face
	local pattern = Instance.new("ImageLabel")
	pattern.Name = "Studs"
	pattern.Size = UDim2.new(1, 0, 1, 0)
	pattern.BackgroundTransparency = 1
	pattern.Image = STUDS_ID
	pattern.ImageTransparency = 0.55
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromOffset(69, 69)
	pattern.ZIndex = face.ZIndex
	pattern.Parent = face

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, 0, 0.62, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = labelText
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.ZIndex = face.ZIndex + 1
	label.Parent = face
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = Color3.new(0, 0, 0)
	labelStroke.Thickness = 3
	labelStroke.Parent = label

	addPressFeedback(base)
	return base
end

local confirmBtn = buildActionButton(
	"ConfirmButton", 1, 0.485,
	Color3.fromRGB(16, 92, 36),
	Color3.fromRGB(190, 240, 200), Color3.fromRGB(34, 170, 70),
	"EAT IT"
)
local cancelBtn = buildActionButton(
	"CancelButton", 0, 0.515,
	Color3.fromRGB(92, 16, 16),
	Color3.fromRGB(255, 130, 130), Color3.fromRGB(239, 28, 28),
	"CANCEL"
)

local pendingRokakaka = nil

local function closeConfirm()
	panel.Visible = false
	pendingRokakaka = nil
end

confirmBtn.Activated:Connect(function()
	local tool = pendingRokakaka
	closeConfirm()
	if tool and tool.Parent then
		standAction:FireServer("UseRokakaka")
	end
end)
cancelBtn.Activated:Connect(closeConfirm)
closeBtn.Activated:Connect(closeConfirm)
localPlayer.CharacterRemoving:Connect(closeConfirm)

-- Watch the player's inventory for the item tools and wire activation.
local watchedTools = setmetatable({}, { __mode = "k" })
local function watchTool(tool)
	if not tool:IsA("Tool") then return end
	-- un outil passe du sac à la main : ne le brancher qu'une fois
	if watchedTools[tool] then return end
	watchedTools[tool] = true
	if tool.Name == "StandArrow" then
		tool.Activated:Connect(function()
			if not localPlayer:GetAttribute("Standless") then
				showDeniedToast("Arrow")
				return
			end
			standAction:FireServer("UseArrow")
		end)
	elseif tool.Name == "RequiemArrow" then
		tool.Activated:Connect(function()
			if localPlayer:GetAttribute("StandId") ~= "GoldExperience" then
				showDeniedToast("RequiemArrow")
				return
			end
			standAction:FireServer("UseRequiemArrow")
		end)
	elseif tool.Name == "Rokakaka" then
		tool.Activated:Connect(function()
			if localPlayer:GetAttribute("Standless") then return end
			pendingRokakaka = tool
			panel.Visible = true
		end)
	end
end

local backpack = localPlayer:WaitForChild("Backpack")
backpack.ChildAdded:Connect(watchTool)
for _, tool in backpack:GetChildren() do
	watchTool(tool)
end
local function watchCharacter(character)
	character.ChildAdded:Connect(watchTool)
	for _, tool in character:GetChildren() do
		watchTool(tool)
	end
end
if localPlayer.Character then
	watchCharacter(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(watchCharacter)

print("[StandItemClient] Ready - Stand Arrow activates instantly, Rokakaka asks first")

-- ==================== SPRINT (SHIFT) + SHIFTLOCK (CTRL) ====================
-- Sprint: hold LeftShift for extra speed. It never overrides speeds the
-- server owns (barrage self-slow, time-stop freeze), because it only ever
-- converts BASE_SPEED <-> SPRINT_SPEED and leaves any other value alone.
-- Shiftlock: LeftControl toggles a right-shoulder locked camera (the default
-- Roblox Shift-lock is disabled in StarterPlayer so Shift stays free).

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local BASE_SPEED = 16
local SPRINT_SPEED = 24
local SHIFTLOCK_OFFSET = Vector3.new(1.75, 0, 0)

local shiftLocked = false

local function getHumanoid()
	local char = localPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function standControlsSpeed()
	local stand = workspace:FindFirstChild(localPlayer.Name .. "Stand")
	return not stand or stand:GetAttribute("State") == "Idle"
end

local function setShiftLock(on)
	shiftLocked = on
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.CameraOffset = on and SHIFTLOCK_OFFSET or Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local humanoid = getHumanoid()
		if humanoid and humanoid.WalkSpeed == BASE_SPEED and standControlsSpeed() then
			humanoid.WalkSpeed = SPRINT_SPEED
		end
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		setShiftLock(not shiftLocked)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local humanoid = getHumanoid()
		if humanoid and humanoid.WalkSpeed == SPRINT_SPEED then
			humanoid.WalkSpeed = BASE_SPEED
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if not shiftLocked then return end
	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and humanoid.Health > 0) then return end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end)

localPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = BASE_SPEED
	if shiftLocked then
		humanoid.CameraOffset = SHIFTLOCK_OFFSET
	end
end)
