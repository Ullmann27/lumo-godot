#!/usr/bin/env python3
"""Generate the LUMO village texture set: terrain layers and the building atlas.

Eigenbau: every pixel is computed here from seeded noise; no photos, scans or
downloaded material. Output (PNG, max 1024 px, stored once and shared by all
village models): assets/creative/village3d/textures/.

Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/make_textures.py [--check]
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/village3d/textures"
TILE = 256
ATLAS_GRID = 4
TILES = [
    "plaster", "planks", "beam", "roof_clay",
    "roof_slate", "thatch", "stone_wall", "cobble",
    "window", "door", "cloth", "field",
    "metal", "bark", "leaves", "plain",
]


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def periodic_noise(size: int, scale: float, seed: int, aspect=(1.0, 1.0)) -> np.ndarray:
    """Tileable band-limited noise (FFT filtered white noise), normalised 0..1."""
    white = rng(seed).standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * aspect[1]
    fx = np.fft.fftfreq(size)[None, :] * aspect[0]
    radius = np.sqrt(fx * fx + fy * fy) * size
    filt = np.exp(-(radius / max(scale, 0.5)) ** 2)
    filt[0, 0] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def fbm(size: int, seed: int, base: float = 4.0, octaves: int = 5, aspect=(1.0, 1.0)) -> np.ndarray:
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for octave in range(octaves):
        total += periodic_noise(size, base * 2 ** octave, seed + octave * 17, aspect) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def voronoi(size: int, count: int, seed: int):
    """Wrapped Voronoi: distance to nearest and second nearest site, site id."""
    pts = rng(seed).random((count, 2)) * size
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    d1 = np.full((size, size), 1e9)
    d2 = np.full((size, size), 1e9)
    ident = np.zeros((size, size), dtype=np.int32)
    for index, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, size - dx)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        ident = np.where(closer, index, ident)
        d1 = np.where(closer, d, d1)
    return d1, d2, ident


def hexcol(value: str) -> np.ndarray:
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    return a * (1.0 - t[..., None]) + b * t[..., None]


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    n = np.stack([-dx * strength, dy * strength, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def to_img(rgb: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    rgb = np.clip(rgb, 0.0, 1.0)
    if alpha is None:
        return Image.fromarray((rgb * 255.0 + 0.5).astype(np.uint8), "RGB")
    rgba = np.concatenate([rgb, np.clip(alpha, 0, 1)[..., None]], axis=-1)
    return Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")


def strokes(size, count, seed, length, width, angle_spread, base_angle=-np.pi / 2):
    """Short wrapped strokes (grass blades, straw) as a height field."""
    r = rng(seed)
    field = np.zeros((size, size))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    for _ in range(count):
        cx, cy = r.random(2) * size
        ang = base_angle + r.normal(0, angle_spread)
        ln = length * (0.6 + r.random() * 0.8)
        ex, ey = np.cos(ang), np.sin(ang)
        x0 = int(cx - ln - 2)
        y0 = int(cy - ln - 2)
        w = int(ln * 2 + 4)
        ys = (np.arange(y0, y0 + w)) % size
        xs = (np.arange(x0, x0 + w)) % size
        lx = np.arange(x0, x0 + w)[None, :] - cx
        ly = np.arange(y0, y0 + w)[:, None] - cy
        t = np.clip(lx * ex + ly * ey, 0, ln)
        px = lx - t * ex
        py = ly - t * ey
        dist = np.sqrt(px * px + py * py)
        taper = width * (1.0 - t / ln * 0.8)
        blade = np.clip(1.0 - dist / np.maximum(taper, 0.3), 0, 1) * (0.55 + 0.45 * t / ln)
        sub = field[np.ix_(ys, xs)]
        field[np.ix_(ys, xs)] = np.maximum(sub, blade * (0.5 + r.random() * 0.5))
    return field


# --------------------------------------------------------------------- terrain

def terrain_grass(size=512):
    macro = fbm(size, 11, 3.0, 4)
    blades = strokes(size, 5200, 12, 9.0, 1.3, 0.45)
    blades2 = strokes(size, 2400, 13, 6.0, 1.0, 0.7)
    h = np.maximum(blades, blades2 * 0.8)
    deep = hexcol("3f6f2c")
    mid = hexcol("6d9a3e")
    light = hexcol("a6c25a")
    dry = hexcol("b9b061")
    col = mix(deep, mid, np.clip(macro * 1.4 - 0.1, 0, 1))
    col = mix(col, dry, np.clip((fbm(size, 14, 2.0, 3) - 0.62) * 3.0, 0, 1) * 0.55)
    col = mix(col, light, h * 0.75)
    col *= (0.82 + 0.18 * h)[..., None]
    # Sparse clover and tiny flowers.
    r = rng(15)
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(70):
        cx, cy = r.integers(0, size, 2)
        petal = hexcol(["fff5e0", "f7d34a", "e9a3d4", "ffffff"][r.integers(0, 4)])
        dx = np.minimum(np.abs(xx - cx), size - np.abs(xx - cx))
        dy = np.minimum(np.abs(yy - cy), size - np.abs(yy - cy))
        m = np.clip(2.2 - np.sqrt(dx * dx + dy * dy), 0, 1)
        col = mix(col, petal, m * 0.9)
        h = np.maximum(h, m * 0.9)
    return to_img(col), to_img(normal_from_height(h, 2.4))


def terrain_dirt(size=512):
    base = fbm(size, 21, 6.0, 5)
    d1, d2, ident = voronoi(size, 260, 22)
    pebble = np.clip(1.0 - d1 / 5.5, 0, 1) ** 0.6
    pebble *= (rng(23).random(260)[ident] > 0.35)
    h = base * 0.6 + pebble * 0.8
    col = mix(hexcol("6e4b2e"), hexcol("a27a50"), base)
    tones = rng(24).random((260, 3)) * 0.18 - 0.09
    peb_col = np.clip(hexcol("a69c8c")[None, None, :] + tones[ident], 0, 1)
    col = mix(col, peb_col, pebble * 0.85)
    col *= (0.78 + 0.22 * h)[..., None]
    return to_img(col), to_img(normal_from_height(h, 3.0))


def terrain_rock(size=512):
    warp = fbm(size, 31, 3.0, 4)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    strata = np.sin((yy / size * 9.0 + warp * 2.4) * 2 * np.pi) * 0.5 + 0.5
    d1, d2, ident = voronoi(size, 18, 32)
    cracks = 0.55 + 0.45 * np.clip((d2 - d1) / 6.0, 0, 1) ** 0.35
    grain = fbm(size, 33, 18.0, 4)
    strata = strata ** 3
    h = cracks * 0.35 + strata * 0.55 + grain * 0.4
    col = mix(hexcol("6b6660"), hexcol("a8a196"), np.clip(strata * 0.6 + grain * 0.5, 0, 1))
    col = mix(col, hexcol("8a7a62"), np.clip(fbm(size, 34, 2.5, 3) - 0.45, 0, 1) * 1.2)
    tones = rng(35).random(18) * 0.12 - 0.06
    col = col + tones[ident][..., None]
    col *= (0.45 + 0.55 * cracks * (0.75 + 0.25 * (1 - strata)))[..., None]
    # Lichen speckles.
    lichen = np.clip((fbm(size, 36, 24.0, 3) - 0.68) * 5.0, 0, 1)
    col = mix(col, hexcol("9aa36a"), lichen * 0.6)
    return to_img(col), to_img(normal_from_height(h, 4.0))


def terrain_sand(size=512):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    warp = fbm(size, 41, 3.0, 3)
    ripples = np.sin((xx / size * 14.0 + yy / size * 3.0 + warp * 3.0) * 2 * np.pi) * 0.5 + 0.5
    grain = rng(42).random((size, size))
    h = ripples * 0.5 + grain * 0.25 + fbm(size, 43, 5.0, 3) * 0.4
    col = mix(hexcol("c9ad7d"), hexcol("ead6a6"), np.clip(h, 0, 1))
    col += ((grain - 0.5) * 0.08)[..., None]
    return to_img(col), to_img(normal_from_height(h, 1.6))


# ---------------------------------------------------------------- atlas tiles

def tile_plaster(s):
    n = fbm(s, 101, 6.0, 5)
    stain = np.clip(fbm(s, 102, 2.0, 3) - 0.55, 0, 1) * 1.5
    col = mix(hexcol("f2ead8"), hexcol("d8ccb2"), n * 0.7 + stain * 0.5)
    h = n * 0.8
    return col, h, np.ones((s, s))


def tile_planks(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    rows = 6
    row = (yy / s * rows).astype(int)
    v = (yy / s * rows) % 1.0
    offset = rng(111).random(rows + 1)[row] * s
    seam_x = ((xx + offset) % (s / 1.5))
    grain = periodic_noise(s, 40.0, 112, aspect=(0.08, 1.0))
    grain2 = fbm(s, 113, 8.0, 4)
    seam = np.clip(np.minimum(v, 1 - v) * 40, 0, 1) * np.clip(np.minimum(seam_x, s / 1.5 - seam_x) * 0.8, 0, 1)
    tone = rng(114).random(rows + 1)[row] * 0.25
    col = mix(hexcol("8a5a33"), hexcol("c48e57"), np.clip(grain * 0.7 + tone + grain2 * 0.3, 0, 1))
    col *= (0.45 + 0.55 * seam)[..., None]
    h = seam * 0.8 + grain * 0.2
    return col, h, np.ones((s, s))


def tile_beam(s):
    grain = periodic_noise(s, 50.0, 121, aspect=(0.05, 1.0))
    knots = np.clip(1 - voronoi(s, 5, 122)[0] / 9, 0, 1)
    col = mix(hexcol("4a2e1b"), hexcol("7a4c2c"), np.clip(grain + fbm(s, 123, 6.0, 3) * 0.3, 0, 1))
    col = mix(col, hexcol("2e1b10"), knots * 0.8)
    return col, grain * 0.6 + knots * 0.3, np.ones((s, s))


def tile_roof_clay(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    rows = 8
    cols = 8
    rv = (yy / s * rows) % 1.0
    row = (yy / s * rows).astype(int)
    shift = (row % 2) * 0.5
    cu = ((xx / s * cols) + shift) % 1.0
    # Rounded tile profile across, overlapping lip at the bottom of each row.
    across = np.sin(cu * np.pi)
    lip = np.clip((1.0 - rv) * 6.0, 0, 1)
    h = across * 0.7 * lip + (1 - lip) * 0.2 + rv * 0.25
    tile_id = (row * cols + ((xx / s * cols) + shift).astype(int)) % 997
    tone = rng(131).random(997)[tile_id]
    col = mix(hexcol("9c4a2c"), hexcol("d27a4c"), np.clip(tone * 0.7 + across * 0.3, 0, 1))
    col *= (0.55 + 0.45 * lip * (0.6 + 0.4 * across))[..., None]
    col = mix(col, hexcol("6e7a4a"), np.clip(fbm(s, 132, 3.0, 3) - 0.66, 0, 1) * 2.0)
    return col, h, np.ones((s, s))


def tile_roof_slate(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    rows = 9
    row = (yy / s * rows).astype(int)
    rv = (yy / s * rows) % 1.0
    shift = rng(141).random(rows + 1)[row]
    cu = (xx / s * 7 + shift * 3) % 1.0
    ident = (row * 7 + (xx / s * 7 + shift * 3).astype(int)) % 997
    edge = np.clip(np.minimum(cu, 1 - cu) * 24, 0, 1) * np.clip((1 - rv) * 10, 0, 1)
    tone = rng(142).random(997)[ident]
    col = mix(hexcol("3e4f63"), hexcol("6f8096"), np.clip(tone * 0.8 + fbm(s, 143, 8, 3) * 0.3, 0, 1))
    col *= (0.5 + 0.5 * edge)[..., None]
    return col, edge * 0.6 + rv * 0.3, np.ones((s, s))


def tile_thatch(s):
    h = strokes(s, 3800, 151, 26.0, 1.4, 0.18, base_angle=np.pi / 2)
    bands = (np.mgrid[0:s, 0:s][0] / s * 5.0) % 1.0
    h = np.maximum(h, 0.15) * (0.7 + 0.3 * np.clip(bands * 3, 0, 1))
    col = mix(hexcol("7a5f2c"), hexcol("d9b867"), h)
    return col, h, np.ones((s, s))


def tile_stone_wall(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    rows = 6
    row = (yy / s * rows).astype(int)
    rv = (yy / s * rows) % 1.0
    shifts = rng(161).random(rows + 1)
    widths = 3 + (rng(162).random(rows + 1) * 2).astype(int)
    cu = (xx / s * widths[row] + shifts[row] * 2) % 1.0
    ident = (row * 11 + (xx / s * widths[row] + shifts[row] * 2).astype(int)) % 997
    mortar = np.clip(np.minimum(rv, 1 - rv) * 18, 0, 1) * np.clip(np.minimum(cu, 1 - cu) * 16, 0, 1)
    bump = fbm(s, 163, 10, 4)
    tone = rng(164).random(997) * 0.22
    warm = rng(165).random(997) * 0.05
    base = hexcol("8f8678")[None, None, :] + (tone[ident] - 0.11)[..., None]
    base[..., 0] += warm[ident]
    col = mix(hexcol("cfc4ad"), base, mortar)
    col *= (0.75 + 0.35 * bump)[..., None]
    return col, mortar * 0.8 + bump * 0.3, np.ones((s, s))


def tile_cobble(s):
    d1, d2, ident = voronoi(s, 70, 171)
    stone = np.clip((d2 - d1) / 7.0, 0, 1) ** 0.5
    dome = np.clip(1 - d1 / 22.0, 0, 1)
    tone = rng(172).random(70) * 0.22
    base = hexcol("8d8a80")[None, None, :] + (tone[ident] - 0.1)[..., None]
    col = mix(hexcol("6a5d48"), base, stone)
    col *= (0.7 + 0.3 * dome)[..., None]
    return col, stone * 0.6 + dome * 0.4, np.ones((s, s))


def tile_window(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64) / s
    frame = np.zeros((s, s))
    border = 0.12
    bar = 0.045
    outer = (xx < border) | (xx > 1 - border) | (yy < border) | (yy > 1 - border)
    mull = (np.abs(xx - 0.5) < bar) | (np.abs(yy - 0.5) < bar)
    frame = (outer | mull).astype(np.float64)
    glass_grad = 0.35 + 0.65 * (1 - yy)
    glass = mix(hexcol("23384f"), hexcol("6f9fbf"), np.clip(glass_grad * 0.6 + (xx - yy) * 0.25, 0, 1))
    # Soft diagonal sky reflection.
    streak = np.clip(1 - np.abs((xx + yy) % 0.5 - 0.25) * 18, 0, 1) * 0.25
    glass = glass + streak[..., None]
    wood = mix(hexcol("f3ead6"), hexcol("d7c7a6"), fbm(s, 181, 8, 3))
    col = mix(glass, wood, frame)
    glow = 1.0 - frame
    return col, frame * 0.9, 1.0 - glow * 0.95


def tile_door(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    boards = (xx / s * 5) % 1.0
    seam = np.clip(np.minimum(boards, 1 - boards) * 30, 0, 1)
    grain = periodic_noise(s, 50.0, 191, aspect=(1.0, 0.06))
    col = mix(hexcol("5a3420"), hexcol("8e5733"), grain)
    col *= (0.5 + 0.5 * seam)[..., None]
    band = (np.abs((yy / s) % 0.5 - 0.22) < 0.035)
    col = np.where(band[..., None], hexcol("2f2f33")[None, None, :] * (0.8 + 0.3 * fbm(s, 192, 9, 2))[..., None], col)
    stud = band & (np.abs(boards - 0.5) < 0.12)
    col = np.where(stud[..., None], hexcol("8b8b90")[None, None, :], col)
    h = seam * 0.6 + band * 0.4 + stud * 0.3
    return col, h, np.ones((s, s))


def tile_cloth(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    weave = (np.sin(xx * np.pi / 2) * np.sin(yy * np.pi / 2)) * 0.5 + 0.5
    stripes = ((xx / s * 6) % 1.0) < 0.5
    col = np.where(stripes[..., None], hexcol("f4efe3")[None, None, :], hexcol("d9d0bc")[None, None, :])
    col = col * (0.88 + 0.12 * weave)[..., None]
    folds = fbm(s, 201, 2.0, 3)
    col *= (0.85 + 0.2 * folds)[..., None]
    return col, weave * 0.2 + folds * 0.5, np.ones((s, s))


def tile_field(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    furrow = np.sin(xx / s * 8 * 2 * np.pi) * 0.5 + 0.5
    clods = fbm(s, 211, 16, 4)
    col = mix(hexcol("4e3320"), hexcol("8a6040"), np.clip(furrow * 0.6 + clods * 0.5, 0, 1))
    sprout = (furrow > 0.86) & (rng(212).random((s, s)) > 0.55)
    col = np.where(sprout[..., None], hexcol("7fae46")[None, None, :], col)
    return col, furrow * 0.7 + clods * 0.3, np.ones((s, s))


def tile_metal(s):
    n = fbm(s, 221, 10, 4)
    rust = np.clip(fbm(s, 222, 3, 3) - 0.6, 0, 1) * 2.0
    col = mix(hexcol("3b3f46"), hexcol("6d737c"), n)
    col = mix(col, hexcol("8a4f2a"), rust * 0.6)
    return col, n * 0.4, np.ones((s, s))


def tile_bark(s):
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    warp = fbm(s, 231, 3, 3)
    ridges = np.abs(np.sin((xx / s * 9 + warp * 1.5) * np.pi)) ** 0.6
    breaks = periodic_noise(s, 30.0, 232, aspect=(1.0, 0.15))
    h = ridges * 0.7 + breaks * 0.3
    col = mix(hexcol("3e2b1e"), hexcol("7a5d44"), h)
    return col, h, np.ones((s, s))


def tile_leaves(s):
    d1, d2, ident = voronoi(s, 180, 241)
    leaf = np.clip(1 - d1 / 11.0, 0, 1)
    vein = np.clip((d2 - d1) / 4.0, 0, 1)
    tone = rng(242).random(180) * 0.35
    col = mix(hexcol("2f5a24"), hexcol("7fb04a"), np.clip(leaf * 0.6 + tone[ident], 0, 1))
    col *= (0.55 + 0.45 * vein)[..., None]
    return col, leaf * 0.6 + vein * 0.4, np.ones((s, s))


def tile_plain(s):
    n = fbm(s, 251, 8, 3)
    col = mix(hexcol("e6e6e6"), hexcol("ffffff"), n)
    return col, n * 0.2, np.ones((s, s))


TILE_FUNCS = {
    "plaster": tile_plaster, "planks": tile_planks, "beam": tile_beam, "roof_clay": tile_roof_clay,
    "roof_slate": tile_roof_slate, "thatch": tile_thatch, "stone_wall": tile_stone_wall, "cobble": tile_cobble,
    "window": tile_window, "door": tile_door, "cloth": tile_cloth, "field": tile_field,
    "metal": tile_metal, "bark": tile_bark, "leaves": tile_leaves, "plain": tile_plain,
}
STRENGTH = {"window": 3.0, "door": 3.0, "roof_clay": 5.0, "stone_wall": 5.0, "cobble": 4.0}


def atlas():
    size = TILE * ATLAS_GRID
    albedo = np.zeros((size, size, 3))
    alpha = np.ones((size, size))
    normal = np.zeros((size, size, 3))
    for index, name in enumerate(TILES):
        col, h, a = TILE_FUNCS[name](TILE)
        y = (index // ATLAS_GRID) * TILE
        x = (index % ATLAS_GRID) * TILE
        albedo[y:y + TILE, x:x + TILE] = np.clip(col, 0, 1)
        alpha[y:y + TILE, x:x + TILE] = a
        normal[y:y + TILE, x:x + TILE] = normal_from_height(h, STRENGTH.get(name, 3.0))
    return to_img(albedo, alpha), to_img(normal)


def leaf_cards(size=512):
    """Alpha-cut leaf cluster card for tree canopies and bushes."""
    r = rng(301)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    alpha = np.zeros((size, size))
    col = np.zeros((size, size, 3))
    cx0, cy0 = size / 2, size / 2
    for _ in range(420):
        ang = r.random() * 2 * np.pi
        rad = np.sqrt(r.random()) * size * 0.42
        cx = cx0 + np.cos(ang) * rad
        cy = cy0 + np.sin(ang) * rad
        rot = r.random() * np.pi
        ln = 13 + r.random() * 10
        wd = ln * 0.45
        lx = (xx - cx) * np.cos(rot) + (yy - cy) * np.sin(rot)
        ly = -(xx - cx) * np.sin(rot) + (yy - cy) * np.cos(rot)
        inside = (lx / ln) ** 2 + (ly / wd) ** 2
        m = inside < 1.0
        shade = 0.55 + 0.45 * (1 - inside) + (r.random() - 0.5) * 0.2
        base = mix(hexcol("2d5a20"), hexcol("8cc256"), np.full((size, size), r.random()))
        vein = np.abs(ly) < 0.9
        leafc = base * np.clip(shade, 0, 1.2)[..., None]
        leafc = np.where(vein[..., None], leafc * 0.8, leafc)
        col = np.where(m[..., None], leafc, col)
        alpha = np.where(m, 1.0, alpha)
    # Dilate colour under transparent texels to avoid dark fringes in mips.
    filled = col.copy()
    for _ in range(6):
        nb = (np.roll(filled, 1, 0) + np.roll(filled, -1, 0) + np.roll(filled, 1, 1) + np.roll(filled, -1, 1)) / 4
        filled = np.where((alpha > 0.5)[..., None], col, nb)
    return to_img(filled, alpha)


def water_normal(size=512):
    h = fbm(size, 401, 5.0, 5)
    h2 = periodic_noise(size, 14.0, 402, aspect=(1.0, 0.4))
    return to_img(normal_from_height(h * 0.7 + h2 * 0.3, 6.0))


def cloud_noise(size=256):
    """Tileable soft noise: R = cloud cover, G = macro ground variation."""
    clouds = fbm(size, 501, 3.0, 5)
    macro = fbm(size, 502, 2.0, 4)
    detail = fbm(size, 503, 9.0, 3)
    rgb = np.stack([clouds, macro, detail], axis=-1)
    return to_img(rgb)


def build(out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    files = {}
    jobs = {
        "terrain_grass": terrain_grass, "terrain_dirt": terrain_dirt,
        "terrain_rock": terrain_rock, "terrain_sand": terrain_sand,
    }
    for name, func in jobs.items():
        alb, nor = func()
        alb.save(out / f"{name}_albedo.png", optimize=True)
        nor.save(out / f"{name}_normal.png", optimize=True)
        files[f"{name}_albedo.png"] = alb.size
        files[f"{name}_normal.png"] = nor.size
    alb, nor = atlas()
    alb.save(out / "village_atlas_albedo.png", optimize=True)
    nor.save(out / "village_atlas_normal.png", optimize=True)
    files["village_atlas_albedo.png"] = alb.size
    files["village_atlas_normal.png"] = nor.size
    leaf = leaf_cards()
    leaf.save(out / "leaf_cards.png", optimize=True)
    files["leaf_cards.png"] = leaf.size
    cl = cloud_noise()
    cl.save(out / "cloud_noise.png", optimize=True)
    files["cloud_noise.png"] = cl.size
    wat = water_normal()
    wat.save(out / "water_normal.png", optimize=True)
    files["water_normal.png"] = wat.size
    manifest = {"tiles": TILES, "grid": ATLAS_GRID, "files": {}}
    for name in sorted(files):
        data = (out / name).read_bytes()
        manifest["files"][name] = {
            "size": list(files[name]), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()
        }
    (out / "textures.json").write_text(json.dumps(manifest, indent=1) + "\n")
    return manifest


def check(out: Path) -> None:
    manifest = json.loads((out / "textures.json").read_text())
    for name, info in manifest["files"].items():
        path = out / name
        assert path.exists(), name
        img = Image.open(path)
        assert max(img.size) <= 1024, name
        assert path.stat().st_size < 2 * 1024 * 1024, name
    print("textures ok:", len(manifest["files"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        build(OUT)
    check(OUT)
