#!/usr/bin/env python3
"""Author the LUMO village height map (Eigenbau, seeded, reproducible).

One contiguous 880 m x 640 m valley (since 2026-11: was 640 m x 480 m). The
child's town grows in square rings around x=-100 up to 65 x 65 plots (4225,
plot spacing 5.3 m); the old 33 x 33 district (1089 plots) keeps every address
and every buildable plot. The three neighbour towns get their own districts on
the east bank (19 x 19 plots each). Gentle meadow hills, a river with banks
through the middle, a mountain range in the north, alpine lakes east and west
and a coast in the south. Rocky hills, every steep or wet plot and every plot
inside a neighbour's district are recorded as NOT buildable for the child.

The first 225 plots (rings 0..7) of each town are always buildable and every
plot of the old 1089 district that was buildable stays buildable, so every
existing save and every early campaign chapter keeps its land.

Output: assets/creative/village3d/terrain/village_heightmap.tres
Run:    /home/user/tools/bpyenv/bin/python tools/lumo_village_art/make_terrain.py [--check] [--preview out.png]
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/village3d/terrain/village_heightmap.tres"
# The buildable/blocked split of the old 1089-plot district (map of 2026-10),
# frozen so a regenerated map never takes land away from an existing village.
OLD_BLOCKED = Path(__file__).resolve().parent / "old_blocked_player_1089.json"
ORIGIN = (-440.0, -320.0)
STEP = 2.5
WIDTH = 353
DEPTH = 257
WATER = -1.1
TOWN_CENTER = 100.0
SPACING = 5.3
MAX_PLOTS = 4225
OLD_PLOTS = 1089
RIVAL_PLOTS = 1089
SAFE_PLOTS = 225
# Neighbour districts (id, centre x, centre z); 19 x 19 sites = rings 0..9.
NEIGHBOR_SITES = [("leo", 190.0, -5.0), ("ella", 165.0, -125.0), ("flitz", 170.0, 120.0)]
NEIGHBOR_PLOTS = 361
NEIGHBOR_HALF = 9.5 * SPACING
HILLS = [
    # x, z, radius, height  (outer rings only: never inside the first 225 plots)
    (-158.0, -62.0, 13.0, 9.0), (-42.0, 66.0, 10.0, 6.5), (-172.0, 50.0, 15.0, 12.0),
    (-118.0, -80.0, 9.0, 5.5), (152.0, -56.0, 14.0, 10.0), (46.0, -70.0, 10.0, 7.0),
    (168.0, 62.0, 13.0, 11.0), (120.0, 81.0, 9.0, 6.0),
    # New outer rings of the grown town (rings 17..32): a few rocky knolls.
    (-232.0, -118.0, 15.0, 10.0), (-58.0, 142.0, 13.0, 8.0), (-246.0, 104.0, 12.0, 9.0),
    (-150.0, 150.0, 10.0, 6.0), (-196.0, -150.0, 11.0, 7.0), (40.0, 128.0, 11.0, 7.0),
]
# Places on the map that tell a story and stay free of houses (x, z, radius):
# Funkel's cave, Krummzahn's camp and the wood grove the neighbours want.
RESERVED = [(-196.0, -86.0, 10.0), (-178.0, 78.0, 9.0), (-190.0, 30.0, 9.0)]
LAKES = [(338.0, 40.0, 26.0), (-352.0, -30.0, 24.0)]


def river_center(z):
    return 2.4 * np.sin(z * 0.021) + 1.5 * np.sin(z * 0.057 + 1.3)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def value_noise(x, z, freq, seed):
    gx = x * freq
    gz = z * freq
    ix = np.floor(gx).astype(np.int64)
    iz = np.floor(gz).astype(np.int64)
    fx = gx - ix
    fz = gz - iz

    def h(a, b):
        v = (a * 374761393 + b * 668265263 + seed * 2654435761) & 0xFFFFFFFF
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0

    ux = fx * fx * (3 - 2 * fx)
    uz = fz * fz * (3 - 2 * fz)
    a = h(ix, iz)
    b = h(ix + 1, iz)
    c = h(ix, iz + 1)
    d = h(ix + 1, iz + 1)
    return (a * (1 - ux) + b * ux) * (1 - uz) + (c * (1 - ux) + d * ux) * uz


def fbm(x, z, freq, seed, octaves=4):
    total = 0.0
    amp = 1.0
    norm = 0.0
    for octave in range(octaves):
        total = total + value_noise(x, z, freq * 2 ** octave, seed + octave * 31) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def plot_coordinate(index):
    if index < 9:
        return index % 3 - 1, index // 3 - 1
    ring = 2
    while index >= (ring * 2 + 1) ** 2:
        ring += 1
    offset = index - (ring * 2 - 1) ** 2
    if offset < ring * 2:
        return ring, offset - ring + 1
    offset -= ring * 2
    if offset < ring * 2 - 1:
        return offset - ring + 1, ring
    offset -= ring * 2 - 1
    if offset < ring * 2 + 1:
        return -ring, offset - ring
    offset -= ring * 2 + 1
    return offset - ring + 1, -ring


def plot_position(index, opponent):
    cx, cz = plot_coordinate(index)
    return (TOWN_CENTER if opponent else -TOWN_CENTER) + cx * SPACING, cz * SPACING


def masks(x, z):
    hill = np.zeros_like(x)
    for hx, hz, hr, _ in HILLS:
        d = np.sqrt((x - hx) ** 2 + (z - hz) ** 2)
        hill = np.maximum(hill, np.exp(-(d / hr) ** 2 * 1.3))
    north = smoothstep(-192.0, -254.0, z + (fbm(x, z, 0.010, 7, 3) - 0.5) * 48.0)
    side = smoothstep(300.0, 372.0, np.abs(x) + (fbm(x, z, 0.011, 9, 3) - 0.5) * 56.0)
    mountain = np.maximum(north, side)
    return hill, mountain


def raw_height(x, z):
    h = 1.5 + (fbm(x, z, 0.019, 1, 3) - 0.5) * 2.4 + (fbm(x, z, 0.0065, 2, 3) - 0.5) * 3.4
    hill, mountain = masks(x, z)
    for hx, hz, hr, hh in HILLS:
        d = np.sqrt((x - hx) ** 2 + (z - hz) ** 2)
        shape = np.exp(-(d / hr) ** 2 * 1.3)
        rough = 0.75 + 0.5 * fbm(x, z, 0.09, 13, 3)
        h = h + hh * shape * rough
    ridged = 1.0 - np.abs(2.0 * fbm(x, z, 0.0105, 3, 4) - 1.0)
    detail = fbm(x, z, 0.034, 4, 4)
    peaks = (ridged ** 2.2) * 0.72 + detail * 0.28
    gorge = 0.18 + 0.82 * smoothstep(9.0, 52.0, np.abs(x - river_center(z)))
    edge = smoothstep(400.0, 440.0, np.abs(x)) + smoothstep(-282.0, -320.0, z)
    h = h + (mountain ** 1.05) * (12.0 + 62.0 * peaks) * np.where(z < 0, gorge, 1.0) + edge * 12.0
    for lx, lz, lr in LAKES:
        d = np.sqrt((x - lx) ** 2 + (z - lz) ** 2) + (fbm(x, z, 0.03, 17, 2) - 0.5) * 10.0
        lake = smoothstep(lr + 16.0, lr - 4.0, d)
        h = h * (1 - lake) + (-6.0) * lake
    coast_line = 214.0 + (fbm(x, z, 0.008, 5, 3) - 0.5) * 44.0
    sea = smoothstep(coast_line - 16.0, coast_line + 18.0, z)
    h = h * (1 - sea) + (-7.5) * sea
    d = np.abs(x - river_center(z))
    bank = smoothstep(4.6, 11.0, d)
    h = np.minimum(h, h * bank + (-2.9) * (1 - bank))
    return h


def sample(grid, x, z):
    gx = np.clip((np.asarray(x) - ORIGIN[0]) / STEP, 0, WIDTH - 1.001)
    gz = np.clip((np.asarray(z) - ORIGIN[1]) / STEP, 0, DEPTH - 1.001)
    ix = np.floor(gx).astype(int)
    iz = np.floor(gz).astype(int)
    fx = gx - ix
    fz = gz - iz
    a = grid[iz, ix]
    b = grid[iz, ix + 1]
    c = grid[iz + 1, ix]
    d = grid[iz + 1, ix + 1]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz


def neighbor_position(site, index):
    cx, cz = plot_coordinate(index)
    return site[1] + cx * SPACING, site[2] + cz * SPACING


def foreign(px, pz):
    """Inside a neighbour's district (plus half a plot of border)."""
    for _, sx, sz in NEIGHBOR_SITES:
        if abs(px - sx) <= NEIGHBOR_HALF + SPACING * 0.5 and abs(pz - sz) <= NEIGHBOR_HALF + SPACING * 0.5:
            return True
    return False


