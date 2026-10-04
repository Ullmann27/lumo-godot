#!/usr/bin/env python3
"""Original Lumo Kart score and effects, composed/synthesized for this project.

No external recordings, samples, MIDI or melodies. Deterministic additive/FM
voices and percussion. Requires numpy, scipy and ffmpeg with libvorbis.
Run from any directory: python tools/art/generate_kart_audio.py
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/kart'
SR = 32000
RNG = np.random.default_rng(61103)
TAU = 2 * math.pi


def freq(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def voice(midi, duration, kind='pluck'):
    n = max(8, int(duration * SR))
    t = np.arange(n) / SR
    f = freq(midi)
    attack = 1 - np.exp(-t / (.045 if kind == 'pad' else .006))
    release = np.minimum((duration - t) / (.2 if kind == 'pad' else .055), 1).clip(0, 1)
    if kind == 'pad':
        x = (np.sin(TAU * f * t) + .3 * np.sin(TAU * f * 1.003 * t) + .18 * np.sin(TAU * f * 2 * t)) / 1.48
        env = attack * release ** 2
    elif kind == 'bass':
        x = np.sin(TAU * f * t) + .25 * np.sin(TAU * f * 2 * t)
        env = attack * np.exp(-t * 2.3 / duration) * release
    elif kind == 'bell':
        x = np.sin(TAU * f * t + 1.9 * np.exp(-t * 7) * np.sin(TAU * f * 2 * t)) + .13 * np.sin(TAU * f * 3 * t) * np.exp(-t * 8)
        env = attack * np.exp(-t * 3.5 / duration) * release
    elif kind == 'marimba':
        x = np.sin(TAU * f * t) + .42 * np.sin(TAU * f * 4 * t) * np.exp(-t * 18) + .12 * np.sin(TAU * f * 7 * t) * np.exp(-t * 30)
        env = attack * np.exp(-t * 5 / duration) * release
    else:
        x = sum(np.sin(TAU * f * h * t) * np.exp(-t * (3 + h * 1.6)) / h ** 1.7 for h in range(1, 7))
        env = attack * release
    return (x * env).astype(np.float64)


def percussion(kind):
    duration = {'kick': .26, 'snare': .14, 'hat': .065, 'shaker': .11}[kind]
    t = np.arange(int(duration * SR)) / SR
    noise = RNG.normal(size=len(t))
    if kind == 'kick':
        phase = TAU * (45 * t + 8 * (1 - np.exp(-t * 24)))
        x = np.sin(phase) * np.exp(-t * 18)
    elif kind == 'snare':
        noise = sosfilt(butter(2, [650, 6500], btype='bandpass', fs=SR, output='sos'), noise)
        x = (.45 * noise + .25 * np.sin(TAU * 190 * t)) * np.exp(-t * 28)
    else:
        noise = sosfilt(butter(2, 6500 if kind == 'hat' else 3800, btype='highpass', fs=SR, output='sos'), noise)
        x = noise * np.exp(-t * (60 if kind == 'hat' else 32)) * .35
    x *= np.minimum(t / .0015, 1) * np.minimum((duration - t) / .006, 1)
    return x


def add(buffer, wave, start, gain=1, pan=0):
    """Circular placement folds all release/reverb tails into the loop head."""
    at = int(start * SR)
    idx = (at + np.arange(len(wave))) % len(buffer)
    angle = (pan + 1) * math.pi / 4
    buffer[idx, 0] += wave * gain * math.cos(angle)
    buffer[idx, 1] += wave * gain * math.sin(angle)


THEMES = {
    'garage': dict(bpm=100, root=62, scale=[0, 2, 4, 5, 7, 9, 11], chords=[0, 5, 3, 4], lead='pluck', mood='Quiet glass garage; relaxed plucked keys and airy chords',
                   melody=[0, 2, 4, 2, 1, 2, 5, 4, 3, 2, 1, 4, 2, 1, 6, 4]),
    'sonnenhafen': dict(bpm=128, root=65, scale=[0, 2, 4, 5, 7, 9, 11], chords=[0, 4, 5, 3], lead='marimba', mood='Sunny harbor; playful wooden melody and gently bouncing bass',
                       melody=[0, 2, 4, 5, 4, 2, 1, 2, 5, 4, 2, 0, 1, 3, 2, 1]),
    'zauberwald': dict(bpm=112, root=62, scale=[0, 2, 3, 5, 7, 9, 10], chords=[0, 3, 6, 0], lead='bell', mood='Enchanted forest; soft celesta and suspended Dorian colors',
                      melody=[4, 6, 7, 4, 2, 3, 1, 0, 2, 4, 6, 5, 4, 2, 1, 4]),
    'bergwelt': dict(bpm=122, root=67, scale=[0, 2, 4, 5, 7, 9, 11], chords=[0, 3, 1, 4], lead='pluck', mood='High mountain air; open plucked strings and small bright bells',
                    melody=[0, 4, 7, 6, 4, 2, 3, 4, 5, 7, 6, 4, 3, 1, 2, 4]),
    'holo_city': dict(bpm=136, root=57, scale=[0, 2, 3, 5, 7, 8, 10], chords=[0, 5, 2, 6], lead='bell', mood='Holographic city; rounded FM arpeggios and a light electronic pulse',
                     melody=[0, 4, 2, 6, 4, 7, 6, 4, 2, 5, 4, 1, 6, 4, 2, 1]),
}


def note(cfg, degree, octave=0):
    return cfg['root'] + cfg['scale'][degree % 7] + 12 * (degree // 7 + octave)


def compose(name, cfg):
    beat = 60 / cfg['bpm']
    buffer = np.zeros((round(32 * beat * SR), 2), dtype=np.float64)
    for bar in range(8):
        root_degree = cfg['chords'][bar % 4]
        for offset in [0, 2, 4, 6]:
            add(buffer, voice(note(cfg, root_degree + offset, -1), 4.3 * beat, 'pad'), bar * 4 * beat, .065, (offset - 3) / 5)
        for step in range(4):
            degree = root_degree + (4 if step == 2 else 0)
            add(buffer, voice(note(cfg, degree, -2), beat * .68, 'bass'), (bar * 4 + step) * beat, .24)
            if step in [0, 2] or name == 'holo_city':
                add(buffer, percussion('kick'), (bar * 4 + step) * beat, .2 if name != 'garage' else .1)
            if step in [1, 3]:
                add(buffer, percussion('snare'), (bar * 4 + step) * beat, .11 if name != 'garage' else .035, .12)
            add(buffer, percussion('shaker' if name in ['garage','zauberwald'] else 'hat'), (bar * 4 + step + .5) * beat, .09, -.2)
        for step in range(4):
            melody_index = (bar % 4) * 4 + step
            degree = cfg['melody'][melody_index]
            # Original call/answer phrase: second four bars rise then resolve.
            if bar >= 4 and step == 2:
                degree += 2 if bar < 6 else -1
            when = (bar * 4 + step + (0.25 if step == 1 else 0)) * beat
            wave = voice(note(cfg, degree, 0 if name != 'holo_city' else 1), beat * 1.2, cfg['lead'])
            gain = .20 if name != 'garage' else .145
            add(buffer, wave, when, gain, -.15 if step % 2 else .15)
            add(buffer, wave, when + beat * .75, gain * .18, .65)
            add(buffer, wave, when + beat * 1.5, gain * .075, -.65)
        if name in ['holo_city', 'bergwelt']:
            for step in range(8):
                pitch = note(cfg, root_degree + [0, 2, 4, 2][step % 4], 0)
                add(buffer, voice(pitch, beat * .6, 'marimba'), (bar * 4 + step * .5) * beat, .055, .5 if step % 2 else -.5)
    # Circular stereo reflections retain continuity across the file boundary.
    reflected = buffer.copy()
    for delay, gain in [(.037, .09), (.073, .06), (.113, .04)]:
        reflected += np.roll(buffer[:, ::-1], int(delay * SR), axis=0) * gain
    return reflected


def effect(kind):
    durations = dict(start=.9, boost=.8, drift=.45, item=.65, finish=2.0, countdown=.22, collision=.18)
    duration = durations[kind]
    buffer = np.zeros((int(duration * SR), 2))
    if kind in ['start', 'item', 'finish', 'countdown']:
        phrases = {'start': [(0,74),(.12,78),(.24,81),(.36,86)], 'item': [(0,81),(.085,86),(.17,90)], 'finish': [(0,74),(.16,78),(.32,81),(.55,86),(1.05,90),(1.22,86)], 'countdown': [(0,74)]}
        for when, midi in phrases[kind]:
            wave = voice(midi, min(.55, duration - when), 'bell')
            add(buffer, wave, when, .38, 0)
    else:
        t = np.arange(len(buffer)) / SR
        smooth_noise = sosfilt(butter(2, 3800, fs=SR, output='sos'), RNG.normal(size=len(t)))
        env = np.sin(np.pi * t / duration) ** 2
        if kind == 'boost':
            phase = TAU * np.cumsum(180 + 900 * (t / duration) ** 1.5) / SR
            mono = (.4 * smooth_noise + .2 * np.sin(phase)) * env
        elif kind == 'drift':
            mono = (smooth_noise * .3 + .1 * np.sin(TAU * 650 * t)) * env
        else:
            mono = (smooth_noise * .2 + .3 * np.sin(TAU * 82 * t)) * np.exp(-t * 25) * np.minimum(t / .004, 1)
        buffer[:, 0] = buffer[:, 1] = mono
    # All one-shots have silent boundaries, including the victory tail.
    fade = min(int(.02 * SR), len(buffer) // 3)
    buffer[:fade] *= np.linspace(0, 1, fade)[:, None]
    buffer[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return buffer


def export(name, audio, loop, metadata):
    # Peak-normalized to -3 dBFS with smooth saturation; runtime gains keep
    # music well below foreground guidance and effects.
    audio -= audio.mean(axis=0)
    audio = np.tanh(audio * 1.15)
    peak = np.max(np.abs(audio))
    if peak:
        audio *= .707 / peak
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'source.wav'
        wavfile.write(wav, SR, np.round(audio * 32767).astype('<i2'))
        dest = OUT / (name + '.ogg')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '3', '-fflags', '+bitexact', '-flags:a', '+bitexact', '-map_metadata', '-1', '-metadata', 'artist=Lumo project original synthesis', '-metadata', 'title=' + name, str(dest)], check=True)
    metadata.update(file=dest.name, seconds=round(len(audio) / SR, 5), sample_rate=SR, channels=2, peak_dbfs=round(20 * math.log10(np.max(np.abs(audio))), 3), seam_delta=round(float(np.max(np.abs(audio[-1] - audio[0]))), 6), loop=loop, bytes=dest.stat().st_size, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    return metadata


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest=[]
    for name, cfg in THEMES.items():
        manifest.append(export(name, compose(name, cfg), True, {'bpm': cfg['bpm'], 'bars': 8, 'description': cfg['mood']}))
    for kind in ['start','boost','drift','item','finish','countdown','collision']:
        manifest.append(export(kind, effect(kind), False, {'description': 'Original synthesized ' + kind + ' cue'}))
    (OUT / 'manifest.json').write_text(json.dumps({'generator': 'tools/art/generate_kart_audio.py', 'seed': 61103, 'original_samples_only': True, 'assets': manifest}, indent=2) + '\n')
    print(json.dumps({'files': len(manifest), 'total_bytes':sum(m['bytes'] for m in manifest), 'max_loop_seam_delta':max(m['seam_delta'] for m in manifest if m['loop'])}))

if __name__ == '__main__':
    main()
