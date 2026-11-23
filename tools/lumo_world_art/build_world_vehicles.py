"""Original LUMO World traffic props; run with Blender --background --python.

All geometry is authored by this script. No external asset/license dependency.
Forward is -Z, wheels touch Y=0 after glTF export. Vehicles are visual props;
the playable kart uses the established LUMO Kart vehicle and rig.
"""
from pathlib import Path
import bpy
import json
import math
import hashlib
import sys
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/lumo_world/vehicles"
OUT.mkdir(parents=True, exist_ok=True)


def material(name, rgb, metallic=0.0, roughness=0.4):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


PAINT = material("World turquoise enamel", (0.035, 0.55, 0.64), 0.28, 0.25)
BUS = material("Warm schoolbus yellow", (1.0, 0.61, 0.055), 0.14, 0.31)
INK = material("Graphite rubber", (0.018, 0.029, 0.045), 0.0, 0.72)
GLASS = material("Blue windshield", (0.09, 0.23, 0.34), 0.38, 0.12)
WHITE = material("Ivory trim", (0.93, 0.96, 0.94), 0.1, 0.34)
METAL = material("Brushed aluminium", (0.58, 0.69, 0.73), 0.78, 0.26)
RED = material("Warm rear lenses", (0.93, 0.10, 0.07), 0.18, 0.2)
GREEN = material("Lime bicycle frame", (0.38, 0.78, 0.09), 0.24, 0.29)


