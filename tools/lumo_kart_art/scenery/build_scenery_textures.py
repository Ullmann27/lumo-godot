#!/usr/bin/env python3
"""Selbst erzeugte Texturen der Lumo-Kart-Streckenkulisse (keine fremden Bilder).

Ausgabe unter assets/kart/scenery/textures/:
  foliage_albedo.png  1024x1024 RGBA, 4x4 Zellen a 256 px (Blattkarten mit Alpha)
  foliage_normal.png  1024x1024 RGB  (Blattwoelbung, Mittelrippe, Adern)
  bark_albedo.png     1024x1024 RGB  (4 Rindenstreifen a 256 px, vertikal kachelbar)
  bark_normal.png     1024x1024 RGB
  rock_albedo.png / rock_normal.png  512x512 (kachelbar)
  lamp_albedo.png     256x256 RGB    (Metall/Holz/Stein der Leuchten, 4x4 Farbfelder)

Zellen der Blatt-Atlas (Spalte, Zeile):
  (0,0) Laub gruen   (1,0) Laub hell    (2,0) Nadelzweig    (3,0) Nadelzweig mit Schnee
  (0,1)+(1,1) Palmwedel (doppelt breit)  (2,1) Dschungelblaetter (3,1) Zauberwald-Blaetter
  (0,2) Grasbueschel (1,2) Blumenwiese   (2,2) Farn          (3,2) Buschblaetter
  (0,3) Trockengras  (1,3) Schneegras    (2,3) Herbstlaub    (3,3) Einzelblaetter 4x4 (Partikel)
Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/scenery/build_scenery_textures.py
"""
from __future__ import annotations

import colorsys
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/scenery/textures"
CELL = 256
SS = 2  # supersampling
RNG = np.random.default_rng(20261118)


def rgb(hex_color: str) -> tuple[int, int, int]:
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4))


def vary(color, hue=0.03, sat=0.12, val=0.14):
    r, g, b = [c / 255.0 for c in color]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h + RNG.uniform(-hue, hue)) % 1.0
    s = min(1.0, max(0.0, s * (1.0 + RNG.uniform(-sat, sat))))
    v = min(1.0, max(0.0, v * (1.0 + RNG.uniform(-val, val))))
    return tuple(int(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))


