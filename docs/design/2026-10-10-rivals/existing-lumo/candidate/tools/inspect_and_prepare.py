"""Inspect a real Meshy GLB and prepare an isolated mobile-review candidate.

Run with Blender, not ordinary Python. The source GLB is never overwritten.
The derived mesh is not a runtime replacement and has no invented rig.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def measure(objects):
    meshes = [obj for obj in objects if obj.type == "MESH"]
    bounds = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(point[axis] for point in bounds) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in bounds) for axis in range(3)))
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    return {
        "mesh_objects": len(meshes),
        "triangles": triangles,
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "uv_layers": {obj.name: len(obj.data.uv_layers) for obj in meshes},
        "materials": sorted({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material}),
        "bounds_min": list(low),
        "bounds_max": list(high),
        "dimensions": list(high - low),
        "armatures": sum(obj.type == "ARMATURE" for obj in objects),
        "shape_keys": {
            obj.name: [key.name for key in obj.data.shape_keys.key_blocks]
            for obj in meshes if obj.data.shape_keys
        },
        "animation_actions": len(bpy.data.actions),
    }, low, high


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def light(name, location, target, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    aim(obj, target)


def render_view(scene, camera, center, height, angle_degrees, destination):
    angle = math.radians(angle_degrees)
    distance = height * 2.1
    camera.location = (
        center.x + math.sin(angle) * distance,
        center.y - math.cos(angle) * distance,
        center.z + height * 0.10,
    )
    aim(camera, center)
    scene.render.filepath = str(destination)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target-triangles", type=int, default=30000)
    parser.add_argument("--render", action="store_true", help="Optional Blender renders; not needed for mesh optimization.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = Path(args.input).resolve()
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    renders = out / "renders"
    renders.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=False)
    imported = list(bpy.context.scene.objects)
    original, low, high = measure(imported)
    assert original["triangles"] > 0
    assert all(count > 0 for count in original["uv_layers"].values())
    original["textures"] = [
        {"name": image.name, "width": image.size[0], "height": image.size[1]}
        for image in bpy.data.images if image.type == "IMAGE" and image.size[0]
    ]
    original["sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
    original["bytes"] = source.stat().st_size

    center = (low + high) / 2
    height = high.z - low.z
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE" if bpy.app.version >= (5, 0, 0) else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("Lumo inspection studio")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.028, 0.043, 0.075, 1)
    background.inputs["Strength"].default_value = 0.45
    bpy.ops.mesh.primitive_plane_add(size=height * 100, location=(center.x, center.y, low.z - height * 0.004))
    floor = bpy.context.object
    floor.name = "Inspection floor - not exported"
    floor_material = bpy.data.materials.new("Inspection navy")
    floor_material.diffuse_color = (0.025, 0.045, 0.075, 1)
    floor_material.use_nodes = True
    floor_material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.025, 0.045, 0.075, 1)
    floor_material.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 1
    floor.data.materials.append(floor_material)
    camera_data = bpy.data.cameras.new("Inspection camera")
    camera = bpy.data.objects.new("Inspection camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = height * 1.19
    scene.camera = camera
    energy_scale = height * height
    light("Soft key", center + Vector((-height * 1.8, -height * 2, height * 1.8)), center, 120 * energy_scale, height * 2)
    light("Soft fill", center + Vector((height * 2, -height, height)), center, 45 * energy_scale, height * 2)
    light("Rim", center + Vector((height, height * 1.8, height * 1.8)), center, 80 * energy_scale, height * 1.5)
    for image in bpy.data.images:
        if image.type == "IMAGE" and image.size[0]:
            image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "Lumo-Meshy-Inspection.blend"))
    if args.render:
        for name, angle in [("original-front", 0), ("original-quarter", 35), ("original-side", 90), ("original-back", 180)]:
            destination = renders / f"{name}.png"
            if not destination.exists():
                render_view(scene, camera, center, height, angle, destination)

    ratio = min(1.0, args.target_triangles / original["triangles"])
    for obj in imported:
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("Review LOD - preserve original separately", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    for image in bpy.data.images:
        if image.type != "IMAGE" or not image.size[0]:
            continue
        max_side = max(image.size)
        if max_side > 1024:
            factor = 1024 / max_side
            image.scale(max(1, round(image.size[0] * factor)), max(1, round(image.size[1] * factor)))
            image.pack()
    mobile, _, _ = measure(imported)
    mobile["textures"] = [
        {"name": image.name, "width": image.size[0], "height": image.size[1]}
        for image in bpy.data.images if image.type == "IMAGE" and image.size[0]
    ]
    assert mobile["triangles"] <= args.target_triangles
    assert all(count > 0 for count in mobile["uv_layers"].values())
    assert len(mobile["materials"]) == len(original["materials"])
    bpy.ops.object.select_all(action="DESELECT")
    for obj in imported:
        obj.select_set(True)
    destination = out / "Lumo-Meshy-Mobile-30k.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_animations=False,
        export_yup=True,
    )
    mobile["sha256"] = hashlib.sha256(destination.read_bytes()).hexdigest()
    mobile["bytes"] = destination.stat().st_size
    if args.render:
        render_view(scene, camera, center, height, 0, renders / "mobile-front.png")
    result = {
        "blender": bpy.app.version_string,
        "original": original,
        "mobile_candidate": mobile,
        "source_unchanged": hashlib.sha256(source.read_bytes()).hexdigest() == original["sha256"],
        "runtime_replaced": False,
        "rig_ready": False,
        "physical_android_test": False,
        "review": "Real model renders. Mobile derivative requires visual approval and a separate animation adapter.",
    }
    (out / "blender-inspection.json").write_text(json.dumps(result, indent=2) + "\n")
    print("LUMO_MESHY_INSPECTION=" + json.dumps(result))


if __name__ == "__main__":
    main()
