#!/usr/bin/env python3
"""Record bounded real-engine teardown checks; never writes project sources."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path('/workspace/scratch/b3485b7bb989/lumo-native-followups')
HERE = Path(__file__).resolve().parent
TESTS = {
    'kart_ai_behavior_regression': '[KartAI] PASS',
    'kart_garage_touch_targets_regression': '[GarageTargets] PASS',
    'kart_full_field_regression': '[KartFullField] PASS',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True).strip()


def stamp():
    tracked = git('ls-files', 'project.godot', 'scripts', 'scenes', 'shaders', 'assets/audio', 'tools/run_godot_probe.py').splitlines()
    files = {}
    for rel in tracked:
        if rel.startswith('scripts/tests/') and Path(rel).stem not in TESTS:
            continue
        if rel == 'scripts/creative/build_world.gd':
            continue
        if Path(rel).suffix == '.uid':
            continue
        p = ROOT / rel
        if p.is_file():
            files[rel] = {'sha256': digest(p), 'bytes': p.stat().st_size}
    return {
        'utc': datetime.now(timezone.utc).isoformat(),
        'head': git('rev-parse', 'HEAD'),
        'tree': git('rev-parse', 'HEAD^{tree}'),
        'scope': 'tracked product scripts/scenes/shaders, project.godot, audio assets, the three assigned tests and strict Python runner; excludes unrelated tests, docs, shell gates, generated caches and concurrently repaired scripts/creative/build_world.gd (not part of these Kart scenes)',
        'files': files,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase')
    parser.add_argument('--only', choices=list(TESTS))
    parser.add_argument('--script-dir', type=Path)
    parser.add_argument('--fixed-fps', type=int)
    args = parser.parse_args()
    output = HERE / args.phase
    output.mkdir(parents=True, exist_ok=True)
    before = stamp()
    (output / 'source-before.json').write_text(json.dumps(before, indent=2) + '\n')
    results = []
    for name, marker in TESTS.items():
        if args.only and args.only != name:
            continue
        case = output / name
        case.mkdir(exist_ok=True)
        environment = os.environ.copy()
        for kind in ['DATA', 'CONFIG', 'CACHE']:
            directory = case / ('xdg-' + kind.lower())
            directory.mkdir(exist_ok=True)
            environment['XDG_' + kind + '_HOME'] = str(directory)
        environment['GODOT_SILENCE_ROOT_WARNING'] = '1'
        script = (args.script_dir / (name + '.gd')) if args.script_dir else ROOT / 'scripts/tests' / (name + '.gd')
        command = [
            'python3', str(ROOT / 'tools/run_godot_probe.py'),
            '--log', str(case / 'engine.log'), '--timeout', '240', '--required', marker,
            '--', '/usr/local/bin/godot', '--headless', '--audio-driver', 'Dummy', '--verbose',
            '--path', str(ROOT), '--script', str(script),
        ]
        if args.fixed_fps:
            command.extend(['--fixed-fps', str(args.fixed_fps)])
        started = time.monotonic()
        started_utc = datetime.now(timezone.utc).isoformat()
        print('START ' + args.phase + ' ' + name, flush=True)
        with (case / 'runner.log').open('wb') as log:
            process = subprocess.run(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=260)
        engine = (case / 'engine.log').read_text()
        errors = [line for line in engine.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|Leaked instance:|Resource still in use:', line)]
        result = {
            'phase': args.phase, 'test': name, 'started_utc': started_utc,
            'finished_utc': datetime.now(timezone.utc).isoformat(),
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'command': command, 'cwd': str(ROOT),
            'xdg': {k:v for k,v in environment.items() if k.startswith('XDG_')},
            'script_sha256': digest(script), 'strict_runner_exit': process.returncode,
            'required_marker': marker, 'marker_present': marker in engine,
            'errors': errors,
            'cleanup_lines': [line for line in engine.splitlines() if 'audio_release' in line or 'retained_audio_playbacks' in line],
            'engine_log_sha256': digest(case / 'engine.log'),
            'runner_log_sha256': digest(case / 'runner.log'),
        }
        (case / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        results.append(result)
        print(json.dumps({k: result[k] for k in ['test','strict_runner_exit','elapsed_seconds','marker_present','errors','cleanup_lines']}), flush=True)
    after = stamp()
    (output / 'source-after.json').write_text(json.dumps(after, indent=2) + '\n')
    changes = [rel for rel in set(before['files']) | set(after['files']) if before['files'].get(rel) != after['files'].get(rel)]
    summary = {'phase': args.phase, 'source_files_unchanged': not changes, 'changed_files': changes, 'head_before': before['head'], 'head_after': after['head'], 'results': results}
    (output / 'results.json').write_text(json.dumps(summary, indent=2) + '\n')
    print('SOURCES_UNCHANGED ' + str(not changes), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
