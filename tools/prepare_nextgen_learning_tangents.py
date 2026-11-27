#!/usr/bin/env python3
"""Prepare the recovered learning actor without changing its original GLB.

Godot 4.6 forces tangent calculation on UV-less morph targets even though
the base surface has a fallback tangent. Author a valid orthogonal basis
only for those untextured surfaces. UV-bearing surfaces keep Godot's
normal MikkTSpace path. All source payloads, materials and animations are
preserved; only new accessor data and references are appended.
"""
import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "art/recovered/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
RUNTIME = ROOT / "assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
SOURCE_SHA = "1694c5877f6a13144482545a53a721cd1ff62b238db7624281c5962d483023f3"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(raw):
    if len(raw) < 28 or struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
        raise ValueError("Invalid GLB 2 header")
    size, tag = struct.unpack_from("<I4s", raw, 12)
    offset = 20 + size
    if tag != b"JSON" or offset + 8 > len(raw) or size % 4:
        raise ValueError("Invalid GLB JSON chunk")
    length, tag = struct.unpack_from("<I4s", raw, offset)
    if tag != b"BIN\x00" or offset + 8 + length != len(raw) or length % 4:
        raise ValueError("Expected exactly one GLB binary chunk")
    doc = json.loads(raw[20:offset])
    if len(doc["buffers"]) != 1 or "uri" in doc["buffers"][0]:
        raise ValueError("External or multiple buffers are unsupported")
    binary = raw[offset + 8:]
    used = doc["buffers"][0]["byteLength"]
    if not 0 <= len(binary) - used <= 3:
        raise ValueError("Invalid binary buffer size")
    return doc, binary[:used]


def read_normals(doc, binary, index):
    a = doc["accessors"][index]
    if a["componentType"] != 5126 or a["type"] != "VEC3" or a.get("normalized"):
        raise ValueError("Expected float VEC3 normal accessor")
    count = a["count"]
    if not 0 < count <= 1_000_000:
        raise ValueError("Invalid normal count")
    views = doc["bufferViews"]
    def read(view_id, offset, number, fmt, stride=None):
        v = views[view_id]
        size = struct.calcsize(fmt)
        stride = stride or v.get("byteStride", size)
        begin = v.get("byteOffset", 0) + offset
        end = begin + (number - 1) * stride + size if number else begin
        if v["buffer"] != 0 or stride < size or offset < 0 or end > min(len(binary), v.get("byteOffset", 0) + v["byteLength"]):
            raise ValueError("Accessor exceeds its bufferView")
        return [struct.unpack_from(fmt, binary, begin + i * stride) for i in range(number)]
    values = (read(a["bufferView"], a.get("byteOffset", 0), count, "<3f")
              if "bufferView" in a else [(0.0, 0.0, 0.0)] * count)
    sparse = a.get("sparse")
    if sparse:
        si, sv = sparse["indices"], sparse["values"]
        fmt = {5121: "<B", 5123: "<H", 5125: "<I"}[si["componentType"]]
        indices = read(si["bufferView"], si.get("byteOffset", 0), sparse["count"], fmt)
        replacements = read(sv["bufferView"], sv.get("byteOffset", 0), sparse["count"], "<3f")
        last = -1
        for (i,), normal in zip(indices, replacements):
            if not last < i < count:
                raise ValueError("Invalid sparse normal index")
            values[i] = normal
            last = i
    return values


def basis(normal):
    if not all(math.isfinite(n) for n in normal):
        raise ValueError("Nonfinite source normal")
    length = math.sqrt(sum(n*n for n in normal))
    if length < 1e-8:
        raise ValueError("Zero source normal")
    x, y, z = (n / length for n in normal)
    axis = min(range(3), key=lambda i: abs((x, y, z)[i]))
    t = ((0.0, -z, y), (z, 0.0, -x), (-y, x, 0.0))[axis]
    l = math.sqrt(sum(v*v for v in t))
    return (*(v / l for v in t), 1.0)


