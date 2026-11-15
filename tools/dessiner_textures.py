# Dessine les textures de VFX du jeu dans assets/textures/ (PNG blancs sur
# fond transparent : Roblox les teinte à la couleur de chaque Stand).
# Usage (depuis la racine du dépôt) : python3 -I tools/dessiner_textures.py
#
# Après modification : réimporter les PNG dans Roblox (Gestionnaire d'assets)
# et mettre les nouveaux ID dans SpellFX.client.luau (tableau TEXTURES).
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("assets", "textures")
SS = 4  # suréchantillonnage : on dessine 4x plus grand puis on réduit
random.seed(7)
np.random.seed(7)


def canvas(size):
    return Image.new("L", (size * SS, size * SS), 0)


def finish(mask, size, blur=0, glow=0, name="tex"):
    """mask : image L (alpha). Ajoute un halo optionnel, réduit, enregistre."""
    m = mask
    if glow:
        halo = m.filter(ImageFilter.GaussianBlur(glow * SS))
        m = Image.fromarray(np.maximum(np.asarray(m), (np.asarray(halo) * 0.85).astype(np.uint8)))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    m = m.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(m)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    return path


def radial(size, power=2.0):
    n = size * SS
    y, x = np.mgrid[0:n, 0:n]
    c = (n - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (n / 2)
    return np.clip(1 - d, 0, 1) ** power, d


# ─── 1. Halo doux ────────────────────────────────────────────────────────────
def glow():
    a, _ = radial(256, 2.2)
    return finish(Image.fromarray((a * 255).astype(np.uint8)), 256, name="glow")


# ─── 2. Étincelle étirée (verticale : s'aligne sur la vitesse) ───────────────
def spark():
    n = 128 * SS
    y, x = np.mgrid[0:n, 0:n]
    c = (n - 1) / 2
    dx = np.abs(x - c) / (n * 0.06)
    dy = np.abs(y - c) / (n * 0.48)
    a = np.clip(1 - dy, 0, 1) ** 1.5 * np.exp(-dx ** 2)
    return finish(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), 128, glow=2, name="spark")


# ─── 3. Impact en étoile éclatée ─────────────────────────────────────────────
def impact():
    size = 512
    m = canvas(size)
    d = ImageDraw.Draw(m)
    c = size * SS / 2
    spikes = 14
    for i in range(spikes):
        ang = i / spikes * 2 * math.pi + random.uniform(-0.12, 0.12)
        length = c * random.uniform(0.55, 0.98)
        width = c * random.uniform(0.05, 0.09)
        tip = (c + math.cos(ang) * length, c + math.sin(ang) * length)
        left = (c + math.cos(ang + math.pi / 2) * width, c + math.sin(ang + math.pi / 2) * width)
        right = (c + math.cos(ang - math.pi / 2) * width, c + math.sin(ang - math.pi / 2) * width)
        d.polygon([left, tip, right], fill=255)
    core, _ = radial(size, 1.4)
    arr = np.maximum(np.asarray(m), (core * 255 * 1.3).clip(0, 255).astype(np.uint8))
    return finish(Image.fromarray(arr), size, glow=6, name="impact")


# ─── 4. Onde de choc (anneau) ────────────────────────────────────────────────
def ring():
    _, dist = radial(512)
    a = np.exp(-((dist - 0.8) / 0.07) ** 2) + 0.35 * np.exp(-((dist - 0.68) / 0.12) ** 2)
    a = np.clip(a, 0, 1) * (dist < 1)
    return finish(Image.fromarray((a * 255).astype(np.uint8)), 512, name="ring")