def build():
    xs = ORIGIN[0] + np.arange(WIDTH) * STEP
    zs = ORIGIN[1] + np.arange(DEPTH) * STEP
    X, Z = np.meshgrid(xs, zs)
    heights = raw_height(X, Z)
    hill_mask, mountain_mask = masks(X, Z)
    old_blocked = set(json.loads(OLD_BLOCKED.read_text()))
    blocked = {False: [], True: []}
    reasons = {}
    neighbor_blocked = {site[0]: [] for site in NEIGHBOR_SITES}
    centres = {}
    offs = np.linspace(-2.3, 2.3, 5)
    OX, OZ = np.meshgrid(offs, offs)
    lo_x, hi_x = ORIGIN[0] + 4.0, ORIGIN[0] + STEP * (WIDTH - 1) - 4.0
    lo_z, hi_z = ORIGIN[1] + 4.0, ORIGIN[1] + STEP * (DEPTH - 1) - 4.0

    def judge(px, pz):
        if not (lo_x < px < hi_x and lo_z < pz < hi_z):
            return "outside", 0.0
        samples = sample(heights, px + OX, pz + OZ)
        spread = float(samples.max() - samples.min())
        centre = float(sample(heights, px, pz))
        river = abs(px - float(river_center(pz)))
        if river <= 11.5 or centre < WATER + 0.9:
            return "water", centre
        if float(sample(mountain_mask, px, pz)) >= 0.05:
            return "mountain", centre
        if float(sample(hill_mask, px, pz)) >= 0.22 or spread > 1.45:
            return "slope", centre
        return "ok", centre

    for opponent in (False, True):
        for index in range(RIVAL_PLOTS if opponent else MAX_PLOTS):
            px, pz = plot_position(index, opponent)
            verdict, centre = judge(px, pz)
            if not opponent and verdict == "ok" and foreign(px, pz):
                verdict = "foreign"
            if not opponent and verdict == "ok" and any(
                (px - rx) ** 2 + (pz - rz) ** 2 < rr * rr for rx, rz, rr in RESERVED
            ):
                verdict = "reserved"
            if not opponent and index < OLD_PLOTS and index not in old_blocked and verdict != "ok":
                # Old district: a plot that was buildable stays buildable.
                verdict, centre = "ok", float(sample(heights, px, pz))
            if index < SAFE_PLOTS and verdict != "ok":
                raise SystemExit(f"safe plot {index} opponent={opponent} not buildable: {verdict}")
            if verdict != "ok":
                blocked[opponent].append(index)
                if not opponent:
                    reasons.setdefault(verdict, []).append(index)
            else:
                centres[("p" if not opponent else "r", index)] = (px, pz, centre)
                if not opponent and px > float(river_center(pz)):
                    reasons.setdefault("far_bank", []).append(index)
    for site in NEIGHBOR_SITES:
        for index in range(NEIGHBOR_PLOTS):
            px, pz = neighbor_position(site, index)
            verdict, centre = judge(px, pz)
            if verdict != "ok":
                neighbor_blocked[site[0]].append(index)
            else:
                centres[(site[0], index)] = (px, pz, centre)
    # Soft building pads: every buildable cell is eased towards its centre
    # height, so houses stand level while roads between them stay gentle.
    flat = heights.copy()
    reach = int(np.ceil(3.2 / STEP))
    for _, (px, pz, centre) in centres.items():
        ix0 = int(round((px - ORIGIN[0]) / STEP))
        iz0 = int(round((pz - ORIGIN[1]) / STEP))
        for iz in range(iz0 - reach, iz0 + reach + 1):
            for ix in range(ix0 - reach, ix0 + reach + 1):
                if not (0 <= ix < WIDTH and 0 <= iz < DEPTH):
                    continue
                wx = abs(ORIGIN[0] + ix * STEP - px)
                wz = abs(ORIGIN[1] + iz * STEP - pz)
                w = float(smoothstep(3.4, 2.0, max(wx, wz)))
                if w > 0:
                    flat[iz, ix] = flat[iz, ix] * (1 - w * 0.85) + centre * w * 0.85
    return flat, blocked, reasons, neighbor_blocked


