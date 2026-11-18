#!/usr/bin/env python3
"""Lumo Kart: selbst gezeichnete Nahdetail-Texturen für die Fahrzeuge.

  kart_sticker_atlas.png   512 x 512, 4 x 4 Fantasie-Aufkleber (keine echten Marken):
                           Fuchs-Stern, Sternkraft, Funkelöl, Mondreifen, Lumo-Team, ...
  kart_flake_normal.png    256 x 256 kachelbare Normal-Map für Metallic-Flakes im Klarlack
  kart_dust_film.png        64 x 256 senkrechter Staubverlauf (unten dicht, oben frei)

Alles mit PIL/numpy gezeichnet, fester Zufallssamen: gleiche Eingabe, gleiche Dateien.
Aufruf (Repo-Wurzel): python3 tools/art/make_kart_detail_textures.py
"""
from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets/kart/production/details"
FONT = REPO / "assets/fonts/Nunito-Black.ttf"
CELL = 128
SS = 4  # Überabtastung beim Zeichnen

# id, Grundfarbe, Schriftfarbe, Text, Symbol. Reihenfolge = Atlas-Zelle (Zeile für Zeile).
STICKERS = [
    ("fuchsstern", "ff8a2c", "ffffff", "LUMO", "fox"),
    ("sternkraft", "1d3d8f", "ffd23f", "STERNKRAFT", "star"),
    ("funkeloel", "17a68a", "ffffff", "FUNKELÖL", "drop"),
    ("mondreifen", "2b2f4a", "dfe9ff", "MONDREIFEN", "moon"),
    ("lerncrew", "ffd23f", "1d2a5a", "LERN-CREW", "book"),
    ("blitzbox", "7a3cff", "ffffff", "BLITZBOX", "bolt"),
    ("wolkenwerk", "e8f4ff", "1d5fb8", "WOLKENWERK", "cloud"),
    ("kometen", "ff4f6d", "ffffff", "KOMETEN-CLUB", "comet"),
    ("zahlenzauber", "31c4ff", "0b1d3a", "1+1=2", "none"),
    ("igelgrip", "6b4a2c", "ffe0a8", "IGEL-GRIP", "dots"),
    ("polarlicht", "0e2a3a", "8affd8", "POLARLICHT", "wave"),
    ("sonnenhafen", "ffb347", "5a2600", "SONNENHAFEN", "sun"),
    ("checker", "ffffff", "111111", "", "checker"),
    ("pfotenpower", "c58cff", "ffffff", "PFOTEN", "paw"),
    ("turbotee", "3fd0c0", "06302a", "TURBO-TEE", "cup"),
    ("lumostripe", "0f2450", "2fd0ff", "LUMO", "stripe"),
]


def hexc(value, alpha=255):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def fit_font(draw, text, width, height):
    size = int(height)
    while size > 6:
        font = ImageFont.truetype(str(FONT), size)
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= width and box[3] - box[1] <= height:
            return font, box
        size -= 2
    font = ImageFont.truetype(str(FONT), 6)
    return font, draw.textbbox((0, 0), text, font=font)


def symbol(draw, kind, cx, cy, r, ink, base):
    if kind == "fox":
        draw.polygon([(cx - r, cy + r * .2), (cx - r * .55, cy - r), (cx - r * .15, cy - r * .2),
                      (cx + r * .15, cy - r * .2), (cx + r * .55, cy - r), (cx + r, cy + r * .2),
                      (cx, cy + r)], fill=ink)
        draw.polygon([(cx - r * .55, cy + r * .1), (cx, cy + r * .7), (cx + r * .55, cy + r * .1), (cx, cy + r * .3)], fill=base)
    elif kind in ("star", "comet"):
        pts = []
        for i in range(10):
            rr = r if i % 2 == 0 else r * .45
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        if kind == "comet":
            for k in range(3):
                draw.line([(cx - r * .3, cy + (k - 1) * r * .35), (cx - r * 1.25, cy + (k - 1) * r * .5)], fill=ink, width=int(r * .22))
        draw.polygon(pts, fill=ink)
    elif kind == "drop":
        draw.ellipse([cx - r * .7, cy - r * .1, cx + r * .7, cy + r * 1.0], fill=ink)
        draw.polygon([(cx - r * .62, cy + r * .2), (cx, cy - r), (cx + r * .62, cy + r * .2)], fill=ink)
        draw.ellipse([cx - r * .35, cy + r * .25, cx - r * .05, cy + r * .55], fill=base)
    elif kind == "moon":
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ink)
        draw.ellipse([cx - r * .45, cy - r * 1.05, cx + r * 1.3, cy + r * .75], fill=base)
    elif kind == "book":
        draw.polygon([(cx - r, cy - r * .6), (cx, cy - r * .35), (cx, cy + r * .8), (cx - r, cy + r * .55)], fill=ink)
        draw.polygon([(cx + r, cy - r * .6), (cx, cy - r * .35), (cx, cy + r * .8), (cx + r, cy + r * .55)], fill=ink)
    elif kind == "bolt":
        draw.polygon([(cx + r * .2, cy - r), (cx - r * .6, cy + r * .15), (cx - r * .05, cy + r * .15),
                      (cx - r * .25, cy + r), (cx + r * .6, cy - r * .2), (cx + r * .05, cy - r * .2)], fill=ink)
    elif kind == "cloud":
        for dx, dy, rr in ((-.5, .15, .45), (0, -.2, .6), (.5, .15, .45)):
            draw.ellipse([cx + dx * r - rr * r, cy + dy * r - rr * r, cx + dx * r + rr * r, cy + dy * r + rr * r], fill=ink)
    elif kind == "dots":
        for k in range(7):
            a = k * math.tau / 7
            draw.ellipse([cx + math.cos(a) * r * .7 - r * .2, cy + math.sin(a) * r * .7 - r * .2,
                          cx + math.cos(a) * r * .7 + r * .2, cy + math.sin(a) * r * .7 + r * .2], fill=ink)
    elif kind == "wave":
        for k in range(3):
            pts = [(cx - r + j * r / 6, cy + (k - 1) * r * .5 + math.sin(j * .9 + k) * r * .2) for j in range(13)]
            draw.line(pts, fill=ink, width=int(r * .2), joint="curve")
    elif kind == "sun":
        draw.ellipse([cx - r * .5, cy - r * .5, cx + r * .5, cy + r * .5], fill=ink)
        for k in range(10):
            a = k * math.tau / 10
            draw.line([(cx + math.cos(a) * r * .65, cy + math.sin(a) * r * .65), (cx + math.cos(a) * r, cy + math.sin(a) * r)], fill=ink, width=int(r * .16))
    elif kind == "paw":
        draw.ellipse([cx - r * .55, cy - r * .05, cx + r * .55, cy + r * .85], fill=ink)
        for dx, dy in ((-.7, -.35), (-.25, -.8), (.25, -.8), (.7, -.35)):
            draw.ellipse([cx + dx * r - r * .22, cy + dy * r - r * .26, cx + dx * r + r * .22, cy + dy * r + r * .26], fill=ink)
    elif kind == "cup":
        draw.rectangle([cx - r * .6, cy - r * .5, cx + r * .4, cy + r * .7], fill=ink)
        draw.ellipse([cx + r * .2, cy - r * .3, cx + r * .9, cy + r * .4], outline=ink, width=int(r * .18))
    elif kind == "stripe":
        for k in range(3):
            x = cx - r + k * r * .7
            draw.polygon([(x, cy + r), (x + r * .35, cy + r), (x + r * .85, cy - r), (x + r * .5, cy - r)], fill=ink)


