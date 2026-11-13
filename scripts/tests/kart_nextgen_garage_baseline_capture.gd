extends SceneTree
## Copy this capture-only script into the exact pre-change checkout. It uses
## only PR156 production APIs and captures actual entry/selection at fixed sizes.
var game
var failures := 0
var output := "res://exports/nextgen-garage-before"


func _initialize() -> void:
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _settle() -> void:
	for _frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw


func _tap(button: Control) -> void:
	var pixel: Vector2 = button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = pixel
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _shot(label: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != root.size or image.save_png(output.path_join(label + ".png")) != OK:
		failures += 1
		push_error("[NextGenGarageBefore] invalid raster: " + label)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[NextGenGarageBefore] A real renderer is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var host = root.get_node("HostBridge")
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]:
		host._options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
		game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await _settle()
		root.size = dimensions
		await _settle()
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		game._show_reference_landing(true)
		await _settle()
		await _tap(game.reference_landing._navigation.get_node("Open_garage"))
		if game.garage.step != 2:
			failures += 1
		await _shot("garage-%dx%d" % [dimensions.x, dimensions.y])
		var cards: GridContainer = game.garage.choices.get_child(0)
		var selected: Button = cards.get_node("KartCard_gecko_velo")
		game.garage.choices.get_parent().ensure_control_visible(selected)
		await _settle()
		await _tap(selected)
		if game.garage.setup.kart != "gecko_velo":
			failures += 1
		await _shot("selection-%dx%d" % [dimensions.x, dimensions.y])
		game.queue_free()
		await _settle()
	print("[NextGenGarageBefore] ", "PASS" if failures == 0 else "FAIL", " six renderer captures")
	quit(0 if failures == 0 else 1)
