"""Author LUMO's learning performance on the actual original fox in Blender.

The checked-in source stays untouched. The derivative keeps its recognizable
atlas, goggles, suit, 65 original bones and nine clips. Mouth topology, ear
joints, facial poses and teaching actions are authored here without a paid
service. Run with Blender 4.3.2; outputs and provenance are reproducible.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/characters/lumo_facial/Lumo-Facial-Mobile.glb'
ART = ROOT / 'art/lumo_next/character'
RUNTIME = ROOT / 'assets/lumo_next/character'
FPS = 30
TAU = math.tau
VISEMES = {
    'Neutral': (1.0, 0.0, 0.0, 0.0, 0.0),
    'AA': (0.94, 0.038, 0.003, 0.000, 0.0),
    'EE': (1.10, 0.017, 0.001, 0.000, 0.0),
    'OH': (0.50, 0.036, 0.008, 0.006, 0.0),
    'OU': (0.35, 0.027, 0.008, 0.012, 0.0),
    'MBP': (0.92, -0.0005, -0.0005, 0.005, 0.0),
    'FV': (1.00, 0.010, 0.000, 0.000, 0.0),
    'L': (0.96, 0.027, 0.002, 0.000, 0.0),
    'TH': (1.00, 0.018, 0.001, 0.000, 0.0),
    'Smile': (1.06, 0.005, 0.000, 0.000, 0.010),
    'Concern': (0.94, 0.002, 0.000, 0.000, -0.011),
}
CLIPS = {
    'idle_breathe': (8.0, True), 'listening': (6.4, True),
    'thinking': (5.2, True), 'answer': (1.3, False),
    'explain': (4.6, True), 'point': (2.8, False),
    'nod': (1.5, False), 'unsure': (2.6, False),
    'encourage': (3.2, False), 'celebrate_step': (2.4, False),
    'interrupt': (0.65, False), 'farewell': (2.5, False),
    'greeting': (3.2, False), 'focused_input': (9.0, True),
}
AXES = {'x': Vector((1, 0, 0)), 'y': Vector((0, 1, 0)), 'z': Vector((0, 0, 1))}


def clamp(value, lo=0.0, hi=1.0):
    return max(lo, min(hi, value))


def smooth(value):
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def ramp(a, b, value):
    return smooth((value - a) / (b - a))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def seam_z(x):
    return 1.2215 + 4.2 * x * x


def seam_y(x):
    return -0.3015 + 6.05 * x * x


def mouth_deform(point, name):
    """Local, bounded lower muzzle deformation. Nose and goggles stay fixed."""
    p = Vector(point)
    if name == 'Neutral':
        return p
    width, opening, upper, forward, corners = VISEMES[name]
    local = (1.0 - ramp(.115, .185, abs(p.x)))
    local *= ramp(1.125, 1.192, p.z) * (1.0 - ramp(1.267, 1.305, p.z))
    local *= (1.0 - ramp(-.19, -.10, p.y))
    local *= 1.0 - ramp(1.223, 1.238, p.z) * (1.0 - ramp(-.365, -.335, p.y))
    lower = 1.0 - ramp(-.0015, .0025, p.z - seam_z(p.x))
    p.z += local * (-opening * lower + upper * (1.0 - lower))
    p.z += corners * local * clamp(abs(p.x) / .09) ** 1.5
    p.x *= 1.0 + (width - 1.0) * local * .58
    p.y -= forward * local * .55
    if name in ['OH', 'OU']:
        p.z -= .017 * local * clamp(abs(point.x) / .10) ** 1.4
    if name in ['Smile', 'Concern']:
        brow = ramp(.035, .075, abs(point.x)) * (1.0 - ramp(.16, .20, abs(point.x)))
        brow *= ramp(1.405, 1.438, point.z) * (1.0 - ramp(1.460, 1.485, point.z))
        brow *= 1.0 - ramp(-.25, -.20, point.y)
        p.z += brow * (.010 if name == 'Smile' else .016 * (1 - clamp(abs(point.x) / .18)))
    return p


def material(name, color, roughness=.5, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    n = m.node_tree.nodes.get('Principled BSDF')
    n.inputs['Base Color'].default_value = (*color, 1)
    n.inputs['Roughness'].default_value = roughness
    n.inputs['Metallic'].default_value = metallic
    return m


def bind_mesh(obj, rig, name='Head'):
    vg = obj.vertex_groups.new(name=name)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    modifier = obj.modifiers.new('Lumo facial skin', 'ARMATURE')
    modifier.object = rig
    obj.parent = rig


def face_source(body):
    mesh = body.data
    mesh.calc_loop_triangles()
    positions = [v.co.copy() for v in mesh.vertices]
    triangles = [tuple(p.vertices) for p in mesh.loop_triangles]
    uv = [[mesh.uv_layers[0].data[i].uv.copy() for i in p.loops] for p in mesh.loop_triangles]
    subset = []
    for i, tri in enumerate(triangles):
        center = sum((positions[v] for v in tri), Vector()) / 3
        if abs(center.x) < .19 and 1.15 < center.z < 1.31 and -.352 < center.y < -.15:
            subset.append(i)
    local = BVHTree.FromPolygons(positions, [triangles[i] for i in subset], all_triangles=True)
    def sample(point):
        hit, normal, local_index, distance = local.find_nearest(point)
        if hit is None:
            raise RuntimeError('Mouth surface sample missed the measured original muzzle')
        index = subset[local_index]
        a, b, c = triangles[index]
        u, v, w = [Vector((co.x, co.y, 0)) for co in uv[index]]
        projected = barycentric_transform(hit, positions[a], positions[b], positions[c], u, v, w)
        return hit, normal, projected.xy
    return positions, triangles, uv, sample


def rebuild_body(body, positions, triangles, uvs, sample):
    """Weld sub-millimeter atlas cracks locally, open one manifold mouth loop."""
    from collections import defaultdict, Counter
    from mathutils.kdtree import KDTree
    original = body.data
    original_keys = {key.name: [p.co.copy() for p in key.data]
                     for key in original.shape_keys.key_blocks}
    old_weights = [[(g.group, g.weight) for g in v.groups] for v in original.vertices]
    group_names = [g.name for g in body.vertex_groups]
    tree = KDTree(len(positions))
    eligible = set()
    for i, p in enumerate(positions):
        tree.insert(p, i)
        if abs(p.x) < .20 and 1.14 < p.z < 1.33 and p.y < -.12:
            eligible.add(i)
    tree.balance()
    groups = []
    mapping = {}
    for i, p in enumerate(positions):
        if i in mapping:
            continue
        near = [j for co, j, distance in tree.find_range(p, .0008)
                if j in eligible and j not in mapping] if i in eligible else [i]
        if not near:
            near = [i]
        group = len(groups)
        groups.append(near)
        for j in near:
            mapping[j] = group
    verts = [sum((positions[i] for i in group), Vector()) / len(group) for group in groups]
    weld_error = max((positions[i] - verts[mapping[i]]).length for i in mapping)
    polys = []
    source_ids = []
    for i, tri in enumerate(triangles):
        mapped = tuple(mapping[v] for v in tri)
        if len(set(mapped)) == 3:
            polys.append(mapped)
            source_ids.append(i)
    by_vertex = defaultdict(set)
    selected = set()
    for i, tri in enumerate(polys):
        for v in tri:
            by_vertex[v].add(i)
        c = sum((verts[v] for v in tri), Vector()) / 3
        if abs(c.x) < .094 and c.y < -.209 and abs(c.z - seam_z(c.x)) < .008:
            selected.add(i)
    all_edges = Counter()
    for a, b, c in polys:
        for x, y in [(a, b), (b, c), (c, a)]:
            all_edges[tuple(sorted((x, y)))] += 1
    def boundary():
        edges = Counter()
        for i in selected:
            a, b, c = polys[i]
            for x, y in [(a, b), (b, c), (c, a)]:
                edges[tuple(sorted((x, y)))] += 1
        graph = defaultdict(set)
        for (a, b), n in edges.items():
            if n == 1 and all_edges[(a, b)] > 1:
                graph[a].add(b)
                graph[b].add(a)
        return graph
    for attempt in range(12):
        graph = boundary()
        bad = [v for v, neighbors in graph.items() if len(neighbors) != 2]
        if bad:
            for v in bad:
                selected.update(by_vertex[v])
            continue
        seen = set()
        loops = []
        for v in graph:
            if v in seen:
                continue
            stack = [v]
            component = []
            while stack:
                p = stack.pop()
                if p in seen:
                    continue
                seen.add(p)
                component.append(p)
                stack.extend(graph[p] - seen)
            loops.append(component)
        if len(loops) == 1:
            break
        largest = max(loops, key=len)
        for loop in loops:
            if loop is largest:
                continue
            for v in loop:
                selected.update(by_vertex[v])
    graph = boundary()
    if any(len(v) != 2 for v in graph.values()):
        raise RuntimeError('Mouth opening did not form a clean boundary')
    first = max(graph, key=lambda i: verts[i].x)
    next_vertex = max(graph[first], key=lambda i: verts[i].z - seam_z(verts[i].x))
    ordered = [first]
    previous, current = first, next_vertex
    while current != first:
        ordered.append(current)
        others = graph[current] - {previous}
        if len(others) != 1:
            raise RuntimeError('Non-manifold mouth border')
        previous, current = current, next(iter(others))
        if len(ordered) > len(graph):
            raise RuntimeError('Unclosed mouth border')
    if len(ordered) != len(graph):
        raise RuntimeError('Additional isolated mouth openings remain')
    left_index = min(range(len(ordered)), key=lambda i: verts[ordered[i]].x)
    angles = [0.0] * len(ordered)
    for start, end, offset in [(0, left_index, 0.0), (left_index, len(ordered), math.pi)]:
        ids = ordered[start:end + 1] if end < len(ordered) else ordered[start:] + [first]
        distance = [0.0]
        for a, b in zip(ids, ids[1:]):
            distance.append(distance[-1] + (verts[b] - verts[a]).length)
        for j in range(len(ids) - (1 if end == len(ordered) else 0)):
            angles[start + j] = offset + math.pi * distance[j] / distance[-1]
    kept = [i for i in range(len(polys)) if i not in selected]
    mesh = bpy.data.meshes.new('Lumo original surface with manifold oral opening')
    mesh.from_pydata(verts, [], [polys[i] for i in kept])
    mesh.update()
    mesh.materials.append(original.materials[0])
    cornea = original.materials[0].copy()
    cornea.name = 'Lumo eye and nose satin'
    principled = next(n for n in cornea.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for link in list(cornea.node_tree.links):
        if link.to_node == principled and link.to_socket.name in ['Roughness', 'Metallic']:
            cornea.node_tree.links.remove(link)
    principled.inputs['Roughness'].default_value = .24
    principled.inputs['Metallic'].default_value = 0.0
    mesh.materials.append(cornea)
    layer = mesh.uv_layers.new(name='Original LUMO atlas')
    for poly, source_i in zip(mesh.polygons, kept):
        c = sum((verts[v] for v in poly.vertices), Vector()) / 3
        eye = abs(abs(c.x) - .112) < .060 and 1.292 < c.z < 1.414 and c.y < -.270
        nose = abs(c.x) < .036 and 1.233 < c.z < 1.287 and c.y < -.409
        poly.use_smooth = True
        poly.material_index = 1 if eye or nose else 0
        for li, tex in zip(poly.loop_indices, uvs[source_ids[source_i]]):
            layer.data[li].uv = tex
    body.data = mesh
    body.vertex_groups.clear()
    for name in group_names:
        body.vertex_groups.new(name=name)
    for index, group in enumerate(groups):
        values = defaultdict(float)
        for old in group:
            for bone, weight in old_weights[old]:
                values[bone] += weight / len(group)
        influences = sorted(values.items(), key=lambda item: item[1], reverse=True)[:4]
        total = sum(w for bone, w in influences)
        for bone, weight in influences:
            body.vertex_groups[bone].add([index], weight / total, 'REPLACE')
    for key_name, coords in original_keys.items():
        key = body.shape_key_add(name=key_name)
        for index, group in enumerate(groups):
            key.data[index].co = sum((coords[i] for i in group), Vector()) / len(group)
        key.value = 0.0
    for key_name in VISEMES:
        key = body.shape_key_add(name=key_name)
        for vertex, pos in zip(key.data, verts):
            vertex.co = mouth_deform(pos, key_name)
    body['oral_topology'] = 'One measured boundary loop; annular lip topology and real recessed oral cavity'
    return ({'removed_mouth_triangles': len(selected), 'body_triangles': len(kept),
             'mouth_boundary_vertices': len(ordered), 'local_weld_max_error_m': weld_error,
             'local_weld_tolerance_m': .0008}, [verts[i] for i in ordered], angles)

def make_mouth(body, rig, sample, outer, angles):
    """Closed neutral seam becomes a real recessed cavity, not a black plane."""
    count = len(outer)
    outer_uv = [sample(point)[2] for point in outer]
    descriptors = []
    coords_by_key = {}
    patch_rows = [0.0, .26, .55, .78, .92, 1.0]
    for row, r in enumerate(patch_rows):
        for i in range(count):
            descriptors.append(('patch', r, i))
    cavity_rows = [(1.0, .006), (.87, .018), (.59, .039), (.18, .052)]
    for shrink, depth in cavity_rows:
        for i in range(count):
            descriptors.append(('cavity', shrink, depth, i))
    # Inner endpoint: smooth basin with no aperture at its rear.
    descriptors.append(('bottom',))
    # Friendly small upper enamel strip (not human-sized teeth).
    for row in range(3):
        for i in range(21):
            descriptors.append(('enamel', row, i))
    tongue_start = len(descriptors)
    for ring in range(9):
        for seg in range(24):
            descriptors.append(('tongue', ring, seg))
    def inner(name, index):
        width, opening, upper, forward, corners = VISEMES[name]
        t = angles[index]
        x = .093 * width * math.cos(t)
        s = math.sin(t)
        z = seam_z(.093 * math.cos(t))
        z += .0010 * s
        z += upper * max(s, 0) - opening * max(-s, 0)
        z += corners * abs(math.cos(t)) ** 1.5
        # Rounded phonemes narrow and soften the smile arc, preserving muzzle.
        if name in ['OH', 'OU']:
            z = 1.2215 + (upper - opening) * .5 + ((upper + opening) * .5 + .001) * s
        return Vector((x, seam_y(x) - forward - .0016, z))
    for name in VISEMES:
        width, opening, upper, forward, corners = VISEMES[name]
        center = Vector((0, -.302 - forward, 1.2215 + (upper - opening) * .5))
        points = []
        for desc in descriptors:
            if desc[0] == 'patch':
                _, r, i = desc
                exterior = mouth_deform(outer[i], name)
                p = exterior.lerp(inner(name, i), r)
                # A gentle lip roll catches a narrow key light without a shiny rim.
                p.y -= .0011 * math.sin(math.pi * r)
            elif desc[0] == 'cavity':
                _, shrink, depth, i = desc
                boundary = inner(name, i)
                p = center.lerp(boundary, shrink)
                p.y = boundary.y + depth
            elif desc[0] == 'bottom':
                p = center + Vector((0, .058, 0))
            elif desc[0] == 'enamel':
                _, row, i = desc
                a = (i / 20 - .5) * 2
                x = a * .052 * width
                z = 1.2215 + 4.2 * x * x + .0015 * upper
                z += .002 - .006 * (row / 2) * math.sqrt(max(0, 1 - a * a))
                y = seam_y(x) - forward + .009 + .004 * math.sin(math.pi * row / 2)
                if opening <= .001:
                    y += .018
                if name in ['OH', 'OU']:
                    y += .016
                p = Vector((x, y, z))
            else:
                _, ring, seg = desc
                phi = math.pi * ring / 8
                theta = TAU * seg / 24
                tongue_lift = .017 if name == 'L' else (.009 if name == 'TH' else 0)
                tongue_front = -.015 if name == 'TH' else (.001 if name == 'L' else .017)
                lower = 1.2215 - max(opening, 0) + .004
                if opening < .002:
                    lower -= .018
                    tongue_front += .085
                p = Vector((.033 * width * math.sin(phi) * math.cos(theta),
                            -.302 - forward + tongue_front + .016 * math.sin(phi) * math.sin(theta),
                            lower + tongue_lift + .006 * math.cos(phi)))
            points.append(p)
        coords_by_key[name] = points
    faces = []
    face_mats = []
    uvs = []
    def quad(a, b, c, d, mat):
        faces.append((a, b, c, d)); face_mats.append(mat)
    total_rows = len(patch_rows) + len(cavity_rows)
    for row in range(total_rows - 1):
        for i in range(count):
            nxt = (i + 1) % count
            # Front of the muzzle is -Y; recalc below makes cavity orientation consistent.
            quad(row * count + i, row * count + nxt,
                 (row + 1) * count + nxt, (row + 1) * count + i,
                 0 if row < len(patch_rows) - 2 else 1)
    bottom = total_rows * count
    for i in range(count):
        faces.append(((total_rows - 1) * count + i,
                      (total_rows - 1) * count + (i + 1) % count, bottom))
        face_mats.append(1)
    enamel_start = bottom + 1
    for row in range(2):
        for i in range(20):
            quad(enamel_start + row * 21 + i, enamel_start + row * 21 + i + 1,
                 enamel_start + (row + 1) * 21 + i + 1,
                 enamel_start + (row + 1) * 21 + i, 2)
    for row in range(8):
        for i in range(24):
            quad(tongue_start + row * 24 + i, tongue_start + row * 24 + (i + 1) % 24,
                 tongue_start + (row + 1) * 24 + (i + 1) % 24,
                 tongue_start + (row + 1) * 24 + i, 3)
    mesh = bpy.data.meshes.new('Lumo editable oral topology')
    mesh.from_pydata(coords_by_key['Neutral'], [], faces)
    mesh.update()
    mesh.materials.append(material('Lumo muzzle fur', (.92, .89, .82), .7))
    mesh.materials.append(material('Lumo mouth lining', (.075, .022, .026), .63))
    mesh.materials.append(material('Lumo warm enamel', (.84, .80, .68), .31))
    mesh.materials.append(material('Lumo tongue', (.43, .115, .13), .52))
    layer = mesh.uv_layers.new(name='Original atlas projected muzzle and oral unwrap')
    for poly, mat in zip(mesh.polygons, face_mats):
        poly.material_index = mat
        poly.use_smooth = True
        for li, vi in zip(poly.loop_indices, poly.vertices):
            desc = descriptors[vi]
            if desc[0] == 'patch':
                point, normal, uv = sample(coords_by_key['Neutral'][vi])
                layer.data[li].uv = uv
            else:
                point = coords_by_key['Neutral'][vi]
                layer.data[li].uv = (.5 + point.x / .25, .5 + (point.z - 1.22) / .15)
    obj = bpy.data.objects.new('LumoFace', mesh)
    bpy.context.scene.collection.objects.link(obj)
    bind_mesh(obj, rig)
    obj.shape_key_add(name='Basis')
    for name, coords in coords_by_key.items():
        key = obj.shape_key_add(name=name)
        for vert, p in zip(key.data, coords):
            vert.co = p
        key.value = 0.0
    obj['phoneme_pose_note'] = 'Named authored mouth shapes; sync only when actual playback timestamps and cues are provided.'
    obj['neutral_seam_opening_m'] = .002
    obj['closed_cavity_depth_m'] = .058
    return obj



def sew_lip_surface(body, mouth, boundary):
    """Share lip border vertices with the real body for continuous normals."""
    from mathutils.kdtree import KDTree
    count = len(boundary)
    patch_end = count * 6
    body_mesh = body.data
    face_mesh = mouth.data
    body_mesh.calc_loop_triangles()
    body_coords = [v.co.copy() for v in body_mesh.vertices]
    face_coords = [v.co.copy() for v in face_mesh.vertices]
    body_keys = {k.name: [v.co.copy() for v in k.data] for k in body_mesh.shape_keys.key_blocks}
    face_keys = {k.name: [v.co.copy() for v in k.data] for k in face_mesh.shape_keys.key_blocks}
    group_names = [g.name for g in body.vertex_groups]
    group_weights = [[(g.group, g.weight) for g in v.groups] for v in body_mesh.vertices]
    tree = KDTree(len(body_coords))
    for index, co in enumerate(body_coords):
        tree.insert(co, index)
    tree.balance()
    mapping = {}
    for i, point in enumerate(boundary):
        co, index, distance = tree.find(point)
        if distance > .000001:
            raise RuntimeError('Lip boundary no longer matches the body')
        mapping[i] = index
    for i in range(count, patch_end):
        mapping[i] = len(body_coords)
        body_coords.append(face_coords[i])
        group_weights.append([(group_names.index('Head'), 1.0)])
        for name in body_keys:
            body_keys[name].append(face_keys.get(name, face_keys['Basis'])[i])
    polygons = [tuple(p.vertices) for p in body_mesh.polygons]
    material_ids = [p.material_index for p in body_mesh.polygons]
    tex = [[body_mesh.uv_layers[0].data[i].uv.copy() for i in p.loop_indices] for p in body_mesh.polygons]
    remaining = []
    for p in face_mesh.polygons:
        if all(v < patch_end for v in p.vertices):
            polygons.append(tuple(mapping[v] for v in p.vertices))
            material_ids.append(2 if p.material_index == 0 else 3)
            tex.append([face_mesh.uv_layers[0].data[i].uv.copy() for i in p.loop_indices])
        else:
            remaining.append(p.index)
    mesh = bpy.data.meshes.new('Lumo continuous muzzle and original atlas surface')
    mesh.from_pydata(body_coords, [], polygons)
    mesh.update()
    for m in list(body_mesh.materials) + [face_mesh.materials[0], face_mesh.materials[1]]:
        mesh.materials.append(m)
    uv = mesh.uv_layers.new(name='Original atlas and sewn lip unwrap')
    for p, material_index, values in zip(mesh.polygons, material_ids, tex):
        if p.index < len(body_mesh.polygons):
            center = sum((body_coords[v] for v in p.vertices), Vector()) / len(p.vertices)
            old_painted_crease = abs(center.x) < .120 and center.y < -.205 and abs(center.z - seam_z(center.x)) < .020
            original_nose = center.y < -.39 and center.z > 1.230
            if old_painted_crease and not original_nose:
                material_index = 2
        p.material_index = material_index
        p.use_smooth = True
        for li, value in zip(p.loop_indices, values):
            uv.data[li].uv = value
    body.data = mesh
    body.vertex_groups.clear()
    for name in group_names:
        body.vertex_groups.new(name=name)
    for i, weights in enumerate(group_weights):
        for group, weight in weights:
            body.vertex_groups[group].add([i], weight, 'REPLACE')
    for name, coords in body_keys.items():
        key = body.shape_key_add(name=name)
        for v, co in zip(key.data, coords):
            v.co = co
    interior = bpy.data.meshes.new('Lumo recessed oral cavity tongue and enamel')
    interior.from_pydata(face_coords, [], [tuple(face_mesh.polygons[i].vertices) for i in remaining])
    interior.update()
    for m in face_mesh.materials:
        interior.materials.append(m)
    uv = interior.uv_layers.new(name='Oral surface unwrap')
    for p, source_i in zip(interior.polygons, remaining):
        source = face_mesh.polygons[source_i]
        p.material_index = source.material_index
        p.use_smooth = True
        for li, old_li in zip(p.loop_indices, source.loop_indices):
            uv.data[li].uv = face_mesh.uv_layers[0].data[old_li].uv
    mouth.data = interior
    mouth.vertex_groups.clear()
    mouth.vertex_groups.new(name='Head').add(list(range(len(face_coords))), 1.0, 'REPLACE')
    for name, coords in face_keys.items():
        key = mouth.shape_key_add(name=name)
        for v, co in zip(key.data, coords):
            v.co = co
    body['lip_seam_shared_vertices'] = count

def author_ears(rig, body):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side, sign in [('L', 1), ('R', -1)]:
        ear = rig.data.edit_bones.new('Ear.' + side)
        ear.head = (sign * .183, -.042, 1.475)
        ear.tail = (sign * .267, -.016, 1.683)
        ear.parent = rig.data.edit_bones['Head']
        ear.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    ear_weights = {}
    for side, sign in [('L', 1), ('R', -1)]:
        group = body.vertex_groups.new(name='Ear.' + side)
        count = 0
        for vertex in body.data.vertices:
            p = vertex.co
            if p.x * sign <= 0:
                continue
            amount = ramp(1.470, 1.548, p.z) * ramp(.125, .185, abs(p.x)) * ramp(-.192, -.115, p.y)
            if amount < .001:
                continue
            old = [(g.group, g.weight * (1 - amount)) for g in vertex.groups]
            groups = sorted(old + [(group.index, amount)], key=lambda item: item[1], reverse=True)[:4]
            total = sum(w for i, w in groups)
            for item in list(vertex.groups):
                body.vertex_groups[item.group].remove([vertex.index])
            for index, weight in groups:
                body.vertex_groups[index].add([vertex.index], weight / total, 'REPLACE')
            count += 1
        ear_weights[side] = count
    return ear_weights


def add_blinks(lids):
    # Endpoint aliases aid editors. The runtime uses the four original curved
    # closure stages; a linear endpoint interpolation is explicitly not preferred.
    if not lids or not lids.data.shape_keys:
        return
    for side in ['Left', 'Right']:
        close = lids.data.shape_keys.key_blocks['Blink' + side + 'Close']
        key = lids.shape_key_add(name='Blink' + side)
        for target, source in zip(key.data, close.data):
            target.co = source.co
        key.value = 0.0


def rotate_world(rig, name, axis, angle):
    if name not in rig.pose.bones or abs(angle) < 1e-8:
        return
    bone = rig.pose.bones[name]
    m = bone.matrix.copy()
    q = Quaternion(AXES[axis], angle)
    bone.matrix = Matrix.LocRotScale(m.translation, q @ m.to_quaternion(), m.to_scale())
    bpy.context.view_layer.update()


def solve_arm(rig, side, target):
    # Wrist participates in the original rest chain; both lengths remain rigid.
    upper = rig.pose.bones['UpperArm.' + side]
    fore = rig.pose.bones['Forearm.' + side]
    wrist = rig.pose.bones['Wrist.' + side]
    v1 = fore.head - upper.head
    v2 = wrist.head - fore.head
    toward = target - upper.head
    if toward.length < 1e-7:
        return
    direction = toward.normalized()
    a, b = v1.length, v2.length
    distance = clamp(toward.length, abs(a - b) + .0001, a + b - .0001)
    along = (a * a - b * b + distance * distance) / (2 * distance)
    height = math.sqrt(max(0, a * a - along * along))
    pole = Vector((side == 'L' and 1 or -1, -.4, .12))
    pole -= direction * pole.dot(direction)
    pole.normalize()
    elbow = upper.head + direction * along + pole * height
    m = upper.matrix.copy()
    q = v1.normalized().rotation_difference((elbow - upper.head).normalized())
    upper.matrix = Matrix.LocRotScale(m.translation, q @ m.to_quaternion(), m.to_scale())
    bpy.context.view_layer.update()
    m = fore.matrix.copy()
    target = upper.head + direction * distance
    q = (wrist.head - fore.head).normalized().rotation_difference((target - fore.head).normalized())
    fore.matrix = Matrix.LocRotScale(m.translation, q @ m.to_quaternion(), m.to_scale())
    bpy.context.view_layer.update()


def author_actions(rig, original_actions):
    scene = bpy.context.scene
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    idle = next(action for action in original_actions if action.name == 'idle')
    rig.animation_data.action = idle
    scene.frame_set(1)
    bpy.context.view_layer.update()
    base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy())
            for b in rig.pose.bones}
    hands = {s: rig.pose.bones['Wrist.' + s].head.copy() for s in ['L', 'R']}
    for action in original_actions:
        action.use_fake_user = True
    authored = {}
    for name, (duration, loop) in CLIPS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        action['loop'] = loop
        action['authored_in_blender'] = True
        rig.animation_data.action = action
        frames = list(range(1, round(duration * FPS) + 2, 3))
        if frames[-1] != round(duration * FPS) + 1:
            frames.append(round(duration * FPS) + 1)
        for frame in frames:
            scene.frame_set(frame)
            t = (frame - 1) / FPS
            u = t / duration
            phase = TAU * u
            for bone in rig.pose.bones:
                loc, q, scale = base[bone.name]
                bone.rotation_mode = 'QUATERNION'
                bone.location = loc
                bone.rotation_quaternion = q
                bone.scale = scale
            bpy.context.view_layer.update()
            e = smooth(t / .4) * (1 - smooth((t - (duration - .5)) / .5))
            if loop:
                e = math.sin(math.pi * u) ** 2
            quiet = .3 if name == 'focused_input' else 1.0
            rotate_world(rig, 'Chest', 'x', math.sin(phase * 2) * .012 * quiet)
            rotate_world(rig, 'Neck', 'z', math.sin(phase) * .012 * quiet)
            for i, tail in enumerate(['TailBase', 'Tail1', 'Tail2', 'Tail3', 'TailTip']):
                wave = (math.sin(phase - i * .35) - math.sin(-i * .35)) * .025 * quiet
                rotate_world(rig, tail, 'z', wave)
            for side, offset in [('L', .0), ('R', 1.0)]:
                rotate_world(rig, 'Ear.' + side, 'y', (.025 * math.sin(phase * 2 + offset) - .025 * math.sin(offset)) * quiet)
            if name == 'idle_breathe':
                rotate_world(rig, 'Head', 'z', .035 * math.sin(phase) + .012 * math.sin(phase * 3))
            elif name == 'listening':
                rotate_world(rig, 'Head', 'y', -.055 * e)
                rotate_world(rig, 'Neck', 'x', .028 * e)
                rotate_world(rig, 'Ear.L', 'x', -.07 * e)
                rotate_world(rig, 'Ear.R', 'x', -.06 * e)
            elif name == 'thinking':
                rotate_world(rig, 'Head', 'z', -.085 * e)
                rotate_world(rig, 'Head', 'x', -.055 * e)
                target = Vector((-.11, -.31, 1.12))
                solve_arm(rig, 'R', hands['R'].lerp(target, e))
            elif name == 'answer':
                rotate_world(rig, 'Head', 'x', .05 * math.sin(math.pi * u))
                solve_arm(rig, 'L', hands['L'].lerp(Vector((.28, -.28, .98)), e))
            elif name in ['explain', 'encourage']:
                rotate_world(rig, 'Head', 'y', .035 * math.sin(phase) * e)
                target = Vector((.32, -.25, 1.00 + .035 * math.sin(phase * 2)))
                solve_arm(rig, 'L', hands['L'].lerp(target, e))
                if name == 'encourage':
                    rotate_world(rig, 'Head', 'x', .075 * math.sin(phase * 1.5) * e)
                    solve_arm(rig, 'R', hands['R'].lerp(Vector((-.30, -.22, .97)), e * .45))
            elif name == 'point':
                target = Vector((.43, -.18, 1.13))
                solve_arm(rig, 'L', hands['L'].lerp(target, e))
                rotate_world(rig, 'Head', 'z', .11 * e)
            elif name == 'nod':
                rotate_world(rig, 'Head', 'x', .11 * math.sin(phase * 1.5) * e)
                rotate_world(rig, 'Neck', 'x', .035 * math.sin(phase * 1.5) * e)
            elif name == 'unsure':
                rotate_world(rig, 'Head', 'y', -.13 * e)
                rotate_world(rig, 'Ear.R', 'x', .10 * e)
                for s, sign in [('L', 1), ('R', -1)]:
                    solve_arm(rig, s, hands[s].lerp(Vector((sign * .32, -.21, 1.0)), e * .62))
            elif name == 'celebrate_step':
                # Feet stay fixed: delight comes from hands, ears and head.
                rotate_world(rig, 'Head', 'x', -.055 * e)
                for s, sign in [('L', 1), ('R', -1)]:
                    solve_arm(rig, s, hands[s].lerp(Vector((sign * .30, -.13, 1.24)), e))
                    rotate_world(rig, 'Hand.' + s, 'z', sign * .12 * math.sin(phase * 3) * e)
            elif name in ['greeting', 'farewell']:
                solve_arm(rig, 'R', hands['R'].lerp(Vector((-.32, -.16, 1.30)), e))
                rotate_world(rig, 'Hand.R', 'y', .25 * math.sin(phase * 2.5) * e)
                rotate_world(rig, 'Head', 'y', -.06 * e)
            elif name == 'interrupt':
                # A short acknowledgement. Runtime cancellation owns actual stop.
                rotate_world(rig, 'Head', 'x', .045 * math.sin(math.pi * u))
                rotate_world(rig, 'Ear.L', 'x', -.08 * math.sin(math.pi * u))
                rotate_world(rig, 'Ear.R', 'x', -.08 * math.sin(math.pi * u))
            for bone in rig.pose.bones:
                for attr in ['location', 'rotation_quaternion', 'scale']:
                    bone.keyframe_insert(attr, frame=frame, group=bone.name)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = 'BEZIER'
                key.handle_left_type = 'AUTO_CLAMPED'
                key.handle_right_type = 'AUTO_CLAMPED'
        authored[name] = action
    rig.animation_data.action = authored['idle_breathe']
    scene.frame_set(1)
    return authored


def set_face(name, amount=1.0):
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or not obj.data.shape_keys:
            continue
        for key in obj.data.shape_keys.key_blocks:
            key.value = amount if key.name == name else 0.0


def studio_scene():
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 40
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 960
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('Lumo warm learning studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.13, .19, .22, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .40
    floor_mat = material('Studio blue slate', (.028, .062, .078), .78)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.002))
    floor = bpy.context.object
    floor.name = 'Review stage (excluded from GLB)'
    floor.data.materials.append(floor_mat)
    for name, loc, power, size, color in [
        ('Soft warm key', (-3, -4, 4), 500, 3.0, (1, .88, .75)),
        ('Sky fill', (3, -2, 2.8), 280, 3.2, (.70, .86, 1)),
        ('Cyan rim', (1.2, 2.5, 3.4), 560, 2.4, (.60, .95, 1)),
    ]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = power
        data.shape = 'DISK'
        data.size = size
        data.color = color
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = loc
        light.rotation_euler = (Vector((0, -.03, 1.0)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    data = bpy.data.cameras.new('Learning review camera')
    camera = bpy.data.objects.new('Learning review camera', data)
    scene.collection.objects.link(camera)
    data.type = 'ORTHO'
    data.ortho_scale = 2.02
    scene.camera = camera
    scene.view_settings.view_transform = 'AgX'
    return scene


def camera_view(scene, position, target, ortho, size=(960, 1080)):
    scene.camera.location = position
    scene.camera.rotation_euler = (Vector(target) - scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera.data.ortho_scale = ortho
    scene.render.resolution_x, scene.render.resolution_y = size


def write_attribution():
    text = '''# LUMO Learning — source and modification notice\n\nThis derivative uses the actual existing LUMO fox, originally generated with\nMeshy from the user-authorized reference 50137.jpeg on 10 October 2026.\nThe original source repository records the license as Creative Commons\nAttribution 4.0 International: https://creativecommons.org/licenses/by/4.0/ .\nOriginal provider: https://www.meshy.ai/ . No endorsement is implied.\nThe upstream notices in assets/characters/lumo_animated/ATTRIBUTION.md and\nassets/characters/lumo_facial/ATTRIBUTION.md remain applicable.\n\nThe current work uses no newly purchased service, downloaded material,\nexternal character or external motion-library clip. Existing atlas images\nare preserved and embedded; all new topology, weighting, mouth shapes and\nteaching poses are locally authored through Blender Python with AI-assisted\ncode/pose design. This is not motion capture or a provider-generated video.\n\nChanges: actual oral aperture and recessed lining, warm enamel and tongue;\nAA, EE, OH, OU, MBP, FV, L, TH plus Neutral, Smile and Concern shape keys;\ntwo smoothly weighted ear bones; controlled satin eye/nose roughness; 14\nlearning actions while retaining the original 65 bones and nine actions.\nThe source .blend includes the whole character, textures and review stage.\n\nNamed mouth shapes alone do not prove phoneme synchronization. Playback\ntimestamps and cues must be connected and measured in the app. Painted eye\nsurfaces retain the existing bounded gaze morphs; no independent rotating\neyeball anatomy is claimed. The original four-stage eyelid closure is kept.\n\nAlways distribute this notice and the upstream attribution with derivatives.\n'''
    (RUNTIME / 'ATTRIBUTION.md').write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--preview-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    ART.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    (ART / '.gdignore').write_text('')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = bpy.data.objects['Mesh_0']
    base_material = body.data.materials[0]
    base_principled = next(n for n in base_material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for link in list(base_material.node_tree.links):
        if link.to_node == base_principled and link.to_socket.name in ['Metallic', 'Roughness']:
            base_material.node_tree.links.remove(link)
    base_principled.inputs['Roughness'].default_value = .60
    base_principled.inputs['Metallic'].default_value = .10
    lids = bpy.data.objects.get('LumoEyelids')
    original_actions = list(bpy.data.actions)
    for action in original_actions:
        action.name = action.name.removesuffix('_' + rig.name)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    for key in body.data.shape_keys.key_blocks:
        key.value = 0
    positions, triangles, uv, sample = face_source(body)
    topology, outer, angles = rebuild_body(body, positions, triangles, uv, sample)
    mouth = make_mouth(body, rig, sample, outer, angles)
    sew_lip_surface(body, mouth, outer)
    ears = author_ears(rig, body)
    add_blinks(lids)
    authored = author_actions(rig, original_actions) if not args.preview_only else {}
    if args.preview_only:
        rig.animation_data.action = next(a for a in original_actions if a.name == 'idle')
        bpy.context.scene.frame_set(1)
    for im in bpy.data.images:
        if im.name.startswith('Image'):
            mapping = {'Image_0': 'lumo_albedo.png', 'Image_1': 'lumo_orm.png', 'Image_2': 'lumo_normal.png'}
            im.filepath_raw = str(RUNTIME / mapping.get(im.name, im.name + '.png'))
            im.file_format = 'PNG'
            im.save()
            im.pack()
    set_face('Neutral')
    mesh_counts = {}
    for obj in [body, mouth, lids]:
        if obj:
            obj.data.calc_loop_triangles()
            mesh_counts[obj.name] = {'vertices': len(obj.data.vertices), 'triangles': len(obj.data.loop_triangles), 'material_slots': len(obj.data.materials), 'uv_layers': len(obj.data.uv_layers)}
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj.find_armature() == rig:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    glb = RUNTIME / 'Lumo-Learning.glb'
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_step=2,
        export_optimize_animation_size=True, export_anim_single_armature=True,
        export_morph=True, export_skins=True, export_extras=True,
    )
    scene = studio_scene()
    camera_view(scene, (2.3, -4.8, 2.15), (0, -.02, .90), 2.02)
    blend = ART / 'Lumo-Learning.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    write_attribution()
    manifest = {
        'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': digest(SOURCE),
        'blender_version': bpy.app.version_string,
        'production': 'Local Blender Python; AI-assisted authored topology and poses, no new paid provider',
        'meters_per_unit': 1.0, 'blender_up': '+Z', 'blender_front': '-Y',
        'gltf_up': '+Y', 'gltf_front': '+Z',
        'origin': 'Inherited original ground-centered coordinate system; sole minimum approximately 0 m',
        'bones': [b.name for b in rig.data.bones], 'bone_count': len(rig.data.bones),
        'added_ear_vertices': ears, **topology, 'meshes': mesh_counts,
        'total_triangles': sum(m['triangles'] for m in mesh_counts.values()),
        'viseme_blending': 'Convex sum <= 1; Smile + Concern <= 0.35 during speech',
        'neutral_lid_visibility': 'Hide LumoEyelids below blink 0.002; use existing four-stage curved closure',
        'original_actions': [a.name for a in original_actions],
        'new_actions': {k: {'seconds': v[0], 'loop': v[1]} for k, v in CLIPS.items()},
        'morphs': {o.name: list(o.data.shape_keys.key_blocks.keys()) for o in [body, mouth, lids] if o and o.data.shape_keys},
        'textures': {f.name: {'bytes': f.stat().st_size, 'sha256': digest(f)} for f in RUNTIME.glob('*.png')},
        'runtime_glb': str(glb.relative_to(ROOT)), 'runtime_bytes': glb.stat().st_size,
        'runtime_sha256': digest(glb), 'blend_sha256': digest(blend),
        'limitations': ['Physical Fold7 performance not measured here',
                        'Mouth pose library is not proof of phoneme timing',
                        'Original eye anatomy remains a painted surface with gaze morphs'],
    }
    (ART / 'production_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if args.render:
        views = [('three_quarter', (2.3, -4.8, 2.15), (0, -.02, .90), 2.02),
                 ('front', (0, -4.8, 1.0), (0, 0, .87), 2.02),
                 ('side', (4.8, 0, 1.05), (0, 0, .88), 2.02),
                 ('back', (0, 4.8, 1.10), (0, 0, .88), 2.02)]
        for label, position, target, ortho in views:
            set_face('Neutral')
            camera_view(scene, position, target, ortho)
            scene.render.filepath = str(ART / ('blender_' + label + '.png'))
            bpy.ops.render.render(write_still=True)
        for name in ['Neutral', 'AA', 'EE', 'OH', 'OU', 'MBP', 'FV', 'L', 'TH', 'Smile', 'Concern']:
            set_face(name)
            camera_view(scene, (1.2, -4.8, 1.38), (0, -.12, 1.34), .86, (900, 900))
            scene.render.filepath = str(ART / ('blender_face_' + name + '.png'))
            bpy.ops.render.render(write_still=True)
        set_face('Neutral')
    print('LUMO_LEARNING_PRODUCTION', json.dumps({'bones': len(rig.data.bones), 'bytes': glb.stat().st_size, **topology}))


if __name__ == '__main__':
    main()
