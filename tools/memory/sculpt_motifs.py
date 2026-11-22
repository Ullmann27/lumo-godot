"""Render the original tabletop miniatures for the Memory deck.

blender -b -t 2 -P tools/memory/sculpt_motifs.py -- output_folder [motif ...]
Then run finish_cards.py on that folder. Blender 4.3, Cycles CPU.
"""

import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index("--") + 1 :]
OUT = Path(args[0])
OUT.mkdir(exist_ok=True, parents=True)
TAU = math.tau
INK = "182936"
CREAM = "fff0c6"
GOLD = "e7a548"
PALE = "ffde83"
materials = {}


def material(hexcolor, metal=False):
    key = (hexcolor, metal)
    if key not in materials:
        m = bpy.data.materials.new(hexcolor)
        rgb = [int(hexcolor[i : i + 2], 16) / 255 for i in (0, 2, 4)]
        color = tuple(
            v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb
        ) + (1,)
        m.diffuse_color = color
        m.use_nodes = True
        shader = m.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = 0.34 if metal else 0.40
        shader.inputs["Metallic"].default_value = 0.54 if metal else 0.03
        materials[key] = m
    return materials[key]


def finish(o, col, metal=False):
    o.data.materials.append(material(col, metal))
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def oval(p, s, col, metal=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=p)
    o = bpy.context.object
    o.scale = s
    return finish(o, col, metal)


