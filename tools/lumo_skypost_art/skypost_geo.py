"""Bausteine fuer die Sternenpost-Modelle (Blender, bmesh).

Alle Punkte werden in Godot-Koordinaten angegeben (Y oben, -Z vorne, Meter).
Beim Zusammenbau dreht Model.build() alles einmal in Blenders Z-oben-Raum; der
glTF-Export (export_yup) dreht es zurueck. So bleiben Mass-Angaben direkt mit
den Godot-Messungen (Sitz, Haende, Steuerhorn) vergleichbar.
"""
from __future__ import annotations

import math

import bpy  # noqa: I001  (bpy must come first: it provides bmesh)
import bmesh
from mathutils import Matrix, Vector, noise

from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets/skypost/models"
G_TO_B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def linear(hex_color: str):
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


_MATERIALS: dict[str, bpy.types.Material] = {}


def material(name, color, metal=0.0, rough=.5, emission=0.0, alpha=1.0, coat=0.0):
    if name in _MATERIALS:
        return _MATERIALS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = linear(color)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if coat:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = .2
    if emission:
        p.inputs["Emission Color"].default_value = linear(color)
        p.inputs["Emission Strength"].default_value = emission
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    m.diffuse_color = linear(color)
    _MATERIALS[name] = m
    return m


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATERIALS.clear()


# ------------------------------------------------------------------ primitive bmesh shapes

def _matrix(origin=(0, 0, 0), basis: Matrix | None = None, scale=(1, 1, 1)):
    m = Matrix.Translation(Vector(origin))
    if basis is not None:
        m = m @ basis.to_4x4()
    return m @ Matrix.Diagonal(Vector((*scale, 1.0)))


def box(center, size, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(center)) @ Matrix(_euler(rot)).to_4x4() @ Matrix.Diagonal(Vector((*size, 1)))
    bm.transform(m)
    return bm


def _euler(rot):
    from mathutils import Euler
    return Euler(rot, "XYZ").to_matrix()


def _align(a: Vector, b: Vector) -> Matrix:
    """Basis whose Z axis points from a to b."""
    axis = (b - a).normalized()
    up = Vector((0, 1, 0)) if abs(axis.y) < .95 else Vector((1, 0, 0))
    x = up.cross(axis).normalized()
    y = axis.cross(x).normalized()
    return Matrix((x, y, axis)).transposed()


def cylinder(a, b, r1, r2=None, segments=16, caps=True):
    a, b = Vector(a), Vector(b)
    r2 = r1 if r2 is None else r2
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segments, radius1=r1, radius2=r2,
                          depth=(b - a).length)
    m = Matrix.Translation((a + b) * .5) @ _align(a, b).to_4x4()
    bm.transform(m)
    return bm


def sphere(center, radii, u=16, v=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    bm.transform(Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector((*radii, 1))))
    return bm


def torus(center, major, minor, seg=24, ring=8, axis="y", arc=math.tau):
    bm = bmesh.new()
    rows = []
    closed = arc >= math.tau - 1e-6
    count = seg if closed else seg + 1
    for i in range(count):
        t = arc * i / seg
        row = []
        for j in range(ring):
            s = math.tau * j / ring
            r = major + minor * math.cos(s)
            p = Vector((r * math.cos(t), minor * math.sin(s), r * math.sin(t)))
            row.append(bm.verts.new(p))
        rows.append(row)
    for i in range(seg):
        a = rows[i]
        b = rows[(i + 1) % count] if closed else rows[i + 1]
        for j in range(ring):
            bm.faces.new((a[j], a[(j + 1) % ring], b[(j + 1) % ring], b[j]))
    rot = Matrix.Identity(4)
    if axis == "z":
        rot = Matrix.Rotation(math.pi / 2, 4, "X")
    elif axis == "x":
        rot = Matrix.Rotation(math.pi / 2, 4, "Z")
    bm.transform(Matrix.Translation(Vector(center)) @ rot)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def superellipse(hw, hh, power, n, start=0.0):
    pts = []
    for i in range(n):
        t = start + math.tau * i / n
        c, s = math.cos(t), math.sin(t)
        x = hw * math.copysign(abs(c) ** (2.0 / power), c)
        y = hh * math.copysign(abs(s) ** (2.0 / power), s)
        pts.append((x, y))
    return pts


