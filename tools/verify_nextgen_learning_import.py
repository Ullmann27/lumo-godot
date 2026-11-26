#!/usr/bin/env python3
"""Verify exact original learning GLB and the per-asset tangent policy."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
EXPECTED = "1694c5877f6a13144482545a53a721cd1ff62b238db7624281c5962d483023f3"


def verify():
    raw = SOURCE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        raise ValueError("Original learning GLB identity changed")
    if struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
        raise ValueError("Invalid GLB header")
    length, chunk = struct.unpack_from("<I4s", raw, 12)
    if chunk != b"JSON" or 20 + length > len(raw):
        raise ValueError("Invalid GLB JSON chunk")
    doc = json.loads(raw[20:20 + length])
    materials = doc.get("materials", [])
    uvless_morphs = 0
    primitives = 0
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            primitives += 1
            attrs = primitive["attributes"]
            if "TEXCOORD_0" not in attrs and primitive.get("targets"):
                uvless_morphs += len(primitive["targets"])
            material = materials[primitive["material"]] if "material" in primitive else {}
            extensions = material.get("extensions", {})
            # A tangent-dependent texture may not silently lose its basis.
            tangent_textures = [
                material.get("normalTexture"),
                extensions.get("KHR_materials_clearcoat", {}).get("clearcoatNormalTexture"),
                extensions.get("KHR_materials_anisotropy", {}).get("anisotropyTexture"),
            ]
            if any(tangent_textures) or extensions.get("KHR_materials_anisotropy", {}).get("anisotropyStrength", 0) > 0:
                if "TANGENT" not in attrs:
                    raise ValueError(f"{mesh.get('name')}: tangent-dependent material has no authored tangent array")
            if any("TANGENT" in target for target in primitive.get("targets", [])) and "TANGENT" not in attrs:
                raise ValueError(f"{mesh.get('name')}: tangent morph lacks a base tangent array")
    if uvless_morphs == 0:
        raise ValueError("Expected UV-less morph targets were not found")
    settings = SOURCE.with_suffix(".glb.import").read_text(encoding="utf-8")
    if "meshes/ensure_tangents=false" not in settings:
        raise ValueError("Per-asset tangent policy is not enabled")
    print(f"[LearningImport] PASS {primitives} primitives; {uvless_morphs} UV-less morph targets; original hash retained")


if __name__ == "__main__":
    verify()
