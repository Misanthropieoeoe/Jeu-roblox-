# Lit les attributs (ex. _lemonadeUniqueId de Lemonade) des scripts d'un
# fichier .rbxlx. Utilisé par extraire_scripts.py.
import base64
import struct

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}


def decode_attributes(b64):
    """Décode AttributesSerialize. Ne garde que les attributs texte et
    nombre (les seuls utilisés sur les scripts) ; s'arrête sur un type inconnu."""
    if not b64:
        return {}
    data = base64.b64decode(b64.strip())
    out, pos = {}, 0

    def u32():
        nonlocal pos
        (v,) = struct.unpack_from("<I", data, pos)
        pos += 4
        return v

    def string():
        nonlocal pos
        n = u32()
        s = data[pos:pos + n].decode("utf-8", "replace")
        pos += n
        return s

    count = u32()
    for _ in range(count):
        key = string()
        kind = data[pos]
        pos += 1
        if kind == 0x02:  # String
            out[key] = {"String": string()}
        elif kind == 0x03:  # Bool
            out[key] = {"Bool": data[pos] != 0}
            pos += 1
        elif kind == 0x06:  # Float64
            (v,) = struct.unpack_from("<d", data, pos)
            pos += 8
            out[key] = {"Float64": v}
        else:
            break
    return out


def script_attributes(root):
    """{ "Service/Dossier/Script": { attribut: valeur } } pour tous les scripts."""
    result = {}

    def props(item):
        p = item.find("Properties")
        return {c.get("name"): c.text for c in p} if p is not None else {}

    def walk(node, path):
        for item in node.findall("Item"):
            pr = props(item)
            pth = path + [pr.get("Name") or ""]
            if item.get("class") in SCRIPT_CLASSES:
                attrs = decode_attributes(pr.get("AttributesSerialize"))
                if attrs:
                    result["/".join(pth)] = attrs
            walk(item, pth)

    walk(root, [])
    return result
