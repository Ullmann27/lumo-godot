"""Regression coverage for the Android garage -> 3D race image gate."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

SCRIPT = Path(__file__).resolve().parents[1] / "check_android_frame.py"
SPEC = importlib.util.spec_from_file_location("android_frame", SCRIPT)
frame = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(frame)


def rgb_png(width=96, height=48, *, race=False, tiny_change=False):
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            if race and x > width // 4:
                rgb = (22, 191, 118)
            else:
                rgb = (83, 61, 167)
            if tiny_change and x == width // 2 and y == height // 2:
                rgb = (255, 255, 255)
            row.extend(rgb)
        rows.append(bytes(row))
    body = zlib.compress(b"".join(rows))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", body) + chunk(b"IEND", b""))


class AndroidRaceTransitionTest(unittest.TestCase):
    def test_identical_garage_fails_even_if_nonblank(self):
        menu = rgb_png()
        with self.assertRaisesRegex(ValueError, "still resembles"):
            frame.validate_race_transition(menu, menu)

    def test_one_animated_pixel_does_not_count_as_racing(self):
        with self.assertRaisesRegex(ValueError, "still resembles"):
            frame.validate_race_transition(rgb_png(), rgb_png(tiny_change=True))

    def test_actual_large_scene_change_passes(self):
        result = frame.validate_race_transition(rgb_png(), rgb_png(race=True))
        self.assertGreater(result["changed_fraction"], 0.5)

    def test_size_mismatch_cannot_pass(self):
        with self.assertRaisesRegex(ValueError, "same Android viewport"):
            frame.validate_race_transition(rgb_png(), rgb_png(width=128))


if __name__ == "__main__":
    unittest.main()
