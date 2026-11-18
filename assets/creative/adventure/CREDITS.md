# Abenteuerwelten – Herkunft der Assets

Alle Dateien in `assets/creative/adventure/` sind **Eigenbau**:

| Ordner | Erzeugt durch | Inhalt |
|---|---|---|
| `textures/` | `tools/lumo_adventure_art/textures.py` (numpy/Pillow) | Boden (Gras, Sand, Pfad, Fels, Stein), Rinde, Palmrinde, Ruinenmauer, Moos, Holz, Putz, Stoff, Filz, Papier, Dachschindeln, Lautsprechergitter, Wasser-Normalen, Blatt-/Wedel-/Gras-/Flügelkarten, Flamme, Konfetti, Lichtpunkt, Lichtkegel |
| `models/` | `tools/lumo_adventure_art/build_models.py` (Blender bpy 5.3, Skript) | Bäume, Palmen, Büsche, Farne, Grasbüschel, Felsen, Klippen, Säulen, Mauer, Bögen, Höhle, Sternenschloss, Muscheln, Leuchtturm, Lagerfeuer, Zelt, Kiste, Fass, Wegweiser, Krabbe, Möwe, Schmetterling, Lautsprecherturm, Traverse, Moving Head, Atelierlampe, Staffelei, Farbgläser, Spielewelt-Tore |
| `shaders/` | von Hand geschrieben | Blattwind, Moos-Stein, Inselboden, Meer, Brandung, fließendes Wasser, Flügelschlag, Flamme, Lichtkegel, LED-Wand, Notenbahn |

- Keine heruntergeladenen Modelle, Texturen, Fotos, Logos oder Schriften.
- Keine bezahlten oder KI-Bilddienste.
- Lizenz: Teil des Lumo-Projekts; keine Fremdrechte, keine Attributionspflicht.
- Neu erzeugen: beide Skripte erneut ausführen (feste Seeds → gleiche Ergebnisse);
  Prüfung: `python -m unittest tools.tests.test_adventure_art`.
