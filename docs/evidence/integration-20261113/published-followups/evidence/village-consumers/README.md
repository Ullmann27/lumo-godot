# Published Village consumer check

The three unchanged published probes were executed against the isolated combined working tree in `lumo-native-published-followups`, after the actual import gate completed with exit 0 and `errors: []`. Base HEAD and merge identity are bound in the source manifest; this is not a claim that this staged combination has already passed remote CI.

| Existing probe | Actual headless result | Duration |
| --- | --- | --- |
| build_village_economy_regression.gd | PASS, 337 checks | 0.612 s |
| build_village_art_regression.gd | 2,259 checks, 0 failures | 0.849 s |
| build_village_scene_regression.gd | PASS, 19 checks | 1.812 s |

Each probe ran through the unchanged `tools/run_godot_probe.py` with Godot 4.6.3, Dummy audio and its own XDG data/config/cache/runtime directory. Original complete engine output and runner output are retained. No SCRIPT ERROR, parse error, ERROR, assertion failure, FAIL, ObjectDB/resource/RID leak was observed. The Art probe intentionally uses its real `checks / 0 failures` terminal marker because the published probe has no textual PASS token; a clean process exit and strict error check remain mandatory.

All three probe bytes, all six inspected production modules and all three original GLBs match published source `027c2535d2d69fc56fc19d8d96490f7de5be9c37`. The 756 scoped production/asset/scene/runner/probe sources were identical before and after every run. No source, staging, commit, pin, receipt or reference was changed by this agent.

`review.json` records the actual zero-coin/refund/JSON/identity contracts and their precise limits. The new real-scene probe proves a separate village path and restart of the same child. It does not run two child profiles or seed a historic settlement file; the existing independent settlement-play probe already defines those negative identity cases and was only read here. These are headless functional and asset-structure results, not renderer or Android approval.

`manifest.json` binds this evidence pack. The large before/after source manifests are deterministically gzip-compressed; their original hashes and sizes are recorded. XDG test data/cache files and generated UID files are deliberately outside the evidence pack.
