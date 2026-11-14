# Kart geometry workflow: genuine fixture failure and bounded repair

This packet binds the unmodified published source `90d34181409c15d1b1ad3a6a9643539453155c1d` (tree `9b407d61633a6421dc47b6858e6a6fb3fa60bea5`) to a narrowly scoped workflow repair. Local base `64202e88e979b110cc3fdca511d4644be7f12ea7` has that same tree.

## Observed failure

Run 43483977367, job 132087436119, reported GitHub SUCCESS. Its actual checkout was PR merge `40ae7b7d0768a30e9c4ae76c1c3c55901d29dfab`, independently tree-bound to the published source. Checkout explicitly disabled sparse checkout. The workflow-created isolated fixture omitted required Platform/Teacher pose scripts and their transitive BodySpace/StudioClips dependencies. Genuine Parse/Compile errors and the original geometry success marker coexist in the original log. A nonterminal inverted `! grep` did not stop the shell; the final positive marker grep returned zero.

Complete original API/log data and the separate historical cce correction remain unchanged in `../auxiliary-90d34181/`. Its original manifest SHA256 is `cb9cd641d54d01f99f64e0ce5c11d195a10b9eeab9f1a0a36a0930106801757c`; the decoded original job log SHA256 is `1732e99646acb4cf6b18dcb7e9a1408843425474b36109e3ad3badb60c70192e`. The older cce run has the same proven technical failure; its API SUCCESS remains a historical fact, not a valid geometry result.

## Actual local red and green

- Unmodified original workflow shell and actual Godot 4.6.3: exit 0, original marker present, 11 engine error lines, 10.147 seconds. This is a faithfully reproduced false success, not an invented nonzero exit.
- Repaired workflow shell and the same original geometry/product sources in a fresh fixture and separate XDG directories: exit 0, no engine errors or resource-leak exit messages, original marker present, 9.697 seconds. All 15 required copied source files equal the committed original bytes.
- The real green ran on workflow SHA256 `8f8976db482d3c543327cdeda268b5d7d1010c097ce3bb5002bd3e16b9eab249`. A subsequent isolated change adds the two already existing push filters for cinema materials/shaders under pull_request. The final workflow SHA256 is `da132fa960d01a2192b916dc9a53a7013dc2bd95599fbcf1a4e9b466d476ad2d`. Its actual engine shell block remains byte-identical: SHA256 `6b5b934915eed9f36b1d86d9a49fa44ae943dd61c07089be7717a8f05e4acbd8`. No second engine run is claimed.

## Repair and counter-contract

The workflow explicitly includes the complete four-file missing preload chain. Both import and runtime use the unchanged existing strict `tools/run_godot_probe.py`, retaining the 120-second limit and the original runtime marker. Original import/probe logs are archived with `if: always()`. Trigger paths include the actual new fixture dependencies, strict runner, and bounded test.

Five tests execute the actual workflow shell with explicit synthetic engine transports: complete original dependency copies, import ERROR with exit zero stopping before runtime, runtime ERROR after the required marker despite exit zero, missing marker, and preservation of error logs. These are gate tests, not substitute gameplay evidence. Against the old workflow there were three assertion failures and one missing-archive error; the existing missing-marker rejection already passed. All five passed on both the initial repair and the final filter-only workflow. Focused actionlint exited zero on both. Raw logs and exact source hashes distinguish each execution.

## Scope and verification

Only `.github/workflows/kart-vehicle-regression.yml` changed among 1,404 pre-bound existing source/assets/tool/workflow paths. The only new source file is `tools/tests/test_kart_vehicle_workflow.py`. The strict runner and genuine geometry probe remain unchanged. Root-owned status/evidence documents are outside this source scope. No product edits, deadline increase, error-filter weakening, pin/receipt mutation, staging, commit, or remote ref change was performed by this repair agent.

`manifest.json` records both stored and decoded hashes. Gzip objects use mtime zero and preserve full original bytes. Before/initial-green/final snapshots and both exact patches are retained. This is local repair evidence; fresh published CI validation remains separate and no Native package or visual approval is created by this packet.
