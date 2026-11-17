"""Run isolated Blender production and independent verification theme by theme."""
import argparse
import json
from pathlib import Path
import subprocess
import time

THEMES = ["zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple", "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway", "desert_drift", "learning_lab"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--themes", nargs="+", default=THEMES)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    repo = args.repo.resolve()
    evidence = repo / "evidence/lumo_kart_art/tracks"
    evidence.mkdir(parents=True, exist_ok=True)
    for theme in args.themes:
        if theme not in THEMES:
            raise ValueError(f"Unknown track theme: {theme}")
        start = time.monotonic()
        commands = [
            ("build", ["blender", "-b", "-t", "3", "--python-exit-code", "1", "--python", "tools/lumo_kart_art/tracks/build_tunnel_kit.py", "--", "--repo", str(repo), "--themes", theme]),
            ("verify", ["blender", "-b", "-t", "1", "--python-exit-code", "1", "--python", "tools/lumo_kart_art/tracks/verify_tunnel_kit.py", "--", "--assets", f"assets/kart/production/tracks/{theme}"]),
        ]
        if args.render:
            commands.append(("render", ["blender", "-b", "-t", "3", "--python-exit-code", "1", "--python", "tools/lumo_kart_art/tracks/render_tunnel_review.py", "--", "--repo", str(repo), "--theme", theme, "--views", "portal", "interior", "--width", "1280", "--height", "800", "--samples", "16"]))
        for stage, command in commands:
            with (evidence / f"{theme}_{stage}.log").open("w") as log:
                subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, check=True)
            print(json.dumps(dict(theme=theme, stage=stage, elapsed_seconds=round(time.monotonic()-start,1))), flush=True)
        old = repo / "assets/kart/production/tracks" / theme / "textures"
        for role in ("inner", "outer"):
            png, jpg = old / f"{theme}_{role}_albedo.png", old / f"{theme}_{role}_albedo.jpg"
            if png.exists() and jpg.exists():
                png.unlink()


if __name__ == "__main__":
    main()
