extends RefCounted
## 65-bone Lumo locomotion layer. It preserves the imported idle pose and
## articulates hips/knees/ankles/arms, including alternating swing clearance.
## This pose generator does NOT translate the character or modify collisions;
## the owning world must supply a real velocity / navigation position.
## Foot planting against non-flat terrain needs a separate ground-contact IK.

const REQUIRED: Array[String] = [
	"Thigh.L", "Thigh.R", "Shin.L", "Shin.R",
	"Foot.L", "Foot.R", "Toe.L", "Toe.R",
	"UpperArm.L", "UpperArm.R", "SpineLower", "Pelvis",
]

var skeleton: Skeleton3D
var indices: Dictionary = {}
var neutral_rotation: Dictionary = {}
var neutral_position: Dictionary = {}
var phase: float = 0.0
var stride_metres: float = 0.73


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
	return true


func advance(delta: float, speed_metres_per_second: float) -> void:
	if skeleton == null or delta <= 0.0 or speed_metres_per_second <= 0.0:
		return
	var pace: float = clampf(speed_metres_per_second / stride_metres, 0.65, 3.5)
	phase = fposmod(phase + delta * TAU * pace, TAU)
	var effort: float = clampf(speed_metres_per_second / 1.7, 0.4, 1.2)
	for side in ["L", "R"]:
		var offset: float = 0.0 if side == "L" else PI
		var step: float = phase + offset
		var swing: float = sin(step)
		var clearance: float = pow(maxf(0.0, swing), 2.0)
		# Positive knee bend lifts the advancing foot; opposite leg supports.
		_rotate("Thigh." + side, Vector3.RIGHT, -0.38 * swing * effort)
		_rotate("Shin." + side, Vector3.RIGHT, 0.12 + 0.48 * clearance * effort)
		_rotate("Foot." + side, Vector3.RIGHT,
			0.28 * swing * effort - 0.22 * clearance * effort)
		_rotate("Toe." + side, Vector3.RIGHT, 0.18 * maxf(0.0, -swing))
		_position("Foot." + side,
			Vector3(0.0, 0.045 * clearance * effort, 0.0))
		# Natural contralateral arm swing: left leg forwards, right arm forwards.
		_rotate("UpperArm." + side, Vector3.RIGHT, 0.26 * swing * effort)
	_rotate("SpineLower", Vector3.UP, 0.046 * sin(phase * 2.0))
	_position("Pelvis", Vector3(0.0,
		0.016 * (1.0 - cos(phase * 2.0)) * effort, 0.0))
	skeleton.force_update_all_bone_transforms()


func stop() -> void:
	if skeleton == null:
		return
	for name in indices:
		var index: int = int(indices[name])
		skeleton.set_bone_pose_rotation(index, neutral_rotation[name])
		skeleton.set_bone_pose_position(index, neutral_position[name])
	skeleton.force_update_all_bone_transforms()


func _rotate(name: String, axis: Vector3, radians: float) -> void:
	var index: int = int(indices[name])
	var rotation: Quaternion = neutral_rotation[name]
	skeleton.set_bone_pose_rotation(
		index, rotation * Quaternion(axis, radians)
	)


func _position(name: String, shift: Vector3) -> void:
	var index: int = int(indices[name])
	skeleton.set_bone_pose_position(index,
		neutral_position[name] + shift)
