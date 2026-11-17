from pathlib import Path
import ast, textwrap, json, hashlib
PACK=Path('/tmp/native-studio-52-gate-integration-20261114')
PRODUCER=Path('/workspace/scratch/b3485b7bb989/native-pr167-facial-treasure-integration-20261114/originals/producer-harness/tools/validate_studio.sh')
text=PRODUCER.read_text(); block=text.split("if ! python3 - \"$LOG_DIR\" <<'PY'\n",1)[1].split('\nPY\nthen',1)[0]
tree=ast.parse(block)
class ExplicitChecks(ast.NodeTransformer):
 def visit_Assert(self,node):
  return ast.copy_location(ast.Expr(ast.Call(ast.Name('require',ast.Load()),[self.visit(node.test),self.visit(node.msg) if node.msg else ast.Constant('Invalid Studio2020 report')],[])),node)
 def visit_Call(self,node):
  self.generic_visit(node)
  if isinstance(node.func,ast.Attribute) and isinstance(node.func.value,ast.Name) and node.func.value.id=='json' and node.func.attr=='loads' and len(node.args)==1:
   arg=node.args[0]
   if isinstance(arg,ast.Call) and isinstance(arg.func,ast.Attribute) and arg.func.attr=='read_text':
    return ast.copy_location(ast.Call(ast.Name('read_json',ast.Load()),[arg.func.value],[]),node)
  return node
constants=[]; functions=[]
for n in tree.body:
 if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in {'face_names','c4_views','treasure_title_views'} for t in n.targets):constants.append(ast.unparse(n))
 if isinstance(n,ast.FunctionDef) and n.name in {'face_report','c4_report','treasure_title_report'}:
  functions.append(ast.unparse(ast.fix_missing_locations(ExplicitChecks().visit(n))))
