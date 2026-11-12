# Complete native-tab race, save/resume and host acknowledgement

Base: `a80457de51e07470f691eec182aa32188f47da7d`. Date: 2026-11-12.

## Corrected test behavior

`kart_complete_flow_regression.gd` still expected five successive NEXT actions. The spatial menu's START now launches immediately and frees the menu, so the second old wizard iteration accessed a freed `garage` object.

The end-to-end test now uses actual visible native controls in a direct, nonsequential order:

1. Strecken tab, Sonnenhafen card.
2. Tempo tab, Abenteuer card, selecting the doubled 41 m/s baseline through the UI.
3. Rennen tab, Einzelrennen card.
4. One START action.

Touch coordinates are cached before a control can trigger a transition and free itself. Touch/drag events are flushed before the next fixed physics step, as in the independently verified full-route test.

The race controller fixture steers through the real joystick and holds the real gas pedal. It uses the real brake pedal before ramps according to the published ramp plan. It never assigns a running kart's position, speed, progress, checkpoint, flight, loop or result state. Both saved-race reopens release every held finger, then acquire fresh joystick/gas inputs. No production code was changed.

## Full local result

Godot 4.6.3, headless, isolated XDG directories, executed through `tools/run_godot_probe.py` with its assertion/error watchdog and required completion marker:

- **Exit 0, PASS.** All sixteen gates were physically crossed in order.
- First save/reopen after gate four; second save/reopen after gate twelve.
- Two independently measured laps: **49.600 s** and **48.833333 s**, total **98.433333 s**.
- Zero rescue resets, as required by the unchanged final assertion.
- Result identity, paused progress and lap timing survived both reopens at the original strict tolerances.
- The completed result was reopened again; its payload, displayed lap lines and stopped/disabled controls remained consistent.
- Exactly **one** host reward call. Reopening did not add a second local or host reward.
- The real result modal's return action received a durable ACK, removed the completed save, and a subsequent fresh instance had no saved race.
- All nine existing structured continuity/result checks passed; the original additional assertions remain active.

The final log and complete JSON report are in `docs/evidence/kart-native-complete-flow-20261112/`. The report records all seven menu touch actions and all sixteen actual gate distances/times.

## Renderer boundary

The same test now runs its complete logic in headless mode without waiting for an unavailable rendered frame. Headless output explicitly records `visual_capture_status: NOT_EXECUTED_HEADLESS`, an empty screenshot hash map and no claimed PNG.

On a real display, the test retains all six actual PNG captures. The native CI job now explicitly requires `visual_capture_status == RENDERED` and exactly six screenshot hashes before accepting its evidence; a headless result cannot satisfy that gate.

Requesting `--capture` with `--headless` was separately tested and correctly exits **1**. That expected negative-control log is stored separately. The native renderer result and Android-device performance remain unclaimed by this local run.
