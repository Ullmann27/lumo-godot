#!/usr/bin/env python3
"""Inspect the concrete lower racing-suit/seat-shell concern, without edits."""
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='driver_torso_probe.json')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    kart = ROOT / 'art/lumo_kart/blender/karts/aurora_comet.blend'
    driver = ROOT / 'art/lumo_kart/blender/drivers/rabbit.blend'
    driver_glb = ROOT / 'assets/kart/production/drivers/rabbit/driver.glb'
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (kart, driver, driver_glb)}
    bpy.ops.wm.open_mainfile(filepath=str(kart))
    shell, _ = evaluated_surface([bpy.data.objects['BucketSeatShell']])
    bpy.ops.wm.open_mainfile(filepath=str(driver))
    actor = bpy.data.objects['DriverMesh']
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = bpy.data.actions['kart_seated']
    begin = float(rig.animation_data.action.frame_range[0])
    bpy.context.scene.frame_set(int(begin), subframe=begin-int(begin))
    bpy.context.view_layer.update()
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
    remaining = set(eligible)
    components = []
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
        components.append(component)
    indices = max(components, key=len)
    evaluated = actor.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    vertices = [evaluated.matrix_world @ v.co for v in mesh.vertices]
    faces = [tuple(t.vertices) for t in mesh.loop_triangles if all(i in indices for i in t.vertices)]
    surface = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
    hits = shell.overlap(surface)
    hit_vertices = {i for _, b in hits for i in faces[b]}
    companion_components = []
    for component in sorted(components, key=len, reverse=True):
        if component is indices:
            continue
        component_faces = [tuple(t.vertices) for t in mesh.loop_triangles
                           if all(i in component for i in t.vertices)]
        component_surface = BVHTree.FromPolygons(vertices, component_faces, all_triangles=True)
        component_hits = shell.overlap(component_surface)
        companion_components.append({
            'vertices': len(component), 'triangles': len(component_faces),
            'bounds_godot_m': bounds_godot([vertices[i] for i in component]),
            'intersecting_triangle_pairs': len(component_hits),
        })
    result = {
        'method': 'Actual Blender source skin evaluation; Rabbit kart_seated at its first frame; largest connected component whose weights sum to >.999 exclusively on Pelvis/Spine/Chest; actual triangle BVH against Comet BucketSeatShell. No geometry or rig changes.',
        'source_sha256': hashes,
        'component_vertex_counts': sorted((len(c) for c in components), reverse=True),
        'selected_vertices': len(indices), 'selected_triangles': len(faces),
        'bounds_godot_m': bounds_godot([vertices[i] for i in indices]),
        'intersecting_triangle_pairs': len(hits),
        'intersecting_driver_triangle_count': len({b for _, b in hits}),
        'intersecting_driver_triangle_bounds_godot_m': bounds_godot([vertices[i] for i in hit_vertices]) if hit_vertices else None,
        'other_exclusively_torso_weighted_components': companion_components,
        'passed': not hits and all(not c['intersecting_triangle_pairs'] for c in companion_components),
    }
    evaluated.to_mesh_clear()
    for relative, digest in hashes.items():
        if hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() != digest:
            raise RuntimeError('A measured source changed during the test: ' + relative)
    output = ROOT / 'evidence/lumo_kart_art/karts' / args.output
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    if not result['passed']:
        raise RuntimeError('An actual torso-weighted clothing surface intersects the seat shell')


if __name__ == '__main__':
    main()
