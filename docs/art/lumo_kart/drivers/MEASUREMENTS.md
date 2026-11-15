# Gemessene Fahrerdateien

Diese Werte werden aus den endgültigen Blender-Messdateien und den tatsächlich exportierten GLB-Strukturen gelesen. Das vollständige maschinenlesbare Verzeichnis mit allen SHA-256-Werten steht in `assets/kart/production/drivers/manifest.json`.

| Fahrer | LOD0 Dreiecke | LOD1 Dreiecke | LOD2 Dreiecke | GLB-Größen LOD0 / 1 / 2 |
|---|---:|---:|---:|---|
| Löwe (`lion`) | 41008 | 23374 | 11892 | 1.92 MiB / 1.27 MiB / 0.86 MiB |
| Eule (`owl`) | 43462 | 24772 | 12602 | 2.01 MiB / 1.32 MiB / 0.88 MiB |
| Nova (`rabbit`) | 39124 | 22300 | 11344 | 1.85 MiB / 1.23 MiB / 0.83 MiB |
| Eichhörnchen (`squirrel`) | 38092 | 21712 | 11046 | 1.81 MiB / 1.21 MiB / 0.82 MiB |
| Schildkröte (`turtle`) | 43286 | 24672 | 12552 | 2.00 MiB / 1.32 MiB / 0.88 MiB |

Alle 15 GLBs besitzen je einen Skin mit 21 Gelenken, sechs Material-Primitives und dieselben sechs Animationen. Jeder Clip enthält 63 tatsächliche Transformationskanäle. Die ersten Keys liegen bei 1/24 s. Beide Normalmaps sind eingebettet; externe Bild- oder Bufferpfade sind nicht erforderlich.

Alle 15 vermessenen Meshes haben null nicht geschlossene Kanten und null ungewichtete Vertices. Je Fahrer wurden sechs Clips an fünf Zeitpunkten am tatsächlich deformierten Blender-Mesh geprüft, insgesamt 150 Posen. Die Basis-Meshes haben keine flächenlosen Dreiecke, ungültigen Normalen oder nicht endlichen UV-Koordinaten.

Die ausführlichen Rig-, Import-, Anschluss-, Herkunfts- und Materialangaben stehen in `DRIVER_CONTRACT.md`. Godot-Verhalten, gemeinsame Kartpassung und tatsächliche Gerätebildrate sind getrennte Prüfebenen; die jeweiligen Prüfberichte nennen die von ihnen untersuchten Dateihashes.

## SHA-256 der Hauptmodelle

| Fahrer | SHA-256 von `driver.glb` |
|---|---|
| lion | `b3925896a2addd6de0f1710410953a77efbe1e72e35f5d74b6339414f3510833` |
| owl | `f07f9c26140790af36961fe780fe0ba77d0d1df8de2117fa5c10a064f89094c3` |
| rabbit | `3f21d290e77fee2e7d0ac66f1f8af0195759628895a2a3d391a1db2b419a13e3` |
| squirrel | `61b1bf1c4d8f7c407001ef23334d402e81417435b841ed87095c5eea3c2a0db0` |
| turtle | `282febd626d383eaf666ace1d845e728e1d5526d6894bdb8209b92ecb3bec77f` |
