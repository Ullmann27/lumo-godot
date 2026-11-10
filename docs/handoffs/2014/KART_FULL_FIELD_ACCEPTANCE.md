# LUMO 2014: continuous rival field acceptance

Integration base: `660f746677c449b64b721b27eef7b9dc5bd00fdf`. Engine: Godot 4.6.3, Linux headless. The associated commit contains the controller fixes, new ramp planner, acceptance test and corrected physical item fixture. It is a single incremental commit against this integration base; the earlier exploratory `e55d7e9` is not required.

## Implemented and reproduced defects

- The earlier canned rival ramp animation dropped a kart 2.173 m in one frame. The integrated geometry team's launch-speed flight replaces that arc. Persistent road contact prevents a newly projected ramp sample from skipping the take-off lip.
- A stationary player near the finish trapped four rivals indefinitely: ordinary following-distance braking set speed to zero even when a free passing lane existed. Rivals now turn toward that lane and move at 2 m/s only after checking their next physical step against nearby traffic. They do not receive sideways position changes, progress adjustments, or catch-up boosts.
- The precision ramp now uses the existing ballistic landing solution and the actual kart's acceleration/top speed. Easy rivals can apply full available throttle to clear the mandatory gap. Pro rivals brake toward the landing zone. The ramp target follows generic curve planning so an unrelated heading cap cannot unexpectedly reduce launch speed, while traffic and stun constraints still apply afterwards.
- Loop approach begins 110 m before entry, ahead of the preceding panorama ramp. A 55 m approach started during flight and sometimes left a fast rival on the opposite side without enough grounded road to reach the entry lane. The loop still requires genuine position, direction and launch speed.
- The existing physics item fixture previously changed only reported race progress, leaving cars in the crowded starting grid while passing an invented gap. The corrected fixture places real transforms, speeds and headings consistently: a boost is held behind a stopped player and consumed only in a physically clear corridor. Existing pulse warning, hit and shield checks remain intact.

## Automated result

The test advances the production `_drive_opponents` method at 1/60 s for up to 420 simulated seconds. After initial player placement, no transform, race progress, item, drift charge, boost, or stunt state is injected. All five existing kart profiles remain at their production grid positions. Full pickup gates, road geometry, obstacles, ramp and loop controllers remain active.

All six scenarios passed: **30/30 two-lap finishes, 120/120 mandatory ramp landings, zero gap rescues, zero failed loops and zero stalled 15-second windows**. Both adventurous rivals complete at least two physical loops in every medium/pro scenario. Others may enter the loop naturally when their actual line reaches it. The minimum measured clearance from the stopped player is **1.557 m**. Every per-frame position change is below **0.570 m**; the strict gate remains 1.5 m and is not waived for any rescue.

| Difficulty | Human placement | Finishers | Last finish | Observed speed m/s | Completed loops | Max frame movement |
| --- | --- | --- | --- | --- | --- | --- |
| gemuetlich | Off road | 5/5 | 299.73 s | 4.85–21.58 | 1 | 0.360 m |
| flott | Off road | 5/5 | 199.62 s | 3.66–25.66 | 4 | 0.428 m |
| pro | Off road | 5/5 | 151.43 s | 6.42–34.16 | 5 | 0.570 m |
| gemuetlich | Stopped at finish | 5/5 | 300.32 s | 4.07–18.55 | 0 | 0.344 m |
| flott | Stopped at finish | 5/5 | 204.03 s | 1.58–25.66 | 6 | 0.428 m |
| pro | Stopped at finish | 5/5 | 154.90 s | 1.60–34.16 | 6 | 0.570 m |

Per-racer telemetry, including individual finish times, speed ranges, loop counts, clearance and movement bounds, is stored in `KART_FULL_FIELD_RESULTS.json`. Observed speed includes genuine earned boosts and naturally accelerated loop motion. No value is a device FPS measurement.

## Reproduction and other checks

From the Godot repository root:

```sh
godot --headless --script scripts/tests/kart_full_field_regression.gd
```

Optional diagnostics select a subset, for example `-- --level=pro --stopped-player`. Default execution always covers all six scenarios. An unknown difficulty fails rather than silently passing an empty run.

On this final integrated tree, these headless scripts also passed with exit code 0:

- `kart_physics_regression.gd` (complete existing physics suite, including the formerly failing item check)
- `kart_rival_drift_items_regression.gd`
- `kart_racecraft_regression.gd`

New helper/test formatting and lint checks, plus `git diff --check`, pass. A known Godot teardown resource warning may appear after a successful run; no script, parse or assertion failure is accepted. The separate geometry flight test explicitly requires a rendering server, and a headless invocation is not an accepted result for it.

## Evidence limits

This is a deterministic production-AI controller simulation on Sonnenhafen with a stationary human, not a complete human-driven match, rendered video, Android emulator run, or physical phone/Fold test. It does not measure GPU performance, RAM, thermals, loading time or all twelve tracks. Renderer evidence and device acceptance are reported separately by integration/geometry. No release, save-data migration, package/signature change, or hardware claim is made here.
