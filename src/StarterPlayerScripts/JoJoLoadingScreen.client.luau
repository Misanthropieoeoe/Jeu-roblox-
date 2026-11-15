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

-- layout: fullscreen-landing (loading variant)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "JoJoLoadingScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Backdrop: full-screen black at 0.18 — blocks the world, does not tint it.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.18
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.ZIndex = 1
backdrop.Parent = screenGui

-- Zone A: sunburst menace underlay, kept inside the title zone.
local sunburst = Instance.new("ImageLabel")
sunburst.Name = "Sunburst"
sunburst.BackgroundTransparency = 1
sunburst.AnchorPoint = Vector2.new(0.5, 0.5)
sunburst.Position = UDim2.fromScale(0.5, 0.20)
sunburst.Size = UDim2.fromOffset(620, 620)
sunburst.Image = "rbxassetid://91084849147872"
sunburst.ImageTransparency = 0.75
sunburst.ScaleType = Enum.ScaleType.Crop
local sunAspect = Instance.new("UIAspectRatioConstraint")
sunAspect.AspectRatio = 1
sunAspect.Parent = sunburst
sunburst.ZIndex = 2
sunburst.Parent = backdrop

-- Zone A: bare title lockup, white->gold gradient, no plate behind it.
local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.19)
title.Size = UDim2.fromScale(0.70, 0.16)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.RichText = true
title.Text = '<font size="132">A BIZARRE DAY</font>'
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.ZIndex = 3
title.Parent = backdrop
local titleGrad = Instance.new("UIGradient")
titleGrad.Rotation = 90
titleGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 210, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 20)),
})
titleGrad.Parent = title
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.new(0, 0, 0)
titleStroke.Thickness = 3
titleStroke.Parent = title

-- Zone A: one-line tagline directly under the title.
local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.AnchorPoint = Vector2.new(0.5, 0.5)
tagline.Position = UDim2.fromScale(0.5, 0.285)
tagline.Size = UDim2.fromScale(0.35, 0.04)
tagline.BackgroundTransparency = 1
tagline.Font = Enum.Font.FredokaOne
tagline.Text = "YARE YARE DAZE... YOUR STAND AWAITS"
tagline.TextColor3 = Color3.new(1, 1, 1)
tagline.TextScaled = true
tagline.ZIndex = 3
tagline.Parent = backdrop
local taglineStroke = Instance.new("UIStroke")
taglineStroke.Color = Color3.new(0, 0, 0)
taglineStroke.Thickness = 2.5
taglineStroke.Parent = tagline

-- Zone B: loading progress bar (dark track + thickness-4 outline).
local barTrack = Instance.new("Frame")
barTrack.Name = "ProgressTrack"
barTrack.AnchorPoint = Vector2.new(0.5, 0)
barTrack.Position = UDim2.fromScale(0.5, 0.64)
barTrack.Size = UDim2.fromScale(0.50, 0.05)
barTrack.BackgroundColor3 = Color3.fromRGB(22, 30, 26)
barTrack.BorderSizePixel = 0
barTrack.ZIndex = 3
barTrack.Parent = backdrop
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.new(0, 0, 0)
barStroke.Thickness = 4
barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
barStroke.Parent = barTrack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.AnchorPoint = Vector2.new(0, 0)
barFill.Position = UDim2.fromScale(0, 0)
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(34, 170, 70)
barFill.BorderSizePixel = 0
barFill.ZIndex = 4
barFill.Parent = barTrack
local fillGrad = Instance.new("UIGradient")
fillGrad.Rotation = 90
fillGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 240, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 170, 70)),
})
fillGrad.Parent = barFill

local barLabel = Instance.new("TextLabel")
barLabel.Name = "Value"
barLabel.AnchorPoint = Vector2.new(0.5, 0.5)
barLabel.Position = UDim2.fromScale(0.5, 0.5)
barLabel.Size = UDim2.fromScale(0.9, 0.8)
barLabel.BackgroundTransparency = 1
barLabel.Font = Enum.Font.FredokaOne
barLabel.Text = "SUMMONING STANDS..."
barLabel.TextColor3 = Color3.new(1, 1, 1)
barLabel.TextScaled = true
barLabel.ZIndex = 5
barLabel.Parent = barTrack
local barLabelGrad = Instance.new("UIGradient")
barLabelGrad.Rotation = 90
barLabelGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 210, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 20)),
})
barLabelGrad.Parent = barLabel
local barLabelStroke = Instance.new("UIStroke")
barLabelStroke.Color = Color3.new(0, 0, 0)
barLabelStroke.Thickness = 2
barLabelStroke.Parent = barLabel

-- Zone B: bare status line under the bar.
local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.715)
status.Size = UDim2.fromScale(0.5, 0.035)
status.BackgroundTransparency = 1
status.Font = Enum.Font.FredokaOne
status.Text = "MENACING... WAKING DIO'S COFFIN"
status.TextColor3 = Color3.new(1, 1, 1)
status.TextScaled = true
status.ZIndex = 3
status.Parent = backdrop
local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.new(0, 0, 0)
statusStroke.Thickness = 2.5
statusStroke.Parent = status

-- Zone C: bare footer line.
local footer = Instance.new("TextLabel")
footer.Name = "Footer"
footer.AnchorPoint = Vector2.new(0.5, 0.5)
footer.Position = UDim2.fromScale(0.5, 0.95)
footer.Size = UDim2.fromScale(0.4, 0.03)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.FredokaOne
footer.Text = "A BIZARRE DAY — STAND BATTLE"
footer.TextColor3 = Color3.new(1, 1, 1)
footer.TextScaled = true
footer.ZIndex = 3
footer.Parent = backdrop
local footerStroke = Instance.new("UIStroke")
footerStroke.Color = Color3.new(0, 0, 0)
footerStroke.Thickness = 2
footerStroke.Parent = footer

-- Loading flow: the bar crawls through hardcoded JoJo status lines while the
-- map loads, then fills to 100% and the screen dismisses once the character
-- has actually spawned.
local STATUSES = {
	"MENACING... WAKING DIO'S COFFIN",
	"MENACING... PAVING MAIN STREET",
	"MENACING... CHARGING THE TIME STOP",
	"MENACING... YOUR STAND APPROACHES",
}
local MIN_DISPLAY_TIME = 3
local startClock = os.clock()

local function isReady()
	local char = localPlayer.Character
	if not char then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

task.spawn(function()
	local progress = 0
	local statusIndex = 1
	local lastStatusChange = os.clock()
	while progress < 1 do
		local target = isReady() and (os.clock() - startClock >= MIN_DISPLAY_TIME and 1 or 0.9) or 0.75
		progress = math.min(1, progress + (progress < target and 0.02 or 0))
		barFill.Size = UDim2.new(progress, 0, 1, 0)
		if os.clock() - lastStatusChange >= 0.9 and progress < 1 then
			statusIndex = statusIndex % #STATUSES + 1
			status.Text = STATUSES[statusIndex]
			lastStatusChange = os.clock()
		end
		task.wait(0.1)
	end
	status.Text = "MENACING... THE WORLD IS YOURS"
	task.wait(0.4)
	screenGui.Enabled = false
	print("[JoJoLoadingScreen] Loading screen dismissed")
end)

print("[JoJoLoadingScreen] Ready")
