# Original Lumo in the Hub and direct Village host return

## Requirement and verified cause

Heinz's existing requirement is to use the original Lumo character, with no replacement figure or newly generated asset. Visual review of the real integration captures found that the Hub always instantiated `lumo_character.tscn`, a primitive capsule/sphere/box character with a purple hoodie. That selection was unconditional. It was neither a selected child avatar nor a failed load of the genuine model. Merely naming this node `OriginalAnimatedLumo` had not proved asset identity.

This targeted patch starts from `7d53f29e68269c21d1d5a66bdf3d488f8e886970` (tree `6f835356946d53c665cf235cd0c26071fdf643ee`). It changes two production scripts, strengthens existing tests and the existing Discovery checker, and adds one test-only identity inspector. It does not introduce or change any character asset or the shared rig adapter.

## Hub behavior

`game_hub.gd` now instantiates the same `lumo_rigged_actor.gd` used by the learning world. Its real imported resource is `res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb`, with the actual 65-bone skeleton, 9original clips and 2 bound body/facial meshes containing24,027 vertices. The existing eyelid adapter hides its eyelid mesh between blinks; the visible original body contributes21,659 vertices in these captures.

The camera fits the full authored mesh bounds, with idle-motion clearance, into the existing free Hero control. Depth-aware projection correction keeps the full figure above the controls. This adjustment runs on layout changes, not every animation frame. ReducedMotion reaches the original rig; application pause/resume preserves that preference. All 8 existing portal destinations, profile selectors and the original Back callback remain in place.

Both original Hub captures remain 1080×1920 and2400×1080, with their existing filenames and PASS marker. The actual capture asserts the imported GLB, adapter,65 bones,9 clips, bound skin resources, visible geometry, projected containment and separation from Back/profile/portal controls. It writes `hub-original-identity.json` from actual loaded objects and control rectangles. The existing 38-PNG Discovery verifier now requires this file and validates it; it also rejects missing, primitive, wrong-resource, clipped and overlaid identity records. The existing 10-probe/38-PNG contract and result-record shape remain unchanged.

The landscape original shows all 8 portals fully. The portrait original shows 6 complete cards; the last 2 continue within the existing scroll area. We do not claim all 8 are fully visible in the initial portrait viewport.

## Direct Village host return

The direct Flutter→Village entry previously had only a Village→Bauwelt return. Actual `HostBridge.is_embedded()` and its validated launch scene `settlement`/livingVillage select the new direct context. Only that context changes the existing visible return control to `‹ Spiele`, saving first and using the existing `SceneRouter.goto("games")` / HostBridge acknowledgement path. AndroidBack continues to pause. The existing Bauwelt route remains reachable through the extra `Zur Bauwelt` pause-menu button. Native Hub/Bauwelt entries retain `‹ Bauwelt`.

The VillageHost regression instantiates the production scene for both contexts. It verifies that a failed save blocks return, a JNI integer 0 acknowledgement keeps the scene and permits retry, integer 1 preserves the host session/destination, the saved child/slot state restores through the real canonical state parser, and returning does not change progress. JSON numbers are restored to the model's canonical integer form before exact snapshot comparison.

After the actual landscape, UI, plot rebuild, resident sync, camera and layout initialization, `[VillageHostReady]` reports actual values: scene_file_path, mode, living_village, save_path, slot, model plots/population, visible resident count, initialized plot-node count, save_blocked and the selected host_entry/return_scene. These are runtime values, not expected launch assertions. A ready marker alone is not a rendered Android UI result: the separately coordinated Android probe must bind this marker to its actual launched native PID, genuine screenshot and acknowledged visible return.

## Local verification

| Original or strengthened probe | Actual result | Seconds |
| --- | --- | ---: |
| Hub routes, original identity, ReducedMotion/lifecycle | PASS existing8-route marker |0.967|
| VillageHost with real scene/save/ACK/context controls | PASS original marker |1.168|
| Original rig (headless) | PASS 21 checks |0.816|
| Original HostBridge | PASS all 3 original markers |5.791|
| Original VillageScene | PASS 222 checks |5.279|
| Original VillageEconomy | PASS 337 checks |0.365|
| Discovery evidence helper | PASS 11 methods / 57 negative cases |12.634|
| Actual Hub renderer | PASS 2 original PNGs |15.176|
| Discovery image/identity replay | PASS 38 original PNGs |1.159|

The unchanged Hub was independently rejected by the new identity probe (exit 1, 1.224 s). The missing direct Village host return was reproduced before its navigation correction (exit 1, 1.018 s). The first Hub framing attempt was rejected because its conservative projected bounds crossed the Hero top by 3.45 logical pixels; the camera correction was then verified by both final layouts. No containment threshold was loosened.

The original rig probe actually contains 21 headless checks. An initial local wrapper mistakenly expected 23; its original exit 0 and untouched log were replayed with the correct exact 21-check marker. This wrapper correction changes no original test or acceptance threshold.

All successful Godot logs were checked for SCRIPT ERROR, Parse Error, ERROR, assertion failures and object/resource leaks. The final capture uses actual Godot 4.6.3 Compatibility rendering on Mesa llvmpipe in the existing isolated authenticated Xorg runner. Its renderer warnings about unavailable VSync/screen-space AA/volumetric fog are retained in the original log. These timings are not physical Android FPS results.

## Source and evidence binding

`hub-original-source-manifest.json` lists the exact changed file blobs, original PNG SHA256 hashes and actual Hub identity report. A fresh audit read all 1,391 previously byte-verified project files: none were missing; exactly the five intended pre-existing production/test paths changed. The new identity helper and two Discovery tool changes are separately hash-bound in the manifest. Shared rig, original GLB, all other runtime/asset paths and the existing 52/17, Live 9/7 and Discovery 10/38 runners are preserved.

The local project is a byte-verified materialized source directory, not a Git checkout; no local HEAD or tree is invented. The checkpoint is created from the real GitData parent/tree and exact tested file blobs. Full source-bound CI on the new final pin and the actual Android roundtrip remain required. The previous 7d53 Host run cannot certify this later source.

Only the affected 2 Hub images were rerendered. The 38-image checker replay uses these 2 plus the 36 unchanged original Learning/Wonder images from the earlier verified run. It is explicitly a compatibility replay, not a claim of 38 fresh renders. Original PNGs and complete renderer/test logs are also preserved on a separate evidence branch, with the final source commit in its archive manifest. The prior 38-image archive remains on `evidence/lumo-discovery-originals-20261114` at `e4fa9bc338f1dee29ec8706c7ddf624fddd35c22` for its original source scope.
