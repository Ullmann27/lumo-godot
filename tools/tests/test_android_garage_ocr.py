"""Garage footer OCR against a real Android API 35 emulator capture.

The fixture is kart-garage-step-1.png from lumo-godot run 38803602256
(320x640 mdpi emulator, landscape). That run failed with "Visible footer
control missing at step 1: Weiter" although the gold "Weiter" button is
plainly visible in the capture.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

try:
    from PIL import Image
except ImportError:  # Pillow arrives with the Android OCR apt step.
    Image = None

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# CI sets this after installing the OCR tools so the check cannot skip there.
REQUIRED = os.environ.get('LUMO_REQUIRE_ANDROID_OCR') == '1'
FIXTURE = Path(__file__).resolve().parent / 'fixtures' / 'android_api35_kart_garage_step1.png'


@unittest.skipUnless(REQUIRED or (Image and shutil.which('tesseract')),
                     'Pillow and tesseract required')
class AndroidGarageOcrTest(unittest.TestCase):
    def setUp(self):
        from tap_android_garage import footer_targets, tesseract_tsv
        self.footer_targets = footer_targets
        self.work = tempfile.TemporaryDirectory()
        self.read = tesseract_tsv(Path(self.work.name) / 'ocr.png')
        self.image = Image.open(FIXTURE).convert('RGB')

    def tearDown(self):
        self.work.cleanup()

    def test_dark_text_on_gold_footer_button_is_found_inside_the_button(self):
        targets = self.footer_targets(self.image, 'Weiter', self.read)
        self.assertTrue(targets, 'visible gold Weiter button was not read')
        _, text, (x0, y0, x1, y1) = targets[0]
        self.assertEqual(text, 'Weiter')
        centre = ((x0 + x1) / 2, (y0 + y1) / 2)
        # Gold button measured in the capture: x 484..632, y 216..264.
        self.assertTrue(484 <= centre[0] <= 632 and 216 <= centre[1] <= 264, centre)
        r, g, b = self.image.getpixel((round(x0) - 3, round(centre[1])))
        self.assertTrue(r > 200 and g > 170 and b < 120, 'tap target is not on the gold button')

    def test_light_text_reader_still_reads_dark_glass_controls(self):
        targets = self.footer_targets(self.image, 'Spieleauswahl', self.read)
        self.assertTrue(targets)
        _, _, (x0, y0, x1, y1) = targets[0]
        self.assertLess(x1, 160)

    def test_labels_absent_from_the_capture_are_not_invented(self):
        self.assertEqual(self.footer_targets(self.image, 'Rennen starten', self.read), [])

    def test_upper_controls_are_not_taken_as_footer_actions(self):
        # "1 Modus" is a real label but lives in the step tabs at the top.
        self.assertEqual(self.footer_targets(self.image, 'Modus', self.read), [])


if __name__ == '__main__':
    unittest.main()
