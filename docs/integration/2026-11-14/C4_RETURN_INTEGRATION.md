# C4 return recovery integrated on the live Native baseline

Base commit: `d1191322989a7f20db66d4da9ba641bf6e8702ac`.
Source: PR171 at `c99fd3f387d78f44157f4a29cb8dbb707e058452`.

The three source blobs are reused exactly: the table implementation, the standalone return regression, and the producer handoff. No other gameplay, reward, scene, asset, or existing gate file is replaced.

## Independent local verification on 2026-11-14

A separate runtime copy contained the exact 1d7 runtime resources and the four d119 helper/runner files. Those runtime resources are unchanged between 1d7 and d119. The parent checkout and index were not modified. Every probe used fresh, separate XDG data/config/cache directories.

Godot: `4.6.3.stable.official.7d41c59c4`. Project import completed with exit 0 and no SCRIPT ERROR, Parse Error, or ERROR lines. Its locally retained log has SHA-256 `6bf55cb28b0c177e1a6d4c3f3b4c89f9746c7d7e74f75b319e9f62fafedca700` (139387 bytes).

| Case | Product blob | Result | Duration |
| --- | --- | --- | --- |
| Counterfactual unchanged table | `cdeb31fc6cfe30c18fc6c96afb2b1d749532c37f` | Exit 1, 20 checks, exactly 3 expected return-retry failures | 0.863 s |
| Integrated recovery | `f2ae17e7edf8ac1b2d0d72a0d477d7e1459b1458` | Exit 0, 21 checks, no engine/script errors | 0.448 s |

The difference in check count comes from checking the second recorded return request only when it exists. The failing counterfactual is deliberately retained as evidence, not presented as an accepted test.

The final probe ran through the unchanged strict `tools/run_godot_probe.py` with required marker `CONNECT_FOUR_RETURN_PASS checks=21` and a 120-second deadline. It loads the production scene and exercises its action/polling paths. Only the Android boundary is a fixture: first refusal, then acceptance. Token, stale revision, pending acknowledgement, successful-return idempotence, stable game state/geometry/layout, and absence of duplicate game/reward actions are checked.

Both complete short probe logs and the measured result JSON are stored beside this file. The product file was restored to the integrated blob after the counterfactual. These are newly executed tests in the restored environment; they do not depend on logs lost in the earlier environment failure.

## Boundaries and connection

The existing 52-mode Native runner and 17-artifact raster contract remain unchanged. The new return probe is an additional independent test; the host integration must continue to invoke it after Native import. The existing C4 two-process Dart/Native runtime probe was not rerun here because it requires the host-side coordinator. No Android device execution, full release build, renderer acceptance, or physical FPS measurement is claimed.
