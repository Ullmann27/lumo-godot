"""Check Original-Lumo tail skin exported by kart_production_lumo_tail_regression.gd.

Run from any directory:
blender -b -t 1 --python-exit-code 1 --python verify_original_lumo_tail.py -- \
    --samples /tmp/lumo-original-tail-validation
"""

import argparse
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

SOURCE = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--samples', type=Path, default=Path('/tmp/lumo-original-tail-validation'))
parser.add_argument('--output', type=Path, default=SOURCE / 'evidence/lumo_kart_runtime/karts/original_lumo_tail_surfaces.json')
options = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
ROOT = options.samples
sys.path.insert(0, str(SOURCE / 'tools/lumo_kart_art/karts'))
from inspect_mechanics import evaluated_surface


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds(points):
    if not points:
        return None
    return {
        'min_m': [min(p[i] for p in points) for i in range(3)],
        'max_m': [max(p[i] for p in points) for i in range(3)],
    }


capture = json.loads((ROOT / 'captures.json').read_text())
topology = json.loads((ROOT / 'topology.json').read_text())
assert capture['status'] == 'PASS', capture['failures']
assert sha256(ROOT / 'topology.json') == capture['topology_sha256']
weights, body_faces, tail_faces = [], [], []
for row in topology:
    offset = len(weights)
    assert len(row['vertex_weights']) == row['vertex_count']
    weights.extend(row['vertex_weights'])
    body_faces.extend(tuple(v + offset for v in face) for face in row['body_faces'])
    tail_faces.extend(tuple(v + offset for v in face) for face in row['tail_faces'])
assert body_faces and tail_faces
free_tail_faces = {
    i for i, face in enumerate(tail_faces)
    if any(weights[v]['dominant_bone'] in ('Tail1', 'Tail2', 'Tail3', 'TailTip') for v in face)
}
attachment_faces = set(range(len(tail_faces))) - free_tail_faces
attachment_vertices = {v for face in attachment_faces for v in tail_faces[face]}


def load_geometry(path):
    raw = path.read_bytes()
    cursor = 0
    poses = []
    for _ in range(2):
        rows, = struct.unpack_from('<I', raw, cursor)
        cursor += 4
        assert rows == len(topology)
        points = []
        for row in topology:
            count, = struct.unpack_from('<I', raw, cursor)
            cursor += 4
            assert count == row['vertex_count']
            values = struct.unpack_from(f'<{count * 3}f', raw, cursor)
            cursor += count * 12
            points.extend(Vector(values[i:i + 3]) for i in range(0, len(values), 3))
        poses.append(points)
    assert cursor == len(raw)
    return poses


def self_contact(points, original_attachment_region):
    body = BVHTree.FromPolygons(points, body_faces, all_triangles=True)
    tail = BVHTree.FromPolygons(points, tail_faces, all_triangles=True)
    pairs = body.overlap(tail)
    free_pairs = [pair for pair in pairs if pair[1] in free_tail_faces]
    attached_pairs = [pair for pair in pairs if pair[1] not in free_tail_faces]
    outside_attachment = [
        (a, b) for a, b in attached_pairs
        if any(
            points[v][axis] < original_attachment_region['min_m'][axis] - 0.000001
            or points[v][axis] > original_attachment_region['max_m'][axis] + 0.000001
            for v in tail_faces[b] for axis in range(3)
        )
    ]
    groups = Counter(
        '/'.join(sorted({weights[v]['dominant_bone'] for v in tail_faces[b]}))
        for a, b in attached_pairs
    )
    return {
        'all_self_pairs': len(pairs),
        'free_tail_body_pairs': len(free_pairs),
        'attachment_body_pairs': len(attached_pairs),
        'attachment_pairs_outside_original_region': len(outside_attachment),
        'original_attachment_region': original_attachment_region,
        'attachment_max_distal_weight': max((weights[v]['distal_tail'] for a, b in attached_pairs for v in tail_faces[b]), default=0.0),
        'attachment_dominant_bone_groups': dict(groups),
        'attachment_contact_bounds': bounds([points[v] for a, b in attached_pairs for v in tail_faces[b]]),
        'free_contact_bounds': bounds([points[v] for a, b in free_pairs for v in tail_faces[b]]),
    }


