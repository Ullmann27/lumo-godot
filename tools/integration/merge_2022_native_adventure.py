#!/usr/bin/env python3
"""Review-scoped resolution of four conflicts between LUMO 2022 and Adventure+Art.

Merge participants are pinned; no conflict is silently resolved by taking a side.
Git index stage 2 is the installed 2022 native source; stage 3 is the 2026
Adventure+Art work. Unexpected conflicts or changed conflict bodies fail closed.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {
    "scripts/games/kart_island.gd",
    "scripts/games/kart_vehicle.gd",
    "scripts/games/kart_world.gd",
    "scripts/games/lumo_opponent_roster.gd",
}
BASE = "0e7be88791bf4ed5d556d535078471e05a02315d"
NEW = "ebf5a5c75d43164ea888e29b987ee9b163cdc72c"
PATTERN = re.compile(
    r"^<<<<<<<[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>>[^\n]*\n",
    re.MULTILINE | re.DOTALL,
)


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=ROOT, encoding="utf8",
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)


def unique(fragment: str, text: str, name: str) -> None:
    if text.count(fragment) != 1:
        raise RuntimeError(f"{name} expected exactly once: {fragment[:100]!r}")


def resolve_vehicle(original: str, matches: list[re.Match[str]]) -> tuple[str, dict]:
    """Reconcile all eight observed 2022-production vs 2026-rival regions."""
    if len(matches) != 8:
        raise RuntimeError(f"Vehicle source changed: {len(matches)} regions, expected 8")
    replacements: list[str] = []
    anchors = [
        ("production_driver.set_suspended(suspended)", "rival_visual.set_suspended(suspended)"),
        ("production_driver.celebrate_finished_race(place)", "rival_visual.celebrate_finished_race(place)"),
        ("production_vehicle = null", "rival_visual = null"),
        ("if _build_production_driver():", "var is_lumo: bool = animal == \"fox\""),
        ("child == production_vehicle", "child == rival_visual"),
        ("if animal == \"fox\" and not is_instance_valid(production_vehicle):",
         "var chassis := SurfaceTool.new()"),
        ("production_driver.apply_vehicle_sample", "rival_visual.apply_vehicle_sample"),
        ("if not is_instance_valid(production_vehicle):", "for i in range(wheel_rotors.size()):"),
    ]
    for index, item in enumerate(matches):
        old, newer = item.group(1), item.group(2)
        unique(anchors[index][0], old, f"kart_vehicle hunk {index + 1}")
        unique(anchors[index][1], newer, f"kart_vehicle hunk {index + 1}")
        if index in (0, 1, 2, 6):
            # Production Lumo retains all existing motion/contact state;
            # skinned-GLB rivals get their separate animation update.
            replacement = old.rstrip("\n") + "\n" + newer
        elif index == 3:
            # Returning early for production Lumo is essential: the standard
            # fox must not get two separately rendered driver heads.
            replacement = "\tif _build_production_driver():\n\t\treturn\n" + newer
        elif index == 4:
            # Neither the imported original nor the new imported rivals
            # may be baked into the low-detail rigid proxy.
            replacement = old.replace(
                "child == production_driver or (child == driver",
                "child == production_driver or child == rival_visual or (child == driver")
        elif index == 5:
            # Production vehicle already supplies the distant chassis;
            # every other kart (fox fallback or rival) builds the proxy.
            replacement = old.replace(
                'if animal == "fox" and not is_instance_valid(production_vehicle):',
                'if not is_instance_valid(production_vehicle):')
        else:
            # For the original imported vehicle, chassis/wheel joints remain
            # owned by that imported GLB. This does not change driving.
            replacement = old.replace(
                "is_instance_valid(lumo_animation) or is_instance_valid(production_driver):",
                "is_instance_valid(lumo_animation) or is_instance_valid(production_driver) or is_instance_valid(rival_visual):")
        replacements.append(replacement)
    cursor = 0
    pieces: list[str] = []
    for match, replacement in zip(matches, replacements):
        pieces.extend((original[cursor:match.start()], replacement))
        cursor = match.end()
    pieces.append(original[cursor:])
    result = "".join(pieces)
    if re.search(r"^(<<<<<<<|=======|>>>>>>>)", result, flags=re.MULTILINE):
        raise RuntimeError("Unresolved vehicle marker")
    return result, {"file": "scripts/games/kart_vehicle.gd", "regions": 8,
                    "production_driver_preserved": True, "rival_visual_preserved": True}


def resolve_world(original: str, matches: list[re.Match[str]]) -> tuple[str, dict]:
    if len(matches) != 4:
        raise RuntimeError(f"World changed: {len(matches)} regions, expected 4")
    replacements: list[str] = []
    expected = [
        ("production_tunnels = null", "adventure_tunnel.clear()"),
        ("if is_instance_valid(production_tunnels):", "ADVENTURE_TUNNELS.contains(self, distance, 16.0)"),
        ("if is_instance_valid(production_tunnels):", "ADVENTURE_TUNNELS.contains(self, distance, 15.0)"),
        ("if is_instance_valid(production_tunnels):", "ADVENTURE_TUNNELS.contains(self, distance, 25.0)"),
    ]
    for i, match in enumerate(matches):
        old, newer = match.group(1), match.group(2)
        unique(expected[i][0], old, f"world hunk {i + 1}")
        unique(expected[i][1], newer, f"world hunk {i + 1}")
        if i == 0:
            replacement = old.rstrip("\n") + "\n" + newer
        else:
            # Both old production-tunnel and new Adventure-tunnel footprints
            # must be excluded from the existing decorative arches.
            replacement = old.rstrip("\n").removesuffix(":") + " or " + newer.strip().removeprefix("if ") + "\n"
            if not replacement.strip().endswith(":"):
                raise RuntimeError("Bad combined world exclusion predicate")
        replacements.append(replacement)
    cursor = 0
    segments: list[str] = []
    for match, text in zip(matches, replacements):
        segments.extend([original[cursor:match.start()], text])
        cursor = match.end()
    segments.append(original[cursor:])
    return "".join(segments), {"file": "scripts/games/kart_world.gd",
        "regions": 4, "production_tunnels_preserved": True,
        "adventure_tunnels_preserved": True}


def resolve_file(name: str) -> dict:
    path = ROOT / name
    # Git's ort strategy may produce 1 or many conflict blocks depending on
    # neighbouring edits; resolve the immutable index stages, not those hunks.
    with tempfile.TemporaryDirectory(prefix="lumo-three-way-") as directory:
        inputs = []
        for stage in (2, 1, 3):
            stage_file = Path(directory) / f"stage-{stage}.gd"
            record = git("show", f":{stage}:{name}")
            stage_file.write_text(record.stdout, encoding="utf8")
            inputs.append(str(stage_file))
        merged = subprocess.run(
            ["git", "merge-file", "-p", *inputs],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # git-merge-file exits with the number of conflicts (not merely 1).
        if merged.returncode < 0 or merged.returncode > 127:
            raise RuntimeError(f"merge-file failed for {name}: {merged.stderr}")
        original = merged.stdout
    matches = list(PATTERN.finditer(original))
    proof = Path(os.environ.get("PROOF", "/tmp"))
    if proof.is_dir():
        (proof / ("mergefile_" + Path(name).stem + ".txt")).write_text(
            original, encoding="utf8")
    print(f"[LumoNativeUnion] {name}: merge-file conflict regions={len(matches)}", flush=True)
    if name.endswith("kart_vehicle.gd") or name.endswith("kart_world.gd"):
        out, report = (resolve_vehicle(original, matches)
                       if name.endswith("kart_vehicle.gd")
                       else resolve_world(original, matches))
        path.write_text(out, encoding="utf8")
        git("add", "--", name)
        return report
    if len(matches) != 1:
        raise RuntimeError(f"{name}: review {len(matches)} regions in mergefile evidence")
    old, newer = matches[0].group(1), matches[0].group(2)
    if name.endswith("kart_island.gd"):
        if old.count("RIVAL_FLIGHT.STATE_KEY") != 2:
            raise RuntimeError("Expected airborne flight metadata guard and read")
        unique("kart.set_driver_runtime_state(rival_airborne, rival_stunned, paused)", old, name)
        unique("fx.advance(_delta, paused or not racing or finished, reduced_motion)", newer, name)
        if newer.count("for fx in opponent_item_fx:") != 1:
            raise RuntimeError("Opponent effects block missing")
        effects = newer[newer.index("\tfor fx in opponent_item_fx:"):]
        merged = old.rstrip("\n") + "\n" + effects
    elif name.endswith("kart_vehicle.gd"):
        unique("production_driver.set_suspended(suspended)", old, name)
        unique("rival_visual.set_suspended(suspended)", newer, name)
        merged = old.rstrip("\n") + "\n" + newer
    elif name.endswith("kart_world.gd"):
        unique("production_tunnels = null", old, name)
        unique("adventure_tunnel.clear()", newer, name)
        merged = old.rstrip("\n") + "\n" + newer
    else:
        # Preserve the new validated skinned-GLB racing adapter and its real
        # scene factory. The 2022 3-LOD path accessor remains below the conflict
        # so old production drivers and their checks are still addressable.
        unique("static func can_use_racing_model(id: String) -> bool:", newer, name)
        if not old.startswith("\t\tif str(entry.id) == id:"):
            raise RuntimeError("Unexpected 2022 racing model guard")
        merged = newer
    out = original[: matches[0].start()] + merged + original[matches[0].end():]
    if re.search(r"^(<<<<<<<|=======|>>>>>>>)", out, flags=re.MULTILINE):
        raise RuntimeError(f"{name}: unresolved marker")
    path.write_text(out, encoding="utf8")
    git("add", "--", name)
    return {"file": name, "legacy_lines": len(old.splitlines()),
            "newer_lines": len(newer.splitlines()), "merged_lines": len(merged.splitlines())}


def assert_production_models_in_shared_regression() -> None:
    """Preserve genuine 2022 Blender LOD karts instead of testing fake coachwork."""
    name = "scripts/tests/kart_modular_parts_regression.gd"
    path = ROOT / name
    source = path.read_text(encoding="utf8")
    expected = """\t\tvar body: Node3D = kart.get_node_or_null("AuroraCoachwork")
