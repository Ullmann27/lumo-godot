#!/usr/bin/env python3
"""Run bounded real-world theme checks with isolated test data and exact sources.

This geometry runner does not approve camera appearance or device performance.
Coordinate shared resources before running it alongside another engine job.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


TRACK_IDS = (
    "zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple",
    "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway",
    "desert_drift", "learning_lab",
)
GROUND_TRACKS = frozenset({
    "crystal_canyon", "jungle_temple", "winter_sprint", "desert_drift", "learning_lab",
})
ERROR_LINE = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|Shader Error:)")
PASS_LINE = re.compile(
    r"(?m)^\[ThemeWorld\] PASS cases=(\d+) checks=(\d+) support_probes=(\d+);"
)
CASE_LINE = re.compile(
    r"(?m)^\[ThemeWorld\] CASE (?P<track>[a-z_]+)/(?P<quality>light|full) "
    r"accepted=(?P<accepted>\d+) unaccepted_slots=(?P<unaccepted_slots>\d+) "
    r"parts=(?P<parts>\d+) support=(?P<support>geometry_probed|NOT_ASSESSED) "
    r"support_probes=(?P<support_probes>\d+) failures=(?P<failures>\d+)\s*$"
)


def git_output(repository: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments], cwd=repository, text=True, capture_output=True,
        timeout=10, check=True,
    )
    return result.stdout.strip()


def as_text(value: str | bytes | None) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value or ""


def snapshot_changes(repository: Path, output: Path) -> list[dict[str, str]]:
    """Retain exact changed runtime sources, including uncommitted fixes."""
    tracked = git_output(repository, "diff", "HEAD", "--name-only").splitlines()
    untracked = git_output(repository, "ls-files", "--others", "--exclude-standard").splitlines()
    entries: list[dict[str, str]] = []
    runtime_extensions = {".gd", ".py", ".gdshader", ".tres", ".tscn", ".godot", ".uid"}
    for relative in sorted(set(tracked + untracked)):
        source = repository / relative
        if not source.is_file() or source.suffix not in runtime_extensions:
            continue
        if not source.resolve().is_relative_to(repository):
            raise ValueError("Changed runtime source escapes repository: " + relative)
        data = source.read_bytes()
        destination = output / "source_snapshot" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        entries.append({"path": relative, "sha256": hashlib.sha256(data).hexdigest()})
    patch = subprocess.run(
        ["git", "diff", "--binary", "HEAD"], cwd=repository, capture_output=True,
        timeout=10, check=True,
    ).stdout
    (output / "tracked_changes.patch").write_bytes(patch)
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--track", choices=(*TRACK_IDS, "all"), default="learning_lab")
    parser.add_argument("--quality", choices=("light", "full", "both"), default="light")
    parser.add_argument("--out", required=True, type=Path, help="New evidence directory; never overwritten")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout-seconds", default=120, type=int)
    args = parser.parse_args()
    if not 1 <= args.timeout_seconds <= 300:
        parser.error("--timeout-seconds must be between 1 and 300")
    executable = shutil.which(args.godot)
    if executable is None:
        parser.error("The requested Godot executable is not available")

    repository = Path(__file__).resolve().parents[1]
    output = args.out.expanduser().resolve()
    if output.exists():
        parser.error("--out must name a new directory")
    output.mkdir(parents=True, exist_ok=False)
    data_root = output / "isolated-user-data"
    data_home = data_root / "data"
    config_home = data_root / "config"
    cache_home = data_root / "cache"
    for directory in (data_home, config_home, cache_home):
        directory.mkdir(parents=True, exist_ok=False)
    environment = os.environ.copy()
    environment.update({
        "XDG_DATA_HOME": str(data_home),
        "XDG_CONFIG_HOME": str(config_home),
        "XDG_CACHE_HOME": str(cache_home),
    })
    tracks = TRACK_IDS if args.track == "all" else (args.track,)
    qualities = ("light", "full") if args.quality == "both" else (args.quality,)
    expected_cases = [(track, quality) for track in tracks for quality in qualities]
    command = [
        executable, "--headless", "--quit-after", "8", "--path", str(repository), "--script",
        "res://scripts/tests/kart_track_theme_world_regression.gd", "--",
        f"--track={args.track}", f"--quality={args.quality}",
    ]
    evidence: dict[str, object] = {
        "schema_version": 2,
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "status": "PREPARING",
        "scope": "Real world geometry checks; no driving camera, rendering or Android performance acceptance",
        "command": command,
        "timeout_seconds": args.timeout_seconds,
        "test_data_root": str(data_root),
        "expected_cases": expected_cases,
        "log": "world-check.log",
    }
    log = ""
    engine_exit: int | None = None
    result_code = 1
    try:
        evidence["source_commit"] = git_output(repository, "rev-parse", "HEAD")
        evidence["source_status"] = git_output(repository, "status", "--porcelain")
        evidence["changed_runtime_sources"] = snapshot_changes(repository, output)
        evidence["source_snapshot_scope"] = "Changed and untracked runtime sources; unchanged files are bound to source_commit"
        evidence["target_sha256"] = hashlib.sha256(
            (repository / "scripts/tests/kart_track_theme_world_regression.gd").read_bytes()
        ).hexdigest()
        evidence["runner_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        evidence["status"] = "RUNNING"
        (output / "world-check.json").write_text(
            json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        completed = subprocess.run(
            command, cwd=repository, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
            timeout=args.timeout_seconds, check=False,
        )
        log = completed.stdout
        engine_exit = completed.returncode
        pass_matches = PASS_LINE.findall(log)
        case_details = [match.groupdict() for match in CASE_LINE.finditer(log)]
        observed_cases = [(case["track"], case["quality"]) for case in case_details]
        coverage_valid = True
        for case in case_details:
            accepted = int(case["accepted"])
            probes = int(case["support_probes"])
            coverage_valid &= accepted > 0 and int(case["parts"]) > 0
            coverage_valid &= int(case["failures"]) == 0
            if case["track"] in GROUND_TRACKS:
                coverage_valid &= case["support"] == "geometry_probed" and probes >= accepted * 3
            else:
                coverage_valid &= case["support"] == "NOT_ASSESSED" and probes == 0
        observed_probe_total = sum(int(case["support_probes"]) for case in case_details)
        raw_case_count = len(re.findall(r"(?m)^\[ThemeWorld\] CASE ", log))
        has_engine_errors = bool(ERROR_LINE.search(log))
        complete = (
            engine_exit == 0
            and not has_engine_errors
            and "[ThemeWorld] FAIL" not in log
            and len(pass_matches) == 1
            and int(pass_matches[0][0]) == len(expected_cases)
            and int(pass_matches[0][1]) > 0
            and int(pass_matches[0][2]) == observed_probe_total
            and raw_case_count == len(expected_cases)
            and observed_cases == expected_cases
            and coverage_valid
        )
        evidence.update({
            "engine_errors_in_log": has_engine_errors,
            "observed_cases": observed_cases,
            "observed_case_details": case_details,
            "support_coverage_valid": coverage_valid,
            "observed_support_probe_total": observed_probe_total,
            "completion_markers": pass_matches,
            "status": "PASS" if complete else "FAIL",
        })
        result_code = 0 if complete else 1
    except subprocess.TimeoutExpired as error:
        log = as_text(error.stdout)
        evidence.update({"status": "TIMEOUT", "error": str(error)})
        result_code = 124
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        evidence.update({"status": "EXECUTION_ERROR", "error": str(error)})
        result_code = 1
    finally:
        evidence["engine_exit_code"] = engine_exit
        evidence["runner_exit_code"] = result_code
        evidence["completed_utc"] = datetime.now(timezone.utc).isoformat()
        (output / "world-check.log").write_text(log, encoding="utf-8")
        (output / "world-check.json").write_text(
            json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(log, end="" if log.endswith("\n") or not log else "\n")
    print(f"[ThemeWorldRunner] {evidence['status']} evidence={output}")
    return result_code


if __name__ == "__main__":
    sys.exit(main())
