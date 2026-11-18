#!/usr/bin/env python3
"""Author every LUMO village building and prop in Blender (bpy 5.3), export GLB.

Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/build_village_models.py [--only house_a] [--check]

Eigenbau: all geometry is generated here from code. One shared texture atlas
(tools/lumo_village_art/make_textures.py) is referenced by tile index only:
  UV0 (TEXCOORD_0) = repeating texture coordinates in metres / tile size,
  UV1 (TEXCOORD_1) = atlas tile centre ((col+.5)/4, (row+.5)/4),
  COLOR_0          = linear tint (rgb) and wave weight (1 - alpha).
Godot draws all of them with one shader (village_building.gdshader), so a
building is usually ONE draw call. Moving parts are separate child objects
named Spin_* (rotate about local X in Godot) or Sway_* (wind).

Coordinates are written in Godot convention (metres, Y up, front = +Z) and
converted to Blender's Z-up on the way in. Footprint centre at ground = origin.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy  # noqa: I001  (bpy must load before bmesh)
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/village3d/models"
TILES = [
    "plaster", "planks", "beam", "roof_clay",
    "roof_slate", "thatch", "stone_wall", "cobble",
    "window", "door", "cloth", "field",
    "metal", "bark", "leaves", "plain",
]
TILE_SCALE = {
    "plaster": 1.6, "planks": 1.6, "beam": 1.1, "roof_clay": 1.7, "roof_slate": 1.7,
    "thatch": 1.5, "stone_wall": 1.5, "cobble": 1.4, "cloth": 1.2, "field": 3.0,
    "metal": 1.0, "bark": 0.9, "leaves": 0.55, "plain": 2.0,
}
FIT = {"window", "door"}


def _tile_means():
    """Mean linear colour of every atlas tile, so vertex tints aim at the
    requested colour while keeping the texture detail (tint = colour / 2·mean)."""
    try:
        from PIL import Image
    except ImportError:
        return {}
    path = ROOT / "assets/creative/village3d/textures/village_atlas_albedo.png"
    if not path.exists():
        return {}
    img = Image.open(path).convert("RGB")
    tile = img.size[0] // 4
    means = {}
    for index, name in enumerate(TILES):
        x, y = (index % 4) * tile, (index // 4) * tile
        crop = img.crop((x, y, x + tile, y + tile)).resize((32, 32))
        px = list(crop.getdata())
        lin_px = [[(c / 255.0 / 12.92 if c / 255.0 <= 0.04045 else ((c / 255.0 + 0.055) / 1.055) ** 2.4) for c in q] for q in px]
        means[name] = tuple(sum(q[i] for q in lin_px) / len(lin_px) for i in range(3))
    return means


TILE_MEANS = _tile_means()


def _leaf_mean():
    try:
        from PIL import Image
        img = Image.open(ROOT / "assets/creative/village3d/textures/leaf_cards.png").convert("RGBA").resize((64, 64))
    except Exception:
        return (0.08, 0.2, 0.04)
    px = [q for q in img.getdata() if q[3] > 128]
    lin_px = [[(c / 255.0 / 12.92 if c / 255.0 <= 0.04045 else ((c / 255.0 + 0.055) / 1.055) ** 2.4) for c in q[:3]] for q in px]
    return tuple(sum(q[i] for q in lin_px) / max(len(lin_px), 1) for i in range(3))


LEAF_MEAN = _leaf_mean()


NEUTRAL_TILES = {"plain", "plaster", "cloth"}


def tint(tile: str, hex_color: str, alpha: float):
    if hex_color.lower() == "ffffff" or tile not in TILE_MEANS:
        return (0.5, 0.5, 0.5, alpha)
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    saturation = (max(srgb) - min(srgb)) / max(max(srgb), 1e-5)
    if tile not in NEUTRAL_TILES and saturation < 0.16:
        # Grey on a coloured texture means "a little darker/weathered".
        value = max(srgb)
        return (0.5 * value, 0.5 * value, 0.5 * value, alpha)
    target = lin(hex_color)
    mean = TILE_MEANS[tile]
    # Neutral tiles take any colour; textured tiles only shift by ±40 % so
    # leaves, wood and roofs keep their painted detail instead of blowing out.
    low, high = (0.0, 1.0) if tile in NEUTRAL_TILES else (0.3, 0.7)
    return tuple(min(high, max(low, target[i] / max(2.0 * mean[i], 0.02))) for i in range(3)) + (alpha,)


def lin(hex_color: str, alpha: float = 1.0):
    c = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (alpha,)


def g2b(v):
    """Godot (x, y up, z front) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


