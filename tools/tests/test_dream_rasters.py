#!/usr/bin/env python3
"""Small synthetic counterexamples for the separate Dream evidence reader."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw, PngImagePlugin

TOOLS = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('dream_rasters_under_test', TOOLS / 'verify_dream_rasters.py')
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


def raster(path, size, marker=0, *, transparent=False, uniform=False, note=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new('RGBA', size, (28, 45, 80, 0 if transparent else 255))
    if not uniform:
        ImageDraw.Draw(image).rectangle((8 + marker, 8, 32 + marker, 32),
                                       fill=(240, 170, 60, 0 if transparent else 255))
    info = PngImagePlugin.PngInfo()
    if note is not None:
        info.add_text('synthetic-fixture', note)
    image.save(path, pnginfo=info)
    image.close()


def fixture(root):
    original_root = '/original-ci/dream'
    (root / 'capture-root.txt').write_text(original_root + '\n')
    for kind, value in [('sha', 'a' * 40), ('tree', 'b' * 40)]:
        for suffix in ['', '-after']:
            (root / f'source-{kind}{suffix}.txt').write_text(value + '\n')
    for name in ['source-dirty.txt', 'source-dirty-after.txt']:
        (root / name).write_bytes(b'')
    (root / 'engine.txt').write_text(GATE.ENGINE + '\n')
    data = b'synthetic tracked source\n'
    blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    inventory = {'schema': 1, 'head': 'a' * 40, 'tree': 'b' * 40, 'index_sha256': 'c' * 64,
                 'tracked': [{'path': 'scripts/synthetic.gd', 'git_blob': blob, 'actual_blob': blob,
                              'mode': '100644', 'skip_worktree': False, 'materialized': True,
                              'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}],
                 'untracked_import_inventory': [
                     {'path': 'scripts/synthetic.gd.uid', 'category': 'generated_uid',
                      'tracked_owner': 'scripts/synthetic.gd', 'mode': '100644', 'bytes': 15,
                      'actual_blob': 'd' * 40, 'sha256': 'e' * 64}]}
    for phase in ('before', 'after'):
        (root / ('source-inventory-' + phase + '.json')).write_text(json.dumps(inventory))
    (root / 'results.tsv').write_text('probe\tmode\tresult\n' + ''.join(
        f'{name}\t{mode}\tPASS\n' for name, mode, _ in GATE.PROBES))
    for name, mode, marker in GATE.PROBES:
        (root / f'{name}-{mode}.log').write_text(
            'Godot Engine v' + GATE.ENGINE + ' - synthetic evidence fixture\n' +
            marker.format(capture_root=original_root) + '\n')
    for world, (preset, motes, butterflies) in GATE.WORLD_COUNTS.items():
        frames = []
        for index in range(2):
            relative = f'captures/{world}/{world}_{index:02}.png'
            raster(root / relative, (128, 96), index)
            frames.append({'path': original_root + '/' + relative, 'width': 128, 'height': 96,
                           'ambience': {'preset': preset, 'tier': 'high', 'motes': motes,
                                        'butterflies': butterflies, 'animation_time': 0.5 + index,
                                        'reduced_motion': False, 'batches': 2}})
        report = {'scene': f'res://scenes/{"creative" if world == "treasure" else "learning"}/{world}_world.tscn',
                  'display': 'X11', 'renderer': 'gl_compatibility', 'frames': frames,
                  'device_fps_measured': False}
        (root / f'captures/{world}/{world}.json').write_text(json.dumps(report))
    for width, height in GATE.GARDEN:
        raster(root / f'captures/garden/learning-dream-{width}x{height}.png', (width, height))


class DreamRasterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='lumo-dream-reader-')
        self.root = Path(self.directory.name)
        fixture(self.root)

    def tearDown(self):
        self.directory.cleanup()

    def report(self, world='treasure'):
        path = self.root / f'captures/{world}/{world}.json'
        return path, json.loads(path.read_bytes())

    def test_complete_contract_and_read_only_recomputation(self):
        result = GATE.verify(self.root, write=True)
        self.assertEqual((len(result['probes']), len(result['original_pngs']), len(result['original_reports'])),
                         (5, 7, 2))
        self.assertEqual(result['untracked_inventory_counts'][0]['generated_uid'], 1)
        before = {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(GATE.verify(self.root, write=False), result)
        self.assertEqual(before, {p.relative_to(self.root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in self.root.rglob('*') if p.is_file()})

    def test_failed_or_duplicate_probe_pairs_are_rejected(self):
        path = self.root / 'results.tsv'
        original = path.read_text()
        for content in [original.replace('PASS', 'FAIL', 1), original + original.splitlines(True)[1]]:
            path.write_text(content)
            with self.subTest(content=content), self.assertRaisesRegex(ValueError, 'five exact'):
                GATE.verify(self.root)

    def test_missing_or_extra_capture_is_rejected(self):
        path = self.root / 'captures/treasure/treasure_01.png'
        original = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'capture files'):
            GATE.verify(self.root)
        path.write_bytes(original)
        (self.root / 'captures/unrequested.png').write_bytes(original)
        with self.assertRaisesRegex(ValueError, 'capture files'):
            GATE.verify(self.root)

    def test_invalid_png_cannot_be_a_header_only_success(self):
        path = self.root / 'captures/treasure/treasure_01.png'
        path.write_bytes(path.read_bytes()[:40])
        with self.assertRaises((OSError, ValueError, SyntaxError)):
            GATE.verify(self.root)

    def test_equal_pixels_fail_even_with_different_png_metadata(self):
        path = self.root / 'captures/treasure/treasure_01.png'
        raster(path, (128, 96), 0, note='different bytes but same displayed pixels')
        self.assertNotEqual(path.read_bytes(), (path.parent / 'treasure_00.png').read_bytes())
        with self.assertRaisesRegex(ValueError, 'pixels did not change'):
            GATE.verify(self.root)

    def test_clock_must_advance(self):
        path, report = self.report()
        report['frames'][1]['ambience']['animation_time'] = report['frames'][0]['ambience']['animation_time']
        path.write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, 'clock did not advance'):
            GATE.verify(self.root)

    def test_report_path_scene_and_geometry_counts_are_bound(self):
        path, report = self.report()
        original = json.dumps(report)
        mutations = [lambda x: x['frames'][0].update(path='/unrelated/treasure_00.png'),
                     lambda x: x.update(scene='res://scenes/creative/puzzle_world.tscn'),
                     lambda x: x['frames'][0]['ambience'].update(batches=True)]
        for mutate in mutations:
            changed = json.loads(original)
            mutate(changed)
            path.write_text(json.dumps(changed))
            with self.subTest(mutation=mutate), self.assertRaises(ValueError):
                GATE.verify(self.root)

    def test_garden_dimensions_remain_exact(self):
        raster(self.root / 'captures/garden/learning-dream-412x915.png', (412, 914))
        with self.assertRaisesRegex(ValueError, 'dimensions'):
            GATE.verify(self.root)

    def test_uniform_and_invisible_frames_are_rejected(self):
        path = self.root / 'captures/treasure/treasure_00.png'
        for options in [{'uniform': True}, {'transparent': True}]:
            raster(path, (128, 96), **options)
            with self.subTest(options=options), self.assertRaises(ValueError):
                GATE.verify(self.root)

    def test_errors_after_success_and_duplicate_markers_still_fail(self):
        name, mode, marker = GATE.PROBES[0]
        path = self.root / f'{name}-{mode}.log'
        original = path.read_text()
        for suffix in ['ERROR: original failure\n', 'WARNING: ObjectDB instances leaked at exit\n', marker + '\n']:
            path.write_text(original + suffix)
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                GATE.verify(self.root)

    def test_changed_or_dirty_source_fails(self):
        path = self.root / 'source-tree-after.txt'
        path.write_text('c' * 40 + '\n')
        with self.assertRaisesRegex(ValueError, 'Native tree'):
            GATE.verify(self.root)
        path.write_text('b' * 40 + '\n')
        (self.root / 'source-dirty-after.txt').write_text(' M project.godot\n')
        with self.assertRaisesRegex(ValueError, 'dirty'):
            GATE.verify(self.root)
        (self.root / 'source-dirty-after.txt').write_text('')
        inventory_path = self.root / 'source-inventory-after.json'
        inventory = json.loads(inventory_path.read_bytes())
        inventory['index_sha256'] = 'd' * 64
        inventory_path.write_text(json.dumps(inventory))
        with self.assertRaisesRegex(ValueError, 'Git index changed'):
            GATE.verify(self.root)

    def test_capture_and_manifest_symlinks_are_rejected(self):
        path = self.root / 'captures/treasure/treasure_01.png'
        original = path.read_bytes()
        path.unlink()
        path.symlink_to(path.parent / 'treasure_00.png')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            GATE.verify(self.root)
        path.unlink()
        path.write_bytes(original)
        (self.root / 'dream-images.json').symlink_to(self.root / 'engine.txt')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            GATE.verify(self.root, write=True)


if __name__ == '__main__':
    unittest.main()
