extends Node3D
## VISUAL adapter driven by the vehicle's existing motion and race state.
## It never writes speed, steering, collision, laps, rewards, saves or physics.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const VISUAL_TICK_SECONDS := 1.0 / 30.0
const MAX_VISUAL_STEP_SECONDS := 0.10
const TICK_EPSILON_SECONDS := 0.000000001
const ATTENTION_YAW_LIMIT := 0.28
const ATTENTION_PITCH_LIMIT := 0.12
const LANDING_SETTLE_SECONDS := 0.42
const BREATH_PERIOD_SECONDS := 3.8
var actor
var kart: Node3D
var steering := 0.0
var speed := 0.0
var airborne := false
var hit_amount := 0.0
var victory := false
var celebration_clip := "celebrate"
var suspended := false
var reduced_motion := false
var boosting := false
var drifting := false
var elapsed := 0.0
var maximum_contact_error := 0.0
var _tick := 0.0
var _seated_leg_rotations: Dictionary = {}
var _menu_gesture := false
var _attention_enabled := false
var _attention_target := Vector3.ZERO
var _attention_angles := Vector2.ZERO
var _visual_steering := 0.0
var _chest_roll := 0.0
var _boost_pitch := 0.0
var _breath := 0.0
var _landing_elapsed := -1.0
var landing_amount := 0.0


func bind_visual(review_kart: Node3D) -> bool:
	if actor != null:
		return actor.is_usable()
	var anchors: Variant = review_kart.get("wheel_rest_grips")
	if review_kart.get("steering_wheel") == null or not anchors is Array or anchors.size() != 2:
		return false
	kart = review_kart
	actor = ACTOR.new()
	# Fit the existing standalone character to the existing bucket seat.
	# One uniform visual scale only, never stretching limbs or chassis.
	actor.scale = Vector3.ONE * 1.15
	actor.position = Vector3(0, -0.05, 0.12)
	actor.rotation.y = PI
	add_child(actor)
	if not actor.is_usable():
		actor.free()
		actor = null
		return false
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
	return true


func _behavior_finished(behavior: String) -> void:
	if behavior == celebration_clip and victory:
		victory = false
		actor.play_behavior("kart_seated")


func apply_vehicle_sample(
	velocity: float, steer: float, in_air: bool, hit: bool = false,
	boost: bool = false, drift: bool = false
) -> void:
	# Callers supply real state. Do not infer a jump from elapsed time.
	speed = absf(velocity) if is_finite(velocity) else 0.0
	steering = clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	# A landing is the real vehicle's airborne -> grounded edge, never a
	# repeating timer or a guessed jump. Repeated grounded samples cannot
	# restart the short settle; pause/reduced motion cannot queue a reaction.
	if airborne and not in_air and not suspended and not reduced_motion:
		_landing_elapsed = 0.0
	airborne = in_air
	boosting = boost
	drifting = drift
	if hit:
		hit_amount = 1.0


## A world-space point supplied by the presentation owner. This turns the
## existing Head bone, not eyes or invented face morphs. Targets behind Lumo
## return to neutral rather than turning his neck beyond a comfortable range.
func set_attention_target(world_position: Vector3) -> bool:
	if not world_position.is_finite():
		return false
	_attention_target = world_position
	_attention_enabled = true
	return true


func clear_attention_target() -> void:
	_attention_enabled = false


func celebrate_finished_race(place: int = 1) -> void:
	if actor == null or victory:
		return
	victory = true
	_menu_gesture = false
	celebration_clip = "celebrate" if place <= 3 else "agree_nod"
	actor.play_behavior(celebration_clip)


## Reuses existing clips and the same seated-leg/wheel constraints in menus.
## Triggered only by actual entry or selection, not a repeating greeting timer.
func play_menu_behavior(behavior: String) -> bool:
	if actor == null or suspended or reduced_motion:
		return false
	if behavior not in ["greeting_wave", "agree_nod", "celebrate", "point_portal"]:
		return false
	_menu_gesture = true
	victory = true
	celebration_clip = behavior
	return actor.play_behavior(behavior)


