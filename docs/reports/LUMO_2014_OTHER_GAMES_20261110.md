# LUMO 2014 – other games integration, 2026-11-10

Baseline: `47bef06db45d61d50ecd06d0b0cd0a69b9a25917`. Own branch: `lumo-2014/other-games-20261110`.

## Preserved development

| PR | Actual source | Integration | Scope |
|---|---|---|---|
| #143 | `74f358d639f66f8419f45edad2da667a5d54cc84` | merge `e8a6f41` | Moving platforms, bounce pads, optional stars, island art and save state |
| #145 | `284925e979c070fc495bd6529f2635e4d5ac2d4c` | merge `05871f4` | Atelier, five picture motifs, 6/12/24/48/96 pieces, hover and completion effects |
| #144 | `b5da336b2a0e24c5e0af102f32b9d566591a5c83` | merge `24bc691` | Atomic fill/copy/mirror tools, UI and tests; newer baseline river repairs retained |
| #146 | `9b150498503c2628d025674a2329557450793f1a` | selective commit `3cc5d52` | Garage interior, menu platform shader and menu regression only |

#146 race controller, air tricks and vehicle drift changes are not included here; their overlap belongs to kart integration. #148 is not duplicated and is owned by root integration. Two historic #144 workflows and TEST_RESULTS.md are preserved in ancestry; they are not current release evidence.

## Concrete repairs after integration

- Garage actions previously always returned empty because `SubViewport.world_3d` is null when its internally owned world is used. Query the camera's effective world. Add native touch with pointer ownership, canceled/drag rejection, primary mouse support and synthesized mouse deduplication. Real camera projection and raycasts reproduced failure before repair and pass afterward.
- Show 3D welcome shortcuts only on the welcome step so they do not cover the chosen kart, driver or track.
- Puzzle tray rims were opaque solid plates above the blue felt. Replace them with four actual border rails.
- Puzzle completion animation was below finished piece surfaces (0.22 versus 0.30). Raise it to 0.32 and verify that rendered animation is not hidden.
- Use a restrained wood shader using the existing project wood asset and reduce picture specular glare. Keep original motifs, character and PDF-derived palette.
- Sandbox UI regression incorrectly expected a successful copy to add no blocks. Test actual 9-block fill, 18-block copied/mirrored result, atomic undo and isolated saved state.

## Reference comparison

Original PDF: `Lumo_Referenzmappe_2026-11-03.pdf`, 152 pages. Visual plates inspected include pages 13 (Bauwelt), 31/46 (Puzzle), 48/49 (Jump platforms/props). Original reference plates are design references, not gameplay evidence.

| Game | Baseline | Reference target | Current verified delta | Still needed |
|---|---|---|---|---|
| Jump | Linear 12-island adventure | Moving/alternate platforms, springs, stars, varied world | 3 moving platforms, 3 bounce pads, 8 optional stars; complete physical route and save/resume | More varied enemies and world art; Android input/performance |
| Puzzle | 3 pictures, 12–96 parts, flat room | Garden atelier, thick pieces, blue/gold trays, completion staging | 5 pictures, 6-piece entry, atelier dressing, hover, visible live picture; two full rounds | Portrait HUD scaling and residual surface banding; richer character staging |
| Bauwelt | Repaired playable river islands and original premium assets | Rich workshop, construction freedom | Atomic area tools, copies/mirrors, expanded workflow; old islands preserved | Portrait toolbar responsiveness; further building content |
| Garage | Floating character preview | Spatial stage and legible interaction | Actual interior, unobstructed selection preview, working physical buttons | Further art refinement and device QA |

## Reproduced verification

Godot 4.6.3; Linux Compatibility renderer with Mesa llvmpipe. This is actual engine rendering, not Android/emulator/device evidence. No FPS, temperature, RAM or battery claim.

- `jump_regression.gd`: PASS full 12-island adventure, physical collisions/jumps, three learning stops, save/resume.
- `jump_extras_regression.gd`: PASS 12 checks, moving platforms, pause/question/finish freeze, real bounce, optional star and resume.
- `puzzle_expansion_regression.gd`: PASS 1105 checks under real OpenGL, all 5 motifs × 5 counts, old save version retained, two complete new 6-piece rounds via camera/raycast/drag/drop, visible completion plane and two real captures.
- `build_sandbox_tools_regression.gd`: PASS atomic tools/undo/save.
- `build_sandbox_ui_regression.gd`: PASS isolated visible controls and actual fill/copy/mirror/undo workflow. Logical 48-unit assertions are not proof of physical Android dp.
- `bauwelt_identity_2013_regression.gd`, `creative_asset_regression.gd`, `creative_scene_smoke.gd`: PASS.
- `kart_garage_3d_touch_regression.gd`: PASS 9 checks with real OpenGL, ray, correct/incorrect finger, drag, cancellation, emulated/real mouse.
- `kart_garage_touch_targets_regression.gd`: PASS 240 visible controls at minimum 48×48 dp in tested viewport layouts.
- `kart_menu_depth_2013_regression.gd`: PASS 41 checks. Headless draw-call value is not performance evidence.
- `python3 tools/validate_project.py`: 117 PASS, 7 WARN, 0 FAIL.
- Owned new tests and puzzle files: gdlint PASS; gdformat check PASS for eight touched files including garage menu.
- Whole repository baseline-style checks fail: 1202 lint findings and 218 files needing formatting at initial integration check. No claim of a clean entire-repository style gate. Avoid broad unrelated formatting.

## Actual renderer artifacts

In shared workspace `artifacts/other-games/`: `before/`, `after/`, `reference/`, `logs/`, `image-manifest.json` (SHA-256 for captures). Before is exact baseline; after is this branch. Puzzle/JUMP camera comparisons are generated by the same scripts. Bauwelt includes low/medium/high and overview/closeup/place/workshop/observatory/canyon. Garage includes 1280×720, 412×915 and 690×829 selection/workshop captures.

Puzzle overview draw calls: 89 before, 79 after on the tested renderer. Bauwelt high overview: 239 before, 245 after; low: 169 before, 175 after. Jump island 4: 261 before, 251 after. These are draw calls from engine frames, not real-hardware FPS measurements.

Known visual limitation: portrait Puzzle and Bauwelt captures reveal small/crowded toolbars even when logical minimum sizes pass; a separate responsive HUD correction is required. Puzzle light/surface banding remains visible in Compatibility captures. The L badge is a retained atelier prop, not the Lumo character. No APK, signed release, physical Android measurement or global acceptance is asserted by this report.
