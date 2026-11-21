"""Wolkenhafen: schwebende Inseln, Haeuser, Briefkasten, Adresstafel, Postamt, Leuchtturm,
Windmuehle, Zeppelin-Anleger, Baeume, Laternen und die Abwurf-Post (Brief, Paket, Sternschirm).
Godot-Koordinaten (Y oben, -Z vorne), Meter. Eingehaengt in build_skypost_models.py.

Materialnamen, die Godot ersetzt (sky_post_models.gd): SP_Wall, SP_Roof, SP_Grass, SP_Rock,
SP_Earth, SP_Leaves, SP_Box. Alle anderen bleiben wie exportiert.
"""
from __future__ import annotations

import math
import random

import bpy  # noqa: I001
import bmesh
from mathutils import Matrix, Vector, noise

import skypost_geo as G
from build_glider import tube


def M():
    return {
        "wall": G.material("SP_Wall", "f2d6a8", rough=.85),
        "roof": G.material("SP_Roof", "d0573d", rough=.6),
        "frame": G.material("SP_Frame", "fbf8f0", rough=.5),
        "window": G.material("SP_Window", "3a6ea8", rough=.08, metal=.1, emission=.25),
        "door": G.material("SP_Door", "7a4a2a", rough=.6),
        "stone": G.material("SP_Stone", "b9b2a6", rough=.9),
        "shutter": G.material("SP_Shutter", "3aa39a", rough=.55),
        "flower": G.material("SP_Flower", "ff5f7e", rough=.6),
        "leaf": G.material("SP_Leaves", "5fae4a", rough=.8),
        "bark": G.material("SP_Bark", "7a5236", rough=.9),
        "wood": G.material("SP_Wood", "b87a45", rough=.6),
        "metal": G.material("SP_Metal", "c9d2dc", metal=.85, rough=.3),
        "dark": G.material("SP_Dark", "24324a", rough=.7),
        "gold": G.material("SP_Accent", "ffc23a", metal=.6, rough=.28),
        "box": G.material("SP_Box", "2c6fe0", rough=.35, coat=.5),
        "paper": G.material("SP_Paper", "fbf7ea", rough=.8),
        "red": G.material("SP_Red", "d9443b", rough=.5),
        "white": G.material("SP_White", "f6f2ea", rough=.55),
        "lamp": G.material("SP_LampWhite", "fff1c2", emission=5.0),
        "lampglass": G.material("SP_LampGlass", "ffe9a8", emission=2.0, rough=.1),
        "cloth": G.material("SP_Cloth", "f4ecd8", rough=.9),
        "shingle": G.material("SP_Shingle", "8c7a6b", rough=.85),
        "grass": G.material("SP_Grass", "79c257", rough=.9),
        "earth": G.material("SP_Earth", "8a5a3c", rough=.95),
        "rock": G.material("SP_Rock", "c9a27e", rough=.95),
        "crystal": G.material("SP_Crystal", "8ff0ff", emission=2.5, rough=.1),
        "envelope": G.material("SP_Envelope", "f4ecd8", rough=.6),
        "trim": G.material("SP_Trim", "2c6fe0", rough=.34, coat=.5),
        "seal": G.material("SP_Seal", "d9443b", rough=.4),
        "parcel": G.material("SP_Parcel", "c89458", rough=.8),
    }


def lods(root_name, make, levels=3):
    """make(model, detail) -> builds each LOD into the same root; returns (root, tri counts)."""
    root = G.empty(root_name)
    counts = []
    for detail in range(levels):
        model = G.Model()
        make(model, detail)
        obj = model.build("%s_lod%d" % (root_name, detail), root)
        counts.append(G.tri_count(obj))
    return root, counts


def bev(detail, width=.04):
    return width if detail == 0 else 0.0


# ------------------------------------------------------------------ vertex-coloured meshes

def colour_object(name, bm, materials, parent):
    bm.transform(G_TO_B())
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(m)
    if len(mesh.color_attributes) > 0:
        mesh.color_attributes.active_color = mesh.color_attributes[0]
        mesh.color_attributes.render_color_index = 0
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(70))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def G_TO_B():
    return G.G_TO_B