def uses_tangent_texture(material):
    ext = material.get("extensions", {})
    return bool(material.get("normalTexture")
                or ext.get("KHR_materials_clearcoat", {}).get("clearcoatNormalTexture")
                or ext.get("KHR_materials_anisotropy", {}).get("anisotropyTexture")
                or ext.get("KHR_materials_anisotropy", {}).get("anisotropyStrength", 0) > 0)


def prepare(raw):
    doc, original_binary = unpack(raw)
    out = copy.deepcopy(doc)
    binary = bytearray(original_binary)
    materials = out.get("materials", [])
    patched = []
    textured = 0
    for mi, mesh in enumerate(out["meshes"]):
        for pi, primitive in enumerate(mesh["primitives"]):
            attrs = primitive["attributes"]
            material = materials[primitive["material"]] if "material" in primitive else {}
            needed = uses_tangent_texture(material)
            if needed:
                textured += 1
                if "TEXCOORD_0" not in attrs or "NORMAL" not in attrs:
                    raise ValueError(f"Textured primitive {mi}/{pi} lacks UV0 or normals")
            if primitive.get("mode", 4) != 4 or not primitive.get("targets"):
                continue
            if "TANGENT" in attrs or "TEXCOORD_0" in attrs or "NORMAL" not in attrs:
                continue
            if needed:
                raise ValueError("Cannot assign fallback tangent to a textured surface")
            normals = read_normals(doc, original_binary, attrs["NORMAL"])
            if len(normals) != doc["accessors"][attrs["POSITION"]]["count"]:
                raise ValueError("Position/normal count mismatch")
            binary.extend(b"\x00" * (-len(binary) % 4))
            start = len(binary)
            for n in normals:
                binary.extend(struct.pack("<4f", *basis(n)))
            view = len(out["bufferViews"])
            out["bufferViews"].append({"buffer": 0, "byteOffset": start,
                                        "byteLength": len(normals) * 16, "target": 34962})
            ai = len(out["accessors"])
            out["accessors"].append({"bufferView": view, "componentType": 5126,
                                     "count": len(normals), "type": "VEC4"})
            attrs["TANGENT"] = ai
            patched.append({"mesh": mi, "primitive": pi, "vertices": len(normals),
                            "morphs": len(primitive["targets"]), "accessor": ai})
    if not patched:
        raise ValueError("Expected at least one UV-less morph primitive")
    if not textured:
        raise ValueError("Expected original tangent-dependent material")
    out["buffers"][0]["byteLength"] = len(binary)
    # Prove that the generator did not change any original payload, material,
    # geometry accessor, animation, skeleton, or morph target.
    restored = copy.deepcopy(out)
    for item in patched:
        del restored["meshes"][item["mesh"]]["primitives"][item["primitive"]]["attributes"]["TANGENT"]
    restored["bufferViews"] = restored["bufferViews"][:len(doc["bufferViews"])]
    restored["accessors"] = restored["accessors"][:len(doc["accessors"])]
    restored["buffers"][0]["byteLength"] = doc["buffers"][0]["byteLength"]
    if restored != doc or bytes(binary[:len(original_binary)]) != original_binary:
        raise ValueError("Original GLB data changed")
    json_bytes = json.dumps(out, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")
    json_bytes += b" " * (-len(json_bytes) % 4)
    binary.extend(b"\x00" * (-len(binary) % 4))
    result = (struct.pack("<4sII", b"glTF", 2, 28 + len(json_bytes) + len(binary))
              + struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
              + struct.pack("<I4s", len(binary), b"BIN\x00") + binary)
    return result, {"source_sha256": sha(raw), "runtime_sha256": sha(result),
                    "source_bytes": len(raw), "runtime_bytes": len(result),
                    "textured_primitives": textured, "patched": patched}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    raw = ORIGINAL.read_bytes()
    if sha(raw) != SOURCE_SHA:
        raise ValueError("Original actor SHA-256 changed")
    result, proof = prepare(raw)
    if args.write:
        RUNTIME.write_bytes(result)
    elif RUNTIME.read_bytes() != result:
        raise ValueError("Runtime actor is not the deterministic prepared asset")
    print("[LearningTangents] " + json.dumps(proof, sort_keys=True))


if __name__ == "__main__":
    main()
