# Studio Native integration review — 2026-11-13

## Exact reviewed source and scope

Published Native source: `cfa9f6657a2fda218f8752dbd21e4cfb49045a70`,
`Ullmann27/lumo-godot`, `chatgpt/lumo-studio-20261113`.
Its code parent is `c7b18d740dbac5be2d638a15d50e3fda7b218a0c`; the pair
adds 20 paths to the existing `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`
Nextgen source. The source was fetched by immutable SHA into a separate
detached review clone. No dirty developer work was copied.

Paired published Host source: `a8e09123805b2bf30706c8dd1914b928ae6b24ca`,
`Ullmann27/lumo-lernen`, `chatgpt/lumo-studio-20261113`.
The new Host `equal_sharing` launch requires this Native implementation.
The existing `ada5ed81` Native pin cannot accept that new activity.

The review covers importability, the published sharing and puzzle changes,
their existing regression probes, affected character regression gates, and
the connection into the existing acceptance runner. It is not a full Native
acceptance run, Android APK test, or visual approval.

## Integration repairs

### Authoring source import

`scripts/learning/learning_atelier.gd` loads the exported PackedScene at
`res://assets/learning/studio/learning_studio.glb`. The runtime scripts,
scenes, assets, project settings and export settings contain no loading
reference to the new `docs/design/studio-20261113` authoring directory.
Its `.blend` and preview are retained source/documentation files.

A fresh import of unmodified `cfa9f665` returned exit code 0 but contained
`ERROR: Blender path is invalid or not set`. It subsequently lacked imported
resources. Exit code 0 alone therefore did not establish a successful import.

Added `docs/design/studio-20261113/.gdignore`. After deleting only the generated
`.godot` cache in the owned review clone, a new Godot 4.6.3 import completed
with exit code 0 and zero `ERROR`, `SCRIPT ERROR`, `Parse Error` or resource
loading error lines. The import log contains `learning_studio.glb` and does
not contain `Learning-Studio.blend`.

### Existing acceptance runner

`tools/validate_nextgen.sh` retains all 25 earlier gates and adds:

| Existing published probe | Mode | Required marker | Timeout |
| --- | --- | --- | --- |
| `learning_sharing_regression.gd` | headless | `[LearningSharing] PASS` | 420 s |
| `learning_host_payload_regression.gd` (integration contract) | headless | `[LearningHostPayload] PASS` | 420 s |
| `puzzle_rotation_regression.gd` | headless | `[PuzzleRotation] PASS` | 420 s |
| `learning_sharing_capture.gd` | rendered | `[LearningSharingCapture] PASS` | 420 s |
| `puzzle_rotation_regression.gd` | rendered | `[PuzzleRotation] PASS` | 420 s |

The sharing capture receives its explicit output directory. The puzzle
capture receives its existing `PUZZLE_ROTATION_CAPTURE_DIR` environment
variable, placing original captures inside the same evidence tree as the
other modules. Independent failure collection and the overall failure exit
are retained. The older learning capture keeps its existing 900 s budget.
There are now 30 gates: 19 headless and 11 rendered. The three-file repair
patch below adds the first four gates; the separate Host contract delta adds
the fifth gate and its exact exported fixture.

`cfa9f665` does not publish a `lumo_studio_motion_regression.gd` or a
`learning_studio_regression.gd`. No test from an active dirty developer tree
was substituted. Existing teacher, gait and original-Jump character gates
were exercised instead; this does not imply complete Studio-motion coverage.

### Gait measurement correction

The existing gait test failed at its old local `Foot.L` Y-position assertion.
The published body-space adapter converts character-up offsets through the
imported parent bone frame. That preserves the intended vertical movement
while local Y can remain unchanged.

Before changing the test, a separate diagnostic sampled 120 original-actor
ticks at 1/60 s and requested speed 1.5 m/s:

| Observed quantity | Left foot | Right foot |
| --- | ---: | ---: |
| Maximum local-Y offset | 0 | 0 |
| Maximum offset transformed back into character space | 0.03968751 m | 0.03968751 m |
| Maximum actual skeleton-space rise above initial pose | 0.10383922 m | 0.10383928 m |
| Minimum actual skeleton-space rise above initial pose | 0.00513673 m | 0.00513685 m |

The actor root did not move. The existing test now samples actual skeletal
foot positions, keeps the original `> 0.022 m` clearance requirement, and
checks both feet. The existing thigh movement, unchanged root, suspension,
reduced-motion, neutral reset and original Kart animation checks remain.
No animation/product source was changed by this repair.

## Observed focused results

