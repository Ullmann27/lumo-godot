"""Render verified LUMO runtime GLBs with Blender's CPU Cycles renderer.

The imported meshes retain their product geometry. Studio cameras, lighting,
display plinths and the optional item preview loop belong only to this review.
Run: blender -b --python tools/art/render_kart_adventure.py -- --input DIR --output DIR --mode items
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("vehicles", "items", "tunnel"), required=True)
    parser.add_argument("--samples", type=int, default=96)
    parser.add_argument("--animate", action="store_true")
    parser.add_argument("--all-views", action="store_true", help="Render every individual kart as well as the fleet")
    parser.add_argument("--track-id", default="crystal_canyon")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def material(name, color, metallic=0.0, roughness=0.4):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return result


def aim(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, at, target, watts, size, color=(1.0, 1.0, 1.0)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = watts
    data.shape = "DISK"
    data.size = size
    data.color = color
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = at
    aim(light, target)
    return light


def camera(at, target, lens=52.0):
    data = bpy.data.cameras.new("LUMO_ReviewCamera")
    data.lens = lens
    data.clip_end = 4000.0
    data.dof.use_dof = False
    obj = bpy.data.objects.new("LUMO_ReviewCamera", data)
    bpy.context.collection.objects.link(obj)
    obj.location = at
    aim(obj, target)
    bpy.context.scene.camera = obj
    return obj


def setup(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.012
    scene.cycles.max_bounces = 7
    scene.cycles.diffuse_bounces = 4
    scene.cycles.glossy_bounces = 4
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.fps = 12
    scene.world = bpy.data.worlds.new("LUMO_StudioWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.065, 0.10, 0.17, 1.0)
    background.inputs["Strength"].default_value = 0.4
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.25
    return scene


def import_asset(path, name, normalize=True):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = set(bpy.data.objects) - before
    assert any(obj.type == "MESH" for obj in objects), f"No geometry in {path}"
    group = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(group)
    group["source_glb"] = path.name
    group["source_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    group["geometry_source"] = "LUMO Kart runtime export"
    for obj in objects:
        if obj.parent not in objects:
            obj.parent = group
    bpy.context.view_layer.update()
    if normalize:
        bounds = [obj.matrix_world @ Vector(corner)
                  for obj in objects if obj.type == "MESH" for corner in obj.bound_box]
        minimum = Vector(tuple(min(v[i] for v in bounds) for i in range(3)))
        maximum = Vector(tuple(max(v[i] for v in bounds) for i in range(3)))
        group.location = (-(minimum.x + maximum.x) * 0.5,
                          -(minimum.y + maximum.y) * 0.5, -minimum.z)
    return group, objects


def visibility(objects, visible):
    for obj in objects:
        obj.hide_render = not visible


def ground():
    bpy.ops.mesh.primitive_plane_add(size=200.0, location=(0.0, 0.0, -0.025))
    obj = bpy.context.object
    obj.name = "LUMO_ReviewFloor"
    obj.data.materials.append(material("LUMO_StudioNavy", (0.018, 0.032, 0.058), 0.18, 0.32))


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    assert path.is_file() and path.stat().st_size > 1000
    print("LUMO_RENDER", path.name, flush=True)


def pack_and_save(path):
    for image in bpy.data.images:
        if image.source == "FILE" and not image.packed_file:
            image.pack()
    for screen in bpy.data.screens:
        for space in screen.areas:
            if space.type == "VIEW_3D":
                space.spaces.active.shading.type = "SOLID"
                space.spaces.active.shading.color_type = "MATERIAL"
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)


def vehicles(args, scene):
    ground()
    area("LUMO_KeySoftbox", (3.5, 5.2, 7.0), (0, 0, 1), 1750, 4.5)
    area("LUMO_FillSoftbox", (-4.5, 2.0, 3.6), (0, 0, 1), 1100, 5.0, (0.70, 0.85, 1.0))
    area("LUMO_RimSoftbox", (1.5, -4.0, 5.5), (0, 0, 1), 1800, 3.3, (0.65, 0.80, 1.0))
    view = camera((4.1, 6.7, 3.7), (0, 0, 1.1), 56.0)
    models = []
    for filename, title in (
        ("rabbit-glider", "LUMO_Nova_Glider"),
        ("otter-gecko_velo", "LUMO_Otter_GeckoVelo"),
        ("badger-terra", "LUMO_Dachs_Terra"),
        ("cat-phantom", "LUMO_Katze_Phantom"),
    ):
        group, objects = import_asset(args.input / (filename + ".glb"), title)
        group.rotation_euler.z = math.radians(-9)
        for _, other_objects in models:
            visibility(other_objects, False)
        if filename == "rabbit-glider" or args.all_views:
            render(scene, args.output / (title + ".png"))
        if filename == "rabbit-glider":
            view.location = (1.0, 3.1, 2.65)
            aim(view, (0.0, 0.0, 1.85))
            view.data.lens = 58
            render(scene, args.output / "LUMO_Nova_Gesicht.png")
            view.location = (4.1, 6.7, 3.7)
            aim(view, (0, 0, 1.1))
            view.data.lens = 56
        models.append((group, objects))
    for index, (group, objects) in enumerate(models):
        visibility(objects, True)
        group.location.x += (index - 1.5) * 3.6
        group.rotation_euler.z = math.radians(-12)
    scene.render.resolution_x = 2160
    scene.render.resolution_y = 1200
    view.location = (7.3, 18.0, 8.0)
    aim(view, (0, 0, 1.1))
    view.data.type = "ORTHO"
    view.data.ortho_scale = 15.8
    area("LUMO_FleetSoftbox", (0.0, 3.0, 9.0), (0, 0, 1), 2800, 10.0)
    render(scene, args.output / "LUMO_Kart_Flotte.png")
    pack_and_save(args.output / "LUMO_Kart_Werkstatt.blend")


def items(args, scene):
    ground()
    area("LUMO_ItemKey", (-3.5, -4.0, 6.0), (0, 0, 1.4), 1450, 4.0)
    area("LUMO_ItemFill", (4.0, -1.5, 3.2), (0, 0, 1.4), 950, 3.0, (0.76, 0.87, 1.0))
    area("LUMO_ItemRim", (0.0, 3.0, 5.0), (0, 0, 1.4), 1800, 4.0, (0.64, 0.79, 1.0))
    camera((0.0, -11.0, 4.6), (0, 0, 1.1), 58.0)
    groups = []
    for index, kind in enumerate(("boost", "shield", "pulse")):
        group, objects = import_asset(args.input / ("item-" + kind + ".glb"), "LUMO_Item_" + kind)
        group.location.x += (index - 1) * 2.35
        group.location.z += 0.65
        groups.append((group, group.location.copy(), objects))
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.91, depth=0.13,
                                           location=((index - 1) * 2.35, 0, 0.07))
        plinth = bpy.context.object
        plinth.name = "LUMO_ReviewPlinth_" + kind
        plinth.data.materials.append(material("LUMO_Plinth_" + kind, (0.035, 0.055, 0.088), 0.55, 0.27))
        bevel = plinth.modifiers.new("SoftDisplayEdge", "BEVEL")
        bevel.width = 0.045
        bevel.segments = 3
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    render(scene, args.output / "LUMO_Items.png")
    if args.animate:
        scene.render.resolution_x = 960
        scene.render.resolution_y = 540
        scene.cycles.samples = min(args.samples, 16)
        frame_dir = args.output / "item-frames"
        frame_dir.mkdir(parents=True, exist_ok=True)
        scene.frame_start = 1
        scene.frame_end = 48
        for frame in range(49):
            phase = frame * math.tau / 48
            for index, (group, base, _) in enumerate(groups):
                local_phase = phase + index * 0.7
                group.location.z = base.z + math.sin(local_phase * 2.0) * 0.045
                group.rotation_euler.z = math.sin(local_phase) * 0.22
                group.keyframe_insert(data_path="location", frame=frame + 1)
                group.keyframe_insert(data_path="rotation_euler", frame=frame + 1)
        for action in bpy.data.actions:
            for curve in action.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = "LINEAR"
        for frame in range(1, 49):
            scene.frame_set(frame)
            render(scene, frame_dir / f"frame-{frame:04d}.png")
        scene.frame_set(1)
    pack_and_save(args.output / "LUMO_Item_Studio.blend")


def godot_to_blender(value):
    return Vector((value[0], -value[2], value[1]))


def tunnel(args, scene):
    manifest = json.loads((args.input / "manifest-tunnel.json").read_text())
    record = next(row for row in manifest["models"] if row.get("track") == args.track_id)
    import_asset(args.input / record["file"], "LUMO_AdventureTunnel", normalize=False)
    eye = godot_to_blender(record["camera"])
    target = godot_to_blender(record["target"])
    camera(eye, target, 25.0)
    area("LUMO_PortalSoftlight", eye + Vector((0, 0, 7)), target, 3500, 9.0)
    area("LUMO_GalleryFill", target + Vector((0, 0, 3)), target - Vector((0, 0, 2)), 1800, 6.0,
         (0.65, 0.83, 1.0))
    sun_data = bpy.data.lights.new("LUMO_Daylight", "SUN")
    sun_data.energy = 2.0
    sun_data.angle = math.radians(12)
    sun = bpy.data.objects.new("LUMO_Daylight", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(25), math.radians(-24), math.radians(36))
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    render(scene, args.output / ("LUMO_Tunnel_" + args.track_id + ".png"))
    pack_and_save(args.output / ("LUMO_Tunnel_" + args.track_id + ".blend"))


def main():
    args = arguments()
    args.input = args.input.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    assert args.samples > 0
    scene = setup(args.samples)
    {"vehicles": vehicles, "items": items, "tunnel": tunnel}[args.mode](args, scene)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    report = {
        "blender": bpy.app.version_string, "renderer": "Cycles CPU", "mode": args.mode,
        "source": "verified exported LUMO runtime GLBs", "product_geometry_redesigned_in_render": False,
        "presentation": "studio lights/camera/floor; source gameplay geometry unchanged",
        "meshes_in_review_scene": len(meshes), "base_mesh_triangles_in_review_scene": triangles,
        "animation": (
            "four-second studio loop of product item geometry"
            if args.mode == "items" and args.animate else "static review"
        ),
        "files": [{"file": path.name, "bytes": path.stat().st_size,
                   "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                  for path in sorted(args.output.iterdir()) if path.suffix in (".blend", ".png")],
        "physical_android_device": False,
    }
    (args.output / ("blender-" + args.mode + "-report.json")).write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_BLENDER_PASS", json.dumps({"mode": args.mode, "meshes": len(meshes), "triangles": triangles}), flush=True)


if __name__ == "__main__":
    main()