def _hex(c):
    return tuple(int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def island(name, seed, detail, parent):
    """Top at y = 0, radius about 10 m. Grass top, earth lip, rock strata below, roots, crystals."""
    rnd = random.Random(seed)
    m = M()
    n = [56, 30, 14][detail]
    radius = 10.0
    off = Vector((seed * 7.3, seed * 3.1, seed * 1.7))

    def outline(a):
        p = Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 0)) + off
        q = Vector((math.cos(a) * 3.1, math.sin(a) * 3.1, 2)) + off
        return radius * (1 + .11 * noise.noise(p) + .05 * noise.noise(q))

    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Col")
    rings = []
    top_rings = [0.0, .3, .55, .78, .92, 1.0][:: (1 if detail == 0 else 2 if detail == 1 else 5)]
    if top_rings[-1] != 1.0:
        top_rings.append(1.0)
    profile = []  # (fraction of outline radius, y, zone, colour seed)
    for f in top_rings[1:]:
        profile.append((f, .55 * (1 - f * f), 0))
    lip = [(1.035, -.18, 0), (1.03, -.42, 1), (.99, -.62, 1), (.95, -1.3, 1)]
    profile += lip if detail < 2 else [(1.02, -.3, 0), (.95, -1.3, 1)]
    depth = 12.5
    strata = [1.3, 2.5, 3.6, 4.9, 6.2, 7.6, 9.0, 10.4, 11.7][:: (1 if detail == 0 else 2 if detail == 1 else 3)]
    for i, d in enumerate(strata):
        t = d / depth
        shrink = (1 - t ** 1.15) * .95
        step = .035 if i % 2 == 0 else -.02
        profile.append((shrink + step, -d, 2))
    centre = bm.verts.new((0, .62 + .15 * noise.noise(off), 0))
    centre_colour = _hex("7cc45a")
    for f, y, zone in profile:
        ring = []
        for j in range(n):
            a = math.tau * j / n
            r = outline(a) * f
            bump = 0.0
            if zone == 0 and f < 1.0:
                bump = .28 * G.fbm((math.cos(a) * r * .25 + off.x, math.sin(a) * r * .25 + off.y, off.z), 2)
            jitter = 0.0
            if zone == 2:
                jitter = .45 * noise.noise(Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, y * .35)) + off)
            rr = r + jitter
            ring.append(bm.verts.new((math.cos(a) * rr, y + bump, math.sin(a) * rr)))
        rings.append((ring, zone, y))
    tip = bm.verts.new((rnd.uniform(-.8, .8), -depth - 2.4, rnd.uniform(-.8, .8)))
    grass = [_hex("6fbf4e"), _hex("8fd060"), _hex("5aa944")]
    strata_cols = [_hex("e2b98a"), _hex("c98f68"), _hex("d8a1a0"), _hex("b9a7c4"), _hex("caa57a")]

    def colour(v, zone, y):
        if zone == 0:
            k = .5 + .5 * noise.noise(v.co * .35 + off)
            c = [grass[0][i] * (1 - k) + grass[1][i] * k for i in range(3)]
            if v.co.y < .05:
                c = [c[i] * .82 + grass[2][i] * .18 for i in range(3)]
            return tuple(c) + (1.0,)
        if zone == 1:
            return _hex("8a5a3c")
        band = int((-y + 1.1 * noise.noise(v.co * .3 + off)) / 1.4) % len(strata_cols)
        base = strata_cols[band]
        shade = .85 + .15 * noise.noise(v.co * .9 + off)
        ao = .65 + .35 * min(1, max(0, (y + depth) / depth))
        return tuple(base[i] * shade * ao for i in range(3)) + (1.0,)

    first = rings[0][0]
    for j in range(n):
        f = bm.faces.new((centre, first[(j + 1) % n], first[j]))
        f.material_index = 0
    for (a, za, ya), (b, zb, yb) in zip(rings, rings[1:]):
        zone = zb if zb != za else za
        for j in range(n):
            f = bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
            f.material_index = min(zone, 2)
    last = rings[-1][0]
    for j in range(n):
        f = bm.faces.new((last[j], last[(j + 1) % n], tip))
        f.material_index = 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        zone = face.material_index
        for loop in face.loops:
            loop[col] = colour(loop.vert, zone, loop.vert.co.y) if loop.vert is not centre else centre_colour
    obj = colour_object(name, bm, [m["grass"], m["earth"], m["rock"]], parent)
    tris = G.tri_count(obj)
    if detail == 0:
        extra = G.Model()
        for k in range(9):
            a = rnd.uniform(0, math.tau)
            r = outline(a) * .93
            start = Vector((math.cos(a) * r, -.9, math.sin(a) * r))
            pts = [start]
            for s in range(1, 5):
                pts.append(start + Vector((math.cos(a) * -.1 * s + rnd.uniform(-.15, .15), -.55 * s,
                                           math.sin(a) * -.1 * s + rnd.uniform(-.15, .15))))
            extra.add(tube(pts, .07 - .004 * k % .03, 5, closed=False), m["bark"])
        for k in range(5):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(2.5, 6.0)
            r = outline(a) * (1 - (d / depth) ** 1.35) * .9
            c = Vector((math.cos(a) * r, -d, math.sin(a) * r))
            bm2 = G.cylinder(c, c + Vector((math.cos(a) * .9, -.4, math.sin(a) * .9)), .22, .0, segments=6)
            extra.add(bm2, m["crystal"], smooth=False)
        e = extra.build(name + "_extra", parent)
        tris += G.tri_count(e)
        # Fold the extras into lod0 so the LOD switch hides them together.
        e.parent = obj
        e.location = (0, 0, 0)
    return tris


def make_island(seed):
    def build():
        root = G.empty("insel_%d" % seed)
        counts = [island("insel_%d_lod%d" % (seed, d), seed, d, root) for d in range(3)]
        G.export_glb(root, OUT() / ("insel_%d.glb" % seed))
        return {"lods": counts}
    return build


def OUT():
    return G.OUT


# ------------------------------------------------------------------ houses

