"""Synthetic byte/sidecar counterexamples; these are never visual acceptance."""
from functools import lru_cache
import hashlib
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import verify_safe_area_rasters as verifier


@lru_cache(maxsize=2)
def raster(width: int, height: int) -> bytes:
    image = Image.new('RGB', (width, height), '#224466')
    ImageDraw.Draw(image).rectangle((width // 2, 0, width - 1, height - 1), fill='#b08020')
    output = BytesIO()
    image.save(output, format='PNG')
    return output.getvalue()


def write_fixture(root: Path) -> None:
    """Model the published JSON boundaries with explicitly synthetic pixels."""
    cards_images, mobile_images = [], []
    for relative, dimensions in {**verifier.CARDS_PNGS, **verifier.MOBILE_PNGS}.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        pixels = raster(*dimensions)
        path.write_bytes(pixels)
        if relative in verifier.CARDS_PNGS:
            layout = {
                'schema': 1, 'layout_sequence': 1, 'pending': 0,
                'settled': True, 'ui_visible': True, 'observation_source': 'fixture',
                'window_px': list(dimensions), 'paused': path.name.endswith('-paused.png'),
                'hand': [{'id': 'fixture-hand', 'quad': [[20, 20], [80, 20], [80, 100], [20, 100]]}],
                'discard': {'id': 'fixture-discard', 'quad': [[120, 20], [180, 20], [180, 100], [120, 100]]},
            }
            path.with_suffix('.layout.json').write_text(json.dumps(layout))
            cards_images.append({'path': str(path), 'size': list(dimensions)})
        else:
            mobile_images.append({'path': path.name, 'width': dimensions[0], 'height': dimensions[1],
                                  'sha256': hashlib.sha256(pixels).hexdigest()})
    cards = {'checks': 1, 'failures': [], 'renderer': 'fixture-display',
             'android_device_measurement': False, 'images': cards_images}
    mobile = {'checks': 1, 'failures': [],
              'targets': [{'fully_inside_true_safe_area': True, 'exposed_dp': [48, 48]} for _ in range(15)],
              'images': mobile_images}
    (root / verifier.CARDS_DIRECTORY / 'cards-safe-area.json').write_text(json.dumps(cards))
    (root / verifier.MOBILE_DIRECTORY / 'mobile-safe-area.json').write_text(json.dumps(mobile))


class SafeAreaRasterTests(unittest.TestCase):
    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        write_fixture(root)
        return root

    def assert_no_complete_manifest(self, root):
        with self.assertRaises((OSError, ValueError)):
            verifier.verify(root)
        self.assertFalse((root / 'safe-area-images.json').exists())

    def test_complete_manifest_binds_seven_original_rasters_three_layouts_and_two_reports(self):
        root = self.fixture()
        result = verifier.verify(root)
        expected = {**verifier.CARDS_PNGS, **verifier.MOBILE_PNGS}
        self.assertEqual({row['path']: (row['width'], row['height']) for row in result['images']}, expected)
        self.assertEqual(result['schema'], 1)
        self.assertEqual(len(result['reports']), 2)
        self.assertEqual(sum('native_layout' in row for row in result['images']), 3)
        for row in result['images'] + result['reports']:
            data = (root / row['path']).read_bytes()
            self.assertEqual(row['sha256'], hashlib.sha256(data).hexdigest())
            self.assertEqual(row['bytes'], len(data))
        for row in result['images']:
            if 'native_layout' in row:
                layout = row['native_layout']
                self.assertEqual(layout['path'], str(Path(row['path']).with_suffix('.layout.json')))
                self.assertEqual(layout['sha256'], hashlib.sha256((root / layout['path']).read_bytes()).hexdigest())
        self.assertEqual(json.loads((root / 'safe-area-images.json').read_text()), result)

    def test_every_missing_renamed_truncated_uniform_or_wrong_size_original_rejects(self):
        for relative in {**verifier.CARDS_PNGS, **verifier.MOBILE_PNGS}:
            root = self.fixture()
            (root / relative).unlink()
            with self.subTest(missing=relative):
                self.assert_no_complete_manifest(root)
        for mutation in ('renamed', 'truncated', 'uniform', 'dimensions', 'symlink'):
            root = self.fixture()
            path = root / next(iter(verifier.CARDS_PNGS))
            if mutation == 'renamed': path.rename(path.with_name('unexpected.png'))
            if mutation == 'truncated': path.write_bytes(path.read_bytes()[:40])
            if mutation == 'uniform': Image.new('RGB', (1080, 2400), '#224466').save(path)
            if mutation == 'dimensions': path.write_bytes(raster(2400, 1080))
            if mutation == 'symlink':
                original = root / 'outside.png'
                path.rename(original)
                path.symlink_to(original)
            with self.subTest(mutation=mutation):
                self.assert_no_complete_manifest(root)

    def test_missing_unsettled_foreign_or_mismatched_cards_layout_rejects(self):
        for mutation in ('missing', 'schema-bool', 'sequence-float', 'pending', 'unsettled', 'hidden',
                         'wrong-source', 'viewport', 'phase', 'hand', 'discard', 'empty-id', 'nonfinite'):
            root = self.fixture()
            path = (root / next(iter(verifier.CARDS_PNGS))).with_suffix('.layout.json')
            layout = json.loads(path.read_text())
            if mutation == 'missing': path.unlink()
            else:
                field, value = {
                    'schema-bool': ('schema', True), 'pending': ('pending', 1),
                    'sequence-float': ('layout_sequence', 1.0),
                    'unsettled': ('settled', False), 'hidden': ('ui_visible', False),
                    'wrong-source': ('observation_source', 'android_window_insets'),
                    'viewport': ('window_px', [2400, 1080]), 'phase': ('paused', True),
                    'hand': ('hand', []), 'discard': ('discard', {}),
                    'empty-id': ('hand', [{'id': '', 'quad': [[20, 20], [80, 20], [80, 100], [20, 100]]}]),
                    'nonfinite': ('hand', [{'quad': [[float('nan'), 1]] * 4}]),
                }[mutation]
                layout[field] = value
                path.write_text(json.dumps(layout))
            with self.subTest(mutation=mutation):
                self.assert_no_complete_manifest(root)

    def test_failed_fixture_reports_unsafe_controls_and_changed_png_hashes_reject(self):
        for mutation in ('card-failure', 'headless', 'false-device-claim', 'missing-mobile-target',
                         'unsafe-target', 'small-target', 'image-hash', 'image-count'):
            root = self.fixture()
            cards_path = root / verifier.CARDS_DIRECTORY / 'cards-safe-area.json'
            mobile_path = root / verifier.MOBILE_DIRECTORY / 'mobile-safe-area.json'
            cards, mobile = json.loads(cards_path.read_text()), json.loads(mobile_path.read_text())
            if mutation == 'card-failure': cards['failures'] = ['declared fixture failure']
            if mutation == 'headless': cards['renderer'] = 'headless'
            if mutation == 'false-device-claim': cards['android_device_measurement'] = True
            if mutation == 'missing-mobile-target': mobile['targets'].pop()
            if mutation == 'unsafe-target': mobile['targets'][0]['fully_inside_true_safe_area'] = False
            if mutation == 'small-target': mobile['targets'][0]['exposed_dp'] = [47, 48]
            if mutation == 'image-hash': mobile['images'][0]['sha256'] = '0' * 64
            if mutation == 'image-count': mobile['images'].append(mobile['images'][0])
            cards_path.write_text(json.dumps(cards))
            mobile_path.write_text(json.dumps(mobile))
            with self.subTest(mutation=mutation):
                self.assert_no_complete_manifest(root)


if __name__ == '__main__':
    unittest.main()
