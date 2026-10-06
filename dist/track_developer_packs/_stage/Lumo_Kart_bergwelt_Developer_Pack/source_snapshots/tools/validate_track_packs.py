#!/usr/bin/env python3
"""Validate structured Lumo Kart track packs against the existing Godot route authority."""

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACK_DIR = ROOT / "docs/track_expansion/2026-10-06/packs"
CATALOG = ROOT / "scripts/games/kart_tracks.gd"
PACK_IDS = ("sonnenhafen", "zauberwald", "bergwelt", "holo_city")
VIEW_KINDS = {
    "orbit": 32,
    "orthographic": 4,
    "driver": 4,
    "signature": 2,
    "loop": 2,
    "item_lane": 1,
    "shortcut_entry": 1,
    "ai_debug": 1,
    "collision_debug": 1,
}
ALLOWED_ITEMS = {"boost", "shield", "pulse"}
GENERIC_TEXT = ("implement or review", "todo", "tbd", "lorem ipsum", "placeholder")


def fail(message: str) -> None:
    raise ValueError(message)


def read_authoritative_points() -> dict[str, list[list[float]]]:
    source = CATALOG.read_text(encoding="utf-8")
    arrays = re.findall(r'"points":\s*PackedVector3Array\(\[(.*?)\]\)', source, re.S)
    if len(arrays) != 4:
        fail(f"Expected 4 PackedVector3Array route definitions, found {len(arrays)}")
    order = ("zauberwald", "bergwelt", "holo_city", "sonnenhafen")
    result: dict[str, list[list[float]]] = {}
    for track_id, body in zip(order, arrays):
        points = [
            [float(x), float(y), float(z)]
            for x, y, z in re.findall(
                r"Vector3\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)",
                body,
            )
        ]
        if len(points) < 12:
            fail(f"{track_id}: expected route control points, found {len(points)}")
        result[track_id] = points
    return result


def check_pack(pack: dict, points: dict[str, list[list[float]]]) -> None:
    track_id = pack.get("track_id")
    if track_id not in PACK_IDS:
        fail(f"Unknown track_id: {track_id!r}")
    if pack.get("route", {}).get("control_points_xyz_m") != points[track_id]:
        fail(f"{track_id}: source control points differ from kart_tracks.gd")
    if pack.get("road", {}).get("width_m") != 10.8:
        fail(f"{track_id}: road width must remain 10.8 m")

    details = pack.get("details", [])
    if len(details) < 120:
        fail(f"{track_id}: {len(details)} details; minimum is 120")
    detail_ids = [detail.get("id") for detail in details]
    if len(detail_ids) != len(set(detail_ids)) or any(not value for value in detail_ids):
        fail(f"{track_id}: detail IDs must be present and unique")
    for detail in details:
        if not detail.get("title") or not detail.get("verification"):
            fail(f"{track_id}: {detail.get('id')} lacks a title or verification")
        if len(detail["verification"]) < 35:
            fail(f"{track_id}: {detail['id']} has a non-actionable verification")
        folded = detail["title"].lower() + " " + detail["verification"].lower()
        if any(token in folded for token in GENERIC_TEXT):
            fail(f"{track_id}: generic/filler text in {detail['id']}")

    views = pack.get("views", [])
    if len(views) != 48:
        fail(f"{track_id}: expected exactly 48 view definitions, found {len(views)}")
    view_ids = [view.get("id") for view in views]
    if len(view_ids) != len(set(view_ids)) or any(not value for value in view_ids):
        fail(f"{track_id}: view IDs must be present and unique")
    counts = {kind: 0 for kind in VIEW_KINDS}
    for view in views:
        kind = view.get("kind")
        if kind not in counts:
            fail(f"{track_id}: unknown view kind {kind!r}")
        counts[kind] += 1
        if not view.get("target") or not view.get("acceptance"):
            fail(f"{track_id}: {view.get('id')} lacks a target or acceptance rule")
        if not isinstance(view.get("camera"), dict):
            fail(f"{track_id}: {view.get('id')} has no camera definition")
    if counts != VIEW_KINDS:
        fail(f"{track_id}: incorrect view-kind distribution: {counts}")

    prisms = pack.get("mystery_prism_zones", [])
    if len(prisms) != 5:
        fail(f"{track_id}: expected five Lumo Mystery Prism zones")
    for prism in prisms:
        if not prism.get("name", "").startswith("Lumo Mystery Prism"):
            fail(f"{track_id}: mystery object is not named Lumo Mystery Prism")
        if set(prism.get("core_items", [])) != ALLOWED_ITEMS:
            fail(f"{track_id}: mystery prism core item IDs differ from runtime")
    if set(pack.get("fairness", {}).get("core_items", [])) != ALLOWED_ITEMS:
        fail(f"{track_id}: fairness table must use only current item IDs")

    geometry = pack.get("geometry_guides", {})
    for shape in ("road", "ramp", "bridge", "tunnel", "full_loop"):
        if not geometry.get(shape, {}).get("authoring"):
            fail(f"{track_id}: missing {shape} authoring guide")
    loop = geometry["full_loop"]
    if loop.get("runtime_enabled") is not False:
        fail(f"{track_id}: full loop must not be runtime-enabled")
    if loop.get("status") != "planned_requires_inverted_physics":
        fail(f"{track_id}: full loop must require the inversion contract")


def main() -> int:
    points = read_authoritative_points()
    manifest = json.loads((PACK_DIR / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("pack_ids") != list(PACK_IDS):
        fail("Track pack manifest must list the four catalog tracks in canonical order")
    for track_id in PACK_IDS:
        pack_path = PACK_DIR / f"{track_id}.json"
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        if pack.get("track_id") != track_id:
            fail(f"{pack_path.name}: track ID does not match its file name")
        check_pack(pack, points)
        print(
            f"[TrackPack] {track_id}: {len(pack['details'])} details, "
            f"{len(pack['views'])} views, 5 Mystery Prisms PASS"
        )

    authoring_scene = ROOT / "scenes/games/track_authoring/sky_halo_loop_authoring.tscn"
    authoring_script = ROOT / "scripts/games/authoring/sky_halo_loop_authoring.gd"
    world_script = (ROOT / "scripts/games/kart_world.gd").read_text(encoding="utf-8")
    if not authoring_scene.is_file() or not authoring_script.is_file():
        fail("Sky Halo authoring scene/script is missing")
    if "sky_halo_loop_authoring" in world_script:
        fail("Sky Halo authoring prototype must not be loaded by the race world")
    prototype = authoring_script.read_text(encoding="utf-8")
    for required in (
        'set_meta("runtime_driveable", false)',
        'set_meta("collision_included", false)',
        'set_meta("requires_inverted_physics_contract", true)',
        "const ROAD_WIDTH_M: float = 10.8",
        "const SEGMENTS: int = 96",
    ):
        if required not in prototype:
            fail(f"Sky Halo authoring prototype missing safety/geometry invariant: {required}")
    if any(token in prototype for token in ("CollisionShape3D", "StaticBody3D", "CharacterBody3D")):
        fail("Sky Halo prototype must remain authoring-only without physics bodies")
    print("[SkyHaloAuthoring] 360-degree mesh, no collision, not wired to runtime PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"[TrackPack] FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