# ─── 5. Slash en croissant ───────────────────────────────────────────────────
def slash():
    n = 512 * SS
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = n / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / n
    theta = np.arctan2(y - c, x - c)  # -pi..pi
    # arc d'environ 220° sur le haut, épais au milieu, effilé aux bouts
    t0, t1 = math.radians(-200), math.radians(20)
    th = np.where(theta > t1, theta - 2 * math.pi, theta)
    s_ = np.clip((th - t0) / (t1 - t0), 0, 1)
    inside_range = (th >= t0) & (th <= t1)
    radius = 0.42
    thickness = 0.16 * np.sin(math.pi * s_) ** 0.9
    inner = radius - thickness
    band = inside_range & (r <= radius) & (r >= inner)
    # plus lumineux sur le bord extérieur
    bright = np.clip((r - inner) / (thickness + 1e-6), 0, 1) ** 0.8
    a = band * (0.35 + 0.65 * bright)
    return finish(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), 512, glow=4, name="slash")


# ─── 6. Éclair ───────────────────────────────────────────────────────────────
def lightning():
    size = 512
    m = canvas(size)
    d = ImageDraw.Draw(m)
    n = size * SS
    random.seed(11)

    def bolt(x, y, length, angle, width, depth):
        points = [(x, y)]
        steps = 10
        for _ in range(steps):
            angle = max(-0.45, min(0.45, angle + random.uniform(-0.6, 0.6)))
            x += math.sin(angle) * length / steps
            y += math.cos(angle) * length / steps
            x = max(n * 0.15, min(n * 0.85, x))
            points.append((x, y))
            if depth > 0 and random.random() < 0.3:
                bolt(x, y, length * 0.35, angle + random.choice([-0.9, 0.9]), width * 0.5, depth - 1)
        d.line(points, fill=255, width=int(width), joint="curve")

    bolt(n * 0.5, n * 0.03, n * 0.94, 0.0, n * 0.04, 2)
    return finish(m, size, glow=6, name="lightning")


# ─── 7. Fumée (nuage doux) ───────────────────────────────────────────────────
def smoke():
    size = 256
    n = size * SS
    noise = np.zeros((n, n), np.float32)
    for octave, weight in ((8, 0.5), (16, 0.3), (32, 0.2)):
        small = np.random.rand(octave, octave).astype(np.float32)
        layer = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), np.float32) / 255
        noise += layer * weight
    mask, _ = radial(size, 1.3)
    a = np.clip(mask * (0.45 + noise * 0.9), 0, 1)
    return finish(Image.fromarray((a * 255).astype(np.uint8)), size, blur=2, name="smoke")


# ─── 8. Étoile à 5 branches (Star Platinum) ──────────────────────────────────
def star():
    size = 256
    m = canvas(size)
    d = ImageDraw.Draw(m)
    c = size * SS / 2
    pts = []
    for i in range(10):
        r = c * (0.85 if i % 2 == 0 else 0.36)
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=255)
    return finish(m, size, glow=5, name="star")


# ─── 9. Éclat de verre (Crazy Diamond) ───────────────────────────────────────
def shard():
    size = 256
    m = canvas(size)
    d = ImageDraw.Draw(m)
    n = size * SS
    pts = [(n * 0.5, n * 0.05), (n * 0.68, n * 0.55), (n * 0.56, n * 0.95), (n * 0.34, n * 0.6)]
    d.polygon(pts, fill=150)
    d.line(pts + [pts[0]], fill=255, width=int(n * 0.025))
    d.line([pts[0], (n * 0.5, n * 0.7)], fill=230, width=int(n * 0.012))
    return finish(m, size, glow=2, name="shard")


# ─── 10. Flamme ──────────────────────────────────────────────────────────────
def flame():
    n = 256 * SS
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (x - n / 2) / (n / 2)
    v = (y - n * 0.1) / (n * 0.85)
    width = np.clip(np.sin(np.clip(v, 0, 1) * math.pi * 0.9) * (0.25 + 0.4 * v), 0, None)
    a = np.clip(1 - np.abs(u) / (width + 1e-3), 0, 1) * (v >= 0) * (v <= 1)
    a = a ** 0.8 * (0.5 + 0.5 * np.clip(v, 0, 1))
    return finish(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), 256, blur=1.5, name="flame")


