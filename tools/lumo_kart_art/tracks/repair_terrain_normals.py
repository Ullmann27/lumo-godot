"""Separate flat end-cap normals from smooth terrain surfaces.

Probe mode writes a single temporary cover GLB under evidence, without
saving the Blender source or changing any delivered asset.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_tunnel_kit as kit
import verify_tunnel_kit as verifier


def geometry_signature(path):
    """Hash actual GLB triangle positions, excluding normal-driven splits."""
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    blob = raw[28 + length:]

    def accessor(index):
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
        code = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[acc["componentType"]]
        fmt = "<" + code * count
        step = view.get("byteStride", struct.calcsize(fmt))
        offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return [struct.unpack_from(fmt, blob, offset + i * step) for i in range(acc["count"])]

    triangles = []
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            points = accessor(prim["attributes"]["POSITION"])
            indices = [value[0] for value in accessor(prim["indices"])]
            for i in range(0, len(indices), 3):
                corners = tuple(points[index] for index in indices[i:i + 3])
                # Retain winding, ignoring the chosen first triangle corner.
                triangles.append(min(corners, corners[1:] + corners[:1], corners[2:] + corners[:2]))
    digest = hashlib.sha256()
    for triangle in sorted(triangles):
        digest.update(struct.pack("<9f", *(v for p in triangle for v in p)))
    sockets = sorted((node.get("extras", {}).get("lumo_socket"), node.get("translation"), node.get("rotation"), node.get("scale"), node.get("matrix")) for node in doc.get("nodes", []) if node.get("extras", {}).get("lumo_socket"))
    return {"triangles": len(triangles), "triangle_positions_sha256": digest.hexdigest(), "sockets": sockets}


def cap_polygons(mesh, path):
    frames = [path.matrix(0), path.matrix(path.length)]
    planes = [(m.translation, (m.to_3x3() @ Vector((0, 1, 0))).normalized()) for m in frames]
    return {p.index for p in mesh.polygons if any(all(abs((mesh.vertices[index].co - origin).dot(direction)) < 0.0001 for index in p.vertices) for origin, direction in planes)}


def seam_normal_measurement(mesh, path, caps):
    normals = mesh.corner_normals
    values = []
    for s in (0, path.length):
        frame = path.matrix(s)
        origin = frame.translation
        tangent = (frame.to_3x3() @ Vector((0, 1, 0))).normalized()
        for polygon in mesh.polygons:
            if polygon.index in caps:
                continue
            for loop_index in polygon.loop_indices:
                pos = mesh.vertices[mesh.loops[loop_index].vertex_index].co
                if abs((pos - origin).dot(tangent)) < 0.0001:
                    values.append(abs(normals[loop_index].vector.dot(tangent)))
    return {"seam_side_corners": len(values), "mean_abs_longitudinal_normal": sum(values) / max(1, len(values)), "max_abs_longitudinal_normal": max(values, default=0)}


def flatten_end_caps(mesh, path):
    caps = cap_polygons(mesh, path)
    before = seam_normal_measurement(mesh, path, caps)
    changed = 0
    for index in caps:
        polygon = mesh.polygons[index]
        changed += int(polygon.use_smooth)
        polygon.use_smooth = False
    mesh.update()
    after = seam_normal_measurement(mesh, path, caps)
    return {"end_cap_triangles": len(caps), "changed_smooth_flags": changed, "before": before, "after": after}


def apply_corrections(repo, themes):
    evidence = repo / "evidence/lumo_kart_art/tracks"
    overall = []
    for theme_id in themes:
        assets = repo / "assets/kart/production/tracks" / theme_id
        source = repo / "art/lumo_kart/blender/tracks" / f"{theme_id}_tunnel_workshop.blend"
        core = json.loads((assets / "manifest.json").read_text())
        terrain = json.loads((assets / "terrain_manifest.json").read_text())
        frozen_core = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in assets.glob("*.glb") if "_terrain" not in p.name}
        before_source = hashlib.sha256(source.read_bytes()).hexdigest()
        bpy.ops.wm.open_mainfile(filepath=str(source))
        rows = []
        source_changed = False
        for kind in core["modules"]:
            coll = bpy.data.collections["TERRAIN_SOURCE_" + kind]
            coll.hide_viewport = False
            coll.hide_render = False
            for lod in (0, 1):
                root = next(o for o in coll.objects if o.get("lumo_terrain_cover") and o.get("lod") == lod)
                path = kit.TrackPath(kind)
                filename = kind + ("_terrain_lod1.glb" if lod else "_terrain.glb")
                export = assets / filename
                before_signature = geometry_signature(export)
                before_hash = hashlib.sha256(export.read_bytes()).hexdigest()
                changes = [flatten_end_caps(o.data, path) for o in kit.descendants(root) if o.type == "MESH"]
                changed = any(change["changed_smooth_flags"] for change in changes)
                if changed:
                    source_changed = True
                    objects = kit.descendants(root)
                    visibility = {o: (o.hide_render, o.hide_get()) for o in objects}
                    for obj in objects:
                        obj.hide_render = False
                        obj.hide_set(False)
                    kit.export_glb(export, objects)
                    for obj, (render_hidden, viewport_hidden) in visibility.items():
                        obj.hide_render = render_hidden
                        obj.hide_set(viewport_hidden)
                after_signature = geometry_signature(export)
                assert before_signature == after_signature, (theme_id, filename, "geometry or socket change")
                rows.append({"file": filename, "changed": changed, "before_sha256": before_hash,
                             "after_sha256": hashlib.sha256(export.read_bytes()).hexdigest(),
                             "geometry_and_sockets_identical": True, "geometry_signature": after_signature,
                             "normal_changes": changes})
            coll.hide_render = True
            coll.hide_viewport = True
        if source_changed:
            # Review copies own their mesh data; repair the same caps there too.
            review = bpy.data.collections["REVIEW_Assembled_Track"]
            for root in list(review.objects):
                if root.get("lumo_terrain_cover"):
                    path = kit.TrackPath(root["module_kind"])
                    for obj in kit.descendants(root):
                        if obj.type == "MESH":
                            flatten_end_caps(obj.data, path)
            bpy.context.preferences.filepaths.save_version = 0
            bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
        after_source = hashlib.sha256(source.read_bytes()).hexdigest()
        assert frozen_core == {name: hashlib.sha256((assets / name).read_bytes()).hexdigest() for name in frozen_core}, (theme_id, "core asset changed")
        terrain["normal_policy"] = "Flat closed end caps are separated from longitudinal smooth surface normals; geometry and sockets unchanged"
        (assets / "terrain_manifest.json").write_text(json.dumps(terrain, indent=2) + "\n")
        checks = []
        for kind, records in terrain["modules"].items():
            for lod in ("lod0", "lod1"):
                checks.append(verifier.check_asset(assets / records[lod]["file"], records[lod], kind, core["modules"][kind]["length_m"], True))
        (assets / "terrain_blender_verification.json").write_text(json.dumps({"status": "PASS", "theme": theme_id, "blender": bpy.app.version_string,
             "assets": checks, "preserved_core_glbs": len(frozen_core), "physical_device_fps_verified": False}, indent=2) + "\n")
        record = {"theme": theme_id, "status": "PASS", "changed_cover_glbs": sum(row["changed"] for row in rows),
                  "preserved_core_glbs": len(frozen_core), "before_source_sha256": before_source, "after_source_sha256": after_source,
                  "all_cover_triangle_positions_and_socket_transforms_identical": True, "assets": rows}
        overall.append(record)
        (evidence / "terrain_normal_correction.json").write_text(json.dumps({"status": "RUNNING", "themes": overall}, indent=2) + "\n")
        print("LUMO_TERRAIN_NORMALS_PASS", theme_id, record["changed_cover_glbs"], "covers changed", len(frozen_core), "core byte-identical", flush=True)
    (evidence / "terrain_normal_correction.json").write_text(json.dumps({"status": "PASS", "scope": "Normal-only cap correction after a measured and visually compared single-cover probe", "themes": overall}, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--theme", default="zauberwald")
    parser.add_argument("--module", default="straight_12m")
    parser.add_argument("--apply", action="store_true", help="Apply the confirmed normal correction to all selected themes")
    parser.add_argument("--themes", nargs="+", default=list(kit.THEMES))
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo = args.repo.resolve()
    if args.apply:
        apply_corrections(repo, args.themes)
        return
    source = repo / "art/lumo_kart/blender/tracks" / f"{args.theme}_tunnel_workshop.blend"
    assets = repo / "assets/kart/production/tracks" / args.theme
    evidence = repo / "evidence/lumo_kart_art/tracks/normal_probe"
    evidence.mkdir(exist_ok=True)
    original = assets / f"{args.module}_terrain.glb"
    before = geometry_signature(original)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    coll = bpy.data.collections["TERRAIN_SOURCE_" + args.module]
    coll.hide_viewport = False
    coll.hide_render = False
    root = next(o for o in coll.objects if o.get("lumo_terrain_cover") and o.get("lod") == 0)
    path = kit.TrackPath(args.module)
    changes = [flatten_end_caps(o.data, path) for o in kit.descendants(root) if o.type == "MESH"]
    probe = evidence / f"{args.theme}_{args.module}_flat_caps.glb"
    kit.export_glb(probe, kit.descendants(root))
    after = geometry_signature(probe)
    assert before == after, "Probe changed triangle positions, topology or socket transforms"
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash, "Source unexpectedly changed"
    report = {"status": "PASS", "scope": "Single cover normal-only probe; no delivered asset or source modified", "original": str(original.relative_to(repo)), "probe": str(probe.relative_to(repo)), "geometry_and_sockets_identical": True, "geometry_signature": after, "changes": changes}
    (evidence / "probe_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()
