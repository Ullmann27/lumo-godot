#!/usr/bin/env python3
"""Self-made textures for the Dschungelherz jungle (Lumo Lauf).

Every map is computed here from seeded noise; nothing is downloaded or traced.
All tiling maps are seamless (periodic noise). Normal maps use the OpenGL / glTF
convention (+Y up), as Godot expects.

Written to assets/games/run/jungle/models/textures/:
  bark_*        tree bark with fissures and lichen          (1024)
  leaves_*      leaf atlas, RGBA: broad twig, small twig,
                fern frond, big tropical leaf                (1024, 2x2 cells)
  stone_*       weathered rock with cracks                   (1024)
  sandstone_*   temple stone, layered and pitted             (1024)
  wood_*        wood grain with knots                        (1024)
  moss_*        moss and lichen                              (512)
  ground_*      forest floor: earth, leaf litter, pebbles    (1024)
  iron_*        rusty iron                                   (512)

Run with any Python that has numpy and Pillow, e.g.
  /home/user/tools/bpyenv/bin/python tools/lumo_run_art/jungle_textures.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/games/run/jungle/models/textures"
SEED = 20261118
JPEG_QUALITY = 88


# ------------------------------------------------------------------ noise

def _smooth(t: np.ndarray) -> np.ndarray:
    return t * t * (3.0 - 2.0 * t)


def value_noise(size: tuple[int, int], cells: tuple[int, int], rng: np.random.Generator) -> np.ndarray:
    """Periodic value noise: `cells` lattice points across a `size` (h, w) image."""
    h, w = size
    cy, cx = cells
    grid = rng.random((cy, cx))
    y = np.arange(h) * cy / h
    x = np.arange(w) * cx / w
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    fy = _smooth(y - y0)[:, None]
    fx = _smooth(x - x0)[None, :]
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    y0 %= cy
    x0 %= cx
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y1][:, x0]
    d = grid[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, cells, rng, octaves=5, gain=0.5, lacunarity=2):
    total = np.zeros(size)
    amp = 1.0
    norm = 0.0
    cy, cx = cells
    for _ in range(octaves):
        total += value_noise(size, (cy, cx), rng) * amp
        norm += amp
        amp *= gain
        cy *= lacunarity
        cx *= lacunarity
        if cy > size[0] or cx > size[1]:
            break
    return total / norm


def voronoi(size: int, points: int, rng: np.random.Generator, stretch=(1.0, 1.0)):
    """Periodic Voronoi: distances to nearest and second nearest feature point and the cell id."""
    pts = rng.random((points, 2))
    ys, xs = np.mgrid[0:size, 0:size] / size
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    ident = np.zeros((size, size), dtype=int)
    for index, (py, px) in enumerate(pts):
        dy = np.abs(ys - py)
        dx = np.abs(xs - px)
        dy = np.minimum(dy, 1.0 - dy) * stretch[0]
        dx = np.minimum(dx, 1.0 - dx) * stretch[1]
        dist = np.sqrt(dx * dx + dy * dy)
        closer = dist < f1
        f2 = np.where(closer, f1, np.minimum(f2, dist))
        ident = np.where(closer, index, ident)
        f1 = np.where(closer, dist, f1)
    return f1, f2, ident


def normal_map(height: np.ndarray, strength: float, wrap: bool = True) -> np.ndarray:
    if wrap:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    else:
        dy, dx = np.gradient(height)
    nx = -dx * strength
    ny = dy * strength  # image rows grow downwards; +Y (OpenGL) points up the image
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5
    return rgb


def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) == 2 else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


def colour(hex_value: str) -> np.ndarray:
    hex_value = hex_value.lstrip("#")
    return np.array([int(hex_value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def save_rgb(name: str, rgb: np.ndarray) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image = Image.fromarray(np.clip(rgb * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGB")
    if path.suffix == ".jpg":
        image.save(path, quality=JPEG_QUALITY, optimize=True, subsampling=0)
    else:
        image.save(path, optimize=True)
    return path


def save_rgba(name: str, rgba: np.ndarray) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    Image.fromarray(np.clip(rgba * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
    return path


# ------------------------------------------------------------------ bark

def bark(rng):
    size = 1024
    # Long fissures: noise stretched along the trunk (v), ridged.
    fissure = fbm((size, size), (3, 22), rng, octaves=4)
    ridges = 1.0 - np.abs(fissure - 0.5) * 2.0
    ridges = ridges ** 3.0
    plates = fbm((size, size), (6, 14), rng, octaves=5)
    fine = fbm((size, size), (32, 64), rng, octaves=3)
    height = 0.55 * (1.0 - ridges) + 0.3 * plates + 0.15 * fine
    lichen = fbm((size, size), (8, 8), rng, octaves=4)
    lichen_mask = np.clip((lichen - 0.58) * 6.0, 0, 1) * np.clip((height - 0.35) * 4.0, 0, 1)
    dark = colour("3b2a1e")
    mid = colour("6e5039")
    light = colour("9a7a5c")
    rgb = lerp(dark, mid, np.clip(height * 1.6 - 0.25, 0, 1))
    rgb = lerp(rgb, light, np.clip((height - 0.55) * 3.0, 0, 1) * 0.7)
    rgb = lerp(rgb, colour("8f9a6a"), lichen_mask * 0.75)
    rgb *= (0.85 + 0.3 * fine)[..., None]
    save_rgb("bark_albedo.jpg", rgb)
    save_rgb("bark_normal.jpg", normal_map(height, 9.0))


# ------------------------------------------------------------------ stone, sandstone, moss

def stone(rng):
    size = 1024
    f1, f2, ident = voronoi(size, 18, rng, stretch=(1.0, 0.8))
    edge = f2 - f1
    mask = np.clip((fbm((size, size), (5, 5), rng, 4) - 0.42) * 4.0, 0, 1)
    cracks = 1.0 - np.clip(1.0 - edge * 55.0, 0, 1) * mask
    body = fbm((size, size), (4, 4), rng, octaves=7)
    strata = fbm((size, size), (20, 3), rng, octaves=3)
    grain = fbm((size, size), (96, 96), rng, octaves=2)
    cell_shade = (np.random.default_rng(SEED + 5).random(18))[ident]
    height = 0.55 * body + 0.15 * strata + 0.15 * grain + 0.15 * cracks
    base = lerp(colour("5f625c"), colour("a29d90"), np.clip(body * 1.4 - 0.2, 0, 1))
    base = lerp(base, colour("8c8670"), strata * 0.35)
    lichen = np.clip((fbm((size, size), (7, 7), rng, 5) - 0.56) * 5, 0, 1)
    base = lerp(base, colour("98a070"), lichen * 0.55)
    base *= (0.92 + 0.12 * cell_shade)[..., None]
    base *= (0.82 + 0.25 * grain)[..., None]
    base = lerp(colour("34322e"), base, np.clip(cracks, 0, 1))
    save_rgb("stone_albedo.jpg", base)
    save_rgb("stone_normal.jpg", normal_map(height, 7.0))


def sandstone(rng):
    size = 1024
    layers = fbm((size, size), (24, 3), rng, octaves=4)
    body = fbm((size, size), (5, 5), rng, octaves=6)
    grain = fbm((size, size), (128, 128), rng, octaves=2)
    pits_noise = fbm((size, size), (48, 48), rng, octaves=2)
    pits = np.clip((0.26 - pits_noise) * 6.0, 0, 1)
    height = 0.45 * body + 0.25 * layers + 0.15 * grain - 0.35 * pits
    rgb = lerp(colour("b39a72"), colour("dcc59a"), np.clip(body * 1.2 - 0.1, 0, 1))
    rgb = lerp(rgb, colour("c7a676"), layers * 0.5)
    stain = np.clip((fbm((size, size), (4, 4), rng, 5) - 0.52) * 5.0, 0, 1)
    rgb = lerp(rgb, colour("8b8c6a"), stain * 0.45)
    rgb *= (0.88 + 0.2 * grain)[..., None]
    rgb = lerp(rgb, colour("8a765a"), pits * 0.45)
    save_rgb("sandstone_albedo.jpg", rgb)
    save_rgb("sandstone_normal.jpg", normal_map(height, 6.0))


def moss(rng):
    size = 512
    clumps = fbm((size, size), (8, 8), rng, octaves=5)
    fuzz = fbm((size, size), (128, 128), rng, octaves=2)
    tufts = value_noise((size, size), (256, 256), rng)
    height = 0.5 * clumps + 0.3 * fuzz + 0.2 * tufts
    rgb = lerp(colour("2f5a1f"), colour("6e9a34"), np.clip(height * 1.5 - 0.3, 0, 1))
    rgb = lerp(rgb, colour("a8c255"), np.clip((tufts - 0.8) * 5.0, 0, 1) * 0.6)
    rgb = lerp(rgb, colour("4d6b2a"), np.clip((0.4 - clumps) * 3.0, 0, 1) * 0.5)
    save_rgb("moss_albedo.jpg", rgb)
    save_rgb("moss_normal.jpg", normal_map(height, 5.0))


# ------------------------------------------------------------------ wood and iron

def wood(rng):
    size = 1024
    warp = fbm((size, size), (4, 2), rng, octaves=4)
    ys, xs = np.mgrid[0:size, 0:size] / size
    rings = np.sin((xs * 26.0 + warp * 5.0) * math.pi * 2.0) * 0.5 + 0.5
    fibres = fbm((size, size), (2, 160), rng, octaves=3)
    knots = np.zeros((size, size))
    for _ in range(5):
        ky, kx = rng.random(2)
        dy = np.minimum(np.abs(ys - ky), 1 - np.abs(ys - ky)) * 1.0
        dx = np.minimum(np.abs(xs - kx), 1 - np.abs(xs - kx)) * 3.5
        d = np.sqrt(dx * dx + dy * dy)
        knots = np.maximum(knots, np.clip(1.0 - d * 14.0, 0, 1))
    height = 0.45 * rings + 0.4 * fibres - 0.3 * knots
    rgb = lerp(colour("6a4528"), colour("b07c4a"), np.clip(rings * 0.6 + fibres * 0.6 - 0.1, 0, 1))
    rgb = lerp(rgb, colour("3e2716"), knots * 0.85)
    weather = fbm((size, size), (3, 3), rng, octaves=4)
    rgb = lerp(rgb, colour("8b8070"), np.clip((weather - 0.55) * 3.0, 0, 1) * 0.35)
    save_rgb("wood_albedo.jpg", rgb)
    save_rgb("wood_normal.jpg", normal_map(height, 5.0))


def iron(rng):
    size = 512
    body = fbm((size, size), (6, 6), rng, octaves=6)
    rust = np.clip((fbm((size, size), (8, 8), rng, 5) - 0.45) * 3.0, 0, 1)
    pits = fbm((size, size), (96, 96), rng, octaves=2)
    height = 0.6 * body + 0.4 * pits * rust
    rgb = lerp(colour("4a4c50"), colour("7b7f86"), body)
    rgb = lerp(rgb, colour("8a4a24"), rust * 0.8)
    rgb = lerp(rgb, colour("c07a3c"), np.clip(rust * pits * 2 - 0.6, 0, 1) * 0.6)
    save_rgb("iron_albedo.jpg", rgb)
    save_rgb("iron_normal.jpg", normal_map(height, 4.0))


# ------------------------------------------------------------------ forest floor

def ground(rng):
    size = 1024
    body = fbm((size, size), (4, 4), rng, octaves=7)
    fine = fbm((size, size), (96, 96), rng, octaves=2)
    height = 0.5 * body + 0.2 * fine
    rgb = lerp(colour("4b3524"), colour("7a5a3a"), np.clip(body * 1.3 - 0.15, 0, 1))
    rgb *= (0.85 + 0.25 * fine)[..., None]
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    litter_colours = [colour(c) for c in ("8a5a2a", "a8743a", "6b4a24", "b38b3c", "5d6b2a", "7d4a22", "c09a5a")]
    # Fallen leaves: small rotated ellipses with a midrib, wrapped for tiling.
    for _ in range(900):
        cy, cx = rng.random(2) * size
        length = rng.uniform(10, 26)
        width = length * rng.uniform(0.32, 0.5)
        angle = rng.uniform(0, math.pi)
        r = int(length) + 2
        y0, x0 = int(cy) - r, int(cx) - r
        yy = (np.arange(y0, y0 + 2 * r) % size)
        xx = (np.arange(x0, x0 + 2 * r) % size)
        ly = (np.arange(y0, y0 + 2 * r) - cy)[:, None]
        lx = (np.arange(x0, x0 + 2 * r) - cx)[None, :]
        u = lx * math.cos(angle) + ly * math.sin(angle)
        v = -lx * math.sin(angle) + ly * math.cos(angle)
        t = np.clip(u / length * 0.5 + 0.5, 0, 1)
        half = width * 0.5 * np.maximum(np.sin(t * math.pi), 0.0) ** 0.8
        inside = np.clip((half - np.abs(v)) * 0.8, 0, 1) * (np.abs(u) < length)
        if not inside.any():
            continue
        tone = litter_colours[rng.integers(len(litter_colours))] * rng.uniform(0.75, 1.1)
        rib = np.clip(1.0 - np.abs(v) * 1.2, 0, 1) * 0.25
        patch = rgb[np.ix_(yy, xx)]
        leaf_rgb = tone[None, None, :] * (1.0 + rib[..., None] * 0.6)
        rgb[np.ix_(yy, xx)] = patch * (1 - inside[..., None]) + leaf_rgb * inside[..., None]
        h = height[np.ix_(yy, xx)]
        height[np.ix_(yy, xx)] = np.maximum(h, (0.75 + rib) * inside + h * (1 - inside))
    # Pebbles.
    for _ in range(140):
        cy, cx = rng.random(2) * size
        radius = rng.uniform(3, 8)
        r = int(radius) + 2
        yy = (np.arange(int(cy) - r, int(cy) + r) % size)
        xx = (np.arange(int(cx) - r, int(cx) + r) % size)
        ly = (np.arange(int(cy) - r, int(cy) + r) - cy)[:, None]
        lx = (np.arange(int(cx) - r, int(cx) + r) - cx)[None, :]
        d = np.sqrt(lx * lx + ly * ly) / radius
        dome = np.clip(1.0 - d * d, 0, 1)
        inside = np.clip((1.0 - d) * radius * 0.7, 0, 1)
        tone = colour("8d8a80") * rng.uniform(0.7, 1.15)
        patch = rgb[np.ix_(yy, xx)]
        rgb[np.ix_(yy, xx)] = patch * (1 - inside[..., None]) + (tone * (0.75 + 0.35 * dome[..., None])) * inside[..., None]
        h = height[np.ix_(yy, xx)]
        height[np.ix_(yy, xx)] = np.maximum(h, 0.6 + dome * 0.6)
    save_rgb("ground_albedo.jpg", rgb)
    save_rgb("ground_normal.jpg", normal_map(height, 6.0))


# ------------------------------------------------------------------ leaves

class Canvas:
    """RGBA + height for one atlas cell, with antialiased leaf shapes."""

    def __init__(self, size: int):
        self.size = size
        self.rgb = np.zeros((size, size, 3))
        self.alpha = np.zeros((size, size))
        self.height = np.zeros((size, size))
        self.ys, self.xs = np.mgrid[0:size, 0:size].astype(np.float32)

    def stroke(self, a, b, width, tone, height=0.6):
        """A stem from a to b (pixel coords, x/y)."""
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy + 1e-6
        t = np.clip(((self.xs - ax) * dx + (self.ys - ay) * dy) / length2, 0, 1)
        px = ax + t * dx - self.xs
        py = ay + t * dy - self.ys
        d = np.sqrt(px * px + py * py)
        w = width * (1.0 - 0.5 * t)
        cover = np.clip(w - d + 0.5, 0, 1)
        self._paint(cover, tone, height * (1 - d / (w + 1e-3)).clip(0, 1))

    def leaf(self, base, angle, length, width, tone, rng, tip=0.85, veins=8, slits=0, rib_tone=None, vein_strength=0.18, mottle_amount=0.16):
        """Elliptic, pointed leaf from `base` towards `angle` (radians, 0 = up)."""
        bx, by = base
        ux, uy = math.sin(angle), -math.cos(angle)
        lx = self.xs - bx
        ly = self.ys - by
        u = (lx * ux + ly * uy) / length
        v = (-lx * uy + ly * ux) / (width * 0.5)
        shape = np.maximum(np.sin(np.clip(u, 0, 1) * math.pi), 0.0) ** 0.75 * (1.0 - 0.25 * np.clip(u, 0, 1))
        shape = shape * np.where(u > tip, np.clip((1.0 - u) / (1.0 - tip), 0, 1) ** 0.6, 1.0)
        edge = (shape - np.abs(v)) * width * 0.5
        cover = np.clip(edge + 0.5, 0, 1) * (u > 0) * (u < 1)
        if slits:
            for k in range(slits):
                at = 0.2 + 0.7 * (k + 0.5) / slits
                side = 1 if k % 2 == 0 else -1
                cut = np.abs(u - (at + 0.12 * np.abs(v))) * length < 1.6
                cover = cover * np.where(cut & (np.sign(v) == side) & (np.abs(v) > 0.18), 0.0, 1.0)
        if not cover.any():
            return
        rib = np.clip(1.0 - np.abs(v) * width * 0.5 / 2.2, 0, 1)
        vein_wave = np.abs(np.sin((u * veins - np.abs(v) * 1.6) * math.pi))
        vein = np.clip(1.0 - vein_wave * 6.0, 0, 1) * (np.abs(v) < shape * 0.92)
        # Colour: lighter towards the tip and the rim of light, darker at the base.
        shade = 0.82 + 0.25 * np.clip(u, 0, 1) - 0.12 * np.abs(v)
        rgb = tone[None, None, :] * shade[..., None]
        rib_colour = rib_tone if rib_tone is not None else tone * 1.35 + 0.05
        rgb = rgb * (1 - rib[..., None] * 0.8) + rib_colour[None, None, :] * rib[..., None] * 0.8
        rgb = rgb * (1 - vein[..., None] * vein_strength) + (tone * 1.3 + 0.04)[None, None, :] * vein[..., None] * vein_strength
        mottle = value_noise((self.size, self.size), (24, 24), rng)
        rgb *= (1.0 - mottle_amount * 0.5 + mottle_amount * mottle)[..., None]
        # A darker rim and a sheen along the middle: leaves read as curved, not cut paper.
        rgb *= (0.86 + 0.14 * np.clip(shape - np.abs(v), 0, 1) ** 0.3)[..., None]
        bulge = np.clip(shape - np.abs(v), 0, 1) ** 0.5
        height = 0.5 + 0.35 * bulge - 0.25 * vein - 0.3 * rib
        self._paint(cover, rgb, height)

    def _paint(self, cover, rgb, height):
        cover = cover[..., None] if cover.ndim == 2 else cover
        self.rgb = self.rgb * (1 - cover) + np.broadcast_to(rgb, self.rgb.shape) * cover
        c = cover[..., 0]
        self.height = self.height * (1 - c) + np.broadcast_to(height, c.shape) * c
        self.alpha = np.maximum(self.alpha, c)


def _dilate(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Spreads leaf colours into the transparent area so mipmaps get no dark fringes."""
    weight = alpha.copy()
    acc = rgb * alpha[..., None]
    out = rgb.copy()
    filled = alpha > 0.5
    for step in range(10):
        for axis in (0, 1):
            for shift in (1, -1):
                acc = acc + np.roll(acc, shift * (2 ** min(step, 6)), axis=axis) * 0.5
                weight = weight + np.roll(weight, shift * (2 ** min(step, 6)), axis=axis) * 0.5
        mean = acc / np.maximum(weight[..., None], 1e-6)
        out = np.where(filled[..., None], out, np.where(weight[..., None] > 1e-6, mean, out))
        filled = filled | (weight > 1e-6)
    return np.where(alpha[..., None] > 0.5, rgb, out)


