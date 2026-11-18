"""Geometry kit for the Dschungelherz models (used by build_jungle_art.py).

Everything is authored in Godot space (Y up, -Z forward, metres) with
counter-clockwise front faces; `Geo.to_blender` turns it into a Blender mesh
(Z up) so the glTF exporter brings it back to exactly these coordinates.

Per face corner a Geo stores: UV (texture), UV2 (x = how much the corner sways
in the wind, y = a random phase), a colour (RGB = baked occlusion / tint) and a
normal. Normals are always explicit, so tubes, leaves and bevels look the same
in Blender, in any glTF viewer and in Godot.
"""
from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

UP = Vector((0.0, 1.0, 0.0))


def v3(x, y, z) -> Vector:
    return Vector((float(x), float(y), float(z)))


def any_perpendicular(direction: Vector) -> Vector:
    helper = UP if abs(direction.normalized().dot(UP)) < 0.92 else v3(1, 0, 0)
    return direction.cross(helper).normalized()


class Geo:
    def __init__(self) -> None:
        self.verts: list[Vector] = []
        self.faces: list[tuple[int, ...]] = []
        self.corner_uv: list[list[tuple[float, float]]] = []
        self.corner_uv2: list[list[tuple[float, float]]] = []
        self.corner_col: list[list[tuple[float, float, float, float]]] = []
        self.corner_n: list[list[Vector]] = []
        self.face_mat: list[int] = []
        self.materials: list[str] = []

    # -------------------------------------------------------------- basics
    def mat(self, name: str) -> int:
        if name not in self.materials:
            self.materials.append(name)
        return self.materials.index(name)

    def vert(self, p: Vector) -> int:
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def face(self, ids, uvs, material: str, normals=None, uv2=(0.0, 0.0), col=(1.0, 1.0, 1.0, 1.0)) -> int:
        ids = tuple(ids)
        count = len(ids)
        if normals is None:
            normals = [self.face_normal(ids)] * count
        elif isinstance(normals, Vector):
            normals = [normals] * count
        uv2s = uv2 if isinstance(uv2, list) else [uv2] * count
        cols = col if isinstance(col, list) else [col] * count
        self.faces.append(ids)
        self.corner_uv.append([tuple(u) for u in uvs])
        self.corner_uv2.append([tuple(u) for u in uv2s])
        self.corner_col.append([tuple(c) for c in cols])
        self.corner_n.append([Vector(n).normalized() if Vector(n).length > 1e-9 else UP.copy() for n in normals])
        self.face_mat.append(self.mat(material))
        return len(self.faces) - 1

    def face_normal(self, ids) -> Vector:
        total = Vector((0.0, 0.0, 0.0))
        points = [self.verts[i] for i in ids]
        for index in range(len(points)):
            a = points[index]
            b = points[(index + 1) % len(points)]
            total.x += (a.y - b.y) * (a.z + b.z)
            total.y += (a.z - b.z) * (a.x + b.x)
            total.z += (a.x - b.x) * (a.y + b.y)
        return total.normalized() if total.length > 1e-12 else UP.copy()

    def triangles(self) -> int:
        return sum(len(f) - 2 for f in self.faces)

    def extend(self, other: "Geo") -> None:
        offset = len(self.verts)
        self.verts.extend(Vector(v) for v in other.verts)
        for index, ids in enumerate(other.faces):
            self.faces.append(tuple(i + offset for i in ids))
            self.corner_uv.append(list(other.corner_uv[index]))
            self.corner_uv2.append(list(other.corner_uv2[index]))
            self.corner_col.append(list(other.corner_col[index]))
            self.corner_n.append([Vector(n) for n in other.corner_n[index]])
            self.face_mat.append(self.mat(other.materials[other.face_mat[index]]))

    def transformed(self, matrix) -> "Geo":
        """A copy moved by a 4x4 matrix (mathutils.Matrix)."""
        result = Geo()
        rotation = matrix.to_3x3().inverted().transposed()
        result.verts = [matrix @ v for v in self.verts]
        result.faces = list(self.faces)
        result.corner_uv = [list(c) for c in self.corner_uv]
        result.corner_uv2 = [list(c) for c in self.corner_uv2]
        result.corner_col = [list(c) for c in self.corner_col]
        result.corner_n = [[(rotation @ n).normalized() for n in c] for c in self.corner_n]
        result.face_mat = list(self.face_mat)
        result.materials = list(self.materials)
        return result

    def smooth(self, face_ids=None, angle_deg: float = 180.0) -> None:
        """Recomputes corner normals as area-weighted averages of neighbouring faces
        whose normals differ by less than `angle_deg` (auto smooth)."""
        face_ids = range(len(self.faces)) if face_ids is None else face_ids
        face_ids = list(face_ids)
        limit = math.cos(math.radians(angle_deg))
        normals = {}
        by_vertex: dict[int, list[int]] = {}
        for fid in face_ids:
            ids = self.faces[fid]
            pts = [self.verts[i] for i in ids]
            cross = Vector((0.0, 0.0, 0.0))
            for k in range(1, len(pts) - 1):
                cross += (pts[k] - pts[0]).cross(pts[k + 1] - pts[0])
            normals[fid] = cross
            for i in ids:
                by_vertex.setdefault(self._key(i), []).append(fid)
        for fid in face_ids:
            own = normals[fid].normalized() if normals[fid].length > 1e-12 else UP
            result = []
            for i in self.faces[fid]:
                total = Vector((0.0, 0.0, 0.0))
                for other in by_vertex[self._key(i)]:
                    n = normals[other]
                    if n.length < 1e-12:
                        continue
                    if n.normalized().dot(own) >= limit:
                        total += n
                result.append(total.normalized() if total.length > 1e-12 else own)
            self.corner_n[fid] = result

    def _key(self, index: int):
        v = self.verts[index]
        return (round(v.x, 4), round(v.y, 4), round(v.z, 4))

    def box_uv(self, face_ids, scale: float, offset=(0.0, 0.0)) -> None:
        """Box projection: each face takes the plane of its dominant normal axis."""
        for fid in face_ids:
            n = self.face_normal(self.faces[fid])
            ax = max(range(3), key=lambda k: abs(n[k]))
            uvs = []
            for i in self.faces[fid]:
                p = self.verts[i]
                if ax == 0:
                    uv = (p.z * (1 if n.x > 0 else -1), p.y)
                elif ax == 1:
                    uv = (p.x, p.z * (1 if n.y < 0 else -1))
                else:
                    uv = (p.x * (1 if n.z > 0 else -1), p.y)
                uvs.append((uv[0] * scale + offset[0], uv[1] * scale + offset[1]))
            self.corner_uv[fid] = uvs

    def recolour(self, face_ids, function) -> None:
        for fid in face_ids:
            self.corner_col[fid] = [function(self.verts[i]) for i in self.faces[fid]]

    def resway(self, face_ids, function) -> None:
        for fid in face_ids:
            self.corner_uv2[fid] = [function(self.verts[i], self.corner_uv2[fid][k]) for k, i in enumerate(self.faces[fid])]

    # -------------------------------------------------------------- to Blender
    def to_blender(self, name: str, materials: dict) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(name)
        blender_verts = [(v.x, -v.z, v.y) for v in self.verts]
        mesh.from_pydata(blender_verts, [], [list(f) for f in self.faces])
        mesh.update()
        uv = mesh.uv_layers.new(name="UVMap")
        wind = mesh.uv_layers.new(name="Wind")
        colour = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        loop_normals = []
        for poly in mesh.polygons:
            fid = poly.index
            for k, loop_index in enumerate(range(poly.loop_start, poly.loop_start + poly.loop_total)):
                uv.data[loop_index].uv = self.corner_uv[fid][k]
                wind.data[loop_index].uv = self.corner_uv2[fid][k]
                colour.data[loop_index].color = self.corner_col[fid][k]
                n = self.corner_n[fid][k]
                loop_normals.append((n.x, -n.z, n.y))
            poly.material_index = self.face_mat[fid]
            poly.use_smooth = True
        mesh.color_attributes.active_color = colour
        mesh.uv_layers.active = uv
        for material_name in self.materials:
            mesh.materials.append(materials[material_name])
        mesh.normals_split_custom_set(loop_normals)
        mesh.validate(clean_customdata=False)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# ------------------------------------------------------------------ primitives

