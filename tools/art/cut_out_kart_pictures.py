#!/usr/bin/env python3
"""Turn black/white backdrop renders into pictures with a transparent background.

render_kart_turnaround.gd --cutout writes <kart>_black.png and <kart>_white.png
from the same camera. The difference between both gives the exact coverage of
every pixel (also for soft edges and glass), without guessing an outline.

Usage: cut_out_kart_pictures.py <render dir> <output dir> [--size 320]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def cut_out(black: Path, white: Path) -> Image.Image:
    on_black = np.asarray(Image.open(black).convert("RGB"), dtype=np.float32) / 255.0
    on_white = np.asarray(Image.open(white).convert("RGB"), dtype=np.float32) / 255.0
    # The backdrop values are read from a corner: tone mapping may darken white.
    span = np.maximum(on_white[0, 0] - on_black[0, 0], 1e-3)
    alpha = np.clip(1.0 - ((on_white - on_black) / span).mean(axis=2), 0.0, 1.0)
    colour = np.clip((on_black - on_black[0, 0] * (1.0 - alpha[..., None]))
                     / np.maximum(alpha[..., None], 1e-3), 0.0, 1.0)
    rgba = np.dstack([colour, alpha])
    return Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("renders", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=320)
    arguments = parser.parse_args()
    arguments.output.mkdir(parents=True, exist_ok=True)
    count = 0
    for black in sorted(arguments.renders.glob("*_black.png")):
        white = black.with_name(black.name.replace("_black", "_white"))
        picture = cut_out(black, white)
        box = picture.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
        if box is None:
            raise SystemExit(f"{black}: nothing visible")
        # Square crop around the kart with a small margin, then one clean downscale.
        side = int(max(box[2] - box[0], box[3] - box[1]) * 1.06)
        centre = ((box[0] + box[2]) // 2, (box[1] + box[3]) // 2)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(picture, (side // 2 - centre[0], side // 2 - centre[1]))
        canvas = canvas.resize((arguments.size, arguments.size), Image.LANCZOS)
        canvas.save(arguments.output / (black.name.replace("_black.png", "") + ".webp"),
                    "WEBP", quality=88, method=6)
        count += 1
    print(f"{count} pictures written to {arguments.output}")
    return 0 if count else 1


if __name__ == "__main__":
    raise SystemExit(main())
