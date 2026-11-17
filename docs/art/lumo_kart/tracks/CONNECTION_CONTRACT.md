# LUMO Kart – modular tunnel connection contract

This package supplies original editable track art. It does not change the live
race route, driving physics, terrain sampler, item behavior or existing game
core scripts. Main-team integration must follow the actual road centerline.

## Verified source references

The production checkout is based on
`9f8341494ea316c9e36ed6722915ab34b22e67bd`, branch
`integration/lumo-complete-native-20261114-7a1`. The earlier local
`6b124722f92c81b4352a222a3def701563399933` was inspected only as context.

`scripts/games/kart_world.gd` defines the existing road width as **10.8 m**.
`scripts/games/kart_visual_grade.gd` defines camera height **2.52 m**, chase
distance **4.35–4.8 m**, base vertical FOV **55°**, speed FOV **60°**, boost
FOV **68°** and base look-ahead **4.15 m**. Eleven supported theme IDs come
from `scripts/games/track_themes/track_theme_registry.gd`.

The Zauberwald palette follows the existing tree-library family: bark, warm
wood, brass, green foliage and mint bioluminescence. The existing Sonnenhafen
is retained and no Continuum assets enter this package.

## Files

For each theme `<theme>`:

- `art/lumo_kart/blender/tracks/<theme>_tunnel_workshop.blend`: editable source
  components, packed images and assembled review scene.
- `assets/kart/production/tracks/<theme>/<module>.glb`: main visible geometry.
- `assets/kart/production/tracks/<theme>/<module>_lod1.glb`: reduced decoration;
  the structural shell and socket geometry retain their exact original shape.
- `assets/kart/production/tracks/<theme>/<module>_collision.glb`: separate
  simplified closed tunnel shell, without image textures.
- `assets/kart/production/tracks/<theme>/<module>_terrain.glb`: separate
  closed landscape or architectural roof around the structural tunnel.
- `assets/kart/production/tracks/<theme>/<module>_terrain_lod1.glb`: reduced
  longitudinal terrain geometry with identical socket and end profiles.
- `assets/kart/production/tracks/<theme>/manifest.json`: actual counts, bounds,
  module properties, source and material contract.
- `assets/kart/production/tracks/<theme>/blender_reimport_verification.json`:
  independent re-import measurements and hashes, when verification passes.
- `assets/kart/production/tracks/<theme>/terrain_manifest.json` and
  `terrain_blender_verification.json`: terrain counts, bounds, hashes and
  independent re-import results, including preserved core-file hashes.
- `evidence/lumo_kart_art/tracks/<theme>/`: checked still renders and previews.

The module set is:

| Module | Centerline length | Horizontal turn | Elevation change |
| --- | ---: | ---: | ---: |
| `portal_entry` | 4 m | 0° | 0 m |
| `portal_exit` | 4 m | 0° | 0 m |
| `straight_12m` | 12 m | 0° | 0 m |
| `curve_left_30` | 18.8495559 m | left 30°, radius 36 m | 0 m |
| `curve_right_30` | 18.8495559 m | right 30°, radius 36 m | 0 m |
| `grade_down` | 12 m projected forward | 0° | −1.5 m |
| `grade_up` | 12 m projected forward | 0° | +1.5 m |

The grade modules use a cubic smoothstep height profile and horizontal entry
and exit tangents. Their maximum slope is 18.75%; the main-team roadway must
match this profile before these meshes can be used on a driving route. These
are fixed geometry assets, not arbitrary path deformation scripts.

## Landscape roof covers

Each of the same seven module names has a separate cover and cover LOD1:
**14 additional GLBs per theme**, for **35 GLBs per theme** including the
original visible models, detail LODs and collision proxies. These covers are
included in the same eleven editable `.blend` sources, under
`TERRAIN_SOURCE_<module>`, and the assembled review scene includes them.

Place a terrain cover at exactly the same root transform as its matching
tunnel module. Its `SocketIn` and `SocketOut` are identical to those of the
core. A normal section spans up to 28.4 m laterally and rises to 11.8 m above
the local road. A portal mouth transitions from a 19.4 m exterior span and
10.2 m crown to the normal cover section. See each measured bounds record
before placing it near another road, jump or landmark.

The interior of a normal cover overlaps only the outside of the structural
tunnel by 0.03 m, creating a sealed join. Portal covers flare out around the
visible doorway and root/stone/technical frame. The entire drive opening
remains hollow. The cover provides an actual solid terrain or architectural
deck, not a plane over the camera. The main team's terrain heightfield still
determines how the outer footprint blends into the surrounding landscape.

Cover materials use original per-vertex color and one PBR material, without
repeated embedded image maps. LOD1 reduces longitudinal sampling while
preserving complete end profiles. The already small 4 m portal covers retain
their minimum sampling at both LODs. The covers are visual landscape pieces;
use the existing tunnel proxy and the main team's terrain collision system.
No new collider should fill the hollow doorway.

Closed end caps use flat shading, independent of the longitudinal surface
normals. This prevents dark artificial grooves when smooth cover sections
meet. The correction retains all triangle positions, winding, socket
transforms and end profiles; it does not change the measured clearance.

## Coordinates and sockets

