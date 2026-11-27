#!/usr/bin/env python3
"""Validate the original and deterministic runtime actor; preserve texture maps."""
from prepare_nextgen_learning_tangents import ORIGINAL, RUNTIME, SOURCE_SHA, prepare, sha


def verify():
    original = ORIGINAL.read_bytes()
    if sha(original) != SOURCE_SHA:
        raise ValueError("Original GLB SHA-256 changed")
    expected, proof = prepare(original)
    if RUNTIME.read_bytes() != expected:
        raise ValueError("Prepared runtime GLB identity mismatch")
    settings = RUNTIME.with_suffix(".glb.import").read_text(encoding="utf-8")
    if "meshes/ensure_tangents=true" not in settings:
        raise ValueError("Normal-mapped surfaces must keep tangent generation")
    print(f"[LearningImport] PASS {len(proof['patched'])} repaired primitives; {proof['textured_primitives']} textured primitives preserved")


if __name__ == "__main__":
    verify()
