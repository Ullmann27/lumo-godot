"""Klangwelt: Manifest, Größenbudget und Messwerte der selbst erzeugten Klänge."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/audio/klangwelt'


class KlangweltAudioTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))

    def test_every_file_exists_and_budget_holds(self):
        total = 0
        for group in ('music', 'ambience'):
            for name in self.manifest[group]:
                path = BASE / group / f'{name}.ogg'
                self.assertTrue(path.is_file(), path)
                size = path.stat().st_size
                self.assertLessEqual(size, 1_200_000, path)
                total += size
        for name, entry in self.manifest['sfx'].items():
            for variant in range(entry['variants']):
                path = BASE / 'sfx' / f'{name}_{variant}.ogg'
                self.assertTrue(path.is_file(), path)
                total += path.stat().st_size
        self.assertLessEqual(total, 18_000_000)

    def test_loops_are_long_and_seamless(self):
        for group in ('music', 'ambience'):
            for name, entry in self.manifest[group].items():
                m = entry['measure']
                if group == 'music':
                    self.assertGreaterEqual(m['seconds'], 39.9, name)
                    self.assertLessEqual(m['seconds'], 90.0, name)
                self.assertLess(m['seam_ratio'], 1.0, name)
                self.assertLess(m['dc'], 1e-3, name)
                self.assertLess(m['energy_above_15k'], 1e-4, name)
                self.assertLessEqual(m['true_peak_dbfs'], -0.5, name)

    def test_music_loudness_is_consistent(self):
        levels = [e['measure']['lufs'] for n, e in self.manifest['music'].items() if not e.get('layer_of')]
        self.assertLess(max(levels) - min(levels), 1.5)
        for entry in self.manifest['ambience'].values():
            self.assertLess(entry['measure']['lufs'], -20.0)

    def test_layers_match_their_base(self):
        music = self.manifest['music']
        for name, entry in music.items():
            base = entry.get('layer_of')
            if base:
                self.assertEqual(entry['samples'], music[base]['samples'], name)
                self.assertEqual(entry['bpm'], music[base]['bpm'], name)

    def test_audio_manager_lists_every_generated_sfx(self):
        text = (ROOT / 'scripts/systems/audio_manager.gd').read_text(encoding='utf-8')
        for name, entry in self.manifest['sfx'].items():
            self.assertIn(f'"{name}": {entry["variants"]}', text, name)


if __name__ == '__main__':
    unittest.main()
