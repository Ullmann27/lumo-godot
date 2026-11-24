#!/usr/bin/env python3
"""Lumo Kart: gerendertes 3D-UI-Kit (Platten, Knöpfe, Icons, Platz-Abzeichen).

Baut jedes Teil prozedural in Blender (bpy als Python-Modul), rendert es mit Cycles (CPU)
auf transparentem Grund und schreibt WebP mit Alpha nach assets/kart/ui3d/. Keine fremden
Meshes, Texturen oder Downloads; einzige Fremddatei ist die Projektschrift Nunito Black
(assets/fonts, SIL OFL 1.1) für die Ziffern der Platz-Abzeichen.

Aufruf (im Repo-Wurzelverzeichnis):
  /home/user/tools/bpyenv/bin/python tools/art/render_ui_kit.py
  ... --only icon_flag,plate_nav          nur einzelne Teile neu rendern
  ... --contact-sheet /pfad/sheet.png     Übersicht auf dunklem Grund (nicht ins Repo)
  ... --stretch-test /pfad/stretch.png    9-Slice-Dehnprobe (nicht ins Repo)
  ... --list                              Namen aller Teile

Alle Maße in Texturpixeln. Die Texturen sind für die doppelte Auflösung der
720x1280-Grundfläche gebaut (design_scale 2 im Manifest).
"""
import argparse
import json
import math
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import bpy  # zuerst: stellt addon_utils und bmesh bereit
import addon_utils  # noqa: E402
import bmesh  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets/kart/ui3d"
FONT_PATH = REPO / "assets/fonts/Nunito-Black.ttf"
PX = 0.01  # 1 Texturpixel = 0.01 Blender-Einheiten
SAMPLES = 64
THREADS = 3

CYAN, AMBER, VIOLET, TEAL = "21ccff", "ffa91f", "8a5cff", "1fb8d8"
MAGENTA, NAVY, GOLD, WHITE = "ff4fc8", "08133a", "ffd568", "ffffff"

ROOT = None  # Wurzel-Empty des aktuellen Teils
CAM = None


# ---------------------------------------------------------------- Farben
def srgb(c):
    if isinstance(c, str):
        c = c.lstrip("#")
        return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(c[:3])


def mixc(a, b, t):
    a, b = srgb(a), srgb(b)
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def lin(c):
    out = []
    for v in srgb(c):
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


# ---------------------------------------------------------------- Szene
def stage(w, h, samples=None, light_scale=1.0):
    """Leere Szene mit senkrechter Orthokamera und festem Licht-Aufbau (Licht von oben links)."""
    global ROOT, CAM
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable("cycles", default_set=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples or SAMPLES
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.seed = 7
    sc.cycles.max_bounces = 6
    sc.cycles.transparent_max_bounces = 8
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        sc.cycles.use_denoising = False
    sc.render.threads_mode = "FIXED"
    sc.render.threads = THREADS
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "16"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"

    world = bpy.data.worlds.new("UiWorld")
    sc.world = world
    nt = world.node_tree
    bg = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = -1.0, 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.010, 0.012, 0.030, 1)
    els[1].position, els[1].color = 1.0, (0.85, 0.93, 1.0, 1)
    for pos, col in ((0.42, (0.030, 0.045, 0.11, 1)), (0.62, (0.16, 0.24, 0.46, 1)), (0.80, (0.55, 0.68, 0.95, 1))):
        e = els.new(pos)
        e.color = col
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.9 * light_scale

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(w, h) * PX
    cam_data.clip_start, cam_data.clip_end = 0.1, 100.0
    CAM = bpy.data.objects.new("Cam", cam_data)
    CAM.location = (0, 0, 20)
    sc.collection.objects.link(CAM)
    sc.camera = CAM

    span = max(w, h) * PX / 2.56  # Lichtaufbau wächst mit der Bildgröße
    area("Key", (-2.2, 4.6, 4.4), (6.0, 3.0), 520 * light_scale, (1.0, 0.98, 0.95), span)
    area("Strip", (0.6, 6.5, 1.7), (9.0, 0.7), 260 * light_scale, (1.0, 1.0, 1.0), span)
    area("Fill", (4.5, -2.5, 5.0), (4.0, 4.0), 90 * light_scale, (0.70, 0.82, 1.0), span)
    front = area("Front", (0.0, 0.3, 9.0), (7.0, 7.0), 170 * light_scale, (1.0, 1.0, 1.0), span)
    front.visible_glossy = False

    ROOT = bpy.data.objects.new("Root", None)
    sc.collection.objects.link(ROOT)
    return sc


def area(name, loc, size, energy, color, span=1.0):
    light = bpy.data.lights.new(name, "AREA")
    light.shape = "RECTANGLE"
    light.size, light.size_y = size[0] * span, size[1] * span
    light.energy = energy * span * span
    light.color = color
    ob = bpy.data.objects.new(name, light)
    ob.location = [v * span for v in loc]
    # auf den Ursprung ausrichten
    direction = -ob.location.normalized()
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def link(ob, parent=None):
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent or ROOT
    return ob


