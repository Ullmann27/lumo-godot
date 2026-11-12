# Combined speed, action ramps and roadside lasso acceptance

Production basis: `0547fd2` on `chatgpt/lumo-action-stage-20261112`. This combines the doubled physical pace, extreme rivals, two additional Sonnenhafen ramps and the live roadside-lasso lifecycle.

This follow-up changes only the two driving fixtures and saves their evidence. No production fix or relaxed movement gate was needed after integration.

## What the fixtures now exercise

The complete opponent field runs through `kart_island._physics_process(1/60)` instead of calling `_drive_opponents` directly. Therefore player physics, opponent traffic/items, track events, the lasso clock and its per-racer state, checkpoints and session saves all run in their production order. The clear-course stationary player is initially placed on the shoulder inside the rail, because full player physics correctly rejects the old isolated-fixture position 20 m outside the road. The obstructed scenario retains a stationary player in the outside racing lane.

All five rivals must physically finish two laps, complete at least eight ramp landings, cross both roadside crews on both laps, avoid rescues and fifteen-second stalls, and stay under the unchanged 1.5 m movement-step gate. Adventurous drivers still must complete two loops. Lasso slowing must use exactly the published 0.68 factor and last no longer than 0.65 s plus one simulation tick. The fixture records observed encounter crossings cumulatively because the production rules intentionally prune old lap keys.

The player fixture uses actual screen touch and drag events for gas, steering and braking. Its first-lap route deliberately meets one warned lasso lane, then avoids later crews through steering. It requires a real catch, an avoidance, a finite bounded slowdown, eight jumps and landings, two inverted loops and all sixteen checkpoints, with no rescue or progress injection.

## Player result

- PASS in 98.516667 simulated seconds.
- Eight physical jumps and eight landings; two loops; sixteen ordered checkpoints.
- Zero resets; maximum frame displacement 0.714346 m.
- One actual lasso catch; three avoided encounters; longest slowing period 0.65 s.
- Lasso clock and race time both 98.516667 s; speed factor restored to 1.0 at the finish.
- Both precision gaps landed in their marked target zone.

## Complete opponent field result

All 30 racers across six scenarios finished. They made 241 physical landings, with zero rescues, failed loops or stalled windows. The lasso system observed 120 real encounter crossings and 21 catches; the longest slowdown was 0.65 s. Maximum movement step was 1.171894 m.

| Difficulty | Clear shoulder | Stopped player on racing lane |
| --- | ---: | ---: |
| Entdecken | 126.066667 s | 127.100000 s |
| Abenteuer | 88.750000 s | 91.100000 s |
| Extrem | 77.250000 s | 79.466667 s |

These times are the last finisher in each two-lap field. The JSON evidence is stored in `evidence/combined-drive-20261112/`.

## Reproduction

Godot 4.6.3, Linux headless, isolated temporary `XDG_DATA_HOME` per fixture:

```sh
XDG_DATA_HOME=/tmp/lumo-combined-field-final godot --headless --audio-driver Dummy --path . --script res://scripts/tests/kart_full_field_regression.gd
XDG_DATA_HOME=/tmp/lumo-combined-player godot --headless --audio-driver Dummy --path . --script res://scripts/tests/kart_player_full_route_regression.gd -- --out=/tmp/lumo-combined-player-proof
```

The saved reports include actual movement, completion, flight and lasso measurements. They are physics acceptance evidence, not Android/Fold7 frame-rate or release-APK evidence. The full-field fixture retains an existing resource-at-exit warning after its assertions complete.
