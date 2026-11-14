from __future__ import annotations

from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess

from replay_live_discovery import strict_json

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "original-artifact" / "extracted"
READERS = ROOT / "reader-sources"
OUTPUT = ROOT / "read-only-replay"
SHA = "e9a9f60f20403ffa6b2b26d1437f958b2704d2aa"
TREE = "1c2b5da7a4485cb8b911adcac2b567481cf902b5"
ERROR = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit|\[ProbeRunner\] (?:FAIL|timeout)")


def identities(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": path.relative_to(DATA).as_posix(), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def roster(path: Path, prefix: str) -> list[list[str]]:
    return [shlex.split(line.strip()) for line in path.read_text().replace("\\\n", " ").splitlines()
            if line.strip().startswith(prefix + " ")]


def checked_log(path: Path, marker: str, exact: bool) -> dict:
    lines = path.read_text().splitlines()
    errors = [{"line": index + 1, "text": text} for index, text in enumerate(lines) if ERROR.search(text)]
    if errors:
        raise ValueError(f"Original error/leak markers in {path}: {errors}")
    matches = [{"line": index + 1, "text": text} for index, text in enumerate(lines)
               if (text == marker if exact else marker in text)]
    if not matches:
        raise ValueError(f"Original success marker absent in {path}: {marker}")
    if not any("Godot Engine v4.6.3.stable.official.7d41c59c4" in line for line in lines):
        raise ValueError(f"Original Godot version header absent in {path}")
    return {**identities(path), "required_marker": marker, "marker_match": "exact" if exact else "original runner substring",
            "actual_marker_lines": matches, "error_or_leak_matches": errors}


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    if (DATA / "source-sha.txt").read_text() != SHA + "\n":
        raise ValueError("Global original source differs")
    expected = roster(READERS / "validate_nextgen.sh", "check_probe")
    if len(expected) != 52:
        raise ValueError("Pinned Nextgen source does not contain exactly 52 original probe calls")
    wanted_tsv = "probe\tmode\tresult\n" + "".join(f"{x[1]}\t{x[3]}\tPASS\n" for x in expected)
    if (DATA / "nextgen/results.tsv").read_text() != wanted_tsv:
        raise ValueError("Original Nextgen results differ from full pinned 52-probe roster/order")
    nextgen = [checked_log(DATA / "nextgen" / f"{x[1]}-{x[3]}.log", x[2], False) for x in expected]
    jump = next(x for x in nextgen if "lumo_original_jump_visual_regression-headless.log" in x["path"])
    jump["interpretation"] = "Actual current headless probe checks imported original rig, 65 bones, original visible, old procedural node hidden, movement/pause/resume. This alone is not a raster or Android identity claim."

    ci_dream = (DATA / "dream/capture-root.txt").read_text().strip()
    if not ci_dream.endswith("/dream"):
        raise ValueError("Unexpected original CI capture root")
    ci_parent = ci_dream.rsplit("/", 1)[0]
    live_rows = roster(READERS / "validate_live_connections.sh", "probe")
    discovery_rows = roster(READERS / "validate_discovery_connections.sh", "probe")
    if len(live_rows) != 9 or len(discovery_rows) != 10:
        raise ValueError("Pinned Live/Discovery roster counts differ")
    live = [checked_log(DATA / "live" / f"{x[1]}-{x[2]}.log", x[3].replace("$LOG_DIR", ci_parent + "/live"), True) for x in live_rows]
    discovery = [checked_log(DATA / "discovery" / f"{x[1]}-{x[2]}.log", x[4], True) for x in discovery_rows]
    returned = checked_log(DATA / "connect-four-return.log", "CONNECT_FOUR_RETURN_PASS checks=21", True)
    return_lines = (DATA / "connect-four-return.log").read_text().splitlines()
    if sum(x.startswith("CONNECT_FOUR_RETURN_") for x in return_lines) != 1:
        raise ValueError("Return evidence requires exactly one original status marker")

    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    listing = subprocess.check_output(["git", "ls-tree", "-r", "-z", SHA],
                                      cwd="/workspace/scratch/909ddb52fe7b/lumo-native-accepted", env=env)
    expected_tree = {}
    for item in listing.split(b"\0"):
        if not item:
            continue
        heading, name = item.split(b"\t", 1)
        mode, kind, blob = heading.decode().split()
        expected_tree[name.decode()] = {"mode": mode, "type": kind, "sha": blob}
    inventories = []
    for phase in ("before", "after"):
        path = DATA / "dream" / f"source-inventory-{phase}.json"
        document = strict_json(path)
        rows = document["tracked"]
        if document["head"] != SHA or document["tree"] != TREE:
            raise ValueError("Dream source inventory revision differs")
        if len(rows) != len(expected_tree) or {x["path"] for x in rows} != set(expected_tree):
            raise ValueError("Dream source inventory does not cover complete committed tree")
        for row in rows:
            source = expected_tree[row["path"]]
            if (row["git_blob"] != source["sha"] or row["actual_blob"] != source["sha"]
                    or row["mode"] != source["mode"] or row["skip_worktree"] is not False
                    or row["materialized"] is not True):
                raise ValueError(f"Original materialized source/index does not match Git tree: {row['path']}")
        inventories.append(document)
    if inventories[0]["tracked"] != inventories[1]["tracked"] or inventories[0]["index_sha256"] != inventories[1]["index_sha256"]:
        raise ValueError("Original complete source/index changed during Dream")

    endmarkers = {
        "nextgen-runner.log": "[LumoNextgen52] PASS: all 48 previous modes plus four Studio2020 modes and 17 bound rasters/movie/sidecars",
        "dream-runner.log": "[LumoDreamConnections] PASS 5 original probes and 7 verified renderer PNGs",
        "live-runner.log": "[LumoLiveConnections] PASS 9 original probes and 7 verified renderer PNGs",
        "discovery-runner.log": "[LumoDiscoveryConnections] PASS 10 original probes and 38 verified renderer PNGs",
    }
    ends = [checked_log(DATA / path, marker, True) for path, marker in endmarkers.items()]
    scanned_logs = []
    for path in sorted(DATA.rglob("*.log")):
        relative = path.relative_to(DATA).as_posix()
        if any(component in relative.split("/") for component in ("user-data", "user-cache", "user-config", "cache", "shader_cache")):
            continue
        lines = path.read_text(errors="strict").splitlines()
        failures = [{"line": i + 1, "text": line} for i, line in enumerate(lines) if ERROR.search(line)]
        if failures:
            raise ValueError(f"Original native evidence log has error/leak markers: {relative}: {failures}")
        scanned_logs.append(identities(path))
    project = (DATA / "project.log").read_text().splitlines()
    warnings = [{"line": i + 1, "text": line} for i, line in enumerate(project) if "[WARN]" in line]
    if len(warnings) != 7 or "SUMMARY: 117 PASS / 7 WARN / 0 FAIL" not in project:
        raise ValueError("Original Project warning summary differs from observed contract")

    report = {
        "schema": 1, "host_source": "1e22d2455937e2640d1e44e153d290746f3afe49",
        "native_source": SHA, "native_tree": TREE, "run_id": 43596913210,
        "job_id": 132454178537, "artifact_id": 14118079396,
        "nextgen": {"exact_roster_matches": True, "probes": 52, "original_results": identities(DATA / "nextgen/results.tsv"), "logs": nextgen},
        "jump_original_normal_path": jump,
        "return": returned,
        "live": {"probes": 9, "logs": live},
        "discovery": {"probes": 10, "logs": discovery},
        "original_final_markers": ends,
        "dream_source_tree_binding": {
            "original_tracked_files_each_phase": len(expected_tree),
            "all_original_bytes_and_modes_match_committed_git_blobs": True,
            "all_files_materialized_without_skip_worktree": True,
            "before_after_tracked_and_index_equal": True,
            "original_untracked_inventory_each_phase": [dict(Counter(x["category"] for x in v["untracked_import_inventory"])) for v in inventories],
        },
        "original_engine_error_scan": {"scanned_logs": len(scanned_logs), "matches": [], "files": scanned_logs},
        "project": {"pass": 117, "warn": 7, "fail": 0, "original_warnings": warnings},
        "new_engine_or_renderer_executions": 0,
        "scope": "Original CI logs/source inventories plus unchanged image/report reader replays; no Android or physical FPS acceptance inferred.",
    }
    (OUTPUT / "complete-original-contract-review.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"nextgen_probes": len(nextgen), "live_probes": len(live), "discovery_probes": len(discovery),
                      "return_checks": 21, "jump_original_marker": jump["actual_marker_lines"],
                      "dream_source_tree_binding": report["dream_source_tree_binding"],
                      "original_logs_scanned": len(scanned_logs), "engine_error_or_leak_matches": 0,
                      "project": {"pass": 117, "warn": 7, "fail": 0}}, indent=2))


if __name__ == "__main__":
    main()
