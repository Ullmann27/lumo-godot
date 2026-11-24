# LUMO roadside action and two additional drivable ramps

Date: 2026-11-12. Base: `b4ccf593d7833e8c259ff0f963494b00d245d03d` (Godot 2016).

## Delivered behavior

Sonnenhafen now has two additional 12 m rising ramps, at approximately 407.4 m and 1544.4 m along the production track. They use the existing physical ramp and airborne controller. Each has 64 m of continuous road after take-off, visible landing posts, and a clear approach. These are additional jumps without a new mandatory gap. The existing precision jump, physical loop, panorama ramps, checkpoint order, darkride and native track scenery remain in place.

The separate roadside module places badger crews on safe stretches of the road. Each crew marks one side lane, gives at least 1.05 seconds of warning before a valid catch, and uses a visible golden target ring and rope. The centre of the road remains clear. A catch reduces speed to 68% for at most 0.65 seconds; the same racer receives a 4 second immunity period. Steering out of the marked lane, an active shield, a turbo, or being airborne avoids the catch. A shield or turbo also ends an existing catch. Player and rivals use the same swept-crossing rules. Reverse travel, a reset or a discontinuous reposition cannot sweep the skipped road for catches. Pause stops the encounter clock.

The roadside characters use the existing `badger` companion, with a distinctive cap, dock, signs and cached rope geometry. Geometry and gameplay share the same placement plan. No new paid asset service or replacement Lumo character was introduced.

Action ramp and gate crossing checks now accept a continuous step up to 14 m instead of the previous 6 m limit. Their regression checks cover a 9 m crossing and reject a 45 m skip. The existing underwater regression uses the production powertrain's base speed rather than a hardcoded 20.5 m/s ceiling, so it remains meaningful with the separate speed change.

## Controller integration

The parent integration owns `kart_island.gd` and the speed/AI files. This commit deliberately keeps the action module separate from those concurrent changes. Required hooks:

1. Preload `res://scripts/games/kart_roadside_lasso.gd`. After each production `world.build`, create its `Node3D` beneath `world`, name it `RoadsideLasso`, and call `setup(world)`. Rebuilding the race world creates a fresh encounter state.
2. In the active, non-arena race tick, after player/rival movement and track events, call `advance(self, delta)` exactly once. The module does not run its own process or physics callback. It also checks pause, finish and race state.
3. Multiply the player drive target and rival ground-drive target by `float(racer.get_meta("roadside_speed_factor", 1.0))`. This metadata is 1.0 normally and 0.68 only during the bounded hold. The player receives one immediate matching reduction of actual speed and velocity on the catch event, not repeated frame damping.
4. A fresh start/load should restore the player's and rivals' `roadside_speed_factor` to 1.0 before movement. The new module also resets it on its first update. Do not serialize the temporary hold into a saved race.
5. The complete two-lap player regression now encounters four action ramps per lap. Its expected take-off/landing count must become eight, while keeping the original two-lap, precision-jump and loop assertions intact.

The initial isolated `kart_roadside_action_regression.gd` could create the same module when the controller hook was absent. The subsequent integrated review removed that fallback: the test now requires the production-created node and drives it exclusively through `_physics_process`. See `LUMO_ACTION_REVIEW_20261112.md` for the integrated evidence and follow-up fixes.

## Verification performed locally

Godot `4.6.3.stable.official.7d41c59c4`, headless, dummy audio, separate XDG data/config/cache directories:

- `kart_lasso_regression.gd`: **PASS, 34 assertions**. Includes 30/60/120 Hz and 10 Hz at 70 m/s, swept lane interpolation, counterplay, bounded hold and immunity, reverse/reset handling, pause, and identical player/rival rule results.
- `kart_roadside_action_regression.gd`: **PASS, 175 assertions**. Includes production road geometry, both additional ramp surfaces and landing corridors, safe encounter placement, actual crew/target/rope nodes, a live production-player catch with immediate slowdown, pause and turbo release, plus six actual production-controller jump flights.
- New module scripts parsed successfully with Godot. `git diff --check` passed.

Observed production-controller ramp flights (metres per second on entry):

| Ramp distance | Entry speed | Peak above road | Successful landing | Reset |
| --- | ---: | ---: | ---: | ---: |
| 407.4 m | 20.5 | 1.93 m | 1 | 0 |
| 407.4 m | 48.0 | 2.07 m | 1 | 0 |
| 407.4 m | 70.0 | 2.02 m | 1 | 0 |
| 1544.4 m | 20.5 | 2.06 m | 1 | 0 |
| 1544.4 m | 48.0 | 2.48 m | 1 | 0 |
| 1544.4 m | 70.0 | 2.64 m | 1 | 0 |

The raw logs are in `docs/evidence/kart-action-20261112/`. These results apply to this action slice on the base above. Combined high-speed full-route and rival-field tests must run after integration with the separate speed changes.

## Renderer and device verification still required

No real display is available in the local execution environment. The existing `kart_action_course_regression.gd` includes a real-display requirement and was not claimed as passing here. Native render captures, Fold7 appearance, APK installation and sustained 60 FPS are not evidenced by the headless results.

For a renderer job, run the new live action regression with `LUMO_ACTION_CAPTURE_DIR` set to an artifact directory, without `--headless`. The test saves an actual lasso-catch frame and one airborne frame for each of the six ramp/speed combinations. Setting that capture variable in a headless run fails the capture check rather than substituting a mock screenshot.

Example logic checks:

```sh
godot --headless --audio-driver Dummy --path . --script scripts/tests/kart_lasso_regression.gd
godot --headless --audio-driver Dummy --path . --script scripts/tests/kart_roadside_action_regression.gd
```

Example renderer check (inside an already configured display session):

```sh
LUMO_ACTION_CAPTURE_DIR=/tmp/lumo-action-captures godot --audio-driver Dummy --path . --script scripts/tests/kart_roadside_action_regression.gd
```