class Builder:
    """Accumulates tagged faces in one bmesh; transforms via a matrix stack (Godot space)."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.tile = self.bm.faces.layers.int.new("tile")
        self.fit = self.bm.faces.layers.int.new("fit")
        self.smooth = self.bm.faces.layers.int.new("smooth")
        self.card = self.bm.faces.layers.int.new("card")
        self.card_center = {}
        self._card_meta = []
        self.col = self.bm.loops.layers.float_color.new("Color")
        self.stack = [Matrix.Identity(4)]
        self.rng = random.Random(hash(name) & 0xFFFF)

    # -- transforms (Godot space) --
    def push(self, at=(0, 0, 0), rot_y=0.0, rot_x=0.0, rot_z=0.0, scale=1.0):
        m = (Matrix.Translation(Vector(at)) @ Matrix.Rotation(rot_y, 4, 'Y')
             @ Matrix.Rotation(rot_x, 4, 'X') @ Matrix.Rotation(rot_z, 4, 'Z'))
        if scale != 1.0:
            m = m @ Matrix.Scale(scale, 4)
        self.stack.append(self.stack[-1] @ m)

    def pop(self):
        self.stack.pop()

    def _v(self, p):
        return self.bm.verts.new(g2b(self.stack[-1] @ Vector(p)))

    def face(self, pts, tile="plain", color="ffffff", fit=False, wave=0.0):
        verts = [self._v(p) for p in pts]
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f[self.tile] = TILES.index(tile)
        f[self.fit] = 1 if (fit or tile in FIT) else 0
        c = tint(tile, color, 1.0 - wave)
        for loop in f.loops:
            loop[self.col] = c
        return f

    # -- primitives --
    def box(self, c, s, tile="plain", color="ffffff", top=None, top_color=None, rot_y=0.0, wave=0.0, bottom=True):
        x, y, z = (s[0] / 2, s[1] / 2, s[2] / 2)
        self.push(c, rot_y)
        p = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        self.face([p[4], p[5], p[6], p[7]], tile, color, wave=wave)  # +Z front
        self.face([p[1], p[0], p[3], p[2]], tile, color, wave=wave)  # -Z back
        self.face([p[5], p[1], p[2], p[6]], tile, color, wave=wave)  # +X
        self.face([p[0], p[4], p[7], p[3]], tile, color, wave=wave)  # -X
        self.face([p[7], p[6], p[2], p[3]], top or tile, top_color or color, wave=wave)  # top
        if bottom:
            self.face([p[0], p[1], p[5], p[4]], tile, color, wave=wave)
        self.pop()

    def panel(self, c, w, h, tile, color="ffffff", rot_y=0.0, depth=0.0):
        """Front-facing rectangle (normal +Z after rot_y)."""
        self.push(c, rot_y)
        self.face([(-w / 2, -h / 2, depth), (w / 2, -h / 2, depth), (w / 2, h / 2, depth), (-w / 2, h / 2, depth)],
                  tile, color, fit=tile in FIT)
        self.pop()

    def cylinder(self, c, r, h, segs=10, tile="plain", color="ffffff", axis="y", caps=True, r_top=None, wave=0.0,
                 cap_tile=None):
        r_top = r if r_top is None else r_top
        rot = {"y": (0, 0, 0), "x": (0, 0, -math.pi / 2), "z": (0, math.pi / 2, 0)}[axis]
        self.push(c, rot_z=rot[2], rot_x=rot[1])
        ring_b = [(math.cos(a) * r, -h / 2, math.sin(a) * r) for a in [i / segs * math.tau for i in range(segs)]]
        ring_t = [(math.cos(a) * r_top, h / 2, math.sin(a) * r_top) for a in [i / segs * math.tau for i in range(segs)]]
        for i in range(segs):
            j = (i + 1) % segs
            self.face([ring_b[j], ring_b[i], ring_t[i], ring_t[j]], tile, color, wave=wave)
        if caps:
            if r_top > 0.001:
                self.face(list(reversed(ring_t)), cap_tile or tile, color, wave=wave)
            self.face(ring_b, cap_tile or tile, color, wave=wave)
        self.pop()

    def cone(self, c, r, h, segs=10, tile="plain", color="ffffff", wave=0.0):
        self.push(c)
        tip = (0, h, 0)
        ring = [(math.cos(a) * r, 0, math.sin(a) * r) for a in [i / segs * math.tau for i in range(segs)]]
        for i in range(segs):
            j = (i + 1) % segs
            self.face([ring[j], ring[i], tip], tile, color, wave=wave)
        self.face(ring, tile, color, wave=wave)
        self.pop()

    def blob(self, c, radii, tile="leaves", color="ffffff", subdiv=2, seed=0, jitter=0.18, wave=0.0, flat_bottom=False,
             smooth=None):
        """Displaced icosphere with shared vertices: canopies, bushes, hay (smooth), rocks (faceted)."""
        if smooth is None:
            smooth = tile in ("leaves", "thatch", "cloth", "plain")
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        r = random.Random(seed)
        self.push(c)
        mapped = {}
        for v in tmp.verts:
            k = 1.0 + (r.random() - 0.5) * 2 * jitter
            # tmp is generated in Blender space; read it as Godot xyz (symmetric shape).
            x, y, z = v.co.x * radii[0] * k, v.co.z * radii[1] * k, v.co.y * radii[2] * k
            if flat_bottom:
                y = max(y, -radii[1] * 0.15)
            mapped[v.index] = self._v((x, y, z))
        col = tint(tile, color, 1.0 - wave)
        for f in tmp.faces:
            verts = [mapped[v.index] for v in reversed(f.verts)]
            try:
                nf = self.bm.faces.new(verts)
            except ValueError:
                continue
            nf[self.tile] = TILES.index(tile)
            nf[self.fit] = 0
            nf[self.smooth] = 1 if smooth else 0
            for loop in nf.loops:
                loop[self.col] = col
        self.pop()
        tmp.free()

    def gable_roof(self, c, w, d, rise, over=0.35, thick=0.14, tile="roof_clay", color="ffffff",
                   gable_tile="plaster", gable_color="ffffff", ridge_axis="x"):
        """Pitched roof with two slabs, overhang and filled gable walls (ridge along X)."""
        self.push(c, 0.0 if ridge_axis == "x" else math.pi / 2)
        if ridge_axis != "x":
            w, d = d, w
        hw = w / 2 + over
        hd = d / 2 + over
        slope = math.atan2(rise, d / 2)
        drop = over * math.tan(slope)
        for side in (1, -1):
            # outer slab surface
            a = (-hw, -drop, side * hd)
            b = (hw, -drop, side * hd)
            t1 = (hw, rise, 0)
            t0 = (-hw, rise, 0)
            if side > 0:
                self.face([a, b, t1, t0], tile, color)
            else:
                self.face([b, a, t0, t1], tile, color)
            # underside
            ua = (a[0], a[1] - thick, a[2])
            ub = (b[0], b[1] - thick, b[2])
            ut1 = (t1[0], t1[1] - thick, 0)
            ut0 = (t0[0], t0[1] - thick, 0)
            if side > 0:
                self.face([ut0, ut1, ub, ua], "planks", "8a6a4a")
                self.face([ua, ub, b, a], "beam", "6b4a2f")
            else:
                self.face([ut1, ut0, ua, ub], "planks", "8a6a4a")
                self.face([ub, ua, a, b], "beam", "6b4a2f")
            # slab ends
            for x in (-hw, hw):
                e = [(x, -drop, side * hd), (x, rise, 0), (x, rise - thick, 0), (x, -drop - thick, side * hd)]
                if (x > 0) == (side > 0):
                    self.face(e, "beam", "6b4a2f")
                else:
                    self.face(list(reversed(e)), "beam", "6b4a2f")
        # gable triangles (walls) at both ends
        gx = w / 2
        for x in (-gx, gx):
            tri = [(x, 0, -d / 2), (x, 0, d / 2), (x, rise - thick, 0)]
            self.face(tri if x > 0 else list(reversed(tri)), gable_tile, gable_color)
        # ridge cap
        self.box((0, rise + 0.03, 0), (w + over * 2 + 0.1, 0.12, 0.22), "beam", "5a3a22")
        self.pop()

    def hip_roof(self, c, w, d, rise, over=0.3, tile="roof_slate", color="ffffff"):
        self.push(c)
        hw, hd = w / 2 + over, d / 2 + over
        top = min(hw, hd) * 0.25
        r0 = (-hw, 0, -hd)
        r1 = (hw, 0, -hd)
        r2 = (hw, 0, hd)
        r3 = (-hw, 0, hd)
        if hw >= hd:
            t0, t1 = (-hw + hd, rise, 0), (hw - hd, rise, 0)
            self.face([r3, r2, t1, t0], tile, color)
            self.face([r1, r0, t0, t1], tile, color)
            self.face([r2, r1, t1], tile, color)
            self.face([r0, r3, t0], tile, color)
        else:
            t0, t1 = (0, rise, -hd + hw), (0, rise, hd - hw)
            self.face([r3, r2, t1], tile, color)
            self.face([r1, r0, t0], tile, color)
            self.face([r2, r1, t0, t1], tile, color)
            self.face([r0, r3, t1, t0], tile, color)
        self.face([r0, r1, r2, r3], "planks", "8a6a4a")
        self.pop()

    def pyramid_roof(self, c, w, d, rise, tile="roof_slate", color="ffffff", over=0.25):
        self.push(c)
        hw, hd = w / 2 + over, d / 2 + over
        r = [(-hw, 0, -hd), (hw, 0, -hd), (hw, 0, hd), (-hw, 0, hd)]
        tip = (0, rise, 0)
        for i in range(4):
            self.face([r[(i + 1) % 4], r[i], tip][::-1] if False else [r[i], r[(i + 1) % 4], tip][::-1], tile, color)
        self.face(r, "planks", "8a6a4a")
        self.pop()

    # -- composite details --
    def window(self, c, w=0.62, h=0.78, rot_y=0.0, shutters="5f8fb0", box=True, sill=True):
        self.push(c, rot_y)
        self.box((0, 0, 0.02), (w + 0.12, h + 0.12, 0.08), "beam", "f2e6cc")
        self.panel((0, 0, 0.065), w, h, "window")
        if sill:
            self.box((0, -h / 2 - 0.08, 0.1), (w + 0.26, 0.07, 0.2), "beam", "e9dcc0")
        if shutters:
            for side in (-1, 1):
                self.box((side * (w / 2 + 0.2), 0, 0.05), (0.26, h + 0.06, 0.05), "planks", shutters)
        if box:
            self.box((0, -h / 2 - 0.2, 0.17), (w + 0.1, 0.16, 0.18), "planks", "8a5a33")
            for i in range(5):
                x = -w / 2 + 0.06 + i * (w - 0.12) / 4
                col = ["e84a5f", "ffd166", "f78fb3", "ffffff", "ff9f43"][(i + int(abs(c[0]) * 7)) % 5]
                self.blob((x, -h / 2 - 0.07, 0.19), (0.07, 0.07, 0.07), "plain", col, subdiv=1, seed=i)
                self.blob((x + 0.04, -h / 2 - 0.1, 0.16), (0.08, 0.06, 0.07), "leaves", "6fa84a", subdiv=1, seed=i + 9)
        self.pop()

    def door(self, c, w=0.86, h=1.55, rot_y=0.0, frame="6b4a2f", step=True, lamp=True):
        self.push(c, rot_y)
        self.box((0, h / 2, 0.02), (w + 0.18, h + 0.12, 0.1), "beam", frame)
        self.panel((0, h / 2, 0.075), w, h, "door")
        if step:
            self.box((0, 0.06, 0.32), (w + 0.5, 0.12, 0.5), "stone_wall", "c9c0b0")
        if lamp:
            self.box((w / 2 + 0.28, h + 0.05, 0.12), (0.12, 0.2, 0.12), "metal", "3a3a3a")
            self.panel((w / 2 + 0.28, h + 0.05, 0.19), 0.09, 0.13, "window", "ffd27a")
        self.pop()

    def timber_frame(self, w, h, d, y0=0.0, color="5a3a22"):
        """Half-timber beams on the four walls of a w x h x d block."""
        t = 0.1
        for zf, rot in ((d / 2, 0.0), (-d / 2, math.pi)):
            self.push((0, y0, zf), rot)
            for x in (-w / 2 + 0.05, w / 2 - 0.05):
                self.box((x, h / 2, 0.03), (t, h, 0.07), "beam", color)
            self.box((0, h - 0.05, 0.03), (w, t, 0.07), "beam", color)
            self.box((0, h * 0.5, 0.03), (w, t * 0.8, 0.07), "beam", color)
            self.pop()
        for xf, rot in ((w / 2, math.pi / 2), (-w / 2, -math.pi / 2)):
            self.push((xf, y0, 0), rot)
            for x in (-d / 2 + 0.05, 0.0, d / 2 - 0.05):
                self.box((x, h / 2, 0.03), (t, h, 0.07), "beam", color)
            self.box((0, h - 0.05, 0.03), (d, t, 0.07), "beam", color)
            for s in (-1, 1):
                ang = math.atan2(h * 0.45, d * 0.25) * s
                self.push((s * d * 0.25, h * 0.27, 0.03), rot_z=ang)
                self.box((0, 0, 0), (math.hypot(h * 0.45, d * 0.5) * 0.98, t * 0.8, 0.06), "beam", color)
                self.pop()
            self.pop()

    def plinth(self, w, d, top=0.22, color="a69e8e"):
        self.box((0, (top - 0.9) / 2, 0), (w, top + 0.9, d), "stone_wall", color, bottom=False)

    def chimney(self, c, h=1.6, color="9a8f80"):
        self.box((c[0], c[1] + h / 2, c[2]), (0.5, h, 0.5), "stone_wall", color)
        self.box((c[0], c[1] + h + 0.06, c[2]), (0.62, 0.12, 0.62), "stone_wall", "7d7468")

    def fence(self, a, b, posts=None, color="9a7048", h=0.7):
        a = Vector(a)
        b = Vector(b)
        length = (b - a).length
        n = posts or max(2, int(length / 0.9) + 1)
        ang = math.atan2(-(b - a).z, (b - a).x)
        mid = (a + b) / 2
        for i in range(n):
            p = a + (b - a) * (i / (n - 1))
            self.box((p.x, h / 2, p.z), (0.09, h, 0.09), "beam", color)
        for y in (h * 0.4, h * 0.8):
            self.box((mid.x, y, mid.z), (length, 0.06, 0.04), "planks", color, rot_y=ang)

    def crate(self, c, s=0.42, color="b0814f", rot=0.0):
        self.box((c[0], c[1] + s / 2, c[2]), (s, s, s), "planks", color, rot_y=rot)

    def barrel(self, c, r=0.22, h=0.55, color="8a5a33"):
        self.cylinder((c[0], c[1] + h / 2, c[2]), r, h, 10, "planks", color, r_top=r * 0.92)
        for y in (0.12, h - 0.12):
            self.cylinder((c[0], c[1] + y, c[2]), r * 1.03, 0.04, 10, "metal", "4a4a4a", caps=False)

    def flowers(self, c, n=6, spread=0.5, seed=1):
        r = random.Random(seed)
        for i in range(n):
            x = c[0] + (r.random() - 0.5) * spread * 2
            z = c[2] + (r.random() - 0.5) * spread
            self.blob((x, c[1] + 0.12, z), (0.16, 0.13, 0.16), "leaves", "5f9a3e", subdiv=1, seed=r.randint(0, 99))
            col = ["e84a5f", "ffd166", "f78fb3", "ffffff", "b388ff", "ff9f43"][r.randint(0, 5)]
            self.blob((x, c[1] + 0.26, z), (0.07, 0.06, 0.07), "plain", col, subdiv=1, seed=i)

    def tree(self, c, height=4.0, crown=1.5, kind="round", seed=1, wave=0.12):
        r = random.Random(seed)
        if kind == "fir":
            self.cylinder((c[0], c[1] + height * 0.2, c[2]), 0.16, height * 0.4, 7, "bark", "6b4a35")
            for i in range(4):
                y = c[1] + height * (0.22 + i * 0.19)
                rr = crown * (1.0 - i * 0.22)
                self.cone((c[0], y, c[2]), rr, height * 0.34, 9, "leaves", "3d6b3a", wave=wave)
        else:
            self.cylinder((c[0], c[1] + height * 0.3, c[2]), 0.14, height * 0.6, 7, "bark", "6e4f3a", r_top=0.1)
            for i in range(3):
                off = ((r.random() - 0.5) * crown * 0.8, height * (0.62 + r.random() * 0.2), (r.random() - 0.5) * crown * 0.8)
                rad = crown * (0.6 + r.random() * 0.35)
                self.blob((c[0] + off[0], c[1] + off[1], c[2] + off[2]), (rad, rad * 0.85, rad), "leaves",
                          ["8ab84f", "7aa846", "9cc25a"][i], subdiv=2, seed=seed * 10 + i, wave=wave)

    def cards(self, c, radius, count, seed, color="5f8f38", size=(0.75, 1.15), up_bias=0.35, droop=0.0,
              vertical=1.0, inner=0.55):
        """Alpha-cut leaf cards around a crown cluster (material slot 1, leaf_cards.png).
        Normals point away from the cluster centre so the crown shades like a soft volume;
        cards low in the crown are darker (self-shadowed underside)."""
        r = random.Random(seed)
        cx, cy, cz = c
        base = lin(color)
        for _ in range(count):
            while True:
                d = Vector((r.uniform(-1, 1), r.uniform(-1, 1) + up_bias, r.uniform(-1, 1)))
                if 0.05 < d.length <= 1.25:
                    break
            d.normalize()
            dist = radius * r.uniform(inner, 1.0)
            pos = Vector((cx + d.x * dist, cy + d.y * dist * vertical, cz + d.z * dist))
            n = (d + Vector((r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6) - droop, r.uniform(-0.6, 0.6)))).normalized()
            helper = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))
            u = n.cross(helper).normalized()
            v = n.cross(u).normalized()
            spin = r.uniform(0, math.tau)
            u, v = u * math.cos(spin) + v * math.sin(spin), v * math.cos(spin) - u * math.sin(spin)
            half = r.uniform(*size) * 0.5
            pts = [pos - u * half - v * half, pos + u * half - v * half, pos + u * half + v * half, pos - u * half + v * half]
            verts = [self._v(tuple(q)) for q in pts]
            try:
                f = self.bm.faces.new(verts)
            except ValueError:
                continue
            f[self.tile] = TILES.index("leaves")
            f[self.card] = 1
            height = (pos.y - (cy - radius)) / max(2 * radius, 0.01)
            shade = 0.42 + 0.58 * max(0.0, min(1.0, height)) * (0.75 + 0.25 * dist / radius)
            jitter = r.uniform(0.85, 1.12)
            rel = [min(0.85, max(0.2, 0.5 * base[i] / max(LEAF_MEAN[i], 0.01))) for i in range(3)]
            col = (rel[0] * shade * jitter, rel[1] * shade, rel[2] * shade * (2.0 - jitter), 1.0 - 0.35)
            centre = self.stack[-1] @ Vector((cx, cy, cz))
            self.card_center[f.index if False else id(f)] = None
            for loop in f.loops:
                loop[self.col] = col
            f.normal_update()
            self._card_meta.append((f, g2b(centre)))

    # -- finish --
    def to_object(self, name, parent=None):
        bm = self.bm
        bm.normal_update()
        uv0 = bm.loops.layers.uv.new("UVMap")
        uv1 = bm.loops.layers.uv.new("TileMap")
        up = Vector((0, 0, 1))
        card_centres = {}
        for f, centre in self._card_meta:
            if f.is_valid:
                card_centres[f] = centre
        for f in bm.faces:
            if f[self.card]:
                f.material_index = 1
                for loop, uv in zip(f.loops, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]):
                    loop[uv0].uv = uv
                    loop[uv1].uv = (0.0, 0.0)
                continue
            tile = TILES[f[self.tile]]
            col = TILES.index(tile) % 4
            row = TILES.index(tile) // 4
            n = f.normal
            if abs(n.z) > 0.985:
                u_axis, v_axis = Vector((1, 0, 0)), Vector((0, 1, 0))
            else:
                v_axis = (up - n * n.dot(up)).normalized()
                u_axis = v_axis.cross(n).normalized()
            coords = [(l.vert.co.dot(u_axis), l.vert.co.dot(v_axis)) for l in f.loops]
            if f[self.fit]:
                us = [c[0] for c in coords]
                vs = [c[1] for c in coords]
                du = max(max(us) - min(us), 1e-5)
                dv = max(max(vs) - min(vs), 1e-5)
                coords = [(0.002 + 0.996 * (c[0] - min(us)) / du, 0.002 + 0.996 * (c[1] - min(vs)) / dv) for c in coords]
            else:
                s = TILE_SCALE.get(tile, 1.6)
                coords = [(c[0] / s, c[1] / s) for c in coords]
            for loop, uv in zip(f.loops, coords):
                loop[uv0].uv = uv
                loop[uv1].uv = ((col + 0.5) / 4.0, 1.0 - (row + 0.5) / 4.0)
        # Per-loop normals: cards bend away from their crown centre (soft volume).
        normal_layer = bm.loops.layers.float_vector.new("card_normal") if hasattr(bm.loops.layers, "float_vector") else None
        for f in bm.faces:
            for loop in f.loops:
                if f in card_centres:
                    n = (loop.vert.co - card_centres[f])
                    n = (n.normalized() * 0.75 + Vector((0, 0, 1)) * 0.35).normalized() if n.length > 1e-4 else Vector((0, 0, 1))
                elif f[self.smooth]:
                    n = loop.vert.normal.copy()
                else:
                    n = f.normal.copy()
                if normal_layer is not None:
                    loop[normal_layer] = n
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        loop_normals = []
        for f in bm.faces:
            for loop in f.loops:
                loop_normals.append(None)
        mesh = bpy.data.meshes.new(name + "_mesh")
        bm.to_mesh(mesh)
        has_cards = bool(card_centres)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = parent
        mat = bpy.data.materials.get("village_atlas") or bpy.data.materials.new("village_atlas")
        mesh.materials.append(mat)
        if has_cards:
            foliage = bpy.data.materials.get("village_foliage") or bpy.data.materials.new("village_foliage")
            mesh.materials.append(foliage)
            attr = mesh.attributes.get("card_normal")
            if attr is not None:
                values = [0.0] * (len(mesh.loops) * 3)
                attr.data.foreach_get("vector", values)
                normals = [tuple(values[i * 3:i * 3 + 3]) for i in range(len(mesh.loops))]
                mesh.normals_split_custom_set(normals)
        smooth_layer = mesh.attributes.get("smooth")
        flags = [0] * len(mesh.polygons)
        if smooth_layer is not None:
            smooth_layer.data.foreach_get("value", flags)
        for p in mesh.polygons:
            p.use_smooth = bool(flags[p.index])
        attr = mesh.color_attributes.get("Color")
        if attr is not None:
            mesh.color_attributes.active_color = attr
            mesh.color_attributes.active_color_name = attr.name
            mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(attr)
        return obj


# --------------------------------------------------------------------- models

def house_body(b, w, d, wall_h, wall_tile="plaster", wall_color="f4ead2", timber=True, plinth_color="a69e8e"):
    b.plinth(w + 0.2, d + 0.2, color=plinth_color)
    b.box((0, 0.22 + wall_h / 2, 0), (w, wall_h, d), wall_tile, wall_color, bottom=False)
    if timber:
        b.timber_frame(w + 0.02, wall_h, d + 0.02, y0=0.22)


def model_house_a(b):
    """Fachwerkhaus: half-timber cottage, clay roof, flower boxes, bench."""
    w, d, wh = 3.4, 2.8, 2.1
    house_body(b, w, d, wh)
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.5, tile="roof_clay", color="ffffff", gable_color="f4ead2")
    b.chimney((0.9, 0.22 + wh + 0.6, -0.5), 1.4)
    b.door((-0.7, 0.22, d / 2), lamp=True)
    for x in (0.55, 1.25):
        b.window((x, 0.22 + 1.05, d / 2 + 0.01), w=0.5, h=0.62, shutters="5f8fb0")
    for z in (-0.6, 0.6):
        b.window((w / 2 + 0.01, 0.22 + 1.05, z), w=0.5, h=0.62, rot_y=math.pi / 2, shutters="5f8fb0", box=False)
        b.window((-w / 2 - 0.01, 0.22 + 1.05, z), w=0.5, h=0.62, rot_y=-math.pi / 2, shutters="5f8fb0", box=False)
    b.window((0, 0.22 + wh + 0.55, d / 2 + 0.25), w=0.45, h=0.5, shutters=None, box=False, sill=False)
    b.box((0.8, 0.45, d / 2 + 0.75), (1.1, 0.08, 0.36), "planks", "a87a4e")
    for x in (0.35, 1.25):
        b.box((x, 0.22, d / 2 + 0.75), (0.08, 0.44, 0.3), "beam", "6b4a2f")
    b.flowers((-1.45, 0.0, d / 2 + 0.75), 5, 0.3, seed=3)
    b.barrel((-1.55, 0.0, -0.9))


def model_house_b(b):
    """Steinhaus: stone cottage with slate roof and dormer."""
    w, d, wh = 3.3, 2.9, 2.0
    b.plinth(w + 0.2, d + 0.2, color="8f877a")
    b.box((0, 0.22 + wh / 2, 0), (w, wh, d), "stone_wall", "d9d2c4", bottom=False)
    for x in (-w / 2, w / 2):
        for z in (-d / 2, d / 2):
            b.box((x, 0.22 + wh / 2, z), (0.3, wh + 0.04, 0.3), "stone_wall", "b8b0a0")
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.35, tile="roof_slate", color="ffffff", gable_tile="stone_wall",
                 gable_color="d9d2c4")
    b.box((0.7, 0.22 + wh + 0.55, d / 2 - 0.05), (0.9, 0.75, 0.9), "plaster", "f4ead2")
    b.pyramid_roof((0.7, 0.22 + wh + 0.92, d / 2 - 0.05), 0.9, 0.9, 0.5, tile="roof_slate", over=0.1)
    b.window((0.7, 0.22 + wh + 0.55, d / 2 + 0.41), w=0.42, h=0.46, shutters=None, box=False, sill=False)
    b.chimney((-1.0, 0.22 + wh + 0.5, -0.4), 1.5, color="8f877a")
    b.door((0.0, 0.22, d / 2), frame="4a3a2a")
    for x in (-1.0, 1.0):
        b.window((x, 0.22 + 1.0, d / 2 + 0.01), w=0.55, h=0.66, shutters="7a9a5a")
    for z in (-0.5, 0.6):
        b.window((w / 2 + 0.01, 0.22 + 1.0, z), w=0.5, h=0.6, rot_y=math.pi / 2, shutters="7a9a5a", box=False)
        b.window((-w / 2 - 0.01, 0.22 + 1.0, z), w=0.5, h=0.6, rot_y=-math.pi / 2, shutters="7a9a5a", box=False)
    b.fence((-2.0, 0, 1.9), (-0.7, 0, 1.9), color="c9b48a", h=0.55)
    b.fence((0.7, 0, 1.9), (2.0, 0, 1.9), color="c9b48a", h=0.55)
    b.flowers((1.4, 0.0, 1.6), 4, 0.35, seed=8)
    b.tree((-1.75, 0.0, -1.6), 3.2, 0.9, seed=5)


def model_house_c(b):
    """Großes Bürgerhaus: two storeys, jettied upper floor, dormers, balcony."""
    w, d = 3.5, 2.9
    b.plinth(w + 0.2, d + 0.2)
    b.box((0, 0.22 + 0.9, 0), (w, 1.8, d), "plaster", "f2d9b8", bottom=False)
    b.timber_frame(w + 0.02, 1.8, d + 0.02, y0=0.22, color="6b3a22")
    b.box((0, 2.02 + 0.85, 0.08), (w + 0.2, 1.7, d + 0.16), "plaster", "fbf0dc", bottom=False)
    b.timber_frame(w + 0.22, 1.7, d + 0.18, y0=2.02, color="6b3a22")
    b.gable_roof((0, 3.72, 0.08), w + 0.2, d + 0.16, 1.7, tile="roof_clay", color="e9b8a0", gable_color="fbf0dc")
    b.chimney((-1.0, 4.3, -0.6), 1.3)
    b.chimney((1.1, 4.1, 0.5), 1.4)
    b.door((0.0, 0.22, d / 2), w=0.95, h=1.6)
    for x in (-1.1, 1.1):
        b.window((x, 1.15, d / 2 + 0.01), w=0.6, h=0.7, shutters="b5543a")
    for x in (-1.15, 0.0, 1.15):
        b.window((x, 2.85, d / 2 + 0.17), w=0.55, h=0.7, shutters="b5543a")
    for z in (-0.6, 0.6):
        for side in (-1, 1):
            b.window((side * (w / 2 + 0.01), 1.15, z), w=0.5, h=0.62, rot_y=side * math.pi / 2, shutters="b5543a", box=False)
            b.window((side * (w / 2 + 0.11), 2.85, z), w=0.5, h=0.62, rot_y=side * math.pi / 2, shutters="b5543a", box=False)
    b.box((0, 2.0, d / 2 + 0.55), (1.4, 0.1, 0.7), "planks", "9a6a40")
    b.fence((-0.7, 2.05, d / 2 + 0.88), (0.7, 2.05, d / 2 + 0.88), color="7a4a2a", h=0.5)
    b.flowers((-1.4, 0.0, 1.85), 4, 0.3, seed=11)
    b.flowers((1.4, 0.0, 1.85), 4, 0.3, seed=12)


def model_farm(b):
    """Bauernhof: red barn with hay loft, fenced vegetable field, haystack, cart."""
    b.plinth(2.5, 2.2, color="9a8f80")
    b.box((-0.9, 0.22 + 0.95, -0.9), (2.4, 1.9, 2.0), "planks", "b5433a", bottom=False)
    b.gable_roof((-0.9, 2.12, -0.9), 2.4, 2.0, 1.2, tile="roof_slate", color="c8c8c8", gable_tile="planks",
                 gable_color="b5433a")
    b.box((-0.9, 0.22 + 0.7, 0.12), (1.0, 1.4, 0.06), "planks", "f2ead8")
    for s in (-1, 1):
        b.push((-0.9, 0.92, 0.15), rot_z=s * 0.95)
        b.box((0, 0, 0), (1.5, 0.08, 0.05), "beam", "f2ead8")
        b.pop()
    b.panel((-0.9, 2.45, 0.13), 0.55, 0.55, "planks", "5a2a22")
    # field with crops
    b.box((1.05, 0.02, 0.85), (2.2, 0.08, 2.6), "field", "ffffff", bottom=False)
    for row in range(5):
        for k in range(6):
            x = 0.2 + row * 0.42
            z = -0.25 + k * 0.42
            if row % 2 == 0:
                b.blob((x, 0.18, z), (0.14, 0.11, 0.14), "leaves", "6fae3e", subdiv=1, seed=row * 7 + k)
            else:
                b.blob((x, 0.14, z), (0.1, 0.1, 0.1), "plain", "f08a2c", subdiv=1, seed=row * 9 + k)
                b.blob((x, 0.26, z), (0.06, 0.1, 0.06), "leaves", "4f8f2e", subdiv=1, seed=row * 3 + k)
    b.fence((-0.05, 0, -0.5), (2.2, 0, -0.5), color="c9b48a", h=0.5)
    b.fence((2.2, 0, -0.5), (2.2, 0, 2.2), color="c9b48a", h=0.5)
    b.fence((-0.05, 0, 2.2), (2.2, 0, 2.2), color="c9b48a", h=0.5)
    b.blob((-1.6, 0.55, 1.2), (0.6, 0.6, 0.6), "thatch", "ffffff", subdiv=2, seed=4, jitter=0.08, flat_bottom=True)
    b.blob((-0.6, 0.38, 1.6), (0.42, 0.42, 0.42), "thatch", "ffffff", subdiv=2, seed=6, jitter=0.08, flat_bottom=True)
    b.barrel((-2.0, 0.0, -1.7))
    b.crate((-1.95, 0.0, 0.25), 0.4)


def model_lumber(b):
    """Holzwerkstatt: open sawmill shed, saw wheel (Spin_Saw), log piles, chopping block."""
    b.plinth(3.2, 2.4, color="8f877a")
    for x in (-1.5, 1.5):
        for z in (-1.1, 1.1):
            b.box((x, 0.22 + 1.1, z), (0.2, 2.2, 0.2), "beam", "6b4a2f")
    b.box((0, 0.22 + 0.75, -1.15), (3.2, 1.5, 0.12), "planks", "a87a4e")
    b.gable_roof((0, 2.42, 0), 3.2, 2.4, 0.9, over=0.4, tile="roof_slate", color="d0c8b8", gable_tile="planks",
                 gable_color="a87a4e")
    b.box((0, 0.22 + 0.45, 0.2), (2.2, 0.12, 0.7), "planks", "c49a6a")
    b.cylinder((-0.2, 0.22 + 0.65, 0.2), 0.16, 1.8, 8, "bark", "ffffff", axis="x")
    for row in range(3):
        for k in range(4 - row):
            b.cylinder((-1.2 + k * 0.38 + row * 0.19, 0.18 + row * 0.33, 1.75), 0.18, 1.6, 8, "bark", "ffffff", axis="z",
                       cap_tile="planks")
    for k in range(3):
        b.box((1.5, 0.12 + k * 0.1, 1.6 - k * 0.05), (1.0, 0.08, 0.35), "planks", "d8b07a", rot_y=0.1 * k)
    b.cylinder((1.75, 0.25, -1.75), 0.3, 0.5, 10, "bark", "ffffff")
    b.box((1.75, 0.6, -1.75), (0.08, 0.35, 0.08), "beam", "6b4a2f")
    b.push((1.75, 0.68, -1.6), rot_x=-0.6)
    b.box((0, 0, 0), (0.06, 0.12, 0.3), "metal", "7a7f88")
    b.pop()


def model_lumber_spin(b):
    b.cylinder((0, 0, 0), 0.48, 0.04, 16, "metal", "c8ccd2", axis="x")
    for i in range(16):
        a = i / 16 * math.tau
        b.box((0, math.sin(a) * 0.5, math.cos(a) * 0.5), (0.03, 0.06, 0.06), "metal", "e8ecef")


def model_quarry(b):
    """Steinbruch: rock face, cut blocks, wooden crane with winch, mine cart."""
    b.blob((-0.6, 0.6, -1.0), (2.0, 1.6, 1.2), "stone_wall", "b9b2a6", subdiv=2, seed=21, jitter=0.25, flat_bottom=True)
    b.blob((1.1, 0.4, -1.4), (1.1, 1.0, 0.8), "stone_wall", "a39c90", subdiv=2, seed=22, jitter=0.25, flat_bottom=True)
    b.box((0, 0.03, 0.6), (4.2, 0.06, 2.6), "cobble", "c9c0b0", bottom=False)
    for i, (x, z, s) in enumerate([(-1.4, 0.4, 0.55), (-0.75, 0.55, 0.5), (-1.1, 1.2, 0.45), (0.5, 1.4, 0.5),
                                   (1.05, 1.35, 0.5), (0.8, 1.35, 0.45)]):
        b.box((x, s / 2 + 0.03, z), (s * 1.3, s, s), "stone_wall", "d4cdbf", rot_y=0.2 * i)
    b.box((-1.1, 0.03 + 0.5 + 0.22, 0.45), (0.7, 0.44, 0.48), "stone_wall", "c4bdaf")
    # crane
    b.box((1.4, 1.5, 0.0), (0.18, 3.0, 0.18), "beam", "6b4a2f")
    b.push((0.9, 2.85, 0.0), rot_z=-0.08)
    b.box((0, 0, 0), (1.6, 0.14, 0.14), "beam", "6b4a2f")
    b.pop()
    b.cylinder((0.25, 2.2, 0.0), 0.015, 1.3, 4, "metal", "3a3a3a")
    b.box((0.25, 1.45, 0.0), (0.4, 0.3, 0.4), "stone_wall", "d4cdbf")
    b.cylinder((1.4, 0.7, 0.3), 0.22, 0.5, 10, "planks", "8a5a33", axis="z")
    # cart
    b.box((0.2, 0.45, 1.6), (0.9, 0.35, 0.6), "planks", "8a5a33")
    for x in (-0.15, 0.55):
        for z in (1.28, 1.92):
            b.cylinder((x, 0.2, z), 0.18, 0.06, 10, "metal", "3a3a3a", axis="z")
    for i in range(4):
        b.blob((0.05 + i * 0.12, 0.7, 1.6), (0.12, 0.1, 0.12), "stone_wall", "a8a090", subdiv=1, seed=i)


def model_market(b):
    """Marktplatz: cobbled square, three stalls with striped awnings, produce, lamp post."""
    b.box((0, 0.03, 0), (4.3, 0.08, 4.3), "cobble", "d9cfbe", bottom=False)
    stalls = [((-1.2, 0, -0.8), 0.3, "e85d4a"), ((1.2, 0, -0.9), -0.25, "3b8ea5"), ((0.1, 0, 1.3), 0.0, "f2b632")]
    goods = [["f08a2c", "e84a5f", "ffd166"], ["6fae3e", "9b5de5", "e84a5f"], ["d9a35a", "f6e7c1", "c9773a"]]
    for (c, rot, color), wares in zip(stalls, goods):
        b.push(c, rot)
        b.box((0, 0.45, 0), (1.5, 0.9, 0.7), "planks", "a87a4e")
        for x in (-0.7, 0.7):
            for z in (-0.32, 0.32):
                b.box((x, 0.95, z), (0.07, 1.9, 0.07), "beam", "6b4a2f")
        # awning, slanted
        b.push((0, 1.95, 0.1), rot_x=0.28)
        b.box((0, 0, 0), (1.7, 0.05, 1.0), "cloth", color)
        b.pop()
        for i in range(6):
            x = -0.55 + i * 0.22
            b.blob((x, 0.98, 0.1), (0.09, 0.08, 0.09), "plain", wares[i % 3], subdiv=1, seed=i)
            b.blob((x + 0.1, 0.98, -0.12), (0.09, 0.08, 0.09), "plain", wares[(i + 1) % 3], subdiv=1, seed=i + 5)
        b.crate((0.95, 0, 0.45), 0.36)
        b.pop()
    b.cylinder((1.75, 1.2, 1.5), 0.05, 2.4, 6, "metal", "3a3a3a")
    b.box((1.75, 2.45, 1.5), (0.22, 0.3, 0.22), "metal", "3a3a3a")
    b.panel((1.75, 2.45, 1.62), 0.16, 0.22, "window", "ffd27a")
    b.barrel((-1.8, 0.03, 1.6))
    b.barrel((-1.45, 0.03, 1.8))


def model_school(b):
    """Lernhaus/Bibliothek: larger hall, bell tower, round window, book sign."""
    w, d, wh = 3.8, 3.0, 2.4
    b.plinth(w + 0.2, d + 0.2)
    b.box((0, 0.22 + wh / 2, 0), (w, wh, d), "plaster", "e8eef5", bottom=False)
    for x in (-w / 2, w / 2):
        for z in (-d / 2, d / 2):
            b.box((x, 0.22 + wh / 2, z), (0.25, wh + 0.04, 0.25), "stone_wall", "c4c8cc")
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.4, tile="roof_slate", color="9db7e0", gable_color="e8eef5")
    b.box((0, 3.4, 0.6), (0.9, 1.6, 0.9), "planks", "f2ead8")
    b.pyramid_roof((0, 4.2, 0.6), 0.9, 0.9, 1.0, tile="roof_slate", color="9db7e0", over=0.15)
    b.cylinder((0, 3.55, 0.6), 0.22, 0.3, 10, "metal", "d9a441", r_top=0.12)
    b.cylinder((0, 5.35, 0.6), 0.025, 0.4, 4, "metal", "d9a441")
    b.door((0, 0.22, d / 2), w=1.1, h=1.7, frame="3a5a8a")
    for x in (-1.3, 1.3):
        b.window((x, 1.35, d / 2 + 0.01), w=0.65, h=1.0, shutters=None, box=True)
    for z in (-0.8, 0.0, 0.8):
        for side in (-1, 1):
            b.window((side * (w / 2 + 0.01), 1.35, z), w=0.5, h=0.95, rot_y=side * math.pi / 2, shutters=None, box=False)
    b.panel((0, 2.25, d / 2 + 0.03), 1.2, 0.35, "planks", "3a5a8a")
    for i, col in enumerate(["e84a5f", "ffd166", "6fae3e", "4aa3df"]):
        b.box((-0.36 + i * 0.24, 2.25, d / 2 + 0.08), (0.16, 0.24, 0.05), "plain", col)
    b.box((-1.5, 0.45, d / 2 + 0.75), (1.0, 0.08, 0.34), "planks", "a87a4e")
    b.tree((1.75, 0.0, -1.7), 3.6, 1.0, seed=7)
    b.flowers((1.4, 0.0, 1.85), 5, 0.4, seed=17)


def model_well(b):
    """Brunnen: round stone well, timber roof, bucket on rope, cobble ring."""
    b.cylinder((0, 0.03, 0), 1.9, 0.06, 18, "cobble", "d9cfbe")
    b.cylinder((0, 0.42, 0), 0.95, 0.8, 16, "stone_wall", "c9c0b0")
    b.cylinder((0, 0.83, 0), 1.02, 0.08, 16, "stone_wall", "b0a898")
    b.cylinder((0, 0.6, 0), 0.78, 0.5, 16, "plain", "2f6f86", caps=False)
    b.cylinder((0, 0.7, 0), 0.8, 0.02, 16, "plain", "4fa3c0", caps=True)
    for x in (-0.85, 0.85):
        b.box((x, 1.55, 0), (0.14, 1.5, 0.14), "beam", "6b4a2f")
    b.gable_roof((0, 2.2, 0), 1.9, 1.5, 0.75, over=0.18, tile="roof_clay", color="ffffff", gable_tile="planks",
                 gable_color="a87a4e")
    b.cylinder((0, 1.95, 0), 0.08, 1.7, 8, "beam", "6b4a2f", axis="x")
    b.cylinder((0, 1.5, 0), 0.01, 0.9, 4, "metal", "3a3a3a")
    b.cylinder((0, 1.0, 0), 0.13, 0.22, 8, "planks", "8a5a33")
    b.flowers((1.3, 0.03, 1.0), 4, 0.25, seed=21)
    b.flowers((-1.3, 0.03, -0.9), 4, 0.25, seed=22)


def model_grain(b):
    """Kornfeld mit Windmühle: wheat field, sheaves, small windmill (Spin_Blades)."""
    b.box((0, 0.02, 0.4), (4.2, 0.06, 3.3), "field", "e2c78a", bottom=False)
    r = random.Random(4)
    for i in range(70):
        x = -1.9 + (i % 10) * 0.36 + r.random() * 0.1
        z = -0.9 + (i // 10) * 0.42 + r.random() * 0.1
        if x > 0.9 and z < 0.0:
            continue
        b.cylinder((x, 0.38, z), 0.11, 0.7, 5, "thatch", "f0d27a", r_top=0.16, wave=0.25)
    for x in (-1.2, -0.4):
        b.cone((x, 0.0, 1.8), 0.32, 0.9, 7, "thatch", "e8c66a")
    # windmill tower in the back-right corner
    b.cylinder((1.45, 1.3, -1.25), 0.75, 2.6, 10, "plaster", "f4ead2", r_top=0.55)
    b.cone((1.45, 2.6, -1.25), 0.72, 1.0, 10, "roof_clay", "ffffff")
    b.door((1.45, 0.0, -0.53), w=0.5, h=1.0, frame="6b4a2f", step=False, lamp=False)
    b.window((1.45, 1.8, -0.62), w=0.35, h=0.4, shutters=None, box=False, sill=False)


def model_grain_spin(b):
    b.cylinder((0, 0, 0), 0.14, 0.25, 8, "beam", "5a3a22", axis="z")
    for i in range(4):
        b.push((0, 0, 0.1), rot_z=i * math.pi / 2)
        b.box((0, 0.95, 0), (0.08, 1.8, 0.05), "beam", "6b4a2f")
        b.box((0.18, 1.05, 0), (0.32, 1.4, 0.02), "cloth", "f6efe0")
        b.pop()


def model_bakery(b):
    """Bäckerei: warm ochre house, big oven chimney (smoke), pretzel sign, bread display."""
    w, d, wh = 3.4, 2.8, 2.1
    house_body(b, w, d, wh, wall_color="f6d7a7", timber=True)
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.45, tile="roof_clay", color="f0c8a0", gable_color="f6d7a7")
    b.chimney((-1.0, 0.22 + wh + 0.3, -0.45), 2.0, color="a0786a")
    b.box((-2.05, 0.75, -0.3), (0.8, 1.1, 1.5), "stone_wall", "c8a088")
    b.cylinder((-2.05, 1.3, -0.3), 0.75, 1.5, 10, "stone_wall", "c8a088", axis="z", caps=True)
    b.door((0.8, 0.22, d / 2), frame="7a4a2a")
    b.box((-0.6, 0.22 + 0.75, d / 2 + 0.25), (1.6, 0.1, 0.5), "planks", "a87a4e")
    b.window((-0.6, 0.22 + 1.2, d / 2 + 0.01), w=1.2, h=0.7, shutters=None, box=False)
    b.push((-0.6, 0.22 + 1.95, d / 2 + 0.35), rot_x=0.35)
    b.box((0, 0, 0), (1.8, 0.04, 0.8), "cloth", "e85d4a")
    b.pop()
    for i in range(4):
        b.blob((-1.1 + i * 0.32, 0.22 + 0.86, d / 2 + 0.3), (0.13, 0.08, 0.09), "plain", "d9963e", subdiv=1, seed=i)
    b.box((1.55, 2.0, d / 2 + 0.3), (0.06, 0.06, 0.6), "metal", "3a3a3a")
    b.cylinder((1.55, 1.75, d / 2 + 0.6), 0.22, 0.06, 12, "plain", "d9963e", axis="z")
    b.window((1.0, 1.4, -d / 2 - 0.01), w=0.5, h=0.6, rot_y=math.pi, shutters="b5543a", box=False)
    b.barrel((1.55, 0.0, -1.7))
    b.crate((1.1, 0.0, -1.75), 0.38)


def model_road(b):
    """Wegeplatz: cobbled plaza, lantern, bench, planters, small fountain stone."""
    b.box((0, 0.03, 0), (4.3, 0.08, 4.3), "cobble", "e0d5c2", bottom=False)
    b.box((0, 0.08, 0), (2.6, 0.04, 2.6), "cobble", "cfc2ad", bottom=False)
    for x, z in ((-1.7, -1.7), (1.7, 1.7)):
        b.cylinder((x, 1.25, z), 0.06, 2.5, 6, "metal", "3a3a3a")
        b.box((x, 2.55, z), (0.26, 0.34, 0.26), "metal", "2e2e2e")
        b.panel((x, 2.55, z + 0.14), 0.2, 0.26, "window", "ffd27a")
        b.pyramid_roof((x, 2.73, z), 0.26, 0.26, 0.16, tile="metal", color="3a3a3a", over=0.04)
    b.box((1.2, 0.45, -1.6), (1.3, 0.08, 0.4), "planks", "a87a4e")
    for x in (0.7, 1.7):
        b.box((x, 0.22, -1.6), (0.1, 0.44, 0.34), "stone_wall", "b0a898")
    b.box((1.2, 0.75, -1.8), (1.3, 0.4, 0.06), "planks", "a87a4e")
    for x, z in ((-1.7, 1.7), (1.7, -0.4), (-1.7, -0.2)):
        b.box((x, 0.25, z), (0.6, 0.4, 0.6), "stone_wall", "c9bfae")
        b.flowers((x, 0.45, z), 4, 0.18, seed=int(x * 10 + z * 3))
    b.cylinder((0, 0.35, 0), 0.6, 0.55, 12, "stone_wall", "d4cdbf")
    b.cylinder((0, 0.63, 0), 0.5, 0.02, 12, "plain", "4fa3c0")
    b.cylinder((0, 0.9, 0), 0.1, 0.6, 8, "stone_wall", "d4cdbf")


def model_clinic(b):
    """Fürsorgehaus: white house, teal roof, herb garden, heart sign, bench."""
    w, d, wh = 3.4, 2.8, 2.2
    house_body(b, w, d, wh, wall_color="fbfbf6", timber=False)
    b.box((0, 0.22 + wh - 0.08, 0), (w + 0.08, 0.16, d + 0.08), "plain", "8fd0c6")
    b.gable_roof((0, 0.22 + wh, 0), w, d, 1.3, tile="roof_slate", color="9fe0d6", gable_color="fbfbf6")
    b.chimney((1.0, 0.22 + wh + 0.4, -0.5), 1.2)
    b.door((0, 0.22, d / 2), w=1.0, frame="3f8f86")
    b.box((0, 0.22 + 2.0, d / 2 + 0.06), (0.62, 0.62, 0.06), "plain", "ffffff")
    b.box((0, 0.22 + 2.0, d / 2 + 0.1), (0.42, 0.13, 0.03), "plain", "e85d6a")
    b.box((0, 0.22 + 2.0, d / 2 + 0.1), (0.13, 0.42, 0.03), "plain", "e85d6a")
    for x in (-1.15, 1.15):
        b.window((x, 1.2, d / 2 + 0.01), w=0.6, h=0.72, shutters="3f8f86")
    for z in (-0.6, 0.6):
        for side in (-1, 1):
            b.window((side * (w / 2 + 0.01), 1.2, z), w=0.5, h=0.62, rot_y=side * math.pi / 2, shutters="3f8f86", box=False)
    for i in range(3):
        b.box((-1.5 + i * 0.5, 0.12, -1.9), (0.4, 0.22, 0.9), "field", "ffffff")
        for k in range(3):
            b.blob((-1.5 + i * 0.5, 0.33, -2.2 + k * 0.3), (0.12, 0.12, 0.12), "leaves", ["7fbf5a", "9ccf6a", "6aa84f"][i],
                   subdiv=1, seed=i * 3 + k)
    b.box((1.2, 0.45, d / 2 + 0.75), (1.1, 0.08, 0.36), "planks", "a87a4e")
    b.flowers((-1.4, 0.0, 1.85), 5, 0.3, seed=31)


def model_watermill(b):
    """Wassermühle (Uferdeko): stone mill house, water wheel (Spin_Wheel) on the +X side."""
    house_body(b, 3.6, 3.0, 2.4, wall_tile="stone_wall", wall_color="d9d2c4", timber=False)
    b.gable_roof((0, 2.62, 0), 3.6, 3.0, 1.6, tile="thatch", color="ffffff", gable_tile="planks", gable_color="a87a4e")
    b.door((-0.6, 0.22, 1.5))
    b.window((0.8, 1.3, 1.51), shutters="7a9a5a")
    b.box((2.0, 1.4, 0), (0.4, 0.4, 0.4), "beam", "5a3a22")
    b.box((2.2, 2.6, 0.0), (0.2, 0.2, 2.6), "planks", "8a6a4a")
    b.chimney((-1.1, 3.0, -0.6), 1.2)


def model_watermill_spin(b):
    for side in (-0.35, 0.35):
        b.cylinder((side, 0, 0), 1.45, 0.08, 20, "beam", "6b4a2f", axis="x", caps=False)
    b.cylinder((0, 0, 0), 0.25, 0.8, 10, "beam", "5a3a22", axis="x")
    for i in range(12):
        a = i / 12 * math.tau
        b.push((0, math.sin(a) * 0.75, math.cos(a) * 0.75), rot_x=-a)
        b.box((0, 0, 0), (0.06, 0.1, 1.5), "beam", "6b4a2f")
        b.pop()
        b.push((0, math.sin(a) * 1.42, math.cos(a) * 1.42), rot_x=-a)
        b.box((0, 0, 0), (0.75, 0.42, 0.06), "planks", "8a6a4a")
        b.pop()


def model_watchtower(b):
    """Wachturm (Hügeldeko): timber tower on stone base, roofed lookout, flag (wave)."""
    b.cylinder((0, 0.8, 0), 1.4, 1.6, 10, "stone_wall", "b8b0a0", r_top=1.2)
    for x in (-0.8, 0.8):
        for z in (-0.8, 0.8):
            b.box((x, 3.4, z), (0.2, 3.6, 0.2), "beam", "6b4a2f")
    for y in (2.5, 4.0):
        for rot in (0, math.pi / 2):
            b.push((0, y, 0), rot)
            b.box((0, 0, 0.8), (1.8, 0.1, 0.08), "beam", "6b4a2f")
            b.box((0, 0, -0.8), (1.8, 0.1, 0.08), "beam", "6b4a2f")
            b.pop()
    b.box((0, 5.25, 0), (2.4, 0.15, 2.4), "planks", "a87a4e")
    for rot in (0, math.pi / 2, math.pi, -math.pi / 2):
        b.push((0, 5.6, 0), rot)
        b.box((0, 0, 1.15), (2.4, 0.6, 0.08), "planks", "8a6a4a")
        b.pop()
    for x in (-1.1, 1.1):
        for z in (-1.1, 1.1):
            b.box((x, 6.2, z), (0.12, 1.8, 0.12), "beam", "6b4a2f")
    b.pyramid_roof((0, 7.1, 0), 2.4, 2.4, 1.3, tile="roof_clay", over=0.25)
    b.cylinder((0, 8.8, 0), 0.03, 1.4, 4, "metal", "3a3a3a")
    b.box((0.38, 9.25, 0), (0.7, 0.42, 0.02), "cloth", "f2b632", wave=0.9)


def model_warehouse(b):
    """Lagerhaus (Hafen/Steg): long timber store, big doors, crates and barrels."""
    b.plinth(4.2, 2.8, color="8f877a")
    b.box((0, 0.22 + 1.2, 0), (4.0, 2.4, 2.6), "planks", "8a6a4a", bottom=False)
    b.gable_roof((0, 2.62, 0), 4.0, 2.6, 1.2, tile="roof_slate", color="b8b0a0", gable_tile="planks", gable_color="8a6a4a")
    for x in (-1.0, 1.0):
        b.panel((x, 1.15, 1.31), 1.2, 1.7, "door", "ffffff")
    b.box((0, 2.5, 1.45), (0.12, 0.12, 0.6), "beam", "5a3a22")
    for i in range(5):
        b.crate((-1.8 + i * 0.5, 0.0, 1.8), 0.42, rot=0.2 * i)
    b.crate((-1.6, 0.42, 1.8), 0.38)
    for i in range(3):
        b.barrel((1.4 + i * 0.4, 0.0, -1.7))


def model_workshop(b):
    """Werkstatt (Deko): small smithy with anvil and forge glow."""
    house_body(b, 3.0, 2.6, 2.0, wall_tile="stone_wall", wall_color="c8c0b0", timber=False)
    b.gable_roof((0, 2.22, 0), 3.0, 2.6, 1.0, tile="roof_slate", color="d0c8b8", gable_tile="planks", gable_color="8a6a4a")
    b.chimney((1.0, 2.6, -0.6), 1.6, color="7d7468")
    b.door((-0.6, 0.22, 1.3))
    b.window((0.7, 1.2, 1.31), w=0.7, h=0.6, shutters=None, box=False)
    b.box((0.9, 0.25, 1.9), (0.6, 0.5, 0.35), "stone_wall", "8f877a")
    b.box((0.9, 0.6, 1.9), (0.7, 0.18, 0.3), "metal", "3a3f46")


def model_bridge(b):
    """Steinbrücke: three arches, parapets, lantern posts. Length 22 m along X, deck at y=0."""
    length, width = 22.0, 3.0
    b.box((0, -0.2, 0), (length, 0.4, width), "cobble", "c9c0b0")
    for side in (-1, 1):
        b.box((0, 0.35, side * (width / 2 - 0.15)), (length, 0.7, 0.3), "stone_wall", "b8b0a0")
        b.box((0, 0.74, side * (width / 2 - 0.15)), (length, 0.08, 0.38), "stone_wall", "a39c90")
        for x in (-length / 2 + 0.4, length / 2 - 0.4):
            b.box((x, 0.6, side * (width / 2 - 0.15)), (0.5, 1.2, 0.5), "stone_wall", "a39c90")
    # arches as thick stone wall under the deck with semicircular openings
    spans = [(-6.0, 3.2), (0.0, 3.6), (6.0, 3.2)]
    depth = 4.2
    for z in (-width / 2 + 0.05, width / 2 - 0.05):
        face_z = z
        pts_x = [-length / 2 + 1.0, length / 2 - 1.0]
        x = pts_x[0]
        segs = []
        cursor = -length / 2 + 1.0
        for cx, r in spans:
            segs.append((cursor, cx - r))
            cursor = cx + r
        segs.append((cursor, length / 2 - 1.0))
        for a, bnd in segs:
            b.box(((a + bnd) / 2, -0.4 - depth / 2, z), (bnd - a, depth, 0.1 if False else width * 0.02 + 0.08), "stone_wall",
                  "b0a898")
        for cx, r in spans:
            n = 9
            for i in range(n):
                a0 = math.pi * i / n
                a1 = math.pi * (i + 1) / n
                p0 = (cx + math.cos(a0) * r, -0.4 - depth + math.sin(a0) * r + depth - r)
                p1 = (cx + math.cos(a1) * r, -0.4 - depth + math.sin(a1) * r + depth - r)
                top = -0.4
                pts = [(p1[0], p1[1], face_z), (p0[0], p0[1], face_z), (p0[0], top, face_z), (p1[0], top, face_z)]
                if z > 0:
                    b.face(pts[::-1], "stone_wall", "b0a898")
                else:
                    b.face(pts, "stone_wall", "b0a898")
    # solid piers
    for cx in (-3.0, 3.0):
        b.box((cx, -0.4 - depth / 2, 0), (2.4 - 0.4, depth, width - 0.1), "stone_wall", "a8a090")
        b.box((cx, -0.4 - depth + 0.6, 0), (2.1, 1.2, width + 0.6), "stone_wall", "9a9284")
    for x in (-length / 2 + 0.4, length / 2 - 0.4):
        b.box((x, -0.4 - depth / 2, 0), (0.8, depth, width), "stone_wall", "a8a090")
    for x in (-5.0, 5.0):
        b.cylinder((x, 1.5, width / 2 - 0.15), 0.05, 1.6, 6, "metal", "3a3a3a")
        b.box((x, 2.4, width / 2 - 0.15), (0.24, 0.3, 0.24), "metal", "2e2e2e")
        b.panel((x, 2.4, width / 2 - 0.02), 0.18, 0.22, "window", "ffd27a")


def model_dock(b):
    """Liefersteg: plank jetty on posts with mooring bollards and crates."""
    b.box((0, 0.0, 0), (2.4, 0.14, 7.0), "planks", "a87a4e")
    for x in (-1.1, 1.1):
        for z in (-3.2, -1.0, 1.2, 3.2):
            b.cylinder((x, -1.0, z), 0.12, 2.2, 8, "bark", "ffffff")
    for z in (-2.5, 2.5):
        b.cylinder((1.0, 0.25, z), 0.1, 0.35, 8, "metal", "3a3a3a")
    b.crate((-0.6, 0.07, 2.4), 0.45)
    b.crate((-0.6, 0.52, 2.4), 0.38, rot=0.3)
    b.barrel((-0.7, 0.07, 1.6))


def model_scaffold(b):
    """Baugerüst: poles, planks, ladder and a hoist (shown while a building rises)."""
    for x in (-2.0, 2.0):
        for z in (-1.8, 1.8):
            b.box((x, 2.4, z), (0.1, 4.8, 0.1), "beam", "c49a6a")
    for y in (1.3, 2.6, 3.9):
        for rot in (0.0, math.pi / 2):
            b.push((0, y, 0), rot)
            for s in (-1, 1):
                b.box((0, 0, s * (1.8 if rot == 0.0 else 2.0)), (4.1 if rot == 0.0 else 3.7, 0.08, 0.08), "beam", "c49a6a")
            b.pop()
        b.box((0, y + 0.06, 2.0), (4.0, 0.06, 0.45), "planks", "d8b07a")
    for i in range(2):
        b.push((0, 2.4, 1.8 + 0.01), rot_z=0.9 if i == 0 else -0.9)
        b.box((0, 0, 0), (5.4, 0.06, 0.06), "beam", "b08a5a")
        b.pop()
    b.box((-2.4, 2.0, 0.0), (0.06, 4.0, 0.06), "beam", "c49a6a")
    b.box((-2.4, 2.0, 0.4), (0.06, 4.0, 0.06), "beam", "c49a6a")
    for y in range(10):
        b.box((-2.4, 0.3 + y * 0.4, 0.2), (0.05, 0.05, 0.4), "beam", "c49a6a")
    for i in range(3):
        b.crate((1.6, 0.0, 2.3 - i * 0.45), 0.4, color="c49a6a")
    b.box((-1.0, 0.25, 2.3), (1.6, 0.5, 0.6), "stone_wall", "c9c0b0")


def model_cart(b):
    """Fuhrwerk: hay cart with two wheels and shafts."""
    b.box((0, 0.75, 0), (1.0, 0.12, 1.8), "planks", "a87a4e")
    for s in (-1, 1):
        b.box((s * 0.5, 0.95, 0), (0.06, 0.35, 1.8), "planks", "8a6a4a")
    b.box((0, 0.95, -0.9), (1.0, 0.35, 0.06), "planks", "8a6a4a")
    for s in (-1, 1):
        b.cylinder((s * 0.58, 0.45, 0.1), 0.45, 0.08, 14, "planks", "6b4a2f", axis="x")
        b.box((s * 0.3, 0.6, 1.5), (0.06, 0.06, 1.6), "beam", "6b4a2f")
    b.blob((0, 1.3, 0), (0.55, 0.45, 0.9), "thatch", "ffffff", subdiv=2, seed=3, jitter=0.1)


def model_boat(b):
    """Ruderboot."""
    pts = []
    for i in range(9):
        t = i / 8
        z = -1.4 + t * 2.8
        w = 0.62 * math.sin(math.pi * (0.08 + t * 0.84)) ** 0.7
        pts.append((w, z))
    for i in range(len(pts) - 1):
        (w0, z0), (w1, z1) = pts[i], pts[i + 1]
        for s in (-1, 1):
            q = [(s * w0, 0.45, z0), (s * w1, 0.45, z1), (s * w1 * 0.55, 0.0, z1), (s * w0 * 0.55, 0.0, z0)]
            b.face(q if s < 0 else q[::-1], "planks", "c0603a")
        b.face([(-w0 * 0.55, 0.0, z0), (-w1 * 0.55, 0.0, z1), (w1 * 0.55, 0.0, z1), (w0 * 0.55, 0.0, z0)][::-1], "planks", "8a5a33")
    for z in (-0.4, 0.5):
        b.box((0, 0.32, z), (1.05, 0.06, 0.25), "planks", "d8b07a")
    b.box((0, 0.45, 0), (0.05, 0.05, 2.6), "beam", "f2ead8")


def model_lantern(b):
    b.cylinder((0, 0.05, 0), 0.18, 0.1, 8, "stone_wall", "9a9284")
    b.cylinder((0, 1.2, 0), 0.05, 2.3, 6, "metal", "3a3a3a")
    b.box((0, 2.45, 0), (0.26, 0.32, 0.26), "metal", "2e2e2e")
    for rot in (0, math.pi / 2, math.pi, -math.pi / 2):
        b.panel((0, 2.45, 0), 0.2, 0.26, "window", "ffd27a", rot_y=rot, depth=0.135)
    b.pyramid_roof((0, 2.62, 0), 0.26, 0.26, 0.18, tile="metal", color="3a3a3a", over=0.05)


def model_fence(b):
    b.fence((-2.0, 0, 0), (2.0, 0, 0), posts=5, color="9a7048")


def model_tree_oak(b):
    """Laubbaum: knorriger Stamm mit Ästen, dunkler Kronenkern, Blattbüschel-Karten."""
    b.cylinder((0, 1.0, 0), 0.27, 2.0, 9, "bark", "ffffff", r_top=0.18)
    b.cylinder((0, 0.12, 0), 0.38, 0.24, 9, "bark", "ffffff", r_top=0.27)
    for i, (x, z, a) in enumerate([(0.5, 0.2, 0.7), (-0.45, -0.3, -0.75), (0.05, 0.55, 0.35), (-0.2, -0.6, -0.3)]):
        b.push((x * 0.35, 1.75, z * 0.35), rot_z=a * 0.7, rot_x=z * 0.8)
        b.cylinder((0, 0.6, 0), 0.11, 1.3, 6, "bark", "ffffff", r_top=0.05)
        b.pop()
    clusters = [(0, 3.4, 0, 1.55), (1.05, 2.9, 0.35, 1.15), (-0.95, 3.0, -0.3, 1.2), (0.25, 2.75, -1.0, 1.05),
                (-0.35, 2.7, 1.0, 1.05), (0.3, 4.25, 0.2, 1.0)]
    shades = ["4f7f2c", "5c8d34", "467628", "66983a", "557f30", "6fa040"]
    for i, (x, y, z, r) in enumerate(clusters):
        b.blob((x, y, z), (r * 0.62, r * 0.55, r * 0.62), "leaves", "3a5f22", subdiv=1, seed=40 + i, wave=0.1)
        b.cards((x, y, z), r, 26, 140 + i, shades[i], size=(0.8, 1.2))


def model_tree_fir(b):
    """Tanne: Stamm, gestufte dunkle Zweigkegel, hängende Nadelbüschel."""
    b.cylinder((0, 1.2, 0), 0.2, 2.4, 8, "bark", "c8a080", r_top=0.1)
    for i in range(5):
        y = 1.0 + i * 1.0
        r = 1.65 - i * 0.3
        b.cone((0, y, 0), r * 0.8, 1.6, 9, "leaves", ["2f5a2c", "335f2e", "2d5529", "3a6633", "40703a"][i], wave=0.06)
        b.cards((0, y + 0.55, 0), r, 12 - i, 170 + i, ["2e5a2a", "34622f", "2b5527", "3b6a34", "467a3c"][i],
                size=(0.6, 0.95), up_bias=-0.25, droop=0.6, vertical=0.45, inner=0.7)


def model_tree_birch(b):
    b.cylinder((0, 1.6, 0), 0.13, 3.2, 7, "plain", "efece4", r_top=0.08)
    for y in (0.6, 1.3, 2.1, 2.7):
        b.cylinder((0, y, 0), 0.135, 0.05, 7, "plain", "3a3a3a", caps=False)
    for i, (x, y, z, r) in enumerate([(0, 3.6, 0, 1.0), (0.5, 3.0, 0.3, 0.75), (-0.5, 3.1, -0.2, 0.8), (0.1, 4.3, 0.1, 0.7)]):
        b.blob((x, y, z), (r * 0.55, r * 0.6, r * 0.55), "leaves", "4a7a2a", subdiv=1, seed=60 + i, wave=0.15)
        b.cards((x, y, z), r, 18, 160 + i, ["7aa83e", "86b446", "6f9c38", "92bc4e"][i], size=(0.55, 0.85), vertical=1.2)


def model_tree_low(b):
    """Far-LOD tree: 1 trunk + one coarse crown (used for distant forest)."""
    b.cylinder((0, 0.9, 0), 0.25, 1.8, 5, "bark", "ffffff")
    b.blob((0, 3.0, 0), (1.6, 1.5, 1.6), "leaves", "6f9e42", subdiv=1, seed=70)


def model_fir_low(b):
    b.cylinder((0, 0.8, 0), 0.2, 1.6, 5, "bark", "c8a080")
    b.cone((0, 1.0, 0), 1.6, 4.8, 7, "leaves", "3f6c3b")


def model_bush(b):
    for i, (x, z, r) in enumerate([(0, 0, 0.7), (0.5, 0.2, 0.5), (-0.45, -0.1, 0.55), (0.1, -0.45, 0.45)]):
        b.blob((x, r * 0.55, z), (r * 0.75, r * 0.6, r * 0.75), "leaves", "3f6a28", subdiv=1, seed=80 + i, wave=0.06)
        b.cards((x, r * 0.6, z), r, 9, 190 + i, ["5a8a34", "679a3c", "4f7f2e", "73a444"][i], size=(0.45, 0.7), up_bias=0.5)
    for i in range(6):
        a = i * 1.3
        b.blob((math.cos(a) * 0.55, 0.8, math.sin(a) * 0.45), (0.07, 0.07, 0.07), "plain", "f78fb3", subdiv=1, seed=i)


def model_rock_a(b):
    b.blob((0, 0.4, 0), (1.2, 0.8, 0.9), "stone_wall", "b5ada0", subdiv=2, seed=91, jitter=0.28, flat_bottom=True)
    b.blob((0.9, 0.25, 0.4), (0.5, 0.4, 0.45), "stone_wall", "a39c90", subdiv=1, seed=92, jitter=0.3, flat_bottom=True)


def model_rock_b(b):
    b.blob((0, 0.9, 0), (1.4, 1.6, 1.2), "stone_wall", "a8a196", subdiv=2, seed=93, jitter=0.32, flat_bottom=True)
    b.blob((0, 2.0, 0.1), (0.9, 0.6, 0.8), "stone_wall", "bdb5a8", subdiv=1, seed=94, jitter=0.3)


def model_rock_c(b):
    for i in range(4):
        a = i * 1.7
        b.blob((math.cos(a) * 0.5, 0.18, math.sin(a) * 0.5), (0.35, 0.25, 0.3), "stone_wall", "b0a89a", subdiv=1,
               seed=95 + i, jitter=0.3, flat_bottom=True)


def model_flowers(b):
    b.flowers((0, 0, 0), 9, 0.8, seed=101)


def model_grass_tuft(b):
    r = random.Random(7)
    for i in range(9):
        a = i / 9 * math.tau + r.random()
        h = 0.35 + r.random() * 0.25
        x, z = math.cos(a) * 0.12, math.sin(a) * 0.12
        tip = (x * 3.0, h, z * 3.0)
        b.face([(x - 0.03, 0, z), (x + 0.03, 0, z), tip], "leaves", ["6fa84a", "86b24c", "7aa846"][i % 3], wave=0.5)
        b.face([(x + 0.03, 0, z), (x - 0.03, 0, z), tip], "leaves", ["6fa84a", "86b24c", "7aa846"][i % 3], wave=0.5)


def model_reeds(b):
    r = random.Random(11)
    for i in range(12):
        x = (r.random() - 0.5) * 1.2
        z = (r.random() - 0.5) * 1.2
        h = 0.9 + r.random() * 0.6
        b.cylinder((x, h / 2, z), 0.02, h, 4, "leaves", "7a9a4a", caps=False, wave=0.4)
        if i % 3 == 0:
            b.cylinder((x, h + 0.1, z), 0.05, 0.22, 5, "bark", "6b4a35", wave=0.4)


def model_sheep(b):
    b.blob((0, 0.55, 0), (0.42, 0.34, 0.6), "cloth", "f6f2e8", subdiv=2, seed=111, jitter=0.12)
    b.blob((0, 0.62, 0.62), (0.16, 0.17, 0.2), "plain", "3a3330", subdiv=1, seed=112, jitter=0.05)
    for x in (-0.2, 0.2):
        for z in (-0.35, 0.35):
            b.cylinder((x, 0.18, z), 0.05, 0.36, 5, "plain", "3a3330")


def model_cow(b):
    b.box((0, 0.85, 0), (0.6, 0.6, 1.3), "plain", "f4efe6")
    b.box((0.2, 0.95, 0.2), (0.62, 0.35, 0.45), "plain", "4a3a32")
    b.box((0, 1.05, 0.8), (0.4, 0.4, 0.45), "plain", "f4efe6")
    b.box((0, 0.92, 1.03), (0.34, 0.2, 0.08), "plain", "f2b6b0")
    for s in (-1, 1):
        b.cone((s * 0.16, 1.27, 0.75), 0.04, 0.16, 5, "plain", "e8dcc0")
    for x in (-0.2, 0.2):
        for z in (-0.45, 0.45):
            b.box((x, 0.28, z), (0.13, 0.56, 0.13), "plain", "4a3a32")


def model_chicken(b):
    b.blob((0, 0.2, 0), (0.14, 0.13, 0.18), "plain", "f6f2e8", subdiv=1, seed=121, jitter=0.05)
    b.blob((0, 0.33, 0.13), (0.08, 0.09, 0.08), "plain", "f6f2e8", subdiv=1, seed=122, jitter=0.03)
    b.cone((0, 0.32, 0.2), 0.025, 0.06, 4, "plain", "f2a33a")
    b.box((0, 0.42, 0.13), (0.02, 0.05, 0.06), "plain", "e84a3a")


def model_bird(b):
    b.blob((0, 0, 0), (0.08, 0.06, 0.16), "plain", "4a5560", subdiv=1, seed=131, jitter=0.03)
    for s in (-1, 1):
        b.face([(0, 0, 0.05), (s * 0.35, 0.05, -0.02), (0, 0, -0.08)][:: (1 if s > 0 else -1)], "plain", "3a434c", wave=1.0)
        b.face([(0, 0, 0.05), (s * 0.35, 0.05, -0.02), (0, 0, -0.08)][:: (-1 if s > 0 else 1)], "plain", "3a434c", wave=1.0)


def model_camp(b):
    """Gründerlager: Zelt, Lagerfeuer mit Steinkreis, Wegweiser, Sitzstämme, Vorräte."""
    # tent (A-frame) facing +Z, at the back left
    b.push((-1.6, 0, -1.0), 0.25)
    w, d, h = 2.2, 2.4, 1.7
    for side in (-1, 1):
        q = [(side * w / 2, 0.02, d / 2), (side * w / 2, 0.02, -d / 2), (0, h, -d / 2), (0, h, d / 2)]
        b.face(q if side > 0 else q[::-1], "cloth", "e9dcc0")
        q2 = [(side * w / 2 * 0.98, 0.02, -d / 2), (side * w / 2 * 0.98, 0.02, d / 2), (0, h * 0.98, d / 2), (0, h * 0.98, -d / 2)]
        b.face(q2 if side > 0 else q2[::-1], "cloth", "b8a888")
    b.face([(-w / 2, 0.02, -d / 2), (w / 2, 0.02, -d / 2), (0, h, -d / 2)][::-1], "cloth", "d8c8a8")
    b.face([(-w / 2, 0.02, d / 2), (-0.25, 0.02, d / 2), (0, h, d / 2)], "cloth", "d8c8a8")
    b.face([(0.25, 0.02, d / 2), (w / 2, 0.02, d / 2), (0, h, d / 2)], "cloth", "d8c8a8")
    b.face([(-0.25, 0.02, d / 2 - 0.05), (0.25, 0.02, d / 2 - 0.05), (0, h * 0.85, d / 2 - 0.05)], "plain", "4a3a2a")
    b.box((0, h + 0.05, 0), (0.08, 0.08, d + 0.3), "beam", "6b4a2f")
    for z in (-d / 2 - 0.1, d / 2 + 0.1):
        b.box((0, h / 2, z), (0.07, h + 0.1, 0.07), "beam", "6b4a2f")
    b.box((0.35, h + 0.45, d / 2 + 0.1), (0.5, 0.3, 0.02), "cloth", "e85d4a", wave=0.8)
    b.pop()
    # campfire
    for i in range(10):
        a = i / 10 * math.tau
        b.blob((0.9 + math.cos(a) * 0.55, 0.1, 0.6 + math.sin(a) * 0.55), (0.16, 0.12, 0.14), "stone_wall", "9a9284",
               subdiv=1, seed=300 + i, jitter=0.25, flat_bottom=True)
    for i in range(4):
        b.push((0.9, 0.18, 0.6), rot_y=i * math.pi / 4)
        b.push((0, 0, 0), rot_z=0.5)
        b.cylinder((0, 0.15, 0), 0.06, 0.7, 6, "bark", "ffffff")
        b.pop()
        b.pop()
    b.cone((0.9, 0.12, 0.6), 0.3, 0.75, 7, "plain", "ff8a2a", wave=0.5)
    b.cone((0.9, 0.12, 0.6), 0.17, 0.55, 6, "plain", "ffe066", wave=0.6)
    # seats
    for x, z, rot in ((0.0, 1.5, 0.3), (1.9, 1.3, -0.5)):
        b.push((x, 0.2, z), rot)
        b.cylinder((0, 0, 0), 0.2, 1.1, 8, "bark", "ffffff", axis="x", cap_tile="planks")
        b.pop()
    # signpost
    b.cylinder((2.1, 1.0, -1.2), 0.07, 2.0, 6, "beam", "6b4a2f")
    for y, rot, col in ((1.75, 0.4, "f2d38a"), (1.45, -0.6, "e8b56a"), (1.15, 1.9, "f2d38a")):
        b.push((2.1, y, -1.2), rot)
        b.box((0.42, 0, 0), (0.85, 0.2, 0.05), "planks", col)
        b.face([(0.85, -0.1, 0.03), (1.0, 0, 0.03), (0.85, 0.1, 0.03)], "planks", col)
        b.pop()
    # supplies
    b.crate((-0.2, 0.0, -2.0), 0.45)
    b.crate((0.3, 0.0, -2.1), 0.4, rot=0.4)
    b.barrel((-0.3, 0.0, -1.5))
    for i in range(3):
        b.cylinder((1.5 + i * 0.05, 0.12 + i * 0.22, -1.9), 0.12, 0.9, 7, "bark", "ffffff", axis="z", cap_tile="planks")


def model_beacon(b):
    """Lumos Geschichtstafel: stone pedestal, two pillars with a carved arch."""
    b.cylinder((0, 0.22, 0), 2.6, 0.44, 16, "stone_wall", "c9c0b0")
    b.cylinder((0, 0.49, 0), 2.24, 0.12, 16, "cobble", "e0d5c2")
    for side in (-1.95, 1.95):
        b.cylinder((side, 1.45, 0), 0.22, 2.7, 10, "stone_wall", "e2dccf")
    b.box((0, 3.12, 0), (4.4, 0.34, 0.5), "stone_wall", "d4cdbf")
    b.box((0, 3.36, 0), (4.6, 0.12, 0.62), "stone_wall", "bdb5a8")


MODELS = {
    "house_a": (model_house_a, {}), "house_b": (model_house_b, {}), "house_c": (model_house_c, {}),
    "farm": (model_farm, {}), "lumber": (model_lumber, {"Spin_Saw": (model_lumber_spin, (-0.2, 1.05, 0.2))}),
    "quarry": (model_quarry, {}), "market": (model_market, {}), "school": (model_school, {}),
    "well": (model_well, {}), "grain": (model_grain, {"Spin_Blades": (model_grain_spin, (1.45, 2.55, -0.48))}),
    "bakery": (model_bakery, {}), "road": (model_road, {}), "clinic": (model_clinic, {}),
    "watermill": (model_watermill, {"Spin_Wheel": (model_watermill_spin, (2.45, 1.4, 0.0))}),
    "watchtower": (model_watchtower, {}), "warehouse": (model_warehouse, {}), "workshop": (model_workshop, {}),
    "bridge": (model_bridge, {}), "dock": (model_dock, {}), "scaffold": (model_scaffold, {}), "cart": (model_cart, {}),
    "boat": (model_boat, {}), "lantern": (model_lantern, {}), "fence": (model_fence, {}),
    "tree_oak": (model_tree_oak, {}), "tree_fir": (model_tree_fir, {}), "tree_birch": (model_tree_birch, {}),
    "tree_low": (model_tree_low, {}), "fir_low": (model_fir_low, {}), "bush": (model_bush, {}),
    "rock_a": (model_rock_a, {}), "rock_b": (model_rock_b, {}), "rock_c": (model_rock_c, {}),
    "flowers": (model_flowers, {}), "grass_tuft": (model_grass_tuft, {}), "reeds": (model_reeds, {}),
    "sheep": (model_sheep, {}), "cow": (model_cow, {}), "chicken": (model_chicken, {}), "bird": (model_bird, {}),
    "beacon": (model_beacon, {}), "camp": (model_camp, {}),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_model(name):
    reset()
    func, parts = MODELS[name]
    b = Builder(name)
    func(b)
    root = b.to_object(name)
    for part_name, (part_func, pivot) in parts.items():
        pb = Builder(part_name)
        part_func(pb)
        child = pb.to_object(part_name, parent=root)
        child.location = g2b(pivot)
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
    return {"triangles": tris, "bytes": path.stat().st_size, "parts": list(parts)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    names = [n for n in MODELS if not args.only or n in args.only.split(",")]
    report_path = OUT / "models.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    for name in names:
        info = build_model(name)
        info["sha256"] = hashlib.sha256((OUT / f"{name}.glb").read_bytes()).hexdigest()
        report[name] = info
        print(f"{name}: {info['triangles']} tris, {info['bytes']} bytes")
    report_path.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")
    if args.check:
        for name, info in report.items():
            assert (OUT / f"{name}.glb").exists(), name
            assert info["bytes"] < 2 * 1024 * 1024, name
            assert info["triangles"] < 20000, name
        total = sum((OUT / f"{n}.glb").stat().st_size for n in report)
        print("total bytes", total)


if __name__ == "__main__":
    main()
