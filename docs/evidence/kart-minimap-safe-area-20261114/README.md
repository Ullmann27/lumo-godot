# Kart minimap: actual bounded repair and counterexample

The original minimap overflow is reproduced by the existing Safe-Area test, and the reviewed correction passes the same test bytes. This is a source-bound Godot geometry result. It does not replace a new rendered or Android-device acceptance.

## Exact integration basis

The audited Kart source was `f0c19f9eb69ea330ac5d2b8f9948cb029ca218aa`. Integration and actual local runs use its direct successor `f052c2795b765265dbb6f5c27b9e92b557d39a39`, tree `35492eec16cac6774bc546b6e57628900bef61cb`. Both owned baseline files are byte-identical at those commits. The successor tree preserves all intervening Treasure/learning-feedback files.

| File | Original blob | Reviewed and executed candidate blob |
| --- | --- | --- |
| scripts/games/kart_island.gd | f7473190f51fb5dbda7d0f7ad7292f8ec64c0da2 | 83b3b6b548cffa2790c582e061a74e37bbfcf356 |
| scripts/tests/mobile_safe_area_regression.gd | 61ded805fdbc70c3499814b4e8f74214079fc96c | 6c58c08b8c47a7bf7c957c448b88474a984b9509 |

## Observed original defect

The unchanged 2400 × 1080 Android upgrade images `21_race_driving_late_2.png` and `21_lumo_kart_real_race.png` show the minimap cut by the right image edge and covering the upper SPEED artwork. The worker personally inspected both before the runtime reset; the independent reviewer later fetched and personally inspected the first original again. Its durable location, full image hashes and limits are recorded in `manifest.json` and `independent-review.json`.

The old top-right panel used fixed offsets while its child's 160 × 128 minimum grew with UI density. Container padding added another 14 units on each edge. The required panel could grow beyond the positioned rectangle and draw over controls added earlier to the scene. Both minimap nodes ignore pointer events, so these screenshots alone are not evidence of intercepted touch events.

## What changed

The production change is confined to minimap layout in `kart_island.gd`. It observes actual settled safe-area and HUD geometry, reserves the entire instruction and visible jump-hint rectangles, and considers the safe right edge followed by the actual control edges. All visible header buttons, the joystick and pedal artwork are excluded. Pedal artwork is explicitly checked at its unchanged 1.12× drawn extent.

The passive map keeps its aspect and may use an 80 × 64 dp content minimum. Its minimum is no longer re-expanded by the generic UI scaler. A newly shown or hidden jump hint queues fresh layout through real visibility/rectangle signals. Compact, short and arena optional-map behavior remains. Driving controls, physics, action handlers and assets are unchanged. Of 142 previous production functions, 139 are byte-identical; three existing layout functions and two new helpers implement the correction.

The independent first review identified an instruction-row omission in the initial draft. The second draft fixed it before execution. The immutable independent review addresses exactly the production and test blobs shown above.

## Actual unchanged-test comparison

Both runs used the already installed Godot `4.6.3.stable.official.7d41c59c4`, the same new test blob and separate temporary user-data directories. Sources were hashed before and after each run and did not change.

| Run | Production | Checks | Failed checks | Exit | Elapsed |
| --- | --- | ---: | ---: | ---: | ---: |
| Original baseline | f052 original Kart | 380 | 26 | 1 | 14.813 s |
| Reviewed candidate | exact V2 Kart blob | 380 | 0 | 0 | 15.474 s |

The original failures are minimap/control/notice overlap, escape from true safe bounds and failure to reposition when the live hint appears. All original fifteen Safe-Area control records remain. Seven added profiles cover dense left/right cutouts, changed density at identical pixels, an expanded inner display, compact portrait, short landscape and restoration. A focused two-step hint show/hide cycle uses the real hint API without a viewport resize or manual layout call.

In the dense left-cutout result the visible map panel is approximately `(1495.56, 431.25, 406.51, 333.60)` physical fixture pixels, fully inside the measured safe rectangle `(136, 63, 2264, 954)`. On the expanded display the real hint moves its top from `359.46` to `511.98` pixels and hiding it restores `359.46`. These are actual headless Control geometry observations, not rendered screenshots.

Both runs emit the same two nonfatal compatibility-renderer warnings about screen-space AA and volumetric fog. The candidate has no script/runtime error lines and the original report records zero failed checks. Raw logs, reports and invocation records are preserved without editing under `red/` and `green/`; `result-summary.json` records the diagnostics explicitly.

## Mandatory gates preserved

Removing only the additions reconstructs the entire old Safe-Area test byte-for-byte. Its fifteen original control targets, four original rendered Mobile images, existing scene/cache/reader/workshop assertions and failure behavior remain intact. The unchanged `tools/validate_nextgen.sh` still has exactly 52 probe/mode invocations and runs this test both headless and rendered. Its old raster verifier remains unchanged.

Additional Kart PNGs use a separate `LUMO_KART_MINIMAP_CAPTURE_DIR`, set only for a real `--capture` invocation. They do not replace or alter the four existing required Mobile raster fields. The checked-in invocation record is the actual local headless run; the full 52-mode suite was not duplicated locally.

## Rendering limitation

The installed Xorg/dummy setup was attempted in an isolated task directory. Xorg exited 1 because it could not create listening sockets. A separate task-owned Unix-socket probe also received `EPERM / Operation not permitted`. No new renderer image was produced, no dummy image was substituted, and no new engine or permission workaround was installed. Original startup logs and configuration are preserved under `display/`.

A genuine candidate render/device check and the ordinary full candidate CI remain required. There is no claim of Android interaction, frame rate, audio, whole-app completion or Play Store readiness from this bounded repair.
