import struct
import sys
from pathlib import Path
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_android_frame import validate_frame


def picture(width, height, clip=False):
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data))
    row = bytearray()
    for x in range(width):
        row.extend((0, 0, 0) if clip and x >= width // 2 else (80, 180, 200))
    body = zlib.compress((b'\0' + row) * height)
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', body) + chunk(b'IEND', b'')


class AndroidFrameTest(unittest.TestCase):
    def test_accepts_filled_landscape(self):
        self.assertEqual(validate_frame(picture(640, 320))['size'], [640, 320])

    def test_rejects_half_black_regression(self):
        with self.assertRaisesRegex(ValueError, 'Black/clipped'):
            validate_frame(picture(640, 320, clip=True))

    def test_rejects_portrait_race(self):
        with self.assertRaisesRegex(ValueError, 'landscape'):
            validate_frame(picture(320, 640))
