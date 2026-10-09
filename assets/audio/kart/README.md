# Original Lumo Kart music and effects

## Version 2 (8. Oktober 2026): zeitgemäße Rennmusik

Die fünf Musikstücke wurden mit `tools/art/generate_kart_music.py` (Seed 20261008) neu
komponiert und synthetisiert – ebenfalls ohne Aufnahmen, Samples, MIDI oder fremde Melodien.
Je Welt ~60–77 s mit Intro, Strophe, Refrain, Breakdown und zweitem Refrain; Kick/Clap/
Hi-Hats, Sidechain-Bass, Supersaw-Akkorde, Lead mit Ping-Pong-Delay, Arpeggio, Riser, Hall per
Faltung, 44,1 kHz Stereo, Lautheit −14 LUFS, Spitzen ≤ −1,7 dBFS. Für Handylautsprecher ist der
Tiefbass begrenzt (Anteil unter 60 Hz 4–7 %). Schleifen sind nahtlos (Filter und Hall laufen
zirkulär; die Nahtstelle ist ein normaler Taktanfang). Die Effekte unten stammen weiterhin aus
Version 1. Musik und Effekte sind im Pausenmenü getrennt regelbar.

| Datei | Stil | Tempo |
|---|---|---|
| garage.ogg | warmer Future-Bass, Glasklänge | 100 BPM |
| sonnenhafen.ogg | Tropical-House, Steeldrum-Lead | 118 BPM |
| zauberwald.ogg | magischer Electro-Pop, Glocken | 112 BPM |
| bergwelt.ogg | euphorischer Dance-Pop, Supersaws | 126 BPM |
| holo_city.ogg | Synthwave/Electro, Neon-Arpeggio | 132 BPM |

## Version 1 (3. Oktober 2026)

All melodies, arrangements, oscillators, percussion and sound effects in this
folder were created specifically for Lumo on 2026-10-03. No external recordings,
samples, MIDI files or existing game music were used. The synthesis source is
`tools/art/generate_kart_audio.py`; regeneration uses a fixed seed of 61103.

The project's owner may use, modify and distribute these original assets as part
of Lumo or separately. No third-party attribution or sample license is required.
The Python numerical libraries and ffmpeg are build tools, not included samples.

## Score

- `garage.ogg`: quiet D-major plucked keys, 100 BPM.
- `sonnenhafen.ogg`: F-major marimba and gently bouncing bass, 128 BPM.
- `zauberwald.ogg`: D-Dorian celesta and soft suspended chords, 112 BPM.
- `bergwelt.ogg`: G-major plucked strings and small bells, 122 BPM.
- `holo_city.ogg`: A-minor rounded FM melody and electronic pulse, 136 BPM.
  This theme also accompanies the crystal arena.

Each theme has an original eight-bar call-and-answer melody, four-part harmony,
bass, light percussion and stereo reflections. Release/reverb tails wrap into the
beginning before encoding for continuous loops. Files are stereo 32 kHz Ogg
Vorbis. The generator peak-normalizes masters to -3 dBFS; the playback controller
runs music at -17 dB relative gain and effects at -9 dB so cues remain distinct.
There is no spoken audio.

## Gameplay cues

`countdown`, `start`, `boost`, `drift`, `item`, `finish`, and `collision` are
one-shot cues with short attack/release fades. The controller limits retriggering,
uses a four-player effect pool, crossfades music and silences playback when muted,
paused, backgrounded or unfocused. Returning to the foreground does not unmute a
user who selected mute. The existing race preference remains the source of truth.

`manifest.json` records duration, sample rate, peak, loop boundary difference,
size and SHA-256 for each generated source file. These measurements are file
checks; actual device loudness and focus behavior still require Android QA.
