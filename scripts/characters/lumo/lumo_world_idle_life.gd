extends Node
## World-only life overlay for the original 65-bone Lumo.
## It runs after the normal idle clip and adds small, deterministic variation:
## breathing/sway, looking around and an occasional thinking head-scratch.
## Locomotion, collisions and the authored source model remain untouched.

const CYCLE_SECONDS := 13.0
const SCRATCH_START := 7.2
const SCRATCH_END := 9.7

var skeleton: Skeleton3D
var bones: Dictionary = {}
var active := false
var reduced_motion := false
var suspended := false
var clock := 0.0
var thinking_left := 0.0
var _base: Dictionary = {}
var _written: Dictionary = {}


func _init() -> void:
	name = "LumoWorldIdleLife"
	# Run after the character/AnimationPlayer so this is a non-destructive overlay.
	process_priority = 1000


func bind(target: Skeleton3D) -> bool:
	if target == null:
		return false
	for bone in [
		"Pelvis", "SpineLower", "SpineUpper", "Neck", "Head",
		"UpperArm.R", "Forearm.R", "Wrist.R", "Hand.R",
		"TailBase", "Tail1", "Tail2"
	]:
		var index := target.find_bone(bone)
		if index < 0:
			return false
		bones[bone] = index
	skeleton = target
	return true


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if not active:
		_restore()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value


func set_suspended(value: bool) -> void:
	suspended = value
	if value:
		_restore()


func think(seconds := 2.4) -> void:
	thinking_left = maxf(thinking_left, clampf(float(seconds), 0.5, 4.0))


func _process(delta: float) -> void:
	if not active or suspended or skeleton == null:
		return
	var dt := minf(maxf(delta, 0.0), 0.1)
	if dt <= 0.0:
		return
	clock = fposmod(clock + dt, CYCLE_SECONDS)
	thinking_left = maxf(0.0, thinking_left - dt)
	_restore_if_untouched()

	var calm := 0.42 if reduced_motion else 1.0
	var sway := sin(clock * 0.72) * 0.045 * calm
	var breathe := sin(clock * 1.16 + 0.7) * 0.022 * calm
	var look_wave := sin(clock * 0.43 + sin(clock * 0.17)) * 0.11 * calm
	_rotate("Pelvis", Vector3.FORWARD, sway * 0.16)
	_rotate("SpineLower", Vector3.FORWARD, -sway * 0.35)
	_rotate("SpineUpper", Vector3.FORWARD, sway * 0.55)
	_rotate("Neck", Vector3.UP, look_wave * 0.55)
	_rotate("Head", Vector3.UP, look_wave)
	_rotate("Head", Vector3.RIGHT, breathe)
	_rotate("TailBase", Vector3.UP, -look_wave * 0.55)
	_rotate("Tail1", Vector3.UP, sin(clock * 0.63 + 0.9) * 0.055 * calm)
	_rotate("Tail2", Vector3.UP, sin(clock * 0.63 + 1.6) * 0.045 * calm)

	var scratch_weight := 0.0
	if not reduced_motion:
		if thinking_left > 0.0:
			scratch_weight = smoothstep(0.0, 0.35, minf(0.35, thinking_left))
		elif clock >= SCRATCH_START and clock <= SCRATCH_END:
			var phase := (clock - SCRATCH_START) / (SCRATCH_END - SCRATCH_START)
			scratch_weight = smoothstep(0.0, 0.22, phase) * (1.0 - smoothstep(0.78, 1.0, phase))
	if scratch_weight > 0.001:
		_scratch_head(scratch_weight)

	for index in _base:
		_written[index] = skeleton.get_bone_pose_rotation(index)
	skeleton.force_update_all_bone_transforms()


func _scratch_head(weight: float) -> void:
	var upper := int(bones["UpperArm.R"])
	var fore := int(bones["Forearm.R"])
	var hand := int(bones["Hand.R"])
	_remember(upper)
	_remember(fore)
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(fore).origin
	var palm := skeleton.get_bone_global_pose(hand).origin
	var head_at := skeleton.get_bone_global_pose(int(bones.Head)).origin
	# Right paw to the right/top side of the head; tiny oscillation reads as a rub.
	var rub := sin(clock * 13.0) * 0.035
	var goal := head_at + Vector3(-0.24 + rub, 0.13, 0.035)
	goal = palm.lerp(goal, clampf(weight, 0.0, 1.0))
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(palm)
	var reach := clampf(
		shoulder.distance_to(goal),
		absf(upper_length - lower_length) + 0.002,
		(upper_length + lower_length) * 0.992
	)
	var direction := (goal - shoulder).normalized()
	var cos_a := clampf(
		(upper_length * upper_length + reach * reach - lower_length * lower_length)
			/ maxf(0.0001, 2.0 * upper_length * reach),
		-1.0,
		1.0
	)
	var pole := Vector3(-0.72, -0.30, -0.28)
	var across := pole - direction * pole.dot(direction)
	if across.length() < 0.001:
		across = Vector3.LEFT
	across = across.normalized()
	var new_elbow := shoulder + (
		direction * cos_a + across * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	) * upper_length
	_turn(upper, elbow - shoulder, new_elbow - shoulder)
	var moved_elbow := skeleton.get_bone_global_pose(fore).origin
	var moved_palm := skeleton.get_bone_global_pose(hand).origin
	_turn(fore, moved_palm - moved_elbow, goal - moved_elbow)
	_rotate("Head", Vector3.FORWARD, -0.045 * weight)


func _rotate(name: String, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.00001:
		return
	var index := int(bones[name])
	_remember(index)
	var base_rotation: Quaternion = _base[index]
	skeleton.set_bone_pose_rotation(index, (base_rotation * Quaternion(axis.normalized(), angle)).normalized())


func _remember(index: int) -> void:
	if not _base.has(index):
		_base[index] = skeleton.get_bone_pose_rotation(index)


func _restore_if_untouched() -> void:
	for index in _written:
		if not _base.has(index):
			continue
		var now := skeleton.get_bone_pose_rotation(index)
		if now.is_equal_approx(_written[index]):
			skeleton.set_bone_pose_rotation(index, _base[index])
	_base.clear()
	_written.clear()
	skeleton.force_update_all_bone_transforms()


func _restore() -> void:
	if skeleton == null:
		return
	_restore_if_untouched()
	_base.clear()
	_written.clear()


func _turn(index: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return
	var rotation := Quaternion(from.normalized(), to.normalized())
	var bone_basis := skeleton.get_bone_global_pose(index).basis.orthonormalized()
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := (
		skeleton.get_bone_global_pose(parent).basis.orthonormalized()
		if parent >= 0
		else Basis.IDENTITY
	)
	var local := (parent_basis.inverse() * (Basis(rotation) * bone_basis)).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, local.normalized())
	skeleton.force_update_all_bone_transforms()
