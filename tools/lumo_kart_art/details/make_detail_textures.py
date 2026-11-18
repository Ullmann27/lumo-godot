#!/usr/bin/env python3
"""Erzeugt die Detail-Texturen der Lumo-Kart-Strecken (Eigenbau, keine fremden Bilder).

Ausgabe (je 1024 px, einmal extern abgelegt):
  assets/kart/details/textures/kart_detail_wear_atlas.png    4x4 Kacheln Verwitterung/Gebrauchsspuren
  assets/kart/details/textures/kart_detail_banner_atlas.png  2x16 Banner (Streckennamen + Lumo-Fantasiemarken)

Aufruf: python3 tools/lumo_kart_art/details/make_detail_textures.py
Die Kachelreihenfolge ist ein Vertrag mit scripts/games/visual/kart_detail_layer.gd (WEAR_TILES).
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/kart/details/textures"
FONT = ROOT / "assets/fonts/Nunito-Black.ttf"
TILE = 256
RNG = np.random.default_rng(20261118)

WEAR_TILES = [
    "skid", "oil", "patch", "manhole",
    "puddle", "leaves", "sand", "snow",
    "crack", "streak", "moss", "grime",
    "rust", "plaster", "rubber", "tar",
]


def value_noise(size: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells + 1, cells + 1))
    t = np.linspace(0, cells, size, endpoint=False)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = grid[i][:, i]
    b = grid[i][:, i + 1]
    c = grid[i + 1][:, i]
    d = grid[i + 1][:, i + 1]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size: int, seed: int, octaves: int = 5, base: int = 4) -> np.ndarray:
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += value_noise(size, base * 2 ** o, seed + o * 17) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def coords(size: int = TILE):
    y, x = np.mgrid[0:size, 0:size].astype(float)
    return (x + 0.5) / size, (y + 0.5) / size


def edge_fade(margin: float = 0.12) -> np.ndarray:
    u, v = coords()
    fx = np.clip(np.minimum(u, 1 - u) / margin, 0, 1)
    fy = np.clip(np.minimum(v, 1 - v) / margin, 0, 1)
    return fx * fy


def rgba(rgb, alpha) -> np.ndarray:
    out = np.zeros((TILE, TILE, 4))
    rgb = np.asarray(rgb, dtype=float)
    if rgb.ndim == 1:
        out[..., :3] = rgb
    else:
        out[..., :3] = rgb
    out[..., 3] = np.clip(alpha, 0, 1)
    return out


def tint(color, shade) -> np.ndarray:
    c = np.asarray(color, dtype=float) / 255.0
    return c[None, None, :] * shade[..., None]


def tile_skid(seed):
    u, v = coords()
    n = fbm(TILE, seed)
    alpha = np.zeros((TILE, TILE))
    for centre in (0.30, 0.70):
        path = centre + 0.06 * np.sin(v * 3.2 + seed * 0.3)
        band = np.exp(-((u - path) / 0.055) ** 2)
        streaks = 0.6 + 0.4 * np.sin(u * 190.0 + n * 6.0)
        alpha = np.maximum(alpha, band * streaks)
    alpha *= np.clip(np.minimum(v, 1 - v) / 0.25, 0, 1) * (0.55 + 0.45 * n)
    return rgba(tint((22, 21, 22), 0.9 + 0.1 * n), alpha * 0.82)


def tile_oil(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6)
    r = np.hypot(u - 0.5, (v - 0.5) * 1.15) + (n - 0.5) * 0.22
    alpha = np.clip((0.36 - r) / 0.08, 0, 1)
    sheen = 0.5 + 0.5 * np.sin(r * 40.0 + n * 14.0)
    rgb = np.stack([0.07 + 0.05 * sheen, 0.07 + 0.04 * (1 - sheen), 0.08 + 0.07 * sheen], -1)
    drops = (fbm(TILE, seed + 5, 3, 12) > 0.72) * (r < 0.48)
    alpha = np.maximum(alpha * 0.85, drops * 0.6)
    return rgba(rgb, alpha)


def tile_patch(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6, 8)
    jag = (fbm(TILE, seed + 3, 3, 6) - 0.5) * 0.08
    inside = (np.abs(u - 0.5) < 0.40 + jag) & (np.abs(v - 0.5) < 0.42 - jag)
    rim = (np.abs(np.abs(u - 0.5) - (0.40 + jag)) < 0.022) & (np.abs(v - 0.5) < 0.42) | (
        np.abs(np.abs(v - 0.5) - (0.42 - jag)) < 0.022) & (np.abs(u - 0.5) < 0.40)
    grain = 0.75 + 0.35 * n + (RNG.random((TILE, TILE)) - 0.5) * 0.12
    rgb = tint((44, 46, 50), grain)
    rgb[rim] = np.array([0.05, 0.05, 0.055])
    alpha = inside * 0.55 + rim * 0.9
    return rgba(rgb, np.clip(alpha, 0, 1))


def tile_manhole(seed):
    u, v = coords()
    r = np.hypot(u - 0.5, v - 0.5)
    alpha = np.clip((0.46 - r) / 0.012, 0, 1)
    angle = np.arctan2(v - 0.5, u - 0.5)
    shade = 0.55 + 0.15 * fbm(TILE, seed, 4, 8)
    grid = ((np.floor(u * 22) + np.floor(v * 22)) % 2 == 0) & (r < 0.36)
    shade = shade + grid * 0.12
    rings = (np.abs(r - 0.40) < 0.018) | (np.abs(r - 0.37) < 0.008)
    shade = np.where(rings, 0.32, shade)
    lumo_star = np.abs(np.cos(angle * 5.0 / 2.0)) * 0.10 + 0.05
    shade = np.where(r < lumo_star, 0.85, shade)
    rust = fbm(TILE, seed + 9, 5, 6)
    rgb = tint((96, 92, 88), shade)
    rgb = rgb * (1 - 0.35 * (rust > 0.62)[..., None]) + np.array([0.33, 0.17, 0.08]) * 0.35 * (rust > 0.62)[..., None]
    return rgba(rgb, alpha)


def tile_puddle(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6)
    r = np.hypot((u - 0.5) * 0.85, v - 0.5) + (n - 0.5) * 0.30
    alpha = np.clip((0.34 - r) / 0.05, 0, 1)
    wet_rim = np.clip((0.42 - r) / 0.08, 0, 1) * (1 - alpha) * 0.45
    # Blue channel holds a "mirror" mask the shader turns into sky sheen.
    rgb = np.stack([0.20 + 0 * u, 0.24 + 0 * u, 0.30 + 0 * u], -1)
    return rgba(rgb, np.maximum(alpha * 0.92, wet_rim))


def tile_leaves(seed):
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)
    palette = [(196, 92, 34), (221, 150, 48), (150, 60, 30), (172, 160, 60), (120, 82, 40), (230, 186, 80)]
    for _ in range(110):
        cx, cy = rng.random(2) * TILE
        if math.hypot(cx - TILE / 2, cy - TILE / 2) > TILE * 0.47 * (0.6 + 0.4 * rng.random()):
            continue
        length = 10 + rng.random() * 14
        ang = rng.random() * math.tau
        w = length * 0.42
        pts = []
        for k in range(10):
            t = k / 9
            pts.append((cx + math.cos(ang) * (t - 0.5) * length - math.sin(ang) * math.sin(t * math.pi) * w,
                        cy + math.sin(ang) * (t - 0.5) * length + math.cos(ang) * math.sin(t * math.pi) * w))
        for k in range(9, -1, -1):
            t = k / 9
            pts.append((cx + math.cos(ang) * (t - 0.5) * length + math.sin(ang) * math.sin(t * math.pi) * w,
                        cy + math.sin(ang) * (t - 0.5) * length - math.cos(ang) * math.sin(t * math.pi) * w))
        col = palette[rng.integers(len(palette))]
        draw.polygon(pts, fill=col + (235,))
        draw.line([pts[0], pts[9]], fill=(70, 40, 20, 200), width=1)
    return np.asarray(img).astype(float) / 255.0


def tile_drift(seed, color, ripple):
    u, v = coords()
    n = fbm(TILE, seed, 6)
    edge = 0.62 + 0.18 * np.sin(u * 9.0 + n * 3.0) + (n - 0.5) * 0.2
    alpha = np.clip((v - (1 - edge)) / 0.30, 0, 1)
    alpha *= np.clip(np.minimum(u, 1 - u) / 0.15, 0, 1)
    ripples = 0.88 + ripple * np.sin(v * 80.0 + np.sin(u * 7.0) * 4.0 + n * 5.0)
    return rgba(tint(color, ripples * (0.9 + 0.12 * n)), alpha * 0.95)


def tile_crack(seed):
    img = Image.new("L", (TILE, TILE), 0)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)

    def branch(x, y, ang, length, width, depth):
        for _ in range(int(length / 6)):
            ang += (rng.random() - 0.5) * 0.9
            nx, ny = x + math.cos(ang) * 6, y + math.sin(ang) * 6
            draw.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            width *= 0.97
            if depth < 3 and rng.random() < 0.10:
                branch(x, y, ang + (rng.random() - 0.5) * 2.0, length * 0.45, width * 0.7, depth + 1)

    branch(TILE * 0.5, 8, math.pi / 2, TILE * 1.05, 3.2, 0)
    branch(TILE * 0.48, TILE * 0.35, math.pi * 0.15, TILE * 0.4, 2.0, 1)
    mask = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6))).astype(float) / 255.0
    halo = np.asarray(img.filter(ImageFilter.GaussianBlur(4))).astype(float) / 255.0
    rgb = tint((26, 22, 20), np.ones((TILE, TILE)))
    return rgba(rgb, np.clip(mask * 0.95 + halo * 0.35, 0, 1) * edge_fade(0.05))


def tile_streak(seed):
    u, v = coords()
    n = fbm(TILE, seed, 5)
    cols = value_noise(TILE, 24, seed + 4)[0][None, :]
    run = np.clip(cols * 1.6 - 0.45, 0, 1)
    length = 0.35 + 0.6 * value_noise(TILE, 12, seed + 7)[0][None, :]
    fade = np.clip(1 - v / length, 0, 1) ** 1.3
    alpha = run * fade * (0.6 + 0.4 * n) * np.clip(np.minimum(u, 1 - u) / 0.1, 0, 1)
    sill = np.clip(1 - v / 0.05, 0, 1) * 0.55
    return rgba(tint((52, 48, 40), 0.85 + 0.2 * n), np.clip(alpha * 0.75 + sill * edge_fade(0.06), 0, 1))


def tile_moss(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6, 6)
    fine = fbm(TILE, seed + 2, 4, 32)
    height = 0.28 + 0.30 * n
    alpha = np.clip(((v - (1 - height)) / 0.18), 0, 1) * (0.55 + 0.45 * fine)
    alpha *= np.clip(np.minimum(u, 1 - u) / 0.08, 0, 1)
    green = np.stack([0.22 + 0.15 * fine, 0.36 + 0.22 * fine, 0.10 + 0.06 * n], -1)
    return rgba(green, alpha)


def tile_grime(seed):
    n = fbm(TILE, seed, 6, 3)
    fine = fbm(TILE, seed + 1, 4, 24)
    alpha = np.clip((n - 0.42) * 2.4, 0, 1) * (0.6 + 0.4 * fine) * edge_fade(0.2)
    return rgba(tint((58, 50, 42), 0.8 + 0.3 * fine), alpha * 0.7)


def tile_rust(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6, 5)
    fine = fbm(TILE, seed + 3, 4, 40)
    spots = np.clip((n - 0.48) * 3.0, 0, 1)
    cols = value_noise(TILE, 20, seed + 8)[0][None, :]
    runs = np.clip(cols * 2.0 - 1.1, 0, 1) * np.clip(1.2 - v, 0, 1)
    alpha = np.clip(spots + runs * 0.7, 0, 1) * (0.55 + 0.45 * fine) * edge_fade(0.1)
    rgb = np.stack([0.42 + 0.2 * fine, 0.20 + 0.08 * fine, 0.07 + 0 * fine], -1)
    return rgba(rgb, alpha * 0.9)


def tile_plaster(seed):
    u, v = coords()
    n = fbm(TILE, seed, 6, 4)
    shape = np.clip((n - 0.50) * 9.0, 0, 1) * edge_fade(0.2)
    bricks_y = (v * 9.0) % 1.0
    row = np.floor(v * 9.0)
    bricks_x = (u * 4.5 + (row % 2) * 0.5) % 1.0
    mortar = (bricks_y < 0.12) | (bricks_x < 0.06)
    brick = np.where(mortar[..., None], np.array([0.62, 0.58, 0.52]), np.array([0.62, 0.30, 0.20]) * (0.85 + 0.25 * fbm(TILE, seed + 4, 3, 30))[..., None])
    rim = np.clip((n - 0.47) * 9.0, 0, 1) - shape
    rgb = np.where((rim > 0.05)[..., None], np.array([0.30, 0.28, 0.25]), brick)
    return rgba(rgb, np.clip(shape + np.clip(rim, 0, 1) * 0.8, 0, 1))


def tile_rubber(seed):
    u, v = coords()
    n = fbm(TILE, seed, 5, 6)
    lanes = sum(np.exp(-((u - c) / 0.07) ** 2) for c in (0.18, 0.42, 0.58, 0.82))
    alpha = np.clip(lanes, 0, 1) * (0.45 + 0.55 * n) * np.clip(np.minimum(v, 1 - v) / 0.3, 0, 1)
    return rgba(tint((18, 18, 20), np.ones((TILE, TILE))), alpha * 0.7)


def tile_tar(seed):
    img = Image.new("L", (TILE, TILE), 0)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)
    for k in range(3):
        x, y = rng.random() * TILE, 0.0
        pts = [(x, y)]
        while y < TILE:
            y += 10
            x += (rng.random() - 0.5) * 18
            pts.append((x, y))
        draw.line(pts, fill=255, width=7, joint="curve")
    mask = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255.0
    return rgba(tint((12, 12, 14), np.ones((TILE, TILE))), mask * 0.9 * edge_fade(0.06))


def wear_atlas() -> Image.Image:
    builders = {
        "skid": tile_skid, "oil": tile_oil, "patch": tile_patch, "manhole": tile_manhole,
        "puddle": tile_puddle, "leaves": tile_leaves,
        "sand": lambda s: tile_drift(s, (214, 188, 140), 0.035),
        "snow": lambda s: tile_drift(s, (246, 250, 255), 0.02),
        "crack": tile_crack, "streak": tile_streak, "moss": tile_moss, "grime": tile_grime,
        "rust": tile_rust, "plaster": tile_plaster, "rubber": tile_rubber, "tar": tile_tar,
    }
    atlas = np.zeros((TILE * 4, TILE * 4, 4))
    for index, name in enumerate(WEAR_TILES):
        tile = builders[name](101 + index * 13)
        # 4 px transparent gutter against mip bleeding between tiles.
        tile[:4, :, 3] = 0
        tile[-4:, :, 3] = 0
        tile[:, :4, 3] = 0
        tile[:, -4:, 3] = 0
        row, col = divmod(index, 4)
        atlas[row * TILE:(row + 1) * TILE, col * TILE:(col + 1) * TILE] = tile
    return Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8), "RGBA")


TRACK_NAMES = [
    "SONNENHAFEN", "ZAUBERWALD", "HIMMELSINSELN", "HOLO CITY", "KRISTALL-CANYON",
    "DSCHUNGEL-TEMPEL", "CANDY CLOUD", "VOLCANO NIGHT", "WINTER-SPRINT", "GALAXY RINGWAY",
    "DESERT DRIFT", "FUNKEL-LABOR", "DSCHUNGELHERZ",
]
# Lumo-Universum: frei erfundene Marken, keine echten Firmen.
BRANDS = [
    ("STERNENBRAUSE", "prickelt wie Sternschnuppen", (255, 201, 74), (40, 34, 92)),
    ("FUCHSFLITZER", "REIFEN", (255, 140, 60), (24, 30, 46)),
    ("KOMETEN-KAKAO", "warm & lecker", (255, 236, 210), (120, 62, 34)),
    ("WOLKENWERK", "Luftschiffe seit 1888", (60, 90, 150), (232, 244, 255)),
    ("GLÜHWURM", "Laternen & Licht", (190, 255, 120), (20, 52, 40)),
    ("NOVA NUDELN", "superschnell gekocht", (255, 255, 255), (220, 60, 90)),
    ("MILOS MUSCHELN", "Hafenimbiss", (30, 50, 70), (110, 230, 210)),
    ("FUNKELFUNK", "Radio für Rennfans", (255, 255, 255), (130, 90, 230)),
    ("BLITZBEERE", "Saft mit Turbo", (255, 240, 120), (150, 30, 90)),
    ("LUMO KART", "Grand Prix", (255, 210, 90), (18, 36, 70)),
    ("DREHWURM", "Kreisel & Karussells", (40, 40, 40), (255, 205, 60)),
    ("SCHNEEFLOCKE", "Mützen & Schals", (40, 80, 140), (240, 248, 255)),
    ("LAVALOLLI", "heiß und süß", (255, 230, 120), (190, 40, 20)),
    ("PIXELPOST", "Briefe in Lichtgeschwindigkeit", (255, 255, 255), (30, 150, 200)),
    ("RAKETENROLLER", "Bremsen? Klar doch!", (255, 255, 255), (230, 110, 30)),
    ("SANDSCHAUFEL", "Burgenbau AG", (90, 60, 30), (245, 220, 160)),
    ("ZAHLENZAUBER", "Rechnen macht Spaß", (255, 255, 255), (60, 170, 110)),
    ("MONDMILCH", "für Nachteulen", (40, 40, 90), (230, 230, 250)),
    ("START", "", (20, 20, 20), (255, 255, 255)),
]


def banner_atlas() -> Image.Image:
    w, h = 512, 64
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    big = ImageFont.truetype(str(FONT), 40)
    small = ImageFont.truetype(str(FONT), 15)
    cells = []
    for name in TRACK_NAMES:
        cells.append((name, "", (255, 255, 255), (18, 36, 70), True))
    for brand in BRANDS:
        cells.append(brand + (False,))
    for index, (title, sub, fg, bg, is_track) in enumerate(cells[:32]):
        col, row = divmod(index, 16)
        x0, y0 = col * w, row * h
        draw.rounded_rectangle([x0 + 2, y0 + 2, x0 + w - 3, y0 + h - 3], radius=10, fill=bg + (255,))
        accent = (255, 201, 74) if is_track else tuple(min(255, c + 40) for c in fg)
        draw.rounded_rectangle([x0 + 6, y0 + 6, x0 + w - 7, y0 + h - 7], radius=8, outline=accent + (255,), width=3)
        # Lumo-Stern als kleines Motiv links.
        cx, cy, rr = x0 + 34, y0 + h / 2, 18
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rad = rr if k % 2 == 0 else rr * 0.45
            pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
        draw.polygon(pts, fill=accent + (255,))
        font = big
        tw = draw.textlength(title, font=font)
        while tw > w - 90 - (draw.textlength(sub, font=small) + 12 if sub else 0) and font.size > 22:
            font = ImageFont.truetype(str(FONT), font.size - 2)
            tw = draw.textlength(title, font=font)
        sw = draw.textlength(sub, font=small) + 12 if sub else 0
        tx = x0 + 60 + (w - 70 - tw - sw) / 2
        draw.text((tx, y0 + h / 2), title, font=font, fill=fg + (255,), anchor="lm")
        if sub:
            draw.text((tx + tw + 12, y0 + h / 2 + 4), sub, font=small, fill=accent + (255,), anchor="lm")
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wear = wear_atlas()
    wear.save(OUT / "kart_detail_wear_atlas.png", optimize=True)
    banner_atlas().save(OUT / "kart_detail_banner_atlas.png", optimize=True)
    for path in sorted(OUT.glob("*.png")):
        print(f"{path.relative_to(ROOT)} {path.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
