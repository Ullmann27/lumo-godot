extends SceneTree
## Real existing Kart visual plus one opt-in skinned Lumo. No physics edits.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const ADAPTER = preload("res://scripts/characters/lumo/lumo_kart_animation_adapter.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[LumoKartAnimation] " + label)


func _settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://exports/lumo-animation-kart"
	var video := args.has("--video")
	var video_frame := 0
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 720)
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var stage := Node3D.new()
	root.add_child(stage)
	var built: Dictionary = load("res://scripts/games/kart_stage.gd").build(stage)
	var camera: Camera3D = built.camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.look_at_from_position(Vector3(2.7, 2.0, -4.0), Vector3(0, 0.9, 0))
	camera.current = true
	var kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	stage.add_child(kart)
	kart.set_process(false)
	kart._process(1.0 / 30.0)
	await _settle()
	if DisplayServer.get_name() != "headless":
		_check(root.get_texture().get_image().save_png(output.path_join("before-procedural-driver.png")) == OK,
			"Actual original driver before the test-only swap")
	var adapter = ADAPTER.new()
	kart.add_child(adapter)
	adapter.bind_visual(kart)
	adapter.set_process(false)
	# Hide only the procedural driver in THIS TEST scene, never in Kart product code.
	kart.driver.visible = false
	var chassis_transform: Transform3D = kart.transform
	var scale_before: Vector3 = kart.scale
	await _settle()
	var worst := 0.0
	var seated_feet: Dictionary = {}
	for sample in [
		{"name": "seated", "steer": 0.0, "air": false, "hit": false},
		{"name": "steer-left", "steer": -1.0, "air": false, "hit": false},
		{"name": "steer-right", "steer": 1.0, "air": false, "hit": false},
		{"name": "jump-reaction", "steer": 0.4, "air": true, "hit": false},
		{"name": "hit-reaction", "steer": 0.0, "air": false, "hit": true},
	]:
		kart.set_motion(18.0, sample.steer, false, absf(sample.steer) > 0.5)
		adapter.apply_vehicle_sample(18.0, sample.steer, sample.air, sample.hit)
		var sample_worst := 0.0
		for frame in range(24):
			kart._process(1.0 / 30.0)
			adapter.advance_visual(1.0 / 30.0)
			worst = maxf(worst, adapter.maximum_contact_error)
			sample_worst = maxf(sample_worst, adapter.maximum_contact_error)
			_check(adapter.maximum_contact_error < 0.006, "Real hands follow wheel: " + sample.name)
			_check(kart.transform.is_equal_approx(chassis_transform), "Character cannot translate the Kart")
			_check(kart.scale.is_equal_approx(scale_before), "Character cannot scale chassis or collision")
			if video and frame % 2 == 0 and DisplayServer.get_name() != "headless":
				await _settle()
				_check(root.get_texture().get_image().save_png(
					output.path_join("frame-%04d.png" % video_frame)) == OK, "Real video frame")
				video_frame += 1
		print("[LumoKartAnimation] sample=", sample.name, " contact_mm=", sample_worst * 1000)
		if sample.name == "seated":
			for side in ["L", "R"]:
				seated_feet[side] = adapter.actor.skeleton.get_bone_global_pose(
					adapter.actor.skeleton.find_bone("Foot." + side)).origin
		await _settle()
		if DisplayServer.get_name() != "headless":
			_check(root.get_texture().get_image().save_png(output.path_join(sample.name + ".png")) == OK, "Runtime capture")
	adapter.set_suspended(true)
	var prior: float = adapter.elapsed
	adapter.advance_visual(1.0)
	_check(is_equal_approx(adapter.elapsed, prior), "Pause stops animation")
	adapter.set_suspended(false)
	adapter.celebrate_finished_race()
	for frame in range(27):
		adapter.advance_visual(1.0 / 30.0)
		if video and frame % 2 == 0 and DisplayServer.get_name() != "headless":
			await _settle()
			_check(root.get_texture().get_image().save_png(
				output.path_join("frame-%04d.png" % video_frame)) == OK, "Real cheer video frame")
			video_frame += 1
	var head_height: float = adapter.actor.skeleton.get_bone_global_pose(
		adapter.actor.skeleton.find_bone("Head")).origin.y
	for side in ["L", "R"]:
		var hand_height: float = adapter.actor.skeleton.get_bone_global_pose(
			adapter.actor.skeleton.find_bone("Hand." + side)).origin.y
		if side == "R":
			_check(hand_height > head_height, "Victory really raises the right hand")
		else:
			var hand: Vector3 = adapter.actor.skeleton.to_global(
				adapter.actor.skeleton.get_bone_global_pose(
					adapter.actor.skeleton.find_bone("Hand.L")).origin)
			var anchor: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[0])
			_check(hand.distance_to(anchor) < 0.006, "Coasting victory keeps the left hand on the wheel")
		var foot: Vector3 = adapter.actor.skeleton.get_bone_global_pose(
			adapter.actor.skeleton.find_bone("Foot." + side)).origin
		_check(foot.distance_to(seated_feet[side]) < 0.07,
			"Victory boot stays near the actual seated foot position: " + side)
	for index in adapter._seated_leg_rotations:
		_check(adapter.actor.skeleton.get_bone_pose_rotation(index).is_equal_approx(
			adapter._seated_leg_rotations[index]), "Victory keeps seated legs")
	await _settle()
	if DisplayServer.get_name() != "headless":
		_check(root.get_texture().get_image().save_png(output.path_join("victory.png")) == OK, "Actual victory capture")
	_check(kart.transform.is_equal_approx(chassis_transform), "Victory never changes vehicle state")
	for frame in range(48):
		adapter.advance_visual(1.0 / 30.0)
	_check(not adapter.victory and adapter.actor.current_behavior == "kart_seated",
		"Finished cheer returns to the seated driver")
	_check(adapter.maximum_contact_error < 0.006, "Hands regain wheel after the cheer")
	stage.free()
	await _settle()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline, "No orphan nodes")
	print("[LumoKartAnimation] checks=", checks, " worst_hand_contact_mm=", worst * 1000, " failures=", failures)
	if failures == 0:
		print("[LumoKartAnimation] PASS isolated real Kart visual and Lumo; not a playable APK update")
	quit(0 if failures == 0 else 1)
