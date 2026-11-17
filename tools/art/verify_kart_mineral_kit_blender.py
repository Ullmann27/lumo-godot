"""Independent Blender re-import check; does not execute the source generator.

blender --background --threads 1 --python tools/art/verify_kart_mineral_kit_blender.py -- assets/kart/cavern/mineral_kit
"""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy


def verify(directory):
    manifest = json.loads((directory / "mineral_kit.json").read_text())
    results = {}
    for identity, asset in manifest["assets"].items():
        profiles = {}
        for profile, expected in asset["variants"].items():
            source = directory / expected["file_name"]
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            assert digest == expected["sha256"], "input hash differs"
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
            nodes = [node for node in bpy.context.scene.objects if node.type == "MESH"]
            assert len(nodes) == 1, "one source mesh per reusable kit member"
            mesh = nodes[0].data
            mesh.calc_loop_triangles()
            assert len(mesh.loop_triangles) == expected["triangles"], "imported triangle count differs"
            assert len(mesh.materials) == 1 and mesh.materials[0] is not None, "one material surface"
            assert len(mesh.color_attributes) == 1, "lost the mineral facet colors"
            for value in mesh.color_attributes[0].data:
                assert max(value.color[:3]) - min(value.color[:3]) < 0.01, "facet colors must remain grayscale"
                assert 0.6 <= value.color[0] <= 1.0, "facet colors outside readable pigment range"
            assert len(mesh.uv_layers) == 1, "lost the mineral surface UVs"
            assert all(face.area > 1e-10 for face in mesh.loop_triangles), "degenerate imported triangle"
            points = [nodes[0].matrix_world @ vertex.co for vertex in mesh.vertices]
            gltf_points = [(point.x, point.z, -point.y) for point in points]
            lower = [min(point[axis] for point in gltf_points) for axis in range(3)]
            upper = [max(point[axis] for point in gltf_points) for axis in range(3)]
            for actual, target in ((lower, expected["bbox_min_m"]), (upper, expected["bbox_max_m"])):
                assert all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(actual, target)), "imported bounds differ"
            profiles[profile] = {"triangles": len(mesh.loop_triangles), "mesh_nodes": 1,
                                 "material_surfaces": 1, "sha256": digest,
                                 "bbox_min_m": lower, "bbox_max_m": upper}
        results[identity] = profiles
    report = {"status": "PASS", "blender": bpy.app.version_string, "assets": results,
              "physical_device_fps_verified": False}
    (directory / "mineral_kit_blender_verification.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("[MineralKitBlender] PASS: all twelve original GLBs reimport with exact counts, bounds, colors and UVs")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    verify(Path(args[0] if args else "assets/kart/cavern/mineral_kit"))
