"""Small negative controls for the one-off media importer; no network required."""
import copy
import importlib.util
import io
import json
import unittest
import zipfile
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('importer', Path(__file__).with_name('import_track_reference_packs.py'))
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)

class ImportSafetyTests(unittest.TestCase):
    def setUp(self):
        self.row = {'name': 'Track_01_skyline_sprint_clouds.zip', 'bytes': 100,
                    'sha256': 'a' * 64, 'files': 1,
                    'url': MOD.PREFIX + '73c37875-1413-4b94-a5d4-183e2ae51ef3.zip'}

    def test_valid_metadata(self):
        MOD.validate_row(self.row)

    def test_reject_unapproved_source(self):
        self.row['url'] = 'https://example.com/model.zip'
        with self.assertRaises(ValueError): MOD.validate_row(self.row)

    def test_reject_bad_name(self):
        self.row['name'] = '../escape.zip'
        with self.assertRaises(ValueError): MOD.validate_row(self.row)

    def test_reject_bad_checksum(self):
        self.row['sha256'] = 'not-a-checksum'
        with self.assertRaises(ValueError): MOD.validate_row(self.row)

    def test_reject_oversized_metadata(self):
        self.row['bytes'] = 100_000_000
        with self.assertRaises(ValueError): MOD.validate_row(self.row)

    def test_known_hero(self):
        target, kind = MOD.destination('Track_01_skyline_sprint_clouds/reference_images/track_01_hero_original.png')
        self.assertEqual(kind, 'hero_reference')
        self.assertTrue(target.as_posix().startswith(MOD.REFS.as_posix()))

    def test_shared_icon_deduplication(self):
        self.assertEqual(MOD.destination('Shared_Core_Assets/boost_pad_1536.png'),
                         MOD.destination('Track_02_crystal_canyon_dash/shared_core_assets/boost_pad_1536.png'))

    def test_unknown_file_not_executed(self):
        with self.assertRaises(ValueError):
            MOD.destination('Track_01_skyline_sprint_clouds/docs/run_me.py')

    def test_archive_traversal(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr('Track_01_skyline_sprint_clouds/../../escape.txt', 'bad')
        buffer.seek(0)
        with zipfile.ZipFile(buffer) as archive:
            with self.assertRaises(ValueError): MOD.members(archive, self.row)

    def test_archive_duplicate(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr('Track_01_skyline_sprint_clouds/manifest.json', '{}')
            archive.writestr('Track_01_skyline_sprint_clouds/manifest.json', '{}')
        self.row['files'] = 2
        buffer.seek(0)
        with zipfile.ZipFile(buffer) as archive:
            with self.assertRaises(ValueError): MOD.members(archive, self.row)

if __name__ == '__main__': unittest.main()
