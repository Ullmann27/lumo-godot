# Native Garage: bounded source and input review

## Scope and decision

The accepted Native commit remains `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa`, tree `1c2b5da7a4485cb8b911adcac2b567481cf902b5`. No product, central branch, Host pin, or test limit was changed by this review.

The actual Android originals show a partially scrolled vehicle list. They do not establish that manual vehicle selection is broken. They do establish that the Host probe lost all of its complete vehicle-name OCR anchors after one recorded swipe. A proposed short swipe confined to the visible caption is physically accepted by Godot's touchscreen scroll path, but the present evidence does not guarantee that it keeps a complete caption available after every swipe. An actual API35 diagnostic with the unchanged APK is still required.

The supplemental execution archived here is a small **headless desktop input fixture**, not the Android application, a full Garage scene, a screenshot, or an OCR replay. Its caption rectangles are inferred from the original Comet OCR box and the actual positions of the copied card components. In particular, an inferred caption being partly outside the clip does not prove how Tesseract would transcribe the pixels.

## Immutable originals examined

- Host `1e22d2455937e2640d1e44e153d290746f3afe49`, run `43596913210`, attempt 1, Native `e9a9f60…`.
- Android job `132484382995`, artifact `14119041396`; the Android QA agent downloaded and validated the original archive once. This review did not download it again.
- Before frame: `main/21_stage_select_gecko_velo-0.png`, 788919 bytes, SHA-256 `2c5214fe0ae35668c6e547dabcf14772a6e06101e52edd5e13bf01e99c7ab290`.
- After frame: `main/21_stage_select_gecko_velo-2.png`, 784389 bytes, SHA-256 `33ff8013d1541f6c1d0367caba494a4f8cd29578cd2d6c783d636d75386a6549`.
- The unmodified readiness JSON records the visible Comet OCR bounds `[313.5,471.0,434.0,500.0]`, a planned then sent gesture `[374,486,374,341]`, and the subsequent error `No currently visible vehicle card in the actual left list`. The gesture was sent once; the error followed at 50.399644 seconds, within its existing 150-second bound.

The reviewer personally opened both original PNGs. Before the gesture, Comet is fully named and its card occupies nearly the entire left list. Afterwards the green vehicle is partly above the clipped list and Boru Rally's name is partly below it. The Original Lumo figure, selected Kart preview, footer, and start action remain visible. The clip bounds used below are an image-derived approximation, not a native telemetry measurement.

## Actual production call path

`scripts/games/kart_island.gd` loads `kart_spatial_menu.gd` at line 11. The Spatial menu extends `kart_garage_menu.gd`; it overrides the responsive layout. Therefore the classic base menu's 86/142 dp card heights must not be reported as this Android layout's final heights.

| Source | Exact Git blob | Relevant contract |
|---|---|---|
| `scripts/games/kart_island.gd` | `83b3b6b548cffa2790c582e061a74e37bbfcf356` | Spatial-menu preload; Kart sets content scale size to 1280×720. |
| `scripts/games/kart_spatial_menu.gd` | `90de80bb86a115aae46b9802d8c216c6ca413c3f` | Lines 275–385 position the actual drawer, workshop button, and footer; card height 90 dp, or 72 dp only below 300 dp available height. |
| `scripts/games/kart_garage_menu.gd` | `69181cb383de72a2058d2a1d64d629d825b1d871` | Lines 258–265 create the inherited ScrollContainer; lines 1370–1414 create and connect the vehicle buttons. |
| `scripts/games/kart_vehicle_card.gd` | `1db0b925f5737bf143187e296c06c938eb0c4d45` | The entire button is interactive; children ignore mouse input and the card passes drags to its parent. Compact card layout uses the original name and statistics. |
| `scripts/app/mobile_runtime.gd` | `53c6974ef2e1ba82bbb1fff71c9be4d9c16a911f` | Density comes from the actual Host option or Android DPI/160. Density 420 therefore corresponds to 2.625. |