def window(model, m, at, normal, detail, w=.8, h=1.0, shutters=False, flowers=False):
    """at: centre on the wall surface; normal: outward unit vector in XZ."""
    n = Vector(normal).normalized()
    yaw = math.atan2(n.x, n.z)
    rot = (0, yaw, 0)
    c = Vector(at)
    model.add(G.box(c + n * .05, (w, h, .1), rot), m["frame"], bevel=bev(detail, .02))
    model.add(G.box(c + n * .085, (w - .16, h - .16, .06), rot), m["window"], smooth=False)
    if detail == 0:
        model.add(G.box(c + n * .09 + Vector((0, 0, 0)), (.05, h - .16, .07), rot), m["frame"])
        model.add(G.box(c + n * .09, (w - .16, .05, .07), rot), m["frame"])
    model.add(G.box(c + n * .12 + Vector((0, -h / 2 - .04, 0)), (w + .14, .08, .2), rot), m["frame"])
    side = Vector((n.z, 0, -n.x))
    if shutters and detail < 2:
        for s in (-1, 1):
            model.add(G.box(c + n * .06 + side * s * (w / 2 + .2), (.34, h, .05), rot), m["shutter"],
                      bevel=bev(detail, .015))
    if flowers and detail < 2:
        base = c + n * .22 + Vector((0, -h / 2 - .18, 0))
        model.add(G.box(base, (w + .1, .22, .26), rot), m["wood"])
        if detail == 0:
            for k in range(5):
                p = base + side * ((k - 2) * w * .22) + Vector((0, .17, 0))
                model.add(G.sphere(p, (.11, .1, .11), 8, 5), m["flower"] if k % 2 == 0 else m["leaf"])


def door(model, m, at, normal, detail):
    n = Vector(normal).normalized()
    rot = (0, math.atan2(n.x, n.z), 0)
    c = Vector(at)
    model.add(G.box(c + n * .05 + Vector((0, 1.05, 0)), (1.25, 2.1, .12), rot), m["frame"], bevel=bev(detail, .02))
    model.add(G.box(c + n * .09 + Vector((0, 1.0, 0)), (.98, 1.95, .08), rot), m["door"], bevel=bev(detail, .015))
    model.add(G.box(c + n * .35 + Vector((0, .08, 0)), (1.4, .16, .6), rot), m["stone"], bevel=bev(detail, .02))
    if detail == 0:
        model.add(G.sphere(c + n * .16 + Vector((0, 1.0, 0)) + _side(n) * .3, (.05, .05, .05), 8, 5), m["gold"])
        model.add(G.box(c + n * .45 + Vector((0, 2.3, 0)), (1.6, .08, .7), rot), m["roof"])


def _side(n):
    return Vector((n.z, 0, -n.x))


