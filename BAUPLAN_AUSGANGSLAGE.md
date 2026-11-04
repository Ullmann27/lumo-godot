# Bauplan-Ausgangslage (Grok Bot, 4. Nov. 2026)

## Basis
- Zweig `grok/lumo-bauplan` von `integration/lumo-2006-native-20261103` (#129) @ a81ddf1
- #129 enthält #127 (`chatgpt/lumo-all-games-integration-20261103` @ 91b8cdb) vollständig, daher war kein Merge nötig.

## validate_project.sh (ein Lauf, vollständig)
- Godot 4.6.3-stable headless (`/workspace/lumo/Godot_v4.6.3-stable_linux.x86_64`), Laufzeit 165 s, **Exit 0**
- Alle 15 Schritte PASS: Import, KartTests, HostBridgeTests, JumpTests, LumoGait, LumoRenderKit, KartRaceBridge, KartPhysics, KartJump, KartTouchTests, KartLandingFit, LumoCharacterTests, KartWorldTests, KartPauseLayoutTests, KartVehicle
- Kein „resources still in use“, keine Wiederholung nötig

## Mergebarkeit (git merge-tree, nicht nachgezogen)
- #126 `grok/lumo-renderkit-cycle3`: **Konflikte** in `scripts/games/jump_islands.gd` und `scripts/games/kart_island.gd`. Die Basis hat bereits eine RenderKit-Variante samt `lumo_renderkit_regression`.
- `grok/welten-optik-cycle1` (e9d84e7): **Konflikte** in jump_islands.gd, kart_island.gd, `scripts/systems/render/lumo_environment.gd` und `scripts/tests/lumo_renderkit_regression.gd`. Besser die Teile (Preset bauwelt_day, Voxel-Texturen, Capture-Skript) gezielt übernehmen.

## Übergabe
- Stand: Basis grün und dokumentiert, noch kein Bauplan-Code.
- Nächster Schritt: PDF in /workspace/lumo-referenz/ abwarten, danach Kapitel auf Dateien abbilden und Bauwelt-Teile gezielt übernehmen.
- Blender ist auf dem Rechner nicht installiert.
