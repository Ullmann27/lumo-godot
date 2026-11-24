#!/usr/bin/env python3
"""Lumo Kart: gerenderte Teile der Item-Anzeige im Rennen (gleiche Bildsprache wie die Knöpfe).

  seeker_ring        Suchring (Cyan-Neon mit Skalenstrichen) – wandert, verengt sich aufs Ziel
  lock_corner_gold   Zielklammer-Ecke beim Erfassen (Gold-Glas, Lichtkante)
  lock_corner_red    Zielklammer-Ecke eingerastet (Rot-Glas, goldene Lichtkante)
  lock_core          Raute in der Zielmitte, wenn das Ziel erfasst ist
  pod / pod_armed    Raketenhalter (dunkles Glas, Lichtkante cyan bzw. rot) mit zwei Schächten
  pod_rocket         eine Sternrakete für einen Schacht (zeigt nach oben)
  shield_core        Schild-Symbol (Sechseck-Glas mit Stern) für die Restzeit-Anzeige
  warn_arrow         roter Warnpfeil „von hinten“ für den unteren Bildrand

Gerendert mit Blender (bpy als Python-Modul, Cycles CPU, transparenter Hintergrund) in 384 px,
als WebP 256 px nach assets/kart/hud/items/. Bausteine aus tools/art/render_ui_kit.py.
Aufruf (Repo-Wurzel): /home/user/tools/bpyenv/bin/python tools/art/render_kart_item_hud.py [--only a,b]
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_ui_kit as kit  # noqa: E402  (lädt bpy)
from render_ui_kit import Mask, grad, group, lathe, mixc, shape, solid, ball, star_pts  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets/kart/hud/items"
RENDER = 384
FINAL = 256
SAMPLES = 40


def glass(name, top, bottom, emit=0.5):
    return grad(name, [(0.0, bottom), (0.5, mixc(bottom, top, 0.55)), (1.0, top)], -170, 170, rough=0.14, emit=emit, coat=1.0)


def rim(name, color, emit=1.6):
    return solid(name, color, rough=0.12, emit=emit, coat=1.0)


def corner(lead):
    """Ecke einer Zielklammer: L-Form, Spitze unten links (Laufzeit dreht sie)."""
    face = glass("corner", lead["top"], lead["bottom"], 0.7)
    edge = rim("corner_rim", lead["rim"])
    pts = [(-120, 120), (-120, -120), (120, -120)]
    shape("back", Mask(384).line(pts, 64).loops(smooth=0.8), 0, 18, 6, solid("cb", "08102a", rough=0.3, emit=0.1), res=4)
    shape("face", Mask(384).line(pts, 44).loops(smooth=0.8), 10, 22, 8, face, res=5)
    shape("edge", Mask(384).line(pts, 50).line(pts, 38, fill=0).loops(smooth=0.6, step=1), 26, 10, 3, edge, res=3)


def seeker_ring(_m):
    ring = Mask(384).circle(0, 0, 160).circle(0, 0, 138, fill=0)
    shape("ring_back", ring.loops(), 0, 14, 5, solid("rb", "04122e", rough=0.3, emit=0.1), res=4)
    shape("ring", Mask(384).circle(0, 0, 156).circle(0, 0, 142, fill=0).loops(), 10, 14, 5, rim("rr", "7fe9ff", 1.5), res=4)
    tick = rim("tick", "e8fbff", 1.8)
    for k in range(12):
        a = k * math.tau / 12
        length = 30 if k % 3 == 0 else 16
        p0 = (math.cos(a) * 128, math.sin(a) * 128)
        p1 = (math.cos(a) * (128 - length), math.sin(a) * (128 - length))
        shape(f"tick{k}", Mask(384).line([p0, p1], 9).loops(smooth=0.6), 12, 10, 3, tick, res=3)


def lock_core(_m):
    pts = [(0, 130), (130, 0), (0, -130), (-130, 0)]
    shape("core_back", Mask(384).poly(pts).loops(smooth=0.6), 0, 18, 6, solid("kb", "3a0010", rough=0.3, emit=0.1), res=4)
    inner = [(0, 104), (104, 0), (0, -104), (-104, 0)]
    shape("core", Mask(384).poly(inner).loops(smooth=0.6), 10, 22, 8, glass("kc", "ff8aa0", "a0001e", 0.8), res=5)
    shape("core_rim", Mask(384).poly(pts).poly(inner, fill=0).loops(smooth=0.5, step=1), 22, 10, 3, rim("kr", "ffffff", 1.6), res=3)
    star = kit.star_loops(44, 20, 6)
    shape("core_star", star, 34, 10, 4, solid("ks", "ffe066", rough=0.15, emit=1.2, coat=1.0), res=4)


def pod(armed):
    """Raketenhalter von vorn: Glaskapsel mit zwei dunklen Schächten nebeneinander."""
    lead_rim = "ff4f6d" if armed else "7fe9ff"
    body = glass("pod", "2a5aa8" if not armed else "8a1f3a", "071a3e" if not armed else "2a0610", 0.45)
    outline = kit.rect_path(300, 330, ("r", 90), ("r", 90), ("r", 90), ("r", 90), seg=12)
    shape("pod_back", Mask(384).poly(outline).loops(), 0, 22, 8, solid("pb", "030a1c", rough=0.3, emit=0.1), res=4)
    inner = kit.rect_path(270, 300, ("r", 78), ("r", 78), ("r", 78), ("r", 78), seg=12)
    shape("pod_face", Mask(384).poly(inner).loops(), 12, 20, 8, body, res=5)
    shape("pod_rim", Mask(384).poly(outline).poly(inner, fill=0).loops(step=1), 26, 10, 3, rim("pr", lead_rim, 1.7), res=3)
    well = solid("well", "01040e", rough=0.4, emit=0.05, coat=0.4)
    for x in (-66, 66):
        slot = kit.rect_path(96, 236, ("r", 44), ("r", 44), ("r", 44), ("r", 44), cx=x, seg=10)
        shape(f"slot{x}", Mask(384).poly(slot).loops(), 30, 6, 3, well, res=3)
        ring = Mask(384).poly(kit.rect_path(108, 248, ("r", 50), ("r", 50), ("r", 50), ("r", 50), cx=x, seg=10)).poly(slot, fill=0)
        shape(f"slotrim{x}", ring.loops(step=1), 32, 6, 2, solid("sr", mixc(lead_rim, "ffffff", 0.3), rough=0.15, emit=0.9, coat=1.0), res=3)


def pod_rocket(m):
    g = group("rocket", loc=(0, -6, 60), rot=(0, 0, 0))
    white = m["white"]
    red = grad("red", [(0.0, "b0101e"), (0.5, "ff3b3b"), (1.0, "ff8a6a")], -150, 150, emit=0.45, side="6a0510", rough=0.18, coat=1.0)
    lathe("body", [(0, -120), (34, -120), (40, -80), (42, 20), (38, 70), (26, 110), (12, 136), (0, 146)], white, seg=40, parent=g)
    lathe("nose", [(0, 92), (32, 92), (26, 110), (12, 136), (0, 147)], red, seg=40, parent=g).scale = (1.04, 1.0, 1.04)
    lathe("band", [(0, -70), (43, -70), (43, -54), (0, -54)], red, seg=40, parent=g)
    for side in (-1, 1):
        fin = [(side * 36, -60), (side * 84, -122), (side * 80, -150), (side * 36, -128)]
        shape(f"fin{side}", fin, -12, 20, 6, red, parent=g)
    ball("window", 17, (0, 30, 40), solid("win", "4fd2ff", rough=0.05, emit=0.9, coat=1.0), parent=g)


def shield_core(m):
    hexagon = [(math.cos(math.pi / 6 + k * math.pi / 3) * 160, math.sin(math.pi / 6 + k * math.pi / 3) * 160) for k in range(6)]
    inner = [(x * 0.84, y * 0.84) for x, y in hexagon]
    shape("hex_back", Mask(384).poly(hexagon).loops(smooth=0.6), 0, 20, 8, solid("hb", "021f44", rough=0.3, emit=0.1), res=4)
    shape("hex", Mask(384).poly(inner).loops(smooth=0.6), 12, 20, 8, glass("hx", "8af0ff", "0a4fa0", 0.7), res=5)
    shape("hex_rim", Mask(384).poly(hexagon).poly(inner, fill=0).loops(smooth=0.5, step=1), 26, 10, 3, rim("hr", "c8f8ff", 1.7), res=3)
    star = kit.star_loops(74, 32, 9)
    shape("hex_star", star, 36, 16, 6, m["gold"], res=5)


def warn_arrow(_m):
    pts = [(0, 150), (150, -20), (70, -20), (70, -150), (-70, -150), (-70, -20), (-150, -20)]
    shape("arrow_back", Mask(384).poly(pts).loops(smooth=0.7), 0, 18, 6, solid("ab", "3a0010", rough=0.3, emit=0.1), res=4)
    inner = [(0, 120), (118, -6), (52, -6), (52, -128), (-52, -128), (-52, -6), (-118, -6)]
    shape("arrow", Mask(384).poly(inner).loops(smooth=0.7), 10, 22, 8, glass("aw", "ff9aa8", "b0001e", 0.9), res=5)
    shape("arrow_rim", Mask(384).poly(pts).poly(inner, fill=0).loops(smooth=0.5, step=1), 24, 10, 3, rim("ar", "ffd23f", 1.6), res=3)


LEADS = {
    "gold": dict(top="ffe58a", bottom="c47a00", rim="fff4c0", glow="ffc23a"),
    "red": dict(top="ff8a9a", bottom="9a0020", rim="ffd23f", glow="ff3b5c"),
}
SPECS = {
    "seeker_ring": (seeker_ring, "43d8ff"),
    "lock_corner_gold": (lambda m: corner(LEADS["gold"]), "ffc23a"),
    "lock_corner_red": (lambda m: corner(LEADS["red"]), "ff3b5c"),
    "lock_core": (lock_core, "ff3b5c"),
    "pod": (lambda m: pod(False), "43d8ff"),
    "pod_armed": (lambda m: pod(True), "ff3b5c"),
    "pod_rocket": (pod_rocket, "ffb347"),
    "shield_core": (shield_core, "44e3ff"),
    "warn_arrow": (warn_arrow, "ff3b5c"),
}


def render(name, samples):
    builder, glow = SPECS[name]
    kit.stage(RENDER, RENDER, samples)
    m = kit.icon_materials()
    builder(m)
    kit.fit_camera(RENDER, RENDER, 34)
    img = kit.render_rgba(RENDER, RENDER)
    return kit.decorate(img, glow=(glow, 0.5, 7.0), inner=(glow, 0.18, 6.0), shadow=(6, 5.0, 0.45))


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    a = img[..., 3]
    img = img.copy()
    img[..., 3] = np.where(a < 1.5 / 255.0, 0.0, a)
    im = Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA").resize((FINAL, FINAL), Image.LANCZOS)
    path = OUT / f"{name}.webp"
    im.save(path, "WEBP", quality=88, method=6, alpha_quality=95)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--samples", type=int, default=SAMPLES)
    args = parser.parse_args(argv)
    wanted = [s for s in args.only.split(",") if s]
    for name in SPECS:
        if wanted and name not in wanted:
            continue
        print(f"[item-hud] {save(render(name, args.samples), name).name}", flush=True)
    total = sum(p.stat().st_size for p in OUT.glob("*.webp"))
    print(f"[item-hud] {len(list(OUT.glob('*.webp')))} Dateien, {total // 1024} KB")


if __name__ == "__main__":
    main()
