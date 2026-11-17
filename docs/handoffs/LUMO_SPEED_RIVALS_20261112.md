# LUMO: doubled physical pace and extreme rivals

Base: `b4ccf593d7833e8c259ff0f963494b00d245d03d` (PR #155). Work branch: `chatgpt/lumo-speed-rivals-20261112`.

## Implemented behavior

- A shared `PACE_SCALE = 2.0` raises real drivetrain speed for the player and all rivals. The neutral Comet now drives at 41.0 m/s (147.6 km/h) in Abenteuer, compared with the previous 20.5 m/s. This changes world movement, not just the HUD.
- Steering and grip response scale with pace; acceleration and braking scale with its square. This preserves controllable turning/braking distances while maintaining distinctions between the fourteen existing karts. The workshop now integrates the same braking response instead of adding an obsolete fixed 1.5 m lag.
- The saved difficulty ID `pro` remains compatible; its display name is **Extrem**. It has no deliberate mistakes, less lateral wobble, faster steering response, stronger cornering and longer overtaking anticipation. All difficulties retain their own pacing and behavior.
- Rivals react to nearby traffic and obstacles over a longer horizon and look further ahead for actual item rings. Existing earned drifts, pickups, shield behavior and warned pulse attacks remain in use. No catch-up multiplier, hidden progress increase or recovery teleport was introduced.
- Ramp approaches brake using the actual drivetrain. Precision jumps retain their authored geometry and require speed control at the higher road pace. A panorama jump before the loop now plans a landing with room for actual road contact before entry.
- A discovered loop-entry bug is fixed: an airborne rival cannot be snapped down onto the loop deck. It must finish its real ballistic flight first.
- Both player and rival target speed accept the action agent's bounded `roadside_speed_factor` metadata. Lasso setup, ticking and visuals belong to the separate action slice.

## Validation

Godot 4.6.3, Linux headless, fixed 60 Hz simulated physics. These are simulation results, not Android/Fold7 performance measurements. No APK/FPS claim follows from them.

| Check | Observed result |
| --- | --- |
| Actual fleet drive | Comet 41.0 m/s; Glider 39.77; Turbo 44.69; Blitz 41.0; Koloss 42.23 |
| Six continuous two-lap opponent fields | 30/30 racers finished; 120 physical landings; 0 rescues, failed loops or stalled windows |
| Largest opponent frame movement | 1.151851 m, below the unchanged 1.5 m discontinuity limit |
| Player, real screen touch/drag input | 98.283333 s; 16 checkpoints, 2 loops, 4 jumps and landings; 0 resets; maximum step 0.715627 m |
| Relative player position | Identical 27.075 m rival travel with player ahead or behind; no rubber band |
| Same unobstructed 50 m road | Mean lane error: Entdecken 0.564 m, Abenteuer 0.011 m, Extrem 0.168 m |
| Physics, fleet tuning, racecraft, precision jump, rival drift/items, rival item feedback, loop contact | PASS |

Last rival finishing each two-lap field:

| Difficulty | Clear course | Stopped player on course |
| --- | ---: | ---: |
| Entdecken | 127.316667 s | 128.250000 s |
| Abenteuer | 88.916667 s | 90.650000 s |
| Extrem | 77.900000 s | 80.500000 s |

The physical straight-line speed is exactly doubled. Whole-race time does not scale exactly by two because braking, jumps and loops remain physical. The earlier player handoff documents 185.25 s on its earlier baseline; the new run is 98.283333 s. That earlier result was not rerun in this worktree.

### Commands

From the worktree, import once:

```sh
godot --headless --editor --import --path . --quit
```

Each regression uses its own temporary `XDG_DATA_HOME`. The command pattern is:

```sh
XDG_DATA_HOME=/tmp/lumo-speed-test godot --headless --audio-driver Dummy --path . --script res://scripts/tests/kart_full_field_regression.gd
XDG_DATA_HOME=/tmp/lumo-speed-player godot --headless --audio-driver Dummy --path . --script res://scripts/tests/kart_player_full_route_regression.gd -- --out=/tmp/lumo-speed-player-proof
```

The same first pattern ran `kart_physics_regression`, `kart_fleet_stats_regression`, `kart_ai_behavior_regression`, `kart_racecraft_regression`, `kart_precision_jump_regression`, `kart_rival_drift_items_regression`, `kart_rival_item_feedback_regression` and `kart_loop_contact_regression`.

Raw measurements, original console output and the full player trace are in `evidence/speed-rivals-20261112/`. Some console text predates the final label/comment cleanup from Sternen-Profi to Extrem. The player trace embeds hashes of the tested scripts. Two passing fixtures also print pre-existing resource-at-exit warnings; these have not been presented as clean teardown results.

### Regression changes and integration boundary

The old difficulty test measured deviation from the starting grid lane during overtakes and pickups as a driving error. It now retains the live race, movement and no-rubber-band assertions, and compares precision on the same unobstructed 50 m road. The old full-throttle precision-gap assertion is replaced by reachable safe landing speed plus an assertion that the new maximum speed overshoots: braking must matter, with no mid-air correction hiding it. Movement discontinuity thresholds are unchanged.

These results cover the speed/AI slice before the action slice is integrated. Root must rerun full-route and full-field acceptance with the added ramps and lasso system. The player fixture currently expects the original four jumps across two laps; four ramps per lap require eight. The action agent updates its own underwater-speed expectation to derive it from the shared powertrain.