def leaves(rng):
    cell = 512
    greens = [colour(c) for c in ("2f7d32", "3f8f2f", "4d9a35", "2c6b2e", "5a9e3a", "6aa842", "3d7a3a")]

    def pick(shift=0.0):
        tone = greens[rng.integers(len(greens))] * rng.uniform(0.82, 1.12)
        tone = tone + np.array([shift, shift * 0.6, -shift * 0.4])
        return np.clip(tone, 0, 1)

    cells = []
    # 0: broadleaf twig, leaves pointing out from a stem that runs bottom to top.
    c = Canvas(cell)
    stem_bottom = (cell * 0.5, cell * 0.98)
    stem_top = (cell * 0.52, cell * 0.16)
    for k in range(9):
        t = 0.12 + 0.8 * k / 8
        px = stem_bottom[0] + (stem_top[0] - stem_bottom[0]) * t
        py = stem_bottom[1] + (stem_top[1] - stem_bottom[1]) * t
        side = -1 if k % 2 == 0 else 1
        angle = side * rng.uniform(0.7, 1.15) * (1.0 - 0.45 * t)
        size = cell * rng.uniform(0.36, 0.44) * (1.05 - 0.3 * t)
        c.leaf((px, py), angle, size, size * rng.uniform(0.38, 0.46), pick(rng.uniform(-0.02, 0.06)), rng, veins=9)
    c.stroke(stem_bottom, stem_top, 4.0, colour("5b4a2a"))
    c.leaf(stem_top, 0.05, cell * 0.2, cell * 0.08, pick(0.05), rng)
    cells.append(c)
    # 1: small-leaved twig spray (many small leaves on forked twigs).
    c = Canvas(cell)
    twigs = [((0.5, 0.98), (0.5, 0.3)), ((0.5, 0.7), (0.2, 0.15)), ((0.5, 0.6), (0.82, 0.12)), ((0.5, 0.82), (0.12, 0.55)),
             ((0.5, 0.78), (0.88, 0.5))]
    for (ax, ay), (bx, by) in twigs:
        a = (ax * cell, ay * cell)
        b = (bx * cell, by * cell)
        for k in range(9):
            t = 0.15 + 0.85 * k / 8
            px = a[0] + (b[0] - a[0]) * t
            py = a[1] + (b[1] - a[1]) * t
            base_angle = math.atan2(b[0] - a[0], -(b[1] - a[1]))
            for side in (-1, 1):
                angle = base_angle + side * rng.uniform(0.5, 1.0)
                size = cell * rng.uniform(0.07, 0.11)
                c.leaf((px, py), angle, size, size * 0.5, pick(rng.uniform(-0.03, 0.08)), rng, veins=4)
        c.leaf(b, math.atan2(b[0] - a[0], -(b[1] - a[1])), cell * 0.1, cell * 0.05, pick(0.06), rng, veins=4)
        c.stroke(a, b, 2.2, colour("5b4a2a"))
    cells.append(c)
    # 2: fern frond (pinnate), the rachis from bottom centre to the top.
    c = Canvas(cell)
    base = (cell * 0.5, cell * 0.99)
    top = (cell * 0.5, cell * 0.02)
    pinnae = 17
    for k in range(pinnae):
        t = 0.06 + 0.9 * k / (pinnae - 1)
        px = base[0]
        py = base[1] + (top[1] - base[1]) * t
        length = cell * 0.4 * (1.0 - t) ** 0.6 * (0.6 + 0.4 * min(1.0, t * 5.0)) + 8
        for side in (-1, 1):
            tone = pick(0.03) * (0.92 + 0.15 * t)
            c.leaf((px + side * 2, py + side * 6), side * (1.45 - 0.45 * t), length, max(7.0, length * 0.2), tone, rng, veins=7)
    c.stroke(base, top, 3.0, colour("6a7a2a"))
    cells.append(c)
    # 3: one big tropical leaf (banana / elephant ear) filling the cell, with tears.
    c = Canvas(cell)
    c.leaf((cell * 0.5, cell * 0.99), 0.0, cell * 0.97, cell * 0.66, colour("3f8f35"), rng, tip=0.9, veins=14, slits=7,
           rib_tone=colour("b9d27a"), vein_strength=0.4, mottle_amount=0.08)
    cells.append(c)
    size = cell * 2
    rgba = np.zeros((size, size, 4))
    height = np.zeros((size, size))
    for index, c in enumerate(cells):
        oy = (index // 2) * cell
        ox = (index % 2) * cell
        filled = _dilate(c.rgb, c.alpha)
        rgba[oy:oy + cell, ox:ox + cell, :3] = filled
        rgba[oy:oy + cell, ox:ox + cell, 3] = c.alpha
        height[oy:oy + cell, ox:ox + cell] = c.height
    save_rgba("leaves_albedo.png", rgba)
    save_rgb("leaves_normal.jpg", normal_map(height, 3.0, wrap=False))


def build() -> list[Path]:
    rng = np.random.default_rng(SEED)
    for maker in (bark, leaves, stone, sandstone, moss, wood, iron, ground):
        maker(np.random.default_rng(rng.integers(1 << 31)))
        print(f"[jungle_textures] {maker.__name__} done", flush=True)
    return sorted(OUT.glob("*.*"))


if __name__ == "__main__":
    for path in build():
        if path.suffix != ".import":
            print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")
    sys.exit(0)
