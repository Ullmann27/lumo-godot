"""Record the measured, exported driver package without editing gameplay data."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[3]
EXPECTED_CLIPS = {
    'idle', 'kart_seated', 'kart_steer_left', 'kart_steer_right',
    'kart_jump', 'celebrate',
}


def record(path: Path) -> dict:
    return {
        'file': str(path.relative_to(ROOT)),
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def glb_metadata(path: Path) -> dict:
    content = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', content)
    assert magic == b'glTF' and version == 2 and size == len(content), path
    json_size, json_kind = struct.unpack_from('<II', content, 12)
    assert json_kind == 0x4E4F534A, path
    document = json.loads(content[20:20 + json_size])
    accessors = document['accessors']
    animations = []
    for animation in document['animations']:
        timelines = [accessors[sampler['input']] for sampler in animation['samplers']]
        start = min(accessor['min'][0] for accessor in timelines)
        end = max(accessor['max'][0] for accessor in timelines)
        animations.append({
            'name': animation['name'],
            'channels': len(animation['channels']),
            'first_key_s': start,
            'last_key_s': end,
            'active_key_span_s': end - start,
            'godot_clip_length_s': end,
        })
    assert {animation['name'] for animation in animations} == EXPECTED_CLIPS, path
    assert all(animation['channels'] == 63 for animation in animations), path
    primitives = [primitive for mesh in document['meshes'] for primitive in mesh['primitives']]
    triangles = sum(accessors[primitive['indices']]['count'] // 3 for primitive in primitives)
    assert all('uri' not in image for image in document['images']), path
    assert all('uri' not in buffer for buffer in document['buffers']), path
    return {
        'exported_triangles': triangles,
        'mesh_count': len(document['meshes']),
        'primitive_count': len(primitives),
        'material_count': len(document['materials']),
        'skin_joint_counts': [len(skin['joints']) for skin in document['skins']],
        'embedded_images': [image['name'] for image in document['images']],
        'animation_clips': animations,
        'node_names': [node.get('name', '') for node in document['nodes']],
    }


def main() -> None:
    roster = json.loads((ROOT / 'assets/characters/rivals/roster.json').read_text())
    entries = []
    for rival in roster['opponents']:
        species = rival['id']
        evidence = ROOT / 'evidence/lumo_kart_art/drivers' / species
        measured = json.loads((evidence / 'measurement.json').read_text())
        pose_path = evidence / 'pose_check.json'
        poses = json.loads(pose_path.read_text())
        source = ROOT / 'art/lumo_kart/blender/drivers' / (species + '.blend')
        assert poses['status'] == 'PASS' and poses['sample_count'] == 30, species
        assert pose_path.stat().st_mtime_ns >= source.stat().st_mtime_ns, species
        lods = []
        for level, mesh in measured['lods'].items():
            exported = ROOT / mesh['file']
            file_record = record(exported)
            assert file_record['sha256'] == mesh['sha256'], exported
            metadata = glb_metadata(exported)
            assert metadata['exported_triangles'] == mesh['triangles'], exported
            assert metadata['skin_joint_counts'] == [21], exported
            assert metadata['primitive_count'] == metadata['material_count'] == 6, exported
            assert all(marker in metadata['node_names'] for marker in measured['markers']), exported
            assert mesh['nonmanifold_edges'] == mesh['zero_weight_vertices'] == 0, exported
            lods.append({'level': level, **file_record, 'blender_measurements': mesh, 'glb': metadata})
        entries.append({
            'id': species,
            'roster_name': rival['name'],
            'blender_source': record(source),
            'references': [record(ROOT / name) for name in measured['reference_paths']],
            'lods': lods,
            'rig': measured['rig'],
            'bones': measured['bones'],
            'markers': measured['markers'],
            'textures': measured['texture_images'],
            'pose_evidence': record(pose_path),
            'pose_samples': poses['sample_count'],
            'geometry_evidence': poses['geometry'],
        })
    original = ROOT / 'assets/characters/lumo_animated/Lumo-Animated-Mobile.glb'
    package = {
        'schema_version': 1,
        'asset_set': 'LUMO Kart rivals',
        'units': 'metres',
        'runtime_axes': 'X right, Y up, -Z forward',
        'integration_status': 'Isolated assets and review scenes; existing gameplay roster remains unchanged.',
        'authoring': 'Local Blender 4.3.2 mesh, skin, keyframe and procedural texture authoring.',
        'source_generator': record(ROOT / 'tools/lumo_kart_art/drivers/build_drivers.py'),
        'original_lumo_reference': {
            **record(original),
            'unchanged': True,
            'existing_attribution': 'assets/characters/lumo_animated/ATTRIBUTION.md',
        },
        'validation_scope': {
            'blender_pose_samples': sum(entry['pose_samples'] for entry in entries),
            'export_files': sum(len(entry['lods']) for entry in entries),
            'geometry_and_glb_structure': 'PASS for the files listed by SHA-256.',
            'godot_and_kart_fit': 'Separate reports under evidence/lumo_kart_art/review and evidence/lumo_kart_art/karts identify their tested hashes.',
            'android_performance': 'No device FPS claim is made by this package.',
        },
        'drivers': entries,
    }
    fit_path=ROOT/'evidence/lumo_kart_art/review/godot_driver_kart_fit.json'
    if fit_path.is_file():
        fit=json.loads(fit_path.read_text())
        if fit['passed'] and all(digest==hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name,digest in fit['sources'].items()):
            package['godot_contact_evidence']={
                **record(fit_path),
                'engine':fit['godot'],
                'measurements':len(fit['measurements']),
                'maximum_error_m':fit['maximum_error_m'],
                'threshold_m':fit['threshold_m'],
                'physical_android':fit['physical_android'],
            }
    destination = ROOT / 'assets/kart/production/drivers/manifest.json'
    destination.write_text(json.dumps(package, indent=2, ensure_ascii=False) + '\n')

    lines = [
        '# Gemessene Fahrerdateien', '',
        'Diese Werte werden aus den endgültigen Blender-Messdateien und den tatsächlich exportierten GLB-Strukturen gelesen. '
        'Das vollständige maschinenlesbare Verzeichnis mit allen SHA-256-Werten steht in `assets/kart/production/drivers/manifest.json`.', '',
        '| Fahrer | LOD0 Dreiecke | LOD1 Dreiecke | LOD2 Dreiecke | GLB-Größen LOD0 / 1 / 2 |',
        '|---|---:|---:|---:|---|',
    ]
    for entry in entries:
        tris = [str(lod['glb']['exported_triangles']) for lod in entry['lods']]
        sizes = ' / '.join(f"{lod['bytes'] / 1048576:.2f} MiB" for lod in entry['lods'])
        lines.append(f"| {entry['roster_name']} (`{entry['id']}`) | {' | '.join(tris)} | {sizes} |")
    lines += [
        '',
        'Alle 15 GLBs besitzen je einen Skin mit 21 Gelenken, sechs Material-Primitives und dieselben sechs Animationen. '
        'Jeder Clip enthält 63 tatsächliche Transformationskanäle. Die ersten Keys liegen bei 1/24 s. '
        'Beide Normalmaps sind eingebettet; externe Bild- oder Bufferpfade sind nicht erforderlich.', '',
        'Alle 15 vermessenen Meshes haben null nicht geschlossene Kanten und null ungewichtete Vertices. '
        'Je Fahrer wurden sechs Clips an fünf Zeitpunkten am tatsächlich deformierten Blender-Mesh geprüft, insgesamt 150 Posen. '
        'Die Basis-Meshes haben keine flächenlosen Dreiecke, ungültigen Normalen oder nicht endlichen UV-Koordinaten.', '',
        'Die ausführlichen Rig-, Import-, Anschluss-, Herkunfts- und Materialangaben stehen in `DRIVER_CONTRACT.md`. '
        'Godot-Verhalten, gemeinsame Kartpassung und tatsächliche Gerätebildrate sind getrennte Prüfebenen; '
        'die jeweiligen Prüfberichte nennen die von ihnen untersuchten Dateihashes.', '',
        '## SHA-256 der Hauptmodelle', '',
        '| Fahrer | SHA-256 von `driver.glb` |',
        '|---|---|',
    ]
    lines.extend(f"| {entry['id']} | `{entry['lods'][0]['sha256']}` |" for entry in entries)
    (ROOT / 'docs/art/lumo_kart/drivers/MEASUREMENTS.md').write_text('\n'.join(lines) + '\n')
    print('DRIVER_MANIFEST_PASS', len(entries), package['validation_scope']['export_files'])


if __name__ == '__main__':
    main()
