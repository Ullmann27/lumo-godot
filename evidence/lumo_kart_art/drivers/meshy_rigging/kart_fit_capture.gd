extends SceneTree
## Real-engine review sheet for every kart driver: 3/4 face close-up plus a side
## cockpit view (seat, hands on the rim, steering column). Usage:
##   godot --rendering-method gl_compatibility --script res://scripts/tests/kart_driver_fit_capture.gd -- <out.png> [steer]
## Draws the actual LumoRaceKart renderer; it starts no race and writes no save.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const ANIMALS: Array[String] = ["fox", "rabbit", "frog", "lion", "owl", "squirrel", "turtle", "otter", "badger", "cat"]
const CELL := Vector2i(420, 420)
const COLUMNS := 5


func _initialize() -> void:
	call_deferred("_capture")


func _view(stage_color: Color) -> Array:
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = stage_color
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9dcf2")
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 150, 0)
	key.light_energy = 1.2
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -35, 0)
	rim.light_energy = 0.5
	stage.add_child(rim)
	return [viewport, stage]


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "/tmp/lumo-driver-fit.png"
	var steer: float = float(args[1]) if args.size() > 1 else 0.0
	var views: Array = []
	var karts: Array = []
	var models: Array[Dictionary] = []
	var vehicle_sources: Dictionary = {}
	for index in range(ANIMALS.size()):
		for shot in range(3):
			var pair: Array = _view([Color("13213a"), Color("1b2c47"), Color("223a52")][shot])
			var kart = VEHICLE.new()
			kart.configure(ANIMALS[index], CATALOG.entry(CATALOG.DRIVERS, ANIMALS[index]).color, "comet")
			pair[1].add_child(kart)
			assert(is_instance_valid(kart.production_vehicle) and kart.production_vehicle.asset_root != null,
				"Capture requires the actual imported Comet chassis")
			assert(kart.production_vehicle.variant == "comet" and is_instance_valid(kart.production_vehicle.meshy_close_mesh),
				"Capture requires the existing Meshy Comet shell")
			if index == 0 and shot == 0:
				var vehicle_paths: Array = kart.production_vehicle.source_paths.duplicate()
				vehicle_paths.append(kart.production_vehicle.shell_path)
				for path in vehicle_paths:
					vehicle_sources[str(path)] = FileAccess.get_sha256(str(path))
			if ANIMALS[index] == "fox":
				kart.set_animated_lumo_enabled(true)
				assert(is_instance_valid(kart.lumo_animation), "Capture requires the original animated Lumo")
			kart.set_motion(0.0, steer, false, false)
			# Drive the real mechanical and skeletal APIs for 0.2 seconds, then
			# freeze with the existing pause API so renderer timing cannot pick a blink.
			kart.production_vehicle.apply_motion(0.0, steer)
			for pose_step in range(6):
				if ANIMALS[index] == "fox":
					if is_instance_valid(kart.production_lumo_seat):
						kart.production_lumo_seat.prepare_animation_frame()
					kart.lumo_animation.apply_vehicle_sample(0.0, steer, false)
					kart.lumo_animation.advance_tick(1.0 / 30.0)
					if is_instance_valid(kart.production_lumo_seat):
						kart.production_lumo_seat.advance_tick()
				else:
					kart.production_driver.apply_vehicle_sample(0.0, steer, false)
					kart.production_driver.advance_tick(1.0 / 30.0)
			kart.set_driver_runtime_state(false, false, true)
			if ANIMALS[index] != "fox":
				assert(is_instance_valid(kart.production_driver) and kart.production_driver.is_usable(),
					"Capture requires the actual imported driver: " + ANIMALS[index])
				if shot == 0:
					models.append({"driver": ANIMALS[index], "path": kart.production_driver.model_path,
						"sha256": FileAccess.get_sha256(kart.production_driver.model_path),
						"clip": str(kart.production_driver.current_behavior),
						"sample_time_seconds": kart.production_driver.current_sample_time,
						"elapsed_seconds": kart.production_driver.elapsed, "suspended": kart.production_driver.suspended})
			karts.append(kart)
			var camera := Camera3D.new()
			pair[1].add_child(camera)
			if shot == 0:
				camera.fov = 26.0
				var face_skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton if ANIMALS[index] == "fox" else kart.production_driver.skeleton
				var eye_left := face_skeleton.find_bone("Head" if ANIMALS[index] == "fox" else "Eye.L")
				var eye_right := face_skeleton.find_bone("Crown" if ANIMALS[index] == "fox" else "Eye.R")
				assert(eye_left >= 0 and eye_right >= 0, "Review framing uses actual face anchors")
				var eye_midpoint: Vector3 = (face_skeleton.get_bone_global_pose(eye_left).origin + face_skeleton.get_bone_global_pose(eye_right).origin) * 0.5
				var focus: Vector3 = face_skeleton.to_global(eye_midpoint) - Vector3.UP * 0.06
				camera.look_at_from_position(focus + Vector3(-1.05, 0.43, -2.50), focus)
			elif shot == 1:
				camera.fov = 30.0
				camera.look_at_from_position(Vector3(-3.6, 1.45, -0.35), Vector3(0, 1.05, -0.12))
			else:
				camera.fov = 34.0
				camera.look_at_from_position(Vector3(0.9, 2.6, 3.4), Vector3(0, 1.0, -0.4))
			camera.current = true
			views.append(pair[0])
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var worst_contact := 0.0
	var contacts: Dictionary = {}
	var contact_failures: Array[String] = []
	for kart in karts:
		if kart.animal == "fox":
			continue
		var skeleton: Skeleton3D = kart.production_driver.skeleton
		for side in range(2):
			var bone := skeleton.find_bone("Hand.L" if side == 0 else "Hand.R")
			var hand: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
			var grip: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[side])
			var error := hand.distance_to(grip)
			worst_contact = maxf(worst_contact, error)
			contacts[kart.animal] = maxf(float(contacts.get(kart.animal, 0.0)), error)
			if error >= 0.001:
				contact_failures.append("Imported Comet grip error exceeds 1 mm: %s %.6f" % [kart.animal, error])
	var groups := ceili(float(ANIMALS.size()) / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 3 * groups, false, Image.FORMAT_RGBA8)
	for index in range(views.size()):
		var image: Image = views[index].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var animal_index: int = index / 3
		var group: int = animal_index / COLUMNS
		var column: int = animal_index % COLUMNS
		var row: int = group * 3 + index % 3
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(sheet.save_png(output) == OK)
	print("[DriverFit] ", "PASS " if contact_failures.is_empty() else "FAIL ", JSON.stringify({"image": output, "drivers": ANIMALS, "models": models, "steer": steer, "vehicle_sources": vehicle_sources, "maximum_hand_error_m": worst_contact, "hand_error_by_driver_m": contacts, "contact_failures": contact_failures, "pose_advance_seconds": 0.2, "pose_method": "Six real 30 Hz driver samples, actual chassis steering, existing pause API"}))
	for view in views:
		view.free()
	await process_frame
	quit(0 if contact_failures.is_empty() else 1)
