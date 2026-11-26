#!/usr/bin/env python3
"""Build the additional workshop models and their transparent garage thumbnails.

blender --background --threads 2 --python tools/lumo_kart_art/karts/build_workshop_parts.py -- --thumbs
Use --output-dir=/path to stage the GLB and thumbnails for review.
"""
from __future__ import annotations

import math
import sys
from collections import defaultdict
from pathlib import Path

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_parts as parts


def torque_engine(m):
    root = parts.root_node("Engine_Torque")
    parts.box("TorqueBlock", (0, 0.053, 0.109), (0.266, 0.106, 0.24), m["dark"], root)
    for side in (-1, 1):
        x = side * 0.082
        parts.box("TorqueCover", (x, 0.136, 0.11), (0.105, 0.076, 0.199), m["copper"], root, 0.012)
        for rib in range(5):
            parts.box("TorqueFin", (x, 0.178, 0.045 + rib * 0.028), (0.097, 0.012, 0.011), m["metal"], root, 0.002)
        parts.sweep("TorqueRunner", [(x, 0.103, 0.175), (x, 0.092, 0.255), (side * 0.051, 0.045, 0.276)],
                    0.024, m["metal"], root, 12)
    parts.box("TorqueInlet", (0, 0.167, 0.083), (0.055, 0.067, 0.17), m["dark"], root, 0.009)
    parts.box("TorqueInletLip", (0, 0.184, 0.161), (0.067, 0.035, 0.019), m["yellow"], root, 0.004)
    return root


def tire(name, m, emblem, lanes, blocks):
    root = parts.root_node(name)
    radius = parts.TIRE_R + 0.004
    parts.tire_shell("Casing", radius, 0.178, m["rubber"], root, segments=64)
    for side in (-1, 1):
        parts.sidewall_ring("SideStripe", side * 0.198, 0.293, 0.308, m[emblem], root)
    for x, phase, width, length in lanes:
        for block in range(blocks):
            angle = math.tau * (block + phase) / blocks
            height = radius if abs(x) < 0.13 else radius - 0.005
            # The taper provides the edge highlight without beveling thousands
            # of faces across four wheels on each active kart.
            outline = [(x - width * 0.5, height - 0.008), (x + width * 0.5, height - 0.008),
                       (x + width * 0.38, height + 0.010), (x - width * 0.38, height + 0.010)]
            cleat = parts.prism("Tread", outline, length, m["tread"], root, "z", -length * 0.5, 0.0)
            cleat.matrix_basis = Matrix.Rotation(angle, 4, parts.g((1, 0, 0))) @ cleat.matrix_basis
    return root


def touring_tire(m):
    return tire("Tire_Touring", m, "metal", [(-0.113, 0, 0.055, 0.056), (0.113, 0, 0.055, 0.056)], 22)


def sand_tire(m):
    return tire("Tire_Sand", m, "yellow", [(-0.078, 0, 0.139, 0.035), (0.078, 0.5, 0.139, 0.035)], 18)


def gravel_tire(m):
    return tire("Tire_Gravel", m, "copper",
                [(-0.141, 0, 0.046, 0.046), (0, 0.5, 0.079, 0.068), (0.141, 0, 0.046, 0.046)], 17)


def winter_tire(m):
    return tire("Tire_Winter", m, "blue",
                [(-0.141, 0.35, 0.050, 0.031), (-0.056, 0.1, 0.063, 0.036),
                 (0.056, 0.9, 0.063, 0.036), (0.141, 0.65, 0.050, 0.031)], 22)


def tail_wing(m):
    root = parts.root_node("Wing_Tail")
    parts.wing_plane("TailLip", 0.78, 0.113, 0.032, 0.20, 0.07, m["paint"], root)
    parts.wing_plane("TrailingEdge", 0.74, 0.045, 0.026, 0.231, 0.119, m["copper"], root)
    for side in (-1, 1):
        parts.box("TailSupport", (side * 0.26, 0.104, 0.055), (0.043, 0.19, 0.085), m["dark"], root, 0.009)
        parts.prism("TailFin", [(0.169, -0.015), (0.206, -0.03), (0.247, 0.14), (0.177, 0.14)],
                    0.018, m["copper"], root, "x", side * 0.366, 0.004)
    return root


def jump_wing(m):
    root = parts.root_node("Wing_Jump")
    parts.wing_plane("CenterFoil", 0.48, 0.176, 0.038, 0.295, 0.035, m["paint"], root)
    for side in (-1, 1):
        outline = [(side * 0.21, 0.27), (side * 0.25, 0.31), (side * 0.46, 0.385), (side * 0.468, 0.336)]
        parts.prism("RaisedWingTip", outline, 0.155, m["blue"], root, "z", -0.033, 0.008)
        parts.box("WingBridge", (side * 0.17, 0.143, 0.015), (0.035, 0.27, 0.075), m["dark"], root)
        parts.box("TipInlay", (side * 0.446, 0.378, 0.051), (0.025, 0.009, 0.105), m["copper"], root, 0.003)
    return root


