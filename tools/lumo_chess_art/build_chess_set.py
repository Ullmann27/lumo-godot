#!/usr/bin/env python3
"""Lumo Schach: Figuren, Brett, Holztexturen und Figurensymbole – alles Eigenbau.

Aufruf:
  /home/user/tools/bpyenv/bin/python tools/lumo_chess_art/build_chess_set.py [--only models,textures,icons]

Ausgabe unter assets/chess/:
  models/<figur>.glb   pawn, rook, knight, bishop, queen, king, board
  textures/*.webp      Brettfläche mit Intarsienrand, Ahorn und Nussbaum für Figuren und Rahmen
  icons/<w|b>_<figur>.webp  Figurensymbole für die Draufsicht (Cycles-Render der Modelle)

Konvention: Meter, Blender Z oben. Ein Feld ist 0,1 m breit. Figuren stehen
auf dem Ursprung und schauen nach −Y (in Godot +Z). Materialnamen sind
Schlüssel: „wood“ (Godot setzt hell/dunkel ein), „felt“ (Filz unter dem Fuß),
„board_top“, „frame“, „board_felt“.

Formen: Drehkörper aus Profilen, deren Ecken mit Chaikin-Glättung weich
gerundet werden; der Springer ist eine abgerundete Silhouette (Bevel +
Subdivision). Danach glatte Normalen. Keine fremde Geometrie, keine fremden Bilder.
"""
from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy  # bpy zuerst: erst danach ist bmesh importierbar
import bmesh
from mathutils import Matrix, Vector

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "chess"
SQUARE = 0.1
SEG = 48


def linear(hex_color: str) -> tuple:
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


_MATS: dict[str, bpy.types.Material] = {}
BASE = {"wood": "e8c896", "felt": "1f5a3a", "board_top": "ffffff", "frame": "5b3a26", "board_felt": "1f5a3a"}


def mat(name: str) -> bpy.types.Material:
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = linear(BASE.get(name, "ffffff"))
    p.inputs["Roughness"].default_value = 0.35
    _MATS[name] = m
    return m


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def to_object(name: str, bm: bmesh.types.BMesh, material: str, smooth: bool = True, uv_top: tuple | None = None) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        face.smooth = smooth
        for loop in face.loops:
            co = loop.vert.co
            if uv_top is not None:
                x0, y0, w, h = uv_top
                loop[uv_layer].uv = ((co.x - x0) / w, (co.y - y0) / h)
            else:
                loop[uv_layer].uv = (math.atan2(co.y, co.x) / math.tau + 0.5, co.z * 8.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat(material))
    return ob


def chaikin(points: list, iterations: int = 3, keep: set | None = None) -> list:
    """Rundet Ecken einer offenen Linie; Endpunkte (und Indizes in keep) bleiben."""
    keep = keep or set()
    pts = [(Vector(p), i in keep) for i, p in enumerate(points)]
    for _ in range(iterations):
        out = [pts[0]]
        for i in range(len(pts) - 1):
            (a, ka), (b, kb) = pts[i], pts[i + 1]
            if i > 0 and not ka:
                out.append((a * 0.75 + b * 0.25, False))
            elif i > 0:
                out.append((a, True))
            if i < len(pts) - 2 and not kb:
                out.append((a * 0.25 + b * 0.75, False))
        out.append(pts[-1])
        pts = out
    return simplify([(p.x, p.y) for p, _ in pts])


def simplify(points: list, degrees: float = 7.0, min_len: float = 0.0006) -> list:
    """Entfernt Punkte, an denen die Linie kaum knickt (spart Dreiecke)."""
    out = [points[0]]
    for i in range(1, len(points) - 1):
        a = Vector(out[-1])
        b = Vector(points[i])
        c = Vector(points[i + 1])
        d1 = b - a
        d2 = c - b
        if d1.length < 1e-9 or d2.length < 1e-9:
            continue
        if math.degrees(d1.angle(d2)) < degrees and (b - a).length < 0.008:
            continue
        if (b - a).length < min_len:
            continue
        out.append(points[i])
    out.append(points[-1])
    return out


def arc(cx: float, cz: float, r: float, a0: float, a1: float, n: int) -> list:
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * r, cz + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * r)
            for i in range(n + 1)]


