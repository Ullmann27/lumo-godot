#!/usr/bin/env python3
"""Möbel und Deko für Lumos Spielzimmer (Kartentisch, Memory, Vier gewinnt).

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_table_art/build_room_props.py [--only table,clock]
Ausgabe: assets/table_room/models/<prop>.glb – je Prop ein Mesh, Flächen nach
Material gruppiert (wenige Draw-Calls). Bewegliche Teile (Uhrzeiger, Pendel)
bleiben eigene, benannte Objekte.

Konvention: Meter, Blender Z oben, Vorderseite zeigt nach −Y (in Godot +Z).
Materialnamen sind Schlüssel – Godot ersetzt sie durch eigene Materialien mit
den selbst erzeugten Texturen aus make_room_textures.py. Vertexfarben tragen
Farbvarianten (Buchrücken, Spieleschachteln, Blätter).
Alles Eigenbau: keine heruntergeladene Geometrie, keine fremden Texturen.
"""
from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy  # bpy zuerst: erst danach ist bmesh importierbar
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "table_room" / "models"
RNG = random.Random(1118)


def linear(hex_color: str) -> tuple:
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


_MATS: dict[str, bpy.types.Material] = {}
BASE = {
    "oak": "c98f5c", "walnut": "6e4630", "felt": "203a7a", "brass": "d6a64f", "cushion": "c0503a",
    "book": "ffffff", "paper": "f3ead6", "glass": "cfe6ff", "lamp_shade": "2f5a4c", "lamp_bulb": "ffd892",
    "leaf": "ffffff", "pot": "b8653d", "soil": "3a2618", "ceramic": "f2efe6", "cocoa": "5a3420",
    "cookie": "d59a55", "choc": "3b2116", "chalkboard": "24392f", "chalk": "f4f1e6", "clock_face": "f3e7cd",
    "iron": "2b2b30", "box": "ffffff", "gold": "f2c14e", "juice": "ff9a2e", "candle": "f6e9cf", "flame": "ffcc66",
    "globe": "3a7bbf", "fabric": "ffffff",
}


def mat(name: str) -> bpy.types.Material:
    if name in _MATS:
        return _MATS[name]
    if "-" in name:
        BASE[name] = name.split("-", 1)[1]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = linear(BASE.get(name, "ffffff"))
    p.inputs["Roughness"].default_value = 0.6
    m.diffuse_color = linear(BASE.get(name, "ffffff"))
    _MATS[name] = m
    return m


