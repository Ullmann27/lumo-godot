# Studio 2020: integrated board, original Lumo face, renderer acceptance

This source increment starts from native `803e7a626ea6ef0aeeda9c37010e844033d3a8e3`. The corresponding host work starts from `86445f53af5d573549fc8cf03405261611f3cb7e`. It is a separate development candidate. Main, the previous Studio workflow and historical release identities are preserved.

## Product changes

- `scenes/games/connect_four_table.tscn` and `scripts/games/connect_four/connect_four_table.gd` provide the reachable native Connect Four board: actual board thickness and through-holes, animated falling/bouncing pieces, four winning rings, touch columns, pause controls and a density-aware layout. The existing Dart engine remains the rules/bot authority; the native scene does not create a second rule engine. `app_boot.gd`, `scene_router.gd` and `host_bridge.gd` connect the production scene to its separate host session.
- The shared original `LumoRiggedActor` uses the new mobile facial derivative of the existing Lumo asset. Original body vertex/index data, 65-bone skeleton and nine original animation clips are retained. The six existing Studio motion clips are retained as well. Added skinned eyelids, gaze morphs and a subtle muzzle/jaw pose provide real geometry animation.
- `learning_world.gd` connects the face to current local speech state, with mute, stop and stale-state closure. The accompanying Android host change samples the actual local PCM envelope at MediaPlayer playback position. This is amplitude-driven articulation, not a phoneme/viseme system.

- The existing Treasure title now has an opaque themed backdrop so white clouds after restoring a saved position cannot obscure its text. This is a five-line HUD-style change; quest, world, save and input logic remain unchanged. A new contrast/input probe uses the declared original saved-position fixture.

## Actual local evidence before shared CI

| Scope | Executed result | Boundary |
|---|---|---|
| Production Dart controller plus actual Godot C4 process | 170 checks, 248 observed frames, legal seven-move win, real bot move, pause and same-process reopen | File transport and test SharedPreferences; no Android Binder or disk-restart claim |
| Original Lumo facial contracts | 102 facial, 1,047 motion, 34 teacher, 21 original-rig, 5,340 learning checks passed | Local native tests, not device performance |
| Local speech Kotlin contracts | 23 envelope and 17 speech contracts passed | Compiled local contracts; full Android host compilation remains required |
| C4 visual fixture | 303 checks; four genuine PNGs at 960×540, 412×915, 960×540 and 640×360 | Read-only declared host snapshots; no rule or reward implementation |
| Face movie | 148 actual MovieMaker frames, 144 observed animation rows; eight actual scene/inspection PNGs | 24 fps is the recording cadence, not a mobile performance result |
| Treasure title contrast | Original source: four targeted failures; corrected source: 129 headless and 137 rendered checks; all 1,085 existing density checks passed | Four new original captures; compact OCR and existing portrait ellipsis remain documented limits |

The narrow C4 visual fixture checks the actual production scene. It does not replace the two-process rules test or the separate API 35/API 37 Android input/lifecycle tests in the host candidate. Its narrow layouts intentionally show the board without the standing Lumo model; desktop/wide layouts include Lumo.

## Required integration gates

The separate `.github/workflows/lumo-studio-2020.yml` retains all eight native acceptance jobs and adds the new facial and C4 captures to the existing Studio suite. Each new original image is bound to its observed sidecar. Facial evidence also retains and fully decodes the real rendered movie. Headless output cannot satisfy a rendered capture.

Only a successful run at the final native commit, followed by actual original-image review, may become the host 2020 pin/review receipt. The host must then pass full Flutter/native contracts, real Android host compilation, both Android tours, the independent creative tour, C4 Android checks and the real 2017→2020 in-place update before APK publication.

## Remaining limits

No physical Samsung Galaxy Z Fold7 is connected. Stable 60 fps, thermal behavior and physical touch latency are therefore unmeasured. The facial derivative does not provide a full mouth interior or phoneme-accurate lip movement. These changes do not constitute a complete AAA acceptance of every learning subject, every track or every other game. Original failed runs and their later corrections remain separate evidence.
