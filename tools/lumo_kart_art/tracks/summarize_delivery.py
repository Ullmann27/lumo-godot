"""Summarize the completed Blender gates and verify delivery hashes.

Reads frozen asset files and existing re-import reports. It does not rebuild,
re-export, render or modify any asset or Blender source.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path


THEMES = (
    "zauberwald", "bergwelt", "holo_city", "crystal_canyon",
    "jungle_temple", "candy_cloud", "volcano_night", "winter_sprint",
    "galaxy_ringway", "desert_drift", "learning_lab",
)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def category(filename):
    if filename.endswith("_terrain_lod1.glb"):
        return "terrain_lod1"
    if filename.endswith("_terrain.glb"):
        return "terrain_lod0"
    if filename.endswith("_collision.glb"):
        return "collision"
    if filename.endswith("_lod1.glb"):
        return "lod1"
    return "lod0"


def bounds(values):
    return {"min": min(values), "max": max(values)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    repo = args.repo.resolve()
    frozen_files = {}
    summaries = []
    all_records = []
    for theme in THEMES:
        folder = repo / "assets/kart/production/tracks" / theme
        manifest = json.loads((folder / "manifest.json").read_text())
        terrain = json.loads((folder / "terrain_manifest.json").read_text())
        reports = [json.loads((folder / name).read_text()) for name in (
            "blender_reimport_verification.json", "terrain_blender_verification.json")]
        assert all(report["status"] == "PASS" for report in reports), theme
        assert [len(report["assets"]) for report in reports] == [21, 14], theme
        records = [record for report in reports for record in report["assets"]]
        assert {record["file"] for record in records} == {p.name for p in folder.glob("*.glb")}, theme
        counts = Counter(category(record["file"]) for record in records)
        assert all(counts[group] == 7 for group in (
            "lod0", "lod1", "collision", "terrain_lod0", "terrain_lod1")), theme
        for record in records:
            path = folder / record["file"]
            digest = sha256(path)
            assert digest == record["sha256"], str(path)
            assert path.stat().st_size == record["bytes"], str(path)
            assert record["degenerate_triangles"] == 0, str(path)
            assert record["nonmanifold_edges_after_seam_weld"] == 0, str(path)
            frozen_files[str(path.relative_to(repo))] = {
                "sha256": digest, "bytes": path.stat().st_size,
            }
        preserved = terrain["preserved_core_glb_sha256"]
        assert len(preserved) == 21, theme
        assert all(sha256(folder / name) == digest for name, digest in preserved.items()), theme
        source = repo / manifest["source_blend"]
        frozen_files[manifest["source_blend"]] = {
            "sha256": sha256(source), "bytes": source.stat().st_size,
        }
        visible_core = [r for r in records if category(r["file"]) in ("lod0", "lod1")]
        group_stats = {}
        for group in counts:
            group_records = [r for r in records if category(r["file"]) == group]
            group_stats[group] = {
                "count": len(group_records),
                "triangles_per_module": bounds([r["triangles"] for r in group_records]),
                "material_groups_per_module": bounds([r["material_count"] for r in group_records]),
                "total_bytes": sum(r["bytes"] for r in group_records),
            }
        summaries.append({
            "theme": theme, "label": manifest["label"], "status": "PASS",
            "glbs": len(records), "groups": group_stats,
            "source_blend": manifest["source_blend"],
            "source_bytes": source.stat().st_size,
            "glb_bytes": sum(r["bytes"] for r in records),
            "clearance_rays": sum(r["clearance_rays"] for r in records),
            "visible_core_min_side_clearance_m": min(r["measured_min_side_clearance_m"] for r in visible_core),
            "visible_core_min_roof_clearance_m": min(r["measured_min_roof_clearance_m"] for r in visible_core),
            "core_glbs_preserved_while_adding_terrain": len(preserved),
            "verification_reports": [str((folder / name).relative_to(repo)) for name in (
                "blender_reimport_verification.json", "terrain_blender_verification.json")],
        })
        all_records += records
    report = {
        "schema": 1,
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "status": "PASS",
        "scope": "Original modular track art; existing Blender re-import reports plus current file hashes",
        "theme_count": len(summaries),
        "module_shapes_per_theme": 7,
        "glb_count": len(all_records),
        "blend_count": len(summaries),
        "completed_blender_reimport_reports": 2 * len(summaries),
        "total_clearance_rays_in_reports": sum(r["clearance_rays"] for r in all_records),
        "current_glb_hashes_match_reports": True,
        "core_glbs_preserved_while_adding_terrain": sum(s["core_glbs_preserved_while_adding_terrain"] for s in summaries),
        "glb_bytes": sum(r["bytes"] for r in all_records),
        "blend_bytes": sum(s["source_bytes"] for s in summaries),
        "nonmanifold_edges_after_seam_weld": sum(r["nonmanifold_edges_after_seam_weld"] for r in all_records),
        "degenerate_triangles": sum(r["degenerate_triangles"] for r in all_records),
        "physical_device_fps_verified": False,
        "live_race_or_apk_integration_claimed": False,
        "themes": summaries,
        "frozen_files": frozen_files,
    }
    evidence = repo / "evidence/lumo_kart_art/tracks/production_summary.json"
    evidence.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    lines = [
        "# Track art – measured delivery inventory", "",
        f"The frozen package contains **{report['glb_count']} GLBs and {report['blend_count']} editable Blender sources** across eleven themes.",
        "All 22 independent Blender re-import reports passed. The inventory check confirmed that every current GLB matches its recorded SHA-256 hash and byte size.", "",
        "## Actual per-module budgets", "",
        "Ranges below are triangle counts for a single module. They are not a whole-race budget or a measured frame rate. File sizes include embedded original textures.", "",
        "| Theme | Full model triangles | Detail LOD triangles | Material groups, full | All 35 GLBs, MiB | Blender source, MiB |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for summary in summaries:
        groups = summary["groups"]
        full = groups["lod0"]["triangles_per_module"]
        lod = groups["lod1"]["triangles_per_module"]
        materials = groups["lod0"]["material_groups_per_module"]
        lines.append(f"| `{summary['theme']}` | {full['min']:,}–{full['max']:,} | {lod['min']:,}–{lod['max']:,} | {materials['min']}–{materials['max']} | {summary['glb_bytes']/1048576:.2f} | {summary['source_bytes']/1048576:.2f} |")
    min_side = min(s["visible_core_min_side_clearance_m"] for s in summaries)
    min_roof = min(s["visible_core_min_roof_clearance_m"] for s in summaries)
    lines += ["", "## Geometry and verification", "",
        "Each theme has the same seven shapes: entry, exit, 12 m straight, two 30° curves at 36 m radius, and smooth 12 m ascent/descent changing elevation by 1.5 m. Each shape has a full model, detail LOD, separate concave collision shell, terrain cover and terrain LOD: 35 GLBs per theme.", "",
        f"The independent exported-geometry checks recorded **{report['total_clearance_rays_in_reports']:,} clearance rays**, zero degenerate triangles and zero non-manifold edges after seam duplicates were welded for inspection. Sockets, actual triangle counts and UV channel validity were also checked. Sampling is evidence for the stated module envelope; it does not replace live vehicle and camera testing.", "",
        f"Across visible full and detail LOD modules, the lowest sampled side clearance from centerline was **{min_side:.3f} m** and the lowest sampled roof clearance across the 10.8 m road was **{min_roof:.3f} m**. The reserved contract envelope is 11.8 m wide × 4.5 m high.", "",
        "Collision proxies contain 228–456 triangles and no texture materials. Terrain covers contain 820–3,280 triangles, with terrain LODs at 820–1,312 triangles and one untextured vertex-color PBR material. All 231 pre-existing core GLBs remained byte-identical while the 154 terrain GLBs were added.", "",
        f"Total exported GLB size is **{report['glb_bytes']/1048576:.2f} MiB**; all eleven packed, compressed editable sources total **{report['blend_bytes']/1048576:.2f} MiB**. These are storage sizes, not measured runtime memory.", "",
        "## Reusable evidence", "",
        "- `evidence/lumo_kart_art/tracks/production_summary.json`: measured inventory plus current SHA-256 hashes for all 385 GLBs and eleven sources.",
        "- `assets/kart/production/tracks/<theme>/blender_reimport_verification.json`: 21 independently re-imported core GLBs per theme.",
        "- `assets/kart/production/tracks/<theme>/terrain_blender_verification.json`: 14 independently re-imported terrain GLBs per theme.",
        "- `assets/kart/production/tracks/<theme>/manifest.json` and `terrain_manifest.json`: exact file, module, material, triangle and bounds data.",
        "- `docs/art/lumo_kart/tracks/CONNECTION_CONTRACT.md`: axes, nested sockets, light mounts, road profile, collision and LOD rules.", "",
        "## Integration boundary", "",
        "The package supplies original art geometry, material maps and editable sources. Exported models contain no duplicate pavement. Final road placement, surface terrain blending, bounded interior lights, collision creation, runtime LOD selection and Android profiling belong to the main-team integration. Separate Godot review evidence is managed by the root team. This inventory makes no live-race integration, APK release or device frame-rate claim.", "",
    ]
    (repo / "docs/art/lumo_kart/tracks/DELIVERY_SUMMARY.md").write_text("\n".join(lines))
    print(json.dumps({key: value for key, value in report.items() if key not in ("themes", "frozen_files")}, indent=2))


if __name__ == "__main__":
    main()
