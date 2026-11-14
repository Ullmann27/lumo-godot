#!/usr/bin/env python3
"""Collect one fresh, exact-source Discovery run; no retries or existing-run reuse."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
if __package__:
    from . import verify_discovery_connections as gate
else:
    import verify_discovery_connections as gate


def write_json(path, value):
    gate.require(not path.is_symlink(), "Refusing a symlink output")
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def fresh_output(project, requested):
    output = Path(os.path.abspath(requested))
    gate.no_symlink_path(output)
    gate.require(output != project and project not in output.parents, "Evidence must be outside the Native checkout")
    gate.require(not output.exists(), "Discovery output must not already exist")
    gate.require(output.parent.is_dir(), "Create only the external evidence parent before collection")
    output.mkdir()
    return output


def collect(project: Path, output: Path, expected_sha: str, expected_tree: str, godot: str):
    project = Path(os.path.abspath(project))
    gate.no_symlink_path(project)
    gate.require(project.is_dir(), "Native checkout required")
    gate.require(gate.SHA1.fullmatch(expected_sha) and gate.SHA1.fullmatch(expected_tree),
                 "Exact Native HEAD and tree are required")
    for key, value in (("LUMO_EXPECTED_NATIVE_SHA", expected_sha), ("LUMO_EXPECTED_NATIVE_TREE", expected_tree)):
        gate.require(not os.environ.get(key) or os.environ[key] == value, "Conflicting expected source environment")
    env = {**os.environ, "GIT_OPTIONAL_LOCKS": "0", "PYTHONDONTWRITEBYTECODE": "1",
           "GODOT_SILENCE_ROOT_WARNING": "1"}

    def git(*args):
        return subprocess.check_output(["git", "-C", str(project), *args], env=env)

    gate.require(git("rev-parse", "--show-toplevel").decode().strip() == str(project), "Project must be the Git root")
    gate.require(git("rev-parse", "HEAD").decode().strip() == expected_sha and
                 git("rev-parse", "HEAD^{tree}").decode().strip() == expected_tree, "Foreign Native checkout")
    gate.require(git("status", "--porcelain", "--untracked-files=no") == b"", "Dirty tracked Native checkout/index")
    output = fresh_output(project, output)
    (output / "helpers").mkdir()
    (output / "logs").mkdir()
    (output / "captures").mkdir()
    calls = {"schema": 1, "completed": False, "calls": []}
    write_json(output / "invocations.json", calls)
    (output / "results.tsv").write_text("probe\tmode\tresult\n", encoding="utf-8")
    for name, (sha, blob) in gate.HELPERS.items():
        path = project / "tools" / name
        gate.no_symlink_path(path)
        data = path.read_bytes()
        actual = gate.identity(data)
        gate.require(actual["sha256"] == sha and actual["git_blob"] == blob,
                     "Published helper hash differs before import: " + name)
        (output / "helpers" / name).write_bytes(data)
    for name, actual_path in (("collect_discovery_connections.py", Path(__file__)),
                              ("verify_discovery_connections.py", Path(gate.__file__))):
        data = (project / "tools" / name).read_bytes()
        gate.require(data == actual_path.read_bytes(), "Collector must execute the exact checkout source")
        (output / "helpers" / name).write_bytes(data)
    dream = gate.bound_module(output, "verify_dream_rasters.py")

    def snapshot(phase):
        suffix = "" if phase == "before" else "-after"
        (output / ("source-sha" + suffix + ".txt")).write_bytes(git("rev-parse", "HEAD"))
        (output / ("source-tree" + suffix + ".txt")).write_bytes(git("rev-parse", "HEAD^{tree}"))
        (output / ("source-dirty" + suffix + ".txt")).write_bytes(
            git("status", "--porcelain", "--untracked-files=no"))
        (output / ("source-tree-" + phase + ".bin")).write_bytes(git("ls-tree", "-r", "-z", "--full-tree", "HEAD"))
        index = Path(os.fsdecode(git("rev-parse", "--git-path", "index")).strip())
        if not index.is_absolute():
            index = project / index
        (output / ("source-index-" + phase + ".bin")).write_bytes(index.read_bytes())
        return dream.snapshot_source(project, output, phase)

    (output / "source-commit.raw").write_bytes(git("cat-file", "commit", expected_sha))
    failure = None
    try:
        initial = snapshot("before")
        gate.require(all(row["materialized"] is True for row in initial["tracked"]),
                     "This full-checkout CI requires every tracked source byte before running probes")
        executable = shutil.which(godot)
        gate.require(executable is not None, "Godot executable not found")
        engine = Path(executable).resolve(strict=True)
        binary = dream.disk_identity(engine)
        write_json(output / "engine-binary.json", {"path": str(engine), "bytes": binary["bytes"],
                                                  "sha256": binary["sha256"]})
        version = subprocess.run([str(engine), "--version"], stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, env=env, timeout=20, check=False)
        (output / "engine.txt").write_bytes(version.stdout)
        gate.require(version.returncode == 0 and version.stdout == (gate.ENGINE + "\n").encode(),
                     "Unexpected Godot engine identity")
        display = os.environ.get("DISPLAY", "")
        if display:
            gate.require(gate.re.fullmatch(r":[0-9]+(?:\.[0-9]+)?", display), "Use a local display only")
            renderer_prefix = []
        else:
            xvfb = shutil.which("xvfb-run")
            gate.require(xvfb is not None, "A genuine X11 renderer requires DISPLAY or xvfb-run")
            renderer_prefix = [str(Path(xvfb).absolute()), "-a", "-s", "-screen 0 2560x2560x24"]
        context = {"schema": 1, "native_source": expected_sha, "native_tree": expected_tree,
                   "project": str(project), "output": str(output), "output_was_absent": True,
                   "godot": str(engine), "python": str(Path(sys.executable).absolute()),
                   "renderer_prefix": renderer_prefix, "display": display,
                   "started_monotonic_ns": time.monotonic_ns()}
        write_json(output / "collection-context.json", context)
        for item in gate.invocation_plan(context):
            for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                Path(item["environment"][key]).mkdir(parents=True, exist_ok=False)
            call = {**item, "started_monotonic_ns": time.monotonic_ns(),
                    "finished_monotonic_ns": None, "returncode": None, "outer_timeout": False}
            calls["calls"].append(call)
            write_json(output / "invocations.json", calls)
            print(f"[DiscoveryCollector] START {item['ordinal']}/10 {item['probe']} "
                  f"{item['mode']} deadline={item['timeout_seconds']}s", flush=True)
            with (output / item["runner_log"]).open("xb") as transcript:
                # The unchanged source-bound runner owns its original per-probe
                # deadline and five-second TERM/KILL grace. No retry or extension.
                process = subprocess.Popen(item["command"], cwd=project,
                                           stdout=transcript, stderr=subprocess.STDOUT,
                                           env={**env, **item["environment"]})
                code = process.wait()
            call.update(finished_monotonic_ns=time.monotonic_ns(), returncode=code)
            write_json(output / "invocations.json", calls)
            print(f"[DiscoveryCollector] END {item['ordinal']}/10 returncode={code}", flush=True)
            gate.require(code == 0, "Original Discovery probe failed: " + item["probe"])
            text = gate.read(output, item["log"]).decode("utf-8")
            gate.require(gate.ERRORS.search(text) is None and text.splitlines().count(item["marker"]) == 1,
                         "Original error/leak or missing/duplicate marker: " + item["probe"])
            with (output / "results.tsv").open("a", encoding="utf-8") as results:
                results.write(item["probe"] + "\t" + item["mode"] + "\tPASS\n")
        calls.update(completed=True, finished_monotonic_ns=time.monotonic_ns())
        write_json(output / "invocations.json", calls)
    except Exception as error:
        failure = error
        write_json(output / "collection-failure.json", {"schema": 1, "error": type(error).__name__,
                                                      "message": str(error), "successful_collection": False})
    finally:
        # Preserve tracked/index failures and generated UIDs independently. Never clean.
        try:
            snapshot("after")
        except Exception as error:
            write_json(output / "source-finalization-failure.json",
                       {"error": type(error).__name__, "message": str(error)})
            if failure is None:
                failure = error
    if failure is not None:
        raise failure
    result = gate.verify(output, expected_native_sha=expected_sha, expected_native_tree=expected_tree, write=False)
    write_json(output / gate.MANIFEST, result)
    print(gate.PASS)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-native-sha", required=True)
    parser.add_argument("--expected-native-tree", required=True)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    collect(args.project, args.output, args.expected_native_sha, args.expected_native_tree, args.godot)


if __name__ == "__main__":
    main()
