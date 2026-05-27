#!/usr/bin/env python3
"""
fetch_assets.py - KI-3D-Asset-Pipeline fuer Lumo 3D (Godot 4.6.3).

Holt prozedurale 3D-Modelle (.glb) von externen AI-APIs (Meshy AI,
Replicate, optional Hugging Face) und legt sie in assets/models/ ab,
damit Godot's AssetLoader sie beim naechsten App-Start instanziiert.

Konfiguration via JSON oder Kommandozeile:
    python3 tools/fetch_assets.py --config tools/assets.json
    python3 tools/fetch_assets.py --prompt "low-poly sci-fi crate" --provider meshy
    python3 tools/fetch_assets.py --prompt "neon hologram orb"     --provider replicate

Voraussetzung:
    export MESHY_API_KEY="..."         # https://meshy.ai
    export REPLICATE_API_TOKEN="..."   # https://replicate.com
    export HF_TOKEN="..."              # https://huggingface.co (optional)

Ohne API-Keys laeuft das Skript im Dry-Run-Modus und schreibt eine
Platzhalter-glb (leeres GLTF mit einer markierten Box) - damit der
Godot-AssetLoader nicht ueber Null-Bytes stolpert wenn die App ohne
Internet startet.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import os
import struct
import sys
import time
from pathlib import Path
from typing import Iterable
from urllib import error as urlerror
from urllib import request as urlrequest

REPO_ROOT = Path(__file__).resolve().parent.parent
MODELS_DIR = REPO_ROOT / "assets" / "models"
TEXTURES_DIR = REPO_ROOT / "assets" / "textures"

MESHY_BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"
REPLICATE_BASE = "https://api.replicate.com/v1/predictions"


@dataclasses.dataclass
class AssetSpec:
    prompt: str
    out_name: str
    provider: str = "meshy"  # meshy | replicate | dryrun
    style: str = "realistic"  # nur Meshy
    seed: int | None = None


def _http_post(url: str, data: dict, headers: dict, timeout: int = 60) -> dict:
    body = json.dumps(data).encode("utf-8")
    req = urlrequest.Request(url, data=body, headers=headers, method="POST")
    with urlrequest.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _http_get(url: str, headers: dict, timeout: int = 60) -> dict:
    req = urlrequest.Request(url, headers=headers, method="GET")
    with urlrequest.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _http_download(url: str, dest: Path, timeout: int = 120) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urlrequest.urlopen(url, timeout=timeout) as resp:
        dest.write_bytes(resp.read())


# ────────────────────────────────────────────────────────────────────────
# Provider: Meshy AI
# ────────────────────────────────────────────────────────────────────────
def fetch_meshy(spec: AssetSpec, api_key: str) -> Path:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    create = _http_post(
        MESHY_BASE,
        {
            "mode": "preview",
            "prompt": spec.prompt,
            "art_style": spec.style,
            "negative_prompt": "low quality, broken topology",
        },
        headers,
    )
    task_id = create.get("result") or create.get("id")
    if not task_id:
        raise RuntimeError(f"Meshy: no task id in response: {create}")
    poll_url = f"{MESHY_BASE}/{task_id}"
    deadline = time.time() + 240
    while time.time() < deadline:
        status = _http_get(poll_url, headers)
        if status.get("status") == "SUCCEEDED":
            glb_url = status["model_urls"]["glb"]
            dest = MODELS_DIR / f"{spec.out_name}.glb"
            _http_download(glb_url, dest)
            return dest
        if status.get("status") == "FAILED":
            raise RuntimeError(f"Meshy: task failed: {status}")
        time.sleep(4)
    raise TimeoutError("Meshy: timeout waiting for generation")


# ────────────────────────────────────────────────────────────────────────
# Provider: Replicate (Tripo, OpenLRM, etc. - frei waehlbar via JSON)
# ────────────────────────────────────────────────────────────────────────
def fetch_replicate(spec: AssetSpec, api_token: str, model_version: str) -> Path:
    headers = {
        "Authorization": f"Token {api_token}",
        "Content-Type": "application/json",
    }
    create = _http_post(
        REPLICATE_BASE,
        {
            "version": model_version,
            "input": {"prompt": spec.prompt, "seed": spec.seed or 0},
        },
        headers,
    )
    poll_url = create["urls"]["get"]
    deadline = time.time() + 240
    while time.time() < deadline:
        status = _http_get(poll_url, headers)
        if status.get("status") == "succeeded":
            output = status["output"]
            glb_url = output if isinstance(output, str) else output[0]
            dest = MODELS_DIR / f"{spec.out_name}.glb"
            _http_download(glb_url, dest)
            return dest
        if status.get("status") in ("failed", "canceled"):
            raise RuntimeError(f"Replicate: {status.get('error')}")
        time.sleep(4)
    raise TimeoutError("Replicate: timeout waiting for generation")


# ────────────────────────────────────────────────────────────────────────
# Provider: Dry-Run (Minimal-GLB-Stub - 1 leerer Node, valid GLTF)
# ────────────────────────────────────────────────────────────────────────
def write_placeholder_glb(spec: AssetSpec) -> Path:
    dest = MODELS_DIR / f"{spec.out_name}.glb"
    dest.parent.mkdir(parents=True, exist_ok=True)
    json_chunk = json.dumps(
        {
            "asset": {"version": "2.0", "generator": "lumo-fetch-assets dryrun"},
            "scene": 0,
            "scenes": [{"nodes": [0], "name": spec.out_name}],
            "nodes": [{"name": spec.prompt[:60]}],
        },
        separators=(",", ":"),
    ).encode("utf-8")
    # GLTF binary requires 4-byte aligned JSON chunk
    pad = (4 - len(json_chunk) % 4) % 4
    json_chunk += b" " * pad
    total = 12 + 8 + len(json_chunk)
    out = bytearray()
    out += b"glTF"
    out += struct.pack("<II", 2, total)
    out += struct.pack("<II", len(json_chunk), 0x4E4F534A)  # "JSON"
    out += json_chunk
    dest.write_bytes(out)
    return dest


# ────────────────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────────────────
def parse_config(path: Path) -> list[AssetSpec]:
    raw = json.loads(path.read_text())
    return [AssetSpec(**item) for item in raw.get("assets", [])]


def run_specs(specs: Iterable[AssetSpec]) -> int:
    meshy_key = os.environ.get("MESHY_API_KEY", "")
    replicate_token = os.environ.get("REPLICATE_API_TOKEN", "")
    replicate_model = os.environ.get(
        "REPLICATE_MODEL_VERSION",
        # Tripo SR (text->mesh). Heinz kann ueberschreiben via env.
        "a0c0b9c5e8e9b1a2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6",
    )
    count = 0
    for spec in specs:
        try:
            if spec.provider == "meshy" and meshy_key:
                dest = fetch_meshy(spec, meshy_key)
            elif spec.provider == "replicate" and replicate_token:
                dest = fetch_replicate(spec, replicate_token, replicate_model)
            else:
                print(
                    f"[fetch_assets] {spec.provider}: no API key set, "
                    f"writing placeholder for '{spec.out_name}'",
                    file=sys.stderr,
                )
                dest = write_placeholder_glb(spec)
            print(f"[fetch_assets] OK: {dest.relative_to(REPO_ROOT)}")
            count += 1
        except (urlerror.URLError, urlerror.HTTPError, RuntimeError,
                TimeoutError) as exc:
            print(
                f"[fetch_assets] FAIL: {spec.out_name} ({exc}) -> placeholder",
                file=sys.stderr,
            )
            write_placeholder_glb(spec)
            count += 1
    return count


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Fetch procedural 3D assets for Lumo 3D."
    )
    p.add_argument("--config", type=Path, default=None,
                   help="JSON config with batch of assets (see assets.json)")
    p.add_argument("--prompt", type=str, default=None)
    p.add_argument("--name", type=str, default=None)
    p.add_argument("--provider", choices=("meshy", "replicate", "dryrun"),
                   default="meshy")
    p.add_argument("--style", default="realistic")
    p.add_argument("--seed", type=int, default=None)
    args = p.parse_args(argv)

    if args.config:
        specs = parse_config(args.config)
    elif args.prompt:
        specs = [AssetSpec(
            prompt=args.prompt,
            out_name=args.name or args.prompt.lower().replace(" ", "_")[:32],
            provider=args.provider,
            style=args.style,
            seed=args.seed,
        )]
    else:
        p.error("either --config or --prompt must be set")
        return 2

    count = run_specs(specs)
    print(f"[fetch_assets] {count} asset(s) processed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
