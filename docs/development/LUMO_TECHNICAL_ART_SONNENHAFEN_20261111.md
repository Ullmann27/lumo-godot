# Sonnenhafen: original street architecture and calm welcome animation

Baseline: Godot `207bfbc5377c0f3e8be800854c83ddf2110ac3f6` from the verified
2014 integration. Runtime source checkpoint:
`977f120bf586db96250b3f3eb5f2503d2994a8d4`, tree
`5ed9fa4c582f089a1652287436550290a2ce46d3`.

The original `Lumo_Referenzmappe_2026-11-03.pdf` was available and its actual
pages 16–17 were visually inspected. They are design references, not implemented
game images. The change uses original authored procedural geometry; no provider,
external model, paid service, texture download or engine migration was used.

## Comparison and implementation

| Area | Verified 2014 state | Original reference | Implemented change | Evidence |
| --- | --- | --- | --- | --- |
| Opening street | Flat rectangular windows; side walls mostly blank | Cream arched surrounds, blue joinery, terracotta town | Recessed arch shapes, stone courses, shutters and sills on approach and inward road faces | Matched real race-view and shopfront renders |
| Balconies | Slab, separate vertical bars and exposed flower shapes | Complete dark railings and planted boxes | Continuous handrails, side returns, planted terracotta troughs | Matched close renderer view |
| Ground floor | Existing blue/cream canopy, simple door | Shaded shopfronts and warm lamps | Arched door/glazing, opaque warm lamp panes, canopy braces and foundation terraces | Actual meshes and same-camera render |
| Lumo identity | Existing palette, house masses, roof forms and towers | Warm harbor architecture and blue/gold L detail | Original masses, roof and tower placements retained; subtle L pennants | No original character, vehicle or brand replacement |
| Motion | Existing reacting harbor wheel | Calm welcoming street life | One bounded fabric batch; gentle sway and one short welcome after proximity entry | Real-GL transform/lifecycle test and deterministic renderer clip |

The actual source change is confined to `kart_sonnenhafen_generation.gd` and
the new `visual/kart_sonnenhafen_streetfronts.gd`. Road shape, collision,
checkpoints, ramp/loop geometry, camera transitions, vehicle data and AI approach
code are not modified. Full race acceptance remains an integration gate.

## Material, geometry and placement bounds

Four shared opaque materials distinguish rough masonry, painted joinery,
glazing and matte fabric. There are no screen/depth texture reads, transparent
window layers, new texture residency, additional lights or collision objects.
Geometry is combined by material in 48 m spatial cells with distance visibility.
The real authored geometry is measured separately from the existing world
instance count; merged geometry is not presented as reduced total rendering work.

| Installed street kit | LOW | HIGH |
| --- | ---: | ---: |
| Houses | 9 | 15 |
| Arch windows/doors | 120 | 210 |
| Combined architecture triangles | 35,676 | 95,196 |
| Material surfaces | 20 | 24 |
| Shared material resources | 4 | 4 |
| Animated pennant instances / batch | 9 / 1 | 15 / 1 |
| Smallest checked distance from road center | 12.3149 m | 12.3151 m |

The world test checks every distinct projected architecture vertex, not just
house centers. Required road clearance stays at least 7 m. The new hard limits
are 100,000 architecture triangles and 32 material surfaces. The original
generation test and its 1,400-instance cap are unchanged and pass.

## Actual renderer measurements

Same source fixture, camera matrices, FOV, HIGH quality and 1280 × 720 size.
Environment: Godot 4.6.3, GL Compatibility, Linux Mesa llvmpipe.

| Fixed view | Baseline draw calls | Street kit draw calls | Baseline primitives | Street kit primitives |
| --- | ---: | ---: | ---: | ---: |
| Existing race camera | 220 | 260 | 1,241,599 | 1,327,353 |
| Existing shopfront camera | 194 | 227 | 972,898 | 1,089,776 |
| Harbor wheel context | 230 | 269 | 1,032,286 | 1,154,332 |

