#!/usr/bin/env python3
"""Schneidet aus Heinz' Bedienelemente-Blatt (docs/design_targets/2026-10-08-kart-fahrzeuge/07_*.png)
die Bildteile für die Rennanzeige und baut daraus sauber trennbare Texturen:

  assets/kart/hud/frame.png            leerer Glasrahmen (ohne Symbol und Beschriftung)
  assets/kart/hud/icon_gas.png         goldenes Pedal mit Tempostreifen
  assets/kart/hud/icon_brake.png       rote Bremsscheibe
  assets/kart/hud/icon_boost.png       türkise Rakete
  assets/kart/hud/icon_item.png        goldener Fragezeichen-Würfel
  assets/kart/hud/joystick_ring.png    Lenkring mit Pfeilen
  assets/kart/hud/joystick_knob.png    runder Lenkknopf

Beschriftungen zeichnet das Spiel selbst (damit Item-Name und Boost-Anzahl lebendig bleiben).
Symbole werden durch Differenz zum rekonstruierten leeren Rahmen freigestellt, inklusive weichem Leuchten.
Aufruf: python3 tools/art/extract_hud_art.py
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "docs/design_targets/2026-10-08-kart-fahrzeuge/07_kart_von_hinten_und_bedienelemente.png"
OUT = ROOT / "assets/kart/hud"
# Spaltenbereiche der sechs Bauteile im Blatt (x von, x bis), Zeilenbereich der unteren Reihe.
PIECES = {
    "joystick_ring": (27, 313),
    "joystick_knob": (332, 485),
    "gas": (506, 782),
    "brake": (796, 1071),
    "boost": (1085, 1361),
    "item": (1377, 1653),
}
ROW = (579, 889)
PAD = 28


def crop(sheet: Image.Image, name: str) -> Image.Image:
    x0, x1 = PIECES[name]
    box = (max(0, x0 - PAD), ROW[0] - 4, min(sheet.width, x1 + PAD), ROW[1] + 4)
    return sheet.crop(box).convert("RGBA")


def isolate_main_piece(region: np.ndarray) -> np.ndarray:
    """Der Zuschnitt enthält am Rand Teile der Nachbarn: nur das größte zusammenhängende Teil
    (samt weichem Leuchten) behalten, alles andere durchsichtig machen."""
    solid = ndi.binary_closing(region[..., 3] > 40, iterations=3)
    labels, count = ndi.label(solid)
    if count <= 1:
        return region
    sizes = ndi.sum(solid, labels, range(1, count + 1))
    main = labels == (int(np.argmax(sizes)) + 1)
    keep = ndi.binary_dilation(main, iterations=10)
    cleaned = region.copy()
    cleaned[~keep] = 0
    return cleaned


def ring_and_interior(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Rahmenring (größte helle Schleife) und das Innere der Glasfläche (abgerundetes Quadrat)."""
    rgb = rgba[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    bright = (hsv[..., 2] > 195) & (rgba[..., 3] > 200)
    labels, count = ndi.label(ndi.binary_closing(bright, iterations=2))
    best = 0
    best_span = -1
    for index in range(1, count + 1):
        ys, xs = np.where(labels == index)
        span = (xs.max() - xs.min()) * (ys.max() - ys.min())
        if span > best_span:
            best_span = span
            best = index
    ring = labels == best
    ys, xs = np.where(ring)
    cx = (xs.min() + xs.max()) / 2.0
    cy = (ys.min() + ys.max()) / 2.0
    half_w = (xs.max() - xs.min()) / 2.0
    half_h = (ys.max() - ys.min()) / 2.0
    yy, xx = np.mgrid[0 : rgba.shape[0], 0 : rgba.shape[1]]
    # Innenfläche: Superellipse (n = 4,5), etwas kleiner als der Ring, damit der Leuchtrand bleibt.
    inner_w = half_w * 0.885
    inner_h = half_h * 0.88
    interior = (np.abs((xx - cx) / inner_w) ** 4.5 + np.abs((yy - cy) / inner_h) ** 4.5) < 1.0
    return ring, interior


def row_interpolated_background(rgb: np.ndarray, content: np.ndarray) -> np.ndarray:
    """Glasfläche ohne Symbol: Je Bildzeile wird zwischen den sauberen Pixeln links und rechts des
    Inhalts gemischt. Das trifft Farbverlauf und Vignette gut, ohne Flecken oder Nähte."""
    height, width = content.shape
    result = rgb.astype(np.float32).copy()
    left = np.full((height, 3), np.nan, np.float32)
    right = np.full((height, 3), np.nan, np.float32)
    edges: dict[int, tuple[int, int]] = {}
    for y in range(height):
        xs = np.where(content[y])[0]
        if len(xs) == 0:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        a0 = max(0, x0 - 5)
        b0 = min(width - 1, x1 + 5)
        left[y] = rgb[y, max(0, a0 - 3) : a0 + 4].astype(np.float32).mean(axis=0)
        right[y] = rgb[y, max(0, b0 - 3) : b0 + 4].astype(np.float32).mean(axis=0)
        edges[y] = (a0, b0)
    for channel in range(3):
        for side in (left, right):
            valid = ~np.isnan(side[:, channel])
            if valid.sum() > 4:
                indices = np.where(valid)[0]
                side[:, channel] = np.interp(np.arange(height), indices, side[valid, channel])
                side[:, channel] = cv2.GaussianBlur(side[:, channel].reshape(-1, 1), (0, 0), 3.0).ravel()
    for y, (a0, b0) in edges.items():
        if b0 <= a0:
            continue
        t = np.linspace(0.0, 1.0, b0 - a0 + 1, dtype=np.float32)[:, None]
        result[y, a0 : b0 + 1] = left[y][None, :] * (1.0 - t) + right[y][None, :] * t
    return result


def blank_frame(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    ring, interior = ring_and_interior(rgba)
    rgb = rgba[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    ys, xs = np.where(interior)
    cx = (xs.min() + xs.max()) / 2.0
    cy = (ys.min() + ys.max()) / 2.0
    half_w = (xs.max() - xs.min()) / 2.0
    half_h = (ys.max() - ys.min()) / 2.0
    yy, xx = np.mgrid[0 : rgba.shape[0], 0 : rgba.shape[1]]
    # Nur die Mitte der Glasfläche: Am Rand leuchtet das Glas selbst hell und gehört nicht zum Symbol.
    core = (np.abs((xx - cx) / (half_w * 0.86)) ** 4.0 + np.abs((yy - cy) / (half_h * 0.93)) ** 4.0) < 1.0
    content = core & ((hsv[..., 2] > 160) | ((hsv[..., 1] > 130) & (hsv[..., 2] > 100)))
    content = ndi.binary_dilation(content, iterations=12) & core
    # Glas ist nahezu radialsymmetrisch (Mitte tief, Rand hell, unten etwas heller): eindimensionale Anpassung
    # an alle unverdeckten Pixel, ausgewertet nur unter dem Symbol.
    radius = (np.abs((xx - cx) / (half_w * 0.9)) ** 3.0 + np.abs((yy - cy) / (half_h * 0.9)) ** 3.0) ** (1.0 / 3.0)
    # Unter dem Symbol gibt es kaum Messpunkte nahe der Mitte: dort nicht über den Messbereich hinaus rechnen.
    radius = np.maximum(radius, 0.62)
    ny = np.clip((yy - cy) / half_h, -0.9, 0.9)
    features = np.stack([np.ones_like(radius), radius**2, radius**4, ny, ny * radius**2], axis=-1)
    known = interior & ~content
    pick = np.where(known.ravel())[0]
    rng = np.random.default_rng(3)
    pick = rng.choice(pick, size=min(15000, len(pick)), replace=False)
    flat_features = features.reshape(-1, features.shape[-1])
    background = rgb.astype(np.float32).copy()
    for channel in range(3):
        target = rgb[..., channel].reshape(-1)[pick].astype(np.float32)
        weights, *_ = np.linalg.lstsq(flat_features[pick], target, rcond=None)
        estimate = (flat_features @ weights).reshape(radius.shape)
        background[..., channel] = estimate
    blend = cv2.GaussianBlur(content.astype(np.float32), (0, 0), 4.0)[..., None]
    result = rgb.astype(np.float32) * (1.0 - blend) + np.clip(background, 0, 255) * blend
    out = rgba.copy()
    out[..., :3] = np.clip(result, 0, 255).astype(np.uint8)
    return out, np.where(blend > 0.001, np.clip(background, 0, 255) * blend + rgb * (1.0 - blend), rgb).astype(np.uint8)


def unify_glass_hue(frame: np.ndarray) -> np.ndarray:
    """Reste von Gold- und Rotschein aus den Quellsymbolen zurück ins Glasblau holen."""
    rgb = frame[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    hue = hsv[..., 0] * 2.0  # OpenCV: 0..180 -> Grad
    off = (hue < 190.0) | (hue > 232.0)
    off &= hsv[..., 2] < 170  # helle Ringpixel nicht anfassen
    off &= frame[..., 3] > 100
    hsv[..., 0] = np.where(off, 212.0 / 2.0, hsv[..., 0])
    hsv[..., 1] = np.where(off, np.maximum(hsv[..., 1], 190.0), hsv[..., 1])
    fixed = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
    out = frame.copy()
    out[..., :3] = fixed
    return out


def extract_icon(rgba: np.ndarray, background: np.ndarray, icon_box: tuple[int, int, int, int]):
    """Symbol als RGBA mit weichem Leuchten (Differenz zur geglätteten Glasfläche)."""
    x0, y0, x1, y1 = icon_box
    original = rgba[..., :3].astype(np.float32)
    # Nur Aufhellung zählt als Symbol (Leuchten addiert Licht); dunklere Reste der Rekonstruktion nicht.
    difference = np.clip(original - background.astype(np.float32), 0.0, None).max(axis=-1)
    alpha = np.clip((difference - 12.0) / 70.0, 0.0, 1.0)
    window = np.zeros_like(alpha)
    window[y0:y1, x0:x1] = 1.0
    alpha *= window
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.9)
    safe = np.maximum(alpha, 0.05)[..., None]
    color = np.clip((original - background * (1.0 - alpha[..., None])) / safe, 0, 255)
    out = np.dstack([color, alpha * 255.0]).astype(np.uint8)
    image = Image.fromarray(out, "RGBA")
    box = image.getbbox()
    if box is None:
        return image, (0, 0, 0)
    side = max(box[2] - box[0], box[3] - box[1]) + 40
    cx = (box[0] + box[2]) // 2
    cy = (box[1] + box[3]) // 2
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)), (0, 0))
    return square.resize((256, 256), Image.LANCZOS), (cx, cy, side)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET).convert("RGBA")
    layout: dict = {}
    for name in ("joystick_ring", "joystick_knob"):
        # Quadratisch um den hellen Kern zuschneiden, damit das Spiel Kern und Leuchten genau trifft.
        x0, x1 = PIECES[name]
        region = np.array(sheet.crop((max(0, x0 - PAD), ROW[0] - 4, min(sheet.width, x1 + PAD), ROW[1] + 4)))
        region = isolate_main_piece(region)
        ys, xs = np.where(region[..., 3] > 170)
        cx = (xs.min() + xs.max()) / 2.0
        cy = (ys.min() + ys.max()) / 2.0
        core = float(max(xs.max() - xs.min(), ys.max() - ys.min()))
        half = int(core / 2 + PAD)
        left, top = int(round(cx - half)), int(round(cy - half))
        box = (left, top, left + 2 * half, top + 2 * half)
        square = Image.fromarray(region).crop(box)
        square.save(OUT / f"{name}.png")
        layout[name] = {"core": core, "size": float(square.width)}
    frames: dict[str, np.ndarray] = {}
    backgrounds: dict[str, np.ndarray] = {}
    sources: dict[str, np.ndarray] = {}
    for name in ("gas", "brake", "boost", "item"):
        rgba = np.array(crop(sheet, name))
        sources[name] = rgba
        frames[name], backgrounds[name] = blank_frame(rgba)
    height = min(frame.shape[0] for frame in frames.values())
    width = min(frame.shape[1] for frame in frames.values())
    stack = np.stack([frame[:height, :width].astype(np.float32) for frame in frames.values()])
    frame = np.median(stack, axis=0).astype(np.uint8)
    frame = unify_glass_hue(frame)
    Image.fromarray(frame, "RGBA").save(OUT / "frame.png")
    layout["frame"] = [width, height]
    for name in ("gas", "brake", "boost", "item"):
        rgba = sources[name][:height, :width]
        icon, (cx, cy, side) = extract_icon(rgba, backgrounds[name][:height, :width], (0, 0, width, int(height * 0.66)))
        icon.save(OUT / f"icon_{name}.png")
        layout[name] = {"center": [cx / width, cy / height], "size": side / width}
        print(name, icon.size, layout[name])
    (OUT / "layout.json").write_text(json.dumps(layout, indent=2))
    print("fertig:", OUT)


if __name__ == "__main__":
    main()
