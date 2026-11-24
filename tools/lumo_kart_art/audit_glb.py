#!/usr/bin/env python3
"""Measure the authored glTF binaries independently of their Blender generators.

This checks bytes, accessors, finite geometry, skin weights, texture sizes and
animation data. It does not replace visual review or Android frame-time tests.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import sys

import numpy as np
from PIL import Image


COMPONENTS = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
REQUIRED_DRIVER_CLIPS = {"idle", "kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump", "celebrate"}


class BinaryModel:
    def __init__(self, path: Path):
        self.path = path
        self.raw = path.read_bytes()
        magic, version, length = struct.unpack_from("<4sII", self.raw)
        if magic != b"glTF" or version != 2 or length != len(self.raw):
            raise ValueError("Invalid glTF 2.0 binary header/length")
        self.document = None
        self.binary = b""
        offset = 12
        while offset < length:
            size, kind = struct.unpack_from("<II", self.raw, offset)
            offset += 8
            chunk = self.raw[offset:offset + size]
            if len(chunk) != size:
                raise ValueError("Truncated GLB chunk")
            if kind == 0x4E4F534A:
                self.document = json.loads(chunk.rstrip(b" \0"))
            elif kind == 0x004E4942:
                self.binary = chunk
            offset += size
        if self.document is None:
            raise ValueError("Missing JSON chunk")

    def array(self, index: int) -> np.ndarray:
        accessor = self.document["accessors"][index]
        if "sparse" in accessor:
            raise ValueError("Sparse accessor requires an explicit audit implementation")
        count = accessor["count"]
        width = WIDTHS[accessor["type"]]
        dtype = np.dtype(COMPONENTS[accessor["componentType"]])
        if "bufferView" not in accessor:
            return np.zeros((count, width), dtype=dtype)
        view = self.document["bufferViews"][accessor["bufferView"]]
        if view.get("buffer", 0) != 0:
            raise ValueError("Expected embedded buffer zero")
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * dtype.itemsize)
        end = start + max(0, count - 1) * stride + (width * dtype.itemsize if count else 0)
        if end > view.get("byteOffset", 0) + view["byteLength"] or end > len(self.binary):
            raise ValueError("Accessor exceeds its buffer view")
        result = np.ndarray((count, width), dtype=dtype, buffer=self.binary,
                            offset=start, strides=(stride, dtype.itemsize)).copy()
        if accessor.get("normalized") and accessor["componentType"] != 5126:
            bounds = np.iinfo(dtype)
            result = result.astype(float) / bounds.max
            if bounds.min < 0:
                result = np.maximum(-1, result)
        return result


def local_transform(node: dict) -> np.ndarray:
    if "matrix" in node:
        return np.array(node["matrix"], dtype=float).reshape((4, 4), order="F")
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    rotation = np.array([
        [1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w)],
        [2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w)],
        [2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y)],
    ])
    result = np.eye(4)
    result[:3, :3] = rotation @ np.diag(node.get("scale", [1, 1, 1]))
    result[:3, 3] = node.get("translation", [0, 0, 0])
    return result


def inspect(path: Path, base: Path) -> dict:
    model = BinaryModel(path)
    doc = model.document
    errors = []
    warnings = []
    triangles = 0
    vertices = 0
    degenerate = 0
    surface_count = 0
    normalized_deviation = 0.0
    joint_weight_deviation = 0.0
    textureless_surfaces = 0
    meshes = doc.get("meshes", [])
    mesh_bounds = {}
    for mesh_index, mesh in enumerate(meshes):
        all_positions = []
        for primitive in mesh.get("primitives", []):
            surface_count += 1
            if primitive.get("mode", 4) != 4:
                errors.append("Non-triangle primitive")
                continue
            attrs = primitive.get("attributes", {})
            positions = model.array(attrs["POSITION"]).astype(float)
            all_positions.append(positions)
            vertices += len(positions)
            if not np.isfinite(positions).all():
                errors.append("Non-finite position")
            indices = model.array(primitive["indices"]).ravel().astype(int) if "indices" in primitive else np.arange(len(positions))
            if len(indices) % 3 or (len(indices) and (indices.min() < 0 or indices.max() >= len(positions))):
                errors.append("Invalid triangle index buffer")
                continue
            faces = positions[indices.reshape((-1, 3))]
            areas = np.linalg.norm(np.cross(faces[:, 1] - faces[:, 0], faces[:, 2] - faces[:, 0]), axis=1)
            degenerate += int(np.count_nonzero(areas < 1e-12))
            triangles += len(faces)
            if "NORMAL" not in attrs:
                errors.append("Missing authored normals")
            else:
                normals = model.array(attrs["NORMAL"]).astype(float)
                if not np.isfinite(normals).all():
                    errors.append("Non-finite normal")
                normalized_deviation = max(normalized_deviation, float(np.max(np.abs(np.linalg.norm(normals, axis=1) - 1))))
            # Separate physics proxies intentionally carry no rendering material.
            if "material" not in primitive and not path.name.endswith("_collision.glb"):
                errors.append("Missing material")
            if "TEXCOORD_0" not in attrs:
                textureless_surfaces += 1
            if "WEIGHTS_0" in attrs:
                weights = model.array(attrs["WEIGHTS_0"]).astype(float)
                if "WEIGHTS_1" in attrs:
                    weights = np.concatenate((weights, model.array(attrs["WEIGHTS_1"])), axis=1)
                if not np.isfinite(weights).all() or np.any(weights < 0):
                    errors.append("Invalid skin weights")
                joint_weight_deviation = max(joint_weight_deviation, float(np.max(np.abs(weights.sum(axis=1) - 1))))
        if all_positions:
            positions = np.concatenate(all_positions)
            mesh_bounds[mesh_index] = (positions.min(axis=0), positions.max(axis=0))
    if degenerate:
        errors.append(f"{degenerate} triangles have near-zero area")
    if normalized_deviation > 0.01:
        errors.append("Normals deviate from unit length by over 0.01")
    if joint_weight_deviation > 0.002:
        errors.append("Skin weights do not sum to one")

    nodes = doc.get("nodes", [])
    roots = doc.get("scenes", [{}])[doc.get("scene", 0)].get("nodes", [])
    points = []
    markers = {}
    instanced_triangles = 0

    def visit(index: int, parent: np.ndarray):
        nonlocal instanced_triangles
        node = nodes[index]
        world = parent @ local_transform(node)
        if "mesh" in node and node["mesh"] in mesh_bounds:
            lo, hi = mesh_bounds[node["mesh"]]
            corners = np.array([[x, y, z, 1] for x in [lo[0], hi[0]] for y in [lo[1], hi[1]] for z in [lo[2], hi[2]]])
            points.extend((world @ corners.T).T[:, :3])
            for primitive in meshes[node["mesh"]]["primitives"]:
                count = doc["accessors"][primitive.get("indices", primitive["attributes"]["POSITION"])]["count"]
                instanced_triangles += count // 3
        if "mesh" not in node and "skin" not in node:
            markers[node.get("name", str(index))] = [round(float(x), 6) for x in world[:3, 3]]
        for child in node.get("children", []):
            visit(child, world)

    for root in roots:
        visit(root, np.eye(4))

    image_info = []
    for item in doc.get("images", []):
        if "bufferView" not in item:
            errors.append("Image is not embedded")
            image_info.append({"name": item.get("name"), "external_uri": item.get("uri")})
            continue
        view = doc["bufferViews"][item["bufferView"]]
        offset = view.get("byteOffset", 0)
        data = model.binary[offset:offset + view["byteLength"]]
        with Image.open(io.BytesIO(data)) as img:
            img.load()
            image_info.append({"name": item.get("name"), "width": img.width, "height": img.height, "mode": img.mode, "sha256": hashlib.sha256(data).hexdigest()})
    animations = []
    for animation in doc.get("animations", []):
        duration = 0.0
        changing_channels = 0
        for sampler in animation.get("samplers", []):
            time = model.array(sampler["input"]).ravel()
            values = model.array(sampler["output"]).astype(float)
            if not np.isfinite(time).all() or not np.isfinite(values).all():
                errors.append("Non-finite animation key")
            if len(time) > 1 and np.any(np.diff(time) <= 0):
                errors.append("Animation times are not strictly increasing")
            duration = max(duration, float(time.max()) if len(time) else 0.0)
            if len(values) > 1 and float(np.max(np.ptp(values, axis=0))) > 1e-6:
                changing_channels += 1
        animations.append({"name": animation.get("name"), "duration_seconds": duration,
                           "channels": len(animation.get("channels", [])), "changing_channels": changing_channels})
    if "/drivers/" in path.as_posix():
        names = {a["name"] for a in animations}
        missing = REQUIRED_DRIVER_CLIPS - names
        if missing:
            errors.append("Missing driver animations: " + ", ".join(sorted(missing)))
        if not doc.get("skins"):
            errors.append("Driver has no glTF skin")
        for clip in animations:
            if clip["name"] in REQUIRED_DRIVER_CLIPS and clip["changing_channels"] == 0:
                errors.append("Static driver clip: " + str(clip["name"]))
    bounds = np.array(points) if points else np.zeros((1, 3))
    return {"path": path.relative_to(base).as_posix(), "sha256": hashlib.sha256(model.raw).hexdigest(),
            "bytes": len(model.raw), "mesh_resources": len(meshes), "surfaces": surface_count,
            "triangles_unique_meshes": triangles, "triangles_instanced_scene": instanced_triangles,
            "vertices": vertices, "degenerate_triangles": degenerate,
            "materials": len(doc.get("materials", [])), "textures": image_info,
            "surfaces_without_uv": textureless_surfaces,
            "max_normal_length_error": normalized_deviation, "max_skin_weight_sum_error": joint_weight_deviation,
            "static_bounds_min": bounds.min(axis=0).tolist(), "static_bounds_max": bounds.max(axis=0).tolist(),
            "static_dimensions_m": np.ptp(bounds, axis=0).tolist(),
            "skins": [{"name": s.get("name"), "joints": len(s["joints"])} for s in doc.get("skins", [])],
            "animations": animations, "node_positions_m": markers,
            "errors": sorted(set(errors)), "warnings": warnings, "passed": not errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    base = args.root.resolve()
    files = sorted((base / "assets/kart/production").rglob("*.glb"))
    results = []
    for path in files:
        try:
            results.append(inspect(path, base))
        except Exception as exc:
            results.append({"path": path.relative_to(base).as_posix(), "passed": False, "errors": [str(exc)]})
    report = {"schema_version": 1, "method": "Independent glTF binary/accessor/skin/animation inspection",
              "visual_review": False, "physical_android_test": False,
              "assets": results, "asset_count": len(results), "passed": bool(results) and all(r["passed"] for r in results)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    for result in results:
        print(("PASS" if result["passed"] else "FAIL"), result["path"], result.get("triangles_unique_meshes", "?"), result.get("errors", []))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
