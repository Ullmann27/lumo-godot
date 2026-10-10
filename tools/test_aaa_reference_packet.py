"""Negative controls for the offline handoff, without Blender or network."""
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import aaa_reference_packet as packet


class ReferencePacketTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.png = self.folder / "menu.png"
        self.png.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 640, 360))
        self.row = {
            "source_commit": "a" * 40, "clean_tracked_source": True,
            "tracked_differences": "", "image": "menu.png", "size": [640, 360],
        }
        self.git = patch.object(packet, "git", return_value="")
        self.git.start()
        self.addCleanup(self.git.stop)

    def check(self):
        (self.folder / "capture.json").write_text(json.dumps([self.row]))
        return packet.verified_capture(self.folder, self.folder, "capture.json", "godot")

    def test_valid_capture_is_not_art_or_device_approval(self):
        row = self.check()[0]
        self.assertEqual(row["pixel_size"], [640, 360])
        self.assertFalse(row["physical_android_device"])
        self.assertIn("Not approved", row["visual_acceptance"])

    def test_missing_commit(self):
        self.row["source_commit"] = None
        with self.assertRaises(ValueError):
            self.check()

    def test_dirty_capture(self):
        self.row["tracked_differences"] = "scripts/games/kart_vehicle.gd"
        with self.assertRaises(ValueError):
            self.check()

    def test_dimension_mismatch(self):
        self.row["size"] = [1280, 720]
        with self.assertRaises(ValueError):
            self.check()

    def test_not_png(self):
        self.png.write_bytes(b"not a screenshot")
        with self.assertRaises(ValueError):
            self.check()

    def test_path_traversal(self):
        self.row["image"] = "../menu.png"
        with self.assertRaises(ValueError):
            self.check()

    def test_stale_runtime(self):
        with patch.object(packet, "git", side_effect=["", "scripts/games/kart_vehicle.gd"]):
            with self.assertRaises(ValueError):
                self.check()


if __name__ == "__main__":
    unittest.main()
