"""Blender-side audit of an existing character; never rewrites the input."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = Path(args.input).resolve()
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=False)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    all_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    # Blender's glTF importer creates an Icosphere for bone display. It is
    # not a node/mesh in the GLB and must not inflate runtime skinning counts.
    meshes = [obj for obj in all_meshes if not rigs or
              any(m.type == "ARMATURE" and m.object in rigs for m in obj.modifiers)]
    bounds = [obj.matrix_world @ Vector(c) for obj in meshes for c in obj.bound_box]
    low = [min(p[i] for p in bounds) for i in range(3)]
    high = [max(p[i] for p in bounds) for i in range(3)]
    triangles = 0
    unweighted = 0
    max_influences = 0
    bad_sums = 0
    mesh_rows = []
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        group_use = {}
        for vertex in obj.data.vertices:
            groups = [group for group in vertex.groups if group.weight > 1e-6]
            max_influences = max(max_influences, len(groups))
            if not groups:
                unweighted += 1
            elif abs(sum(g.weight for g in groups) - 1) > 0.002:
                bad_sums += 1
            for g in groups:
                name = obj.vertex_groups[g.group].name
                group_use[name] = group_use.get(name, 0) + 1
        mesh_rows.append({
            "name": obj.name, "vertices": len(obj.data.vertices),
            "triangles": len(obj.data.loop_triangles),
            "uv_layers": len(obj.data.uv_layers),
            "groups": group_use,
            "shape_keys": [key.name for key in obj.data.shape_keys.key_blocks]
            if obj.data.shape_keys else [],
            "modifiers": [{"type": m.type, "target": m.object.name if hasattr(m, "object") and m.object else None}
                          for m in obj.modifiers],
        })
    result = {
        "blender": bpy.app.version_string, "file": source.name,
        "sha256": digest, "bytes": source.stat().st_size,
        "triangles": triangles, "vertices": sum(len(m.data.vertices) for m in meshes),
        "bounds_min": low, "bounds_max": high,
        "mesh_objects": mesh_rows,
        "importer_display_helpers_excluded": [o.name for o in all_meshes if o not in meshes],
        "materials": [m.name for m in bpy.data.materials],
        "textures": [{"name": i.name, "size": list(i.size)}
                     for i in bpy.data.images if i.size[0]],
        "rigs": [{"name": rig.name, "bones": [{
            "name": b.name, "parent": b.parent.name if b.parent else None,
            "head": list(rig.matrix_world @ b.head_local),
            "tail": list(rig.matrix_world @ b.tail_local),
            "deform": b.use_deform,
        } for b in rig.data.bones]} for rig in rigs],
        "unweighted_vertices": unweighted, "weight_sum_errors": bad_sums,
        "max_skin_influences": max_influences,
        "animations": [{"name": a.name} for a in bpy.data.actions],
        "source_unchanged": hashlib.sha256(source.read_bytes()).hexdigest() == digest,
        "android_runtime_measured": False,
    }
    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2) + "\n")
    print("LUMO_RIG_AUDIT=" + json.dumps(result))


if __name__ == "__main__":
    main()