These are actual renderer counters, including the rest of the visible world.
They show the cost of the added detail. They are not physical Android FPS,
temperature, power or RAM measurements. No such device result is claimed.

The additional production race-scene captures retain Lumo, the kart, the real
HUD and the production chase-camera method. The capture-script SHA-256,
resolution, quality, camera transform/FOV and player transform match the
baseline exactly at all four staged positions:

| Production race camera | Baseline draw calls | Street kit draw calls | Baseline primitives | Street kit primitives |
| --- | ---: | ---: | ---: | ---: |
| 18 m | 350 | 391 | 1,411,713 | 1,535,963 |
| 60 m | 278 | 313 | 914,960 | 1,038,810 |
| 110 m | 269 | 287 | 821,804 | 900,586 |
| 160 m | 250 | 250 | 791,680 | 790,576 |

The 60 m view was inspected before and after: newly detailed street-facing
walls are visible on both sides during the ordinary race-camera framing.
These deterministic posed views do not replace driven-loop acceptance.

## Animation ownership and controller connection

The kit has no independent Tween or shader TIME animation. The race controller
owns time and calls the same explicit interface used by the existing attraction:

```gdscript
var streetfronts = world.get_node_or_null("SonnenhafenStreetfronts")
if streetfronts != null:
    streetfronts.advance(delta, player.position, racing and not paused and not finished, reduced_motion)
```

The integration owner installs this hook in the existing `kart_island.gd`
physics loop. Geometry-only capture scripts call the same method explicitly.
Their staged position stimulus is documented and is not claimed as driven input.

Pennants update at no more than 20 Hz on LOW and 30 Hz on HIGH. Their proximity
reaction uses 30 m entry and 43 m exit hysteresis, lasts 1.8 seconds, and returns
to ordinary gentle sway. Beyond 170 m no instance transforms are updated.
Inactive racing, pause, finish and reduced-motion input freeze animation state.
Nonfinite positions/delta and nonpositive delta are rejected.

## Reproducible acceptance

Use the project's existing Godot 4.6.3 runtime/imported assets. No test assertion
was removed or relaxed.

```bash
godot --headless --path . --script res://scripts/tests/kart_sonnenhafen_generation_regression.gd
godot --headless --path . --script res://scripts/tests/kart_sonnenhafen_streetfronts_regression.gd
godot --headless --path . --script res://scripts/tests/kart_sonnenhafen_streetfronts_world_regression.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://scripts/tests/kart_sonnenhafen_streetfronts_regression.gd
```

All four passed on the runtime checkpoint. The GL run verifies real MultiMesh
transforms, movement, one trigger per approach, exact pause/reduced-motion
freezing, invalid-input rejection, exit/reentry hysteresis and return to idle.
The headless run does not stand in for that GL evidence.

Capture commands:

```bash
LUMO_CAPTURE_DIR=/absolute/output/harbor godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://scripts/tests/kart_harbor_living_capture.gd
LUMO_CAPTURE_DIR=/absolute/output/pennants LUMO_SOURCE_SHA=977f120bf586db96250b3f3eb5f2503d2994a8d4 godot --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 12 --script res://scripts/tests/kart_sonnenhafen_streetfronts_capture.gd
ffmpeg -framerate 12 -i /absolute/output/pennants/frames/%03d.png -c:v libx264 -pix_fmt yuv420p -movflags +faststart /absolute/output/pennants.mp4
```

The existing harbor script produces before/after images and renderer counters.
The pennant script produces 72 actual 960 × 540 renderer frames and a metadata
file. Its six-second timeline is deterministic animation evidence, not measured
real-time game performance. The root integrator additionally captures the actual
production race scene and chase camera at 18/60/110/160 m and runs complete
player/rival loop and ramp acceptance on the combined source.

Physical Android/Fold7 performance, final APK integration and device acceptance
are outside the standalone art-branch evidence. No APK or release is produced
by this branch.
