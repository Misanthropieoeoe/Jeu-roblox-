# Synthétise les effets sonores originaux du jeu dans assets/sons/ (WAV mono
# 16 bits, 44,1 kHz). Usage (depuis la racine du dépôt) :
#   python3 -I tools/generer_sons.py
# Ensuite : importer les WAV dans Roblox (Gestionnaire d'assets -> Audio) et
# mettre les ID dans src/ReplicatedStorage/SFX.luau.
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join("assets", "sons")
rng = np.random.default_rng(11)


def t(dur):
    return np.arange(int(dur * RATE)) / RATE


def env(x, attack, decay_power):
    """attaque linéaire puis décroissance exponentielle"""
    n = len(x)
    a = max(1, int(attack * RATE))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(0, 1, n - a)
    e[a:] = np.exp(-tail * decay_power)
    return x * e


def lowpass(x, cutoff):
    # filtre passe-bas à un pôle, appliqué deux fois
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        y = np.zeros_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc += alpha * (v - acc)
            y[i] = acc
        x = y
    return x


def sweep_lowpass(x, c0, c1):
    """passe-bas dont la fréquence glisse de c0 à c1"""
    cut = np.linspace(c0, c1, len(x))
    alpha = 1 - np.exp(-2 * np.pi * cut / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha[i] * (v - acc)
        y[i] = acc
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(dur * RATE))


def tone(dur, f0, f1=None, shape="sine"):
    f1 = f0 if f1 is None else f1
    freq = np.linspace(f0, f1, int(dur * RATE))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    return np.sin(phase)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(0.01 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    return path


# ─── Les sons ──────────────────────────────────────────────────────────────
def punch_hit():
    """coup de poing : claque sèche + bruit grave"""
    thump = env(tone(0.16, 180, 60), 0.002, 9)
    crack = env(lowpass(noise(0.08), 3500), 0.001, 14) * 0.8
    return save("punch_hit", mix(thump, crack))


def heavy_hit():
    """coup final / gros coup : boum grave + craquement"""
    boom = env(tone(0.55, 120, 38), 0.003, 6)
    sub = env(tone(0.5, 55, 40), 0.01, 5) * 0.6
    crack = env(lowpass(noise(0.18), 5000), 0.001, 10) * 0.9
    return save("heavy_hit", mix(boom, sub, crack))


def impact():
    """impact de sort : grondement court"""
    rumble = env(lowpass(noise(0.8), 600), 0.004, 5)
    body = env(tone(0.6, 90, 45), 0.004, 5) * 0.7
    snap = env(lowpass(noise(0.06), 6000), 0.001, 12) * 0.5
    return save("impact", mix(rumble, body, snap))


def whoosh():
    """mouvement rapide : souffle filtré qui monte puis redescend"""
    n = noise(0.38)
    x = sweep_lowpass(n, 300, 2600)
    e = np.sin(np.linspace(0, np.pi, len(x))) ** 2
    return save("whoosh", x * e, 0.75)


def projectile():
    """tir : zap descendant"""
    zap = env(tone(0.3, 1400, 300, "saw"), 0.002, 5) * 0.5
    air = env(sweep_lowpass(noise(0.3), 4000, 800), 0.002, 4) * 0.6
    return save("projectile", mix(lowpass(zap, 4000), air), 0.7)


def block():
    """coup bloqué : choc sourd et métallique"""
    clang = env(mix(tone(0.25, 420), tone(0.25, 610) * 0.6, tone(0.25, 980) * 0.3), 0.001, 12)
    knock = env(lowpass(noise(0.05), 2500), 0.001, 15)
    return save("block", mix(clang, knock), 0.8)


def parry():
    """parade parfaite : tintement clair qui résonne"""
    ring = mix(tone(0.7, 1320), tone(0.7, 1980) * 0.5, tone(0.7, 2640) * 0.3)
    ring = env(ring, 0.002, 4)
    hit = env(lowpass(noise(0.04), 7000), 0.001, 15) * 0.6
    return save("parry", mix(ring, hit), 0.8)


def guard_break():
    """garde brisée : éclatement + notes qui tombent"""
    shatter = env(lowpass(noise(0.6), 7000), 0.001, 6)
    fall = env(mix(tone(0.6, 900, 250), tone(0.6, 1350, 380) * 0.6), 0.002, 4) * 0.6
    return save("guard_break", mix(shatter, fall), 0.85)


def double_jump():
    """double saut : souffle qui monte"""
    air = sweep_lowpass(noise(0.32), 400, 3000)
    e = np.sin(np.linspace(0, np.pi, len(air))) ** 1.5
    lift = env(tone(0.32, 300, 700), 0.01, 4) * 0.25
    return save("double_jump", mix(air * e, lift), 0.6)


def summon():
    """invocation du Stand : scintillement qui monte"""
    d = 0.9
    shimmer = mix(*[env(tone(d, f, f * 2), 0.15, 3) * a for f, a in ((440, 0.5), (660, 0.35), (880, 0.25))])
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 14 * t(d))
    air = sweep_lowpass(noise(d), 500, 5000) * np.linspace(0.1, 0.6, int(d * RATE))
    return save("summon", mix(shimmer * trem, env(air, 0.3, 2)), 0.7)


def coin():
    """argent ramassé : deux notes brillantes"""
    a = env(tone(0.12, 1320, 1320, "square"), 0.002, 6) * 0.4
    b = env(tone(0.3, 1760, 1760, "square"), 0.002, 5) * 0.4
    x = np.concatenate([a, b])
    return save("coin", lowpass(x, 6000), 0.6)


def chest():
    """coffre de skins : roulement puis éclat brillant"""
    roll = env(lowpass(noise(0.5), 1500), 0.05, 1) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * t(0.5))))
    sparkle = env(mix(tone(0.8, 880, 1760), tone(0.8, 1320, 2640) * 0.5), 0.005, 3)
    return save("chest", np.concatenate([roll * 0.5, sparkle]), 0.75)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (punch_hit, heavy_hit, impact, whoosh, projectile, block, parry, guard_break, double_jump, summon, coin, chest):
        p = f()
        print(p, os.path.getsize(p) // 1024, "Ko")
