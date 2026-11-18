#!/usr/bin/env python3
"""Dorfwelt Teil 3: Schutzbauten, Gegner-Lager und Figuren der Angriffe (Eigenbau).

Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/build_defense_models.py [--only castle_wall]

Uses the same Builder, atlas tiles and GLB export as build_village_models.py,
so every piece is drawn by the shared village shader (usually one draw call).
Kindgerecht: no weapons with blades; guards carry foam-tipped poles and
shields, the robbers are cheeky raccoons with sacks, the dragon is round and
friendly. Moving parts are child objects named Spin_* (animated in Godot).
Coordinates in Godot convention (Y up, front = +Z), footprint centre = origin.
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


def merlons(b, length, y, depth, color="b9b1a2", step=1.0, z=0.0):
    count = int(round(length / step))
    for i in range(count):
        x = -length / 2 + step * (i + 0.5)
        if i % 2 == 0:
            b.box((x, y + 0.3, z), (step * 0.92, 0.6, depth), "stone_wall", color)


def model_palisade(b):
    """Holzpalisade, 5 m along X: pointed stakes, cross rails, walkway posts."""
    for i in range(12):
        x = -2.3 + i * 0.42
        h = 2.2 + 0.18 * math.sin(i * 1.7)
        b.cylinder((x, h / 2, 0), 0.2, h, 7, "bark", "ffffff")
        b.cone((x, h, 0), 0.2, 0.42, 7, "planks", "c49a6a")
    for y in (0.7, 1.6):
        b.box((0, y, -0.24), (5.0, 0.16, 0.08), "beam", "6b4a2f")
    for x in (-2.0, 0.0, 2.0):
        b.push((x, 0.9, -0.55), rot_x=0.45)
        b.box((0, 0, 0), (0.14, 1.9, 0.14), "beam", "6b4a2f")
        b.pop()


def model_castle_wall(b):
    """Steinmauer, 5 m along X: battered base, walkway, crenellations, buttresses."""
    b.box((0, 0.35, 0), (5.04, 0.7, 1.5), "stone_wall", "a39b8c", bottom=False)
    b.box((0, 1.6, 0), (5.02, 2.1, 1.15), "stone_wall", "c3bbab", bottom=False)
    b.box((0, 2.72, 0), (5.04, 0.14, 1.3), "cobble", "b1a998")
    merlons(b, 5.0, 2.79, 0.34, z=0.5)
    merlons(b, 5.0, 2.79, 0.3, color="aea696", z=-0.5)
    for x in (-1.6, 1.6):
        b.box((x, 0.9, 0.7), (0.6, 1.8, 0.5), "stone_wall", "b3ab9c")
    b.box((0, 1.4, 0.58), (0.18, 0.5, 0.02), "plain", "2b2622")


def model_wall_tower(b):
    """Runder Mauerturm: stone drum, arrow slits, crenellated top, slate cone, flag."""
    b.cylinder((0, 0.5, 0), 2.1, 1.0, 14, "stone_wall", "a39b8c", r_top=1.95)
    b.cylinder((0, 3.4, 0), 1.9, 4.8, 14, "stone_wall", "c6beae")
    b.cylinder((0, 5.9, 0), 2.2, 0.3, 14, "stone_wall", "aea696")
    for i in range(10):
        a = i / 10 * math.tau
        b.push((math.cos(a) * 1.95, 6.35, math.sin(a) * 1.95), rot_y=-a + math.pi / 2)
        b.box((0, 0, 0), (0.7, 0.6, 0.35), "stone_wall", "b9b1a2")
        b.pop()
    for i, y in enumerate((2.4, 4.2)):
        for k in range(4):
            a = k / 4 * math.tau + i * 0.4
            b.push((math.cos(a) * 1.91, y, math.sin(a) * 1.91), rot_y=-a + math.pi / 2)
            b.panel((0, 0, 0), 0.22, 0.7, "plain", "2b2622")
            b.pop()
    b.door((0, 0.05, 1.86), w=0.9, h=1.6, lamp=False, step=False)
    b.cylinder((0, 6.6, 0), 1.6, 0.6, 12, "beam", "6b4a2f", caps=False)
    b.cone((0, 6.9, 0), 2.0, 2.6, 14, "roof_slate", "6b7f9a")
    b.cylinder((0, 10.0, 0), 0.04, 1.4, 4, "metal", "3a3a3a")
    b.box((0.42, 10.4, 0), (0.8, 0.46, 0.02), "cloth", "38b6c9", wave=0.9)
    b.blob((0, 9.55, 0), (0.12, 0.12, 0.12), "plain", "ffd25a", subdiv=1, seed=3, jitter=0.0)


def model_gatehouse(b):
    """Torhaus: two square towers, arch with portcullis; Spin_Bridge = Zugbrücke."""
    for s in (-1, 1):
        b.box((s * 2.4, 2.4, 0), (2.0, 4.8, 2.2), "stone_wall", "c6beae", bottom=False)
        b.box((s * 2.4, 5.0, 0), (2.3, 0.3, 2.5), "stone_wall", "aea696")
        b.pyramid_roof((s * 2.4, 5.15, 0), 2.1, 2.3, 1.6, tile="roof_clay", color="c96a4a")
        b.panel((s * 2.4, 3.4, 1.11), 0.3, 0.8, "plain", "2b2622")
    b.box((0, 4.1, 0), (2.9, 1.4, 2.0), "stone_wall", "bdb5a6")
    merlons(b, 2.8, 4.8, 0.3, z=0.9)
    b.box((0, 3.25, 1.02), (2.9, 0.3, 0.12), "beam", "6b4a2f")
    for i in range(6):
        b.box((-1.15 + i * 0.46, 2.45, 0.6), (0.08, 1.4, 0.08), "metal", "3a3f46")
    b.box((0, 2.9, 0.6), (2.6, 0.08, 0.08), "metal", "3a3f46")
    b.box((0, 0.02, 0), (2.8, 0.04, 2.2), "cobble", "b1a998")
    b.box((0, 4.3, 1.05), (0.9, 0.9, 0.06), "cloth", "38b6c9")
    b.blob((0, 4.3, 1.1), (0.25, 0.25, 0.04), "plain", "ffd25a", subdiv=1, seed=5, jitter=0.0)
    for s in (-1, 1):
        b.cylinder((s * 1.3, 3.0, 1.2), 0.03, 2.6, 4, "metal", "4a4a4a", axis="y")


def model_gatehouse_bridge(b):
    """Zugbrücke: hinge at origin, deck lies along +Z when lowered (rotate about X)."""
    b.box((0, 0.08, 1.6), (2.6, 0.16, 3.2), "planks", "a87a4e")
    for z in (0.4, 1.6, 2.8):
        b.box((0, 0.18, z), (2.6, 0.06, 0.16), "beam", "6b4a2f")
    for s in (-1, 1):
        b.box((s * 1.25, 0.2, 1.6), (0.1, 0.12, 3.2), "metal", "3a3f46")


def model_moat(b):
    """Wassergraben, 5 m along X, 3 m wide: earth banks, stones, rippling water."""
    b.box((0, -0.45, 0), (5.04, 0.1, 2.4), "plain", "3f8fae", wave=0.6)
    for s in (-1, 1):
        q = [(-2.52, 0.05, s * 1.5), (2.52, 0.05, s * 1.5), (2.52, -0.6, s * 1.1), (-2.52, -0.6, s * 1.1)]
        b.face(q if s < 0 else q[::-1], "cobble", "8c7b62")
        for i in range(4):
            b.blob((-1.9 + i * 1.25, -0.05, s * 1.35), (0.28, 0.16, 0.22), "stone_wall", "9a9284", subdiv=1,
                   seed=40 + i + (s + 1) * 5, jitter=0.25, flat_bottom=True)
    for i in range(3):
        b.cylinder((-1.6 + i * 1.6, -0.1, 1.2), 0.03, 0.6, 4, "leaves", "6f9a3e", wave=0.8)


def model_net_trap(b):
    """Netzfalle: tripod with a rolled net, a rope and a honey pot as bait."""
    for i in range(3):
        a = i / 3 * math.tau
        b.push((math.cos(a) * 0.55, 0.9, math.sin(a) * 0.55), rot_y=-a)
        b.push((0, 0, 0), rot_z=0.32)
        b.box((0, 0, 0), (0.08, 1.9, 0.08), "beam", "8a6a4a")
        b.pop()
        b.pop()
    b.blob((0, 1.75, 0), (0.42, 0.24, 0.42), "cloth", "d8c8a0", subdiv=1, seed=9, jitter=0.15)
    b.cylinder((0, 1.1, 0), 0.015, 1.2, 4, "plain", "c9b38a")
    b.cylinder((0, 0.17, 0), 0.2, 0.34, 9, "plain", "e8a33a", r_top=0.14)
    b.cylinder((0, 0.36, 0), 0.15, 0.06, 9, "cloth", "f2e6cc")
    for i in range(8):
        a = i / 8 * math.tau
        b.box((math.cos(a) * 0.9, 0.02, math.sin(a) * 0.9), (0.3, 0.04, 0.04), "cloth", "c9b38a", rot_y=-a)


def model_robber_camp(b):
    """Krummzahns Lager: patched tents, fire, loot pile, banner, lookout ladder."""
    for x, z, rot, col in ((-2.8, -1.4, 0.35, "7d6a8c"), (2.4, -2.2, -0.4, "6d7f5a")):
        b.push((x, 0, z), rot)
        w, d, h = 2.6, 2.8, 2.0
        for side in (-1, 1):
            q = [(side * w / 2, 0.02, d / 2), (side * w / 2, 0.02, -d / 2), (0, h, -d / 2), (0, h, d / 2)]
            b.face(q if side > 0 else q[::-1], "cloth", col)
            q2 = [(side * w / 2 * 0.98, 0.02, -d / 2), (side * w / 2 * 0.98, 0.02, d / 2), (0, h * 0.98, d / 2),
                  (0, h * 0.98, -d / 2)]
            b.face(q2 if side > 0 else q2[::-1], "cloth", "5a4a4a")
        b.face([(-w / 2, 0.02, -d / 2), (w / 2, 0.02, -d / 2), (0, h, -d / 2)][::-1], "cloth", col)
        b.face([(-w / 2, 0.02, d / 2), (-0.3, 0.02, d / 2), (0, h, d / 2)], "cloth", col)
        b.face([(0.3, 0.02, d / 2), (w / 2, 0.02, d / 2), (0, h, d / 2)], "cloth", col)
        b.box((0.5, 1.0, d / 2 + 0.01), (0.5, 0.4, 0.02), "cloth", "e9c46a")
        b.box((0, h + 0.05, 0), (0.08, 0.08, d + 0.3), "beam", "6b4a2f")
        b.pop()
    for i in range(10):
        a = i / 10 * math.tau
        b.blob((math.cos(a) * 0.6, 0.1, 1.2 + math.sin(a) * 0.6), (0.17, 0.12, 0.15), "stone_wall", "8a8274",
               subdiv=1, seed=500 + i, jitter=0.25, flat_bottom=True)
    b.cone((0, 0.12, 1.2), 0.32, 0.8, 7, "plain", "ff8a2a", wave=0.5)
    b.cone((0, 0.12, 1.2), 0.18, 0.6, 6, "plain", "ffe066", wave=0.6)
    for i in range(5):
        b.blob((-0.6 + i * 0.35, 0.35, -3.6 + (i % 2) * 0.3), (0.32, 0.38, 0.3), "cloth", "c9a874", subdiv=2,
               seed=520 + i, jitter=0.1, flat_bottom=True)
    b.crate((0.9, 0.0, -3.4), 0.5, color="8a5a33", rot=0.3)
    b.crate((1.3, 0.0, -3.9), 0.45, color="8a5a33")
    b.barrel((-1.2, 0.0, -3.0))
    b.cylinder((3.8, 2.4, 1.5), 0.08, 4.8, 6, "beam", "6b4a2f")
    b.box((4.45, 4.3, 1.5), (1.3, 0.9, 0.03), "cloth", "3b3550", wave=0.9)
    b.box((4.45, 4.3, 1.52), (0.9, 0.24, 0.02), "plain", "f2ead8", wave=0.9)
    for s in (-1, 1):
        b.blob((4.45 + s * 0.24, 4.3, 1.535), (0.1, 0.08, 0.01), "plain", "1e1a24", subdiv=1, seed=7, jitter=0.0,
               wave=0.9)
    for x in (-4.0, -3.2):
        b.box((x, 1.6, 2.4), (0.12, 3.2, 0.12), "beam", "6b4a2f")
    for i in range(7):
        b.box((-3.6, 0.3 + i * 0.45, 2.4), (0.9, 0.06, 0.08), "beam", "8a6a4a")
    b.box((-3.6, 3.25, 2.4), (1.4, 0.1, 1.2), "planks", "8a6a4a")


def model_raccoon(b):
    """Räuber-Waschbär (~1.1 m): round body, mask, ringed tail, loot sack on the back."""
    b.blob((0, 0.5, 0), (0.32, 0.36, 0.3), "plain", "8f8f96", subdiv=2, seed=601, jitter=0.04)
    b.blob((0, 0.48, 0.12), (0.22, 0.26, 0.18), "plain", "d9d4cc", subdiv=2, seed=602, jitter=0.03)
    b.blob((0, 0.98, 0.04), (0.27, 0.24, 0.25), "plain", "9a9aa2", subdiv=2, seed=603, jitter=0.03)
    b.blob((0, 0.93, 0.27), (0.12, 0.09, 0.12), "plain", "e8e2d8", subdiv=1, seed=604, jitter=0.02)
    b.blob((0, 0.96, 0.38), (0.045, 0.04, 0.04), "plain", "1e1a1c", subdiv=1, seed=605, jitter=0.0)
    b.box((0, 1.03, 0.2), (0.5, 0.1, 0.14), "plain", "2b2a30")
    for s in (-1, 1):
        b.blob((s * 0.1, 1.04, 0.27), (0.045, 0.05, 0.02), "plain", "ffffff", subdiv=1, seed=606, jitter=0.0)
        b.blob((s * 0.1, 1.04, 0.288), (0.022, 0.026, 0.01), "plain", "1e1a1c", subdiv=1, seed=607, jitter=0.0)
        b.cone((s * 0.17, 1.16, 0.0), 0.08, 0.16, 6, "plain", "6e6e76")
        b.blob((s * 0.2, 0.12, 0.05), (0.09, 0.1, 0.12), "plain", "4a4a52", subdiv=1, seed=608, jitter=0.02)
        b.blob((s * 0.32, 0.55, 0.12), (0.07, 0.16, 0.07), "plain", "6e6e76", subdiv=1, seed=609, jitter=0.02)
    for i in range(5):
        b.blob((0, 0.32 + i * 0.06, -0.32 - i * 0.12), (0.1, 0.1, 0.09), "plain", "2b2a30" if i % 2 else "a8a8b0",
               subdiv=1, seed=610 + i, jitter=0.02)
    b.blob((0.05, 0.75, -0.28), (0.22, 0.26, 0.2), "cloth", "c9a874", subdiv=2, seed=620, jitter=0.1)
    b.box((0.05, 1.0, -0.28), (0.1, 0.06, 0.1), "plain", "8a6a3a")


def model_guard(b):
    """Dorfwache (~1.3 m): tunic with Lumo star, helmet, round shield, foam-tipped pole."""
    b.blob((0, 0.55, 0), (0.28, 0.38, 0.24), "cloth", "3f7fd9", subdiv=2, seed=701, jitter=0.03)
    b.box((0, 0.36, 0), (0.58, 0.08, 0.5), "beam", "6b4a2f")
    b.blob((0, 1.08, 0.02), (0.22, 0.22, 0.21), "plain", "f2c79a", subdiv=2, seed=702, jitter=0.02)
    b.cylinder((0, 1.24, 0.0), 0.24, 0.16, 10, "metal", "c9ced6", r_top=0.2)
    b.blob((0, 1.31, 0.0), (0.2, 0.1, 0.2), "metal", "c9ced6", subdiv=1, seed=703, jitter=0.0)
    b.cone((0, 1.38, 0), 0.04, 0.16, 6, "cloth", "e8553f")
    for s in (-1, 1):
        b.blob((s * 0.08, 1.1, 0.2), (0.03, 0.035, 0.015), "plain", "1e1a1c", subdiv=1, seed=704, jitter=0.0)
        b.cylinder((s * 0.12, 0.12, 0.02), 0.08, 0.24, 6, "plain", "4a3a2a")
    b.blob((0, 0.62, 0.23), (0.09, 0.09, 0.02), "plain", "ffd25a", subdiv=1, seed=705, jitter=0.0)
    b.cylinder((-0.36, 0.6, 0.12), 0.26, 0.06, 12, "planks", "c0603a", axis="x")
    b.cylinder((-0.4, 0.6, 0.12), 0.08, 0.04, 8, "metal", "ffd25a", axis="x")
    b.cylinder((0.34, 0.85, 0.08), 0.03, 1.7, 5, "beam", "a87a4e")
    b.blob((0.34, 1.73, 0.08), (0.08, 0.1, 0.08), "cloth", "ffd25a", subdiv=1, seed=706, jitter=0.0)


def model_dragon(b):
    """Funkel, der kleine Drache (~3 m): chubby body, light belly, horns, back spikes, tail."""
    b.blob((0, 1.2, 0), (0.75, 0.7, 1.0), "plain", "39b49a", subdiv=2, seed=801, jitter=0.03)
    b.blob((0, 1.05, 0.25), (0.55, 0.5, 0.7), "plain", "f2e3a0", subdiv=2, seed=802, jitter=0.02)
    b.blob((0, 2.05, 0.75), (0.5, 0.46, 0.5), "plain", "3cc0a4", subdiv=2, seed=803, jitter=0.02)
    b.blob((0, 1.92, 1.18), (0.3, 0.22, 0.26), "plain", "48c9ad", subdiv=2, seed=804, jitter=0.02)
    for s in (-1, 1):
        b.blob((s * 0.1, 1.95, 1.43), (0.04, 0.03, 0.02), "plain", "1e3a34", subdiv=1, seed=805, jitter=0.0)
        b.blob((s * 0.2, 2.2, 1.08), (0.11, 0.12, 0.06), "plain", "ffffff", subdiv=1, seed=806, jitter=0.0)
        b.blob((s * 0.2, 2.2, 1.13), (0.06, 0.07, 0.03), "plain", "2b2622", subdiv=1, seed=807, jitter=0.0)
        b.push((s * 0.22, 2.45, 0.62), rot_x=-0.5)
        b.cone((0, 0, 0), 0.08, 0.36, 6, "plain", "ffe6a8")
        b.pop()
        b.blob((s * 0.42, 0.3, 0.45), (0.2, 0.3, 0.24), "plain", "2ea38a", subdiv=1, seed=808, jitter=0.02)
        b.blob((s * 0.42, 0.3, -0.45), (0.2, 0.3, 0.24), "plain", "2ea38a", subdiv=1, seed=809, jitter=0.02)
        b.blob((s * 0.25, 1.92, 1.0), (0.08, 0.05, 0.03), "plain", "f59bb0", subdiv=1, seed=810, jitter=0.0)
    for i in range(6):
        z = 0.55 - i * 0.32
        b.cone((0, 1.85 - abs(i - 1.5) * 0.08, z), 0.12, 0.3, 5, "plain", "f2b632")
    for i in range(6):
        t = i / 5
        b.blob((0, 0.9 - t * 0.5, -1.0 - t * 1.4), (0.32 - t * 0.2, 0.28 - t * 0.18, 0.32), "plain", "39b49a",
               subdiv=1, seed=820 + i, jitter=0.02)
    b.cone((0, 0.4, -2.55), 0.16, 0.35, 4, "plain", "f2b632")


def dragon_wing(b, side):
    """One wing in local space: hinge at origin, spans along side * X."""
    s = side
    pts = [(0, 0, 0.3), (s * 1.6, 0.5, 0.1), (s * 1.9, 0.2, -0.6), (s * 1.2, -0.05, -0.5), (s * 0.6, -0.05, -0.55),
           (0, 0, -0.4)]
    for face in ((0, 1, 2, 3), (0, 3, 4, 5)):
        q = [pts[i] for i in face]
        b.face(q if s < 0 else q[::-1], "cloth", "f59b6b", wave=0.3)
        b.face(q[::-1] if s < 0 else q, "cloth", "e8805a", wave=0.3)
    b.cylinder((s * 0.8, 0.25, 0.2), 0.05, 1.7, 5, "plain", "2ea38a", axis="x")


def model_dragon_wing_l(b):
    dragon_wing(b, -1)


def model_dragon_wing_r(b):
    dragon_wing(b, 1)


def model_dragon_nest(b):
    """Funkels Höhle: rocky outcrop, cave mouth, glittering coin pile."""
    for i, (x, z, r) in enumerate(((-2.5, -1.0, 2.4), (2.2, -1.5, 2.6), (0.0, -2.6, 2.8), (-3.6, 1.2, 1.4),
                                   (3.5, 1.0, 1.5))):
        b.blob((x, r * 0.55, z), (r, r * 1.1, r * 0.9), "stone_wall", "9a9284", subdiv=2, seed=900 + i, jitter=0.2,
               flat_bottom=True)
    b.blob((0, 1.2, -0.7), (1.3, 1.3, 0.3), "plain", "2b2622", subdiv=1, seed=910, jitter=0.05)
    for i in range(14):
        a = i * 2.4
        rr = 0.3 + (i % 5) * 0.18
        b.cylinder((math.cos(a) * rr, 0.06 + (i % 3) * 0.08, 1.0 + math.sin(a) * rr * 0.6), 0.16, 0.05, 8, "metal",
                   "ffd25a")
    b.blob((0, 0.25, 1.0), (0.7, 0.3, 0.45), "metal", "f2b632", subdiv=1, seed=911, jitter=0.1, flat_bottom=True)
    for i in range(4):
        b.blob((-1.4 + i * 0.9, 0.2, 1.9), (0.3, 0.25, 0.3), "leaves", "5f8f38", subdiv=1, seed=920 + i)


MODELS = {
    "palisade": (model_palisade, {}),
    "castle_wall": (model_castle_wall, {}),
    "wall_tower": (model_wall_tower, {}),
    "gatehouse": (model_gatehouse, {"Spin_Bridge": (model_gatehouse_bridge, (0.0, 0.0, 1.15))}),
    "moat": (model_moat, {}),
    "net_trap": (model_net_trap, {}),
    "robber_camp": (model_robber_camp, {}),
    "raccoon": (model_raccoon, {}),
    "guard": (model_guard, {}),
    "dragon": (model_dragon, {"Spin_WingL": (model_dragon_wing_l, (-0.45, 1.75, 0.25)),
                              "Spin_WingR": (model_dragon_wing_r, (0.45, 1.75, 0.25))}),
    "dragon_nest": (model_dragon_nest, {}),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    V.MODELS.update(MODELS)
    names = [n for n in MODELS if not args.only or n in args.only.split(",")]
    report_path = V.OUT / "models.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    for name in names:
        info = V.build_model(name)
        info["sha256"] = hashlib.sha256((V.OUT / f"{name}.glb").read_bytes()).hexdigest()
        assert info["triangles"] < 20000 and info["bytes"] < 2 * 1024 * 1024, name
        report[name] = info
        print(f"{name}: {info['triangles']} tris, {info['bytes']} bytes")
    report_path.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
