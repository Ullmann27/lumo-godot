#!/usr/bin/env python3
"""Check the exact original Discovery PNG roster and production-state report."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageChops


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def raster_roster() -> dict[str, tuple[int, int]]:
    roster = {
        "hub/hub_portrait.png": (1080, 1920),
        "hub/hub_fold_landscape.png": (2400, 1080),
    }
    for width, height in ((1280, 720), (412, 915), (2400, 1080)):
        for state in ("start", "ten", "complete"):
            roster[f"learning/math-{state}-{width}x{height}.png"] = (width, height)
    for kind in ("syllables", "plant_parts", "subtract_ten", "equal_groups", "bridge_hundred", "fraction_parts"):
        for state in ("start", "complete"):
            roster[f"learning/{kind}-{state}.png"] = (1280, 720)
    for width, height in ((412, 915), (2400, 1080)):
        for state in ("start", "complete"):
            roster[f"learning/bridge_hundred-{state}-{width}x{height}.png"] = (width, height)
    for width, height in ((1280, 720), (412, 915)):
        for state in ("start", "complete"):
            roster[f"wonder/current-numbers-{state}-{width}x{height}.png"] = (width, height)
    roster["wonder/current-numbers-one-step-1280x720.png"] = (1280, 720)
    for kind in ("syllables", "plant_parts"):
        for state in ("start", "complete"):
            roster[f"wonder/current-{kind}-{state}.png"] = (1280, 720)
    for state in ("start", "complete"):
        roster[f"wonder/current-hundreds-phone-{state}.png"] = (412, 915)
    return roster


def read_json(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), f"Original JSON required: {path}")

    def no_duplicates(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    def no_constant(value):
        raise ValueError(f"Non-finite JSON number: {value}")

    result = json.loads(path.read_text(), object_pairs_hook=no_duplicates, parse_constant=no_constant)
    require(type(result) is dict, "Expected a JSON object")
    return result


def verify(directory: Path) -> list[dict]:
    captures = directory / "captures"
    roster = raster_roster()
    found = {str(path.relative_to(captures)) for path in captures.rglob("*.png")}
    require(found == set(roster), f"Original 38-PNG roster differs: missing={set(roster) - found}, extra={found - set(roster)}")
    images = {}
    records = []
    for relative, dimensions in roster.items():
        path = captures / relative
        require(path.is_file() and not path.is_symlink(), f"Original regular PNG required: {relative}")
        with Image.open(path) as original:
            original.load()
            require(original.format == "PNG" and original.size == dimensions, f"Wrong PNG dimensions: {relative}")
            image = original.convert("RGB")
            require(any(low != high for low, high in image.getextrema()), f"Uniform PNG: {relative}")
        images[relative] = image
        records.append({"path": f"captures/{relative}", "width": dimensions[0], "height": dimensions[1],
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    for name, before in images.items():
        if "-start" in name:
            after_name = name.replace("-start", "-complete")
            after = images[after_name]
            require(ImageChops.difference(before, after).getbbox() is not None,
                    f"Actual activity did not change its renderer image: {name}")

    report = read_json(captures / "wonder" / "captures.json")
    require(type(report.get("checks")) is int and report["checks"] == 136, "Original 136 geometry checks required")
    require(type(report.get("failures")) is int and report["failures"] == 0, "Geometry check failed")
    entries = report.get("captures")
    require(type(entries) is list and len(entries) == 11, "Exactly 11 Wonder records required")
    expected = {name.removeprefix("wonder/") for name in roster if name.startswith("wonder/")}
    require(all(type(entry) is dict for entry in entries), "Capture records must be objects")
    require(all(type(entry.get("file")) is str for entry in entries), "Capture filenames must be strings")
    require({entry["file"] for entry in entries} == expected, "Wonder filenames are missing or duplicated")
    for entry in entries:
        name = entry["file"]
        size = entry.get("size")
        require(type(size) is list and len(size) == 2 and all(type(n) is int for n in size), f"Invalid size: {name}")
        require(tuple(size) == roster["wonder/" + name], f"Wrong Wonder dimensions: {name}")
        require(entry.get("headless") is False, "Original renderer evidence is required")
        require(entry.get("actual_production_scene") == "res://scenes/learning/learning_world.tscn", "Wrong scene route")
        complete = "-complete" in name
        require(entry.get("complete") is complete, f"Wrong original completion state: {name}")
        garden = entry.get("garden")
        require(type(garden) is dict, "Actual garden state required")
        require(garden.get("writes_learning_state") is False and garden.get("reduced_motion") is True,
                "Garden must observe original task state and preserve reduced motion")
        for field, value in (("flowers", 5), ("petals", 35), ("geometry_batches", 7)):
            require(type(garden.get(field)) is int and garden[field] == value, f"Wrong geometry budget: {field}")
        progress = garden.get("progress")
        require(type(progress) in (int, float) and math.isfinite(progress), "Finite numeric progress required")
        wanted = 1.0 if complete else (0.2 if "one-step" in name else 0.0)
        require(math.isclose(progress, wanted, abs_tol=1e-8), f"Wrong task-linked bloom progress: {name}")
        kind = "bridge_ten" if "numbers" in name else ("bridge_hundred" if "hundreds" in name else ("syllables" if "syllables" in name else "plant_parts"))
        require(entry.get("kind") == kind and garden.get("kind") == kind, f"Wrong actual lesson: {name}")
    return records


def main() -> None:
    require(len(sys.argv) == 2, "Usage: verify_discovery_rasters.py LOG_DIR")
    directory = Path(sys.argv[1])
    records = verify(directory)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], text=True).strip()
    result = {"schema": 1, "native_source": source, "native_tree": tree, "probes": 10,
              "original_pngs": records, "physical_android_fps_measured": False}
    (directory / "discovery-connections.json").write_text(json.dumps(result, indent=2) + "\n")
    print("[LumoDiscoveryConnections] PASS 10 original probes and 38 verified renderer PNGs")


if __name__ == "__main__":
    main()
