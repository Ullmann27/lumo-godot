"""Negative controls for the evidence checker; synthetic PNGs are test data only."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from verify_discovery_rasters import raster_roster, read_json, verify


class DiscoveryEvidenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="lumo-discovery-checker-")
        cls.directory = Path(cls.temp.name)
        cls.captures = cls.directory / "captures"
        entries = []
        for relative, size in raster_roster().items():
            path = cls.captures / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            # Deliberately synthetic, two-color control images; no runtime claim.
            image = Image.new("RGB", size, (30, 60, 90))
            image.putpixel((0, 0), (200 if "-complete" in relative else 120, 40, 20))
            image.save(path)
            if relative.startswith("wonder/"):
                name = Path(relative).name
                complete = "-complete" in name
                kind = "bridge_ten" if "numbers" in name else ("bridge_hundred" if "hundreds" in name else ("syllables" if "syllables" in name else "plant_parts"))
                entries.append({"file": name, "size": list(size), "headless": False,
                                "actual_production_scene": "res://scenes/learning/learning_world.tscn",
                                "kind": kind, "complete": complete,
                                "garden": {"kind": kind, "flowers": 5, "petals": 35,
                                           "geometry_batches": 7, "writes_learning_state": False,
                                           "reduced_motion": True,
                                           "progress": 1.0 if complete else (0.2 if "one-step" in name else 0.0)}})
        cls.report = {"checks": 136, "failures": 0, "captures": entries}
        cls.report_path = cls.captures / "wonder/captures.json"

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.report_path.write_text(json.dumps(self.report))

    def test_complete_exact_roster(self):
        records = verify(self.directory)
        self.assertEqual(len(records), 38)
        counts = {group: sum(r["path"].startswith("captures/" + group + "/") for r in records)
                  for group in ("hub", "learning", "wonder")}
        self.assertEqual(counts, {"hub": 2, "learning": 25, "wonder": 11})

    def test_missing_or_extra_image(self):
        original = self.captures / "hub/hub_portrait.png"
        content = original.read_bytes()
        original.unlink()
        try:
            with self.assertRaises(ValueError):
                verify(self.directory)
        finally:
            original.write_bytes(content)
        extra = self.captures / "stale.png"
        extra.write_bytes(content)
        try:
            with self.assertRaises(ValueError):
                verify(self.directory)
        finally:
            extra.unlink()

    def test_bad_raster_or_nonoriginal_file(self):
        path = self.captures / "hub/hub_portrait.png"
        content = path.read_bytes()
        for failure in ("dimensions", "format", "uniform", "symlink"):
            with self.subTest(failure=failure):
                try:
                    if failure == "dimensions":
                        Image.new("RGB", (5, 5)).save(path)
                    elif failure == "format":
                        Image.new("RGB", (1080, 1920)).save(path, format="JPEG")
                    elif failure == "uniform":
                        Image.new("RGB", (1080, 1920)).save(path)
                    else:
                        path.unlink()
                        path.symlink_to(self.captures / "hub/hub_fold_landscape.png")
                    with self.assertRaises(ValueError):
                        verify(self.directory)
                finally:
                    if path.is_symlink():
                        path.unlink()
                    path.write_bytes(content)

    def test_unchanged_completion_image(self):
        path = self.captures / "learning/math-complete-1280x720.png"
        content = path.read_bytes()
        path.write_bytes((self.captures / "learning/math-start-1280x720.png").read_bytes())
        try:
            with self.assertRaises(ValueError):
                verify(self.directory)
        finally:
            path.write_bytes(content)

    def test_false_or_incomplete_geometry_report(self):
        mutations = [
            ("checks", 135), ("checks", True), ("failures", 1),
            ("failures", False), ("captures", self.report["captures"][:-1]),
            ("captures", self.report["captures"][:-1] + [self.report["captures"][0]]),
        ]
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                report = copy.deepcopy(self.report)
                report[key] = value
                self.report_path.write_text(json.dumps(report))
                with self.assertRaises(ValueError):
                    verify(self.directory)

    def test_false_production_state(self):
        mutations = [
            ("headless", True), ("headless", 0), ("complete", 0),
            ("actual_production_scene", "res://scenes/games/game_hub.tscn"),
            ("kind", "invalid"), ("size", [1280, True]),
        ]
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                report = copy.deepcopy(self.report)
                report["captures"][0][key] = value
                self.report_path.write_text(json.dumps(report))
                with self.assertRaises(ValueError):
                    verify(self.directory)

    def test_false_task_progress_or_budget(self):
        mutations = [
            ("progress", True), ("progress", 0.5), ("progress", float("nan")),
            ("writes_learning_state", True), ("reduced_motion", False),
            ("flowers", 6), ("petals", 34), ("geometry_batches", 8),
            ("kind", "invalid"),
        ]
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                report = copy.deepcopy(self.report)
                report["captures"][0]["garden"][key] = value
                self.report_path.write_text(json.dumps(report))
                with self.assertRaises(ValueError):
                    verify(self.directory)

    def test_ambiguous_or_nonfinite_json(self):
        for content in ('{"checks":136,"checks":1}', '{"value":NaN}', '[]'):
            with self.subTest(content=content):
                self.report_path.write_text(content)
                with self.assertRaises(ValueError):
                    read_json(self.report_path)


if __name__ == "__main__":
    unittest.main()
