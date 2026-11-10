# Sonnenhafen: continuous player acceptance from the grid

Production baseline tested: `c27d621635c5fb990505eced4adfa3d74ed93014`.

The existing complete-flow test proves a normal two-lap race and saved
continuation, but its centre-line driver does not request the optional loop.
`kart_player_full_route_regression.gd` closes that specific acceptance gap.

The new driver starts the real race with the normal preview and countdown.
It holds the actual gas control, sends analogue screen-drag events to the
joystick and presses/releases the actual brake control. It lines up on the
loop lane before the panorama ramp, and uses the same published ballistic
prediction as the precision-jump hint to plan its braking. After the initial
race selection it never assigns position, heading, velocity, progress,
checkpoints, countdown, opponent state, flight state or loop state.

Input events are flushed before each fixed physics tick. Without that test
harness detail, infrequent software-rendered frames coalesce multiple seconds
of steering, which makes the automated driver oscillate between the rails.
No production game change was necessary.

## Results

Both the headless physics run and the real X11 / OpenGL Compatibility renderer
run passed on Godot 4.6.3. Both produced the same race telemetry:

| Acceptance | Observed |
| --- | --- |
| Complete race | Two laps, 16 sequential checkpoints |
| Simulated race time | 185.250 seconds |
| Actual loop traversals | Two, with 24 upside-down physics frames in total |
| Mandatory ramp take-offs / landings | Four / four |
| Precision jump outcomes | Two in the target zone |
| Rescues / resets | Zero |
| Largest consecutive position displacement | 0.398146 m at 60 Hz |

The test rejects any frame displacement above 1.5 m, any rescue, skipped
checkpoint, unfinished race, missed loop or missing mandatory ramp flight.
Five production opponents remain active throughout the run.

## Reproduce

Use isolated user data so existing profiles and race saves are untouched:

```sh
XDG_DATA_HOME=/tmp/lumo-player-proof \
  godot --headless --audio-driver Dummy --path . \
  --script scripts/tests/kart_player_full_route_regression.gd \
  -- --out=/tmp/lumo-player-proof/evidence
```

With a real display server, replace `--headless` with
`--rendering-method gl_compatibility` and add `--record` after `--`.
This records a grid image, real frames every ten simulated seconds, the
finish and a continuous 10-fps first-loop sequence. The full race always runs;
the video sequence is an excerpt from that uninterrupted race.

## Actual renderer evidence

Session artifacts are under `artifacts/kart-player/` in the shared workspace:

- `recorded.log`: complete renderer execution, no script/resource errors.
- `recorded/player-route.json`: per-second trace and all 28 transition events.
- `recorded/loop-00018.jpg`: the actual player upside down at the apex.
- `player-loop-from-full-race.mp4`: 47 successive renderer frames, 4.7 seconds.

SHA-256:

```text
video 83df1ea8fabe4344a68279911a27d824499cf472ddc218f7851a0de4866c6496
json  8807c72e6f60e87807525d00942923aa2a848130f6e92f9727c372116f91aedf
log   19cf99694eba91d225480f060040fc7bb2217504623fd3f97732dfeb3b52539f
```

This is real production gameplay with software desktop rendering. It does not
measure Android device frame rate, thermals, touch latency or audio quality,
and is not an Android emulator acceptance result.
