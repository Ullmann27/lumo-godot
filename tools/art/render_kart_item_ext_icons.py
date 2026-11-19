#!/usr/bin/env python3
"""HUD icons of the extended Lumo-Kart items (original artwork, drawn from code).

Each icon is a bold silhouette with a dark ink outline (readable at 30-80 px on bright and
dark tracks), a soft inner gradient and a highlight, in the colour of its kart_items.json row.
Drawn at 4x and downsampled for clean edges. Writes assets/kart/hud/items/icon_<id>.webp
(256 px, transparent). Run: python3 tools/art/render_kart_item_ext_icons.py [out_dir]
"""
from pathlib import Path
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/kart/hud/items"
S = 1024
INK = (7, 20, 40, 255)


def rgba(hex_value, alpha=255):
    hex_value = hex_value.lstrip("#")
    return tuple(int(hex_value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def star_points(cx, cy, outer, inner, rotation=-math.pi / 2, count=5):
    points = []
    for k in range(count * 2):
        r = outer if k % 2 == 0 else inner
        a = rotation + k * math.pi / count
        points.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return points


def vertical_gradient(mask, top, bottom):
    """Fill `mask` (L image) with a top->bottom gradient."""
    grad = Image.new("RGBA", (S, S))
    draw = ImageDraw.Draw(grad)
    box = mask.getbbox() or (0, 0, S, S)
    for y in range(S):
        t = min(1.0, max(0.0, (y - box[1]) / max(1, box[3] - box[1])))
        draw.line([(0, y), (S, y)], fill=mix(top, bottom, t))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.paste(grad, (0, 0), mask)
    return layer


def radial_gradient(mask, centre, radius, inner, outer):
    grad = Image.new("RGBA", (S, S))
    px = grad.load()
    cx, cy = centre
    box = mask.getbbox() or (0, 0, S, S)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2], 2):
            t = min(1.0, math.hypot(x - cx, y - cy) / radius)
            c = mix(inner, outer, t)
            px[x, y] = c
            if x + 1 < S:
                px[x + 1, y] = c
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.paste(grad, (0, 0), mask)
    return layer


def shape_mask(draw_fn):
    mask = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(mask))
    return mask


def outline(mask, width):
    return mask.filter(ImageFilter.MaxFilter(width | 1))


def compose(layers_and_masks, ink_width=49, glow=None):
    """Ink outline under the union of all masks, then the coloured layers on top."""
    union = Image.new("L", (S, S), 0)
    for _layer, mask in layers_and_masks:
        union = ImageChops.lighter(union, mask)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if glow:
        halo = outline(union, 121).filter(ImageFilter.GaussianBlur(40))
        glow_layer = Image.new("RGBA", (S, S), glow)
        glow_layer.putalpha(halo.point(lambda v: int(v * 0.55)))
        canvas.alpha_composite(glow_layer)
    ink = Image.new("RGBA", (S, S), INK)
    ink.putalpha(outline(union, ink_width))
    canvas.alpha_composite(ink)
    for layer, _mask in layers_and_masks:
        canvas.alpha_composite(layer)
    return canvas


def highlight(canvas, mask, offset=(-40, -60), strength=110):
    shine = mask.filter(ImageFilter.MinFilter(61)).filter(ImageFilter.GaussianBlur(24))
    shifted = Image.new("L", (S, S), 0)
    shifted.paste(shine, offset)
    lit = ImageChops.multiply(shifted, mask)
    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(lit.point(lambda v: int(v * strength / 255)))
    canvas.alpha_composite(white)


def thunder_star():
    star = shape_mask(lambda d: d.polygon(star_points(480, 440, 300, 128), fill=255))
    bolt_pts = [(640, 430), (520, 650), (610, 650), (470, 930), (760, 600), (660, 600), (770, 430)]
    bolt = shape_mask(lambda d: d.polygon(bolt_pts, fill=255))
    star_layer = vertical_gradient(star, rgba("fff3a0"), rgba("ffb21c"))
    bolt_layer = vertical_gradient(bolt, rgba("ffffff"), rgba("ffe14d"))
    canvas = compose([(star_layer, star), (bolt_layer, bolt)], glow=rgba("ffd84a", 200))
    highlight(canvas, star)
    # Little sparks around the bolt tip.
    draw = ImageDraw.Draw(canvas)
    for x, y, r in ((380, 880, 26), (560, 900, 18), (330, 780, 16)):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=rgba("fff6b0"), outline=INK, width=10)
    return canvas


def frost_crystal():
    cx, cy = 512, 500
    pts = [(cx, 120), (cx + 230, 330), (cx + 200, 700), (cx, 900), (cx - 200, 700), (cx - 230, 330)]
    body = shape_mask(lambda d: d.polygon(pts, fill=255))
    layer = vertical_gradient(body, rgba("e9fdff"), rgba("2fb6f0"))
    canvas = compose([(layer, body)], glow=rgba("9ff0ff", 210))
    draw = ImageDraw.Draw(canvas)
    # Facet lines.
    for a, b in (((cx, 120), (cx, 900)), ((cx - 230, 330), (cx + 200, 700)), ((cx + 230, 330), (cx - 200, 700))):
        draw.line([a, b], fill=(255, 255, 255, 120), width=14)
    # Snowflake in the centre.
    for k in range(6):
        a = k * math.pi / 3
        tip = (cx + math.cos(a) * 150, cy + math.sin(a) * 150)
        draw.line([(cx, cy), tip], fill=(255, 255, 255, 255), width=26)
        for side in (-1, 1):
            b = a + side * 0.7
            mid = (cx + math.cos(a) * 95, cy + math.sin(a) * 95)
            draw.line([mid, (mid[0] + math.cos(b) * 55, mid[1] + math.sin(b) * 55)], fill=(255, 255, 255, 255), width=18)
    draw.ellipse((cx - 34, cy - 34, cx + 34, cy + 34), fill=(255, 255, 255, 255))
    highlight(canvas, body, (-30, -70), 90)
    return canvas


