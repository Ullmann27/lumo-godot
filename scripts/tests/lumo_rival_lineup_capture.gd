extends SceneTree
## Real product vehicle renderer, same camera for before/after opponent review.
## Does not start a race, modify rewards, or replace an installed APK.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "/tmp/lumo-rivals.png"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 640)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101b30")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b7d0ef")
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 145, 0)
	key.light_energy = 1.25
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -40, 0)
	rim.light_energy = 0.45
	stage.add_child(rim)
	var ids: Array[String] = ["otter", "rabbit", "badger", "cat", "fox"]
	var colors: Array[Color] = [Color("75d7f1"), Color("a696ee"), Color("83dab9"), Color("c8d8ef"), Color("6987db")]
	var ready: bool = ROSTER.ready_for_race()
	var entries := ROSTER.for_game("kart")
	if ready:
		for index in range(ids.size()):
			ids[index] = str(entries[index].id)
			colors[index] = Color(str(entries[index].color))
	for index in range(ids.size()):
		var kart = VEHICLE.new()
		kart.set_meta("reference_rival", ready)
		kart.configure(ids[index], colors[index], "comet")
		kart.set_process(false)
		kart.position.x = (index - 2) * 3.0
		stage.add_child(kart)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3.0, -12.0), Vector3(0, 1.0, 0))
	camera.current = true
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image != null and not image.is_empty())
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(image.save_png(output) == OK)
	print("[RivalLineup] PASS ", JSON.stringify({
		"image": output.get_file(),
		"identities": ids,
		"reference_models_active": ready,
		"actual_product_vehicle_renderer": true,
		"physical_android_device": false,
		"size": [1800, 640],
	}))
	viewport.free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0)
