#!/usr/bin/env python3
"""Original Dschungelherz score and environmental sound design.

Every oscillator, note and noise source is synthesized here; no recordings,
downloaded samples, MIDI files or third-party compositions are used. The three
arrangements share 32 bars at exactly 112 BPM and are phase-compatible. Circular
mixing preserves note tails and reverberation across the loop boundary.

Requires Python, numpy, scipy and ffmpeg/libvorbis. The generated manifest binds
every output to this source by SHA-256 and records decoded duration and levels.
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
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 112
BEAT = 60.0 / BPM
BEAT_FRAMES = 23625
BARS = 32
LOOP_FRAMES = BEAT_FRAMES * 4 * BARS
SEED = 3600112
TAU = math.tau
RNG = np.random.default_rng(SEED)


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def clock(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * SR), dtype=np.float64) / SR


def band_noise(count: int, lo: float, hi: float) -> np.ndarray:
    return sosfilt(butter(2, [lo, hi], btype="bandpass", fs=SR, output="sos"), RNG.normal(size=count))


def marimba(note: float, length: float = 0.9, soft: bool = False) -> np.ndarray:
    t = clock(length)
    attack = 1.0 - np.exp(-t * 850.0)
    out = np.zeros_like(t)
    for ratio, amplitude, decay in ((1.0, 1.0, 3.8), (3.97, .32, 10.5), (9.14, .10, 21.0), (13.6, .035, 33.0)):
        if hz(note) * ratio < SR * .43:
            out += amplitude * np.sin(TAU * hz(note) * ratio * t) * np.exp(-t * decay)
    out *= attack * (.72 if soft else 1.0)
    return out


def flute(note: float, length: float) -> np.ndarray:
    t = clock(length)
    gate = np.clip(t / .095, 0, 1) * np.clip((length - t) / .18, 0, 1)
    vibrato = .0022 * np.sin(TAU * 4.8 * t) * np.clip(t / .35, 0, 1)
    phase = TAU * np.cumsum(hz(note) * (1.0 + vibrato)) / SR
    voice = np.sin(phase) + .16 * np.sin(phase * 2.0) + .035 * np.sin(phase * 3.0)
    breath = band_noise(t.size, 1300, 5600) * .045
    return (voice + breath) * gate


def bass(note: float, length: float) -> np.ndarray:
    t = clock(length)
    phase = TAU * hz(note) * t
    envelope = (1 - np.exp(-t * 120)) * np.exp(-t * 2.0) * np.clip((length - t) / .055, 0, 1)
    return (np.sin(phase) + .15 * np.sin(phase * 2) + .055 * np.sin(phase * 3)) * envelope


def hand_drum(tone: float, slap: bool = False) -> np.ndarray:
    t = clock(.30 if slap else .5)
    pitch = tone + 70.0 * np.exp(-t * 65.0)
    phase = TAU * np.cumsum(pitch) / SR
    body = np.sin(phase) * np.exp(-t * (19.0 if slap else 10.0))
    body += .23 * np.sin(phase * 1.62) * np.exp(-t * 27)
    skin = band_noise(t.size, 600, 8800) * np.exp(-t * (55 if slap else 100)) * (.70 if slap else .22)
    return (body + skin) * (1 - np.exp(-t * 2200))


def shaker() -> np.ndarray:
    t = clock(.068)
    return band_noise(t.size, 5200, 14500) * np.sin(np.pi * t / .068) ** 2


def pad(chord: list[int], seconds: float) -> np.ndarray:
    t = clock(seconds)
    envelope = np.minimum(np.clip(t / .38, 0, 1), np.clip((seconds - t) / .48, 0, 1))
    out = np.zeros_like(t)
    for note in chord:
        out += np.sin(TAU * hz(note) * t) + .10 * np.sin(TAU * hz(note) * 2 * t)
    return out / len(chord) * envelope


def place(mix: np.ndarray, signal: np.ndarray, seconds: float, gain: float, pan: float = 0.0, wrap: bool = True) -> None:
    start = int(round(seconds * SR)) % len(mix)
    p = np.clip(pan, -1, 1)
    levels = np.array([math.cos((p + 1) * math.pi / 4), math.sin((p + 1) * math.pi / 4)]) * gain
    signal = np.asarray(signal, dtype=np.float32)[:, None] * levels[None, :]
    first = min(len(signal), len(mix) - start)
    mix[start:start + first] += signal[:first]
    remaining = len(signal) - first
    if remaining and wrap:
        mix[:remaining] += signal[first:]


def ambience_noise(seconds: float, exponent: float, highpass: float = 35.0) -> np.ndarray:
    """Periodic noise: filtering in the Fourier domain avoids edge transients."""
    count = round(seconds * SR)
    bins = np.fft.rfftfreq(count, 1.0 / SR)
    spectrum = RNG.normal(size=len(bins)) + 1j * RNG.normal(size=len(bins))
    response = 1.0 / np.maximum(bins, highpass) ** exponent
    response *= 1.0 - np.exp(-(bins / highpass) ** 4)
    response *= np.exp(-(bins / 13000.0) ** 6)
    spectrum *= response
    spectrum[0] = 0
    out = np.fft.irfft(spectrum, n=count)
    return out / max(np.std(out), 1e-8)


def score(variant: str) -> np.ndarray:
    calm = variant == "calm"
    finale = variant == "final"
    mix = np.zeros((LOOP_FRAMES, 2), dtype=np.float32)
    # Authored D-major motif, answered in a different rhythm every second phrase.
    motif_a = [(0, 74, .65), (.75, 78, .75), (1.5, 81, .85), (2.0, 78, .7), (2.75, 76, .75), (3.5, 74, .95)]
    motif_b = [(.25, 78, .85), (1.0, 81, .75), (1.75, 83, .9), (2.5, 81, .8), (3.0, 78, .7), (3.5, 76, .8)]
    progression = [(50, [62, 66, 69]), (47, [59, 62, 66]), (43, [55, 59, 62]), (45, [57, 61, 64])]
    for bar in range(BARS):
        at = bar * BEAT * 4
        root_note, chord = progression[(bar // 2) % 4]
        phrase = bar // 8
        # Same harmony and phrase length in every arrangement permits smooth,
        # playhead-aligned in-game transitions at any point in a lap.
        place(mix, pad(chord, BEAT * 4 + .6), at, .06 if calm else .037, -.15)
        for beat, note in [(0, root_note - 12), (1.5, root_note), (2.5, root_note - 12), (3.5, root_note + 7)]:
            if calm and beat in [1.5, 3.5]:
                continue
            place(mix, bass(note, BEAT * .9), at + beat * BEAT, .24 if not calm else .15)
        pattern = motif_a if bar % 4 in [0, 3] else motif_b
        for index, (beat, note, length) in enumerate(pattern):
            if calm and index % 2:
                continue
            shift = -12 if calm else (12 if phrase == 3 and index == 2 else 0)
            place(mix, marimba(note + shift, length + .25, calm), at + beat * BEAT, .18 if not calm else .145, -.25 + .1 * (index % 3))
        for eighth in range(8):
            if calm and eighth % 2:
                continue
            note = chord[eighth % 3] + (12 if eighth % 4 == 3 else 0)
            place(mix, marimba(note, .7, True), at + eighth * .5 * BEAT + (.017 if eighth % 2 else 0), .067 if finale else .046, .38)
            place(mix, shaker(), at + eighth * .5 * BEAT, (.035 if calm else .070) * (1.0 if eighth % 2 else .72), -.52 if eighth % 2 else .48)
        for beat, tone, slap in [(0, 92, False), (.75, 184, False), (1.5, 134, True), (2.25, 106, False), (3, 196, True), (3.5, 152, False)]:
            if calm and beat not in [0, 3]:
                continue
            place(mix, hand_drum(tone, slap), at + beat * BEAT, (.105 if calm else .18) * (.8 if slap else 1), .20 if slap else -.10)
        if finale:
            for beat in [1.25, 2.75, 3.75]:
                place(mix, hand_drum(224, True), at + beat * BEAT, .10, -.40)
        if bar % 4 in ([1, 3] if calm else [2, 3]) or finale and phrase >= 1:
            notes = [81, 78, 76, 74] if bar % 4 == 3 else [78, 81, 83, 81]
            for index, note in enumerate(notes):
                place(mix, flute(note, .62 * BEAT + .16), at + (index + .25) * BEAT, .068 if calm else .075, .28)
    dry = mix.copy()
    for seconds, gain, reverse in [(.041, .12, False), (.079, .08, True), (.137, .055, False), (.219, .04, True), (BEAT * .75, .095, True), (BEAT * 1.5, .048, False)]:
        echo = np.roll(dry, round(seconds * SR), axis=0)
        mix += (echo[:, ::-1] if reverse else echo) * gain
    return mix


def environment(kind: str) -> np.ndarray:
    seconds = 16.0
    count = round(seconds * SR)
    mix = np.zeros((count, 2), dtype=np.float32)
    t = np.arange(count) / SR
    if kind == "jungle":
        for channel in range(2):
            mix[:, channel] = ambience_noise(seconds, .65, 250) * .025 * (1 + .20 * np.sin(TAU * t / seconds * 3 + channel))
        for index in range(23):
            at = (index * .713 + .19) % seconds
            bt = clock(.20 + (index % 3) * .045)
            pitch = 1700 + 700 * np.sin(TAU * bt * (4 + index % 3)) + index % 5 * 180
            bird = np.sin(TAU * np.cumsum(pitch) / SR) * np.sin(np.pi * np.arange(bt.size) / bt.size) ** 2
            place(mix, bird, at, .055, float(RNG.uniform(-.8, .8)))
    elif kind == "water":
        for channel in range(2):
            mix[:, channel] = ambience_noise(seconds, .62, 85) * .11 * (1 + .16 * np.sin(TAU * t / seconds * 5 + channel * 2))
        for index in range(40):
            bt = clock(.095)
            bubble = np.sin(TAU * np.cumsum(650 + 1400 * np.exp(-bt * 25)) / SR) * np.exp(-bt * 48) * (1 - np.exp(-bt * 1200))
            place(mix, bubble, index * .393, .030, float(RNG.uniform(-.8, .8)))
    elif kind == "rain":
        for channel in range(2):
            mix[:, channel] = ambience_noise(seconds, .20, 650) * .095 * (1 + .10 * np.sin(TAU * t / seconds * 2 + channel))
        for index in range(64):
            bt = clock(.025)
            drop = np.sin(TAU * (1800 + index % 7 * 120) * bt) * np.exp(-bt * 240) * (1 - np.exp(-bt * 1800))
            place(mix, drop, index * .247, .035, float(RNG.uniform(-.85, .85)))
    else:
        for index in range(8):
            bt = clock(1.3)
            pitch = 91 + index % 4 * 15 + 9 * np.sin(TAU * bt * .8)
            phase = TAU * np.cumsum(pitch) / SR
            creak = (np.sin(phase) + .18 * np.sin(phase * 3.03)) * np.sin(np.pi * bt / 1.3) ** 2
            place(mix, creak, index * 2.0 + .12, .10, (-.6 if index % 2 else .6))
            place(mix, hand_drum(260, True), index * 2.0 + .18, .055, .2)
    return mix


def signal_score(kind: str) -> np.ndarray:
    seconds = 2.3 if kind == "start" else 4.0
    mix = np.zeros((round(seconds * SR), 2), dtype=np.float32)
    notes = [74, 78, 81, 86] if kind == "start" else [81, 78, 83, 81, 78, 74, 86]
    for index, note in enumerate(notes):
        place(mix, marimba(note, 1.0), index * (.23 if kind == "start" else .33), .40, -.2 + index % 3 * .2, False)
    place(mix, hand_drum(92), .0, .28, wrap=False)
    end = round(.25 * SR)
    mix[-end:] *= np.linspace(1, 0, end)[:, None]
    return mix


def export_audio(name: str, data: np.ndarray, out: Path, loop: bool, ffmpeg: str) -> dict:
    # Linear normalization is the same at every phase; no nonlinear limiter or
    # boundary fade disturbs the continuous loop. Music leaves headroom for SFX.
    data -= np.mean(data, axis=0)
    peak = float(np.max(np.abs(data)))
    ceiling = 10 ** ((-3.0 if loop else -2.0) / 20)
    data *= ceiling / max(peak, 1e-9)
    pcm = np.rint(np.clip(data, -.999, .999) * 32767).astype(np.int16)
    path = out / f"{name}.ogg"
    with tempfile.TemporaryDirectory(prefix="lumo-jungle-audio-") as temp:
        source = Path(temp) / "source.wav"
        decoded = Path(temp) / "decoded.wav"
        wavfile.write(source, SR, pcm)
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source), "-c:a", "libvorbis", "-q:a", "6", "-metadata", "title=Dschungelherz - " + name, "-metadata", "artist=LUMO original procedural composition", str(path)], check=True)
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(path), "-c:a", "pcm_s16le", str(decoded)], check=True)
        decoded_sr, decoded_pcm = wavfile.read(decoded)
        decoded_float = decoded_pcm.astype(np.float64) / 32768
        decoded_peak = float(np.max(np.abs(decoded_float)))
        rms = float(np.sqrt(np.mean(decoded_float ** 2)))
        seam = float(np.max(np.abs(decoded_float[-1] - decoded_float[0])))
        result = subprocess.run([ffmpeg, "-hide_banner", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True, check=True)
        summary = result.stderr[result.stderr.rfind("Summary:"):].strip()
    return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size,
            "sample_rate": int(decoded_sr), "frames": len(decoded_pcm), "seconds": len(decoded_pcm) / decoded_sr,
            "loop": loop, "sample_peak_dbfs": round(20 * math.log10(max(decoded_peak, 1e-9)), 3),
            "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 3), "boundary_sample_delta": round(seam, 6),
            "ebur128_measured_summary": summary}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = {"title": "Dschungelherz – Expedition Smaragd", "bpm": BPM, "bars": BARS,
                "loop_frames": LOOP_FRAMES, "sample_rate": SR, "loop_seconds": LOOP_FRAMES / SR,
                "source": "All notes, oscillators, percussion and environmental noises synthesized by the included Python source. No external samples or recordings.",
                "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "seed": SEED, "files": []}
    for variant in ["main", "calm", "final"]:
        entry = export_audio(variant, score(variant), args.out, True, args.ffmpeg)
        manifest["files"].append(entry)
        print(json.dumps({k: entry[k] for k in ["file", "bytes", "seconds", "sample_peak_dbfs", "boundary_sample_delta"]}), flush=True)
    for kind in ["start", "finish"]:
        entry = export_audio(kind, signal_score(kind), args.out, False, args.ffmpeg)
        manifest["files"].append(entry)
        print(json.dumps({k: entry[k] for k in ["file", "bytes", "seconds"]}), flush=True)
    for kind in ["jungle", "water", "rain", "bridge"]:
        entry = export_audio(kind, environment(kind), args.out, True, args.ffmpeg)
        manifest["files"].append(entry)
        print(json.dumps({k: entry[k] for k in ["file", "bytes", "seconds"]}), flush=True)
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
