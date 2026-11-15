# Jeu Roblox

Projet Roblox synchronisé avec Roblox Studio grâce à [Rojo](https://rojo.space).

## Structure

| Dossier                       | Dans Roblox Studio                      |
|-------------------------------|-----------------------------------------|
| `src/ServerScriptService/`    | `ServerScriptService` (scripts serveur) |
| `src/StarterPlayerScripts/`   | `StarterPlayer.StarterPlayerScripts` (LocalScripts) |
| `src/ReplicatedStorage/`      | `ReplicatedStorage` (ModuleScripts partagés) |
| `src/ReplicatedStorage/Animations/` | `ReplicatedStorage.Animations`    |

Convention des noms de fichiers :
- `Nom.server.luau` → **Script**
- `Nom.client.luau` → **LocalScript**
- `Nom.luau` → **ModuleScript**

Chaque script est déclaré **un par un** dans `default.project.json` : Rojo ne touche
qu'à ces scripts. La map, les modèles (StarPlatinumTemplate…) et tout le reste
restent gérés dans Studio. **Un nouveau script doit être ajouté dans
`default.project.json`**, sauf dans `Animations/` qui est synchronisé en entier.

Branches : `dev` = en test (endroit de test), `main` = validé (vrai jeu).

## Installation (une seule fois)

1. Installer **GitHub Desktop** et cloner ce dépôt.
2. Installer **VS Code** + l'extension **Rojo** (par evaera).
3. Dans Roblox Studio, installer le **plugin Rojo** (l'extension VS Code propose de l'installer).

## Utilisation

1. Ouvrir le dossier du dépôt dans VS Code.
2. `Ctrl+Shift+P` → **Rojo: Open menu** → démarrer le serveur avec `default.project.json`.
3. Dans Roblox Studio : onglet **Plugins** → **Rojo** → **Connect**.
4. Les scripts apparaissent dans Studio et se mettent à jour automatiquement.

Pour récupérer les modifications faites sur GitHub : **Fetch origin** puis **Pull** dans GitHub Desktop.

> ⚠️ Seuls les scripts sont dans le dépôt. Les modèles, la map et les parties (Parts) restent dans le fichier de place sauvegardé dans Studio.
