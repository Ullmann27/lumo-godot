# Actual Native PR acceptance on 84789d — 14 November 2026

**All eleven actual pull-request workflows completed successfully, with twelve original job logs independently read and preserved.** The actual run head is `84789d0c2c6fb4b6ecd2897ce1951b89f958b604`, tree `91cc8fc1c6f8a36336b7ac9a12585284a983a6f6`.

This archive covers those eleven PR workflows only. The new separate push workflow **43613299144** is not included in this success claim; its Discovery/Scaling/Minimap artifact and final source/index result are reviewed separately after completion. The original catalog retained here includes the then-running push workflow as context.

## Actual source identity

Each original checkout line was read. Jobs either check out the exact final head or GitHub's actual PR test merge `a77db91cc6e61d4fca8199324b644024bc29b591`. The latter commit was fetched independently: its genuine parents are `f052c2795b765265dbb6f5c27b9e92b557d39a39` and the final head; its complete tree identity is exactly `91cc8fc1c6f8a36336b7ac9a12585284a983a6f6`. This is source-tree equivalence established from Git objects, not an assumption from run labels.

| Run | Job | Actual job | Duration | Actual checkout |
| --- | --- | --- | ---: | --- |
| 43613302272 | 132502834570 | combined-godot-runtime | 49 s | a77db91c |
| 43613302244 | 132502834495 | real-native-proof (precision) | 67 s | 84789d0c |
| 43613302244 | 132502834809 | real-native-proof (bauwelt) | 81 s | 84789d0c |
| 43613302363 | 132502835054 | validated-race-event | 108 s | a77db91c |
| 43613302188 | 132502834280 | hero-flight | 103 s | 84789d0c |
| 43613302194 | 132502834314 | hero-flight | 102 s | 84789d0c |
| 43613302225 | 132502834504 | video-grade | 151 s | a77db91c |
| 43613302257 | 132502834537 | real-godot-tests | 325 s | 84789d0c |
| 43613302322 | 132502834567 | kart-stage2 | 920 s | 84789d0c |
| 43613302162 | 132502834040 | native-resonance | 98 s | a77db91c |
| 43613302179 | 132502834220 | rival-feedback | 163 s | a77db91c |
| 43613302165 | 132502834176 | nextgen-visual | 185 s | a77db91c |

The full original run catalog and individual job metadata preserve timestamps, step status and workflow identity. `review.json` records the actual workflow blob/mode, checkout line numbers and each output marker with its original log line number.

## Actual runtime evidence

The combined runtime job records original PremiumRailKit, KartTerrainExtent, twelve real Bauwelt meshes, VillageEconomy **339**, VillageScene **222**, and BuildNextgen **71** checks. The lifecycle matrix records its ten-frame precision capture and actual Bauwelt state reload, pause and four rendered frames. Other original logs contain actual Neon-Surge lifecycle/image-difference, Resonance, Rival Feedback, full-mode/race-physics, Sonnenhafen flight/aerial, and Nextgen live-Hub/menu results.

The Stunt workflow records PrecisionJump **55**, lap continuity **104**, handoff lifecycle **10**, profile lifetime **24**, actual full-race/save-resume checks and ten original precision frames. Stage2 records the real Lumo player factory both in the source and exported pack, gesture contact **200**, eleven menu configurations with cumulative **612** checks, actual save-I/O recovery, four world captures, anatomy **2,325**, face depth **23**, and the final fourteen-PNG source-bound character report.

These figures are taken from actual output, not rerun historical counts. Some workflow commands replay a marker with grep; those duplicated output lines remain in the originals and are not counted as independent invocations. The independent review found zero actual runtime/parse/assertion/engine-leak/GitHub error lines in these twelve complete job logs.

## Warnings are retained

There are **134 warning lines** across the twelve job stdout originals:

- Each of three known software-renderer capability warnings appears 42 times: V-Sync changes unsupported; screen-space AA requires Forward+ or Mobile; volumetric fog requires Forward+.
- The static project validator reports **117 PASS / 7 WARN / 0 FAIL**. Its seven warnings remain the six absent legacy catalog GLBs (`lumo_fox`, `hub_island`, `portal_learn`, `portal_games`, `portal_parent`, `star_collectible`) and non-executable `tools/build_web_bundle.sh`. This is not described as warning-free or as a physical measurement gap.
- One `Race checkpoint tmp write failed` warning occurs in the actual controlled write-failure probe, original Stage2 line **4950**. The source explicitly creates the checkpoint's `.tmp` path as a directory, checks preservation of the durable old snapshot, removes the fault and checks subsequent actual periodic-save recovery. Its original terminal marker is **FirstActiveWriteFailure: 8 checks / 0 failures**. The source blob and original context are bound in the review.

## Scope

Every log was fetched once after its job became terminal, hashed, stored unchanged and referenced by exact Git blob in the manifest. Original job stdout and metadata are distinguished from derived review files. Auxiliary screenshot artifacts have not been additionally downloaded or decoded for this review; their producer success markers remain producer evidence. The separate Discovery push artifact receives its own original-ZIP and raster-reader verification.

This archive makes no Android, physical touch, physical-device FPS or universal Original-Lumo claim. It changes no runtime, asset, workflow, central source reference or Host pin.
