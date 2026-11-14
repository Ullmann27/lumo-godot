#!/usr/bin/env python3
"""Run the real Dart Quiz authority and production Godot presenter together.

The file transport, test answer oracle and award ledger are declared QA
boundaries. This run cannot establish Android Binder, SharedPreferences or
physical-device performance. Existing Android and Flutter gates cover those
boundaries separately.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def git_identity(directory: Path, expected: str) -> dict[str, str]:
    if not re.fullmatch(r"[a-f0-9]{40}", expected):
        raise ValueError("An exact 40-character source commit is required")
    def git(*args: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(directory), *args], text=True
        ).strip()
    actual = git("rev-parse", "HEAD")
    if actual != expected:
        raise ValueError(f"Source mismatch: {directory}: {actual} != {expected}")
    if git("diff", "--name-only", "HEAD", "--"):
        raise ValueError(f"Tracked source has local changes: {directory}")
    return {"commit": actual, "tree": git("rev-parse", "HEAD^{tree}")}


class LoggedProcess:
    def __init__(self, command: list[str], cwd: Path, environment: dict[str, str],
                 path: Path, name: str, engine: bool = False) -> None:
        self.name = name
        self.engine_error = False
        self.lines: list[str] = []
        self.process = subprocess.Popen(
            command, cwd=cwd, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True,
        )
        def consume() -> None:
            assert self.process.stdout is not None
            with path.open("w") as log:
                for line in self.process.stdout:
                    log.write(line)
                    log.flush()
                    self.lines.append(line)
                    print(f"[{self.name}] {line}", end="", flush=True)
                    if engine and re.search(
                        r"SCRIPT ERROR|Parse Error|ERROR:|Assertion failed", line
                    ):
                        self.engine_error = True
        self.reader = threading.Thread(target=consume, daemon=True)
        self.reader.start()

    def stop(self) -> None:
        if self.process.poll() is None:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
                self.process.wait(timeout=5)
            except ProcessLookupError:
                pass
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.process.wait(timeout=5)
        self.reader.join(timeout=5)


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--host", type=Path, required=True)
    parser.add_argument("--expected-native", required=True)
    parser.add_argument("--expected-host", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--dart", default="dart")
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    native, host, output = args.native.resolve(), args.host.resolve(), args.output.resolve()
    if output.exists():
        parser.error("Output must be a fresh directory; previous evidence is retained")
    output.mkdir(parents=True)
    state = output / "authority"
    state.mkdir()
    render = output / "native"
    render.mkdir()
    processes: list[LoggedProcess] = []
    started = time.monotonic()
    report: dict = {
        "schema": 1, "success": False,
        "scope": "Real production Dart bank/controller/session and Godot input with an explicit QA disk transport and award ledger. No Android/device performance claim.",
        "capture_requested": args.capture,
    }
    try:
        before = {
            "native": git_identity(native, args.expected_native),
            "host": git_identity(host, args.expected_host),
        }
        report["source_before"] = before
        report["versions"] = {
            "godot": subprocess.check_output([args.godot, "--version"], text=True).strip(),
            "dart": subprocess.check_output([args.dart, "--version"], stderr=subprocess.STDOUT, text=True).strip(),
        }
        write_json(output / "source-identity.json", before)
        environment = dict(os.environ)
        environment["LUMO_QUIZ_QA_DIR"] = str(state)
        environment["LUMO_CAPTURE_DIR"] = str(render)
        for variable, suffix in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            isolated = output / "user" / suffix
            isolated.mkdir(parents=True)
            environment[variable] = str(isolated)
        dart_command = [args.dart, str(host / "tools/android_qa/quiz_native_authority.dart"), str(state)]
        godot_command = [args.godot, "--path", str(native), "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
        if not args.capture:
            godot_command.append("--headless")
        godot_command.extend(["--script", "res://scripts/tests/quiz_studio_runtime.gd", "--"])
        if args.capture:
            godot_command.append("--capture")
        report["commands"] = {"dart": dart_command, "godot": godot_command}
        authority = LoggedProcess(dart_command, host, environment, output / "dart-authority.log", "DartAuthority")
        processes.append(authority)
        native_process = LoggedProcess(godot_command, native, environment, output / "godot-runtime.log", "GodotQuiz", engine=True)
        processes.append(native_process)
        deadline = started + 330.0
        while any(p.process.poll() is None for p in processes):
            if native_process.engine_error:
                raise RuntimeError("Godot emitted a script or engine error")
            failed = next((p for p in processes if p.process.poll() not in (None, 0)), None)
            if failed is not None:
                raise RuntimeError(f"{failed.name} exited {failed.process.returncode}")
            if time.monotonic() >= deadline:
                raise TimeoutError("Native/authority pair exceeded its real-time 330 second deadline")
            time.sleep(0.1)
        for process in processes:
            process.reader.join(timeout=5)
        failed = next((p for p in processes if p.process.returncode != 0), None)
        if failed is not None:
            raise RuntimeError(f"{failed.name} ended with nonzero exit {failed.process.returncode}")
        if native_process.engine_error:
            raise RuntimeError("Godot emitted an error during shutdown")
        if not any("[QuizStudioRuntime] PASS" in line for line in native_process.lines):
            raise RuntimeError("Missing actual production-authority renderer success marker")
        if not any("[QuizNativeAuthority] complete" in line for line in authority.lines):
            raise RuntimeError("Missing actual Dart authority completion marker")
        renderer = read_json(render / "quiz-runtime-report.json")
        result = read_json(state / "authority-result.json")
        native_result = read_json(state / "native-result.json")
        wallet = read_json(state / "wallet.json")
        if renderer.get("mode") != "production_dart_disk_authority" or renderer.get("failures") != []:
            raise RuntimeError("Renderer report is not a successful real-authority execution")
        if not native_result.get("return_observed") or native_result.get("failures") != []:
            raise RuntimeError("Native return did not wait for its real authority acknowledgement")
        if result.get("finished") is not True or result.get("stars") != 5000 or len(result.get("paid_ids", [])) != 1:
            raise RuntimeError("Real controller did not settle the complete round exactly once")
        if wallet != {"stars": 5000, "ids": result["paid_ids"]}:
            raise RuntimeError("Actual durable QA ledger disagrees with authority result")
        if args.capture and (renderer.get("display_driver") == "headless" or len(renderer.get("captures", [])) < 6):
            raise RuntimeError("Requested renderer evidence is absent")
        after = {
            "native": git_identity(native, args.expected_native),
            "host": git_identity(host, args.expected_host),
        }
        if before != after:
            raise RuntimeError("Source identity changed during execution")
        report.update({
            "success": True, "source_after": after,
            "checks": renderer["checks"], "inputs": len(renderer["inputs"]),
            "captures": len(renderer["captures"]), "requests": len(result["requests"]),
            "confirmed_stars_in_qa_ledger": result["stars"],
        })
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr, flush=True)
    finally:
        for process in processes:
            process.stop()
        report["elapsed_wall_seconds"] = round(time.monotonic() - started, 3)
        report["process_exit_codes"] = {p.name: p.process.returncode for p in processes}
        entries = []
        for path in sorted(output.rglob("*")):
            if path.is_file() and "user" not in path.relative_to(output).parts:
                data = path.read_bytes()
                entries.append({"path": str(path.relative_to(output)), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        report["evidence"] = entries
        write_json(output / "pair-result.json", report)
    print("[QuizNativePair] " + ("PASS" if report["success"] else "FAIL"), flush=True)
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
