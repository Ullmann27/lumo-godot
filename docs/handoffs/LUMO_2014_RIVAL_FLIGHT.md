# LUMO 2014 - physical rival ramp flight

The controller no longer assigns an airborne height from `world.rival_arc(distance)`. A real crossing of a ramp lip starts a transient ballistic state from that rival's actual speed. The shared precision-jump launch function supplies lift, the ramp supplies gravity, and the kart integrates horizontal velocity and vertical gravity each tick. Road ramp pitch is applied before take-off.

Covered routes are the action-course kickers (including both Sonnenhafen ramps) and the main Himmelsinseln jump. During flight, steering is limited and the precision lane envelope clips velocity instead of teleporting a kart. In-air boost and drift cannot change the stored launch speed. The partial road drift charge is cancelled on take-off.

Short precision jumps really descend into the gap and use the same cloud recovery location and 8 m/s initial recovery speed as the player. A recovery incurs one second of rival slowdown. Long landings lose 40% of speed and have a brief slowdown. Correct zone landings earn a 1.2 s boost. Rescue and landing counters are separate, so race acceptance can distinguish legitimate gap recovery from an unexplained position jump.

Active-flight snapshots put the saved rival at the ramp entrance, preserving the cumulative lap, without moving the live kart. Session restoration clears transient flight/loop state before applying the snapshot. The existing session version and profile format are unchanged.

## Godot 4.6.3 actual-renderer regression

`scripts/tests/kart_rival_flight_regression.gd` verifies:

- At 12 m/s, an actual short jump and gap rescue.
- At the shared model's reference speed, a correct zone landing at 22.74 m.
- At 30 m/s, a long landing at 37.62 m and speed penalty.
- Distinct measured apex heights: 3.31 / 3.97 / 4.87 m.
- Constant launch speed during flight, bounded per-frame movement and monotonic lap progress.
- A real saved snapshot during flight, preserving the second lap without a shortcut.
- A rescued kart stays on the road instead of being lifted by the old canned arc.
- Automatic AI approach, take-off and landing at Sonnenhafen's panorama ramp and the Himmelsinseln jump.

The fixed-speed fixtures initialize a real kart at the lip once; every subsequent update calls the actual rival controller. Separate automatic-approach checks begin eight metres before the ramp. This does not claim a complete race, Android test or hardware FPS result.

The independent racecraft integration must plan safe approach speed on each difficulty and rerun full two-lap field acceptance. Its target must stay within genuine vehicle top speed and the physically computed landing envelope; no artificial in-air speed correction is allowed.
