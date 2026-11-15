-- CmdCast : pose du joueur pendant une attaque de son Stand (voir PlayerPoses).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
return require(ReplicatedStorage:WaitForChild("PlayerPoses")).Build("CmdCast")
