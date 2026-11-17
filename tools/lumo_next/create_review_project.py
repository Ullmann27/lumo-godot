#!/usr/bin/env python3
"""Build a bounded review project with exact product sources and dependencies.

This does not substitute scene implementations or gameplay autoloads. Only
unvisited routes in the unchanged SceneRouter dictionary are omitted from the
copied resource closure; the production lesson route and every actual asset
remain present. The review manifest records all copied byte digests.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    source = args.source.resolve()
    destination = args.destination.resolve()
    if destination == source or source in destination.parents:
        raise SystemExit("Use a separate scratch review directory.")
    destination.mkdir(parents=True, exist_ok=True)
    project = (source / "project.godot").read_text()
    pending = ["project.godot", "icon.svg", "scenes/learning/learning_world.tscn"]
    pending += re.findall(r'="\*res://([^"\n]+)"', project)
    pending += [str(path.relative_to(source)) for root in ["scripts/lumo_next", "tests/lumo_next", "assets/lumo_next"] for path in (source / root).rglob("*") if path.is_file() and not path.name.endswith((".import", ".uid"))]
    pending += ["scripts/tests/learning_world_regression.gd", "scripts/tests/learning_sharing_regression.gd", "scripts/tests/learning_world_capture.gd", "tools/lumo_next/capture_learning_scene.gd", "assets/audio/voice/words/apfel.wav"]
    copied: dict[str, str] = {}
    omitted: list[str] = []
    while pending:
        relative = pending.pop()
        if relative in copied:
            continue
        path = source / relative
        if not path.is_file():
            if relative not in omitted:
                omitted.append(relative)
            continue
        data = path.read_bytes()
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        copied[relative] = hashlib.sha256(data).hexdigest()
        sidecar = path.with_suffix(path.suffix + ".import")
        if sidecar.is_file():
            shutil.copy2(sidecar, destination / (relative + ".import"))
        if path.suffix not in {".gd", ".tscn", ".tres", ".godot", ".gdshader"}:
            continue
        for match in re.findall(r'res://([^"\n\s\)]+)', data.decode("utf-8")):
            if any(symbol in match for symbol in ["%", "{", "*", "'", "`"]) or match.endswith("/"):
                continue
            if relative == "scripts/app/scene_router.gd" and match.endswith(".tscn") and match != "scenes/learning/learning_world.tscn":
                continue
            if (source / match).is_file():
                pending.append(match)
    review = project.replace('run/main_scene="res://scenes/app/boot.tscn"', 'run/main_scene="res://scenes/learning/learning_world.tscn"')
    (destination / "project.godot").write_text(review)
    report = {"source": str(source), "file_count": len(copied), "sha256": copied, "not_found": omitted, "project_override": "Only main_scene points directly at the unchanged production learning route."}
    (destination / "review_sources.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"review_project": str(destination), "files": len(copied), "missing_optional": omitted}))


if __name__ == "__main__":
    main()
