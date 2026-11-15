-- Nettoyage des scripts en double dans Roblox Studio.
-- À coller dans la barre de commande de Studio (en bas : "Exécuter une
-- commande"), en MODE ÉDITION (pas en Play). Ctrl+Z annule tout.
--
-- 1. Doublons : dans ReplicatedStorage, ReplicatedStorage.Animations,
--    StarterPlayerScripts et ServerScriptService, si deux scripts ont le même
--    nom, on garde :
--      - la version à jour pour les scripts listés dans RECENT (reconnue à
--        un bout de code que seule la dernière version contient) ;
--      - sinon une seule copie si elles sont identiques.
--    Deux copies DIFFÉRENTES d'un autre script sont gardées (avertissement
--    en orange dans la Sortie) : il faut alors regarder à la main.
-- 2. Restes "Hello world" du modèle par défaut de Rojo : Client, Server et
--    le dossier Shared (qui ne contient que Hello).
--
-- La version en une ligne (à coller) est dans la réponse de Claude.

local ChangeHistory = game:GetService("ChangeHistoryService")
ChangeHistory:SetWaypoint("Avant nettoyage")

local removed = 0

-- Bout de code présent seulement dans la dernière version
local RECENT = {
	SpellBar = "SpellBarVersion",
	StandSpells = "HomingRange",
	StandStrikes = "local BLOCK = hold",
}

local function remove(child, why)
	print(why, child:GetFullName())
	child:Destroy()
	removed += 1
end

local function dedupe(parent)
	if not parent then return end
	local groups = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("LuaSourceContainer") then
			local key = child.ClassName .. ":" .. child.Name
			groups[key] = groups[key] or {}
			table.insert(groups[key], child)
		end
	end
	for _, copies in pairs(groups) do
		if #copies > 1 then
			local marker = RECENT[copies[1].Name]
			local keep = nil
			if marker then
				for _, c in ipairs(copies) do
					if c.Source:find(marker, 1, true) then keep = c break end
				end
			end
			for _, c in ipairs(copies) do
				if c ~= (keep or copies[1]) then
					if keep then
						remove(c, "Supprimé ancienne version :")
					elseif c.Source == copies[1].Source then
						remove(c, "Supprimé doublon :")
					else
						warn("Doublon DIFFÉRENT gardé :", c:GetFullName())
					end
				end
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
