"""Build the LUMO rival animals as continuous, rigged and animated kart drivers.

Run: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/drivers/build_animal_drivers.py --species lion [--review DIR] [--no-export]

Pipeline per animal (everything local, no downloads, no generators):
1. Sculpt one signed-distance body (suit + fur + head + ears + tail) in the
   seated kart pose of the existing 21-bone driver contract.
2. Mesh it with sparse surface nets, decimate with extra density around the
   face, colour borders and fingers.
3. Colour, finish and weight every vertex from the owning sculpt parts.
4. Add separate face parts that move on their own bones like Lumo's face:
   eyeballs (Eye.L/R), upper lids (Lid.L/R), jaw (Jaw); plus goggles,
   brows, nose details, teeth, tongue and whiskers.
5. Animate all clips used by race, garage and table, export three LOD GLBs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import sdf_kit as K  # noqa: E402
from animal_body import Design, SIGN  # noqa: E402
import animal_species as SP  # noqa: E402

ROOT = HERE.parents[2]
TAU = math.tau
BODY_BONES = ['Root', 'Pelvis', 'Spine', 'Chest', 'Neck', 'Head', 'Tail',
              'UpperArm.L', 'Forearm.L', 'Hand.L', 'Thigh.L', 'Shin.L', 'Foot.L', 'Ear.L',
              'UpperArm.R', 'Forearm.R', 'Hand.R', 'Thigh.R', 'Shin.R', 'Foot.R', 'Ear.R']
FACE_BONES = ['Jaw', 'Eye.L', 'Eye.R', 'Lid.L', 'Lid.R']
CLIPS = {
    'idle': 72, 'kart_seated': 72, 'kart_steer_left': 48, 'kart_steer_right': 48,
    'kart_jump': 36, 'celebrate': 72, 'kart_celebrate': 72, 'kart_hit': 36,
    'greeting_wave': 48, 'agree_nod': 36, 'point_portal': 48, 'card_play': 36,
}
LID_HIDDEN = .93
LID_SHOWN = 1.045
FINISHES = {
    'Organic': (['Fur', 'Cream', 'InnerEar', 'Mane', 'ManeDark', 'Skin', 'Belly', 'Feather', 'FeatherDark', 'FeatherLight', 'Spot', 'Shell', 'ShellDark', 'ShellRim', 'Brow', 'Tail', 'TailLight', 'TailTip', 'Disc', 'Talon', 'Web', 'Scale', 'Plastron', 'Lash'], .82, 0.0, .25),
    'Fabric': (['Suit', 'Navy', 'Orange', 'White'], .66, 0.0, .12),
    'Rubber': (['Rubber', 'Glove'], .86, 0.0, .05),
    'Metal': (['Metal'], .28, .8, 0.0),
    'Glass': (['GoggleGlass'], .1, .2, 0.0),
    'Face': (['EyeWhite', 'Iris', 'Pupil', 'Catch', 'Nose', 'Beak', 'Mouth', 'Tongue', 'Teeth', 'Lid', 'Claw', 'Nail'], .32, 0.0, 0.0),
}


def srgb_to_linear(hex_color):
    values = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return np.array([v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values])


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ sculpt
class Sculpt:
    def __init__(self, design: Design, voxel=.0045):
        self.d = design
        self.field = K.Field((-.62, -.78, .66), (.62, .66, 2.36), voxel)
        for part in design.parts:
            self.field.apply(part.shape, part.op, part.k)

    def ray(self, origin, direction, far=.8):
        """First surface hit of the sculpt along a ray (origin outside)."""
        o = np.asarray(origin, dtype=np.float64)
        dvec = np.asarray(direction, dtype=np.float64)
        dvec = dvec / np.linalg.norm(dvec)
        ts = np.arange(0, far, self.field.h * .5)
        pts = o + ts[:, None] * dvec
        vals = self.field.sample(pts)
        inside = np.nonzero(vals < 0)[0]
        if len(inside) == 0:
            return None
        i = inside[0]
        if i == 0:
            return o
        a, b = vals[i - 1], vals[i]
        t = ts[i - 1] + (ts[i] - ts[i - 1]) * a / (a - b)
        return o + dvec * t

    def normal(self, point):
        g = self.field.gradient(np.asarray([point]))[0]
        return g / max(np.linalg.norm(g), 1e-9)


def owner_weights(design: Design, pts, tau_scale=1.0):
    owners = [p for p in design.parts if p.owns]
    dist = np.stack([p.shape(pts.astype(np.float32)).astype(np.float64) for p in owners], axis=1)
    dmin = dist.min(axis=1, keepdims=True)
    taus = np.array([p.tau for p in owners]) * tau_scale
    soft = np.exp(-(dist - dmin) / taus[None, :])
    soft[(dist - dmin) > 5 * taus[None, :]] = 0.0
    soft /= soft.sum(axis=1, keepdims=True)
    return owners, dist, soft


def vertex_attributes(design: Design, pts):
    """Colour (linear RGB), label and bone weights for each surface point."""
    owners, dist, soft = owner_weights(design, pts)
    labels = sorted({p.label for p in owners} | {p.label for p in design.paints})
    colors = np.zeros((len(pts), 3))
    nearest = np.argmin(dist, axis=1)
    label_index = np.array([labels.index(owners[i].label) for i in nearest])
    # colour: sharp between suit parts, softer inside fur (owner tau)
    owners_c, dist_c, soft_c = owner_weights(design, pts, .35)
    for j, p in enumerate(owners_c):
        colors += soft_c[:, j:j + 1] * srgb_to_linear(design.palette[p.label])[None, :]
    for paint in design.paints:
        val = paint.shape(pts.astype(np.float32)).astype(np.float64)
        alpha = smooth((paint.soft - val) / (2 * paint.soft))
        if paint.only is not None:
            allowed = np.isin(np.array(labels)[label_index], list(paint.only))
            alpha = alpha * allowed
        col = srgb_to_linear(design.palette[paint.label])
        colors = colors * (1 - alpha[:, None]) + col[None, :] * alpha[:, None]
        label_index = np.where(alpha > .5, labels.index(paint.label), label_index)
    weights = {}
    for j, p in enumerate(owners):
        w = p.bones
        if isinstance(w, str):
            w = {w: 1.0}
        if callable(w):
            w = w(pts)
        for bone, value in w.items():
            weights[bone] = weights.get(bone, 0.0) + soft[:, j] * value
    return colors, [labels[i] for i in label_index], weights


def detail_mask(design: Design, pts):
    mask = np.full(len(pts), .15)
    for shape in design.detail:
        val = shape(pts.astype(np.float32))
        mask = np.maximum(mask, np.where(val < 0, 1.0, 0.0))
    for paint in design.paints:
        val = np.abs(paint.shape(pts.astype(np.float32)))
        mask = np.maximum(mask, np.where(val < .012, .9, 0.0))
    # fingers, ears and face carry the character: keep them dense
    mask = np.maximum(mask, np.where(pts[:, 2] > 1.42, .55, 0.0))
    # importance 0..1 -> stored so that the inverted weight never reaches 0
    return np.clip(mask * .8, 0.0, .8)


# ------------------------------------------------------------------ mesh helpers
PARTS = []


def new_object(name, verts, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in verts], [], [tuple(int(i) for i in f) for f in faces])
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def assign(obj, colors, labels, weights):
    """Store colour + label (as material slot name) + normalized weights."""
    mesh = obj.data
    attr = mesh.color_attributes.new('Palette', 'BYTE_COLOR', 'POINT')
    rgba = np.ones((len(mesh.vertices), 4))
    rgba[:, :3] = colors
    attr.data.foreach_set('color', rgba.ravel())
    names = list(weights)
    stack = np.stack([np.asarray(weights[n], dtype=np.float64) * np.ones(len(mesh.vertices)) for n in names], axis=1)
    stack[stack < 1e-4] = 0.0
    order = np.argsort(-stack, axis=1)[:, :4]
    for v in range(len(mesh.vertices)):
        chosen = [(names[i], stack[v, i]) for i in order[v] if stack[v, i] > 0]
        total = sum(w for _, w in chosen)
        for bone, w in chosen:
            group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            group.add([v], w / total, 'REPLACE')


def label_materials(obj, labels):
    """Face material = majority finish of its vertices (labels per vertex)."""
    finish_of = {}
    for finish, (names, *_rest) in FINISHES.items():
        for n in names:
            finish_of[n] = finish
    mats = list(FINISHES)
    for m in mats:
        obj.data.materials.append(bpy.data.materials['Finish_' + m])
    vf = [mats.index(finish_of.get(label, 'Organic')) for label in labels]
    for poly in obj.data.polygons:
        votes = [vf[i] for i in poly.vertices]
        poly.material_index = max(set(votes), key=votes.count)


EYE_CENTRES = {}


def design_eye_centre(name):
    return EYE_CENTRES.get(name.split('.')[-1], (0, 0, 0))


def primitive(name, verts, faces, color, finish, bones):
    """A separate accessory surface with one colour (or per-vertex colours)."""
    obj = new_object(name, verts, faces)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # open shells (lids): make sure the faces look away from the part centre
    centre = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    if name.startswith('Lid'):
        centre = Vector(design_eye_centre(name))
    outward = sum((f.calc_center_median() - centre).dot(f.normal) for f in bm.faces)
    if outward < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data); bm.free()
    n = len(obj.data.vertices)
    if isinstance(color, str):
        cols = np.repeat(srgb_to_linear(color)[None, :], n, axis=0)
    else:
        cols = np.asarray(color)
    w = bones if isinstance(bones, dict) else {bones: 1.0}
    assign(obj, cols, [finish] * n, {k: np.full(n, v) for k, v in w.items()} if not callable(bones) else bones(np.array([v.co for v in obj.data.vertices])))
    obj.data.materials.append(bpy.data.materials['Finish_' + finish])
    for poly in obj.data.polygons:
        poly.use_smooth = True
    PARTS.append(obj)
    return obj


def ellipsoid_mesh(center, radii, rot=None, seg=24, rings=14, polar=None, open_end=False):
    """UV ellipsoid; `polar` lists ring positions (0 = back pole, 1 = front)."""
    c = Vector(center)
    R = rot if rot is not None else Matrix.Identity(3)
    ring_t = polar if polar is not None else [j / rings for j in range(1, rings)]
    verts = [c + R @ Vector((0, 0, -radii[2]))]
    for t in ring_t:
        th = math.pi * t
        for i in range(seg):
            a = TAU * i / seg
            verts.append(c + R @ Vector((radii[0] * math.sin(th) * math.cos(a), radii[1] * math.sin(th) * math.sin(a), -radii[2] * math.cos(th))))
    top = len(verts)
    verts.append(c + R @ Vector((0, 0, radii[2])))
    faces = [(0, 1 + (i + 1) % seg, 1 + i) for i in range(seg)]
    nr = len(ring_t)
    for j in range(nr - 1):
        for i in range(seg):
            a = 1 + j * seg + i
            b = 1 + j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    base = 1 + (nr - 1) * seg
    if open_end:
        verts.pop()
    else:
        faces += [(base + i, base + (i + 1) % seg, top) for i in range(seg)]
    return [tuple(v) for v in verts], faces, ring_t


def tube_mesh(points, radii, sides=10, caps=True):
    pts = [Vector(p) for p in points]
    verts = []
    for i, p in enumerate(pts):
        tan = (pts[min(len(pts) - 1, i + 1)] - pts[max(0, i - 1)]).normalized()
        ref = Vector((0, 0, 1)) if abs(tan.z) < .9 else Vector((0, 1, 0))
        u = tan.cross(ref).normalized(); v = tan.cross(u).normalized()
        r = radii[i] if isinstance(radii, list) else radii
        rx, ry = r if isinstance(r, tuple) else (r, r)
        for k in range(sides):
            a = TAU * k / sides
            verts.append(tuple(p + u * math.cos(a) * rx + v * math.sin(a) * ry))
    faces = []
    for i in range(len(pts) - 1):
        for k in range(sides):
            a, b = i * sides + k, i * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if caps:
        faces.append(tuple(range(sides - 1, -1, -1)))
        faces.append(tuple((len(pts) - 1) * sides + k for k in range(sides)))
    return verts, faces


# ------------------------------------------------------------------ build body
def build_body(design: Design, sculpt: Sculpt, target_tris):
    t0 = time.time()
    verts, quads = sculpt.field.mesh(newton=3)
    print('surface nets', verts.shape, quads.shape, round(time.time() - t0, 1), 's')
    obj = new_object('Body', verts, quads)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data); bm.free()
    # keep only the biggest connected piece (no floating noise crumbs)
    keep_largest(obj)
    pts = np.array([v.co for v in obj.data.vertices])
    mask = detail_mask(design, pts)
    group = obj.vertex_groups.new(name='Detail')
    for i, w in enumerate(mask):
        group.add([i], float(w), 'REPLACE')
    # Weighted collapse cannot always reach the ratio in one pass: repeat.
    for _ in range(5):
        tris = len(obj.data.polygons)
        if tris <= target_tris * 1.03:
            break
        dec = obj.modifiers.new('Budget', 'DECIMATE')
        dec.ratio = max(.05, target_tris / tris)
        dec.vertex_group = 'Detail'
        dec.vertex_group_factor = 1.0
        # In Blender's collapse mode the group weight is how freely a vertex
        # may be collapsed (0 = locked). Face, colour borders and fingers get
        # a low weight, plain suit areas the full weight.
        dec.invert_vertex_group = True
        dec.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=dec.name)
    obj.vertex_groups.remove(obj.vertex_groups['Detail'])
    # light relaxation removes decimation facets while staying on the sculpt
    pts = np.array([v.co for v in obj.data.vertices])
    for _ in range(2):
        val = sculpt.field.sample(pts)
        g = sculpt.field.gradient(pts)
        pts = pts - (val / np.maximum((g * g).sum(1), 1e-9))[:, None] * g
    obj.data.vertices.foreach_set('co', pts.ravel())
    obj.data.update()
    conform_lower_back(obj)
    orient_outward(obj, sculpt)
    pts = np.array([v.co for v in obj.data.vertices])
    colors, labels, weights = vertex_attributes(design, pts)
    jaw_weights(design, pts, weights)
    # the seat back keeps tail roots in place: tails follow the Tail bone only
    assign(obj, colors, labels, weights)
    label_materials(obj, labels)
    body_group = obj.vertex_groups.new(name='LODBody')
    body_group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    for poly in obj.data.polygons:
        poly.use_smooth = True
    print('body', len(obj.data.polygons), 'tris', round(time.time() - t0, 1), 's')
    PARTS.append(obj)
    return obj


def orient_outward(obj, sculpt):
    """Make every body face point out of the sculpt (along the field gradient).

    bmesh.recalc_face_normals only makes the winding consistent; on the dense
    surface-nets body its outside guess can fail and turn the whole skin inside
    out. Cycles ignores back-face culling, so Blender renders still looked
    right, but Godot culls the (reversed) front of the face and shows the inner
    back of the head instead: no light muzzle, no pink inner ears.
    """
    mesh = obj.data
    n = len(mesh.polygons)
    centers = np.zeros(n * 3); normals = np.zeros(n * 3)
    mesh.polygons.foreach_get('center', centers)
    mesh.polygons.foreach_get('normal', normals)
    grad = sculpt.field.gradient(centers.reshape(-1, 3))
    agree = float(((grad * normals.reshape(-1, 3)).sum(1) > 0).mean())
    if agree < .5:
        bm = bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(mesh); bm.free()
        mesh.update()
    print('body faces outward %.3f%s' % (max(agree, 1 - agree), ' (flipped)' if agree < .5 else ''))


def keep_largest(obj):
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    islands = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; island = []
        seen.add(v.index)
        while stack:
            cur = stack.pop(); island.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        islands.append(island)
    islands.sort(key=len, reverse=True)
    drop = [v for island in islands[1:] for v in island]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context='VERTS')
    bm.to_mesh(obj.data); bm.free()
    print('islands', len(islands), 'dropped verts', len(drop))


def conform_lower_back(obj):
    """Measured inner seat profile: the lower back may not cut the seat shell."""
    profile = [(.70, .03), (.75, .057), (.775, .0882), (.8, .12), (.825, .1476), (.85, .1748), (.875, .2014),
               (.9, .2275), (.925, .2528), (.95, .2771), (.975, .3004), (1.0, .3195), (1.1, .40)]
    zs = np.array([p[0] for p in profile]); ds = np.array([p[1] for p in profile]) - .03
    for v in obj.data.vertices:
        z = v.co.z
        if z > .99 or v.co.y >= 0 or abs(v.co.x) > .3:
            continue
        limit = float(np.interp(z, zs, ds))
        if -v.co.y > limit:
            v.co.y = -(limit + .01 * math.tanh((-v.co.y - limit) / .01))
    obj.data.update()


def jaw_weights(design: Design, pts, weights):
    if not design.mouth:
        return
    m = design.mouth
    x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
    lip = m['top'] + m['curve'] * x * x - m['rz'] * .55
    cy = m['center'][1]
    w = smooth((lip - z) / .03) * smooth((y - (cy - .16)) / .08) * smooth((m['rx'] * 2.6 - np.abs(x)) / .05) * smooth((z - (m['center'][2] - .17)) / .05)
    head = weights.get('Head', np.zeros(len(pts)))
    moved = head * w
    weights['Head'] = head - moved
    weights['Jaw'] = weights.get('Jaw', np.zeros(len(pts))) + moved


# ------------------------------------------------------------------ face parts
def eyes(design: Design, sculpt: Sculpt):
    e = design.eyes
    rx, ry, rz = e['radius']
    pal = design.palette
    iris_a, pupil_a = e.get('iris_angle', .30), e.get('pupil_angle', .17)
    # Rings cluster around the iris and pupil borders so both stay round and crisp.
    polar = sorted(set([.02, .05, .08, .11, .14, pupil_a - .006, pupil_a + .006, .2, .23, .26, .29, iris_a - .015, iris_a - .005, iris_a + .005, .4, .46, .55, .65, .75, .85, .93]))
    polar = [1 - t for t in polar][::-1]
    for side in 'LR':
        c = Vector(e['center'][side])
        EYE_CENTRES[side] = tuple(c)
        gaze = Vector(e.get('gaze', (0, 1, 0))).normalized()
        out = Vector((SIGN[side] * e.get('splay', .18), 0, 0))
        axis = (gaze + out).normalized()
        R = axis.to_track_quat('Z', 'Y').to_matrix()
        verts, faces, rings = ellipsoid_mesh(c, (rx, rz, ry), R, e.get('segments', 32), 0, polar)
        cols = []
        iris = srgb_to_linear(pal[e['iris']])
        ax, ay = e.get('pupil_aspect', (1.0, 1.0))
        sp, si = math.sin(math.pi * pupil_a), math.sin(math.pi * iris_a)
        Rinv = R.inverted()
        for co in verts:
            q = Rinv @ (Vector(co) - c)
            q = Vector((q.x / rx, q.y / rz, q.z / ry)).normalized()
            radial = math.hypot(q.x, q.y)
            if q.z > 0 and math.hypot(q.x / ax, q.y / ay) < sp:
                cols.append(srgb_to_linear(pal.get('PupilColor', pal['Pupil'])))
            elif q.z > 0 and radial < si:
                f = radial / si
                angle = math.atan2(q.y, q.x)
                fibres = 0.5 + 0.5 * math.cos(11 * angle + 2.2 * f)
                rim = max(0.0, (f - 0.84) / 0.16)
                amber = srgb_to_linear('F1AD64') * (1.0 - f) ** 2
                cols.append(iris * (1.18 + 0.21 * fibres - 0.58 * rim) + amber * 0.25)
            else:
                cols.append(srgb_to_linear(pal['EyeWhite']))
        primitive('Eye.' + side, verts, faces, np.clip(np.array(cols), 0, 1), 'Face', 'Eye.' + side)
        # fixed catch lights on the head, so they stay put while the eye looks
        for local, size in [((-.36, .48, .80), (.016, .021, .004)), ((.38, -.42, .82), (.007, .008, .003))]:
            dvec = (R @ Vector(local)).normalized()
            p = c + Vector((dvec.x * rx, dvec.y * ry, dvec.z * rz)) * 1.03
            v, f, _ = ellipsoid_mesh(p, size, R, 8, 4)
            primitive('Catchlight.' + side, v, f, 'FFFFFF', 'Face', 'Head')
        # Upper lid: an open shell just outside the eyeball, rotated up into the
        # socket at rest; the Lid bone swings it down over the eye to blink.
        # Built inside the eyeball so it can never show through at rest (even
        # with low depth precision); the blink scales it out over the eye.
        lid_r = (rx * LID_HIDDEN, rz * LID_HIDDEN, ry * LID_HIDDEN)
        lid_polar = [j / 9 * .56 for j in range(1, 10)]
        rest = e.get('lid_rest', 2.6)
        Rl = Matrix.Rotation(rest, 3, 'X') @ Matrix.Rotation(math.pi / 2, 3, 'X')
        lv, lf, _ = ellipsoid_mesh(c, lid_r, Rl, 24, 0, lid_polar, open_end=True)
        lid_col = pal.get(e['lid'], pal['Fur'])
        primitive('Lid.' + side, lv, lf, lid_col, 'Organic', 'Lid.' + side)
        soft_lid(design, side, c, R, (rx, rz, ry), lid_col)


def soft_lid(design: Design, side, c, R, radii, colour):
    """Lumo-style resting upper lid: a thin fur cap over the top of the eye with
    a dark lash line that dips toward the corners, so the eye reads soft and
    friendly instead of staring. It sits outside the blink lid (Head bone)."""
    e = design.eyes
    cover = e.get('lid_cover', .95)  # radians of elevation where the lid edge sits in front
    if cover is None:
        return
    s = SIGN[side]
    scale = e.get('lid_cap_scale', 1.06)
    az_max = 1.75

    def point(az, el, grow):
        local = Vector((math.cos(el) * math.sin(az) * radii[0], math.sin(el) * radii[1], math.cos(el) * math.cos(az) * radii[2])) * grow
        return c + R @ local

    def edge(az):
        return cover - .3 * (az / az_max) ** 2 + .1 * s * az / az_max * e.get('lid_tilt', 0.0)
    cols, rows = 26, 7
    verts, faces = [], []
    for i in range(cols):
        az = -az_max + 2 * az_max * i / (cols - 1)
        el0 = edge(az)
        for j in range(rows):
            el = el0 + (1.45 - el0) * j / (rows - 1)
            verts.append(tuple(point(az, el, scale)))
    for i in range(cols - 1):
        for j in range(rows - 1):
            a = i * rows + j
            faces.append((a, a + rows, a + rows + 1, a + 1))
    primitive('LidCap.' + side, verts, faces, colour, 'Organic', 'Head')
    lash = [tuple(point(az, edge(az) + .02, scale + .012)) for az in np.linspace(-az_max * .92, az_max * .92, 17)]
    radii_l = [(.0035, .003)] + [(.0075, .005)] * 15 + [(.0035, .003)]
    v, f = tube_mesh(lash, radii_l, 6)
    primitive('Lash', v, f, design.palette.get('Lash', '2E1C14'), 'Organic', 'Head')


def brows(design: Design, sculpt: Sculpt):
    b = getattr(design, 'brows', None)
    if not b:
        return
    for side in 'LR':
        s = SIGN[side]
        pts = []
        points = b['points'](s)
        for i, (x, z) in enumerate(points):
            # Lumo's brows sit well above the eyes and rise toward the nose;
            # low brows that dip inward read as a frown
            z += b.get('lift', .022) + b.get('inner_lift', .012) * (1 - i / max(1, len(points) - 1))
            hit = sculpt.ray((x, .6, z), (0, -1, 0))
            if hit is not None:
                pts.append(tuple(hit + np.array([0, .004, 0])))
        if len(pts) < 2:
            continue
        r = b['radius']
        radii = [(r * .6, r * .45)] + [(r, r * .6)] * (len(pts) - 2) + [(r * .5, r * .4)]
        v, f = tube_mesh(pts, radii, 10)
        primitive('Brow.' + side, v, f, design.palette[b['label']], 'Organic', 'Head')


def mouth_parts(design: Design, sculpt: Sculpt):
    if not design.mouth:
        return
    m = design.mouth
    cx, cy, cz = m['center']
    pal = design.palette
    v, f, _ = ellipsoid_mesh((cx, cy - m['ry'] * .55, cz), (m['rx'] * 1.05, m['ry'] * .6, m['rz'] * 1.25), seg=24, rings=12)
    primitive('MouthBack', v, f, pal['Mouth'], 'Face', {'Head': .5, 'Jaw': .5})
    v, f, _ = ellipsoid_mesh((cx, cy - m['ry'] * .25, cz - m['rz'] * .55), (m['rx'] * .7, m['ry'] * .45, m['rz'] * .35), seg=20, rings=10)
    primitive('Tongue', v, f, pal['Tongue'], 'Face', 'Jaw')
    top = m['top']
    if m.get('teeth') == 'buck':
        for s in (-1, 1):
            v, f, _ = ellipsoid_mesh((s * .012, cy + m['ry'] * .45, top - .016), (.011, .006, .016), seg=12, rings=8)
            primitive('Tooth', v, f, pal['Teeth'], 'Face', 'Head')
    elif m.get('teeth') == 'upper':
        pts = [(x, cy + m['ry'] * (.62 - 2.0 * x * x), top + m['curve'] * x * x - .009) for x in np.linspace(-m['rx'] * .62, m['rx'] * .62, 7)]
        v, f = tube_mesh(pts, [(.006, .004)] + [(.009, .006)] * 5 + [(.006, .004)], 8)
        primitive('Teeth', v, f, pal['Teeth'], 'Face', 'Head')


def goggles(design: Design, sculpt: Sculpt):
    g = getattr(design, 'goggle', None)
    if not g:
        return
    z0 = g['z']
    tilt = g.get('tilt', .2)
    center_y = g.get('axis_y', -.02)
    pal = design.palette
    strap = []
    for i in range(36):
        a = TAU * i / 36
        dirv = np.array([math.cos(a), math.sin(a), 0.0])
        zz = z0 - tilt * .12 * math.sin(a)
        origin = np.array([0, center_y, zz]) + dirv * .75
        hit = sculpt.ray(origin, -dirv, .75)
        if hit is None:
            continue
        strap.append(tuple(hit + dirv * .006))
    if len(strap) > 8 and not g.get('no_strap'):
        strap.append(strap[0])
        v, f = tube_mesh(strap, (.009, .017), 6, caps=False)
        primitive('GoggleStrap', v, f, pal['Navy'], 'Rubber', 'Head')
    if g.get('strap_stub'):
        # short strap ends that run back from the goggles and vanish in the mane
        for s in (-1, 1):
            pts = []
            for k, a in enumerate(np.linspace(.85, .85 - g['strap_stub'] * 6, 6)):
                ang = a if s > 0 else math.pi - a
                dirv = np.array([math.cos(ang), math.sin(ang), 0.0])
                origin = np.array([0, center_y, z0]) + dirv * .75
                hit = sculpt.ray(origin, -dirv, .75)
                if hit is not None:
                    pts.append(tuple(hit + dirv * (.006 - .012 * max(0, k - 3))))
            if len(pts) > 2:
                v, f = tube_mesh(pts, (.009, .017), 6)
                primitive('GoggleStrap', v, f, pal['Navy'], 'Rubber', 'Head')
    for s in (-1, 1):
        x = s * g.get('spread', .105)
        hit = sculpt.ray((x, .7, z0 + .02), (0, -1, 0))
        if hit is None:
            continue
        n = Vector(sculpt.normal(hit))
        base = Vector(hit) + n * .012
        R = n.to_track_quat('Z', 'Y').to_matrix()
        v, f, _ = ellipsoid_mesh(base, (.078, .058, .036), R, 22, 9)
        primitive('GoggleHousing', v, f, pal['Rubber'], 'Rubber', 'Head')
        v, f, _ = ellipsoid_mesh(base + n * .026, (.064, .046, .016), R, 22, 8)
        primitive('GoggleLens', v, f, pal['GoggleGlass'], 'Glass', 'Head')
        ring = [tuple(base + n * .022 + R @ Vector((.07 * math.cos(TAU * i / 24), .052 * math.sin(TAU * i / 24), 0))) for i in range(25)]
        v, f = tube_mesh(ring, .008, 6, caps=False)
        primitive('GoggleRim', v, f, pal['Metal'], 'Metal', 'Head')
        # Recessed brass fasteners distinguish the lens rim from the soft leather housing.
        for angle in (0.22 * math.pi, 0.78 * math.pi, 1.22 * math.pi, 1.78 * math.pi):
            pin = base + R @ Vector((.070 * math.cos(angle), .052 * math.sin(angle), .030))
            v, f, _ = ellipsoid_mesh(pin, (.005, .005, .0028), R, 8, 4)
            primitive('RimRivet', v, f, 'EDBC77', 'Metal', 'Head')
        hl = [tuple(base + n * .045 + R @ Vector((-.035 + .025 * t, .018 + .012 * t, 0))) for t in (0, .5, 1)]
        v, f = tube_mesh(hl, .004, 6)
        primitive('LensGlint', v, f, 'F4FAFF', 'Face', 'Head')
        v, f, _ = ellipsoid_mesh(Vector(hit) + n * .01 + R @ Vector((s * .09, 0, 0)), (.018, .02, .014), R, 12, 8)
        primitive('GoggleClip', v, f, pal['Orange'], 'Fabric', 'Head')


def whiskers(design: Design, sculpt: Sculpt):
    wk = getattr(design, 'whiskers', None)
    if wk:
        for s in (-1, 1):
            for k, (dz, ang) in enumerate(wk['rows']):
                root = sculpt.ray((s * wk['x'], .6, wk['z'] + dz), (0, -1, 0))
                if root is None:
                    continue
                d = Vector((s * math.cos(ang), .25, math.sin(ang))).normalized()
                pts = [tuple(Vector(root) + d * wk['length'] * t + Vector((0, 0, -.01 * t * t))) for t in (0, .35, .7, 1)]
                v, f = tube_mesh(pts, [.0025, .002, .0015, .0008], 5)
                primitive('Whisker', v, f, wk.get('color', 'F7F2EA'), 'Face', 'Head')
    if getattr(design, 'whisker_dots', False):
        for s in (-1, 1):
            for x, z in [(.05, 1.53), (.075, 1.52), (.065, 1.505), (.09, 1.535)]:
                hit = sculpt.ray((s * x, .6, z), (0, -1, 0))
                if hit is not None:
                    v, f, _ = ellipsoid_mesh(hit, (.006, .006, .006), seg=6, rings=4)
                    primitive('WhiskerDot', v, f, 'B98E5C', 'Organic', 'Head')


def suit_hardware(design: Design, sculpt: Sculpt):
    pal = design.palette
    plan = getattr(design, 'plan', {})
    top = plan.get('top', 'overall')
    J = design.joints_resolved
    if top in ('harness', 'none'):
        return
    pts = []
    zip_range = plan.get('zip', (.9, 1.27))
    for z in np.linspace(*zip_range, 9) if zip_range else ():
        hit = sculpt.ray((0, .6, z), (0, -1, 0))
        if hit is not None and hit[1] > .02:
            pts.append(tuple(hit + np.array([0, .003, 0])))
    if len(pts) > 3:
        v, f = tube_mesh(pts, (.006, .003), 6)
        primitive('Zipper', v, f, pal['Metal'], 'Metal', lambda p: {'Spine': np.clip((1.12 - p[:, 2]) / .2, 0, 1), 'Chest': 1 - np.clip((1.12 - p[:, 2]) / .2, 0, 1)})
        pull_anchor = Vector(pts[-2])
        v, f, _ = ellipsoid_mesh(pull_anchor + Vector((.012, .006, -.01)), (.011, .005, .02), seg=12, rings=6)
        primitive('ZipPull', v, f, pal['Metal'], 'Metal', 'Chest')
    # Racing stripes: white diagonal chest panels with an orange inner line,
    # following the actual suit surface (reference sheets).
    for s in (-1, 1) if plan.get('stripes', True) else ():
        for offset, half, colour, lift in [(.0, .03, 'White', .004), (-.043, .009, 'Orange', .005)]:
            line = []
            for z in np.linspace(1.235, .93, 10):
                x = s * (.085 + (z - .95) * .5 + offset)
                # start just in front of the chest so the arms never catch the ray
                hit = sculpt.ray((x, .145, z), (0, -1, 0), .3)
                if hit is not None and -.02 < hit[1] < .14:
                    line.append(tuple(hit + sculpt.normal(hit) * lift))
            if len(line) > 4:
                v, f = tube_mesh(line, (half, .004), 6)
                primitive('ChestStripe', v, f, pal[colour], 'Fabric', lambda p: {'Spine': np.clip((1.12 - p[:, 2]) / .2, 0, 1), 'Chest': 1 - np.clip((1.12 - p[:, 2]) / .2, 0, 1)})
    # Orange sleeve stripe on the outside of each arm, shoulder to cuff.
    for side in 'LR' if plan.get('sleeves', 'long' if top in ('overall', 'jersey') else 'none') == 'long' else ():
        s = SIGN[side]
        sh, el, ha = Vector(J['shoulder'][side]), Vector(J['elbow'][side]), Vector(J['hand'][side])
        wrist = ha - (ha - el).normalized() * .095
        line = []
        for t in np.linspace(.12, 1.0, 11):
            p = sh + (el - sh) * min(1, t * 2) if t <= .5 else el + (wrist - el) * ((t - .5) * 2)
            out = Vector((s, 0, .55)).normalized()
            hit = sculpt.ray(tuple(p + out * .4), tuple(-out), .5)
            if hit is not None:
                line.append(tuple(hit + sculpt.normal(hit) * .004))
        if len(line) > 5:
            v, f = tube_mesh(line, (.011, .004), 6)

            def arm_w(pts, side=side, el=el):
                d = np.linalg.norm(pts - np.array(el), axis=1)
                fore = (pts[:, 1] > el.y).astype(float)
                blend = np.clip(1 - d / .06, 0, 1) * .5
                w_fore = np.clip(fore * (1 - blend) + (1 - fore) * blend, 0, 1)
                return {'UpperArm.' + side: 1 - w_fore, 'Forearm.' + side: w_fore}
            primitive('SleeveStripe', v, f, pal['Orange'], 'Fabric', arm_w)
    hit = sculpt.ray((0, .6, .872), (0, -1, 0)) if top == 'overall' else None
    if hit is not None:
        v, f, _ = ellipsoid_mesh(Vector(hit) + Vector((0, .006, 0)), (.05, .014, .03), seg=20, rings=8)
        primitive('BeltBuckle', v, f, pal['Metal'], 'Metal', 'Pelvis')
        v, f, _ = ellipsoid_mesh(Vector(hit) + Vector((0, .019, 0)), (.03, .004, .016), seg=16, rings=6)
        primitive('BuckleInset', v, f, pal['Orange'], 'Fabric', 'Pelvis')


HEAD_FAMILY = {'Head', 'Ear.L', 'Ear.R', 'Jaw', 'Eye.L', 'Eye.R', 'Lid.L', 'Lid.R'}
HEAD_PIVOT = Vector((0, -.02, 1.40))


def head_point(design: Design, point, amount=1.0):
    k = 1.0 - amount * (1.0 - getattr(design, 'head_scale', 1.0))
    return tuple(HEAD_PIVOT + (Vector(point) - HEAD_PIVOT) * k)


def scale_head(design: Design):
    """Fit the whole head group to Lumo's size, blending through the neck."""
    if getattr(design, 'head_scale', 1.0) == 1.0:
        return
    for obj in PARTS:
        idx = {g.index for g in obj.vertex_groups if g.name in HEAD_FAMILY}
        if not idx:
            continue
        for v in obj.data.vertices:
            amount = sum(g.weight for g in v.groups if g.group in idx)
            if amount > 1e-4:
                v.co = Vector(head_point(design, v.co, min(1.0, amount)))
        obj.data.update()


