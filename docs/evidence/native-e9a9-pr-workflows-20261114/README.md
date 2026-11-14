# Original Native PR workflow evidence for e9a9

All eleven existing pull-request workflows on `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa` completed successfully on 2026-11-14, attempt 1. Their twelve jobs are preserved here as unmodified decoded UTF-8 original GitHub logs. No workflow was started or retried for this archive.

## Actual source binding

The Native commit tree is `1c2b5da7a4485cb8b911adcac2b567481cf902b5`. Six jobs explicitly check out e9a9. Six check out GitHub's actual PR merge `5fcb2df962602d07613dc73d661455268193ab11`; its parents are `f052c2795b765265dbb6f5c27b9e92b557d39a39` and e9a9, and its tree is exactly the same. Both original commit API responses and the complete, non-truncated 3,712-file Git tree are included under `source/`. Actual checkout log lines are identified in `review.json`.

## Completed run and job roster

| Run | Jobs | Job names | Result |
| --- | --- | --- | --- |
| 43595542896 | 132449119169 | nextgen-visual | success |
| 43595542888 | 132449119140 | video-grade | success |
| 43595542947 | 132449119154 | native-resonance | success |
| 43595542907 | 132449119188 | validated-race-event | success |
| 43595542961 | 132449119376 | hero-flight | success |
| 43595542899 | 132449119225 | rival-feedback | success |
| 43595542916 | 132449119202 | hero-flight | success |
| 43595542951 | 132449119389 | combined-godot-runtime | success |
| 43595542891 | 132449119246, 132449119363 | real-native-proof (bauwelt) / real-native-proof (precision) | success |
| 43595542924 | 132449119138 | real-godot-tests | success |
| 43595543000 | 132449119326 | kart-stage2 | success |

The last Kart Stage2 job completed at 12:50:17 UTC after 913 seconds (15:13). The stunt integration completed at 12:42:22 after 438 seconds (7:18). Every job uses original Godot 4.6.3 output.

## Original evidence and preservation

- `logs/` contains all twelve complete logs, 2,224,749 UTF-8 bytes in total.
- `metadata/runs/`, `metadata/jobs/` and `metadata/artifacts/` contain full original API response bodies for each of the eleven runs. The complete head-filtered catalog is retained as well.
- Thirteen uploaded artifact records are source/run/hash-bound in the metadata. Their binary/image payloads were not downloaded or visually reviewed for this archive.
- `review.json` records observed source identities, actual success markers with original line numbers, log digests, terminal job metadata and explicit scope limits.
- `manifest.json` records the exact byte size, SHA256 and Gitblob for every original and review file.
- `complete-originals.tar` contains those files and the manifest with unchanged member bytes. POSIX ustar member timestamps are zero for reproducibility. `archive-binding.json` gives its Gitblob, byte size, SHA256 and complete member verification.
- The archive was reconstructed and every member identity compared with its source content before upload. This is byte-preservation checking, not a new product test.

The original logs contain the expected completed gameplay/capture markers. No actual Script/Parse/engine/resource-leak error or failing result marker was found in this bounded review. Existing warnings are retained, including the static validator's `117 PASS / 7 WARN / 0 FAIL`; this is not a zero-warning claim.

## Acceptance boundary

These are fresh results for the recorded Native tree. The visual-smoke workflow is not the full 52-mode suite. This evidence does not replace the next exact Host pipeline's Native52/17, Live9/7, Discovery10/38 or Dream5/7/2 acceptance, APK checks, or direct Android Village roundtrip.

The capture counts are observations from the original successful workflow logs, not a new human visual review. No Android hardware performance, audio or frame-rate result follows from this archive. No local Godot, renderer, Android, Flutter or optional test execution occurred for its creation. No central Native/Host ref was changed.
