# Final Native discovery verification and advanced-base reconciliation

The candidate joins the exact source union a7bb5815009ea4ae9b8842026f4f3761ae99c98b and the actual advanced C4 base f052c2795b765265dbb6f5c27b9e92b557d39a39 as ordered parents. No game runtime, shader, scene, asset or original test is changed by this reconciliation.

## Actual base and conflict

PR173's JSON still reported base0e261 while its real branch ref already pointed to f052. The original compare against0e261 was therefore insufficient to diagnose mergeability. The actual f052-to-a7bb comparison is diverged7ahead/2behind, merge base0e261.

The two new base commits introduce20 paths. Nine are already byte-identical here, including all production changes and the C4 handoff. Ten are additive historical source/evidence documents and one archive, retained directly using their original Git blob SHAs. The sole differing path is an add/add conflict in treasure_wisp_regression.gd: f052 carries the14-check producer version. This candidate retains our exact stronger blob67927a6f2147658d13e60cacdbbd24bf717a0c1d. All14 original check calls are text-identical and four direct MultiMesh renderer checks remain added. The full path/blob mapping is in native-base-f052-reconciliation.json.

The preserved f052 documents explicitly describe their own source checkpoints and unexecuted gates. They are historical provenance, not new acceptance claims for this candidate.

## Actual completed union execution

All original probes below ran against the same byte-verified local runtime union that was then published as a7bb. The minimal local directory was not a Git checkout; this is explicitly recorded. Its1391 original/producer files were checked against the immutable Git blobs. The final reconciliation preserves identical assets, scripts, scenes and project.godot object hashes, recorded in the JSON.

| Probe | Actual result | Seconds |
|---|---|---:|
| Full Godot4.6.3 import | Exit0, no parse/script/engine errors |9.588|
| Learning world |5347 checks, Exit0|19.698|
| Sharing |1811 checks, Exit0|2.857|
| Learning Studio |183 checks, Exit0|7.874|
| Native hub |8 actual routes, Exit0|0.912|
| Village HostBridge/boot contract |Exact original PASS, Exit0|0.160|
| Wonder headless |100 checks, Exit0|5.363|
| Wisp additional headless cross-check |14 checks, Exit0|0.431|
| Wonder real renderer |108 checks, including invalid activity, Exit0|125.996|
| Hub real renderer |2 original PNGs, Exit0|14.353|
| Existing learning real-touch capture |25 original PNGs, Exit0|580.766|
| Wonder geometry/image capture |136 checks,11 original PNGs, Exit0|106.094|

Every completed probe has its exact required PASS and no engine/script/parse/error or leaked-resource marker. The unchanged original25-image test exercised actual touch and child-facing controls. The new eleven-image test projected the actual mesh/shader flower vertices to verify clipping bounds. The38-image aggregate passed verify_discovery_rasters.verify against the actual output, including exact roster, dimensions, nonuniform PNGs, changed start/completion frames and real lesson/garden states. File hashes and all four real-renderer outcomes are in discovery-final-local.json; complete renderer logs and execution records are in discovery-final-renderer-tests.log. Earlier import/headless/checker logs remain in discovery-initial-runtime-tests.log.

The evidence checker passed8 test methods and31 negative cases. Independent QA reviewed the10/38 runner contract. This author's actual38-PNG replay above completed without rendering or modifying those images. The preserved Live9 gate remains separate; its earlier local images were lost in the workspace reset and are not reconstructed or claimed as a new run here.

## One tooling adjustment and remaining required CI

The only tooling behavior change is the timeout for the same25-image learning capture:600→900 seconds, matching the existing52-mode runner. The measured580.766-second success left about19seconds of600-second reserve. All25 images, original tests, markers, failure gates and the10/38 roster are unchanged. The successful image capture is not rerun solely to lengthen its allowance.

The host must pin the final reconciliation commit and execute the existing52-mode gate, Live9/7 PNG, and mandatory Discovery10/38 on that exact checkout. The final Discovery manifest binds both the real source commit and tree. Android compilation, signed APK and device/emulator acceptance remain separate mandatory gates. No physical Android FPS or release acceptance is claimed by these software-renderer results.