def box(name, at, dimensions, mat, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def tube(name, a, b, radius, mat, vertices=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=d.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def wheel(name, x, y, z, radius, width):
    tube(name + " tyre", (x-width/2, y, z), (x+width/2, y, z), radius, INK, 28)
    for side in [-1, 1]:
        edge = x + side*width*0.51
        tube(name + " rim", (edge, y, z), (edge + side*0.015, y, z), radius*0.56, METAL, 20)
        tube(name + " hub", (edge, y, z), (edge + side*0.04, y, z), radius*0.20, PAINT, 12)


def car():
    box("Sculpted lower body", (0, 0, 0.63), (1.65, 3.25, 0.67), PAINT, 0.2)
    box("Ivory cabin", (0, -0.1, 1.17), (1.43, 1.76, 0.71), WHITE, 0.18)
    box("Panoramic front glass", (0, -0.92, 1.27), (1.19, 0.08, 0.49), GLASS, 0.07)
    box("Rear glass", (0, 0.72, 1.26), (1.16, 0.06, 0.44), GLASS, 0.06)
    for side in [-1, 1]:
        box("Side window", (side*0.715, -0.08, 1.3), (0.035, 1.23, 0.39), GLASS, 0.04)
        box("Door handle", (side*0.84, 0.16, 0.9), (0.055, 0.25, 0.045), METAL, 0.018)
        box("Mirror", (side*0.86, -0.78, 1.13), (0.23, 0.22, 0.12), PAINT, 0.04)
        for y in [-0.96, 1.02]:
            wheel("Car wheel", side*0.79, y, 0.38, 0.38, 0.27)
        box("LED headlamp", (side*0.57, -1.62, 0.72), (0.42, 0.06, 0.13), WHITE, 0.04)
        box("Rear lamp", (side*0.61, 1.62, 0.72), (0.3, 0.05, 0.14), RED, 0.04)
    box("Front grille", (0, -1.64, 0.43), (0.95, 0.07, 0.16), INK, 0.03)
    box("Front badge", (0, -1.68, 0.68), (0.13, 0.03, 0.13), METAL, 0.03)


def bus():
    box("Bus body", (0, 0, 1.15), (2.0, 5.0, 1.7), BUS, 0.19)
    box("Rounded white roof", (0, 0, 2.04), (1.98, 4.9, 0.23), WHITE, 0.1)
    box("Large driver windscreen", (0, -2.49, 1.56), (1.67, 0.06, 0.82), GLASS, 0.08)
    for side in [-1, 1]:
        for index in range(4):
            box("Passenger window", (side*1.005, -1.66+index*1.04, 1.62), (0.045, 0.85, 0.64), GLASS, 0.06)
        box("Reflective side belt", (side*1.02, 0, 0.94), (0.035, 4.7, 0.12), WHITE, 0.01)
        for y in [-1.65, 1.63]:
            wheel("Bus wheel", side*0.98, y, 0.48, 0.48, 0.29)
        box("Bus headlight", (side*0.7, -2.52, 0.75), (0.4, 0.05, 0.18), WHITE, 0.04)
        box("Bus rear lamp", (side*0.75, 2.51, 0.79), (0.23, 0.05, 0.26), RED, 0.04)
    box("Door", (1.025, -1.58, 1.15), (0.05, 0.72, 1.49), INK, 0.02)
    box("Door window", (1.055, -1.58, 1.62), (0.025, 0.59, 0.55), GLASS, 0.02)
    box("Friendly destination panel", (0, -2.52, 2.0), (1.27, 0.04, 0.2), INK, 0.03)


def bicycle():
    for y in [-0.73, 0.73]:
        wheel("Bicycle wheel", 0, y, 0.37, 0.37, 0.075)
    a, b, c, d = (0, -0.73, 0.37), (0, 0.12, 0.37), (0, 0.22, 1.00), (0, 0.73, 0.37)
    e = (0, -0.48, 1.03)
    for p, q in [(a,e),(e,c),(c,b),(b,a),(b,d),(d,c)]:
        tube("Bicycle frame", p, q, 0.035, GREEN)
    tube("Handlebar stem", e, (0, -0.47, 1.24), 0.028, METAL)
    tube("Handlebar", (-0.3, -0.47, 1.24), (0.3, -0.47, 1.24), 0.028, METAL)
    for x in [-0.24, 0.24]:
        box("Grip", (x, -0.47, 1.24), (0.16, 0.07, 0.07), INK, 0.025)
        box("Pedal", (x, 0.12, 0.37), (0.2, 0.16, 0.035), INK, 0.012)
    box("Saddle", (0, 0.26, 1.09), (0.24, 0.38, 0.11), INK, 0.05)
    tube("Kickstand", (0.1, 0.3, 0.42), (0.27, 0.28, 0.015), 0.018, METAL)


def scooter():
    for y in [-0.47, 0.44]:
        wheel("Scooter wheel", 0, y, 0.11, 0.11, 0.07)
    box("Grip deck", (0, 0.12, 0.135), (0.22, 0.77, 0.065), PAINT, 0.035)
    box("Deck traction", (0, 0.12, 0.171), (0.16, 0.62, 0.012), INK, 0.018)
    tube("Steering column", (0, -0.47, 0.11), (0, -0.37, 1.03), 0.025, METAL)
    tube("Handlebar", (-0.26, -0.37, 1.03), (0.26, -0.37, 1.03), 0.025, PAINT)
    for x in [-0.21, 0.21]:
        box("Soft handlebar grip", (x, -0.37, 1.03), (0.14, 0.065, 0.065), INK, 0.02)
    tube("Kickstand", (0.08, 0.1, 0.13), (0.16, 0.1, 0.01), 0.012, METAL)


manifest = {"generator": "tools/lumo_world_art/build_world_vehicles.py", "source": "Original procedural Blender geometry, created for LUMO", "blender": bpy.app.version_string, "models": {}}
for name, build in [("city_car", car), ("school_bus", bus), ("city_bicycle", bicycle), ("kick_scooter", scooter)]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    build()
    # Blender -Y is glTF +Z. Rotate the authored geometry once so exported
    # fronts use Godot's -Z convention and traffic never drives backwards.
    turn = Matrix.Rotation(math.pi, 4, "Z")
    for obj in bpy.context.scene.objects:
        obj.matrix_world = turn @ obj.matrix_world
    bpy.ops.object.select_all(action="SELECT")
    output = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    data = output.read_bytes()
    if data[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB: {output}")
    manifest["models"][name] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("LUMO_WORLD_VEHICLES_READY " + json.dumps(manifest["models"]))

if "--preview" in sys.argv:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for name, at, angle in [
        ("city_car", (-2.6, 0.7, 0), -0.15),
        ("school_bus", (1.5, 0, 0), 0.12),
        ("city_bicycle", (-2.6, -2.1, 0), 0.5),
        ("kick_scooter", (-0.7, -2.6, 0), 0.35),
    ]:
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT / (name + ".glb")))
        imported = set(bpy.context.scene.objects) - before
        transform = Matrix.Translation(Vector(at)) @ Matrix.Rotation(angle, 4, "Z")
        for obj in imported:
            if obj.parent not in imported:
                obj.matrix_world = transform @ obj.matrix_world
    ground = material("Warm gallery floor", (0.50, 0.67, 0.69), 0, 0.85)
    box("Gallery plinth", (0, 0, -0.16), (11, 10, 0.3), ground, 0.2)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.54, 0.70, 0.81, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    for location, energy, size in [((1, 3, 9), 1700, 7), ((-6, -3, 5), 900, 6), ((5, -2, 6), 1100, 4)]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 0.7)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(8.2, 10.5, 8.0))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0.0, 0.6)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 11.4
    scene.camera = camera
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = str(OUT.parent / "vehicles_preview.png")
    bpy.ops.render.render(write_still=True)
