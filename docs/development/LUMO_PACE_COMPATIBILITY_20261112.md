# Doubled-pace CI corrections

Date: 2026-11-12. Local starting point: `ccf30050491acc10b3d5df76e655d52ef22db84b`, which includes the combined eight-ramp-flight fixtures. The reported remote CI source `45d0469` corresponds to local `96d2820564111b376059b5c2f1ae4d251bfeb95e`; the additional local combined-driving test commit was retained.

## Findings and changes

| Reported failure | Observed cause | Correction |
| --- | --- | --- |
| ActionCourse open-edge cloud rescue | **Production defect.** At the higher pace a falling kart reaches the end of the 30 m open section before the existing 1.15 s fall timer expires. The next closed rail moves it back inside the road and the normal ground path raises it onto the asphalt. | Preserve a begun open-edge fall until the existing cloud rescue. While falling, a later rail, regular ground contact or loop entry cannot cancel the descent. Reset clears the state and still gives the existing 6 m/s recovery and short shield. |
| SonnenhafenStunt slow loop failure | **Invalid test approach.** Starting 0.8 m before the lip at 14 m/s with no throttle now loses 0.667 m/s per physics step. The kart reached the lip at 11.333 m/s, below the unchanged 13 m/s entry requirement, so it never tested an in-loop failure. | Place the initial kart less than one physics step before the lip and calculate the small coasting allowance from the actual powertrain. The test now also checks that the actual entry momentum remains within 2 m/s of the minimum, then brakes inside the loop and retains all safe-return assertions. |
| KartPhysics blue drift after one second | **Obsolete timing fixture.** The new pace scale intentionally charges drift twice as fast. Diagnostics measured 1.0 charge at 0.5 s and 2.0 at 1.0 s; the old test asked for blue after it had already reached orange. | Derive the blue fixture's input duration from `PACE_SCALE`. The existing charge interval, blue/orange rewards and insufficient-drift rejection remain unchanged. |
| Resonance high-tier pulse | **Obsolete speed fixture.** The fixed 22 m/s no longer represents a precise crossing at the current kart/difficulty reference speed. | Obtain the reference through the same powertrain, kart factors and difficulty data used by the production scoring path. The test still requires the pulse tier, real ring consumption, usable pulse and once-per-lap keys. |

The production change is limited to the fall/rescue lifecycle in `kart_island.gd`. It does not lengthen the rescue timer or weaken a rail, loop, scoring or drift threshold.

## Measured fall and loop evidence

Before the correction, Candy Cloud reached a height of **−2.86 m** at track distance **300.26 m**, then was suddenly back at **+0.04 m** at **303.21 m**, without any reset or cloud rescue. The opening ends at **302.878 m**.

After the correction, the unchanged driving input reaches the cloud rescue after **1.48 s** including its approach. Beyond the end of the opening, its highest measured pre-rescue height is **−4.25 m**. The test additionally requires that the subsequent wall never lifts the falling kart, that rescue finishes within the existing two-second limit, and that its fall state is cleared afterward.

The corrected slow-loop fixture enters at **13.32 m/s**, fails inside the loop, returns to the main lane and does not re-enter. The full high-speed loop still reaches the top at **16.1 m** with **1.000** orientation alignment, collects 11 stars and continues into the tunnel. The precision tests still distinguish 12 m/s shortfall, the 19.6 m/s landing-zone entry and the 30 m/s overshoot; their thresholds and outcome requirements were not relaxed.

## Assertion-safe reporting

Godot assertions inside helper methods abort that helper, which allowed the old Physics test to print a final PASS afterward. Physics and ActionCourse now require every top-level check to reach its end before printing PASS. The Resonance script also checks completion of its separate deterministic-award helper. Stunt already had the equivalent five-check guard.

A deliberate negative control aborted the Physics drift helper. The inherited report gate produced **`FAIL: 22 of 23 checks completed`**, exited **1**, and emitted no Physics PASS. This intentional failure is stored separately and is not a passing gameplay test. Any CI run containing an assertion remains a failure regardless of a subsequent text marker.

## Final local validation

Godot 4.6.3, headless, dummy audio, isolated XDG directories per suite:

| Run | Result |
| --- | --- |
| `kart_physics_regression.gd` | Exit 0, PASS; all 23 checks completed, including both rail sides on all 12 tracks |
| `kart_resonance_gate_regression.gd` | Exit 0, PASS |
| `kart_action_logic_regression.gd` | Exit 0, PASS; all five original action-physics checks completed |
| `kart_stunt_logic_regression.gd` | Exit 0, PASS; all five original stunt-physics checks completed |
| Deliberate Physics report negative control | Expected exit 1, FAIL, no false PASS |
| `git diff --check` | PASS |

The four final positive logs have no assertion, script error, engine error or resource-leak warning. Raw before/after traces and the negative-control script/log are in `docs/evidence/kart-pace-compatibility-20261112/`.

The two new logic companions inherit and invoke the existing production-physics checks. They are explicitly named and logged as headless logic evidence. **The original ActionCourse and SonnenhafenStunt native-display requirements remain unchanged and must still pass in the renderer CI job.** These local results do not certify rendered appearance, an Android installation or device frame rate.