def lathe_bm(profile: list, segments: int = SEG) -> bmesh.types.BMesh:
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        a = math.tau * i / segments
        rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for r, z in profile])
    for i in range(segments):
        ra, rb = rings[i], rings[(i + 1) % segments]
        for k in range(len(profile) - 1):
            bm.faces.new((ra[k], rb[k], rb[k + 1], ra[k + 1]))
    if profile[0][0] > 1e-5:
        bm.faces.new([r[0] for r in reversed(rings)])
    if profile[-1][0] > 1e-5:
        bm.faces.new([r[-1] for r in rings])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return bm


def lathe(name: str, profile: list, material: str = "wood", segments: int = SEG) -> bpy.types.Object:
    return to_object(name, lathe_bm(profile, segments), material)


def boolean(target: bpy.types.Object, cutter: bpy.types.Object, operation: str = "DIFFERENCE") -> None:
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = operation
    mod.object = cutter
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def box(name: str, at: tuple, size: tuple, rot_z: float = 0.0, rot_x: float = 0.0, material: str = "wood", bevel: float = 0.0) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3, affect="EDGES", profile=0.5)
    m = Matrix.Translation(Vector(at)) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Rotation(rot_x, 4, "X")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return to_object(name, bm, material, smooth=bevel > 0)


def sphere(name: str, at: tuple, radius: float, material: str = "wood", scale: tuple = (1, 1, 1)) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    return to_object(name, bm, material)


