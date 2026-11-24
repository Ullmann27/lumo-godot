#!/usr/bin/env python3
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import time
from run_checks import ROOT, HERE, TESTS, stamp, digest

out = HERE / 'diagnostic-before'
out.mkdir(exist_ok=True)
before = stamp()
(out / 'source-before.json').write_text(json.dumps(before, indent=2) + '\n')
rows = []
for name, marker in TESTS.items():
    case = out / name
    case.mkdir(exist_ok=True)
    env = os.environ.copy()
    for kind in ['DATA', 'CONFIG', 'CACHE']:
        path = case / ('xdg-' + kind.lower())
        path.mkdir(exist_ok=True)
        env['XDG_' + kind + '_HOME'] = str(path)
    env['GODOT_SILENCE_ROOT_WARNING'] = '1'
    command = ['/usr/local/bin/godot', '--headless', '--audio-driver', 'Dummy', '--verbose', '--path', str(ROOT), '--script', 'scripts/tests/' + name + '.gd']
    if name != 'kart_ai_behavior_regression':
        command.extend(['--fixed-fps', '60'])
    if name == 'kart_full_field_regression':
        command.extend(['--', '--level=pro', '--clear-player'])
    print('START diagnostic ' + name, flush=True)
    start = time.monotonic()
    utc = datetime.now(timezone.utc).isoformat()
    with (case / 'engine.log').open('wb') as log:
        process = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    text = (case / 'engine.log').read_text()
    row = {
        'test': name, 'command': command, 'started_utc': utc,
        'elapsed_seconds': round(time.monotonic() - start, 3),
        'engine_exit': process.returncode, 'mode': 'diagnostic only; complete teardown output, not an acceptance run',
        'marker_present': marker in text,
        'errors_and_objects': [line for line in text.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|Leaked instance:|Resource still in use:', line)],
        'log_sha256': digest(case / 'engine.log'),
    }
    (case / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    rows.append(row)
    print(json.dumps(row), flush=True)
after = stamp()
(out / 'source-after.json').write_text(json.dumps(after, indent=2) + '\n')
changes = [p for p in set(before['files']) | set(after['files']) if before['files'].get(p) != after['files'].get(p)]
(out / 'results.json').write_text(json.dumps({'results': rows, 'source_files_unchanged': not changes, 'changed_files': changes}, indent=2) + '\n')
print('SOURCES_UNCHANGED ' + str(not changes), flush=True)
