# LUMO 2014+ – Live integration audit

Read-only audit on 2026-11-10. No working-tree edits, merges, releases, or game tests performed by this audit agent. GitHub metadata, CI job summaries/logs and local commit ancestry were read. PR descriptions are not current source-of-truth when later commits exist.

## Baselines

- Flutter APK 2013: `76aa559cb03d968f492b59129c1b7cee057e76e9` (PR #450).
- Godot pin in that candidate: `47bef06db45d61d50ecd06d0b0cd0a69b9a25917`.
- All nine inspected development PRs remain open drafts. Nothing was merged into main by this audit.
- CI listing connector returns PR-triggered runs only. Push-only specialist workflows require their specific run ID; green generic runs alone do not prove the specialist gate passed.

## Integration matrix

| Repository / PR | Actual current HEAD | Relative to candidate 2013 | Observed CI / next check |
|---|---|---|---|
| Godot #140 Bauwelt | `fe493ea1d9e44e20ca87fbd3ffbae3bb1f658878` | Fully included by ancestry; no remaining delta | Generic Godot integration, native lifecycle, stunt and twelve-prop QA green. Do not apply again or regress river-island repairs later added in candidate. |
| Godot #141 Rhythm/Treasure | `74fa4d1631a2903f61bb112e5ba6a6399be64612` | Only through `b8a63a0` included; four later commits remain | Latest head is documentation-only. Three generic runs green. PR body still quotes old `93af86a`. Use repair branch #148 for substantive R3/Rhythm delta. |
| Godot #143 Jump | `74f358d639f66f8419f45edad2da667a5d54cc84` | Not included; one commit, two game files | Stage 2/stunt/gait workflows green. Dedicated new-mechanics tests and after-render proof still absent from PR. Check moving-platform carry, bounce pad trigger bounds, checkpoint persistence, bonus collection. |
| Godot #144 Sandbox | `b5da336b2a0e24c5e0af102f32b9d566591a5c83` | Not included; built on included #140 | Body falsely stale as empty checkpoint. Actual fill/copy/mirror + atomic undo + UI implemented in `dc04b93..2b68ef3`. Three generic head runs green. `TEST_RESULTS.md` reports specialist `verify` failure on last code head `44da6026294801a82ddd4fc437deba0950246ee9`; cause not yet resolved by this audit. Must run tools/UI regressions and preservation check. |
| Godot #145 Puzzle | `284925e979c070fc495bd6529f2635e4d5ac2d4c` | Not included; nine files | Generic integration/lifecycle/stunt green. New atelier, two motifs, six-piece mode, hover/snap/finish shader need exact after renders and extended play tests. |
| Godot #146 Garage/tricks | `9b150498503c2628d025674a2329557450793f1a` | Not included; twelve files | Twelve listed generic/specialist workflows green. Product delta overlaps `kart_island.gd` and `kart_vehicle.gd` with new 2014 physics work. Integrate before new edits or port carefully; dedicated air-trick and menu-depth tests needed on combined state. |
| Godot #148 Creative repair | `7de43014f7a8983ac79aa1d9ba85a152fec4b79b` | Not included; includes remaining #141 gameplay then repairs | **Specific push run 42857422251 verified SUCCESS** (see below). GitHub reports mergeable:false against old base branch, but dry `merge-tree` into candidate 2013 is clean. Recommended prior-work integration candidate after image inspection. |
| Flutter #446 Learning art | `d723ea880eec09d896470ed70ef508af38b4839e` | Not included; 27 new images and nine code/test/config files | Full suite failed. Fourteen screenshot tests hardcode `/workspace/...` and hit permission denied on runner; twelve older hub/layout failures also occur. Integrate on fixed 2013 baseline, repair output path and run full suite. Preserve current pubspec version. |
| Flutter #449 Games play | `84f610522db4bc49625773ef6bbf0578da999074` | Not included; one commit/fifteen files | Latest full suite failed: 2057 pass, 197 skip, 13 fail. Most failures are stale hub base; Four-in-a-row complete touch game also fails at `games_screen_flow_test.dart:144` (no usable column found). Integrate on fixed 2013 baseline and reproduce. |

## Proven #148 completion, not just PR claims

Exact run: https://github.com/Ullmann27/lumo-godot/actions/runs/42857422251

Job `129974152392` completed success; every listed verification step succeeded:

- Format/lint repaired scripts and import project.
- Rhythm/Treasure regressions.
- Real LOW/MEDIUM/HIGH captures and draw-call ceilings.
- Complete gameplay captures.
- `validate_project.py`, `validate_project.sh`, full-repository lint/format debt comparison.

Proof artifact `13782799610`, `lumo-2013-creative-repair-proof`, 33,630,651 bytes, not expired. Archive digest `sha256:6255ab1d6c00ce1a233ea292891a52b0b81339fa038e0fff937044a7e3244ce2`. It is associated with exact HEAD `7de43014...`. Capture contents have not been visually reviewed by this audit agent; no visual acceptance claimed. This is Linux Godot evidence, not Android or Fold7 hardware evidence.

PR #148 includes a workflow that can auto-commit formatting. Its outputs must be compared to the committed HEAD; the run succeeded, but do not assume any hypothetical later auto-commit exists. Refresh branch head before integration.

## Conflict checks without mutating checkouts

`git merge-tree --write-tree` was run for each branch independently into the 2013 baseline. All checked pairs merged cleanly syntactically. This is not combined integration validation and does not establish behavioral compatibility.

| PR | Computed merged tree |
|---|---|
| Godot #143 | `6535713fd966d4ced3b50f0f48c941baba566088` |
| Godot #144 | `9b715dc58b9fbebdf6c6eafc1d0c1a7cc5f98b46` |
| Godot #145 | `3163b4eadc38f96949a774871ca5de8eb4eb0aac` |
| Godot #146 | `1333741f9044d3acbd05cce2cd1dc1ebfe5e0476` |
| Godot #148 | `60c6277829ea3be09cd47e55d16fd3dec11ee53f` |
| Flutter #446 | `e1fb1b87f9a5c523710d0be1059726a919c17e3f` |
| Flutter #449 | `9d0c4bf0dbd1c60e3e0fb199cc7817f1449851d6` |

Do not replace entire files with old branch versions: e.g. direct two-dot diff from #148 to candidate would remove integrated Bauwelt landmarks. Merge/cherry-pick deltas with ancestry instead.

## Exact Flutter failure evidence

#446 run 42823768078, job 129855671586: `lern_optik_capture_test.dart` fails fourteen phone/Fold captures with `Creation failed, path = '/workspace' (OS Error: Permission denied, errno = 13)`. Final summary 2047 pass / 180 skip / 26 fail. Remaining failures concern old Spielewelt layout, routes and Bauwelt availability, so they must be reevaluated on current baseline rather than patched blindly.

#449 run 42834717106, job 129894018442: final summary 2057 pass / 197 skip / 13 fail. Failing tests:

- `home_lumo_meister_entry_test`: RenderFlex overflow 23 px.
- `design/parent_games_polish_test`: layout overflow 21 px; rapid Cards navigation finds no `LumoStarTrailScreen` (old expectation).
- `games/lumo_cards_fair_bot_test`: expects Bauwelt comingSoon but sees playable.
- `games/games_world_layout_test`: duplicate Quizshow title; old Cards showcase expectation; overflow.
- `games/lumo_meister_portal_test`, `flame_adventure_round_test`, `flame_adventure_flow_test`: hub overflows.
- `games/games_screen_flow_test.dart:144`: Four in a row complete touch flow expects usable columns but finds none. This is the game-specific failure to investigate after baseline update.

## References and capture inventory

Original PDF was resolved by parent as `Lumo_Referenzmappe_2026-11-03.pdf` (75,905,897 bytes); audit agent has not read its image pages. Existing repository report `docs/qa/lumo-kart-support-20261104/TEAM.md` identifies it as 152 pages and points to Sonnenhafen pages 16–17, requirement pages 98 and 112–118. These page numbers are a retrieval aid from prior report, not a new visual review.

Available original repository references:

- `assets/characters/lumo/reference/01_master_character_sheet.png`, `02_orthographic_model_sheet.png`.
- `docs/design_targets/2026-10-29-kart-reference/kart-ref-01-loops-bridges-last-lap.jpg`, `02-boost-ramp-lighthouse`, `03-loop-gate-windmill`, `04-glass-tunnel-waterfalls`.
- `docs/design_targets/2026-10-08-kart-fahrzeuge/` (seven original figure/kart sheets).
- `docs/design_targets/KART_VIDEO_DIRECTION_2026-10-07.md`: actual chase-camera frames at 1280×720; near/low camera; horizon and landing readability; bounded FOV; Reduced Motion; loop/ramp only accepted with physics/camera/AI/collision/respawn proof.
- `docs/puzzle/2026-10-07/references/puzzle_key_art.webp`, `puzzle_board.webp`; `REFERENCE_SPEC.md` explicitly separates picture-surface art from genuine 3D scenery.
- `docs/track_expansion/2026-10-05/legacy_reference_notes/Track_*/docs/DESIGN_BRIEF.md` and original design-target image packs for all other tracks.

| Game / area | Required current-before and candidate-after captures / play proof |
|---|---|
| Sonnenhafen | `kart_sonnenhafen_generation_capture.gd`: race_camera, elevated_overview, landmark_wow. Precision capture: loop run-up, loop exit-to-ramp, side gap/landing, takeoff/airborne/landing/too-slow states. Must add continuous driven loop proof; posed screenshots alone insufficient. |
| Bauwelt | `bauwelt_optik_capture.gd` fixed overview/close-up at LOW/MEDIUM/HIGH; `creative_build_capture.gd` house, bridge test, tower, pause with JSON reload; new Sandbox tools touch-use and atomic undo views. Reference PR points to Tafeln 03,04,60–63 (visually verify in PDF). |
| Rhythm | `creative_worlds_optik_capture.gd` overview, songselect, closeup, cover for all tiers from repaired branch; compare speaker membranes to pre-optimization reference. `creative_adventure_capture.gd` playable note sequence. |
| Schatzsuche | Same capture harness overview/closeup/cover, R3 fixed camera, discoveries; `creative_adventure_capture.gd` exploration and actual completion/save. |
| Puzzle | `creative_puzzle_2013_capture.gd` same camera as pre-pass; `creative_puzzle_capture.gd` 12-part, 96-part, hint, plus actual pick/drag/snap/JSON resume; add 6-piece and new-motif completion tests. |
| Jump | `jump_optik_capture.gd` overview/closeup; add real moving-platform, bounce-pad, bonus island and checkpoint-resume progression. |
| Garage | `kart_menu_depth_2013_regression.gd`, menu/garage capture from portrait/landscape/Fold and real 3D button activation; ensure all five existing menu stages remain reachable. |
| Memory / Cards / Four-in-a-row / Quiz | `test/design/flutter_games_2013_capture_test.dart` on actual current baseline plus phone/Fold layouts. Complete rounds, save/resume and bot actions; keep Cards route identity and prevent double-open. |

## Limitations

No Android emulator, physical-device, FPS, thermal, memory or APK verification was executed by this audit agent. Green historic runs apply only to their recorded commits. No claim that all prior branches or every historical PR was audited; scope is the nine pending streams assigned above.
