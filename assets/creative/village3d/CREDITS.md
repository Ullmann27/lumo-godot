# Dorfwelt-Assets (assets/creative/village3d) – Herkunft

Alles Eigenbau, ohne fremde Bitmaps, Scans, Fotos, Modelle oder bezahlte Dienste.
Jede Datei wird reproduzierbar von einem Generator im Repo erzeugt:

| Ordner/Datei | Generator | Inhalt |
|---|---|---|
| `textures/*.png` | `tools/lumo_village_art/make_textures.py` | Gelände (Gras, Erde, Fels, Sand), Gebäude-Atlas 4×4, Blattkarten, Wasser-Normalen, Wolken-/Makrorauschen (geseedetes Rauschen, numpy) |
| `terrain/village_heightmap.tres` | `tools/lumo_village_art/make_terrain.py` | Höhenkarte 321×241 (2 m), gesperrte Grundstücke je Ort |
| `models/*.glb` (+ `models.json` mit Dreiecken/Bytes/SHA-256) | `tools/lumo_village_art/build_village_models.py` (Blender bpy 5.3) | alle Gebäude, Landmarken, Bäume, Felsen, Tiere, Boot, Fuhrwerk, Gerüst |
| `ui/res_*.png`, `ui/panel_*.png` | `tools/lumo_village_art/make_icons.py` (PIL) | Rohstoffsymbole und HUD-Tafeln |
| `ui/bld_*.png` | `scripts/tests/village_icon_capture.gd` (Godot-Render der eigenen Modelle) | Gebäudebilder der Bauleiste |
| `shaders/*.gdshader` | von Hand | Gelände, Wasser, Gebäude, Rauch (Mobile/gl_compatibility-fähig) |

Auch die aufgefrischten Bauwelt-Blocktexturen (`assets/creative/bauwelt_voxel/*.png`)
stammen aus `tools/lumo_village_art/make_voxel_textures.py` (gleiche Dateinamen).

Lizenz: Teil des Lumo-Projekts, keine Namensnennung Dritter nötig.
