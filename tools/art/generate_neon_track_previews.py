"""Reproducible small Lumo Kart track previews from actual Godot 2032 captures.

This is authoring code, not runtime. It never invents an in-game environment.
Requires: Pillow. Run from the lumo-godot project root.
"""
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
SOURCE = {
    "volcano_night": "evidence/lumo_kart_runtime/review/volcano_night_entry.png",
    "jungle_emerald_3600": "evidence/jungle_emerald_3600/dense/godot_final/waterfall.png",
    "desert_drift": "evidence/lumo_kart_runtime/review/desert_drift_entry.png",
    "sonnenhafen": "assets/kart/landing/sonnenhafen_art.webp",
}
OUT = ROOT / "assets/kart/neon_previews"


def generate() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for track, path in SOURCE.items():
        with Image.open(ROOT / path) as im:
            img = ImageEnhance.Color(ImageEnhance.Contrast(im.convert("RGB")).enhance(1.11)).enhance(1.17)
            width, height = img.size
            ratio = 16 / 9
            if width / height > ratio:
                new_width = int(height * ratio)
                left = (width - new_width) // 2
                img = img.crop((left, 0, left + new_width, height))
            else:
                new_height = int(width / ratio)
                top = (height - new_height) // 2
                img = img.crop((0, top, width, top + new_height))
            destination = OUT / (track + ".webp")
            img.resize((640, 360), Image.Resampling.LANCZOS).save(destination, "WEBP", quality=82, method=5)
            assert destination.stat().st_size > 1000, destination
            print(f"{track}: {destination.stat().st_size} bytes")


if __name__ == "__main__":
    generate()
