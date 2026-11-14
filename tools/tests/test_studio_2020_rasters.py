"""Test new evidence contracts with original reports and synthetic transport.

The compressed reports below retain their original bytes. Generated PNGs and
movie payloads are explicitly synthetic validator fixtures, never game proof.
"""
from __future__ import annotations

import base64
import copy
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / 'tools'
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
import verify_studio_2020_rasters as verifier

FIXTURE_HEAD = '1' * 40
FIXTURE_TREE = '2' * 40
AVI_BYTES = b'synthetic-MovieMaker-input-for-contract-test\n' * 64
MOVIE_BYTES = b'synthetic-encoded-movie-for-contract-test\n' * 64


def original(name: str):
    entry = ORIGINAL_REPORTS[name]
    data = zlib.decompress(base64.b85decode(entry['data']))
    if hashlib.sha256(data).hexdigest() != entry['sha256']:
        raise ValueError('Original fixture identity changed: ' + name)
    return json.loads(data)


@lru_cache(maxsize=12)
def fixture_png(width: int, height: int) -> bytes:
    def chunk(kind, value):
        return struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind + value))
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    row = b'\x20\x40\x60' * (width // 2) + b'\xb0\x80\x20' * (width - width // 2)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
            + chunk(b'IDAT', zlib.compress((b'\0' + row) * height)) + chunk(b'IEND', b''))


def store_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + '\n')


def movie_proof(folder: Path) -> dict:
    def record(name):
        data = (folder / name).read_bytes()
        return {'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    return {'schema': 1, 'kind': 'actual_godot_movie', 'recording_fps': 24,
            'scope': 'Synthetic transport fixture, not an actual movie or renderer proof',
            'source_avi': record('facial-runtime.avi'), 'encoded_movie': record('facial-runtime.mp4'),
            'ffprobe': record('movie-ffprobe.json'), 'encode_log': record('movie-encode.log'),
            'decode_log': record('movie-decode.log'), 'probe_stderr': record('movie-ffprobe-stderr.log'),
            'encode_exit_code': 0, 'decode_exit_code': 0, 'probe_exit_code': 0}


