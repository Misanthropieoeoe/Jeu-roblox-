-- Script serveur, dans ServerScriptService.Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Hello = require(ReplicatedStorage.Shared.Hello)

Players.PlayerAdded:Connect(function(joueur)
	print("[Serveur] " .. Hello.saluer(joueur.Name))
end)

print("[Serveur] Rojo fonctionne !")
