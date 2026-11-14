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
                    invalid_raster='', post_pass_error='', puzzle_mutation='', runner=RUNNER):
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
            if runner == STUDIO_RUNNER:
                # Reuse the full synthetic Studio2020 source fixture. The fake
                # engine copies each scene's own files only when it is invoked.
                template_root = root / 'studio-fixtures'
                template_root.mkdir()
                StudioPuzzleMenuContractTests().write_roster_fixture(template_root)
                face = template_root / 'captures/lumo_facial_capture'
                root.joinpath('fixture-media.json').write_bytes((face / 'movie-ffprobe.json').read_bytes())
                root.joinpath('fixture-movie.bin').write_bytes((face / 'facial-runtime.mp4').read_bytes())
                for filename in ('facial-runtime.mp4', 'movie.json', 'movie-ffprobe.json'):
                    (face / filename).unlink()
                (face / 'facial-runtime.avi').write_bytes(b'SYNTHETIC orchestration fixture AVI' * 80)
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
                              'if "--headless" not in sys.argv:\n'
                              '    template=pathlib.Path("studio-fixtures/captures")/name\n'
                              '    if template.is_dir() and name not in rasters and name!="puzzle_menu_lifecycle_regression":\n'
                              '        capture=pathlib.Path(os.environ["LUMO_CAPTURE_DIR"])\n'
                              '        shutil.copytree(template,capture,dirs_exist_ok=True)\n'
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
                              '        selected=capture/"640x360-rotation-menu.png"\n'
                              f'        mutation={puzzle_mutation!r}\n'
                              '        if mutation=="renamed": selected.rename(capture/"unexpected.png")\n'
                              '        if mutation=="truncated": selected.write_bytes(selected.read_bytes()[:40])\n'
                              '        if mutation=="uniform": shutil.copyfile("fixture-raster.png",selected)\n'
                              '        if mutation=="pixel-size": shutil.copyfile("puzzle-menu-fixtures/960x540-rotation-menu.png",selected)\n'
                              f'print({markers!r}[name])\n'
                              f'if name=={post_pass_error!r}: print("ERROR: native fixture error after PASS with process exit zero")\n')
            engine.chmod(0o755)
            if runner == STUDIO_RUNNER:
                # These provider substitutes exercise the actual shell and
                # movie receipts. They never claim decoded gameplay evidence.
                media_tool = (
                    f'#!{sys.executable}\n'
                    'import json, pathlib, sys\n'
                    'tool=pathlib.Path(sys.argv[0]).name\n'
                    'with open("media-invocations.jsonl","a") as log:\n'
                    '    log.write(json.dumps({"tool":tool,"args":sys.argv[1:]})+"\\n")\n'
                    'if tool=="ffprobe":\n'
                    '    sys.stdout.write(pathlib.Path("fixture-media.json").read_text())\n'
                    'elif sys.argv[-1]!="-":\n'
                    '    pathlib.Path(sys.argv[-1]).write_bytes(pathlib.Path("fixture-movie.bin").read_bytes())\n'
                )
                for name in ('ffmpeg', 'ffprobe'):
                    tool = root / 'bin' / name
                    tool.write_text(media_tool)
                    tool.chmod(0o755)
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
            manifest = root / 'logs' / (
                'studio-original-images.json' if runner == STUDIO_RUNNER else 'renderer-images.json')
            studio_manifest = root / 'logs/renderer-images.json'
            result.studio_images = (json.loads(studio_manifest.read_text())['images']
                                    if runner == STUDIO_RUNNER and studio_manifest.exists() else [])
            media_log = root / 'media-invocations.jsonl'
            result.media_invocations = ([json.loads(line) for line in media_log.read_text().splitlines()]
                                        if media_log.exists() else [])
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
        self.assertEqual(len(cases), 20)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('puzzle_rotation_regression: found 6 PNGs, expected 7', result.stderr)
        self.assertNotIn('[LumoStudio] PASS', result.stdout)
        self.assertEqual(images, [])

    def test_studio_success_requires_twenty_pairs_and_separate_original_rosters(self):
        result, rows, cases, budgets, images = self.run_fixture(runner=STUDIO_RUNNER)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(cases), 20)
        self.assertEqual(len(rows), 20)
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        previous = [
            ('learning_sharing_regression', '[LearningSharing] PASS', 'headless'),
            ('learning_studio_regression', '[LearningStudio] PASS', 'headless'),
            ('lumo_studio_motion_regression', '[LumoStudioMotion] PASS', 'headless'),
            ('puzzle_rotation_regression', '[PuzzleRotation] PASS', 'headless'),
            ('treasure_exploration_regression', '[TreasureExploration] PASS', 'headless'),
            ('learning_sharing_capture', '[LearningSharingCapture] PASS', 'rendered'),
            ('lumo_studio_motion_capture', '[LumoStudioCapture] PASS', 'rendered'),
            ('puzzle_rotation_regression', '[PuzzleRotation] PASS', 'rendered'),
            ('treasure_exploration_regression', '[TreasureExploration] PASS', 'rendered'),
        ]
        additional = {
            'cards_safe_area_android_contract', 'cards_safe_area_regression',
            'mobile_safe_area_regression', 'lumo_facial_regression',
            'lumo_facial_capture', 'connect_four_visual_capture',
            'treasure_title_contrast_regression',
        }
        self.assertEqual(
            [case for case in cases if case[0] not in additional | {'puzzle_menu_lifecycle_regression'}],
            previous)
        expected_additional = {
            ('cards_safe_area_android_contract', 'headless'): '180',
            ('cards_safe_area_regression', 'headless'): '180',
            ('mobile_safe_area_regression', 'headless'): '240',
            ('cards_safe_area_regression', 'rendered'): '600',
            ('mobile_safe_area_regression', 'rendered'): '900',
            ('lumo_facial_regression', 'headless'): '180',
            ('lumo_facial_capture', 'rendered'): '420',
            ('connect_four_visual_capture', 'rendered'): '600',
            ('treasure_title_contrast_regression', 'rendered'): '600',
        }
        self.assertEqual({(name, mode) for name, _, mode in cases if name in additional},
                         set(expected_additional))
        for (name, mode), seconds in expected_additional.items():
            self.assertEqual(budgets[name + '-' + mode], seconds)
        self.assertEqual(len(result.studio_images), 54)
        self.assertEqual([call['tool'] for call in result.media_invocations],
                         ['ffmpeg', 'ffmpeg', 'ffprobe'])
        for name, _, mode in previous:
            expected = '180' if mode == 'headless' else '420' if name == 'lumo_studio_motion_capture' else '600'
            self.assertEqual(budgets[name + '-' + mode], expected)
        self.assertEqual(budgets['puzzle_menu_lifecycle_regression-headless'], '180')
        self.assertEqual(budgets['puzzle_menu_lifecycle_regression-rendered'], '600')
        self.assertIn('[LumoStudio] PASS', result.stdout)
        self.assertIn('[StudioRasterRoster] PASS 24 actual PNG files', result.stdout)
        self.assertEqual(len(images), 24)
        self.assertIn('[PuzzleMenuRasterRoster] PASS 6 actual PNG files', result.stdout)
        self.assertEqual({image['path']: (image['width'], image['height']) for image in result.puzzle_menu_images},
                         {PUZZLE_MENU_DIRECTORY + '/' + name: size for name, size in PUZZLE_MENU_PNGS.items()})
        for image in result.puzzle_menu_images:
            data = fixture_png(image['width'], image['height'], varied=True)
            self.assertEqual(image['bytes'], len(data))
            self.assertEqual(image['sha256'], hashlib.sha256(data).hexdigest())
        calls = [call for call in result.invocations if call['name'] == 'puzzle_menu_lifecycle_regression']
        self.assertEqual(len(calls), 2)
        for call in calls:
            headless = '--headless' in call['args']
            self.assertEqual('--capture' in call['args'], not headless)
            ending = '/evidence/puzzle_menu_lifecycle_regression-headless' if headless else '/' + PUZZLE_MENU_DIRECTORY
            self.assertTrue(call['puzzle_menu_dir'].endswith(ending))
            self.assertEqual(call['puzzle_menu_dir'] == call['capture_dir'], not headless)
        self.assertNotEqual(calls[0]['puzzle_menu_dir'], calls[1]['puzzle_menu_dir'])

    def test_studio_missing_or_invalid_puzzle_evidence_rejects_all_pass_markers(self):
        for mutation in ('missing', 'renamed', 'truncated', 'uniform', 'pixel-size'):
            with self.subTest(mutation=mutation):
                result, rows, cases, _, images = self.run_fixture(
                    runner=STUDIO_RUNNER, puzzle_mutation=mutation,
                    missing_raster='puzzle_menu_lifecycle_regression' if mutation == 'missing' else '')
                self.assertEqual(result.returncode, 1)
                self.assertEqual(len(rows), len(cases))
                self.assertTrue(all(row.endswith('\tPASS') for row in rows))
                self.assertEqual(len(images), 24)
                self.assertEqual(result.puzzle_menu_images, [])
                self.assertIn('puzzle-menu-raster-roster', result.stderr)
                self.assertNotIn('[LumoStudio] PASS', result.stdout)

    def test_studio_native_puzzle_error_after_pass_rejects_zero_engine_exit(self):
        result, rows, cases, _, images = self.run_fixture(
            runner=STUDIO_RUNNER, post_pass_error='puzzle_menu_lifecycle_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertEqual(result.stdout.count('[PuzzleMenuLifecycle] PASS'), 2)
        self.assertEqual(result.stdout.count('ERROR: native fixture error after PASS with process exit zero'), 2)
        self.assertIn('puzzle_menu_lifecycle_regression\theadless\tFAIL', rows)
        self.assertIn('puzzle_menu_lifecycle_regression\trendered\tFAIL', rows)
        self.assertTrue(all(row.endswith('\tPASS') for row in rows
                            if not row.startswith('puzzle_menu_lifecycle_regression\t')))
        self.assertEqual(len(images), 24)
        self.assertEqual(len(result.puzzle_menu_images), 6)
        self.assertIn('[ProbeRunner] FAIL', result.stderr)
        self.assertNotIn('[LumoStudio] PASS', result.stdout)


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


class StudioPuzzleMenuContractTests(unittest.TestCase):
    """Synthetic fixtures test gate rejection; they are never renderer evidence."""

    def setUp(self):
        self.source = (ROOT / 'tools/validate_studio.sh').read_text()
        self.roster = self.source.split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]

    def test_existing_probes_and_budgets_survive_two_required_menu_modes(self):
        cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+) (\d+)", self.source, re.M)
        added_names = {'cards_safe_area_android_contract', 'cards_safe_area_regression',
                       'mobile_safe_area_regression'}
        studio2020_names = {'lumo_facial_regression', 'lumo_facial_capture', 'connect_four_visual_capture',
                            'treasure_title_contrast_regression'}
        legacy = [row for row in cases if row[0] not in added_names | studio2020_names]
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
        self.assertEqual(len(legacy), 11)
        self.assertEqual([row for row in legacy if row[0] != 'puzzle_menu_lifecycle_regression'], previous)
        self.assertEqual([row for row in legacy if row[0] == 'puzzle_menu_lifecycle_regression'], [
            ('puzzle_menu_lifecycle_regression', '[PuzzleMenuLifecycle] PASS', 'headless', '180'),
            ('puzzle_menu_lifecycle_regression', '[PuzzleMenuLifecycle] PASS', 'rendered', '600'),
        ])
        self.assertIn("check_probe puzzle_menu_lifecycle_regression '[PuzzleMenuLifecycle] PASS' "
                      'rendered 600 -- --capture', self.source)
        self.assertEqual([row for row in cases if row[0] in added_names], [
            ('cards_safe_area_android_contract', 'CARDS_ANDROID_INSETS_PASS', 'headless', '180'),
            ('cards_safe_area_regression', 'CARDS_SAFE_AREA_PASS', 'headless', '180'),
            ('mobile_safe_area_regression', 'MOBILE_SAFE_AREA_PASS', 'headless', '240'),
            ('cards_safe_area_regression', 'CARDS_SAFE_AREA_PASS', 'rendered', '600'),
            ('mobile_safe_area_regression', 'MOBILE_SAFE_AREA_PASS', 'rendered', '900'),
        ])
        self.assertEqual(len([row for row in cases if row[0] not in studio2020_names]), 16)
        self.assertEqual(len(cases), 20)
        self.assertEqual([row for row in cases if row[0] in studio2020_names], [
            ('lumo_facial_regression', 'LUMO_FACIAL_PASS checks=102', 'headless', '180'),
            ('lumo_facial_capture', 'LUMO_FACIAL_CAPTURE_PASS frames=144', 'rendered', '420'),
            ('connect_four_visual_capture', 'CONNECT_FOUR_VISUAL_PASS', 'rendered', '600'),
            ('treasure_title_contrast_regression', '[TreasureTitleContrast] PASS', 'rendered', '600'),
        ])
        self.assertIn('LUMO_FACE_CAPTURE_DIR="$capture"', self.source)
        self.assertIn('--resolution 640x640 --fixed-fps 24', self.source)
        self.assertIn('--write-movie "$LOG_DIR/captures/lumo_facial_capture/facial-runtime.avi"', self.source)
        self.assertIn("check_probe connect_four_visual_capture 'CONNECT_FOUR_VISUAL_PASS' rendered 600 -- --capture", self.source)
        self.assertIn("check_probe treasure_title_contrast_regression '[TreasureTitleContrast] PASS' rendered 600 -- --capture", self.source)
        self.assertIn('"$@" || return $?', self.source)
        self.assertIn('collect_face_movie "$capture" || return $?', self.source)
        self.assertIn("check_probe cards_safe_area_regression 'CARDS_SAFE_AREA_PASS' "
                      'rendered 600 -- --capture', self.source)
        self.assertIn("check_probe mobile_safe_area_regression 'MOBILE_SAFE_AREA_PASS' "
                      'rendered 900 -- --capture', self.source)

    @staticmethod
    def fixture_layout(width, height):
        return {'schema': 1, 'settled': True, 'ui_visible': True, 'pending': 0,
                'observation_source': 'fixture', 'window_px': [width, height],
                'hand': [{'id': 'fixture-card',
                          'quad': [[100, 400], [220, 400], [220, 580], [100, 580]]}],
                'discard': {'quad': [[360, 400], [480, 400], [480, 580], [360, 580]]}}

    @staticmethod
    def fixture_png(width, height):
        def chunk(kind, data):
            return (struct.pack('>I', len(data)) + kind + data
                    + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
        return (b'\x89PNG\r\n\x1a\n'
                + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(bytes(width * 3 + 1) * height))
                + chunk(b'IEND', b''))

    def studio2020_fixture(self, root, mutation):
        """Small synthetic state/media fixtures; no engine/Android acceptance."""
        face = root / 'captures/lumo_facial_capture'
        face.mkdir()
        for name in ('teacher_scene', 'neutral', 'audio_jaw', 'blink', 'blink_intermediate',
                     'muted', 'gaze_left', 'stopped'):
            (face / (name + '.png')).write_bytes(self.fixture_png(640, 640))
        rows = []
        for step in range(144):
            audible = 31 <= step <= 53 or 60 <= step <= 65 or 96 <= step <= 107
            muted = 67 <= step <= 75
            blink = step == 43
            rows.append({'step': step, 'engine_drawn_frames': step + 1,
                'actual_jaw_weight': .4 if audible else 0, 'blink': 1 if blink else 0,
                'lid_mesh_weights': [0, 0, 0, 1, 0, 0, 0, 1] if blink else [0] * 8,
                'player': {'state': 'playing' if audible or muted else 'idle',
                    'audible': audible, 'envelopeAvailable': True, 'envelope': .5 if audible else 0,
                    'positionMs': ((step % 23) + 1) * 20 if audible or muted else 0,
                    'durationMs': 928.027210884354}})
        state = {'lesson_kind': 'syllables', 'lesson_word': 'Apfel',
            'word_source': 'res://assets/audio/voice/words/apfel.wav', 'recording_fps': 24,
            'observed_audible_jaw': True, 'observed_muted_closed': True,
            'observed_stopped_closed': True, 'observed_blink': True,
            'actual_max_jaw_weight': .4, 'rows': rows}
        media = {'streams': [
            {'codec_type': 'video', 'codec_name': 'h264', 'width': 640, 'height': 640,
             'r_frame_rate': '24/1', 'nb_read_frames': '148', 'duration': '6.166667'},
            {'codec_type': 'audio', 'codec_name': 'aac', 'nb_read_frames': '290'}]}
        # These bytes intentionally are not a movie; the pure roster validator
        # is under test. The actual encoder/decoder is exercised independently.
        (face / 'facial-runtime.avi').write_bytes(b'fixture-only AVI bytes')
        (face / 'facial-runtime.mp4').write_bytes(b'fixture-only encoded bytes')
        if mutation == 'face-missing-image':
            (face / 'blink.png').unlink()
        elif mutation == 'face-renamed-image':
            (face / 'blink.png').rename(face / 'wrong.png')
        elif mutation == 'face-dimensions':
            (face / 'neutral.png').write_bytes(self.fixture_png(641, 640))
        elif mutation == 'face-invalid-lesson':
            state['lesson_kind'] = 'invalid'
        elif mutation == 'face-false-caption':
            state['lesson_word'] = 'Sonne'
        elif mutation == 'face-wrong-original-word':
            state['word_source'] = 'res://invented.wav'
        elif mutation == 'face-short-record':
            rows.pop()
        elif mutation == 'face-repeated-step':
            rows[3]['step'] = 2
        elif mutation == 'face-stale-render-frame':
            rows[3]['engine_drawn_frames'] = 1
        elif mutation == 'face-nonfinite-weight':
            rows[39]['actual_jaw_weight'] = float('nan')
        elif mutation == 'face-no-actual-blink':
            rows[43]['lid_mesh_weights'] = [0] * 8
        elif mutation == 'face-no-audio-jaw':
            for row in rows:
                row['actual_jaw_weight'] = 0
            state['actual_max_jaw_weight'] = 0
        elif mutation == 'face-muted-motion':
            rows[68]['actual_jaw_weight'] = .1
        elif mutation == 'face-stop-still-playing':
            rows[113]['player']['state'] = 'playing'
        elif mutation == 'face-false-positive-flag':
            state['observed_muted_closed'] = False
        elif mutation == 'face-wrong-video-rate':
            media['streams'][0]['r_frame_rate'] = '60/1'
        elif mutation == 'face-wrong-video-size':
            media['streams'][0].update(width=720, height=1280)
        elif mutation == 'face-truncated-video':
            media['streams'][0]['nb_read_frames'] = '140'
        elif mutation == 'face-no-recorded-audio':
            media['streams'].pop()
        if mutation != 'face-missing-state':
            (face / 'runtime-frames.json').write_text('{' if mutation == 'face-malformed-state' else json.dumps(state))
        (face / 'movie-ffprobe.json').write_text(json.dumps(media))
        def file_record(name):
            data = (face / name).read_bytes()
            return {'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        proof = {'schema': 1, 'kind': 'actual_godot_movie', 'recording_fps': 24,
                 'source_avi': file_record('facial-runtime.avi'),
                 'encoded_movie': file_record('facial-runtime.mp4'),
                 'ffprobe': file_record('movie-ffprobe.json'),
                 'encode_exit_code': 0, 'decode_exit_code': 0, 'probe_exit_code': 0}
        if mutation == 'face-wrong-movie-hash':
            proof['encoded_movie']['sha256'] = '0' * 64
        elif mutation == 'face-movie-decode-failure':
            proof['decode_exit_code'] = 1
        elif mutation == 'face-missing-movie':
            (face / 'facial-runtime.mp4').unlink()
        if mutation != 'face-missing-movie-proof':
            (face / 'movie.json').write_text(json.dumps(proof))

        c4 = root / 'captures/connect_four_visual_capture'
        c4.mkdir()
        examples = [
            ('c4-empty-landscape', 960, 540, 0, 0, False, 'playing', '4b85b841d4981813dfcd61bc2a1232a9a665ea8be1b69f9ca192d57f2e2eb490'),
            ('c4-playing-phone', 412, 915, 2, 0, False, 'playing', 'b871ef7da990d3f31143a80caa9cd4739d91a0dcf0028e56734d61ddfcf56ab6'),
            ('c4-win-landscape', 960, 540, 7, 4, False, 'won', 'f19e96174c8d970a7d10df04259d05e99e370ef1884a5eda8682da48f09d5cc8'),
            ('c4-paused-small', 640, 360, 3, 0, True, 'playing', '6812f85731ce01cf4aed2b34962fa86644ebec07728268f9ff100252e58f99f7'),
        ]
        captures = []
        for name, width, height, count, rings, paused, phase, source in examples:
            data = self.fixture_png(width, height)
            (c4 / (name + '.png')).write_bytes(data)
            board = [1] * count + [0] * (42 - count)
            target = {'text': 'Fortsetzen', 'enabled': True, 'size_dp': [52., 52.],
                      'rect_px': [20., 20., 52., 52.], 'hit_rect_px': [20., 20., 52., 52.]}
            captures.append({'file': name + '.png', 'sha256': hashlib.sha256(data).hexdigest(),
                'size_px': [width, height], 'scope': 'visual_fixture_only', 'fixture_source_sha256': source,
                'fixture_state': {'game': 'connect_four', 'paused': paused, 'phase': phase,
                    'board': board, 'winningLine': [[5, n] for n in range(rings)], 'token': 'fixture-token', 'revision': 7},
                'geometry': {'disc_count': count, 'discs': [{'mesh_class': 'CylinderMesh'} for _ in range(count)],
                    'win_ring_count': rings, 'win_rings': [{'mesh_class': 'TorusMesh'} for _ in range(rings)],
                    'board_vertices': 14000, 'board_indices': 24192, 'board_depth': .34,
                    'original_lumo_visible': name in ('c4-empty-landscape', 'c4-win-landscape')},
                'production_layout': {'settled': True, 'window_px': [width, height],
                    'token': 'fixture-token', 'revision': 7, 'board': board},
                'input_requests_rejected': [], 'host_return_attempts': 0, 'raster_unique_samples': 99,
                'targets': [dict(target) for _ in range(9)],
                'reachable_menu_targets': [dict(target) for _ in range(4)] if paused else [],
                'caption': 'Cyan gewinnt!' if phase == 'won' else 'Gespeichert · Cyan ist dran',
                'pause_caption': 'Spiel pausiert. Deine Runde bleibt gespeichert.' if paused else ''})
        state = {'schema': 1, 'kind': 'connect_four_visual_fixture', 'read_only_fixture_host': True,
            'errors': [], 'density': 1, 'display_driver': 'X11', 'rendering_method': 'gl_compatibility',
            'source_before': {'fixture': 'a' * 64}, 'source_after': {'fixture': 'a' * 64},
            'input_events': [{'kind': 'ScreenDrag'}, {'kind': 'ScreenTouch', 'pressed': False}], 'captures': captures}
        selected = captures[2]
        if mutation == 'c4-missing-image':
            (c4 / selected['file']).unlink()
        elif mutation == 'c4-wrong-dimensions':
            data = self.fixture_png(960, 541);(c4 / selected['file']).write_bytes(data)
            selected['sha256'] = hashlib.sha256(data).hexdigest()
        elif mutation == 'c4-schema-bool':
            state['schema'] = True
        elif mutation == 'c4-android-claim':
            selected['scope'] = 'android'
        elif mutation == 'c4-mutable-host':
            state['read_only_fixture_host'] = False
        elif mutation == 'c4-reported-error':
            state['errors'] = ['fixture failure']
        elif mutation == 'c4-source-changed':
            state['source_after'] = {'fixture': 'b' * 64}
        elif mutation == 'c4-headless':
            state['display_driver'] = 'headless'
        elif mutation == 'c4-missing-swipe':
            state['input_events'] = []
        elif mutation == 'c4-wrong-original-fixture':
            selected['fixture_source_sha256'] = '0' * 64
        elif mutation == 'c4-wrong-image-hash':
            selected['sha256'] = '0' * 64
        elif mutation == 'c4-wrong-discs':
            selected['geometry']['disc_count'] = 6
        elif mutation == 'c4-hidden-wide-lumo':
            selected['geometry']['original_lumo_visible'] = False
        elif mutation == 'c4-visible-small-lumo':
            captures[1]['geometry']['original_lumo_visible'] = True
        elif mutation == 'c4-flat-board':
            selected['geometry']['board_depth'] = 0
        elif mutation == 'c4-no-win-rings':
            selected['geometry']['win_rings'] = []
        elif mutation == 'c4-stale-layout':
            selected['production_layout']['revision'] = 6
        elif mutation == 'c4-unsettled':
            selected['production_layout']['settled'] = False
        elif mutation == 'c4-fake-action':
            selected['input_requests_rejected'] = ['not allowed here']
        elif mutation == 'c4-small-target':
            selected['targets'][0]['size_dp'] = [48, 47.98]
        elif mutation == 'c4-clipped-target':
            selected['targets'][0]['hit_rect_px'] = [20., 20., 40., 52.]
        elif mutation == 'c4-wrong-win-caption':
            selected['caption'] = 'Playing'
        elif mutation == 'c4-pause-no-resume':
            captures[-1]['reachable_menu_targets'] = []
        if mutation != 'c4-missing-state':
            (c4 / 'visual-state.json').write_text('{' if mutation == 'c4-malformed-state' else json.dumps(state))

    def treasure_title_fixture(self, root, mutation):
        """Synthetic report contracts, not an additional renderer execution."""
        folder = root / 'captures/treasure_title_contrast_regression'
        folder.mkdir()
        profiles = [
            ('landscape', 1920, 1080, 1.5, [112, 36, 0, 24]),
            ('compact', 640, 320, 1.0, [0, 0, 0, 0]),
            ('portrait', 1080, 2400, 2.625, [0, 136, 0, 63]),
            ('fold', 2176, 1812, 2.25, [0, 136, 0, 63]),
            ('landscape-cutout', 2400, 1080, 2.625, [136, 63, 0, 63]),
        ]
        observations = []
        for profile, width, height, density, insets in profiles:
            path = folder / f'treasure-title-{profile}.png'
            data = self.fixture_png(width, height)
            path.write_bytes(data)
            left, top, right, bottom = insets
            safe_width, safe_height = width - left - right, height - top - bottom
            avatar = [left + safe_width / 2 - 20, top + safe_height / 2 - 20, 40, 40]
            clue_role = 'hint' if profile in ('compact', 'landscape-cutout') else 'clue'
            boxes = {
                'header': [left + 12, top + 12, safe_width - 24, 48 * density],
                clue_role: [left + 12, top + 72 * density, 48 * density, 48 * density],
                'toast': [left + safe_width / 2 - 48 * density, height - bottom - 12 - 48 * density, 96 * density, 48 * density],
                'joystick': [left + 12, height - bottom - 12 - 48 * density, 48 * density, 48 * density],
                'action': [width - right - 12 - 48 * density, height - bottom - 12 - 48 * density, 48 * density, 48 * density],
                'jump': [width - right - 12 - 48 * density, height - bottom - 24 - 96 * density, 48 * density, 48 * density],
            }
            for restored in (False, True):
                item = {'profile': profile, 'window_px': [width, height],
                    'density': density, 'insets_fixture': list(insets),
                    'title_rect': [left + 12, top + 12, 360, 42 * density],
                    'worst_white_backdrop_contrast': 14.4422647052388,
                    'initial_state_fixture': 'original86445 first tree save' if restored else 'production fresh start',
                    'gameplay_view': {'avatar_rect_px': list(avatar),
                        'secondary_white_backdrop_contrast': 14.4422647052388,
                        'hud_rects': [{'role': role, 'name': f'Fixture-{role}', 'rect_px': list(bounds),
                                       'overlap_px': [0, 0, 0, 0]} for role, bounds in boxes.items()]}}
                recorded = not restored if profile == 'landscape-cutout' else restored
                if recorded:
                    item.update(image=str(path), image_sha256=hashlib.sha256(data).hexdigest(),
                                image_px=[width, height])
                observations.append(item)
        state = {'checks': 3341, 'failures': [], 'observations': observations,
                 'scope': 'Production HUD, real ScreenTouch, declared saved-position and Android-boundary fixture; not device execution'}
        chosen = observations[3]
        image = folder / Path(chosen['image']).name
        view = chosen['gameplay_view']
        hud = {region['role']: region for region in view['hud_rects']}
        if mutation == 'title-missing-image':
            image.unlink()
        elif mutation == 'title-renamed-image':
            image.rename(folder / 'wrong.png')
        elif mutation == 'title-wrong-dimensions':
            data = self.fixture_png(640, 321)
            image.write_bytes(data)
            chosen['image_sha256'] = hashlib.sha256(data).hexdigest()
        elif mutation == 'title-reported-failure':
            state['failures'] = ['bad contrast']
        elif mutation == 'title-partial-checks':
            state['checks'] = 129
        elif mutation == 'title-boolean-checks':
            state['checks'] = True
        elif mutation == 'title-old-four-case-checks':
            state['checks'] = 137
        elif mutation == 'visibility-pre-spacing-checks':
            state['checks'] = 3273
        elif mutation == 'title-missing-profile':
            observations.pop()
        elif mutation == 'title-duplicate-profile':
            observations[-1] = dict(chosen)
        elif mutation == 'title-wrong-image-hash':
            chosen['image_sha256'] = '0' * 64
        elif mutation == 'title-wrong-reported-image':
            chosen['image'] = str(folder / 'treasure-title-portrait.png')
        elif mutation == 'title-wrong-window':
            chosen['window_px'] = [640, 321]
        elif mutation == 'title-wrong-density':
            chosen['density'] = 2
        elif mutation == 'title-wrong-insets':
            observations[0]['insets_fixture'] = [0, 36, 112, 24]
        elif mutation == 'title-wrong-fixture':
            chosen['initial_state_fixture'] = 'invented progress'
        elif mutation == 'title-low-contrast':
            chosen['worst_white_backdrop_contrast'] = 6.99
        elif mutation == 'title-nonfinite-contrast':
            chosen['worst_white_backdrop_contrast'] = float('nan')
        elif mutation == 'title-offscreen':
            chosen['title_rect'] = [630, 12, 360, 42]
        elif mutation == 'title-zero-area':
            chosen['title_rect'][2] = 0
        elif mutation == 'title-device-claim':
            state['scope'] = 'actual Android'
        elif mutation == 'visibility-missing-cutout-image':
            (folder / 'treasure-title-landscape-cutout.png').unlink()
        elif mutation == 'visibility-cutout-dimensions':
            data = self.fixture_png(2399, 1080)
            (folder / 'treasure-title-landscape-cutout.png').write_bytes(data)
            observations[8]['image_sha256'] = hashlib.sha256(data).hexdigest()
        elif mutation == 'visibility-cutout-insets-swapped':
            observations[8]['insets_fixture'] = [0, 63, 136, 63]
        elif mutation == 'visibility-cutout-capture-restored':
            for key in ('image', 'image_px', 'image_sha256'):
                observations[9][key] = observations[8].pop(key)
        elif mutation == 'visibility-extra-fresh-capture':
            for key in ('image', 'image_px', 'image_sha256'):
                observations[0][key] = observations[1][key]
        elif mutation == 'visibility-partial-unrecorded-image':
            observations[0]['image_sha256'] = observations[1]['image_sha256']
        elif mutation == 'visibility-missing-fresh':
            observations.pop(8)
        elif mutation == 'visibility-duplicate-restored':
            observations[8] = dict(observations[9])
        elif mutation == 'visibility-unrecorded-fresh-avatar-covered':
            fresh = observations[0]['gameplay_view']
            fresh['hud_rects'][0]['rect_px'] = list(fresh['avatar_rect_px'])
        elif mutation == 'visibility-unrecorded-fresh-low-contrast':
            observations[0]['gameplay_view']['secondary_white_backdrop_contrast'] = 6.99
        elif mutation == 'visibility-missing-avatar':
            view.pop('avatar_rect_px')
        elif mutation == 'visibility-zero-avatar':
            view['avatar_rect_px'][2] = 0
        elif mutation == 'visibility-nonfinite-avatar':
            view['avatar_rect_px'][0] = float('nan')
        elif mutation == 'visibility-avatar-offscreen':
            view['avatar_rect_px'][0] = 639
        elif mutation == 'visibility-missing-hud':
            view['hud_rects'].pop()
        elif mutation == 'visibility-duplicate-role':
            hud['jump']['role'] = 'action'
        elif mutation == 'visibility-no-role':
            hud['jump'].pop('role')
        elif mutation == 'visibility-compact-clue-instead-of-hint':
            hud['hint']['role'] = 'clue'
        elif mutation == 'visibility-tall-hint-instead-of-clue':
            observations[4]['gameplay_view']['hud_rects'][1]['role'] = 'hint'
        elif mutation == 'visibility-empty-control-name':
            hud['jump']['name'] = ''
        elif mutation == 'visibility-nonfinite-hud':
            hud['jump']['rect_px'][0] = float('inf')
        elif mutation == 'visibility-zero-hud':
            hud['toast']['rect_px'][2] = 0
        elif mutation == 'visibility-unsafe-hud':
            observations[8]['gameplay_view']['hud_rects'][0]['rect_px'][0] = 0
        elif mutation == 'visibility-hud-overlap-despite-zero-report':
            hud['toast']['rect_px'] = list(view['avatar_rect_px'])
        elif mutation == 'visibility-false-overlap-report':
            hud['toast']['overlap_px'] = [0, 0, 1, 1]
        elif mutation == 'visibility-toast-covers-jump':
            hud['toast']['rect_px'] = list(hud['jump']['rect_px'])
        elif mutation == 'visibility-toast-covers-hint':
            hud['toast']['rect_px'] = list(hud['hint']['rect_px'])
        elif mutation == 'visibility-small-touch':
            hud['jump']['rect_px'][3] = 47.98
        elif mutation == 'visibility-low-secondary-contrast':
            view['secondary_white_backdrop_contrast'] = 6.99
        elif mutation == 'visibility-nonfinite-secondary-contrast':
            view['secondary_white_backdrop_contrast'] = float('nan')
        if mutation != 'title-missing-report':
            (folder / 'treasure-title-report.json').write_text(
                '{' if mutation == 'title-malformed-report' else json.dumps(state))

    def write_roster_fixture(self, root, mutation=''):
        """Populate explicitly synthetic source files for both gate test paths."""
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
        cards = root / 'captures/cards_safe_area_regression'
        cards.mkdir()
        for name, width, height in (
                ('android35_portrait-playing', 1080, 2400),
                ('android35_portrait-paused', 1080, 2400),
                ('landscape_cutout_fixture-playing', 2400, 1080)):
            (cards / f'{name}.png').write_bytes(self.fixture_png(width, height))
            (cards / f'{name}.layout.json').write_text(
                json.dumps(self.fixture_layout(width, height), sort_keys=True) + '\n')
        mobile = root / 'captures/mobile_safe_area_regression'
        mobile.mkdir()
        mobile_report = {
            'failures': [],
            'targets': [{'name': f'fixture-{index}', 'fully_inside_true_safe_area': True,
                         'exposed_dp': [48.0, 48.0]} for index in range(15)],
            'images': [],
        }
        for module in ('jump', 'build', 'puzzle', 'treasure'):
            path = mobile / f'{module}-landscape-cutout.png'
            data = self.fixture_png(2400, 1080)
            path.write_bytes(data)
            mobile_report['images'].append({'path': path.name,
                                           'sha256': hashlib.sha256(data).hexdigest()})
        selected = folder / '640x360-rotation-menu.png'
        if mutation == 'missing':
            selected.unlink()
        elif mutation == 'renamed':
            selected.rename(folder / 'wrong-scene.png')
        elif mutation == 'dimensions':
            selected.write_bytes(self.fixture_png(640, 361))
        elif mutation == 'legacy-short-image':
            (root / 'captures/learning_sharing_capture/fixture-0.png').write_bytes(self.fixture_png(640, 320))
        card_png = cards / 'landscape_cutout_fixture-playing.png'
        card_layout = card_png.with_suffix('.layout.json')
        layout_changes = {
            'cards-schema-bool': {'schema': True},
            'cards-schema-version': {'schema': 2},
            'cards-unsettled': {'settled': False},
            'cards-hidden': {'ui_visible': False},
            'cards-pending': {'pending': 1},
            'cards-wrong-source': {'observation_source': 'android'},
            'cards-window-mismatch': {'window_px': [2400, 1081]},
            'cards-no-hand': {'hand': []},
            'cards-no-discard-quad': {'discard': {'quad': []}},
        }
        if mutation == 'cards-missing-image':
            card_png.unlink()
        elif mutation == 'cards-missing-layout':
            card_layout.unlink()
        elif mutation == 'cards-malformed-layout':
            card_layout.write_text('{')
        elif mutation in layout_changes:
            layout = json.loads(card_layout.read_text())
            layout.update(layout_changes[mutation])
            card_layout.write_text(json.dumps(layout))
        mobile_image = mobile / 'treasure-landscape-cutout.png'
        if mutation == 'mobile-missing-image':
            mobile_image.unlink()
        elif mutation == 'mobile-renamed-image':
            mobile_image.rename(mobile / 'wrong-scene.png')
        elif mutation == 'mobile-dimensions':
            mobile_image.write_bytes(self.fixture_png(2400, 1081))
        elif mutation == 'mobile-reported-failure':
            mobile_report['failures'].append('fixture unsafe target')
        elif mutation == 'mobile-missing-target':
            mobile_report['targets'].pop()
        elif mutation == 'mobile-unsafe-target':
            mobile_report['targets'][-1]['fully_inside_true_safe_area'] = False
        elif mutation == 'mobile-small-target':
            mobile_report['targets'][-1]['exposed_dp'] = [48.0, 47.94]
        elif mutation == 'mobile-wrong-hash':
            mobile_report['images'][-1]['sha256'] = '0' * 64
        elif mutation == 'mobile-missing-roster-entry':
            mobile_report['images'].pop()
        elif mutation == 'mobile-extra-roster-entry':
            mobile_report['images'].append({'path': 'extra.png', 'sha256': '0' * 64})
        if mutation != 'mobile-missing-report':
            (mobile / 'mobile-safe-area.json').write_text(
                '{' if mutation == 'mobile-malformed-report' else json.dumps(mobile_report))
        self.studio2020_fixture(root, mutation)
        self.treasure_title_fixture(root, mutation)

    def roster_fixture(self, mutation=''):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_roster_fixture(root, mutation)
            result = subprocess.run([sys.executable, '-', str(root)], input=self.roster,
                                    text=True, capture_output=True, timeout=15)
            report = root / 'renderer-images.json'
            return result, json.loads(report.read_text()) if report.exists() else None

    def test_all_thirty_seven_required_rasters_and_named_menu_views_are_enforced(self):
        result, report = self.roster_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(report['images']), 54)
        self.assertEqual(sum(1 for image in report['images'] if Path(image['path']).parts[1] not in ('lumo_facial_capture', 'connect_four_visual_capture', 'treasure_title_contrast_regression')), 37)
        counts = {}
        for image in report['images']:
            probe = Path(image['path']).parts[1]
            counts[probe] = counts.get(probe, 0) + 1
            if probe == 'cards_safe_area_regression':
                layout_data = (json.dumps(self.fixture_layout(image['width'], image['height']),
                                          sort_keys=True) + '\n').encode()
                self.assertEqual(image['native_layout'], {
                    'path': str(Path(image['path']).with_suffix('.layout.json')),
                    'bytes': len(layout_data), 'sha256': hashlib.sha256(layout_data).hexdigest(),
                })
        self.assertEqual(counts, {
            'learning_sharing_capture': 6, 'lumo_studio_motion_capture': 8,
            'puzzle_rotation_regression': 7, 'treasure_exploration_regression': 3,
            'puzzle_menu_lifecycle_regression': 6,
            'cards_safe_area_regression': 3, 'mobile_safe_area_regression': 4,
            'lumo_facial_capture': 8, 'connect_four_visual_capture': 4,
            'treasure_title_contrast_regression': 5,
        })
        for mutation in ('missing', 'renamed', 'dimensions', 'legacy-short-image'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_cards_require_each_raster_and_settled_matching_layout_sidecar(self):
        for mutation in (
                'cards-missing-image', 'cards-missing-layout', 'cards-malformed-layout',
                'cards-schema-bool', 'cards-schema-version', 'cards-unsettled', 'cards-hidden',
                'cards-pending', 'cards-wrong-source', 'cards-window-mismatch',
                'cards-no-hand', 'cards-no-discard-quad'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_mobile_requires_all_named_images_and_safe_hash_bound_target_report(self):
        for mutation in (
                'mobile-missing-image', 'mobile-renamed-image', 'mobile-dimensions',
                'mobile-missing-report', 'mobile-malformed-report', 'mobile-reported-failure',
                'mobile-missing-target', 'mobile-unsafe-target', 'mobile-small-target',
                'mobile-wrong-hash', 'mobile-missing-roster-entry', 'mobile-extra-roster-entry'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_face_requires_valid_lesson_actual_mesh_audio_and_decoded_bound_movie(self):
        for mutation in (
                'face-missing-image', 'face-renamed-image', 'face-dimensions',
                'face-missing-state', 'face-malformed-state', 'face-invalid-lesson',
                'face-false-caption', 'face-wrong-original-word', 'face-short-record',
                'face-repeated-step', 'face-stale-render-frame', 'face-nonfinite-weight',
                'face-no-actual-blink', 'face-no-audio-jaw', 'face-muted-motion',
                'face-stop-still-playing', 'face-false-positive-flag',
                'face-wrong-video-rate', 'face-wrong-video-size',
                'face-truncated-video', 'face-no-recorded-audio',
                'face-wrong-movie-hash', 'face-movie-decode-failure',
                'face-missing-movie', 'face-missing-movie-proof'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_c4_fixture_requires_real_geometry_safe_targets_and_original_bound_states(self):
        for mutation in (
                'c4-missing-image', 'c4-wrong-dimensions', 'c4-missing-state',
                'c4-malformed-state', 'c4-schema-bool', 'c4-android-claim',
                'c4-mutable-host', 'c4-reported-error', 'c4-source-changed',
                'c4-headless', 'c4-missing-swipe', 'c4-wrong-original-fixture',
                'c4-wrong-image-hash', 'c4-wrong-discs', 'c4-hidden-wide-lumo',
                'c4-visible-small-lumo', 'c4-flat-board',
                'c4-no-win-rings', 'c4-stale-layout', 'c4-unsettled', 'c4-fake-action',
                'c4-small-target', 'c4-clipped-target', 'c4-wrong-win-caption',
                'c4-pause-no-resume'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_new_roster_entries_bind_sidecars_and_the_recorded_movie(self):
        result, report = self.roster_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        faces = [row for row in report['images'] if '/lumo_facial_capture/' in row['path']]
        self.assertEqual(len(faces), 8)
        for row in faces:
            self.assertEqual(row['facial_runtime']['path'], 'captures/lumo_facial_capture/runtime-frames.json')
            self.assertEqual(row['facial_movie']['path'], 'captures/lumo_facial_capture/facial-runtime.mp4')
            self.assertEqual(row['facial_movie']['proof']['path'], 'captures/lumo_facial_capture/movie.json')
            self.assertRegex(row['facial_movie']['sha256'], r'^[a-f0-9]{64}$')
        c4 = [row for row in report['images'] if '/connect_four_visual_capture/' in row['path']]
        self.assertEqual(len(c4), 4)
        for row in c4:
            self.assertEqual(row['connect_four_visual_state']['path'], 'captures/connect_four_visual_capture/visual-state.json')
            self.assertRegex(row['connect_four_visual_state']['sha256'], r'^[a-f0-9]{64}$')
        treasure = [row for row in report['images'] if '/treasure_title_contrast_regression/' in row['path']]
        self.assertEqual(len(treasure), 5)
        for row in treasure:
            self.assertEqual(row['treasure_title_report']['path'], 'captures/treasure_title_contrast_regression/treasure-title-report.json')
            self.assertGreater(row['treasure_title_report']['bytes'], 0)
            self.assertRegex(row['treasure_title_report']['sha256'], r'^[a-f0-9]{64}$')

    def test_treasure_title_requires_five_hash_bound_contrast_and_safe_layout_reports(self):
        for mutation in (
                'title-missing-image', 'title-renamed-image', 'title-wrong-dimensions',
                'title-missing-report', 'title-malformed-report', 'title-reported-failure',
                'title-partial-checks', 'title-boolean-checks', 'title-missing-profile',
                'title-duplicate-profile', 'title-wrong-image-hash', 'title-wrong-reported-image',
                'title-wrong-window', 'title-wrong-density', 'title-wrong-insets',
                'title-wrong-fixture', 'title-low-contrast', 'title-nonfinite-contrast',
                'title-offscreen', 'title-zero-area', 'title-device-claim'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_treasure_requires_both_start_states_and_exact_cutout_capture_assignment(self):
        for mutation in (
                'visibility-missing-cutout-image', 'visibility-cutout-dimensions',
                'visibility-cutout-insets-swapped', 'visibility-cutout-capture-restored',
                'visibility-extra-fresh-capture', 'visibility-partial-unrecorded-image',
                'visibility-missing-fresh', 'visibility-duplicate-restored',
                'visibility-unrecorded-fresh-avatar-covered',
                'visibility-unrecorded-fresh-low-contrast', 'title-old-four-case-checks',
                'visibility-pre-spacing-checks'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_treasure_requires_actual_avatar_and_complete_semantic_hud_bounds(self):
        for mutation in (
                'visibility-missing-avatar', 'visibility-zero-avatar',
                'visibility-nonfinite-avatar', 'visibility-avatar-offscreen',
                'visibility-missing-hud', 'visibility-duplicate-role', 'visibility-no-role',
                'visibility-compact-clue-instead-of-hint',
                'visibility-tall-hint-instead-of-clue', 'visibility-empty-control-name',
                'visibility-nonfinite-hud', 'visibility-zero-hud', 'visibility-unsafe-hud'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_treasure_recomputes_occlusion_and_preserves_accessible_hint_and_message(self):
        for mutation in (
                'visibility-hud-overlap-despite-zero-report', 'visibility-false-overlap-report',
                'visibility-toast-covers-jump', 'visibility-toast-covers-hint',
                'visibility-small-touch', 'visibility-low-secondary-contrast',
                'visibility-nonfinite-secondary-contrast'):
            with self.subTest(mutation=mutation):
                result, report = self.roster_fixture(mutation)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(report)

    def test_new_workflow_preserves_all_required_jobs_and_exact_source_archive(self):
        workflow = (ROOT / '.github/workflows/lumo-studio-2020.yml').read_text()
        self.assertIn('branches: [chatgpt/lumo-studio-2020-20261114]', workflow)
        self.assertIn('scope: [workshop, treasure, build]', workflow)
        for job in ('learning-preview', 'gameplay', 'new-worlds', 'studio', 'touch-density', 'bundle-evidence', 'archive-evidence'):
            self.assertIn('  ' + job + ':', workflow)
        self.assertIn('needs: [learning-preview, gameplay, new-worlds, studio, touch-density, bundle-evidence]', workflow)
        self.assertIn('name: lumo-studio-2020-native-evidence', workflow)
        self.assertNotIn('lumo-studio-2019-', workflow)
        self.assertIn('tag="studio-2020-evidence-$SOURCE_SHA-$artifact_id"', workflow)
        self.assertIn('cmp native-evidence.zip public-native-evidence.zip', workflow)
        self.assertIn('--prerelease --latest=false', workflow)
        self.assertNotIn('--clobber', workflow)
        self.assertIn('ffmpeg', workflow.split('\n  studio:\n')[1].split('\n  touch-density:\n')[0])

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
