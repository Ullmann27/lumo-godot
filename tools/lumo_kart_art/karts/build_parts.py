#!/usr/bin/env python3
"""Austauschbare Anbauteile der Aurora-Karts: Radaufsätze, Auspuffblenden und Leistungsteile.

Leistungsteile (kart_part_catalog.gd): Motor (Engine_*), Reifen (Tire_*), Heckflügel
(Wing_*), Turbo (Booster_*) und Fahrwerk (Damper_*). Jede Wurzel ist ihr Montagepunkt
(Eigenschaft „mount“): engine_deck / wing_deck (Heckdeck, +Z hinten), wheel_axis (Radmitte,
Achse X), booster_side (rechte Deckseite, links gespiegelt), damper_upright (Radträger
rechts, links gespiegelt).

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/karts/build_parts.py [--thumbs]

Erzeugt
  assets/kart/production/parts/kart_parts.glb   ein Knoten je Teil (Wurzel = Montagepunkt)
  assets/kart/production/parts/thumbs/<id>.png  Teilebild, transparent, einheitliche Kamera

Koordinaten wie im Spiel (Godot): Meter, +Y oben. Radaufsätze schauen nach +X (außen am
rechten Rad; das Spiel spiegelt sie für die linke Seite), Auspuffblenden zeigen nach +Z
(hinten) und sitzen auf den Markern Boost_L/Boost_R. Bevel + gewichtete Normalen, getrennte
Materialien PartPaint (wird im Spiel in Kartfarbe getönt), PartMetal, PartDark, PartRubber,
PartHeat. Alles eigene Geometrie, keine fremden Vorlagen.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/production/parts"
# Godot (x, y, z) -> Blender (x, -z, y)
G_TO_B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def g(p):
    return G_TO_B @ Vector(p)


def linear(hex_color):
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


def material(name, color, metal, rough, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = linear(color)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emission:
        p.inputs["Emission Color"].default_value = linear(color)
        p.inputs["Emission Strength"].default_value = emission
    return m


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def obj_from_bmesh(name, bm, mat, parent, bevel=0.0, segments=2):
    data = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(data)
    bm.free()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = True
    o.parent = parent
    if bevel > 0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
    wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    return o


def lathe(name, profile, mat, parent, axis="x", segments=48, xform=Matrix.Identity(4), cap=True):
    """profile: [(axial, radius)] in Godot units along +X (axis='x'), +Y or +Z.

    cap=False für geschlossene Ringprofile (Reifenhülle, Bänder): keine Deckelscheiben."""
    bm = bmesh.new()
    rings = []
    for axial, radius in profile:
        ring = []
        for k in range(segments):
            a = math.tau * k / segments
            if axis == "x":
                p = (axial, math.cos(a) * radius, math.sin(a) * radius)
            elif axis == "y":
                p = (math.cos(a) * radius, axial, math.sin(a) * radius)
            else:
                p = (math.cos(a) * radius, math.sin(a) * radius, axial)
            ring.append(bm.verts.new(xform @ g(p)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for k in range(segments):
            a, b = rings[r][k], rings[r][(k + 1) % segments]
            c, d = rings[r + 1][(k + 1) % segments], rings[r + 1][k]
            bm.faces.new((a, b, c, d))
    if not cap:
        for k in range(segments):
            a, b = rings[-1][k], rings[-1][(k + 1) % segments]
            c, d = rings[0][(k + 1) % segments], rings[0][k]
            bm.faces.new((a, b, c, d))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        if cap and len(ring) > 2 and profile[0 if flip else -1][1] > 1e-4:
            face = bm.faces.new(list(reversed(ring)) if flip else ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent)


def prism(name, outline, depth, mat, parent, axis="x", offset=0.0, bevel=0.004):
    """Extrude a 2D outline (u, v) along +X (or +Z) from offset to offset+depth."""
    bm = bmesh.new()
    def p3(u, v, w):
        return g((w, u, v)) if axis == "x" else g((u, v, w))
    front = [bm.verts.new(p3(u, v, offset + depth)) for u, v in outline]
    back = [bm.verts.new(p3(u, v, offset)) for u, v in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for k in range(n):
        bm.faces.new((back[k], back[(k + 1) % n], front[(k + 1) % n], front[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent, bevel)


def root_node(name):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o["mount"] = MOUNTS.get(name.split("_")[0], "boost_outlet")
    return o


MOUNTS = {
    "WheelCover": "wheel_face",
    "ExhaustTip": "boost_outlet",
    "Engine": "engine_deck",
    "Wing": "wing_deck",
    "Tire": "wheel_axis",
    "Booster": "booster_side",
    "Damper": "damper_upright",
}


def mats():
    return {
        "paint": material("PartPaint", "e8eef6", 0.35, 0.28),
        "metal": material("PartMetal", "d7dee8", 0.95, 0.16),
        "dark": material("PartDark", "1d222c", 0.4, 0.42),
        "rubber": material("PartRubber", "15181e", 0.0, 0.8),
        "heat": material("PartHeat", "7a5cff", 0.9, 0.2),
        "glow": material("PartGlow", "ffb347", 0.0, 0.4, emission=3.0),
        "cool": material("PartCool", "5fe3ff", 0.0, 0.35, emission=2.5),
        "yellow": material("PartYellow", "f5c542", 0.3, 0.35),
        "red": material("PartRed", "d6323a", 0.35, 0.3),
        "blue": material("PartBlue", "2f6fd6", 0.6, 0.25),
    }


# --------------------------------------------------------------------- Radaufsätze
# Rad: Radius 0.35 (Reifen), Felgenstirn bei x = 0.191, Felgenlippe 0.221. Aufsätze sitzen
# davor (x 0.195 .. 0.235) und bleiben im Felgenring (r <= 0.205).

def wheel_turbine(m):
    root = root_node("WheelCover_Turbine")
    lathe("TurbineRing", [(0.196, 0.205), (0.214, 0.205), (0.222, 0.192), (0.214, 0.178), (0.196, 0.178)],
          m["metal"], root, segments=64)
    lathe("TurbineHub", [(0.196, 0.062), (0.226, 0.060), (0.240, 0.040), (0.246, 0.0)], m["paint"], root, segments=40)
    # Zehn gekrümmte, schräg angestellte Schaufeln: von vorn eine Turbine, im Profil zackig.
    for k in range(10):
        bm = bmesh.new()
        verts = []
        steps = 6
        for i in range(steps + 1):
            t = i / steps
            r = 0.064 + (0.178 - 0.064) * t
            a = math.tau * k / 10 + 0.55 * t * t
            width = 0.020 - 0.006 * t
            for side in (-1, 1):
                aa = a + side * width / r * 0.5
                lean = 0.012 * side
                p = (0.205 + lean + 0.012 * (1 - t), math.cos(aa) * r, math.sin(aa) * r)
                verts.append(bm.verts.new(g(p)))
        for i in range(steps):
            a0, b0, a1, b1 = verts[2 * i], verts[2 * i + 1], verts[2 * i + 2], verts[2 * i + 3]
            bm.faces.new((a0, b0, b1, a1))
        res = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        moved = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=moved, vec=g((0.010, 0, 0)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj_from_bmesh("TurbineBlade_%d" % k, bm, m["metal"] if k % 2 == 0 else m["dark"], root, 0.0015)
    return root


def star_outline(points, outer, inner, rotation=math.pi / 2):
    outline = []
    for k in range(points * 2):
        r = outer if k % 2 == 0 else inner
        a = rotation + math.pi * k / points
        outline.append((math.cos(a) * r, math.sin(a) * r))
    return outline


def wheel_star(m):
    root = root_node("WheelCover_Star")
    lathe("StarBackDisc", [(0.195, 0.200), (0.205, 0.200), (0.207, 0.190), (0.205, 0.0)], m["dark"], root, segments=64)
    prism("StarPlate", star_outline(5, 0.185, 0.078), 0.016, m["paint"], root, "x", 0.205, 0.005)
    prism("StarInlay", star_outline(5, 0.120, 0.052), 0.008, m["metal"], root, "x", 0.221, 0.003)
    lathe("StarCap", [(0.228, 0.036), (0.238, 0.034), (0.244, 0.018), (0.246, 0.0)], m["glow"], root, segments=32)
    return root


# --------------------------------------------------------------------- Auspuffblenden
# Montagepunkt Boost_L/R (0.12, 0.467, 1.13): Blende zeigt nach +Z, vorhandene Öffnung 0.15x0.07.

def exhaust_rocket(m):
    root = root_node("ExhaustTip_Rocket")
    # Glockenförmige Düse mit Anlauf-Ring und dunklem Inneren.
    lathe("RocketBell", [(-0.03, 0.030), (0.0, 0.032), (0.03, 0.036), (0.07, 0.050), (0.10, 0.068),
          (0.108, 0.070), (0.108, 0.062), (0.07, 0.044), (0.03, 0.030), (0.0, 0.026)],
          m["metal"], root, "z", 48)
    lathe("RocketHeatRing", [(0.012, 0.0345), (0.040, 0.0395), (0.040, 0.030), (0.012, 0.030)], m["heat"], root, "z", 40)
    lathe("RocketCore", [(0.02, 0.026), (0.09, 0.040), (0.09, 0.0)], m["glow"], root, "z", 32)
    return root


def exhaust_twin(m):
    root = root_node("ExhaustTip_Twin")
    for k, x in enumerate((-0.034, 0.034)):
        offset = Matrix.Translation(g((x, 0.0, 0.0)))
        # Gerade, schräg abgeschnittene Doppelrohre: kantig und eckig statt rund ausgestellt.
        lathe("TwinPipe_%d" % k, [(-0.03, 0.024), (0.085, 0.024), (0.085, 0.019), (-0.03, 0.019)],
              m["metal"], root, "z", 6, offset)
        lathe("TwinInner_%d" % k, [(0.0, 0.019), (0.080, 0.019), (0.080, 0.0)], m["dark"], root, "z", 6, offset)
    prism("TwinBracket", [(-0.068, -0.016), (0.068, -0.016), (0.068, 0.016), (-0.068, 0.016)], 0.03,
          m["paint"], root, "z", -0.01, 0.004)
    return root


# --------------------------------------------------------------------- Leistungsteile
# Hilfen: Kasten (gerundete Kanten über Bevel), Rohr entlang einer Linie (Federn, Streben).

def box(name, centre, size, mat, parent, bevel=0.008):
    """Quader in Godot-Koordinaten (Mitte, Größe), Kanten gefast."""
    cx, cy, cz = centre
    sx, sy, sz = (v * 0.5 for v in size)
    outline = [(cx - sx, cy - sy), (cx + sx, cy - sy), (cx + sx, cy + sy), (cx - sx, cy + sy)]
    return prism(name, outline, sz * 2, mat, parent, "z", cz - sz, bevel)


def sweep(name, points, radius, mat, parent, segments=10, closed_ends=True):
    """Rohr mit Kreisquerschnitt entlang einer Punktfolge (Godot-Koordinaten)."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            tangent = pts[1] - pts[0]
        elif i == len(pts) - 1:
            tangent = pts[-1] - pts[-2]
        else:
            tangent = pts[i + 1] - pts[i - 1]
        tangent.normalize()
        helper = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
        side = tangent.cross(helper).normalized()
        up = side.cross(tangent).normalized()
        ring = []
        for k in range(segments):
            a = math.tau * k / segments
            q = p + (side * math.cos(a) + up * math.sin(a)) * radius
            ring.append(bm.verts.new(g(q)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for k in range(segments):
            bm.faces.new((rings[r][k], rings[r][(k + 1) % segments],
                          rings[r + 1][(k + 1) % segments], rings[r + 1][k]))
    if closed_ends:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent)


def helix(start, end, radius, turns, steps_per_turn=14):
    """Punkte einer Schraubenfeder von start nach end (Godot-Koordinaten)."""
    a, b = Vector(start), Vector(end)
    axis = b - a
    length = axis.length
    axis.normalize()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    steps = int(turns * steps_per_turn)
    return [tuple(a + axis * (length * i / steps) + (u * math.cos(math.tau * turns * i / steps)
                                                      + v * math.sin(math.tau * turns * i / steps)) * radius)
            for i in range(steps + 1)]


def oriented(start, end):
    """Matrix, die die Lathe-Achse +Y auf die Strecke start→end legt (für lathe axis='y')."""
    a, b = g(start), g(end)
    direction = (b - a).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4()
    # lathe axis 'y' (Godot) = Blender +Z
    return Matrix.Translation(a) @ rot


# Motor: Wurzel auf dem Heckdeck hinter dem Sitz (engine_deck), +Z zeigt nach hinten.
def engine_sprint(m):
    root = root_node("Engine_Sprint")
    box("SprintBlock", (0, 0.045, 0.10), (0.26, 0.09, 0.22), m["dark"], root, 0.012)
    box("SprintPlate", (0, 0.095, 0.10), (0.22, 0.012, 0.18), m["paint"], root, 0.004)
    # Vier kurze, weit ausgestellte Ansaugtrichter: der schnelle Antritt.
    for k, (x, z) in enumerate(((-0.055, 0.05), (0.055, 0.05), (-0.055, 0.15), (0.055, 0.15))):
        xf = Matrix.Translation(g((x, 0.0, z)))
        lathe("SprintStack_%d" % k, [(0.10, 0.026), (0.15, 0.024), (0.18, 0.034), (0.195, 0.046),
                                       (0.198, 0.040), (0.17, 0.026), (0.12, 0.020)],
              m["metal"], root, "y", 32, xf)
        lathe("SprintGlow_%d" % k, [(0.12, 0.019), (0.175, 0.024), (0.175, 0.0)], m["glow"], root, "y", 20, xf)
    return root


def engine_long(m):
    root = root_node("Engine_Long")
    # Lange, flache Haube mit Kühlrippen und einer großen Lufthutze: hohes Endtempo.
    prism("LongCover", [(-0.12, 0.0), (0.12, 0.0), (0.11, 0.09), (0.06, 0.12), (-0.06, 0.12), (-0.11, 0.09)],
          0.34, m["paint"], root, "z", -0.02, 0.01)
    for k in range(6):
        z = 0.02 + k * 0.05
        prism("LongFin_%d" % k, [(-0.125, 0.03), (0.125, 0.03), (0.125, 0.105), (-0.125, 0.105)],
              0.012, m["metal"], root, "z", z, 0.002)
    prism("LongScoop", [(-0.07, 0.10), (0.07, 0.10), (0.06, 0.20), (-0.06, 0.20)], 0.12,
          m["dark"], root, "z", -0.04, 0.008)
    box("LongScoopGlow", (0, 0.15, -0.042), (0.10, 0.07, 0.006), m["cool"], root, 0.0)
    box("LongStripe", (0, 0.122, 0.20), (0.03, 0.006, 0.30), m["cool"], root, 0.0)
    return root


# Heckflügel: Wurzel am Heckdeck (wing_deck), Streben gehen nach oben.
def wing_plane(name, span, chord, thick, y, z, mat, parent, camber=0.25):
    outline = []
    for i in range(9):
        t = i / 8
        outline.append((z - chord * 0.5 + chord * t, y + thick * (0.6 * math.sin(math.pi * t)) + camber * thick * t))
    for i in range(8, -1, -1):
        t = i / 8
        outline.append((z - chord * 0.5 + chord * t, y - thick * 0.25 * math.sin(math.pi * t) + camber * thick * t))
    bm = bmesh.new()
    front = [bm.verts.new(g((span * 0.5, v, u))) for u, v in outline[:-1]]
    back = [bm.verts.new(g((-span * 0.5, v, u))) for u, v in outline[:-1]]
    n = len(front)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for k in range(n):
        bm.faces.new((back[k], back[(k + 1) % n], front[(k + 1) % n], front[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent, 0.003)


def wing_big(m):
    root = root_node("Wing_Big")
    wing_plane("BigMain", 0.86, 0.24, 0.05, 0.30, 0.0, m["paint"], root)
    wing_plane("BigFlap", 0.82, 0.12, 0.03, 0.37, 0.09, m["dark"], root)
    for side in (-1, 1):
        prism("BigEndplate_%d" % side, [(0.20, -0.16), (0.22, 0.18), (0.44, 0.18), (0.42, -0.10)], 0.014,
              m["dark"], root, "x", side * 0.43 - 0.007, 0.004)
        box("BigEndGlow_%d" % side, (side * 0.438, 0.40, 0.02), (0.004, 0.025, 0.26), m["glow"], root, 0.0)
        sweep("BigStrut_%d" % side, [(side * 0.16, 0.0, 0.02), (side * 0.16, 0.30, 0.0)], 0.016, m["metal"], root)
    return root


def wing_flat(m):
    root = root_node("Wing_Flat")
    # Flache, schmale Abrisskante dicht am Heck: wenig Luftwiderstand.
    wing_plane("FlatMain", 0.74, 0.13, 0.022, 0.13, 0.03, m["paint"], root, camber=0.1)
    for side in (-1, 1):
        prism("FlatTip_%d" % side, [(0.10, -0.04), (0.11, 0.10), (0.16, 0.10), (0.155, -0.02)], 0.01,
              m["metal"], root, "x", side * 0.37 - 0.005, 0.003)
        prism("FlatStrut_%d" % side, [(0.0, -0.03), (0.0, 0.03), (0.13, 0.04), (0.13, -0.01)], 0.018,
              m["dark"], root, "x", side * 0.12 - 0.009, 0.003)
    box("FlatStripe", (0, 0.146, 0.03), (0.70, 0.004, 0.02), m["cool"], root, 0.0)
    return root


def wing_glide(m):
    root = root_node("Wing_Glide")
    # Breiter, nach hinten gepfeilter Gleiter mit Federspitzen: lenkt in der Luft.
    for side in (-1, 1):
        outline = [(0.0, -0.10), (0.24, -0.05), (0.46, 0.06), (0.56, 0.16), (0.50, 0.19), (0.24, 0.09), (0.0, 0.07)]
        bm = bmesh.new()
        upper = [bm.verts.new(g((side * x, 0.28 + 0.12 * x * x + 0.012, z))) for x, z in outline]
        lower = [bm.verts.new(g((side * x, 0.28 + 0.12 * x * x - 0.012, z))) for x, z in outline]
        bm.faces.new(upper)
        bm.faces.new(list(reversed(lower)))
        n = len(outline)
        for k in range(n):
            bm.faces.new((lower[k], lower[(k + 1) % n], upper[(k + 1) % n], upper[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj_from_bmesh("GlideWing_%d" % side, bm, m["paint"], root, 0.004)
        for f in range(3):
            x0 = 0.50 - f * 0.05
            sweep("GlideFeather_%d_%d" % (side, f),
                  [(side * x0, 0.28 + 0.12 * x0 * x0, 0.15 + f * 0.02),
                   (side * (x0 + 0.05), 0.32 + 0.12 * x0 * x0 + f * 0.012, 0.27 + f * 0.02)],
                  0.010, m["cool"] if f == 0 else m["metal"], root, 8)
        sweep("GlideStrut_%d" % side, [(side * 0.12, 0.0, 0.03), (side * 0.12, 0.285, 0.01)], 0.015, m["metal"], root)
    lathe("GlideHub", [(-0.10, 0.0), (-0.09, 0.03), (0.10, 0.03), (0.11, 0.0)], m["dark"], root, "z", 20,
          Matrix.Translation(g((0, 0.28, 0))))
    return root


# Turbo: Wurzel an der rechten Deckseite (booster_side), links gespiegelt.
def booster_short(m):
    root = root_node("Booster_Short")
    # Kompakter Turbolader (Schnecke): kurzer, starker Schub.
    lathe("ShortSnail", [(-0.035, 0.0), (-0.035, 0.070), (-0.025, 0.078), (0.025, 0.078), (0.035, 0.070),
          (0.035, 0.0)], m["metal"], root, "x", 40)
    sweep("ShortOutlet", [(0.0, 0.065, -0.02), (0.0, 0.07, 0.06), (0.0, 0.04, 0.12)], 0.024, m["metal"], root, 14)
    lathe("ShortInletRing", [(0.035, 0.050), (0.055, 0.050), (0.055, 0.038), (0.035, 0.038)], m["dark"], root, "x", 32,
          cap=False)
    lathe("ShortInletGlow", [(0.04, 0.038), (0.05, 0.03), (0.05, 0.0)], m["glow"], root, "x", 24)
    lathe("ShortHeat", [(-0.045, 0.060), (-0.035, 0.060), (-0.035, 0.0), (-0.045, 0.0)], m["heat"], root, "x", 32)
    box("ShortBracket", (-0.02, -0.06, 0.0), (0.05, 0.04, 0.10), m["dark"], root, 0.006)
    return root


def booster_long(m):
    root = root_node("Booster_Long")
    # Langer Druckbehälter mit Leuchtfenster: sanfter Schub, der lange hält.
    lathe("LongTank", [(-0.20, 0.0), (-0.19, 0.03), (-0.17, 0.045), (0.15, 0.045), (0.17, 0.03), (0.18, 0.0)],
          m["blue"], root, "z", 32)
    for k, z in enumerate((-0.12, 0.0, 0.11)):
        lathe("LongBand_%d" % k, [(z - 0.012, 0.047), (z + 0.012, 0.047), (z + 0.012, 0.040), (z - 0.012, 0.040)],
              m["metal"], root, "z", 32, cap=False)
    box("LongWindow", (0.044, 0.0, -0.06), (0.006, 0.026, 0.10), m["cool"], root, 0.0)
    box("LongWindow2", (0.044, 0.0, 0.055), (0.006, 0.026, 0.07), m["cool"], root, 0.0)
    sweep("LongPipe", [(0.0, -0.03, 0.17), (0.0, -0.05, 0.22), (-0.03, -0.07, 0.25)], 0.012, m["metal"], root, 10)
    box("LongCradle", (0.0, -0.05, 0.0), (0.06, 0.02, 0.26), m["dark"], root, 0.005)
    return root


# Reifen: Wurzel in der Radmitte (wheel_axis), Achse X; Laufflächen-Hülle über dem Serienreifen.
TIRE_R = 0.350


def tire_shell(name, radius, half_width, mat, root, segments=72):
    return lathe(name, [(-half_width, radius - 0.03), (-half_width + 0.01, radius - 0.004), (-half_width + 0.03, radius),
                        (half_width - 0.03, radius), (half_width - 0.01, radius - 0.004), (half_width, radius - 0.03),
                        (half_width - 0.01, radius - 0.04), (-half_width + 0.01, radius - 0.04)],
                 mat, root, "x", segments, cap=False)


def sidewall_ring(name, x, r0, r1, mat, root, segments=64):
    return lathe(name, [(x - 0.004, r0), (x - 0.004, r1), (x + 0.004, r1), (x + 0.004, r0)], mat, root, "x", segments,
                 cap=False)


def tire_grip(m):
    root = root_node("Tire_Grip")
    # Breiter Slick mit gelbem Haftstreifen: klebt in Kurven.
    tire_shell("GripSlick", TIRE_R + 0.004, 0.175, m["rubber"], root)
    for side in (-1, 1):
        sidewall_ring("GripStripe_%d" % side, side * 0.198, 0.286, 0.306, m["yellow"], root)
    return root


def tire_drift(m):
    root = root_node("Tire_Drift")
    tire_shell("DriftShell", TIRE_R + 0.003, 0.168, m["rubber"], root)
    # Schräge Rillen und ein violetter Ring mit Pfeilen: rutscht leicht und lädt schnell.
    for k in range(24):
        a = math.tau * k / 24
        r = TIRE_R + 0.004
        p0 = (-0.12, math.cos(a) * r, math.sin(a) * r)
        p1 = (0.12, math.cos(a + 0.22) * r, math.sin(a + 0.22) * r)
        sweep("DriftGroove_%d" % k, [p0, p1], 0.006, m["dark"], root, 6)
    for side in (-1, 1):
        sidewall_ring("DriftRing_%d" % side, side * 0.198, 0.27, 0.29, m["heat"], root)
        for k in range(6):
            a = math.tau * k / 6
            pts = [(side * 0.203, math.cos(a + d) * (0.30 + abs(d) * 0.1), math.sin(a + d) * (0.30 + abs(d) * 0.1))
                   for d in (-0.12, 0.0, 0.12)]
            sweep("DriftChevron_%d_%d" % (side, k), pts, 0.008, m["cool"], root, 6)
    return root


def tire_knobby(m):
    root = root_node("Tire_Knobby")
    tire_shell("KnobbyBase", TIRE_R - 0.002, 0.17, m["rubber"], root)
    # Grobe Stollen in zwei versetzten Reihen: Halt auf Sand und Gras.
    count = 18
    for row, x in enumerate((-0.085, 0.085)):
        for k in range(count):
            a = math.tau * (k + 0.5 * row) / count
            bm = bmesh.new()
            corners = []
            for dx in (-0.06, 0.06):
                for da in (-0.05, 0.05):
                    for rr in (TIRE_R - 0.01, TIRE_R + 0.020):
                        corners.append(bm.verts.new(g((x + dx, math.cos(a + da) * rr, math.sin(a + da) * rr))))
            bmesh.ops.convex_hull(bm, input=corners)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            obj_from_bmesh("Knob_%d_%d" % (row, k), bm, m["rubber"], root, 0.004)
    for side in (-1, 1):
        sidewall_ring("KnobbyRing_%d" % side, side * 0.198, 0.28, 0.30, m["glow"], root)
    return root


# Fahrwerk: Wurzel am Radträger rechts (damper_upright), Feder zur Karosserie, links gespiegelt.
DAMPER_LOW = (-0.215, 0.10, 0.0)
DAMPER_HIGH = (-0.40, 0.29, 0.0)


def damper_body(prefix, m, root, radius, colour):
    xf = oriented(DAMPER_LOW, DAMPER_HIGH)
    length = (Vector(DAMPER_HIGH) - Vector(DAMPER_LOW)).length
    lathe(prefix + "Body", [(0.0, radius * 0.55), (length * 0.55, radius * 0.55), (length * 0.55, radius * 0.75),
                             (length, radius * 0.75), (length, 0.0)], m["metal"], root, "y", 20, xf)
    lathe(prefix + "Cap", [(length * 0.94, radius * 1.25), (length * 1.02, radius * 1.25), (length * 1.02, 0.0)],
          colour, root, "y", 24, xf)
    lathe(prefix + "Seat", [(0.02, radius * 1.25), (0.04, radius * 1.25), (0.04, 0.0)], colour, root, "y", 24, xf)


def damper_spring(m):
    root = root_node("Damper_Spring")
    # Dicke, weiche gelbe Feder mit vielen Windungen: federt Landungen weich ab.
    damper_body("Spring", m, root, 0.028, m["dark"])
    sweep("SpringCoil", helix(DAMPER_LOW, DAMPER_HIGH, 0.042, 7), 0.0085, m["yellow"], root, 8)
    return root


def damper_sport(m):
    root = root_node("Damper_Sport")
    # Kurze, harte rote Feder auf blauem Sportdämpfer: liegt flach in Kurven.
    damper_body("Sport", m, root, 0.026, m["blue"])
    low = tuple(Vector(DAMPER_LOW) + (Vector(DAMPER_HIGH) - Vector(DAMPER_LOW)) * 0.35)
    sweep("SportCoil", helix(low, DAMPER_HIGH, 0.036, 3.5), 0.010, m["red"], root, 8)
    return root


def damper_heavy(m):
    root = root_node("Damper_Heavy")
    # Doppelte, dicke Dämpfer mit Schutzblech: Rempler bremsen kaum.
    for k, dz in enumerate((-0.05, 0.05)):
        low = (DAMPER_LOW[0], DAMPER_LOW[1], dz)
        high = (DAMPER_HIGH[0], DAMPER_HIGH[1], dz)
        xf = oriented(low, high)
        length = (Vector(high) - Vector(low)).length
        lathe("HeavyBody_%d" % k, [(0.0, 0.026), (length, 0.026), (length, 0.0)], m["dark"], root, "y", 16, xf)
        sweep("HeavyCoil_%d" % k, helix(low, high, 0.036, 4.5), 0.012, m["metal"], root, 8)
    box("HeavyGuard", (-0.30, 0.20, 0.0), (0.03, 0.16, 0.20), m["paint"], root, 0.01)
    box("HeavyGuardStripe", (-0.284, 0.20, 0.0), (0.004, 0.03, 0.18), m["glow"], root, 0.0)
    return root


BUILDERS = {
    "WheelCover_Turbine": wheel_turbine,
    "WheelCover_Star": wheel_star,
    "ExhaustTip_Rocket": exhaust_rocket,
    "ExhaustTip_Twin": exhaust_twin,
    "Engine_Sprint": engine_sprint,
    "Engine_Long": engine_long,
    "Tire_Grip": tire_grip,
    "Tire_Drift": tire_drift,
    "Tire_Knobby": tire_knobby,
    "Wing_Big": wing_big,
    "Wing_Flat": wing_flat,
    "Wing_Glide": wing_glide,
    "Booster_Short": booster_short,
    "Booster_Long": booster_long,
    "Damper_Spring": damper_spring,
    "Damper_Sport": damper_sport,
    "Damper_Heavy": damper_heavy,
}


def apply_modifiers():
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)


def build_all():
    reset()
    m = mats()
    roots = {}
    for i, (name, fn) in enumerate(BUILDERS.items()):
        root = fn(m)
        roots[name] = root
    apply_modifiers()
    return roots


def export(roots):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "kart_parts.glb"), export_format="GLB", export_apply=True,
                              export_yup=True, export_extras=True, export_animations=False)
    stats = {}
    for name, root in roots.items():
        tris = 0
        for child in root.children:
            child.data.calc_loop_triangles()
            tris += len(child.data.loop_triangles)
        stats[name] = tris
    print("[KartParts] triangles", stats)


# Einheitliche Kamera je Teileart: (Zielpunkt relativ zum Montagepunkt, Blickrichtung, Bildbreite m).
THUMB_KIND = {"WheelCover": "wheel_cover", "ExhaustTip": "exhaust", "Engine": "engine", "Wing": "wing",
              "Booster": "booster", "Tire": "tires", "Damper": "suspension"}
THUMB_CAMERA = {
    "wheel_cover": ((0.22, 0, 0), (1.0, 0.35, -0.45), 0.50),
    "exhaust": ((0, 0, 0.04), (0.55, 0.35, 1.0), 0.26),
    "engine": ((0, 0.09, 0.13), (0.7, 0.75, 1.0), 0.50),
    "wing": ((0, 0.24, 0.0), (0.75, 0.55, 1.0), 1.05),
    "booster": ((0, 0.0, 0.0), (1.0, 0.6, 0.8), 0.50),
    "tires": ((0.0, 0, 0), (1.0, 0.25, -0.5), 0.86),
    "suspension": ((-0.30, 0.20, 0), (0.6, 0.45, -1.0), 0.50),
}


def render_thumbs(roots):
    thumbs = OUT / "thumbs"
    thumbs.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 60
    key.size = 0.6
    key_o = bpy.data.objects.new("Key", key)
    bpy.context.collection.objects.link(key_o)
    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 35
    rim.color = (1.0, 0.75, 0.5)
    rim_o = bpy.data.objects.new("Rim", rim)
    bpy.context.collection.objects.link(rim_o)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam_o = bpy.data.objects.new("Cam", cam)
    bpy.context.collection.objects.link(cam_o)
    scene.camera = cam_o
    only = None
    for arg in sys.argv:
        if arg.startswith("--only="):
            only = arg[7:].split(",")
    shots = [(name, Vector((0, 0, 0)), root) for name, root in roots.items()]
    # Serie: das echte Originalteil bzw. die Originalstelle des Komet-Karts, gleiche Kamera.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/kart/production/karts/aurora_comet.glb"))
    kart_objects = [o for o in bpy.data.objects if o not in before]
    by_name = {o.name: o for o in kart_objects}
    wheel_fr = by_name["Wheel_FR"].matrix_world.translation.copy()
    shots.append(("Serie_wheel_cover", wheel_fr, None))
    shots.append(("Serie_exhaust", by_name["Boost_R"].matrix_world.translation.copy(), None))
    # Gleiche Montagepunkte wie PART_MOUNTS (Comet) in kart_production_vehicle.gd.
    shots.append(("Serie_engine", g((0, 0.64, 0.70)), None))
    shots.append(("Serie_wing", g((0, 0.66, 1.00)), None))
    shots.append(("Serie_booster", g((0.29, 0.68, 0.86)), None))
    shots.append(("Serie_tires", wheel_fr, None))
    shots.append(("Serie_suspension", by_name["Steer_FR"].matrix_world.translation.copy(), None))
    for name, origin, root in shots:
        if only and name not in only:
            continue
        for other in roots.values():
            for child in other.children:
                child.hide_render = other is not root
        for o in kart_objects:
            o.hide_render = root is not None
        kind = THUMB_KIND.get(name.split("_")[0], name.split("_", 1)[-1])
        if kind == "tires" and root is not None:
            # Reifen auf dem echten Serienrad zeigen (Felge sichtbar), gleiche Kamera wie Serie.
            root.location = wheel_fr
            origin = wheel_fr
            for o in kart_objects:
                o.hide_render = o.name != "Wheel_FR_Mesh"
        offset, view, scale = THUMB_CAMERA[kind]
        target = origin + g(offset)
        cam.ortho_scale = scale * (1.0 if root is not None or kind not in ("exhaust",) else 1.77)
        cam_o.location = target + g(view).normalized() * 3.0
        direction = target - cam_o.location
        cam_o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        key_o.location = target + g((0.8, 1.0, -0.6))
        key_o.rotation_euler = (target - key_o.location).to_track_quat("-Z", "Y").to_euler()
        rim_o.location = target + g((-0.6, 0.6, 0.9))
        rim_o.rotation_euler = (target - rim_o.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(thumbs / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        if root is not None:
            root.location = (0, 0, 0)
        print("[KartParts] thumb", scene.render.filepath)


if __name__ == "__main__":
    roots = build_all()
    export(roots)
    if "--thumbs" in sys.argv:
        render_thumbs(roots)
