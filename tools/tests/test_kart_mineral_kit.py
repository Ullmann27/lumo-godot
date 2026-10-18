"""Actual GLB contract and corrupt-buffer checks for the original cavern kit."""
import importlib.util
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("mineral_verifier", ROOT / "tools/art/verify_kart_mineral_kit.py")
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)
KIT = ROOT / "assets/kart/cavern/mineral_kit"


class KartMineralKitTests(unittest.TestCase):
    def test_imported_bytes_fit_lod_budget_and_keep_six_distinct_silhouettes(self):
        report = VERIFIER.verify(KIT)
        self.assertEqual(len(report["assets"]), 6)
        manifest = json.loads((KIT / "mineral_kit.json").read_text())
        hashes = set()
        for asset in manifest["assets"].values():
            high, mobile = asset["variants"]["high"], asset["variants"]["mobile"]
            hashes.add(high["sha256"])
            self.assertLess(mobile["bytes"], high["bytes"] * 0.7)
            self.assertGreater(high["triangles"], 200)
            self.assertEqual(high["materials"], 1)
            self.assertEqual(mobile["materials"], 1)
        self.assertEqual(len(hashes), 6)

    def test_nonfinite_position_is_rejected_from_the_binary_buffer(self):
        data = bytearray((KIT / "crystal_fan_mobile.glb").read_bytes())
        json_length = struct.unpack_from("<I", data, 12)[0]
        doc = json.loads(data[20:20 + json_length])
        index = doc["meshes"][0]["primitives"][0]["attributes"]["POSITION"]
        access = doc["accessors"][index]
        view = doc["bufferViews"][access["bufferView"]]
        offset = 28 + json_length + view.get("byteOffset", 0) + access.get("byteOffset", 0)
        struct.pack_into("<f", data, offset, float("nan"))
        with self.assertRaisesRegex(ValueError, "non-finite"):
            VERIFIER.inspect_glb(bytes(data))

    def test_truncated_glb_is_rejected(self):
        data = (KIT / "hanging_canopy_high.glb").read_bytes()
        with self.assertRaisesRegex(ValueError, "header"):
            VERIFIER.inspect_glb(data[:-4])

    def test_uv_like_data_in_color_buffer_is_rejected(self):
        data = bytearray((KIT / "strata_shelf_mobile.glb").read_bytes())
        json_length = struct.unpack_from("<I", data, 12)[0]
        doc = json.loads(data[20:20 + json_length])
        index = doc["meshes"][0]["primitives"][0]["attributes"]["COLOR_0"]
        access = doc["accessors"][index]
        self.assertEqual(access["componentType"], 5126)
        view = doc["bufferViews"][access["bufferView"]]
        offset = 28 + json_length + view.get("byteOffset", 0) + access.get("byteOffset", 0)
        struct.pack_into("<fff", data, offset, -0.4, 0.18, -0.3)
        with self.assertRaisesRegex(ValueError, "grayscale"):
            VERIFIER.inspect_glb(bytes(data))


if __name__ == "__main__":
    unittest.main()
