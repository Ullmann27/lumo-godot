#!/usr/bin/env python3
"""Lumo Kart: gerenderte Bedienknöpfe (Gas, Bremse, Drift, Turbo, Item) und Lenk-Stick.

Jeder Knopf ist ein plastischer Glas-Knopf mit dunkler Wand, Fase, Neon-Lichtkante,
innerem Leuchten und einem großen 3D-Symbol, das ohne Lesen verständlich ist:

  gas    grün-türkis   Gaspedal mit Tempo-Streifen
  brake  rot-orange    Bremsscheibe mit Bremssattel
  drift  blau          Reifen mit Funken und Drift-Bogen
  boost  gold          Rakete mit Flamme (Turbo)
  item   violett       Überraschungs-Kiste (leer / bereit / scharf / Schild)
  stick  cyan          Lenk-Basis mit Links/Rechts-Pfeilen und glänzender Knauf

Gerendert mit Blender (bpy als Python-Modul, Cycles CPU, transparenter Hintergrund) in
512 px und danach auf 384 px verkleinert als WebP abgelegt. Die Bausteine (Bühne, Licht,
Materialien, Formen, Nachleuchten) stammen aus tools/art/render_ui_kit.py.

Zustände je Knopf:  _normal, _pressed (Kappe eingedrückt + heller), _disabled (aus dem
Normalbild entsättigt und abgedunkelt), bei boost/item zusätzlich _ready (stärkeres Glühen).
Item hat dazu _armed, _armed_pressed (= feuern) und _shield.

Aufruf (im Repo-Wurzelverzeichnis):
  /home/user/tools/bpyenv/bin/python tools/art/render_kart_controls.py
  ... --only gas,stick_knob          nur einzelne Teile
  ... --contact-sheet /pfad/blatt.png Übersicht auf Fahrbahngrau und Dunkelblau (nicht ins Repo)
  ... --samples 96
Gleiche Maschine, gleiche Eingaben: gleiche Dateien (fester Cycles-Seed).
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_ui_kit as kit  # noqa: E402  (lädt bpy)
from render_ui_kit import PX, Mask, grad, group, lathe, metal, mixc, shape, solid, tube, ball, smooth_path, star_pts  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets/kart/controls/rendered"
RENDER = 512
FINAL = 384
SAMPLES = 64

# Leitfarben: Kappe oben, Kappe unten, Wand, Lichtkante, Glühen
LEADS = {
    "gas": dict(top="34e0b0", bottom="03463f", wall="022b2a", rim="8dffe0", glow="1ff5c0"),
    "brake": dict(top="ff5a32", bottom="58060c", wall="360508", rim="ffb48a", glow="ff4a22"),
    "drift": dict(top="3f8cff", bottom="06175e", wall="040c3a", rim="9fd8ff", glow="2f8bff"),
    "boost": dict(top="ffc23a", bottom="5c2c00", wall="371900", rim="ffeaa0", glow="ffb71a"),
    "item": dict(top="a46bff", bottom="230a62", wall="16053d", rim="dcc6ff", glow="a161ff"),
    "item_armed": dict(top="ff5a6e", bottom="5a0418", wall="35020e", rim="ffd23f", glow="ff3b5c"),
    "item_shield": dict(top="3fd8ff", bottom="03336a", wall="021f44", rim="c8f8ff", glow="44e3ff"),
}

BODY = 392.0  # Kantenlänge des Knopfkörpers in Renderpixeln (Rest: Leuchtrand)
RADIUS = 104.0
LIP = 16.0
SINK = 10.0


# ---------------------------------------------------------------- Knopfkörper
def rr(w, h, r, cx=0.0, cy=0.0):
    c = ("r", r)
    return kit.rect_path(w, h, c, c, c, c, cx=cx, cy=cy, seg=14)


def button_body(lead, pressed):
    """Wand (unten als Kante sichtbar), Glaskappe mit Verlauf, Neon-Lichtkante, Glanz.
    Gibt die Gruppe zurück, auf der das Symbol sitzt (sinkt beim Drücken mit ein)."""
    sink = SINK if pressed else 0.0
    lift = 1.35 if pressed else 1.0  # gedrückt: heller
    wall = grad("wall", [(0.0, mixc(lead["wall"], "000000", 0.35)), (1.0, mixc(lead["wall"], lead["bottom"], 0.6))],
                -BODY / 2 - LIP, -BODY / 2 + 40, rough=0.3, emit=0.15, coat=0.6)
    shape("wall", rr(BODY, BODY, RADIUS, cy=-LIP), 0, 30, 12, wall, res=5)
    # dunkler Sockelring unter der Kappe (Tiefe, Fuge)
    shape("socket", rr(BODY, BODY, RADIUS, cy=-sink * 0.5), 6, 26, 10, solid("socket", mixc(lead["wall"], "000000", 0.2), rough=0.4, emit=0.05), res=4)
    top, bottom = lead["top"], lead["bottom"]
    if pressed:
        top, bottom = mixc(top, "ffffff", 0.18), mixc(bottom, top, 0.22)
    cap = grad("cap", [(0.0, bottom), (0.45, mixc(bottom, top, 0.55)), (1.0, top)], -BODY / 2 - sink, BODY / 2 - sink,
               rough=0.16, emit=0.55 * lift, coat=1.0)
    inner = BODY - 22
    shape("cap", rr(inner, inner, RADIUS - 11, cy=-sink), 14, 26, 12, cap, res=6)
    # Neon-Lichtkante als Ring um die Kappe
    ring = Mask(512).poly(rr(BODY - 4, BODY - 4, RADIUS - 2, cy=-sink)).poly(rr(inner - 2, inner - 2, RADIUS - 12, cy=-sink), fill=0)
    shape("rim", ring.loops(smooth=0.8, step=1), 24, 16, 6, solid("rim", lead["rim"], rough=0.12, emit=1.6 * lift, coat=1.0), res=4)
    # Glanz unter der Oberkante (Glas)
    # Glanz unter der Oberkante: flacher Lichtbogen, nach unten auslaufend
    gloss = solid("gloss", "ffffff", rough=0.08, emit=1.0, coat=0.0, alpha=0.085 if not pressed else 0.05)
    top_y = inner / 2 - 14 - sink
    lens = Mask(512).circle(0, top_y - 250, 268).poly(rr(inner + 40, 600, 10, cy=top_y - 340), fill=0)
    clip = Mask(512).poly(rr(inner - 30, inner - 30, RADIUS - 24, cy=-sink))
    both = np.asarray(lens.im) & np.asarray(clip.im)
    loops = kit.mask_loops(both > 127, lens.ss, lens.size, 1.0, 2)
    shape("gloss", loops, 40.5, 0.6, 0.0, gloss)
    holder = group("icon", loc=(0, -sink + 30, 40 - sink))
    return holder


# ---------------------------------------------------------------- Materialien der Symbole
def mats():
    kw = dict(rough=0.18, coat=1.0)
    m = kit.icon_materials()
    m.update(
        red=grad("red", [(0.0, "b0101e"), (0.5, "ff3b3b"), (1.0, "ff8a6a")], -120, 120, emit=0.45, side="6a0510", **kw),
        orange=grad("orange", [(0.0, "ff5a00"), (1.0, "ffb02a")], -120, 120, emit=0.6, side="b03000", **kw),
        rubber=grad("rubber", [(0.0, "0b0f1a"), (1.0, "2a3346")], -120, 120, rough=0.45, emit=0.08, coat=0.3, side="05070c"),
        lime=solid("lime", "c9ff5a", rough=0.2, emit=1.4, coat=0.6),
        spark=solid("spark", "ffd84a", rough=0.2, emit=2.2, coat=0.3),
        spark2=solid("spark2", "ff8a1f", rough=0.2, emit=2.0, coat=0.3),
        swoosh=solid("swoosh", "7fe8ff", rough=0.2, emit=2.0, coat=0.3),
        flame=grad("flame", [(0.0, "ff3c00"), (0.6, "ff9a12"), (1.0, "ffe680")], -150, 0, emit=2.2, rough=0.3, coat=0.0),
        flame_core=grad("flamecore", [(0.0, "ffd040"), (1.0, "fffbe0")], -120, 0, emit=2.6, rough=0.3, coat=0.0),
        steel=metal("steel", "ffffff", "c9d6ea", "6a7a98", -120, 120, rough=0.22, emit=0.22),
        glass_blue=solid("window", "4fd2ff", rough=0.05, emit=0.9, coat=1.0),
    )
    return m


# ---------------------------------------------------------------- Symbole (Mitte ~ (0, 0), ~220 px)
def icon_gas(m, holder):
    # Zwei dicke Pfeile nach vorn (= losfahren) auf dunkler Unterlage, damit sie auf der
    # hellen Kappe klar stehen.
    arrow_mat = grad("arrow", [(0.0, "c8fff0"), (0.6, "f4fffc"), (1.0, "ffffff")], -110, 120, rough=0.15, emit=0.6, coat=1.0, side="1a9c86")
    back = solid("arrow_back", "033a33", rough=0.3, emit=0.15, coat=0.6)
    for i, y in enumerate((-62, 30)):
        pts = [(-96, y - 30), (0, y + 62), (96, y - 30)]
        g = group(f"c{i}", loc=(0, 0, 0), rot=(-12, 0, 0), parent=holder)
        shape(f"chevron_back{i}", Mask(400).line(pts, 70).loops(smooth=1.0), 0 + i * 12, 20, 8, back, res=4, parent=g)
        shape(f"chevron{i}", Mask(400).line(pts, 46).loops(smooth=1.0), 12 + i * 12, 34, 12, arrow_mat, res=6, parent=g)


def icon_brake(m, holder):
    g = group("brake", loc=(-10, -14, 8), rot=(-18, 14, 0), parent=holder)
    disc = Mask(400).circle(0, 0, 94).circle(0, 0, 40, fill=0)
    for k in range(12):
        a = k * math.tau / 12
        disc.circle(67 * math.cos(a), 67 * math.sin(a), 7.5, fill=0)
    shape("disc", disc.loops(smooth=0.8), 0, 18, 5, m["steel"], res=4, parent=g)
    hub = Mask(400).circle(0, 0, 44).circle(0, 0, 13, fill=0)
    shape("hub", hub.loops(), 6, 28, 8, m["navy"], res=4, parent=g)
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        ball(f"bolt{k}", 7.5, (27 * math.cos(a), 27 * math.sin(a), 34), m["silver"], parent=g)
    caliper = kit.arc_pts(0, 0, 112, 6, 100, 20) + list(reversed(kit.arc_pts(0, 0, 60, 6, 100, 20)))
    shape("caliper", caliper, 14, 42, 14, m["gold"], res=6, parent=g)
    stripe = kit.arc_pts(0, 0, 92, 30, 76, 10) + list(reversed(kit.arc_pts(0, 0, 80, 30, 76, 10)))
    shape("caliper_stripe", stripe, 54, 6, 2.5, solid("stripe", "c0281c", rough=0.2, emit=0.5, coat=1.0), parent=g)


def icon_drift(m, holder):
    # Drift-Bogen hinter dem Reifen
    arc = smooth_path([(-104, -60, 0), (-120, 0, 0), (-96, 64, 0), (-40, 104, 0), (24, 112, 0)], per=8)
    tube("swoosh", arc, 10, m["swoosh"], parent=group("sw", loc=(0, -6, 6), parent=holder))
    arc2 = smooth_path([(-78, -64, 0), (-90, -8, 0), (-70, 44, 0), (-28, 80, 0)], per=8)
    tube("swoosh2", arc2, 6, m["cyan"], parent=group("sw2", loc=(0, -6, 6), parent=holder))
    g = group("tire", loc=(26, 4, 34), rot=(-16, 26, -10), parent=holder)
    tread = Mask(400).circle(0, 0, 82)
    for k in range(18):
        a = k * math.tau / 18
        tread.circle(86 * math.cos(a), 86 * math.sin(a), 8, fill=0)
    tread.circle(0, 0, 48, fill=0)
    shape("tire", tread.loops(smooth=0.8), 0, 54, 20, m["rubber"], res=6, parent=g)
    rim = Mask(400).circle(0, 0, 50)
    for k in range(5):
        a = k * math.tau / 5 + 0.6
        rim.circle(28 * math.cos(a), 28 * math.sin(a), 10, fill=0)
    shape("rim", rim.loops(smooth=0.8), 10, 34, 7, m["steel"], res=4, parent=g)
    ball("hub", 12, (0, 0, 46), m["cyan"], parent=g)
    # Funken unten rechts am Reifen (Bodenkontakt beim Driften)
    sparks = [((96, -82), 24, 0), ((132, -48), 17, 1), ((70, -122), 16, 1), ((122, -110), 12, 0), ((150, -84), 9, 0)]
    for i, ((x, y), r, kind) in enumerate(sparks):
        loops = Mask(400).poly(star_pts(4, r, r * 0.34, rot=20 * i)).loops(smooth=0.6, step=1)
        shape(f"spark{i}", loops, 50, 10, 3, m["spark"] if kind == 0 else m["spark2"], parent=group(f"sp{i}", loc=(x - 26, y, 10), parent=holder))


def icon_boost(m, holder):
    g = group("rocket", loc=(10, 0, 40), rot=(0, 0, -42), parent=holder)
    body = [(0, -70), (30, -70), (35, -40), (36, 10), (33, 40), (24, 70), (12, 92), (0, 102)]
    rocket = lathe("body", body, m["white"], seg=48, parent=g)
    rocket.rotation_euler = (math.radians(-12), 0, 0)
    nose = lathe("nose", [(0, 58), (26, 58), (24, 70), (12, 92), (0, 103)], m["red"], seg=48, parent=g)
    nose.scale = (1.04, 1.0, 1.04)
    nose.rotation_euler = rocket.rotation_euler
    ring = lathe("band", [(0, -48), (37, -48), (37, -36), (0, -36)], m["red"], seg=48, parent=g)
    ring.rotation_euler = rocket.rotation_euler
    win = group("win", loc=(0, 22, 34), parent=g)
    ball("window", 15, (0, 0, 0), m["glass_blue"], parent=win)
    shape("window_frame", Mask(200).circle(0, 0, 21).circle(0, 0, 15, fill=0).loops(), -6, 8, 3, m["silver"], parent=win)
    for side in (-1, 1):
        fin = [(side * 30, -10), (side * 66, -58), (side * 64, -82), (side * 30, -64)]
        shape(f"fin{side}", fin, -10, 18, 5, m["red"], parent=g)
    shape("fin_mid", [(-7, -30), (7, -30), (7, -84), (-7, -84)], 30, 12, 4, m["red"], parent=g)
    flame = group("flame", loc=(0, -72, 0), parent=g)
    outer = lathe("flame_out", [(0, 0), (28, -4), (30, -26), (20, -60), (0, -104)], m["flame"], seg=40, parent=flame)
    outer.scale = (1.0, 1.0, 0.7)
    core = lathe("flame_core", [(0, 0), (16, -6), (16, -28), (0, -66)], m["flame_core"], seg=32, parent=flame)
    core.location.z = 10 * PX
    core.scale = (1.0, 1.0, 0.7)


def icon_item(m, holder):
    font = kit.bpy.data.fonts.load(str(kit.FONT_PATH))
    g = group("box", loc=(0, 0, 70), rot=(-24, 32, 0), parent=holder)
    kit.box("box", (150, 150, 150), (0, 0, 0), m["gold"], bevel=22, parent=g)
    for side, rot in (("front", (0, 0, 0)), ("right", (0, 90, 0)), ("top", (-90, 0, 0))):
        face = group(f"q_{side}", rot=rot, parent=g)
        q = group("q", loc=(0, -4, 75), parent=face)
        kit.text(f"q_{side}", "?", 130, 0, 10, 3, m["navy"], font, res=2, parent=q)


def stick_base(m):
    lead = dict(top="1f9bff", bottom="051a52", wall="030c2c", rim="7fe9ff")
    wall = grad("swall", [(0.0, "01040f"), (1.0, "0a1d5c")], -250, -150, rough=0.3, emit=0.12, coat=0.6)
    shape("swall", Mask(512).circle(0, -12, 232).loops(), 0, 30, 14, wall, res=5)
    dish = grad("dish", [(0.0, "061033"), (0.5, "0c2a78"), (1.0, "1d55c8")], -230, 230, rough=0.18, emit=0.45, coat=1.0)
    shape("dish", Mask(512).circle(0, 0, 226).loops(), 10, 22, 12, dish, res=6)
    rim = Mask(512).circle(0, 0, 228).circle(0, 0, 208, fill=0)
    shape("srim", rim.loops(), 24, 14, 5, solid("srim", lead["rim"], rough=0.12, emit=1.5, coat=1.0), res=4)
    well = grad("well", [(0.0, "0a2a6e"), (1.0, "020820")], -140, 140, rough=0.25, emit=0.3, coat=1.0)
    shape("well", Mask(512).circle(0, 0, 150).loops(), 24, 10, 8, well, res=5)
    inner = Mask(512).circle(0, 0, 154).circle(0, 0, 146, fill=0)
    shape("wellring", inner.loops(), 32, 6, 2, solid("wring", "3fb6ff", rough=0.2, emit=1.2, coat=1.0))
    arrow = solid("arrow", "e8fbff", rough=0.15, emit=1.4, coat=1.0)
    for side in (-1, 1):
        pts = [(side * 172, 34), (side * 196, 0), (side * 172, -34)]
        shape(f"arrow{side}", Mask(512).line(pts, 18).loops(smooth=0.6), 30, 10, 4, arrow)
    small = solid("arrow_small", "7fb8e8", rough=0.2, emit=0.6, coat=1.0)
    for side in (-1, 1):
        pts = [(-18, side * 176), (0, side * 192), (18, side * 176)]
        shape(f"tick{side}", Mask(512).line(pts, 10).loops(smooth=0.6), 30, 6, 2.5, small)
    gloss = solid("sgloss", "ffffff", rough=0.08, emit=1.0, coat=0.0, alpha=0.07)
    shape("sgloss", Mask(512).circle(0, 40, 196).circle(0, -10, 210, fill=0).loops(), 36, 0.6, 0.0, gloss)


def stick_knob(m, pressed):
    lift = 1.45 if pressed else 1.0
    top = mixc("4fd8ff", "ffffff", 0.2) if pressed else "4fd8ff"
    shape("kshadow", Mask(512).circle(0, -14, 204).loops(), 0, 20, 10, solid("kwall", "020a26", rough=0.35, emit=0.1), res=4)
    dome = grad("dome", [(0.0, "0a2a8e"), (0.55, "1e7ae8"), (1.0, top)], -200, 200, rough=0.12, emit=0.6 * lift, coat=1.0)
    g = group("knob", loc=(0, 0, 20), rot=(90, 0, 0))
    lathe("dome", [(0, 70), (120, 66), (176, 50), (198, 24), (200, 0), (0, 0)], dome, seg=72, parent=g)
    grip = Mask(512).circle(0, 0, 150).circle(0, 0, 132, fill=0)
    shape("grip", grip.loops(), 80, 12, 4, solid("grip", "a8f2ff", rough=0.12, emit=1.4 * lift, coat=1.0), res=4)
    pad = grad("pad", [(0.0, "0c3aa8"), (1.0, "3ab8ff")], -130, 130, rough=0.2, emit=0.5 * lift, coat=1.0)
    shape("pad", Mask(512).circle(0, 0, 128).loops(), 88, 6, 3, pad)
    star = kit.star_loops(54, 24, 9)
    shape("star", star, 92, 14, 6, m["gold"], res=5)
    gloss = solid("kgloss", "ffffff", rough=0.08, emit=1.0, coat=0.0, alpha=0.18)
    shape("kgloss", Mask(512).circle(0, 20, 180).circle(14, -6, 184, fill=0).loops(), 108, 0.6, 0.0, gloss)


# ---------------------------------------------------------------- Ablauf
ICON = {"gas": icon_gas, "brake": icon_brake, "drift": icon_drift, "boost": icon_boost, "item": icon_item}
ICON_SCALE = {"gas": 1.08, "brake": 1.16, "drift": 1.12, "boost": 1.12, "item": 1.2}
BUTTONS = ["gas", "brake", "drift", "boost", "item"]


def specs():
    out = {}
    for name in BUTTONS:
        out[f"{name}_normal"] = dict(kind="button", icon=name, lead=name, pressed=False)
        out[f"{name}_pressed"] = dict(kind="button", icon=name, lead=name, pressed=True)
    out["item_armed"] = dict(kind="button", icon="item", lead="item_armed", pressed=False)
    out["item_armed_pressed"] = dict(kind="button", icon="item", lead="item_armed", pressed=True)
    out["item_shield"] = dict(kind="button", icon="item", lead="item_shield", pressed=False)
    out["stick_base"] = dict(kind="stick_base")
    out["stick_knob_normal"] = dict(kind="stick_knob", pressed=False)
    out["stick_knob_pressed"] = dict(kind="stick_knob", pressed=True)
    return out


def glow_of(spec):
    if spec["kind"] == "button":
        lead = LEADS[spec["lead"]]
        return (lead["glow"], 0.75 if spec["pressed"] else 0.5, 9.0)
    if spec["kind"] == "stick_base":
        return ("29b6ff", 0.45, 9.0)
    return ("43d8ff", 0.55 if spec["pressed"] else 0.3, 7.0)


def render(name, spec, samples):
    kit.stage(RENDER, RENDER, samples)
    m = mats()
    if spec["kind"] == "button":
        holder = button_body(LEADS[spec["lead"]], spec["pressed"])
        ICON[spec["icon"]](m, holder)
        holder.scale = (ICON_SCALE.get(spec["icon"], 1.0),) * 3
    elif spec["kind"] == "stick_base":
        stick_base(m)
    else:
        stick_knob(m, spec["pressed"])
    img = kit.render_rgba(RENDER, RENDER)
    inner = None
    if spec["kind"] == "button":
        inner = (LEADS[spec["lead"]]["glow"], 0.22, 10.0)
    img = kit.decorate(img, glow=glow_of(spec), inner=inner, shadow=(8, 7.0, 0.5))
    return img


def to_image(img):
    a = img[..., 3]
    img = img.copy()
    img[..., 3] = np.where(a < 1.5 / 255.0, 0.0, a)
    return Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA")


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im = im.resize((FINAL, FINAL), Image.LANCZOS)
    path = OUT / f"{name}.webp"
    im.save(path, "WEBP", quality=88, method=6, alpha_quality=95)
    return path


def disabled_variant(im):
    """Deaktiviert: entsättigt, kühl-grau, abgedunkelt, Leuchten fast aus."""
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[..., :3]
    grey = (rgb * np.array([0.30, 0.55, 0.15])).sum(axis=2, keepdims=True)
    cool = np.array([0.52, 0.60, 0.72])
    out = grey * cool * 1.15 * 0.85 + rgb * 0.08
    alpha = a[..., 3:4]
    alpha = np.where(alpha < 0.55, alpha * 0.45, alpha)  # Leuchtrand schwächer
    return Image.fromarray((np.clip(np.concatenate([out, alpha * 0.96], axis=2), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def ready_variant(img_float, glow_color):
    """Bereit: das Normalbild mit kräftigerem, breiterem Leuchtrand."""
    return to_image(kit.decorate(img_float.copy(), glow=(glow_color, 0.55, 15.0)))


def contact_sheet(path):
    files = sorted(OUT.glob("*.webp"))
    cell = 200
    cols = 6
    rows = math.ceil(len(files) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 26)), (0, 0, 0, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(str(kit.FONT_PATH), 15)
    except OSError:
        font = None
    for i, f in enumerate(files):
        x, y = (i % cols) * cell, (i // cols) * (cell + 26)
        bg = (92, 98, 110, 255) if (i // cols) % 2 == 0 else (12, 26, 54, 255)
        draw.rectangle((x, y, x + cell, y + cell + 26), fill=bg)
        im = Image.open(f).convert("RGBA").resize((cell - 16, cell - 16), Image.LANCZOS)
        sheet.alpha_composite(im, (x + 8, y + 8))
        draw.text((x + 8, y + cell + 4), f.stem, fill=(255, 255, 255, 255), font=font)
    sheet.convert("RGB").save(path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="")
    parser.add_argument("--samples", type=int, default=SAMPLES)
    parser.add_argument("--contact-sheet", default="")
    parser.add_argument("--sheet-only", action="store_true")
    args = parser.parse_args(argv)
    all_specs = specs()
    wanted = [s.strip() for s in args.only.split(",") if s.strip()]
    names = [n for n in all_specs if not wanted or any(n == w or n.startswith(w + "_") for w in wanted)]
    if not args.sheet_only:
        for name in names:
            spec = all_specs[name]
            img = render(name, spec, args.samples)
            im = to_image(img)
            print(f"[controls] {save(im, name).name}", flush=True)
            if name.endswith("_normal") and spec["kind"] == "button":
                base = name[: -len("_normal")]
                print(f"[controls] {save(disabled_variant(im), base + '_disabled').name}", flush=True)
                if base in ("boost", "item"):
                    print(f"[controls] {save(ready_variant(img, LEADS[base]['glow']), base + '_ready').name}", flush=True)
            if name == "stick_base":
                print(f"[controls] {save(disabled_variant(im), 'stick_base_disabled').name}", flush=True)
    if args.contact_sheet:
        contact_sheet(args.contact_sheet)
        print(f"[controls] Übersicht: {args.contact_sheet}")
    total = sum(f.stat().st_size for f in OUT.glob("*.webp"))
    print(f"[controls] {len(list(OUT.glob('*.webp')))} Dateien, {total // 1024} KB")


if __name__ == "__main__":
    main()
