# Régénère default.project.json à partir des fichiers de src/ (un script =
# une entrée), en remettant sur chaque script ses attributs Studio (ex. les
# identifiants _lemonadeUniqueId de Lemonade) enregistrés dans
# tools/attributs_studio.json, pour que Rojo ne les efface pas.
# Usage (depuis la racine du dépôt) : python3 -I tools/generer_projet.py
import json
import os

SUFFIXES = [".server.luau", ".client.luau", ".luau"]
ATTR_FILE = os.path.join("tools", "attributs_studio.json")

# dossier de src  ->  chemin dans Studio
FOLDERS = {
    "src/ReplicatedStorage": "ReplicatedStorage",
    "src/ReplicatedStorage/Animations": "ReplicatedStorage/Animations",
    "src/ServerScriptService": "ServerScriptService",
    "src/StarterPlayerScripts": "StarterPlayer/StarterPlayerScripts",
}

attributes = {}
if os.path.exists(ATTR_FILE):
    with open(ATTR_FILE, encoding="utf-8") as f:
        attributes = json.load(f)


def instance_name(filename):
    for suffix in SUFFIXES:
        if filename.endswith(suffix):
            return filename[: -len(suffix)]
    return None


def scripts_in(folder):
    studio = FOLDERS[folder]
    nodes = {}
    for filename in sorted(os.listdir(folder)):
        name = instance_name(filename)
        if not name or not os.path.isfile(os.path.join(folder, filename)):
            continue
        node = {"$path": f"{folder}/{filename}"}
        attrs = attributes.get(f"{studio}/{name}")
        if attrs:
            node["$attributes"] = attrs
        nodes[name] = node
    return nodes


replicated = scripts_in("src/ReplicatedStorage")
animations = {"$className": "Folder", "$ignoreUnknownInstances": True}
animations.update(scripts_in("src/ReplicatedStorage/Animations"))
replicated["Animations"] = animations

project = {
    "name": "Jeu-roblox",
    "tree": {
        "$className": "DataModel",
        "ReplicatedStorage": replicated,
        "ServerScriptService": scripts_in("src/ServerScriptService"),
        "StarterPlayer": {"StarterPlayerScripts": scripts_in("src/StarterPlayerScripts")},
    },
}

with open("default.project.json", "w", encoding="utf-8") as f:
    json.dump(project, f, indent=2, ensure_ascii=False)
    f.write("\n")
