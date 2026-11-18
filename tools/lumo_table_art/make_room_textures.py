#!/usr/bin/env python3
"""Eigene Texturen für Lumos Spielzimmer (Kartentisch, Memory, Vier gewinnt).

Rein prozedural mit numpy + Pillow: keine fremden Bilder, keine Fotos.
Ausgabe: assets/table_room/textures/*.webp (höchstens 1024 px, je < 1,5 MB).

Aufruf: python3 tools/lumo_table_art/make_room_textures.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "table_room" / "textures"
RNG = np.random.default_rng(20261118)


# ------------------------------------------------------------------ Rauschen


def tile_noise(size: int, cells: int, seed: int) -> np.ndarray:
    """Kachelbares Wertrauschen (bikubisch geglättet), Bereich 0..1."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells))
    img = Image.fromarray((grid * 255).astype(np.uint8))
    # Kachelbar: dreifach legen, groß skalieren, Mitte ausschneiden.
    big = Image.new("L", (cells * 3, cells * 3))
    for y in range(3):
        for x in range(3):
            big.paste(img, (x * cells, y * cells))
    big = big.resize((size * 3, size * 3), Image.BICUBIC)
    return np.asarray(big.crop((size, size, size * 2, size * 2)), dtype=np.float32) / 255.0


def fbm(size: int, base: int, octaves: int, seed: int) -> np.ndarray:
    total = np.zeros((size, size), np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += tile_noise(size, base * 2 ** o, seed + o * 17) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def to_img(rgb: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8))


def normal_from_height(h: np.ndarray, strength: float) -> Image.Image:
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return to_img(n * 0.5 + 0.5)


def save(img: Image.Image, name: str, quality: int = 88) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    img.save(path, "WEBP", quality=quality, method=6)
    print(f"{name}: {img.size[0]}x{img.size[1]} {path.stat().st_size // 1024} KB")


def hexrgb(value: str) -> np.ndarray:
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# --------------------------------------------------------------------- Holz


def wood(size: int, planks: int, seed: int, light: str, dark: str, knots: int) -> tuple[np.ndarray, np.ndarray]:
    """Dielenholz: Bretter längs U, Jahresringe, Äste, Fugen. Gibt (rgb, höhe)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    warp = fbm(size, 4, 4, seed) - 0.5
    fine = fbm(size, 32, 3, seed + 5)
    plank = np.floor(y * planks)
    offset = (np.sin(plank * 12.9898) * 43758.5453) % 1.0
    local_y = (y * planks) % 1.0
    # Jahresringe: lange, flache Bögen längs des Bretts, durch Rauschen verbogen.
    bend = np.sin(x * math.tau * (1 + (plank % 3)) + offset * 6.0) * 0.18 + warp * 0.9
    rings = np.sin((local_y * 2.6 + bend + offset * 9.0) * math.tau * 1.6)
    grain = (0.5 + 0.5 * rings) ** 3.0
    # Feine Längsfasern: Rauschen stark in U-Richtung gestreckt.
    fibres = np.random.default_rng(seed + 9).random((size, 24)).astype(np.float32)
    streak = np.asarray(Image.fromarray((fibres * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), np.float32).T / 255.0
    tone = 0.42 * grain + 0.18 * fine + 0.4 * streak.T
    # Äste: dunkle Ellipsen mit Ringen.
    rng = np.random.default_rng(seed + 3)
    for _ in range(knots):
        cx, cy = rng.random(2)
        rx = 0.018 + rng.random() * 0.02
        ry = rx * 0.55
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt(((x - cx - ox) / rx) ** 2 + ((y - cy - oy) / ry) ** 2)
                knot = np.exp(-d * d * 1.4)
                tone = tone * (1.0 - 0.55 * knot) + 0.12 * knot * (0.5 + 0.5 * np.sin(d * 9.0))
    a, b = hexrgb(light), hexrgb(dark)
    rgb = b[None, None, :] + (a - b)[None, None, :] * tone[..., None]
    # Jedes Brett leicht anders getönt.
    rgb *= (0.9 + 0.18 * offset)[..., None]
    # Fugen zwischen den Brettern.
    seam = np.minimum(local_y, 1.0 - local_y) * planks * size
    gap = np.clip(seam / 2.2, 0.0, 1.0)
    rgb *= (0.45 + 0.55 * gap)[..., None]
    height = tone * 0.6 + gap * 0.8
    return rgb, height


# ------------------------------------------------------------------- Textil


def felt(size: int) -> Image.Image:
    """Filzplatte: vorhandenes Sternenkreis-Motiv mit Faserstruktur und Gebrauchsspuren."""
    src = Image.open(ROOT / "assets/cards_table/table/table_top.webp").convert("RGB").resize((size, size), Image.LANCZOS)
    base = np.asarray(src, np.float32) / 255.0
    fibre = fbm(size, 128, 3, 41)
    fuzz = tile_noise(size, 256, 43)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) * 2.0
    # Abgegriffener Ring dort, wo Hände und Karten über den Filz rutschen.
    worn = np.exp(-((r - 0.78) / 0.09) ** 2) * (0.6 + 0.4 * fbm(size, 6, 3, 47))
    # Ein paar flaue Flecken (Kakao, Krümel), ganz leicht.
    spots = np.zeros_like(r)
    rng = np.random.default_rng(51)
    for _ in range(7):
        cx, cy = rng.random(2) * 0.7 + 0.15
        rad = 0.02 + rng.random() * 0.035
        spots += np.exp(-(((x - cx) ** 2 + (y - cy) ** 2) / rad ** 2)) * (0.4 + 0.6 * rng.random())
    rgb = base * (0.86 + 0.2 * fibre[..., None] + 0.06 * fuzz[..., None])
    rgb = rgb + worn[..., None] * np.array([0.05, 0.06, 0.09]) * (0.6 + fibre[..., None])
    rgb = rgb * (1.0 - 0.10 * np.clip(spots, 0, 1)[..., None])
    # Rand dunkler (Schatten der Holzkante) und dezente Vignette.
    rgb *= (1.0 - 0.32 * np.clip((r - 0.86) / 0.14, 0, 1) ** 1.5)[..., None]
    return to_img(rgb)


def rug(size: int) -> Image.Image:
    """Runder Flechtteppich: Ringe in Lumo-Farben mit geflochtener Struktur."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    dx, dy = x - 0.5, y - 0.5
    r = np.sqrt(dx * dx + dy * dy) * 2.0
    a = np.arctan2(dy, dx)
    palette = [hexrgb(c) for c in ("2b3a7a", "c9873e", "2b3a7a", "39798f", "e2b65c", "2b3a7a", "7a4f9a", "2b3a7a", "c9873e", "1f2c62")]
    band = np.clip((r * 13.0).astype(int), 0, len(palette) - 1)
    rgb = np.zeros((size, size, 3), np.float32)
    for i, colour in enumerate(palette):
        rgb[band == i] = colour
    # Flechtmuster: schräge Wülste je Ring.
    braid = 0.5 + 0.5 * np.sin(a * 140.0 + (r * 13.0 % 1.0) * 6.0 * np.where(band % 2 == 0, 1, -1))
    within = (r * 13.0) % 1.0
    bulge = np.sin(within * math.pi)
    shade = 0.62 + 0.3 * bulge * (0.7 + 0.3 * braid)
    fibre = fbm(size, 96, 2, 61)
    rgb *= (shade * (0.9 + 0.2 * fibre))[..., None]
    alpha = np.clip((1.0 - r) * size * 0.25, 0, 1)
    out = np.concatenate([rgb, alpha[..., None]], -1)
    return Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGBA")