def write_fixture(root: Path) -> None:
    """Original sidecar shapes plus declared synthetic pictures/movie envelopes."""
    root.mkdir(parents=True, exist_ok=True)
    (root / 'source-sha.txt').write_text(FIXTURE_HEAD + '\n')
    (root / 'source-tree.txt').write_text(FIXTURE_TREE + '\n')
    (root / 'source-dirty.txt').write_bytes(b'')
    face = root / verifier.FACE_DIRECTORY
    face.mkdir(parents=True)
    store_json(face / 'runtime-frames.json', original('face-runtime'))
    store_json(face / 'movie-ffprobe.json', original('movie-ffprobe'))
    (face / 'facial-runtime.avi').write_bytes(AVI_BYTES)
    (face / 'facial-runtime.mp4').write_bytes(MOVIE_BYTES)
    (face / 'movie-encode.log').write_text('synthetic encoder fixture\n')
    (face / 'movie-decode.log').write_bytes(b'')
    (face / 'movie-ffprobe-stderr.log').write_bytes(b'')
    store_json(face / 'movie.json', movie_proof(face))
    for name in verifier.face_names:
        (face / name).write_bytes(fixture_png(640, 640))
    c4 = root / verifier.C4_DIRECTORY
    c4.mkdir(parents=True)
    captures = []
    for example in original('c4-states'):
        name = example['name'] + '.png'
        size, discs, rings, paused, phase, visible, original_hash = verifier.c4_views[name]
        data = fixture_png(*size)
        (c4 / name).write_bytes(data)
        state = example['state']
        targets = [{'text': str(index), 'rect_px': [10 + (index % 5) * 72, 10 + (index // 5) * 60, 48, 48],
                    'hit_rect_px': [10 + (index % 5) * 72, 10 + (index // 5) * 60, 48, 48],
                    'size_dp': [48, 48], 'enabled': True} for index in range(9)]
        menu = [copy.deepcopy(targets[index]) for index in range(4)] if paused else []
        if menu:
            menu[-1]['text'] = 'Fortsetzen'
        captures.append({'file': name, 'sha256': hashlib.sha256(data).hexdigest(),
            'scope': 'visual_fixture_only', 'fixture_source_sha256': original_hash,
            'size_px': list(size), 'fixture_state': state,
            'geometry': {'disc_count': discs, 'discs': [{'mesh_class': 'CylinderMesh'} for _ in range(discs)],
                         'win_ring_count': rings, 'win_rings': [{'mesh_class': 'TorusMesh'} for _ in range(rings)],
                         'board_vertices': 2000, 'board_indices': 4000, 'board_depth': 0.4,
                         'original_lumo_visible': visible},
            'production_layout': {'settled': True, 'window_px': list(size), 'token': state['token'],
                                  'revision': state['revision'], 'board': state['board']},
            'input_requests_rejected': [], 'host_return_attempts': 0, 'raster_unique_samples': 100,
            'targets': targets, 'reachable_menu_targets': menu,
            'pause_caption': 'Spiel pausiert. Deine Runde bleibt gespeichert.' if paused else '',
            'caption': 'Cyan gewinnt!' if phase == 'won' else 'Gespeichert · Cyan ist dran'})
    source_hashes = {key: 'a' * 64 for key in verifier.C4_SOURCE_PATHS}
    store_json(c4 / 'visual-state.json', {'schema': 1, 'kind': 'connect_four_visual_fixture',
        'read_only_fixture_host': True, 'source_revision': FIXTURE_HEAD, 'checks': 200, 'errors': [],
        'density': 1, 'display_driver': 'fixture-x11', 'rendering_method': 'gl_compatibility',
        'source_before': source_hashes, 'source_after': source_hashes,
        'input_events': [{'kind': 'ScreenDrag'}, {'kind': 'ScreenTouch', 'pressed': False}],
        'captures': captures})
    write_treasure_fixture(root)


def write_treasure_fixture(root: Path, mutation: str = '') -> None:
    """Synthetic report contracts, not an additional renderer execution."""
    folder = root / 'captures/treasure_title_contrast_regression'
    folder.mkdir(parents=True)
    profiles = [
        ('landscape', 1920, 1080, 1.5, [112, 36, 0, 24]),
        ('compact', 640, 320, 1.0, [0, 0, 0, 0]),
        ('portrait', 1080, 2400, 2.625, [0, 136, 0, 63]),
        ('fold', 2176, 1812, 2.25, [0, 136, 0, 63]),
        ('landscape-cutout', 2400, 1080, 2.625, [136, 63, 0, 63]),
    ]
    observations = []
    for profile, width, height, density, insets in profiles:
        path = folder / f'treasure-title-{profile}.png'
        data = fixture_png(width, height)
        path.write_bytes(data)
        left, top, right, bottom = insets
        safe_width, safe_height = width - left - right, height - top - bottom
        avatar = [left + safe_width / 2 - 20, top + safe_height / 2 - 20, 40, 40]
        clue_role = 'hint' if profile in ('compact', 'landscape-cutout') else 'clue'
        boxes = {
            'header': [left + 12, top + 12, safe_width - 24, 48 * density],
            clue_role: [left + 12, top + 72 * density, 48 * density, 48 * density],
            'toast': [left + safe_width / 2 - 48 * density, height - bottom - 12 - 48 * density, 96 * density, 48 * density],
            'joystick': [left + 12, height - bottom - 12 - 48 * density, 48 * density, 48 * density],
            'action': [width - right - 12 - 48 * density, height - bottom - 12 - 48 * density, 48 * density, 48 * density],
            'jump': [width - right - 12 - 48 * density, height - bottom - 24 - 96 * density, 48 * density, 48 * density],
        }
        for restored in (False, True):
            item = {'profile': profile, 'window_px': [width, height],
                'density': density, 'insets_fixture': list(insets),
                'title_rect': [left + 12, top + 12, 360, 42 * density],
                'worst_white_backdrop_contrast': 14.4422647052388,
                'initial_state_fixture': 'original86445 first tree save' if restored else 'production fresh start',
                'gameplay_view': {'avatar_rect_px': list(avatar),
                    'secondary_white_backdrop_contrast': 14.4422647052388,
                    'hud_rects': [{'role': role, 'name': f'Fixture-{role}', 'rect_px': list(bounds),
                                   'overlap_px': [0, 0, 0, 0]} for role, bounds in boxes.items()]}}
            recorded = not restored if profile == 'landscape-cutout' else restored
            if recorded:
                item.update(image=str(path), image_sha256=hashlib.sha256(data).hexdigest(),
                            image_px=[width, height])
            observations.append(item)
    state = {'checks': 3341, 'failures': [], 'observations': observations,
             'scope': 'Production HUD, real ScreenTouch, declared saved-position and Android-boundary fixture; not device execution'}
    chosen = observations[3]
    image = folder / Path(chosen['image']).name
    view = chosen['gameplay_view']
    hud = {region['role']: region for region in view['hud_rects']}
    if mutation == 'title-missing-image':
        image.unlink()
    elif mutation == 'title-renamed-image':
        image.rename(folder / 'wrong.png')
    elif mutation == 'title-wrong-dimensions':
        data = fixture_png(640, 321)
        image.write_bytes(data)
        chosen['image_sha256'] = hashlib.sha256(data).hexdigest()
    elif mutation == 'title-reported-failure':
        state['failures'] = ['bad contrast']
    elif mutation == 'title-partial-checks':
        state['checks'] = 129
    elif mutation == 'title-boolean-checks':
        state['checks'] = True
    elif mutation == 'title-old-four-case-checks':
        state['checks'] = 137
    elif mutation == 'visibility-pre-spacing-checks':
        state['checks'] = 3273
    elif mutation == 'title-missing-profile':
        observations.pop()
    elif mutation == 'title-duplicate-profile':
        observations[-1] = dict(chosen)
    elif mutation == 'title-wrong-image-hash':
        chosen['image_sha256'] = '0' * 64
    elif mutation == 'title-wrong-reported-image':
        chosen['image'] = str(folder / 'treasure-title-portrait.png')
    elif mutation == 'title-wrong-window':
        chosen['window_px'] = [640, 321]
    elif mutation == 'title-wrong-density':
        chosen['density'] = 2
    elif mutation == 'title-wrong-insets':
        observations[0]['insets_fixture'] = [0, 36, 112, 24]
    elif mutation == 'title-wrong-fixture':
        chosen['initial_state_fixture'] = 'invented progress'
    elif mutation == 'title-low-contrast':
        chosen['worst_white_backdrop_contrast'] = 6.99
    elif mutation == 'title-nonfinite-contrast':
        chosen['worst_white_backdrop_contrast'] = float('nan')
    elif mutation == 'title-offscreen':
        chosen['title_rect'] = [630, 12, 360, 42]
    elif mutation == 'title-zero-area':
        chosen['title_rect'][2] = 0
    elif mutation == 'title-device-claim':
        state['scope'] = 'actual Android'
    elif mutation == 'visibility-missing-cutout-image':
        (folder / 'treasure-title-landscape-cutout.png').unlink()
    elif mutation == 'visibility-cutout-dimensions':
        data = fixture_png(2399, 1080)
        (folder / 'treasure-title-landscape-cutout.png').write_bytes(data)
        observations[8]['image_sha256'] = hashlib.sha256(data).hexdigest()
    elif mutation == 'visibility-cutout-insets-swapped':
        observations[8]['insets_fixture'] = [0, 63, 136, 63]
    elif mutation == 'visibility-cutout-capture-restored':
        for key in ('image', 'image_px', 'image_sha256'):
            observations[9][key] = observations[8].pop(key)
    elif mutation == 'visibility-extra-fresh-capture':
        for key in ('image', 'image_px', 'image_sha256'):
            observations[0][key] = observations[1][key]
    elif mutation == 'visibility-partial-unrecorded-image':
        observations[0]['image_sha256'] = observations[1]['image_sha256']
    elif mutation == 'visibility-missing-fresh':
        observations.pop(8)
    elif mutation == 'visibility-duplicate-restored':
        observations[8] = dict(observations[9])
    elif mutation == 'visibility-unrecorded-fresh-avatar-covered':
        fresh = observations[0]['gameplay_view']
        fresh['hud_rects'][0]['rect_px'] = list(fresh['avatar_rect_px'])
    elif mutation == 'visibility-unrecorded-fresh-low-contrast':
        observations[0]['gameplay_view']['secondary_white_backdrop_contrast'] = 6.99
    elif mutation == 'visibility-missing-avatar':
        view.pop('avatar_rect_px')
    elif mutation == 'visibility-zero-avatar':
        view['avatar_rect_px'][2] = 0
    elif mutation == 'visibility-nonfinite-avatar':
        view['avatar_rect_px'][0] = float('nan')
    elif mutation == 'visibility-avatar-offscreen':
        view['avatar_rect_px'][0] = 639
    elif mutation == 'visibility-missing-hud':
        view['hud_rects'].pop()
    elif mutation == 'visibility-duplicate-role':
        hud['jump']['role'] = 'action'
    elif mutation == 'visibility-no-role':
        hud['jump'].pop('role')
    elif mutation == 'visibility-compact-clue-instead-of-hint':
        hud['hint']['role'] = 'clue'
    elif mutation == 'visibility-tall-hint-instead-of-clue':
        observations[4]['gameplay_view']['hud_rects'][1]['role'] = 'hint'
    elif mutation == 'visibility-empty-control-name':
        hud['jump']['name'] = ''
    elif mutation == 'visibility-nonfinite-hud':
        hud['jump']['rect_px'][0] = float('inf')
    elif mutation == 'visibility-zero-hud':
        hud['toast']['rect_px'][2] = 0
    elif mutation == 'visibility-unsafe-hud':
        observations[8]['gameplay_view']['hud_rects'][0]['rect_px'][0] = 0
    elif mutation == 'visibility-hud-overlap-despite-zero-report':
        hud['toast']['rect_px'] = list(view['avatar_rect_px'])
    elif mutation == 'visibility-false-overlap-report':
        hud['toast']['overlap_px'] = [0, 0, 1, 1]
    elif mutation == 'visibility-toast-covers-jump':
        hud['toast']['rect_px'] = list(hud['jump']['rect_px'])
    elif mutation == 'visibility-toast-covers-hint':
        hud['toast']['rect_px'] = list(hud['hint']['rect_px'])
    elif mutation == 'visibility-small-touch':
        hud['jump']['rect_px'][3] = 47.98
    elif mutation == 'visibility-low-secondary-contrast':
        view['secondary_white_backdrop_contrast'] = 6.99
    elif mutation == 'visibility-nonfinite-secondary-contrast':
        view['secondary_white_backdrop_contrast'] = float('nan')
    if mutation != 'title-missing-report':
        (folder / 'treasure-title-report.json').write_text(
            '{' if mutation == 'title-malformed-report' else json.dumps(state))


def write_movie_commands(directory: Path, fixture_root: Path) -> None:
    """Explicit process-boundary stubs; never used outside synthetic tests."""
    directory.mkdir(exist_ok=True)
    encoder = directory / 'ffmpeg'
    encoder.write_text('#!' + sys.executable + '\n'
        'import os, pathlib, sys\n'
        'if "-f" in sys.argv: sys.exit(int(os.environ.get("FIXTURE_DECODE_RC", "0")))\n'
        'if os.environ.get("FIXTURE_ENCODE_RC"): sys.exit(int(os.environ["FIXTURE_ENCODE_RC"]))\n'
        'pathlib.Path(sys.argv[-1]).write_bytes(' + repr(MOVIE_BYTES) + ')\n'
        'print("synthetic encoder fixture")\n')
    encoder.chmod(0o755)
    probe = directory / 'ffprobe'
    probe.write_text('#!' + sys.executable + '\n'
        'import pathlib, sys\n'
        'sys.stdout.buffer.write(pathlib.Path(' + repr(str(fixture_root / verifier.FACE_DIRECTORY / 'movie-ffprobe.json')) + ').read_bytes())\n')
    probe.chmod(0o755)


class Studio2020RasterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        write_fixture(self.root)

    def mutate(self, directory, name, change):
        path = self.root / directory / name
        value = json.loads(path.read_bytes())
        change(value)
        store_json(path, value)

    def reject(self):
        with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
            verifier.verify(self.root, write=False)
        self.assertFalse((self.root / verifier.MANIFEST).exists())

    def test_original_sidecar_structures_bind_all_seventeen_decoded_synthetic_images(self):
        result = verifier.verify(self.root)
        self.assertEqual(len(result['images']), 17)
        self.assertEqual(len(result['reports']), 3)
        self.assertEqual(len(result['movies']), 1)
        self.assertEqual(result['source']['commit'], FIXTURE_HEAD)
        self.assertEqual(result['source']['tree'], FIXTURE_TREE)
        self.assertEqual(json.loads((self.root / verifier.MANIFEST).read_bytes()), result)

    def test_read_only_replay_preserves_all_original_files_and_manifests(self):
        expected = verifier.verify(self.root)
        before = {p.relative_to(self.root): (p.stat().st_mtime_ns, p.read_bytes())
                  for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(verifier.verify(self.root, write=False), expected)
        after = {p.relative_to(self.root): (p.stat().st_mtime_ns, p.read_bytes())
                 for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(after, before)

    def test_missing_extra_and_truncated_new_images_reject_all_original_reports(self):
        for directory in (verifier.FACE_DIRECTORY, verifier.C4_DIRECTORY, verifier.TITLE_DIRECTORY):
            with self.subTest(directory=directory):
                path = next((self.root / directory).glob('*.png'))
                data = path.read_bytes()
                path.unlink()
                self.reject()
                path.write_bytes(data[:40])
                self.reject()
                path.write_bytes(data)
                extra = self.root / directory / 'unexpected.png'
                extra.write_bytes(data)
                self.reject()
                extra.unlink()

    def test_symlinked_report_cannot_enter_read_only_verification(self):
        path = self.root / verifier.FACE_DIRECTORY / 'runtime-frames.json'
        original_path = self.root / 'saved-report.json'
        path.rename(original_path)
        path.symlink_to(original_path)
        self.reject()

    def test_mute_and_stop_cannot_retain_positive_jaw_after_early_audible_success(self):
        for index in (67, 112):
            with self.subTest(index=index):
                store_json(self.root / verifier.FACE_DIRECTORY / 'runtime-frames.json', original('face-runtime'))
                self.mutate(verifier.FACE_DIRECTORY, 'runtime-frames.json',
                            lambda value: value['rows'][index].update(actual_jaw_weight=.2))
                self.reject()

    def test_repeated_player_positions_and_missing_real_lid_weights_are_rejected(self):
        def freeze_positions(value):
            for row in value['rows']:
                if row['player']['audible'] and row['player']['state'] == 'playing':
                    row['player']['positionMs'] = 100
        self.mutate(verifier.FACE_DIRECTORY, 'runtime-frames.json', freeze_positions)
        self.reject()
        store_json(self.root / verifier.FACE_DIRECTORY / 'runtime-frames.json', original('face-runtime'))
        self.mutate(verifier.FACE_DIRECTORY, 'runtime-frames.json',
                    lambda value: value['rows'][0].update(lid_mesh_weights=[0] * 7))
        self.reject()

    def test_boolean_step_nonfinite_and_duplicate_json_fields_are_rejected(self):
        path = self.root / verifier.FACE_DIRECTORY / 'runtime-frames.json'
        self.mutate(verifier.FACE_DIRECTORY, path.name, lambda value: value['rows'][0].update(step=False))
        self.reject()
        path.write_text('{"recording_fps":24,"recording_fps":24}')
        self.reject()
        path.write_text('{"recording_fps":NaN}')
        self.reject()

    def test_movie_payload_hash_fps_decode_status_and_truncation_are_mandatory(self):
        folder = self.root / verifier.FACE_DIRECTORY
        avi = folder / 'facial-runtime.avi'
        avi.write_bytes(avi.read_bytes() + b'changed')
        self.reject()
        avi.write_bytes(AVI_BYTES)
        self.mutate(verifier.FACE_DIRECTORY, 'movie.json', lambda value: value.update(decode_exit_code=1))
        self.reject()
        store_json(folder / 'movie.json', movie_proof(folder))
        self.mutate(verifier.FACE_DIRECTORY, 'movie-ffprobe.json', lambda value: value['streams'][0].update(r_frame_rate='60/1'))
        store_json(folder / 'movie.json', movie_proof(folder))
        self.reject()

    def test_portrait_movie_dimensions_cannot_pass_square_face_capture(self):
        # Producer acf51d3 documents an actual 720x1280 MovieMaker output.
        # This is a synthetic transport replay of that format, not its movie.
        self.assertEqual(len(verifier.verify(self.root, write=False)['images']), 17)
        folder = self.root / verifier.FACE_DIRECTORY
        media = original('movie-ffprobe')
        media['streams'][0].update(width=720, height=1280)
        store_json(folder / 'movie-ffprobe.json', media)
        # Rebind the transport hash: rejection must be the dimensions, not a
        # stale proof digest or a corrupt image (the eight PNGs stay 640x640).
        store_json(folder / 'movie.json', movie_proof(folder))
        self.reject()
        store_json(folder / 'movie-ffprobe.json', original('movie-ffprobe'))
        store_json(folder / 'movie.json', movie_proof(folder))
        self.assertEqual(len(verifier.verify(self.root, write=False)['images']), 17)

    def test_movie_failed_decode_has_no_success_proof(self):
        prepared = self.root / 'fresh-face'
        prepared.mkdir()
        (prepared / 'facial-runtime.avi').write_bytes(AVI_BYTES)
        commands = self.root / 'bin'
        write_movie_commands(commands, self.root)
        env = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH'], FIXTURE_DECODE_RC='5')
        with mock.patch.dict(os.environ, env, clear=True), self.assertRaises(ValueError):
            verifier.collect_face_movie(prepared)
        self.assertFalse((prepared / 'movie.json').exists())
        self.assertTrue((prepared / 'movie-decode.log').exists())

    def test_c4_host_sha_missing_source_actual_actions_or_wrong_revision_are_rejected(self):
        path = self.root / verifier.C4_DIRECTORY / 'visual-state.json'
        before = path.read_bytes()
        changes = [lambda value: value.update(source_revision='3' * 40),
                   lambda value: value['source_before'].pop(next(iter(value['source_before']))),
                   lambda value: value['captures'][0].update(host_return_attempts=1),
                   lambda value: value['captures'][1]['production_layout'].update(revision=999)]
        for change in changes:
            with self.subTest(change=change):
                path.write_bytes(before)
                self.mutate(verifier.C4_DIRECTORY, path.name, change)
                self.reject()

    def test_c4_clipped_pause_target_and_mismatched_png_fail(self):
        path = self.root / verifier.C4_DIRECTORY / 'visual-state.json'
        before = path.read_bytes()
        self.mutate(verifier.C4_DIRECTORY, path.name,
                    lambda value: value['captures'][-1]['reachable_menu_targets'][-1].update(hit_rect_px=[0, 0, 1, 1]))
        self.reject()
        path.write_bytes(before)
        self.mutate(verifier.C4_DIRECTORY, path.name,
                    lambda value: value['captures'][0].update(sha256='0' * 64))
        self.reject()

    def test_treasure_contrast_profile_safe_bounds_and_original_hash_are_mandatory(self):
        path = self.root / verifier.TITLE_DIRECTORY / 'treasure-title-report.json'
        before = path.read_bytes()
        changes = [lambda value: value['observations'][0].update(worst_white_backdrop_contrast=6.99),
                   lambda value: value['observations'][0].update(insets_fixture=[0, 0, 0, 0]),
                   lambda value: value['observations'][0].update(title_rect=[-100, -100, 80, 40]),
                   lambda value: value['observations'][0].update(image_sha256='0' * 64)]
        for change in changes:
            with self.subTest(change=change):
                path.write_bytes(before)
                self.mutate(verifier.TITLE_DIRECTORY, path.name, change)
                self.reject()

    def test_dirty_or_non_commit_native_source_stamps_fail(self):
        (self.root / 'source-dirty.txt').write_text(' M scripts/games/example.gd\n')
        self.reject()
        (self.root / 'source-dirty.txt').write_bytes(b'')
        (self.root / 'source-tree.txt').write_text('not-a-tree\n')
        self.reject()

    def test_cli_read_only_rejects_forged_manifest_without_changing_originals(self):
        verifier.verify(self.root)
        path = self.root / verifier.MANIFEST
        document = json.loads(path.read_bytes())
        document['images'][0]['sha256'] = '0' * 64
        store_json(path, document)
        before = path.read_bytes()
        command = [sys.executable, str(TOOLS / 'verify_studio_2020_rasters.py'), 'verify', str(self.root), '--read-only']
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 1)
        self.assertIn('differs from recomputed evidence', result.stderr)
        self.assertEqual(path.read_bytes(), before)


    def test_treasure_title_requires_five_hash_bound_contrast_and_safe_layout_reports(self):
        # Exact producer counterexamples, replayed against the shared helper.
        for mutation in ["title-missing-image","title-renamed-image","title-wrong-dimensions","title-missing-report","title-malformed-report","title-reported-failure","title-partial-checks","title-boolean-checks","title-missing-profile","title-duplicate-profile","title-wrong-image-hash","title-wrong-reported-image","title-wrong-window","title-wrong-density","title-wrong-insets","title-wrong-fixture","title-low-contrast","title-nonfinite-contrast","title-offscreen","title-zero-area","title-device-claim"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                write_fixture(root)
                import shutil
                shutil.rmtree(root / verifier.TITLE_DIRECTORY)
                write_treasure_fixture(root, mutation)
                with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
                    verifier.verify(root, write=False)
                self.assertFalse((root / verifier.MANIFEST).exists())

    def test_treasure_requires_both_start_states_and_exact_cutout_capture_assignment(self):
        # Exact producer counterexamples, replayed against the shared helper.
        for mutation in ["visibility-missing-cutout-image","visibility-cutout-dimensions","visibility-cutout-insets-swapped","visibility-cutout-capture-restored","visibility-extra-fresh-capture","visibility-partial-unrecorded-image","visibility-missing-fresh","visibility-duplicate-restored","visibility-unrecorded-fresh-avatar-covered","visibility-unrecorded-fresh-low-contrast","title-old-four-case-checks","visibility-pre-spacing-checks"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                write_fixture(root)
                import shutil
                shutil.rmtree(root / verifier.TITLE_DIRECTORY)
                write_treasure_fixture(root, mutation)
                with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
                    verifier.verify(root, write=False)
                self.assertFalse((root / verifier.MANIFEST).exists())

    def test_treasure_requires_actual_avatar_and_complete_semantic_hud_bounds(self):
        # Exact producer counterexamples, replayed against the shared helper.
        for mutation in ["visibility-missing-avatar","visibility-zero-avatar","visibility-nonfinite-avatar","visibility-avatar-offscreen","visibility-missing-hud","visibility-duplicate-role","visibility-no-role","visibility-compact-clue-instead-of-hint","visibility-tall-hint-instead-of-clue","visibility-empty-control-name","visibility-nonfinite-hud","visibility-zero-hud","visibility-unsafe-hud"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                write_fixture(root)
                import shutil
                shutil.rmtree(root / verifier.TITLE_DIRECTORY)
                write_treasure_fixture(root, mutation)
                with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
                    verifier.verify(root, write=False)
                self.assertFalse((root / verifier.MANIFEST).exists())

    def test_treasure_recomputes_occlusion_and_preserves_accessible_hint_and_message(self):
        # Exact producer counterexamples, replayed against the shared helper.
        for mutation in ["visibility-hud-overlap-despite-zero-report","visibility-false-overlap-report","visibility-toast-covers-jump","visibility-toast-covers-hint","visibility-small-touch","visibility-low-secondary-contrast","visibility-nonfinite-secondary-contrast"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                write_fixture(root)
                import shutil
                shutil.rmtree(root / verifier.TITLE_DIRECTORY)
                write_treasure_fixture(root, mutation)
                with self.assertRaises((ValueError, KeyError, TypeError, OSError)):
                    verifier.verify(root, write=False)
                self.assertFalse((root / verifier.MANIFEST).exists())


# Four exact original report/state payloads, independently bound by SHA256.

ORIGINAL_REPORTS = {
    'face-runtime': {
        "sha256": '387e88b82304292e01a2dad27104da394a21d4507f5d245aeecee2563c6c31e3',
        "bytes": 83168,
        "data": (
            'c-rlqU2_{(a)$5yD^$8xp#J{YT<uMAm8w+bGL=$sCD>+G7FDEVWwW*aJ>3vj!i=Sv1&Aq*!x3%TB1nK3Jm}N?o<48?^@nHAo?pHG'
            '@bT*Ht6#4E=hc5-eR}n2fBn<XAD;i=8SE?*3?$Pmknlx+_uKv5-OamKf4+YAroQL--Cy3mz4}vq@%izspKfjsxBl_{kNdZuZ@Kx?'
            '-TwC1{hL=;AKzTp5A<Wzw|uz$xF6pBr?=Pd{`}2be);&JKEHl@bGLu<&2PB-aP$8CH^1d}|GIvq>vuoB`tki;-9YmB%Qv6;Z~s~U'
            '|Loac51+qYkkQ3}7k|I~@4w;k*Y@vzx_-BR_2%~K)4Nwc-d_E(?>ojXxBqnYzxywb)PG>7rUK|mN=BkDzTEUrb(<(Cgr+D`%Kc6M'
            '_2ur~Uf1Q=-~D|53*L?H8eS~-m*4y@@84eiWq(`0!C$|8+w=PuxxV=0)!V!M*E@Lr=Hu<vhwGbn|JJ{AQtW`75F&(Cj=pdI?$`a>'
            'oA>+Sbw0Y`kH21BAJ98`o$tTp`ps{C>ix~#^_Pbo-gNij>O<d2{aD@E{n!8Y<>}ph*uU?e`Qhlx3!p+%s8|#V=AmFwKnzeZg2ZqI'
            'H%iV8l}ASf7e<ArQ1KK;U=BpJ9HGKigt!S11^I@`qoYC#qastNgx2Ci&J+wFF+>HT;)*J8fWwB$<D<e0qoOmYkW{9UDd9X!RWu=m'
            '6bPuYnT?c3Cq)(}#U@E1Wpc=<wMKIoR1^e>MUqL?XhY@EQPG7_@yS#rpso*cSmi7>j4D<4)FrH3x0fK@3ZTbF#TG^-CQ)I5UT2hp'
            'EQh233xSa%I_j3GJU%JDFey1%DrY4kS&%5P5e`tPFBl*cCTS?Pq4Mac#KNc`OtPY=b%p9uwT9wDRw%lTMmI#;6u1?zl1sBPsn!}s'
            '7eQ8uNmW3@yp{p0^eI*}Y7yF&pcP1POUt!5sn=>^RFxBENg%_(LY|aS!Nscv+E96XRF;-&k*9ZoGF>F7@>}s?YD-2C6sYJx5gROz'
            '56jYmElw)7s-#sjBYUE$4PlY0qr)At{=f#y3Se1Uvc*ZwwrXXEN=L{d14ogC>*7h}wq7L>Zldi9U|CwV#Yx##$t%Cb3{6HEu>uBO'
            'e}Z}2U|t0)OUt%6soNGNVpQP+ii{B}R9{ujsJz9QH&z~>m8ErCjA>S=>Y&P2EEscC2~lOWb@|+?PO>eqtN@m!rCXfTZWSu86(R2Z'
            'WE-WoXz2)*<vN6KdxtB4Wohx2U>X*IPFR@LDw7?-B1#o?g3Ks4m1PC6EUn(sbgwNSq*6+63nh<WsY}QrQDLQ`&IZflcf~E<Y&)sm'
            'O3SlMz**N!MhPw=iDIo&Zp^sB^7ybUt=|$)!{P*Pf(EEYBUk{W7NPpjwhFC+m8Iodl4({nt=1T*;1M!X<RGh<?iz`zde#k=$A@KU'
            '`IdAB7GUN2M4g|EV5!VDqWk9raf>V~fMsd<mTVdpF-UPm)_^fAkcNTG47LT96|l0jd`mvf3W|q!;D{U*&KN1cmL3wki7YE%Woh}A'
            'Cgt1SQ|?9;WhM+6u>xk5`X&prZ;Q|hU|CwerJRNZt(Ku)h}d8Ri?fq?wC3-$)y*q_Woh}AC*|92J_x6XZm{KHEmR8=7=nAZL~Sko'
            'Yk*~G`IaZ-+adz0++k;lWX}jbeoctlpuz;iNpMSAR&Z4HB>mRC&jaG&2&spj0}oBY!=PwxqJ&!T9KS-ng%rI}R58eZ*G+Sym-Q@k'
            'kU+>=*;Zq;GeF|+gT%6ndZ#jDS{0)7Evot{UcdY4`(T}-^&+S+k)(khHA|kt6;E;{RCmnDM$CGA)ToayR;Y5ZPMa<4iF4%@nK`?Y'
            '8S0|oWw~<QiAnUEyF$pZs(J!fr|7~+?tsFmNO6S730%oES7Md*R8$l)J#NOUo46G}53WMpU7mWpDyXC`QfQSM7sd(+cUdV#1&>T*'
            'I}58*6lCNovs0}8LHYV@PQglN!j)H?(gdtDX^=s2A|*sU%etKQ)TsifRf;MtV63$;EiMd}(M~z*E#421dKOqGsm<nyQY<S`q{ca9'
            '*>r*xu5>tdfbOURw3xHrozMXb!k;=?loi%1a64qBCwf`32zZB;bX3HueCK%KIDxE_v}vKr<tlJx0|0amSw2lxtJLX*FS+@!>~m)W'
            'lRgUL`Q(EZs#cv7MztQgUN~k|61^*+6x!1z@w}LIl9Ek9RN*(WTZ19bAuA@yqKbsheW1!9z=nc?5%zJax|ojf<YN|K)LR_UsaD1d'
            'r&*PE?20a_>bn9XpGVe7vNthcrq_ZLRtwiTWaTtjZQcoBRVT3eU^T1@*{iX7n5g4ZCyP^{;(Mi|>Oy&8y@6rZk8e)os^_hSr)cDi'
            'sC|q#+AWvQ0ZU*SER4>tDh6AdCJn%<XjReK5bL7*Qx92UQTamDd$1NoyKt6O>D!KLmF+FjS`W|T>J&M>iZv;!SdBu@sS9OVTgUDN'
            'khbru3?2tE79QlY%2d5_3x4W3R!4J8ks^!b_$<>UuoCoLwr>PWtsmzl?{bRnPA#_gLYPqX$XQ%X%kF5HQDAXY?ruKd3fK<52H4KU'
            '`s8KzS}{zh7Q>3|d||Fkc3hQtW-&Wx_c?*9lVo?JN~@5`L`=UWkJkGLrDECPv(p@9(;_@pc&sp7b*NM_KX@tYNuyLMpORQ_ty3wx'
            '|1GoX&niQ6Aj5wC?YXLyNZ@}AtxMeBV`ORVE}l@YYQ-g!ONYJWU6bF@An<r|?gTtf>gw*btib?})NfXneMTtY{_|J)?|Xbsi}_VZ'
            'TK36$ugsqYNgD(cRTkk{^^aWg<Pjc}>jEF@(hf7l`zJ=wRw2Xc<P!Jy7=T`u$jWmHlIWv9QLp}46{(!mI^M>~sZyce9KN;x-9B|+'
            'K8~`v?*KWy4Nz-ttqIhxWc$DmUURQ^1d>)Pt>1(m24s6hbb+Vl#r`0sb&ptmbhic>{bLB8cX$5}aE$u{Y0`PRowdCwCv6u%E#Bhw'
            'bX!RFZx*t38NPnlERfT?2Uy|Qt9Tan;kHyo=sw|a*x#!Vc`}X(hYz+&s*`e@8+`Y+@BZZ?cli59vQnxYaxIRPuwW%DXCZmgJ_C>*'
            'oQf*3%nUiFmqVsE8rm|}>(1MkT$N?GP6O8xhxKK36ME{h-Gyl~+_^>N#FfA!oJZ41dkaucFgU6l>LE)`=j@2e^zK3>Nm$iy*2>=I'
            'pgv0bSh(IiS;^m%*Xk}zlSB0BI3rLAlJn{bKaD1?^)h<<!rF)YoCZe88Ja3QRZa#6YZMy=r|zrw!l}a)Z!}$$CW&1?UeDdC*Y-S`'
            ';xw8N!O%P^G#KPLJD)nejR0;8hgx2%bQ@IwiCWjX-D^97>4wuqaf;kYAFYE{JHpSxY3WXUo$18)Djz!@X>Z-}P(VoSuGa`k1K#qa'
            'i^3DEyWSo!>q3Lhf=8D&R?+D#0Wj<FKW$TMIZlhRy_^a!;tD?-JeP&XZC7OtWhDv}avnTO8?7kMz=NQy?ot0G&EbX;k)hP`Re<@n'
            'Y+V$dB-&-xyYh3Z-&tEoy0r6(PRsC6g}qdM+)_My4pZp%wzZU6mrY$a>+H+o^PLl9uWx>N|91aj|K|J5EI#sZS}E_z*OktAFIZH8'
            'XYj(<=RjH^Cq%aKFl#|(X&V-`8Ds=2J8SWwy}yRYh<DRNI}K(Jd)Sy+2{TLEvFMES%mJiYRaGDA!r>M%dvyD43L<H2N8#7P%+j_j'
            'I-@T$*3u)?10D#6%_QB&*TWKvobEK)OxV}L%+l^GI-??!QUp`ff0~^kGfdnUv71_BTbowH%+e+;Hlr0|I7pkAavxb3#+ml?L9T2E'
            'C1UgMUkx)$E5tUV5F=Geqa94DK#CzU)YDnb>KhP#*Tdp3a!vt*+Q`$}y@u%wesrqwcPHKW+vRD*c@5=uieB6%E1kyzwxiQIz6ds>'
            '9z!2->`|>f34(KkRz@Yy>_puq_tei;dA5TiCS~ti>SfUi-+}ktW7V?+=b?3qnry|fwH(t&tLU7w3N~rt-AkAlS8VE)3`b;DI1_V@'
            '9&6-^o9V{GOgARLs<2UEM7;aTNRBOaP5|o^rJ0lw2)iTa=v6<3E1Bl10<ZTehrXgnL)p2{fwn1wVpPbo&35C#wi~*v?S`EsNT*iJ'
            '=>1Ofdgae)<giJD@QPX9u4dAkrX0iEysLk%-=JGkMU6M(jfWa<=(5Hec9L>ksWo>cukA!7=bSaRNk8$5iDY?D1AuijFb9CxqtAsF'
            'cV16^^WJ!<_l7R(y<sOw+?B**1(tx&R6J`{^l7-f0#jD8(8JMT=s*tGV|TJW>pQ@0O4NmEx`5w?EiHcAq$fErJJuV4Dn{YJHsZ5j'
            '#jRD<+p&^$-Zo4wi_axYHEd}e+;SS9!&y5N>)E8orSU-{rwTv4iaS?@v-y-?7@rGxXV}t`xKH|)L#@Q&*a&rEKZ-tNbxVukj2Ig|'
            '7gjVcV3A=<i{m~yhZ3|Zk@lO0UZX}MZo5dSs7ge^p0thXxwIhua3>63x`Enh8Xs+^giw+~WHdnzxR0!J#U6$}K(gU;QG68YMwWV$'
            '_O(AxK=P$qsC`=Iu1dbODE~ZlLq_<hp(SF9_p$B`pUdJSx-*NO09nQLd1bsW-9+uvYPK;|=2L-(7@5b>C)y1_y78z@4mW%*i%-(-'
            '@Q~^VeqQ0_OZQXzv|eqd83<GvbPwAY;v;>?Rf8%wil9yQxhy`Hux#+9d#im~lD4Y2v@HsI;@q+Q-T@yb)(TLn6lxnj7slrT9u2;9'
            'o3&4i&b?8gshz<oCXMiEpE#h(udA@PE%&)BKIhDk@})&)pB9;WRt8n7gKQ!`%5|j29aJQ3@4@0}!{zaDSz1)~oWUiM45CW#p4&af'
            'MS4n9pNsG5S{p8pkIT{`a=;8OiM7rMBy_z!#-&Q}!|tb9<vJTKkB`gJs&P!WRJS#7cr8R#Ays}d#-#@|3w5g*;}%^WAD38KC61Ya'
            'mlhRWz&o~($QYOKp8KxRu2q{#yaHU7R)u5QSffW+R_Scw<S;Ibdg=fJdN<|xwic~`mZe4DkeT3OJ%m!s2=cfA{4*|9LOZoXl+f0F'
            'vj$w27JXydM58hiZ8t_!L6LD`BveIqw!OG+8{VtHWoeN&rVTWzh9+z$O(pc-q%O?B+H-_E(cRi>R)EXWqHaukXV78H8nUJIvNOU3'
            'gS4{X^!7;DXnA~EmezD*+BE~KdWI^XDJqQkxcwoEBZi>EjD;=JT>&mjYr2s$lQN=KA_MKiFfrP%?jCek>vlb*%`<KdxGb&dCd_%h'
            '17@WrWZmH~YAk2rl&tSb+oH=Va9LW@%^8~vYiovs<qk^ncr`-S!^ykKa0E6{_wjkjrA6JGalepWaKtNzIpnjW*6~1MWe4xM7Ta>P'
            '0$!F@b#ulpnW8-hq>rMs72JpyG436J&qLid@1_;-vb3(7GY-j^)FW#+jZnsC3kWhIlud#`HeOc1%hJMb&bT9go@Of2Qv`9`A%zaW'
            'B<&LbZrgga0$!F@cGKo;;l$LSLP#3gXrHkvZ0PxUiP7gOH(nl}m!+lMoUuhlq^u$c%y4{48^W_4`+GvK+3y;cb@&LzvOa=&itzhz'
            'AHke4Pe$POFpz95IBjJ125FvZJ)}>c`WTvr+X%+8HiCJIM*MIa!OXds1?GJauAR(=4$A_HD0O=<S6tg%1Rv%i7|Xf{<|$(GgIxp>'
            '=4_Y?9OyO*Vo1fotJi}r>%l!7dK}4SBlut&!6~*}c326l5ou2xKZ~uCl;?-r2qMfGHb)PasOQu3Acx+kwMYVJH>>yV#Z&h_y?~A2'
            '1Y3l%Ye!J;5sHy#owBPiagvXqbzi3zV3l)y?fpCnt{K^y`cSyFFBkQr3<qzaWv!NddZyTZ@}rO|2STn;Z`r<{7tZ6!a97LWVgBf#'
            'MmT}3lO*kauT+#2&mQ~eXR$RWal7>>)gGAJr>ll+scVvT+cMIVx2R+n#y(TTl42K5xEOHPQeaO#A9RqP!q!RhcW`ApnUxAD=#iD_'
            'DQwNi;Y{Yt5ss-EqqyZ-E2g!DrQ(*$SHj(Pi`-tr%ok=$XxDy~^@3}?>}M{Dr)cGcV)h9<Fa<s{;hK@oxoSkKNU!ZNI1(V-xp=E='
            '&&brDx&R@446?l%>w*n>YA(W7#IBI7HOkukAJ1d!6kQ#|DuFbwoH|I)LThdSVZmDuV!bRLzZVZHq5*NGuNYk=J#n&#NvpWZ=%Kc9'
            ';WDvag<Y)=Z4>G4$MYmkA?p+co_h94y{?B)EO-`LGlG0&a(&8Os8aUGQMN^FO6?!kLHfzh$RM*Y>0`T=%9j@8AMRs_a8fI_8!Jhr'
            '@`Oo#Ub;1-$tzjCSNc$ywduxCgsA1Ri^nRBJnhMg5SPX26268NIu_n6JTe{n4nJNo2)!+?Kt_XiHMo8G0bO}(j=MBK=WH$`EZwY)'
            'I3uZBRRtn_%nYi28Rp;}jPMYRWV6Ct2{5@hFmwId(j5og$X}V(c(iv^k>UxGOp;rB+zNm}SR9xc<=Y(5sOpR=yatZ1hlBFj6=xz-'
            'r!^ZeD*y%;2WCdjwh%LC5Y!lS_#ckSBYFEO)Vf5xMVK`JLyH45qfxhAx3uGFT9ulkev=;bU4<Kjscv(WRsjqz4vfwL!$9p*=sh`Z'
            'I5JRrsFL?!s7hfrFOD_vB8&54vjHaBqELHsck+lAbnkT70~EKadJVwn;=uS^3KO0v87eqvGx*#Asn~y@E~ac%^%{V&#es?0oLAcT'
            'Kh%|N7-3qhGqm2aa@!)zDu7vB=*66?s@pFNqFVwmVg!sRQc!OhV{AF^8h}|`=%qQK*L#Z}Bs6j`ZT2v<<}hnkhzM0Sn}sz1v$)Vp'
            'b3$)xFkK0C|CithnD*>uwW_*ZHyLIHz|i7CFU<+P))|a&R&MJfUOd9gq)qBnwsWm(;AL^0m*#X{ajL7N?YpeU=iUy$u%^|uY)>HH'
            'fLQ}Di|f2Jr}GkrQROO!d}X-x$ks=H>t^ng&|3<#24EJ~d1*%H)t=)?rdt0pkCr6s+0+$yloN1^Flzv2aiN!Hgx(^BN!v(QQ*|W6'
            'h_x95q4cHPs_HcWv$)VpGeWO|_sK!2g{S?+hQKsQ$^CCFOB*n20A_Kamu7@s(aK#sT@czwWC#oZas5*?A#Z!ts{m$kp_gWaUa177'
            '+rbIdh8s!bV3|Ej8++dUhRX_YSzPAj8JV|&2UoJ&HZ?*rT#$(S+<?o$u6rBrx(Z+xmw6fI{82*`vF+&k;PS`?st^)5491eJ0elU>'
            '@ZvHr&pKK3a2oaY%J9+ox5CIBpe`utHkxJ~z&upv6}O&Db@;3tv-r%YzJ<l1WFl>2fno0*_8DYPkw~C3@Tq&{fb?$Dl0o%;{{$-O'
            '<~Vv1Gt6Az{+=v$4^@k+sQ&tK)H41(>}IrMNaLVRfy|6;_=-UkaZ-iX!HnRN=3yA0Kl)&>$6(j}{ub=+WI}my;rn~C;5}4zRzLbU'
            '%AURl-i!tfeZIv*6+(;B;rW*eA5ze96?skh!?rCf4<FIz(`^t~84e%VbHYY4_=}6)+mnUvp~^L;ef`i`=4^7TdYel}q;_92;^<H('
            '06Izgj79I)pYHAI?Xehv2g8U_Bhf$hm-Fu7$+ES$$jv^96V{bd64!1z^wI265ID3lSE>Yk%4SRXS3u0-DmTY8F&31>Y-pPB8`tu#'
            '4TZBUTzNZUvkGDsm$^A7i6JHnE*^T~7yo7|LM6NvUqCwL*h0)2fLUDV7MKPmwXJ{HOnKm2b+0j~BoL_fq0kMO6#%oi&@DI#3~S}O'
            'axjGJQ(5D=PQYmelc39%#H;}rSzPEAngm9$(%FCnNB111y~GDwb*d1v*;cFqm&Mzeg{N^b7cDBlSwcp0OzR?wx7R5~n<;I;tN@tB'
            '+nGfsfl;iB)FUl=dfaF|VlWHoIRsTlZTo1e;N@Od{^9<)KfinZ`PaKg=GnjAyt(=C?EUS{n~$&ip`Lx%U%mc$fBWLu^}D<G`_Er{'
            'U2xo9y?AzWdtJ=bPrbc)U7tVQ+`jqeXYcCg|M>3B?alR@m+ybRdAF~Z_~pO+`+qz?JYIj#tGk<zx33S6db_{-!^@XfcX#^_cQ5;T'
            '-@N?w=KA&iWq)6N<^7NQx4TbQzdrxrZ~q4t;7cz'
        ),
    },
    'movie-ffprobe': {
        "sha256": 'fca341ff4aaf0787c4aeba1a5ebcf336ea9edc4db9571156db6c1a32c9f2844c',
        "bytes": 4655,
        "data": (
            'c-rk)O>g5i5WVMD7&^5;Vtv_?oLdmI-9w7)7jjuFgpou`Oe9hzDJR)Q{(Fa%?TsYL4vOBoLJ~Nd$027pd~fKl7YlqGsRV&WI@gO&'
            '=7oN~9zPifWd(UgfOk23pYwv`DT9Wf(W!!H<ya9lXXO$0VTrhfySTZ(#lOG)_R}v{tKmN_2(|FNv9DI}Ev<VWw5;q?sh8FucC;XT'
            '1_EV@K~q+0AnbB~7N-H;bLdB597Pk@6D?GQkZ3hdOhs^k%4*WSi*$ZyZ$IUr<`NM(w2E>jE!%=wYSK~wWfo%vGR@Mhz}?VegOOQ6'
            ')7B&f*^*qP0&otU1pj&xeL-bg!^?Z1EqzY6jSk0o>2?pRz-z~ln(Ro8fN+|RnhW&KO0%zR?pOh`h1>u#wTiv0oS-Vf8^B7;^*VK8'
            'oSZO4gfmGVsf(100!`PZ=t@DPq&qT33bNH1T#a5+nPN@pu}XB4K@94&CahFdD(M%q;>n?*MPGN5Jc@qbbgs?FVC7CQuq)qzQWOCh'
            'NCWU)KM0a!jFAe@VcIHNiS;(^#VmE{nP*ZWov8|z8XxgGj-wfb_7W}q2%mWDC8O#Xi@%Cv%R~r~X-jmSJf(dJYxE=}_NMaDm(7l3'
            'SeyotXC<Hj1&1A6`<A1@CEW)$B-0*1w$Ro3K#Yd&laftSZY*5Tl41$Xm~-AVSkyDt`bE%O&KMs-0DmMi)-4w~DQ1in0ZpbUZCapW'
            '7Ph0Z!{R@K%4-5FCEG1>%G_E(Dab42z?SAS5M7x?s;aKZ7|?po6T{jpC@G1W^)%13`<;}zpeG>>QKnpGJ+uV%b#~jNqP0#Nlyke&'
            'U@1|gV#8S8!2UWu_fSfEN!G})T|bA@vBI%!G_az^Lv~Q|d#$k_`j<BR4&y><?&<84_xbo^0~4l|&v5P?@@M2P{ms(%{6$T(XWdy0'
            '<GQd!IMcQGC%YDa{2fip&CTuNhnr#t49~&hrYk64-0}j;{>Kw-%H8ehCIz&g_cSR@yMi-KO5}$qd{N=p1${5S+gi0Vhy%s05(~lR'
            'xc7|IwvJ(MO0fWWXC{#-tJCJ|$k9iB9*YWPNSR0xEfhr`xHqGW!8v90T<^RvT0kRRwC3W!*2Q46-bBecVYI8>w_OX9aC1`bf{lM('
            '?t+bXUhclD-FLP7|Eb-d9D)Bz?dFureEQtG(nZ&R8mv}d<j7%q_lb)~bIWmY4?yLWyWS*m60LzGN$CC!?%}*#)m_7{wvZ#4UP+}z'
            '<|^?*;u3u;Mg?>4G~nX_{&SD~qhq>|mMAuF;?pGY?JI&{XfU^<-s0JY;4PGQ?bzIhdQ5D?cb7QlWwV0Iux#-+xNIKYQv6}WK$3s&'
            'X#V&YE?9qY@bUgF{45KfyLUK;yP5CDi8mn5;dNvkBw;v67p5d5sm!_12;X}fxV0Xg1|G0(GQ8rN(xH+!V-9X8L&%N@xnJ|z52pP9'
            'a*d)HO1beR56<v6(BE=kjwcE*?7Fttb;a0ph0dr*UoT!S{sD}xIk*'
        ),
    },
    'c4-states': {
        "sha256": 'cb2b8d22d32066777698ba4af01eb139e90c2d75bf7a7c2b95ab4b757de7f6c0',
        "bytes": 3872,
        "data": (
            'c-q}o+iv4F5d9ZDD+Y&m=Cyq(&;mtYjldX@!;N-j$<QU~HrRjfNOsa>y@^vdMbni4fgH^la>zM{T;CNfZmGB|qQ0Q*Zv1@FV4H@B'
            'J1WXzsQ=)9>tID`w76nJH}#P=xo#Fr*R~YLO=jz6L9ZJ8+)d-^<IuImgZpre(pU!Q%A3k-NIH1%pi+*>LKP)~R1yPPYY2TsP}z_}'
            'L<lk&mnBK6bP#jM5l0^Tt{CDqZLzq7viNXF;n8&1bL>7*%Vs?BuxoeQQqQhl0aZK?($+}O=qgM;Qk4)uX=}6bn62_rRg`7avhs?e'
            'vr3?fRn8o$@1{2WlsMQ75|ACqU~Q!=qUFSlhny>c$<EGnQx7#S)uo#|vFp=s4<=m}7(W%4YX0?+6C;i)%3_DpFgG(c1C>R@_Q$^4'
            '6_;Z_ad&r(!@L+f-if;XFt5YZx63k(x81L7rGB_~Zs>*@cHY+G$PEtGHPg1`|7+gts>7bgS&Q<`UygoTw=GZb=eni+a6R4fc#krp'
            '-|O+A(^Hxv{nCxg+8m5G*wpEVhdGN9N?EE>m!`BFk@~*lZEdHf`NEqV<Fu>i`0J}L<>SIXtkuQtx@#Ymy#`qZFfW(=g4tBvxan!w'
            'b?rbWI8b>9lwHCQL{eD+XoX%x#1NBqDx?4?Qp`d~PsTc>nInm*l8wd6{;xRT5(R{$Q~;q;v@T}pW6p+zQ6Z-%95BZmPzMgczrle6'
            '_yrQEQoR`u<dYt}3m)7R+=x7`<au;`lQxmsaV~?kSaFn<12I3!gSNqyY+R^wK*2XrV&%<(l8U9?8^4Er#W_y<?4yRUCrFkdP_W>1'
            '^eH%jE`dl{XlX(chC(3a1ZD7EqoIV}dYMrBEJ89d`tSFkk@}crtaAsN=~wdX(7z|z?Xn5y9W<h}T&|W2*1RFx?l}jCcW%ogwyn)f'
            'LH@$>mCILMJt5&ff&YYqa%EhYAIa5fg*k(e7e_Ikq34T1cwD*1cnb_XD+pukg5d*C7=W{;@`AvWFRbL>Pv8~1@j9W~Q|MyYV$=Mk'
            'b5@H|*%LaqKu;*0^&qo1PC+CAF>9nGE2V>#nPtstO%+Aqob=NA9CGFgl17r@PRQ>2RXVW8O6Lwj7oO3%J=vd=xv%dN@*Jsq^NTgy'
            'UnXXedoLG?_oGDrgveKa0zu7udj'
        ),
    },
    'treasure-title': {
        "sha256": '42edeca87413b05cb7b1ae4b6a717c8aebf18f3ef15d26db65a6ffe50e3b92c9',
        "bytes": 3116,
        "data": (
            'c-qyLOOM+)41n+RD~y~IN1~|L?x{czJua}jr=kdCiAs#g*s1Nz14aLPX=B<r-L?seqL|Gg2+2@<eIoSXrYIJ1NAb2_{830{m!l$w'
            'dVlO_RK0ySY1*o%?mi54+e}*46~%|?o2`kOz8;>&6H2}OtgY|DmRPq~KeXL#e+ZG*eeA*zcWdpPbw&qrPOaaEb?k@_zo*rf+B+J$'
            'rxhzw-B91JoI%v<ffYR`wc2(>4V#-p-71E|FlKr(5B0F8)jl+-XCsw|X1h2~X>)k|Qo{I=9>nq_2`8R~cVGGSy8zmZ75PM|sz5nN'
            'COcPwK!wRxib#j#l1Y$#R?<{4TZ*J)6o@KR2q8M4Sw>Ag)M3BrhcM74*N<a4V~Dn^w{;WtQ}sozyM8FRNGkepf9BuQ(9axabx9~^'
            'g()+a#9RO@|6B8+YjeGya{1EDQ{1V|n~vge78A@_OzloQa6%}cM9-tQ9=!1<i&5W5;Gu3(`|uOfV%+*+^RTPAqg9BvscR3L*fv8K'
            '`Y~OJB_e=9D>Tp0O@1Gj-)CC92&Q9u$MJ?Mh&DK%J6z@&D+{j5-bF-@!J!c`kcMD|NLp0Pwp2oa)KLU4v~$Vx4{||9<E{TKJd5x0'
            '`?c^RmY=(Lkz^^(PL=xXF4;39!qxa*9L+C=7fJ&!V<jKjj%%o|;di{%^X()q6AVmkaz17wK)6f+g8)Z~B^A&lWqgpHK~4^pL=zLp'
            'g#3Tr#?lJ>{RGP&EaY$Q!x_Y%dwJD9wpLjLW3_d17T&3Hq{wM&3^(l@ZY_n^+DW0&o-AILUMLG_xMNblwJZDbIDa|yF9iDB?$Z^('
            'gS2Ko8VMJH*TO?~<GSXy1kW!K^1O+$(wQ;}BXTqfLM5{Y(u5JT^umg4y#&nS{{{Tm$IGw-FKN&Y9TQ^g3~6b6X^rxh@e$|OKpR)0'
            '5^}m8Fng_dEVc4dNoi1P;jV=Jic$U?>^ILxEc)0Url$PWwdokgH+k{q-`C56(c2e)$C1l_+GE@;i$rlBI!e>T60cysALHNoJy*PH'
            'IBuO*ReNkw=$?w_0sdJu?ZBS*b)<qGDIQ0c#m&c0XoMYR'
        ),
    },
}


if __name__ == "__main__":
    unittest.main()
