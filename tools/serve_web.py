#!/usr/bin/env python3
"""
serve_web.py - Localhost-Server fuer den Lumo 3D Web-Export.

Hostet exports/web/ unter http://localhost:8000 (Default), mit den
fuer Godot 4.x WebAssembly noetigen COOP/COEP-Headern (sonst
SharedArrayBuffer + Threads tot).

Loggt jede Anfrage in /tmp/lumo_serve.log fuer Performance-Profiling.

Usage:
    python3 tools/serve_web.py            # Port 8000
    python3 tools/serve_web.py --port 9090
    python3 tools/serve_web.py --bind 0.0.0.0 --port 8000   # extern erreichbar
"""
from __future__ import annotations

import argparse
import datetime as dt
import http.server
import socketserver
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ROOT = REPO_ROOT / "exports" / "web"
LOG_PATH = Path("/tmp/lumo_serve.log")


class CrossOriginIsolatedHandler(http.server.SimpleHTTPRequestHandler):
    """Setzt die Cross-Origin-Isolation-Headers + protokolliert Anfragen."""

    def end_headers(self) -> None:
        # SharedArrayBuffer braucht beide Header
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # Bessere Caching-Defaults fuer .wasm / .pck
        if self.path.endswith((".wasm", ".pck", ".js")):
            self.send_header("Cache-Control", "public, max-age=3600")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        ts = dt.datetime.now().strftime("%H:%M:%S")
        line = f"[{ts}] {self.address_string()} - {fmt % args}\n"
        sys.stderr.write(line)
        try:
            with LOG_PATH.open("a", encoding="utf-8") as f:
                f.write(line)
        except OSError:
            pass


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--bind", default="127.0.0.1")
    p.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = p.parse_args(argv)

    if not args.root.is_dir():
        print(
            f"[serve_web] {args.root} existiert nicht - "
            f"erst 'tools/build_web.sh' laufen lassen.",
            file=sys.stderr,
        )
        return 2

    import os
    os.chdir(args.root)
    LOG_PATH.write_text("")  # truncate
    with socketserver.ThreadingTCPServer(
        (args.bind, args.port), CrossOriginIsolatedHandler
    ) as srv:
        print(
            f"[serve_web] http://{args.bind}:{args.port}/ "
            f"(root: {args.root}, log: {LOG_PATH})",
            file=sys.stderr,
        )
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("[serve_web] stop.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
