# Native landing text rasterization — 2026-11-12

## Confirmed defect

The actual renderer capture `landing-412x915.png` on native revision `460c94`
showed blurred mode, navigation and footer text. The garage capture remained
readable. The landing scaled its entire Control tree while retaining small
font raster sizes. On the 412 × 915 surface the UI scale is approximately
3.1068, followed by the viewport's inverse stretch.

## Narrow correction

`kart_spatial_landing.gd` now keeps its layout root at unit scale and applies
the UI conversion to control positions, sizes, minimum sizes, fonts and
container spacing. Mode cards receive the same scale through their existing
`apply_size` method. The layout, actions, selected-mode behavior and single
shared 3D viewport remain unchanged.

At 412 × 915, title/navigation/back fonts now use 40/43/50 logical pixels,
corresponding to approximately 13/14/16 dp after the viewport conversion.
The previous parent magnification is no longer involved in text rendering.

## Verification

The existing `kart_spatial_menu_regression.gd` still exercises physical touch,
mode selection, garage navigation, all fourteen kart choices being present,
selection of a real kart, camera clearance, track geometry, difficulty and
starting a playable race on all four surfaces:

- 1280 × 720
- 412 × 915
- 690 × 829
- 640 × 320

Additional assertions verify a unit-scale landing root, actual font raster
sizes converted back to dp, and visible landing buttons remaining at least
48 × 48 dp and within the safe area. This includes card titles, captions,
selection marks, navigation buttons, stars, settings and both footer actions.

Result: **PASS, 354 checks; renderer=headless**, process exit 0. The engine
import and probe reported no script/parse/runtime errors. `git diff --check`
also passed.

Command:

```sh
python3 tools/run_godot_probe.py --timeout 180 \
  --log /tmp/lumo-landing-raster.log --required '[SpatialMenu] PASS' -- \
  godot --headless --audio-driver Dummy --path . \
  --script scripts/tests/kart_spatial_menu_regression.gd
```

The run used isolated XDG data/config/cache directories. Its complete output
is retained in `docs/evidence/kart-landing-readability-20261112/headless.log`.
Headless evidence does not certify the final visual raster. The existing CI
renderer capture must produce the updated portrait images; no Android-device
verification or frame-rate claim is made here.
