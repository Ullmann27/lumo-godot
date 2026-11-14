"""Exercise the real legacy shell gates against post-PASS engine errors.

The fixture executable only replays a log and exits zero. These are shell
acceptance-policy tests, not engine, renderer or gameplay evidence.
"""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
GATES = {
    "validate_project.sh": "godot_log_ok",
    "validate_2014.sh": "run_probe",
    "validate_technical_art.sh": "run_probe",
}
PASS = "[KartAI] PASS: completed gameplay assertions\n"
RESOURCE_ERROR = (
    "WARNING: ObjectDB instances leaked at exit (run with --verbose for details).\n"
    "ERROR: 4 resources still in use at exit (run with --verbose for details).\n"
)


class LegacyLogPolicyTests(unittest.TestCase):
    def run_gate(self, script_name, log):
        source = (ROOT / "tools" / script_name).read_text(encoding="utf-8")
        function_name = GATES[script_name]
        definition = re.search(
            rf"^{re.escape(function_name)}\(\) \{{\n.*?^\}}$",
            source,
            re.MULTILINE | re.DOTALL,
        )
        self.assertIsNotNone(definition, f"Missing actual gate in {script_name}")
        with tempfile.TemporaryDirectory(prefix="lumo-legacy-log-policy-") as tmp:
            folder = Path(tmp)
            original_log = folder / "original-engine.log"
            original_log.write_text(log, encoding="utf-8")
            engine = folder / "replay-engine"
            engine.write_text(
                "#!/usr/bin/env python3\n"
                "import os, pathlib, sys\n"
                "sys.stdout.write(pathlib.Path(os.environ['LUMO_TEST_LOG']).read_text())\n",
                encoding="utf-8",
            )
            engine.chmod(0o755)
            if function_name == "godot_log_ok":
                program = (
                    "set -euo pipefail\n"
                    + definition.group(0)
                    + '\ngodot_log_ok "$1" \'\\[KartAI\\] PASS\'\n'
                )
                arguments = [str(original_log)]
            else:
                program = (
                    "set -euo pipefail\n"
                    'GODOT="$1"\nLOG_DIR="$2"\nexport LUMO_TEST_LOG="$3"\n'
                    + definition.group(0)
                    + "\nrun_probe fixture '[KartAI] PASS' headless\n"
                )
                arguments = [str(engine), str(folder), str(original_log)]
            return subprocess.run(
                ["bash", "-c", program, "legacy-log-policy", *arguments],
                cwd=ROOT,
                env=os.environ.copy(),
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=10,
                check=False,
            )

    def test_clean_pass_is_accepted(self):
        for script_name in GATES:
            with self.subTest(script=script_name):
                result = self.run_gate(script_name, PASS)
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_exit_zero_with_post_pass_resource_error_is_rejected(self):
        for script_name in GATES:
            with self.subTest(script=script_name):
                result = self.run_gate(script_name, PASS + RESOURCE_ERROR)
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_missing_pass_is_rejected(self):
        for script_name in GATES:
            with self.subTest(script=script_name):
                result = self.run_gate(script_name, "Completed without success marker.\n")
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_post_pass_script_error_is_rejected(self):
        for script_name in GATES:
            with self.subTest(script=script_name):
                result = self.run_gate(script_name, PASS + "SCRIPT ERROR: Invalid call.\n")
                self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
