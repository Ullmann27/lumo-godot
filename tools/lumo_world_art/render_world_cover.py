"""Reproducible Blender preview art, explicitly not a gameplay screenshot.

Uses the original LUMO rig, the production Comet kart and existing village
buildings/atlas. Run Blender --background --python this_file.py. The PNG is a
temporary render; package_world_art.py creates the lightweight WebP delivery.
"""
from pathlib import Path
import bpy
import math
import json
import hashlib
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/lumo_world"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
SOURCES = []


def material(name, rgb, metallic=0, roughness=0.5, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*rgb, 1)
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Emission Color"].default_value = (*rgb, 1)
    node.inputs["Emission Strength"].default_value = emission
    return mat


GRASS = material("World soft green turf", (0.25, 0.46, 0.19), roughness=0.95)
EARTH = material("Island layered earth", (0.21, 0.27, 0.22), roughness=0.9)
ROAD = material("Village asphalt", (0.095, 0.15, 0.19), roughness=0.85)
PATH = material("Warm village stone", (0.68, 0.58, 0.40), roughness=0.85)
PAINT = material("Road ivory markings", (0.9, 0.88, 0.67), roughness=0.65)
WATER = material("Treasure island turquoise water", (0.02, 0.45, 0.55), metallic=0.22, roughness=0.2)
NEON = material("Mission green light", (0.40, 1.0, 0.16), metallic=0.1, roughness=0.2, emission=2.1)
METAL = material("Mission silver rim", (0.30, 0.46, 0.49), metallic=0.7, roughness=0.25)


