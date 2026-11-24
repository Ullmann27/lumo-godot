"""Run existing repository regressions on normally imported production assets."""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
GODOT = '/tmp/lumo-2078/runtime/Godot_v4.6.3-stable_linux.x86_64'
TESTS = ['lumo_rival_rig_contract_regression', 'lumo_kart_production_driver_regression',
         'cards_character_roster_regression']
environment = os.environ.copy()
environment['XDG_DATA_HOME'] = str(ROOT / 'user-data')
requested = sys.argv[1:] or TESTS
assert all(name in TESTS for name in requested), requested
results = []
if (ROOT / 'regression_runs.json').is_file():
    results = [row for row in json.loads((ROOT / 'regression_runs.json').read_text())['tests']
               if row['name'] not in requested]
for name in requested:
    command = [GODOT, '--headless', '--path', str(ROOT), '--script', f'res://scripts/tests/{name}.gd']
    if name == 'lumo_kart_production_driver_regression':
        command += ['--', str(ROOT / 'production-runtime-report.json')]
    started = time.monotonic()
    with (ROOT / 'logs' / f'{name}.log').open('w') as output:
        try:
            run = subprocess.run(command, env=environment, stdout=output, stderr=subprocess.STDOUT,
                                 timeout=60)
            exit_code = run.returncode
        except subprocess.TimeoutExpired:
            exit_code = 124
    row = {'name': name, 'command': command, 'exit_code': exit_code,
           'elapsed_seconds': round(time.monotonic() - started, 3)}
    results.append(row)
    print(json.dumps(row), flush=True)
report = {'engine': subprocess.check_output([GODOT, '--version'], text=True).strip(),
          'source_inventory': 'staged_sources.json',
          'tests': sorted(results, key=lambda row: TESTS.index(row['name'])),
          'method': 'Normal Godot editor imports; exact production GLBs and actual runtime sources.',
          'physical_android': False, 'rendered_visual_review': False}
(ROOT / 'regression_runs.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if all(row['exit_code'] == 0 for row in results) else 1)
