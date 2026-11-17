# Branch-Inventur lumo-godot – 17.11.2026 (Nullpunkt)

Erstellt von Lumo · HAUPTBOT (Grok Bot) im Auftrag von Heinz („Ja merge“, 17.11.2026 12:35 Europe/Vienna).

Integrationsbasis: `origin/fix/lumo-playready-hub-20261117 @ 6a26a158`. Remote-Branches gesamt (ohne main): 279.

## Hinweis

`lumo-kart/menu-strecken-20261117` und `lumo-kart/gameplay-items-20261117` (samt Draft-PRs) werden seit 12:44 von Chef-HAUPTBOT-Bots bearbeitet: **laufend (Chef-HAUPTBOT-Bots)**, nicht gemergt, nicht angefasst. Zum Inventurzeitpunkt waren sie noch nicht auf dem Remote.

Die Veröffentlichungsschritte in `.github/workflows/build.yml` (Vorabversion + Pages) laufen ab jetzt nur noch bei manuellem Start mit `publish=true`, nicht mehr automatisch beim Merge nach main.

## Kategorien

- **A** schon enthalten: Tip ist Vorfahre von main/Integrationslinie, oder ein Merge ändert keine Datei (dann als No-op-Merge formal angeschlossen).
- **B** fertig und integrierbar: konfliktfrei, ab 10.11.2026, ändert keine `.github`-Workflows → gemergt.
- **C** Konflikt, halbfertig (WIP), veraltet (vor 10.11.), ändert CI/Release-Workflows oder enthält Release-Werkzeug → nicht gemergt, Grund angegeben.
- **D** ersetzt: Tip ist Vorfahre eines neueren Branches (genannt) oder parallele Variante.
- **W** in Arbeit anderer Bots (lumo-2040/* Lumo · Design, lumo-kart/* Chef-HAUPTBOT-Bots) → nicht angefasst.
- **N** nach der Inventur neu angelegt → nicht angefasst.

| Kategorie | Anzahl |
|---|---|
| A | 162 |
| B | 11 |
| C | 68 |
| D | 36 |
| W | 2 |

## Tabelle

| Branch | PR | SHA | Datum | Kat. | Beleg | Aktion |
|---|---|---|---|---|---|---|
| `lumo-2040/bauwelt-20261117` | – | 29fce96b | 2026-11-17 | W | in Arbeit (Lumo · Design) | nicht angefasst |
| `lumo-2040/kart-20261117` | – | 9b348f2f | 2026-11-17 | W | in Arbeit (Lumo · Design) | nicht angefasst |
| `chatgpt/lumo-kart-adventure-20261114-a839` | #183 | c8492665 | 2026-11-14 | B | konfliktfrei, 3 Datei(en): docs/design/2026-11-14-kart-adventure/README.md;scripts/tests/kart_adventure_asset_export.gd;tools/art/render_kart_adven | Merge |
| `chatgpt/lumo-sunharbor-art-20261111` | – | 5ad16154 | 2026-11-11 | B | konfliktfrei, 19 Datei(en): docs/development/LUMO_TECHNICAL_ART_SONNENHAFEN_20261111.md;docs/evidence/technical-art-20261111/sonnenhafen/README.md;d | Merge |
| `chatgpt/lumo-technical-art-20261111` | #152 | e885b145 | 2026-11-11 | B | konfliktfrei, 124 Datei(en): docs/TECHNICAL_ART_20261111.md;docs/development/LUMO_TECHNICAL_ART_SONNENHAFEN_20261111.md;docs/evidence/technical-art-2 | Merge |
| `checkpoint/lumo-c4-return-independent-20261114-2708` | – | 556faff3 | 2026-11-14 | B | konfliktfrei, 5 Datei(en): docs/evidence/native-c4-return-independent-20261114/README.md;docs/evidence/native-c4-return-independent-20261114/green. | Merge |
| `checkpoint/lumo-treasure-runtime-evidence-20261114-2708` | – | b69c654d | 2026-11-14 | B | konfliktfrei, 16 Datei(en): docs/evidence/treasure-504-readiness-20261114-2708/README.md;docs/evidence/treasure-504-readiness-20261114-2708/headless | Merge |
| `evidence/lumo-discovery-afc0df9-20261114` | – | 8b32b128 | 2026-11-14 | B | konfliktfrei, 7 Datei(en): docs/evidence/discovery-afc-targeted-20261114/engine.json;docs/evidence/discovery-afc-targeted-20261114/handoff.json;doc | Merge |
| `feature/lumo-nextgen-voice-godot-bridge-20261115` | – | 6a322439 | 2026-11-15 | B | konfliktfrei, 2 Datei(en): docs/integration/lumo-nextgen-20261115/CHAT3_FOX_HANDOFF.md;scripts/learning/lumo_voice_conversation.gd | Merge |
| `handoff/jungle-emerald-assets-20261115-1a6e` | #186 | 1cda08a9 | 2026-11-15 | B | konfliktfrei, 1 Datei(en): docs/art/jungle_emerald_3600/SUPPORT_DELIVERY.md | Merge |
| `lumo-2013/creative-godot-20261110` | #141 | 74fa4d16 | 2026-11-10 | B | einziger Konflikt TEST_RESULTS.md (Doku), gelöst durch Zusammenführen beider Abschnitte | Merge (Konflikt gelöst) |
| `lumo-2013/guard-ci-20261110` | #138 | 0f74baed | 2026-11-10 | B | konfliktfrei, 3 Datei(en): assets/creative/covers/build.png;assets/creative/covers/rhythm.png;assets/creative/covers/treasure.png | Merge |
| `work/lumo-festival-graphics-20261114` | – | 966f5141 | 2026-11-14 | B | konfliktfrei, 7 Datei(en): assets/kart/home_festival/provenance.json;assets/kart/home_festival/sonnenhafen_festival_gate.glb;docs/design/home-festi | Merge |
| `chatgpt/kart-android-adb-resilience-2026-10-16` | #73 | b9ef3350 | 2026-10-16 | C | Merge-Konflikt in 1 Datei(en): .github/workflows/build.yml | nicht gemergt |
| `chatgpt/kart-android-real-race-gate-1957-2026-10-16` | #77 | 2cac61bf | 2026-10-16 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/argon-source-pdfs.yml;tools/argon_source_pdf.py | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/kart-brake-reverse-2026-10-07` | – | a6821656 | 2026-10-07 | C | Merge-Konflikt in 4 Datei(en): scripts/games/kart_island.gd;scripts/games/kart_vehicle.gd;scripts/tests/kart_brake_reverse_feedback_regression.gd;scripts/tests/kart_vehicle_regression.gd | nicht gemergt |
| `chatgpt/lumo-1971-bauwelt-originals-runtime-evidence-2026-10-17` | #81 | 386f6e2a | 2026-10-17 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-bauwelt-1971-actual-premium-scene.yml;scripts/tests/creative_1971_premium_runtime_capture.gd | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/lumo-audio-diagnostic-76980a94` | – | b127f30d | 2026-11-13 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-audio-lifetime-diagnostic.yml;scripts/tests/diagnostics/kart_lasso_audio_lifetime_diagnostic.gd | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/lumo-bauwelt-12-procedural-assets-2026-10-15` | #68 | ba939042 | 2026-10-15 | C | Merge-Konflikt in 12 Datei(en): assets/shaders/kart_aquarium.gdshader.uid;scripts/creative/build_catalog.gd;scripts/creative/build_premium_props.gd;scripts/creative/creative_runtime.gd.uid;scripts/creative/puzzle_piece.g | nicht gemergt |
| `chatgpt/lumo-character-art-20261111` | – | 0005e507 | 2026-11-11 | C | Merge-Konflikt in 1 Datei(en): scripts/tests/lumo_attention_landing_regression.gd | nicht gemergt |
| `chatgpt/lumo-complete-games-2026-10-07` | #63,#23 | 329b10cc | 2026-10-07 | C | Merge-Konflikt in 2 Datei(en): scripts/games/kart_island.gd;scripts/games/kart_touch_action.gd | nicht gemergt |
| `chatgpt/lumo-complete-nextgen-20261113` | #164 | dc478230 | 2026-11-13 | C | Merge-Konflikt in 6 Datei(en): scripts/creative/build_settlement_region.gd;scripts/creative/build_settlement_state.gd;scripts/creative/build_settlement_world.gd;scripts/creative/build_world.gd;scripts/tests/build_village | nicht gemergt |
| `chatgpt/lumo-darkride-road-guidance-qa-2026-10-17` | – | e1ca954b | 2026-10-17 | C | Merge-Konflikt in 3 Datei(en): assets/shaders/kart_sonnenhafen_darkride.gdshader;scripts/tests/kart_sonnenhafen_darkride_capture.gd;scripts/tests/kart_sonnenhafen_darkride_regression.gd | nicht gemergt |
| `chatgpt/lumo-fox-expressive-face-2026-10-09` | #60,#41 | 8348496b | 2026-10-09 | C | Merge-Konflikt in 4 Datei(en): .github/workflows/kart-stage2-regression.yml;scripts/games/kart_garage_menu.gd;scripts/games/kart_vehicle.gd;scripts/tests/kart_fox_eye_proportions_regression.gd | nicht gemergt |
| `chatgpt/lumo-garage-art-20261111` | – | 0dad5b89 | 2026-11-11 | C | Merge-Konflikt in 1 Datei(en): scripts/games/kart_garage_menu.gd | nicht gemergt |
| `chatgpt/lumo-learning-wonder-details-20261114` | #178 | dbf181e4 | 2026-11-14 | C | Merge-Konflikt in 5 Datei(en): scenes/learning/learning_world.tscn;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd;scripts/tests/learning_wonder_details_regression.gd;scripts/tests/lu | nicht gemergt |
| `chatgpt/lumo-learning-wonder-feedback-20261114` | #174 | f2edd325 | 2026-11-14 | C | Merge-Konflikt in 2 Datei(en): scripts/learning/learning_world.gd;scripts/tests/learning_world_regression.gd | nicht gemergt |
| `chatgpt/lumo-native-qa-worker-20261114` | – | d0b89548 | 2026-11-14 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/agents/lumo-3d-director.agent.md;.github/workflows/lumo-native-3d-qa-worker.yml;.github/workflows/lumo-native-ag | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/lumo-nextgen-chat3-3d-20261115` | #187 | d7e6082d | 2026-11-15 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-nextgen-chat3.yml;assets/characters/lumo_nextgen_chat3/Blender_Lumo_LearningObjects.png;assets/ch | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/lumo-nextgen-feature-20261114` | #182 | 29080ef8 | 2026-11-14 | C | Merge-Konflikt in 1 Datei(en): tools/tests/test_nextgen_runner.py | nicht gemergt |
| `chatgpt/lumo-nextgen-native-blender-integration-20261115` | #189 | b4513ac0 | 2026-11-15 | C | Merge-Konflikt in 2 Datei(en): scripts/learning/learning_activity.gd;scripts/learning/learning_world.gd | nicht gemergt |
| `chatgpt/lumo-sculpted-eye-sockets-2026-10-09` | #40 | ee281622 | 2026-10-09 | C | Merge-Konflikt in 4 Datei(en): .github/workflows/kart-stage2-regression.yml;scripts/games/kart_garage_menu.gd;scripts/games/kart_vehicle.gd;scripts/tests/kart_fox_eye_proportions_regression.gd | nicht gemergt |
| `chatgpt/lumo-source-recovery-20261114` | – | fb89029c | 2026-11-14 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-source-recovery.yml | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `chatgpt/lumo-village-native-host-20261114` | #176 | 5d607860 | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scripts/app/app_boot.gd;scripts/games/game_hub.gd;scripts/systems/host_bridge.gd;scripts/tests/game_hub_magic_capture.gd;scripts/tests/game_hub_magic_regression.gd | nicht gemergt |
| `chatgpt/sulafat-godot-audio-2026-10-10` | #59,#48 | d434f931 | 2026-10-10 | C | Merge-Konflikt in 2 Datei(en): scripts/systems/audio_manager.gd;tools/generate_sulafat_voices.py | nicht gemergt |
| `claude/kart-finish-cine` | – | e5eecd70 | 2026-10-05 | C | Merge-Konflikt in 4 Datei(en): scripts/games/kart_island.gd;scripts/games/kart_vehicle.gd;scripts/tests/kart_finish_capture.gd;scripts/tests/kart_regression.gd | nicht gemergt |
| `claude/kart-rival-race-craft-20261022` | – | 66b280a4 | 2026-10-25 | C | Merge-Konflikt in 3 Datei(en): scripts/games/kart_catalog.gd;scripts/games/kart_island.gd;tools/validate_project.sh | nicht gemergt |
| `codex/lumo-cup-finish-regression-2026-10-09` | #61,#34 | f5647f45 | 2026-10-09 | C | Merge-Konflikt in 4 Datei(en): OPUS_NEXT.md;scripts/games/kart_island.gd;scripts/tests/kart_first_active_snapshot_engine_probe.gd;scripts/tests/kart_modal_backdrop_regression.gd | nicht gemergt |
| `codex/lumo-kart-premium-menu-2026-10-10` | #64,#44 | 026571b9 | 2026-10-10 | C | Merge-Konflikt in 5 Datei(en): scripts/games/kart_garage_menu.gd;scripts/games/kart_menu_choice.gd;scripts/tests/kart_first_active_snapshot_engine_probe.gd;scripts/tests/kart_menu_flow_regression.gd;scripts/tests/kart_st | nicht gemergt |
| `codex/lumo-visual-fidelity-2026-10-08` | #62,#30 | 7ded3f51 | 2026-10-08 | C | Merge-Konflikt in 8 Datei(en): .github/workflows/kart-stage2-regression.yml;.github/workflows/kart-vehicle-regression.yml;OPUS_NEXT.md;scripts/games/kart_character_finish.gd;scripts/games/kart_fur_geometry.gd | nicht gemergt |
| `design/lumo-kart-ui-brief-20261020` | #110 | 322a176a | 2026-10-20 | C | veraltet: Stand 2026-10-20, 593 Commits hinter Integrationslinie; ändert docs/design/lumo-kart-2026-10-20/CODEX_KART_MAIN_MENU_3D_BRIEF.md | nicht gemergt (veraltet, ungeprüft) |
| `design/sonnenhafen-physical-flight-and-ramp-20261103` | – | 16cdda07 | 2026-11-03 | C | Merge-Konflikt in 2 Datei(en): scripts/games/kart_action_course.gd;scripts/games/kart_sonnenhafen_stunt_sequence.gd | nicht gemergt |
| `evidence/lumo-current-c4-kart-20261114` | – | 17f3a07d | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-discovery-originals-20261114` | – | e4fa9bc3 | 2026-11-14 | C | Merge-Konflikt in 12 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/games/game_hub.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-e9a9-warnings-callgraph-909ddb52fe7b` | – | bca73b31 | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-garage-scroll-909ddb52fe7b` | – | cb17c81c | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-host-6b-native-originals-20261114` | – | e46b0aee | 2026-11-14 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-discovery-connections.yml;.github/workflows/lumo-learning-wonder-details.yml;.github/workflows/lu | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `evidence/lumo-hub-original-20261114` | – | 02192998 | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-native-847-discovery-originals-20261114` | – | 1a96e90b | 2026-11-14 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-discovery-connections.yml;.github/workflows/lumo-learning-wonder-details.yml;.github/workflows/lu | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `evidence/lumo-native-e9a9-ci-20261114` | – | 935a4d8f | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-native-host-1e22-43596913210` | – | 66a3700f | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `evidence/lumo-native-upstream-057-20261114` | – | b4b3d7ee | 2026-11-14 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-discovery-connections.yml;.github/workflows/lumo-learning-wonder-details.yml;.github/workflows/lu | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `feat/lumo-65bone-grounded-walk-20261103` | #122 | 8e742ad4 | 2026-11-03 | C | Merge-Konflikt in 5 Datei(en): .github/workflows/kart-vehicle-regression.yml;.github/workflows/lumo-65bone-walk-qa.yml;scripts/characters/lumo/lumo_rigged_actor.gd;scripts/characters/lumo/lumo_walk_locomotion.gd;scripts/ | nicht gemergt |
| `feat/sonnenhafen-physics-ramp-mainline-loop-20261103` | #121 | 820742f4 | 2026-11-03 | C | Merge-Konflikt in 4 Datei(en): scripts/games/kart_action_course.gd;scripts/games/kart_island.gd;scripts/games/kart_sonnenhafen_stunt_sequence.gd;scripts/games/kart_world.gd | nicht gemergt |
| `feature/lumo-volcano-landscape-pilot-20261115` | – | 17cba48f | 2026-11-15 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-kart-arrow-tail-qa.yml;scripts/games/kart_vehicle.gd;scripts/games/kart_world.gd;scripts/tests/ka | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `fix/lumo-2034-3d-english-animals-20261116` | #194 | 49277f1b | 2026-11-16 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-2034-english-animals-qa.yml;test/qa_lumo_english_lab_animals.gd | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `fix/lumo-kart-chevrons-tail-clearance-20261115` | – | 17cba48f | 2026-11-15 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-kart-arrow-tail-qa.yml;scripts/games/kart_vehicle.gd;scripts/games/kart_world.gd;scripts/tests/ka | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `fix/lumo-learning-button-state-contrast-20261116` | – | 4eeafe49 | 2026-11-16 | C | Merge-Konflikt in 1 Datei(en): scripts/learning/learning_world.gd | nicht gemergt |
| `gh-pages` | – | 55519a46 | 2026-10-16 | C | veraltet: Stand 2026-10-16, ? Commits hinter Integrationslinie; ändert .nojekyll;_headers;index.audio.position.worklet.js;index.audio.worklet.js;index.html;index.js;index. | nicht gemergt (veraltet, ungeprüft) |
| `grok/lumo-bauplan` | #130 | c2e5161d | 2026-11-04 | C | veraltet: Stand 2026-11-04, 318 Commits hinter Integrationslinie; ändert BAUPLAN_AUSGANGSLAGE.md | nicht gemergt (veraltet, ungeprüft) |
| `grok/welten-optik-cycle1` | – | e9d84e79 | 2026-11-03 | C | Merge-Konflikt in 10 Datei(en): TEST_RESULTS.md;scripts/creative/creative_kit.gd;scripts/games/jump_islands.gd;scripts/games/kart_island.gd;scripts/games/visual/jump_sky_islands_art.gd | nicht gemergt |
| `integration/lumo-2031-nextgen-jungle-20261116` | #190 | ecdd7f13 | 2026-11-16 | C | Merge-Konflikt in 2 Datei(en): scripts/creative/build_settlement_world.gd;scripts/games/kart_neon_hub.gd | nicht gemergt |
| `integration/lumo-2034-allworkshop-jungle-bauwelt-20261116` | – | 12fa885b | 2026-11-16 | C | Merge-Konflikt in 5 Datei(en): .github/workflows/lumo-bauwelt-child-guidance-qa.yml;.github/workflows/lumo-kart-neon-home.yml;scripts/games/kart_neon_hub.gd;scripts/games/kart_spatial_landing.gd;scripts/tests/kart_neon_h | nicht gemergt |
| `integration/lumo-combined-art-2023-f131` | – | a69cb761 | 2026-11-15 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/workflows/lumo-discovery-connections.yml;.github/workflows/lumo-learning-wonder-details.yml;.github/workflows/lu | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `integration/lumo-dream-paradise-20261114` | – | bf279e4f | 2026-11-14 | C | Merge-Konflikt in 9 Datei(en): scripts/games/game_hub.gd;scripts/learning/lumo_dream_props.gd;scripts/systems/render/lumo_dream_ambience.gd;scripts/tests/dream_garden_capture.gd;scripts/tests/dream_garden_props_regressio | nicht gemergt |
| `integration/lumo-kart-material-20261114` | – | 822cd669 | 2026-11-14 | C | Merge-Konflikt in 10 Datei(en): scripts/games/kart_modular_aero_kit.gd;scripts/games/kart_vehicle.gd;scripts/games/lumo_opponent_roster.gd;scripts/learning/english_object_gallery.gd;scripts/learning/english_vocabulary.gd | nicht gemergt |
| `integration/lumo-learning-nextgen-20261115` | #188 | 561f751b | 2026-11-15 | C | Merge-Konflikt in 1 Datei(en): scripts/learning/learning_activity.gd | nicht gemergt |
| `integration/lumo-live-dream-minimap-union-20261114` | – | 668d00ce | 2026-11-14 | C | Merge-Konflikt in 7 Datei(en): scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd;scripts/learning/learning_wonder_world.gd | nicht gemergt |
| `integration/lumo-magic-studio-2020-20261114` | #177 | c6bb8921 | 2026-11-14 | C | Merge-Konflikt in 5 Datei(en): scripts/learning/learning_world.gd;scripts/tests/learning_world_regression.gd;scripts/tests/treasure_exploration_regression.gd;tools/tests/test_studio_2020_rasters.py;tools/verify_studio_20 | nicht gemergt |
| `integration/lumo-nextgen-learning-20261115` | – | 9d6ef1d7 | 2026-11-16 | C | Merge-Konflikt in 1 Datei(en): scripts/learning/learning_world.gd | nicht gemergt |
| `lumo-2013/bauwelt-sandbox-20261110` | #144 | b5da336b | 2026-11-10 | C | Merge-Konflikt in 3 Datei(en): scripts/creative/build_world.gd;scripts/tests/build_sandbox_tools_regression.gd;scripts/tests/build_sandbox_ui_regression.gd | nicht gemergt |
| `lumo-2013/jump-20261110` | #143 | 74f358d6 | 2026-11-10 | C | WIP-Stopp-Commit vom 10.11.; Merge-Konflikt in 1 Datei(en): scripts/games/jump_islands.gd; Dateien wurden danach von neueren Strängen stark umgebaut | nicht gemergt |
| `lumo-2013/kart-menu-20261110` | #146 | 9b150498 | 2026-11-10 | C | WIP-Stopp-Commit vom 10.11.; Merge-Konflikt in 5 Datei(en): scripts/games/kart_garage_interior.gd;scripts/games/kart_garage_menu.gd;scripts/games/kart_island.gd;scripts/games/kart_vehicle.gd;scripts/tests/kart_menu_depth | nicht gemergt |
| `lumo-2013/puzzle-20261110` | #145 | 284925e9 | 2026-11-10 | C | WIP-Stopp-Commit vom 10.11.; Merge-Konflikt in 4 Datei(en): scripts/creative/puzzle_atelier_art.gd;scripts/creative/puzzle_piece.gd;scripts/creative/puzzle_state.gd;scripts/creative/puzzle_world.gd; Dateien wurden danach | nicht gemergt |
| `lumo-2014/kart-ai-20261110` | – | 9f18b947 | 2026-11-10 | C | Merge-Konflikt in 5 Datei(en): scripts/games/kart_island.gd;scripts/games/kart_rival_racecraft.gd;scripts/tests/kart_ai_behavior_regression.gd;scripts/tests/kart_racecraft_regression.gd;scripts/tests/kart_rival_drift_ite | nicht gemergt |
| `lumo-2014/kart-geometry-20261110` | #151 | a632ee9d | 2026-11-10 | C | Merge-Konflikt in 5 Datei(en): scripts/games/kart_island.gd;scripts/games/kart_rival_flight.gd;scripts/games/kart_rival_stunts.gd;scripts/tests/kart_rival_flight_regression.gd;scripts/tests/kart_stunt_continuity_regressi | nicht gemergt |
| `lumo-next/eleven-tracks-handoff-20261110` | – | f85a3d19 | 2026-11-10 | C | ändert .github (Workflows/Agenten, u.a. APK/Publish/Patcher): .github/handoffs/lumo-other-tracks-code.patch.gz.b64;.github/handoffs/lumo-other-tracks-code.ready;.github/workflows/lum | nicht gemergt (CI/Release-Risiko, Einzelprüfung nötig) |
| `ops/lumo-kart-cloud-checkpoint-protection-20261020` | #112 | e87bda80 | 2026-10-20 | C | Merge-Konflikt in 6 Datei(en): scripts/games/game_hub.gd;scripts/games/kart_garage_menu.gd;scripts/games/kart_island.gd;scripts/games/kart_reference_landing.gd;scripts/tests/kart_nextgen_ui_smoke.gd | nicht gemergt |
| `repair/lumo-native-complete-portals-20261114` | #180 | ec1fb3c3 | 2026-11-14 | C | Merge-Konflikt in 9 Datei(en): scripts/app/app_boot.gd;scripts/games/game_hub.gd;scripts/learning/learning_world.gd;scripts/systems/host_bridge.gd;scripts/tests/game_hub_magic_capture.gd | nicht gemergt |
| `repair/lumo-village-live-completion-20261114` | #181 | 2cea87a4 | 2026-11-14 | C | Merge-Konflikt in 9 Datei(en): export_presets.cfg;scenes/learning/learning_world.tscn;scripts/app/app_boot.gd;scripts/creative/build_settlement_world.gd;scripts/learning/learning_wonder_garden.gd | nicht gemergt |
| `sol/kart-quality-20261026` | – | f49a9f5f | 2026-10-26 | C | Merge-Konflikt in 1 Datei(en): scripts/games/kart_island.gd | nicht gemergt |
| `chatgpt/lumo-3d-agent-network-20261114` | #168 | 3ea8ca80 | 2026-11-14 | D | Tip ist Vorfahre von chatgpt/lumo-native-qa-worker-20261114 | nicht gemergt (ersetzt) |
| `chatgpt/lumo-dream-ambience-20261114` | – | 9d7d1e3c | 2026-11-14 | D | Tip ist Vorfahre von chatgpt/lumo-dream-garden-source-20261114 (+4 weitere) | nicht gemergt (ersetzt) |
| `chatgpt/lumo-dream-garden-source-20261114` | – | 70627936 | 2026-11-14 | D | Tip ist Vorfahre von integration/lumo-dream-paradise-20261114 | nicht gemergt (ersetzt) |
| `chatgpt/lumo-face-showroom-2026-10-09` | #38 | b7815d12 | 2026-10-09 | D | Tip ist Vorfahre von chatgpt/lumo-fox-expressive-face-2026-10-09 (+2 weitere) | nicht gemergt (ersetzt) |
| `chatgpt/lumo-fox-eye-proportions-2026-10-09` | #39 | 6eeea4ea | 2026-10-09 | D | Tip ist Vorfahre von chatgpt/lumo-fox-expressive-face-2026-10-09 (+1 weitere) | nicht gemergt (ersetzt) |
| `chatgpt/lumo-magic-gamehub-portals-20261114` | #175 | db635442 | 2026-11-14 | D | Tip ist Vorfahre von chatgpt/lumo-village-native-host-20261114 | nicht gemergt (ersetzt) |
| `chatgpt/lumo-treasure-magic-wisps-20261114` | #172 | 1b01b08a | 2026-11-14 | D | Tip ist Vorfahre von chatgpt/lumo-learning-wonder-feedback-20261114 | nicht gemergt (ersetzt) |
| `chatgpt/puzzle-3d-core-2026-10-07` | – | 6606d504 | 2026-10-07 | D | alle 1 Commits patch-gleich in Integrationslinie (git cherry) | keine |
| `checkpoint/lumo-dream-minimap-verified-20261114-2708` | – | e2d15dbc | 2026-11-14 | D | Tip ist Vorfahre von checkpoint/lumo-native-merge-20261114-2708 (+14 weitere) | nicht gemergt (ersetzt) |
| `checkpoint/lumo-kart-minimap-verified-20261114-2708` | – | 6ecc560e | 2026-11-14 | D | Tip ist Vorfahre von checkpoint/lumo-dream-minimap-verified-20261114-2708 (+15 weitere) | nicht gemergt (ersetzt) |
| `checkpoint/lumo-native-merge-20261114-2708` | – | a69f5351 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-host-6b-native-originals-20261114 (+7 weitere) | nicht gemergt (ersetzt) |
| `claude/continue-previous-chat-KtY7p` | – | a6dfcc09 | 2026-10-09 | D | Tip ist Vorfahre von chatgpt/lumo-bauwelt-12-procedural-assets-2026-10-15 | nicht gemergt (ersetzt) |
| `codex/lumo-godot-nextgen-audit-20261023` | – | 494416be | 2026-10-23 | D | Tip ist Vorfahre von sol/kart-quality-20261026 | nicht gemergt (ersetzt) |
| `codex/lumo-integrated-runtime-2026-10-08` | #29 | 3f9ff57b | 2026-10-09 | D | Tip ist Vorfahre von codex/lumo-cup-finish-regression-2026-10-09 (+1 weitere) | nicht gemergt (ersetzt) |
| `codex/lumo-lap-session-recovery-2026-10-09` | – | 3f9ff57b | 2026-10-09 | D | Tip ist Vorfahre von codex/lumo-cup-finish-regression-2026-10-09 (+1 weitere) | nicht gemergt (ersetzt) |
| `codex/lumo-modal-viewport-repair-2026-10-09` | #33 | 9eb0979b | 2026-10-09 | D | Tip ist Vorfahre von codex/lumo-cup-finish-regression-2026-10-09 | nicht gemergt (ersetzt) |
| `design/lumo-kart-premium-ui-implementation-20261020` | #111 | 8d9798ef | 2026-10-20 | D | Tip ist Vorfahre von ops/lumo-kart-cloud-checkpoint-protection-20261020 | nicht gemergt (ersetzt) |
| `evidence/lumo-native-847-pr-originals-20261114` | – | 2b8628c9 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-native-847-discovery-originals-20261114 | nicht gemergt (ersetzt) |
| `feat/sonnenhafen-long-flight-20261028` | #115 | 6b4f8a2a | 2026-10-28 | D | alle 1 Commits patch-gleich in Integrationslinie (git cherry) | keine |
| `feat/sonnenhafen-water-lava-cave-20261028` | #116 | db305c1e | 2026-10-28 | D | alle 3 Commits patch-gleich in Integrationslinie (git cherry) | keine |
| `feature/lumo-nextgen-fox-20261115` | – | 8fde4acd | 2026-11-15 | D | Tip ist Vorfahre von feature/lumo-nextgen-voice-godot-bridge-20261115 | nicht gemergt (ersetzt) |
| `grok/lumo-gait-cycle2` | #124 | 372937e6 | 2026-11-03 | D | Tip ist Vorfahre von grok/lumo-renderkit-cycle3 (+1 weitere) | nicht gemergt (ersetzt) |
| `grok/lumo-renderkit-cycle3` | #126 | 3af44ad2 | 2026-11-03 | D | Tip ist Vorfahre von grok/welten-optik-cycle1 | nicht gemergt (ersetzt) |
| `integration/lumo-discovery-connections-20261114` | – | a7bb5815 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+18 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-discovery-final-20261114` | – | 7d53f29e | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+17 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-hub-original-20261114` | – | 71a4c1e2 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+15 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-kart-opus-tracks-2026-10-05` | – | 7b041dd5 | 2026-10-05 | D | alle 0 Commits patch-gleich in Integrationslinie (git cherry) | keine |
| `integration/lumo-live-base-reconciled-20261114` | – | 454e8122 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+21 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-live-c4-recovery-20261114` | – | 1f12bc89 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+23 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-live-connections-20261114` | #173 | 84789d0c | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-host-6b-native-originals-20261114 (+4 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-live-runtime-20261114` | – | 1d7d7a44 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+25 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-live-treasure-wisps-20261114` | – | 8db41cd0 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-current-c4-kart-20261114 (+22 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-native-village-discovery-union-20261114` | – | fe861bd0 | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-host-6b-native-originals-20261114 (+6 weitere) | nicht gemergt (ersetzt) |
| `integration/lumo-next-authorities-20261114` | – | f9d9772b | 2026-11-14 | D | Tip ist Vorfahre von integration/lumo-kart-material-20261114 | nicht gemergt (ersetzt) |
| `repair/lumo-native-2020-apk-20261114` | #179 | 905b83a8 | 2026-11-14 | D | Tip ist Vorfahre von repair/lumo-native-complete-portals-20261114 | nicht gemergt (ersetzt) |
| `repair/lumo-native-discovery-gate-20261114` | – | 84789d0c | 2026-11-14 | D | Tip ist Vorfahre von evidence/lumo-host-6b-native-originals-20261114 (+4 weitere) | nicht gemergt (ersetzt) |
| `assist/lumo-kart-support-team-20261104` | #131 | 25cf93ca | 2026-11-04 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `astra/lumo-animation-quality-2026-10-11` | #57 | 853175c6 | 2026-10-11 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/argon-lumo-review-pdf-2026-10-15` | – | e430f1a0 | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/fold-kart-controls-2026-10-07` | #24 | 0ba0422c | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/godot-launcher-anr-test-recovery-2026-10-16` | – | aebfcd76 | 2026-10-16 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-1986-real-scene-quality-regression-2026-10-19` | #108 | 63cecf09 | 2026-10-19 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/kart-asphalt-material-polish-2026-10-16` | #74 | 268c9b32 | 2026-10-16 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-developer-packs-zip-2026-10-06` | – | d47a0de8 | 2026-10-06 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-himmelsinseln-stage2-2026-10-05` | #18 | 89325ecf | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-quality-profile-autoload-fix-2026-10-18` | #106 | 85f392bf | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/kart-rival-feedback-2026-10-07` | #21 | 4df4b637 | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-video-quality-2026-10-07` | #25 | b79ec387 | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/kart-video-visual-grade-2026-10-07` | #22 | 06d27c33 | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-1977-full-race-resume-precision-2026-10-18` | #102 | 1c70db1c | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-2016-gameplay-effects-20261111` | #155 | b4ccf593 | 2026-11-11 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-action-stage-20261112` | #156 | 1d5c5cb4 | 2026-11-12 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-agent-squad-2026-10-04` | – | d1f077f0 | 2026-10-04 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `chatgpt/lumo-ai-3d-factory-first-slice-2026-10-17` | #96 | 59b1154e | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-all-games-integration-20261103` | #127 | 91b8cdba | 2026-11-03 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-argon-coordinate-audit-2026-10-17` | #82 | 10fb6799 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b-sonnenhafen-viaduct-2026-10-17` | #86 | a8f35b33 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b1-viaduct-ci-approved-2026-10-17` | – | a8f35b33 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b2-sonnenhafen-long-course-2026-10-17` | #88 | 5c657c27 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b3-hero-coast-ci-approved-2026-10-17` | – | 7bdb7ca9 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b3-long-coast-hero-scenes-2026-10-17` | #89 | 7bdb7ca9 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b4-road-nearest-kd-2026-10-17` | #90 | 93801042 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b5-true-coastal-foam-2026-10-17` | #91 | 38b3e489 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b6-clear-sonnenhafen-road-2026-10-17` | #92 | 42b011dc | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-b6-road-clearance-ci-approved-2026-10-17` | – | 42b011dc | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-c4-return-recovery-20261114` | #171 | bebf7bba | 2026-11-14 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `chatgpt/lumo-character-production-2026-10-09` | #42 | d140e5b0 | 2026-10-09 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-creative-effects-20261113` | – | bb889bc2 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-cartoon-burst-vfx-2026-10-17` | #98 | aff8dd36 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-first-playable-2026-10-17` | #95 | 605f5b5a | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-lap-reactive-neon-2026-10-17` | #97 | b70c623d | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-mineral-strata-artpass-2026-10-17` | #99 | 25f5453f | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-reduced-motion-state-guard-2026-10-18` | #100 | 6518a13f | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-darkride-road-guidance-2026-10-17` | – | 25f5453f | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-gate-terrain-flush-detail-2026-10-17` | #94 | a17b06c4 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-gemini-visual-implementation-2026-10-15` | #71 | c850e8d6 | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-godot-1938-complete-integration-2026-10-12` | – | daa775ff | 2026-10-12 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-godot-1938-emergency-fallback-2026-10-12` | – | ec96515a | 2026-10-12 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-graphics-expansion-20261113` | #159 | 25e3a118 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-kart-bauwelt-integrated-2026-10-15` | #69 | 94c95e1d | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-kart-home-20261113` | – | 8d4a4e1e | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-kart-larger-world-preview-2026-10-15` | #70 | ad6bd885 | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-kart-modular-parts-20261114` | #184 | e4d65778 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-living-village-20261113` | – | 7c088c52 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-meshy-start-finish-gate-2026-10-17` | #93 | e1b570e0 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-milestone-a-drive-guards-2026-10-17` | #84 | b8f464d9 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-multilevel-road-projection-2026-10-17` | #83 | 1b632253 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-nextgen-20261113` | #157 | ada5ed81 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-original-fox-jump-20261103` | #128 | bc1f6133 | 2026-11-03 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-pro-agent-fallbacks-2026-10-05` | – | c3a65cac | 2026-10-05 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `chatgpt/lumo-puzzle-menu-20261113` | – | ab923702 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-racing-skill-resonance-gates-2026-10-18` | #103 | e3e0bd94 | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-railkit-first-track-2026-10-15` | #67 | f8466d25 | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/lumo-sol-portrait-menu-recovery-20261021` | #114 | 700baf49 | 2026-10-21 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-sonnenhafen-cinema-rock-material-2026-10-18` | #104 | 5b252231 | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-studio-2020-20261114` | #167 | 34421df8 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-studio-20261113` | #158 | 803e7a62 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-track-art-pass-20261115` | #185 | ebf5a5c7 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-village-release-repairs-20261113` | #163,#162 | 027c2535 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/lumo-winter-world-20261113` | – | a1e083a7 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/repair-opus-handoff-2026-10-07` | #26 | 9ade252e | 2026-10-07 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/sonnenhafen-animated-crane-hoist-2026-10-17` | – | 81ad31d8 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/sonnenhafen-grounding-corrugation-2026-10-17` | – | 6d475aa4 | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/sonnenhafen-lookout-3d-landmarks-2026-10-16` | #76 | 41aa76a2 | 2026-10-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `chatgpt/sonnenhafen-water-visual-qa-2026-10-15` | #72 | 9d80dfff | 2026-10-15 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `chatgpt/sulafat-safety-on-kart-pin-2026-10-10` | – | ec1040c2 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `checkpoint/lumo-blender-production-20261115-f131` | – | 0e7be887 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `checkpoint/lumo-graphics-review-20261113` | – | 72a1330a | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `checkpoint/lumo-puzzle-connections-20261113` | – | 993c1453 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `checkpoint/lumo-treasure-504-visibility-20261114-2708` | – | a8e730ee | 2026-11-14 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `claude/kart-2027-menu-flow-20261029` | – | db3bf178 | 2026-10-29 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `claude/kart-2027-physics-feel-20261029` | – | 929fa3aa | 2026-10-29 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `claude/kart-2027-stunt-on-2006-20261106` | – | 4e0f3ab4 | 2026-11-06 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `claude/kart-2027-track-kit-20261029` | – | dcce2a2d | 2026-11-06 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `claude/kart-integration-2026-10-16` | – | ea69d122 | 2026-10-16 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `claude/kart-landing-landscape-fit-20261022` | – | 3a314260 | 2026-10-22 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `claude/lumo-nextgen-combined-20261113` | – | 76d49866 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `claude/sonnenhafen-harbor-crane-2026-10-17` | #78 | 3453a43a | 2026-10-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `codex/kart-start-light-polish-2026-10-19` | #107 | ffd2955c | 2026-10-19 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `codex/lumo-1909-snapshot-backdrop-2026-10-09` | #35 | 75e563e3 | 2026-10-09 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-1977-cavern-production-2026-10-18` | #101 | efa1f69b | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `codex/lumo-aaa-safe-visuals-2026-10-10` | #46 | ff67107c | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-action-workshop-2026-10-09` | – | 8542c0bb | 2026-10-09 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-claude-game-entry-2026-10-09` | – | f9d2b906 | 2026-10-09 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-face-continuation-2026-10-10` | #43 | 6b401531 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-game-entry-brand-2026-10-09` | #36 | e9ac48b8 | 2026-10-09 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-holographic-kart-2026-10-03` | #4 | a369da2d | 2026-10-04 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-island-cup-2026-10-02` | – | 3435acd4 | 2026-10-02 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-kart-fleet-2026-10-08` | – | 7edbb15d | 2026-10-08 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-kart-reference-final-2026-10-10` | #45 | 81a1306e | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-kart-sunharbor-2026-10-02` | – | 55a35b84 | 2026-10-03 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-modal-fixture-state-2026-10-08` | – | 35cc1376 | 2026-10-08 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-modal-touch-2026-10-08` | – | 6873c072 | 2026-10-08 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-race-continuity-2026-10-08` | #28 | 649e7dc7 | 2026-10-08 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-reference-design-2026-10-08` | #27 | b6889d1e | 2026-10-08 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/lumo-unified-kart-2026-10-03` | – | 36ec0171 | 2026-10-03 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/opus-vehicle-regression-fix` | #13 | 68034268 | 2026-10-05 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `codex/sonnenhafen-tactile-cinema-2026-10-18` | #105 | 20652880 | 2026-10-18 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `codex/track-reference-import-2026-10-05` | #14 | 7351f175 | 2026-10-05 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-character-animation-2026-10-10` | #51 | b056d534 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-kart-aaa-2026-10-10` | #47 | f672e02c | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-kart-animation-integration-2026-10-10` | #52 | b840e7e5 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-kart-production-menu-2026-10-10` | #53 | 2eab464b | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-kart-real-loading-2026-10-11` | #54 | 6063f56f | 2026-10-11 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-kart-stage2-fixture-cleanup-2026-10-11` | #55 | 7cb03702 | 2026-10-11 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-next-level-menu-2026-10-11` | #56 | 3d377f14 | 2026-10-11 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-rival-reference-2026-10-10` | #50 | daaf78bf | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-sulafat-reference-2026-10-10` | – | e3767469 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `computer/lumo-visual-foundation-2026-10-10` | #49 | 08767330 | 2026-10-10 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `copilot/lumo-kart-upload-streckenpakete` | – | edc47b61 | 2026-10-05 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `design/sonnenhafen-precision-flight-road-20261103` | – | ec61db3c | 2026-11-03 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `feature/lumo-child-guided-bauwelt-20261116` | #192 | d4608af5 | 2026-11-16 | A | Merge in Integrationslinie ändert keine Datei (git merge-tree: Baum identisch) | No-op-Merge (formal angeschlossen) |
| `feature/lumo-jungle-emerald-3600-20261115-a298` | – | 36a2a240 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `feature/lumo-nextgen-conversation-20261115-403a` | – | d38967f6 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `fix/lumo-loop-camera-effects-20261113` | – | bd4f59ca | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `fix/lumo-native-android-capabilities-20261115` | – | 678cb38f | 2026-11-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `fix/lumo-playready-hub-20261117` | – | 6a26a158 | 2026-11-17 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `grok/sonnenhafen-jump-cycle1` | #125 | 1300b009 | 2026-11-03 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/astra-kart-landing-on-verified-gameplay-20261021` | #113 | 928fed3c | 2026-10-21 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/kart-verified-gameplay-base-20261021` | – | 63cecf09 | 2026-10-19 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-1999-pinned-godot-20261028` | – | 4d0fd40f | 2026-10-23 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-2006-native-20261103` | #129 | a81ddf12 | 2026-11-04 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-2023-native-complete-20261115` | – | d38967f6 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-2032-workshop-contrast-20261116` | – | f07b007c | 2026-11-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-2034-workshop-bauwelt-neon-20261116` | #193 | bceaa113 | 2026-11-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-c4-connections-20261114` | – | f052c279 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-complete-native-20261114-7a1` | – | 9f834149 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-connections-20261113` | #160 | 993c1453 | 2026-11-13 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-discovery-bd-20261114` | – | baf148b0 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-dream-connections-20261114` | – | bd071225 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-kart-2000-sonnenhafen-flight-cave-20261028` | #117 | adcce309 | 2026-10-28 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-learning-generation-20261115-ea41` | – | d38967f6 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-next-packaging-20261114` | – | 2281d990 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-playready-20261117` | – | bb478880 | 2026-11-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-reviewed-delta-20261115-58e0` | – | d38967f6 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/lumo-safe-area-20261113` | #166 | 17f5b9d4 | 2026-11-14 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `integration/sonnenhafen-2027-stunts-20261030` | #119 | 890fac6c | 2026-10-30 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2013/bauwelt-20261110` | #140 | fe493ea1 | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2013/creative-repair-20261110` | #148 | 7de43014 | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2013/guard-flakes-20261110` | #142 | 3968a1cf | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2013/integration-20261110` | #139 | 47bef06d | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2013/integration-repair-20261110` | – | b4095eea | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-2014/integration-20261110` | #150 | 207bfbc5 | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-next/design-worlds-20261110` | #133 | bff06fbe | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-next/eleven-tracks-20261110` | – | e46262c7 | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-next/game-identity-2013-20261110` | #137 | 568b0df0 | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-next/godot-integration-20261110` | #135 | 9947346e | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `lumo-next/kart-integration-20261110` | #134 | 8c1bf1dd | 2026-11-10 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `qa/sonnenhafen-2003-aerial-flight-captures-20261029` | #118 | 54ed3158 | 2026-10-29 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `repair/lumo-kart-2027-pickup-continuity-20261030` | #120 | 3689307a | 2026-10-30 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `repair/lumo-learning-workshop-3d-20261116` | #191 | 1ade09d4 | 2026-11-16 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `reviewbase/lumo-2023-native-d38967-20261115` | – | d38967f6 | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `sol/lumo-1936-unified-integration-2026-10-12` | – | 82b53fc0 | 2026-10-12 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `sol/lumo-1937-kart-quality-2026-10-12` | #65 | ec96515a | 2026-10-12 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `sol/lumo-harbor-pavilions-1939-2026-10-14` | #66 | d8d00414 | 2026-10-14 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `sol/lumo-kart-fold-games-2026-10-12` | #58 | 82b53fc0 | 2026-10-12 | A | Tip ist Vorfahre von origin/main | keine (bereits enthalten) |
| `sol/lumo-runtime-crystals-kart-20261021` | – | 8d9901c0 | 2026-10-21 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
| `support/lumo-nextgen-native-ci-contract-fixes-20261115` | – | ec702dad | 2026-11-15 | A | Tip ist Vorfahre der Integrationslinie origin/f | keine (bereits enthalten) |
