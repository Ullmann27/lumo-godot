#!/usr/bin/env python3
"""Sonnenhafen modular town kit for LUMO World (Eigenbau, Blender 5.3 / bpy).

Run: /home/user/tools/bpyenv/bin/python tools/lumo_world_art/build_sonnenhafen_kit.py [--only wall_plaster,door_house]

Every module is authored from code with the shared village Builder, so all
pieces reference the SAME 4x4 village texture atlas (1024 px) and are drawn by
the same Godot shader (village_building.gdshader): one material for the whole
town, window tiles glow in the evening, and Godot batches repeated modules as
MultiMesh instances. Godot's GLB importer adds mesh LODs automatically.

World scale: LUMO figures are about 2.4 m tall, so one facade bay is 3.2 m
wide and one storey is 4.0 m high. Coordinates are Godot convention (Y up,
front = +Z); a wall module's outside face lies at z = +WALL/2 and its origin is
at the bottom centre. Overlay pieces (windows, doors, shutters, gutters) sit
in front of z = 0 so they can be placed on any wall module with the same
transform. Tintable modules keep a neutral vertex colour (0.5): Godot sets the
final hue per instance (MultiMesh instance colour).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lumo_village_art"))
import build_village_models as V  # noqa: E402
import bpy  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/lumo_world/sonnenhafen/kit"
BAY = 3.2
STOREY = 4.0
WALL = 0.4
DEPTH = 9.6
HALL_DEPTH = 12.8
ROOF_RISE = 4.4
HALL_RISE = 4.2
NEUTRAL = "ffffff"


# ------------------------------------------------------------------ walls
def wall_bay(b, tile, color=NEUTRAL):
    b.box((0, STOREY / 2, 0), (BAY, STOREY, WALL), tile, color, bottom=False)


def model_wall_plaster(b):
    """Plaster bay (tinted per building)."""
    wall_bay(b, "plaster")


def model_wall_brick(b):
    """Brick-like stone bay (tinted warm red per building)."""
    wall_bay(b, "stone_wall")


def model_wall_planks(b):
    """Weatherboard bay for warehouses and the fish hall."""
    wall_bay(b, "planks")
    for x in (-BAY / 2 + 0.1, BAY / 2 - 0.1):
        b.box((x, STOREY / 2, WALL / 2 + 0.03), (0.16, STOREY, 0.08), "beam", "6b4a2f")


def model_plinth(b):
    """Stone base course under the ground floor (0.6 m, partly below ground)."""
    b.box((0, 0.1, 0.05), (BAY + 0.02, 0.8, WALL + 0.14), "stone_wall", "a69e8e", bottom=False)


def model_corner(b):
    """Corner pilaster hiding the seam between facade and side wall."""
    b.box((0, STOREY / 2, 0), (0.56, STOREY, 0.56), "stone_wall", "d9d2c4")


def model_cornice(b):
    """Storey band / eaves moulding, one bay long."""
    b.box((0, 0.0, WALL / 2 + 0.08), (BAY + 0.04, 0.26, 0.28), "beam", "f2ead8")
    b.box((0, 0.18, WALL / 2 + 0.03), (BAY + 0.04, 0.12, 0.18), "beam", "e2d6bc")


# ------------------------------------------------------------- openings
FRONT = WALL / 2


def model_window_sash(b):
    """Tall sash window with white frame, cross bars and sill."""
    w, h, y = 1.35, 1.9, 2.05
    b.box((0, y, FRONT + 0.04), (w + 0.24, h + 0.24, 0.1), "beam", "f6f1e4")
    b.panel((0, y, FRONT + 0.095), w, h, "window", "ffffff")
    b.box((0, y, FRONT + 0.11), (0.08, h, 0.04), "beam", "f6f1e4")
    b.box((0, y + 0.15, FRONT + 0.11), (w, 0.08, 0.04), "beam", "f6f1e4")
    b.box((0, y - h / 2 - 0.12, FRONT + 0.16), (w + 0.4, 0.12, 0.3), "stone_wall", "e2dccf")
    b.box((0, y + h / 2 + 0.16, FRONT + 0.08), (w + 0.36, 0.14, 0.16), "beam", "f2ead8")


def model_window_round(b):
    """Arched window for the ground floor of brick houses."""
    w, h, y = 1.3, 1.6, 1.9
    b.box((0, y, FRONT + 0.04), (w + 0.24, h + 0.12, 0.1), "beam", "f6f1e4")
    b.panel((0, y, FRONT + 0.095), w, h, "window", "ffffff")
    segs = 8
    r = w / 2 + 0.12
    for i in range(segs):
        a0 = math.pi * i / segs
        a1 = math.pi * (i + 1) / segs
        cx = (math.cos(a0) + math.cos(a1)) / 2 * r
        cy = (math.sin(a0) + math.sin(a1)) / 2 * r
        b.push((cx, y + h / 2 + cy, FRONT + 0.06), rot_z=(a0 + a1) / 2 + math.pi / 2)
        b.box((0, 0, 0), (0.24, math.pi * r / segs + 0.04, 0.14), "stone_wall", "c96a4a")
        b.pop()
    b.face([(-w / 2, y + h / 2, FRONT + 0.09), (w / 2, y + h / 2, FRONT + 0.09), (0, y + h / 2 + w / 2, FRONT + 0.09)],
           "window", "ffffff", fit=True)
    b.box((0, y - h / 2 - 0.1, FRONT + 0.15), (w + 0.36, 0.12, 0.28), "stone_wall", "e2dccf")


def model_window_shop(b):
    """Large display window of a ground-floor shop."""
    w, h, y = 2.5, 2.3, 1.85
    b.box((0, 0.35, FRONT + 0.12), (w + 0.3, 0.7, 0.24), "planks", "6b4a2f")
    b.box((0, y, FRONT + 0.04), (w + 0.3, h + 0.3, 0.12), "beam", "3f5d6a")
    b.panel((0, y, FRONT + 0.11), w, h, "window", "ffffff")
    for x in (-w / 6, w / 6):
        b.box((x, y, FRONT + 0.13), (0.07, h, 0.05), "beam", "3f5d6a")


def model_window_loft(b):
    """Warehouse loading hatch with hoist beam."""
    b.box((0, 2.3, FRONT + 0.05), (1.6, 2.0, 0.12), "beam", "5a3a22")
    b.panel((0, 2.3, FRONT + 0.12), 1.4, 1.8, "door", "ffffff")
    b.box((0, 3.6, FRONT + 0.6), (0.18, 0.18, 1.2), "beam", "5a3a22")
    b.cylinder((0, 3.2, FRONT + 1.1), 0.02, 0.8, 5, "metal", "3a3a3a")


def model_door_house(b):
    """Front door (2.9 m) with transom, steps and lamp."""
    w, h = 1.7, 2.9
    b.box((0, h / 2 + 0.1, FRONT + 0.05), (w + 0.36, h + 0.3, 0.12), "beam", "f2ead8")
    b.panel((0, h / 2, FRONT + 0.12), w, h - 0.5, "door", "ffffff")
    b.panel((0, h - 0.1, FRONT + 0.12), w, 0.4, "window", "ffffff")
    b.box((0, 0.08, FRONT + 0.55), (w + 1.0, 0.16, 0.9), "stone_wall", "c9c0b0")
    b.box((w / 2 + 0.45, h + 0.05, FRONT + 0.2), (0.2, 0.3, 0.2), "metal", "2e2e2e")
    b.panel((w / 2 + 0.45, h + 0.05, FRONT + 0.305), 0.15, 0.22, "window", "ffd27a")


def model_door_frame(b):
    """Open doorway surround (walk-in buildings). Opening 3.0 x 3.3 m."""
    w, h = 3.0, 3.3
    for x in (-w / 2 - 0.2, w / 2 + 0.2):
        b.box((x, h / 2, FRONT + 0.06), (0.4, h, 0.32), "stone_wall", "d9cfbe")
    b.box((0, h + 0.35, FRONT + 0.06), (w + 0.8, 0.7, 0.32), "stone_wall", "d9cfbe")
    b.box((0, h + 0.35, FRONT + 0.25), (w + 0.2, 0.46, 0.08), "planks", "3f5d6a")


def model_door_warehouse(b):
    """Big barn gate of a warehouse."""
    w, h = 2.8, 3.4
    b.box((0, h / 2 + 0.05, FRONT + 0.05), (w + 0.4, h + 0.2, 0.12), "beam", "5a3a22")
    for s in (-1, 1):
        b.panel((s * w / 4, h / 2, FRONT + 0.12), w / 2 - 0.05, h, "door", "ffffff")
        b.push((s * w / 4, h / 2, FRONT + 0.15), rot_z=s * math.atan2(h, w / 2))
        b.box((0, 0, 0), (math.hypot(h, w / 2) * 0.95, 0.12, 0.05), "beam", "6b4a2f")
        b.pop()


def model_shutters(b):
    """Pair of window shutters (tinted per building)."""
    for s in (-1, 1):
        b.box((s * 1.05, 2.05, FRONT + 0.06), (0.62, 1.95, 0.08), "planks", NEUTRAL)
        b.box((s * 1.05, 2.05, FRONT + 0.11), (0.5, 0.08, 0.03), "beam", "f2ead8")


def model_flower_box(b):
    """Window flower box with mixed flowers."""
    b.box((0, 0.85, FRONT + 0.34), (1.6, 0.32, 0.34), "planks", "8a5a33")
    for i in range(7):
        x = -0.66 + i * 0.22
        col = ["e84a5f", "ffd166", "f78fb3", "ffffff", "ff9f43", "b388ff", "e84a5f"][i]
        b.blob((x, 1.1, FRONT + 0.34), (0.16, 0.13, 0.16), "leaves", "5f9a3e", subdiv=1, seed=i + 3)
        b.blob((x + 0.05, 1.24, FRONT + 0.38), (0.1, 0.08, 0.1), "plain", col, subdiv=1, seed=i)


def _awning(b, color):
    b.push((0, 3.45, FRONT + 0.2), rot_x=0.38)
    stripes = 6
    for i in range(stripes):
        x = -BAY / 2 + (i + 0.5) * BAY / stripes
        b.box((x, 0, 0.75), (BAY / stripes, 0.06, 1.5), "cloth", color if i % 2 == 0 else "fbf6ea")
    for i in range(stripes):
        x = -BAY / 2 + (i + 0.5) * BAY / stripes
        b.box((x, -0.12, 1.5), (BAY / stripes, 0.28, 0.04), "cloth", color if i % 2 == 0 else "fbf6ea")
    b.pop()
    for s in (-1, 1):
        b.push((s * (BAY / 2 - 0.1), 3.1, FRONT + 0.75), rot_x=-0.9)
        b.box((0, 0, 0), (0.05, 0.05, 1.2), "metal", "3a3a3a")
        b.pop()


def model_awning_red(b):
    _awning(b, "d94a3d")


def model_awning_blue(b):
    _awning(b, "2f7fb5")


def model_awning_green(b):
    _awning(b, "3f9a5a")


def model_balcony(b):
    """Wrought-iron balcony in front of an upper-floor door/window."""
    b.box((0, 0.0, FRONT + 0.55), (2.2, 0.16, 1.1), "stone_wall", "d9d2c4")
    b.box((0, 1.0, FRONT + 1.08), (2.2, 0.06, 0.06), "metal", "2d3a40")
    for i in range(12):
        x = -1.05 + i * 0.19
        b.box((x, 0.5, FRONT + 1.08), (0.035, 1.0, 0.035), "metal", "2d3a40")
    for s in (-1, 1):
        b.box((s * 1.08, 1.0, FRONT + 0.55), (0.06, 0.06, 1.1), "metal", "2d3a40")
        for i in range(5):
            b.box((s * 1.08, 0.5, FRONT + 0.1 + i * 0.22), (0.035, 1.0, 0.035), "metal", "2d3a40")
    b.flowers((0.6, 0.08, FRONT + 0.7), 3, 0.25, seed=5)


def model_sign_bracket(b):
    """Iron wall bracket with a hanging sign board (text is drawn in Godot)."""
    b.box((0, 0.0, FRONT + 0.6), (0.08, 0.08, 1.2), "metal", "2d3a40")
    b.push((0, -0.3, FRONT + 0.45), rot_x=-0.5)
    b.box((0, 0, 0), (0.05, 0.05, 0.8), "metal", "2d3a40")
    b.pop()
    for z in (FRONT + 0.35, FRONT + 1.05):
        b.cylinder((0, -0.15, z), 0.015, 0.3, 4, "metal", "3a3a3a")
    b.box((0, -0.62, FRONT + 0.7), (0.1, 0.7, 1.1), "planks", "e9d6a8")
    b.box((0, -0.62, FRONT + 0.7), (0.12, 0.78, 1.18), "beam", "6b4a2f", bottom=True)


def model_lamp_wall(b):
    """Wall lantern; its glass glows in the evening."""
    b.box((0, 0, FRONT + 0.25), (0.08, 0.08, 0.5), "metal", "2e2e2e")
    b.box((0, -0.25, FRONT + 0.5), (0.34, 0.46, 0.34), "metal", "2e2e2e")
    for rot in (0, math.pi / 2, math.pi, -math.pi / 2):
        b.push((0, -0.25, FRONT + 0.5), rot)
        b.panel((0, 0, 0.175), 0.26, 0.36, "window", "ffd27a")
        b.pop()
    b.pyramid_roof((0, -0.02, FRONT + 0.5), 0.34, 0.34, 0.22, tile="metal", color="2e2e2e", over=0.05)


def model_gutter(b):
    """Eaves gutter (Regenrinne), one bay long, hung at the eave line."""
    b.cylinder((0, 0, FRONT + 0.75), 0.13, BAY, 8, "metal", "8d9aa1", axis="x", caps=False)
    b.box((0, -0.06, FRONT + 0.75), (BAY, 0.04, 0.24), "metal", "7c8890")
    for x in (-BAY / 2 + 0.3, BAY / 2 - 0.3):
        b.box((x, 0.05, FRONT + 0.5), (0.05, 0.05, 0.5), "metal", "5d6a70")


def model_downpipe(b):
    """Downpipe running one storey down a wall corner."""
    b.cylinder((0, STOREY / 2, FRONT + 0.18), 0.08, STOREY, 7, "metal", "8d9aa1")
    for y in (0.6, 2.2, 3.6):
        b.box((0, y, FRONT + 0.1), (0.24, 0.05, 0.16), "metal", "5d6a70")
    b.push((0, 0.1, FRONT + 0.3), rot_x=0.6)
    b.cylinder((0, 0, 0), 0.08, 0.4, 7, "metal", "8d9aa1")
    b.pop()


# ------------------------------------------------------------------ roofs
def _gable_section(b, length, depth, rise, tile, color, over=0.6):
    """One straight length of a pitched roof (ridge along X), no gable walls."""
    hl = length / 2
    hd = depth / 2 + over
    slope = math.atan2(rise, depth / 2)
    drop = over * math.tan(slope)
    thick = 0.22
    for side in (1, -1):
        a = (-hl, -drop, side * hd)
        c = (hl, -drop, side * hd)
        t1 = (hl, rise, 0)
        t0 = (-hl, rise, 0)
        if side > 0:
            b.face([a, c, t1, t0], tile, color)
            b.face([(t0[0], t0[1] - thick, 0), (t1[0], t1[1] - thick, 0), (c[0], c[1] - thick, c[2]), (a[0], a[1] - thick, a[2])],
                   "planks", "8a6a4a")
            b.face([(a[0], a[1] - thick, a[2]), (c[0], c[1] - thick, c[2]), c, a], "beam", "6b4a2f")
        else:
            b.face([c, a, t0, t1], tile, color)
            b.face([(t1[0], t1[1] - thick, 0), (t0[0], t0[1] - thick, 0), (a[0], a[1] - thick, a[2]), (c[0], c[1] - thick, c[2])],
                   "planks", "8a6a4a")
            b.face([(c[0], c[1] - thick, c[2]), (a[0], a[1] - thick, a[2]), a, c], "beam", "6b4a2f")
    b.box((0, rise + 0.05, 0), (length + 0.02, 0.18, 0.34), "beam", "5a3a22")


def model_roof_bay(b):
    """Pitched roof section over one bay of a 9.6 m (3 bay) deep house (tinted)."""
    _gable_section(b, BAY, DEPTH, ROOF_RISE, "roof_clay", NEUTRAL)


def model_roof_bay_slate(b):
    _gable_section(b, BAY, DEPTH, ROOF_RISE, "roof_slate", NEUTRAL)


def _gable_end(b, depth, rise, tile, color, over=0.6, window=True, wall=True, trim=True):
    """Gable wall triangle at x = 0 facing +X (wall) and its barge boards/window (trim)."""
    if wall:
        tri = [(0, 0, -depth / 2), (0, 0, depth / 2), (0, rise - 0.2, 0)]
        b.face(list(reversed(tri)), tile, color)
        b.face([(p[0] - WALL, p[1], p[2]) for p in tri], tile, color)
    if not trim:
        return
    slope = math.atan2(rise, depth / 2)
    length = math.hypot(rise, depth / 2) + over / math.cos(slope)
    for s in (-1, 1):
        b.push((0.08, rise / 2 - 0.1, s * depth / 4), rot_x=s * slope)
        b.box((0, 0, 0), (0.12, 0.3, length), "beam", "6b4a2f")
        b.pop()
    if window:
        b.push((0.02, 0, 0), rot_y=math.pi / 2)
        b.box((0, rise * 0.38, 0.0), (1.0, 1.1, 0.1), "beam", "f6f1e4")
        b.panel((0, rise * 0.38, 0.06), 0.8, 0.9, "window", "ffffff")
        b.pop()


def model_roof_end(b):
    """Plaster gable end for a 9.6 m deep house (place at the bay end, +X outward); tinted."""
    _gable_end(b, DEPTH, ROOF_RISE, "plaster", NEUTRAL, trim=False)


def model_roof_end_trim(b):
    """Barge boards and attic window for roof_end (same transform, untinted)."""
    _gable_end(b, DEPTH, ROOF_RISE, "plaster", NEUTRAL, wall=False)


def model_roof_end_planks(b):
    _gable_end(b, HALL_DEPTH, HALL_RISE, "planks", "8a6a4a", window=False)


def model_roof_hall(b):
    """Pitched roof section over one bay of a 12.8 m (4 bay) deep warehouse/hall."""
    _gable_section(b, BAY, HALL_DEPTH, HALL_RISE, "roof_slate", NEUTRAL)


def model_roof_front_gable(b):
    """Gable-front (giebelständig) roof for a 3-bay, 9.6 m deep house; ridge along Z."""
    w = BAY * 3
    b.push((0, 0, 0), rot_y=math.pi / 2)
    _gable_section(b, DEPTH + 0.8, w, 5.4, "roof_clay", NEUTRAL, over=0.5)
    b.pop()


def model_gable_front_wall(b):
    """Plaster front gable triangle, 3 bays wide (tinted)."""
    w = BAY * 3
    rise = 5.4
    pts = [(-w / 2, 0, FRONT), (w / 2, 0, FRONT), (0, rise - 0.2, FRONT)]
    b.face(pts, "plaster", NEUTRAL)


def model_gable_window(b):
    """Attic windows of a front gable (untinted overlay)."""
    b.box((0, 1.6, FRONT + 0.05), (1.3, 1.6, 0.1), "beam", "f6f1e4")
    b.panel((0, 1.6, FRONT + 0.11), 1.05, 1.35, "window", "ffffff")
    b.box((0, 3.4, FRONT + 0.05), (0.7, 0.7, 0.1), "beam", "f6f1e4")
    b.panel((0, 3.4, FRONT + 0.11), 0.5, 0.5, "window", "ffffff")


def model_gable_stepped(b):
    """Hanseatic stepped brick gable, 3 bays wide (tinted)."""
    w = BAY * 3
    steps = [(w, 1.3), (w * 0.8, 1.2), (w * 0.6, 1.2), (w * 0.4, 1.2), (w * 0.2, 1.1)]
    y = 0.0
    for width, h in steps:
        b.box((0, y + h / 2, FRONT - 0.2), (width, h, WALL + 0.02), "stone_wall", NEUTRAL)
        b.box((0, y + h + 0.06, FRONT - 0.15), (width + 0.1, 0.12, WALL + 0.14), "stone_wall", NEUTRAL)
        y += h


def model_gable_stepped_trim(b):
    """Window and blind arches of the stepped gable (untinted overlay)."""
    b.box((0, 2.0, FRONT + 0.04), (1.3, 1.6, 0.1), "beam", "f6f1e4")
    b.panel((0, 2.0, FRONT + 0.1), 1.05, 1.35, "window", "ffffff")
    for x in (-2.4, 2.4):
        b.box((x, 1.6, FRONT + 0.03), (0.8, 1.6, 0.06), "stone_wall", "9b4a36")


def model_dormer(b):
    """Small dormer for the front slope of a 9.6 m deep roof (origin on the eave line)."""
    b.box((0, 1.0, -0.6), (1.6, 1.6, 1.8), "plaster", "f4ead2")
    b.box((0, 1.0, 0.31), (1.1, 1.1, 0.06), "beam", "f6f1e4")
    b.panel((0, 1.0, 0.35), 0.9, 0.9, "window", "ffffff")
    b.gable_roof((0, 1.8, -0.6), 1.6, 1.8, 0.7, over=0.2, thick=0.1, tile="roof_slate", color="ffffff",
                 gable_tile="plaster", gable_color="f4ead2", ridge_axis="z")


def model_chimney(b):
    b.box((0, 0.9, 0), (0.8, 1.8, 0.8), "stone_wall", "9a8f80")
    b.box((0, 1.86, 0), (0.96, 0.16, 0.96), "stone_wall", "7d7468")
    b.cylinder((0, 2.05, 0), 0.14, 0.3, 6, "metal", "4a4a4a")


# ------------------------------------------------------------- street props
def model_lamp_post(b):
    """Harbour street lamp, 4.6 m; glass glows in the evening."""
    b.cylinder((0, 0.15, 0), 0.32, 0.3, 10, "stone_wall", "9a9284")
    b.cylinder((0, 2.2, 0), 0.09, 4.2, 8, "metal", "2d3a40", r_top=0.06)
    b.box((0, 4.15, 0.35), (0.06, 0.06, 0.7), "metal", "2d3a40")
    b.box((0, 4.35, 0), (0.46, 0.56, 0.46), "metal", "2d3a40")
    for rot in (0, math.pi / 2, math.pi, -math.pi / 2):
        b.push((0, 4.35, 0), rot)
        b.panel((0, 0, 0.235), 0.36, 0.46, "window", "ffd27a")
        b.pop()
    b.pyramid_roof((0, 4.63, 0), 0.46, 0.46, 0.34, tile="metal", color="2d3a40", over=0.08)


def model_bollard(b):
    b.cylinder((0, 0.35, 0), 0.24, 0.7, 10, "metal", "2d3a40")
    b.cylinder((0, 0.75, 0), 0.32, 0.12, 10, "metal", "2d3a40")


def model_bench(b):
    b.box((0, 0.55, 0), (2.4, 0.1, 0.7), "planks", "a87a4e")
    b.box((0, 0.95, -0.32), (2.4, 0.5, 0.08), "planks", "a87a4e")
    for x in (-1.0, 1.0):
        b.box((x, 0.27, 0), (0.1, 0.55, 0.6), "metal", "2d3a40")
        b.box((x, 0.75, -0.32), (0.1, 0.9, 0.1), "metal", "2d3a40")


def model_flower_tub(b):
    b.cylinder((0, 0.35, 0), 0.7, 0.7, 12, "planks", "8a5a33", r_top=0.78)
    b.blob((0, 0.85, 0), (0.75, 0.45, 0.75), "leaves", "5f9a3e", subdiv=2, seed=4)
    b.flowers((0, 0.75, 0), 9, 0.55, seed=6)


def model_crate_stack(b):
    for i, (x, z, r) in enumerate([(-0.5, 0.0, 0.1), (0.45, 0.1, -0.2), (0.0, -0.6, 0.3)]):
        b.crate((x, 0, z), 0.8, rot=r)
    b.crate((-0.1, 0.8, 0.0), 0.7, color="c49a6a", rot=0.4)


def model_barrel_group(b):
    for x, z in ((-0.4, 0.0), (0.35, 0.1), (0.0, -0.55)):
        b.barrel((x, 0, z), r=0.36, h=0.9)
    b.barrel((0.0, 0.9, -0.1), r=0.34, h=0.85, color="9a6a3a")


def model_fish_crates(b):
    for i, (x, z) in enumerate(((-0.55, 0.0), (0.4, 0.05), (-0.1, 0.0))):
        y = 0.0 if i < 2 else 0.5
        b.box((x, y + 0.22, z), (0.85, 0.44, 0.6), "planks", "c9a46a")
        for k in range(4):
            b.blob((x - 0.3 + k * 0.2, y + 0.48, z), (0.1, 0.06, 0.24), "plain", ["9fb7c4", "c9d6dc", "8aa3b0", "b5c8d0"][k],
                   subdiv=1, seed=k + i * 4, jitter=0.05)


def model_rope_coil(b):
    for i in range(4):
        b.cylinder((0, 0.06 + i * 0.1, 0), 0.5 - i * 0.04, 0.1, 14, "cloth", "d9c08a", caps=False)
    b.cylinder((0, 0.2, 0), 0.32, 0.4, 10, "cloth", "c4a86c")


def model_net_rack(b):
    """Wooden frame with a drying fishing net and floats."""
    for x in (-1.6, 1.6):
        b.box((x, 1.3, 0), (0.14, 2.6, 0.14), "beam", "6b4a2f")
    b.box((0, 2.55, 0), (3.4, 0.12, 0.12), "beam", "6b4a2f")
    for i in range(9):
        x = -1.4 + i * 0.35
        b.box((x, 1.55, 0.02), (0.025, 1.9, 0.02), "cloth", "6f7f6a")
    for j in range(6):
        b.box((0, 0.7 + j * 0.33, 0.02), (3.0, 0.025, 0.02), "cloth", "6f7f6a")
    for i in range(5):
        b.blob((-1.2 + i * 0.6, 2.42, 0.08), (0.1, 0.1, 0.1), "plain", "f28a3a", subdiv=1, seed=i)


def model_anchor(b):
    b.box((0, 1.0, 0), (0.16, 2.0, 0.16), "metal", "34414a")
    b.box((0, 1.85, 0), (0.9, 0.14, 0.16), "metal", "34414a")
    b.cylinder((0, 2.1, 0), 0.18, 0.1, 10, "metal", "34414a", axis="z", caps=True)
    for s in (-1, 1):
        b.push((s * 0.45, 0.35, 0), rot_z=s * 0.7)
        b.box((0, 0, 0), (0.14, 0.9, 0.16), "metal", "34414a")
        b.pop()
    b.box((0, 0.1, 0), (1.3, 0.16, 0.16), "metal", "34414a")


def _stall(b, color, wares):
    w = 3.4
    b.box((0, 0.55, 0.3), (w, 1.1, 1.1), "planks", "a87a4e")
    b.box((0, 1.12, 0.3), (w + 0.1, 0.08, 1.2), "planks", "c49a6a")
    for x in (-w / 2 + 0.1, w / 2 - 0.1):
        for z in (-0.3, 0.9):
            b.box((x, 1.45, z), (0.12, 2.9, 0.12), "beam", "6b4a2f")
    b.push((0, 2.95, 0.3), rot_x=0.22)
    for i in range(6):
        x = -w / 2 + (i + 0.5) * w / 6
        b.box((x, 0, 0), (w / 6 + 0.01, 0.07, 1.8), "cloth", color if i % 2 == 0 else "fbf6ea")
    b.pop()
    for i in range(10):
        x = -1.4 + (i % 5) * 0.7
        z = 0.05 if i < 5 else 0.55
        b.blob((x, 1.25, z), (0.22, 0.13, 0.22), "plain", wares[i % len(wares)], subdiv=1, seed=i + 11, jitter=0.08)
    b.crate((w / 2 + 0.5, 0, 0.6), 0.7, rot=0.2)
    b.crate((-w / 2 - 0.5, 0, 0.4), 0.7, rot=-0.3)


def model_stall_fish(b):
    _stall(b, "2f7fb5", ["9fb7c4", "c9d6dc", "8aa3b0", "f28a7a"])


def model_stall_fruit(b):
    _stall(b, "d94a3d", ["e84a5f", "ffd166", "6fae3e", "f08a2c"])


def model_stall_bread(b):
    _stall(b, "e0a030", ["d9a35a", "f6e7c1", "c9773a", "b5652a"])


def model_fountain(b):
    """Market fountain: octagonal basin, column, bowl and a gull finial."""
    b.cylinder((0, 0.4, 0), 3.0, 0.8, 8, "stone_wall", "c9c0b0")
    b.cylinder((0, 0.78, 0), 2.7, 0.06, 8, "plain", "5fb7d0", caps=True)
    b.cylinder((0, 1.6, 0), 0.4, 2.4, 8, "stone_wall", "d9d2c4")
    b.cylinder((0, 2.85, 0), 1.2, 0.3, 10, "stone_wall", "c9c0b0", r_top=0.8)
    b.cylinder((0, 3.02, 0), 1.0, 0.04, 10, "plain", "7fd0e6")
    b.blob((0, 3.5, 0), (0.35, 0.3, 0.6), "plain", "f4f6f8", subdiv=2, seed=2, jitter=0.05)
    for s in (-1, 1):
        b.push((s * 0.45, 3.6, 0), rot_z=s * 0.5)
        b.box((0, 0, 0), (0.7, 0.06, 0.4), "plain", "f4f6f8")
        b.pop()


# ------------------------------------------------------------- harbour works
def model_pier(b):
    """4 m pier segment (along Z), deck top at y = 0, on posts into the water."""
    b.box((0, -0.1, 0), (4.0, 0.2, 4.0), "planks", "a87a4e")
    for x in (-1.8, 1.8):
        for z in (-1.6, 1.6):
            b.cylinder((x, -1.4, z), 0.18, 2.6, 8, "bark", "ffffff")
        b.box((x, 0.06, 0), (0.24, 0.12, 4.0), "beam", "6b4a2f")


def model_quay_edge(b):
    """4 m stone quay wall with granite kerb; walkway top at y = 0, water side +Z."""
    b.box((0, -1.2, 0.0), (4.0, 2.4, 1.0), "stone_wall", "b5ad9c", bottom=False)
    b.box((0, 0.12, 0.05), (4.04, 0.24, 1.1), "stone_wall", "d9d2c4")
    b.box((0, -1.6, 0.52), (4.0, 0.6, 0.06), "plain", "3d5a4a")


def model_bridge_road(b):
    """12 m stone road bridge segment, 10 m wide, deck at y = 0, crossing along Z."""
    length, width = 12.0, 10.0
    b.box((0, -0.3, 0), (width, 0.6, length), "cobble", "d1c6b2", bottom=False)
    for s in (-1, 1):
        b.box((s * (width / 2 - 0.3), 0.55, 0), (0.6, 1.1, length), "stone_wall", "c9c0b0")
        b.box((s * (width / 2 - 0.3), 1.15, 0), (0.75, 0.14, length + 0.1), "stone_wall", "e2dccf")
        for z in (-length / 2 + 0.4, length / 2 - 0.4):
            b.box((s * (width / 2 - 0.3), 0.8, z), (0.9, 1.6, 0.9), "stone_wall", "b5ad9c")
    # Solid stone body below the deck; the canal water hides its foot.
    b.box((0, -1.4, 0), (width - 0.4, 1.6, length - 0.4), "stone_wall", "a69e8e", bottom=False)
    for s_ in (-1, 1):
        b.box((s_ * (width / 2 - 0.15), -0.9, 0), (0.3, 0.6, length), "stone_wall", "c9c0b0")


def model_bridge_foot(b):
    """12 m wooden footbridge, 4 m wide, deck at y = 0, crossing along Z, with rails."""
    length, width = 12.0, 4.0
    b.box((0, -0.12, 0), (width, 0.24, length), "planks", "b08a5a")
    for s in (-1, 1):
        for z in range(7):
            b.box((s * (width / 2 - 0.1), 0.6, -length / 2 + 0.3 + z * (length - 0.6) / 6), (0.16, 1.2, 0.16), "beam", "6b4a2f")
        b.box((s * (width / 2 - 0.1), 1.2, 0), (0.18, 0.12, length), "beam", "8a5a33")
        b.box((s * (width / 2 - 0.1), 0.65, 0), (0.08, 0.08, length), "beam", "8a5a33")
    for z in (-length / 2 + 1.0, 0.0, length / 2 - 1.0):
        for s in (-1, 1):
            b.cylinder((s * (width / 2 - 0.3), -1.4, z), 0.16, 2.6, 8, "bark", "ffffff")


def model_crane(b):
    """Wooden harbour crane with jib, rope and hook (Hafenkran)."""
    b.box((0, 0.3, 0), (3.0, 0.6, 3.0), "stone_wall", "a69e8e")
    for x in (-1.0, 1.0):
        for z in (-1.0, 1.0):
            b.push((x * 0.8, 3.4, z * 0.8), rot_x=-z * 0.1, rot_z=x * 0.1)
            b.box((0, 0, 0), (0.3, 6.0, 0.3), "beam", "6b4a2f")
            b.pop()
    b.box((0, 6.5, 0), (2.4, 0.4, 2.4), "planks", "8a5a33")
    b.push((0, 7.0, 1.0), rot_x=-0.55)
    b.box((0, 0, 2.6), (0.32, 0.32, 6.4), "beam", "5a3a22")
    b.pop()
    b.cylinder((0, 3.5, 4.4), 0.03, 5.0, 4, "cloth", "d9c08a")
    b.box((0, 1.0, 4.4), (0.3, 0.3, 0.1), "metal", "3a3a3a")
    b.gable_roof((0, 6.7, 0), 2.6, 2.6, 1.0, over=0.2, thick=0.1, tile="roof_slate", color="ffffff",
                 gable_tile="planks", gable_color="8a6a4a")


def model_lighthouse(b):
    """Lighthouse, 17 m: red/white bands, gallery, glowing lantern room."""
    segs = 14
    y = 0.0
    radius = 2.6
    b.cylinder((0, 0.6, 0), 3.6, 1.2, segs, "stone_wall", "b5ad9c")
    y = 1.2
    for i in range(6):
        h = 2.0
        r0 = radius - i * 0.17
        r1 = radius - (i + 1) * 0.17
        b.cylinder((0, y + h / 2, 0), r0, h, segs, "plaster", "d94a3d" if i % 2 == 0 else "fbf6ea", r_top=r1, caps=False)
        y += h
    b.cylinder((0, y + 0.15, 0), 2.0, 0.3, segs, "stone_wall", "e2dccf")
    for i in range(16):
        a = i / 16 * math.tau
        b.box((math.cos(a) * 1.85, y + 0.75, math.sin(a) * 1.85), (0.06, 0.9, 0.06), "metal", "2d3a40")
    b.cylinder((0, y + 1.2, 0), 1.88, 0.06, segs, "metal", "2d3a40", caps=False)
    for i in range(8):
        a = (i + 0.5) / 8 * math.tau
        b.push((0, y + 1.4, 0), rot_y=-a + math.pi / 2)
        b.panel((0, 0, 1.15), 0.85, 1.6, "window", "ffd27a")
        b.pop()
    b.cylinder((0, y + 1.4, 0), 0.6, 1.6, 8, "metal", "2d3a40")
    b.cone((0, y + 2.2, 0), 1.45, 1.4, segs, "metal", "2d3a40")
    b.cylinder((0, y + 3.7, 0), 0.08, 0.3, 6, "metal", "2d3a40")
    b.door((0, 1.2, radius), w=1.2, h=2.2, lamp=False, step=False)
    for i in range(3):
        wy = 3.5 + i * 3.6
        b.push((0, wy, 0), rot_y=i * 2.1)
        b.window((0, 0, radius - (wy - 1.2) * 0.085 + 0.02), w=0.5, h=0.7, shutters=None, box=False)
        b.pop()


def _hull(b, length, beam, height, color, deck="c49a6a"):
    n = 10
    pts = []
    for i in range(n + 1):
        t = i / n
        z = -length / 2 + t * length
        w = beam / 2 * (math.sin(math.pi * (0.06 + t * 0.9)) ** 0.55)
        if t > 0.8:
            w *= 1.0 - (t - 0.8) * 2.2
        pts.append((max(w, 0.05), z))
    for i in range(n):
        (w0, z0), (w1, z1) = pts[i], pts[i + 1]
        for s in (-1, 1):
            q = [(s * w0, height, z0), (s * w1, height, z1), (s * w1 * 0.5, 0.0, z1), (s * w0 * 0.5, 0.0, z0)]
            b.face(q if s < 0 else q[::-1], "planks", color)
            band = [(s * w0 * 1.01, height, z0), (s * w1 * 1.01, height, z1), (s * w1 * 1.01, height - 0.25, z1),
                    (s * w0 * 1.01, height - 0.25, z0)]
            b.face(band if s < 0 else band[::-1], "plain", "fbf6ea")
        b.face([(-w0 * 0.5, 0.0, z0), (-w1 * 0.5, 0.0, z1), (w1 * 0.5, 0.0, z1), (w0 * 0.5, 0.0, z0)][::-1], "planks", "5a3a22")
        b.face([(-w1, height - 0.15, z1), (w1, height - 0.15, z1), (w0, height - 0.15, z0), (-w0, height - 0.15, z0)],
               "planks", deck)
    (w_end, z_end) = pts[0]
    b.face([(w_end, 0.0, z_end), (-w_end, 0.0, z_end), (-w_end, height, z_end), (w_end, height, z_end)], "planks", color)


def model_boat_cutter(b):
    """Fishing cutter, 10 m: hull, wheelhouse, mast with boom and nets."""
    _hull(b, 10.0, 3.6, 1.7, "2f6f8f")
    b.box((0, 2.6, 1.6), (2.2, 1.8, 2.2), "planks", "fbf6ea")
    b.box((0, 3.55, 1.6), (2.5, 0.16, 2.5), "planks", "d94a3d")
    for x in (-1.11, 1.11):
        b.panel((x, 2.8, 1.6), 1.4, 0.7, "window", "ffffff", rot_y=math.pi / 2 if x > 0 else -math.pi / 2)
    b.panel((0, 2.8, 2.71), 1.6, 0.7, "window", "ffffff")
    b.cylinder((0, 4.5, -1.2), 0.12, 6.4, 8, "beam", "6b4a2f")
    b.push((0, 2.8, -2.7), rot_x=0.25)
    b.box((0, 0, 0), (0.12, 0.12, 3.0), "beam", "6b4a2f")
    b.pop()
    b.box((0, 2.3, -3.0), (1.6, 0.8, 0.1), "cloth", "6f7f6a")
    b.blob((0.6, 1.8, -3.2), (0.5, 0.25, 0.4), "cloth", "6f7f6a", subdiv=1, seed=3)
    for i in range(3):
        b.blob((-0.9 + i * 0.4, 1.75, -2.4), (0.14, 0.14, 0.14), "plain", "f28a3a", subdiv=1, seed=i)


def model_boat_sail(b):
    """Small sailboat, 8 m, with a white sail and red stripe."""
    _hull(b, 8.0, 2.8, 1.3, "fbf6ea", deck="d8b07a")
    b.cylinder((0, 5.0, 0.6), 0.1, 8.0, 8, "beam", "8a5a33")
    b.face([(0, 1.6, 0.4), (0, 8.4, 0.5), (0, 1.6, -2.8)], "cloth", "fbf6ea")
    b.face([(0, 1.6, -2.8), (0, 8.4, 0.5), (0, 1.6, 0.4)], "cloth", "fbf6ea")
    b.face([(0.01, 1.6, 0.6), (0.01, 6.0, 0.7), (0.01, 1.6, 3.4)], "cloth", "f2c14e")
    b.face([(0.01, 1.6, 3.4), (0.01, 6.0, 0.7), (0.01, 1.6, 0.6)], "cloth", "f2c14e")
    b.box((0, 1.6, -1.2), (0.1, 0.1, 3.4), "beam", "8a5a33")
    b.box((0, 1.08, -2.3), (1.4, 0.6, 1.6), "planks", "c49a6a")


def model_rowboat(b):
    """Harbour rowboat, 4.5 m."""
    _hull(b, 4.6, 1.8, 0.8, "c0603a", deck="d8b07a")
    for z in (-0.6, 0.6):
        b.box((0, 0.6, z), (1.5, 0.08, 0.36), "planks", "d8b07a")
    for s in (-1, 1):
        b.push((s * 0.95, 0.75, 0.0), rot_y=s * 0.2, rot_z=s * 0.25)
        b.box((0, 0, 0), (0.06, 0.06, 2.6), "beam", "8a5a33")
        b.pop()


# ---------------------------------------------------------------- interior
def model_floor_planks(b):
    """4 x 4 m interior floor tile, top at y = 0.08."""
    b.box((0, 0.04, 0), (4.0, 0.08, 4.0), "planks", "c49a6a", bottom=False)


def model_counter(b):
    """Shop counter with scale, till box and jar of shells."""
    b.box((0, 0.6, 0), (4.0, 1.2, 1.0), "planks", "8a5a33")
    b.box((0, 1.24, 0), (4.2, 0.08, 1.2), "planks", "c49a6a")
    b.box((-1.2, 1.4, 0), (0.7, 0.24, 0.45), "metal", "b08a3a")
    b.cylinder((-1.2, 1.7, 0), 0.04, 0.4, 6, "metal", "b08a3a")
    b.box((-1.2, 1.9, 0), (0.9, 0.04, 0.05), "metal", "b08a3a")
    for s in (-1, 1):
        b.cylinder((-1.2 + s * 0.42, 1.75, 0), 0.16, 0.05, 10, "metal", "d9b04a")
    b.box((1.1, 1.42, 0), (0.7, 0.28, 0.5), "planks", "6b4a2f")
    b.cylinder((0.2, 1.5, 0.1), 0.2, 0.44, 10, "window", "dff0f4")
    for i in range(5):
        b.blob((0.15 + (i % 2) * 0.1, 1.38 + i * 0.07, 0.1), (0.07, 0.04, 0.07), "plain", "f7d9c4", subdiv=1, seed=i)


def model_shelf_goods(b):
    """Wall shelf (3.2 m) stocked with jars, loaves, rope and lanterns."""
    b.box((0, 1.6, -0.15), (3.2, 3.2, 0.1), "planks", "6b4a2f")
    for x in (-1.55, 1.55):
        b.box((x, 1.6, 0.15), (0.1, 3.2, 0.7), "planks", "8a5a33")
    goods = [["d9a35a", "f6e7c1", "c9773a"], ["9fb7c4", "c9d6dc", "f28a7a"], ["e84a5f", "ffd166", "6fae3e"],
             ["d9c08a", "8a5a33", "f2c14e"]]
    for row in range(4):
        y = 0.3 + row * 0.78
        b.box((0, y, 0.15), (3.1, 0.07, 0.65), "planks", "a87a4e")
        for i in range(7):
            col = goods[row][i % 3]
            if row == 1:
                b.cylinder((-1.3 + i * 0.43, y + 0.2, 0.2), 0.14, 0.34, 8, "window", col)
            else:
                b.blob((-1.3 + i * 0.43, y + 0.16, 0.2), (0.17, 0.13, 0.17), "plain", col, subdiv=1, seed=row * 7 + i)


def model_table_round(b):
    b.cylinder((0, 0.95, 0), 1.0, 0.1, 14, "planks", "c49a6a")
    b.cylinder((0, 0.48, 0), 0.12, 0.9, 8, "beam", "6b4a2f")
    b.cylinder((0, 0.05, 0), 0.5, 0.1, 10, "beam", "6b4a2f")


def model_stool(b):
    b.cylinder((0, 0.62, 0), 0.38, 0.1, 10, "planks", "a87a4e")
    for i in range(3):
        a = i / 3 * math.tau
        b.box((math.cos(a) * 0.25, 0.3, math.sin(a) * 0.25), (0.08, 0.62, 0.08), "beam", "6b4a2f")


def model_board_delivery(b):
    """Delivery notice board with pinned order slips (Lieferaufträge)."""
    b.box((0, 2.0, 0), (3.0, 2.0, 0.12), "planks", "8a5a33")
    b.box((0, 2.0, 0.04), (2.7, 1.7, 0.08), "cloth", "c9a46a")
    for x in (-1.4, 1.4):
        b.box((x, 1.2, 0), (0.14, 2.4, 0.14), "beam", "6b4a2f")
    slips = ["fbf6ea", "f7e7a0", "d9ecf2", "fbf6ea", "f2d0c0", "e0f0d0"]
    for i, col in enumerate(slips):
        x = -0.9 + (i % 3) * 0.9
        y = 2.45 - (i // 3) * 0.85
        b.box((x, y, 0.1), (0.62, 0.66, 0.02), "plain", col)
        b.blob((x, y + 0.28, 0.12), (0.04, 0.04, 0.03), "plain", "d94a3d", subdiv=1, seed=i)


def model_crate_pallet(b):
    """Pallet with labelled crates (coloured lids mark the destination)."""
    b.box((0, 0.08, 0), (2.0, 0.16, 1.6), "planks", "b08a5a")
    for i, (x, z) in enumerate(((-0.5, -0.4), (0.5, -0.4), (-0.5, 0.4), (0.5, 0.4))):
        b.box((x, 0.56, z), (0.9, 0.8, 0.75), "planks", "c49a6a")
        b.box((x, 0.98, z), (0.92, 0.06, 0.77), "plain", ["d94a3d", "2f7fb5", "3f9a5a", "e0a030"][i])


# ------------------------------------------------------------- accessories
def model_acc_souwester(b):
    """Yellow fisher's sou'wester (for the village figures' head, ~0.5 m)."""
    b.cylinder((0, 0.0, -0.04), 0.42, 0.05, 14, "cloth", "f2c14e", r_top=0.40)
    b.blob((0, 0.13, 0.0), (0.27, 0.2, 0.27), "cloth", "f2c14e", subdiv=2, seed=1, jitter=0.02)


def model_acc_cap(b):
    """Navy sailor cap with a white top."""
    b.cylinder((0, 0.07, 0), 0.27, 0.15, 14, "cloth", "1f3a5a")
    b.cylinder((0, 0.17, 0), 0.31, 0.06, 14, "cloth", "fbf6ea")
    b.box((0, 0.02, 0.27), (0.32, 0.04, 0.18), "metal", "1a1a1a")


def model_acc_strawhat(b):
    b.cylinder((0, 0.0, 0), 0.45, 0.04, 16, "thatch", "ffffff")
    b.cylinder((0, 0.1, 0), 0.24, 0.2, 14, "thatch", "ffffff", r_top=0.21)
    b.cylinder((0, 0.05, 0), 0.245, 0.06, 14, "cloth", "d94a3d", caps=False)


def model_acc_baker(b):
    b.cylinder((0, 0.06, 0), 0.25, 0.12, 14, "cloth", "fbf6ea")
    b.blob((0, 0.26, 0), (0.3, 0.17, 0.3), "cloth", "fbf6ea", subdiv=2, seed=2, jitter=0.12)


def model_acc_scarf(b):
    b.cylinder((0, 0.0, 0), 0.34, 0.14, 14, "cloth", "d94a3d", r_top=0.3)
    b.push((0.12, -0.18, 0.28), rot_x=0.3)
    b.box((0, 0, 0), (0.14, 0.32, 0.05), "cloth", "d94a3d")
    b.pop()


MODELS = {name[len("model_"):]: fn for name, fn in sorted(globals().items()) if name.startswith("model_")}
## Modules whose final colour comes from the Godot instance colour: their vertex
## colour is forced to 1.0 so instance = target / (2 * tile mean) reproduces the
## same tint formula as the village Builder.
TINTABLE = {"wall_plaster", "wall_brick", "wall_planks", "shutters", "roof_bay", "roof_bay_slate", "roof_hall",
            "roof_front_gable", "roof_end", "gable_front_wall", "gable_stepped"}


def build(name: str) -> dict:
    V.reset()
    builder = V.Builder("sonnenhafen_" + name)
    MODELS[name](builder)
    if name in TINTABLE:
        for face in builder.bm.faces:
            for loop in face.loops:
                alpha = loop[builder.col][3]
                loop[builder.col] = (1.0, 1.0, 1.0, alpha)
    builder.to_object(name)
    path = OUT / f"{name}.glb"
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
    return {"triangles": tris, "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    names = [n for n in MODELS if not args.only or n in args.only.split(",")]
    report_path = OUT / "kit.json"
    report = json.loads(report_path.read_text()).get("modules", {}) if report_path.exists() else {}
    for name in names:
        info = build(name)
        report[name] = info
        print(f"{name}: {info['triangles']} tris, {info['bytes']} bytes")
    report = {k: report[k] for k in sorted(report) if k in MODELS}
    meta = {"generator": "tools/lumo_world_art/build_sonnenhafen_kit.py", "bay": BAY, "storey": STOREY,
            "wall": WALL, "depth": DEPTH, "hall_depth": HALL_DEPTH, "atlas": "village_atlas_albedo.png (shared)",
            "modules": report, "tintable": sorted(TINTABLE),
            "tile_means_linear": {k: [round(c, 5) for c in v] for k, v in V.TILE_MEANS.items()}}
    report_path.write_text(json.dumps(meta, indent=1, sort_keys=True) + "\n")
    total = sum(v["bytes"] for v in report.values())
    assert all(v["triangles"] < 12000 for v in report.values())
    print("modules", len(report), "total bytes", total)


if __name__ == "__main__":
    main()