def wallpaper(size: int) -> tuple[np.ndarray, np.ndarray]:
    """Senkrechte Wandbretter mit Nägeln (Baumhaus)."""
    rgb, h = wood(size, 6, 77, "b88a63", "6f4a33", 5)
    rgb = np.transpose(rgb, (1, 0, 2)).copy()
    h = h.T.copy()
    # Nagelköpfe oben und unten an jedem Brett.
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    for col in range(6):
        cx = (col + 0.5) / 6.0
        for cy in (0.08, 0.92):
            d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) * size
            nail = np.clip(1.0 - d / 4.0, 0, 1)
            rgb = rgb * (1.0 - nail[..., None] * 0.6) + nail[..., None] * np.array([0.32, 0.3, 0.3]) * 0.6
            h = h + nail * 0.6
    return rgb, h


def chalkboard(size: int) -> Image.Image:
    """Tafelgrund mit Kreidewischern – Namen und Punkte schreibt das Spiel darauf."""
    base = hexrgb("23392f")
    smear = fbm(size, 6, 5, 91)
    wipe = fbm(size, 3, 3, 93)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    arcs = 0.5 + 0.5 * np.sin((x * 3.0 + wipe * 2.0) * math.tau * 2.0 + y * 3.0)
    rgb = base[None, None, :] * (0.8 + 0.35 * smear[..., None]) + 0.06 * (arcs * smear)[..., None]
    img = to_img(rgb)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(97)
    # Ein kleiner Stern und Kreidestriche als Kritzelei in der Ecke.
    for _ in range(9):
        x0, y0 = rng.random(2) * size
        draw.line([(x0, y0), (x0 + rng.random() * 30 - 15, y0 + rng.random() * 10)], fill=(150, 170, 160), width=1)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def clock_face(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), (243, 231, 205))
    arr = np.asarray(img, np.float32) / 255.0
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) * 2.0
    arr = arr * (1.0 - 0.18 * r[..., None] ** 2) * (0.94 + 0.08 * fbm(size, 16, 3, 101)[..., None])
    img = to_img(arr)
    draw = ImageDraw.Draw(img)
    c = size / 2
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
    font = ImageFont.truetype(font_path, int(size * 0.1)) if Path(font_path).exists() else ImageFont.load_default()
    for i in range(60):
        ang = math.radians(i * 6 - 90)
        outer = size * 0.46
        inner = size * (0.40 if i % 5 == 0 else 0.43)
        draw.line([(c + math.cos(ang) * inner, c + math.sin(ang) * inner), (c + math.cos(ang) * outer, c + math.sin(ang) * outer)],
                  fill=(60, 44, 34), width=4 if i % 5 == 0 else 2)
    for hour in range(1, 13):
        ang = math.radians(hour * 30 - 90)
        tx, ty = c + math.cos(ang) * size * 0.33, c + math.sin(ang) * size * 0.33
        draw.text((tx, ty), str(hour), fill=(70, 50, 40), font=font, anchor="mm")
    # Kleiner Stern unter der 12, Lumo-Motiv.
    pts = []
    for k in range(10):
        rr = size * (0.05 if k % 2 == 0 else 0.022)
        ang = math.radians(k * 36 - 90)
        pts.append((c + math.cos(ang) * rr, c - size * 0.15 + math.sin(ang) * rr))
    draw.polygon(pts, fill=(226, 160, 52))
    draw.ellipse([c - size * 0.47, c - size * 0.47, c + size * 0.47, c + size * 0.47], outline=(120, 90, 60), width=3)
    return img


