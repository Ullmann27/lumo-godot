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


def kart_shape(draw_fn_mask, cx, cy, w):
    """Simple kart silhouette (body + two wheels) as mask polygons."""
    h = w * 0.42
    return [(cx - w * 0.5, cy), (cx - w * 0.38, cy - h * 0.55), (cx - w * 0.05, cy - h * 0.6), (cx + w * 0.08, cy - h),
            (cx + w * 0.3, cy - h), (cx + w * 0.36, cy - h * 0.55), (cx + w * 0.5, cy - h * 0.4), (cx + w * 0.5, cy)]


def gravity_wave():
    canvas_layers = []
    for k, r in enumerate((400, 300, 200)):
        ring = shape_mask(lambda d, r=r: d.arc((512 - r, 640 - r * 0.45, 512 + r, 640 + r * 0.45), 0, 360, fill=255, width=46))
        canvas_layers.append((vertical_gradient(ring, mix(rgba("8ff0ff"), rgba("b48cff"), k / 2), rgba("6a5cff")), ring))
    body = shape_mask(lambda d: d.polygon(kart_shape(None, 512, 470, 380), fill=255))
    wheels = shape_mask(lambda d: [d.ellipse((x - 62, 430, x + 62, 554), fill=255) for x in (390, 640)])
    canvas_layers.append((vertical_gradient(body, rgba("ffffff"), rgba("8fe0ff")), body))
    canvas_layers.append((vertical_gradient(wheels, rgba("4a5a80"), rgba("1d2440")), wheels))
    canvas = compose(canvas_layers, glow=rgba("9fe8ff", 200))
    draw = ImageDraw.Draw(canvas)
    for x in (300, 512, 724):
        draw.polygon([(x, 150), (x - 46, 230), (x + 46, 230)], fill=rgba("b8f4ff"), outline=INK, width=12)
    return canvas


