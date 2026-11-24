#!/usr/bin/env python3
"""Lumo Klangwelt – Musik, Atmosphären und Bedientöne für alle Spiele
(außer den Fahrklängen von Lumo Kart und Lumo Lauf, die eigene Klänge haben).

Alles ist für Lumo neu komponiert und synthetisiert (siehe klangwelt_synth.py):
keine Aufnahmen, keine Samples, keine fremden Melodien. Fester Seed, daher
reproduzierbar. Benötigt nur numpy und ffmpeg mit libvorbis. Es entstehen keine
WAV-Zwischendateien: Audio wird direkt per Pipe an ffmpeg übergeben.

Das Lumo-Motiv (Stufen so–do'–ti–so · la–so–mi) ist die Erkennungsmelodie des
Home-Themas und klingt in jedem anderen Stück in dessen Tonart und Takt an.

Aufruf:
  python tools/art/generate_klangwelt_audio.py              # alles erzeugen + messen
  python tools/art/generate_klangwelt_audio.py --only hub   # einzelne Datei(en)
  python tools/art/generate_klangwelt_audio.py --measure    # nur messen
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import klangwelt_synth as ks  # noqa: E402
from klangwelt_synth import (  # noqa: E402
    DORIAN, MAJOR, SR, TAU, Song, adsr, bandpass, bell, brass, brown, celesta, clarinet, epiano,
    fade_edges, flute, gen_line, glock, guitar, harp, highpass, horn, hz, kalimba, lowpass, marimba,
    musicbox, nsamp, ocarina, pink, pizz, soft_bass, square_lead, strings, synth_bass, tax,
    tremolo_strings, upright, vibes, warm_pad, whistle_lead,
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/klangwelt'
DOC = ROOT / 'docs/KLANGWELT_MESSWERTE.md'
SEED = 20261118
MOTIF = '4:.5 7:.5 6:.5 4:.5 5:1 4:.5 2:.5'  # Lumo-Motiv, ein 4/4-Takt
MUSIC_LUFS = -16.0
AMBIENCE_LUFS = -27.0
PEAK = 10 ** (-1.5 / 20)


# ── Hilfen für Begleitung ─────────────────────────────────────────────────

def chord_spans(song: Song, prog: list[str]):
    """'ii-V' teilt einen Takt. Liefert (startbeat, beats, akkordname)."""
    spans = []
    for bar, name in enumerate(prog):
        parts = name.split('-')
        each = song.bpb / len(parts)
        for i, part in enumerate(parts):
            spans.append((bar * song.bpb + i * each, each, part))
    return spans


def in_bars(beat: float, song: Song, bars) -> bool:
    return bars is None or int(beat // song.bpb) in bars


def pad(song, inst, prog, octave=-1, gain=0.5, bars=None, verb=0.35, top=True):
    for start, beats, name in chord_spans(song, prog):
        if not in_bars(start, song, bars):
            continue
        tones = song.chord(name, octave)
        voicing = [tones[0]] + [t + 12 for t in tones[1:3]] + ([tones[3] + 12] if len(tones) > 3 else [])
        if top:
            voicing = tones[:]
        for i, m in enumerate(voicing):
            song.note(inst, m, start, beats, 0.7, gain / len(voicing) ** 0.5, pan=(i - 1.5) * 0.25, verb=verb)


def arp(song, inst, prog, octave=0, pattern=(0, 1, 2, 3, 2, 1, 2, 3), step=0.5, gain=0.4, bars=None,
        verb=0.3, pan=0.25, length=1.0, vel=0.7):
    for start, beats, name in chord_spans(song, prog):
        if not in_bars(start, song, bars):
            continue
        tones = song.chord(name, octave)
        ext = tones[:3] + [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24]
        count = int(round(beats / step))
        for i in range(count):
            idx = pattern[i % len(pattern)]
            song.note(inst, ext[idx], start + i * step, step * length, vel * (1.0 if i % 2 == 0 else 0.82),
                      gain, pan * (1 if (i // 2) % 2 else -1), verb)


def block(song, inst, prog, onsets, length, octave=-1, gain=0.4, bars=None, verb=0.25, vel=0.7, pan=0.0,
          drop_root=False):
    for start, beats, name in chord_spans(song, prog):
        if not in_bars(start, song, bars):
            continue
        tones = song.chord(name, octave)
        if drop_root:
            tones = tones[1:] + [tones[0] + 12]
        for onset in onsets:
            if onset >= beats - 1e-6:
                continue
            for i, m in enumerate(tones):
                song.note(inst, m, start + onset, length, vel, gain / len(tones) ** 0.5,
                          pan + (i - 1) * 0.15, verb)


def bass(song, inst, prog, style='root_fifth', octave=-2, gain=0.8, bars=None, verb=0.04):
    spans = chord_spans(song, prog)
    for i, (start, beats, name) in enumerate(spans):
        if not in_bars(start, song, bars):
            continue
        tones = song.chord(name, octave)
        root, third, fifth = tones[0], tones[1], tones[2]
        nxt = song.chord(spans[(i + 1) % len(spans)][2], octave)[0]
        if style == 'root_fifth':
            pts = [(0, root, 1.5), (beats / 2, fifth - 12 if fifth - 12 >= root - 7 else fifth, 1.5)] if beats >= 2 else [(0, root, beats)]
        elif style == 'whole':
            pts = [(0, root, beats)]
        elif style == 'half':
            pts = [(0, root, beats / 2), (beats / 2, fifth - 12, beats / 2)] if beats >= 2 else [(0, root, beats)]
        elif style == 'bounce':
            pts = [(0, root, 0.75), (1.5, root + 12, 0.4), (2, fifth, 0.75), (3.5, root, 0.4)]
            pts = [p for p in pts if p[0] < beats]
        elif style == 'eighths':
            pts = [(k * 0.5, root if k % 4 != 3 else fifth, 0.4) for k in range(int(beats * 2))]
        elif style == 'walking':
            approach = nxt - 1 if (nxt - fifth) > 0 else nxt + 1
            line = [root, third, fifth, approach] if beats >= 4 else [root, fifth]
            pts = [(k, m, 0.95) for k, m in enumerate(line[: int(beats)])]
        elif style == 'waltz':
            pts = [(0, root, 1.0)]
        elif style == 'six8':
            pts = [(0, root, 2.0), (3, fifth - 12, 2.0)] if beats >= 6 else [(0, root, beats)]
        elif style == 'staccato':
            pts = [(0, root, 0.4), (1, root, 0.3), (1.5, fifth - 12, 0.3), (2, root, 0.4), (3, third, 0.3), (3.5, fifth - 12, 0.3)]
            pts = [p for p in pts if p[0] < beats]
        else:
            raise ValueError(style)
        for off, m, dur in pts:
            song.note(inst, m, start + off, dur, 0.8, gain, 0.0, verb)


def every_bar(song, bars=None):
    for bar in range(song.bars):
        if bars is None or bar in bars:
            yield bar, bar * song.bpb


def drums_pop(song, bars=None, gain=1.0, clap_=True, hats=True, shake=True, kick_extra=True):
    for bar, b in every_bar(song, bars):
        song.drum('kick', ks.kick, b, 0.9 * gain)
        song.drum('kick', ks.kick, b + 2, 0.8 * gain)
        if kick_extra and bar % 2 == 1:
            song.drum('kick', ks.kick, b + 2.5, 0.5 * gain)
        if clap_:
            song.drum('clap', ks.clap, b + 1, 0.55 * gain, pan=0.05, verb=0.2)
            song.drum('clap', ks.clap, b + 3, 0.55 * gain, pan=-0.05, verb=0.2)
        if hats:
            for k in range(8):
                song.drum('hat', ks.hat, b + k * 0.5, (0.42 if k % 2 else 0.3) * gain, pan=0.3)
        if shake:
            for k in range(16):
                song.drum('shaker', ks.shaker, b + k * 0.25, (0.22 if k % 2 else 0.14) * gain, pan=-0.35)


def drums_swing(song, bars=None, gain=1.0):
    for bar, b in every_bar(song, bars):
        for off, g in [(0, 0.5), (1, 0.6), (1.5, 0.35), (2, 0.5), (3, 0.6), (3.5, 0.35)]:
            song.drum('ride', ks.ride, b + off, g * gain, pan=0.35, verb=0.12)
        song.drum('brush', lambda r: ks.snare(r, brush=True), b + 1, 0.5 * gain, pan=-0.1)
        song.drum('brush', lambda r: ks.snare(r, brush=True), b + 3, 0.5 * gain, pan=-0.1)
        song.drum('kick_soft', lambda r: ks.kick(r, soft=True), b, 0.45 * gain)
        if bar % 4 == 3:
            song.add(ks.brush_sweep(song.rng, 0.9), b + 2, 0.8 * gain, pan=-0.2, verb=0.1)


def drums_hand(song, bars=None, gain=1.0, shake=True):
    pattern = [(0, 300, 0.7), (0.75, 420, 0.4), (1.5, 300, 0.5), (2, 220, 0.7), (2.75, 420, 0.4), (3.5, 300, 0.5)]
    for bar, b in every_bar(song, bars):
        for off, pitch, g in pattern:
            song.drum(f'bongo{pitch}', lambda r, p=pitch: ks.bongo(r, p), b + off, g * gain, pan=0.3 if pitch > 300 else -0.2)
        if shake:
            for k in range(8):
                song.drum('shaker', ks.shaker, b + k * 0.5, (0.25 if k % 2 else 0.16) * gain, pan=-0.35)


def drums_soft(song, bars=None, gain=1.0):
    for bar, b in every_bar(song, bars):
        song.drum('kick_soft', lambda r: ks.kick(r, soft=True), b, 0.5 * gain)
        song.drum('brush', lambda r: ks.snare(r, brush=True), b + 1, 0.32 * gain)
        song.drum('brush', lambda r: ks.snare(r, brush=True), b + 3, 0.32 * gain)
        for k in range(8):
            song.drum('shaker', ks.shaker, b + k * 0.5, (0.18 if k % 2 else 0.1) * gain, pan=-0.3)


def triangle_at(song, bars, beat=0.0, gain=0.6):
    for bar in bars:
        song.drum('triangle', ks.triangle, bar * song.bpb + beat, gain, pan=0.4, verb=0.4, variants=2)


def chord_steps(song: Song, prog: list[str]) -> list[list[int]]:
    """Akkordtöne eines Takts als Skalenstufen (für gen_line)."""
    out = []
    for name in prog:
        first = name.split('-')[0]
        tones = song.chord(first, 0)
        steps = []
        for m in tones[:3]:
            rel = (m - song.key) % 12
            if rel in song.scale:
                steps.append(song.scale.index(rel))
        out.append(steps or [0, 2, 4])
    return out


# ── Musikstücke ───────────────────────────────────────────────────────────

def song_lumo_theme():
    s = Song('lumo_theme', 96, 4, 16, 65, MAJOR, seed=SEED + 1)
    prog = ['I', 'IV', 'vi', 'V', 'I', 'IV', 'ii-V', 'I', 'vi', 'IV', 'I', 'V', 'IV', 'V', 'I', 'V']
    a = (MOTIF + ' | 3:1 2:.5 3:.5 5:2 | 5:.5 7:.5 6:.5 5:.5 4:1 2:1 | 1:1.5 2:.5 4:2 | ' + MOTIF +
         ' | 3:1 5:.5 3:.5 7:2 | 5:1 3:1 4:1 1:1 | 0:3 r:1')
    b = ('2:1 4:1 5:1.5 4:.5 | 3:1 5:1 7:1.5 5:.5 | 4:.5 7:.5 6:.5 4:.5 2:2 | 1:1 4:1 6:2 | '
         '5:1 3:1 0:1 3:1 | 4:1.5 3:.5 2:1 1:1 | 0:2 4:1 2:1 | 1:2 r:2')
    s.melody(flute, a, 0, vel=0.85, gain=0.9, pan=0.05, verb=0.32)
    s.melody(flute, b, 32, vel=0.75, gain=0.6, pan=0.05, verb=0.32)
    s.melody(musicbox, b, 32, octave=1, vel=0.8, gain=0.55, pan=-0.15, verb=0.4)
    arp(s, harp, prog, octave=-1, gain=0.32)
    pad(s, warm_pad, prog, octave=-1, gain=0.4)
    bass(s, pizz, prog, 'root_fifth', gain=0.9)
    drums_soft(s, bars=range(4, 16), gain=0.7)
    triangle_at(s, [0, 8])
    return s, dict(key='F-Dur', mood='Lumo-Thema: Erkennungsmelodie, warm und neugierig')


def song_hub():
    s = Song('hub', 112, 4, 32, 72, MAJOR, seed=SEED + 2)
    pa = ['I', 'V', 'vi', 'IV', 'I', 'V', 'IV-V', 'I']
    pb = ['IV', 'V', 'iii', 'vi', 'I', 'IV', 'ii-V', 'V']
    prog = pa + pa + pb + pa
    a = ('0:.5 2:.5 4:.5 2:.5 7:1 4:1 | 6:.5 4:.5 1:.5 4:.5 6:1 r:1 | 5:.5 7:.5 9:.5 7:.5 5:1 2:1 | '
         '3:1 5:.5 3:.5 0:1 r:1 | 0:.5 2:.5 4:.5 2:.5 7:1 9:1 | 8:.5 6:.5 4:.5 6:.5 8:1 r:1 | '
         '7:1 5:1 4:1 6:1 | 7:2 r:1 4:.5 6:.5')
    b = ('5:1.5 3:.5 0:1 3:1 | 4:1.5 1:.5 -1:1 1:1 | 2:1 4:1 6:1 4:1 | 5:2 r:1 4:.5 5:.5 | ' + MOTIF +
         ' | 3:1 5:1 7:2 | 5:1 3:1 4:1 6:1 | 8:1 6:1 4:1 r:1')
    s.melody(whistle_lead, a, 0, octave=-1, vel=0.85, gain=0.75, pan=0.1)
    s.melody(marimba, a, 32, vel=0.9, gain=0.9, pan=-0.1)
    s.melody(whistle_lead, a, 32, octave=-1, vel=0.7, gain=0.35, pan=0.15)
    s.melody(ocarina, b, 64, octave=-1, vel=0.8, gain=0.8, pan=0.05)
    s.melody(marimba, a, 96, vel=0.9, gain=0.85, pan=-0.1)
    counter = gen_line(s, chord_steps(s, pa), [1, 1, 1, 1], -3, 5, 2, s.rng)
    s.melody(flute, counter, 96, octave=-1, vel=0.6, gain=0.4, pan=0.3, verb=0.3)
    block(s, guitar, prog, [0.5, 1.5, 2.5, 3.5], 0.3, octave=-1, gain=0.42, vel=0.6, pan=-0.2, drop_root=True)
    bass(s, synth_bass, prog, 'bounce', octave=-3, gain=0.75)
    pad(s, warm_pad, prog, octave=-2, gain=0.22, bars=range(16, 32))
    drums_pop(s, bars=range(0, 32), gain=0.7)
    for bar in [0, 8, 24]:
        s.melody(glock, '7:.25 9:.25 11:.25 14:1.25', bar * 4 + 3, vel=0.6, gain=0.35, pan=0.4, verb=0.5)
    return s, dict(key='C-Dur', mood='Spielewelt: einladend, verspielt, federnder Pop')


def song_cards():
    s = Song('cards', 100, 4, 24, 70, MAJOR, swing=0.12, seed=SEED + 3)
    pa = ['Imaj7', 'vi7', 'ii7', 'V7', 'Imaj7', 'vi7', 'ii7-V7', 'Imaj7']
    pa2 = pa[:7] + ['I6']
    pb = ['IVmaj7', 'iv7', 'iii7', 'vi7', 'ii7', 'V7', 'I6', 'V7']
    prog = pa + pa2 + pb
    a = (MOTIF + ' | 0:1.5 2:.5 4:1 r:1 | 5:.5 3:.5 1:.5 3:.5 5:1 7:1 | 6:1.5 4:.5 3:2 | '
         '2:.5 4:.5 6:.5 7:.5 9:1 7:1 | 5:1 4:.5 2:.5 0:2 | 3:.5 5:.5 7:.5 5:.5 6:.5 4:.5 3:.5 1:.5 | 2:2 r:2')
    a2 = a.rsplit('|', 1)[0] + '| 0:2 r:2'
    s.melody(vibes, a, 0, octave=-1, vel=0.85, gain=0.85, pan=0.15, verb=0.28)
    s.melody(clarinet, a2, 32, octave=-1, vel=0.8, gain=0.75, pan=-0.05, verb=0.25)
    counter = gen_line(s, chord_steps(s, pa2), [2, 1, 1], -2, 6, 4, s.rng)
    s.melody(vibes, counter, 32, octave=-1, vel=0.55, gain=0.32, pan=0.3)
    line_b = gen_line(s, chord_steps(s, pb), [1.5, .5, 1, 1], -1, 8, 4, s.rng)
    s.melody(clarinet, line_b, 64, octave=-1, vel=0.75, gain=0.7, pan=-0.05)
    block(s, epiano, prog, [0, 1.5], 0.9, octave=-1, gain=0.42, vel=0.55, pan=-0.15, drop_root=True)
    bass(s, upright, prog, 'walking', octave=-3, gain=0.95)
    drums_swing(s, gain=0.75)
    return s, dict(key='B-Dur', mood='Kartentisch: gemütlicher Swing mit Vibrafon und Klarinette')


def song_memory():
    s = Song('memory', 76, 4, 16, 67, MAJOR, seed=SEED + 4, humanize=0.004)
    prog = ['Imaj7', 'IVmaj7', 'vi7', 'IVmaj7', 'Imaj7', 'IVmaj7', 'ii7', 'Vsus',
            'vi7', 'IVmaj7', 'Imaj7', 'V', 'IVmaj7', 'ii7', 'Vsus', 'V']
    a = ('4:2 2:1 4:1 | 5:3 3:1 | 2:2 0:1 2:1 | 3:4 | 4:2 7:1 6:1 | 5:3 3:1 | 3:2 5:1 3:1 | 4:4 | '
         'r:4 | r:2 2:1 4:1 | ' + MOTIF + ' | 4:4 | 5:2 3:2 | 3:2 1:2 | r:4 | r:2 1:1 2:1')
    s.melody(celesta, a, 0, vel=0.7, gain=0.75, pan=0.1, verb=0.45)
    arp(s, musicbox, prog, octave=0, pattern=(0, 2, 1, 3, 2, 1, 3, 2), gain=0.24, vel=0.55, verb=0.45)
    pad(s, warm_pad, prog, octave=-1, gain=0.42, verb=0.45)
    bass(s, soft_bass, prog, 'half', octave=-2, gain=0.6)
    for bar, b in every_bar(s, range(8, 16)):
        for k in range(4):
            s.drum('shaker', ks.shaker, b + k + 0.5, 0.09, pan=-0.3)
    return s, dict(key='G-Dur', mood='Memory: ruhig und konzentriert, Spieluhr und Celesta')


def song_connect_four():
    s = Song('connect_four', 116, 4, 28, 74, MAJOR, seed=SEED + 5)
    pa = ['I', 'IV', 'I', 'V', 'vi', 'IV', 'V', 'I']
    pb = ['ii', 'V', 'iii', 'vi', 'IV', 'V', 'I-vi', 'ii-V']
    tag = ['IV', 'V', 'IV', 'V']
    prog = pa + pb + pa + tag
    a = ('0:.5 0:.5 4:.5 4:.5 5:.5 4:.5 2:1 | 3:.5 3:.5 5:.5 5:.5 7:.5 5:.5 3:1 | ' + MOTIF +
         ' | 6:.5 4:.5 1:.5 4:.5 6:2 | 5:.5 7:.5 5:.5 2:.5 0:1 2:1 | 3:.5 5:.5 7:.5 5:.5 3:1 r:1 | '
         '4:.5 6:.5 8:.5 6:.5 4:1 1:1 | 0:2 r:2')
    s.melody(marimba, a, 0, octave=-1, vel=0.9, gain=0.9, pan=0.1)
    line_b = gen_line(s, chord_steps(s, pb), [.5, .5, 1, .5, .5, 1], -3, 5, 0, s.rng)
    s.melody(kalimba, line_b, 32, vel=0.85, gain=0.8, pan=-0.1)
    s.melody(marimba, a, 64, octave=-1, vel=0.9, gain=0.85, pan=0.1)
    s.melody(pizz, a, 64, octave=0, vel=0.7, gain=0.35, pan=-0.3)
    block(s, pizz, prog, [0.5, 1.5, 2.5, 3.5], 0.25, octave=-1, gain=0.5, vel=0.6, drop_root=True)
    bass(s, synth_bass, prog, 'staccato', octave=-3, gain=0.75)
    drums_hand(s, gain=0.75)
    for bar, b in every_bar(s):
        s.drum('wood_hi', lambda r: ks.woodblock(r, 1250), b + 1, 0.3, pan=0.4)
        s.drum('wood_lo', lambda r: ks.woodblock(r, 900), b + 3, 0.3, pan=-0.4)
        if bar >= 24:
            for k in range(4):
                s.drum('snare', ks.snare, b + 2 + k * 0.5, 0.15 + 0.08 * k + 0.05 * (bar - 24))
    return s, dict(key='D-Dur', mood='Vier gewinnt: verschmitzt, Marimba und Pizzicato, Tick-Tack')


def _quiz_prog():
    pa = ['I', 'vi', 'IV', 'V', 'I', 'vi', 'ii', 'V']
    pa2 = ['I', 'vi', 'IV', 'V', 'I', 'vi', 'ii-V', 'I']
    pb = ['IV', 'V', 'iii', 'vi', 'ii', 'V', 'IV', 'V']
    return pa + pa2 + pb + pa2


def song_quiz():
    s = Song('quiz', 120, 4, 32, 75, MAJOR, seed=SEED + 6)
    prog = _quiz_prog()
    a = ('0:.5 4:.5 7:1 7:.5 6:.5 7:1 | 5:1.5 4:.5 2:2 | 3:.5 5:.5 7:1 7:.5 8:.5 9:1 | 8:1.5 7:.5 6:1 4:1 | ' +
         MOTIF + ' | 0:1 2:1 5:2 | 3:1 5:1 8:1 7:1 | 6:2 r:2')
    a2 = a.rsplit('|', 2)[0] + '| 3:1 5:1 4:1 6:1 | 7:3 r:1'
    s.melody(brass, a, 0, octave=-1, vel=0.9, gain=0.75, pan=0.05, verb=0.22)
    s.melody(square_lead, a2, 32, octave=-1, vel=0.8, gain=0.55, pan=0.1)
    s.melody(brass, a2, 32, octave=-2, vel=0.7, gain=0.4, pan=-0.1)
    line_b = gen_line(s, chord_steps(s, prog[16:24]), [1, .5, .5, 1, 1], -2, 7, 2, s.rng)
    s.melody(square_lead, line_b, 64, octave=-1, vel=0.75, gain=0.55, pan=0.05)
    s.melody(brass, a2, 96, octave=-1, vel=0.95, gain=0.75, pan=0.05, verb=0.22)
    block(s, brass, prog, [1.5, 3.5], 0.35, octave=-1, gain=0.45, vel=0.75, drop_root=True)
    pad(s, strings, prog, octave=-1, gain=0.3)
    bass(s, synth_bass, prog, 'eighths', octave=-3, gain=0.7)
    for bar, b in every_bar(s):
        for k in range(4):
            s.drum('kick', ks.kick, b + k, 0.75)
        s.drum('clap', ks.clap, b + 1, 0.5, verb=0.2)
        s.drum('clap', ks.clap, b + 3, 0.5, verb=0.2)
        for k in range(4):
            s.drum('ohat', lambda r: ks.hat(r, True), b + k + 0.5, 0.22, pan=0.3)
        for k in range(16):
            s.drum('tamb', ks.tambourine, b + k * 0.25, 0.1 if k % 2 else 0.16, pan=-0.35)
        if bar % 8 == 7:
            s.add(ks.cymbal_swell(s.rng, s.seconds(4)), b, 0.8, verb=0.2)
    return s, dict(key='Es-Dur', mood='Quiz-Studio: Show-Thema mit Bläsern, Four-on-the-floor')


def song_quiz_tension():
    s = Song('quiz_tension', 120, 4, 32, 75, MAJOR, seed=SEED + 7)
    prog = _quiz_prog()
    for start, beats, name in chord_spans(s, prog):
        tones = s.chord(name, 0)
        for m in (tones[0], tones[2]):
            s.note(tremolo_strings, m, start, beats, 0.7, 0.5, pan=0.3 if m == tones[2] else -0.3, verb=0.2)
    for bar, b in every_bar(s):
        root = s.chord(prog[bar].split('-')[0], -3)[0]
        s.add(ks.timpani(s.rng, root + 12), b, 0.55, verb=0.15)
        s.add(ks.timpani(s.rng, root + 12), b + 2, 0.4, verb=0.15)
        for k in range(8):
            pitch = 2100 if k % 2 == 0 else 1750
            s.drum(f'tick{pitch}', lambda r, p=pitch: ks.woodblock(r, p), b + k * 0.5, 0.22, pan=0.25 if k % 2 else -0.25)
        if bar % 4 == 3:
            s.add(ks.cymbal_swell(s.rng, s.seconds(4)), b, 0.6, verb=0.2)
    return s, dict(key='Es-Dur', mood='Quiz-Spannungsschicht: Uhr-Ticken, Tremolo, Pauken (synchron)')


def _treasure_prog():
    pa = ['i', 'IV', 'i', 'VII', 'i', 'IV', 'VII', 'VII']
    pb = ['III', 'VII', 'IV', 'i', 'III', 'VII', 'IV', 'v']
    return pa + pa + pb + pa


def song_treasure():
    s = Song('treasure', 96, 4, 32, 62, DORIAN, seed=SEED + 8)
    prog = _treasure_prog()
    a = ('4:1.5 3:.5 2:1 0:1 | 1:.5 2:.5 3:1 5:2 | ' + MOTIF + ' | 6:2 r:1 4:.5 6:.5 | 7:1.5 6:.5 4:1 2:1 | '
         '3:1 5:1 8:1 7:1 | 6:1.5 4:.5 1:1 2:1 | 1:3 r:1')
    s.melody(flute, a, 0, octave=1, vel=0.75, gain=0.7, pan=0.1, verb=0.35)
    s.melody(kalimba, a, 32, octave=1, vel=0.8, gain=0.6, pan=-0.15, verb=0.35)
    line_b = gen_line(s, chord_steps(s, prog[16:24]), [2, 1, 1], -1, 8, 4, s.rng)
    s.melody(ocarina, line_b, 64, octave=1, vel=0.75, gain=0.7, pan=0.05, verb=0.35)
    s.melody(flute, a, 96, octave=1, vel=0.8, gain=0.7, pan=0.1, verb=0.35)
    arp(s, marimba, prog, octave=0, pattern=(0, 2, 1, 3, 0, 2, 1, 3), gain=0.32, vel=0.6, verb=0.3)
    pad(s, warm_pad, prog, octave=-1, gain=0.35, verb=0.4)
    bass(s, pizz, prog, 'root_fifth', octave=-2, gain=0.85)
    drums_hand(s, gain=0.55, shake=True)
    return s, dict(key='D-Dorisch', mood='Schatzsuche: Erkundung, Kalimba, Flöte, Handtrommeln')


def song_treasure_discovery():
    s = Song('treasure_discovery', 96, 4, 32, 62, DORIAN, seed=SEED + 9)
    prog = _treasure_prog()
    line = gen_line(s, chord_steps(s, prog), [2, 2], -2, 6, 0, s.rng)
    s.melody(horn, line, 0, octave=0, vel=0.85, gain=0.75, pan=-0.15, verb=0.3)
    block(s, brass, prog, [0, 2.5], 0.6, octave=-1, gain=0.42, vel=0.8, pan=0.15)
    arp(s, harp, prog, octave=0, pattern=(0, 1, 2, 3, 4, 5, 6, 5), step=0.25, gain=0.2, vel=0.6, verb=0.35)
    for bar, b in every_bar(s):
        root = s.chord(prog[bar], -3)[0]
        s.add(ks.timpani(s.rng, root + 12), b, 0.6, verb=0.18)
        s.add(ks.timpani(s.rng, root + 12), b + 2.5, 0.35, verb=0.18)
        for k in range(8):
            s.drum('tamb', ks.tambourine, b + k * 0.5, 0.2 if k % 2 else 0.12, pan=0.35)
        s.drum('snare', ks.snare, b + 1, 0.25)
        s.drum('snare', ks.snare, b + 3, 0.25)
    return s, dict(key='D-Dorisch', mood='Schatzsuche-Entdeckung: Hörner, Pauken, Harfenläufe (synchron)')


def song_puzzle():
    s = Song('puzzle', 84, 3, 24, 64, MAJOR, seed=SEED + 10, humanize=0.005)
    pa = ['I', 'IVmaj7', 'vi', 'V', 'I', 'IVmaj7', 'ii', 'V']
    pb = ['vi', 'iii', 'IV', 'I', 'ii', 'V', 'I', 'V']
    prog = pa + pb + pa
    a = '4:2 2:1 | 3:2 5:1 | 7:1.5 6:.5 5:1 | 4:3 | 4:1 7:1 9:1 | 7:2 5:1 | 5:1 3:1 1:1 | 4:3'
    a2 = '4:2 2:1 | 3:2 5:1 | 7:1.5 6:.5 5:1 | 4:3 | 4:.5 7:.5 6:.5 4:.5 5:1 | 7:2 5:1 | 5:1 3:1 1:1 | 4:3'
    s.melody(celesta, a, 0, vel=0.75, gain=0.8, pan=0.1, verb=0.45)
    line_b = gen_line(s, chord_steps(s, pb), [2, 1], -1, 8, 4, s.rng)
    s.melody(flute, line_b, 24, vel=0.7, gain=0.65, pan=0.0, verb=0.4)
    s.melody(flute, a2, 48, vel=0.75, gain=0.6, pan=0.05, verb=0.4)
    s.melody(celesta, a2, 48, octave=1, vel=0.6, gain=0.4, pan=-0.2, verb=0.5)
    for start, beats, name in chord_spans(s, prog):
        tones = s.chord(name, -1)
        s.note(harp, tones[0] - 12, start, 1, 0.75, 0.6, pan=-0.1, verb=0.35)
        for off in (1, 2):
            for i, m in enumerate(tones[1:3] + [tones[0] + 12]):
                s.note(harp, m, start + off, 0.9, 0.5, 0.22, pan=0.15 + 0.1 * i, verb=0.35)
    pad(s, warm_pad, prog, octave=-1, gain=0.35, verb=0.5)
    triangle_at(s, [0, 8, 16], gain=0.45)
    return s, dict(key='E-Dur', mood='Puzzle: verträumter Walzer mit Celesta und Harfe (3/4)')


def song_build():
    s = Song('build', 108, 4, 28, 67, MAJOR, seed=SEED + 11)
    pa = ['I', 'V', 'vi', 'IV', 'I', 'V', 'IV', 'IV']
    pb = ['ii', 'IV', 'I', 'V', 'vi', 'IV', 'ii', 'V']
    tag = ['IV', 'V', 'IV', 'V']
    prog = pa + pa + pb + tag
    a = ('0:.5 2:.5 4:1 7:.5 4:.5 2:1 | 1:.5 4:.5 6:1 8:1 6:1 | 5:.5 4:.5 5:1 7:1 9:1 | 8:1 7:1 5:1 3:1 | ' +
         MOTIF + ' | 1:1 4:1 6:2 | 5:1 7:1 5:1 3:1 | 3:3 r:1')
    s.melody(glock, a, 0, vel=0.8, gain=0.6, pan=0.15, verb=0.35)
    s.melody(square_lead, a, 0, octave=-1, vel=0.65, gain=0.35, pan=-0.05)
    s.melody(marimba, a, 32, vel=0.85, gain=0.8, pan=-0.1)
    s.melody(glock, a, 32, octave=0, vel=0.6, gain=0.3, pan=0.3, verb=0.4)
    line_b = gen_line(s, chord_steps(s, pb), [1, .5, .5, 1, 1], -2, 7, 4, s.rng)
    s.melody(whistle_lead, line_b, 64, octave=-1, vel=0.8, gain=0.65, pan=0.05)
    arp(s, guitar, prog, octave=-1, pattern=(0, 1, 2, 3, 1, 2, 3, 4), gain=0.32, vel=0.6, verb=0.25)
    bass(s, synth_bass, prog, 'bounce', octave=-3, gain=0.75)
    drums_pop(s, bars=range(0, 28), gain=0.62, kick_extra=False)
    for bar, b in every_bar(s):
        s.drum('snap', ks.snap, b + 1.5, 0.3, pan=0.4)
    pad(s, warm_pad, prog, octave=-1, gain=0.25, bars=range(16, 28))
    return s, dict(key='G-Dur', mood='Bauwelt: hell und kreativ, Glockenspiel, Gitarren-Arpeggio')


def _settle_prog():
    pa = ['I', 'IV', 'I', 'V', 'I', 'IV', 'V', 'I']
    pb = ['vi', 'IV', 'I', 'V', 'IV', 'I', 'ii', 'V']
    return pa + pa + pb + pa


def song_settlement_day():
    s = Song('settlement_day', 180, 6, 32, 62, MAJOR, seed=SEED + 12)
    prog = _settle_prog()
    a = '0:2 2:1 4:3 | 5:2 3:1 7:3 | 4:2 2:1 0:2 2:1 | 1:3 4:3 | 4:1 7:1 6:1 4:1 5:1 4:1 | 3:3 5:3 | 8:2 6:1 4:3 | 7:6'
    s.melody(horn, a, 0, vel=0.85, gain=0.8, pan=-0.1, verb=0.35)
    s.melody(strings, a, 48, octave=1, vel=0.8, gain=0.7, pan=0.1, verb=0.35)
    counter = gen_line(s, chord_steps(s, prog[8:16]), [2, 1, 2, 1], 2, 11, 7, s.rng)
    s.melody(flute, counter, 48, octave=1, vel=0.6, gain=0.4, pan=0.35)
    line_b = gen_line(s, chord_steps(s, prog[16:24]), [3, 2, 1], -1, 8, 4, s.rng)
    s.melody(flute, line_b, 96, octave=1, vel=0.75, gain=0.65, pan=0.05)
    s.melody(horn, a, 144, vel=0.9, gain=0.85, pan=-0.1, verb=0.35)
    s.melody(strings, a, 144, octave=1, vel=0.7, gain=0.45, pan=0.15, verb=0.35)
    block(s, pizz, prog, [3], 2, octave=-1, gain=0.45, vel=0.6, drop_root=True)
    arp(s, harp, prog, octave=0, pattern=(0, 1, 2, 3, 2, 1), step=1, gain=0.22, vel=0.55, verb=0.4)
    bass(s, upright, prog, 'six8', octave=-3, gain=0.85)
    pad(s, warm_pad, prog, octave=-1, gain=0.3)
    for bar, b in every_bar(s):
        s.drum('kick_soft', lambda r: ks.kick(r, soft=True), b, 0.45)
        s.drum('brush', lambda r: ks.snare(r, brush=True), b + 3, 0.38)
        s.drum('brush', lambda r: ks.snare(r, brush=True), b + 5, 0.18)
        if bar % 2 == 0:
            s.add(ks.timpani(s.rng, s.chord(prog[bar], -3)[0] + 12), b, 0.45, verb=0.2)
        for k in range(6):
            s.drum('tamb', ks.tambourine, b + k, 0.08 if k % 3 else 0.13, pan=0.35)
    return s, dict(key='D-Dur', mood='Dorf am Tag: pastoral-heroisch, Horn und Streicher (6/8)')


def song_settlement_evening():
    s = Song('settlement_evening', 72, 4, 16, 62, MAJOR, seed=SEED + 13, humanize=0.005)
    prog = ['I', 'vi', 'IV', 'V', 'I', 'vi', 'ii', 'V', 'IV', 'I', 'vi', 'V', 'IV', 'V', 'I', 'I']
    a = '0:1.5 2:.5 4:2 | 5:1.5 4:.5 2:2 | 3:1.5 5:.5 7:2 | 6:3 r:1 | ' + MOTIF + ' | 5:2 2:2 | 3:2 1:2 | 4:4'
    s.melody(flute, a, 0, vel=0.7, gain=0.7, pan=0.05, verb=0.45)
    line_b = gen_line(s, chord_steps(s, prog[8:]), [2, 1, 1], -2, 6, 2, s.rng)
    s.melody(clarinet, line_b, 32, vel=0.65, gain=0.65, pan=-0.05, verb=0.4)
    arp(s, harp, prog, octave=-1, pattern=(0, 1, 2, 3, 4, 3, 2, 1), gain=0.3, vel=0.55, verb=0.45)
    pad(s, horn, prog, octave=-1, gain=0.25, verb=0.45)
    pad(s, warm_pad, prog, octave=-1, gain=0.3, verb=0.45)
    bass(s, soft_bass, prog, 'whole', octave=-2, gain=0.6)
    triangle_at(s, [0, 8], gain=0.35)
    return s, dict(key='D-Dur', mood='Dorf am Abend: ruhige Harfe, Flöte, warme Hörner')


def song_learning():
    s = Song('learning', 88, 4, 24, 65, MAJOR, seed=SEED + 14, humanize=0.004)
    prog = ['Imaj7', 'iii7', 'IVmaj7', 'V', 'Imaj7', 'vi7', 'ii7', 'V7', 'IVmaj7', 'V', 'iii7', 'vi7',
            'ii7', 'V7', 'Imaj7', 'Imaj7', 'IVmaj7', 'Imaj7', 'IVmaj7', 'V', 'Imaj7', 'vi7', 'ii7', 'V7']
    mel = ('r:4 | r:4 | r:4 | r:2 1:1 2:1 | ' + MOTIF + ' | 0:3 r:1 | 1:2 3:2 | 4:3 r:1 | r:4 | r:4 | r:4 | r:4 | '
           'r:4 | r:4 | r:4 | r:2 4:1 2:1 | 3:2 5:2 | 4:3 r:1 | 5:1.5 3:.5 0:2 | 1:3 r:1')
    s.melody(vibes, mel, 0, octave=-1, vel=0.6, gain=0.55, pan=0.15, verb=0.35)
    block(s, epiano, prog, [0, 2.5], 1.4, octave=-1, gain=0.4, vel=0.45, pan=-0.1, drop_root=True)
    bass(s, upright, prog, 'half', octave=-3, gain=0.75)
    drums_soft(s, gain=0.42)
    return s, dict(key='F-Dur', mood='Lernwerkstatt: freundlich und zurückhaltend, viel Platz für Sprache')


MUSIC = {
    'lumo_theme': song_lumo_theme, 'hub': song_hub, 'cards': song_cards, 'memory': song_memory,
    'connect_four': song_connect_four, 'quiz': song_quiz, 'quiz_tension': song_quiz_tension,
    'treasure': song_treasure, 'treasure_discovery': song_treasure_discovery, 'puzzle': song_puzzle,
    'build': song_build, 'settlement_day': song_settlement_day, 'settlement_evening': song_settlement_evening,
    'learning': song_learning,
}
# Schichten, die zu einem Grundstück gehören: gleiche Länge, gleiches Tempo, gleicher Pegel-Faktor.
LAYER_OF = {'quiz_tension': 'quiz', 'treasure_discovery': 'treasure'}
# Die Spannungsschicht ist allein sehr dünn; sie muss über dem Grundstück hörbar sein.
LAYER_BOOST = {'quiz_tension': 2.0}
LOWPASS = {'learning': 6500.0, 'memory': 9000.0, 'settlement_evening': 9000.0}


# ── Mastering ─────────────────────────────────────────────────────────────

def k_weight(x: np.ndarray) -> np.ndarray:
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    f = np.maximum(np.fft.rfftfreq(n, 1 / SR), 1e-3)
    shelf = 10 ** ((4.0 / (1 + (1680.0 / f) ** 2)) / 20)
    hp = 1 / np.sqrt(1 + (38.0 / f) ** 4)
    return np.fft.irfft(spec * shelf * hp, n=n, axis=-1)


def lufs(x: np.ndarray) -> float:
    x = np.atleast_2d(x)
    w = k_weight(x)
    block, hop = nsamp(0.4), nsamp(0.1)
    if w.shape[-1] < block:
        return 10 * math.log10(np.mean(np.sum(w ** 2, axis=0) / w.shape[0] * w.shape[0]) + 1e-12) - 0.691
    powers = []
    for start in range(0, w.shape[-1] - block + 1, hop):
        powers.append(np.sum(np.mean(w[:, start:start + block] ** 2, axis=1)))
    powers = np.array(powers)
    loud = -0.691 + 10 * np.log10(powers + 1e-12)
    gated = powers[loud > -70]
    if gated.size == 0:
        return -70.0
    rel = -0.691 + 10 * math.log10(gated.mean()) - 10
    final = powers[(loud > -70) & (loud > rel)]
    return -0.691 + 10 * math.log10(final.mean() + 1e-12)


def limiter(x: np.ndarray, ceiling: float = PEAK, circular: bool = True) -> np.ndarray:
    x = np.atleast_2d(x)
    n = x.shape[-1]
    blk = 64
    nb = int(math.ceil(n / blk))
    padded = np.zeros((x.shape[0], nb * blk))
    padded[:, :n] = np.abs(x)
    peaks = padded.reshape(x.shape[0], nb, blk).max(axis=(0, 2))
    near = np.maximum.reduce([np.roll(peaks, k) for k in range(-3, 4)])
    gain = np.minimum(1.0, ceiling / np.maximum(near, 1e-9))
    smooth = np.minimum.reduce([np.roll(gain, k) for k in range(-2, 3)])
    kernel = np.ones(5) / 5
    smooth = np.convolve(np.concatenate([smooth[-4:], smooth, smooth[:4]]), kernel, mode='same')[4:-4]
    smooth = np.minimum(smooth, gain)
    g = np.interp(np.arange(n), np.arange(nb) * blk + blk / 2, smooth, period=n if circular else None)
    y = x * g
    return np.clip(y, -ceiling, ceiling)


def master_music(x: np.ndarray, gain: float | None = None, lp: float = 13800.0) -> tuple[np.ndarray, float]:
    x = highpass(x, 28, 2)
    x = lowpass(x, lp, 4)
    x -= x.mean(axis=-1, keepdims=True)
    if gain is None:
        gain = 10 ** ((MUSIC_LUFS - lufs(x)) / 20)
    return limiter(x * gain), gain


# ── Atmosphären (mono, zirkulär) ──────────────────────────────────────────

class Amb:
    def __init__(self, name: str, seconds: float, seed: int):
        self.name = name
        self.N = nsamp(seconds)
        self.seconds = seconds
        self.buf = np.zeros(self.N)
        self.rng = np.random.default_rng(seed)

    def add(self, sig: np.ndarray, at: float, gain: float = 1.0):
        start = int(at * SR) % self.N
        idx = 0
        while idx < sig.size:
            pos = (start + idx) % self.N
            take = min(sig.size - idx, self.N - pos)
            self.buf[pos:pos + take] += sig[idx:idx + take] * gain
            idx += take

    def bed(self, sig: np.ndarray, gain: float = 1.0):
        self.buf += sig[: self.N] * gain

    def slow(self, cutoff: float, lo: float = 0.0, hi: float = 1.0) -> np.ndarray:
        """Langsame, zirkuläre Zufallskurve (z. B. Windböen)."""
        c = lowpass(self.rng.standard_normal(self.N), cutoff, 2)
        c = (c - c.min()) / (c.max() - c.min() + 1e-12)
        return lo + (hi - lo) * c

    def times(self, count: int, min_gap: float = 0.5):
        pts = np.sort(self.rng.uniform(0, self.seconds, count))
        return [p for i, p in enumerate(pts) if i == 0 or p - pts[i - 1] > min_gap]


def vowel_voice(rng, seconds: float, f0: float, bright: float = 1.0) -> np.ndarray:
    """Wortlose Stimme: Glottis-Puls durch wechselnde Formanten, unverständlich weich gefiltert."""
    n = nsamp(seconds)
    t = tax(n)
    contour = f0 * (1 + 0.08 * np.sin(TAU * rng.uniform(1.5, 3.0) * t + rng.uniform(0, TAU)) - 0.06 * t / seconds)
    ph = TAU * np.cumsum(contour) / SR
    src = np.zeros(n)
    for k in range(1, 30):
        if f0 * k > 3500:
            break
        src += np.sin(k * ph) / k
    vowels = [(700, 1200), (400, 2000), (500, 900), (300, 2300), (600, 1700)]
    out = np.zeros(n)
    syl = rng.uniform(0.13, 0.22)
    pos = 0
    while pos < n:
        length = min(nsamp(syl * rng.uniform(0.7, 1.3)), n - pos)
        f1, f2 = vowels[int(rng.integers(len(vowels)))]
        seg = src[pos:pos + length]
        shaped = bandpass(seg, f1 * 0.7, f1 * 1.3, 2) + 0.5 * bright * bandpass(seg, f2 * 0.8, f2 * 1.2, 2)
        env = np.sin(np.pi * np.linspace(0, 1, length)) ** 0.8
        out[pos:pos + length] += shaped * env
        pos += length
    return lowpass(fade_edges(out, 0.05, 0.1), 2600)


def cricket(rng, seconds: float, carrier: float, rate: float) -> np.ndarray:
    n = nsamp(seconds)
    t = tax(n)
    gate = np.zeros(n)
    period = 1 / rate
    start = rng.uniform(0, period)
    while start < seconds:
        for p in range(3):
            s0 = start + p * 0.022
            mask = (t >= s0) & (t < s0 + 0.014)
            gate[mask] = np.sin(np.pi * (t[mask] - s0) / 0.014)
        start += period * rng.uniform(0.9, 1.1)
    return np.sin(TAU * carrier * t) * gate


def bird_phrase(rng, kind: int) -> np.ndarray:
    if kind == 0:  # Zwitschern: 3–6 schnelle Aufwärtsbögen
        notes = []
        base = rng.uniform(2800, 4200)
        for _ in range(int(rng.integers(3, 7))):
            n = nsamp(rng.uniform(0.05, 0.09))
            t = tax(n)
            f = base * (1 + 0.35 * t / t[-1]) * rng.uniform(0.95, 1.05)
            notes.append(np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]))
            notes.append(np.zeros(nsamp(rng.uniform(0.03, 0.07))))
        return np.concatenate(notes) * 0.5
    if kind == 1:  # Triller
        n = nsamp(rng.uniform(0.5, 0.9))
        t = tax(n)
        f = rng.uniform(3200, 4500) * (1 + 0.06 * np.sin(TAU * 24 * t))
        env = np.sin(np.pi * t / t[-1]) * (0.5 + 0.5 * np.sin(TAU * 24 * t))
        return np.sin(TAU * np.cumsum(f) / SR) * env * 0.4
    # Zwei-Ton-Ruf (tief, Holztaube-artig, eigenes Intervall)
    out = []
    for f0, dur in [(rng.uniform(560, 640), 0.32), (rng.uniform(470, 520), 0.45)]:
        n = nsamp(dur)
        t = tax(n)
        out.append((np.sin(TAU * f0 * t) + 0.2 * np.sin(TAU * 2 * f0 * t)) * np.sin(np.pi * t / t[-1]) ** 1.5)
        out.append(np.zeros(nsamp(0.12)))
    return np.concatenate(out) * 0.35


def gull(rng) -> np.ndarray:
    n = nsamp(rng.uniform(0.35, 0.55))
    t = tax(n)
    u = t / t[-1]
    f = 1500 + 700 * np.sin(np.pi * u) - 500 * u
    ph = TAU * np.cumsum(f) / SR
    y = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
    y += bandpass(rng.standard_normal(n), 1500, 4000) * 0.2
    return y * np.sin(np.pi * u) ** 0.7 * 0.25


def creak(rng) -> np.ndarray:
    n = nsamp(rng.uniform(0.5, 0.9))
    t = tax(n)
    rate = 40 + 25 * np.sin(np.pi * t / t[-1]) + rng.uniform(-5, 5)
    ph = np.cumsum(rate) / SR
    clicks = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    y = bandpass(clicks, 350, 1600, 2) * np.sin(np.pi * t / t[-1])
    return y * 2.5


def knock(rng, pitch: float) -> np.ndarray:
    n = nsamp(0.25)
    t = tax(n)
    y = np.sin(TAU * pitch * t) * np.exp(-t * 30) + bandpass(rng.standard_normal(n), 800, 3000) * np.exp(-t * 120) * 0.5
    return lowpass(y, 2500)


def amb_playroom():
    a = Amb('playroom', 48.0, SEED + 101)
    tick = lowpass(highpass(fade_edges(np.sin(TAU * 2600 * tax(nsamp(0.02))) * np.exp(-tax(nsamp(0.02)) * 260)), 900), 7000)
    tock = lowpass(highpass(fade_edges(np.sin(TAU * 2050 * tax(nsamp(0.02))) * np.exp(-tax(nsamp(0.02)) * 230)), 900), 7000)
    for sec in range(48):
        a.add(tick if sec % 2 == 0 else tock, sec + 0.0, 0.11)
    wind = bandpass(pink(a.N, a.rng), 250, 1400, 2) * a.slow(0.12, 0.1, 1.0) ** 2
    whistle = bandpass(pink(a.N, a.rng), 900, 1300, 3) * a.slow(0.08, 0.0, 1.0) ** 4
    a.bed(wind, 0.06)
    a.bed(whistle, 0.05)
    for at in a.times(4, 6):
        a.add(creak(a.rng), at, 0.05)
    a.bed(bandpass(brown(a.N, a.rng), 60, 300), 0.012)
    return a, 'Spielzimmer: Uhr tickt, Holz knarzt leise, Wind am Fenster'


def amb_island():
    a = Amb('island', 48.0, SEED + 102)
    surf_src = lowpass(brown(a.N, a.rng), 900) + 0.4 * bandpass(pink(a.N, a.rng), 300, 2500)
    env = np.zeros(a.N)
    at = 0.0
    while at < a.seconds:
        n = nsamp(9.0)
        t = tax(n)
        e = np.where(t < 2.4, (t / 2.4) ** 1.8, np.exp(-(t - 2.4) / 2.0))
        a2 = Amb('x', a.seconds, 0)
        a2.add(e, at)
        env = np.maximum(env, a2.buf)
        at += a.rng.uniform(6.0, 8.5)
    a.bed(surf_src * (0.2 + env), 0.11)
    foam = bandpass(pink(a.N, a.rng), 2000, 7000) * np.roll(env, nsamp(0.9)) ** 2
    a.bed(foam, 0.035)
    leaves = bandpass(pink(a.N, a.rng), 2500, 9000) * a.slow(0.25, 0.0, 1.0) ** 3
    a.bed(leaves, 0.03)
    for at in a.times(6, 4):
        a.add(gull(a.rng), at, 0.12)
    return a, 'Insel: Brandung, Möwen, Blätterrauschen'


def amb_island_waterfall():
    a = Amb('island_waterfall', 30.0, SEED + 103)
    roar = bandpass(pink(a.N, a.rng), 150, 6000) * a.slow(0.6, 0.85, 1.0)
    rumble = lowpass(brown(a.N, a.rng), 220)
    a.bed(roar, 0.12)
    a.bed(rumble, 0.08)
    return a, 'Wasserfall in der Nähe (Schicht, lauter beim Näherkommen)'


def brook(a: Amb, gain: float):
    a.bed(bandpass(pink(a.N, a.rng), 500, 3500) * a.slow(1.5, 0.5, 1.0), gain * 0.5)
    for at in np.sort(a.rng.uniform(0, a.seconds, int(a.seconds * 22))):
        n = nsamp(a.rng.uniform(0.012, 0.035))
        t = tax(n)
        f = a.rng.uniform(350, 1300) * (1 + 1.2 * t / t[-1])
        blip = np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1])
        a.add(blip, at, gain * a.rng.uniform(0.3, 1.0))


def amb_village_day():
    a = Amb('village_day', 60.0, SEED + 104)
    brook(a, 0.05)
    a.bed(bandpass(pink(a.N, a.rng), 200, 1500) * a.slow(0.1, 0.2, 1.0), 0.03)
    for at in a.times(26, 1.0):
        a.add(bird_phrase(a.rng, int(a.rng.choice([0, 0, 1, 2]))), at, 0.09 * a.rng.uniform(0.5, 1.0))
    for at in a.times(5, 8):
        pitch = a.rng.uniform(160, 240)
        for k in range(int(a.rng.integers(3, 6))):
            a.add(knock(a.rng, pitch), at + k * 0.48, 0.12)
    for at in a.times(3, 12):
        n = nsamp(3.0)
        t = tax(n)
        strokes = np.abs(np.sin(TAU * 0.8 * t)) ** 1.5
        saw_ = bandpass(a.rng.standard_normal(n), 900, 3200) * strokes * np.sin(np.pi * t / t[-1]) ** 0.3
        a.add(lowpass(saw_, 2800), at, 0.04)
    for at in a.times(10, 3):
        a.add(vowel_voice(a.rng, a.rng.uniform(1.2, 2.6), a.rng.uniform(110, 240)), at, 0.035)
    return a, 'Dorf am Tag: Vögel, Bach, Hämmern und Sägen, wortloses Gemurmel'


def amb_village_evening():
    a = Amb('village_evening', 48.0, SEED + 105)
    brook(a, 0.035)
    a.bed(bandpass(pink(a.N, a.rng), 150, 900) * a.slow(0.08, 0.2, 1.0), 0.03)
    for carrier, rate, g in [(4300, 2.1, 0.022), (4700, 2.6, 0.016), (3900, 1.7, 0.014)]:
        a.bed(cricket(a.rng, a.seconds, carrier, rate) * a.slow(0.05, 0.5, 1.0), g)
    for at in a.times(4, 8):
        a.add(bird_phrase(a.rng, 2), at, 0.05)
    return a, 'Dorf am Abend: Grillen, leiser Bach, Abendwind'


def crowd(a: Amb, voices: int, gain: float):
    for at in np.linspace(0, a.seconds, voices, endpoint=False) + a.rng.uniform(0, 1.5, voices):
        a.add(vowel_voice(a.rng, a.rng.uniform(1.0, 2.4), a.rng.uniform(100, 260), 0.7), float(at), gain)
    a.bed(bandpass(pink(a.N, a.rng), 250, 1800) * a.slow(0.15, 0.6, 1.0), gain * 0.6)


def amb_stage():
    a = Amb('stage', 40.0, SEED + 106)
    crowd(a, 90, 0.03)
    return a, 'Bühne: erwartungsvolles Publikumsraunen'


def amb_studio():
    a = Amb('studio', 40.0, SEED + 107)
    crowd(a, 50, 0.025)
    a.bed(lowpass(brown(a.N, a.rng), 120), 0.01)
    return a, 'Quiz-Studio: Studiopublikum, leises Raunen'


AMBIENCE = {
    'playroom': amb_playroom, 'island': amb_island, 'island_waterfall': amb_island_waterfall,
    'village_day': amb_village_day, 'village_evening': amb_village_evening, 'stage': amb_stage,
    'studio': amb_studio,
}


# ── Bedien- und Ereignistöne ──────────────────────────────────────────────

def mix_at(parts, total: float) -> np.ndarray:
    out = np.zeros(nsamp(total))
    for sig, at, g in parts:
        s = int(at * SR)
        e = min(out.size, s + sig.size)
        out[s:e] += sig[: e - s] * g
    return out


def seq(inst, midis, step, rng, vel=0.8, dur=None, gain=1.0, start=0.0):
    return [(inst(m, dur or step, vel, rng), start + i * step, gain) for i, m in enumerate(midis)]


def whoosh(rng, seconds, lo, hi, up=True):
    n = nsamp(seconds)
    t = tax(n)
    u = t / t[-1]
    src = pink(n, rng)
    pos = u if up else 1 - u
    bands = [lo, math.sqrt(lo * hi), hi]
    out = np.zeros(n)
    for i, c in enumerate(bands):
        weight = np.clip(1 - np.abs(pos * 2 - i), 0, 1)
        out += bandpass(src, c * 0.6, c * 1.6) * weight
    return out * np.sin(np.pi * u) ** 1.2


def flick(rng, bright=4000.0, length=0.03):
    n = nsamp(length)
    t = tax(n)
    return bandpass(rng.standard_normal(n), bright * 0.5, min(bright * 1.6, 12000)) * np.exp(-t * 140)


def thump(rng, cutoff=900.0, length=0.08, decay=60.0):
    n = nsamp(length)
    t = tax(n)
    return lowpass(rng.standard_normal(n), cutoff) * np.exp(-t * decay)


def sparkle(rng, seconds=0.6, density=40):
    out = np.zeros(nsamp(seconds))
    for at in rng.uniform(0, seconds * 0.8, density):
        note = glock(int(rng.integers(88, 101)), 0.1, rng.uniform(0.3, 0.8), rng)[: nsamp(0.4)]
        s = int(at * SR)
        e = min(out.size, s + note.size)
        out[s:e] += note[: e - s] * rng.uniform(0.15, 0.35) * (1 - at / seconds)
    return out


def sfx_ui_click(rng, v):
    n = nsamp(0.06)
    t = tax(n)
    f = 1350 * (1 + 0.06 * v)
    y = np.sin(TAU * f * t) * np.exp(-t * 120) * 0.6 + np.sin(TAU * 620 * t) * np.exp(-t * 90) * 0.4
    return y + flick(rng, 5000, 0.06)[:n] * 0.25


def sfx_ui_confirm(rng, v):
    root = [84, 86, 83][v]
    return mix_at(seq(marimba, [root, root + 7], 0.07, rng, 0.85) + [(bell(root + 12, 0.2, 0.5, rng), 0.07, 0.35)], 0.6)


def sfx_ui_cancel(rng, v):
    root = [79, 77][v]
    out = mix_at(seq(marimba, [root, root - 5], 0.08, rng, 0.6), 0.45)
    return lowpass(out, 4000)


def sfx_ui_back(rng, v):
    n = nsamp(0.16)
    t = tax(n)
    f = (900 - 320 * t / t[-1]) * (1 + 0.05 * v)
    y = np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]) ** 0.6 * 0.5
    return y + mix_at([(flick(rng, 3000), 0, 0.3)], 0.16)


def sfx_portal_tap(rng, v):
    base = [76, 79][v]
    parts = seq(bell, [base, base + 4, base + 7, base + 12], 0.06, rng, 0.7, gain=0.5)
    parts.append((whoosh(rng, 0.6, 600, 5000), 0.0, 0.25))
    parts.append((sparkle(rng, 0.7, 12), 0.15, 0.6))
    return mix_at(parts, 1.1)


def sfx_card_next(rng, v):
    return mix_at([(whoosh(rng, 0.18 + 0.03 * v, 1200, 4500), 0, 0.6), (flick(rng, 4500), 0.12, 0.25)], 0.3)


def sfx_star_collected(rng, v):
    scale = [0, 2, 4, 7, 9, 12, 14]
    base = 84 + [0, 2, 5, -3][v]
    notes = [base + scale[i] for i in sorted(rng.choice(len(scale), 5, replace=False))]
    parts = seq(glock, notes, 0.045, rng, 0.75, gain=0.7)
    parts.append((sparkle(rng, 0.6, 24), 0.05, 0.7))
    return mix_at(parts, 0.9)


def sfx_celebrate(rng, v):
    key = [72, 74][v]
    parts = seq(brass, [key - 12, key - 8, key - 5, key], 0.11, rng, 0.85, dur=0.12, gain=0.6)
    parts += [(brass(m, 0.7, 0.9, rng), 0.44, 0.35) for m in (key - 12, key - 5, key, key + 4)]
    parts.append((ks.timpani(rng, 36 + (key - 72)), 0.44, 0.5))
    parts.append((ks.cymbal_swell(rng, 0.45)[::-1].copy(), 0.44, 0.6))
    parts.append((sparkle(rng, 1.0, 30), 0.45, 0.8))
    return mix_at(parts, 1.8)


def sfx_card_deal(rng, v):
    return mix_at([(flick(rng, 5000 + 400 * v, 0.03), 0, 0.7), (thump(rng, 1200, 0.04, 90), 0.012, 0.5)], 0.08)


def sfx_card_play(rng, v):
    return mix_at([(flick(rng, 3500, 0.025), 0, 0.5), (thump(rng, 700 + 100 * v, 0.09, 55), 0.008, 0.9)], 0.14)


def sfx_card_draw(rng, v):
    n = nsamp(0.13)
    t = tax(n)
    slide = bandpass(rng.standard_normal(n), 1500, 5500) * (t / t[-1]) ** 1.5 * np.exp(-t * 4)
    return mix_at([(slide, 0, 0.5 + 0.05 * v), (flick(rng, 4500), 0.11, 0.3)], 0.18)


def sfx_card_select(rng, v):
    return mix_at([(flick(rng, 4000, 0.02), 0, 0.4), (vibes(91 + 2 * v, 0.06, 0.5, rng)[: nsamp(0.3)], 0.005, 0.35)], 0.3)


def sfx_card_refuse(rng, v):
    root = [60, 62][v]
    parts = [(lowpass(marimba(root, 0.1, 0.6, rng), 2500), 0, 0.7), (lowpass(marimba(root, 0.1, 0.5, rng), 2500), 0.12, 0.5)]
    return mix_at(parts, 0.5)


def sfx_card_pass(rng, v):
    return mix_at([(whoosh(rng, 0.22, 3500, 900, up=False), 0, 0.5 + 0.05 * v)], 0.25)


def sfx_card_shuffle(rng, v):
    total = 0.95
    parts = []
    at = 0.0
    gap = 0.03
    while at < 0.7:
        parts.append((flick(rng, rng.uniform(3500, 6000), 0.02), at, rng.uniform(0.25, 0.45)))
        at += gap * rng.uniform(0.6, 1.2)
        gap = max(0.008, gap * 0.93)
    parts.append((thump(rng, 900, 0.1, 40), 0.74 + 0.02 * v, 0.7))
    return mix_at(parts, total)


def sfx_card_flip(rng, v):
    return mix_at([(flick(rng, 4200, 0.02), 0, 0.5), (whoosh(rng, 0.09, 1500, 4000), 0.01, 0.35),
                   (flick(rng, 3200 + 300 * v, 0.03), 0.07, 0.45)], 0.15)


def sfx_trick_win(rng, v):
    parts = [(whoosh(rng, 0.25, 800, 3000), 0, 0.35)]
    parts += seq(marimba, [79 + v * 2, 83 + v * 2, 86 + v * 2], 0.07, rng, 0.8, gain=0.7, start=0.1)
    return mix_at(parts, 0.75)


def sfx_quartet(rng, v):
    parts = seq(celesta, [84, 88, 91, 96], 0.07, rng, 0.85, gain=0.8)
    parts += [(bell(m, 0.5, 0.6, rng), 0.3, 0.3) for m in (84, 91)]
    parts.append((sparkle(rng, 0.9, 25), 0.25, 0.7))
    return mix_at(parts, 1.5)


def sfx_round_win(rng, v):
    parts = seq(marimba, [72, 76, 79, 84, 88], 0.08, rng, 0.85, gain=0.75)
    parts += [(brass(m, 0.6, 0.8, rng), 0.4, 0.3) for m in (60, 67, 72, 76)]
    parts.append((sparkle(rng, 1.0, 30), 0.4, 0.7))
    return mix_at(parts, 1.6)


def sfx_turn_ping(rng, v):
    return mix_at(seq(vibes, [88 + v, 93 + v], 0.09, rng, 0.6, dur=0.1, gain=0.6), 0.9)


def sfx_piece_drop(rng, v):
    n = nsamp(0.12)
    t = tax(n)
    slide = bandpass(rng.standard_normal(n), 2000, 6000) * (t / t[-1]) * 0.2
    pitch = 1150 + 90 * v
    clack = lambda g: _clack(rng, pitch) * g  # noqa: E731
    return mix_at([(slide, 0, 1.0), (clack(0.9), 0.12, 1), (clack(0.35), 0.21, 1), (clack(0.12), 0.26, 1),
                   (thump(rng, 500, 0.12, 30), 0.12, 0.5)], 0.45)


def _clack(rng, pitch):
    n = nsamp(0.07)
    t = tax(n)
    y = np.sin(TAU * pitch * t) * np.exp(-t * 70) + 0.6 * np.sin(TAU * pitch * 1.73 * t) * np.exp(-t * 90)
    return y * 0.4 + flick(rng, 4000, 0.07) * 0.3


def sfx_pair_found(rng, v):
    base = [86, 88][v]
    parts = seq(glock, [base, base + 5, base + 9], 0.06, rng, 0.8, gain=0.8)
    parts.append((sparkle(rng, 0.6, 18), 0.12, 0.6))
    return mix_at(parts, 0.9)


def sfx_pair_miss(rng, v):
    root = [74, 72][v]
    return lowpass(mix_at(seq(kalimba, [root, root - 2], 0.13, rng, 0.55, gain=0.6), 0.7), 5000)


def sfx_answer_correct(rng, v):
    base = [79, 81, 77][v]
    parts = seq(vibes, [base, base + 4, base + 7, base + 12], 0.055, rng, 0.85, dur=0.3, gain=0.6)
    parts.append((bell(base + 12, 0.3, 0.6, rng), 0.22, 0.4))
    parts.append((sparkle(rng, 0.5, 12), 0.2, 0.5))
    return mix_at(parts, 1.2)


def sfx_answer_wrong(rng, v):
    # Freundlich, nie strafend: weiches „hm-hm“ (große Sekunde abwärts), gedämpft.
    root = [67, 65][v]
    parts = [(lowpass(vibes(root, 0.18, 0.5, rng), 3000), 0, 0.6), (lowpass(vibes(root - 2, 0.3, 0.45, rng), 3000), 0.17, 0.55)]
    return mix_at(parts, 0.9)


def sfx_coin(rng, v):
    base = [95, 97, 93, 98][v]
    parts = [(bell(base, 0.1, 0.8, rng), 0, 0.5), (bell(base + 5, 0.3, 0.8, rng), 0.06, 0.55),
             (flick(rng, 8000, 0.02), 0, 0.2)]
    return mix_at(parts, 0.7)


def sfx_count_tick(rng, v):
    return mix_at([(glock(88 + 2 * v, 0.05, 0.6, rng)[: nsamp(0.25)], 0, 0.5), (flick(rng, 7000, 0.015), 0, 0.15)], 0.25)


def sfx_build_place(rng, v):
    pitch = [150, 170, 135, 190][v]
    parts = [(ks.bongo(rng, pitch) * 1.2, 0, 1.0), (flick(rng, 2500, 0.03), 0, 0.4),
             (marimba(84 + [0, 2, 4, 7][v], 0.1, 0.5, rng), 0.03, 0.25)]
    return mix_at(parts, 0.45)


def sfx_build_remove(rng, v):
    n = nsamp(0.3)
    t = tax(n)
    crumble = np.zeros(n)
    for at in rng.uniform(0.02, 0.25, 14):
        s = int(at * SR)
        g = thump(rng, 1500, 0.03, 120)
        crumble[s:s + g.size] += g[: max(0, min(g.size, n - s))] * rng.uniform(0.2, 0.6)
    pop = np.sin(TAU * np.cumsum(np.linspace(300, 900, nsamp(0.06))) / SR) * np.exp(-tax(nsamp(0.06)) * 40)
    return mix_at([(pop, 0, 0.5), (crumble, 0.02, 0.8 + 0.1 * v), (whoosh(rng, 0.3, 800, 3000), 0.0, 0.25)], 0.4)


def sfx_level_up(rng, v):
    parts = seq(harp, [60, 64, 67, 72, 76, 79, 84], 0.05, rng, 0.8, dur=0.3, gain=0.5)
    parts += [(brass(m, 0.9, 0.85, rng), 0.38, 0.32) for m in (60, 67, 72, 76)]
    parts.append((ks.timpani(rng, 36), 0.38, 0.5))
    parts.append((sparkle(rng, 1.3, 40), 0.38, 0.9))
    return mix_at(parts, 2.2)


def sfx_treasure_found(rng, v):
    parts = [(creak(rng) * 0.6, 0, 0.35)]
    parts.append((whoosh(rng, 1.0, 400, 6000), 0.3, 0.3))
    parts += [(strings(m, 1.2, 0.8, rng), 0.45, 0.35) for m in (62, 66, 69, 74)]
    parts += seq(celesta, [86, 90, 93, 98, 102], 0.07, rng, 0.85, gain=0.6, start=0.55)
    parts.append((ks.timpani(rng, 38), 0.45, 0.5))
    parts.append((sparkle(rng, 1.4, 45), 0.6, 0.9))
    return mix_at(parts, 2.6)


def sfx_puzzle_snap(rng, v):
    pitch = 1600 + 150 * v
    return mix_at([(_clack(rng, pitch), 0, 0.7), (_clack(rng, pitch * 1.2), 0.035, 0.45),
                   (celesta(91 + v, 0.1, 0.5, rng)[: nsamp(0.4)], 0.04, 0.25)], 0.45)


def sfx_dig(rng, v):
    n = nsamp(0.28)
    t = tax(n)
    grit = bandpass(rng.standard_normal(n), 600, 4000) * (np.abs(np.sin(TAU * 60 * t)) ** 3) * np.exp(-t * 9)
    return mix_at([(grit, 0, 0.7), (thump(rng, 500, 0.12, 25), 0.0, 0.7 + 0.1 * v)], 0.32)


def sfx_applause(rng, v):
    total = 3.2
    out = np.zeros(nsamp(total))
    for at in rng.uniform(0, 2.6, 520):
        density = math.exp(-((at - 0.9) / 1.0) ** 2)
        if rng.random() > density:
            continue
        c = ks.clap(rng)[: nsamp(0.06)] * rng.uniform(0.2, 0.6)
        s = int(at * SR)
        out[s:s + c.size] += c
    for _ in range(5):
        voice = vowel_voice(rng, 1.2, rng.uniform(220, 380))
        s = int(rng.uniform(0.1, 0.6) * SR)
        out[s:s + voice.size] += voice[: out.size - s] * 0.15
    return fade_edges(lowpass(out, 9000), 0.01, 0.4)


def sfx_crowd_ooh(rng, v):
    total = 1.4
    out = np.zeros(nsamp(total))
    for _ in range(8):
        n = nsamp(1.2)
        t = tax(n)
        f0 = rng.uniform(170, 330)
        contour = f0 * (1 + 0.15 * np.sin(np.pi * t / t[-1]))
        ph = TAU * np.cumsum(contour) / SR
        src = sum(np.sin(k * ph) / k for k in range(1, 12))
        y = bandpass(src, 300, 900) * np.sin(np.pi * t / t[-1]) ** 1.2
        out[: y.size] += y * 0.2
    return lowpass(out, 3000)


def sfx_lumo_jingle(rng, v):
    s = Song('jingle', 104, 4, 4, 77, MAJOR, seed=SEED + 300, humanize=0.0)
    s.melody(celesta, MOTIF + ' | 0+4:2 r:2', 0, vel=0.85, gain=0.9)
    s.melody(flute, MOTIF + ' | 0:2 r:2', 0, octave=-1, vel=0.7, gain=0.5)
    for i, m in enumerate(s.chord('I', -1)):
        s.note(warm_pad, m, 0, 6, 0.6, 0.25)
        s.note(harp, m, 4 + i * 0.12, 2, 0.6, 0.4)
    mixed = s.mix(2.2).mean(axis=0)[: nsamp(6.0)]
    return fade_edges(mixed, 0.002, 0.4)


def sfx_whoosh(rng, v):
    return whoosh(rng, 0.35 + 0.1 * v, 500, 5000, up=v == 0)


SFX = {
    'ui_click': (sfx_ui_click, 4), 'ui_confirm': (sfx_ui_confirm, 3), 'ui_cancel': (sfx_ui_cancel, 2),
    'ui_back': (sfx_ui_back, 2), 'portal_tap': (sfx_portal_tap, 2), 'card_next': (sfx_card_next, 3),
    'star_collected': (sfx_star_collected, 4), 'celebrate': (sfx_celebrate, 2), 'card_deal': (sfx_card_deal, 4),
    'card_play': (sfx_card_play, 4), 'card_draw': (sfx_card_draw, 3), 'card_select': (sfx_card_select, 3),
    'card_refuse': (sfx_card_refuse, 2), 'card_pass': (sfx_card_pass, 2), 'card_shuffle': (sfx_card_shuffle, 2),
    'card_flip': (sfx_card_flip, 3), 'trick_win': (sfx_trick_win, 2), 'quartet': (sfx_quartet, 1),
    'round_win': (sfx_round_win, 1), 'turn_ping': (sfx_turn_ping, 2), 'piece_drop': (sfx_piece_drop, 4),
    'pair_found': (sfx_pair_found, 2), 'pair_miss': (sfx_pair_miss, 2), 'answer_correct': (sfx_answer_correct, 3),
    'answer_wrong': (sfx_answer_wrong, 2), 'coin': (sfx_coin, 4), 'count_tick': (sfx_count_tick, 4),
    'build_place': (sfx_build_place, 4), 'build_remove': (sfx_build_remove, 3), 'level_up': (sfx_level_up, 1),
    'treasure_found': (sfx_treasure_found, 1), 'puzzle_snap': (sfx_puzzle_snap, 3), 'dig': (sfx_dig, 3),
    'applause': (sfx_applause, 2), 'crowd_ooh': (sfx_crowd_ooh, 1), 'lumo_jingle': (sfx_lumo_jingle, 1),
    'whoosh': (sfx_whoosh, 2),
}
# Spitzenpegel je Ton (dBFS): Klicks leiser als Fanfaren.
SFX_PEAK_DB = {'ui_click': -9.0, 'card_select': -8.0, 'count_tick': -9.0, 'card_deal': -8.0, 'turn_ping': -7.0,
               'applause': -6.0, 'crowd_ooh': -8.0, 'whoosh': -8.0}


# ── Export und Messung ────────────────────────────────────────────────────

def encode(path: Path, audio: np.ndarray, quality: float) -> None:
    audio = np.atleast_2d(audio).astype(np.float32)
    channels = audio.shape[0]
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', str(channels), '-i', 'pipe:0',
           '-c:a', 'libvorbis', '-q:a', str(quality), '-map_metadata', '-1', '-fflags', '+bitexact',
           '-flags:a', '+bitexact', str(path)]
    subprocess.run(cmd, input=audio.T.copy().tobytes(), check=True)


def decode(path: Path) -> np.ndarray:
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'stream=channels', '-of', 'csv=p=0', str(path)],
                           capture_output=True, text=True, check=True)
    channels = int(probe.stdout.strip().split()[0])
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ar', str(SR), 'pipe:1'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).T.astype(np.float64)


def ffmpeg_loudness(path: Path) -> tuple[float | None, float | None, float | None]:
    res = subprocess.run(['ffmpeg', '-nostats', '-i', str(path), '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                         capture_output=True, text=True)
    text = res.stderr.split('Summary:')[-1]
    integ = re.search(r'I:\s+(-?[\d.]+|-inf) LUFS', text)
    tp = re.search(r'Peak:\s+(-?[\d.]+|-inf) dBFS', text)
    vol = subprocess.run(['ffmpeg', '-nostats', '-i', str(path), '-af', 'volumedetect', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    mx = re.search(r'max_volume:\s+(-?[\d.]+) dB', vol)

    def f(m):
        return None if m is None or 'inf' in m.group(1) else float(m.group(1))
    return f(integ), f(tp), f(mx)


def measure(path: Path, loop: bool) -> dict:
    y = decode(path)
    n = y.shape[1]
    integ, tp, peak = ffmpeg_loudness(path)
    spec = np.abs(np.fft.rfft(y, axis=1)) ** 2
    freqs = np.fft.rfftfreq(n, 1 / SR)
    hi = float(spec[:, freqs > 15000].sum() / (spec.sum() + 1e-20))
    info = {
        'file': str(path.relative_to(OUT)), 'seconds': round(n / SR, 3), 'bytes': path.stat().st_size,
        'kbps': round(path.stat().st_size * 8 / (n / SR) / 1000, 1), 'channels': y.shape[0],
        'lufs': integ, 'true_peak_dbfs': tp, 'max_volume_db': peak,
        'dc': float(np.abs(y.mean(axis=1)).max()), 'energy_above_15k': hi,
    }
    if loop:
        d = np.abs(np.diff(y, axis=1))
        seam = float(np.abs(y[:, 0] - y[:, -1]).max())
        info['seam_jump'] = seam
        info['diff_p99'] = float(np.percentile(d, 99))
        info['seam_ratio'] = seam / (info['diff_p99'] + 1e-12)
        w = nsamp(0.02)
        joined = np.concatenate([y[:, -w:], y[:, :w]], axis=1)
        rms_seam = float(np.sqrt(np.mean(joined ** 2)))
        rms_all = float(np.sqrt(np.mean(y ** 2)))
        info['seam_rms_ratio'] = rms_seam / (rms_all + 1e-12)
    return info


def build_music(name: str, gains: dict) -> dict:
    song, meta = MUSIC[name]()
    width = 0.75
    mixed = song.mix(2.2 if name not in ('cards', 'quiz') else 1.6, 0.9, width)
    base = LAYER_OF.get(name)
    gain = gains.get(base) * LAYER_BOOST.get(name, 1.0) if base else None
    out, g = master_music(mixed, gain, LOWPASS.get(name, 13800.0))
    gains[name] = g
    path = OUT / 'music' / f'{name}.ogg'
    encode(path, out, 3)
    meta.update(bpm=song.bpm, meter=f'{song.bpb}/{8 if song.bpb == 6 else 4}', bars=song.bars,
                samples=song.N, layer_of=base, motif=True)
    return meta


def build_ambience(name: str) -> dict:
    amb, mood = AMBIENCE[name]()
    x = highpass(amb.buf, 40, 2)
    x = lowpass(x, 13000, 4)
    x -= x.mean()
    target = AMBIENCE_LUFS + (3.0 if name == 'island_waterfall' else 0.0)
    x = limiter(x * 10 ** ((target - lufs(x)) / 20), 10 ** (-6 / 20))[0]
    encode(OUT / 'ambience' / f'{name}.ogg', x, 1)
    return dict(mood=mood, samples=amb.N)


def build_sfx(name: str) -> dict:
    fn, count = SFX[name]
    for v in range(count):
        rng = np.random.default_rng(SEED + 1000 + hash_name(name) * 10 + v)
        y = fn(rng, v)
        y = highpass(y, 60, 2)
        y = lowpass(y, 13000, 4)
        y = fade_edges(y - y.mean(), 0.0015, 0.03)
        peak_db = SFX_PEAK_DB.get(name, -3.0)
        y = y / (np.abs(y).max() + 1e-12) * 10 ** (peak_db / 20)
        encode(OUT / 'sfx' / f'{name}_{v}.ogg', y, 4)
    return dict(variants=count)


def hash_name(name: str) -> int:
    return sum((i + 1) * ord(c) for i, c in enumerate(name)) % 9973


def write_report(manifest: dict) -> None:
    rows = ['# Klangwelt – Messwerte', '',
            'Automatisch erzeugt von `tools/art/generate_klangwelt_audio.py` aus den dekodierten OGG-Dateien.',
            '**Nichts davon wurde abgehört** – alle Angaben sind Messungen (ffmpeg `ebur128`/`volumedetect`,',
            'numpy-Auswertung). Abtastrate 32 kHz: Energie über 16 kHz ist technisch ausgeschlossen; gemessen',
            'wird der Anteil über 15 kHz. Schleifenpunkt: `Sprung` = größte Sample-Differenz zwischen letztem',
            'und erstem Sample, `p99` = 99. Perzentil aller Nachbar-Differenzen im Stück (Sprung/p99 < 1 heißt:',
            'der Übergang ist glatter als 99 % des Materials), `RMS±20ms` = Pegel rund um den Übergang relativ',
            'zum Gesamtpegel (≈1 = kein Loch und kein Knall).', '']
    rows += ['## Musik', '',
             '| Datei | Tonart | Tempo/Takt | Länge s | KB | kbit/s | LUFS | True Peak dBFS | DC | >15 kHz | Sprung/p99 | RMS±20ms |',
             '|---|---|---|---|---|---|---|---|---|---|---|---|']
    for name, e in manifest['music'].items():
        m = e['measure']
        rows.append(f"| {name}.ogg | {e['key']} | {e['bpm']:g} BPM {e['meter']} | {m['seconds']:.1f} | {m['bytes'] // 1024} | "
                    f"{m['kbps']:.0f} | {fmt(m['lufs'])} | {fmt(m['true_peak_dbfs'])} | {m['dc']:.1e} | "
                    f"{m['energy_above_15k']:.1e} | {m['seam_ratio']:.2f} | {m['seam_rms_ratio']:.2f} |")
    rows += ['', '## Atmosphären', '',
             '| Datei | Inhalt | Länge s | KB | kbit/s | LUFS | True Peak dBFS | DC | >15 kHz | Sprung/p99 | RMS±20ms |',
             '|---|---|---|---|---|---|---|---|---|---|---|']
    for name, e in manifest['ambience'].items():
        m = e['measure']
        rows.append(f"| {name}.ogg | {e['mood']} | {m['seconds']:.1f} | {m['bytes'] // 1024} | {m['kbps']:.0f} | "
                    f"{fmt(m['lufs'])} | {fmt(m['true_peak_dbfs'])} | {m['dc']:.1e} | {m['energy_above_15k']:.1e} | "
                    f"{m['seam_ratio']:.2f} | {m['seam_rms_ratio']:.2f} |")
    rows += ['', '## Töne', '', '| Name | Varianten | Länge s (max) | KB gesamt | Spitze dBFS (max) | DC (max) |',
             '|---|---|---|---|---|---|']
    for name, e in manifest['sfx'].items():
        ms = e['measure']
        rows.append(f"| {name} | {len(ms)} | {max(m['seconds'] for m in ms):.2f} | {sum(m['bytes'] for m in ms) // 1024} | "
                    f"{fmt(max(m['max_volume_db'] for m in ms))} | {max(m['dc'] for m in ms):.1e} |")
    rows += ['', f"**Gesamtgröße:** {manifest['total_bytes'] / 1e6:.2f} MB in {manifest['file_count']} Dateien; "
             f"größte Einzeldatei {manifest['largest_bytes'] / 1e6:.2f} MB.", '']
    DOC.write_text('\n'.join(rows), encoding='utf-8')


def fmt(v):
    return '–' if v is None else f'{v:.1f}'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='*', default=None)
    parser.add_argument('--measure', action='store_true', help='nur vorhandene Dateien messen')
    args = parser.parse_args()
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest.setdefault('music', {})
    manifest.setdefault('ambience', {})
    manifest.setdefault('sfx', {})
    manifest.update(generator='tools/art/generate_klangwelt_audio.py', sample_rate=SR, seed=SEED,
                    license='Eigenbau für Lumo: selbst komponiert und synthetisiert, keine fremden Samples oder Melodien')
    wanted = set(args.only) if args.only else None
    gains: dict = {}
    if not args.measure:
        order = sorted(MUSIC, key=lambda k: k in LAYER_OF)
        for name in order:
            if wanted and name not in wanted and LAYER_OF.get(name) not in wanted:
                continue
            if LAYER_OF.get(name) and LAYER_OF[name] not in gains:
                build_music(LAYER_OF[name], gains)
            print('Musik', name, flush=True)
            manifest['music'][name] = build_music(name, gains)
        for name in AMBIENCE:
            if wanted and name not in wanted:
                continue
            print('Atmosphäre', name, flush=True)
            manifest['ambience'][name] = build_ambience(name)
        for name in SFX:
            if wanted and name not in wanted and 'sfx' not in wanted:
                continue
            manifest['sfx'][name] = build_sfx(name)
        print('Töne fertig', flush=True)
    total = 0
    largest = 0
    count = 0
    for group, loop in (('music', True), ('ambience', True)):
        for name, entry in manifest[group].items():
            entry['measure'] = measure(OUT / group / f'{name}.ogg', loop)
            total += entry['measure']['bytes']
            largest = max(largest, entry['measure']['bytes'])
            count += 1
    for name, entry in manifest['sfx'].items():
        entry['measure'] = [measure(OUT / 'sfx' / f'{name}_{v}.ogg', False) for v in range(entry['variants'])]
        for m in entry['measure']:
            total += m['bytes']
            largest = max(largest, m['bytes'])
            count += 1
    manifest.update(total_bytes=total, largest_bytes=largest, file_count=count)
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    write_report(manifest)
    print(f'Gesamt {total / 1e6:.2f} MB, {count} Dateien, größte {largest / 1e6:.2f} MB')


if __name__ == '__main__':
    main()
