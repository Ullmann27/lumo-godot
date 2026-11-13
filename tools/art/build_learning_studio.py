"""Author the runtime learning atelier in Blender, with a bounded mobile mesh.

Run: blender --background --python tools/art/build_learning_studio.py -- --preview
Coordinates in helpers are Godot metres (X right, Y up, Z forward). The export
is real geometry with opaque PBR materials. The preview is a Blender render of
these same exported meshes, not evidence of Godot or Android rendering.
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


ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / "assets/learning/studio"
SOURCE = ROOT / "docs/design/studio-20261113"
MATERIALS = {}


def xyz(point):
    return (point[0], -point[2], point[1])


def material(name, hexadecimal, roughness=0.65, metal=0.0):
    color = tuple(int(hexadecimal[i:i + 2], 16) / 255 for i in (0, 2, 4))
    # Hex colors are sRGB; the material nodes contain linear values.
    color = tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in color)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    mat.diffuse_color = (*color, 1)
    MATERIALS[name] = mat
    return mat


def assign(obj, name, mat):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS[mat])
    return obj


def box(name, position, size, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(position))
    obj = assign(bpy.context.object, name, mat)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Physical rounded edges", "BEVEL")
        modifier.width = min(bevel, min(size) * 0.22)
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def sphere(name, position, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=xyz(position))
    obj = assign(bpy.context.object, name, mat)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def rod(name, start, end, radius, mat, vertices=12):
    a, b = Vector(xyz(start)), Vector(xyz(end))
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length,
                                      location=(a + b) * 0.5)
    obj = assign(bpy.context.object, name, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return obj


def arch(name, x, y, z, radius, width, depth, mat, start=0.0, end=math.pi, segments=28):
    vertices, faces = [], []
    for i in range(segments + 1):
        angle = start + (end - start) * i / segments
        for dz in (-depth / 2, depth / 2):
            for r in (radius, radius + width):
                vertices.append(xyz((x + math.cos(angle) * r, y + math.sin(angle) * r, z + dz)))
    for i in range(segments):
        j = i * 4
        faces.extend([(j, j + 4, j + 5, j + 1), (j + 2, j + 3, j + 7, j + 6),
                      (j, j + 2, j + 6, j + 4), (j + 1, j + 5, j + 7, j + 3)])
    faces.extend([(0, 1, 3, 2), (segments * 4, segments * 4 + 2, segments * 4 + 3, segments * 4 + 1)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, name, mat)
    # Consistent outward normals are required on the actual Android mesh.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def architecture():
    material("StudioStone", "c5c9bd", 0.86)
    material("StudioOak", "79543d", 0.75)
    material("StudioTeal", "205663", 0.56)
    material("StudioBrass", "c19451", 0.36, 0.65)
    material("StudioPaper", "ddd8bd", 0.88)
    material("StudioCoral", "bd694b", 0.7)
    material("StudioBlue", "4b8191", 0.65)
    material("StudioLeaf", "4b8266", 0.88)
    material("StudioLeafLight", "8ea873", 0.88)
    material("StudioSoil", "4e4537", 0.95)
    for x in (-4.4, 0.0, 4.4):
        for side in (-1, 1):
            column = x + side * 1.49
            box("Stone pier", (column, 1.3, -5.65), (0.29, 2.6, 0.47), "StudioStone", 0.04)
            box("Pier base", (column, 0.13, -5.65), (0.5, 0.26, 0.7), "StudioStone")
            box("Pier capital", (column, 2.58, -5.65), (0.42, 0.16, 0.63), "StudioStone")
            box("Column inlay", (column, 1.4, -5.398), (0.05, 1.94, 0.025), "StudioBrass", 0.006)
        arch("Continuous carved arch", x, 2.65, -5.65, 1.34, 0.30, 0.47, "StudioStone")
        arch("Brass arch fillet", x, 2.65, -5.39, 1.385, 0.045, 0.035, "StudioBrass")
        box("Window sill", (x, 0.54, -5.7), (2.7, 0.16, 0.55), "StudioOak")
        for baluster in range(7):
            bx = x - 1.13 + baluster * 0.376
            rod("Balustrade", (bx, 0.13, -5.68), (bx, 0.52, -5.68), 0.028, "StudioTeal", 8)
    box("Header beam", (0, 4.38, -5.65), (13.15, 0.24, 0.67), "StudioOak", 0.05)
    box("Header enamel", (0, 4.43, -5.285), (12.94, 0.12, 0.05), "StudioTeal", 0.01)
    for side in (-1, 1):
        x = side * 6.13
        box("Terrace post", (x, 1.82, -2.1), (0.23, 3.75, 0.23), "StudioOak")
        box("Terrace brace", (x, 3.67, -3.88), (0.28, 0.22, 3.79), "StudioOak")
        box("Brass rail", (x, 0.74, 0.1), (0.16, 0.12, 4.8), "StudioBrass")
        for z in (-2.0, -0.65, 0.7, 2.25):
            box("Rail post", (x, 0.29, z), (0.12, 0.78, 0.12), "StudioTeal")
        for shelf in range(3):
            box("Bookcase shelf", (side * 4.85, 0.32 + shelf * 0.64, -4.6), (1.78, 0.12, 0.7), "StudioOak")
        for edge in (-0.83, 0.83):
            box("Bookcase side", (side * 4.85 + edge, 0.93, -4.6), (0.13, 1.95, 0.7), "StudioTeal")
        for index in range(10):
            xbook = side * 4.85 + (index % 5 - 2) * 0.28
            height = 0.37 + (index % 3) * 0.06
            ybook = 0.4 + (index // 5) * 0.64 + height / 2
            box("Rounded book cover", (xbook, ybook, -4.48), (0.22, height, 0.45),
                ("StudioCoral", "StudioBlue", "StudioTeal")[index % 3], 0.018)
            box("Book pages", (xbook, ybook, -4.226), (0.16, height - 0.07, 0.018), "StudioPaper", 0.004)
            box("Book gold spine", (xbook, ybook - height * 0.2, -4.236), (0.16, 0.025, 0.025), "StudioBrass", 0.003)
    # A real abacus and globe make the two side cabinets identifiable.
    for side in (-1, 1):
        box("Science worktop", (side * 4.85, 0.63, 2.0), (1.65, 0.13, 1.45), "StudioOak", 0.04)
        for xoff in (-0.65, 0.65):
            for z in (1.45, 2.55):
                box("Worktop leg", (side * 4.85 + xoff, 0.25, z), (0.13, 0.65, 0.13), "StudioTeal")
    globe = (4.85, 1.20, 2.0)
    sphere("Solid globe", globe, (0.37, 0.37, 0.37), "StudioBlue")
    arch("Globe meridian", globe[0], globe[1], globe[2], 0.40, 0.025, 0.04,
         "StudioBrass", 0, math.tau, 36)
    rod("Globe stem", (4.85, 0.7, 2), (4.85, 0.85, 2), 0.045, "StudioBrass")
    for index in range(5):
        angle = index * 1.7
        sphere("Raised continent", (4.85 + math.sin(angle) * 0.24, 1.25 + math.cos(angle) * 0.18,
                                     2.0 + math.cos(angle * 1.3) * 0.20),
               (0.16, 0.09, 0.16), "StudioLeafLight")
    for x in (-5.42, -4.28):
        box("Abacus upright", (x, 1.09, 2), (0.07, 0.86, 0.08), "StudioOak")
    for row in range(4):
        y = 0.82 + row * 0.18
        rod("Abacus rail", (-5.42, y, 2), (-4.28, y, 2), 0.018, "StudioBrass", 8)
        for bead in range(5):
            sphere("Counting bead", (-5.30 + bead * 0.18, y, 2), (0.065, 0.07, 0.07),
                   "StudioCoral" if row % 2 == 0 else "StudioTeal")
    # Broad shaped leaves rather than floating billboard vegetation.
    for side in (-1, 1):
        for z in (-3.1, 3.65):
            x = side * 5.8
            box("Ceramic planter", (x, 0.21, z), (0.75, 0.49, 0.75), "StudioCoral", 0.08)
            box("Planter soil", (x, 0.47, z), (0.61, 0.03, 0.61), "StudioSoil", 0.008)
            for leaf in range(7):
                angle = leaf * math.tau / 7
                end = (x + math.cos(angle) * 0.36, 0.91 + (leaf % 3) * 0.12,
                       z + math.sin(angle) * 0.36)
                rod("Leaf stem", (x, 0.45, z), end, 0.014, "StudioLeaf", 6)
                ob = sphere("Sculpted leaf", end, (0.12, 0.25, 0.045),
                            "StudioLeafLight" if leaf % 3 == 0 else "StudioLeaf")
                ob.rotation_euler = (0.35 * math.cos(angle), 0.2, angle)


def consolidate():
    # Join by opaque material: one mesh surface per material, not one draw per book.
    for mat in MATERIALS.values():
        group = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.active_material == mat]
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        combined = bpy.context.object
        combined.name = mat.name + "Batch"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")


def preview():
    # Preview-only floor/camera/lights are intentionally excluded from the GLB.
    material("PreviewFloor", "718b87", 0.9)
    box("Preview teaching deck", (0, -0.12, 0), (13.0, 0.2, 13.0), "PreviewFloor", 0.06)
    source = ROOT / "assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported = set(bpy.data.objects) - before
    rig = next(o for o in imported if o.type == "ARMATURE")
    top = rig
    while top.parent:
        top = top.parent
    rig.animation_data_clear()
    # Fit by the rest mesh bounds; keep original geometry/materials intact.
    meshes = [o for o in imported if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    bounds = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    low, high = min(v.z for v in bounds), max(v.z for v in bounds)
    scale = 3.1 / (high - low)
    top.scale *= scale
    top.location = Vector(xyz((-4.6, -low * scale, -0.4)))
    bpy.ops.object.camera_add(location=xyz((10.8, 10.5, 15.3)))
    camera = bpy.context.object
    camera.rotation_euler = (Vector(xyz((0, 1.15, -0.8))) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 20
    bpy.context.scene.camera = camera
    for name, position, power, color, size in [
        ("Large daylight", (-3, 10, 4), 1800, (1.0, 0.90, 0.75), 10),
        ("Cool softbox", (6, 6, -3), 1100, (0.67, 0.83, 1.0), 8),
    ]:
        bpy.ops.object.light_add(type="AREA", location=xyz(position))
        light = bpy.context.object
        light.name = name
        light.data.energy, light.data.color, light.data.shape, light.data.size = power, color, "DISK", size
        light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1000, 700, 100
    scene.world = bpy.data.worlds.new("Preview daylight")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.30, 0.37, 0.42, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(SOURCE / "blender-studio-preview.png")
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    opts = parser.parse_args(args)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    architecture()
    consolidate()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    assert len(meshes) <= 12 and triangles < 45000, (len(meshes), triangles)
    blend = SOURCE / "Learning-Studio.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    target = DESTINATION / "learning_studio.glb"
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", export_animations=False,
                             export_cameras=False, export_lights=False, export_extras=True)
    report = {"schema": 1, "tool": "Blender " + bpy.app.version_string, "source": "original scripted geometry",
              "units": "metres", "mesh_count": len(meshes), "material_count": len(MATERIALS),
              "triangles": triangles, "runtime_asset": str(target.relative_to(ROOT)),
              "asset_bytes": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
              "blend_sha256": hashlib.sha256(blend.read_bytes()).hexdigest(),
              "runtime_capture_status": "requires actual Godot render; Blender preview is asset evidence only"}
    (DESTINATION / "provenance.json").write_text(json.dumps(report, indent=2) + "\n")
    print("[LearningStudioBlender] EXPORTED " + json.dumps(report), flush=True)
    if opts.preview:
        preview()
    print("[LearningStudioBlender] PASS", flush=True)


if __name__ == "__main__":
    main()