func clear_celebration() -> void:
	victory = false
	_menu_gesture = false
	if actor != null and not suspended:
		actor.play_behavior("kart_seated")


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	if value:
		_landing_elapsed = -1.0
		landing_amount = 0.0
		_attention_angles = Vector2.ZERO
		_breath = 0.0
		_visual_steering = 0.0
		_chest_roll = 0.0
		_boost_pitch = 0.0
	if actor != null:
		actor.set_reduced_motion(value)


func set_suspended(value: bool) -> void:
	if suspended == value:
		return
	suspended = value
	_tick = 0.0
	if actor != null:
		actor.set_suspended(value)


func _process(delta: float) -> void:
	advance_tick(delta)


func advance_tick(delta: float) -> void:
	if actor == null or suspended or not is_finite(delta) or delta < 0.0:
		return
	_tick += delta
	if _tick + TICK_EPSILON_SECONDS < VISUAL_TICK_SECONDS:
		# Bone clips update at 30 Hz, but wheel contact follows every visual
		# frame. Otherwise a 60 Hz steering change separates hand and rim.
		# Nodding keeps both hands on the wheel. It uses the same two-hand
		# constraint between bone ticks as in advance_visual(); otherwise the
		# right hand remains at the previous steering angle for a whole frame.
		if not victory or celebration_clip == "agree_nod":
			maximum_contact_error = 0.0
			_follow_wheel_hand(0)
			_follow_wheel_hand(1)
		elif speed > 0.5 or _menu_gesture:
			maximum_contact_error = 0.0
			_follow_wheel_hand(0)
		return
	# Keep the fractional interval: resetting it dropped the cadence to 25 Hz
	# at 50/75 Hz input. Consume whole intervals once, without double-counting
	# the retained time. After a hitch, discard excess whole intervals while
	# keeping the existing 100 ms cap and avoiding a catch-up loop.
	var intervals := floori((_tick + TICK_EPSILON_SECONDS) / VISUAL_TICK_SECONDS)
	var consumed := float(intervals) * VISUAL_TICK_SECONDS
	_tick = maxf(0.0, _tick - consumed)
	advance_visual(minf(consumed, MAX_VISUAL_STEP_SECONDS))


func advance_visual(delta: float) -> void:
	if actor == null or suspended or not is_finite(delta) or delta < 0.0:
		return
	if not reduced_motion:
		elapsed += delta
	hit_amount = move_toward(hit_amount, 0.0, delta * 2.5)
	_advance_secondary_motion(minf(delta, MAX_VISUAL_STEP_SECONDS))
	var already_advanced := false
	if victory:
		maximum_contact_error = 0.0
		if not reduced_motion:
			actor.player.advance(delta)
			already_advanced = true
		# The existing stand-up cheer provides the upper body; preserve the
		# actual seated legs instead of dropping boots through the chassis.
		for index in _seated_leg_rotations:
			actor.skeleton.set_bone_pose_rotation(index, _seated_leg_rotations[index])
		actor.skeleton.force_update_all_bone_transforms()
		# Preserve the existing safe finish-coast gesture: left hand stays
		# on the actual moving wheel while the right celebrates.
		# animation_finished can switch victory off inside advance(). In that
		# frame we must already restore BOTH contacts, not return with raised
		# hands and a seated state label.
		if victory:
			_apply_attention()
			actor.skeleton.force_update_all_bone_transforms()
			if speed > 0.5 or celebration_clip == "agree_nod" or _menu_gesture:
				_follow_wheel_hand(0)
			if celebration_clip == "agree_nod":
				_follow_wheel_hand(1)
			return
	var clip := "kart_jump" if airborne else "kart_seated"
	if actor.current_behavior != clip:
		actor.play_behavior(clip)
	if reduced_motion:
		actor.player.seek(0.3, true)
	elif not already_advanced:
		actor.player.advance(delta)
	var skeleton: Skeleton3D = actor.skeleton
	var chest: int = skeleton.find_bone("Chest")
	var head: int = skeleton.find_bone("Head")
	# These deltas affect only the visual skeleton, not the chassis.
	if not reduced_motion:
		skeleton.set_bone_pose_rotation(chest, skeleton.get_bone_pose_rotation(chest) *
			Quaternion(Vector3.FORWARD, _chest_roll))
		skeleton.set_bone_pose_rotation(chest, skeleton.get_bone_pose_rotation(chest) *
			Quaternion(Vector3.RIGHT, _boost_pitch + _breath + landing_amount * 0.12))
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) *
			Quaternion(Vector3.UP, _visual_steering * 0.07))
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) *
			Quaternion(Vector3.RIGHT, -_breath * 0.45 - landing_amount * 0.06))
	_apply_attention()
	skeleton.force_update_all_bone_transforms()
	maximum_contact_error = 0.0
	for i in range(2):
		_follow_wheel_hand(i)
	_curl_fingers()


