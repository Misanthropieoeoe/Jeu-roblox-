-- ChatAnnounce. Affiche dans le chat les annonces du serveur (StandFX
-- "Announce", texte, couleur), par exemple l'apparition d'une Flèche Requiem.
-- Marche avec le nouveau chat (TextChatService) et l'ancien.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local standFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StandFX")

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function announce(text, color)
	color = typeof(color) == "Color3" and color or Color3.fromRGB(255, 200, 80)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(string.format('<font color="%s"><b>%s</b></font>', hex(color), text))
			return
		end
	end
	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = color, Font = Enum.Font.GothamBold })
	end)
end

standFX.OnClientEvent:Connect(function(kind, text, color)
	if kind == "Announce" and type(text) == "string" then
		announce(text, color)
	end
end)
