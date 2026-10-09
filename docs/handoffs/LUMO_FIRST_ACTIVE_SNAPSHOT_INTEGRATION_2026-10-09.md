# Lumo: earlier active session persistence and full viewport pause

Status: SCOPED SOURCE / LINUX GL PASS. ANDROID ACCEPTANCE PENDING. VISUAL_GAP / NOT FINISHED.

BASE Godot: 3f9ff57b15e27b373e4baf696c43af3fa0ef9ca0. Immediate parent: abbc5cbb74b9222cb0479383f4a1f87b72efc8e1 (PR33, tree a4895e1b0e9a2ded123cd030fcadfabaa6d04884). The RESULT commit is the commit containing this handoff; resolve its current branch ref rather than recycling a historical SHA. Owning branch: codex/lumo-modal-viewport-repair-2026-10-09. Root is the sole publisher; active 3f9/App2b sources remain preserved.

## Problem and behavior

The actual own APK1908 Android35/36 full races hit the preserved 1200s alarm while the native process was alive in lap2/2. Finish, final reward/ACK, replay and final host return were not reached. The first durable active session had elapsed5.0167; the original fresh-ready reader correctly required a new session, countdown0 and elapsed>=1. This patch attempts the first active save at elapsed1.0 and keeps subsequent five-active-second cadence. It is a measured persistence change, not a proven Android timeout or rendering cure.

Only four first-save Core hunks are grafted onto the published four-offset pause repair: one pending boolean, reset cadence on begin, first-active/save-period condition, and pending derivation on restore. The atomic save writer, elapsed/countdown calculation, driving physics, checkpoint order, result/payload/ACK/reward and graphics rebuild are preserved. Storage failure clears pending before successful write; retry remains five active seconds later. No guarantee of durability at one second under storage failure.

The pause backdrop uses four compensating offsets to cover viewport edges while preserving dialog/HUD Safe Insets, hierarchy, filter, color, visibility and input routing. This fixes bright strips observed in actual1908 pause screenshots. Fold Insets here are explicit synthetic fixtures, not physical Fold validation.

## Exact source and verification

Combined Core SHA256: 238818f2b4d999be976904a86e7adaafa6c7b1ade9275e9732f74ec047715a6e. Before adding this documentation:921 source paths,916 unselected Modal-tree paths and all other Modal hunks unchanged; four new save probes match the corrected accepted packet b550cba75699a38377b257ab3b56bf79a9f43c7d285d75aa929301b29d9cdcf8. The earlier packet5af467... embeds a superseded fault journal and must not be used.

New identical first-save controls: preserved BASE23 failures /60; candidate60/60. Combined source:41 controlled physics checks,11 normal Engine/public ScreenTouch checks,8 real temporary-path filesystem-fault checks all PASS. Manual physics controls are labeled; natural Engine proof uses no manual physics/gameplay-state injection. First durable natural CFG elapsed1/countdown0/checkpoint0/unfinished identity/empty payload, next interval5.0167 active seconds. Fault journal deep-copy fix preserves predicates and Core; rejected live-array records are retained.

Combined real softwareGL: unchanged Lap104 + Lifecycle10, FullFlow9 with16 actual gates/one reward/ACK, Countdown8, original Modal37, new Modal40 all PASS. All eight owned Engine runs strict exit0/no SCRIPT ERROR/ERROR/leak/timeout, exact921 source before/after, processes reaped. FullFlow uses actual public touch and the original driving model with explicitly manual fixed physics steps and sparse rendering; it is not a normal-time full-race video or device performance test. These are selected combined regressions, not a new complete Native24/GL17 run. The Android build must retain and execute Native24/GL17, Profile24, Finish16 and full Android1200/45 without relaxed assertions.

The new Modal40 keeps74 exact touch rows and the unchanged0.5px coverage tolerance. Original Modal37 retains6 real button drags,106 Touch/Drag inputs and14 true PNGs. White coverage calibration is diagnostic imagery, not gameplay. DesktopGL is Godot4.6.3 Compatibility on software llvmpipe; it is not target-device performance or physical Fold.

Closed combined proof:32,468,031 bytes /128 members, SHA2567bff60db21f24bcaba6c591150ba111f53339858c7171746abd3b8ef1b82ba11; raw audit5017 assertions,90 evidence files and40 true PNGs. Git-only source packet168304 bytes / SHA2567ec45e787997a99be3ab8fa68385acc64ec3fbc5a14461a33722a322cc1eede6. Root personally reviewed the four Core hunks, current full-edge inner-pause screenshot and current result screenshot. Result dialog covers the hero; this remains a visual gap.

## Current inventory and exclusions

| Area | State | Evidence / next step |
|---|---|---|
| Existing Flutter/Godot integration, meshes, shared materials, LOD, checkpoints, result/ACK | Present | Preserve exact active source and original controls |
| Own1908 Android full race completion | Confirmed failed | Both1200s alarms during living lap2/2; rebuild and evaluate new exact APK |
| Pause edge coverage | Source/GL corrected | Physical Android Fold remains pending |
| First active durable snapshot | Source/Engine corrected | No Android latency/speed promise |
| App return screenshot readiness | Draft2fea / PR224 | Reuses existing strict host readiness; exact repaired APK still pending |
| Action rival spacing experiment | HOLD / unadopted | Three player-wall regressions in identical replay despite improved rival spacing |
| Ball48-to24 rendering trial | DISCARD / unadopted | Near drawcalls292->302; measured llvmpipe GPU benefit7.43%, below frozen10% |
| Full fox/vehicle/reference fidelity and moving contours | VISUAL_GAP | Existing faceting/clipped pale rails; no new character design adopted |
| User video motion comparison | NOT EXECUTED | Referenced player provided no decoded moving frames |
| CPU/GPU/FPS on physical Android and physical Fold | NOT EXECUTED | No physical device access; softwareGL counters remain separate |

No discarded World/Action overlay, foreign full workflow, delayed QA deadline, new engine/runtime dependency, model or copied third-party code is adopted. The existing World and vehicle identity remain.

## Sources and integration

Official Godot4.6 Control: https://docs.godotengine.org/en/4.6/classes/class_control.html (parent-relative offsets). Official ConfigFile: https://docs.godotengine.org/en/4.6/classes/class_configfile.html (existing persistence API). Own existing implementation/probes adapted; no foreign implementation or license/dependency change.

After this commit is independently verified at the remote tree, retarget App readers and the explicitly synthetic lifecycle fixture to this exact Core hash and config/godot-source.json to the exact RESULT commit. Preserve historical fixtures, original24/17/Profile24/Finish16 and1200/45. Use a fresh version/build number, build once, inspect actual APK provenance, then run both Android35/36 full flows and evaluate real screenshots/video. Until those receipts close, no fixed/ready APK or complete visual-quality claim.

