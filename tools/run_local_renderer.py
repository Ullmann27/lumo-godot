#!/usr/bin/env python3
"""Run Godot Compatibility in an isolated, authenticated Xorg dummy display.

This local QA fallback does not use a shared desktop or alter global Xorg
configuration. It needs Xorg, the dummy video driver, xauth and Godot on PATH.
The renderer is software Mesa; its timing is not an Android performance result.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time


CONFIG = '''Section "ServerFlags"
 Option "AutoAddDevices" "false"
 Option "AutoEnableDevices" "false"
 Option "AllowMouseOpenFail" "true"
 Option "DontVTSwitch" "true"
EndSection
Section "Device"
 Identifier "LumoQADummy"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "LumoQAMonitor"
 HorizSync 5.0-1000.0
 VertRefresh 5.0-200.0
 Modeline "2560x2560" 269.58 2560 2632 2904 3248 2560 2563 2568 2767 -HSync +VSync
EndSection
Section "Screen"
 Identifier "LumoQAScreen"
 Device "LumoQADummy"
 Monitor "LumoQAMonitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "2560x2560"
  Virtual 2560 2560
 EndSubSection
EndSection
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--display', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--timeout', type=int, default=1200)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('godot_args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not 90 <= args.display <= 199 or args.timeout <= 0:
        parser.error('Use an exclusive test display from 90 to 199 and a positive timeout')
    if not (args.project / 'project.godot').is_file():
        parser.error('The project directory must contain project.godot')
    executables = {name: shutil.which(name) for name in ('Xorg', 'xauth', 'godot')}
    missing = [name for name, path in executables.items() if not path]
    if missing:
        parser.error('Missing local renderer dependencies: ' + ', '.join(missing))
    extra = args.godot_args[1:] if args.godot_args[:1] == ['--'] else args.godot_args
    if '--headless' in extra:
        parser.error('This runner requires an actual renderer; omit --headless')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    config, auth = output / 'xorg.conf', output / 'auth'
    config.write_text(CONFIG)
    auth.touch(mode=0o600)
    server = None
    started = time.monotonic()
    try:
        subprocess.run([executables['xauth'], '-f', str(auth), 'add',
                        f'localhost:{args.display}', 'MIT-MAGIC-COOKIE-1',
                        secrets.token_hex(16)], check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)
        with (output / 'server-stdout.log').open('w') as server_log:
            server = subprocess.Popen([
                executables['Xorg'], f':{args.display}', '-config', str(config),
                '-logfile', str(output / 'Xorg.log'), '-nolisten', 'unix',
                '-nolisten', 'local', '-listen', 'tcp', '-noreset', '-auth', str(auth),
            ], stdout=server_log, stderr=subprocess.STDOUT)
            time.sleep(1.5)
            if server.poll() is not None:
                raise RuntimeError('Isolated Xorg did not start; inspect Xorg.log')
            environment = os.environ.copy()
            environment.update({
                'DISPLAY': f'localhost:{args.display}', 'XAUTHORITY': str(auth),
                'LIBGL_ALWAYS_SOFTWARE': '1',
                'XDG_DATA_HOME': str(output / 'data'),
                'XDG_CONFIG_HOME': str(output / 'config'),
                'XDG_CACHE_HOME': str(output / 'cache'),
            })
            command = [executables['godot'], '--path', str(args.project.resolve()),
                       '--display-driver', 'x11', '--audio-driver', 'Dummy',
                       '--rendering-method', 'gl_compatibility', *extra]
            with (output / 'godot.log').open('w') as game_log:
                try:
                    completed = subprocess.run(command, env=environment, stdout=game_log,
                                               stderr=subprocess.STDOUT, timeout=args.timeout)
                    code = completed.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            report = {'exit_code': code, 'elapsed_seconds': time.monotonic() - started,
                      'display': args.display, 'project': str(args.project.resolve()),
                      'godot_arguments': extra, 'timed_out': code == 124,
                      'scope': 'Local software renderer; not physical Android performance'}
            (output / 'run.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report))
            return code
    finally:
        if server is not None and server.poll() is None:
            server.terminate()
            try:
                server.wait(timeout=3)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
        auth.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
