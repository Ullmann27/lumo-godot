#!/usr/bin/env python3
"""Eigenbau-Modelle der Abenteuerwelten in Blender (bpy 5.x), reproduzierbar.

Ausführen:
  /home/user/tools/bpyenv/bin/python tools/lumo_adventure_art/build_models.py [--only flora,ruins,...]

Blender-Koordinaten: Z oben, Meter; der glTF-Export dreht nach Godot (Y oben).
Die GLBs enthalten nur Geometrie, UVs, eigene Normalen und benannte Materialien
(ohne eingebettete Bilder). Godot ordnet die Materialnamen in
scripts/creative/adventure_kit.gd den einmal abgelegten Texturen zu
(assets/creative/adventure/textures). Keine fremde Geometrie, keine Downloads.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/adventure/models"


# ------------------------------------------------------------------ Grundlagen

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_MATS: dict[str, bpy.types.Material] = {}


def mat(name, color=(0.8, 0.8, 0.8), double=False):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = tuple(color) + (1.0,)
    m.diffuse_color = tuple(color) + (1.0,)
    m.use_backface_culling = not double
    _MATS[name] = m
    return m


class Builder:
    """Sammelt Dreiecke/Vierecke mit UVs, Materialindex und optionalen Normalen."""

    def __init__(self, name):
        self.name = name
        self.verts: list[Vector] = []
        self.faces: list[tuple] = []  # (indices, uvs, mat_name, normals|None)
        self.mats: list[str] = []

    def v(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def face(self, idx, uvs, material, normals=None):
        if material not in self.mats:
            self.mats.append(material)
        self.faces.append((tuple(idx), [tuple(u) for u in uvs], material, normals))

    def build(self, smooth=True):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(v) for v in self.verts], [], [f[0] for f in self.faces])
        uv = me.uv_layers.new(name="UVMap")
        for poly, f in zip(me.polygons, self.faces):
            poly.material_index = self.mats.index(f[2])
            poly.use_smooth = smooth
            for li, loop in enumerate(poly.loop_indices):
                uv.data[loop].uv = f[1][li]
        for name in self.mats:
            me.materials.append(_MATS[name])
        if any(f[3] is not None for f in self.faces):
            normals = []
            for poly, f in zip(me.polygons, self.faces):
                for li, vi in enumerate(f[0]):
                    if f[3] is not None:
                        normals.append(tuple(f[3][li]))
                    else:
                        normals.append(tuple(poly.normal))
            me.validate(clean_customdata=False)
            try:
                me.normals_split_custom_set(normals)
            except Exception as error:  # pragma: no cover - Blender-Version ohne API
                print("custom normals unavailable:", error)
        else:
            me.validate()
        me.update()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def tube(b, points, radii, material, sides=8, u_repeat=1.0, v_scale=0.5, cap=False, jitter=0.0, seed=0):
    """Verjüngte Röhre entlang einer Punktliste (Stamm, Ast, Säule)."""
    rnd = random.Random(seed)
    rings = []
    prev_side = None
    length = 0.0
    for i, p in enumerate(points):
        p = Vector(p)
        if i < len(points) - 1:
            d = (Vector(points[i + 1]) - p).normalized()
        else:
            d = (p - Vector(points[i - 1])).normalized()
        if prev_side is None:
            up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
            side = d.cross(up).normalized()
        else:
            side = (prev_side - d * prev_side.dot(d)).normalized()
        prev_side = side
        other = d.cross(side).normalized()
        if i > 0:
            length += (p - Vector(points[i - 1])).length
        ring = []
        for s in range(sides + 1):
            a = s / sides * math.tau
            rr = radii[i] * (1.0 + (rnd.uniform(-jitter, jitter) if s < sides else 0))
            off = side * math.cos(a) * rr + other * math.sin(a) * rr
            ring.append((b.v(p + off), (s / sides * u_repeat, length * v_scale)))
        if jitter and ring:
            # Naht schließen: letzter Punkt = erster Punkt geometrisch.
            b.verts[ring[-1][0]] = b.verts[ring[0][0]].copy()
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(sides):
            idx = (r0[s][0], r0[s + 1][0], r1[s + 1][0], r1[s][0])
            uvs = (r0[s][1], r0[s + 1][1], r1[s + 1][1], r1[s][1])
            b.face(idx, uvs, material)
    if cap:
        top = rings[-1]
        c = b.v(Vector(points[-1]))
        for s in range(sides):
            b.face((top[s][0], top[s + 1][0], c), ((0.5 + 0.4 * math.cos(s / sides * math.tau), 0.5 + 0.4 * math.sin(s / sides * math.tau)),
                                                     (0.5 + 0.4 * math.cos((s + 1) / sides * math.tau), 0.5 + 0.4 * math.sin((s + 1) / sides * math.tau)),
                                                     (0.5, 0.5)), material)
    return rings


def card(b, center, right, up, uv_rect, material, normal=None, bend=0.0, segments=1):
    """Blattkarte; bend wölbt die Karte entlang 'up'. normal: Kronen-Normale."""
    c = Vector(center)
    right, up = Vector(right), Vector(up)
    fwd = right.cross(up).normalized()
    u0, v0, u1, v1 = uv_rect
    rows = []
    for k in range(segments + 1):
        t = k / segments
        off = up * t + fwd * (bend * t * t)
        rows.append([b.v(c - right * 0.5 + off), b.v(c + right * 0.5 + off)])
    for k in range(segments):
        t0, t1 = k / segments, (k + 1) / segments
        idx = (rows[k][0], rows[k][1], rows[k + 1][1], rows[k + 1][0])
        uvs = ((u0, v0 + (v1 - v0) * t0), (u1, v0 + (v1 - v0) * t0), (u1, v0 + (v1 - v0) * t1), (u0, v0 + (v1 - v0) * t1))
        nrm = None
        if normal is not None:
            nrm = [tuple(normal(b.verts[i])) for i in idx]
        b.face(idx, uvs, material, nrm)


def box_uv_face(points, normal, scale):
    n = Vector(normal)
    ax = max(range(3), key=lambda i: abs(n[i]))
    out = []
    for p in points:
        if ax == 0:
            out.append((p.y * scale, p.z * scale))
        elif ax == 1:
            out.append((p.x * scale, p.z * scale))
        else:
            out.append((p.x * scale, p.y * scale))
    return out


def add_bm(b, bm, material, uv_scale=0.5, offset=Vector((0, 0, 0)), material_fn=None):
    """Übernimmt ein bmesh mit Box-Projektion-UVs in einen Builder."""
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    base = len(b.verts)
    for v in bm.verts:
        b.verts.append(v.co.copy() + offset)
    for f in bm.faces:
        pts = [v.co + offset for v in f.verts]
        uvs = box_uv_face(pts, f.normal, uv_scale)
        m = material_fn(f) if material_fn else material
        b.face([base + v.index for v in f.verts], uvs, m)


def rock_bm(seed, size=(1, 1, 1), subdiv=3, rough=0.35, flat=0.25):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 3.17, seed * 1.31, seed * 2.03))
    for v in bm.verts:
        p = v.co.copy()
        n = noise.fractal(p * 1.2 + off, 0.6, 2.0, 4) * rough
        n += noise.noise(p * 3.1 + off) * rough * 0.35
        v.co = p * (1.0 + n)
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if v.co.z < -size[2] * flat:
            v.co.z = -size[2] * flat + (v.co.z + size[2] * flat) * 0.15
    # Kanten brechen: zufällige Facetten etwas eindrücken.
    return bm


def box_bm(sx, sy, sz, at=(0, 0, 0), rot=0.0, tilt=(0.0, 0.0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def bevel_box(b, sx, sy, sz, at, material, rot=0.0, tilt=(0.0, 0.0), bevel=0.04, uv_scale=0.5, chip=0.0, seed=0):
    bm = box_bm(sx, sy, sz, (0, 0, 0))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, sx * 0.3, sy * 0.3, sz * 0.3), segments=1, affect="EDGES")
    if chip > 0:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co += Vector((rnd.uniform(-chip, chip), rnd.uniform(-chip, chip), rnd.uniform(-chip, chip)))
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    add_bm(b, bm, material, uv_scale)
    bm.free()


def lathe(b, profile, material, sides=16, at=(0, 0, 0), u_repeat=1.0, v_scale=0.5, flutes=0, flute_depth=0.0):
    """Drehkörper aus (radius, z)-Profil."""
    at = Vector(at)
    rings = []
    length = 0.0
    for i, (r, z) in enumerate(profile):
        if i:
            length += math.hypot(r - profile[i - 1][0], z - profile[i - 1][1])
        ring = []
        for s in range(sides + 1):
            a = s / sides * math.tau
            rr = r
            if flutes and 0 < i < len(profile) - 1:
                rr = r * (1.0 - flute_depth * (0.5 + 0.5 * math.cos(a * flutes)))
            ring.append((b.v(at + Vector((math.cos(a) * rr, math.sin(a) * rr, z))), (s / sides * u_repeat, length * v_scale)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(sides):
            r0, r1 = rings[i], rings[i + 1]
            b.face((r0[s][0], r0[s + 1][0], r1[s + 1][0], r1[s][0]), (r0[s][1], r0[s + 1][1], r1[s + 1][1], r1[s][1]), material)
    return rings


def ellipsoid(b, center, size, material, seg=10, rings=6, rot=0.0):
    c = Vector(center)
    grid = []
    for r in range(rings + 1):
        th = r / rings * math.pi
        row = []
        for s in range(seg + 1):
            ph = s / seg * math.tau
            p = Vector((math.sin(th) * math.cos(ph) * size[0], math.sin(th) * math.sin(ph) * size[1], math.cos(th) * size[2]))
            p = Matrix.Rotation(rot, 3, "Z") @ p
            row.append(b.v(c + p))
        grid.append(row)
    for r in range(rings):
        for s in range(seg):
            b.face((grid[r][s], grid[r + 1][s], grid[r + 1][s + 1], grid[r][s + 1]),
                   ((s / seg, r / rings), (s / seg, (r + 1) / rings), ((s + 1) / seg, (r + 1) / rings), ((s + 1) / seg, r / rings)), material)


# ------------------------------------------------------------------ Pflanzen

ATLAS_CELLS = [(0.0, 0.5, 0.5, 1.0), (0.5, 0.5, 1.0, 1.0), (0.0, 0.0, 0.5, 0.5), (0.5, 0.0, 1.0, 0.5)]


def broadleaf_tree(name, seed, height=10.0, leaf_mat="leaves_broad", spread=1.0, clusters=14):
    rnd = random.Random(seed)
    b = Builder(name)
    trunk_h = height * 0.52
    pts, radii = [], []
    lean = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))
    base_r = height * 0.045
    for i in range(9):
        t = i / 8
        p = Vector((0, 0, t * trunk_h)) + lean * (t * t)
        p += Vector((math.sin(t * 5 + seed) * 0.12, math.cos(t * 4 + seed) * 0.12, 0))
        pts.append(p)
        flare = 1.0 + 0.9 * max(0.0, 1.0 - t * 5) ** 2
        radii.append(base_r * (1.0 - 0.42 * t) * flare)
    tube(b, pts, radii, "bark", sides=10, u_repeat=2.0, v_scale=0.35, jitter=0.06, seed=seed)
    crown_center = Vector((lean.x, lean.y, height * 0.68))
    ends = []
    # Wurzelansätze
    for k in range(5):
        a = k / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        root = [Vector((0, 0, 0.55)) + d * base_r * 0.6, d * base_r * 2.4 + Vector((0, 0, 0.08)), d * base_r * 3.6 + Vector((0, 0, -0.25))]
        tube(b, root, [base_r * 0.55, base_r * 0.32, base_r * 0.12], "bark", sides=6, u_repeat=1, v_scale=0.4, seed=seed + k)
    n_main = 6
    for k in range(n_main):
        a = k / n_main * math.tau + rnd.uniform(-0.35, 0.35)
        t0 = rnd.uniform(0.55, 0.95)
        start = pts[int(t0 * 8)]
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(0.55, 1.1))).normalized()
        L = height * rnd.uniform(0.28, 0.38) * spread
        mid = start + d * L * 0.5 + Vector((0, 0, L * 0.12))
        end = start + d * L + Vector((0, 0, L * 0.1))
        r0 = radii[int(t0 * 8)] * 0.62
        tube(b, [start, mid, end], [r0, r0 * 0.6, r0 * 0.25], "bark", sides=7, u_repeat=1, v_scale=0.4, seed=seed + 10 + k)
        ends.append(end)
        for j in range(2):
            s = start.lerp(end, rnd.uniform(0.45, 0.8))
            dd = (d + Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7), rnd.uniform(0.0, 0.6)))).normalized()
            e = s + dd * L * rnd.uniform(0.3, 0.5)
            tube(b, [s, e], [r0 * 0.35, r0 * 0.1], "bark", sides=5, u_repeat=1, v_scale=0.4, seed=seed + 20 + k * 2 + j)
            ends.append(e)
    ends.append(crown_center + Vector((0, 0, height * 0.22)))
    # Blattbüschel: Karten um jedes Astende, Normalen von der Kronenmitte weg.
    radius = height * 0.36 * spread

    def crown_normal(p):
        n = (p - crown_center)
        n.z *= 0.8
        n.z += radius * 0.35
        return n.normalized()

    cards = 0
    target = clusters * 8
    while cards < target:
        e = ends[cards % len(ends)]
        jitter = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.9))) * height * 0.12
        c = e + jitter
        size = height * rnd.uniform(0.2, 0.27)
        yaw = rnd.uniform(0, math.tau)
        pitch = rnd.uniform(-0.6, 0.9)
        right = Vector((math.cos(yaw), math.sin(yaw), 0)) * size
        up = Vector((-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))).normalized() * size
        card(b, c - up * 0.5, right, up, ATLAS_CELLS[rnd.randrange(4)], leaf_mat, crown_normal, bend=size * 0.12, segments=2)
        cards += 1
    return b.build()


def palm(name, seed, height=9.5, fronds=11):
    rnd = random.Random(seed)
    b = Builder(name)
    pts, radii = [], []
    bend = rnd.uniform(0.8, 1.6)
    yaw = rnd.uniform(0, math.tau)
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    segs = 14
    for i in range(segs + 1):
        t = i / segs
        p = Vector((0, 0, t * height)) + d * (bend * t * t * height * 0.22)
        pts.append(p)
        radii.append(height * 0.03 * (1.0 - 0.32 * t) * (1.0 + 0.6 * max(0, 1 - t * 6) ** 2))
    tube(b, pts, radii, "palm_bark", sides=9, u_repeat=1.0, v_scale=0.28, seed=seed)
    top = pts[-1]
    # Kokosnüsse
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        ellipsoid(b, top + Vector((math.cos(a) * 0.32, math.sin(a) * 0.32, -0.3)), (0.22, 0.22, 0.26), "coconut", seg=8, rings=5)
    L = height * 0.5
    W = L / 4.0

    for k in range(fronds):
        a = k / fronds * math.tau + rnd.uniform(-0.2, 0.2)
        rise = rnd.uniform(0.25, 0.9) if k % 3 else rnd.uniform(-0.3, 0.1)
        dirv = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        n_seg = 8
        prev = None
        for s in range(n_seg + 1):
            t = s / n_seg
            pos = top + dirv * (L * t) + Vector((0, 0, L * (rise * t - 0.75 * t * t)))
            w = W * 0.5 * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 1.05 + 0.05)))
            spine = pos + Vector((0, 0, 0.06))
            lft = pos - side * w + Vector((0, 0, -w * 0.35))
            rgt = pos + side * w + Vector((0, 0, -w * 0.35))
            row = (b.v(lft), b.v(spine), b.v(rgt))
            if prev is not None:
                t0 = (s - 1) / n_seg
                up_n = Vector((0, 0, 1)) * 0.75 + dirv * 0.25
                nr = [tuple(up_n.normalized())] * 4
                b.face((prev[0], prev[1], row[1], row[0]), ((t0, 0.0), (t0, 0.5), (t, 0.5), (t, 0.0)), "palm_frond", nr)
                b.face((prev[1], prev[2], row[2], row[1]), ((t0, 0.5), (t0, 1.0), (t, 1.0), (t, 0.5)), "palm_frond", nr)
            prev = row
    return b.build()


def bush(name, seed, size=1.6, leaf_mat="leaves_broad", count=34):
    rnd = random.Random(seed)
    b = Builder(name)
    center = Vector((0, 0, size * 0.45))
    for k in range(5):
        a = k / 5 * math.tau
        tube(b, [Vector((0, 0, 0)), Vector((math.cos(a) * size * 0.3, math.sin(a) * size * 0.3, size * 0.5))], [0.05, 0.02], "bark", sides=4, seed=seed + k)

    def nrm(p):
        n = p - center
        n.z += size * 0.4
        return n.normalized()

    for k in range(count):
        th = rnd.uniform(0, math.tau)
        ph = rnd.uniform(0.1, 1.35)
        dirv = Vector((math.cos(th) * math.sin(ph), math.sin(th) * math.sin(ph), math.cos(ph) * 0.8))
        c = center + dirv * size * rnd.uniform(0.25, 0.55)
        s = size * rnd.uniform(0.5, 0.75)
        right = Vector((-math.sin(th), math.cos(th), 0)) * s
        up = (Vector((0, 0, 1)) * 0.75 + dirv * 0.5).normalized() * s
        card(b, c - up * 0.45, right, up, ATLAS_CELLS[rnd.randrange(4)], leaf_mat, nrm, bend=s * 0.15, segments=2)
    return b.build()


def fern(name, seed, size=1.4, fronds=9):
    rnd = random.Random(seed)
    b = Builder(name)
    for k in range(fronds):
        a = k / fronds * math.tau + rnd.uniform(-0.2, 0.2)
        dirv = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        L = size * rnd.uniform(0.8, 1.1)
        W = L * 0.5
        rise = rnd.uniform(0.9, 1.5)
        prev = None
        for s in range(6):
            t = s / 5
            pos = dirv * (L * t * 0.9) + Vector((0, 0, L * (rise * t - 1.05 * t * t) * 0.8))
            w = W * 0.5 * (1.0 - t * 0.7)
            row = (b.v(pos - side * w), b.v(pos + Vector((0, 0, 0.02))), b.v(pos + side * w))
            if prev is not None:
                t0 = (s - 1) / 5
                nr = [(0, 0, 1)] * 4
                b.face((prev[0], prev[1], row[1], row[0]), ((t0, 0.0), (t0, 0.5), (t, 0.5), (t, 0.0)), "fern_frond", nr)
                b.face((prev[1], prev[2], row[2], row[1]), ((t0, 0.5), (t0, 1.0), (t, 1.0), (t, 0.5)), "fern_frond", nr)
            prev = row
    return b.build()


def grass_tuft(name, flowers=False, w=1.3, h=0.75):
    b = Builder(name)
    u0, u1 = (0.5, 1.0) if flowers else (0.0, 0.5)
    for k in range(3):
        a = k / 3 * math.pi
        right = Vector((math.cos(a), math.sin(a), 0)) * w
        fwd = Vector((-math.sin(a), math.cos(a), 0))
        lean = fwd * 0.12
        p = [Vector((0, 0, 0)) - right * 0.5, Vector((0, 0, 0)) + right * 0.5]
        q = [p[0] + Vector((0, 0, h)) + lean, p[1] + Vector((0, 0, h)) + lean]
        idx = (b.v(p[0]), b.v(p[1]), b.v(q[1]), b.v(q[0]))
        b.face(idx, ((u0, 0.0), (u1, 0.0), (u1, 1.0), (u0, 1.0)), "grass_tuft", [(0, 0, 1)] * 4)
    return b.build()


# ------------------------------------------------------------------ Fels, Ruinen, Höhle

def rock(name, seed, size, subdiv=3, material="rock_moss"):
    b = Builder(name)
    bm = rock_bm(seed, size, subdiv=subdiv)
    add_bm(b, bm, material, uv_scale=0.35)
    bm.free()
    return b.build()


def column(b, at, height, radius, material, broken=False, seed=0, drums=3, capital=True):
    rnd = random.Random(seed)
    at = Vector(at)
    bevel_box(b, radius * 3.0, radius * 3.0, radius * 0.6, at + Vector((0, 0, radius * 0.3)), material, bevel=0.05, uv_scale=0.6, chip=0.03, seed=seed)
    lathe(b, [(radius * 1.25, radius * 0.6), (radius * 1.1, radius * 0.85), (radius, radius * 1.0)], material, sides=16, at=at, v_scale=0.6)
    z = radius
    drum_h = (height - radius * 2.2) / drums
    for k in range(drums):
        top = z + drum_h
        prof = [(radius * (1 - 0.04 * k), z + 0.01), (radius * (1 - 0.04 * k) * 0.99, top - 0.02)]
        prof = [prof[0], ((prof[0][0] + prof[1][0]) / 2, (z + top) / 2), prof[1]]
        rings = lathe(b, prof, material, sides=20, at=at, v_scale=0.5, flutes=10, flute_depth=0.08)
        if broken and k == drums - 1:
            # Abgebrochene Oberkante: obersten Ring zackig absenken.
            for vi, _ in rings[-1]:
                b.verts[vi].z -= rnd.uniform(0.0, drum_h * 0.55)
            break
        z = top
    if capital and not broken:
        lathe(b, [(radius * 0.95, z), (radius * 1.2, z + radius * 0.35), (radius * 1.3, z + radius * 0.45)], material, sides=16, at=at, v_scale=0.6)
        bevel_box(b, radius * 3.0, radius * 3.0, radius * 0.45, at + Vector((0, 0, z + radius * 0.68)), material, bevel=0.05, uv_scale=0.6, chip=0.04, seed=seed + 3)


def ruins_set():
    out = []
    b = Builder("ruin_column")
    column(b, (0, 0, 0), 6.4, 0.42, "ruin_moss", seed=3)
    out.append(b.build())
    b = Builder("ruin_column_broken")
    column(b, (0, 0, 0), 4.6, 0.42, "ruin_moss", broken=True, seed=5)
    for k in range(5):
        bm = rock_bm(40 + k, (0.25, 0.2, 0.15), subdiv=1, rough=0.5)
        add_bm(b, bm, "ruin_moss", 0.5, Vector((math.cos(k) * 1.1, math.sin(k * 1.7) * 1.1, 0.1)))
        bm.free()
    out.append(b.build())
    b = Builder("ruin_column_fallen")
    for k in range(3):
        rings = lathe(b, [(0.4, 0), (0.4, 0.9)], "ruin_moss", sides=20, flutes=10, flute_depth=0.08, v_scale=0.5)
        rot = Matrix.Rotation(math.pi / 2, 3, "Y")
        rot = Matrix.Rotation(0.12 * (k - 1), 3, "Z") @ rot
        for ring in rings:
            for vi, _ in ring:
                b.verts[vi] = rot @ b.verts[vi] + Vector((k * 1.05 - 1.0, (k % 2) * 0.12, 0.36))
    bevel_box(b, 1.2, 1.2, 0.36, (2.2, 0.6, 0.18), "ruin_moss", rot=0.5, tilt=(0.2, 0.1), chip=0.04, seed=8)
    out.append(b.build())
    # Mauer mit Steinlagen, Lücken und gezackter Oberkante.
    b = Builder("ruin_wall")
    rnd = random.Random(12)
    length = 7.0
    for row in range(7):
        z = row * 0.52
        x = -length / 2 + (0.35 if row % 2 else 0.0)
        limit = length * (1.0 - row * 0.09) - rnd.uniform(0, 1.6) * (row > 2)
        while x < -length / 2 + limit:
            w = rnd.uniform(0.7, 1.15)
            if row > 1 and rnd.random() < 0.08:
                x += w
                continue
            bevel_box(b, w - 0.04, 0.62 + rnd.uniform(-0.04, 0.04), 0.48, (x + w / 2, rnd.uniform(-0.03, 0.03), z + 0.25),
                      "ruin_moss", rot=rnd.uniform(-0.03, 0.03), bevel=0.05, uv_scale=0.45, chip=0.025, seed=row * 31 + int(x * 10))
            x += w
    for k in range(6):
        bm = rock_bm(60 + k, (0.35, 0.28, 0.2), subdiv=1, rough=0.45)
        add_bm(b, bm, "ruin_moss", 0.5, Vector((rnd.uniform(-3.4, 3.4), rnd.uniform(0.5, 1.2) * (1 if k % 2 else -1), 0.12)))
        bm.free()
    out.append(b.build())
    # Bogenfragment: zwei Pfeiler, halber Bogen aus Keilsteinen.
    b = Builder("ruin_arch")
    for side in (-1, 1):
        for row in range(6):
            bevel_box(b, 0.9, 0.9, 0.55, (side * 2.0, 0, row * 0.56 + 0.28), "ruin_moss", bevel=0.05, uv_scale=0.45, chip=0.025, seed=row * 7 + side)
    segs = 9
    for k in range(segs):
        if k >= segs - 3:
            break  # rechte Bogenhälfte eingestürzt
        a0 = math.pi - k / segs * math.pi
        a = a0 - math.pi / segs * 0.5
        cx, cz = math.cos(a) * 2.0, 3.36 + math.sin(a) * 2.0
        bevel_box(b, 0.62, 0.9, 0.5, (cx, 0, cz), "ruin_moss", tilt=(0, -(a - math.pi / 2)), bevel=0.05, uv_scale=0.45, chip=0.02, seed=90 + k)
    out.append(b.build())
    return out


def crenellations(b, at, radius, z, count, material):
    for k in range(count):
        if k % 2:
            continue
        a = k / count * math.tau
        bevel_box(b, radius * 0.55, 0.55, 0.7, (at[0] + math.cos(a) * radius, at[1] + math.sin(a) * radius, z + 0.35), material,
                  rot=a, bevel=0.04, uv_scale=0.5, chip=0.02, seed=k)


def castle():
    """Sternenschloss: zwei Rundtürme, Halle mit Tor, Zinnen, Schindeldächer, abgebrochener Seitenturm."""
    b = Builder("star_castle")
    for side in (-1, 1):
        at = (side * 6.8, 0, 0)
        lathe(b, [(2.6, 0.0), (2.3, 1.0), (2.15, 9.5), (2.5, 10.0)], "stone_block", sides=20, at=at, u_repeat=4, v_scale=0.3)
        lathe(b, [(2.5, 10.0), (2.55, 10.4), (1.9, 10.4)], "stone_block", sides=20, at=at, u_repeat=4)
        crenellations(b, at, 2.3, 10.4, 16, "stone_block")
        lathe(b, [(2.3, 10.6), (1.4, 13.0), (0.4, 15.0), (0.0, 15.6)], "roof_tiles", sides=20, at=at, u_repeat=3, v_scale=0.25)
        tube(b, [Vector((at[0], 0, 15.4)), Vector((at[0], 0, 17.2))], [0.05, 0.04], "metal_dark", sides=4)
        for k, z in enumerate((3.2, 6.4)):
            bevel_box(b, 0.5, 0.3, 1.0, (at[0] - side * 0.4, 2.2, z), "window_glow", bevel=0.03)
    # Halle
    for row in range(1):
        bevel_box(b, 11.4, 4.6, 7.0, (0, 0, 3.5), "stone_block", bevel=0.08, uv_scale=0.3)
    for k in range(12):
        x = -5.4 + k * 0.98
        bevel_box(b, 0.6, 0.6, 0.7, (x, 2.0, 7.35), "stone_block", bevel=0.04, uv_scale=0.5, chip=0.02, seed=k)
    # Satteldach
    base = 7.0
    pts = [Vector((-5.9, -2.6, base)), Vector((5.9, -2.6, base)), Vector((5.9, 0.0, base + 3.6)), Vector((-5.9, 0.0, base + 3.6))]
    for mirror in (1, -1):
        q = [Vector((p.x, p.y * mirror, p.z)) for p in pts]
        idx = [b.v(p) for p in q]
        uv = ((0, 0), (4, 0), (4, 1.6), (0, 1.6))
        if mirror < 0:
            idx, uv = idx[::-1], uv[::-1]
        b.face(idx, uv, "roof_tiles")
    # Torbogen mit Holztor
    bevel_box(b, 3.0, 0.4, 4.4, (0, 2.4, 2.2), "wood_dark", bevel=0.05, uv_scale=0.6)
    for k in range(9):
        a = math.pi - k / 8 * math.pi
        bevel_box(b, 0.55, 0.7, 0.5, (math.cos(a) * 1.8, 2.45, 4.0 + math.sin(a) * 1.3), "stone_block", tilt=(0, -(a - math.pi / 2)), bevel=0.04, uv_scale=0.5)
    for side in (-1, 1):
        bevel_box(b, 0.9, 0.35, 1.4, (side * 3.6, 2.35, 4.6), "window_glow", bevel=0.04)
        tube(b, [Vector((side * 2.4, 2.5, 5.4)), Vector((side * 2.4, 2.9, 5.6))], [0.05, 0.05], "metal_dark", sides=4)
    return b.build()


def stone_arch(name, half_span, spring, depth, pillars, pillar_h=0.0, segments=13):
    """Vollständiger Steinbogen aus Keilsteinen; optional mit Pfeilern."""
    b = Builder(name)
    if pillars:
        rows = max(1, int(pillar_h / 0.58))
        for side in (-1, 1):
            for row in range(rows):
                bevel_box(b, 0.82, depth, pillar_h / rows - 0.03, (side * half_span, 0, row * pillar_h / rows + pillar_h / rows / 2),
                          "stone_block", rot=0.02 * ((row % 2) * 2 - 1), bevel=0.05, uv_scale=0.5, chip=0.02, seed=row * 5 + side)
    for k in range(segments):
        a = math.pi - (k + 0.5) / segments * math.pi
        cx, cz = math.cos(a) * half_span, spring + math.sin(a) * half_span
        h = 0.7 if k != segments // 2 else 0.95
        bevel_box(b, math.pi * half_span / segments - 0.04, depth * (1.08 if k == segments // 2 else 1.0), h, (cx, 0, cz), "stone_block",
                  tilt=(0, -(a - math.pi / 2)), bevel=0.05, uv_scale=0.5, chip=0.015, seed=40 + k)
    return b.build()


def shells():
    b = Builder("shells")
    rnd = random.Random(5)
    for k in range(7):
        at = Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.6, 0.6), 0))
        rot = rnd.uniform(0, math.tau)
        prof = [(0.0, 0.0), (0.16, 0.0), (0.14, 0.06), (0.06, 0.1), (0.0, 0.11)]
        rings = lathe(b, prof, "shell", sides=10, flutes=7, flute_depth=0.25)
        for ring in rings:
            for vi, _ in ring:
                v = b.verts[vi]
                v.x *= 1.0
                v.y *= 0.8
                b.verts[vi] = Matrix.Rotation(rot, 3, "Z") @ v * rnd.uniform(0.7, 1.4) + at
    return b.build()


def cave_arch():
    """Höhleneingang: Felsbogen mit dunklem Inneren (Tunnel nach hinten geschlossen)."""
    b = Builder("cave_entrance")
    rings = []
    sides = 14
    depth_steps = 6
    for dz in range(depth_steps + 1):
        y = -dz * 1.2
        ring = []
        for s in range(sides + 1):
            a = s / sides * math.pi
            r_in = 3.2 * (1.0 - dz * 0.06)
            p = Vector((math.cos(a) * r_in * 1.15, y, math.sin(a) * r_in))
            n = noise.noise(p * 0.7 + Vector((5, 1, 2))) * 0.45
            p += Vector((math.cos(a), 0, math.sin(a))) * n
            ring.append(b.v(p))
        rings.append(ring)
    for dz in range(depth_steps):
        for s in range(sides):
            idx = (rings[dz][s + 1], rings[dz][s], rings[dz + 1][s], rings[dz + 1][s + 1])
            uv = box_uv_face([b.verts[i] for i in idx], Vector((0, 1, 0)), 0.35)
            b.face(idx, uv, "cave_dark")
    # Rückwand
    back = rings[-1]
    c = b.v(Vector((0, -depth_steps * 1.2, 0)))
    for s in range(sides):
        b.face((back[s + 1], back[s], c), ((0, 0), (1, 0), (0.5, 1)), "cave_dark")
    # Boden
    fl = [b.v((-3.5, 0.2, 0.02)), b.v((3.5, 0.2, 0.02)), b.v((3.0, -depth_steps * 1.2, 0.02)), b.v((-3.0, -depth_steps * 1.2, 0.02))]
    b.face((fl[0], fl[3], fl[2], fl[1]), ((0, 0), (0, 2), (2, 2), (2, 0)), "cave_dark")
    # Äußere Felsschale aus großen Blöcken
    for k in range(11):
        a = k / 10 * math.pi
        bm = rock_bm(70 + k, (1.7, 2.6, 1.6), subdiv=2, rough=0.4, flat=0.6)
        add_bm(b, bm, "rock_moss", 0.3, Vector((math.cos(a) * 4.4, -2.2, math.sin(a) * 4.1)))
        bm.free()
    bm = rock_bm(90, (5.4, 4.2, 2.4), subdiv=3, rough=0.35, flat=0.2)
    add_bm(b, bm, "rock_moss", 0.3, Vector((0, -4.6, 4.4)))
    bm.free()
    return b.build()


# ------------------------------------------------------------------ Requisiten

def lighthouse():
    b = Builder("lighthouse")
    # Sockel
    lathe(b, [(3.0, 0.0), (3.0, 1.2), (2.7, 1.3)], "stone_block", sides=10, v_scale=0.4, u_repeat=4)
    h = 13.0
    bands = 6
    for k in range(bands):
        z0, z1 = 1.3 + k * h / bands, 1.3 + (k + 1) * h / bands
        r0 = 2.4 - 0.8 * (z0 - 1.3) / h
        r1 = 2.4 - 0.8 * (z1 - 1.3) / h
        lathe(b, [(r0, z0), (r1, z1)], "lighthouse_red" if k % 2 else "lighthouse_white", sides=18, u_repeat=3, v_scale=0.35)
    top = 1.3 + h
    lathe(b, [(1.6, top), (2.3, top + 0.25), (2.3, top + 0.45), (1.5, top + 0.5)], "metal_dark", sides=18)
    for k in range(16):
        a = k / 16 * math.tau
        tube(b, [Vector((math.cos(a) * 2.15, math.sin(a) * 2.15, top + 0.45)), Vector((math.cos(a) * 2.15, math.sin(a) * 2.15, top + 1.35))], [0.04, 0.04], "metal_dark", sides=4)
    lathe(b, [(2.2, top + 1.3), (2.2, top + 1.4)], "metal_dark", sides=24)
    lathe(b, [(1.15, top + 0.5), (1.15, top + 2.4)], "lamp_glass", sides=12, u_repeat=2)
    lathe(b, [(1.45, top + 2.4), (0.25, top + 3.5), (0.0, top + 3.6)], "lighthouse_red", sides=16)
    ellipsoid(b, (0, 0, top + 3.75), (0.22, 0.22, 0.22), "metal_dark", seg=8, rings=5)
    # Tür und Fenster
    bevel_box(b, 0.9, 0.3, 1.8, (0, -2.33, 2.2), "wood", bevel=0.03)
    for k in range(3):
        z = 4.5 + k * 3.5
        r = 2.4 - 0.8 * (z - 1.3) / h
        bevel_box(b, 0.5, 0.25, 0.8, (0, -r + 0.05, z), "window_dark", bevel=0.02)
    return b.build()


def campfire():
    b = Builder("campfire")
    for k in range(9):
        a = k / 9 * math.tau
        bm = rock_bm(100 + k, (0.28, 0.22, 0.2), subdiv=1, rough=0.4)
        add_bm(b, bm, "rock", 0.5, Vector((math.cos(a) * 0.85, math.sin(a) * 0.85, 0.12)))
        bm.free()
    for k in range(5):
        a = k / 5 * math.tau
        p0 = Vector((math.cos(a) * 0.65, math.sin(a) * 0.65, 0.08))
        p1 = Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.7))
        tube(b, [p0, p1], [0.09, 0.07], "bark", sides=6, u_repeat=1, v_scale=0.8, cap=True)
    lathe(b, [(0.0, 0.05), (0.62, 0.05), (0.0, 0.06)], "embers", sides=12)
    for k in range(3):
        a = k / 3 * math.pi
        r = Vector((math.cos(a), math.sin(a), 0)) * 1.0
        card(b, Vector((0, 0, 0.12)), r, Vector((0, 0, 1.45)), (0, 0, 1, 1), "flame")
    # Sitzstämme
    for k, a in enumerate((0.6, 2.4, 4.3)):
        c = Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 0.28))
        d = Vector((-math.sin(a), math.cos(a), 0)) * 0.9
        tube(b, [c - d, c + d], [0.28, 0.26], "bark", sides=8, u_repeat=2, v_scale=0.5, cap=True)
    return b.build()


def tent():
    b = Builder("tent")
    w, d, h = 2.4, 3.0, 2.2
    pts = {
        "fl": Vector((-w / 2, d / 2, 0)), "fr": Vector((w / 2, d / 2, 0)), "bl": Vector((-w / 2, -d / 2, 0)), "br": Vector((w / 2, -d / 2, 0)),
        "ft": Vector((0, d / 2 + 0.15, h)), "bt": Vector((0, -d / 2 - 0.15, h)),
    }
    def q(a, c, e, f, m):
        idx = [b.v(pts[k]) for k in (a, c, e, f)]
        b.face(idx, ((0, 0), (2, 0), (2, 2), (0, 2)), m)
    q("bl", "fl", "ft", "bt", "fabric")
    q("fr", "br", "bt", "ft", "fabric")
    idx = [b.v(pts[k]) for k in ("br", "bl", "bt")]
    b.face(idx, ((0, 0), (2, 0), (1, 2)), "fabric")
    # offene Klappe vorne
    idx = [b.v(pts["fl"]), b.v(pts["fl"] + Vector((-0.6, 0.7, 0))), b.v(pts["ft"])]
    b.face(idx, ((0, 0), (1, 0), (0.5, 1)), "fabric")
    for k in ("ft", "bt"):
        tube(b, [pts[k] * Vector((1, 1, 0)), pts[k] + Vector((0, 0, 0.25))], [0.05, 0.05], "wood", sides=5)
    tube(b, [pts["ft"] + Vector((0, 0, 0.05)), pts["bt"] + Vector((0, 0, 0.05))], [0.04, 0.04], "wood", sides=5)
    return b.build()


def crate():
    b = Builder("crate")
    bevel_box(b, 1.0, 1.0, 1.0, (0, 0, 0.5), "wood", bevel=0.05, uv_scale=1.0)
    for z in (0.08, 0.92):
        bevel_box(b, 1.04, 1.04, 0.1, (0, 0, z), "wood_dark", bevel=0.02, uv_scale=1.0)
    return b.build()


def barrel():
    b = Builder("barrel")
    prof = [(0.0, 0.0), (0.42, 0.0), (0.5, 0.35), (0.53, 0.6), (0.5, 0.85), (0.42, 1.2), (0.0, 1.2)]
    lathe(b, prof, "wood", sides=16, u_repeat=2, v_scale=0.8)
    for z, r in ((0.2, 0.47), (0.6, 0.54), (1.0, 0.47)):
        lathe(b, [(r, z - 0.05), (r + 0.015, z), (r, z + 0.05)], "metal_dark", sides=16)
    return b.build()


def signpost():
    b = Builder("signpost")
    tube(b, [Vector((0, 0, -0.2)), Vector((0, 0, 3.2))], [0.12, 0.1], "wood", sides=6, u_repeat=1, v_scale=0.4, cap=True)
    for k, (z, yaw) in enumerate(((2.6, 0.0), (2.0, math.pi), (1.45, 0.35))):
        rot = Matrix.Rotation(yaw, 3, "Z")
        L, H, T = 1.6, 0.42, 0.08
        base = Vector((0.12, 0, z))
        pts = [Vector((0, -T, -H / 2)), Vector((L, -T, -H / 2)), Vector((L + 0.35, -T, 0)), Vector((L, -T, H / 2)), Vector((0, -T, H / 2))]
        front = [b.v(rot @ (p + base)) for p in pts]
        back = [b.v(rot @ (p + base + Vector((0, 2 * T, 0)))) for p in pts]
        uv = [(p.x * 0.5, p.z * 0.5 + 0.5) for p in pts]
        b.face(front[::-1], uv[::-1], "wood")
        b.face(back, uv, "wood")
        for i in range(5):
            j = (i + 1) % 5
            b.face((front[i], front[j], back[j], back[i]), ((0, 0), (0.2, 0), (0.2, 0.1), (0, 0.1)), "wood")
    return b.build()


# ------------------------------------------------------------------ Tiere

def crab():
    b = Builder("crab")
    ellipsoid(b, (0, 0, 0.26), (0.42, 0.32, 0.16), "crab_shell", seg=12, rings=6)
    for side in (-1, 1):
        for k in range(3):
            y0 = (k - 1) * 0.16
            p0 = Vector((side * 0.32, y0, 0.24))
            p1 = Vector((side * 0.62, y0 * 1.4, 0.34))
            p2 = Vector((side * 0.82, y0 * 1.7, 0.0))
            tube(b, [p0, p1, p2], [0.045, 0.035, 0.015], "crab_shell", sides=5)
        arm = [Vector((side * 0.25, 0.25, 0.26)), Vector((side * 0.42, 0.52, 0.32))]
        tube(b, arm, [0.05, 0.05], "crab_shell", sides=5)
        ellipsoid(b, (side * 0.46, 0.66, 0.34), (0.16, 0.2, 0.1), "crab_claw", seg=8, rings=5)
        tube(b, [Vector((side * 0.08, 0.26, 0.38)), Vector((side * 0.1, 0.3, 0.52))], [0.02, 0.02], "crab_shell", sides=4)
        ellipsoid(b, (side * 0.1, 0.3, 0.56), (0.05, 0.05, 0.05), "eye_black", seg=6, rings=4)
    return b.build()


def gull():
    b = Builder("gull")
    ellipsoid(b, (0, 0, 0), (0.18, 0.55, 0.18), "bird_body", seg=10, rings=6)
    ellipsoid(b, (0, 0.5, 0.1), (0.13, 0.15, 0.13), "bird_body", seg=8, rings=5)
    tube(b, [Vector((0, 0.62, 0.08)), Vector((0, 0.82, 0.04))], [0.04, 0.005], "beak", sides=4)
    tube(b, [Vector((0, -0.4, 0.02)), Vector((0, -0.75, 0.04))], [0.12, 0.02], "bird_body", sides=4)
    # Flügel: eine Karte, UV untere Atlas-Hälfte (Godot-Shader schlägt nach |x|).
    span = 1.9
    for side in (-1, 1):
        p = [Vector((side * 0.1, 0.25, 0.08)), Vector((side * span, 0.05, 0.08)), Vector((side * span, -0.25, 0.08)), Vector((side * 0.1, -0.2, 0.08))]
        u_in, u_out = (0.5, 0.0) if side < 0 else (0.5, 1.0)
        uvs = ((u_in, 0.48), (u_out, 0.45), (u_out, 0.33), (u_in, 0.38))
        idx = [b.v(x) for x in p]
        if side < 0:
            idx = idx[::-1]
            uvs = uvs[::-1]
        b.face(idx, uvs, "bird_wing", [(0, 0, 1)] * 4)
    return b.build()


def butterfly():
    b = Builder("butterfly")
    tube(b, [Vector((0, -0.12, 0)), Vector((0, 0.14, 0))], [0.025, 0.02], "eye_black", sides=4)
    for side in (-1, 1):
        p = [Vector((0, 0.2, 0)), Vector((side * 0.32, 0.2, 0)), Vector((side * 0.32, -0.2, 0)), Vector((0, -0.2, 0))]
        u_mid = 0.125
        u_out = 0.0 if side < 0 else 0.25
        uvs = ((u_mid, 1.0), (u_out, 1.0), (u_out, 0.75), (u_mid, 0.75))
        idx = [b.v(x) for x in p]
        if side < 0:
            idx, uvs = idx[::-1], uvs[::-1]
        b.face(idx, uvs, "butterfly_wing", [(0, 0, 1)] * 4)
    return b.build()


# ------------------------------------------------------------------ Bühne, Atelier, Spielewelt

def speaker_tower():
    b = Builder("speaker_tower")
    for k in range(4):
        z = k * 1.05
        w = 1.6 - k * 0.08
        bevel_box(b, w, 1.0, 1.0, (0, 0, z + 0.5), "speaker_box", bevel=0.04, uv_scale=1.0)
        for x in ((-0.38, 0.38) if k < 3 else (0.0,)):
            lathe_rings = lathe(b, [(0.36, 0.0), (0.3, 0.04), (0.12, 0.12), (0.0, 0.14)], "speaker_cone", sides=16)
            rot = Matrix.Rotation(-math.pi / 2, 3, "X")
            for ring in lathe_rings:
                for vi, _ in ring:
                    b.verts[vi] = rot @ b.verts[vi] + Vector((x * w / 1.6, -0.51, z + 0.5))
        bevel_box(b, w * 0.92, 0.02, 0.06, (0, -0.51, z + 0.94), "metal_dark", bevel=0.0)
    return b.build()


def truss(length=18.0):
    b = Builder("truss_beam")
    r = 0.04
    s = 0.35
    for dy in (-s, s):
        for dz in (-s, s):
            tube(b, [Vector((-length / 2, dy, dz)), Vector((length / 2, dy, dz))], [r, r], "truss_metal", sides=5, v_scale=0.2)
    n = int(length / 0.7)
    for k in range(n):
        x0 = -length / 2 + k * 0.7
        for dy, dz, ey, ez in ((-s, -s, -s, s), (s, -s, s, s), (-s, s, s, s), (-s, -s, s, -s)):
            tube(b, [Vector((x0, dy, dz)), Vector((x0 + 0.7, ey, ez))], [r * 0.6, r * 0.6], "truss_metal", sides=4)
    return b.build()


def moving_head():
    b = Builder("moving_head")
    bevel_box(b, 0.7, 0.5, 0.25, (0, 0, 0.12), "metal_dark", bevel=0.03)
    for side in (-1, 1):
        bevel_box(b, 0.08, 0.3, 0.6, (side * 0.33, 0, -0.25), "metal_dark", bevel=0.02)
    lathe(b, [(0.0, -0.75), (0.24, -0.75), (0.3, -0.45), (0.28, -0.2), (0.0, -0.2)], "metal_dark", sides=16)
    lathe(b, [(0.0, -0.76), (0.22, -0.76), (0.0, -0.765)], "lamp_glass", sides=16)
    return b.build()


def atelier_lamp():
    b = Builder("atelier_lamp")
    lathe(b, [(0.0, 0.0), (0.32, 0.0), (0.3, 0.06), (0.0, 0.07)], "brass", sides=20)
    tube(b, [Vector((0, 0, 0.05)), Vector((0.1, 0, 1.0)), Vector((0.7, 0, 1.5))], [0.03, 0.03, 0.03], "brass", sides=6)
    rings = lathe(b, [(0.06, 0.0), (0.14, -0.06), (0.32, -0.28), (0.34, -0.3)], "lamp_shade", sides=20)
    rot = Matrix.Rotation(0.5, 3, "Y")
    for ring in rings:
        for vi, _ in ring:
            b.verts[vi] = rot @ b.verts[vi] + Vector((0.72, 0, 1.52))
    lathe(b, [(0.0, -0.05), (0.09, -0.12), (0.0, -0.2)], "lamp_glass", sides=10, at=(0.82, 0, 1.4))
    return b.build()


def easel():
    b = Builder("easel")
    for side in (-1, 1):
        tube(b, [Vector((side * 0.55, 0.2, 0)), Vector((side * 0.12, 0, 2.3))], [0.04, 0.035], "wood", sides=5)
    tube(b, [Vector((0, -0.7, 0)), Vector((0, 0.02, 2.0))], [0.035, 0.03], "wood", sides=5)
    bevel_box(b, 1.3, 0.12, 0.06, (0, 0.12, 0.9), "wood", bevel=0.01)
    bevel_box(b, 1.0, 0.04, 0.75, (0, 0.18, 1.35), "paper", bevel=0.01, uv_scale=1.0)
    return b.build()


def paint_jars():
    b = Builder("paint_jars")
    for k, m in enumerate(("paint_red", "paint_blue", "paint_yellow", "paint_green")):
        at = (k * 0.22 - 0.33, (k % 2) * 0.12, 0)
        lathe(b, [(0.0, 0.0), (0.08, 0.0), (0.085, 0.16), (0.07, 0.18)], "lamp_glass", sides=12, at=at)
        lathe(b, [(0.0, 0.12), (0.075, 0.12), (0.0, 0.121)], m, sides=12, at=at)
    for k in range(3):
        tube(b, [Vector((0.5, -0.1 + k * 0.06, 0.02)), Vector((0.5 + 0.08 * k, -0.1 + k * 0.06, 0.45))], [0.012, 0.008], "wood", sides=4)
    return b.build()


def portal_gate(name, style):
    """Spielewelt: Tor mit eigenem Charakter je Spiel."""
    b = Builder(name)
    if style == "stone":
        for side in (-1, 1):
            for row in range(6):
                bevel_box(b, 0.9, 0.9, 0.62, (side * 2.0, 0, row * 0.64 + 0.31), "stone_block", bevel=0.06, uv_scale=0.5, chip=0.03, seed=row * 3 + side)
        for k in range(11):
            a = math.pi - k / 10 * math.pi
            bevel_box(b, 0.6, 0.9, 0.55, (math.cos(a) * 2.0, 0, 3.85 + math.sin(a) * 1.8), "stone_block", tilt=(0, -(a - math.pi / 2)), bevel=0.05, uv_scale=0.5)
    elif style == "wood":
        for side in (-1, 1):
            tube(b, [Vector((side * 2.0, 0, 0)), Vector((side * 1.9, 0, 4.6))], [0.24, 0.2], "bark", sides=8, cap=True)
        tube(b, [Vector((-2.6, 0, 4.4)), Vector((2.6, 0, 4.7))], [0.18, 0.18], "bark", sides=8, cap=True)
        bevel_box(b, 3.0, 0.12, 0.9, (0, -0.25, 3.7), "wood", bevel=0.03, uv_scale=0.8)
    else:
        for side in (-1, 1):
            lathe(b, [(0.35, 0), (0.3, 0.3), (0.25, 4.0), (0.35, 4.3)], "metal_dark", sides=12, at=(side * 2.0, 0, 0))
        rings = lathe(b, [(2.3, -0.12), (2.3, 0.12)], "lamp_glass", sides=28)
        rot = Matrix.Rotation(math.pi / 2, 3, "X")
        for ring in rings:
            for vi, _ in ring:
                b.verts[vi] = rot @ b.verts[vi] + Vector((0, 0, 2.6))
    return b.build()


# ------------------------------------------------------------------ Export

def export(objects, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = OUT / filename
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_normals=True, export_tangents=False,
                              export_materials="EXPORT", export_image_format="NONE",
                              export_cameras=False, export_lights=False, export_animations=False)
    info = {}
    for o in objects:
        me = o.data
        me.calc_loop_triangles()
        info[o.name] = {"triangles": len(me.loop_triangles), "materials": [m.name for m in me.materials],
                        "size": [round(v, 3) for v in o.dimensions]}
    return {"file": filename, "bytes": path.stat().st_size, "objects": info}


SETS = {
    "flora": lambda: [
        broadleaf_tree("tree_oak_a", 1, 10.0), broadleaf_tree("tree_oak_b", 2, 12.0, spread=1.15),
        broadleaf_tree("tree_oak_c", 3, 8.5, leaf_mat="leaves_autumn", spread=0.9, clusters=12),
        palm("palm_a", 4, 9.5), palm("palm_b", 5, 11.0, fronds=12),
        bush("bush_a", 6, 1.7), bush("bush_b", 7, 1.3, leaf_mat="leaves_autumn", count=26),
        fern("fern", 8), grass_tuft("grass_tuft"), grass_tuft("grass_flowers", flowers=True),
    ],
    "ruins": lambda: [
        rock("rock_a", 1, (1.6, 1.2, 0.9)), rock("rock_b", 2, (1.0, 1.1, 1.3)), rock("rock_c", 3, (2.4, 1.6, 1.1)),
        rock("boulder_cliff", 4, (5.0, 3.6, 3.2), subdiv=4),
        *ruins_set(), cave_arch(), castle(),
        stone_arch("arch_welcome", 2.55, 3.45, 0.86, True, 3.45), stone_arch("arch_gate", 3.3, 4.38, 0.98, False, 0.0, 17), shells(),
    ],
    "props": lambda: [lighthouse(), campfire(), tent(), crate(), barrel(), signpost()],
    "fauna": lambda: [crab(), gull(), butterfly()],
    "stage": lambda: [speaker_tower(), truss(), moving_head()],
    "atelier": lambda: [atelier_lamp(), easel(), paint_jars()],
    "hub": lambda: [portal_gate("gate_stone", "stone"), portal_gate("gate_wood", "wood"), portal_gate("gate_ring", "ring")],
}

COLORS = {
    "bark": (0.35, 0.27, 0.2), "leaves_broad": (0.3, 0.5, 0.2), "leaves_autumn": (0.6, 0.45, 0.2), "palm_bark": (0.5, 0.4, 0.3),
    "palm_frond": (0.3, 0.5, 0.2), "coconut": (0.3, 0.2, 0.12), "fern_frond": (0.25, 0.45, 0.2), "grass_tuft": (0.3, 0.5, 0.2),
    "rock_moss": (0.5, 0.5, 0.48), "rock": (0.5, 0.5, 0.48), "ruin_moss": (0.6, 0.55, 0.48), "cave_dark": (0.05, 0.04, 0.04),
    "stone_block": (0.6, 0.55, 0.5), "lighthouse_red": (0.7, 0.15, 0.12), "lighthouse_white": (0.92, 0.9, 0.86),
    "metal_dark": (0.12, 0.12, 0.14), "lamp_glass": (1.0, 0.9, 0.6), "wood": (0.5, 0.35, 0.2), "wood_dark": (0.3, 0.2, 0.12),
    "window_dark": (0.08, 0.1, 0.14), "embers": (1.0, 0.4, 0.1), "flame": (1.0, 0.6, 0.2), "fabric": (0.7, 0.55, 0.35),
    "crab_shell": (0.85, 0.3, 0.15), "crab_claw": (0.9, 0.38, 0.2), "eye_black": (0.02, 0.02, 0.02), "bird_body": (0.95, 0.95, 0.95),
    "beak": (0.95, 0.75, 0.2), "bird_wing": (0.9, 0.9, 0.9), "butterfly_wing": (1.0, 0.6, 0.2), "speaker_box": (0.08, 0.08, 0.1),
    "speaker_cone": (0.1, 0.1, 0.12), "truss_metal": (0.7, 0.72, 0.75), "brass": (0.8, 0.6, 0.3), "lamp_shade": (0.2, 0.35, 0.3),
    "paper": (0.95, 0.92, 0.85), "paint_red": (0.85, 0.2, 0.2), "paint_blue": (0.2, 0.4, 0.9), "paint_yellow": (0.95, 0.8, 0.2),
    "paint_green": (0.3, 0.75, 0.35), "roof_tiles": (0.2, 0.35, 0.65), "shell": (0.95, 0.88, 0.8), "window_glow": (1.0, 0.85, 0.5),
}
DOUBLE = {"leaves_broad", "leaves_autumn", "palm_frond", "fern_frond", "grass_tuft", "flame", "bird_wing", "butterfly_wing", "fabric"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "models.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"sets": {}}
    wanted = [s for s in args.only.split(",") if s] or list(SETS)
    for key in wanted:
        reset()
        _MATS.clear()
        random.seed(7)
        for name, color in COLORS.items():
            mat(name, color, name in DOUBLE)
        objects = SETS[key]()
        manifest["sets"][key] = export(objects, f"adventure_{key}.glb")
        print(key, manifest["sets"][key]["bytes"], {k: v["triangles"] for k, v in manifest["sets"][key]["objects"].items()})
    manifest["generator"] = "tools/lumo_adventure_art/build_models.py"
    manifest["license"] = "Eigenbau in Blender per Skript, keine fremde Geometrie"
    manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
