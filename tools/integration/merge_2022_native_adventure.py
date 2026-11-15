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
    for item in reports:
        print("[LumoNativeUnion]", item, flush=True)
    print("[LumoNativeUnion] PASS explicit 2022 and Adventure+Art reconciliation",
          flush=True)


if __name__ == "__main__":
    main()
