# Welten-Optik · Zyklus 1 (Bauwelt) – Zwischenstand (WIP, pausiert)

Stand 03.11.2026, Zweig `grok/welten-optik-cycle1` (Basis `grok/lumo-renderkit-cycle3` @ 372937e).
Der Zyklus wurde auf Anweisung pausiert; die Bauwelt-Szene selbst ist **noch unverändert**.

## Fertig
- **RenderKit-Snapshot**: `scripts/systems/render/lumo_environment.gd` / `lumo_quality.gd` byte-identisch aus Lumos
  (uncommitteten) Working Tree übernommen. Beim Rebase auf Lumos Commit durch dessen Version ersetzen.
- **Preset `bauwelt_day`** in `lumo_environment.gd` (eigene `_bauwelt_day()`): heller Tageshimmel, warme Sonne
  (Schatten laut `LumoQuality.budget`, PSSM 2 Splits, weich), Sky-Ambient, dünner Dunst, SSAO-/Glow-/Volumetric-Fog-Werte
  nur als Form (an/aus schaltet weiterhin PerformanceManager), kühles schattenloses Fülllicht `SkyFill` im `rim`-Slot.
  `creative_night` und `wolkeninseln` unverändert.
- **Voxel-Texturen** `assets/creative/bauwelt_voxel/*_albedo.png` + `*_normal.png` (256 px, je Blockfläche),
  rein prozedural erzeugt mit `tools/art/generate_bauwelt_voxel_textures.py` (keine Fremd-Assets).
- **Capture-Skript** `scripts/tests/bauwelt_optik_capture.gd` (Übersicht, Nahaufnahme, Platzieren je Stufe + metrics.json).
- **Vorher-Bilder** (gl_compatibility, llvmpipe): `/workspace/lumo-welten-artifacts/cycle1/before/`
  (`bauwelt_{low,medium,high}_{overview,closeup,place}.png`, `metrics.json`).

## Offen
- `build_world.gd`: `kit.environment(self)` → `LumoEnvironment.apply(self, "bauwelt_day")`, Wolken statt Sterne.
- Bauwelt-eigener Voxel-Styler (z. B. `scripts/creative/build_voxel_style.gd`): abgeschrägte, pro Teil gemergte Block-Meshes
  mit den neuen PBR-Materialien; Kollisionen/Meta weiter aus `kit.part_node()` (IDs, Saves, Kollision unverändert).
  Nebeneffekt: Bauwelt hat heute ~3050 Draw Calls (alle Stufen) – Mergen senkt das stark (wichtig für LOW/Android).
- Boden: Gras-/Erde-Voxel mit eingebackenem Raster statt ~135 Rasterlinien-Boxen.
- Effekte: Platzier-Partikel (CPUParticles3D, aus bei LOW wie `sparkles: 0`), Pop-Tween, pulsierendes Hover-Highlight.
- Nachher-Bilder, Draw-Call-Vergleich, volle Regression unter xvfb.
- Geprüft, nichts übernommen: `origin/chatgpt/lumo-bauwelt-12-procedural-assets-2026-10-15` (Props bereits integriert),
  `origin/chatgpt/lumo-1971-bauwelt-originals-runtime-evidence-2026-10-17` (nur Capture-Test + CI),
  lumo-lernen `origin/claude/lumo-2027-bauwelt-20261029` (keine Bauwelt-spezifischen Godot-Änderungen).

## Testergebnisse (Stand dieses Commits, Logs: `/workspace/lumo-welten-artifacts/cycle1/logs/`)
| Test | Ergebnis |
|---|---|
| validate_project.py | PASS (7 Warnungen, wie Basis) |
| Godot-Import (headless) | PASS, 0 Script-Fehler |
| `--check-only` lumo_environment.gd | PASS |
| creative_scene_smoke | PASS |
| creative_asset_regression | PASS |
| build_premium_props_regression (`--logic-only`) | PASS (Render-Teil nicht gelaufen) |
| bauwelt_optik_capture (Vorher) | PASS |

## Fragen/Vorschläge an Lumo
- `bauwelt_day` ist neu in `lumo_environment.gd` – bitte beim Einfrieren der API übernehmen oder Bescheid geben.
- `rim` wird für `bauwelt_day` als Fülllicht `SkyFill` genutzt; ggf. Rückgabe-Schlüssel `fill` ergänzen.
- PerformanceManager schaltet auf MEDIUM/HIGH `fog_enabled` ein: Presets ohne eigene Fog-Werte bekommen Godots
  Default-Dichte 0.01 (grauer Himmel bei `creative_night`, siehe Vorher-Bilder). Vorschlag: Fog-Werte pro Preset setzen.

## Nachtrag 2026-11-03 – Rebase auf Lumo RenderKit (3af44ad)
- Rebase auf origin/grok/lumo-renderkit-cycle3 (3af44ad) sauber, ohne Konflikte; WIP-Kopie cc4e76c entfällt.
- LumoEnvironment.apply() liefert jetzt zusätzlich `fill` (Fülllicht, bauwelt_day "SkyFill"); `rim` bleibt Gegenlicht (wolkeninseln). Kein Aufrufer las `["rim"]`.
- Nebel explizit je Preset: creative_night Farbe 0c1c3f, Dichte 0.0012, sky_affect 0.0 (aerial 0.0); wolkeninseln unverändert bfeaf6 / 0.0042 / 0.15; bauwelt_day d6eef8 / 0.0025 / 0.0.
- Tests: lumo_renderkit_regression PASS (inkl. neuer fill/Nebel-Asserts), creative_scene_smoke PASS (Bau/Rhythmus/Schatz), creative_asset_regression PASS.
  validate_project.sh: 1. Lauf brach nach kart_regression ab (KartTests PASS, aber Exit-Meldung "ERROR: 4 resources still in use"; auf der Basis 3af44ad nicht reproduziert, Einzel-Wiederholung ohne Fehler → vermutlich flaky). Vollständiger 2. Lauf wegen Limit abgebrochen – offen.
- Performance: Bauwelt hat auf jeder Stufe 3051 Draw Calls – fürs Fold7 zu viel. Nächster Schritt: Instancing bzw. MultiMesh prüfen.
