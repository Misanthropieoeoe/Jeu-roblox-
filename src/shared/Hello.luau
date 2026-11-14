-- ModuleScript partagé (serveur + client), dans ReplicatedStorage.Shared
local Hello = {}

function Hello.saluer(nom: string): string
	return "Salut " .. nom .. " !"
end

return Hello