func _advance_secondary_motion(delta: float) -> void:
	if reduced_motion:
		return
	var follow := 1.0 - exp(-delta * 9.0)
	_visual_steering = lerpf(_visual_steering, steering, follow)
	_chest_roll = lerpf(_chest_roll,
		steering * (-0.075 if drifting else -0.055) + hit_amount * 0.07, follow)
	_boost_pitch = lerpf(_boost_pitch, -0.025 if boosting else 0.0, follow)
	# The shipped kart_seated clip is a static seated pose. A slow chest
	# rotation gives it breath without scaling the mesh, moving the seat or
	# competing with its AnimationPlayer. Strong gestures keep their clip.
	_breath = sin(elapsed * TAU / BREATH_PERIOD_SECONDS) * 0.012 * (
		1.0 - 0.6 * clampf(speed / 20.0, 0.0, 1.0))
	if _landing_elapsed >= 0.0:
		_landing_elapsed += delta
		var progress := clampf(_landing_elapsed / LANDING_SETTLE_SECONDS, 0.0, 1.0)
		landing_amount = sin(progress * PI) * (1.0 - progress)
		if progress >= 1.0:
			_landing_elapsed = -1.0
			landing_amount = 0.0
	var target_angles := Vector2.ZERO
	if _attention_enabled:
		var head: int = actor.skeleton.find_bone("Head")
		var origin: Vector3 = actor.skeleton.to_global(
			actor.skeleton.get_bone_global_pose(head).origin)
		# The unchanged source character faces +Z; its adapter rotates the
		# actor into the kart. Convert world targets through that actual basis.
		var direction: Vector3 = actor.global_basis.inverse() * (_attention_target - origin)
		var horizontal := Vector2(direction.x, direction.z).length()
		if direction.z > 0.05 and horizontal > 0.05:
			target_angles.x = clampf(atan2(direction.x, direction.z),
				-ATTENTION_YAW_LIMIT, ATTENTION_YAW_LIMIT)
			target_angles.y = clampf(-atan2(direction.y, horizontal),
				-ATTENTION_PITCH_LIMIT, ATTENTION_PITCH_LIMIT)
	_attention_angles = _attention_angles.lerp(target_angles, 1.0 - exp(-delta * 7.0))


func _apply_attention() -> void:
	if reduced_motion:
		return
	var skeleton: Skeleton3D = actor.skeleton
	var head := skeleton.find_bone("Head")
	skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) *
		Quaternion(Vector3.UP, _attention_angles.x) *
		Quaternion(Vector3.RIGHT, _attention_angles.y))


func _follow_wheel_hand(index: int) -> void:
	var skeleton: Skeleton3D = actor.skeleton
	var wheel: Node3D = kart.get("steering_wheel")
	var anchors: Array = kart.get("wheel_rest_grips")
	var target: Vector3 = skeleton.to_local(wheel.to_global(anchors[index]))
	maximum_contact_error = maxf(
		maximum_contact_error, _solve_hand("L" if index == 0 else "R", target)
	)


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
