#!/usr/bin/env python3
"""Packt Lumos gerenderte Bewegungsbilder zu Bildstreifen für die Lern-App.

Eingabe: Ordner von scripts/tests/lumo_actor_capture.gd (je Bewegung
<clip>/f_###.png in doppelter Größe, vormultipliziertes Alpha, meta.json).
Ausgabe: clip_<name>.webp (Raster aus 384x384-Feldern), shadow.webp und
lumo_actor.json. Optional Kontaktbögen auf dunklem und hellem Grund.

Aufruf:
  python tools/lumo_actor/pack_lumo_actor.py <roh> <ausgabe> [--sheets <ordner>]
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

FRAME = 384
ORDER = ["idle", "run", "point", "talk", "listen", "think", "cheer", "comfort", "wave"]
MAX_COLUMNS = 8
WEBP_QUALITY = 90


def load_frame(path: Path, supersample: int) -> np.ndarray:
    """Liest ein Feld (vormultipliziert), rechnet im vormultiplizierten Raum
    herunter (Kastenfilter) und gibt gerades Alpha als float32 RGBA 0..1 zurück."""
    data = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    h, w, _ = data.shape
    s = supersample
    data = data.reshape(h // s, s, w // s, s, 4).mean(axis=(1, 3))
    alpha = data[..., 3:4]
    rgb = np.where(alpha > 1e-4, data[..., :3] / np.maximum(alpha, 1e-4), 0.0)
    rgb = np.clip(rgb, 0.0, 1.0)
    alpha = np.where(alpha < 1.5 / 255.0, 0.0, alpha)
    return np.concatenate([rgb, alpha], axis=-1)


def bleed(frame: np.ndarray, steps: int = 6) -> np.ndarray:
    """Füllt die Farbe durchsichtiger Randpixel mit der Farbe der Nachbarn,
    damit verlustbehaftete Kompression keinen dunklen Saum hineinzieht."""
    rgb = frame[..., :3].copy()
    known = frame[..., 3] > 0.0
    for _ in range(steps):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            shifted_known = np.roll(np.roll(known, dy, 0), dx, 1)
            shifted_rgb = np.roll(np.roll(rgb, dy, 0), dx, 1)
            acc += shifted_rgb * shifted_known[..., None]
            cnt += shifted_known
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    out = frame.copy()
    out[..., :3] = rgb
    return out


def to_image(frame: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(np.round(frame * 255.0), 0, 255).astype(np.uint8), "RGBA")


def lowest_row(alpha: np.ndarray, threshold: float = 0.5) -> int:
    rows = np.where((alpha >= threshold).any(axis=1))[0]
    return int(rows.max()) if rows.size else -1


def make_shadow(anchor: tuple[float, float], width: float) -> Image.Image:
    """Weicher, eigenständiger Bodenschatten (ein Feld)."""
    scale = 4
    big = Image.new("L", (FRAME * scale, FRAME * scale), 0)
    draw = ImageDraw.Draw(big)
    cx, cy = anchor[0] * scale, anchor[1] * scale
    rx, ry = width * 0.5 * scale, width * 0.11 * scale
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    big = big.filter(ImageFilter.GaussianBlur(radius=ry * 0.75))
    mask = np.asarray(big.resize((FRAME, FRAME), Image.LANCZOS), dtype=np.float32) / 255.0
    rgba = np.zeros((FRAME, FRAME, 4), dtype=np.float32)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = 0.04, 0.06, 0.14
    rgba[..., 3] = mask * 0.42
    return to_image(rgba)


def contact_sheet(frames: list[Image.Image], columns: int, background: tuple[int, int, int],
                  anchor: tuple[float, float], shadow: Image.Image | None) -> Image.Image:
    rows = math.ceil(len(frames) / columns)
    sheet = Image.new("RGB", (columns * FRAME, rows * FRAME), background)
    line = (255, 80, 80) if sum(background) < 300 else (200, 0, 0)
    for index, frame in enumerate(frames):
        tile = Image.new("RGBA", (FRAME, FRAME), background + (255,))
        if shadow is not None:
            tile.alpha_composite(shadow)
        tile.alpha_composite(frame)
        draw = ImageDraw.Draw(tile)
        ax, ay = anchor
        draw.line((ax - 40, ay, ax + 40, ay), fill=line, width=1)
        draw.line((ax, ay - 6, ax, ay + 6), fill=line, width=1)
        draw.text((6, 4), str(index), fill=line)
        sheet.paste(tile.convert("RGB"), ((index % columns) * FRAME, (index // columns) * FRAME))
    return sheet


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--sheets", type=Path, default=None)
    parser.add_argument("--quality", type=int, default=WEBP_QUALITY)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    clips_meta: dict[str, dict] = {}
    anchor: tuple[float, float] | None = None
    footprint = 0.0
    manifest_path = args.out / "lumo_actor.json"
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text())
        clips_meta.update(previous.get("clips", {}))
        anchor = (float(previous["anchor"][0]), float(previous["anchor"][1]))
    for name in ORDER:
        folder = args.raw / name
        if not (folder / "meta.json").exists():
            continue
        meta = json.loads((folder / "meta.json").read_text())
        supersample = int(meta["supersample"])
        if anchor is None:
            anchor = (float(meta["anchor"][0]), float(meta["anchor"][1]))
        files = sorted(folder.glob("f_*.png"))
        if len(files) != int(meta["frames"]):
            raise SystemExit(f"{name}: {len(files)} Bilder, erwartet {meta['frames']}")
        frames = [load_frame(path, supersample) for path in files]
        if name == "idle":
            # Fußpunkt: waagrecht die Projektion des Wurzelknochens (zwischen den
            # Füßen), senkrecht die gemessene Standlinie der Sohlen im Stand.
            lows = sorted(lowest_row(f[..., 3]) for f in frames)
            anchor = (float(meta["anchor"][0]), float(lows[len(lows) // 2]))
            # Breite der Standfläche für den Schatten.
            alpha = frames[0][..., 3]
            low = lowest_row(alpha)
            cols = np.where((alpha[max(0, low - 24):low + 1] >= 0.5).any(axis=0))[0]
            footprint = float(cols.max() - cols.min()) if cols.size else 110.0
        columns = min(MAX_COLUMNS, len(frames))
        rows = math.ceil(len(frames) / columns)
        strip = Image.new("RGBA", (columns * FRAME, rows * FRAME), (0, 0, 0, 0))
        images = []
        for index, frame in enumerate(frames):
            image = to_image(bleed(frame))
            images.append(image)
            strip.paste(image, ((index % columns) * FRAME, (index // columns) * FRAME))
        file_name = f"clip_{name}.webp"
        strip.save(args.out / file_name, "WEBP", quality=args.quality, method=6,
                   alpha_quality=100, exact=False)
        entry = {
            "file": file_name,
            "frames": len(frames),
            "columns": columns,
            "fps": int(meta["fps"]),
            "loop": bool(meta["loop"]),
        }
        if "stride_px" in meta:
            entry["stride_px"] = float(meta["stride_px"])
        clips_meta[name] = entry
        if args.sheets is not None:
            args.sheets.mkdir(parents=True, exist_ok=True)
            decoded = Image.open(args.out / file_name).convert("RGBA")
            tiles = [decoded.crop(((i % columns) * FRAME, (i // columns) * FRAME,
                                   (i % columns + 1) * FRAME, (i // columns + 1) * FRAME))
                     for i in range(len(frames))]
            shadow_img = make_shadow(anchor, max(footprint, 90.0) * 1.15)
            for label, background in (("dunkel", (24, 32, 52)), ("hell", (246, 241, 230))):
                contact_sheet(tiles, columns, background, anchor, shadow_img).save(
                    args.sheets / f"{name}_{label}.jpg", quality=92)
        size = (args.out / file_name).stat().st_size
        print(f"{name}: {len(frames)} Felder, {columns} Spalten, {entry['fps']} fps, "
              f"{size / 1024:.0f} KB")
    if anchor is None:
        raise SystemExit("keine Bewegungen gefunden")
    shadow = make_shadow(anchor, max(footprint, 90.0) * 1.15)
    shadow.save(args.out / "shadow.webp", "WEBP", quality=args.quality, method=6,
                alpha_quality=100, exact=False)
    ordered = {name: clips_meta[name] for name in ORDER if name in clips_meta}
    manifest = {
        "version": 1,
        "frame": [FRAME, FRAME],
        "anchor": [anchor[0], anchor[1]],
        "facing": "right",
        "shadow": {"file": "shadow.webp"},
        "clips": ordered,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    total = sum(p.stat().st_size for p in args.out.glob("*.webp"))
    print(f"gesamt {total / 1024:.0f} KB, Anker {anchor}, Schattenbreite {footprint:.0f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
