#!/usr/bin/env python3
"""Build deterministic developer ZIP packs for the four Lumo Kart worlds."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
PACK_ROOT = ROOT / "docs/track_expansion/2026-10-06/packs"
OUT_ROOT = ROOT / "dist/track_developer_packs"
PACK_IDS = ("sonnenhafen", "zauberwald", "bergwelt", "holo_city")
MAX_ZIP_BYTES = 30 * 1024 * 1024
REQUIRED_VIEWS = 48
MIN_DETAILS = 101

COMMON_SOURCE_PATHS = (
    "scripts/games/kart_tracks.gd",
    "scripts/games/kart_world.gd",
    "scripts/games/kart_island.gd",
    "scripts/games/kart_sky_islands.gd",
    "assets/shaders/kart_asphalt.gdshader",
    "assets/shaders/kart_stylized_vertex_tint.gdshader",
    "tools/validate_track_packs.py",
    "docs/track_expansion/2026-10-06/TRACK_DEVELOPER_PACK_SPEC.md",
)

TRACK_SOURCE_PATHS = {
    "sonnenhafen": ("scripts/tests/kart_sonnenhafen_showcase.gd",),
    "zauberwald": ("scripts/tests/kart_zauberwald_showcase.gd",),
    "bergwelt": (
        "scenes/games/track_authoring/sky_halo_loop_authoring.tscn",
        "scripts/games/authoring/sky_halo_loop_authoring.gd",
        "scripts/tests/kart_sky_halo_authoring_contract.gd",
        "scripts/tests/kart_sky_halo_authoring_showcase.gd",
        "scripts/tests/kart_sky_islands_showcase.gd",
    ),
    "holo_city": ("scripts/tests/kart_holo_city_showcase.gd",),
}


def die(message: str) -> None:
    raise ValueError(message)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def stable_json(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def flatten(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return str(value)


def write_csv(path: Path, rows: Iterable[dict[str, Any]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for raw in rows:
            writer.writerow({field: flatten(raw.get(field)) for field in fields})


def route_rows(pack: dict[str, Any]) -> list[dict[str, Any]]:
    route = pack["route"]
    result = []
    for index, (point_id, label, xyz) in enumerate(
        zip(
            route["control_point_ids"],
            route["control_point_labels"],
            route["control_points_xyz_m"],
        )
    ):
        result.append(
            {
                "index": index,
                "id": point_id,
                "label": label,
                "x_m": xyz[0],
                "y_m": xyz[1],
                "z_m": xyz[2],
            }
        )
    return result


def snapshot_paths(track_id: str) -> list[str]:
    ordered = list(COMMON_SOURCE_PATHS) + list(TRACK_SOURCE_PATHS.get(track_id, ()))
    result = []
    for path in ordered:
        if path not in result:
            result.append(path)
    return result


def copy_sources(track_id: str, stage: Path) -> list[str]:
    copied = []
    for relative in snapshot_paths(track_id):
        source = ROOT / relative
        if not source.is_file():
            continue
        destination = stage / "source_snapshots" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        copied.append(relative)
    return copied


def copy_runtime_views(track_id: str, stage: Path) -> list[str]:
    source_dir = ROOT / "exports/track-pack-views" / track_id
    if not source_dir.is_dir():
        return []
    destination_dir = stage / "runtime_views"
    destination_dir.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for source in sorted(source_dir.iterdir()):
        if source.is_file() and source.suffix.lower() in {".png", ".json"}:
            shutil.copy2(source, destination_dir / source.name)
            copied.append(source.name)
    return copied


def readme_text(pack: dict[str, Any], copied_sources: list[str], runtime_views: list[str]) -> str:
    source_lines = "\n".join("- " + item for item in copied_sources) or "- none"
    runtime_pngs = len([item for item in runtime_views if item.lower().endswith(".png")])
    return f"""# Lumo Kart Developer Pack - {pack["display_name"]}

Pack-ID: {pack["pack_id"]}
Track-ID: {pack["track_id"]}
Status: {pack["status"]}

This is a reproducible 3D / level-design handoff for the existing Lumo Kart
codebase. It contains no third-party branded racing-game assets.

## Scope

- {len(pack["details"])} individually verifiable build/gameplay/QA details
- {len(pack["views"])} exact camera/debug views
- {len(pack["route"]["control_points_xyz_m"])} authoritative route control points
- {len(pack["signature_setpieces"])} signature setpieces
- {len(pack["checkpoints"])} checkpoint/respawn anchors
- {len(pack["ai_racing_line"])} AI racing-line anchors
- {len(pack["mystery_prism_zones"])} Lumo Mystery Prism zones
- {runtime_pngs} rendered developer-view PNGs included in this build
- road width: {pack["road"]["width_m"]} m
- geometry guides: {", ".join(pack["geometry_guides"].keys())}

