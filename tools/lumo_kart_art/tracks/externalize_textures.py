#!/usr/bin/env python3
"""Store every tunnel texture once per course instead of once per module.

The tunnel kit embeds the same four maps in up to fourteen GLB files of a
course, and the engine imports each copy uncompressed (about 5.7 MB per
module). This tool rewrites each GLB so that its images are external files
referenced by a relative ``uri`` (valid glTF, also inside ``.glb``): identical
bytes are written once to ``<course>/textures/``. Geometry, materials,
samplers and node data are not touched; only image storage changes.

Idempotent: a GLB without embedded images is left exactly as it is.

Run: python3 tools/lumo_kart_art/tracks/externalize_textures.py [--check]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TRACKS = ROOT / "assets/kart/production/tracks"
EXTENSIONS = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}
GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2 or length != len(data):
        raise ValueError(f"{path}: not a glTF 2 binary")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != JSON_CHUNK:
        raise ValueError(f"{path}: first chunk is not JSON")
    document = json.loads(data[20:20 + json_length])
    offset = 20 + json_length
    binary = b""
    if offset < len(data):
        bin_length, bin_type = struct.unpack_from("<II", data, offset)
        if bin_type != BIN_CHUNK:
            raise ValueError(f"{path}: second chunk is not BIN")
        binary = data[offset + 8:offset + 8 + bin_length]
    return document, binary


def write_glb(path: Path, document: dict, binary: bytes) -> None:
    text = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    chunks = struct.pack("<II", len(text), JSON_CHUNK) + text
    if binary:
        chunks += struct.pack("<II", len(binary), BIN_CHUNK) + binary
    path.write_bytes(struct.pack("<III", GLB_MAGIC, 2, 12 + len(chunks)) + chunks)


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "image"


def externalize(path: Path, check_only: bool) -> dict:
    document, binary = read_glb(path)
    images = document.get("images", [])
    embedded = [i for i, image in enumerate(images) if "bufferView" in image]
    report = {"file": str(path.relative_to(ROOT)), "embedded_images": len(embedded), "written": [], "reused": []}
    if not embedded or check_only:
        return report
    if len(document.get("buffers", [])) != 1 or "uri" in document["buffers"][0]:
        raise ValueError(f"{path}: expected exactly one internal buffer")
    views = document["bufferViews"]
    folder = path.parent / "textures"
    folder.mkdir(exist_ok=True)
    removed: set[int] = set()
    for index in embedded:
        image = images[index]
        view = views[image["bufferView"]]
        start = view.get("byteOffset", 0)
        payload = binary[start:start + view["byteLength"]]
        extension = EXTENSIONS.get(image.get("mimeType", ""))
        if extension is None:
            raise ValueError(f"{path}: unsupported image type {image.get('mimeType')}")
        digest = hashlib.sha256(payload).hexdigest()
        name = safe_name(image.get("name", f"image_{digest[:8]}"))
        target = folder / (name + extension)
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            target = folder / f"{name}_{digest[:8]}{extension}"
        if target.exists():
            report["reused"].append(target.name)
        else:
            target.write_bytes(payload)
            report["written"].append(target.name)
        removed.add(image["bufferView"])
        images[index] = {"name": image.get("name", name), "uri": f"textures/{target.name}"}
    # Rebuild the binary chunk without the image views; keep order and alignment.
    remap: dict[int, int] = {}
    rebuilt = bytearray()
    kept = []
    for old_index, view in enumerate(views):
        if old_index in removed:
            continue
        start = view.get("byteOffset", 0)
        payload = binary[start:start + view["byteLength"]]
        rebuilt += b"\0" * (-len(rebuilt) % 4)
        updated = dict(view)
        updated["byteOffset"] = len(rebuilt)
        rebuilt += payload
        remap[old_index] = len(kept)
        kept.append(updated)
    document["bufferViews"] = kept

    def retarget(holder: dict) -> None:
        if "bufferView" in holder:
            if holder["bufferView"] in removed:
                raise ValueError(f"{path}: geometry shares a buffer view with an image")
            holder["bufferView"] = remap[holder["bufferView"]]

    for accessor in document.get("accessors", []):
        retarget(accessor)
        sparse = accessor.get("sparse")
        if sparse:
            retarget(sparse["indices"])
            retarget(sparse["values"])
    for image in images:
        retarget(image)
    document["buffers"][0]["byteLength"] = len(rebuilt) + (-len(rebuilt) % 4)
    write_glb(path, document, bytes(rebuilt))
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="only report; exit 1 if images are still embedded")
    arguments = parser.parse_args()
    reports = [externalize(path, arguments.check) for path in sorted(TRACKS.glob("*/*.glb"))]
    embedded = sum(report["embedded_images"] for report in reports)
    written = sum(len(report["written"]) for report in reports)
    reused = sum(len(report["reused"]) for report in reports)
    print(json.dumps({"glb_files": len(reports), "embedded_images_found": embedded,
                      "texture_files_written": written, "references_to_existing_files": reused,
                      "check_only": arguments.check}, indent=2))
    return 1 if arguments.check and embedded else 0


if __name__ == "__main__":
    sys.exit(main())
