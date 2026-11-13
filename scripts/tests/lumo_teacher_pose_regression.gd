extends SceneTree
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const DT: float = 1.0 / 60.0
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[LumoTeacherPose] " + label)


func _run() -> void:
	var actor = ACTOR.new()
	var reference = ACTOR.new()
	root.add_child(actor)
	root.add_child(reference)
	actor.set_process(false)
	reference.set_process(false)
	_check(
		actor.is_usable() and actor.skeleton.get_bone_count() == 65,
		"original 65-bone teacher loaded"
	)
	if not actor.is_usable():
		quit(1)
		return
	reference.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var origin: Vector3 = actor.position
	var head: int = actor.skeleton.find_bone("Head")
	var neck: int = actor.skeleton.find_bone("Neck")
	var thigh: int = actor.skeleton.find_bone("Thigh.L")
	var eye_height: Vector3 = actor.skeleton.to_global(
		actor.skeleton.get_bone_global_pose(head).origin
	)
	_check(
		actor.set_teaching_target(eye_height + Vector3(3, 0.8, 4)),
		"selected object accepts actual world-space point"
	)
	_check(
		(
			actor.teacher_enabled
			and (
				actor.player.callback_mode_process
				== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			)
		),
		"teacher has one explicit animation owner"
	)
	for _frame in range(60):
		actor._process(DT)
		reference.player.advance(DT)
	var head_delta: float = actor.skeleton.get_bone_pose_rotation(head).angle_to(
		reference.skeleton.get_bone_pose_rotation(head)
	)
	var neck_delta: float = actor.skeleton.get_bone_pose_rotation(neck).angle_to(
		reference.skeleton.get_bone_pose_rotation(neck)
	)
	_check(
		head_delta > 0.20 and neck_delta > 0.10,
		"real head and neck bones both follow object, not a metadata-only target"
	)
	var face_in_bone: Vector3 = (
		actor.skeleton.get_bone_global_rest(head).basis.inverse() * Vector3.BACK
	)
	var face: Vector3 = (
		(
			actor.skeleton.global_basis
			* actor.skeleton.get_bone_global_pose(head).basis
			* face_in_bone
		)
		. normalized()
	)
	var reference_face: Vector3 = (
		(
			reference.skeleton.global_basis
			* reference.skeleton.get_bone_global_pose(head).basis
			* face_in_bone
		)
		. normalized()
	)
	var desired_face := Vector3(3, 0.8, 4).normalized()
	_check(
		face.angle_to(desired_face) < reference_face.angle_to(desired_face) * 0.3,
		"actual facial facing vector converges towards the selected object despite original bone rest axes"
	)
	actor.rotation.y = 0.7
	actor.set_teaching_target(actor.global_transform * (eye_height + Vector3(3, 0.8, 4)))
	for _frame in range(60):
		actor._process(DT)
	face = (
		(
			actor.skeleton.global_basis
			* actor.skeleton.get_bone_global_pose(head).basis
			* face_in_bone
		)
		. normalized()
	)
	_check(
		face.angle_to(actor.global_basis * desired_face) < 0.15,
		"rotated teaching stage preserves correct world-space attention"
	)
	actor.rotation.y = 0.0
	_check(
		(
			actor.skeleton.get_bone_pose_rotation(thigh).angle_to(
				reference.skeleton.get_bone_pose_rotation(thigh)
			)
			< 0.001
		),
		"teacher gaze preserves authored leg pose"
	)
	_check(actor.position == origin, "teacher gestures never translate physics root")
	var target: Vector3 = actor.teacher_pose.target
	_check(
		not actor.set_teaching_target(Vector3(NAN, 0, 0)) and actor.teacher_pose.target == target,
		"invalid object coordinates cannot poison skeleton"
	)
	actor.set_teaching_target(eye_height + Vector3(100, 50, 1))
	var maximum_head_delta: float = 0.0
	for _frame in range(600):
		actor._process(DT)
		reference.player.advance(DT)
		maximum_head_delta = maxf(
			maximum_head_delta,
			actor.skeleton.get_bone_pose_rotation(head).angle_to(
				reference.skeleton.get_bone_pose_rotation(head)
			)
		)
	_check(
		(
			absf(actor.teacher_pose.angles.x) <= 0.65001
			and absf(actor.teacher_pose.angles.y) <= 0.32001
		),
		"far targets respect anatomical attention limits"
	)
	_check(maximum_head_delta < 0.55, "600 samples do not accumulate additive head rotation")
	actor.set_teaching_target(eye_height + Vector3(0, 0, -4))
	for _frame in range(90):
		actor._process(DT)
	_check(
		actor.teacher_pose.angles.length() < 0.005,
		"rear target returns to neutral without backwards neck twist"
	)
	for event in ["explain", "encourage", "correct", "celebrate", "welcome"]:
		_check(actor.teacher_react(event), "real teacher reaction accepts " + event)
		actor._process(0.05)
		_check(
			actor.player.current_animation_position > 0.0,
			event + " advances original authored clip"
		)
	_check(not actor.teacher_react("unsupported"), "unknown reaction is rejected")
	_check(
		actor.set_teacher_speaking(true) and actor.teacher_pose.speaking,
		"actual playback owner can enable gentle speech motion"
	)
	actor.apply_speech_sample(2.5, 0.7, true)
	_check(not actor.mouth_supported, "voice envelope is not misreported as unsupported lip-sync")
	actor.set_suspended(true)
	var paused_angle: Quaternion = actor.skeleton.get_bone_pose_rotation(head)
	var paused_time: float = actor.player.current_animation_position
	actor._process(0.8)
	_check(
		(
			actor.skeleton.get_bone_pose_rotation(head).is_equal_approx(paused_angle)
			and is_equal_approx(actor.player.current_animation_position, paused_time)
		),
		"suspend freezes teacher pose and clip clock"
	)
	actor.set_suspended(false)
	actor._process(DT)
	_check(
		actor.player.current_animation_position > paused_time, "teacher resumes the actual gesture"
	)
	actor.set_reduced_motion(true)
	paused_angle = actor.skeleton.get_bone_pose_rotation(head)
	actor._process(1.0)
	_check(
		actor.skeleton.get_bone_pose_rotation(head).is_equal_approx(paused_angle),
		"reduced motion stays still"
	)
	actor.set_reduced_motion(false)
	actor.set_teacher_speaking(false)
	actor.set_platform_motion(Vector3(2, 0, 0), true, DT)
	_check(
		not actor.teacher_enabled and actor.platform_active,
		"walking takes exclusive ownership back from teacher"
	)
	_check(
		actor.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE,
		"leaving teacher restores original callback mode"
	)
	_check(
		actor.teacher_react("explain") and not actor.platform_active,
		"teacher gesture takes sole ownership from platform motion"
	)
	_check(
		actor.play_behavior("walk_loop") and actor.walking and not actor.teacher_enabled,
		"legacy walk behavior also takes sole ownership from teacher"
	)
	var standing_thigh: Quaternion = actor.skeleton.get_bone_pose_rotation(thigh)
	for _frame in range(8):
		actor._process(DT)
	_check(
		actor.skeleton.get_bone_pose_rotation(thigh).angle_to(standing_thigh) > 0.03,
		"legacy walk skeleton advances after leaving teacher mode"
	)
	_check(
		not reference.set_teaching_target(eye_height + Vector3(0, 0, 4)),
		"external manual owner such as kart cannot be overwritten"
	)
	actor.free()
	reference.free()
	await process_frame
	if failures.is_empty():
		print(
			(
				"[LumoTeacherPose] PASS %d checks: original gestures, bounded split gaze, owner exclusivity, pause and honest voice seam"
				% checks
			)
		)
		quit(0)
	else:
		print("[LumoTeacherPose] FAIL ", failures)
		quit(1)
