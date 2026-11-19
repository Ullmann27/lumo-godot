#!/usr/bin/env python3
"""Prüft Lumos Bildstreifen für die Lern-App gegen den Liefervertrag.

- lumo_actor.json gültig (version, frame, anchor, clips mit file/frames/columns/fps/loop)
- Dateien vorhanden, Raster passt zur Bildgröße
- jedes Feld hat Deckung, nichts berührt den Feldrand (nichts abgeschnitten)
- Anker liegt in jedem Feld auf/unter den untersten deckenden Pixeln (±6 px);
  bei Bewegungen am Boden (ohne Sprung/Flugphase) zusätzlich nicht darüber schwebend
- Gesamtgröße höchstens 3 MB

Aufruf: python tools/lumo_actor/verify_lumo_actor.py <ordner>
Exit 0 bei PASS, 1 bei FAIL.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REQUIRED = ["idle", "run", "point", "talk", "listen", "think", "cheer", "comfort", "wave"]
AIRBORNE = {"run", "cheer"}
TOLERANCE = 6
BUDGET = 3 * 1024 * 1024


def main() -> int:
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else "exports/lumo_actor")
    failures: list[str] = []
    warnings: list[str] = []
    checks = 0

    def check(condition: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    manifest_path = folder / "lumo_actor.json"
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, ValueError) as error:
        print(f"FAIL lumo_actor.json: {error}")
        return 1
    check(manifest.get("version") == 1, "version muss 1 sein")
    frame = manifest.get("frame")
    check(isinstance(frame, list) and len(frame) == 2, "frame [w,h] fehlt")
    fw, fh = int(frame[0]), int(frame[1])
    ax, ay = (float(v) for v in manifest.get("anchor", [-1, -1]))
    check(0 <= ax < fw and 0 <= ay < fh, "anchor liegt nicht im Feld")
    clips = manifest.get("clips", {})
    for name in REQUIRED:
        if name not in clips:
            warnings.append(f"Bewegung fehlt noch: {name}")
    shadow = manifest.get("shadow", {}).get("file")
    if shadow:
        check((folder / shadow).exists(), f"Schatten fehlt: {shadow}")
    for name, clip in clips.items():
        for key in ("file", "frames", "columns", "fps", "loop"):
            check(key in clip, f"{name}: Feld '{key}' fehlt")
        path = folder / str(clip.get("file", ""))
        if not path.exists():
            failures.append(f"{name}: Datei fehlt {path.name}")
            continue
        frames, columns = int(clip["frames"]), int(clip["columns"])
        rows = -(-frames // columns)
        image = Image.open(path).convert("RGBA")
        check(image.size == (columns * fw, rows * fh),
              f"{name}: Raster {columns}x{rows} passt nicht zu {image.size}")
        if name == "run":
            check(float(clip.get("stride_px", 0)) > 0, "run: stride_px fehlt")
        alpha = np.asarray(image, dtype=np.uint8)[..., 3]
        lows = []
        for index in range(frames):
            cx, cy = (index % columns) * fw, (index // columns) * fh
            cell = alpha[cy:cy + fh, cx:cx + fw]
            solid = cell >= 128
            check(solid.sum() > 2000, f"{name}[{index}]: keine Deckung")
            if not solid.any():
                continue
            touched = (cell[0].max() > 8 or cell[-1].max() > 8
                       or cell[:, 0].max() > 8 or cell[:, -1].max() > 8)
            check(not touched, f"{name}[{index}]: Figur berührt den Feldrand (abgeschnitten?)")
            low = int(np.where(solid.any(axis=1))[0].max())
            lows.append(low)
            check(low <= ay + TOLERANCE,
                  f"{name}[{index}]: unterster Pixel {low} liegt unter dem Anker {ay:.0f}")
            if name not in AIRBORNE:
                check(low >= ay - TOLERANCE,
                      f"{name}[{index}]: Figur schwebt ({low} über Anker {ay:.0f})")
        size = path.stat().st_size
        print(f"{name}: {frames} Felder, {columns} Spalten, {clip['fps']} fps, "
              f"loop={clip['loop']}, {size / 1024:.0f} KB, Fußzeile {min(lows)}..{max(lows)}")
    total = sum(p.stat().st_size for p in folder.iterdir() if p.is_file())
    check(total <= BUDGET, f"Gesamtgröße {total / 1024:.0f} KB > 3 MB")
    print(f"gesamt {total / 1024:.0f} KB")
    for warning in warnings:
        print("WARN", warning)
    for failure in failures:
        print("FAIL", failure)
    print(("PASS" if not failures else "FAIL") + f" checks={checks} failures={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
