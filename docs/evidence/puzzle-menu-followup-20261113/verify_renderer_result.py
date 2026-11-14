#!/usr/bin/env python3
"""Reject functional failures, native Godot errors, or missing real captures."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    directory = args.evidence.resolve()
    report_file = directory / 'puzzle-menu-lifecycle.json'
    log_file = directory / 'renderer/godot.log'
    run_file = directory / 'renderer/run.json'
    report = json.loads(report_file.read_text())
    run = json.loads(run_file.read_text())
    log = log_file.read_text()
    errors = [line for line in log.splitlines()
              if re.match(r'^\s*(?:SCRIPT )?ERROR:', line)]
    captures = report.get('captures', [])
    valid = (run.get('exit_code') == 0 and run.get('timed_out') is False
             and report.get('failures') == [] and report.get('display') == 'X11'
             and '[PuzzleMenuLifecycle] PASS ' in log and not errors
             and len(captures) == 6 and len(set(captures)) == 6
             and all((directory / name).is_file() for name in captures))
    result = {
        'status': 'PASS' if valid else 'FAIL',
        'native_process_exit_code': run.get('exit_code'),
        'timed_out': run.get('timed_out'),
        'behavioral_checks': report.get('checks'),
        'behavioral_failures': report.get('failures'),
        'native_error_count': len(errors),
        'native_error_lines': errors,
        'can_process_error_count': len(re.findall(r'at: can_process\b', log)),
        'actual_capture_count': len(captures),
        'file_sha256': {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in (report_file, log_file, run_file)},
        'scope': 'Local Godot/X11 input and native-error gate; not Android performance',
    }
    (directory / 'strict-result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    return 0 if valid else 1


if __name__ == '__main__':
    raise SystemExit(main())
