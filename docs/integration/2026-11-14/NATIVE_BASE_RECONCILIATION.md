# Reconcile the advanced Native integration base

The merge records both `9ad09a32bcd42d21b89b2a83ceee68b1dd2bd7cf` and `0e26153f0e58cc05739e72923b4c563a4cf380b8` as parents. The latter is a single new commit above 504c8ba containing the narrow 785 HUD/17-raster source checkpoint and ten recovered evidence files.

## Resolution

Four source paths were already byte-identical: settlement singular wording, the title regression, the 52-mode runner, and its tests. Our Treasure world already contained the same HUD correction plus twelve Wisp-hook additions. Those additions remain unchanged.

The two divergent helper files required a real resolution. The 0e261 helper is stronger: it explicitly validates array shapes and requires finite, non-boolean inset values. Our earlier helper compared the inset list only by equality. Python treats `False == 0`, so a boolean value could pass where the recorded inset should be numeric zero.

That difference was independently reproduced against the earlier helper: one targeted test failed exactly at `mutation='boolean-insets'`, because rejection did not occur. The final helper is the exact published 0e261 blob `b60c3360730f0db73f91324cbaed3a8806fd141e`. Its other top-level functions and existing Face/C4/movie rules are unchanged.

The combined test blob is `575c3ab5de57ec614684263fa594ea76fe8b8edc`. All nineteen existing helper test methods, all seven existing fixture/helper functions, and the original 53 Producer mutation cases remain unchanged. Five base test methods and their mutation helper are appended. The base's different restored-state contrast/hash check is retained under a distinct name, preserving both versions. AST comparisons verified preservation before execution.

Ten recovered evidence paths are added as exact existing Git blobs. They were absent from 9ad and do not replace any current evidence. Their historical source-only/test-pending descriptions remain historical; they are not relabeled as new acceptance.

## Actual verification

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=tools:tools/tests \
  python3 -m unittest test_nextgen_runner test_studio_2020_rasters
```

**47 tests passed, exit 0: 102.552 seconds reported by unittest, 102.693 seconds elapsed for the command.** These comprise 24 helper test methods and 23 runner/workflow contract methods, with their existing subcases. Complete short success and counterfactual logs are stored beside this file; exact hashes and preservation details are in `helper-reconciliation-evidence.json`.

The isolated test copy initially lacked the exact 9ad workflow file and the expected top-level test import path. That incomplete invocation was rejected. The accepted full run used the exact `.github/workflows/lumo-nextgen-2018.yml` and `tools/validate_studio.sh` from 9ad with the documented PYTHONPATH. No test condition was removed or relaxed.

## Runtime preservation

This reconciliation changes only the raster helper, its tests, and evidence documentation. The assets, scripts, scenes and project configuration retain these exact 9ad Git identities:

| Path | Tree/blob |
| --- | --- |
| assets | `e668c92ef0e3540598a79191c61fa345a994095a` |
| scripts | `473afcf7204530a12e282fd73822e01ce601a0ec` |
| scenes | `86bc6e97e89cc2a7aa568d6d05eeef3b8b811376` |
| project.godot | `296b8b1752ebfd526aedd019907ac88efbfd0c02` |

The 52-mode roster, 17-image contract, Wisp renderer checks, C4 recovery, global live-integration runner, and all runtime/asset changes already in 9ad remain intact. The Python tests use declared synthetic fixtures; this reconciliation does not claim another actual engine/renderer run. The central branch is left for parent coordination.