class Cell:
    """Zeichenflaeche einer Atlaszelle in Supersampling mit Hoehenkarte."""

    def __init__(self, w=1, h=1):
        self.W, self.H = CELL * w * SS, CELL * h * SS
        self.color = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.height = Image.new("L", (self.W, self.H), 0)
        self.dc = ImageDraw.Draw(self.color)
        self.dh = ImageDraw.Draw(self.height)

    def line(self, pts, width, color, height=90):
        pts = [(x * SS, y * SS) for x, y in pts]
        self.dc.line(pts, fill=color + (255,), width=max(1, int(width * SS)), joint="curve")
        self.dh.line(pts, fill=height, width=max(1, int(width * SS)))

    def leaf(self, base, angle, length, width, color, tip=0.55, serrate=0.0, vein=True, lobes=0):
        """Eiförmiges Blatt mit Spitze, Mittelrippe, Seitenadern und Woelbung."""
        bx, by = base
        ca, sa = math.cos(angle), math.sin(angle)
        n = 28
        outline_l, outline_r = [], []
        for i in range(n + 1):
            t = i / n
            # Breitenprofil: rund am Grund, spitz am Ende
            w = math.sin(math.pi * min(1.0, t ** 0.8)) ** tip * width * 0.5
            if serrate:
                w *= 1.0 - serrate * (0.5 + 0.5 * math.sin(t * 40.0))
            if lobes:
                w *= 0.75 + 0.25 * abs(math.sin(t * math.pi * lobes))
            outline_l.append((t * length, w))
            outline_r.append((t * length, -w))
        poly = outline_l + outline_r[::-1]

        def tr(p):
            x, y = p
            return ((bx + x * ca - y * sa) * SS, (by + x * sa + y * ca) * SS)

        pts = [tr(p) for p in poly]
        self.dc.polygon(pts, fill=color + (255,))
        # Woelbung: Hoehe faellt zum Rand hin ab (mehrere geschrumpfte Konturen)
        for k, h in enumerate((70, 120, 170, 210)):
            f = 1.0 - k * 0.22
            sp = [tr((x, y * f)) for x, y in poly]
            self.dh.polygon(sp, fill=h)
        # Lichtverlauf zur Spitze und dunklerer Rand
        tip_col = tuple(min(255, int(c * 1.16)) for c in color)
        sp = [tr((x * 0.55 + length * 0.42, y * 0.55)) for x, y in poly]
        self.dc.polygon(sp, fill=tip_col + (255,))
        if vein:
            rib = tuple(int(c * 0.72 + 50) for c in color)
            self.dc.line([tr((0, 0)), tr((length * 0.92, 0))], fill=rib + (255,), width=max(1, int(width * 0.06 * SS)))
            self.dh.line([tr((0, 0)), tr((length * 0.92, 0))], fill=235, width=max(1, int(width * 0.06 * SS)))
            for j in range(1, 6):
                t = j / 6.5
                for s in (-1, 1):
                    a = tr((t * length, 0))
                    b = tr((t * length + length * 0.16, s * width * 0.36 * math.sin(math.pi * t) ** 0.5))
                    vc = tuple(int(c * 0.86 + 20) for c in color)
                    self.dc.line([a, b], fill=vc + (255,), width=max(1, int(width * 0.025 * SS)))

    def blob(self, center, radius, color, height=200):
        x, y = center
        box = [(x - radius) * SS, (y - radius) * SS, (x + radius) * SS, (y + radius) * SS]
        self.dc.ellipse(box, fill=color + (255,))
        self.dh.ellipse(box, fill=height)

    def finish(self):
        """Herunterrechnen, Farbe in transparente Raender ausbluten lassen."""
        size = (self.W // SS, self.H // SS)
        img = self.color.resize(size, Image.LANCZOS)
        hgt = self.height.filter(ImageFilter.GaussianBlur(1.6 * SS)).resize(size, Image.LANCZOS)
        a = np.asarray(img).astype(np.float32)
        alpha = a[..., 3:4] / 255.0
        col = a[..., :3]
        # Ausbluten: mehrfach weichzeichnen und nur leere Pixel auffuellen
        fill = col * alpha
        weight = alpha.copy()
        for radius in (2, 4, 8, 16, 32):
            fb = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(radius))).astype(np.float32)
            wb = np.asarray(Image.fromarray((weight[..., 0] * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(radius))).astype(np.float32)[..., None] / 255.0
            est = fb / np.maximum(wb, 1e-3)
            empty = weight < 0.5
            col = np.where(empty & (wb > 0.02), est, col)
            weight = np.where(empty & (wb > 0.02), 1.0, weight)
            fill = col * weight
        out = np.concatenate([np.clip(col, 0, 255), a[..., 3:4]], axis=-1).astype(np.uint8)
        return Image.fromarray(out, "RGBA"), np.asarray(hgt).astype(np.float32) / 255.0


def twig(cell, start, end, width, color, bend=0.0):
    pts = []
    for i in range(9):
        t = i / 8
        x = start[0] + (end[0] - start[0]) * t + math.sin(t * math.pi) * bend
        y = start[1] + (end[1] - start[1]) * t
        pts.append((x, y))
    cell.line(pts, width, color)
    return pts


def broadleaf_cell(base_hex, leaf_len=(30, 42), count=46, autumn=False):
    c = Cell()
    base = rgb(base_hex)
    bark = rgb("5a4330")
    stem = twig(c, (128, 252), (128, 30), 5, bark, bend=12)
    for side_i in range(7):
        t = 0.2 + side_i * 0.11
        sx, sy = stem[int(t * 8)]
        for s in (-1, 1):
            ex, ey = sx + s * RNG.uniform(50, 80), sy - RNG.uniform(20, 55)
            twig(c, (sx, sy), (ex, ey), 2.5, bark)
    leaves = []
    while len(leaves) < count:
        x, y = RNG.uniform(46, 210), RNG.uniform(40, 200)
        if (x - 128) ** 2 / 86 ** 2 + (y - 118) ** 2 / 84 ** 2 <= 1:
            leaves.append((y, x))
    for y, x in sorted(leaves):
        ang = math.atan2(y - 250, x - 128) + RNG.uniform(-0.8, 0.8)
        L = RNG.uniform(*leaf_len)
        col = vary(base, 0.025 if not autumn else 0.07, 0.15, 0.2)
        c.leaf((x, y), ang, L, L * RNG.uniform(0.48, 0.62), col, serrate=0.06)
    return c.finish()


def conifer_cell(snow=False):
    c = Cell()
    bark = rgb("5d3f2c")
    needle = rgb("2f5a3a")
    stem = twig(c, (128, 254), (128, 6), 5, bark, bend=6)
    for side_i in range(9):
        t = 0.1 + side_i * 0.095
        sx, sy = stem[min(8, int(t * 8.5))]
        for s in (-1, 1):
            length = (1.0 - t) * 95 + 25
            end = (sx + s * length, sy - length * 0.35)
            pts = twig(c, (sx, sy), end, 2.2, bark)
            for k in range(26):
                u = k / 26
                px = sx + (end[0] - sx) * u
                py = sy + (end[1] - sy) * u
                for ns in (-1, 1):
                    a = math.atan2(end[1] - sy, end[0] - sx) + ns * RNG.uniform(0.7, 1.1)
                    nl = RNG.uniform(9, 15) * (1.0 - u * 0.4)
                    col = vary(needle, 0.02, 0.1, 0.22)
                    c.line([(px, py), (px + math.cos(a) * nl, py + math.sin(a) * nl)], 1.7, col, 150)
    for k in range(60):
        u = k / 60
        px, py = 128 + RNG.uniform(-3, 3), 250 - u * 240
        for ns in (-1, 1):
            a = -math.pi / 2 + ns * RNG.uniform(0.5, 1.0)
            c.line([(px, py), (px + math.cos(a) * 13, py + math.sin(a) * 13)], 1.7, vary(needle), 150)
    if snow:
        for _ in range(90):
            x, y = RNG.uniform(20, 236), RNG.uniform(10, 230)
            img = c.color
            if img.getpixel((int(x * SS), int(y * SS)))[3] > 0:
                c.blob((x, y - 2), RNG.uniform(3.5, 8.5), vary(rgb("f2f7ff"), 0.01, 0.05, 0.04), 245)
    return c.finish()


def palm_cell():
    c = Cell(2, 1)
    rachis = rgb("6b7a3a")
    leaf = rgb("3f8a3c")
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((8 + t * 496, 150 - math.sin(t * math.pi) * 70 + t * 40))
    c.line(pts, 5, rachis, 200)
    for i in range(2, 40):
        t = i / 40
        x, y = pts[i]
        dx, dy = pts[i + 1][0] - x, pts[i + 1][1] - y
        a = math.atan2(dy, dx)
        L = 95 * math.sin(math.pi * min(1, t * 1.1)) ** 0.6 + 16
        for s in (-1, 1):
            col = vary(leaf, 0.03, 0.12, 0.2)
            c.leaf((x, y), a + s * (1.05 + RNG.uniform(-0.1, 0.1)), L, 13 * (1 - t * 0.5), col, tip=0.4, vein=False)
    return c.finish()


def jungle_cell():
    c = Cell()
    stem = rgb("4f6b2c")
    for k in range(4):
        base = (128 + RNG.uniform(-30, 30), 254)
        ang = -math.pi / 2 + (k - 1.5) * 0.45
        L = RNG.uniform(120, 150)
        tip = (base[0] + math.cos(ang) * L * 0.45, base[1] + math.sin(ang) * L * 0.45)
        c.line([base, tip], 4, stem)
        col = vary(rgb("2e7a3b"), 0.04, 0.12, 0.18)
        c.leaf(tip, ang, L * 0.62, L * 0.5, col, tip=0.75, lobes=4)
    return c.finish()


def magic_cell():
    c = Cell()
    bark = rgb("3b3550")
    stem = twig(c, (128, 252), (120, 30), 5, bark, bend=-10)
    for side_i in range(6):
        sx, sy = stem[1 + side_i]
        for s in (-1, 1):
            twig(c, (sx, sy), (sx + s * RNG.uniform(50, 85), sy - RNG.uniform(10, 50)), 2.5, bark)
    for _ in range(40):
        x, y = RNG.uniform(50, 206), RNG.uniform(44, 200)
        ang = math.atan2(y - 250, x - 128) + RNG.uniform(-0.9, 0.9)
        base = rgb("3f9a8c") if RNG.random() > 0.3 else rgb("7d86c9")
        L = RNG.uniform(28, 40)
        c.leaf((x, y), ang, L, L * 0.7, vary(base, 0.03, 0.15, 0.2), tip=0.9)
    for _ in range(14):
        c.blob((RNG.uniform(20, 236), RNG.uniform(14, 220)), RNG.uniform(1.6, 3.0), rgb("d8fff4"), 250)
    return c.finish()


def grass_cell(base_hex="4f8f3a", tip_hex="a8c25a", blades=70, height=(150, 240), flowers=None, snow=False):
    c = Cell()
    base, tipc = rgb(base_hex), rgb(tip_hex)
    for _ in range(blades):
        x0 = 128 + RNG.normal(0, 38)
        h = RNG.uniform(*height)
        lean = RNG.uniform(-60, 60)
        n = 10
        pts = []
        for i in range(n + 1):
            t = i / n
            pts.append((x0 + lean * t * t, 255 - h * t))
        for i in range(n):
            t = i / n
            w = 5.5 * (1 - t) + 0.8
            col = tuple(int(base[j] * (1 - t) + tipc[j] * t) for j in range(3))
            col = vary(col, 0.02, 0.08, 0.12)
            if snow and t > 0.6:
                col = tuple(int(c_ * 0.4 + 255 * 0.6) for c_ in col)
            c.line([pts[i], pts[i + 1]], w, col, 120 + int(100 * t))
    if flowers:
        for _ in range(16):
            x, y = 128 + RNG.normal(0, 45), RNG.uniform(40, 150)
            c.line([(x, 255), (x + RNG.uniform(-10, 10), y)], 2.0, rgb("4d8a33"))
            col = rgb(flowers[RNG.integers(len(flowers))])
            for p in range(6):
                a = p * math.tau / 6
                c.blob((x + math.cos(a) * 6, y + math.sin(a) * 6), 5.5, vary(col, 0.02, 0.1, 0.1), 210)
            c.blob((x, y), 3.5, rgb("f6c33a"), 240)
    return c.finish()


def fern_cell():
    c = Cell()
    col = rgb("3d7a35")
    for k in range(5):
        ang = -math.pi / 2 + (k - 2) * 0.42
        base = (128, 254)
        pts = []
        for i in range(21):
            t = i / 20
            a = ang + t * 0.5 * (k - 2) * 0.4
            pts.append((base[0] + math.cos(a) * t * 220, base[1] + math.sin(a) * t * 220 + t * t * 40))
        c.line(pts, 3, rgb("5a7a2c"))
        for i in range(1, 20):
            x, y = pts[i]
            a = math.atan2(pts[i + 1][1] - y, pts[i + 1][0] - x)
            L = 30 * (1 - i / 22)
            for s in (-1, 1):
                c.leaf((x, y), a + s * 1.2, L, 9, vary(col, 0.02, 0.1, 0.18), tip=0.5, vein=False, serrate=0.15)
    return c.finish()


def bush_cell():
    c = Cell()
    bark = rgb("4f3b2a")
    for k in range(5):
        twig(c, (128, 254), (RNG.uniform(30, 226), RNG.uniform(30, 120)), 3, bark, bend=RNG.uniform(-20, 20))
    for _ in range(70):
        x, y = RNG.uniform(16, 240), RNG.uniform(16, 236)
        if (x - 128) ** 2 / 120 ** 2 + (y - 135) ** 2 / 125 ** 2 > 1:
            continue
        L = RNG.uniform(18, 28)
        c.leaf((x, y), RNG.uniform(0, math.tau), L, L * 0.62, vary(rgb("3a7034"), 0.03, 0.15, 0.22), tip=0.7)
    return c.finish()


def single_leaves_cell():
    c = Cell()
    cols = ["d9822b", "e8b23a", "b8452a", "8a9a3a", "c9662a", "f0cd5a", "7a8f36", "d49a3a",
            "f2f6ff", "ffb15a", "ff6a2a", "fff1a8", "e9d3a3", "c9b38a", "9de4ff", "d6b0ff"]
    for i in range(16):
        cx, cy = (i % 4) * 64 + 32, (i // 4) * 64 + 32
        if i < 8:
            c.leaf((cx - 22, cy + 12), -0.5, 44, 26, rgb(cols[i]), tip=0.7)
        else:
            # Weiche runde Flocken/Funken/Staubkoerner fuer Umgebungs-Partikel
            for r, a in ((24, 60), (17, 120), (11, 190), (6, 255)):
                col = rgb(cols[i])
                c.dc.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=col + (a,))
    img, h = c.finish()
    return img, h


def height_to_normal(h, strength=2.5, wrap=False):
    if wrap:
        gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        gx = np.gradient(h, axis=1)
        gy = np.gradient(h, axis=0)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def tile_noise(w, h, scale_x, scale_y, octaves=5, seed=0):
    """Periodische fBm-Rauschtextur (kachelbar)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gx, gy = scale_x * 2 ** o, scale_y * 2 ** o
        grid = rng.random((gy, gx)).astype(np.float32)
        grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w + w // gx, h + h // gy), Image.BICUBIC)
        arr = np.asarray(img).astype(np.float32)[:h, :w] / 255.0
        out += arr * amp
        total += amp
        amp *= 0.55
    return out / total


def bark_strip(kind, w=256, h=1024, seed=1):
    x = np.linspace(0, 1, w, endpoint=False)[None, :]
    y = np.linspace(0, 1, h, endpoint=False)[:, None]
    n1 = tile_noise(w, h, 4, 8, 5, seed)
    n2 = tile_noise(w, h, 16, 8, 4, seed + 7)
    if kind == "oak":
        ridges = np.abs(np.sin((x * 9 + n1 * 1.6) * math.pi))
        height = ridges ** 0.6 * 0.7 + n2 * 0.3
        dark, light = np.array(rgb("3e3024")), np.array(rgb("8a7560"))
    elif kind == "pine":
        plates = tile_noise(w, h, 6, 12, 2, seed + 3)
        cracks = np.abs(np.sin((x * 6 + n1) * math.pi)) * np.abs(np.sin((y * 14 + n1 * 0.7) * math.pi))
        height = np.clip(plates * 0.5 + cracks ** 0.3 * 0.5, 0, 1)
        dark, light = np.array(rgb("3a2219")), np.array(rgb("a8653f"))
    elif kind == "palm":
        rings = np.abs(np.sin((y * 22 + n1 * 0.25) * math.pi)) ** 0.35
        height = rings * 0.75 + n2 * 0.25
        dark, light = np.array(rgb("5a4734")), np.array(rgb("b49a72"))
    else:  # magic: dunkle Rinde mit tuerkisem Moos/Flechten
        ridges = np.abs(np.sin((x * 7 + n1 * 2.0) * math.pi))
        height = ridges ** 0.7 * 0.65 + n2 * 0.35
        dark, light = np.array(rgb("27223a")), np.array(rgb("6f6488"))
    height = (height - height.min()) / (height.max() - height.min())
    col = dark[None, None, :] * (1 - height[..., None]) + light[None, None, :] * height[..., None]
    col *= (0.85 + 0.3 * n2[..., None])
    if kind in ("oak", "magic"):
        moss = np.clip((tile_noise(w, h, 3, 6, 4, seed + 11) - 0.55) * 4, 0, 1) * (1 - height)
        moss_col = np.array(rgb("4f7a3a") if kind == "oak" else rgb("3fb39c"))
        col = col * (1 - moss[..., None] * 0.7) + moss_col * moss[..., None] * 0.7
    return np.clip(col, 0, 255).astype(np.uint8), height


def rock_texture(size=512):
    n = tile_noise(size, size, 4, 4, 6, 41)
    cracks = 1 - np.abs(tile_noise(size, size, 6, 6, 3, 43) - 0.5) * 2
    cracks = np.clip((cracks - 0.9) * 10, 0, 1)
    height = np.clip(n - cracks * 0.35, 0, 1)
    base = np.array(rgb("8c8a84"))
    col = base * (0.62 + 0.55 * height[..., None])
    lichen = np.clip((tile_noise(size, size, 5, 5, 3, 47) - 0.62) * 5, 0, 1)
    col = col * (1 - lichen[..., None] * 0.5) + np.array(rgb("a3a65a")) * lichen[..., None] * 0.5
    speck = (RNG.random((size, size)) > 0.985)[..., None]
    col = np.where(speck, col * 1.25, col)
    return np.clip(col, 0, 255).astype(np.uint8), height


def lamp_texture():
    """4x4 Farbfelder (Metall dunkel/hell, Messing, Holz, Stein, ...) mit feinem Rauschen."""
    swatches = ["262d35", "4b5966", "b08a4a", "6e4a2e", "8a8478", "2f2a3a", "d8dde2", "1c1c22",
                "3b4a3a", "7a5a3a", "e8e0d0", "403830", "56606a", "9a7a4a", "2a3a4a", "5a4a6a"]
    img = np.zeros((256, 256, 3), np.float32)
    n = tile_noise(256, 256, 8, 8, 4, 77)
    for i, s in enumerate(swatches):
        cx, cy = (i % 4) * 64, (i // 4) * 64
        img[cy:cy + 64, cx:cx + 64] = np.array(rgb(s))
    img *= (0.88 + 0.24 * n[..., None])
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    height = np.zeros((1024, 1024), np.float32)

    def put(cell, col, row):
        img, h = cell
        atlas.paste(img, (col * CELL, row * CELL))
        height[row * CELL:row * CELL + h.shape[0], col * CELL:col * CELL + h.shape[1]] = h

    put(broadleaf_cell("3f7f35"), 0, 0)
    put(broadleaf_cell("6a9a3a", (26, 38), 52), 1, 0)
    put(conifer_cell(False), 2, 0)
    put(conifer_cell(True), 3, 0)
    put(palm_cell(), 0, 1)
    put(jungle_cell(), 2, 1)
    put(magic_cell(), 3, 1)
    put(grass_cell(), 0, 2)
    put(grass_cell("4a8a3a", "9fc45a", 55, (90, 200), ["f4f1e6", "f5d14a", "b58cff", "ff7a8a", "7ab8ff"]), 1, 2)
    put(fern_cell(), 2, 2)
    put(bush_cell(), 3, 2)
    put(grass_cell("8a7a4a", "e0c890", 60, (110, 230)), 0, 3)
    put(grass_cell("5a7a6a", "dfe8f0", 55, (80, 190), snow=True), 1, 3)
    put(broadleaf_cell("c8742a", (28, 40), 44, autumn=True), 2, 3)
    put(single_leaves_cell(), 3, 3)
    atlas.save(OUT / "foliage_albedo.png", optimize=True)
    height_to_normal(height, 3.0).save(OUT / "foliage_normal.png", optimize=True)

    bark = np.zeros((1024, 1024, 3), np.uint8)
    bark_h = np.zeros((1024, 1024), np.float32)
    for i, kind in enumerate(("oak", "pine", "palm", "magic")):
        col, h = bark_strip(kind, seed=10 + i)
        bark[:, i * 256:(i + 1) * 256] = col
        bark_h[:, i * 256:(i + 1) * 256] = h
    Image.fromarray(bark, "RGB").save(OUT / "bark_albedo.png", optimize=True)
    height_to_normal(bark_h, 6.0, wrap=True).save(OUT / "bark_normal.png", optimize=True)

    rock, rock_h = rock_texture()
    Image.fromarray(rock, "RGB").save(OUT / "rock_albedo.png", optimize=True)
    height_to_normal(rock_h, 5.0, wrap=True).save(OUT / "rock_normal.png", optimize=True)
    lamp_texture().save(OUT / "lamp_albedo.png", optimize=True)
    for p in sorted(OUT.glob("*.png")):
        print(f"{p.name}: {p.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
