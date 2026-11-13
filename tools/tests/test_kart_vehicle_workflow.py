"""Exercise the real geometry workflow block; synthetic engines are gate tests."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/kart-vehicle-regression.yml'
PROBE = 'scripts/tests/kart_vehicle_regression.gd'
MARKER = '[KartVehicle] Geometry/colours, shadows, animations, effects, LOD and hysteresis passed'


def workflow_fixture_step():
    lines = WORKFLOW.read_text().splitlines()
    step = lines.index('      - name: Run committed source in isolated regression fixture')
    start = next(index for index in range(step + 1, len(lines))
                 if lines[index] == '        run: |')
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('          '):
            break
        body.append(line[10:] if line else '')
    return '\n'.join(body) + '\n'


def mandatory_sources():
    """Resolve actual literal preloads, independently of the workflow copy list."""
    pending, sources = [PROBE], {}
    while pending:
        relative = pending.pop()
        if relative in sources:
            continue
        path = ROOT / relative
        sources[relative] = path.read_bytes()
        if path.suffix == '.gd':
            pending.extend(re.findall(r'''preload\s*\(\s*["']res://([^"']+)["']\s*\)''',
                                      path.read_text()))
    return sources


class KartVehicleWorkflowTests(unittest.TestCase):
    def run_fixture(self, scenario='clean'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative, data in mandatory_sources().items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            (root / 'tools').mkdir()
            shutil.copyfile(ROOT / 'tools/run_godot_probe.py', root / 'tools/run_godot_probe.py')
            (root / 'bin').mkdir()
            engine = root / 'bin/Godot_v4.6.3-stable_linux.x86_64'
            engine.write_text(
                f'#!{sys.executable}\n'
                'import json, os, pathlib, sys\n'
                'phase = "probe" if "--script" in sys.argv else "import"\n'
                'with open(os.environ["FIXTURE_INVOCATIONS"], "a") as log:\n'
                '    log.write(json.dumps({"phase": phase, "args": sys.argv[1:]}) + "\\n")\n'
                'lines = ["Godot Engine v4.6.3.stable.official.7d41c59c4"]\n'
                'scenario = os.environ["FIXTURE_SCENARIO"]\n'
                f'if phase == "probe" and scenario != "missing-marker": lines.append({MARKER!r})\n'
                'if phase == "import" and scenario == "import-error":\n'
                '    lines.append("SCRIPT ERROR: Parse Error: synthetic import failure with exit zero")\n'
                'if phase == "probe" and scenario == "probe-error":\n'
                '    lines.append("ERROR: synthetic runtime failure after success marker with exit zero")\n'
                'sys.stdout.write("\\n".join(lines) + "\\n")\n'
                'sys.stdout.flush()\n'
                'sys.exit(0)\n')
            engine.chmod(0o755)
            temporary = root / 'runner temp'
            temporary.mkdir()
            result = subprocess.run(
                ['bash', '-c', workflow_fixture_step()], cwd=root,
                env=dict(os.environ, RUNNER_TEMP=str(temporary),
                         PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'],
                         FIXTURE_SCENARIO=scenario,
                         FIXTURE_INVOCATIONS=str(root / 'invocations.jsonl')),
                text=True, capture_output=True, timeout=20)
            result.invocations = [json.loads(line) for line in
                                  (root / 'invocations.jsonl').read_text().splitlines()]
            fixture = temporary / 'kart-check'
            result.copied_sources = {
                path.relative_to(fixture).as_posix(): path.read_bytes()
                for path in fixture.rglob('*') if path.is_file() and path.suffix in ('.gd', '.gdshader')}
            result.logs = {name: (temporary / name).read_text() for name in ('import.log', 'vehicle.log')
                           if (temporary / name).is_file()}
            return result

    def test_clean_fixture_contains_every_actual_preload_and_keeps_original_source_bytes(self):
        result = self.run_fixture()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.copied_sources, mandatory_sources())
        self.assertEqual([call['phase'] for call in result.invocations], ['import', 'probe'])
        self.assertIn(MARKER, result.logs['vehicle.log'])

    def test_import_error_with_zero_exit_stops_before_a_later_probe_can_print_success(self):
        result = self.run_fixture('import-error')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([call['phase'] for call in result.invocations], ['import'])
        self.assertIn('SCRIPT ERROR: Parse Error:', result.logs['import.log'])
        self.assertNotIn('vehicle.log', result.logs)

    def test_runtime_error_with_zero_exit_cannot_be_hidden_by_the_success_marker(self):
        result = self.run_fixture('probe-error')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(MARKER, result.logs['vehicle.log'])
        self.assertIn('ERROR: synthetic runtime failure', result.logs['vehicle.log'])

    def test_zero_exit_without_required_geometry_marker_still_fails(self):
        result = self.run_fixture('missing-marker')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn(MARKER, result.logs['vehicle.log'])

    def test_original_import_and_probe_logs_are_archived_even_after_failure(self):
        source = WORKFLOW.read_text()
        archive = source.split('      - name: Preserve actual import and geometry logs\n', 1)[1]
        self.assertIn('if: always()', archive)
        self.assertIn('uses: actions/upload-artifact@v4', archive)
        self.assertIn('${{ runner.temp }}/import.log', archive)
        self.assertIn('${{ runner.temp }}/vehicle.log', archive)
        self.assertIn("-p 'test_kart_vehicle_workflow.py' -v", source)


if __name__ == '__main__':
    unittest.main()
