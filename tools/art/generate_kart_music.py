#!/usr/bin/env python3
"""Lumo Kart – zeitgemäße Original-Rennmusik (Version 2).

Alles hier ist für Lumo neu komponiert und synthetisiert: keine Aufnahmen, keine
Samples, keine fremden Melodien oder MIDI-Dateien. Deterministisch (fester Seed).
Benötigt numpy, scipy, pyloudnorm und ffmpeg mit libvorbis.

Produktion je Welt (~60 s, nahtlose Schleife):
  Intro (gefiltert) · Strophe · Refrain · Breakdown · Refrain
  Kick/Clap/Hi-Hats mit Swing, Sidechain-Bass, Supersaw-Akkorde, Lead mit
  Ping-Pong-Delay, Arpeggio, Riser vor dem Refrain, Hall per Faltung,
  Bus-Kompression, Lautheit −14 LUFS, Spitzen ≤ −1 dBFS.

Aufruf:  python tools/art/generate_kart_music.py [--ffmpeg PFAD] [--only NAME]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import pyloudnorm
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/kart'
SR = 44100
TAU = 2 * math.pi
SEED = 20261008
TARGET_LUFS = -14.0
PEAK_CEILING = 10 ** (-1.0 / 20)

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]

# Jede Welt: Tempo, Grundton, Skala, Akkordstufen (je Takt), Klangfarbe des Leads.
THEMES = {
    'garage': dict(
        bpm=100, root=62, scale=MAJOR, chords=[0, 5, 3, 4], lead='glass', swing=0.10, energy=0.55,
        mood='Lumo-Garage: warmer Future-Bass, weiche Glasklänge, ruhiger Groove'),
    'sonnenhafen': dict(
        bpm=118, root=65, scale=MAJOR, chords=[0, 4, 5, 3], lead='steel', swing=0.14, energy=0.85,
        mood='Sonnenhafen: Tropical-House, Steeldrum-Lead, federnder Bass'),
    'zauberwald': dict(
        bpm=112, root=62, scale=DORIAN, chords=[0, 6, 3, 4], lead='bell', swing=0.08, energy=0.75,
        mood='Zauberwald: magischer Electro-Pop mit Glocken und Funkel-Arpeggio'),
    'bergwelt': dict(
        bpm=126, root=67, scale=MAJOR, chords=[5, 3, 0, 4], lead='supersaw', swing=0.0, energy=1.0,
        mood='Himmelsinseln: euphorischer Dance-Pop, breite Supersaws, großer Refrain'),
    'holo_city': dict(
        bpm=132, root=57, scale=MINOR, chords=[0, 5, 2, 6], lead='square', swing=0.0, energy=1.0,
        mood='Holo City: treibender Synthwave/Electro mit Neon-Arpeggio'),
}
SECTIONS = [('intro', 4), ('verse', 8), ('chorus', 8), ('break', 4), ('chorus2', 8)]


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


# ── Oszillatoren (band-begrenzt per PolyBLEP) ───────────────────────────────

def _polyblep(phase: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(phase)
    a = phase < dt
    t = phase[a] / dt[a]
    out[a] = t + t - t * t - 1
    b = phase > 1 - dt
    t = (phase[b] - 1) / dt[b]
    out[b] = t * t + t + t + 1
    return out


def saw(freq: np.ndarray, phase0: float = 0.0) -> np.ndarray:
    dt = freq / SR
    phase = (phase0 + np.cumsum(dt)) % 1.0
    return 2 * phase - 1 - _polyblep(phase, dt)


def square(freq: np.ndarray, phase0: float = 0.0, width: float = 0.5) -> np.ndarray:
    dt = freq / SR
    phase = (phase0 + np.cumsum(dt)) % 1.0
    value = np.where(phase < width, 1.0, -1.0)
    value += _polyblep(phase, dt)
    shifted = (phase - width) % 1.0
    value -= _polyblep(shifted, dt)
    return value


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    cutoff = min(max(cutoff, 30.0), SR * 0.45)
    return sosfilt(butter(order, cutoff, fs=SR, output='sos'), x)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, cutoff, btype='highpass', fs=SR, output='sos'), x)


def bandpass(x: np.ndarray, low: float, high: float) -> np.ndarray:
    return sosfilt(butter(2, [low, high], btype='bandpass', fs=SR, output='sos'), x)


def envelope(n: int, attack: float, decay: float, sustain: float, release: float, gate: float) -> np.ndarray:
    t = np.arange(n) / SR
    env = np.where(t < attack, t / max(attack, 1e-4), 0.0)
    after = t >= attack
    env[after] = sustain + (1 - sustain) * np.exp(-(t[after] - attack) / max(decay, 1e-4))
    rel = t > gate
    if rel.any():
        level = env[np.argmax(rel) - 1] if np.argmax(rel) > 0 else sustain
        env[rel] = level * np.exp(-(t[rel] - gate) / max(release, 1e-4))
    return env


# ── Instrumente ─────────────────────────────────────────────────────────────

class Kit:
    def __init__(self, rng: np.random.Generator):
        self.rng = rng

    def kick(self) -> np.ndarray:
        n = int(0.42 * SR)
        t = np.arange(n) / SR
        f = 56 + 120 * np.exp(-t * 30)
        body = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 9.5)
        # Mittiger „Knock“ macht die Kick auf Handylautsprechern hörbar.
        knock = np.sin(TAU * 170 * t) * np.exp(-t * 38) * 0.45
        click = highpass(self.rng.normal(size=n), 2500) * np.exp(-t * 300) * 0.35
        return np.tanh((body + knock + click) * 1.5)

    def clap(self) -> np.ndarray:
        n = int(0.38 * SR)
        t = np.arange(n) / SR
        noise = bandpass(self.rng.normal(size=n), 900, 7000)
        env = np.zeros(n)
        for offset in (0.0, 0.011, 0.022):
            k = t >= offset
            env[k] = np.maximum(env[k], np.exp(-(t[k] - offset) * (60 if offset < 0.02 else 13)))
        body = np.sin(TAU * 205 * t) * np.exp(-t * 35) * 0.25
        return noise * env * 0.8 + body

    def hat(self, open_: bool = False) -> np.ndarray:
        n = int((0.32 if open_ else 0.07) * SR)
        t = np.arange(n) / SR
        metal = sum(square(np.full(n, f)) for f in (317, 461, 573, 727, 919, 1063)) / 6
        noise = self.rng.normal(size=n) * 0.6
        tone = highpass(metal * 0.5 + noise, 7000)
        return tone * np.exp(-t * (11 if open_ else 70)) * 0.45

    def shaker(self) -> np.ndarray:
        n = int(0.09 * SR)
        t = np.arange(n) / SR
        noise = bandpass(self.rng.normal(size=n), 4000, 11000)
        return noise * np.sin(np.pi * t / t[-1]) ** 2 * 0.3

    def crash(self) -> np.ndarray:
        n = int(2.4 * SR)
        t = np.arange(n) / SR
        noise = highpass(self.rng.normal(size=n), 3500)
        return noise * np.exp(-t * 1.7) * 0.32

    def riser(self, seconds: float) -> np.ndarray:
        n = int(seconds * SR)
        t = np.arange(n) / SR
        noise = self.rng.normal(size=n)
        # Gleitender Bandpass: Blöcke mit steigender Mittenfrequenz.
        out = np.zeros(n)
        blocks = 48
        for b in range(blocks):
            s, e = b * n // blocks, (b + 1) * n // blocks
            centre = 400 * (16 ** (b / blocks))
            out[s:e] = bandpass(noise[s:e], centre * 0.7, min(centre * 1.6, 15000))
        return out * (t / seconds) ** 2 * 0.5


def bass_note(midi: float, seconds: float, energy: float) -> np.ndarray:
    n = int(seconds * SR)
    f = np.full(n, midi_hz(midi))
    raw = 0.55 * saw(f) + 0.45 * square(f * 0.5, width=0.5) * 0.6 + 0.5 * np.sin(TAU * np.cumsum(f) / SR)
    env = envelope(n, 0.004, 0.18, 0.55, 0.05, seconds * 0.85)
    bright = lowpass(raw, 600 + 1500 * energy)
    dark = lowpass(raw, 260)
    pluck = np.exp(-np.arange(n) / SR / 0.09)
    return (bright * pluck + dark * (1 - pluck)) * env


def supersaw_chord(midis: list[float], seconds: float, cutoff: float, rng: np.random.Generator) -> np.ndarray:
    n = int(seconds * SR)
    out = np.zeros((n, 2))
    detunes = (-0.19, -0.11, -0.04, 0.0, 0.05, 0.12, 0.2)
    for m in midis:
        for i, d in enumerate(detunes):
            f = np.full(n, midi_hz(m + d * 0.5))
            voice = saw(f, phase0=rng.random())
            pan = (i / (len(detunes) - 1)) * 2 - 1
            out[:, 0] += voice * math.cos((pan + 1) * math.pi / 4)
            out[:, 1] += voice * math.sin((pan + 1) * math.pi / 4)
    out /= len(detunes) * len(midis) * 0.6
    env = envelope(n, 0.02, 0.6, 0.75, 0.25, seconds * 0.92)[:, None]
    return np.stack([lowpass(out[:, 0], cutoff), lowpass(out[:, 1], cutoff)], axis=1) * env


def lead_note(midi: float, seconds: float, kind: str, rng: np.random.Generator) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    vibrato = 1 + 0.004 * np.sin(TAU * 5.4 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    f = midi_hz(midi) * vibrato
    if kind == 'bell':
        mod = np.exp(-t * 6) * 2.2
        x = np.sin(TAU * np.cumsum(f) / SR + mod * np.sin(TAU * np.cumsum(f * 3.5) / SR))
        env = envelope(n, 0.002, 0.5, 0.18, 0.4, seconds)
    elif kind == 'steel':
        mod = np.exp(-t * 9) * 1.4
        x = np.sin(TAU * np.cumsum(f) / SR + mod * np.sin(TAU * np.cumsum(f * 2.0) / SR)) * 0.8 \
            + 0.2 * np.sin(TAU * np.cumsum(f * 4.0) / SR) * np.exp(-t * 14)
        env = envelope(n, 0.002, 0.25, 0.25, 0.2, seconds * 0.9)
    elif kind == 'glass':
        x = 0.6 * np.sin(TAU * np.cumsum(f) / SR) + 0.25 * np.sin(TAU * np.cumsum(f * 2.0) / SR) \
            + 0.15 * square(f, width=0.3)
        x = lowpass(x, 4200)
        env = envelope(n, 0.01, 0.4, 0.45, 0.3, seconds * 0.9)
    elif kind == 'square':
        x = 0.7 * square(f, width=0.42) + 0.3 * saw(f * 1.003)
        x = lowpass(x, 2800 + 2600 * np.exp(-0.0))
        env = envelope(n, 0.004, 0.2, 0.6, 0.12, seconds * 0.9)
    else:  # supersaw lead
        x = sum(saw(f * (1 + d), phase0=rng.random()) for d in (-0.006, -0.002, 0.0, 0.003, 0.007)) / 3.0
        x = lowpass(x, 5200)
        env = envelope(n, 0.006, 0.25, 0.7, 0.18, seconds * 0.9)
    return x * env


def arp_note(midi: float, seconds: float) -> np.ndarray:
    n = int(seconds * SR)
    f = np.full(n, midi_hz(midi))
    x = 0.6 * square(f, width=0.25) + 0.4 * saw(f)
    pluck = np.exp(-np.arange(n) / SR / 0.06)
    return (lowpass(x, 1200) * (1 - pluck) + lowpass(x, 6500) * pluck) * envelope(n, 0.002, 0.08, 0.2, 0.05, seconds * 0.7)


# ── Komposition ─────────────────────────────────────────────────────────────

class Song:
    def __init__(self, name: str, cfg: dict):
        self.name = name
        self.cfg = cfg
        self.rng = np.random.default_rng(SEED + sum(map(ord, name)))
        self.kit = Kit(self.rng)
        self.beat = 60.0 / cfg['bpm']
        self.bars = sum(b for _, b in SECTIONS)
        self.length = int(round(self.bars * 4 * self.beat * SR))
        self.bus = {k: np.zeros((self.length, 2)) for k in ('drums', 'bass', 'chords', 'lead', 'arp', 'fx')}
        self.kicks: list[float] = []

    # Platzierung mit Umlauf: Ausklänge laufen in den Schleifenanfang.
    def add(self, bus: str, wave: np.ndarray, at_beats: float, gain: float = 1.0, pan: float = 0.0) -> None:
        start = int(round(at_beats * self.beat * SR))
        if wave.ndim == 1:
            angle = (pan + 1) * math.pi / 4
            stereo = np.stack([wave * math.cos(angle), wave * math.sin(angle)], axis=1) * math.sqrt(2)
        else:
            stereo = wave
        idx = (start + np.arange(len(stereo))) % self.length
        np.add.at(self.bus[bus], idx, stereo * gain)

    def degree(self, d: int, octave: int = 0) -> int:
        scale = self.cfg['scale']
        return self.cfg['root'] + scale[d % 7] + 12 * (d // 7 + octave)

    def chord_tones(self, root_degree: int, octave: int = 0) -> list[int]:
        return [self.degree(root_degree + k, octave) for k in (0, 2, 4)]

    def section_of(self, bar: int) -> str:
        acc = 0
        for name, bars in SECTIONS:
            if bar < acc + bars:
                return name
            acc += bars
        return SECTIONS[-1][0]

    def compose(self) -> np.ndarray:
        cfg = self.cfg
        swing = cfg['swing']
        energy = cfg['energy']
        motif = self._motif()
        for bar in range(self.bars):
            sec = self.section_of(bar)
            chord_deg = cfg['chords'][bar % 4]
            b0 = bar * 4
            full = sec in ('chorus', 'chorus2')
            # Schlagzeug
            if sec != 'break':
                for beat in range(4):
                    self.add('drums', self.kit.kick(), b0 + beat, 0.95)
                    self.kicks.append(b0 + beat)
                for beat in (1, 3):
                    self.add('drums', self.kit.clap(), b0 + beat, 0.55 if sec != 'intro' else 0.3, 0.05)
            for eighth in range(8):
                at = b0 + eighth * 0.5 + (swing * 0.5 if eighth % 2 else 0.0)
                if eighth % 2 == 1:
                    self.add('drums', self.kit.hat(open_=full), at, 0.42 if full else 0.34, 0.3)
                elif sec != 'intro':
                    self.add('drums', self.kit.hat(), at, 0.22, -0.3)
            if full or sec == 'verse':
                for six in range(16):
                    if six % 4 != 0:
                        self.add('drums', self.kit.shaker(), b0 + six * 0.25 + (swing * 0.25 if six % 2 else 0), 0.25 if full else 0.15, -0.5)
            # Bass (synkopiert, im Refrain treibende Achtel)
            if sec != 'intro':
                root = self.degree(chord_deg, -1) - 12 * (1 if self.cfg['root'] > 63 else 0)
                pattern = [(0, 0.45), (0.75, 0.25), (1.5, 0.45), (2.5, 0.45), (3.25, 0.25), (3.5, 0.45)] if not full \
                    else [(i * 0.5, 0.42) for i in range(8)]
                for i, (at, dur) in enumerate(pattern):
                    pitch = root + (12 if (full and i % 4 == 3) else 0)
                    self.add('bass', bass_note(pitch, dur * self.beat, energy), b0 + at, 0.62 if sec != 'break' else 0.35)
            # Akkorde (Supersaw); im Intro dunkel gefiltert
            cutoff = {'intro': 900, 'verse': 2400, 'chorus': 5200, 'break': 1500, 'chorus2': 5600}[sec]
            tones = self.chord_tones(chord_deg, -1)
            if full:
                tones = tones + [tones[0] + 12]
                for hit in (0, 1.5, 2.5):
                    self.add('chords', supersaw_chord(tones, 0.95 * self.beat, cutoff, self.rng), b0 + hit, 0.42)
            else:
                self.add('chords', supersaw_chord(tones, 4 * self.beat, cutoff, self.rng), b0, 0.36)
            # Arpeggio (Strophe/Breakdown/Refrain)
            if sec in ('verse', 'break', 'chorus2'):
                arp_tones = self.chord_tones(chord_deg, 0)
                order = [0, 1, 2, 1, 0, 2, 1, 2] if sec != 'chorus2' else [0, 1, 2, 3, 2, 1, 2, 3]
                for six in range(16):
                    idx = order[six % 8]
                    pitch = (arp_tones + [arp_tones[0] + 12])[idx]
                    self.add('arp', arp_note(pitch, 0.24 * self.beat), b0 + six * 0.25, 0.2, 0.55 if six % 2 else -0.55)
            # Lead-Melodie (Strophe ruhig, Refrain eine Oktave höher)
            if sec in ('verse', 'chorus', 'chorus2'):
                phrase_bar = (bar - self._section_start(sec)) % 8
                octave = 1 if full else 0
                for at, dur, deg in motif[phrase_bar]:
                    pitch = self.degree(deg, octave)
                    self.add('lead', lead_note(pitch, dur * self.beat * 0.95, cfg['lead'], self.rng), b0 + at,
                             0.34 if full else 0.26, 0.1 * math.sin(at))
        # Riser und Crash vor bzw. an jedem Refrain.
        for sec_name in ('chorus', 'chorus2'):
            start = self._section_start(sec_name) * 4
            self.add('fx', self.kit.riser(4 * self.beat * 2), start - 8, 0.55)
            self.add('fx', self.kit.crash(), start, 0.7)
        return self.mix()

    def _section_start(self, name: str) -> int:
        acc = 0
        for sec, bars in SECTIONS:
            if sec == name:
                return acc
            acc += bars
        return 0

    def _motif(self) -> list[list[tuple[float, float, int]]]:
        """Acht Takte Melodie aus gestalteten Phrasenkonturen.

        A = Bogen (Motiv), A2 = gleiche Kontur auf neuem Akkord, B = Antwort,
        C = Sprung mit Rückweg, END = Kadenz auf den Grundton. Starke Zählzeiten
        landen auf Akkordtönen in Richtung der Kontur, keine Tonwiederholungen,
        Umfang eine Oktave plus Terz (Stufen 7–16), an den Rändern gespiegelt.
        """
        cfg = self.cfg
        phrases = {
            'A': ([(0, 0.75), (0.75, 0.75), (1.5, 0.5), (2, 1.0), (3, 0.5), (3.5, 0.5)], [0, 2, -1, 1, 2, -2]),
            'B': ([(0, 1.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1.0)], [0, -1, -1, 3, -1]),
            'C': ([(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 1.0), (2.5, 1.5)], [4, -1, -1, -1, -2]),
            'END': ([(0, 1.0), (1, 0.5), (1.5, 0.5), (2, 2.0)], [0, -1, -1, -3]),
        }
        plan = ['A', 'B', 'A', 'C', 'A', 'B', 'C', 'END']
        # Eigene Handschrift je Welt: Kontur umkehren bzw. rückwärts lesen.
        variant = sum(map(ord, self.name)) % 4
        if variant in (1, 3):
            phrases['B'] = (phrases['B'][0], [-step for step in phrases['B'][1]])
        if variant in (2, 3):
            phrases['A'] = (phrases['A'][0], [0] + [-step for step in reversed(phrases['A'][1][1:])])
        if variant == 1:
            phrases['C'] = (phrases['C'][0], [-3, 1, 1, 2, -1])
        low, high = 7, 16
        bars: list[list[tuple[float, float, int]]] = []
        current = 9
        for bar, kind in enumerate(plan):
            chord = cfg['chords'][bar % 4]
            chord_tones = sorted({t + 7 * o for t in (chord, chord + 2, chord + 4) for o in range(0, 4)})
            rhythm, contour = phrases[kind]
            notes = []
            if kind in ('A', 'END'):
                # Phrasenbeginn auf einem Akkordton nahe der Mitte.
                current = min((c for c in chord_tones if low + 1 <= c <= high - 3), key=lambda c: abs(c - 10))
            for (at, dur), step in zip(rhythm, contour):
                target = current + step
                if target > high or target < low:
                    target = current - step  # an den Rändern spiegeln
                strong = float(at).is_integer()
                if kind == 'END' and (at, dur) == rhythm[-1]:
                    target = 7  # Kadenz: Grundton
                elif strong:
                    direction = 1 if step >= 0 else -1
                    options = [c for c in chord_tones if low <= c <= high and c != current]
                    toward = [c for c in options if (c - current) * direction > 0]
                    pool = toward or options
                    target = min(pool, key=lambda c: abs(c - target))
                elif target == current:
                    target = current + (1 if current < high else -1)
                notes.append((at, dur, int(target)))
                current = int(target)
            bars.append(notes)
        return bars

    # ── Mischung ────────────────────────────────────────────────────────────
    def sidechain(self) -> np.ndarray:
        gain = np.ones(self.length)
        t_idx = np.arange(int(0.35 * SR))
        duck = 1 - 0.62 * np.exp(-t_idx / SR / 0.11)
        for k in self.kicks:
            start = int(round(k * self.beat * SR))
            idx = (start + t_idx) % self.length
            gain[idx] = np.minimum(gain[idx], duck)
        return gain[:, None]

    def reverb(self, x: np.ndarray, seconds: float = 1.8, wet: float = 0.22) -> np.ndarray:
        n = int(seconds * SR)
        t = np.arange(n) / SR
        ir = np.stack([self.rng.normal(size=n), self.rng.normal(size=n)], axis=1) * np.exp(-t * 3.2)[:, None]
        ir[: int(0.012 * SR)] = 0
        ir = np.stack([lowpass(ir[:, 0], 6500), lowpass(ir[:, 1], 6500)], axis=1)
        ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True))
        out = np.zeros_like(x)
        for ch in range(2):
            full = fftconvolve(x[:, ch], ir[:, ch])
            wrapped = full[: self.length].copy()
            tail = full[self.length:]
            wrapped[: len(tail)] += tail  # Hall läuft nahtlos in den Schleifenanfang
            out[:, ch] = wrapped
        return x + out * wet

    def delay(self, x: np.ndarray, beats: float = 0.75, feedback: float = 0.38, repeats: int = 4) -> np.ndarray:
        out = x.copy()
        step = int(round(beats * self.beat * SR))
        gain = 1.0
        for r in range(1, repeats + 1):
            gain *= feedback
            shifted = np.roll(x, step * r, axis=0)
            if r % 2:
                shifted = shifted[:, ::-1]  # Ping-Pong
            out += circular(lambda v: lowpass_stereo(v, 5200), shifted) * gain
        return out

    def mix(self) -> np.ndarray:
        sc = self.sidechain()
        drums = self.bus['drums']
        bass = self.bus['bass'] * sc
        chords = self.bus['chords'] * sc
        arp = self.delay(self.bus['arp'], 0.75, 0.3, 3) * sc
        lead = self.delay(self.bus['lead'], 0.75, 0.33, 4)
        fx = self.bus['fx']
        bass = circular(lambda v: highpass_stereo(v, 45), bass)
        music = drums * 0.85 + bass * 0.8 + chords * 0.95 + arp * 0.7 + lead * 1.1 + fx * 0.6
        music = self.reverb(music - drums * 0.9 * 0.7, 1.9, 0.24) + drums * 0.9 * 0.7
        music = circular(lambda v: highpass_stereo(v, 40), music)
        return master(music)


def circular(fn, x: np.ndarray, pad_seconds: float = 2.0) -> np.ndarray:
    """Filtert eine Schleife so, als liefe sie schon: das Ende wird vorangestellt,
    damit kein Einschwingen an der Nahtstelle hörbar ist."""
    pad = min(len(x) - 1, int(pad_seconds * SR))
    y = fn(np.concatenate([x[-pad:], x], axis=0))
    return y[pad:]


def lowpass_stereo(x: np.ndarray, cutoff: float) -> np.ndarray:
    return np.stack([lowpass(x[:, 0], cutoff), lowpass(x[:, 1], cutoff)], axis=1)


def highpass_stereo(x: np.ndarray, cutoff: float) -> np.ndarray:
    return np.stack([highpass(x[:, 0], cutoff), highpass(x[:, 1], cutoff)], axis=1)


def master(x: np.ndarray) -> np.ndarray:
    # Sanfte Bus-Kompression (2:1 über −18 dB RMS), dann weiche Sättigung.
    rms = np.sqrt(np.maximum(circular(lambda v: lowpass(v, 8), np.mean(x ** 2, axis=1)), 0) + 1e-9)
    level = 20 * np.log10(rms + 1e-9)
    over = np.maximum(level + 18, 0)
    gain = 10 ** (-(over * 0.5) / 20)
    x = x * gain[:, None]
    meter = pyloudnorm.Meter(SR)
    loud = meter.integrated_loudness(x)
    x = x * 10 ** ((TARGET_LUFS - loud) / 20)
    x = np.tanh(x * 1.05) / 1.05
    peak = np.max(np.abs(x))
    if peak > PEAK_CEILING:
        x *= PEAK_CEILING / peak
    return x


def export(name: str, audio: np.ndarray, ffmpeg: str, metadata: dict) -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'source.wav'
        wavfile.write(wav, SR, np.round(np.clip(audio, -1, 1) * 32767).astype('<i2'))
        dest = OUT / (name + '.ogg')
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis',
                        '-q:a', '4', '-fflags', '+bitexact', '-flags:a', '+bitexact', '-map_metadata', '-1',
                        '-metadata', 'artist=Lumo project original synthesis', '-metadata', 'title=' + name,
                        str(dest)], check=True)
    meter = pyloudnorm.Meter(SR)
    metadata.update(
        file=dest.name, seconds=round(len(audio) / SR, 3), sample_rate=SR, channels=2,
        lufs=round(meter.integrated_loudness(audio), 2),
        peak_dbfs=round(20 * math.log10(np.max(np.abs(audio))), 2),
        seam_delta=round(float(np.max(np.abs(audio[-1] - audio[0]))), 5), loop=True,
        bytes=dest.stat().st_size, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    by_file = {entry['file']: entry for entry in manifest['assets']}
    for name, cfg in THEMES.items():
        if args.only and name != args.only:
            continue
        audio = Song(name, cfg).compose()
        entry = export(name, audio, args.ffmpeg, {
            'bpm': cfg['bpm'], 'bars': sum(b for _, b in SECTIONS), 'description': cfg['mood'],
            'generator': 'tools/art/generate_kart_music.py', 'seed': SEED})
        by_file[entry['file']] = entry
        print(json.dumps({k: entry[k] for k in ('file', 'seconds', 'lufs', 'peak_dbfs', 'bytes')}))
    manifest['assets'] = list(by_file.values())
    manifest['music_generator'] = 'tools/art/generate_kart_music.py (v2, seed %d)' % SEED
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
