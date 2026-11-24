"""Bind the retained Meshy rivals to LUMO's real kart/card skeleton.

Blender 4.3+: blender -b -t 2 --python-exit-code 1 -P this_file -- --species rabbit
The inputs are immutable textured GLBs, not replacement procedural characters.
Anatomical landmarks are reviewed against their front/side render; mesh weights
are computed in that original A-pose, then baked into the established seated
rest space. The same 26-bone rig and 12 fully keyed actions drive all three LODs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_animal_drivers as animal

ROOT = HERE.parents[2]
ANATOMY = HERE / "meshy_anatomy.json"
NAMES = animal.BODY_BONES + animal.FACE_BONES
INDEX = {name: i for i, name in enumerate(NAMES)}
HEAD_SCALE = {"rabbit": 2.0, "frog": 2.35, "lion": 2.1, "owl": 1.9,
              "squirrel": 1.9, "turtle": 2.15, "otter": 2.05,
              "badger": 2.0, "cat": 2.05}
LID_COLOR = {"rabbit": "aaa8b6", "frog": "80b63c", "lion": "c8853f",
             "owl": "8a7058", "squirrel": "b7642d", "turtle": "83b85d",
             "otter": "765340", "badger": "626064", "cat": "cac6ca"}


def smooth(value):
    value = np.clip(value, 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def authored(point, center):
    """Right-handed glTF +Z-facing -> authored Blender +Y-facing rotation."""
    return np.array((center[0] - point[0], point[2] - center[1], point[1]), dtype=float)


def side_from_raw(raw_side):
    return "R" if raw_side == "L" else "L"


def map_bone_points(points, source_span, target_span, radial_scale):
    a, b = source_span
    c, d = target_span
    axis = b-a
    original_length = np.linalg.norm(axis)
    axis = axis/original_length
    rotation = np.asarray(Vector(b-a).rotation_difference(Vector(d-c)).to_matrix())
    offset = np.asarray(points)-a
    along = (offset @ axis)[..., None]*axis
    axial_scale = np.linalg.norm(d-c)/original_length
    return c + ((offset-along)*radial_scale+along*axial_scale) @ rotation.T


def source_bones(config):
    center = config["center"]
    joints = {joint: {side_from_raw(side): authored(point, center)
                      for side, point in entries.items()}
              for joint, entries in config["joints"].items()}
    hip = (joints["hip"]["L"] + joints["hip"]["R"]) * .5
    neck = authored(config["neck"], center)
    # These four contiguous spans avoid cracks where the jacket meets the neck.
    line = neck - hip
    spine = hip + line * .20
    chest = hip + line * .66
    throat = hip + line * .90
    head_top = float(config["head_top"])
    if head_top <= neck[2] + .04:
        raise ValueError("Head landmark is below the neck")
    specs = {
        "Root": (np.array((0, 0, -.475)), np.array((0, 0, -.325)), None),
        "Pelvis": (hip, spine, "Root"),
        "Spine": (spine, chest, "Pelvis"),
        "Chest": (chest, throat, "Spine"),
        "Neck": (throat, neck, "Chest"),
        "Head": (neck, neck + np.array((0, 0, head_top-neck[2])), "Neck"),
    }
    for side in "LR":
        sh, el, palm = [joints[key][side] for key in ("shoulder", "elbow", "palm")]
        fingertip = palm + (palm - el) / np.linalg.norm(palm - el) * .045
        knee, ankle = [joints[key][side] for key in ("knee", "ankle")]
        specs.update({
            "UpperArm." + side: (sh, el, "Chest"),
            "Forearm." + side: (el, palm, "UpperArm." + side),
            "Hand." + side: (palm, fingertip, "Forearm." + side),
            "Thigh." + side: (joints["hip"][side], knee, "Pelvis"),
            "Shin." + side: (knee, ankle, "Thigh." + side),
            "Foot." + side: (ankle, ankle + np.array((0, .07, -.02)), "Shin." + side),
        })
    for raw_side, eye in config["eyes"].items():
        side = side_from_raw(raw_side)
        c = authored(eye["center"], center)
        specs["Eye." + side] = (c, c + np.array((0, .035, 0)), "Head")
        specs["Lid." + side] = (c, c + np.array((0, 0, .025)), "Head")
    eye_height = np.mean([specs["Eye."+side][0][2] for side in "LR"])
    jaw = neck + np.array((0, .025, max(.025, eye_height-neck[2]-.055)))
    specs["Jaw"] = (jaw, jaw + np.array((0, .08, -.025)), "Head")
    for raw_side, ear in config["ears"].items():
        side = side_from_raw(raw_side)
        specs["Ear."+side] = (authored(ear["base"], center),
                              authored(ear["tip"], center), "Head")
    tail = config["tail"]
    specs["Tail"] = (authored(tail["base"], center),
                      authored(tail["tip"], center), "Pelvis")
    assert set(specs) == set(NAMES)
    return specs


def seated_bones(source, species):
    """The existing wheel/pedal contract is exact; torso and head retain anatomy."""
    head_scale = HEAD_SCALE[species]
    shoulder_width = abs(source["UpperArm.R"][0][0])
    width_scale = min(2.65, max(1.55, .235 / shoulder_width))
    specs = {
        "Root": ((0, 0, 0), (0, 0, .15), None),
        "Pelvis": ((0, -.07, .82), (0, -.07, .92), "Root"),
        "Spine": ((0, -.07, .92), (0, -.075, 1.10), "Pelvis"),
        "Chest": ((0, -.075, 1.10), (0, -.04, 1.29), "Spine"),
        "Neck": ((0, -.04, 1.29), (0, -.015, 1.42), "Chest"),
        "Head": ((0, -.015, 1.42),
                 (0, -.015, 1.42 + (source["Head"][1][2]-source["Head"][0][2])*head_scale), "Neck"),
    }
    shoulder_z = {"frog": 1.19, "turtle": 1.20, "owl": 1.225}.get(species, 1.235)
    for side, sign in (("L", -1), ("R", 1)):
        shoulder = (sign * shoulder_width * width_scale, -.015, shoulder_z)
        elbow = (sign * .325, .16, 1.04)
        hand = (sign * .16, .34, 1.055)
        hip, knee, ankle = (sign*.145, -.04, .83), (sign*.165, .18, .91), (sign*.18, .24, .80)
        specs.update({
            "UpperArm."+side: (shoulder, elbow, "Chest"),
            "Forearm."+side: (elbow, hand, "UpperArm."+side),
            "Hand."+side: (hand, (sign*.16, .385, 1.055), "Forearm."+side),
            "Thigh."+side: (hip, knee, "Pelvis"),
            "Shin."+side: (knee, ankle, "Thigh."+side),
            "Foot."+side: (ankle, (sign*.18, .38, .80), "Shin."+side),
        })
    head_origin = np.asarray(specs["Head"][0])
    original_head = source["Head"][0]
    for name in animal.FACE_BONES + ["Ear.L", "Ear.R"]:
        a, b, parent = source[name]
        specs[name] = (head_origin + (a-original_head)*head_scale,
                       head_origin + (b-original_head)*head_scale, parent)
    tail_a, tail_b, parent = source["Tail"]
    # The root follows its actual attachment on the pelvis. A single generic
    # offset would leave an asymmetric squirrel/rabbit tail floating behind it.
    tail_origin = map_bone_points(tail_a, source['Pelvis'][:2],
                                  tuple(np.asarray(p) for p in specs['Pelvis'][:2]), width_scale)
    tail_scale = 1.45 if species == "squirrel" else 1.35
    specs["Tail"] = (tail_origin, tail_origin + (tail_b-tail_a)*tail_scale, parent)
    return {name: (np.asarray(a, dtype=float), np.asarray(b, dtype=float), parent)
            for name, (a, b, parent) in specs.items()}, width_scale


def segment_distance(points, a, b):
    line = b-a
    fraction = np.clip((points-a) @ line / np.dot(line, line), 0, 1)
    return np.linalg.norm(points-a-fraction[:, None]*line, axis=1)


def chain_weights(points, specs, names, softness=.027):
    # Interpolate only at joints. Distance softmax mixes adjacent bones along
    # entire limbs, because a shared endpoint can be nearly as close as a span.
    distances, fractions, lengths = [], [], []
    for name in names:
        a, b, _ = specs[name]
        line = b-a
        length = np.linalg.norm(line)
        fraction = np.clip((points-a) @ line / (length*length), 0, 1)
        distances.append(np.linalg.norm(points-a-fraction[:, None]*line, axis=1))
        fractions.append(fraction)
        lengths.append(length)
    distances = np.stack(distances, axis=1)
    fractions = np.stack(fractions, axis=1)
    lengths = np.asarray(lengths)
    offsets = np.r_[0.0, np.cumsum(lengths)[:-1]]
    nearest = distances.argmin(axis=1)
    along = (offsets + fractions*lengths)[np.arange(len(points)), nearest]
    first = smooth((along-lengths[0]+softness)/(2*softness))
    second = smooth((along-lengths[:2].sum()+softness)/(2*softness))
    weights = np.stack((1-first, first*(1-second), first*second), axis=1)
    return weights, distances.min(axis=1)


def skin_weights(points, config, specs, species):
    count = len(points)
    weights = np.zeros((count, len(NAMES)), dtype=float)
    z = points[:, 2]
    weights[:, INDEX["Pelvis"]] = 1
    previous = "Pelvis"
    for name, band in (("Spine", .035), ("Chest", .035), ("Neck", .025), ("Head", .035)):
        amount = smooth((z-specs[name][0][2]+band)/(2*band))
        weights[:, INDEX[name]] += amount * weights[:, INDEX[previous]]
        weights[:, INDEX[previous]] *= 1-amount
        previous = name
    core_distance = segment_distance(points, specs["Pelvis"][0], specs["Head"][0])
    for side, sign in (("L", -1), ("R", 1)):
        names = [name+"."+side for name in ("UpperArm", "Forearm", "Hand")]
        local, distance = chain_weights(points, specs, names, .026)
        shoulder = specs[names[0]][0]
        palm = specs[names[2]][0]
        mask = smooth((core_distance-distance-.012)/.045)
        mask *= smooth((shoulder[2]+.055-z)/.055)
        mask *= smooth((z-palm[2]+.13)/.08)
        mask *= smooth((sign*points[:, 0]-.01)/.05)
        weights *= (1-mask[:, None])
        for index, name in enumerate(names):
            weights[:, INDEX[name]] += local[:, index]*mask
    for side, sign in (("L", -1), ("R", 1)):
        names = [name+"."+side for name in ("Thigh", "Shin", "Foot")]
        local, distance = chain_weights(points, specs, names, .018)
        hip = specs[names[0]][0]
        mask = smooth((hip[2]+.035-z)/.08)
        mask *= smooth((sign*points[:, 0]+.018)/.036)
        arm_distance = np.minimum.reduce([
            segment_distance(points, specs[part+"."+side][0], specs[part+"."+side][1])
            for part in ("UpperArm", "Forearm", "Hand")])
        # Source hands sit at hip height in an A-pose. Height alone would bind
        # their fingers to the thighs and tear the hands during a greeting.
        mask *= smooth((arm_distance-distance-.005)/.035)
        weights *= 1-mask[:, None]
        for index, name in enumerate(names):
            weights[:, INDEX[name]] += local[:, index]*mask
    # Tail masks are evaluated before facial parts. A detached squirrel tail is
    # rigidly weighted to its actual component; no box-centre guess is involved.
    tail_config = config["tail"]
    tail_mask = np.zeros(count)
    indices = tail_config.get("original_vertex_indices", [])
    if indices:
        selected = np.asarray(indices, dtype=int)
        tail_mask[selected] = 1
        if tail_config['kind'] == 'anatomical_region':
            root_distance = np.linalg.norm(points-specs['Tail'][0], axis=1)
            collar = 1-smooth((root_distance-.025)/.04)
            weights *= 1-collar[:, None]
            weights[:, INDEX['Pelvis']] += collar
            tail_mask[selected] = smooth(root_distance[selected]/.065)
        weights[selected] = 0
        weights[selected, INDEX['Pelvis']] = 1-tail_mask[selected]
        weights[:, INDEX['Tail']] += tail_mask
    elif tail_config["kind"] == 'anatomical_region':
        path = [authored(p, config['center']) for p in tail_config['path']]
        tail_distance = np.minimum.reduce([
            segment_distance(points, a, b) for a, b in zip(path, path[1:])])
        leg_distance = np.minimum.reduce([
            segment_distance(points, specs[part+'.'+side][0], specs[part+'.'+side][1])
            for side in 'LR' for part in ('Thigh', 'Shin', 'Foot')])
        radius = tail_config['radius']
        region = ((tail_distance+.003 < leg_distance) &
                  (tail_distance < radius*2.2) &
                  (points[:, 1] < path[0][1]+.035) &
                  (z < path[0][2]+.035))
        # Keep a continuous root blend with Pelvis only; tail surfaces must not
        # inherit boot/knee motion just because the source tail passes a leg.
        tail_mask = region.astype(float)*smooth(np.linalg.norm(points-path[0], axis=1)/.065)
        weights[region] = 0
        weights[region, INDEX['Pelvis']] = 1-tail_mask[region]
        weights[:, INDEX['Tail']] += tail_mask
    for raw_side, ear in config["ears"].items():
        if not ear["anatomical"]:
            continue
        side = side_from_raw(raw_side)
        base = specs["Ear."+side][0]
        sign = -1 if side == "L" else 1
        amount = smooth((z-base[2])/.055) * smooth((sign*points[:, 0]-.018)/.035)
        amount *= weights[:, INDEX["Head"]]
        weights[:, INDEX["Head"]] -= amount
        weights[:, INDEX["Ear."+side]] += amount
    # The lower muzzle moves on Jaw; smooth falloff stays below the eyes and
    # cannot drag the whole cranium when the mouth opens.
    eye_z = np.mean([specs["Eye."+side][0][2] for side in "LR"])
    neck = specs["Head"][0]
    jaw = smooth((eye_z-.025-z)/.04) * smooth((z-neck[2]+.005)/.04)
    jaw *= smooth((points[:, 1]-neck[1]-.018)/.04)
    jaw *= smooth((.09-np.abs(points[:, 0]))/.035)
    amount = jaw * weights[:, INDEX["Head"]] * .85
    weights[:, INDEX["Head"]] -= amount
    weights[:, INDEX["Jaw"]] += amount
    for raw_side, eye in config["eyes"].items():
        side = side_from_raw(raw_side)
        selected = np.zeros(count, dtype=bool)
        indices = eye.get("original_vertex_indices", [])
        if eye["kind"] == "detached_component":
            assert indices, (species, side, "Missing detached eye component")
            selected[np.asarray(indices, dtype=int)] = True
            weights[selected, :] = 0
            weights[selected, INDEX["Eye."+side]] = 1
        else:
            # Otter eyes are part of the original continuous face. Bind only
            # their small surface regions, with low amplitude eye articulation.
            c = specs["Eye."+side][0]
            raw_r = eye["radii"]
            radii = np.asarray((raw_r[0], raw_r[2], raw_r[1]))
            dist = np.linalg.norm((points-c)/radii, axis=1)
            strength = smooth((1.25-dist)/.4) * smooth((points[:, 1]-c[1])/.008)
            strength *= weights[:, INDEX["Head"]]
            weights[:, INDEX["Head"]] -= strength
            weights[:, INDEX["Eye."+side]] += strength
    # Apply rigid anatomy last, so the general leg classifier cannot overwrite
    # the lower edge of a shell that extends below the hips.
    shell = rigid_shell_mask(count, config)
    if np.any(shell):
        weights *= 1-shell[:, None]
        weights[:, INDEX[config['rigid_shell']['bone']]] += shell
    order = np.argsort(-weights, axis=1)
    for row in range(count):
        weights[row, order[row, 4:]] = 0
    weights[weights < 1e-5] = 0
    totals = weights.sum(axis=1)
    assert np.all(totals > 0) and np.all(np.isfinite(weights))
    return weights/totals[:, None]


def rigid_shell_mask(count, config):
    mask = np.zeros(count)
    shell = config.get('rigid_shell')
    if shell:
        mask[np.asarray(shell['transition_vertex_indices'], dtype=int)] = shell['transition_weight']
        mask[np.asarray(shell['original_vertex_indices'], dtype=int)] = 1.0
    return mask


def fit_to_seated(points, weights, source, target, width_scale, species):
    result = np.zeros_like(points)
    for index, name in enumerate(NAMES):
        if not np.any(weights[:, index] > 0):
            continue
        a, b, _ = source[name]
        c, d, _ = target[name]
        radial_scale = width_scale
        if name in animal.FACE_BONES or name in ("Head", "Ear.L", "Ear.R"):
            radial_scale = HEAD_SCALE[species]
        elif name == "Tail":
            radial_scale = 1.45 if species == "squirrel" else 1.35
        elif name.startswith(("Hand.", "Foot.")):
            radial_scale = 1.55
        elif name.startswith(("Thigh.", "Shin.")):
            radial_scale = 1.65
        elif name.startswith(("UpperArm.", "Forearm.")):
            radial_scale = 1.75
        mapped = map_bone_points(points, (a,b), (c,d), radial_scale)
        result += mapped*weights[:, index:index+1]
    assert np.all(np.isfinite(result))
    return result


def add_lids(config, target, species):
    material = bpy.data.materials.new("Meshy_"+species+"_Eyelid")
    material.use_nodes = True
    material.use_backface_culling = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*animal.srgb_to_linear(LID_COLOR[species]), 1)
    shader.inputs["Roughness"].default_value = .85
    crease_material = bpy.data.materials.new("Meshy_"+species+"_LidCrease")
    crease_material.use_nodes = True
    crease_material.use_backface_culling = True
    crease_shader = crease_material.node_tree.nodes.get("Principled BSDF")
    crease_shader.inputs["Base Color"].default_value = (*animal.srgb_to_linear("302b2b"), 1)
    crease_shader.inputs["Roughness"].default_value = .9
    lids = []
    for raw_side, eye in config["eyes"].items():
        side = side_from_raw(raw_side)
        c = target["Lid."+side][0]
        rx, rz, ry = np.asarray(eye["radii"])*HEAD_SCALE[species]
        # The closed lid grows out from inside the existing eyeball; no
        # substitute eyeball or painted face is introduced.
        rotation = Matrix.Rotation(2.6, 3, 'X') @ Matrix.Rotation(math.pi/2, 3, 'X')
        verts, faces, _ = animal.ellipsoid_mesh(c, (rx*.93, rz*.93, ry*.93), rotation,
                                              24, 0, [j/9*.56 for j in range(1, 10)], True)
        obj = animal.new_object("Lid."+side, verts, faces)
        group = obj.vertex_groups.new(name="Lid."+side)
        group.add(list(range(len(verts))), 1.0, 'REPLACE')
        obj.data.materials.append(material)
        for face in obj.data.polygons:
            face.use_smooth = True
        lids.append(obj)
        # A closed eye must read as a blink, not as an untextured white sphere.
        # The fine curved fold lives inside the original eye at rest, and
        # emerges with the same Lid bone and scale as the closure shell.
        closed = []
        for x in np.linspace(-.72, .72, 13):
            z = -.12-.16*(1-(x/.72)**2)
            y = math.sqrt(max(0, 1-x*x-z*z))
            relative = Vector((x*rx, y*ry, z*rz))*.935
            closed.append(Vector(c)+Matrix.Rotation(2.6, 3, 'X') @ relative)
        verts, faces = animal.tube_mesh(closed, .0008*HEAD_SCALE[species], 5)
        fold = animal.new_object("LidCrease."+side, verts, faces)
        fold.vertex_groups.new(name="Lid."+side).add(list(range(len(verts))), 1.0, 'REPLACE')
        fold.data.materials.append(crease_material)
        for face in fold.data.polygons:
            face.use_smooth = True
        lids.append(fold)
    return lids


def build(species, config, review_directory=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source_file = ROOT/config["source_file"]
    digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
    assert digest == config["source_sha256"], (species, "Meshy original changed")
    bpy.ops.import_scene.gltf(filepath=str(source_file))
    objects = [o for o in bpy.context.selected_objects if o.type == 'MESH']
    assert len(objects) == 1, (species, "Source topology changed")
    obj = objects[0]
    obj.name = "DriverMesh"
    original_points = np.array([obj.matrix_world @ v.co for v in obj.data.vertices])
    # The conversion is a rotation, never a negative-scale reflection.
    points = original_points*np.array((-1, -1, 1))
    points[:, 0] += config["center"][0]
    points[:, 1] -= config["center"][1]
    obj.matrix_world = Matrix.Identity(4)
    source = source_bones(config)
    target, width_scale = seated_bones(source, species)
    weights = skin_weights(points, config, source, species)
    fitted = fit_to_seated(points, weights, source, target, width_scale, species)
    shell = rigid_shell_mask(len(points), config)
    if np.any(shell):
        scale = ((target['Head'][0][2]-target['Pelvis'][0][2]) /
                 (source['Head'][0][2]-source['Pelvis'][0][2]))
        rigid = target['Pelvis'][0] + (points-source['Pelvis'][0])*scale
        fitted = fitted*(1-shell[:, None]) + rigid*shell[:, None]
    obj.data.vertices.foreach_set('co', fitted.astype(np.float32).ravel())
    obj.data.update()
    # Imported custom normals describe the A-pose; recalculate for the new rest.
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    # Retain the original triangle winding. UV seams are separate vertices;
    # reorienting each resulting island would arbitrarily flip valid surfaces.
    obj.data.update()
    for name, column in INDEX.items():
        group = obj.vertex_groups.new(name=name)
        for vertex in np.nonzero(weights[:, column] > 0)[0]:
            group.add([int(vertex)], float(weights[vertex, column]), 'REPLACE')
    # Protect the original eyes and face rings in all distance levels.
    detail = points[:, 2] < source["Head"][0][2]+.035
    body_group = obj.vertex_groups.new(name="LODBody")
    body_group.add(np.nonzero(detail)[0].tolist(), 1.0, 'REPLACE')
    for material in obj.data.materials:
        material.name = "Meshy_"+species+"_Original"
        material.use_backface_culling = True
    texture_info = []
    for image in list(bpy.data.images):
        if image.name == 'Render Result' or image.source not in ('FILE', 'GENERATED'):
            continue
        # glTF images load lazily: has_data may be false until pixels are read.
        if not image.pixels:
            continue
        before = list(image.size)
        if max(image.size) > 1024:
            ratio = 1024/max(image.size)
            image.scale(round(image.size[0]*ratio), round(image.size[1]*ratio))
        # Replace the packed source bytes explicitly; otherwise glTF export can
        # reuse the original 2048 PNG even though Blender displays 1024 pixels.
        with tempfile.TemporaryDirectory(prefix='lumo-meshy-texture-') as temporary:
            image.filepath_raw = str(Path(temporary)/(species+'_albedo.png'))
            image.file_format = 'PNG'
            image.save()
            if image.packed_file:
                image.unpack(method='REMOVE')
            image.pack()
        texture_info.append({"name": image.name, "source_size": before, "runtime_size": list(image.size)})
    for poly in obj.data.polygons:
        poly.use_smooth = True
    lids = add_lids(config, target, species)
    bpy.ops.object.select_all(action='DESELECT')
    for part in [obj]+lids:
        part.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    rig = animal.make_rig(target)
    obj.parent = rig
    modifier = obj.modifiers.new("NormalizedSkin", 'ARMATURE')
    modifier.object = rig
    modifier.use_deform_preserve_volume = False  # identical to exported glTF linear skinning
    fused_limits = [eye['max_gaze_radians'] for eye in config['eyes'].values()
                    if eye['kind'] == 'fused_surface_ellipsoid']
    animations = animal.animate(rig, target, max_eye_gaze=min(fused_limits) if fused_limits else None,
                                lid_shown=1.20 if species == 'cat' else animal.LID_SHOWN)
    animal.make_markers(rig)
    rig["meshy_source_sha256"] = digest
    rig["meshy_task_id"] = config["task_id"]
    rig["species"] = species
    output = ROOT/"assets/kart/production/drivers"/species
    lods = animal.export_lods(obj, rig, output)
    blend_directory = ROOT/"art/lumo_kart/blender/drivers"
    blend_directory.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_directory/(species+".blend")), compress=True)
    measured = {"species": species, "source_file": config["source_file"], "source_sha256": digest,
                "task_id": config["task_id"], "bones": NAMES, "animations": animations,
                "lods": lods, "textures": texture_info,
                "anatomy_file": str(ANATOMY.relative_to(ROOT)),
                "anatomy_sha256": hashlib.sha256(ANATOMY.read_bytes()).hexdigest(),
                "blender_version": bpy.app.version_string,
                "authoring": "Retained textured Meshy source, anatomy-guided four-influence skinning, seated rest-space fitting, actual eye components and eyelid skins, 26 bones and 12 authored clips; three explicit LODs."}
    evidence = ROOT/"evidence/lumo_kart_art/drivers"/species
    evidence.mkdir(parents=True, exist_ok=True)
    if review_directory:
        render_review(species, rig, review_directory)
    portrait = render_portrait(species, rig, obj)
    measured["portrait"] = {"file": str(portrait.relative_to(ROOT)),
                            "sha256": hashlib.sha256(portrait.read_bytes()).hexdigest(),
                            "bytes": portrait.stat().st_size,
                            "source": "Rendered from this rigged Meshy mesh"}
    (evidence/"measurement.json").write_text(json.dumps(measured, indent=2)+"\n")
    print("MESHY_RIG_COMPLETE", species, json.dumps({k: (v['triangles'],v['bytes']) for k,v in lods.items()}), flush=True)


def render_review(species, rig, output):
    """Actual evaluated Blender skin; useful for evaluating fitting and gestures."""
    output.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('RigReviewWorld')
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes['Background']
    background.inputs[0].default_value = (.2, .24, .31, 1)
    background.inputs[1].default_value = .7
    scene.view_settings.view_transform = 'AgX'
    for name, location, energy, size in [('ReviewKey',(-3,4,5),700,4),
                                         ('ReviewFill',(3,2,3),450,4),
                                         ('ReviewRim',(0,-3,4),700,3)]:
        light = bpy.data.lights.new(name,'AREA')
        light.energy, light.size = energy, size
        node = bpy.data.objects.new(name, light)
        scene.collection.objects.link(node)
        node.location = location
        animal.look_at(node, (0,0,1.35))
    camera = bpy.data.objects.new('ReviewCamera', bpy.data.cameras.new('ReviewCamera'))
    scene.collection.objects.link(camera)
    camera.data.type = 'ORTHO'
    scene.camera = camera
    for clip, frame, view in [('kart_seated',1,'front'), ('kart_seated',1,'side'), ('kart_seated',31,'blink'),
                              ('kart_steer_left',22,'quarter'), ('greeting_wave',24,'quarter'),
                              ('celebrate',35,'quarter'), ('idle',1,'front')]:
        rig.animation_data.action = bpy.data.actions[clip]
        scene.frame_set(frame)
        evaluated = bpy.data.objects['DriverMesh'].evaluated_get(bpy.context.evaluated_depsgraph_get())
        points = np.asarray([evaluated.matrix_world @ v.co for v in evaluated.data.vertices])
        center = (points.min(axis=0)+points.max(axis=0))/2
        direction = {'front': (0,5,0), 'blink': (0,5,0), 'side': (5,0,0), 'quarter': (2.7,4.4,.65)}[view]
        camera.location = Vector(center)+Vector(direction)
        animal.look_at(camera, center)
        rotation = np.asarray(camera.rotation_euler.to_matrix())
        projected = (points-center) @ rotation[:, :2]
        camera.data.ortho_scale = float(np.abs(projected).max()*2.16)
        scene.render.filepath = str(output/f'{species}_{clip}_{view}.png')
        bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.name.startswith('Review'):
            bpy.data.objects.remove(obj, do_unlink=True)


def render_portrait(species, rig, mesh):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 4
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.resolution_x = scene.render.resolution_y = 400
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'WEBP'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.quality = 93
    scene.world = scene.world or bpy.data.worlds.new('PortraitWorld')
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes['Background']
    background.inputs[0].default_value = (.6,.70,.75,1)
    background.inputs[1].default_value = .32
    scene.view_settings.view_transform = 'AgX'
    head_groups = {mesh.vertex_groups[name].index for name in
                   ['Head', 'Ear.L', 'Ear.R'] + animal.FACE_BONES}
    points = np.asarray([v.co[:] for v in mesh.data.vertices
                         if sum(w.weight for w in v.groups if w.group in head_groups) > .6])
    low, high = points.min(axis=0), points.max(axis=0)
    floor = 1.12
    target = Vector(((low[0]+high[0])/2, 0, (floor+high[2])/2))
    for name, location, energy, color, size in [
            ('PortraitKey',(-2.4,3.8,4.3),380,(1,.87,.76),2.7),
            ('PortraitFill',(2.5,2.6,2.9),190,(.76,.88,1),3),
            ('PortraitRim',(1.2,-2.6,3.3),430,(1,.81,.59),1.9)]:
        light = bpy.data.lights.new(name, 'AREA')
        light.energy, light.color, light.size = energy, color, size
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = location
        animal.look_at(obj, target)
    camera = bpy.data.objects.new('PortraitCamera', bpy.data.cameras.new('PortraitCamera'))
    scene.collection.objects.link(camera)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = max(high[2]-floor, high[0]-low[0]) * 1.13
    camera.location = target+Vector((.65,4.2,.12))
    animal.look_at(camera, target)
    scene.camera = camera
    rig.animation_data.action = bpy.data.actions['kart_seated']
    scene.frame_set(8)
    path = ROOT/'assets/kart/menu/drivers'/f'{species}.webp'
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--species', nargs='+')
    parser.add_argument('--review', type=Path)
    parser.add_argument('--review-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    anatomy = json.loads(ANATOMY.read_text())['species']
    for species in args.species or anatomy:
        if species not in anatomy:
            raise ValueError(f'Unknown driver {species}')
        if args.review_only:
            if args.review is None:
                parser.error('--review-only requires --review')
            bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/lumo_kart/blender/drivers'/f'{species}.blend'))
            rig = bpy.data.objects['DriverRig']
            assert rig['meshy_source_sha256'] == anatomy[species]['source_sha256']
            render_review(species, rig, args.review)
        else:
            build(species, anatomy[species], args.review)


if __name__ == '__main__':
    main()
