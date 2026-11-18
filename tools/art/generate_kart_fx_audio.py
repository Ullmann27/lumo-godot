#!/usr/bin/env python3
"""Original Lumo-Kart driving sounds: layered engine, rail scrape, tyre squeal, surfaces.

Synthesised from scratch like tools/art/generate_kart_item_audio.py: no recordings, no samples.
Loops are built from circular FFT noise and whole numbers of periods, so they repeat without
a seam. Requires numpy and ffmpeg with libvorbis. Writes assets/audio/kart/fx/*.ogg and a
manifest. Run: python3 tools/art/generate_kart_fx_audio.py
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/kart/fx"
SR = 32000
SEED = 20261118
RNG = np.random.default_rng(SEED)
TAU = 2 * math.pi


def t_axis(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def band(x, low=None, high=None, order=4):
    """Soft FFT band mask; circular, so a loop stays seamless."""
    n = len(x)
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(f)
    if high:
        mask *= 1 / (1 + (f / high) ** order)
    if low:
        mask *= 1 / (1 + (low / np.maximum(f, 1)) ** order)
    y = np.fft.irfft(spectrum * mask, n)
    return y


def noise(n, low=None, high=None):
    y = band(RNG.normal(size=n), low, high)
    return y / (np.std(y) + 1e-9)


def env(t, attack, release):
    d = t[-1] if len(t) else 1
    a = np.minimum(t / max(attack, 1e-4), 1)
    r = np.clip((d - t) / max(release, 1e-4), 0, 1)
    return a * r


def periodic_mod(t, seconds, cycles, depth, phase=0.0):
    # Whole cycles per loop length keep the modulation seamless.
    return 1 + depth * np.sin(TAU * cycles * t / seconds + phase)


def engine_layer(f0, seconds, harmonics, brightness, load):
    """A small single-cylinder kart engine: firing pulses + intake/exhaust noise."""
    t = t_axis(seconds)
    f0 = round(f0 * seconds) / seconds
    tone = np.zeros_like(t)
    for n in range(1, harmonics + 1):
        weight = (1.0 / n ** brightness) * (1.25 if n % 2 else 0.8)
        # Tiny periodic phase wobble per harmonic: a living engine, still seamless.
        wobble = 0.35 * np.sin(TAU * (3 + n % 4) * t / seconds + n)
        tone += weight * np.sin(TAU * n * f0 * t + wobble)
    firing = 0.5 + 0.5 * np.sin(TAU * f0 * t) ** 8
    breath = noise(len(t), 250, 2600 + 1800 * load) * firing * (0.18 + 0.22 * load)
    rumble = noise(len(t), 30, 160) * 0.25
    sub = np.sin(TAU * f0 * 0.5 * t) * 0.35
    mix = tone + breath + rumble + sub
    if load > 0.5:
        mix = np.tanh(mix * 1.6)
    return mix


def engine_off(seconds):
    """Off-throttle: muffled, lower, with a few soft overrun crackles."""
    t = t_axis(seconds)
    body = band(engine_layer(104, seconds, 10, 1.4, 0.0), None, 900)
    crackle = np.zeros_like(t)
    for when in RNG.uniform(0.0, seconds - 0.05, 7):
        i = int(when * SR)
        k = t_axis(0.03)
        burst = noise(len(k), 400, 3500) * np.exp(-k * 140) * RNG.uniform(0.6, 1.4)
        crackle[i:i + len(k)] += burst[: len(crackle[i:i + len(k)])]
    return body / (np.std(body) + 1e-9) + crackle * 0.9


def scrape(seconds):
    """Metal grinding along a rail: gritty bright noise and squealing partials."""
    t = t_axis(seconds)
    grit = noise(len(t), 1800, 7500)
    jitter = np.abs(noise(len(t), 6, 70))
    grit *= 0.55 + 0.75 * jitter
    partials = sum(
        np.sin(TAU * (round(f * seconds) / seconds) * t + 0.6 * np.sin(TAU * 5 * t / seconds * (i + 1)))
        * a
        for i, (f, a) in enumerate(((1830, 0.35), (2710, 0.28), (4120, 0.2), (5290, 0.12)))
    )
    partials *= 0.6 + 0.4 * np.abs(noise(len(t), 3, 25))
    rumble = noise(len(t), 160, 700) * 0.55
    return grit * 0.8 + partials + rumble


def squeal(seconds):
    t = t_axis(seconds)
    f = round(1240 * seconds) / seconds
    vib = 18 * np.sin(TAU * 7 * t)
    phase = TAU * np.cumsum(f + vib) / SR
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    tone *= periodic_mod(t, seconds, 3, 0.25)
    hiss = noise(len(t), 900, 2200) * 0.35
    return tone * 0.8 + hiss


def grains(seconds, per_second, low, high, decay, rumble_band):
    t = t_axis(seconds)
    out = np.zeros_like(t)
    n = len(t)
    k = t_axis(0.012)
    for when in RNG.uniform(0, seconds, int(per_second * seconds)):
        i = int(when * SR)
        click = RNG.normal(size=len(k)) * np.exp(-k * decay) * RNG.uniform(0.3, 1.0)
        idx = (np.arange(len(k)) + i) % n  # wrap: circular, seamless
        out[idx] += click
    out = band(out, low, high)
    out /= np.std(out) + 1e-9
    rumble = noise(n, rumble_band[0], rumble_band[1]) * 0.6
    return out + rumble


def turbo(seconds):
    t = t_axis(seconds)
    roar = noise(len(t), 140, 2400) * periodic_mod(t, seconds, 9, 0.2)
    whine_f = round(880 * seconds) / seconds
    whine = np.sin(TAU * whine_f * t) * 0.25 + np.sin(TAU * whine_f * 1.5 * t) * 0.1
    return roar + whine


def wind(seconds):
    t = t_axis(seconds)
    w = noise(len(t), 180, 1300) * periodic_mod(t, seconds, 2, 0.35)
    w += noise(len(t), 1500, 4000) * 0.2 * periodic_mod(t, seconds, 3, 0.5, 1.0)
    return w


def rail_hit(soft=False):
    t = t_axis(0.38 if soft else 0.75)
    thud = np.sin(TAU * 92 * t * (1 - 0.25 * t)) * np.exp(-t * (26 if soft else 16)) * 1.1
    partials = [(523, 7), (1187, 9), (1876, 12), (2643, 15), (3511, 18)]
    clang = sum(np.sin(TAU * f * t + 0.4 * np.sin(TAU * 3 * t)) * np.exp(-t * d * (1.6 if soft else 1.0)) / (i + 1) ** 0.4
                for i, (f, d) in enumerate(partials))
    crash = noise(len(t), 900, 9000) * np.exp(-t * (40 if soft else 22)) * 0.9
    return thud + clang * (0.45 if soft else 0.75) + crash


def backfire():
    t = t_axis(0.26)
    pop = noise(len(t), 120, 1800) * np.exp(-t * 30)
    thump = np.sin(TAU * 78 * t) * np.exp(-t * 22) * 1.2
    return pop * 0.8 + thump


def land_thump():
    t = t_axis(0.45)
    thud = np.sin(TAU * 64 * t * (1 - 0.3 * t)) * np.exp(-t * 11) * 1.3
    rattle = noise(len(t), 600, 5200) * np.exp(-t * 20) * 0.5
    spring = np.sin(TAU * 310 * t) * np.exp(-t * 14) * 0.25 * np.sin(TAU * 9 * t)
    return thud + rattle + spring


def confetti():
    t = t_axis(1.0)
    pop = noise(len(t), 300, 6000) * np.exp(-t * 45) * 1.2
    bells = np.zeros_like(t)
    for i, f in enumerate((1318, 1568, 1976, 2349, 2637)):
        d = 0.08 + i * 0.07
        k = np.maximum(t - d, 0)
        bells += (t > d) * np.sin(TAU * f * k + 1.2 * np.exp(-k * 9) * np.sin(TAU * f * 2 * k)) * np.exp(-k * 6) * 0.35
    return pop + bells


def whoosh():
    t = t_axis(0.65)
    sweep = noise(len(t), 300, 5000)
    shape = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 2
    return sweep * shape


def rocket_fly(seconds):
    """Sternraketen-Flug: helles Fauchen + weicher Pfeifton, nahtlos als Schleife."""
    t = t_axis(seconds)
    hiss = noise(len(t), 900, 7000) * periodic_mod(t, seconds, 12, 0.18)
    rumble = noise(len(t), 70, 420) * 0.55 * periodic_mod(t, seconds, 5, 0.25, 0.7)
    whistle_f = round(1320 * seconds) / seconds
    whistle = np.sin(TAU * whistle_f * t + 0.6 * np.sin(TAU * 6 / seconds * t)) * 0.22
    return hiss + rumble + whistle


# name -> (builder, loop)
SOUNDS = {
    "engine_low": (lambda: engine_layer(62, 1.0, 14, 1.15, 1.0), True),
    "engine_mid": (lambda: engine_layer(118, 1.0, 12, 1.05, 1.0), True),
    "engine_high": (lambda: engine_layer(196, 1.0, 10, 0.95, 1.0), True),
    "engine_off": (lambda: engine_off(1.0), True),
    "scrape": (lambda: scrape(1.2), True),
    "squeal": (lambda: squeal(1.0), True),
    "gravel": (lambda: grains(1.0, 900, 700, 5200, 900, (60, 400)), True),
    "snow": (lambda: grains(1.0, 650, 250, 2600, 500, (40, 260)), True),
    "turbo": (lambda: turbo(1.0), True),
    "wind": (lambda: wind(2.0), True),
    "rail_hit": (lambda: rail_hit(False), False),
    "rail_hit_soft": (lambda: rail_hit(True), False),
    "backfire": (backfire, False),
    "land_thump": (land_thump, False),
    "confetti": (confetti, False),
    "whoosh": (whoosh, False),
    # Appended last: the earlier cues keep their random stream (identical files).
    "rocket_fly": (lambda: rocket_fly(1.0), True),
}


def export(name, audio, loop):
    audio = audio - audio.mean()
    if not loop:
        fade = min(int(0.006 * SR), len(audio) // 4)
        audio[:fade] *= np.linspace(0, 1, fade)
        audio[-fade:] *= np.linspace(1, 0, fade)
    audio = np.tanh(audio / (np.max(np.abs(audio)) + 1e-9) * 1.4)
    audio *= 0.707 / (np.max(np.abs(audio)) + 1e-9)
    seam = float(abs(audio[0] - audio[-1])) if loop else None
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "cue.wav"
        with wave.open(str(wav), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(np.round(audio * 32767).astype("<i2").tobytes())
        dest = OUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1",
                        "-metadata", "artist=Lumo project original synthesis", "-metadata", "title=" + name, str(dest)], check=True)
    entry = {"file": dest.name, "seconds": round(len(audio) / SR, 4), "loop": loop, "bytes": dest.stat().st_size,
             "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(), "description": "Original synthesized " + name}
    if seam is not None:
        entry["seam_delta"] = round(seam, 5)
    return entry


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, (builder, loop) in SOUNDS.items():
        manifest.append(export(name, builder(), loop))
    (OUT / "manifest.json").write_text(json.dumps({"generator": "tools/art/generate_kart_fx_audio.py", "seed": SEED,
                                                   "sample_rate": SR, "channels": 1,
                                                   "original_samples_only": True, "assets": manifest}, indent=2) + "\n")
    print(json.dumps({"files": len(manifest), "total_bytes": sum(m["bytes"] for m in manifest)}))


if __name__ == "__main__":
    main()
