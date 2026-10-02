from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

class NativeRouteBridgeTest(unittest.TestCase):
    def test_installs_allowlisted_route_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            tools = root / 'tools'
            tools.mkdir()
            script = tools / 'prepare_android_bridge.py'
            script.write_text((Path(__file__).parents[1] / script.name).read_text())
            app = root / 'android/build/src/main'
            app.mkdir(parents=True)
            java = app / 'GodotApp.java'
            java.write_text('package com.godot.game; public class GodotApp extends GodotActivity {}')
            manifest = app / 'AndroidManifest.xml'
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name="com.godot.game.GodotApp" android:exported="true" /></application></manifest>')
            for _ in range(2):
                subprocess.run([sys.executable, str(script)], check=True, capture_output=True)
            text = java.read_text()
            self.assertEqual(text.count('// LUMO_ALLOWLISTED_BRIDGE:'), 1)
            self.assertIn('Math.max(1, Math.min(4, grade))', text)
            self.assertIn('new_launch_requested', text)
            document = ET.parse(manifest)
            data = document.findall('application/activity/intent-filter/data')
            self.assertEqual(len(data), 1)
            self.assertEqual(data[0].get('{http://schemas.android.com/apk/res/android}scheme'), 'lumo3d')