| Check | Result |
| --- | --- |
| Fresh import after authoring-source ignore | PASS; exit 0 and zero error lines |
| `learning_sharing_regression` | PASS, 1811 checks |
| `puzzle_rotation_regression` | PASS, 4037 checks |
| Existing `learning_world_regression` | PASS, 5328 checks |
| Existing `lumo_teacher_pose_regression` | PASS, 34 checks |
| Existing `lumo_original_jump_visual_regression` | PASS |
| Repaired `lumo_65bone_walk_gait_regression` | PASS |
| Serialized Host payload to Native model | PASS, 5 actual Host-export cases / 135 checks |
| Acceptance runner orchestration tests | PASS, 3 tests |
| Project structure validation | 117 PASS, 7 WARN, 0 FAIL |
| Shell syntax and patch whitespace | PASS |
| New rendered sharing and puzzle probes | Not executed locally: no DISPLAY or Xvfb available |

The headless sharing probe exercises actual `InputEventScreenTouch` routing
and scene state. The puzzle probe exercises the real scene/picking and emits
the rotation button signal; that is not an Android touch observation. The
renderer probes require the existing CI Xvfb environment. No original
renderer PNGs, Android performance or device claims are issued by this review.

Local review logs are in
`/workspace/scratch/b3485b7bb989/godot-studio-review-evidence/`.
`native-integration-repairs.patch` contains only the ignore file, runner
connection, and gait-test correction. Its SHA-256 is
`6783f58dca6bfd3152c1519d599c5b0b31b3a8ddb3b404560e0d2b4a3937a5d5`.
These are local results on the published source plus the documented delta,
not a clean new commit's final acceptance artifact.

## Host and Native contracts

The Native parser accepts integer-valued finite JSON numbers, not numeric
strings or fractional values. `equal_sharing` requires divisor `b` from 2
through 6, dividend `a >= b`, `a <= 36`, `a % b == 0`, and `a / b <= 6`.
It represents `a` original objects in `b` groups of `a / b` objects. The
12:3 destination sequence is `[0,4,8,1,5,9,2,6,10,3,7,11]`, so each group
receives one object before the next distribution round begins.

The joint Host/Native regression consumes actual serialized Host launch
payloads from the real Dart launch path after a StandardMethodCodec roundtrip.
The Host test serializes the inner learning map using `jsonEncode`, modeling
the existing Kotlin `JSONObject(learning)` conversion. Kotlin/Android IPC
itself was not executed by this test.

`scripts/tests/fixtures/learning_host_payloads.json` contains the exact
4951-byte successful Host export, SHA-256
`df186ff311e5775342793cbfd41911d9d4b5ca25a7b7083c19b8040448788264`.
The Host repository freezes the same bytes and compares fresh launches,
original task identity and real mission persistence against that fixture.
The fixture includes the four exact source-blob IDs checked during export.

`learning_host_payload_regression.gd` parses those serialized payload strings
with Godot `JSON.parse_string` and passes them into the actual production
`LearningActivity.configure`. It checks exact float-decoded integer values,
validated integer model state, unchanged input, completion and restart.

| Host task | Native state retained |
| --- | --- |
| `12 : 3` | `equal_sharing`, 12 objects, 3 groups, 4 per group |
| `3 × 4` | `equal_groups`, 3 groups of 4 |
| `4 × 3` | `equal_groups`, 4 groups of 3 |
| `1/4 + 2/4` | `fraction_parts`, `a=1`, `b=4`, `extra=2` |
| `1/4 + 1/4`, Host answer `1/2` | Original quarter operands retained: `a=1`, `b=4`, `extra=1` |

Observed Native result:
`[LearningHostPayload] PASS cases=5 checks=135 host=a8e09123805b2bf30706c8dd1914b928ae6b24ca`.
Task identity belongs to the Host caller; the Native payload contains no
invented `taskInstanceId`. The Host test separately observed progress
`0 -> 1 -> 1` after Native return, correct answer, and replay respectively.
These Host persistence observations are not attributed to the Native test.

## Required exact-source acceptance connection

The reviewed Native workflow originally runs on pushes to the Nextgen branch,
PRs targeting the action-stage branch, or manual dispatch. It has no head-name
guard and checks out the exact PR head SHA. An integration PR targeting
Nextgen therefore needs that additional PR base trigger. Root owns this
workflow change; this review clone did not alter the workflow.

The Host delivery verifier does not hardcode the previous 25 Native gates.
It requires successful `gameplay` and `new-worlds` jobs, exact Native source,
and artifact identity. Additional gates in the Native runner are therefore
enforced by the same required job.

The visual module set in Host `scripts/verify_nextgen_delivery.py` currently
omits `puzzle`. To review the changed puzzle scene honestly, that module set
and the fixed seven-image expectation in
`scripts/tests/test_nextgen_delivery.py` need the corresponding extension.
`record_nextgen_visual_review.py` already accepts the new capture paths
within `nextgen-evidence/nextgen/captures/`.

The eventual Host pin, `APPROVED[2018]` and source-bound visual receipt must
refer to the final accepted Native commit. Existing `ada5ed81` images or
receipts do not establish visual acceptance of this Studio source.