\t\tassert(body != null, "Original chassis root missing")
\t\tassert(int(body.get_meta("modular_aero_revision", 0)) == 1)
\t\tvar parts: int = int(body.get_meta("modular_aero_count", 0))
\t\tassert(parts >= 20 and parts <= 28, "New chassis details absent or unbounded")
\t\tassert(kart.wheel_pivots.size() == 4, "Wheel anchors changed")
\t\tfor anchor: Vector3 in AERO.envelope_anchors():
\t\t\tassert(absf(anchor.x) <= 0.7 and anchor.y < 0.9 and absf(anchor.z) <= 1.19,
\t\t\t\t"Additional aero hardware exceeds the original chassis envelope")"""
    upgraded = """\t\tvar body: Node3D = kart.get_node_or_null("AuroraCoachwork")
\t\tif style in ["comet", "glider"]:
\t\t\t# The installed 2022 family app uses real Blender chassis with
\t\t\t# all three original LOD GLBs. Preserve these instead of replacing
\t\t\t# them with lower-detail procedural coachwork.
\t\t\tassert(body == null, "Original production GLB unexpectedly replaced")
\t\t\tassert(is_instance_valid(kart.production_vehicle),
\t\t\t\t"Original 2022 Blender vehicle disappeared")
\t\t\tassert(kart.production_vehicle.source_paths.size() == 3,
\t\t\t\t"Original 2022 LOD0/LOD1/LOD2 source assets missing")
\t\telse:
\t\t\tassert(body != null, "Procedural chassis root missing")
\t\t\tassert(int(body.get_meta("modular_aero_revision", 0)) == 1)
\t\t\tvar parts: int = int(body.get_meta("modular_aero_count", 0))
\t\t\tassert(parts >= 20 and parts <= 28, "New chassis details absent")
\t\t\tfor anchor: Vector3 in AERO.envelope_anchors():
\t\t\t\tassert(absf(anchor.x) <= 0.7 and anchor.y < 0.9 and absf(anchor.z) <= 1.19,
\t\t\t\t\t"Additional aero hardware exceeds the original chassis envelope")
\t\tassert(kart.wheel_pivots.size() == 4, "Wheel anchors changed")"""
    unique(expected, source, name)
    path.write_text(source.replace(expected, upgraded), encoding="utf8")
    git("add", "--", name)
    print("[LumoNativeUnion] production GLB LOD contract and procedural Aero"
          " explicitly tested separately", flush=True)


def main() -> None:
    conflicts = set(git("diff", "--name-only", "--diff-filter=U").stdout.splitlines())
    if conflicts != EXPECTED:
        raise RuntimeError(f"Unexpected native merge conflicts: {conflicts} vs {EXPECTED}")
    reports = [resolve_file(path) for path in sorted(EXPECTED)]
    remaining = git("diff", "--name-only", "--diff-filter=U").stdout.splitlines()
    if remaining:
        raise RuntimeError(f"Still unmerged: {remaining}")
    combined = (ROOT / "scripts/games/kart_tracks.gd").read_text(encoding="utf8")
    if 'kart_adventure_routes.gd' not in combined:
        raise RuntimeError("Missing authored Adventure routes in merged source")
    assert_production_models_in_shared_regression()
    for item in reports:
        print("[LumoNativeUnion]", item, flush=True)
    print("[LumoNativeUnion] PASS explicit 2022 and Adventure+Art reconciliation",
          flush=True)


if __name__ == "__main__":
    main()
