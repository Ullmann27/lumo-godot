#!/usr/bin/env python3
"""Compare original, unretouched Godot runtime captures from two immutable SHAs.

Produces annotated side-by-side references and numeric change metrics.
Pixel differences prove a rendering change, not that art quality improved.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

VIEWS = (
    "01_start_grid", "02_grandstand", "03_terraced_curve",
    "04_waterfall", "05_harbour_run", "06_overview",
)


def compare(before: Path, after: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    summary = {
        "baseline": "ea69d122c7c36d0b4b5ffaab388321ddb0931967",
        "scope": "Actual Godot 4.6.3 Mesa GL Compatibility screenshots",
        "caveat": "Pixel change is not evidence of visual quality or device frame rate",
        "views": {}
    }
    for name in VIEWS:
        p1, p2 = before / (name + ".png"), after / (name + ".png")
        if not p1.is_file() or not p2.is_file():
            raise AssertionError(f"{name}: missing actual screenshot")
        with Image.open(p1) as first, Image.open(p2) as second:
            a, b = first.convert("RGB"), second.convert("RGB")
            if a.size != b.size or a.size != (1280, 720):
                raise AssertionError(f"{name}: unexpected capture dimensions {a.size}/{b.size}")
            diff = ImageChops.difference(a, b)
            mean = sum(ImageStat.Stat(diff).mean) / 3
            summary["views"][name] = {
                "before_bytes": p1.stat().st_size,
                "after_bytes": p2.stat().st_size,
                "mean_rgb_delta": round(mean, 3),
                "changed_bbox": list(diff.getbbox()) if diff.getbbox() else None,
            }
            sheet = Image.new("RGB", (2560, 770), (15, 30, 47))
            sheet.paste(a, (0, 50))
            sheet.paste(b, (1280, 50))
            draw = ImageDraw.Draw(sheet)
            draw.text((20, 18), "BEFORE - BASELINE ea69d12", fill="white")
            draw.text((1300, 18), "AFTER - ASSEMBLED MATERIAL CANDIDATE", fill="white")
            sheet.save(out / f"comparison_{name}.png", optimize=True)
    (out / "comparison_metrics.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("[KartAsphaltComparison] PASS: six paired unretouched before/after Godot views")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: compare_asphalt_before_after.py BEFORE AFTER OUT")
    compare(*map(Path, sys.argv[1:]))
