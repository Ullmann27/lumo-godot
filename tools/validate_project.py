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

    # 7b. Generated Asset Pack (lumo3d_assets)
    pack_root = REPO / "assets" / "generated" / "lumo3d_assets"
    if not pack_root.is_dir():
        emit("FAIL", "asset-pack", f"missing dir: {pack_root.relative_to(REPO)}")
    else:
        emit("PASS", "asset-pack", f"present: {pack_root.relative_to(REPO)}")
        # pack manifest valid
        pmf = pack_root / "asset_manifest.json"
        if pmf.is_file():
            try:
                pm_data = json.loads(pmf.read_text())
                emit("PASS", "asset-pack-manifest",
                     f"valid JSON, {sum(pm_data.get('counts', {}).values())} assets in counts")
            except json.JSONDecodeError as exc:
                emit("FAIL", "asset-pack-manifest", f"JSON kaputt: {exc}")
        else:
            emit("FAIL", "asset-pack-manifest", "asset_manifest.json fehlt")
        # PNG count
        png_count = len(list(pack_root.rglob("*.png")))
        if png_count >= 100:
            emit("PASS", "asset-pack-png-count", f"{png_count} PNG files")
        else:
            emit("FAIL", "asset-pack-png-count", f"only {png_count} PNG files (< 100)")
        # Required subdirs (FAIL if missing - that's pack corruption)
        for sub in ["textures/albedo", "textures/normal", "textures/emission",
                    "particles", "billboards", "portals", "sky_gradients",
                    "ui_panels", "masks"]:
            p = pack_root / sub
            if p.is_dir() and any(p.glob("*.png")):
                emit("PASS", "asset-pack-category", f"{sub}: {len(list(p.glob('*.png')))} PNGs")
            else:
                emit("FAIL", "asset-pack-category", f"missing or empty: {sub}")

    # 7c. Generated material .tres files
    mat_gen_dir = REPO / "assets" / "materials" / "generated"
    required_mats = [
        "mat_grass_magic.tres", "mat_stone_warm.tres", "mat_wood_warm.tres",
        "mat_hologrid_cyan.tres", "mat_crystal_floor.tres",
        "mat_portal_learn.tres", "mat_portal_games.tres", "mat_portal_parent.tres",
        "mat_sky_backdrop.tres", "mat_billboard_crystal.tres",
        "mat_billboard_book.tres", "mat_particle_gold.tres",
    ]
    for m in required_mats:
        p = mat_gen_dir / m
        if p.is_file():
            emit("PASS", "generated-material", m)
        else:
            emit("FAIL", "generated-material", f"missing: {m}")

    # 7d. Central manifest contains new texture categories
    if manifest_path.is_file():
        try:
            data2 = json.loads(manifest_path.read_text())
            for needed in ["textures", "normal_maps", "emission_maps",
                           "particles", "billboards", "portals", "sky", "ui",
                           "masks", "materials"]:
                items = data2.get(needed, {})
                if isinstance(items, dict) and len(items) > 0:
                    emit("PASS", "central-manifest", f"{needed}: {len(items)} IDs")
                else:
                    emit("FAIL", "central-manifest", f"central manifest missing/empty: {needed}")
        except json.JSONDecodeError:
            pass  # already FAILed above

    # 7e. Home scene references at least 1 generated material on Insel +
    #     uses portal scene which loads portal materials
    home_path = REPO / "scenes" / "app" / "home_3d.tscn"
    home_ctl = REPO / "scripts" / "app" / "home_controller.gd"
    if home_ctl.is_file():
        ctl_text = home_ctl.read_text()
        if "mat_stone_warm" in ctl_text or "mat_grass_magic" in ctl_text:
            emit("PASS", "home-island-material", "home_controller references generated island material")
        else:
            emit("FAIL", "home-island-material", "home_controller does NOT reference any generated insel material")
        if "mat_sky_backdrop" in ctl_text:
            emit("PASS", "home-sky", "home_controller references mat_sky_backdrop")
        else:
            emit("WARN", "home-sky", "home_controller has no sky backdrop reference")
        if "mat_billboard" in ctl_text:
            emit("PASS", "home-billboards", "home_controller references billboard materials")
        else:
            emit("WARN", "home-billboards", "home_controller has no billboard references")
    portal_script = REPO / "scripts" / "hub" / "portal_interaction.gd"
    if portal_script.is_file():
        pt = portal_script.read_text()
        n_portals = sum(1 for m in ["mat_portal_learn", "mat_portal_games", "mat_portal_parent"] if m in pt)
        if n_portals == 3:
            emit("PASS", "home-portal-materials", "all 3 portal materials wired")
        else:
            emit("FAIL", "home-portal-materials", f"only {n_portals}/3 portal materials wired")

    # 7e2. Portal-Target-Szenen (Phase 1 Content)
    for portal_file in [
        "scenes/games/star_collect.tscn",
        "scenes/games/learn_card.tscn",
        "scenes/games/parent_settings.tscn",
        "scripts/games/star_collect_game.gd",
        "scripts/games/learn_card.gd",
        "scripts/games/parent_settings.gd",
    ]:
        check_file(REPO / portal_file, "FAIL", "portal-content")

    # 7f. LUMO Character System
    lumo_ref_dir = REPO / "assets" / "characters" / "lumo" / "reference"
    if lumo_ref_dir.is_dir():
        pngs = list(lumo_ref_dir.glob("*.png"))
        if len(pngs) >= 10:
            emit("PASS", "lumo-reference", f"{len(pngs)} PNG sheets in reference/")
        else:
            emit("FAIL", "lumo-reference", f"nur {len(pngs)} sheets (<10) in reference/")
    else:
        emit("FAIL", "lumo-reference", "assets/characters/lumo/reference/ fehlt")
    lumo_ref_manifest = lumo_ref_dir / "lumo_reference_manifest.json"
    if lumo_ref_manifest.is_file():
        try:
            json.loads(lumo_ref_manifest.read_text())
            emit("PASS", "lumo-reference-manifest", "lumo_reference_manifest.json valide")
        except json.JSONDecodeError as exc:
            emit("FAIL", "lumo-reference-manifest", f"JSON kaputt: {exc}")
    else:
        emit("WARN", "lumo-reference-manifest", "lumo_reference_manifest.json fehlt")
    for lumo_file in [
        "scenes/characters/lumo/lumo_character.tscn",
        "scenes/characters/lumo/lumo_showcase.tscn",
        "scripts/characters/lumo/lumo_character_controller.gd",
        "scripts/characters/lumo/lumo_behavior_controller.gd",
        "scripts/characters/lumo/lumo_animation_state.gd",
        "scripts/characters/lumo/lumo_eye_system.gd",
        "scripts/characters/lumo/lumo_mouth_system.gd",
        "scripts/characters/lumo/lumo_reference_board.gd",
        "scripts/app/showcase_controller.gd",
    ]:
        check_file(REPO / lumo_file, "FAIL", "lumo-system")
    # Fehlende echte GLBs bleiben WARN (siehe Asset-Check oben).

    # 8. Verbot: keine Flutter-Kernstruktur
    for forbidden in ["pubspec.yaml", "lib/main.dart"]:
        if (REPO / forbidden).exists():
            emit("FAIL", "no-flutter", f"Flutter-Datei im Repo: {forbidden}")
        else:
            emit("PASS", "no-flutter", f"absent: {forbidden}")

    # 9. Export-Skripte vorhanden + ausfuehrbar
    for tool in ["tools/build_web.sh", "tools/build_web_bundle.sh", "tools/build_android.sh",
                 "tools/setup_android_keystore.sh",
                 "tools/install_android.sh", "tools/logcat_lumo.sh",
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