def frame_along(direction: Vector, previous_side: Vector | None = None):
    direction = direction.normalized()
    if previous_side is not None:
        side = (previous_side - direction * previous_side.dot(direction))
        if side.length > 1e-4:
            side.normalize()
            return side, direction.cross(side).normalized()
    side = any_perpendicular(direction)
    return side, direction.cross(side).normalized()


def tube(geo: Geo, points, radii, sides: int, material: str, *, uv_around: float = 1.0, uv_len: float = 1.0,
         sway=None, phase: float = 0.0, colours=None, cap_end: bool = False, bump: float = 0.0, seed: int = 0,
         ellipse=None, v_start: float = 0.0) -> float:
    """A smooth tube through `points` (Vectors) with one radius per point.
    `sway` and `colours` give one value per point. `ellipse` = list of (a, b) half axes
    per point that replaces the radius (a along the frame's `up`, b sideways).
    Returns the v coordinate at the end (for continuing a branch)."""
    count = len(points)
    rings = []
    side = None
    v = v_start
    for index in range(count):
        here = points[index]
        ahead = points[min(index + 1, count - 1)] - points[max(index - 1, 0)]
        side, other = frame_along(ahead, side)
        if index > 0:
            v += (points[index] - points[index - 1]).length / uv_len
        ring = []
        for k in range(sides + 1):
            angle = math.tau * k / sides
            c, s = math.cos(angle), math.sin(angle)
            if ellipse is not None:
                a, b = ellipse[index]
                offset = side * (c * b) + other * (s * a)
                normal = (side * (c / max(b, 1e-4)) + other * (s / max(a, 1e-4))).normalized()
            else:
                r = radii[index]
                if bump > 0.0:
                    p = here + (side * c + other * s) * r
                    r *= 1.0 + bump * noise.noise(p * 2.3 + v3(seed, 0, 0))
                offset = (side * c + other * s) * r
                normal = (side * c + other * s).normalized()
            ring.append((here + offset, normal, (k / sides * uv_around, v)))
        rings.append(ring)
    weights = sway if sway is not None else [0.0] * count
    tints = colours if colours is not None else [(1.0, 1.0, 1.0, 1.0)] * count
    ids = [[geo.vert(p) for p, _, _ in ring] for ring in rings]
    for index in range(count - 1):
        for k in range(sides):
            a, b = ids[index][k], ids[index][k + 1]
            c, d = ids[index + 1][k + 1], ids[index + 1][k]
            ra, rb = rings[index][k], rings[index][k + 1]
            rc, rd = rings[index + 1][k + 1], rings[index + 1][k]
            geo.face((a, b, c, d), [ra[2], rb[2], rc[2], rd[2]], material,
                     normals=[ra[1], rb[1], rc[1], rd[1]],
                     uv2=[(weights[index], phase), (weights[index], phase), (weights[index + 1], phase), (weights[index + 1], phase)],
                     col=[tints[index], tints[index], tints[index + 1], tints[index + 1]])
    if cap_end:
        last = rings[-1]
        centre = geo.vert(points[-1])
        tip_dir = (points[-1] - points[-2]).normalized()
        for k in range(sides):
            a = geo.vert(last[k][0])
            b = geo.vert(last[k + 1][0])
            geo.face((a, b, centre), [last[k][2], last[k + 1][2], (0.5, v)], material, normals=tip_dir,
                     uv2=(weights[-1], phase), col=tints[-1])
    return v


