#!/usr/bin/env python3
"""Generate the Bauwelt voxel texture set (albedo + normal), fully procedural.

No external images are used, so the output is original work of this repo
(same licence as the project). One texture = one block face (1 grid cell).
Run: python3 tools/art/generate_bauwelt_voxel_textures.py
Output: assets/creative/bauwelt_voxel/<kind>_albedo.png, <kind>_normal.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

N = 256
OUT = Path(__file__).resolve().parents[2] / "assets/creative/bauwelt_voxel"
RNG = np.random.default_rng(20261103)


def value_noise(cells: int, octaves: int = 4) -> np.ndarray:
    """Tileable fractal value noise in [0, 1]."""
    total = np.zeros((N, N))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2**o)
        grid = RNG.random((c, c))
        y = np.linspace(0, c, N, endpoint=False)
        i0 = np.floor(y).astype(int)
        f = y - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % c
        a = grid[np.ix_(i0, i0)] * (1 - f)[None, :] + grid[np.ix_(i0, i1)] * f[None, :]
        b = grid[np.ix_(i1, i0)] * (1 - f)[None, :] + grid[np.ix_(i1, i1)] * f[None, :]
        total += amp * (a * (1 - f)[:, None] + b * f[:, None])
        norm += amp
        amp *= 0.5
    return total / norm


def bricks(rows: int, cols: int, mortar: float, stagger: bool = True):
    """Height map (1 brick, 0 mortar, soft bevel) and per-brick random value."""
    yy, xx = np.mgrid[0:N, 0:N] / N
    row = np.floor(yy * rows).astype(int)
    shift = np.where(row % 2 == 1, 0.5 / cols, 0.0) if stagger else 0.0
    u = (xx + shift) % 1.0
    col = np.floor(u * cols).astype(int)
    fy = yy * rows - row
    fx = u * cols - col
    edge = np.minimum(np.minimum(fx, 1 - fx) / cols * rows, np.minimum(fy, 1 - fy))
    height = np.clip((edge - mortar) / 0.06, 0, 1)
    ids = (row * 131 + (col % cols) * 17) % 997
    rand = (np.sin(ids * 12.9898) * 43758.5453) % 1.0
    return height, rand


def normal_from_height(h: np.ndarray, strength: float) -> Image.Image:
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def save(kind: str, rgb: np.ndarray, height: np.ndarray, strength: float = 6.0) -> None:
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").save(
        OUT / f"{kind}_albedo.png", optimize=True
    )
    normal_from_height(height, strength).save(OUT / f"{kind}_normal.png", optimize=True)


def tint(gray: np.ndarray, color) -> np.ndarray:
    return gray[..., None] * np.array(color)[None, None, :]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fine = value_noise(16, 4)
    coarse = value_noise(4, 3)
    # Stone: grey castle bricks, 4 rows x 2 (tinted by the part colour).
    h, r = bricks(4, 2, 0.035)
    g = 0.72 + 0.16 * r + 0.14 * (fine - 0.5) + 0.06 * (coarse - 0.5)
    g = g * (0.55 + 0.45 * h)
    save("stone", tint(g, (1.0, 1.0, 1.0)), h * 0.8 + fine * 0.2)
    # Sandstone: large warm blocks, 2 rows x 1.
    h, r = bricks(2, 1, 0.03)
    g = 0.80 + 0.10 * r + 0.10 * (fine - 0.5) + 0.06 * (coarse - 0.5)
    g = g * (0.62 + 0.38 * h)
    save("sand", tint(g, (1.0, 0.98, 0.95)), h * 0.75 + fine * 0.25)
    # Wood planks: 4 horizontal planks with grain.
    yy, xx = np.mgrid[0:N, 0:N] / N
    plank = np.floor(yy * 4)
    fy = yy * 4 - plank
    seam = np.clip(np.minimum(fy, 1 - fy) / 0.05, 0, 1)
    grain = 0.5 + 0.5 * np.sin((yy * 60 + value_noise(6, 3) * 7 + plank * 1.7) * np.pi)
    g = (0.70 + 0.10 * grain + 0.10 * ((plank * 0.37) % 1.0) + 0.08 * (fine - 0.5)) * (0.55 + 0.45 * seam)
    save("wood", tint(g, (1.0, 0.96, 0.92)), seam * 0.8 + grain * 0.2, 5.0)
    # Roof tiles: staggered shingles, rounded lower edge.
    rows, cols = 5, 3
    row = np.floor(yy * rows)
    u = (xx + np.where(row % 2 == 1, 0.5 / cols, 0)) % 1.0
    fx = u * cols - np.floor(u * cols)
    fy = yy * rows - row
    tile = np.clip(np.minimum(fx, 1 - fx) / 0.06, 0, 1) * np.clip((1 - fy) / 0.18, 0, 1)
    shade = 0.62 + 0.38 * fy  # darker at the top where the next row overlaps
    ids = (row * 31 + np.floor(u * cols) * 7) % 97
    r = (np.sin(ids * 78.233) * 43758.5453) % 1.0
    g = (0.78 + 0.12 * r + 0.08 * (fine - 0.5)) * shade * (0.6 + 0.4 * tile)
    save("roof", tint(g, (1.0, 1.0, 1.0)), tile * fy, 7.0)
    # Paving / cobbles.
    h, r = bricks(3, 3, 0.05)
    g = (0.74 + 0.16 * r + 0.12 * (fine - 0.5)) * (0.55 + 0.45 * h)
    save("paving", tint(g, (1.0, 1.0, 1.0)), h * 0.85 + fine * 0.15, 7.0)
    # Plain (coloured blocks, glass, magic): soft speckle + inset frame.
    edge = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    frame = np.clip((edge - 0.06) / 0.04, 0, 1)
    g = (0.88 + 0.10 * (fine - 0.5)) * (0.86 + 0.14 * frame)
    save("plain", tint(g, (1.0, 1.0, 1.0)), frame * 0.6 + fine * 0.1, 3.0)
    # Grass top: lush green with blade speckles and a soft cell border (grid).
    blades = value_noise(48, 2)
    g = 0.78 + 0.18 * (blades - 0.5) + 0.12 * (coarse - 0.5)
    border = np.clip(edge / 0.03, 0, 1)
    grass = tint(g * (0.9 + 0.1 * border), (0.42, 0.74, 0.30))
    save("grass_top", grass, blades * 0.5 + border * 0.2, 4.0)
    # Dirt and grass side (green fringe with jagged edge over dirt).
    dirt_g = 0.72 + 0.20 * (fine - 0.5) + 0.10 * (coarse - 0.5)
    dirt = tint(dirt_g, (0.58, 0.42, 0.28))
    pebbles = (value_noise(24, 1) > 0.78).astype(float)
    dirt = dirt * (1 + 0.18 * pebbles[..., None])
    save("dirt", dirt, fine * 0.6 + pebbles * 0.4, 5.0)
    fringe_line = 0.21 + 0.035 * np.sin(xx * np.pi * 12) + 0.10 * (value_noise(10, 3) - 0.5)
    is_grass = (yy < fringe_line).astype(float)
    side = dirt * (1 - is_grass[..., None]) + grass * is_grass[..., None]
    save("grass_side", side, is_grass * 0.5 + fine * 0.4, 5.0)
    # Leaves: blotchy greens for voxel tree crowns.
    leaf = value_noise(10, 4)
    g = 0.70 + 0.35 * (leaf - 0.5)
    save("leaves", tint(g * (0.9 + 0.1 * frame), (0.45, 0.76, 0.33)), leaf, 5.0)
    # Bark: vertical furrows.
    furrow = 0.5 + 0.5 * np.sin((xx * 9 + value_noise(5, 3) * 1.5) * np.pi * 2)
    g = 0.62 + 0.16 * furrow + 0.08 * (fine - 0.5)
    save("bark", tint(g, (0.62, 0.45, 0.30)), furrow, 6.0)
    print("[BauweltTextures] wrote", sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