def write(heights, blocked, reasons, neighbor_blocked, out: Path):
    out.parent.mkdir(parents=True, exist_ok=True)
    values = ", ".join(f"{v:.2f}".rstrip("0").rstrip(".") if abs(v) > 0.004 else "0" for v in heights.ravel())
    text = (
        '[gd_resource type="Resource" format=3]\n\n[resource]\n'
        f'metadata/origin = Vector2({ORIGIN[0]}, {ORIGIN[1]})\n'
        f'metadata/step = {STEP}\n'
        f'metadata/width = {WIDTH}\n'
        f'metadata/depth = {DEPTH}\n'
        f'metadata/water_level = {WATER}\n'
        f'metadata/generator = "tools/lumo_village_art/make_terrain.py"\n'
        f'metadata/blocked_player = PackedInt32Array({", ".join(str(i) for i in blocked[False])})\n'
        f'metadata/blocked_neighbor = PackedInt32Array({", ".join(str(i) for i in blocked[True])})\n'
        f'metadata/max_plots = {MAX_PLOTS}\n'
        + "".join(
            f'metadata/reason_{key} = PackedInt32Array({", ".join(str(i) for i in reasons.get(key, []))})\n'
            for key in ("water", "mountain", "slope", "foreign", "reserved", "outside", "far_bank")
        )
        + "".join(
            f'metadata/blocked_site_{key} = PackedInt32Array({", ".join(str(i) for i in neighbor_blocked[key])})\n'
            for key in sorted(neighbor_blocked)
        )
        + f'metadata/heights = PackedFloat32Array({values})\n'
    )
    out.write_text(text)
    return hashlib.sha256(text.encode()).hexdigest()


