import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("label")
parser.add_argument("--production", choices=["baseline", "candidate"], required=True)
parser.add_argument("--rendered", action="store_true")
args = parser.parse_args()
stage = Path("/home/agent/lumo-kart-minimap-2708")
source = stage / "source"
directory = stage / "evidence" / args.label
directory.mkdir()
expected_test = "6c58c08b8c47a7bf7c957c448b88474a984b9509"
expected_production = {
    "baseline": "f7473190f51fb5dbda7d0f7ad7292f8ec64c0da2",
    "candidate": "83b3b6b548cffa2790c582e061a74e37bbfcf356",
}[args.production]
paths = ["scripts/games/kart_island.gd", "scripts/tests/mobile_safe_area_regression.gd"]

def identify(relative):
    data = (source / relative).read_bytes()
    return {
        "path": relative,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest(),
    }

before = [identify(p) for p in paths]
if before[0]["git_blob"] != expected_production or before[1]["git_blob"] != expected_test:
    raise SystemExit("Exact production/test identity does not match")
head = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
if head != "f052c2795b765265dbb6f5c27b9e92b557d39a39":
    raise SystemExit("Unexpected isolated base HEAD")
env = os.environ.copy()
env["XDG_DATA_HOME"] = str(stage / ("user-" + args.label))
env["LUMO_CAPTURE_DIR"] = str(directory)
command = ["godot", "--path", str(source), "--rendering-method", "gl_compatibility"]
if not args.rendered:
    command += ["--headless"]
else:
    if not env.get("DISPLAY"):
        raise SystemExit("Rendered run requires an actual display")
    env["LUMO_KART_MINIMAP_CAPTURE_DIR"] = str(directory / "kart-originals")
command += ["--script", "res://scripts/tests/mobile_safe_area_regression.gd"]
if args.rendered:
    command += ["--", "--capture"]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
clock = time.monotonic()
log = directory / "run.log"
with log.open("w") as output:
    try:
        result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=180)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
after = [identify(p) for p in paths]
report = directory / "mobile-safe-area.json"
document = json.loads(report.read_text()) if report.is_file() else None
data = log.read_bytes()
record = {
    "label": args.label,
    "base_head": head,
    "production": args.production,
    "before": before,
    "after": after,
    "source_unchanged": before == after,
    "command": command,
    "environment": {k: env.get(k) for k in ["DISPLAY", "XDG_DATA_HOME", "LUMO_CAPTURE_DIR", "LUMO_KART_MINIMAP_CAPTURE_DIR"]},
    "started_utc": started,
    "seconds": round(time.monotonic() - clock, 3),
    "engine_exit_code": code,
    "log": str(log),
    "log_bytes": len(data),
    "log_sha256": hashlib.sha256(data).hexdigest(),
    "report_present": document is not None,
    "checks": document.get("checks") if document else None,
    "failures": document.get("failures") if document else None,
    "report_sha256": hashlib.sha256(report.read_bytes()).hexdigest() if report.is_file() else None,
}
(directory / "run.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
print(data.decode("utf-8", errors="replace")[-8000:])
if before != after:
    raise SystemExit("Source changed during the probe")
raise SystemExit(code)
