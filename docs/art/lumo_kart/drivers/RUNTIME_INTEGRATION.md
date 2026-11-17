# Production rival integration

The five existing roster identities now resolve to the frozen Blender production
drivers through `scripts/games/lumo_opponent_roster.gd`. Their identity, display
name, colour, source references and availability in other games are preserved.
The existing LUMO fox actor and its adapter are not replaced by this driver rig.

## Runtime boundary

`scripts/games/kart_production_driver.gd` is a visual child of `LumoRaceKart`, at
identity transform in the shared kart coordinate system. The vehicle supplies
its real steering wheel, its two wheel-local grip points, speed, steering,
airborne state, pause, reduced motion and actual finish events. The helper never
writes vehicle transforms, speed, collisions, checkpoints, rewards or saves.

The helper supports the API used by `kart_vehicle.gd`:

| Method | Purpose |
| --- | --- |
| `bind_visual(vehicle, species)` | Load and validate the canonical imported rival; supports construction before SceneTree insertion. |
| `is_usable()` | Report whether the imported mesh, skeleton and animation player are bound. |
| `apply_vehicle_sample(speed, steer, airborne, hit, boost, drift)` | Receive existing vehicle state. Only actual airborne state selects a jump. |
| `advance_tick(delta)` | Advance the sole vehicle-owned visual clock. |
| `set_suspended(value)` | Freeze animation time and pose. |
| `set_reduced_motion(value)` | Suppress optional body motion and celebration while retaining seated posture and steering contact. |
| `celebrate_finished_race(place)` / `clear_celebration()` | Start a one-shot authored celebration and restore the current driving pose. |
| `set_visual_lod(level)` | Select an authored LOD while preserving every current bone pose. |
| `set_graphics_quality(profile)` | Apply a minimum LOD of 0 / 1 / 2 for high / medium / low. |

Only one imported skin is live per driver. PackedScene resources are cached by
path; nodes, skeletons and animation state remain separate per instance. The
helper does not enable its own `_process`. The vehicle rotates the actual wheel
first and then calls `advance_tick`, including its far-detail path.

## Clips and contact

The imported 21-bone rig retains all six existing clips: `idle`, `kart_seated`,
`kart_steer_left`, `kart_steer_right`, `kart_jump` and `celebrate`. Standing `idle`
is retained in the asset and explicitly covered by transition tests; a seated
race driver uses the other five. The rig has no authored hit, boost or drift
clip. Those inputs keep their existing vehicle effects and do not synthesize a
jump or a different physical state.

Normal clip sampling runs at 30 Hz with a bounded 100 ms visual step after a
hitch. Grip correction runs on every supplied visual tick, including ticks
between clip samples. Two analytic arm solves preserve each arm's segment
lengths and the sampled palm orientation while following the actual moving
wheel points. They only affect the arm chain. Feet retain the validated authored
seated animation.

The steering clips use the inverse of their authored sine ramp to sample the
actual continuous steering value. The first GLB key is at **1/24 second**, which
is included in this mapping; the active span is clip length minus 1/24 second.
Jump time begins on the actual grounded-to-airborne edge and does not loop to
invent repeated jumps. The grounded edge restores the seated/steering clip.

The existing three-second celebration raises both hands while stopped. During
finish coasting above 0.5 m/s, the left hand stays on the wheel. At the end of the
active clip span, both driving contacts are restored. Reduced motion suppresses
this optional celebration.

## Editor and APK import contract

All 15 production GLBs have explicit adjacent `.glb.import` settings:

```ini
animation/import=true
animation/remove_immutable_tracks=false
meshes/generate_lods=false
meshes/light_baking=0
skins/use_named_skins=true
gltf/embedded_image_handling=3
```

The first two settings preserve all 63 bone T/R/S tracks in every clip, including
constant reset tracks needed after switching from standing idle. Automatic mesh
LODs are disabled because the three authored LOD files are selected explicitly.

Godot 4.6.3 identifies image mode 3 as
`HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED`. It embeds texture data in the
imported scene and produced no extracted source PNG files in the isolated
15-scene import. It does not imply compressed texture memory on the device.

The runtime helper exclusively uses `load(path) as PackedScene` followed by
`instantiate()`. It contains no raw `GLTFDocument` fallback. The normal export
therefore consumes imported scene resources; raw GLB inclusion is not required
by the helper. These per-asset `.import` files must be committed explicitly
because the repository's general ignore pattern covers `*.import`. The two
existing original-LUMO import settings are untouched.

## Focused verification

`scripts/tests/lumo_kart_production_driver_regression.gd` tests normal editor
imports, not the separate raw-GLTF art review loader. It can be run in the full
project after the editor import:

```sh
godot --headless --path . \
  --script res://scripts/tests/lumo_kart_production_driver_regression.gd -- \
  evidence/lumo_kart_art/drivers/runtime_driver_integration.json
```

The first run used an isolated project with the same `res://` source paths and
the generated per-asset import settings. After the central editor import, the
same test was repeated in the complete game project with its real autoloads and
import cache. Both runs passed **4,016 assertions** across all **15 imported
scenes**. The shared roster regression also passed all **125 assertions** in
the full project. Driver coverage includes:

- All six clips and their 63 constant-preserving tracks.
- Standing → sitting and celebration → sitting reset transitions.
- Arbitrary steering, moving world transforms and 120 Hz between-sample contact.
- Actual flight plus simultaneous steering, followed by a real landing edge.
- Pause, reduced motion, one-shot finish celebration and finish coasting.
- Exact 21-bone pose retention across all three LODs and profile changes.
- A single live skeleton per driver and no autonomous duplicate processing.

The maximum measured hand-to-moving-grip error was **0.197317 mm**, below the
1 mm test limit. The JSON report records the source and import-setting SHA-256
values for all 15 scenes. This focused result does not replace the full product
scene, APK or physical Android performance checks owned by the integration
release process. The frozen Blender/GLB geometry and prior mesh-clearance
evidence remain unchanged.
