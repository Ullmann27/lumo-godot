"""Deterministic, secure, mobile-budgeted procedural GLB production tests."""
import importlib.util
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "ai3d_factory.py"
spec = importlib.util.spec_from_file_location("ai3d_factory", MODULE_PATH)
factory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(factory)

DEFAULT = {
    "asset_id": "sonnenhafen_biolum_cavern_crystals",
    "recipe": "crystal_cluster",
    "seed": 1975,
    "height_m": 4.2,
    "radius_m": 0.72,
    "count": 9,
    "max_triangles": 520,
}


def decoded_manifest(glb: bytes):
    magic, version, total = struct.unpack_from("<4sII", glb)
    assert magic == b"glTF" and version == 2 and total == len(glb)
    json_size, tag = struct.unpack_from("<I4s", glb, 12)
    assert tag == b"JSON"
    tree = json.loads(glb[20:20 + json_size])
    bin_offset = 20 + json_size
    data_size, tag = struct.unpack_from("<I4s", glb, bin_offset)
    assert tag == b"BIN\0"
    assert bin_offset + 8 + data_size == len(glb)
    return tree


class LumoProceduralAssetFactoryTests(unittest.TestCase):
    def test_mobile_variant_reduces_real_geometry_preserving_shard_tips(self):
        high, high_report = factory.glb_bytes(DEFAULT)
        mobile, mobile_report = factory.glb_bytes(DEFAULT, profile="mobile")
        self.assertEqual(mobile_report["triangles"], 144)
        self.assertLess(len(mobile), len(high) * 0.6)
        self.assertEqual(mobile_report["profile"], "mobile")
        self.assertEqual(mobile_report["bbox_max_m"][1], high_report["bbox_max_m"][1])
        high_surfaces = factory.generate_geometry(DEFAULT)
        low_surfaces = factory.generate_geometry(DEFAULT, profile="mobile")
        for a, b in zip(high_surfaces, low_surfaces):
            # One tip per shard: the same cluster composition at both detail levels.
            high_tips = {max(a.positions[i:i + 108], key=lambda p: p[1])
                         for i in range(0, len(a.positions), 108)}
            self.assertTrue(high_tips <= set(b.positions))
        self.assertEqual(factory.glb_bytes(DEFAULT, profile="mobile")[0], mobile)

    def test_binary_validator_checks_geometry_not_just_json_or_hash(self):
        original, report = factory.glb_bytes(DEFAULT)
        self.assertEqual(factory.validate_glb(original)["triangles"], 324)
        doc = decoded_manifest(original)
        json_size = struct.unpack_from("<I", original, 12)[0]
        binary_start = 28 + json_size
        primitive = doc["meshes"][0]["primitives"][0]
        for attribute, value, packing in (("POSITION", float("nan"), "f"),
                                          ("NORMAL", 0.0, "f"),
                                          ("indices", 65535, "H")):
            accessor_id = primitive["indices"] if attribute == "indices" else primitive["attributes"][attribute]
            accessor = doc["accessors"][accessor_id]
            offset = binary_start + doc["bufferViews"][accessor["bufferView"]]["byteOffset"]
            broken = bytearray(original)
            struct.pack_into("<" + packing, broken, offset, value)
            if attribute == "NORMAL":
                struct.pack_into("<fff", broken, offset, 0, 0, 0)
            with self.subTest(attribute=attribute), self.assertRaises(ValueError):
                factory.validate_glb(bytes(broken))
        with self.assertRaises(ValueError):
            factory.validate_glb(original[:-4])
        with self.assertRaisesRegex(ValueError, "manifest"):
            factory.verify_manifest(original, dict(report, triangles=1))

    def test_variant_build_is_reproducible_and_manifest_verifiable(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "input.json"
            source.write_text(json.dumps(DEFAULT), encoding="utf-8")
            manifest = factory.build_variants(source, root / "output")
            self.assertEqual(set(manifest["variants"]), {"high", "mobile"})
            snapshots = {p.name: p.read_bytes() for p in (root / "output").iterdir()}
            factory.build_variants(source, root / "output")
            self.assertEqual(snapshots, {p.name: p.read_bytes() for p in (root / "output").iterdir()})
            for profile, report in manifest["variants"].items():
                data = (root / "output" / report["file_name"]).read_bytes()
                self.assertEqual(factory.verify_manifest(data, report)["triangles"], report["triangles"])
                self.assertEqual(report["profile"], profile)

    def test_glb_v2_has_normals_uv_materials_16bit_indices_and_ground_pivot(self):
        output, evidence = factory.glb_bytes(DEFAULT)
        doc = decoded_manifest(output)
        self.assertEqual(doc["asset"]["version"], "2.0")
        self.assertEqual(len(doc["scenes"]), 1)
        self.assertEqual(len(doc["materials"]), 2)
        self.assertEqual(len(doc["meshes"][0]["primitives"]), 2)
        self.assertEqual(evidence["triangles"], 324)
        self.assertEqual(evidence["ground_pivot_m"], 0.0)
        self.assertAlmostEqual(evidence["bbox_max_m"][1], DEFAULT["height_m"], places=6)
        self.assertLessEqual(evidence["triangles"], DEFAULT["max_triangles"])
        for part in doc["meshes"][0]["primitives"]:
            self.assertEqual(part["mode"], 4)
            self.assertTrue({"POSITION", "NORMAL", "TEXCOORD_0"} <= set(part["attributes"]))
            index_access = doc["accessors"][part["indices"]]
            self.assertEqual(index_access["componentType"], 5123)
            self.assertEqual(index_access["count"] % 3, 0)

    def test_identical_spec_generates_bitwise_identical_binary(self):
        a, report = factory.glb_bytes(DEFAULT)
        b, _ = factory.glb_bytes(dict(DEFAULT))
        self.assertEqual(a, b)
        self.assertEqual(report["sha256"], factory.hashlib.sha256(b).hexdigest())

    def test_changed_seed_yields_a_different_real_mesh(self):
        b, _ = factory.glb_bytes(DEFAULT)
        altered = dict(DEFAULT, seed=2026)
        a, _ = factory.glb_bytes(altered)
        self.assertNotEqual(a, b)

    def test_budget_failure_is_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "triangle"):
            factory.glb_bytes(dict(DEFAULT, max_triangles=200))

    def test_unapproved_code_and_pathlike_identifiers_are_rejected(self):
        for identity in ("../escape", "a", "fake.png", "TOO_UPPER", "folder/name"):
            with self.subTest(identity=identity):
                with self.assertRaises(ValueError):
                    factory.validate_spec(dict(DEFAULT, asset_id=identity))
        with self.assertRaises(ValueError):
            factory.validate_spec(dict(DEFAULT, recipe="python_exec"))

    def test_boolean_nan_infinity_and_unknown_fields_are_rejected(self):
        for broken in (
            dict(DEFAULT, count=True),
            dict(DEFAULT, height_m=float("nan")),
            dict(DEFAULT, radius_m=float("inf")),
            dict(DEFAULT, extra="danger"),
        ):
            with self.subTest(broken=broken):
                with self.assertRaises(ValueError):
                    factory.validate_spec(broken)

    def test_output_hash_report_and_repeated_generation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "input.json"
            source.write_text(json.dumps(DEFAULT), encoding="utf-8")
            report = factory.build(source, root / "output")
            glb = root / "output" / (DEFAULT["asset_id"] + ".glb")
            report_json = root / "output" / (DEFAULT["asset_id"] + ".json")
            self.assertTrue(glb.exists())
            self.assertEqual(report["sha256"], factory.hashlib.sha256(glb.read_bytes()).hexdigest())
            self.assertEqual(report_json.stat().st_size > 0, True)
            self.assertEqual(factory.build(source, root / "output")["sha256"], report["sha256"])

    def test_symlink_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "spec.json"
            source.write_text(json.dumps(DEFAULT), encoding="utf-8")
            output = root / "render"
            output.mkdir()
            victim = root / "protected.txt"
            victim.write_text("never overwrite", encoding="utf-8")
            (output / (DEFAULT["asset_id"] + ".glb")).symlink_to(victim)
            with self.assertRaisesRegex(ValueError, "symlink"):
                factory.build(source, output)
            self.assertEqual(victim.read_text(), "never overwrite")


if __name__ == "__main__":
    unittest.main()
