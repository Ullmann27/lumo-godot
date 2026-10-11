extends SceneTree
## Sample actual wheel/hand transforms between the 30 Hz clip updates.
## Optional images are genuine Godot frames, not an FPS measurement.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _contact(kart, side: String, anchor: int) -> float:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var hand := skeleton.to_global(
		skeleton.get_bone_global_pose(skeleton.find_bone("Hand." + side)).origin
	)
	return hand.distance_to(kart.steering_wheel.to_global(kart.wheel_rest_grips[anchor]))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://exports/gesture-contact"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1000, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce8ff")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -28, 0)
	light.light_energy = 1.2
	stage.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_energy = 0.5
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 37
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.72, 2.0, -3.8), Vector3(0, 1.05, -0.10))
	var kart = VEHICLE.new()
	kart.configure("fox", Color("76d9ff"), "comet")
	stage.add_child(kart)
	kart.set_process(false)
	kart.set_animated_lumo_enabled(true)
	var transform_before: Transform3D = kart.transform
	var samples: Array[Dictionary] = []
	for fps in [60, 120]:
		for menu in [false, true]:
			kart.celebrate(0)
			kart.set_motion(0.0 if menu else 18.0, 0.0, false, false)
			kart.lumo_animation._tick = 0.0
			kart._process(1.0 / 30.0)
			if menu:
				kart.lumo_animation.play_menu_behavior("agree_nod")
			else:
				kart.celebrate(4)
			kart._process(1.0 / 30.0)
			var worst_left := 0.0
			var worst_right := 0.0
			var cpu_samples: Array[float] = []
			var name := ("menu" if menu else "finish") + "-nod-%d" % fps
			for frame in range(48):
				# A legitimate fast steering input immediately after a bone tick,
				# followed by continuous direction changes while nodding.
				var steer := cos(frame * 0.24)
				kart.set_motion(0.0 if menu else 18.0, steer, false, false)
				var begin := Time.get_ticks_usec()
				kart._process(1.0 / fps)
				cpu_samples.append((Time.get_ticks_usec() - begin) / 1000.0)
				worst_left = maxf(worst_left, _contact(kart, "L", 0))
				worst_right = maxf(worst_right, _contact(kart, "R", 1))
				checks += 1
				if not kart.transform.is_equal_approx(transform_before):
					failures += 1
				if frame == 0 and DisplayServer.get_name() != "headless":
					await process_frame
					await RenderingServer.frame_post_draw
					var error := root.get_texture().get_image().save_png(
						output.path_join(name + ".png")
					)
					if error != OK:
						failures += 1
				if (
					args.has("--video")
					and fps == 60
					and not menu
					and DisplayServer.get_name() != "headless"
				):
					await process_frame
					await RenderingServer.frame_post_draw
					if (
						root.get_texture().get_image().save_png(
							output.path_join("frame-%03d.png" % frame)
						)
						!= OK
					):
						failures += 1
			checks += 2
			if worst_left >= 0.006:
				failures += 1
			if worst_right >= 0.006:
				failures += 1
			cpu_samples.sort()
			var total := 0.0
			for sample in cpu_samples:
				total += sample
			samples.append(
				{
					"case": name,
					"left_mm": worst_left * 1000.0,
					"right_mm": worst_right * 1000.0,
					"cpu_step_mean_ms": total / cpu_samples.size(),
					"cpu_step_p95_ms": cpu_samples[ceili(cpu_samples.size() * 0.95) - 1],
					"cpu_samples": cpu_samples.size()
				}
			)
			print("[LumoGestureContact] ", JSON.stringify(samples[-1]))
	if DisplayServer.get_name() != "headless":
		kart.celebrate(0)
		kart.set_motion(0.0, 0.0, false, false)
		for frame in range(10):
			kart._process(1.0 / 30.0)
		for view in [
			["front", Vector3(0, 2.0, -4.5)],
			["side", Vector3(4.5, 2.0, 0)],
			["back", Vector3(0, 2.0, 4.5)],
			["three-quarter", Vector3(3.4, 2.0, -3.4)],
		]:
			camera.look_at_from_position(view[1], Vector3(0, 0.9, 0))
			await process_frame
			await RenderingServer.frame_post_draw
			if (
				root.get_texture().get_image().save_png(
					output.path_join("kart-" + view[0] + ".png")
				)
				!= OK
			):
				failures += 1
	var file := FileAccess.open(output.path_join("contact.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"checks": checks,
				"failures": failures,
				"samples": samples,
				"scope": "Desktop Godot fixture, 60/120 Hz input steps; not measured FPS"
			},
			"\t"
		)
	)
	file.close()
	stage.free()
	await process_frame
	print(
		"[LumoGestureContact] ",
		"PASS" if failures == 0 else "FAIL",
		" checks=",
		checks,
		" failures=",
		failures
	)
	quit(0 if failures == 0 else 1)
