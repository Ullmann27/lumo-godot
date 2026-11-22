#!/usr/bin/env python3
"""Lumo Schach: Figuren, Brett, Holztexturen und Figurensymbole – alles Eigenbau.

Aufruf:
  blender -b -t 2 -P tools/lumo_chess_art/build_chess_set.py -- --only models,textures,icons

Ausgabe unter assets/chess/:
  models/<figur>.glb   pawn, rook, knight, bishop, queen, king, board
  textures/*.webp      Brettfläche mit Intarsienrand, Ahorn und Nussbaum für Figuren und Rahmen
  icons/<w|b>_<figur>.webp  Figurensymbole für die Draufsicht (Cycles-Render der Modelle)

Konvention: Meter, Blender Z oben. Ein Feld ist 0,1 m breit. Figuren stehen
auf dem Ursprung und schauen nach −Y (in Godot +Z). Materialnamen sind
Schlüssel: „wood“ (Godot setzt hell/dunkel ein), „felt“ (Filz unter dem Fuß),
„board_top“, „frame“, „board_felt“.

Formen: Stufenfuß mit Messingband, gedrehte Säulen und eigenständig gezeichnete
Profile. Die Figuren der Draufsicht werden aus derselben Geometrie gerendert.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy  # bpy zuerst: erst danach ist bmesh importierbar
import bmesh
from mathutils import Matrix, Vector

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "chess"
SQUARE = 0.1
SEG = 48


def linear(hex_color: str) -> tuple:
    srgb = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1.0,)


_MATS: dict[str, bpy.types.Material] = {}
BASE = {"brass": "d9ad60", "wood": "f3eee2", "felt": "1f5a3a", "board_top": "ffffff", "frame": "5b3a26", "board_felt": "1f5a3a"}


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


def profile(name, points, material="wood", sides=32):
    """Turn the workshop drawing (radius and height in millimetres)."""
    return lathe(name, [(r / 1000, z / 1000) for r, z in points], material, sides)


def base(name, radius, shoulder, height):
    # Stepped ceramic plinth, thin brass collar, then a tapered column.
    body = profile(name, [(0, 1), (radius - 3, 1), (radius, 4), (radius, 8),
                          (radius - 3, 11), (radius - 9, 13), (shoulder, height), (0, height)])
    brass = profile("Collar", [(radius, 4), (radius + .2, 4.6),
                               (radius + .2, 6.6), (radius, 7)], "brass")
    pad = profile("Felt", [(0, 0), (radius - 3, 0), (radius - 3, 1), (0, 1)], "felt")
    return [body, brass, pad]


def silhouette(name, outline, half_width, axis="y"):
    """Bevel an original drawn outline into a solid standing on the plinth."""
    bm = bmesh.new()
    layers = []
    for half in [-half_width, half_width]:
        layers.append([bm.verts.new((half/1000, u/1000, z/1000) if axis == "y"
                                    else (u/1000, half/1000, z/1000)) for u, z in outline])
    bm.faces.new(layers[0])
    bm.faces.new(layers[1][::-1])
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((layers[0][i], layers[1][i], layers[1][j], layers[0][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.0014, segments=3, affect="EDGES")
    return to_object(name, bm, "wood", smooth=False)


def build_pawn():
    parts = base("Pawn", 29, 10, 40)
    parts.append(profile("Cup", [(10, 37), (16, 42), (16, 45), (9, 48), (0, 48)]))
    parts.append(sphere("Orb", (0, 0, .057), .016, scale=(1, 1, 1.03)))
    return parts


def build_rook():
    parts = base("Rook", 33, 18, 58)
    parts.append(profile("Battlement", [(18, 55), (27, 65), (27, 77), (0, 77)]))
    for i in range(4):
        a = math.tau * i / 4 + math.pi/4
        parts.append(box("Merlon", (.019*math.cos(a), .019*math.sin(a), .080),
                         (.015, .024, .015), rot_z=a, bevel=.002))
    return parts


def build_knight():
    parts = base("Knight", 32, 21, 29)
    parts.append(silhouette("Horse", [(-20, 27), (-24, 43), (-20, 67), (-9, 88),
                                      (-6, 104), (2, 97), (5, 93), (12, 90), (32, 71),
                                      (31, 62), (23, 59), (9, 66), (5, 56), (13, 38),
                                      (19, 27)], 11))
    for side in [-1, 1]:
        parts.append(sphere("Eye", (side*.011, .006, .084), .0028, material="brass"))
    return parts


def build_bishop():
    parts = base("Bishop", 32, 11, 65)
    parts.append(profile("Collar", [(11, 60), (18, 64), (17, 68), (0, 70)]))
    mitre = profile("Mitre", [(7, 68), (16, 75), (18, 84), (14, 96), (3, 111), (0, 113)])
    boolean(mitre, box("Slit", (.009, 0, .098), (.005, .060, .039), rot_z=0,
                       bevel=0))
    parts.append(mitre)
    return parts


def build_queen():
    parts = base("Queen", 35, 10, 84)
    parts.append(profile("Cup", [(10, 78), (17, 84), (13, 90), (23, 105), (22, 110), (0, 110)]))
    # Five gold-tipped petals form a readable open crown.
    for i in range(5):
        a = math.tau*i/5
        petal = sphere("Petal", (0, 0, 0), .009, scale=(.72, .82, 1.65))
        petal.location = (.022*math.cos(a), .022*math.sin(a), .113)
        petal.rotation_euler = (0, .28, a)
        parts.append(petal)
    parts.append(sphere("Pearl", (0, 0, .115), .009, "brass"))
    return parts


def build_king():
    parts = base("King", 36, 12, 89)
    parts.append(profile("Cap", [(12, 83), (21, 91), (14, 96), (20, 106),
                                 (18, 115), (7, 120), (0, 120)]))
    parts.append(silhouette("Cross", [(-5, 116), (5, 116), (5, 128), (15, 128),
                                      (15, 137), (5, 137), (5, 150), (-5, 150),
                                      (-5, 137), (-15, 137), (-15, 128), (-5, 128)], 4, "x"))
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
    pads = [p for p in parts if p.data.materials[0].name == "felt"]
    body = join([p for p in parts if p not in pads], name.capitalize())
    return [body, *pads]


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


MAPLE = ((212, 226, 210), (194, 211, 192))
WALNUT = ((103, 151, 145), (77, 123, 121))


def build_textures() -> None:
    rng = np.random.default_rng(1118)
    size = 2048
    px_per_m = size / BOARD_INLAY
    img = np.zeros((size, size, 3), np.float32)
    # Intarsienband: Nussbaum, darin eine helle Ahornader und kleine Rauten.
    band = wood((size, size), WALNUT[0], WALNUT[1], rng, rings=60, vertical=False)
    img[:] = band * .46
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    inner0 = (BOARD_INLAY - BOARD_INNER) / 2 * px_per_m
    edge = np.minimum(np.minimum(xx, yy), np.minimum(size - 1 - xx, size - 1 - yy))
    vein = (edge > inner0 * 0.42) & (edge < inner0 * 0.58)
    img[vein] = (225, 188, 119)
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
    save(wood((1024, 1024), (245, 238, 216), (234, 225, 204), np.random.default_rng(5), rings=26, warp=2.0, pores=0.1), "piece_maple")
    save(wood((1024, 1024), (52, 66, 86), (43, 51, 72), np.random.default_rng(6), rings=26, warp=2.0, pores=0.14), "piece_walnut")
    # Rahmen: Nussbaum, längs gemasert.
    save(wood((1024, 1024), (43, 74, 73), (31, 56, 58), np.random.default_rng(9), rings=30, warp=2.0, vertical=False), "frame_walnut")
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
            body.data.materials[0] = _render_material("m", "piece_maple" if colour == "w" else "piece_walnut", 0.32)
            for felt in parts[1:]:
                bpy.data.objects.remove(felt, do_unlink=True)
            scene = bpy.context.scene
            scene.render.engine = "CYCLES"
            scene.cycles.samples = 16
            scene.cycles.use_denoising = False
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
                light_data.energy = energy * (0.33 if colour == "w" else .86)
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
