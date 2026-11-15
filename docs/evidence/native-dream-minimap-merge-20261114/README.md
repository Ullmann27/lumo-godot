# Native Dream / minimap integration

This checkpoint merges the exact Dream parent `bd0712259bb64908a5649ee1999638826c9eb597` and reviewed minimap parent `6ecc560ea16202b935c4f1d32b08b93cda358e02`. Their verified common ancestor is `f052c2795b765265dbb6f5c27b9e92b557d39a39`.

## Preserved source

The Dream side changes 42 paths and the minimap side changes 22 paths from that ancestor. The changed-path intersection is empty. Every mode, type and blob in the full union was verified against the created tree `71a6ca75c3c21de70ae857d2d5c3b259c7db7f1a` (3,637 non-tree entries). This evidence is then added without altering that union.

The merge uses two real Git parents through GitData. It does not claim a command-line git merge execution. No remote branch/ref or Host pin was changed by this operation.

The final Kart source remains blob `83b3b6b548cffa2790c582e061a74e37bbfcf356`; the existing extended SafeArea test remains blob `6c58c08b8c47a7bf7c957c448b88474a984b9509`. The previous minimap red/green, independent review and display limitation remain intact under `docs/evidence/kart-minimap-safe-area-20261114/`. All Dream assets, code and evidence remain intact. The existing 52-mode runner and the separate Dream runner/workflow/verifier retain their parent blob identities.

## Actual bounded integration run

Direct Kart and safe-area dependencies did not change on the Dream side. Three LearningAtelier/environment sources loaded by the existing SafeArea probe did change, so one focused integration run was warranted. The exact changes and reviewed new visual dependencies are recorded in `dependency-review.json`.

The isolated checkout used exact Dream HEAD plus only the two tested minimap source overrides. It physically copied the prior private import cache, then ran the existing engine's asset import. Import completed successfully (5.353 seconds); its one missing UID cache warning and original log are preserved.

The same existing SafeArea test then completed on Godot `4.6.3.stable.official.7d41c59c4`:

- Started: 2026-11-14T11:29:03.473121+00:00.
- Exit 0; 380 checks, zero failures, 15 existing controls, zero captured images.
- Duration: 14.646 seconds.
- All 1,454 materialized tracked files were verified against the exact parent-plus-two-overrides before and after execution. Their inventory was unchanged.
- No script/runtime errors appeared. The same two nonfatal compatibility-renderer warnings about screen-space AA and volumetric fog are retained in the original log.

The old red run was not repeated. No full 52-mode, Dream raster, Android, performance, audio or touch-device validation is claimed by this narrow integration run. No new PNG was generated. The prior display capability restriction is retained in the minimap evidence; no new display workaround was attempted.

## Evidence

`source-preservation.json` records exact ancestry, every changed entry and the full-union verification. `manifest.json` hashes all original execution records. `run_integration.py` is the actual invocation wrapper with explicit parent and source guards. The integration source is reproducible from the two parents without changing any product/test bytes.
