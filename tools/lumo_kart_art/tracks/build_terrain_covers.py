"""Attach original terrain/architectural roof covers without changing core GLBs."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import time

import bpy
import bmesh
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_tunnel_kit as kit
import verify_tunnel_kit as verifier


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def remove_collection(name):
    coll = bpy.data.collections.get(name)
    if coll:
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(coll)


def terrain_material(theme_id, theme):
    mat = bpy.data.materials.new(theme_id + "_TerrainVertexPBR")
    mat.use_nodes = True
    mat.use_backface_culling = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    technical = theme["form"] in ("tech", "space", "lab")
    bsdf.inputs["Roughness"].default_value = 0.45 if technical else 0.91
    bsdf.inputs["Metallic"].default_value = 0.45 if technical else 0
    colors = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    colors.layer_name = "TerrainTint"
    mat.node_tree.links.new(colors.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def cross_section(path, t, layer, theme, steps=32):
    kind = path.kind
    transition = 0.0
    if kind == "portal_entry":
        transition = 1.0 - (3 * t * t - 2 * t * t * t)
    elif kind == "portal_exit":
        transition = 3 * t * t - 2 * t * t * t
    if layer == 0:
        rx, rz = 7.62 + transition * 0.68, 5.67 + transition * 0.68
        points = [(rx, -1.14), (rx, 0.55), (rx, 1.35), (rx, 2.1)]
        points += [(rx * math.cos(i * math.pi / steps), 2.65 + rz * math.sin(i * math.pi / steps)) for i in range(steps + 1)]
        points += [(-rx, 2.1), (-rx, 1.35), (-rx, 0.55), (-rx, -1.14)]
        return points
    rx, crown = 14.2 - transition * 4.5, 11.8 - transition * 1.6
    technical = theme["form"] in ("tech", "space", "lab")
    power = 0.72 if technical else 1.3
    points = [(rx, -1.85), (rx, -1.2), (rx, -0.6), (rx, -0.15)]
    for i in range(steps + 1):
        a = i * math.pi / steps
        relief = 0 if technical else 0.38 * math.sin(math.pi * t) ** 2 * math.sin(a) * (math.sin(3 * a + 0.7) + 0.35 * math.sin(7 * a + 1.9))
        x = rx * math.cos(a)
        z = crown * max(0, math.sin(a)) ** power + relief
        points.append((x, z))
    points += [(-rx, -0.15), (-rx, -0.6), (-rx, -1.2), (-rx, -1.85)]
    return points


def make_cover(theme_id, theme, kind, mat, coll, lod):
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[coll.name]
    path = kit.TrackPath(kind)
    nlong = max(4, math.ceil(path.length / (3.0 if lod else 1.0)))
    count = len(cross_section(path, 0, 0, theme))
    verts, uv, faces, meta = [], [], [], []
    for layer in range(2):
        for row in range(nlong + 1):
            t = row / nlong
            profile = cross_section(path, t, layer, theme)
            circ = 0
            for j, (x, z) in enumerate(profile):
                if j:
                    circ += math.dist(profile[j - 1], profile[j])
                verts.append(path.pos(path.length * t, x, z))
                uv.append((circ / 2, path.length * t / 2))
                meta.append((layer, row, j, z, t))
    stride = (nlong + 1) * count
    for layer in range(2):
        for row in range(nlong):
            for j in range(count):
                a = layer * stride + row * count + j
                b = layer * stride + row * count + (j + 1) % count
                quad = (a, a + count, b + count, b)
                faces.append(tuple(reversed(quad)) if layer == 0 else quad)
    for row in (0, nlong):
        for j in range(count):
            a, b = row * count + j, row * count + (j + 1) % count
            quad = (a, b, b + stride, a + stride)
            faces.append(tuple(reversed(quad)) if row == 0 else quad)
    root = bpy.data.objects.new(f"{theme_id}_{kind}_TerrainLOD{lod}", None)
    coll.objects.link(root)
    root["lumo_terrain_cover"] = True
    root["module_kind"] = kind
    root["theme"] = theme_id
    root["lod"] = lod
    root["does_not_replace_road"] = True
    smooth = theme["form"] not in ("basalt", "crystal")
    obj = kit.mesh_object("TerrainRoof", verts, faces, mat, root, uv, smooth)
    # Closed ring caps must not bend the longitudinal surface normals at joins.
    # Keep all triangle positions and end profiles unchanged.
    for polygon in obj.data.polygons:
        if polygon.index >= 2 * nlong * count:
            polygon.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    base_hex = theme["secondary"] if theme["form"] in ("root", "temple") else (theme["inner"] if theme["form"] == "basalt" else theme["roof"])
    base = kit.srgb(base_hex)
    secondary = kit.srgb(theme["secondary"])
    attr = obj.data.color_attributes.new(name="TerrainTint", type="BYTE_COLOR", domain="CORNER")
    obj.data.color_attributes.active_color = attr
    for polygon in obj.data.polygons:
        for li in polygon.loop_indices:
            layer, row, index, z, t = meta[obj.data.loops[li].vertex_index]
            shade = 0.82 + 0.15 * max(0.0, min(1.0, z / 12)) + 0.055 * math.sin(index * 0.81 + t * math.tau * 2)
            if layer == 0:
                shade *= 0.55
            blend = 0.12 + 0.12 * math.sin(index * 0.52) if theme["form"] == "candy" else 0
            rgb = [(base[k] * (1 - blend) + secondary[k] * blend) * shade for k in range(3)]
            attr.data[li].color = (*rgb, 1)
    for label, s in (("in", 0), ("out", path.length)):
        marker = bpy.data.objects.new("SocketIn" if label == "in" else "SocketOut", None)
        coll.objects.link(marker)
        marker.parent = root
        marker.matrix_local = path.matrix(s)
        marker["lumo_socket"] = label
    return root, path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--themes", nargs="+", default=list(kit.THEMES))
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo = args.repo.resolve()
    for theme_id in args.themes:
        assets = repo / "assets/kart/production/tracks" / theme_id
        verification = assets / "blender_reimport_verification.json"
        deadline = time.monotonic() + 600
        while not verification.exists():
            if time.monotonic() > deadline:
                raise RuntimeError(f"Core verification unavailable for {theme_id}")
            time.sleep(1)
        if json.loads(verification.read_text())["status"] != "PASS":
            raise RuntimeError(f"Core did not pass for {theme_id}")
        frozen = {p.name: digest(p) for p in assets.glob("*.glb") if "_terrain" not in p.name}
        core = json.loads((assets / "manifest.json").read_text())
        source = repo / core["source_blend"]
        bpy.ops.wm.open_mainfile(filepath=str(source))
        theme = kit.THEMES[theme_id]
        mat = terrain_material(theme_id, theme)
        roots, paths, modules = {}, {}, {}
        for kind in core["modules"]:
            coll_name = "TERRAIN_SOURCE_" + kind
            remove_collection(coll_name)
            coll = kit.collection(coll_name)
            records = {}
            for lod in (0, 1):
                root, path = make_cover(theme_id, theme, kind, mat, coll, lod)
                filename = kind + ("_terrain_lod1.glb" if lod else "_terrain.glb")
                kit.export_glb(assets / filename, kit.descendants(root))
                record = kit.audit(root)
                assert record["nonmanifold_edges"] == 0 and record["degenerate_triangles"] == 0, (theme_id, filename, record)
                records["lod1" if lod else "lod0"] = dict(file=filename, **record)
                if lod == 0:
                    roots[kind], paths[kind] = root, path
                else:
                    # Keep low-detail source geometry separate and hidden.
                    for child in kit.descendants(root):
                        child.hide_render = True
                        child.hide_set(True)
            coll.hide_render = True
            coll.hide_viewport = True
            modules[kind] = records
        review = bpy.data.collections["REVIEW_Assembled_Track"]
        for obj in list(review.objects):
            if obj.name.startswith("TerrainDemo_"):
                bpy.data.objects.remove(obj, do_unlink=True)
        transform = Matrix.Identity(4)
        for i, kind in enumerate(("portal_entry", "straight_12m", "curve_right_30", "straight_12m", "portal_exit")):
            kit.instance_module(roots[kind], review, transform, f"TerrainDemo_{i}")
            transform = transform @ paths[kind].matrix(paths[kind].length)
        bpy.ops.file.pack_all()
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
        assert frozen == {name: digest(assets / name) for name in frozen}, f"Core GLB changed for {theme_id}"
        manifest = dict(schema=1, theme=theme_id, source_blend=core["source_blend"],
                        description="Separate closed terrain or architectural cover shell around the existing tunnel",
                        additional_glbs=14, modules=modules, textures="No image textures; original per-vertex terrain colors",
                        material_count=1, ordinary_outer_width_m=28.4, ordinary_crown_height_m=11.8,
                        portal_outer_width_m=19.4, portal_crown_height_m=10.2,
                        core_overlap_m=0.03, collision_policy="Visual landscape cover; use the existing tunnel collision and the main team's terrain collider",
                        lod_policy="Identical socket/end profiles; longitudinal tessellation reduced in LOD1",
                        normal_policy="Flat closed end caps are separated from longitudinal smooth surface normals",
                        preserved_core_glb_sha256=frozen, runtime_integration=False)
        (assets / "terrain_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        checks = []
        for kind, records in modules.items():
            for lod in ("lod0", "lod1"):
                checks.append(verifier.check_asset(assets / records[lod]["file"], records[lod], kind, core["modules"][kind]["length_m"], True))
        (assets / "terrain_blender_verification.json").write_text(json.dumps(dict(status="PASS", theme=theme_id, blender=bpy.app.version_string, assets=checks, preserved_core_glbs=len(frozen), physical_device_fps_verified=False), indent=2) + "\n")
        print("LUMO_TERRAIN_PASS", theme_id, len(checks), "core_unchanged", len(frozen), flush=True)


if __name__ == "__main__":
    main()
