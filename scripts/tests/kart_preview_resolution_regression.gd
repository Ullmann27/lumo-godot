extends SceneTree
## Engine-requested 3D dimensions in the production Home and Garage. This is
## a resolution contract, not a measurement of physical GPU frame rate.
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[KartPreviewResolution] " + label)


func _settle() -> void:
	for _frame in range(10):
		await process_frame


func _verify(menu, expected: Vector2, label: String) -> void:
	var viewport: SubViewport = menu.preview_viewport
	var requested_3d := Vector2(viewport.size) * viewport.scaling_3d_scale
	var difference := requested_3d - expected
	_check(difference.x >= -0.5 and difference.x < 1.5 and difference.y >= -0.5 and difference.y < 1.5, label + " 3D target matches the displayed physical pixels")
	_check(viewport.msaa_3d == Viewport.MSAA_4X, label + " retains the high-profile 4x MSAA")
	_check(viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, label + " uses Compatibility-supported bilinear scaling")
	_check(menu.preview_container.stretch and menu.preview_container.stretch_shrink == 1, label + " keeps logical presentation and input coordinates")
	_check(viewport.scaling_3d_scale <= 1.0, label + " does not introduce supersampling")
	print("[KartPreviewResolution] TARGET ", label, " logical=", viewport.size,
		" scale=", viewport.scaling_3d_scale, " requested_3d=", requested_3d, " displayed=", expected)


func _run() -> void:
	root.get_node("HostBridge")._options["displayDensity"] = 1.0
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(640, 320)]:
		root.size = dimensions
		await _settle()
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		game._show_reference_landing(true)
		await _settle()
		var menu = game.garage
		var expected := Vector2(dimensions - Vector2i(24, 36))
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		_verify(menu, expected, "home-" + suffix)
		game.reference_landing._navigation.get_node("Open_garage").pressed.emit()
		await _settle()
		_verify(menu, expected, "garage-" + suffix)
		if dimensions == Vector2i(1280, 720):
			# Keep this fixture's logical surface constant: desktop resize reports
			# zero native insets, so clear the earlier synthetic phone insets first.
			game._apply_safe_area(Rect2(), Vector2(dimensions))
			await _settle()
			var logical_canvas := root.get_visible_rect().size
			var logical_preview: Vector2i = menu.preview_viewport.size
			root.size = Vector2i(640, 360)
			await _settle()
			_check(root.get_visible_rect().size.is_equal_approx(logical_canvas), "same-aspect resize keeps the 1280px logical canvas")
			_check(menu.preview_viewport.size == logical_preview, "same-aspect resize keeps the logical preview buffer")
			_verify(menu, Vector2(dimensions) * 0.5, "same-aspect-half-window")
			root.size = dimensions
			await _settle()
			_verify(menu, Vector2(dimensions), "same-aspect-restored-window")
		menu.back_button.pressed.emit()
		await _settle()
	game.queue_free()
	await _settle()
	print("[KartPreviewResolution] ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	quit(0 if failures.is_empty() else 1)
