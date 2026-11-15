-- HUD. En haut à gauche : l'argent du joueur (avec l'animation "+30" quand
-- on ramasse de l'argent au sol) et le menu qui ouvre les fenêtres :
-- INVENTAIRE (J), BOUTIQUE (N), SKINS (K) et STANDS (admins, L).
-- Les fenêtres elles-mêmes sont dans InventoryMenu, ShopMenu, SkinMenu et
-- StandMenu ; le style est dans ReplicatedStorage/UITheme.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local C = UITheme.Colors
local moneyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MoneyEvent")

local player = Players.LocalPlayer
local gui, root = UITheme.Screen("GameHUD", 6)

-- Barre en haut au centre : en haut à gauche, la fenêtre du chat de Roblox
-- passait par-dessus et prenait les clics.
local BUTTON_W = 134

local rail = Instance.new("Frame")
rail.Name = "Rail"
rail.BackgroundTransparency = 1
rail.AnchorPoint = Vector2.new(0.5, 0)
rail.Position = UDim2.new(0.5, 0, 0, 8)
rail.Size = UDim2.fromOffset(0, 42)
rail.AutomaticSize = Enum.AutomaticSize.X
rail.Parent = root
local railLayout = Instance.new("UIListLayout")
railLayout.FillDirection = Enum.FillDirection.Horizontal
railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
railLayout.Padding = UDim.new(0, 6)
railLayout.SortOrder = Enum.SortOrder.LayoutOrder
railLayout.Parent = rail

-- Argent -----------------------------------------------------------------------
local cashPill = Instance.new("Frame")
cashPill.Name = "Cash"
cashPill.LayoutOrder = 0
cashPill.Size = UDim2.fromOffset(160, 40)
cashPill.BackgroundColor3 = C.Night
cashPill.BackgroundTransparency = 0.1
cashPill.Parent = rail
UITheme.Corner(cashPill, 20)
local cashStroke = UITheme.Stroke(cashPill, C.Money, 1.35, 0.23)
UITheme.Surface(cashPill)

local cashIcon = UITheme.Label(cashPill, "$", 22, C.Night, UITheme.Bold)
cashIcon.Position = UDim2.fromOffset(5, 5)
cashIcon.Size = UDim2.fromOffset(30, 30)
cashIcon.TextXAlignment = Enum.TextXAlignment.Center
cashIcon.BackgroundColor3 = C.Money
cashIcon.BackgroundTransparency = 0
UITheme.Corner(cashIcon, 15)

local cashLabel = UITheme.Label(cashPill, "0 $", 18, C.Text, UITheme.Bold)
cashLabel.Position = UDim2.fromOffset(42, 0)
cashLabel.Size = UDim2.new(1, -50, 1, 0)

local function cashValue()
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local shown = 0
local countTween
local function refreshCash(animate)
	local cash = cashValue()
	local target = cash and cash.Value or 0
	if countTween then countTween:Cancel() end
	if animate and target ~= shown then
		local value = Instance.new("NumberValue")
		value.Value = shown
		value.Changed:Connect(function(v)
			cashLabel.Text = UITheme.Money(v)
		end)
		countTween = TweenService:Create(value, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = target })
		countTween.Completed:Connect(function()
			value:Destroy()
			cashLabel.Text = UITheme.Money(target)
		end)
		countTween:Play()
	else
		cashLabel.Text = UITheme.Money(target)
	end
	shown = target
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local cash = stats:WaitForChild("Cash")
	cash.Changed:Connect(function()
		refreshCash(true)
	end)
	refreshCash(false)
end)

