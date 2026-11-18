"""The Blender-built jungle of Lumo Lauf stays light enough for phones.

Checks the generated GLBs and textures (tools/lumo_run_art/verify_jungle_art.py)
and that the Android export takes the art folder along.
"""
import configparser
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/lumo_run_art'))

import verify_jungle_art  # noqa: E402


class RunJungleArt(unittest.TestCase):
    def test_models_and_textures_are_valid_and_small(self):
        problems, summary = verify_jungle_art.verify()
        self.assertEqual(problems, [])
        self.assertGreaterEqual(summary['models'], 40)
        self.assertLess(summary['bytes'], 20 * 1024 * 1024)

    def test_trees_have_a_light_far_version(self):
        _, summary = verify_jungle_art.verify()
        counts = summary['triangles']
        for tree in ('tree_broad', 'tree_slender', 'tree_fig', 'tree_kapok', 'palm_a', 'palm_b'):
            self.assertIn(tree + '_lod', counts)
            self.assertLess(counts[tree + '_lod'] * 4, counts[tree], tree)

    def test_android_export_includes_the_art(self):
        presets = configparser.ConfigParser(strict=False, interpolation=None)
        presets.read(ROOT / 'export_presets.cfg')
        android = next(s for s in presets.sections() if presets.get(s, 'platform', fallback='').strip('"') == 'Android')
        self.assertEqual(presets.get(android, 'export_filter').strip('"'), 'all_resources')
        excluded = presets.get(android, 'exclude_filter', fallback='').strip('"').split(',')
        for pattern in excluded:
            self.assertFalse(pattern.startswith('assets/games'), pattern)
            self.assertNotIn(pattern, ('assets/*', 'assets/games/*'))


if __name__ == '__main__':
    unittest.main()
