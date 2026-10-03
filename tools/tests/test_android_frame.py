import struct
import sys
from pathlib import Path
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_android_frame import validate_frame


def picture(width, height, clip=False, solid=None):
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data))
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            colour = solid or (80 + x % 150, 80 + y % 150, 100 + (x + y) % 140)
            rows.extend((0, 0, 0) if clip and x >= width // 2 else colour)
    body = zlib.compress(rows)
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', body) + chunk(b'IEND', b'')


class AndroidFrameTest(unittest.TestCase):
    def test_accepts_detailed_landscape(self):
        self.assertEqual(validate_frame(picture(640, 320))['size'], [640, 320])

    def test_rejects_half_black_regression(self):
        with self.assertRaisesRegex(ValueError, 'Black/clipped'):
            validate_frame(picture(640, 320, clip=True))

    def test_rejects_portrait_race(self):
        with self.assertRaisesRegex(ValueError, 'landscape'):
            validate_frame(picture(320, 640))

    def test_rejects_empty_godot_clear_colour_regression(self):
        with self.assertRaisesRegex(ValueError, 'Blank'):
            validate_frame(picture(640, 320, solid=(20, 15, 31)))

    def test_rejects_bright_empty_loading_surface(self):
        with self.assertRaisesRegex(ValueError, 'Blank'):
            validate_frame(picture(640, 320, solid=(180, 220, 200)))