The Spatial menu places the workshop button in the footer only when the available height is below 300 dp, or below 360 dp in landscape. The observed image still shows `Lack, Teile & Effekte` in the left panel. The resulting visible list is approximately physical y416–665: about 249 px / 94.86 dp. A 90 dp card occupies about 236–237 px. Partially clipped neighboring cards are therefore possible during ordinary scrolling. There is no project override of `scroll_deadzone`, no scroll-ended snap, and no automatic post-drag caption alignment in this path. Switching the actual menu section resets the drawer offsets; it does not snap individual cards after a swipe.

## Engine behavior verified from its primary source

The installed binary is `4.6.3.stable.official.7d41c59c4`. The engine source was read from `godotengine/godot`, tag `4.6.3-stable`, `scene/gui/scroll_container.cpp`, Git blob `7794443daf6be4ebd837126816c634f343004b4d`.

- Lines 882 and 938 define and load `gui/common/default_scroll_deadzone = 0`.
- The drag branch at lines 231–264 accumulates the local mouse-motion relative vector and begins scrolling when the enabled-axis absolute displacement exceeds the deadzone.
- Release can enter deceleration. Lines 514–577 update scroll position from drag speed and reduce speed by 1000 local units/s².
- The project contains no override of this default. The fixture independently observed a zero deadzone and a scroll-start/scroll-end pair for every actual gesture.

This proves that 25–27 physical px are not blocked by a positive deadzone in this path. It does not establish the exact Android event cadence or explain the whole measured Android post-swipe displacement. No exact Android inertia cause is claimed.

## Bounded desktop execution

Only nine original source/asset dependencies were copied into an isolated project, totaling 529788 bytes. Each copied file was checked against the immutable Native Git blob before execution; `source-copy-manifest.json` records the identities. The fixture uses the original VehicleCard, Fleet, StatBars, Theme, font files, and first three vehicle thumbnails. The card container and scroll rectangle are reconstructed for this diagnostic. It omits the full Garage stage, preview, GPU workload, Android input pipeline, and application state.

The fixture uses a 2400×1080 window, 1600×720 logical viewport, pixels-per-unit 1.5, density 2.625, and UI scale factor 1.75. Its actual cards are 237 px high with a 241.5 px pitch. The inferred first two caption boxes initially begin at y471 and y712.5, both 29 px high. Comet is fully within the assumed clip only through offset55 px. Gecko becomes fully within it from offset76.5 px. The interval between those values has no fully enclosed caption according to this geometric criterion.

Input enters through actual `InputEventScreenTouch` / `InputEventScreenDrag` events, with the same desktop touchscreen-emulation mechanism used by the repository's existing input regressions. Each swipe has an intended duration650 ms, then a one-second settling observation. `Engine.max_fps=60` only controls this small diagnostic's event pacing; it is not a product frame-rate result.

| Gesture case | Actual settled physical offsets | Observed geometric result |
|---|---|---|
| Original145 px distance | 162 px after one gesture | Gecko's inferred caption is within the clip. This does **not** reproduce the larger Android displacement and proves no Android fix. |
|25 px inside current caption |24 →51 →76.5 px | Gecko's inferred caption reaches y636–665 after three gestures, with no bottom-edge reserve. |
|27 px inside current caption |27 →55.5 px | After two gestures Comet begins at415.5 and Gecko ends at686. Both inferred boxes fail complete enclosure. The upper clipping is only0.5 px; whether real OCR still reads Comet is unresolved. |

All six gestures produced actual scroll-start and scroll-end signals, with zero unintended vehicle-button activations. The process completed with exit0; that means the diagnostic completed and wrote its observations, not that every candidate gesture passed a product gate. The source import also completed with exit0. No additional Native suite, renderer, emulator, or Android rerun was launched by this agent.

Commands, using this isolated directory as the project:

```sh
godot --headless --path fixture --editor --import --quit --log-file import.log
godot --headless --path fixture --script res://diagnostic.gd --log-file input-diagnostic.log
```

Both commands used private XDG data/cache directories under `native-garage-input-review` and `GODOT_SILENCE_ROOT_WARNING=1`. The exact fixture and original output are archived beside this document. The runtime source and accepted Native pin remain unchanged. A real API35 diagnostic, using the original APK and preserved post-action save/return assertions, must determine the final probe behavior.
