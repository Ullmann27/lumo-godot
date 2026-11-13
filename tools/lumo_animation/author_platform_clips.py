"""Author a reusable motion library on the unchanged original Lumo skeleton.

Run in Blender. The runtime library contains sampled character-space bone
rotations derived from evaluated Blender poses, including two-bone leg IK.
Original geometry, skin, UVs, materials and nine source clips are never written.
The small .blend contains editable actions which can be appended to the source
rig; the runtime uses exactly the exported keyframes, not a lookalike fox.
"""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

BONES = [
    "Pelvis", "SpineLower", "SpineUpper", "Neck", "Head",
    "Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R",
    "Toe.L", "Toe.R", "UpperArm.L", "UpperArm.R", "Forearm.L", "Forearm.R",
    "TailBase", "Tail1", "Tail2", "Tail3", "TailTip",
]
CLIPS = {
    "walk": (1.0, True), "sprint": (0.60, True),
    "jump_rise": (0.48, False), "jump_fall": (0.48, False),
    "land": (0.20, False), "brake": (0.30, False),
}
C = Matrix.Rotation(math.pi / 2, 3, "X")
SAMPLES = 25


def update():
    bpy.context.view_layer.update()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def body_quaternion(axis, angle):
    return (C @ Quaternion(Vector(axis), angle).to_matrix() @ C.inverted()).to_quaternion()


