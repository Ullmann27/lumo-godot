# Living Village source and selective integration review

Reviewed immutable published Native source:
`7c088c521fc6a3d6033040956b2f4aa255caf926`, based on
`ada5ed81ad62339f15289da62670c0a4f9f7f2b9`.
The published commit explicitly describes unfinished UI integration and
campaign verification. Its entire 24-file package is not a completed
Living Village runtime delivery.

## Completed free-construction portion

These seven exact published files form the connected free-construction
change. None needs the new settlement economy, residents, region, or GLBs.

| Path | Published Git blob |
| --- | --- |
| `scripts/creative/build_frontier_landscape.gd` | `40bf7e4e137e4c25161a5fbebe4f7ff43c18cb31` |
| `scripts/creative/build_state.gd` | `226e10e6dce77dd29ee70284cdb993e3a795868e` |
| `scripts/creative/build_world.gd` | `93bc6926de47dda1b1a8e9cb2eb77a90030690cd` |
| `scripts/tests/build_frontier_regression.gd` | `ae5b3da43f2566b1f67d4b185fbaeac625395602` |
| `scripts/tests/bauwelt_identity_2013_regression.gd` | `204c5e25fc258a7c39da223f35915c2bb1844774` |
| `scripts/tests/build_sandbox_tools_regression.gd` | `d8250ee38d9a6a8d0d520bf7d47222b1c0dda593` |
| `scripts/tests/build_transform_regression.gd` | `5e055e7adc210d777d7b400d33dc1f6497b2b660` |

Dependencies are the existing `BuildLandmarks`, `BuildVoxelStyle`,
`creative_kit.gd`, build catalog/sandbox/explorer, and current build scene.
The only new product-script preload introduced by this subset is
`build_world.gd -> build_frontier_landscape.gd`. Existing settlement launch
routes remain available through their existing scene and are not replaced.

The construction model expands from `HALF=24` to `HALF=128`: 257 by 257
possible cell coordinates, stored sparsely. The 1536-piece limit and save
version 1 remain. Existing original coordinates and support rules remain.
`build_world.gd` attaches the outer terrain, extends actual ground colliders,
sets camera radius limit 240 and far plane 520, uses that far plane for
selection rays, and extends the explorer limit. The spawn search starts
near the camera and searches successive rings instead of scanning every cell.

The new frontier probe checks distant builds, a real JSON roundtrip, full
building bounds, the open river, actual attached terrain, bounded terrain
chunks, physical ray hits on distant ground, and an explorer spawn near
the distant camera.

Prepared selective patch:
`/workspace/scratch/b3485b7bb989/godot-village-review-evidence/free-build-frontier-seven-files.patch`.
SHA-256: `f19a49543b5d25418afc6229b9dea3e6006c4a76d9cb2d70a230cb1a092d5c6e`.
The patch contains the seven published paths only. It contains no new
implementation or changes copied from a developer's working tree.

## Focused execution on the immutable published snapshot

Godot: `4.6.3.stable.official.7d41c59c4`.
Each probe used separate application data. Product tracked files remained
unchanged. These results were obtained on the full published snapshot;
the subset's dependency closure was additionally reviewed in source.

| Probe | Observed result |
| --- | --- |
| Fresh project import | Exit 0, zero ERROR/Parse/Script error lines |
| `build_frontier_regression` | PASS, 14 checks |
| `bauwelt_identity_2013_regression` | PASS, original object identity/templates/undo/save |
| `build_sandbox_tools_regression` | PASS, atomic fill/copy/mirror/undo/save |
| `build_transform_regression` | PASS, 38 checks |
| `build_nextgen_play_regression` | PASS, 62 checks |
| `build_settlement_regression` | PASS, 194 checks; mirrored AI campaign 22 days |
| `build_settlement_play_regression` | PASS, 127 checks |
| `build_village_art_regression` | 2259 checks, 0 failures |
| Published `build_village_economy_regression` | FAIL, long-campaign completion assertion |

No renderer run was attempted for this review because the executor lacks a
DISPLAY and Xvfb. Geometry/node, physics and logical checks are not visual
approval or device performance measurements.

## Published Living Village gaps

The new state model defaults `use_living_village` to false.
`build_settlement_world.gd` still calls `STATE.new(mode)`, presents the six
classical building choices, and retains the old world setup. The new
`build_settlement_region.gd` and `build_settlement_residents.gd` are instantiated
by the Art regression, but not by this published production world. The new
campaign, public-project, delivery and story interfaces are therefore not
connected in the production scene. No new settlement speech path is connected
in this published snapshot.

The Host options do survive the published route: `HostBridge.validated_options`
copies the full input and maps `game=build` to `scene=build`; boot copies them
into `SceneRouter.launch_options`. The router selects `build_world.tscn`.
The real Siedlung/Wettbau buttons call `_open_settlement`, which only adds
`settlementMode` and `buildSlot`, then navigates to `settlement`. Neither
published Build scene consumes the learning voice flags or invokes
`speakLearning`. The only published production GDScript consumer of that
speech API is `learning_world.gd`. Forwarded flags alone therefore do not
establish a Bauwelt speech path.

