# Native live-stage menu verification — 12 November 2026

## Actual production change

The landing and direct race/driver/kart/track/difficulty sections share one native 3D viewport. The existing animated original Lumo, selected kart, workshop, unlocks and saves remain in use. A single START begins the selected race; selecting a section no longer advances a mandatory five-step wizard.

The production camera fits the real chassis, rig and stage rings to the available area. The track view fits 96 points on the actual drivable curve. Layout and camera calculations operate on physical window size, density and safe insets.

## Two distinct visual issues found by actual image review

The first two CI artifacts (native heads `45d0469e0ca1741b60e34bea49f8eb58c808346f` and `1efcbb189b401212f89006203cb62bc10ff2aba0`) saved portrait-named files at 1280x720 because desktop `_ready()` reset the test window. They are **landscape evidence only**, regardless of filename. The probe now resizes after startup and asserts both window and saved image dimensions.

The second artifact also revealed an occluded garage. Frustum fitting placed the nominal camera at x=4.560 m, but the horizontal camera offset moved its actual optical origin beyond the right studio wall at x=5.7 m. A valid projected bounding box alone did not establish visibility. The shallower three-quarter camera direction keeps the optical origin inside the open side of the studio. Checks now use `get_camera_transform()` and studio mesh bounds to detect wall occlusion. Manual inspection switches clear inherited offsets immediately; rear, side and overhead camera targets now remain inside the studio walls and ceiling. A completed fit also clears any interrupted projection-transition veil. The actual renderer additionally checks lit content and orange Lumo pixels in the unobscured stage region; a blank dark viewport cannot pass.

## Evidence and limits

`docs/evidence/kart-spatial-20261112/inspection-clear-headless.log` records 192 successful logic/touch/geometry assertions at 1280x720, 412x915, 690x829 and 640x320. It is headless evidence, not a rendered screenshot or device measurement. The rendered acceptance gate requires real raster output with matching dimensions; old images must not be relabelled as new evidence.

The existing eleven-density production menu gate and real touch menu-flow gate remain required. The compact 640x320 safe-area case is separately exercised with genuine kart/workshop touches. Full-race and first-active-snapshot probes use direct native tabs and one START while preserving their save, resume, physics and reward contracts.

No physical Fold7 frame-rate result is inferred from these desktop engine checks. The Android package must separately identify and pin the exact published native revision.