def curve(a: Vector, b: Vector, lift: float, steps: int, droop: float = 0.0):
    """Points from a to b bending up by `lift` (and down by `droop` at the end)."""
    out = []
    for k in range(steps + 1):
        t = k / steps
        p = a.lerp(b, t) + UP * (lift * math.sin(t * math.pi * 0.5) * (1 - t) * 1.2 - droop * t * t)
        out.append(p)
    return out


# cell rectangles of the leaf atlas in Blender UV space (v up)
LEAF_CELLS = {
    "twig": (0.0, 0.5, 0.5, 1.0),
    "small": (0.5, 0.5, 1.0, 1.0),
    "fern": (0.0, 0.0, 0.5, 0.5),
    "big": (0.5, 0.0, 1.0, 0.5),
}


def leaf_card(geo: Geo, base: Vector, direction: Vector, side_hint: Vector, length: float, width: float, cell: str,
              material: str, *, bend: float = 0.25, fold: float = 0.12, segments: int = 3, centre: Vector | None = None,
              spherical: float = 0.6, sway=(0.6, 1.0), phase: float = 0.0, ao=(1.0, 1.0), columns: int = 3,
              inset: float = 0.01) -> None:
    """A bent, V-folded card showing one atlas cell. Base at the cell's bottom."""
    u0, v0, u1, v1 = LEAF_CELLS[cell]
    u0 += inset
    u1 -= inset
    v0 += inset
    v1 -= inset
    direction = direction.normalized()
    side = (side_hint - direction * side_hint.dot(direction))
    side = side.normalized() if side.length > 1e-4 else any_perpendicular(direction)
    face_n = side.cross(direction).normalized()
    if face_n.dot(UP) < -0.2:
        face_n = -face_n
        side = -side
    rows = []
    for k in range(segments + 1):
        t = k / segments
        spine = base + direction * (length * t) - UP * (bend * length * t * t)
        row = []
        for c in range(columns):
            s = (c / (columns - 1)) * 2.0 - 1.0 if columns > 1 else 0.0
            ridge = (1.0 - abs(s)) * fold * width
            p = spine + side * (s * width * 0.5) + face_n * ridge
            uv = (u0 + (u1 - u0) * (s * 0.5 + 0.5), v0 + (v1 - v0) * t)
            n = face_n.copy()
            if centre is not None and spherical > 0.0:
                out = (p - centre)
                if out.length > 1e-4:
                    n = face_n.lerp(out.normalized(), spherical).normalized()
            w = sway[0] + (sway[1] - sway[0]) * t
            a = ao[0] + (ao[1] - ao[0]) * t
            row.append((geo.vert(p), uv, n, (w, phase), (a, a, a, 1.0)))
        rows.append(row)
    for k in range(segments):
        for c in range(columns - 1):
            corners = [rows[k][c], rows[k][c + 1], rows[k + 1][c + 1], rows[k + 1][c]]
            geo.face([x[0] for x in corners], [x[1] for x in corners], material, normals=[x[2] for x in corners],
                     uv2=[x[3] for x in corners], col=[x[4] for x in corners])


