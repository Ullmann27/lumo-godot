#!/usr/bin/env python3
"""Dorfwelt: vier Soldaten als glaubwürdige Menschen (Nachtrag von Heinz, 18.11.2026).

Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/build_soldier_models.py [--only soldier_schild]

Eigenbau, alles aus Code: Körper und Pferd entstehen als Skelettlinie mit
Skin- und Subdivision-Modifier (menschliche Proportionen, ca. 7 Kopfhöhen),
der Kopf ist eine verformte Kugel mit Nase, Augenhöhlen, Kinn und Ohren.
Helm, Schild, Waffen und Rüstungsteile sind eigene Teile mit Bevel. Alle
Flächen benutzen den Dorf-Atlas (ein Material, Metall/Leder/Stoff/Haut über
Kachel und Tönung) wie build_village_models.py.

Bewegung ohne Skelett, handytauglich in MultiMesh-Gruppen: jede Fläche trägt
in COLOR.a die Nummer ihres Körperteils (Kopf, Arme, Beine, Pferdebeine ...),
village_soldier.gdshader dreht diese Teile um ihre Gelenke (stehen/atmen,
marschieren, Abwehr, jubeln, zurückweichen, Waffen senken). Die Gelenke
schreibt dieses Skript nach scripts/creative/build_village_soldier_rig.gd.
Flächen in Stadtfarbe sind in UV2 markiert, damit Gegner dieselben Menschen
in ihrer eigenen Farbe zeigen können. Kein Blut, keine Verletzungen.
Koordinaten in Godot-Konvention (Y oben, vorne = +Z), Mitte am Boden = Ursprung.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_village_models as V  # noqa: E402
import bpy  # noqa: E402,I001
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

WEIGHTED = False
RIG_PATH = V.ROOT / "scripts/creative/build_village_soldier_rig.gd"
# Körperteile (COLOR.a = (id + 0.5) / 16); 1.0 = starr.
HEAD, ARM_L, ARM_R, LEG_L, LEG_R, HORSE_A, HORSE_B, HORSE_HEAD, HORSE_TAIL = 1, 2, 3, 4, 5, 6, 7, 8, 9
TEAM = "36589c"      # Stadtfarbe (Lumo-Blau)
TEAM_DARK = "2a4478"
TRIM = "f0c64a"      # Gold-Borte, Stern
SKIN = ["e2b08c", "c98f6a", "f0c4a0", "a8714f"]
LEATHER = "6e4a2e"
LEATHER_DARK = "3e2a1c"
MAIL = "838b96"
STEEL = "a6aeb8"
WOOD = "9a6b40"
LINEN = "d9cfb8"


_VILLAGE_TINT = V.tint


def _soldier_tint(tile, hex_color, alpha):
    """Stoff und Metall der Soldaten werden auf die glatte Kachel gelegt: Farbe voll treffen."""
    return _VILLAGE_TINT("plain" if tile in ("metal", "cloth") else tile, hex_color, alpha)


V.tint = _soldier_tint


def part_alpha(part):
    return (part + 0.5) / 16.0


class Part:
    """Alle Flächen, die im Block entstehen, bekommen dieses Körperteil (falls noch starr)."""

    def __init__(self, b, part, team=False):
        self.b = b
        self.part = part
        self.team = team

    def __enter__(self):
        self.start = len(self.b.bm.faces)
        return self

    def __exit__(self, *exc):
        bm = self.b.bm
        bm.faces.ensure_lookup_table()
        for f in bm.faces[self.start:]:
            if self.team:
                f[self.b.team] = 1
            if self.part is None:
                continue
            for loop in f.loops:
                c = loop[self.b.col]
                if c[3] > 0.99:
                    loop[self.b.col] = (c[0], c[1], c[2], part_alpha(self.part))
        return False


def builder(name):
    b = V.Builder(name)
    b.team = b.bm.faces.layers.int.new("team")
    return b


def set_part_faces(b, faces, part):
    for f in faces:
        for loop in f.loops:
            c = loop[b.col]
            loop[b.col] = (c[0], c[1], c[2], part_alpha(part))


def add_object(b, obj, classify):
    """Bewertetes bpy-Objekt (mit Modifiern) in den Builder übernehmen.
    classify(centre_godot, normal_godot) -> (tile, colour, part|None, smooth, team)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    mw = obj.matrix_world
    src = bmesh.new()
    src.from_mesh(me)
    # Flächen einheitlich nach außen (Drehkörper und Kopf werden sonst innen gezeichnet).
    bmesh.ops.recalc_face_normals(src, faces=src.faces[:])
    src.verts.ensure_lookup_table()
    verts = [b.bm.verts.new(mw @ v.co) for v in src.verts]
    for poly in src.faces:
        vs = [verts[v.index] for v in poly.verts]
        try:
            f = b.bm.faces.new(vs)
        except ValueError:
            continue
        c = mw @ poly.calc_center_median()
        n = (mw.to_3x3() @ poly.normal).normalized()
        tile, colour, part, smooth, team = classify((c.x, c.z, -c.y), (n.x, n.z, -n.y))
        f[b.tile] = V.TILES.index(tile)
        f[b.fit] = 0
        f[b.smooth] = 1 if smooth else 0
        if hasattr(b, "team"):
            f[b.team] = 1 if team else 0
        col = V.tint(tile, colour, 1.0)
        if part is not None:
            col = (col[0], col[1], col[2], part_alpha(part))
        for loop in f.loops:
            loop[b.col] = col
    src.free()
    ev.to_mesh_clear()
    bpy.data.objects.remove(obj, do_unlink=True)


