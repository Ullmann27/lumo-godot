"""Standing, walking LUMO animal figures from the retained Meshy A-pose originals.

Run (Blender Python, no GUI):
  /home/user/tools/bpyenv/bin/python tools/lumo_animation/animals/build_standing_animals.py -- --species lion
  ... -- (all nine)

Why: the kart drivers (assets/kart/production/drivers) are fitted into the
seated kart pose (head x2, limbs thickened, legs bent forward). Using them as
standing or walking figures deforms them and they cannot walk. This builder
keeps the original standing A-pose geometry and UVs as the rest pose, reuses
the reviewed anatomy landmarks and skin classifier of the driver rig, and
extends the skeleton for locomotion:

* 30 bones: the 26 driver bones (same names) + TailMid, TailTip, Toe.L, Toe.R,
* weights computed in the original A-pose (rig_meshy_drivers.skin_weights),
  tail split along a three-bone chain, feet split at the ball,
* 20 clips from animal_motion.py (walk/run with foot contact, idle, turns,
  stop, sit, stand, wave, listen, talk, think, joy, surprise, disappointed,
  interact, enter/exit vehicle, drive),
* one GLB per figure (body decimated, face kept), JPEG albedo <= 1024 px,
  Godot generates distance LODs on import.

Outputs assets/characters/animals/<id>/figure.glb and a shared manifest
assets/characters/animals/figures.json (clip lengths, loop flags, stride,
speed, seat height, vehicle entry offset).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools/lumo_kart_art/drivers'))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import rig_meshy_drivers as RM  # noqa: E402
import build_animal_drivers as animal  # noqa: E402
import animal_motion as AM  # noqa: E402

ANATOMY = ROOT / 'tools/lumo_kart_art/drivers/meshy_anatomy.json'
OUT = ROOT / 'assets/characters/animals'
FIGURE_HEIGHT = 1.6
FPS = 30
DRIVER_NAMES = RM.NAMES
EXTRA = ['TailMid', 'TailTip', 'Toe.L', 'Toe.R']
NAMES = DRIVER_NAMES + EXTRA
PARENTS = {'TailMid': 'Tail', 'TailTip': 'TailMid', 'Toe.L': 'Foot.L', 'Toe.R': 'Foot.R'}
BODY_RATIO = .6
NAMES_DE = {'lion': 'Löwe', 'owl': 'Eule', 'rabbit': 'Nova (Hase)', 'squirrel': 'Eichhörnchen',
            'turtle': 'Schildkröte', 'frog': 'Frosch', 'otter': 'Milo (Otter)', 'badger': 'Bruno (Dachs)',
            'cat': 'Mika (Katze)'}


def polyline_points(path, count):
    path = [np.asarray(p, dtype=float) for p in path]
    lengths = [np.linalg.norm(b - a) for a, b in zip(path, path[1:])]
    total = sum(lengths)
    out = []
    for k in range(count):
        target = total * k / (count - 1)
        run = 0.0
        for (a, b), length in zip(zip(path, path[1:]), lengths):
            if run + length >= target - 1e-9 or b is path[-1]:
                f = 0.0 if length < 1e-9 else (target - run) / length
                out.append(a + (b - a) * min(1.0, max(0.0, f)))
                break
            run += length
    return out


def extend_skeleton(source, config, points, weights):
    specs = {name: (np.asarray(a, dtype=float), np.asarray(b, dtype=float), parent)
             for name, (a, b, parent) in source.items()}
    tail = config['tail']
    if 'path' in tail and len(tail['path']) >= 2:
        path = [RM.authored(p, config['center']) for p in tail['path']]
    else:
        path = [specs['Tail'][0], specs['Tail'][1]]
    chain = polyline_points(path, 4)
    specs['Tail'] = (chain[0], chain[1], 'Pelvis')
    specs['TailMid'] = (chain[1], chain[2], 'Tail')
    specs['TailTip'] = (chain[2], chain[3], 'TailMid')
    heel = {}
    for side in 'LR':
        foot = weights[:, DRIVER_NAMES.index('Foot.' + side)]
        ankle = specs['Foot.' + side][0]
        mask = (foot > .5) & (points[:, 2] < ankle[2])
        front = float(points[mask, 1].max()) if np.any(mask) else ankle[1] + .06
        back = float(points[mask, 1].min()) if np.any(mask) else ankle[1] - .02
        ball = np.array((ankle[0], ankle[1] + .6 * (front - ankle[1]), ankle[2] * .45 + points[:, 2].min() * .55))
        tip = np.array((ankle[0], front, ball[2] - .006))
        specs['Foot.' + side] = (ankle, ball, 'Shin.' + side)
        specs['Toe.' + side] = (ball, tip, 'Foot.' + side)
        heel[side] = back
    return specs, heel


def extend_weights(points, specs, weights, config):
    count = len(points)
    full = np.zeros((count, len(NAMES)))
    full[:, :len(DRIVER_NAMES)] = weights
    tail_w = full[:, NAMES.index('Tail')].copy()
    sel = tail_w > 0
    if np.any(sel):
        local, _distance = RM.chain_weights(points[sel], specs, ['Tail', 'TailMid', 'TailTip'], .02)
        for k, name in enumerate(['Tail', 'TailMid', 'TailTip']):
            full[sel, NAMES.index(name)] = tail_w[sel] * local[:, k]
    for side in 'LR':
        fi, ti = NAMES.index('Foot.' + side), NAMES.index('Toe.' + side)
        ball = specs['Toe.' + side][0]
        amount = RM.smooth((points[:, 1] - ball[1] + .008) / .016) * RM.smooth((ball[2] + .02 - points[:, 2]) / .02)
        moved = full[:, fi] * amount
        full[:, fi] -= moved
        full[:, ti] += moved
    order = np.argsort(-full, axis=1)
    for row in range(count):
        full[row, order[row, 4:]] = 0
    full[full < 1e-5] = 0
    return full / full.sum(axis=1)[:, None]


def limit_four(weights):
    order = np.argsort(-weights, axis=1)
    rows = np.arange(len(weights))[:, None]
    weights[rows, order[:, 4:]] = 0
    weights[weights < 1e-5] = 0
    return weights / weights.sum(axis=1)[:, None]


def stretch_test_poses(sk):
    _walk, walk_at, _ = AM.locomotion(sk, 'walk')
    _run, run_at, _ = AM.locomotion(sk, 'run')
    return {'joy_arms_up': AM.joy_pose(sk, .3), 'wave': AM.wave_pose(sk, .5), 'sit': AM.sit_idle_pose(sk, 0.0),
            'run_a': run_at(.2), 'run_b': run_at(.7), 'walk': walk_at(.1), 'think': AM.think_pose(sk, .5),
            'surprise': AM.surprise_pose(sk, .4), 'interact': AM.interact_pose(sk, .4),
            'enter': AM.vehicle_pose(sk, .5), 'drive': AM.drive_pose(sk, 0.0)}


def skinned(sk, placed, weights, pose):
    matrices = AM.solve(sk, pose)
    skin = np.stack([np.array(matrices[n] @ sk.rest[n].inverted()) for n in NAMES])
    homogeneous = np.c_[placed, np.ones(len(placed))]
    moved = np.einsum('bij,nj->nbi', skin, homogeneous)[:, :, :3]
    return np.einsum('nb,nbi->ni', weights, moved)


def edge_stretch(sk, placed, weights, edges, poses):
    rest = np.linalg.norm(placed[edges[:, 0]] - placed[edges[:, 1]], axis=1)
    worst = np.ones(len(edges))
    for pose in poses.values():
        deformed = skinned(sk, placed, weights, pose)
        now = np.linalg.norm(deformed[edges[:, 0]] - deformed[edges[:, 1]], axis=1)
        worst = np.maximum(worst, now / np.maximum(rest, 1e-5))
        # tiny edges may double without being visible; judge absolute growth too
        worst = np.where(now - rest < .008, np.minimum(worst, 1.0 + (now - rest) / .008), worst)
    return worst


def repair_stretch(sk, placed, weights, edges, poses, limit=2.2):
    """Harmonic weight repair where a test pose tears a triangle edge apart."""
    count = len(placed)
    before = float(edge_stretch(sk, placed, weights, edges, poses).max())
    repaired = 0
    for _round in range(4):
        worst = edge_stretch(sk, placed, weights, edges, poses)
        bad = worst > limit
        if not np.any(bad):
            break
        region = np.zeros(count, dtype=bool)
        region[edges[bad].ravel()] = True
        for _ring in range(2):
            grow = region.copy()
            grow[edges[region[edges[:, 0]], 1]] = True
            grow[edges[region[edges[:, 1]], 0]] = True
            region = grow
        repaired += int(region.sum())
        neighbours = np.zeros(count)
        np.add.at(neighbours, edges[:, 0], 1)
        np.add.at(neighbours, edges[:, 1], 1)
        for _step in range(24):
            total = np.zeros_like(weights)
            np.add.at(total, edges[:, 0], weights[edges[:, 1]])
            np.add.at(total, edges[:, 1], weights[edges[:, 0]])
            weights[region] = total[region] / np.maximum(neighbours[region], 1)[:, None]
        weights = limit_four(weights)
    final = edge_stretch(sk, placed, weights, edges, poses)
    after = float(final.max())
    for index in np.argsort(-final)[:4]:
        a, b = edges[index]
        top = [NAMES[i] for i in np.argsort(-weights[a])[:2]] + [NAMES[i] for i in np.argsort(-weights[b])[:2]]
        print('  worst edge', round(float(final[index]), 2), np.round(placed[a], 3), top, flush=True)
    return weights, {'max_edge_stretch_before': round(before, 3), 'max_edge_stretch_after': round(after, 3),
                     'repaired_vertices': repaired, 'test_poses': sorted(poses)}


def make_rig(specs):
    data = bpy.data.armatures.new('FigureSkeleton')
    rig = bpy.data.objects.new('FigureRig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name in NAMES:
        head, tail, parent = specs[name]
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = Vector(head), Vector(tail)
        bone.roll = 0.0
        bone.use_deform = True
    for name in NAMES:
        parent = specs[name][2]
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.select_set(False)
    rig['coordinate_contract'] = 'Metres; +Y forward and Z up in Blender; -Z forward and Y up in Godot; feet on y = 0.'
    return rig


def clip_table(sk):
    walk, walk_at, _ = AM.locomotion(sk, 'walk')
    run, run_at, _ = AM.locomotion(sk, 'run')
    sit_start = AM.sit_idle_pose(sk, 0.0)
    stand_start = AM.idle_pose(sk, 0.0)
    drive_start = AM.drive_pose(sk, 0.0)
    clips = {
        # name: (seconds, loop, keys per second, pose(t))
        'idle': (4.0, True, 15, lambda t: AM.idle_pose(sk, t)),
        'walk': (walk.duration, True, 30, walk_at),
        'run': (run.duration, True, 30, run_at),
        'turn_left': (1.0, True, 30, lambda t: AM.turn_pose(sk, t, 1.0)),
        'turn_right': (1.0, True, 30, lambda t: AM.turn_pose(sk, t, -1.0)),
        'stop': (.8, False, 30, lambda t: AM.stop_pose(sk, t, walk_at)),
        'sit_down': (1.2, False, 30, lambda t: AM.transition(sk, t, stand_start, sit_start)),
        'sit_idle': (4.0, True, 15, lambda t: AM.sit_idle_pose(sk, t)),
        'stand_up': (1.2, False, 30, lambda t: AM.transition(sk, t, sit_start, stand_start, -.4)),
        'wave': (2.0, False, 30, lambda t: AM.wave_pose(sk, t)),
        'listen': (4.0, True, 15, lambda t: AM.listen_pose(sk, t)),
        'talk': (3.0, True, 30, lambda t: AM.talk_pose(sk, t)),
        'think': (4.0, True, 15, lambda t: AM.think_pose(sk, t)),
        'joy': (1.6, False, 30, lambda t: AM.joy_pose(sk, t)),
        'surprise': (1.6, False, 30, lambda t: AM.surprise_pose(sk, t)),
        'disappointed': (2.4, False, 15, lambda t: AM.disappointed_pose(sk, t)),
        'interact': (1.8, False, 30, lambda t: AM.interact_pose(sk, t)),
        'enter_vehicle': (1.6, False, 30, lambda t: AM.vehicle_pose(sk, t, True)),
        'drive': (2.0, True, 15, lambda t: AM.drive_pose(sk, t)),
        'exit_vehicle': (1.4, False, 30, lambda t: AM.vehicle_pose(sk, t, False)),
    }
    meta = {'walk': {'stride_m': walk.stride, 'speed_mps': walk.speed},
            'run': {'stride_m': run.stride, 'speed_mps': run.speed}}
    extra = {'seat_height_m': sit_start['_seat'], 'drive_seat_height_m': drive_start['_seat'],
             'vehicle_entry_offset_m': [-.55 * sk.leg, 0.0, 0.0]}
    return clips, meta, extra


def animate(rig, sk):
    scene = bpy.context.scene
    scene.render.fps = FPS
    rig.animation_data_create()
    clips, meta, extra = clip_table(sk)
    report = {}
    for name, (seconds, loop, rate, pose_at) in clips.items():
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        frames = max(2, round(seconds * FPS))
        step = max(1, FPS // rate)
        keys = list(range(0, frames + 1, step))
        if keys[-1] != frames:
            keys.append(frames)
        for frame in keys:
            t = frame / frames
            matrices = AM.solve(sk, pose_at(0.0 if (loop and frame == frames) else t))
            local = AM.basis(sk, matrices)
            for bone in NAMES:
                pb = rig.pose.bones[bone]
                pb.rotation_mode = 'QUATERNION'
                pb.matrix_basis = local[bone]
                pb.keyframe_insert('location', frame=frame, group=bone)
                pb.keyframe_insert('rotation_quaternion', frame=frame, group=bone)
                pb.keyframe_insert('scale', frame=frame, group=bone)
        for fc in animal.action_fcurves(action):
            for key in fc.keyframe_points:
                key.interpolation = 'LINEAR'
        action.use_fake_user = True
        entry = {'seconds': frames / FPS, 'loop': loop, 'keys': len(keys)}
        entry.update(meta.get(name, {}))
        report[name] = entry
    rig.animation_data.action = bpy.data.actions['idle']
    scene.frame_set(1)
    return report, extra


def decimate_body(obj, ratio):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.vertex_groups.active_index = obj.vertex_groups['LODBody'].index
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.vertex_group_select()
    bpy.ops.mesh.decimate(ratio=ratio)
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode='OBJECT')
    animal.limit_influences(obj)


def export(obj, rig, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                              export_skins=True, export_all_influences=False, export_apply=False, export_extras=False,
                              export_def_bones=False, export_materials='EXPORT', export_cameras=False,
                              export_lights=False, export_image_format='JPEG', export_jpeg_quality=88,
                              export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True)


def repack_textures(path, quality=88):
    """Re-encode embedded JPEGs as plain baseline JFIF (no ICC/comment blocks).

    Godot's JPEG decoder rejects Blender's JPEG variant ("Couldn't load image
    ... image/jpeg"); the pixels stay identical apart from JPEG re-quantisation.
    """
    import io
    import struct
    from PIL import Image
    raw = path.read_bytes()
    offset = 12
    document, binary = None, b''
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        chunk = raw[offset + 8:offset + 8 + size]
        offset += 8 + size
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        else:
            binary = chunk
    replace = {}
    for image in document.get('images', []):
        if image.get('mimeType') != 'image/jpeg':
            continue
        view = document['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        picture = Image.open(io.BytesIO(binary[start:start + view['byteLength']])).convert('RGB')
        out = io.BytesIO()
        picture.save(out, 'JPEG', quality=quality, optimize=True, progressive=False, subsampling=0)
        replace[image['bufferView']] = out.getvalue()
    if not replace:
        return
    rebuilt = bytearray()
    for index, view in enumerate(document['bufferViews']):
        start = view.get('byteOffset', 0)
        data = replace.get(index, binary[start:start + view['byteLength']])
        while len(rebuilt) % 4:
            rebuilt.append(0)
        view['byteOffset'] = len(rebuilt)
        view['byteLength'] = len(data)
        rebuilt.extend(data)
    while len(rebuilt) % 4:
        rebuilt.append(0)
    document['buffers'][0]['byteLength'] = len(rebuilt)
    text = json.dumps(document, separators=(',', ':')).encode()
    text += b' ' * ((4 - len(text) % 4) % 4)
    total = 12 + 8 + len(text) + 8 + len(rebuilt)
    path.write_bytes(struct.pack('<4sII', b'glTF', 2, total) + struct.pack('<II', len(text), 0x4E4F534A) + text
                     + struct.pack('<II', len(rebuilt), 0x004E4942) + bytes(rebuilt))


def build(species, config):
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source_file = ROOT / config['source_file']
    digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
    assert digest == config['source_sha256'], (species, 'Meshy original changed')
    bpy.ops.import_scene.gltf(filepath=str(source_file))
    meshes = [o for o in bpy.context.selected_objects if o.type == 'MESH']
    assert len(meshes) == 1, (species, 'Source topology changed')
    obj = meshes[0]
    obj.name = 'FigureMesh'
    raw = np.array([obj.matrix_world @ v.co for v in obj.data.vertices])
    points = raw * np.array((-1, -1, 1))
    points[:, 0] += config['center'][0]
    points[:, 1] -= config['center'][1]
    obj.matrix_world.identity()
    source = RM.source_bones(config)
    weights = RM.skin_weights(points, config, source, species)
    specs, heel = extend_skeleton(source, config, points, weights)
    weights = extend_weights(points, specs, weights, config)
    ground = float(points[:, 2].min())
    scale = FIGURE_HEIGHT / float(points[:, 2].max() - ground)

    def place(p):
        q = (np.asarray(p, dtype=float) - np.array((0, 0, ground))) * scale
        return q
    placed = place(points)
    specs = {name: (place(a), place(b), parent) for name, (a, b, parent) in specs.items()}
    specs['Root'] = (np.zeros(3), np.array((0, 0, .15)), None)
    heel = {side: (y) * scale for side, y in heel.items()}
    obj.data.vertices.foreach_set('co', placed.astype(np.float32).ravel())
    obj.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    rig = make_rig(specs)
    rig['figure_height'] = FIGURE_HEIGHT
    rig['heel_y_L'] = float(heel['L'])
    rig['heel_y_R'] = float(heel['R'])
    rig['tail_weighted'] = bool(np.any(weights[:, NAMES.index('Tail')] > 0))
    fused = [eye['max_gaze_radians'] for eye in config['eyes'].values() if eye['kind'] == 'fused_surface_ellipsoid']
    sk = AM.Skeleton(rig, lid_shown=1.20 if species == 'cat' else animal.LID_SHOWN,
                     max_gaze=min(fused) if fused else None)
    edges = np.array([e.vertices[:] for e in obj.data.edges], dtype=int)
    weights, rig_check = repair_stretch(sk, placed, weights, edges, stretch_test_poses(sk))
    print('RIG_CHECK', species, rig_check, flush=True)
    for index, name in enumerate(NAMES):
        group = obj.vertex_groups.new(name=name)
        for vertex in np.nonzero(weights[:, index] > 0)[0]:
            group.add([int(vertex)], float(weights[vertex, index]), 'REPLACE')
    detail = points[:, 2] < source['Head'][0][2] + .035
    obj.vertex_groups.new(name='LODBody').add(np.nonzero(detail)[0].tolist(), 1.0, 'REPLACE')
    for material in obj.data.materials:
        material.name = 'Figure_' + species + '_Original'
        # The Meshy source is double sided: some original triangles face inwards.
        material.use_backface_culling = False
    texture_info = []
    for image in list(bpy.data.images):
        if image.name == 'Render Result' or not image.pixels:
            continue
        before = list(image.size)
        if max(image.size) > 1024:
            ratio = 1024 / max(image.size)
            image.scale(round(image.size[0] * ratio), round(image.size[1] * ratio))
        with tempfile.TemporaryDirectory(prefix='lumo-figure-texture-') as temporary:
            image.filepath_raw = str(Path(temporary) / (species + '_albedo.png'))
            image.file_format = 'PNG'
            image.save()
            if image.packed_file:
                image.unpack(method='REMOVE')
            image.pack()
        texture_info.append({'source_size': before, 'runtime_size': list(image.size)})
    for poly in obj.data.polygons:
        poly.use_smooth = True
    # Eyelid shells of the driver rig, at the figure's uniform scale.
    RM.HEAD_SCALE[species] = scale
    lid_specs = {name: (specs[name][0], specs[name][1], specs[name][2]) for name in specs}
    lids = RM.add_lids(config, lid_specs, species)
    bpy.ops.object.select_all(action='DESELECT')
    for part in [obj] + lids:
        part.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = 'FigureMesh'
    obj.parent = rig
    modifier = obj.modifiers.new('Skin', 'ARMATURE')
    modifier.object = rig
    modifier.use_deform_preserve_volume = False
    clips, extra = animate(rig, sk)
    decimate_body(obj, BODY_RATIO)
    path = OUT / species / 'figure.glb'
    export(obj, rig, path)
    repack_textures(path)
    data = path.read_bytes()
    obj.data.calc_loop_triangles()
    entry = {
        'id': species, 'name': NAMES_DE[species], 'model': 'res://' + str(path.relative_to(ROOT)),
        'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
        'triangles': len(obj.data.loop_triangles), 'bones': NAMES, 'height_m': FIGURE_HEIGHT,
        'hip_height_m': sk.hip_height, 'leg_length_m': sk.leg, 'clips': clips,
        'textures': texture_info, 'source_file': config['source_file'], 'source_sha256': digest,
        'tail_weighted': bool(rig['tail_weighted']), 'rig_check': rig_check,
        'build_seconds': round(time.time() - t0, 1),
    }
    entry.update(extra)
    print('FIGURE_COMPLETE', species, entry['triangles'], entry['bytes'], entry['build_seconds'], flush=True)
    return entry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--species', nargs='+')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    anatomy = json.loads(ANATOMY.read_text())['species']
    manifest_path = OUT / 'figures.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'schemaVersion': 1, 'figures': {}}
    for species in args.species or list(anatomy):
        manifest['figures'][species] = build(species, anatomy[species])
    manifest['generator'] = 'tools/lumo_animation/animals/build_standing_animals.py'
    manifest['contract'] = ('Rest pose = original standing A-pose; feet on y=0; Godot -Z forward. Locomotion clips are '
                            'in place: move the node with speed_mps (or scale playback by velocity/speed_mps). '
                            'enter_vehicle starts beside the seat at vehicle_entry_offset_m and ends in drive; '
                            'exit_vehicle is its reverse.')
    manifest['figures'] = dict(sorted(manifest['figures'].items()))
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
