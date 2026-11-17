#!/usr/bin/env python3
"""Check the two proven lower-body problem components across actual GLB clips."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_mechanics import evaluated_surface
from inspect_driver_appendages import bounds_godot


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def select_clothing(actor):
    """Resolve authored suit and belt after material batching and UV splitting."""
    allowed = {actor.vertex_groups[name].index for name in ('Pelvis', 'Spine', 'Chest')}
    eligible = {v.index for v in actor.data.vertices
                if sum(g.weight for g in v.groups if g.group in allowed) > .999
                and all(g.group in allowed or g.weight < 1e-6 for g in v.groups)}
    adjacency = {i: [] for i in eligible}
    for edge in actor.data.edges:
        a, b = edge.vertices
        if a in eligible and b in eligible:
            adjacency[a].append(b)
            adjacency[b].append(a)
    positions = {}
    for i in eligible:
        key = tuple(round(float(value), 6) for value in actor.data.vertices[i].co)
        if key in positions:
            other = positions[key]
            adjacency[i].append(other)
            adjacency[other].append(i)
        else:
            positions[key] = i
    remaining = set(eligible)
    candidates = []
    while remaining:
        seed = remaining.pop()
        component = {seed}
        queue = [seed]
        while queue:
            for neighbor in adjacency[queue.pop()]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        points = [actor.data.vertices[i].co for i in component]
        unique_positions = {tuple(round(float(value), 6) for value in point) for point in points}
        candidates.append((component, bounds_godot(points), len(unique_positions)))
    selected = {}
    specifications = {'TailoredRacingSuit': (.77, 1.30, 324), 'Belt': (.825, .886, 128)}
    for name, (lower, upper, count) in specifications.items():
        matches = [(indices, bounds, unique_count) for indices, bounds, unique_count in candidates
                   if abs(bounds['min'][1] - lower) < .0001
                   and abs(bounds['max'][1] - upper) < .0001 and unique_count == count]
        if len(matches) != 1:
            raise RuntimeError('Cannot unambiguously resolve authored component ' + name)
        selected[name] = matches[0][0]
    return selected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--drivers', default='rabbit,lion,squirrel,owl,turtle')
    parser.add_argument('--output', default='driver_torso_clearance.json')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    surfaces = {}
    kart_blend_hashes = {}
    kart_glb_hashes = {}
    for variant in ('comet', 'glider', 'turbo'):
        path = ROOT / 'art/lumo_kart/blender/karts' / ('aurora_' + variant + '.blend')
        exported = ROOT / 'assets/kart/production/karts' / ('aurora_' + variant + '.glb')
        kart_blend_hashes[variant] = digest(path)
        kart_glb_hashes[variant] = digest(exported)
        bpy.ops.wm.open_mainfile(filepath=str(path))
        bpy.context.scene.frame_set(1)
        surfaces[variant], _ = evaluated_surface([bpy.data.objects['BucketSeatShell']])
    cases = []
    driver_hashes = {}
    for species in args.drivers.split(','):
        path = ROOT / 'assets/kart/production/drivers' / species / 'driver.glb'
        source_hash = digest(path)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        actor = next(o for o in bpy.data.objects if o.type == 'MESH' and 'Pelvis' in o.vertex_groups)
        rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
        rig.animation_data_create()
        for track in rig.animation_data.nla_tracks:
            track.mute = True
        selected = select_clothing(actor)
        for clip in ('kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump'):
            actions = [a for a in bpy.data.actions if a.name == clip or a.name.startswith(clip+'_') or a.name.startswith(clip+'.')]
            if len(actions) != 1:
                raise RuntimeError('Cannot resolve clip ' + clip)
            rig.animation_data.action = actions[0]
            start, end = actions[0].frame_range
            for fraction in (0, .25, .5, .75, 1):
                frame = start + (end-start)*fraction
                bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
                bpy.context.view_layer.update()
                evaluated = actor.evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh = evaluated.to_mesh()
                mesh.calc_loop_triangles()
                vertices = [evaluated.matrix_world @ v.co for v in mesh.vertices]
                parts = {}
                for name, indices in selected.items():
                    faces = [tuple(t.vertices) for t in mesh.loop_triangles if all(i in indices for i in t.vertices)]
                    parts[name] = (BVHTree.FromPolygons(vertices, faces, all_triangles=True), faces)
                for variant, shell in surfaces.items():
                    component_results = {}
                    total_pairs = 0
                    for name, (surface, faces) in parts.items():
                        hits = shell.overlap(surface)
                        total_pairs += len(hits)
                        component_results[name] = {'triangles': len(faces), 'intersecting_triangle_pairs': len(hits)}
                        if hits:
                            hit_indices = {i for _, b in hits for i in faces[b]}
                            component_results[name]['intersecting_driver_triangle_bounds_godot_m'] = bounds_godot([vertices[i] for i in hit_indices])
                    cases.append({'driver': species, 'kart': variant, 'clip': clip,
                                  'clip_fraction': fraction, 'target': 'BucketSeatShell',
                                  'intersecting_triangle_pairs': total_pairs,
                                  'components': component_results})
                evaluated.to_mesh_clear()
        if digest(path) != source_hash:
            raise RuntimeError('Driver GLB changed during inspection: ' + species)
        driver_hashes[species] = source_hash
    result = {
        'method': 'Actual GLB import and skin/clip evaluation. Exactly the connected TailoredRacingSuit and Belt surfaces are resolved by Pelvis/Spine/Chest weights, authored height ranges (.77..1.30 and .825...886 m), and 324/128 unique positions after reconnecting GLB UV seams at 1e-6 m. Actual triangle BVH against each frozen Blender BucketSeatShell. The identified kart GLBs are the corresponding separately validated exports; this target-specific gate does not claim whole-body or soft-seat contact clearance.',
        'driver_sha256': driver_hashes, 'kart_blend_sha256': kart_blend_hashes,
        'kart_glb_sha256': kart_glb_hashes, 'cases': cases,
        'component_checks': len(cases)*2,
        'passed': all(c['intersecting_triangle_pairs'] == 0 for c in cases),
    }
    output = ROOT / 'evidence/lumo_kart_art/karts' / args.output
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'passed': result['passed'], 'cases': len(cases),
                      'component_checks': result['component_checks'],
                      'failed_cases': [c for c in cases if c['intersecting_triangle_pairs']],
                      'report': str(output)}))
    if not result['passed']:
        raise RuntimeError('The actual suit/belt surface still intersects a seat shell')


if __name__ == '__main__':
    main()
