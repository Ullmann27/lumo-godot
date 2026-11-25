# LUMO 2082: original card and chess motion evidence

The final rendered acceptance run **45569486039 passed 148 checks with zero failures and 14 original viewport captures**, using source commit `62108c0355f860ab9a0a020ecb5f3f941f1032e9`.

This directory is an evidence-only addition on the QA branch. It does not change a product pin, product file, feature/integration branch, or workflow. The separate QA workflow triggers only when its own YAML changes; the evidence commit also carries `[skip ci]`.

## Immutable source and execution

- [Exact scene/probe source](https://github.com/Ullmann27/lumo-godot/tree/62108c0355f860ab9a0a020ecb5f3f941f1032e9)
- [Exact capture workflow](https://github.com/Ullmann27/lumo-godot/blob/c5acad4eee639d39b329e474a32c2028c1696e3b/.github/workflows/lumo-2082-table-motion-capture.yml)
- [Final renderer job](https://github.com/Ullmann27/lumo-godot/actions/runs/45569486039/job/139052318890)
- [Final original artifact](https://github.com/Ullmann27/lumo-godot/actions/runs/45569486039/artifacts/15001058610)
- [Final result and source-blob metadata](final-45569486039/RESULT.json)
- [Original renderer output](final-45569486039/TABLE-MOTION.txt)
- [Original 14-image manifest](final-45569486039/CAPTURES.json)
- [SHA256 values for every extracted original artifact file](final-45569486039/ARTIFACT-SHA256SUMS.txt)
- [Headless verification of the same source](https://github.com/Ullmann27/lumo-godot/actions/runs/45568517233)

The real Godot 4.6.3 scenes and original assets were rendered using GL Compatibility, Mesa llvmpipe and Xvfb at 1440 × 900 and normal `time_scale = 1.0`. The setup uses deterministic legal positions and calls production move/animation methods. The full asset import, runtime error gate, image inventory, and job all passed. The original log records 148/0/14, an actual cancelled AI search at two frames/768 nodes, and final card input release with zero distance from its final slot.

The quartet sequence completed in **7.591 engine seconds / 20.134 wall seconds**, within **12 engine seconds** and an independent **60 wall-second watchdog**. Headless it completed in 6.050/6.050 seconds. All five product files are unchanged from `bfc1eda07e65af57b33a6c0f2db3641aab3bf9bd`; the final follow-up changed only the temporal probe's clock definition and elapsed-time logging.

## Visual observations

All 14 original images were viewed individually. The coordinator independently reviewed five key images and the original job log. No critical visual issue was found.

| Evidence in the artifact | What is actually visible |
| --- | --- |
| `frames/cards_00_before.png`, `cards_01b_lumo_card_midflight.png`, `cards_02_settled.png` | The card travels from the opponent hand to the table; the middle frame shows its tilted intermediate position. The opponent remains highlighted during travel; the child's hand and label highlight after landing. |
| `frames/chess_top_00_before.png`, `chess_top_01_child_in_flight.png`, `chess_top_02_lumo_in_flight.png`, `chess_top_03_settled.png` | Both pawn moves have intermediate positions. The final board has the white pawn on e4 and Lumo's black pawn on d5. |
| `frames/chess_3d_00_castling_before.png`, `chess_3d_01_castling_king_in_flight.png`, `chess_3d_02_castling_rook_in_flight.png`, `chess_3d_03_castling_settled.png` | The king travels first and the rook follows. The final king g1 and rook f1 are settled. The rook's middle frame is partly occluded by the king from this camera; the king frame is clearer. |
| `frames/cards_quartet_sequential_transfer.png` | Transfer status; the complete sequencing is supported by temporal assertions and the log, not this still alone. |

These are desktop software-renderer observations, not Android/Fold7 measurements or an FPS claim. The PNG bytes remain in the linked original Actions artifact with retention through **2026-12-25T07:42:34Z**. The text, source identities, image metadata and hashes in this Git commit remain independently inspectable after that artifact expires. No image is recreated or edited in this evidence commit.

## Failed runs retained without rewriting

1. [Run 45564185742](https://github.com/Ullmann27/lumo-godot/actions/runs/45564185742): 143 checks, two failed checks, 13 captures, and stale deferred-scroll runtime errors. Its existing [result](failed-45564185742/RESULT.json) and [raw output](failed-45564185742/TABLE-MOTION.txt) are preserved byte-for-byte. The scroll error was fixed with generation, weak-reference and ancestry guards. The card landing check used an obsolete expected slot 0.005 metres above the final assigned slot; the follow-up separates input release and final-position assertions.
2. [Run 45567127413](https://github.com/Ullmann27/lumo-godot/actions/runs/45567127413): 150 checks, one failed check, 16 captures. The original [diagnostic log](diagnostic-45567127413/TABLE-MOTION.txt) records 12.161 wall seconds but only 4.658 engine seconds. A valid, unsuspended set-card tween progressed from 0.0 to 0.390909 seconds and changed position. The [result metadata](diagnostic-45567127413/RESULT.json) and [all-file hashes](diagnostic-45567127413/ARTIFACT-SHA256SUMS.txt) preserve that actual failure. The final fix measures the unchanged 12-second animation budget in engine time while retaining a finite, independent wall watchdog. It does not speed up the game, remove an assertion, or classify the failed run as a pass.

The two diagnostic folders are historical evidence. Only `final-45569486039` is the final rendered acceptance result.
