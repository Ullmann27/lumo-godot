#!/usr/bin/env python3
"""Baut das Lumo-Sternendeck und die Tisch-Grafiken für den Kartentisch.

Alles hier ist eigene Gestaltung: Formen, Farben und Aufbau entstehen in diesem
Skript. Die Bildkarten zeigen die Porträts der Projektfiguren, gerendert von
`tools/cards/render_portraits.gd` aus den vorhandenen 3D-Modellen. Einzige
Fremddatei ist die Projektschrift Nunito (SIL OFL 1.1, assets/fonts).

Aufruf:
    /home/user/tools/bpyenv/bin/python tools/cards/build_star_deck.py
    /home/user/tools/bpyenv/bin/python tools/cards/build_star_deck.py --sheet /tmp/deck.png

Schreibt nach assets/cards_table/: deck/star_deck.webp + star_deck.json,
ui/*.webp, portraits/*.webp, table/*.webp. Gleiche Eingaben, gleiche Dateien.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'cards_table'
PORTRAITS = Path(__file__).resolve().parent / 'portraits'
FONT = ROOT / 'assets' / 'fonts' / 'Nunito-Black.ttf'

CELL_W, CELL_H = 256, 360
COLS, ROWS = 8, 7
SS = 3  # Überabtastung
W, H = CELL_W * SS, CELL_H * SS

SUITS = [
    # Schlüssel, Name, hell, dunkel, Akzent
    ('stern', 'Stern', (255, 190, 46), (238, 112, 20), (255, 236, 150)),
    ('mond', 'Mond', (160, 122, 255), (88, 56, 205), (222, 205, 255)),
    ('blatt', 'Blatt', (74, 214, 128), (20, 142, 84), (200, 250, 190)),
    ('welle', 'Welle', (64, 190, 255), (18, 110, 214), (190, 238, 255)),
]
FACES = {11: ('NOVA', 'rabbit'), 12: ('EULE', 'owl'), 13: ('LUMO', 'lumo')}
NAVY = (9, 26, 66)
WHITE = (255, 255, 255)


def font(size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), int(round(size)))


# ----------------------------------------------------------------- Formen

def star_points(cx, cy, outer, inner=0.5, spikes=5, turn=-90.0):
    points = []
    for index in range(spikes * 2):
        radius = outer if index % 2 == 0 else outer * inner
        angle = math.radians(turn + index * 180.0 / spikes)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def symbol_mask(suit: str, size: int) -> Image.Image:
    """Weiße Form auf Schwarz, quadratisch, mit weichem Rand."""
    big = size * 2
    mask = Image.new('L', (big, big), 0)
    draw = ImageDraw.Draw(mask)
    c = big / 2
    if suit == 'stern':
        draw.polygon(star_points(c, c * 1.04, big * 0.48, 0.52), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(big * 0.022)).point(lambda v: 255 if v > 118 else 0)
    elif suit == 'mond':
        radius = big * 0.44
        draw.ellipse((c - radius, c - radius, c + radius, c + radius), fill=255)
        cut = Image.new('L', (big, big), 0)
        offset = radius * 0.50
        inner = radius * 0.84
        ImageDraw.Draw(cut).ellipse((c + offset - inner, c - offset * 0.42 - inner,
                                     c + offset + inner, c - offset * 0.42 + inner), fill=255)
        mask = ImageChops.subtract(mask, cut)
    elif suit == 'blatt':
        points = []
        length = big * 0.46
        for step in range(0, 181, 4):
            t = math.radians(step)
            points.append((length * 0.70 * math.sin(t) ** 0.9, -length * math.cos(t)))
        for step in range(180, -1, -4):
            t = math.radians(step)
            points.append((-length * 0.70 * math.sin(t) ** 0.9, -length * math.cos(t)))
        turn = math.radians(38)
        rotated = [(c + x * math.cos(turn) - y * math.sin(turn), c + x * math.sin(turn) + y * math.cos(turn))
                   for x, y in points]
        draw.polygon(rotated, fill=255)
        # Mittelrippe und Stiel als Aussparung/Ansatz.
        tip = (c + length * math.sin(turn), c - length * math.cos(turn))
        foot = (c - length * math.sin(turn), c + length * math.cos(turn))
        draw.line((c + (tip[0] - c) * 0.55, c + (tip[1] - c) * 0.55, c + (foot[0] - c) * 0.72,
                   c + (foot[1] - c) * 0.72), fill=0, width=int(big * 0.035))
        draw.line((foot[0], foot[1], c + (foot[0] - c) * 1.2, c + (foot[1] - c) * 1.2), fill=255,
                  width=int(big * 0.07))
    else:  # welle
        for row, shift in ((-0.20, 0.0), (0.20, 0.0)):
            upper, lower = [], []
            thickness = big * 0.105
            for step in range(0, 101):
                x = big * 0.07 + step / 100 * big * 0.86
                y = c + row * big + math.sin((step / 100 * 1.5 + shift) * math.pi * 2) * big * 0.085
                upper.append((x, y - thickness))
                lower.append((x, y + thickness))
            draw.polygon(upper + lower[::-1], fill=255)
            for x, y in (upper[0], upper[-1]):
                draw.ellipse((x - thickness, y, x + thickness, y + thickness * 2), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def tint(mask: Image.Image, color, alpha: float = 1.0) -> Image.Image:
    layer = Image.new('RGBA', mask.size, tuple(color) + (0,))
    layer.putalpha(mask.point(lambda v: int(v * alpha)))
    return layer


def gradient(size, top, bottom) -> Image.Image:
    width, height = size
    column = Image.new('RGB', (1, height))
    for y in range(height):
        f = y / max(1, height - 1)
        column.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))
    return column.resize((width, height))


def rounded_mask(size, radius) -> Image.Image:
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def soft_shadow(layer: Image.Image, offset, blur, color=(0, 0, 0), strength=0.5) -> Image.Image:
    alpha = layer.getchannel('A').point(lambda v: int(v * strength))
    shadow = Image.new('RGBA', layer.size, tuple(color) + (0,))
    shadow.putalpha(alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    return ImageChops.offset(shadow, int(offset[0]), int(offset[1]))


def text_layer(size, text, pixel, fill, anchor='mm', at=None, stroke=0, stroke_fill=None) -> Image.Image:
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    position = at if at is not None else (size[0] / 2, size[1] / 2)
    draw.text(position, text, font=font(pixel), fill=fill, anchor=anchor, stroke_width=int(stroke),
              stroke_fill=stroke_fill)
    return layer


# ------------------------------------------------------------------ Karten

def card_base(light, dark, accent) -> Image.Image:
    """Weißer Rahmen, farbiges Feld mit Schimmer – ohne Inhalt."""
    card = Image.new('RGBA', (W, H), (252, 250, 244, 255))
    border = int(W * 0.050)
    field_size = (W - border * 2, H - border * 2)
    field = gradient(field_size, light, dark).convert('RGBA')
    # Lichtkegel oben links und zarte Sternpunkte.
    glow = Image.new('L', field_size, 0)
    ImageDraw.Draw(glow).ellipse((-field_size[0] * 0.5, -field_size[1] * 0.45, field_size[0] * 0.9,
                                  field_size[1] * 0.5), fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.09))
    field = Image.composite(Image.new('RGBA', field_size, accent + (255,)), field, glow)
    dots = ImageDraw.Draw(field)
    for index in range(34):
        x = (index * 197 + 61) % field_size[0]
        y = (index * 331 + 97) % field_size[1]
        radius = 2 + (index * 7) % 5
        dots.ellipse((x - radius, y - radius, x + radius, y + radius), fill=WHITE + (70 + (index * 13) % 70,))
    field.putalpha(rounded_mask(field_size, int(W * 0.075)))
    card.alpha_composite(field, (border, border))
    # Feine dunkle Innenlinie gibt dem Feld Tiefe.
    line = ImageDraw.Draw(card)
    line.rounded_rectangle((border, border, W - border - 1, H - border - 1), radius=int(W * 0.075),
                           outline=tuple(int(v * 0.62) for v in dark) + (255,), width=max(2, SS * 1))
    return card


def corner_index(card: Image.Image, label: str, suit: str, dark) -> None:
    """Wert und Farbform oben links (im Fächer sichtbar), Farbform unten rechts."""
    tab_w, tab_h = int(W * 0.245), int(H * 0.255)
    tab = Image.new('RGBA', (tab_w, tab_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tab)
    draw.rounded_rectangle((0, 0, tab_w - 1, tab_h - 1), radius=int(W * 0.055),
                           fill=tuple(int(v * 0.50) for v in dark) + (238,))
    pixel = W * (0.180 if len(label) == 1 else 0.142)
    tab.alpha_composite(text_layer((tab_w, tab_h), label, pixel, WHITE + (255,), at=(tab_w / 2, tab_h * 0.30)))
    symbol = tint(symbol_mask(suit, int(tab_w * 0.58)), WHITE)
    tab.alpha_composite(symbol, (int(tab_w * 0.21), int(tab_h * 0.55)))
    margin = int(W * 0.072)
    card.alpha_composite(tab, (margin, margin))
    small = int(W * 0.13)
    mark = tint(symbol_mask(suit, small), WHITE, 0.92).rotate(180)
    position = (W - int(W * 0.095) - small, H - int(W * 0.095) - small)
    card.alpha_composite(soft_shadow(mark, (0, SS), SS, (0, 0, 0), 0.35), position)
    card.alpha_composite(mark, position)


def number_card(suit_index: int, rank: int) -> Image.Image:
    key, _name, light, dark, accent = SUITS[suit_index]
    card = Image.new('RGBA', (W, H), (252, 249, 237, 255))
    draw = ImageDraw.Draw(card)
    inset = int(W * .035)
    draw.rounded_rectangle((inset, inset, W - inset, H - inset), radius=int(W * .065),
                           outline=dark + (255,), width=3 * SS)
    # An inset suit seal and a large dark numeral keep the value readable in a small hand.
    cx, cy = W * .52, H * .49
    radius = W * .33
    paper_tint = tuple(round(.22 * v + .78 * 248) for v in light)
    draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=paper_tint + (255,))
    mark = tint(symbol_mask(key, int(W * .51)), accent)
    card.alpha_composite(mark, (int(cx - mark.width/2), int(cy - mark.height/2)))
    corner_index(card, str(rank), key, dark)
    ink = tuple(round(v * .51) for v in dark)
    label = str(rank)
    pixel = W * (.58 if len(label) == 1 else .47)
    card.alpha_composite(text_layer((W, H), label, pixel, ink + (255,), at=(cx, cy)))
    # Mengenbild: so viele kleine Formen wie der Wert (Zehnerfeld, 2 × 5).
    pip = int(W * 0.088)
    gap = int(pip * 0.22)
    rows = [min(rank, 5), max(0, rank - 5)]
    top = int(H * 0.735)
    for row, count in enumerate(rows):
        if count == 0:
            continue
        total = count * pip + (count - 1) * gap
        x0 = (W - total) // 2
        for column in range(count):
            symbol = tint(symbol_mask(key, pip), dark)
            position = (x0 + column * (pip + gap), top + row * (pip + gap))
            card.alpha_composite(symbol, position)
    return card


def face_card(suit_index: int, rank: int) -> Image.Image:
    key, _name, light, dark, accent = SUITS[suit_index]
    title, portrait_id = FACES[rank]
    card = card_base(light, dark, accent)
    # Strahlenkranz hinter dem Porträt.
    rays = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rays)
    centre = (W / 2, H * 0.455)
    for index in range(16):
        a0 = math.radians(index * 22.5 - 5)
        a1 = math.radians(index * 22.5 + 5)
        reach = W * 0.62
        draw.polygon([centre, (centre[0] + reach * math.cos(a0), centre[1] + reach * math.sin(a0)),
                      (centre[0] + reach * math.cos(a1), centre[1] + reach * math.sin(a1))], fill=WHITE + (46,))
    field_mask = rounded_mask((W - int(W * 0.10), H - int(W * 0.10)), int(W * 0.075))
    clip = Image.new('L', (W, H), 0)
    clip.paste(field_mask, (int(W * 0.05), int(W * 0.05)))
    rays.putalpha(ImageChops.multiply(rays.getchannel('A'), clip))
    card.alpha_composite(rays)
    # Rundes Fenster mit Porträt.
    radius = int(W * 0.335)
    ring = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ring)
    draw.ellipse((centre[0] - radius - SS * 5, centre[1] - radius - SS * 5, centre[0] + radius + SS * 5,
                  centre[1] + radius + SS * 5), fill=WHITE + (255,))
    card.alpha_composite(soft_shadow(ring, (0, SS * 4), SS * 5, tuple(int(v * 0.3) for v in dark), 0.6))
    card.alpha_composite(ring)
    window = gradient((radius * 2, radius * 2), tuple(min(255, int(v * 0.55 + 110)) for v in accent),
                      tuple(int(v * 0.72) for v in light)).convert('RGBA')
    portrait = Image.open(PORTRAITS / f'{portrait_id}.png').convert('RGBA')
    scale = radius * 2.0 / portrait.width * (1.06 if portrait_id != 'rabbit' else 1.24)
    portrait = portrait.resize((int(portrait.width * scale), int(portrait.height * scale)), Image.LANCZOS)
    offset_y = int(radius * (0.10 if portrait_id != 'rabbit' else -0.06))
    window.alpha_composite(portrait, ((radius * 2 - portrait.width) // 2, (radius * 2 - portrait.height) // 2 + offset_y))
    disc = Image.new('L', (radius * 2, radius * 2), 0)
    ImageDraw.Draw(disc).ellipse((0, 0, radius * 2 - 1, radius * 2 - 1), fill=255)
    window.putalpha(disc)
    card.alpha_composite(window, (int(centre[0] - radius), int(centre[1] - radius)))
    corner_index(card, str(rank), key, dark)
    # Namensband.
    band_w, band_h = int(W * 0.60), int(H * 0.115)
    band = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(band)
    left, top = (W - band_w) // 2, int(H * 0.775)
    draw.rounded_rectangle((left, top, left + band_w, top + band_h), radius=band_h // 2,
                           fill=(255, 251, 240, 255), outline=tuple(int(v * 0.62) for v in dark) + (255,),
                           width=SS * 2)
    card.alpha_composite(soft_shadow(band, (0, SS * 3), SS * 3, (0, 0, 0), 0.4))
    card.alpha_composite(band)
    card.alpha_composite(text_layer((W, H), title, band_h * 0.70, tuple(int(v * 0.50) for v in dark) + (255,),
                                    at=(W / 2, top + band_h * 0.50)))
    # Kleine Krone aus drei Sternen über dem Fenster.
    for index, dx in enumerate((-0.11, 0.0, 0.11)):
        size = int(W * (0.085 if index == 1 else 0.062))
        star = tint(symbol_mask('stern', size), (255, 240, 170))
        position = (int(W / 2 + dx * W - size / 2), int(centre[1] - radius - size * (1.1 if index == 1 else 0.82)))
        card.alpha_composite(soft_shadow(star, (0, SS), SS * 2, (60, 30, 0), 0.6), position)
        card.alpha_composite(star, position)
    return card


def card_back() -> Image.Image:
    card = Image.new('RGBA', (W, H), (252, 250, 244, 255))
    border = int(W * 0.050)
    field_size = (W - border * 2, H - border * 2)
    field = gradient(field_size, (22, 66, 150), (8, 22, 70)).convert('RGBA')
    draw = ImageDraw.Draw(field)
    cx, cy = field_size[0] / 2, field_size[1] / 2
    # Sternbild-Punkte auf festem Raster.
    state = 20261117
    for index in range(70):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        x = (state >> 8) % field_size[0]
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        y = (state >> 8) % field_size[1]
        radius = 2 + (index * 5) % 5
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(170, 220, 255, 60 + (index * 17) % 110))
    for radius, width, color in ((0.40, 4, (83, 221, 253, 255)), (0.345, 2, (83, 221, 253, 130)),
                                 (0.46, 2, (255, 201, 74, 150))):
        r = field_size[0] * radius
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=width * SS)
    # Kompassstrahlen.
    for index in range(8):
        angle = math.radians(index * 45 + 22.5)
        r0, r1 = field_size[0] * 0.345, field_size[0] * 0.46
        draw.line((cx + r0 * math.cos(angle), cy + r0 * math.sin(angle), cx + r1 * math.cos(angle),
                   cy + r1 * math.sin(angle)), fill=(255, 201, 74, 170), width=SS * 2)
    field.putalpha(rounded_mask(field_size, int(W * 0.075)))
    card.alpha_composite(field, (border, border))
    star = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(star).polygon(star_points(W / 2, H / 2 + W * 0.01, W * 0.235, 0.50), fill=(255, 205, 70, 255))
    star = star.filter(ImageFilter.GaussianBlur(SS * 1.2))
    halo = soft_shadow(star, (0, 0), SS * 12, (255, 215, 110), 0.9)
    card.alpha_composite(halo)
    card.alpha_composite(star)
    shine = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shine).polygon(star_points(W / 2, H / 2 - W * 0.012, W * 0.125, 0.50), fill=(255, 244, 190, 255))
    card.alpha_composite(shine.filter(ImageFilter.GaussianBlur(SS * 2)))
    line = ImageDraw.Draw(card)
    line.rounded_rectangle((border + SS * 5, border + SS * 5, W - border - SS * 5 - 1, H - border - SS * 5 - 1),
                           radius=int(W * 0.062), outline=(83, 221, 253, 200), width=SS * 2)
    return card


def finish(card: Image.Image) -> Image.Image:
    return card.convert('RGB').resize((CELL_W, CELL_H), Image.LANCZOS)


def build_deck() -> tuple[Image.Image, dict]:
    atlas = Image.new('RGB', (CELL_W * COLS, CELL_H * ROWS), (252, 250, 244))
    cells = {}
    index = 0
    for suit in range(4):
        for rank in range(1, 14):
            image = face_card(suit, rank) if rank in FACES else number_card(suit, rank)
            atlas.paste(finish(image), ((index % COLS) * CELL_W, (index // COLS) * CELL_H))
            cells[str(suit * 13 + rank - 1)] = index
            index += 1
    atlas.paste(finish(card_back()), ((index % COLS) * CELL_W, (index // COLS) * CELL_H))
    layout = {'generator': 'tools/cards/build_star_deck.py', 'cell': [CELL_W, CELL_H], 'columns': COLS,
              'rows': ROWS, 'cards': cells, 'back': index, 'edge': index + 1,
              'suits': [suit[0] for suit in SUITS]}
    return atlas, layout


# ----------------------------------------------------------- Oberfläche/Tisch

def suit_icon(suit_index: int, size: int = 128) -> Image.Image:
    key, _name, light, dark, _accent = SUITS[suit_index]
    big = size * 2
    mask = symbol_mask(key, int(big * 0.80))
    canvas = Image.new('L', (big, big), 0)
    canvas.paste(mask, (int(big * 0.10), int(big * 0.10)))
    outline = canvas.filter(ImageFilter.MaxFilter(int(big * 0.07) | 1)).filter(ImageFilter.GaussianBlur(1.5))
    icon = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    icon.alpha_composite(tint(outline, WHITE))
    fill = gradient((big, big), light, dark).convert('RGBA')
    fill.putalpha(canvas)
    icon.alpha_composite(fill)
    return icon.resize((size, size), Image.LANCZOS)


def card_glow(size=(192, 256)) -> Image.Image:
    """Weicher Leuchtrahmen für spielbare Karten (wird eingefärbt)."""
    big = (size[0] * 2, size[1] * 2)
    mask = Image.new('L', big, 0)
    pad = int(big[0] * 0.14)
    ImageDraw.Draw(mask).rounded_rectangle((pad, pad, big[0] - pad, big[1] - pad), radius=int(big[0] * 0.10),
                                           fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(big[0] * 0.055))
    image = Image.new('RGBA', big, WHITE + (0,))
    image.putalpha(mask)
    return image.resize(size, Image.LANCZOS)


def emote(kind: str, size: int = 160) -> Image.Image:
    big = size * 3
    image = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    pad = int(big * 0.08)
    body = (pad, pad, big - pad, int(big * 0.80))
    draw.rounded_rectangle(body, radius=int(big * 0.30), fill=(255, 255, 255, 255), outline=NAVY + (255,),
                           width=int(big * 0.03))
    draw.polygon([(big * 0.36, big * 0.78), (big * 0.50, big * 0.78), (big * 0.33, big * 0.95)],
                 fill=(255, 255, 255, 255), outline=NAVY + (255,), width=int(big * 0.03))
    draw.polygon([(big * 0.375, big * 0.76), (big * 0.485, big * 0.76), (big * 0.40, big * 0.83)],
                 fill=(255, 255, 255, 255))
    cx, cy = big / 2, (body[1] + body[3]) / 2
    if kind == 'think':
        for index in range(3):
            r = big * 0.062
            x = cx + (index - 1) * big * 0.19
            draw.ellipse((x - r, cy - r, x + r, cy + r), fill=(60, 100, 190, 255))
    elif kind == 'happy':
        draw.polygon(star_points(cx, cy + big * 0.01, big * 0.25, 0.50), fill=(255, 190, 40, 255),
                     outline=(214, 120, 10, 255), width=int(big * 0.02))
    elif kind == 'grumpy':
        # Kleine Gewitterwolke mit Kringel – kindgerechter Ärger.
        for dx, dy, r in ((-0.11, 0.02, 0.10), (0.02, -0.05, 0.13), (0.14, 0.03, 0.09)):
            draw.ellipse((cx + dx * big - r * big, cy + dy * big - r * big, cx + dx * big + r * big,
                          cy + dy * big + r * big), fill=(120, 132, 160, 255))
        draw.rectangle((cx - big * 0.17, cy + big * 0.02, cx + big * 0.19, cy + big * 0.11), fill=(120, 132, 160, 255))
        draw.arc((cx - big * 0.07, cy - big * 0.06, cx + big * 0.07, cy + big * 0.08), 200, 520,
                 fill=(255, 255, 255, 255), width=int(big * 0.025))
    elif kind == 'idea':
        draw.ellipse((cx - big * 0.14, cy - big * 0.20, cx + big * 0.14, cy + big * 0.08), fill=(255, 214, 70, 255),
                     outline=(214, 140, 10, 255), width=int(big * 0.02))
        draw.rounded_rectangle((cx - big * 0.07, cy + big * 0.07, cx + big * 0.07, cy + big * 0.18),
                               radius=int(big * 0.02), fill=(120, 132, 160, 255))
    else:  # ask
        image.alpha_composite(text_layer((big, big), '?', big * 0.52, (60, 100, 190, 255), at=(cx, cy)))
    return image.resize((size, size), Image.LANCZOS)


def table_top(size: int = 1024) -> Image.Image:
    """Runde Tischplatte: Nachtblauer Filz mit leuchtendem Sternenkreis."""
    big = size * 2
    c = big / 2
    felt = gradient((big, big), (20, 58, 128), (10, 30, 84)).convert('RGBA')
    # Filzkorn aus festen Punkten.
    grain = Image.effect_noise((big // 4, big // 4), 26).resize((big, big), Image.BICUBIC)
    felt = Image.blend(felt, Image.merge('RGBA', (grain, grain, grain, Image.new('L', (big, big), 255))), 0.07)
    vignette = Image.new('L', (big, big), 0)
    ImageDraw.Draw(vignette).ellipse((big * 0.10, big * 0.10, big * 0.90, big * 0.90), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(big * 0.10))
    felt = Image.composite(felt, Image.new('RGBA', (big, big), (6, 16, 48, 255)), vignette)
    glow = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for radius, width, color in ((0.445, 10, (83, 221, 253, 255)), (0.415, 3, (83, 221, 253, 150)),
                                 (0.255, 5, (83, 221, 253, 210)), (0.235, 2, (255, 201, 74, 190))):
        r = big * radius
        draw.ellipse((c - r, c - r, c + r, c + r), outline=color, width=width * 2)
    for index in range(24):
        angle = math.radians(index * 15)
        r0, r1 = big * 0.415, big * 0.445
        draw.line((c + r0 * math.cos(angle), c + r0 * math.sin(angle), c + r1 * math.cos(angle),
                   c + r1 * math.sin(angle)), fill=(83, 221, 253, 190), width=4)
    for index in range(12):
        angle = math.radians(index * 30 + 15)
        r = big * 0.335
        size_star = big * (0.020 if index % 3 else 0.030)
        draw.polygon(star_points(c + r * math.cos(angle), c + r * math.sin(angle), size_star, 0.48),
                     fill=(255, 220, 120, 230))
    draw.polygon(star_points(c, c, big * 0.105, 0.46, 8, -90), fill=(255, 201, 74, 70))
    draw.polygon(star_points(c, c, big * 0.075, 0.50), fill=(255, 214, 110, 150))
    halo = glow.filter(ImageFilter.GaussianBlur(big * 0.012))
    felt.alpha_composite(halo)
    felt.alpha_composite(halo)
    felt.alpha_composite(glow)
    return felt.convert('RGB').resize((size, size), Image.LANCZOS)


def table_glow(size: int = 512) -> Image.Image:
    """Nur die Leuchtlinien – als Emission über dem Filz."""
    big = size * 2
    c = big / 2
    glow = Image.new('RGB', (big, big), (0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for radius, width, color in ((0.445, 10, (60, 190, 240)), (0.255, 5, (50, 160, 220)), (0.235, 2, (220, 160, 50))):
        r = big * radius
        draw.ellipse((c - r, c - r, c + r, c + r), outline=color, width=width * 2)
    for index in range(12):
        angle = math.radians(index * 30 + 15)
        r = big * 0.335
        size_star = big * (0.020 if index % 3 else 0.030)
        draw.polygon(star_points(c + r * math.cos(angle), c + r * math.sin(angle), size_star, 0.48),
                     fill=(230, 180, 80))
    draw.polygon(star_points(c, c, big * 0.075, 0.50), fill=(150, 110, 40))
    soft = glow.filter(ImageFilter.GaussianBlur(big * 0.014))
    return ImageChops.add(glow, soft).resize((size, size), Image.LANCZOS)


def wood(size: int = 512, planks: int = 0) -> Image.Image:
    """Kachelbare, gemalte Holzmaserung (Fasern laufen senkrecht)."""
    import numpy as np
    rng = np.random.default_rng(20261117 + planks)
    # Feine Fasern: Rauschen quer, stark gestreckt längs; durch Kacheln nahtlos.
    fine = rng.random((1, size))
    fine = np.repeat(fine, size, axis=0)
    slow = rng.random((size // 32, size // 8))
    slow_image = Image.fromarray((slow * 255).astype('uint8')).resize((size, size), Image.BICUBIC)
    slow = np.asarray(slow_image, dtype=float) / 255.0
    wobble = rng.random((size // 64, 1))
    wobble_image = Image.fromarray((np.repeat(wobble, 8, axis=1) * 255).astype('uint8')).resize((size, size), Image.BICUBIC)
    shift = (np.asarray(wobble_image, dtype=float) / 255.0 - 0.5) * 18.0
    xs = (np.arange(size)[None, :] + shift).astype(int) % size
    fine = fine[np.arange(size)[:, None], xs]
    value = 0.62 + 0.20 * (fine - 0.5) + 0.26 * (slow - 0.5)
    if planks:
        width = size // planks
        for index in range(planks):
            value[:, index * width:(index + 1) * width] += (rng.random() - 0.5) * 0.14
            value[:, index * width:index * width + 3] *= 0.55
            value[:, (index + 1) * width - 2:(index + 1) * width] *= 1.06
    value = np.clip(value, 0.0, 1.0)
    # Warmes Holz: dunkel rotbraun bis honiggelb.
    dark = np.array([96, 58, 38], dtype=float)
    light = np.array([226, 168, 112], dtype=float)
    rgb = dark[None, None, :] + (light - dark)[None, None, :] * value[:, :, None]
    image = Image.fromarray(rgb.astype('uint8'), 'RGB')
    # Naht glätten: Bild um die Hälfte versetzen und Ränder überblenden.
    return image.filter(ImageFilter.GaussianBlur(0.6))


def save_webp(image: Image.Image, path: Path, quality: int = 90, lossless: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, 'WEBP', quality=quality, method=6, lossless=lossless, exact=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sheet', type=Path, help='zusätzlich ein PNG-Prüfbild des Atlas schreiben')
    args = parser.parse_args()
    atlas, layout = build_deck()
    save_webp(atlas, OUT / 'deck' / 'star_deck.webp', quality=94)
    (OUT / 'deck' / 'star_deck.json').write_text(json.dumps(layout, indent=1) + '\n')
    for index, suit in enumerate(SUITS):
        save_webp(suit_icon(index), OUT / 'ui' / f'suit_{suit[0]}.webp', lossless=True)
    save_webp(card_glow(), OUT / 'ui' / 'card_glow.webp', lossless=True)
    for kind in ('think', 'happy', 'grumpy', 'idea', 'ask'):
        save_webp(emote(kind), OUT / 'ui' / f'emote_{kind}.webp', lossless=True)
    for path in sorted(PORTRAITS.glob('*.png')):
        portrait = Image.open(path).convert('RGBA').resize((192, 192), Image.LANCZOS)
        save_webp(portrait, OUT / 'portraits' / f'{path.stem}.webp', quality=92)
    save_webp(table_top(), OUT / 'table' / 'table_top.webp', quality=90)
    save_webp(table_glow(), OUT / 'table' / 'table_glow.webp', quality=88)
    save_webp(wood(512, 0), OUT / 'table' / 'wood_grain.webp', quality=86)
    save_webp(wood(512, 4), OUT / 'table' / 'wood_planks.webp', quality=86)
    if args.sheet:
        atlas.save(args.sheet)
    total = sum(path.stat().st_size for path in OUT.rglob('*.webp'))
    print(f'[StarDeck] {len(layout["cards"])} Karten + Rücken, {total // 1024} KB WebP in {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
