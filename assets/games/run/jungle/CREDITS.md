# Dschungelherz (Lumo Lauf) – Herkunft der Grafik

Alle Modelle und Texturen in diesem Ordner sind **Eigenbau**: vollständig aus
Programmcode erzeugt, ohne heruntergeladene, gekaufte oder fremde Vorlagen,
ohne bezahlte Dienste. Keine Lizenzpflichten Dritter.

| Was | Erzeugt von | Werkzeug |
|---|---|---|
| `models/*.glb` (Bäume, Pflanzen, Felsen, Tempel, Holzteile, Spielteile, Gegner) | `tools/lumo_run_art/build_jungle_art.py` (fester Seed 20261118) | Blender 5.3 als Python-Modul (`/home/user/tools/bpyenv/bin/python`) |
| `models/textures/*` (Rinde, Blatt-Atlas mit Alpha, Stein, Sandstein, Holz, Moos, Waldboden, Eisen; Albedo + Normal) | `tools/lumo_run_art/jungle_textures.py` | numpy + Pillow (Rauschen, Voronoi, gezeichnete Blätter) |
| `models/jungle_art.json` | Generator (Dreiecke, Materialien, Größen, SHA-256) | – |

Prüfen: `python3 tools/lumo_run_art/verify_jungle_art.py` und
`tools/tests/test_run_jungle_art.py`. Ansicht in Blender/Cycles:
`tools/lumo_run_art/render_jungle_review.py`.

Die GLBs verweisen auf die Texturen unter `models/textures/` (einmal abgelegt,
nicht je Modell eingebettet). Automatische LODs sind in den `.glb.import`
abgeschaltet; die Bäume haben eigene `_lod`-Modelle für die Ferne.
