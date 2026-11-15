-- UITheme. Le style commun de toutes les interfaces du jeu (barre de sorts,
-- tableau des scores, inventaire, boutique, skins, menu des Stands) et les
-- petites fonctions pour les construire. Côté client uniquement.
--
-- Fenêtres : UITheme.Window(...) crée une fenêtre centrée. Une seule fenêtre
-- est ouverte à la fois : UITheme.Toggle("Boutique") ferme les autres.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UITheme = {}

-- Couleurs ---------------------------------------------------------------------
-- Palette "A New Bizarre Day" : fonds nuit violette, contours violets,
-- accents or / rose / bleu / vert.
UITheme.Colors = {
	Night = Color3.fromRGB(16, 15, 31),      -- base : fond le plus sombre
	Panel = Color3.fromRGB(23, 20, 42),      -- fond des panneaux
	Card = Color3.fromRGB(31, 25, 54),       -- base2 : cartes, cases
	CardHover = Color3.fromRGB(44, 36, 74),
	Line = Color3.fromRGB(117, 91, 167),     -- contours
	Text = Color3.fromRGB(247, 245, 255),
	Muted = Color3.fromRGB(180, 169, 207),
	Gold = Color3.fromRGB(252, 195, 96),
	GoldDark = Color3.fromRGB(150, 104, 30),
	Purple = Color3.fromRGB(167, 111, 249),
	Magenta = Color3.fromRGB(241, 100, 189), -- rose
	Pink = Color3.fromRGB(241, 100, 189),
	Blue = Color3.fromRGB(109, 172, 255),
	Green = Color3.fromRGB(107, 245, 182),
	Red = Color3.fromRGB(240, 74, 84),
	Legend = Color3.fromRGB(255, 170, 40),
	Money = Color3.fromRGB(107, 245, 182),
}
local C = UITheme.Colors

-- Polices
UITheme.Title = Enum.Font.GothamBlack    -- titres
UITheme.Bold = Enum.Font.GothamBold
UITheme.Body = Enum.Font.GothamMedium

-- Petits outils ------------------------------------------------------------------
function UITheme.Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

function UITheme.Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or C.Line
	s.Thickness = thickness or 1.35
	s.Transparency = transparency or 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Dégradé (réutilise celui déjà posé sur l'objet : un seul compte)
function UITheme.Gradient(parent, top, bottom, rotation)
	local g = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function UITheme.Padding(parent, all)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, all)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = u, u, u, u
	p.Parent = parent
	return p
end

-- Texte. font = UITheme.Title / Bold / Body
function UITheme.Label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or UITheme.Body
	l.Text = text or ""
	l.TextSize = size or 16
	l.TextColor3 = color or C.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

-- Petite barre d'accent colorée sur le bord gauche d'une carte
function UITheme.Accent(parent, color)
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = color or C.Purple
	bar.BorderSizePixel = 0
	bar.Active = false
	bar.Position = UDim2.new(0, 2, 0.225, 0)
	bar.Size = UDim2.new(0, 3, 0.55, 0)
	bar.ZIndex = (parent.ZIndex or 1) + 1
	bar.Parent = parent
	UITheme.Corner(bar, 3)
	return bar
end

-- Fond sombre en dégradé (base2 -> base) commun aux panneaux et cartes
function UITheme.Surface(parent)
	parent.BackgroundColor3 = Color3.new(1, 1, 1)
	parent.BorderSizePixel = 0
	return UITheme.Gradient(parent, C.Card, C.Night, 95)
end