# ─── 11. Pétale (Gold Experience) ────────────────────────────────────────────
def petal():
    n = 256 * SS
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (x - n / 2) / (n * 0.5)
    v = (y - n / 2) / (n * 0.46)  # -1 en haut (pointe), +1 en bas
    width = 0.55 * np.clip(1 - v ** 2, 0, 1) ** 0.6 * (1 + 0.3 * v)
    shape = (np.abs(u) < width) & (np.abs(v) <= 1)
    edge = np.clip(1 - np.abs(u) / (width + 1e-6), 0, 1)
    vein = np.exp(-(u / 0.03) ** 2) * 0.3
    a = shape * (0.55 + 0.35 * edge + vein)
    return finish(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)), 256, glow=2, name="petal")


# ─── 12. Gemme taillée (Hierophant Green) ────────────────────────────────────
def gem():
    size = 256
    m = canvas(size)
    d = ImageDraw.Draw(m)
    n = size * SS
    top, mid_l, mid_r, bottom = (n * 0.5, n * 0.1), (n * 0.15, n * 0.42), (n * 0.85, n * 0.42), (n * 0.5, n * 0.92)
    d.polygon([top, mid_r, bottom, mid_l], fill=170)
    d.polygon([top, (n * 0.65, n * 0.42), (n * 0.5, n * 0.6), (n * 0.35, n * 0.42)], fill=255)
    d.line([mid_l, mid_r], fill=255, width=int(n * 0.015))
    d.line([top, mid_r, bottom, mid_l, top], fill=255, width=int(n * 0.02))
    return finish(m, size, glow=3, name="gem")


# ─── 13. Bande de fermeture éclair (Sticky Fingers, pour un Beam) ────────────
def zipper():
    size = 256
    m = canvas(size)
    d = ImageDraw.Draw(m)
    n = size * SS
    teeth = 8
    for i in range(teeth):
        y0 = i * n / teeth
        side = i % 2
        x0 = n * (0.22 if side == 0 else 0.5)
        d.rounded_rectangle([x0, y0 + n * 0.02, x0 + n * 0.28, y0 + n / teeth - n * 0.02], radius=n * 0.03, fill=255)
    d.rectangle([n * 0.47, 0, n * 0.53, n], fill=200)
    return finish(m, size, glow=1.5, name="zipper")