def skin_object(name, nodes, edges, radii, levels=1):
    """Skelettlinie (Godot-Punkte) -> Skin + Subdivision. radii[i] = (breit, tief)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([V.g2b(p) for p in nodes], edges, [])
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    layer = me.skin_vertices[0].data
    for i, r in enumerate(radii):
        layer[i].radius = (r[0], r[1])
        layer[i].use_root = i == 0
    if levels:
        sub = obj.modifiers.new("sub", "SUBSURF")
        sub.levels = levels
        sub.render_levels = levels
    return obj


def bevel_box(c, s, width=0.01, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=V.g2b(c))
    obj = bpy.context.active_object
    obj.scale = (s[0], s[2], s[1])
    obj.rotation_euler = (rot[0], -rot[2], rot[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = 2
    mod.limit_method = "NONE"
    return obj


def mesh_object(name, verts, faces, bevel=0.0, subdiv=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([V.g2b(p) for p in verts], [], faces)
    me.validate()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    if subdiv:
        sub = obj.modifiers.new("sub", "SUBSURF")
        sub.levels = subdiv
    return obj


def lathe(name, profile, segs=16, bevel=0.0, scale=(1.0, 1.0)):
    """Drehkörper um Y aus (radius, y)-Profil, offen oder mit Polen bei r=0."""
    verts = []
    faces = []
    rings = len(profile)
    for (r, y) in profile:
        for i in range(segs):
            a = i / segs * math.tau
            verts.append((math.sin(a) * r * scale[0], y, math.cos(a) * r * scale[1]))
    for k in range(rings - 1):
        for i in range(segs):
            j = (i + 1) % segs
            faces.append((k * segs + i, (k + 1) * segs + i, (k + 1) * segs + j, k * segs + j))
    return mesh_object(name, verts, faces, bevel=bevel)


def place(obj, at=(0, 0, 0), rot_x=0.0, rot_y=0.0, rot_z=0.0):
    """Godot-Rotation (Y, X, Z) um den Ursprung, dann verschieben."""
    obj.rotation_mode = "YXZ"
    # Godot X = Blender X, Godot Y = Blender Z, Godot Z = -Blender Y.
    obj.rotation_euler = (rot_x, -rot_z, rot_y)
    obj.location = V.g2b(at)
    bpy.context.view_layer.update()
    return obj


def solid(tile, colour, part=None, smooth=True, team=False):
    return lambda c, n: (tile, colour, part, smooth, team)


# ------------------------------------------------------------------ Mensch

class Pose:
    """Gelenkpunkte eines stehenden oder reitenden Menschen (Godot-Koordinaten)."""

    def __init__(self, y0=0.0, seated=False, arm_l=None, arm_r=None):
        self.y0 = y0
        up = lambda p: (p[0], p[1] + y0, p[2])  # noqa: E731
        self.pelvis = up((0, 0.98, 0))
        self.waist = up((0, 1.12, 0.005))
        self.chest = up((0, 1.30, 0.01))
        self.shoulder_line = up((0, 1.42, 0))
        self.neck = up((0, 1.52, 0.005))
        self.head = up((0, 1.635, 0.02))
        if seated:
            self.leg = {
                s: [up((s * 0.1, 0.94, 0.0)), up((s * 0.26, 0.86, 0.36)), up((s * 0.3, 0.42, 0.26)),
                    up((s * 0.3, 0.33, 0.27)), up((s * 0.3, 0.31, 0.41))] for s in (-1, 1)}
        else:
            self.leg = {
                s: [up((s * 0.095, 0.93, 0.0)), up((s * 0.1, 0.5, 0.025)), up((s * 0.105, 0.1, -0.01)),
                    up((s * 0.105, 0.04, 0.03)), up((s * 0.11, 0.03, 0.15))] for s in (-1, 1)}
        hang = lambda s: [up((s * 0.2, 1.42, -0.01)), up((s * 0.255, 1.13, -0.03)), up((s * 0.27, 0.88, 0.02)),  # noqa: E731
                          up((s * 0.275, 0.79, 0.04))]
        self.arm = {-1: [up(p) for p in arm_l] if arm_l else hang(-1), 1: [up(p) for p in arm_r] if arm_r else hang(1)}

    def hand(self, s):
        return Vector(self.arm[s][3])


def human_body(b, pose, skin, trousers="5b5246", boots=LEATHER, sleeves=TEAM, forearm=LEATHER, gloves=None):
    """Körper aus einer Skelettlinie: Hüfte, Rumpf, Hals, Arme, Beine, Füße."""
    nodes = [pose.pelvis, pose.waist, pose.chest, pose.shoulder_line, pose.neck]
    radii = [(0.17, 0.115), (0.15, 0.105), (0.185, 0.12), (0.19, 0.105), (0.058, 0.058)]
    edges = [(0, 1), (1, 2), (2, 3), (3, 4)]
    labels = {}

    def chain(points, rads, attach, label):
        first = len(nodes)
        for i, (p, r) in enumerate(zip(points, rads)):
            nodes.append(p)
            radii.append(r)
            edges.append((attach if i == 0 else len(nodes) - 2, len(nodes) - 1))
            labels[len(nodes) - 1] = f"{label}{i}"
        return first

    for s in (-1, 1):
        chain(pose.arm[s], [(0.07, 0.068), (0.054, 0.054), (0.04, 0.034), (0.044, 0.026)], 3, f"arm{s}_")
        chain(pose.leg[s], [(0.098, 0.098), (0.068, 0.07), (0.05, 0.052), (0.052, 0.056), (0.044, 0.034)], 0, f"leg{s}_")
    obj = skin_object("body", nodes, edges, radii, levels=1)
    segs = []
    for (a, c) in edges:
        label = labels.get(c, "torso")
        segs.append((Vector(nodes[a]), Vector(nodes[c]), label))

    def classify(centre, normal):
        p = Vector(centre)
        best = None
        for (a, c, label) in segs:
            ab = c - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-6)))
            d = (a + ab * t - p).length
            if best is None or d < best[0]:
                best = (d, label, t)
        _, label, t = best
        if label == "torso":
            if p.y > pose.neck[1] - 0.03:
                return ("plain", skin, HEAD, True, False)
            return ("cloth", TEAM_DARK, None, True, True)
        side = -1 if "-1" in label else 1
        idx = int(label[-1])
        if label.startswith("arm"):
            part = ARM_L if side < 0 else ARM_R
            if idx == 0:
                return ("cloth", sleeves, part, True, sleeves == TEAM)
            if idx == 1:
                return ("plain", forearm, part, True, False)
            return ("plain", gloves or skin, part, True, False)
        part = LEG_L if side < 0 else LEG_R
        if pose.y0 > 0.0:
            part = None
        if idx <= 1:
            return ("cloth", trousers, part, True, False)
        if idx == 2 and t < 0.25:
            return ("cloth", trousers, part, True, False)
        return ("plain", boots, part, True, False)

    add_object(b, obj, classify)


def human_head(b, pose, skin, hair="5a3a22", beard=None, seed=0):
    """Kopf ~0,24 m: Schädel, Kiefer, Nase, Augenhöhlen, Brauen, Ohren, Augen."""
    hx, hy, hz = pose.head
    verts = []
    faces = []
    segs, rings = 18, 14
    for k in range(rings + 1):
        v = k / rings
        phi = v * math.pi
        for i in range(segs):
            a = i / segs * math.tau
            x = math.sin(phi) * math.sin(a)
            y = math.cos(phi)
            z = math.sin(phi) * math.cos(a)
            rx, ry, rz = 0.088, 0.118, 0.104
            # Kiefer schmaler, Hinterkopf voller, Kinn vorn.
            if y < -0.1:
                rx *= 1.0 - 0.28 * min(1.0, (-y - 0.1) / 0.9)
                rz *= 1.0 - 0.12 * min(1.0, (-y - 0.1) / 0.9)
            if z < -0.2 and y > -0.3:
                rz *= 1.06
            px, py, pz = x * rx, y * ry, z * rz
            front = max(0.0, z)
            # Nase: Grat entlang der Mitte zwischen Augen und Mund.
            if front > 0.8 and abs(x) < 0.3 and -0.45 < y < 0.15:
                ridge = (1.0 - abs(x) / 0.3) * (1.0 - abs((y + 0.15) / 0.3)) ** 0.7
                pz += 0.036 * max(0.0, ridge) ** 1.5 * (1.25 if y < -0.25 else 1.0)
            # Augenhöhlen und Brauenbogen.
            for s in (-1, 1):
                dx, dy = x - s * 0.36, y - 0.08
                d = math.hypot(dx * 1.1, dy * 1.6)
                if front > 0.5 and d < 0.28:
                    pz -= 0.012 * (1.0 - d / 0.28)
                if front > 0.5 and abs(dx) < 0.32 and 0.18 < y < 0.34:
                    pz += 0.006
            # Kinn und Wangen.
            if front > 0.75 and y < -0.72 and abs(x) < 0.4:
                pz += 0.008
            verts.append((hx + px, hy + py, hz + pz))
    for k in range(rings):
        for i in range(segs):
            j = (i + 1) % segs
            faces.append((k * segs + i, k * segs + j, (k + 1) * segs + j, (k + 1) * segs + i))
    head = mesh_object("head", verts, faces)
    bm = bmesh.new()
    bm.from_mesh(head.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(head.data)
    bm.free()

    def classify(c, n):
        y = c[1] - hy
        z = c[2] - hz
        x = c[0] - hx
        if hair and y > 0.055 and z < 0.07:
            return ("cloth", hair, HEAD, True, False)
        if hair and z < -0.06 and y > -0.05:
            return ("cloth", hair, HEAD, True, False)
        if beard and y < -0.045 and z > -0.02 and abs(x) < 0.085:
            if not (-0.065 < y < -0.035 and z > 0.08 and abs(x) < 0.03):
                return ("cloth", beard, HEAD, True, False)
        return ("plain", skin, HEAD, True, False)

    add_object(b, head, classify)
    with Part(b, HEAD):
        for s in (-1, 1):
            # Ohren, Augen (Weiß + Iris), Brauen, Lippen.
            b.blob((hx + s * 0.088, hy - 0.005, hz - 0.005), (0.014, 0.03, 0.022), "plain", skin, subdiv=1,
                   seed=seed + 3, jitter=0.0)
            b.blob((hx + s * 0.033, hy + 0.012, hz + 0.088), (0.014, 0.008, 0.008), "plain", "f2eee6", subdiv=1,
                   seed=seed + 4, jitter=0.0)
            b.blob((hx + s * 0.033, hy + 0.012, hz + 0.095), (0.0065, 0.0065, 0.004), "plain", "3a4a5a", subdiv=1,
                   seed=seed + 5, jitter=0.0)
            b.push((hx + s * 0.034, hy + 0.033, hz + 0.093), rot_z=-s * 0.12)
            b.box((0, 0, 0), (0.034, 0.007, 0.012), "plain", hair or "4a3020")
            b.pop()
        b.box((hx, hy - 0.058, hz + 0.093), (0.032, 0.006, 0.01), "plain", "a5625a")


def surcoat(b, pose, length=0.42, colour=TEAM, flare=0.25, slit=True, star=True):
    """Waffenrock in Stadtfarbe: Brustteil, ausgestellter Rock mit Schlitzen, Gürtel, Stern."""
    y_top = pose.shoulder_line[1] - 0.02
    y_waist = pose.waist[1] - 0.03
    y_hem = y_waist - length
    profile = [(0.17, y_top), (0.185, pose.chest[1]), (0.155, pose.waist[1] + 0.02), (0.17, y_waist - 0.04),
               (0.2, y_waist - length * 0.45), (flare, y_hem)]
    verts = []
    faces = []
    segs = 20
    for (r, y) in profile:
        for i in range(segs):
            a = i / segs * math.tau
            depth = 0.74 if y > y_waist else 0.86
            verts.append((math.sin(a) * r, y, math.cos(a) * r * depth + 0.008))
    rings = len(profile)
    for k in range(rings - 1):
        for i in range(segs):
            j = (i + 1) % segs
            # Schlitze vorne und hinten im Rock.
            if slit and k >= rings - 3 and i in (0, segs // 2):
                continue
            faces.append((k * segs + i, (k + 1) * segs + i, (k + 1) * segs + j, k * segs + j))
    obj = mesh_object("surcoat", verts, faces)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.012
    sol.offset = 1.0

    def classify(c, n):
        if c[1] < y_hem + 0.035:
            return ("cloth", TRIM, None, True, False)
        return ("cloth", colour, None, True, True)

    add_object(b, obj, classify)
    # Gürtel mit Schnalle, Schulterkragen.
    belt = lathe("belt", [(0.168, y_waist - 0.025), (0.168, y_waist + 0.025)], segs=20)
    belt.scale = (1.0, 0.8, 1.0)
    add_object(b, belt, solid("plain", LEATHER_DARK))
    b.box((0, y_waist, 0.145), (0.05, 0.045, 0.015), "metal", "d8b65a")
    if star:
        star_panel(b, (0, pose.chest[1] + 0.02, 0.148), 0.06)


def star_panel(b, c, r, colour=TRIM, rot_y=0.0, depth=0.008):
    """Fünfzackiger Stern (Lumo-Zeichen) als flaches Prisma, Vorderseite +Z."""
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    b.push(c, rot_y)
    front = [(x, y, depth) for (x, y) in pts]
    for i in range(10):
        j = (i + 1) % 10
        b.face([(0, 0, depth), front[i], front[j]], "plain", colour)
        b.face([front[j], front[i], (pts[i][0], pts[i][1], 0), (pts[j][0], pts[j][1], 0)], "plain", colour)
    b.pop()


def mail_coif(b, pose):
    """Kettenhaube über Hals und Schultern (Metallkachel)."""
    y = pose.neck[1]
    obj = lathe("coif", [(0.175, y - 0.1), (0.125, y - 0.05), (0.092, y + 0.0), (0.088, y + 0.035)], segs=18)
    add_object(b, obj, solid("metal", MAIL, HEAD))


def nasal_helmet(b, pose):
    """Spangenhelm mit Nasenschutz und Nackenschirm."""
    hx, hy, hz = pose.head
    prof = [(0.0, hy + 0.165), (0.04, hy + 0.158), (0.075, hy + 0.13), (0.1, hy + 0.08), (0.111, hy + 0.035),
            (0.114, hy + 0.012)]
    obj = lathe("helm", prof, segs=20, bevel=0.0, scale=(1.0, 1.08))
    place(obj, (hx, 0, hz + 0.0))
    add_object(b, obj, solid("metal", STEEL, HEAD))
    rim = lathe("rim", [(0.116, hy + 0.012), (0.118, hy + 0.034)], segs=20, scale=(1.0, 1.08))
    place(rim, (hx, 0, hz))
    add_object(b, rim, solid("metal", "8d939c", HEAD))
    with Part(b, HEAD):
        b.box((hx, hy - 0.005, hz + 0.118), (0.018, 0.075, 0.012), "metal", STEEL)


def kettle_hat(b, pose):
    """Eisenhut mit breiter Krempe."""
    hx, hy, hz = pose.head
    prof = [(0.0, hy + 0.17), (0.05, hy + 0.162), (0.09, hy + 0.125), (0.112, hy + 0.06), (0.118, hy + 0.035),
            (0.2, hy + 0.0), (0.205, hy - 0.01)]
    obj = lathe("kettle", prof, segs=22)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.006
    place(obj, (hx, 0, hz - 0.005))
    add_object(b, obj, solid("metal", "979fa9", HEAD))
    with Part(b, HEAD):
        b.box((hx, hy + 0.17, hz - 0.005), (0.012, 0.02, 0.2), "metal", "8d939c")
        b.box((hx, hy - 0.085, hz + 0.02), (0.012, 0.012, 0.17), "plain", LEATHER_DARK)


def archer_hood(b, pose, colour="3f6a3a"):
    """Gugel (Kapuze mit Schulterkragen und Zipfel)."""
    hx, hy, hz = pose.head
    obj = lathe("hood", [(0.0, hy + 0.15), (0.07, hy + 0.135), (0.112, hy + 0.07), (0.122, hy + 0.0),
                         (0.118, hy - 0.06), (0.14, hy - 0.11), (0.23, hy - 0.17), (0.25, hy - 0.21)], segs=20,
                 scale=(1.0, 1.1))
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.01
    place(obj, (hx, 0, hz - 0.012))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Gesicht frei: vordere Flächen im Kopfbereich entfernen.
    kill = [f for f in bm.faces if f.calc_center_median().y < -0.05 and -0.085 < f.calc_center_median().z - hy < 0.085
            and abs(f.calc_center_median().x) < 0.08]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    add_object(b, obj, solid("cloth", colour, HEAD))
    with Part(b, HEAD):
        b.push((hx, hy + 0.08, hz - 0.13), rot_x=-1.0)
        b.cone((0, 0, 0), 0.04, 0.2, 8, "cloth", colour)
        b.pop()


def plume_helmet(b, pose):
    """Reiterhelm: runde Glocke, Wangenklappen, Helmbusch in Stadtfarbe."""
    hx, hy, hz = pose.head
    obj = lathe("rhelm", [(0.0, hy + 0.17), (0.06, hy + 0.158), (0.1, hy + 0.11), (0.116, hy + 0.04),
                          (0.118, hy - 0.02)], segs=20, scale=(1.0, 1.06))
    place(obj, (hx, 0, hz - 0.006))
    add_object(b, obj, solid("metal", STEEL, HEAD))
    with Part(b, HEAD):
        for s in (-1, 1):
            b.push((hx + s * 0.105, hy - 0.04, hz + 0.03), rot_y=s * 0.25)
            b.box((0, 0, 0), (0.012, 0.09, 0.08), "metal", "aab1bb")
            b.pop()
    with Part(b, HEAD, team=True):
        for i in range(7):
            t = i / 6
            b.blob((hx, hy + 0.18 + math.sin(t * math.pi) * 0.05, hz + 0.08 - t * 0.26), (0.025, 0.035, 0.04),
                   "cloth", TEAM, subdiv=1, seed=40 + i, jitter=0.05)


# ------------------------------------------------------------------ Ausrüstung

def kite_shield(b, at, rot_y=0.0, rot_x=0.0, size=1.0):
    """Normannischer Langschild: gewölbt, Stadtfarbe, Goldstern, Metallrand und Buckel."""
    w, h = 0.25 * size, 0.46 * size
    outline = []
    for i in range(14):
        t = i / 13
        a = math.pi * t
        outline.append((math.cos(a) * w, h * 0.55 + math.sin(a) * w * 0.55))
    outline.append((-w * 0.86, h * 0.1))
    outline.append((-w * 0.55, -h * 0.45))
    outline.append((0.0, -h))
    outline.append((w * 0.55, -h * 0.45))
    outline.append((w * 0.86, h * 0.1))
    pts = [(x, y, 0.04 * (1.0 - (x / w) ** 2)) for (x, y) in outline]
    centre = (0.0, h * 0.12, 0.045)
    verts = [centre] + pts
    faces = [(0, 1 + i, 1 + (i + 1) % len(pts)) for i in range(len(pts))]
    obj = mesh_object("shield", verts, faces)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.022
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = 0.006
    bev.segments = 2
    bev.limit_method = "ANGLE"
    place(obj, at, rot_x=rot_x, rot_y=rot_y)
    add_object(b, obj, lambda c, n: ("cloth", TEAM, None, False, True))
    b.push(at, rot_y=rot_y, rot_x=rot_x)
    # Rand aus Metall, Buckel, Stern.
    for i in range(len(outline)):
        p0 = outline[i]
        p1 = outline[(i + 1) % len(outline)]
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        ln = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
        b.push((mx, my, 0.04 * (1.0 - (mx / w) ** 2) + 0.012), rot_z=ang)
        b.box((0, 0, 0), (ln + 0.01, 0.018, 0.02), "metal", "a8afb8")
        b.pop()
    b.blob((0, h * 0.12, 0.07), (0.045, 0.045, 0.03), "metal", "d8b65a", subdiv=2, seed=7, jitter=0.0, smooth=True)
    star_panel(b, (0, h * 0.12, 0.05), 0.15 * size, depth=0.012)
    b.pop()


def round_shield(b, at, rot_y=0.0, rot_x=0.0, r=0.27):
    obj = lathe("rshield", [(0.0, 0.035), (r * 0.5, 0.028), (r, 0.0), (r, -0.02), (0.0, -0.01)], segs=24)
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = 0.005
    bev.segments = 2
    bev.limit_method = "ANGLE"
    obj.rotation_mode = "XYZ"
    # Scheibe zeigt nach +Z (Godot): um Godot-X drehen.
    place(obj, at, rot_x=rot_x + math.pi / 2, rot_y=rot_y)

    def classify(c, n):
        return ("plain", TEAM, None, False, True)

    add_object(b, obj, classify)
    b.push(at, rot_y=rot_y, rot_x=rot_x)
    b.cylinder((0, 0, 0.0), r + 0.012, 0.03, 24, "metal", "8d939c", axis="z", caps=False)
    b.blob((0, 0, 0.045), (0.06, 0.06, 0.035), "metal", "d8b65a", subdiv=2, seed=9, jitter=0.0, smooth=True)
    for k in range(4):
        b.push((0, 0, 0.03), rot_z=k * math.pi / 4)
        b.box((0, 0, 0), (r * 1.9, 0.03, 0.01), "plain", TRIM)
        b.pop()
    b.pop()


def sword(b, hand, rot_x=0.0, rot_z=0.0, length=0.78):
    """Einhandschwert: Klinge mit Grat (Bevel), Parierstange, Griff, Knauf. Spitze zeigt nach -Y lokal."""
    b.push(tuple(hand), rot_x=rot_x, rot_z=rot_z)
    blade = mesh_object("blade", [(-0.022, -0.06, 0.0), (0.022, -0.06, 0.0), (0.018, -length + 0.05, 0.0),
                                  (0.0, -length, 0.0), (-0.018, -length + 0.05, 0.0), (0.0, -0.06, 0.006),
                                  (0.0, -length + 0.05, 0.004), (0.0, -0.06, -0.006), (0.0, -length + 0.05, -0.004)],
                        [(0, 5, 6, 4), (5, 1, 2, 6), (4, 6, 3), (6, 2, 3), (1, 7, 8, 2), (7, 0, 4, 8), (8, 4, 3),
                         (2, 8, 3)])
    m = b.stack[-1]
    for v in blade.data.vertices:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        w = m @ g
        v.co = V.g2b(w)
    add_object(b, blade, solid("metal", "dfe5ec", None, False))
    b.box((0, -0.05, 0), (0.16, 0.022, 0.03), "metal", "c2a256")
    b.cylinder((0, 0.03, 0), 0.016, 0.13, 8, "plain", LEATHER_DARK)
    b.blob((0, 0.105, 0), (0.026, 0.026, 0.026), "metal", "c2a256", subdiv=1, seed=3, jitter=0.0, smooth=True)
    b.pop()


def scabbard(b, pose):
    hip = (-0.17, pose.waist[1] - 0.1 + 0.0, 0.05)
    b.push(hip, rot_x=0.35, rot_z=-0.12)
    b.box((0, -0.36, 0), (0.05, 0.72, 0.025), "plain", LEATHER_DARK)
    b.box((0, -0.71, 0), (0.055, 0.04, 0.03), "metal", "c2a256")
    b.box((0, 0.04, 0), (0.15, 0.02, 0.03), "metal", "c2a256")
    b.cylinder((0, 0.1, 0), 0.015, 0.12, 6, "plain", LEATHER_DARK)
    b.pop()


def spear(b, hand, length=2.65, butt=0.95):
    """Langer Speer, senkrecht in der Hand, blattförmige Spitze mit Grat, Wimpelband."""
    x, y, z = hand
    y0 = y - butt
    b.cylinder((x, y0 + length / 2, z), 0.017, length, 8, "beam", WOOD)
    blade = mesh_object("spear_tip", [(0, 0, 0), (0.035, 0.08, 0), (0, 0.28, 0), (-0.035, 0.08, 0), (0, 0.08, 0.012),
                                      (0, 0.08, -0.012)],
                        [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)])
    place(blade, (x, y0 + length, z))
    add_object(b, blade, solid("metal", "e1e6ec", None, False))
    b.cylinder((x, y0 + length - 0.01, z), 0.024, 0.06, 8, "metal", "8d939c")
    b.cylinder((x, y0 + 0.02, z), 0.02, 0.05, 8, "metal", "8d939c")


def longbow(b, hand, height=1.62, rot_y=0.0):
    """Langbogen (gebogener Stab, verjüngt) mit Sehne, Griffwicklung in der linken Hand."""
    hx, hy, hz = hand
    seg = 16
    pts = []
    for i in range(seg + 1):
        t = i / seg * 2 - 1
        pts.append((0.0, t * height / 2, 0.12 * (1 - t * t)))
    b.push((hx, hy, hz - 0.05), rot_y=rot_y)
    for i in range(seg):
        p0, p1 = pts[i], pts[i + 1]
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        ln = math.hypot(p1[1] - p0[1], p1[2] - p0[2])
        ang = math.atan2(p1[2] - p0[2], p1[1] - p0[1])
        t = abs((i + 0.5) / seg * 2 - 1)
        r = 0.02 * (1 - 0.55 * t)
        b.push(mid, rot_x=ang)
        b.cylinder((0, 0, 0), r, ln + 0.004, 6, "beam", "7a4a26")
        b.pop()
    b.cylinder((0, 0, -0.0), 0.003, height - 0.02, 3, "plain", "efe8d8")
    b.cylinder((0, 0, 0.12), 0.024, 0.12, 8, "plain", LEATHER_DARK)
    b.pop()


def quiver(b, pose):
    """Köcher schräg am Rücken mit Pfeilen (Federn in Weiß und Stadtfarbe)."""
    b.push((0.08, pose.chest[1] - 0.02, -0.15), rot_z=-0.35, rot_x=0.12)
    b.cylinder((0, 0, 0), 0.055, 0.52, 10, "plain", LEATHER, r_top=0.06)
    b.cylinder((0, 0.27, 0), 0.064, 0.03, 10, "plain", LEATHER_DARK)
    for i in range(6):
        a = i / 6 * math.tau
        x, z = math.cos(a) * 0.03, math.sin(a) * 0.03
        b.cylinder((x, 0.34, z), 0.005, 0.18, 4, "beam", "c8a27a")
        b.box((x, 0.4, z), (0.004, 0.07, 0.03), "cloth", "f0ece2" if i % 2 else TEAM)
    b.pop()


def gambeson(b, pose, colour=TEAM, length=0.36):
    """Gesteppter Waffenrock (Bogenschütze): kürzer, mit Steppnähten."""
    surcoat(b, pose, length=length, colour=colour, flare=0.22, slit=True, star=False)
    with Part(b, None):
        for i in range(5):
            y = pose.waist[1] + 0.02 + i * 0.065
            b.box((0, y, 0.135 - abs(i - 2) * 0.004), (0.26 - abs(i - 2) * 0.02, 0.006, 0.01), "cloth", TEAM_DARK)
    star_panel(b, (0.07, pose.chest[1] + 0.06, 0.142), 0.03)


# ------------------------------------------------------------------ Figuren

def model_soldier_schild(b):
    """Schildwache (1,78 m): Spangenhelm, Kettenhaube, Waffenrock, Langschild links, Schwert rechts."""
    arm_l = [(-0.2, 1.42, -0.01), (-0.27, 1.16, 0.04), (-0.2, 1.06, 0.26), (-0.17, 1.05, 0.31)]
    arm_r = [(0.2, 1.42, -0.01), (0.25, 1.14, -0.01), (0.27, 0.9, 0.08), (0.27, 0.83, 0.12)]
    pose = Pose(arm_l=arm_l, arm_r=arm_r)
    skin = SKIN[0]
    human_body(b, pose, skin, sleeves=MAIL, forearm=MAIL, gloves=LEATHER)
    human_head(b, pose, skin, hair="5a3a22", beard="5a3a22", seed=1100)
    mail_coif(b, pose)
    nasal_helmet(b, pose)
    surcoat(b, pose, length=0.44)
    scabbard(b, pose)
    with Part(b, ARM_L):
        kite_shield(b, (-0.2, 1.0, 0.36), rot_y=0.18, rot_x=-0.06, size=1.02)
    with Part(b, ARM_R):
        sword(b, pose.hand(1), rot_x=-0.5, rot_z=0.05, length=0.74)
    return pose


def model_soldier_bogen(b):
    """Bogenschütze (1,76 m): Gugel, gesteppter Rock, Langbogen links, Köcher am Rücken."""
    arm_l = [(-0.2, 1.42, -0.01), (-0.28, 1.17, 0.07), (-0.29, 1.02, 0.25), (-0.29, 1.0, 0.31)]
    pose = Pose(arm_l=arm_l)
    skin = SKIN[1]
    human_body(b, pose, skin, trousers="6b5a3e", sleeves=TEAM, forearm=LEATHER)
    human_head(b, pose, skin, hair="2e2420", beard=None, seed=1200)
    archer_hood(b, pose)
    gambeson(b, pose)
    quiver(b, pose)
    with Part(b, ARM_L):
        longbow(b, (-0.29, 1.0, 0.36), height=1.66)
    with Part(b, ARM_R):
        # Pfeil locker in der rechten Hand.
        hand = pose.hand(1)
        b.push(tuple(hand), rot_x=-0.25)
        b.cylinder((0, -0.05, 0.02), 0.005, 0.72, 4, "beam", "c8a27a")
        b.cone((0, 0.31, 0.02), 0.012, 0.05, 4, "metal", STEEL)
        b.pop()
    return pose


def model_soldier_speer(b):
    """Speerträger (1,80 m): Eisenhut, Waffenrock, langer Speer rechts, Rundschild links."""
    arm_r = [(0.2, 1.42, -0.01), (0.29, 1.18, 0.04), (0.29, 1.12, 0.22), (0.28, 1.12, 0.27)]
    pose = Pose(arm_r=arm_r)
    skin = SKIN[2]
    human_body(b, pose, skin, trousers="4f5560", sleeves=TEAM, forearm=LEATHER)
    human_head(b, pose, skin, hair="7a5030", beard="7a5030", seed=1300)
    kettle_hat(b, pose)
    surcoat(b, pose, length=0.4)
    with Part(b, ARM_R):
        spear(b, (0.28, 1.12, 0.28), length=2.7, butt=1.08)
    with Part(b, ARM_L):
        round_shield(b, (-0.33, 0.98, 0.07), rot_y=-1.35, r=0.28)
    return pose


def horse(b, colour="7a4a2c", mane="2a1d16"):
    """Pferd (Widerrist ~1,5 m) aus Skelettlinie: Rumpf, Hals, Kopf, vier Beine, Schweif."""
    spine = [(0, 1.3, -0.62), (0, 1.27, -0.12), (0, 1.3, 0.42), (0, 1.62, 0.72), (0, 1.9, 0.9), (0, 1.66, 1.18),
             (0, 1.52, 1.32)]
    rads = [(0.27, 0.28), (0.26, 0.29), (0.25, 0.31), (0.14, 0.2), (0.1, 0.13), (0.085, 0.11), (0.07, 0.08)]
    nodes = list(spine)
    radii = list(rads)
    edges = [(i, i + 1) for i in range(len(spine) - 1)]
    labels = {}
    legs = {
        "fl": ([(-0.16, 1.12, 0.48), (-0.16, 0.86, 0.5), (-0.16, 0.5, 0.52), (-0.16, 0.14, 0.5), (-0.16, 0.035, 0.54)], 2),
        "fr": ([(0.16, 1.12, 0.48), (0.16, 0.86, 0.5), (0.16, 0.5, 0.52), (0.16, 0.14, 0.5), (0.16, 0.035, 0.54)], 2),
        "hl": ([(-0.17, 1.16, -0.62), (-0.18, 0.86, -0.5), (-0.17, 0.5, -0.74), (-0.16, 0.14, -0.68),
                (-0.16, 0.035, -0.64)], 0),
        "hr": ([(0.17, 1.16, -0.62), (0.18, 0.86, -0.5), (0.17, 0.5, -0.74), (0.16, 0.14, -0.68),
                (0.16, 0.035, -0.64)], 0),
    }
    leg_r = [(0.1, 0.12), (0.075, 0.09), (0.042, 0.05), (0.04, 0.045), (0.055, 0.06)]
    for key, (pts, attach) in legs.items():
        for i, p in enumerate(pts):
            nodes.append(p)
            radii.append(leg_r[i])
            edges.append((attach if i == 0 else len(nodes) - 2, len(nodes) - 1))
            labels[len(nodes) - 1] = (key, i)
    obj = skin_object("horse", nodes, edges, radii, levels=1)

    def classify(c, n):
        x, y, z = c
        if z > 0.95 and y > 1.45:
            return ("plain", colour, HORSE_HEAD, True, False)
        if z > 0.62 and y > 1.42:
            return ("plain", colour, HORSE_HEAD, True, False)
        if y < 1.05:
            front = z > 0.0
            left = x < 0
            part = HORSE_A if (front == left) else HORSE_B
            if y < 0.07:
                return ("plain", "2a2420", part, True, False)
            if y < 0.2:
                return ("plain", "e8e0d0" if (front and not left) else colour, part, True, False)
            return ("plain", colour, part, True, False)
        return ("plain", colour, None, True, False)

    add_object(b, obj, classify)
    with Part(b, HORSE_HEAD):
        # Mähne, Ohren, Augen, Blesse, Zaumzeug.
        for i in range(9):
            t = i / 8
            p = (0, 1.66 + t * 0.32, 0.6 + t * 0.32)
            b.push(p, rot_x=-0.6)
            b.box((0, 0.03, -0.03), (0.04, 0.12, 0.09), "cloth", mane)
            b.pop()
        for s in (-1, 1):
            b.push((s * 0.055, 2.02, 0.93), rot_z=-s * 0.2, rot_x=0.2)
            b.cone((0, 0, 0), 0.035, 0.12, 6, "plain", colour)
            b.pop()
            b.blob((s * 0.085, 1.86, 1.06), (0.012, 0.018, 0.022), "plain", "141010", subdiv=1, seed=5, jitter=0.0)
            b.box((s * 0.08, 1.67, 1.18), (0.008, 0.02, 0.32), "plain", LEATHER_DARK)
        b.blob((0, 1.8, 1.1), (0.03, 0.09, 0.03), "plain", "efe8de", subdiv=1, seed=6, jitter=0.0)
        b.box((0, 1.62, 1.22), (0.17, 0.02, 0.02), "plain", LEATHER_DARK)
    with Part(b, HORSE_TAIL):
        for i in range(6):
            t = i / 5
            b.blob((0, 1.28 - t * 0.55, -0.78 - math.sin(t * 1.4) * 0.1), (0.05 + t * 0.03, 0.12, 0.05 + t * 0.02),
                   "cloth", mane, subdiv=1, seed=60 + i, jitter=0.08)


def model_soldier_reiter(b):
    """Reiter: Pferd mit Schabracke in Stadtfarbe, Sattel, Reiter mit Helmbusch, Lanze und Schild."""
    horse(b)
    # Schabracke (Satteldecke) und Sattel.
    deck = []
    faces = []
    cols = 9
    for k, z in enumerate((-0.42, -0.22, 0.0, 0.2, 0.36)):
        for i in range(cols):
            a = -math.pi * 0.62 + i / (cols - 1) * math.pi * 1.24
            r = 0.32 if abs(z) < 0.3 else 0.3
            deck.append((math.sin(a) * r * 1.02, 1.28 + math.cos(a) * r * 0.98 + (0.0 if abs(a) < 1.2 else -0.06), z))
    for k in range(4):
        for i in range(cols - 1):
            faces.append((k * cols + i, k * cols + i + 1, (k + 1) * cols + i + 1, (k + 1) * cols + i))
    obj = mesh_object("deck", deck, faces)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.012
    sol.offset = 1.0

    def deck_classify(c, n):
        if c[1] < 1.08:
            return ("cloth", TRIM, None, True, False)
        return ("cloth", TEAM, None, True, True)

    add_object(b, obj, deck_classify)
    b.box((0, 1.61, -0.05), (0.3, 0.07, 0.42), "plain", LEATHER)
    b.box((0, 1.67, 0.15), (0.22, 0.1, 0.06), "plain", LEATHER)
    b.box((0, 1.66, -0.24), (0.26, 0.12, 0.05), "plain", LEATHER)
    for s in (-1, 1):
        b.box((s * 0.3, 1.0, 0.27), (0.01, 0.02, 0.08), "metal", "8d939c")
        b.box((s * 0.3, 1.27, 0.25), (0.006, 0.55, 0.01), "plain", LEATHER_DARK)
        star_panel(b, (s * 0.33, 1.28, -0.05), 0.07, rot_y=s * math.pi / 2)
    y0 = 0.72
    arm_r = [(0.2, 1.42, -0.01), (0.28, 1.2, 0.08), (0.29, 1.12, 0.26), (0.28, 1.12, 0.31)]
    arm_l = [(-0.2, 1.42, -0.01), (-0.26, 1.17, 0.07), (-0.16, 1.07, 0.3), (-0.1, 1.06, 0.36)]
    pose = Pose(y0=y0, seated=True, arm_l=arm_l, arm_r=arm_r)
    skin = SKIN[3]
    human_body(b, pose, skin, trousers="514638", boots=LEATHER_DARK, sleeves=MAIL, forearm=MAIL, gloves=LEATHER)
    human_head(b, pose, skin, hair="1e1814", beard="1e1814", seed=1400)
    mail_coif(b, pose)
    plume_helmet(b, pose)
    surcoat(b, pose, length=0.3, flare=0.26, slit=True)
    with Part(b, ARM_R):
        x, y, z = pose.hand(1)
        spear(b, (x, y, z + 0.0), length=3.0, butt=1.25)
        b.box((x, y - 1.25 + 3.0 - 0.38, z + 0.2), (0.008, 0.16, 0.36), "cloth", TEAM)
        b.box((x, y - 1.25 + 3.0 - 0.38, z + 0.43), (0.008, 0.08, 0.1), "cloth", TRIM)
    with Part(b, ARM_L):
        kite_shield(b, (-0.3, pose.y0 + 1.05, 0.2), rot_y=-0.9, size=0.85)
    # Zügel von der Hand zum Maul.
    b.push((-0.05, 1.6, 0.85), rot_x=0.75)
    b.box((0, 0, 0), (0.008, 0.008, 0.62), "plain", LEATHER_DARK)
    b.pop()
    return pose


# ------------------------------------------------------------------ Ausbildungsstätten
# Gebäude im Dorf-Stil (village_building.gdshader, starr): Kaserne, Schießplatz, Stall.

def site_flag(b, at, h=5.0):
    b.cylinder((at[0], h / 2, at[2]), 0.06, h, 6, "beam", "6b4a2f")
    b.box((at[0] + 0.55, h - 0.5, at[2]), (1.0, 0.75, 0.03), "cloth", TEAM, wave=0.8)
    b.box((at[0] + 0.55, h - 0.92, at[2]), (1.0, 0.1, 0.035), "cloth", TRIM, wave=0.8)


def model_site_kaserne(b):
    """Kaserne (8 × 5 m): Steinbau mit Schieferdach, Tor, Fenster, Waffenständer, Übungspuppen, Fahne."""
    w, d, wh = 7.6, 4.6, 2.6
    b.plinth(w + 0.3, d + 0.3, color="8f877a")
    b.box((0, 0.22 + wh / 2, 0), (w, wh, d), "stone_wall", "cfc6b4", bottom=False)
    for x in (-w / 2, 0.0, w / 2):
        for z in (-d / 2, d / 2):
            b.box((x, 0.22 + wh / 2, z), (0.36, wh + 0.06, 0.36), "stone_wall", "aaa290")
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.9, tile="roof_slate", color="ffffff", gable_tile="stone_wall",
                 gable_color="cfc6b4")
    b.door((0, 0.22, d / 2), w=1.5, h=2.0, frame="4a3a2a", lamp=True)
    for x in (-2.6, -1.5, 1.5, 2.6):
        b.window((x, 0.22 + 1.5, d / 2 + 0.01), w=0.5, h=0.7, shutters="2f5f9a", box=False)
    b.box((0, 0.22 + wh + 0.2, d / 2 + 0.05), (1.6, 0.6, 0.06), "cloth", TEAM)
    # Waffenständer mit Speeren und Schilden, Übungspuppen aus Stroh.
    b.box((-2.8, 0.7, d / 2 + 1.2), (1.6, 0.08, 0.12), "beam", "6b4a2f")
    for i in range(5):
        b.cylinder((-3.4 + i * 0.3, 1.2, d / 2 + 1.25), 0.02, 2.4, 5, "beam", WOOD)
        b.cone((-3.4 + i * 0.3, 2.4, d / 2 + 1.25), 0.035, 0.18, 4, "metal", STEEL)
    for i, x in enumerate((1.8, 3.1)):
        b.cylinder((x, 0.7, d / 2 + 1.6), 0.05, 1.4, 6, "beam", "6b4a2f")
        b.blob((x, 1.2, d / 2 + 1.6), (0.22, 0.35, 0.18), "thatch", "e0c070", subdiv=1, seed=70 + i)
        b.blob((x, 1.7, d / 2 + 1.6), (0.14, 0.15, 0.14), "thatch", "e0c070", subdiv=1, seed=80 + i)
        b.box((x, 1.35, d / 2 + 1.6), (0.9, 0.08, 0.08), "beam", "6b4a2f")
    site_flag(b, (-w / 2 - 0.8, 0, d / 2 + 0.8), 5.6)
    b.box((0, 0.03, d / 2 + 1.4), (w + 1.2, 0.06, 2.6), "cobble", "b1a998")


def model_site_schiessplatz(b):
    """Schießplatz: Unterstand, Schießlinie, drei Strohscheiben mit Ringen, Zaun, Bogenständer."""
    b.box((0, 0.03, 0), (9.0, 0.06, 7.0), "field", "c9b98a")
    for z in (-3.4, 3.4):
        b.fence((-4.4, 0, z), (4.4, 0, z), color="9a7048", h=0.8)
    # Unterstand (offenes Pultdach) an der Schießlinie.
    for x in (-3.8, -1.8):
        for z in (1.6, 3.0):
            b.box((x, 1.2, z), (0.14, 2.4, 0.14), "beam", "6b4a2f")
    b.push((-2.8, 2.45, 2.3), rot_x=0.18)
    b.box((0, 0, 0), (2.6, 0.1, 1.9), "thatch", "d6b870")
    b.pop()
    b.box((0, 0.06, 1.2), (8.6, 0.04, 0.12), "plain", "f2ead0")
    for i in range(4):
        b.cylinder((-3.6 + i * 0.4, 0.9, 2.4), 0.02, 1.7, 5, "beam", "7a4a26")
    for i, x in enumerate((-2.4, 0.0, 2.4)):
        b.push((x, 0, -2.4))
        for s in (-1, 1):
            b.push((s * 0.35, 0.65, -0.2), rot_x=0.25)
            b.box((0, 0, 0), (0.08, 1.4, 0.08), "beam", "6b4a2f")
            b.pop()
        b.cylinder((0, 1.15, 0.0), 0.62, 0.3, 18, "thatch", "e3c878", axis="z")
        for r, col in ((0.5, "f4efe2"), (0.36, "c94a3a"), (0.22, "f4efe2"), (0.1, "f0c64a")):
            b.cylinder((0, 1.15, 0.16 + (0.5 - r) * 0.02), r, 0.01, 18, "plain", col, axis="z")
        b.pop()
    site_flag(b, (4.0, 0, 2.6), 4.4)


def model_site_stall(b):
    """Stall: Holzscheune mit großem Tor, Heuboden, Koppelzaun, Tränke, Heuballen, zwei Pferde."""
    w, d, wh = 6.4, 4.2, 2.5
    b.plinth(w + 0.2, d + 0.2, color="8f877a")
    b.box((0, 0.22 + wh / 2, 0), (w, wh, d), "planks", "8a5a36", bottom=False)
    b.timber_frame(w + 0.02, wh, d + 0.02, y0=0.22, color="4a3020")
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.8, tile="thatch", color="ffffff", gable_tile="planks", gable_color="8a5a36")
    for x in (-1.6, 1.6):
        b.box((x, 0.22 + 1.0, d / 2 + 0.03), (1.4, 2.0, 0.06), "planks", "5e3c22")
        b.box((x, 0.22 + 1.0, d / 2 + 0.07), (1.3, 0.1, 0.03), "beam", "3e2a1c")
    b.box((0, 0.22 + wh + 0.6, d / 2 + 0.05), (1.0, 0.8, 0.05), "planks", "3e2a1c")
    b.blob((0, 0.22 + wh + 0.45, d / 2 + 0.12), (0.4, 0.2, 0.1), "thatch", "e0c070", subdiv=1, seed=91)
    for a, c in (((-3.6, 0, 2.6), (3.6, 0, 2.6)), ((-3.6, 0, 6.6), (3.6, 0, 6.6)), ((-3.6, 0, 2.6), (-3.6, 0, 6.6)),
                 ((3.6, 0, 2.6), (3.6, 0, 6.6))):
        b.fence(a, c, color="9a7048", h=0.95)
    b.box((2.4, 0.3, 3.4), (1.4, 0.4, 0.5), "planks", "6b4a2f")
    b.box((2.4, 0.46, 3.4), (1.25, 0.06, 0.38), "plain", "4f8fae")
    for i, (x, z) in enumerate(((-3.0, -2.6), (-2.2, -2.7), (3.4, -2.2))):
        b.cylinder((x, 0.45, z), 0.45, 0.9, 12, "thatch", "e0c070", axis="z")
    start = len(b.bm.faces)
    b.push((-1.2, 0, 4.6), rot_y=0.6)
    horse(b, colour="7a4a2c")
    b.pop()
    b.push((1.0, 0, 5.4), rot_y=-2.2)
    horse(b, colour="3e2c22", mane="1a1410")
    b.pop()
    b.bm.faces.ensure_lookup_table()
    for f in b.bm.faces[start:]:
        for loop in f.loops:
            c = loop[b.col]
            loop[b.col] = (c[0], c[1], c[2], 1.0)
    site_flag(b, (-w / 2 - 0.6, 0, d / 2 + 0.4), 5.0)


SITES = {
    "site_kaserne": model_site_kaserne,
    "site_schiessplatz": model_site_schiessplatz,
    "site_stall": model_site_stall,
}


def build_site(name):
    V.tint = _VILLAGE_TINT
    try:
        V.MODELS[name] = (SITES[name], {})
        info = V.build_model(name)
    finally:
        V.tint = _soldier_tint
    return info


MODELS = {
    "soldier_schild": model_soldier_schild,
    "soldier_bogen": model_soldier_bogen,
    "soldier_speer": model_soldier_speer,
    "soldier_reiter": model_soldier_reiter,
}


METAL_TILE = V.TILES.index("metal")
PLAIN_TILE = V.TILES.index("plain")
SOFT_TILES = {V.TILES.index("cloth"), V.TILES.index("metal")}


def finish(b, name):
    """Spiegeln (Godot: die eigene Linke liegt bei +X), Stoff/Metall auf glatte Kachel, Normalen."""
    bm = b.bm
    b.metal = bm.faces.layers.int.new("metal")
    for v in bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for f in bm.faces:
        tile = f[b.tile]
        if tile in SOFT_TILES:
            f[b.metal] = 1 if tile == METAL_TILE else 0
            f[b.tile] = PLAIN_TILE
    obj = b.to_object(name)
    me = obj.data
    team = me.attributes.get("team")
    uv1 = me.uv_layers.get("TileMap")
    metal = me.attributes.get("metal")
    if team is not None and uv1 is not None:
        flags = [0] * len(me.polygons)
        team.data.foreach_get("value", flags)
        shiny = [0] * len(me.polygons)
        if metal is not None:
            metal.data.foreach_get("value", shiny)
        for poly in me.polygons:
            du = 0.02 if flags[poly.index] else 0.0
            dv = 0.02 if shiny[poly.index] else 0.0
            if du or dv:
                for li in poly.loop_indices:
                    u, v = uv1.data[li].uv
                    uv1.data[li].uv = (u + du, v + dv)
    if WEIGHTED:
        wn = obj.modifiers.new("weighted", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        wn.weight = 50
    return obj


def build(name):
    V.reset()
    b = builder(name)
    pose = MODELS[name](b)
    finish(b, name)
    path = V.OUT / f"{name}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
        export_texcoords=True, export_normals=True, export_tangents=True,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_materials="EXPORT", export_animations=False, export_cameras=False,
        export_lights=False, export_apply=True,
    )
    tris = 0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
    rig = {
        "hip": [abs(pose.leg[1][0][0]), pose.leg[1][0][1], pose.leg[1][0][2]],
        "shoulder": [abs(pose.arm[1][0][0]), pose.arm[1][0][1], pose.arm[1][0][2]],
        "neck": [0.0, pose.neck[1], pose.neck[2]],
        "seated": pose.y0 > 0.0,
        "height": pose.head[1] + 0.17,
    }
    return {"triangles": tris, "bytes": path.stat().st_size, "parts": []}, rig


def write_rig(rigs):
    lines = [
        "extends RefCounted",
        "## Gelenke der Blender-Soldaten (erzeugt von tools/lumo_village_art/build_soldier_models.py).",
        "## village_soldier.gdshader dreht Körperteile um diese Punkte (Godot-Koordinaten, Meter).",
        "const PIVOTS := {",
    ]
    for name in sorted(rigs):
        r = rigs[name]
        lines.append('\t"%s":' % name)
        lines.append(
            '\t{\n\t\t"hip": Vector3(%.3f, %.3f, %.3f),\n\t\t"shoulder": Vector3(%.3f, %.3f, %.3f),\n'
            '\t\t"neck": Vector3(%.3f, %.3f, %.3f),\n\t\t"seated": %s,\n\t\t"height": %.3f,\n\t},'
            % (*r["hip"], *r["shoulder"], *r["neck"], "true" if r["seated"] else "false", r["height"]))
    lines.append("}")
    RIG_PATH.write_text("\n".join(lines) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    names = [n for n in MODELS if not args.only or n in args.only.split(",")]
    report_path = V.OUT / "models.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    rigs = {}
    for name in MODELS:
        if name not in names:
            continue
        info, rig = build(name)
        info["sha256"] = hashlib.sha256((V.OUT / f"{name}.glb").read_bytes()).hexdigest()
        assert info["triangles"] < 20000 and info["bytes"] < 2 * 1024 * 1024, name
        report[name] = info
        rigs[name] = rig
        print(f"{name}: {info['triangles']} tris, {info['bytes']} bytes")
    if len(rigs) == len(MODELS):
        write_rig(rigs)
    for name in SITES:
        if args.only and name not in args.only.split(","):
            continue
        info = build_site(name)
        info["sha256"] = hashlib.sha256((V.OUT / f"{name}.glb").read_bytes()).hexdigest()
        assert info["triangles"] < 20000 and info["bytes"] < 2 * 1024 * 1024, name
        report[name] = info
        print(f"{name}: {info['triangles']} tris, {info['bytes']} bytes")
    report_path.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
