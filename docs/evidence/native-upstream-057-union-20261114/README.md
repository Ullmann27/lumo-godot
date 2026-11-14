# Native upstream union and discovery trigger — 14 November 2026

The final source checkpoint is **84789d0c2c6fb4b6ecd2897ce1951b89f958b604**, tree **91cc8fc1c6f8a36336b7ac9a12585284a983a6f6**. Its only change from the locally tested union is the authorized workflow trigger patch. No central reference was changed by this reviewer. Root subsequently activated this exact commit at 16:01:20 UTC.

The focused local checks passed on the unchanged runtime of parent **fe861bd09296ef0051887dc21f48ca38215fc76b**, tree **c4271487ba818845a5428e31877ca701c4dd5f5f**. They are not a replacement for the final Native/Host acceptance. In particular, the rendered Scaling run proves **46 runtime checks, two original PNGs, and unchanged tracked bytes/modes/logical index entries**; it does **not** prove raw index-file byte equality. The exact limitation is recorded below and in the original inventories.

## Source and genuine ancestry

Host producer **057a4e8d067872c4f3514b126aa04c3706d2e5b5**, tree **a2ae17af283a76fb3b99f1a0899a0898e7157230**, has parents **77936fae6ce7b7bcbddb93dda19fb0104f696e12** and **0b7bacadd3cdc45d22a8e038c5df50ba8b739d62**. Its actual `config/godot-source.json` blob is **6f05fad948c0b3c07d5266afac3e0725c188bae7** and pins Native **a69f53518b2510873d88f00ff2783d616ab53702**, engine 4.6.3.

The accepted Native parent was **e9a9f60f20403ffa6b2b26d1437f958b2704d2aa**, tree **1c2b5da7a4485cb8b911adcac2b567481cf902b5**. Incoming a69f has tree **607643d9e109079925e21dfcf9c991a8250d4a46** and parents **e2d15dbc5f3709306decb139eeb70a1cf30c0b73** plus **baf148b03a7a32c6ad9f737d731f900eb9113ea1**. The actual e9/a69 merge base is e2d15. The comparison was diverged, seven incoming commits ahead and ten accepted commits behind; incoming a69 alone was not a superset.

Full, untruncated trees contain 3,649 files at the merge base, 3,712 at e9, and 3,721 at a69. The direct comparison has 116 differing paths: 49 only in e9, 58 only in a69, and nine present with changed identities. Three-way classification has 62 incoming-only changes, 51 accepted-only changes and three changed on both sides. These are distinct classifications, not interchangeable counts.

The genuine merge **fe861bd** has exactly two parents, **e9a9** and **a69f**. Its 3,770-file tree takes exactly **65 original incoming blobs and modes** and preserves all 51 accepted-only changes. There are no removals. The complete 65-entry list, three-way classification, source API payloads and full tree proofs are included in this evidence directory.

The three shared paths resolve to exact incoming originals:

| Path | Chosen original Git blob | Integration reason |
| --- | --- | --- |
| `scripts/creative/build_settlement_world.gd` | `149a4386225812592917b1bcac0b85294413f1b4` | Incoming bounded detailed facilities and overview instances retain the actual HostReady, save and direct Host-return changes. |
| `scripts/learning/learning_wonder_garden.gd` | `616e9824e3c14f9ab4f5e29da0d926a577516b5e` | Ambience is owned by the existing atelier parent. |
| `scripts/tests/learning_wonder_details_regression.gd` | `4801759f704708bc53613d5aed8cacd595b01289` | The original regression checks that one actual atelier-owned ambience exists, without a duplicate. |

The incoming settlement state uses the validated version-2 envelope for the living ledger, including negative coverage for misleading legacy economy-version fields. The 96-detail bound per town, overview batches, camera-region changes and explorer transitions remain the incoming producer implementation. The Original-Lumo Hub, actual identity reports, direct child-bound Village return, Live9 runner, additional Wisp checks, original Studio negative cases and five accepted producer workflows remain preserved. No speculative Kart/Garage product fix is included.