def join(objects: list, name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def finish(ob: bpy.types.Object, subdiv: int = 0, weighted: bool = True) -> bpy.types.Object:
    bpy.context.view_layer.objects.active = ob
    if subdiv > 0:
        mod = ob.modifiers.new("smooth", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    if weighted:
        mod = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.keep_sharp = False
        mod.weight = 50
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


# ===================================================================== Figuren
#
# Profile: (Radius, Höhe) von der Achse unten nach oben. Fuß mit Filzring,
# Wulst, Hals, Kopf. Die Höhen staffeln sich deutlich, damit jede Figur auch
# schräg von oben sofort erkennbar ist: Bauer 0,072 · Turm 0,086 · Springer
# 0,098 · Läufer 0,108 · Dame 0,128 · König 0,148 m.


def foot(r: float) -> list:
    """Gedrechselter Fuß: breite Platte, Hohlkehle, Wulst."""
    return [(0.0, 0.0006), (r - 0.002, 0.0006), (r, 0.003), (r, 0.0075), (r - 0.004, 0.0105), (r - 0.006, 0.012),
            (r - 0.0045, 0.0145), (r - 0.0045, 0.0175), (r - 0.0085, 0.0205)]


def felt_pad(r: float) -> bpy.types.Object:
    bm = lathe_bm([(0.0, 0.0), (r - 0.0025, 0.0), (r - 0.002, 0.0008), (0.0, 0.0008)], 48)
    return to_object("Felt", bm, "felt")


def build_pawn() -> list:
    r = 0.031
    prof = foot(r) + [(0.017, 0.026), (0.0105, 0.040), (0.0092, 0.046), (0.0165, 0.0485), (0.017, 0.0515),
                      (0.0098, 0.0535)]
    body = chaikin(prof, 3, keep={0})
    head = arc(0.0, 0.0605, 0.0128, -52, 90, 16)
    profile = body + head[1:]
    return [lathe("Pawn", profile), felt_pad(r)]


def build_rook() -> list:
    r = 0.034
    prof = foot(r) + [(0.0215, 0.026), (0.0195, 0.060), (0.0205, 0.064), (0.0255, 0.068), (0.0262, 0.0745),
                      (0.0262, 0.086), (0.0185, 0.086), (0.0175, 0.079), (0.0, 0.079)]
    profile = chaikin(prof, 2, keep={0, len(prof) - 1, len(prof) - 2, len(prof) - 3, len(prof) - 4})
    rook = lathe("Rook", profile)
    # Zinnen: fünf Scharten in den Kranz schneiden.
    for i in range(5):
        a = math.tau * i / 5 + 0.3
        cutter = box("Cut", (math.cos(a) * 0.024, math.sin(a) * 0.024, 0.088), (0.02, 0.0085, 0.016), rot_z=a)
        boolean(rook, cutter)
    # Schmales Zierband unter dem Kranz.
    band = lathe("Band", chaikin([(0.0, 0.0612), (0.0212, 0.0612), (0.0218, 0.0628), (0.0212, 0.0644), (0.0, 0.0644)], 2, keep={0, 4}))
    return [rook, band, felt_pad(r)]


def build_bishop() -> list:
    r = 0.032
    prof = foot(r) + [(0.0175, 0.027), (0.0105, 0.052), (0.0095, 0.0605), (0.0185, 0.0635), (0.0188, 0.0665),
                      (0.0110, 0.0685), (0.0128, 0.0745), (0.0158, 0.0835), (0.0142, 0.0925), (0.0085, 0.1005), (0.0035, 0.1035)]
    body = chaikin(prof, 3, keep={0})
    knob = arc(0.0, 0.1072, 0.0048, -40, 90, 8)
    bishop = lathe("Bishop", body + knob)
    # Kerbe in der Mitra: schräger, schmaler Schnitt.
    cutter = box("Slit", (0.0, -0.011, 0.0885), (0.04, 0.012, 0.0032), rot_x=math.radians(-38))
    boolean(bishop, cutter)
    return [bishop, felt_pad(r)]


def build_queen() -> list:
    r = 0.036
    prof = foot(r) + [(0.0195, 0.028), (0.0118, 0.060), (0.0102, 0.080), (0.0195, 0.0845), (0.0198, 0.0875),
                      (0.0118, 0.0895), (0.0135, 0.0985), (0.0215, 0.111), (0.0222, 0.1145), (0.0165, 0.1155),
                      (0.0105, 0.117)]
    body = chaikin(prof, 3, keep={0})
    dome = arc(0.0, 0.112, 0.0105, 10, 90, 10)
    queen = lathe("Queen", body + dome[1:])
    parts = [queen]
    # Krone: neun kleine Kugeln auf dem Rand, eine Perle oben.
    for i in range(9):
        a = math.tau * i / 9
        parts.append(sphere("Pearl", (math.cos(a) * 0.0205, math.sin(a) * 0.0205, 0.1175), 0.0042))
    parts.append(sphere("Top", (0.0, 0.0, 0.1265), 0.0058))
    parts.append(felt_pad(r))
    return parts


def build_king() -> list:
    r = 0.037
    prof = foot(r) + [(0.0205, 0.028), (0.0125, 0.063), (0.0108, 0.085), (0.0205, 0.0895), (0.0208, 0.0925),
                      (0.0125, 0.0945), (0.0142, 0.104), (0.0205, 0.1165), (0.0205, 0.1205), (0.0150, 0.1215)]
    body = chaikin(prof, 3, keep={0})
    dome = arc(0.0, 0.1175, 0.0115, 25, 90, 10)
    king = lathe("King", body + dome[1:])
    # Kreuz mit runden Kanten.
    upright = box("CrossV", (0.0, 0.0, 0.1385), (0.0068, 0.0068, 0.0215), bevel=0.0019)
    beam = box("CrossH", (0.0, 0.0, 0.1405), (0.0195, 0.0066, 0.0066), bevel=0.0019)
    return [king, upright, beam, felt_pad(r)]


def build_knight() -> list:
    r = 0.034
    base_prof = foot(r) + [(0.0205, 0.0245), (0.0195, 0.0275), (0.0, 0.0285)]
    base = lathe("KnightBase", chaikin(base_prof, 3, keep={0, len(base_prof) - 1}))
    # Seitenansicht des Pferdekopfs (y nach vorn = Blickrichtung −Y in Blender
    # wird unten gespiegelt). Punkte gegen den Uhrzeigersinn.
    sil = [(-0.021, 0.024), (-0.0235, 0.046), (-0.0215, 0.066), (-0.0165, 0.082), (-0.0095, 0.0925),
           (-0.0045, 0.0985), (-0.0015, 0.1035), (0.0018, 0.0975), (0.0058, 0.0945), (0.0145, 0.0885),
           (0.0255, 0.0765), (0.0322, 0.0675), (0.0328, 0.0615), (0.0285, 0.0575), (0.0195, 0.0585),
           (0.0175, 0.0585), (0.0155, 0.0525), (0.0165, 0.042), (0.0185, 0.030), (0.0195, 0.024)]
    closed = sil + [sil[0]]
    smooth = chaikin(closed, 3)[:-1]
    bm = bmesh.new()
    half = 0.0118
    front = [bm.verts.new((-half, y, z)) for y, z in smooth]
    back = [bm.verts.new((half, y, z)) for y, z in smooth]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(smooth)
    for i in range(n):
        bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    edges = [e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) < 1e-6]
    bmesh.ops.bevel(bm, geom=edges, offset=0.0038, segments=4, affect="EDGES", profile=0.5)
    # Maul und Stirn schmaler als der Hals: Kopf verjüngt sich nach vorn.
    for v in bm.verts:
        t = min(1.0, max(0.0, (v.co.y + 0.004) / 0.036))
        v.co.x *= 1.0 - 0.32 * t
    head = to_object("KnightHead", bm, "wood")
    finish(head, subdiv=1, weighted=False)
    parts = [base, head]
    # Mähne: Reihe abgeflachter Kugeln hinten am Hals.
    back = [Vector(p) for p in [(-0.0235, 0.046), (-0.0215, 0.066), (-0.0165, 0.082), (-0.0095, 0.0925), (-0.0045, 0.0985)]]
    for i in range(10):
        t = i / 9.0 * (len(back) - 1)
        k = min(int(t), len(back) - 2)
        at = back[k].lerp(back[k + 1], t - k)
        parts.append(sphere("Mane", (0.0, at.x + 0.0012, at.y), 0.0050 - 0.0012 * i / 9.0, scale=(0.72, 0.9, 1.3)))
    # Augen: kleine Kugeln, leicht erhaben, auf beiden Seiten; Nüstern vorn.
    for side in (-1, 1):
        parts.append(sphere("Eye", (side * 0.0098, 0.0115, 0.0845), 0.0028, scale=(0.6, 1.0, 1.0)))
        parts.append(sphere("Nostril", (side * 0.0058, 0.0305, 0.0635), 0.0021, scale=(0.7, 1.0, 1.0)))
    parts.append(felt_pad(r))
    # Blender −Y ist vorn; die Silhouette schaut nach +Y: einmal umdrehen.
    for ob in parts:
        ob.rotation_euler = (0, 0, math.pi)
    return parts


HEIGHTS = {"pawn": 0.073, "rook": 0.088, "knight": 0.104, "bishop": 0.112, "queen": 0.132, "king": 0.150}

PIECES = {
    "pawn": build_pawn, "rook": build_rook, "knight": build_knight,
    "bishop": build_bishop, "queen": build_queen, "king": build_king,
}


def export(name: str, objects: list) -> None:
    folder = OUT / "models"
    folder.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    path = folder / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_animations=False, export_cameras=False, export_lights=False,
                              export_materials="EXPORT")
    tris = sum(len(p.vertices) - 2 for ob in objects if ob.type == "MESH" for p in ob.data.polygons)
    print(f"[chess] {name}: {path.stat().st_size // 1024} KB, ~{tris} Dreiecke")


