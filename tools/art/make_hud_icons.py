#!/usr/bin/env python3
"""Zeichnet die Abzeichen für den Inhalt des Item-Knopfs (Schild, Impuls, Wind), die Heinz'
Bedienelemente-Blatt nicht enthält: Glasverlauf, helle Kante, farbiges Leuchten.
Ausgabe: assets/kart/hud/icon_shield.png, icon_pulse.png, icon_wind.png (256 x 256, RGBA).
Aufruf: python3 tools/art/make_hud_icons.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets/kart/hud"
S = 1024  # Zeichenfläche, wird auf 256 verkleinert


def gradient(size, top, bottom):
    arr = np.zeros((size, size, 4), np.uint8)
    for y in range(size):
        t = y / (size - 1)
        arr[y, :, :3] = [int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)]
        arr[y, :, 3] = 255
    return Image.fromarray(arr, "RGBA")


def glow_layer(mask: Image.Image, color, radius, strength):
    blurred = mask.filter(ImageFilter.GaussianBlur(radius))
    layer = Image.new("RGBA", mask.size, color + (0,))
    layer.putalpha(blurred.point(lambda v: min(255, int(v * strength))))
    return layer


def finish(mask: Image.Image, top, bottom, rim=(255, 255, 255), glow=None, extra_masks=()):
    """Maske -> Glasverlauf + heller Rand + Leuchten, alles auf transparentem Grund."""
    glow = glow or bottom
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    canvas.alpha_composite(glow_layer(mask, glow, 34, 1.6))
    canvas.alpha_composite(glow_layer(mask, glow, 12, 1.2))
    fill = gradient(S, top, bottom)
    fill.putalpha(mask)
    canvas.alpha_composite(fill)
    # heller Innenrand: Maske minus verkleinerte Maske
    inner = mask.filter(ImageFilter.MinFilter(15))
    edge = ImageChops.subtract(mask, inner)
    rim_layer = Image.new("RGBA", (S, S), rim + (0,))
    rim_layer.putalpha(edge.point(lambda v: int(v * 0.70)))
    canvas.alpha_composite(rim_layer)
    # Glanz oben links
    shine = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shine).ellipse((S * 0.18, S * 0.10, S * 0.62, S * 0.40), fill=70)
    shine = ImageChops.multiply(shine.filter(ImageFilter.GaussianBlur(40)), mask)
    shine_layer = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    shine_layer.putalpha(shine)
    canvas.alpha_composite(shine_layer)
    return canvas


def polygon_mask(points):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(1.6))


def bezier(p0, p1, p2, steps=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / steps for i in range(steps + 1)]]


def stroke_mask(points, width):
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    draw.line(points, fill=255, width=width, joint="curve")
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(1.6))


def shield():
    cx = S // 2
    outline = (bezier((cx, 140), (cx + 330, 170), (cx + 330, 430)) + bezier((cx + 330, 430), (cx + 300, 700), (cx, 890))
               + bezier((cx, 890), (cx - 300, 700), (cx - 330, 430)) + bezier((cx - 330, 430), (cx - 330, 170), (cx, 140)))
    mask = polygon_mask(outline)
    canvas = finish(mask, (190, 245, 255), (40, 130, 255), glow=(70, 200, 255))
    # innere Fläche etwas dunkler, damit der Stern leuchtet
    inner = polygon_mask([(cx + (x - cx) * 0.76, 520 + (y - 520) * 0.76) for x, y in outline])
    dark = Image.new("RGBA", (S, S), (10, 40, 110, 0))
    dark.putalpha(inner.point(lambda v: int(v * 0.55)))
    canvas.alpha_composite(dark)
    star = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 190 if i % 2 == 0 else 84
        star.append((cx + math.cos(a) * r, 500 + math.sin(a) * r))
    canvas.alpha_composite(finish(polygon_mask(star), (255, 244, 190), (255, 178, 40), glow=(255, 200, 80)))
    return canvas


def pulse():
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    cx = cy = S // 2
    d.ellipse((cx - 92, cy - 92, cx + 92, cy + 92), fill=255)
    canvas = finish(mask.filter(ImageFilter.GaussianBlur(1.6)), (240, 255, 255), (60, 190, 255), glow=(80, 210, 255))
    for radius, width, alpha in ((230, 44, 255), (350, 36, 190), (450, 28, 120)):
        ring = Image.new("L", (S, S), 0)
        rd = ImageDraw.Draw(ring)
        rd.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=255, width=width)
        ring = ring.filter(ImageFilter.GaussianBlur(1.6)).point(lambda v, a=alpha: int(v * a / 255))
        canvas.alpha_composite(finish(ring, (200, 245, 255), (60, 170, 255), glow=(70, 200, 255)))
    return canvas


def wind():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    chevrons = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(chevrons)
    for i in range(3):
        x = 330 + i * 190
        d.line([(x, 250), (x + 150, 512), (x, 774)], fill=255, width=96, joint="curve")
    chevrons = chevrons.filter(ImageFilter.GaussianBlur(1.6))
    canvas.alpha_composite(finish(chevrons, (220, 255, 230), (50, 214, 150), glow=(90, 255, 190)))
    lines = Image.new("L", (S, S), 0)
    ld = ImageDraw.Draw(lines)
    for y, x0, x1 in ((330, 90, 270), (512, 40, 250), (694, 110, 280)):
        ld.rounded_rectangle((x0, y - 22, x1, y + 22), radius=22, fill=255)
    canvas.alpha_composite(finish(lines.filter(ImageFilter.GaussianBlur(1.6)), (230, 255, 245), (60, 200, 220), glow=(80, 230, 220)))
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in (("shield", shield), ("pulse", pulse), ("wind", wind)):
        image = make().resize((256, 256), Image.LANCZOS)
        image.save(OUT / f"icon_{name}.png")
        print(name)


if __name__ == "__main__":
    main()