# ─── 14. Cercle de zone (attaques "Zone" au sol, vu du dessus) ──────────────
# Double anneau, graduations, étoile à 6 branches entrelacée, petits points
# et langues de flamme qui dépassent du bord. Vu de dessus sur un Decal.
def zone():
    size = 1024
    m = canvas(size)
    d = ImageDraw.Draw(m)
    n = size * SS
    c = n / 2
    R = n * 0.43

    def circle(r, w, fill=255):
        d.ellipse([c - r, c - r, c + r, c + r], outline=fill, width=int(w))

    # langues de flamme au bord (24, longueurs variées)
    for i in range(24):
        a0 = i / 24 * 2 * math.pi
        length = n * (0.035 + 0.025 * ((i * 7) % 5) / 4)
        half = 2 * math.pi / 24 * 0.32
        base_r = R + n * 0.005
        tip = (c + math.cos(a0 + half * 0.4) * (base_r + length), c + math.sin(a0 + half * 0.4) * (base_r + length))
        left = (c + math.cos(a0 - half) * base_r, c + math.sin(a0 - half) * base_r)
        right = (c + math.cos(a0 + half) * base_r, c + math.sin(a0 + half) * base_r)
        d.polygon([left, tip, right], fill=200)
    # anneaux
    circle(R, n * 0.012)
    circle(R - n * 0.03, n * 0.005, 210)
    circle(R * 0.62, n * 0.008)
    circle(R * 0.58, n * 0.004, 190)
    circle(R * 0.16, n * 0.006)
    # graduations entre les deux grands anneaux
    for i in range(72):
        a0 = i / 72 * 2 * math.pi
        big = i % 6 == 0
        r1 = R - n * 0.03
        r2 = R * 0.62 + (n * 0.0 if big else n * 0.06)
        if not big:
            r1, r2 = R - n * 0.035, R - n * 0.075
        d.line([(c + math.cos(a0) * r1, c + math.sin(a0) * r1), (c + math.cos(a0) * r2, c + math.sin(a0) * r2)],
               fill=230 if big else 160, width=int(n * (0.006 if big else 0.003)))
    # petits ronds sur l'anneau intermédiaire
    for i in range(12):
        a0 = (i + 0.5) / 12 * 2 * math.pi
        r = R * 0.79
        x, y = c + math.cos(a0) * r, c + math.sin(a0) * r
        rr = n * (0.012 if i % 2 == 0 else 0.007)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    # étoile à 6 branches : deux triangles
    for k in range(2):
        pts = []
        for j in range(3):
            a0 = -math.pi / 2 + k * math.pi / 3 + j * 2 * math.pi / 3
            pts.append((c + math.cos(a0) * R * 0.58, c + math.sin(a0) * R * 0.58))
        d.line(pts + [pts[0]], fill=235, width=int(n * 0.007))
    # hexagone intérieur et rayons
    hexa = [(c + math.cos(math.pi / 6 + j * math.pi / 3) * R * 0.3, c + math.sin(math.pi / 6 + j * math.pi / 3) * R * 0.3) for j in range(6)]
    d.line(hexa + [hexa[0]], fill=200, width=int(n * 0.004))
    for j in range(6):
        a0 = -math.pi / 2 + j * math.pi / 3
        d.line([(c + math.cos(a0) * R * 0.16, c + math.sin(a0) * R * 0.16), (c + math.cos(a0) * R * 0.58, c + math.sin(a0) * R * 0.58)],
               fill=120, width=int(n * 0.003))
    # léger fond lumineux à l'intérieur (la zone reste lisible au sol)
    arr = np.asarray(m, np.float32)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    dist = np.sqrt((x - c) ** 2 + (y - c) ** 2) / R
    fill = np.clip(1 - dist, 0, 1) ** 0.5 * 45 * (dist < 1)
    m = Image.fromarray(np.clip(np.maximum(arr, fill), 0, 255).astype(np.uint8))
    return finish(m, size, glow=3, name="zone")


# ─── Planche d'aperçu (couleurs de quelques Stands) ──────────────────────────
def preview(paths):
    colors = [(170, 120, 255), (255, 200, 70), (255, 130, 200), (110, 255, 140), (255, 120, 40),
              (90, 160, 255), (220, 30, 60), (200, 255, 255), (60, 220, 120), (230, 230, 240),
              (255, 160, 60), (150, 255, 190), (150, 200, 255)]
    cell = 200
    cols = 5
    rows = math.ceil(len(paths) / cols)
    sheet = Image.new("RGB", (cols * cell, rows * cell), (22, 20, 28))
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        tex = Image.open(path).convert("RGBA").resize((cell - 40, cell - 40), Image.LANCZOS)
        r, g, b = colors[i % len(colors)]
        tint = Image.new("RGBA", tex.size, (r, g, b, 255))
        tint.putalpha(tex.getchannel("A"))
        x, y = (i % cols) * cell + 20, (i // cols) * cell + 10
        sheet.paste(tint, (x, y), tint)
        draw.text((x, y + cell - 38), os.path.basename(path), fill=(200, 200, 210))
    out = os.path.join("assets", "apercu_textures.png")
    sheet.save(out)
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    made = [f() for f in (glow, spark, impact, ring, slash, lightning, smoke, star, shard, flame, petal, gem, zipper, zone)]
    for p in made:
        print(p, os.path.getsize(p) // 1024, "Ko")
    print("aperçu :", preview(made))
