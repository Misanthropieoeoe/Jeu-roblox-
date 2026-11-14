# Jeu Roblox

Projet Roblox synchronisé avec Roblox Studio grâce à [Rojo](https://rojo.space).

## Structure

| Dossier        | Dans Roblox Studio                          | Type de script                 |
|----------------|---------------------------------------------|--------------------------------|
| `src/server/`  | `ServerScriptService.Server`                | Scripts serveur                |
| `src/client/`  | `StarterPlayer.StarterPlayerScripts.Client` | LocalScripts                   |
| `src/shared/`  | `ReplicatedStorage.Shared`                  | ModuleScripts partagés         |

Convention des noms de fichiers :
- `Nom.server.luau` → **Script**
- `Nom.client.luau` → **LocalScript**
- `Nom.luau` → **ModuleScript**

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