-- "+30" qui jaillit de la pastille d'argent
local function popGain(amount)
	local pop = UITheme.Label(cashPill, "+" .. tostring(amount), 28, C.Money, UITheme.Title)
	pop.AnchorPoint = Vector2.new(0.5, 0)
	pop.Position = UDim2.new(0.5, 0, 1, 2)
	pop.Size = UDim2.fromOffset(90, 30)
	pop.TextXAlignment = Enum.TextXAlignment.Center
	pop.ZIndex = 10
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = pop
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, 26),
	}):Play()
	task.delay(0.55, function()
		TweenService:Create(pop, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
		local stroke = pop:FindFirstChildOfClass("UIStroke")
		if stroke then TweenService:Create(stroke, TweenInfo.new(0.55), { Transparency = 1 }):Play() end
	end)
	task.delay(1.2, function() pop:Destroy() end)
	-- la pastille clignote en vert
	cashStroke.Thickness = 4
	TweenService:Create(cashStroke, TweenInfo.new(0.5), { Thickness = 2 }):Play()
	cashPill.BackgroundColor3 = C.Money:Lerp(C.Night, 0.6)
	TweenService:Create(cashPill, TweenInfo.new(0.5), { BackgroundColor3 = C.Night }):Play()
end

moneyEvent.OnClientEvent:Connect(function(action, amount)
	if action == "Gained" then
		popGain(amount)
	end
end)

-- Boutons du menu ----------------------------------------------------------------
local menuButtons = {} -- [window] = { button, stroke }

local function menuButton(order, window, icon, text, key, accent)
	local button = Instance.new("TextButton")
	button.Name = window
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(BUTTON_W, 42)
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = C.Panel
	button.BackgroundTransparency = 0.1
	button.Parent = rail
	UITheme.Corner(button, 10)
	local stroke = UITheme.Stroke(button, accent, 1.35, 0.23)
	UITheme.Gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 175), 95)
	UITheme.Accent(button, accent)

	local badge = UITheme.Label(button, icon, 18, C.Text, UITheme.Body)
	badge.Position = UDim2.fromOffset(6, 6)
	badge.Size = UDim2.fromOffset(30, 30)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.BackgroundColor3 = accent
	badge.BackgroundTransparency = 0.7
	UITheme.Corner(badge, 8)

	local label = UITheme.Label(button, text, 13, C.Text, UITheme.Bold)
	label.Position = UDim2.fromOffset(42, 0)
	label.Size = UDim2.new(1, -46, 1, 0)

	local keyLabel = UITheme.Label(button, key, 12, C.Muted, UITheme.Bold)
	keyLabel.AnchorPoint = Vector2.new(1, 0.5)
	keyLabel.Position = UDim2.new(1, -8, 0.5, 0)
	keyLabel.Size = UDim2.fromOffset(22, 22)
	keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	keyLabel.BackgroundColor3 = C.Night
	keyLabel.BackgroundTransparency = 0.3
	UITheme.Corner(keyLabel, 6)
	-- la touche s'affiche en petit sous l'icône (place réduite dans la barre)
	keyLabel.AnchorPoint = Vector2.new(0, 1)
	keyLabel.Position = UDim2.fromOffset(26, 40)
	keyLabel.Size = UDim2.fromOffset(14, 14)
	keyLabel.TextSize = 9
	keyLabel.ZIndex = 3
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		keyLabel.Visible = false
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.13), { BackgroundColor3 = C.CardHover }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.13, Enum.EasingStyle.Quad), { Color = C.Text, Transparency = 0.07 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.17), { BackgroundColor3 = C.Panel }):Play()
		local open = UITheme.IsOpen(window)
		TweenService:Create(stroke, TweenInfo.new(0.17, Enum.EasingStyle.Quad), { Color = accent, Transparency = open and 0 or 0.23 }):Play()
	end)
	button.Activated:Connect(function()
		if not UITheme.Toggle(window) then
			warn("[HUD] Fenêtre pas chargée :", window)
			UITheme.Toast("Chargement de " .. text .. "…", C.Muted)
		end
	end)
	menuButtons[window] = { button = button, stroke = stroke, accent = accent }
	return button
end

menuButton(1, "Inventaire", "🎒", "INVENTAIRE", "J", C.Blue)
menuButton(2, "Boutique", "🛒", "BOUTIQUE", "N", C.Gold)
menuButton(3, "Skins", "🎨", "SKINS", "K", C.Pink)
local standsButton = menuButton(4, "Stands", "⭐", "STANDS", "L", C.Purple)

-- bouton allumé quand sa fenêtre est ouverte
UITheme.WindowChanged:Connect(function(name, open)
	local entry = menuButtons[name]
	if entry then
		entry.stroke.Color = entry.accent
		entry.stroke.Transparency = open and 0 or 0.23
		entry.stroke.Thickness = open and 2 or 1.35
	end
end)

-- STANDS : admins seulement
local function refreshAdmin()
	local admin = player:GetAttribute("StandAdmin") == true
	standsButton.Visible = admin
	if not admin then UITheme.Close("Stands") end
end
player:GetAttributeChangedSignal("StandAdmin"):Connect(refreshAdmin)
refreshAdmin()

-- Raccourcis clavier
local SHORTCUTS = {
	[Enum.KeyCode.J] = "Inventaire",
	[Enum.KeyCode.N] = "Boutique",
	[Enum.KeyCode.K] = "Skins",
	[Enum.KeyCode.L] = "Stands",
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local window = SHORTCUTS[input.KeyCode]
	if window == "Stands" and player:GetAttribute("StandAdmin") ~= true then return end
	if window then
		UITheme.Toggle(window)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		for name in pairs(menuButtons) do
			UITheme.Close(name)
		end
	end
end)
