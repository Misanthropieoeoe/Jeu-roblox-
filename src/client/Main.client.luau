-- LocalScript, dans StarterPlayer.StarterPlayerScripts.Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Hello = require(ReplicatedStorage.Shared.Hello)

print("[Client] " .. Hello.saluer(Players.LocalPlayer.Name))
