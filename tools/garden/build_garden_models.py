#!/usr/bin/env python3
"""Lumos Riesengarten: Wahrzeichen in Blender (bpy), alles selbst modelliert.

Aufruf: /home/user/tools/bpyenv/bin/python tools/garden/build_garden_models.py [name ...]
Ausgabe: assets/kart/riesengarten/models/<name>.glb mit Objekten <name>_lod0/_lod1/_lod2
und assets/kart/riesengarten/models/garden_models.json (Dreiecke je Stufe, Bytes).

Bauweise: Drehkörper, Rohre entlang Kurven, geformte Blätter; Fasen und gewichtete
Normalen (Modifier angewendet), getrennte PBR-Materialien (glTF), keine Texturen.
LOD1/LOD2 entstehen per Decimate (0,45 / 0,16) aus LOD0. Blender: Z oben, Y vorn
(glTF-Export mit +Y oben: Blender +Y wird in Godot -Z = Fahrtrichtung).
Einheit Meter; die Teile werden in Godot auf ihre Streckengröße skaliert, wo angegeben.
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import bpy  # noqa: I001 – bpy zuerst, es stellt bmesh/mathutils bereit
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/kart/riesengarten/models"
MATS: dict = {}


# ----------------------------------------------------------------- Grundwerkzeuge


def material(name, color, rough=0.6, metal=0.0, emission=None, strength=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except (AttributeError, TypeError):
        pass
    m.diffuse_color = (*color, 1.0)
    bsdf = None
    if m.node_tree is not None:
        for node in m.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                bsdf = node
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = strength
    MATS[name] = m
    return m


def obj_from_bmesh(name, bm, mats):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    mesh.validate(clean_customdata=False)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    return o


def lathe(bm, profile, segments, mat=0, offset=(0, 0, 0), cap_top=False, cap_bottom=False, ribs=0, rib_depth=0.0):
    """Drehkörper um Z: profile = [(r, z), ...] von unten nach oben."""
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            rr = r
            if ribs:
                rr = r * (1.0 - rib_depth * (1.0 - abs(math.cos(a * ribs / 2.0))) ** 1.6)
            ring.append(bm.verts.new((offset[0] + rr * math.cos(a), offset[1] + rr * math.sin(a), offset[2] + z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            f.material_index = mat
            f.smooth = True
    if cap_bottom:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = mat
    if cap_top:
        f = bm.faces.new(rings[-1])
        f.material_index = mat
    return rings


def tube(bm, points, radii, segments=10, mat=0, cap=True):
    """Rohr entlang einer Punktliste (Vector), Radius je Punkt."""
    frames = []
    prev_n = None
    for i, p in enumerate(points):
        if i == 0:
            t = (points[1] - points[0]).normalized()
        elif i == len(points) - 1:
            t = (points[-1] - points[-2]).normalized()
        else:
            t = (points[i + 1] - points[i - 1]).normalized()
        if prev_n is None:
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(up).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n).normalized()
        frames.append((p, n, b))
    rings = []
    for (p, n, b), r in zip(frames, radii):
        ring = [bm.verts.new(p + (n * math.cos(2 * math.pi * i / segments) + b * math.sin(2 * math.pi * i / segments)) * r)
                for i in range(segments)]
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            f.material_index = mat
            f.smooth = True
    if cap:
        f = bm.faces.new(list(reversed(rings[0])))
        f.material_index = mat
        f = bm.faces.new(rings[-1])
        f.material_index = mat
    return rings


def leaf(bm, base, direction, side, length, width, mat=0, droop=0.25, curl=0.12, rows=10, cols=6, heart=False, lobes=0):
    """Blatt mit Mittelrippe: Gitter, Umriss über die Länge, Hängen und Rollen."""
    direction = direction.normalized()
    side = (side - direction * side.dot(direction)).normalized()
    normal = direction.cross(side).normalized()
    grid = []
    for i in range(rows + 1):
        u = i / rows
        if heart:
            outline = math.sin(math.pi * min(1.0, u * 1.1)) ** 0.7 * (1.0 - 0.25 * u)
        else:
            outline = math.sin(math.pi * u) ** 0.8
        if lobes:
            outline *= 0.82 + 0.18 * abs(math.cos(u * math.pi * lobes))
        row = []
        for j in range(cols + 1):
            v = j / cols * 2.0 - 1.0
            w = v * outline * width * 0.5
            along = u * length
            drop = -droop * length * u * u
            fold = -abs(v) * curl * width + (0.04 * width if abs(v) < 0.2 else 0.0)
            p = base + direction * along + side * w + normal * (drop + fold)
            row.append(bm.verts.new(p))
        grid.append(row)
    for i in range(rows):
        for j in range(cols):
            f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
            f.material_index = mat
            f.smooth = True
    return grid


def sphere(bm, center, radius, mat=0, segments=12, rings=8, scale=(1, 1, 1)):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    for v in ret["verts"]:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
    for f in {f for v in ret["verts"] for f in v.link_faces}:
        f.material_index = mat
        f.smooth = True
    return ret["verts"]


def box(bm, center, size, mat=0, rot=None):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Diagonal((*size, 1.0))
    if rot is not None:
        m = rot.to_4x4() @ m
    for v in ret["verts"]:
        v.co = (m @ v.co.to_4d()).to_3d() + Vector(center)
    for f in {f for v in ret["verts"] for f in v.link_faces}:
        f.material_index = mat
    return ret["verts"]


def finish(o, bevel=0.0, smooth_angle=50.0):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    if bevel > 0.0:
        mod = o.modifiers.new("Fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
    mod = o.modifiers.new("Normalen", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    o.select_set(False)
    return o


def lods(name, lod0):
    """LOD0 benennen, LOD1/LOD2 als vereinfachte Kopien."""
    lod0.name = f"{name}_lod0"
    result = [lod0]
    for level, ratio in ((1, 0.45), (2, 0.16)):
        copy = lod0.copy()
        copy.data = lod0.data.copy()
        copy.name = f"{name}_lod{level}"
        bpy.context.collection.objects.link(copy)
        bpy.context.view_layer.objects.active = copy
        mod = copy.modifiers.new("Vereinfachen", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        copy.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        copy.data.validate(clean_customdata=False)
        copy.select_set(False)
        result.append(copy)
    return result


def triangles(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(name, objects, report):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = OUT / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_yup=True, export_normals=True, export_tangents=False,
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_animations=False, export_apply=True)
    report[name] = {"triangles": [triangles(o) for o in objects], "bytes": path.stat().st_size}
    for o in objects:
        bpy.data.objects.remove(o, do_unlink=True)


# ----------------------------------------------------------------- Modelle


def sunflower():
    """Riesen-Sonnenblume: 48 m Stängel, Blüte 22 m, zum Start geneigt (+Y)."""
    green = material("stem_green", (0.22, 0.45, 0.14), 0.55)
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    disk = material("seed_brown", (0.22, 0.12, 0.05), 0.8)
    seed = material("seed_dark", (0.10, 0.06, 0.03), 0.7)
    petal = material("petal_yellow", (1.0, 0.74, 0.06), 0.45)
    petal2 = material("petal_orange", (0.98, 0.55, 0.05), 0.45)
    bm = bmesh.new()
    stem = [Vector((0.25 * math.sin(t * 2.4), 6.0 * t * t, 44.0 * t)) for t in [i / 16 for i in range(17)]]
    tube(bm, stem, [1.5 - 0.7 * (i / 16) for i in range(17)], 14, 0)
    rnd = random.Random(7)
    for k in range(7):
        t = 0.16 + k * 0.1
        p = stem[int(t * 16)]
        ang = k * 2.4
        d = Vector((math.cos(ang), math.sin(ang), 0.25)).normalized()
        leaf(bm, p, d, Vector((0, 0, 1)).cross(d), 11.0 - k * 0.7, 7.5 - k * 0.4, 1, droop=0.35, curl=0.18, heart=True, rows=12, cols=8)
    head = stem[-1] + Vector((0, 1.2, 1.0))
    tilt = Matrix.Rotation(math.radians(-58), 3, "X")
    bm2 = bmesh.new()
    lathe(bm2, [(0.0, -1.2), (4.0, -1.6), (7.4, -0.9), (7.8, -0.2), (7.2, 0.5), (4.0, 1.0), (0.0, 1.15)], 40, 2)
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(360):
        r = 6.9 * math.sqrt((i + 0.5) / 360)
        a = i * golden
        z = 1.15 - 0.35 * (r / 7.0) ** 2
        sphere(bm2, (r * math.cos(a), r * math.sin(a), z), 0.23, 3, 6, 4, (1, 1, 0.7))
    for ring, (count, length, width, lift, mat) in enumerate(((26, 7.5, 2.6, 0.15, 4), (26, 6.8, 2.3, 0.45, 5))):
        for i in range(count):
            a = 2 * math.pi * (i + 0.5 * ring) / count
            d = Vector((math.cos(a), math.sin(a), lift)).normalized()
            base = Vector((math.cos(a) * 7.2, math.sin(a) * 7.2, 0.2 + ring * 0.3))
            leaf(bm2, base, d, Vector((-math.sin(a), math.cos(a), 0)), length + rnd.uniform(-0.5, 0.5), width, mat,
                 droop=-0.06 - 0.04 * ring, curl=0.10, rows=6, cols=4)
    for i in range(22):
        a = 2 * math.pi * i / 22
        d = Vector((math.cos(a), math.sin(a), -0.5)).normalized()
        base = Vector((math.cos(a) * 6.5, math.sin(a) * 6.5, -1.0))
        leaf(bm2, base, d, Vector((-math.sin(a), math.cos(a), 0)), 3.2, 1.6, 1, droop=0.1, curl=0.1, rows=4, cols=2)
    for v in bm2.verts:
        v.co = tilt @ v.co + head
    o1 = obj_from_bmesh("sonnenblume_stem", bm, [green, leafm, disk, seed, petal, petal2])
    o2 = obj_from_bmesh("sonnenblume_head", bm2, [green, leafm, disk, seed, petal, petal2])
    return join([o1, o2])


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.select_set(False)
    return o


def watering_can():
    """Liegende Gießkanne: Ursprung = Fahrbahnmitte an der Rumpföffnung, Y = Fahrtrichtung.
    Rumpf 47 m (Radius 11, Achse 8,83 m über der Fahrbahn), Ausguss 16 m (Radius 4,6),
    um 10,4° steigend wie die Schanze (2,2 m auf 12 m)."""
    paint = material("can_green", (0.16, 0.50, 0.30), 0.38, 0.35)
    inside = material("can_inner", (0.42, 0.50, 0.48), 0.42, 0.7)
    brass = material("can_brass", (0.90, 0.66, 0.24), 0.28, 0.9)
    bm = bmesh.new()
    axis_z = 8.83
    rot = Matrix.Rotation(math.radians(-90), 4, "X")  # Lathe-Z -> +Y
    body = bmesh.new()
    lathe(body, [(11.0, 0.0), (11.0, 46.2), (10.4, 47.0), (0.0, 47.0)], 48, 0)
    lathe(body, [(10.4, 46.4), (10.4, 0.0)], 48, 1)
    lathe(body, [(10.4, 0.0), (11.0, 0.0)], 48, 0)
    torus = bmesh.ops.create_cone(body, cap_ends=False, segments=48, radius1=11.6, radius2=11.6, depth=1.2)
    for f in {f for v in torus["verts"] for f in v.link_faces}:
        f.material_index = 2
    for v in body.verts:
        v.co = (rot @ v.co.to_4d()).to_3d() + Vector((0, 0, axis_z))
    # Ausguss-Rohr: steigt mit der Schanze, Trompete am Ende.
    spout_pts = []
    radii = []
    for i in range(19):
        y = 46.0 + i * 1.0
        ramp = max(0.0, min(2.2, (y - 48.0) / 12.0 * 2.2))
        spout_pts.append(Vector((0, y, ramp + 2.27)))
        flare = max(0.0, (i - 14) / 4.0)
        radii.append(4.6 + 0.1 * i / 18 + 1.6 * flare * flare)
    tube(body, spout_pts, [r + 0.45 for r in radii], 28, 0, cap=False)
    tube(body, spout_pts, radii, 28, 1, cap=False)
    tip = spout_pts[-1]
    lip = bmesh.new()
    lathe(lip, [(radii[-1] + 0.45, 0.0), (radii[-1] + 0.75, 0.25), (radii[-1], 0.3)], 28, 2)
    for v in lip.verts:
        v.co = Matrix.Rotation(math.radians(-90), 3, "X") @ v.co + tip
    bm_merge(body, lip)
    # Henkel: breites Band über den Rumpf.
    handle = [Vector((0, 8 + 30 * t, axis_z + 11 + 7.5 * math.sin(math.pi * t))) for t in [i / 20 for i in range(21)]]
    tube(body, handle, [1.1] * 21, 12, 0)
    for y in (8.0, 38.0):
        tube(body, [Vector((0, y, axis_z + 10.4)), Vector((0, y, axis_z + 11.8))], [1.6, 1.4], 12, 2)
    # Bänder am Rumpf.
    for y in (3.0, 44.0):
        band = bmesh.ops.create_cone(body, cap_ends=False, segments=48, radius1=11.25, radius2=11.25, depth=0.8)
        for v in band["verts"]:
            v.co = (rot @ v.co.to_4d()).to_3d() + Vector((0, y, axis_z))
        for f in {f for v in band["verts"] for f in v.link_faces}:
            f.material_index = 2
    o = obj_from_bmesh("giesskanne", body, [paint, inside, brass])
    bm.free()
    # Loch im Kannenboden für den Ausguss.
    cutter_bm = bmesh.new()
    tube(cutter_bm, [Vector((0, 45.5, 2.27)), Vector((0, 48.5, 2.27 + 0.2))], [4.55, 4.55], 28, 0)
    cutter = obj_from_bmesh("cutter", cutter_bm, [paint])
    mod = o.modifiers.new("Ausgussloch", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return finish(o)


def lilypad():
    """Riesen-Seerosenblatt (Einheitsradius 1): flach, aufgebogener roter Rand, Adern."""
    top = material("pad_green", (0.22, 0.48, 0.14), 0.42)
    rim = material("pad_rim", (0.62, 0.16, 0.22), 0.5)
    bm = bmesh.new()
    rings = 9
    seg = 56
    center = bm.verts.new((0, 0, 0.02))
    prev = None
    for k in range(1, rings + 1):
        r = k / rings * 0.9
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            vein = 0.006 * (abs(math.cos(a * 9)) ** 8)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0.02 - vein + 0.01 * r)))
        if prev is None:
            for i in range(seg):
                f = bm.faces.new((center, ring[i], ring[(i + 1) % seg]))
                f.material_index = 0
                f.smooth = True
        else:
            for i in range(seg):
                j = (i + 1) % seg
                f = bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
                f.material_index = 0
                f.smooth = True
        prev = ring
    for (r, z, mat) in ((0.95, 0.07, 1), (0.99, 0.14, 1), (0.985, 0.17, 1), (0.95, 0.15, 1)):
        ring = [bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)]
        for i in range(seg):
            j = (i + 1) % seg
            f = bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
            f.material_index = mat
            f.smooth = True
        prev = ring
    return finish(obj_from_bmesh("seerose_blatt", bm, [top, rim]))


def lily_flower():
    white = material("lily_white", (0.98, 0.90, 0.94), 0.5)
    pink = material("lily_pink", (0.96, 0.52, 0.70), 0.5)
    yellow = material("lily_yellow", (1.0, 0.80, 0.15), 0.6)
    bm = bmesh.new()
    for layer, (count, length, width, lift, mat) in enumerate(((10, 1.0, 0.42, 0.25, 1), (9, 0.85, 0.38, 0.65, 0), (7, 0.6, 0.3, 1.1, 0))):
        for i in range(count):
            a = 2 * math.pi * (i + 0.5 * layer) / count
            d = Vector((math.cos(a), math.sin(a), lift)).normalized()
            leaf(bm, Vector((0, 0, 0.05 * layer)), d, Vector((-math.sin(a), math.cos(a), 0)), length, width, mat,
                 droop=-0.12, curl=0.18, rows=6, cols=4)
    lathe(bm, [(0.0, 0.1), (0.2, 0.12), (0.22, 0.28), (0.0, 0.3)], 16, 2)
    return finish(obj_from_bmesh("seerose_bluete", bm, [white, pink, yellow]))


def flower_pot():
    """Terrakottatopf (oben Radius 1, Höhe 1) mit Wulstrand und Erde."""
    clay = material("terracotta", (0.78, 0.38, 0.20), 0.85)
    clay2 = material("terracotta_rim", (0.84, 0.45, 0.25), 0.8)
    soil = material("soil", (0.20, 0.13, 0.08), 0.95)
    bm = bmesh.new()
    lathe(bm, [(0.0, 0.0), (0.74, 0.0), (0.78, 0.02), (0.95, 0.84), (0.97, 0.86)], 48, 0)
    lathe(bm, [(0.97, 0.86), (1.05, 0.87), (1.07, 0.9), (1.07, 0.99), (1.03, 1.01), (0.95, 1.0)], 48, 1)
    lathe(bm, [(0.95, 1.0), (0.92, 0.96), (0.91, 0.93), (0.0, 0.93)], 48, 2)
    return finish(obj_from_bmesh("blumentopf", bm, [clay, clay2, soil]))


def hose_coupling():
    """Schlauchkupplung als Tor (Einheitsradius 1 = Schlauch-Innenradius)."""
    orange = material("coupling_orange", (0.98, 0.45, 0.08), 0.4, 0.05)
    grey = material("coupling_grey", (0.30, 0.33, 0.36), 0.35, 0.2)
    bm = bmesh.new()
    rot = Matrix.Rotation(math.radians(-90), 3, "X")
    lathe(bm, [(1.0, -0.3), (1.12, -0.3), (1.16, -0.2), (1.16, 0.25), (1.12, 0.3), (1.0, 0.3)], 48, 1, ribs=0)
    lathe(bm, [(1.0, 0.3), (1.2, 0.32), (1.26, 0.45), (1.26, 0.9), (1.2, 0.98), (1.0, 1.0)], 48, 0, ribs=12, rib_depth=0.04)
    for v in bm.verts:
        v.co = rot @ v.co
    return finish(obj_from_bmesh("schlauchkupplung", bm, [orange, grey]))


def locomotive():
    """Spielzeug-Gartenbahn-Lok (11 m lang, Y vorn)."""
    red = material("loco_red", (0.82, 0.12, 0.10), 0.35, 0.2)
    black = material("loco_black", (0.06, 0.06, 0.07), 0.45, 0.4)
    green = material("loco_green", (0.10, 0.42, 0.24), 0.4, 0.15)
    gold = material("loco_gold", (0.95, 0.72, 0.22), 0.25, 0.95)
    bm = bmesh.new()
    box(bm, (0, 0.5, 1.2), (3.8, 11.0, 0.7), 1)
    rot = Matrix.Rotation(math.radians(-90), 3, "X")
    boiler = bmesh.new()
    lathe(boiler, [(0.0, 0.0), (1.55, 0.0), (1.55, 6.4), (1.62, 6.5), (1.62, 7.2), (0.0, 7.3)], 28, 0)
    for v in boiler.verts:
        v.co = rot @ v.co + Vector((0, -1.0, 2.9))
    bm_merge(bm, boiler)
    for y, mat in ((-0.6, 3), (1.9, 3), (4.4, 3)):
        tube(bm, [Vector((0, y, 2.9)), Vector((0, y + 0.3, 2.9))], [1.66, 1.66], 28, mat)
    tube(bm, [Vector((0, 5.0, 4.2)), Vector((0, 5.0, 5.6)), Vector((0, 5.0, 6.0))], [0.55, 0.62, 0.85], 16, 1)
    sphere(bm, (0, 2.2, 4.45), 0.75, 3, 16, 8, (1, 1, 0.9))
    box(bm, (0, -3.4, 3.4), (3.6, 2.8, 3.6), 2)
    box(bm, (0, -3.4, 5.4), (4.2, 3.4, 0.35), 1)
    box(bm, (0, -3.4, 3.8), (3.7, 1.4, 1.2), 1)
    for x in (-1.75, 1.75):
        for y in (-2.6, 0.4, 3.2):
            tube(bm, [Vector((x, y, 1.15)), Vector((x * 1.12, y, 1.15))], [1.1, 1.1], 18, 0)
            tube(bm, [Vector((x * 1.12, y, 1.15)), Vector((x * 1.16, y, 1.15))], [0.35, 0.35], 10, 3)
    box(bm, (0, 6.1, 1.3), (4.2, 0.4, 0.9), 0)
    for x in (-1.4, 1.4):
        tube(bm, [Vector((x, 6.2, 1.4)), Vector((x, 6.9, 1.4))], [0.35, 0.35], 10, 3)
    sphere(bm, (0, 6.1, 3.0), 0.45, 3, 12, 6)
    return finish(obj_from_bmesh("gartenbahn_lok", bm, [red, black, green, gold]), 0.04)


def bm_merge(target, source):
    mesh = bpy.data.meshes.new("tmp")
    source.to_mesh(mesh)
    source.free()
    target.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def wagon():
    yellow = material("wagon_yellow", (0.98, 0.78, 0.18), 0.4, 0.1)
    black = material("loco_black", (0.06, 0.06, 0.07), 0.45, 0.4)
    clay = material("terracotta", (0.78, 0.38, 0.20), 0.85)
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    bm = bmesh.new()
    box(bm, (0, 0, 1.2), (3.8, 8.0, 0.6), 1)
    box(bm, (0, 0, 2.3), (3.8, 7.6, 1.6), 0)
    for x in (-1.75, 1.75):
        for y in (-2.5, 2.5):
            tube(bm, [Vector((x, y, 1.0)), Vector((x * 1.12, y, 1.0))], [0.95, 0.95], 16, 1)
    for y in (-2.0, 0.0, 2.0):
        lathe(bm, [(0.0, 3.0), (0.55, 3.0), (0.8, 4.0), (0.85, 4.1), (0.0, 4.0)], 16, 2, offset=(0, y, 0))
        sphere(bm, (0, y, 4.6), 0.9, 1, 10, 6, (1, 1, 0.8))
    return finish(obj_from_bmesh("gartenbahn_wagen", bm, [yellow, black, clay, leafm]), 0.03)


def station():
    """Bahnsteig-Häuschen „Lumo-Hof“ und Lokschuppen (beide Y = Gleisrichtung)."""
    wood = material("hut_wood", (0.72, 0.48, 0.28), 0.7)
    roof = material("hut_roof", (0.70, 0.18, 0.14), 0.55)
    white = material("hut_white", (0.95, 0.92, 0.84), 0.6)
    bm = bmesh.new()
    box(bm, (0, 0, 2.6), (6.0, 8.0, 5.2), 0)
    for side in (-1, 1):
        rot = Matrix.Rotation(math.radians(32 * side), 3, "Y")
        box(bm, (side * 1.7, 0, 6.4), (4.4, 9.4, 0.4), 1, rot)
    box(bm, (0, 4.05, 2.2), (2.2, 0.2, 3.6), 2)
    for y in (-2.4, 2.4):
        box(bm, (3.05, y, 3.2), (0.2, 1.8, 1.6), 2)
    return finish(obj_from_bmesh("gartenbahn_bahnhof", bm, [wood, roof, white]), 0.05)


def pumpkin():
    """Kürbis (Einheitsradius 1, Höhe 0,74) mit 12 Rippen, Stiel und Blatt."""
    orange = material("pumpkin_orange", (0.95, 0.46, 0.06), 0.55)
    stalk = material("pumpkin_stalk", (0.42, 0.40, 0.16), 0.7)
    bm = bmesh.new()
    prof = []
    for i in range(17):
        t = i / 16
        a = -math.pi / 2 + math.pi * t
        prof.append((max(0.0, math.cos(a)) * 1.0, 0.37 + math.sin(a) * 0.37 * (0.9 if t > 0.5 else 1.0)))
    prof[0] = (0.0, 0.0)
    prof[-1] = (0.0, 0.70)
    lathe(bm, prof, 64, 0, ribs=12, rib_depth=0.09)
    stem = [Vector((0.02 * math.sin(t * 3), 0.05 * t * t, 0.66 + 0.2 * t)) for t in [i / 8 for i in range(9)]]
    tube(bm, stem, [0.085 - 0.03 * (i / 8) for i in range(9)], 8, 1)
    return finish(obj_from_bmesh("kuerbis", bm, [orange, stalk]))


def big_leaf():
    """Großes gelapptes Kürbis-/Gartenblatt (Länge 1)."""
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    bm = bmesh.new()
    leaf(bm, Vector((0, 0, 0)), Vector((0, 1, 0.1)), Vector((1, 0, 0)), 1.0, 0.95, 0, droop=0.15, curl=0.1,
         rows=10, cols=8, heart=True, lobes=2)
    tube(bm, [Vector((0, -0.4, -0.3)), Vector((0, -0.1, -0.05)), Vector((0, 0.02, 0.0))], [0.03, 0.025, 0.02], 6, 0)
    return finish(obj_from_bmesh("gartenblatt", bm, [leafm]))


def dandelion():
    """Pusteblume (Höhe 1): Stängel + Kugel aus Schirmchen."""
    stem = material("dandelion_stem", (0.38, 0.55, 0.22), 0.6)
    fluff = material("dandelion_fluff", (0.97, 0.97, 0.94), 0.8, 0.0, (0.9, 0.9, 0.85), 0.15)
    core = material("dandelion_core", (0.55, 0.50, 0.38), 0.8)
    bm = bmesh.new()
    pts = [Vector((0.03 * math.sin(t * 2), 0.0, 0.82 * t)) for t in [i / 8 for i in range(9)]]
    tube(bm, pts, [0.012] * 9, 6, 0)
    top = pts[-1] + Vector((0, 0, 0.06))
    sphere(bm, top, 0.04, 2, 8, 6)
    golden = math.pi * (3 - math.sqrt(5))
    n = 140
    for i in range(n):
        y = 1 - (i + 0.5) / n * 2
        r = math.sqrt(1 - y * y)
        a = i * golden
        d = Vector((math.cos(a) * r, math.sin(a) * r, y))
        tip = top + d * 0.15
        side = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        up = d.cross(side).normalized()
        for s in (side, up):
            v0 = bm.verts.new(tip - s * 0.035)
            v1 = bm.verts.new(tip + s * 0.035)
            v2 = bm.verts.new(top + d * 0.05)
            f = bm.faces.new((v0, v1, v2))
            f.material_index = 1
    return finish(obj_from_bmesh("pusteblume", bm, [stem, fluff, core]))


def seed_parachute():
    """Einzelnes Schirmchen (Höhe 1) für fliegende Samen und Schub-Ringe."""
    fluff = material("dandelion_fluff", (0.97, 0.97, 0.94), 0.8, 0.0, (0.9, 0.9, 0.85), 0.15)
    core = material("dandelion_core", (0.55, 0.50, 0.38), 0.8)
    bm = bmesh.new()
    tube(bm, [Vector((0, 0, 0)), Vector((0, 0, 0.75))], [0.02, 0.015], 5, 1)
    for i in range(16):
        a = 2 * math.pi * i / 16
        d = Vector((math.cos(a), math.sin(a), 0.35)).normalized()
        v0 = bm.verts.new((0, 0, 0.75))
        v1 = bm.verts.new(Vector((0, 0, 0.75)) + d * 0.45 + Vector((-math.sin(a), math.cos(a), 0)) * 0.04)
        v2 = bm.verts.new(Vector((0, 0, 0.75)) + d * 0.45 - Vector((-math.sin(a), math.cos(a), 0)) * 0.04)
        bm.faces.new((v0, v1, v2)).material_index = 0
    return finish(obj_from_bmesh("schirmchen", bm, [fluff, core]))


def grass_clump():
    """Grashalm-Büschel (Höhe 1): fünf gebogene Halme."""
    blade = material("grass_blade", (0.30, 0.60, 0.18), 0.55)
    tip = material("grass_tip", (0.55, 0.75, 0.25), 0.55)
    bm = bmesh.new()
    rnd = random.Random(3)
    for k in range(5):
        a = k * 2.4
        base = Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0))
        d = Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, 1.0)).normalized()
        leaf(bm, base, d, Vector((-math.sin(a), math.cos(a), 0)), 0.75 + rnd.uniform(0, 0.3), 0.07, k % 2,
             droop=0.35, curl=0.25, rows=7, cols=2)
    return finish(obj_from_bmesh("grashalme", bm, [blade, tip]))


def tomato_arch():
    """Tomatenranken-Tor über die Fahrbahn (Spannweite 16 m, Höhe 12 m)."""
    cane = material("bamboo", (0.78, 0.66, 0.38), 0.6)
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    red = material("tomato_red", (0.88, 0.10, 0.06), 0.25)
    bm = bmesh.new()
    rnd = random.Random(11)
    arch = [Vector((-8.0 + 16.0 * t, 0, 12.0 * math.sin(math.pi * t) ** 0.6)) for t in [i / 24 for i in range(25)]]
    for dy in (-0.8, 0.8):
        tube(bm, [p + Vector((0, dy, 0)) for p in arch], [0.22] * 25, 8, 0)
    for i in range(0, 25, 2):
        p = arch[i]
        for k in range(3):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.6))).normalized()
            leaf(bm, p, d, Vector((0, 0, 1)).cross(d) if abs(d.z) < 0.9 else Vector((1, 0, 0)), 1.6, 1.1, 1,
                 droop=0.3, curl=0.15, rows=4, cols=4, lobes=2)
        if 3 < i < 21:
            sphere(bm, p + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.8, 0.8), -0.9)), 0.55, 2, 12, 8)
    return finish(obj_from_bmesh("tomatenbogen", bm, [cane, leafm, red]))


def plant_table():
    """Pflanztisch (6 m × 3 m) mit Anzuchtschalen und Setzlingen."""
    wood = material("table_wood", (0.62, 0.44, 0.28), 0.7)
    tray = material("tray_black", (0.10, 0.10, 0.10), 0.6)
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    bm = bmesh.new()
    box(bm, (0, 0, 2.2), (3.0, 6.0, 0.25), 0)
    for x in (-1.3, 1.3):
        for y in (-2.7, 2.7):
            box(bm, (x, y, 1.05), (0.22, 0.22, 2.1), 0)
    box(bm, (0, 0, 0.6), (2.6, 5.6, 0.12), 0)
    rnd = random.Random(5)
    for y in (-1.8, 0.0, 1.8):
        box(bm, (0, y, 2.45), (2.4, 1.5, 0.25), 1)
        for k in range(6):
            p = Vector((-0.8 + (k % 3) * 0.8, y - 0.4 + (k // 3) * 0.8, 2.6))
            for j in range(3):
                a = j * 2.1 + rnd.uniform(0, 1)
                d = Vector((math.cos(a), math.sin(a), 1.4)).normalized()
                leaf(bm, p, d, Vector((-math.sin(a), math.cos(a), 0)), 0.55, 0.32, 2, droop=0.2, curl=0.1, rows=3, cols=2)
    return finish(obj_from_bmesh("pflanztisch", bm, [wood, tray, leafm]), 0.03)


def garden_arch():
    """Ziel-Rosenbogen (Spannweite 19 m, Höhe 14 m) aus weiß lackiertem Holz mit Rosen."""
    white = material("arch_white", (0.95, 0.94, 0.90), 0.5)
    leafm = material("leaf_green", (0.20, 0.52, 0.16), 0.5)
    rose = material("rose_red", (0.90, 0.16, 0.32), 0.45)
    bm = bmesh.new()
    rnd = random.Random(17)
    for x in (-9.5, 9.5):
        for dy in (-1.0, 1.0):
            box(bm, (x, dy, 5.0), (0.45, 0.45, 10.0), 0)
    arch = [Vector((-9.5 + 19.0 * t, 0, 10.0 + 4.0 * math.sin(math.pi * t))) for t in [i / 24 for i in range(25)]]
    for dy in (-1.0, 1.0):
        tube(bm, [p + Vector((0, dy, 0)) for p in arch], [0.25] * 25, 8, 0)
    for i in range(1, 24, 3):
        box(bm, arch[i], (0.18, 2.2, 0.18), 0)
    vine = arch[:]
    for i, p in enumerate(vine):
        for k in range(2):
            d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.8))).normalized()
            leaf(bm, p + Vector((0, rnd.uniform(-1, 1), 0)), d, Vector((0, 0, 1)).cross(d) if abs(d.z) < 0.9 else Vector((1, 0, 0)),
                 1.0, 0.6, 1, droop=0.2, curl=0.1, rows=3, cols=2)
        if i % 2 == 0:
            sphere(bm, p + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-1.1, 1.1), 0.4)), 0.55, 2, 10, 6, (1, 1, 0.8))
    for x in (-9.5, 9.5):
        for z in range(1, 10, 2):
            sphere(bm, (x + rnd.uniform(-0.4, 0.4), rnd.uniform(-1.2, 1.2), z), 0.5, 2, 10, 6, (1, 1, 0.8))
    return finish(obj_from_bmesh("rosenbogen", bm, [white, leafm, rose]))


def ladybug():
    red = material("bug_red", (0.90, 0.08, 0.06), 0.25)
    black = material("loco_black", (0.06, 0.06, 0.07), 0.45, 0.4)
    bm = bmesh.new()
    sphere(bm, (0, 0, 0.35), 0.5, 0, 20, 10, (0.9, 1.0, 0.75))
    sphere(bm, (0, 0.5, 0.3), 0.22, 1, 12, 8)
    for (x, y) in ((0.25, 0.15), (-0.25, 0.15), (0.3, -0.2), (-0.3, -0.2), (0.0, -0.35)):
        sphere(bm, (x, y, 0.58 if abs(x) < 0.1 else 0.55), 0.1, 1, 8, 4, (1, 1, 0.5))
    return finish(obj_from_bmesh("marienkaefer", bm, [red, black]))


def bee():
    yellow = material("bee_yellow", (0.98, 0.76, 0.12), 0.45)
    black = material("loco_black", (0.06, 0.06, 0.07), 0.45, 0.4)
    wing = material("bee_wing", (0.85, 0.92, 0.98), 0.1, 0.0, (0.6, 0.7, 0.8), 0.2)
    bm = bmesh.new()
    sphere(bm, (0, -0.1, 0.0), 0.32, 0, 14, 8, (1, 1.5, 1))
    for y in (-0.15, 0.1):
        tube(bm, [Vector((0, y, 0)), Vector((0, y + 0.08, 0))], [0.33, 0.33], 14, 1)
    sphere(bm, (0, 0.42, 0.02), 0.2, 1, 10, 6)
    for x in (-1, 1):
        leaf(bm, Vector((0.1 * x, 0.0, 0.25)), Vector((x, -0.3, 0.5)), Vector((0, 1, 0)), 0.55, 0.3, 2, droop=0.0, curl=0.0, rows=3, cols=2)
    return finish(obj_from_bmesh("biene", bm, [yellow, black, wing]))


def butterfly():
    wing = material("butterfly_wing", (0.98, 0.52, 0.12), 0.5, 0.0, (0.6, 0.25, 0.05), 0.25)
    body = material("loco_black", (0.06, 0.06, 0.07), 0.45, 0.4)
    bm = bmesh.new()
    tube(bm, [Vector((0, -0.3, 0)), Vector((0, 0.3, 0))], [0.05, 0.04], 6, 1)
    for x in (-1, 1):
        leaf(bm, Vector((0.02 * x, 0.05, 0)), Vector((x, 0.5, 0)), Vector((0, 1, 0)), 0.65, 0.6, 0, droop=0.0, curl=0.0, rows=4, cols=3)
        leaf(bm, Vector((0.02 * x, -0.05, 0)), Vector((x, -0.6, 0)), Vector((0, 1, 0)), 0.45, 0.4, 0, droop=0.0, curl=0.0, rows=3, cols=2)
    return finish(obj_from_bmesh("schmetterling", bm, [wing, body]))


def dragonfly():
    teal = material("dragon_teal", (0.10, 0.62, 0.70), 0.3, 0.3)
    wing = material("bee_wing", (0.85, 0.92, 0.98), 0.1, 0.0, (0.6, 0.7, 0.8), 0.2)
    bm = bmesh.new()
    tube(bm, [Vector((0, -1.0, 0)), Vector((0, 0.2, 0)), Vector((0, 0.45, 0))], [0.04, 0.07, 0.09], 8, 0)
    sphere(bm, (0, 0.55, 0), 0.12, 0, 10, 6)
    for x in (-1, 1):
        for y in (0.25, 0.05):
            leaf(bm, Vector((0.03 * x, y, 0.02)), Vector((x, 0.1, 0.05)), Vector((0, 1, 0)), 0.8, 0.18, 1, droop=0.0, curl=0.0, rows=3, cols=2)
    return finish(obj_from_bmesh("libelle", bm, [teal, wing]))


MODELS = {
    "sonnenblume": sunflower,
    "giesskanne": watering_can,
    "seerose_blatt": lilypad,
    "seerose_bluete": lily_flower,
    "blumentopf": flower_pot,
    "schlauchkupplung": hose_coupling,
    "gartenbahn_lok": locomotive,
    "gartenbahn_wagen": wagon,
    "gartenbahn_bahnhof": station,
    "kuerbis": pumpkin,
    "gartenblatt": big_leaf,
    "pusteblume": dandelion,
    "schirmchen": seed_parachute,
    "grashalme": grass_clump,
    "tomatenbogen": tomato_arch,
    "pflanztisch": plant_table,
    "rosenbogen": garden_arch,
    "marienkaefer": ladybug,
    "biene": bee,
    "schmetterling": butterfly,
    "libelle": dragonfly,
}


def main():
    names = [a for a in sys.argv[1:] if a in MODELS] or list(MODELS)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    report_path = OUT / "garden_models.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    for name in names:
        MATS.clear()
        o = MODELS[name]()
        export(name, lods(name, o), report)
        print(name, report[name])
    OUT.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(dict(sorted(report.items())), indent=1) + "\n")


if __name__ == "__main__":
    main()
