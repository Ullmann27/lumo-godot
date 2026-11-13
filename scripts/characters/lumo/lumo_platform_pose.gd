extends RefCounted
## One skeletal pose owner for the original fox in walking/platform worlds.
## Physics remains with the CharacterBody3D. Every pose uses the owner's real
## velocity and floor contact; root transforms and collider dimensions stay put.

const BODY_SPACE = preload("res://scripts/characters/lumo/lumo_body_space_pose.gd")

const BONES: Array[String] = [
	"Pelvis",
	"SpineLower",
	"SpineUpper",
	"Neck",
	"Head",
	"Thigh.L",
	"Thigh.R",
	"Shin.L",
	"Shin.R",
	"Foot.L",
	"Foot.R",
	"Toe.L",
	"Toe.R",
	"UpperArm.L",
	"UpperArm.R",
	"Forearm.L",
	"Forearm.R",
	"TailBase",
	"Tail1",
	"Tail2",
	"Tail3",
	"TailTip",
]
var skeleton: Skeleton3D
var indices: Dictionary = {}
var rotations: Dictionary = {}
var positions: Dictionary = {}
var phase: float = 0.0
var state: String = "idle"
var landing_left: float = 0.0
var landing_strength: float = 0.0
var last_vertical_speed: float = 0.0
var last_speed: float = 0.0
var was_grounded: bool = true
var has_sample: bool = false
var body_space


func bind(source: Skeleton3D) -> bool:
	if source == null:
		return false
	for bone in BONES:
		var index: int = source.find_bone(bone)
		if index < 0:
			return false
		indices[bone] = index
		rotations[bone] = source.get_bone_pose_rotation(index)
		positions[bone] = source.get_bone_pose_position(index)
	skeleton = source
	body_space = BODY_SPACE.new()
	if not body_space.bind(source, indices):
		return false
	has_sample = false
	landing_left = 0.0
	phase = 0.0
	return true


func advance(velocity: Vector3, grounded: bool, delta: float) -> void:
	if skeleton == null or delta <= 0.0 or not velocity.is_finite():
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if has_sample and grounded and not was_grounded:
		landing_left = 0.20
		landing_strength = clampf(-last_vertical_speed / 11.0, 0.25, 1.0)
	landing_left = maxf(0.0, landing_left - delta)
	var landing: float = sin(PI * landing_left / 0.20) * landing_strength
	var moving: bool = grounded and speed > 0.06
	var running: float = clampf((speed - 2.0) / 3.5, 0.0, 1.0)
	if moving:
		# Advance by distance, with a longer stride at running speed.
		phase = fposmod(phase + delta * TAU * speed / lerpf(0.82, 1.65, running), TAU)
	var effort: float = clampf(speed / 2.0, 0.0, 1.0)
	var acceleration: float = clampf((speed - last_speed) / delta / 30.0, -1.0, 1.0)
	var air_tuck: float = clampf(velocity.y / 8.5, -0.35, 1.0) if not grounded else 0.0
	var blend: float = 1.0 - exp(-18.0 * delta)
	state = (
		("jump_rise" if velocity.y > 0.35 else "jump_fall")
		if not grounded
		else (
			"land"
			if landing_left > 0.0
			else ("run_loop" if speed >= 3.2 else ("walk_loop" if moving else "idle"))
		)
	)
	for side in ["L", "R"]:
		var swing: float = sin(phase + (0.0 if side == "L" else PI)) * effort if moving else 0.0
		var lift: float = pow(maxf(0.0, swing), 2.0)
		var thigh: float = -swing * lerpf(0.40, 0.62, running) - landing * 0.30
		var knee: float = lift * lerpf(0.52, 0.82, running) + landing * 0.54
		var ankle: float = swing * 0.24 - lift * 0.20 - landing * 0.23
		var arm: float = swing * lerpf(0.28, 0.55, running)
		if not grounded:
			thigh = -0.28 - 0.20 * maxf(air_tuck, 0.0)
			knee = 0.48 + 0.36 * maxf(air_tuck, 0.0)
			ankle = -0.18
			arm = -0.52 + air_tuck * 0.18
		_rotate("Thigh." + side, Vector3.RIGHT, thigh, blend)
		_rotate("Shin." + side, Vector3.RIGHT, knee, blend)
		_rotate("Foot." + side, Vector3.RIGHT, ankle, blend)
		_rotate("Toe." + side, Vector3.RIGHT, maxf(0.0, -swing) * 0.16, blend)
		_rotate("UpperArm." + side, Vector3.RIGHT, arm, blend)
		_rotate("Forearm." + side, Vector3.RIGHT, -0.18 * running - landing * 0.10, blend)
		_position("Foot." + side, Vector3.UP * lift * 0.04, blend)
	var lean: float = -0.08 * running - acceleration * 0.12 + landing * 0.16
	_rotate("SpineLower", Vector3.RIGHT, lean, blend)
	_rotate("SpineUpper", Vector3.UP, sin(phase * 2.0) * effort * 0.045 if grounded else 0.0, blend)
	_rotate("Neck", Vector3.RIGHT, -lean * 0.65, blend)
	_rotate("Head", Vector3.RIGHT, -lean * 0.35 + air_tuck * 0.06, blend)
	for index in range(5):
		var bone: String = ["TailBase", "Tail1", "Tail2", "Tail3", "TailTip"][index]
		_rotate(
			bone,
			Vector3.UP,
			sin(phase - float(index) * 0.48) * effort * 0.07 if grounded else 0.03 * air_tuck,
			blend
		)
	_position(
		"Pelvis", Vector3.UP * ((1.0 - cos(phase * 2.0)) * effort * 0.014 - landing * 0.075), blend
	)
	skeleton.force_update_all_bone_transforms()
	last_vertical_speed = velocity.y
	last_speed = speed
	was_grounded = grounded
	has_sample = true


func stop() -> void:
	if not is_instance_valid(skeleton):
		return
	for bone in indices:
		var index: int = int(indices[bone])
		skeleton.set_bone_pose_rotation(index, rotations[bone])
		skeleton.set_bone_pose_position(index, positions[bone])
	skeleton.force_update_all_bone_transforms()
	has_sample = false
	landing_left = 0.0


func _rotate(bone: String, axis: Vector3, angle: float, blend: float) -> void:
	var index: int = int(indices[bone])
	var target: Quaternion = body_space.rotation_target(bone, Quaternion(axis, angle))
	skeleton.set_bone_pose_rotation(
		index, skeleton.get_bone_pose_rotation(index).slerp(target, blend)
	)


func _position(bone: String, offset: Vector3, blend: float) -> void:
	var index: int = int(indices[bone])
	var target: Vector3 = body_space.position_target(bone, offset)
	skeleton.set_bone_pose_position(
		index, skeleton.get_bone_pose_position(index).lerp(target, blend)
	)
