from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
ORIGINAL = ROOT / "original-artifact" / "extracted"
READERS = ROOT / "reader-sources"
OUTPUT = ROOT / "read-only-replay"
SOURCE = "e9a9f60f20403ffa6b2b26d1437f958b2704d2aa"
TREE = "1c2b5da7a4485cb8b911adcac2b567481cf902b5"


def strict_json(path: Path):
    def pairs(values):
        result = {}
        for key, value in values:
            if key in result:
                raise ValueError(f"Duplicate JSON key in {path}: {key}")
            result[key] = value
        return result

    def constant(value):
        raise ValueError(f"Non-finite JSON constant in {path}: {value}")

    return json.loads(path.read_text(), object_pairs_hook=pairs, parse_constant=constant)


def identity(path: Path) -> dict:
    data = path.read_bytes()
    return {
        "path": str(path.relative_to(ROOT)),
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest(),
    }


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    original_live = ORIGINAL / "live"
    live_copy = OUTPUT / "live-original-copy"
    if live_copy.exists():
        raise ValueError("Live replay target already exists; no original or replay overwrite")
    shutil.copytree(original_live / "captures", live_copy / "captures")
    runner = READERS / "validate_live_connections.sh"
    if identity(runner)["git_blob"] != "047c48b60af8ea8c1ed91426604cdb0e5dac7299":
        raise ValueError("Original Live runner bytes differ")
    source = runner.read_text()
    python_body = source.split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0] + "\n"
    heredoc = OUTPUT / "live-original-heredoc.py"
    heredoc.write_text(python_body)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_OPTIONAL_LOCKS="0")
    completed = subprocess.run(
        [sys.executable, str(heredoc), str(live_copy)],
        cwd="/workspace/scratch/909ddb52fe7b/lumo-native-accepted",
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    (OUTPUT / "live-original-heredoc-replay.log").write_bytes(completed.stdout)
    if completed.returncode != 0:
        raise ValueError(f"Unchanged Live reader failed with exit {completed.returncode}")
    live_manifest = strict_json(original_live / "live-connections.json")
    recomputed_live = strict_json(live_copy / "live-connections.json")
    if live_manifest != recomputed_live or live_manifest["native_source"] != SOURCE:
        raise ValueError("Original Live manifest differs from exact reader replay or Native source")
    if type(live_manifest["probes"]) is not int or live_manifest["probes"] != 9:
        raise ValueError("Live probe count differs")
    if len(live_manifest["original_pngs"]) != 7 or live_manifest["physical_android_fps_measured"] is not False:
        raise ValueError("Live PNG count or device-performance scope differs")

    discovery_reader = READERS / "verify_discovery_rasters.py"
    if identity(discovery_reader)["git_blob"] != "219e691fc8aa119cc80221b3db6c77e63caf8bfe":
        raise ValueError("Original Discovery reader bytes differ")
    specification = importlib.util.spec_from_file_location("original_discovery_reader", discovery_reader)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    discovery = ORIGINAL / "discovery"
    records = module.verify(discovery)
    manifest = strict_json(discovery / "discovery-connections.json")
    expected = {
        "schema": 1,
        "native_source": SOURCE,
        "native_tree": TREE,
        "probes": 10,
        "original_pngs": records,
        "physical_android_fps_measured": False,
    }
    if manifest != expected:
        raise ValueError("Original Discovery manifest differs from unchanged reader replay or source")
    if len(records) != 38 or type(manifest["probes"]) is not int:
        raise ValueError("Discovery original count/type differs")

    report = {
        "schema": 1,
        "native_source": SOURCE,
        "native_tree": TREE,
        "method": "Unchanged original Live heredoc on a separate capture copy; unchanged Discovery.verify on original files; no renderer or runtime launch",
        "live": {"probes": 9, "original_pngs": 7, "exact_manifest_equal": True, "exit_code": completed.returncode,
                 "reader": identity(runner), "heredoc": identity(heredoc),
                 "transcript": identity(OUTPUT / "live-original-heredoc-replay.log")},
        "discovery": {"probes": 10, "original_pngs": 38, "exact_manifest_equal": True,
                      "mandatory_original_hub_identity_checked": True,
                      "reader": identity(discovery_reader)},
        "new_engine_or_renderer_executions": 0,
        "physical_android_fps_measured": False,
    }
    (OUTPUT / "live-discovery-replay.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