def build_piece(name: str) -> list:
    parts = PIECES[name]()
    wood = [p for p in parts if p.data.materials[0].name == "wood"]
    felt = [p for p in parts if p.data.materials[0].name == "felt"]
    body = join(wood, name.capitalize())
    if name != "knight":
        finish(body)
    else:
        for poly in body.data.polygons:
            poly.use_smooth = True
    out = [body] + felt
    return out


# ======================================================================= Brett

BOARD_INNER = 0.8   # 8 Felder
BOARD_INLAY = 0.84  # mit Intarsienband
BOARD_OUTER = 0.95  # mit Rahmen
BOARD_THICK = 0.03


def build_board() -> list:
    parts = []
    h = BOARD_THICK
    # Rahmen: Platte mit weich gerundeter Oberkante, Fase unten.
    o = BOARD_OUTER / 2
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((BOARD_OUTER, BOARD_OUTER, h)), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((0, 0, h / 2)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.0045, segments=4, affect="EDGES", profile=0.5)
    frame = to_object("Frame", bm, "frame")
    frame.data.polygons.foreach_set("use_smooth", [True] * len(frame.data.polygons))
    parts.append(frame)
    # Spielfläche (mit Intarsienband) als eigene Fläche mit 0..1-UV, minimal erhaben.
    i = BOARD_INLAY / 2
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, h + 0.0004)) for x, y in [(-i, -i), (i, -i), (i, i), (-i, i)]]
    bm.faces.new(vs)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=7, use_grid_fill=True)
    parts.append(to_object("BoardTop", bm, "board_top", smooth=False, uv_top=(-i, -i, 2 * i, 2 * i)))
    # Schmale Kehle zwischen Rahmen und Fläche (dunkle Fuge, gibt Tiefe).
    bm = bmesh.new()
    k = i + 0.003
    outer = [bm.verts.new((x, y, h + 0.0002)) for x, y in [(-k, -k), (k, -k), (k, k), (-k, k)]]
    inner = [bm.verts.new((x, y, h + 0.0002)) for x, y in [(-i, -i), (i, -i), (i, i), (-i, i)]]
    for n in range(4):
        bm.faces.new((outer[n], outer[(n + 1) % 4], inner[(n + 1) % 4], inner[n]))
    parts.append(to_object("Groove", bm, "frame", smooth=False))
    # Filz unten.
    bm = bmesh.new()
    f = o - 0.01
    vs = [bm.verts.new((x, y, -0.0005)) for x, y in [(-f, -f), (-f, f), (f, f), (f, -f)]]
    bm.faces.new(vs)
    parts.append(to_object("Felt", bm, "board_felt", smooth=False))
    return parts


