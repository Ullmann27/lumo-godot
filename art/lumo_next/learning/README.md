# LUMO learning asset source

The `.blend` contains editable named mesh parts, UVs, packed atlas textures, semantic empty anchors, a gallery layout and the exact Blender preview camera/lights. Run `blender -b -t 2 --python tools/lumo_next/build_learning_assets.py` from the repository to reproduce it.

## Runtime conventions

One unit is one metre. Export is glTF Y-up, X-right, Z-towards the child. Assets use a lower-centre origin except the floor module's explicit datum. See `manifest.json` for measured bounds and anchor locations. All geometry is opaque, uses UVs and requires only the exported PBR material. No Blender nodes must execute in Godot.

`count_token_teal` and `count_token_gold` each count as exactly one; `ten_bundle` contains exactly ten individually named unit meshes. `ten_frame` has ten empty receiving wells. Frames, cards, carpet, soil and scenery are not countable. Dynamic text must be supplied by the lesson; the text carriers are intentionally reusable and never contain a fixed answer.

Runtime IDs belong to lesson instances, not global screen positions. Suggested IDs: `addend_a_00`, `addend_b_00`, `ten_frame_primary/slot_0`, `tens_bundle_00`, `syllable_0`, `pattern_item_00`, `plant_root`, `plant_stem`, `plant_leaf`, `plant_flower`. Keep these IDs stable while layout transforms change. Node anchors provide local positions.

## Evidence boundary

`learning_assets_blender_overview.png` is an unretouched Blender Cycles render. It proves source production only. Godot import, live pointing, transitions and device performance need their own runtime captures and measurements. The overview contains eight teal counters in the frame and five gold counters beside it; the bundle, shapes and science objects are separate asset samples.

New work uses no external stock material or paid generation service. Read `provenance.json`.
