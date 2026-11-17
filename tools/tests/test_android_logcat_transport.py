#!/usr/bin/env python3
"""Contract tests for transient ADB logcat retries in the REAL Android startup script.

These tests exercise the production shell function extracted verbatim. They do
not replace the live Android emulator end-to-end test or relax its assertions.
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STARTUP = ROOT / "tools/test_android_startup.sh"
MOCK = r"""#!/usr/bin/env python3
import os
import pathlib
import sys
counter = pathlib.Path(os.environ["MOCK_COUNTER"])
n = int(counter.read_text() if counter.exists() else "0") + 1
counter.write_text(str(n))
assert sys.argv[1:] == ["logcat", "-d", "-v", "threadtime"], sys.argv
mode = os.environ["MOCK_MODE"]
if mode == "offline_once" and n == 1:
    print("adb: device offline", file=sys.stderr)
    sys.exit(1)
if mode == "always_offline":
    print("adb: device offline", file=sys.stderr)
    sys.exit(1)
if mode in ("silent255_once", "silent255_always") and (n == 1 or mode == "silent255_always"):
    sys.exit(255)
if mode == "nontransient":
    print("unsupported logcat argument", file=sys.stderr)
    sys.exit(23)
print("10-16 03:02:00.000 2000 2100 I godot : [EventBus] online - signals registered")
print("10-16 03:02:00.200 2000 2100 I godot : [Router] loaded:kart")
if mode == "crash":
    print("10-16 03:02:00.500 2000 2100 E AndroidRuntime : FATAL EXCEPTION: main")
"""


class AndroidLogcatContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = STARTUP.read_text(encoding="utf-8")
        begin = source.index("capture_logcat() {")
        end = source.index("\n}\n\nlumo_deadline=", begin) + 2
        cls.production_function = source[begin:end]

    def run_scenario(self, mode):
        with tempfile.TemporaryDirectory(prefix="lumo-adb-qa-") as tmp:
            directory = Path(tmp)
            fake_adb = directory / "mock-adb"
            fake_adb.write_text(MOCK, encoding="utf-8")
            fake_adb.chmod(0o755)
            counter = directory / "counter"
            capture = directory / "capture.log"
            audit_log = directory / "startup.log"
            script = (
                "set -Eeuo pipefail\n"
                f'lumo_adb="{fake_adb}"\n'
                "lumo_adb_args=()\n"
                f'lumo_capture="{capture}"\n'
                f'lumo_log="{audit_log}"\n'
                'fail() { printf "[AndroidStartup] FAIL: %s\\n" "$*" >&2; exit 1; }\n'
                "sleep() { :; }\n"
                + self.production_function + "\n"
                "capture_logcat\n"
                'echo "[Contract] passed"\n'
            )
            env = dict(os.environ, MOCK_MODE=mode, MOCK_COUNTER=str(counter))
            process = subprocess.run(
                ["bash", "-c", script],
                env=env, text=True, capture_output=True, timeout=20,
            )
            count = int(counter.read_text()) if counter.exists() else 0
            return process, count, capture.read_text() if capture.exists() else "", \
                audit_log.read_text() if audit_log.exists() else ""

    def test_offline_is_retried_and_complete_raw_log_preserved(self):
        result, count, capture, audit = self.run_scenario("offline_once")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(count, 2)
        self.assertIn("[EventBus] online", capture)
        self.assertIn("[Router] loaded:kart", capture)
        self.assertIn("logcat attempt 1/3 failed", audit)

    def test_silent_exit_255_after_deep_link_is_retried_once(self):
        result, count, capture, audit = self.run_scenario("silent255_once")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(count, 2)
        self.assertIn("[Router] loaded:kart", capture)
        self.assertIn("Empty-stderr adb 255", audit)
        self.assertIn("logcat attempt 1/3 failed (exit 255)", audit)

    def test_silent_exit_255_never_masks_persistent_failure(self):
        result, count, capture, audit = self.run_scenario("silent255_always")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(count, 3)
        self.assertEqual(capture, "")
        self.assertIn("Could not capture logcat after 3 bounded attempts", result.stderr)
        self.assertIn("logcat attempt 3/3 failed (exit 255)", audit)

    def test_real_runtime_crash_still_fails(self):
        result, count, capture, _ = self.run_scenario("crash")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(count, 1)
        self.assertIn("FATAL EXCEPTION", capture)
        self.assertIn("Project loading, script, Java or native crash detected", result.stderr)

    def test_nontransient_adb_failure_does_not_retry(self):
        result, count, capture, _ = self.run_scenario("nontransient")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(count, 1)
        self.assertEqual(capture, "")
        self.assertIn("Non-transient adb logcat failure", result.stderr)

    def test_repeated_offline_fails_closed_after_three_attempts(self):
        result, count, capture, audit = self.run_scenario("always_offline")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(count, 3)
        self.assertEqual(capture, "")
        self.assertIn("Could not capture logcat after 3 bounded attempts", result.stderr)
        self.assertIn("logcat attempt 3/3", audit)


if __name__ == "__main__":
    unittest.main(verbosity=2)