# =================================================================== Texturen


def _noise(shape: tuple, scale: float, rng: np.random.Generator, stretch: float = 1.0, vertical: bool = True) -> np.ndarray:
    """Weiches Rauschen durch Hochskalieren kleiner Zufallsfelder (mehrere Oktaven).
    `stretch` > 1 zieht das Rauschen entlang der Faser (vertical: entlang y)."""
    h, w = shape
    total = np.zeros(shape, np.float32)
    amp = 1.0
    norm = 0.0
    s = scale
    for _ in range(4):
        sy, sx = (s * stretch, s) if vertical else (s, s * stretch)
        gh, gw = max(2, int(h / sy)), max(2, int(w / sx))
        small = rng.random((gh, gw)).astype(np.float32)
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        total += np.asarray(img, np.float32) / 255.0 * amp
        norm += amp
        amp *= 0.5
        s /= 2.2
    return total / norm


def wood(shape: tuple, light: tuple, dark: tuple, rng: np.random.Generator, rings: float = 38.0,
         warp: float = 3.0, vertical: bool = True, pores: float = 0.12) -> np.ndarray:
    """Maserung: lange, leicht gewellte Jahresringe (Sinus über eine entlang der
    Faser gestreckte, gestörte Koordinate), feine Faserstriche und Poren."""
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    along, across = (yy, xx) if vertical else (xx, yy)
    span = max(w if vertical else h, 1)
    n1 = _noise(shape, 48.0, rng, stretch=7.0, vertical=vertical)
    n2 = _noise(shape, 10.0, rng, stretch=9.0, vertical=vertical)
    coord = across / span * rings + n1 * warp + n2 * 0.5 + np.sin(along / 140.0 + across / 300.0) * 0.35
    ring = 0.5 + 0.5 * np.sin(coord * math.tau)
    # Spätholz schmal und dunkel, Frühholz breit und hell.
    ring = np.clip((ring - 0.35) / 0.65, 0, 1) ** 2.6
    fibre = _noise(shape, 1.6, rng, stretch=30.0, vertical=vertical)
    pore = _noise(shape, 1.2, rng, stretch=6.0, vertical=vertical)
    pore = np.clip((pore - 0.62) * 4.0, 0, 1)
    figure = _noise(shape, 90.0, rng, stretch=2.0, vertical=vertical)
    t = np.clip(ring * 0.62 + (fibre - 0.5) * 0.35 + pore * pores + (figure - 0.5) * 0.25 + 0.12, 0, 1)
    light_c = np.array(light, np.float32)
    dark_c = np.array(dark, np.float32)
    rgb = light_c[None, None, :] * (1 - t[..., None]) + dark_c[None, None, :] * t[..., None]
    return rgb


