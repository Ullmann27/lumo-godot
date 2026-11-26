#!/usr/bin/env python3
"""Wolkensturm - Himmelsmetropole: Wahrzeichen in Blender (bpy), alles selbst modelliert.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_signature_art/build_wolkensturm.py [name ...]
Ausgabe: assets/kart/signature/wolkensturm/<name>.glb mit LOD0/LOD1/LOD2 und models.json.
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
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_karts as k  # noqa: E402
from build_windwerk import Builder  # noqa: E402
from build_vulkanexpress import cylinder_z  # noqa: E402

OUT = ROOT / "assets/kart/signature/wolkensturm"
COLORS = {
    "white": ("eef3fb", .1, .4, 0), "steel": ("8794a8", .75, .3, 0),
    "dark": ("1e2638", .5, .4, 0), "glass": ("6fb4e8", .4, .08, .25),
    "cyan": ("5ff0ff", .0, .3, 2.2), "pink": ("ff4fd8", .0, .3, 2.2),
    "gold": ("ffcf5a", .6, .3, 1.2), "yellow": ("ffd23a", .2, .35, 0),
    "rock": ("7d7a8a", .02, .9, 0), "grass": ("7bc96a", .0, .8, 0),
    "window": ("ffe7b0", .0, .3, 1.4), "violet": ("8a6bff", .1, .3, 0),
}


def tower(b, height, width, depth, bands, crown):
    """Hochhaus mit Rücksprüngen, Fensterbändern und Leuchtkrone."""
    y = 0.0
    w, d = width, depth
    for step in range(3):
        h = height * (.5, .3, .2)[step]
        b.box((0, y + h * .5, 0), (w, h, d), "white" if step % 2 == 0 else "steel")
        rows = max(1, int(h / 3.2)) if b.level == 0 else max(1, int(h / 6.4)) if b.level == 1 else 0
        for r in range(rows):
            yy = y + (r + .5) * h / rows
            b.box((0, yy, 0), (w + .12, .9 if b.level == 0 else 1.8, d + .12), "glass")
        y += h
        w, d = w * .78, d * .78
    b.box((0, y + .3, 0), (w * 1.1, .6, d * 1.1), "dark")
    b.box((0, y + .9, 0), (w * 1.12, .25, d * 1.12), crown)
    b.beam((0, y, 0), (0, y + height * .16, 0), .5, .5, "steel")
    b.box((0, y + height * .16, 0), (1.0, 1.0, 1.0), crown)


def sky_tower(b):
    tower(b, 64.0, 16.0, 16.0, 3, "cyan")


def sky_tower_b(b):
    tower(b, 82.0, 13.0, 18.0, 3, "pink")
    for side in (-1, 1):
        b.box((side * 7.0, 40.0, 0), (.4, 60.0, .4), "cyan")


def star_tower(b):
    # Sternenturm: schlanker Schaft, Ringe, Stern als Krone (Mitte der Spirale).
    b.profile([(0, 20.0), (8, 16.0), (30, 12.0), (90, 9.0), (120, 7.0), (126, 9.0), (130, .5)],
              "white", n=24)
    for y in (24, 48, 72, 96):
        b.profile([(y, 13.0 - y * .045), (y + 1.2, 13.0 - y * .045)], "cyan", n=24)
    star = []
    n = 5
    for i in range(2 * n):
        r = 9.0 if i % 2 == 0 else 3.8
        a = math.pi / 2 + i * math.pi / n
        star.append((math.cos(a) * r, 140 + math.sin(a) * r))
    b.face(star, 0, 1.6, "gold")
    b.beam((0, 128, 0), (0, 134, 0), .8, .8, "steel")


def air_taxi(b):
    # Schwebetaxi: gelber Rumpf, Glaskuppel, vier leuchtende Schwebedüsen.
    cylinder_z(b, (0, 1.5, 0), 1.15, 4.6, "yellow")
    b.box((0, 1.0, 0), (2.4, .7, 4.4), "yellow")
    b.profile([(1.9, 1.0), (2.6, .9), (3.0, .2)], "glass", x=0, z=.2, n=14)
    b.box((0, 1.45, -2.35), (2.0, .5, .12), "dark")
    b.box((0, 1.45, -2.42), (1.2, .2, .06), "window")
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.profile([(.2, .55), (.6, .5), (.65, .3)], "dark", x=sx * 1.35, z=sz * 1.7, n=10)
            b.profile([(.1, .4), (.2, .4)], "cyan", x=sx * 1.35, z=sz * 1.7, n=10)
    b.box((0, 2.75, .8), (1.6, .4, .8), "dark")
    b.box((0, 2.98, .8), (1.3, .12, .5), "window")


def floating_platform(b):
    # Schwebende Plattform: Landefeld mit Lichtern auf einem Felsbrocken.
    b.profile([(-9, .4), (-6, 4.0), (-2, 9.0), (0, 10.5), (.6, 10.5)], "rock", n=20)
    b.profile([(.6, 10.2), (.9, 10.0)], "grass", n=20)
    b.profile([(.95, 7.0), (1.05, 7.0)], "dark", n=20)
    if b.level < 2:
        for i in range(8):
            a = i * math.tau / 8
            b.box((math.cos(a) * 8.6, 1.2, math.sin(a) * 8.6), (.4, .3, .4), "cyan")
        b.box((0, 1.1, 0), (4.0, .08, .6), "white")
        b.box((0, 1.1, 0), (.6, .08, 4.0), "white")


def holo_pylon(b):
    b.profile([(0, .9), (.4, .7), (6.5, .35), (7.0, .6), (7.4, .1)], "steel", n=12)
    for y in (1.6, 3.4, 5.2):
        b.profile([(y, .75), (y + .25, .75)], "cyan" if y < 3 else "pink", n=16)


def wind_rotor(b):
    # Vertikales Windrad (Rotor dreht in Godot um y).
    b.profile([(0, 1.6), (1.0, 1.2), (24, .6), (25, .9)], "steel", n=12)
    for i in range(3):
        a = i * math.tau / 3
        for seg in range(8 if b.level == 0 else 4):
            t0, t1 = seg / (8 if b.level == 0 else 4), (seg + 1) / (8 if b.level == 0 else 4)
            p = (math.cos(a + t0 * 1.2) * 4.0, 6 + t0 * 16, math.sin(a + t0 * 1.2) * 4.0)
            q = (math.cos(a + t1 * 1.2) * 4.0, 6 + t1 * 16, math.sin(a + t1 * 1.2) * 4.0)
            b.beam(p, q, .3, 1.4, "white")
        b.beam((0, 8, 0), (math.cos(a) * 4.0, 8, math.sin(a) * 4.0), .25, .25, "steel")
        b.beam((0, 20, 0), (math.cos(a + 1.0) * 4.0, 20, math.sin(a + 1.0) * 4.0), .25, .25, "steel")


def lobby_hall(b):
    # Glashalle über der Lobby-Abkürzung: Stützen, Dach, Leuchtbänder (9 m breit, 32 m lang).
    for z in range(-16, 17, 8):
        for x in (-4.8, 4.8):
            b.box((x, 3.6, z), (.5, 7.2, .5), "steel")
    b.box((0, 7.5, 0), (10.4, .5, 33.0), "dark")
    b.box((0, 7.15, 0), (9.0, .1, 32.0), "cyan")
    if b.level < 2:
        for z in range(-14, 15, 4):
            b.box((0, 7.0, z), (8.6, .12, .3), "pink" if z % 8 == 0 else "cyan")
        for x in (-4.8, 4.8):
            b.box((x, .5, 0), (.3, 1.0, 32.0), "steel")
            b.box((x, 1.05, 0), (.34, .1, 32.0), "cyan")


def sky_portal(b):
    # Leuchtring-Portal (Glastunnel-Einfahrt, Starttor): 16 m Durchfahrt.
    steps = 20 if b.level == 0 else (10 if b.level == 1 else 6)
    for i in range(steps):
        a0, a1 = math.pi * i / steps, math.pi * (i + 1) / steps
        for r, mat, wdt in ((9.6, "white", 1.2), (8.9, "cyan", .3)):
            p = (math.cos(a0) * r, math.sin(a0) * r * 1.05, 0)
            q = (math.cos(a1) * r, math.sin(a1) * r * 1.05, 0)
            b.beam(p, q, wdt, 1.4 if mat == "white" else .6, mat)
    for side in (-1, 1):
        b.box((side * 9.6, -1.0, 0), (1.6, 2.0, 1.8), "steel")


def island_rock(b):
    # Fels einer schwebenden Insel (40 m Radius), Gras oben, Kristallspitzen unten.
    rows = [(-46, .5), (-36, 8), (-24, 20), (-12, 32), (-4, 39), (0, 41), (.8, 40)]
    b.profile(rows, "rock", n=28)
    b.profile([(.8, 40.0), (1.4, 38.5)], "grass", n=28)
    if b.level < 2:
        for i in range(6):
            a = i * math.tau / 6 + .3
            b.profile([(-30, .2), (-24, 2.6), (-16, 3.0)], "violet",
                      x=math.cos(a) * 14, z=math.sin(a) * 14, n=6)


MODELS = {
    "sky_tower": sky_tower, "sky_tower_b": sky_tower_b, "star_tower": star_tower,
    "air_taxi": air_taxi, "floating_platform": floating_platform, "holo_pylon": holo_pylon,
    "wind_rotor": wind_rotor, "lobby_hall": lobby_hall, "sky_portal": sky_portal,
    "island_rock": island_rock,
}


def build(name, report):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {key: k.material("Wolken_" + key, c, metal, rough, emission)
            for key, (c, metal, rough, emission) in COLORS.items()}
    root = k.empty("Wolken_" + name)
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
    print("WOLKEN MODEL", name, triangles, path.stat().st_size, flush=True)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in MODELS] or list(MODELS)
    manifest = OUT / "models.json"
    report = json.loads(manifest.read_text()) if manifest.exists() else {}
    for model in names:
        build(model, report)
    manifest.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
