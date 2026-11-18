#!/usr/bin/env python3
"""Lumo Klangwelt – Synthese-Baukasten (nur numpy).

Alles ist Eigenbau: additive/FM-Instrumente, gefiltertes Rauschen für Schlagwerk
und Atmosphäre, Faltungshall aus selbst erzeugter Impulsantwort. Keine Samples,
keine Aufnahmen, keine fremden Melodien.

Kernidee für nahtlose Schleifen: Jede Spur wird in einen Puffer exakt der
Schleifenlänge N geschrieben. Noten, deren Ausklang über das Ende hinausreicht,
werden an den Anfang zurückgefaltet (zirkuläres Addieren). Filter und Hall
arbeiten per FFT über den ganzen Puffer und sind damit ebenfalls zirkulär. Das
Ergebnis ist streng periodisch: Sample N-1 geht stetig in Sample 0 über.
"""
from __future__ import annotations

import math

import numpy as np

SR = 32000
TAU = 2 * math.pi
NYQ_SAFE = 13500.0  # Obertöne darüber werden gar nicht erst erzeugt


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def tax(n: int) -> np.ndarray:
    return np.arange(n) / SR


def nsamp(seconds: float) -> int:
    return max(1, int(round(seconds * SR)))


# ── Filter (FFT, zirkulär) ─────────────────────────────────────────────────

def fft_filter(x: np.ndarray, low: float | None = None, high: float | None = None, order: int = 2) -> np.ndarray:
    """Butterworth-Betragsgang im Frequenzbereich. Arbeitet auf der letzten Achse."""
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    gain = np.ones_like(freqs)
    if high is not None:
        gain *= 1 / np.sqrt(1 + (freqs / max(high, 1.0)) ** (2 * order))
    if low is not None:
        gain *= 1 / np.sqrt(1 + (max(low, 1.0) / np.maximum(freqs, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec * gain, n=n, axis=-1)


def lowpass(x, cutoff, order=2):
    return fft_filter(x, None, cutoff, order)


def highpass(x, cutoff, order=2):
    return fft_filter(x, cutoff, None, order)


def bandpass(x, low, high, order=2):
    return fft_filter(x, low, high, order)


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def pink(n: int, rng: np.random.Generator) -> np.ndarray:
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec /= np.sqrt(np.maximum(freqs, 20.0))
    out = np.fft.irfft(spec, n=n)
    return out / (np.std(out) + 1e-12)


def brown(n: int, rng: np.random.Generator) -> np.ndarray:
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec /= np.maximum(freqs, 15.0)
    out = np.fft.irfft(spec, n=n)
    return out / (np.std(out) + 1e-12)


# ── Hüllkurven ─────────────────────────────────────────────────────────────

def adsr(n: int, a: float, d: float, s: float, gate: float, r: float) -> np.ndarray:
    t = tax(n)
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4)))
    rel = t > gate
    if rel.any():
        env[rel] *= np.exp(-(t[rel] - gate) / max(r, 1e-4))
    return env


