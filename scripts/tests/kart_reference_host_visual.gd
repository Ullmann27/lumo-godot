extends SceneTree
## Tests the production Kart owner, not only an isolated UI mock.
## Existing --script regressions launch the garage by default; this fixture
## explicitly opens the new front layer over the real game scene.
func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 12) -> void:
	for i in range(frames):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _run() -> void:
	var game := (load("res://scenes/games/kart_island.tscn") as PackedScene).instantiate()
	game.lightweight = true
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(15)
	assert(is_instance_valid(game.garage), "Original real setup must remain available")
	game._show_reference_landing()
	await _settle()
	assert(is_instance_valid(game.reference_landing), "Live Kart owner must mount the reference landing")
	var landing: Control = game.reference_landing
	var required_images: Array[String] = [
		"sunset_world.webp", "cinematic_hero.webp", "kart_logo_art.webp",
		"grand_prix_art.webp", "time_trial_art.webp", "sonnenhafen_art.webp",
		"garage_art.webp", "settings_art.webp", "lumo_avatar.webp"
	]
	for image_file in required_images:
		assert(ResourceLoader.exists("res://assets/kart/landing/" + image_file),
			"Production art is missing: " + image_file)
	var card: Button = landing.find_child("Landing_time_trial", true, false)
	assert(card != null)
	card.pressed.emit()
	assert(game.garage.setup.mode == "time_trial", "Time trial failed to enter real game setup")
	assert(landing.visible, "Selecting a mode must stay in the premium menu until START")
	game._show_reference_landing()
	await _settle()
	landing = game.reference_landing
	(landing.find_child("Landing_sonnenhafen", true, false) as Button).pressed.emit()
	assert(game.garage.setup.track == "sonnenhafen" and landing.visible,
		"Selecting Sonnenhafen must not throw the player back into the old wizard")
	game._show_reference_landing()
	await _settle()
	landing = game.reference_landing
	assert(landing.find_child("LiveQuickStart", true, false) is Button,
		"Main Start is not a real button")
	assert(landing.quick_start.get_connections().size() > 0,
		"Main Start is not connected to the game owner")
	if DisplayServer.get_name() != "headless":
		var destination := "res://exports/nextgen-ui/"
		DirAccess.make_dir_recursive_absolute(destination)
		for dimensions in [Vector2i(1280, 720), Vector2i(690, 829)]:
			root.size = dimensions
			await _settle(18)
			var image := root.get_texture().get_image()
			var file := "host-landing-%dx%d.png" % [dimensions.x, dimensions.y]
			assert(image.save_png(destination + file) == OK)
			print("[ReferenceHost] SCREENSHOT ", destination + file)
	(landing.find_child("LiveQuickStart", true, false) as Button).pressed.emit()
	await _settle()
	assert(not game.menu_active and game.mode == "cup",
		"The selected premium START must directly launch the real Kart race")
	assert(is_instance_valid(game.player) and game.opponents.size() == 5,
		"Premium START must initialize a real kart and competitors")
	game.queue_free()
	await _settle()
	print("[ReferenceHost] PASS: brand-consistent modes, live premium START, 3D Kart race and navigation")
	quit(0)
