#!/usr/bin/env python3
"""Draw the LUMO Dorfwelt HUD art: resource icons and soft glass/wood panels.

Eigenbau with PIL (4x supersampled shapes, gradients, outlines). No fonts,
photos or downloaded art. Output: assets/creative/village3d/ui/*.png
Run: /home/user/tools/bpyenv/bin/python tools/lumo_village_art/make_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/creative/village3d/ui"
S = 4  # supersampling
SIZE = 128


def canvas(size=SIZE):
    return Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))


def finish(img, size=SIZE, shadow=True):
    small = img.resize((size, size), Image.LANCZOS)
    if not shadow:
        return small
    alpha = small.split()[3]
    sh = Image.new("RGBA", small.size, (10, 25, 35, 0))
    sh.putalpha(alpha.point(lambda a: int(a * 0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    base = Image.new("RGBA", small.size, (0, 0, 0, 0))
    base.alpha_composite(sh, (2, 4))
    base.alpha_composite(small)
    return base


def p(v):
    return v * S


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color[:3]) + (255,)


def ellipse(d, box, fill, outline=(40, 30, 25, 255), width=5):
    d.ellipse([p(b) for b in box], fill=fill, outline=outline, width=p(width) // 4 * 4 // 4 * S if False else width * S // 2)


def poly(d, pts, fill, outline=(40, 30, 25, 255), width=5):
    d.polygon([(p(x), p(y)) for x, y in pts], fill=fill, outline=outline, width=width * S // 2)


def icon_wood():
    img = canvas()
    d = ImageDraw.Draw(img)
    for i, (y, x0) in enumerate([(72, 16), (46, 30)]):
        d.rounded_rectangle([p(x0), p(y), p(x0 + 74), p(y + 30)], radius=p(10), fill=(166, 104, 58, 255),
                            outline=(70, 40, 20, 255), width=S * 3)
        d.line([p(x0 + 8), p(y + 9), p(x0 + 60), p(y + 9)], fill=(196, 134, 80, 255), width=S * 3)
        d.ellipse([p(x0 + 62), p(y), p(x0 + 92), p(y + 30)], fill=(232, 190, 128, 255), outline=(70, 40, 20, 255), width=S * 3)
        for r in (10, 5):
            d.ellipse([p(x0 + 77 - r), p(y + 15 - r), p(x0 + 77 + r), p(y + 15 + r)], outline=(180, 120, 70, 255), width=S * 2)
    return finish(img)


def icon_stone():
    img = canvas()
    d = ImageDraw.Draw(img)
    poly(d, [(18, 86), (30, 52), (62, 38), (96, 50), (110, 84), (84, 104), (40, 104)], (176, 186, 196, 255), width=6)
    poly(d, [(30, 52), (62, 38), (70, 64), (40, 72)], (214, 222, 230, 255), width=3)
    poly(d, [(70, 64), (96, 50), (110, 84), (84, 88)], (150, 160, 172, 255), width=3)
    return finish(img)


def icon_food():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([p(22), p(30), p(106), p(110)], fill=(224, 72, 58, 255), outline=(90, 20, 20, 255), width=S * 3)
    d.ellipse([p(36), p(42), p(60), p(66)], fill=(255, 150, 130, 255))
    d.line([p(64), p(34), p(70), p(14)], fill=(90, 60, 30, 255), width=S * 5)
    poly(d, [(70, 22), (98, 12), (90, 34)], (108, 176, 64, 255), width=3)
    return finish(img)


def icon_coins():
    img = canvas()
    d = ImageDraw.Draw(img)
    for i, (x, y) in enumerate([(14, 58), (46, 26)]):
        d.ellipse([p(x), p(y), p(x + 66), p(y + 66)], fill=(244, 196, 58, 255), outline=(140, 90, 10, 255), width=S * 3)
        d.ellipse([p(x + 12), p(y + 12), p(x + 54), p(y + 54)], outline=(196, 140, 30, 255), width=S * 3)
        d.text((p(x + 24), p(y + 14)), "", fill=(0, 0, 0, 255))
        d.rectangle([p(x + 30), p(y + 20), p(x + 36), p(y + 46)], fill=(196, 140, 30, 255))
    return finish(img)


def icon_people():
    img = canvas()
    d = ImageDraw.Draw(img)
    for x, col, s in [(26, (120, 196, 255, 255), 0.85), (60, (255, 176, 112, 255), 1.0)]:
        d.ellipse([p(x + 4), p(26 / s), p(x + 40), p(26 / s + 36)], fill=(255, 222, 186, 255), outline=(60, 40, 30, 255), width=S * 3)
        d.rounded_rectangle([p(x - 4), p(66), p(x + 48), p(112)], radius=p(18), fill=col, outline=(40, 50, 70, 255), width=S * 3)
    return finish(img)


def icon_plots():
    img = canvas()
    d = ImageDraw.Draw(img)
    poly(d, [(64, 22), (114, 52), (64, 84), (14, 52)], (126, 196, 96, 255), width=5)
    poly(d, [(14, 52), (64, 84), (64, 104), (14, 72)], (96, 150, 70, 255), width=4)
    poly(d, [(64, 84), (114, 52), (114, 72), (64, 104)], (80, 130, 60, 255), width=4)
    for x, y in [(64, 30), (104, 52), (64, 76), (24, 52)]:
        d.rectangle([p(x - 3), p(y - 16), p(x + 3), p(y)], fill=(150, 100, 60, 255))
    return finish(img)


def icon_day():
    img = canvas()
    d = ImageDraw.Draw(img)
    for i in range(10):
        a = i / 10 * math.tau
        d.line([p(64 + math.cos(a) * 34), p(64 + math.sin(a) * 34), p(64 + math.cos(a) * 54), p(64 + math.sin(a) * 54)],
               fill=(255, 196, 60, 255), width=S * 7)
    d.ellipse([p(34), p(34), p(94), p(94)], fill=(255, 220, 90, 255), outline=(200, 130, 20, 255), width=S * 3)
    return finish(img)


def icon_treasury():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([p(16), p(52), p(112), p(108)], radius=p(8), fill=(150, 92, 46, 255), outline=(60, 36, 16, 255), width=S * 3)
    d.pieslice([p(16), p(22), p(112), p(84)], 180, 360, fill=(182, 118, 60, 255), outline=(60, 36, 16, 255), width=S * 3)
    d.rectangle([p(16), p(50), p(112), p(58)], fill=(230, 180, 60, 255))
    d.rounded_rectangle([p(54), p(56), p(74), p(78)], radius=p(4), fill=(250, 210, 80, 255), outline=(120, 80, 10, 255), width=S * 2)
    return finish(img)


def icon_happy():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([p(14), p(28), p(66), p(80)], fill=(255, 120, 150, 255))
    d.ellipse([p(62), p(28), p(114), p(80)], fill=(255, 120, 150, 255))
    poly(d, [(18, 64), (110, 64), (64, 112)], (255, 120, 150, 255), outline=None, width=0)
    d.ellipse([p(28), p(38), p(48), p(56)], fill=(255, 200, 214, 255))
    return finish(img)


def icon_water():
    img = canvas()
    d = ImageDraw.Draw(img)
    poly(d, [(64, 12), (100, 70), (64, 114), (28, 70)], (90, 190, 255, 255), outline=None, width=0)
    d.ellipse([p(28), p(46), p(100), p(116)], fill=(90, 190, 255, 255), outline=(20, 90, 150, 255), width=S * 3)
    d.ellipse([p(44), p(62), p(60), p(86)], fill=(200, 236, 255, 255))
    return finish(img)


def icon_grain():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.line([p(64), p(116), p(64), p(30)], fill=(150, 120, 40, 255), width=S * 5)
    for i in range(5):
        y = 34 + i * 15
        for s in (-1, 1):
            d.ellipse([p(64 + s * 6 - 9), p(y - 7), p(64 + s * 6 + 9), p(y + 9)], fill=(240, 200, 90, 255), outline=(150, 110, 30, 255), width=S * 2)
    return finish(img)


def panel(fill_top, fill_bottom, border, size=96, radius=26, border_w=3, inner=None, alpha=255):
    img = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (1, size * S))
    for y in range(size * S):
        t = y / (size * S - 1)
        c = tuple(int(fill_top[i] * (1 - t) + fill_bottom[i] * t) for i in range(3)) + (alpha,)
        grad.putpixel((0, y), c)
    grad = grad.resize((size * S, size * S))
    mask = Image.new("L", (size * S, size * S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * S - 1, size * S - 1], radius=radius * S, fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    if inner:
        # Blend the soft top highlight over the fill (never replace its alpha).
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle([S * 4, S * 3, size * S - S * 4, size * S // 2], radius=(radius - 4) * S, fill=inner)
        img.alpha_composite(glow)
        d = ImageDraw.Draw(img)
    d.rounded_rectangle([S, S, size * S - S, size * S - S], radius=radius * S, outline=border, width=border_w * S)
    return img.resize((size, size), Image.LANCZOS)


def wood_panel(size=96):
    img = panel((176, 120, 74), (128, 82, 46), (74, 44, 22, 255), size=size, radius=22, border_w=4)
    d = ImageDraw.Draw(img)
    for y in range(12, size - 8, 14):
        d.line([8, y, size - 8, y], fill=(110, 70, 38, 120), width=1)
    d.rounded_rectangle([5, 5, size - 6, size - 6], radius=18, outline=(232, 190, 120, 160), width=1)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {
        "res_wood": icon_wood, "res_stone": icon_stone, "res_food": icon_food, "res_coins": icon_coins,
        "res_people": icon_people, "res_plots": icon_plots, "res_day": icon_day, "res_treasury": icon_treasury,
        "res_happy": icon_happy, "res_water": icon_water, "res_grain": icon_grain,
    }
    for name, func in icons.items():
        func().save(OUT / f"{name}.png", optimize=True)
    panel((26, 58, 78), (12, 34, 50), (120, 214, 220, 210), inner=(255, 255, 255, 18), alpha=226).save(OUT / "panel_glass.png", optimize=True)
    panel((255, 250, 236), (240, 226, 196), (196, 160, 104, 255), inner=(255, 255, 255, 70)).save(OUT / "panel_parchment.png", optimize=True)
    wood_panel().save(OUT / "panel_wood.png", optimize=True)
    panel((40, 76, 98), (18, 44, 62), (255, 214, 120, 230), radius=30, inner=(255, 255, 255, 22), alpha=236).save(OUT / "panel_chip.png", optimize=True)
    print("ui art:", len(icons) + 4)


if __name__ == "__main__":
    main()
