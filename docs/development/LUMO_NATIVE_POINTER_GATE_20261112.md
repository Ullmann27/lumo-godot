# Native pointer gate contract — 2026-11-12

Base: `2f1f7d69542b1934bee04a235c1dcafbf6f4d0da`.

## Confirmed CI blocker

The acceptance run at native revision `b496` still required the production
garage to navigate through the old 3D plaques. The spatial menu deliberately
hides those plaques and returns no legacy action from its picker. The failure
was an obsolete test contract, not a missing native navigation feature.

## Scoped correction

`kart_garage_3d_touch_regression.gd` now checks both explicit contracts:

- The actual production garage rejects every hidden plaque. Real events sent
  through `Input.parse_input_event` exercise preview rotation, finger ownership,
  foreign-finger release/drag rejection, cancellation, duplicate release and
  emulated/secondary mouse exclusion. Native touch and primary mouse open the
  actual track section and construct its real world preview.
- A separate instance of the retained `kart_garage_menu.gd` base runs all nine
  original projected-ray/action checks, including multi-touch, cancellation,
  drag and mouse exclusions. Their assertions have not been removed or relaxed.

Both sections must finish before the suite can print PASS. The optional
`--negative-control` test argument disables the real native track tab; both
native navigation checks must then fail even though the legacy section succeeds.

The directly following MenuDepth probe kept all 41 checks. Its first very fast
headless run printed PASS but reported pending resources at shutdown, so the
strict runner correctly returned failure. Only the post-`queue_free` settling
phase changed from two to eight frames. The final run exits cleanly.

**No production code, workflow gate, touch threshold, race logic or UI layout
was changed.** The code diff is restricted to the two test scripts above.

## Verification and raw evidence

All commands used Godot 4.6.3 with isolated XDG directories and the existing
`tools/run_godot_probe.py` watchdog/error scanner. Logs are under
`docs/evidence/kart-native-pointer-gate-20261112/`:

| Probe | Result | Raw log |
| --- | --- | --- |
| Native + retained legacy pointer contracts | PASS, 27 checks, exit 0 | `touch-positive.log` |
| Disabled actual native track button | Expected FAIL, exit 1, no PASS | `touch-negative-control.log` |
| Initial MenuDepth shutdown diagnostic | 41 checks followed by resource errors; runner rejected it | `menu-depth-before-cleanup.log` |
| MenuDepth with completed cleanup | PASS, 41 checks, exit 0 | `menu-depth-positive.log` |
| Existing Technical-Art GaragePresentation | PASS, 66 checks, exit 0, unchanged | `garage-presentation.log` |

The negative control reports exactly the expected touch and primary-mouse
navigation failures. The final positive logs contain no script/runtime or
shutdown resource errors. `git diff --check` passed.

The immediately subsequent Technical-Art entry points were also inspected:
its garage presentation already explicitly instantiates the legacy base, while
the remaining probes construct race-world or original-rig fixtures directly.
No other obsolete native-menu launch helper was identified there.

These are headless behavioral checks. Existing rendered acceptance remains
required in CI; no local screenshot or Android-device verification is claimed.