## Exact additive trigger patch

Final commit **84789d** has the single parent **fe861bd**. The final full tree differs from fe861bd at exactly one path: `.github/workflows/lumo-discovery-connections.yml`, mode `100644`, original blob **a806855cf51ab7f63b14163596488fc1d3746dc1** → **02940ea1a3698d14b8fabaed4d5ee7af5b24907b**.

Only three literal replacements were made:

1. The push branch filter also permits `integration/lumo-live-connections-20261114`, while retaining `integration/lumo-discovery-bd-20261114`.
2. The job condition permits precisely those two refs, still requiring this repository and a push event.
3. The concurrency group includes `${{ github.ref }}`. `cancel-in-progress` remains false.

Reverse application restores every original byte. All twelve original run blocks, every step/upload, the 130-minute limit, permissions and the other 3,769 files remain unchanged. The runtime/helpers were not rerun solely for these workflow expressions.

Actionlint **1.7.12** returned zero with no diagnostics. The binary SHA-256 is **c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4**. All twelve run blocks pass `bash -n`. The static contract reads the actual YAML and checks twelve repository/event/ref cases, including both permitted branches, unrelated branches, misleading suffix/prefix refs, a tag, a fork, another repository, pull-request/manual events and a pull-request merge ref. The two allowed refs produce distinct concurrency groups. This is static contract evidence, separate from GitHub's actual dispatch.

The dispatch was subsequently observed: **run 43613299144, attempt 1**, event **push**, branch **integration/lumo-live-connections-20261114**, exact head **84789d**, created **16:01:22 UTC**. Eleven additional PR workflows started on the same head. The initial catalog is a point-in-time record, **not a terminal success claim**. Their terminal original evidence is collected separately.

## Fresh focused verification

All commands, complete stdout/log files, timings and source identities are preserved.

| Actual check on fe861bd | Result | Actual elapsed time |
| --- | --- | --- |
| Original strict Discovery helper tests | 24 tests, no skips, exit 0 | 20.046 s |
| Original Discovery raster helper tests | 11 tests, no skips, exit 0 | 38.882 s |
| Original Studio raster helper tests | 24 tests, no skips, exit 0 | 14.277 s |
| Full production project headless import | Exit 0; no error/leak lines | 41.628 s |
| Village economy original probe | `[VillageEconomy] PASS 339 checks` | 1.131 s |
| Village scaling original headless probe | `[VillageScaling] PASS 42 checks: full 2178-house model, camera and explorer` | 5.321 s |
| Original direct Village Host launch probe | Exact original PASS marker once | 1.579 s |
| Learning Wonder original headless probe | 100 checks, zero failures; invalid scene not checked in this mode | 5.961 s |
| Village scaling actual renderer probe | 46 checks, two original PNGs, exit 0 | 34.120 s outer; 33.962113 s renderer runner |

There are **59 freshly executed Python tests**, not 82 or 47 Studio tests. The earlier merge commit's wording “47 Studio counterexample tests” referred imprecisely to the existing combined 24-Studio/23-runner collection; the 23 nextgen-runner tests were **not** executed in this focused preflight. This note corrects that description without rewriting original commits or logs.

The original headless per-probe log and corresponding runner stdout are byte-identical. Each required marker appears once and the recorded error/leak checks are empty. Six Python source ASTs and the original YAML parsed successfully. The first static report accurately records that Actionlint was not yet available on PATH; the later trigger-patch report records the actual successful Actionlint run.

Environment: CPython **3.12.14**, Pillow **13.0.0**, Godot **4.6.3.stable.official.7d41c59c4**. The engine binary SHA-256 is **f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3**. The actual CI workflow retains Pillow **12.3.0**; these versions are not conflated. Headless and rendered checks used private state/output directories, and the renderer used an isolated authenticated Xorg display through the unchanged repository runner.

## Two original Scaling images and visible findings