def save(img: np.ndarray, name: str, quality: int = 92) -> None:
    folder = OUT / "textures"
    folder.mkdir(parents=True, exist_ok=True)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    out.save(folder / f"{name}.webp", quality=quality, method=6)
    print(f"[chess] Textur {name}: {out.size[0]}x{out.size[1]}")


MAPLE = ((238, 214, 172), (205, 160, 104))
WALNUT = ((112, 72, 44), (58, 34, 20))


def build_textures() -> None:
    rng = np.random.default_rng(1118)
    size = 2048
    px_per_m = size / BOARD_INLAY
    img = np.zeros((size, size, 3), np.float32)
    # Intarsienband: Nussbaum, darin eine helle Ahornader und kleine Rauten.
    band = wood((size, size), WALNUT[0], WALNUT[1], rng, rings=60, vertical=False)
    img[:] = band
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    inner0 = (BOARD_INLAY - BOARD_INNER) / 2 * px_per_m
    edge = np.minimum(np.minimum(xx, yy), np.minimum(size - 1 - xx, size - 1 - yy))
    vein = (edge > inner0 * 0.42) & (edge < inner0 * 0.58)
    maple_band = wood((size, size), MAPLE[0], MAPLE[1], rng, rings=24, vertical=True)
    img[vein] = maple_band[vein]
    # Felder: abwechselnd Ahorn und Nussbaum, Maserung jedes Feld eigen.
    cell = BOARD_INNER / 8 * px_per_m
    for rank in range(8):
        for file in range(8):
            x0 = int(round(inner0 + file * cell))
            y0 = int(round(inner0 + (7 - rank) * cell))
            x1 = int(round(inner0 + (file + 1) * cell))
            y1 = int(round(inner0 + (8 - rank) * cell))
            light = (file + rank) % 2 == 1
            shape = (y1 - y0, x1 - x0)
            sub = np.random.default_rng(rank * 8 + file + 7)
            pal = MAPLE if light else WALNUT
            tile = wood(shape, pal[0], pal[1], sub, rings=5 + sub.random() * 3, warp=1.2,
                        vertical=(file + rank) % 2 == 0, pores=0.18)
            # Leichte Farbabweichung je Feld wie bei echtem Furnier.
            tile *= 0.95 + sub.random() * 0.08
            img[y0:y1, x0:x1] = tile
            # Feine Fuge zwischen den Feldern.
            img[y0:y0 + 1, x0:x1] *= 0.78
            img[y0:y1, x0:x0 + 1] *= 0.78
    # Rand der Spielfläche: dunkle Fuge.
    grid = (edge > inner0 - 2) & (edge < inner0 + 1)
    img[grid] *= 0.55
    save(img, "board_top")
    # Figurenholz (wird in Godot dreiplanar aufgelegt): feine, dichte Maserung.
    save(wood((1024, 1024), (246, 226, 188), (214, 172, 118), np.random.default_rng(5), rings=26, warp=2.0, pores=0.1), "piece_maple")
    save(wood((1024, 1024), (84, 50, 30), (34, 19, 10), np.random.default_rng(6), rings=26, warp=2.0, pores=0.14), "piece_walnut")
    # Rahmen: Nussbaum, längs gemasert.
    save(wood((1024, 1024), (122, 80, 50), (66, 39, 23), np.random.default_rng(9), rings=30, warp=2.0, vertical=False), "frame_walnut")
    # Filz unter Brett und Figuren.
    felt = _noise((256, 256), 2.0, np.random.default_rng(3))
    base = np.array((34, 92, 58), np.float32)
    save(base[None, None, :] * (0.85 + felt[..., None] * 0.3), "felt_green")
    # Weicher Kontaktschatten (rund) für jede Figur.
    s = 256
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    d = np.sqrt((xx - s / 2 + 0.5) ** 2 + (yy - s / 2 + 0.5) ** 2) / (s / 2)
    alpha = np.clip(1.0 - d, 0, 1) ** 1.6
    rgba = np.zeros((s, s, 4), np.uint8)
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    (OUT / "textures").mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT / "textures" / "piece_shadow.webp", lossless=True)
    print("[chess] Textur piece_shadow")


