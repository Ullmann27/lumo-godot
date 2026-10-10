extends Node3D
## Opt-in VISUAL test adapter only. It never writes speed, steering, collision,
## lap count, rewards, saves or physics state. Existing driver stays in production.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
var actor
var kart: Node3D
var steering := 0.0
var speed := 0.0
var airborne := false
var hit_amount := 0.0
var victory := false
var suspended := false
var elapsed := 0.0
var maximum_contact_error := 0.0
var _tick := 0.0
var _seated_leg_rotations: Dictionary = {}


func bind_visual(review_kart: Node3D) -> void:
	assert(actor == null and review_kart.get("steering_wheel") != null)
	kart = review_kart
	actor = ACTOR.new()
	# Fit the existing standalone character to the existing bucket seat.
	# One uniform visual scale only, never stretching limbs or chassis.
	actor.scale = Vector3.ONE * 1.15
	actor.position = Vector3(0, -0.05, 0.12)
	actor.rotation.y = PI
	add_child(actor)
	actor.behavior_finished.connect(_behavior_finished)
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.play_behavior("kart_seated")
	# Binding is an initial pose, not a crossfade from the stand-up idle.
	# Capturing before that blend settles would save standing leg rotations.
	actor.player.stop()
	actor.player.play("kart_seated", 0.0)
	actor.player.advance(0.0)
	actor.player.seek(0.3, true)
	actor.skeleton.force_update_all_bone_transforms()
	for side in ["L", "R"]:
		for part in ["Thigh.", "Shin.", "Foot.", "Toe.", "ToeTip."]:
			var index: int = actor.skeleton.find_bone(part + side)
			_seated_leg_rotations[index] = actor.skeleton.get_bone_pose_rotation(index)


func _behavior_finished(behavior: String) -> void:
	if behavior == "celebrate" and victory:
		victory = false
		actor.play_behavior("kart_seated")


func apply_vehicle_sample(velocity: float, steer: float, in_air: bool, hit: bool = false) -> void:
	# Callers supply real state. Do not infer a jump from elapsed time.
	speed = maxf(0.0, velocity) if is_finite(velocity) else 0.0
	steering = clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	airborne = in_air
	if hit:
		hit_amount = 1.0


func celebrate_finished_race() -> void:
	victory = true
	actor.play_behavior("celebrate")


func set_suspended(value: bool) -> void:
	suspended = value
	if actor != null:
		actor.set_suspended(value)


func _process(delta: float) -> void:
	if actor == null or suspended:
		return
	_tick += delta
	if _tick < 1.0 / 30.0:
		return
	var step := minf(_tick, 0.10)
	_tick = 0.0
	advance_visual(step)


func advance_visual(delta: float) -> void:
	if actor == null or suspended or not is_finite(delta) or delta < 0.0:
		return
	elapsed += delta
	hit_amount = move_toward(hit_amount, 0.0, delta * 2.5)
	if victory:
		actor.player.advance(delta)
		# The existing stand-up cheer provides the upper body; preserve the
		# actual seated legs instead of dropping boots through the chassis.
		for index in _seated_leg_rotations:
			actor.skeleton.set_bone_pose_rotation(index, _seated_leg_rotations[index])
		actor.skeleton.force_update_all_bone_transforms()
		return
	var clip := "kart_jump" if airborne else "kart_seated"
	if actor.current_behavior != clip:
		actor.play_behavior(clip)
	actor.player.advance(delta)
	var skeleton: Skeleton3D = actor.skeleton
	var chest: int = skeleton.find_bone("Chest")
	var head: int = skeleton.find_bone("Head")
	# These deltas affect only the visual skeleton, not the chassis.
	skeleton.set_bone_pose_rotation(chest, skeleton.get_bone_pose_rotation(chest) *
		Quaternion(Vector3.FORWARD, steering * -0.055 + hit_amount * 0.07))
	skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) *
		Quaternion(Vector3.UP, steering * 0.07))
	skeleton.force_update_all_bone_transforms()
	maximum_contact_error = 0.0
	for i in range(2):
		var side := "L" if i == 0 else "R"
		var wheel: Node3D = kart.get("steering_wheel")
		var anchors: Array = kart.get("wheel_rest_grips")
		var target: Vector3 = skeleton.to_local(wheel.to_global(anchors[i]))
		maximum_contact_error = maxf(maximum_contact_error, _solve_hand(side, target))
	_curl_fingers()


func _curl_fingers() -> void:
	# Modest glove curl, not a validated finger/rim collision constraint.
	# The single source mesh has finger bones but no separate hand colliders.
	var skeleton: Skeleton3D = actor.skeleton
	for index in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(index)
		if not name.begins_with("Finger_"):
			continue
		var number := int(name.trim_prefix("Finger_"))
		var thumb := number in [33, 34, 35, 36, 49, 50, 51, 52]
		var axis := skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.RIGHT
		skeleton.set_bone_pose_rotation(
			index,
			skeleton.get_bone_pose_rotation(index) * Quaternion(axis.normalized(), -0.18 if thumb else -0.48)
		)
	skeleton.force_update_all_bone_transforms()


func _solve_hand(side: String, target: Vector3) -> float:
	var skeleton: Skeleton3D = actor.skeleton
	var end: int = skeleton.find_bone("Hand." + side)
	# Most poses converge early; near-full extension needs more iterations
	# during continuous steering, not only the static left/right end poses.
	for iteration in range(64):
		var tip: Vector3 = skeleton.get_bone_global_pose(end).origin
		if tip.distance_to(target) <= 0.001:
			break
		for joint_name in ["Wrist.", "Forearm.", "UpperArm.", "Clavicle."]:
			var joint: int = skeleton.find_bone(joint_name + side)
			var origin: Vector3 = skeleton.get_bone_global_pose(joint).origin
			var a: Vector3 = skeleton.get_bone_global_pose(end).origin - origin
			var b: Vector3 = target - origin
			if a.length_squared() < 0.0000001 or b.length_squared() < 0.0000001:
				continue
			var delta := Quaternion(a.normalized(), b.normalized())
			var parent: int = skeleton.get_bone_parent(joint)
			var frame: Quaternion = (
				skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
				* skeleton.get_bone_rest(joint).basis.get_rotation_quaternion()
			)
			var local_delta := frame.inverse() * delta * frame
			skeleton.set_bone_pose_rotation(joint, local_delta * skeleton.get_bone_pose_rotation(joint))
			skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(end).origin).distance_to(
		skeleton.to_global(target))
