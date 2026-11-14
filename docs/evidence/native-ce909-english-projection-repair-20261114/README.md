# English: actual 640×360 projection correction proposal

This pack contains one proposed product file, based exactly on Native
`ce909c4d3bab3a5514b653bf945a0ef46adfa539`, tree
`e2a374b2154f7ecb080f693c4bc90def53a20a00`. It has not been imported, executed,
rendered or tested. No working checkout, Git index, ref, workflow, pin or asset
was modified. Root owns the subsequent source checkpoint and actual CI.

## Actual failure

Host run `43623178880`, attempt 1, English job `132533159373`, ran Host
`bca5333767918398ba2414cc6cf5cd23af079f90` with that Native source. The actual
probe rejected its 640×360 ruler case because a real object's projected height
was below the unchanged 48 dp minimum. The original observation establishes:

| Actual choice | Mesh-union width × height at density 1 | Actual pick rectangle |
| --- | --- | --- |
| pencil case | 51.4057007 × 45.6951904 px | 48 × 48 px |
| ruler | 51.4057007 × 45.5801849 px | 48 × 48 px |
| paper | 51.4057312 × 46.7344055 px | 48 × 48 px |

The first failure in probe iteration order is the pencil case; the diagnostic
case name refers to the requested word, ruler. All three projected heights
are too small. This is separate from the valid, larger collision hit regions.

The original world corners independently reproduce the recorded camera
projections to within 0.000041702 px. The actual available stage is
608×157 px; the orthographic size read from the original projection matrix is
approximately 14.5664733. These are original observations and arithmetic,
not a replacement renderer run.

The original archive has five earlier rendered images. It has no ruler
failure PNG, no ruler scene summary, and no final English report: the run
stopped at the error before completing those outputs. The retained ruler
layout JSON is an actual product observation written before that assertion.
No image has been generated or edited to fill this gap.

## One product change

Only `scripts/learning/learning_world.gd` changes. Its existing
`_layout_english` keeps the shared camera fit, resets each model's scale on
every layout, then invokes one new helper in landscape only. The helper:

- Reads the actual current projected mesh rectangles.
- Does nothing when every dimension already meets 48 dp.
- If necessary, calculates one common physical enlargement to a 52 dp
  minimum, including model meshes, numbers and collision bodies.
- Checks that the resulting row fits beside the actual original Lumo,
  completely within the existing unobscured stage.
- Positions the row using measured projections with 8 dp gaps, without
  changing the camera, HUD, original character, mesh resources or vocabulary.

The proposed factor for the original failing geometry is 1.1408466217; the
predicted three-object row with two gaps is 191.9381×53.3168 px. The failed
layout does not record Lumo's mesh corners, so its final row position cannot
be asserted from that JSON. The implementation measures those corners at
runtime. If a future viewport cannot contain the enlarged row, the original
layout remains and the unchanged size regression still fails. There is no
fallback that changes the acceptance threshold or hides an error.

The unit scale reset restores the original portrait geometry and prevents
cumulative growth during repeated hints, relayout or orientation changes.
All 66 other existing functions are byte-identical, including input,
speech/consent, ACK/return, lifecycle and observation logic. Existing Wisp
declarations and setup remain unchanged. The gallery and the full original
English regression are unchanged reference bytes.

## Required subsequent acceptance

The current actual Host-generated English fixture and the unchanged original
probe must run on the new checkpoint with a real renderer. All 14 profiles,
17 original captures, both orientations, hints, action/voice/return/lifecycle
checks and the actual ≥48 dp requirement remain mandatory. This source pack
claims no new renderer, Android, FPS or overall qualification success.

## Original retention and local preparation

The original ZIP and every extracted member remain unchanged in the sibling
`host-next-authorities-bca533-native-evidence-20261114` pack. This smaller
pack includes the exact failure observation, task fixture, native log,
runner log, before/after source, unchanged direct reference sources,
arithmetic derivation and source/function bindings. It references earlier
PNG originals without duplicating them.

The read-only local Git commands reported a missing old `/tmp` alternate
object directory after the environment recovery. All selected object reads
nevertheless returned exit 0, matched the published ce909 blob IDs and the
original CI inventories, and matched materialized source bytes. That warning
is preserved in `source-read-binding.json`. No Git configuration was changed.
