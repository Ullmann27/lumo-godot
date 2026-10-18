"""Independent Blender import audit for the factory's paired high/mobile outputs.

blender --background --threads 1 --python tools/ai3d/verify_blender.py -- build/ai3d/ASSET_variants.json
"""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy


def verify(manifest_path):
    manifest = json.loads(manifest_path.read_text())
    results = {}
    for profile, expected in manifest["variants"].items():
        source = manifest_path.parent / expected["file_name"]
        if source.parent.resolve() != manifest_path.parent.resolve():
            raise ValueError("Variant must be next to its manifest")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected["sha256"]:
            raise ValueError("Variant hash mismatch")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        triangles = 0
        positions = []
        for obj in meshes:
            mesh = obj.data
            mesh.calc_loop_triangles()
            triangles += len(mesh.loop_triangles)
            positions.extend(obj.matrix_world @ v.co for v in mesh.vertices)
            if any(tri.area <= 1e-10 for tri in mesh.loop_triangles):
                raise ValueError("Degenerate Blender triangle")
            if len(mesh.materials) != expected["materials"] or any(m is None for m in mesh.materials):
                raise ValueError("Lost materials")
        if triangles != expected["triangles"] or len(meshes) != 1:
            raise ValueError("Imported geometry count mismatch")
        # Blender maps glTF Y-up coordinates (x,y,z) to (x,-z,y).
        gltf_positions = [(p.x, p.z, -p.y) for p in positions]
        lower = [min(p[i] for p in gltf_positions) for i in range(3)]
        upper = [max(p[i] for p in gltf_positions) for i in range(3)]
        for actual, wanted in ((lower, expected["bbox_min_m"]), (upper, expected["bbox_max_m"])):
            if not all(math.isclose(a, b, abs_tol=1e-5) for a, b in zip(actual, wanted)):
                raise ValueError("Imported geometry bounds mismatch")
        results[profile] = {"sha256": digest, "triangles": triangles,
                            "mesh_nodes": len(meshes), "bbox_min_m": lower, "bbox_max_m": upper}
    report = {"status": "PASS", "blender": bpy.app.version_string, "variants": results,
              "physical_device_fps_verified": False}
    target = manifest_path.with_name(manifest["asset_id"] + "_blender_verification.json")
    target.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("[AI3DBlender] PASS " + json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:]
    verify(Path(arguments[0]))
