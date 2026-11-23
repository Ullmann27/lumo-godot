"""Two real Godot clients, a separate relay process, and a durable DB restart."""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import sqlite3
import sys
import tempfile

import aiohttp


async def execute(godot: str, output: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lumo-online-qa-") as temp:
        root = Path(temp)
        project = root / "project"
        for relative in ("scripts/games/online/kart_online_session.gd",
                         "scripts/tests/kart_online_client_probe.gd"):
            destination = project / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(repo / relative, destination)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Lumo Online QA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
            encoding="utf-8")
        database = root / "accounts.sqlite3"
        keys = {role: secrets.token_hex(32) for role in ("alpha", "beta")}
        results = []
        for round_index in (1, 2):
            with socket.socket() as socket_probe:
                socket_probe.bind(("127.0.0.1", 0))
                port = socket_probe.getsockname()[1]
            server_env = {**os.environ, "HOST": "127.0.0.1", "PORT": str(port),
                          "LUMO_DATABASE_PATH": str(database)}
            server_log = output / f"relay-round-{round_index}.log"
            with server_log.open("wb") as log:
                relay = await asyncio.create_subprocess_exec(
                    sys.executable, str(repo / "server/kart_online/relay.py"),
                    env=server_env, stdout=log, stderr=asyncio.subprocess.STDOUT)
                processes = []
                readers = []
                try:
                    async with aiohttp.ClientSession() as http:
                        for attempt in range(100):
                            try:
                                async with http.get(f"http://127.0.0.1:{port}/health") as response:
                                    if response.status == 200:
                                        break
                            except aiohttp.ClientError:
                                pass
                            if relay.returncode is not None:
                                raise RuntimeError("relay exited before health became ready")
                            await asyncio.sleep(0.05)
                        else:
                            raise RuntimeError("relay health timeout")
                    beta_ready = asyncio.Event()
                    collected: dict[str, list[str]] = {"alpha": [], "beta": []}

                    async def read_lines(process, role: str) -> None:
                        async for raw in process.stdout:
                            line = raw.decode("utf-8", errors="replace").rstrip()
                            collected[role].append(line)
                            if line == "LUMO_ONLINE_QA_READY beta":
                                beta_ready.set()

                    async def launch(role: str):
                        env = {**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1",
                               "LUMO_ONLINE_QA_ROLE": role, "LUMO_ONLINE_QA_KEY": keys[role],
                               "LUMO_ONLINE_QA_DIR": str(root),
                               "LUMO_ONLINE_QA_URL": f"ws://127.0.0.1:{port}/ws"}
                        process = await asyncio.create_subprocess_exec(
                            godot, "--headless", "--path", str(project), "--max-fps", "60",
                            "--script", "res://scripts/tests/kart_online_client_probe.gd",
                            env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
                        processes.append(process)
                        readers.append(asyncio.create_task(read_lines(process, role)))
                        return process

                    beta = await launch("beta")
                    await asyncio.wait_for(beta_ready.wait(), 25.0)
                    alpha = await launch("alpha")
                    codes = await asyncio.wait_for(asyncio.gather(alpha.wait(), beta.wait()), 90.0)
                    await asyncio.gather(*readers)
                    for role, lines in collected.items():
                        (output / f"godot-{role}-round-{round_index}.log").write_text("\n".join(lines) + "\n", encoding="utf-8")
                        passing = [line for line in lines if line.startswith("LUMO_ONLINE_QA_PASS ")]
                        if len(passing) != 1:
                            raise AssertionError(f"{role} round {round_index}: no unique PASS; see original log")
                        report = json.loads(passing[0].split(" ", 1)[1])
                        if not report["remote_moved"] or not report["registered"] or report["friends"] != 1:
                            raise AssertionError(f"{role} round {round_index}: incomplete live path")
                        results.append({"round": round_index, **report})
                    if codes != [0, 0]:
                        raise AssertionError(f"Godot client exit codes: {codes}")
                finally:
                    for process in processes:
                        if process.returncode is None:
                            process.terminate()
                            try:
                                await asyncio.wait_for(process.wait(), 3)
                            except TimeoutError:
                                process.kill()
                                await process.wait()
                    for reader in readers:
                        if not reader.done():
                            reader.cancel()
                    await asyncio.gather(*readers, return_exceptions=True)
                    # Preserve failures too, without persisting test credentials.
                    if "collected" in locals():
                        for role, lines in collected.items():
                            (output / f"godot-{role}-round-{round_index}.log").write_text("\n".join(lines) + "\n", encoding="utf-8")
                    if relay.returncode is None:
                        relay.terminate()
                        try:
                            await asyncio.wait_for(relay.wait(), 5)
                        except TimeoutError:
                            relay.kill()
                            await relay.wait()
            with sqlite3.connect(database) as connection:
                accounts = connection.execute("SELECT username FROM accounts ORDER BY username").fetchall()
                friendships = connection.execute("SELECT COUNT(*) FROM friendships").fetchone()[0]
            if accounts != [("QaAlpha",), ("QaBeta",)] or friendships != 2:
                raise AssertionError("Persistent account/friendship rows differ from accepted pair")
        evidence = {
            "status": "PASS",
            "scope": "two separate Godot processes over real local WebSocket sockets; server restarted against the same SQLite file",
            "internet_deployment_proven": False,
            "physical_devices_proven": False,
            "rounds": results,
            "persistent_accounts": 2,
            "persistent_directed_friendship_rows": 2,
        }
        (output / "online-two-process.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"status": "PASS", "clients_per_round": 2, "rounds": 2, "evidence": str(output)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    asyncio.run(execute(args.godot, args.output))
