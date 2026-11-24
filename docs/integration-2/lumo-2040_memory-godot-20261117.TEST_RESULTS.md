# TEST_RESULTS · LUMO 2040 Memory-3D-Tisch (`lumo-2040/memory-godot-20261117`)

Stand: 17.11.2026, ca. 13:20 Europe/Vienna. Godot 4.6.3, Xvfb/llvmpipe, gl_compatibility. Es gibt keine FPS-Aussage.
Geänderte Dateien: `scripts/games/memory/memory_table.gd`, `scripts/games/memory/memory_table_look.gd` (neu) und `scripts/tests/memory_table_capture.gd` (neu).

## Grün
- `memory_table_regression.gd --capture`: **MEMORY_VIEW_PASS, 7020 Prüfungen, 8 Bilder.** Gleiche Prüfanzahl wie vor der Änderung, Stand `197f6911`.
- `native_table_boot_regression.gd`: **PASS (26).**
- `memory_table_capture.gd` (LOW/HIGH × Querformat/Hochformat): **MEMORY_CAPTURE_PASS.** Gemessen auf `a646354e`. Der Folge-Commit `197f6911` ändert nur die Größe des Motivs, die Stilvorlagen der Buttons und die Emission des Holzrands.

## Draw Calls (Profi-Brett mit 24 Karten, im Spiel mit 3 Paaren und 2 offenen Karten)
| Tier · Ansicht | vorher (`bb478880`) | nachher (`a646354e`) |
|---|---|---|
| LOW · Querformat 1920×1080 | 185 | **106** |
| LOW · Hochformat 1080×2400 | 183 | **105** |
| HIGH · Querformat | 185 | 178 |
| HIGH · Hochformat | 183 | 176 |
Vorher waren LOW und HIGH identisch, weil keine Tiers genutzt wurden. Beim Start: LOW 141 → 79, HIGH 141 → 131.

## tools/validate_project.sh
- Lauf mit Weiterlaufen bei Fehlern, damit alle Stufen sichtbar sind. Log: `/workspace/lumo/artifacts/2040/memory/logs/validate_project_all.log`.
- PASS: KartTests, HostBridgeTests (3), JumpTests, LumoGait, LumoRenderKit, LumoEnvironmentApply, CreativePresets, KartRaceBridge, KartTouchTests, KartLandingFit, LumoCharacterTests, KartWorldTests, KartPauseLayoutTests.
- **ROT: KartPhysics** („jungle_emerald_3600: the kart stays inside the rail“) und **KartJump**.
  - Dieser Branch ändert keine Kart-Datei. Der Diff gegen `bb478880` betrifft nur die drei Memory-Dateien.
  - Die `/tmp/lumo-*.log` werden auf der Box von parallelen Agenten mitbenutzt. Das Kart-Jump-Log zeigte einen fremden Spielstand (78 statt 105 Sterne), wurde also während des Laufs überschrieben.
  - Ob die Fehler auch auf der Basis auftreten: **NOT RUN.** Dafür reichte die Zeit nicht mehr.
- Der erste Gate-Lauf brach am bekannten Flake `kart_regression` (Lenk-Assertion) ab. Im zweiten Lauf war KartTests PASS.
- Die restlichen Stufen nach KartPauseLayoutTests liefen beim Abschluss noch. **Ergebnis offen.**

## Nicht gelaufen
- DEVICE TEST NOT RUN · FOLD7 NOT RUN.
- `run_memory_native_authority.py` (Dart- und Godot-Prozess zusammen): NOT RUN. Es braucht CI mit dem Host-Checkout.
- Nachher-Bilder pro Tier nach `197f6911`: NOT RUN. Die Bilder von `memory_table_regression` (8 Stück) gibt es bereits auf `197f6911`.

## Bilder
Vorher: `/workspace/lumo/artifacts/2040/memory/before/` und `before/tiers/`. Nachher: `/workspace/lumo/artifacts/2040/memory/after/` und `after/tiers/`.
