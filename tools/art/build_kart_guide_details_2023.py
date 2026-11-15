"""Author, export, re-import and render the original LUMO shoulder guide kit.

Run with Blender 4.3.2, CPU and two threads. All writes stay in the new details
directories. Existing Comet and tunnel files are read-only composition inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector


NAMES = ("guide_body", "guide_trim", "guide_inset", "guide_signal")
PALETTES = {
    "holo_city": ("233951", "c6a46b", "101c29", "72e6ed"),
    "zauberwald": ("536c59", "d0ad65", "263d34", "a5f0ca"),
    "crystal_canyon": ("665c85", "d4b0da", "29243e", "7ce0ee"),
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def linear(hex_color):
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values)


def material(name, hex_color, roughness, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    rgb = linear(hex_color)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Emission Color"].default_value = (*rgb, 1)
    shader.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*rgb, 1)
    mat["lumo_role"] = name.split(".")[0]
    return mat


def palette(theme):
    colors = PALETTES[theme]
    return {
        NAMES[0]: material(NAMES[0], colors[0], 0.42, 0.12),
        NAMES[1]: material(NAMES[1], colors[1], 0.29, 0.62),
        NAMES[2]: material(NAMES[2], colors[2], 0.68, 0.0),
        NAMES[3]: material(NAMES[3], colors[3], 0.25, 0.0, 1.8),
    }


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def recalc_uv(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    minimum = [min(v.co[i] for v in mesh.vertices) for i in range(3)]
    span = [max(v.co[i] for v in mesh.vertices) - minimum[i] for i in range(3)]
    for poly in mesh.polygons:
        normal_axis = max(range(3), key=lambda i: abs(poly.normal[i]))
        a, b = [i for i in range(3) if i != normal_axis]
        for loop_id in poly.loop_indices:
            point = mesh.vertices[mesh.loops[loop_id].vertex_index].co
            layer.data[loop_id].uv = ((point[a] - minimum[a]) / max(span[a], 1e-8),
                                      (point[b] - minimum[b]) / max(span[b], 1e-8))


def bevel(obj, width, lod):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Crafted edge chamfer", "BEVEL")
    mod.width = width
    mod.segments = 1 if lod else 2
    mod.affect = "EDGES"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    recalc_uv(obj)
    for face in obj.data.polygons:
        face.use_smooth = True
    mod = obj.modifiers.new("Planar weighted normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.weight = 50
    bpy.ops.object.modifier_apply(modifier=mod.name)


def box(name, at, size, mat, lod, edge=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel(obj, min(edge, min(size) * 0.35), lod)
    return obj


def prism(name, outline, axis, center, thickness, mat):
    """Closed extruded polygon; outline is expressed in the two other axes."""
    other = [i for i in range(3) if i != axis]
    verts = []
    for offset in (-thickness / 2, thickness / 2):
        for p, q in outline:
            vertex = list(center)
            vertex[axis] += offset
            vertex[other[0]] += p
            vertex[other[1]] += q
            verts.append(vertex)
    count = len(outline)
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count)
              for i in range(count)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    recalc_uv(obj)
    return obj


def beacon(lod, mats):
    parts = []
    add = lambda *args, **kwargs: parts.append(box(*args, lod=lod, **kwargs))
    add("Beacon_Foot", (0, 0, 0.05), (0.48, 0.68, 0.10), mats["guide_inset"], edge=0.025)
    add("Beacon_Plinth", (0, 0, 0.14), (0.44, 0.62, 0.12), mats["guide_trim"], edge=0.032)
    add("Beacon_CraftedBody", (0, 0, 0.68), (0.40, 0.56, 1.04), mats["guide_body"], edge=0.055)
    add("Beacon_LowerCollar", (0, 0, 0.30), (0.426, 0.58, 0.095), mats["guide_trim"], edge=0.018)
    add("Beacon_CrownSignal", (0, 0, 1.19), (0.424, 0.58, 0.035), mats["guide_signal"], edge=0.008)
    add("Beacon_Crown", (0, 0, 1.2675), (0.44, 0.62, 0.105), mats["guide_trim"], edge=0.035)
    add("Beacon_CrownInset", (0, 0, 1.310), (0.25, 0.41, 0.018), mats["guide_body"], edge=0.006)
    chevron = [(-0.155, -0.205), (-0.052, -0.205), (0.155, 0.0),
               (-0.052, 0.205), (-0.155, 0.205), (0.052, 0.0)]
    for side in (-1, 1):
        add(f"Beacon_SignFrame_{side}", (side * 0.198, 0, 0.785), (0.026, 0.49, 0.63),
            mats["guide_trim"], edge=0.008)
        add(f"Beacon_SignRecess_{side}", (side * 0.214, 0, 0.785), (0.010, 0.44, 0.565),
            mats["guide_inset"], edge=0.003)
        parts.append(prism(f"Beacon_ForwardChevron_{side}", chevron, 0,
                           (side * 0.224, 0, 0.785), 0.008, mats["guide_signal"]))
        if lod == 0:
            for y in (-0.178, 0.178):
                add(f"Beacon_FramePin_{side}_{y}", (side * 0.219, y, 1.047),
                    (0.013, 0.022, 0.022), mats["guide_trim"], edge=0.004)
    return parts


def ribbon(lod, mats):
    parts = []
    add = lambda *args, **kwargs: parts.append(box(*args, lod=lod, **kwargs))
    add("Ribbon_ContactShoe", (0, 0, 0.035), (0.28, 2.00, 0.07), mats["guide_inset"], edge=0.025)
    add("Ribbon_ShoulderBody", (0, 0, 0.115), (0.256, 1.98, 0.16), mats["guide_body"], edge=0.038)
    add("Ribbon_Recess", (0, 0, 0.194), (0.16, 1.88, 0.014), mats["guide_inset"], edge=0.004)
    for side in (-1, 1):
        add(f"Ribbon_Rim_{side}", (side * 0.096, 0, 0.191), (0.027, 1.87, 0.032),
            mats["guide_trim"], edge=0.008)
    add("Ribbon_ContinuousLight", (0, 0, 0.206), (0.028, 1.78, 0.012), mats["guide_signal"], edge=0.003)
    arrow = [(-0.069, -0.066), (-0.045, -0.092), (0, -0.013),
             (0.045, -0.092), (0.069, -0.066), (0, 0.068)]
    for index, distance in enumerate((-0.61, 0.0, 0.61)):
        parts.append(prism(f"Ribbon_ForwardChevron_{index}", arrow, 2,
                           (0, distance, 0.215), 0.010, mats["guide_signal"]))
    for side in (-1, 1):
        add(f"Ribbon_EndCap_{side}", (0, side * 0.943, 0.15), (0.253, 0.06, 0.10),
            mats["guide_trim"], edge=0.016)
    return parts


def mesh_report(objects):
    points, triangles, vertices, bad_faces, nonmanifold = [], 0, 0, 0, 0
    uv_ok, normals_ok, components_positive = True, True, True
    materials = set()
    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices += len(mesh.vertices)
        points += [obj.matrix_world @ v.co for v in mesh.vertices]
        materials.update(m.name for m in mesh.materials if m)
        uv_ok = uv_ok and bool(mesh.uv_layers.active) and all(
            math.isfinite(v) for loop in mesh.uv_layers.active.data for v in loop.uv)
        normals_ok = normals_ok and all(math.isfinite(v) for vertex in mesh.vertices for v in vertex.normal)
        bad_faces += sum(1 for face in mesh.loop_triangles if face.area < 1e-12)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        nonmanifold += sum(not edge.is_manifold for edge in bm.edges)
        components_positive = components_positive and bm.calc_volume(signed=True) > 0
        bm.free()
    bounds = {"min": [min(v[i] for v in points) for i in range(3)],
              "max": [max(v[i] for v in points) for i in range(3)]}
    return dict(mesh_count=len(objects), vertices=vertices, triangles=triangles,
                materials=sorted(materials), material_count=len(materials), bounds_blender_m=bounds,
                dimensions_m=[bounds["max"][i] - bounds["min"][i] for i in range(3)],
                nonmanifold_edges=nonmanifold, degenerate_triangles=bad_faces,
                finite_uvs=uv_ok, finite_normals=normals_ok, positive_component_volumes=components_positive)


def export_module(parts, path, name):
    bpy.ops.object.select_all(action="DESELECT")
    copies = []
    for source in parts:
        obj = source.copy()
        obj.data = source.data.copy()
        bpy.context.collection.objects.link(obj)
        obj.select_set(True)
        copies.append(obj)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj["lumo_asset"] = name
    obj["lumo_original_geometry"] = True
    obj["lumo_forward"] = "+Y in Blender; -Z in Godot"
    obj["lumo_role"] = "visual shoulder guidance; no collision or light nodes"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_extras=True,
                              export_cameras=False, export_lights=False, export_texcoords=True,
                              export_normals=True, export_tangents=False)
    report = mesh_report([obj])
    bpy.data.objects.remove(obj, do_unlink=True)
    return report


def glb_report(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2 and length == len(data)
    chunk_length, chunk_kind = struct.unpack_from("<II", data, 12)
    assert chunk_kind == 0x4e4f534a
    info = json.loads(data[20:20 + chunk_length])
    assert len(info["meshes"]) == 1
    primitives = info["meshes"][0]["primitives"]
    assert len(primitives) == 4
    assert all("NORMAL" in p["attributes"] and "TEXCOORD_0" in p["attributes"] for p in primitives)
    assert all("uri" not in image for image in info.get("images", []))
    return {"meshes": len(info["meshes"]), "material_surfaces": len(primitives),
            "materials": [m["name"] for m in info["materials"]],
            "embedded_images": len(info.get("images", [])), "external_dependencies": 0,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def build(root):
    reset()
    target = root / "assets/kart/production/details"
    source = root / "art/lumo_kart/blender/details"
    evidence = root / "evidence/lumo_kart_art/details2023"
    for path in (target, source, evidence):
        path.mkdir(parents=True, exist_ok=True)
    mats = palette("holo_city")
    modules, source_collections = {}, []
    for name, creator in (("lumo_guide_beacon", beacon), ("lumo_guide_ribbon_2m", ribbon)):
        for lod in (0, 1):
            filename = name + ("_lod1" if lod else "") + ".glb"
            collection = bpy.data.collections.new(name + f"_Editable_LOD{lod}")
            bpy.context.scene.collection.children.link(collection)
            parts = creator(lod, mats)
            for obj in parts:
                for old in list(obj.users_collection):
                    old.objects.unlink(obj)
                collection.objects.link(obj)
            bpy.context.view_layer.update()
            source_report = mesh_report(parts)
            assert source_report["nonmanifold_edges"] == 0 and source_report["degenerate_triangles"] == 0
            assert source_report["positive_component_volumes"] and source_report["finite_uvs"]
            packed = export_module(parts, target / filename, name)
            modules[filename] = {"lod": lod, "geometry": packed, "glb": glb_report(target / filename)}
            collection.hide_render = lod == 1
            source_collections.append((collection, name, lod))
    for collection, name, lod in source_collections:
        for obj in collection.objects:
            obj.location.x += 0.75 if "ribbon" in name else -0.45
            if lod:
                obj.hide_set(True)
    scene = bpy.context.scene
    scene["LUMO_guide_contract"] = "Sources are editable parts; exported GLBs each contain one mesh and four materials. Meter units, +Y forward, +Z up."
    scene["LUMO_originals_preserved"] = "Existing karts and tunnel sources are read-only. No animation or gameplay changes."
    scene["LUMO_placement"] = "Place roots at road-frame lateral +/-6.50 m, outside old curb at6.13+/-0.09m. Avoid old rib/root stations."
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source / "lumo_guide_details_2023.blend"), compress=True)
    manifest = {
        "schema": 1, "name": "LUMO shoulder guide details", "version": 2023,
        "authoring": "Original deterministic Blender geometry authored for this LUMO project; no external model or paid generator",
        "license": "Original project artwork; distribution follows the LUMO repository license. No third-party model or texture inputs in the new GLBs.",
        "blender": bpy.app.version_string, "units": "meters", "source_blend": str((source / "lumo_guide_details_2023.blend").relative_to(root)),
        "axes": {"blender_forward": "+Y", "blender_up": "+Z", "godot_forward": "-Z", "godot_up": "+Y"},
        "placement": {"root": "floor center", "recommended_lateral_m": 6.50,
                      "road_half_width_m": 5.4, "reserved_clear_half_width_m": 5.9,
                      "existing_curb_center_m": 6.13, "existing_curb_radius_m": 0.09,
                      "existing_inner_wall_half_width_m": 6.8,
                      "mirror": False, "facing": "Both sides use the same road-frame basis, forward chevrons on both lateral faces",
                      "colliders": 0, "light_nodes": 0},
        "materials": {name: {"role": role} for name, role in zip(NAMES, ("theme body", "edge and rim", "dark recess", "forward signal with bounded emission"))},
        "palette_srgb": PALETTES, "mobile_policy": {"max_meshes_per_glb": 1, "max_surfaces_per_glb": 4,
            "textures": 0, "alpha_blending": False, "material_policy": "shared by theme; instancing supported"},
        "modules": modules,
        "source_sha256": digest(source / "lumo_guide_details_2023.blend"),
        "builder_sha256": digest(Path(__file__)),
        "android_runtime_verified": False,
    }
    (target / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    verify(root)
    print("LUMO_GUIDE_EXPORT_READY", json.dumps({k: v["glb"] for k, v in modules.items()}), flush=True)


def verify(root):
    target = root / "assets/kart/production/details"
    evidence = root / "evidence/lumo_kart_art/details2023"
    manifest = json.loads((target / "manifest.json").read_text())
    results = {}
    for filename, expected in manifest["modules"].items():
        reset()
        path = target / filename
        before = digest(path)
        bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        report = mesh_report(meshes)
        static = glb_report(path)
        checks = {
            "one_mesh_four_surfaces": static["meshes"] == 1 and static["material_surfaces"] == 4,
            "exact_material_roles": set(static["materials"]) == set(NAMES),
            "round_trip_bounds": all(abs(a - b) < 0.0001 for k in ("min", "max")
                for a, b in zip(report["bounds_blender_m"][k], expected["geometry"]["bounds_blender_m"][k])),
            "finite_normals_uvs": report["finite_normals"] and report["finite_uvs"],
            "no_degenerate_faces": report["degenerate_triangles"] == 0,
            "positive_volume": report["positive_component_volumes"],
            "bytes_unchanged": before == digest(path) == expected["glb"]["sha256"],
            "no_external_dependencies": static["external_dependencies"] == 0,
            "under_triangle_budget": report["triangles"] <= (2600 if expected["lod"] == 0 else 1400),
        }
        assert all(checks.values()), (filename, checks, report)
        results[filename] = {"checks": checks, "reimport": report, "glb": static}
    (evidence / "blender_reimport_verification.json").write_text(json.dumps(
        {"status": "PASS", "blender": bpy.app.version_string, "modules": results,
         "scope": "Static exported bytes and actual Blender re-import; no Android performance claim"}, indent=2) + "\n")
    print("LUMO_GUIDE_REIMPORT_PASS", len(results), flush=True)


def camera(at, focus, lens=50, ortho=None):
    data = bpy.data.cameras.new("ReviewCamera")
    obj = bpy.data.objects.new("ReviewCamera", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = at
    obj.rotation_euler = (Vector(focus) - obj.location).to_track_quat("-Z", "Y").to_euler()
    data.lens = lens
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    bpy.context.scene.camera = obj
    return obj


def area(name, at, focus, power, size, color="ffffff"):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = power, "DISK", size, linear(color)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = at
    obj.rotation_euler = (Vector(focus) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_setup(width=1500, height=1100, samples=96):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    available_denoisers = {item.identifier for item in scene.cycles.bl_rna.properties["denoiser"].enum_items}
    scene.cycles.use_denoising = "OPENIMAGEDENOISE" in available_denoisers
    if scene.cycles.use_denoising:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.006
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 4
    scene.render.threads_mode, scene.render.threads = "FIXED", 2
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("ReviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (*linear("b7cbd7"), 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.45
    return scene


def import_asset(path, at=(0, 0, 0), theme=None):
    existing = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = set(bpy.data.objects) - existing
    for obj in imported:
        if obj.parent not in imported:
            obj.location += Vector(at)
        if theme and obj.type == "MESH":
            recolored = palette(theme)
            for i, mat in enumerate(obj.data.materials):
                role = mat.name.split(".")[0]
                if role in recolored:
                    obj.data.materials[i] = recolored[role]
    return list(imported)


def label(text, at, size, color="ddeaf1", rotation=(math.pi / 2, 0, 0)):
    curve = bpy.data.curves.new("ReviewLabel", "FONT")
    curve.body, curve.size, curve.extrude = text, size, 0.0002
    obj = bpy.data.objects.new("ReviewLabel", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location, obj.rotation_euler = at, rotation
    curve.materials.append(material("ReviewLabelInk", color, 0.7))
    return obj


def denoise_render(scene, output, executable):
    """Denoise actual linear Cycles output with the separately verified CPU CLI."""
    raw_png = output.with_name(output.stem + "_raw.png")
    raw_exr = output.with_suffix(".working.exr")
    input_pfm = output.with_suffix(".working.pfm")
    output_pfm = output.with_suffix(".denoised.pfm")
    render_result = bpy.data.images["Render Result"]
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "8"
    render_result.save_render(filepath=str(raw_png), scene=scene)
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_depth = "32"
    render_result.save_render(filepath=str(raw_exr), scene=scene)
    raw = bpy.data.images.load(str(raw_exr), check_existing=False)
    width, height = raw.size[:]
    pixels = np.empty(width * height * 4, dtype=np.float32)
    raw.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    assert np.isfinite(pixels).all()
    with input_pfm.open("wb") as stream:
        stream.write(f"PF\n{width} {height}\n-1.0\n".encode("ascii"))
        stream.write(pixels[:, :, :3].astype("<f4").tobytes())
    command = [str(executable), "--device", "cpu", "--hdr", str(input_pfm),
               "--output", str(output_pfm), "--quality", "high", "--threads", "2",
               "--maxmem", "512", "--affinity", "0"]
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    with output_pfm.open("rb") as stream:
        assert stream.readline().strip() == b"PF"
        assert tuple(map(int, stream.readline().split())) == (width, height)
        assert float(stream.readline()) < 0
        clean = np.frombuffer(stream.read(), dtype="<f4").reshape(height, width, 3)
    assert np.isfinite(clean).all()
    pixels[:, :, :3] = clean
    result = bpy.data.images.new("OIDN_ActualCyclesOutput", width=width, height=height,
                                 alpha=True, float_buffer=True)
    result.colorspace_settings.name = raw.colorspace_settings.name
    result.pixels.foreach_set(pixels.reshape(-1))
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "8"
    result.save_render(filepath=str(output), scene=scene)
    receipt = {"source": "Actual unmodified Cycles linear render pixels",
               "input_raw_png": raw_png.name, "input_raw_png_sha256": digest(raw_png),
               "input_linear_exr_sha256": digest(raw_exr), "input_pfm_sha256": digest(input_pfm),
               "output_pfm_sha256": digest(output_pfm), "output_png_sha256": digest(output),
               "executable_sha256": digest(executable), "command": command,
               "returncode": completed.returncode, "stdout": completed.stdout, "stderr": completed.stderr,
               "output_size": [width, height], "finite_output": True,
               "color_management": f"Linear {raw.colorspace_settings.name} -> same Blender AgX scene view transform"}
    bpy.data.images.remove(raw)
    bpy.data.images.remove(result)
    for temporary in (raw_exr, input_pfm, output_pfm):
        temporary.unlink()
    return receipt


def render(root, view, oidn_executable=None):
    reset()
    scene = render_setup(1600, 1100, (96 if view == "context" else 64) if oidn_executable else 256)
    target = root / "assets/kart/production/details"
    evidence = root / "evidence/lumo_kart_art/details2023"
    floor = material("ReviewFloor", "14252e", 0.5, 0.07)
    inputs = [target / "lumo_guide_beacon.glb", target / "lumo_guide_ribbon_2m.glb"]
    if view == "detail":
        import_asset(inputs[0], (-0.4, 0.15, 0))
        import_asset(inputs[1], (0.48, 0.22, 0))
        box("StudioPlinth", (0.0, 0.05, -0.115), (2.2, 2.9, 0.23), floor, 0, 0.07)
        camera((3.5, -4.8, 3.25), (0.0, 0.05, 0.50), ortho=4.1)
        area("KeySoftbox", (0, -3, 5), (0, 0, 0.5), 600, 4, "e4f4ff")
        area("GoldEdge", (-3, 1.2, 3), (0, 0, 0.5), 450, 3, "ffd6a1")
        area("SignalRim", (3, 3, 3.2), (0, 0, 0.5), 700, 3, "b4e6f0")
        label("LUMO / GUIDE DETAILS", (-0.83, -1.412, -0.063), 0.115)
    elif view == "palettes":
        for index, theme in enumerate(("zauberwald", "crystal_canyon", "holo_city")):
            x = (index - 1) * 1.48
            import_asset(inputs[0], (x - 0.27, 0.12, 0), theme)
            import_asset(inputs[1], (x + 0.29, 0.10, 0), theme)
            box("PalettePlinth", (x, 0, -0.11), (1.36, 2.6, 0.22), floor, 0, 0.06)
            text = {"zauberwald": "WALD", "crystal_canyon": "KRISTALL", "holo_city": "NEON"}[theme]
            label(text, (x - 0.48, -1.306, -0.052), 0.14)
        camera((5.0, -9.8, 5.4), (0, 0, 0.52), ortho=6.15)
        area("StudioKey", (0, -5, 7), (0, 0, 0), 1400, 6, "e9f4ff")
        area("WarmFill", (-5, 0, 4), (0, 0, 0.6), 1100, 5, "ffe0bd")
        area("CoolRim", (4, 4, 5), (0, 0, 0.6), 1700, 5, "bfebff")
    elif view == "context":
        track = root / "assets/kart/production/tracks/zauberwald"
        for filename, at in (("portal_entry.glb", (0, 0, 0)), ("straight_12m.glb", (0, 4, 0)),
                             ("portal_exit.glb", (0, 16, 0))):
            inputs.append(track / filename)
            import_asset(track / filename, at)
        comet = root / "assets/kart/production/karts/aurora_comet.glb"
        inputs.append(comet)
        import_asset(comet, (1.7, -2.8, 0))
        for side in (-1, 1):
            for distance in (-3.5, 2.0, 10.0, 18.0):
                import_asset(target / "lumo_guide_beacon.glb", (side * 6.50, distance, 0), "zauberwald")
            for distance in (-1.6, 6.24, 13.76):
                import_asset(target / "lumo_guide_ribbon_2m.glb", (side * 6.50, distance, 0), "zauberwald")
        road = material("ReviewRoad", "414d49", 0.92)
        box("ReviewRoad", (0, 6, -0.14), (10.8, 34, 0.27), road, 0, 0.01)
        ground = material("ReviewLandscape", "314d3e", 0.94)
        box("ReviewGround", (0, 8, -0.28), (72, 72, 0.3), ground, 0, 0.01)
        camera((16.0, -22.0, 11.0), (0.0, 5.0, 3.0), lens=43)
        area("ForestSoftSun", (-5, -7, 17), (0, 5, 1), 14500, 11, "ffefd4")
        area("ForestFrontFill", (10, -11, 10), (0, 2, 2), 8000, 9, "d1edff")
        area("ForestPortalFill", (0, 4, 5), (0, 8, 0), 1400, 5, "d6f7dc")
        area("ForestBackRim", (-8, 15, 13), (0, 8, 2), 12000, 8, "cfeddf")
        scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    else:
        raise ValueError(view)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.29 if view != "context" else -0.44))
    bpy.context.object.name = "ReviewBackdrop"
    bpy.context.object.data.materials.append(floor)
    output = evidence / f"lumo_guide_{view}.png"
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=oidn_executable is None)
    denoise_receipt = denoise_render(scene, output, oidn_executable) if oidn_executable else None
    receipt = {"view": view, "renderer": "Blender Cycles CPU", "blender": bpy.app.version_string,
               "samples": scene.cycles.samples,
               "denoiser": "Separate offline Open Image Denoise CPU 2.5.1" if denoise_receipt else (
                   "OpenImageDenoise" if scene.cycles.use_denoising else "Unavailable in installed Blender; higher sampling used"),
               "threads": 2,
               "resolution": [scene.render.resolution_x, scene.render.resolution_y],
               "camera": {"position_blender_m": list(scene.camera.location),
                   "quaternion_wxyz": list(scene.camera.rotation_euler.to_quaternion()),
                   "type": scene.camera.data.type, "lens_mm": scene.camera.data.lens,
                   "orthographic_scale": scene.camera.data.ortho_scale},
               "source_hashes": {str(p.relative_to(root)): digest(p) for p in inputs},
               "output": str(output.relative_to(root)), "sha256": digest(output),
               "classification": "Authored asset presentation rendered in Blender, not an Android or Godot gameplay screenshot",
               "denoise_pass": denoise_receipt}
    (evidence / f"render_{view}.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("LUMO_GUIDE_RENDER_DONE", output, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--phase", choices=("build", "verify", "render"), required=True)
    parser.add_argument("--view", choices=("detail", "palettes", "context"), default="detail")
    parser.add_argument("--oidn-executable", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    root = args.repo.resolve()
    if args.phase == "build":
        build(root)
    elif args.phase == "verify":
        verify(root)
    else:
        render(root, args.view, args.oidn_executable.resolve() if args.oidn_executable else None)


if __name__ == "__main__":
    main()
