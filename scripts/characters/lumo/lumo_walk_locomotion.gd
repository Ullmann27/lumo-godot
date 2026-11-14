extends RefCounted
## 65-bone Lumo locomotion layer. It preserves the imported idle pose and
## samples Blender-authored IK clips on hips/knees/ankles/arms.
## This pose generator does NOT translate the character or modify collisions;
## the owning world must supply a real velocity / navigation position.
## The original rigid leg lengths are preserved. Uneven-terrain IK is separate.

const BODY_SPACE = preload("res://scripts/characters/lumo/lumo_body_space_pose.gd")

const REQUIRED: Array[String] = [
	"Pelvis", "SpineLower", "SpineUpper", "Neck", "Head",
	"Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R",
	"Toe.L", "Toe.R", "UpperArm.L", "UpperArm.R", "Forearm.L", "Forearm.R",
	"TailBase", "Tail1", "Tail2", "Tail3", "TailTip",
]

var skeleton: Skeleton3D
var indices: Dictionary = {}
var neutral_rotation: Dictionary = {}
var neutral_position: Dictionary = {}
var phase: float = 0.0
var stride_metres: float = 0.78
var body_space


func bind(source: Skeleton3D) -> bool:
	if not is_instance_valid(source):
		return false
	var found: Dictionary = {}
	for name in REQUIRED:
		var index: int = source.find_bone(name)
		if index < 0:
			return false
		found[name] = index
	skeleton = source
	indices = found
	neutral_rotation.clear()
	neutral_position.clear()
	for name in REQUIRED:
		var i: int = int(indices[name])
		neutral_rotation[name] = source.get_bone_pose_rotation(i)
		neutral_position[name] = source.get_bone_pose_position(i)
	phase = 0.0
	body_space = BODY_SPACE.new()
	return body_space.bind(source, indices)


func advance(delta: float, speed_metres_per_second: float) -> void:
	if skeleton == null or not is_finite(delta) or delta <= 0.0 or not is_finite(speed_metres_per_second) or speed_metres_per_second <= 0.0:
		return
	delta = minf(delta, 0.10)
	stride_metres = body_space.stride_metres()
	phase = fposmod(phase + delta * TAU * speed_metres_per_second / maxf(0.05, stride_metres), TAU)
	var cycle: float = phase / TAU
	var effort: float = clampf(speed_metres_per_second / 0.65, 0.0, 1.0)
	for name in REQUIRED:
		var rotation: Quaternion = Quaternion.IDENTITY.slerp(body_space.clip_rotation("walk", name, cycle), effort)
		skeleton.set_bone_pose_rotation(int(indices[name]), body_space.rotation_target(name, rotation))
	skeleton.set_bone_pose_position(
		int(indices.Pelvis), body_space.position_target("Pelvis", body_space.clip_pelvis("walk", cycle) * effort)
	)
	skeleton.force_update_all_bone_transforms()


func stop() -> void:
	if skeleton == null:
		return
	for name in indices:
		var index: int = int(indices[name])
		skeleton.set_bone_pose_rotation(index, neutral_rotation[name])
		skeleton.set_bone_pose_position(index, neutral_position[name])
	skeleton.force_update_all_bone_transforms()
