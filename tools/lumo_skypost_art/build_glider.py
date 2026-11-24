"""Lumos Sternsegler: kleiner Motorsegler mit offenem Cockpit, Steuerhorn und Posttasche.

Masse aus der Sitzmessung (scripts/tests/sky_post_seat_probe.gd, Fliegerraum, Meter):
  Lumo kart_seated: Becken y 0.85 / z -0.05, Fuesse y 0.19 / z -0.22..-0.52,
  Haende (+-0.17, 1.02, -0.36), Kopf y 1.31, Ohren bis y 1.9, Schweif hinten bis z 0.65.
  Steuerhorn-Mitte daher (0, 1.02, -0.36), Griffe +-0.17 in x.
Bewegliche Teile (nur LOD0, Drehpunkt = Scharnier): Yoke, Propeller, AileronL/R, Elevator, Rudder.
"""
from __future__ import annotations

import math

import bpy  # noqa: I001
import bmesh
from mathutils import Matrix, Vector

import skypost_geo as G

FUSELAGE = [
    # z, cx, cy, half width, half height, power
    (-2.16, 0, .55, .03, .03, 2.0),
    (-2.08, 0, .55, .2, .2, 2.0),
    (-1.85, 0, .55, .34, .33, 2.3),
    (-1.35, 0, .53, .45, .43, 2.5),
    (-.75, 0, .49, .52, .5, 2.6),
    (-.1, 0, .47, .53, .5, 2.6),
    (.5, 0, .5, .47, .44, 2.6),
    (1.1, 0, .62, .31, .3, 2.4),
    (1.8, 0, .74, .18, .18, 2.2),
    (2.6, 0, .8, .13, .14, 2.1),
    (3.25, 0, .83, .1, .12, 2.0),
    (3.42, 0, .83, .025, .03, 2.0),
]
WING_ROOT, WING_TIP = .42, 3.86
AILERON = (2.06, 3.6)
AILERON_CHORD = .2
DIHEDRAL = math.tan(math.radians(5))
YOKE_AT = (0, 1.02, -.36)
PROP_AT = (0, .55, -2.47)
TAIL_Y = 1.98
ELEVATOR_AT = (0, TAIL_Y + .02, 3.57)
RUDDER_AT = (0, .98, 3.47)


