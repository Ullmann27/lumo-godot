"""Blender-Hintergrundrender des exportierten LOD0. Aufruf: -P render_landmark.py -- modell.glb bild.png."""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

model, output = map(Path, sys.argv[sys.argv.index("--") + 1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(model.resolve()))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
levels = {obj.name: obj for obj in meshes}
for index in range(3):
    assert f"{model.stem}_lod{index}" in levels, f"LOD {index} fehlt"
hero = levels[f"{model.stem}_lod0"]
for obj in meshes:
    obj.hide_render = obj != hero
corners = [hero.matrix_world @ Vector(point) for point in hero.bound_box]
center = sum(corners, Vector()) / len(corners)
extent = max((corner - center).length for corner in corners)
direction = Vector((1.1, 1.9, 0.85)).normalized()
scene = bpy.context.scene
world = bpy.data.worlds.new("Gartenatelier")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.23, 0.28, 0.25, 1)
bpy.ops.object.camera_add(location=center + direction * extent * 3)
camera = bpy.context.object
camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = extent * 2.05
camera.data.clip_end = extent * 7
scene.camera = camera
for vector, power, color in [
    ((1, 1, 1.8), 130, (1.0, 0.84, 0.63)),
    ((-1, 0.4, 1), 85, (0.65, 0.8, 1.0)),
]:
    position = center + Vector(vector) * extent * 1.6
    bpy.ops.object.light_add(type="AREA", location=position)
    light = bpy.context.object
    light.rotation_euler = (center - position).to_track_quat("-Z", "Y").to_euler()
    light.data.energy = power * extent ** 2
    light.data.shape = "DISK"
    light.data.size = extent * 1.8
    light.data.color = color
scene.render.engine = "CYCLES"
scene.cycles.samples = 12
scene.cycles.use_denoising = False
scene.render.resolution_x, scene.render.resolution_y = 480, 480
scene.render.resolution_percentage = 100
scene.render.filepath = str(output.resolve())
bpy.ops.render.render(write_still=True)
