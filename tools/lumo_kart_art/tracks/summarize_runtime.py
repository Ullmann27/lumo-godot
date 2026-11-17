#!/usr/bin/env python3
"""Summarize actual runtime regression evidence and verify immutable Blender delivery."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "evidence/lumo_kart_art/tracks"
RUNTIME = EVIDENCE / "runtime"
SHAPES = ("portal_entry", "straight_12m", "portal_exit")
SUFFIXES = ("", "_lod1", "_collision", "_terrain", "_terrain_lod1")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def main():
    frozen = read(EVIDENCE / "production_summary.json")
    checks = {}
    for relative, record in frozen["frozen_files"].items():
        path = ROOT / relative
        checks[relative] = path.exists() and sha256(path) == record["sha256"]
    assets = []
    for theme in frozen["themes"]:
        for shape in SHAPES:
            for suffix in SUFFIXES:
                relative = f"assets/kart/production/tracks/{theme['theme']}/{shape}{suffix}.glb"
                assets.append({"path": relative, **frozen["frozen_files"][relative]})
    mobile = read(RUNTIME / "physics_all_mobile.json")
    full = read(RUNTIME / "physics_all_full.json")
    visual = read(RUNTIME / "visible_clearance_all.json")
    native_visual = read(RUNTIME / "visual_qa.json") if (RUNTIME / "visual_qa.json").exists() else None
    code_paths = (
        "scripts/games/kart_world.gd",
        "scripts/games/kart_production_tunnel_layout.gd",
        "scripts/games/kart_production_tunnel_mesh.gd",
        "scripts/games/kart_production_tunnels.gd",
        "scripts/tests/kart_production_tunnel_layout_regression.gd",
        "scripts/tests/kart_production_tunnel_physics_regression.gd",
        "scripts/tests/kart_production_tunnel_visual_clearance.gd",
        "scripts/tests/kart_production_tunnel_lighting_probe.gd",
    )
    records = mobile["tracks"] + full["tracks"]
    summary = {
        "status": "PASS" if all(checks.values()) and mobile["passed"] and full["passed"] and visual["passed"] else "FAIL",
        "scope": "Actual game world construction, real physics and visible warped triangles; APK/device tests are separate",
        "frozen_asset_count": len(checks),
        "frozen_assets_byte_identical": all(checks.values()),
        "modified_frozen_files": [path for path, equal in checks.items() if not equal],
        "runtime_glb_count": len(assets),
        "runtime_glb_bytes": sum(asset["bytes"] for asset in assets),
        "unused_authoring_glb_count": frozen["glb_count"] - len(assets),
        "runtime_assets": assets,
        "themes_tested_in_each_detail_mode": len(mobile["tracks"]),
        "physics_world_builds": len(records),
        "free_kart_capsule_sweeps": sum(record["free_capsule_sweeps"] for record in records),
        "free_road_camera_rays": sum(record["free_road_camera_rays"] for record in records),
        "wall_roof_slide_contacts": sum(len(record["contacts"]) for record in records),
        "visible_clear_cross_sections": sum(record["clear_cross_sections"] for record in visual["records"]),
        "maximum_socket_error_m": max(record["socket_position_error_m"] for record in records),
        "maximum_joint_error_m": max(record["joint_position_error_m"] for record in records),
        "maximum_joint_rotation_error_rad": max(record["joint_rotation_error_rad"] for record in records),
        "capsule": {"radius_m": 0.85, "height_m": 2.0, "origin": "kart feet", "center_offset_y_m": 1.0},
        "camera_sphere_radius_m": 0.20,
        "world_layouts": [{"track": record["track"], "start": record["statistics"]["start"],
                          "end": record["statistics"]["end"], "modules": record["statistics"]["module_count"],
                          "mobile_triangles": record["statistics"]["triangles"],
                          "collision_triangles": record["statistics"]["collision_triangles"]}
                         for record in mobile["tracks"]],
        "evidence": {path.name: sha256(path) for path in
                     (RUNTIME / "physics_all_mobile.json", RUNTIME / "physics_all_full.json",
                      RUNTIME / "visible_clearance_all.json")},
        "source_snapshot": {path: sha256(ROOT / path) for path in code_paths},
        "source_snapshot_semantics": "Final delivery snapshot; geometry/physics checks precede the Volcano-only local lighting correction. Separate light probes and native recapture validate that later change.",
        "physical_android_device_fps_measured": False,
    }
    if native_visual is not None:
        summary["native_visual_review"] = {
            "status": native_visual["status"],
            "reviewed_current_images": native_visual["reviewed_images"],
            "manual_image_inspections": native_visual.get("manual_image_inspections", native_visual["reviewed_images"]),
            "report": "evidence/lumo_kart_art/tracks/runtime/visual_qa.json",
            "sha256": sha256(RUNTIME / "visual_qa.json"),
            "volcano_light_profile": native_visual.get("lighting_correction", {}),
        }
        if native_visual["status"] != "PASS":
            summary["status"] = "FAIL"
    destination = RUNTIME / "runtime_summary.json"
    destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in summary.items()
                      if key not in ("runtime_assets", "world_layouts", "source_snapshot", "evidence")}, indent=2))
    raise SystemExit(0 if summary["status"] == "PASS" else 1)


if __name__ == "__main__":
    main()
