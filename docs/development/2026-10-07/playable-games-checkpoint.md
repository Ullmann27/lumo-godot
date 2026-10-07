# Lumo: playable games and track expansion — 7 October 2026

Runtime source: `9136662953a42cd60cfe3cdf05fbd6497b13bfb1`.
Successful real-render workflow: https://github.com/Ullmann27/lumo-godot/actions/runs/37614750293
Artifact: `lumo-creative-runtime-37614750293` (artifact ID `11479533267`; exact name can be checked in that run).

## Resulting playable behavior

The Flutter creative shelf can enter four native scenes using the existing
private Android game process and durable HostBridge. SceneRouter and AppBoot
accept puzzle/build/rhythm/treasure alongside the established kart and jump.
All four creative scenes apply native safe insets, use landscape, pause on
Android Back/background, and return through the existing host bridge.

- **Bauwelt:** 28 building parts; 33×33 area, height 20, at most 768 parts;
  quarter-turn placement; occupied-volume and support validation; meaningful
  house, connected bridge, tower, garden, castle and village goals; 64 undo/redo
  steps; six independent worlds per child; atomic JSON saves, camera recovery,
  templates and real collision meshes. The initial castle contains 161 parts.
  A successful goal gives 3 stars / 24 XP exactly once per child and goal.
- **Puzzle:** original matching interlocking 3D meshes, 12/24/48/96 parts,
  three existing/original motifs, tray paging, edge filter, image preview,
  hint marker, actual ray-pick/lift/drag and correct-slot snap. Square and wide
  artwork retains its proportions. Atomic saves retain free and placed pieces,
  moves, hints, elapsed time and result identity. No reward before completion.
- **Rhythm:** three original synthesized songs (96/108/120 BPM), four lanes,
  tap/hold/slide/star notes, touch or D/F/G/H, three timing difficulties,
  accuracy/combo/results, audio/time pause and saved best results. Zero-input
  rounds cannot earn stars. Unfinished songs restart rather than resume after
  process death; this is distinct from the saved best results.
- **Treasure:** original island, castle, garden and river route; seven clues
  gated by actual distance, correct answers and inventory; a locked bridge
  that cannot be jumped past; physical walking/jumping; inventory view; atomic
  per-child chapter/position/result saves. Completion gives 3 stars / 40 XP.

Learning remains in Flutter. Kart races do not ask learning questions.

## Kart expansion

The four established worlds remain. Eight separate circuits bring the menu and
cup to twelve worlds. Their measured new lengths are 691–803 m: Crystal Canyon,
Jungle Temple, Candy Cloud, Volcano Night, Winter Sprint, Galaxy Ringway,
Desert Drift and Learning Lab. Landmarks, road/sky materials and track geometry
differ; the expansion is not twelve copies with renamed labels.

Five circuits have physical ramp launches and landing recovery. Candy,
Volcano and Galaxy have optional momentum-dependent right-lane loops with
actual inversion, upright camera, insufficient-speed exit and safe recovery.
Rivals retain the main racing lane. Existing shield/impulse warnings and
fairness feedback from PR21 remain.

Reference direction is grounded in Heinz's two 10-second Candy/Volcano videos,
the supplied 2026-10-05 track boards and existing Opus fox/kart design. Original
sandstone imagery is identified as generated art; runtime captures come from
Godot, not image generation. Existing design-target assets remain intact.

## Meaningful verification

Godot 4.6.3 ran the actual scenes on Ubuntu/Mesa llvmpipe. The workflow produced
21 gameplay/menu PNGs from the tested source. Tests cover real scene startup;
supported/unsupported building, overlap, removal safety, connected bridge,
house/castle/village goals, undo/redo and rejected corrupt saves; rhythm
timing/early release/slide/pause; clue proximity and inventory gates; puzzle
matching edges, wrong-slot rejection, real input picking/drag/snap and JSON
resume; eight distinct driving worlds, ramp flight/landing and three complete
loop inversion/recovery paths. All passed.

## Limits and next evidence

These are playable development scenes, not a completed visual approval against
the videos. Candy/Volcano still have a **VISUAL_GAP** in model detail, environment
density, lighting and animation. The preserved Lumo character is a procedural
animated model, not a verified production skinned GLB. A physical Samsung/Fold
frame-rate, thermal, touch/hinge or 60-FPS acceptance has not been performed.
The APK runtime probe separately reports installation, profile, save, pause,
reward and actual native scene behavior; it does not imply full song/puzzle/
treasure completion or all twelve complete races on Android.

The branch stays isolated. No main merge, release publication or physical-device
approval is implied by this checkpoint.
