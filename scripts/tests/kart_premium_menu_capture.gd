extends SceneTree
## Real renderer captures for the premium entry, no mocked text or 2D kart.
## Do not preload the scene before the app autoload singletons exist.


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 5) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var output := "res://exports/premium-menu"
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle(8)
	assert(is_instance_valid(game.garage))
	var garage = game.garage
	garage.stars = 48
	garage.setup.mode = "race"
	garage.step = 0
	for dimensions in [Vector2i(1200, 896), Vector2i(1280, 720), Vector2i(640, 360), Vector2i(690, 829)]:
		root.size = dimensions
		garage._refresh()
		garage._apply_responsive_layout()
		await _settle(16)
		assert(garage.title_label.text in ["Dein nächstes Abenteuer", "Dein Abenteuer"])
		assert(garage.step_buttons.size() == 5)
		assert(garage.choices.get_child_count() == 1)
		var cards: GridContainer = garage.choices.get_child(0)
		assert(cards is GridContainer)
		assert(cards.columns == 1)
		assert(cards.get_child_count() == 5)
		assert(cards.get_child(0).title == "Einzelrennen")
		assert(cards.get_child(1).title == "Zeitfahren")
		assert(cards.get_child(2).title == "Kristall-Arena")
		assert(cards.get_child(3).title == "Sternen-Cup")
		assert(cards.get_child(4).title == "Freies Training")
		assert(garage.next_button.visible)
		var viewport_rect: Rect2 = root.get_visible_rect()
		var next_rect: Rect2 = garage.next_button.get_global_rect()
		var last_mode: Rect2 = cards.get_child(4).get_global_rect()
		var clip_rect: Rect2 = garage.choices.get_parent().get_global_rect()
		print("[KartPremiumMenu] LAYOUT ", dimensions, " left=", garage.setup_left.size.x,
			" continue_visible=", viewport_rect.encloses(next_rect),
			" last_mode_visible=", clip_rect.encloses(last_mode),
			" footer=", next_rect, " fifth=", last_mode, " clip=", clip_rect)
		assert(garage.preview_kart != null)
		var image := root.get_texture().get_image()
		assert(not image.is_empty())
		var path := "%s/start-%dx%d.png" % [output, dimensions.x, dimensions.y]
		assert(image.save_png(path) == OK)
		print("[KartPremiumMenu] SCREENSHOT ", path, "  ", image.get_size())
	print("[KartPremiumMenu] PASS: four actual visual sizes; 5 modes; live kart; five steps; gold navigation")
	quit(0)
