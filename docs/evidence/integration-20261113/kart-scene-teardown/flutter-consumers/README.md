# Six Kart teardown consumers — frozen evidence

## Scope and source

This pack covers only `host_bridge_regression.gd`, `kart_race_bridge_regression.gd`, `kart_physics_regression.gd`, `kart_jump_regression.gd`, `kart_touch_regression.gd` and `kart_compact_selection_regression.gd`.

Original local commit: `a59dca033d1ad6afa4afbf0b51b03e04fe8c4ef9`.
Published equivalent source: `74c246d0b0af01c5d2d5438400ddd9ff3a3b0fef`.
Shared tree: `05f547fd58ccdc1002d98ff1031d4208b992b0ee`.

Only `kart_regression.gd` had an observed CI teardown failure. These six consumers had source-proven missing lifetime conditions; this pack does not claim six reproduced failing baselines. Root owns the separately tested helper and the main Kart repair.

## Change

All 12 existing Kart disposal sites now call the frozen shared `release_scene` helper and require success before their concluding gameplay PASS. Each false return emits a consumer-specific FAIL, exits with status 1 and returns from the caller. RaceBridge propagates false through all five `_drop` call sites. The three HostBridge Kart scenes are guarded separately; existing JNI ACK and Jump logic remain unchanged.

The helper observes the actual scene and current AudioStreamPlayer playbacks through WeakRefs and retains its fixed 2,000 ms real-time limit. Frozen helper blob: `03939804a22a0c7792de798676a5ef7d5338aa15`; SHA256: `63f4138d64d4bc0d9bd8f5698ad34c1b305062567197f4d28ba01c02995bf885`.

Redundant audio wait buffers are removed after confirmed release. RaceBridge retains one process frame to flush the separately queued fake Host node. Existing layout/input frames, abandoned flags, save/return logic and all 240 original static `assert`/`_check` calls are preserved exactly.

## Actual validation

Godot `4.6.3.stable.official.7d41c59c4`, existing `tools/run_godot_probe.py`, unchanged error filters and 120-second per-probe bound. Every probe uses separate XDG data/config/cache directories. Exact commands and environment paths are in `test-results.json`.

| Existing probe | Result | Duration | Scene releases | Tracked playbacks | Release times (ms) |
|---|---|---:|---:|---:|---|
| KartTouch | PASS, exit 0 | 6.415 s | 1 | 1 | 100 |
| HostBridge | PASS, exit 0 | 7.663 s | 3 | 6 | 15, 65, 67 |
| KartRaceBridge | PASS, exit 0 | 14.444 s | 5 | 9 | 189, 83, 126, 52, 140 |
| KartJump | PASS, exit 0 | 5.916 s | 1 | 2 | 69 |
| KartPhysics | PASS, exit 0 | 31.216 s | 1 | 3 | 83 |
| CompactKartSelection | PASS, exit 0; 355 checks, 6/6 cases | 30.791 s | 1 | 1 | 81 |

Total: 6/6 probes, 12 actual scene releases and 22 tracked playbacks, 96.445 seconds. No engine errors, ObjectDB leak notices or retained-resource errors. Expected HostBridge warnings from deliberately rejected synthetic reward ACKs remain in the unfiltered original logs. All seven source hashes (six consumers plus helper) match before and after every probe.

These are existing headless probes. This pack does not claim a new rendered-image review, Android acceptance or release approval.

## Files and integrity

`originals/` and `final-sources/` contain complete losslessly compressed source files. `source-before.json` and `source-after.json` retain exact Git blob and SHA256 identities. `six-consumer.patch.gz` is the full unmodified patch, including original diff context whitespace. `assertion-preservation.json` records exact original-call equality. `logs/` contains complete engine and runner stdout/stderr logs, without filtering. `initial-status.txt.gz` records the pre-existing generated-path list only; no UID files, caches, XDG state, binaries or images are included.

All gzip files use timestamp zero. `manifest.json` binds every stored object by byte count and SHA256 and also records the original decompressed byte count and SHA256. Each archived object has been decoded and compared with its original bytes. No staging, commit or ref operation was performed by this consumer agent.