def preview(heights, path):
    from PIL import Image
    gx = np.gradient(heights, axis=1)
    gz = np.gradient(heights, axis=0)
    shade = np.clip(0.6 + (-gx * 0.6 - gz * 0.4) * 0.6, 0, 1)
    col = np.zeros(heights.shape + (3,))
    col[...] = [0.45, 0.65, 0.3]
    col[heights > 25] = [0.55, 0.52, 0.48]
    col[heights > 42] = [0.95, 0.95, 0.97]
    col[heights < WATER] = [0.2, 0.45, 0.65]
    img = (col * shade[..., None] * 255).astype(np.uint8)
    Image.fromarray(img).resize((WIDTH * 2, DEPTH * 2)).save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--preview", default="")
    args = parser.parse_args()
    heights, blocked, reasons, neighbor_blocked = build()
    if args.check:
        text = OUT.read_text()
        fresh = OUT.with_suffix(".check.tres")
        write(heights, blocked, reasons, neighbor_blocked, fresh)
        same = fresh.read_text() == text
        fresh.unlink()
        assert same, "village_heightmap.tres is not reproducible from make_terrain.py"
    else:
        write(heights, blocked, reasons, neighbor_blocked, OUT)
    if args.preview:
        preview(heights, args.preview)
    stats = {
        "min": float(heights.min()), "max": float(heights.max()),
        "blocked_player": len(blocked[False]), "blocked_neighbor": len(blocked[True]),
        "water_cells": int((heights < WATER).sum()), "bytes": OUT.stat().st_size,
        "reasons": {k: len(v) for k, v in reasons.items()},
        "neighbor_blocked": {k: len(v) for k, v in neighbor_blocked.items()},
    }
    print(json.dumps(stats))


if __name__ == "__main__":
    main()
