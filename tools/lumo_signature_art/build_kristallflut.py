#!/usr/bin/env python3
"""Kristallflut - versunkene Abenteuerwelt: Wahrzeichen in Blender (bpy), alles selbst modelliert.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_signature_art/build_kristallflut.py [name ...]
Ausgabe: assets/kart/signature/kristallflut/<name>.glb mit LOD0/LOD1/LOD2 und models.json.
Koordinaten wie in Godot: Meter, +Y oben, -Z Fahrtrichtung. Bausteine: Windwerk-Builder.
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

OUT = ROOT / "assets/kart/signature/kristallflut"
COLORS = {
    "hull": ("2f5f7a", .1, .5, 0), "plank": ("a8794e", .02, .7, 0), "sail": ("f4efe2", .0, .8, 0),
    "red": ("d2553f", .1, .5, 0), "white": ("f2f0ea", .05, .5, 0), "stone": ("a9b3a6", .02, .85, 0),
    "moss": ("5f8f5a", .0, .9, 0), "teal": ("3fd8d0", .1, .15, 1.4), "aqua": ("7ff5ff", .1, .1, 1.8),
    "gold": ("e9c25a", .6, .3, 0), "lamp": ("fff1b0", .0, .3, 3.0), "metal": ("7d8f9c", .7, .35, 0),
    "coral": ("ff7f8a", .0, .6, .2), "coral2": ("ffb35c", .0, .6, .2), "sand": ("d8c79a", .0, .9, 0),
    "dark": ("27313a", .3, .5, 0),
}


def loft(b, sections, mat, deck_mat=None):
    """Rumpf aus Querschnitten [(z, halbe Breite, Boden y, Deck y)]: Seiten, Boden, Deck."""
    verts = []
    for z, half, bottom, top in sections:
        verts += [(-half, top, z), (half, top, z), (half * .55, bottom, z), (-half * .55, bottom, z)]
    faces = []
    for i in range(len(sections) - 1):
        a, c = i * 4, (i + 1) * 4
        faces += [(a, c, c + 3, a + 3), (a + 1, a + 2, c + 2, c + 1), (a + 2, a + 3, c + 3, c + 2)]
    b.solid(verts, faces, mat)
    deck = [(x, y + .02, z) for x, y, z in verts[0::4]] + [(x, y + .02, z) for x, y, z in verts[1::4]]
    n = len(sections)
    b.solid(deck, [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)], deck_mat or mat)


def ship(b):
    # Abenteuerschiff am Anleger: Rumpf, Deck, zwei Masten mit Segeln, Laternen.
    sections = [(-11.0, .2, 2.2, 3.4), (-8.0, 2.4, .6, 3.0), (-3.0, 3.4, 0, 2.8), (3.0, 3.4, 0, 2.8),
                (7.0, 3.0, .3, 3.2), (9.5, 2.2, .8, 4.2)]
    loft(b, sections, "hull", "plank")
    b.box((0, 2.95, 9.3), (4.2, 2.0, 1.4), "plank")
    for z, h in ((-2.5, 14.0), (4.0, 11.0)):
        b.beam((0, 2.8, z), (0, 2.8 + h, z), .4, .4, "plank")
        b.beam((-3.6, 2.8 + h * .8, z), (3.6, 2.8 + h * .8, z), .22, .22, "plank")
        rows = 3 if b.level < 2 else 1
        for r in range(rows):
            y0 = 4.0 + r * (h * .7 / rows)
            b.box((0, y0 + h * .35 / rows, z + .3), (6.6 - r * .8, h * .7 / rows - .3, .12),
                  "sail" if r % 2 == 0 or b.level == 2 else "red")
    b.box((0, 3.0, -10.6), (.3, .3, 3.0), "plank")
    if b.level < 2:
        for z in (-6.0, 0.0, 6.0):
            for side in (-1, 1):
                b.box((side * 3.3, 3.4, z), (.3, .5, .3), "lamp")
        b.box((0, 3.2, -8.5), (1.2, .8, 1.2), "gold")


def lighthouse(b):
    rows = [(0, 3.4), (2, 3.0), (18, 2.0), (19, 2.6), (19.6, 2.6)]
    b.profile(rows, "white", n=20)
    for y in (3.5, 8.5, 13.5):
        b.profile([(y, 3.0 - y * .055), (y + 2.5, 2.9 - (y + 2.5) * .055)], "red", n=20)
    b.profile([(19.6, 1.7), (22.4, 1.7)], "lamp", n=14)
    b.profile([(22.4, 2.2), (23.4, 1.4), (24.6, .1)], "red", n=14)
    b.profile([(0, 5.0), (1.0, 4.6)], "stone", n=20)


def ruin_arch(b):
    # Versunkenes Tor: zwei kannelierte Säulen, Sturz, abgebrochene Kante, Moos.
    for side in (-1, 1):
        x = side * 5.0
        b.profile([(0, 1.3), (.8, 1.1), (8.5, .95), (9.0, 1.25)], "stone", x=x, n=16)
        b.box((x, 9.4, 0), (2.8, .8, 2.8), "stone")
        if b.level < 2:
            b.profile([(1.0, 1.14), (2.2, 1.12)], "moss", x=x, n=16)
    b.box((-.8, 10.4, 0), (11.0, 1.4, 2.4), "stone")
    b.box((4.4, 11.4, 0), (2.0, .7, 2.2), "stone")
    if b.level < 2:
        b.box((-2.0, 11.2, .3), (4.0, .3, 1.8), "moss")
        for x in (-3.0, 0.0, 3.0):
            b.box((x, 10.4, 1.25), (.9, .9, .12), "gold")


def ruin_column(b):
    b.profile([(0, 1.5), (.7, 1.25), (5.5, 1.0), (6.2, .9), (6.6, .3)], "stone", n=14)
    if b.level < 2:
        b.profile([(.6, 1.3), (1.8, 1.26)], "moss", n=14)
        b.box((1.6, .4, 1.2), (1.6, .8, 1.2), "stone")


def crystal_spire(b):
    shards = [(0, 0, 9.0, 1.4), (1.8, .8, 6.5, 1.0), (-1.6, 1.1, 7.2, 1.1), (.6, -1.8, 5.0, .9),
              (-1.2, -1.4, 4.2, .8), (2.6, -.6, 3.4, .6), (-2.6, -.2, 3.0, .5)]
    for i, (x, z, h, r) in enumerate(shards if b.level < 2 else shards[:4]):
        b.profile([(0, r * .8), (h * .74, r), (h, .03)], "aqua" if i % 3 == 0 else "teal", x=x, z=z, n=6)
    b.profile([(0, 3.6), (.8, 3.0), (1.2, .4)], "stone", n=10)


def fountain(b):
    b.profile([(0, 4.6), (.9, 4.6), (1.0, 4.2), (.4, 4.0)], "stone", n=24)
    b.profile([(.4, 4.0), (.45, .1)], "dark", n=24)
    b.profile([(0, 1.0), (2.6, .7), (2.8, 1.6), (3.2, 1.5), (3.3, .3)], "stone", n=16)
    if b.level < 2:
        for i in range(6):
            a = i * math.tau / 6
            b.box((math.cos(a) * 4.3, 1.15, math.sin(a) * 4.3), (.5, .3, .5), "gold")


def tunnel_ring(b):
    # Stahlrippe des Unterwassertunnels (Innenradius 8,6 m), Leuchtband innen.
    steps = 16 if b.level == 0 else (10 if b.level == 1 else 6)
    for i in range(steps):
        a0, a1 = math.pi * i / steps, math.pi * (i + 1) / steps
        for r, mat, wdt, dep in ((9.0, "metal", .55, .9), (8.7, "aqua", .14, .3)):
            p = (math.cos(a0) * r, math.sin(a0) * r * 1.05, 0)
            q = (math.cos(a1) * r, math.sin(a1) * r * 1.05, 0)
            b.beam(p, q, wdt, dep, mat)
    for side in (-1, 1):
        b.box((side * 9.0, -.6, 0), (1.0, 1.2, 1.0), "metal")


def coral(b):
    stems = [(0, 0, 3.2, .45, "coral"), (1.1, .6, 2.4, .35, "coral2"), (-1.0, .8, 2.8, .4, "coral"),
             (.4, -1.0, 2.0, .3, "coral2"), (-.8, -.8, 1.6, .3, "teal")]
    for x, z, h, r, mat in stems if b.level < 2 else stems[:3]:
        b.profile([(0, r), (h * .6, r * .8), (h, r * 1.3), (h + .2, .05)], mat, x=x, z=z, n=8)
    b.profile([(0, 2.2), (.5, 1.6), (.7, .2)], "sand", n=10)


def pier_gate(b):
    # Anleger-Torbogen über der Startgeraden: Holzpfosten, Querbalken, Laternen.
    for side in (-1, 1):
        x = side * 9.2
        b.beam((x, -2.0, 0), (x, 9.0, 0), 1.0, 1.0, "plank")
        b.box((x, 9.4, 0), (1.4, .8, 1.4), "dark")
        if b.level < 2:
            b.box((x - side * .9, 6.0, 0), (.4, .7, .4), "lamp")
    b.box((0, 8.6, 0), (20.0, 1.2, .9), "plank")
    b.box((0, 9.5, 0), (18.0, .5, 1.1), "hull")


MODELS = {
    "ship": ship, "lighthouse": lighthouse, "ruin_arch": ruin_arch, "ruin_column": ruin_column,
    "crystal_spire": crystal_spire, "fountain": fountain, "tunnel_ring": tunnel_ring,
    "coral": coral, "pier_gate": pier_gate,
}


def build(name, report):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {key: k.material("Flut_" + key, c, metal, rough, emission)
            for key, (c, metal, rough, emission) in COLORS.items()}
    root = k.empty("Flut_" + name)
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
    print("FLUT MODEL", name, triangles, path.stat().st_size, flush=True)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in MODELS] or list(MODELS)
    manifest = OUT / "models.json"
    report = json.loads(manifest.read_text()) if manifest.exists() else {}
    for model in names:
        build(model, report)
    manifest.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
