"""Umweltklänge der Signatur-Strecken (Vulkanexpress, Wolkensturm, Kristallflut).

Alles wird hier synthetisiert: gefiltertes Rauschen, Sinus-Teiltöne, Hüllkurven. Keine
Aufnahmen, keine Samples, kein Netz. Schleifen werden im Frequenzraum gefiltert und sind
damit nahtlos (zirkulär). Benötigt NumPy und FFmpeg.

Aufruf: python3 tools/art/compose_signature_ambience.py [vulkanexpress|wolkensturm|kristallflut ...]
Ausgabe: assets/audio/kart/signature/<strecke>/<klang>.ogg und manifest.json im Ordner.
"""
import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2] / "assets/audio/kart/signature"
SR = 32000


def band_noise(rng, seconds, low, high, tilt=0.0):
    """Zirkulär gefiltertes Rauschen (nahtlose Schleife), Band low..high Hz."""
    n = int(SR * seconds)
    spectrum = np.fft.rfft(rng.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    shape = 1.0 / (1.0 + ((f / max(high, 1.0)) ** 4)) * (1.0 - 1.0 / (1.0 + ((f / max(low, 1.0)) ** 4)))
    if tilt:
        shape *= (np.maximum(f, 20.0) / 1000.0) ** tilt
    out = np.fft.irfft(spectrum * shape, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def env_loop(seconds, cycles, depth, phase=0.0):
    t = np.arange(int(SR * seconds)) / SR
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / seconds + phase))


def tone(freq, seconds, attack=0.02, release=0.2, vibrato=0.0):
    t = np.arange(int(SR * seconds)) / SR
    phase = 2 * np.pi * freq * t + vibrato * np.sin(2 * np.pi * 5.2 * t)
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, np.maximum(0.0, seconds - t) / release)
    return np.sin(phase) * env


def place(mix, sound, at, gain=1.0, loop=True):
    start = int(at * SR) % len(mix)
    n = min(len(sound), len(mix) - start)
    mix[start:start + n] += sound[:n] * gain
    if loop and n < len(sound):
        mix[:len(sound) - n] += sound[n:] * gain


def stereo(mono, width=0.15, rng=None):
    delay = int(SR * 0.011)
    right = np.roll(mono, delay)
    left = mono * (1 - width) + right * width
    return np.stack([left, mono * width + right * (1 - width)], axis=1)


def normalise(x, peak=0.7):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


# ------------------------------------------------------------------ Vulkanexpress


def surf(rng):
    s = 12.0
    wash = band_noise(rng, s, 120, 2400) * env_loop(s, 2, 0.8)
    fizz = band_noise(rng, s, 2500, 9000) * env_loop(s, 2, 0.95, 1.2) * 0.35
    return stereo(normalise(wash + fizz, 0.6))


def lava(rng):
    s = 10.0
    rumble = band_noise(rng, s, 25, 140) * env_loop(s, 3, 0.35)
    mix = rumble * 0.8
    for k in range(18):
        f = rng.uniform(55, 140)
        pop = tone(f, 0.18, 0.004, 0.15) * np.exp(-np.arange(int(SR * 0.18)) / SR * 18)
        place(mix, pop, rng.uniform(0, s), rng.uniform(0.25, 0.5))
    crackle = band_noise(rng, s, 3000, 9000)
    gate = (rng.random(len(crackle)) > 0.9993).astype(float)
    gate = np.convolve(gate, np.exp(-np.arange(200) / 30.0), mode="same")
    mix += crackle * gate * 0.5
    return stereo(normalise(mix, 0.6))


def cave(rng):
    s = 12.0
    drone = band_noise(rng, s, 40, 300) * 0.6
    mix = drone.copy()
    for k in range(9):
        at = rng.uniform(0, s)
        f = rng.uniform(900, 1700)
        drip = tone(f, 0.12, 0.002, 0.1) * np.exp(-np.arange(int(SR * 0.12)) / SR * 40)
        for echo in range(4):
            place(mix, drip, at + echo * 0.21, 0.4 * (0.5 ** echo))
    return stereo(normalise(mix, 0.55), 0.35)


def steam(rng):
    s = 8.0
    hiss = band_noise(rng, s, 1800, 9000) * env_loop(s, 4, 0.7)
    body = band_noise(rng, s, 300, 1500) * env_loop(s, 4, 0.7) * 0.3
    return stereo(normalise(hiss + body, 0.6))