class Author:
    def __init__(self, rig):
        self.rig = rig
        self.neutral = {}
        self.global_neutral = {}
        for bone in rig.pose.bones:
            bone.rotation_mode = "QUATERNION"
            self.neutral[bone.name] = (
                bone.location.copy(), bone.rotation_quaternion.copy(), bone.scale.copy()
            )
            self.global_neutral[bone.name] = bone.matrix.copy()
        self.foot_rest = {side: rig.pose.bones["Foot." + side].head.copy() for side in ["L", "R"]}
        self.max_leg_error = 0.0

    def reset(self):
        for name, (location, rotation, scale) in self.neutral.items():
            bone = self.rig.pose.bones[name]
            bone.location = location
            bone.rotation_quaternion = rotation
            bone.scale = scale
        update()

    def rotate(self, name, axis, angle):
        bone = self.rig.pose.bones[name]
        frame = self.global_neutral[name].to_quaternion()
        delta = frame.inverted() @ body_quaternion(axis, angle) @ frame
        bone.rotation_quaternion = self.neutral[name][1] @ delta

    def translate(self, name, godot_offset):
        bone = self.rig.pose.bones[name]
        frame = self.global_neutral[name].to_3x3()
        bone.location = self.neutral[name][0] + frame.inverted() @ (C @ Vector(godot_offset))

    def turn_joint(self, name, end, goal):
        joint = self.rig.pose.bones[name]
        origin = joint.head.copy()
        a, b = end - origin, goal - origin
        if min(a.length, b.length) < 1e-7:
            return
        delta = a.normalized().rotation_difference(b.normalized()).to_matrix().to_4x4()
        joint.matrix = Matrix.Translation(origin) @ delta @ Matrix.Translation(-origin) @ joint.matrix
        update()

    def leg(self, side, goal):
        """Two rigid links, forward pole and a level sole; no bone stretching."""
        thigh = self.rig.pose.bones["Thigh." + side]
        shin = self.rig.pose.bones["Shin." + side]
        foot = self.rig.pose.bones["Foot." + side]
        hip, knee, ankle = thigh.head.copy(), shin.head.copy(), foot.head.copy()
        upper, lower = (knee - hip).length, (ankle - knee).length
        direction = goal - hip
        length = min(upper + lower - 0.0001, max(abs(upper - lower) + 0.0001, direction.length))
        direction.normalize()
        target = hip + direction * length
        pole = C @ Vector((0, 0, 1))
        pole = (pole - direction * pole.dot(direction)).normalized()
        along = (upper * upper - lower * lower + length * length) / (2 * length)
        height = math.sqrt(max(0, upper * upper - along * along))
        wanted_knee = hip + direction * along + pole * height
        self.turn_joint("Thigh." + side, knee, wanted_knee)
        self.turn_joint("Shin." + side, foot.head.copy(), target)
        matrix = self.global_neutral["Foot." + side].copy()
        matrix.translation = foot.head.copy()
        foot.matrix = matrix
        update()
        self.max_leg_error = max(self.max_leg_error, (foot.head - target).length)

    def pose(self, clip, progress):
        self.reset()
        phase = progress * math.tau
        if clip in ["walk", "sprint"]:
            running = clip == "sprint"
            duty = 0.38 if running else 0.62
            sweep = (1.42 if running else 0.78) * duty * 0.5
            bob = 0.018 * (1 - math.cos(phase * 2))
            self.translate("Pelvis", (0, -0.045 + bob, 0))
            self.rotate("SpineLower", (1, 0, 0), 0.14 if running else 0.035)
            self.rotate("SpineUpper", (0, 1, 0), math.sin(phase) * (0.06 if running else 0.035))
            self.rotate("Neck", (1, 0, 0), -0.07 if running else -0.02)
            update()
            for side, offset in [("L", 0), ("R", 0.5)]:
                u = (progress + offset) % 1
                if u < duty:
                    forward, lift = sweep * (1 - 2 * u / duty), 0.0
                else:
                    swing = (u - duty) / (1 - duty)
                    forward = -sweep * math.cos(math.pi * swing)
                    lift = (0.17 if running else 0.095) * math.sin(math.pi * swing)
                goal = self.foot_rest[side] + C @ Vector((0, lift, forward))
                self.leg(side, goal)
                self.rotate("UpperArm." + side, (1, 0, 0), math.sin((progress + offset) * math.tau) * (0.58 if running else 0.30))
                self.rotate("Forearm." + side, (1, 0, 0), -0.38 if running else -0.08)
        elif clip in ["jump_rise", "jump_fall"]:
            rising = clip == "jump_rise"
            tuck = math.sin(progress * math.pi * 0.65) if rising else 1 - progress
            self.rotate("SpineLower", (1, 0, 0), 0.08 * tuck)
            self.rotate("Neck", (1, 0, 0), -0.05 * tuck)
            update()
            for side in ["L", "R"]:
                goal = self.foot_rest[side] + C @ Vector((0, 0.055 + 0.17 * tuck, -0.035 - 0.06 * tuck))
                self.leg(side, goal)
                self.rotate("UpperArm." + side, (1, 0, 0), -0.55 + 0.18 * tuck)
                self.rotate("Forearm." + side, (1, 0, 0), -0.22 * tuck)
        else:
            strength = math.sin(math.pi * progress)
            crouch = 0.10 if clip == "land" else 0.045
            self.translate("Pelvis", (0, -crouch * strength, 0))
            self.rotate("SpineLower", (1, 0, 0), (0.16 if clip == "land" else -0.23) * strength)
            self.rotate("Neck", (1, 0, 0), (-0.10 if clip == "land" else 0.14) * strength)
            update()
            for side in ["L", "R"]:
                self.leg(side, self.foot_rest[side])
                self.rotate("UpperArm." + side, (1, 0, 0), -0.30 * strength)
        for i, name in enumerate(["TailBase", "Tail1", "Tail2", "Tail3", "TailTip"]):
            self.rotate(name, (0, 1, 0), math.sin(phase - i * 0.48) * (0.045 if clip in ["walk", "sprint"] else 0.02))
        update()

    def exported_rotation(self, name):
        bone = self.rig.pose.bones[name]
        initial = self.global_neutral[name].to_quaternion()
        actual = bone.matrix.to_quaternion()
        p0 = self.global_neutral[bone.parent.name].to_quaternion() if bone.parent else Quaternion()
        p1 = bone.parent.matrix.to_quaternion() if bone.parent else Quaternion()
        delta = p0 @ p1.inverted() @ actual @ initial.inverted()
        return (C.inverted() @ delta.to_matrix() @ C).to_quaternion().normalized()


def gd_number(value):
    value = 0.0 if abs(value) < 0.0000005 else value
    return f"{value:.7f}"


