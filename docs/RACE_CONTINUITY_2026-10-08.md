# Lumo race continuity — 8 October 2026

Baseline: `d2ebb85d0dcfeec690c18b7d35135a66f472b170` on `codex/lumo-reference-design-2026-10-08`.
Work branch: `codex/lumo-race-continuity-2026-10-08`.
Coordination: the package was claimed on Godot PR 27 and Flutter PR 214 before edits.

## Confirmed problems and correction

Changing quality in the pause menu rebuilt the real race world and cleared
`item_box_collected`. A previously consumed violet prism returned, allowing the
same lap to receive another item. Closing and reopening the saved race caused
the same problem because the consumed dictionary was absent from the ConfigFile.
The new code preserves that dictionary across rebuilds, writes it in the existing
atomic save and restores its visibility immediately, including while paused.
The next legitimate lap still makes the prism available normally.

Rival held items and stun, cooldown, boost, shield and pulse-warning durations were
also absent from the saved session. These now round-trip through the existing
ConfigFile and immediately restore the corresponding visible indicators. Only
known item IDs and finite durations within the existing gameplay bounds are
accepted. Missing/short arrays and invalid optional values become neutral states.
The saved remaining warning remains paused until the race resumes.

Manual Reset during an actual ramp flight left `airborne`, `vertical_speed` and
`air_time` active after moving the kart onto safe road. Reset now clears those
three values so this interruption cannot count as a successful landing or grant
its landing turbo. The existing safe road and checkpoint placement is retained.

This is an additive version-4 save change. Existing versions 1–4 remain readable.
Older files that never recorded these fields cannot reconstruct earlier pickup
consumption or rival effects; the absent information defaults to neutral.
No HostBridge JSON field, result identity, reward rule, vehicle art or track was
changed by this gameplay package.

## Runtime evidence

Engine used: Godot `4.6.3.stable.official.7d41c59c4`.
The new regression was run against an immutable baseline checkout first:

| Baseline probe | Observed failure |
| --- | --- |
| Real pause-menu quality callback | Consumed pickup identity disappeared |
| Native ConfigFile save | Consumed pickup key absent |
| Saved scene reopened as a new instance | Rival gameplay durations disappeared |
| Real ramp flight, then manual Reset | Kart remained logically airborne |

The corrected `kart_race_continuity_regression.gd` passes five scenario groups:
quality rebuild and next-lap release; native save/new-instance reopen; rival
effects and paused durations; version 1–4 compatibility and malformed optional
fields; and interrupted-flight reset without a landing turbo. It also checks
that quality changes and reopened races retain their result ID.

Unmodified existing regressions passed:

- `kart_physics_regression.gd`: rail contacts on both sides of all 12 tracks,
  drift tiers, reverse line and shortcut rejection, GAS/BREMSE, boost and raised route.
- `kart_jump_regression.gd`: genuine 0.60-second flight, 1.2-second landing turbo,
  crawl rescue, ordered checkpoints, authored rival arc and no jump elsewhere.
- `kart_race_bridge_regression.gd`: integer `solved` in native JSON, single award,
  failed ACK keeps the save, cup continuation and legacy learning-cup migration.
- `kart_regression.gd`: two laps using steering input, pause, save/reopen,
  finish coast and one award; 3017 physics steps, 51.4 seconds of simulated race time.

These are desktop engine checks. Physical Android/Fold testing, device GPU/CPU
timing, memory soak and 60 FPS are **NOT EXECUTED** by this package. The headless
timing probe does not establish Android input latency or device frame rate.

Reproduce the focused suite with isolated user data:

```sh
XDG_DATA_HOME=/tmp/lumo-continuity-qa \
  godot --headless --audio-driver Dummy \
  --script res://scripts/tests/kart_race_continuity_regression.gd
```

## Sources and boundaries

Used the existing project's world rebuild, native Variant save and ordered
checkpoint architecture. No third-party implementation or assets were copied.
Godot 4.6 official documentation was checked for
[ConfigFile](https://docs.godotengine.org/en/4.6/classes/class_configfile.html)
Variant storage, explicit defaults and disk-save semantics, and
[DirAccess](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html)
absolute `user://` paths. The current temporary-save/rename approach is preserved.

Remaining separate gameplay gaps include full ballistic rival jumps, interrupted
flight persistence on an offline restart, pause-aware cosmetic rival animations,
and camera/landing visibility validation on real Android displays. Loop layout
remains gated off in the current world build. This package makes no claim that
reference fidelity, complete device QA or overall visual quality is finished.

## Connected driver and complete reference race

The same packet corrects the existing procedural arm rig rather than replacing
Lumo. Both hands now follow real wheel grip points through steering and body lean;
the non-celebrating hand stays attached during victory and both return to their
rest grip afterwards. The malformed sleeve shell is curved from the existing
shoulder through an elbow to the glove. Its original navy cloth, cyan seam and
orange/white bands remain. The far LOD follows the same connected shape.

New contact tests check 11,700 hand poses (maximum wheel error 0.2777 mm against
a 0.5 mm limit) and 6,240 authored sleeve/glove cases. At least 9/20 near cuff
vertices and 3/8 far cuff vertices lie inside the actual ellipsoid palm. The
preserved base has no cuff contact in these poses, with its nearest cuff vertex
16.577 cm from the palm centre. Final Comet geometry has 137,768 vertices and
61 surfaces versus 136,508 vertices and 64 surfaces on the base. This correction
adds 1,260 near vertices (0.92%) without adding draw surfaces; it does not establish
physical-device performance.

`kart_complete_flow_regression.gd` starts the actual garage, selects its five
steps with ScreenTouch, accelerates and steers with ScreenTouch/ScreenDrag,
pauses mid-race, preserves a failed return ACK, destroys/reopens the race,
uses the actual saved-race action, drives all 16 ordered gates, finishes two
laps, returns the result and clears the save only after ACK. It checks one raw
host reward call, three stars and zero learning answers. No checkpoint, distance
or finish state is forced. The desktop run finished in 82.8 simulated race
seconds without a reset. Its physics is stepped at 1/60; this is behaviour evidence,
not measured wall-time frame rate or a touch-latency measurement.

Real rendered PNGs are produced by `kart_steering_grip_capture.gd` (rest, straight,
left, right, victory), `kart_reference_capture.gd` and the complete-flow test.
These are runtime captures, not generated concept art. Keep comparison captures
from the immutable base under the same camera and pose. Existing geometry,
material-colour, shadow, animation, far-LOD, vehicle-detail and nine-car fleet
regressions remain unchanged and passed after both arm corrections.

Official Godot 4.6 [Node3D](https://docs.godotengine.org/en/4.6/classes/class_node3d.html),
[Basis](https://docs.godotengine.org/en/4.6/classes/class_basis.html) and
[Quaternion](https://docs.godotengine.org/en/4.6/classes/class_quaternion.html)
documentation was used for the existing local transforms and contact correction.
No external rig, model, animation or source implementation was imported.

Overall result remains **VISUAL_GAP / NOT FINISHED**. This reversible packet
repairs demonstrated continuity/contact problems. It does not turn the procedural
character into the missing authored production asset or establish the user's
full video-reference fidelity. The added reference is
https://youtu.be/-euI313vamw?is=MxiKLskM3fw1W4VF; exact frame inspection and Android
round footage are separate evidence, never substitutes for one another.
