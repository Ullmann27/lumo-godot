#!/usr/bin/env python3
"""Original LUMO passage sounds (no samples, no recordings): Kiri's call "uh-uh-AAH".

Synthesised from sine partials with a pitch glide, vibrato and a soft formant
envelope. Deterministic. Usage: generate_passage_audio.py <out_dir>
Needs ffmpeg for the Ogg Vorbis encode.
"""
import math, os, struct, subprocess, sys, wave

RATE = 44100


def call(out):
    notes = [(0.00, 0.18, 330, 400, 0.55), (0.24, 0.18, 350, 430, 0.6), (0.50, 0.55, 470, 760, 0.95)]
    total = int(RATE * 1.15)
    data = [0.0] * total
    for start, dur, f0, f1, amp in notes:
        n = int(dur * RATE)
        phase = 0.0
        for i in range(n):
            t = i / n
            # rise then fall back a little: a cheeky monkey "aah"
            f = f0 + (f1 - f0) * math.sin(t * math.pi * 0.85)
            f *= 1.0 + 0.025 * math.sin(2 * math.pi * 7.5 * i / RATE)
            phase += 2 * math.pi * f / RATE
            env = min(1.0, t * 12.0) * (1.0 - t) ** 1.4
            sample = (math.sin(phase) + 0.45 * math.sin(2 * phase) + 0.22 * math.sin(3 * phase + 0.4)
                      + 0.10 * math.sin(4 * phase))
            k = int(start * RATE) + i
            if k < total:
                data[k] += sample * env * amp
    peak = max(abs(v) for v in data) or 1.0
    frames = b"".join(struct.pack("<h", int(v / peak * 0.8 * 32767)) for v in data)
    wav = out + ".wav"
    with wave.open(wav, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out + ".ogg"], check=True)
    os.remove(wav)


def _write(out, data):
    peak = max(abs(v) for v in data) or 1.0
    frames = b"".join(struct.pack("<h", int(v / peak * 0.8 * 32767)) for v in data)
    wav = out + ".wav"
    with wave.open(wav, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out + ".ogg"], check=True)
    os.remove(wav)


def tones(out, notes, total, partials=(1.0, 0.5, 0.25), decay=3.0, noise=0.0, seed=7):
    """notes: (start, duration, f0, f1). Bell-like or buzzy cue with an optional noise bed."""
    import random
    rng = random.Random(seed)
    n_total = int(RATE * total)
    data = [0.0] * n_total
    for start, dur, f0, f1 in notes:
        n = int(dur * RATE)
        phase = 0.0
        for i in range(n):
            t = i / n
            f = f0 + (f1 - f0) * t
            phase += 2 * math.pi * f / RATE
            env = min(1.0, t * 40.0) * math.exp(-decay * t)
            v = sum(a * math.sin(phase * (k + 1) * (1.0 if k == 0 else 2.01)) for k, a in enumerate(partials))
            if noise:
                v += noise * (rng.random() * 2 - 1)
            k = int(start * RATE) + i
            if k < n_total:
                data[k] += v * env
    _write(out, data)


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/kart/passage"
    os.makedirs(target, exist_ok=True)
    call(os.path.join(target, "monkey_call"))
    # Harbour boom bell, temple stone rumble, metro switch chime, lava hiss, lab robot beeps.
    tones(os.path.join(target, "gate_bell"), [(0.0, 0.5, 880, 880), (0.45, 0.6, 660, 660)], 1.1, decay=4.0)
    tones(os.path.join(target, "stone_rumble"), [(0.0, 1.0, 55, 48)], 1.0, partials=(1.0, 0.7, 0.5), decay=1.5, noise=0.6)
    tones(os.path.join(target, "switch_chime"), [(0.0, 0.18, 1046, 1046), (0.2, 0.18, 1318, 1318), (0.4, 0.3, 1568, 1568)], 0.8, decay=5.0)
    tones(os.path.join(target, "lava_hiss"), [(0.0, 1.0, 90, 70)], 1.0, partials=(0.4, 0.2), decay=1.2, noise=1.0)
    tones(os.path.join(target, "robot_beep"), [(0.0, 0.12, 990, 990), (0.18, 0.12, 990, 990), (0.36, 0.25, 1320, 1180)], 0.7, partials=(1.0, 0.3), decay=2.0)
    print("written", target)