def loft(sections, n=24, axis="z", cap_start=True, cap_end=True):
    """sections: (along, cx, cy, half_w, half_h, power). Rings perpendicular to axis."""
    bm = bmesh.new()
    rings = []
    for along, cx, cy, hw, hh, pw in sections:
        ring = []
        for x, y in superellipse(hw, hh, pw, n, start=math.pi / 2):
            if axis == "z":
                p = (cx + x, cy + y, along)
            elif axis == "x":
                p = (along, cy + y, cx + x)
            else:
                p = (cx + x, along, cy + y)
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if cap_start:
        _cap(bm, rings[0], sections[0])
    if cap_end:
        _cap(bm, rings[-1], sections[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _cap(bm, ring, section):
    centre = sum((v.co for v in ring), Vector()) / len(ring)
    c = bm.verts.new(centre)
    n = len(ring)
    for j in range(n):
        bm.faces.new((ring[j], ring[(j + 1) % n], c))


def airfoil(chord, thickness, n=14):
    """Closed profile (x along chord 0..1 from leading edge, y thickness), leading edge round."""
    pts = []
    for i in range(n + 1):
        b = math.pi * i / n
        x = (1 - math.cos(b)) / 2
        t = 5 * thickness * (.2969 * math.sqrt(x) - .126 * x - .3516 * x * x + .2843 * x ** 3 - .1036 * x ** 4)
        pts.append((x * chord, t))
    upper = pts
    lower = [(x, -t * .55) for x, t in reversed(pts[1:-1])]
    return upper + lower


def wing(sections, n=14, cap=True):
    """sections: (span_pos Vector-like origin of leading edge, chord, thickness, twist).
    Span runs along the given positions; chord along +Z (backwards in Godot)."""
    bm = bmesh.new()
    rings = []
    for origin, chord, thick in sections:
        o = Vector(origin)
        ring = [bm.verts.new(o + Vector((0, y, x))) for x, y in airfoil(chord, thick, n)]
        rings.append(ring)
    m = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for j in range(m):
            bm.faces.new((a[j], a[(j + 1) % m], b[(j + 1) % m], b[j]))
    if cap:
        for ring in (rings[0], rings[-1]):
            bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def fin(sections, n=12):
    """Vertical fin: sections (origin leading edge, chord, thickness); profile lies in X(thick)/Z(chord)."""
    bm = bmesh.new()
    rings = []
    for origin, chord, thick in sections:
        o = Vector(origin)
        ring = [bm.verts.new(o + Vector((y, 0, x))) for x, y in airfoil(chord, thick, n)]
        rings.append(ring)
    m = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for j in range(m):
            bm.faces.new((a[j], a[(j + 1) % m], b[(j + 1) % m], b[j]))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def star_prism(center, radius, depth, axis="z", points=5, inner=.45):
    bm = bmesh.new()
    top, bot = [], []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points
        r = radius if i % 2 == 0 else radius * inner
        x, y = math.cos(a) * r, -math.sin(a) * r
        top.append(bm.verts.new((x, y, depth / 2)))
        bot.append(bm.verts.new((x, y, -depth / 2)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    k = len(top)
    for i in range(k):
        bm.faces.new((top[i], bot[i], bot[(i + 1) % k], top[(i + 1) % k]))
    rot = Matrix.Identity(4)
    if axis == "x":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    elif axis == "y":
        rot = Matrix.Rotation(-math.pi / 2, 4, "X")
    bm.transform(Matrix.Translation(Vector(center)) @ rot)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism_roof(center, width, depth, height, overhang=.25, thickness=.18):
    """Gable roof, ridge along Z."""
    cx, cy, cz = center
    w = width / 2 + overhang
    d = depth / 2 + overhang
    bm = bmesh.new()
    pts = [(-w, 0), (0, height), (w, 0), (w - .05, -thickness), (0, height - thickness * 1.4), (-w + .05, -thickness)]
    front = [bm.verts.new((cx + x, cy + y, cz - d)) for x, y in pts]
    back = [bm.verts.new((cx + x, cy + y, cz + d)) for x, y in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    k = len(pts)
    for i in range(k):
        bm.faces.new((front[i], back[i], back[(i + 1) % k], front[(i + 1) % k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def lathe(profile, segments=24, center=(0, 0, 0)):
    """profile: (radius, y) from bottom to top. Revolved around +Y."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        ring = []
        for i in range(segments):
            a = math.tau * i / segments
            ring.append(bm.verts.new((center[0] + math.cos(a) * r, center[1] + y, center[2] + math.sin(a) * r)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    if profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ model assembly

class Model:
    """Collects parts (each with one material) and bakes modifiers into one mesh."""

    def __init__(self):
        self.parts = []

    def add(self, bm, mat, bevel=0.0, segments=2, smooth=True, angle=48.0, boolean=None):
        me = bpy.data.meshes.new("part")
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("part", me)
        bpy.context.scene.collection.objects.link(obj)
        if boolean is not None:
            mod = obj.modifiers.new("cut", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.object = boolean
            try:
                mod.material_mode = "TRANSFER"
            except AttributeError:
                pass
        if bevel > 0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(30)
        dg = bpy.context.evaluated_depsgraph_get()
        baked = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(me)
        for poly in baked.polygons:
            poly.use_smooth = smooth
        if smooth:
            baked.set_sharp_from_angle(angle=math.radians(angle))
        names = [m.name for m in baked.materials if m is not None] if boolean is not None else []
        self.parts.append((baked, mat, names))
        return self

    def triangles(self):
        return sum(sum(len(p.vertices) - 2 for p in me.polygons) for me, _, _ in self.parts)

    def build(self, name, parent=None, origin=(0, 0, 0), local=False):
        """origin: pivot in Godot space. local=True: parts are already given around the pivot."""
        materials: list[bpy.types.Material] = []
        bm = bmesh.new()
        for me, mat, transfer in self.parts:
            before = len(bm.faces)
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            local = [m for m in me.materials]
            for face in bm.faces[before:]:
                chosen = mat
                if transfer and face.material_index < len(local) and local[face.material_index] is not None:
                    chosen = local[face.material_index]
                if chosen not in materials:
                    materials.append(chosen)
                face.material_index = materials.index(chosen)
            bpy.data.meshes.remove(me)
        if not local:
            bm.transform(Matrix.Translation(-Vector(origin)))
        bm.transform(G_TO_B)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for m in materials:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = G_TO_B @ Vector(origin)
        self.parts = []
        return obj


def empty(name, at=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = G_TO_B @ Vector(at)
    o.parent = parent
    return o


def descendants(root):
    out = [root]
    for child in root.children:
        out.extend(descendants(child))
    return out


def export_glb(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in descendants(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_normals=True, export_tangents=False, export_vertex_color="ACTIVE",
                              export_all_vertex_colors=True, export_cameras=False, export_lights=False,
                              export_animations=False, export_extras=False)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def fbm(p, octaves=3):
    total, amp, freq = 0.0, 1.0, 1.0
    for _ in range(octaves):
        total += amp * noise.noise(Vector(p) * freq)
        amp *= .5
        freq *= 2.1
    return total
