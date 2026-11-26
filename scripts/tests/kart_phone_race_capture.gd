extends SceneTree

var game
var folder := OS.get_environment("LUMO_CONTROL_PHOTOS")

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless" or folder.is_empty():
		push_error("Supply an X11 renderer and LUMO_CONTROL_PHOTOS.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	RenderingServer.render_loop_enabled = false
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.lightweight = true
	game._start_selected_race({"mode":"race","driver":"fox","kart":"comet","track":"sonnenhafen","difficulty":"gemuetlich"})
	game._end_preview()
	game.set_physics_process(false)
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.auto_gas = true
	game.item = "star_rocket"
	game.boosts = 1
	game.modal.hide()
	var anchor := 126.0
	game.previous_road_distance = anchor
	game.distance = anchor
	game.speed = 19.5
	var forward: Vector3 = game.world.forward(anchor)
	game.player_heading = atan2(-forward.x, -forward.z)
	game.player.position = game.world.position_at(anchor)
	game.player.rotation.y = game.player_heading
	game.message.text = ""
	game._update_hud()
	var surfaces: Array[Vector2i] = [
		Vector2i(904, 2316), Vector2i(2316, 904), Vector2i(1080, 2340),
		Vector2i(1080, 2520), Vector2i(2520, 1080),
	]
	var only := OS.get_environment("LUMO_CONTROL_ONLY")
	for surface in surfaces:
		if not only.is_empty() and only != "%dx%d" % [surface.x, surface.y]:
			continue
		root.size = surface
		await frames(3)
		var insets := Rect2(0, 44, 0, 52) if surface.x < surface.y else Rect2(38, 0, 42, 26)
		game._apply_safe_area(insets, Vector2(surface))
		game._apply_responsive_layout()
		game._update_camera(0.10, true)
		await frames(5)
		RenderingServer.render_loop_enabled = true
		await frames(3)
		await RenderingServer.frame_post_draw
		var file := folder.path_join("%dx%d.png" % [surface.x,surface.y])
		assert(root.get_texture().get_image().save_png(file) == OK)
		print("Capture ",file," gas visible ",game.gas_button.is_visible_in_tree(), " brake size ",game.brake_button.size)
		RenderingServer.render_loop_enabled = false
	game.abandoned = true
	game.queue_free()
	await frames(6)
	quit()