def rumble(rng):
    s = 3.2
    t = np.arange(int(SR * s)) / SR
    env = np.minimum(1.0, t / 1.4) * np.minimum(1.0, (s - t) / 0.8)
    low = band_noise(rng, s, 20, 110) * env
    wobble = tone(38, s, 0.6, 0.8) * 0.4 * env
    return stereo(normalise(low + wobble, 0.8))


def eruption(rng):
    s = 4.5
    t = np.arange(int(SR * s)) / SR
    boom = np.sin(2 * np.pi * (42 * t + 30 * (1 - np.exp(-t * 6)))) * np.exp(-t * 2.2)
    burst = band_noise(rng, s, 60, 1800) * np.exp(-t * 1.3)
    crackle = band_noise(rng, s, 2500, 8000) * (rng.random(len(t)) > 0.995) * np.exp(-t * 0.8)
    crackle = np.convolve(crackle, np.ones(60) / 6.0, mode="same")
    return stereo(normalise(boom * 0.9 + burst * 0.6 + crackle * 0.5, 0.85), 0.3)


def whistle(rng):
    s = 1.7
    chord = sum(tone(f, s, 0.06, 0.35, vibrato=0.6) for f in (523.0, 659.0, 784.0)) / 3.0
    breath = band_noise(rng, s, 1500, 6000) * 0.12
    t = np.arange(int(SR * s)) / SR
    env = np.minimum(1.0, t / 0.08) * np.minimum(1.0, (s - t) / 0.4)
    return stereo(normalise((chord + breath) * env, 0.7))


# ------------------------------------------------------------------ Wolkensturm


def wind(rng):
    s = 12.0
    gust = env_loop(s, 3, 0.75) * env_loop(s, 7, 0.3, 0.8)
    body = band_noise(rng, s, 150, 1400, tilt=-0.4) * gust
    whistle = band_noise(rng, s, 1800, 2600) * env_loop(s, 3, 0.9, 2.0) * 0.18
    return stereo(normalise(body + whistle, 0.6), 0.4)


def city(rng):
    s = 12.0
    hum = band_noise(rng, s, 60, 500) * 0.6
    mix = hum.copy()
    for k in range(5):
        at = rng.uniform(0, s)
        f = rng.choice([392.0, 440.0, 523.0])
        chime = (tone(f, 0.5, 0.01, 0.4) + 0.5 * tone(f * 1.5, 0.5, 0.01, 0.4)) * 0.25
        place(mix, chime, at, 0.5)
    whoosh = band_noise(rng, s, 300, 3000) * env_loop(s, 2, 0.95, 0.4) * 0.25
    return stereo(normalise(mix + whoosh, 0.5), 0.3)


def hum(rng):
    s = 6.0
    t = np.arange(int(SR * s)) / SR
    tone_sum = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((100, .5), (200, .3), (300, .15), (400, .08)))
    buzz = band_noise(rng, s, 2000, 6000) * 0.05
    shimmer = 0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * t)
    return stereo(normalise((tone_sum + buzz) * shimmer, 0.45))


def thunder(rng):
    s = 5.5
    t = np.arange(int(SR * s)) / SR
    crack = band_noise(rng, s, 400, 6000) * np.exp(-t * 9.0)
    roll = band_noise(rng, s, 25, 260) * (np.minimum(1.0, t / 0.25) * np.exp(-t * 0.75))
    roll *= 0.75 + 0.25 * np.sin(2 * np.pi * 1.3 * t + 0.5) * np.sin(2 * np.pi * 0.7 * t)
    return stereo(normalise(crack * 0.5 + roll, 0.85), 0.35)


# ------------------------------------------------------------------ Kristallflut


def harbour(rng):
    s = 12.0
    lap = band_noise(rng, s, 80, 900) * env_loop(s, 4, 0.6) * 0.7
    mix = lap.copy()
    for k in range(4):
        creak = tone(rng.uniform(140, 220), 0.6, 0.1, 0.3, vibrato=2.0) * 0.18
        place(mix, creak, rng.uniform(0, s), 0.6)
    for k in range(3):
        bell = tone(rng.choice([880.0, 988.0]), 1.2, 0.005, 1.0) * 0.12
        place(mix, bell, rng.uniform(0, s), 1.0)
    return stereo(normalise(mix, 0.55), 0.3)


