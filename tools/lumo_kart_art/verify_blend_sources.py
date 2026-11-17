"""Reopen every authoring scene in Blender and verify local editable dependencies."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    root = args.root.resolve()
    sources = sorted((root / "art/lumo_kart/blender").rglob("*.blend"))
    reports = []
    for source in sources:
        bpy.ops.wm.open_mainfile(filepath=str(source))
        errors = []
        objects = list(bpy.data.objects)
        meshes = [obj for obj in objects if obj.type == "MESH"]
        armatures = [obj for obj in objects if obj.type == "ARMATURE"]
        if not meshes:
            errors.append("No editable mesh objects")
        if not bpy.data.materials:
            errors.append("No authoring materials")
        images = []
        for image in bpy.data.images:
            if image.type in {"RENDER_RESULT", "COMPOSITING"} or image.source in {"VIEWER"}:
                continue
            packed = image.packed_file is not None or len(image.packed_files) > 0
            external = Path(bpy.path.abspath(image.filepath)) if image.filepath else None
            available = packed or image.source == "GENERATED" or (external is not None and external.is_file())
            if not available:
                errors.append("Missing image dependency: " + image.name)
            images.append({"name": image.name, "size": list(image.size), "source": image.source,
                           "packed": packed, "external_required": not packed and image.source != "GENERATED"})
        if "/drivers/" in source.as_posix() and not armatures:
            errors.append("Driver source has no editable armature")
        reports.append({
            "path": source.relative_to(root).as_posix(),
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "bytes": source.stat().st_size, "mesh_objects": len(meshes),
            "editable_vertices": sum(len(obj.data.vertices) for obj in meshes),
            "materials": len(bpy.data.materials), "cameras": sum(obj.type == "CAMERA" for obj in objects),
            "armatures": [{"name": obj.name, "bones": len(obj.data.bones)} for obj in armatures],
            "actions": [action.name for action in bpy.data.actions], "images": images,
            "passed": not errors, "errors": errors,
        })
        print("SOURCE", "PASS" if not errors else "FAIL", source.name, flush=True)
    passed = len(sources) == 19 and all(item["passed"] for item in reports)
    output = root / "evidence/lumo_kart_art/review/blender_sources.json"
    output.write_text(json.dumps({"blender": bpy.app.version_string, "source_count": len(sources),
                                 "expected_source_count": 19, "passed": passed,
                                 "method": "Actual bpy.ops.wm.open_mainfile for each final scene; editable geometry, rigs and image dependencies inspected",
                                 "sources": reports}, indent=2) + "\n")
    if not passed:
        raise RuntimeError("Authoring source verification failed; inspect " + str(output))


if __name__ == "__main__":
    main()
