# TEST_RESULTS – lumo-2013/creative-godot-20261110 (PR #141)

Stand: 10.11.2026, Abschluss nach Nutzungslimit. Head vor diesem Commit: 93af86afcfebc17f9720f38a84db0c9c57ffcb4b.

## Grün (vor dem Stopp, 10.11.2026)
- `scripts/tests/treasure_island_regression.gd` – grün (Schatzsuche R3 @76f63a3)
- `scripts/tests/rhythm_party_regression.gd` – grün (nach MultiMesh-Bündelung, vor Membran-Fix)
- `creative_adventure_capture.gd -- --logic-only` – grün
- `creative_scene_smoke` – grün

## Draw Calls (Godot 4.6.3 headless, Xvfb/llvmpipe, gl_compatibility)
- Schatzsuche Overview: LOW 148→138, MEDIUM 254→243, HIGH 278→265
- Rhythm (WIP @93af86a): LOW 105, MEDIUM 187, HIGH 188 (Ziele ≤160/≤250/≤280)

## Nicht gelaufen
- Membran-Fix der seitlichen Lautsprecher (@93af86a): NICHT GETESTET, kein Recapture. `after/rhythm_*.png` gilt nicht als Optik-Abnahme; Referenz `after/rhythm_*_preopt.png`.
- `tools/validate_project.sh` nach dem letzten Commit: NOT RUN
- VISUAL PROOF (Rhythm nach Fix) NOT RUN, DEVICE TEST NOT RUN, FOLD7 NOT RUN

## Nächster Schritt
Rhythm neu rendern, mit preopt vergleichen, Regression + validate_project.sh, dann Abnahme.
