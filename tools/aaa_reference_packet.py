#!/usr/bin/env python3
"""Package verified existing references and real captures for a focused art pass.

No network, image generation, engine invocation, APK build or runtime mutation.
The packet rejects dirty capture sources, missing images and stale Godot pins.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

REFERENCE_DIR = Path("docs/design/2026-10-10-lumo-games/references")
RUNTIME_PATHS = ("scripts/games", "scenes/games", "assets", "project.godot")
ASSET_PATHS = (*RUNTIME_PATHS, "tools/aaa_export_runtime_asset.gd",
               "tools/aaa_blender_archive.py", "tools/aaa_verify_glb.gd")


def git(repo, *args):
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, stderr=subprocess.PIPE
    ).strip()


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def png_size(path):
    with Path(path).open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG capture: {path}")
    if header[12:16] != b"IHDR":
        raise ValueError(f"Missing PNG dimensions: {path}")
    return list(struct.unpack(">II", header[16:24]))


def verified_references(app):
    folder = Path(app) / REFERENCE_DIR
    rows = []
    for line in (folder / "SHA256SUMS").read_text().splitlines():
        sha, name = line.split(maxsplit=1)
        name = name.lstrip("*")
        if Path(name).name != name or len(sha) != 64:
            raise ValueError("Unsafe reference checksum entry")
        path = folder / name
        if digest(path) != sha:
            raise ValueError(f"Changed original reference: {name}")
        rows.append({"file": str(REFERENCE_DIR / name), "sha256": sha})
    if not {"50666.gif", "50294.png", "50288.png", "50610.png"} <= {
        Path(row["file"]).name for row in rows
    }:
        raise ValueError("Core Lumo reference is missing")
    return rows


def verified_capture(folder, repo, manifest_name, kind):
    folder = Path(folder)
    manifest = json.loads((folder / manifest_name).read_text())
    rows = manifest if isinstance(manifest, list) else manifest["shots"]
    output = []
    for row in rows:
        metadata = row if isinstance(manifest, list) else manifest
        sha = metadata.get("source_commit")
        if (
            not isinstance(sha, str) or len(sha) != 40
            or metadata.get("tracked_differences")
            or metadata.get("clean_tracked_source") is False
        ):
            raise ValueError(f"Capture has no clean exact source: {folder}")
        git(repo, "cat-file", "-e", f"{sha}^{{commit}}")
        # A later documentation-only commit is fine; changed runtime code is not.
        scopes = RUNTIME_PATHS if kind == "godot" else ("lib", "assets", "pubspec.yaml", "pubspec.lock")
        if git(repo, "diff", "--name-only", sha, "HEAD", "--", *scopes):
            raise ValueError(f"Capture is stale relative to runtime: {folder}")
        name = row.get("image", row.get("file"))
        if not isinstance(name, str) or Path(name).name != name:
            raise ValueError("Capture filename must not escape its folder")
        path = folder / name
        dimensions = png_size(path)
        expected = row.get("size", [row.get("pixel_width"), row.get("pixel_height")])
        if dimensions != expected:
            raise ValueError(f"Capture dimension mismatch: {path}")
        output.append({
            **row, "sha256": digest(path), "source_commit": sha,
            "pixel_size": dimensions, "capture_kind": kind,
            "physical_android_device": False,
            "visual_acceptance": "Not approved; manual reference comparison required",
        })
    if not output:
        raise ValueError("Empty capture manifest")
    return output


def validate_pin(app, godot):
    pin = json.loads((Path(app) / "config/godot-source.json").read_text())
    revision = pin["revision"]
    git(godot, "cat-file", "-e", f"{revision}^{{commit}}")
    if git(godot, "diff", "--name-only", revision, "HEAD", "--", *RUNTIME_PATHS):
        raise ValueError("Godot runtime differs from app pin; integrate before art capture")
    return pin


def asset_source_is_current(godot, inventory):
    sha = inventory.get("source_commit")
    if not isinstance(sha, str) or len(sha) != 40:
        return False
    git(godot, "cat-file", "-e", f"{sha}^{{commit}}")
    return not git(godot, "diff", "--name-only", sha, "HEAD", "--", *ASSET_PATHS)


def build(args):
    app, godot = Path(args.app_repo).resolve(), Path(__file__).resolve().parents[1]
    for repo in (app, godot):
        if git(repo, "diff", "--name-only", "HEAD"):
            raise ValueError(f"Commit tracked edits before making a handoff: {repo.name}")
    pin = validate_pin(app, godot)
    refs = verified_references(app)
    packets = [
        ("godot", Path(args.menu_captures), "capture.json"),
        ("model", Path(args.model_captures), "capture.json"),
        ("cards", Path(args.cards_captures), "capture-manifest.json"),
    ]
    captured = {}
    for label, folder, manifest in packets:
        kind = "flutter" if label == "cards" else "godot"
        captured[label] = verified_capture(folder, app if kind == "flutter" else godot, manifest, kind)
    assets = Path(args.assets)
    inventory = json.loads((assets / "asset-manifest.json").read_text())
    roundtrip = json.loads((assets / "roundtrip-verification.json").read_text())
    if (
        not inventory.get("clean_tracked_source")
        or not asset_source_is_current(godot, inventory)
        or inventory["sha256"] != digest(assets / inventory["asset"])
        or roundtrip.get("status") != "PASS"
        or roundtrip.get("original_glb_sha256") != inventory["sha256"]
        or roundtrip.get("roundtrip_glb_sha256") != digest(assets / "lumo-comet-blender-roundtrip.glb")
    ):
        raise ValueError("3D source inventory/roundtrip is stale or incomplete")
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    packet = {
        "app_source": git(app, "rev-parse", "HEAD"),
        "godot_source": git(godot, "rev-parse", "HEAD"),
        "app_godot_pin": pin, "references": refs, "captures": captured,
        "asset_inventory": inventory, "roundtrip": roundtrip,
        "apk_built_in_this_phase": False, "android_device_verified": False,
        "art_approval": False, "runtime_replacement": False,
        "scope": "Existing Lumo identity; Kart entry and Comet/fox first; no learning-data or voice changes",
    }
    import shutil
    for row in refs:
        path = app / row["file"]
        target = output / "references" / path.name
        target.parent.mkdir(exist_ok=True)
        shutil.copy2(path, target)
    for label, folder, manifest in packets:
        target = output / label
        target.mkdir(exist_ok=True)
        shutil.copy2(folder / manifest, target / manifest)
        for row in captured[label]:
            name = row.get("image", row.get("file"))
            shutil.copy2(folder / name, target / name)
    target = output / "editable-3d"
    target.mkdir(exist_ok=True)
    for name in [
        "lumo-comet-existing.glb", "lumo-comet-existing.blend",
        "lumo-comet-blender-roundtrip.glb", "asset-manifest.json",
        "blender-import-report.json", "roundtrip-verification.json",
    ]:
        shutil.copy2(assets / name, target / name)
    (output / "handoff-manifest.json").write_text(
        json.dumps(packet, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"[AAAReferencePacket] PASS: {len(refs)} verified references, "
          f"{sum(map(len, captured.values()))} real captures, editable 3D source; art approval still open")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("app-repo", "menu-captures", "model-captures", "cards-captures", "assets", "output"):
        parser.add_argument(f"--{name}", required=True)
    build(parser.parse_args())


if __name__ == "__main__":
    main()