def fire_meteor():
    tail_pts = [(256, 426), (600, 170), (660, 250), (790, 130), (820, 290), (890, 270), (574, 744)]
    tail = shape_mask(lambda d: d.polygon(tail_pts, fill=255))
    tail = tail.filter(ImageFilter.GaussianBlur(10)).point(lambda v: 255 if v > 110 else 0)
    ball = shape_mask(lambda d: d.ellipse((190, 360, 640, 810), fill=255))
    tail_layer = vertical_gradient(tail, rgba("ffe066"), rgba("ff5a1f"))
    ball_layer = radial_gradient(ball, (360, 520), 300, rgba("fff4b8"), rgba("e8320f"))
    canvas = compose([(tail_layer, tail), (ball_layer, ball)], glow=rgba("ff8a2a", 210))
    draw = ImageDraw.Draw(canvas)
    # Glowing cracks on the meteor.
    for line in (((300, 500), (390, 580), (360, 690)), ((470, 450), (520, 560)), ((430, 720), (530, 680))):
        draw.line(line, fill=rgba("fff2a8"), width=20, joint="curve")
    for x, y, r in ((760, 640, 22), (860, 520, 16), (700, 760, 14)):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=rgba("ffd166"), outline=INK, width=9)
    highlight(canvas, ball, (-50, -60), 120)
    return canvas


def star_fortress():
    outer = shape_mask(lambda d: d.pieslice((110, 150, 914, 954), 180, 360, fill=255))
    outer = ImageChops.subtract(outer, shape_mask(lambda d: d.pieslice((200, 240, 824, 864), 180, 360, fill=255)))
    inner = shape_mask(lambda d: d.pieslice((250, 290, 774, 814), 180, 360, fill=255))
    base_bar = shape_mask(lambda d: d.rounded_rectangle((90, 540, 934, 640), 46, fill=255))
    outer_layer = vertical_gradient(outer, rgba("fff0a0"), rgba("f0a81c"))
    inner_layer = vertical_gradient(inner, rgba("d8fbff"), rgba("2bbfe8"))
    bar_layer = vertical_gradient(base_bar, rgba("ffe48a"), rgba("d98a10"))
    canvas = compose([(outer_layer, outer), (inner_layer, inner), (bar_layer, base_bar)], glow=rgba("8cf0ff", 190))
    draw = ImageDraw.Draw(canvas)
    draw.polygon(star_points(512, 420, 120, 52), fill=rgba("ffffff"), outline=INK, width=12)
    # Twelve timer ticks under the domes (12 Sekunden).
    for k in range(12):
        x = 160 + k * 64
        draw.rounded_rectangle((x - 22, 690, x + 22, 800), 12, fill=rgba("66e8ff") if k < 8 else rgba("ffd166"), outline=INK, width=8)
    highlight(canvas, inner, (-30, -50), 80)
    return canvas


def whirlwind():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bands = []
    for k in range(5):
        y = 210 + k * 140
        half = 380 - k * 62
        cx = 512 + math.sin(k * 1.1) * 40
        mask = shape_mask(lambda d, y=y, half=half, cx=cx: d.rounded_rectangle((cx - half, y - 46, cx + half, y + 46), 46, fill=255))
        colour = mix(rgba("f2fffd"), rgba("5fe0d0"), k / 4)
        bands.append((vertical_gradient(mask, colour, mix(colour, rgba("2aa8a0"), 0.35)), mask))
    tip = shape_mask(lambda d: d.polygon([(470, 880), (560, 880), (520, 980)], fill=255))
    bands.append((vertical_gradient(tip, rgba("5fe0d0"), rgba("2aa8a0")), tip))
    canvas = compose(bands, glow=rgba("aef7ea", 180))
    draw = ImageDraw.Draw(canvas)
    # Swirl strokes and two flying leaves/flakes.
    for k in range(4):
        y = 280 + k * 140
        draw.arc((300 + k * 40, y - 40, 724 - k * 40, y + 60), 200, 340, fill=(255, 255, 255, 230), width=16)
    draw.ellipse((800, 300, 880, 360), fill=rgba("ffd166"), outline=INK, width=10)
    draw.ellipse((150, 520, 220, 575), fill=rgba("9be36a"), outline=INK, width=10)
    return canvas


ICONS = {
    "thunder_star": thunder_star,
    "frost_crystal": frost_crystal,
    "fire_meteor": fire_meteor,
    "star_fortress": star_fortress,
    "whirlwind": whirlwind,
}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    out.mkdir(parents=True, exist_ok=True)
    for item_id, painter in ICONS.items():
        image = painter().resize((256, 256), Image.LANCZOS)
        path = out / ("icon_%s.webp" % item_id)
        image.save(path, "WEBP", lossless=True)
        print(path, path.stat().st_size)


if __name__ == "__main__":
    main()
