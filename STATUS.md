# Combined LUMO integration / geometry CI repair

Updated: 2026-11-13. Active Native draft: PR160; Host draft: PR465.
The published Native source 90d34181 connects the current Loop, Village, Puzzle
and Studio followups. Its reported green Kart geometry job contains actual
GDScript parse/compile failures. The temporary fixture omits four existing
transitive dependencies; its last positive grep hides the failing negated
error grep. The exact old workflow block reproduces the false success locally.

The bounded fixture and strict-runner repair passes the actual clean engine
run in 9.697 seconds with all 15 unchanged product dependencies. Five focused
counterchecks and actionlint pass. The subsequent trigger-only change retains
the exact executed engine block. Fresh published CI remains mandatory. An independent final source review
found no blocker and binds the exact repaired source hashes. Original 90d job logs and a separate correction of the earlier
cce false-success interpretation are preserved under
[Auxiliary evidence](docs/evidence/integration-20261113/auxiliary-90d34181/README.md).
The 15 reported green cce workflows are not a clean complete geometry proof.
No product source is being rewritten for this CI correction.

The current Host repairs are separately published as 5d44b479, exact Tree 609c710f.
Its 157 focused methods cover final-scroll observation, SDK37.0 package selection
and the Native Python environment. Existing historical proofs, version, pins
and receipts keep their own scopes. See [CONTINUE.md](CONTINUE.md) for source
identities, original-evidence boundaries and the remaining real Android gates.
Main and producer worktrees remain protected; this integration branch does not
publish an APK or claim physical-device frame rate.

## Preserved earlier action-stage history

The following original notes describe their historical development source.
They do not establish acceptance of the current integration or its CI repair.

# LUMO Kart action and live-stage integration

Updated: 2026-11-12. Development branch: `chatgpt/lumo-action-stage-20261112`.
Review: https://github.com/Ullmann27/lumo-godot/pull/156

## Implemented

- Actual shared driving pace is doubled. The neutral Comet reaches 41 m/s instead of 20.5 m/s; steering, acceleration, braking and jump approaches use the same production powertrain.
- The compatible difficulty ID `pro` is labelled **Extrem**, with stronger opponent racecraft. It is the default for new menu setups; restored setups retain their selection.
- Sonnenhafen has two additional physical ramps. Roadside badger crews warn before throwing a lasso. Dodging, jumping, shield and turbo provide counterplay; holds last at most 0.65 s and affect rivals too.
- A fast kart falling over an open edge stays in that fall until the existing rescue. It cannot be pulled back up by the next guarded road segment.
- Kart menus share one full-screen native 3D stage. Direct race, driver, vehicle, track and difficulty sections retain the existing workshop, fourteen karts, original animated Lumo and saves. Camera fitting uses real model/road points and respects compact layouts.

## Evidence and limits

The combined player route used real touch/drag input: two laps, eight jumps and landings, two inverted loops, all sixteen checkpoints, one lasso catch, three dodges and no reset in 98.516667 simulated seconds. Six opponent fields completed all thirty two-lap drives, with 120 lasso crossings, 21 catches, no rescues, failed loops or stalls. These are engine simulation measurements, not device frame-rate measurements.

Lasso rules, production lifecycle, new ramp flights and the corrected physics fixtures have separate source-scoped logs. The new menu has 354 headless production touch/layout/road-framing assertions across four surfaces. The existing eleven-density production check exposed and drove corrections to portrait framing and the safe-area list height. The 412x915 landing font raster was separately corrected to use physical font sizes with a unit-scale parent. Actual-renderer CI is a separate required gate; headless output is not a substitute for screenshots.

Review of the first actual render artifacts revealed a capture-fixture error: the desktop scene's `_ready()` reset every requested window to 1280x720. Those earlier portrait-named PNGs therefore prove landscape rendering only. The capture now resizes after startup, checks the physical window and verifies every saved PNG's actual dimensions. The earlier artifacts remain traceable and are not presented as portrait evidence. The compact 640x320 touch/customization path now passes 181 assertions, and the complete two-lap saved-race flow passes with 16 ordered gates, two in-race reopenings and exactly one reward. Actual renders remain a required separate gate before APK delivery.

See `docs/handoffs/LUMO_COMBINED_DRIVE_20261112.md`, `docs/development/LUMO_ACTION_REVIEW_20261112.md`, `docs/development/LUMO_PACE_COMPATIBILITY_20261112.md` and `docs/evidence/kart-spatial-20261112/`.

The companion Flutter work is on `chatgpt/lumo-spielewelt-stage-20261112` in `Ullmann27/lumo-lernen`. The full Android build must pin the exact published native commit, pass its emulator/update gates and verify its signing certificate and APK digest before delivery. No physical Fold7 or sustained 60 FPS claim is made here.

Main is unchanged. This development branch is not itself an APK release.
