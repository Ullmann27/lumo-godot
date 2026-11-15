# Track art – measured delivery inventory

The frozen package contains **385 GLBs and 11 editable Blender sources** across eleven themes.
All 22 independent Blender re-import reports passed. The inventory check confirmed that every current GLB matches its recorded SHA-256 hash and byte size.

## Actual per-module budgets

Ranges below are triangle counts for a single module. They are not a whole-race budget or a measured frame rate. File sizes include embedded original textures.

| Theme | Full model triangles | Detail LOD triangles | Material groups, full | All 35 GLBs, MiB | Blender source, MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| `zauberwald` | 8,534–13,348 | 6,570–9,916 | 7–7 | 34.99 | 3.19 |
| `bergwelt` | 8,002–19,372 | 4,322–9,868 | 4–5 | 35.08 | 2.83 |
| `holo_city` | 10,076–14,836 | 5,944–10,084 | 4–4 | 10.44 | 0.97 |
| `crystal_canyon` | 7,460–19,372 | 4,292–9,868 | 5–5 | 36.46 | 2.78 |
| `jungle_temple` | 8,628–21,004 | 4,596–10,444 | 7–7 | 35.94 | 2.83 |
| `candy_cloud` | 5,772–10,564 | 3,704–8,140 | 5–5 | 25.71 | 2.14 |
| `volcano_night` | 6,236–15,772 | 4,420–10,324 | 5–5 | 31.22 | 2.19 |
| `winter_sprint` | 4,304–9,904 | 3,768–8,296 | 5–5 | 10.05 | 1.22 |
| `galaxy_ringway` | 12,444–18,388 | 7,912–13,636 | 5–5 | 12.20 | 1.08 |
| `desert_drift` | 11,244–19,708 | 4,860–9,436 | 5–5 | 36.84 | 2.88 |
| `learning_lab` | 10,556–15,556 | 6,464–10,804 | 5–6 | 11.83 | 1.06 |

## Geometry and verification

Each theme has the same seven shapes: entry, exit, 12 m straight, two 30° curves at 36 m radius, and smooth 12 m ascent/descent changing elevation by 1.5 m. Each shape has a full model, detail LOD, separate concave collision shell, terrain cover and terrain LOD: 35 GLBs per theme.

The independent exported-geometry checks recorded **97,405 clearance rays**, zero degenerate triangles and zero non-manifold edges after seam duplicates were welded for inspection. Sockets, actual triangle counts and UV channel validity were also checked. Sampling is evidence for the stated module envelope; it does not replace live vehicle and camera testing.

Across visible full and detail LOD modules, the lowest sampled side clearance from centerline was **5.917 m** and the lowest sampled roof clearance across the 10.8 m road was **5.242 m**. The reserved contract envelope is 11.8 m wide × 4.5 m high.

Collision proxies contain 228–456 triangles and no texture materials. Terrain covers contain 820–3,280 triangles, with terrain LODs at 820–1,312 triangles and one untextured vertex-color PBR material. All 231 pre-existing core GLBs remained byte-identical while the 154 terrain GLBs were added.

Total exported GLB size is **280.76 MiB**; all eleven packed, compressed editable sources total **23.14 MiB**. These are storage sizes, not measured runtime memory.

## Reusable evidence

- `evidence/lumo_kart_art/tracks/production_summary.json`: measured inventory plus current SHA-256 hashes for all 385 GLBs and eleven sources.
- `assets/kart/production/tracks/<theme>/blender_reimport_verification.json`: 21 independently re-imported core GLBs per theme.
- `assets/kart/production/tracks/<theme>/terrain_blender_verification.json`: 14 independently re-imported terrain GLBs per theme.
- `assets/kart/production/tracks/<theme>/manifest.json` and `terrain_manifest.json`: exact file, module, material, triangle and bounds data.
- `docs/art/lumo_kart/tracks/CONNECTION_CONTRACT.md`: axes, nested sockets, light mounts, road profile, collision and LOD rules.

## Integration boundary

The package supplies original art geometry, material maps and editable sources. Exported models contain no duplicate pavement. Final road placement, surface terrain blending, bounded interior lights, collision creation, runtime LOD selection and Android profiling belong to the main-team integration. Separate Godot review evidence is managed by the root team. This inventory makes no live-race integration, APK release or device frame-rate claim.
