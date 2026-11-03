# TEST_RESULTS – grok/welten-optik-cycle1 (Stand 3.11.2026, Abschluss bei Nutzungslimit)

Basis: `origin/grok/lumo-renderkit-cycle3` @ 3af44ad (Lumos RenderKit). Status: Bauwelt-Optik WIP, pausiert, kein PR.

| Test | Ergebnis |
|---|---|
| lumo_renderkit_regression (inkl. neuer Prüfungen `fill` + Nebel je Preset) | PASS |
| creative_scene_smoke (Bauwelt, Rhythmus, Schatzsuche) | PASS |
| creative_asset_regression | PASS |
| build_premium_props_regression | PASS nur mit `--logic-only` (Render-Teil nicht gelaufen) |
| validate_project.sh | UNVOLLSTÄNDIG: Lauf 1 Abbruch nach kart_regression wegen „4 resources still in use“ beim Beenden (vermutlich flaky, auf 3af44ad nicht reproduziert); Lauf 2 grün bis KartWorldTests, dann wegen Nutzungslimit abgebrochen |

Offen: voller validate_project-Lauf; build_world.gd auf `bauwelt_day` + neue Voxel-Materialien umstellen; Draw Calls (3051 je Stufe) per MultiMesh/Instancing senken; Nachher-Screenshots.
Details: `docs/welten-optik/cycle1_results.md`, Logs/Bilder unter `/workspace/lumo-welten-artifacts/cycle1/`.