def extras(design: Design, sculpt: Sculpt):
    for fn in design.extras:
        fn(design, sculpt, primitive, ellipsoid_mesh, tube_mesh)


# ------------------------------------------------------------------ materials
def finishes(micro=256):
    for name, (_names, rough, metal, sheen) in FINISHES.items():
        m = bpy.data.materials.new('Finish_' + name)
        m.use_nodes = True
        # Single-sided (glTF doubleSided=false): Godot culls back faces, so
        # hidden inner faces can never fight with the visible surface.
        m.use_backface_culling = True
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Roughness'].default_value = rough
        bsdf.inputs['Metallic'].default_value = metal
        bsdf.inputs['Sheen Weight'].default_value = sheen
        attr = m.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Palette'
        m.node_tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
        if name == 'Glass':
            bsdf.inputs['Coat Weight'].default_value = 1.0
    for family in ['Organic', 'Fabric']:
        v, u = np.mgrid[0:micro, 0:micro].astype(np.float32) / micro
        if family == 'Organic':
            height = .18 * np.sin(TAU * (37 * u + 1.1 * np.sin(TAU * 3 * v))) + .07 * np.sin(TAU * (59 * u + 5 * v))
        else:
            height = .10 * np.cos(TAU * 32 * u) + .10 * np.cos(TAU * 32 * v) + .05 * np.cos(TAU * 16 * u) * np.cos(TAU * 16 * v)
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * .5
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * .5
        normal = np.stack((-dx, -dy, np.ones_like(dx)), axis=-1)
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        rgba = np.ones((micro, micro, 4), dtype=np.float32); rgba[:, :, :3] = normal * .5 + .5
        image = bpy.data.images.new('LUMO_' + family + '_MicroNormal', width=micro, height=micro, alpha=False)
        image.colorspace_settings.name = 'Non-Color'
        image.pixels.foreach_set(rgba.ravel()); image.update(); image.pack()
        mat = bpy.data.materials['Finish_' + family]
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image; tex.extension = 'REPEAT'
        nm = mat.node_tree.nodes.new('ShaderNodeNormalMap'); nm.uv_map = 'UVMap'
        nm.inputs['Strength'].default_value = .45 if family == 'Organic' else .3
        mat.node_tree.links.new(tex.outputs['Color'], nm.inputs['Color'])
        mat.node_tree.links.new(nm.outputs['Normal'], mat.node_tree.nodes['Principled BSDF'].inputs['Normal'])