def bevel_box(geo: Geo, centre: Vector, half: Vector, material: str, *, radius: float = 0.04, segments: int = 2,
              uv_scale: float = 0.5, rotation=None, jitter: float = 0.0, rng: random.Random | None = None,
              colour=(1.0, 1.0, 1.0, 1.0), uv_offset=(0.0, 0.0)) -> None:
    """A box with rounded edges (bmesh bevel), smooth bevels, flat faces, box UVs."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * half.x, vert.co.y * half.y, vert.co.z * half.z))
    r = min(radius, half.x * 0.45, half.y * 0.45, half.z * 0.45)
    if r > 0.0005 and segments > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=r, segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    if jitter > 0.0 and rng is not None:
        for vert in bm.verts:
            vert.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter
    _bm_into(geo, bm, material, centre, rotation, colour)
    start = len(geo.faces) - len(bm.faces)
    faces = range(start, len(geo.faces))
    geo.smooth(faces, angle_deg=35.0)
    geo.box_uv(faces, uv_scale, uv_offset)
    bm.free()


def _bm_into(geo: Geo, bm, material: str, centre: Vector, rotation, colour) -> None:
    bm.verts.ensure_lookup_table()
    ids = {}
    for vert in bm.verts:
        p = Vector(vert.co)
        if rotation is not None:
            p = rotation @ p
        ids[vert.index] = geo.vert(p + centre)
    for face in bm.faces:
        geo.face([ids[v.index] for v in face.verts], [(0.0, 0.0)] * len(face.verts), material, col=colour)


def blob(geo: Geo, centre: Vector, size: Vector, material: str, *, subdiv: int = 3, rough: float = 0.2, freq: float = 1.2,
         seed: int = 0, flat_bottom: float | None = None, uv_scale: float = 0.5, colour=None, sway: float = 0.0,
         phase: float = 0.0, smooth_angle: float = 180.0, crease: float = 0.0) -> range:
    """Noise-displaced icosphere: rocks, heads, caps. Smooth normals, box UVs.
    `colour` may be a function of the local unit position. Returns the face range."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    offset = v3(seed * 3.17, seed * 1.31, seed * 2.03)
    for vert in bm.verts:
        d = vert.co.normalized()
        n = noise.noise(d * freq + offset) * 0.6 + noise.noise(d * freq * 2.7 + offset) * 0.3 + noise.noise(d * freq * 6.1 + offset) * 0.1
        if crease > 0.0:
            ridged = 1.0 - abs(noise.noise(d * freq * 1.7 + offset * 0.5))
            n -= crease * ridged ** 4
        p = Vector((d.x * size.x, d.y * size.y, d.z * size.z)) * (1.0 + rough * n)
        if flat_bottom is not None and p.y < -size.y * flat_bottom:
            p.y = -size.y * flat_bottom + (p.y + size.y * flat_bottom) * 0.08
        vert.co = p
    start = len(geo.faces)
    _bm_into(geo, bm, material, centre, None, (1.0, 1.0, 1.0, 1.0))
    bm.free()
    faces = range(start, len(geo.faces))
    geo.smooth(faces, angle_deg=smooth_angle)
    geo.box_uv(faces, uv_scale)
    if colour is not None:
        geo.recolour(faces, lambda p: colour((p - centre)))
    if sway:
        geo.resway(faces, lambda p, old: (sway, phase))
    return faces


