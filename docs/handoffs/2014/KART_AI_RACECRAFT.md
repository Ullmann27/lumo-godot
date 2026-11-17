# LUMO 2014: rival racecraft and earned items

Baseline: Godot `47bef06db45d61d50ecd06d0b0cd0a69b9a25917`.

## Implemented

- Five deterministic driving styles with distinct clearance, apex preference and corner risk.
- Upcoming horizontal road curvature limits speed using a lateral acceleration budget. Speed comes from each displayed kart's existing fleet statistics and difficulty, without a catch-up or race-position multiplier.
- All nearby racers and actual course cones enter the same traffic model. Lane selection evaluates the lane-change path; a blocked car brakes while it seeks a pass. Different road decks are excluded by normal-axis separation.
- Medium/pro drivers aim for real resonance rings when safe. Pickup uses the same 2.65m proximity and minimum speed gates as the player.
- An earned boost is usable while leading, but is saved for a clear, aligned straight and held before precision ramps.
- Medium/pro rivals earn drift charge from sustained controlled road turns. Visual drift state is active; controlled corner exit grants the existing 0.8/1.8 charge mini-turbo tiers. Hits and loss of control cancel charge.
- Resonance reads actual earned drift charge and the kart's own reference pace. Previously hardcoded zero drift made the 0.90 gold threshold unreachable (maximum 0.85).
- Rival pulses now select nearby rivals as well as the player and resolve after the existing visible warning. Shields block the effect for both human and AI racers. No hidden instantaneous hit.

## Automated evidence

Godot 4.6.3.stable.official.7d41c59c4, Linux headless production scene.

- `kart_ai_behavior_regression.gd`: no teleport, no rubber-band and ordered easy/medium/pro progress. Snapshot now includes actual motion speeds and earned drift charge so repeated simulations restore the same state.
- `kart_racecraft_regression.gd`: distinct styles, free/blocked lane decisions, curve braking, safe leader boost, and actual production cone avoidance (minimum measured clearance 1.748m over 51.68m travel).
- `kart_rival_drift_items_regression.gd`: actual driving earns charge; a gate placed on that observed line yields gold; the earned pulse hits an unshielded AI after warning, a shielded AI remains unharmed, and real drift exit yields a mini-turbo. No charge or pulse is injected.
- Existing `kart_rival_item_feedback_regression.gd`: warning, dodge, shield and bounded boost remain green.
- New helper and tests: gdformat/gdlint pass. `git diff --check` passes.

The known Godot teardown-only `resources still in use at exit` message can occur after PASS, as already handled by the repository's validator; no script, parse or assertion failures are accepted.

## Integration ownership and remaining evidence

`kart_island.gd` planning/item sections belong to this stream. Geometry owns loop/ramp movement helpers; cancel `racecraft_drift_charge` when entering an actual loop or flight. Root integrates these non-overlapping sections and runs combined gates. Add both new tests to the root validation runner.

The eight-second pace test is not a full-lap measurement. Complete combined two-lap challenge, actual Android/phone/Fold hardware and frame/thermal measurements remain required. This stream does not claim AAA completion, a new APK, or hardware acceptance. Existing save version and child profiles are unchanged.
