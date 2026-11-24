"""Capture the exact staged LUMO renderer under an authenticated Xvfb display."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time

HERE = Path(__file__).resolve().parent
GODOT = Path('/tmp/lumo-2078/runtime/Godot_v4.6.3-stable_linux.x86_64')
XVFB = Path('/workspace/scratch/2c007901863c/runtime/renderer/usr/bin/Xvfb')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--display', type=int, default=109)
    parser.add_argument('--name', required=True)
    parser.add_argument('--script', default='res://kart_driver_fit_runtime_capture.gd')
    parser.add_argument('--steer', default='0')
    options = parser.parse_args()
    assert GODOT.is_file() and XVFB.is_file(), 'Verified renderer binaries are unavailable'
    output = HERE / 'visual' / options.name
    output.mkdir(parents=True, exist_ok=False)
    auth = output / 'xauth'
    auth.touch(mode=0o600)
    display = f'localhost:{options.display}'
    subprocess.run(['xauth', '-f', str(auth), 'add', display, 'MIT-MAGIC-COOKIE-1',
                    secrets.token_hex(16)], check=True, capture_output=True)
    environment = os.environ.copy()
    environment.update({'DISPLAY': display, 'XAUTHORITY': str(auth),
                        'LIBGL_ALWAYS_SOFTWARE': '1', 'XDG_DATA_HOME': str(output / 'data'),
                        'XDG_CONFIG_HOME': str(output / 'config'), 'XDG_CACHE_HOME': str(output / 'cache')})
    server = None
    started = time.monotonic()
    source_inventory = HERE / 'staged_sources.json'
    try:
        with (output / 'xvfb.log').open('w') as server_log:
            server = subprocess.Popen([str(XVFB), f':{options.display}', '-screen', '0', '1600x1600x24',
                                       '+extension', 'GLX', '+render', '-noreset', '-auth', str(auth),
                                       '-nolisten', 'unix', '-nolisten', 'local', '-listen', 'tcp'],
                                      stdout=server_log, stderr=subprocess.STDOUT)
            time.sleep(1)
            if server.poll() is not None:
                raise RuntimeError('Xvfb failed; see xvfb.log')
            command = [str(GODOT), '--path', str(HERE), '--display-driver', 'x11',
                       '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
                       '--script', options.script, '--', str(output / 'kart-driver-fit.png'), options.steer]
            stopped_for = ''
            with (output / 'godot.log').open('w') as game_log:
                run = subprocess.Popen(command, env=environment, stdout=game_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 600
                while run.poll() is None:
                    time.sleep(0.5)
                    log = (output / 'godot.log').read_text(errors='replace')
                    if 'SCRIPT ERROR:' in log or time.monotonic() >= deadline:
                        stopped_for = 'script_error' if 'SCRIPT ERROR:' in log else 'timeout'
                        run.terminate()
                        break
                run.wait(timeout=5)
            exit_code = run.returncode
            if not (output / 'kart-driver-fit.png').is_file() and exit_code == 0:
                stopped_for = 'missing_capture'
                exit_code = 1
            report = {'exit_code': exit_code, 'stopped_for': stopped_for, 'elapsed_seconds': time.monotonic() - started,
                      'command': command, 'source_inventory_sha256': hashlib.sha256(source_inventory.read_bytes()).hexdigest(),
                      'capture_script_sha256': hashlib.sha256((HERE / options.script.removeprefix('res://')).read_bytes()).hexdigest(),
                      'scope': 'Godot 4.6.3 Compatibility desktop software renderer; actual production kart and drivers; no physical Android result'}
            (output / 'run.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report), flush=True)
            return exit_code
    finally:
        if server is not None and server.poll() is None:
            server.terminate()
            server.wait(timeout=5)
        auth.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
