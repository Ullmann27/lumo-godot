"""Test the actual acceptance shell's fail-closed evidence collection."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tools/validate_nextgen.sh'


class NextgenRunnerTests(unittest.TestCase):
    def run_fixture(self, *, failing='', missing=''):
        """The fake engine tests orchestration, never claims rendered/gameplay proof."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            root.joinpath('tools').mkdir()
            root.joinpath('scripts/tests').mkdir(parents=True)
            root.joinpath('bin').mkdir()
            shutil.copyfile(RUNNER, root / 'tools/validate_nextgen.sh')
            shutil.copyfile(ROOT / 'tools/run_godot_probe.py', root / 'tools/run_godot_probe.py')
            cases = re.findall(r"^check_probe (\S+) '([^']+)' (\S+)", RUNNER.read_text(), re.M)
            markers = {name: marker for name, marker, _ in cases}
            for name in markers:
                if name != missing:
                    root.joinpath('scripts/tests', name + '.gd').write_text('# fixture only\n')
            engine = root / 'bin/fixture-godot'
            engine.write_text('#!/usr/bin/env python3\n'
                              'import pathlib, sys\n'
                              'if "--version" in sys.argv: print("fixture-engine"); sys.exit(0)\n'
                              'name=pathlib.Path(sys.argv[sys.argv.index("--script")+1]).stem\n'
                              f'if name == {failing!r}: print("ERROR: requested fixture failure"); sys.exit(1)\n'
                              f'print({markers!r}[name])\n')
            engine.chmod(0o755)
            git = root / 'bin/git'
            git.write_text('#!/bin/sh\nif [ "$1" = rev-parse ]; then echo fixture-source; fi\n')
            git.chmod(0o755)
            env = dict(os.environ, GODOT_BIN=str(engine), DISPLAY=':fixture',
                       LUMO_NEXTGEN_LOG_DIR=str(root / 'logs'),
                       PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
            result = subprocess.run(['bash', 'tools/validate_nextgen.sh'], cwd=root,
                                    env=env, capture_output=True, text=True, timeout=45)
            rows = (root / 'logs/results.tsv').read_text().splitlines()[1:]
            return result, rows, cases

    def test_success_requires_every_logic_and_rendered_probe(self):
        result, rows, cases = self.run_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(rows), len(cases))
        self.assertTrue(all(row.endswith('\tPASS') for row in rows))
        self.assertIn('[LumoNextgen] PASS', result.stdout)

    def test_failure_does_not_suppress_other_module_evidence_or_emit_pass(self):
        result, rows, cases = self.run_fixture(failing='jump_nextgen_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('jump_nextgen_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)
        self.assertIn('[LumoNextgen] FAIL', result.stderr)

    def test_missing_required_source_is_a_failure_and_other_captures_still_run(self):
        result, rows, cases = self.run_fixture(missing='learning_world_regression')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(rows), len(cases))
        self.assertIn('learning_world_regression\theadless\tFAIL', rows)
        self.assertIn('cards_table_capture\trendered\tPASS', rows)
        self.assertNotIn('[LumoNextgen] PASS', result.stdout)


if __name__ == '__main__':
    unittest.main()
