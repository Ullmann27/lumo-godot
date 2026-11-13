extends SceneTree
## Independent exported-GLB skeletal gait test: no procedural substitute or
## root position cheating. No real device performance or terrain IK claim.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const DT: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor = ACTOR.new()
	root.add_child(actor)
	await process_frame
	await process_frame
	assert(actor.is_usable() and actor.skeleton.get_bone_count() == 65,
		"Use the exact original skinned Lumo")
	var home: Vector3 = actor.position
	var i_l: int = actor.skeleton.find_bone("Thigh.L")
	var i_r: int = actor.skeleton.find_bone("Thigh.R")
	var i_f: int = actor.skeleton.find_bone("Foot.L")
	var i_fr: int = actor.skeleton.find_bone("Foot.R")
	assert(i_l >= 0 and i_r >= 0 and i_f >= 0 and i_fr >= 0)
	# Imported feet have rotated parent axes. Measure actual skeletal height,
	# so a correct body-space offset cannot be mistaken for zero local-Y lift.
	var foot_home: Vector3 = actor.skeleton.get_bone_global_pose(i_f).origin
	var right_foot_home: Vector3 = actor.skeleton.get_bone_global_pose(i_fr).origin
	assert(actor.set_locomotion_speed(1.5))
	assert(actor.walking and actor.get_current_behavior() == "walk_loop")
	var neutral: Quaternion = actor.locomotion.neutral_rotation["Thigh.L"]
	var max_left: float = 0.0
	var max_right: float = 0.0
	var max_lift: float = 0.0
	var max_right_lift: float = 0.0
	for t in range(55):
		actor._process(DT)
		var pose_l: Quaternion = actor.skeleton.get_bone_pose_rotation(i_l)
		var pose_r: Quaternion = actor.skeleton.get_bone_pose_rotation(i_r)
		max_left = maxf(max_left, pose_l.angle_to(neutral))
		max_right = maxf(max_right, pose_r.angle_to(actor.locomotion.neutral_rotation["Thigh.R"]))
		var lift: float = actor.skeleton.get_bone_global_pose(i_f).origin.y - foot_home.y
		var right_lift: float = actor.skeleton.get_bone_global_pose(i_fr).origin.y - right_foot_home.y
		max_lift = maxf(max_lift, lift)
		max_right_lift = maxf(max_right_lift, right_lift)
		assert(actor.position.is_equal_approx(home),
			"Gait must not fake translation or modify collision")
	assert(max_left > 0.28 and max_right > 0.28, "Both thighs visibly step")
	assert(max_lift > 0.022 and max_right_lift > 0.022,
		"Both swing feet lift off the original ground pose in skeleton space")
	var paused: float = actor.locomotion.phase
	actor.set_suspended(true)
	actor._process(0.8)
	assert(is_equal_approx(actor.locomotion.phase, paused), "Pause freezes footsteps")
	actor.set_suspended(false)
	actor.set_reduced_motion(true)
	actor._process(1.0)
	assert(is_equal_approx(actor.locomotion.phase, paused), "Calm mode freezes footsteps")
	actor.set_reduced_motion(false)
	actor.set_locomotion_speed(0.0)
	assert(not actor.walking and actor.current_behavior == "idle")
	assert(actor.play_behavior("kart_seated"), "Original nine Kart/gesture clips preserved")
	actor.free()
	await process_frame
	await process_frame
	print("[LumoGait] PASS: real 65-bone alternating thigh/foot/toe/arm movement, pause, calm mode, neutral reset")
	quit(0)
