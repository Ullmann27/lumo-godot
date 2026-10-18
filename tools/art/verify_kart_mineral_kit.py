"""Read the actual GLB buffers for the original Sonnenhafen mineral kit.

python3 tools/art/verify_kart_mineral_kit.py [asset-directory]
This is independent of Blender's export statistics and runs without Blender.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct
import sys


def inspect_glb(data: bytes) -> dict:
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(len(data) >= 28, "truncated GLB")
    magic, version, length = struct.unpack_from("<4sII", data)
    require(magic == b"glTF" and version == 2 and length == len(data), "GLB header")
    json_length, tag = struct.unpack_from("<I4s", data, 12)
    require(tag == b"JSON", "GLB JSON chunk")
    doc = json.loads(data[20:20 + json_length])
    binary_offset = 28 + json_length
    binary_length, tag = struct.unpack_from("<I4s", data, 20 + json_length)
    require(tag == b"BIN\0" and binary_offset + binary_length == len(data), "GLB buffer chunk")
    require(len(doc.get("meshes", [])) == 1, "one reusable mesh required")
    require(len(doc.get("materials", [])) == 1, "one material batch required")
    require(not any(doc.get(key) for key in ("skins", "animations", "images", "textures")),
            "kit must remain geometry only")
    primitives = doc["meshes"][0]["primitives"]
    require(len(primitives) == 1, "one primitive per mesh required")

    def accessor(index):
        definition = doc["accessors"][index]
        view = doc["bufferViews"][definition["bufferView"]]
        counts = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
        formats = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
        width = counts[definition["type"]]
        fmt = "<" + formats[definition["componentType"]] * width
        size = struct.calcsize(fmt)
        stride = view.get("byteStride", size)
        start = binary_offset + view.get("byteOffset", 0) + definition.get("byteOffset", 0)
        require(stride >= size and start + (definition["count"] - 1) * stride + size <= len(data),
                "accessor exceeds binary buffer")
        result = [struct.unpack_from(fmt, data, start + i * stride) for i in range(definition["count"])]
        require(all(math.isfinite(v) for row in result for v in row), "non-finite attribute")
        if definition.get("normalized") and definition["componentType"] in (5121, 5123):
            maximum = 255 if definition["componentType"] == 5121 else 65535
            result = [tuple(value / maximum for value in row) for row in result]
        return result

    primitive = primitives[0]
    require(primitive.get("mode", 4) == 4, "triangle geometry required")
    attributes = primitive["attributes"]
    require({"POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"} <= set(attributes),
            "positions, normals, UVs and facet colors required")
    points = accessor(attributes["POSITION"])
    normals = accessor(attributes["NORMAL"])
    uvs = accessor(attributes["TEXCOORD_0"])
    colors = accessor(attributes["COLOR_0"])
    indices = [row[0] for row in accessor(primitive["indices"])]
    require(len(points) == len(normals) == len(uvs), "attribute lengths differ")
    require(len(colors) == len(points), "facet color count differs")
    require(all(max(color[:3]) - min(color[:3]) < 0.01 for color in colors),
            "facet colors must be grayscale")
    require(all(0.6 <= color[0] <= 1.0 for color in colors),
            "facet colors outside readable pigment range")
    require(len(indices) % 3 == 0 and indices and min(indices) >= 0 and max(indices) < len(points),
            "invalid triangle indices")
    require(all(abs(sum(v * v for v in normal) - 1.0) < 0.001 for normal in normals),
            "non-unit mesh normals")
    for offset in range(0, len(indices), 3):
        a, b, c = [points[index] for index in indices[offset:offset + 3]]
        u = [b[i] - a[i] for i in range(3)]
        v = [c[i] - a[i] for i in range(3)]
        cross = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        require(sum(value * value for value in cross) > 1e-14, "degenerate triangle")
        require(all(sum(cross[i] * normals[index][i] for i in range(3)) > -1e-7
                    for index in indices[offset:offset + 3]), "normal opposes mesh winding")
    lower = [min(point[axis] for point in points) for axis in range(3)]
    upper = [max(point[axis] for point in points) for axis in range(3)]
    require(abs(lower[1]) < 0.0001 and all(upper[i] > lower[i] for i in range(3)),
            "ground pivot or mesh extent invalid")
    return {"triangles": len(indices) // 3, "vertices": len(points), "materials": 1,
            "mesh_primitives": 1, "bbox_min_m": lower, "bbox_max_m": upper,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "vertex_color_grayscale": True,
            "vertex_color_range": [min(color[0] for color in colors), max(color[0] for color in colors)]}


def verify(directory: Path) -> dict:
    manifest = json.loads((directory / "mineral_kit.json").read_text())
    results = {}
    for identity, asset in manifest["assets"].items():
        profiles = {}
        for profile, expected in asset["variants"].items():
            filename = expected["file_name"]
            if Path(filename).name != filename:
                raise ValueError("asset path escapes kit")
            actual = inspect_glb((directory / filename).read_bytes())
            for key, value in actual.items():
                if expected.get(key) != value:
                    raise ValueError(f"{filename}: manifest mismatch for {key}")
            if actual["triangles"] > (1800 if profile == "high" else 650):
                raise ValueError(f"{filename}: mesh budget exceeded")
            profiles[profile] = actual
        if profiles["mobile"]["triangles"] >= profiles["high"]["triangles"] * 0.65:
            raise ValueError(f"{identity}: mobile geometry does not reduce enough")
        if abs(profiles["mobile"]["bbox_max_m"][1] - profiles["high"]["bbox_max_m"][1]) > 0.001:
            raise ValueError(f"{identity}: mobile lost its main silhouette height")
        results[identity] = {profile: data["triangles"] for profile, data in profiles.items()}
    return {"status": "PASS", "assets": results, "material_surfaces_per_asset": 1,
            "physical_device_fps_verified": False}


if __name__ == "__main__":
    destination = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/kart/cavern/mineral_kit")
    print(json.dumps(verify(destination), indent=2, sort_keys=True))
