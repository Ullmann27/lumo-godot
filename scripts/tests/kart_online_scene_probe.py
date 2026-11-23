"""Start a private relay and probe the real kart scene; optional original PNGs."""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import socket
import sys
import tempfile

import aiohttp


async def run(godot: str, output: Path, shots: bool) -> None:
    repo = Path(__file__).resolve().parents[2]
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lumo-online-scene-") as directory:
        temp = Path(directory)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        env = {**os.environ, "HOST": "127.0.0.1", "PORT": str(port),
               "LUMO_DATABASE_PATH": str(temp / "accounts.sqlite3"),
               "XDG_DATA_HOME": str(temp / "godot-user-data"),
               "GODOT_SILENCE_ROOT_WARNING": "1",
               "LUMO_ONLINE_QA_URL": f"ws://127.0.0.1:{port}/ws",
               "LUMO_ONLINE_QA_OUTPUT": str(output.absolute()),
               "LUMO_ONLINE_QA_SHOTS": "1" if shots else "0"}
        with (output / "scene-relay.log").open("wb") as server_log:
            server = await asyncio.create_subprocess_exec(
                sys.executable, str(repo / "server/kart_online/relay.py"), env=env,
                stdout=server_log, stderr=asyncio.subprocess.STDOUT)
            child = None
            try:
                async with aiohttp.ClientSession() as http:
                    for attempt in range(100):
                        try:
                            async with http.get(f"http://127.0.0.1:{port}/health") as response:
                                if response.status == 200:
                                    break
                        except aiohttp.ClientError:
                            pass
                        if server.returncode is not None:
                            raise RuntimeError("Relay stopped before health readiness")
                        await asyncio.sleep(0.05)
                    else:
                        raise RuntimeError("Relay health timeout")
                command = [godot]
                if not shots:
                    command.append("--headless")
                command += ["--path", str(repo), "--max-fps", "60",
                            "--script", "res://scripts/tests/kart_online_race_regression.gd"]
                with (output / "godot-online-scene.log").open("wb") as client_log:
                    child = await asyncio.create_subprocess_exec(*command, env=env,
                        stdout=client_log, stderr=asyncio.subprocess.STDOUT)
                    code = await asyncio.wait_for(child.wait(), timeout=300)
                if code != 0:
                    raise AssertionError(f"Godot real-scene probe returned {code}; see original log")
                report = json.loads((output / "online-scene.json").read_text())
                if report["status"] != "PASS" or report["checks"] < 25:
                    raise AssertionError("The original scene report is incomplete")
                if shots and len(list(output.glob("0*_online_*.png"))) != 3:
                    raise AssertionError("The three requested original screenshots are incomplete")
                print(json.dumps(report))
            finally:
                for process in (child, server):
                    if process is not None and process.returncode is None:
                        process.terminate()
                        try:
                            await asyncio.wait_for(process.wait(), 5)
                        except TimeoutError:
                            process.kill()
                            await process.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shots", action="store_true")
    args = parser.parse_args()
    asyncio.run(run(args.godot, args.output, args.shots))
