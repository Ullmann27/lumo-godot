#!/usr/bin/env python3
"""Run actual Memory rules and Godot input with explicitly bounded QA adapters.

The production controller/session and original dealer run in Dart. Godot uses
real ScreenTouch events and renderer geometry. Disk transport, deterministic
clock, private test deck plan and reward ledger are QA adapters. This does not
prove Android Binder, SharedPreferences, physical-device timing or frame rate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time

from run_quiz_native_authority import LoggedProcess, git_identity, read_json, write_json


CAPTURES = (
    "01-memory-real-hidden.png", "02-memory-real-face.png",
    "03-memory-real-paused.png", "04-memory-real-reopened.png",
    "05-memory-real-bot-first.png", "06-memory-real-bot-second.png",
    "07-memory-real-win.png", "08-memory-real-paid-reopen.png",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify_capture(folder: Path, entry: dict, *, layout: bool) -> str:
    name = entry.get("file")
    require(isinstance(name, str) and Path(name).name == name, "Capture must be a local basename")
    path = folder / name
    require(path.is_file() and not path.is_symlink(), f"Missing original capture: {name}")
    data = path.read_bytes()
    require(len(data) > 32 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
            f"Capture is not a PNG: {name}")
    width, height = struct.unpack(">II", data[16:24])
    require(width > 0 and height > 0 and width == entry.get("width") and height == entry.get("height"),
            f"Framebuffer dimensions disagree: {name}")
    digest = hashlib.sha256(data).hexdigest()
    require(digest == entry.get("sha256"), f"Capture bytes disagree: {name}")
    if layout:
        observed = read_json(path.with_suffix(".layout.json"))
        require(observed.get("settled") is True, f"Unsettled layout: {name}")
        for key in ("token", "roundId", "revision"):
            require(observed.get(key) == entry.get(key), f"Capture/layout {key} mismatch: {name}")
    return digest


def verify_results(authority: dict, renderer: dict, native_result: dict,
                   wallet: dict, render_dir: Path, capture: bool) -> dict:
    require(authority.get("success") is True, "Dart authority did not succeed")
    require(renderer == native_result, "Native result differs from original renderer report")
    require(renderer.get("success") is True and renderer.get("failures") == [] and
            renderer.get("mode") == "production_dart_disk_authority", "No successful production-authority report")
    require(renderer.get("return_observed") == 3, "Three durable native returns are required")
    require(authority.get("award_calls") == 1, "Actual QA award callback must run exactly once")
    require(wallet == authority.get("wallet"), "Durable QA ledger and authority disagree")
    require(type(wallet.get("stars")) is int and wallet["stars"] == 2 and
            type(wallet.get("xp")) is int and wallet["xp"] == 16 and
            isinstance(wallet.get("ids"), list) and len(wallet["ids"]) == 1 and
            isinstance(wallet["ids"][0], str) and bool(wallet["ids"][0]),
            "Original easy reward must settle once as 2 stars and 16 XP")
    tokens = authority.get("tokens", [])
    require(len(tokens) == 3 and all(isinstance(t, str) and t for t in tokens) and
            len(set(tokens)) == 3, "Three separate native sessions are required")
    require(set(authority.get("closed_tokens", [])) == set(tokens), "Every own token must be closed")
    initial = authority.get("initial_round")
    require(isinstance(initial, str) and initial and renderer.get("initial_round") == initial,
            "Renderer must use the actual initial round")
    restored = authority.get("unfinished_reopen", {})
    require(restored.get("roundId") == initial and restored.get("restoredRoundId") == initial and
            restored.get("paused") is True and restored.get("remainingMs") == 550 and
            restored.get("oldToken") == tokens[0] and restored.get("newToken") == tokens[1],
            "Unfinished round, remaining time and new-token restore disagree")
    completed = authority.get("completed_round", {})
    rules = completed.get("rules", {})
    require(completed.get("rewarded") is True and rules.get("kindPairs") == 4 and
            rules.get("lumoPairs") == 0 and rules.get("kindMoves") == 4,
            "Four legal pairs must complete the actual stored round")
    completed_id = completed.get("id")
    require(isinstance(completed_id, str) and completed_id != initial and
            renderer.get("completed_round") == completed_id, "Completed round identity disagrees")
    paid = authority.get("paid_reopen", {})
    require(paid.get("completedRoundId") == completed_id and
            isinstance(paid.get("newRoundId"), str) and paid["newRoundId"] not in (initial, completed_id) and
            paid.get("oldToken") == tokens[1] and paid.get("newToken") == tokens[2] and
            paid.get("difficulty") == "leicht" and paid.get("pack") == "alle" and
            paid.get("best", {}).get("leicht") == 4 and paid.get("best", {}).get("schwer") == 17,
            "Paid reopen must preserve settings and prior best without repaying")
    require({"botFirst", "botSecond", "resolve"}.issubset(set(authority.get("bot_phases", []))),
            "Actual Dart opponent decisions were not observed")
    requests = authority.get("requests", [])
    require(isinstance(requests, list) and bool(requests), "No actual native intent records")
    for row in requests:
        request = row.get("request", {})
        require(json.loads(row.get("raw", "null")) == request, "Original native request bytes changed in transport")
        require(type(request.get("sequence")) is int and type(request.get("revision")) is int and
                row.get("ack") == request["sequence"] and request.get("token") in tokens,
                "Native intent lacks its own exact durable acknowledgement")
    captures = renderer.get("captures", [])
    motion = renderer.get("motion_frames", [])
    if capture:
        require(renderer.get("display_driver") != "headless" and renderer.get("capture") is True,
                "A real renderer was requested")
        require([c.get("file") for c in captures] == list(CAPTURES), "Eight current gameplay captures are required")
        require([c.get("file") for c in motion] == [f"motion-{i:02d}.png" for i in range(12)],
                "Twelve actual flip frames are required")
        for entry in captures:
            verify_capture(render_dir, entry, layout=True)
        require(len({verify_capture(render_dir, entry, layout=False) for entry in motion}) >= 4,
                "Flip sequence contains fewer than four distinct framebuffers")
    return {"checks": renderer["checks"], "inputs": len(renderer["inputs"]),
            "requests": len(requests), "captures": len(captures), "motion_frames": len(motion),
            "durable_returns": 3, "qa_award_calls": 1, "qa_stars": 2, "qa_xp": 16}


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
        parser.error("Output must be fresh; old evidence must be retained")
    output.mkdir(parents=True)
    state, render = output / "authority", output / "native"
    state.mkdir()
    render.mkdir()
    processes: list[LoggedProcess] = []
    started = time.monotonic()
    report: dict = {"schema": 1, "success": False, "capture_requested": args.capture,
                    "scope": __doc__}
    try:
        before = {"native": git_identity(native, args.expected_native),
                  "host": git_identity(host, args.expected_host)}
        report["source_before"] = before
        write_json(output / "source-identity.json", before)
        report["versions"] = {
            "godot": subprocess.check_output([args.godot, "--version"], text=True).strip(),
            "dart": subprocess.check_output([args.dart, "--version"], stderr=subprocess.STDOUT, text=True).strip(),
        }
        environment = dict(os.environ)
        environment["LUMO_MEMORY_QA_DIR"] = str(state)
        environment["LUMO_MEMORY_CAPTURE_DIR"] = str(render)
        for variable, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            isolated = output / "user" / suffix
            isolated.mkdir(parents=True)
            environment[variable] = str(isolated)
        dart_command = [args.dart, str(host / "tools/android_qa/memory_native_authority.dart"), str(state)]
        godot_command = [args.godot, "--path", str(native), "--rendering-method", "gl_compatibility",
                         "--audio-driver", "Dummy", "--fixed-fps", "60", "--disable-vsync"]
        if not args.capture:
            godot_command.append("--headless")
        godot_command.extend(["--script", "res://scripts/tests/memory_table_runtime.gd", "--"])
        if args.capture:
            godot_command.append("--capture")
        report["commands"] = {"dart": dart_command, "godot": godot_command}
        authority = LoggedProcess(dart_command, host, environment, output / "dart-authority.log", "DartAuthority")
        processes.append(authority)
        presenter = LoggedProcess(godot_command, native, environment, output / "godot-runtime.log", "GodotMemory", engine=True)
        processes.append(presenter)
        while any(p.process.poll() is None for p in processes):
            if presenter.engine_error:
                raise RuntimeError("Godot emitted a script or engine error")
            failed = next((p for p in processes if p.process.poll() not in (None, 0)), None)
            if failed:
                raise RuntimeError(f"{failed.name} exited {failed.process.returncode}")
            if time.monotonic() >= started + 330:
                raise TimeoutError("Memory authority pair exceeded its 330-second wall deadline")
            time.sleep(0.1)
        for process in processes:
            process.reader.join(timeout=5)
        require(all(p.process.returncode == 0 for p in processes), "A child ended with nonzero exit")
        require(not presenter.engine_error, "Godot emitted an error during shutdown")
        require(any("[MemoryTableRuntime] PASS" in line for line in presenter.lines), "Missing actual Godot success marker")
        require(any("[MemoryNativeAuthority] complete" in line for line in authority.lines), "Missing actual Dart completion marker")
        report.update(verify_results(read_json(state / "authority-result.json"),
                                    read_json(render / "memory-runtime-report.json"),
                                    read_json(state / "native-result.json"),
                                    read_json(state / "wallet.json"), render, args.capture))
        after = {"native": git_identity(native, args.expected_native),
                 "host": git_identity(host, args.expected_host)}
        require(before == after, "Source identity changed during execution")
        report.update({"success": True, "source_after": after})
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr, flush=True)
    finally:
        for process in processes:
            process.stop()
        report["elapsed_wall_seconds"] = round(time.monotonic() - started, 3)
        report["process_exit_codes"] = {p.name: p.process.returncode for p in processes}
        report["evidence"] = [{"path": str(p.relative_to(output)), "bytes": p.stat().st_size,
                               "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                              for p in sorted(output.rglob("*"))
                              if p.is_file() and "user" not in p.relative_to(output).parts]
        write_json(output / "pair-result.json", report)
    print("[MemoryNativePair] " + ("PASS" if report["success"] else "FAIL"), flush=True)
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