assert len(constants)==3 and len(functions)==3
header='''#!/usr/bin/env python3
"""Verify PR167's additional16 PNGs, actual facial movie and original sidecars.

The52-gate caller keeps every earlier gate and roster. Movie collection invokes
real ffmpeg/ffprobe once; verification can be completely read-only for publisher
replay. These are renderer-fixture/transport checks, never Android or device FPS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

from verify_village_rasters import verify_fixed_rasters

FACE_DIRECTORY = 'captures/lumo_facial_capture'
C4_DIRECTORY = 'captures/connect_four_visual_capture'
TITLE_DIRECTORY = 'captures/treasure_title_contrast_regression'
MANIFEST = 'studio-2020-images.json'
C4_SOURCE_PATHS = {
    'res://scripts/tests/connect_four_visual_capture.gd',
    'res://scenes/games/connect_four_table.tscn',
    'res://scripts/games/connect_four/connect_four_table.gd',
    'res://scripts/systems/host_bridge.gd',
    'res://scripts/app/mobile_runtime.gd',
    'res://scripts/app/android_safe_area.gd',
    'res://scripts/characters/lumo/lumo_rigged_actor.gd',
    'res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb',
}


def require(condition: bool, message: object) -> None:
    if not condition:
        raise ValueError(str(message))


def finite(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def file_record(root: Path, path: Path) -> dict:
    relative = path.relative_to(root)
    require(not root.is_symlink() and not any(part == '..' for part in relative.parts),
            'Evidence must remain inside its original root')
    current = root
    for part in relative.parts:
        current = current / part
        require(not current.is_symlink(), 'Symlinked evidence is forbidden: ' + str(path))
    require(path.is_file(), 'Missing original regular file: ' + str(path))
    before = path.stat()
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    after = path.stat()
    require((before.st_size, before.st_mtime_ns, before.st_ino)
            == (after.st_size, after.st_mtime_ns, after.st_ino),
            'Original changed while hashing: ' + str(path))
    return {'path': relative.as_posix(), 'bytes': after.st_size, 'sha256': digest}


def read_json(path: Path) -> dict:
    def invalid(value):
        raise ValueError('Nonfinite JSON constant: ' + value)
    def pairs(rows):
        result = {}
        for key, value in rows:
            require(key not in result, 'Duplicate JSON key: ' + key)
            result[key] = value
        return result
    require(path.stat().st_size <= 4 * 1024 * 1024, 'Oversized original report: ' + str(path))
    result = json.loads(path.read_bytes(), parse_constant=invalid, object_pairs_hook=pairs)
    require(isinstance(result, dict), 'Expected report object: ' + str(path))
    return result


def collect_face_movie(folder: Path) -> dict:
    """Encode the actual MovieMaker AVI, fully decode and preserve ffprobe output."""
    avi = folder / 'facial-runtime.avi'
    source = file_record(folder, avi)
    require(source['bytes'] > 1024, 'Missing actual MovieMaker AVI payload')
    names = ('facial-runtime.mp4', 'movie.json', 'movie-encode.log',
             'movie-decode.log', 'movie-ffprobe.json', 'movie-ffprobe-stderr.log')
    require(not any((folder / name).exists() or (folder / name).is_symlink() for name in names),
            'Refusing to replace existing facial movie evidence')
    movie = folder / 'facial-runtime.mp4'
    def run(name: str, command: list[str]) -> int:
        with (folder / name).open('xb') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        require(result.returncode == 0, (name, result.returncode))
        return result.returncode
    encode = run('movie-encode.log', ['ffmpeg', '-nostdin', '-n', '-i', str(avi),
        '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-c:a', 'aac',
        '-b:a', '128k', '-movflags', '+faststart', str(movie)])
    decode = run('movie-decode.log', ['ffmpeg', '-nostdin', '-v', 'error', '-xerror',
        '-i', str(movie), '-f', 'null', '-'])
    probe = subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-show_streams',
        '-show_format', '-of', 'json', str(movie)], stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, timeout=90)
    (folder / 'movie-ffprobe.json').write_bytes(probe.stdout)
    (folder / 'movie-ffprobe-stderr.log').write_bytes(probe.stderr)
    require(probe.returncode == 0, ('ffprobe', probe.returncode))
    require(not probe.stderr and not (folder / 'movie-decode.log').read_bytes(),
            'Movie decode or ffprobe reported an error')
    read_json(folder / 'movie-ffprobe.json')
    require(file_record(folder, avi) == source, 'MovieMaker source changed during collection')
    def identity(name):
        record = file_record(folder, folder / name)
        return {'file': name, 'bytes': record['bytes'], 'sha256': record['sha256']}
    result = {'schema': 1, 'kind': 'actual_godot_movie', 'recording_fps': 24,
        'scope': 'Actual MovieMaker frames and original local audio; not Android/device FPS or phoneme lip sync',
        'source_avi': identity('facial-runtime.avi'), 'encoded_movie': identity('facial-runtime.mp4'),
        'ffprobe': identity('movie-ffprobe.json'), 'encode_log': identity('movie-encode.log'),
        'decode_log': identity('movie-decode.log'), 'probe_stderr': identity('movie-ffprobe-stderr.log'),
        'encode_exit_code': encode, 'decode_exit_code': decode, 'probe_exit_code': probe.returncode}
    with (folder / 'movie.json').open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\\n')
    return result

'''
verify_start='''

def verify(root: Path, *, write: bool = True) -> dict:
    """Recompute all new evidence; write=False never changes the original pack."""
    root = Path(root)
    stamps = [file_record(root, root / name) for name in
              ('source-sha.txt', 'source-tree.txt', 'source-dirty.txt')]
    head = (root / 'source-sha.txt').read_text().strip()
    tree = (root / 'source-tree.txt').read_text().strip()
    require(re.fullmatch(r'[a-f0-9]{40}', head) and re.fullmatch(r'[a-f0-9]{40}', tree),
            'Exact Native source and tree stamps are required')
    require((root / 'source-dirty.txt').read_bytes() == b'', 'Native source stamp is dirty')
    def identity(path):
        return file_record(root, path)
    def verify_file(folder, report, name):
        require(isinstance(report, dict) and report['file'] == name, (folder, name))
        actual = identity(folder / name)
        require(type(report['bytes']) is int and report['bytes'] == actual['bytes'], name)
        require(report['sha256'] == actual['sha256'], name)
        return actual
'''
footer='''
    # Preserve every published sidecar condition, then bind the source and full
    # decoded rasters using the already active decoder (not header-only PNGs).
    face_folder, c4_folder, title_folder = (root / FACE_DIRECTORY, root / C4_DIRECTORY, root / TITLE_DIRECTORY)
    for folder, name in ((face_folder, 'runtime-frames.json'), (face_folder, 'movie.json'),
                         (face_folder, 'movie-ffprobe.json'), (c4_folder, 'visual-state.json'),
                         (title_folder, 'treasure-title-report.json')):
        file_record(root, folder / name)
    facial_state, facial_movie = face_report(face_folder)
    c4_state, c4_reported = c4_report(c4_folder)
    title_state, title_reported = treasure_title_report(title_folder)
    c4_document = read_json(c4_folder / 'visual-state.json')
    require(type(c4_document.get('checks')) is int and c4_document['checks'] > 0,
            'C4 visual report lacks actual checks')
    require(c4_document.get('source_revision') == head,
            'C4 report must identify the actual Native checkout, not the Host GITHUB_SHA')
    require(set(c4_document['source_before']) == C4_SOURCE_PATHS,
            'C4 report lacks the complete declared original source subset')
    proof = read_json(face_folder / 'movie.json')
    logs = [verify_file(face_folder, proof[key], name) for key, name in
            (('encode_log', 'movie-encode.log'), ('decode_log', 'movie-decode.log'),
             ('probe_stderr', 'movie-ffprobe-stderr.log'))]
    require(logs[1]['bytes'] == logs[2]['bytes'] == 0, 'Movie decode/ffprobe original stderr is not clean')
    require(proof['source_avi']['bytes'] > 1024 and proof['encoded_movie']['bytes'] > 1024,
            'Movie source/encoded payload is empty or truncated')
    face_expected = {FACE_DIRECTORY + '/' + name: (640, 640) for name in face_names}
    c4_expected = {C4_DIRECTORY + '/' + name: value[0] for name, value in c4_views.items()}
    title_expected = {TITLE_DIRECTORY + '/treasure-title-' + name + '.png': value[0]
                      for name, value in treasure_title_views.items()}
    images = []
    groups = ((FACE_DIRECTORY, face_expected, 'Facial runtime', 'facial-images.json'),
              (C4_DIRECTORY, c4_expected, 'C4 visual fixture', 'connect-four-visual-images.json'),
              (TITLE_DIRECTORY, title_expected, 'Treasure title', 'treasure-title-images.json'))
    for directory, expected, label, manifest in groups:
        # Inspect all ancestors before the reusable decoder opens any image.
        for relative in expected:
            file_record(root, root / relative)
        rows = verify_fixed_rasters(root, directory=directory, expected=expected,
                                    label=label, manifest=manifest, write=write)
        for entry in rows:
            name = Path(entry['path']).name
            if directory == FACE_DIRECTORY:
                entry['facial_runtime'] = facial_state
                entry['facial_movie'] = facial_movie
            elif directory == C4_DIRECTORY:
                require(c4_reported[name]['sha256'] == entry['sha256'], 'C4 original PNG hash mismatch: ' + name)
                entry['connect_four_visual_state'] = c4_state
            else:
                profile = Path(name).stem.removeprefix('treasure-title-')
                require(title_reported[profile]['image_sha256'] == entry['sha256'], 'Treasure original PNG hash mismatch: ' + name)
                entry['treasure_title_report'] = title_state
            images.append(entry)
    movie = {'encoded': identity(face_folder / 'facial-runtime.mp4'),
             'source_avi': identity(face_folder / 'facial-runtime.avi'),
             'proof': identity(face_folder / 'movie.json'),
             'ffprobe': identity(face_folder / 'movie-ffprobe.json'), 'logs': logs}
    result = {'schema': 1, 'kind': 'studio_2020_extension',
              'scope': '16 actual Native renderer PNGs, original facial movie and sidecars; no Android/device FPS or Dart rules acceptance',
              'source': {'commit': head, 'tree': tree, 'stamps': stamps},
              'images': images, 'reports': [facial_state, c4_state, title_state], 'movies': [movie]}
    if write:
        temporary = root / ('.' + MANIFEST + '.tmp')
        temporary.write_text(json.dumps(result, indent=2) + '\\n')
        temporary.replace(root / MANIFEST)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    replay = commands.add_parser('verify')
    replay.add_argument('log_dir', type=Path)
    replay.add_argument('--read-only', action='store_true')
    collect = commands.add_parser('collect-face-movie')
    collect.add_argument('capture_dir', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'collect-face-movie':
            collect_face_movie(args.capture_dir)
            print('[Studio2020Movie] PASS: actual AVI encoded, fully decoded and ffprobed')
        else:
            result = verify(args.log_dir, write=not args.read_only)
            if args.read_only:
                original = read_json(args.log_dir / MANIFEST)
                require(original == result, 'Original Studio2020 manifest differs from recomputed evidence')
            print('[Studio2020RasterRoster] PASS 16 actual PNG files, 3 original sidecars and 1 verified facial movie')
    except (OSError, ValueError, TypeError, KeyError, IndexError, subprocess.SubprocessError) as error:
        print('[Studio2020RasterRoster] FAIL: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
'''
source=header+'\n\n'.join(constants)+'\n'+verify_start+'\n'+ '\n\n'.join(textwrap.indent(s,'    ') for s in functions)+'\n'+footer
ast.parse(source)
assert not any(isinstance(node,ast.Assert) for node in ast.walk(ast.parse(source)))
out=PACK/'final-source/tools/verify_studio_2020_rasters.py';out.write_text(source)
(PACK/'ported-checks.json').write_text(json.dumps({'producer_harness_sha256':hashlib.sha256(PRODUCER.read_bytes()).hexdigest(),'ported_functions':['face_report','c4_report','treasure_title_report'],'published_assertions_preserved_as_explicit_require':sum(isinstance(n,ast.Assert) for fn in tree.body if isinstance(fn,ast.FunctionDef) and fn.name in {'face_report','c4_report','treasure_title_report'} for n in ast.walk(fn)),'note':'All published conditions retained; no Python assert optimization bypass. Full decoded-PNG/source/movie-log binding added. No original runner replacement.'},indent=2)+'\n')
print(out, len(source), 'bytes', 'require_calls',sum(isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='require' for n in ast.walk(ast.parse(source))))