def fade_edges(x: np.ndarray, attack: float = 0.002, release: float = 0.01) -> np.ndarray:
    n = x.shape[-1]
    a = min(nsamp(attack), n // 2)
    r = min(nsamp(release), n // 2)
    env = np.ones(n)
    if a > 1:
        env[:a] = np.linspace(0, 1, a)
    if r > 1:
        env[-r:] *= np.linspace(1, 0, r) ** 2
    return x * env


def release_tail(t: np.ndarray, gate: float, r: float) -> np.ndarray:
    return np.where(t > gate, np.exp(-(t - gate) / max(r, 1e-4)), 1.0)


def phase_of(freq: np.ndarray | float, n: int) -> np.ndarray:
    if np.isscalar(freq):
        return TAU * float(freq) * tax(n)
    return TAU * np.cumsum(freq) / SR


# ── Gestimmte Instrumente: f(midi, sekunden, velocity, rng) -> mono ───────

def epiano(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 1.1)
    t = tax(n)
    ph = TAU * f * t + rng.uniform(0, TAU)
    index = (0.6 + 1.1 * vel) * np.exp(-t * 5.0)
    y = np.sin(ph + index * np.sin(ph))
    y += 0.5 * np.sin(ph * 1.0007 + 0.3)
    if f * 7 < NYQ_SAFE:
        y += 0.12 * vel * np.sin(ph * 7) * np.exp(-t * 28)
    env = np.exp(-t * (1.3 + f / 900)) * release_tail(t, dur, 0.16)
    return fade_edges(y * env * 0.5, 0.002, 0.02)


def marimba(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(min(dur, 0.9) + 0.6)
    t = tax(n)
    ph = TAU * f * t
    y = np.sin(ph)
    if 4 * f < NYQ_SAFE:
        y += 0.32 * np.sin(4 * ph) * np.exp(-t * 26)
    if 9.9 * f < NYQ_SAFE:
        y += 0.07 * np.sin(9.9 * ph) * np.exp(-t * 70)
    env = np.exp(-t * (3.2 + m / 30.0))
    return fade_edges(y * env * (0.55 + 0.45 * vel), 0.0015, 0.03)


def kalimba(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(1.6)
    t = tax(n)
    ph = TAU * f * t
    y = np.sin(ph) + (0.22 * np.sin(5.4 * ph) * np.exp(-t * 32) if 5.4 * f < NYQ_SAFE else 0)
    y += 0.08 * np.sin(2 * ph) * np.exp(-t * 6)
    env = np.exp(-t * 2.4)
    return fade_edges(y * env * (0.5 + 0.5 * vel), 0.0015, 0.05)


def _partials(f, n, ratios, amps, decays, rng, attack=0.001):
    t = tax(n)
    y = np.zeros(n)
    for ratio, amp, dec in zip(ratios, amps, decays):
        if f * ratio >= NYQ_SAFE:
            continue
        y += amp * np.sin(TAU * f * ratio * t + rng.uniform(0, TAU)) * np.exp(-t * dec)
    return fade_edges(y, attack, 0.05)


def bell(m, dur, vel, rng):
    f = hz(m)
    return 0.42 * (0.5 + 0.5 * vel) * _partials(
        f, nsamp(2.4), [1, 2.0, 3.0, 4.16, 5.43, 6.79], [1, 0.42, 0.22, 0.12, 0.06, 0.03],
        [1.6, 2.4, 3.8, 6.0, 8.0, 11.0], rng)


def celesta(m, dur, vel, rng):
    f = hz(m)
    return 0.42 * (0.5 + 0.5 * vel) * _partials(
        f, nsamp(1.8), [1, 2.0, 3.98, 6.1], [1, 0.3, 0.14, 0.05], [2.2, 3.5, 7.0, 12.0], rng)


def glock(m, dur, vel, rng):
    f = hz(m)
    return 0.32 * (0.5 + 0.5 * vel) * _partials(
        f, nsamp(1.6), [1, 2.76, 5.40], [1, 0.25, 0.08], [2.0, 5.0, 10.0], rng)


def musicbox(m, dur, vel, rng):
    f = hz(m)
    return 0.36 * (0.5 + 0.5 * vel) * _partials(
        f, nsamp(1.9), [1, 3.0, 5.93, 9.1], [1, 0.18, 0.08, 0.03], [1.9, 4.0, 9.0, 15.0], rng)


def vibes(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 1.4)
    t = tax(n)
    y = _partials(f, n, [1, 4.0, 10.0], [1, 0.22, 0.05], [0.9, 3.0, 9.0], rng)
    y *= 1 + 0.22 * np.sin(TAU * 5.2 * t)
    return 0.42 * (0.5 + 0.5 * vel) * y * release_tail(t, dur + 0.25, 0.35)


def pluck(m, dur, vel, rng, pos=0.22, damp=1.0, length=2.6):
    """Harfe/Gitarre: additive Saite mit frequenzabhängigem Abklingen."""
    f = hz(m)
    n = nsamp(min(dur + 1.2, length))
    t = tax(n)
    y = np.zeros(n)
    k_max = int(min(24, NYQ_SAFE * 0.8 // f))
    for k in range(1, k_max + 1):
        amp = abs(math.sin(math.pi * k * pos)) / k ** 1.05
        dec = damp * (1.1 + 0.42 * k * math.sqrt(f / 220))
        y += amp * np.sin(TAU * f * k * t * (1 + 0.00012 * k * k) + rng.uniform(0, TAU)) * np.exp(-t * dec)
    y *= release_tail(t, dur + 0.6, 0.4)
    return fade_edges(y * 0.45 * (0.5 + 0.5 * vel), 0.0015, 0.04)


def harp(m, dur, vel, rng):
    return pluck(m, dur, vel, rng, pos=0.3, damp=0.8, length=3.0)


def guitar(m, dur, vel, rng):
    return pluck(m, dur, vel, rng, pos=0.18, damp=1.3, length=1.8)


def pizz(m, dur, vel, rng):
    return pluck(m, min(dur, 0.3), vel, rng, pos=0.25, damp=3.2, length=0.9)


def upright(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(min(dur, 1.2) + 0.35)
    t = tax(n)
    y = np.zeros(n)
    for k in range(1, 11):
        if f * k > 4000:
            break
        amp = abs(math.sin(math.pi * k * 0.16)) / k ** 1.3
        y += amp * np.sin(TAU * f * k * t + rng.uniform(0, TAU)) * np.exp(-t * (2.0 + 0.9 * k))
    thump = lowpass(rng.standard_normal(n), 900) * np.exp(-t * 90) * 0.15
    y = (y + thump) * release_tail(t, min(dur, 1.2), 0.08)
    return fade_edges(y * 0.9 * (0.6 + 0.4 * vel), 0.002, 0.03)


def synth_bass(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.12)
    t = tax(n)
    ph = TAU * f * t
    y = np.sin(ph) + 0.32 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(4 * ph)
    env = adsr(n, 0.006, 0.18, 0.62, dur, 0.06)
    return fade_edges(y * env * 0.7 * (0.6 + 0.4 * vel), 0.002, 0.02)


def soft_bass(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.3)
    t = tax(n)
    ph = TAU * f * t
    y = np.sin(ph) + 0.18 * np.sin(2 * ph)
    env = adsr(n, 0.02, 0.5, 0.55, dur, 0.18)
    return fade_edges(y * env * 0.75 * (0.6 + 0.4 * vel), 0.004, 0.04)


def _vibrato_phase(f, n, rate=5.2, depth=0.004, delay=0.25, rng=None):
    t = tax(n)
    wobble = 1 + depth * np.sin(TAU * rate * t + (rng.uniform(0, TAU) if rng is not None else 0)) * np.minimum(1, t / max(delay, 1e-3))
    return TAU * np.cumsum(f * wobble) / SR


def flute(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.16)
    t = tax(n)
    ph = _vibrato_phase(f, n, 5.0, 0.0045, 0.35, rng)
    y = np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    breath = bandpass(rng.standard_normal(n), f * 1.5, min(f * 4, 9000)) * 0.05
    env = adsr(n, 0.045, 0.25, 0.82, dur, 0.07)
    return fade_edges((y + breath * (1 + np.exp(-t * 12) * 3)) * env * 0.42 * (0.6 + 0.4 * vel), 0.003, 0.03)


def ocarina(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.12)
    ph = _vibrato_phase(f, n, 5.8, 0.005, 0.3, rng)
    y = np.sin(ph) + 0.06 * np.sin(3 * ph)
    env = adsr(n, 0.03, 0.2, 0.85, dur, 0.06)
    return fade_edges(y * env * 0.45 * (0.6 + 0.4 * vel), 0.003, 0.03)


def clarinet(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.12)
    ph = _vibrato_phase(f, n, 4.6, 0.003, 0.4, rng)
    y = np.zeros(n)
    for k, a in [(1, 1.0), (2, 0.06), (3, 0.42), (5, 0.18), (7, 0.08), (9, 0.035)]:
        if f * k < 9000:
            y += a * np.sin(k * ph)
    env = adsr(n, 0.04, 0.3, 0.8, dur, 0.07)
    return fade_edges(y * env * 0.33 * (0.6 + 0.4 * vel), 0.003, 0.03)


def _saw_stack(f, n, cutoff, rng, voices=3, detune=0.004, vib=0.0025):
    y = np.zeros(n)
    k_max = int(min(18, 7000 // f))
    for v in range(voices):
        fv = f * (1 + detune * (v - (voices - 1) / 2))
        ph = _vibrato_phase(fv, n, 4.8 + 0.4 * v, vib, 0.5, rng)
        for k in range(1, k_max + 1):
            y += (1.0 / k) * math.exp(-k * f / cutoff) * np.sin(k * ph + rng.uniform(0, TAU))
    return y / voices


def strings(m, dur, vel, rng, cutoff=2200.0, attack=0.32):
    f = hz(m)
    n = nsamp(dur + 0.8)
    env = adsr(n, attack, 0.6, 0.85, dur, 0.55)
    return fade_edges(_saw_stack(f, n, cutoff, rng) * env * 0.16 * (0.6 + 0.4 * vel), 0.004, 0.05)


def warm_pad(m, dur, vel, rng):
    return strings(m, dur, vel, rng, cutoff=1100.0, attack=0.6)


def tremolo_strings(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.4)
    t = tax(n)
    y = _saw_stack(f, n, 2600.0, rng, voices=2)
    y *= 0.55 + 0.45 * np.abs(np.sin(TAU * 6.0 * t))  # 12 Bogenstriche pro Sekunde
    env = adsr(n, 0.08, 0.4, 0.9, dur, 0.25)
    return fade_edges(y * env * 0.17 * (0.6 + 0.4 * vel), 0.004, 0.05)


def brass(m, dur, vel, rng, mellow=False):
    f = hz(m)
    n = nsamp(dur + 0.2)
    t = tax(n)
    env = adsr(n, 0.035 if not mellow else 0.07, 0.25, 0.78, dur, 0.09)
    scoop = 1 - 0.012 * np.exp(-t * 30)
    ph = _vibrato_phase(f * scoop, n, 5.0, 0.002, 0.4, rng)
    base_cut = 380.0 if mellow else 650.0
    span = 900.0 if mellow else 2300.0
    cut = base_cut + span * env * (0.5 + 0.5 * vel)
    y = np.zeros(n)
    k_max = int(min(16, 7500 // f))
    for k in range(1, k_max + 1):
        y += (1.0 / k) * np.exp(-k * f / cut) * np.sin(k * ph)
    return fade_edges(y * env * 0.42 * (0.6 + 0.4 * vel), 0.003, 0.03)


def horn(m, dur, vel, rng):
    return brass(m, dur, vel, rng, mellow=True)


def whistle_lead(m, dur, vel, rng):
    """Heller Pfeif-Lead mit leichtem Portamento-Einschwingen (Hub)."""
    f = hz(m)
    n = nsamp(dur + 0.1)
    t = tax(n)
    glide = 1 - 0.02 * np.exp(-t * 40)
    ph = _vibrato_phase(f * glide, n, 6.0, 0.006, 0.2, rng)
    y = np.sin(ph) + 0.12 * np.sin(2 * ph)
    env = adsr(n, 0.015, 0.15, 0.75, dur, 0.05)
    return fade_edges(y * env * 0.38 * (0.6 + 0.4 * vel), 0.002, 0.03)


def square_lead(m, dur, vel, rng):
    f = hz(m)
    n = nsamp(dur + 0.1)
    ph = _vibrato_phase(f, n, 5.5, 0.003, 0.3, rng)
    y = np.zeros(n)
    for k in range(1, 14, 2):
        if f * k < 8000:
            y += np.sin(k * ph) / k * math.exp(-k / 9)
    env = adsr(n, 0.008, 0.2, 0.6, dur, 0.06)
    return fade_edges(y * env * 0.3 * (0.6 + 0.4 * vel), 0.002, 0.02)


# ── Schlagwerk (gecacht, mehrere Varianten) ────────────────────────────────

def kick(rng, soft=False):
    n = nsamp(0.45)
    t = tax(n)
    f = 48 + (80 if soft else 105) * np.exp(-t * 32)
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * (11 if soft else 8))
    click = lowpass(rng.standard_normal(n), 2500) * np.exp(-t * 300) * 0.25
    return fade_edges((y + click) * 0.9, 0.0005, 0.02)


def snare(rng, brush=False):
    n = nsamp(0.35)
    t = tax(n)
    body = np.sin(TAU * 190 * t) * np.exp(-t * 28) * (0.25 if brush else 0.5)
    hiss = bandpass(rng.standard_normal(n), 1400, 7500) * np.exp(-t * (16 if brush else 20)) * (0.45 if brush else 0.6)
    return fade_edges(body + hiss, 0.001 if not brush else 0.008, 0.03)


def brush_sweep(rng, seconds=0.5):
    n = nsamp(seconds)
    t = tax(n)
    env = np.sin(np.pi * t / seconds) ** 1.5
    return fade_edges(bandpass(rng.standard_normal(n), 1800, 6500) * env * 0.12, 0.01, 0.05)


def clap(rng):
    n = nsamp(0.32)
    t = tax(n)
    src = bandpass(rng.standard_normal(n), 900, 5200)
    env = np.zeros(n)
    for start in (0.0, 0.011, 0.022):
        s = t - start
        env += np.where(s >= 0, np.exp(-np.maximum(s, 0) * 140), 0)
    env += np.where(t > 0.022, np.exp(-(t - 0.022) * 16) * 0.5, 0)
    return fade_edges(src * env * 0.42, 0.0005, 0.03)


def hat(rng, open_=False):
    n = nsamp(0.4 if open_ else 0.09)
    t = tax(n)
    y = bandpass(rng.standard_normal(n), 6500, 12500, 3) * np.exp(-t * (9 if open_ else 55))
    return fade_edges(y * 0.24, 0.0005, 0.01)


def shaker(rng):
    n = nsamp(0.12)
    t = tax(n)
    env = np.minimum(1, t / 0.018) * np.exp(-t * 34)
    return fade_edges(bandpass(rng.standard_normal(n), 4200, 11000, 3) * env * 0.2, 0.002, 0.01)


def ride(rng):
    n = nsamp(1.1)
    t = tax(n)
    y = np.zeros(n)
    for ratio, amp in [(1, 1.0), (1.47, 0.6), (2.09, 0.45), (2.56, 0.3), (3.13, 0.2)]:
        y += amp * np.sin(TAU * 2650 * ratio * t + rng.uniform(0, TAU)) * np.exp(-t * (4.5 + ratio))
    y = y * 0.05 + bandpass(rng.standard_normal(n), 5000, 12000) * np.exp(-t * 6) * 0.06
    return fade_edges(y, 0.0005, 0.05)


def woodblock(rng, pitch=900.0):
    n = nsamp(0.12)
    t = tax(n)
    y = np.sin(TAU * pitch * t) + 0.4 * np.sin(TAU * pitch * 1.83 * t + 1)
    return fade_edges(y * np.exp(-t * 45) * 0.3, 0.0005, 0.01)


def bongo(rng, pitch=330.0):
    n = nsamp(0.3)
    t = tax(n)
    f = pitch * (1 + 0.18 * np.exp(-t * 40))
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 17)
    y += bandpass(rng.standard_normal(n), 1500, 6000) * np.exp(-t * 200) * 0.3
    return fade_edges(y * 0.4, 0.0005, 0.02)


def tambourine(rng):
    n = nsamp(0.3)
    t = tax(n)
    y = bandpass(rng.standard_normal(n), 6000, 12500, 3) * np.exp(-t * 14)
    for jf in rng.uniform(6200, 9800, 4):
        y += 0.15 * np.sin(TAU * jf * t) * np.exp(-t * 18)
    return fade_edges(y * 0.16, 0.001, 0.02)


def timpani(rng, midi=38):
    f0 = hz(midi)
    n = nsamp(1.8)
    t = tax(n)
    f = f0 * (1 + 0.025 * np.exp(-t * 8))
    ph = TAU * np.cumsum(f) / SR
    y = np.sin(ph) + 0.5 * np.sin(1.5 * ph) * np.exp(-t * 2) + 0.3 * np.sin(1.99 * ph) * np.exp(-t * 3)
    y *= np.exp(-t * 1.9)
    y += lowpass(rng.standard_normal(n), 1200) * np.exp(-t * 60) * 0.3
    return fade_edges(y * 0.55, 0.001, 0.05)


def triangle(rng):
    n = nsamp(1.4)
    return 0.12 * _partials(2600.0, n, [1, 2.83, 4.95], [1, 0.5, 0.25], [2.0, 2.6, 3.4], rng)


def snap(rng):
    n = nsamp(0.08)
    t = tax(n)
    return fade_edges(bandpass(rng.standard_normal(n), 1800, 5000) * np.exp(-t * 90) * 0.4, 0.0003, 0.01)


def cymbal_swell(rng, seconds=1.6):
    n = nsamp(seconds)
    t = tax(n)
    env = (t / seconds) ** 2.5
    return fade_edges(bandpass(rng.standard_normal(n), 3000, 11000) * env * 0.12, 0.01, 0.01)


# ── Song-Engine ────────────────────────────────────────────────────────────

ROMAN = {'i': 0, 'ii': 1, 'iii': 2, 'iv': 3, 'v': 4, 'vi': 5, 'vii': 6}
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
MIXO = [0, 2, 4, 5, 7, 9, 10]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (pan + 1) * math.pi / 4
    return math.cos(angle) * math.sqrt(2), math.sin(angle) * math.sqrt(2)


class Song:
    """Zirkulärer Stereo-Puffer mit Taktraster, Tonart und Hall-Send."""

    def __init__(self, name: str, bpm: float, bpb: int, bars: int, key: int, scale: list[int],
                 swing: float = 0.0, seed: int = 1, humanize: float = 0.006):
        self.name = name
        self.bpm = bpm
        self.bpb = bpb
        self.bars = bars
        self.key = key
        self.scale = scale
        self.swing = swing
        self.spb = 60.0 / bpm
        self.beats = bars * bpb
        self.N = int(round(self.beats * self.spb * SR))
        self.rng = np.random.default_rng(seed)
        self.humanize = humanize
        self.dry = np.zeros((2, self.N))
        self.send = np.zeros((2, self.N))
        self._drum_cache: dict[str, list[np.ndarray]] = {}

    # Zeit
    def pos(self, beat: float, jitter: bool = True) -> int:
        whole = math.floor(beat + 1e-9)
        frac = beat - whole
        if self.swing and abs(frac - 0.5) < 1e-6:
            frac = 0.5 + self.swing
        sec = (whole + frac) * self.spb
        if jitter and self.humanize:
            sec += self.rng.normal(0, self.humanize * 0.5)
        return int(round(sec * SR))

    def seconds(self, beats: float) -> float:
        return beats * self.spb

    # Tonhöhe
    def step(self, s: int | str, octave: int = 0) -> int:
        acc = 0
        if isinstance(s, str):
            while s.endswith(('#', 'b')):
                acc += 1 if s.endswith('#') else -1
                s = s[:-1]
            s = int(s)
        o, idx = divmod(s, 7)
        return self.key + 12 * (o + octave) + self.scale[idx] + acc

    def chord(self, roman: str, octave: int = 0) -> list[int]:
        """'I', 'vi', 'IV7', 'V7', 'iimaj7', 'bVII', 'IVsus', 'Iadd9', 'vii°'."""
        r = roman
        shift = 0
        if r.startswith('b'):
            shift, r = -1, r[1:]
        elif r.startswith('#'):
            shift, r = 1, r[1:]
        ext = ''
        head = ''
        for ch in r:
            if ch.lower() in 'iv' and not ext:
                head += ch
            else:
                ext += ch
        degree = ROMAN[head.lower()]
        root = self.key + 12 * octave + self.scale[degree] + shift
        upper = head.isupper()
        tones = [0, 4, 7] if upper else [0, 3, 7]
        if '°' in ext or 'dim' in ext:
            tones = [0, 3, 6]
        if 'sus' in ext:
            tones = [0, 5, 7]
        if 'maj7' in ext:
            tones.append(11)
        elif '7' in ext:
            tones.append(10)
        if 'add9' in ext:
            tones.append(14)
        if '6' in ext and '7' not in ext:
            tones.append(9)
        return [root + x for x in tones]

    # Klang setzen
    def add(self, sig: np.ndarray, beat: float, gain: float = 1.0, pan: float = 0.0, verb: float = 0.2,
            jitter: bool = True, offset_s: float = 0.0) -> None:
        start = (self.pos(beat, jitter) + int(round(offset_s * SR))) % self.N
        gl, gr = pan_gains(pan)
        for ch, g in ((0, gl), (1, gr)):
            part = sig * (gain * g)
            self._wrap_add(self.dry[ch], part, start)
            if verb:
                self._wrap_add(self.send[ch], part * verb, start)

    def _wrap_add(self, buf: np.ndarray, sig: np.ndarray, start: int) -> None:
        n = sig.shape[0]
        idx = 0
        while idx < n:
            pos = (start + idx) % self.N
            take = min(n - idx, self.N - pos)
            buf[pos:pos + take] += sig[idx:idx + take]
            idx += take

    def note(self, inst, midi: float, beat: float, beats: float, vel: float = 0.8, gain: float = 1.0,
             pan: float = 0.0, verb: float = 0.2) -> None:
        v = float(np.clip(vel * (1 + self.rng.normal(0, 0.06)), 0.1, 1.0))
        self.add(inst(midi, self.seconds(beats) * 0.98, v, self.rng), beat, gain, pan, verb)

    def drum(self, kind: str, maker, beat: float, gain: float = 1.0, pan: float = 0.0, verb: float = 0.08,
             variants: int = 4) -> None:
        cache = self._drum_cache.setdefault(kind, [])
        if len(cache) < variants:
            cache.append(maker(self.rng))
            sig = cache[-1]
        else:
            sig = cache[int(self.rng.integers(len(cache)))]
        g = gain * float(np.clip(1 + self.rng.normal(0, 0.08), 0.6, 1.3))
        self.add(sig, beat, g, pan, verb)

    def melody(self, inst, text: str, start_beat: float, octave: int = 0, vel: float = 0.8, gain: float = 1.0,
               pan: float = 0.0, verb: float = 0.25, legato: float = 0.95) -> float:
        """Text: 'stufe:dauer …', Stufe 0 = Grundton, 7 = Oktave, 'r' = Pause, '4#' chromatisch.
        Mehrere Töne gleichzeitig mit '+' ('0+2+4:2')."""
        beat = start_beat
        for token in text.split():
            if token == '|':
                continue
            pitch, length = token.split(':')
            dur = float(length)
            if pitch != 'r':
                accent = 1.0 if abs(beat - round(beat)) < 1e-6 else 0.88
                for p in pitch.split('+'):
                    self.note(inst, self.step(p, octave), beat, dur * legato, vel * accent, gain, pan, verb)
            beat += dur
        return beat

    # Mischung
    def reverb(self, seconds: float = 2.0, damp: float = 5200.0, pre: float = 0.018) -> np.ndarray:
        n_ir = nsamp(seconds)
        t = tax(n_ir)
        rng = np.random.default_rng(len(self.name) * 7919 + 13)
        out = np.zeros_like(self.send)
        for ch in range(2):
            ir = rng.standard_normal(n_ir) * np.exp(-t * 6.9 / seconds)
            ir = lowpass(ir, damp)
            ir[: nsamp(pre)] = 0
            ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
            full = np.zeros(self.N)
            full[: min(n_ir, self.N)] = ir[: self.N]
            out[ch] = np.fft.irfft(np.fft.rfft(self.send[ch]) * np.fft.rfft(full), n=self.N)
        return highpass(out, 180)

    def mix(self, verb_seconds: float = 2.0, verb_gain: float = 0.9, width: float = 1.0) -> np.ndarray:
        wet = self.reverb(verb_seconds) * verb_gain
        mixed = self.dry + wet
        if width != 1.0:
            mid = (mixed[0] + mixed[1]) / 2
            side = (mixed[0] - mixed[1]) / 2 * width
            mixed = np.stack([mid + side, mid - side])
        return mixed


def gen_line(song: Song, chord_steps: list[list[int]], rhythm: list[float], lo: int, hi: int,
             start: int, rng: np.random.Generator, end_on_root: bool = True) -> str:
    """Erzeugt eine sangliche Gegenstimme: Akkordtöne auf schweren Zeiten,
    Schrittbewegung dazwischen; gibt Melodie-Text für Song.melody zurück."""
    tokens = []
    cur = start
    for bar, tones in enumerate(chord_steps):
        beat = 0.0
        for i, dur in enumerate(rhythm):
            strong = abs(beat - round(beat)) < 1e-6 and int(round(beat)) % 2 == 0
            cands = [s for s in range(lo, hi + 1) if (s % 7) in [t % 7 for t in tones]] if strong else \
                [cur - 1, cur + 1, cur - 2, cur + 2]
            cands = [c for c in cands if lo <= c <= hi] or [cur]
            weights = np.array([1.0 / (1 + abs(c - cur)) ** 1.6 for c in cands])
            if cur > (lo + hi) / 2 + 2:
                weights *= np.array([1.6 if c < cur else 0.6 for c in cands])
            elif cur < (lo + hi) / 2 - 2:
                weights *= np.array([1.6 if c > cur else 0.6 for c in cands])
            weights /= weights.sum()
            cur = int(cands[int(rng.choice(len(cands), p=weights))])
            last = bar == len(chord_steps) - 1 and i == len(rhythm) - 1
            if last and end_on_root:
                root = tones[0] % 7
                cur = min([s for s in range(lo, hi + 1) if s % 7 == root], key=lambda s: abs(s - cur))
            tokens.append(f'{cur}:{dur:g}')
            beat += dur
    return ' '.join(tokens)
