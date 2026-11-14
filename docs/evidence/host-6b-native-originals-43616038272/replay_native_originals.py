#!/usr/bin/env python3
"""Read the exact current original Native artifact; never invoke the engine."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import platform
import re
import sys
import tempfile
import time
import traceback

os.environ['GIT_OPTIONAL_LOCKS'] = '0'
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'source'
ORIGINALS = ROOT / 'originals'
REPLAY = ROOT / 'replay'
NATIVE = '84789d0c2c6fb4b6ecd2897ce1951b89f958b604'
TREE = '91cc8fc1c6f8a36336b7ac9a12585284a983a6f6'
HOST = '6b3047b7979dfb86d837e74a21b0fd890e4f9e66'
READER_BLOBS = {
    'original_reader_driver.py': '3c81457f029952ea4125bdb20da9e89a4f15d3b8',
    'verify_connect_four_delivery.py': '42d54aa5293750f64f1c0307b5d97aace354471d',
}


def load_reader(name):
    path = ROOT / 'reader' / name
    data = path.read_bytes()
    actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + bytes([0]) + data).hexdigest()
    if actual != READER_BLOBS[name]:
        raise ValueError('Reader differs from bound Git blob: ' + name)
    spec = importlib.util.spec_from_file_location(name.removesuffix('.py'), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    import PIL
    from PIL import Image
    driver = load_reader('original_reader_driver.py')
    delivery = load_reader('verify_connect_four_delivery.py')
    temporary = REPLAY / 'temporary'
    temporary.mkdir(exist_ok=False)
    tempfile.tempdir = str(temporary)
    run = driver.read(ROOT / 'metadata/host-run-attempt-original.json')
    driver.require(run['id'] == 43616038272 and run['run_attempt'] == 1
                   and run['head_sha'] == HOST, 'Wrong original Host run/attempt/source')
    source_before = driver.source_snapshot(SOURCE, NATIVE, TREE)
    remote = driver.read(ROOT / 'metadata/native-tree-original.json')
    driver.require(remote['sha'] == TREE and remote['truncated'] is False,
                   'Incomplete remote source tree')
    remote_files = {row['path']: (row['mode'], row['sha']) for row in remote['tree'] if row['type'] == 'blob'}
    actual_files = {row['path']: (row['git_mode'], row['blob']) for row in source_before['files']}
    driver.require(len(actual_files) == 3770 and actual_files == remote_files,
                   'Materialized source/index differs from full remote tree')
    driver.write_new(REPLAY / 'source-before.json', source_before)
    original_before = driver.file_inventory(ORIGINALS)
    driver.require(original_before == driver.read(REPLAY / 'original-files-before.json'),
                   'Original files changed after extraction')
    helper_before = driver.file_inventory(ROOT / 'reader')
    archive_before = driver.record(ROOT / 'native-6b-14125605621-original.zip')
    results = {'status': 'IN_PROGRESS', 'host_source': HOST, 'native_source': NATIVE,
               'native_tree': TREE, 'run_id': 43616038272, 'run_attempt': 1,
               'artifact_id': 14125605621, 'python': sys.version,
               'pillow': PIL.__version__, 'ci_pillow': '12.3.0',
               'platform': platform.platform(), 'reader_blobs': READER_BLOBS,
               'engine_invocations': 0, 'renderer_invocations': 0,
               'scope': 'Independent read-only replay of original Desktop Native evidence; no Android/FPS/audio claim'}
    started = time.monotonic()
    error = None
    try:
        step_started = time.monotonic()
        native = delivery.checked_native(ORIGINALS, SOURCE, NATIVE)
        driver.write_new(REPLAY / 'checked-native.json', native)
        results['checked_native_seconds'] = round(time.monotonic() - step_started, 3)
        results['core_modes'] = native['core_modes']
        results['core_logs'] = len(native['mode_logs'])
        results['live'] = {key: native['connections']['live'][key] for key in ('probe_count', 'png_count')}
        results['discovery'] = {key: native['discovery'][key] for key in ('probe_modes', 'png_count', 'report_count')}
        text = (ORIGINALS / 'connect-four-return.log').read_text()
        marker = 'CONNECT_FOUR_RETURN_PASS checks=21'
        driver.require(text.splitlines().count(marker) == 1
                       and len(re.findall(r'^CONNECT_FOUR_RETURN_', text, re.M)) == 1
                       and not re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:', text),
                       'Original extra Return log lacks unique clean 21-check ending')
        results['extra_return'] = {'marker': marker, **driver.record(ORIGINALS / 'connect-four-return.log')}
        jump = ORIGINALS / 'nextgen/lumo_original_jump_visual_regression-headless.log'
        jump_text = jump.read_text()
        driver.require(jump_text.splitlines().count('[JumpOriginalLumo] PASS') == 1,
                       'Original Jump rig regression lacks its exact PASS marker')
        results['jump_rig_headless'] = {'marker': '[JumpOriginalLumo] PASS', **driver.record(jump)}
        pngs = []
        for path in sorted(ORIGINALS.rglob('*.png')):
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                image.load()
                driver.require(image.format == 'PNG' and min(image.size) > 0,
                               'Original PNG did not fully decode')
                pngs.append({'path': path.relative_to(ORIGINALS).as_posix(),
                             'width': image.width, 'height': image.height,
                             'format': image.format, **driver.record(path)})
        driver.require(len(pngs) == 188, 'Unexpected original full PNG inventory')
        driver.write_new(REPLAY / 'all-original-png-decodes.json', pngs)
        results['all_original_pngs_decoded'] = len(pngs)
        results['status'] = 'PASS'
    except Exception as exc:
        error = exc
        results['status'] = 'FAIL'
        results['exception_type'] = type(exc).__name__
        results['exception'] = str(exc)
        traceback.print_exc()
    finally:
        source_after = driver.source_snapshot(SOURCE, NATIVE, TREE)
        original_after = driver.file_inventory(ORIGINALS)
        driver.write_new(REPLAY / 'source-after.json', source_after)
        driver.write_new(REPLAY / 'original-files-after.json', original_after)
        unchanged = {'all_3770_tracked_source_bytes_and_modes_unchanged': source_after == source_before,
                     'raw_source_index_unchanged': source_after['raw_index'] == source_before['raw_index'],
                     'all_6106_original_paths_bytes_and_modes_unchanged': original_after == original_before,
                     'reader_bytes_and_modes_unchanged': driver.file_inventory(ROOT / 'reader') == helper_before,
                     'original_zip_bytes_unchanged': driver.record(ROOT / 'native-6b-14125605621-original.zip') == archive_before}
        results['unchanged'] = unchanged
        results['elapsed_seconds'] = round(time.monotonic() - started, 3)
        if not all(unchanged.values()):
            results['status'] = 'FAIL'
        driver.write_new(REPLAY / 'replay-summary.json', results)
        print(json.dumps(results, indent=2))
    if error is not None:
        raise error
    driver.require(results['status'] == 'PASS', 'Read-only evidence boundary failed')


if __name__ == '__main__':
    main()
