#!/usr/bin/env python3
"""Pruefbild eines Sternenpost-Modells mit Cycles (CPU), nur fuer die Durchsicht.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_skypost_art/render_review.py <modell> <ausgabe.png>
        [lod] [abstand]
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    name, out = args[:2]
    lod = int(args[2]) if len(args) > 2 else 0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/skypost/models" / (name + ".glb")))
    keep = "_lod%d" % lod
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        if "_lod" in o.name and keep not in o.name:
            o.hide_render = True
        elif lod > 0 and "_lod" not in o.name:
            o.hide_render = True
    visible = [o for o in meshes if not o.hide_render]
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in visible:
        for corner in o.bound_box:
            p = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.55, .7, .9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .8
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 40
    distance = radius * (float(args[3]) if len(args) > 3 else 2.6)
    views = [(-35, 22), (180 + 30, 18)]
    out_path = Path(out)
    for index, (yaw, pitch) in enumerate(views):
        direction = Vector((math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)),
                            -math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)),
                            math.sin(math.radians(pitch))))
        cam.location = centre + direction * distance
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out_path.with_name(out_path.stem + "_%d" % index + out_path.suffix))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
