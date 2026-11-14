#!/usr/bin/env python3
"""Complete only the supplemental Jump/full-PNG reporting on unchanged originals."""
from pathlib import Path
import importlib.util
import hashlib
import json
import os
import re
import sys
import time

os.environ['GIT_OPTIONAL_LOCKS'] = '0'
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prior_reader_harness', ROOT / 'replay_native_originals.py')
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)
driver = harness.load_reader('original_reader_driver.py')


def main():
    import PIL
    from PIL import Image
    started = time.monotonic()
    before = driver.source_snapshot(harness.SOURCE, harness.NATIVE, harness.TREE)
    originals_before = driver.file_inventory(harness.ORIGINALS)
    driver.require(before == driver.read(harness.REPLAY / 'source-before.json')
                   and originals_before == driver.read(harness.REPLAY / 'original-files-before.json'),
                   'Original inputs changed since first bound-reader replay')
    test = harness.SOURCE / 'scripts/tests/lumo_original_jump_visual_regression.gd'
    expected = re.findall(r'^\s*print\("(\[JumpOriginalLumo\] PASS[^"\n]*)"\)\s*$',
                          test.read_text(), re.M)
    driver.require(len(expected) == 1, 'Unique actual source Jump marker required')
    jump = harness.ORIGINALS / 'nextgen/lumo_original_jump_visual_regression-headless.log'
    text = jump.read_text()
    driver.require(text.splitlines().count(expected[0]) == 1
                   and len(re.findall(r'^\[JumpOriginalLumo\]', text, re.M)) == 1
                   and not re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:', text),
                   'Actual source-bound Jump success marker differs')
    pngs = []
    for path in sorted(harness.ORIGINALS.rglob('*.png')):
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            image.load()
            driver.require(image.format == 'PNG' and min(image.size) > 0,
                           'Original PNG did not fully decode')
            pngs.append({'path': path.relative_to(harness.ORIGINALS).as_posix(),
                         'width': image.width, 'height': image.height, 'format': image.format,
                         **driver.record(path)})
    driver.require(len(pngs) == 188, 'Unexpected full original PNG inventory')
    driver.write_new(harness.REPLAY / 'all-original-png-decodes.json', pngs)
    after = driver.source_snapshot(harness.SOURCE, harness.NATIVE, harness.TREE)
    originals_after = driver.file_inventory(harness.ORIGINALS)
    driver.require(after == before and originals_after == originals_before,
                   'Supplemental read changed source/index/original evidence')
    prior = driver.read(harness.REPLAY / 'replay-summary.json')
    driver.require(prior['checked_native_seconds'] > 0 and prior['core_modes'] == 52
                   and prior['exception'] == 'Original Jump rig regression lacks its exact PASS marker'
                   and all(prior['unchanged'].values()), 'Unexpected first reporting outcome')
    native = driver.read(harness.REPLAY / 'checked-native.json')
    results = {'status': 'PASS', 'host_source': harness.HOST, 'native_source': harness.NATIVE,
               'native_tree': harness.TREE, 'run_id': 43616038272, 'run_attempt': 1,
               'artifact_id': 14125605621, 'python': sys.version, 'pillow': PIL.__version__,
               'ci_pillow': '12.3.0', 'engine_invocations': 0, 'renderer_invocations': 0,
               'bound_checked_native_completed_before_supplemental_reporting_error': True,
               'prior_checked_native_seconds': prior['checked_native_seconds'],
               'bound_checked_native_original_result': driver.record(harness.REPLAY / 'checked-native.json'),
               'initial_reporting_error': {'retained_log': 'reader-replay.log',
                   'retained_summary': 'replay-summary.json', 'initial_process_exit': 1,
                   'cause': 'Supplemental harness incorrectly expected a bare Jump PASS line; the committed probe appends its explicit rig checks.',
                   'correction': 'Expected full marker is extracted from the unchanged committed GDScript; no original reader or gameplay source was changed or rerun.'},
               'actual_jump_marker': expected[0], 'jump_original_log': driver.record(jump),
               'jump_probe_source': driver.record(test),
               'decoded_original_pngs': len(pngs),
               'core_modes': native['core_modes'],
               'all_6106_original_files_unchanged': originals_after == originals_before,
               'all_3770_source_files_and_raw_index_unchanged': before == after,
               'elapsed_seconds': round(time.monotonic() - started, 3),
               'scope': 'Original Desktop Native evidence replay and supplemental PNG decoding; visual review is separately recorded, no Android/FPS/audio claim'}
    driver.write_new(harness.REPLAY / 'supplemental-replay-summary.json', results)
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
