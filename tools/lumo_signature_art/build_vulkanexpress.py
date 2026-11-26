#!/usr/bin/env python3
"""Vulkanexpress - Feuerinsel: Wahrzeichen in Blender (bpy), alles selbst modelliert.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_signature_art/build_vulkanexpress.py [name ...]
Ausgabe: assets/kart/signature/vulkanexpress/<name>.glb mit LOD0/LOD1/LOD2 (Godot schaltet
nach Entfernung, kart_signature_environment.module) und models.json (Dreiecke je Stufe).
Koordinaten wie in Godot: Meter, +Y oben, -Z Fahrtrichtung. Bausteine: der Windwerk-Builder
(Kisten, Balken, Drehkörper, Profile) mit groberen Stufen für LOD1/LOD2.
"""
import json
import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/lumo_kart_art/karts"))
sys.path.insert(0, str(ROOT / "tools/lumo_windwerk_art"))
import build_karts as k  # noqa: E402
from build_windwerk import Builder  # noqa: E402

OUT = ROOT / "assets/kart/signature/vulkanexpress"
# name: (Farbe, Metall, Rauheit, Leuchten)
COLORS = {
    "basalt": ("3b3436", .02, .9, 0), "ash": ("6d625d", .0, .95, 0),
    "stone": ("8a7b6e", .02, .82, 0), "wood": ("8c5a36", .02, .7, 0),
    "red": ("c8402e", .25, .45, 0), "black": ("23212a", .45, .5, 0),
    "gold": ("e7b04b", .7, .3, 0), "cream": ("f1e2c2", .03, .6, 0),
    "roof": ("7a2f2a", .05, .65, 0), "lamp": ("ffc773", .0, .3, 3.0),
    "lava": ("ff7a24", .0, .4, 4.0), "crystal": ("ff8a3d", .1, .15, .7),
    "violet": ("a66cff", .1, .15, .6), "sulfur": ("e8d36a", .0, .8, 0),
    "steel": ("6e7a86", .8, .35, 0), "teal": ("2f8f8a", .2, .45, 0),
}


