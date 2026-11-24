extends SceneTree
var game

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(12):
		await process_frame

func _dump(label: String) -> void:
	var menu = game.garage
	var scroll: ScrollContainer = menu.choices.get_parent()
	var card: Button = menu.choices.get_child(0).get_node("KartCard_gecko_velo")
	var pixels := Vector2(root.size) / root.get_visible_rect().size
	var scale: float = menu._preview_dp_scale()
	var srect := scroll.get_global_rect()
	var crect := card.get_global_rect()
	print("CARD_BOUNDS ", label, " viewport_px=", root.size, " density=", root.get_node("MobileRuntime").get_ui_density(),
		" safe_dp=", game.safe_ui.size / scale, " root_pixels_per_logical=", pixels,
		" scroll_px=", Rect2(srect.position * pixels, srect.size * pixels), " scroll_dp=", scroll.size / scale,
		" card_px=", Rect2(crect.position * pixels, crect.size * pixels), " card_dp=", card.size / scale,
		" card_min_dp=", card.get_combined_minimum_size() / scale,
		" fully_enclosed=", srect.grow(0.01).encloses(crect), " vertical_scroll=", scroll.scroll_vertical,
		" workshop_parent=", menu.workshop_button.get_parent().get_class(), " footer_columns=", menu.footer.columns)

func _run() -> void:
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	root.size = Vector2i(2400, 1080)
	await _settle()
	game._apply_safe_area(Rect2(0, 32, 0, 126), Vector2(root.size))
	game._reference_select_mode("garage")
	await _settle()
	var menu = game.garage
	menu.setup.kart = "gecko_velo"
	menu._refresh()
	await _settle()
	_dump("fresh selected Gecko")
	var scroll: ScrollContainer = menu.choices.get_parent()
	var card: Button = menu.choices.get_child(0).get_node("KartCard_gecko_velo")
	scroll.ensure_control_visible(card)
	await _settle()
	_dump("after ensure_control_visible")
	# Align its upper edge exactly: even this best position cannot enlarge
	# the viewport or make an intrinsically taller card fit within it.
	scroll.scroll_vertical += roundi(card.global_position.y - scroll.global_position.y)
	await _settle()
	_dump("card top aligned with viewport")
	game.abandoned = true
	game.queue_free()
	await _settle()
	quit()
