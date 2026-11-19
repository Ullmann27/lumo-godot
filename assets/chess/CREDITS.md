# Lumo Schach – Herkunft

Alles in diesem Ordner ist **Eigenbau**: keine heruntergeladenen Modelle,
Fotos, Texturen, Schriften oder Marken; keine bezahlten Dienste.

| Datei(en) | Herkunft | Werkzeug |
|---|---|---|
| `models/*.glb` (pawn, rook, knight, bishop, queen, king, board) | prozedural modelliert: Drehkörper aus Profilen mit gerundeten Ecken, Springer als abgerundete Silhouette mit Mähne | `tools/lumo_chess_art/build_chess_set.py` (Blender/bpy 5.3) |
| `textures/*.webp` (Brettfläche mit Intarsienrand, Ahorn/Nussbaum für Figuren und Rahmen, Filz, Kontaktschatten) | prozedural erzeugt (gestrecktes Rauschen, Sinus-Jahresringe) | dasselbe Skript (numpy, Pillow) |
| `icons/*.webp` (Figurensymbole der Draufsicht) | Cycles-Render der eigenen Modelle mit den eigenen Holztexturen | dasselbe Skript (`--only icons`) |

Lizenz: wie das Projekt. Neu erzeugen:
`/home/user/tools/bpyenv/bin/python tools/lumo_chess_art/build_chess_set.py`