def lathe(geo: Geo, profile, sides: int, material: str, *, centre: Vector | None = None, uv_around: float = 1.0,
          uv_len: float = 1.0, axis=None, colour=None, smooth_angle: float = 50.0) -> range:
    """Surface of revolution around Y from a (radius, height) profile, bottom to top."""
    centre = centre if centre is not None else v3(0, 0, 0)
    start = len(geo.faces)
    rings = []
    v = 0.0
    for index, (r, h) in enumerate(profile):
        if index:
            pr, ph = profile[index - 1]
            v += math.hypot(r - pr, h - ph) / uv_len
        ring = []
        for k in range(sides + 1):
            angle = math.tau * k / sides
            p = v3(math.cos(angle) * r, h, -math.sin(angle) * r)
            if axis is not None:
                p = axis @ p
            ring.append((geo.vert(p + centre), (k / sides * uv_around, v)))
        rings.append(ring)
    for index in range(len(rings) - 1):
        for k in range(sides):
            a, b = rings[index][k], rings[index][k + 1]
            c, d = rings[index + 1][k + 1], rings[index + 1][k]
            if geo.verts[a[0]] == geo.verts[d[0]] and geo.verts[b[0]] == geo.verts[c[0]]:
                continue
            ids = [a[0], b[0], c[0], d[0]]
            uvs = [a[1], b[1], c[1], d[1]]
            if geo.verts[a[0]] == geo.verts[b[0]]:
                ids, uvs = [a[0], c[0], d[0]], [a[1], c[1], d[1]]
            elif geo.verts[c[0]] == geo.verts[d[0]]:
                ids, uvs = [a[0], b[0], c[0]], [a[1], b[1], c[1]]
            geo.face(ids, uvs, material)
    faces = range(start, len(geo.faces))
    geo.smooth(faces, angle_deg=smooth_angle)
    if colour is not None:
        geo.recolour(faces, colour)
    return faces


def fbm3(p: Vector, octaves: int = 3) -> float:
    total, amp, norm = 0.0, 1.0, 0.0
    for _ in range(octaves):
        total += noise.noise(p) * amp
        norm += amp
        amp *= 0.5
        p = p * 2.03
    return total / norm
