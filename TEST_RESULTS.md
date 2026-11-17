# TEST_RESULTS – lumo-2040/bauwelt-20261117 (PR #195)

Stand: 17.11.2026 ca. 13:30 (Europe/Vienna). Basis bb478880. Godot 4.6.3, Xvfb/llvmpipe, gl_compatibility. Keine FPS-Aussagen.

## Grün (lokal, dieser Branch)
| Test | Ergebnis |
|---|---|
| build_campaign_map_regression (neu) | PASS 54 checks |
| build_defense_regression (neu, nur Logik) | PASS 162 checks |
| build_dialog_density_regression | PASS 2018 checks |
| build_sandbox_ui_regression | PASS |
| build_sandbox_tools_regression | PASS |
| build_village_scene_regression | PASS 232 checks |
| build_settlement_play_regression | PASS 127 checks |
| build_settlement_regression | PASS 194 checks |
| build_village_economy_regression | PASS 339 checks |
| build_village_scaling_regression | PASS 42 checks |
| build_village_art_regression | 2259 checks / 0 failures |
| build_frontier_regression | PASS 14 checks |
| build_transform_regression | PASS 38 checks |
| build_premium_props_regression | PASS |
| build_nextgen_play_regression | PASS 71 checks |
| village_host_launch_regression | PASS |
| mobile_safe_area_regression | 380 checks / 0 failures, aber 1 SCRIPT ERROR in `scripts/lumo_next/learning_world_next.gd:375` (nicht von diesem Branch geändert) |

## Rot
- `tools/validate_project.sh`: Exit 1 bei `[KartPhysics] FAIL: 22 of 24 checks completed`. Dieser Branch ändert keine Kart-Datei. Ob der Fehler auf der Basis bb478880 auch auftritt, wurde nicht geprüft. Möglicherweise lief gleichzeitig ein anderer Strang mit denselben `/tmp/lumo-*.log`-Pfaden. Alle Schritte davor waren PASS (Import, Kart, HostBridge, Jump, Gait, RenderKit, EnvApply, CreativePresets, KartRaceBridge, KartSplit). Die Schritte danach sind NOT RUN.

## Draw Calls Startansicht (scripts/tests/bauwelt_hud_capture.gd)
| Ansicht | vorher LOW/MED/HIGH | nachher LOW/MED/HIGH | Ziel LOW/HIGH |
|---|---|---|---|
| Freie Bauwelt | 230 / 304 / 304 | 237 / 311 / 313 | ≤170 / ≤255 → **verfehlt** |
| Dorf | 121 / 173 / 187 | 157 / 209 / 223 | erfüllt |
| Kampagnenkarte (neu) | – | 184 / 184 / 224 | – |
Bauwelt-Analyse: 3D allein 114 auf LOW. Das HUD kostet in gl_compatibility ca. 123 Draw Calls (je sichtbarer Button Stylebox plus Text). Das alte HUD kostete etwa gleich viel. Für das Ziel müsste die Werkzeugleiste umgebaut werden (weniger gleichzeitig sichtbare Buttons). Offen.

## NOT RUN
- DEVICE TEST NOT RUN · FOLD7 NOT RUN.
- After-Captures im Hochformat: Bauwelt vorhanden, Dorf und Karte im Hochformat nicht (Capture-Lauf abgebrochen, Exit 143). Ein früherer Lauf mit Karte im Hochformat liegt vor dem letzten Farbfix.

## Offen (nicht im Spielfluss)
- Strategie: Regeln, Hasen-Wellen-KI, Stufen-Schwierigkeit, Übernahme und Rückeroberung sowie Tutorial-Status existieren nur als getestete Logik (`build_defense_sim.gd`, `build_defense_state.gd`, `spend_committed`). Keine UI, keine 3D-Einheiten, nicht im Spiel erreichbar.
- Einheitenvisuals, Formationen, große Weltkarte, sichtbar wachsende KI-Dörfer, Effekte (Pfeile, Staub, Fahnen): nicht begonnen.
- Sandbox-Möbel und Robo-Dialoge: nicht begonnen.

---

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

---

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

---

# TEST_RESULTS – lumo-nullpunkt/integration-20261117 (PR #197) – Stand 17.11.2026 13:30 (Europe/Vienna)

Abbruch wegen Nutzungslimit (90 %). **Nicht nach main gemergt**: CI auf dem Kopf-SHA ist nicht grün.

## Reparaturen in diesem Zweig
- `scripts/games/kart_jungle_environment.gd` fehlte auf allen Branches → Dschungelherz stürzte ab. Neu implementiert (Wald, Wasser, Wahrzeichen, Glühwürmchen, Regen, Zielblüten) + `kart_jungle_environment_regression.gd` (lokal PASS).
- `kart_jungle_audio.gd`: fehlende Original-Ambience-Loops → stiller Fallback statt Fehler.
- `kart_neon_layout.gd`: griff auf nicht existierende `badge_label`/`art_frame` zu → Absturz im Kart-Menü. Lokal: `kart_aaa_menu_capture` PASS.
- `kart_regression` Lenk-Flake: Ursache ist persistiertes `auto_gas=false` in `user://kart_preferences.cfg` (von anderen Kart-Tests gespeichert). Mit dieser Datei vor dem Fix reproduzierbar FAIL, nach dem Fix PASS.
- Tests an 13 Strecken / Gate-Struktur / Jungle-Leitplanken angepasst. `build.yml`: Pillow installiert; Release/Pages nur noch bei manuellem Start mit publish=true.

## Lokal (Box, Godot 4.6.3)
validate_project rc=0, import PASS, kart_precision_jump PASS, sonnenhafen stunt/water/darkride/long/visual_finish/hero_coast PASS, kart_regression PASS, progress_profile_lifetime PASS, kart_nextgen_ui_smoke PASS, kart_reference_host_visual PASS.

## Offen / rot (mit Grund)
- CI `real-two-lap-race` (`kart_complete_flow_regression.gd:450`): nach „Zur Spieleauswahl“ ist die letzte Rückgabe nicht `completed` mit der erwarteten resultId. Lokal reproduziert, Ursache noch nicht gefunden (Diagnosemeldung ergänzt).
- CI `build` → `kart_jump_regression`: „A real flight (0.48 s)“ (> 0.5 s erwartet). Nicht untersucht.
- CI `nextgen-visual`: `kart_reference_host_visual` Timeout 120 s in CI, lokal PASS.
- CI `grounded-harbor`: einmal Segfault 139 (Vulkan-Fehler im Runner), Re-Run angestoßen.
- `kart-stage2` (kart_physics_regression): Ergebnis nach den Test-Anpassungen noch ausstehend.
- Integration-2 (lumo-2040/*, lumo-kart/*, #196/#200-Mapping, #529 Memory-Fix): **nicht begonnen**.
- lumo-2013 WIP-Stränge #143/#145/#146 und #144 nicht gemergt (Konflikte, siehe Inventur).
- DEVICE/FOLD7 NOT RUN.
