"""Write assets/kart/production/drivers/manifest.json for the rigged animal rivals.

Run after rig_meshy_drivers.py. Every LOD file is checked against the
build measurement (SHA-256, bytes, triangles) and its glTF structure (one
skin with the 26 body and face bones, the 12 clips, embedded textures only).
Each measurement must identify the retained Meshy original and its task ID.
Run: python3 tools/lumo_kart_art/drivers/write_animal_manifest.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/kart/production/drivers/manifest.json'
GENERATOR = 'tools/lumo_kart_art/drivers/rig_meshy_drivers.py'
SOURCE_MANIFEST = 'art/lumo_kart/meshy/20261123/drivers/source_manifest.json'
ANATOMY = 'tools/lumo_kart_art/drivers/meshy_anatomy.json'
CLIPS = {'idle', 'kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump', 'celebrate', 'kart_celebrate',
         'kart_hit', 'greeting_wave', 'agree_nod', 'point_portal', 'card_play'}
BONES = 26
MAX_STRUCTURE_BYTES = 2 * 1024 * 1024
MAX_IMAGE_BYTES = 1536 * 1024
MAX_TEXTURE_EDGE = 1024


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb(path: Path, bones: list[str]) -> dict:
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
    joint_names = [doc['nodes'][joint]['name'] for joint in doc['skins'][0]['joints']]
    assert len(bones) == BONES and set(joint_names) == set(bones), (path, joint_names)
    assert all('uri' not in i for i in doc.get('images', [])) and all('uri' not in b for b in doc['buffers']), path
    images = doc.get('images', [])
    assert len(images) == 1 and images[0].get('mimeType') == 'image/png', path
    bin_size, bin_kind = struct.unpack_from('<II', content, 20 + json_size)
    bin_start = 28 + json_size
    assert bin_kind == 0x004E4942 and bin_start + bin_size == len(content), path
    view = doc['bufferViews'][images[0]['bufferView']]
    image_size = view['byteLength']
    image_offset = view.get('byteOffset', 0)
    assert view['buffer'] == 0 and image_offset >= 0 and image_offset + image_size <= bin_size, path
    png = content[bin_start + image_offset:bin_start + image_offset + image_size]
    assert len(png) >= 24 and png[:8] == b'\x89PNG\r\n\x1a\n' and png[12:16] == b'IHDR', path
    width, height = struct.unpack_from('>II', png, 16)
    assert 0 < width <= MAX_TEXTURE_EDGE and 0 < height <= MAX_TEXTURE_EDGE, (path, width, height)
    assert image_size <= MAX_IMAGE_BYTES, (path, image_size)
    assert len(content) - image_size <= MAX_STRUCTURE_BYTES, (path, len(content) - image_size)
    return {'triangles': sum(acc[p['indices']]['count'] // 3 for p in prims), 'primitives': len(prims),
            'materials': [m.get('name', '') for m in doc['materials']], 'skin_joints': BONES, 'clips': clips,
            'embedded_images': [i.get('name', '') for i in images],
            'image_dimensions': [width, height], 'image_bytes': image_size,
            'structure_bytes': len(content) - image_size}


def main() -> None:
    roster = json.loads((ROOT / 'assets/characters/rivals/roster.json').read_text())
    original = json.loads((ROOT / SOURCE_MANIFEST).read_text())
    sources = {model['id']: model for model in original['models']}
    assert len(sources) == len(original['models']), 'Duplicate Meshy source IDs'
    assert {rival['id'] for rival in roster['opponents']} == set(sources), 'Roster/source mismatch'
    drivers = []
    for rival in roster['opponents']:
        species = rival['id']
        measured = json.loads((ROOT / 'evidence/lumo_kart_art/drivers' / species / 'measurement.json').read_text())
        source = sources[species]
        source_path = ROOT / source['source_file']
        assert source_path.stat().st_size == source['bytes'] and sha(source_path) == source['sha256'], source_path
        assert measured['species'] == species, species
        assert measured['source_file'] == source['source_file'], species
        assert measured['source_sha256'] == source['sha256'], species
        assert measured['task_id'] == source['task_id'], species
        assert measured['anatomy_file'] == ANATOMY, species
        assert measured['anatomy_sha256'] == sha(ROOT / ANATOMY), (species, 'Rebuild after anatomy changes')
        portrait = measured['portrait']
        portrait_path = ROOT / portrait['file']
        assert portrait['file'] == f'assets/kart/menu/drivers/{species}.webp', species
        assert portrait_path.stat().st_size == portrait['bytes'] and sha(portrait_path) == portrait['sha256'], portrait_path
        assert set(measured['lods']) == {'lod0', 'lod1', 'lod2'}, species
        lods = []
        for level, mesh in sorted(measured['lods'].items()):
            path = ROOT / mesh['file']
            filename = 'driver.glb' if level == 'lod0' else f'driver_{level}.glb'
            assert mesh['file'] == f'assets/kart/production/drivers/{species}/{filename}', path
            digest = sha(path)
            assert digest == mesh['sha256'] and path.stat().st_size == mesh['bytes'], path
            meta = glb(path, measured['bones'])
            assert meta['triangles'] == mesh['triangles'], (path, meta['triangles'], mesh['triangles'])
            lods.append({'level': level, 'file': mesh['file'], 'bytes': mesh['bytes'], 'sha256': digest,
                         'vertices': mesh['vertices'], 'max_influences': mesh['max_influences'], 'glb': meta})
        tris = [lod['glb']['triangles'] for lod in lods]
        assert tris[0] > tris[1] > tris[2] > 0, species
        assert tris[0] <= 30000, (species, tris[0])
        drivers.append({'id': species, 'roster_name': rival['name'],
                        'source': {'provider': 'Meshy', 'task_id': source['task_id'],
                                   'file': source['source_file'], 'sha256': source['sha256'],
                                   'bytes': source['bytes'], 'triangles': source['triangles'],
                                   'original_skins': source['skins'], 'original_animations': source['animations']},
                        'authoring': measured['authoring'], 'bones': measured['bones'],
                        'textures': measured['textures'], 'portrait': portrait,
                        'animations': measured['animations'], 'lods': lods})
    package = {
        'schema_version': 2,
        'asset_set': 'LUMO rival animals (kart, table)',
        'units': 'metres',
        'runtime_axes': 'X right, Y up, -Z forward',
        'source_manifest': {'file': SOURCE_MANIFEST, 'sha256': sha(ROOT / SOURCE_MANIFEST)},
        'source_generator': {'file': GENERATOR,
                             'sha256': sha(ROOT / GENERATOR),
                             'anatomy_file': ANATOMY,
                             'anatomy_sha256': sha(ROOT / ANATOMY),
                             'base_generator_sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/build_animal_drivers.py'),
                             'species_file_sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/animal_species.py'),
                             'body_file_sha256': sha(ROOT / 'tools/lumo_kart_art/drivers/animal_body.py')},
        'blender_sources': 'Reproducible from the rig generator and retained Meshy GLBs; .blend files are not versioned.',
        'mobile_asset_budget': {'lod0_triangles': 30000, 'skin_joints': BONES,
                                'embedded_images': 1, 'texture_max_edge': MAX_TEXTURE_EDGE,
                                'image_max_bytes': MAX_IMAGE_BYTES, 'structure_max_bytes': MAX_STRUCTURE_BYTES,
                                'rationale': 'Textured Meshy figures retain one reduced albedo atlas. Its encoded bytes are bounded separately from geometry, skin and twelve animation clips; the former total-size limit described untextured procedural figures.'},
        'android_performance': 'No device FPS claim is made by this package.',
        'drivers': drivers,
    }
    OUT.write_text(json.dumps(package, indent=2) + '\n', encoding='utf-8')
    print('ANIMAL_MANIFEST', OUT.relative_to(ROOT), len(drivers), 'drivers', sum(len(d['lods']) for d in drivers), 'files')


if __name__ == '__main__':
    main()