## Directory

- pack.json: full structured authority
- tables/: CSV exports for DCC, level tools, sheets and QA
- guides/: geometry, shot, item, loop, implementation and QA handoff
- source_snapshots/: relevant Godot, shader and test sources from this build
- runtime_views/: rendered Godot views plus capture_report.json when CI capture is available
- manifest.json: counts, provenance and safety state

## Hard rules

1. Road, visible rail and collision must stay spatially aligned.
2. Full loop stays authoring-only until 360-degree inversion physics passes for
   player, camera, AI, collision and respawn.
3. Mystery Prisms use only boost, shield and pulse.
4. No learning questions, answer timers or correct-answer turbo in Kart races.
5. Repeated props should remain MultiMesh/batch friendly with mobile LODs and
   simple collision meshes.
6. 60 FPS is a target budget; no physical-device PASS without measurement.

## Source snapshots

{source_lines}

Runtime files in the repository remain authoritative. Snapshots exist only to
make this exact handoff self-contained and auditable.
"""


def shotlist_text(pack: dict[str, Any]) -> str:
    lines = [
        "# Shotlist - " + pack["display_name"],
        "",
        "Exactly 48 views. Each capture must satisfy its camera definition and acceptance rule.",
        "",
    ]
    for view in pack["views"]:
        lines.extend(
            [
                "## " + view["id"] + " - " + view["kind"],
                "- Target: " + str(view["target"]),
                "- Camera: " + json.dumps(view["camera"], ensure_ascii=False, sort_keys=True),
                "- Acceptance: " + str(view["acceptance"]),
                "",
            ]
        )
    return "\n".join(lines)


def checklist_text(pack: dict[str, Any]) -> str:
    lines = [
        "# Implementation Checklist - " + pack["display_name"],
        "",
        "Check an item only after the verification rule is actually met.",
        "",
    ]
    for detail in pack["details"]:
        lines.append(
            "- [ ] "
            + detail["id"]
            + " | "
            + detail["kind"]
            + " | "
            + detail["title"]
            + " -- "
            + detail["verification"]
            + " [Authority: "
            + detail["authority"]
            + "]"
        )
    return "\n".join(lines) + "\n"


def loop_contract_text(pack: dict[str, Any]) -> str:
    loop = pack["geometry_guides"]["full_loop"]
    return f"""# Full Loop / Inversion Contract - {pack["display_name"]}

Status: {loop.get("status")}
Runtime enabled: {loop.get("runtime_enabled")}

Authoring:
{loop.get("authoring", "")}

## Release gates

- [ ] Kart up-vector and gravity follow road normal through 360 degrees.
- [ ] Camera remains stable relative to road surface.
- [ ] Rival AI uses the same inverted geometry and racing line.
- [ ] Checkpoint and respawn work inside and after the loop.
- [ ] Collision correctly distinguishes rideable side through the loop.
- [ ] Complete player and AI engine runs pass.
- [ ] Entry and exit have safe speed and landing corridors.
- [ ] Side and top debug captures match the 48-view shotlist.

