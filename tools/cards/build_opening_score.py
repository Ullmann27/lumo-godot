"""Render the original five-bar celesta and bowed-bass cue for the card opening."""
from pathlib import Path
import subprocess
import numpy as np

RATE = 44100
SECONDS = 5.7
OUTPUT = Path(__file__).resolve().parents[2] / "assets/cards_table/audio/table_opening.ogg"
mix = np.zeros((int(RATE * SECONDS), 2))


def note(at, midi, length, gain, pan, bowed=False):
    first = round(at * RATE)
    count = min(round(length * RATE), len(mix) - first)
    t = np.arange(count) / RATE
    frequency = 440 * 2 ** ((midi - 69) / 12)
    if bowed:
        phase = 2 * np.pi * frequency * t + .055 * np.sin(2 * np.pi * 4.1 * t)
        wave = np.sin(phase) + .22 * np.sin(phase * 2) + .08 * np.sin(3 * phase)
        envelope = np.minimum(t / .25, 1) * np.minimum((length - t) / .5, 1)
    else:
        wave = np.zeros_like(t)
        for multiple, level, decay in [(1, 1, 2.2), (2.01, .32, 4), (3.985, .21, 8), (6.02, .09, 15)]:
            wave += level * np.sin(2 * np.pi * frequency * multiple * t) * np.exp(-t * decay)
        envelope = np.minimum(t / .005, 1) * np.minimum((length - t) / .12, 1)
    mix[first:first + count] += (wave * envelope * gain)[:, None] * np.sqrt([1-pan, pan])


# An opening D6/9 arpeggio, a reply in G, and the final suspended A resolving to D.
for attack, pitches, strength in [(0.06, [62, 69, 76, 78], .17), (1.80, [67, 71, 74], .145),
                                  (3.50, [57, 64, 69], .135), (4.22, [62, 66, 69, 74], .13)]:
    for index, pitch in enumerate(pitches):
        note(attack + index * .145, pitch, 1.72, strength, .33 + index * .11)
for attack, pitch, length in [(0.03, 38, 1.94), (1.72, 43, 1.86), (3.36, 45, 1.03), (4.18, 38, 1.50)]:
    note(attack, pitch, length, .075, .52, bowed=True)

dry = mix.copy()
for delay, gain in [(.061, .17), (.113, .105), (.192, .06), (.267, .035)]:
    lag = round(delay * RATE)
    mix[lag:] += dry[:-lag, ::-1] * gain
mix[-round(.34 * RATE):] *= np.linspace(1, 0, round(.34 * RATE))[:, None]
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(RATE),
                "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "5", str(OUTPUT)],
               input=mix.astype("<f4").tobytes(), check=True)