# ===================================================== Figurensymbole (Render)


def _image_texture(path: Path) -> bpy.types.Image:
    return bpy.data.images.load(str(path), check_existing=True)


def _render_material(name: str, texture: str, roughness: float) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = _image_texture(OUT / "textures" / f"{texture}.webp")
    tex.projection = "BOX"
    tex.projection_blend = 0.3
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (9.0, 9.0, 9.0)
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = 0.6
        p.inputs["Coat Roughness"].default_value = 0.12
    return m


def build_icons(size: int = 256) -> None:
    folder = OUT / "icons"
    folder.mkdir(parents=True, exist_ok=True)
    for name in PIECES:
        for colour in ("w", "b"):
            reset_scene()
            parts = build_piece(name)
            body = parts[0]
            body.data.materials.clear()
            body.data.materials.append(_render_material("m", "piece_maple" if colour == "w" else "piece_walnut", 0.32))
            for felt in parts[1:]:
                bpy.data.objects.remove(felt, do_unlink=True)
            scene = bpy.context.scene
            scene.render.engine = "CYCLES"
            scene.cycles.samples = 48
            scene.cycles.use_denoising = True
            scene.render.film_transparent = True
            scene.render.resolution_x = size
            scene.render.resolution_y = size
            scene.view_settings.view_transform = "Standard"
            scene.view_settings.look = "None"
            world = bpy.data.worlds.new("w")
            world.use_nodes = True
            world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.52, 0.5, 1)
            world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
            scene.world = world
            cam_data = bpy.data.cameras.new("cam")
            cam_data.type = "ORTHO"
            height = HEIGHTS[name]
            cam_data.ortho_scale = 0.05 + height * 0.82
            cam = bpy.data.objects.new("cam", cam_data)
            scene.collection.objects.link(cam)
            # Leicht von oben vorn, damit Krone und Zinnen lesbar sind.
            tilt = math.radians(14)
            dist = 1.0
            target = Vector((0, 0, height * 0.5 + 0.004))
            cam.location = target + Vector((0, -math.cos(tilt) * dist, math.sin(tilt) * dist))
            cam.rotation_euler = (math.pi / 2 - tilt, 0, 0)
            if name == "knight":
                # Springer im Profil, Blick nach links wie in Schachdiagrammen.
                body.rotation_euler = (0, 0, body.rotation_euler[2] - math.pi / 2)
            scene.camera = cam
            for loc, energy, size_l in [((-0.35, -0.45, 0.55), 16.0, 0.35), ((0.45, -0.2, 0.25), 6.0, 0.5),
                                        ((0.1, 0.5, 0.4), 12.0, 0.25)]:
                light_data = bpy.data.lights.new("l", "AREA")
                light_data.energy = energy * (0.42 if colour == "w" else 1.8)
                light_data.size = size_l
                light = bpy.data.objects.new("l", light_data)
                light.location = loc
                direction = Vector((0, 0, 0.07)) - Vector(loc)
                light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
                scene.collection.objects.link(light)
            path = folder / f"{colour}_{name}.png"
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            im = Image.open(path).convert("RGBA")
            # Weicher dunkler Rand: hebt helle Figuren vom hellen Feld ab.
            alpha = im.split()[3]
            halo = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.2))
            ring = Image.new("RGBA", im.size, (40, 22, 10, 0) if colour == "w" else (255, 236, 200, 0))
            ring.putalpha(halo.point(lambda v: int(v * (0.85 if colour == "w" else 0.7))))
            ring.alpha_composite(im)
            ring.save(folder / f"{colour}_{name}.webp", lossless=False, quality=94, method=6)
            path.unlink()
            print(f"[chess] Symbol {colour}_{name}")


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="models,textures,icons")
    args = parser.parse_args(argv)
    only = set(args.only.split(","))
    if "textures" in only:
        build_textures()
    if "models" in only:
        for name in PIECES:
            reset_scene()
            export(name, build_piece(name))
        reset_scene()
        export("board", build_board())
    if "icons" in only:
        build_icons()


if __name__ == "__main__":
    main()
