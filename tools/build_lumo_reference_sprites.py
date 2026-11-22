#!/usr/bin/env python3
"""Deterministic reference sprite import for Godot Lumo Kart.
Usage: python3 tools/build_lumo_reference_sprites.py /path/to/lumo_kart_neon_rennspass_am_sonnenhafen.png
Requires Pillow. Produces separated reference layers with transparent edges
without baking any clickable UI into a texture. Keep dynamic labels as controls.
"""
import json
import hashlib
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

BOXES = {
    "kart_logo_art.webp": (12, 25, 416, 229),
    "cinematic_hero.webp": (285, 205, 941, 699),
    "grand_prix_art.webp": (36, 700, 450, 844),
    "time_trial_art.webp": (459, 700, 930, 844),
    "sonnenhafen_art.webp": (30, 960, 350, 1110),
    "garage_art.webp": (360, 960, 635, 1110),
    "settings_art.webp": (645, 960, 930, 1110),
    "lumo_avatar.webp": (430, 245, 750, 478),
}
HERE = Path(__file__).resolve().parents[1]
OUTPUT = HERE / "assets" / "kart" / "landing"


def create(source: Path) -> None:
    data = source.read_bytes()
    original = Image.open(source).convert("RGBA")
    if original.size != (941, 1672):
        raise ValueError(f"Expected 941×1672 original Lumo Kart reference, got {original.size}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source_sha256": hashlib.sha256(data).hexdigest(),
        "size": list(original.size),
        "warning": "Original crops have some background/text; no pixel-perfect full-body matting claimed.",
        "outputs": {},
    }
    for filename, coords in BOXES.items():
        crop = original.crop(coords)
        width, height = crop.size
        layer = Image.new("L", crop.size)
        painter = ImageDraw.Draw(layer)
        painter.rounded_rectangle((1, 1, width - 2, height - 2),
                                 radius=min(24, width // 9, height // 9), fill=255)
        if filename == "cinematic_hero.webp":
            pixels = layer.load()
            for y in range(height):
                for x in range(width):
                    distance = min(x, width - 1 - x, y, height - 1 - y)
                    pixels[x, y] = min(pixels[x, y], int(min(255, distance * 8)))
        if filename in {"grand_prix_art.webp", "time_trial_art.webp", "sonnenhafen_art.webp",
                        "garage_art.webp", "settings_art.webp"}:
            pixels = layer.load()
            for y in range(height):
                opacity = max(0.0, min(1.0, (height - y) / (height * .31)))
                for x in range(width):
                    pixels[x, y] = int(pixels[x, y] * opacity)
        crop.putalpha(layer.filter(ImageFilter.GaussianBlur(1)))
        output = OUTPUT / filename
        crop.save(output, "WEBP", quality=83, method=4)
        manifest["outputs"][filename] = {
            "box": list(coords), "bytes": output.stat().st_size,
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "alpha": True,
        }
    background = original.convert("RGB").resize((470, 836), Image.Resampling.LANCZOS)
    background = ImageEnhance.Brightness(background.filter(
        ImageFilter.GaussianBlur(12))).enhance(.55)
    output = OUTPUT / "sunset_world.webp"
    background.save(output, "WEBP", quality=68, method=4)
    manifest["outputs"][output.name] = {
        "bytes": output.stat().st_size, "sha256": hashlib.sha256(output.read_bytes()).hexdigest()
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(
        manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Imported {len(manifest['outputs'])} Lumo Kart visual layers to {OUTPUT}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 tools/build_lumo_reference_sprites.py SOURCE.png")
    create(Path(sys.argv[1]))
