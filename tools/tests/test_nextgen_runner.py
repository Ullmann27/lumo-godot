"""Test the actual acceptance shell's fail-closed evidence collection."""
from pathlib import Path
from functools import lru_cache
import hashlib
import importlib.util
from io import BytesIO
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
VILLAGE_PNGS = {
    'village-overview-1280x720.png': (1280, 720),
    'village-chapters-412x915.png': (412, 915),
    'village-trader-2176x1812.png': (2176, 1812),
    'village-treasury-640x360.png': (640, 360),
}
VILLAGE_DIRECTORY = 'captures/build_village_scene_regression'
PUZZLE_MENU_DIRECTORY = 'captures/puzzle_menu_lifecycle_regression'
PUZZLE_MENU_PNGS = {
    f'{width}x{height}-{stage}.png': (width, height)
    for width, height in ((960, 540), (640, 360))
    for stage in ('rotation-menu', 'rotation-play', 'classic-play')
}


@lru_cache(maxsize=16)
def fixture_png(width=640, height=360, varied=False):
    """A synthetic raster exercises file validation, never visual acceptance."""
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data)))

    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    row = (b'\x20\x40\x60' * (width // 2) + b'\xb0\x80\x20' * (width - width // 2)
           if varied else b'\x20\x40\x60' * width)
    pixels = (b'\x00' + row) * height
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
            village_verifier = ROOT / 'tools/verify_village_rasters.py'
            if village_verifier.exists():
                shutil.copyfile(village_verifier, root / 'tools/verify_village_rasters.py')
            puzzle_verifier = ROOT / 'tools/verify_puzzle_menu_rasters.py'
            if puzzle_verifier.exists():
                shutil.copyfile(puzzle_verifier, root / 'tools/verify_puzzle_menu_rasters.py')
            root.joinpath('fixture-raster.png').write_bytes(fixture_png())
            root.joinpath('village-fixtures').mkdir()
            for name, dimensions in VILLAGE_PNGS.items():
                root.joinpath('village-fixtures', name).write_bytes(fixture_png(*dimensions, varied=True))
            root.joinpath('puzzle-menu-fixtures').mkdir()
            for name, dimensions in PUZZLE_MENU_PNGS.items():
                root.joinpath('puzzle-menu-fixtures', name).write_bytes(fixture_png(*dimensions, varied=True))
            cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+)", runner.read_text(), re.M)
            markers = {name: marker for name, marker, _ in cases}
            for name in markers:
                if name != missing:
                    root.joinpath('scripts/tests', name + '.gd').write_text('# fixture only\n')
            engine = root / 'bin/fixture-godot'
            engine.write_text('#!/usr/bin/env python3\n'
                              'import json, os, pathlib, shutil, sys\n'
                              'if "--version" in sys.argv: print("fixture-engine"); sys.exit(0)\n'
                              'name=pathlib.Path(sys.argv[sys.argv.index("--script")+1]).stem\n'
                              'with open("invocations.jsonl", "a") as log:\n'
                              '    log.write(json.dumps({"name":name,"args":sys.argv[1:],"capture_dir":os.environ.get("LUMO_CAPTURE_DIR"),"puzzle_menu_dir":os.environ.get("LUMO_PUZZLE_MENU_EVIDENCE_DIR")})+"\\n")\n'
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
                              'if name=="build_village_scene_regression" and "--headless" not in sys.argv:\n'
                              '    assert "--capture" in sys.argv, "Village renderer must exercise its capture path"\n'
                              '    capture=pathlib.Path(os.environ["LUMO_CAPTURE_DIR"])\n'
                              '    capture.mkdir(parents=True,exist_ok=True)\n'
                              f'    names=list({VILLAGE_PNGS!r})\n'
                              f'    if name=={missing_raster!r}: names.pop()\n'
                              '    for image_name in names:\n'
                              '        shutil.copyfile(pathlib.Path("village-fixtures")/image_name,capture/image_name)\n'
                              'if name=="puzzle_menu_lifecycle_regression":\n'
                              '    assert os.environ.get("LUMO_PUZZLE_MENU_EVIDENCE_DIR"), "Puzzle lifecycle evidence directory is mandatory"\n'
                              '    if "--headless" not in sys.argv:\n'
                              '        assert "--capture" in sys.argv, "Puzzle lifecycle renderer must capture actual frames"\n'
                              '        capture=pathlib.Path(os.environ["LUMO_PUZZLE_MENU_EVIDENCE_DIR"])\n'
                              '        capture.mkdir(parents=True,exist_ok=True)\n'
                              f'        names=list({PUZZLE_MENU_PNGS!r})\n'
                              f'        if name=={missing_raster!r}: names.pop()\n'
                              '        for image_name in names:\n'
                              '            shutil.copyfile(pathlib.Path("puzzle-menu-fixtures")/image_name,capture/image_name)\n'
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
            village_manifest = root / 'logs/village-images.json'
            result.village_images = json.loads(village_manifest.read_text())['images'] if village_manifest.exists() else []
            puzzle_manifest = root / 'logs/puzzle-menu-images.json'
            result.puzzle_menu_images = json.loads(puzzle_manifest.read_text())['images'] if puzzle_manifest.exists() else []
            result.invocations = [json.loads(line) for line in root.joinpath('invocations.jsonl').read_text().splitlines()]
            return result, rows, cases, budgets, images

    def test_success_requires_every_logic_and_rendered_probe(self):
        result, rows, cases, budgets, images = self.run_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(cases), 43)
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
        self.assertIn('[VillageRasterRoster] PASS 4 actual PNG files', result.stdout)
        self.assertEqual({image['path']: (image['width'], image['height']) for image in result.village_images},
                         {VILLAGE_DIRECTORY + '/' + name: size for name, size in VILLAGE_PNGS.items()})
        pairs = {(name, mode) for name, _, mode in cases}
        self.assertTrue({('build_village_economy_regression', 'headless'),
                         ('build_village_art_regression', 'headless'),
                         ('build_village_scene_regression', 'headless'),
                         ('build_village_scene_regression', 'rendered')}.issubset(pairs))
        village_calls = [call for call in result.invocations if call['name'] == 'build_village_scene_regression']
        self.assertEqual(len(village_calls), 2)
        for call in village_calls:
            self.assertEqual('--capture' in call['args'], '--headless' not in call['args'])
            self.assertTrue(call['capture_dir'].endswith('/' + VILLAGE_DIRECTORY))
        self.assertIn('[PuzzleMenuRasterRoster] PASS 6 actual PNG files', result.stdout)
        self.assertEqual({image['path']: (image['width'], image['height']) for image in result.puzzle_menu_images},
                         {PUZZLE_MENU_DIRECTORY + '/' + name: size for name, size in PUZZLE_MENU_PNGS.items()})
        puzzle_calls = [call for call in result.invocations if call['name'] == 'puzzle_menu_lifecycle_regression']
        self.assertEqual(len(puzzle_calls), 2)
        for call in puzzle_calls:
            self.assertEqual('--capture' in call['args'], '--headless' not in call['args'])
            self.assertTrue(call['puzzle_menu_dir'].endswith('/' + PUZZLE_MENU_DIRECTORY))

    def test_missing_puzzle_menu_png_cannot_pass_with_all_existing_scene_evidence(self):
        result, rows, cases, _, images = self.run_fixture(missing_raster='puzzle_menu_lifecycle_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertEqual(len(images), 24)
        self.assertEqual(len(result.village_images), 4)
        self.assertEqual(result.puzzle_menu_images, [])
        self.assertIn('puzzle-menu-raster-roster', result.stderr)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)

    def test_native_puzzle_menu_error_fails_both_modes_and_keeps_other_evidence(self):
        result, rows, cases, _, _ = self.run_fixture(failing='puzzle_menu_lifecycle_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('puzzle_menu_lifecycle_regression\theadless\tFAIL', rows)
        self.assertIn('puzzle_menu_lifecycle_regression\trendered\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)

    def test_missing_village_png_fails_even_with_all_core_markers_and_studio_rasters(self):
        result, rows, cases, _, images = self.run_fixture(missing_raster='build_village_scene_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertEqual(len(images), 24)
        self.assertIn('village-raster-roster', result.stderr)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertEqual(result.village_images, [])

    def test_failing_village_scene_still_collects_other_modules_without_final_pass(self):
        result, rows, cases, _, _ = self.run_fixture(failing='build_village_scene_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('build_village_scene_regression\theadless\tFAIL', rows)
        self.assertIn('build_village_scene_regression\trendered\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)

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


class VillageRasterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('village_rasters', ROOT / 'tools/verify_village_rasters.py')
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        capture = root / VILLAGE_DIRECTORY
        capture.mkdir(parents=True)
        for name, dimensions in VILLAGE_PNGS.items():
            (capture / name).write_bytes(fixture_png(*dimensions, varied=True))
        return root, capture

    def test_exact_decoded_original_roster_has_physical_dimensions_and_byte_hashes(self):
        root, capture = self.fixture()
        images = self.module.verify(root)
        self.assertEqual({item['path']: (item['width'], item['height']) for item in images},
                         {VILLAGE_DIRECTORY + '/' + name: size for name, size in VILLAGE_PNGS.items()})
        for item in images:
            data = (root / item['path']).read_bytes()
            self.assertEqual(item['sha256'], hashlib.sha256(data).hexdigest())
            self.assertEqual(item['bytes'], len(data))
        self.assertEqual(json.loads((root / 'village-images.json').read_text()), {'images': images})

    def test_missing_or_additional_original_images_cannot_produce_a_complete_roster(self):
        for name in VILLAGE_PNGS:
            root, capture = self.fixture()
            (capture / name).unlink()
            with self.subTest(missing=name), self.assertRaises(ValueError):
                self.module.verify(root)
            self.assertFalse((root / 'village-images.json').exists())
        root, capture = self.fixture()
        (capture / 'unexpected.png').write_bytes(fixture_png(varied=True))
        with self.assertRaises(ValueError):
            self.module.verify(root)

    def test_renamed_symlinked_corrupt_uniform_transparent_or_wrong_sized_images_fail(self):
        for mutation in ('renamed', 'symlink', 'truncated', 'uniform', 'transparent', 'pixel-size'):
            root, capture = self.fixture()
            path = capture / 'village-overview-1280x720.png'
            if mutation == 'renamed': path.rename(capture / 'invented.png')
            if mutation == 'symlink':
                original = root / 'outside.png'
                path.rename(original)
                path.symlink_to(original)
            if mutation == 'truncated': path.write_bytes(path.read_bytes()[:40])
            if mutation == 'uniform': path.write_bytes(fixture_png(1280, 720))
            if mutation == 'transparent':
                from PIL import Image
                output = BytesIO()
                Image.new('RGBA', (1280, 720), (200, 40, 90, 0)).save(output, format='PNG')
                path.write_bytes(output.getvalue())
            if mutation == 'pixel-size': path.write_bytes(fixture_png(640, 360, varied=True))
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.module.verify(root)
            self.assertFalse((root / 'village-images.json').exists())


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