No optical fake and no runtime activation before full acceptance.
"""


def item_text(pack: dict[str, Any]) -> str:
    lines = [
        "# Lumo Mystery Prisms - " + pack["display_name"],
        "",
        "Core items: boost, shield, pulse",
        "",
        "Zones:",
    ]
    for zone in pack["mystery_prism_zones"]:
        lines.append(
            "- "
            + zone["id"]
            + " | route_fraction="
            + str(zone["route_fraction"])
            + " | lateral_m="
            + str(zone["lateral_m"])
            + " | radius_m="
            + str(zone["pickup_radius_m"])
        )
    lines.extend(
        [
            "",
            "Position/fairness data is fully retained in pack.json > fairness.",
            "Catch-up uses visible item weighting, not teleporting or hidden top-speed advantages.",
            "",
        ]
    )
    return "\n".join(lines)


def qa_text(pack: dict[str, Any]) -> str:
    qa = pack["qa"]
    return (
        "# QA Acceptance - "
        + pack["display_name"]
        + "\n\n## Collision\n"
        + flatten(qa.get("collision"))
        + "\n\n## Low-detail parity\n"
        + flatten(qa.get("low_detail_parity"))
        + "\n\n## Learning separation\n"
        + flatten(qa.get("learning_separation"))
        + "\n\n## Performance\n"
        + flatten(qa.get("performance"))
        + "\n\nAlso run tools/validate_track_packs.py, existing Kart regressions and real Godot runtime captures against all 48 view definitions.\n"
    )


def validate_pack(pack: dict[str, Any], track_id: str) -> None:
    if pack.get("track_id") != track_id:
        die(track_id + ": track_id mismatch")
    if len(pack.get("details", [])) < MIN_DETAILS:
        die(track_id + ": requires more than 100 details")
    if len(pack.get("views", [])) != REQUIRED_VIEWS:
        die(track_id + ": requires exactly 48 views")
    if pack.get("road", {}).get("width_m") != 10.8:
        die(track_id + ": road width must remain 10.8 m")
    if len(pack.get("mystery_prism_zones", [])) != 5:
        die(track_id + ": requires five Mystery Prism zones")
    loop = pack.get("geometry_guides", {}).get("full_loop", {})
    if loop.get("runtime_enabled") is not False:
        die(track_id + ": full loop must remain disabled until inversion contract passes")


def build_stage(pack: dict[str, Any], track_id: str) -> Path:
    stage = OUT_ROOT / "_stage" / ("Lumo_Kart_" + track_id + "_Developer_Pack")
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    copied_sources = copy_sources(track_id, stage)
    runtime_views = copy_runtime_views(track_id, stage)
    (stage / "pack.json").write_text(stable_json(pack), encoding="utf-8")

    write_csv(
        stage / "tables/details.csv",
        pack["details"],
        ["id", "kind", "title", "anchor", "verification", "authority"],
    )
    write_csv(
        stage / "tables/views.csv",
        pack["views"],
        ["id", "kind", "target", "camera", "acceptance"],
    )
    write_csv(
        stage / "tables/signature_setpieces.csv",
        pack["signature_setpieces"],
        ["id", "name", "status", "anchor_fraction", "authority", "dimensions_m", "palette_role", "handoff_notes"],
    )
    write_csv(
        stage / "tables/checkpoints.csv",
        pack["checkpoints"],
        ["id", "route_fraction", "respawn", "source"],
    )
    write_csv(
        stage / "tables/ai_racing_line.csv",
        pack["ai_racing_line"],
        ["id", "route_fraction", "lateral_m", "target_speed_kmh", "overtake_clearance_m", "source"],
    )
    write_csv(
        stage / "tables/mystery_prisms.csv",
        pack["mystery_prism_zones"],
        ["id", "name", "route_fraction", "lateral_m", "pickup_radius_m", "once_per_lap", "core_items", "runtime_source"],
    )
    write_csv(
        stage / "tables/route_control_points.csv",
        route_rows(pack),
        ["index", "id", "label", "x_m", "y_m", "z_m"],
    )

    guides = stage / "guides"
    guides.mkdir(parents=True, exist_ok=True)
    (guides / "geometry_guides.json").write_text(stable_json(pack["geometry_guides"]), encoding="utf-8")
    (guides / "palette.json").write_text(stable_json(pack["palette"]), encoding="utf-8")
    (guides / "fairness.json").write_text(stable_json(pack["fairness"]), encoding="utf-8")
    (guides / "SHOTLIST_48_VIEWS.md").write_text(shotlist_text(pack), encoding="utf-8")
    (guides / "IMPLEMENTATION_CHECKLIST.md").write_text(checklist_text(pack), encoding="utf-8")
    (guides / "LOOPING_INVERSION_CONTRACT.md").write_text(loop_contract_text(pack), encoding="utf-8")
    (guides / "ITEM_SYSTEM.md").write_text(item_text(pack), encoding="utf-8")
    (guides / "QA_ACCEPTANCE.md").write_text(qa_text(pack), encoding="utf-8")
    (stage / "README.md").write_text(readme_text(pack, copied_sources, runtime_views), encoding="utf-8")

    manifest = {
        "schema_version": "1.0.0",
        "track_id": track_id,
        "display_name": pack["display_name"],
        "details": len(pack["details"]),
        "views": len(pack["views"]),
        "route_control_points": len(pack["route"]["control_points_xyz_m"]),
        "signature_setpieces": len(pack["signature_setpieces"]),
        "checkpoints": len(pack["checkpoints"]),
        "ai_racing_line_anchors": len(pack["ai_racing_line"]),
        "mystery_prisms": len(pack["mystery_prism_zones"]),
        "source_snapshots": copied_sources,
        "runtime_capture_files": runtime_views,
        "runtime_capture_pngs": len([item for item in runtime_views if item.lower().endswith(".png")]),
        "runtime_loop_enabled": pack["geometry_guides"]["full_loop"]["runtime_enabled"],
        "max_zip_bytes": MAX_ZIP_BYTES,
    }
    (stage / "manifest.json").write_text(stable_json(manifest), encoding="utf-8")
    return stage


def zip_directory(stage: Path, destination: Path) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(stage.rglob("*")):
            if not path.is_file():
                continue
            arcname = Path(stage.name) / path.relative_to(stage)
            info = zipfile.ZipInfo(str(arcname).replace("\\", "/"))
            info.date_time = (2026, 10, 6, 0, 0, 0)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    size = destination.stat().st_size
    if size >= MAX_ZIP_BYTES:
        die(destination.name + ": must be smaller than 30 MiB")
    return hashlib.sha256(destination.read_bytes()).hexdigest()


def main() -> int:
    if OUT_ROOT.exists():
        shutil.rmtree(OUT_ROOT)
    OUT_ROOT.mkdir(parents=True)

    summary_rows = []
    checksums = []
    for track_id in PACK_IDS:
        pack = read_json(PACK_ROOT / (track_id + ".json"))
        validate_pack(pack, track_id)
        stage = build_stage(pack, track_id)
        zip_path = OUT_ROOT / ("Lumo_Kart_" + track_id + "_Developer_Pack.zip")
        digest = zip_directory(stage, zip_path)
        checksums.append((digest, zip_path.name))
        summary_rows.append(
            {
                "track_id": track_id,
                "display_name": pack["display_name"],
                "details": len(pack["details"]),
                "views": len(pack["views"]),
                "zip": zip_path.name,
                "bytes": zip_path.stat().st_size,
                "sha256": digest,
            }
        )

    index = [
        "# Lumo Kart Developer ZIPs",
        "",
        "Four independent, reproducible level / 3D handoffs.",
        "Each pack contains more than 100 details, exactly 48 views, geometry / loop / item / AI / QA data and relevant source snapshots.",
        "",
    ]
    for row in summary_rows:
        index.append(
            "- "
            + row["display_name"]
            + ": "
            + str(row["details"])
            + " details, "
            + str(row["views"])
            + " views, "
            + row["zip"]
            + ", "
            + str(row["bytes"])
            + " bytes, SHA256 "
            + row["sha256"]
        )
    (OUT_ROOT / "PACK_INDEX.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    (OUT_ROOT / "pack_summary.json").write_text(stable_json(summary_rows), encoding="utf-8")
    (OUT_ROOT / "SHA256SUMS.txt").write_text(
        "".join(digest + "  " + name + "\n" for digest, name in checksums),
        encoding="utf-8",
    )

    metadata_paths = [
        OUT_ROOT / "PACK_INDEX.md",
        OUT_ROOT / "pack_summary.json",
        OUT_ROOT / "SHA256SUMS.txt",
    ]
    pack_zip_paths = [OUT_ROOT / row["zip"] for row in summary_rows]
    max_payload = MAX_ZIP_BYTES - (512 * 1024)
    bundle_groups: list[list[Path]] = [[]]
    bundle_payload = 0
    for path in pack_zip_paths:
        size = path.stat().st_size
        if size >= max_payload:
            die(path.name + ": too large to place in a split delivery bundle")
        if bundle_groups[-1] and bundle_payload + size >= max_payload:
            bundle_groups.append([])
            bundle_payload = 0
        bundle_groups[-1].append(path)
        bundle_payload += size

    bundle_rows = []
    for index_part, group in enumerate(bundle_groups, start=1):
        if len(bundle_groups) == 1:
            bundle_name = "Lumo_Kart_Track_Developer_Packs_ALL.zip"
        else:
            bundle_name = "Lumo_Kart_Track_Developer_Packs_PART_" + str(index_part).zfill(2) + ".zip"
        bundle_path = OUT_ROOT / bundle_name
        with zipfile.ZipFile(
            bundle_path,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for path in metadata_paths + group:
                info = zipfile.ZipInfo(path.name)
                info.date_time = (2026, 10, 6, 0, 0, 0)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                archive.writestr(info, path.read_bytes())
        if bundle_path.stat().st_size >= MAX_ZIP_BYTES:
            die(bundle_name + ": split bundle must be smaller than 30 MiB")
        bundle_rows.append(
            {
                "name": bundle_name,
                "bytes": bundle_path.stat().st_size,
                "contains": [path.name for path in group],
                "sha256": hashlib.sha256(bundle_path.read_bytes()).hexdigest(),
            }
        )

    (OUT_ROOT / "bundle_manifest.json").write_text(
        stable_json(bundle_rows), encoding="utf-8"
    )

    print("[TrackDeveloperPacks] PASS")
    for row in summary_rows:
        print(
            "  "
            + row["track_id"]
            + ": "
            + str(row["details"])
            + " details / "
            + str(row["views"])
            + " views / "
            + str(row["bytes"])
            + " bytes / "
            + row["sha256"][:12]
        )
    for row in bundle_rows:
        print(
            "  bundle: "
            + row["name"]
            + " / "
            + str(row["bytes"])
            + " bytes / "
            + ", ".join(row["contains"])
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("[TrackDeveloperPacks] FAIL: " + str(error), file=sys.stderr)
        raise SystemExit(1)
