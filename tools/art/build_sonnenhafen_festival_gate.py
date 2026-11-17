"""Author the original Sonnenhafen festival gate with Blender 4.3+.

blender -b -t 4 --python tools/art/build_sonnenhafen_festival_gate.py -- --preview

Coordinates below are Godot metres: X right, Y up, front faces -Z. Exported
geometry has a ground origin, a 4.8 x 3.8 m reserved passage, and six opaque
PBR material batches. This is scenery; collisions and race logic stay in Godot.
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
MATERIALS = {}


def xyz(point):
    return (point[0], -point[2], point[1])


def material(name, color, roughness, metallic=0.0):
    values = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*linear, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*linear, 1)
    MATERIALS[name] = mat


def assign(obj, name, mat):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS[mat])
    return obj


def bevel(obj, amount=.045, segments=2):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Rounded masonry and enamel edges", "BEVEL")
    mod.width = amount
    mod.segments = segments
    mod.harden_normals = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    norm = obj.modifiers.new("Stable corner normals", "WEIGHTED_NORMAL")
    norm.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=norm.name)
    return obj


def box(name, pos, size, mat, rounded=.045):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(pos))
    obj = assign(bpy.context.object, name, mat)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return bevel(obj, min(rounded, min(size) * .3))


def sphere(name, pos, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1, location=xyz(pos))
    obj = assign(bpy.context.object, name, mat)
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def rod(name, start, end, radius, mat, vertices=12):
    a, b = Vector(xyz(start)), Vector(xyz(end))
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length,
                                      location=(a + b) * .5)
    obj = assign(bpy.context.object, name, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return obj


def polygon(name, points, z, depth, mat, rounded=.025):
    count = len(points)
    vertices = [xyz((x, y, z - depth / 2)) for x, y in points]
    vertices += [xyz((x, y, z + depth / 2)) for x, y in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, name, mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return bevel(obj, rounded)


def ribbon(name, center, width, z, depth, mat):
    lower, upper = [], []
    for i, (x, y) in enumerate(center):
        before = Vector(center[max(0, i - 1)])
        after = Vector(center[min(len(center) - 1, i + 1)])
        direction = (after - before).normalized()
        normal = Vector((-direction.y, direction.x)) * (width / 2)
        lower.append((x - normal.x, y - normal.y))
        upper.append((x + normal.x, y + normal.y))
    points = lower + list(reversed(upper))
    return polygon(name, points, z, depth, mat, .025)


def architecture():
    material("FestivalIvory", "f6e7cb", .64)
    material("FestivalTeal", "267f88", .36, .10)
    material("FestivalCopper", "bb7453", .38, .48)
    material("FestivalGold", "edbe5d", .30, .68)
    material("FestivalNavy", "294459", .55)
    material("FestivalFoam", "8cdbd3", .37)
    for side in (-1, 1):
        x = side * 3.18
        box("Masonry plinth", (x, .16, 0), (1.22, .32, 1.46), "FestivalIvory", .09)
        box("Copper plinth inset", (x, .36, 0), (1.06, .10, 1.25), "FestivalCopper", .025)
        box("Rounded tower body", (x, 2.13, 0), (.82, 3.48, .88), "FestivalIvory", .12)
        box("Teal recessed column face", (x, 2.13, -.45), (.53, 2.91, .055), "FestivalTeal", .06)
        for offset in (-.20, .20):
            box("Brass pillar fillet", (x + offset, 2.13, -.492), (.025, 2.69, .027), "FestivalGold", .009)
        for y in (.76, 3.42):
            box("Decorative copper collar", (x, y, 0), (.94, .14, 1.0), "FestivalCopper", .035)
        box("Stepped tower capital", (x, 3.86, 0), (1.14, .24, 1.22), "FestivalIvory", .075)
        box("Turquoise capital glaze", (x, 4.02, 0), (1.04, .10, 1.12), "FestivalTeal", .035)
        # Asymmetric swept fins are original wave architecture, not a copied logo.
        fin = [(side * 3.18, 4.05), (side * 3.90, 4.18), (side * 3.87, 4.70),
               (side * 3.65, 5.26), (side * 3.34, 5.63), (side * 3.37, 5.04),
               (side * 3.12, 4.49), (side * 2.87, 4.18)]
        polygon("Sculpted ocean fin", fin, .13, .20, "FestivalTeal", .045)
        ribbon("Foam trail on fin", [(side * 3.42, 4.32), (side * 3.60, 4.61),
                                     (side * 3.56, 4.90), (side * 3.43, 5.16)],
               .065, -.006, .055, "FestivalFoam")
        # Small round metal fasteners are batched with the existing gold.
        for y in (1.18, 2.10, 3.03):
            sphere("Flush gold fastener", (x, y, -.493), (.055, .055, .025), "FestivalGold")
    curve = []
    for index in range(33):
        x = -3.18 + 6.36 * index / 32
        curve.append((x, 4.14 + .59 * (1 - (x / 3.18) ** 2)))
    ribbon("Wide sculpted wave lintel", curve, .42, 0, .56, "FestivalIvory")
    ribbon("Copper inner edge", [(x, y - .20) for x, y in curve], .07, -.31, .07, "FestivalCopper")
    ribbon("Teal enamel face", [(x, y + .02) for x, y in curve], .18, -.31, .065, "FestivalTeal")
    ribbon("Fine gold upper fillet", [(x, y + .19) for x, y in curve], .045, -.347, .045, "FestivalGold")
    # Crest has dimensional rays and a turquoise wave: no text or external marks.
    center = Vector((0, 5.25, -.10))
    sphere("Warm enamel sun", center, (.36, .36, .14), "FestivalGold")
    for ray in range(12):
        angle = math.tau * ray / 12
        a = center + Vector((math.cos(angle) * .44, math.sin(angle) * .44, 0))
        b = center + Vector((math.cos(angle) * .61, math.sin(angle) * .61, 0))
        rod("Rounded sun ray", a, b, .045, "FestivalGold")
        sphere("Rounded sun ray tip", b, (.045, .045, .045), "FestivalGold")
    wave = []
    for i in range(21):
        x = -.31 + .62 * i / 20
        wave.append((x, 5.25 + math.sin(x * 9.0) * .09))
    ribbon("Ocean wave sun emblem", wave, .10, -.255, .055, "FestivalTeal")
    # Two tapered side pennants create silhouette without alpha blending.
    for side in (-1, 1):
        rod("Festival pennant mast", (side * 2.73, 4.45, .24), (side * 2.73, 5.57, .24), .032, "FestivalGold")
        polygon("Sculpted coral pennant", [(side * 2.73, 5.52), (side * 2.12, 5.33),
                                          (side * 2.73, 5.12)], .24, .065, "FestivalCopper", .015)
    # The darker base pads are outside the reserved central driving volume.
    for side in (-1, 1):
        box("Foundation shadow pad", (side * 3.18, .025, 0), (1.35, .05, 1.57), "FestivalNavy", .025)


def consolidate():
    for material in MATERIALS.values():
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.active_material == material]
        if not meshes:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        combined = bpy.context.object
        combined.name = material.name + "Batch"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")


def audit():
    triangles = 0
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    points = []
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for vertex in obj.data.vertices:
            p = obj.matrix_world @ vertex.co
            points.append((p.x, p.z, -p.y))
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    assert len(meshes) <= 6 and triangles <= 15000, (len(meshes), triangles)
    assert low[1] >= -.001 and high[1] <= 6.0, (low, high)
    # Every triangle is outside the reserved central 4.8m x 3.8m opening.
    for obj in meshes:
        for tri in obj.data.loop_triangles:
            coords = [obj.matrix_world @ obj.data.vertices[i].co for i in tri.vertices]
            godot = [(p.x, p.z) for p in coords]
            assert (min(p[1] for p in godot) >= 3.8 or
                    max(p[0] for p in godot) <= -2.4 or
                    min(p[0] for p in godot) >= 2.4), "Reserved passage is obstructed"
    return {"mesh_nodes": len(meshes), "material_surfaces": len(meshes), "triangles": triangles,
            "bbox_min_m": low, "bbox_max_m": high, "reserved_passage_m": [4.8, 3.8],
            "passage_triangle_test": "PASS", "alpha_blended_materials": 0}


def preview(target):
    # Preview floor is added only after GLB export and source save.
    box("Preview floor", (0, -.12, 0), (11.0, .20, 5.0), "FestivalNavy", .08)
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=xyz((10.5, 7.9, -14.5)))
    camera = bpy.context.object
    camera.rotation_euler = (Vector(xyz((0, 2.7, 0))) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 11.2
    scene.camera = camera
    for pos, power, color in [((-5, 9, -7), 1600, (1, .88, .70)),
                              ((6, 5, -3), 1100, (.66, .85, 1)),
                              ((0, 8, 6), 1800, (1, .91, .74))]:
        bpy.ops.object.light_add(type="AREA", location=xyz(pos))
        light = bpy.context.object
        light.data.energy = power
        light.data.color = color
        light.data.size = 6
        light.rotation_euler = (Vector(xyz((0, 2, 0))) - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.world = bpy.data.worlds.new("Festival studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.19, .25, .32, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .45
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = bool(getattr(bpy.app.build_options, "openimagedenoise", False))
    scene.render.resolution_x, scene.render.resolution_y = 1000, 760
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--source-root", type=Path, default=ROOT / "docs/design/home-festival-20261114")
    opts = parser.parse_args(args)
    destination = ROOT / "assets/kart/home_festival"
    destination.mkdir(parents=True, exist_ok=True)
    opts.source_root.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    architecture()
    consolidate()
    stats = audit()
    glb = destination / "sonnenhafen_festival_gate.glb"
    blend = opts.source_root / "Sonnenhafen-Festival-Gate.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_animations=False,
                             export_cameras=False, export_lights=False, export_extras=True)
    report = {"schema": 1, "tool": "Blender " + bpy.app.version_string,
              "source": "original scripted geometry", "runtime_asset": str(glb.relative_to(ROOT)),
              "asset_bytes": glb.stat().st_size, "sha256": hashlib.sha256(glb.read_bytes()).hexdigest(),
              "blend_sha256": hashlib.sha256(blend.read_bytes()).hexdigest(),
              "origin": "ground center", "front": "-Z", "up": "+Y", "units": "metres",
              "runtime_render_verified": False, "physical_android_fps_verified": False, **stats}
    (destination / "provenance.json").write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_FESTIVAL_GATE_EXPORTED " + json.dumps(report), flush=True)
    if opts.preview:
        preview_file = opts.source_root / "blender-festival-gate.png"
        preview(preview_file)
        report["blender_preview_sha256"] = hashlib.sha256(preview_file.read_bytes()).hexdigest()
        report["blender_preview_scope"] = "Asset geometry and lighting; not Godot or Android evidence"
        (destination / "provenance.json").write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_FESTIVAL_GATE_PASS", flush=True)


if __name__ == "__main__":
    main()
