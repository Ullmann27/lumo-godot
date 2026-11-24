#!/usr/bin/env python3
"""Upgrade the Bauwelt block textures (assets/creative/bauwelt_voxel) to 512 px.

Same file names and the same colour logic as before: tinted materials (stone,
wood, roof, paving, plain, sand) stay light and neutral so BuildVoxelStyle's
albedo_color still decides the colour; natural ones (grass, dirt, leaves,
bark) keep their own colour. The magic block keeps its original artwork.
Eigenbau, seeded noise only (shares the generators of make_textures.py).
Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/make_voxel_textures.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_textures as mt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/bauwelt_voxel"
SIZE = 512


def neutral(col: np.ndarray, level: float = 0.84, warmth: float = 0.03, keep: float = 0.12) -> np.ndarray:
    gray = col.mean(axis=-1, keepdims=True)
    gray = gray / max(gray.mean(), 1e-5) * level
    out = gray * (1 - keep) + col / max(col.mean(), 1e-5) * level * keep
    out = out + np.array([warmth, warmth * 0.4, -warmth * 0.3])
    return np.clip(out, 0, 1)


def save(name: str, col: np.ndarray, height: np.ndarray, strength: float) -> None:
    mt.to_img(np.clip(col, 0, 1)).save(OUT / f"{name}_albedo.png", optimize=True)
    mt.to_img(mt.normal_from_height(height, strength)).save(OUT / f"{name}_normal.png", optimize=True)


def main() -> None:
    s = SIZE
    col, h, _ = mt.tile_stone_wall(s)
    save("stone", neutral(col, 0.86, 0.0, 0.05), h, 5.0)
    col, h, _ = mt.tile_planks(s)
    save("wood", neutral(col, 0.82, 0.012, 0.1), h, 3.5)
    col, h, _ = mt.tile_roof_clay(s)
    save("roof", neutral(col, 0.84, 0.0, 0.0), h, 5.0)
    col, h, _ = mt.tile_cobble(s)
    save("paving", neutral(col, 0.86, 0.0, 0.05), h, 4.0)
    col, h, _ = mt.tile_plaster(s)
    save("plain", neutral(col, 0.92, 0.0, 0.1), h, 1.5)
    alb, _ = mt.terrain_sand(s)
    sand = np.asarray(alb, dtype=np.float64) / 255.0
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
    sand_h = mt.fbm(s, 61, 6.0, 4) * 0.6 + np.sin((xx / s * 10 + mt.fbm(s, 62, 3.0, 3) * 2) * 2 * np.pi) * 0.2
    save("sand", neutral(sand, 0.88, 0.01, 0.2), sand_h, 1.8)
    alb, _ = mt.terrain_grass(s)
    grass = np.asarray(alb, dtype=np.float64) / 255.0
    grass_h = mt.strokes(s, 4000, 71, 8.0, 1.2, 0.5)
    save("grass_top", grass, grass_h, 2.4)
    alb, _ = mt.terrain_dirt(s)
    dirt = np.asarray(alb, dtype=np.float64) / 255.0
    dirt_h = mt.fbm(s, 72, 6.0, 5)
    save("dirt", dirt, dirt_h, 3.0)
    # Grass side: dirt body with a ragged grass fringe hanging from the top.
    fringe = 0.26 + 0.07 * np.sin(xx / s * 2 * np.pi * 9) + (mt.fbm(s, 73, 12.0, 3) - 0.5) * 0.12
    band = (yy / s < fringe).astype(np.float64)
    side = mt.mix(dirt, grass, band)
    side_h = np.maximum(dirt_h * (1 - band), band * (0.6 + grass_h * 0.4))
    save("grass_side", side, side_h, 3.0)
    col, h, _ = mt.tile_leaves(s)
    save("leaves", col, h, 3.0)
    col, h, _ = mt.tile_bark(s)
    save("bark", col, h, 4.0)
    print("voxel textures:", 11)


if __name__ == "__main__":
    main()
