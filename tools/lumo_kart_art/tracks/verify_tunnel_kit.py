"""Independent Blender re-import and driving-clearance verification of exported GLBs."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def frame(kind, s, length):
    if "curve" in kind:
        sign = -1 if "left" in kind else 1
        a = s / 36
        p = Vector((sign * 36 * (1 - math.cos(a)), 36 * math.sin(a), 0))
        f = Vector((sign * math.sin(a), math.cos(a), 0))
    else:
        h = (-1.5 if kind == "grade_down" else 1.5) if "grade" in kind else 0
        t = s / length
        p = Vector((0, s, h * (3 * t * t - 2 * t * t * t)))
        f = Vector((0, 1, h / length * (6 * t - 6 * t * t))).normalized()
    r = f.cross(Vector((0, 0, 1))).normalized()
    return p, r, r.cross(f).normalized()


def check_asset(path, expected, kind, length, require_sockets=True):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    verts, faces, materials, triangles, nonmanifold, degenerate = [], [], set(), 0, 0, 0
    # glTF splits vertices at UV/normal/material boundaries. Weld only the
    # validation copy to measure geometric closure rather than seam duplication.
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        m = obj.data
        m.calc_loop_triangles()
        triangles += len(m.loop_triangles)
        degenerate += sum(1 for tri in m.loop_triangles if tri.area < 1e-10)
        materials.update(mat.name for mat in m.materials if mat)
        textured_slots = {i for i, mat in enumerate(m.materials) if mat and mat.use_nodes and any(n.type == "TEX_IMAGE" for n in mat.node_tree.nodes)}
        if textured_slots:
            assert len(m.uv_layers) == 1, (path.name, "ambiguous UV channels", len(m.uv_layers))
            uv = m.uv_layers.active.data
            tested_uv, collapsed_uv = 0, 0
            for tri in m.loop_triangles:
                if m.polygons[tri.polygon_index].material_index not in textured_slots:
                    continue
                a, b, c = [uv[i].uv for i in tri.loops]
                area = abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
                tested_uv += 1
                collapsed_uv += area < 1e-10
            assert tested_uv and collapsed_uv / tested_uv < 0.02, (path.name, "collapsed textured UVs", collapsed_uv, tested_uv)
        offset = len(verts)
        verts.extend(obj.matrix_world @ v.co for v in m.vertices)
        faces.extend(tuple(offset + i for i in t.vertices) for t in m.loop_triangles)
        bm = bmesh.new()
        bm.from_mesh(m)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00001)
        nonmanifold += sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
    assert triangles == expected["triangles"], (path.name, "triangle count", triangles, expected["triangles"])
    assert degenerate == 0, (path.name, "degenerate triangles", degenerate)
    assert nonmanifold == 0, (path.name, "nonmanifold welded geometry", nonmanifold)
    sockets = {o.get("lumo_socket"): o for o in bpy.context.scene.objects if o.get("lumo_socket")}
    if require_sockets:
        assert set(sockets) == {"in", "out"}, (path.name, "sockets", list(sockets))
        for label, s in (("in", 0), ("out", length)):
            desired = frame(kind, s, length)[0]
            assert (sockets[label].matrix_world.translation - desired).length < 1e-4, (path.name, label, list(sockets[label].matrix_world.translation), list(desired))
    tree = BVHTree.FromPolygons(verts, faces, all_triangles=True)
    min_side, min_roof = 100.0, 100.0
    samples = 0
    for i in range(1, 24):
        p, r, up = frame(kind, length * i / 24, length)
        for h in (0.5, 1.5, 2.52, 4.5):
            origin = p + up * h
            for sign in (-1, 1):
                hit = tree.ray_cast(origin, r * sign, 25)
                if hit[0] is not None:
                    min_side = min(min_side, hit[3])
                    assert hit[3] >= 5.9 - 0.015, (path.name, "side clearance", round(length * i / 24, 3), h, sign, hit[3])
                    assert hit[1].dot(r * sign) < 0.0001, (path.name, "inward-facing wall normal", i, h, sign)
                samples += 1
        for x in (-5.4, 0, 5.4):
            hit = tree.ray_cast(p + r * x + up * 0.1, up, 25)
            assert hit[0] is not None, (path.name, "uncovered ceiling", i, x)
            min_roof = min(min_roof, hit[3] + 0.1)
            assert hit[3] + 0.1 >= 4.5 - 0.015, (path.name, "roof clearance", i, x, hit[3] + 0.1)
            assert hit[1].dot(up) < 0.0001, (path.name, "inward-facing ceiling normal", i, x)
            samples += 1
    return dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), bytes=path.stat().st_size,
                triangles=triangles, material_count=len(materials), degenerate_triangles=degenerate,
                nonmanifold_edges_after_seam_weld=nonmanifold, clearance_rays=samples,
                measured_min_side_clearance_m=min_side, measured_min_roof_clearance_m=min_roof,
                sockets=sorted(sockets))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    manifest = json.loads((args.assets / "manifest.json").read_text())
    result = []
    for kind, desc in manifest["modules"].items():
        for suffix, expected, sockets in (("", desc["lod0"], True), ("_lod1", desc["lod1"], True), ("_collision", desc["collision"], False)):
            result.append(check_asset(args.assets / (kind + suffix + ".glb"), expected, kind, desc["length_m"], sockets))
    report = dict(status="PASS", blender=bpy.app.version_string, theme=manifest["theme"], assets=result,
                  rendered_in_game=False, physical_device_fps_verified=False)
    (args.assets / "blender_reimport_verification.json").write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_TRACK_VERIFY_PASS", manifest["theme"], len(result), flush=True)


if __name__ == "__main__":
    main()
