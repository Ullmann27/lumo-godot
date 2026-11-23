# Lumo World: connected first chapter

Implementation date: 23 November 2026. Source baseline: Godot integration/kart-action-20261123, commit `c9619c589e3a9faa0b56f190fb38a61bf44bb1d6`.

## Playable scope

`scenes/creative/lumo_world.tscn` is a registered native `world` entry. It starts on the actual existing Treasure Island: original terrain, nature, welcome arches, chest, lanterns, environment and original 65-bone Lumo adapter. No existing Treasure Island scene, mission or save is edited. A boardwalk leads to Sonnendorf, Sternenstadt, a garden, school, friendship park and the child's existing village region.

Movement uses acceleration, braking, smoothed turning and the original Lumo rig driven by actual post-collision velocity. Walking/running, a following collision-aware camera, landscape/portrait controls, pause and a world overview are present. All five main button rectangles are checked at 360×800, 640×360, 720×840 and 1280×720. Actual Android density, gesture behaviour and device frame rate still require device acceptance.

The original production Comet kart is enterable at the village parking place. It has steering, forward/reverse motion, braking, physical building collision and the original seated Lumo. This is a local exploration vehicle; the Kart portal opens the existing full race game. Bicycle and kick scooter are visible props in this chapter, not yet controllable vehicles. Four traffic vehicles move on the village/city road and yield at the requested pedestrian crossing.

## The child's own village

`lumo_world_village.gd` reads the existing file, with the original unmodified child key and selected village slot:

```text
user://lumo_settlement_<FULL sha256(childKey)>_<buildSlot>_village.json
```

It validates the original envelope and restores the original settlement model. Existing building IDs (strings such as `b1`, `b2`), plots, house positions, yards and resident families are used. The existing terrain, slopes, roads, regional art and building meshes are reused at an offset in the larger world. Nearby buildings have individual meshes and collision; more distant buildings are grouped by model. The projection never advances the economy/day or writes the settlement save.

The building portal opens the existing village strategy/editor on that same save. Returning reloads the projection. Economy, campaigns, troops, raid progression and editing remain in that existing mode; they do not have a second parallel simulation in World. An invalid village file is only observed and is never overwritten by this projection.

## Missions and learning

There are six ordered, deterministic missions, with authored answers rather than random rewards:

| Mission | Playable behaviour |
| --- | --- |
| Meet Nelli | Walk to her home and speak to her. |
| School crossing | Request pedestrian green, wait for traffic clearance, cross on foot. |
| Garden plan at school | Open actual Flutter Mathematics learning for the current school grade. |
| Garden delivery | Solve an authored grade 1–4 arithmetic task. |
| City parcels | Read a grade 1–4 delivery instruction. |
| Friendship picnic | Consider a friend's wishes and ask whether she wants to join. |

The social task practices a response in a particular situation. It is not an IQ, EQ, AQ or personality diagnosis. Wrong answers invite another attempt without subtracting progress.

The crossing lesson follows the Austrian government's pedestrian guidance: wait for green and attend to traffic. It is an initial supervised game situation, not a complete road-safety curriculum. Source reviewed 23 November 2026: <https://www.oesterreich.gv.at/de/themen/mobilitaet/Fussgaenger>. Vehicle-specific bicycle/scooter rules have not been introduced as lessons in this chapter.

## School bridge contract

Before opening the app's lesson, World persists an exact pending request:

```json
{
  "worldMission": {
    "version": 1,
    "id": "school_numbers",
    "requestId": "durable-unique-request-id",
    "subject": "Mathematik",
    "grade": 2,
    "returnGame": "world"
  }
}
```

`HostBridge.return_to_app("learn", payload)` carries the request. Flutter returns after three genuinely correct, persisted lesson answers with launch option `worldLearningReceipt`:

```json
{
  "version": 1,
  "requestId": "durable-unique-request-id",
  "missionId": "school_numbers",
  "completed": true,
  "subject": "Mathematik",
  "grade": 2,
  "returnGame": "world"
}
```

World checks all fields against the pending request. Missing, foreign or repeated receipts cannot advance the mission. Returning without a receipt preserves the pending mission. If the child's current school grade changes, the World startup replaces the old pending request with a new ID and current grade before consuming any returned receipt. A previous-grade receipt cannot complete the replacement. The non-embedded desktop version offers three actual arithmetic questions locally, using the same completion contract.

## Portals and return

The native `worldPortalOrigin: "world"` option records a Kart, Cards or Settlement portal entry. SceneRouter and HostBridge route the existing game's normal games/home/build exit back to World. The World position was saved before entry, so the child returns to that doorway. The `learn` destination remains an actual app lesson transition and is not intercepted. Existing games entered normally retain their normal exit behaviour.

World saves use:

```text
user://lumo_world_<first 32 characters of sha256(childKey)>.json
```

Writes use a flushed temporary file followed by rename. The mission prefix, finite bounded position and pending request are validated before restore mutates the model. A present unreadable, oversized or invalid save blocks writes, lesson receipt consumption and completion rewards; a clear return dialog lets the child leave while preserving the original bytes. A missing file starts a new World normally.

Chapter rewards use a persisted unique result ID and the existing host's idempotent reward path. Current vehicle parking is not persisted independently: reopening World restores the character location and mission state, while the exploration kart returns to its parking place.

## Art and evidence

The four new traffic prop GLBs are locally authored Blender geometry. Their generator, byte sizes and SHA-256 hashes are recorded in `assets/creative/lumo_world/vehicles/manifest.json`.

`assets/games/hub/world.webp` is composed **Blender preview art**, using the existing village houses, original Lumo, production Comet kart and treasure chest. It is not a runtime screenshot. Source hashes and attribution are recorded in `assets/creative/lumo_world/world_cover_manifest.json`. Existing original-Lumo CC BY 4.0 notices are retained. Rebuild the preview with:

```sh
blender -t 4 --background --python tools/lumo_world_art/render_world_cover.py
python tools/lumo_world_art/package_world_art.py
```

Actual runtime evidence is produced separately by the real scene capture:

```sh
LUMO_PRODUCT_SHA=<tested-commit> xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://scripts/tests/lumo_world_capture.gd -- \
  --out=/tmp/lumo-world-capture
```

It requires a real renderer and refuses headless image evidence. It creates five WebP images plus `world-capture.json`: the Treasure Island starting view, walking in Sonnendorf, portrait school view, driving the original kart and the projected existing village. It uses an isolated synthetic child profile and a valid save produced by the actual settlement model. Captures use the normal follow camera and real HUD. The report records engine, renderer, source commit, geometry/draw statistics and 60 sampled frame times per view. Those measurements describe the capture machine, not Android performance.

Focused regression commands are:

```sh
godot --headless --path . --script res://scripts/tests/lumo_world_regression.gd
godot --headless --path . --script res://scripts/tests/host_bridge_regression.gd
godot --headless --path . --script res://scripts/tests/treasure_exploration_regression.gd
```

Local results and limitations are recorded in `docs/evidence/lumo_world_20261123/verification.json`. A successful model/scene regression is not a GPU, touch-device, sound-output or 60-FPS acceptance claim. A full seamless multiplayer world, general NPC daily routines, enterable interiors and a complete traffic curriculum remain outside this first chapter.