One unit is one meter. Blender authoring axes are **+Y forward, +Z up**. The
GLB conversion produces Godot **−Z forward, +Y up**, with +X to the right.
Each visible LOD contains named `SocketIn` and `SocketOut` nodes. The original
semantic role also survives in node extras as `lumo_socket: "in"` / `"out"`.

Place the next module using:

```gdscript
var inlet_local: Transform3D = next_module.global_transform.affine_inverse() * next_in.global_transform
next_module.global_transform = previous_out.global_transform * inlet_local.affine_inverse()
```

The first line computes the socket relative to its module root and works with
the exported nested nodes. Both socket bases face in the same direction of
travel. Do not add a 180° rotation at each connection.

Light mount nodes sit at a maximum longitudinal spacing of 6 m,
6.2 m above the road centerline. Their extras carry `lumo_light_socket`,
`light_color_srgb`, `suggested_radius_m` (8 m), and `casts_shadows` (false).
Blender prefixes/suffixes remain in their visible node names, for example
`Export_LightSocket_00.002` in Zauberwald. Match `*LightSocket*` for a name-based
lookup; the preserved semantic `lumo_light_socket` extra is the stable contract.
They are explicit mounts for controlled game lighting, not automatic live
lights. The main team should choose a bounded set of unshadowed lights or a
baked lighting solution for underground sections. The emissive lenses alone
do not imply that they illuminate other surfaces in every Godot renderer.

## Road and camera envelope

- Existing road surface: 10.8 m wide, centered on the module centerline.
- Reserved rectangular driving envelope: 11.8 m wide and 4.5 m high.
- Inner straight sidewalls: ±6.8 m.
- Spring line: 2.65 m above the centerline road surface.
- Inner crown: 7.5 m; structural ribs occupy part of the space above the
  reserved 4.5 m envelope.
- Outer shell thickness: 0.85 m; bottom surface extends below the road.
- The exported module contains no duplicate road pavement. The preview scene
  has a separately named `PreviewRoad_NotPartOfExport` demonstration surface.

The shell includes real interior walls, crown, exterior wall, underside and
closed end-ring thickness. Its intentional apertures are the road entrance
and exit. The asset never relies on a one-sided plane, hidden rear opening or
camera occlusion trick to appear enclosed.

These dimensions are unsuitable for an existing loop, jump, shortcut or
airborne stunt unless the main team separately verifies the vehicle and
camera envelope. Do not attach an underground roof to an unchanged surface
route and call that an underground tunnel. Surrounding terrain and surface
height must be reconciled with the descending and ascending road.

## Collision and LOD

The proxy is a **concave static shell**. In Godot, create a
`ConcavePolygonShape3D` from the collision mesh and attach it to a
`StaticBody3D`. A convex hull over the entire tunnel would block the driving
opening and is incorrect. Keep decorative mushrooms, lamps, leaves and roof
details out of the collision path.

Choose either the full model or its LOD1 for a given module; do not display
both at once. LOD1 retains the complete structural shell at original
resolution, so different neighboring LOD choices keep identical joint
profiles. Distances and mobile performance remain integration decisions
that require a real target-device measurement.

## Materials, UVs and editing

Each theme uses at most seven differentiated materials. The two main shell materials
have baked, original 1024 × 1024 albedo, roughness and tangent-space normal
maps. Albedo can be JPEG; data maps remain PNG. They are embedded in GLB and
packed in the `.blend`. Metric shell UVs repeat once per 2 m, giving nominal
512 texels per meter. Small solid-color detail meshes do not claim a texture
density they do not use.

The original source collections are named `SOURCE_<module>`, with individual
art components retained. `REVIEW_Assembled_Track` contains the assembled
curved demonstration. Source collections are hidden in the review scene;
enable them to edit. `COLLISION_<module>` stores the low-detail proxy.

## Reproduction

```bash
python tools/lumo_kart_art/tracks/produce_verified_tracks.py --repo .
blender -b -t 3 --python-exit-code 1 --python tools/lumo_kart_art/tracks/build_terrain_covers.py -- --repo .
python tools/lumo_kart_art/tracks/summarize_delivery.py --repo .
```

These commands rebuild all eleven core kits, independently verify them,
append and verify terrain covers, then record current file hashes. For a
single-theme rebuild, pass `--themes zauberwald` to the first two commands.
Rebuilding creates new source/export files; preserve a delivery freeze when
only producing additional evidence. Rendering an existing source does not
re-export or save the `.blend`:

```bash
blender -b -t 3 --python-exit-code 1 --python tools/lumo_kart_art/tracks/render_tunnel_review.py -- --repo . --theme zauberwald --views portal interior bend rear underside --width 1600 --height 1000 --samples 32
```

The source generator can build all eleven explicit IDs. It does not load
unrelated assets or invoke a paid provider. The verification tool re-imports
the exported GLBs, verifies actual triangle counts, stitches seam duplicates
for closure inspection, tests socket positions and ray-tests the declared
driving envelope against exported geometry. Its result does not establish
Android performance, collision behavior in the live race, or integration
into an APK.

## Provenance and license

All geometry, material design and baked maps are original work authored for
this LUMO project. No third-party asset pack, Nintendo design or generated
provider output is included. No repository-wide license file was present in
the inspected production checkout. This package does not introduce a new
public license or claim a third-party license: it is commissioned project
work for LUMO, with no externally sourced asset requiring attribution.
