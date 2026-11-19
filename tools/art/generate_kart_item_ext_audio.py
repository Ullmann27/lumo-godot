#!/usr/bin/env python3
"""Original Lumo-Kart cues for the extended items (Donnerstern, Frostkristall, Feuermeteor,
Sternenfestung, Wirbelwind, Schwerkraft-Welle, Sternen-Duplikat, Turbo-Kette XL,
Lichtbogen-Falle, Zeitblüte) plus a soft warning tone.

Synthesised from scratch (numpy + ffmpeg/libvorbis), no recordings, no samples. Reuses the
helpers and the export pipeline of tools/art/generate_kart_item_audio.py so loudness and format
match the existing item cues. Child-friendly: no harsh cracks, peaks at -3 dBFS, short.
Writes assets/audio/kart/items/<name>.ogg and assets/audio/kart/items/ext_manifest.json.
Run: python3 tools/art/generate_kart_item_ext_audio.py
"""
from pathlib import Path
import importlib.util
import json
import math

import numpy as np

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("base_item_audio", HERE / "generate_kart_item_audio.py")
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)
base.RNG = np.random.default_rng(20261119)

SR = base.SR
TAU = 2 * math.pi
t_axis, noise, sweep, env, bell = base.t_axis, base.noise, base.sweep, base.env, base.bell


def delayed(t, start):
    return np.maximum(t - start, 0) * (t > start)


def crackle(n, rate, decay):
    """Sparse electric clicks (Poisson) with short ringing."""
    out = np.zeros(n)
    hits = base.RNG.random(n) < rate / SR
    for index in np.nonzero(hits)[0]:
        k = np.arange(min(n - index, int(0.012 * SR))) / SR
        out[index:index + len(k)] += np.sin(TAU * base.RNG.uniform(2500, 6000) * k) * np.exp(-k * decay) * base.RNG.uniform(0.3, 1.0)
    return out


