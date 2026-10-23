extends Node

func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("_run")

func _run() -> void:
	assert(not OS.get_cmdline_args().has("--script"))
	get_window().size = Vector2i(1280, 720)
	get_tree().change_scene_to_file("res://scenes/app/boot.tscn")
	var deadline := Time.get_ticks_msec() + 30000
	var game: Node
	var from_hub := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		game = get_tree().current_scene
		if game != null and game.scene_file_path == "res://scenes/games/game_hub.tscn":
			from_hub = true
			for i in range(12):
				await get_tree().process_frame
			var actions := game.find_child("ScrollableRealGameActions", true, false) as ScrollContainer
			var kart := game.find_child("GameRoute_kart", true, false) as Button
			actions.ensure_control_visible(kart)
			for i in range(4):
				await get_tree().process_frame
			assert(actions.get_global_rect().encloses(kart.get_global_rect()))
			var scale := Vector2(get_window().size) / get_viewport().get_visible_rect().size
			for pressed in [true, false]:
				var touch := InputEventScreenTouch.new()
				touch.index = 1
				touch.position = kart.get_global_rect().get_center() * scale
				touch.pressed = pressed
				Input.parse_input_event(touch)
				await get_tree().process_frame
		if game != null and game.scene_file_path == "res://scenes/games/kart_island.tscn":
			break
	assert(game != null and game.scene_file_path == "res://scenes/games/kart_island.tscn", "Production boot must reach kart")
	for i in range(8):
		await get_tree().process_frame
	assert(game.reference_landing != null and game.reference_landing.visible, "Production launch mounts premium landing automatically")
	assert(not game.garage.visible and game.menu_active and not is_instance_valid(game.player))
	if from_hub and is_instance_valid(game.intro):
		for pressed in [true, false]:
			var skip := InputEventScreenTouch.new()
			skip.index = 2
			skip.position = Vector2(get_window().size) * 0.5
			skip.pressed = pressed
			Input.parse_input_event(skip)
			await get_tree().process_frame
		deadline = Time.get_ticks_msec() + 30000
		while is_instance_valid(game.intro) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	assert(not is_instance_valid(game.intro), "Real touch skips the hub entry intro; direct boot avoids duplication")
	if DisplayServer.get_name() != "headless" and not OS.get_environment("LUMO_AUDIT_OUTPUT").is_empty():
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(OS.get_environment("LUMO_AUDIT_OUTPUT")) == OK)
	var landing = game.reference_landing
	landing.find_child("Landing_time_trial", true, false).pressed.emit()
	assert(landing.visible and not game.garage.visible and game.garage.setup.mode == "time_trial")
	landing.find_child("LiveQuickStart", true, false).pressed.emit()
	assert(not game.menu_active and game.mode == "time_trial" and is_instance_valid(game.player))
	print("[ProductionEntryAudit] PASS: real boot, automatic premium landing, no wizard fallback, direct time-trial race")
	game.abandoned = true
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
