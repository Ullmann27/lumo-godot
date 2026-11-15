# Native learning layout correction — 2026-11-15

This evidence records the actual routed Next Generation learning scene after two observed overlap defects were corrected. It supplements the separate software performance and geometry evidence in `../runtime-fixes-02/`.

## Production change

Only `scripts/lumo_next/learning_world_next.gd` changes production behavior.

- Syllable sources and receiving pads move together to reserve a clear word row. The existing extruded word is placed above the actual receiving pads, below the full teacher and flower row. Banane's existing 3D object remains visible. Syllable identities, ordering, state, and audio segments are preserved.
- The existing task card and full teacher occupy separate horizontal spaces. Orthographic framing adjusts when needed. The card is vertically aligned clear of the foreground globe, and the full head, body, and paws remain visible.
- Gaze and pointing continue to use the actual registered target after placement. The regression measures the real wrist-to-hand bone ray against that target and checks common Stop.
- No model, rig, texture, global actor, Kart, or Jungle changes are included.

## Results

| Verification | Result |
| --- | --- |
| Exact same new route probe on prior production `0b93d806a47df4a0b4aca02461b7dcc5210ee4c8` | 1,774 checks, 12 failures: six word/teacher overlaps and six card/teacher overlaps |
| Exact same probe after correction, headless Godot | 1,774 checks, zero failures |
| Real X11 software-renderer capture of the corrected scene | 1,789 checks, zero failures, 15 saved PNGs |
| Canonical avatar / turn / target / interrupt contract | 300 checks, zero failures |
| Original Base/Fox audio regression | 69 checks, zero failures |
| Formatter and linter on both changed scripts | Pass |
| Project validator | 118 pass, zero warnings, zero failures |
| Five corresponding 8+5 screenshots versus prior evidence | Identical SHA-256 and pixels in all five |

The 15 additional software-render checks verify successful image capture. The layout matrix covers seven viewports and enlarged text; the focused pointing test additionally exercises 412×960 and 750×832 with actual actor motion. The test validates geometric separation, visible content bounds, 48dp action targets, correct task state, and the existing segmented audio path. It does not infer visual quality from bounds alone: the final screenshots were also inspected.

## Review images

- `screenshots/syllables_412x960.png` and `screenshots/syllables_750x832.png`: word, banana, receiving pads, and full teacher visibly separated.
- `screenshots/task_card_412x960.png` and `screenshots/task_card_750x832.png`: full teacher beside the card; the foreground globe does not cover card text or choices.
- `screenshots/task_card_point_412x960.png` and `screenshots/task_card_point_750x832.png`: actual pointing at the repositioned card.
- `screenshots/bridge_ten_412x960.png`, `screenshots/bridge_ten_750x832.png`, and `screenshots/bridge_ten_after_two.png`: unchanged 8+5 scene and state after two real token moves.

## Provenance and limits

`red-green-source.json` fixes the baseline, presenter hashes, and identical test hash. `manifest.json` contains source and evidence hashes. Raw before/after, actor, Base/Fox, and software-render logs are included; `bridge-ten-image-comparison.json` records actual pixel and byte comparisons.

The capture ran Godot 4.6.3 using X11, OpenGL Compatibility, and Mesa llvmpipe (LLVM 19.1.7, 256 bits). These are indirect viewport checks, including 412×960 and 750×832, not physical foldable-device captures. No physical Android audio, full Flutter-task coverage, or 60-FPS result is asserted here. The software driver logged the expected unsupported VSync, screen-space AA, and volumetric-fog warnings; the final render completed with exit code 0 and no script errors. The final verbose actor run is clean. A preceding nonverbose actor run had passed all 300 checks with an intermittent ObjectDB-exit warning, which did not recur in the recorded final verbose run.

The software renderer's incidental frame window during screenshot setup is not a benchmark. The separate `runtime-fixes-02` evidence contains the bounded performance observations and their limitations.