-- Bouton. style = "primary" (doré), "danger" (rouge) ou "ghost" (discret)
function UITheme.Button(parent, text, style, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Font = UITheme.Bold
	b.Text = text or ""
	b.TextSize = size or 15
	b.Size = UDim2.fromOffset(120, 36)
	b.Parent = parent
	UITheme.Corner(b, 8)
	local base, textColor
	if style == "primary" then
		base, textColor = C.Gold, C.Night
	elseif style == "danger" then
		base, textColor = C.Red, C.Text
	else
		base, textColor = C.Card, C.Text
		UITheme.Stroke(b, C.Line, 1.35, 0.23)
	end
	b.BackgroundColor3 = base
	b.TextColor3 = textColor
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.15)
	b.MouseEnter:Connect(function()
		if b.Active then
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.95 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return b
end

-- Désactive un bouton (grisé)
function UITheme.SetEnabled(button, enabled)
	button.Active = enabled
	button.AutoButtonColor = false
	button.TextTransparency = enabled and 0 or 0.5
	button.BackgroundTransparency = enabled and 0 or 0.45
end

-- Carte cliquable : fond en dégradé, contour violet, barre d'accent.
-- Au survol le contour s'éclaircit (sa couleur reste gérée par l'appelant).
function UITheme.Card(parent, accent)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = C.Card
	b.Parent = parent
	UITheme.Corner(b, 10)
	UITheme.Gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 175), 95)
	local stroke = UITheme.Stroke(b, C.Line, 1.35, 0.23)
	UITheme.Accent(b, accent or C.Purple)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.13), { BackgroundColor3 = C.CardHover }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.13), { Transparency = 0.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.17), { BackgroundColor3 = C.Card }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.17), { Transparency = 0.23 }):Play()
	end)
	return b, stroke
end

-- Montant d'argent lisible : 12 500 $
function UITheme.Money(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", "")) .. " $"
end

-- Écran ------------------------------------------------------------------------
-- ScreenGui avec son UIScale : tout est dessiné pour un écran de 720 px de
-- haut, et suit la taille réelle (plus petit sur mobile).
function UITheme.Screen(name, displayOrder)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = displayOrder or 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local s = math.clamp(math.min(size.Y / 720, size.X / 1100), 0.62, 1.35)
		scale.Scale = s
		-- le Root garde la taille de l'écran une fois l'échelle appliquée
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	gui.Parent = playerGui
	return gui, root
end

-- Fenêtres -----------------------------------------------------------------------
local windows = {} -- [name] = { setOpen = fn, isOpen = fn }
local changed = Instance.new("BindableEvent")
UITheme.WindowChanged = changed.Event -- (name, open)

function UITheme.Register(name, setOpen, isOpen)
	windows[name] = { setOpen = setOpen, isOpen = isOpen }
end

function UITheme.Open(name)
	for other, w in pairs(windows) do
		if other ~= name and w.isOpen() then
			w.setOpen(false)
			changed:Fire(other, false)
		end
	end
	local w = windows[name]
	if w then
		w.setOpen(true)
		changed:Fire(name, true)
	end
end

function UITheme.Close(name)
	local w = windows[name]
	if w and w.isOpen() then
		w.setOpen(false)
		changed:Fire(name, false)
	end
end

-- Renvoie false si la fenêtre n'existe pas (script pas encore chargé)
function UITheme.Toggle(name)
	local w = windows[name]
	if not w then return false end
	if w.isOpen() then
		UITheme.Close(name)
	else
		UITheme.Open(name)
	end
	return true
end

function UITheme.IsOpen(name)
	local w = windows[name]
	return w ~= nil and w.isOpen()
end

-- Fenêtre centrée : renvoie { frame, body, title, subtitle, status }.
-- body est la zone de contenu (sous le titre).
function UITheme.Window(root, name, titleText, subtitleText, accent, maxSize)
	accent = accent or C.Gold
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.new(0.9, 0, 0.82, 0)
	frame.BackgroundTransparency = 0.04
	frame.Visible = false
	frame.Parent = root
	UITheme.Corner(frame, 13)
	UITheme.Stroke(frame, accent, 1.6, 0.18)
	UITheme.Surface(frame)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize or Vector2.new(760, 500)
	limit.Parent = frame

	-- bandeau de titre : sombre, barre d'accent à gauche, filet coloré dessous
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 58)
	header.Parent = frame
	local accentBar = Instance.new("Frame")
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Position = UDim2.fromOffset(14, 13)
	accentBar.Size = UDim2.fromOffset(4, 32)
	accentBar.Parent = header
	UITheme.Corner(accentBar, 2)
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = accent
	rule.BackgroundTransparency = 0.55
	rule.BorderSizePixel = 0
	rule.Position = UDim2.new(0, 14, 1, -1)
	rule.Size = UDim2.new(1, -28, 0, 1)
	rule.Parent = header

	local title = UITheme.Label(header, titleText, 24, C.Text, UITheme.Title)
	title.Position = UDim2.fromOffset(28, 8)
	title.Size = UDim2.new(1, -90, 0, 28)
	local subtitle = UITheme.Label(header, subtitleText or "", 12, C.Muted, UITheme.Body)
	subtitle.Position = UDim2.fromOffset(29, 35)
	subtitle.Size = UDim2.new(1, -90, 0, 15)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -14, 0.5, 0)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = C.Card
	close.Font = UITheme.Bold
	close.Text = "✕"
	close.TextSize = 18
	close.TextColor3 = C.Text
	close.Parent = header
	UITheme.Corner(close, 17)
	local closeStroke = UITheme.Stroke(close, C.Line, 1.35, 0.23)
	close.MouseEnter:Connect(function()
		TweenService:Create(closeStroke, TweenInfo.new(0.13), { Color = C.Text, Transparency = 0.05 }):Play()
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(closeStroke, TweenInfo.new(0.17), { Color = C.Line, Transparency = 0.23 }):Play()
	end)
	close.Activated:Connect(function()
		UITheme.Close(name)
	end)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(14, 70)
	body.Size = UDim2.new(1, -28, 1, -106)
	body.Parent = frame

	local status = UITheme.Label(frame, "", 14, C.Muted, UITheme.Body)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 18, 1, -10)
	status.Size = UDim2.new(1, -36, 0, 20)

	-- petite animation d'ouverture
	local pop = Instance.new("UIScale")
	pop.Parent = frame
	local open = false
	UITheme.Register(name, function(state)
		open = state
		if state then
			frame.Visible = true
			pop.Scale = 0.92
			TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			frame.Visible = false
		end
	end, function()
		return open
	end)

	return { frame = frame, body = body, title = title, subtitle = subtitle, status = status }
