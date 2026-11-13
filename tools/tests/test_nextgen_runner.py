"""Test the actual acceptance shell's fail-closed evidence collection."""
from pathlib import Path
import hashlib
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
STUDIO_RUNNER = ROOT / 'tools/validate_studio.sh'
RASTERS = {'learning_sharing_capture': 6, 'lumo_studio_motion_capture': 8,
           'puzzle_rotation_regression': 7, 'treasure_exploration_regression': 3}


def fixture_png():
    """A synthetic raster exercises file validation, never visual acceptance."""
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data)))

    header = struct.pack('>IIBBBBB', 640, 360, 8, 2, 0, 0, 0)
    pixels = (b'\x00' + b'\x20\x40\x60' * 640) * 360
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
            + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b''))


class NextgenRunnerTests(unittest.TestCase):
    def run_fixture(self, *, failing='', missing='', missing_raster='',
                    invalid_raster='', runner=RUNNER):
        """The fake engine tests orchestration, never claims rendered/gameplay proof."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            root.joinpath('tools').mkdir()
            root.joinpath('scripts/tests').mkdir(parents=True)
            root.joinpath('bin').mkdir()
            shutil.copyfile(runner, root / 'tools' / runner.name)
            shutil.copyfile(ROOT / 'tools/run_godot_probe.py', root / 'tools/run_godot_probe.py')
            shutil.copyfile(ROOT / 'tools/verify_studio_rasters.py', root / 'tools/verify_studio_rasters.py')
            root.joinpath('fixture-raster.png').write_bytes(fixture_png())
            cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+)", runner.read_text(), re.M)
            markers = {name: marker for name, marker, _ in cases}
            for name in markers:
                if name != missing:
                    root.joinpath('scripts/tests', name + '.gd').write_text('# fixture only\n')
            engine = root / 'bin/fixture-godot'
            engine.write_text('#!/usr/bin/env python3\n'
                              'import os, pathlib, shutil, sys\n'
                              'if "--version" in sys.argv: print("fixture-engine"); sys.exit(0)\n'
                              'name=pathlib.Path(sys.argv[sys.argv.index("--script")+1]).stem\n'
                              f'if name == {failing!r}: print("ERROR: requested fixture failure"); sys.exit(1)\n'
                              f'rasters={RASTERS!r}\n'
                              'if "--headless" not in sys.argv and name in rasters:\n'
                              '    variable={"puzzle_rotation_regression":"PUZZLE_ROTATION_CAPTURE_DIR",\n'
                              '              "treasure_exploration_regression":"TREASURE_EXPLORATION_CAPTURE_DIR"}.get(name,"LUMO_CAPTURE_DIR")\n'
                              '    capture=pathlib.Path(os.environ[variable])\n'
                              '    capture.mkdir(parents=True,exist_ok=True)\n'
                              f'    count=rasters[name]-int(name=={missing_raster!r})\n'
                              '    for index in range(count):\n'
                              '        image=capture/f"fixture-{index}.png"\n'
                              f'        if name=={invalid_raster!r} and index==0: image.write_bytes(b"not a PNG")\n'
                              '        else: shutil.copyfile("fixture-raster.png",image)\n'
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
                       LUMO_STUDIO_LOG_DIR=str(root / 'logs'),
                       PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['bash', 'tools/' + runner.name], cwd=root,
                                    env=env, capture_output=True, text=True, timeout=45)
            rows = (root / 'logs/results.tsv').read_text().splitlines()[1:]
            budgets = dict(line.split('\t') for line in root.joinpath('budgets.tsv').read_text().splitlines())
            manifest = root / 'logs/renderer-images.json'
            images = json.loads(manifest.read_text())['images'] if manifest.exists() else []
            return result, rows, cases, budgets, images

    def test_success_requires_every_logic_and_rendered_probe(self):
        result, rows, cases, budgets, images = self.run_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(cases), 37)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('[LumoNextgen] PASS', result.stdout)
        self.assertEqual(budgets['learning_world_capture-rendered'], '900')
        self.assertEqual(budgets['treasure_exploration_regression-rendered'], '600')
        self.assertTrue(all(value == '420' for key, value in budgets.items()
                            if key not in ('learning_world_capture-rendered',
                                           'treasure_exploration_regression-rendered')))
        self.assertIn('[StudioRasterRoster] PASS 24 actual PNG files', result.stdout)
        self.assertEqual(len(images), 24)
        self.assertTrue(all(image['sha256'] == hashlib.sha256(fixture_png()).hexdigest()
                            for image in images))

    def test_failure_does_not_suppress_other_module_evidence_or_emit_pass(self):
        result, rows, cases, _, _ = self.run_fixture(failing='jump_nextgen_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('jump_nextgen_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertIn('[LumoNextgen] FAIL', result.stderr)

    def test_missing_required_source_is_a_failure_and_other_captures_still_run(self):
        result, rows, cases, _, _ = self.run_fixture(missing='learning_world_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('learning_world_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)

    def test_missing_treasure_image_fails_even_when_every_probe_reports_pass(self):
        result, rows, cases, _, images = self.run_fixture(
            missing_raster='treasure_exploration_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('treasure_exploration_regression: found 2 PNGs, expected 3', result.stderr)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertEqual(images, [])

    def test_invalid_png_fails_even_when_file_counts_and_probe_markers_match(self):
        result, rows, _, _, images = self.run_fixture(invalid_raster='lumo_studio_motion_capture')
        self.assertEqual(result.returncode, 1)
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('Invalid PNG:', result.stderr)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertEqual(images, [])

    def test_producer_studio_runner_uses_the_same_raster_guard(self):
        result, rows, cases, _, images = self.run_fixture(
            runner=STUDIO_RUNNER, missing_raster='puzzle_rotation_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(cases), 9)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('puzzle_rotation_regression: found 6 PNGs, expected 7', result.stderr)
        self.assertNotIn('[LumoStudio] PASS', result.stdout)
        self.assertEqual(images, [])


class NextgenEvidenceWorkflowTests(unittest.TestCase):
    def job(self, name):
        source = (ROOT / '.github/workflows/lumo-nextgen-2018.yml').read_text()
        matched = re.search(r'^  ' + re.escape(name) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)',
                            source, flags=re.M | re.S)
        self.assertIsNotNone(matched, name)
        return matched.group(1)

    def test_complete_archive_waits_for_touch_and_keeps_original_scope_roots(self):
        worlds, touch, bundle = (self.job(name) for name in ('new-worlds', 'touch-density', 'bundle-evidence'))
        self.assertIn('name: lumo-nextgen-2018-worlds-evidence', worlds)
        self.assertNotIn('name: lumo-nextgen-2018-native-evidence', worlds)
        self.assertIn('scope: [workshop, treasure, build]', touch)
        self.assertIn('fail-fast: false', touch)
        self.assertIn('name: touch-${{ matrix.scope }}', touch)
        self.assertIn('ref: ${{ github.event.pull_request.head.sha || github.sha }}', touch)
        self.assertIn('bash tools/validate_studio_touch.sh "$TOUCH_SCOPE"', touch)
        self.assertIn('name: lumo-nextgen-2019-touch-${{ matrix.scope }}', touch)
        self.assertIn('path: touch-evidence/', touch)
        self.assertIn('needs: [new-worlds, touch-density]', bundle)
        self.assertIn('name: lumo-nextgen-2018-worlds-evidence', bundle)
        self.assertIn('pattern: lumo-nextgen-2019-touch-*', bundle)
        self.assertIn('path: native-evidence/touch-evidence/', bundle)
        self.assertIn('merge-multiple: true', bundle)
        self.assertIn('name: lumo-nextgen-2018-native-evidence', bundle)
        self.assertNotIn('if: always()', bundle)

    def test_evidence_archive_rejects_failed_touch_partial_bundle_and_foreign_sources(self):
        archive = self.job('archive-evidence')
        expression = archive.split('    if: >-\n', 1)[1].split('    runs-on:', 1)[0]
        expression = expression.replace('\n', ' ').replace('&&', 'and').strip()
        values = {
            'github.event_name': 'pull_request', 'github.repository': 'Ullmann27/lumo-godot',
            'github.event.pull_request.head.repo.full_name': 'Ullmann27/lumo-godot',
            'github.event.pull_request.base.ref': 'chatgpt/lumo-nextgen-20261113',
            'github.event.pull_request.head.ref': 'integration/lumo-connections-20261113',
            **{'needs.' + name + '.result': 'success' for name in
               ('learning-preview', 'gameplay', 'new-worlds', 'touch-density', 'bundle-evidence')},
        }

        def allowed(changes):
            actual = dict(values, **changes)
            executable = expression
            for key in sorted(actual, key=len, reverse=True):
                executable = executable.replace(key, repr(actual[key]))
            return eval(executable, {'__builtins__': {}}, {})

        self.assertTrue(allowed({}))
        cases = [(key, status) for key in values if key.startswith('needs.')
                 for status in ('failure', 'skipped', 'cancelled')]
        cases.extend([('github.event_name', 'workflow_dispatch'),
                      ('github.repository', 'other/fork'),
                      ('github.event.pull_request.head.repo.full_name', 'other/fork'),
                      ('github.event.pull_request.base.ref', 'main'),
                      ('github.event.pull_request.head.ref', 'main')])
        for key, value in cases:
            with self.subTest(key=key, value=value):
                self.assertFalse(allowed({key: value}))
        self.assertIn('SOURCE_SHA: ${{ github.event.pull_request.head.sha }}', archive)
        self.assertIn("artifact['workflow_run']['head_sha'] == os.environ['SOURCE_SHA']", archive)
        self.assertIn('sha256sum -c native-evidence.zip.sha256', archive)
        self.assertNotIn('.apk', archive.lower())


if __name__ == '__main__':
    unittest.main()
