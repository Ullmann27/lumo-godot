#!/usr/bin/env python3
"""Review renders of the jungle GLBs (Cycles, CPU) as one contact sheet.

  /home/user/tools/bpyenv/bin/python tools/lumo_run_art/render_jungle_review.py OUT.jpg name1 name2 ...

Imports each GLB the way any glTF viewer would (external textures included),
so the sheet also proves that the files are self-contained.
"""
from __future__ import annotations

import math
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/games/run/jungle/models"
SIZE = 420


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.7, 0.85, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.5
    sun_obj = bpy.data.objects.new("sun", sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    ground = bpy.data.meshes.new("g")
    ground.from_pydata([(-200, -200, 0), (200, -200, 0), (200, 200, 0), (-200, 200, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("ground", ground)
    mat = bpy.data.materials.new("gm")
    mat.diffuse_color = (0.3, 0.25, 0.18, 1)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.26, 0.18, 1)
    ground.materials.append(mat)
    scene.collection.objects.link(g)
    return scene, cam


def render_one(scene, cam, name: str, out: Path) -> None:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    corners = []
    for obj in new:
        if obj.type == "MESH":
            corners.extend(obj.matrix_world @ Vector(c) for c in obj.bound_box)
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    centre = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.2)
    direction = Vector((0.75, -1.0, 0.45)).normalized()
    cam.data.lens = 50
    distance = radius / math.tan(math.radians(18)) * 1.05
    cam.location = centre + direction * distance
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = distance * 4
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    for obj in new:
        bpy.data.objects.remove(obj, do_unlink=True)


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sheet_path = Path(args[0])
    names = args[1:]
    scene, cam = setup_scene()
    tiles = []
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            out = Path(tmp) / f"{name}.png"
            render_one(scene, cam, name, out)
            tile = Image.open(out).convert("RGB")
            ImageDraw.Draw(tile).text((6, 6), name, fill=(255, 255, 255))
            tiles.append(tile)
    columns = min(4, len(tiles))
    rows = math.ceil(len(tiles) / columns)
    sheet = Image.new("RGB", (columns * SIZE, rows * SIZE))
    for index, tile in enumerate(tiles):
        sheet.paste(tile, ((index % columns) * SIZE, (index // columns) * SIZE))
    sheet.save(sheet_path, quality=88)
    return 0


if __name__ == "__main__":
    sys.exit(main())
