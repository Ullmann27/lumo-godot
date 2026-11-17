"""Counterexamples for evidence acceptance; these do not execute a game."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_memory_native_authority import verify_capture, verify_results


def declared_results():
    request = {"token": "first", "roundId": "initial", "revision": 1, "sequence": 1, "action": "flip"}
    wallet = {"stars": 2, "xp": 16, "ids": ["completed-reward"]}
    authority = {
        "success": True, "award_calls": 1, "wallet": wallet,
        "tokens": ["first", "restored", "paid"], "closed_tokens": ["first", "restored", "paid"],
        "initial_round": "initial",
        "unfinished_reopen": {"roundId": "initial", "restoredRoundId": "initial", "paused": True,
                              "remainingMs": 550, "oldToken": "first", "newToken": "restored"},
        "completed_round": {"id": "completed", "rewarded": True,
                            "rules": {"kindPairs": 4, "lumoPairs": 0, "kindMoves": 4}},
        "paid_reopen": {"completedRoundId": "completed", "newRoundId": "next",
                        "oldToken": "restored", "newToken": "paid", "difficulty": "leicht", "pack": "alle",
                        "best": {"leicht": 4, "schwer": 17}},
        "bot_phases": ["botFirst", "botSecond", "resolve"],
        "requests": [{"raw": json.dumps(request), "request": request, "ack": 1}],
    }
    renderer = {"success": True, "failures": [], "mode": "production_dart_disk_authority",
                "return_observed": 3, "initial_round": "initial", "completed_round": "completed",
                "checks": 1, "inputs": [{"label": "explicit unit fixture"}],
                "captures": [], "motion_frames": [], "display_driver": "headless", "capture": False}
    return authority, renderer, deepcopy(renderer), deepcopy(wallet)


class MemoryEvidenceCounterexamples(unittest.TestCase):
    def evaluate(self, values, capture=False):
        return verify_results(*values, Path("unused-headless-unit-fixture"), capture)

    def test_declared_headless_contract_is_not_android_or_render_evidence(self):
        result = self.evaluate(declared_results())
        self.assertEqual(result["captures"], 0)
        self.assertEqual(result["qa_award_calls"], 1)
        self.assertNotIn("android", result)

    def test_reward_callback_and_durable_ledger_counterexamples(self):
        for field, value in (("award_calls", 2), ("success", False)):
            with self.subTest(field=field):
                values = declared_results()
                values[0][field] = value
                with self.assertRaises(ValueError):
                    self.evaluate(values)
        values = declared_results()
        values[3]["ids"] = ["another-round"]
        with self.assertRaises(ValueError):
            self.evaluate(values)
        values = declared_results()
        values[0]["wallet"]["stars"] = values[3]["stars"] = 2.0
        with self.assertRaises(ValueError):
            self.evaluate(values)

    def test_original_request_integer_ack_and_token_counterexamples(self):
        for key, value in (("revision", 1.0), ("sequence", 1.0), ("token", "unrelated")):
            with self.subTest(key=key):
                values = declared_results()
                row = values[0]["requests"][0]
                row["request"][key] = value
                row["raw"] = json.dumps(row["request"])
                with self.assertRaises(ValueError):
                    self.evaluate(values)
        for field, value in (("ack", 0), ("raw", "{}")):
            values = declared_results()
            values[0]["requests"][0][field] = value
            with self.assertRaises(ValueError):
                self.evaluate(values)

    def test_unfinished_and_completed_rounds_cannot_be_substituted(self):
        for key, value in (("remainingMs", 850), ("restoredRoundId", "other-child"), ("paused", False)):
            with self.subTest(key=key):
                values = declared_results()
                values[0]["unfinished_reopen"][key] = value
                with self.assertRaises(ValueError):
                    self.evaluate(values)
        values = declared_results()
        values[0]["paid_reopen"]["newRoundId"] = "completed"
        with self.assertRaises(ValueError):
            self.evaluate(values)

    def test_return_report_and_renderer_requirements_cannot_be_skipped(self):
        values = declared_results()
        values[1]["return_observed"] = values[2]["return_observed"] = 2
        with self.assertRaises(ValueError):
            self.evaluate(values)
        values = declared_results()
        values[2]["checks"] = 999
        with self.assertRaises(ValueError):
            self.evaluate(values)
        with self.assertRaises(ValueError):
            self.evaluate(declared_results(), capture=True)

    def test_capture_requires_actual_bytes_dimensions_and_current_layout(self):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) +
               chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00\xff")) + chunk(b"IEND", b""))
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            (folder / "unit.png").write_bytes(png)
            entry = {"file": "unit.png", "width": 1, "height": 1, "sha256": hashlib.sha256(png).hexdigest(),
                     "token": "own", "roundId": "current", "revision": 3}
            observed = {"settled": True, "token": "own", "roundId": "current", "revision": 3}
            (folder / "unit.layout.json").write_text(json.dumps(observed))
            self.assertEqual(verify_capture(folder, entry, layout=True), entry["sha256"])
            observed["revision"] = 2
            (folder / "unit.layout.json").write_text(json.dumps(observed))
            with self.assertRaises(ValueError):
                verify_capture(folder, entry, layout=True)
            (folder / "unit.png").write_bytes(png + b"changed")
            with self.assertRaises(ValueError):
                verify_capture(folder, entry, layout=False)
            entry["file"] = "../outside.png"
            with self.assertRaises(ValueError):
                verify_capture(folder, entry, layout=False)


if __name__ == "__main__":
    unittest.main()