end

-- Liste défilante (verticale) avec grille ou liste
function UITheme.Scroll(parent, accent)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = accent or C.Gold
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Size = UDim2.fromScale(1, 1)
	s.Parent = parent
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 3)
	p.PaddingBottom = UDim.new(0, 3)
	p.PaddingLeft = UDim.new(0, 3)
	p.PaddingRight = UDim.new(0, 9)
	p.Parent = s
	return s
end

-- Petit message éphémère en bas de l'écran
local toastGui, toastLabel, toastToken
function UITheme.Toast(text, color)
	if not toastGui or not toastGui.Parent then
		local root
		toastGui, root = UITheme.Screen("UIToast", 20)
		toastLabel = UITheme.Label(root, "", 16, C.Text, UITheme.Bold)
		toastLabel.AnchorPoint = Vector2.new(0.5, 1)
		toastLabel.Position = UDim2.new(0.5, 0, 1, -150)
		toastLabel.Size = UDim2.fromOffset(0, 38)
		toastLabel.AutomaticSize = Enum.AutomaticSize.X
		toastLabel.TextXAlignment = Enum.TextXAlignment.Center
		toastLabel.BackgroundColor3 = C.Night
		toastLabel.BackgroundTransparency = 0.15
		toastLabel.Visible = false
		UITheme.Corner(toastLabel, 19)
		UITheme.Stroke(toastLabel, C.Gold, 1.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
		pad.Parent = toastLabel
	end
	toastToken = (toastToken or 0) + 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or C.Text
	toastLabel.Visible = true
	task.delay(2.6, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

return UITheme