def waterfall(rng):
    s = 10.0
    roar = band_noise(rng, s, 200, 7000, tilt=-0.3)
    rumble = band_noise(rng, s, 30, 200) * 0.5
    return stereo(normalise(roar + rumble, 0.62), 0.45)


def underwater(rng):
    s = 12.0
    drone = band_noise(rng, s, 30, 350) * 0.8
    mix = drone.copy()
    for k in range(14):
        f = rng.uniform(500, 1400)
        t = np.arange(int(SR * 0.09)) / SR
        bubble = np.sin(2 * np.pi * (f * t + f * 1.5 * t * t)) * np.exp(-t * 35)
        place(mix, bubble, rng.uniform(0, s), rng.uniform(0.15, 0.35))
    for k in range(2):
        song = tone(rng.uniform(180, 260), 2.0, 0.5, 0.8, vibrato=4.0) * 0.12
        place(mix, song, rng.uniform(0, s), 1.0)
    return stereo(normalise(mix, 0.5), 0.4)


def grotto(rng):
    s = 12.0
    mix = band_noise(rng, s, 40, 250) * 0.4
    for k in range(8):
        f = rng.choice([1046.5, 1318.5, 1568.0, 2093.0])
        chime = tone(f, 1.4, 0.004, 1.2) * np.exp(-np.arange(int(SR * 1.4)) / SR * 2.5)
        at = rng.uniform(0, s)
        for echo in range(3):
            place(mix, chime, at + echo * 0.33, 0.22 * (0.5 ** echo))
    return stereo(normalise(mix, 0.5), 0.4)


def fountain_loop(rng):
    s = 8.0
    splash = band_noise(rng, s, 600, 8000) * env_loop(s, 4, 0.5)
    return stereo(normalise(splash, 0.5), 0.35)


def tide(rng):
    s = 4.0
    t = np.arange(int(SR * s)) / SR
    swell = band_noise(rng, s, 60, 1200) * np.sin(np.pi * t / s) ** 2
    rise = tone(220, s, 1.0, 1.0) * 0.15 + tone(330, s, 1.5, 1.0) * 0.1
    return stereo(normalise(swell + rise, 0.7), 0.4)


TRACKS = {
    "vulkanexpress": {
        "surf": (surf, True), "lava": (lava, True), "cave": (cave, True), "steam": (steam, True),
        "rumble": (rumble, False), "eruption": (eruption, False), "whistle": (whistle, False),
    },
    "wolkensturm": {
        "wind": (wind, True), "city": (city, True), "hum": (hum, True), "thunder": (thunder, False),
    },
    "kristallflut": {
        "harbour": (harbour, True), "waterfall": (waterfall, True), "surf": (surf, True),
        "underwater": (underwater, True), "grotto": (grotto, True), "fountain": (fountain_loop, True),
        "tide": (tide, False),
    },
}


def write(folder, name, audio, loop):
    out = ROOT / folder
    out.mkdir(parents=True, exist_ok=True)
    path = out / (name + ".ogg")
    pcm = np.clip(audio, -1.0, 1.0).astype("<f4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2",
                    "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "2", "-fflags", "+bitexact",
                    "-flags:a", "+bitexact", str(path)], input=pcm.tobytes(), check=True)
    return {"file": name + ".ogg", "seconds": round(len(audio) / SR, 3), "loop": loop,
            "peak": round(float(np.max(np.abs(audio))), 3), "bytes": path.stat().st_size,
            "generator": "tools/art/compose_signature_ambience.py",
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("tracks", nargs="*")
    args = cli.parse_args()
    for folder in args.tracks or TRACKS:
        rng = np.random.default_rng(int.from_bytes(hashlib.sha256(folder.encode()).digest()[:4], "little"))
        manifest = []
        for name, (make, loop) in TRACKS[folder].items():
            manifest.append(write(folder, name, make(rng), loop))
            print(folder, name, flush=True)
        (ROOT / folder / "manifest.json").write_text(json.dumps(
            {"track": folder, "license": "Eigene Synthese für Lumo, frei nutzbar", "assets": manifest},
            indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
