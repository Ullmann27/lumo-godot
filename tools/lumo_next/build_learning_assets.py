"""Author LUMO's original, reusable learning manipulatives in Blender.

Run with Blender 4.3+: blender -b -t 2 --python tools/lumo_next/build_learning_assets.py
The Godot-space helpers use metres, +Y up and +Z towards the viewing child.
Every exported asset has a lower-centre origin. Socket positions and exact
cardinality are written to the machine-readable manifest alongside the GLBs.
This is source geometry and a Blender render; neither proves Android output.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zlib

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art/lumo_next/learning"
RUNTIME = ROOT / "assets/lumo_next/learning"
TEXTURES = ART / "textures"
PALETTE = [
    ("oak", "a78357"), ("sandstone", "c6bd9f"),
    ("petrol", "385b60"), ("navy", "153d62"),
    ("blue", "3c91ad"), ("gold", "d69b39"),
    ("cream", "f2e6bf"), ("leaf", "547a55"),
    ("violet", "ad91dc"), ("soil", "68503b"),
    ("leaf_light", "94ab68"), ("coral", "d78b7e"),
    ("banana", "eed170"), ("dark", "303e43"),
    ("stone", "b9b9aa"), ("moss", "78856b"),
]
TILES = {name: i for i, (name, _) in enumerate(PALETTE)}
ASSETS = []
MATERIALS = {}
CURRENT_ROOT = None
CURRENT_COLLECTION = None


def godot(point):
    return Vector((point[0], -point[2], point[1]))


def as_godot(point):
    return [round(point[0], 6), round(point[2], 6), round(-point[1], 6)]


def png_rgba(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    scanlines = b"".join(b"\0" + pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
    payload = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    payload += chunk(b"IDAT", zlib.compress(scanlines, 9)) + chunk(b"IEND", b"")
    path.write_bytes(payload)


def build_atlas():
    """A deterministic original colour/roughness atlas, with padded UV cells."""
    size, cell = 512, 128
    colours = [tuple(int(hexadecimal[j:j + 2], 16) for j in (0, 2, 4)) for _, hexadecimal in PALETTE]
    rgba, rough = bytearray(), bytearray()
    for py in range(size):
        for px in range(size):
            row, column = (size - 1 - py) // cell, px // cell
            tile = row * 4 + column
            x, y = px % cell, (size - 1 - py) % cell
            grain = math.sin(x * .085 + .9 * math.sin(y * .038))
            grain += .4 * math.sin(x * .31 + .35 * math.sin(y * .067))
            fine = math.sin(x * 1.73 + y * 2.91) * math.sin(x * .47 - y * .79)
            variation = (grain * 5.8 + fine * 1.3) if tile == 0 else fine * 1.4
            if tile in (1, 14):
                variation = math.sin(x * .11 + y * .14) * 2.1 + fine * 2.7
            if tile in (7, 10, 15):
                variation = math.sin(y * .047) * 3.2 + fine * 1.5
            rgba.extend([max(0, min(255, round(c + variation))) for c in colours[tile]] + [255])
            value = max(0, min(255, round(175 + fine * 7)))
            rough.extend((value, value, value, 255))
    colour_path = TEXTURES / "lumo_learning_atlas.png"
    rough_path = TEXTURES / "lumo_learning_roughness.png"
    png_rgba(colour_path, size, size, rgba)
    png_rgba(rough_path, size, size, rough)
    colour = bpy.data.images.load(str(colour_path), check_existing=False)
    roughness = bpy.data.images.load(str(rough_path), check_existing=False)
    colour.colorspace_settings.name = "sRGB"
    roughness.colorspace_settings.name = "Non-Color"
    colour.pack()
    roughness.pack()
    material = bpy.data.materials.new("LumoLearningAtlas_Matte")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .68
    bsdf.inputs["Specular IOR Level"].default_value = .25
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.name = "Original padded colour atlas"
    albedo_node.image = colour
    links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])
    rough_node = nodes.new("ShaderNodeTexImage")
    rough_node.name = "Original subtle roughness atlas"
    rough_node.image = roughness
    links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
    MATERIALS["atlas"] = material


def asset(name, category, gallery, countable=False, **metadata):
    global CURRENT_ROOT, CURRENT_COLLECTION
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    root = bpy.data.objects.new(name, None)
    collection.objects.link(root)
    root["asset_id"] = name
    root["countable"] = countable
    root["units"] = "metres"
    root["origin"] = "lower centre, +Y up in Godot"
    CURRENT_COLLECTION, CURRENT_ROOT = collection, root
    record = dict(id=name, category=category, countable=countable, gallery=gallery,
                  root=root, collection=collection, anchors={}, **metadata)
    ASSETS.append(record)
    return root


def attach(obj, name, colour, smooth=False):
    obj.name = name
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    CURRENT_COLLECTION.objects.link(obj)
    obj.parent = CURRENT_ROOT
    obj["surface_colour"] = colour
    if obj.type == "MESH":
        obj.data.materials.clear()
        obj.data.materials.append(MATERIALS["atlas"])
        for face in obj.data.polygons:
            face.use_smooth = smooth
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def atlas_uv(obj, tile):
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.1519, island_margin=.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = obj.data.uv_layers.active
    uv.name = "LumoAtlasUV"
    index = TILES[tile]
    # Four texels of padding at each cell boundary survive filtering/mipmaps.
    origin = Vector(((index % 4) * .25 + 4 / 512, (index // 4) * .25 + 4 / 512))
    for loop in uv.data:
        loop.uv = origin + loop.uv * (.25 - 8 / 512)


def finish(obj, colour):
    atlas_uv(obj, colour)
    return obj


def box(name, position, size, colour, bevel=.025, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=godot(position))
    obj = attach(bpy.context.object, name, colour)
    obj.scale = (size[0], size[2], size[1])
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Rounded physical edges", "BEVEL")
        mod.width = min(bevel, min(size) * .45)
        mod.segments = segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for p in obj.data.polygons:
            p.use_smooth = True
        mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, colour)


def sphere(name, position, dimensions, colour, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1,
                                        location=godot(position))
    obj = attach(bpy.context.object, name, colour, True)
    obj.scale = (dimensions[0] / 2, dimensions[2] / 2, dimensions[1] / 2)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, colour)


def cylinder(name, position, radius, height, colour, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height,
                                       location=godot(position))
    obj = attach(bpy.context.object, name, colour)
    select_only(obj)
    mod = obj.modifiers.new("Soft rim", "BEVEL")
    mod.width = min(.018, height * .16)
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new("Weighted cap normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, colour)


def mesh(name, vertices, faces, colour, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata([godot(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    attach(obj, name, colour, smooth)
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.000001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def tube(name, points, radii, colour, sides=10):
    vertices, faces = [], []
    for i, point in enumerate(points):
        previous = Vector(points[max(0, i - 1)])
        following = Vector(points[min(len(points) - 1, i + 1)])
        tangent = (following - previous).normalized()
        reference = Vector((0, 0, 1)) if abs(tangent.z) < .85 else Vector((0, 1, 0))
        across = tangent.cross(reference).normalized()
        around = tangent.cross(across).normalized()
        for j in range(sides):
            theta = j / sides * math.tau
            offset = (math.cos(theta) * across + math.sin(theta) * around) * radii[i]
            vertices.append(tuple(Vector(point) + offset))
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces += [tuple(reversed(range(sides))), tuple((len(points) - 1) * sides + j for j in range(sides))]
    return finish(mesh(name, vertices, faces, colour, True), colour)


def leaf(name, start, end, width, colour):
    a, b = Vector(start), Vector(end)
    length = (b - a).length
    along = (b - a).normalized()
    sideways = along.cross(Vector((0, 0, 1))).normalized()
    if sideways.length < .01:
        sideways = Vector((1, 0, 0))
    vertices, faces = [], []
    for i in range(9):
        t = i / 8
        centre = a.lerp(b, t) + Vector((0, 0, -math.sin(t * math.pi) * length * .08))
        breadth = math.sin(t * math.pi) * width * (.85 + .15 * math.cos(t * math.pi))
        for j in (-1, 0, 1):
            vertices.append(tuple(centre + sideways * breadth * j + Vector((0, 0, abs(j) * .025 * math.sin(t * math.pi)))))
    for i in range(8):
        for j in range(2):
            v = i * 3 + j
            faces.append((v, v + 1, v + 4, v + 3))
    obj = mesh(name, vertices, faces, colour, True)
    select_only(obj)
    solid = obj.modifiers.new("Leaf has physical thickness", "SOLIDIFY")
    solid.thickness = .007
    bpy.ops.object.modifier_apply(modifier=solid.name)
    finish(obj, colour)
    tube(name + "_midrib", [start, tuple(a.lerp(b, .5)), end], [.013, .009, .002], "leaf_light", 6)
    return obj


def anchor(name, position, semantic=None):
    node_name = CURRENT_ROOT.name + "__" + name
    obj = bpy.data.objects.new(node_name, None)
    CURRENT_COLLECTION.objects.link(obj)
    obj.parent = CURRENT_ROOT
    obj.location = godot(position)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = .06
    obj["semantic_id"] = semantic or name
    ASSETS[-1]["anchors"][name] = {"node": node_name, "position": list(position), "semantic_id": semantic or name}


def counting_token(name, colour, gallery):
    asset(name, "counting", gallery, True, cardinality=1)
    box("SingleCountableBody", (0, .18, 0), (.58, .36, .58), colour, .068, 4)
    anchor("object_anchor", (0, .36, 0), "addend_a_00" if colour == "blue" else "addend_b_00")
    anchor("grip_anchor", (0, .18, 0))


def ten_frame():
    asset("ten_frame", "counting_support", (0, 0, -1.0), False, slot_count=10)
    box("OakTrayBase", (0, .04, 0), (4.65, .08, 2.05), "oak", .028)
    # Perimeter and grid form genuine shallow wells; no coplanar overlays.
    for side in (-1, 1):
        box("OuterLongRail", (0, .13, side * .955), (4.65, .1, .14), "oak", .02)
        box("OuterShortRail", (side * 2.255, .13, 0), (.14, .1, 1.77), "oak", .02)
    box("MiddleRail", (0, .13, 0), (4.38, .1, .10), "oak", .015)
    for x in (-1.275, -.425, .425, 1.275):
        box("ColumnRail", (x, .13, 0), (.09, .1, 1.77), "oak", .013)
    for index in range(10):
        x = -1.7 + index % 5 * .85
        z = -.5 + index // 5
        box(f"SlotWell_{index:02d}", (x, .095, z), (.74, .03, .77), "petrol", .02)
        anchor(f"slot_{index}", (x, .112, z), f"ten_frame_primary/slot_{index}")
    anchor("object_anchor", (0, .18, 0), "ten_frame_primary")


def ten_bundle():
    asset("ten_bundle", "counting", (3.6, 0, -1.0), True, cardinality=10,
          note="Ten separately named units; its root represents one ten. Hide individual units only during an explicit bundling step.")
    for index in range(10):
        x = -.945 + index * .21
        box(f"unit_{index}", (x, .105, 0), (.203, .21, .21), "blue", .019, 2)
        anchor(f"unit_anchor_{index}", (x, .21, 0), f"tens_bundle_00/unit_{index}")
    anchor("object_anchor", (0, .21, 0), "tens_bundle_00")


def text_carrier(name, width, depth, gallery):
    asset(name, "text_support", gallery, False,
          note="No baked characters. Godot TextMesh/Label3D supplies current letters or syllables at label_anchor.")
    box("RoundedCarrierBody", (0, .18, 0), (width, .36, depth), "cream", .065, 4)
    box("FineLowerEdge", (0, .042, 0), (width - .04, .06, depth - .04), "oak", .02, 2)
    # Inlay marks the carrier edge only; the label surface stays entirely quiet.
    box("ReadingEdge", (0, .361, depth * .34), (width * .72, .012, .023), "petrol", .004, 2)
    anchor("label_anchor", (0, .375, -.02), "syllable_0" if name == "syllable_tile" else "letter_0")
    anchor("object_anchor", (0, .375, 0))


def shape_token(name, sides, colour, gallery, radius=.38):
    asset("shape_" + name, "pattern", gallery, True, cardinality=1, shape=name)
    points = []
    if sides == 4:
        points = [(-radius, -radius), (radius, -radius), (radius, radius), (-radius, radius)]
    else:
        angle0 = -math.pi / 2
        points = [(math.cos(angle0 + i * math.tau / sides) * radius,
                   math.sin(angle0 + i * math.tau / sides) * radius) for i in range(sides)]
    verts = [(x, y, z) for y in (.0, .22) for x, z in points]
    faces = [tuple(reversed(range(sides))), tuple(sides + i for i in range(sides))]
    faces += [(i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides)]
    obj = mesh("SingleShapeBody", verts, faces, colour)
    select_only(obj)
    mod = obj.modifiers.new("Child friendly rounded edge", "BEVEL")
    mod.width = .024
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new("Preserve clear planar silhouette", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    finish(obj, colour)
    anchor("object_anchor", (0, .22, 0), "pattern_item_00")


def banana():
    asset("banana", "science", (3.5, 0, 2.6), True, cardinality=1,
          note="Single banana, supporting the word Banane without extra countable fruit.")
    points, radii = [], []
    for i in range(25):
        t = i / 24
        points.append((- .82 + 1.64 * t, .215 + .50 * (2 * t - 1) ** 2, 0))
        radii.append(.045 + .17 * math.sin(t * math.pi) ** .7)
    tube("BananaBody", points, radii, "banana", 12)
    tube("BananaStem", [(-.82, .715, 0), (-.91, .825, 0), (-.90, .945, 0)], [.05, .046, .035], "soil", 9)
    tube("BlossomEnd", [(.81, .705, 0), (.86, .765, 0)], [.045, .022], "soil", 9)
    # Four long low-relief peel ridges follow the fruit's curve.
    for side in (-1, 1):
        ridge = [(x, y + .06, side * r * .92) for (x, y, _), r in zip(points[2:-2], radii[2:-2])]
        tube("PeelRidge", ridge, [.010] * len(ridge), "gold", 6)
    anchor("object_anchor", (0, .43, 0), "science_banana")


def plant():
    asset("plant_study", "science", (-4.4, 0, 2.8), False,
          note="Parts are individually named and separated from countable items. Roots are exposed on a teaching cutaway.")
    cylinder("SoilSection", (0, .12, 0), .66, .24, "soil", 32)
    for index in range(5):
        angle = index * math.tau / 5 + .15
        x, z = math.cos(angle), math.sin(angle)
        tube("PlantRoot", [(0, .17, 0), (x * .22, .21, z * .18), (x * .46, .25, z * .45),
                           (x * .58, .24, z * .52)], [.035, .027, .018, .004], "cream", 7)
    stem = [(0, .25, 0), (.01, .55, 0), (-.035, .93, 0), (.025, 1.3, 0), (0, 1.75, 0)]
    tube("PlantStem", stem, [.052, .048, .043, .036, .027], "leaf", 10)
    leaf("PlantLeafLeft", (-.03, .87, 0), (-.61, 1.21, -.02), .17, "leaf")
    leaf("PlantLeafRight", (.01, 1.05, 0), (.60, 1.41, .03), .18, "leaf_light")
    tube("LeafStemLeft", [(-.03, .87, 0), (-.26, .99, -.01)], [.025, .013], "leaf", 7)
    tube("LeafStemRight", [(.01, 1.05, 0), (.25, 1.20, .01)], [.025, .013], "leaf", 7)
    # A simple recognisable flower whose petals cannot be confused with counters.
    for i in range(8):
        theta = i * math.tau / 8
        petal = sphere("PlantPetal", (math.cos(theta) * .19, 1.79 + math.sin(theta) * .19, .0),
                       (.18, .31, .10), "coral", 16, 8)
        petal.rotation_euler[1] = -theta + math.pi / 2
    sphere("PlantFlowerCentre", (0, 1.79, .065), (.24, .24, .14), "gold", 20, 10)
    for name, at in [("plant_root", (0, .245, .24)), ("plant_stem", (0, .83, .03)),
                     ("plant_leaf", (.34, 1.29, .06)), ("plant_flower", (0, 1.79, .15))]:
        anchor(name, at)


def floor_module():
    asset("floor_module", "scenery", (0, -.08, 0), False,
          note="Reusable quiet floor. No counters or bright decorative dots within the teaching area.")
    box("StonePlinth", (0, -.09, 0), (10.4, .18, 9.0), "stone", .07)
    for index in range(16):
        box("OakFloorBoard", (0, .015, -4.2 + index * .56), (10.14, .05, .55), "oak", .012, 2)
    box("QuietCarpetBorder", (0, .052, 0), (6.0, .025, 6.6), "navy", .08)
    box("QuietCarpet", (0, .071, 0), (5.86, .018, 6.46), "petrol", .06)
    anchor("teaching_origin", (0, .08, 0))


def pedestal():
    asset("pedestal", "scenery", (-3.4, 0, -1.0), False)
    cylinder("LowerPlinth", (0, .055, 0), .83, .11, "stone", 40)
    cylinder("PedestalColumn", (0, .19, 0), .74, .22, "oak", 40)
    cylinder("SoftTop", (0, .315, 0), .79, .075, "petrol", 40)
    anchor("top_surface", (0, .3525, 0))


def backdrop_module():
    asset("backdrop_module", "scenery", (0, 0, -4.5), False,
          note="Optional side/perimeter module; do not add atop the existing atelier or in a countable region.")
    # Quiet stepped planters and bent foliage remain behind the teaching plane.
    for side in (-1, 1):
        x = side * 3.7
        box("PlanterBody", (x, .36, 0), (1.25, .72, .85), "sandstone", .075)
        box("PlanterInset", (x, .733, 0), (1.08, .03, .69), "soil", .045)
        for j in range(3):
            start = (x + (j - 1) * .22, .75, .03)
            end = (x + (j - 1) * .39, 1.62 + .16 * (j % 2), -.04)
            tube("BackdropStem", [start, (start[0], 1.18, .01), end], [.027, .02, .005], "leaf", 8)
            leaf("BackdropLeaf", (start[0], 1.06, .0), (end[0] + side * .25, end[1], -.04), .15, "leaf")
            leaf("BackdropLeaf", (start[0], 1.02, .0), (end[0] - side * .20, end[1] - .20, .02), .14, "leaf_light")
    box("BackdropLowRail", (0, .24, -.20), (6.0, .48, .22), "sandstone", .04)
    box("BackdropCap", (0, .51, -.20), (6.1, .08, .30), "oak", .018)


def scene_setup():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in list(bpy.data.collections):
        if coll.name != "Collection":
            bpy.data.collections.remove(coll)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    scene = bpy.context.scene
    bpy.context.preferences.filepaths.save_version = 0
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    # This installed Blender build has no OpenImageDenoise; render real samples.
    scene.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 1120
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world.color = (.14, .17, .17)
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (.15, .18, .20, 1)
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .5


def exports():
    manifest_assets = []
    for record in ASSETS:
        root, collection = record["root"], record["collection"]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in collection.objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = root
        filename = record["id"] + ".glb"
        path = RUNTIME / filename
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                   export_yup=True, export_apply=True, export_animations=False,
                                   export_extras=True, export_texcoords=True, export_normals=True,
                                   export_materials="EXPORT", export_cameras=False, export_lights=False)
        vertices, triangles = 0, 0
        bounds = []
        for obj in collection.objects:
            if obj.type != "MESH":
                continue
            vertices += len(obj.data.vertices)
            obj.data.calc_loop_triangles()
            triangles += len(obj.data.loop_triangles)
            bounds.extend([Vector(as_godot(obj.matrix_world @ Vector(p))) for p in obj.bound_box])
        minimum = [min(p[i] for p in bounds) for i in range(3)]
        maximum = [max(p[i] for p in bounds) for i in range(3)]
        # Mesh bounds exclude empty interaction anchors.
        serial = {k: v for k, v in record.items() if k not in ("root", "collection", "gallery")}
        logical_types = {"count_token_teal": "count_token", "count_token_gold": "count_token",
                         "shape_circle": "circle", "shape_triangle": "triangle", "shape_square": "square",
                         "shape_hexagon": "hexagon", "plant_study": "plant"}
        serial["logical_type"] = logical_types.get(record["id"], record["id"])
        serial.update(path="res://assets/lumo_next/learning/" + filename,
                      bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                      vertices=vertices, triangles=triangles,
                      bounds_min=minimum, bounds_max=maximum, materials=1,
                      surface_origin="bottom centre" if minimum[1] >= -.001 else "floor datum; see bounds",
                      texture_resolution=[512, 512])
        manifest_assets.append(serial)
    manifest = dict(schema="lumo.learning_assets.v1", generated_with=bpy.app.version_string,
                    units="metres", axis="right-handed; +X right, +Y up, +Z towards viewer",
                    geometry="Opaque low-poly meshes; no hair, geometry nodes, Blender-only shaders or alpha cards required at runtime.",
                    texture_policy="Two packed original 512x512 images on a single opaque material per asset. Individual GLBs embed copies; runtime decoded-texture sharing has not been verified.",
                    source="art/lumo_next/learning/lumo_learning_assets.blend", assets=manifest_assets)
    (RUNTIME / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (ART / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return manifest


def camera_and_lights():
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=godot((9.1, 11.6, 12.5)))
    camera = bpy.context.object
    camera.name = "BlenderLearningOverviewCamera"
    target = godot((0, .25, -.25))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 15.6
    camera.data.lens = 52
    scene.camera = camera
    for name, at, power, size, colour in [
        ("Large soft window", (1, 8, 4), 1500, 8, (1.0, .88, .73)),
        ("Cool soft fill", (-6, 5, 2), 1050, 7, (.72, .86, 1.0)),
        ("Gentle garden bounce", (1, 6, -5), 950, 6, (1.0, .95, .83)),
    ]:
        data = bpy.data.lights.new(name, type="AREA")
        data.energy, data.shape, data.size = power, "DISK", size
        data.color = colour
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = godot(at)
        obj.rotation_euler = (godot((0, 0, 0)) - obj.location).to_track_quat("-Z", "Y").to_euler()


def preview_placements():
    for record in ASSETS:
        record["root"].location = godot(record["gallery"])
    # Reusable source objects retain names and are visibly separate in the overview.
    ten = next(r for r in ASSETS if r["id"] == "ten_frame")
    blue = next(r for r in ASSETS if r["id"] == "count_token_teal")
    gold = next(r for r in ASSETS if r["id"] == "count_token_gold")
    for index in range(1, 8):
        instance = bpy.data.objects.new(f"OverviewExample_8_Token_{index}", None)
        bpy.context.scene.collection.objects.link(instance)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = blue["collection"]
        slot = ten["anchors"][f"slot_{index}"]["position"]
        instance.location = godot((slot[0] + ten["gallery"][0] - blue["gallery"][0],
                                   slot[1] - blue["gallery"][1],
                                   slot[2] + ten["gallery"][2] - blue["gallery"][2]))
    for index in range(1, 5):
        instance = bpy.data.objects.new(f"OverviewExample_5_Token_{index}", None)
        bpy.context.scene.collection.objects.link(instance)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = gold["collection"]
        instance.location = godot((2.8 + index % 2 * .7 - gold["gallery"][0],
                                   -gold["gallery"][1],
                                   -.1 + index // 2 * .7 - gold["gallery"][2]))
    # The source exemplar is the first item in each group: exactly 8 plus 5.
    # No text is baked into the carriers or exported GLBs.


def provenance(manifest):
    source = {
        "asset_family": "LUMO next-generation learning manipulatives",
        "authoring": "Original geometry, UV layouts, deterministic texture atlas and Blender scene authored for Heinz Ullmann's LUMO project through a scripted Blender production workflow.",
        "third_party_geometry": [], "third_party_textures": [], "paid_provider_calls": [],
        "reference_sources": [
            "Existing lumo-godot scripts/learning/learning_world.gd for dimensions, lesson semantics and palette",
            "Existing lumo-godot scripts/learning/learning_atelier.gd for compatible restrained colours",
            "Existing lumo-lernen lib/features/learning/lab/learning_lab_catalog.dart for Banane / Ba-na-ne",
        ],
        "rights": "New project-authored assets; no third-party model, texture, motion or stock asset licenses are required. No ownership or license statement is made for pre-existing project files.",
        "source_script": "tools/lumo_next/build_learning_assets.py",
        "blender_version": bpy.app.version_string,
        "render_evidence": "learning_assets_blender_overview.png is a direct Cycles render of the editable scene. It does not represent Godot or an Android capture.",
        "runtime_status": "GLB export completed; engine import, app interaction and device profiling are separate checks owned by integration.",
    }
    (ART / "provenance.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    (RUNTIME / "provenance.json").write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    (ART / "README.md").write_text(
        "# LUMO learning asset source\n\n"
        "The `.blend` contains editable named mesh parts, UVs, packed atlas textures, "
        "semantic empty anchors, a gallery layout and the exact Blender preview camera/lights. "
        "Run `blender -b -t 2 --python tools/lumo_next/build_learning_assets.py` from the repository to reproduce it.\n\n"
        "## Runtime conventions\n\n"
        "One unit is one metre. Export is glTF Y-up, X-right, Z-towards the child. "
        "Assets use a lower-centre origin except the floor module's explicit datum. "
        "See `manifest.json` for measured bounds and anchor locations. All geometry is opaque, "
        "uses UVs and requires only the exported PBR material. No Blender nodes must execute in Godot.\n\n"
        "`count_token_teal` and `count_token_gold` each count as exactly one; `ten_bundle` "
        "contains exactly ten individually named unit meshes. `ten_frame` has ten empty receiving wells. "
        "Frames, cards, carpet, soil and scenery are not countable. Dynamic text must be supplied by the lesson; "
        "the text carriers are intentionally reusable and never contain a fixed answer.\n\n"
        "Runtime IDs belong to lesson instances, not global screen positions. Suggested IDs: "
        "`addend_a_00`, `addend_b_00`, `ten_frame_primary/slot_0`, `tens_bundle_00`, "
        "`syllable_0`, `pattern_item_00`, `plant_root`, `plant_stem`, `plant_leaf`, `plant_flower`. "
        "Keep these IDs stable while layout transforms change. Node anchors provide local positions.\n\n"
        "## Evidence boundary\n\n"
        "`learning_assets_blender_overview.png` is an unretouched Blender Cycles render. "
        "It proves source production only. Godot import, live pointing, transitions and device performance "
        "need their own runtime captures and measurements. The overview contains eight teal counters in "
        "the frame and five gold counters beside it; the bundle, shapes and science objects are separate asset samples.\n\n"
        "New work uses no external stock material or paid generation service. Read `provenance.json`.\n"
    )


def main():
    for path in (ART, RUNTIME, TEXTURES):
        path.mkdir(parents=True, exist_ok=True)
    scene_setup()
    build_atlas()
    counting_token("count_token_teal", "blue", (-1.7, .112, -1.5))
    counting_token("count_token_gold", "gold", (2.8, .0, -.1))
    ten_frame()
    ten_bundle()
    text_carrier("syllable_tile", 1.45, .95, (-.45, 0, 2.8))
    text_carrier("letter_tile", .82, .82, (1.15, 0, 2.8))
    shape_token("circle", 48, "blue", (-1.75, 0, 1.0))
    shape_token("triangle", 3, "gold", (-.75, 0, 1.0), .45)
    shape_token("square", 4, "violet", (.25, 0, 1.0), .34)
    shape_token("hexagon", 6, "leaf", (1.25, 0, 1.0), .42)
    banana()
    plant()
    pedestal()
    floor_module()
    backdrop_module()
    manifest = exports()
    provenance(manifest)
    preview_placements()
    camera_and_lights()
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / "lumo_learning_assets.blend"))
    if "--skip-render" not in sys.argv:
        bpy.context.scene.render.filepath = str(ART / "learning_assets_blender_overview.png")
        bpy.ops.render.render(write_still=True)
    summary = {"assets": len(manifest["assets"]), "triangles": sum(a["triangles"] for a in manifest["assets"]),
               "runtime_bytes": sum(a["bytes"] for a in manifest["assets"]),
               "source": str(ART / "lumo_learning_assets.blend")}
    print("LUMO_LEARNING_ASSETS " + json.dumps(summary))


if __name__ == "__main__":
    main()
