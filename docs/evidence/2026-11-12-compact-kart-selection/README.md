# Compact Kart selection: physical touch regression

Base: `a80457d`. Safe-area case: **640 × 320**, insets **left 16 / top 32 / right 16 / bottom 48**, density 1.

## Defect and change

The safe stage is only 240 dp tall. Tabs and the existing footer leave the selection panel 84 dp high. The 48-dp workshop row plus separation reduced the actual scroll viewport to about 30 dp, while each Kart card was 90 dp. `ensure_control_visible` could therefore never reveal a whole card; the actual Gecko tap did not change the selected Comet.

On ultra-short stages only, Workshop now shares the existing footer. Cards are 72 dp tall and the scroll viewport remains 84 dp tall. The footer keeps 52-dp actions, including the existing Resume action when present. Larger stages retain the separate workshop row and 90-dp cards. Resizing moves the existing workshop button between its two parents without replacing its signal or state. Camera, physics, kart catalog, saves and input handling are unchanged.

## Actual validation

`kart_compact_selection_regression.gd` sends actual `InputEventScreenTouch` press/release events through `Input.parse_input_event`. It checks every original kart against the scroll clip, selects Gecko, verifies the live preview kart and setup, opens the production workshop by touch, and verifies the selected kart reaches it. The cases cover 640→800→640 resizing and 640 with the production Resume action. Completion counting and accumulated errors prevent a failed assertion from printing a successful result.

- Identical test on the unmodified base: **FAIL**, Exit 1, four completed cases; Gecko remained Comet in the clipped layout. See `before.log`.
- Changed layout: **PASS**, Exit 0, **181 checks / 4 completed cases**. See `after.log`.
- Existing `kart_garage_touch_targets_regression.gd`: **PASS**, all reported controls remain at least 48 × 48 dp. See `touch-targets.log`.
- Added the new headless test to the existing `tools/validate_project.sh`; no existing test or assertion was removed or weakened.

These are headless layout/input checks, **not renderer screenshots or a passed renderer menu-flow gate**. The unchanged `kart_menu_flow_regression.gd` still requires CI rendering and must run on the integrated source.

Run:

```sh
godot --headless --script scripts/tests/kart_compact_selection_regression.gd
godot --headless --script scripts/tests/kart_garage_touch_targets_regression.gd
```
