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

-- layout: hud-zone-system
-- Stand Stat HUD: A-Bizarre-Day-style stat board (dark checkered plate, red
-- zigzag dividers) showing the current Stand name and its Power /
-- Durability / Speed grades. Toggled with the M key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local StandData = require(ReplicatedStorage:WaitForChild("StandData"))
local localPlayer = Players.LocalPlayer

local CHECKER_A = Color3.fromRGB(56, 56, 62)
local CHECKER_B = Color3.fromRGB(44, 44, 50)
local BAND_NAME = Color3.fromRGB(112, 112, 120)
local BAND_STAT = Color3.fromRGB(66, 66, 72)
local RED = Color3.fromRGB(198, 42, 42)
local RED_DARK = Color3.fromRGB(126, 20, 20)
local WHITE = Color3.new(1, 1, 1)

local PANEL_W = 324
local INSET = 12
local ROW_W = PANEL_W - INSET * 2
local NAME_H = 78
local STAT_H = 64
local DIV_H = 18
local MONEY_H = 64
local ROWS_H = NAME_H + 3 * (STAT_H + DIV_H) + DIV_H + MONEY_H
local PANEL_H = ROWS_H + INSET * 2

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StandStatHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Bottom-left zone (toasts own top-center, CombatFX owns top-right).
local zone = Instance.new("Frame")
zone.Name = "BottomLeftZone"
zone.BackgroundTransparency = 1
zone.AnchorPoint = Vector2.new(0, 1)
zone.Position = UDim2.new(0.025, 0, 0.97, 0)
zone.Size = UDim2.fromOffset(PANEL_W, PANEL_H + 30)
zone.Parent = screenGui

-- Bare hint label above the board.
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(0, 0)
hint.Position = UDim2.fromOffset(0, 0)
hint.Size = UDim2.fromOffset(PANEL_W, 22)
hint.Font = Enum.Font.FredokaOne
hint.Text = "Press M to toggle"
hint.TextColor3 = WHITE
hint.TextScaled = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.ZIndex = 1
hint.Parent = zone
local hintStroke = Instance.new("UIStroke")
hintStroke.Color = Color3.new(0, 0, 0)
hintStroke.Thickness = 2.5
hintStroke.Parent = hint

-- Board: dark checkered backing plate.
local board = Instance.new("Frame")
board.Name = "Board"
board.BackgroundColor3 = CHECKER_B
board.BorderSizePixel = 0
board.Position = UDim2.fromOffset(0, 30)
board.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
board.ZIndex = 1
board.Parent = zone
local boardStroke = Instance.new("UIStroke")
boardStroke.Color = Color3.new(0, 0, 0)
boardStroke.Thickness = 4
boardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
boardStroke.Parent = board

-- Two-tone checkerboard laid over the backing plate.
do
	local CELL = 26
	local cols = math.ceil(PANEL_W / CELL)
	local rows = math.ceil(PANEL_H / CELL)
	for gy = 0, rows - 1 do
		for gx = 0, cols - 1 do
			local cell = Instance.new("Frame")
			cell.Name = "Checker"
			cell.BackgroundColor3 = ((gx + gy) % 2 == 0) and CHECKER_A or CHECKER_B
			cell.BorderSizePixel = 0
			cell.Position = UDim2.fromOffset(gx * CELL, gy * CELL)
			cell.Size = UDim2.fromOffset(CELL, CELL)
			cell.ZIndex = 1
			cell.Parent = board
		end
	end
end

-- Bands stack inside the plate with a small margin.
local stack = Instance.new("Frame")
stack.Name = "Rows"
stack.BackgroundTransparency = 1
stack.Position = UDim2.fromOffset(INSET, INSET)
stack.Size = UDim2.fromOffset(ROW_W, ROWS_H)
stack.ZIndex = 2
stack.Parent = board

local stackLayout = Instance.new("UIListLayout")
stackLayout.FillDirection = Enum.FillDirection.Vertical
stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
stackLayout.Padding = UDim.new(0, 0)
stackLayout.Parent = stack

local function textLabel(parent)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -8, 1, -12)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = WHITE
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = 3
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 3.5
	stroke.Parent = label
	return label
end

local function buildBand(order, height, color)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.Size = UDim2.fromOffset(ROW_W, height)
	band.LayoutOrder = order
	band.ZIndex = 2
	band.Parent = stack
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = band
	return band
end

-- Red zigzag ribbon: a chevron wave of alternating red diamonds.
local function buildDivider(order)
	local strip = Instance.new("Frame")
	strip.Name = "Zigzag"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(ROW_W, DIV_H)
	strip.LayoutOrder = order
	strip.ZIndex = 2
	strip.Parent = stack
	local count = math.floor(ROW_W / 20)
	local step = ROW_W / count
	for i = 0, count - 1 do
		local tooth = Instance.new("Frame")
		tooth.Name = "Tooth"
		tooth.BackgroundColor3 = (i % 2 == 0) and RED or RED_DARK
		tooth.BorderSizePixel = 0
		tooth.Rotation = 45
		tooth.Size = UDim2.fromOffset(13, 13)
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromOffset(step * i + step / 2, (i % 2 == 0) and 5 or 13)
		tooth.ZIndex = 2
		tooth.Parent = strip
	end
	return strip
end

local nameBand = buildBand(1, NAME_H, BAND_NAME)
local nameLabel = textLabel(nameBand)
nameLabel.Text = "..."

buildDivider(2)

local function statBand(order, title)
	local band = buildBand(order, STAT_H, BAND_STAT)
	local label = textLabel(band)
	label.Text = title .. "  -"
	return label
end

local powerLabel = statBand(3, "POWER")
buildDivider(4)
local durabilityLabel = statBand(5, "DURABILITY")
buildDivider(6)
local speedLabel = statBand(7, "SPEED")

-- Money box: always-on cash readout in the same band style.
buildDivider(8)
local moneyBand = buildBand(9, MONEY_H, BAND_STAT)
local moneyLabel = textLabel(moneyBand)
moneyLabel.Text = "$0"

local function refreshMoney()
	local leaderstats = localPlayer:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	moneyLabel.Text = "$" .. tostring(cash and cash.Value or 0)
end

local moneyStats = localPlayer:WaitForChild("leaderstats")
local cashStat = moneyStats:WaitForChild("Cash")
cashStat.Changed:Connect(refreshMoney)
refreshMoney()

local function refresh()
	local standless = localPlayer:GetAttribute("Standless")
	local standId = localPlayer:GetAttribute("StandId")
	-- No StandId and not standless means the server's default stand.
	local key = standless and nil or (standId or StandData.DefaultStand)
	local def = key and StandData.GetStand(key) or nil
	nameLabel.Text = (def and def.DisplayName) or "NO STAND"
	local grades = key and StandData.StatGrades[key] or nil
	powerLabel.Text = "POWER  " .. (grades and grades.Power or "-")
	durabilityLabel.Text = "DURABILITY  " .. (grades and grades.Durability or "-")
	speedLabel.Text = "SPEED  " .. (grades and grades.Speed or "-")
end

localPlayer:GetAttributeChangedSignal("Standless"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("StandId"):Connect(refresh)
refresh()

-- Caché au départ : il faut appuyer sur M pour l'afficher.
screenGui.Enabled = false

-- M toggles the HUD.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.M then
		screenGui.Enabled = not screenGui.Enabled
	end
end)

print("[StandStatHUD] Ready - M toggles the stand stat board")