Both PNGs were decoded as 1280×720 RGBA and opened individually for visual inspection. They show the existing **2,178-house stress fixture**, not a default newly created village. The home-region view shows detailed houses near the active region and simplified roof/body instances farther away. The river-boundary view shows both riverbanks and the bridge, with detailed houses close to the two banks. No black/error view or missing whole-town region is visible. Header values, back, Lumo and pause controls are readable. The bottom rows retain horizontal scrollbars; this review does not claim every horizontal action is simultaneously visible.

| Original PNG | Bytes | SHA-256 | Git blob |
| --- | ---: | --- | --- |
| `01-home-region.png` | 767,547 | `002d626354042e070fabebb5d8537926880f7e2f8062ffb5a3ae54754e480491` | `0f3d7cdd0e6738961fecd77d0ea5f2ec40819790` |
| `02-river-boundary.png` | 996,507 | `3e17cff1e6cb5c6b477914a08b80eb310be4957ffd411469226cb1dae669d87c` | `1dd069f09f8baf82289c82b3a7d77767d3d0297e` |

The actual renderer is Mesa llvmpipe, OpenGL 4.5 Compatibility, Mesa 25.0.7-2+deb13u1, LLVM 19.1.7. Its original log contains **three warnings**: V-Sync changes unsupported by this graphics driver; screen-space AA requires Forward+ or Mobile; volumetric fog requires Forward+. No warning-free claim is made. These images and node checks do not establish Android performance, 60 FPS or physical touch acceptance.

## Source and index limitation

The preflight before the renderer has identical HEAD, tree, all 3,770 materialized tracked records and raw index SHA-256 before/after. That original result is preserved independently in `preflight/source/`.

For the separate rendered check, all 3,770 tracked records, actual file bytes, modes, logical index entries, HEAD and tree match before/after. The 961 generated import/UID records also match. Git status, working-tree diff and cached diff are empty. However the raw index-file SHA-256 changes from **7c7edd8cfbbd8cf72be4d69f5da099e37430700c272f5cc99ac4967073d520fc** to **b5b4f3ad78741fc278ae456ef285f82caea0d92ef0476f9881a978f774d3c332**.

After rendering and before the after-inventory, this reviewer ran `git status` without `GIT_OPTIONAL_LOCKS=0`. The change is consistent with a Git stat-cache refresh, but exact causal byte-level attribution is not asserted because the original raw before-index bytes were not retained. No original report was repaired or rewritten to hide this. The rendered result is explicitly **not a raw-index equality PASS**. The final real Native workflow retains its unchanged strict before/after index gate and global `GIT_OPTIONAL_LOCKS=0`.

## Preserved helper and notice contracts

All five incoming helper blobs remain exact in the final tree: strict Discovery reader **c00ca987**, collector **1ebdec66**, Discovery raster reader **219e691f**, Dream reader **da8eed7d** and probe runner **c23859ec**. Full SHA/mode records are included. In particular the Dream reader remains executable mode `100755`; other listed helper modes are preserved from their producer tree rather than normalized.

The four existing notice texts remain exact, mode `100644`: Nunito **c8210f08**, animated Lumo attribution **3b3f2070**, facial attribution **50f43591**, third-party notices **ceedc772**. No notice was rewritten.

The collector produces its original numbered logs, invocations, source-stamp inventories, 38 PNGs, two reports and `discovery-acceptance.json`, with the strict `[DiscoveryOriginals] PASS 10 exact probes, 38 decoded PNGs and 2 original reports` marker. It does not fabricate the previous legacy manifest/marker. Host integration keeps Live9 separately and invokes the new Discovery collector once. The separate Native workflow supplies the additional Village Scaling and live minimap checks; those are not falsely counted inside the existing ten Discovery probes.

The evidence manifest hashes every archived file. Original stdout, API content, reports and PNG bytes are preserved without substitution; derived reviews are labeled separately. Runtime source, central refs and Host pins are not changed by the evidence commit.
