"""The tunnel kit must not embed textures in its modules again.

Embedded copies made the Android game pack 150 MB larger (the same four maps
in up to fourteen modules per course, imported uncompressed).
"""
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class TrackTexturesExternal(unittest.TestCase):
    def test_no_module_embeds_images_and_every_reference_exists(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / 'tools/lumo_kart_art/tracks/externalize_textures.py'), '--check'],
            capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads(result.stdout)
        self.assertGreater(report['glb_files'], 300)
        self.assertEqual(report['embedded_images_found'], 0)
        sys.path.insert(0, str(ROOT / 'tools/lumo_kart_art/tracks'))
        from externalize_textures import TRACKS, read_glb
        references = 0
        for path in sorted(TRACKS.glob('*/*.glb')):
            document, _ = read_glb(path)
            for image in document.get('images', []):
                self.assertIn('uri', image, path)
                target = path.parent / image['uri']
                self.assertTrue(target.is_file(), f'{path}: missing {image["uri"]}')
                self.assertEqual(target.parent.name, 'textures')
                references += 1
        self.assertGreater(references, 500)


if __name__ == '__main__':
    unittest.main()