def cylinder_z(b, centre, radius, length, mat, n=20):
    """Liegender Zylinder entlang z (Kessel, Achsen)."""
    n = max(6, n // (b.level + 1))
    x, y, z = centre
    outline = [(x + radius * math.cos(i * math.tau / n), y + radius * math.sin(i * math.tau / n))
               for i in range(n)]
    b.face(outline, z, length, mat)


def wheel_x(b, centre, radius, width, mat, n=18):
    """Rad mit Achse entlang x."""
    n = max(6, n // (b.level + 1))
    x, y, z = centre
    verts = []
    for side in (-width * .5, width * .5):
        for i in range(n):
            a = i * math.tau / n
            verts.append((x + side, y + radius * math.sin(a), z + radius * math.cos(a)))
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b.solid(verts, faces, mat)


def crystal(b, x, z, height, radius, mat, tilt=0.0):
    rows = [(0, radius * .8), (height * .72, radius), (height, 0.02)]
    b.profile(rows, mat, x=x, z=z, n=6)


# ------------------------------------------------------------------ Modelle


def station(b):
    # Bahnsteig, Lavastein-Sockel, Empfangshaus mit Uhrturm, Dach über dem Gleis.
    b.box((0, .45, 0), (7.0, .9, 30.0), "stone")
    b.box((-.2, .95, 0), (6.4, .12, 29.6), "ash")
    b.box((2.6, 3.4, 0), (5.2, 5.0, 14.0), "cream")
    b.box((2.6, .7, 0), (5.6, 1.4, 14.4), "basalt")
    b.face([(-.6, 5.9), (2.6, 8.3), (5.8, 5.9)], 0, 15.0, "roof")
    for z in (-5.0, -1.7, 1.7, 5.0):
        b.box((-.02, 3.1, z), (.14, 1.9, 1.3), "lamp")
        if b.level < 2:
            b.box((-.06, 2.05, z), (.2, .14, 1.5), "wood")
    # Uhrturm
    b.box((2.6, 6.5, -8.4), (3.0, 13.0, 3.0), "cream")
    b.box((2.6, 13.4, -8.4), (3.5, .6, 3.5), "roof")
    b.profile([(13.6, 2.2), (16.4, .05)], "roof", x=2.6, z=-8.4, n=4)
    if b.level < 2:
        for side in (-1, 1):
            b.box((1.05, 10.9, -8.4 + side * 0.0), (.12, 1.7, 1.7), "gold")
        b.box((1.0, 10.9, -8.4), (.12, 1.3, 1.3), "cream")
    # Bahnsteigdach
    for z in range(-12, 13, 6):
        b.beam((-2.8, .9, z), (-2.8, 4.6, z), .22, .22, "black")
    b.box((-1.4, 4.75, 0), (4.4, .25, 28.0), "red")
    if b.level == 0:
        for z in range(-13, 14, 2):
            b.box((-3.55, 4.55, z), (.15, .5, .9), "gold")


def locomotive(b):
    # Kleine Dampflok: Fahrgestell, Kessel, Führerhaus, Schlot, Dom, Laterne, Räder.
    b.box((0, .95, 0), (2.4, .5, 8.6), "black")
    cylinder_z(b, (0, 2.15, -1.2), 1.05, 5.4, "red")
    for z in (-3.6, -2.0, -.4, 1.2):
        cylinder_z(b, (0, 2.15, z), 1.1, .16, "gold")
    b.box((0, 2.7, 2.7), (2.5, 3.0, 2.8), "red")
    b.box((0, 4.35, 2.7), (2.9, .3, 3.2), "black")
    if b.level < 2:
        for side in (-1, 1):
            b.box((side * 1.26, 3.2, 2.5), (.06, .9, 1.2), "lamp")
    b.profile([(3.0, .38), (4.2, .32), (4.6, .62), (4.85, .62)], "black", x=0, z=-3.3, n=14)
    b.profile([(3.0, .55), (3.5, .52), (3.75, .2)], "gold", x=0, z=-.6, n=12)
    b.box((0, 2.2, -4.0), (.7, .6, .3), "lamp")
    b.box((0, .7, -4.45), (2.6, .35, .3), "gold")
    for z, r in ((-3.0, .55), (-1.4, .78), (.4, .78), (2.2, .55)):
        for side in (-1, 1):
            wheel_x(b, (side * 1.15, r, z), r, .22, "black")
            if b.level < 2:
                wheel_x(b, (side * 1.27, r, z), r * .45, .06, "gold")
    if b.level < 2:
        for side in (-1, 1):
            b.beam((side * 1.33, .78, -1.4), (side * 1.33, .78, .4), .1, .12, "steel")


def wagon(b):
    # Offener Aussichtswagen mit Bänken und gestreiftem Sonnendach.
    b.box((0, .95, 0), (2.4, .5, 7.6), "black")
    b.box((0, 1.6, 0), (2.5, .9, 7.4), "teal")
    b.box((0, 2.08, 0), (2.6, .12, 7.5), "gold")
    for z in (-2.6, -.9, .8, 2.5):
        b.box((0, 1.75, z), (2.1, .5, .5), "wood")
    for x in (-1.15, 1.15):
        for z in (-3.5, 3.5):
            b.beam((x, 2.1, z), (x, 3.7, z), .12, .12, "gold")
    for i in range(6 if b.level < 2 else 2):
        b.box((-1.25 + i * .5 if b.level < 2 else 0, 3.8, 0),
              (.5 if b.level < 2 else 2.8, .12, 7.6), "red" if i % 2 == 0 else "cream")
    for z in (-2.6, 2.6):
        for side in (-1, 1):
            wheel_x(b, (side * 1.15, .55, z), .55, .2, "black")


def bridge_tower(b):
    # Torbogen der Hängebrücke: zwei Lavastein-Türme, Holzjoch, Laternen.
    for side in (-1, 1):
        x = side * 8.4
        b.box((x, 6.0, 0), (2.4, 12.0, 2.4), "stone")
        b.box((x, .8, 0), (3.2, 1.6, 3.2), "basalt")
        b.box((x, 12.3, 0), (2.9, .6, 2.9), "basalt")
        b.profile([(12.6, 1.6), (14.6, .1)], "roof", x=x, z=0, n=4)
        if b.level < 2:
            for y in (3.0, 6.0, 9.0):
                b.box((x, y, 0), (2.5, .16, 2.5), "basalt")
            b.box((x - side * 1.25, 9.5, 0), (.2, .8, .6), "lamp")
    b.box((0, 10.6, 0), (19.2, 1.0, 1.1), "wood")
    b.box((0, 11.3, 0), (17.0, .3, 1.3), "red")
    if b.level < 2:
        for x in (-4.0, 0.0, 4.0):
            b.beam((x, 10.1, 0), (x, 8.9, 0), .06, .06, "black")
            b.box((x, 8.6, 0), (.5, .6, .5), "lamp")


def crystal_cluster(b):
    shards = [(0, 0, 6.0, .9), (1.4, .6, 4.2, .7), (-1.2, .9, 4.8, .75), (.5, -1.3, 3.6, .6),
              (-.9, -1.1, 3.0, .55), (2.2, -.6, 2.4, .45), (-2.1, -.2, 2.0, .4)]
    for i, (x, z, h, r) in enumerate(shards if b.level < 2 else shards[:4]):
        crystal(b, x, z, h, r, "crystal" if i % 3 else "violet")
    b.profile([(0, 3.0), (.6, 2.4), (1.0, .2)], "basalt", n=10)


def basalt_columns(b):
    cols = [(0, 0, 5.5), (1.05, .6, 4.2), (-1.05, .6, 4.8), (0, 1.2, 3.6), (1.05, -.6, 3.2),
            (-1.05, -.6, 6.2), (0, -1.2, 4.4), (2.1, 0, 2.6), (-2.1, 0, 3.0)]
    for x, z, h in cols if b.level < 2 else cols[:5]:
        b.profile([(0, .62), (h, .62), (h + .05, .5)], "basalt", x=x, z=z, n=6)
    if b.level == 0:
        for x, z, h in cols[:4]:
            b.profile([(h + .02, .3), (h + .12, .25)], "lava", x=x, z=z, n=6)


def geyser_vent(b):
    b.profile([(0, 3.2), (.6, 2.6), (1.2, 1.2), (1.25, .8), (.9, .55)], "ash", n=16)
    b.profile([(1.18, 1.2), (1.32, 1.0), (1.26, .8)], "sulfur", n=16)
    b.profile([(.7, .55), (.95, .5)], "lava", n=12)
    if b.level < 2:
        for i in range(5):
            a = i * math.tau / 5
            b.profile([(0, .5), (.5, .3), (.7, .05)], "sulfur", x=math.cos(a) * 2.4, z=math.sin(a) * 2.4, n=6)


def tunnel_portal(b):
    # Felsportal: Pfeiler und ein Bogen aus Lavasteinen, Fackeln, Schlussstein.
    inner, height = 8.6, 8.2
    for side in (-1, 1):
        b.box((side * (inner + 1.4), height * .5 - .5, 0), (2.8, height + 1.0, 3.2), "basalt")
        if b.level < 2:
            b.box((side * (inner - .1), 4.0, -1.7), (.25, .9, .25), "lamp")
    steps = 13 if b.level == 0 else (7 if b.level == 1 else 5)
    for i in range(steps):
        a0 = math.pi * i / steps
        a1 = math.pi * (i + 1) / steps
        p = (math.cos(a0) * (inner + 1.2), height + math.sin(a0) * 3.4, 0)
        q = (math.cos(a1) * (inner + 1.2), height + math.sin(a1) * 3.4, 0)
        b.beam(p, q, 2.6, 3.2, "stone" if i % 2 else "basalt")
    b.box((0, height + 3.6, -1.5), (2.2, 1.6, .5), "gold")
    b.box((0, height + 4.4, 0), (24.0, 3.0, 3.4), "basalt")


def stone_arch(b):
    # Steinbogen unter der Lavastrom-Brücke (Bogenachse quer zur Fahrbahn: entlang x).
    span, rise = 11.0, 5.0
    for side in (-1, 1):
        b.box((side * (span * .5 + 1.6), -4.0, 0), (3.2, 10.0, 15.0), "stone")
    steps = 11 if b.level == 0 else 6
    for i in range(steps):
        a0, a1 = math.pi * i / steps, math.pi * (i + 1) / steps
        p = (math.cos(a0) * span * .5, -rise + math.sin(a0) * rise, 0)
        q = (math.cos(a1) * span * .5, -rise + math.sin(a1) * rise, 0)
        b.beam(p, q, 1.4, 15.0, "stone" if i % 2 else "basalt")
    b.box((0, -.5, 0), (span + 6.4, 1.0, 15.0), "stone")


MODELS = {
    "station": station, "locomotive": locomotive, "wagon": wagon,
    "bridge_tower": bridge_tower, "crystal_cluster": crystal_cluster,
    "basalt_columns": basalt_columns, "geyser_vent": geyser_vent,
    "tunnel_portal": tunnel_portal, "stone_arch": stone_arch,
}


def build(name, report):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {key: k.material("Vulkan_" + key, c, metal, rough, emission)
            for key, (c, metal, rough, emission) in COLORS.items()}
    root = k.empty("Vulkan_" + name)
    triangles = []
    for level in range(3):
        group = k.empty("Static" + str(level), parent=root)
        builder = Builder(group, level, mats)
        MODELS[name](builder)
        mesh = builder.finish("LOD" + str(level))
        triangles.append(sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in k.descendants(root):
        o.select_set(True)
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_animations=False)
    report[name] = {"triangles": triangles, "bytes": path.stat().st_size}
    print("VULKAN MODEL", name, triangles, path.stat().st_size, flush=True)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in MODELS] or list(MODELS)
    manifest = OUT / "models.json"
    report = json.loads(manifest.read_text()) if manifest.exists() else {}
    for model in names:
        build(model, report)
    manifest.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
