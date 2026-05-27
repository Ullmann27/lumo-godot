#!/usr/bin/env python3
"""
validate_project.py - Pre-commit Validator fuer Lumo 3D (Godot 4.6.3).

Prueft die Pflicht-Struktur des Projekts. Exit 0 bei PASS oder reinen
WARNs. Exit 1 nur bei kritischen FAILs.

PASS  = alles OK
WARN  = darf fehlen (z.B. echte AI-Assets), aber wird notiert
FAIL  = kritisch (Pflicht-Skript fehlt, JSON kaputt, Autoload fehlt)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESULTS: list[tuple[str, str, str]] = []  # (level, category, detail)


def emit(level: str, category: str, detail: str) -> None:
    RESULTS.append((level, category, detail))
    print(f"[{level}] {category}: {detail}")


def check_file(path: Path, level: str = "FAIL", category: str = "file") -> bool:
    if path.is_file():
        emit("PASS", category, f"{path.relative_to(REPO)}")
        return True
    emit(level, category, f"missing: {path.relative_to(REPO)}")
    return False


def check_dir(path: Path, level: str = "FAIL", category: str = "dir") -> bool:
    if path.is_dir():
        emit("PASS", category, f"{path.relative_to(REPO)}/")
        return True
    emit(level, category, f"missing: {path.relative_to(REPO)}/")
    return False


def main() -> int:
    print(f"validate_project.py - root = {REPO}")
    print("=" * 60)

    # 1. project.godot
    check_file(REPO / "project.godot", "FAIL", "project")

    # 2. Pflicht-Verzeichnisse
    for d in [
        "scenes/app", "scenes/hub", "scenes/characters", "scenes/games",
        "scripts/app", "scripts/camera", "scripts/characters",
        "scripts/hub", "scripts/systems", "scripts/ui",
        "assets/manifests", "assets/models", "assets/materials",
        "assets/textures", "assets/shaders", "tools",
    ]:
        check_dir(REPO / d, "FAIL", "dir")

    # 3. Pflicht-Szenen
    for s in [
        "scenes/app/boot.tscn", "scenes/app/intro_3d.tscn",
        "scenes/app/home_3d.tscn", "scenes/app/loading_screen.tscn",
        "scenes/hub/hub_portal.tscn", "scenes/hub/star_field.tscn",
        "scenes/characters/lumo_companion.tscn",
        "scenes/default_env.tres",
    ]:
        check_file(REPO / s, "FAIL", "scene")

    # 4. Pflicht-Skripte
    for s in [
        "scripts/app/app_boot.gd",
        "scripts/app/scene_router.gd",
        "scripts/app/mobile_runtime.gd",
        "scripts/app/intro_controller.gd",
        "scripts/app/home_controller.gd",
        "scripts/camera/mobile_touch_camera.gd",
        "scripts/characters/lumo_companion.gd",
        "scripts/hub/portal_interaction.gd",
        "scripts/hub/star_field.gd",
        "scripts/systems/performance_manager.gd",
        "scripts/systems/asset_loader.gd",
        "scripts/systems/event_bus.gd",
        "scripts/ui/mobile_safe_area.gd",
    ]:
        check_file(REPO / s, "FAIL", "script")

    # 5. Autoloads in project.godot
    pg = (REPO / "project.godot").read_text(errors="ignore") if (REPO / "project.godot").exists() else ""
    autoload_block = ""
    m = re.search(r"\[autoload\](.*?)(\[|\Z)", pg, re.DOTALL)
    if m:
        autoload_block = m.group(1)
    for autoload in ["EventBus", "PerformanceManager", "SceneRouter",
                     "MobileRuntime", "AssetLoader"]:
        if re.search(rf"^\s*{autoload}\s*=", autoload_block, re.MULTILINE):
            emit("PASS", "autoload", autoload)
        else:
            emit("FAIL", "autoload", f"missing: {autoload}")

    # 6. Manifest
    manifest_path = REPO / "assets" / "manifests" / "assets.json"
    if manifest_path.is_file():
        try:
            data = json.loads(manifest_path.read_text())
            if "models" not in data:
                emit("FAIL", "manifest", "no 'models' key in assets.json")
            else:
                emit("PASS", "manifest",
                     f"valid JSON, {len(data.get('models', {}))} model entries")
                # 7. Per-Asset-Check (WARN bei fehlender Datei)
                for asset_id, path in data["models"].items():
                    rel = path.replace("res://", "")
                    if (REPO / rel).exists():
                        emit("PASS", "asset", f"{asset_id} -> {rel}")
                    else:
                        emit("WARN", "asset",
                             f"{asset_id} fehlt ({rel}) - AssetLoader nutzt Placeholder")
        except json.JSONDecodeError as exc:
            emit("FAIL", "manifest", f"JSON kaputt: {exc}")
    else:
        emit("FAIL", "manifest", "assets/manifests/assets.json fehlt")

    # 8. Verbot: keine Flutter-Kernstruktur
    for forbidden in ["pubspec.yaml", "lib/main.dart"]:
        if (REPO / forbidden).exists():
            emit("FAIL", "no-flutter", f"Flutter-Datei im Repo: {forbidden}")
        else:
            emit("PASS", "no-flutter", f"absent: {forbidden}")

    # 9. Export-Skripte vorhanden + ausfuehrbar
    for tool in ["tools/build_web.sh", "tools/build_android.sh",
                 "tools/serve_web.py", "tools/fetch_assets.py",
                 "tools/validate_project.py"]:
        p = REPO / tool
        if not p.exists():
            emit("FAIL", "tool", f"missing: {tool}")
            continue
        if not os.access(p, os.X_OK):
            emit("WARN", "tool", f"{tool} nicht ausfuehrbar (chmod +x fehlt)")
        else:
            emit("PASS", "tool", tool)

    # 10. CLAUDE.md
    claude = REPO / "CLAUDE.md"
    if not claude.is_file():
        emit("FAIL", "docs", "CLAUDE.md fehlt")
    else:
        text = claude.read_text(errors="ignore").lower()
        for kw in ["mobile", "boot", "home", "performance"]:
            if kw in text:
                emit("PASS", "docs", f"CLAUDE.md enthaelt '{kw}'")
            else:
                emit("WARN", "docs", f"CLAUDE.md fehlt Schluesselwort '{kw}'")

    # Summary
    print("=" * 60)
    n_pass = sum(1 for r in RESULTS if r[0] == "PASS")
    n_warn = sum(1 for r in RESULTS if r[0] == "WARN")
    n_fail = sum(1 for r in RESULTS if r[0] == "FAIL")
    print(f"SUMMARY: {n_pass} PASS / {n_warn} WARN / {n_fail} FAIL")
    if n_fail > 0:
        print(f"RESULT: FAIL ({n_fail} errors)")
        return 1
    print(f"RESULT: PASS ({n_warn} warnings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
