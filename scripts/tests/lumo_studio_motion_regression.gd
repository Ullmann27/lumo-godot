extends SceneTree
## Cross-tool pose evidence: compare Godot's original skin to Blender's
## independently evaluated leg endpoints, then exercise the production actor.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const BODY_SPACE = preload("res://scripts/characters/lumo/lumo_body_space_pose.gd")
const PLATFORM = preload("res://scripts/characters/lumo/lumo_platform_pose.gd")
const DT: float = 1.0 / 60.0
var failures: Array[String] = []
var checks: int = 0
var max_endpoint_error: float = 0.0
var max_segment_error: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[LumoStudioMotion] " + message)


func _neutral(actor) -> void:
	actor.player.play("idle", 0.0)
	actor.player.seek(0.0, true)
	actor.player.advance(0.0)
	actor.player.pause()
	actor.skeleton.force_update_all_bone_transforms()


func _endpoint(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin


func _blender_agreement(actor) -> void:
	_neutral(actor)
	var indices: Dictionary = {}
	for bone in PLATFORM.BONES:
		indices[bone] = actor.skeleton.find_bone(bone)
	var pose = BODY_SPACE.new()
	_check(pose.bind(actor.skeleton, indices), "bind actual original skeleton")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/studio-character-20261113/motion_build.json"))
	_check(raw is Dictionary, "independent Blender evaluation receipt exists")
	if not raw is Dictionary:
		return
	var report: Dictionary = raw
	_check(bool(report.source_unchanged), "Blender leaves original source unchanged")
	_check(FileAccess.get_sha256(ACTOR.ORIGINAL_MODEL) == str(report.source_sha256), "untouched source hash still matches Blender body-clip input")
	_check(FileAccess.get_sha256(ACTOR.MODEL) != FileAccess.get_sha256(ACTOR.ORIGINAL_MODEL), "authored facial derivative is distinct from preserved source")
	var original_lengths: Dictionary = {}
	for side in ["L", "R"]:
		original_lengths[side] = Vector2(
			_endpoint(actor.skeleton, "Thigh." + side).distance_to(_endpoint(actor.skeleton, "Shin." + side)),
			_endpoint(actor.skeleton, "Shin." + side).distance_to(_endpoint(actor.skeleton, "Foot." + side))
		)
	for clip in pose.STUDIO.CLIPS:
		var keyframes: Array = report.foot_keyframes_model_metres[clip]
		for frame in range(keyframes.size()):
			var phase: float = float(frame) / float(keyframes.size() - 1)
			for bone in PLATFORM.BONES:
				actor.skeleton.set_bone_pose_rotation(int(indices[bone]), pose.rotation_target(bone, pose.clip_rotation(clip, bone, phase)))
				actor.skeleton.set_bone_pose_position(int(indices[bone]), pose.positions[bone])
			actor.skeleton.set_bone_pose_position(int(indices.Pelvis), pose.position_target("Pelvis", pose.clip_pelvis(clip, phase)))
			actor.skeleton.force_update_all_bone_transforms()
			for side in ["L", "R"]:
				var row: Array = keyframes[frame][side]
				var expected := Vector3(float(row[0]), float(row[1]), float(row[2]))
				var actual: Vector3 = _endpoint(actor.skeleton, "Foot." + side)
				max_endpoint_error = maxf(max_endpoint_error, actual.distance_to(expected))
				var lengths := Vector2(
					_endpoint(actor.skeleton, "Thigh." + side).distance_to(_endpoint(actor.skeleton, "Shin." + side)),
					_endpoint(actor.skeleton, "Shin." + side).distance_to(actual)
				)
				max_segment_error = maxf(max_segment_error, lengths.distance_to(original_lengths[side]))
				_check(actual.distance_to(expected) < 0.003, "Blender/Godot feet agree: %s/%d/%s" % [clip, frame, side])
				_check(lengths.distance_to(original_lengths[side]) < 0.00002, "original rigid leg lengths survive clip: %s/%d/%s" % [clip, frame, side])
				if clip in ["walk", "sprint", "land", "brake"]:
					_check(actual.y >= 0.034, "authored planted feet do not sink below source sole plane")
					var sole: Vector3 = actor.skeleton.get_bone_global_pose(int(indices["Foot." + side])).basis.z.normalized()
					_check(sole.dot(Vector3.UP) > 0.999, "foot sole orientation stays level")
	_check(max_endpoint_error < 0.003, "all 300 endpoints agree across independent tools")
	_check(max_segment_error < 0.00002, "no animation stretches thighs or shins")
	actor.rotation.y = 0.73
	actor.scale = Vector3.ONE * 0.6
	_check(is_equal_approx(pose.stride_metres(), 0.78 * 0.6), "stride follows actor scale in world metres")
	actor.rotation.y = 0.0
	actor.scale = Vector3.ONE
	_neutral(actor)


func _production_modes(actor) -> void:
	var root_before: Transform3D = actor.transform
	_check(actor.set_locomotion_speed(1.4), "learning-world walk enters original actor")
	var foot_min: float = INF
	var foot_max: float = -INF
	for _frame in range(100):
		actor._process(DT)
		var foot: Vector3 = _endpoint(actor.skeleton, "Foot.L")
		foot_min = minf(foot_min, foot.y)
		foot_max = maxf(foot_max, foot.y)
	_check(foot_max - foot_min > 0.07, "authored swing visibly lifts actual ankle")
	_check(foot_min >= 0.028, "interpolated walk does not bury planted feet")
	_check(actor.transform.is_equal_approx(root_before), "motion library never moves collider/root")
	_check(actor.set_platform_motion(Vector3(0, 0, 5.5), true, DT), "production platform uses motion library")
	for _frame in range(30):
		actor.set_platform_motion(Vector3(0, 0, 5.5), true, DT)
	_check(actor.current_behavior == "run_loop", "actual sprint selects running phase")
	_check(actor.platform_active and not actor.player.is_playing(), "one pose owner; original player is paused")
	actor.set_platform_motion(Vector3(0, 8.5, 2), false, DT)
	_check(actor.current_behavior == "jump_rise", "upward physics selects ascent clip")
	for _frame in range(12):
		actor.set_platform_motion(Vector3(0, -6, 2), false, DT)
	_check(actor.current_behavior == "jump_fall", "downward physics selects descent clip")
	actor.set_platform_motion(Vector3.ZERO, true, DT)
	_check(actor.current_behavior == "land", "floor transition selects impact recovery")
	for _frame in range(40):
		actor.set_platform_motion(Vector3.ZERO, true, DT)
	_check(not actor.platform_active and actor.player.is_playing(), "authored breathing resumes after recovery")
	actor.set_platform_motion(Vector3(0, 0, 2), true, DT)
	var phase: float = actor.platform_pose.phase
	actor.set_suspended(true)
	_check(not actor.set_platform_motion(Vector3(0, 0, 2), true, DT), "suspension prevents invisible stepping")
	_check(is_equal_approx(actor.platform_pose.phase, phase), "pause leaves motion phase unchanged")
	actor.set_suspended(false)
	actor.set_teaching_target(Vector3(0.5, 1.2, 2.0))
	_check(actor.teacher_enabled and not actor.platform_active and not actor.walking, "teacher gaze takes exclusive pose ownership")
	_check(actor.teacher_react("correct"), "existing teacher response remains connected")
	actor.set_locomotion_speed(1.0)
	_check(not actor.teacher_enabled and actor.walking, "walking can resume after a teaching gesture")
	actor.set_locomotion_speed(0.0)
	for clip in ACTOR.CLIPS:
		_check(actor.play_behavior(clip), "original clip retained: " + clip)
	_check(actor.mouth_supported and not actor.phoneme_lipsync_supported, "no facial rig or phoneme evidence is invented")


func _idle_phase_independence() -> void:
	# Rebinding after an existing idle must not retain its breathing Root
	# offset. Before explicit seek(), both APIs differed by up to 3.28 mm.
	for mode in ["platform", "walk"]:
		var first := Vector3.ZERO
		for idle_phase in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]:
			var actor = ACTOR.new()
			root.add_child(actor)
			actor.set_process(false)
			actor.player.play("idle", 0.0)
			actor.player.seek(idle_phase, true)
			actor.player.advance(0.0)
			actor.player.pause()
			if mode == "platform":
				for _frame in range(60):
					actor.set_platform_motion(Vector3(0, 0, 1.4), true, DT)
			else:
				actor.set_locomotion_speed(1.4)
				for _frame in range(60):
					actor._process(DT)
			var actual: Vector3 = _endpoint(actor.skeleton, "Foot.L")
			if is_zero_approx(idle_phase):
				first = actual
			_check(actual.distance_to(first) < 0.00002, "%s pose is independent of old idle phase %.1f" % [mode, idle_phase])
			actor.free()


func _run() -> void:
	var actor = ACTOR.new()
	root.add_child(actor)
	await process_frame
	_check(actor.is_usable() and actor.skeleton.get_bone_count() == 65, "original imported fox is usable")
	if not actor.is_usable():
		quit(1)
		return
	actor.set_process(false)
	_blender_agreement(actor)
	_production_modes(actor)
	actor.free()
	_idle_phase_independence()
	await process_frame
	print("[LumoStudioMotion] %s checks=%d Blender/Godot endpoint_error_m=%.9f segment_error_m=%.9f; no physical Android claim" % ["PASS" if failures.is_empty() else "FAIL", checks, max_endpoint_error, max_segment_error])
	quit(0 if failures.is_empty() else 1)
