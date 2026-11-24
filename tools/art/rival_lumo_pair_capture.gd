extends SceneTree
## Each rival directly beside the real Lumo: same kart, same camera, same light.
## Writes pair_<id>.png (both karts, three-quarter front), face_<id>.png
## (both heads), face_close_<id>.png / face_close_lumo.png (one head each, same
## camera) and side_<id>.png for every requested rival (default: kart roster).
## Usage: godot --path . --rendering-method gl_compatibility \
##   --script res://tools/art/rival_lumo_pair_capture.gd -- /abs/out_dir [id ...]

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const GAP := 2.3
## Head height of a seated driver above the kart origin (face close-ups).
const HEAD_Y := 1.27


func _initialize() -> void:
	call_deferred("_capture")


func _shot(
	viewport: SubViewport, camera: Camera3D, from: Vector3, at: Vector3, path: String
) -> void:
	camera.look_at_from_position(from, at)
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("[RivalLumoPair] cannot write " + path)


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/lumo-pair"
	var wanted: Array[String] = []
	for index in range(1, args.size()):
		wanted.append(args[index])
	if wanted.is_empty():
		for entry: Dictionary in ROSTER.for_game("kart"):
			wanted.append(str(entry.id))
	DirAccess.make_dir_recursive_absolute(out)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c9d6e6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dfe8f5")
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -40, 0)
	rim.light_energy = 0.5
	stage.add_child(rim)
	var lumo = VEHICLE.new()
	lumo.configure("fox", Color("6987db"), "comet")
	lumo.set_process(false)
	lumo.position.x = -0.5 * GAP
	stage.add_child(lumo)
	# The real rigged Lumo, as in the race, not the procedural stand-in.
	lumo.set_animated_lumo_enabled(true)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	for id in wanted:
		var color := Color("e9eff8")
		for entry: Dictionary in ROSTER.for_game("kart"):
			if str(entry.id) == id:
				color = Color(str(entry.color))
		var kart = VEHICLE.new()
		kart.configure(id, color, "comet")
		kart.set_process(false)
		kart.position.x = 0.5 * GAP
		stage.add_child(kart)
		# Hold both drivers in their seated pose (eyes open, no blink) so the
		# comparison never depends on how fast this software renderer runs.
		for frame in range(3):
			await process_frame
		kart.process_mode = Node.PROCESS_MODE_DISABLED
		lumo.process_mode = Node.PROCESS_MODE_DISABLED
		camera.fov = 26.0
		await _shot(
			viewport,
			camera,
			Vector3(1.0, 2.4, -7.6),
			Vector3(0, 1.05, 0),
			out + "/pair_%s.png" % id
		)
		camera.fov = 22.0
		await _shot(
			viewport,
			camera,
			Vector3(0.0, 1.75, -4.4),
			Vector3(0, 1.22, 0),
			out + "/face_%s.png" % id
		)
		# Close head shots with one fixed camera (rival, then Lumo) for the
		# face boards, and a side view that shows how the body sits in the kart.
		camera.fov = 16.0
		await _shot(
			viewport,
			camera,
			Vector3(0.5 * GAP, HEAD_Y + 0.08, -2.6),
			Vector3(0.5 * GAP, HEAD_Y, 0),
			out + "/face_close_%s.png" % id
		)
		await _shot(
			viewport,
			camera,
			Vector3(-0.5 * GAP, HEAD_Y + 0.08, -2.6),
			Vector3(-0.5 * GAP, HEAD_Y, 0),
			out + "/face_close_lumo.png"
		)
		camera.fov = 26.0
		await _shot(
			viewport,
			camera,
			Vector3(0.5 * GAP + 5.2, 1.3, 0.25),
			Vector3(0.5 * GAP, 0.9, 0.25),
			out + "/side_%s.png" % id
		)
		kart.queue_free()
		lumo.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
	print("[RivalLumoPair] PASS ", JSON.stringify({"ids": wanted, "dir": out}))
	viewport.queue_free()
	await create_timer(0.2).timeout
	quit(0)