def star_decoy():
    real = shape_mask(lambda d: d.polygon(kart_shape(None, 400, 700, 470), fill=255))
    real_wheels = shape_mask(lambda d: [d.ellipse((x - 70, 650, x + 70, 790), fill=255) for x in (250, 545)])
    canvas = compose([(vertical_gradient(real, rgba("ffd66b"), rgba("ff8a3c")), real),
                      (vertical_gradient(real_wheels, rgba("4a5a80"), rgba("1d2440")), real_wheels)], glow=None)
    holo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hmask = shape_mask(lambda d: d.polygon(kart_shape(None, 640, 420, 470), fill=255))
    hw = shape_mask(lambda d: [d.ellipse((x - 70, 370, x + 70, 510), fill=255) for x in (490, 785)])
    union = ImageChops.lighter(hmask, hw)
    lines = Image.new("L", (S, S), 0)
    ld = ImageDraw.Draw(lines)
    for y in range(200, 560, 26):
        ld.rectangle((0, y, S, y + 12), fill=255)
    fill = Image.new("RGBA", (S, S), rgba("6fe8ff", 230))
    fill.putalpha(ImageChops.multiply(union, lines.point(lambda v: 150 + v // 3)))
    rim = Image.new("RGBA", (S, S), rgba("bff6ff"))
    rim.putalpha(ImageChops.subtract(outline(union, 25), union))
    holo.alpha_composite(fill)
    holo.alpha_composite(rim)
    glow = Image.new("RGBA", (S, S), rgba("6fe8ff"))
    glow.putalpha(outline(union, 81).filter(ImageFilter.GaussianBlur(30)).point(lambda v: int(v * 0.5)))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(holo)
    out.alpha_composite(canvas)
    draw = ImageDraw.Draw(out)
    draw.polygon(star_points(800, 180, 110, 46), fill=rgba("ffffff"), outline=INK, width=12)
    return out


def turbo_xl():
    layers = []
    for k in range(3):
        x = 230 + k * 230
        pts = [(x - 110, 260), (x + 40, 260), (x + 190, 512), (x + 40, 764), (x - 110, 764), (x + 40, 512)]
        m = shape_mask(lambda d, pts=pts: d.polygon(pts, fill=255))
        layers.append((vertical_gradient(m, mix(rgba("aef6ff"), rgba("ff7ad9"), k / 2), mix(rgba("3cc7ff"), rgba("b04cff"), k / 2)), m))
    canvas = compose(layers, glow=rgba("7fe6ff", 200))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((640, 760, 950, 950), 40, fill=rgba("ffd23f"), outline=INK, width=16)
    draw.text((675, 770), "XL", fill=INK, font=_font(150))
    return canvas


def _font(size):
    try:
        from PIL import ImageFont
        return ImageFont.truetype(str(ROOT / "assets/fonts/Nunito-Black.ttf"), size)
    except OSError:
        from PIL import ImageFont
        return ImageFont.load_default()


def arc_trap():
    posts = shape_mask(lambda d: [d.rounded_rectangle((x - 50, 420, x + 50, 900), 30, fill=255) for x in (230, 794)])
    caps = shape_mask(lambda d: [d.ellipse((x - 85, 330, x + 85, 500), fill=255) for x in (230, 794)])
    canvas = compose([(vertical_gradient(posts, rgba("7b6aa8"), rgba("3a2d63")), posts),
                      (radial_gradient(caps, (230, 400), 120, rgba("ffffff"), rgba("b47cff")), caps)], glow=rgba("c08cff", 200))
    draw = ImageDraw.Draw(canvas)
    pts = [(230, 410), (330, 250), (410, 360), (512, 200), (614, 360), (694, 250), (794, 410)]
    draw.line(pts, fill=rgba("b47cff"), width=70, joint="curve")
    draw.line(pts, fill=rgba("fff4ff"), width=26, joint="curve")
    draw.line([(150, 930), (874, 930)], fill=rgba("c08cff"), width=30)
    return canvas


def time_bloom():
    layers = []
    for k in range(8):
        a = k * math.pi / 4
        cx, cy = 512 + math.cos(a) * 230, 512 + math.sin(a) * 230
        m = shape_mask(lambda d, cx=cx, cy=cy: d.ellipse((cx - 140, cy - 140, cx + 140, cy + 140), fill=255))
        colour = rgba("7ff0d8") if k % 2 == 0 else rgba("ff9fd2")
        layers.append((radial_gradient(m, (cx, cy), 160, rgba("ffffff"), colour), m))
    centre = shape_mask(lambda d: d.ellipse((322, 322, 702, 702), fill=255))
    layers.append((radial_gradient(centre, (480, 470), 260, rgba("fffbe8"), rgba("ffe08a")), centre))
    canvas = compose(layers, glow=rgba("9ff5e2", 190))
    draw = ImageDraw.Draw(canvas)
    for k in range(12):
        a = k * math.pi / 6
        draw.line([(512 + math.cos(a) * 150, 512 + math.sin(a) * 150), (512 + math.cos(a) * 175, 512 + math.sin(a) * 175)], fill=INK, width=14)
    draw.line([(512, 512), (512, 380)], fill=INK, width=26)
    draw.line([(512, 512), (610, 560)], fill=INK, width=22)
    draw.ellipse((488, 488, 536, 536), fill=INK)
    return canvas


ICONS = {
    "gravity_wave": gravity_wave,
    "star_decoy": star_decoy,
    "turbo_xl": turbo_xl,
    "arc_trap": arc_trap,
    "time_bloom": time_bloom,
    "thunder_star": thunder_star,
    "frost_crystal": frost_crystal,
    "fire_meteor": fire_meteor,
    "star_fortress": star_fortress,
    "whirlwind": whirlwind,
}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    out.mkdir(parents=True, exist_ok=True)
    for item_id, painter in ICONS.items():
        if only and item_id not in only:
            continue
        image = painter().resize((256, 256), Image.LANCZOS)
        path = out / ("icon_%s.webp" % item_id)
        image.save(path, "WEBP", lossless=True)
        print(path, path.stat().st_size)


if __name__ == "__main__":
    main()
