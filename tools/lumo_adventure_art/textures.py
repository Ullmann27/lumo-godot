#!/usr/bin/env python3
"""Eigenbau-Texturen für die Abenteuerwelten (Schatzinsel, Bühne, Atelier, Spielewelt).

Ausführen: /home/user/tools/bpyenv/bin/python tools/lumo_adventure_art/textures.py
Alles wird aus Rauschen, Formeln und gezeichneten Polygonen erzeugt: keine
fremden Bilder, keine Downloads. Gleicher Seed -> gleiche Bytes (reproduzierbar).
Kachelbare Flächen entstehen per FFT-Rauschen (von Natur aus periodisch).
Blattkarten haben Alpha und eingefärbte transparente Ränder (kein dunkler
Mipmap-Saum).
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/adventure/textures"


def rng(seed):
    return np.random.default_rng(seed)


def fnoise(size, beta, seed, aniso=(1.0, 1.0)):
    """Periodisches 1/f^beta-Rauschen in [0,1]. aniso streckt Frequenzen (x, y)."""
    h, w = (size, size) if isinstance(size, int) else size
    r = rng(seed)
    white = r.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * aniso[1]
    fx = np.fft.fftfreq(w)[None, :] * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(white) / (f ** beta)
    spec[0, 0] = 0
    out = np.real(np.fft.ifft2(spec))
    out -= out.min()
    out /= max(out.max(), 1e-9)
    return out


def lerp(a, b, t):
    return a + (b - a) * t


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def ramp(t, stops):
    """t (HxW in 0..1) durch Farbstopps [(pos, 'hex'), ...] -> HxWx3."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[..., None]
        out[m] = lerp(hexc(c0), hexc(c1), k)[m]
    return out


