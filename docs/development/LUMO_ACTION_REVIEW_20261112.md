# Integrated roadside action review

Reviewed from `0547fd26c736e90c9dc412858a53e931980faaf7` on 2026-11-12, including the real controller hooks and doubled-speed powertrain.

## Corrections

- Production ground rivals integrate `target_speed` directly into their position. The existing metadata hook therefore already reduces their next actual movement, without an acceleration delay. On a catch the roadside adapter now also immediately sets their observed `motion_speed` to 68%, once. This matches the player's immediate speed/velocity reduction and keeps rival wheel animation, speed-dependent planning and the following physical step consistent.
- Warning and rope geometry now also represent actual rival encounters. When a nearby rival is caught, the rope ends at that rival's actual position. A player's own catch retains presentation priority; otherwise the nearest caught rival is shown. The HUD warning remains specific to the human driver.
- A change of the production player's `reset_count` explicitly forgets that player's temporary encounter state. This handles both backward and forward safe-road resets, including cases in which a distance-only discontinuity check would be insufficient.
- The action regression now requires the production-created `RoadsideLasso` node. It no longer creates a substitute or directly advances the module. Pause and boost release are also exercised through `_physics_process`.

## Evidence

Godot 4.6.3, isolated XDG directories, after a full asset import in the new worktree:

| Regression | Result |
| --- | --- |
| `kart_lasso_regression.gd` | PASS, 34 assertions |
| `kart_roadside_action_regression.gd` | PASS, 176 assertions |
| `kart_lasso_production_regression.gd` | PASS, 24 assertions |

The new production test covers the actual single tick hook, visible warning time, player catch, player/rival pause, real rescue, saving while caught, the real saved-race rebuild, a fresh hold-free restored node, a real rival lane crossing, the rival rope endpoint, immediate speed synchronization, the following physical displacement, expiry and immunity.

Measured real rival motion: **24.532 m/s** in the catch frame before the effect, **16.682 m/s** immediately after the catch (68%), and **16.591 m/s** on the next actual movement step. Both added ramps still pass all six production flights at 20.5/48/70 m/s with a successful landing and no rescue.

Logs: `docs/evidence/kart-action-20261112/integrated-*.log`. All three final runs exited 0, with no script assertion, runtime error or resource-leak warning. The initial unimported worktree failed to resolve asset loaders; a full Godot import resolved that environment prerequisite before the recorded runs.

No changes to `kart_island.gd` or the speed/AI modules are included in this review commit. Native render appearance, device performance and an installed APK remain outside this headless evidence.
