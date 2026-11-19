#!/usr/bin/env python3
"""Lumo Lauf · Dschungelherz – original procedural music and sound effects.

Everything here is composed and synthesised for Lumo: no recordings, no samples,
no foreign melodies. Deterministic (fixed seed). Needs numpy and ffmpeg with
libvorbis. Writes small OGG files to assets/audio/run/.

Music (112 BPM, D major with a lowered seventh for the adventure colour):
  jungle_calm    marimba, kalimba, flute theme, hand drums, soft pad   (32 bars loop)
  jungle_action  extra layer on top: drums, bass ostinato, brass stabs, fast arps
                 (same length and tempo: both play in sync and are cross-faded)
  jungle_chase   own urgent motif in D minor, 132 BPM, 16 bars loop
  finish         short fanfare            bonus   magical harp sweep
Effects: jump, land, dash, star_0..7 (rising scale for star series), letter,
barrel_in, barrel_shoot, vine, checkpoint, stomp, hit, respawn, gate, cart.

Usage:  python3 tools/art/generate_run_jungle_audio.py [--ffmpeg PATH]
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/run"
SR = 32000
TAU = 2 * math.pi
RNG = np.random.default_rng(20261118)


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1 / SR)
    spectrum *= 1 / np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, n=signal.size)


def bandpass(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1 / SR)
    spectrum *= (1 / np.sqrt(1 + (low / np.maximum(freqs, 1)) ** 4)) * (1 / np.sqrt(1 + (freqs / high) ** 4))
    return np.fft.irfft(spectrum, n=signal.size)


def envelope(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    env = np.exp(-t / max(decay, 1e-4))
    a = int(attack * SR)
    if a > 0:
        env[:a] *= np.linspace(0, 1, a)
    return env


# ── instruments ─────────────────────────────────────────────────────────────

def marimba(note: float, length: float = 0.7, bright: float = 1.0) -> np.ndarray:
    t = t_axis(length)
    f = hz(note)
    body = np.sin(TAU * f * t) * np.exp(-t * 5.0)
    overtone = 0.35 * bright * np.sin(TAU * f * 3.93 * t) * np.exp(-t * 22.0)
    knock = 0.15 * np.sin(TAU * f * 9.2 * t) * np.exp(-t * 80.0)
    out = body + overtone + knock
    out[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return out


def kalimba(note: float, length: float = 1.0) -> np.ndarray:
    t = t_axis(length)
    f = hz(note)
    return (np.sin(TAU * f * t) + 0.25 * np.sin(TAU * f * 5.4 * t) * np.exp(-t * 18)) * np.exp(-t * 3.2)


def flute(note: float, length: float) -> np.ndarray:
    t = t_axis(length)
    f = hz(note)
    vibrato = 1 + 0.006 * np.sin(TAU * 5.2 * t) * np.clip(t * 3, 0, 1)
    phase = TAU * f * np.cumsum(vibrato) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = bandpass(RNG.standard_normal(t.size), f * 0.8, f * 3) * 0.05
    env = np.minimum(1, t / 0.06) * np.minimum(1, (length - t) / 0.08).clip(0, 1)
    return (tone + breath) * env


def brass(note: float, length: float) -> np.ndarray:
    t = t_axis(length)
    f = hz(note)
    out = np.zeros_like(t)
    for k in range(1, 12):
        if f * k > SR / 2.2:
            break
        out += np.sin(TAU * f * k * t + k) / k * np.exp(-t * (1.5 + k * 1.2))
    env = np.minimum(1, t / 0.02) * np.minimum(1, (length - t) / 0.05).clip(0, 1)
    return out * env


def pluck_bass(note: float, length: float) -> np.ndarray:
    t = t_axis(length)
    f = hz(note)
    out = np.sin(TAU * f * t) + 0.4 * np.sin(TAU * 2 * f * t) * np.exp(-t * 9) + 0.2 * np.sin(TAU * 3 * f * t) * np.exp(-t * 14)
    return out * np.exp(-t * 3.0) * np.minimum(1, (length - t) / 0.03).clip(0, 1)


def pad(chord: list[int], seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for note in chord:
        for detune in (-0.08, 0.0, 0.07):
            f = hz(note + detune)
            out += (2 * ((f * t) % 1) - 1) * 0.3
    out = lowpass(out, 1100)
    env = np.minimum(1, t / 0.5) * np.minimum(1, (seconds - t) / 0.5).clip(0, 1)
    return out * env / len(chord)


def kick() -> np.ndarray:
    t = t_axis(0.45)
    sweep = 45 + 85 * np.exp(-t * 28)
    return np.sin(TAU * np.cumsum(sweep) / SR) * np.exp(-t * 7) + 0.3 * RNG.standard_normal(t.size) * np.exp(-t * 200)


def tom(note: float) -> np.ndarray:
    t = t_axis(0.5)
    f = hz(note) * (1 + 0.5 * np.exp(-t * 30))
    return np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 7)


def clap() -> np.ndarray:
    t = t_axis(0.3)
    noise = bandpass(RNG.standard_normal(t.size), 900, 5000)
    env = np.exp(-t * 18) * (1 + 0.7 * (np.sin(TAU * 90 * t) > 0) * np.exp(-t * 60))
    return noise * env


def shaker() -> np.ndarray:
    t = t_axis(0.09)
    return bandpass(RNG.standard_normal(t.size), 5000, 12000) * np.exp(-t * 45)


def conga(note: float) -> np.ndarray:
    t = t_axis(0.35)
    f = hz(note) * (1 + 0.25 * np.exp(-t * 40))
    return np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 11) + 0.2 * RNG.standard_normal(t.size) * np.exp(-t * 300)


def cymbal(length: float = 2.0) -> np.ndarray:
    t = t_axis(length)
    return bandpass(RNG.standard_normal(t.size), 4000, 14000) * np.exp(-t * 2.2)


# ── mixing ──────────────────────────────────────────────────────────────────

def place(mix: np.ndarray, signal: np.ndarray, seconds: float, gain: float, pan: float = 0.0) -> None:
    """Adds a mono signal to the stereo mix; what runs past the end wraps round (seamless loop)."""
    start = int(seconds * SR) % mix.shape[0]
    left = gain * math.cos((pan + 1) * math.pi / 4)
    right = gain * math.sin((pan + 1) * math.pi / 4)
    total = mix.shape[0]
    done = 0
    while done < signal.size:
        at = (start + done) % total
        count = min(signal.size - done, total - at)
        piece = signal[done:done + count]
        mix[at:at + count, 0] += piece * left
        mix[at:at + count, 1] += piece * right
        done += count


def reverb(mix: np.ndarray, seconds: float = 1.6, wet: float = 0.22, circular: bool = True) -> np.ndarray:
    n = int(seconds * SR)
    out = np.empty_like(mix)
    for channel in range(2):
        ir = RNG.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
        ir = lowpass(ir, 6000)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = mix.shape[0] if circular else mix.shape[0] + n
        wet_signal = np.fft.irfft(np.fft.rfft(mix[:, channel], size) * np.fft.rfft(ir, size), size)[: mix.shape[0]]
        out[:, channel] = mix[:, channel] + wet * wet_signal
    return out


def finish(mix: np.ndarray, loudness: float = 0.16) -> np.ndarray:
    rms = np.sqrt(np.mean(mix ** 2)) + 1e-9
    mix = mix * (loudness / rms)
    return np.tanh(mix * 1.1) / np.tanh(1.1) * 0.89


# ── composition ─────────────────────────────────────────────────────────────

BPM = 112
BEAT = 60 / BPM
BAR = 4 * BEAT
D = 62  # D4
# Chords per bar (root notes, triad in D major with the adventure C major).
PROGRESSION = [
    [50, 54, 57], [48, 52, 55], [43, 47, 50], [50, 54, 57],
    [47, 50, 54], [43, 47, 50], [45, 49, 52], [45, 49, 52],
]
BRIDGE = [[43, 47, 50], [45, 49, 52], [47, 50, 54], [48, 52, 55], [43, 47, 50], [45, 49, 52], [50, 54, 57], [45, 49, 52]]
# Main theme (MIDI, beats): a bright, climbing call that answers itself.
THEME = [
    (69, 1), (74, 1.5), (73, 0.5), (71, 1),
    (69, 1.5), (67, 0.5), (66, 1), (64, 1),
    (66, 1), (67, 1), (69, 1.5), (71, 0.5),
    (69, 2), (0, 2),
    (69, 1), (74, 1.5), (76, 0.5), (78, 1),
    (76, 1.5), (74, 0.5), (73, 1), (71, 1),
    (73, 1), (71, 1), (69, 1), (66, 1),
    (69, 3), (0, 1),
]
BRIDGE_MELODY = [(71, 2), (74, 2), (73, 2), (69, 2), (71, 1), (74, 1), (76, 2), (78, 3), (0, 1),
                 (79, 2), (78, 1), (76, 1), (74, 2), (73, 2), (74, 4), (73, 2), (0, 2)]


def chords_for(bar: int) -> list[int]:
    section = bar // 8
    return (BRIDGE if section == 2 else PROGRESSION)[bar % 8]


def jungle_layers() -> tuple[np.ndarray, np.ndarray]:
    bars = 32
    length = bars * BAR
    calm = np.zeros((int(length * SR), 2))
    action = np.zeros_like(calm)
    for bar in range(bars):
        start = bar * BAR
        chord = chords_for(bar)
        place(calm, pad([n + 12 for n in chord], BAR + 0.4), start, 0.22)
        # Marimba arpeggio in eighths (calm), sixteenths on top (action).
        pattern = [0, 1, 2, 1, 2, 0, 1, 2]
        for step in range(8):
            note = chord[pattern[step]] + 24 + (12 if step == 6 else 0)
            place(calm, marimba(note, 0.6), start + step * BEAT / 2, 0.28 if step % 2 == 0 else 0.2, -0.3)
        for step in range(16):
            note = chord[(step * 2) % 3] + 36
            place(action, marimba(note, 0.3, 1.4), start + step * BEAT / 4, 0.14, 0.35)
        # Hand drums and shaker.
        for beat in range(4):
            place(calm, conga(D - 10 if beat % 2 == 0 else D - 5), start + beat * BEAT, 0.28, 0.2)
            place(calm, conga(D - 3), start + beat * BEAT + BEAT * 0.75, 0.16, 0.25)
            for sub in range(4):
                place(calm, shaker(), start + beat * BEAT + sub * BEAT / 4, 0.09 if sub % 2 else 0.14, -0.5)
        # Action: kick on every beat, clap on 2 and 4, toms fill every 4th bar.
        for beat in range(4):
            place(action, kick(), start + beat * BEAT, 0.62)
            if beat % 2 == 1:
                place(action, clap(), start + beat * BEAT, 0.3, 0.1)
        if bar % 4 == 3:
            for k, note in enumerate([50, 47, 45, 43, 40, 38]):
                place(action, tom(note), start + 2 * BEAT + k * BEAT / 3, 0.36, -0.4 + k * 0.15)
        # Bass ostinato: root, root, fifth, octave in eighths.
        root = chord[0] - 12 if chord[0] > 45 else chord[0]
        for step, offset in enumerate([0, 0, 7, 12, 0, 7, 10, 7]):
            place(action, pluck_bass(root + offset, BEAT * 0.48), start + step * BEAT / 2, 0.42)
        # Brass stabs on the chord change.
        for note in chord:
            place(action, brass(note + 12, BEAT * 0.9), start, 0.12, 0.0)
            place(action, brass(note + 12, BEAT * 0.4), start + BEAT * 2.5, 0.08, 0.0)
    # Melodies: theme in the A sections (bars 0-15 and 24-31), bridge melody 16-23.
    def melody(target: np.ndarray, notes: list, start_bar: int, maker, gain: float, transpose: int = 0, pan: float = 0.0) -> None:
        clock = start_bar * BAR
        for note, beats in notes:
            if note:
                place(target, maker(note + transpose, beats * BEAT * 0.95), clock, gain, pan)
            clock += beats * BEAT
    melody(calm, THEME, 0, flute, 0.3, 0, 0.1)
    melody(calm, THEME, 8, kalimba_line, 0.28, 0, -0.2)
    melody(calm, BRIDGE_MELODY, 16, flute, 0.28, 0, 0.1)
    melody(calm, THEME, 24, flute, 0.3, 0, 0.1)
    melody(action, THEME, 8, brass, 0.16, 12, 0.2)
    melody(action, THEME, 24, brass, 0.16, 12, 0.2)
    calm = reverb(calm, 1.8, 0.28)
    action = reverb(action, 1.2, 0.16)
    # Shared gain: the action layer sits on top of the calm one, not instead of it.
    peak_rms = np.sqrt(np.mean((calm + action) ** 2)) + 1e-9
    gain = 0.17 / peak_rms
    calm_out = np.tanh(calm * gain * 1.05) * 0.9
    action_out = np.tanh(action * gain * 1.05) * 0.9
    return calm_out, action_out


def kalimba_line(note: float, length: float) -> np.ndarray:
    return kalimba(note, max(0.6, length))


def chase_loop() -> np.ndarray:
    bpm = 132
    beat = 60 / bpm
    bars = 16
    mix = np.zeros((int(bars * 4 * beat * SR), 2))
    progression = [[38, 41, 45], [34, 38, 41], [36, 40, 43], [33, 37, 40]]
    motif = [(74, 0.5), (72, 0.5), (74, 0.5), (77, 0.5), (76, 1), (74, 1), (72, 0.5), (69, 0.5), (70, 1), (69, 2)]
    for bar in range(bars):
        start = bar * 4 * beat
        chord = progression[bar % 4]
        for step in range(16):
            place(mix, pluck_bass(chord[0] + (12 if step % 4 == 2 else 0), beat * 0.24), start + step * beat / 4, 0.36)
        for b in range(4):
            place(mix, kick(), start + b * beat, 0.6)
            if b % 2 == 1:
                place(mix, clap(), start + b * beat, 0.32)
            for sub in range(2):
                place(mix, shaker(), start + b * beat + sub * beat / 2 + beat / 4, 0.12, 0.4)
        if bar % 2 == 1:
            for k, note in enumerate([52, 50, 48, 45, 43, 41, 40, 38]):
                place(mix, tom(note), start + 2 * beat + k * beat / 4, 0.3, -0.5 + k * 0.12)
        for note in chord:
            for step in range(8):
                place(mix, brass(note + 24, beat * 0.22), start + step * beat / 2, 0.05, 0.25 if step % 2 else -0.25)
        if bar % 4 in (0, 2):
            clock = start
            for note, beats in motif:
                place(mix, flute(note, beats * beat * 0.9) + 0.6 * brass(note - 12, beats * beat * 0.9), clock, 0.22, 0.05)
                clock += beats * beat
    return finish(reverb(mix, 1.0, 0.14), 0.18)


def fanfare() -> np.ndarray:
    length = 4.5
    mix = np.zeros((int(length * SR), 2))
    for k, note in enumerate([62, 66, 69, 74]):
        place(mix, brass(note, 0.35), k * 0.16, 0.5, -0.3 + k * 0.2)
        place(mix, marimba(note + 12, 0.6), k * 0.16, 0.3, 0.3)
    for note in [62, 66, 69, 74, 78]:
        place(mix, brass(note, 2.6), 0.7, 0.28)
    place(mix, pad([62, 66, 69, 74], 3.4), 0.7, 0.5)
    place(mix, cymbal(3.0), 0.68, 0.25)
    for k in range(12):
        place(mix, marimba(74 + [0, 2, 4, 7, 9, 12][k % 6] + 12 * (k // 6), 0.4), 1.1 + k * 0.07, 0.18, 0.4)
    return finish(reverb(mix, 1.8, 0.3, False), 0.16)


def harp_sweep() -> np.ndarray:
    length = 2.6
    mix = np.zeros((int(length * SR), 2))
    scale = [62, 64, 66, 69, 71, 74, 76, 78, 81, 83, 86, 88]
    for k, note in enumerate(scale):
        place(mix, kalimba(note, 1.6), k * 0.07, 0.3, -0.6 + k * 0.1)
    place(mix, bandpass(RNG.standard_normal(int(2.0 * SR)), 6000, 12000) * np.exp(-np.arange(int(2.0 * SR)) / SR * 2) * 0.3, 0.2, 0.3)
    return finish(reverb(mix, 1.6, 0.35, False), 0.14)


# ── effects ─────────────────────────────────────────────────────────────────

def sweep(f0: float, f1: float, seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    f = f0 * (f1 / f0) ** (t / seconds)
    return np.sin(TAU * np.cumsum(f) / SR)


def bell(note: float, seconds: float = 0.45) -> np.ndarray:
    t = t_axis(seconds)
    f = hz(note)
    return (np.sin(TAU * f * t) + 0.4 * np.sin(TAU * f * 2.76 * t) * np.exp(-t * 10) + 0.2 * np.sin(TAU * f * 5.4 * t) * np.exp(-t * 20)) * np.exp(-t * 7)


def noise(seconds: float, low: float, high: float, decay: float) -> np.ndarray:
    n = int(seconds * SR)
    return bandpass(RNG.standard_normal(n), low, high) * np.exp(-np.arange(n) / SR * decay)


def effects() -> dict[str, np.ndarray]:
    fx: dict[str, np.ndarray] = {}
    t = t_axis(0.22)
    fx["jump"] = sweep(320, 820, 0.22) * np.exp(-t * 9) * 0.7 + noise(0.22, 800, 4000, 14) * 0.25
    t = t_axis(0.25)
    fx["land"] = np.sin(TAU * 85 * t) * np.exp(-t * 22) + noise(0.25, 1500, 7000, 18) * 0.5
    fx["dash"] = noise(0.35, 400, 6000, 7) * np.sin(np.linspace(0, math.pi, int(0.35 * SR))) * 0.9
    for k, step in enumerate([0, 2, 4, 5, 7, 9, 11, 12]):
        fx[f"star_{k}"] = bell(86 + step, 0.42) * 0.8
    letter = np.zeros(int(1.1 * SR))
    for k, note in enumerate([86, 90, 93, 98]):
        b = bell(note, 0.8)
        start = int(k * 0.08 * SR)
        letter[start:start + b.size] += b[: letter.size - start] * 0.5
    letter += noise(1.1, 6000, 12000, 3) * 0.2
    fx["letter"] = letter
    t = t_axis(0.25)
    fx["barrel_in"] = (np.sin(TAU * 190 * t) + 0.5 * np.sin(TAU * 410 * t)) * np.exp(-t * 26) + noise(0.25, 300, 1500, 30) * 0.4
    t = t_axis(0.7)
    fx["barrel_shoot"] = sweep(140, 40, 0.7) * np.exp(-t * 6) + noise(0.7, 300, 5000, 5) * np.exp(-t * 2) * 0.6
    t = t_axis(0.55)
    creak = np.sign(np.sin(TAU * (60 + 30 * np.sin(TAU * 3 * t)) * t)) * 0.15 * np.exp(-t * 9)
    fx["vine"] = lowpass(creak, 2500) + noise(0.55, 600, 3000, 4) * np.sin(np.linspace(0, math.pi, t.size)) * 0.6
    chime = np.zeros(int(1.0 * SR))
    for k, note in enumerate([81, 86, 90]):
        b = bell(note, 0.7)
        start = int(k * 0.11 * SR)
        chime[start:start + b.size] += b[: chime.size - start] * 0.55
    fx["checkpoint"] = chime
    t = t_axis(0.3)
    fx["stomp"] = sweep(700, 180, 0.3) * np.exp(-t * 10) * 0.8 + np.sin(TAU * 120 * t) * np.exp(-t * 30) * 0.5
    t = t_axis(0.7)
    bonk = (np.sin(TAU * 720 * t) + 0.5 * np.sin(TAU * 1080 * t)) * np.exp(-t * 30)
    tweet = sweep(1800, 2600, 0.7) * (0.5 + 0.5 * np.sin(TAU * 9 * t)) * np.exp(-t * 4) * 0.25
    fx["hit"] = bonk + tweet
    t = t_axis(0.7)
    sparkle = sum(bell(n, 0.5) for n in [93]) * 0.0
    fx["respawn"] = sweep(600, 2400, 0.7) * np.exp(-t * 5) * 0.4 + noise(0.7, 5000, 12000, 4) * 0.25 + np.pad(sparkle, (0, max(0, t.size - sparkle.size)))[: t.size]
    t = t_axis(1.4)
    fx["gate"] = noise(1.4, 40, 400, 2.0) * 1.4 + np.pad(bell(86, 0.8), (int(0.6 * SR), 0))[: t.size] * 0.4
    t = t_axis(0.4)
    clack = np.zeros(t.size)
    for start in (0.0, 0.16):
        s = int(start * SR)
        ping = (np.sin(TAU * 1900 * t[: int(0.12 * SR)]) + noise(0.12, 2000, 8000, 40)) * np.exp(-t[: int(0.12 * SR)] * 50)
        clack[s:s + ping.size] += ping
    fx["cart"] = clack * 0.7
    out = {}
    for name, signal in fx.items():
        peak = np.max(np.abs(signal)) + 1e-9
        fade = np.minimum(1, (signal.size - np.arange(signal.size)) / (0.01 * SR))
        out[name] = signal / peak * 0.85 * fade
    return out


# ── export ──────────────────────────────────────────────────────────────────

def export(name: str, data: np.ndarray, ffmpeg: str, quality: float, loop: bool) -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    stereo = data if data.ndim == 2 else np.stack([data, data], axis=1)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    channels = 2 if data.ndim == 2 else 1
    with tempfile.TemporaryDirectory(prefix="lumo-run-audio-") as temp:
        source = Path(temp) / f"{name}.wav"
        with wave.open(str(source), "wb") as handle:
            handle.setnchannels(channels)
            handle.setsampwidth(2)
            handle.setframerate(SR)
            handle.writeframes(pcm[:, 0].tobytes() if channels == 1 else pcm.tobytes())
        target = OUT / f"{name}.ogg"
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source), "-c:a", "libvorbis", "-q:a", str(quality),
             "-metadata", "title=Lumo Lauf Dschungelherz - " + name, "-metadata", "artist=LUMO original procedural composition",
             str(target)],
            check=True,
        )
    seconds = stereo.shape[0] / SR
    return {"file": f"{name}.ogg", "seconds": round(seconds, 3), "bytes": target.stat().st_size, "loop": loop}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()
    manifest = {"generator": "tools/art/generate_run_jungle_audio.py", "sample_rate": SR, "bpm": BPM, "files": []}
    calm, action = jungle_layers()
    manifest["files"].append(export("jungle_calm", calm, args.ffmpeg, 2, True))
    manifest["files"].append(export("jungle_action", action, args.ffmpeg, 2, True))
    manifest["files"].append(export("jungle_chase", chase_loop(), args.ffmpeg, 2, True))
    manifest["files"].append(export("finish", fanfare(), args.ffmpeg, 3, False))
    manifest["files"].append(export("bonus", harp_sweep(), args.ffmpeg, 3, False))
    for name, signal in effects().items():
        manifest["files"].append(export("sfx_" + name, signal.astype(np.float64), args.ffmpeg, 3, False))
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    total = sum(entry["bytes"] for entry in manifest["files"])
    print(f"wrote {len(manifest['files'])} files, {total / 1024:.0f} KiB to {OUT}")


if __name__ == "__main__":
    main()
