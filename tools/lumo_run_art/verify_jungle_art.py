#!/usr/bin/env python3
"""Checks the generated jungle art of Lumo Lauf (no Blender needed).

  python3 tools/lumo_run_art/verify_jungle_art.py

For every model listed in assets/games/run/jungle/models/jungle_art.json:
the GLB exists, is at most 2 MB, embeds no image, every image it references
exists in models/textures/, its triangle count and material names match the
manifest, leaf materials are alpha-cut and double sided, plants carry the wind
channel (TEXCOORD_1). Textures are at most 1024 px and 2 MB; the whole art
folder stays under 20 MB; every GLB has a committed .import with automatic
LODs switched off and every texture import builds mipmaps.
Exit 1 on any failure.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/games/run/jungle/models"
TEXTURES = MODELS / "textures"
MAX_FILE = 2 * 1024 * 1024
MAX_TOTAL = 20 * 1024 * 1024
REQUIRED = [
    "tree_broad", "tree_slender", "tree_fig", "tree_kapok", "palm_a", "fern_a", "bigleaf_a", "liana_a", "rock_a",
    "pillar", "arch", "wall", "statue", "stairs", "post", "plank", "rope", "barrel", "crate", "cart", "lantern",
    "gate", "boulder", "mushroom", "crystal_a", "crab", "beetle", "coconut", "log", "groundcover",
]


def read_glb(path: Path) -> dict:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError(f"{path.name}: not a glTF 2 binary")
    json_length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + json_length])


def triangles(document: dict) -> int:
    total = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            if "indices" in primitive:
                total += document["accessors"][primitive["indices"]]["count"] // 3
            else:
                total += document["accessors"][primitive["attributes"]["POSITION"]]["count"] // 3
    return total


def image_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    index = 2
    while index < len(data):
        marker = data[index + 1]
        length = struct.unpack(">H", data[index + 2:index + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2):
            height, width = struct.unpack(">HH", data[index + 5:index + 9])
            return width, height
        index += 2 + length
    raise ValueError(f"{path.name}: size unknown")


def verify() -> tuple[list[str], dict]:
    problems: list[str] = []
    manifest = json.loads((MODELS / "jungle_art.json").read_text())
    models = manifest["models"]
    for name in REQUIRED:
        if name not in models:
            problems.append(f"model {name} missing from manifest")
    summary = {"models": len(models), "triangles": {}, "bytes": 0}
    for name, entry in models.items():
        path = MODELS / entry["file"]
        if not path.exists():
            problems.append(f"{name}: {path.name} missing")
            continue
        size = path.stat().st_size
        summary["bytes"] += size
        if size > MAX_FILE:
            problems.append(f"{name}: {size} bytes > 2 MB")
        document = read_glb(path)
        for image in document.get("images", []):
            if "bufferView" in image:
                problems.append(f"{name}: embeds an image")
            elif not (MODELS / image.get("uri", "")).exists():
                problems.append(f"{name}: image {image.get('uri')} not found")
        count = triangles(document)
        summary["triangles"][name] = count
        if count != entry["triangles"]:
            problems.append(f"{name}: {count} triangles, manifest says {entry['triangles']}")
        names = [m["name"] for m in document.get("materials", [])]
        if names != entry["materials"]:
            problems.append(f"{name}: materials {names} != {entry['materials']}")
        for material in document.get("materials", []):
            if material["name"] == "leaves":
                if material.get("alphaMode") != "MASK" or not material.get("doubleSided"):
                    problems.append(f"{name}: leaves are not alpha-cut and double sided")
        if "leaves" in names:
            for mesh in document["meshes"]:
                for primitive in mesh["primitives"]:
                    if "TEXCOORD_1" not in primitive["attributes"]:
                        problems.append(f"{name}: no wind channel (TEXCOORD_1)")
        if count > 12000:
            problems.append(f"{name}: {count} triangles is too heavy for a phone")
        import_file = path.with_name(path.name + ".import")
        if not import_file.exists():
            problems.append(f"{name}: no committed .import")
        elif "meshes/generate_lods=false" not in import_file.read_text():
            problems.append(f"{name}: automatic LODs are on")
    for texture in sorted(TEXTURES.iterdir()):
        if texture.suffix == ".import":
            continue
        size = texture.stat().st_size
        summary["bytes"] += size
        width, height = image_size(texture)
        if max(width, height) > 1024:
            problems.append(f"{texture.name}: {width}x{height} > 1024")
        if size > MAX_FILE:
            problems.append(f"{texture.name}: {size} bytes > 2 MB")
        import_file = texture.with_name(texture.name + ".import")
        if not import_file.exists() or "mipmaps/generate=true" not in import_file.read_text():
            problems.append(f"{texture.name}: import without mipmaps")
    if summary["bytes"] > MAX_TOTAL:
        problems.append(f"art folder {summary['bytes']} bytes > 20 MB")
    return problems, summary


def main() -> int:
    problems, summary = verify()
    for name, count in sorted(summary["triangles"].items()):
        print(f"{name:20s} {count:6d} triangles")
    print(f"{summary['models']} models, {summary['bytes'] / 1048576:.2f} MB")
    for problem in problems:
        print("FAIL", problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
