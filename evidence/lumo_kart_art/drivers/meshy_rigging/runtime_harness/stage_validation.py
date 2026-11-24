"""Stage exact LUMO runtime sources and selected production assets for headless QA.

This is a temporary import harness, not a replacement implementation. Runtime
scripts are copied byte for byte from the shared checkout. Missing sparse files
are read from its immutable HEAD, and every staged source is hashed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

REPO = Path('/workspace/scratch/83ad04e680ae/asset-audit/repo')
HERE = Path(__file__).resolve().parent
AUTOLOADS = {
    'EventBus': 'scripts/systems/event_bus.gd',
    'SettingsStore': 'scripts/systems/settings_store.gd',
    'PerformanceManager': 'scripts/systems/performance_manager.gd',
    'MobileRuntime': 'scripts/app/mobile_runtime.gd',
    'HostBridge': 'scripts/systems/host_bridge.gd',
    'SceneRouter': 'scripts/app/scene_router.gd',
    'AudioManager': 'scripts/systems/audio_manager.gd',
    'ProgressStore': 'scripts/systems/progress_store.gd',
}
TESTS = [
    'scripts/tests/lumo_rival_rig_contract_regression.gd',
    'scripts/tests/lumo_kart_production_driver_regression.gd',
    'scripts/tests/cards_character_roster_regression.gd',
]
ALL_DRIVERS = ['lion', 'owl', 'rabbit', 'squirrel', 'turtle', 'frog', 'otter', 'badger', 'cat']


def source(path: str) -> bytes:
    local = REPO / path
    if local.is_file():
        return local.read_bytes()
    return subprocess.run(['git', 'show', f'HEAD:{path}'], cwd=REPO,
                          capture_output=True, check=True, timeout=60).stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--drivers', nargs='+', choices=ALL_DRIVERS, default=['rabbit'])
    parser.add_argument('--with-kart-fit', action='store_true')
    parser.add_argument('--keep-staged-drivers', action='store_true',
                        help='Prepare capture dependencies while production files are being regenerated.')
    args = parser.parse_args()
    pending = list(TESTS) + list(AUTOLOADS.values())
    pending += ['assets/characters/rivals/roster.json']
    pending += ['assets/kart/production/drivers/manifest.json']
    pending += [f'assets/cards_table/portraits/{id}.webp' for id in ALL_DRIVERS[:5]]
    pending += [f'assets/kart/menu/drivers/{id}.webp' for id in ALL_DRIVERS]
    pending += [f'assets/cards_table/ui/emote_{id}.webp' for id in ['think', 'happy', 'grumpy', 'idea', 'ask']]
    generated_import_defaults = []
    if args.with_kart_fit:
        pending += ['scripts/tests/kart_driver_fit_capture.gd']
        pending += ['assets/kart/production/details/kart_sticker_atlas.png',
                    'assets/kart/production/details/kart_flake_normal.png']
        kart_models = ['assets/kart/production/karts/aurora_comet' + suffix + '.glb'
                       for suffix in ['', '_lod1', '_lod2']]
        kart_models += ['assets/kart/production/fleet/comet.glb',
                        'assets/kart/production/meshy/comet.glb',
                        'assets/kart/production/parts/kart_parts.glb',
                        'assets/characters/lumo_facial/Lumo-Facial-Mobile.glb']
        for path in kart_models:
            pending.append(path)
            sidecar = path + '.import'
            tracked = subprocess.run(['git', 'ls-tree', 'HEAD', '--', sidecar], cwd=REPO,
                                     capture_output=True, check=True).stdout
            if (REPO / sidecar).is_file() or tracked:
                pending.append(sidecar)
            else:
                generated_import_defaults.append(sidecar)
    for id in args.drivers:
        for filename in ['driver.glb', 'driver_lod1.glb', 'driver_lod2.glb']:
            path = f'assets/kart/production/drivers/{id}/{filename}'
            pending += [path, path + '.import']
    staged = {}
    while pending:
        path = pending.pop()
        if path in staged:
            continue
        target = HERE / path
        if args.keep_staged_drivers and path.startswith('assets/kart/production/drivers/'):
            data = target.read_bytes()
        else:
            data = source(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_file() or target.read_bytes() != data:
            target.write_bytes(data)
        staged[path] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        if path.endswith('.gd'):
            text = data.decode('utf-8')
            pending += re.findall(r'(?:preload|load)\(\s*[\'"]res://([^\'"]+)[\'"]\s*\)', text)
            pending += re.findall(r'^extends\s+[\'"]res://([^\'"]+)[\'"]', text, flags=re.M)
    autoload = '\n'.join(f'{name}="*res://{path}"' for name, path in AUTOLOADS.items())
    (HERE / 'project.godot').write_text(
        'config_version=5\n\n[application]\nconfig/name="LUMO Meshy runtime verification"\n'
        'config/features=PackedStringArray("4.6", "GL Compatibility")\n\n'
        '[autoload]\n' + autoload + '\n\n'
        '[editor]\nimport/use_multiple_threads=false\n\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=REPO,
                              capture_output=True, check=True, text=True).stdout.strip()
    report = {'repository': str(REPO), 'base_commit': revision, 'drivers': args.drivers,
              'production_snapshot_reused': args.keep_staged_drivers,
              'normal_import_defaults_without_tracked_sidecar': generated_import_defaults,
              'method': 'Exact working-tree bytes; absent sparse files read from the same git HEAD.',
              'files': staged}
    (HERE / 'staged_sources.json').write_text(json.dumps(report, indent=2) + '\n')
    (HERE / 'logs').mkdir(exist_ok=True)
    print(json.dumps({'harness': str(HERE), 'drivers': args.drivers, 'files': len(staged),
                      'copied_bytes': sum(row['bytes'] for row in staged.values())}))


if __name__ == '__main__':
    main()