def cue(name):
    if name == "thunder_charge":
        # Rising electric hum with crackles: the star charges on the own kart.
        t = t_axis(0.6)
        hum = sweep(t, 110, 440, 1.4) * env(t, 0.05, 0.08) * 0.45
        buzz = np.sign(np.sin(TAU * np.cumsum(110 + 330 * (t / t[-1]) ** 1.4) / SR)) * 0.08 * env(t, 0.1, 0.1)
        return hum + buzz + crackle(len(t), 60, 500) * 0.35 * (t / t[-1])
    if name == "thunder_strike":
        # Bright zap, then a soft rolling rumble (no sharp crack): lightning hits from above.
        t = t_axis(1.3)
        zap = noise(len(t), 1800, 9000) * np.exp(-t * 22) * 0.7
        snap = sweep(t, 2400, 300, 0.4) * np.exp(-t * 18) * 0.35
        rumble = noise(len(t), 30, 260) * env(t, 0.06, 0.9) * np.exp(-t * 2.2) * 0.9
        sparkle = sum(bell(delayed(t, d), f, 9) for d, f in ((0.04, 2093), (0.1, 2637), (0.16, 3136))) * 0.18
        return zap + snap + rumble + sparkle + crackle(len(t), 40, 400) * 0.25 * np.exp(-t * 3)
    if name == "frost_launch":
        t = t_axis(0.55)
        glass = bell(t, 2349, 8) * 0.35 + bell(t, 3520, 11) * 0.2
        whoosh = noise(len(t), 1500, 7000) * env(t, 0.03, 0.3) * 0.3
        return glass + whoosh + sweep(t, 600, 1400, 0.6) * env(t, 0.02, 0.2) * 0.15
    if name == "frost_hit":
        # Crystalline shatter + icy hiss as the wheels freeze.
        t = t_axis(1.0)
        shards = sum(bell(delayed(t, d), f, 10) for d, f in ((0.0, 2793), (0.03, 3729), (0.07, 2217), (0.11, 4186), (0.16, 3136))) * 0.22
        hiss = noise(len(t), 3500, 11000) * env(t, 0.01, 0.6) * np.exp(-t * 3.5) * 0.35
        thud = np.sin(TAU * (90 * t)) * np.exp(-t * 18) * 0.35
        return shards + hiss + thud
    if name == "frost_melt":
        # Little drops and a soft steam sigh.
        t = t_axis(0.9)
        drops = sum(bell(delayed(t, d), f, 22) * 0.3 for d, f in ((0.05, 1568), (0.22, 1760), (0.41, 1397), (0.58, 1661)))
        steam = noise(len(t), 1200, 6000) * env(t, 0.2, 0.4) * 0.18
        return drops + steam
    if name == "meteor_launch":
        # Fiery whoosh with a low push.
        t = t_axis(0.8)
        push = np.sin(TAU * (65 * t + 25 * (1 - np.exp(-t * 20)))) * np.exp(-t * 10) * 0.6
        roar = noise(len(t), 150, 3800) * env(t, 0.02, 0.45) * 0.6
        fizz = crackle(len(t), 90, 300) * 0.25 * np.exp(-t * 2)
        return push + roar + fizz
    if name == "meteor_hit":
        # Warm "pfumpf" + crackling embers (no explosion crack).
        t = t_axis(1.1)
        boom = np.sin(TAU * (60 * t + 18 * (1 - np.exp(-t * 22)))) * np.exp(-t * 7) * 0.7
        puff = noise(len(t), 120, 1800) * np.exp(-t * 6) * 0.45
        embers = crackle(len(t), 120, 260) * 0.3 * np.exp(-t * 1.6)
        return boom + puff + embers
    if name == "ember_hiss":
        t = t_axis(0.7)
        return noise(len(t), 2000, 8000) * env(t, 0.08, 0.4) * 0.3 + crackle(len(t), 70, 300) * 0.25
    if name == "fortress_up":
        # Two shimmering layers rising (cyan inner, gold outer) + a warm chord.
        t = t_axis(1.2)
        chord = sum(np.sin(TAU * f * t + i) for i, f in enumerate((392, 523, 659, 784))) / 4
        inner = sweep(t, 300, 1200, 0.7) * env(t, 0.05, 0.4) * 0.22
        outer = sweep(delayed(t, 0.18), 450, 1800, 0.7) * (t > 0.18) * env(t, 0.2, 0.4) * 0.18
        bells = sum(bell(delayed(t, d), f, 5) for d, f in ((0.32, 1568), (0.44, 2093))) * 0.25
        return chord * env(t, 0.1, 0.5) * 0.45 + inner + outer + bells
    if name == "fortress_end":
        t = t_axis(0.7)
        return sweep(t, 1200, 380, 0.8) * env(t, 0.02, 0.4) * 0.3 + bell(t, 1046, 6) * 0.2
    if name == "whirl_go":
        # Spinning wind: band noise with a rotating (tremolo) filter feel.
        t = t_axis(1.0)
        wind = noise(len(t), 250, 2600) * env(t, 0.12, 0.35)
        swirl = 0.55 + 0.45 * np.sin(TAU * (4 + 6 * t / t[-1]) * t)
        whistle = sweep(t, 700, 1100, 0.9) * env(t, 0.2, 0.3) * 0.12
        return wind * swirl * 0.6 + whistle
    if name == "whirl_hit":
        t = t_axis(0.8)
        gust = noise(len(t), 200, 3200) * np.exp(-t * 4) * env(t, 0.01, 0.2) * 0.7
        flutter = noise(len(t), 1500, 5000) * (0.5 + 0.5 * np.sin(TAU * 18 * t)) * np.exp(-t * 6) * 0.3
        return gust + flutter
    if name == "gravity_wave":
        # Deep "wobbly" whoomp + rising hologram shimmer: space bends, karts float.
        t = t_axis(1.2)
        wob = np.sin(TAU * np.cumsum(70 + 25 * np.sin(TAU * 5 * t)) / SR) * env(t, 0.02, 0.6) * np.exp(-t * 2.0) * 0.8
        shimmer = sum(np.sin(TAU * f * t + i) for i, f in enumerate((880, 1320, 1760))) / 3 * env(t, 0.15, 0.5) * 0.25
        return wob + shimmer + sweep(t, 200, 900, 0.8) * env(t, 0.1, 0.4) * 0.15
    if name == "decoy_up":
        t = t_axis(0.8)
        chord = (bell(t, 1046, 4) + bell(delayed(t, 0.06), 1568, 4) + bell(delayed(t, 0.12), 2093, 5)) * 0.3
        return chord + sweep(t, 600, 2400, 0.6) * env(t, 0.02, 0.5) * 0.15
    if name == "decoy_pop":
        t = t_axis(0.6)
        return noise(len(t), 2500, 9000) * np.exp(-t * 14) * 0.4 + sum(bell(delayed(t, d), f, 10) for d, f in ((0.0, 2637), (0.05, 2093), (0.1, 1568))) * 0.25
    if name == "turbo_xl":
        # Strong ignition: thump + bright jet roar + rising engine whine.
        t = t_axis(1.3)
        thump = np.sin(TAU * (60 * t + 30 * (1 - np.exp(-t * 25)))) * np.exp(-t * 12) * 0.8
        roar = noise(len(t), 200, 6000) * env(t, 0.02, 0.5) * np.exp(-t * 1.2) * 0.5
        whine = sweep(t, 300, 1100, 0.6) * env(t, 0.05, 0.4) * 0.25
        return thump + roar + whine
    if name == "arc_place":
        t = t_axis(0.7)
        clank = sum(np.sin(TAU * f * t) * np.exp(-t * 30) for f in (420, 690)) * 0.3
        buzz = np.sign(np.sin(TAU * 120 * t)) * env(t, 0.2, 0.2) * 0.12 + crackle(len(t), 50, 400) * 0.3 * (t > 0.25)
        return clank + buzz
    if name == "arc_zap":
        t = t_axis(0.6)
        return noise(len(t), 1500, 9000) * np.exp(-t * 12) * 0.6 + crackle(len(t), 160, 300) * 0.4 * np.exp(-t * 4)
    if name == "bloom_open":
        # Soft blossom: harp-like rising arpeggio, slowed shimmer.
        t = t_axis(1.4)
        notes = sum(bell(delayed(t, 0.09 * i), f, 3.5) for i, f in enumerate((523, 659, 784, 988, 1175))) * 0.28
        return notes + noise(len(t), 3000, 9000) * env(t, 0.4, 0.6) * 0.06
    if name == "bloom_slow":
        # Pitch sliding down: "time slows".
        t = t_axis(0.8)
        return sweep(t, 900, 300, 0.7) * env(t, 0.03, 0.4) * 0.35 + bell(t, 660, 4) * 0.15
    if name == "ext_warning":
        # Soft two-note "Achtung von oben" (gentler than the rocket alarm).
        t = t_axis(0.42)
        return (bell(t, 1318, 6) * (t < 0.2) + bell(delayed(t, 0.18), 988, 6) * (t > 0.18)) * 0.5
    raise ValueError(name)


CUES = [
    "thunder_charge", "thunder_strike", "frost_launch", "frost_hit", "frost_melt", "meteor_launch",
    "meteor_hit", "ember_hiss", "fortress_up", "fortress_end", "whirl_go", "whirl_hit", "ext_warning",
    "gravity_wave", "decoy_up", "decoy_pop", "turbo_xl", "arc_place", "arc_zap", "bloom_open", "bloom_slow",
]


def main():
    base.OUT.mkdir(parents=True, exist_ok=True)
    manifest = [base.export(name, cue(name)) for name in CUES]
    (base.OUT / "ext_manifest.json").write_text(json.dumps({
        "generator": "tools/art/generate_kart_item_ext_audio.py", "seed": 20261119,
        "original_samples_only": True, "assets": manifest}, indent=2) + "\n")
    print(json.dumps({"files": len(manifest), "total_bytes": sum(m["bytes"] for m in manifest)}))


if __name__ == "__main__":
    main()
