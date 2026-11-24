# LUMO 2078: Meshy drivers and the recovered World camera repair

This integration retains the nine fully rigged original Meshy drivers from
`574a10e8fb7b06fc8f9af3ff89ef28c6bd4f76d7` and adds the five previously uncommitted
camera/export files recovered from the 2078 repair workspace. Older experimental
driver binaries and generated import files were not copied over the completed rigs.

## User-visible corrections

- When a wall pushes the follow camera toward Lumo, its look-ahead decreases with
  the actual smoothed camera distance so his head and feet stay in frame.
- Near-camera world labels retain their original text and depth testing, with a
  maximum projected size of 320 by 34 dp. Physical direction boards retain their
  authored dimensions.
- The mission star remains visible with a maximum projected size of 48 dp.
- The Android export explicitly includes the production driver manifest used by
  the APK asset verification.

The recovered capture script also supports selecting named views and rejects
unknown or repeated view names. Its default still captures all eight World views.

## Focused local verification

Godot 4.6.3 completed the camera regression with **27 checks and zero failures** in
1280 by 720 at density 1, 1384 by 1400 at density 2, and 720 by 1280 at density 2.
The exact five integration files were byte-compared with the test workspace.
`camera-integration.json` records their SHA-256 values and the verification scope.

This focused run reused the earlier full World test workspace and its existing
import cache. It is a camera regression result, not an assertion that the complete
new APK or the newly combined source tree has already passed Android verification.
The delivery workflow imports and tests the actual pinned combined Godot commit,
renders all required views, checks all 27 models in the produced APK, and exercises
the installed APK before publication.

The model proof under `../drivers/meshy_rigging/` remains unchanged. The new rigs
are used by Kart and Cards; this integration does not replace the World village
residents or claim a new general-purpose NPC behaviour system.
