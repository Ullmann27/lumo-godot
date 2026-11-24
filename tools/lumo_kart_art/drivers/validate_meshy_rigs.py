#!/usr/bin/env python3
"""Independently evaluate exported LUMO Meshy skins and their actual movement.

This reads GLB binary accessors and evaluates glTF TRS animation and linear
blend skinning with NumPy. It does not import Blender or the rig generator.
It reports structural correctness and measured deformations; visual approval
and Android performance are separate evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import numpy as np


BONES = (
    "Root", "Pelvis", "Spine", "Chest", "Neck", "Head", "Tail",
    "UpperArm.L", "Forearm.L", "Hand.L", "Thigh.L", "Shin.L", "Foot.L", "Ear.L",
    "UpperArm.R", "Forearm.R", "Hand.R", "Thigh.R", "Shin.R", "Foot.R", "Ear.R",
    "Jaw", "Eye.L", "Eye.R", "Lid.L", "Lid.R",
)
CLIPS = (
    "idle", "kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump",
    "celebrate", "kart_celebrate", "kart_hit", "greeting_wave", "agree_nod",
    "point_portal", "card_play",
)
BODY_WEIGHTED = (
    "Pelvis", "Spine", "Chest", "Head", "UpperArm.L", "Forearm.L", "Hand.L",
    "Thigh.L", "Shin.L", "Foot.L", "UpperArm.R", "Forearm.R", "Hand.R",
    "Thigh.R", "Shin.R", "Foot.R",
)
FACE_BONES = ("Jaw", "Eye.L", "Eye.R", "Lid.L", "Lid.R")
# Each threshold applies to actual skinned vertices, not bone transforms.
VISIBLE_MOTION = {
    "kart_seated": 0.001,
    "kart_steer_left": 0.006,
    "kart_steer_right": 0.006,
    "greeting_wave": 0.035,
    "card_play": 0.020,
    "celebrate": 0.050,
    "kart_celebrate": 0.050,
}
DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
SOURCE_MANIFEST = Path("art/lumo_kart/meshy/20261123/drivers/source_manifest.json")


class GLB:
    def __init__(self, path: Path):
        self.raw = path.read_bytes()
        if len(self.raw) < 20:
            raise ValueError("Truncated GLB header")
        magic, version, length = struct.unpack_from("<4sII", self.raw)
        if magic != b"glTF" or version != 2 or length != len(self.raw):
            raise ValueError("Invalid glTF 2 header or declared length")
        chunks = {}
        cursor = 12
        while cursor < length:
            if cursor + 8 > length:
                raise ValueError("Truncated GLB chunk header")
            size, kind = struct.unpack_from("<II", self.raw, cursor)
            cursor += 8
            if size % 4 or cursor + size > length or kind in chunks:
                raise ValueError("Invalid, duplicate or truncated GLB chunk")
            chunks[kind] = self.raw[cursor:cursor + size]
            cursor += size
        self.doc = json.loads(chunks[0x4E4F534A].rstrip(b" \0"))
        self.binary = chunks.get(0x004E4942, b"")
        if any("uri" in b for b in self.doc.get("buffers", [])):
            raise ValueError("GLB references an external buffer")
        self._arrays = {}

    def array(self, index: int) -> np.ndarray:
        if index in self._arrays:
            return self._arrays[index]
        acc = self.doc["accessors"][index]
        if "sparse" in acc:
            raise ValueError("Sparse accessors are not supported by this audit")
        dtype = np.dtype(DTYPES[acc["componentType"]])
        width, count = WIDTHS[acc["type"]], acc["count"]
        if "bufferView" not in acc:
            result = np.zeros((count, width), dtype=dtype)
        else:
            view = self.doc["bufferViews"][acc["bufferView"]]
            if view.get("buffer", 0) != 0:
                raise ValueError("Expected embedded buffer zero")
            stride = view.get("byteStride", width * dtype.itemsize)
            if stride < width * dtype.itemsize:
                raise ValueError("Accessor stride is shorter than an element")
            start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            end = start + max(0, count - 1) * stride + (width * dtype.itemsize if count else 0)
            if end > view.get("byteOffset", 0) + view["byteLength"] or end > len(self.binary):
                raise ValueError("Accessor exceeds buffer view")
            result = np.ndarray((count, width), dtype=dtype, buffer=self.binary,
                                offset=start, strides=(stride, dtype.itemsize)).copy()
        if acc.get("normalized", False) and acc["componentType"] != 5126:
            limits = np.iinfo(dtype)
            result = result.astype(np.float64) / limits.max
            if limits.min < 0:
                result = np.maximum(result, -1.0)
        self._arrays[index] = result
        return result


def textured_triangle_uv_multiset(model: GLB) -> dict:
    """Fingerprint every textured triangle, independent of vertex/winding order.

    Skin fitting intentionally changes positions. UV triangle connectivity and
    multiplicity remain an independent way to verify the retained original
    surface. Canonicalizing Blender's float32 V-axis round trip avoids treating
    its floating-point round-trip changes as topology edits; no coarse UV rounding
    or approximate matching is used.
    """
    rows, vertices = [], 0
    for mesh in model.doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            material = model.doc.get("materials", [])[primitive["material"]]
            texture = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if texture is None:
                continue
            attribute = "TEXCOORD_" + str(texture.get("texCoord", 0))
            uv = model.array(primitive["attributes"][attribute]).astype("<f4")
            if uv.shape[1] != 2 or not np.isfinite(uv).all():
                raise ValueError("Invalid original-texture UV accessor")
            uv[:, 1] = np.float32(1) - np.float32(np.float32(1) - uv[:, 1])
            uv[uv == 0] = 0  # Equal coordinates must not differ by signed zero.
            vertices += len(uv)
            triangles = model.array(primitive["indices"]).reshape((-1, 3)).astype(int)
            bits = uv[triangles].view("<u4")
            order = np.lexsort((bits[:, :, 1], bits[:, :, 0]), axis=1)
            rows.append(np.take_along_axis(bits, order[:, :, None], axis=1).reshape((-1, 6)))
    if not rows:
        raise ValueError("No textured original triangles were exported")
    unique, counts = np.unique(np.concatenate(rows), axis=0, return_counts=True)
    digest = hashlib.sha256(unique.astype("<u4").tobytes()
                            + counts.astype("<i8").tobytes()).hexdigest()
    return {"textured_vertices": vertices, "textured_triangles": int(counts.sum()),
            "unique_triangle_uv_signatures": len(unique), "triangle_uv_multiset_sha256": digest}


def source_retention_evidence(path: Path, model: GLB, root: Path) -> dict | None:
    """LOD0 retains original textured topology; LOD1/2 intentionally reduce it."""
    if path.name != "driver.glb":
        return None
    manifest = json.loads((root / SOURCE_MANIFEST).read_text(encoding="utf-8"))
    entries = [entry for entry in manifest["models"] if entry["id"] == path.parent.name]
    if len(entries) != 1:
        raise ValueError("Driver has no unique immutable Meshy source entry")
    entry = entries[0]
    source = GLB(root / entry["source_file"])
    source_hash = hashlib.sha256(source.raw).hexdigest()
    if source_hash != entry["sha256"]:
        raise ValueError("Immutable Meshy source hash has changed")
    original, exported = textured_triangle_uv_multiset(source), textured_triangle_uv_multiset(model)
    extras = [node.get("extras", {}) for node in model.doc.get("nodes", [])]
    recorded_source = any(
        item.get("meshy_source_sha256") == source_hash
        and item.get("meshy_task_id") == entry["task_id"] for item in extras
    )
    return {
        "source_file": entry["source_file"], "source_sha256": source_hash,
        "meshy_task_id": entry["task_id"], "source_hash_verified": True,
        "runtime_source_metadata_matches": recorded_source,
        "source": original, "runtime": exported,
        "original_textured_triangle_uv_multiset_retained": original == exported,
        "method": "Compare the complete float32 triangle-UV multiset, including duplicate counts, after canonical V-axis round trip; new untextured eyelid geometry is excluded.",
    }


def original_part_weight_evidence(path: Path, model: GLB, root: Path) -> dict | None:
    """Follow original eye/tail/shell vertices through unambiguous source UVs.

    Testing only mixed influences misses a tail tip assigned wholly to a foot.
    The preserved LOD0 UV layout lets this check follow the actual original
    anatomical selectors, independent of exported vertex/index reordering.
    """
    if path.name != "driver.glb":
        return None
    anatomy = json.loads((root / "tools/lumo_kart_art/drivers/meshy_anatomy.json").read_text())
    config = anatomy["species"][path.parent.name]
    source = GLB(root / config["source_file"])
    primitive = source.doc["meshes"][0]["primitives"][0]

    def uv_bits(document: GLB, item: dict) -> np.ndarray:
        uv = document.array(item["attributes"]["TEXCOORD_0"]).astype("<f4")
        uv[:, 1] = np.float32(1) - np.float32(np.float32(1) - uv[:, 1])
        uv[uv == 0] = 0
        return uv.view("<u4")

    source_uv = uv_bits(source, primitive)
    source_positions = source.array(primitive["attributes"]["POSITION"])
    keys, inverse = np.unique(source_uv, axis=0, return_inverse=True)
    lower, upper = np.full((len(keys), 3), np.inf), np.full((len(keys), 3), -np.inf)
    np.minimum.at(lower, inverse, source_positions)
    np.maximum.at(upper, inverse, source_positions)
    if np.any(np.linalg.norm(upper - lower, axis=1) > 1e-6):
        raise ValueError("Source UVs map to different positions; original-part audit needs triangle correspondence")
    names = [model.doc["nodes"][index]["name"] for index in model.doc["skins"][0]["joints"]]
    exported = {}
    offset = 0
    # Match the exact node/primitive/vertex order used by Evaluator.pose.
    for node in model.doc["nodes"]:
        if "mesh" not in node:
            continue
        for item in model.doc["meshes"][node["mesh"]]["primitives"]:
            vertex_count = len(model.array(item["attributes"]["POSITION"]))
            material = model.doc["materials"][item["material"]]
            if "baseColorTexture" not in material.get("pbrMetallicRoughness", {}):
                offset += vertex_count
                continue
            uv = uv_bits(model, item)
            joints = model.array(item["attributes"]["JOINTS_0"]).astype(int)
            weights = model.array(item["attributes"]["WEIGHTS_0"]).astype(float)
            for vertex in range(len(uv)):
                influence = np.zeros(len(names))
                np.add.at(influence, joints[vertex], weights[vertex])
                exported.setdefault(tuple(uv[vertex]), []).append((offset + vertex, influence))
            offset += vertex_count
    parts = []
    for raw_side, eye in config["eyes"].items():
        if eye.get("original_vertex_indices"):
            bone = "Eye." + ("R" if raw_side == "L" else "L")
            parts.append((bone, bone, eye))
    if config["tail"].get("original_vertex_indices"):
        parts.append(("Tail", "Tail", config["tail"]))
    if config.get("rigid_shell", {}).get("original_vertex_indices"):
        parts.append(("RigidShell", config["rigid_shell"]["bone"],
                      {**config["rigid_shell"], "kind": "rigid_shell"}))
    limb_columns = [index for index, name in enumerate(names)
                    if name.startswith(("UpperArm.", "Forearm.", "Hand.", "Thigh.", "Shin.", "Foot."))]
    evidence = {}
    for part, bone, selector in parts:
        indices = selector["original_vertex_indices"]
        source_keys = {tuple(source_uv[index]) for index in indices}
        matches = [item for key in sorted(source_keys) for item in exported.get(key, [])]
        mapped = np.asarray([item[1] for item in matches])
        if not len(mapped) or any(key not in exported for key in source_keys):
            raise ValueError("An original anatomical vertex has no exported UV match: " + bone)
        expected = mapped[:, names.index(bone)]
        max_limb = float(mapped[:, limb_columns].sum(axis=1).max())
        detached_eye = bone.startswith("Eye.") and selector.get("kind") == "detached_component"
        rigid_shell = selector.get("kind") == "rigid_shell"
        evidence[part] = {
            "expected_bone": bone,
            "selector_kind": selector.get("kind"),
            "original_vertices": len(indices), "unique_source_uvs": len(source_keys),
            "matched_runtime_vertices": len(mapped),
            "minimum_expected_bone_weight": float(expected.min()),
            "mean_expected_bone_weight": float(expected.mean()),
            "maximum_expected_bone_weight": float(expected.max()),
            "maximum_unrelated_limb_weight": max_limb,
            "valid": max_limb <= 0.01
                     and float(expected.max()) > (0.5 if bone == "Tail" or detached_eye else 0.01)
                     and (not detached_eye or float(expected.min()) >= 0.95)
                     and (not rigid_shell or float(expected.min()) >= 0.999999),
        }
        if rigid_shell:
            evidence[part]["_runtime_vertex_indices"] = [item[0] for item in matches]
    return evidence


def embedded_image_evidence(model: GLB) -> list[dict]:
    images = []
    for entry in model.doc.get("images", []):
        view = model.doc["bufferViews"][entry["bufferView"]]
        offset = view.get("byteOffset", 0)
        data = model.binary[offset:offset + view["byteLength"]]
        dimensions = {}
        if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
            width, height = struct.unpack_from(">II", data, 16)
            dimensions = {"width": width, "height": height}
        images.append({"name": entry.get("name"), "mime_type": entry.get("mimeType"),
                       "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                       **dimensions})
    return images


def trs(translation, quaternion, scale) -> np.ndarray:
    x, y, z, w = quaternion
    matrix = np.eye(4, dtype=np.float64)
    matrix[:3, :3] = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]) @ np.diag(scale)
    matrix[:3, 3] = translation
    return matrix


def local_matrix(node: dict, overrides: dict | None = None) -> np.ndarray:
    if "matrix" in node:
        if overrides:
            raise ValueError("Animation targets a matrix-only node")
        return np.asarray(node["matrix"], dtype=float).reshape((4, 4), order="F")
    values = dict(node)
    values.update(overrides or {})
    return trs(values.get("translation", [0, 0, 0]), values.get("rotation", [0, 0, 0, 1]),
               values.get("scale", [1, 1, 1]))


def slerp(a: np.ndarray, b: np.ndarray, fraction: float) -> np.ndarray:
    dot = float(np.dot(a, b))
    if dot < 0:
        b, dot = -b, -dot
    dot = min(1.0, max(-1.0, dot))
    if dot > 0.9995:
        value = a * (1 - fraction) + b * fraction
        return value / np.linalg.norm(value)
    angle = math.acos(dot)
    return (math.sin((1 - fraction) * angle) * a + math.sin(fraction * angle) * b) / math.sin(angle)


class Evaluator:
    def __init__(self, model: GLB):
        self.model, self.doc = model, model.doc
        self.nodes = self.doc["nodes"]
        self.parents = {}
        for parent, node in enumerate(self.nodes):
            for child in node.get("children", []):
                if child in self.parents or not 0 <= child < len(self.nodes):
                    raise ValueError("Invalid or multiply-parented scene node")
                self.parents[child] = parent
        self.rest = self.world({})
        self.skin = self.doc["skins"][0]
        self.joints = self.skin["joints"]
        if len(set(self.joints)) != len(self.joints):
            raise ValueError("Duplicate skin joints")
        self.names = [self.nodes[index]["name"] for index in self.joints]
        raw = model.array(self.skin["inverseBindMatrices"]).astype(float)
        self.binds = np.transpose(raw.reshape((-1, 4, 4)), (0, 2, 1))
        if len(self.binds) != len(self.joints) or not np.isfinite(self.binds).all():
            raise ValueError("Invalid inverse-bind matrix count or values")
        if np.min(np.abs(np.linalg.det(self.binds))) < 1e-12:
            raise ValueError("Singular inverse-bind matrix")
        self.primitives = []
        for node_index, node in enumerate(self.nodes):
            if "mesh" not in node:
                continue
            if node.get("skin") != 0:
                raise ValueError("Visible mesh is not bound to the single driver skin")
            for primitive in self.doc["meshes"][node["mesh"]]["primitives"]:
                attrs = primitive["attributes"]
                if "JOINTS_0" not in attrs or "WEIGHTS_0" not in attrs:
                    raise ValueError("Visible primitive has no skin attributes")
                if "JOINTS_1" in attrs or "WEIGHTS_1" in attrs:
                    raise ValueError("More than four exported skin influences")
                positions = model.array(attrs["POSITION"]).astype(float)
                joints = model.array(attrs["JOINTS_0"]).astype(int)
                weights = model.array(attrs["WEIGHTS_0"]).astype(float)
                if len(positions) != len(joints) or joints.shape != weights.shape or joints.shape[1] != 4:
                    raise ValueError("Mismatched skin attribute dimensions")
                if np.any(joints < 0) or np.any(joints >= len(self.joints)):
                    raise ValueError("Skin index is outside the joint table")
                if not np.isfinite(positions).all() or not np.isfinite(weights).all() or np.any(weights < 0):
                    raise ValueError("Invalid positions or skin weights")
                if np.max(np.abs(weights.sum(1) - 1.0)) > 0.002:
                    raise ValueError("Vertex weights are not normalized")
                indices = model.array(primitive["indices"]).ravel().astype(int)
                if len(indices) % 3 or indices.min() < 0 or indices.max() >= len(positions):
                    raise ValueError("Invalid triangle indices")
                self.primitives.append({"node": node_index, "positions": positions,
                                        "joints": joints, "weights": weights, "indices": indices})

    def world(self, overrides: dict) -> list[np.ndarray]:
        worlds, visiting = {}, set()

        def visit(index):
            if index in worlds:
                return worlds[index]
            if index in visiting:
                raise ValueError("Scene hierarchy contains a cycle")
            visiting.add(index)
            parent = visit(self.parents[index]) if index in self.parents else np.eye(4)
            worlds[index] = parent @ local_matrix(self.nodes[index], overrides.get(index))
            visiting.remove(index)
            return worlds[index]

        return [visit(index) for index in range(len(self.nodes))]

    def pose(self, animation: dict | None, time: float = 0.0):
        overrides = {}
        if animation:
            for channel in animation["channels"]:
                sampler = animation["samplers"][channel["sampler"]]
                target = channel["target"]
                times = self.model.array(sampler["input"]).ravel()
                values = self.model.array(sampler["output"]).astype(float)
                method = sampler.get("interpolation", "LINEAR")
                if method not in {"LINEAR", "STEP"}:
                    raise ValueError("Audit requires sampled LINEAR or STEP animation")
                if len(times) != len(values) or not len(times):
                    raise ValueError("Animation key counts differ")
                lower = int(np.clip(np.searchsorted(times, time, side="right") - 1, 0, len(times) - 1))
                upper = min(lower + 1, len(times) - 1)
                fraction = float(np.clip((time - times[lower]) / (times[upper] - times[lower]), 0, 1)) if lower != upper else 0.0
                if method == "STEP" or lower == upper:
                    value = values[lower]
                elif target["path"] == "rotation":
                    value = slerp(values[lower], values[upper], fraction)
                else:
                    value = values[lower] * (1 - fraction) + values[upper] * fraction
                overrides.setdefault(target["node"], {})[target["path"]] = value
        worlds = self.world(overrides)
        matrices = np.asarray([worlds[joint] @ self.binds[index] for index, joint in enumerate(self.joints)])
        vertices = []
        for primitive in self.primitives:
            homogeneous = np.column_stack((primitive["positions"], np.ones(len(primitive["positions"]))))
            output = np.zeros((len(homogeneous), 4), dtype=np.float64)
            for influence in range(4):
                transformed = np.einsum("nij,nj->ni", matrices[primitive["joints"][:, influence]], homogeneous)
                output += transformed * primitive["weights"][:, influence, None]
            vertices.append(output[:, :3])
        return np.concatenate(vertices), worlds

    def bone_vertex_weights(self) -> np.ndarray:
        arrays = []
        for primitive in self.primitives:
            out = np.zeros((len(primitive["positions"]), len(self.joints)), dtype=np.float64)
            row = np.arange(len(out))
            for influence in range(4):
                np.add.at(out, (row, primitive["joints"][:, influence]), primitive["weights"][:, influence])
            arrays.append(out)
        return np.concatenate(arrays)


def inspect(path: Path, root: Path) -> dict:
    errors = []
    model = GLB(path)
    doc = model.doc
    if len(doc.get("skins", [])) != 1:
        raise ValueError("Expected exactly one exported skin")
    if any("uri" in image for image in doc.get("images", [])):
        raise ValueError("A material image is not embedded")
    source_evidence = source_retention_evidence(path, model, root)
    if source_evidence is not None:
        if not source_evidence["runtime_source_metadata_matches"]:
            errors.append("Runtime Meshy source hash/task metadata does not match the immutable original")
        if not source_evidence["original_textured_triangle_uv_multiset_retained"]:
            errors.append("LOD0 original textured vertex count or complete triangle-UV multiset changed")
    original_parts = original_part_weight_evidence(path, model, root)
    if original_parts:
        for name, evidence in original_parts.items():
            if not evidence["valid"]:
                errors.append("Original anatomical vertices are not correctly weighted: " + name)
    images = embedded_image_evidence(model)
    evaluator = Evaluator(model)
    if set(evaluator.names) != set(BONES) or len(evaluator.names) != len(BONES):
        errors.append("Driver skeleton must contain exactly the 26 contract bones")
    animations = doc.get("animations", [])
    names = [a.get("name", "") for a in animations]
    if set(names) != set(CLIPS) or len(names) != len(CLIPS):
        errors.append("Expected exactly the 12 runtime animation clips")
    weighted = evaluator.bone_vertex_weights()
    bone_counts = {name: int(np.count_nonzero(weighted[:, index] > 0.01))
                   for index, name in enumerate(evaluator.names)}
    # Hands in a source A-pose can sit at hip height. A height-only leg mask
    # then silently attaches the forearm to the thigh; animation channels and
    # normalized weights remain valid, but waving pulls long mesh spikes.
    arm_columns = [index for index, name in enumerate(evaluator.names)
                   if name.startswith(("UpperArm.", "Forearm.", "Hand."))]
    leg_columns = [index for index, name in enumerate(evaluator.names)
                   if name.startswith(("Thigh.", "Shin.", "Foot."))]
    mixed_arm_leg = ((weighted[:, arm_columns].sum(axis=1) > 0.10)
                     & (weighted[:, leg_columns].sum(axis=1) > 0.10))
    mixed_arm_leg_count = int(np.count_nonzero(mixed_arm_leg))
    if mixed_arm_leg_count:
        errors.append(f"{mixed_arm_leg_count} vertices blend unrelated arm and leg bones above 10% each")
    tail_column = evaluator.names.index("Tail") if "Tail" in evaluator.names else None
    tail_limb_count = 0
    if tail_column is not None:
        tail_limb_count = int(np.count_nonzero(
            (weighted[:, tail_column] > 0.10)
            & (weighted[:, arm_columns + leg_columns].sum(axis=1) > 0.10)
        ))
        if tail_limb_count:
            errors.append(f"{tail_limb_count} vertices blend tail and unrelated limb bones above 10% each")
    for name in BODY_WEIGHTED:
        if bone_counts.get(name, 0) == 0:
            errors.append("Body bone has no visible skin influence: " + name)
    bind_positions, _ = evaluator.pose(None)
    source_positions = []
    for primitive in evaluator.primitives:
        points = np.column_stack((primitive["positions"], np.ones(len(primitive["positions"]))))
        source_positions.append((evaluator.rest[primitive["node"]] @ points.T).T[:, :3])
    bind_error = float(np.linalg.norm(bind_positions - np.concatenate(source_positions), axis=1).max())
    if bind_error > 0.0002:
        errors.append("Inverse bind transforms alter neutral skin by over 0.2 mm")
    # A finite envelope alone does not reveal badly stretched elbow/hip seams.
    # Record deformation of actual topology relative to its neutral bind skin.
    edges = []
    offset = 0
    for primitive in evaluator.primitives:
        triangles = primitive["indices"].reshape((-1, 3)) + offset
        edges.append(np.concatenate((triangles[:, [0, 1]], triangles[:, [1, 2]], triangles[:, [2, 0]])))
        offset += len(primitive["positions"])
    edges = np.unique(np.sort(np.concatenate(edges), axis=1), axis=0)
    bind_lengths = np.linalg.norm(bind_positions[edges[:, 0]] - bind_positions[edges[:, 1]], axis=1)
    valid_edges = bind_lengths > 0.00001
    edges, bind_lengths = edges[valid_edges], bind_lengths[valid_edges]
    shell_vertices = (original_parts or {}).get("RigidShell", {}).pop("_runtime_vertex_indices", [])
    shell_mask = np.zeros(len(bind_positions), dtype=bool)
    shell_mask[shell_vertices] = True
    shell_edges = np.flatnonzero(np.all(shell_mask[edges], axis=1))
    shell_maximum_edge_error = 0.0
    if shell_vertices and not len(shell_edges):
        errors.append("Original rigid shell has no preserved interior topology edges")
    report_clips = []
    expected_targets = {(node, path) for node in evaluator.joints for path in ("translation", "rotation", "scale")}
    for animation in animations:
        name = animation["name"]
        targets = [(c["target"]["node"], c["target"]["path"]) for c in animation["channels"]]
        if len(targets) != 78 or set(targets) != expected_targets:
            errors.append(name + ": expected 78 unique bone T/R/S channels")
        duration = 0.0
        for sampler in animation["samplers"]:
            times = model.array(sampler["input"]).ravel()
            values = model.array(sampler["output"])
            if not np.isfinite(times).all() or not np.isfinite(values).all() or not len(times):
                raise ValueError(name + ": invalid animation data")
            if np.any(np.diff(times) <= 0) or times[0] < 0:
                raise ValueError(name + ": unordered or negative sample times")
            duration = max(duration, float(times[-1]))
        if duration <= 0.0:
            errors.append(name + ": clip has zero duration")
        for channel in animation["channels"]:
            if channel["target"]["path"] == "rotation":
                values = model.array(animation["samplers"][channel["sampler"]]["output"])
                if np.max(np.abs(np.linalg.norm(values, axis=1) - 1)) > 0.002:
                    errors.append(name + ": quaternion is not unit length")
        initial, initial_worlds = evaluator.pose(animation, 0.0)
        displacement = np.zeros(len(initial))
        maximum_edge_stretch = np.ones(len(edges))
        shell_clip_edge_error = 0.0
        head_index = evaluator.joints[evaluator.names.index("Head")]
        initial_local = (np.linalg.inv(initial_worlds[head_index]) @ np.column_stack(
            (initial, np.ones(len(initial)))).T).T[:, :3]
        head_relative_displacement = np.zeros(len(initial))
        lower = np.full(3, np.inf)
        upper = np.full(3, -np.inf)
        hand_error = foot_error = 0.0
        for fraction in (0.0, 0.1, 0.25, 0.4, 0.5, 0.65, 0.75, 0.9, 1.0):
            vertices, worlds = evaluator.pose(animation, duration * fraction)
            if not np.isfinite(vertices).all():
                raise ValueError(name + ": non-finite evaluated skin")
            lower = np.minimum(lower, vertices.min(0))
            upper = np.maximum(upper, vertices.max(0))
            displacement = np.maximum(displacement, np.linalg.norm(vertices - initial, axis=1))
            edge_lengths = np.linalg.norm(vertices[edges[:, 0]] - vertices[edges[:, 1]], axis=1)
            edge_ratios = edge_lengths / bind_lengths
            maximum_edge_stretch = np.maximum(maximum_edge_stretch, edge_ratios)
            if len(shell_edges):
                shell_clip_edge_error = max(
                    shell_clip_edge_error, float(np.max(np.abs(edge_ratios[shell_edges] - 1.0))))
            head_local = (np.linalg.inv(worlds[head_index]) @ np.column_stack(
                (vertices, np.ones(len(vertices)))).T).T[:, :3]
            head_relative_displacement = np.maximum(
                head_relative_displacement, np.linalg.norm(head_local - initial_local, axis=1))
            if name == "kart_seated":
                for side, sign in (("L", -1.0), ("R", 1.0)):
                    hand_index = evaluator.joints[evaluator.names.index("Hand." + side)]
                    foot_index = evaluator.joints[evaluator.names.index("Foot." + side)]
                    hand_error = max(hand_error, float(np.linalg.norm(worlds[hand_index][:3, 3] - [sign * .16, 1.055, -.34])))
                    foot_error = max(foot_error, float(np.linalg.norm(worlds[foot_index][:3, 3] - [sign * .18, .80, -.24])))
        if np.max(np.abs(np.concatenate((lower, upper)))) > 4.0:
            errors.append(name + ": evaluated skin escapes the four-metre driver envelope")
        p95 = float(np.quantile(displacement, .95))
        if name in VISIBLE_MOTION and p95 < VISIBLE_MOTION[name]:
            errors.append(name + ": insufficient visible skin motion (95th percentile %.6f m)" % p95)
        if name == "kart_seated" and (hand_error > .002 or foot_error > .001):
            errors.append(name + ": grip or pedal contact differs from the runtime contract")
        shell_maximum_edge_error = max(shell_maximum_edge_error, shell_clip_edge_error)
        if shell_clip_edge_error > 0.002:
            errors.append(name + ": original rigid shell edge length changes by over 0.2%")
        regional_motion = {}
        facial_motion = {}
        for index, bone in enumerate(evaluator.names):
            region = weighted[:, index] > .25
            regional_motion[bone] = float(np.quantile(displacement[region], .95)) if np.any(region) else None
            if bone in FACE_BONES:
                face_region = weighted[:, index] > .05
                facial_motion[bone] = (
                    float(np.quantile(head_relative_displacement[face_region], .95))
                    if np.any(face_region) else None)
        for bone in ("Hand.R",) if name in ("greeting_wave", "card_play", "point_portal", "celebrate", "kart_celebrate") else ():
            if (regional_motion.get(bone) or 0.0) < .035:
                errors.append(name + ": visible right hand does not follow its gesture")
        report_clips.append({"name": name, "seconds": duration, "channels": len(targets),
                             "sample_count": 9, "maximum_vertex_motion_m": float(displacement.max()),
                             "p95_vertex_motion_m": p95,
                             "maximum_edge_stretch_ratio": float(maximum_edge_stretch.max()),
                             "p99_edge_stretch_ratio": float(np.quantile(maximum_edge_stretch, .99)),
                             "rigid_shell_maximum_edge_length_relative_error": shell_clip_edge_error if len(shell_edges) else None,
                             "weighted_region_p95_motion_m": regional_motion,
                             "head_relative_facial_p95_motion_m": facial_motion,
                             "skin_bounds_min_m": lower.tolist(), "skin_bounds_max_m": upper.tolist(),
                             "seated_hand_error_m": hand_error if name == "kart_seated" else None,
                             "seated_foot_error_m": foot_error if name == "kart_seated" else None})
    if shell_vertices:
        original_parts["RigidShell"]["interior_edges_evaluated"] = len(shell_edges)
        original_parts["RigidShell"]["maximum_edge_length_relative_error"] = shell_maximum_edge_error
        original_parts["RigidShell"]["rigid_across_all_clips"] = shell_maximum_edge_error <= 0.002
    by_clip = {clip["name"]: clip for clip in report_clips}
    face_evidence = {}
    for bone in FACE_BONES:
        clip = "celebrate" if bone == "Jaw" else "kart_seated"
        amount = by_clip.get(clip, {}).get("head_relative_facial_p95_motion_m", {}).get(bone)
        face_evidence[bone] = {
            "weighted_vertices": bone_counts.get(bone, 0), "clip": clip,
            "p95_movement_relative_to_head_m": amount,
            "has_measured_deformation": amount is not None and amount > 0.0001,
        }
    return {
        "path": path.relative_to(root).as_posix() if path.is_relative_to(root) else str(path),
        "sha256": hashlib.sha256(model.raw).hexdigest(), "bytes": len(model.raw),
        "triangles": sum(len(p["indices"]) // 3 for p in evaluator.primitives),
        "vertices": int(len(weighted)), "skins": 1, "bones": evaluator.names,
        "embedded_images": images,
        "non_image_bytes": len(model.raw) - sum(item["bytes"] for item in images),
        "source_retention": source_evidence,
        "original_part_weights": original_parts,
        "weighted_vertices_by_bone": bone_counts,
        "unrelated_arm_leg_blend_vertices": mixed_arm_leg_count,
        "unrelated_tail_limb_blend_vertices": tail_limb_count,
        "facial_deformation_evidence": face_evidence,
        "max_weight_sum_error": float(np.max(np.abs(weighted.sum(1) - 1.0))),
        "maximum_influences": int(np.max(np.count_nonzero(weighted > 0, axis=1))),
        "neutral_skin_bind_error_m": bind_error, "clips": report_clips,
        "errors": sorted(set(errors)), "passed": not errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    paths = args.paths or sorted((root / "assets/kart/production/drivers").glob("*/driver*.glb"))
    results = []
    for path in paths:
        absolute = path.resolve() if path.is_absolute() else (root / path).resolve()
        try:
            result = inspect(absolute, root)
        except Exception as exc:
            result = {"path": str(path), "passed": False, "errors": [str(exc)]}
            if absolute.is_file():
                data = absolute.read_bytes()
                result.update({"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
                try:
                    source = GLB(absolute).doc
                    result.update({"skins": len(source.get("skins", [])),
                                   "animation_count": len(source.get("animations", []))})
                except (ValueError, KeyError, struct.error, json.JSONDecodeError):
                    pass
        results.append(result)
        print(("PASS" if result["passed"] else "FAIL"), result["path"], "; ".join(result["errors"]), flush=True)
    passed = bool(results) and all(item["passed"] for item in results)
    report = {"schema_version": 1, "method": "Independent GLB accessor decoding, glTF TRS sampling and linear blend skin evaluation",
              "visual_review": False, "physical_android_test": False, "asset_count": len(results),
              "passed": passed, "assets": results}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
