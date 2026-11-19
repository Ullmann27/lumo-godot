"""Author two original LUMO garden sculptures and their editable Blender source.

blender --background --threads 2 --python tools/art/build_dream_garden.py -- --preview

The Godot axes are X right, Y up, Z forward; one unit is one metre. Sculpted
page ribbons, petal surfaces and curved stems are real mesh geometry. Preview
staging and lights are excluded from runtime exports. No provider is involved.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / "assets/dream_garden"
SOURCE = ROOT / "docs/design/dream-garden-20261114"
MATERIALS = {}


def xyz(point):
    return (point[0], -point[2], point[1])


def material(name, hexadecimal, roughness=0.65, metal=0.0, emission=0.0):
    srgb = tuple(int(hexadecimal[i:i + 2], 16) / 255 for i in (0, 2, 4))
    color = tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in srgb)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1)
    MATERIALS[name] = mat
    return mat


def palette():
    MATERIALS.clear()
    # Carry the existing atelier's teal, brass, sage and parchment palette.
    material("DreamTeal", "205663", 0.4, 0.12)
    material("DreamBrass", "c19451", 0.38, 0.55)
    material("DreamPaper", "ede6ce", 0.82)
    material("DreamLeaf", "4b8266", 0.75)
    material("DreamPetal", "e9ba96", 0.62)
    material("DreamLight", "ffe1a0", 0.4, emission=0.55)


def assign(obj, name, material_name):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS[material_name])
    return obj


def mesh_object(name, vertices, faces, material_name, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([xyz(p) for p in vertices], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, name, material_name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    return obj


def rounded_box(name, at, size, material_name, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(at))
    obj = assign(bpy.context.object, name, material_name)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Hand rounded edges", "BEVEL")
    modifier.width = min(bevel, min(size) * 0.24)
    modifier.segments = 2
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def lathe(name, profile, at, material_name, sides=24):
    vertices = []
    for height, radius in profile:
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append((at[0] + math.cos(angle) * radius, at[1] + height,
                             at[2] + math.sin(angle) * radius))
    faces = [tuple(reversed(range(sides))), tuple(range((len(profile) - 1) * sides, len(profile) * sides))]
    for ring in range(len(profile) - 1):
        for index in range(sides):
            a, b = ring * sides + index, ring * sides + (index + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    return mesh_object(name, vertices, faces, material_name, True)


def curved_stem(name, points, radius, material_name, sides=8):
    vertices = []
    for index, point in enumerate(points):
        direction = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(index - 1, 0)])
        direction.normalize()
        reference = Vector((0, 0, 1)) if abs(direction.z) < 0.8 else Vector((1, 0, 0))
        cross = direction.cross(reference).normalized()
        other = direction.cross(cross).normalized()
        for side in range(sides):
            angle = math.tau * side / sides
            value = Vector(point) + radius * (math.cos(angle) * cross + math.sin(angle) * other)
            vertices.append(tuple(value))
    faces = [tuple(reversed(range(sides))), tuple(range((len(points) - 1) * sides, len(points) * sides))]
    for index in range(len(points) - 1):
        for side in range(sides):
            a, b = index * sides + side, index * sides + (side + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    return mesh_object(name, vertices, faces, material_name, True)


def petal(name, origin, angle, length, width, lift, material_name, steps=12):
    # A double-sided closed almond surface with a raised midrib, curved tip and
    # tapered root. No alpha cards or flat primitive substitutes are used.
    vertices = []
    for underside in (False, True):
        for along in range(steps + 1):
            t = along / steps
            envelope = max(0.018, math.sin(math.pi * t) ** 0.76)
            for across in range(5):
                u = (across - 2) / 2
                radial = length * t
                lateral = width * envelope * u
                y = lift * t * t + 0.10 * math.sin(math.pi * t) * (1 - u * u)
                y -= 0.028 if underside else 0
                vertices.append((origin[0] + radial * math.cos(angle) - lateral * math.sin(angle),
                                 origin[1] + y,
                                 origin[2] + radial * math.sin(angle) + lateral * math.cos(angle)))
    faces = []
    stride = (steps + 1) * 5
    for half in (0, stride):
        for along in range(steps):
            for across in range(4):
                a = half + along * 5 + across
                quad = (a, a + 1, a + 6, a + 5)
                faces.append(tuple(reversed(quad)) if half else quad)
    perimeter = list(range(5)) + [i * 5 + 4 for i in range(1, steps + 1)]
    perimeter += list(range(steps * 5 + 3, steps * 5 - 1, -1))
    perimeter += [i * 5 for i in range(steps - 1, 0, -1)]
    for index, a in enumerate(perimeter):
        b = perimeter[(index + 1) % len(perimeter)]
        faces.append((a, a + stride, b + stride, b))
    return mesh_object(name, vertices, faces, material_name, True)


def book_sheet(name, side, elevation, material_name, length=1.18, depth=1.35):
    vertices = []
    steps = 18
    # Real curled page volume, opening from the gutter into a broad readable arc.
    for underside in (False, True):
        for index in range(steps + 1):
            t = index / steps
            y = elevation + 0.20 * math.sin(math.pi * t * 0.85) + 0.15 * t
            y -= 0.025 if underside else 0
            for z in (-depth / 2, depth / 2):
                vertices.append((side * (0.03 + t * length), y, z))
    stride = (steps + 1) * 2
    faces = []
    for index in range(steps):
        a = index * 2
        faces.extend(((a, a + 2, a + 3, a + 1),
                      (a + stride, a + stride + 1, a + stride + 3, a + stride + 2),
                      (a, a + stride, a + stride + 2, a + 2),
                      (a + 1, a + 3, a + stride + 3, a + stride + 1)))
    faces.extend(((0, 1, stride + 1, stride),
                  (steps * 2, steps * 2 + stride, steps * 2 + stride + 1, steps * 2 + 1)))
    return mesh_object(name, vertices, faces, material_name, True)


def star(name, at, outer, material_name):
    vertices = []
    for depth in (-0.035, 0.035):
        for index in range(10):
            angle = math.pi / 2 + index * math.pi / 5
            radius = outer if index % 2 == 0 else outer * 0.44
            vertices.append((at[0] + math.cos(angle) * radius, at[1] + math.sin(angle) * radius, at[2] + depth))
    faces = [tuple(reversed(range(10))), tuple(range(10, 20))]
    faces.extend((i, (i + 1) % 10, (i + 1) % 10 + 10, i + 10) for i in range(10))
    return mesh_object(name, vertices, faces, material_name)


def build_storybook():
    lathe("Book pedestal", [(0, 0.78), (0.06, 0.82), (0.14, 0.79), (0.19, 0.58), (0.26, 0.55)],
          (0, 0, 0), "DreamTeal")
    lathe("Pedestal gilding", [(0.10, 0.805), (0.13, 0.805)], (0, 0, 0), "DreamBrass")
    rounded_box("Book spine", (0, 0.30, 0), (0.12, 0.14, 1.48), "DreamBrass", 0.03)
    for side in (-1, 1):
        book_sheet("Sculpted hard cover", side, 0.31, "DreamTeal", 1.25, 1.48)
        for page in range(4):
            book_sheet("Layered curved parchment", side, 0.35 + page * 0.023, "DreamPaper",
                       1.18 - page * 0.022, 1.36 - page * 0.012)
        # A gilded page edge is visible as physical geometry, never written text.
        book_sheet("Fine gilded page edge", side, 0.427, "DreamBrass", 1.10, 1.37)
        book_sheet("Top parchment", side, 0.445, "DreamPaper", 1.10, 1.34)
    # A small blossoming tree grows out of the story. This is a decorative
    # miniature: lesson tokens and collisions belong to the existing runtime.
    points = [(0.08 * math.sin(t * math.pi), 0.50 + t * 0.76, -0.18) for t in [i / 12 for i in range(13)]]
    curved_stem("Story tree", points, 0.035, "DreamBrass")
    for index in range(5):
        angle = index * math.tau / 5 + 0.25
        petal("Sage story canopy", (0, 1.08, -0.18), angle, 0.43, 0.13, 0.27, "DreamLeaf")
    for side in (-1, 1):
        for index in range(3):
            petal("Carved parchment leaf", (side * 0.40, 0.66, 0.12 + index * 0.12),
                  0.1 + side * 0.7, 0.26, 0.05, 0.03, "DreamBrass", steps=8)
    for index, point in enumerate(((-0.47, 1.18, -0.12), (0.45, 1.36, -0.13), (0.03, 1.62, -0.18))):
        obj = star("DreamOrbit%02d" % index, point, 0.11 if index < 2 else 0.15, "DreamLight")
        obj["animated_dream_part"] = True


def build_blossom():
    lathe("Scalloped teal pot", [(0, 0.29), (0.05, 0.32), (0.32, 0.40), (0.39, 0.39), (0.44, 0.43)],
          (0, 0, 0), "DreamTeal", 20)
    lathe("Pot gilded lip", [(0.41, 0.431), (0.44, 0.432), (0.46, 0.40)], (0, 0, 0), "DreamBrass", 20)
    lathe("Sage moss", [(0.435, 0.36), (0.47, 0.32), (0.49, 0.02)], (0, 0, 0), "DreamLeaf", 20)
    for index in range(3):
        height = (1.18, 1.62, 1.30)[index]
        angle = index * math.tau / 3 + 0.4
        end = (math.cos(angle) * 0.24, height, math.sin(angle) * 0.24)
        points = []
        for step in range(15):
            t = step / 14
            points.append((end[0] * t * t, 0.46 + (height - 0.46) * t, end[2] * t * t))
        curved_stem("Living curved stem", points, 0.023, "DreamBrass")
        for leaf in range(2):
            t = 0.30 + leaf * 0.22
            origin = (end[0] * t * t, 0.46 + (height - 0.46) * t, end[2] * t * t)
            petal("Sculpted leaf", origin, angle + (1.0 if leaf else -1.0), 0.35, 0.09, 0.14, "DreamLeaf")
        flower_parts = []
        for petal_index in range(5):
            flower_parts.append(petal("Lantern petal", end, angle + petal_index * math.tau / 5,
                                      0.28, 0.12, 0.16, "DreamPetal"))
        flower_parts.append(lathe("Luminous pollen", [(0, 0.10), (0.08, 0.12), (0.16, 0.08), (0.18, 0.015)],
                                   end, "DreamLight", 16))
        bpy.ops.object.select_all(action="DESELECT")
        for obj in flower_parts:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = flower_parts[0]
        bpy.ops.object.join()
        flower = flower_parts[0]
        flower.name = "DreamFlower%02d" % index
        bpy.context.scene.cursor.location = xyz(end)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        flower["animated_dream_part"] = True


def consolidate_static():
    for mat in MATERIALS.values():
        group = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
                 and not obj.get("animated_dream_part") and obj.active_material == mat]
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        group[0].name = mat.name + "Sculpture"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def inspect_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError("Invalid GLB header")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != 0x4E4F534A:
        raise ValueError("Missing GLB JSON")
    gltf = json.loads(data[20:20 + json_length])
    triangles, surfaces = 0, 0
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("Non-triangle primitive")
            triangles += gltf["accessors"][primitive["indices"]]["count"] // 3
            surfaces += 1
    if triangles > 14000 or surfaces > 12 or len(data) > 1000000:
        raise ValueError("Dream garden mobile mesh budget exceeded")
    return {"file": path.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "triangles": triangles, "surfaces": surfaces, "mesh_count": len(gltf["meshes"]),
            "material_count": len(gltf["materials"]),
            "texture_count": len(gltf.get("textures", [])),
            "animated_part_names": [n["name"] for n in gltf["nodes"]
                                    if n.get("name", "").startswith(("DreamOrbit", "DreamFlower"))]}


def preview():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, offset in (("dream_storybook", (-1.75, 0, 0)), ("dream_blossom", (1.65, 0, 0.12))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(DESTINATION / (name + ".glb")))
        for obj in set(bpy.data.objects) - before:
            if obj.parent is None:
                obj.location += Vector(xyz(offset))
    palette()
    rounded_box("Preview plinth", (0, -0.13, 0), (7.8, 0.25, 4.0), "DreamTeal", 0.08)
    material("PreviewStudioStone", "c5c9bd", 0.84)
    rounded_box("Preview floor", (0, -0.29, 0), (200, 0.15, 200), "PreviewStudioStone", 0.01)
    bpy.ops.object.camera_add(location=xyz((6.0, 5.6, 8.6)))
    camera = bpy.context.object
    camera.rotation_mode = "QUATERNION"
    camera.rotation_quaternion = (Vector(xyz((0, 0.65, 0))) - camera.location).to_track_quat("-Z", "Y")
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.5
    bpy.context.scene.camera = camera
    for position, power, color, size in [((-3, 6, 3), 700, (1.0, 0.9, 0.76), 5),
                                         ((4, 5, -2), 500, (0.69, 0.84, 1.0), 4)]:
        bpy.ops.object.light_add(type="AREA", location=xyz(position))
        light = bpy.context.object
        light.data.energy, light.data.color, light.data.shape, light.data.size = power, color, "DISK", size
        light.rotation_mode = "QUATERNION"
        light.rotation_quaternion = (Vector(xyz((0, 0.5, 0))) - light.location).to_track_quat("-Z", "Y")
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1280, 820, 100
    scene.world = bpy.data.worlds.new("Atelier daylight")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.37, 0.42, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.42
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(SOURCE / "blender-dream-garden.png")
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = parser.parse_args(args)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / ".gdignore").touch()
    reports = []
    for name, build in (("dream_storybook", build_storybook), ("dream_blossom", build_blossom)):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        palette()
        build()
        consolidate_static()
        blend = SOURCE / (name + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
        target = DESTINATION / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", export_animations=False,
                                 export_cameras=False, export_lights=False, export_extras=True)
        report = inspect_glb(target)
        report["editable_source"] = str(blend.relative_to(ROOT))
        report["blend_sha256"] = hashlib.sha256(blend.read_bytes()).hexdigest()
        reports.append(report)
    manifest = {"schema": 1, "tool": "Blender " + bpy.app.version_string,
                "provenance": "Original LUMO geometry authored locally by this deterministic generator",
                "source": "tools/art/build_dream_garden.py", "units": "metres; glTF Y up",
                "materials": "Original opaque PBR; existing atelier palette; no downloaded textures",
                "assets": reports, "physical_android_performance_measured": False,
                "preview_scope": "Blender render of exported GLBs; separate Godot evidence is required"}
    (DESTINATION / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("[DreamGardenBlender] " + json.dumps(manifest), flush=True)
    if options.preview:
        preview()
    print("[DreamGardenBlender] PASS", flush=True)


if __name__ == "__main__":
    main()
