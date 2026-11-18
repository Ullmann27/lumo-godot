# Assets – Herkunft

## Klangwelt (`assets/audio/klangwelt/`)

- Musik, Atmosphären und Ereignistöne: **selbst komponiert und synthetisiert für Lumo**.
- Generator: `tools/art/generate_klangwelt_audio.py` mit `tools/art/klangwelt_synth.py`
  (numpy + ffmpeg/libvorbis, fester Seed 20261118, reproduzierbar).
- Keine Aufnahmen, keine fremden Samples, Loops, MIDI-Dateien oder Melodien; keine bezahlten Dienste.
- Lizenz: Eigentum des Projekts, keine Attribution Dritter nötig.
- Doku: `docs/KLANGWELT.md`, Messwerte: `docs/KLANGWELT_MESSWERTE.md`.

## Kart-Detailschicht (assets/kart/details/)
- `models/kart_detail_props.glb` – Kleinteile-Kit (68 Objekte, Vertex-Farben), Eigenbau in Blender aus Grundkörpern: `tools/lumo_kart_art/details/build_detail_props.py`.
- `textures/kart_detail_wear_atlas.png`, `textures/kart_detail_banner_atlas.png` – programmgeneriert (numpy/Pillow): `tools/lumo_kart_art/details/make_detail_textures.py`; Schrift Nunito (OFL, liegt bereits im Projekt). Alle Marken auf den Bannern sind erfundene Fantasiemarken des Lumo-Universums.
