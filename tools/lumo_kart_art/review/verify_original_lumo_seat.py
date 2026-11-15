#!/usr/bin/env python3
"""Check evaluated Original-Lumo leg/foot skin against each frozen Blender kart.

Run with Blender after kart_production_lumo_seat_regression.gd. The Godot gate
records real skin vertices for every sample; this gate intersects those triangles
with the original authored coachwork and seat instead of reusing IK targets.
"""
import hashlib
import json
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/lumo_kart_art/review"))
sys.path.insert(0, str(ROOT / "tools/lumo_kart_art/karts"))
from check_original_lumo_surfaces import check
from inspect_mechanics import evaluated_surface


def main():
    source = ROOT / "evidence/lumo_kart_runtime/karts/original_lumo_seat_contacts.json"
    contacts = json.loads(source.read_text())
    results = []
    sources = {}
    for variant in ("comet", "glider", "turbo"):
        model = ROOT / f"art/lumo_kart/blender/karts/aurora_{variant}.blend"
        sources[str(model.relative_to(ROOT))] = hashlib.sha256(model.read_bytes()).hexdigest()
        bpy.ops.wm.open_mainfile(filepath=str(model))
        bpy.context.scene.frame_set(1)
        coachwork = bpy.data.objects["Coachwork"]
        body, names = evaluated_surface([o for o in coachwork.children_recursive if o.type == "MESH"])
        seat, seat_names = evaluated_surface([bpy.data.objects["BucketSeatShell"]])
        for sample in contacts["samples"]:
            if sample["variant"] != variant:
                continue
            geometry = Path(sample["geometry"])
            checks = check(json.loads(geometry.read_text()), body, names, seat, seat_names)
            results.append({"variant": variant, "phase": sample["phase"], "seconds": sample["seconds"],
                            "geometry_sha256": hashlib.sha256(geometry.read_bytes()).hexdigest(),
                            "intersection_pairs": sum(r["intersection_pairs"] for r in checks),
                            "checks": checks})
    passed = contacts["status"] == "PASS" and len(results) == 54 and all(r["intersection_pairs"] == 0 for r in results)
    report = {"status": "PASS" if passed else "FAIL", "sample_count": len(results),
              "method": "Godot-evaluated, bone-weighted foot/leg triangles against unmodified Blender coachwork and bucket-seat shell triangles; BVH overlap. Includes leg/foot transition triangles.",
              "contacts_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "sources": sources, "samples": results}
    target = ROOT / "evidence/lumo_kart_runtime/karts/original_lumo_seat_clearance.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "samples": len(results),
                      "colliding_samples": [{"variant": r["variant"], "phase": r["phase"], "seconds": r["seconds"],
                                             "pairs": r["intersection_pairs"], "parts": [c["kart_parts"] for c in r["checks"]]}
                                            for r in results if r["intersection_pairs"]]}))
    if not passed:
        raise RuntimeError("Original Lumo seat-contact gate failed; see original_lumo_seat_clearance.json")


if __name__ == "__main__":
    main()
