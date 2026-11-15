"""Render approved complete theme exports with a measured CPU preview budget."""
import argparse
import json
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--themes", nargs="+", required=True)
    args = parser.parse_args()
    repo = args.repo.resolve()
    for theme in args.themes:
        verification = repo / "assets/kart/production/tracks" / theme / "blender_reimport_verification.json"
        deadline = time.monotonic() + 600
        while not verification.exists():
            if time.monotonic() > deadline:
                raise RuntimeError(f"No verified export arrived for {theme}")
            time.sleep(1)
        if json.loads(verification.read_text())["status"] != "PASS":
            raise RuntimeError(f"Verification did not pass for {theme}")
        for view, width, height, samples in (("portal",1280,800,16),("interior",960,600,8)):
            log_path = repo / "evidence/lumo_kart_art/tracks" / f"{theme}_{view}_render.log"
            command = ["blender", "-b", "-t", "2", "--python-exit-code", "1", "--python", "tools/lumo_kart_art/tracks/render_tunnel_review.py", "--", "--repo", str(repo), "--theme", theme, "--views", view, "--width", str(width), "--height", str(height), "--samples", str(samples), "--threads", "2"]
            with log_path.open("w") as log:
                subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, check=True)
            print(json.dumps(dict(theme=theme, view=view, width=width, height=height, samples=samples)), flush=True)


if __name__ == "__main__":
    main()
