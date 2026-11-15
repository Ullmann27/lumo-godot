import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

STAGE = Path("/home/agent/lumo-kart-dream-merge-2708")
SOURCE = STAGE / "source"
DREAM = "bd0712259bb64908a5649ee1999638826c9eb597"
DREAM_TREE = "2eb628d3e3a327ee8985385130c96168db7aa852"
OVERRIDES = {
    "scripts/games/kart_island.gd": "83b3b6b548cffa2790c582e061a74e37bbfcf356",
    "scripts/tests/mobile_safe_area_regression.gd": "6c58c08b8c47a7bf7c957c448b88474a984b9509",
}
DEPENDENCIES = [
    "project.godot",
    "scripts/learning/learning_atelier.gd",
    "scripts/learning/lumo_dream_props.gd",
    "scripts/systems/render/lumo_environment.gd",
    "scripts/systems/render/lumo_environment_creative_presets.gd",
    "scripts/systems/render/lumo_dream_ambience.gd",
    "assets/shaders/lumo_dream_ambience.gdshader",
    "assets/dream_garden/dream_blossom.glb",
    "assets/dream_garden/dream_storybook.glb",
    "tools/validate_nextgen.sh",
    "tools/validate_dream_connections.sh",
    "tools/verify_dream_rasters.py",
    ".github/workflows/lumo-dream-connections.yml",
]

def git(*args):
    return subprocess.check_output(["git", "-C", str(SOURCE), *args], text=True).strip()

def identity(path):
    data = (SOURCE / path).read_bytes()
    return {
        "path": path, "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest(),
    }

def snapshot():
    if git("rev-parse", "HEAD") != DREAM or git("rev-parse", "HEAD^{tree}") != DREAM_TREE:
        raise RuntimeError("Unexpected isolated source commit/tree")
    rows = []
    missing = []
    expected = {}
    index = subprocess.check_output(["git", "-C", str(SOURCE), "ls-files", "--stage", "-z"])
    for record in index.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, sha, stage = metadata.decode().split()
        path = raw_path.decode()
        if stage != "0":
            raise RuntimeError("Unmerged source entry: " + path)
        expected[path] = OVERRIDES.get(path, sha)
        file = SOURCE / path
        if not file.exists():
            missing.append(path)
            continue
        if file.is_symlink() or not file.is_file():
            raise RuntimeError("Unsupported source file type: " + path)
        item = identity(path)
        if item["git_blob"] != expected[path]:
            raise RuntimeError("Source differs from the exact merged inputs: " + path)
        rows.append(item)
    for path in [*OVERRIDES, *DEPENDENCIES]:
        if path in missing or path not in expected:
            raise RuntimeError("Required merge source absent: " + path)
    raw = (json.dumps(rows, sort_keys=True, separators=(",", ":")) + "\n").encode()
    return {
        "head": DREAM, "head_tree": DREAM_TREE,
        "tracked_materialized_count": len(rows),
        "tracked_sparse_absent_count": len(missing),
        "inventory_sha256": hashlib.sha256(raw).hexdigest(),
        "important_sources": [r for r in rows if r["path"] in OVERRIDES or r["path"] in DEPENDENCIES],
    }

parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["import", "probe"])
args = parser.parse_args()
directory = STAGE / "evidence" / ("integration-" + args.mode)
directory.mkdir()
before = snapshot()
env = os.environ.copy()
for key in ["LUMO_KART_MINIMAP_CAPTURE_DIR", "LUMO_CAPTURE_DIR", "DISPLAY"]:
    env.pop(key, None)
env["XDG_DATA_HOME"] = str(STAGE / ("user-integration-" + args.mode))
if args.mode == "import":
    command = ["godot", "--headless", "--editor", "--path", str(SOURCE), "--import", "--quit"]
else:
    env["LUMO_CAPTURE_DIR"] = str(directory)
    command = [
        "godot", "--path", str(SOURCE), "--rendering-method", "gl_compatibility",
        "--headless", "--script", "res://scripts/tests/mobile_safe_area_regression.gd",
    ]
version = subprocess.check_output(["godot", "--version"], text=True).strip()
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
clock = time.monotonic()
log = directory / "run.log"
with log.open("w") as output:
    try:
        result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
after = snapshot()
data = log.read_bytes()
report = directory / "mobile-safe-area.json"
document = json.loads(report.read_text()) if report.is_file() else None
record = {
    "purpose": "one exact existing SafeArea probe on combined Dream and reviewed minimap source",
    "mode": args.mode,
    "base_head": DREAM,
    "source_overrides": OVERRIDES,
    "before": before, "after": after,
    "sources_unchanged": before == after,
    "engine_version": version,
    "command": command,
    "environment": {key: env.get(key) for key in [
        "XDG_DATA_HOME", "DISPLAY", "LUMO_CAPTURE_DIR", "LUMO_KART_MINIMAP_CAPTURE_DIR"
    ]},
    "started_utc": started,
    "seconds": round(time.monotonic() - clock, 3),
    "exit_code": code,
    "log_bytes": len(data),
    "log_sha256": hashlib.sha256(data).hexdigest(),
    "report_present": document is not None,
    "checks": document.get("checks") if document else None,
    "failures": document.get("failures") if document else None,
    "report_sha256": hashlib.sha256(report.read_bytes()).hexdigest() if report.is_file() else None,
    "rendered_capture_requested": False,
}
(directory / "run.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
print(data.decode("utf-8", errors="replace")[-10000:])
if before != after:
    raise SystemExit("Tracked source changed during the integration run")
raise SystemExit(code)
