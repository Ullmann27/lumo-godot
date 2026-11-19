extends SceneTree
## Echtes Rennen in Sonnenhafen, eingefroren in der Startaufstellung: einmal die
## Spielkamera hinter Lumo, einmal eine Kamera vor dem Feld, damit die Gesichter der
## Mitspieler in ihren Karts zu sehen sind. Kein Bildfrequenz-Messwert.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://tools/art/rival_start_grid_capture.gd -- /abs/out_dir
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")


func _initialize() -> void:
	call_deferred("_run")


func _save(path: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("[StartGrid] cannot write " + path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "/tmp/lumo-start-grid"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.intro_mode = "off"
	root.add_child(game)
	for i in range(6):
		await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	game.preview_left = 0.0
	game._update_camera(0.1, true)
	for i in range(8):
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var karts: Array[Node3D] = []
	for node in game.find_children("*", "", true, false):
		if node.get_script() == VEHICLE and node is Node3D and node.is_visible_in_tree():
			karts.append(node)
			node.process_mode = Node.PROCESS_MODE_DISABLED
	game.countdown = 2.8
	game.start_green_left = 0.0
	game._update_start_lights(0.0)
	await _save(out + "/start_spielkamera.png")
	var ids: Array[String] = []
	var center := Vector3.ZERO
	var forward := Vector3.ZERO
	for kart in karts:
		ids.append(str(kart.get("animal")))
		center += kart.global_position
		forward += -kart.global_basis.z
	if not karts.is_empty():
		center /= karts.size()
		forward = forward.normalized()
		var camera := Camera3D.new()
		camera.fov = 42.0
		game.add_child(camera)
		camera.global_position = center + forward * 9.0 + Vector3.UP * 2.6
		camera.look_at(center + Vector3.UP * 1.1, Vector3.UP)
		camera.current = true
		await _save(out + "/start_feld_vorn.png")
		# Close look at the two karts nearest the camera.
		camera.fov = 26.0
		camera.global_position = center + forward * 6.0 + Vector3.UP * 1.9
		camera.look_at(center + Vector3.UP * 1.1, Vector3.UP)
		await _save(out + "/start_feld_nah.png")
	print(
		"[StartGrid] PASS ",
		JSON.stringify({"karts": ids, "dir": out, "physical_android_device": false})
	)
	game.queue_free()
	await process_frame
	quit()
