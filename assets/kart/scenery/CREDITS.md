# Lumo Kart – Streckenkulisse (Herkunft)

Alle Dateien in diesem Ordner sind **selbst erzeugt**, ohne fremde Bilder, Modelle oder
bezahlte Dienste. Keine Lizenzpflichten Dritter.

| Dateien | Erzeugt mit |
|---|---|
| `textures/foliage_*.png`, `bark_*.png`, `rock_*.png`, `lamp_albedo.png` | `tools/lumo_kart_art/scenery/build_scenery_textures.py` (Pillow/numpy, prozedural gezeichnet) |
| `models/*.glb`, `models/scenery_models.json` | `tools/lumo_kart_art/scenery/build_scenery_models.py` (Blender 5.3 bpy, prozedural modelliert) |

Neu erzeugen:

```bash
/home/user/tools/bpyenv/bin/python tools/lumo_kart_art/scenery/build_scenery_textures.py
/home/user/tools/bpyenv/bin/python tools/lumo_kart_art/scenery/build_scenery_models.py
```

Die GLB-Dateien enthalten nur Geometrie (keine eingebetteten Bilder); die Texturen
liegen einmal extern und werden in `scripts/games/visual/kart_scenery.gd` gesetzt.
