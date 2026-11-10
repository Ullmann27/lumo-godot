# LUMO 2014 - continuous loop contact and rival traversal

Base: `47bef06db45d61d50ecd06d0b0cd0a69b9a25917` (Godot collector used by APK 2013).

## Implemented

- Replaced uniform angle increments with a once-per-entry measured arc-distance table. The old model reported a speed that differed from actual kart movement by up to 20.7% on the 6.5 m loop.
- Player entry begins at the lip, preserves the entered lateral offset, and preserves that offset at exit. Race progress does not run backwards while entering.
- Two adventurous AI personalities choose the Sonnenhafen loop on Abenteuer and Sternen-Profi. They use the same physical loop solver, gravity and path as the player and actually become inverted. Beginner rivals retain the easier road route.
- Interrupted AI loops use the existing safe player snapshot policy: save at the entry road without awarding progress or moving the live kart. No save-version or profile migration.

## Verified on Godot 4.6.3 desktop

| Test | Observed result |
| --- | --- |
| `kart_loop_contact_regression.gd` on original helper | RED: physical speed error 0.207 |
| Same test after patch | PASS: maximum error 0.0102 at radius 6.5 m, 0.0076 at radius 8 m |
| `kart_sonnenhafen_stunt_regression.gd` with actual OpenGL renderer | PASS: full player loop, pad, stars, safe failure and precision jump |
| Precision jump | 21.0 m flight, 3.7 m height, 1.02 s airtime; short/correct/long outcomes pass |
| `kart_stunt_continuity_regression.gd` with actual OpenGL renderer | PASS: full loop with per-frame displacement bounds, no rescue, no exit lane snap |
| Real AI loops | Two completions each on Abenteuer and Sternen-Profi; apex 16.06-16.07 m; inverted orientation checked |
| Snapshot during inverted AI traversal | PASS: on-road saved position, no shortcut, live rival unchanged |
| `gdformat`, `gdlint` (helper and new tests), `git diff --check` | PASS |

`kart_stunt_continuity_regression.gd` accepts `LUMO_GEOMETRY_CAPTURE_DIR` for actual approach/apex/exit PNGs. With `LUMO_GEOMETRY_RECORD=1` it writes `drive-%04d.png` every four 60 Hz simulation ticks. Encode at 15 fps to preserve simulation time. This records the real driven scenario after one initial setup position; no intermediate vehicle pose is injected. The existing camera follows the actual kart.

Use an isolated `XDG_DATA_HOME` when running parallel Godot tests so unrelated test preferences cannot change render quality or session files.

## Remaining acceptance work

- Re-run combined controller tests after integrating independent AI planning changes.
- Full project regression and Android emulator validation are not claimed by this slice.
- No Fold7 device test, FPS, RAM, thermal or Android signature result is claimed.
- This is a functional contact/AI repair, not a new loop/ramp art pass. The other tracks and other ramps require their own scenario coverage. The pre-existing rival jump animation still uses its fixed reference arc outside the loop and requires a separate physical-jump upgrade.