def write_runtime(path, clips, source_sha):
    lines = ["extends RefCounted", "## Generated by Blender author_platform_clips.py; do not hand-edit.",
             f'const SOURCE_SHA256: String = "{source_sha}"',
             'const STRIDE_METRES = {"walk": 0.78, "sprint": 1.42}', "const CLIPS = {"]
    for name, data in clips.items():
        lines.append(f'\t"{name}": {{"duration": {data["duration"]}, "loop": {str(data["loop"]).lower()}, "rotations": {{')
        for bone in BONES:
            values = ["Quaternion(%s)" % ", ".join(gd_number(x) for x in (q.x, q.y, q.z, q.w)) for q in data["rotations"][bone]]
            lines.append(f'\t\t"{bone}": [{", ".join(values)}],')
        values = ["Vector3(%s)" % ", ".join(gd_number(x) for x in p) for p in data["pelvis"]]
        lines.append('\t}, "pelvis": [' + ", ".join(values) + "]},")
    lines.append("}\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines))


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = 720, 840
    scene.render.resolution_percentage = 100
    if scene.world is None:
        scene.world = bpy.data.worlds.new("StudioWorld")
    scene.world.color = (0.12, 0.16, 0.23)
    scene.view_settings.view_transform = "AgX"
    mat = bpy.data.materials.new("StudioFloor")
    mat.diffuse_color = (0.055, 0.085, 0.12, 1)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.004))
    bpy.context.object.data.materials.append(mat)
    for location, energy, size in [((3, -4, 6), 700, 5), ((-3, -2, 3), 400, 4), ((1, 3, 4), 900, 3)]:
        lamp = bpy.data.lights.new("StudioSoftbox", "AREA")
        lamp.energy, lamp.shape, lamp.size = energy, "DISK", size
        obj = bpy.data.objects.new(lamp.name, lamp)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("StudioCamera")
    camera = bpy.data.objects.new("StudioCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (2.6, -4.6, 2.0)
    camera.rotation_euler = (Vector((0, 0, 0.88)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type, camera_data.ortho_scale = "ORTHO", 2.35
    scene.camera = camera


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source, runtime, evidence = map(Path, [args.input, args.runtime, args.evidence])
    evidence.mkdir(parents=True, exist_ok=True)
    source_sha = digest(source)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source.resolve()), merge_vertices=False)
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1
    rig = rigs[0]
    assert len(rig.data.bones) == 65
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    assert len(meshes) == 1
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    originals = sorted(a.name for a in bpy.data.actions)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    idle = next(a for a in bpy.data.actions if a.name.startswith("idle_"))
    rig.animation_data.action = idle
    bpy.context.scene.frame_set(0)
    update()
    author = Author(rig)
    clips, actions, foot_stats, pose_references = {}, [], {}, {}
    scene = bpy.context.scene
    scene.render.fps = 60
    for name, (duration, loop) in CLIPS.items():
        action = bpy.data.actions.new("studio_" + name)
        action.use_fake_user = True
        rig.animation_data.action = action
        actions.append(action)
        data = {"duration": duration, "loop": loop, "rotations": {n: [] for n in BONES}, "pelvis": []}
        feet = []
        for frame in range(SAMPLES):
            progress = frame / (SAMPLES - 1)
            scene.frame_set(frame)
            author.pose(name, progress)
            for bone in BONES:
                data["rotations"][bone].append(author.exported_rotation(bone))
                pose = rig.pose.bones[bone]
                pose.keyframe_insert("rotation_quaternion", frame=progress * duration * 60, group=bone)
                pose.keyframe_insert("location", frame=progress * duration * 60, group=bone)
            offset = rig.pose.bones["Pelvis"].head - author.global_neutral["Pelvis"].translation
            data["pelvis"].append(C.inverted() @ offset)
            feet.append({side: list(C.inverted() @ rig.pose.bones["Foot." + side].head) for side in ["L", "R"]})
        clips[name] = data
        pose_references[name] = feet
        foot_stats[name] = {side: {"min_y": min(f[side][1] for f in feet), "max_y": max(f[side][1] for f in feet), "min_x": min(f[side][0] for f in feet), "max_x": max(f[side][0] for f in feet)} for side in ["L", "R"]}
    write_runtime(runtime, clips, source_sha)
    bpy.data.libraries.write(str(evidence / "Lumo-Studio-Actions.blend"), set(actions), fake_user=True, compress=True)
    report = {"blender": bpy.app.version_string, "source": str(source), "source_sha256": source_sha, "source_unchanged": digest(source) == source_sha,
              "bones": 65, "original_clips_preserved": originals, "clips": list(clips), "samples_per_clip": SAMPLES,
              "runtime_sha256": digest(runtime), "runtime_bytes": runtime.stat().st_size,
              "maximum_ik_endpoint_error_metres": author.max_leg_error, "foot_ranges_model_metres": foot_stats,
              "foot_keyframes_model_metres": pose_references,
              "geometry_modified": False, "facial_rig_added": False, "physical_android_measured": False, "renders": []}
    assert report["source_unchanged"] and author.max_leg_error < 0.003
    (evidence / "motion_build.json").write_text(json.dumps(report, indent=2) + "\n")
    if args.render:
        setup_render()
        for name, progress in [("walk", 0.17), ("sprint", 0.17), ("jump_rise", 0.65), ("land", 0.5)]:
            rig.animation_data.action = None
            author.pose(name, progress)
            scene.render.filepath = str((evidence / (name + ".png")).resolve())
            bpy.ops.render.render(write_still=True)
            report["renders"].append({"file": name + ".png", "clip": name, "phase": progress, "engine": "Blender Cycles CPU"})
    (evidence / "motion_build.json").write_text(json.dumps(report, indent=2) + "\n")
    print("LUMO_STUDIO_MOTION=" + json.dumps(report))


if __name__ == "__main__":
    main()
