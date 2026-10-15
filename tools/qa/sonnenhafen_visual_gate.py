#!/usr/bin/env python3
"""Fail closed on missing, uniform, or duplicated Sonnenhafen runtime screenshots.

Input PNGs MUST originate from the running Godot renderer. This gate does not
claim parity with artwork, native Android frame rates, or APK installability.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

CAPTURE_NAMES = (
    "01_start_grid",
    "02_grandstand",
    "03_terraced_curve",
    "04_waterfall",
    "05_harbour_run",
    "06_overview",
)
SAMPLE_SIZE = (160, 90)
GRID_TILE = (480, 270)
CAPTURE_DIMENSIONS = (1280, 720)


def check(root: Path) -> dict:
    frames = {}
    report = {"source": "Godot 4.6.3 rendered screenshots (Mesa GL Compatibility)",
              "dimensions": list(CAPTURE_DIMENSIONS), "views": {}}
    for name in CAPTURE_NAMES:
        path = root / f"{name}.png"
        if not path.is_file() or path.stat().st_size < 8_000:
            raise AssertionError(f"{name}: screenshot absent or unexpectedly tiny")
        with Image.open(path) as original:
            original.verify()
        with Image.open(path) as loaded:
            rgb = loaded.convert("RGB")
            if rgb.size != CAPTURE_DIMENSIONS:
                raise AssertionError(f"{name}: image size {rgb.size}, expected {CAPTURE_DIMENSIONS}")
            sample = rgb.resize(SAMPLE_SIZE)
            metrics = ImageStat.Stat(sample)
            unique = len(set(sample.getdata()))
            mean = sum(metrics.mean) / 3.0
            contrast = max(metrics.stddev)
            if unique < 90 or contrast < 6.0 or mean < 9.0 or mean > 248.0:
                raise AssertionError(
                    f"{name}: probable blank/flat image: unique={unique}, "
                    f"contrast={contrast:.2f}, brightness={mean:.2f}"
                )
            report["views"][name] = {"bytes": path.stat().st_size, "unique_sample_colors": unique,
                                      "brightness": round(mean, 2), "max_channel_stddev": round(contrast, 2)}
            frames[name] = (rgb, sample)
    start = frames["01_start_grid"][1]
    overview = frames["06_overview"][1]
    diff = ImageStat.Stat(ImageChops.difference(start, overview)).mean
    separation = sum(diff) / 3.0
    if separation < 4.0:
        raise AssertionError(f"Start and overview are nearly identical ({separation:.2f}); camera may be stuck")
    report["start_overview_average_rgb_delta"] = round(separation, 2)

    margin = 20
    header = 60
    board = Image.new("RGB", (GRID_TILE[0] * 3 + margin * 4,
                               GRID_TILE[1] * 2 + header + margin * 3), (15, 28, 48))
    draw = ImageDraw.Draw(board)
    draw.text((margin, 17), "LUMO KART  |  SONNENHAFEN  |  ACTUAL GODOT CAPTURES",
              fill=(235, 246, 253))
    for n, name in enumerate(CAPTURE_NAMES):
        column, row = n % 3, n // 3
        x, y = margin + column * (GRID_TILE[0] + margin), header + margin + row * (GRID_TILE[1] + margin)
        image = frames[name][0].resize(GRID_TILE)
        board.paste(image, (x, y))
        draw.rectangle((x, y, x + 220, y + 23), fill=(15, 28, 48))
        draw.text((x + 10, y + 6), name.replace("_", " "), fill=(235, 246, 253))
    montage = root / "00_sonnenhafen_runtime_montage.png"
    board.save(montage, optimize=True)
    summary = root / "visual_quality_report.json"
    summary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    try:
        report = check(Path(sys.argv[1] if len(sys.argv) > 1 else "exports/sonnenhafen"))
        print("[SonnenhafenVisualGate] PASS:", len(report["views"]), "nonblank runtime views",
              "start-overview delta", report["start_overview_average_rgb_delta"])
    except (AssertionError, OSError, ValueError) as exc:
        print(f"[SonnenhafenVisualGate] FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