def nozzle(name, m, outer, edge, sides, end, radius):
    root = parts.root_node(name)
    parts.lathe("Outlet", [(-0.025, 0.028), (0.012, radius * 0.82), (end - 0.012, radius),
                          (end, radius), (end, radius - 0.009), (0.005, 0.022)],
                m[outer], root, "z", sides, cap=False)
    parts.lathe("OutletEdge", [(end - 0.006, radius + 0.002), (end, radius + 0.003),
                              (end + 0.004, radius - 0.007), (end - 0.006, radius - 0.008)],
                m[edge], root, "z", sides, cap=False)
    parts.lathe("Recess", [(end - 0.025, 0.0), (end - 0.025, radius - 0.010),
                           (end - 0.012, radius - 0.010)], m["dark"], root, "z", sides)
    return root


def rally_exhaust(m):
    root = nozzle("ExhaustTip_Rally", m, "metal", "copper", 12, 0.102, 0.052)
    for band in (0.024, 0.045, 0.067):
        parts.lathe("CoolingBand", [(band - 0.004, 0.054), (band + 0.004, 0.054),
                                     (band + 0.004, 0.045), (band - 0.004, 0.045)], m["dark"], root, "z", 12, cap=False)
    return root


def slate_exhaust(m):
    root = nozzle("ExhaustTip_Slate", m, "dark", "metal", 6, 0.112, 0.057)
    for x in (-0.038, 0.038):
        parts.box("SideRail", (x, 0.012, 0.059), (0.017, 0.023, 0.084), m["metal"], root, 0.004)
    return root


def copper_exhaust(m):
    root = nozzle("ExhaustTip_Copper", m, "copper", "metal", 32, 0.129, 0.049)
    for band in (0.041, 0.082):
        parts.lathe("BraceRing", [(band - 0.006, 0.048), (band + 0.006, 0.048),
                                  (band + 0.006, 0.042), (band - 0.006, 0.042)], m["dark"], root, "z", 24, cap=False)
    return root


def vent_exhaust(m):
    root = nozzle("ExhaustTip_Vent", m, "blue", "metal", 8, 0.093, 0.056)
    for fin in range(3):
        parts.box("GrilleVane", (0, (fin - 1) * 0.024, 0.094), (0.069, 0.009, 0.018), m["metal"], root, 0.002)
    return root


def slash_exhaust(m):
    root = parts.root_node("ExhaustTip_Slash")
    for elevation, end in ((-0.028, 0.09), (0.028, 0.126)):
        offset = Matrix.Translation(parts.g((0, elevation, 0)))
        parts.lathe("StackedPipe", [(-0.012, 0.022), (end - 0.016, 0.026), (end, 0.025),
                                   (end, 0.018), (end - 0.08, 0.016)], m["metal"], root, "z", 24, offset, cap=False)
        parts.lathe("HeatSleeve", [(end - 0.031, 0.028), (end - 0.014, 0.028), (end - 0.014, 0.025),
                                   (end - 0.031, 0.025)], m["heat"], root, "z", 24, offset, cap=False)
    return root


def batch_materials(root):
    by_material = defaultdict(list)
    for obj in root.children:
        by_material[obj.data.materials[0].name].append(obj)
    for material, objects in by_material.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        master = objects[0]
        bpy.context.view_layer.objects.active = master
        if len(objects) > 1:
            bpy.ops.object.join()
        master.name = f"{root.name}_{material}"


def main():
    for arg in sys.argv:
        if arg.startswith("--output-dir="):
            parts.OUT = Path(arg.split("=", 1)[1]).resolve()
    parts.reset()
    materials = parts.mats()
    materials.update({
        "blue": parts.material("WorkshopEnamel", "538fff", 0.26, 0.32),
        "copper": parts.material("WorkshopCopper", "d69053", 0.65, 0.27),
        "tread": parts.material("WorkshopTread", "353b43", 0.0, 0.77),
    })
    builders = (torque_engine, touring_tire, sand_tire, gravel_tire, winter_tire,
                tail_wing, jump_wing, rally_exhaust, slate_exhaust, copper_exhaust,
                vent_exhaust, slash_exhaust)
    roots = {obj.name: obj for obj in (build(materials) for build in builders)}
    parts.apply_modifiers()
    for obj in roots.values():
        batch_materials(obj)
    parts.OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(parts.OUT / "parts_workshop.glb"), export_format="GLB",
                              export_apply=True, export_yup=True, export_extras=True, export_animations=False)
    if "--thumbs" in sys.argv:
        if not any(arg.startswith("--only=") for arg in sys.argv):
            sys.argv.append("--only=" + ",".join(roots))
        parts.render_thumbs(roots, denoise=False)


if __name__ == "__main__":
    main()
