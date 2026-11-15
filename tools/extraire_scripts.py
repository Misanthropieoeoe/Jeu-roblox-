# Extrait les scripts d'un fichier .rbxlx vers src/ (voir tools/LISEZMOI.md).
# Usage : python3 -I tools/extraire_scripts.py <fichier.rbxlx> <racine du dépôt>
import sys, os, json, xml.etree.ElementTree as ET
place, out = sys.argv[1], sys.argv[2]
root = ET.parse(place).getroot()
EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
def props(it):
    p = it.find("Properties"); return {c.get("name"): c.text for c in p} if p is not None else {}
# chemin Studio -> dossier dans src
MAP = {
  "ServerScriptService": "src/ServerScriptService",
  "StarterPlayer/StarterPlayerScripts": "src/StarterPlayerScripts",
  "ReplicatedStorage": "src/ReplicatedStorage",
  "ReplicatedStorage/Animations": "src/ReplicatedStorage/Animations",
}
written = []
def walk(node, path):
    for it in node.findall("Item"):
        cls = it.get("class"); pr = props(it); n = pr.get("Name") or ""; pth = path + [n]
        parent = "/".join(path)
        if cls in EXT and parent in MAP:
            d = os.path.join(out, MAP[parent]); os.makedirs(d, exist_ok=True)
            f = os.path.join(d, n + EXT[cls])
            src = (pr.get("Source") or "").replace("\r\n", "\n")
            if not src.endswith("\n"): src += "\n"
            open(f, "w", encoding="utf-8").write(src); written.append((cls, "/".join(pth), os.path.relpath(f, out)))
        walk(it, pth)
walk(root, [])
for w in written: print(*w, sep="  |  ")
print(len(written), "fichiers")

# Attributs Studio des scripts (identifiants Lemonade…) pour generer_projet.py
import json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from attributs import script_attributes
attr_path = os.path.join(out, "tools", "attributs_studio.json")
saved = {}
if os.path.exists(attr_path):
    with open(attr_path, encoding="utf-8") as f:
        saved = json.load(f)
saved.update(script_attributes(root))
with open(attr_path, "w", encoding="utf-8") as f:
    json.dump(saved, f, indent=2, ensure_ascii=False, sort_keys=True)
    f.write("\n")
print(len(saved), "scripts avec attributs enregistrés dans tools/attributs_studio.json")
