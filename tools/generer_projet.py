# Régénère default.project.json à partir des fichiers de src/ (un script = une entrée).
# Usage (depuis la racine du dépôt) : python3 -I tools/generer_projet.py
import os, json, sys
SUF = [".server.luau", ".client.luau", ".luau"]
def inst(fn):
    for s in SUF:
        if fn.endswith(s): return fn[:-len(s)]
def files(d):
    return {inst(f): {"$path": f"{d}/{f}"} for f in sorted(os.listdir(d)) if os.path.isfile(f"{d}/{f}") and inst(f)}
rs = files("src/ReplicatedStorage")
rs["Animations"] = {"$path": "src/ReplicatedStorage/Animations", "$ignoreUnknownInstances": True}
proj = {
  "name": "Jeu-roblox",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": rs,
    "ServerScriptService": files("src/ServerScriptService"),
    "StarterPlayer": {"StarterPlayerScripts": files("src/StarterPlayerScripts")},
  },
}
json.dump(proj, open("default.project.json", "w"), indent=2, ensure_ascii=False); open("default.project.json","a").write("\n")
