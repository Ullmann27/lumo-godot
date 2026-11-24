#!/usr/bin/env python3
"""Read actual Godot-skinned triangles and test them against the frozen kart."""
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/lumo_kart_art/karts"))
from inspect_mechanics import evaluated_surface


def check(rows, coachwork, names, seat, seat_names):
    result = []
    for index, row in enumerate(rows):
        vertices = [Vector((p[0], -p[2], p[1])) for p in row["vertices"]]
        for key, target, labels in [("foot_faces", coachwork, names), ("leg_faces", seat, seat_names)]:
            faces = row[key]
            if not faces:
                continue
            bvh = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
            hits = target.overlap(bvh)
            touched = {}
            points = []
            for a, b in hits:
                touched[labels[a]] = touched.get(labels[a], 0) + 1
                points.extend(row["vertices"][i] for i in faces[b])
            result.append({"surface": index, "selection": key, "triangles": len(faces),
                           "intersection_pairs": len(hits), "kart_parts": touched,
                           "contact_bounds_godot": {
                               "min": [min(p[i] for p in points) for i in range(3)],
                               "max": [max(p[i] for p in points) for i in range(3)]
                           } if points else {}})
    return result


def main():
    inputs = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    source = Path(inputs[0]) if inputs else Path("/tmp/lumo-original-fit-comet.json")
    variant = inputs[1] if len(inputs) > 1 else "comet"
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"art/lumo_kart/blender/karts/aurora_{variant}.blend"))
    bpy.context.scene.frame_set(1)
    body = bpy.data.objects["Coachwork"]
    coachwork, names = evaluated_surface([o for o in body.children_recursive if o.type == "MESH"])
    seat, seat_names = evaluated_surface([bpy.data.objects["BucketSeatShell"]])
    if source.is_dir():
        candidates = []
        for item in sorted(source.glob("pose_*.json")):
            checks = check(json.loads(item.read_text()), coachwork, names, seat, seat_names)
            candidates.append({"path": str(item), "checks": checks,
                               "intersection_pairs": sum(c["intersection_pairs"] for c in checks)})
        target = ROOT / "evidence/lumo_kart_runtime/karts/original_lumo_pole_search.json"
        target.write_text(json.dumps({"kart": variant, "candidates": candidates}, indent=2) + "\n")
        print(json.dumps({"candidates": [{"pose": c["path"], "hits": c["intersection_pairs"],
                                         "parts": [r["kart_parts"] for r in c["checks"]]} for c in candidates]}))
        return
    result = check(json.loads(source.read_text()), coachwork, names, seat, seat_names)
    report = {"kart": variant, "source": str(source), "passed": all(r["intersection_pairs"] == 0 for r in result),
              "method": "Actual Godot bone-pose skinning; triangles selected by Foot/Toe or full leg influence, including transition triangles; BVH against the unchanged Blender coachwork/seat shell", "checks": result}
    target = ROOT / "evidence/lumo_kart_runtime/karts/original_lumo_surface_probe.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
