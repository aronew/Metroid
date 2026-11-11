"""Synthesise the slice's sound effects.

No audio was supplied, so these are placeholders made from filtered noise and
a few sine partials: quiet, dry and low, to sit under real sound design later.
Every sound the game asks for by name (see game/audio/sfx.gd) is written here.

    python3 tools/build_sfx.py   ->  assets/audio/sfx/*.wav
"""
import os, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "audio", "sfx")
SR = 44100
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec, lo, hi):
    """Band-limited noise, by zeroing the spectrum outside lo..hi Hz."""
    n = int(SR * sec)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    edge = np.clip((f - lo) / max(lo * 0.3, 20), 0, 1) * np.clip((hi - f) / max(hi * 0.3, 20), 0, 1)
    out = np.fft.irfft(spec * edge, n)
    return out / (np.abs(out).max() + 1e-9)


def env(sec, attack, decay_power=2.0):
    x = t(sec) / sec
    a = np.clip(x / max(attack / sec, 1e-4), 0, 1)
    return a * (1 - x) ** decay_power


def sweep(sec, f0, f1):
    x = t(sec)
    f = f0 * (f1 / f0) ** (x / sec)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def save(name, sig, gain=0.8):
    sig = np.asarray(sig, np.float64)
    sig = sig / (np.abs(sig).max() + 1e-9) * gain
    fade = min(200, len(sig) // 4)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(sig, before):
    return np.concatenate([np.zeros(int(SR * before)), sig])


os.makedirs(OUT, exist_ok=True)

# --- Cowl ---------------------------------------------------------------
save("step", noise(0.05, 150, 1400) * env(0.05, 0.002, 3), 0.35)
save("jump", mix(noise(0.13, 300, 2600) * env(0.13, 0.01, 2) * 0.7, sweep(0.11, 170, 330) * env(0.11, 0.005, 2) * 0.5), 0.5)
save("land", mix(sweep(0.11, 120, 55) * env(0.11, 0.002, 2), noise(0.07, 100, 900) * env(0.07, 0.002, 3) * 0.6), 0.55)
save("land_heavy", mix(sweep(0.22, 110, 38) * env(0.22, 0.002, 2), noise(0.14, 60, 700) * env(0.14, 0.002, 2.5) * 0.8), 0.8)
save("dodge", noise(0.22, 500, 5000) * env(0.22, 0.03, 1.6) * (0.6 + 0.4 * sweep(0.22, 3, 9)), 0.5)
save("swing", noise(0.15, 900, 7000) * env(0.15, 0.025, 2.2), 0.6)
save("swing_heavy", mix(noise(0.22, 500, 5000) * env(0.22, 0.05, 2.0), sweep(0.2, 260, 120) * env(0.2, 0.03, 2) * 0.35), 0.72)
save("hit", mix(sweep(0.09, 190, 70) * env(0.09, 0.001, 2.2), noise(0.05, 1500, 8000) * env(0.05, 0.001, 3) * 0.7,
                np.sin(2 * np.pi * 2350 * t(0.12)) * env(0.12, 0.001, 4) * 0.25), 0.8)
save("hurt", mix(sweep(0.26, 300, 90) * env(0.26, 0.004, 1.6), noise(0.12, 200, 2500) * env(0.12, 0.002, 2.5) * 0.7), 0.75)
save("rustle", noise(0.5, 1200, 6000) * env(0.5, 0.2, 1.2) * (0.5 + 0.5 * np.abs(sweep(0.5, 5, 11))), 0.3)
save("pickup", mix(np.sin(2 * np.pi * 1320 * t(0.8)) * env(0.8, 0.002, 3),
                   np.sin(2 * np.pi * 1987 * t(0.8)) * env(0.8, 0.002, 4) * 0.6,
                   np.sin(2 * np.pi * 3110 * t(0.5)) * env(0.5, 0.002, 5) * 0.35,
                   noise(0.06, 3000, 9000) * env(0.06, 0.001, 3) * 0.5), 0.6)

# --- the house ------------------------------------------------------------
save("vine_cut", mix(noise(0.2, 400, 4500) * env(0.2, 0.004, 2.4), pad(noise(0.16, 200, 1800) * env(0.16, 0.01, 2), 0.05) * 0.6), 0.7)
save("candle", noise(0.35, 200, 1800) * env(0.35, 0.08, 2) * 0.8, 0.35)
save("lift_start", mix(sweep(0.16, 90, 60) * env(0.16, 0.002, 2), noise(0.5, 80, 600) * env(0.5, 0.1, 1.0) * 0.5,
                       pad(np.sin(2 * np.pi * 640 * t(0.06)) * env(0.06, 0.001, 3) * 0.4, 0.02)), 0.6)
save("lift_stop", mix(sweep(0.2, 100, 45) * env(0.2, 0.001, 2), noise(0.08, 300, 3000) * env(0.08, 0.001, 3) * 0.5), 0.7)
save("locked", mix(sweep(0.07, 140, 90) * env(0.07, 0.001, 3), pad(sweep(0.07, 130, 85) * env(0.07, 0.001, 3), 0.12) * 0.8), 0.5)
save("door_heavy", mix(noise(1.0, 40, 260) * env(1.0, 0.15, 1.2), sweep(1.0, 55, 42) * env(1.0, 0.1, 1.4) * 0.8,
                       pad(noise(0.1, 200, 2000) * env(0.1, 0.001, 3), 0.85) * 0.5), 0.8)
save("secret", mix(np.sin(2 * np.pi * 660 * t(0.9)) * env(0.9, 0.01, 3), pad(np.sin(2 * np.pi * 990 * t(0.8)) * env(0.8, 0.01, 3), 0.12) * 0.7), 0.35)

# --- creatures ------------------------------------------------------------
save("creature_alert", noise(0.3, 1500, 6000) * env(0.3, 0.02, 1.5) * (np.sign(sweep(0.3, 38, 60)) * 0.5 + 0.5), 0.45)
save("creature_die", mix(noise(0.3, 150, 2200) * env(0.3, 0.005, 2), sweep(0.25, 420, 80) * env(0.25, 0.005, 2) * 0.5), 0.7)

# --- ambience: the house holding its breath (a seamless 14 s loop) ---------
sec = 14.0
x = t(sec)
drone = (np.sin(2 * np.pi * 46 * x) * 0.6 + np.sin(2 * np.pi * 69.2 * x + 1.0) * 0.3 + np.sin(2 * np.pi * 92.5 * x) * 0.15)
drone *= 0.7 + 0.3 * np.sin(2 * np.pi * x / sec * 2)
air = noise(sec, 120, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * x / sec * 3 + 1.3)) * 0.35
amb = drone + air
n = int(SR * 1.5)                                 # crossfade the tail into the head
amb[:n] = amb[:n] * np.linspace(0, 1, n) + amb[-n:] * np.linspace(1, 0, n)
amb = amb[:-n]
amb = amb / np.abs(amb).max() * 0.5
with wave.open(os.path.join(OUT, "ambience.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((amb * 32767).astype("<i2").tobytes())
print("wrote", len(os.listdir(OUT)), "sounds")