def spherical_uv(obj):
    data = obj.data
    uv = data.uv_layers.new(name='UVMap')
    co = np.array([v.co for v in data.vertices])
    center = np.array([0, -.02, 1.3])
    for poly in data.polygons:
        for li in poly.loop_indices:
            p = co[data.loops[li].vertex_index] - center
            uv.data[li].uv = (.5 + math.atan2(p[1], p[0]) / TAU * 4, .5 + p[2] * 4)


# ------------------------------------------------------------------ rig
def bone_spec(design: Design):
    specs = {
        'Root': ((0, 0, 0), (0, 0, .15), None),
        'Pelvis': ((0, -.07, .82), (0, -.07, .92), 'Root'),
        'Spine': ((0, -.07, .92), (0, -.075, 1.10), 'Pelvis'),
        'Chest': ((0, -.075, 1.10), (0, -.04, 1.29), 'Spine'),
        'Neck': ((0, -.04, 1.29), (0, -.015, 1.42), 'Chest'),
        'Head': ((0, -.015, 1.42), (0, -.015, 1.86), 'Neck'),
        'Tail': ((0, -.21, .89), (0, -.215, 1.03), 'Pelvis'),
    }
    J = design.joints_resolved
    for side, s in [('L', -1), ('R', 1)]:
        specs.update({
            'UpperArm.' + side: (J['shoulder'][side], J['elbow'][side], 'Chest'),
            'Forearm.' + side: (J['elbow'][side], J['hand'][side], 'UpperArm.' + side),
            'Hand.' + side: (J['hand'][side], (s * .16, .385, 1.055), 'Forearm.' + side),
            'Thigh.' + side: (J['hip'][side], J['knee'][side], 'Pelvis'),
            'Shin.' + side: (J['knee'][side], J['ankle'][side], 'Thigh.' + side),
            'Foot.' + side: (J['ankle'][side], (s * .18, .38, .80), 'Shin.' + side),
            'Ear.' + side: ((s * .17, -.025, 1.80), (s * .22, -.04, 2.05), 'Head'),
        })
    for name, (head, tail) in design.bones.items():
        if name in specs:
            specs[name] = (head, tail, specs[name][2])
    e = design.eyes
    for side in 'LR':
        c = Vector(e['center'][side])
        specs['Eye.' + side] = (tuple(c), tuple(c + Vector((0, .05, 0))), 'Head')
        # Upright like the Head bone: the blink rotation then stays well inside
        # +-180 degrees relative to the parent, so sampled quaternions never
        # take the long way round (the lid used to sweep in from below).
        specs['Lid.' + side] = (tuple(c), tuple(c + Vector((0, 0, .04))), 'Head')
    m = design.mouth
    if m:
        cx, cy, cz = m['center']
        specs['Jaw'] = ((0, cy - .16, cz + .02), (0, cy + .02, cz - .03), 'Head')
    else:
        specs['Jaw'] = ((0, .05, 1.50), (0, .2, 1.45), 'Head')
    if 'Jaw' in design.bones:
        specs['Jaw'] = (design.bones['Jaw'][0], design.bones['Jaw'][1], 'Head')
    for name in HEAD_FAMILY:
        head, tail, parent = specs[name]
        amount = 0.0 if name == 'Head' else 1.0
        specs[name] = (head_point(design, head, amount), head_point(design, tail, 1.0), parent)
    return specs


