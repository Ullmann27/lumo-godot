# Spielzimmer (Kartentisch, Memory, Vier gewinnt) – Herkunft

Alles in diesem Ordner ist **Eigenbau**: keine heruntergeladenen Modelle,
Fotos, Texturen, Schriften oder Marken; keine bezahlten Dienste.

| Datei(en) | Herkunft | Werkzeug |
|---|---|---|
| `models/*.glb` (table, chair, shelf, clock, lamp, window, plant, snacks, scoreboard) | prozedural modelliert | `tools/lumo_table_art/build_room_props.py` (Blender/bpy 5.3) |
| `textures/*.webp` (Eiche, Nussbaum, Dielen, Wandbretter samt Normal-Maps, Filz, Teppich, Kreidetafel, Zifferblatt, Buchrücken, Kontaktschatten) | prozedural erzeugt (Rauschen, Sinus-Maserung) | `tools/lumo_table_art/make_room_textures.py` (numpy, Pillow) |

Der Filz übernimmt das vorhandene Sternenkreis-Motiv aus
`assets/cards_table/table/table_top.webp` (ebenfalls Eigenbau) und legt
Faserstruktur und Gebrauchsspuren darüber. Die Ziffern des Zifferblatts sind
mit der System-Schrift DejaVu Serif gezeichnet (freie Lizenz, nur als
Pixelbild, keine Schriftdatei im Projekt).

Lizenz: wie das Projekt. Neu erzeugen: beide Skripte erneut ausführen.
