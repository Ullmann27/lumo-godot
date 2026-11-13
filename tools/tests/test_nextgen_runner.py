"""Test the actual acceptance shell's fail-closed evidence collection."""
from pathlib import Path
import json
import os
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
import sys
import zlib


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tools/validate_nextgen.sh'


class NextgenRunnerTests(unittest.TestCase):
    def run_fixture(self, *, failing='', missing=''):
        """The fake engine tests orchestration, never claims rendered/gameplay proof."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            root.joinpath('tools').mkdir()
            root.joinpath('scripts/tests').mkdir(parents=True)
            root.joinpath('bin').mkdir()
            shutil.copyfile(RUNNER, root / 'tools/validate_nextgen.sh')
            shutil.copyfile(ROOT / 'tools/run_godot_probe.py', root / 'tools/run_godot_probe.py')
            cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+)", RUNNER.read_text(), re.M)
            markers = {name: marker for name, marker, _ in cases}
            for name in markers:
                if name != missing:
                    root.joinpath('scripts/tests', name + '.gd').write_text('# fixture only\n')
            engine = root / 'bin/fixture-godot'
            engine.write_text('#!/usr/bin/env python3\n'
                              'import pathlib, sys\n'
                              'if "--version" in sys.argv: print("fixture-engine"); sys.exit(0)\n'
                              'name=pathlib.Path(sys.argv[sys.argv.index("--script")+1]).stem\n'
                              f'if name == {failing!r}: print("ERROR: requested fixture failure"); sys.exit(1)\n'
                              f'print({markers!r}[name])\n')
            engine.chmod(0o755)
            git = root / 'bin/git'
            git.write_text('#!/bin/sh\nif [ "$1" = rev-parse ]; then echo fixture-source; fi\n')
            git.chmod(0o755)
            python = root / 'bin/python3'
            python.write_text(f'#!{sys.executable}\n'
                              'import os, pathlib, sys\n'
                              'if len(sys.argv)>1 and sys.argv[1]=="tools/run_godot_probe.py":\n'
                              '    name=pathlib.Path(sys.argv[sys.argv.index("--log")+1]).stem\n'
                              '    budget=sys.argv[sys.argv.index("--timeout")+1]\n'
                              '    with open("budgets.tsv","a") as log: log.write(name+"\\t"+budget+"\\n")\n'
                              f'os.execv({sys.executable!r}, [{sys.executable!r}, *sys.argv[1:]])\n')
            python.chmod(0o755)
            env = dict(os.environ, GODOT_BIN=str(engine), DISPLAY=':fixture',
                       LUMO_NEXTGEN_LOG_DIR=str(root / 'logs'),
                       PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['bash', 'tools/validate_nextgen.sh'], cwd=root,
                                    env=env, capture_output=True, text=True, timeout=45)
            rows = (root / 'logs/results.tsv').read_text().splitlines()[1:]
            budgets = dict(line.split('\t') for line in root.joinpath('budgets.tsv').read_text().splitlines())
            return result, rows, cases, budgets

    def test_success_requires_every_logic_and_rendered_probe(self):
        result, rows, cases, budgets = self.run_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('[LumoNextgen] PASS', result.stdout)
        self.assertEqual(budgets['learning_world_capture-rendered'], '900')
        self.assertTrue(all(value == '420' for key, value in budgets.items()
                            if key != 'learning_world_capture-rendered'))

    def test_failure_does_not_suppress_other_module_evidence_or_emit_pass(self):
        result, rows, cases, _ = self.run_fixture(failing='jump_nextgen_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('jump_nextgen_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertIn('[LumoNextgen] FAIL', result.stderr)

    def test_missing_required_source_is_a_failure_and_other_captures_still_run(self):
        result, rows, cases, _ = self.run_fixture(missing='learning_world_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('learning_world_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)


class StudioPuzzleMenuContractTests(unittest.TestCase):
    """Synthetic fixtures test gate rejection; they are never renderer evidence."""

    def setUp(self):
        self.source = (ROOT / 'tools/validate_studio.sh').read_text()
        self.roster = self.source.split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]

    def test_existing_probes_and_budgets_survive_two_required_menu_modes(self):
        cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+) (\d+)", self.source, re.M)
        previous = [
            ('learning_sharing_regression', '[LearningSharing] PASS', 'headless', '180'),
            ('learning_studio_regression', '[LearningStudio] PASS', 'headless', '180'),
            ('lumo_studio_motion_regression', '[LumoStudioMotion] PASS', 'headless', '180'),
            ('puzzle_rotation_regression', '[PuzzleRotation] PASS', 'headless', '180'),
            ('treasure_exploration_regression', '[TreasureExploration] PASS', 'headless', '180'),
            ('learning_sharing_capture', '[LearningSharingCapture] PASS', 'rendered', '600'),
            ('lumo_studio_motion_capture', '[LumoStudioCapture] PASS', 'rendered', '420'),
            ('puzzle_rotation_regression', '[PuzzleRotation] PASS', 'rendered', '600'),
            ('treasure_exploration_regression', '[TreasureExploration] PASS', 'rendered', '600'),
        ]
        self.assertEqual([row for row in cases if row[0] != 'puzzle_menu_lifecycle_regression'], previous)
        self.assertEqual([row for row in cases if row[0] == 'puzzle_menu_lifecycle_regression'], [
            ('puzzle_menu_lifecycle_regression', '[PuzzleMenuLifecycle] PASS', 'headless', '180'),
            ('puzzle_menu_lifecycle_regression', '[PuzzleMenuLifecycle] PASS', 'rendered', '600'),
        ])
        self.assertIn("check_probe puzzle_menu_lifecycle_regression '[PuzzleMenuLifecycle] PASS' "
                      'rendered 600 -- --capture', self.source)

    @staticmethod
    def fixture_png(width, height):
        def chunk(kind, data):
            return (struct.pack('>I', len(data)) + kind + data
                    + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
        return (b'\x89PNG\r\n\x1a\n'
                + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(bytes(width * 3 + 1) * height))
                + chunk(b'IEND', b''))

    def roster_fixture(self, mutation=''):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for probe, count in {'learning_sharing_capture': 6, 'lumo_studio_motion_capture': 8,
                                 'puzzle_rotation_regression': 7, 'treasure_exploration_regression': 3}.items():
                folder = root / 'captures' / probe
                folder.mkdir(parents=True)
                for index in range(count):
                    (folder / f'fixture-{index}.png').write_bytes(self.fixture_png(360, 360))
            folder = root / 'captures/puzzle_menu_lifecycle_regression'
            folder.mkdir()
            for width, height in ((960, 540), (640, 360)):
                for phase in ('rotation-menu', 'rotation-play', 'classic-play'):
                    (folder / f'{width}x{height}-{phase}.png').write_bytes(self.fixture_png(width, height))
            selected = folder / '640x360-rotation-menu.png'
            if mutation == 'missing':
                selected.unlink()
            elif mutation == 'renamed':
                selected.rename(folder / 'wrong-scene.png')
            elif mutation == 'dimensions':
                selected.write_bytes(self.fixture_png(640, 361))
            result = subprocess.run([sys.executable, '-', str(root)], input=self.roster,
                                    text=True, capture_output=True, timeout=15)
            report = root / 'renderer-images.json'
            return result, json.loads(report.read_text()) if report.exists() else None

    def test_all_thirty_required_rasters_and_named_menu_views_are_enforced(self):
        result, report = self.roster_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(report['images']), 30)
        for mutation in ('missing', 'renamed', 'dimensions'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_native_menu_error_rejects_even_a_success_marker_and_zero_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = ('print("[PuzzleMenuLifecycle] PASS fixture only", flush=True); '
                       'print("ERROR: Condition !is_inside_tree() is true. Returning: false", flush=True)')
            result = subprocess.run([
                sys.executable, str(ROOT / 'tools/run_godot_probe.py'),
                '--log', str(Path(directory) / 'native-error.log'), '--timeout', '10',
                '--required', '[PuzzleMenuLifecycle] PASS', '--', sys.executable, '-c', fixture,
            ], capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('[PuzzleMenuLifecycle] PASS', result.stdout)
            self.assertIn('ERROR:', result.stdout)
            self.assertIn('[ProbeRunner] FAIL', result.stderr)


if __name__ == '__main__':
    unittest.main()
