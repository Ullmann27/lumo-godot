#!/usr/bin/env python3
"""Check authored driver tails and turtle shell against actual kart surfaces.

Run in Blender. This is a targeted surface-intersection gate, not a substitute for
whole-character visual review. It never modifies the driver or kart source files.
"""
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


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds_godot(points):
    points = [(v.x, v.z, -v.y) for v in points]
    return {name: [function(v[i] for v in points) for i in range(3)]
            for name, function in (("min", min), ("max", max))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--drivers', default='rabbit,lion,squirrel,owl,turtle')
    parser.add_argument('--output', default='driver_appendage_clearance.json')
    parser.add_argument('--source-format', choices=('blend', 'glb'), default='blend')
    parser.add_argument('--kart-format', choices=('blend', 'glb'), default='blend')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    karts = {}
    kart_hashes = {}
    kart_glb_hashes = {}
    for variant in ('comet', 'glider', 'turbo'):
        path = ROOT / 'art/lumo_kart/blender/karts' / ('aurora_' + variant + '.blend')
        glb_path = ROOT / 'assets/kart/production/karts' / ('aurora_' + variant + '.glb')
        kart_hashes[variant] = sha256(path)
        kart_glb_hashes[variant] = sha256(glb_path)
        if args.kart_format == 'blend':
            bpy.ops.wm.open_mainfile(filepath=str(path))
        else:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(glb_path))
        bpy.context.scene.frame_set(1)
        body = bpy.data.objects['Coachwork']
        karts[variant] = evaluated_surface([o for o in body.children_recursive if o.type == 'MESH'])

    cases = []
    driver_hashes = {}
    for species in args.drivers.split(','):
        if args.source_format == 'blend':
            path = ROOT / 'art/lumo_kart/blender/drivers' / (species + '.blend')
        else:
            path = ROOT / 'assets/kart/production/drivers' / species / 'driver.glb'
        before_hash = sha256(path)
        if args.source_format == 'blend':
            bpy.ops.wm.open_mainfile(filepath=str(path))
        else:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(path))
        actor = next(o for o in bpy.data.objects if o.type == 'MESH' and 'Chest' in o.vertex_groups)
        rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
        rig.animation_data_create()
        for track in rig.animation_data.nla_tracks:
            track.mute = True
        group = actor.vertex_groups['Chest' if species == 'turtle' else 'Tail'].index
        indices = {v.index for v in actor.data.vertices
                   if any(w.group == group and w.weight > .999 for w in v.groups)}
        if species == 'turtle':
            # The rear coordinate selects shell seeds unambiguously. Expand to
            # their entire disconnected source components, including front rim
            # faces, so moving a face across the threshold cannot hide contact.
            seeds = {i for i in indices if actor.data.vertices[i].co.y < -.24}
            adjacency = {i: [] for i in indices}
            for edge in actor.data.edges:
                a, b = edge.vertices
                if a in indices and b in indices:
                    adjacency[a].append(b)
                    adjacency[b].append(a)
            # GLB duplicates vertices across UV/material seams. Connect equal
            # source positions for selection only; geometry remains untouched.
            positions = {}
            for i in indices:
                key = tuple(round(float(value), 6) for value in actor.data.vertices[i].co)
                if key in positions:
                    other = positions[key]
                    adjacency[i].append(other)
                    adjacency[other].append(i)
                else:
                    positions[key] = i
            indices = set(seeds)
            queue = list(seeds)
            while queue:
                current = queue.pop()
                for neighbor in adjacency[current]:
                    if neighbor not in indices:
                        indices.add(neighbor)
                        queue.append(neighbor)
        if not indices:
            raise RuntimeError('No appendage vertices selected for ' + species)
        for clip in ('kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump'):
            candidates = [a for a in bpy.data.actions if a.name == clip or a.name.startswith(clip + '_') or a.name.startswith(clip + '.')]
            if len(candidates) != 1:
                raise RuntimeError('Cannot resolve exact driver clip ' + clip)
            rig.animation_data.action = candidates[0]
            begin, end = rig.animation_data.action.frame_range
            # Quarter phases include the authored sinusoidal tail sway extrema;
            # start/mid/end alone all miss its maximum lateral displacement.
            for fraction in (0, .25, .5, .75, 1):
                frame = begin + (end - begin) * fraction
                bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
                bpy.context.view_layer.update()
                evaluated = actor.evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh = evaluated.to_mesh()
                mesh.calc_loop_triangles()
                vertices = [evaluated.matrix_world @ v.co for v in mesh.vertices]
                faces = [tuple(t.vertices) for t in mesh.loop_triangles
                         if all(i in indices for i in t.vertices)]
                if not faces:
                    raise RuntimeError('No appendage triangles selected for ' + species)
                surface = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
                for variant, (body_bvh, sources) in karts.items():
                    hits = body_bvh.overlap(surface)
                    touched = {}
                    for a, b in hits:
                        touched[sources[a]] = touched.get(sources[a], 0) + 1
                    case = {
                        'driver': species, 'kart': variant, 'clip': clip,
                        'clip_fraction': fraction, 'triangles': len(faces),
                        'appendage': 'shell_components' if species == 'turtle' else 'tail',
                        'bounds_godot_m': bounds_godot([vertices[i] for i in indices]),
                        'intersecting_triangle_pairs': len(hits),
                        'coachwork_parts': touched,
                    }
                    if hits:
                        hit_vertices = {i for _, b in hits for i in faces[b]}
                        case['intersecting_appendage_triangle_bounds_godot_m'] = bounds_godot([vertices[i] for i in hit_vertices])
                    cases.append(case)
                evaluated.to_mesh_clear()
        after_hash = sha256(path)
        if before_hash != after_hash:
            raise RuntimeError('Driver source changed during inspection: ' + str(path))
        driver_hashes[species] = before_hash

    result = {
        'method': 'Blender source or actual GLB import (see source_format and kart_source_format), real skin/clip evaluation; rigid Tail weight > .999; turtle disconnected rigid Chest components seeded by local Blender Y < -.24 and expanded to full connected components (selection reconnects duplicated GLB seam positions at 1e-6 m precision); triangle BVH against frozen kart Coachwork. Surface intersections only; this is not a whole-driver clearance claim.',
        'source_format': args.source_format,
        'kart_source_format': args.kart_format,
        'driver_sha256': driver_hashes,
        'kart_blend_sha256': kart_hashes,
        'kart_glb_sha256': kart_glb_hashes,
        'cases': cases,
        'passed': all(c['intersecting_triangle_pairs'] == 0 for c in cases),
    }
    output = ROOT / 'evidence/lumo_kart_art/karts' / args.output
    output.write_text(json.dumps(result, indent=2) + '\n')
    failures = [c for c in cases if c['intersecting_triangle_pairs']]
    print(json.dumps({'passed': result['passed'], 'cases': len(cases), 'report': str(output),
                      'failed_case_count': len(failures),
                      'seated_start_failures': [c for c in failures if c['clip'] == 'kart_seated' and c['clip_fraction'] == 0]}))
    if failures:
        raise RuntimeError('Driver appendage/coachwork surface intersections require review')


if __name__ == '__main__':
    main()