def new_object(name: str, bm: bmesh.types.BMesh, material: str, colour: str | None = None, smooth: bool = False,
               uv_mode: str = "box", uv_rect: tuple | None = None) -> bpy.types.Object:
    """bmesh → Objekt mit einem Material, Vertexfarbe und einfacher UV."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv_layer = bm.loops.layers.uv.verify()
    col_layer = bm.loops.layers.color.new("Col") if colour is not None else None
    c = linear(colour) if colour else None
    xs = [v.co.x for v in bm.verts] or [0]
    ys = [v.co.y for v in bm.verts] or [0]
    zs = [v.co.z for v in bm.verts] or [0]
    lo = Vector((min(xs), min(ys), min(zs)))
    span = Vector((max(xs) - lo.x or 1, max(ys) - lo.y or 1, max(zs) - lo.z or 1))
    for face in bm.faces:
        n = face.normal
        for loop in face.loops:
            co = loop.vert.co
            if uv_mode == "top":
                uv = ((co.x - lo.x) / span.x, 1 - (co.y - lo.y) / span.y)
            elif uv_mode == "front":
                uv = ((co.x - lo.x) / span.x, 1 - (co.z - lo.z) / span.z)
            else:
                if abs(n.z) > max(abs(n.x), abs(n.y)):
                    uv = (co.x, co.y)
                elif abs(n.x) > abs(n.y):
                    uv = (co.y, co.z)
                else:
                    uv = (co.x, co.z)
            if uv_rect is not None:
                u0, v0, u1, v1 = uv_rect
                fu = (co.x - lo.x) / span.x if uv_mode != "spine" else 0
                uv = (u0 + (u1 - u0) * ((co.x - lo.x) / span.x), v0 + (v1 - v0) * (1 - (co.z - lo.z) / span.z))
            loop[uv_layer].uv = uv
            if col_layer is not None:
                loop[col_layer] = c
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = smooth
    # Farbvarianten werden eigene Materialien „basis-rrggbb“ (Godot färbt danach ein).
    me.materials.append(mat(f"{material}-{colour}") if colour else mat(material))
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def cube(name, at, size, material, colour=None, rot=(0, 0, 0), bevel=0.0, uv_mode="box", uv_rect=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    rotm = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(at)) @ rotm, verts=bm.verts)
    return new_object(name, bm, material, colour, uv_mode=uv_mode, uv_rect=uv_rect)


def lathe(name, profile, material, segments=24, at=(0, 0, 0), colour=None, smooth=True, cap=True, scale=(1, 1, 1),
          rot=(0, 0, 0)):
    """Drehkörper aus (Radius, Höhe)-Punkten, unten nach oben."""
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        a = math.tau * i / segments
        rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for r, z in profile])
    for i in range(segments):
        ra, rb = rings[i], rings[(i + 1) % segments]
        for k in range(len(profile) - 1):
            bm.faces.new((ra[k], rb[k], rb[k + 1], ra[k + 1]))
    if cap:
        if profile[0][0] > 1e-4:
            bm.faces.new([r[0] for r in reversed(rings)])
        if profile[-1][0] > 1e-4:
            bm.faces.new([r[-1] for r in rings])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    rotm = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(at)) @ rotm, verts=bm.verts)
    return new_object(name, bm, material, colour, smooth=smooth)


def cylinder(name, at, radius, depth, material, segments=20, colour=None, rot=(0, 0, 0), uv_mode="top"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    rotm = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(at)) @ rotm, verts=bm.verts)
    return new_object(name, bm, material, colour, uv_mode=uv_mode)


def torus(name, at, major, minor, material, rot=(0, 0, 0), seg=24, ring=8, colour=None, arc=1.0):
    bm = bmesh.new()
    rings = []
    count = seg if arc >= 1.0 else seg + 1
    for i in range(count):
        a = math.tau * arc * i / seg
        centre = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(centre + out * math.cos(math.tau * k / ring) * minor + Vector((0, 0, math.sin(math.tau * k / ring) * minor)))
                      for k in range(ring)])
    for i in range(seg if arc >= 1.0 else seg):
        ra, rb = rings[i], rings[(i + 1) % len(rings)]
        for k in range(ring):
            bm.faces.new((ra[k], rb[k], rb[(k + 1) % ring], ra[(k + 1) % ring]))
    rotm = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(at)) @ rotm, verts=bm.verts)
    return new_object(name, bm, material, colour, smooth=True)


def leaf(name, base, direction, length, width, droop, material="leaf", colour="4f9a5a"):
    """Gebogenes Blatt aus einem schmalen Streifen (beidseitig im Material)."""
    bm = bmesh.new()
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    steps = 6
    rows = []
    for i in range(steps + 1):
        t = i / steps
        w = width * math.sin(math.pi * min(1.0, t * 1.05)) * (1.0 - 0.25 * t)
        centre = Vector(base) + d * length * t + Vector((0, 0, -droop * t * t))
        rows.append([bm.verts.new(centre - side * w * 0.5), bm.verts.new(centre + Vector((0, 0, 0.008 * math.sin(math.pi * t)))),
                     bm.verts.new(centre + side * w * 0.5)])
    for i in range(steps):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    return new_object(name, bm, material, colour, smooth=True)


def join(objects: list, name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def export(name: str, objects: list) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    path = OUT / f"{name}.glb"
    kwargs = dict(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                  export_animations=False, export_cameras=False, export_lights=False, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    tris = sum(len(p.vertices) - 2 for ob in objects if ob.type == "MESH" for p in ob.data.polygons)
    print(f"[props] {name}: {path.stat().st_size // 1024} KB, ~{tris} Dreiecke")


# ===================================================================== Props


def build_table() -> None:
    """Runder Eichentisch: Filzeinlage, Holzkante mit Kerben, gedrechselte Säule, vier Füße."""
    top_z = 0.98
    radius = 1.25
    parts = []
    # Platte als Drehkörper mit gerundeter Kante (Querschnitt).
    profile = [(0.0, top_z - 0.075), (radius - 0.06, top_z - 0.075), (radius - 0.01, top_z - 0.06), (radius, top_z - 0.035),
               (radius - 0.006, top_z - 0.008), (radius - 0.03, top_z + 0.004), (radius - 0.11, top_z + 0.004),
               (radius - 0.125, top_z - 0.006), (0.0, top_z - 0.006)]
    seg = 128
    bm = bmesh.new()
    rings = []
    notches = {7: 0.012, 8: 0.016, 9: 0.01, 41: 0.008, 42: 0.011, 88: 0.014, 89: 0.009, 109: 0.01}
    for i in range(seg):
        a = math.tau * i / seg
        dent = notches.get(i, 0.0)
        ring = []
        for k, (r, z) in enumerate(profile):
            rr = r - (dent if 2 <= k <= 5 else 0.0)
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    for i in range(seg):
        ra, rb = rings[i], rings[(i + 1) % seg]
        for k in range(len(profile) - 1):
            bm.faces.new((ra[k], rb[k], rb[k + 1], ra[k + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    parts.append(new_object("TableTop", bm, "oak", smooth=True))
    # Filz: Scheibe mit sauberer 0..1-UV (Sternenkreis-Motiv).
    bm = bmesh.new()
    centre = bm.verts.new((0, 0, top_z - 0.004))
    ring = [bm.verts.new((math.cos(math.tau * i / seg) * (radius - 0.12), math.sin(math.tau * i / seg) * (radius - 0.12), top_z - 0.004)) for i in range(seg)]
    for i in range(seg):
        bm.faces.new((centre, ring[i], ring[(i + 1) % seg]))
    parts.append(new_object("Felt", bm, "felt", uv_mode="top"))
    # Zarge unter der Platte, Messing-Beschläge.
    parts.append(lathe("Apron", [(radius - 0.16, top_z - 0.2), (radius - 0.14, top_z - 0.2), (radius - 0.13, top_z - 0.07), (radius - 0.16, top_z - 0.07)],
                       "walnut", seg // 2))
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts.append(cube(f"Fitting{i}", (math.cos(a) * (radius - 0.125), math.sin(a) * (radius - 0.125), top_z - 0.13), (0.05, 0.012, 0.08), "brass",
                          rot=(0, 0, a + math.pi / 2)))
    # Gedrechselte Säule.
    column = [(0.0, 0.2), (0.24, 0.2), (0.24, 0.24), (0.17, 0.27), (0.13, 0.34), (0.15, 0.42), (0.11, 0.5), (0.105, 0.62),
              (0.15, 0.68), (0.15, 0.71), (0.12, 0.74), (0.13, 0.8), (0.3, top_z - 0.2), (0.0, top_z - 0.2)]
    parts.append(lathe("Column", column, "walnut", 28))
    parts.append(torus("ColumnRing", (0, 0, 0.695), 0.152, 0.012, "brass", seg=28, ring=6))
    # Vier geschwungene Füße.
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        bm = bmesh.new()
        steps = 8
        rows = []
        for s in range(steps + 1):
            t = s / steps
            reach = 0.12 + 0.62 * t
            h = 0.2 - 0.17 * math.sin(t * math.pi * 0.5) + 0.03 * t * t
            w = 0.07 * (1 - 0.45 * t)
            th = 0.09 * (1 - 0.5 * t)
            cx, cy = math.cos(a) * reach, math.sin(a) * reach
            sx, sy = -math.sin(a) * w, math.cos(a) * w
            rows.append([bm.verts.new((cx - sx, cy - sy, h - th)), bm.verts.new((cx + sx, cy + sy, h - th)),
                         bm.verts.new((cx + sx, cy + sy, h)), bm.verts.new((cx - sx, cy - sy, h))])
        for s in range(steps):
            ra, rb = rows[s], rows[s + 1]
            for k in range(4):
                bm.faces.new((ra[k], rb[k], rb[(k + 1) % 4], ra[(k + 1) % 4]))
        bm.faces.new(rows[0][::-1])
        bm.faces.new(rows[-1])
        parts.append(new_object(f"Foot{i}", bm, "walnut", smooth=True))
        tip = (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.018)
        parts.append(lathe(f"FootCap{i}", [(0.0, 0.0), (0.04, 0.0), (0.045, 0.02), (0.0, 0.035)], "brass", 12, at=tip))
    export("table", [join(parts, "Table")])


def build_chair() -> None:
    """Holzstuhl mit Kissen, niedriger Rückenlehne aus Sprossen. Sitzhöhe 0,72 m."""
    seat_z = 0.62
    parts = [lathe("Seat", [(0.0, seat_z - 0.05), (0.3, seat_z - 0.05), (0.32, seat_z - 0.02), (0.31, seat_z), (0.0, seat_z)], "oak", 28)]
    parts.append(lathe("Cushion", [(0.0, seat_z), (0.27, seat_z), (0.29, seat_z + 0.03), (0.27, seat_z + 0.085), (0.15, seat_z + 0.1), (0.0, seat_z + 0.1)],
                       "cushion", 24))
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        x, y = math.cos(a) * 0.23, math.sin(a) * 0.23
        top = seat_z - 0.05
        parts.append(lathe(f"Leg{i}", [(0.0, 0.0), (0.024, 0.0), (0.03, top * 0.25), (0.022, top * 0.5), (0.03, top * 0.75), (0.026, top), (0.0, top)],
                           "oak", 10, at=(x, y, 0)))
    parts.append(torus("Stretcher", (0, 0, 0.22), 0.245, 0.014, "oak", seg=24, ring=6))
    # Lehne hinten: Blender −Y wird Godot +Z (vom Tisch weg; die Figur schaut nach −Z).
    for k in range(5):
        a = math.radians(235 + k * 17.5)
        x, y = math.cos(a) * 0.27, math.sin(a) * 0.27
        parts.append(cylinder(f"Spindle{k}", (x, y, seat_z + 0.2), 0.016, 0.42, "oak", 8, uv_mode="box"))
    parts.append(torus("BackRail", (0, 0, seat_z + 0.42), 0.27, 0.03, "oak", rot=(0, 0, math.radians(228)), seg=16, ring=8, arc=0.235))
    export("chair", [join(parts, "Chair")])


BOOK_COLOURS = ["b8433a", "3c74a3", "d39d36", "3f8d5f", "7a54ad", "2f4a7a", "c4683b", "8a2f45", "557a3a", "e0c27a"]


def build_shelf() -> None:
    """Bücherregal 2,0 × 2,2 m: Bücher, Spieleschachteln, Pokale, Globus, Sternenglas."""
    w, h, d = 2.0, 2.2, 0.38
    parts = []
    for side in (-1, 1):
        parts.append(cube(f"Side{side}", (side * (w / 2 - 0.03), 0, h / 2), (0.06, d, h), "walnut", bevel=0.006))
    parts.append(cube("Back", (0, d / 2 - 0.01, h / 2), (w - 0.06, 0.02, h - 0.02), "walnut"))
    parts.append(cube("Crown", (0, -0.01, h + 0.03), (w + 0.1, d + 0.06, 0.06), "walnut", bevel=0.01))
    parts.append(cube("Plinth", (0, -0.01, 0.05), (w, d + 0.02, 0.1), "walnut"))
    levels = [0.1, 0.62, 1.12, 1.62, 2.12]
    for i, z in enumerate(levels[:-1]):
        parts.append(cube(f"Board{i}", (0, 0, z + 0.015), (w - 0.06, d - 0.02, 0.03), "oak", bevel=0.004))
    parts.append(cube("BoardTop", (0, 0, levels[-1] + 0.015), (w - 0.06, d - 0.02, 0.03), "oak"))
    rng = random.Random(7)
    for shelf, z in enumerate(levels[:-1]):
        x = -w / 2 + 0.08
        base = z + 0.03
        while x < w / 2 - 0.12:
            pick = rng.random()
            if shelf == 1 and abs(x + 0.35) < 0.05:
                # Pokal.
                parts.append(lathe("Trophy", [(0.0, 0.0), (0.07, 0.0), (0.07, 0.02), (0.025, 0.04), (0.02, 0.1), (0.04, 0.12), (0.085, 0.2),
                                               (0.09, 0.27), (0.075, 0.27), (0.0, 0.16)], "gold", 20, at=(x + 0.08, 0, base)))
                for s in (-1, 1):
                    parts.append(torus("Handle", (x + 0.08 + s * 0.09, 0, base + 0.21), 0.035, 0.008, "gold", rot=(math.pi / 2, 0, 0), seg=12, ring=5))
                x += 0.2
                continue
            if shelf == 2 and abs(x - 0.45) < 0.05:
                # Globus auf Fuß.
                parts.append(lathe("GlobeFoot", [(0.0, 0.0), (0.07, 0.0), (0.06, 0.02), (0.015, 0.04), (0.012, 0.09), (0.0, 0.09)], "brass", 16, at=(x + 0.1, 0, base)))
                parts.append(lathe("Globe", [(math.sin(math.pi * k / 10) * 0.11, -math.cos(math.pi * k / 10) * 0.11) for k in range(11)], "globe", 20,
                                   at=(x + 0.1, 0, base + 0.2)))
                parts.append(torus("GlobeRing", (x + 0.1, 0, base + 0.2), 0.125, 0.006, "brass", rot=(math.pi / 2, 0.4, 0), seg=24, ring=4))
                x += 0.25
                continue
            if shelf == 0 and pick < 0.45:
                # Stapel Spieleschachteln (liegend).
                height = base
                bw = 0.36 + rng.random() * 0.1
                for k in range(rng.randint(2, 4)):
                    bh = 0.05 + rng.random() * 0.03
                    c = BOOK_COLOURS[rng.randrange(len(BOOK_COLOURS))]
                    parts.append(cube("GameBox", (x + bw / 2, -0.01, height + bh / 2), (bw - k * 0.02, 0.28 - k * 0.01, bh), "box", c,
                                      rot=(0, 0, (rng.random() - 0.5) * 0.12), bevel=0.003))
                    height += bh
                x += bw + 0.04
                continue
            if pick < 0.12 and shelf != 0:
                # Sternenglas (leuchtet in Godot).
                parts.append(lathe("StarJar", [(0.0, 0.0), (0.06, 0.0), (0.065, 0.12), (0.045, 0.15), (0.0, 0.15)], "glass", 16, at=(x + 0.07, 0, base)))
                parts.append(cylinder("JarLid", (x + 0.07, 0, base + 0.16), 0.047, 0.025, "brass", 14))
                x += 0.16
                continue
            # Reihe Bücher, eins manchmal schräg angelehnt.
            for k in range(rng.randint(4, 9)):
                if x > w / 2 - 0.12:
                    break
                bw = 0.03 + rng.random() * 0.03
                bh = 0.26 + rng.random() * 0.14
                bd = 0.2 + rng.random() * 0.08
                col = rng.randrange(8)
                lean = 0.0
                if k == 0 and rng.random() < 0.3:
                    lean = -0.25
                parts.append(cube("Book", (x + bw / 2 + (bh * 0.12 if lean else 0), -0.02, base + bh / 2 - (0.01 if lean else 0)), (bw, bd, bh), "book",
                                  BOOK_COLOURS[rng.randrange(len(BOOK_COLOURS))], rot=(0, lean, 0), uv_mode="spine",
                                  uv_rect=(col / 8, 0.0, (col + 1) / 8, 1.0)))
                x += bw + 0.003 + (0.05 if lean else 0)
            x += 0.05 + rng.random() * 0.05
    export("shelf", [join(parts, "Shelf")])


def build_clock() -> None:
    """Wanduhr mit Pendel. Zeiger und Pendel bleiben eigene Objekte (drehen in Godot)."""
    parts = []
    parts.append(lathe("Case", [(0.0, -0.04), (0.3, -0.04), (0.33, -0.01), (0.33, 0.02), (0.3, 0.04), (0.27, 0.04), (0.27, 0.02), (0.0, 0.02)],
                       "walnut", 40, rot=(math.pi / 2, 0, 0)))
    parts.append(cylinder("Face", (0, -0.025, 0), 0.268, 0.004, "clock_face", 40, rot=(math.pi / 2, 0, 0), uv_mode="front"))
    parts.append(torus("Bezel", (0, -0.042, 0), 0.275, 0.012, "brass", rot=(math.pi / 2, 0, 0), seg=40, ring=6))
    parts.append(cube("PendulumBox", (0, 0.0, -0.55), (0.24, 0.07, 0.56), "walnut", bevel=0.01))
    parts.append(cube("PendulumWindow", (0, -0.037, -0.55), (0.17, 0.004, 0.44), "iron"))
    parts.append(lathe("Finial", [(0.0, 0.0), (0.03, 0.0), (0.02, 0.04), (0.035, 0.07), (0.0, 0.11)], "brass", 12, at=(0, 0, 0.33)))
    body = join(parts, "ClockBody")
    hour = cube("HourHand", (0, -0.05, 0.07), (0.022, 0.006, 0.16), "iron")
    hour_tip = cube("HourTip", (0, -0.05, 0.15), (0.04, 0.006, 0.03), "iron", rot=(0, math.pi / 4, 0))
    hour = join([hour, hour_tip], "HourHand")
    minute = cube("MinuteHand", (0, -0.056, 0.1), (0.014, 0.006, 0.22), "iron")
    cap = cylinder("Cap", (0, -0.06, 0), 0.018, 0.012, "brass", 12, rot=(math.pi / 2, 0, 0))
    minute = join([minute, cap], "MinuteHand")
    rod = cube("Rod", (0, -0.042, -0.18), (0.008, 0.004, 0.32), "brass")
    bob = cylinder("Bob", (0, -0.044, -0.36), 0.045, 0.01, "brass", 18, rot=(math.pi / 2, 0, 0))
    pendulum = join([rod, bob], "Pendulum")
    # Pendel dreht um seinen Aufhängepunkt: Ursprung oben.
    pendulum.location = (0, 0, 0)
    for ob in (pendulum,):
        for v in ob.data.vertices:
            v.co.z += 0.0
    pendulum.location = (0, 0, -0.32)
    for v in pendulum.data.vertices:
        v.co.z += 0.32
    export("clock", [body, hour, minute, pendulum])


def build_lamp() -> None:
    """Hängelampe: Metallschirm, Glühbirne, Kette, Deckenrosette. Ursprung = Birne."""
    parts = []
    shade = [(0.06, 0.32), (0.09, 0.3), (0.2, 0.2), (0.32, 0.06), (0.36, 0.0), (0.355, -0.012), (0.31, 0.04), (0.18, 0.17), (0.08, 0.27), (0.05, 0.29)]
    parts.append(lathe("Shade", shade, "lamp_shade", 36, cap=False))
    parts.append(torus("ShadeRim", (0, 0, -0.004), 0.36, 0.008, "brass", seg=36, ring=6))
    parts.append(lathe("Socket", [(0.0, 0.3), (0.06, 0.3), (0.05, 0.4), (0.035, 0.42), (0.0, 0.42)], "brass", 16))
    for k in range(10):
        parts.append(torus("Link", (0, 0, 0.45 + k * 0.05), 0.016, 0.004, "brass", rot=(math.pi / 2, 0, (k % 2) * math.pi / 2), seg=10, ring=4))
    body = join(parts, "LampBody")
    bulb = lathe("Bulb", [(0.0, 0.05), (0.05, 0.07), (0.075, 0.12), (0.06, 0.18), (0.03, 0.22), (0.0, 0.22)], "lamp_bulb", 18)
    export("lamp", [body, bulb])


def build_window() -> None:
    """Rundbogenfenster 2,4 × 2,6 m mit Sprossen und Sims. Ursprung unten Mitte."""
    w, h = 2.4, 2.6
    spring = h - w / 2
    parts = []
    for side in (-1, 1):
        parts.append(cube("Jamb", (side * (w / 2 + 0.06), 0, spring / 2 + 0.4), (0.14, 0.24, spring - 0.8 + 0.02), "oak", bevel=0.01))
    parts.append(torus("Arch", (0, 0, spring), w / 2 + 0.06, 0.08, "oak", rot=(math.pi / 2, 0, 0), seg=28, ring=8, arc=0.5))
    parts.append(cube("Sill", (0, -0.1, 0.38), (w + 0.5, 0.42, 0.07), "oak", bevel=0.012))
    parts.append(cube("Apron", (0, 0.0, 0.3), (w + 0.2, 0.18, 0.12), "walnut"))
    for k in range(1, 4):
        x = -w / 2 + k * w / 4
        top = spring + math.sqrt(max(0.0, (w / 2) ** 2 - x * x)) - 0.02
        parts.append(cube("Mullion", (x, 0.02, (0.42 + top) / 2), (0.035, 0.05, top - 0.42), "walnut"))
    for z in (1.3, spring):
        parts.append(cube("Transom", (0, 0.02, z), (w, 0.05, 0.035), "walnut"))
    # Blumenkasten und Kerze auf dem Sims.
    parts.append(lathe("Candle", [(0.0, 0.0), (0.035, 0.0), (0.035, 0.16), (0.0, 0.16)], "candle", 12, at=(0.85, -0.18, 0.415)))
    parts.append(lathe("CandleDish", [(0.0, 0.0), (0.08, 0.0), (0.085, 0.015), (0.0, 0.01)], "brass", 14, at=(0.85, -0.18, 0.415)))
    body = join(parts, "WindowFrame")
    flame = lathe("Flame", [(0.0, 0.0), (0.012, 0.012), (0.01, 0.03), (0.0, 0.05)], "flame", 8, at=(0.85, -0.18, 0.585))
    export("window", [body, flame])


def build_plant() -> None:
    """Topfpflanze mit großen gebogenen Blättern (Vertexfarben in zwei Grüntönen)."""
    parts = [lathe("Pot", [(0.0, 0.0), (0.16, 0.0), (0.2, 0.05), (0.23, 0.36), (0.25, 0.38), (0.25, 0.42), (0.21, 0.42), (0.2, 0.38), (0.0, 0.36)],
                   "pot", 24)]
    parts.append(cylinder("Soil", (0, 0, 0.37), 0.205, 0.02, "soil", 20))
    rng = random.Random(3)
    for k in range(13):
        a = k * 2.39996 + rng.random() * 0.3
        up = 0.35 + rng.random() * 0.55
        d = (math.cos(a) * (1 - up * 0.5), math.sin(a) * (1 - up * 0.5), up)
        length = 0.42 + rng.random() * 0.3
        parts.append(leaf("Leaf", (math.cos(a) * 0.03, math.sin(a) * 0.03, 0.38 + rng.random() * 0.05), d, length, 0.16 + rng.random() * 0.07,
                          0.2 + rng.random() * 0.15, colour="3f8f55" if k % 3 else "6cbf6f"))
    export("plant", [join(parts, "Plant")])


def build_snacks() -> None:
    """Kakaobecher, Keksteller, Saftglas – für den Tischrand. Ursprung = Tischfläche."""
    mug = [lathe("Mug", [(0.0, 0.0), (0.04, 0.0), (0.045, 0.005), (0.045, 0.09), (0.04, 0.09), (0.039, 0.01), (0.0, 0.01)], "ceramic", 20)]
    mug.append(torus("MugHandle", (0.055, 0, 0.05), 0.022, 0.006, "ceramic", rot=(math.pi / 2, 0, 0), seg=12, ring=5))
    mug.append(cylinder("Cocoa", (0, 0, 0.075), 0.039, 0.004, "cocoa", 16))
    mug.append(cube("MugStar", (0, -0.046, 0.05), (0.03, 0.004, 0.03), "gold", rot=(0, math.pi / 4, 0)))
    mug_ob = join(mug, "Mug")
    plate = [lathe("Plate", [(0.0, 0.0), (0.08, 0.0), (0.11, 0.012), (0.12, 0.018), (0.0, 0.008)], "ceramic", 28)]
    rng = random.Random(9)
    for k in range(5):
        a = k * 1.3
        r = 0.0 if k == 0 else 0.055
        z = 0.015 + (0.012 if k == 0 else 0.0)
        at = (math.cos(a) * r, math.sin(a) * r, z)
        plate.append(lathe("Cookie", [(0.0, 0.0), (0.035, 0.0), (0.038, 0.006), (0.033, 0.011), (0.0, 0.012)], "cookie", 14, at=at,
                           rot=(0.08 * (k % 2), 0.06 * ((k + 1) % 2), 0)))
        for c in range(4):
            ca = rng.random() * math.tau
            cr = rng.random() * 0.025
            plate.append(cube("Chip", (at[0] + math.cos(ca) * cr, at[1] + math.sin(ca) * cr, z + 0.012), (0.008, 0.008, 0.005), "choc", rot=(0, 0, ca)))
    plate.append(cube("Crumb", (0.15, 0.02, 0.002), (0.006, 0.005, 0.003), "cookie"))
    plate.append(cube("Crumb2", (0.13, -0.05, 0.002), (0.004, 0.005, 0.003), "cookie"))
    plate_ob = join(plate, "CookiePlate")
    glass = [lathe("Glass", [(0.0, 0.0), (0.03, 0.0), (0.034, 0.11), (0.031, 0.11), (0.027, 0.006), (0.0, 0.006)], "glass", 18)]
    glass.append(lathe("Juice", [(0.0, 0.006), (0.027, 0.006), (0.03, 0.075), (0.0, 0.075)], "juice", 16))
    glass.append(cylinder("Straw", (0.012, 0, 0.1), 0.004, 0.14, "cushion", 6, rot=(0.25, 0, 0)))
    glass_ob = join(glass, "JuiceGlass")
    export("snacks", [mug_ob, plate_ob, glass_ob])


def build_scoreboard() -> None:
    """Kreidetafel im Holzrahmen mit Ablage, Kreide und Schwamm. Ursprung unten Mitte, Tafel 1,1 × 0,8."""
    w, h = 1.1, 0.8
    parts = [cube("Board", (0, 0, h / 2), (w, 0.01, h), "chalkboard", uv_mode="front")]
    for side in (-1, 1):
        parts.append(cube("FrameV", (side * (w / 2 + 0.03), -0.01, h / 2), (0.06, 0.04, h + 0.12), "oak", bevel=0.006))
        parts.append(cube("FrameH", (0, -0.01, h / 2 + side * (h / 2 + 0.03)), (w, 0.04, 0.06), "oak", bevel=0.006))
    parts.append(cube("Tray", (0, -0.05, -0.02), (w * 0.8, 0.08, 0.02), "oak"))
    for k, c in enumerate(["f4f1e6", "ffd36a", "8fe0ff"]):
        parts.append(cylinder("Chalk", (-0.25 + k * 0.07, -0.05, -0.002), 0.007, 0.06, "chalk", 8, rot=(0, math.pi / 2, 0.2 * k)))
        parts[-1].data.materials.clear()
        parts[-1].data.materials.append(mat("chalk"))
    parts.append(cube("Sponge", (0.25, -0.05, 0.01), (0.1, 0.05, 0.035), "box", "c88a3a", bevel=0.006))
    parts.append(cube("Nail", (0, 0.0, h + 0.14), (0.02, 0.02, 0.02), "iron"))
    export("scoreboard", [join(parts, "Scoreboard")])


BUILDERS = {
    "table": build_table, "chair": build_chair, "shelf": build_shelf, "clock": build_clock, "lamp": build_lamp,
    "window": build_window, "plant": build_plant, "snacks": build_snacks, "scoreboard": build_scoreboard,
}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    names = [n for n in args.only.split(",") if n] or list(BUILDERS)
    for name in names:
        reset_scene()
        BUILDERS[name]()


if __name__ == "__main__":
    main()