def sticker(spec):
    _id, base_hex, ink_hex, text, kind = spec
    size = CELL * SS
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    base, ink = hexc(base_hex), hexc(ink_hex)
    pad = 6 * SS
    if kind == "checker":
        n = 6
        step = (size - 2 * pad) / n
        for i in range(n):
            for j in range(n):
                colour = base if (i + j) % 2 == 0 else ink
                draw.rectangle([pad + i * step, pad + j * step, pad + (i + 1) * step, pad + (j + 1) * step], fill=colour)
    else:
        # Weißer Stanzrand wie bei echten Vinyl-Aufklebern, darin die Grundform.
        rad = 30 * SS
        draw.rounded_rectangle([pad, pad + 16 * SS, size - pad, size - pad - 16 * SS], rad, fill=(255, 255, 255, 255))
        inner = [pad + 5 * SS, pad + 21 * SS, size - pad - 5 * SS, size - pad - 21 * SS]
        draw.rounded_rectangle(inner, rad - 5 * SS, fill=base)
        if kind != "none":
            symbol(draw, kind, size * .27 if text else size * .5, size * .5, 20 * SS, ink, base)
        if text:
            left = size * (.46 if kind != "none" else .14)
            font, box = fit_font(draw, text, size - left - pad - 10 * SS, 40 * SS)
            h = box[3] - box[1]
            draw.text((left - box[0], size * .5 - h * .5 - box[1]), text, font=font, fill=ink)
    return im.resize((CELL, CELL), Image.LANCZOS)


def sticker_atlas():
    atlas = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for index, spec in enumerate(STICKERS):
        atlas.alpha_composite(sticker(spec), ((index % 4) * CELL, (index // 4) * CELL))
    return atlas


def flake_normal(size=256, flakes=2600, seed=7):
    """Kleine, zufällig gekippte Plättchen; Rand kachelt (Wrap beim Zeichnen)."""
    rng = np.random.default_rng(seed)
    nx = np.zeros((size, size), np.float32)
    ny = np.zeros((size, size), np.float32)
    for _ in range(flakes):
        x, y = rng.integers(0, size, 2)
        r = rng.integers(1, 3)
        tx, ty = rng.normal(0, .35, 2)
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    nx[(y + dy) % size, (x + dx) % size] = tx
                    ny[(y + dy) % size, (x + dx) % size] = ty
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, .05, 1))
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=2) * .5 + .5
    return Image.fromarray((rgb * 255 + .5).astype(np.uint8), "RGB")


def dust_film(w=64, h=256, seed=11):
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h)[:, None]  # 0 = unten
    density = np.clip(1.0 - v * 1.25, 0, 1) ** 1.6
    noise = rng.random((h, w)).astype(np.float32)
    noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.4))) / 255.0
    alpha = np.clip(density * (.55 + .7 * noise) * .85, 0, 1)
    rgb = np.zeros((h, w, 3), np.float32)
    rgb[...] = np.array([.42, .36, .29])
    out = np.concatenate([rgb, alpha[..., None]], axis=2)[::-1]  # Bildzeile 0 = oben
    return Image.fromarray((out * 255 + .5).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sticker_atlas().save(OUT / "kart_sticker_atlas.png", optimize=True)
    flake_normal().save(OUT / "kart_flake_normal.png", optimize=True)
    dust_film().save(OUT / "kart_dust_film.png", optimize=True)
    total = sum(p.stat().st_size for p in OUT.glob("*.png"))
    print(f"[kart-details] {len(list(OUT.glob('*.png')))} Dateien, {total // 1024} KB")


if __name__ == "__main__":
    main()
