#!/usr/bin/env python3
"""Report actual native LUMO navigation/learning discoverability from tracked sources."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "audit" / "native"
out.mkdir(parents=True, exist_ok=True)
router = (ROOT / "scripts/app/scene_router.gd").read_text(encoding="utf-8")
hub = (ROOT / "scripts/games/game_hub.gd").read_text(encoding="utf-8")
build = (ROOT / "scripts/creative/build_world.gd").read_text(encoding="utf-8")
learning = (ROOT / "scripts/learning/learning_world.gd").read_text(encoding="utf-8")
routes = dict(re.findall(r'^\s*"([a-z_]+)":\s*"(res://[^"]+)"', router, re.M))
missing = [name for name, path in routes.items() if not (ROOT / path.removeprefix("res://")).is_file()]
if missing:
    raise SystemExit("Missing registered native scene source(s): " + ", ".join(missing))
direct = re.findall(r'_make_route\([^,\n]+,\s*Color\([^)]*\),\s*"([a-z_]+)"', hub)
village_nested = '["Dorf & Wirtschaft", _open_settlement.bind("settlement", true)]' in build
kinds = []
for key in ("bridge_ten", "addition", "bridge_hundred", "subtract_ten",
            "equal_groups", "equal_sharing", "fraction_parts", "syllables", "plant_parts"):
    if '"' + key + '"' in learning:
        kinds.append(key)
asset = ROOT / "assets/learning/studio/learning_studio.glb"
asset_valid = asset.is_file() and asset.read_bytes()[:4] == b"glTF"
report = {
  "role": "native-3d-qa-worker",
  "status": "AUDIT_COMPLETE_WITH_OPEN_QUALITY_GAPS",
  "registered_scene_count": len(routes),
  "registered_scenes": routes,
  "direct_native_game_hub_routes": direct,
  "direct_native_game_hub_count": len(direct),
  "village_is_nested_inside_build_toolbar": village_nested,
  "separate_village_entry_in_native_scene_router": "village" in routes,
  "learning_3d_kinds_observed": kinds,
  "existing_studio_glb_header_valid": asset_valid,
  "review_flags": [
    "Existing native games hub does not expose all registered game routes directly.",
    "Village & Economy is nested in a horizontally scrolling Bauwelt tool row."
  ],
  "all_3d_visuals_reviewed": False,
  "all_games_playtested": False,
  "physical_fold_fps_measured": False,
  "is_automatic_code_agent": False
}
target = out / "native-discoverability.json"
target.write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
print(json.dumps(report, indent=2, ensure_ascii=False))
