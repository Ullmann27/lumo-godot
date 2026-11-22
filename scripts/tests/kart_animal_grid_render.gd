extends SceneTree
## Exercise the production race grid, player garage selection and fallback kart configuration.
## Optional --out=/path captures four directions of each seated animal on the starting grid.
const DIRECTIONS := [Vector3(.46,.35,-1), Vector3(1,.25,0), Vector3(.38,.33,1), Vector3(-1,.25,0)]
var output := ""
var failures: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _inspect(game, kart, species: String) -> void:
	var driver = kart.production_driver
	check(is_instance_valid(driver) and driver.is_usable(), species + " seated imported rig")
	if not is_instance_valid(driver):
		return
	for lod in [2, 1, 0]:
		driver.set_graphics_quality("high")
		driver.set_visual_lod(lod)
		check(driver.visual_lod == lod and driver.model_load_kind == "imported_packed_scene", species + " LOD " + str(lod))
		check(driver.skeleton.get_bone_count() == 26 and driver.player.has_animation("kart_jump"), species + " articulated rig")
	driver.apply_vehicle_sample(12.0, .85, false)
	driver.advance_tick(.15)
	check(driver.current_behavior == &"kart_steer_left", species + " steering animation")
	var error: float = driver.maximum_contact_error
	check(error < .18, "%s wheel grip error %.3f m" % [species, error])
	print("[GridDriver] ", species, " contact_m=", error, " lods=3")
	if output.is_empty():
		return
	for index in DIRECTIONS.size():
		var at: Vector3 = kart.to_global(Vector3(0,1.15,0))
		var eye: Vector3 = at + kart.global_basis.orthonormalized() * DIRECTIONS[index] * 3.75
		game.camera.fov = 34
		game.camera.look_at_from_position(eye, at)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		check(img.save_png(output.path_join("%s-%d.png" % [species,index])) == OK, species + " grid view")


func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.graphics_profile = "high"
	game.reduced_motion = true
	game.lightweight = true
	game._start_selected_race({"mode":"race", "track":"sonnenhafen", "kart":"comet", "driver":"otter", "difficulty":"flott"})
	game.set_physics_process(false)
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	root.content_scale_size = Vector2i(768,432)
	root.size = Vector2i(768,432)
	var racers: Array = [game.player]
	racers.append_array(game.opponents)
	for kart in racers:
		await _inspect(game, kart, kart.animal)
	# Use the race vehicle entry point for the remaining rotation and fallback identities.
	for id in ["frog","badger","cat"]:
		game.player.set_driver_character(id)
		await _inspect(game,game.player,id)
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("[GridDriver] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
