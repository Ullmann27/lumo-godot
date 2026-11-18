#!/usr/bin/env python3
"""Builds every model of the Dschungelherz jungle (Lumo Lauf) in Blender.

Run (bpy 5.3 as a Python module, numpy and Pillow in the same environment):

  /home/user/tools/bpyenv/bin/python tools/lumo_run_art/build_jungle_art.py [--only tree_broad,fern_a]

1. Makes the textures (jungle_textures.py) unless --keep-textures.
2. Builds each model from code with a fixed seed: trees with buttress roots,
   bark relief and crowns of many alpha-cut leaf cards, ferns, tropical leaves,
   lianas, mossy rocks, temple parts, wooden parts, gameplay props and the
   three friendly enemies. Smooth normals, rounded edges.
3. Exports one GLB per model to assets/games/run/jungle/models/ and rewrites it
   so its images are references to the shared files in
   assets/games/run/jungle/models/textures/ (stored once, not per GLB).
4. Writes assets/games/run/jungle/models/jungle_art.json (triangles, materials,
   sizes) which verify_jungle_art.py and the Godot tests read.

Every shape and texture is original and generated here: no downloads, no
foreign assets, no paid services.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import shutil
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jungle_geo as G  # noqa: E402
from jungle_geo import UP, Geo, v3  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/games/run/jungle/models"
TEXTURES = MODELS / "textures"
SEED = 20261118

# ------------------------------------------------------------------ materials

MATERIALS = {
    "bark": {"albedo": "bark_albedo.jpg", "normal": "bark_normal.jpg", "rough": 0.92},
    "leaves": {"albedo": "leaves_albedo.png", "normal": "leaves_normal.jpg", "rough": 0.62, "mask": True},
    "stone": {"albedo": "stone_albedo.jpg", "normal": "stone_normal.jpg", "rough": 0.88},
    "sandstone": {"albedo": "sandstone_albedo.jpg", "normal": "sandstone_normal.jpg", "rough": 0.86},
    "wood": {"albedo": "wood_albedo.jpg", "normal": "wood_normal.jpg", "rough": 0.8},
    "moss": {"albedo": "moss_albedo.jpg", "normal": "moss_normal.jpg", "rough": 0.95},
    "iron": {"albedo": "iron_albedo.jpg", "normal": "iron_normal.jpg", "rough": 0.55, "metal": 0.65},
    "rope": {"albedo": "wood_albedo.jpg", "normal": "wood_normal.jpg", "rough": 0.95, "color": (0.95, 0.85, 0.6)},
    "coconut_husk": {"albedo": "bark_albedo.jpg", "normal": "bark_normal.jpg", "rough": 0.95, "color": (0.85, 0.62, 0.42)},
    "grass": {"color": (0.36, 0.62, 0.22), "rough": 0.7, "double": True},
    "stem": {"color": (0.36, 0.55, 0.2), "rough": 0.6},
    "petal": {"color": (1.0, 1.0, 1.0), "rough": 0.5, "double": True},
    "paint_pollen": {"color": (1.0, 0.85, 0.25), "rough": 0.6},
    "paint_crab": {"color": (1.0, 0.42, 0.2), "rough": 0.35},
    "paint_crab_belly": {"color": (1.0, 0.82, 0.62), "rough": 0.45},
    "paint_beetle": {"color": (0.2, 0.78, 0.74), "rough": 0.18, "metal": 0.35},
    "paint_dark": {"color": (0.12, 0.14, 0.2), "rough": 0.4},
    "paint_eye": {"color": (0.98, 0.98, 0.96), "rough": 0.15},
    "paint_pupil": {"color": (0.04, 0.05, 0.08), "rough": 0.08},
    "paint_cap": {"color": (1.0, 0.32, 0.27), "rough": 0.3},
    "paint_spot": {"color": (1.0, 0.95, 0.82), "rough": 0.5},
    "paint_stem_cream": {"color": (0.96, 0.9, 0.78), "rough": 0.7},
    "paint_gold": {"color": (1.0, 0.76, 0.3), "rough": 0.25, "metal": 0.9},
    "paint_ember": {"color": (1.0, 0.45, 0.12), "rough": 0.9, "emit": (1.0, 0.4, 0.1)},
    "glow_crystal": {"color": (0.6, 0.95, 1.0), "rough": 0.1, "emit": (0.4, 0.9, 1.0)},
    "glow_lantern": {"color": (1.0, 0.86, 0.5), "rough": 0.2, "emit": (1.0, 0.75, 0.35)},
}


def make_material(name: str) -> bpy.types.Material:
    spec = MATERIALS[name]
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:  # Blender 5 always uses nodes
        pass
    tree = mat.node_tree
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    # Colours in the table are sRGB (as picked by eye); glTF factors are linear.
    colour = tuple(c ** 2.2 for c in spec.get("color", (1.0, 1.0, 1.0)))
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = spec.get("rough", 0.8)
    bsdf.inputs["Metallic"].default_value = spec.get("metal", 0.0)
    if "albedo" in spec:
        image = load_image(spec["albedo"], colour_data=True)
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        if "color" in spec:
            mix = tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            tree.links.new(tex.outputs["Color"], mix.inputs["A"])
            mix.inputs["B"].default_value = (*colour, 1.0)
            tree.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
        else:
            tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if spec.get("mask"):
            tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    if "normal" in spec:
        image = load_image(spec["normal"], colour_data=False)
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        normal = tree.nodes.new("ShaderNodeNormalMap")
        tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
        tree.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if "emit" in spec:
        bsdf.inputs["Emission Color"].default_value = (*(c ** 2.2 for c in spec["emit"]), 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    mat.use_backface_culling = not (spec.get("mask") or spec.get("double"))
    return mat


_IMAGES: dict[str, bpy.types.Image] = {}


def load_image(file_name: str, colour_data: bool) -> bpy.types.Image:
    if file_name not in _IMAGES:
        image = bpy.data.images.load(str(TEXTURES / file_name))
        image.name = file_name
        image.colorspace_settings.name = "sRGB" if colour_data else "Non-Color"
        _IMAGES[file_name] = image
    return _IMAGES[file_name]


# ------------------------------------------------------------------ tree parts

def ao_colour(value: float, tint=(1.0, 1.0, 1.0)):
    value = max(0.25, min(1.0, value))
    return (value * tint[0], value * tint[1], value * tint[2], 1.0)


def trunk(geo: Geo, rng: random.Random, height: float, r0: float, r1: float, *, sides: int, rings: int,
          lean: Vector, wobble: float = 0.4, bump: float = 0.07, flare: float = 1.5, seed: int = 0,
          sway_top: float = 0.08):
    """A tapering, slightly curving trunk from the ground up. Returns the spine."""
    points, radii, sway, cols = [], [], [], []
    for k in range(rings + 1):
        t = k / rings
        bend = lean * (t * t) + v3(math.sin(t * 3.1 + seed) * wobble, 0, math.cos(t * 2.3 + seed) * wobble) * t
        points.append(v3(0, height * t, 0) + bend - v3(0, 0.25, 0) * (k == 0))
        r = r0 + (r1 - r0) * t ** 0.8
        r *= 1.0 + (flare - 1.0) * max(0.0, 1.0 - t * 7.0) ** 2
        radii.append(r)
        sway.append(sway_top * t * t)
        cols.append(ao_colour(0.62 + 0.38 * min(1.0, t * 3.0)))
    around = max(1.0, round(2.0 * math.pi * r0 / 1.1))
    G.tube(geo, points, radii, sides, "bark", uv_around=around, uv_len=2.2, sway=sway, colours=cols, bump=bump, seed=seed)
    return points, radii


def buttresses(geo: Geo, rng: random.Random, trunk_r: float, count: int, height: float, reach: float, *,
               sides: int, steps: int, seed: int = 0) -> None:
    start = rng.uniform(0, math.tau)
    for index in range(count):
        angle = start + math.tau * index / count + rng.uniform(-0.25, 0.25)
        out = v3(math.cos(angle), 0, math.sin(angle))
        length = reach * rng.uniform(0.75, 1.2)
        high = height * rng.uniform(0.75, 1.15)
        thick = trunk_r * rng.uniform(0.2, 0.3)
        points, ellipse, cols = [], [], []
        wiggle = v3(-out.z, 0, out.x) * rng.uniform(-0.25, 0.25)
        for k in range(steps + 1):
            t = k / steps
            a = high * (1.0 - t) ** 1.7 * 0.5 + 0.07
            b = thick * (1.0 - 0.65 * t) + 0.03
            centre = out * (trunk_r * 0.55 + t * length) + wiggle * math.sin(t * math.pi) + UP * (a - 0.12)
            points.append(centre)
            ellipse.append((a, b))
            cols.append(ao_colour(0.6 + 0.25 * t))
        G.tube(geo, points, None, sides, "bark", uv_around=1.0, uv_len=2.2, ellipse=ellipse, colours=cols, seed=seed + index)


def branch(geo: Geo, rng: random.Random, start: Vector, direction: Vector, length: float, r0: float, r1: float, *,
           sides: int, steps: int, rise: float, sway0: float, sway1: float, phase: float, droop: float = 0.0):
    end = start + direction.normalized() * length
    points = G.curve(start, end, rise * length, steps, droop * length)
    radii = [r0 + (r1 - r0) * (k / steps) for k in range(steps + 1)]
    sway = [sway0 + (sway1 - sway0) * (k / steps) for k in range(steps + 1)]
    cols = [ao_colour(0.75 + 0.2 * k / steps) for k in range(steps + 1)]
    G.tube(geo, points, radii, sides, "bark", uv_around=1.0, uv_len=2.2, sway=sway, phase=phase, colours=cols)
    return points


def leaf_cluster(geo: Geo, rng: random.Random, centre: Vector, radius: float, count: int, card: float, cell: str, *,
                 crown_centre: Vector, crown_radius: float, lod: bool, phase: float, sway=(0.55, 1.0), up_bias: float = 0.35,
                 droop: float = 0.3, width_ratio: float = 0.62, cells=None) -> None:
    for _ in range(count):
        d = v3(rng.gauss(0, 1), rng.gauss(0, 1) * 0.7 + up_bias, rng.gauss(0, 1)).normalized()
        base = centre + d * radius * rng.uniform(0.05, 0.45)
        direction = (d + v3(rng.uniform(-0.4, 0.4), rng.uniform(-0.1, 0.35), rng.uniform(-0.4, 0.4))).normalized()
        length = card * rng.uniform(0.8, 1.2) * (1.35 if lod else 1.0)
        side_hint = v3(rng.uniform(-1, 1), rng.uniform(-0.3, 0.3), rng.uniform(-1, 1))
        depth = (base - crown_centre).length / max(crown_radius, 0.1)
        height_term = (base.y - crown_centre.y) / max(crown_radius, 0.1)
        ao0 = 0.5 + 0.3 * min(1.0, depth) + 0.15 * height_term
        ao1 = ao0 + 0.22
        chosen = cell if cells is None else rng.choice(cells)
        G.leaf_card(geo, base, direction, side_hint, length, length * width_ratio, chosen, "leaves",
                    bend=droop * rng.uniform(0.6, 1.3), fold=0.1, segments=1 if lod else 2, columns=2 if lod else 3,
                    centre=crown_centre, spherical=0.65, sway=sway, phase=phase + rng.uniform(0, 0.2), ao=(ao0, ao1))


def crown_from_branches(geo, rng, tips, *, crown_centre, crown_radius, lod, per_tip, lod_per_tip, card, cell,
                        cluster_r, cells=None, droop=0.3):
    for index, tip in enumerate(tips):
        leaf_cluster(geo, rng, tip, cluster_r, lod_per_tip if lod else per_tip, card, cell, crown_centre=crown_centre,
                     crown_radius=crown_radius, lod=lod, phase=(index * 0.137) % 1.0, cells=cells, droop=droop)


def tree_generic(name: str, seed: int, lod: bool, *, height: float, r0: float, r1: float, buttress: int,
                 buttress_h: float, buttress_reach: float, branch_from: float, branch_to: float, branches: int,
                 branch_len: float, branch_rise: float, sub: int, per_tip: int, lod_per_tip: int, card: float, cell: str,
                 cluster_r: float, lean: float = 0.6, cells=None, flare: float = 1.5, top_tip: bool = True,
                 droop: float = 0.3, extra=None) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    lean_vec = v3(rng.uniform(-1, 1), 0, rng.uniform(-1, 1)).normalized() * lean
    sides = 7 if lod else 12
    spine, radii = trunk(geo, rng, height, r0, r1, sides=sides, rings=5 if lod else 12, lean=lean_vec, seed=seed,
                         flare=flare, bump=0.0 if lod else 0.07)
    if buttress:
        buttresses(geo, rng, r0, buttress, buttress_h, buttress_reach, sides=5 if lod else 8, steps=3 if lod else 7, seed=seed)
    tips = []
    crown_centre = spine[-1] + v3(0, -branch_len * 0.2, 0)
    crown_radius = branch_len * 1.1

    def spine_at(t):
        f = t * (len(spine) - 1)
        i = min(int(f), len(spine) - 2)
        return spine[i].lerp(spine[i + 1], f - i), radii[i] + (radii[i + 1] - radii[i]) * (f - i)

    start_angle = rng.uniform(0, math.tau)
    for b in range(branches):
        t = branch_from + (branch_to - branch_from) * (b / max(1, branches - 1)) + rng.uniform(-0.03, 0.03)
        at, r = spine_at(min(0.98, t))
        angle = start_angle + b * 2.39996 + rng.uniform(-0.3, 0.3)
        out = v3(math.cos(angle), branch_rise + rng.uniform(-0.15, 0.15), math.sin(angle))
        length = branch_len * rng.uniform(0.8, 1.15) * (1.0 - 0.3 * (t - branch_from))
        phase = (b * 0.21 + 0.05) % 1.0
        points = branch(geo, rng, at, out, length, r * 0.6, r * 0.15, sides=5 if lod else 8, steps=3 if lod else 6,
                        rise=0.25, sway0=0.05, sway1=0.35, phase=phase)
        tips.append(points[-1])
        # Leaf clumps also sit along the outer half of every limb.
        for k in range(len(points) // 2, len(points) - 1, 2 if lod else 1):
            tips.append(points[k] + UP * 0.2)
        for s in range(sub):
            k = rng.randint(len(points) // 3, len(points) - 2)
            twig_dir = (out + v3(rng.uniform(-1, 1), rng.uniform(0.2, 0.9), rng.uniform(-1, 1))).normalized()
            twig = branch(geo, rng, points[k], twig_dir, length * rng.uniform(0.35, 0.55), r * 0.22, r * 0.07,
                          sides=4 if lod else 6, steps=2 if lod else 4, rise=0.2, sway0=0.25, sway1=0.5, phase=phase)
            tips.append(twig[-1])
    if top_tip:
        tips.append(spine[-1] + v3(0, 0.4, 0))
    crown_from_branches(geo, rng, tips, crown_centre=crown_centre, crown_radius=crown_radius, lod=lod,
                        per_tip=int(per_tip * 1.5), lod_per_tip=lod_per_tip + 2, card=card, cell=cell, cluster_r=cluster_r, cells=cells, droop=droop)
    if extra is not None:
        extra(geo, rng, spine, radii, tips, lod)
    return geo


def tree_broad(lod: bool) -> Geo:
    return tree_generic("tree_broad", 101, lod, height=15.0, r0=0.55, r1=0.24, buttress=5, buttress_h=1.8, buttress_reach=1.7,
                        branch_from=0.5, branch_to=0.94, branches=7, branch_len=4.6, branch_rise=0.5, sub=2, per_tip=11,
                        lod_per_tip=4, card=2.0, cell="twig", cluster_r=1.6, cells=["twig", "twig", "small"])


def tree_slender(lod: bool) -> Geo:
    return tree_generic("tree_slender", 202, lod, height=13.0, r0=0.26, r1=0.12, buttress=0, buttress_h=0, buttress_reach=0,
                        branch_from=0.5, branch_to=0.95, branches=8, branch_len=3.2, branch_rise=0.7, sub=1, per_tip=10,
                        lod_per_tip=4, card=1.6, cell="small", cluster_r=1.1, lean=0.9, flare=1.8, cells=["small", "small", "twig"])


def _fig_extra(geo, rng, spine, radii, tips, lod):
    # Strangler fig: roots wrapped round the trunk and aerial roots hanging down.
    strands = 2 if lod else 4
    for s in range(strands):
        offset = rng.uniform(0, math.tau)
        points, rr = [], []
        steps = 6 if lod else 16
        for k in range(steps + 1):
            t = k / steps
            f = t * 0.75 * (len(spine) - 1)
            i = min(int(f), len(spine) - 2)
            centre = spine[i].lerp(spine[i + 1], f - i)
            r = radii[i] * 1.02
            angle = offset + t * 5.0
            points.append(centre + v3(math.cos(angle) * r, 0, math.sin(angle) * r) + UP * (-0.1 if k == 0 else 0))
            rr.append(0.13 * (1.0 - 0.5 * t) + 0.02)
        G.tube(geo, points, rr, 4 if lod else 6, "bark", uv_len=1.5, colours=[ao_colour(0.7)] * len(points))
    hanging = 2 if lod else 4
    for h in range(hanging):
        top = rng.choice(tips[:-1]) if len(tips) > 1 else tips[0]
        anchor = top.lerp(v3(0, top.y, 0), rng.uniform(0.2, 0.6))
        points = [anchor + v3(math.sin(k * 1.3 + h) * 0.25, -anchor.y * k / 6 - 0.2 * (k == 6), math.cos(k * 0.9 + h) * 0.2) for k in range(7)]
        G.tube(geo, points, [0.05, 0.04, 0.035, 0.035, 0.04, 0.05, 0.07], 3 if lod else 4, "bark", uv_len=1.5, sway=[0.1 + 0.1 * k for k in range(7)],
               phase=0.3 + h * 0.1, colours=[ao_colour(0.75)] * 7)


def tree_fig(lod: bool) -> Geo:
    return tree_generic("tree_fig", 303, lod, height=17.0, r0=0.55, r1=0.28, buttress=6, buttress_h=1.2, buttress_reach=1.2,
                        branch_from=0.45, branch_to=0.9, branches=8, branch_len=5.2, branch_rise=0.35, sub=2, per_tip=10,
                        lod_per_tip=4, card=2.1, cell="twig", cluster_r=1.8, lean=0.4, extra=_fig_extra, droop=0.4)


def tree_kapok(lod: bool) -> Geo:
    return tree_generic("tree_kapok", 404, lod, height=27.0, r0=0.95, r1=0.45, buttress=6, buttress_h=4.2, buttress_reach=4.2,
                        branch_from=0.74, branch_to=0.98, branches=8, branch_len=8.0, branch_rise=0.2, sub=3, per_tip=10,
                        lod_per_tip=4, card=2.6, cell="twig", cluster_r=2.4, lean=0.3, flare=1.3, droop=0.25)


def palm(seed: int, height: float, lod: bool) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    lean = v3(rng.uniform(-1, 1), 0, rng.uniform(-1, 1)).normalized()
    rings = 8 if lod else 26
    points, radii, sway, cols = [], [], [], []
    for k in range(rings + 1):
        t = k / rings
        p = v3(0, height * t, 0) + lean * height * 0.22 * t * t
        points.append(p - v3(0, 0.2, 0) * (k == 0))
        ring_bump = 0.0 if lod else (0.035 if k % 2 == 0 else -0.01)
        radii.append(0.3 - 0.12 * t + ring_bump + (0.15 if k == 0 else 0))
        sway.append(0.15 * t * t)
        cols.append(ao_colour(0.7 + 0.3 * t, (1.0, 0.95, 0.88)))
    G.tube(geo, points, radii, 6 if lod else 10, "bark", uv_around=1.0, uv_len=1.6, sway=sway, colours=cols)
    top = points[-1]
    fronds = 9 if lod else 15
    for f in range(fronds):
        angle = math.tau * f / fronds + rng.uniform(-0.15, 0.15)
        tilt = rng.uniform(-0.1, 0.55) if f % 3 else rng.uniform(0.4, 0.8)
        direction = v3(math.cos(angle), tilt, math.sin(angle))
        length = height * rng.uniform(0.32, 0.4)
        G.leaf_card(geo, top - UP * 0.15, direction, v3(-math.sin(angle), 0, math.cos(angle)), length, length * 0.55, "fern",
                    "leaves", bend=rng.uniform(0.35, 0.6), fold=0.18, segments=2 if lod else 6, columns=2 if lod else 3,
                    centre=top - UP * 1.0, spherical=0.5, sway=(0.25, 1.0), phase=f * 0.07, ao=(0.7, 1.0))
    if not lod:
        for c in range(5):
            angle = rng.uniform(0, math.tau)
            G.blob(geo, top - UP * 0.35 + v3(math.cos(angle) * 0.22, rng.uniform(-0.1, 0.1), math.sin(angle) * 0.22),
                   v3(0.13, 0.15, 0.13), "coconut_husk", subdiv=1, rough=0.05, seed=c)
    return geo


# ------------------------------------------------------------------ plants

def fern(seed: int, fronds: int, reach: float, upright: float) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    for f in range(fronds):
        angle = math.tau * f / fronds + rng.uniform(-0.25, 0.25)
        direction = v3(math.cos(angle), upright + rng.uniform(-0.2, 0.3), math.sin(angle))
        length = reach * rng.uniform(0.75, 1.15)
        G.leaf_card(geo, v3(0, 0.02, 0), direction, v3(-math.sin(angle), 0.2, math.cos(angle)), length, length * 0.5, "fern",
                    "leaves", bend=rng.uniform(0.35, 0.55), fold=0.16, segments=4, columns=3, centre=v3(0, -0.4, 0),
                    spherical=0.45, sway=(0.0, 1.0), phase=rng.random(), ao=(0.45, 1.0))
    return geo


def bigleaf(seed: int, leaves: int, stem: float, size: float, width: float, outward: float) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    for index in range(leaves):
        angle = math.tau * index / leaves + rng.uniform(-0.35, 0.35)
        out = v3(math.cos(angle), 0, math.sin(angle))
        height = stem * rng.uniform(0.7, 1.2)
        top = out * height * outward + UP * height
        stem_points = [out * height * outward * t * t + UP * height * t for t in (0.0, 0.35, 0.7, 1.0)]
        G.tube(geo, stem_points, [0.035, 0.03, 0.026, 0.022], 5, "stem", sway=[0.0, 0.15, 0.35, 0.5], phase=index * 0.13,
               colours=[ao_colour(0.6), ao_colour(0.8), ao_colour(0.9), ao_colour(1.0)])
        direction = (out * rng.uniform(0.8, 1.2) + UP * rng.uniform(0.2, 0.6)).normalized()
        length = size * rng.uniform(0.85, 1.15)
        G.leaf_card(geo, top - direction * 0.03, direction, v3(-out.z, 0, out.x), length, length * width, "big", "leaves",
                    bend=rng.uniform(0.3, 0.55), fold=0.22, segments=4, columns=3, centre=UP * stem * 0.3, spherical=0.35,
                    sway=(0.5, 1.0), phase=index * 0.13, ao=(0.75, 1.0))
    return geo


def bush(seed: int) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    tips = []
    for b in range(4):
        angle = math.tau * b / 4 + rng.uniform(-0.4, 0.4)
        out = v3(math.cos(angle), rng.uniform(0.8, 1.3), math.sin(angle))
        points = branch(geo, rng, v3(0, 0, 0), out, rng.uniform(0.7, 1.0), 0.05, 0.015, sides=4, steps=3, rise=0.1,
                        sway0=0.0, sway1=0.4, phase=b * 0.2)
        tips.append(points[-1])
    tips.append(v3(0, 0.9, 0))
    crown_from_branches(geo, rng, tips, crown_centre=v3(0, 0.45, 0), crown_radius=1.0, lod=False, per_tip=6, lod_per_tip=3,
                        card=0.9, cell="twig", cluster_r=0.6, cells=["twig", "small"], droop=0.3)
    return geo


def groundcover(seed: int) -> Geo:
    """A low carpet of leafy sprigs that hides the bare forest floor."""
    rng = random.Random(seed)
    geo = Geo()
    for index in range(12):
        angle = math.tau * index / 12 + rng.uniform(-0.3, 0.3)
        base = v3(math.cos(angle), 0, math.sin(angle)) * rng.uniform(0.0, 0.6)
        direction = v3(math.cos(angle), rng.uniform(0.15, 0.5), math.sin(angle))
        length = rng.uniform(0.6, 0.95)
        G.leaf_card(geo, base + UP * 0.02, direction, v3(-math.sin(angle), 0.3, math.cos(angle)), length, length * 0.7,
                    rng.choice(["small", "twig", "fern"]), "leaves", bend=0.2, fold=0.12, segments=1, columns=3,
                    centre=v3(0, -0.5, 0), spherical=0.5, sway=(0.0, 0.5), phase=rng.random(), ao=(0.55, 0.95))
    return geo


def grass(seed: int, blades: int, height: float) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    for _ in range(blades):
        angle = rng.uniform(0, math.tau)
        at = v3(math.cos(angle), 0, math.sin(angle)) * rng.uniform(0, 0.3)
        lean = v3(math.cos(angle), 0, math.sin(angle)) * rng.uniform(0.15, 0.45)
        side = v3(-math.sin(angle), 0, math.cos(angle)) * 0.025
        tall = height * rng.uniform(0.6, 1.2)
        rows = []
        for k in range(4):
            t = k / 3
            centre = at + lean * t * t + UP * tall * t
            w = 1.0 - t
            rows.append((geo.vert(centre - side * w), geo.vert(centre + side * w), t))
        for k in range(3):
            a, b, t0 = rows[k]
            c, d, t1 = rows[k + 1]
            col0 = ao_colour(0.55 + 0.45 * t0)
            col1 = ao_colour(0.55 + 0.45 * t1)
            geo.face((a, b, d, c), [(0, t0), (1, t0), (1, t1), (0, t1)], "grass", uv2=[(t0, angle), (t0, angle), (t1, angle), (t1, angle)],
                     col=[col0, col0, col1, col1])
    return geo


def flower(seed: int) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    for index in range(4):
        angle = math.tau * index / 4 + rng.uniform(-0.3, 0.3)
        direction = v3(math.cos(angle), 0.55, math.sin(angle))
        G.leaf_card(geo, v3(0, 0.02, 0), direction, v3(-math.sin(angle), 0, math.cos(angle)), 0.5, 0.32, "small", "leaves",
                    bend=0.2, fold=0.1, segments=2, columns=3, sway=(0.0, 0.8), phase=rng.random(), ao=(0.6, 1.0))
    heads = 3
    for h in range(heads):
        angle = math.tau * h / heads + rng.uniform(-0.4, 0.4)
        top = v3(math.cos(angle) * 0.12, rng.uniform(0.45, 0.65), math.sin(angle) * 0.12)
        G.tube(geo, [v3(0, 0, 0), top * 0.5 + v3(0, 0.05, 0), top], [0.014, 0.012, 0.01], 4, "stem", sway=[0.0, 0.4, 0.7])
        petals = 6
        centre_id = geo.vert(top + UP * 0.015)
        for p in range(petals):
            a0 = math.tau * p / petals
            a1 = a0 + math.tau / petals
            mid = (a0 + a1) * 0.5
            tip = top + v3(math.cos(mid) * 0.13, 0.05, math.sin(mid) * 0.13)
            left = top + v3(math.cos(a0) * 0.05, 0.02, math.sin(a0) * 0.05)
            right = top + v3(math.cos(a1) * 0.05, 0.02, math.sin(a1) * 0.05)
            ids = (centre_id, geo.vert(right), geo.vert(tip), geo.vert(left))
            geo.face(ids, [(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)], "petal", normals=UP,
                     uv2=(0.8, h * 0.3), col=[ao_colour(0.75), ao_colour(0.95), ao_colour(1.0), ao_colour(0.95)])
        G.blob(geo, top + UP * 0.03, v3(0.03, 0.025, 0.03), "paint_pollen", subdiv=1, rough=0.0)
    return geo


def liana(seed: int, length: float) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    steps = 14
    points = []
    for k in range(steps + 1):
        t = k / steps
        points.append(v3(math.sin(t * 5.0 + seed) * 0.25, -length * t, math.cos(t * 4.0 + seed) * 0.18))
    G.tube(geo, points, [0.05 - 0.02 * k / steps for k in range(steps + 1)], 5, "bark", uv_len=1.0,
           sway=[k / steps for k in range(steps + 1)], phase=seed * 0.1, colours=[ao_colour(0.8)] * (steps + 1))
    for k in range(2, steps + 1):
        t = k / steps
        at = points[k]
        for _ in range(2):
            angle = rng.uniform(0, math.tau)
            out = v3(math.cos(angle), rng.uniform(-0.6, 0.2), math.sin(angle))
            G.leaf_card(geo, at, out, v3(-math.sin(angle), 0, math.cos(angle)), 0.55, 0.36, "small", "leaves", bend=0.15,
                        fold=0.08, segments=1, columns=2, sway=(t, t), phase=seed * 0.1, ao=(0.85, 1.0))
    return geo


def canopy(seed: int) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    tips = []
    for b in range(4):
        angle = math.tau * b / 4 + rng.uniform(-0.4, 0.4)
        out = v3(math.cos(angle), rng.uniform(-0.1, 0.25), math.sin(angle))
        points = branch(geo, rng, v3(0, 0.3, 0), out, rng.uniform(1.4, 2.0), 0.12, 0.04, sides=5, steps=3, rise=0.1,
                        sway0=0.1, sway1=0.45, phase=b * 0.25)
        tips.append(points[-1])
        tips.append(points[1])
    crown_from_branches(geo, rng, tips, crown_centre=v3(0, 0.0, 0), crown_radius=2.2, lod=False, per_tip=7, lod_per_tip=3,
                        card=1.5, cell="twig", cluster_r=1.0, droop=0.35)
    return geo


def rock(seed: int, size: Vector, subdiv: int = 3, crease: float = 0.25) -> Geo:
    geo = Geo()
    G.blob(geo, v3(0, size.y * 0.3, 0), size, "stone", subdiv=subdiv, rough=0.28, freq=1.1, seed=seed, flat_bottom=0.3,
           uv_scale=0.6, crease=crease, colour=lambda p: ao_colour(0.7 + 0.3 * max(0.0, min(1.0, p.y / max(size.y, 0.1) + 0.5))))
    return geo


def cliff() -> Geo:
    geo = Geo()
    G.blob(geo, v3(0, 0, 0), v3(1, 1, 1), "stone", subdiv=4, rough=0.35, freq=1.6, seed=77, flat_bottom=0.25, uv_scale=2.0,
           crease=0.6, colour=lambda p: ao_colour(0.7 + 0.3 * max(0.0, min(1.0, p.y + 0.5))))
    return geo


# ------------------------------------------------------------------ temple

def temple_block(geo, centre, half, rng, *, chip=0.012, radius=0.06, colour=None):
    G.bevel_box(geo, centre, half, "sandstone", radius=radius, segments=2, uv_scale=0.45, jitter=chip, rng=rng,
                rotation=Matrix.Rotation(rng.uniform(-0.03, 0.03), 3, "Y"),
                uv_offset=(rng.random(), rng.random()), colour=colour or ao_colour(rng.uniform(0.85, 1.0)))


def glyph(geo, centre, normal_axis: str, size: float, rng):
    """A carved round sun glyph: a lathe disc ring standing out of a face."""
    axis = {"z": Matrix.Rotation(math.pi / 2, 3, "X"), "x": Matrix.Rotation(-math.pi / 2, 3, "Z")}[normal_axis]
    profile = [(0.0, 0.03), (size * 0.25, 0.035), (size * 0.32, 0.0), (size * 0.62, 0.0), (size * 0.7, 0.04), (size * 0.85, 0.04), (size * 0.9, 0.0)][::-1]
    G.lathe(geo, profile, 16, "sandstone", centre=centre, axis=axis, smooth_angle=40)


def pillar(seed: int, broken: bool) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    temple_block(geo, v3(0, 0.2, 0), v3(0.8, 0.2, 0.8), rng)
    y = 0.4
    blocks = 4 if broken else 6
    for b in range(blocks):
        h = rng.uniform(0.8, 0.95)
        w = 0.55 + rng.uniform(-0.03, 0.03)
        shift = v3(rng.uniform(-0.05, 0.05), 0, rng.uniform(-0.05, 0.05))
        temple_block(geo, shift + v3(0, y + h * 0.5, 0), v3(w, h * 0.5 - 0.015, w), rng)
        if b == 2:
            for axis, sign in (("z", 1), ("x", 1), ("z", -1), ("x", -1)):
                offset = v3(0, y + h * 0.5, 0) + (v3(0, 0, w) if axis == "z" else v3(w, 0, 0)) * sign
                rot = Matrix.Rotation(0 if axis == "z" else math.pi / 2, 4, "Y")
                if sign < 0:
                    rot = Matrix.Rotation(math.pi, 4, "Y") @ rot
                small = Geo()
                glyph(small, v3(0, 0, 0), "z", 0.35, rng)
                geo.extend(small.transformed(Matrix.Translation(shift + offset) @ rot))
        y += h
    if broken:
        G.blob(geo, v3(0.05, y + 0.15, 0.0), v3(0.5, 0.3, 0.5), "sandstone", subdiv=2, rough=0.35, freq=2.0, seed=seed,
               flat_bottom=0.5, uv_scale=0.45)
        G.blob(geo, v3(1.1, 0.15, 0.6), v3(0.45, 0.3, 0.35), "sandstone", subdiv=2, rough=0.3, freq=2.0, seed=seed + 1,
               flat_bottom=0.4, uv_scale=0.45)
    else:
        temple_block(geo, v3(0, y + 0.2, 0), v3(0.75, 0.2, 0.75), rng)
        temple_block(geo, v3(0, y + 0.52, 0), v3(0.6, 0.12, 0.6), rng)
    return geo


def arch() -> Geo:
    rng = random.Random(505)
    geo = Geo()
    width, height = 5.6, 4.8
    for side in (-1, 1):
        y = 0.0
        while y < height - 0.05:
            h = min(rng.uniform(0.55, 0.75), height - y)
            temple_block(geo, v3(side * width * 0.5 + rng.uniform(-0.03, 0.03), y + h * 0.5, 0), v3(0.45, h * 0.5 - 0.015, 0.5), rng)
            y += h
    x = -width * 0.5 - 0.7
    while x < width * 0.5 + 0.69:
        w = min(rng.uniform(0.9, 1.3), width * 0.5 + 0.7 - x)
        temple_block(geo, v3(x + w * 0.5, height + 0.35, 0), v3(w * 0.5 - 0.015, 0.35, 0.6), rng)
        x += w
    temple_block(geo, v3(0, height + 0.95, 0), v3(1.0, 0.25, 0.5), rng)
    glyph(geo, v3(0, height + 0.95, 0.5), "z", 0.4, rng)
    glyph(geo, v3(0, height + 0.35, 0.6), "z", 0.28, rng)
    for side in (-1, 1):
        temple_block(geo, v3(side * 1.6, height + 0.85, 0), v3(0.45, 0.15, 0.45), rng)
    return geo


def wall() -> Geo:
    rng = random.Random(606)
    geo = Geo()
    y = 0.0
    row = 0
    while y < 2.4:
        h = rng.uniform(0.4, 0.55)
        x = -2.0 + (0.3 if row % 2 else 0.0) - 0.3
        while x < 2.0:
            w = rng.uniform(0.6, 1.0)
            missing = y > 1.5 and rng.random() < 0.35 + (y - 1.5) * 0.4
            if not missing and x + w > -2.0:
                left, right = max(x, -2.0), min(x + w, 2.0)
                temple_block(geo, v3((left + right) * 0.5, y + h * 0.5, rng.uniform(-0.03, 0.03)),
                             v3((right - left) * 0.5 - 0.02, h * 0.5 - 0.02, 0.4), rng, chip=0.015)
            x += w
        y += h
        row += 1
    return geo


def statue() -> Geo:
    rng = random.Random(707)
    geo = Geo()
    temple_block(geo, v3(0, 0.3, 0), v3(1.05, 0.3, 0.95), rng)
    temple_block(geo, v3(0, 0.85, 0), v3(0.85, 0.25, 0.75), rng)
    # Round friendly head with leaf crown (original design).
    G.blob(geo, v3(0, 2.15, 0), v3(1.15, 1.1, 0.95), "sandstone", subdiv=4, rough=0.03, freq=1.5, seed=7, uv_scale=0.45)
    for side in (-1, 1):
        G.blob(geo, v3(side * 1.12, 2.3, -0.05), v3(0.28, 0.38, 0.18), "sandstone", subdiv=2, rough=0.04, seed=8 + side, uv_scale=0.45)
        # Eyes: carved rings with a round pupil stone.
        eye_rot = Matrix.Rotation(math.pi / 2, 3, "X")
        G.lathe(geo, [(0.0, 0.06), (0.12, 0.06), (0.2, 0.0), (0.26, -0.02), (0.3, 0.04), (0.34, -0.06)][::-1], 14, "sandstone",
                centre=v3(side * 0.42, 2.38, 0.83), axis=eye_rot, smooth_angle=45)
        G.blob(geo, v3(side * 0.42, 2.38, 0.92), v3(0.11, 0.11, 0.06), "moss", subdiv=2, rough=0.0, seed=9)
    # Smile: a bent tube.
    smile = [v3(math.sin(t) * 0.45, 1.78 - math.cos(t) * 0.12 + 0.12, 0.86 + 0.05 * math.cos(t)) for t in [(-0.9 + 1.8 * k / 8) for k in range(9)]]
    G.tube(geo, smile, [0.05] * 9, 6, "sandstone", uv_len=0.5)
    G.blob(geo, v3(0, 2.05, 0.97), v3(0.13, 0.1, 0.1), "sandstone", subdiv=2, rough=0.0, seed=10, uv_scale=0.45)
    # Leaf crown carved in stone.
    for leaf in range(7):
        angle = -1.1 + leaf * (2.2 / 6)
        centre = v3(math.sin(angle) * 0.85, 3.1 + math.cos(angle) * 0.25, math.cos(angle) * 0.25 - 0.1)
        rot = Matrix.Rotation(angle * 0.9, 4, "Z")
        piece = Geo()
        G.blob(piece, v3(0, 0, 0), v3(0.22, 0.48, 0.09), "sandstone", subdiv=2, rough=0.04, seed=11 + leaf, uv_scale=0.45)
        geo.extend(piece.transformed(Matrix.Translation(centre) @ rot))
    return geo


def stairs() -> Geo:
    rng = random.Random(808)
    geo = Geo()
    for step in range(5):
        x = -1.5
        while x < 1.5:
            w = min(rng.uniform(0.8, 1.2), 1.5 - x)
            temple_block(geo, v3(x + w * 0.5, step * 0.3 + 0.15, -step * 0.4), v3(w * 0.5 - 0.015, 0.15, 0.4 + step * 0.0), rng)
            x += w
    return geo


def block() -> Geo:
    rng = random.Random(909)
    geo = Geo()
    temple_block(geo, v3(0, 0, 0), v3(0.5, 0.5, 0.5), rng, chip=0.02, radius=0.07)
    return geo


def rubble() -> Geo:
    rng = random.Random(1010)
    geo = Geo()
    for index in range(7):
        half = v3(rng.uniform(0.35, 0.6), rng.uniform(0.25, 0.4), rng.uniform(0.3, 0.5))
        at = v3(rng.uniform(-0.6, 0.6), half.y + (0.0 if index < 4 else 0.55), rng.uniform(-0.5, 0.5))
        temple_block(geo, at, half, rng, chip=0.03)
    for index in range(3):
        G.blob(geo, v3(rng.uniform(-0.9, 0.9), 0.15, rng.uniform(-0.8, 0.8)), v3(0.3, 0.2, 0.3), "stone", subdiv=1,
               rough=0.3, seed=20 + index, flat_bottom=0.4)
    return geo


# ------------------------------------------------------------------ wood and gameplay pieces

def post() -> Geo:
    geo = Geo()
    profile = [(0.0, -0.5), (0.44, -0.5), (0.5, -0.46), (0.5, 0.42), (0.46, 0.49), (0.3, 0.5), (0.0, 0.5)]
    G.lathe(geo, profile, 10, "wood", uv_len=1.0, smooth_angle=50)
    return geo


def plank() -> Geo:
    geo = Geo()
    G.bevel_box(geo, v3(0, 0, 0), v3(0.5, 0.5, 0.5), "wood", radius=0.08, segments=2, uv_scale=1.0)
    return geo


def rope() -> Geo:
    geo = Geo()
    for strand in range(2):
        offset = strand * math.pi
        points = [v3(math.cos(offset + t * 8.0) * 0.18, math.sin(offset + t * 8.0) * 0.18, -0.5 + t) for t in [k / 10 for k in range(11)]]
        G.tube(geo, points, [0.3] * 11, 4, "rope", uv_len=0.3)
    return geo


def iron_rail() -> Geo:
    geo = Geo()
    G.bevel_box(geo, v3(0, 0.3, 0), v3(0.5, 0.2, 0.5), "iron", radius=0.06, segments=1, uv_scale=1.0)
    G.bevel_box(geo, v3(0, -0.05, 0), v3(0.18, 0.2, 0.5), "iron", radius=0.03, segments=1, uv_scale=1.0)
    G.bevel_box(geo, v3(0, -0.4, 0), v3(0.5, 0.1, 0.5), "iron", radius=0.03, segments=1, uv_scale=1.0)
    return geo


def barrel() -> Geo:
    geo = Geo()
    axis = Matrix.Rotation(-math.pi / 2, 3, "X")  # lathe Y axis -> Godot -Z (the mouth)
    staves = 18
    profile = []
    for k in range(9):
        t = k / 8
        profile.append((0.62 + 0.12 * math.sin(math.pi * t), -0.75 + 1.5 * t))
    body = G.lathe(geo, profile, staves * 2, "wood", uv_around=4.0, uv_len=1.5, axis=axis, smooth_angle=60)
    # Stave seams: pull every second ring vertex in a little.
    seam_ids = set()
    for fid in body:
        for i in geo.faces[fid]:
            p = geo.verts[i]
            angle = math.atan2(p.y, p.x)
            k = round(angle / (math.tau / (staves * 2)))
            if k % 2 == 0:
                seam_ids.add(i)
    for i in seam_ids:
        p = geo.verts[i]
        geo.verts[i] = v3(p.x * 0.985, p.y * 0.985, p.z)
    for at in (-0.55, 0.0, 0.55):
        r = 0.62 + 0.12 * math.sin(math.pi * (at + 0.75) / 1.5) + 0.012
        G.lathe(geo, [(r - 0.005, at - 0.06), (r + 0.02, at - 0.05), (r + 0.02, at + 0.05), (r - 0.005, at + 0.06)], 36, "iron",
                axis=axis, uv_len=0.5, smooth_angle=60)
    # Back lid (planks) and the dark open mouth with a rim.
    G.lathe(geo, [(0.0, -0.73), (0.6, -0.73), (0.64, -0.76)], 18, "wood", axis=axis, smooth_angle=20)
    G.lathe(geo, [(0.64, 0.76), (0.6, 0.72), (0.52, 0.6), (0.0, 0.55)], 18, "paint_dark", axis=axis, smooth_angle=50)
    return geo


def crate() -> Geo:
    rng = random.Random(1111)
    geo = Geo()
    G.bevel_box(geo, v3(0, 0.5, 0), v3(0.47, 0.47, 0.47), "wood", radius=0.02, uv_scale=1.0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            G.bevel_box(geo, v3(sx * 0.46, 0.5, sz * 0.46), v3(0.06, 0.5, 0.06), "wood", radius=0.02, uv_scale=1.0,
                        uv_offset=(rng.random(), 0))
    return geo


def cart() -> Geo:
    geo = Geo()
    G.bevel_box(geo, v3(0, 0.55, 0), v3(0.8, 0.1, 1.1), "wood", radius=0.04, uv_scale=0.8)
    for side in (-1, 1):
        for k in range(3):
            G.bevel_box(geo, v3(side * 0.76, 0.75 + k * 0.22, 0), v3(0.05, 0.1, 1.08), "wood", radius=0.03, uv_scale=0.8,
                        uv_offset=(0.3 * k, 0.1 * k))
            G.bevel_box(geo, v3(0, 0.75 + k * 0.22, side * 1.06), v3(0.74, 0.1, 0.05), "wood", radius=0.03, uv_scale=0.8,
                        uv_offset=(0.2 * k, 0.4))
        G.bevel_box(geo, v3(side * 0.8, 1.32, 0), v3(0.08, 0.05, 1.14), "iron", radius=0.02, uv_scale=1.0)
        G.bevel_box(geo, v3(0, 1.32, side * 1.1), v3(0.8, 0.05, 0.07), "iron", radius=0.02, uv_scale=1.0)
        for end in (-0.7, 0.7):
            G.bevel_box(geo, v3(side * 0.8, 0.95, end), v3(0.06, 0.42, 0.05), "iron", radius=0.02, uv_scale=1.0)
            wheel_axis = Matrix.Rotation(math.pi / 2, 3, "Z")
            centre = v3(side * 0.82, 0.3, end)
            G.lathe(geo, [(0.0, -0.1), (0.1, -0.1), (0.12, -0.06), (0.22, -0.05), (0.26, -0.08), (0.3, -0.07), (0.3, 0.07),
                          (0.26, 0.08), (0.22, 0.05), (0.12, 0.06), (0.1, 0.1), (0.0, 0.1)], 16, "iron",
                    centre=centre, axis=wheel_axis, smooth_angle=45)
    return geo


def lantern() -> Geo:
    geo = Geo()
    G.lathe(geo, [(0.0, 0.0), (0.09, 0.0), (0.08, 0.95), (0.06, 1.0), (0.0, 1.0)], 8, "wood", smooth_angle=50)
    G.bevel_box(geo, v3(0.15, 0.95, 0), v3(0.2, 0.025, 0.025), "iron", radius=0.01, uv_scale=1.0)
    centre = v3(0.32, 0.72, 0)
    G.lathe(geo, [(0.0, 0.0), (0.12, 0.0), (0.12, 0.04), (0.0, 0.04)], 8, "iron", centre=centre, smooth_angle=30)
    G.lathe(geo, [(0.0, 0.04), (0.1, 0.04), (0.11, 0.12), (0.1, 0.22), (0.0, 0.22)], 12, "glow_lantern", centre=centre, smooth_angle=60)
    for k in range(4):
        angle = k * math.pi / 2 + math.pi / 4
        G.bevel_box(geo, centre + v3(math.cos(angle) * 0.105, 0.13, math.sin(angle) * 0.105), v3(0.012, 0.1, 0.012), "iron",
                    radius=0.004, segments=1, uv_scale=1.0)
    G.lathe(geo, [(0.13, 0.22), (0.13, 0.25), (0.05, 0.33), (0.02, 0.36), (0.035, 0.38), (0.0, 0.4)], 8, "iron", centre=centre,
            smooth_angle=40)
    G.lathe(geo, [(0.0, 0.0), (0.02, 0.0), (0.02, 0.24), (0.0, 0.24)], 4, "iron", centre=v3(0.32, 0.95, 0) - v3(0, 0.2, 0), smooth_angle=10)
    return geo


def torch() -> Geo:
    geo = Geo()
    G.lathe(geo, [(0.0, 0.0), (0.09, 0.0), (0.085, 0.3), (0.075, 1.85), (0.0, 1.85)], 8, "wood", uv_len=1.0, smooth_angle=50)
    for y in (0.6, 1.25, 1.7):
        G.lathe(geo, [(0.085, y - 0.06), (0.1, y - 0.04), (0.1, y + 0.04), (0.085, y + 0.06)], 8, "rope", smooth_angle=60)
    G.lathe(geo, [(0.06, 1.78), (0.1, 1.8), (0.2, 1.93), (0.24, 2.08), (0.22, 2.1), (0.18, 1.98), (0.0, 1.96)], 12, "iron",
            smooth_angle=50)
    G.blob(geo, v3(0, 2.0, 0), v3(0.17, 0.07, 0.17), "paint_ember", subdiv=2, rough=0.3, seed=3)
    return geo


def gate() -> Geo:
    rng = random.Random(1212)
    geo = Geo()
    G.bevel_box(geo, v3(0, 2.2, 0), v3(2.0, 2.2, 0.25), "sandstone", radius=0.08, uv_scale=0.45)
    for row in range(3):
        for col in (-1, 1):
            G.bevel_box(geo, v3(col * 0.95, 0.85 + row * 1.35, 0.26), v3(0.8, 0.55, 0.05), "sandstone", radius=0.04,
                        uv_scale=0.45, uv_offset=(rng.random(), rng.random()))
    G.lathe(geo, [(0.0, 0.08), (0.3, 0.08), (0.38, 0.0), (0.5, 0.0), (0.56, 0.1), (0.62, 0.1), (0.66, 0.0)][::-1], 20, "paint_gold",
            centre=v3(0, 2.3, 0.3), axis=Matrix.Rotation(math.pi / 2, 3, "X"), smooth_angle=40)
    for x in (-1.9, 1.9):
        G.bevel_box(geo, v3(x, 2.2, 0.28), v3(0.08, 2.15, 0.04), "iron", radius=0.02, uv_scale=1.0)
    return geo


def boulder() -> Geo:
    geo = Geo()
    G.blob(geo, v3(0, 0, 0), v3(1, 1, 1), "stone", subdiv=4, rough=0.05, freq=1.4, seed=17, uv_scale=1.0)
    for index, tilt in enumerate((0.0, math.pi / 2, math.pi / 4)):
        axis = Matrix.Rotation(tilt, 3, "X") @ Matrix.Rotation(index * 0.7, 3, "Y")
        G.lathe(geo, [(0.985, -0.06), (1.015, -0.04), (1.015, 0.04), (0.985, 0.06)], 40, "paint_gold", axis=axis, smooth_angle=60)
    return geo


def mushroom() -> Geo:
    rng = random.Random(1313)
    geo = Geo()
    G.lathe(geo, [(0.0, 0.0), (0.36, 0.0), (0.3, 0.12), (0.25, 0.45), (0.29, 0.8), (0.0, 0.85)], 14, "paint_stem_cream",
            smooth_angle=70)
    G.lathe(geo, [(0.3, 0.8), (0.75, 0.74), (1.1, 0.7), (1.18, 0.78)], 22, "paint_spot", smooth_angle=70)
    cap = [(1.18, 0.78)]
    for k in range(1, 10):
        t = k / 9
        cap.append((1.18 * math.cos(t * math.pi / 2) ** 0.8 + 0.0, 0.78 + 0.6 * math.sin(t * math.pi / 2)))
    cap[-1] = (0.0, 1.38)
    G.lathe(geo, cap, 22, "paint_cap", smooth_angle=80)
    for spot in range(9):
        angle = math.tau * spot / 9 + rng.uniform(-0.2, 0.2)
        t = rng.uniform(0.35, 0.75)
        r = 1.18 * math.cos(t * math.pi / 2) ** 0.8
        y = 0.78 + 0.6 * math.sin(t * math.pi / 2)
        normal = v3(math.cos(angle) * math.cos(t * math.pi / 2), math.sin(t * math.pi / 2) * 1.4, math.sin(angle) * math.cos(t * math.pi / 2)).normalized()
        centre = v3(math.cos(angle) * r, y, math.sin(angle) * r)
        rot = normal.to_track_quat("Y", "Z").to_matrix().to_4x4()
        piece = Geo()
        G.blob(piece, v3(0, 0, 0), v3(0.16, 0.035, 0.16) * rng.uniform(0.8, 1.2), "paint_spot", subdiv=2, rough=0.1, seed=spot)
        geo.extend(piece.transformed(Matrix.Translation(centre) @ rot))
    G.blob(geo, v3(0, 1.37, 0), v3(0.2, 0.04, 0.2), "paint_spot", subdiv=2, rough=0.05, seed=30)
    return geo


def treasure() -> Geo:
    """A heap of gold coins with a few gems: the riches of the hidden hall."""
    rng = random.Random(1414)
    geo = Geo()
    G.blob(geo, v3(0, 0.05, 0), v3(0.85, 0.32, 0.85), "paint_gold", subdiv=3, rough=0.12, freq=3.0, seed=40, flat_bottom=0.15)
    for _ in range(34):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.95)
        centre = v3(math.cos(angle) * r, 0.0, math.sin(angle) * r)
        centre.y = max(0.03, 0.3 * (1.0 - (r / 0.95) ** 2)) + rng.uniform(0.0, 0.05)
        tilt = Matrix.Rotation(rng.uniform(-0.6, 0.6), 3, "X") @ Matrix.Rotation(rng.uniform(-0.6, 0.6), 3, "Z")
        G.lathe(geo, [(0.0, -0.012), (0.1, -0.012), (0.11, 0.0), (0.1, 0.012), (0.0, 0.012)], 10, "paint_gold", centre=centre,
                axis=tilt, smooth_angle=50)
    for k in range(3):
        angle = rng.uniform(0, math.tau)
        rot = Matrix.Rotation(rng.uniform(-0.4, 0.4), 3, "X")
        G.lathe(geo, [(0.0, 0.0), (0.09, 0.0), (0.09, 0.1), (0.0, 0.2)], 6, "glow_crystal",
                centre=v3(math.cos(angle) * 0.5, 0.18, math.sin(angle) * 0.5), axis=rot, smooth_angle=10)
    return geo


def crystal(seed: int, spikes: int, tall: float) -> Geo:
    rng = random.Random(seed)
    geo = Geo()
    for index in range(spikes):
        tilt = v3(rng.uniform(-0.55, 0.55), 1.0, rng.uniform(-0.55, 0.55)).normalized() if index else UP.copy()
        length = tall * rng.uniform(0.5, 1.0) * (1.2 if index == 0 else 1.0)
        width = rng.uniform(0.1, 0.18) * (1.3 if index == 0 else 1.0)
        rot = tilt.to_track_quat("Y", "Z").to_matrix()
        base = v3(rng.uniform(-0.2, 0.2), -0.1, rng.uniform(-0.2, 0.2)) if index else v3(0, -0.1, 0)
        G.lathe(geo, [(0.0, 0.0), (width, 0.0), (width, length * 0.72), (0.0, length)], 6, "glow_crystal", centre=base, axis=rot,
                smooth_angle=10)
    return geo


def log() -> Geo:
    geo = Geo()
    points = [v3(-2.0 + 4.0 * k / 8, 0.34 + 0.03 * math.sin(k), 0) for k in range(9)]
    radii = [0.32 + 0.03 * math.sin(k * 1.7) for k in range(9)]
    G.tube(geo, points, radii, 12, "bark", uv_around=2.0, uv_len=2.0, bump=0.08, seed=5)
    for end, sign in ((points[0], -1), (points[-1], 1)):
        axis = Matrix.Rotation(sign * math.pi / 2, 3, "Z")
        r = radii[0 if sign < 0 else -1]
        G.lathe(geo, [(0.0, 0.0), (r * 0.98, -0.01), (r + 0.01, -0.03)], 12, "wood", centre=end, axis=axis, smooth_angle=30)
    for k in range(3):
        stub_at = points[2 + k * 2]
        G.tube(geo, [stub_at, stub_at + v3(0.1, 0.45, 0.15 * (k - 1))], [0.08, 0.05], 6, "bark", cap_end=True)
    return geo


# ------------------------------------------------------------------ enemies (friendly, rounded)

def eyes(geo: Geo, positions, size: float, look=v3(0, 0, 1)):
    for p in positions:
        G.blob(geo, p, v3(size, size, size * 0.9), "paint_eye", subdiv=2, rough=0.0)
        G.blob(geo, p + look * size * 0.75, v3(size * 0.5, size * 0.55, size * 0.3), "paint_pupil", subdiv=2, rough=0.0)
        G.blob(geo, p + look * size * 0.95 + v3(size * 0.15, size * 0.2, 0), v3(size * 0.14, size * 0.14, size * 0.08), "paint_eye",
               subdiv=1, rough=0.0)


def crab() -> Geo:
    geo = Geo()
    G.blob(geo, v3(0, 0.42, 0), v3(0.62, 0.32, 0.46), "paint_crab", subdiv=4, rough=0.04, freq=1.0, seed=1,
           colour=lambda p: ao_colour(0.75 + 0.25 * max(0.0, min(1.0, p.y / 0.3 + 0.6))))
    G.blob(geo, v3(0, 0.3, 0.05), v3(0.5, 0.18, 0.38), "paint_crab_belly", subdiv=2, rough=0.0)
    for side in (-1, 1):
        G.tube(geo, [v3(side * 0.45, 0.42, 0.2), v3(side * 0.66, 0.5, 0.3), v3(side * 0.8, 0.52, 0.38)], [0.08, 0.07, 0.065], 7, "paint_crab")
        G.blob(geo, v3(side * 0.88, 0.55, 0.44), v3(0.24, 0.19, 0.2), "paint_crab", subdiv=2, rough=0.03, seed=2)
        G.blob(geo, v3(side * 0.82, 0.66, 0.62), v3(0.08, 0.06, 0.16), "paint_crab", subdiv=2, rough=0.0, seed=3)
        G.blob(geo, v3(side * 0.9, 0.48, 0.62), v3(0.07, 0.05, 0.14), "paint_crab", subdiv=2, rough=0.0, seed=4)
        G.tube(geo, [v3(side * 0.2, 0.65, 0.2), v3(side * 0.24, 0.92, 0.25)], [0.045, 0.035], 6, "paint_crab")
        for leg in range(3):
            z = -0.22 + leg * 0.2
            G.tube(geo, [v3(side * 0.5, 0.36, z), v3(side * 0.78, 0.32, z), v3(side * 0.9, 0.02, z - 0.04)], [0.05, 0.045, 0.025], 6,
                   "paint_crab", cap_end=True)
    eyes(geo, [v3(-0.24, 1.0, 0.28), v3(0.24, 1.0, 0.28)], 0.12)
    smile = [v3(math.sin(t) * 0.2, 0.42 - math.cos(t) * 0.06 + 0.06, 0.45 + 0.02 * math.cos(t)) for t in [(-1.0 + 2.0 * k / 6) for k in range(7)]]
    G.tube(geo, smile, [0.022] * 7, 5, "paint_dark")
    return geo


def beetle() -> Geo:
    geo = Geo()
    for side in (-1, 1):
        G.blob(geo, v3(side * 0.24, 0.45, -0.05), v3(0.28, 0.33, 0.6), "paint_beetle", subdiv=4, rough=0.02, seed=5 + side,
               colour=lambda p: ao_colour(0.7 + 0.3 * max(0.0, min(1.0, p.y / 0.33 + 0.5))))
    G.blob(geo, v3(0, 0.36, 0.0), v3(0.46, 0.22, 0.6), "paint_dark", subdiv=2, rough=0.0)
    G.blob(geo, v3(0, 0.4, 0.6), v3(0.3, 0.24, 0.24), "paint_dark", subdiv=2, rough=0.02)
    eyes(geo, [v3(-0.13, 0.48, 0.78), v3(0.13, 0.48, 0.78)], 0.09)
    for side in (-1, 1):
        G.tube(geo, [v3(side * 0.1, 0.56, 0.75), v3(side * 0.2, 0.75, 0.88), v3(side * 0.32, 0.88, 0.95)], [0.025, 0.02, 0.015], 5, "paint_dark")
        G.blob(geo, v3(side * 0.33, 0.9, 0.96), v3(0.04, 0.04, 0.04), "paint_beetle", subdiv=1, rough=0.0)
        for leg in range(3):
            z = -0.3 + leg * 0.3
            G.tube(geo, [v3(side * 0.38, 0.3, z), v3(side * 0.62, 0.22, z + 0.05), v3(side * 0.72, 0.01, z)], [0.04, 0.035, 0.025], 5,
                   "paint_dark", cap_end=True)
    return geo


def coconut() -> Geo:
    geo = Geo()
    G.blob(geo, v3(0, 0.45, 0), v3(0.45, 0.45, 0.45), "coconut_husk", subdiv=4, rough=0.04, freq=2.0, seed=13, uv_scale=1.2)
    eyes(geo, [v3(-0.15, 0.56, 0.37), v3(0.15, 0.56, 0.37)], 0.095)
    smile = [v3(math.sin(t) * 0.14, 0.36 - math.cos(t) * 0.05 + 0.05, 0.42 + 0.02 * math.cos(t)) for t in [(-1.0 + 2.0 * k / 6) for k in range(7)]]
    G.tube(geo, smile, [0.02] * 7, 5, "paint_dark")
    rng = random.Random(14)
    for k in range(5):
        angle = math.tau * k / 5
        G.leaf_card(geo, v3(0, 0.86, 0), v3(math.cos(angle), 1.3, math.sin(angle)), v3(-math.sin(angle), 0, math.cos(angle)), 0.35,
                    0.24, "small", "leaves", bend=0.08, fold=0.1, segments=1, columns=2, sway=(0.0, 0.4), phase=rng.random())
    return geo


# ------------------------------------------------------------------ catalogue

def catalogue():
    """name -> (builder, notes). LOD variants end in _lod."""
    items = {
        "tree_broad": lambda: tree_broad(False),
        "tree_broad_lod": lambda: tree_broad(True),
        "tree_slender": lambda: tree_slender(False),
        "tree_slender_lod": lambda: tree_slender(True),
        "tree_fig": lambda: tree_fig(False),
        "tree_fig_lod": lambda: tree_fig(True),
        "tree_kapok": lambda: tree_kapok(False),
        "tree_kapok_lod": lambda: tree_kapok(True),
        "palm_a": lambda: palm(505, 11.0, False),
        "palm_a_lod": lambda: palm(505, 11.0, True),
        "palm_b": lambda: palm(506, 14.0, False),
        "palm_b_lod": lambda: palm(506, 14.0, True),
        "fern_a": lambda: fern(201, 9, 1.35, 0.55),
        "fern_b": lambda: fern(202, 7, 1.8, 0.9),
        "bigleaf_a": lambda: bigleaf(301, 6, 0.9, 1.35, 0.55, 0.25),
        "bigleaf_b": lambda: bigleaf(302, 5, 0.75, 1.0, 0.75, 0.45),
        "bush": lambda: bush(1100),
        "grass": lambda: grass(401, 16, 0.7),
        "groundcover": lambda: groundcover(402),
        "flower": lambda: flower(900),
        "liana_a": lambda: liana(1000, 5.0),
        "liana_b": lambda: liana(1001, 7.0),
        "liana_c": lambda: liana(1002, 9.0),
        "canopy": lambda: canopy(1101),
        "rock_a": lambda: rock(600, v3(1.4, 0.9, 1.2)),
        "rock_b": lambda: rock(601, v3(1.5, 0.6, 1.1), crease=0.4),
        "cliff": cliff,
        "pillar": lambda: pillar(700, False),
        "pillar_broken": lambda: pillar(701, True),
        "arch": arch,
        "wall": wall,
        "statue": statue,
        "stairs": stairs,
        "block": block,
        "rubble": rubble,
        "post": post,
        "plank": plank,
        "rope": rope,
        "rail": iron_rail,
        "barrel": barrel,
        "crate": crate,
        "cart": cart,
        "lantern": lantern,
        "torch": torch,
        "gate": gate,
        "boulder": boulder,
        "mushroom": mushroom,
        "crystal_a": lambda: crystal(800, 7, 1.3),
        "crystal_b": lambda: crystal(801, 4, 2.0),
        "log": log,
        "treasure": treasure,
        "crab": crab,
        "beetle": beetle,
        "coconut": coconut,
    }
    return items


# ------------------------------------------------------------------ export

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path: Path):
    data = path.read_bytes()
    json_length, _ = struct.unpack_from("<II", data, 12)
    document = json.loads(data[20:20 + json_length])
    offset = 20 + json_length
    binary = b""
    if offset < len(data):
        bin_length, _ = struct.unpack_from("<II", data, offset)
        binary = data[offset + 8:offset + 8 + bin_length]
    return document, binary


def write_glb(path: Path, document: dict, binary: bytes) -> None:
    text = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    chunks = struct.pack("<II", len(text), JSON_CHUNK) + text
    if binary:
        chunks += struct.pack("<II", len(binary), BIN_CHUNK) + binary
    path.write_bytes(struct.pack("<III", GLB_MAGIC, 2, 12 + len(chunks)) + chunks)


def finish_glb(path: Path) -> dict:
    """Images become references to the shared texture files; leaf materials get alpha cut."""
    document, binary = read_glb(path)
    removed = set()
    for image in document.get("images", []):
        name = image.get("name", "")
        match = None
        for candidate in TEXTURES.iterdir():
            if candidate.stem == Path(name).stem:
                match = candidate
                break
        if match is None:
            raise ValueError(f"{path.name}: image {name} has no texture file")
        if "bufferView" in image:
            removed.add(image["bufferView"])
        image.clear()
        image.update({"name": match.stem, "uri": f"textures/{match.name}"})
    if removed:
        views = document["bufferViews"]
        remap, rebuilt, kept = {}, bytearray(), []
        for old, view in enumerate(views):
            if old in removed:
                continue
            start = view.get("byteOffset", 0)
            payload = binary[start:start + view["byteLength"]]
            rebuilt += b"\0" * (-len(rebuilt) % 4)
            updated = dict(view)
            updated["byteOffset"] = len(rebuilt)
            rebuilt += payload
            remap[old] = len(kept)
            kept.append(updated)
        document["bufferViews"] = kept
        for accessor in document.get("accessors", []):
            if "bufferView" in accessor:
                accessor["bufferView"] = remap[accessor["bufferView"]]
        document["buffers"][0]["byteLength"] = len(rebuilt) + (-len(rebuilt) % 4)
        binary = bytes(rebuilt)
    for material in document.get("materials", []):
        spec = MATERIALS.get(material.get("name", ""), {})
        if spec.get("mask"):
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = 0.45
        else:
            material.pop("alphaMode", None)
            material.pop("alphaCutoff", None)
        if spec.get("mask") or spec.get("double"):
            material["doubleSided"] = True
    document.setdefault("asset", {})["generator"] = "Lumo jungle art (tools/lumo_run_art/build_jungle_art.py)"
    write_glb(path, document, binary)
    return document


def export(name: str, geo: Geo, materials: dict) -> dict:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    obj = geo.to_blender(name, materials)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = MODELS / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_texcoords=True, export_normals=True, export_tangents=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_image_format="AUTO", export_animations=False, export_cameras=False, export_lights=False,
                              export_extras=False)
    document = finish_glb(path)
    xs = [v.x for v in geo.verts]
    ys = [v.y for v in geo.verts]
    zs = [v.z for v in geo.verts]
    return {
        "file": f"{name}.glb",
        "triangles": geo.triangles(),
        "vertices": len(geo.verts),
        "materials": [m["name"] for m in document.get("materials", [])],
        "bytes": path.stat().st_size,
        "size_m": [round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2), round(max(zs) - min(zs), 2)],
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="", help="comma separated model names")
    parser.add_argument("--keep-textures", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    MODELS.mkdir(parents=True, exist_ok=True)
    if not args.keep_textures:
        import jungle_textures
        jungle_textures.OUT = TEXTURES
        jungle_textures.build()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    noise.seed_set(SEED)
    materials = {name: make_material(name) for name in MATERIALS}
    wanted = [n for n in args.only.split(",") if n]
    manifest_path = MODELS / "jungle_art.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() and wanted else {"models": {}}
    for name, builder in catalogue().items():
        if wanted and name not in wanted:
            continue
        geo = builder()
        entry = export(name, geo, materials)
        manifest["models"][name] = entry
        print(f"[jungle_art] {name}: {entry['triangles']} triangles, {entry['bytes'] // 1024} KB, materials {entry['materials']}", flush=True)
    manifest["generator"] = "tools/lumo_run_art/build_jungle_art.py"
    manifest["seed"] = SEED
    manifest["textures"] = sorted(p.name for p in TEXTURES.iterdir() if p.suffix in (".png", ".jpg"))
    manifest["models"] = dict(sorted(manifest["models"].items()))
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
