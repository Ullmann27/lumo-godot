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
	if skeleton == null or not is_finite(delta) or delta <= 0.0 or not velocity.is_finite():
		return
	delta = minf(delta, 0.10)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if has_sample and grounded and not was_grounded:
		landing_left = 0.20
		landing_strength = clampf(-last_vertical_speed / 11.0, 0.25, 1.0)
	landing_left = maxf(0.0, landing_left - delta)
	var moving: bool = grounded and speed > 0.06
	var running: float = clampf((speed - 2.0) / 3.5, 0.0, 1.0)
	if moving:
		# Blender's foot trajectories and this phase use the same stride length.
		# Character scaling is included; a small teacher takes shorter steps.
		phase = fposmod(phase + delta * TAU * speed / maxf(0.05, body_space.stride_metres(running)), TAU)
	var effort: float = clampf(speed / 0.65, 0.0, 1.0)
	var braking: float = clampf((last_speed - speed) / delta / 32.0, 0.0, 1.0) if grounded else 0.0
	var blend: float = 1.0 - exp(-22.0 * delta)
	var cycle: float = phase / TAU
	var land_phase: float = 1.0 - landing_left / 0.20
	var air_phase: float = (
		clampf(1.0 - velocity.y / 8.5, 0.0, 1.0)
		if velocity.y > 0.35 else clampf(-velocity.y / 11.0, 0.0, 1.0)
	)
	state = (
		("jump_rise" if velocity.y > 0.35 else "jump_fall")
		if not grounded else (
			"land" if landing_left > 0.0 else
			("run_loop" if speed >= 3.2 else ("walk_loop" if moving else "idle"))
		)
	)
	for bone in BONES:
		var body_delta := Quaternion.IDENTITY
		if not grounded:
			body_delta = body_space.clip_rotation(state, bone, air_phase)
		elif moving:
			body_delta = Quaternion.IDENTITY.slerp(
				body_space.clip_rotation("walk", bone, cycle).slerp(
					body_space.clip_rotation("sprint", bone, cycle), running
				), effort
			)
		if grounded and landing_left > 0.0:
			body_delta = body_delta.slerp(body_space.clip_rotation("land", bone, land_phase), landing_strength)
		elif braking > 0.02:
			body_delta = body_delta.slerp(body_space.clip_rotation("brake", bone, 0.5), braking * 0.65)
		var index: int = int(indices[bone])
		var target: Quaternion = body_space.rotation_target(bone, body_delta)
		skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(target, blend))
	# Only the pelvis translates. Leg segment lengths and toe offsets remain
	# exactly those of the original skin; feet lift through joint articulation.
	var pelvis := Vector3.ZERO
	if not grounded:
		pelvis = body_space.clip_pelvis(state, air_phase)
	elif moving:
		pelvis = body_space.clip_pelvis("walk", cycle).lerp(body_space.clip_pelvis("sprint", cycle), running) * effort
	if grounded and landing_left > 0.0:
		pelvis = pelvis.lerp(body_space.clip_pelvis("land", land_phase), landing_strength)
	elif braking > 0.02:
		pelvis = pelvis.lerp(body_space.clip_pelvis("brake", 0.5), braking * 0.65)
	var pelvis_index: int = int(indices.Pelvis)
	skeleton.set_bone_pose_position(
		pelvis_index,
		skeleton.get_bone_pose_position(pelvis_index).lerp(body_space.position_target("Pelvis", pelvis), blend)
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
