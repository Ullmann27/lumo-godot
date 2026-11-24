"""Editable, meter-scaled LUMO tunnel production using Blender 4.3+.

Run: blender -b -t 3 --python tools/lumo_kart_art/tracks/build_tunnel_kit.py --
     --repo . --themes zauberwald --render

Geometry is original deterministic authoring, not a downloaded asset. Geometry,
closed collision proxies, baked texture maps and socket contracts are exported.
No game core file is changed. All paths are relative to the repository root.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import random
import struct
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

PI = math.pi
TAU = math.tau
INNER_X = 6.8
SPRING = 2.65
INNER_Z = 4.85
THICKNESS = 0.85
ROAD_WIDTH = 10.8
CLEAR_WIDTH = 11.8
PROFILE_STEPS = 32
DETAIL_LOD = 0
ICO_CACHE = {}
CUBE_CACHE = {}

THEMES = {
    "zauberwald": dict(label="Wurzelgewölbe", family="wood", outer="553725", inner="946449", trim="744a2f", accent="cba75c", light="7ad7c5", secondary="507742", roof="245e49", form="root"),
    "bergwelt": dict(label="Himmelsgewölbe", family="stone", outer="626582", inner="c6c4b0", trim="d8d2b8", accent="d7a646", light="ffd17a", secondary="38694f", roof="adc8d9", form="sky"),
    "holo_city": dict(label="Aurora Passage", family="panel", outer="152b52", inner="455a7b", trim="edf2fa", accent="d6ab58", light="6ddcec", secondary="8c71c1", roof="243959", form="tech"),
    "crystal_canyon": dict(label="Resonanzgrotte", family="stone", outer="65516d", inner="977b94", trim="c0a1b4", accent="bd9251", light="60c5dc", secondary="ae7edd", roof="806778", form="crystal"),
    "jungle_temple": dict(label="Verborgene Wissenshalle", family="stone", outer="806945", inner="cbab70", trim="e5c88e", accent="298e83", light="c8e6b4", secondary="507742", roof="245e49", form="temple"),
    "candy_cloud": dict(label="Wolkenkonfekt", family="sugar", outer="b69bdc", inner="fff0d5", trim="ed94b4", accent="e4b657", light="ffd17e", secondary="efa878", roof="e8d8ef", form="candy"),
    "volcano_night": dict(label="Basaltobservatorium", family="stone", outer="171c2d", inner="4c4b61", trim="242a3d", accent="947462", light="ee9548", secondary="b35235", roof="2c2834", form="basalt"),
    "winter_sprint": dict(label="Frostgalerie", family="ice", outer="6d7a8d", inner="83c4d8", trim="cbdced", accent="344d7e", light="ffc570", secondary="86b6d7", roof="e4edf6", form="ice"),
    "galaxy_ringway": dict(label="Orbitalpassage", family="panel", outer="152b52", inner="66759e", trim="edf2fa", accent="d6ab58", light="b5a2f5", secondary="6ddcec", roof="263452", form="space"),
    "desert_drift": dict(label="Oasengewölbe", family="stone", outer="b88950", inner="d9a65d", trim="edc681", accent="245a9b", light="ffe0a0", secondary="39b8ba", roof="cbab70", form="desert"),
    "learning_lab": dict(label="Funkel Passage", family="panel", outer="397db4", inner="d0dfeb", trim="edf2fa", accent="70a66c", light="6ddcec", secondary="cc8fbb", roof="749bb1", form="lab"),
}


def srgb(hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in rgb)


def mesh_object(name, verts, faces, material, parent=None, uv=None, smooth=False):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material:
        mesh.materials.append(material)
    if parent:
        obj.parent = parent
    if uv:
        layer = mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            for li in polygon.loop_indices:
                layer.data[li].uv = uv[mesh.loops[li].vertex_index]
            if len(polygon.vertices) > 4:
                axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
                a, b = [i for i in range(3) if i != axis]
                for li in polygon.loop_indices:
                    p = mesh.vertices[mesh.loops[li].vertex_index].co
                    layer.data[li].uv = (p[a] / 2, p[b] / 2)
    else:
        # Stable box projection; generated detail surfaces share meter density.
        layer = mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
            a, b = [i for i in range(3) if i != axis]
            for li in polygon.loop_indices:
                p = mesh.vertices[mesh.loops[li].vertex_index].co
                layer.data[li].uv = (p[a] / 2, p[b] / 2)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    return obj


def cube(name, location, scale, material, parent=None, bevel=0.04, rotation=None):
    cache_key = (tuple(scale), bevel, DETAIL_LOD, material.name if material else "")
    if cache_key in CUBE_CACHE:
        obj = bpy.data.objects.new(name, CUBE_CACHE[cache_key].copy())
        bpy.context.collection.objects.link(obj)
        obj.location = location
        if rotation is not None:
            obj.rotation_euler = rotation
        if parent:
            obj.parent = parent
        return obj
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if rotation is not None:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material:
        obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    if bevel:
        mod = obj.modifiers.new("Soft crafted edges", "BEVEL")
        # Keep a real flat strip on thin cladding; a half-thickness bevel
        # collapses faces even when Blender's overlap clamp is enabled.
        mod.width = min(bevel, min(abs(float(v)) for v in scale) * 0.40)
        mod.segments = 1 if DETAIL_LOD else 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    CUBE_CACHE[cache_key] = obj.data.copy()
    return obj


def ico(name, at, scale, material, parent, subdivisions=2):
    if DETAIL_LOD:
        subdivisions = max(1, subdivisions - 1)
    if subdivisions not in ICO_CACHE:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1)
        template = bpy.context.object
        ICO_CACHE[subdivisions] = template.data.copy()
        bpy.data.objects.remove(template, do_unlink=True)
    mesh = ICO_CACHE[subdivisions].copy()
    for v in mesh.vertices:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = at
    obj.data.materials.append(material)
    obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def tube(name, points, radii, material, parent, sides=8):
    if DETAIL_LOD:
        sides = max(6, sides - 2)
    points = [Vector(v) for v in points]
    verts, faces, uv = [], [], []
    distance = 0.0
    for i, p in enumerate(points):
        direction = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        guide = Vector((0, 1, 0)) if abs(direction.y) < 0.90 else Vector((0, 0, 1))
        a = direction.cross(guide).normalized()
        b = direction.cross(a).normalized()
        if i:
            distance += (points[i] - points[i - 1]).length
        radius = radii[i] if isinstance(radii, list) else radii
        for j in range(sides):
            theta = TAU * j / sides
            verts.append(p + (a * math.cos(theta) + b * math.sin(theta)) * radius)
            uv.append((j / sides, distance / 2))
    for i in range(len(points) - 1):
        for j in range(sides):
            k = i * sides + j
            kn = i * sides + (j + 1) % sides
            faces.append((k, kn, kn + sides, k + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(points) - 1) * sides + i for i in range(sides)))
    obj = mesh_object(name, verts, faces, material, parent, uv, True)
    if name == "RaisedGuideCurb":
        obj["lumo_structural_shell"] = True
    return obj


def leaf(name, base, tip, width, material, parent):
    base, tip = Vector(base), Vector(tip)
    d = tip - base
    side = d.cross(Vector((0, 0, 1))).normalized() * width
    mid = base.lerp(tip, 0.50) + Vector((0, 0, width * 0.42))
    verts = [base, mid + side, tip, mid - side, mid + Vector((0, 0, width * 0.22)), mid - Vector((0, 0, 0.04))]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)]
    return mesh_object(name, verts, faces, material, parent, smooth=True)


def crystal(name, at, height, radius, material, parent, lean=0.0, sides=6):
    verts = []
    for z, r in [(0.0, radius * 0.65), (height * 0.18, radius), (height * 0.76, radius * 0.88)]:
        for j in range(sides):
            a = TAU * j / sides
            verts.append((at[0] + math.cos(a) * r + z * lean, at[1] + math.sin(a) * r, at[2] + z))
    verts.append((at[0] + height * lean, at[1], at[2] + height))
    faces = [tuple(reversed(range(sides)))]
    for r in range(2):
        for j in range(sides):
            k, n = r * sides + j, r * sides + (j + 1) % sides
            faces.append((k, n, n + sides, k + sides))
    for j in range(sides):
        faces.append((2 * sides + j, 2 * sides + (j + 1) % sides, 3 * sides))
    return mesh_object(name, verts, faces, material, parent)


def maps(family, target):
    """Original seamless baked albedo/roughness/normal maps, each 1024 square."""
    target.mkdir(parents=True, exist_ok=True)
    key = target / (family + "_albedo.png")
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    if family == "wood":
        warp = x + 0.023 * np.sin(TAU * (y * 2 + x * 3)) + 0.01 * np.sin(TAU * y * 7)
        grain = np.sin(TAU * (warp * 31 + 0.2 * np.sin(TAU * y * 4)))
        fine = np.sin(TAU * (warp * 103 + 0.5 * np.sin(TAU * y * 13)))
        height = 0.48 + 0.15 * grain + 0.07 * fine + 0.06 * np.sin(TAU * (x * 5 + y * 2))
        pigment = 0.76 + 0.14 * grain + 0.07 * fine
        rough = 0.69 + 0.12 * grain
    elif family == "panel":
        edge_x = np.minimum(x % 0.5, 0.5 - x % 0.5)
        edge_y = np.minimum(y % 0.5, 0.5 - y % 0.5)
        seam = np.minimum(edge_x, edge_y) < 0.008
        height = 0.55 - seam * 0.16 + 0.008 * np.sin(TAU * x * 117)
        pigment = 0.94 - seam * 0.21 + 0.012 * np.sin(TAU * x * 117)
        rough = 0.32 + seam * 0.3 + 0.02 * np.sin(TAU * y * 53)
    elif family == "sugar":
        fine = np.sin(TAU * (x * 91 + y * 73)) * np.sin(TAU * (x * 83 - y * 67))
        height = 0.5 + 0.025 * fine
        pigment = 0.97 + 0.025 * fine
        rough = 0.42 + 0.06 * fine
    elif family == "ice":
        veins = np.exp(-np.abs(np.sin(TAU * (x * 7 + 0.23 * np.sin(TAU * y * 5)))) * 24)
        height = 0.5 + 0.015 * veins
        pigment = 0.82 + 0.14 * veins + 0.04 * np.sin(TAU * (x + y) * 3)
        rough = 0.21 + 0.15 * veins
    else:
        low = np.sin(TAU * (x * 3 + y * 2)) * np.sin(TAU * (y * 5 - x))
        med = np.sin(TAU * (x * 17 + y * 13)) * np.cos(TAU * (y * 23 - x * 3))
        fine = np.sin(TAU * (x * 101 + y * 79)) * np.sin(TAU * (y * 91 - x * 67))
        stratum = np.sin(TAU * (y * 9 + 0.035 * np.sin(TAU * x * 4)))
        height = 0.5 + 0.10 * low + 0.06 * med + 0.018 * fine + 0.02 * stratum
        pigment = 0.84 + 0.10 * low + 0.055 * med + 0.015 * fine
        rough = 0.81 + 0.075 * med
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 2.2
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 2.2
    normal = np.dstack((-dx, -dy, np.ones_like(dx)))
    normal /= np.maximum(np.linalg.norm(normal, axis=2)[:, :, None], 1e-5)
    data = {
        "albedo": np.dstack((pigment, pigment, pigment)),
        "roughness": np.dstack((rough, rough, rough)),
        "normal": normal * 0.5 + 0.5,
    }
    result = {}
    for suffix, pixels in data.items():
        path = target / f"{family}_{suffix}.png"
        im = bpy.data.images.new(f"Original_{family}_{suffix}_1024", n, n, alpha=True)
        rgba = np.ones((n, n, 4), dtype=np.float32)
        rgba[:, :, :3] = np.clip(pixels, 0, 1)
        im.pixels.foreach_set(rgba.ravel())
        im.filepath_raw = str(path)
        im.file_format = "PNG"
        im.save()
        if suffix != "albedo":
            im.colorspace_settings.name = "Non-Color"
        result[suffix] = im
    return result


def material(name, color, roughness=0.6, metallic=0, emission=0, textures=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*srgb(color), 1)
    mat.use_nodes = True
    mat.use_backface_culling = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*srgb(color), 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission:
        shader.inputs["Emission Color"].default_value = (*srgb(color), 1)
        shader.inputs["Emission Strength"].default_value = emission
    if textures:
        # glTF supports image × factor through the baseColorFactor socket value.
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = textures["albedo"]
        # Bake the pigment multiplication into an explicit texture for GLB.
        tinted = bpy.data.images.new(name + "_albedo", 1024, 1024, alpha=True)
        pix = np.empty(1024 * 1024 * 4, dtype=np.float32)
        textures["albedo"].pixels.foreach_get(pix)
        pix = pix.reshape((-1, 4))
        pix[:, :3] *= np.array(srgb(color), dtype=np.float32)
        tinted.pixels.foreach_set(pix.ravel())
        tinted.filepath_raw = str(Path(textures["albedo"].filepath).parent / (name + "_albedo.jpg"))
        tinted.file_format = "JPEG"
        tinted.save()
        tex.image = tinted
        links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        tex_r = nodes.new("ShaderNodeTexImage")
        tex_r.image = textures["roughness"]
        links.new(tex_r.outputs["Color"], shader.inputs["Roughness"])
        tex_n = nodes.new("ShaderNodeTexImage")
        tex_n.image = textures["normal"]
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = 0.5
        links.new(tex_n.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], shader.inputs["Normal"])
    return mat


class TrackPath:
    def __init__(self, kind):
        self.kind = kind
        self.length = (36 * PI / 6 if "curve" in kind else (4.0 if "portal" in kind else 12.0))

    def frame(self, s):
        t = s / self.length
        if "curve" in self.kind:
            sign = -1 if "left" in self.kind else 1
            angle = s / 36
            p = Vector((sign * 36 * (1 - math.cos(angle)), 36 * math.sin(angle), 0))
            f = Vector((sign * math.sin(angle), math.cos(angle), 0))
        else:
            sign = -1 if self.kind == "grade_down" else 1
            h = 1.5 * sign if "grade" in self.kind else 0.0
            p = Vector((0, s, h * (3 * t * t - 2 * t * t * t)))
            f = Vector((0, 1, h / self.length * (6 * t - 6 * t * t))).normalized()
        r = f.cross(Vector((0, 0, 1))).normalized()
        up = r.cross(f).normalized()
        return p, r, f, up

    def pos(self, s, x=0, z=0):
        p, r, f, up = self.frame(s)
        return p + r * x + up * z

    def matrix(self, s):
        p, r, f, up = self.frame(s)
        m = Matrix((r, f, up)).transposed().to_4x4()
        m.translation = p
        return m


def section(steps=PROFILE_STEPS, outer=False):
    delta = THICKNESS if outer else 0
    rx, rz = INNER_X + delta, INNER_Z + delta
    points = [(rx, -0.32 - delta), (rx, 0.55), (rx, 1.35), (rx, 2.1)]
    points.extend((rx * math.cos(i * PI / steps), SPRING + rz * math.sin(i * PI / steps)) for i in range(steps + 1))
    points.extend([(-rx, 2.1), (-rx, 1.35), (-rx, 0.55), (-rx, -0.32 - delta)])
    return points


def shell(path, name, mats, parent, steps=PROFILE_STEPS, longitudinal=12, niches=False):
    profiles = [section(steps, False), section(steps, True)]
    n = len(profiles[0])
    verts, uv, faces = [], [], []
    for layer, profile in enumerate(profiles):
        for row in range(longitudinal + 1):
            s = path.length * row / longitudinal
            circum = 0
            for j, (x, z) in enumerate(profile):
                if j:
                    circum += math.dist(profile[j - 1], profile[j])
                displacement = 0.0
                if niches and layer == 0 and abs(x) >= INNER_X - 0.01:
                    displacement = 0.30 * math.sin(3 * PI * s / path.length) ** 4 * max(0.0, 1.0 - abs(z - 1.45) / 1.25)
                verts.append(path.pos(s, x + math.copysign(displacement, x), z))
                uv.append((circum / 2, s / 2))
    layer_stride = (longitudinal + 1) * n
    material_indices = []
    for layer in range(2):
        for row in range(longitudinal):
            for j in range(n):
                a = layer * layer_stride + row * n + j
                b = layer * layer_stride + row * n + (j + 1) % n
                quad = (a, a + n, b + n, b)
                faces.append(tuple(reversed(quad)) if layer == 0 else quad)
                material_indices.append(layer)
    for row in (0, longitudinal):
        for j in range(n):
            a, b = row * n + j, row * n + (j + 1) % n
            quad = (a, b, b + layer_stride, a + layer_stride)
            faces.append(tuple(reversed(quad)) if row == 0 else quad)
            material_indices.append(2)
    obj = mesh_object(name, verts, faces, mats[0], parent, uv, True)
    obj["lumo_structural_shell"] = True
    obj.data.materials.append(mats[1])
    obj.data.materials.append(mats[2])
    for poly, idx in zip(obj.data.polygons, material_indices):
        poly.material_index = idx
    # A closed manifold solid: recalculate normals consistently, including lumen.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def rib(path, s, name, material, parent, radius=0.20, steps=32):
    if DETAIL_LOD:
        steps = 24
    pts = [path.pos(s, INNER_X + 0.04, 0.1)]
    pts += [path.pos(s, (INNER_X + 0.04) * math.cos(PI * i / steps), SPRING + (INNER_Z - 0.12) * math.sin(PI * i / steps)) for i in range(steps + 1)]
    pts += [path.pos(s, -(INNER_X + 0.04), 0.1)]
    return tube(name, pts, radius, material, parent, 10)


def stone_ring(path, s, mats, parent, prefix, sides=16, depth=0.50):
    if DETAIL_LOD:
        sides = 12
    for i in range(sides):
        a = PI * i / sides + 0.014
        b = PI * (i + 1) / sides - 0.014
        verts = []
        for y in (s - depth / 2, s + depth / 2):
            for radius in (0.0, 0.48):
                for angle in (a, b):
                    verts.append(path.pos(y, (INNER_X - 0.12 + radius) * math.cos(angle), SPRING + (INNER_Z - 0.1 + radius) * math.sin(angle)))
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        obj = mesh_object(f"{prefix}_Voussoir_{i:02}", verts, faces, mats[i % len(mats)], parent)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.028, segments=1 if DETAIL_LOD else 2,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
        bm.to_mesh(obj.data)
        bm.free()
    for side in (-1, 1):
        for z in (0.5, 1.48, 2.35):
            p = path.pos(s, side * 6.83, z)
            yaw = -math.atan2(path.frame(s)[2].x, path.frame(s)[2].y)
            cube(prefix + "_Pier", p, (0.72, depth + 0.12, 0.93), mats[0], parent, 0.05, (0, 0, yaw))


def mushroom(path, s, side, scale, mats, parent, i):
    p = path.pos(s, side * 6.53, 0.16)
    stem = [p, p + Vector((side * 0.06, 0, scale * 0.50)), p + Vector((side * 0.15, 0, scale))]
    tube(f"MyceliumStem_{i}", stem, [scale * 0.11, scale * 0.08, scale * 0.075], mats["trim"], parent)
    ico(f"MyceliumCap_{i}", stem[-1], (scale * 0.45, scale * 0.40, scale * 0.18), mats["secondary"], parent, 2)
    ico(f"LuminousGills_{i}", stem[-1] - Vector((0, 0, scale * 0.055)), (scale * 0.40, scale * 0.35, scale * 0.045), mats["light"], parent, 2)
    for j in range(4):
        a = j * TAU / 4 + 0.3
        ico(f"CapSpeck_{i}_{j}", stem[-1] + Vector((math.cos(a) * scale * 0.25, math.sin(a) * scale * 0.23, scale * 0.135)), (scale * 0.055,) * 3, mats["accent"], parent, 1)


def motif(path, s, side, theme, mats, parent, index):
    form = theme["form"]
    origin = path.pos(s, side * 6.20, 0.10)
    if form == "root":
        mushroom(path, s, side, 0.95 + (index % 3) * 0.16, mats, parent, index)
        for j in range(3):
            base = path.pos(s + 0.50, side * 6.58, 0.10)
            tip = base + Vector((-side * (0.25 + j * 0.1), 0.6 - j * 0.5, 0.5 + j * 0.21))
            leaf(f"WoodFern_{index}_{j}", base, tip, 0.19, mats["roof"], parent)
    elif form in ("crystal", "ice", "sky"):
        for j in range(3):
            p = origin + Vector((side * 0.08 * j, (j - 1) * 0.30, 0))
            mineral_mat = mats["trim"] if form == "sky" else mats["secondary"]
            crystal(f"MineralCluster_{index}_{j}", p, 0.9 + j * 0.42, 0.16 + 0.035 * j, mats["light"] if j == 1 else mineral_mat, parent, side * 0.09)
    elif form in ("temple", "desert"):
        p = path.pos(s, side * 6.35, 1.55)
        cube(f"CarvedPlinth_{index}", p, (0.44, 0.72, 0.72), mats["trim"], parent, 0.07)
        crystal(f"InsetBeacon_{index}", p + Vector((-side * 0.22, 0, -0.20)), 0.51, 0.16, mats["accent"], parent, 0, 4)
        if form == "temple":
            pts = [path.pos(s + 0.25 * math.sin(i), side * (6.42 + 0.1 * math.cos(i)), 0.1 + i * 0.60) for i in range(6)]
            tube(f"TempleVine_{index}", pts, 0.035, mats["secondary"], parent)
            for j in (2, 4):
                leaf(f"TempleLeaf_{index}_{j}", pts[j], pts[j] + Vector((-side * 0.30, 0.32, 0.15)), 0.22, mats["roof"], parent)
    elif form == "candy":
        tube(f"SugarStem_{index}", [origin, origin + Vector((0, 0, 1.4))], 0.09, mats["trim"], parent)
        ico(f"SugarRosette_{index}", origin + Vector((0, 0, 1.45)), (0.30, 0.24, 0.35), mats["secondary"], parent, 2)
        for j in range(5):
            a = TAU * j / 5
            ico(f"RosettePetal_{index}_{j}", origin + Vector((0, math.cos(a) * 0.25, 1.45 + math.sin(a) * 0.25)), (0.12, 0.15, 0.15), mats["trim"], parent, 1)
    elif form == "basalt":
        for j in range(3):
            h = 1.1 + 0.4 * j
            crystal(f"BasaltColumn_{index}_{j}", origin + Vector((side * 0.15, (j - 1) * 0.33, 0)), h, 0.21, mats["trim"], parent, 0, 6)
        p = path.pos(s - 0.52, side * 6.35, 0.45)
        cube(f"ProtectedEmber_{index}", p, (0.15, 0.58, 0.72), mats["light"], parent, 0.04)
        for j in range(4):
            cube(f"EmberGuard_{index}_{j}", p + Vector((-side * 0.12, -0.24 + j * 0.16, 0)), (0.1, 0.045, 0.78), mats["accent"], parent, 0.01)
    else:
        yaw = -math.atan2(path.frame(s)[2].x, path.frame(s)[2].y)
        p = path.pos(s, side * 6.35, 1.70)
        cube(f"MachinedLightHousing_{index}", p, (0.24, 0.92, 1.30), mats["trim"], parent, 0.08, (0, 0, yaw))
        cube(f"ProtectedLightLens_{index}", p + path.frame(s)[1] * (-side * 0.135), (0.075, 0.58, 0.85), mats["light"], parent, 0.035, (0, 0, yaw))
        if form == "lab":
            for j in range(3):
                ico(f"MoleculeAtom_{index}_{j}", path.pos(s + (j - 1) * 0.28, side * 6.20, 2.65 + (j % 2) * 0.30), (0.16,) * 3, mats["secondary"], parent, 1)
        if form == "space":
            pts = [path.pos(s + 0.50 * math.sin(TAU * j / 24), side * 6.0, 2.9 + 0.50 * math.cos(TAU * j / 24)) for j in range(25)]
            tube(f"OrbitalNavigationRing_{index}", pts, 0.038, mats["accent"], parent, 6)


def portal_details(path, kind, theme, mats, parent):
    form = theme["form"]
    s = 0.25 if kind == "portal_entry" else path.length - 0.25
    if form == "root":
        for side in (-1, 1):
            for i in range(4):
                station = 0.35 + i * 0.85 if kind == "portal_entry" else path.length - 0.35 - i * 0.85
                pts = [
                    path.pos(station, side * 7.65, 4.0 - i * 0.2),
                    path.pos(station + 0.12, side * 7.85, 2.9),
                    path.pos(station - 0.12, side * 8.25, 1.4),
                    path.pos(station + (i % 2 - 0.5), side * 9.15, 0.48),
                    path.pos(station + (i % 2 - 0.5) * 1.6, side * 10.15, 0.08),
                ]
                tube(f"PortalButtressRoot_{side}_{i}", pts, [0.48, 0.46, 0.38, 0.20, 0.06], mats["outer"], parent, 10)
                fork = [pts[2], pts[3] + Vector((0, 0.9, 0.04)), pts[4] + Vector((-side * 0.3, 1.3, 0))]
                tube(f"RootFork_{side}_{i}", fork, [0.25, 0.14, 0.035], mats["trim"], parent, 8)
            for i in range(7):
                base = path.pos(s + 0.3 * (i % 3), side * (7.3 + (i % 2) * 0.25), 3.35 + (i % 3) * 0.42)
                direction = Vector((side * (0.75 + 0.08 * i), 0.7 * math.sin(i * 1.6), 0.45 + 0.12 * math.cos(i)))
                leaf(f"PortalFernFrond_{side}_{i}", base, base + direction, 0.25, mats["roof"] if i % 2 else mats["secondary"], parent)
                tube(f"FrondVein_{side}_{i}", [base, base + direction * 0.5 + Vector((0, 0, 0.10)), base + direction], 0.012, mats["secondary"], parent, 6)
            lamp = path.pos(s + 0.45, side * 6.30, 4.68)
            tube(f"LanternHook_{side}", [lamp + Vector((side * 0.25, 0, 0.65)), lamp + Vector((0, 0, 0.38)), lamp + Vector((0, 0, 0.23))], 0.055, mats["accent"], parent, 8)
            ico(f"SeedLanternGlass_{side}", lamp, (0.17, 0.17, 0.28), mats["light"], parent, 2)
            ico(f"SeedLanternCap_{side}", lamp + Vector((0, 0, 0.26)), (0.23, 0.23, 0.08), mats["accent"], parent, 2)
        for strand in range(3):
            points = []
            for j in range(25):
                a = PI * j / 24
                points.append(path.pos(s + strand * 0.32 + 0.12 * math.sin(j * 0.8 + strand), (7.78 + 0.06 * math.sin(j * 0.8 + strand)) * math.cos(a), SPRING + (5.82 + 0.04 * math.cos(j * 0.7 + strand)) * math.sin(a)))
            tube(f"WovenExteriorArch_{strand}", points, [0.18 + 0.09 * math.sin(j * PI / 24) for j in range(25)], mats["trim"] if strand % 2 else mats["outer"], parent, 9)
        for i in range(11):
            a = PI * (i + 0.5) / 11
            base = path.pos(s, 7.55 * math.cos(a), SPRING + 5.65 * math.sin(a))
            tip = base + Vector((math.cos(a) * 0.60, -0.40 + 0.10 * (i % 3), 0.4))
            leaf(f"CrownFern_{i}", base, tip, 0.29, mats["roof"] if i % 2 else mats["secondary"], parent)
    elif form in ("tech", "space", "lab"):
        stone_ring(path, s, [mats["trim"], mats["outer"]], parent, "MachinedPortalBand", 20, 0.92)
        for side in (-1, 1):
            for tier in range(3):
                p = path.pos(s, side * (7.55 + 0.15 * tier), 0.65 + tier * 1.3)
                cube(f"PortalServicePylon_{side}_{tier}", p, (1.15, 2.4, 1.2), mats["outer"], parent, 0.12)
                cube(f"PylonPearlCladding_{side}_{tier}", p + Vector((-side * 0.12, -1.17, 0)), (0.98, 0.10, 0.85), mats["trim"], parent, 0.06)
                cube(f"PylonLightRail_{side}_{tier}", p + Vector((0, -1.24, 0)), (0.60, 0.035, 0.06), mats["light"], parent, 0.01)
        rib(path, s + 0.54, "PortalNavigationLightArc", mats["light"], parent, 0.045)
        if form == "space":
            for side in (-1, 1):
                pts = [path.pos(s, side * 8.0 + math.cos(j * TAU / 32) * 0.58, 5.4 + math.sin(j * TAU / 32) * 0.58) for j in range(33)]
                tube(f"PortalOrbit_{side}", pts, 0.08, mats["accent"], parent, 8)
        if form == "lab":
            for side in (-1, 1):
                center = path.pos(s, side * 8.0, 5.1)
                ico(f"MoleculePortalHub_{side}", center, (0.17,) * 3, mats["accent"], parent, 2)
                points = [center + Vector((math.cos(a) * 0.46, 0, math.sin(a) * 0.46)) for a in (0, TAU / 3, TAU * 2 / 3)]
                for i, p in enumerate(points):
                    tube(f"MoleculeBond_{side}_{i}", [center.lerp(p, 0.18), p], 0.05, mats["accent"], parent, 8)
                    ico(f"MoleculePortalAtom_{side}_{i}", p, (0.22,) * 3, mats["secondary"], parent, 2)
    elif form == "basalt":
        for side in (-1, 1):
            for i in range(5):
                p = path.pos(s + (i % 2) * 0.9, side * (7.45 + i * 0.35), 0)
                crystal(f"PortalBasaltColumn_{side}_{i}", p, 2.0 + ((i * 3) % 5) * 0.62, 0.48, mats["outer"] if i % 2 else mats["trim"], parent, 0, 6)
            p = path.pos(s + 0.35, side * 7.0, 4.4)
            crystal(f"ProtectedPortalEmber_{side}", p, 0.55, 0.18, mats["light"], parent, 0, 6)
    elif form in ("temple", "desert", "sky", "crystal", "ice"):
        for side in (-1, 1):
            for i in range(4):
                p = path.pos(min(path.length - 0.2, max(0.2, s + (i - 1.5) * 0.7)), side * (7.55 + (i % 2) * 0.60), 1.0 + i * 0.13)
                if form in ("temple", "desert", "sky"):
                    cube(f"PortalMasonryPier_{side}_{i}", p, (1.45, 1.35, 1.70), mats["outer"] if i % 2 else mats["trim"], parent, 0.12)
                else:
                    ico(f"PortalNaturalRock_{side}_{i}", p, (1.3, 1.2, 1.5), mats["outer"], parent, 1)
                if form == "temple":
                    for k in range(3):
                        base = p + Vector((0, 0, 0.9))
                        leaf(f"RuinCrownLeaf_{side}_{i}_{k}", base, base + Vector((side * 0.7, (k - 1) * 0.5, 0.4)), 0.23, mats["roof"], parent)
                if form in ("crystal", "ice"):
                    crystal(f"PortalMineralSpire_{side}_{i}", p + Vector((0, 0, 1.1)), 0.9 + i * 0.32, 0.30, mats["secondary"] if i % 2 else mats["light"], parent, side * 0.15)
        if form == "desert":
            stone_ring(path, s, [mats["trim"], mats["accent"]], parent, "OasisMosaicBand", 24, 0.85)
        if form == "sky":
            for i in range(5):
                a = PI * (i + 0.5) / 5
                p = path.pos(s, 7.55 * math.cos(a), SPRING + 5.6 * math.sin(a))
                crystal(f"SkyCrownMineral_{i}", p, 0.65, 0.25, mats["accent"], parent, 0, 4)
    else:
        for side in (-1, 1):
            for i in range(3):
                p = path.pos(min(path.length - 0.2, max(0.2, s + i * 0.8)), side * (7.6 + 0.12 * i), 1.15)
                ico(f"MarshmallowButtress_{side}_{i}", p, (1.05, 1.20, 1.3), mats["outer"], parent, 2)
                ico(f"IcingCap_{side}_{i}", p + Vector((0, 0, 1.06)), (1.08, 1.22, 0.33), mats["trim"], parent, 2)
        for i in range(9):
            a = PI * (i + 0.5) / 9
            p = path.pos(s, 7.5 * math.cos(a), SPRING + 5.45 * math.sin(a))
            ico(f"SugarCrownPetal_{i}", p, (0.65, 0.80, 0.35), mats["secondary"] if i % 2 else mats["trim"], parent, 2)


def make_module(kind, theme_id, theme, mats, collection):
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[collection.name]
    root = bpy.data.objects.new(f"{theme_id}_{kind}", None)
    collection.objects.link(root)
    root["lumo_asset_version"] = 1
    root["theme"] = theme_id
    root["module_kind"] = kind
    root["travel_axis"] = "Godot -Z; Blender +Y"
    root["road_width_m"] = ROAD_WIDTH
    root["reserved_clear_width_m"] = CLEAR_WIDTH
    path = TrackPath(kind)
    form = theme["form"]
    shell(path, "ContinuousVault", [mats["inner"], mats["outer"], mats["trim"]], root, longitudinal=max(6, math.ceil(path.length / 1.2)), niches=form == "root")
    count = max(2, round(path.length / 4) + 1)
    stations = [0.36 + i * (path.length - 0.72) / (count - 1) for i in range(count)]
    for i, s in enumerate(stations):
        if form in ("temple", "desert", "sky", "crystal"):
            stone_ring(path, s, [mats["trim"], mats["outer"]], root, f"Arch_{i}")
        else:
            rib(path, s, f"StructuralRib_{i}", mats["trim"], root, 0.23 if form == "root" else 0.16)
        if form in ("tech", "space", "lab"):
            rib(path, s + 0.20, f"RecessedLightArc_{i}", mats["light"], root, 0.035)
        if form == "root":
            # Secondary roots visibly weave diagonally into the main trunk.
            for side in (-1, 1):
                pts = [path.pos(s + 0.22 * math.sin(j * 0.8), side * (6.56 - 0.60 * (j / 6) ** 1.5), 0.13 + j * 0.83) for j in range(7)]
                tube(f"LivingRoot_{i}_{side}", pts, [0.19 - j * 0.018 for j in range(7)], mats["trim"], root, 7)
                branch_s = min(path.length - 0.15, max(0.15, s + (0.95 if i % 2 else -0.95)))
                fork = [pts[3], path.pos((s + branch_s) * 0.5, side * 6.34, 3.6), path.pos(branch_s, side * 6.46, 4.55)]
                tube(f"RootSideBranch_{i}_{side}", fork, [0.12, 0.075, 0.025], mats["outer"], root, 7)
        if form == "ice":
            for j in (-2, 0, 2):
                # Icicles stay above the central 5.5 m camera clearance.
                tip = path.pos(s, j, 6.55)
                crystal(f"CeilingIce_{i}_{j}", tip, 0.72, 0.18, mats["secondary"], root)
        for side in (-1, 1):
            motif(path, min(path.length - 1, max(1, s + 0.4)), side, theme, mats, root, i * 2 + (side + 1) // 2)
    # Continuous curbs and physically shaped directional chevrons.
    for side in (-1, 1):
        points = [path.pos(path.length * i / 24, side * 6.13, 0.14) for i in range(25)]
        tube("RaisedGuideCurb", points, 0.09, mats["trim"], root, 6)
        for i in range(max(1, int(path.length / 4))):
            s = 2 + i * 4
            for pair in (0, 1):
                v = [path.pos(s + pair * 0.38 - 0.15, side * 5.99, 0.22), path.pos(s + pair * 0.38 + 0.12, side * 6.08, 0.22), path.pos(s + pair * 0.38 - 0.15, side * 6.17, 0.22)]
                tube(f"RaisedDirectionChevron_{side}_{i}_{pair}", v, 0.035, mats["light"], root, 6)
    if "portal" in kind:
        portal_details(path, kind, theme, mats, root)
    # Explicit socket orientations (outgoing +Y Blender = -Z Godot).
    for label, s in (("SocketIn", 0), ("SocketOut", path.length)):
        marker = bpy.data.objects.new(label, None)
        collection.objects.link(marker)
        marker.empty_display_type = "ARROWS"
        marker.empty_display_size = 0.75
        marker.parent = root
        marker.matrix_local = path.matrix(s)
        marker["clear_width_m"] = CLEAR_WIDTH
        marker["clear_height_m"] = 4.5
        marker["frame_forward"] = "-Z after glTF conversion"
        marker["lumo_socket"] = "in" if label == "SocketIn" else "out"
    for i in range(max(1, math.ceil(path.length / 6.0))):
        station = (i + 0.5) * path.length / max(1, math.ceil(path.length / 6.0))
        marker = bpy.data.objects.new(f"LightSocket_{i:02}", None)
        collection.objects.link(marker)
        marker.parent = root
        marker.location = path.pos(station, 0, 6.2)
        marker["lumo_light_socket"] = i
        marker["light_color_srgb"] = theme["light"]
        marker["suggested_radius_m"] = 8.0
        marker["casts_shadows"] = False
    return root, path


def descendants(root):
    return [root] + list(root.children_recursive)


def select(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def join_meshes(objects, name):
    for obj in objects:
        if obj.type == "MESH" and obj.data.uv_layers.active:
            obj.data.uv_layers.active.name = "UVMap"
    if len(objects) > 1:
        select(objects)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = name
    return objects[0] if objects else None


def combine_by_material(root):
    """Reduce draw submissions without destroying source mesh editability."""
    objects = [o for o in descendants(root) if o.type == "MESH"]
    join_meshes(objects, "TunnelGeometry")
    return [o for o in descendants(root) if o.type == "MESH"][0]


def export_glb(path, objects):
    for obj in objects:
        if obj.type == "MESH":
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            bm.to_mesh(obj.data)
            bm.free()
            obj.data.validate(verbose=False)
    select(objects)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True, export_animations=False, export_extras=True, export_yup=True, export_texcoords=True, export_normals=True, export_tangents=True)
    # Blender object names are globally unique, whereas each glTF is independent.
    # Stable semantic socket names therefore get normalized in its JSON chunk.
    raw = path.read_bytes()
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    payload = json.loads(raw[20:20 + json_length])
    for node in payload.get("nodes", []):
        role = node.get("extras", {}).get("lumo_socket")
        if role in ("in", "out"):
            node["name"] = "SocketIn" if role == "in" else "SocketOut"
    encoded = json.dumps(payload, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    rest = raw[20 + json_length:]
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 20 + len(encoded) + len(rest)) + struct.pack("<II", len(encoded), json_type) + encoded + rest)


def audit(root):
    rows, points, materials = [], [], set()
    for obj in descendants(root):
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        points.extend(obj.matrix_world @ v.co for v in mesh.vertices)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        nonmanifold = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        materials.update(m.name for m in mesh.materials if m)
        rows.append(dict(name=obj.name, triangles=len(mesh.loop_triangles), vertices=len(mesh.vertices), nonmanifold_edges=nonmanifold, degenerate_triangles=sum(1 for t in mesh.loop_triangles if t.area < 1e-10)))
    minimum = [min(v[i] for v in points) for i in range(3)]
    maximum = [max(v[i] for v in points) for i in range(3)]
    return dict(meshes=rows, triangles=sum(r["triangles"] for r in rows), materials=sorted(materials), material_count=len(materials), bounds_blender_m=dict(min=minimum, max=maximum), nonmanifold_edges=sum(r["nonmanifold_edges"] for r in rows), degenerate_triangles=sum(r["degenerate_triangles"] for r in rows))


def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def instance_module(original, target_collection, transform, label):
    mapping = {}
    for old in descendants(original):
        new = old.copy()
        if old.type == "MESH":
            new.data = old.data.copy()
        new.name = label + "_" + old.name
        target_collection.objects.link(new)
        mapping[old] = new
    for old, new in mapping.items():
        if old.parent in mapping:
            new.parent = mapping[old.parent]
    mapping[original].matrix_world = transform
    return mapping[original]


def area(name, position, target, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def camera(position, target, lens=30):
    data = bpy.data.cameras.new("ReviewCamera")
    obj = bpy.data.objects.new("ReviewCamera", data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    data.lens = lens
    data.sensor_fit = "VERTICAL"
    data.sensor_height = 24
    data.clip_start = 0.08
    data.clip_end = 400
    bpy.context.scene.camera = obj
    return obj


def road_piece(path, parent, mat):
    verts, faces, uv = [], [], []
    n = max(8, math.ceil(path.length))
    for i in range(n + 1):
        s = path.length * i / n
        for x in (-5.4, 5.4):
            verts.append(path.pos(s, x, 0))
            uv.append((x / 2, s / 2))
    for i in range(n):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
    return mesh_object("PreviewRoad_NotPartOfExport", verts, faces, mat, parent, uv)


def prepare_review(roots, paths, theme_id, mats, evidence, render=False, animation=False):
    scene = bpy.context.scene
    review = collection("REVIEW_Assembled_Track")
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[review.name]
    road_mat = material("Preview_Asphalt", "36434c", 0.9)
    transform = Matrix.Identity(4)
    sections = []
    for n, kind in enumerate(("portal_entry", "straight_12m", "curve_right_30", "straight_12m", "portal_exit")):
        obj = instance_module(roots[kind], review, transform, f"Demo_{n}")
        road_piece(paths[kind], obj, road_mat)
        sections.append((paths[kind], transform.copy()))
        transform = transform @ paths[kind].matrix(paths[kind].length)
    for c in bpy.data.collections:
        if c.name.startswith("SOURCE_") or c.name.startswith("COLLISION_"):
            c.hide_render = True
            c.hide_viewport = True
    world = bpy.data.worlds.new("NeutralReviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.08, 0.12, 0.16, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.50
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 5
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 2
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 3
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    area("ExteriorKey", (-10, -11, 17), (0, 3, 3), 7000, 11, (1.0, 0.84, 0.64))
    area("ExteriorFill", (11, -6, 8), (0, 5, 4), 3500, 9, (0.55, 0.76, 1.0))
    for i, (path, mat) in enumerate(sections):
        for j in range(max(1, int(path.length / 5))):
            s = (j + 0.5) * path.length / max(1, int(path.length / 5))
            p = mat @ path.pos(s, 0, 6.3)
            target = mat @ path.pos(s + 0.1, 0, 0)
            area(f"ReviewInteriorSoftbox_{i}_{j}", p, target, 1100, 3.8, (0.77, 1.0, 0.90))
    cube("ReviewGround", (4, 20, -1.14), (65, 90, 0.16), material("ReviewGroundMaterial", "273e3b", 0.95), None, 0)
    cam = camera((17, -20, 11), (0, 5, 3.5), 29)
    evidence.mkdir(parents=True, exist_ok=True)
    if render:
        views = {
            "01_portal_three_quarter": ((17, -20, 11), (0, 5, 3.5), 29),
            "02_race_camera_interior": ((0, 7, 2.52), (0, 18, 1.25), 23),
            "03_bend_interior": ((0, 13, 2.52), (2.0, 25, 1.25), 23),
            "04_exit_backside": ((34, 66, 12), (16, 44, 3), 31),
        }
        for label, (pos, target, lens) in views.items():
            cam.location = pos
            cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = lens
            scene.render.filepath = str(evidence / (theme_id + "_" + label + ".png"))
            bpy.ops.render.render(write_still=True)
    if animation:
        scene.render.resolution_x = 960
        scene.render.resolution_y = 540
        scene.cycles.samples = 6
        scene.render.fps = 24
        scene.frame_start, scene.frame_end = 1, 96
        scene.render.image_settings.file_format = "PNG"
        frames = evidence / "flythrough_frames"
        frames.mkdir(exist_ok=True)
        total = sum(p.length for p, m in sections)
        for frame in range(1, 97):
            distance = 2.5 + (total - 6) * (frame - 1) / 95
            remain = distance
            chosen = sections[-1]
            for path, mat in sections:
                if remain <= path.length:
                    chosen = path, mat
                    break
                remain -= path.length
            path, mat = chosen
            pos = mat @ path.pos(remain, 0, 2.52)
            _, _, f, _ = path.frame(remain)
            f = mat.to_3x3() @ f
            target = pos + f * 10 - Vector((0, 0, 1.20))
            cam.location = pos
            cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = 23
            scene.frame_set(frame)
            scene.render.filepath = str(frames / f"{frame:04}.png")
            bpy.ops.render.render(write_still=True)
    return review


def main():
    global DETAIL_LOD
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--themes", nargs="+", default=["zauberwald"])
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--animation", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo = args.repo.resolve()
    for theme_id in args.themes:
        theme = THEMES[theme_id]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        ICO_CACHE.clear()
        CUBE_CACHE.clear()
        assets = repo / "assets/kart/production/tracks" / theme_id
        source = repo / "art/lumo_kart/blender/tracks"
        evidence = repo / "evidence/lumo_kart_art/tracks" / theme_id
        for p in (assets, source, evidence):
            p.mkdir(parents=True, exist_ok=True)
        textures = maps(theme["family"], assets / "textures")
        mats = {}
        for key in ("outer", "inner", "trim", "accent", "light", "secondary", "roof"):
            textured = textures if key in ("outer", "inner") else None
            metallic = 0.72 if key == "accent" and theme["form"] in ("root", "tech", "space", "lab", "sky", "crystal") else 0
            roughness = 0.30 if metallic else (0.77 if theme["family"] in ("wood", "stone") else 0.35)
            if key == "light":
                roughness = 0.18
            mats[key] = material(f"{theme_id}_{key}", theme[key], roughness, metallic, 1.8 if key == "light" else 0, textured)
        roots, paths, reports = {}, {}, {}
        for kind in ("portal_entry", "portal_exit", "straight_12m", "curve_left_30", "curve_right_30", "grade_down", "grade_up"):
            coll = collection("SOURCE_" + kind)
            root, path = make_module(kind, theme_id, theme, mats, coll)
            # Keep editable original components in the .blend; export joined clone.
            export_collection = collection("EXPORT_" + kind)
            clone = instance_module(root, export_collection, Matrix.Identity(4), "Export")
            combined = combine_by_material(clone)
            report = audit(clone)
            assert report["nonmanifold_edges"] == 0, (theme_id, kind, report)
            assert report["degenerate_triangles"] == 0, (theme_id, kind, report)
            file = assets / (kind + ".glb")
            export_glb(file, descendants(clone))
            # Re-author closed low-detail primitives instead of collapsing tiny
            # disconnected solids into open caps. Main shell resolution is fixed.
            DETAIL_LOD = 1
            lod, _ = make_module(kind, theme_id, theme, mats, export_collection)
            DETAIL_LOD = 0
            combine_by_material(lod)
            export_glb(assets / (kind + "_lod1.glb"), descendants(lod))
            lod_report = audit(lod)
            assert lod_report["nonmanifold_edges"] == 0, (theme_id, kind, "LOD1 closure", lod_report)
            assert lod_report["degenerate_triangles"] == 0, (theme_id, kind, "LOD1 degenerate", lod_report)
            collision_collection = collection("COLLISION_" + kind)
            bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[collision_collection.name]
            collision_root = bpy.data.objects.new("CollisionProxy", None)
            collision_collection.objects.link(collision_root)
            proxy = shell(path, "TunnelShellCollision", [mats["inner"]] * 3, collision_root, steps=10, longitudinal=max(2, math.ceil(path.length / 4)))
            proxy.data.materials.clear()
            export_glb(assets / (kind + "_collision.glb"), descendants(collision_root))
            collision_report = audit(collision_root)
            reports[kind] = dict(file=file.name, length_m=path.length, centerline_radius_m=36 if "curve" in kind else None, turn_degrees=(-30 if "left" in kind else 30) if "curve" in kind else 0, elevation_change_m=path.frame(path.length)[0].z, socket_in_blender=list(path.frame(0)[0]), socket_out_blender=list(path.frame(path.length)[0]), lod0=report, lod1=lod_report, collision=collision_report)
            for obj in list(export_collection.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.collections.remove(export_collection)
            roots[kind], paths[kind] = root, path
            print("LUMO_TRACK_MODULE", theme_id, kind, report["triangles"], report["material_count"], flush=True)
        prepare_review(roots, paths, theme_id, mats, evidence, args.render, args.animation)
        # Pack textures so the authoring scene is a portable editable deliverable.
        bpy.ops.file.pack_all()
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(source / (theme_id + "_tunnel_workshop.blend")), compress=True)
        manifest = dict(schema=1, theme=theme_id, label=theme["label"], source_blend=f"art/lumo_kart/blender/tracks/{theme_id}_tunnel_workshop.blend", blender=bpy.app.version_string, units="meters", axes=dict(blender_forward="+Y", blender_up="+Z", godot_forward="-Z", godot_up="+Y"), existing_road_width_m=ROAD_WIDTH, reserved_clear_width_m=CLEAR_WIDTH, reserved_clear_height_m=4.5, inner_wall_half_width_m=INNER_X, central_ceiling_height_m=SPRING+INNER_Z, texture_size_px=[1024,1024], texture_density_texels_per_meter=512, material_policy="seven theme materials; original texture maps embedded in GLB", modules=reports, source_provenance="Original procedural geometry and original baked images, authored for LUMO; no external assets or Nintendo content", runtime_integration=False, physical_device_fps_verified=False)
        (assets / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print("LUMO_TRACK_THEME_DONE", theme_id, flush=True)


if __name__ == "__main__":
    main()
