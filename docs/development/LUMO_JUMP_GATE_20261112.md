# Jump-gate correction after the doubled-pace integration

Base: `e28ffacaacd017731a9c2e0bddfdca251fc5aa3a`. Date: 2026-11-12.

The two reported `kart_jump_regression.gd` assertions came from obsolete test inputs and observation windows. No production jump physics, gap dimensions, gravity, checkpoints, fall threshold or rescue behavior was changed.

## Findings

The original clean-jump fixture drove for a fixed 150 frames after placing the kart before the ramp. With the new pace it legitimately crossed checkpoint **3 → 4** on frame 62 at **237.284 m**, then **4 → 5** on frame 124 at **295.662 m**. The final assertion incorrectly required it still to be at checkpoint four after 150 frames. Gate four is crossed while airborne; the subsequent fifth gate is ordinary post-landing progress.

The original slow fixture used Auto-Gas and 50% brake. Its new forward target is `41 × (1 − 0.50 × 0.94) = 21.73 m/s`, which clears the gap. It therefore did not exercise a crawl or a failed jump.

The old diagnostic run logged both assertions and nevertheless printed a final PASS because an assertion aborted only its helper. **That run was a failure. Its PASS text is not valid evidence.** The full diagnostic log is retained as `before-diagnostic-with-assertions.log`.

## Correction

The clean-jump fixture now observes the actual first landing within the existing 150-frame maximum. It still requires one take-off, one landing, no rescue, meaningful flight time, landing turbo and checkpoint four. It additionally records and requires the exact ordered gate history **[3, 4]**.

The slow fixture now holds the real GAS input and uses a brake input calculated from the current powertrain to target **8 m/s**. Explicit GAS prevents the intended brake-to-reverse behavior, so these remain physical forward pedal inputs. The test does not overwrite speed or position during the flight. It also checks the actual take-off speed, then retains the original single-fall/single-reset, post-gap placement, maximum rescue distance and road-height assertions.

PASS now requires all four check functions to finish. An aborted helper produces a nonzero exit instead of a misleading success marker.

## Verification

Godot 4.6.3, headless with dummy audio, isolated XDG directories:

- Full `kart_jump_regression.gd`: **exit 0, PASS**, all four checks completed, no assertion/runtime-error/resource-leak output.
- Clean jump: **0.77 s** airborne, **1.2 s** landing turbo, gate history **[3, 4]**, landing at **270.14 m**.
- Slow jump: actual take-off **8.00 m/s**, exactly one fall/reset, recovery at **236.0 m**, just beyond the gap ending at **233.0 m**.
- Existing rival flight and grounded starting-segment checks also completed.
- A deliberate failing clean-jump helper produced **exit 1**, **`FAIL: 3 of 4 checks completed`**, and no Jump PASS. This is a report-gate negative control, not a passing gameplay run.
- `git diff --check`: PASS.

Raw logs and the negative-control script are under `docs/evidence/kart-jump-gate-20261112/`. The full native renderer CI and Android handoff remain separate acceptance steps.
