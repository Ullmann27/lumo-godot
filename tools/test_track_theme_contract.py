#!/usr/bin/env python3
"""Run the real detail/theme scripts in a small, asset-free Godot project.

This contract test does not launch the game, autoloads, a renderer or Android.
Its mesh factory is extracted unchanged from kart_world.gd so footprint checks
follow the runtime primitive dimensions rather than separately guessed sizes.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[1]
    files = [
        Path("scripts/games/kart_track_detail.gd"),
        Path("scripts/games/kart_world_meshes.gd"),
        Path("scripts/games/kart_landmarks.gd"),
        Path("scripts/games/kart_volcano_mesh.gd"),
        Path("scripts/games/kart_tracks.gd"),
        Path("scripts/games/kart_expansion_tracks.gd"),
        Path("scripts/games/kart_sonnenhafen_long_course.gd"),
        Path("scripts/tests/kart_track_theme_contract.gd"),
    ]
    files.extend(sorted(path.relative_to(repository) for path in
                        (repository / "scripts/games/track_themes").glob("*.gd")))
    original = subprocess.run(
        ["git", "show", "a81ddf12d594cc252caef7503162e89c6b26e1c7:scripts/games/kart_track_detail.gd"],
        cwd=repository, text=True, capture_output=True, check=True,
    ).stdout
    source = (repository / "scripts/games/kart_world.gd").read_text()
    start = source.index("func _shape(kind: String) -> Mesh:")
    end = source.index("\nfunc _prop(", start)
    factory = (
        "extends RefCounted\n"
        'const LANDMARKS = preload("res://scripts/games/kart_landmarks.gd")\n'
        'const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")\n'
        "var meshes: Dictionary = {}\n"
        "var low_detail: bool = false\n\n" + source[start:end] + "\n"
    )
    with tempfile.TemporaryDirectory(prefix="lumo-track-contract-") as temporary:
        project = Path(temporary)
        for relative in files:
            destination = project / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(repository / relative, destination)
        (project / "scripts/tests/runtime_mesh_factory.gd").write_text(factory)
        (project / "scripts/tests/legacy_track_detail.gd").write_text(original)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Lumo Track Contract"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        )
        result = subprocess.run(
            [args.godot, "--headless", "--quit-after", "8", "--path", str(project),
             "--script", "res://scripts/tests/kart_track_theme_contract.gd"],
            text=True, capture_output=True, timeout=45,
        )
        print(result.stdout, end="")
        print(result.stderr, end="")
        if result.returncode != 0:
            return result.returncode
        # Godot may return 0 after an assertion or script error; require a
        # completion marker and reject parser/runtime failures explicitly.
        combined = result.stdout + result.stderr
        if "[TrackThemeContract] PASS" not in combined:
            return 1
        if "SCRIPT ERROR:" in combined or "Parse Error:" in combined:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
