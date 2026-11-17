"""Original bevelled Sonnenhafen geology, authored with Blender mesh operations.

blender --background --threads 1 --python tools/art/generate_kart_mineral_kit.py -- assets/kart/cavern/mineral_kit
No provider, downloaded mesh, texture, collision, or animation is involved.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_kart_mineral_kit import inspect_glb

SEED = 261018
IDENTITIES = ("strata_shelf", "split_ledge", "hanging_canopy", "crystal_fan", "crystal_spire", "crystal_rosette")


def mesh_object(name, points, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    node = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(node)
    return node


def stone_layer(name, center, radii, phase, sides, bevel, steps):
    points = []
    for height, multiplier in ((-radii[2], 0.88), (radii[2], 1.0)):
        for index in range(sides):
            angle = math.tau * index / sides
            contour = 1.0 + 0.09 * math.sin(angle * 3.0 + phase)
            points.append((center[0] + math.cos(angle) * radii[0] * multiplier * contour,
                           center[1] + math.sin(angle) * radii[1] * multiplier * contour,
                           center[2] + height + 0.045 * math.sin(angle * 2.0 + phase)))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
    faces.extend((i, (i + 1) % sides, (i + 1) % sides + sides, i + sides) for i in range(sides))
    node = mesh_object(name, points, faces)
    bpy.context.view_layer.objects.active = node
    node.select_set(True)
    modifier = node.modifiers.new("Carved mineral edge bevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = steps
    modifier.affect = "EDGES"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    node.select_set(False)
    return node


def make_stone(identity, profile):
    sides, bevel_steps = (10, 2) if profile == "high" else (6, 1)
    layers = {
        "strata_shelf": [((0.04, 0.0, 0.27), (0.78, 2.42, 0.23)),
                         ((-0.08, 0.14, 0.77), (0.94, 2.12, 0.23)),
                         ((0.10, -0.12, 1.35), (0.79, 1.86, 0.31)),
                         ((0.17, 0.20, 1.96), (0.64, 1.54, 0.30))],
        "split_ledge": [((0.0, 0.0, 0.30), (0.96, 1.64, 0.26)),
                        ((-0.17, 0.08, 0.92), (0.78, 1.43, 0.34)),
                        ((0.13, -0.17, 1.63), (1.04, 1.67, 0.34))],
        "hanging_canopy": [((0.17, 0.28, 0.36), (0.38, 0.72, 0.29)),
                           ((-0.16, -0.28, 0.97), (0.59, 1.08, 0.32)),
                           ((0.04, 0.04, 1.59), (0.84, 1.51, 0.32)),
                           ((0.01, 0.0, 2.20), (1.09, 1.94, 0.30))],
    }[identity]
    return [stone_layer(f"{identity}_stratum_{i}", center, radii, 0.63 + i * 1.77,
                        sides, 0.10 if identity != "hanging_canopy" else 0.085,
                        bevel_steps) for i, (center, radii) in enumerate(layers)]


def shard(name, position, height, radius, lean, phase, sides):
    points = []
    # Three independently offset rings create shoulders and real clipped facets.
    for ring_height, width in ((0.0, 0.78), (height * 0.12, 1.0), (height * 0.77, 0.86)):
        for index in range(sides):
            angle = math.tau * index / sides + phase
            r = radius * width * (1.0 + 0.07 * math.sin(angle * 2.0 + phase))
            points.append((position[0] + math.cos(angle) * r + lean[0] * ring_height,
                           position[1] + math.sin(angle) * r + lean[1] * ring_height,
                           position[2] + ring_height))
    tip = len(points)
    points.append((position[0] + lean[0] * height + radius * 0.18,
                   position[1] + lean[1] * height - radius * 0.12, position[2] + height))
    faces = [tuple(reversed(range(sides)))]
    for ring in range(2):
        faces.extend((ring * sides + i, ring * sides + (i + 1) % sides,
                      (ring + 1) * sides + (i + 1) % sides, (ring + 1) * sides + i)
                     for i in range(sides))
    faces.extend((2 * sides + i, 2 * sides + (i + 1) % sides, tip) for i in range(sides))
    return mesh_object(name, points, faces)


def make_crystal(identity, profile):
    sides = 8 if profile == "high" else 4
    if identity == "crystal_fan":
        specifications = [((-0.84, 0.0, 0.05), 1.58, 0.27, (-0.28, 0.01)),
                          ((-0.42, 0.05, 0.0), 2.26, 0.31, (-0.18, 0.0)),
                          ((0.0, 0.0, 0.0), 2.68, 0.36, (0.02, 0.02)),
                          ((0.43, 0.02, 0.02), 2.05, 0.30, (0.23, 0.02)),
                          ((0.82, -0.02, 0.02), 1.37, 0.25, (0.34, -0.04))]
        if profile == "high":
            specifications += [((-0.30, -0.38, 0.03), 1.08, 0.24, (-0.24, -0.17)),
                               ((0.30, -0.32, 0.02), 1.33, 0.24, (0.22, -0.18))]
    elif identity == "crystal_spire":
        specifications = [((0.03, 0.03, 0.0), 3.34, 0.45, (-0.10, 0.06)),
                          ((-0.48, -0.14, 0.0), 2.03, 0.29, (-0.19, -0.05)),
                          ((0.45, 0.24, 0.0), 1.64, 0.27, (0.20, 0.08))]
        if profile == "high":
            specifications += [((0.19, -0.38, 0.0), 1.11, 0.24, (0.15, -0.18)),
                               ((-0.29, 0.38, 0.0), 1.47, 0.22, (-0.07, 0.16))]
    else:
        specifications = [((0.0, 0.0, 0.0), 1.82, 0.39, (0.03, 0.02))]
        petals = 8 if profile == "high" else 4
        for i in range(petals):
            angle = math.tau * i / petals
            specifications.append(((math.cos(angle) * 0.40, math.sin(angle) * 0.40, 0.0),
                                   1.18 + 0.15 * math.sin(angle * 2.0), 0.26,
                                   (math.cos(angle) * 0.40, math.sin(angle) * 0.40)))
    return [shard(f"{identity}_shard_{i}", p, height, radius, lean, 0.28 + i * 0.61, sides)
            for i, (p, height, radius, lean) in enumerate(specifications)]


def finish_mesh(identity, nodes):
    bpy.ops.object.select_all(action="DESELECT")
    for node in nodes:
        node.select_set(True)
    bpy.context.view_layer.objects.active = nodes[0]
    bpy.ops.object.join()
    node = nodes[0]
    node.name = identity
    mesh = node.data
    minimum = min(vertex.co.z for vertex in mesh.vertices)
    height = max(vertex.co.z for vertex in mesh.vertices) - minimum
    target = {"strata_shelf": 2.30, "split_ledge": 2.0, "hanging_canopy": 2.50}.get(identity, height)
    for vertex in mesh.vertices:
        vertex.co.z = (vertex.co.z - minimum) * target / height
    mesh.uv_layers.new(name="MineralUV")
    mesh.color_attributes.new(name="MineralFacet", type="FLOAT_COLOR", domain="CORNER")
    # Adding a color attribute reorders Blender's underlying CustomData layers.
    # Resolve both RNA handles afterwards: an earlier UV handle can otherwise
    # alias the new color storage and silently overwrite RGB with UV floats.
    uv_layer = mesh.uv_layers["MineralUV"]
    colors = mesh.color_attributes["MineralFacet"]
    for polygon in mesh.polygons:
        polygon.use_smooth = False
        luminance = 0.81 + 0.16 * (0.5 + 0.5 * math.sin(polygon.center.z * 6.0 + polygon.index * 0.47))
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = (vertex.x * 0.42 + vertex.y * 0.16, vertex.z * 0.37)
            colors.data[loop_index].color = (luminance, luminance, luminance, 1.0)
    mesh.color_attributes.active_color = colors
    material = bpy.data.materials.new("OriginalMineralSurface")
    material.diffuse_color = (0.55, 0.71, 0.75, 1.0) if identity.startswith("crystal") else (0.30, 0.39, 0.47, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = material.diffuse_color
    shader.inputs["Roughness"].default_value = 0.26 if identity.startswith("crystal") else 0.69
    facet = material.node_tree.nodes.new("ShaderNodeVertexColor")
    facet.layer_name = "MineralFacet"
    material.node_tree.links.new(facet.outputs["Color"], shader.inputs["Base Color"])
    mesh.materials.clear()
    mesh.materials.append(material)
    mesh.update()
    assert all(max(value.color[:3]) - min(value.color[:3]) < 1e-6
               and 0.6 <= value.color[0] <= 1.0 for value in mesh.color_attributes["MineralFacet"].data), \
        "Blender source facet storage must contain readable grayscale, never UV data"
    return node


def generate(destination):
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 1, "asset_id": "sonnenhafen_tactile_mineral_kit", "seed": SEED,
                "provenance": "Original Lumo geometry authored with deterministic Blender mesh operations; no external assets or provider",
                "license": "Project-original; same license as repository", "blender": bpy.app.version_string,
                "source": "tools/art/generate_kart_mineral_kit.py", "assets": {},
                "physical_device_fps_verified": False}
    for identity in IDENTITIES:
        variants = {}
        for profile in ("high", "mobile"):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            nodes = make_crystal(identity, profile) if identity.startswith("crystal") else make_stone(identity, profile)
            finish_mesh(identity, nodes)
            file = destination / f"{identity}_{profile}.glb"
            if file.is_symlink():
                raise ValueError("refusing to replace a symlink")
            bpy.ops.export_scene.gltf(filepath=str(file.resolve()), export_format="GLB",
                                      use_selection=True, export_apply=True, export_yup=True,
                                      export_texcoords=True, export_normals=True, export_materials="EXPORT",
                                      export_attributes=False, export_animations=False, export_cameras=False,
                                      export_lights=False, export_unused_images=False)
            variants[profile] = dict(inspect_glb(file.read_bytes()), file_name=file.name, profile=profile)
        manifest["assets"][identity] = {"kind": "crystal" if identity.startswith("crystal") else "stone",
                                          "variants": variants}
    (destination / "mineral_kit.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("[MineralKit] generated 6 original silhouettes in paired real geometry LODs")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    generate(Path(args[0] if args else "assets/kart/cavern/mineral_kit"))