Classical version-1 settlement saves still use the old rules. Explicit
model-level opt-in upgrades to version 2 and preserves resources, population,
buildings and day; the existing new test exercises idempotent migration and
rejects malformed new economy records. Those model checks do not substitute
for a completed world/UI migration and navigation test.

## Campaign failure and diagnosis

The published long-campaign test runs a greedy action planner. It considers
expansion before the prepared market purchase priorities and spends the
initial money before establishing income. Its original 350-turn run reached:

- Chapter 4, market count 0, trade count 0.
- Region 1, 16 plots, 6 residents.
- Coins 0, income total 0, but wood 4088, stone 3056 and food 4174.

This is a real failing published acceptance probe, but it does not establish
that the underlying campaign is impossible. A separate diagnostic copy used
the already existing regression's legal opening: house, farm, lumber, quarry,
well; three real days; then a paid market. The remaining long-campaign logic
and all assertions were retained. No currency or other resource was injected
and no product file was changed.

That diagnostic reached all 12 chapters in 56 days, with 1089 plots,
98 residents, 48 children, all four paid public projects, and passed all
330 assertions. The distinction is explicit: the campaign model has a legal
completion path; the published test planner fails; production world/UI
integration remains unfinished.

Relevant logs in `/workspace/scratch/b3485b7bb989/godot-village-review-evidence/`:
`build_village_economy_regression-runner.log`,
`village_campaign_diagnostic.log`, and `village_legal_opening_diagnostic.log`.
The diagnostic result does not relabel the published regression as passing.

## New GLB imports

All three GLBs imported cleanly. Independent GLB JSON/accessor inspection found:

| Exported model | Bytes | POSITION vertices | Triangles | Joints | Materials | Animations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Bruno | 205240 | 2586 | 3744 | 7 | 1 | 2 |
| Nelli | 211272 | 2760 | 4032 | 7 | 1 | 1 |
| Tilda | 191444 | 2300 | 3360 | 7 | 1 | 3 |

The manifest's smaller vertex values describe different counts than the
exported POSITION accessors; triangle counts and bytes agree. The Godot Art
probe independently verifies imported skeletons, skinned meshes, animations,
bounded crowds and pause behavior. These assets are outside the seven-file
free-construction subset.

## Existing producer work: inspect, do not duplicate

The active producer is under `/workspace/scratch/5a306b6c9c68/`. A read-only
check found completed local commits addressing precisely the remaining work:

- UI worktree at `85ac830c6ce647cd5db80302e227581c7efef322`: actual
  `STATE.new(mode, true)`, explicit legacy upgrade, REGION/RESIDENTS attachment,
  voice consent flags and story/economy/delivery presentation.
- Economy worktree at `44009697eadd8093b9dd408819d77be33dc42cf8`: schema
  boundary validation, contribution preview, campaign planner, and a bounded
  visiting trader recovery path before a market exists.
- Main producer worktree observed at
  `355908d34427eb3f9c190a99e2f62396d97ca6a9`, including additional completed
  local integration/art work. Targeted world and economy-test files were
  committed and clean during inspection.

The GitHub living-village branch still resolved to published `7c088c5` during
the remote read, repeated at 2026-11-13 13:16 UTC. Local successors were not copied, merged, or represented as
published acceptance-ready deliveries. The producer should finish and publish
its paired world/UI/economy result before full-package integration review.

## Acceptance connections

For the selective free-construction portion, connect these existing probes
to the current Nextgen headless gate list with its normal 420 s budget:

```bash
check_probe build_frontier_regression '[BuildFrontier] PASS' headless
check_probe bauwelt_identity_2013_regression '[BauweltIdentity2013] PASS' headless
```

The modified sandbox-tools probe is already called by `validate_2014.sh`.
The transform and Nextgen-play probes are already called by
`validate_nextgen.sh`. The identity probe was not present in the inspected
mandatory acceptance runners, so it should remain an explicit preservation
gate for the enlarged world.

The two connections are prepared as a separate patch against the existing
30-gate integration runner:
`free-build-frontier-gates.patch`, SHA-256
`95b14f1c1cdc4884f0528578908973e768e0bd7e0553a0b903bc037c81e884c5`.
This patch adds exactly two headless calls and retains every existing gate
and timeout. The resulting 32-gate shell passes syntax validation and all
three existing fail-closed orchestration tests. The review report and both
patches are copied into the local `godot-village-review-evidence` handoff.

For a future completed Living Village snapshot, its published economy, art,
UI and scaling probes must be reviewed and connected. The current Art probe
reports `2259 checks / 0 failures` rather than a `PASS` marker; its existing
success text plus clean exit must be honored. No nonexistent or unpublished
probe was added to the integration runner by this read-only review.
