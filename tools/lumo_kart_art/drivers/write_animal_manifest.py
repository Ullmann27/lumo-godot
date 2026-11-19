"""Write assets/kart/production/drivers/manifest.json for the rigged animal rivals.

Run after build_animal_drivers.py. Every LOD file is checked against the
build measurement (SHA-256, bytes, triangles) and its glTF structure (one
skin with the 26 body and face bones, the 12 clips, embedded textures only).
Run: python3 tools/lumo_kart_art/drivers/write_animal_manifest.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/kart/production/drivers/manifest.json'
CLIPS = {'idle', 'kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump', 'celebrate', 'kart_celebrate',
         'kart_hit', 'greeting_wave', 'agree_nod', 'point_portal', 'card_play'}
BONES = 26


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb(path: Path) -> dict:
    content = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', content)
    assert magic == b'glTF' and version == 2 and size == len(content), path
    json_size, json_kind = struct.unpack_from('<II', content, 12)
    assert json_kind == 0x4E4F534A, path
    doc = json.loads(content[20:20 + json_size])
    acc = doc['accessors']
    prims = [p for m in doc['meshes'] for p in m['primitives']]
    clips = sorted(a['name'] for a in doc['animations'])
    assert set(clips) == CLIPS, (path, clips)
    assert [len(s['joints']) for s in doc['skins']] == [BONES], path
    assert all('uri' not in i for i in doc.get('images', [])) and all('uri' not in b for b in doc['buffers']), path
    return {'triangles': sum(acc[p['indices']]['count'] // 3 for p in prims), 'primitives': len(prims),
            'materials': [m.get('name', '') for m in doc['materials']], 'skin_joints': BONES, 'clips': clips,
            'embedded_images': [i.get('name', '') for i in doc.get('images', [])]}


def main() -> None:
    roster = json.loads((ROOT / 'assets/characters/rivals/roster.json').read_text())
    drivers = []
    for rival in roster['opponents']:
        species = rival['id']
        measured = json.loads((ROOT / 'evidence/lumo_kart_art/drivers' / species / 'measurement.json').read_text())
        lods = []
        for level, mesh in sorted(measured['lods'].items()):
            path = ROOT / mesh['file']
            digest = sha(path)
            assert digest == mesh['sha256'] and path.stat().st_size == mesh['bytes'], path
            meta = glb(path)
            assert meta['triangles'] == mesh['triangles'], (path, meta['triangles'], mesh['triangles'])
            lods.append({'level': level, 'file': mesh['file'], 'bytes': mesh['bytes'], 'sha256': digest,
                         'vertices': mesh['vertices'], 'max_influences': mesh['max_influences'], 'glb': meta})
        tris = [lod['glb']['triangles'] for lod in lods]
        assert tris[0] > tris[1] > tris[2] > 0, species
        drivers.append({'id': species, 'roster_name': rival['name'], 'bones': measured['bones'],
                        'animations': measured['animations'], 'lods': lods})
    package = {
        'schema_version': 2,
        'asset_set': 'LUMO rival animals (kart, table)',
        'units': 'metres',
        'runtime_axes': 'X right, Y up, -Z forward',
        'source_generator': {'file': 'tools/lumo_kart_art/drivers/build_animal_drivers.py',
                             'sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/build_animal_drivers.py'),
                             'species_file_sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/animal_species.py'),
                             'body_file_sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/animal_body.py')},
        'blender_sources': 'Reproducible from the generator; .blend files are not versioned.',
        'android_performance': 'No device FPS claim is made by this package.',
        'drivers': drivers,
    }
    OUT.write_text(json.dumps(package, indent=2) + '\n', encoding='utf-8')
    print('ANIMAL_MANIFEST', OUT.relative_to(ROOT), len(drivers), 'drivers', sum(len(d['lods']) for d in drivers), 'files')


if __name__ == '__main__':
    main()