def normal_from_height(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save_rgb(arr, name, quality=90):
    img = Image.fromarray(np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")
    path = OUT / name
    if name.endswith(".jpg"):
        img.save(path, quality=quality, subsampling=0)
    else:
        img.save(path, optimize=True)
    return path


def save_rgba(img, name):
    path = OUT / name
    img.save(path, optimize=True)
    return path


def bleed(img, passes=10):
    """Transparente Pixel bekommen die Farbe ihrer Nachbarn (gegen dunkle Säume)."""
    a = np.asarray(img).astype(np.float64) / 255.0
    rgb, alpha = a[..., :3].copy(), a[..., 3].copy()
    known = alpha > 0.02
    acc = rgb * known[..., None]
    wsum = known.astype(np.float64)
    for _ in range(passes):
        sm = sum(np.roll(np.roll(acc, dy, 0), dx, 1) for dy in (-2, 0, 2) for dx in (-2, 0, 2))
        sw = sum(np.roll(np.roll(wsum, dy, 0), dx, 1) for dy in (-2, 0, 2) for dx in (-2, 0, 2))
        fill = ~known & (sw > 0)
        rgb[fill] = sm[fill] / sw[fill][:, None]
        known = known | fill
        acc = rgb * known[..., None]
        wsum = known.astype(np.float64)
    mean = rgb[alpha > 0.02].mean(0) if (alpha > 0.02).any() else np.zeros(3)
    rgb[~known] = mean
    out = np.concatenate([rgb, alpha[..., None]], -1)
    return Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- Bodenflächen

def grass_ground(n=1024):
    base = fnoise(n, 1.15, 11)
    patches = fnoise(n, 1.9, 12)
    blades = fnoise(n, 0.35, 13, aniso=(0.35, 1.6))
    dry = np.clip((fnoise(n, 2.1, 14) - 0.55) * 3.0, 0, 1)
    t = np.clip(0.18 + base * 0.55 + (blades - 0.5) * 0.45, 0, 1)
    col = ramp(t, [(0, "26401c"), (0.35, "3d6127"), (0.62, "5d8434"), (0.85, "86a447"), (1, "a8b85c")])
    col = lerp(col, col * hexc("c9b46a") * 1.35, dry[..., None] * 0.55)
    col *= (0.82 + patches * 0.3)[..., None]
    # Kleine Kleeblätter / Blüten als Punkte (Detail aus der Nähe).
    r = rng(15)
    img = Image.fromarray(np.clip(col * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    for _ in range(int(n * n / 2600)):
        x, y = r.integers(0, n, 2)
        rad = r.uniform(1.2, 2.6)
        c = [(240, 236, 214), (246, 214, 92), (196, 168, 236)][r.integers(0, 3)]
        if r.random() < 0.6:
            continue
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.ellipse([x + ox - rad, y + oy - rad, x + ox + rad, y + oy + rad], fill=c)
    col = np.asarray(img).astype(np.float64) / 255.0
    height = base * 0.4 + blades * 0.6
    nrm = normal_from_height(height, 3.2)
    small = Image.fromarray(np.clip(nrm * 255, 0, 255).astype(np.uint8)).resize((n // 2, n // 2), Image.LANCZOS)
    return col, np.asarray(small).astype(np.float64) / 255.0


def sand(n=512):
    fine = fnoise(n, 0.25, 21)
    mid = fnoise(n, 1.4, 22)
    yy, xx = np.mgrid[0:n, 0:n] / n
    ripple = 0.5 + 0.5 * np.sin((yy * 9 + mid * 2.2) * 2 * math.pi)
    t = np.clip(0.3 + mid * 0.45 + (fine - 0.5) * 0.35 + ripple * 0.08, 0, 1)
    col = ramp(t, [(0, "a8916a"), (0.4, "cdb68b"), (0.75, "e2cfa4"), (1, "f1e3bf")])
    r = rng(23)
    img = Image.fromarray(np.clip(col * 255, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    for _ in range(900):
        x, y = r.integers(0, n, 2)
        s = r.uniform(0.6, 1.8)
        c = tuple(int(v) for v in r.choice([[120, 104, 86], [236, 230, 214], [168, 120, 96]]))
        d.ellipse([x - s, y - s, x + s, y + s], fill=c)
    col = np.asarray(img).astype(np.float64) / 255.0
    return col, normal_from_height(ripple * 0.5 + fine * 0.5, 2.0)


def rock(n=512, seed=31, warm=False):
    big = fnoise(n, 2.0, seed)
    mid = fnoise(n, 1.3, seed + 1)
    fine = fnoise(n, 0.5, seed + 2)
    strata = 0.5 + 0.5 * np.sin((np.mgrid[0:n, 0:n][0] / n * 7 + big * 3.0) * 2 * math.pi)
    crack = np.abs(fnoise(n, 1.6, seed + 3) - 0.5)
    crack = np.clip(1.0 - crack * 22, 0, 1) ** 2
    t = np.clip(0.2 + mid * 0.5 + fine * 0.2 + strata * 0.12 - crack * 0.35, 0, 1)
    stops = ([(0, "3e3832"), (0.4, "6e6458"), (0.75, "9c907e"), (1, "c4b8a2")] if warm
             else [(0, "34363a"), (0.4, "5f6062"), (0.75, "8b8a86"), (1, "b6b2a8")])
    col = ramp(t, stops)
    lichen = np.clip((fnoise(n, 1.7, seed + 4) - 0.68) * 5, 0, 1)
    col = lerp(col, hexc("8f9a5a"), lichen[..., None] * 0.45)
    height = mid * 0.5 + fine * 0.3 + strata * 0.2 - crack * 0.6
    return col, normal_from_height(height, 4.5)


def dirt_path(n=512):
    base = fnoise(n, 1.3, 41)
    fine = fnoise(n, 0.4, 42)
    t = np.clip(0.25 + base * 0.5 + (fine - 0.5) * 0.4, 0, 1)
    col = ramp(t, [(0, "4a3524"), (0.45, "7a5a3a"), (0.8, "9e7c55"), (1, "bca078")])
    height = base * 0.4 + fine * 0.3
    r = rng(43)
    img = Image.fromarray(np.clip(col * 255, 0, 255).astype(np.uint8), "RGB")
    hmap = Image.fromarray(np.clip(height * 160, 0, 255).astype(np.uint8), "L")
    d, dh = ImageDraw.Draw(img), ImageDraw.Draw(hmap)
    for _ in range(420):
        x, y = r.integers(0, n, 2)
        a, b = r.uniform(2, 7), r.uniform(1.5, 5)
        g = int(r.uniform(110, 190))
        c = (g, int(g * 0.94), int(g * 0.86))
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                box = [x + ox - a, y + oy - b, x + ox + a, y + oy + b]
                d.ellipse(box, fill=c)
                dh.ellipse(box, fill=230)
    col = np.asarray(img).astype(np.float64) / 255.0
    height = np.asarray(hmap.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float64) / 255.0
    return col, normal_from_height(height, 3.0)


# ---------------------------------------------------------------- Rinde, Stein, Holz

def bark(n=512):
    fis = fnoise(n, 1.2, 51, aniso=(0.12, 1.0))
    fine = fnoise(n, 0.6, 52, aniso=(0.3, 1.0))
    blotch = fnoise(n, 1.8, 53)
    ridge = np.clip(1.0 - np.abs(fis - 0.5) * 3.2, 0, 1)
    t = np.clip(0.15 + ridge * 0.6 + fine * 0.25, 0, 1)
    col = ramp(t, [(0, "1e1510"), (0.35, "3c2c20"), (0.7, "65503c"), (1, "8f7a60")])
    moss = np.clip((blotch - 0.6) * 4, 0, 1)
    col = lerp(col, hexc("4f6a2c"), moss[..., None] * 0.5)
    return col, normal_from_height(ridge * 0.7 + fine * 0.3, 6.0)


def palm_bark(n=512):
    yy = np.mgrid[0:n, 0:n][0] / n
    warp = fnoise(n, 1.6, 61)
    rings = (yy * 10 + warp * 0.35) % 1.0
    ring_h = np.clip(1.0 - rings * 1.4, 0, 1) ** 0.6
    fib = fnoise(n, 0.5, 62, aniso=(0.18, 1.0))
    t = np.clip(0.2 + ring_h * 0.55 + fib * 0.3, 0, 1)
    col = ramp(t, [(0, "3a2a1c"), (0.4, "6b5236"), (0.75, "9a7e58"), (1, "c2a77e")])
    return col, normal_from_height(ring_h * 0.8 + fib * 0.2, 7.0)


def masonry(n=512, seed=71):
    """Ruinenstein: unregelmäßige Quader, Fugen, Risse, Abplatzungen."""
    r = rng(seed)
    height = np.zeros((n, n))
    col = np.zeros((n, n, 3))
    rows = 6
    rh = n // rows
    tone = fnoise(n, 1.3, seed + 1)
    fine = fnoise(n, 0.5, seed + 2)
    for row in range(rows):
        x = int(r.integers(0, rh))
        y0 = row * rh
        while x < n + rh:
            w = int(r.integers(int(rh * 0.9), int(rh * 1.9)))
            shade = r.uniform(0.82, 1.12)
            x0, x1 = x, x + w
            ys = slice(y0 + 3, y0 + rh - 3)
            for xs in range(x0 + 3, x1 - 3):
                xi = xs % n
                height[ys, xi] = 0.6 + 0.4 * shade - 0.3
                col[ys, xi] = shade
            x = x1
    edge = np.asarray(Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2))) / 255.0
    crack = np.clip(1.0 - np.abs(fnoise(n, 1.5, seed + 3) - 0.5) * 30, 0, 1) ** 2
    t = np.clip(0.25 + tone * 0.45 + fine * 0.2, 0, 1)
    stone = ramp(t, [(0, "5c5246"), (0.5, "8e8270"), (0.85, "b3a68e"), (1, "cbbfa5")])
    mortar = hexc("4a4238")
    shade = np.where(col[..., :1] > 0, col[..., :1], 0)
    out = np.where(height[..., None] > 0.05, stone * shade, mortar)
    out = lerp(out, out * 0.35, crack[..., None] * (height[..., None] > 0.05))
    grime = np.clip((fnoise(n, 1.9, seed + 4) - 0.5) * 2.2, 0, 1)
    out = lerp(out, out * hexc("6e7a4a") * 1.3, grime[..., None] * 0.35)
    h = edge * 0.8 + fine * 0.15 - crack * 0.4
    return out, normal_from_height(h, 5.0)


def moss(n=512):
    a = fnoise(n, 1.0, 81)
    b = fnoise(n, 0.3, 82)
    t = np.clip(0.2 + a * 0.5 + (b - 0.5) * 0.6, 0, 1)
    col = ramp(t, [(0, "1f3412"), (0.4, "3e5d1e"), (0.75, "68862e"), (1, "9bb04a")])
    return col, normal_from_height(a * 0.4 + b * 0.6, 4.0)


def wood(n=512, seed=91, tint="7a5634"):
    yy, xx = np.mgrid[0:n, 0:n] / n
    warp = fnoise(n, 1.5, seed, aniso=(0.2, 1.0))
    grain = 0.5 + 0.5 * np.sin((xx * 24 + warp * 4) * 2 * math.pi)
    fine = fnoise(n, 0.5, seed + 1, aniso=(0.15, 1.0))
    planks = (xx * 4) % 1.0
    gap = (planks < 0.012) | (planks > 0.988)
    t = np.clip(0.3 + grain * 0.35 + fine * 0.3, 0, 1)
    base = hexc(tint)
    col = ramp(t, [(0, "2b1c10"), (0.5, "5a3e24"), (1, "9a744a")]) * (base / hexc("7a5634"))
    col = np.clip(col, 0, 1)
    col[gap] *= 0.35
    return col, normal_from_height(grain * 0.4 + fine * 0.4 - gap * 0.8, 3.0)


def plaster(n=512):
    a = fnoise(n, 1.4, 101)
    b = fnoise(n, 0.4, 102)
    t = np.clip(0.55 + a * 0.3 + (b - 0.5) * 0.2, 0, 1)
    col = ramp(t, [(0, "a49c90"), (0.6, "e2dbcf"), (1, "f6f1e8")])
    stain = np.clip((fnoise(n, 1.8, 103, aniso=(1, 0.3)) - 0.6) * 3, 0, 1)
    col = lerp(col, col * 0.78, stain[..., None])
    return col, normal_from_height(a * 0.5 + b * 0.5, 2.0)


def fabric(n=256):
    yy, xx = np.mgrid[0:n, 0:n]
    weave = (np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)) * 0.5 + 0.5
    a = fnoise(n, 1.2, 111)
    t = np.clip(0.5 + weave * 0.25 + (a - 0.5) * 0.4, 0, 1)
    col = ramp(t, [(0, "6e4e2e"), (0.5, "b28a5a"), (1, "e0c08e")])
    return col, normal_from_height(weave * 0.6 + a * 0.2, 1.5)


def roof_tiles(n=512, seed=161):
    """Schindeldach: versetzte Bogenreihen, leicht verwittert (kachelbar)."""
    yy, xx = np.mgrid[0:n, 0:n] / n
    rows = 8
    row = np.floor(yy * rows)
    fy = (yy * rows) % 1.0
    shift = (row % 2) * 0.5
    fx = (xx * rows + shift) % 1.0
    arc = np.sqrt(((fx - 0.5) * 1.0) ** 2 + (fy * 0.9) ** 2)
    h = np.clip(1.0 - fy, 0, 1) * 0.7 + np.clip(0.55 - arc, 0, 1) * 0.6
    edge = (np.abs(fx - 0.5) > 0.47) | (fy > 0.93)
    tone = fnoise(n, 1.5, seed)
    var = rng(seed).uniform(0.82, 1.12, (rows, rows * 2))
    tile_id = (row.astype(int) % rows, np.floor(xx * rows + shift).astype(int) % (rows * 2))
    shade = var[tile_id]
    col = ramp(np.clip(0.3 + tone * 0.5, 0, 1), [(0, "203a72"), (0.5, "2f5aa4"), (1, "5a86c8")]) * shade[..., None]
    col = lerp(col, col * 0.85 + hexc("6a7a5a") * 0.15, np.clip((fnoise(n, 1.8, seed + 1) - 0.6) * 3, 0, 1)[..., None])
    col[edge] *= 0.45
    return np.clip(col, 0, 1), normal_from_height(h - edge * 0.5, 4.0)


def water_normal(n=512):
    a = fnoise(n, 1.6, 121)
    b = fnoise(n, 1.1, 122)
    return normal_from_height(a * 0.7 + b * 0.3, 9.0)


def felt(n=512, seed=131):
    a = fnoise(n, 0.2, seed)
    b = fnoise(n, 1.4, seed + 1)
    t = np.clip(0.4 + (a - 0.5) * 0.5 + b * 0.25, 0, 1)
    col = ramp(t, [(0, "1c3a2c"), (0.5, "2f5a44"), (1, "4c7e62")])
    return col, normal_from_height(a, 1.2)


def paper(n=512, seed=141):
    a = fnoise(n, 0.15, seed)
    fib = fnoise(n, 0.7, seed + 1, aniso=(1.0, 0.25))
    b = fnoise(n, 1.6, seed + 2)
    t = np.clip(0.6 + (a - 0.5) * 0.25 + (fib - 0.5) * 0.3 + b * 0.12, 0, 1)
    col = ramp(t, [(0, "b9ad94"), (0.6, "e9e1cf"), (1, "fbf7ec")])
    return col, normal_from_height(a * 0.5 + fib * 0.5, 1.4)


def metal_mesh(n=256):
    yy, xx = np.mgrid[0:n, 0:n]
    holes = ((xx % 16 - 8) ** 2 + (yy % 16 - 8) ** 2) < 22
    a = fnoise(n, 0.8, 151)
    col = np.where(holes[..., None], np.array([0.03, 0.03, 0.035]), (0.16 + a[..., None] * 0.08) * np.ones(3))
    h = np.where(holes, 0.0, 1.0)
    h = np.asarray(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))) / 255.0
    return col, normal_from_height(h, 2.5)


# ---------------------------------------------------------------- Karten mit Alpha

def _leaf_poly(cx, cy, length, width, angle, tip=0.9):
    pts = []
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(math.pi * t) ** 0.85 * width * (1 - 0.35 * t)
        pts.append((t * length, w))
    for i in range(steps, -1, -1):
        t = i / steps
        w = math.sin(math.pi * t) ** 0.85 * width * (1 - 0.35 * t)
        pts.append((t * length, -w))
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def _rot(cx, cy, x, y, a):
    ca, sa = math.cos(a), math.sin(a)
    return (cx + x * ca - y * sa, cy + x * sa + y * ca)


def broadleaf_atlas(n=1024, seed=201, palette=None):
    """2x2 Zweige mit vielen Einzelblättern (Laubbaum-Krone)."""
    s = 2
    big = n * s
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(seed)
    palette = palette or [(52, 86, 30), (70, 110, 38), (92, 132, 46), (118, 150, 58), (60, 98, 40), (140, 160, 70)]
    cell = big // 2
    for cy in range(2):
        for cx in range(2):
            ox, oy = cx * cell, cy * cell
            # Zweig von unten-Mitte nach oben
            base = (ox + cell * 0.5, oy + cell * 0.98)
            twigs = []
            for k in range(7):
                ang = -math.pi / 2 + r.uniform(-1.0, 1.0)
                ln = cell * r.uniform(0.35, 0.62)
                end = (base[0] + math.cos(ang) * ln, base[1] + math.sin(ang) * ln)
                twigs.append((base, end, ang, ln))
                d.line([base, end], fill=(70, 52, 36, 255), width=int(5 * s))
            for (b, e, ang, ln) in twigs:
                for j in range(13):
                    t = 0.18 + j / 13 * 0.85
                    px = b[0] + (e[0] - b[0]) * t
                    py = b[1] + (e[1] - b[1]) * t
                    side = 1 if j % 2 else -1
                    la = ang + side * r.uniform(0.5, 1.1)
                    L = cell * r.uniform(0.11, 0.17)
                    W = L * r.uniform(0.28, 0.38)
                    c = palette[r.integers(0, len(palette))]
                    light = r.uniform(0.85, 1.15)
                    col = tuple(int(min(255, v * light)) for v in c) + (255,)
                    d.polygon(_leaf_poly(px, py, L, W, la), fill=col)
                    tip = _rot(px, py, L * 0.92, 0, la)
                    d.line([(px, py), tip], fill=tuple(int(min(255, v * 1.35)) for v in c) + (255,), width=max(1, int(1.2 * s)))
                # Endblatt
                c = palette[r.integers(0, len(palette))]
                d.polygon(_leaf_poly(e[0], e[1], cell * 0.15, cell * 0.05, ang), fill=c + (255,))
    img = img.resize((n, n), Image.LANCZOS)
    return bleed(img)


def palm_frond(w=1024, h=256, seed=211):
    s = 2
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(seed)
    W, H = w * s, h * s
    cy = H * 0.5
    d.line([(0, cy), (W, cy)], fill=(120, 110, 60, 255), width=int(7 * s))
    count = 46
    for i in range(count):
        t = 0.04 + i / count * 0.94
        x = t * W
        L = H * 0.48 * math.sin(math.pi * min(1, t * 1.08)) ** 0.6 + H * 0.06
        for side in (-1, 1):
            ang = side * (math.pi / 2 - 0.62 - 0.25 * t) + math.pi * 0.0
            ang = math.atan2(side * 1.0, 1.15 - 0.3 * t)
            g = r.uniform(0.82, 1.12)
            c = (int(58 * g), int(112 * g), int(36 * g), 255)
            if r.random() < 0.15:
                c = (int(118 * g), int(128 * g), int(52 * g), 255)
            d.polygon(_leaf_poly(x, cy, L, H * 0.028, ang), fill=c)
            d.line([(x, cy), _rot(x, cy, L * 0.95, 0, ang)], fill=(150, 170, 80, 255), width=max(1, s))
    img = img.resize((w, h), Image.LANCZOS)
    return bleed(img)


def fern_frond(w=512, h=256, seed=221):
    s = 2
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(seed)
    W, H = w * s, h * s
    cy = H * 0.5
    d.line([(0, cy), (W * 0.98, cy)], fill=(70, 96, 40, 255), width=int(4 * s))
    count = 26
    for i in range(count):
        t = 0.05 + i / count * 0.92
        x = t * W
        L = H * 0.46 * (1 - t) ** 0.7 + H * 0.05
        for side in (-1, 1):
            ang = math.atan2(side * 1.0, 0.75)
            g = r.uniform(0.85, 1.15)
            # Fiederblatt aus kleinen Lappen
            for k in range(6):
                u = (k + 0.5) / 6
                px, py = _rot(x, cy, L * u, 0, ang)
                sz = H * 0.03 * (1 - u * 0.6)
                c = (int(48 * g), int(104 * g), int(34 * g), 255)
                d.ellipse([px - sz, py - sz * 0.7, px + sz, py + sz * 0.7], fill=c)
            d.line([(x, cy), _rot(x, cy, L, 0, ang)], fill=(60, 110, 40, 255), width=max(1, s))
    img = img.resize((w, h), Image.LANCZOS)
    return bleed(img)


def grass_tufts(w=1024, h=256, seed=231):
    """Links Gräser, rechts Gräser mit Wildblumen; unten Wurzel, oben Spitzen."""
    s = 2
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(seed)
    W, H = w * s, h * s
    for half in (0, 1):
        x0 = half * W / 2
        for _ in range(170):
            bx = x0 + r.uniform(0.04, 0.96) * W / 2
            height = H * r.uniform(0.45, 0.97)
            lean = r.uniform(-0.35, 0.35)
            width = r.uniform(3, 7) * s
            g = r.uniform(0.75, 1.2)
            dry = r.random() < 0.18
            base_c = (np.array([70, 112, 40]) * g) if not dry else (np.array([150, 140, 80]) * g)
            tip_c = base_c * np.array([1.35, 1.25, 1.1]) if not dry else base_c * 1.15
            segs = 8
            pts_l, pts_r = [], []
            for k in range(segs + 1):
                t = k / segs
                cx = bx + lean * height * t * t
                cyy = H - t * height
                ww = width * (1 - t) + 0.4
                pts_l.append((cx - ww, cyy))
                pts_r.append((cx + ww, cyy))
            colr = tuple(int(min(255, v)) for v in lerp(base_c * 0.55, tip_c, 0.6)) + (255,)
            d.polygon(pts_l + pts_r[::-1], fill=colr)
        if half == 1:
            for _ in range(26):
                fx = x0 + r.uniform(0.08, 0.92) * W / 2
                fy = H * r.uniform(0.08, 0.45)
                d.line([(fx, fy), (fx + r.uniform(-8, 8), H)], fill=(66, 100, 40, 255), width=2 * s)
                c = [(250, 246, 230), (250, 210, 70), (190, 150, 240), (240, 120, 150), (120, 170, 250)][r.integers(0, 5)]
                pr = r.uniform(6, 11) * s
                for p in range(5):
                    a = p / 5 * 2 * math.pi
                    px, py = fx + math.cos(a) * pr * 0.7, fy + math.sin(a) * pr * 0.7
                    d.ellipse([px - pr * 0.55, py - pr * 0.55, px + pr * 0.55, py + pr * 0.55], fill=c + (255,))
                d.ellipse([fx - pr * 0.35, fy - pr * 0.35, fx + pr * 0.35, fy + pr * 0.35], fill=(240, 190, 40, 255))
    img = img.resize((w, h), Image.LANCZOS)
    return bleed(img)


def wing_atlas(n=512, seed=241):
    """Schmetterlingsflügel (oben links/rechts in 4 Farben) + Möwenflügel (unten)."""
    s = 2
    N = n * s
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cols = [((250, 160, 40), (40, 20, 10)), ((80, 160, 250), (20, 30, 60)),
            ((250, 240, 120), (90, 70, 20)), ((230, 110, 200), (60, 20, 50))]
    cell = N // 4
    for i, (main, edge) in enumerate(cols):
        ox = i * cell
        cx, cy = ox + cell * 0.5, cell * 0.5
        for side in (-1, 1):
            up = [(cx, cy), (cx + side * cell * 0.46, cy - cell * 0.42), (cx + side * cell * 0.48, cy - cell * 0.05)]
            lo = [(cx, cy + 4), (cx + side * cell * 0.36, cy + cell * 0.4), (cx + side * cell * 0.1, cy + cell * 0.44)]
            d.polygon(up, fill=edge + (255,))
            d.polygon(lo, fill=edge + (255,))
            up2 = [(cx + side * 6, cy), (cx + side * cell * 0.4, cy - cell * 0.34), (cx + side * cell * 0.42, cy - cell * 0.08)]
            lo2 = [(cx + side * 6, cy + 6), (cx + side * cell * 0.3, cy + cell * 0.33), (cx + side * cell * 0.12, cy + cell * 0.37)]
            d.polygon(up2, fill=main + (255,))
            d.polygon(lo2, fill=main + (255,))
            ex, ey = cx + side * cell * 0.3, cy - cell * 0.2
            d.ellipse([ex - 10 * s, ey - 10 * s, ex + 10 * s, ey + 10 * s], fill=(250, 250, 250, 255))
            d.ellipse([ex - 5 * s, ey - 5 * s, ex + 5 * s, ey + 5 * s], fill=edge + (255,))
        d.rectangle([cx - 3 * s, cy - cell * 0.25, cx + 3 * s, cy + cell * 0.35], fill=(30, 24, 20, 255))
    # Möwe: Flügel als Feder-Fächer, weiß mit grauer Spitze
    gy = cell + cell * 0.2
    for side in (-1, 1):
        cx = N * 0.5
        for f in range(14):
            t = f / 13
            x1 = cx + side * N * 0.46 * (0.25 + 0.75 * t)
            y1 = gy + cell * 0.1 + t * cell * 0.2
            c = (240, 242, 246) if t < 0.72 else (70, 74, 82)
            d.polygon([(cx + side * N * 0.04, gy), (x1, y1 - cell * 0.12), (x1, y1 + cell * 0.12), (cx + side * N * 0.04, gy + cell * 0.25)], fill=c + (255,))
    img = img.resize((n, n), Image.LANCZOS)
    return bleed(img)


def flame(n=256):
    yy, xx = np.mgrid[0:n, 0:n] / n
    a = fnoise(n, 1.2, 251)
    shape = np.clip(1.0 - (np.abs(xx - 0.5) * 2.2 / (0.25 + (1 - yy) * 0.75)) ** 2, 0, 1)
    shape *= np.clip((yy - 0.05) * 3, 0, 1) * np.clip((1 - yy) * 1.4 + a * 0.6 - 0.2, 0, 1)
    core = np.clip(shape * 1.6 - 0.4, 0, 1)
    rgb = np.stack([np.ones_like(shape), 0.45 + core * 0.5, 0.08 + core * 0.55], -1)
    alpha = np.clip(shape * 1.4, 0, 1)
    out = np.concatenate([rgb, alpha[..., None]], -1)
    return Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGBA")


def soft_dot(n=128):
    yy, xx = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(xx * xx + yy * yy)
    a = np.clip(1 - r, 0, 1) ** 2.2
    out = np.stack([np.ones_like(a)] * 3 + [a], -1)
    return Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGBA")


def light_beam(w=128, h=256):
    yy, xx = np.mgrid[0:h, 0:w]
    u = xx / (w - 1) * 2 - 1
    v = yy / (h - 1)
    a = np.clip(1 - np.abs(u), 0, 1) ** 1.6 * (1 - v) ** 0.8 * np.clip(v * 8, 0, 1)
    out = np.stack([np.ones_like(a)] * 3 + [a], -1)
    return Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGBA")


def confetti(n=128):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cols = [(255, 214, 90), (98, 220, 255), (185, 151, 255), (119, 239, 189)]
    c = n // 2
    for i, col in enumerate(cols):
        ox, oy = (i % 2) * c, (i // 2) * c
        if i % 2:
            d.rectangle([ox + c * 0.3, oy + c * 0.12, ox + c * 0.7, oy + c * 0.88], fill=col + (255,))
        else:
            pts = []
            for k in range(10):
                a = k / 10 * 2 * math.pi - math.pi / 2
                rr = c * (0.44 if k % 2 == 0 else 0.2)
                pts.append((ox + c / 2 + math.cos(a) * rr, oy + c / 2 + math.sin(a) * rr))
            d.polygon(pts, fill=col + (255,))
    return img


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    written = {}

    def pair(fn, stem, albedo_ext=".jpg", **kw):
        col, nrm = fn(**kw)
        written[stem + "_albedo" + albedo_ext] = save_rgb(col, stem + "_albedo" + albedo_ext)
        written[stem + "_normal.jpg"] = save_rgb(nrm, stem + "_normal.jpg", quality=92)

    pair(grass_ground, "grass")
    pair(sand, "sand")
    pair(rock, "rock")
    pair(rock, "stone", seed=35, warm=True)
    pair(dirt_path, "path")
    pair(bark, "bark")
    pair(palm_bark, "palm_bark")
    pair(masonry, "ruin")
    pair(moss, "moss")
    pair(wood, "wood")
    pair(plaster, "plaster")
    pair(fabric, "fabric")
    pair(roof_tiles, "roof")
    pair(felt, "felt")
    pair(paper, "paper")
    pair(metal_mesh, "speaker_mesh")
    pair(wood, "table_wood", seed=97, tint="8a5a34")
    written["water_normal.jpg"] = save_rgb(water_normal(), "water_normal.jpg", quality=92)
    written["leaves_broad.png"] = save_rgba(broadleaf_atlas(), "leaves_broad.png")
    written["leaves_autumn.png"] = save_rgba(broadleaf_atlas(512, 207, [(150, 120, 40), (120, 130, 44), (176, 96, 38), (90, 120, 40), (190, 150, 60)]), "leaves_autumn.png")
    written["palm_frond.png"] = save_rgba(palm_frond(), "palm_frond.png")
    written["fern_frond.png"] = save_rgba(fern_frond(), "fern_frond.png")
    written["grass_tufts.png"] = save_rgba(grass_tufts(), "grass_tufts.png")
    written["wings.png"] = save_rgba(wing_atlas(), "wings.png")
    written["flame.png"] = save_rgba(flame(), "flame.png")
    written["soft_dot.png"] = save_rgba(soft_dot(), "soft_dot.png")
    written["light_beam.png"] = save_rgba(light_beam(), "light_beam.png")
    written["confetti.png"] = save_rgba(confetti(), "confetti.png")
    manifest = {name: {"bytes": p.stat().st_size, "size": list(Image.open(p).size)} for name, p in sorted(written.items())}
    (OUT / "textures.json").write_text(json.dumps({"generator": "tools/lumo_adventure_art/textures.py",
                                                   "license": "Eigenbau, prozedural, keine fremden Bilder",
                                                   "textures": manifest}, indent=1) + "\n")
    return manifest


if __name__ == "__main__":
    m = build()
    total = sum(v["bytes"] for v in m.values())
    for k, v in m.items():
        print(f"{k:28s} {v['size']} {v['bytes'] / 1024:.0f} KB")
    print(f"total {total / 1048576:.2f} MB")
