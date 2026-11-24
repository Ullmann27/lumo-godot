#!/usr/bin/env python3
"""Lumo-Kart-Streckenkulisse in Blender: Baeume, Bodenbewuchs, Felsen, Leuchten.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/scenery/build_scenery_models.py
Ausgabe: assets/kart/scenery/models/<art>.glb mit Objekten <art>_lod0/_lod1/_lod2
und assets/kart/scenery/models/scenery_models.json (Dreiecke je Stufe).

Alles selbst modelliert (keine fremde Geometrie, keine eingebetteten Bilder).
Die Texturen liegen einmalig extern unter assets/kart/scenery/textures/ und werden
in Godot vom Kulissen-Shader gesetzt (scripts/games/visual/kart_scenery.gd).

Kodierung fuer den Shader assets/shaders/kart_scenery_foliage.gdshader:
  COLOR.r  Windgewicht (0 Stammfuss .. 1 Zweigspitze)
  COLOR.g  Zufallsphase je Blattbuendel (Flattern, Farbvariation)
  COLOR.b  Umgebungsverdeckung (0 innen dunkel .. 1 aussen)
  UV2.y    0 Blattkarte (UV = Atlas), 1 Rinde (UV kachelnd, UV2.x = Streifen), 2 Fels (triplanar)
Leuchten: Oberflaeche "lamp_body" (UV in lamp_albedo-Farbfelder) und "lamp_glow"
  (Lichtflecken auf der Fahrbahn setzt kart_scenery.gd entlang des Strassenrahmens.)
  (additiv; COLOR.r Helligkeit, COLOR.g Art: 0 Leuchtkoerper, .25 Hof, .5 Lichtkegel,
  .75 Lichtfleck am Boden, 1 Flamme/Gluehwuermchen; COLOR.b Phase).
Koordinaten: Blender Z oben, Export mit +Y oben (Godot). Meter.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/scenery/models"

# Blatt-Atlas-Zellen (Spalte, Zeile, Breite) in 4x4 Raster
CELLS = {
    "laub": (0, 0, 1), "laub_hell": (1, 0, 1), "nadel": (2, 0, 1), "nadel_schnee": (3, 0, 1),
    "palme": (0, 1, 2), "dschungel": (2, 1, 1), "zauber": (3, 1, 1),
    "gras": (0, 2, 1), "blumen": (1, 2, 1), "farn": (2, 2, 1), "busch": (3, 2, 1),
    "trockengras": (0, 3, 1), "schneegras": (1, 3, 1), "herbst": (2, 3, 1),
}
BARK = {"eiche": 0, "kiefer": 1, "palme": 2, "zauber": 3}


class Builder:
    """Sammelt Dreiecke mit Normalen, UV, UV2 und Farbe je Ecke."""

    def __init__(self):
        self.verts: list[Vector] = []
        self.normals: list[Vector] = []
        self.uv: list[tuple] = []
        self.uv2: list[tuple] = []
        self.col: list[tuple] = []
        self.faces: list[tuple] = []
        self.face_mat: list[int] = []

    def vert(self, p, n, uv, uv2=(0.0, 1.0), col=(0, 0, 1, 1)):
        self.verts.append(Vector(p))
        self.normals.append(Vector(n).normalized())
        self.uv.append(uv)
        self.uv2.append(uv2)
        self.col.append(col)
        return len(self.verts) - 1

    def tri(self, a, b, c, mat=0):
        self.faces.append((a, b, c))
        self.face_mat.append(mat)

    def quad(self, a, b, c, d, mat=0):
        self.tri(a, b, c, mat)
        self.tri(a, c, d, mat)

    def triangles(self):
        return len(self.faces)

    def to_object(self, name, materials):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        for m in materials:
            mesh.materials.append(m)
        for poly, mi in zip(mesh.polygons, self.face_mat):
            poly.material_index = mi
        uv1 = mesh.uv_layers.new(name="UVMap")
        uv2 = mesh.uv_layers.new(name="UV2")
        colors = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        loop_normals = []
        for loop in mesh.loops:
            vi = loop.vertex_index
            uv1.data[loop.index].uv = self.uv[vi]
            uv2.data[loop.index].uv = self.uv2[vi]
            colors.data[loop.index].color = self.col[vi]
            loop_normals.append(tuple(self.normals[vi]))
        mesh.uv_layers.active = uv1
        mesh.color_attributes.active_color = colors
        mesh.validate(clean_customdata=False)
        mesh.normals_split_custom_set(loop_normals)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def atlas_uv(cell, u, v):
    """u, v in 0..1 innerhalb der Zelle (v=0 oben im Bild) -> Blender-UV."""
    col, row, width = CELLS[cell]
    inset = 0.004
    uu = (col + inset + u * (width - 2 * inset)) / 4.0
    vv = (row + inset + v * (1 - 2 * inset)) / 4.0
    return (uu, 1.0 - vv)


def bark_uv2(strip):
    return (BARK[strip] * 0.25, 0.0)  # Godot UV2.y = 1 -> Rinde


LEAF_UV2 = (0.0, 1.0)  # Godot UV2.y = 0 -> Blatt
ROCK_UV2 = (0.0, -1.0)  # Godot UV2.y = 2 -> Fels


def frames(path):
    """Parallel transportierte Rahmen entlang eines Pfades."""
    tangents = []
    for i in range(len(path)):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        tangents.append((b - a).normalized())
    ref = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.9 else Vector((0, 1, 0))
    normal = tangents[0].cross(ref).normalized()
    out = []
    for t in tangents:
        normal = (normal - t * normal.dot(t)).normalized()
        out.append((t, normal, t.cross(normal).normalized()))
    return out


def tube(b, path, radii, sides, strip, wind, ao, flare=0.0, buttress=0, cap=False, seed=0):
    """Rindenrohr mit Wurzelanlauf (flare) und Brettwurzeln (buttress Anzahl)."""
    fr = frames(path)
    length = 0.0
    rng = random.Random(seed)
    phase = rng.random() * math.tau
    rings = []
    for i, p in enumerate(path):
        if i:
            length += (p - path[i - 1]).length
        t, n1, n2 = fr[i]
        r = radii[i]
        circ = 2 * math.pi * max(r, 0.05)
        tiles = max(1, round(circ / 0.9))
        ring = []
        for j in range(sides + 1):
            a = j / sides * math.tau
            rr = r
            if flare:
                z = max(0.0, p.z)
                rr *= 1.0 + flare * math.exp(-z / 0.45)
                if buttress:
                    lobe = max(0.0, math.sin(a * buttress + phase)) ** 3
                    rr *= 1.0 + buttress * 0.22 * lobe * math.exp(-z / 0.8)
            rr *= 1.0 + 0.06 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, p.z * 1.5 + seed)))
            d = n1 * math.cos(a) + n2 * math.sin(a)
            ring.append(b.vert(p + d * rr, d, (j / sides * tiles, length / 3.4), bark_uv2(strip),
                               (wind[i], rng.random(), ao[i], 1.0)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(sides):
            b.quad(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j])
    if cap:
        tip = path[-1] + fr[-1][0] * radii[-1]
        c = b.vert(tip, fr[-1][0], (0.5, length / 3.4), bark_uv2(strip), (wind[-1], 0.5, ao[-1], 1))
        for j in range(sides):
            b.tri(rings[-1][j], rings[-1][j + 1], c)


def card(b, base, up, normal, width, height, cell, wind_base, wind_tip, ao_center, crown_center,
         crown_radius, bend=0.18, subdiv=2, phase=None, rng=None, normal_blend=0.75, flip=False):
    """Blattkarte: Unterkante mittig am Zweig (base), waechst entlang up."""
    up = up.normalized()
    side = up.cross(normal).normalized()
    normal = side.cross(up).normalized()
    ph = phase if phase is not None else (rng.random() if rng else 0.5)
    idx = []
    for iy in range(subdiv + 1):
        row = []
        ty = iy / subdiv
        for ix in range(subdiv + 1):
            tx = ix / subdiv
            off = (tx - 0.5) * width
            curve = bend * width * (4 * (tx - 0.5) ** 2) + bend * height * 0.5 * ty * ty
            p = base + side * off + up * (ty * height) - normal * curve
            radial = (p - crown_center)
            dist = radial.length / max(crown_radius, 0.01)
            n = normal.lerp(radial.normalized() if radial.length > 1e-4 else normal, normal_blend)
            ao = min(1.0, ao_center + (1 - ao_center) * min(1.0, dist) ** 1.5)
            w = wind_base + (wind_tip - wind_base) * ty
            u = (1.0 - tx) if flip else tx
            row.append(b.vert(p, n, atlas_uv(cell, u, 1.0 - ty), LEAF_UV2, (w, ph, ao, 1.0)))
        idx.append(row)
    for iy in range(subdiv):
        for ix in range(subdiv):
            b.quad(idx[iy][ix], idx[iy][ix + 1], idx[iy + 1][ix + 1], idx[iy + 1][ix])


def cluster(b, at, direction, size, cells, rng, crown_center, crown_radius, wind, ao, count=3, subdiv=2):
    """Gekreuzte Blattkarten, die vom Ast nach aussen zeigen."""
    d = direction.normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.92 else Vector((1, 0, 0))
    n0 = d.cross(ref).normalized()
    rot0 = rng.random() * math.pi
    for k in range(count):
        ang = rot0 + k * math.pi / count
        n = (Matrix.Rotation(ang, 3, d) @ n0).normalized()
        jitter = Vector((rng.uniform(-.25, .25), rng.uniform(-.25, .25), rng.uniform(-.1, .3)))
        up = (d + jitter).normalized()
        s = size * rng.uniform(0.82, 1.18)
        card(b, at - up * s * 0.12, up, n, s * 1.05, s, rng.choice(cells), wind * 0.8, wind, ao,
             crown_center, crown_radius, rng=rng, subdiv=subdiv, flip=rng.random() > .5)


def lerp_path(a, b, n, bend=Vector((0, 0, 0)), droop=0.0):
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t) + bend * math.sin(math.pi * t) - Vector((0, 0, droop * t * t))
        pts.append(p)
    return pts


# ---------------------------------------------------------------- Baumarten

def broadleaf(lod, seed, cells=("laub", "laub_hell"), strip="eiche", height=9.0, crown=4.2,
              trunk_r=0.32, branches=7, buttress=0, umbrella=False, flare=0.55, magic=False):
    rng = random.Random(seed)
    b = Builder()
    sides = (14, 8, 5)[lod]
    trunk_top = height * (0.52 if not umbrella else 0.78)
    steps = (10, 5, 2)[lod]
    trunk = []
    lean = Vector((rng.uniform(-.3, .3), rng.uniform(-.3, .3), 0))
    for i in range(steps + 1):
        t = i / steps
        twist = Vector((math.sin(t * 3 + seed) * 0.18, math.cos(t * 2.3 + seed) * 0.18, 0)) if magic else Vector()
        trunk.append(Vector((0, 0, -0.35 + t * (trunk_top + 0.35))) + lean * t * t + twist * t)
    radii = [trunk_r * (1.0 - 0.45 * (i / steps)) for i in range(steps + 1)]
    wind = [0.0 + 0.12 * (i / steps) ** 2 for i in range(steps + 1)]
    ao = [0.45 + 0.4 * (i / steps) for i in range(steps + 1)]
    tube(b, trunk, radii, sides, strip, wind, ao, flare=flare if lod < 2 else flare * 0.6,
         buttress=buttress if lod == 0 else 0, seed=seed)
    center = trunk[-1] + Vector((0, 0, crown * (0.55 if not umbrella else 0.15)))
    crown_r = crown
    n_br = (branches, max(4, branches - 2), 3)[lod]
    clusters_per = (5, 3, 2)[lod]
    card_size = (1.95, 2.6, 3.8)[lod] * (crown / 4.2)
    for k in range(n_br):
        a = k / n_br * math.tau + rng.uniform(-.3, .3)
        start_t = rng.uniform(0.55, 0.95) if not umbrella else rng.uniform(0.85, 1.0)
        si = int(start_t * steps)
        start = trunk[min(si, steps)]
        out = Vector((math.cos(a), math.sin(a), 0))
        rise = rng.uniform(0.35, 0.9) if not umbrella else rng.uniform(0.05, 0.3)
        reach = crown * rng.uniform(0.7, 1.0)
        end = start + out * reach + Vector((0, 0, reach * rise))
        n_seg = (5, 3, 1)[lod]
        path = lerp_path(start, end, n_seg, bend=Vector((0, 0, reach * 0.18)))
        br = radii[min(si, steps)] * 0.55
        if lod < 2:
            tube(b, path, [br * (1 - 0.75 * i / n_seg) for i in range(n_seg + 1)], (6, 4, 3)[lod], strip,
                 [0.15 + 0.6 * i / n_seg for i in range(n_seg + 1)], [0.55 + 0.35 * i / n_seg for i in range(n_seg + 1)],
                 cap=True, seed=seed + k)
        # Zweige zweiter Ordnung mit Blattbuendeln
        for c in range(clusters_per):
            t = 0.45 + 0.55 * (c + rng.random() * 0.6) / clusters_per
            p = path[0].lerp(path[-1], t) + Vector((0, 0, reach * 0.18 * math.sin(math.pi * t)))
            twig_dir = (out * rng.uniform(.4, 1.0) + Vector((rng.uniform(-.7, .7), rng.uniform(-.7, .7), rng.uniform(.2, .9)))).normalized()
            if lod == 0 and c % 2 == 0:
                tip = p + twig_dir * card_size * 0.6
                tube(b, [p, tip], [br * 0.35, br * 0.12], 3, strip, [0.6, 0.85], [0.7, 0.8], seed=seed + 31 * c)
                p = tip
            radial = (p - center)
            cluster(b, p, (twig_dir + radial.normalized() * 0.6).normalized(), card_size, cells, rng, center,
                    crown_r, 0.9, 0.35, count=(3, 2, 2)[lod], subdiv=(2, 1, 1)[lod])
    # Kronenfuellung: Buendel auf einer Ellipsoidschale (keine leeren Loecher)
    fill = (30, 12, 6)[lod]
    for k in range(fill):
        u = rng.uniform(0, math.tau)
        v = rng.uniform(-0.3, 1.0)
        dirv = Vector((math.cos(u) * math.sqrt(1 - v * v), math.sin(u) * math.sqrt(1 - v * v), v * (0.75 if not umbrella else 0.35)))
        p = center + dirv * crown_r * rng.uniform(0.55, 0.85)
        cluster(b, p, dirv, card_size * 1.05, cells, rng, center, crown_r, 1.0, 0.35, count=(3, 2, 2)[lod],
                subdiv=(2, 1, 1)[lod])
    return b


def conifer(lod, seed, snow=False, height=11.0, radius=2.9):
    rng = random.Random(seed)
    b = Builder()
    cell = ["nadel_schnee", "nadel"] if snow else ["nadel"]
    sides = (12, 7, 5)[lod]
    steps = (8, 4, 2)[lod]
    trunk = [Vector((0, 0, -0.3 + i / steps * (height + 0.3))) for i in range(steps + 1)]
    tube(b, trunk, [0.26 * (1 - 0.9 * i / steps) + 0.02 for i in range(steps + 1)], sides, "kiefer",
         [0.12 * (i / steps) ** 2 for i in range(steps + 1)], [0.4 + 0.5 * i / steps for i in range(steps + 1)],
         flare=0.45, buttress=4 if lod == 0 else 0, cap=True, seed=seed)
    whorls = (11, 7, 4)[lod]
    per = (6, 4, 3)[lod]
    center = Vector((0, 0, height * 0.45))
    for w in range(whorls):
        t = w / whorls
        z = height * (0.18 + 0.8 * t)
        reach = radius * (1.0 - t) ** 0.95 + 0.35
        for k in range(per):
            a = k / per * math.tau + w * 0.7 + rng.uniform(-.2, .2)
            out = Vector((math.cos(a), math.sin(a), 0))
            start = Vector((0, 0, z))
            end = start + out * reach + Vector((0, 0, -reach * 0.28))
            if lod == 0 and reach > 1.0:
                tube(b, lerp_path(start, end, 2, droop=0.2), [0.07, 0.045, 0.02], 3, "kiefer", [0.1, 0.5, 0.8],
                     [0.5, 0.6, 0.7], seed=seed + w * 10 + k)
            size = max(0.9, reach * 1.05)
            n_up = Vector((0, 0, 1))
            # flach liegende Zweigkarte plus leicht gekippte zweite Lage
            card(b, start + out * 0.05, out + Vector((0, 0, -0.15)), n_up, size * 0.95, size, rng.choice(cell),
                 0.2, 0.85, 0.35, center, height * 0.55, bend=0.12, subdiv=(2, 1, 1)[lod], rng=rng,
                 normal_blend=0.55)
            if lod < 2:
                side = out.cross(n_up)
                card(b, start + out * 0.05, out + Vector((0, 0, 0.1)), (n_up + side * 0.9).normalized(),
                     size * 0.8, size * 0.9, rng.choice(cell), 0.2, 0.8, 0.4, center, height * 0.55, bend=0.1,
                     subdiv=1, rng=rng, normal_blend=0.55)
    # Wipfel
    card(b, Vector((0, 0, height * 0.9)), Vector((0, 0, 1)), Vector((1, 0, 0)), 1.0, height * 0.16 + 0.6,
         cell[0], 0.8, 1.0, 0.8, center, height * 0.55, subdiv=1, rng=rng)
    card(b, Vector((0, 0, height * 0.9)), Vector((0, 0, 1)), Vector((0, 1, 0)), 1.0, height * 0.16 + 0.6,
         cell[0], 0.8, 1.0, 0.8, center, height * 0.55, subdiv=1, rng=rng)
    return b


def palm(lod, seed, height=8.5):
    rng = random.Random(seed)
    b = Builder()
    sides = (10, 7, 5)[lod]
    steps = (10, 5, 3)[lod]
    curve = Vector((rng.uniform(1.0, 1.8), 0, 0))
    trunk = [Vector((0, 0, -0.3 + i / steps * (height + 0.3))) + curve * (i / steps) ** 2 for i in range(steps + 1)]
    tube(b, trunk, [0.24 * (1 - 0.3 * i / steps) for i in range(steps + 1)], sides, "palme",
         [0.2 * (i / steps) ** 2 for i in range(steps + 1)], [0.6 + 0.4 * i / steps for i in range(steps + 1)],
         flare=0.5, cap=True, seed=seed)
    top = trunk[-1]
    fronds = (12, 8, 5)[lod]
    segs = (7, 4, 2)[lod]
    for k in range(fronds):
        a = k / fronds * math.tau + rng.uniform(-.15, .15)
        out = Vector((math.cos(a), math.sin(a), 0))
        lift = rng.uniform(0.2, 0.75) if k % 3 else rng.uniform(-0.1, 0.25)
        length = rng.uniform(3.6, 4.6)
        side = out.cross(Vector((0, 0, 1))).normalized()
        rows = []
        for i in range(segs + 1):
            t = i / segs
            p = top + out * length * t + Vector((0, 0, length * (lift * t - 0.55 * t * t)))
            w = 1.25 * math.sin(math.pi * min(1.0, t * 1.15 + 0.08)) + 0.12
            fold = 0.22 * w
            n = Vector((0, 0, 1))
            row = []
            for s, vv in ((-1, 0.0), (0, 0.5), (1, 1.0)):
                q = p + side * s * w * 0.55 - Vector((0, 0, fold * abs(s)))
                nn = (n + side * s * 0.35).normalized()
                row.append(b.vert(q, nn, atlas_uv("palme", t, vv), LEAF_UV2,
                                  (0.35 + 0.65 * t, rng.random(), 0.55 + 0.45 * t, 1.0)))
            rows.append(row)
        for i in range(segs):
            b.quad(rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1])
            b.quad(rows[i][1], rows[i + 1][1], rows[i + 1][2], rows[i][2])
    if lod == 0:  # Kokosnuesse aus Rindenmaterial
        for k in range(4):
            a = k / 4 * math.tau + 0.4
            c = top + Vector((math.cos(a) * 0.32, math.sin(a) * 0.32, -0.25))
            tube(b, [c - Vector((0, 0, .14)), c, c + Vector((0, 0, .14))], [0.06, 0.17, 0.06], 6, "palme",
                 [0.2, 0.2, 0.2], [0.5, 0.6, 0.5], seed=k)
    return b


def bush(lod, seed, cells=("busch", "laub"), radius=1.3):
    rng = random.Random(seed)
    b = Builder()
    center = Vector((0, 0, radius * 0.55))
    n = (22, 9, 4)[lod]
    for k in range(n):
        u = rng.uniform(0, math.tau)
        v = rng.uniform(0.0, 1.0)
        d = Vector((math.cos(u) * (1 - v * 0.6), math.sin(u) * (1 - v * 0.6), v * 0.9 + 0.2)).normalized()
        p = Vector((d.x * radius * 0.3, d.y * radius * 0.3, 0.05))
        cluster(b, p, d, radius * (1.15 if lod else 0.95), cells, rng, center, radius, 0.7, 0.3,
                count=(3, 2, 1)[lod], subdiv=1)
    return b


def verge(lod, seed, cells, size=3.2, tufts=(9, 5, 3)):
    """Bodenbewuchs-Flecken: mehrere gekreuzte Grasbueschel."""
    rng = random.Random(seed)
    b = Builder()
    for k in range(tufts[lod]):
        p = Vector((rng.uniform(-size, size) * 0.5, rng.uniform(-size, size) * 0.5, -0.03))
        h = rng.uniform(0.45, 0.85)
        cell = rng.choice(cells)
        center = p + Vector((0, 0, -0.4))
        for j in range((2, 2, 1)[lod]):
            a = rng.uniform(0, math.pi) + j * math.pi / 2
            n = Vector((math.cos(a), math.sin(a), 0))
            card(b, p, Vector((0, 0, 1)), n, h * 1.15, h, cell, 0.0, 0.75, 0.55, center, 1.0, bend=0.08,
                 subdiv=1, rng=rng, normal_blend=0.55)
    return b


def rock(lod, seed, squash=0.62):
    b = Builder()
    rng = random.Random(seed)
    sub = (3, 2, 1)[lod]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1.0)
    ico = bpy.context.active_object
    me = ico.data
    off = Vector((rng.random() * 9, rng.random() * 9, rng.random() * 9))
    pos = []
    for v in me.vertices:
        d = v.co.normalized()
        r = 1.0 + 0.32 * noise.noise(d * 1.4 + off) + 0.12 * noise.noise(d * 3.5 + off)
        r += 0.18 * max(0.0, abs(d.x) - 0.6)  # Kante
        pos.append(Vector((d.x * r * 1.15, d.y * r, max(-0.3, d.z * r * squash))))
    idx = []
    for i, v in enumerate(me.vertices):
        idx.append(b.vert(pos[i], v.co.normalized(), (0, 0), ROCK_UV2, (0.0, rng.random(), 0.75 + 0.25 * max(0.0, v.co.z), 1.0)))
    for poly in me.polygons:
        vs = list(poly.vertices)
        b.tri(idx[vs[0]], idx[vs[1]], idx[vs[2]])
    bpy.data.objects.remove(ico, do_unlink=True)
    # Flaechennormalen fuer kantige Felsen: Normalen aus Geometrie mitteln
    acc = [Vector() for _ in b.verts]
    for a, c, d in b.faces:
        n = (b.verts[c] - b.verts[a]).cross(b.verts[d] - b.verts[a])
        for i in (a, c, d):
            acc[i] += n
    b.normals = [n.normalized() if n.length > 0 else Vector((0, 0, 1)) for n in acc]
    return b


# ---------------------------------------------------------------- Leuchten

SWATCH = {"eisen": 0, "stahl": 1, "messing": 2, "holz": 3, "stein": 4, "violett": 5, "chrom": 6,
          "schwarz": 7, "moos": 8, "holz_hell": 9, "papier": 10, "dunkel": 11, "grau": 12,
          "bronze": 13, "blau": 14, "lila": 15}


def sw(name):
    i = SWATCH[name]
    return ((i % 4) * 0.25 + 0.125, 1.0 - ((i // 4) * 0.25 + 0.125))


def solid(b, path, radii, sides, swatch, mat=0, cap=True):
    fr = frames(path)
    rings = []
    for i, p in enumerate(path):
        t, n1, n2 = fr[i]
        ring = []
        for j in range(sides + 1):
            a = j / sides * math.tau + math.pi / sides
            d = n1 * math.cos(a) + n2 * math.sin(a)
            ring.append(b.vert(p + d * radii[i], d, sw(swatch), (0, 0), (1, 1, 1, 1)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(sides):
            b.quad(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j], mat)
    if cap:
        for end, sign in ((0, -1), (len(path) - 1, 1)):
            c = b.vert(path[end], fr[end][0] * sign, sw(swatch), (0, 0), (1, 1, 1, 1))
            for j in range(sides):
                if sign > 0:
                    b.tri(rings[end][j], rings[end][j + 1], c, mat)
                else:
                    b.tri(rings[end][j + 1], rings[end][j], c, mat)


def box(b, center, size, swatch, mat=0, glow=None):
    cx, cy, cz = center
    sx, sy, sz = (s * 0.5 for s in size)
    faces = [((1, 0, 0), (0, 1, 0), (0, 0, 1)), ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
             ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
             ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0))]
    for n, u, v in faces:
        n, u, v = Vector(n), Vector(u), Vector(v)
        half = Vector((sx, sy, sz))
        o = Vector(center) + Vector((n.x * sx, n.y * sy, n.z * sz))
        du = Vector((u.x * sx, u.y * sy, u.z * sz))
        dv = Vector((v.x * sx, v.y * sy, v.z * sz))
        col = glow if glow else (1, 1, 1, 1)
        uv = sw(swatch) if glow is None else (0.5, 0.5)
        ids = [b.vert(o + du * a + dv * c, n, uv, (0, 0), col) for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        b.quad(*ids, mat=mat)


def glow_quad(b, center, u, v, kind, intensity, phase=0.0, drift=False):
    """drift=True: schwebt im Shader (Gluehwuermchen, Funken; COLOR.a = 0.5)."""
    ids = []
    for a, c, uv in ((-1, -1, (0, 1)), (1, -1, (1, 1)), (1, 1, (1, 0)), (-1, 1, (0, 0))):
        p = Vector(center) + u * a + v * c
        ids.append(b.vert(p, u.cross(v).normalized(), uv, (0, 0), (intensity, kind, phase, 0.5 if drift else 1.0)))
    b.quad(*ids, mat=1)


def light_cone(b, apex, ground_z, radius, intensity, segs=12):
    """Offener Lichtkegel (additiv): UV.y 0 an der Lampe, 1 am Boden."""
    apex = Vector(apex)
    h = apex.z - ground_z
    top, bottom = [], []
    for j in range(segs + 1):
        a = j / segs * math.tau
        d = Vector((math.cos(a), math.sin(a), 0))
        top.append(b.vert(apex + d * 0.12, d, (j / segs, 0.0), (0, 0), (intensity, 0.5, 0, 1)))
        bottom.append(b.vert(Vector((apex.x, apex.y, ground_z + 0.05)) + d * radius, d, (j / segs, 1.0), (0, 0),
                             (intensity, 0.5, 0, 1)))
    for j in range(segs):
        b.quad(top[j], top[j + 1], bottom[j + 1], bottom[j], 1)


def halo(b, at, size, intensity):
    at = Vector(at)
    for u, v in ((Vector((size, 0, 0)), Vector((0, 0, size))), (Vector((0, size, 0)), Vector((0, 0, size))),
                 (Vector((size * .7, size * .7, 0)), Vector((0, 0, size)))):
        glow_quad(b, at, u, v, 0.25, intensity)


def pool(b, at, size, intensity):
    glow_quad(b, Vector(at), Vector((size, 0, 0)), Vector((0, size, 0)), 0.75, intensity)


def lamp_harbor(lod):
    """Gusseiserne Hafenlaterne: Sockel, kannelierter Mast, Bogenarm, Laternenkopf."""
    b = Builder()
    s = (12, 8, 6)[lod]
    solid(b, [Vector((0, 0, 0)), Vector((0, 0, 0.35))], [0.26, 0.22], s, "eisen")
    solid(b, [Vector((0, 0, 0.35)), Vector((0, 0, 0.55))], [0.17, 0.12], s, "eisen")
    solid(b, [Vector((0, 0, 0.55)), Vector((0, 0, 4.6))], [0.085, 0.06], s, "eisen")
    if lod < 2:
        for z in (1.2, 3.9):
            solid(b, [Vector((0, 0, z)), Vector((0, 0, z + 0.07))], [0.1, 0.1], s, "messing")
    arm = [Vector((0, 0, 4.4)), Vector((-0.35, 0, 4.75)), Vector((-0.9, 0, 4.85)), Vector((-1.25, 0, 4.7))]
    solid(b, arm, [0.045] * 4, (6, 4, 4)[lod], "eisen")
    head = Vector((-1.25, 0, 4.45))
    box(b, head + Vector((0, 0, 0.30)), (0.46, 0.46, 0.08), "eisen")
    solid(b, [head + Vector((0, 0, 0.34)), head + Vector((0, 0, 0.56))], [0.2, 0.02], 6, "eisen")
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        box(b, head + Vector((dx * 0.17, dy * 0.17, 0.05)), (0.03, 0.03, 0.5), "eisen")
    box(b, head + Vector((0, 0, -0.22)), (0.3, 0.3, 0.06), "eisen")
    box(b, head + Vector((0, 0, 0.04)), (0.3, 0.3, 0.42), "chrom", mat=1, glow=(2.2, 0.0, 0, 1))
    halo(b, head + Vector((0, 0, 0.04)), 0.95, 0.9)
    light_cone(b, head + Vector((0, 0, -0.2)), 0.0, 2.6, 0.55, (14, 10, 6)[lod])
    return b


def lamp_forest(lod):
    """Holzpfahl mit Querholz und haengender runder Laterne, Gluehwuermchen."""
    b = Builder()
    s = (8, 6, 5)[lod]
    solid(b, [Vector((0, 0, -0.2)), Vector((0, 0, 3.6))], [0.12, 0.1], s, "holz")
    solid(b, [Vector((0.1, 0, 3.35)), Vector((-1.05, 0, 3.5))], [0.06, 0.05], s, "holz")
    if lod < 2:
        solid(b, [Vector((0, 0, 2.6)), Vector((-0.55, 0, 3.4))], [0.035, 0.035], 4, "holz")
        solid(b, [Vector((0, 0, 0.0)), Vector((0, 0, 0.5))], [0.2, 0.14], s, "moos")
    solid(b, [Vector((-0.95, 0, 3.47)), Vector((-0.95, 0, 3.15))], [0.01, 0.01], 3, "schwarz", cap=False)
    head = Vector((-0.95, 0, 2.92))
    solid(b, [head + Vector((0, 0, 0.22)), head + Vector((0, 0, 0.3))], [0.14, 0.05], s, "bronze")
    solid(b, [head + Vector((0, 0, -0.24)), head + Vector((0, 0, -0.2))], [0.1, 0.12], s, "bronze")
    solid(b, [head + Vector((0, 0, -0.2)), head, head + Vector((0, 0, 0.22))], [0.12, 0.2, 0.13], s, "papier",
          mat=1)
    for i in range(len(b.col)):
        if b.col[i] == (1, 1, 1, 1) and False:
            pass
    halo(b, head, 0.9, 0.85)
    light_cone(b, head + Vector((0, 0, -0.2)), 0.0, 1.9, 0.4, (12, 8, 6)[lod])
    rng = random.Random(5)
    for k in range((10, 5, 0)[lod]):
        p = head + Vector((rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4), rng.uniform(-2.2, 0.8)))
        glow_quad(b, p, Vector((0.07, 0, 0)), Vector((0, 0, 0.07)), 1.0, 1.6, rng.random(), drift=True)
    return b


def lamp_neon(lod):
    """Neon-Stele: dunkler Pfeiler mit breiten Leuchtpaneelen zur Fahrbahn und in
    Fahrtrichtung, Leuchtringen und Lichtbalken oben (Holo City, Labor, Galaxie)."""
    b = Builder()
    box(b, Vector((0, 0, 0.1)), (0.8, 0.8, 0.2), "schwarz")
    box(b, Vector((0, 0, 3.1)), (0.36, 0.36, 6.0), "dunkel")
    box(b, Vector((0, 0, 6.15)), (0.55, 0.55, 0.12), "chrom")
    # Paneele: zur Strasse (-X) und nach vorn/hinten (+-Y), leicht vorstehend
    box(b, Vector((-0.19, 0, 3.3)), (0.03, 0.22, 5.2), "chrom", mat=1, glow=(1.0, 0.0, 0, 1))
    for dy in (-1, 1):
        box(b, Vector((0, dy * 0.19, 3.3)), (0.22, 0.03, 5.2), "chrom", mat=1, glow=(0.85, 0.0, 0, 1))
    # Querbalken mit Lichtleiste ueber dem Fahrbahnrand
    box(b, Vector((-0.75, 0, 5.9)), (1.5, 0.16, 0.12), "dunkel")
    box(b, Vector((-0.85, 0, 5.82)), (1.2, 0.1, 0.04), "chrom", mat=1, glow=(1.0, 0.0, 0, 1))
    if lod < 2:
        for z in (0.8, 1.9, 3.0, 4.1, 5.2):
            box(b, Vector((0, 0, z)), (0.42, 0.42, 0.05), "chrom", mat=1, glow=(0.9, 0.0, 0, 1))
    halo(b, Vector((-0.3, 0, 3.3)), 1.6, 0.55)
    halo(b, Vector((-0.9, 0, 5.75)), 1.2, 0.7)
    light_cone(b, Vector((-1.0, 0, 5.75)), 0.0, 2.6, 0.35, (10, 8, 6)[lod])
    return b


def lamp_torch(lod):
    """Steinsaeule mit Feuerschale und lodernder Flamme (Tempel, Vulkan, Wueste)."""
    b = Builder()
    s = (8, 6, 5)[lod]
    box(b, Vector((0, 0, 0.15)), (0.9, 0.9, 0.3), "stein")
    solid(b, [Vector((0, 0, 0.3)), Vector((0, 0, 1.2)), Vector((0, 0, 2.3))], [0.26, 0.22, 0.19], s, "stein")
    solid(b, [Vector((0, 0, 2.3)), Vector((0, 0, 2.5)), Vector((0, 0, 2.75))], [0.2, 0.42, 0.55], s, "bronze")
    rng = random.Random(3)
    for k in range((6, 4, 3)[lod]):
        a = k * math.pi / (6, 4, 3)[lod]
        u = Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0))
        glow_quad(b, Vector((0, 0, 3.25)), u, Vector((0, 0, 0.7)), 1.0, 1.0, rng.random())
    # innerer heller Kern
    for k in range(2):
        a = k * math.pi / 2 + 0.4
        u = Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, 0))
        glow_quad(b, Vector((0, 0, 3.05)), u, Vector((0, 0, 0.38)), 0.0, 1.0, rng.random())
    halo(b, Vector((0, 0, 3.2)), 2.0, 0.9)
    for k in range((10, 5, 0)[lod]):
        p = Vector((rng.uniform(-.35, .35), rng.uniform(-.35, .35), 3.6 + rng.uniform(0, 1.6)))
        glow_quad(b, p, Vector((0.05, 0, 0)), Vector((0, 0, 0.05)), 1.0, 1.0, rng.random(), drift=True)
    return b


def lamp_string(lod):
    """Lichterkette: Mast mit Durchhang-Leitung 14 m entlang -Y (Strassenrichtung)."""
    b = Builder()
    s = (8, 6, 4)[lod]
    solid(b, [Vector((0, 0, -0.2)), Vector((0, 0, 4.3))], [0.07, 0.055], s, "holz_hell")
    span = 14.0
    pts = []
    n = (14, 8, 4)[lod]
    for i in range(n + 1):
        t = i / n
        pts.append(Vector((0, -t * span, 4.1 - 1.1 * math.sin(math.pi * t))))
    solid(b, pts, [0.012] * len(pts), 3, "schwarz", cap=False)
    colors = [0.0, 0.0]
    bulbs = (11, 7, 4)[lod]
    for i in range(1, bulbs + 1):
        t = i / (bulbs + 1)
        p = Vector((0, -t * span, 4.1 - 1.1 * math.sin(math.pi * t) - 0.12))
        box(b, p, (0.11, 0.11, 0.15), "chrom", mat=1, glow=(2.6, 0.0, (i % 4) / 4 + 0.01, 1))
        if lod < 2:
            halo(b, p, 0.32, 0.8)
    return b


# ---------------------------------------------------------------- Export

def make_materials():
    mats = {}
    for name, color in (("scenery", (0.4, 0.5, 0.3, 1)), ("lamp_body", (0.2, 0.2, 0.22, 1)),
                        ("lamp_glow", (1.0, 0.9, 0.6, 1))):
        m = bpy.data.materials.new(name)
        m.diffuse_color = color
        mats[name] = m
    return mats


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_normals=True, export_tangents=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=True,
                              export_materials="PLACEHOLDER", export_cameras=False, export_lights=False,
                              export_animations=False)
    for o in objects:
        bpy.data.objects.remove(o, do_unlink=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    report = {}
    flora = {
        "laubbaum": lambda lod: broadleaf(lod, 11),
        "laubbaum_b": lambda lod: broadleaf(lod, 23, cells=("laub_hell", "laub", "herbst"), height=7.5, crown=3.6,
                                            trunk_r=0.26, branches=6),
        "nadelbaum": lambda lod: conifer(lod, 5),
        "palme": lambda lod: palm(lod, 7),
        "zauberbaum": lambda lod: broadleaf(lod, 41, cells=("zauber", "zauber", "laub"), strip="zauber",
                                            height=14.0, crown=6.2, trunk_r=0.75, branches=9, buttress=5,
                                            flare=0.9, magic=True),
        "dschungelbaum": lambda lod: broadleaf(lod, 53, cells=("dschungel", "laub", "dschungel"), height=15.0,
                                               crown=5.0, trunk_r=0.42, branches=8, buttress=4, umbrella=True,
                                               flare=0.8),
        "winterbaum": lambda lod: conifer(lod, 9, snow=True, height=9.5, radius=2.6),
        "busch": lambda lod: bush(lod, 3),
        "busch_bluehend": lambda lod: bush(lod, 4, cells=("busch", "blumen"), radius=1.0),
        "wiese": lambda lod: verge(lod, 61, ["gras", "gras", "blumen", "farn"]),
        "trockengras": lambda lod: verge(lod, 62, ["trockengras", "trockengras", "gras"]),
        "schneegras": lambda lod: verge(lod, 63, ["schneegras", "schneegras", "trockengras"]),
        "farnflur": lambda lod: verge(lod, 64, ["farn", "farn", "gras", "dschungel"]),
        "zauberflur": lambda lod: verge(lod, 65, ["farn", "blumen", "gras", "zauber"]),
        "fels": lambda lod: rock(lod, 71),
        "fels_flach": lambda lod: rock(lod, 72, squash=0.38),
    }
    lamps = {
        "leuchte_hafen": lamp_harbor,
        "leuchte_wald": lamp_forest,
        "leuchte_neon": lamp_neon,
        "leuchte_fackel": lamp_torch,
        "leuchte_kette": lamp_string,
    }
    for name, fn in flora.items():
        objs = []
        report[name] = {}
        for lod in range(3):
            bld = fn(lod)
            obj = bld.to_object(f"{name}_lod{lod}", [mats["scenery"]])
            report[name][f"lod{lod}"] = bld.triangles()
            objs.append(obj)
        export(name, objs)
    for name, fn in lamps.items():
        objs = []
        report[name] = {}
        for lod in range(3):
            bld = fn(lod)
            obj = bld.to_object(f"{name}_lod{lod}", [mats["lamp_body"], mats["lamp_glow"]])
            report[name][f"lod{lod}"] = bld.triangles()
            objs.append(obj)
        export(name, objs)
    for name in report:
        report[name]["bytes"] = (OUT / f"{name}.glb").stat().st_size
    (OUT / "scenery_models.json").write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
