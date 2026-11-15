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


# ─── Outils "anime" : écho, saturation, accords de cuivres ───────────────────
def fft_convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
    return y


def reverb(x, seconds=1.2, wet=0.35, bright=4000):
    """réverbération de grande salle (réponse impulsionnelle de bruit qui s'éteint)"""
    ir = noise(seconds) * np.exp(-np.linspace(0, 6, int(seconds * RATE)))
    ir = lowpass(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet_sig = fft_convolve(x, ir)
    out = np.zeros(len(wet_sig))
    out[: len(x)] += x * (1 - wet)
    return out + wet_sig * wet


def drive(x, amount=2.5):
    """saturation douce : rend les coups plus "épais" """
    return np.tanh(x * amount) / np.tanh(amount)


def brass(dur, freqs, attack=0.02, decay=2.5, cutoff=2200):
    """accord de cuivres synthétiques (dents de scie filtrées, léger désaccord)"""
    layers = []
    for f in freqs:
        for detune in (-0.004, 0.0, 0.005):
            layers.append(tone(dur, f * (1 + detune), f * (1 + detune), "saw"))
    chord = mix(*layers) / len(layers)
    return env(lowpass(chord, cutoff), attack, decay)


def reverse_swell(dur, bright=6000):
    """souffle inversé qui monte (comme une cymbale passée à l'envers)"""
    x = lowpass(noise(dur), bright) * np.linspace(0, 1, int(dur * RATE)) ** 3
    return x


def note(name):
    table = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    letter, acc, octave = name[0], name[1:-1], int(name[-1])
    semi = table[letter] + (1 if acc == "#" else -1 if acc == "b" else 0) + (octave - 4) * 12
    return 440 * 2 ** (semi / 12)


# ─── Les sons ──────────────────────────────────────────────────────────────
def punch_hit():
    """coup de poing anime : claque saturée + basse courte + petit écho"""
    thump = env(tone(0.18, 210, 55), 0.001, 10)
    crack = env(lowpass(noise(0.07), 6000), 0.0005, 16)
    x = drive(mix(thump, crack * 0.9), 3.0)
    return save("punch_hit", reverb(x, 0.5, 0.18))


def heavy_hit():
    """coup final : énorme impact + accord de cuivres sombre + longue salle"""
    boom = env(tone(0.7, 140, 32), 0.002, 5)
    sub = env(tone(0.9, 48, 36), 0.01, 3.5) * 0.8
    crack = env(lowpass(noise(0.2), 7000), 0.0005, 9)
    hit = drive(mix(boom, sub, crack), 3.5)
    stab = brass(0.9, [note("D2"), note("A2"), note("D3"), note("F3")], 0.004, 3.2, 1800) * 0.55
    return save("heavy_hit", reverb(mix(hit, stab), 1.6, 0.3))


def impact():
    """impact de sort : explosion grave qui roule dans une grande salle"""
    rumble = env(lowpass(noise(1.0), 500), 0.003, 4)
    body = env(tone(0.8, 95, 40), 0.003, 4) * 0.8
    snap = env(lowpass(noise(0.05), 8000), 0.0005, 14) * 0.6
    return save("impact", reverb(drive(mix(rumble, body, snap), 2.2), 1.4, 0.35))


def whoosh():
    """mouvement éclair : souffle inversé qui s'arrête net + traînée"""
    swell = reverse_swell(0.32, 5000)
    cut = env(sweep_lowpass(noise(0.25), 3000, 400), 0.001, 6) * 0.5
    x = np.concatenate([swell, cut])
    return save("whoosh", reverb(x, 0.6, 0.2), 0.75)


def projectile():
    """tir : charge très courte puis décharge d'énergie"""
    charge = tone(0.08, 300, 1600, "saw") * np.linspace(0.2, 1, int(0.08 * RATE))
    blast = env(mix(tone(0.35, 1500, 220, "saw") * 0.5, sweep_lowpass(noise(0.35), 6000, 900)), 0.001, 4)
    x = np.concatenate([lowpass(charge, 5000) * 0.6, lowpass(blast, 5000)])
    return save("projectile", reverb(drive(x, 1.8), 0.7, 0.22), 0.7)


def block():
    """garde : choc métallique sourd, comme un bouclier"""
    partials = [(380, 1.0), (571, 0.6), (897, 0.4), (1340, 0.25)]
    clang = env(mix(*[tone(0.4, f) * a for f, a in partials]), 0.0008, 9)
    knock = env(lowpass(noise(0.05), 3000), 0.0005, 15)
    return save("block", reverb(drive(mix(clang, knock), 2.0), 0.6, 0.2), 0.8)


def parry():
    """parade parfaite : tintement d'acier qui résonne + accord brillant"""
    ring = env(mix(tone(1.0, 1568), tone(1.0, 2349) * 0.5, tone(1.0, 3136) * 0.3), 0.001, 3)
    hit = env(lowpass(noise(0.04), 9000), 0.0005, 16) * 0.7
    shine = brass(0.8, [note("E5"), note("B5"), note("E6")], 0.01, 3.5, 6000) * 0.25
    return save("parry", reverb(mix(ring, hit, shine), 1.5, 0.35), 0.8)


def guard_break():
    """garde brisée : éclatement + accord qui s'effondre"""
    shatter = env(lowpass(noise(0.7), 8000), 0.0005, 5)
    d = 0.8
    fall = mix(*[env(tone(d, f, f * 0.55, "saw"), 0.002, 3) for f in (note("A4"), note("E5"), note("C5"))]) * 0.35
    return save("guard_break", reverb(mix(shatter, lowpass(fall, 3000)), 1.2, 0.3), 0.85)


def double_jump():
    """double saut : souffle vif qui monte + petite note"""
    air = sweep_lowpass(noise(0.3), 500, 5000)
    air *= np.sin(np.linspace(0, np.pi, len(air))) ** 1.5
    pip = env(tone(0.25, note("E5"), note("B5")), 0.005, 6) * 0.25
    return save("double_jump", reverb(mix(air, pip), 0.5, 0.2), 0.6)


def summon():
    """arrêt du temps : souffle inversé, coup de gong grave, puis silence qui sonne"""
    swell = reverse_swell(0.7, 7000) * 0.8
    gong_partials = [(55, 1.0), (82.5, 0.6), (131, 0.5), (196, 0.35), (277, 0.25)]
    gong = env(mix(*[tone(2.2, f, f * 0.995) * a for f, a in gong_partials]), 0.003, 2.2)
    stab = brass(1.6, [note("C2"), note("G2"), note("Eb3"), note("G3")], 0.005, 2.0, 1500) * 0.6
    x = np.concatenate([swell, drive(mix(gong, stab), 1.8)])
    return save("summon", reverb(x, 2.2, 0.4), 0.8)


def menace():
    """ゴゴゴ : grondement grave et pulsé, menaçant"""
    d = 2.4
    tt = t(d)
    drone = mix(tone(d, 41), tone(d, 41.6) * 0.8, tone(d, 61.7) * 0.5, lowpass(noise(d), 180) * 0.8)
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * 2.6 * tt) ** 2
    shape = np.minimum(1, tt / 0.4) * np.minimum(1, (d - tt) / 0.6)
    return save("menace", reverb(drive(drone * pulse * shape, 1.6), 1.5, 0.3), 0.8)


