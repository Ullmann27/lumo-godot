#!/usr/bin/env python3
"""Recheck the separate Dream originals; write=False never changes any evidence."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys

from PIL import Image, ImageChops

ENGINE = '4.6.3.stable.official.7d41c59c4'
ERRORS = re.compile(r'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|'
                    r'resources still in use at exit|\[ProbeRunner\] (?:FAIL|timeout)')
PROBES = (
    ('lumo_dream_ambience_regression', 'headless', '[DreamAmbience] 170 checks, 0 failures'),
    ('dream_garden_props_regression', 'headless', '[DreamGarden] checks=544 failures=0'),
    ('lumo_dream_ambience_capture', 'rendered-treasure',
     '[DreamAmbienceCapture] PASS treasure original frames in {capture_root}/captures/treasure'),
    ('lumo_dream_ambience_capture', 'rendered-learning',
     '[DreamAmbienceCapture] PASS learning original frames in {capture_root}/captures/learning'),
    ('dream_garden_capture', 'rendered', '[DreamGardenCapture] failures=0'),
)
GARDEN = ((1280, 720), (412, 915), (2400, 1080))
WORLD_COUNTS = {'treasure': ('treasure_day', 48, 10), 'learning': ('learning_garden', 28, 8)}


def require(condition, message):
    if not condition:
        raise ValueError(str(message))


def disk_identity(path):
    info = path.lstat()
    if stat.S_ISLNK(info.st_mode):
        data = os.fsencode(os.readlink(path))
        return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                'actual_blob': hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest(),
                'mode': '120000'}
    require(stat.S_ISREG(info.st_mode), 'Nonregular source entry: ' + str(path))
    sha256 = hashlib.sha256()
    blob = hashlib.sha1(b'blob ' + str(info.st_size).encode() + b'\0')
    count = 0
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            count += len(block)
            sha256.update(block)
            blob.update(block)
    require(count == info.st_size, 'Source size changed while reading: ' + str(path))
    return {'bytes': count, 'sha256': sha256.hexdigest(), 'actual_blob': blob.hexdigest(),
            'mode': '100755' if info.st_mode & stat.S_IXUSR else '100644'}


def snapshot_source(project: Path, output: Path, phase: str) -> dict:
    """Bind tracked bytes/index, while recording generated import files separately."""
    project = Path(project).absolute()
    require(phase in ('before', 'after'), 'Invalid source snapshot phase')
    def git(*args):
        return subprocess.check_output(['git', '-C', str(project), *args],
                                       env={**os.environ, 'GIT_OPTIONAL_LOCKS': '0'})
    tagged = git('ls-files', '-v', '-z').decode('utf-8').split('\0')
    skipped = {row[2:] for row in tagged if row and row[0].upper() == 'S'}
    tracked = []
    for row in git('ls-files', '--stage', '-z').split(b'\0'):
        if not row:
            continue
        metadata, raw_path = row.split(b'\t', 1)
        mode, oid, stage = metadata.decode().split()
        require(stage == '0' and mode in ('100644', '100755', '120000'), 'Unmerged or unsupported tracked source')
        relative = raw_path.decode('utf-8')
        path = project / relative
        entry = {'path': relative, 'git_blob': oid, 'mode': mode, 'skip_worktree': relative in skipped}
        if not path.exists() and not path.is_symlink():
            require(relative in skipped, 'Missing tracked source: ' + relative)
            entry['materialized'] = False
        else:
            actual = disk_identity(path)
            require(actual['actual_blob'] == oid and actual['mode'] == mode,
                    'Tracked bytes or mode differ from the Git index: ' + relative)
            entry.update(actual, materialized=True)
        tracked.append(entry)
    names = {row['path'] for row in tracked}
    untracked = set(git('ls-files', '--others', '--exclude-standard', '-z').decode('utf-8').split('\0'))
    ignored_imports = git('ls-files', '--others', '--ignored', '--exclude-standard', '-z',
                          '--', '*.uid', '*.import').decode('utf-8').split('\0')
    untracked.update(p for p in ignored_imports if p and not p.startswith('.godot/'))
    generated = []
    for relative in sorted(untracked - {''}):
        category = 'other_untracked'
        source_path = None
        for suffix, kind in (('.uid', 'generated_uid'), ('.import', 'generated_import_metadata')):
            if relative.endswith(suffix) and relative[:-len(suffix)] in names:
                category, source_path = kind, relative[:-len(suffix)]
        generated.append({'path': relative, 'category': category, 'tracked_owner': source_path,
                          **disk_identity(project / relative)})
    index = Path(os.fsdecode(git('rev-parse', '--git-path', 'index')).strip())
    if not index.is_absolute():
        index = project / index
    result = {'schema': 1, 'head': git('rev-parse', 'HEAD').decode().strip(),
              'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
              'index_sha256': disk_identity(index)['sha256'],
              'tracked': sorted(tracked, key=lambda x: x['path']), 'untracked_import_inventory': generated,
              'scope': 'Tracked byte/index equality is separate from inventoried untracked/import outputs; no cleanup performed'}
    destination = output / ('source-inventory-' + phase + '.json')
    require(not destination.is_symlink(), 'Symlink source inventory')
    destination.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def file_record(root, relative):
    name = PurePosixPath(relative)
    require(not name.is_absolute() and '..' not in name.parts, 'Unsafe evidence path')
    path = root.joinpath(*name.parts)
    for ancestor in (path, *path.parents):
        require(not ancestor.is_symlink(), 'Symlink evidence: ' + str(path))
        if ancestor == root:
            break
    require(path.is_file(), 'Missing regular original: ' + relative)
    data = path.read_bytes()
    return {'path': relative, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def original_text(root, relative):
    record = file_record(root, relative)
    return (root / relative).read_bytes().decode('utf-8'), record


def original_json(root, relative):
    text, record = original_text(root, relative)
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Duplicate JSON key in ' + relative)
            result[key] = value
        return result
    result = json.loads(text, object_pairs_hook=unique)
    require(type(result) is dict, 'Expected JSON object: ' + relative)
    return result, record


def png(root, relative, dimensions):
    require(all(type(x) is int and 0 < x <= 4096 for x in dimensions) and
            dimensions[0] * dimensions[1] <= 8388608, 'Invalid raster dimensions')
    record = file_record(root, relative)
    require(0 < record['bytes'] <= 67108864, 'Invalid PNG byte size: ' + relative)
    path = root / relative
    with Image.open(path) as image:
        require(image.format == 'PNG' and image.size == tuple(dimensions), 'Wrong PNG dimensions: ' + relative)
        image.verify()
    with Image.open(path) as image:
        image.load()
        require(image.getchannel('A').getextrema()[1] > 0 if 'A' in image.getbands() else True,
                'Fully transparent renderer raster: ' + relative)
        decoded = image.convert('RGB')
    require(any(lo != hi for lo, hi in decoded.getextrema()), 'Uniform renderer raster: ' + relative)
    return {**record, 'width': dimensions[0], 'height': dimensions[1]}, decoded


def verify(root: Path, *, write: bool = False) -> dict:
    root = Path(root).absolute()
    require(root.is_dir() and not root.is_symlink(), 'Original evidence directory required')
    stamps = []
    source = {}
    for kind in ('sha', 'tree'):
        before, before_record = original_text(root, 'source-' + kind + '.txt')
        after, after_record = original_text(root, 'source-' + kind + '-after.txt')
        require(re.fullmatch(r'[0-9a-f]{40}\n', before) is not None and after == before,
                'Changed or invalid Native ' + kind + ' stamps')
        stamps.extend((before_record, after_record))
        source[kind] = before.strip()
    for name in ('source-dirty.txt', 'source-dirty-after.txt'):
        text, record = original_text(root, name)
        require(text == '', 'Tracked Native source is dirty: ' + name)
        stamps.append(record)
    engine, record = original_text(root, 'engine.txt')
    require(engine == ENGINE + '\n', 'Unexpected engine identity')
    stamps.append(record)
    inventories = []
    inventory_records = []
    for phase in ('before', 'after'):
        inventory, record = original_json(root, 'source-inventory-' + phase + '.json')
        require(inventory.get('schema') == 1 and inventory.get('head') == source['sha'] and
                inventory.get('tree') == source['tree'], 'Source inventory identity mismatch')
        require(type(inventory.get('index_sha256')) is str and
                re.fullmatch(r'[0-9a-f]{64}', inventory['index_sha256']) is not None,
                'Missing exact Git index identity')
        tracked = inventory.get('tracked')
        require(type(tracked) is list and tracked, 'Missing original tracked-byte inventory')
        paths = []
        for entry in tracked:
            require(type(entry) is dict and type(entry.get('path')) is str, 'Invalid tracked entry')
            name = PurePosixPath(entry['path'])
            require(not name.is_absolute() and '..' not in name.parts and str(name) == entry['path'],
                    'Unsafe tracked path')
            paths.append(entry['path'])
            require(re.fullmatch(r'[0-9a-f]{40}', entry.get('git_blob', '')) is not None and
                    entry.get('mode') in ('100644', '100755', '120000') and
                    type(entry.get('skip_worktree')) is bool, 'Invalid tracked Git identity')
            if entry.get('materialized') is True:
                require(entry.get('actual_blob') == entry['git_blob'] and
                        type(entry.get('bytes')) is int and entry['bytes'] >= 0 and
                        re.fullmatch(r'[0-9a-f]{64}', entry.get('sha256', '')) is not None,
                        'Tracked original bytes do not match the index')
            else:
                require(entry.get('materialized') is False and entry['skip_worktree'],
                        'Unexplained missing tracked source')
        require(paths == sorted(set(paths)), 'Tracked paths must be unique and ordered')
        require(type(inventory.get('untracked_import_inventory')) is list,
                'Missing generated import inventory')
        untracked_paths = []
        for entry in inventory['untracked_import_inventory']:
            require(type(entry) is dict and type(entry.get('path')) is str, 'Invalid import inventory entry')
            name = PurePosixPath(entry['path'])
            require(not name.is_absolute() and '..' not in name.parts and str(name) == entry['path'] and
                    entry['path'] not in paths, 'Unsafe or tracked import inventory path')
            untracked_paths.append(entry['path'])
            require(type(entry.get('bytes')) is int and entry['bytes'] >= 0 and
                    re.fullmatch(r'[0-9a-f]{64}', entry.get('sha256', '')) is not None and
                    re.fullmatch(r'[0-9a-f]{40}', entry.get('actual_blob', '')) is not None and
                    entry.get('mode') in ('100644', '100755', '120000'), 'Invalid import original identity')
            category = entry.get('category')
            require(category in ('generated_uid', 'generated_import_metadata', 'other_untracked'),
                    'Unknown import inventory classification')
            if category != 'other_untracked':
                suffix = '.uid' if category == 'generated_uid' else '.import'
                require(entry.get('tracked_owner') in paths and
                        entry['path'] == entry['tracked_owner'] + suffix,
                        'Generated import has no bound tracked owner')
        require(untracked_paths == sorted(set(untracked_paths)), 'Import paths must be unique and ordered')
        inventories.append(inventory)
        inventory_records.append(record)
    require(inventories[0]['tracked'] == inventories[1]['tracked'] and
            inventories[0]['index_sha256'] == inventories[1]['index_sha256'],
            'Tracked bytes or Git index changed during Dream probes')
    original_root, record = original_text(root, 'capture-root.txt')
    capture_root = original_root.removesuffix('\n')
    require(original_root == capture_root + '\n' and '\n' not in capture_root and
            PurePosixPath(capture_root).is_absolute() and '..' not in PurePosixPath(capture_root).parts and
            str(PurePosixPath(capture_root)) == capture_root, 'Invalid original capture root')
    stamps.append(record)
    results, result_record = original_text(root, 'results.tsv')
    expected = 'probe\tmode\tresult\n' + ''.join(f'{name}\t{mode}\tPASS\n' for name, mode, _ in PROBES)
    require(results == expected, 'All five exact Dream probe/mode pairs must pass once')
    logs = []
    for name, mode, template in PROBES:
        text, record = original_text(root, f'{name}-{mode}.log')
        lines = text.splitlines()
        marker = template.format(capture_root=capture_root)
        require(lines.count(marker) == 1, 'Missing or duplicate original success marker: ' + record['path'])
        require(sum(line.startswith('Godot Engine v' + ENGINE + ' - ') for line in lines) == 1,
                'One exact original engine invocation required: ' + record['path'])
        require(ERRORS.search(text) is None, 'Original engine error or resource leak: ' + record['path'])
        logs.append({**record, 'probe': name, 'mode': mode, 'marker': marker})
    expected_files = {f'captures/{world}/{world}_{i:02}.png' for world in WORLD_COUNTS for i in range(2)}
    expected_files |= {f'captures/{world}/{world}.json' for world in WORLD_COUNTS}
    expected_files |= {f'captures/garden/learning-dream-{w}x{h}.png' for w, h in GARDEN}
    actual = set()
    for path in (root / 'captures').rglob('*'):
        require(not path.is_symlink(), 'Symlink in captures')
        if path.is_file():
            actual.add(path.relative_to(root).as_posix())
    require(actual == expected_files, 'Missing or unexpected Dream capture files')
    images, reports, pairs = [], [], []
    for world, (preset, motes, butterflies) in WORLD_COUNTS.items():
        report, record = original_json(root, f'captures/{world}/{world}.json')
        scene = f'res://scenes/{"creative" if world == "treasure" else "learning"}/{world}_world.tscn'
        require(report.get('scene') == scene and report.get('renderer') == 'gl_compatibility' and
                type(report.get('display')) is str and report['display'].strip() == report['display'] and
                report['display'].casefold() not in ('', 'headless') and
                report.get('device_fps_measured') is False, 'Original renderer report identity: ' + world)
        frames = report.get('frames')
        require(type(frames) is list and len(frames) == 2, 'Two actual frames required: ' + world)
        decoded = []
        clocks = []
        try:
            for index, frame in enumerate(frames):
                require(type(frame) is dict, 'Invalid frame report')
                relative = f'captures/{world}/{world}_{index:02}.png'
                require(frame.get('path') == capture_root + '/' + relative, 'Foreign frame path: ' + world)
                dimensions = (frame.get('width'), frame.get('height'))
                state = frame.get('ambience')
                require(type(state) is dict, 'Missing actual ambience state')
                require(state.get('preset') == preset and state.get('tier') == 'high' and
                        state.get('reduced_motion') is False, 'Wrong captured ambience context')
                for key, value in [('motes', motes), ('butterflies', butterflies), ('batches', 2)]:
                    require(type(state.get(key)) is int and state[key] == value, 'Invalid ambience count: ' + key)
                clock = state.get('animation_time')
                require(type(clock) in (float, int) and math.isfinite(clock) and clock > 0,
                        'Invalid original animation clock')
                clocks.append(clock)
                image, pixels = png(root, relative, dimensions)
                images.append(image)
                decoded.append(pixels)
            require(clocks[1] > clocks[0], 'Original animation clock did not advance: ' + world)
            require(decoded[0].size == decoded[1].size, 'Frame size changed: ' + world)
            difference = ImageChops.difference(decoded[0], decoded[1])
            try:
                bounds = difference.getbbox()
            finally:
                difference.close()
            require(bounds is not None, 'Decoded original pixels did not change: ' + world)
            pairs.append({'world': world, 'animation_times': clocks, 'changed_pixel_bounds': list(bounds)})
        finally:
            for image in decoded:
                image.close()
        reports.append(record)
    for width, height in GARDEN:
        image, pixels = png(root, f'captures/garden/learning-dream-{width}x{height}.png', (width, height))
        pixels.close()
        images.append(image)
    result = {'schema': 1, 'native_source': source['sha'], 'native_tree': source['tree'],
              'engine': ENGINE, 'probes': logs, 'results': result_record, 'source_stamps': stamps,
              'source_inventories': inventory_records,
              'untracked_inventory_counts': [
                  {kind: sum(row['category'] == kind for row in x['untracked_import_inventory'])
                   for kind in ('generated_uid', 'generated_import_metadata', 'other_untracked')}
                  for x in inventories],
              'original_pngs': images, 'original_reports': reports, 'changed_pairs': pairs,
              'scope': 'Five separate Dream probes and seven original renderer PNGs; existing52/17, Android and visual review remain separate',
              'physical_android_fps_measured': False}
    if write:
        manifest = root / 'dream-images.json'
        require(not manifest.is_symlink(), 'Symlink Dream manifest')
        manifest.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--write', action='store_true', help='Create the separate original manifest after collection')
    parser.add_argument('--snapshot-source', type=Path, help='Record original tracked bytes/index and generated import inventory')
    parser.add_argument('--snapshot-phase', choices=('before', 'after'))
    args = parser.parse_args()
    try:
        if args.snapshot_source is not None:
            require(args.snapshot_phase is not None and not args.write, 'Source snapshot phase required')
            snapshot_source(args.snapshot_source, args.root, args.snapshot_phase)
            print('[DreamSourceSnapshot] recorded ' + args.snapshot_phase)
            return 0
        require(args.snapshot_phase is None, 'Source snapshot project required')
        result = verify(args.root, write=args.write)
        if not args.write:
            original, _ = original_json(args.root, 'dream-images.json')
            require(original == result, 'Original Dream manifest differs from recomputed evidence')
    except (OSError, ValueError, KeyError, TypeError, SyntaxError, subprocess.SubprocessError) as exc:
        print('[DreamRasterRoster] FAIL: ' + str(exc), file=sys.stderr)
        return 1
    print('[DreamRasterRoster] PASS 7 actual PNG files and 2 original reports')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
