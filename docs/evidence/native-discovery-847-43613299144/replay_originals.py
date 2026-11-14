#!/usr/bin/env python3
"""Replay the exact archived readers and original workflow Python blocks; no engine."""

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

import PIL
import yaml


ROOT = Path(__file__).resolve().parent
ORIGINALS = ROOT / "originals"
REPLAY = ROOT / "replay"
SOURCE_SHA = "84789d0c2c6fb4b6ecd2897ce1951b89f958b604"
SOURCE_TREE = "91cc8fc1c6f8a36336b7ac9a12585284a983a6f6"
WORKFLOW = Path("/workspace/scratch/909ddb52fe7b/native-upstream-057-review/trigger-patch/.github/workflows/lumo-discovery-connections.yml")
EXPECTED_WORKFLOW_BLOB = "02940ea1a3698d14b8fabaed4d5ee7af5b24907b"
HELPERS = {
    "verify_discovery_connections.py": "c00ca9873106c974d66282cddfdcfaf5eb3bbebc",
    "collect_discovery_connections.py": "1ebdec66300dfb87bf9287d194525d3c374c8aee",
    "verify_discovery_rasters.py": "219e691fc8aa119cc80221b3db6c77e63caf8bfe",
    "verify_dream_rasters.py": "da8eed7d6383fcbc82a03596518a5fcc3b9a00c5",
    "run_godot_probe.py": "c23859ece2d62101d000d7a89556fda5d3fe4105",
}


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + bytes([0]) + data).hexdigest()


def main():
    REPLAY.mkdir(exist_ok=False)
    helpers = ORIGINALS / "discovery/helpers"
    identities = []
    for name, expected in HELPERS.items():
        data = (helpers / name).read_bytes()
        assert git_blob(data) == expected, name
        identities.append({"name": name, "git_blob": expected,
                           "sha256": hashlib.sha256(data).hexdigest()})
    workflow_bytes = WORKFLOW.read_bytes()
    assert git_blob(workflow_bytes) == EXPECTED_WORKFLOW_BLOB
    workflow = yaml.load(workflow_bytes, Loader=yaml.BaseLoader)
    steps = workflow["jobs"]["discovery-native-acceptance"]["steps"]
    environment = os.environ | {
        "PYTHONDONTWRITEBYTECODE": "1", "GIT_OPTIONAL_LOCKS": "0",
        "LUMO_EXPECTED_NATIVE_SHA": SOURCE_SHA,
        "LUMO_EXPECTED_NATIVE_TREE": SOURCE_TREE,
    }
    results = []

    def run(name, command, extra_environment=None):
        begin = time.monotonic()
        with (REPLAY / (name + ".log")).open("xb") as output:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                    env=environment | (extra_environment or {}), timeout=180)
        record = {"name": name, "command": command, "exit": result.returncode,
                  "elapsed_seconds": round(time.monotonic() - begin, 3),
                  "log": name + ".log"}
        results.append(record)
        (REPLAY / "partial-results.json").write_text(json.dumps(results, indent=2) + "\n")
        assert result.returncode == 0, record

    run("dream-read-only", [sys.executable, "-B", str(helpers / "verify_dream_rasters.py"),
                           str(ORIGINALS / "dream")])
    run("discovery-read-only", [sys.executable, "-B", str(helpers / "verify_discovery_connections.py"),
                               str(ORIGINALS / "discovery"), "--expected-native-sha", SOURCE_SHA,
                               "--expected-native-tree", SOURCE_TREE])

    # The unmodified Minimap block validates absolute original report paths.
    # Recreate only this unique CI-run namespace with independent copies. The
    # downloaded originals remain read-only and are never removed or rewritten.
    context = json.loads((ORIGINALS / "discovery/collection-context.json").read_text())
    ci_discovery = Path(context["output"])
    expected_ci = Path("/home/runner/work/_temp/lumo-discovery-43613299144-1/evidence/discovery")
    assert ci_discovery == expected_ci
    namespace = ci_discovery.parent.parent
    assert not namespace.exists() and not namespace.is_symlink()
    namespace.mkdir(parents=True, exist_ok=False)
    reader_project = REPLAY / "reader-source"
    (reader_project / "tools").mkdir(parents=True)
    for name in HELPERS:
        shutil.copyfile(helpers / name, reader_project / "tools" / name)

    inline = (
        ("Require exact village save schema and bounded original renderer evidence",
         "village-scaling", "LUMO_VILLAGE_OUTPUT", "village-scaling-acceptance.json"),
        ("Render the exact MobileSafeArea and live minimap observations",
         "mobile-minimap", "LUMO_MINIMAP_OUTPUT", "mobile-minimap-acceptance.json"),
    )
    for step_name, directory, variable, report_name in inline:
        matching = [step for step in steps if step.get("name") == step_name]
        assert len(matching) == 1
        run_text = matching[0]["run"]
        marker = "<<'PY'\n"
        assert run_text.count(marker) == 1
        code = run_text.split(marker, 1)[1]
        assert code.endswith("PY\n")
        code = code[:-3]
        script = REPLAY / (directory + "-original-workflow-block.py")
        script.write_text(code)
        destination = namespace / "evidence" / directory
        shutil.copytree(ORIGINALS / directory, destination)
        (destination / report_name).unlink()  # Only the independent replay copy.
        run(directory + "-original-block", [sys.executable, "-B", str(script)],
            {variable: str(destination), "GITHUB_WORKSPACE": str(reader_project)})
        original_report = (ORIGINALS / directory / report_name).read_bytes()
        replay_report = (destination / report_name).read_bytes()
        assert replay_report == original_report, "Recomputed original report bytes differ: " + directory
        results[-1]["recomputed_report_byte_equal_to_original"] = True
        results[-1]["original_report_sha256"] = hashlib.sha256(original_report).hexdigest()
        results[-1]["exact_workflow_python_block_sha256"] = hashlib.sha256(code.encode()).hexdigest()
        shutil.copyfile(destination / report_name, REPLAY / report_name)

    inventory = json.loads((ROOT / "artifact-manifest.json").read_text())
    for record in inventory["files"]:
        data = (ORIGINALS / record["path"]).read_bytes()
        assert len(data) == record["bytes"]
        assert hashlib.sha256(data).hexdigest() == record["sha256"], record["path"]
        assert git_blob(data) == record["git_blob"], record["path"]
    names = {p.relative_to(ORIGINALS).as_posix() for p in ORIGINALS.rglob("*") if p.is_file()}
    assert names == {record["path"] for record in inventory["files"]}
    report = {
        "source_commit": SOURCE_SHA, "source_tree": SOURCE_TREE,
        "python": sys.version, "pillow": PIL.__version__, "platform": platform.platform(),
        "ci_pillow": "12.3.0", "readers": identities,
        "workflow_git_blob": EXPECTED_WORKFLOW_BLOB, "replays": results,
        "all_original_files_unchanged": len(inventory["files"]),
        "original_names_unchanged": True, "engine_invocations": 0,
        "copied_original_ci_namespace": str(namespace),
        "scope": "Original-reader replay only; independent copies for the two unchanged workflow blocks; no Android/FPS claim",
    }
    (REPLAY / "replay-summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