def gable(center, width, depth, height):
    bm = bmesh.new()
    cx, cy, cz = center
    pts = [(-width / 2, 0), (0, height), (width / 2, 0)]
    front = [bm.verts.new((cx + x, cy + y, cz - depth / 2)) for x, y in pts]
    back = [bm.verts.new((cx + x, cy + y, cz + depth / 2)) for x, y in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(3):
        bm.faces.new((front[i], back[i], back[(i + 1) % 3], front[(i + 1) % 3]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def house_a(model, detail):
    m = M()
    model.add(G.box((0, .25, 0), (4.4, .5, 4.4)), m["stone"], bevel=bev(detail, .05))
    model.add(G.box((0, 2.55, 0), (4.0, 4.1, 4.0)), m["wall"], bevel=bev(detail, .04))
    model.add(gable((0, 4.6, 0), 4.0, 4.0, 2.1), m["wall"], smooth=False)
    model.add(G.prism_roof((0, 4.6, 0), 4.0, 4.0, 2.2, overhang=.38, thickness=.2), m["roof"], smooth=False)
    if detail < 2:
        model.add(G.box((0, 4.6, 0), (4.3, .16, 4.3)), m["frame"], bevel=bev(detail, .03))
    model.add(G.box((1.1, 6.3, .9), (.6, 1.6, .6)), m["stone"], bevel=bev(detail, .03))
    model.add(G.box((1.1, 7.15, .9), (.78, .12, .78)), m["dark"])
    door(model, m, (.0, .5, -2.0), (0, 0, -1), detail)
    for x in (-1.15, 1.15):
        window(model, m, (x, 3.4, -2.0), (0, 0, -1), detail, shutters=True, flowers=True)
        window(model, m, (x, 3.4, 2.0), (0, 0, 1), detail)
        window(model, m, (x, 1.6, 2.0), (0, 0, 1), detail)
    window(model, m, (-1.25, 1.6, -2.0), (0, 0, -1), detail, w=.7, h=.9)
    if detail < 2:
        for z in (-.9, .9):
            window(model, m, (-2.0, 2.6, z), (-1, 0, 0), detail, w=.7)
            window(model, m, (2.0, 2.6, z), (1, 0, 0), detail, w=.7)
        model.add(G.cylinder((0, 5.4, -2.02), (0, 5.4, -2.14), .38, segments=[20, 10][detail]), m["frame"])
        model.add(G.cylinder((0, 5.4, -2.1), (0, 5.4, -2.16), .28, segments=[20, 10][detail]), m["window"], smooth=False)


def house_b(model, detail):
    m = M()
    seg = [28, 16, 8][detail]
    model.add(G.lathe([(2.45, 0), (2.45, .55), (2.2, .55)], segments=seg), m["stone"], angle=40)
    model.add(G.lathe([(2.15, .5), (2.15, 5.3)], segments=seg), m["wall"], angle=40)
    model.add(G.lathe([(2.35, 5.2), (2.35, 5.45), (.0, 5.45)], segments=seg), m["frame"], angle=40)
    model.add(G.lathe([(2.75, 5.35), (2.6, 5.6), (1.2, 7.4), (.25, 8.6), (0, 8.75)], segments=seg), m["roof"], angle=40)
    model.add(G.sphere((0, 8.85, 0), (.22, .22, .22), 10, 6), m["gold"])
    if detail < 2:
        model.add(G.cylinder((0, 8.9, 0), (0, 9.6, 0), .03, segments=6), m["metal"])
        model.add(G.star_prism((0, 9.75, 0), .25, .05, axis="z"), m["gold"])
    door(model, m, (0, .5, -2.12), (0, 0, -1), detail)
    for k in range(6 if detail < 2 else 3):
        a = math.pi / 2 + math.tau * (k + .5) / 6
        n = Vector((math.cos(a), 0, -math.sin(a)))
        for y in ((1.9, 3.8) if k not in (2, 3) else (3.8,)):
            window(model, m, n * 2.12 + Vector((0, y, 0)), n, detail, w=.72, h=.95, shutters=(y > 3 and detail == 0),
                   flowers=(y > 3 and k in (2, 3)))


def make_house(kind):
    def build():
        root, counts = lods("haus_%s" % kind, house_a if kind == "a" else house_b)
        G.export_glb(root, OUT() / ("haus_%s.glb" % kind))
        return {"lods": counts}
    return build


# ------------------------------------------------------------------ mailbox and address board

def mailbox():
    m = M()
    root = G.empty("briefkasten")
    counts = []
    for detail in range(2):
        model = G.Model()
        model.add(G.cylinder((0, 0, 0), (0, 1.15, 0), .07, segments=[12, 6][detail]), m["dark"])
        model.add(G.box((0, .03, 0), (.5, .06, .5)), m["stone"], bevel=bev(detail, .02))
        model.add(G.box((0, 1.33, 0), (.62, .42, .86)), m["box"], bevel=bev(detail, .05))
        model.add(_half_cylinder((0, 1.54, 0), .31, .86, [24, 10][detail]), m["box"])
        if detail == 0:
            model.add(G.star_prism((.315, 1.4, 0), .14, .025, axis="x"), m["gold"])
            model.add(G.star_prism((-.315, 1.4, 0), .14, .025, axis="x"), m["gold"])
        obj = model.build("briefkasten_lod%d" % detail, root)
        counts.append(G.tri_count(obj))
    flap = G.Model()
    flap.add(G.box((0, .26, -.02), (.56, .52, .05)), m["box"], bevel=.015)
    flap.add(G.box((0, .45, -.06), (.22, .05, .05)), m["gold"])
    flap.build("Flap", root, origin=(0, 1.12, -.44), local=True)
    flag = G.Model()
    flag.add(G.cylinder((0, 0, 0), (0, .62, 0), .025, segments=8), m["metal"])
    flag.add(G.box((0, .5, .16), (.03, .24, .32)), m["red"], bevel=.01)
    flag.build("Flag", root, origin=(.34, 1.2, .12), local=True)
    G.export_glb(root, OUT() / "briefkasten.glb")
    return {"lods": counts, "pivots": {"Flap": [0, 1.12, -.44], "Flag": [.34, 1.2, .12]}}


def _half_cylinder(center, r, length, seg):
    bm = bmesh.new()
    cx, cy, cz = center
    front, back = [], []
    for i in range(seg + 1):
        a = math.pi * i / seg
        x, y = math.cos(a) * r, math.sin(a) * r
        front.append(bm.verts.new((cx + x, cy + y, cz - length / 2)))
        back.append(bm.verts.new((cx + x, cy + y, cz + length / 2)))
    for i in range(seg):
        bm.faces.new((front[i], back[i], back[i + 1], front[i + 1]))
    bm.faces.new(list(reversed(front)))
    bm.faces.new(back)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def address_board():
    """Pole with a round board; Godot turns the board (node 'Board') toward the camera and writes on it."""
    m = M()
    root = G.empty("adresstafel")
    pole = G.Model()
    pole.add(G.cylinder((0, 0, 0), (0, 3.2, 0), .08, segments=10), m["wood"])
    pole.add(G.box((0, .05, 0), (.5, .1, .5)), m["stone"], bevel=.02)
    obj = pole.build("adresstafel_lod0", root)
    board = G.Model()
    board.add(G.cylinder((0, 0, -.06), (0, 0, .06), 1.0, segments=32), m["trim"])
    board.add(G.cylinder((0, 0, -.075), (0, 0, .075), .86, segments=32), m["frame"])
    board.add(G.torus((0, 0, 0), 1.0, .07, 32, 6, axis="z"), m["gold"])
    b = board.build("Board", root, origin=(0, 4.1, 0), local=True)
    G.export_glb(root, OUT() / "adresstafel.glb")
    return {"lods": [G.tri_count(obj) + G.tri_count(b)], "pivots": {"Board": [0, 4.1, 0]}}


# ------------------------------------------------------------------ post office

def post_office(model, detail):
    m = M()
    b = bev(detail, .05)
    model.add(G.box((0, .4, 0), (11.0, .8, 8.0)), m["stone"], bevel=b)
    model.add(G.box((0, 3.9, 0), (10.4, 6.4, 7.4)), m["wall"], bevel=b)
    model.add(G.box((0, 7.25, 0), (10.9, .35, 7.9)), m["frame"], bevel=b)
    # Mansard roof.
    bm = bmesh.new()
    lo = [(-5.3, -3.8), (5.3, -3.8), (5.3, 3.8), (-5.3, 3.8)]
    hi = [(-4.3, -2.8), (4.3, -2.8), (4.3, 2.8), (-4.3, 2.8)]
    a = [bm.verts.new((x, 7.4, z)) for x, z in lo]
    c = [bm.verts.new((x, 9.6, z)) for x, z in hi]
    for i in range(4):
        bm.faces.new((a[i], a[(i + 1) % 4], c[(i + 1) % 4], c[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(c)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    model.add(bm, m["roof"], smooth=False)
    # Arched windows, two floors, front and sides.
    for y in (2.6, 5.4):
        for x in (-3.6, -1.9, 1.9, 3.6):
            window(model, m, (x, y, -3.7), (0, 0, -1), detail, w=1.1, h=1.6, flowers=(y < 3 and detail == 0))
            if detail < 2:
                model.add(_half_disc((x, y + .8, -3.76), .55, [16, 8][detail]), m["frame"])
        if detail < 2:
            for z in (-1.8, 0, 1.8):
                window(model, m, (-5.2, y, z), (-1, 0, 0), detail, w=1.0, h=1.5)
                window(model, m, (5.2, y, z), (1, 0, 0), detail, w=1.0, h=1.5)
    # Big entrance with arch and emblem.
    model.add(G.box((0, 2.0, -3.78), (2.4, 3.2, .2)), m["frame"], bevel=b)
    model.add(G.box((0, 1.75, -3.86), (1.9, 2.7, .1)), m["door"], bevel=bev(detail, .02))
    model.add(G.box((0, 3.7, -4.3), (3.4, .2, 1.4)), m["trim"], bevel=b)
    for x in (-1.5, 1.5):
        model.add(G.cylinder((x, .8, -4.85), (x, 3.6, -4.85), .1, segments=[12, 6, 6][detail]), m["frame"])
    model.add(G.box((0, 6.2, -3.82), (2.6, 1.6, .12)), m["envelope"], bevel=bev(detail, .03))
    if detail < 2:
        model.add(gable_flap((0, 6.98, -3.9), 2.6, .8), m["paper"], smooth=False)
        model.add(G.star_prism((0, 6.3, -3.95), .55, .1, axis="z"), m["gold"])
    # Clock tower.
    model.add(G.box((0, 11.0, 1.2), (3.2, 7.2, 3.2)), m["wall"], bevel=b)
    model.add(G.box((0, 14.75, 1.2), (3.6, .3, 3.6)), m["frame"], bevel=b)
    for face in range(4):
        a = math.pi / 2 * face
        n = Vector((math.sin(a), 0, -math.cos(a)))
        c = Vector((0, 12.6, 1.2)) + n * 1.62
        model.add(G.cylinder(c, c + n * .14, 1.05, segments=[32, 16, 8][detail]), m["gold"])
        model.add(G.cylinder(c + n * .05, c + n * .17, .9, segments=[32, 16, 8][detail]), m["frame"])
    model.add(G.box((0, 15.6, 1.2), (2.8, 1.4, 2.8)), m["white"], bevel=b)
    roof = G.lathe([(2.4, 0), (0, 3.2)], segments=4)
    roof.transform(Matrix.Translation((0, 16.3, 1.2)) @ Matrix.Rotation(math.pi / 4, 4, "Y"))
    model.add(roof, m["roof"], smooth=False)
    model.add(G.sphere((0, 19.6, 1.2), (.3, .3, .3), 10, 6), m["gold"])
    if detail < 2:
        model.add(G.star_prism((0, 20.4, 1.2), .55, .1, axis="z"), m["gold"])
    # Launch deck to the front with rails and a gentle lip.
    model.add(G.box((0, .78, -10.5), (4.4, .3, 13.0)), m["wood"], bevel=bev(detail, .03))
    if detail == 0:
        for k in range(26):
            model.add(G.box((0, .95, -4.3 - k * .5), (4.3, .04, .04)), m["door"])
    for x in (-2.15, 2.15):
        model.add(G.box((x, 1.55, -10.5), (.12, .12, 13.0)), m["frame"], bevel=bev(detail, .02))
        for k in range(8 if detail < 2 else 3):
            z = -4.3 - k * 12.4 / (7 if detail < 2 else 2)
            model.add(G.cylinder((x, .9, z), (x, 1.55, z), .06, segments=6), m["frame"])
        for k in range(3):
            model.add(G.cylinder((x, -.2 - k * 1.2, -6 - k * 3.5), (x * .6, .7, -6 - k * 3.5), .12, segments=6), m["wood"])
    model.add(G.box((0, 1.1, -17.2), (4.4, .3, 1.2), rot=(-.35, 0, 0)), m["wood"], bevel=bev(detail, .03))
    for x in (-1.6, 0, 1.6):
        model.add(G.sphere((x, 1.0, -16.2), (.12, .12, .12), 8, 5), m["lamp"])


def _half_disc(center, r, seg):
    bm = bmesh.new()
    cx, cy, cz = center
    verts = [bm.verts.new((cx + math.cos(math.pi * i / seg) * r, cy + math.sin(math.pi * i / seg) * r, cz)) for i in range(seg + 1)]
    verts2 = [bm.verts.new((v.co.x, v.co.y, cz + .1)) for v in verts]
    bm.faces.new(verts)
    bm.faces.new(list(reversed(verts2)))
    for i in range(seg):
        bm.faces.new((verts[i], verts2[i], verts2[i + 1], verts[i + 1]))
    bm.faces.new((verts[-1], verts2[-1], verts2[0], verts[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def gable_flap(center, width, height):
    bm = bmesh.new()
    cx, cy, cz = center
    pts = [(-width / 2, 0), (width / 2, 0), (0, -height)]
    f = [bm.verts.new((cx + x, cy + y, cz)) for x, y in pts]
    b = [bm.verts.new((cx + x, cy + y, cz + .06)) for x, y in pts]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    for i in range(3):
        bm.faces.new((f[i], b[i], b[(i + 1) % 3], f[(i + 1) % 3]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ lighthouse

def lighthouse(model, detail):
    m = M()
    seg = [32, 18, 10][detail]
    model.add(G.lathe([(3.4, 0), (3.4, 1.2), (2.7, 1.5)], segments=seg), m["stone"], angle=40)
    bands = [(0, "red"), (3.5, "white"), (7.0, "red"), (10.5, "white")]
    for i, (y, colour) in enumerate(bands):
        y0, y1 = 1.4 + y, 1.4 + y + 3.5
        r0, r1 = 2.4 - y * .055, 2.4 - (y + 3.5) * .055
        model.add(G.lathe([(r0, y0), (r1, y1)], segments=seg), m[colour], angle=40)
    top = 1.4 + 14.0
    model.add(G.lathe([(2.6, top), (2.6, top + .35), (0, top + .35)], segments=seg), m["dark"], angle=40)
    if detail < 2:
        model.add(G.torus((0, top + 1.2, 0), 2.45, .05, seg, 5), m["white"])
        for k in range(16 if detail == 0 else 8):
            a = math.tau * k / (16 if detail == 0 else 8)
            p = Vector((math.cos(a) * 2.45, top + .35, math.sin(a) * 2.45))
            model.add(G.cylinder(p, p + Vector((0, .85, 0)), .04, segments=5), m["white"])
    model.add(G.lathe([(1.35, top + .35), (1.35, top + 2.3)], segments=seg), m["lampglass"], angle=40)
    if detail < 2:
        for k in range(8):
            a = math.tau * k / 8
            p = Vector((math.cos(a) * 1.37, top + .35, math.sin(a) * 1.37))
            model.add(G.cylinder(p, p + Vector((0, 1.95, 0)), .05, segments=5), m["dark"])
    model.add(G.lathe([(1.75, top + 2.3), (1.7, top + 2.55), (.3, top + 3.7), (0, top + 3.8)], segments=seg), m["red"], angle=40)
    model.add(G.sphere((0, top + 3.95, 0), (.25, .25, .25), 10, 6), m["gold"])
    model.add(G.sphere((0, top + 1.35, 0), (.55, .55, .55), 12, 8), m["lamp"])
    door(model, m, (0, 1.3, -2.38), (0, 0, -1), detail)
    for y, a in ((6.5, -.3), (10.5, .25), (13.5, -.2)):
        r = 2.4 - (y - 1.4) * .055
        n = Vector((math.sin(a), 0, -math.cos(a)))
        window(model, m, n * r + Vector((0, y, 0)), n, detail, w=.55, h=.85)
    # Keeper's cottage.
    model.add(G.box((4.4, 1.3, 1.6), (3.0, 2.6, 2.6)), m["white"], bevel=bev(detail))
    model.add(G.prism_roof((4.4, 2.6, 1.6), 3.0, 2.6, 1.3, overhang=.25, thickness=.15), m["red"], smooth=False)
    model.add(gable((4.4, 2.6, 1.6), 3.0, 2.6, 1.25), m["white"], smooth=False)
    window(model, m, (4.4, 1.4, .3), (0, 0, -1), detail, w=.7, h=.8, shutters=True)


# ------------------------------------------------------------------ windmill

def windmill(model, detail):
    m = M()
    seg = 8
    model.add(G.lathe([(3.2, 0), (3.2, 1.6), (2.75, 1.6)], segments=16 if detail < 2 else 8), m["stone"], angle=40)
    body = G.lathe([(2.6, 1.5), (1.75, 9.0)], segments=seg)
    body.transform(Matrix.Rotation(math.pi / 8, 4, "Y"))
    model.add(body, m["shingle"], smooth=False)
    if detail < 2:
        for y in (3.0, 5.5, 8.0):
            r = 2.6 - (y - 1.5) * (.85 / 7.5)
            ring = G.lathe([(r + .07, y - .08), (r + .07, y + .08)], segments=seg)
            ring.transform(Matrix.Rotation(math.pi / 8, 4, "Y"))
            model.add(ring, m["frame"], smooth=False)
    # Stage (gallery) around the mill.
    model.add(G.lathe([(3.4, 4.0), (3.4, 4.2), (2.2, 4.2)], segments=[24, 12, 8][detail]), m["wood"], angle=40)
    if detail < 2:
        model.add(G.torus((0, 5.1, 0), 3.35, .05, [24, 12][detail], 5), m["wood"])
        for k in range(12 if detail == 0 else 6):
            a = math.tau * k / (12 if detail == 0 else 6)
            p = Vector((math.cos(a) * 3.35, 4.2, math.sin(a) * 3.35))
            model.add(G.cylinder(p, p + Vector((0, .9, 0)), .05, segments=5), m["wood"])
    cap = G.lathe([(1.9, 0), (2.0, .4), (1.6, 1.4), (.8, 2.1), (0, 2.3)], segments=[20, 12, 8][detail])
    cap.transform(Matrix.Translation((0, 8.9, 0)) @ Matrix.Diagonal((1.0, 1.0, 1.25, 1.0)))
    model.add(cap, m["roof"], angle=40)
    model.add(G.cylinder((0, 9.6, -1.5), (0, 9.6, -2.25), .32, segments=[12, 8, 6][detail]), m["dark"])
    door(model, m, (0, 1.6, -2.48), (0, 0, -1), detail)
    for y, a in ((6.2, 0.0), (2.6, math.pi * .6)):
        r = 2.6 - (y - 1.5) * (.85 / 7.5)
        n = Vector((math.sin(a), 0, -math.cos(a)))
        window(model, m, n * (r * math.cos(math.pi / 8)) + Vector((0, y, 0)), n, detail, w=.6, h=.8)


def sails(model):
    m = M()
    model.add(G.cylinder((0, 0, .1), (0, 0, -.35), .38, segments=12), m["dark"])
    model.add(G.sphere((0, 0, -.4), (.25, .25, .2), 10, 6), m["gold"])
    for k in range(4):
        a = math.pi / 4 + math.pi / 2 * k
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        model.add(G.box(d * 3.6 + Vector((0, 0, -.25)), (7.0 if abs(d.x) > 0 else .2, .2, .16),
                        rot=(0, 0, a)), m["wood"])
        for j in range(7):
            p = d * (1.4 + j * .82) + s * .55 + Vector((0, 0, -.22))
            model.add(G.box(p, (.06, 1.2, .06), rot=(0, 0, a)), m["wood"])
        model.add(G.box(d * 4.2 + s * .62 + Vector((0, 0, -.18)), (5.0, 1.05, .03), rot=(0, 0, a)), m["cloth"])


def make_windmill():
    root, counts = lods("windmuehle", windmill)
    s = G.Model()
    sails(s)
    obj = s.build("Sails", root, origin=(0, 9.6, -2.35), local=True)
    G.export_glb(root, OUT() / "windmuehle.glb")
    return {"lods": counts, "sails": G.tri_count(obj), "pivots": {"Sails": [0, 9.6, -2.35]}}


# ------------------------------------------------------------------ zeppelin mast and zeppelin

def mast(model, detail):
    m = M()
    h = 14.0
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

    def at(c, y):
        w = 1.6 - (y / h) * 1.0
        return Vector((c[0] * w, y, c[1] * w))

    for c in corners:
        model.add(G.cylinder(at(c, 0), at(c, h), .09, segments=[8, 5, 4][detail]), m["red"])
    if detail < 2:
        steps = 7
        for s in range(steps):
            y0, y1 = h * s / steps, h * (s + 1) / steps
            for i in range(4):
                a, b = corners[i], corners[(i + 1) % 4]
                model.add(G.cylinder(at(a, y0), at(b, y1), .035, segments=4), m["white"])
                if detail == 0:
                    model.add(G.cylinder(at(b, y0), at(a, y1), .035, segments=4), m["white"])
                model.add(G.cylinder(at(a, y1), at(b, y1), .04, segments=4), m["red"])
    model.add(G.box((0, h + .1, 0), (2.2, .2, 2.2)), m["wood"], bevel=bev(detail, .03))
    model.add(G.cylinder((0, h + .2, 0), (0, h + 1.6, 0), .35, .12, segments=[12, 8, 6][detail]), m["metal"])
    model.add(G.sphere((0, h + 1.7, 0), (.22, .22, .22), 10, 6), m["lamp"])
    model.add(G.box((0, .15, 0), (4.0, .3, 4.0)), m["stone"], bevel=bev(detail))


def zeppelin(model):
    m = M()
    length = 15.0
    profile = []
    for i in range(17):
        t = i / 16
        r = 2.9 * math.sin(math.pi * t) ** .65 * (1 - .18 * t)
        profile.append((max(r, .001), t * length))
    hull = G.lathe(profile, segments=32)
    hull.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    model.add(hull, m["cloth"], angle=40)
    for t in (.22, .55):
        r = 2.9 * math.sin(math.pi * t) ** .65 * (1 - .18 * t)
        band = G.lathe([(r + .03, t * length - .25), (r + .03, t * length + .25)], segments=32)
        band.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
        model.add(band, m["trim"], angle=40)
    for k in range(4):
        a = math.pi / 2 * k
        d = Vector((math.cos(a), math.sin(a), 0))
        root = Vector((0, 0, length * .82)) + d * 1.2
        bm = G.fin([((0, 0, 0), 2.6, .18), ((0, 1.9, .9), 1.4, .12)], n=8)
        bm.transform(Matrix.Translation(root) @ Matrix.Rotation(a - math.pi / 2, 4, "Z"))
        model.add(bm, m["trim"])
    model.add(G.box((0, -3.05, 6.6), (1.3, .9, 3.4)), m["white"], bevel=.08)
    for z in (5.6, 6.4, 7.2):
        for x in (-.66, .66):
            model.add(G.box((x, -2.95, z), (.04, .4, .5)), m["window"], smooth=False)
    for x in (-1.3, 1.3):
        model.add(G.cylinder((x, -2.7, 7.6), (x, -2.7, 8.3), .2, segments=10), m["dark"])
    for side in (-1, 1):
        model.add(G.star_prism((side * 2.75, .2, 5.6), 1.0, .08, axis="x"), m["gold"])


def make_mast():
    root, counts = lods("zeppelinmast", mast)
    z = G.Model()
    zeppelin(z)
    obj = z.build("Zeppelin", root, origin=(0, 15.6, 0), local=True)
    G.export_glb(root, OUT() / "zeppelinmast.glb")
    return {"lods": counts, "zeppelin": G.tri_count(obj), "pivots": {"Zeppelin": [0, 15.6, 0]}}


# ------------------------------------------------------------------ trees, lamps, post

def tree(name, seed, slim, detail, parent):
    rnd = random.Random(seed)
    m = M()
    model = G.Model()
    h = 5.5 if slim else 3.2
    model.add(G.cylinder((0, 0, 0), (0, h, 0), .28, .14, segments=[10, 6, 5][detail]), m["bark"])
    obj = model.build(name + "_trunk", parent)
    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Col")
    blobs = []
    if slim:
        for k in range(5):
            blobs.append((Vector((0, 2.2 + k * 1.15, 0)), 1.15 - k * .16))
    else:
        blobs = [(Vector((0, 3.8, 0)), 1.9)]
        for k in range(5):
            a = rnd.uniform(0, math.tau)
            blobs.append((Vector((math.cos(a) * 1.2, 3.4 + rnd.uniform(-.3, .9), math.sin(a) * 1.2)), rnd.uniform(1.0, 1.4)))
    subdiv = [2, 1, 1][detail]
    if detail == 2:
        blobs = blobs[:2]
    for c, r in blobs:
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=r)
        for v in tmp.verts:
            v.co += v.co.normalized() * r * .16 * noise.noise(v.co * .9 + c + Vector((seed, 0, 0)))
            v.co += c
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    light, dark = _hex("8ccf58"), _hex("3f8a3a")
    for f in bm.faces:
        for loop in f.loops:
            k = min(1, max(0, (loop.vert.co.y - 1.5) / (h + 1.5) + .25 * noise.noise(loop.vert.co * .7)))
            loop[col] = tuple(dark[i] * (1 - k) + light[i] * k for i in range(3)) + (1.0,)
    leaves = colour_object(name + "_leaves", bm, [m["leaf"]], obj)
    leaves.location = (0, 0, 0)
    return G.tri_count(obj) + G.tri_count(leaves)


def make_tree(kind):
    def build():
        root = G.empty("baum_%s" % kind)
        counts = []
        for d in range(3):
            holder = G.empty("baum_%s_lod%d" % (kind, d), parent=root)
            counts.append(tree("baum_%s_%d" % (kind, d), 11 if kind == "rund" else 23, kind == "schlank", d, holder))
        G.export_glb(root, OUT() / ("baum_%s.glb" % kind))
        return {"lods": counts}
    return build


def lamp_post(model, detail):
    m = M()
    model.add(G.cylinder((0, 0, 0), (0, 3.0, 0), .07, .05, segments=8), m["dark"])
    model.add(G.box((0, .08, 0), (.4, .16, .4)), m["stone"])
    model.add(G.box((0, 3.25, 0), (.36, .5, .36)), m["lamp"], bevel=bev(detail, .02))
    model.add(G.lathe([(.32, 3.5), (0, 3.8)], segments=8), m["dark"], smooth=False)


def post_items():
    m = M()
    root = G.empty("post")
    env = G.Model()
    env.add(G.box((0, 0, 0), (.7, .04, .46)), m["envelope"], bevel=.012)
    env.add(_flat_triangle((0, .025, -.23), .7, .28), m["paper"], smooth=False)
    env.add(G.cylinder((0, .02, .0), (0, .05, .0), .07, segments=14), m["seal"])
    env.add(G.star_prism((0, .055, 0), .05, .01, axis="y"), m["gold"])
    env.build("Brief", root)
    parcel = G.Model()
    parcel.add(G.box((0, 0, 0), (.55, .4, .55)), m["parcel"], bevel=.03)
    parcel.add(G.box((0, 0, 0), (.57, .42, .08)), m["red"])
    parcel.add(G.box((0, 0, 0), (.08, .42, .57)), m["red"])
    parcel.add(G.torus((0, .23, 0), .1, .03, 12, 5, axis="x"), m["red"])
    parcel.build("Paket", root)
    chute = G.Model()
    canopy = G.lathe([(0.001, 1.35), (.45, 1.3), (.8, 1.12), (.95, .95), (.9, .9)], segments=10)
    chute.add(canopy, m["box"], angle=40)
    for k in range(5):
        a = math.tau * k / 5
        chute.add(G.cylinder((math.cos(a) * .9, .9, math.sin(a) * .9), (0, .05, 0), .01, segments=4), m["paper"])
    chute.add(G.star_prism((0, 1.4, 0), .3, .05, axis="y"), m["gold"])
    chute.build("Schirm", root)
    G.export_glb(root, OUT() / "post.glb")
    return {"lods": [0]}


def _flat_triangle(center, width, depth):
    bm = bmesh.new()
    cx, cy, cz = center
    vs = [bm.verts.new((cx - width / 2, cy, cz)), bm.verts.new((cx + width / 2, cy, cz)), bm.verts.new((cx, cy, cz + depth))]
    bm.faces.new(vs)
    return bm


def simple(name, fn, levels=3):
    def build():
        root, counts = lods(name, fn, levels)
        G.export_glb(root, OUT() / (name + ".glb"))
        return {"lods": counts}
    return build


BUILDERS = {
    "insel_1": make_island(1), "insel_2": make_island(2), "insel_3": make_island(3),
    "haus_a": make_house("a"), "haus_b": make_house("b"),
    "briefkasten": mailbox, "adresstafel": address_board,
    "postamt": simple("postamt", post_office),
    "leuchtturm": simple("leuchtturm", lighthouse),
    "windmuehle": make_windmill,
    "zeppelinmast": make_mast,
    "baum_rund": make_tree("rund"), "baum_schlank": make_tree("schlank"),
    "laterne": simple("laterne", lamp_post, 2),
    "post": post_items,
}
