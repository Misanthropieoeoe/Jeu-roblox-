-- EmoteMenu. Fenêtre EMOTES (touche H) : poses originales style JoJo
-- (PlayerPoses.Emotes). La pose est tenue jusqu'à ce que le joueur bouge,
-- saute, attaque ou relance une emote. Tout le monde la voit (AnimSync, voir
-- AnimationController / AnimReplicator), avec des "ゴゴゴ" autour du joueur.
-- Raccourcis : 1 à 8 quand la fenêtre est ouverte.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
if not UITheme.Guard(script) then return end
local PlayerPoses = require(ReplicatedStorage:WaitForChild("PlayerPoses"))
local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local C = UITheme.Colors

local player = Players.LocalPlayer
local _, root = UITheme.Screen("EmoteMenu", 8)
local win = UITheme.Window(root, "Emotes", "EMOTES", "Prends la pose · bouge pour arrêter", C.Pink, Vector2.new(640, 400))

local grid = UITheme.Scroll(win.body, C.Pink)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(140, 120)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

-- Emote en cours ------------------------------------------------------------------
local current = nil -- Id de l'emote jouée
local startedAt = 0

local function stopEmote()
	if not current then return end
	local id = current
	current = nil
	if AnimationController.CurrentAnimation() == id then
		AnimationController.Stop(id)
	end
end

local function playEmote(id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if player:GetAttribute("Hitstun") then
		UITheme.Toast("Impossible pendant un coup reçu.", C.Red)
		return
	end
	if current == id then
		stopEmote()
		return
	end
	stopEmote()
	current = id
	startedAt = os.clock()
	AnimationController.Play(id)
end

-- On arrête la pose dès que le joueur bouge / saute / prend un coup
RunService.Heartbeat:Connect(function()
	if not current then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		current = nil
		return
	end
	if os.clock() - startedAt < 0.25 then return end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local state = humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
	-- une autre animation a pris le relais (attaque, coup reçu, garde…)
	local replaced = AnimationController.CurrentAnimation() ~= current
	if moving or airborne or replaced or player:GetAttribute("Hitstun") then
		if replaced then
			current = nil
		else
			stopEmote()
		end
	end
end)
player.CharacterAdded:Connect(function()
	current = nil
end)

-- Cartes -------------------------------------------------------------------------
for order, emote in ipairs(PlayerPoses.Emotes) do
	local card = UITheme.Card(grid, C.Pink)
	card.Name = emote.Id
	card.LayoutOrder = order

	local icon = UITheme.Label(card, emote.Icon, 34, C.Text, UITheme.Title)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 10)
	icon.Size = UDim2.fromOffset(60, 60)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.BackgroundColor3 = C.Pink
	icon.BackgroundTransparency = 0.8
	UITheme.Corner(icon, 30)
	UITheme.Stroke(icon, C.Pink, 1.35, 0.3)

	local name = UITheme.Label(card, emote.Name, 15, C.Text, UITheme.Title)
	name.Position = UDim2.new(0, 8, 0, 76)
	name.Size = UDim2.new(1, -16, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Center

	local key = UITheme.Label(card, tostring(order), 11, C.Muted, UITheme.Bold)
	key.AnchorPoint = Vector2.new(0.5, 0)
	key.Position = UDim2.new(0.5, 0, 0, 98)
	key.Size = UDim2.fromOffset(20, 16)
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.BackgroundColor3 = C.Night
	key.BackgroundTransparency = 0.3
	UITheme.Corner(key, 5)

	card.Activated:Connect(function()
		UITheme.Close("Emotes")
		playEmote(emote.Id)
	end)
end

-- Touches 1 à 8 quand la fenêtre est ouverte
local NUMBER_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not UITheme.IsOpen("Emotes") then return end
	for i, keyCode in ipairs(NUMBER_KEYS) do
		if input.KeyCode == keyCode and PlayerPoses.Emotes[i] then
			UITheme.Close("Emotes")
			playEmote(PlayerPoses.Emotes[i].Id)
			return
		end
	end
end)

-- "ゴゴゴ" autour de chaque joueur qui fait une emote (visible par tous) ----------
local rng = Random.new()
local MENACE_COLOR = Color3.fromRGB(190, 120, 255)

local function letter(rootPart)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(rootPart.Position + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.5, 2.5), rng:NextNumber(-3, 3)))
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(44, 44)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "ゴ"
	label.TextScaled = true
	label.TextColor3 = MENACE_COLOR
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Rotation = rng:NextNumber(-20, 20)
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(1.3), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.4, function() anchor:Destroy() end)
end

local function isEmote(name)
	return type(name) == "string" and string.sub(name, 1, 5) == "Emote"
end

local menacing = setmetatable({}, { __mode = "k" })
local function watchCharacter(character)
	local function check()
		if not isEmote(character:GetAttribute("SyncAnim")) or menacing[character] then return end
		menacing[character] = true
		task.spawn(function()
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			local started = os.clock()
			-- l'attribut SyncAnim reste tant que le joueur n'a pas lancé autre chose
			while character.Parent and rootPart and isEmote(character:GetAttribute("SyncAnim"))
				and os.clock() - started < 30 do
				-- le joueur bouge : la pose est finie
				if rootPart.AssemblyLinearVelocity.Magnitude > 4 and os.clock() - started > 0.4 then break end
				letter(rootPart)
				task.wait(0.28)
			end
			menacing[character] = nil
		end)
	end
	character:GetAttributeChangedSignal("SyncAnim"):Connect(check)
	character:GetAttributeChangedSignal("SyncAnimAt"):Connect(check)
	check()
end

local function watchPlayer(p)
	if p.Character then watchCharacter(p.Character) end
	p.CharacterAdded:Connect(watchCharacter)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
