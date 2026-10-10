"""Import the real existing GLB, inspect it, save editable .blend and roundtrip.

Run with Blender, not the system Python. No shape, face, rig or material redesign.
"""
import bpy
import hashlib
import json
from pathlib import Path
import sys

args = sys.argv[sys.argv.index("--") + 1:]
source = Path(args[0]).resolve()
output = Path(args[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert mesh_objects, "The source must contain actual 3D geometry."
triangles = 0
for obj in mesh_objects:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
report = {
    "blender_version": bpy.app.version_string,
    "source_glb": source.name,
    "source_glb_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "mesh_objects": len(mesh_objects),
    "triangles": triangles,
    "materials": len(bpy.data.materials),
    "images": len(bpy.data.images),
    "armatures": len([obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]),
    "geometry_modified": False,
    "material_fidelity_approved": False,
    "runtime_replacement": False,
    "animation_status": "Static source snapshot, not a new skeletal animation system",
}
bpy.ops.wm.save_as_mainfile(
    filepath=str(output / "lumo-comet-existing.blend"), compress=True
)
bpy.ops.export_scene.gltf(
    filepath=str(output / "lumo-comet-blender-roundtrip.glb"),
    export_format="GLB",
    export_animations=False,
)
report["roundtrip_glb_sha256"] = hashlib.sha256(
    (output / "lumo-comet-blender-roundtrip.glb").read_bytes()
).hexdigest()
(output / "blender-import-report.json").write_text(
    json.dumps(report, indent=2) + "\n", encoding="utf-8"
)
print("LUMO_BLENDER_ARCHIVE_PASS", json.dumps(report))