def coin():
    """argent : deux notes vives, façon jeu d'arcade"""
    a = env(tone(0.09, note("B5"), note("B5"), "square"), 0.002, 5) * 0.4
    b = env(tone(0.35, note("E6"), note("E6"), "square"), 0.002, 4) * 0.4
    return save("coin", reverb(lowpass(np.concatenate([a, b]), 7000), 0.5, 0.15), 0.55)


def chest():
    """coffre : roulement de tambour qui monte, puis accord de fanfare"""
    roll_d = 0.9
    tt = t(roll_d)
    hits = (np.sin(2 * np.pi * (10 + 14 * tt / roll_d) * tt) > 0.6).astype(float)
    roll = lowpass(noise(roll_d), 1800) * hits * np.linspace(0.3, 1, len(tt))
    fanfare = brass(1.2, [note("C4"), note("E4"), note("G4"), note("C5")], 0.01, 2.0, 4000)
    sparkle = env(mix(tone(1.0, note("C6"), note("G6")) * 0.2, tone(1.0, note("E6"), note("C7")) * 0.15), 0.01, 3)
    return save("chest", reverb(np.concatenate([roll * 0.6, mix(fanfare, sparkle)]), 1.3, 0.3), 0.75)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (punch_hit, heavy_hit, impact, whoosh, projectile, block, parry, guard_break, double_jump, summon,
              menace, coin, chest):
        p = f()
        print(p, os.path.getsize(p) // 1024, "Ko")