def box(name, at, size, mat, bevel=0.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width, mod.segments = bevel, 4
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def bounds(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        points.extend(evaluated.matrix_world @ Vector(p) for p in evaluated.bound_box)
    if not points:
        raise RuntimeError("Imported asset has no visible geometry")
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    return lo, hi


def import_asset(relative, at, width=None, height=None, angle=0, pose=None):
    path = ROOT / relative
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = set(bpy.context.scene.objects) - before
    SOURCES.append({"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    if pose:
        for obj in objects:
            if not obj.animation_data:
                continue
            for track in obj.animation_data.nla_tracks:
                track.mute = True
            action = next((a for a in bpy.data.actions if a.name == pose or a.name.startswith(pose + ".")), None)
            if action:
                obj.animation_data.action = action
        bpy.context.scene.frame_set(14)
        bpy.context.view_layer.update()
    low, high = bounds(objects)
    factor = width / (high.x - low.x) if width else height / (high.z - low.z) if height else 1
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    transform = Matrix.Translation(Vector(at)) @ Matrix.Rotation(angle, 4, "Z") @ Matrix.Scale(factor, 4) @ Matrix.Translation(-center)
    for obj in objects:
        if obj.parent not in objects:
            obj.matrix_world = transform @ obj.matrix_world
    return objects


def repair_village_materials():
    atlas = bpy.data.images.load(str(ROOT / "assets/creative/village3d/textures/village_atlas_albedo.png"), check_existing=True)
    leaves = bpy.data.images.load(str(ROOT / "assets/creative/village3d/textures/leaf_cards.png"), check_existing=True)
    for mat in bpy.data.materials:
        if not mat.name.startswith(("village_atlas", "village_foliage")):
            continue
        mat.use_nodes = True
        tree = mat.node_tree
        shader = tree.nodes.get("Principled BSDF")
        image = tree.nodes.new("ShaderNodeTexImage")
        foliage = mat.name.startswith("village_foliage")
        image.image = leaves if foliage else atlas
        image.interpolation = "Linear"
        tree.links.new(image.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.82
        if foliage:
            tree.links.new(image.outputs["Alpha"], shader.inputs["Alpha"])


def ribbon(name, points, width, z, mat):
    verts, faces = [], []
    for i, (x, y) in enumerate(points):
        a = Vector(points[max(0, i - 1)])
        b = Vector(points[min(len(points) - 1, i + 1)])
        tangent = (b - a).normalized()
        side = Vector((-tangent.y, tangent.x)) * width / 2
        verts.extend([(x + side.x, y + side.y, z), (x - side.x, y - side.y, z)])
        if i:
            faces.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# A composed miniature of the familiar island leading to its village. The
# runtime capture script separately records the actual playable world.
box("Floating island base", (0, 1, -0.85), (27, 27, 1.8), EARTH, 2.0)
box("Island turf", (0, 1, -0.03), (26.7, 26.7, 0.25), GRASS, 1.8)
box("Turquoise inlet", (-8.8, -7.7, 0.13), (7.7, 8.2, 0.1), WATER, 1.7)
box("Warm landing", (-3.2, -5.8, 0.15), (7.8, 6.5, 0.10), PATH, 0.7)
road_points = [(-1.5 + 4.2 * math.sin(i / 31 * 2.3), -11 + i / 31 * 24) for i in range(32)]
ribbon("Village road stone shoulders", road_points, 5.9, 0.15, PATH)
ribbon("Winding village road", road_points, 4.6, 0.19, ROAD)
for i in range(2, 31, 4):
    x, y = road_points[i]
    stripe = box("Road center dash", (x, y, 0.215), (0.09, 0.85, 0.018), PAINT, 0.015)
    stripe.rotation_euler.z = -math.atan2(road_points[min(i + 1, 31)][0] - road_points[max(0, i - 1)][0], 1.55)
for i in range(5):
    box("Walking crossing", (0.1 + i * 0.7, -1.2, 0.23), (0.42, 2.1, 0.018), PAINT, 0.01)

import_asset("assets/creative/village3d/models/bridge.glb", (-8.7, -4.1, 0.18), width=6.9, angle=math.pi / 2)
import_asset("assets/creative/village3d/models/house_a.glb", (-7.2, 2.7, 0.17), width=7.1, angle=0.10)
import_asset("assets/creative/village3d/models/house_b.glb", (-6.7, 9.8, 0.17), width=6.3, angle=0.10)
import_asset("assets/creative/village3d/models/school.glb", (6.9, 7.1, 0.17), width=8.9, angle=-0.15)
import_asset("assets/creative/village3d/models/house_c.glb", (9.1, 0.7, 0.17), width=5.1, angle=-0.15)
for i, (x, y, h) in enumerate([(-11, 8, 5.0), (-11, 2, 4.6), (-10, 11, 4.5), (0, 12, 4.6), (11.2, 11.8, 5.0), (11.5, -4.4, 4.2), (7, -9.7, 3.6), (-11.1, -9.7, 3.2)]):
    import_asset("assets/creative/village3d/models/tree_oak.glb", (x, y, 0.16), height=h, angle=i * 0.62)
for x, y in [(-5, -1.6), (-7.6, -1.1), (-9.6, -0.3), (6, 1.8), (8.3, 1.1), (11, 3.2), (-4.2, 7.7)]:
    import_asset("assets/creative/village3d/models/flowers.glb", (x, y, 0.16), height=0.55)
repair_village_materials()

# This is the user's existing hero model, posed by its authored greeting clip.
hero = import_asset("assets/characters/lumo_animated/Lumo-Animated-Mobile.glb", (-3.7, -6.0, 0.22), height=4.4, angle=0.28, pose="greeting_wave")
import_asset("assets/kart/production/karts/aurora_comet.glb", (3.1, -5.9, 0.23), width=4.4, angle=math.pi + 0.32)
import_asset("assets/creative/lumo_world/vehicles/school_bus.glb", (2.2, 4.1, 0.22), width=1.65, angle=0.18)
import_asset("assets/creative/models/lumo_treasure_chest.glb", (-7.3, -7.2, 0.2), width=2.4, angle=-0.25)
for x, y in [(-5.8, -3.1), (5.5, -1.5), (4.5, 10.3)]:
    import_asset("assets/creative/models/lumo_lantern.glb", (x, y, 0.17), height=2.25)

# A subtle destination halo matches the in-game green mission accents.
bpy.ops.mesh.primitive_torus_add(major_radius=2.25, minor_radius=0.035, major_segments=64, minor_segments=8, location=(-3.7, -6, 0.25))
bpy.context.object.name = "Mission destination halo"
bpy.context.object.data.materials.append(NEON)
for angle in [0.3, 2.1, 4.3]:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.10, location=(-3.7 + 2.2 * math.cos(angle), -6 + 2.2 * math.sin(angle), 0.8 + 0.5 * math.sin(angle)))
    bpy.context.object.data.materials.append(NEON)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 144
scene.cycles.use_denoising = False
scene.cycles.max_bounces = 6
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.11, 0.21, 0.28, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
floor = material("Deep teal gallery", (0.025, 0.085, 0.12), roughness=0.75)
box("Backdrop", (0, 0, -2.1), (200, 200, 0.1), floor, 0)
for at, energy, size, color in [((-10, -12, 22), 3600, 12, (1, 0.88, 0.66)), ((14, 6, 18), 2800, 10, (0.53, 0.84, 1)), ((1, -15, 10), 1300, 8, (0.82, 0.96, 1))]:
    bpy.ops.object.light_add(type="AREA", location=at)
    light = bpy.context.object
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add(location=(22, -31, 24))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0.1, 1.3)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 35
scene.camera = camera
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = str(OUT / "world_cover_render.png")
bpy.ops.render.render(write_still=True)
manifest = {"kind": "Blender preview artwork, not a gameplay screenshot", "blender": bpy.app.version_string, "generator": "tools/lumo_world_art/render_world_cover.py", "sources": SOURCES, "render": {"engine": "Cycles CPU", "samples": 144, "width": 1600, "height": 1000}}
(OUT / "world_cover_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("LUMO_WORLD_COVER_RENDERED " + scene.render.filepath)