def make_rig(specs):
    data = bpy.data.armatures.new('DriverSkeleton')
    rig = bpy.data.objects.new('DriverRig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name in BODY_BONES + FACE_BONES:
        head, tail, parent = specs[name]
        b = data.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.roll = 0.0
        if parent:
            b.parent = data.edit_bones[parent]
        b.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.select_set(False)
    rig['coordinate_contract'] = 'Metres; +Y forward and Z up in Blender; -Z forward and Y up in Godot.'
    rig['seat_godot'] = [0, .69, .07]
    return rig


def solve_joint(start, end, la, lb, pole):
    delta = end - start
    dist = max(1e-6, min(delta.length, la + lb - 1e-6))
    axis = delta.normalized()
    along = (la * la - lb * lb + dist * dist) / (2 * dist)
    radius = math.sqrt(max(0, la * la - along * along))
    perp = Vector(pole) - axis * Vector(pole).dot(axis)
    if perp.length < 1e-6:
        perp = axis.cross(Vector((0, 0, 1)))
    return start + axis * along + perp.normalized() * radius


def pulse(t, center, width):
    x = (t - center) / width
    return max(0.0, 1 - x * x) ** 2


def clip_curves(clip, t):
    """Body intentions per clip at normalized time t (0..1, looping clips end at rest)."""
    steer = 0.0
    ramp = math.sin(math.pi * min(1, t / .25) / 2) if t < .25 else 1.0 if t < .75 else math.cos(math.pi * (t - .75) / .25 / 2)
    if clip == 'kart_steer_left':
        steer = ramp
    if clip == 'kart_steer_right':
        steer = -ramp
    c = {'steer': steer, 'breath': math.sin(TAU * t) * .006, 'blink': 0.0, 'jaw': .0, 'look': (0.0, 0.0),
         'head_pitch': 0.0, 'head_yaw': -steer * .12, 'head_roll': 0.0, 'lid_open': 0.0, 'hands': None, 'lift': 0.0}
    if clip in ('idle', 'kart_seated'):
        c['blink'] = pulse(t, .42, .045)
        c['look'] = (.25 * math.sin(TAU * t), .08 * math.sin(TAU * 2 * t))
        c['jaw'] = .08 + .06 * math.sin(TAU * t)
    elif clip in ('kart_steer_left', 'kart_steer_right'):
        c['look'] = (-steer * .55, 0.0)
        c['jaw'] = .1 * ramp
    elif clip == 'kart_jump':
        arc = math.sin(math.pi * t)
        c['lift'] = arc * .045
        c['lid_open'] = .6 * arc
        c['jaw'] = .7 * arc
        c['look'] = (0.0, .3 * arc)
    elif clip in ('celebrate', 'kart_celebrate'):
        up = math.sin(math.pi * t) ** 2
        c['celebrate'] = up
        c['jaw'] = .95 * up
        c['blink'] = .45 * up
        c['head_pitch'] = -.12 * up
        c['head_roll'] = .10 * math.sin(TAU * 2 * t) * up
        c['look'] = (.22 * math.sin(TAU * t) * up, .14 * up)
    elif clip == 'kart_hit':
        jolt = math.sin(math.pi * min(1, t / .35)) if t < .35 else math.sin(math.pi * (1 - (t - .35) / .65) / 2) ** 2
        c['head_pitch'] = -.22 * jolt
        c['head_roll'] = .18 * math.sin(TAU * 1.5 * t) * jolt
        c['blink'] = .85 * jolt
        c['jaw'] = .9 * jolt
        c['lean_back'] = .03 * jolt
    elif clip == 'greeting_wave':
        up = math.sin(math.pi * t) ** 2
        c['wave'] = up
        c['wave_phase'] = math.sin(TAU * 3 * t)
        c['jaw'] = .55 * up
        c['head_roll'] = .08 * up
        c['look'] = (0.0, .1 * up)
    elif clip == 'agree_nod':
        c['head_pitch'] = .16 * math.sin(TAU * 2 * t) * math.sin(math.pi * t)
        c['blink'] = .3 * math.sin(math.pi * t)
        c['jaw'] = .25 * math.sin(math.pi * t)
    elif clip == 'point_portal':
        up = math.sin(math.pi * t) ** 2
        c['point'] = up
        c['look'] = (.35 * up, .05 * up)
        c['head_yaw'] = .14 * up
        c['jaw'] = .35 * up
    elif clip == 'card_play':
        up = math.sin(math.pi * t) ** 2
        c['card'] = up
        c['head_pitch'] = .14 * up
        c['look'] = (0.0, -.35 * up)
    return c


def posed_points(bones, clip, t):
    p = {n: [Vector(a), Vector(b)] for n, (a, b, _parent) in bones.items()}
    c = clip_curves(clip, t)
    steer = c['steer']
    if clip == 'idle':
        shift = Vector((0, 0, -.43 + c['breath']))
        for n in p:
            if n != 'Root':
                p[n] = [v + shift for v in p[n]]
        for side, s in [('L', -1), ('R', 1)]:
            hip = p['Thigh.' + side][0]
            ankle = Vector((s * .17, .005, .08))
            la = (Vector(bones['Thigh.' + side][1]) - Vector(bones['Thigh.' + side][0])).length
            lb = (Vector(bones['Shin.' + side][1]) - Vector(bones['Shin.' + side][0])).length
            knee = solve_joint(hip, ankle, la, lb, (s * .1, 1, 0))
            hand = Vector((s * (.33 + .006 * math.sin(TAU * t)), .018, .36))
            shoulder = p['UpperArm.' + side][0]
            la = (Vector(bones['UpperArm.' + side][1]) - Vector(bones['UpperArm.' + side][0])).length
            lb = (Vector(bones['Forearm.' + side][1]) - Vector(bones['Forearm.' + side][0])).length
            elbow = solve_joint(shoulder, hand, la, lb, (s, .2, -.1))
            p['Thigh.' + side] = [hip, knee]
            p['Shin.' + side] = [knee, ankle]
            p['Foot.' + side] = [ankle, ankle + Vector((0, .14, 0))]
            p['UpperArm.' + side] = [shoulder, elbow]
            p['Forearm.' + side] = [elbow, hand]
            p['Hand.' + side] = [hand, hand + Vector((0, .045, 0))]
    else:
        lean = Vector((-steer * .022, -c.get('lean_back', 0.0), c['breath'] + c['lift']))
        for n in ['Spine', 'Chest', 'Neck', 'Head', 'Ear.L', 'Ear.R'] + FACE_BONES:
            p[n] = [v + lean for v in p[n]]
        for side, s in [('L', -1), ('R', 1)]:
            shoulder = Vector(bones['UpperArm.' + side][0]) + lean
            hand = Vector(bones['Hand.' + side][0])
            if steer:
                axis = Vector((0, -math.cos(.45), math.sin(.45)))
                hand = Vector((0, .33, 1.035)) + Quaternion(axis, -steer * .4) @ (hand - Vector((0, .33, 1.035)))
            if 'celebrate' in c:
                beat = math.sin(TAU * 2 * t + (0 if side == 'L' else math.pi / 2))
                hand += Vector((s * (.11 + .06 * beat), -.20, .47 + .08 * beat)) * c['celebrate']
            if side == 'R' and 'wave' in c:
                hand += Vector((.16 + .05 * c['wave_phase'], -.24, .52)) * c['wave']
            if side == 'R' and 'point' in c:
                hand += Vector((.10, .22, .18)) * c['point']
            if side == 'R' and 'card' in c:
                hand += Vector((-.06, .20, -.10)) * c['card']
            la = (Vector(bones['UpperArm.' + side][1]) - Vector(bones['UpperArm.' + side][0])).length
            lb = (Vector(bones['Forearm.' + side][1]) - Vector(bones['Forearm.' + side][0])).length
            pole = Vector(bones['Forearm.' + side][0]) - Vector(bones['UpperArm.' + side][0])
            elbow = solve_joint(shoulder, hand, la, lb, pole)
            p['UpperArm.' + side] = [shoulder, elbow]
            p['Forearm.' + side] = [elbow, hand]
            p['Hand.' + side] = [hand, hand + Vector((0, .045, 0))]
    return p, c


def animate(rig, bones, lid_rest=2.6, max_eye_gaze=None, lid_shown=LID_SHOWN):
    global design_lid_rest
    design_lid_rest = lid_rest
    rig.animation_data_create()
    scene = bpy.context.scene
    scene.render.fps = 24
    rests = {n: b.matrix_local.copy() for n, b in rig.data.bones.items()}
    order = BODY_BONES + FACE_BONES
    report = {}
    for clip, length in CLIPS.items():
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        max_error = 0.0
        frames = list(range(1, length + 1, 3))
        if frames[-1] != length:
            frames.append(length)
        for frame in frames:
            scene.frame_set(frame)
            t = (frame - 1) / (length - 1)
            desired, c = posed_points(bones, clip, t)
            target = {}
            for name in BODY_BONES:
                if name == 'Root':
                    target[name] = rests[name]
                    continue
                h, tl = desired[name]
                rh, rt, _ = bones[name]
                delta = (Vector(rt) - Vector(rh)).rotation_difference(tl - h)
                target[name] = Matrix.Translation(h) @ delta.to_matrix().to_4x4() @ Matrix.Translation(-Vector(rh)) @ rests[name]
            # head: steering yaw, nod pitch and roll about the neck joint
            pivot = Vector(bones['Head'][0]) + (desired['Head'][0] - Vector(bones['Head'][0]))
            rot = (Matrix.Rotation(c['head_yaw'], 4, 'Z') @ Matrix.Rotation(c['head_pitch'], 4, 'X') @ Matrix.Rotation(c['head_roll'], 4, 'Y'))
            target['Head'] = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ target['Head']
            head_delta = target['Head'] @ rests['Head'].inverted()
            steer = c['steer']
            for side, s in [('L', -1), ('R', 1)]:
                ear = 'Ear.' + side
                wiggle = Matrix.Rotation(s * .05 * math.sin(TAU * t + .3) + steer * .05 - c['jaw'] * .0, 4, 'Y')
                eh = Vector(bones[ear][0])
                target[ear] = head_delta @ Matrix.Translation(eh) @ wiggle @ Matrix.Translation(-eh) @ rests[ear]
                yaw, pitch = c['look']
                eye = rests['Eye.' + side]
                eye_yaw, eye_pitch = -yaw*.35, pitch*.35
                if max_eye_gaze is not None:
                    eye_yaw = max(-max_eye_gaze, min(max_eye_gaze, eye_yaw))
                    eye_pitch = max(-max_eye_gaze, min(max_eye_gaze, eye_pitch))
                target['Eye.' + side] = head_delta @ eye @ Matrix.Rotation(eye_yaw, 4, 'Z') @ Matrix.Rotation(eye_pitch, 4, 'X')
                close = min(1.0, c['blink'])
                lid_angle = design_lid_rest * close - .25 * c.get('lid_open', 0.0)
                grow = 1.0 + (lid_shown / LID_HIDDEN - 1.0) * smooth(close / .25)
                target['Lid.' + side] = head_delta @ rests['Lid.' + side] @ Matrix.Rotation(-lid_angle, 4, 'X') @ Matrix.Scale(grow, 4)
            target['Jaw'] = head_delta @ rests['Jaw'] @ Matrix.Rotation(-.22 * c['jaw'], 4, 'X')
            tail_h = Vector(bones['Tail'][0])
            sway = Matrix.Rotation(.12 * math.sin(TAU * t) + steer * .15, 4, 'Z') @ Matrix.Rotation(.05 * math.cos(TAU * t), 4, 'X')
            target['Tail'] = target['Pelvis'] @ rests['Pelvis'].inverted() @ Matrix.Translation(tail_h) @ sway @ Matrix.Translation(-tail_h) @ rests['Tail']
            for name in order:
                pb = rig.pose.bones[name]
                pb.rotation_mode = 'QUATERNION'
                parent = bones[name][2]
                if parent:
                    pb.matrix_basis = rests[name].inverted() @ rests[parent] @ target[parent].inverted() @ target[name]
                else:
                    pb.matrix_basis = rests[name].inverted() @ target[name]
                pb.keyframe_insert('location', frame=frame, group=name)
                pb.keyframe_insert('rotation_quaternion', frame=frame, group=name)
                pb.keyframe_insert('scale', frame=frame, group=name)
            bpy.context.view_layer.update()
            if clip in ('kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump'):
                for side in 'LR':
                    actual = rig.pose.bones['Hand.' + side].matrix.translation
                    max_error = max(max_error, (actual - desired['Hand.' + side][0]).length)
        for fc in action_fcurves(action):
            for key in fc.keyframe_points:
                key.interpolation = 'BEZIER' if clip in ('idle', 'kart_seated') else 'LINEAR'
        action.use_fake_user = True
        report[clip] = {'frames': length, 'fps': 24, 'duration_s': (length - 1) / 24, 'sampled_max_hand_origin_error_m': max_error}
    rig.animation_data.action = bpy.data.actions['kart_seated']
    scene.frame_set(1)
    scene.frame_start = 1
    scene.frame_end = 72
    return report


def action_fcurves(action):
    if hasattr(action, 'fcurves') and len(getattr(action, 'fcurves', [])):
        return list(action.fcurves)
    curves = []
    for layer in getattr(action, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    return curves


def make_markers(rig):
    for name, bone_name in [('Grip_L', 'Hand.L'), ('Grip_R', 'Hand.R'), ('Foot_L', 'Foot.L'), ('Foot_R', 'Foot.R'), ('HeadAnchor', 'Head'), ('NeckAnchor', 'Head')]:
        obj = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(obj)
        obj.empty_display_size = .025
        obj.parent = rig
        obj.parent_type = 'BONE'
        obj.parent_bone = bone_name
        obj.location = (0, -rig.data.bones[bone_name].length, 0)
    seat = bpy.data.objects.new('SeatAnchor', None)
    bpy.context.collection.objects.link(seat)
    seat.parent = rig
    seat.location = (0, -.07, .69)


# ------------------------------------------------------------------ assemble + export
def join_parts(rig):
    bpy.ops.object.select_all(action='DESELECT')
    for p in PARTS:
        p.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'DriverMesh'
    obj.data.name = 'DriverSurface'
    # merge material slots of the same finish
    slots = [m.name for m in obj.data.materials]
    unique = []
    for name in slots:
        if name not in unique:
            unique.append(name)
    remap = [unique.index(n) for n in slots]
    idx = [remap[p.material_index] for p in obj.data.polygons]
    obj.data.materials.clear()
    for n in unique:
        obj.data.materials.append(bpy.data.materials[n])
    for p, i in zip(obj.data.polygons, idx):
        p.material_index = i
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    bm.to_mesh(obj.data); bm.free()
    spherical_uv(obj)
    obj.parent = rig
    mod = obj.modifiers.new('NormalizedSkin', 'ARMATURE')
    mod.object = rig
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def measured(obj):
    obj.data.calc_loop_triangles()
    skip = {obj.vertex_groups['LODBody'].index} if 'LODBody' in obj.vertex_groups else set()
    groups = [[g for g in v.groups if g.group not in skip] for v in obj.data.vertices]
    sums = [sum(g.weight for g in gs) for gs in groups]
    return {'vertices': len(obj.data.vertices), 'triangles': len(obj.data.loop_triangles), 'materials': len(obj.data.materials),
            'max_weight_sum_error': max(abs(w - 1) for w in sums), 'max_influences': max(len(gs) for gs in groups),
            'dimensions_blender_m': [round(x, 4) for x in obj.dimensions]}


def limit_influences(obj):
    skip = {obj.vertex_groups['LODBody'].index} if 'LODBody' in obj.vertex_groups else set()
    for v in obj.data.vertices:
        # copy (index, weight) first: removing invalidates the v.groups items
        groups = sorted([(g.group, g.weight) for g in v.groups if g.group not in skip], key=lambda g: -g[1])
        for gi, _w in groups[4:]:
            obj.vertex_groups[gi].remove([v.index])
        keep = groups[:4]
        total = sum(w for _gi, w in keep)
        for gi, w in keep:
            obj.vertex_groups[gi].add([v.index], w / total, 'REPLACE')


def export_lods(obj, rig, outdir, ratios=(1.0, .5, .25)):
    outdir.mkdir(parents=True, exist_ok=True)
    results = {}
    for level, ratio in enumerate(ratios):
        if level == 0:
            target = obj
        else:
            target = obj.copy(); target.data = obj.data.copy(); bpy.context.collection.objects.link(target)
            target.name = 'DriverMesh_LOD%d' % level
            # Only the sculpted body is reduced; eyes, lids, mouth and goggles
            # keep their authored rings so the face stays readable at distance.
            bpy.ops.object.select_all(action='DESELECT')
            target.select_set(True)
            bpy.context.view_layer.objects.active = target
            target.vertex_groups.active_index = target.vertex_groups['LODBody'].index
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='DESELECT')
            bpy.ops.object.vertex_group_select()
            bpy.ops.mesh.decimate(ratio=ratio)
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.quads_convert_to_tris()
            bpy.ops.object.mode_set(mode='OBJECT')
            limit_influences(target)
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True); target.select_set(True)
        for ch in rig.children:
            if ch.type == 'EMPTY':
                ch.select_set(True)
        filename = 'driver.glb' if level == 0 else 'driver_lod%d.glb' % level
        bpy.context.view_layer.objects.active = rig
        bpy.ops.export_scene.gltf(filepath=str(outdir / filename), export_format='GLB', use_selection=True, export_yup=True,
                                  export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                                  export_skins=True, export_all_influences=False, export_apply=False, export_extras=True,
                                  export_def_bones=False, export_materials='EXPORT', export_cameras=False, export_lights=False,
                                  export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True)
        results['lod%d' % level] = measured(target)
        data = (outdir / filename).read_bytes()
        results['lod%d' % level].update({'file': str((outdir / filename).relative_to(ROOT)), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        if level:
            bpy.data.objects.remove(target, do_unlink=True)
    return results


# ------------------------------------------------------------------ review renders
def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def review(species, rig, outdir, size=640, samples=12, clip='kart_seated', frame=18, views=None):
    outdir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.render.threads_mode = 'FIXED'; scene.render.threads = 3
    scene.view_settings.view_transform = 'Standard'
    scene.world = scene.world or bpy.data.worlds.new('World')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.75, .8, .88, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .6
    if 'Key' not in bpy.data.objects:
        for name, loc, power, color, sz in [('Key', (-2.5, 4, 4.5), 500, (1, .9, .8), 3), ('Fill', (3.5, 2.5, 2.5), 260, (.75, .85, 1), 3), ('Rim', (1, -3.5, 3.5), 500, (.8, .88, 1), 2)]:
            ld = bpy.data.lights.new(name, 'AREA'); ld.energy = power; ld.color = color; ld.size = sz
            ob = bpy.data.objects.new(name, ld); bpy.context.collection.objects.link(ob); ob.location = loc; look_at(ob, (0, 0, 1.3))
        cam = bpy.data.objects.new('ReviewCamera', bpy.data.cameras.new('ReviewCamera')); bpy.context.collection.objects.link(cam)
    cam = bpy.data.objects['ReviewCamera']
    scene.camera = cam
    cam.data.type = 'ORTHO'
    rig.animation_data.action = bpy.data.actions[clip]
    scene.frame_set(frame)
    views = views or {'front': ((0, 5, 1.45), (0, 0, 1.45), 1.75), 'side': ((5, 0, 1.45), (0, 0, 1.45), 1.75),
                      'three_quarter': ((3.2, 4.2, 2.1), (0, 0, 1.42), 1.75), 'face': ((1.4, 4.6, 1.75), (0, 0, 1.64), .9)}
    scene.render.resolution_x = size; scene.render.resolution_y = size
    out = {}
    for name, (pos, target, ortho) in views.items():
        cam.location = pos; look_at(cam, target); cam.data.ortho_scale = ortho
        for mode in (['color', 'silhouette'] if name in ('front', 'side') else ['color']):
            scene.render.film_transparent = mode == 'silhouette'
            scene.cycles.samples = 1 if mode == 'silhouette' else samples
            scene.cycles.use_denoising = mode != 'silhouette'
            path = outdir / ('%s_%s_%s.png' % (species, name, mode))
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            out[name + '_' + mode] = str(path)
    return out


# ------------------------------------------------------------------ main
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--species', default='lion')
    parser.add_argument('--review', default='')
    parser.add_argument('--review-size', type=int, default=640)
    parser.add_argument('--no-export', action='store_true')
    parser.add_argument('--voxel', type=float, default=.0045)
    parser.add_argument('--tris', type=int, default=19000)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t0 = time.time()
    species = args.species
    design = Design(species)
    design.palette.update(SP.PALETTE_COMMON)
    SP.SPECIES[species](design)
    sculpt = Sculpt(design, args.voxel)
    print('sculpt field', sculpt.field.shape, round(time.time() - t0, 1), 's')
    finishes()
    build_body(design, sculpt, args.tris)
    eyes(design, sculpt)
    brows(design, sculpt)
    mouth_parts(design, sculpt)
    goggles(design, sculpt)
    whiskers(design, sculpt)
    suit_hardware(design, sculpt)
    extras(design, sculpt)
    scale_head(design)
    bones = bone_spec(design)
    rig = make_rig(bones)
    obj = join_parts(rig)
    report = {'species': species, 'bones': BODY_BONES + FACE_BONES}
    report['animations'] = animate(rig, bones, design.eyes.get('lid_rest', 2.6))
    for name in ('Eye.L', 'Lid.L', 'Jaw', 'Head'):
        print('bone axes', name, [tuple(round(x, 3) for x in col) for col in rig.data.bones[name].matrix_local.to_3x3().col])
    make_markers(rig)
    if not args.no_export:
        report['lods'] = export_lods(obj, rig, ROOT / 'assets/kart/production/drivers' / species)
        blends = ROOT / 'art/lumo_kart/blender/drivers'
        blends.mkdir(parents=True, exist_ok=True)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(blends / (species + '.blend')), compress=True)
    else:
        report['lods'] = {'lod0': measured(obj)}
    if args.review:
        report['review'] = review(species, rig, Path(args.review), args.review_size)
    report['build_seconds'] = round(time.time() - t0, 1)
    report['authoring'] = 'Local Blender Python: one signed-distance body (suit, fur, head, ears, tail), sparse surface nets, decimation, per-vertex colours and weights; separate eye, lid and jaw parts on their own bones. No downloads, no generators.'
    if not args.no_export:
        ev = ROOT / 'evidence/lumo_kart_art/drivers' / species
        ev.mkdir(parents=True, exist_ok=True)
        # review renders live outside the repository: keep their paths out of the evidence
        stored = {k: v for k, v in report.items() if k != 'review'}
        (ev / 'measurement.json').write_text(json.dumps(stored, indent=2), encoding='utf-8')
    print('ANIMAL_BUILD_COMPLETE', json.dumps({k: report[k] for k in ('species', 'lods', 'build_seconds')}))


if __name__ == '__main__':
    main()
