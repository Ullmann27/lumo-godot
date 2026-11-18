#!/usr/bin/env python3
"""Austauschbare Anbauteile der Aurora-Karts: Radaufsätze und Auspuffblenden.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/karts/build_parts.py [--thumbs]

Erzeugt
  assets/kart/production/parts/kart_parts.glb   ein Knoten je Teil (Wurzel = Montagepunkt)
  assets/kart/production/parts/thumbs/<id>.png  Teilebild, transparent, einheitliche Kamera

Koordinaten wie im Spiel (Godot): Meter, +Y oben. Radaufsätze schauen nach +X (außen am
rechten Rad; das Spiel spiegelt sie für die linke Seite), Auspuffblenden zeigen nach +Z
(hinten) und sitzen auf den Markern Boost_L/Boost_R. Bevel + gewichtete Normalen, getrennte
Materialien PartPaint (wird im Spiel in Kartfarbe getönt), PartMetal, PartDark, PartRubber,
PartHeat. Alles eigene Geometrie, keine fremden Vorlagen.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/production/parts"
# Godot (x, y, z) -> Blender (x, -z, y)
G_TO_B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def g(p):
    return G_TO_B @ Vector(p)


def linear(hex_color):
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


def material(name, color, metal, rough, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = linear(color)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emission:
        p.inputs["Emission Color"].default_value = linear(color)
        p.inputs["Emission Strength"].default_value = emission
    return m


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def obj_from_bmesh(name, bm, mat, parent, bevel=0.0, segments=2):
    data = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(data)
    bm.free()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = True
    o.parent = parent
    if bevel > 0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        mod.harden_normals = False
    wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    return o


def lathe(name, profile, mat, parent, axis="x", segments=48, xform=Matrix.Identity(4)):
    """profile: [(axial, radius)] in Godot units along +X (axis='x') or +Z (axis='z')."""
    bm = bmesh.new()
    rings = []
    for axial, radius in profile:
        ring = []
        for k in range(segments):
            a = math.tau * k / segments
            if axis == "x":
                p = (axial, math.cos(a) * radius, math.sin(a) * radius)
            else:
                p = (math.cos(a) * radius, math.sin(a) * radius, axial)
            ring.append(bm.verts.new(xform @ g(p)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for k in range(segments):
            a, b = rings[r][k], rings[r][(k + 1) % segments]
            c, d = rings[r + 1][(k + 1) % segments], rings[r + 1][k]
            bm.faces.new((a, b, c, d))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        if len(ring) > 2 and profile[0 if flip else -1][1] > 1e-4:
            face = bm.faces.new(list(reversed(ring)) if flip else ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent)


def prism(name, outline, depth, mat, parent, axis="x", offset=0.0, bevel=0.004):
    """Extrude a 2D outline (u, v) along +X (or +Z) from offset to offset+depth."""
    bm = bmesh.new()
    def p3(u, v, w):
        return g((w, u, v)) if axis == "x" else g((u, v, w))
    front = [bm.verts.new(p3(u, v, offset + depth)) for u, v in outline]
    back = [bm.verts.new(p3(u, v, offset)) for u, v in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for k in range(n):
        bm.faces.new((back[k], back[(k + 1) % n], front[(k + 1) % n], front[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(name, bm, mat, parent, bevel)


def root_node(name):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o["mount"] = "wheel_face" if name.startswith("WheelCover") else "boost_outlet"
    return o


def mats():
    return {
        "paint": material("PartPaint", "e8eef6", 0.35, 0.28),
        "metal": material("PartMetal", "d7dee8", 0.95, 0.16),
        "dark": material("PartDark", "1d222c", 0.4, 0.42),
        "rubber": material("PartRubber", "15181e", 0.0, 0.8),
        "heat": material("PartHeat", "7a5cff", 0.9, 0.2),
        "glow": material("PartGlow", "ffb347", 0.0, 0.4, emission=3.0),
    }


# --------------------------------------------------------------------- Radaufsätze
# Rad: Radius 0.35 (Reifen), Felgenstirn bei x = 0.191, Felgenlippe 0.221. Aufsätze sitzen
# davor (x 0.195 .. 0.235) und bleiben im Felgenring (r <= 0.205).

def wheel_turbine(m):
    root = root_node("WheelCover_Turbine")
    lathe("TurbineRing", [(0.196, 0.205), (0.214, 0.205), (0.222, 0.192), (0.214, 0.178), (0.196, 0.178)],
          m["metal"], root, segments=64)
    lathe("TurbineHub", [(0.196, 0.062), (0.226, 0.060), (0.240, 0.040), (0.246, 0.0)], m["paint"], root, segments=40)
    # Zehn gekrümmte, schräg angestellte Schaufeln: von vorn eine Turbine, im Profil zackig.
    for k in range(10):
        bm = bmesh.new()
        verts = []
        steps = 6
        for i in range(steps + 1):
            t = i / steps
            r = 0.064 + (0.178 - 0.064) * t
            a = math.tau * k / 10 + 0.55 * t * t
            width = 0.020 - 0.006 * t
            for side in (-1, 1):
                aa = a + side * width / r * 0.5
                lean = 0.012 * side
                p = (0.205 + lean + 0.012 * (1 - t), math.cos(aa) * r, math.sin(aa) * r)
                verts.append(bm.verts.new(g(p)))
        for i in range(steps):
            a0, b0, a1, b1 = verts[2 * i], verts[2 * i + 1], verts[2 * i + 2], verts[2 * i + 3]
            bm.faces.new((a0, b0, b1, a1))
        res = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        moved = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=moved, vec=g((0.010, 0, 0)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj_from_bmesh("TurbineBlade_%d" % k, bm, m["metal"] if k % 2 == 0 else m["dark"], root, 0.0015)
    return root


def star_outline(points, outer, inner, rotation=math.pi / 2):
    outline = []
    for k in range(points * 2):
        r = outer if k % 2 == 0 else inner
        a = rotation + math.pi * k / points
        outline.append((math.cos(a) * r, math.sin(a) * r))
    return outline


def wheel_star(m):
    root = root_node("WheelCover_Star")
    lathe("StarBackDisc", [(0.195, 0.200), (0.205, 0.200), (0.207, 0.190), (0.205, 0.0)], m["dark"], root, segments=64)
    prism("StarPlate", star_outline(5, 0.185, 0.078), 0.016, m["paint"], root, "x", 0.205, 0.005)
    prism("StarInlay", star_outline(5, 0.120, 0.052), 0.008, m["metal"], root, "x", 0.221, 0.003)
    lathe("StarCap", [(0.228, 0.036), (0.238, 0.034), (0.244, 0.018), (0.246, 0.0)], m["glow"], root, segments=32)
    return root


# --------------------------------------------------------------------- Auspuffblenden
# Montagepunkt Boost_L/R (0.12, 0.467, 1.13): Blende zeigt nach +Z, vorhandene Öffnung 0.15x0.07.

def exhaust_rocket(m):
    root = root_node("ExhaustTip_Rocket")
    # Glockenförmige Düse mit Anlauf-Ring und dunklem Inneren.
    lathe("RocketBell", [(-0.03, 0.030), (0.0, 0.032), (0.03, 0.036), (0.07, 0.050), (0.10, 0.068),
          (0.108, 0.070), (0.108, 0.062), (0.07, 0.044), (0.03, 0.030), (0.0, 0.026)],
          m["metal"], root, "z", 48)
    lathe("RocketHeatRing", [(0.012, 0.0345), (0.040, 0.0395), (0.040, 0.030), (0.012, 0.030)], m["heat"], root, "z", 40)
    lathe("RocketCore", [(0.02, 0.026), (0.09, 0.040), (0.09, 0.0)], m["glow"], root, "z", 32)
    return root


def exhaust_twin(m):
    root = root_node("ExhaustTip_Twin")
    for k, x in enumerate((-0.034, 0.034)):
        offset = Matrix.Translation(g((x, 0.0, 0.0)))
        # Gerade, schräg abgeschnittene Doppelrohre: kantig und eckig statt rund ausgestellt.
        lathe("TwinPipe_%d" % k, [(-0.03, 0.024), (0.085, 0.024), (0.085, 0.019), (-0.03, 0.019)],
              m["metal"], root, "z", 6, offset)
        lathe("TwinInner_%d" % k, [(0.0, 0.019), (0.080, 0.019), (0.080, 0.0)], m["dark"], root, "z", 6, offset)
    prism("TwinBracket", [(-0.068, -0.016), (0.068, -0.016), (0.068, 0.016), (-0.068, 0.016)], 0.03,
          m["paint"], root, "z", -0.01, 0.004)
    return root


BUILDERS = {
    "WheelCover_Turbine": wheel_turbine,
    "WheelCover_Star": wheel_star,
    "ExhaustTip_Rocket": exhaust_rocket,
    "ExhaustTip_Twin": exhaust_twin,
}


def apply_modifiers():
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)


def build_all():
    reset()
    m = mats()
    roots = {}
    for i, (name, fn) in enumerate(BUILDERS.items()):
        root = fn(m)
        roots[name] = root
    apply_modifiers()
    return roots


def export(roots):
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "kart_parts.glb"), export_format="GLB", export_apply=True,
                              export_yup=True, export_extras=True, export_animations=False)
    stats = {}
    for name, root in roots.items():
        tris = 0
        for child in root.children:
            child.data.calc_loop_triangles()
            tris += len(child.data.loop_triangles)
        stats[name] = tris
    print("[KartParts] triangles", stats)


def render_thumbs(roots):
    thumbs = OUT / "thumbs"
    thumbs.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 60
    key.size = 0.6
    key_o = bpy.data.objects.new("Key", key)
    bpy.context.collection.objects.link(key_o)
    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 35
    rim.color = (1.0, 0.75, 0.5)
    rim_o = bpy.data.objects.new("Rim", rim)
    bpy.context.collection.objects.link(rim_o)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam_o = bpy.data.objects.new("Cam", cam)
    bpy.context.collection.objects.link(cam_o)
    scene.camera = cam_o
    shots = [(name, Vector((0, 0, 0)), root) for name, root in roots.items()]
    # Serie: das echte Originalrad bzw. die Originalöffnung des Komet-Karts, gleiche Kamera.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/kart/production/karts/aurora_comet.glb"))
    kart_objects = [o for o in bpy.data.objects if o not in before]
    by_name = {o.name: o for o in kart_objects}
    shots.append(("Serie_wheel_cover", by_name["Wheel_FR"].matrix_world.translation.copy(), None))
    shots.append(("Serie_exhaust", by_name["Boost_R"].matrix_world.translation.copy(), None))
    for name, origin, root in shots:
        for other in roots.values():
            for child in other.children:
                child.hide_render = other is not root
        for o in kart_objects:
            o.hide_render = root is not None
        wheel = "WheelCover" in name or name.endswith("wheel_cover")
        # Einheitliche Kamera je Teileart: Dreiviertel von vorn auf die Aufsatzfläche.
        target = origin + (g((0.22, 0, 0)) if wheel else g((0, 0, 0.04)))
        view = g((1.0, 0.35, -0.45)).normalized() if wheel else g((0.55, 0.35, 1.0)).normalized()
        cam.ortho_scale = 0.50 if wheel else (0.46 if root is None else 0.26)
        cam_o.location = target + view * 2.0
        direction = target - cam_o.location
        cam_o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        key_o.location = target + g((0.8, 1.0, -0.6))
        key_o.rotation_euler = (target - key_o.location).to_track_quat("-Z", "Y").to_euler()
        rim_o.location = target + g((-0.6, 0.6, 0.9))
        rim_o.rotation_euler = (target - rim_o.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(thumbs / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        print("[KartParts] thumb", scene.render.filepath)


if __name__ == "__main__":
    roots = build_all()
    export(roots)
    if "--thumbs" in sys.argv:
        render_thumbs(roots)