def group(name, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.location = (loc[0] * PX, loc[1] * PX, loc[2] * PX)
    ob.rotation_euler = [math.radians(v) for v in rot]
    ob.scale = (scale, scale, scale)
    return link(ob, parent)


def fit_camera(w, h, margin):
    """Kamera so setzen, dass alle Meshes mit `margin` Pixeln Rand ins Bild passen."""
    bpy.context.view_layer.update()
    xs, ys = [], []
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        mw = ob.matrix_world
        for v in ob.data.vertices:
            p = mw @ v.co
            xs.append(p.x)
            ys.append(p.y)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ex, ey = max(xs) - min(xs), max(ys) - min(ys)
    big = max(w, h)  # ortho_scale misst die längere Bildseite
    scale = max(ex * big / (w - 2 * margin), ey * big / (h - 2 * margin))
    CAM.location.x, CAM.location.y = cx, cy
    CAM.data.ortho_scale = scale


def render_rgba(w, h):
    sc = bpy.context.scene
    with tempfile.TemporaryDirectory() as tmp:
        sc.render.filepath = str(Path(tmp) / "r.png")
        bpy.ops.render.render(write_still=True)
        im = Image.open(sc.render.filepath)
        arr = np.asarray(im).astype(np.float32)
    arr = arr / (65535.0 if arr.max() > 255 else 255.0)
    assert arr.shape == (h, w, 4), arr.shape
    return arr


# ---------------------------------------------------------------- Materialien
class Nodes:
    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.nt = self.mat.node_tree
        self.bsdf = next(n for n in self.nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
        self._coord = None

    def new(self, kind, **props):
        node = self.nt.nodes.new(kind)
        for key, value in props.items():
            setattr(node, key, value)
        return node

    def put(self, sock, value):
        if isinstance(value, bpy.types.NodeSocket):
            self.nt.links.new(value, sock)
        else:
            sock.default_value = value

    def math(self, op, a, b=None):
        node = self.new("ShaderNodeMath", operation=op)
        self.put(node.inputs[0], a)
        if b is not None:
            self.put(node.inputs[1], b)
        return node.outputs[0]

    def mix(self, fac, a, b):
        node = self.new("ShaderNodeMix", data_type="RGBA")
        self.put(node.inputs[0], fac)
        self.put(node.inputs[6], a)
        self.put(node.inputs[7], b)
        return node.outputs[2]

    def coord_px(self):
        """Koordinaten im Raum des Wurzel-Empties, in Pixeln (x, y, z)."""
        if self._coord is None:
            tc = self.new("ShaderNodeTexCoord")
            tc.object = ROOT
            sep = self.new("ShaderNodeSeparateXYZ")
            self.nt.links.new(tc.outputs["Object"], sep.inputs[0])
            self._coord = tuple(self.math("MULTIPLY", sep.outputs[i], 1.0 / PX) for i in range(3))
        return self._coord

    def ramp(self, fac, stops):
        node = self.new("ShaderNodeValToRGB")
        els = node.color_ramp.elements
        els[0].position, els[0].color = stops[0][0], lin(stops[0][1])
        els[1].position, els[1].color = stops[-1][0], lin(stops[-1][1])
        for pos, col in stops[1:-1]:
            e = els.new(pos)
            e.color = lin(col)
        self.put(node.inputs["Fac"], fac)
        return node.outputs["Color"]

    def finish(self, color, rough=0.28, emit=0.3, metallic=0.0, coat=0.5, alpha=1.0, emit_color=None, side=None):
        b = self.bsdf.inputs
        if side is not None:
            # Flächen, die von der Kamera wegkippen (Seitenwände, Fasen), bekommen einen tieferen Ton
            lw = self.new("ShaderNodeLayerWeight")
            lw.inputs["Blend"].default_value = 0.5
            color = self.mix(self.math("POWER", lw.outputs["Facing"], 1.6), color, lin(side))
        self.put(b["Base Color"], color)
        self.put(b["Emission Color"], emit_color if emit_color is not None else color)
        b["Emission Strength"].default_value = emit
        b["Roughness"].default_value = rough
        b["Metallic"].default_value = metallic
        b["Coat Weight"].default_value = coat
        b["Coat Roughness"].default_value = 0.06
        b["Alpha"].default_value = alpha
        return self.mat


def solid(name, color, **kw):
    return Nodes(name).finish(lin(color), **kw)


def grad(name, stops, lo, hi, checker=None, **kw):
    """Senkrechter Verlauf (y im Raum des Wurzel-Empties) zwischen lo und hi Pixeln;
    optional ein Schachmuster, das von einer Ecke aus verblasst."""
    n = Nodes(name)
    x, y, _z = n.coord_px()
    value = y
    mr = n.new("ShaderNodeMapRange")
    n.put(mr.inputs["Value"], value)
    mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = lo, hi
    color = n.ramp(mr.outputs["Result"], stops)
    if checker:
        cell = checker["cell"]
        fx = n.math("FLOOR", n.math("DIVIDE", n.math("ADD", x, 0.01), cell))
        fy = n.math("FLOOR", n.math("DIVIDE", n.math("ADD", y, 0.01), cell))
        parity = n.math("FLOORED_MODULO", n.math("ADD", fx, fy), 2.0)
        dx = n.math("SUBTRACT", x, checker["corner"][0])
        dy = n.math("SUBTRACT", y, checker["corner"][1])
        dist = n.math("SQRT", n.math("ADD", n.math("MULTIPLY", dx, dx), n.math("MULTIPLY", dy, dy)))
        fade = n.new("ShaderNodeClamp")
        n.put(fade.inputs[0], n.math("SUBTRACT", 1.0, n.math("DIVIDE", dist, checker["radius"])))
        fade = n.math("POWER", fade.outputs[0], 1.4)
        fac = n.math("MULTIPLY", n.math("MULTIPLY", parity, fade), checker["strength"])
        color = n.mix(fac, color, lin(checker["color"]))
    return n.finish(color, **kw)


def metal(name, top, mid, bottom, lo, hi, rough=0.2, emit=0.28):
    return grad(name, [(0.0, bottom), (0.5, mid), (1.0, top)], lo, hi, metallic=0.75, rough=rough, emit=emit, coat=0.4)


# ---------------------------------------------------------------- Umrisse
def rect_path(w, h, bl, br, tr, tl, cx=0.0, cy=0.0, seg=8):
    """Rechteck mit je Ecke ('r', Radius) rund oder ('c', Größe) abgeschrägt; gegen den Uhrzeigersinn."""
    pts = []
    for sx, sy, a0, (kind, s) in ((-1, -1, 180, bl), (1, -1, 270, br), (1, 1, 0, tr), (-1, 1, 90, tl)):
        if s <= 0:
            pts.append((cx + sx * w / 2, cy + sy * h / 2))
            continue
        ox, oy = cx + sx * (w / 2 - s), cy + sy * (h / 2 - s)
        steps = seg if kind == "r" else 1
        for i in range(steps + 1):
            a = math.radians(a0 + 90.0 * i / steps)
            pts.append((ox + s * math.cos(a), oy + s * math.sin(a)))
    return pts


def inset_corner(corner, t):
    kind, s = corner
    return (kind, max(0.0, s - t if kind == "r" else s - t * 0.586))


def star_pts(n, outer, inner, rot=90.0, cx=0.0, cy=0.0):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + 180.0 * i / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def arc_pts(cx, cy, r, a0, a1, n=24):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def leaf_pts(length, width, n=10):
    """Spitzes Blatt entlang +x, Fuß im Ursprung."""
    top = [(length * t, width / 2 * math.sin(math.pi * t) ** 0.8) for t in (i / n for i in range(n + 1))]
    return top + [(x, -y) for x, y in reversed(top[1:-1])]


class Mask:
    """Zeichenfläche für Umrisse (Pillow), zentrierte Pixelkoordinaten mit y nach oben.
    Vereinigung/Differenz von Formen wird gezeichnet und danach als Kontur abgetastet."""

    def __init__(self, size=320, ss=4):
        self.size, self.ss = size, ss
        self.im = Image.new("L", (size * ss, size * ss), 0)
        self.d = ImageDraw.Draw(self.im)

    def _p(self, x, y):
        return ((x + self.size / 2) * self.ss, (self.size / 2 - y) * self.ss)

    def circle(self, x, y, r, fill=255):
        (cx, cy), rr = self._p(x, y), r * self.ss
        self.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=fill)
        return self

    def poly(self, pts, fill=255):
        self.d.polygon([self._p(x, y) for x, y in pts], fill=fill)
        return self

    def rrect(self, x0, y0, x1, y1, r, fill=255):
        (ax, ay), (bx, by) = self._p(x0, y1), self._p(x1, y0)
        self.d.rounded_rectangle((ax, ay, bx, by), radius=r * self.ss, fill=fill)
        return self

    def line(self, pts, width, fill=255):
        self.d.line([self._p(x, y) for x, y in pts], fill=fill, width=int(width * self.ss), joint="curve")
        for x, y in (pts[0], pts[-1]):
            self.circle(x, y, width / 2 - 0.2, fill)
        return self

    def rotate(self, deg):
        self.im = self.im.rotate(deg, resample=Image.BICUBIC)
        self.d = ImageDraw.Draw(self.im)
        return self

    def loops(self, smooth=1.0, step=2):
        return mask_loops(np.asarray(self.im) > 127, self.ss, self.size, smooth, step)


def mask_loops(mask, ss, size, smooth=1.0, step=2):
    """Randkanten der Maske zu geschlossenen Schleifen verketten, glätten, ausdünnen."""
    b = np.pad(mask.astype(bool), 1)
    inside = b[1:-1, 1:-1]
    edges = {}

    def add(sx, sy, ex, ey):
        for a, c in zip(zip(sx.tolist(), sy.tolist()), zip(ex.tolist(), ey.tolist())):
            edges.setdefault(a, []).append(c)

    r, c = np.nonzero(inside & ~b[:-2, 1:-1])
    add(c, r, c + 1, r)
    r, c = np.nonzero(inside & ~b[1:-1, 2:])
    add(c + 1, r, c + 1, r + 1)
    r, c = np.nonzero(inside & ~b[2:, 1:-1])
    add(c + 1, r + 1, c, r + 1)
    r, c = np.nonzero(inside & ~b[1:-1, :-2])
    add(c, r + 1, c, r)
    loops = []
    sigma = max(0.5, smooth * ss)
    radius = int(3 * sigma + 0.5)
    kernel = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    kernel /= kernel.sum()
    while edges:
        start = next(iter(edges))
        pts, cur = [start], start
        while True:
            outs = edges[cur]
            nxt = outs.pop()
            if not outs:
                del edges[cur]
            if nxt == start:
                break
            pts.append(nxt)
            cur = nxt
        if len(pts) < 16:
            continue
        p = np.asarray(pts, dtype=np.float64)
        p = (p + np.roll(p, -1, axis=0)) / 2
        if len(p) > 2 * radius + 1:
            wrapped = np.concatenate([p[-radius:], p, p[:radius]])
            p = np.stack([np.convolve(wrapped[:, i], kernel, mode="valid") for i in (0, 1)], axis=1)
        p = thin_loop(p[::step], 0.1 * ss)
        loops.append([(x / ss - size / 2, size / 2 - y / ss) for x, y in p])
    return loops


def thin_loop(p, eps):
    """Douglas-Peucker auf geschlossener Schleife: gerade Strecken bekommen wenige Punkte.
    (Sehr dichte Punktfolgen lassen Blenders Flächenfüllung für 2D-Kurven scheitern.)"""
    n = len(p)
    if n < 8:
        return p
    half = n // 2
    keep = np.zeros(n + 1, dtype=bool)
    q = np.concatenate([p, p[:1]])
    keep[[0, half, n]] = True
    stack = [(0, half), (half, n)]
    while stack:
        a, b = stack.pop()
        if b <= a + 1:
            continue
        seg = q[b] - q[a]
        rel = q[a + 1 : b] - q[a]
        length = float(np.hypot(seg[0], seg[1]))
        if length < 1e-9:
            dist = np.hypot(rel[:, 0], rel[:, 1])
        else:
            dist = np.abs(seg[0] * rel[:, 1] - seg[1] * rel[:, 0]) / length
        i = int(dist.argmax())
        if dist[i] > eps:
            keep[a + 1 + i] = True
            stack.append((a, a + 1 + i))
            stack.append((a + 1 + i, b))
    return q[:-1][keep[:-1]]


# ---------------------------------------------------------------- Geometrie
def finish_mesh(me, name, mat, angle=38.0, weighted=True, parent=None):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.set_sharp_from_angle(angle=math.radians(angle))
    me.materials.clear()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    link(ob, parent)
    if weighted:
        mod = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 100
    return ob


def curve_mesh(curve, name):
    tmp = bpy.data.objects.new(name + "_curve", curve)
    bpy.context.scene.collection.objects.link(tmp)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(curve)
    return me


def shape(name, loops, z0, depth, bevel, mat, res=4, parent=None, angle=38.0):
    """Flächige Form (Schleifen in Pixeln, innere Schleifen = Löcher) mit Tiefe und runder Fase."""
    if loops and not isinstance(loops[0], list):
        loops = [loops]
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    for loop in loops:
        sp = cu.splines.new("POLY")
        sp.points.add(len(loop) - 1)
        for point, (x, y) in zip(sp.points, loop):
            point.co = (x * PX, y * PX, 0.0, 1.0)
        sp.use_cyclic_u = True
    bevel = min(bevel, depth / 2)
    cu.extrude = max(0.0, depth / 2 - bevel) * PX
    cu.bevel_depth = bevel * PX
    cu.bevel_resolution = res
    cu.offset = -bevel * PX
    ob = finish_mesh(curve_mesh(cu, name), name, mat, angle, parent=parent)
    ob.location.z = (z0 + depth / 2) * PX
    return ob


def text(name, body, size, z0, depth, bevel, mat, font, res=4, parent=None, grow=0.0):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.font = font
    cu.size = size * PX
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    cu.resolution_u = 16
    bevel = min(bevel, depth / 2)
    cu.extrude = max(0.0, depth / 2 - bevel) * PX
    cu.bevel_depth = bevel * PX
    cu.bevel_resolution = res
    cu.offset = (grow - bevel) * PX
    me = curve_mesh(cu, name)
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    ox, oy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for v in me.vertices:
        v.co.x -= ox
        v.co.y -= oy
    ob = finish_mesh(me, name, mat, 38.0, parent=parent)
    ob.location.z = (z0 + depth / 2) * PX
    return ob


def tube(name, pts, radius, mat, cyclic=False, res=5, parent=None):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for point, p in zip(sp.points, pts):
        z = p[2] if len(p) > 2 else 0.0
        point.co = (p[0] * PX, p[1] * PX, z * PX, 1.0)
    sp.use_cyclic_u = cyclic
    cu.bevel_depth = radius * PX
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    return finish_mesh(curve_mesh(cu, name), name, mat, 60.0, weighted=False, parent=parent)


def lathe(name, profile, mat, seg=56, parent=None, angle=40.0):
    """Drehkörper um die y-Achse aus (Radius, Höhe)-Punkten in Pixeln."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0.0, y * PX, 0.0))])
        else:
            rings.append([bm.verts.new((r * PX * math.cos(2 * math.pi * i / seg), y * PX, r * PX * math.sin(2 * math.pi * i / seg))) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return finish_mesh(me, name, mat, angle, weighted=False, parent=parent)


def box(name, size, loc, mat, bevel=5.0, parent=None, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0] * PX
        v.co.y *= size[1] * PX
        v.co.z *= size[2] * PX
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel * PX, segments=3, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = finish_mesh(me, name, mat, 50.0, parent=parent)
    ob.location = [v * PX for v in loc]
    ob.rotation_euler = [math.radians(v) for v in rot]
    return ob


def ball(name, radius, loc, mat, parent=None, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=radius * PX)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = finish_mesh(me, name, mat, 80.0, weighted=False, parent=parent)
    ob.location = [v * PX for v in loc]
    ob.scale = scale
    return ob


def smooth_path(pts, per=10):
    """Catmull-Rom durch die Punkte, `per` Zwischenpunkte je Abschnitt."""
    p = [np.asarray(q, dtype=np.float64) for q in pts]
    p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p[i]) + (-p[i - 1] + p[i + 1]) * t + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t + (-p[i - 1] + 3 * p[i] - 3 * p[i + 1] + p[i + 2]) * t**3))
    out.append(p[-2])
    return [tuple(q) for q in out]


# ---------------------------------------------------------------- Nachbearbeitung
def gblur(a, sigma):
    if sigma <= 0:
        return a.copy()
    r = int(3 * sigma + 0.5)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2).astype(np.float32)
    k /= k.sum()
    h, w = a.shape
    p = np.pad(a, ((r, r), (0, 0)))
    out = np.zeros_like(a)
    for i in range(2 * r + 1):
        out += k[i] * p[i : i + h]
    p = np.pad(out, ((0, 0), (r, r)))
    out = np.zeros_like(a)
    for i in range(2 * r + 1):
        out += k[i] * p[:, i : i + w]
    return out


def under(img, color, alpha):
    """Farbschicht mit eigener Deckkraft unter das Bild legen (gerades Alpha)."""
    a = img[..., 3]
    out_a = a + alpha * (1 - a)
    col = np.asarray(srgb(color), dtype=np.float32)
    rgb = (img[..., :3] * a[..., None] + col * (alpha * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    return np.dstack([rgb, out_a])


def edge_fade(h, w, width):
    """Fenster, das zum Bildrand hin sicher auf 0 fällt (transparente Ecken)."""
    y = np.minimum(np.arange(h), np.arange(h)[::-1]).astype(np.float32)
    x = np.minimum(np.arange(w), np.arange(w)[::-1]).astype(np.float32)
    fy = np.clip((y - 1.0) / width, 0, 1)
    fx = np.clip((x - 1.0) / width, 0, 1)
    f = np.minimum(fy[:, None], fx[None, :])
    return f * f * (3 - 2 * f)


def decorate(img, glow=None, inner=None, shadow=None):
    """Leuchten (außen und innen, vom Rand ausgehend) und weicher Schatten."""
    h, w = img.shape[:2]
    sil = (img[..., 3] > 0.5).astype(np.float32)
    window = edge_fade(h, w, 6.0)
    if inner:
        color, strength, sigma = inner
        band = np.clip(np.abs(sil - gblur(sil, 1.5)) * 2.4, 0, 1)
        g = np.clip(gblur(band, sigma) * strength * 3.0, 0, 1)
        col = np.asarray(srgb(color), dtype=np.float32)
        img[..., :3] = np.clip(img[..., :3] + col * g[..., None] * (1 - img[..., :3] * 0.5), 0, 1)
    if glow:
        color, strength, sigma = glow
        band = np.clip(np.abs(sil - gblur(sil, 1.5)) * 2.4, 0, 1)
        g = gblur(band, sigma) * 2.2 + gblur(band, sigma * 0.35) * 1.4
        img = under(img, color, np.clip(g * strength, 0, 1) * window)
    if shadow:
        offset, sigma, strength = shadow
        s = np.roll(sil, offset, axis=0)
        s[:offset] = 0
        img = under(img, "020716", np.clip(gblur(s, sigma) * strength, 0, 1) * window)
    return img


def linearize(img, margins):
    """Mittelbereich durch eine Ausgleichsgerade je Zeile/Spalte ersetzen: exakt (bi)linear und
    rauschfrei, damit 9-Slice-Dehnung unsichtbar bleibt. Gibt die größte Abweichung vom Render
    zurück (Maß dafür, ob Details im Dehnbereich lagen)."""
    left, top, right, bottom = margins
    h, w = img.shape[:2]
    before = img.copy()
    pm = img.astype(np.float64)
    pm[..., :3] *= pm[..., 3:4]

    def fit(block, axis):
        n = block.shape[axis]
        t = np.linspace(-0.5, 0.5, n)
        shape_t = [1, 1, 1]
        shape_t[axis] = n
        t = t.reshape(shape_t)
        mean = block.mean(axis=axis, keepdims=True)
        slope = ((block - mean) * t).sum(axis=axis, keepdims=True) / (t * t).sum()
        return mean + slope * t

    pm[:, left : w - right] = fit(pm[:, left : w - right], 1)
    pm[top : h - bottom] = fit(pm[top : h - bottom], 0)
    out = pm.copy()
    out[..., :3] = pm[..., :3] / np.maximum(pm[..., 3:4], 1e-6)
    out = np.clip(out, 0, 1).astype(np.float32)
    before[..., :3] *= before[..., 3:4]
    return out, float(np.abs(pm - before).max())


def save_webp(img, path):
    a = img[..., 3]
    img = img.copy()
    img[..., 3] = np.where(a < 1.5 / 255.0, 0.0, a)
    data = (np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(data, "RGBA").save(path, "WEBP", quality=90, method=6, alpha_quality=100)


# ---------------------------------------------------------------- Platten (9-Slice)
def plate_layers(w, h, spec):
    """Glasplatte: dunkle Wand (unten als Kante sichtbar), leuchtender Wulstrand, vertieftes Glasfeld."""
    pad_l, pad_t, pad_r, pad_b = spec["pad"]
    lip = spec.get("lip", 0)
    bw = w - pad_l - pad_r
    bh = h - pad_t - pad_b - lip
    cx = (pad_l - pad_r) / 2
    cy = h / 2 - pad_t - bh / 2
    corners = spec["corners"]  # bl, br, tr, tl
    rim = spec["rim"]
    depth = spec.get("depth", 10)
    rim_h = spec.get("rim_h", rim * 0.9)

    def path(inset, extra_h=0.0, dy=0.0):
        cs = [inset_corner(c, inset) for c in corners]
        return rect_path(bw - 2 * inset, bh - 2 * inset + extra_h, *cs, cx=cx, cy=cy + dy)

    hole = path(rim * 0.7)
    if lip:
        wall = solid("wall", spec["wall"], rough=0.35, emit=0.25, coat=0.3)
        shape("wall", [path(0.4, lip, -lip / 2), hole], 0, depth, 2.0, wall)
    rim_mat = solid("rim", spec["rim_color"], rough=0.14, emit=spec.get("rim_emit", 0.75), coat=1.0)
    shape("rim", [path(0), path(rim)], depth - 1, rim_h + 1, min(rim / 2 - 0.2, rim_h), rim_mat, res=5)
    if spec["face"] is None:  # reiner Neonrahmen, die Mitte bleibt durchsichtig
        return path(rim + 0.5)
    face_kw = dict(rough=spec.get("rough", 0.14), emit=spec.get("emit", 0.55), coat=1.0)
    top, bottom = spec["face"]
    lo, hi = cy - bh / 2, cy + bh / 2
    checker = None
    if spec.get("checker"):
        checker = dict(spec["checker"])
        checker["corner"] = (cx + bw / 2 - rim, cy + bh / 2 - rim)
    face = grad("face", [(0.0, bottom), (0.55, mixc(bottom, top, 0.62)), (1.0, top)], lo, hi, checker=checker, **face_kw)
    slab = spec.get("slab", 0)  # gewölbter Glaskörper: runde Kante der Fläche, fängt das Licht
    shape("face", path(rim - 0.6), depth - 6, 8 + 2 * slab, max(1.0, slab), face, res=6)
    line_z = depth + 2 + 2 * slab
    for inset, width, color, emit in spec.get("lines", []):
        line = solid("line", color, rough=0.2, emit=emit, coat=0.5)
        shape("line", [path(inset), path(inset + width)], line_z - 1.0, 2.0, min(width / 2 - 0.1, 0.8), line, res=2)
    return path(rim + 0.5)


def poly_mask(w, h, loop, ss=4):
    """Geglättete Maske (0..1) eines Umrisses in zentrierten Pixelkoordinaten."""
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([((x + w / 2) * ss, (h / 2 - y) * ss) for x, y in loop], fill=255)
    return np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0


def hero_spec(accent, face_top, face_bottom, rim_color, wall):
    return dict(
        kind="plate", size=(236, 240), nine=(110, 110, 110, 114), pad=(40, 38, 40, 40), lip=7,
        corners=(("r", 20), ("c", 38), ("r", 20), ("c", 38)), rim=6, rim_h=7, depth=12, slab=7, rim_emit=0.70,
        face=(face_top, face_bottom), rim_color=rim_color, wall=wall, alpha=0.95, emit=0.50,
        glow=(accent, 2.1, 12.0), inner=(mixc(accent, WHITE, 0.3), 0.14, 6.0),
    )


NAVY_FACE = ("10307e", "071241")
PLATES = {
    "plate_hero_amber": dict(hero_spec(AMBER, "ffb429", "a84808", "ffe9a8", "6e2f06"), use="Große Modus-Kachel (Rennen), 9-Slice"),
    "plate_hero_violet": dict(hero_spec(VIOLET, "7d57f2", "24107c", "d6c4ff", "1c0c62"), use="Große Modus-Kachel (Turniere), 9-Slice"),
    "plate_hero_teal": dict(hero_spec(TEAL, "22b6e4", "0b3d8c", "c2f4ff", "082e6a"), use="Große Modus-Kachel (Saison), 9-Slice"),
    "plate_hero_magenta": dict(hero_spec(MAGENTA, "f24fc4", "6c1484", "ffc9ee", "520f66"), use="Große Modus-Kachel (Event), 9-Slice"),
    "plate_feature_navy": dict(
        kind="plate", size=(184, 184), nine=(84, 84, 84, 84), pad=(24, 24, 24, 24), lip=0,
        corners=(("r", 14), ("c", 30), ("r", 14), ("c", 30)), rim=5, rim_h=5, depth=8, slab=7,
        face=NAVY_FACE, rim_color="8fe6ff", wall=NAVY, alpha=0.80, emit=0.5, rim_emit=1.0,
        lines=[(10, 2.0, "2a7fd6", 0.6)],
        glow=(CYAN, 0.55, 8.0), inner=(CYAN, 0.20, 9.0),
        use="Dunkle Glas-Kachel mit Cyan-Neonrand (Garage, Strecken, Belohnungen), 9-Slice",
    ),
    "panel_glass_navy": dict(
        kind="plate", size=(232, 232), nine=(108, 108, 108, 108), pad=(26, 26, 26, 26), lip=0,
        corners=(("r", 18), ("c", 42), ("r", 18), ("c", 42)), rim=6, rim_h=6, depth=8, slab=7,
        face=("0f2f80", "060f36"), rim_color="9aeaff", wall=NAVY, alpha=0.86, emit=0.45, rim_emit=1.0,
        lines=[(13, 2.2, "2f8fe6", 0.7), (20, 1.2, "1f55b0", 0.5)],
        glow=(CYAN, 0.6, 10.0), inner=(CYAN, 0.22, 12.0),
        use="Großer Glasrahmen für Wertetafeln und Overlays, 9-Slice",
    ),
    "plate_nav": dict(
        kind="plate", size=(132, 132), nine=(58, 58, 58, 58), pad=(18, 18, 18, 18), lip=0,
        corners=(("r", 12), ("c", 20), ("r", 12), ("c", 20)), rim=4, rim_h=4, depth=6, slab=6,
        face=("123a94", "071443"), rim_color="7fdcff", wall=NAVY, alpha=0.82, emit=0.5, rim_emit=0.9,
        glow=(CYAN, 0.42, 6.0), inner=(CYAN, 0.16, 6.0),
        use="Kachel der unteren Leiste, 9-Slice",
    ),
    "plate_nav_active": dict(
        kind="plate", size=(132, 132), nine=(58, 58, 58, 58), pad=(18, 18, 18, 18), lip=0,
        corners=(("r", 12), ("c", 20), ("r", 12), ("c", 20)), rim=5, rim_h=5, depth=6, slab=6,
        face=("f2a52a", "7a3a08"), rim_color="fff0b0", wall="7a3506", alpha=0.94, emit=0.6, rim_emit=1.0,
        glow=(AMBER, 0.8, 7.0), inner=(GOLD, 0.2, 6.0),
        use="Aktive Kachel der unteren Leiste (Bernstein-Leuchten), 9-Slice",
    ),
    "row_stat": dict(
        kind="plate", size=(104, 104), nine=(44, 44, 44, 44), pad=(10, 10, 10, 10), lip=0,
        corners=(("r", 20), ("r", 20), ("r", 20), ("r", 20)), rim=3, rim_h=3, depth=6, slab=5,
        face=("0e2a72", "071440"), rim_color="4f8ff0", wall=NAVY, alpha=0.88, emit=0.45, rim_emit=0.55,
        glow=("2f6fe0", 0.3, 4.0), inner=("3f8fff", 0.12, 5.0),
        use="Abgerundete dunkle Zeile für Werte wie Gesamtzeit, 9-Slice",
    ),
    "frame_neon_cyan": dict(
        kind="plate", size=(120, 120), nine=(50, 50, 50, 50), pad=(16, 16, 16, 16), lip=0,
        corners=(("r", 13), ("r", 13), ("r", 13), ("r", 13)), rim=6, rim_h=6, depth=8,
        face=None, rim_color="8fe6ff", wall=NAVY, rim_emit=1.0,
        glow=(CYAN, 0.5, 5.0),
        use="Neonrahmen mit durchsichtiger Mitte für Streckenbilder, 9-Slice",
    ),
    "frame_neon_amber": dict(
        kind="plate", size=(120, 120), nine=(50, 50, 50, 50), pad=(16, 16, 16, 16), lip=0,
        corners=(("r", 13), ("r", 13), ("r", 13), ("r", 13)), rim=7, rim_h=7, depth=8,
        face=None, rim_color="ffe9a8", wall=NAVY, rim_emit=1.0,
        glow=(AMBER, 0.85, 6.0),
        use="Bernstein-Neonrahmen für das gewählte Streckenbild, 9-Slice",
    ),
    "bar_track": dict(
        kind="plate", size=(72, 64), nine=(34, 30, 34, 30), pad=(8, 8, 8, 8), lip=0,
        corners=(("r", 22), ("r", 22), ("r", 22), ("r", 22)), rim=3, rim_h=3, depth=6, slab=2,
        face=("050c2c", "0a1a52"), rim_color="3f6fd0", wall=NAVY, alpha=0.92, emit=0.35, rim_emit=0.5,
        glow=("2f6fe0", 0.2, 3.0),
        use="Dunkle Rinne eines Fortschrittsbalkens, 9-Slice",
    ),
    "bar_fill_gold": dict(
        kind="plate", size=(72, 64), nine=(34, 30, 34, 30), pad=(8, 8, 8, 8), lip=0,
        corners=(("r", 22), ("r", 22), ("r", 22), ("r", 22)), rim=2, rim_h=3, depth=8, slab=7,
        face=("ffe457", "ff9408"), rim_color="fff3b8", wall="7a3506", emit=0.7, rim_emit=0.9,
        glow=(AMBER, 0.55, 3.5),
        use="Goldene Füllung eines Fortschrittsbalkens (Sternenpfad), 9-Slice",
    ),
    "bar_fill_cyan": dict(
        kind="plate", size=(72, 64), nine=(34, 30, 34, 30), pad=(8, 8, 8, 8), lip=0,
        corners=(("r", 22), ("r", 22), ("r", 22), ("r", 22)), rim=2, rim_h=3, depth=8, slab=7,
        face=("8df4ff", "1a9cf2"), rim_color="e0fcff", wall="0a3a7a", emit=0.7, rim_emit=0.9,
        glow=(CYAN, 0.55, 3.5),
        use="Türkise Füllung eines Fortschrittsbalkens (Fahrer-Stufe), 9-Slice",
    ),
}


def button_spec(face, lip_color, rim_color, glow, pressed, use, rim=0):
    return dict(
        kind="button", size=(128, 136), nine=(56, 58, 56, 62), pad=(18, 14, 18, 18), lip=10,
        radius=22, face=face, lip_color=lip_color, rim_color=rim_color, rim=rim, glow=glow, pressed=pressed, use=use,
    )


BUTTONS = {
    "button_primary_gold": button_spec(("ffdc38", "ff9d08"), "b25e00", None, (AMBER, 0.6, 8.0), False, "Gelber Hauptknopf (Weiter), 9-Slice"),
    "button_primary_gold_pressed": button_spec(("e8b93a", "d47c06"), "7a3e00", None, (AMBER, 0.3, 5.0), True, "Gelber Hauptknopf gedrückt, 9-Slice"),
    "button_secondary_blue": button_spec(("2a6ff0", "0f3192"), "081a58", "9be4ff", (CYAN, 0.5, 8.0), False, "Blauer Nebenknopf (Nochmal), 9-Slice", rim=4),
    "button_secondary_blue_pressed": button_spec(("1f55bd", "0b2670"), "06143f", "6fbde6", (CYAN, 0.25, 5.0), True, "Blauer Nebenknopf gedrückt, 9-Slice", rim=4),
}


def button_layers(w, h, spec):
    pad_l, pad_t, pad_r, pad_b = spec["pad"]
    lip = spec["lip"]
    bw = w - pad_l - pad_r
    bh = h - pad_t - pad_b - lip
    cx = (pad_l - pad_r) / 2
    cy = h / 2 - pad_t - bh / 2
    r = spec["radius"]
    sink = 8 if spec["pressed"] else 0  # gedrückt: Kappe rutscht nach unten, Kante wird schmal
    rr = ("r", r)
    lip_mat = grad("lip", [(0.0, mixc(spec["lip_color"], "000000", 0.25)), (1.0, spec["lip_color"])], cy - bh / 2 - lip, cy - bh / 2 + 10, rough=0.35, emit=0.3, coat=0.4)
    shape("lip", rect_path(bw, bh, rr, rr, rr, rr, cx=cx, cy=cy - lip), 0, 14, 5, lip_mat)
    top, bottom = spec["face"]
    lo, hi = cy - sink - bh / 2, cy - sink + bh / 2
    cap = grad("cap", [(0.0, bottom), (0.5, mixc(bottom, top, 0.55)), (1.0, top)], lo, hi, rough=0.2, emit=0.5 if not spec["pressed"] else 0.42, coat=1.0)
    shape("cap", rect_path(bw, bh, rr, rr, rr, rr, cx=cx, cy=cy - sink), 10, 26, 11, cap, res=6)
    if spec["rim"]:
        rim = spec["rim"]
        rim_mat = solid("rim", spec["rim_color"], rough=0.16, emit=0.9, coat=1.0)
        outer = rect_path(bw, bh, rr, rr, rr, rr, cx=cx, cy=cy - sink)
        inner = rect_path(bw - 2 * rim, bh - 2 * rim, ("r", r - rim), ("r", r - rim), ("r", r - rim), ("r", r - rim), cx=cx, cy=cy - sink)
        shape("rim", [outer, inner], 22, 16, 2.0, rim_mat)
    # heller Glanzstreifen unter der Oberkante (über die ganze Breite gleich, also dehnbar)
    gloss = solid("gloss", WHITE, rough=0.1, emit=1.0, coat=0.0, alpha=(0.10 if not spec["rim"] else 0.045) if not spec["pressed"] else 0.03)
    inset = 9 + spec["rim"]
    gh = min(bh * 0.34, 30.0)
    gr = ("r", max(4, r - inset))
    shape("gloss", rect_path(bw - 2 * inset, gh, ("r", gh * 0.45), ("r", gh * 0.45), gr, gr, cx=cx, cy=cy - sink + bh / 2 - inset - gh / 2), 35.6, 0.6, 0.0, gloss)


# ---------------------------------------------------------------- Icons
def icon_materials():
    kw = dict(rough=0.2, coat=1.0)
    return dict(
        white=grad("white", [(0.0, "a4c2fa"), (0.5, "e4efff"), (1.0, "ffffff")], -110, 110, emit=0.42, side="5d83de", **kw),
        gold=grad("goldp", [(0.0, "ff9a00"), (0.5, "ffc81f"), (1.0, "fff08a")], -110, 110, emit=0.45, side="d05e00", **kw),
        gold_metal=metal("gold", "ffe678", "ffc020", "e07c00", -110, 110, emit=0.34),
        amber=grad("amber", [(0.0, "f07c0a"), (1.0, "ffc23d")], -110, 110, emit=0.45, side="a83c00", **kw),
        cyan=grad("cyan", [(0.0, "1090e8"), (1.0, "5fe4ff")], -110, 110, emit=0.5, side="0a4fb0", **kw),
        magenta=grad("magenta", [(0.0, "d0209f"), (1.0, "ff7ad9")], -110, 110, emit=0.45, side="7a0c70", **kw),
        violet=grad("violet", [(0.0, "4a25c9"), (1.0, "a685ff")], -110, 110, emit=0.45, side="2a108a", **kw),
        navy=grad("navy", [(0.0, "0a1a5e"), (1.0, "2148c0")], -110, 110, emit=0.4, side="040a2e", rough=0.25, coat=1.0),
        silver=metal("silver", "ffffff", "c4d3ec", "6f82ad", -110, 110, rough=0.18, emit=0.24),
        dark=solid("dark", "0a1a52", rough=0.3, emit=0.25, coat=0.8),
    )


def icon_flag(m):
    g = group("flag", rot=(0, 0, -7))
    pole = lathe("pole", [(0, -118), (7.5, -118), (7.5, 104), (0, 104)], m["silver"], seg=24, parent=g)
    pole.location.x = -78 * PX
    ball("knob", 13, (-78, 110, 0), m["gold_metal"], parent=g)
    cols, rows, sub = 5, 4, 8
    nx, ny = cols * sub, rows * sub
    x0, x1, y0, y1 = -72.0, 104.0, -14.0, 100.0
    bm = bmesh.new()
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            wave = math.sin(u * math.pi * 2.3 + 0.4)
            x = x0 + (x1 - x0) * u
            y = y0 + (y1 - y0) * v + 9.0 * math.sin(u * math.pi * 2.0 + 0.9) * (0.35 + 0.65 * u) - 10.0 * u
            z = 6 + 20.0 * wave * (0.25 + 0.75 * u)
            row.append(bm.verts.new((x * PX, y * PX, z * PX)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    me = bpy.data.meshes.new("cloth")
    bm.to_mesh(me)
    bm.free()
    ob = finish_mesh(me, "cloth", m["white"], 80.0, weighted=False, parent=g)
    ob.data.materials.append(grad("flagblue", [(0.0, "10247a"), (1.0, "2f62e6")], -40, 110, rough=0.25, emit=0.4, coat=0.8))
    for poly in ob.data.polygons:  # Reihenfolge der Flächen = Reihenfolge der Erzeugung (zeilenweise)
        i, j = poly.index % nx, poly.index // nx
        poly.material_index = (i // sub + j // sub) % 2
    mod = ob.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 7 * PX
    mod.offset = 0.0
    ROOT.rotation_euler = (math.radians(-6), math.radians(14), 0)


def icon_trophy(m):
    gm = m["gold_metal"]
    cup = [(0, 18), (20, 20), (44, 34), (58, 62), (63, 96), (64, 112), (58, 113), (55, 98), (48, 66), (30, 44), (0, 40)]
    lathe("cup", cup, gm)
    lathe("stem", [(0, -52), (26, -52), (24, -44), (11, -36), (9, -4), (15, 12), (22, 22), (0, 22)], gm)
    lathe("base", [(0, -100), (50, -100), (52, -92), (50, -74), (44, -70), (36, -58), (30, -50), (0, -50)], m["violet"])
    lathe("plinth", [(0, -76), (53, -76), (54, -70), (53, -64), (0, -64)], gm)
    for side in (-1, 1):
        path = smooth_path([(side * 58, 98, 0), (side * 84, 100, 0), (side * 100, 78, 0), (side * 92, 50, 0), (side * 66, 36, 0), (side * 44, 34, 0)], per=8)
        tube("handle", path, 7.5, gm)
    star = Mask().poly(star_pts(5, 22, 10, cy=74)).loops(smooth=0.8)
    shape("emblem", star, 57, 8, 3, m["white"])
    ROOT.rotation_euler = (math.radians(12), 0, 0)


def star_loops(outer, inner, round_px, n=5):
    mk = Mask()
    pts = star_pts(n, outer, inner)
    mk.poly(pts)
    mk.line(pts + [pts[0]], round_px * 2)
    return mk.loops(smooth=1.2)


def icon_star_gold(m):
    shape("star", star_loops(86, 42, 15), 0, 46, 20, m["gold"], res=7)
    shape("shine", star_loops(46, 22, 7), 44, 8, 4, grad("shine", [(0.0, "ffd23a"), (1.0, "fffbd6")], -50, 50, rough=0.15, emit=0.6, coat=1.0), res=4)
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def icon_star_crystal(m):
    n = Nodes("crystal")
    x, y, _z = n.coord_px()
    mr = n.new("ShaderNodeMapRange")
    n.put(mr.inputs["Value"], n.math("SUBTRACT", y, x))
    mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = -150.0, 150.0
    col = n.ramp(mr.outputs["Result"], [(0.0, "ff4fc8"), (0.38, "8a5cff"), (0.7, "3aa8ff"), (1.0, "9ff2ff")])
    crystal = n.finish(col, rough=0.06, emit=0.5, metallic=0.25, coat=1.0)
    outline = star_pts(5, 112, 47)
    bm = bmesh.new()
    apex = bm.verts.new((0, 0, 52 * PX))
    ring = [bm.verts.new((px * PX, py * PX, 10 * PX)) for px, py in outline]
    back = [bm.verts.new((px * PX, py * PX, 0)) for px, py in outline]
    count = len(ring)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((apex, ring[i], ring[j]))
        bm.faces.new((ring[i], back[i], back[j], ring[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("crystal")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(crystal)
    link(bpy.data.objects.new("crystal", me))
    # kleine Innenfacetten für den geschliffenen Eindruck
    bm = bmesh.new()
    apex = bm.verts.new((0, 0, 66 * PX))
    inner = [bm.verts.new((px * PX, py * PX, 40 * PX)) for px, py in star_pts(5, 50, 24, rot=90 + 36)]
    for i in range(len(inner)):
        bm.faces.new((apex, inner[i], inner[(i + 1) % len(inner)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("gem")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(crystal)
    link(bpy.data.objects.new("gem", me))
    edge = solid("edge", "e8f8ff", rough=0.15, emit=0.8, coat=1.0)
    shape("edge", star_loops(113, 50, 5), -6, 12, 4, edge)
    ROOT.rotation_euler = (math.radians(-8), math.radians(8), math.radians(-6))


def icon_calendar(m):
    shape("page", Mask().rrect(-86, -92, 86, 74, 22).loops(), 0, 30, 8, m["white"])
    head = Mask().rrect(-86, 14, 86, 74, 22)
    head.d.rectangle((head._p(-86, 44)[0], head._p(-86, 44)[1], head._p(86, 14)[0], head._p(86, 14)[1]), fill=255)
    shape("head", head.loops(smooth=0.6), 4, 34, 8, m["magenta"])
    for x in (-44, 44):
        shape("ring", Mask().rrect(x - 9, 46, x + 9, 100, 9).loops(), 20, 30, 7, m["navy"])
    shape("star", star_loops(34, 17, 6), 28, 14, 6, m["gold"], res=5).location.y = -38 * PX
    ROOT.rotation_euler = (math.radians(-10), math.radians(12), math.radians(-4))


def icon_wrench(m):
    mk = Mask()
    mk.rrect(-84, -18, 60, 18, 18)
    mk.circle(-80, 0, 31)
    mk.circle(70, 0, 48)
    mk.circle(-80, 0, 12, fill=0)
    mk.poly([(64, -17), (140, -17), (140, 17), (64, 17)], fill=0)  # Maulöffnung
    mk.circle(64, 0, 17, fill=0)
    mk.poly([(103, -60), (140, -60), (140, 60), (103, 60)], fill=0)  # stumpfe Backen
    mk.rotate(45)
    shape("wrench", mk.loops(smooth=1.6), 0, 34, 9, m["white"], res=5)
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def icon_gift(m):
    g = group("gift", rot=(24, -32, 0))
    ribbon = m["gold"]
    box("body", (120, 88, 120), (0, -40, 0), m["magenta"], 7, parent=g)
    box("lid", (136, 30, 136), (0, 16, 0), grad("lid", [(0.0, "e0389f"), (1.0, "ff9be2")], -20, 60, rough=0.2, emit=0.45, coat=1.0), 7, parent=g)
    box("rib_x", (30, 90, 123), (0, -40, 0), ribbon, 3, parent=g)
    box("rib_z", (123, 90, 30), (0, -40, 0), ribbon, 3, parent=g)
    box("lid_x", (32, 32, 139), (0, 16, 0), ribbon, 3, parent=g)
    box("lid_z", (139, 32, 32), (0, 16, 0), ribbon, 3, parent=g)
    for side in (-1, 1):
        loop = smooth_path([(0, 32, 0), (side * 30, 62, 6), (side * 58, 66, 0), (side * 62, 44, -6), (side * 34, 34, 0), (0, 32, 0)], per=8)
        tube("bow", loop, 11, ribbon, parent=g)
    ball("knot", 14, (0, 38, 0), ribbon, parent=g)


def icon_gear(m):
    teeth, pts = 8, []
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        for r, da in ((78, -0.27), (104, -0.16), (104, 0.16), (78, 0.27)):
            pts.append((r * math.cos(a + da), r * math.sin(a + da)))
        pts.append((78 * math.cos(a + math.pi / teeth), 78 * math.sin(a + math.pi / teeth)))
    mk = Mask().poly(pts).circle(0, 0, 78).circle(0, 0, 33, fill=0)
    shape("gear", mk.loops(smooth=1.6), 0, 34, 9, m["white"], res=5)
    hub = Mask().circle(0, 0, 54).circle(0, 0, 33, fill=0)
    shape("hub", hub.loops(), 30, 12, 5, m["cyan"])
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), math.radians(11))


def icon_home(m):
    body = Mask().rrect(-66, -96, 66, 20, 12)
    body.rrect(-19, -110, 19, -34, 10, fill=0)
    shape("body", body.loops(), 0, 30, 8, m["white"])
    shape("chimney", Mask().rrect(40, 30, 66, 92, 7).loops(), 2, 28, 7, m["white"])
    roof = Mask().line([(-98, 0), (0, 86), (98, 0)], 36)
    roof.poly([(-80, 2), (0, 74), (80, 2)])
    shape("roof", roof.loops(smooth=1.2), 8, 34, 10, m["amber"], res=5)
    ROOT.rotation_euler = (math.radians(-10), math.radians(11), 0)


def icon_route(m):
    road = smooth_path([(-74, -98), (-10, -104), (56, -86), (54, -52), (-10, -44), (-62, -26), (-52, 8), (0, 14), (22, 14)], per=10)
    bed = tube("bed", [(x, y, 6) for x, y in road], 20, m["navy"])
    bed.scale.z = 0.45
    lane = tube("lane", [(x, y, 14) for x, y in road], 11.5, m["cyan"])
    lane.scale.z = 0.8
    sx, sy = road[0]
    shape("start", Mask().circle(sx, sy, 15).loops(), 20, 12, 5, m["white"])
    ex, ey = road[-1]
    pin = Mask().circle(ex, ey + 76, 46)
    pin.poly([(ex - 40, ey + 54), (ex + 40, ey + 54), (ex, ey - 2)])
    pin.circle(ex, ey + 76, 17, fill=0)
    shape("pin", pin.loops(smooth=1.5), 22, 40, 15, m["magenta"], res=6)
    shape("dot", Mask().circle(ex, ey + 76, 20).loops(), 24, 24, 8, m["white"])
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def icon_stopwatch(m):
    shape("crown", Mask().rrect(-15, 80, 15, 112, 6).loops(), 4, 26, 7, m["white"])
    shape("cap", Mask().rrect(-27, 104, 27, 124, 9).loops(), 2, 32, 8, m["amber"])
    knob = Mask().rrect(-12, 84, 12, 112, 6).rotate(-42)
    shape("knob", knob.loops(), 4, 26, 7, m["white"])
    case = Mask().circle(0, -6, 92).circle(0, -6, 66, fill=0)
    shape("case", case.loops(), 0, 38, 11, m["white"], res=6)
    shape("dial", Mask().circle(0, -6, 69).loops(), 4, 12, 2, m["navy"])
    wedge = Mask().poly([(0, -6)] + arc_pts(0, -6, 56, 90, -40, 30))
    shape("wedge", wedge.loops(smooth=0.8), 14, 6, 2, m["cyan"])
    shape("hand", Mask().line([(0, -6), (0, 44)], 11).loops(), 18, 9, 4, m["white"])
    shape("hand2", Mask().line([(0, -6), (36, -37)], 11).loops(), 18, 9, 4, m["white"])
    shape("pivot", Mask().circle(0, -6, 12).loops(), 22, 12, 5, m["amber"])
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def icon_lock(m):
    arc = [(46, -6), (46, 36)] + arc_pts(0, 36, 46, 0, 180, 24) + [(-46, -6)]
    shape("shackle", Mask().line(arc, 27).loops(), 6, 30, 12, m["silver"], res=6)
    shape("body", Mask().rrect(-80, -104, 80, 14, 26).loops(), 0, 46, 13, m["gold"], res=6)
    key = Mask().circle(0, -34, 17).poly([(-9, -40), (9, -40), (14, -76), (-14, -76)])
    shape("key", key.loops(smooth=1.2), 42, 8, 3, m["dark"])
    ROOT.rotation_euler = (math.radians(-10), math.radians(11), 0)


def crown_parts(m, parent=None, z0=0.0):
    mk = Mask().poly([(-90, -72), (90, -72), (108, 44), (54, -6), (0, 84), (-54, -6), (-108, 44)])
    for x, y in ((-108, 50), (0, 90), (108, 50)):
        mk.circle(x, y, 15)
    shape("crown", mk.loops(smooth=1.4), z0, 36, 11, m["gold"], res=6, parent=parent)
    shape("band", Mask().rrect(-94, -80, 94, -42, 12).loops(), z0 + 6, 38, 10, m["amber"], res=5, parent=parent)
    for x, r, mat in ((0, 13, m["magenta"]), (-52, 10, m["cyan"]), (52, 10, m["cyan"])):
        shape("gem", Mask().circle(x, -61, r).loops(), z0 + 40, 12, 6, mat, res=5, parent=parent)


def icon_crown(m):
    crown_parts(m)
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def laurel(mat, radius=84.0, leaves=7, parent=None, z0=0.0, depth=16.0, leaf=(50.0, 22.0), gap=28.0):
    """Lorbeerkranz: zwei Zweige mit Blattpaaren, unten gebunden, oben offen."""
    g = group("laurel", parent=parent)
    for side in (-1, 1):
        stem = []
        for i in range(25):
            a = math.radians(-90 + side * 160 * i / 24)
            stem.append((radius * math.cos(a), radius * math.sin(a), z0 + depth * 0.4))
        tube("stem", stem, 3.6, mat, parent=g)
        for k in range(leaves):
            t = (k + 0.6) / leaves
            a = math.radians(-90 + side * (gap / 2 + (160 - gap / 2) * t))
            px, py = radius * math.cos(a), radius * math.sin(a)
            tangent = math.degrees(a) + side * 90
            shrink = 1.0 - 0.38 * t
            for inward, spread in ((1, 34), (-1, 38)):
                lob = shape("leaf", leaf_pts(leaf[0] * shrink * (0.86 if inward == 1 else 1.0), leaf[1] * shrink), 0, depth, depth * 0.45, mat, res=3, parent=g)
                lob.location = (px * PX, py * PX, (z0 + depth / 2 + (k % 2) * 2) * PX)
                lob.rotation_euler = (math.radians(14 * inward * side), math.radians(-8 * side), math.radians(tangent + side * inward * spread))
        tip_a = math.radians(-90 + side * 160)
        tip = shape("tip", leaf_pts(leaf[0] * 0.62, leaf[1] * 0.62), 0, depth, depth * 0.45, mat, res=3, parent=g)
        tip.location = (radius * math.cos(tip_a) * PX, radius * math.sin(tip_a) * PX, (z0 + depth / 2) * PX)
        tip.rotation_euler = (0, 0, tip_a + side * math.radians(96))
    ball("knot", depth * 0.5, (0, -radius, z0 + depth * 0.45), mat, parent=g)
    return g


def icon_laurel(m):
    laurel(m["gold_metal"], radius=86, leaves=7)
    ROOT.rotation_euler = (math.radians(-8), 0, 0)


def icon_back(m):
    mk = Mask().line([(36, 84), (-48, 0), (36, -84)], 46)
    shape("chevron", mk.loops(smooth=1.2), 0, 34, 10, m["white"], res=5)
    ROOT.rotation_euler = (math.radians(-10), math.radians(10), 0)


def icon_play(m):
    ring = Mask().circle(0, 0, 106).circle(0, 0, 89, fill=0)
    shape("ring", ring.loops(), 6, 26, 8, m["cyan"], res=5)
    shape("glass", Mask().circle(0, 0, 93).loops(), 0, 20, 6, m["navy"], res=5)
    corners = [(-28, -52), (58, 0), (-28, 52)]
    tri = Mask().poly(corners).line(corners + [corners[0]], 18)
    shape("triangle", tri.loops(smooth=1.2), 18, 18, 7, m["white"], res=5)
    ROOT.rotation_euler = (math.radians(-8), math.radians(8), 0)


def icon_rotate(m):
    """Drehpfeil im Uhrzeigersinn (Spitze rechts); für die Gegenrichtung gespiegelt zeichnen."""
    radius, end = 70.0, 20.0
    shape("arc", Mask().line(arc_pts(0, 0, radius, 290, end + 14, 40), 30).loops(smooth=1.2), 0, 32, 10, m["white"], res=5)
    a = math.radians(end)
    ex, ey = radius * math.cos(a), radius * math.sin(a)
    tx, ty = math.sin(a), -math.cos(a)  # Laufrichtung am Pfeilende (Winkel fällt)
    nx, ny = math.cos(a), math.sin(a)
    tip = [(ex + tx * 66, ey + ty * 66), (ex + nx * 34 - tx * 4, ey + ny * 34 - ty * 4), (ex - nx * 34 - tx * 4, ey - ny * 34 - ty * 4)]
    head = Mask().poly(tip).line(tip + [tip[0]], 16)
    shape("head", head.loops(smooth=1.2), 0, 32, 10, m["white"], res=5)
    ROOT.rotation_euler = (math.radians(-10), math.radians(8), 0)


def icon_chevrons(m):
    mk = Mask()
    for dx in (-50, 36):
        mk.line([(dx - 28, 72), (dx + 40, 0), (dx - 28, -72)], 30)
    shape("chevrons", mk.loops(smooth=1.0), 0, 28, 9, m["white"], res=5)
    ROOT.rotation_euler = (math.radians(-8), math.radians(8), 0)


def icon_alert(m):
    shape("disc", Mask().circle(0, 0, 100).loops(), 0, 42, 17, m["gold"], res=6)
    mark = Mask().rrect(-16, -20, 16, 64, 16).circle(0, -54, 18)
    shape("mark", mark.loops(smooth=1.0), 40, 10, 4, m["dark"])
    ROOT.rotation_euler = (math.radians(-8), math.radians(8), 0)


ICONS = {
    "icon_flag": (icon_flag, "Zielflagge (Rennen, Strecken)"),
    "icon_trophy": (icon_trophy, "Pokal (Turniere)"),
    "icon_star_crystal": (icon_star_crystal, "Geschliffener Saison-Stern"),
    "icon_star_gold": (icon_star_gold, "Goldstern (Sterne, Belohnung)"),
    "icon_calendar": (icon_calendar, "Kalender (Event)"),
    "icon_wrench": (icon_wrench, "Schraubenschlüssel (Garage)"),
    "icon_gift": (icon_gift, "Geschenk (Belohnungen)"),
    "icon_gear": (icon_gear, "Zahnrad (Einstellungen)"),
    "icon_home": (icon_home, "Haus (Übersicht)"),
    "icon_route": (icon_route, "Strecke mit Nadel (Strecken)"),
    "icon_stopwatch": (icon_stopwatch, "Stoppuhr (Zeiten)"),
    "icon_lock": (icon_lock, "Schloss (gesperrt)"),
    "icon_crown": (icon_crown, "Krone (Bestwert, Rang)"),
    "icon_laurel": (icon_laurel, "Lorbeerkranz (Sieg)"),
    "icon_back": (icon_back, "Pfeil zurück"),
    "icon_play": (icon_play, "Abspielknopf (Strecke fahren)"),
    "icon_rotate": (icon_rotate, "Drehpfeil im Uhrzeigersinn (Kart drehen; gespiegelt für links)"),
    "icon_chevrons": (icon_chevrons, "Doppelpfeil » (weiter, Tempo)"),
    "icon_alert": (icon_alert, "Hinweis-Scheibe mit Ausrufezeichen (Neues)"),
}


# ---------------------------------------------------------------- Lichtschichten (nicht dehnen)
def _soft_band(t, centre, width, soft=2.0):
    return np.clip((width / 2 - np.abs(t - centre)) / soft + 0.5, 0, 1)


def overlay_hero_streak(w, h):
    """Weiße Lichtbahnen und großes Schachmuster für die Modus-Kacheln. Wird unverzerrt über die
    Kachel gelegt (rechts oben verankert) und auf deren Umriss beschnitten."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    slant = 0.52
    t = x + (y - h / 2) * slant  # Bahnen lehnen wie "/"
    a = _soft_band(t, 0.36 * w, 0.20 * w) * 0.085
    a += _soft_band(t, 0.545 * w, 0.045 * w) * 0.15
    a += _soft_band(t, 0.70 * w, 0.11 * w) * 0.075
    cell = 40.0
    cx = np.floor((x + y * slant) / cell)
    cy = np.floor(y / cell)
    parity = ((cx + cy) % 2 == 0).astype(np.float32)
    # weiche Zellkanten, damit das Muster beim Verkleinern nicht flimmert
    fx = np.abs(((x + y * slant) / cell) % 1.0 - 0.5) * cell
    fy = np.abs((y / cell) % 1.0 - 0.5) * cell
    edge = np.clip((cell / 2 - np.maximum(fx, fy)) / 1.5, 0, 1)
    fade = np.clip((x / w - 0.46) / 0.54, 0, 1) ** 1.25 * (1.0 - 0.72 * y / h)
    a += parity * edge * fade * 0.26
    a += np.clip(1.0 - y / (0.42 * h), 0, 1) ** 1.6 * 0.10  # Glanz von oben
    a = np.clip(a, 0, 1) * edge_fade(h, w, 2.0)
    return np.dstack([np.ones((h, w, 3), np.float32), a])


def overlay_glass_grid(w, h):
    """Holo-Bodenraster mit Lichtfleck für die dunklen Glas-Kacheln (rechts unten verankert)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    horizon, vx = 0.34 * h, 0.66 * w
    dy = np.maximum(y - horizon, 0.75)
    depth = 56.0 / dy  # Tiefe in Rasterzellen
    wx = (x - vx) * depth / 30.0

    def lines(value, per_px):
        dist = np.abs(value - np.round(value)) / np.maximum(per_px, 1e-6)
        return np.clip(1.15 - dist, 0, 1)

    grid = np.maximum(lines(depth, 56.0 / (dy * dy)), lines(wx, depth / 30.0))
    below = np.clip((y - horizon) / (0.30 * h), 0, 1)
    side = np.clip(1.0 - np.abs(x - vx) / (0.72 * w), 0, 1) ** 0.8
    a = grid * below * side * 0.34
    spot = np.exp(-(((x - 0.70 * w) / (0.36 * w)) ** 2 + ((y - 0.80 * h) / (0.30 * h)) ** 2))
    a += spot * 0.20
    rng = np.random.default_rng(11)
    for _ in range(14):  # feste Funkelpunkte über dem Horizont
        sx, sy = rng.uniform(0.30, 0.97) * w, rng.uniform(0.08, 0.62) * h
        a += np.exp(-((x - sx) ** 2 + (y - sy) ** 2) / rng.uniform(1.2, 3.2)) * rng.uniform(0.25, 0.6)
    a = np.clip(a, 0, 1) * edge_fade(h, w, 3.0)
    col = np.asarray(srgb("7fe3ff"), np.float32)
    return np.dstack([np.broadcast_to(col, (h, w, 3)).copy(), a])


OVERLAYS = {
    "overlay_hero_streak": dict(size=(384, 256), build=overlay_hero_streak, anchor="top_right", use="Lichtschicht der Modus-Kacheln: schräge Lichtbahnen und großes Schachmuster; unverzerrt, auf den Kachelumriss beschnitten"),
    "overlay_glass_grid": dict(size=(384, 256), build=overlay_glass_grid, anchor="bottom_right", use="Lichtschicht der dunklen Glas-Kacheln: Holo-Bodenraster mit Lichtfleck; unverzerrt, auf den Kachelumriss beschnitten"),
}


# ---------------------------------------------------------------- Platz-Abzeichen
BADGES = {
    "badge_place_1": dict(numeral="1", tones=("ffdc55", "ffb40c", "cc5e00"), crown=True, use="Platz 1: goldene Ziffer mit Lorbeer und Krone"),
    "badge_place_2": dict(numeral="2", tones=("f6f9ff", "b6c6e6", "566a98"), crown=False, use="Platz 2: silberne Ziffer mit Lorbeer"),
    "badge_place_3": dict(numeral="3", tones=("ffb878", "dc7226", "7a3010"), crown=False, use="Platz 3: bronzene Ziffer mit Lorbeer"),
    "badge_place_other": dict(numeral=None, tones=("cfe6ff", "5489ea", "17308a"), crown=False, use="Platz 4 und weiter: neutraler Lorbeer mit Glasscheibe, Zahl als Text darüber"),
}


def badge_layers(spec):
    top, mid, bottom = spec["tones"]
    wreath = metal("wreath", top, mid, bottom, -200, 200, rough=0.2, emit=0.3)
    laurel(wreath, radius=178, leaves=9, depth=26, leaf=(92.0, 40.0), gap=30.0)
    if spec["numeral"]:
        font = bpy.data.fonts.load(str(FONT_PATH))
        # Ziffer: flache, verlaufende Stirnfläche, harte Fase, tiefe dunklere Flanken
        n = Nodes("numeral")
        _x, y, _z = n.coord_px()
        mr = n.new("ShaderNodeMapRange")
        n.put(mr.inputs["Value"], y)
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = -190.0, 190.0
        col = n.ramp(mr.outputs["Result"], [(0.0, bottom), (0.42, mid), (0.5, mixc(mid, top, 0.75)), (1.0, top)])
        face = n.finish(col, rough=0.18, emit=0.3, metallic=0.7, coat=0.6, side=mixc(bottom, "000000", 0.35))
        g = group("num", rot=(-13, 16, 0), loc=(0, -4, 44))
        text("numeral", spec["numeral"], 560, 0, 96, 10, face, font, res=0, parent=g)
        back = solid("back", "0b1d66", rough=0.3, emit=0.35, coat=0.6, side="040b30")
        text("backing", spec["numeral"], 560, -10, 44, 6, back, font, res=2, parent=g, grow=13.0)
        if spec["crown"]:
            m = icon_materials()
            # eigene Verläufe: die Krone sitzt weit oben, außerhalb des Verlaufsbereichs der Icon-Materialien
            m["gold"] = grad("crowngold", [(0.0, "ff9a00"), (0.5, "ffc81f"), (1.0, "fff08a")], 150, 300, rough=0.2, coat=1.0, emit=0.45, side="d05e00")
            m["amber"] = grad("crownband", [(0.0, "e86a00"), (1.0, "ffb02e")], 150, 230, rough=0.2, coat=1.0, emit=0.45, side="a83c00")
            c = group("crown", loc=(-74, 216, 120), rot=(-8, 14, 16), scale=0.66)
            crown_parts(m, parent=c)
    else:
        disc = Mask(400).circle(0, 0, 112).circle(0, 0, 99, fill=0)
        shape("ring", disc.loops(), 30, 24, 9, solid("ring", "9ae6ff", rough=0.16, emit=0.9, coat=1.0), res=5)
        glass = grad("glass", [(0.0, "071443"), (1.0, "1746b4")], -110, 110, rough=0.12, emit=0.5, coat=1.0)
        shape("glass", Mask(400).circle(0, 0, 103).loops(), 28, 20, 9, glass, res=6)
    ROOT.rotation_euler = (math.radians(-6), 0, 0)


# ---------------------------------------------------------------- Ablauf
def all_specs():
    specs = {}
    for name, spec in PLATES.items():
        specs[name] = spec
    for name, spec in BUTTONS.items():
        specs[name] = spec
    for name, (fn, use) in ICONS.items():
        specs[name] = dict(kind="icon", size=(256, 256), nine=None, build=fn, use="Icon: " + use)
    for name, spec in BADGES.items():
        specs[name] = dict(spec, kind="badge", size=(512, 512), nine=None)
    for name, spec in OVERLAYS.items():
        specs[name] = dict(spec, kind="overlay", nine=None)
    return specs


def render_asset(name, spec, samples):
    w, h = spec["size"]
    kind = spec["kind"]
    if kind == "plate":
        stage(w, h, samples)
        face_loop = plate_layers(w, h, spec)
        img = render_rgba(w, h)
        # Glas: Deckkraft der Fläche erst hier (rauschfrei), der Rand bleibt deckend
        img[..., 3] *= 1.0 - (1.0 - spec.get("alpha", 1.0)) * poly_mask(w, h, face_loop)
        img = decorate(img, glow=spec.get("glow"), inner=spec.get("inner"))
    elif kind == "button":
        stage(w, h, samples)
        button_layers(w, h, spec)
        img = render_rgba(w, h)
        img = decorate(img, glow=spec.get("glow"), shadow=(5, 5.0, 0.5))
    elif kind == "overlay":
        img = spec["build"](w, h)  # rechnerisch erzeugte Lichtschicht, kein Render
    elif kind == "icon":
        stage(w, h, samples)
        spec["build"](icon_materials())
        fit_camera(w, h, 15)
        img = render_rgba(w, h)
        img = decorate(img, shadow=(4, 5.0, 0.42))
    else:
        stage(w, h, max(samples, 64), light_scale=1.0)
        badge_layers(spec)
        fit_camera(w, h, 26)
        img = render_rgba(w, h)
        img = decorate(img, shadow=(7, 9.0, 0.45))
    deviation = None
    if spec["nine"]:
        img, deviation = linearize(img, spec["nine"])
    OUT.mkdir(parents=True, exist_ok=True)
    save_webp(img, OUT / f"{name}.webp")
    return deviation


def kind_is_plate(spec):
    return spec["kind"] == "plate"


def write_manifest(specs):
    assets = []
    for name, spec in specs.items():
        path = OUT / f"{name}.webp"
        if not path.exists():
            continue
        with Image.open(path) as im:
            size = list(im.size)
        entry = {"file": f"{name}.webp", "kind": spec["kind"], "size": size, "nine_slice": list(spec["nine"]) if spec["nine"] else None}
        if spec.get("pad"):
            pad = list(spec["pad"])
            entry["glow_pad"] = pad
        if kind_is_plate(spec):
            # Umriss des Glasfelds, damit Lichtschichten exakt beschnitten werden können
            entry["lip"] = spec.get("lip", 0)
            entry["rim"] = spec["rim"]
            entry["corners"] = [[c[0], c[1]] for c in spec["corners"]]
        if spec.get("anchor"):
            entry["anchor"] = spec["anchor"]
        entry["use"] = spec["use"]
        assets.append(entry)
    manifest = {
        "kit": "lumo_kart_ui3d",
        "generator": "tools/art/render_ui_kit.py",
        "design_scale": 2.0,
        "units": "Texturpixel; nine_slice und glow_pad jeweils [links, oben, rechts, unten]; corners [unten links, unten rechts, oben rechts, oben links] je ['r' rund | 'c' abgeschrägt, Größe]; lip = sichtbare Kante unter dem Glasfeld; rim = Randbreite",
        "hint": "Für die 720x1280-Grundfläche in doppelter Auflösung gebaut: 9-Slice mit Faktor 0.5 zeichnen (siehe README.md). glow_pad ist der durchsichtige Leuchtrand um den festen Körper.",
        "assets": assets,
    }
    head = {k: v for k, v in manifest.items() if k != "assets"}
    lines = json.dumps(head, ensure_ascii=False, indent=2)[:-2] + ',\n  "assets": [\n'
    lines += ",\n".join("    " + json.dumps(a, ensure_ascii=False) for a in assets) + "\n  ]\n}\n"
    (OUT / "ui_kit.json").write_text(lines, encoding="utf-8")
    return manifest


def nine_slice(im, margins, size):
    left, top, right, bottom = margins
    w, h = im.size
    tw, th = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    xs = [(0, left, 0, left), (left, w - right, left, tw - right), (w - right, w, tw - right, tw)]
    ys = [(0, top, 0, top), (top, h - bottom, top, th - bottom), (h - bottom, h, th - bottom, th)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 <= dx0 or dy1 <= dy0:
                continue
            piece = im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.BILINEAR)
            out.paste(piece, (dx0, dy0))
    return out


def backdrop(w, h):
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :, None]
    top = np.asarray([10, 24, 74], dtype=np.float32)
    bottom = np.asarray([5, 10, 34], dtype=np.float32)
    arr = top * (1 - y) + bottom * y + 10 * np.sin(x * 9.0) * np.asarray([0.3, 0.6, 1.0], dtype=np.float32)
    rgb = np.clip(arr, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, np.full((h, w, 1), 255, np.uint8)]), "RGBA")


def contact_sheet(specs, path):
    font = ImageFont.truetype(str(FONT_PATH), 15)
    sheet = backdrop(1800, 1960)
    draw = ImageDraw.Draw(sheet)

    def put(im, x, y, label):
        sheet.alpha_composite(im, (x, y))
        draw.text((x + 4, y + im.size[1] + 2), label, font=font, fill=(190, 210, 240, 255))

    def load(name):
        return Image.open(OUT / f"{name}.webp").convert("RGBA")

    x = 20
    for name in [n for n in specs if n.startswith("plate_hero")]:
        put(nine_slice(load(name), specs[name]["nine"], (420, 250)), x, 14, name + " 420x250")
        x += 440
    x = 20
    for name, size in (("plate_feature_navy", (520, 250)), ("panel_glass_navy", (620, 330)), ("row_stat", (540, 120))):
        put(nine_slice(load(name), specs[name]["nine"], size), x, 300, f"{name} {size[0]}x{size[1]}")
        x += size[0] + 20
    row = nine_slice(load("row_stat"), specs["row_stat"]["nine"], (540, 120))
    put(row, 1180, 440, "")
    x = 20
    for name, size in (("plate_nav_active", (200, 170)), ("plate_nav", (200, 170)), ("plate_nav", (200, 170)), ("button_primary_gold", (460, 152)), ("button_primary_gold_pressed", (460, 152)), ("button_secondary_blue", (300, 152))):
        put(nine_slice(load(name), specs[name]["nine"], size), x, 660, name)
        x += size[0] + 12
    put(nine_slice(load("button_secondary_blue_pressed"), specs["button_secondary_blue_pressed"]["nine"], (300, 152)), 1480, 500, "button_secondary_blue_pressed")
    x, y = 20, 860
    icons = [n for n in specs if n.startswith("icon_")]
    for i, name in enumerate(icons):
        put(load(name), 20 + (i % 7) * 254, 860 + (i // 7) * 274, name)
    # Lesbarkeit bei 48 px
    for i, name in enumerate(icons):
        small = load(name).resize((48, 48), Image.LANCZOS)
        sheet.alpha_composite(small, (20 + i * 60, 1420))
    for i, name in enumerate(icons):
        tile = nine_slice(load("plate_nav"), specs["plate_nav"]["nine"], (176, 176)).resize((88, 88), Image.LANCZOS)
        sheet.alpha_composite(tile, (880 + i * 64 - 20, 1400))
        sheet.alpha_composite(load(name).resize((40, 40), Image.LANCZOS), (880 + i * 64 + 4, 1418))
    draw.text((20, 1474), "Icons bei 48 px (links frei, rechts auf plate_nav in halber Größe)", font=font, fill=(190, 210, 240, 255))
    for i, name in enumerate(n for n in specs if n.startswith("badge_")):
        put(load(name).resize((400, 400), Image.LANCZOS), 30 + i * 440, 1520, name + " (512 px, hier 400)")
    sheet.convert("RGB").save(path)


def stretch_test(specs, path):
    """Dehnprobe: jede Platte als 2:1 und 5:1, dazu eine hohe schmale Kachel."""
    font = ImageFont.truetype(str(FONT_PATH), 15)
    sheet = backdrop(1960, 1010)
    draw = ImageDraw.Draw(sheet)
    y = 16
    for name in ("plate_hero_amber", "panel_glass_navy", "button_primary_gold", "row_stat"):
        im = Image.open(OUT / f"{name}.webp").convert("RGBA")
        nine = specs[name]["nine"]
        th = max(nine[1] + nine[3] + 24, im.size[1] if "plate" not in name and "panel" not in name else 0)
        x = 20
        for ratio in (2, 5):
            sheet.alpha_composite(nine_slice(im, nine, (th * ratio, th)), (x, y))
            draw.text((x + 6, y + th), f"{name} {th * ratio}x{th} ({ratio}:1)", font=font, fill=(190, 210, 240, 255))
            x += th * ratio + 30
        y += th + 34
    tall = nine_slice(Image.open(OUT / "plate_hero_teal.webp").convert("RGBA"), specs["plate_hero_teal"]["nine"], (230, 700))
    sheet.alpha_composite(tall, (1700, 16))
    draw.text((1706, 720), "plate_hero_teal 230x700", font=font, fill=(190, 210, 240, 255))
    sheet.convert("RGB").save(path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="", help="Kommagetrennte Namen (ohne .webp); auch Präfix mit * möglich")
    parser.add_argument("--samples", type=int, default=SAMPLES)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--no-render", action="store_true", help="Nur Manifest und Übersichten aus vorhandenen Dateien")
    parser.add_argument("--contact-sheet", default="")
    parser.add_argument("--stretch-test", default="")
    args = parser.parse_args(argv)
    specs = all_specs()
    if args.list:
        print("\n".join(specs))
        return
    names = list(specs)
    if args.only:
        wanted = [s.strip() for s in args.only.split(",") if s.strip()]
        names = [n for n in specs if any(n == s or (s.endswith("*") and n.startswith(s[:-1])) for s in wanted)]
        if not names:
            sys.exit(f"Kein Teil passt auf --only {args.only}")
    if not args.no_render:
        for name in names:
            deviation = render_asset(name, specs[name], args.samples)
            note = "" if deviation is None else f" (9-Slice-Abweichung vor Glättung {deviation:.3f})"
            print(f"[ui3d] {name}.webp {(OUT / (name + '.webp')).stat().st_size // 1024} KB{note}", flush=True)
    manifest = write_manifest(specs)
    print(f"[ui3d] Manifest: {len(manifest['assets'])} Teile")
    if args.contact_sheet:
        contact_sheet(specs, args.contact_sheet)
    if args.stretch_test:
        stretch_test(specs, args.stretch_test)


if __name__ == "__main__":
    main()
