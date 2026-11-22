extends SceneTree

const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, description: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("[GarageLandscape] FAIL: ", description)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _run() -> void:
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	var menu = game.garage
	menu.set_landing_active(false)
	menu.step = 2
	menu._refresh()
	var parts = menu.parts_bay
	for dimensions in [Vector2i(640, 320), Vector2i(840, 400), Vector2i(2400, 1080)]:
		root.get_node("HostBridge")._options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
		root.size = dimensions
		await _settle()
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		menu._apply_responsive_layout()
		await _settle()
		var controls: Array = [menu.step_strip, menu.view_choice, menu.setup_left, menu.footer, parts.open_button, parts.stats_button]
		var safe: Rect2 = game.safe_ui.get_global_rect().grow(1.0)
		for index in range(controls.size()):
			var control: Control = controls[index]
			var bounds: Rect2 = control.get_global_rect()
			_check(control.is_visible_in_tree() and safe.encloses(bounds), "%s %s fits: %s in %s" % [dimensions, control.name, bounds, safe])
			for other in controls.slice(index + 1):
				_check(not bounds.intersects(other.get_global_rect()), "%s %s clear of %s" % [dimensions, control.name, other.name])
		var stage: Rect2 = menu._visible_stage_region()
		_check(stage.size.x >= 0.45 and stage.size.y >= 0.23, "%s kart stage has room: %s" % [dimensions, stage])
		var stage_on_screen := Rect2(menu.preview_container.global_position + stage.position * menu.preview_container.size, stage.size * menu.preview_container.size)
		for button in [menu.view_choice, parts.open_button, parts.stats_button]:
			_check(not stage_on_screen.intersects(button.get_global_rect()), "%s camera stage is free of %s" % [dimensions, button.name])
		var box := Rect2()
		var targets: Array[Vector3] = menu._stage_subject_points(true)
		var plinth: MeshInstance3D = menu.garage_interior.turntable.get_parent().get_node("GarageTurntablePlinth")
		var base := plinth.mesh as CylinderMesh
		for i in range(48):
			var angle := TAU * i / 48.0
			targets.append(plinth.to_global(Vector3(cos(angle) * base.bottom_radius, -base.height * 0.5, sin(angle) * base.bottom_radius)))
		for point in targets:
			var pixel: Vector2 = menu.preview_camera.unproject_position(point) / Vector2(menu.preview_viewport.size)
			box = Rect2(pixel, Vector2.ZERO) if box == Rect2() else box.expand(pixel)
		_check(stage.encloses(box), "%s actual kart, standing Lumo and plinth fit, normalized %s in %s" % [dimensions, box, stage])
		print("[GarageLandscape] fitted ", dimensions, " subject ", box, " region ", stage)
		parts.open_button.pressed.emit()
		await _settle()
		_check(parts.panel.is_visible_in_tree() and safe.encloses(parts.panel.get_global_rect()), "%s parts panel fits: %s in %s" % [dimensions, parts.panel.get_global_rect(), safe])
		_check(not menu.setup_left.visible and not menu.view_choice.visible, "%s uses the left column for one panel" % dimensions)
		parts.back_button.pressed.emit()
		await _settle()
		_check(not parts.is_open() and menu.view_choice.visible, "%s returns to the kart list" % dimensions)
	game.abandoned = true
	_check(await TEARDOWN.release_scene(self, game, "[GarageLandscape]"), "scene released")
	if _failures == 0:
		print("[GarageLandscape] PASS: ", _checks, " checks")
	quit(0 if _failures == 0 else 1)
