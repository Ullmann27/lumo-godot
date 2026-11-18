#!/usr/bin/env python3
"""Baut das Kleinteile-Kit für den Streckenrand von Lumo Kart in Blender (bpy).

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/details/build_detail_props.py
Ausgabe: assets/kart/details/models/kart_detail_props.glb

Jedes Kleinteil ist ein eigenes Objekt (Name = Kennung in kart_detail_props.gd),
leuchtende Teile liegen in "<name>__glow". Farbe steckt in den Vertex-Farben
(linear, ohne Textur), der Alphakanal ist das Bewegungsgewicht für den Shader
(0 = fest, 1 = schwingt: Arme winken, Fahnen flattern, Flügel schlagen).
Koordinaten: Meter, Blender Z oben, die Vorderseite schaut nach -Y (= Godot +Z,
also zur Fahrbahn). Ursprung = Mitte der Standfläche.
Alles Eigenbau aus Grundkörpern: keine geladenen Modelle, Texturen oder Marken.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy  # bpy zuerst: erst danach sind bmesh/mathutils importierbar
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/details/models/kart_detail_props.glb"


def lin(hex_color: str) -> tuple:
    rgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


def T(x=0.0, y=0.0, z=0.0) -> Matrix:
    return Matrix.Translation((x, y, z))


def S(x, y=None, z=None) -> Matrix:
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1.0))


def RX(a): return Matrix.Rotation(a, 4, "X")
def RY(a): return Matrix.Rotation(a, 4, "Y")
def RZ(a): return Matrix.Rotation(a, 4, "Z")


class Prop:
    """Sammelt Grundkörper eines Kleinteils in zwei BMeshes (normal / leuchtend)."""

    def __init__(self, name: str):
        self.name = name
        self.parts = {False: bmesh.new(), True: bmesh.new()}
        for bm in self.parts.values():
            bm.loops.layers.color.new("Col")

    def _paint(self, bm, faces, color, weight, smooth):
        layer = bm.loops.layers.color["Col"]
        c = lin(color) if isinstance(color, str) else color
        for f in faces:
            f.smooth = smooth
            for loop in f.loops:
                w = weight(loop.vert.co) if callable(weight) else weight
                loop[layer] = (c[0], c[1], c[2], max(0.0, min(1.0, w)))

    def add(self, kind, matrix, color, weight=0.0, glow=False, smooth=None, **kw):
        bm = self.parts[glow]
        bm.faces.ensure_lookup_table()
        before = set(bm.faces)
        if kind == "box":
            bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
            if kw.get("bevel"):
                new = [f for f in bm.faces if f not in before]
                edges = list({e for f in new for e in f.edges})
                bmesh.ops.bevel(bm, geom=edges, offset=kw["bevel"], segments=1, affect="EDGES")
            smooth = False if smooth is None else smooth
        elif kind == "cyl":
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=kw.get("seg", 12),
                                  radius1=kw.get("r1", 0.5), radius2=kw.get("r2", kw.get("r1", 0.5)),
                                  depth=1.0, matrix=matrix @ T(0, 0, 0.5) @ RX(0) )
            smooth = True if smooth is None else smooth
        elif kind == "ball":
            size = max(matrix.to_scale())
            # Kleine Kugeln (Augen, Knöpfe, Punkte) brauchen kaum Unterteilung.
            seg_default, ring_default = (5, 3) if size < 0.12 else ((8, 5) if size < 0.5 else (12, 7))
            bmesh.ops.create_uvsphere(bm, u_segments=kw.get("seg", seg_default), v_segments=kw.get("ring", ring_default),
                                      radius=0.5, matrix=matrix)
            smooth = True if smooth is None else smooth
        elif kind == "torus":
            self._torus(bm, matrix, kw.get("r", 0.5), kw.get("t", 0.15), kw.get("seg", 16), kw.get("sides", 8))
            smooth = True if smooth is None else smooth
        elif kind == "quad":
            verts = [bm.verts.new(matrix @ Vector(p)) for p in ((-0.5, 0, 0), (0.5, 0, 0), (0.5, 0, 1), (-0.5, 0, 1))]
            bm.faces.new(verts)
            back = [bm.verts.new(matrix @ Vector(p)) for p in ((-0.5, 0, 0), (-0.5, 0, 1), (0.5, 0, 1), (0.5, 0, 0))]
            bm.faces.new(back)
            smooth = False if smooth is None else smooth
        elif kind == "tri":
            pts = kw["pts"]
            verts = [bm.verts.new(matrix @ Vector(p)) for p in pts]
            bm.faces.new(verts)
            back = [bm.verts.new(matrix @ Vector(p)) for p in reversed(pts)]
            bm.faces.new(back)
            smooth = False if smooth is None else smooth
        new = [f for f in bm.faces if f not in before]
        self._paint(bm, new, color, weight, smooth)
        return new

    @staticmethod
    def _torus(bm, matrix, r, t, seg, sides):
        rows = []
        for i in range(seg):
            a = i / seg * math.tau
            ring = []
            for j in range(sides):
                b = j / sides * math.tau
                x = (r + t * math.cos(b)) * math.cos(a)
                y = (r + t * math.cos(b)) * math.sin(a)
                z = t * math.sin(b)
                ring.append(bm.verts.new(matrix @ Vector((x, y, z))))
            rows.append(ring)
        for i in range(seg):
            for j in range(sides):
                a, b = rows[i][j], rows[(i + 1) % seg][j]
                c, d = rows[(i + 1) % seg][(j + 1) % sides], rows[i][(j + 1) % sides]
                bm.faces.new((a, b, c, d))

    def tube(self, a, b, radius, color, seg=8, weight=0.0, glow=False):
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        return self.add("cyl", T(*a) @ rot @ S(1, 1, length), color, weight, glow, r1=radius, seg=seg)

    def build(self, collection):
        objects = []
        for glow, bm in self.parts.items():
            if not bm.faces:
                bm.free()
                continue
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            name = self.name + ("__glow" if glow else "")
            mesh = bpy.data.meshes.new(name)
            bm.to_mesh(mesh)
            bm.free()
            mesh.update()
            # glTF exportiert nur Farb-Attribute am Eckpunkt zuverlässig.
            mesh.color_attributes.active_color = mesh.color_attributes["Col"]
            obj = bpy.data.objects.new(name, mesh)
            collection.objects.link(obj)
            objects.append(obj)
        return objects


PROPS: dict = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


# --------------------------------------------------------------------------- Rennstrecke
@prop
def tire_stack(p: Prop):
    for i in range(4):
        p.add("torus", T(0, 0, 0.13 + i * 0.25) @ S(1, 1, 1.2), "1d1e22", r=0.36, t=0.13, seg=14, sides=7)
    p.add("torus", T(0, 0, 0.13 + 3 * 0.25 + 0.005) @ S(1.0, 1.0, 0.25), "e8e8e8", r=0.36, t=0.135, seg=14, sides=6)
    p.add("torus", T(0, 0, 0.38) @ S(1.0, 1.0, 0.25), "d63a2f", r=0.36, t=0.135, seg=14, sides=6)


@prop
def pylon(p: Prop):
    p.add("box", T(0, 0, 0.02) @ S(0.42, 0.42, 0.04), "e85f1c")
    p.add("cyl", T(0, 0, 0.04) @ S(1, 1, 0.66), "f26a1f", r1=0.17, r2=0.03, seg=12)
    p.add("cyl", T(0, 0, 0.28) @ S(1, 1, 0.09), "f4f4f0", r1=0.115, r2=0.10, seg=12)
    p.add("cyl", T(0, 0, 0.46) @ S(1, 1, 0.07), "f4f4f0", r1=0.075, r2=0.062, seg=12)


@prop
def barrier(p: Prop):
    for x in (-0.95, 0.95):
        p.add("box", T(x, 0, 0.55) @ S(0.06, 0.06, 1.1), "b9c0c6")
        p.add("box", T(x, 0, 0.03) @ S(0.1, 0.6, 0.06), "6a7178")
    p.add("box", T(0, 0, 1.08) @ S(1.96, 0.05, 0.06), "b9c0c6")
    p.add("box", T(0, 0, 0.18) @ S(1.96, 0.05, 0.05), "b9c0c6")
    for i in range(6):
        col = "d8322b" if i % 2 == 0 else "f2f2ee"
        x = -0.79 + i * 0.316
        p.add("box", T(x, -0.005, 0.66) @ S(0.316, 0.03, 0.62), col)
    for i in range(9):
        p.add("box", T(-0.84 + i * 0.21, 0.01, 0.42) @ S(0.02, 0.02, 0.36), "8e959b")


@prop
def hay_bale(p: Prop):
    p.add("cyl", T(-0.65, 0, 0.48) @ RY(math.pi / 2) @ S(1, 1, 1.3), "d9b65a", r1=0.48, seg=16)
    for x in (-0.35, 0.35):
        p.add("cyl", T(x - 0.03, 0, 0.48) @ RY(math.pi / 2) @ S(1, 1, 0.06), "8f6a2c", r1=0.49, seg=16)
    p.add("ball", T(0.66, 0, 0.48) @ S(0.06, 0.92, 0.92), "c7a14a")


@prop
def bench(p: Prop):
    for i in range(3):
        p.add("box", T(0, 0.08 - i * 0.14, 0.45) @ S(1.6, 0.12, 0.04), "a8673a", bevel=0.01)
    for i in range(2):
        p.add("box", T(0, 0.17, 0.62 + i * 0.16) @ S(1.6, 0.04, 0.11), "a8673a", bevel=0.01)
    for x in (-0.68, 0.68):
        p.add("box", T(x, -0.06, 0.22) @ S(0.06, 0.06, 0.44), "34393f")
        p.add("box", T(x, 0.17, 0.42) @ S(0.06, 0.06, 0.84), "34393f")
        p.add("box", T(x, 0.05, 0.43) @ S(0.06, 0.34, 0.05), "34393f")


@prop
def bin(p: Prop):
    p.add("cyl", T(0, 0, 0.0) @ S(1, 1, 0.9), "2f8a55", r1=0.28, r2=0.31, seg=14)
    p.add("cyl", T(0, 0, 0.9) @ S(1, 1, 0.08), "236b42", r1=0.33, seg=14)
    p.add("box", T(0, -0.31, 0.55) @ S(0.22, 0.02, 0.22), "f2f2ee")
    p.add("box", T(0, -0.322, 0.55) @ S(0.12, 0.02, 0.12), "2f8a55")
    p.add("box", T(0.0, 0.0, 1.0) @ S(0.22, 0.05, 0.04), "1d4f30")


@prop
def planter(p: Prop):
    p.add("box", T(0, 0, 0.22) @ S(1.4, 0.45, 0.44), "8c5a33", bevel=0.02)
    p.add("box", T(0, 0, 0.43) @ S(1.32, 0.38, 0.04), "4a3020")
    colors = ["ff5f7e", "ffd23f", "ffffff", "b06cff", "ff8a3d"]
    for i in range(9):
        x = -0.56 + i * 0.14
        y = 0.08 if i % 2 else -0.08
        p.add("ball", T(x, y, 0.52 + 0.05 * (i % 3)) @ S(0.22, 0.22, 0.17), "3f8f3a", ring=5, seg=8)
        p.add("ball", T(x, y - 0.03, 0.62 + 0.05 * (i % 3)) @ S(0.12), colors[i % 5], ring=5, seg=8)


@prop
def mailbox(p: Prop):
    p.add("box", T(0, 0, 0.5) @ S(0.08, 0.08, 1.0), "3a3f45")
    p.add("box", T(0, 0, 1.15) @ S(0.42, 0.3, 0.5), "f6c636", bevel=0.03)
    p.add("cyl", T(0, 0.15, 1.4) @ RX(math.pi / 2) @ S(1, 1, 0.3), "f6c636", r1=0.21, seg=12)
    p.add("box", T(0, -0.155, 1.28) @ S(0.24, 0.02, 0.04), "2b2b2b")
    p.add("tri", T(0, -0.16, 1.07) @ RX(math.pi / 2) @ S(0.11), "1f3d7a",
          pts=[(math.cos(a) * (1 if k % 2 == 0 else 0.45), math.sin(a) * (1 if k % 2 == 0 else 0.45), 0)
               for k, a in enumerate([math.pi / 2 + i * math.pi / 5 for i in range(3)])])


@prop
def hydrant(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 0.08), "a02420", r1=0.2, seg=12)
    p.add("cyl", T(0, 0, 0.08) @ S(1, 1, 0.55), "d8322b", r1=0.14, seg=12)
    p.add("ball", T(0, 0, 0.66) @ S(0.3, 0.3, 0.26), "d8322b")
    p.add("cyl", T(0, 0, 0.76) @ S(1, 1, 0.07), "e8e8e0", r1=0.04, seg=8)
    for a in (0, math.pi):
        p.add("cyl", T(0, 0, 0.45) @ RZ(a) @ RY(math.pi / 2) @ S(1, 1, 0.2), "f0c43a", r1=0.055, seg=8)
    p.add("cyl", T(0, 0, 0.42) @ RX(math.pi / 2) @ S(1, 1, 0.19), "d8322b", r1=0.07, seg=8)


@prop
def bicycle(p: Prop):
    for x in (-0.52, 0.52):
        p.add("torus", T(x, 0, 0.34) @ RX(math.pi / 2), "202226", r=0.31, t=0.035, seg=16, sides=5)
        p.add("cyl", T(x, -0.03, 0.34) @ RX(math.pi / 2) @ S(1, 1, 0.06), "c9ced3", r1=0.05, seg=6)
    frame = "2aa7d8"
    p.tube((-0.52, 0, 0.34), (0.0, 0, 0.34), 0.025, frame)
    p.tube((0.0, 0, 0.34), (0.40, 0, 0.78), 0.025, frame)
    p.tube((-0.52, 0, 0.34), (-0.12, 0, 0.74), 0.025, frame)
    p.tube((-0.12, 0, 0.74), (0.40, 0, 0.78), 0.025, frame)
    p.tube((0.0, 0, 0.34), (-0.15, 0, 0.80), 0.025, frame)
    p.tube((0.40, 0, 0.78), (0.52, 0, 0.34), 0.022, "c9ced3")
    p.add("box", T(-0.16, 0, 0.84) @ S(0.24, 0.1, 0.05), "202226")
    p.tube((0.38, -0.25, 0.92), (0.38, 0.25, 0.92), 0.02, "202226")
    p.tube((0.40, 0, 0.78), (0.38, 0, 0.92), 0.022, "c9ced3")
    p.add("box", T(0.45, 0, 0.75) @ S(0.22, 0.24, 0.16), "8c5a33")


@prop
def crate(p: Prop):
    p.add("box", T(0, 0, 0.35) @ S(0.7), "b98b52", bevel=0.02)
    for z in (0.06, 0.64):
        p.add("box", T(0, 0, z) @ S(0.72, 0.72, 0.08), "8a6236")
    p.add("box", T(0, -0.355, 0.35) @ RY(0.78) @ S(0.9, 0.02, 0.07), "8a6236")
    p.add("box", T(0, -0.358, 0.35) @ S(0.24, 0.02, 0.24), "1d6fb5")


@prop
def crate_stack(p: Prop):
    for (x, y, z, s, col) in ((-0.42, 0, 0.35, 0.7, "b98b52"), (0.38, 0.05, 0.3, 0.6, "a87b45"),
                              (-0.3, 0.02, 1.0, 0.6, "c49a5d")):
        p.add("box", T(x, y, z) @ S(s), col, bevel=0.02)
        p.add("box", T(x, y - s / 2 - 0.005, z) @ S(s * 0.92, 0.01, 0.06), "6e4c28")
        p.add("box", T(x, y - s / 2 - 0.006, z) @ S(0.06, 0.012, s * 0.92), "6e4c28")


@prop
def toolbox(p: Prop):
    p.add("box", T(0, 0, 0.45) @ S(0.9, 0.5, 0.8), "d8322b", bevel=0.02)
    for i in range(4):
        p.add("box", T(0, -0.255, 0.2 + i * 0.18) @ S(0.82, 0.02, 0.14), "b52722")
        p.add("box", T(0, -0.27, 0.22 + i * 0.18) @ S(0.3, 0.02, 0.03), "d9dde1")
    for x in (-0.38, 0.38):
        for y in (-0.18, 0.18):
            p.add("cyl", T(x, y, 0.0) @ S(1, 1, 0.06), "202226", r1=0.05, seg=8)
    p.add("box", T(0.05, 0, 0.88) @ S(0.5, 0.16, 0.1), "c9ced3")
    p.add("box", T(-0.25, 0.05, 0.9) @ S(0.3, 0.03, 0.03), "f6c636")
    p.add("cyl", T(0.25, 0.02, 0.86) @ RY(math.pi / 2) @ S(1, 1, 0.28), "8a8f96", r1=0.025, seg=6)


@prop
def tire_rack(p: Prop):
    for x in (-0.8, 0.8):
        p.add("box", T(x, 0, 0.6) @ S(0.06, 0.5, 1.2), "596069")
    p.add("box", T(0, 0, 0.05) @ S(1.66, 0.5, 0.05), "596069")
    p.add("box", T(0, 0, 0.62) @ S(1.66, 0.5, 0.05), "596069")
    for row, z in enumerate((0.33, 0.9)):
        for i in range(4):
            p.add("torus", T(-0.6 + i * 0.4, 0, z) @ RX(math.pi / 2) @ S(1, 1, 1.3), "1d1e22", r=0.18, t=0.09, seg=12, sides=6)
            p.add("cyl", T(-0.6 + i * 0.4, -0.11, z) @ RX(math.pi / 2) @ S(1, 1, 0.02), "f6c636" if row else "c9ced3", r1=0.12, seg=10)


@prop
def jerrycan(p: Prop):
    p.add("box", T(0, 0, 0.25) @ S(0.34, 0.16, 0.48), "2f8a55", bevel=0.02)
    p.add("box", T(0, 0, 0.52) @ S(0.24, 0.05, 0.06), "236b42")
    p.add("cyl", T(0.13, 0, 0.48) @ S(1, 1, 0.08), "f6c636", r1=0.03, seg=8)


@prop
def reflector_post(p: Prop):
    p.add("box", T(0, 0, 0.5) @ S(0.12, 0.12, 1.0), "f2f2ee", bevel=0.01)
    p.add("box", T(0, 0, 0.82) @ S(0.125, 0.125, 0.14), "1d1e22")
    p.add("box", T(0, -0.066, 0.82) @ S(0.05, 0.01, 0.1), "ff9d2e", glow=True)


@prop
def flag_pole(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 4.2), "d9dde1", r1=0.045, seg=8)
    p.add("ball", T(0, 0, 4.24) @ S(0.12), "f6c636")
    cols = ["3fb7e8", "ffd23f"]
    for i in range(6):
        for j in range(2):
            x0 = 0.05 + i * 0.22
            p.add("quad", T(x0 + 0.11, 0, 3.0 + j * 0.5) @ S(0.22, 1, 0.5), cols[(i + j) % 2],
                  weight=lambda co: (co.x - 0.0) / 1.4)


@prop
def marshal(p: Prop):
    # Streckenposten in Warnweste mit Fahne (kein Lumo, keine Fuchsfigur).
    p.add("cyl", T(-0.1, 0, 0) @ S(1, 1, 0.8), "2e3646", r1=0.08, seg=8)
    p.add("cyl", T(0.1, 0, 0) @ S(1, 1, 0.8), "2e3646", r1=0.08, seg=8)
    p.add("cyl", T(0, 0, 0.78) @ S(1, 1, 0.62), "f26a1f", r1=0.22, r2=0.19, seg=10)
    p.add("box", T(0, -0.205, 1.05) @ S(0.3, 0.02, 0.05), "e8f0f0")
    p.add("box", T(0, -0.21, 0.9) @ S(0.3, 0.02, 0.05), "e8f0f0")
    p.add("ball", T(0, 0, 1.6) @ S(0.36), "e0b48c")
    p.add("cyl", T(0, 0, 1.72) @ S(1, 1, 0.12), "f2f2ee", r1=0.2, seg=10)
    p.add("box", T(0, -0.15, 1.73) @ S(0.3, 0.16, 0.03), "f2f2ee")
    p.add("ball", T(-0.07, -0.17, 1.62) @ S(0.05), "1d1e22")
    p.add("ball", T(0.07, -0.17, 1.62) @ S(0.05), "1d1e22")
    p.add("cyl", T(-0.24, 0, 0.9) @ RY(-0.3) @ S(1, 1, 0.48), "f26a1f", r1=0.06, seg=6)
    arm = lambda co: (co.z - 1.2) / 0.9
    p.tube((0.22, 0, 1.3), (0.42, 0, 1.95), 0.06, "f26a1f", weight=arm)
    p.tube((0.42, 0, 1.9), (0.48, 0, 2.6), 0.02, "c9ced3", weight=arm)
    for i in range(3):
        for j in range(3):
            col = "1d1e22" if (i + j) % 2 else "f2f2ee"
            p.add("quad", T(0.6 + i * 0.2, 0, 2.15 + j * 0.15) @ S(0.2, 1, 0.15), col,
                  weight=lambda co: 0.6 + (co.x - 0.5) * 0.8)


def spectator(p: Prop, shirt, pants, skin, hat, ears=None):
    # Freundliche Zuschauerfigur aus Grundkörpern, Arme winken (Gewicht im Alpha).
    p.add("cyl", T(-0.09, 0, 0) @ S(1, 1, 0.55), pants, r1=0.075, seg=8)
    p.add("cyl", T(0.09, 0, 0) @ S(1, 1, 0.55), pants, r1=0.075, seg=8)
    p.add("ball", T(0, 0, 0.82) @ S(0.44, 0.34, 0.66), shirt)
    p.add("ball", T(0, 0, 1.3) @ S(0.38), skin)
    p.add("ball", T(-0.07, -0.17, 1.33) @ S(0.055), "1d1e22")
    p.add("ball", T(0.07, -0.17, 1.33) @ S(0.055), "1d1e22")
    p.add("ball", T(0, -0.18, 1.24) @ S(0.09, 0.04, 0.04), "b8453d")
    if hat:
        p.add("cyl", T(0, 0, 1.42) @ S(1, 1, 0.12), hat, r1=0.19, seg=10)
        p.add("box", T(0, -0.17, 1.44) @ S(0.26, 0.18, 0.03), hat)
    if ears:
        for x in (-0.12, 0.12):
            p.add("ball", T(x, 0, 1.55) @ S(0.12, 0.08, 0.3 if ears == "long" else 0.13), skin)
    arm = lambda co: (co.z - 1.0) / 0.75
    for side in (-1, 1):
        p.tube((side * 0.17, 0, 1.0), (side * 0.42, -0.05, 1.62), 0.06, shirt, weight=arm)
        p.add("ball", T(side * 0.44, -0.05, 1.66) @ S(0.13), skin, weight=1.0)


@prop
def fan_a(p: Prop):
    spectator(p, "3fb7e8", "2e3646", "f2c9a0", "ffd23f")


@prop
def fan_b(p: Prop):
    spectator(p, "ff6f91", "3b4a6b", "b97a56", None, ears="long")


@prop
def fan_c(p: Prop):
    spectator(p, "7ed957", "4b3a2e", "e8b48c", "d8322b")


@prop
def fan_d(p: Prop):
    spectator(p, "ffb63f", "2b5a7a", "8b5a3c", None, ears="round")


@prop
def grandstand(p: Prop):
    # Tribünenmodul 6 m breit, drei Stufen, Dach mit Stützen.
    for i in range(3):
        p.add("box", T(0, 0.45 + i * 0.7, 0.25 + i * 0.5) @ S(6.0, 0.7, 0.5 + i * 1.0), "c9ced3", bevel=0.02)
        p.add("box", T(0, 0.3 + i * 0.7, 0.53 + i * 1.0) @ S(6.0, 0.36, 0.08), ["3fb7e8", "ffd23f", "ff6f91"][i])
    for x in (-2.9, 2.9):
        p.add("box", T(x, 2.3, 1.9) @ S(0.12, 0.12, 3.8), "596069")
        p.add("box", T(x, 0.2, 1.9) @ S(0.1, 0.1, 3.8), "596069")
    p.add("box", T(0, 1.2, 3.85) @ RX(-0.12) @ S(6.4, 2.8, 0.1), "f2f2ee")
    for i in range(8):
        p.add("box", T(-2.8 + i * 0.8, -0.2, 3.7) @ S(0.8, 0.04, 0.3), "d8322b" if i % 2 else "f2f2ee")


@prop
def start_lights(p: Prop):
    p.add("box", T(0, 0, 0) @ S(2.4, 0.4, 0.7), "1d1e22", bevel=0.04)
    for i in range(5):
        p.add("cyl", T(-0.92 + i * 0.46, -0.21, 0.0) @ RX(math.pi / 2) @ S(1, 1, 0.04), "333840", r1=0.18, seg=12)
        p.add("cyl", T(-0.92 + i * 0.46, -0.24, 0.0) @ RX(math.pi / 2) @ S(1, 1, 0.02), "ff3b2e", r1=0.14, seg=12, glow=True)
        p.add("box", T(-0.92 + i * 0.46, -0.28, 0.17) @ S(0.36, 0.12, 0.04), "1d1e22")


@prop
def camera_tower(p: Prop):
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            p.add("box", T(x, y, 3.0) @ S(0.08, 0.08, 6.0), "8a8f96")
    for z in (1.0, 2.5, 4.0, 5.5):
        for (a, b) in (((-0.8, -0.8), (0.8, -0.8)), ((-0.8, 0.8), (0.8, 0.8)), ((-0.8, -0.8), (-0.8, 0.8)), ((0.8, -0.8), (0.8, 0.8))):
            p.tube((a[0], a[1], z), (b[0], b[1], z + 1.4), 0.03, "8a8f96", seg=5)
    p.add("box", T(0, 0, 6.05) @ S(2.0, 2.0, 0.12), "596069")
    for x in (-0.95, 0.95):
        p.add("box", T(x, 0, 6.55) @ S(0.05, 2.0, 0.05), "f6c636")
    p.add("box", T(0, -0.95, 6.55) @ S(2.0, 0.05, 0.05), "f6c636")
    p.add("box", T(0.1, -0.2, 6.65) @ S(0.4, 0.7, 0.4), "1d1e22", bevel=0.03)
    p.add("cyl", T(0.1, -0.55, 6.68) @ RX(math.pi / 2) @ S(1, 1, 0.35), "2b2f36", r1=0.13, seg=12)
    p.add("cyl", T(0.1, -0.91, 6.68) @ RX(math.pi / 2) @ S(1, 1, 0.02), "6fd3ff", r1=0.1, seg=12, glow=True)
    p.add("box", T(0.1, 0.2, 6.3) @ S(0.1, 0.1, 0.5), "2b2f36")
    p.add("box", T(0.1, 1.0, 7.1) @ S(1.6, 0.06, 1.0), "d8322b")
    p.add("box", T(0.1, 0.0, 7.62) @ S(2.2, 2.2, 0.06), "f2f2ee")


@prop
def podium(p: Prop):
    for (x, h, col) in ((0, 1.1, "ffd23f"), (-1.3, 0.75, "d9dde1"), (1.3, 0.5, "d9935a")):
        p.add("box", T(x, 0, h / 2) @ S(1.3, 1.1, h), col, bevel=0.03)
        p.add("box", T(x, -0.56, h * 0.55) @ S(0.4, 0.02, 0.4), "1d3d7a")
    p.add("box", T(0, 0.9, 0.04) @ S(4.2, 2.6, 0.08), "c43a4a")


@prop
def confetti_cannon(p: Prop):
    p.add("box", T(0, 0, 0.2) @ S(0.6, 0.6, 0.4), "3d4450", bevel=0.03)
    p.add("cyl", T(0, 0.1, 0.35) @ RX(-0.55) @ S(1, 1, 1.0), "ff6f91", r1=0.16, r2=0.21, seg=14)
    p.add("torus", T(0, -0.42, 1.2) @ RX(-0.55 + math.pi / 2), "ffd23f", r=0.21, t=0.035, seg=14, sides=5)
    for k, col in enumerate(("ffd23f", "3fb7e8", "7ed957", "ff6f91", "b06cff", "ffffff")):
        a = k * 1.1
        p.add("box", T(math.cos(a) * 0.35, -0.6 - 0.2 * math.sin(a * 2.0), 1.5 + 0.35 * math.sin(a)) @ RZ(a) @ RX(a) @ S(0.12, 0.02, 0.08), col, glow=True)


@prop
def signpost(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 2.6), "8c5a33", r1=0.07, seg=8)
    p.add("ball", T(0, 0, 2.62) @ S(0.16), "ffd23f")
    for i, (z, ang, col) in enumerate(((2.25, 0.25, "3fb7e8"), (1.85, -0.3, "ff6f91"), (1.45, 0.1, "7ed957"))):
        board = T(0, 0, z) @ RZ(ang)
        p.add("box", board @ T(0.5, 0, 0) @ S(1.0, 0.05, 0.28), col, bevel=0.015)
        p.add("tri", board @ T(1.0, 0, 0), col, pts=[(0, -0.026, -0.14), (0.2, -0.026, 0), (0, -0.026, 0.14)])
        p.add("box", board @ T(0.45, -0.03, 0) @ S(0.7, 0.01, 0.05), "f2f2ee")


@prop
def lamp_post_small(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 0.25), "2b2f36", r1=0.12, seg=10)
    p.add("cyl", T(0, 0, 0.25) @ S(1, 1, 2.4), "2b2f36", r1=0.05, seg=8)
    p.add("cyl", T(0, 0, 2.62) @ S(1, 1, 0.12), "2b2f36", r1=0.2, r2=0.06, seg=10)
    p.add("ball", T(0, 0, 2.55) @ S(0.24, 0.24, 0.3), "ffd98a", glow=True)


# --------------------------------------------------------------------------- Hafen
@prop
def container(p: Prop):
    p.add("box", T(0, 0, 1.3) @ S(6.0, 2.4, 2.6), "dcdcdc", bevel=0.03)
    for i in range(22):
        x = -2.85 + i * 0.27
        p.add("box", T(x, -1.215, 1.3) @ S(0.1, 0.04, 2.4), "bdbdbd")
        p.add("box", T(x, 1.215, 1.3) @ S(0.1, 0.04, 2.4), "bdbdbd")
    p.add("box", T(3.01, 0, 1.3) @ S(0.04, 2.3, 2.5), "bdbdbd")
    for y in (-0.45, 0.45):
        p.add("box", T(3.04, y, 1.3) @ S(0.03, 0.04, 2.3), "c9ced3")
    for z in (0.0, 2.6):
        p.add("box", T(0, 0, z) @ S(6.02, 2.42, 0.12), "8f8f8f")


@prop
def bollard(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 0.55), "2b2f36", r1=0.16, r2=0.13, seg=12)
    p.add("cyl", T(0, 0, 0.55) @ S(1, 1, 0.12), "2b2f36", r1=0.2, seg=12)
    p.add("torus", T(0, 0, 0.3) @ S(1, 1, 1.5), "c9a66b", r=0.17, t=0.03, seg=12, sides=5)


@prop
def rowboat(p: Prop):
    for i in range(7):
        t = i / 6.0
        x = -1.5 + t * 3.0
        w = 0.65 * math.sin(math.pi * (0.12 + 0.76 * t)) + 0.05
        p.add("box", T(x, 0, 0.28) @ S(0.46, w * 2, 0.5), "f2f2ee" if i % 3 else "e6e8ea")
        p.add("box", T(x, 0, 0.1) @ S(0.46, w * 1.6, 0.2), "d8322b")
    p.add("box", T(0, 0, 0.48) @ S(2.6, 0.9, 0.04), "a8673a")
    p.add("box", T(0.4, 0, 0.6) @ S(0.24, 1.0, 0.06), "a8673a")
    p.tube((-0.3, -0.5, 0.6), (0.9, -0.95, 0.5), 0.025, "a8673a")


@prop
def buoy(p: Prop):
    p.add("cyl", T(0, 0, -0.2) @ S(1, 1, 0.7), "d8322b", r1=0.42, r2=0.32, seg=14)
    p.add("cyl", T(0, 0, 0.12) @ S(1, 1, 0.16), "f2f2ee", r1=0.37, r2=0.35, seg=14)
    p.add("cyl", T(0, 0, 0.5) @ S(1, 1, 0.9), "d8322b", r1=0.08, r2=0.06, seg=8)
    p.add("ball", T(0, 0, 1.48) @ S(0.24), "ffd34a", glow=True)


@prop
def gull_flock(p: Prop):
    # Fünf Möwen auf einem Kreis (Radius ~6 m); der Shader dreht den Schwarm um den Ursprung.
    for k in range(5):
        a = k * math.tau / 5 + 0.3 * k
        r = 5.0 + (k % 3) * 1.4
        base = T(math.cos(a) * r, math.sin(a) * r, (k % 2) * 1.2) @ RZ(a + math.pi / 2)
        p.add("ball", base @ S(0.18, 0.62, 0.2), "f4f6f8")
        p.add("ball", base @ T(0, 0.28, 0.05) @ S(0.15), "f4f6f8")
        p.add("cyl", base @ T(0, 0.38, 0.05) @ RX(-math.pi / 2) @ S(1, 1, 0.1), "f6b23a", r1=0.035, r2=0.0, seg=5)
        for side in (-1, 1):
            p.add("tri", base, "dfe5ea", pts=[(side * 0.06, 0.12, 0.02), (side * 0.75, -0.05, 0.12), (side * 0.06, -0.12, 0.02)],
                  weight=lambda co, b=base: min(1.0, (co - b.translation).length / 0.75))
            p.add("tri", base, "4c5560", pts=[(side * 0.55, -0.0, 0.1), (side * 0.78, -0.06, 0.12), (side * 0.6, -0.12, 0.1)],
                  weight=lambda co, b=base: min(1.0, (co - b.translation).length / 0.75))


@prop
def lifebuoy_stand(p: Prop):
    p.add("box", T(0, 0, 0.8) @ S(0.1, 0.1, 1.6), "8c5a33")
    p.add("box", T(0, -0.06, 1.5) @ S(0.8, 0.04, 0.5), "f2f2ee")
    p.add("torus", T(0, -0.12, 1.0) @ RX(math.pi / 2), "ff6a2a", r=0.28, t=0.07, seg=16, sides=6)
    for a in range(4):
        p.add("box", T(0, -0.125, 1.0) @ RY(a * math.pi / 2 + math.pi / 4) @ T(0.28, 0, 0) @ S(0.09, 0.15, 0.15), "f2f2ee")


# --------------------------------------------------------------------------- Wald
@prop
def mushroom_cluster(p: Prop):
    for (x, y, s) in ((0, 0, 1.0), (0.45, 0.2, 0.65), (-0.35, 0.25, 0.5), (0.15, -0.35, 0.4)):
        p.add("cyl", T(x, y, 0) @ S(s, s, s * 0.7), "f2eee0", r1=0.12, r2=0.09, seg=10)
        p.add("ball", T(x, y, 0.7 * s) @ S(0.7 * s, 0.7 * s, 0.4 * s), "d8322b")
        for k in range(5):
            a = k * 1.3
            p.add("ball", T(x + math.cos(a) * 0.2 * s, y + math.sin(a) * 0.2 * s, 0.82 * s) @ S(0.08 * s), "fff8e8")


@prop
def glow_mushrooms(p: Prop):
    for (x, y, s) in ((0, 0, 0.9), (0.38, 0.1, 0.6), (-0.3, 0.2, 0.45)):
        p.add("cyl", T(x, y, 0) @ S(s, s, s * 0.6), "dfe9ff", r1=0.1, r2=0.08, seg=8)
        p.add("ball", T(x, y, 0.6 * s) @ S(0.7 * s, 0.7 * s, 0.38 * s), "5ff2ff", glow=True)


@prop
def fern(p: Prop):
    for k in range(9):
        a = k * math.tau / 9
        rot = RZ(a) @ RX(-0.9 + 0.1 * (k % 3))
        for j in range(5):
            t = j / 5
            p.add("tri", rot @ T(0, 0, 0.12 + t * 0.8), "3f8f3a" if k % 2 else "4fa142",
                  pts=[(-0.09 * (1 - t), 0, 0), (0.09 * (1 - t), 0, 0), (0, 0, 0.2)],
                  weight=lambda co: min(1.0, co.length / 1.0) * 0.6)


@prop
def firefly_lantern(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 1.7), "5a3a24", r1=0.05, seg=6)
    p.tube((0, 0, 1.65), (0.38, 0, 1.8), 0.035, "5a3a24")
    p.tube((0.38, 0, 1.8), (0.38, 0, 1.6), 0.01, "2b2f36")
    p.add("cyl", T(0.38, 0, 1.3) @ S(1, 1, 0.32), "c8ffb0", r1=0.12, r2=0.1, seg=10, glow=True)
    p.add("cyl", T(0.38, 0, 1.6) @ S(1, 1, 0.05), "6b4a2f", r1=0.13, seg=10)


@prop
def stump(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 0.5), "6b4a2f", r1=0.42, r2=0.36, seg=12)
    p.add("cyl", T(0, 0, 0.5) @ S(1, 1, 0.02), "d9b07a", r1=0.35, seg=12)
    p.add("ball", T(0.2, -0.2, 0.15) @ S(0.3, 0.2, 0.12), "5d8c3a")


# --------------------------------------------------------------------------- Winter
@prop
def snowman(p: Prop):
    p.add("ball", T(0, 0, 0.45) @ S(0.95), "f4f8ff")
    p.add("ball", T(0, 0, 1.15) @ S(0.68), "f4f8ff")
    p.add("ball", T(0, 0, 1.68) @ S(0.48), "f4f8ff")
    p.add("cyl", T(0, -0.22, 1.66) @ RX(math.pi / 2) @ S(1, 1, 0.26), "f26a1f", r1=0.05, r2=0.0, seg=8)
    for x in (-0.08, 0.08):
        p.add("ball", T(x, -0.21, 1.76) @ S(0.06), "1d1e22")
    for z in (1.0, 1.2, 1.4):
        p.add("ball", T(0, -0.33, z - 0.1) @ S(0.07), "1d1e22")
    p.add("torus", T(0, 0, 1.43) @ S(1, 1, 1.4), "d8322b", r=0.22, t=0.06, seg=14, sides=6)
    p.add("box", T(0.16, -0.18, 1.28) @ RY(0.2) @ S(0.1, 0.04, 0.35), "d8322b")
    p.add("cyl", T(0, 0, 1.88) @ S(1, 1, 0.06), "1d1e22", r1=0.25, seg=12)
    p.add("cyl", T(0, 0, 1.9) @ S(1, 1, 0.32), "1d1e22", r1=0.17, seg=12)
    for s in (-1, 1):
        p.tube((s * 0.28, 0, 1.2), (s * 0.75, 0, 1.55), 0.025, "6b4a2f", weight=lambda co: 0.4)


@prop
def sled(p: Prop):
    for y in (-0.25, 0.25):
        p.add("box", T(0, y, 0.04) @ S(1.3, 0.05, 0.04), "c9ced3")
        p.tube((0.65, y, 0.04), (0.8, y, 0.3), 0.025, "c9ced3")
        for x in (-0.4, 0.3):
            p.add("box", T(x, y, 0.15) @ S(0.05, 0.05, 0.22), "8c5a33")
    for i in range(5):
        p.add("box", T(-0.5 + i * 0.25, 0, 0.27) @ S(0.2, 0.62, 0.04), "d8322b")


@prop
def ski_rack(p: Prop):
    p.add("box", T(0, 0, 0.6) @ S(1.6, 0.08, 0.08), "8c5a33")
    for x in (-0.75, 0.75):
        p.add("box", T(x, 0, 0.3) @ S(0.08, 0.08, 0.6), "8c5a33")
    for i, col in enumerate(("3fb7e8", "ff6f91", "ffd23f", "7ed957", "b06cff")):
        p.add("box", T(-0.6 + i * 0.3, -0.07, 0.9) @ RY(0.15) @ S(0.08, 0.02, 1.7), col)


# --------------------------------------------------------------------------- Holo City
@prop
def drone(p: Prop):
    p.add("box", T(0, 0, 0) @ S(0.5, 0.5, 0.16), "2b2f36", bevel=0.03)
    for (x, y) in ((-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4)):
        p.tube((0, 0, 0), (x, y, 0.05), 0.03, "2b2f36", seg=5)
        p.add("cyl", T(x, y, 0.06) @ S(1, 1, 0.01), "aab4bf", r1=0.2, seg=12, weight=1.0)
    p.add("ball", T(0, -0.27, -0.06) @ S(0.16), "1d1e22")
    p.add("ball", T(0, -0.33, -0.06) @ S(0.07), "6fd3ff", glow=True)
    p.add("box", T(0, 0, -0.1) @ S(0.12, 0.12, 0.04), "ff3b8a", glow=True)


@prop
def holo_kiosk(p: Prop):
    p.add("box", T(0, 0, 1.1) @ S(1.6, 1.2, 2.2), "2b2f46", bevel=0.04)
    p.add("box", T(0, -0.61, 1.25) @ S(1.3, 0.02, 1.0), "141826")
    p.add("box", T(0, -0.62, 1.25) @ S(1.2, 0.02, 0.9), "6fd3ff", glow=True)
    p.add("box", T(0, 0, 2.25) @ S(1.8, 1.4, 0.1), "ff3b8a", glow=True)


@prop
def neon_arrow(p: Prop):
    p.add("box", T(0, 0, 1.0) @ S(0.1, 0.1, 2.0), "2b2f36")
    p.add("box", T(0, 0.02, 2.3) @ S(1.5, 0.12, 0.7), "1b1f2e", bevel=0.03)
    p.add("tri", T(0, -0.05, 2.3), "ff3b8a", glow=True, pts=[(-0.55, 0, -0.18), (0.25, 0, -0.18), (0.25, 0, -0.3), (0.62, 0, 0.0)][:3])
    p.add("box", T(-0.1, -0.05, 2.3) @ S(0.8, 0.02, 0.14), "6fd3ff", glow=True)
    p.add("tri", T(0.3, -0.06, 2.3), "6fd3ff", glow=True, pts=[(0, 0, -0.24), (0.36, 0, 0.0), (0, 0, 0.24)])


# --------------------------------------------------------------------------- Themen
@prop
def cactus(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 2.2), "4f8f4a", r1=0.24, r2=0.2, seg=10)
    p.add("ball", T(0, 0, 2.2) @ S(0.4), "4f8f4a")
    for s, z in ((-1, 0.9), (1, 1.3)):
        p.tube((0, 0, z), (s * 0.55, 0, z), 0.13, "4f8f4a")
        p.tube((s * 0.55, 0, z), (s * 0.55, 0, z + 0.7), 0.13, "4f8f4a")
        p.add("ball", T(s * 0.55, 0, z + 0.7) @ S(0.26), "4f8f4a")
    p.add("ball", T(0, -0.05, 2.4) @ S(0.14), "ff6f91")


@prop
def mine_cart(p: Prop):
    p.add("box", T(0, 0, 0.55) @ S(1.2, 0.8, 0.6), "6a7178", bevel=0.03)
    p.add("box", T(0, 0, 0.86) @ S(1.24, 0.84, 0.06), "8c5a33")
    for x in (-0.38, 0.38):
        for y in (-0.42, 0.42):
            p.add("cyl", T(x, y, 0.2) @ RX(math.pi / 2) @ S(1, 1, 0.08), "2b2f36", r1=0.18, seg=10)
    for k in range(5):
        p.add("ball", T(-0.35 + k * 0.18, 0.05 * (k % 2), 0.95) @ S(0.24, 0.24, 0.3), "8ff2ff", glow=True, seg=6, ring=4)


@prop
def lollipop(p: Prop):
    p.add("cyl", T(0, 0, 0) @ S(1, 1, 2.4), "f2f2ee", r1=0.06, seg=8)
    p.add("cyl", T(0, 0, 2.7) @ RX(math.pi / 2) @ S(1, 1, 0.16), "ff6f91", r1=0.55, seg=20)
    p.add("torus", T(0, -0.09, 2.7) @ RX(math.pi / 2), "f2f2ee", r=0.32, t=0.06, seg=18, sides=5)
    p.add("torus", T(0, -0.09, 2.7) @ RX(math.pi / 2), "ffd23f", r=0.15, t=0.05, seg=14, sides=5)


@prop
def lava_warning(p: Prop):
    p.add("box", T(0, 0, 0.8) @ S(0.08, 0.08, 1.6), "2b2f36")
    p.add("tri", T(0, -0.05, 1.5), "ffd23f", pts=[(-0.45, 0, -0.35), (0.45, 0, -0.35), (0, 0, 0.42)])
    p.add("tri", T(0, -0.06, 1.5), "1d1e22", pts=[(-0.32, 0, -0.27), (0.32, 0, -0.27), (0, 0, 0.29)])
    p.add("tri", T(0, -0.07, 1.47), "ff6a2a", glow=True, pts=[(-0.18, 0, -0.2), (0.18, 0, -0.2), (0, 0, 0.12)])


@prop
def satellite_dish(p: Prop):
    p.add("box", T(0, 0, 0.6) @ S(0.16, 0.16, 1.2), "8a8f96")
    p.add("cyl", T(0, 0, 1.25) @ RX(-0.7) @ S(1, 1, 0.25), "e8ecf0", r1=0.85, r2=0.15, seg=18)
    p.tube((0, 0, 1.4), (0, -0.55, 1.9), 0.025, "8a8f96")
    p.add("ball", T(0, -0.55, 1.9) @ S(0.1), "ff3b2e", glow=True)


@prop
def abacus(p: Prop):
    for x in (-0.9, 0.9):
        p.add("box", T(x, 0, 0.9) @ S(0.12, 0.2, 1.8), "8c5a33")
    for i in range(5):
        z = 0.4 + i * 0.3
        p.add("cyl", T(-0.9, 0, z) @ RY(math.pi / 2) @ S(1, 1, 1.8), "c9ced3", r1=0.02, seg=6)
        for k in range(5):
            p.add("ball", T(-0.65 + k * 0.18 + (0.5 if k >= 3 else 0) * (i % 2), 0, z) @ S(0.16, 0.12, 0.16),
                  ["ff6f91", "ffd23f", "3fb7e8", "7ed957", "b06cff"][i], seg=10, ring=6)


@prop
def tumbleweed(p: Prop):
    for k in range(7):
        p.add("torus", T(0, 0, 0.4) @ RZ(k * 0.45) @ RX(k * 0.8), "a9895a", r=0.38, t=0.02, seg=14, sides=4)


@prop
def bush_round(p: Prop):
    for (x, y, z, s) in ((0, 0, 0.4, 0.9), (0.4, 0.1, 0.32, 0.7), (-0.38, 0.05, 0.3, 0.65), (0.05, -0.1, 0.72, 0.6)):
        p.add("ball", T(x, y, z) @ S(s), "4e9a45", seg=10, ring=6)
    for k in range(6):
        a = k * 1.05
        p.add("ball", T(math.cos(a) * 0.42, math.sin(a) * 0.42 - 0.08, 0.45 + 0.15 * math.sin(a * 3)) @ S(0.1), "ff8fb0" if k % 2 else "fff1a8", seg=6, ring=4)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = bpy.data.collections.new("KartDetails")
    bpy.context.scene.collection.children.link(collection)
    stats = []
    for name, fn in PROPS.items():
        p = Prop(name)
        fn(p)
        for obj in p.build(collection):
            stats.append((obj.name, len(obj.data.polygons)))
    for obj in collection.objects:
        obj.select_set(True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    kwargs = dict(filepath=str(OUT), export_format="GLB", use_selection=True, export_yup=True,
                  export_animations=False, export_cameras=False, export_lights=False,
                  export_materials="NONE", export_normals=True, export_texcoords=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs, export_colors=True)
    total = 0
    for name, faces in stats:
        total += faces
        print(f"{name:24s} {faces:5d} faces")
    print(f"{len(stats)} objects, {total} faces -> {OUT.relative_to(ROOT)} {OUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
