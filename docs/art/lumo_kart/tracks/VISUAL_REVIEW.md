# Blender track review images

The images in `evidence/lumo_kart_art/tracks/<theme>/` are actual renders of
the editable Blender geometry. No generated illustration is used as model
evidence. The preview road and neutral ground belong only to the review
scene; exported track GLBs do not contain duplicate road pavement.

`evidence/lumo_kart_art/tracks/blender_render_inventory.json` lists all
25 completed stills with actual dimensions, sample budgets, scene scope,
file size and SHA-256 hash.

## Image selection

The forest has five 1600 × 1000 views at 32 Cycles samples:
`zauberwald_portal.png`, `zauberwald_interior.png`, `zauberwald_bend.png`,
`zauberwald_rear.png` and `zauberwald_underside.png`. Portal, rear and underside
are updated after the terrain end-cap normal correction. The inner-shell
geometry shown by the interior and bend views remains unchanged.

Every other theme has a 1280 × 800 portal view at 16 samples and a
960 × 600 interior view at 8 samples. These are production review images,
with visible Monte Carlo sampling noise. The early portal views deliberately
show the structural core before its separate landscape cover was appended.
The final combined Godot captures are maintained by the root team.

| Theme | Modeled details visible in the review | Blender portal composition |
| --- | --- | --- |
| `zauberwald` | Branching root veins, mushrooms, fern leaves, seed lanterns and root-foot doorway | Core and corrected terrain cover |
| `bergwelt` | Pale dressed-stone voussoirs and mineral markers | Structural core |
| `holo_city` | Technical panels, luminous arch bands and service pylons | Structural core |
| `crystal_canyon` | Segmented stone arches and colored mineral clusters | Structural core |
| `jungle_temple` | Stone arches, climbing vines and jade beacons | Structural core |
| `candy_cloud` | Icing rings, sugar rosettes and soft portal ornaments | Structural core |
| `volcano_night` | Dark basalt columns and warm protected ember lights | Structural core |
| `winter_sprint` | Ice crystals, high ceiling icicles and snow-colored framing | Structural core |
| `galaxy_ringway` | Orbit ornaments, station cladding and technical doorway | Core and cover before the normal-only correction |
| `desert_drift` | Sandstone arches, cobalt mosaic band and oasis beacons | Core and cover before the normal-only correction |
| `learning_lab` | Molecule ornaments, laboratory panels and contrasting technical trim | Core and cover before the normal-only correction |

All eleven portal and interior image pairs were visually inspected. The
review checked identifiable theme forms, free roadway, the continuous
curved inner ceiling and side walls, and visibility from the real 2.52 m
camera height. The forest adds rear and underside inspection. These views
are supported by the exported-geometry checks; they do not constitute
Android device captures or frame-rate measurements.

## Terrain seam correction

The root team's combined Godot view exposed dark grooves at landscape module
joins. A single straight-cover probe confirmed that smoothly shaded closed
end caps were tilting the longitudinal surface normals. Flattening only the
caps reduced the mean absolute longitudinal component of the sampled edge
normals from 0.709 to 0.003, while preserving all 2,132 triangle positions,
winding and socket transforms. The source geometry was unchanged.

`evidence/lumo_kart_art/tracks/normal_probe/probe_report.json` records the
single-module comparison. `terrain_normal_correction.json` records the
authorized correction across the package: 126 cover GLBs received the
normal correction, while 28 already faceted covers remained byte-identical.
It includes before/after file hashes and identical geometry signatures; all
231 core GLBs remained byte-identical. The root team retains the actual
Godot before/after comparison. Current authoritative hashes are in
`evidence/lumo_kart_art/tracks/production_summary.json`.

The covers provide a complete separate roof volume. Their outer footprint
must still be blended into the main team's terrain heightfield. The neutral
review scene shows the module construction and does not represent a finished
landscape around a complete racing route.
