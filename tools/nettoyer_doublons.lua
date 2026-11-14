-- Nettoyage des scripts en double dans Roblox Studio.
-- À coller dans la barre de commande de Studio (en bas : "Exécuter une
-- commande"), en MODE ÉDITION (pas en Play). Ctrl+Z annule tout.
--
-- 1. Doublons : dans ReplicatedStorage, ReplicatedStorage.Animations,
--    StarterPlayerScripts et ServerScriptService, si deux scripts ont le même
--    nom ET le même code, la copie en trop est supprimée. Deux scripts du
--    même nom mais avec un code DIFFÉRENT sont gardés (avertissement en
--    orange dans la Sortie) : il faut alors regarder à la main.
-- 2. Restes "Hello world" du modèle par défaut de Rojo : Client, Server et
--    le dossier Shared (qui ne contient que Hello).
--
-- La version en une ligne (à coller) est dans la réponse de Claude.

local ChangeHistory = game:GetService("ChangeHistoryService")
ChangeHistory:SetWaypoint("Avant nettoyage")

local removed = 0

local function dedupe(parent)
	if not parent then return end
	local seen = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("LuaSourceContainer") then
			local key = child.ClassName .. ":" .. child.Name
			local first = seen[key]
			if first then
				if first.Source == child.Source then
					print("Supprimé doublon :", child:GetFullName())
					child:Destroy()
					removed += 1
				else
					warn("Doublon DIFFÉRENT gardé :", child:GetFullName())
				end
			else
				seen[key] = child
			end
		end
	end
end

local RS = game.ReplicatedStorage
local SPS = game.StarterPlayer.StarterPlayerScripts
local SSS = game.ServerScriptService

dedupe(RS)
dedupe(RS:FindFirstChild("Animations"))
dedupe(SPS)
dedupe(SSS)

local function relic(script)
	if script and script:IsA("LuaSourceContainer") and script.Source:find("Hello world") then
		print("Supprimé :", script:GetFullName())
		script:Destroy()
		removed += 1
	end
end
relic(SPS:FindFirstChild("Client"))
relic(SSS:FindFirstChild("Server"))

local shared = RS:FindFirstChild("Shared")
if shared and #shared:GetChildren() == 1 and shared:FindFirstChild("Hello") then
	print("Supprimé :", shared:GetFullName())
	shared:Destroy()
	removed += 1
end

ChangeHistory:SetWaypoint("Nettoyage doublons")
print("Nettoyage terminé :", removed, "élément(s) supprimé(s). Ctrl+Z pour annuler.")
