# TEST_RESULTS – lumo-2040/tutor-godot-20261117 (Lumo-Nachhilfe, 3D-Szene)

Stand: 17.11.2026 (Europe/Vienna), Abschluss wegen Wochenlimit (WIP M1).

## Grün
- Headless-Smoke (Godot 4.6.3): `scenes/learning/tutor_world.tscn` und alle
  `scripts/learning/tutor/*.gd` laden ohne Parse-Fehler (Typ-Inferenz-Fehler in
  `tutor_world.gd:678` behoben); ungültiger Payload (`{"kind":"tutor"}` ohne Pläne) wird
  abgelehnt (fail-closed, `valid=false`).

## NOT RUN
- Szene mit gültigem Payload aus Flutter (Fixtures 8+5 / 6+7) – NOT RUN: Fixture-Erzeugung
  lief in ein Zeitlimit; kein neuer Teilschritt mehr begonnen.
- Regressionstest für `tutor_plan.gd` (Stufen, Vorzeigen/Üben, Drag-Zählung) – NOT RUN, noch nicht geschrieben.
- Captures (Rechenrahmen, Zahlenstrahl, Zerlegen; Hoch/Quer) – NOT RUN.
- gdlint, Android-Export, Gerätetest – NOT RUN.

## Offene Punkte
1. Fixtures aus Flutter erzeugen, headless-Regression für `tutor_plan.gd` schreiben.
2. Captures je Weg/Stufe, Performance auf low-Profil.
3. Routing `app_boot.gd` (learning + kind=tutor → tutor-Szene) ist eingebaut, in der App aber
   unerreichbar, solange der Flutter-Einstieg verborgen ist.

---
## Früherer Stand (aus Basis übernommen, unverändert)

# TEST_RESULTS – lumo-2013/bauwelt-sandbox-20261110 (PR #144)

Stand: 10.11.2026 19:55 (Europe/Vienna), Abschluss nach Nutzungslimit. Basis fe493ea1 (#140).

## Commits von Lumo · Design
- 6309c9a9: leerer WIP-Checkpoint (kein Feature-Code). Lokal nichts getestet.

## Commits eines anderen Bearbeiters (Ullmann27, 14:40–14:52), nicht von mir geprüft
- cf42829..44da602: Füllen/Kopieren/Spiegeln als atomare Werkzeuge inkl. Touch-UI, Tests
  `scripts/tests/build_sandbox_tools_regression.gd`, `scripts/tests/build_sandbox_ui_regression.gd`.
- GitHub-Checks auf 44da602 (abgefragt 10.11.2026 19:55):
  real-godot-tests success, real-native-proof (bauwelt) success, real-native-proof (precision) success,
  combined-godot-runtime success, Gitar success, **verify failure**, CodeRabbit skipped.
  Ursache des verify-Fehlers: nicht untersucht.

## Nicht gelaufen (von mir)
- `tools/validate_project.sh`: NOT RUN. VISUAL PROOF NOT RUN, DEVICE TEST NOT RUN, FOLD7 NOT RUN.

## Nächster Schritt
1. verify-Fehler auf 44da602 klären.
2. M1 Rest: Chunks/MultiMesh, Migrationstest SAVE_VERSION 1, Vorher/Nachher-Captures.
3. M2: Funktionsblöcke + Spielmodus. M3: Robo-NPCs, JSON-Missionen, Wallet.
