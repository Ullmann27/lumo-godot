# Treasure star trails: targeted Native integration

Base: `1f12bc894bfeae1c8595dbd8782964be0a797dd7` (verified d119 baseline plus C4 recovery).
Source: PR172 at `1b01b08abd4ff2580125d787a6150e10b2fe47b8`, rechecked unchanged before checkpoint.

## Included scope

The production shader, visual layer, world hooks, exploration regression, and producer design note are reused as exact published blobs. The only production-world delta from d119 is twelve added lines: instantiate the visual layer, update it from actual available goals, celebrate real discoveries/correct answers, and pause it with the existing modal. Quest rules, save/reward authority, the 785 HUD/cutout corrections, and the C4 recovery stay intact.

The visual layer uses two groups of sixteen guide sprites and twenty reusable celebration sprites. It adds no collision or touch targets. Reduced motion and modal pause are exercised.

The Wisp regression retains all fourteen producer checks. Four direct MultiMesh transform checks from the original test are additionally required when using a real renderer: forward placement, both fork directions, and unchanged instance transforms under reduced motion. The workflow now invokes that eighteen-check renderer mode explicitly in addition to its fourteen-check headless mode and three-image quest capture. Its YAML and every embedded shell script parsed successfully.

## Independent verification on the combined Native runtime

The parent checkout/index was untouched. Tests used a separate runtime copy with exact d119 runtime resources/helper blobs, the C4 fix, and the source blobs listed in `evidence.json`. Godot was `4.6.3.stable.official.7d41c59c4`.

| Probe | Mode | Observed result |
| --- | --- | --- |
| Wisp regression | Headless | Exit 0, 14 checks, 0.472 s |
| Wisp regression | Actual OpenGL Compatibility / Mesa llvmpipe | Exit 0, 18 checks, 2.624 s |
| Treasure exploration | Headless, actual scene and both routes | Exit 0, 92 checks, 2.061 s |
| Existing title/contrast regression | Headless, five profiles and fresh/restored state | Exit 0, 3,341 checks, 0 failures; duration not separately measured |
| Updated project import | Headless editor import | Exit 0, no engine/script error lines |

Complete short logs are stored beside this handoff and bound by SHA-256 in `evidence.json`. Renderer acceptance required a successful process/run report, the exact expected PASS marker in the actual Godot log, and absence of SCRIPT ERROR, Parse Error, and ERROR lines. The original unmodified fourteen-check readback test also passed in the real renderer; its log is retained.

Two exploratory wrapper invocations used an incorrect success-marker/output expectation (HUD marker spelling, and a renderer launcher that redirects Godot output into a file). Their outer failures were not accepted. The final HUD command and final eighteen-check renderer verification used the correct marker and actual Godot output.

## Original red Wisp case and retained renderer coverage

Run `43574314431`, job `132385103853`, failed the original headless test's two fork-direction checks. Headless Godot uses its dummy rendering backend; that test depended on MultiMesh readback. Producer 1b01 extracted the same route-coordinate formula into `route_point()`, used by both the renderer and headless assertions. We independently ran the original readback test unchanged with an actual Compatibility renderer and observed all fourteen checks pass. The integration also restores all four direct transform assertions as additional checks in actual renderer mode, so passing the source-coordinate checks alone cannot satisfy that mode.

## Published source-bound render evidence

Producer run [43574914204](https://github.com/Ullmann27/lumo-godot/actions/runs/43574914204), job `132386964721`, completed successfully on exactly 1b01. It passed fourteen headless Wisp checks, ninety-two headless quest checks, and ninety-five real-render quest checks, including three original PNGs.

Artifact `14105782145` was downloaded; its ZIP SHA-256 is `d75d200139dac7fc9f48084abe494202d8cd08a176164043d5de28ebeffd489c`. The extracted source file matched 1b01. Every PNG's bytes/hash matched the included manifest, and all three 1280×720 images were visually inspected: guide trails, remaining-route state, and completion UI. Their exact hashes are in `evidence.json`. These are producer-source images; they are not relabeled as combined-baseline captures.

## Explicit remaining boundary

Two additional full-quest local renderer attempts on the combined runtime ended with external SIGKILL (exit -9), after 15.946 s and 13.435 s. The second ran after the team paused other renderers. Neither reached a PASS marker; neither is accepted. No engine/script error appeared before termination. The cause is unverified, and an out-of-memory diagnosis is not claimed. Their identical short Godot log and both run records are retained. A completed full-quest renderer run on the final shared integration remains a gate for that acceptance.

The existing 52 Native probe modes and 17 raster/movie contract are unchanged. No main merge, Android device run, physical FPS measurement, or complete APK release is claimed. Parent coordination connects the additional probes in the shared live-integration gate.
