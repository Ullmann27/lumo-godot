#!/usr/bin/env python3
"""Assemble the release inventory only after all final asset evidence matches."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

BASE_COMMIT = "9f8341494ea316c9e36ed6722915ab34b22e67bd"
THEMES = ["zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple",
          "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway", "desert_drift", "learning_lab"]
PROTECTED = ["scripts/games/kart_world.gd", "scripts/games/kart_vehicle.gd",
             "scripts/games/kart_island.gd", "assets/characters/rivals/roster.json",
             "assets/characters/lumo_facial/Lumo-Facial-Mobile.glb",
             "assets/characters/lumo_animated/Lumo-Animated-Mobile.glb",
             "assets/kart/harbor_pavilion/wave_pavilion_lod0.glb"]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, explanation: str) -> None:
    if not condition:
        raise RuntimeError(explanation)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    root = args.root.resolve()
    evidence = root / "evidence/lumo_kart_art/review"
    audits = {}
    for name in ("final_glb_audit.json", "final_godot_import.json", "blender_sources.json",
                 "godot_collision_contract.json", "godot_driver_kart_fit.json"):
        report = json.loads((evidence / name).read_text())
        require(report.get("passed") is True, f"Required gate failed: {name}")
        audits[name] = report
    assets = audits["final_glb_audit.json"]["assets"]
    require(len(assets) == 409, f"Expected 409 GLBs, found {len(assets)}")
    require(len(audits["final_godot_import.json"]["assets"]) == 409, "Godot did not import all 409 GLBs")
    require(len(audits["blender_sources.json"]["sources"]) == 19, "Expected 19 editable Blender sources")
    for name in ("final_glb_audit.json", "final_godot_import.json"):
        for item in audits[name]["assets"]:
            require(digest(root / item["path"]) == item["sha256"], f"Stale {name} source: {item['path']}")
    for item in audits["blender_sources.json"]["sources"]:
        require(digest(root / item["path"]) == item["sha256"], f"Stale Blender source report: {item['path']}")
    domain_gates = []
    kart_evidence = root / "evidence/lumo_kart_art/karts"
    for name in ("export_validation.json", "rabbit_boot_clearance.json", "driver_appendage_clearance.json", "driver_torso_clearance.json", "final_render_index.json"):
        path = kart_evidence / name
        report = json.loads(path.read_text())
        require(report.get("passed") is True, "Kart/driver integration gate failed: " + name)
        domain_gates.append({"path": path.relative_to(root).as_posix(), "sha256": digest(path)})
        if name in {"rabbit_boot_clearance.json", "driver_appendage_clearance.json", "driver_torso_clearance.json"}:
            for key in ("kart_blend_sha256", "kart_glb_sha256"):
                require(set(report.get(key, {})) == {"comet", "glider", "turbo"},
                        "Missing kart source hash map: " + name + "/" + key)
        if name == "export_validation.json":
            for item in report["assets"]:
                require(digest(root / item["path"]) == item["sha256"], "Stale kart export test: " + item["path"])
        elif name == "rabbit_boot_clearance.json":
            require(digest(root / report["driver"]) == report["driver_sha256"], "Stale rabbit boot test")
            require(len(report["cases"]) == 72, "Incomplete boot clearance proof")
        elif name in {"driver_appendage_clearance.json", "driver_torso_clearance.json"}:
            require(len(report["cases"]) == 300, "Incomplete dynamic clearance proof: " + name)
            require(set(report["driver_sha256"]) == {"lion", "owl", "rabbit", "squirrel", "turtle"},
                    "Incomplete driver source hash map: " + name)
            if name == "driver_torso_clearance.json":
                require(report["component_checks"] == 600, "Incomplete torso component proof")
            for driver, expected in report["driver_sha256"].items():
                require(digest(root / "assets/kart/production/drivers" / driver / "driver.glb") == expected,
                        "Stale driver clearance proof: " + name + "/" + driver)
        elif name == "final_render_index.json":
            require(report["image_count"] == 6 and len(report["images"]) == 6,
                    "Incomplete final Blender kart image evidence")
            expected_images = {f"evidence/lumo_kart_art/karts/{kart}/{view}.png"
                               for kart in ("comet", "glider", "turbo")
                               for view in ("front_three_quarter", "rear_three_quarter")}
            require({item["image"] for item in report["images"]} == expected_images,
                    "Missing final Blender kart front/rear view")
            for item in report["images"]:
                require(digest(root / item["source"]) == item["source_sha256"], "Stale Blender kart render source")
                require(digest(root / item["image"]) == item["image_sha256"], "Changed Blender kart render")
        for kart, expected in report.get("kart_blend_sha256", {}).items():
            require(digest(root / "art/lumo_kart/blender/karts" / ("aurora_" + kart + ".blend")) == expected,
                    "Stale kart authoring clearance proof: " + kart)
        for kart, expected in report.get("kart_glb_sha256", {}).items():
            require(digest(root / "assets/kart/production/karts" / ("aurora_" + kart + ".glb")) == expected,
                    "Stale kart export clearance proof: " + kart)
    driver_render_path = root / "evidence/lumo_kart_art/drivers/final_render_manifest.json"
    driver_renders = json.loads(driver_render_path.read_text())
    require(driver_renders.get("status") == "PASS" and len(driver_renders["images"]) == 8,
            "Incomplete final Blender driver image evidence")
    for item in driver_renders["images"]:
        require(digest(root / item["file"]) == item["sha256"], "Changed final Blender driver image")
        for source in item["inputs"]:
            require(digest(root / source["file"]) == source["sha256"], "Stale final Blender driver image source")
    domain_gates.append({"path": driver_render_path.relative_to(root).as_posix(), "sha256": digest(driver_render_path)})
    track_render_path = root / "evidence/lumo_kart_art/tracks/blender_render_inventory.json"
    track_renders = json.loads(track_render_path.read_text())
    require(track_renders.get("status") == "COMPLETE" and len(track_renders["images"]) == 25,
            "Incomplete Blender track image inventory")
    for item in track_renders["images"]:
        require(digest(root / item["file"]) == item["sha256"], "Changed Blender track image")
    domain_gates.append({"path": track_render_path.relative_to(root).as_posix(), "sha256": digest(track_render_path)})
    for path, expected in audits["godot_driver_kart_fit.json"]["sources"].items():
        require(digest(root / path) == expected, f"Stale Godot fit evidence: {path}")
    require(len(audits["godot_driver_kart_fit.json"]["measurements"]) == 720, "Incomplete contact sampling")
    for key, filename in (("straight_sha256", "straight_12m.glb"), ("curve_sha256", "curve_right_30.glb"),
                          ("collision_sha256", "straight_12m_collision.glb")):
        path = root / "assets/kart/production/tracks/zauberwald" / filename
        require(digest(path) == audits["godot_collision_contract.json"][key], "Stale Godot collision proof: " + filename)
    protected = []
    for path in PROTECTED:
        original = subprocess.check_output(["git", "show", f"{BASE_COMMIT}:{path}"], cwd=root)
        expected = hashlib.sha256(original).hexdigest()
        require(digest(root / path) == expected, "Protected source changed: " + path)
        protected.append({"path": path, "sha256": expected, "unchanged": True})
    captures = json.loads((evidence / "godot_render_capture.json").read_text())
    require(len(captures["captures"]) == 63, "Incomplete final Godot still series")
    require(digest(root / "tools/lumo_kart_art/review/review.gd") == captures["review_script_sha256"],
            "Final Godot stills use an outdated review script")
    for record in captures["captures"]:
        require(digest(evidence / record["image"]) == record["sha256"], "Capture image hash mismatch")
    for path, expected in captures["sources"].items():
        require(digest(root / path) == expected, "Stale final render: " + path)
    for theme in THEMES:
        require(len(list((root / "assets/kart/production/tracks" / theme).glob("*.glb"))) == 35,
                "Incomplete theme: " + theme)
        require(any(row["view"] == theme + "_interior" for row in captures["captures"]),
                "Missing actual Godot interior image: " + theme)
        folder = root / "assets/kart/production/tracks" / theme
        for name, expected_count in (("blender_reimport_verification.json", 21), ("terrain_blender_verification.json", 14)):
            path = folder / name
            report = json.loads(path.read_text())
            require(report.get("status") == "PASS" and len(report["assets"]) == expected_count,
                    "Incomplete independent track proof: " + theme + "/" + name)
            for item in report["assets"]:
                require(digest(folder / item["file"]) == item["sha256"], "Stale independent track proof: " + theme + "/" + item["file"])
            domain_gates.append({"path": path.relative_to(root).as_posix(), "sha256": digest(path)})
    movies = []
    for name in ("lumo_zauberwald_flythrough", "lumo_aurora_karts", "lumo_driver_animations"):
        movie = json.loads((evidence / (name + ".json")).read_text())
        require(digest(root / movie["movie"]) == movie["sha256"], "Movie hash mismatch: " + name)
        require(movie["captured_frames"] == movie["encoded_frames"], "Incomplete encoded movie: " + name)
        receipt_path = root / movie["capture_receipt"]
        require(digest(receipt_path) == movie["capture_receipt_sha256"], "Changed movie capture receipt: " + name)
        receipt = json.loads(receipt_path.read_text())
        for path, expected in receipt["sources"].items():
            relevant = ((name == "lumo_aurora_karts" and "/karts/" in path)
                        or (name == "lumo_driver_animations" and ("/drivers/" in path or path.endswith("aurora_comet.glb")))
                        or (name == "lumo_zauberwald_flythrough" and path.endswith(("/zauberwald/straight_12m.glb", "/zauberwald/curve_right_30.glb"))))
            if relevant:
                require(digest(root / path) == expected, "Stale movie model: " + path)
        movies.append(movie)
    inventory = []
    for folder in ("art/lumo_kart", "assets/kart/production", "tools/lumo_kart_art", "docs/art/lumo_kart", "evidence/lumo_kart_art"):
        for path in sorted((root / folder).rglob("*")):
            if not path.is_file() or path.name == "release_manifest.json":
                continue
            if any(part in {".godot", "__pycache__", "tunnel_frames", "turntable_frames", "animation_frames"} for part in path.parts):
                continue
            if path.suffix == ".pyc" or path.name.endswith(".blend1"):
                continue
            inventory.append({"path": path.relative_to(root).as_posix(), "bytes": path.stat().st_size,
                              "sha256": digest(path)})
    report = {
        "schema_version": 1, "base_commit": BASE_COMMIT,
        "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=root, text=True).strip(),
        "status": "verified_asset_handoff", "live_gameplay_integrated": False,
        "runtime_roster_enabled": False, "physical_android_test": False,
        "counts": {"blender_sources": 19, "glb_files": 409, "kart_variants": 3, "driver_variants": 5,
                   "tunnel_themes": 11, "modules_per_theme": 7, "godot_still_images": len(captures["captures"]),
                   "mp4_previews": 3},
        "themes": THEMES, "protected_originals": protected,
        "audit_files": [{"path": (evidence / name).relative_to(root).as_posix(), "sha256": digest(evidence / name)} for name in audits],
        "domain_gates": domain_gates,
        "movies": movies,
        "asset_metrics": [{key: item[key] for key in ("path", "sha256", "bytes", "triangles_instanced_scene", "materials", "surfaces", "textures", "animations")} for item in assets],
        "files": inventory,
    }
    target = root / "docs/art/lumo_kart/release_manifest.json"
    target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"manifest": str(target), "counts": report["counts"], "files": len(inventory)}, indent=2))


if __name__ == "__main__":
    main()
