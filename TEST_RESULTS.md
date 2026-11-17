# TEST_RESULTS — lumo-2040/kreativ-20261117

Stand: Dienstag, 17.11.2026, 13:17 Europe/Vienna.
Godot 4.6.3 headless über Xvfb/llvmpipe, `--rendering-method gl_compatibility`.
Abschluss nach Vorgabe: keine neuen Teilschritte, laufende Arbeit nur gesichert.

## Grün

### Rhythm Party (Commit `8cc7670e`, weiterhin gültig)

- `scripts/tests/rhythm_party_regression.gd` — PASS (auch nachträglich 17.11. 13:16 nach `KIT.star_row`)
- `scripts/tests/rhythm_tour_regression.gd` — PASS (2118 checks)
- `scripts/tests/rhythm_tour_play_regression.gd` — PASS (87 checks)

Draw Calls Übersicht (REFERENZ #141 WIP → ALTER IST Pin `bb478880` → NEUER IST):

- LOW 105 → 115 → **117** (Ziel ≤160)
- MEDIUM 187 → 200 → **203** (Ziel ≤250)
- HIGH 188 → 202 → **205** (Ziel ≤280)

Bilder: `/workspace/lumo/artifacts/2040/kreativ/{ref,before,after}/{low,medium,high}/rhythm_*.png`

### Schatzsuche (dieser Commit)

- `scripts/tests/treasure_island_regression.gd` — PASS (flache Kamera, alte Saves, Serie, neue Fundorte, Rewards)
- `scripts/tests/treasure_exploration_regression.gd` — PASS (92 checks)
- `scripts/tests/treasure_title_contrast_regression.gd` — PASS (3341 checks)
- `scripts/tests/treasure_wisp_regression.gd` — PASS (14 checks)
- `scripts/tests/treasure_density_regression.gd` — PASS (1085 checks; 6 Profile inkl. 640×320, Fold, Portrait)

Vorher-Bilder: `/workspace/lumo/artifacts/2040/kreativ/before/{low,medium,high}/treasure_*.png`

## Nicht gelaufen

- Schatzsuche-After-Captures — **VISUAL PROOF NOT RUN**. Der Abschluss kam, bevor die After-Renders nach dem HUD-/Fundort-Umbau laufen konnten. Die Vorher-Bilder vom Pin existieren.
- Puzzle-After-Captures — **VISUAL PROOF NOT RUN**. Der Puzzle-Umbau wurde zurückgenommen (siehe offen).
- `tools/validate_project.sh` — **NOT RUN** (Zeitbudget; enthält bekannte Kart-/Host-Bridge-Flakes, die nicht zu diesem Strang gehören).
- Gerätetest — **DEVICE TEST NOT RUN**
- Fold7 — **FOLD7 NOT RUN**

## Offen, mit Grund

1. **Puzzle-Meilenstein nicht geliefert.** Ein Anlauf (klarere Werkzeugleiste, Wandschild, stärkerer Snap, Ergebnissterne) ließ `puzzle_rotation_regression.gd` bei 640×360 scheitern: „actual touch selects initial piece 4 through the UI“. Die Änderungen an `puzzle_world.gd` und `puzzle_atelier_art.gd` wurden deshalb nicht committet. Als Nächstes: Werkzeugleiste so umbauen, dass die Spielfläche bei 640×360 nicht verdeckt wird, dann Rotation-, Lifecycle- und Touch-Layout-Tests plus After-Captures.
2. **Schatzsuche visuell nicht abgenommen.** Kompasskarte, fünf neue Fundorte und Fanfare sind getestet, aber ohne After-Render. Vor dem Melden als „besser“ die After-Bilder selbst ansehen.
3. **Rhythm-Lautsprecher-Nahaufnahme.** In `after/high/rhythm_speakers.png` steht eine Bühnensäule teilweise vor dem Gehäuse. Die Membran selbst ist rund und dem Publikum zugewandt. Eine freiere Kameraposition steht noch aus.
4. Merge gegen `integration/lumo-playready-20261117` ist **nicht** vorgesehen (Auftrag: nie mergen).

## Dateien dieses Abschluss-Commits

- `scripts/creative/treasure_state.gd`, `treasure_world.gd`, `treasure_island_art.gd`
- `scripts/tests/treasure_island_regression.gd`, `treasure_density_regression.gd`
- `scripts/creative/creative_kit.gd` (`star_row` für die Ergebnisanzeige)
- `scripts/creative/rhythm_world.gd` (nutzt `KIT.star_row`)
- `TEST_RESULTS.md`