results = []
failures = []
checks = 0
for variant in ('comet', 'glider', 'turbo'):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE / f'art/lumo_kart/blender/karts/aurora_{variant}.blend'))
    bpy.context.scene.frame_set(1)
    coachwork, labels = evaluated_surface([
        obj for obj in bpy.data.objects['Coachwork'].children_recursive if obj.type == 'MESH'
    ])
    for sample in capture['samples']:
        if sample['variant'] != variant:
            continue
        path = ROOT / sample['geometry']
        assert sha256(path) == sample['file_sha256']
        corrected, baseline = load_geometry(path)
        original_region = bounds([baseline[v] for v in attachment_vertices])
        corrected_contact = self_contact(corrected, original_region)
        original_contact = self_contact(baseline, original_region)
        tail = BVHTree.FromPolygons(
            [Vector((p.x, -p.z, p.y)) for p in corrected], tail_faces, all_triangles=True
        )
        hits = coachwork.overlap(tail)
        parts = Counter(labels[a] for a, b in hits)
        checks += 4
        if hits:
            failures.append(f"{variant} {sample['phase']} frame {sample['frame']}: {len(hits)} kart intersections")
        if corrected_contact['free_tail_body_pairs']:
            failures.append(f"{variant} {sample['phase']} frame {sample['frame']}: {corrected_contact['free_tail_body_pairs']} free tail/body intersections")
        if original_contact['free_tail_body_pairs']:
            failures.append(f"{variant} {sample['phase']} frame {sample['frame']}: original free-tail baseline is not clear")
        if corrected_contact['attachment_pairs_outside_original_region']:
            failures.append(f"{variant} {sample['phase']} frame {sample['frame']}: attachment contact leaves original anatomical region")
        result = {
            **sample, 'kart_intersection_pairs': len(hits), 'kart_parts': dict(parts),
            'corrected': corrected_contact, 'same_pose_original_tail': original_contact,
            'tail_bounds': bounds([corrected[v] for v in {v for face in tail_faces for v in face}]),
        }
        results.append(result)
        print(json.dumps({
            'variant': variant, 'phase': sample['phase'], 'frame': sample['frame'],
            'kart': len(hits), 'free_self': corrected_contact['free_tail_body_pairs'],
            'attachment': corrected_contact['attachment_body_pairs'],
            'baseline_attachment': original_contact['attachment_body_pairs'],
        }), flush=True)

checks += 2
if len(results) != 72:
    failures.append(f'Expected 72 poses, found {len(results)}')
if sha256(SOURCE / 'scripts/games/kart_production_lumo_seat.gd') != capture['seat_adapter_sha256']:
    failures.append('Adapter source changed after capture')
report = {
    'status': 'PASS' if not failures else 'FAIL', 'checks': checks, 'failures': failures,
    'method': 'Independent Blender BVH against authored full Coachwork and actual Godot skin. Free tail includes every triangle with any vertex whose dominant bone is Tail1/Tail2/Tail3/TailTip. Shared TailBase-dominant attachment skin is classified by actual weights and compared to the same-pose original attachment. Every retained attachment contact must lie within the original same-pose attachment-skin bounds; only 1 micrometre numerical tolerance is permitted.',
    'scope': 'Full tail against all Coachwork meshes; all free-tail triangles against original non-tail body. Anatomical TailBase attachment overlaps are retained and reported, not claimed absent.',
    'body_triangles': len(body_faces), 'tail_triangles': len(tail_faces),
    'free_tail_triangles': len(free_tail_faces), 'poses': len(results),
    'seat_adapter_sha256': capture['seat_adapter_sha256'],
    'vehicle_script_sha256': capture['vehicle_script_sha256'],
    'model_sha256': capture['model_sha256'], 'original_model_sha256': capture['original_model_sha256'],
    'maximum_kart_pairs': max((row['kart_intersection_pairs'] for row in results), default=0),
    'maximum_free_tail_body_pairs': max((row['corrected']['free_tail_body_pairs'] for row in results), default=0),
    'samples': results,
}
options.output.parent.mkdir(parents=True, exist_ok=True)
options.output.write_text(json.dumps(report, indent=2) + '\n')
print(f"[OriginalTailDynamicBVH] {report['status']}: {checks} checks / {len(results)} poses", flush=True)
if failures:
    raise SystemExit(1)
