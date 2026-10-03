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
            manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application>
                <activity android:name="com.godot.game.GodotApp" android:exported="false">
                    <intent-filter><data android:scheme="lumo3d" /></intent-filter>
                </activity>
                <activity-alias android:name="com.godot.game.GodotAppLauncher"
                    android:targetActivity="com.godot.game.GodotApp" android:exported="true">
                    <intent-filter><action android:name="android.intent.action.MAIN" />
                    <category android:name="android.intent.category.LAUNCHER" /></intent-filter>
                </activity-alias>
                </application></manifest>''')
            for _ in range(2):
                subprocess.run([sys.executable, str(script)], check=True, capture_output=True)
            text = java.read_text()
            self.assertEqual(text.count('// LUMO_ALLOWLISTED_BRIDGE:'), 1)
            self.assertIn('Math.max(1, Math.min(4, grade))', text)
            self.assertIn('new_launch_requested', text)
            document = ET.parse(manifest)
            data = document.findall('application/activity-alias/intent-filter/data')
            ns = '{http://schemas.android.com/apk/res/android}'
            self.assertEqual(len(data), 3)
            self.assertTrue(all(e.get(ns + 'scheme') == 'lumo3d' for e in data))
            self.assertEqual({e.get(ns + 'host') for e in data}, {'kart', 'jump', 'home'})
            self.assertFalse(document.findall('application/activity/intent-filter/data'))
            activity = document.find('application/activity')
            self.assertEqual(activity.get(ns + 'exported'), 'false')
            launcher = document.find('application/activity-alias')
            self.assertEqual(launcher.get(ns + 'exported'), 'true')
            self.assertTrue(any(e.get(ns + 'name') == 'android.intent.action.MAIN'
                                for e in launcher.findall('intent-filter/action')))
            self.assertEqual(activity.get(ns + 'screenOrientation'), 'portrait')
            self.assertEqual(activity.get(ns + 'resizeableActivity'), 'true')
            changes = set(activity.get(ns + 'configChanges').split('|'))
            self.assertTrue({'orientation', 'screenSize', 'colorMode', 'uiMode', 'assetsPaths'} <= changes)