def box(p, s, col, bevel=0.06, metal=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    o = bpy.context.object
    o.dimensions = s
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = o.modifiers.new("Rounded edges", "BEVEL")
    mod.width = bevel
    mod.segments = 5
    o.modifiers.new("Polished facets", "WEIGHTED_NORMAL")
    o.data.materials.append(material(col, metal))
    return o


def pipe(points, col, r=0.024, metal=False):
    c = bpy.data.curves.new("Line", "CURVE")
    c.dimensions = "3D"
    c.resolution_u = 12
    c.bevel_depth = r
    c.bevel_resolution = 4
    c.use_fill_caps = True
    s = c.splines.new("BEZIER")
    s.bezier_points.add(len(points) - 1)
    for bp, p in zip(s.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new("Stroke", c)
    bpy.context.collection.objects.link(o)
    c.materials.append(material(col, metal))
    return o


def plaque(outline, p, col, depth=0.16, bevel=0.035, metal=False):
    c = bpy.data.curves.new("Inlay", "CURVE")
    c.dimensions = "2D"
    c.resolution_u = 3
    c.extrude = depth / 2
    c.bevel_depth = bevel
    c.bevel_resolution = 5
    s = c.splines.new("POLY")
    s.points.add(len(outline) - 1)
    for k, (x, z) in enumerate(outline):
        s.points[k].co = (x, z, 0, 1)
    s.use_cyclic_u = True
    o = bpy.data.objects.new("Enamel inlay", c)
    bpy.context.collection.objects.link(o)
    o.rotation_euler.x = math.pi / 2
    o.location = p
    c.materials.append(material(col, metal))
    return o


def eye(x, y, z, size=0.11):
    oval((x, y, z), (size, size * 0.5, size * 1.18), INK)
    oval(
        (x - size * 0.23, y - size * 0.45, z + size * 0.28),
        (size * 0.29, size * 0.16, size * 0.29),
        "fff8e8",
    )


def face(kind):
    if kind == "pinguin":
        oval((0, 0, 0), (0.72, 0.54, 0.92), INK)
        oval((0, -0.32, -0.10), (0.53, 0.27, 0.64), CREAM)
        for k in [-1, 1]:
            oval((k * 0.24, -0.42, 0.26), (0.25, 0.13, 0.27), CREAM)
            eye(k * 0.23, -0.55, 0.27, 0.071)
            wing = oval((k * 0.62, -0.01, -0.12), (0.17, 0.22, 0.56), "284355")
            wing.rotation_euler.y = -k * 0.4
            oval((k * 0.34, -0.20, -0.81), (0.24, 0.30, 0.104), GOLD)
        beak = plaque(
            [(-0.16, 0.04), (0.16, 0.04), (0, -0.14)], (0, -0.587, 0.10), "f2a64d", 0.12
        )
        pipe(
            [(-0.5, -0.2, -0.22), (0, -0.64, -0.26), (0.49, -0.22, -0.18)],
            "317c89",
            0.08,
        )
        scarf = box((0.31, -0.45, -0.41), (0.18, 0.11, 0.38), "317c89")
        scarf.rotation_euler.y = -0.27
        return
    if kind == "giraffe":
        oval((0, 0.07, -0.31), (0.29, 0.30, 0.80), "dda74d")
        for i in range(4):
            oval(
                ((-1) ** i * 0.15, -0.19, -0.82 + i * 0.23),
                (0.09, 0.045, 0.12),
                "926131",
            )
        for k in [-1, 1]:
            ear = oval((k * 0.63, 0.0, 0.39), (0.27, 0.12, 0.15), "eab75a")
            ear.rotation_euler.y = -k * 0.44
            ear = oval((k * 0.65, -0.094, 0.40), (0.17, 0.05, 0.091), "bb744c")
            ear.rotation_euler.y = -k * 0.44
            pipe([(k * 0.25, 0.03, 0.43), (k * 0.29, 0.035, 0.77)], "ca8c42", 0.061)
            oval((k * 0.29, 0.035, 0.79), (0.13, 0.12, 0.11), "785238")
        oval((0, 0, 0.20), (0.58, 0.46, 0.47), "efbc64")
        oval((0, -0.32, -0.01), (0.49, 0.31, 0.265), "f7d3a1")
        for k in [-1, 1]:
            eye(k * 0.267, -0.399, 0.256, 0.083)
            oval((k * 0.16, -0.59, 0.032), (0.048, 0.026, 0.034), "8e6545")
        pipe(
            [(-0.13, -0.603, -0.07), (0, -0.627, -0.10), (0.13, -0.602, -0.061)],
            "9b674d",
            0.014,
        )
        return
    rabbit = kind == "hase"
    coat = "dbc1a2" if rabbit else "eee8d8"
    oval((0, 0.06, -0.44), (0.54, 0.4, 0.49), coat if rabbit else INK)
    for k in [-1, 1]:
        if rabbit:
            ear = oval((k * 0.32, 0.03, 0.58), (0.17, 0.14, 0.47), coat)
            ear.rotation_euler.y = k * 0.22
            ear = oval((k * 0.332, -0.085, 0.60), (0.09, 0.061, 0.35), "c97f7c")
            ear.rotation_euler.y = k * 0.22
        else:
            oval((k * 0.52, 0.04, 0.46), (0.272, 0.22, 0.252), INK)
        oval((k * 0.33, -0.22, -0.64), (0.23, 0.26, 0.14), coat if rabbit else INK)
    oval((0, 0, -0.02), (0.68, 0.49, 0.57), coat)
    for k in [-1, 1]:
        if not rabbit:
            o = oval((k * 0.276, -0.378, 0.066), (0.225, 0.13, 0.23), INK)
            o.rotation_euler.y = k * 0.38
        eye(k * 0.264, -(0.506 if not rabbit else 0.449), 0.074, 0.085)
        oval((k * 0.127, -0.462, -0.152), (0.202, 0.14, 0.15), CREAM)
    oval((0, -0.60, -0.075), (0.104, 0.073, 0.066), "775044" if rabbit else INK)
    if rabbit:
        for k in [-1, 1]:
            for i in range(2):
                pipe(
                    [
                        (k * 0.235, -0.533, -0.14 - i * 0.058),
                        (k * 0.53, -0.542, -0.14 - i * 0.092),
                    ],
                    "957263",
                    0.009,
                )
        oval((0, -0.395, -0.51), (0.19, 0.086, 0.25), "e89a46").rotation_euler.y = -0.48
        for i in [-1, 0, 1]:
            pipe(
                [(-0.08, -0.39, -0.35), (-0.08 + i * 0.10, -0.40, -0.145)],
                "608558",
                0.025,
            )
    else:
        pipe(
            [(0.28, -0.39, -0.68), (0.46, -0.42, -0.23), (0.51, -0.36, 0.02)],
            "5e965d",
            0.031,
        )
        for i in range(3):
            oval(
                (0.49 + (0.062 if i % 2 else -0.052), -0.44, -0.35 + i * 0.14),
                (0.12, 0.027, 0.054),
                "77ab62",
            ).rotation_euler.y = (-1) ** i * 0.5


def star(n=5, rad=0.88, inner=0.44):
    return [
        (
            math.sin(i * math.pi / n) * (rad if i % 2 == 0 else inner),
            math.cos(i * math.pi / n) * (rad if i % 2 == 0 else inner),
        )
        for i in range(n * 2)
    ]


def treasure(kind):
    if kind == "stern":
        plaque(star(), (0, 0, 0), "af6637", 0.27, 0.065, True)
        plaque(star(rad=0.79, inner=0.38), (0, -0.188, 0), "ffce61", 0.04, 0.035)
        plaque(
            star(n=4, rad=0.26, inner=0.098), (0, -0.245, 0.015), "fff3b1", 0.035, 0.015
        )
    elif kind == "laterne":
        box((0, 0, -0.61), (1.05, 0.62, 0.16), "916545", 0.075, True)
        box((0, 0, -0.49), (0.91, 0.55, 0.13), GOLD, 0.05, True)
        box((0, 0, -0.02), (0.78, 0.51, 0.86), "ffc057", 0.095)
        for k in [-1, 1]:
            pipe(
                [(k * 0.43, -0.27, -0.47), (k * 0.47, -0.27, 0.40)],
                "876348",
                0.058,
                True,
            )
            pipe(
                [(k * 0.41, -0.312, -0.43), (-k * 0.40, -0.312, 0.39)],
                PALE,
                0.028,
                True,
            )
        box((0, 0, 0.46), (1.04, 0.68, 0.13), "745247", 0.06, True)
        plaque(
            [(-0.53, 0), (0.53, 0), (0.22, 0.24), (-0.22, 0.24)],
            (0, 0, 0.47),
            "987650",
            0.49,
            0.05,
            True,
        )
        pipe(
            [
                (-0.22, 0.006, 0.67),
                (-0.26, 0.02, 0.88),
                (0, 0.02, 1.01),
                (0.26, 0.02, 0.88),
                (0.22, 0.006, 0.67),
            ],
            "8b7758",
            0.042,
            True,
        )
    elif kind == "truhe":
        box((0, 0, -0.26), (1.48, 0.92, 0.71), "975a39", 0.12)
        box((0, 0, 0.13), (1.52, 0.96, 0.42), "bb7a46", 0.18)
        box((0, 0, -0.08), (1.55, 0.96, 0.085), "865435", 0.025)
        for k in [-1, 1]:
            box((k * 0.49, -0.01, -0.105), (0.12, 0.97, 0.79), "dbac60", 0.04, True)
            for z in [-0.42, 0.2]:
                oval((k * 0.49, -0.501, z), (0.032, 0.02, 0.032), CREAM, True)
        box((0, -0.515, -0.098), (0.29, 0.10, 0.29), PALE, 0.046, True)
        oval((0, -0.572, -0.08), (0.041, 0.018, 0.056), INK)
    elif kind == "note":
        plaque(
            [
                (-0.5, -0.32),
                (-0.39, -0.32),
                (-0.39, 0.43),
                (0.44, 0.62),
                (0.44, -0.18),
                (0.55, -0.18),
                (0.55, 0.83),
                (-0.51, 0.59),
            ],
            (0, 0, 0),
            "358891",
            0.25,
            0.058,
            True,
        )
        for k, z in [(-0.62, -0.43), (0.32, -0.27)]:
            oval((k, 0, z), (0.29, 0.19, 0.22), "479d9e", True).rotation_euler.y = -0.4
            oval((k - 0.045, -0.153, z + 0.04), (0.11, 0.041, 0.053), "acd6bc")
        pipe([(-0.42, -0.184, 0.51), (0.46, -0.184, 0.70)], PALE, 0.03, True)
    elif kind == "fahne":
        pipe([(-0.51, 0, -0.82), (-0.51, 0, 0.80)], GOLD, 0.055, True)
        oval((-0.51, 0, 0.86), (0.10, 0.10, 0.10), PALE, True)
        plaque(
            [
                (-0.44, 0.70),
                (0.17, 0.56),
                (0.74, 0.70),
                (0.57, 0.38),
                (0.77, 0.15),
                (0.18, 0.01),
                (-0.44, 0.16),
            ],
            (0, 0, 0),
            "bd4f55",
            0.11,
            0.033,
        )
        plaque(star(rad=0.185, inner=0.09), (0.03, -0.11, 0.36), PALE, 0.017, 0.014)
        box((-0.51, 0, -0.77), (0.54, 0.43, 0.13), "578183")
    elif kind == "pilz":
        oval((0, 0, -0.34), (0.32, 0.30, 0.56), "eed9a3")
        oval((0, 0, 0.12), (0.81, 0.61, 0.23), "f6d8a5")
        oval((-0.025, 0.02, 0.24), (0.81, 0.60, 0.43), "bb4438")
        for x, y, z, r in [
            (-0.36, -0.39, 0.44, 0.13),
            (0.17, -0.48, 0.41, 0.16),
            (0.43, -0.26, 0.51, 0.11),
            (-0.06, -0.2, 0.619, 0.082),
        ]:
            oval((x, y, z), (r, r * 0.65, r * 0.40), "fff0cd")
        for i in range(3):
            leaf = oval((-0.36 + 0.39 * i, -0.02, -0.72), (0.19, 0.10, 0.08), "60915a")
            leaf.rotation_euler.y = -0.20 + i * 0.26
    elif kind == "stein":
        for x, y, z, s, col in [
            (-0.38, 0, -0.26, 0.64, "32858c"),
            (0.22, 0.08, -0.25, 0.77, "6574ae"),
            (0.05, -0.24, -0.48, 0.47, "427e93"),
        ]:
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1, radius=s, location=(x, y, z)
            )
            o = bpy.context.object
            o.scale = (1, 0.76, 0.69)
            o.data.materials.append(material(col))
        for x, y, h, tilt, col in [
            (-0.47, 0.03, 0.80, -0.3, "66cccb"),
            (-0.03, 0.04, 1.12, 0.12, "b2a8ed"),
            (0.45, 0.08, 0.70, 0.47, "73a8d8"),
        ]:
            levels = [(-0.34, 0.16), (0.02, 0.20), (h - 0.52, 0.17), (h - 0.27, 0.008)]
            vs = [
                (
                    x + jz * math.sin(tilt) + rad * math.cos(i * TAU / 6),
                    y + rad * math.sin(i * TAU / 6),
                    jz,
                )
                for jz, rad in levels
                for i in range(6)
            ]
            fs = [
                (
                    j * 6 + i,
                    j * 6 + (i + 1) % 6,
                    (j + 1) * 6 + (i + 1) % 6,
                    (j + 1) * 6 + i,
                )
                for j in range(3)
                for i in range(6)
            ]
            m = bpy.data.meshes.new("Faceted quartz")
            m.from_pydata(vs, [], fs)
            o = bpy.data.objects.new("Crystal", m)
            bpy.context.collection.objects.link(o)
            m.materials.append(material(col, True))


def light(name, p, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = p
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()


def render(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials.clear()
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.62,
        0.68,
        0.78,
        1,
    )
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    if kind == "lumo":
        bpy.ops.import_scene.gltf(
            filepath=str(ROOT / "assets/characters/lumo_facial/Lumo-Facial-Mobile.glb")
        )
        meshes = [o for o in scene.objects if o.type == "MESH"]
        pts = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
        mins = Vector(tuple(min(p[i] for p in pts) for i in range(3)))
        maxs = Vector(tuple(max(p[i] for p in pts) for i in range(3)))
        midpoint = (mins + maxs) / 2
        height = maxs.z - mins.z
        center = Vector((midpoint.x, midpoint.y, mins.z + height * 0.65))
        scale = height * 0.78
    else:
        (face if kind in ["panda", "giraffe", "hase", "pinguin"] else treasure)(kind)
        center = Vector((0, 0, -0.01))
        scale = 2.25
    data = bpy.data.cameras.new("Portrait")
    cam = bpy.data.objects.new("Portrait", data)
    scene.collection.objects.link(cam)
    cam.location = (
        center
        + Vector(
            (
                0.085
                if kind in ["panda", "hase", "pinguin", "giraffe", "lumo"]
                else 0.21,
                -1,
                0.13,
            )
        )
        * scale
        * 3
    )
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = scale
    scene.camera = cam
    light("Key", (-2.6, -4.5, 4.6), 560, 4, (1, 0.88, 0.73))
    light("Fill", (3, -2, 2), 330, 4, (0.75, 0.88, 1))
    light("Rim", (1, 2.5, 3.2), 850, 3, (1, 0.88, 0.65))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(OUT / (kind + ".png"))
    bpy.ops.render.render(write_still=True)


for motif in args[1:] or [
    "panda",
    "giraffe",
    "hase",
    "pinguin",
    "stern",
    "laterne",
    "truhe",
    "note",
    "fahne",
    "pilz",
    "stein",
    "lumo",
]:
    render(motif)
