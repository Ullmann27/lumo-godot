#!/usr/bin/env python3
"""Original Lumo-Kart item cues (Sternraketen, Zielerfassung, Sternenschild, Item-Rad).

Synthesised from scratch like tools/art/generate_kart_audio.py: no recordings, no samples.
Requires numpy and ffmpeg with libvorbis (band filters are done in the FFT domain). Writes assets/audio/kart/items/*.ogg and
a manifest. Run: python3 tools/art/generate_kart_item_audio.py
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
OUT = ROOT / "assets/audio/kart/items"
SR = 32000
RNG = np.random.default_rng(20261118)
TAU = 2 * math.pi


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(n, low=None, high=None):
    """White noise band-limited with a soft FFT mask (no scipy needed)."""
    x = RNG.normal(size=n)
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(f)
    if high:
        mask *= 1 / (1 + (f / high) ** 4)
    if low:
        mask *= 1 / (1 + (low / np.maximum(f, 1)) ** 4)
    y = np.fft.irfft(spectrum * mask, n)
    return y / (np.std(y) + 1e-9)


def sweep(t, f0, f1, curve=1.0):
    d = t[-1] if len(t) else 1
    f = f0 + (f1 - f0) * (t / d) ** curve
    return np.sin(TAU * np.cumsum(f) / SR)


def env(t, attack, release, hold=None):
    d = t[-1] if len(t) else 1
    a = np.minimum(t / max(attack, 1e-4), 1)
    r = np.clip((d - t) / max(release, 1e-4), 0, 1)
    return a * r


def bell(t, f, decay):
    return np.sin(TAU * f * t + 1.4 * np.exp(-t * 9) * np.sin(TAU * f * 2 * t)) * np.exp(-t * decay)


def cue(name):
    if name == "rocket_arm":
        # Pods click open, then a soft ignition whoosh rising into a hum.
        t = t_axis(0.75)
        click = np.zeros_like(t)
        for when in (0.0, 0.07):
            i = int(when * SR)
            k = t_axis(0.03)
            click[i:i + len(k)] += np.sin(TAU * 2400 * k) * np.exp(-k * 160) * 0.8
        whoosh = noise(len(t), 300, 3500) * env(t, 0.25, 0.3) * 0.5 * (t / t[-1]) ** 0.6
        hum = sweep(t, 90, 180, 0.8) * env(t, 0.3, 0.25) * 0.35
        return click + whoosh + hum
    if name == "lock_beep":
        t = t_axis(0.075)
        return (np.sin(TAU * 1180 * t) + 0.3 * np.sin(TAU * 2360 * t)) * env(t, 0.004, 0.03) * 0.75
    if name == "lock_on":
        # Solid two-tone "erfasst" chirp.
        t = t_axis(0.42)
        tone = np.where(t < 0.16, np.sin(TAU * 1480 * t), np.sin(TAU * 1975 * t))
        return tone * env(t, 0.005, 0.08) * 0.7 + bell(t, 2960, 9) * 0.25
    if name == "rocket_launch":
        # Thump + roaring whoosh that falls away; two layered rockets (L/R) slightly offset.
        t = t_axis(1.1)
        thump = np.sin(TAU * (55 * t + 30 * (1 - np.exp(-t * 30)))) * np.exp(-t * 14) * 0.9
        roar = noise(len(t), 120, 5200) * np.exp(-t * 2.8) * env(t, 0.01, 0.2) * 0.7
        hiss = noise(len(t), 2500, 9000) * np.exp(-t * 5) * 0.25
        rise = sweep(t, 420, 160, 0.6) * np.exp(-t * 3.5) * 0.25
        mono = thump + roar + hiss + rise
        late = np.roll(mono, int(0.045 * SR)) * 0.75
        return np.stack([mono, late], axis=1)
    if name == "rocket_hit":
        # A padded, downward-pitched air drum and a short cloud of low debris.
        t = t_axis(.58)
        body = np.sin(TAU * (53*t + 3.4*(1-np.exp(-22*t)))) * np.exp(-t*10)
        puff = noise(len(t), 130, 1020) * np.exp(-t*15)
        flap = np.sin(TAU*106*t) * np.exp(-t*9) * (.5+.5*np.cos(TAU*12*t))
        return (.72*body + .42*puff + .16*flap) * env(t,.013,.1)
    if name == "magnet_pull":
        # Two resonating tines approach the same pitch, then release together.
        t = t_axis(.49)
        tines = sum(np.sin(TAU*np.cumsum(276+offset*np.exp(-8*t))/SR) for offset in (-88,119))
        catch = np.sin(TAU*552*t) * np.exp(-16*np.abs(t-.19))
        return (tines*.32 + .19*catch) * env(t,.065,.24)
    if name == "shield_up":
        t = t_axis(0.8)
        shimmer = sum(np.sin(TAU * f * t + i) for i, f in enumerate((523, 784, 1046, 1318))) / 4
        return (shimmer * (0.4 + 0.6 * t / t[-1]) + sweep(t, 300, 1200, 0.7) * 0.25) * env(t, 0.05, 0.3) * 0.7
    if name == "shield_ping":
        # Metallic-glassy ping when a rocket bounces off the dome.
        t = t_axis(0.7)
        return (bell(t, 1760, 7) * 0.6 + bell(t, 2637, 9) * 0.35 + noise(len(t), 3000, 9000) * np.exp(-t * 40) * 0.3)
    if name == "missile_warning":
        # Two-tone alert, 2 pulses per cue (repeats at ~1.6 Hz in game, well below 3 Hz).
        t = t_axis(0.5)
        tone = np.where((t % 0.25) < 0.12, np.sin(TAU * 880 * t), np.sin(TAU * 660 * t))
        gate = ((t % 0.25) < 0.2).astype(float)
        return tone * gate * env(t, 0.005, 0.05) * 0.6
    if name == "roulette_tick":
        # Sternenkompass (19.11.2026): weicher Glas-Ton je Symbolwechsel; das Rennen
        # spielt ihn mit fallender Tonhöhe (Dur-Pentatonik abwärts), leise und kurz.
        t = t_axis(0.11)
        attack = np.minimum(t / 0.004, 1)
        glass = np.sin(TAU * 1568 * t) * np.exp(-t * 38) + 0.45 * np.sin(TAU * 2349 * t) * np.exp(-t * 55)
        return glass * attack * 0.42
    if name == "roulette_done":
        # Sternenkompass-Abschluss: warmes C-Dur-Arpeggio mit leisem Glanz, kein Knall.
        t = t_axis(0.95)
        notes = ((0, 523), (0.06, 659), (0.12, 784), (0.2, 1046))
        chord = sum(bell(np.maximum(t - d, 0), f, 4.5) * (t > d) for d, f in notes) * 0.42
        shimmer = np.sin(TAU * 2093 * t) * np.exp(-np.maximum(t - 0.2, 0) * 6) * (t > 0.2) * 0.12
        return chord + shimmer
    raise ValueError(name)


CUES = ["rocket_arm", "lock_beep", "lock_on", "rocket_launch", "rocket_hit", "magnet_pull", "shield_up", "shield_ping", "missile_warning", "roulette_tick", "roulette_done"]


def export(name, audio):
    if audio.ndim == 1:
        audio = np.stack([audio, audio], axis=1)
    audio = audio - audio.mean(axis=0)
    fade = min(int(0.008 * SR), len(audio) // 4)
    audio[:fade] *= np.linspace(0, 1, fade)[:, None]
    audio[-fade:] *= np.linspace(1, 0, fade)[:, None]
    audio = np.tanh(audio * 1.1)
    peak = np.max(np.abs(audio))
    if peak:
        audio *= 0.707 / peak
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "cue.wav"
        with wave.open(str(wav), "wb") as handle:
            handle.setnchannels(2)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(np.round(audio * 32767).astype("<i2").tobytes())
        dest = OUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1",
                        "-metadata", "artist=Lumo project original synthesis", "-metadata", "title=" + name, str(dest)], check=True)
    return {"file": dest.name, "seconds": round(len(audio) / SR, 4), "bytes": dest.stat().st_size,
            "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(), "description": "Original synthesized " + name + " cue"}


def main():
    import sys
    OUT.mkdir(parents=True, exist_ok=True)
    only = [arg.split("=", 1)[1].split(",") for arg in sys.argv[1:] if arg.startswith("--only=")]
    if only:
        # Nur einzelne Töne neu erzeugen (z. B. --only=roulette_tick,roulette_done), die
        # übrigen Dateien und ihre Manifest-Einträge bleiben unverändert.
        previous = json.loads((OUT / "manifest.json").read_text())
        by_file = {row["file"]: row for row in previous["assets"]}
        for name in only[0]:
            by_file[name + ".ogg"] = export(name, cue(name))
        manifest = [by_file[name + ".ogg"] for name in CUES if name + ".ogg" in by_file]
    else:
        manifest = [export(name, cue(name)) for name in CUES]
    (OUT / "manifest.json").write_text(json.dumps({"generator": "tools/art/generate_kart_item_audio.py", "seed": 20261118,
                                                   "original_samples_only": True, "assets": manifest}, indent=2) + "\n")
    print(json.dumps({"files": len(manifest), "total_bytes": sum(m["bytes"] for m in manifest)}))


if __name__ == "__main__":
    main()
