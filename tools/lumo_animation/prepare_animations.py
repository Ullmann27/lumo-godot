"""Reproducible local animation of ONE existing Meshy Smart-Rig Lumo.

No network calls, model generation, geometry replacement or audio edits.
The provider source is preserved. Face geometry moves rigidly with Head.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

NAMES = {
    0: "Root", 1: "Pelvis", 4: "SpineLower", 3: "SpineUpper", 2: "Chest",
    22: "Neck", 21: "Head", 20: "Crown",
    27: "Clavicle.R", 26: "UpperArm.R", 25: "Forearm.R", 24: "Wrist.R", 23: "Hand.R",
    32: "Clavicle.L", 31: "UpperArm.L", 30: "Forearm.L", 29: "Wrist.L", 28: "Hand.L",
    9: "Thigh.R", 8: "Shin.R", 7: "Foot.R", 6: "Toe.R", 5: "ToeTip.R",
    14: "Thigh.L", 13: "Shin.L", 12: "Foot.L", 11: "Toe.L", 10: "ToeTip.L",
    19: "TailBase", 18: "Tail1", 17: "Tail2", 16: "Tail3", 15: "TailTip",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rotate(rig, name, axis, radians):
    """A rest-local delta about an explicit armature-space axis."""
    bone = rig.pose.bones[name]
    local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
    bone.rotation_quaternion = Quaternion(local_axis.normalized(), radians)


def translate(rig, name, offset):
    bone = rig.pose.bones[name]
    bone.location = bone.bone.matrix_local.to_3x3().inverted() @ Vector(offset)


def update():
    bpy.context.view_layer.update()


def hand_ik(rig, side, target, iterations=28):
    """CCD over the three real arm bones; never stretches the skeleton."""
    target = Vector(target)
    hand = rig.pose.bones["Hand." + side]
    for _ in range(iterations):
        update()
        if (hand.head - target).length < 0.00015:
            break
        for name in ["Wrist.", "Forearm.", "UpperArm."]:
            joint = rig.pose.bones[name + side]
            origin = joint.head.copy()
            a = hand.head - origin
            b = target - origin
            if min(a.length, b.length) < 1e-7:
                continue
            delta = a.normalized().rotation_difference(b.normalized()).to_matrix().to_4x4()
            matrix = Matrix.Translation(origin) @ delta @ Matrix.Translation(-origin) @ joint.matrix
            joint.matrix = matrix
            update()
    return (hand.head - target).length


def relax(rig):
    rotate(rig, "UpperArm.R", (0, 1, 0), -0.17)
    rotate(rig, "UpperArm.L", (0, 1, 0), 0.17)


def seated(rig, steer=0.0):
    for side in ["L", "R"]:
        rotate(rig, "Thigh." + side, (1, 0, 0), math.radians(-76))
        rotate(rig, "Shin." + side, (1, 0, 0), math.radians(84))
        rotate(rig, "Foot." + side, (1, 0, 0), math.radians(-8))
    rotate(rig, "Chest", (0, 1, 0), steer * -0.045)
    # These are review-space targets. The Godot adapter solves them against
    # the actual rotating Kart wheel instead of claiming this is exact contact.
    for side, sign in [("R", -1), ("L", 1)]:
        rotate(rig, "UpperArm." + side, (0, 1, 0), sign * -0.25)
        hand_ik(rig, side, (sign * 0.18, -0.41, 0.87 + sign * steer * 0.075))


def pose(rig, clip, time, duration):
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = Quaternion()
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    relax(rig)
    progress = time / duration
    cycle = math.sin(progress * math.tau)
    if clip == "idle":
        translate(rig, "Root", (0, 0, cycle * 0.004))
        rotate(rig, "Chest", (1, 0, 0), cycle * 0.012)
        rotate(rig, "Head", (0, 0, 1), cycle * 0.025)
        rotate(rig, "TailBase", (0, 0, 1), cycle * 0.025)
    elif clip in ["greeting_wave", "celebrate", "point_portal"]:
        ease = math.sin(math.pi * progress) ** 0.7
        if clip == "greeting_wave":
            rotate(rig, "UpperArm.R", (0, 1, 0), 1.5 * ease)
            rotate(rig, "Forearm.R", (0, 1, 0), -0.50 * ease)
            update()
            start = rig.pose.bones["Hand.R"].head.copy()
            target = start.lerp(Vector((-0.33 - 0.025 * math.sin(time * 9), -0.12, 1.42)), ease)
            hand_ik(rig, "R", target)
            rotate(rig, "Hand.R", (0, 1, 0), math.sin(time * 9) * 0.20 * ease)
            rotate(rig, "Head", (0, 1, 0), -0.05 * ease)
        elif clip == "celebrate":
            for side, sign in [("R", -1), ("L", 1)]:
                rotate(rig, "UpperArm." + side, (0, 1, 0), -sign * 1.45 * ease)
                update()
                start = rig.pose.bones["Hand." + side].head.copy()
                hand_ik(rig, side, start.lerp(Vector((sign * 0.37, -0.13, 1.39)), ease))
            translate(rig, "Root", (0, 0, ease * (0.018 + 0.020 * abs(math.sin(time * 7)))))
            rotate(rig, "Head", (1, 0, 0), -0.04 * ease)
            rotate(rig, "TailBase", (0, 0, 1), math.sin(time * 7) * 0.055 * ease)
        else:
            rotate(rig, "UpperArm.L", (0, 1, 0), -0.60 * ease)
            update()
            start = rig.pose.bones["Hand.L"].head.copy()
            hand_ik(rig, "L", start.lerp(Vector((0.49, -0.10, 1.07)), ease))
            rotate(rig, "Head", (0, 0, 1), -0.08 * ease)
    elif clip == "agree_nod":
        rotate(rig, "Head", (1, 0, 0), math.sin(progress * math.tau * 2) * 0.12 * math.sin(progress * math.pi))
    else:
        steer = -1.0 if clip == "kart_steer_left" else 1.0 if clip == "kart_steer_right" else 0.0
        seated(rig, steer)
        if clip == "kart_jump":
            rotate(rig, "Chest", (1, 0, 0), math.sin(progress * math.pi) * -0.075)
            rotate(rig, "Head", (1, 0, 0), math.sin(progress * math.pi) * 0.06)
            # Character reaction only. No car translation or simulated jump.
            rotate(rig, "TailBase", (1, 0, 0), math.sin(progress * math.pi) * 0.06)
    update()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = Path(args.input).resolve()
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    source_sha = digest(source)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=False)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    assert len(rigs) == 1, "Process one existing rig only."
    rig = rigs[0]
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and
              any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    assert len(meshes) == 1
    mesh = meshes[0]
    removed_helpers = []
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj not in meshes:
            removed_helpers.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    for index, name in NAMES.items():
        old = f"Bone_{index:03d}"
        assert old in rig.data.bones
        rig.data.bones[old].name = name
        if old in mesh.vertex_groups:
            mesh.vertex_groups[old].name = name
    for bone in rig.data.bones:
        if bone.name.startswith("Bone_"):
            old = bone.name
            bone.name = "Finger_" + old[5:]
            if old in mesh.vertex_groups:
                mesh.vertex_groups[old].name = bone.name
    # Keep the recognisable face, goggles, eyebrows and ears as one rigid
    # head region. No eyeball squeeze or false viseme system.
    head = mesh.vertex_groups["Head"]
    pinned = 0
    for vertex in mesh.data.vertices:
        world = mesh.matrix_world @ vertex.co
        if world.z >= 1.22:
            for group in list(vertex.groups):
                mesh.vertex_groups[group.group].remove([vertex.index])
            head.add([vertex.index], 1.0, "REPLACE")
            pinned += 1
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    decimate = mesh.modifiers.new("Mobile30k", "DECIMATE")
    decimate.ratio = 30000 / 107386
    decimate.use_collapse_triangulate = True
    # Decimation must precede skinning and preserves the original UV atlas.
    bpy.ops.object.modifier_move_up(modifier=decimate.name)
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    for vertex in mesh.data.vertices:
        groups = sorted(vertex.groups, key=lambda g: g.weight, reverse=True)
        keep = [(g.group, g.weight) for g in groups[:4] if g.weight > 1e-6]
        assert keep, f"Unweighted character vertex {vertex.index}"
        total = sum(w for _, w in keep)
        for group in list(vertex.groups):
            mesh.vertex_groups[group.group].remove([vertex.index])
        for index, weight in keep:
            mesh.vertex_groups[index].add([vertex.index], weight / total, "REPLACE")
    for image in bpy.data.images:
        if image.size[0]:
            if max(image.size) > 1024:
                image.scale(1024, 1024)
            image.pack()
    scene = bpy.context.scene
    scene.render.fps = 30
    clips = {
        "idle": 3.0, "greeting_wave": 2.0, "celebrate": 2.0,
        "point_portal": 1.6, "agree_nod": 1.6,
        "kart_seated": 1.0, "kart_steer_left": 1.0,
        "kart_steer_right": 1.0, "kart_jump": 1.0,
    }
    rig.animation_data_create()
    for name, duration in clips.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame in range(1, round(duration * 30) + 2, 3):
            scene.frame_set(frame)
            pose(rig, name, min((frame - 1) / 30, duration), duration)
            for bone in rig.pose.bones:
                bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
                bone.keyframe_insert("location", frame=frame, group=bone.name)
        frame = round(duration * 30) + 1
        scene.frame_set(frame)
        pose(rig, name, duration, duration)
        for bone in rig.pose.bones:
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
            bone.keyframe_insert("location", frame=frame, group=bone.name)
    rig.animation_data.action = bpy.data.actions["idle"]
    scene.frame_start = 1
    scene.frame_end = 91
    scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "Lumo-Animated-Mobile.blend"))
    glb = out / "Lumo-Animated-Mobile.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_force_sampling=True, export_frame_range=False,
        export_optimize_animation_size=True, export_anim_single_armature=True,
        export_morph=False, export_yup=True,
    )
    mesh.data.calc_loop_triangles()
    assert len(mesh.data.loop_triangles) <= 30000
    assert digest(source) == source_sha
    result = {
        "source_sha256": source_sha, "source_unchanged": True,
        "output_sha256": digest(glb), "output_bytes": glb.stat().st_size,
        "triangles": len(mesh.data.loop_triangles), "vertices": len(mesh.data.vertices),
        "bones": len(rig.data.bones), "max_weights": 4,
        "textures": [list(i.size) for i in bpy.data.images if i.size[0]],
        "excluded_blender_display_helpers": removed_helpers,
        "head_vertices_pinned_before_lod": pinned,
        "clips": clips, "frame_rate": 30, "key_interval_frames": 3,
        "animation_author": "Local Blender keyframes; not Meshy motion presets",
        "facial_morphs": False, "lip_sync": False,
        "android_device_test": False, "production_driver_replaced": False,
    }
    (out / "animation-build.json").write_text(json.dumps(result, indent=2) + "\n")
    print("LUMO_ANIMATION_BUILD=" + json.dumps(result))


if __name__ == "__main__":
    main()
