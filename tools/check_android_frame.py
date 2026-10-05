"""Reject blank/clipped real Sonnenhafen Android screenshots.

Uses only the standard library. Supports Android screencap's 8-bit RGB/RGBA PNGs.
This checks coverage and rendered detail, not FPS or complete visual quality.
"""
from pathlib import Path
import struct
import sys
import zlib


def pixels_from_png(data):
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Invalid PNG signature')
    offset, packed = 8, bytearray()
    width = height = channels = 0
    while offset + 12 <= len(data):
        length = struct.unpack_from('>I', data, offset)[0]
        tag = data[offset + 4:offset + 8]
        body = data[offset + 8:offset + 8 + length]
        if tag == b'IHDR':
            width, height, depth, colour, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if depth != 8 or colour not in (2, 6) or interlace:
                raise ValueError('Expected non-interlaced 8-bit RGB/RGBA PNG')
            channels = 3 if colour == 2 else 4
        elif tag == b'IDAT':
            packed.extend(body)
        offset += length + 12
    stride = width * channels
    raw = zlib.decompress(packed)
    if not channels or len(raw) != (stride + 1) * height:
        raise ValueError('Invalid PNG pixel data length')
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if filter_type not in range(5):
            raise ValueError('Invalid PNG row filter')
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up = previous[x]
            corner = previous[x - channels] if x >= channels else 0
            predictor = 0
            if filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                p = left + up - corner
                distances = (abs(p - left), abs(p - up), abs(p - corner))
                predictor = (left, up, corner)[distances.index(min(distances))]
            row[x] = (row[x] + predictor) & 255
        rows.append(row)
        previous = row
    return width, height, channels, rows


def validate_frame(data):
    width, height, channels, rows = pixels_from_png(data)
    if width <= height or width < 320 or height < 160:
        raise ValueError(f'Expected a landscape race frame; got {width}x{height}')
    fractions, detail = [], []
    # Exclude Android's status/navigation bars and inspect each third of the image.
    for third in range(3):
        count = visible = bright = 0
        colours = set()
        for y in range(height // 8, height * 7 // 8, 3):
            for x in range(width * third // 3 + 3, width * (third + 1) // 3 - 3, 3):
                at = x * channels
                rgb = rows[y][at:at + 3]
                visible += max(rgb) > 24
                bright += max(rgb) >= 80
                colours.add(tuple(value // 16 for value in rgb))
                count += 1
        fraction = visible / max(1, count)
        fractions.append(round(fraction, 3))
        if fraction < 0.65:
            raise ValueError(f'Black/clipped race region in third {third + 1}: {fraction:.1%} visible')
        # A full-size clear colour/splash can satisfy coverage while rendering no game.
        bright_fraction = bright / max(1, count)
        if len(colours) < 8 or bright_fraction < 0.2:
            raise ValueError(f'Blank race region in third {third + 1}: '
                             f'{len(colours)} colour bins, {bright_fraction:.1%} bright')
        detail.append({'colour_bins': len(colours), 'bright_fraction': round(bright_fraction, 3)})
    return {'size': [width, height], 'visible_fractions': fractions, 'detail': detail}


if __name__ == '__main__':
    try:
        print('[AndroidFrame] PASS:', validate_frame(Path(sys.argv[1]).read_bytes()))
    except (ValueError, zlib.error, OSError, IndexError) as error:
        print('[AndroidFrame] FAIL:', error, file=sys.stderr)
        raise SystemExit(1)
