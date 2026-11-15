"""Reproducible, editable Blender production for LUMO next-generation learning.

Reuses the already licensed Lumo-Animated-Mobile.glb; no foreign assets, no
external paid service. The legacy source model is NEVER edited in place.

Run: blender -b -t 2 --python tools/lumo_nextgen_chat3/build_blender_assets.py --
     --source assets/characters/lumo_animated/Lumo-Animated-Mobile.glb
     --output exports/lumo-nextgen-chat3
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

FPS = 30
CLIPS = {
    "learn_idle_breathe": (4.1, True),
    "learn_listen": (3.8, True),
    "learn_think": (2.4, True),
    "learn_explain": (2.5, True),
    "learn_point": (1.75, False),
    "learn_nod": (1.25, False),
    "learn_unsure": (1.8, False),
    "learn_encourage": (1.6, False),
    "learn_celebrate": (1.7, False),
    "learn_interrupt": (0.45, False),
    "learn_return_listen": (0.75, False),
    "learn_farewell": (1.8, False),
}
FACE_KEYS = {
    "viseme_A": (0.105, 0.088, 0.079, 0.066, 0.000),
    "viseme_E": (0.143, 0.040, 0.120, 0.017, 0.005),
    "viseme_I": (0.125, 0.035, 0.100, 0.012, 0.003),
    "viseme_O": (0.075, 0.086, 0.055, 0.065, 0.000),
    "viseme_U": (0.057, 0.049, 0.035, 0.028, 0.000),
    "viseme_MBP": (0.122, 0.020, 0.090, 0.003, 0.003),
    "viseme_FV": (0.115, 0.033, 0.086, 0.010, 0.002),
    "viseme_L": (0.124, 0.056, 0.092, 0.035, 0.000),
    "expression_smile": (0.149, 0.034, 0.108, 0.012, 0.022),
    "expression_surprise": (0.075, 0.098, 0.052, 0.077, 0.000),
}
CONTROL_BONES = (
    "Root", "Chest", "SpineUpper", "Head",
    "UpperArm.L", "Forearm.L", "Hand.L",
    "UpperArm.R", "Forearm.R", "Hand.R",
    "TailBase", "Tail1", "Tail2", "Tail3", "TailTip",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def material(name: str, rgba, roughness: float = 0.65, metallic: float = 0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = tuple(rgba)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = tuple(rgba)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return m


def rigged_face_mesh(name, vertices_world, faces, rig, source_mesh, head_name, mats):
    # Match imported mesh space, then deform using the real Head bone.
    to_local = source_mesh.matrix_world.inverted()
    vertices = [tuple(to_local @ Vector(v)) for v in vertices_world]
    dat = bpy.data.meshes.new(name + "_geometry")
    dat.from_pydata(vertices, [], faces)
    dat.update()
    obj = bpy.data.objects.new(name, dat)
    bpy.context.scene.collection.objects.link(obj)
    obj.matrix_world = source_mesh.matrix_world.copy()
    for m in mats:
        obj.data.materials.append(m)
    group = obj.vertex_groups.new(name=head_name)
    group.add(list(range(len(vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("FollowOriginalHead", "ARMATURE")
    mod.object = rig
    return obj


def face_overlay(rig, source_mesh, mats):
    """Fit controls to the existing animal face; no detached face rings.

    A resting mouth and both unclosed eyelids are recessed INSIDE the
    original fox mesh. The external surfaces only appear with a requested
    timed viseme or blink; the native original artwork remains intact.
    """
    bone = rig.data.bones["Head"]
    head_z = (rig.matrix_world @ bone.head_local).z
    all_points = [source_mesh.matrix_world @ v.co
                  for v in source_mesh.data.vertices]
    face_z = head_z + 0.037

    def front_surface(x, z, half_width, half_height):
        hits = [p.y for p in all_points
                if abs(p.x - x) <= half_width
                and abs(p.z - z) <= half_height]
        assert len(hits) >= 3, (
            f"Cannot locate original face surface at x={x} z={z}")
        return min(hits)

    mouth_front = front_surface(0.0, face_z, 0.042, 0.027) - 0.008
    segments = 24

    def ellipse(ax, az, ix, iz, smile=0.0, front_y=mouth_front):
        verts = []
        for radius_x, radius_z in ((ax, az), (ix, iz)):
            for j in range(segments):
                theta = 2 * math.pi * j / segments
                x = radius_x * math.cos(theta)
                z = radius_z * math.sin(theta) + smile * abs(math.cos(theta))
                verts.append((x, front_y, face_z + z))
        verts.append((0.0, front_y + 0.001, face_z))
        return verts

    # This small neutral basis is entirely recessed; no permanent pink
    # oval is permitted to float below the chin in a Blender front render.
    basis = ellipse(0.035, 0.008, 0.023, 0.002,
                    front_y=mouth_front + 0.135)
    faces = []
    for j in range(segments):
        k = (j + 1) % segments
        faces.append((j, k, segments + k, segments + j))
        faces.append((segments + j, segments + k, 2 * segments))
    obj = rigged_face_mesh("MouthVisemes", basis, faces, rig, source_mesh, "Head",
                           [mats["lip"], mats["mouth_inner"]])
    for poly in obj.data.polygons:
        poly.material_index = 0 if poly.index % 2 == 0 else 1
    obj.shape_key_add(name="Basis", from_mix=False)
    to_local = source_mesh.matrix_world.inverted()
    for key, dimensions in FACE_KEYS.items():
        morph = obj.shape_key_add(name=key, from_mix=False)
        ax, az, ix, iz, smile = dimensions
        # Size for the original narrow fox muzzle, not a wide human mouth.
        world_mouth = ellipse(
            ax * 0.63, az * 0.68, ix * 0.63, iz * 0.68,
            smile * 0.48, front_y=mouth_front)
        for i, world_position in enumerate(world_mouth):
            morph.data[i].co = to_local @ Vector(world_position)

    for side, sign in (("Left", -1), ("Right", 1)):
        cx = sign * 0.110
        lid_z = head_z + 0.255
        eye_front = front_surface(cx, lid_z, 0.025, 0.030) - 0.008
        lid_world = []
        for j in range(12):
            x = (j / 11.0 - 0.5) * 0.135
            crest = 0.012 - 0.012 * (x / 0.0675) ** 2
            lid_world.append((cx + x, eye_front + 0.17, lid_z + crest))
        lid_world += [(x, y + 0.002, z - 0.009) for x, y, z in lid_world]
        quads = [(j, j + 1, j + 13, j + 12) for j in range(11)]
        lid = rigged_face_mesh("Eyelid" + side, lid_world, quads, rig,
                               source_mesh, "Head", [mats["lid"]])
        lid.shape_key_add(name="Basis", from_mix=False)
        closed = lid.shape_key_add(name="blink", from_mix=False)
        for i, position in enumerate(lid_world):
            x, _, z = position
            closed_y = eye_front - (0.007 if i < 12 else 0.010)
            closed_z = z - (0.062 if i < 12 else 0.095)
            closed.data[i].co = to_local @ Vector((x, closed_y, closed_z))
    return obj, {
        "head_z": head_z, "face_z": face_z, "mouth_front_y": mouth_front,
        "neutral_controls_recessed_inside_head": True,
        "morphs": list(FACE_KEYS), "eyelid_morph": "blink",
    }


def create_actions(rig):
    required = [bone for bone in CONTROL_BONES if bone in rig.pose.bones]
    assert "Head" in required and "TailBase" in required
    rig.animation_data_create()
    created = []
    for name, (duration, loop) in CLIPS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        total = round(duration * FPS)
        for frame in sorted(set(list(range(1, total + 2, 3)) + [total + 1])):
            t = min(1.0, (frame - 1) / total)
            wave = math.sin(t * math.tau)
            envelope = math.sin(math.pi * t)
            values = {key: (0.0, 0.0, 0.0) for key in required}
            values["Chest"] = (0.011 * wave, 0, 0)
            values["Head"] = (0.017 * math.sin(t * math.tau + 0.3), 0.018 * wave, 0)
            values["TailBase"] = (0, 0, 0.06 * math.sin(2 * math.pi * t))
            values["Tail1"] = (0, 0, 0.04 * math.sin(2 * math.pi * t - 0.6))
            if name == "learn_listen":
                values["Head"] = (0.035 * wave, -0.055 + 0.012 * math.cos(t * math.tau), 0)
            elif name == "learn_think":
                values["Head"] = (-0.055 * envelope, 0.07 * envelope, 0.065 * envelope)
                values["UpperArm.R"] = (0, -0.42 * envelope, -0.07 * envelope)
            elif name in ("learn_explain", "learn_point"):
                swing = (0.32 + 0.10 * math.sin(t * math.tau * 2)) if name == "learn_explain" else 0.82 * envelope
                values["UpperArm.L"] = (0, -swing, 0)
                values["Forearm.L"] = (0.06 * envelope, -0.23 * envelope, 0)
                values["Head"] = (-0.025, -0.06 * envelope, 0)
            elif name == "learn_nod":
                values["Head"] = (0.17 * math.sin(t * math.tau * 2) * envelope, 0, 0)
            elif name == "learn_unsure":
                values["Head"] = (-0.05 * envelope, 0, 0.105 * envelope)
                values["UpperArm.R"] = (0, -0.29 * envelope, -0.12 * envelope)
            elif name == "learn_encourage":
                values["UpperArm.L"] = (0, -0.36 * envelope, 0)
                values["Head"] = (-0.07 * envelope, -0.02, 0)
            elif name == "learn_celebrate":
                values["UpperArm.L"] = (0, -1.03 * envelope, 0)
                values["UpperArm.R"] = (0, 0.96 * envelope, 0)
                values["TailBase"] = (0, 0, 0.21 * math.sin(t * 4 * math.pi) * envelope)
                values["Head"] = (-0.12 * envelope, 0, 0)
            elif name == "learn_interrupt":
                values["Head"] = (0.07 * envelope, 0, 0)
                values["UpperArm.L"] = (0, -0.16 * envelope, 0)
            elif name == "learn_return_listen":
                values["Head"] = (0.0, -0.045 * envelope, 0)
            elif name == "learn_farewell":
                values["UpperArm.R"] = (0, 1.07 * envelope, 0)
                values["Forearm.R"] = (0, -0.15 * envelope, 0.19 * wave * envelope)
            for bone_name, (x, y, z) in values.items():
                p = rig.pose.bones[bone_name]
                p.rotation_mode = "QUATERNION"
                p.rotation_quaternion = (
                    Quaternion((1, 0, 0), x) @
                    Quaternion((0, 1, 0), y) @
                    Quaternion((0, 0, 1), z)
                )
                p.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
        if loop:
            # Blender retains the actual independent Action for editable cycles.
            action["loop_requested"] = True
        created.append(name)
    rig.animation_data.action = bpy.data.actions.get("learn_idle_breathe")
    return created


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_preview(mats, avatar_collection):
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=1.05, depth=0.11,
                                        location=(0.0, 0.0, -0.09))
    podium = bpy.context.object
    podium.name = "PreviewOnly_Podium"
    podium.data.materials.append(mats["podium"])
    bpy.ops.object.shade_smooth()
    for loc, power, size in [
        ((-2.5, -3.0, 4.0), 550, 3.0),
        ((2.2, -0.2, 3.3), 440, 2.6),
        ((0.4, 3.0, 3.1), 380, 2.7),
    ]:
        data = bpy.data.lights.new("PreviewOnly_Softbox", "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(obj)
        obj.location = loc
        look_at(obj, (0, 0, 1.0))
    bpy.ops.object.camera_add(location=(2.8, -4.7, 2.15))
    camera = bpy.context.object
    camera.name = "PreviewOnly_Camera"
    look_at(camera, (0, 0, 0.96))
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.5
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("LumoPreviewWorld")
    scene.world.color = (0.06, 0.05, 0.12)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    # Ubuntu's packaged Blender Cycles may be compiled without OpenImageDenoise.
    # Disable denoising explicitly; render native Cycles samples instead.
    for layer in scene.view_layers:
        if hasattr(layer, "cycles"):
            layer.cycles.use_denoising = False
    if hasattr(scene.cycles, "use_preview_denoising"):
        scene.cycles.use_preview_denoising = False
    scene.render.fps = FPS
    return camera


def build_character(source, output):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=False)
    rigs = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1, "One existing character rig expected"
    rig = rigs[0]
    assert "Head" in rig.pose.bones and "TailBase" in rig.pose.bones
    skinned = [o for o in bpy.data.objects if o.type == "MESH"
               and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    assert len(skinned) == 1, "One original skinned mesh expected"
    source_mesh = skinned[0]
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o is not source_mesh:
            # GLTF import occasionally adds Blender-only bone-display meshes.
            bpy.data.objects.remove(o, do_unlink=True)
    mats = {
        "lip": material("LumoFace_RoseOuter", (0.40, 0.14, 0.16, 1), 0.70),
        "mouth_inner": material("LumoFace_MouthInner", (0.10, 0.032, 0.047, 1), 0.84),
        "lid": material("LumoFace_OrangeEyelid", (0.76, 0.39, 0.15, 1), 0.83),
        "podium": material("LumoStage_MoonStone", (0.27, 0.20, 0.47, 1), 0.40),
    }
    face, metadata = face_overlay(rig, source_mesh, mats)
    created = create_actions(rig)
    # Preview elements must not leak into the runtime avatar GLB.
    bpy.ops.object.select_all(action="DESELECT")
    avatar_objects = [rig, source_mesh] + [
        o for o in bpy.data.objects if o.name.startswith("MouthVisemes")
        or o.name.startswith("Eyelid")
    ]
    for o in avatar_objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    glb = output / "Lumo-Learning-Animated.glb"
    op = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kwargs = {
        "filepath": str(glb), "export_format": "GLB",
        "use_selection": True, "export_animations": True,
        "export_force_sampling": True, "export_yup": True,
        "export_morph": True,
    }
    if "export_animation_mode" in op:
        kwargs["export_animation_mode"] = "ACTIONS"
    if "export_anim_single_armature" in op:
        kwargs["export_anim_single_armature"] = True
    bpy.ops.export_scene.gltf(**kwargs)
    camera = setup_preview(mats, avatar_objects)
    rig.animation_data.action = bpy.data.actions["learn_idle_breathe"]
    bpy.context.scene.frame_set(1)
    blend = output / "Lumo-Learning-Animated.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    shots = {
        "front": (0.0, -5.4, 2.00),
        "three_quarter": (2.9, -4.7, 2.15),
        "side": (5.6, 0, 1.90),
        "back": (0.0, 5.4, 1.95),
    }
    for name, loc in shots.items():
        camera.location = loc
        look_at(camera, (0, 0, 0.96))
        bpy.context.scene.render.filepath = str(output / ("Blender_Lumo_" + name + ".png"))
        bpy.ops.render.render(write_still=True)
    return {
        "source_sha256": sha256(source),
        "legacy_rig_bones": len(rig.data.bones),
        "original_mesh_preserved": True,
        "additional_clips": created,
        "existing_actions_retained": [a.name for a in bpy.data.actions if a.name not in CLIPS],
        "face": metadata,
        "blend_sha256": sha256(blend), "glb_sha256": sha256(glb),
        "glb_bytes": glb.stat().st_size,
        "blender_version": bpy.app.version_string,
        "android_tested": False,
        "true_lipsync_tested": False,
    }


def mesh_prop(kind, name, color, location, radius=0.16):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                             radius=radius, location=location)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=radius * 2, location=location)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius,
                                            depth=radius * 0.42, location=location)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=radius, radius2=radius,
                                        depth=0.06, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(color)
    for poly in obj.data.polygons:
        poly.use_smooth = kind != "cube"
    if kind in ("cube", "cylinder"):
        bevel = obj.modifiers.new("SoftChildSafeEdges", "BEVEL")
        bevel.width = radius * 0.14
        bevel.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def build_kit(output):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    orange = material("CounterBerry_Coral", (0.91, 0.24, 0.17, 1), 0.38)
    mint = material("Shape_Mint", (0.20, 0.79, 0.57, 1), 0.48)
    violet = material("Shape_Violet", (0.51, 0.34, 0.90, 1), 0.42)
    gold = material("Shape_Gold", (1.0, 0.76, 0.21, 1), 0.36)
    cream = material("Tile_Cream", (0.98, 0.88, 0.67, 1), 0.60)
    blue = material("Stage_LakeBlue", (0.12, 0.29, 0.48, 1), 0.55)
    mesh_prop("sphere", "CounterBerry", orange, (-1.2, 0.0, 0.24), 0.15)
    mesh_prop("cube", "LetterTile", cream, (-0.6, 0.0, 0.25), 0.22)
    rod = mesh_prop("cube", "TenBundle", mint, (0.0, 0.0, 0.26), 0.17)
    rod.scale = (1.0, 0.55, 3.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mesh_prop("cylinder", "ShapeCircle", gold, (0.6, 0.0, 0.23), 0.19)
    mesh_prop("cube", "ShapeSquare", violet, (1.20, 0.0, 0.23), 0.19)
    mesh_prop("cone", "ShapeTriangle", mint, (1.80, 0.0, 0.23), 0.23)
    mesh_prop("cube", "TenFrameCell", cream, (0.0, 1.0, 0.08), 0.18)
    mesh_prop("cylinder", "LearningPodium", blue, (0.0, 1.90, -0.04), 1.05)
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "Lumo-Learning-Objects.blend"))
    glb = output / "Lumo-Learning-Objects.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB",
                               export_animations=False, export_yup=True)
    return {"asset_names": [
        "CounterBerry", "LetterTile", "TenBundle",
        "ShapeCircle", "ShapeSquare", "ShapeTriangle",
        "TenFrameCell", "LearningPodium"],
        "blend_sha256": sha256(output / "Lumo-Learning-Objects.blend"),
        "glb_sha256": sha256(glb),
        "glb_bytes": glb.stat().st_size}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = args.source.resolve()
    first_hash = sha256(source)
    character = build_character(source, output)
    kit = build_kit(output)
    assert sha256(source) == first_hash, "Source GLB was unexpectedly modified"
    report = {"character": character, "objects": kit,
              "coordinate_system": "Blender Z-up meters; glTF exported Y-up",
              "source_rights": "Retains Meshy CC BY 4.0 original, see assets/characters/lumo_animated/ATTRIBUTION.md",
              "generated_assets": "Original scripted geometry, own actions, no external assets"}
    (output / "production-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("LUMO_CHAT3_BUILD_PASS " + json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