def hull_top(z):
    for a, b in zip(FUSELAGE, FUSELAGE[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return (a[2] + a[4]) * (1 - t) + (b[2] + b[4]) * t
    return FUSELAGE[-1][2]


def chord_at(x):
    t = (x - WING_ROOT) / (3.7 - WING_ROOT)
    return 1.15 + (.66 - 1.15) * min(max(t, 0), 1.2)


def le_at(x):
    return -.62 + (1.15 - chord_at(x)) * .35


def y_at(x):
    return .4 + (x - WING_ROOT) * DIHEDRAL


def aileron_hinge(side):
    x = sum(AILERON) / 2
    return (side * x, y_at(x), le_at(x) + chord_at(x) - AILERON_CHORD)


def mats():
    return {
        "paint": G.material("SP_Paint", "f3efe4", rough=.32, coat=.6),
        "trim": G.material("SP_Trim", "2c6fe0", rough=.34, coat=.5),
        "accent": G.material("SP_Accent", "ffc23a", metal=.6, rough=.28),
        "glass": G.material("SP_Glass", "bfe6ff", rough=.05, alpha=.32),
        "metal": G.material("SP_Metal", "c9d2dc", metal=.9, rough=.25),
        "dark": G.material("SP_Dark", "24324a", rough=.7),
        "seat": G.material("SP_Seat", "c2542f", rough=.6),
        "leather": G.material("SP_Leather", "8a5230", rough=.55),
        "wood": G.material("SP_Wood", "b87a45", rough=.45),
        "paper": G.material("SP_Paper", "fbf7ea", rough=.8),
        "red": G.material("SP_LampRed", "ff4a4a", emission=4.0),
        "green": G.material("SP_LampGreen", "4dff8a", emission=4.0),
    }


def _cutter(detail):
    bm = G.loft([
        (-.68, 0, 1.42, .36, .9, 3.2), (-.5, 0, 1.42, .41, .9, 3.4), (0, 0, 1.42, .42, .9, 3.4),
        (.3, 0, 1.42, .39, .9, 3.2), (.44, 0, 1.42, .3, .9, 3.0)], n=24 if detail == 0 else 14)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("cutter", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(G.material("SP_Dark", "24324a", rough=.7))
    return obj


def tube(points, radius, sides, closed=True):
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    k = len(pts)
    rings = []
    for i, p in enumerate(pts):
        nxt = pts[(i + 1) % k] if (closed or i + 1 < k) else p + (p - pts[i - 1])
        prv = pts[i - 1] if (closed or i > 0) else p - (pts[1] - p)
        tangent = (nxt - prv).normalized()
        up = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
        side = tangent.cross(up).normalized()
        up = side.cross(tangent).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(math.tau * s / sides) + up * math.sin(math.tau * s / sides)) * radius)
                      for s in range(sides)])
    for i in range(k if closed else k - 1):
        a, b = rings[i], rings[(i + 1) % k]
        for s in range(sides):
            bm.faces.new((a[s], a[(s + 1) % sides], b[(s + 1) % sides], b[s]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _windscreen(detail):
    bm = bmesh.new()
    cols = 13 if detail == 0 else 7
    rows = []
    for r in range(3):
        v = r / 2
        row = []
        for i in range(cols):
            t = -1 + 2 * i / (cols - 1)
            row.append(bm.verts.new((.42 * t, .9 + v * (.39 - .12 * t * t), -.86 + .12 * t * t + v * .07)))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for i in range(cols - 1):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=.014)
    return bm


def _wing_sections(side, notch):
    stations = [WING_ROOT, 1.6, AILERON[0] - .02]
    if notch:
        stations += [AILERON[0], 2.9, AILERON[1], AILERON[1] + .02]
    else:
        stations += [2.9]
    stations += [3.7, WING_TIP]
    out = []
    for x in stations:
        chord = chord_at(x) if x < 3.75 else .5
        thick = .14 + (.1 - .14) * (x - WING_ROOT) / (WING_TIP - WING_ROOT)
        cut = AILERON_CHORD if notch and AILERON[0] - .001 <= x <= AILERON[1] + .001 else 0.0
        le = le_at(x) if x < 3.75 else le_at(3.7) + .1
        out.append(((side * x, y_at(x), le), chord - cut, thick))
    return list(reversed(out)) if side < 0 else out


def body(model, m, detail):
    n = [32, 20, 10][detail]
    cutter = _cutter(detail)
    model.add(G.loft(FUSELAGE, n=n), m["paint"], boolean=cutter, angle=60)
    bpy.data.objects.remove(cutter, do_unlink=True)
    if detail < 2:
        cowl = [(z, cx, cy, hw * 1.015, hh * 1.015, pw) for z, cx, cy, hw, hh, pw in FUSELAGE[1:3]]
        cowl.append((-1.4, 0, .532, .452, .433, 2.5))
        model.add(G.loft(cowl, n=n), m["trim"], angle=60)
        ring = []
        for x, zz in G.superellipse(.43, .57, 3.2, 28 if detail == 0 else 16):
            z = -.12 + zz
            ring.append((x, hull_top(z) - .035, z))
        model.add(tube(ring, .045, 8 if detail == 0 else 5), m["trim"])
    # Seat, dashboard and gauges.
    bev = .035 if detail == 0 else 0.0
    model.add(G.box((0, .6, .03), (.62, .1, .5)), m["seat"], bevel=bev)
    model.add(G.box((0, .95, .31), (.6, .62, .1), rot=(-.2, 0, 0)), m["seat"], bevel=bev)
    model.add(G.box((0, .8, -.67), (.8, .32, .14), rot=(.35, 0, 0)), m["dark"], bevel=bev)
    if detail == 0:
        for x in (-.22, 0, .22):
            model.add(G.cylinder((x, .85, -.615), (x, .86, -.59), .075, segments=18), m["accent"])
            model.add(G.cylinder((x, .861, -.592), (x, .864, -.584), .06, segments=18), m["paper"])
    if detail < 2:
        model.add(_windscreen(detail), m["glass"])
        frame = [(.43 * t, 1.29 - .12 * t * t, -.79 + .12 * t * t)
                 for t in [-1 + 2 * i / 12 for i in range(13)]]
        model.add(tube(frame, .022, 6, closed=False), m["trim"])
    # Wings (dihedral, notch for ailerons), winglets with navigation lamps.
    for side in (-1, 1):
        model.add(G.wing(_wing_sections(side, detail < 2), n=[16, 10, 6][detail]), m["paint"], angle=50)
        tip = Vector((side * 3.86, y_at(3.86), le_at(3.7) + .1))
        model.add(G.fin([((tip.x, tip.y - .03, tip.z), .5, .08), ((tip.x + side * .1, tip.y + .46, tip.z + .22), .26, .06)],
                        n=[10, 6, 4][detail]), m["trim"])
        if detail < 2:
            model.add(G.sphere((tip.x + side * .035, tip.y + .03, tip.z + .02), (.06, .06, .06), 10, 6),
                      m["red"] if side < 0 else m["green"])
        if detail == 0:
            # Blue band across the wing near the tip.
            band = [((side * 3.1, y_at(3.1) + .002, le_at(3.1) - .01), chord_at(3.1) - AILERON_CHORD + .02, .155),
                    ((side * 3.3, y_at(3.3) + .002, le_at(3.3) - .01), chord_at(3.3) - AILERON_CHORD + .02, .15)]
            model.add(G.wing(band if side > 0 else list(reversed(band)), n=10), m["trim"])
    # T-tail.
    model.add(G.fin([((0, .9, 2.55), .95, .12), ((0, TAIL_Y, 3.0), .55, .1)], n=[12, 8, 5][detail]), m["trim"])
    for side in (-1, 1):
        sections = [((0, TAIL_Y, 2.98), .58, .1), ((side * 1.2, TAIL_Y + .04, 3.12), .42, .08)]
        model.add(G.wing(sections if side > 0 else list(reversed(sections)), n=[10, 8, 5][detail]), m["paint"])
    # Spinner, wheel, skid.
    spinner = G.lathe([(0, 0), (.17, .02), (.21, .12), (.14, .25), (.05, .32), (0, .33)], segments=[24, 14, 8][detail])
    spinner.transform(Matrix.Translation((0, .55, -2.1)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    model.add(spinner, m["accent"])
    if detail < 2:
        model.add(G.cylinder((-.06, -.04, -.1), (.06, -.04, -.1), .2, segments=[18, 10][detail]), m["dark"])
        model.add(G.cylinder((-.065, -.04, -.1), (.065, -.04, -.1), .09, segments=[12, 8][detail]), m["metal"])
        model.add(G.box((0, .64, 3.22), (.05, .12, .3), rot=(.4, 0, 0)), m["metal"])
    # Post bag with letters and star.
    model.add(G.box((0, 1.03, .78), (.56, .36, .42)), m["leather"], bevel=.06 if detail == 0 else 0.0)
    if detail < 2:
        model.add(G.box((0, 1.22, .7), (.6, .06, .3), rot=(-.25, 0, 0)), m["leather"], bevel=.02 if detail == 0 else 0.0)
        for x, tilt in ((-.13, .2), (.04, -.12), (.17, .3)):
            model.add(G.box((x, 1.25, .88), (.18, .02, .24), rot=(-.6, tilt, 0)), m["paper"])
        for side in (-1, 1):
            model.add(G.star_prism((side * .29, 1.04, .8), .11, .03, axis="x"), m["accent"])
            model.add(G.star_prism((side * .5, .58, -.98), .2, .04, axis="x"), m["accent"])
    if detail < 2:
        # Brass loops hold the two leather straps against the rear of the mailbag.
        for x in (-.16, .16):
            model.add(G.box((x, 1.08, .997), (.068, .29, .024)), m["seat"], bevel=.007 if detail == 0 else 0)
            if detail == 0:
                loop = [(x + dx, 1.08 + dy, 1.014) for dx, dy in ((-.041,-.033), (.041,-.033), (.041,.033), (-.041,.033))]
                model.add(tube(loop, .009, 6), m["accent"])
        # Postal chevrons remain visible from the chase camera on both wings.
        for side in (-1, 1):
            for x in (1.04, 1.30):
                points = [(side * (x + dx), y_at(x + dx) + .077, le_at(x + dx) + dz)
                          for dx, dz in ((0, .11), (.15, .31), (0, .51))]
                model.add(tube(points, .031, 6, closed=False), m["accent"])
    if detail == 0:
        for i in range(16):
            a = math.tau * i / 16
            model.add(G.sphere((math.cos(a) * .46, .532 + math.sin(a) * .44, -1.4), (.018, .018, .014), 6, 4), m["metal"])


def yoke(model, m, detail):
    """Local to YOKE_AT; grips at x = +-0.17."""
    seg = [14, 8][min(detail, 1)]
    model.add(G.cylinder((0, -.02, -.02), (0, -.2, -.3), .028, segments=seg), m["metal"])
    model.add(G.cylinder((-.21, 0, 0), (.21, 0, 0), .026, segments=seg), m["dark"])
    for x in (-.17, .17):
        model.add(G.cylinder((x, -.075, 0), (x, .075, 0), .034, segments=seg), m["dark"])
    model.add(G.sphere((0, 0, -.01), (.05, .05, .04), seg, 6), m["accent"])


def propeller(model, m, detail):
    """Local to PROP_AT; spins about Z."""
    for side in (-1, 1):
        sections = [((side * .05, 0, -.07), .14, .16), ((side * .5, 0, -.045), .09, .12), ((side * .6, 0, -.03), .06, .1)]
        bm = G.wing(sections if side > 0 else list(reversed(sections)), n=[8, 5][min(detail, 1)])
        bm.transform(Matrix.Rotation(-math.pi / 2 + side * .3, 4, "X"))
        model.add(bm, m["wood"])


def aileron(model, m, side):
    sections = []
    for x in AILERON:
        thick = .14 + (.1 - .14) * (x - WING_ROOT) / (WING_TIP - WING_ROOT)
        sections.append(((side * x, y_at(x), le_at(x) + chord_at(x) - AILERON_CHORD + .01), AILERON_CHORD - .01,
                         thick * .38))
    model.add(G.wing(sections if side > 0 else list(reversed(sections)), n=8), m["trim"])


def elevator(model, m):
    sections = [((-1.18, TAIL_Y + .04, 3.52), .2, .04), ((1.18, TAIL_Y + .04, 3.52), .2, .04)]
    model.add(G.wing(sections, n=8), m["trim"])


def rudder(model, m):
    model.add(G.fin([((0, .98, 3.47), .28, .05), ((0, 1.92, 3.52), .2, .04)], n=8), m["accent"])
