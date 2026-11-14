"""Focused counterexamples for Discovery originals; all generated data are synthetic."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from PIL import Image

TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
import verify_discovery_connections as gate
import collect_discovery_connections as collector
from tools.tests import test_discovery_rasters as producer_fixtures


class DiscoveryConnectionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Reuse the unchanged Producer's explicitly synthetic 38/2 test fixture.
        producer_fixtures.DiscoveryEvidenceTest.setUpClass()
        producer_fixtures.DiscoveryEvidenceTest().setUp()
        cls.fixture = producer_fixtures.DiscoveryEvidenceTest.directory

    @classmethod
    def tearDownClass(cls):
        producer_fixtures.DiscoveryEvidenceTest.tearDownClass()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="discovery-connections-contract-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "originals"
        shutil.copytree(self.fixture, self.root)
        (self.root / "helpers").mkdir()
        sources = {}
        for name in (*gate.HELPERS, "collect_discovery_connections.py", "verify_discovery_connections.py"):
            data = (TOOLS / name).read_bytes()
            (self.root / "helpers" / name).write_bytes(data)
            sources["tools/" + name] = data
        sources["scripts/synthetic-source.gd"] = b"# Explicitly synthetic source; no engine was run.\n"
        tracked = [{"path": path, "git_blob": gate.identity(data)["git_blob"], "mode": "100644",
                    "actual_blob": gate.identity(data)["git_blob"], "skip_worktree": False,
                    "materialized": True, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                   for path, data in sorted(sources.items())]
        entries = [{key: row[key] for key in ("path", "mode", "git_blob")} for row in tracked]
        self.tree = gate.tree_id(entries)
        commit = ("tree " + self.tree + "\nauthor Synthetic Test <test@example.invalid> 1 +0000\n"
                  "committer Synthetic Test <test@example.invalid> 1 +0000\n\nSynthetic verifier fixture only.\n").encode()
        self.sha = gate.object_id("commit", commit)
        (self.root / "source-commit.raw").write_bytes(commit)
        listing = b"".join((entry["mode"] + " blob " + entry["git_blob"] + "\t" + entry["path"]).encode() + b"\0"
                           for entry in entries)
        index = b"Synthetic index bytes; explicitly not a Git or engine acceptance.\n"
        self.inventory = {"schema": 1, "head": self.sha, "tree": self.tree,
                          "index_sha256": hashlib.sha256(index).hexdigest(),
                          "tracked": tracked, "untracked_import_inventory": []}
        for phase, suffix in (("before", ""), ("after", "-after")):
            for kind, value in (("sha", self.sha), ("tree", self.tree)):
                (self.root / ("source-" + kind + suffix + ".txt")).write_text(value + "\n")
            (self.root / ("source-dirty" + suffix + ".txt")).write_bytes(b"")
            (self.root / ("source-tree-" + phase + ".bin")).write_bytes(listing)
            (self.root / ("source-index-" + phase + ".bin")).write_bytes(index)
            self.save("source-inventory-" + phase + ".json", self.inventory)
        self.context = {"schema": 1, "native_source": self.sha, "native_tree": self.tree,
                        "project": "/synthetic/native", "output": "/synthetic/evidence/discovery",
                        "output_was_absent": True, "godot": "/synthetic/bin/godot",
                        "python": "/synthetic/venv/bin/python", "display": "",
                        "renderer_prefix": ["/usr/bin/xvfb-run", "-a", "-s", "-screen 0 2560x2560x24"],
                        "started_monotonic_ns": 1}
        self.save("collection-context.json", self.context)
        self.save("engine-binary.json", {"path": self.context["godot"], "bytes": 10, "sha256": "a" * 64})
        (self.root / "engine.txt").write_text(gate.ENGINE + "\n")
        (self.root / "logs").mkdir()
        self.calls = {"schema": 1, "completed": True, "finished_monotonic_ns": 300, "calls": []}
        for plan in gate.invocation_plan(self.context):
            call = {**plan, "started_monotonic_ns": plan["ordinal"] * 10,
                    "finished_monotonic_ns": plan["ordinal"] * 10 + 1,
                    "returncode": 0, "outer_timeout": False}
            self.calls["calls"].append(call)
            # This is a synthetic transcript, never described as a real engine run.
            text = "Godot Engine v" + gate.ENGINE + " - https://godotengine.org\n" + plan["marker"] + "\n"
            for field in ("log", "runner_log"):
                (self.root / plan[field]).write_text(text)
        self.save("invocations.json", self.calls)
        (self.root / "results.tsv").write_text("probe\tmode\tresult\n" + "".join(
            f"{probe}\t{mode}\tPASS\n" for probe, mode, _, _ in gate.PROBES))

    def save(self, relative, value):
        (self.root / relative).write_text(json.dumps(value, indent=2) + "\n")

    def verify(self):
        return gate.verify(self.root, expected_native_sha=self.sha, expected_native_tree=self.tree, write=False)

    def rewrite_log(self, transform, ordinal=0):
        call = self.calls["calls"][ordinal]
        original = (self.root / call["log"]).read_text()
        for field in ("log", "runner_log"):
            (self.root / call[field]).write_text(transform(original))

    def test_complete_originals_replay_is_read_only(self):
        def hashes():
            return {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in self.root.rglob("*") if p.is_file()}
        before = hashes()
        result = self.verify()
        self.assertEqual((result["probe_count"], result["png_count"], result["report_count"]), (10, 38, 2))
        self.assertEqual(before, hashes())
        self.assertFalse(result["physical_android_fps_measured"])
        self.assertFalse(result["complete_native52_acceptance"])
        self.save(gate.MANIFEST, result)
        before = hashes()
        self.assertEqual(self.verify(), result)
        self.assertEqual(before, hashes())

    def test_missing_or_unfinished_engine_call(self):
        for change in ("missing", "unfinished", "not_complete"):
            with self.subTest(change=change):
                calls = copy.deepcopy(self.calls)
                if change == "missing":
                    calls["calls"].pop()
                elif change == "unfinished":
                    calls["calls"][0]["finished_monotonic_ns"] = None
                else:
                    calls["completed"] = False
                self.save("invocations.json", calls)
                with self.assertRaises(ValueError):
                    self.verify()

    def test_duplicate_or_reordered_engine_call(self):
        for duplicate in (False, True):
            calls = copy.deepcopy(self.calls)
            calls["calls"][1] = calls["calls"][0] if duplicate else self.calls["calls"][2]
            self.save("invocations.json", calls)
            with self.assertRaises(ValueError):
                self.verify()

    def test_changed_argv_deadline_or_capture_environment(self):
        for key, value in (("timeout_seconds", 421), ("command", ["true"]),
                           ("environment", {}), ("engine_command", ["godot", "--headless"])):
            with self.subTest(key=key):
                calls = copy.deepcopy(self.calls)
                calls["calls"][0][key] = value
                self.save("invocations.json", calls)
                with self.assertRaises(ValueError):
                    self.verify()

    def test_nonzero_timeout_or_overlapping_interval(self):
        for key, value in (("returncode", 1), ("returncode", False), ("outer_timeout", True),
                           ("started_monotonic_ns", 1), ("finished_monotonic_ns", 999_000_000_000)):
            with self.subTest(key=key):
                calls = copy.deepcopy(self.calls)
                calls["calls"][1][key] = value
                self.save("invocations.json", calls)
                with self.assertRaises(ValueError):
                    self.verify()

    def test_wrong_or_multiple_engine_banner(self):
        original = (self.root / self.calls["calls"][0]["log"]).read_text()
        for text in (original.replace(gate.ENGINE, "4.0"), original + original.splitlines()[0] + "\n",
                     original.split("\n", 1)[1]):
            self.rewrite_log(lambda _: text)
            with self.assertRaises(ValueError):
                self.verify()

    def test_missing_partial_or_duplicate_success_marker(self):
        original = (self.root / self.calls["calls"][0]["log"]).read_text()
        marker = gate.PROBES[0][3]
        for text in (original.replace(marker, ""), original.replace(marker, marker + " extra"),
                     original + marker + "\n"):
            self.rewrite_log(lambda _: text)
            with self.assertRaises(ValueError):
                self.verify()

    def test_errors_after_pass_are_not_filtered(self):
        original = (self.root / self.calls["calls"][0]["log"]).read_text()
        for error in ("ERROR: engine failure", "SCRIPT ERROR: bad", "ObjectDB instances leaked at exit",
                      "2 resources still in use at exit", "[ProbeRunner] timeout after 420s",
                      "Segmentation fault (core dumped)"):
            with self.subTest(error=error):
                self.rewrite_log(lambda _: original + error + "\n")
                with self.assertRaises(ValueError):
                    self.verify()

    def test_different_runner_transcript(self):
        (self.root / self.calls["calls"][0]["runner_log"]).write_text("different original\n")
        with self.assertRaises(ValueError):
            self.verify()

    def test_extra_or_missing_original_log(self):
        extra = self.root / "logs/old-run.log"
        extra.write_text("stale")
        with self.assertRaises(ValueError):
            self.verify()
        extra.unlink()
        (self.root / self.calls["calls"][0]["log"]).unlink()
        with self.assertRaises(ValueError):
            self.verify()

    def test_foreign_expected_source_or_commit(self):
        for sha, tree in (("1" * 40, self.tree), (self.sha, "2" * 40)):
            with self.assertRaises(ValueError):
                gate.verify(self.root, expected_native_sha=sha, expected_native_tree=tree)
        (self.root / "source-commit.raw").write_bytes(b"unrelated")
        with self.assertRaises(ValueError):
            self.verify()

    def test_omitting_a_source_in_both_snapshots_cannot_pass(self):
        for phase in ("before", "after"):
            inventory = copy.deepcopy(self.inventory)
            inventory["tracked"].pop(0)
            self.save("source-inventory-" + phase + ".json", inventory)
            path = self.root / ("source-tree-" + phase + ".bin")
            path.write_bytes(b"\0".join(path.read_bytes().split(b"\0")[1:]))
        with self.assertRaisesRegex(ValueError, "Git tree"):
            self.verify()

    def test_changed_bytes_mode_or_sparse_missing_source(self):
        for key, value in (("actual_blob", "0" * 40), ("mode", "100755"),
                           ("materialized", False), ("sha256", "0" * 64)):
            with self.subTest(key=key):
                inventory = copy.deepcopy(self.inventory)
                inventory["tracked"][0][key] = value
                self.save("source-inventory-after.json", inventory)
                with self.assertRaises(ValueError):
                    self.verify()

    def test_changed_index_or_dirty_status(self):
        path = self.root / "source-index-after.bin"
        original = path.read_bytes()
        path.write_bytes(original + b"changed")
        with self.assertRaises(ValueError):
            self.verify()
        path.write_bytes(original)
        (self.root / "source-dirty-after.txt").write_text(" M scripts/example.gd\n")
        with self.assertRaises(ValueError):
            self.verify()

    def test_generated_uid_inventory_preserved_without_cleanup(self):
        owner = self.inventory["tracked"][0]["path"]
        item = {"path": owner + ".uid", "category": "generated_uid", "tracked_owner": owner,
                "bytes": 7, "sha256": "a" * 64, "actual_blob": "b" * 40, "mode": "100644"}
        inventory = copy.deepcopy(self.inventory)
        inventory["untracked_import_inventory"] = [item]
        self.save("source-inventory-after.json", inventory)
        gate.check_sources(self.root, self.sha, self.tree)
        item["tracked_owner"] = "missing.gd"
        self.save("source-inventory-after.json", inventory)
        with self.assertRaises(ValueError):
            gate.check_sources(self.root, self.sha, self.tree)

    def test_reader_hash_rejected_before_import(self):
        sentinel = self.root / "must-not-exist"
        (self.root / "helpers/verify_discovery_rasters.py").write_text(
            "from pathlib import Path\nPath(" + repr(str(sentinel)) + ").write_text('executed')\n")
        with self.assertRaises(ValueError):
            gate.bound_module(self.root, "verify_discovery_rasters.py")
        self.assertFalse(sentinel.exists())

    def test_missing_extra_or_symlink_capture(self):
        path = self.root / "captures/hub/hub_portrait.png"
        data = path.read_bytes()
        path.unlink()
        with self.assertRaises(ValueError):
            self.verify()
        path.write_bytes(data)
        extra = self.root / "captures/old.json"
        extra.write_text("{}")
        with self.assertRaises(ValueError):
            self.verify()
        extra.unlink()
        path.unlink()
        path.symlink_to(self.root / "captures/hub/hub_fold_landscape.png")
        with self.assertRaises(ValueError):
            self.verify()

    def test_corrupted_uniform_or_transparent_png(self):
        path = self.root / "captures/hub/hub_portrait.png"
        data = path.read_bytes()
        for kind in ("truncated", "uniform", "transparent"):
            with self.subTest(kind=kind):
                if kind == "truncated":
                    path.write_bytes(data[:64])
                else:
                    image = Image.new("RGBA" if kind == "transparent" else "RGB", (1080, 1920),
                                      (40, 50, 60, 0) if kind == "transparent" else (40, 50, 60))
                    image.save(path)
                    image.close()
                with self.assertRaises((ValueError, OSError, SyntaxError)):
                    self.verify()

    def test_nonfinite_or_duplicate_report(self):
        path = self.root / "captures/wonder/captures.json"
        for data in ('{"checks":136,"checks":0}', '{"checks":NaN}'):
            path.write_text(data)
            with self.assertRaises(ValueError):
                self.verify()

    def test_wrong_hub_and_wonder_original_state(self):
        for relative, mutate in (
                ("captures/hub/hub-original-identity.json",
                 lambda report: report["captures"][0].update(headless=True)),
                ("captures/wonder/captures.json",
                 lambda report: report["captures"][0]["garden"].update(geometry_batches=8))):
            path = self.root / relative
            original = path.read_bytes()
            report = json.loads(original)
            mutate(report)
            self.save(relative, report)
            with self.assertRaises(ValueError):
                self.verify()
            path.write_bytes(original)

    def test_unchanged_activity_pixels_fail(self):
        (self.root / "captures/learning/math-complete-1280x720.png").write_bytes(
            (self.root / "captures/learning/math-start-1280x720.png").read_bytes())
        with self.assertRaises(ValueError):
            self.verify()

    def test_forged_manifest_and_write_mode_fail(self):
        self.save(gate.MANIFEST, {"schema": 1, "probe_count": 10})
        with self.assertRaises(ValueError):
            self.verify()
        with self.assertRaises(ValueError):
            gate.verify(self.root, expected_native_sha=self.sha, expected_native_tree=self.tree, write=True)

    def test_fresh_output_rejects_existing_symlink_and_source_descendant(self):
        project = Path(self.temp.name) / "native"
        project.mkdir()
        for path in (self.root, project / "inside"):
            with self.assertRaises(ValueError):
                collector.fresh_output(project, path)
        linked = Path(self.temp.name) / "link"
        linked.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            collector.fresh_output(project, linked / "new")
        fresh = Path(self.temp.name) / "fresh"
        self.assertEqual(collector.fresh_output(project, fresh), fresh)
        self.assertTrue(fresh.is_dir())

    def test_preserved_budgets_and_no_headless_render_substitution(self):
        plan = gate.invocation_plan(self.context)
        self.assertEqual([row["timeout_seconds"] for row in plan], [420, 420, 420, 150, 150, 150, 420, 180, 900, 420])
        self.assertEqual(sum(row["timeout_seconds"] for row in plan), 3630)
        self.assertEqual(len(plan), 10)
        for row in plan:
            self.assertEqual(row["engine_command"].count("--headless"), int(row["mode"] == "headless"))
            self.assertEqual(row["engine_command"].count("--rendering-method"), int(row["mode"] == "rendered"))


if __name__ == "__main__":
    unittest.main()