def book_spines(size: int) -> Image.Image:
    """Graustufen-Buchrücken: Bünde, Titelfeld, Goldlinien. Farbe kommt aus der Vertexfarbe."""
    w = size
    img = Image.new("RGB", (w, w), (235, 235, 235))
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(111)
    cols = 8
    cw = w // cols
    for i in range(cols):
        x0 = i * cw
        style = i % 4
        for b in (0.1, 0.16, 0.84, 0.9):
            draw.rectangle([x0, int(b * w) - 3, x0 + cw, int(b * w) + 3], fill=(255, 226, 150) if style != 2 else (90, 90, 90))
        if style in (0, 3):
            draw.rectangle([x0 + cw * 0.18, w * 0.35, x0 + cw * 0.82, w * 0.62], fill=(250, 240, 210))
            for k in range(4):
                yy = w * (0.39 + 0.05 * k)
                draw.line([(x0 + cw * 0.28, yy), (x0 + cw * (0.5 + rng.random() * 0.25), yy)], fill=(80, 70, 60), width=3)
        elif style == 1:
            draw.ellipse([x0 + cw * 0.25, w * 0.45, x0 + cw * 0.75, w * 0.45 + cw * 0.5], fill=(255, 220, 120))
        draw.line([(x0, 0), (x0, w)], fill=(120, 120, 120), width=2)
    arr = np.asarray(img, np.float32) / 255.0
    arr *= (0.85 + 0.25 * fbm(w, 32, 3, 113))[..., None]
    # Rundung der Rücken: Mitte heller.
    xx = (np.arange(w) % cw) / cw
    arr *= (0.75 + 0.3 * np.sin(xx * math.pi))[None, :, None]
    return to_img(arr)


def card_shadow(size: int) -> Image.Image:
    """Weicher Kontaktschatten unter Karten (Alpha)."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    dx = np.clip(np.abs(x - 0.5) * 2.0 - 0.62, 0, 1) / 0.38
    dy = np.clip(np.abs(y - 0.5) * 2.0 - 0.7, 0, 1) / 0.3
    d = np.sqrt(dx * dx + dy * dy)
    alpha = np.clip(1.0 - d, 0, 1) ** 1.8
    out = np.zeros((size, size, 4), np.float32)
    out[..., 3] = alpha
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def main() -> None:
    oak, oak_h = wood(1024, 5, 7, "d39a62", "7a4a2a", 4)
    save(to_img(oak), "oak_albedo.webp")
    save(normal_from_height(oak_h, 3.0), "oak_normal.webp", 82)
    dark, _ = wood(512, 4, 13, "8a5a3a", "3e261a", 3)
    save(to_img(dark), "walnut_albedo.webp")
    wall, wall_h = wallpaper(1024)
    save(to_img(wall), "wall_planks_albedo.webp")
    save(normal_from_height(wall_h, 2.4), "wall_planks_normal.webp", 82)
    floor, floor_h = wood(1024, 8, 29, "c0875a", "6a3f26", 6)
    save(to_img(floor), "floor_albedo.webp")
    save(normal_from_height(floor_h, 2.0), "floor_normal.webp", 82)
    save(felt(1024), "felt_worn.webp")
    save(rug(1024), "rug_braided.webp")
    save(chalkboard(512), "chalkboard.webp")
    save(clock_face(512), "clock_face.webp")
    save(book_spines(512), "book_spines.webp")
    save(card_shadow(128), "card_shadow.webp", 90)


if __name__ == "__main__":
    main()
