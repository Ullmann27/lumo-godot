#!/usr/bin/env python3
"""Passprobe der Leistungsteile an den drei Aurora-Karosserien (Blender, Cycles).

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/karts/render_parts_fit.py <ausgabeordner>
       [--sets=A,B,C] [--bodies=comet,glider,turbo]

Setzt die Teile aus kart_parts.glb an dieselben Montagepunkte wie das Spiel
(kart_production_vehicle.gd: PART_MOUNTS) und rendert je Karosserie und Satz ein Bild
schräg von hinten oben. Nur zur Prüfung, nichts davon wird eingecheckt.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
G_TO_B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
# Gleiche Werte wie PART_MOUNTS in kart_production_vehicle.gd (Godot-Koordinaten).
MOUNTS = {
    "comet": {"engine": (0, 0.64, 0.70), "wing": (0, 0.66, 1.00), "booster": (0.29, 0.68, 0.86)},
    "glider": {"engine": (0, 0.64, 0.70), "wing": (0, 1.02, 1.02), "booster": (0.27, 0.68, 0.86)},
    "turbo": {"engine": (0, 0.64, 0.70), "wing": (0, 0.95, 1.02), "booster": (0.31, 0.68, 0.86)},
}
SETS = {
    "A": ["Engine_Sprint", "Wing_Big", "Booster_Short", "Tire_Grip", "Damper_Spring"],
    "B": ["Engine_Long", "Wing_Flat", "Booster_Long", "Tire_Knobby", "Damper_Heavy"],
    "C": ["Engine_Sprint", "Wing_Glide", "Booster_Long", "Tire_Drift", "Damper_Sport"],
}


def g(p):
    return G_TO_B @ Vector(p)


def place(source, at, mirror=False, parent_matrix=None):
    copy = source.copy()
    bpy.context.collection.objects.link(copy)
    for child in source.children:
        c = child.copy()
        bpy.context.collection.objects.link(c)
        c.parent = copy
        c.matrix_parent_inverse = Matrix.Identity(4)
    base = Matrix.Translation(g(at))
    if mirror:
        base = base @ Matrix.Scale(-1, 4, Vector((1, 0, 0)))
    copy.matrix_world = (parent_matrix or Matrix.Identity(4)) @ base if parent_matrix else base
    return copy


def main():
    out = Path(sys.argv[-1] if not sys.argv[-1].startswith("--") else ".")
    for arg in sys.argv:
        if arg.startswith("--out="):
            out = Path(arg[6:])
    sets = list(SETS)
    bodies = list(MOUNTS)
    for arg in sys.argv:
        if arg.startswith("--sets="):
            sets = arg[7:].split(",")
        if arg.startswith("--bodies="):
            bodies = arg[9:].split(",")
    out.mkdir(parents=True, exist_ok=True)
    for body in bodies:
        for set_id in sets:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(ROOT / f"assets/kart/production/karts/aurora_{body}.glb"))
            kart = {o.name: o for o in bpy.data.objects}
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/kart/production/parts/kart_parts.glb"))
            parts = {o.name: o for o in bpy.data.objects if o not in before}
            for o in parts.values():
                o.hide_render = True
            for name in SETS[set_id]:
                src = parts[name]
                kind = name.split("_")[0]
                if kind == "Engine":
                    place(src, MOUNTS[body]["engine"])
                elif kind == "Wing":
                    place(src, MOUNTS[body]["wing"])
                elif kind == "Booster":
                    at = MOUNTS[body]["booster"]
                    place(src, at)
                    place(src, (-at[0], at[1], at[2]), True)
                elif kind in ("Tire", "Damper"):
                    for code in ("FL", "FR", "RL", "RR"):
                        node = kart["Wheel_" + code if kind == "Tire" else "Steer_" + code]
                        p = node.matrix_world.translation
                        gp = (p.x, p.z, -p.y)
                        place(src, gp, code.endswith("L"))
            originals = set(parts.values())
            for o in bpy.data.objects:
                if o in originals:
                    continue
                if o.name.startswith(tuple(SETS[set_id])) or (o.parent and o.parent.name.startswith(tuple(SETS[set_id]))):
                    o.hide_render = False
            scene = bpy.context.scene
            scene.render.engine = "CYCLES"
            scene.cycles.samples = 24
            scene.cycles.device = "CPU"
            scene.render.resolution_x = 900
            scene.render.resolution_y = 640
            world = bpy.data.worlds.new("W")
            world.use_nodes = True
            world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.75, 1)
            world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
            scene.world = world
            sun = bpy.data.lights.new("Sun", "SUN")
            sun.energy = 3.0
            so = bpy.data.objects.new("Sun", sun)
            bpy.context.collection.objects.link(so)
            so.rotation_euler = (0.7, 0.2, 0.8)
            cam = bpy.data.cameras.new("Cam")
            cam.lens = 40
            co = bpy.data.objects.new("Cam", cam)
            bpy.context.collection.objects.link(co)
            scene.camera = co
            target = g((0, 0.5, 0.2))
            co.location = g((2.3, 1.9, 3.1))
            co.rotation_euler = (target - co.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(out / f"fit_{body}_{set_id}.png")
            bpy.ops.render.render(write_still=True)
            print("[PartsFit]", scene.render.filepath)


if __name__ == "__main__":
    main()
