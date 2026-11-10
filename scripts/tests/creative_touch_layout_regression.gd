extends SceneTree
## Verify actual viewport transforms and Android density, not logical minima alone.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_warning("[CreativeTouchLayout] " + label)


func _settle() -> void:
	for _frame in range(8):
		await physics_frame


func _buttons(node: Node, output: Array[BaseButton]) -> void:
	if node is BaseButton and node.is_visible_in_tree():
		output.append(node)
	for child in node.get_children():
		_buttons(child, output)


func _measure(game: Node, label: String, density: float) -> void:
	var targets: Array[BaseButton] = []
	_buttons(game, targets)
	var physical_scale := Vector2(root.size) / root.get_visible_rect().size
	for button in targets:
		var dp := button.size * physical_scale / density
		_check(dp.x >= 47.95 and dp.y >= 47.95, "%s %s is %s dp" % [label, button.text, dp])
	_check(not targets.is_empty(), label + " has interactive controls")
	var visible := root.get_visible_rect()
	for button in targets:
		if button.text in ["‹ Spiele", "Ⅱ"]:
			_check(visible.encloses(button.get_global_rect()), label + " header remains on screen")


func _run() -> void:
	var host = root.get_node("HostBridge")
	var capture_dir := OS.get_environment("CREATIVE_TOUCH_CAPTURE_DIR")
	var cases := [
		[Vector2i(412, 915), 1.0],
		[Vector2i(690, 829), 1.0],
		[Vector2i(1280, 720), 1.0],
		[Vector2i(1236, 2745), 3.0],
	]
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	for name in ["puzzle", "build"]:
		for sample in cases:
			var density: float = sample[1]
			if not capture_dir.is_empty() and density > 1.0:
				continue  # The full-density case runs headlessly without huge capture buffers.
			host._options["displayDensity"] = density
			root.size = sample[0]
			root.get_node("SceneRouter").launch_options = {"childKey": "touch_layout_regression"}
			var game = load("res://scenes/creative/%s_world.tscn" % name).instantiate()
			root.add_child(game)
			await _settle()
			var label := "%s %s density %.1f" % [name, sample[0], density]
			if name == "puzzle":
				_check(
					root.get_visible_rect().encloses(game.menu.get_global_rect()),
					label + " menu fits"
				)
				game.selected_count = 6
				game.start()
				await _settle()
				if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var error := root.get_texture().get_image().save_png(
						capture_dir.path_join("puzzle_ready_%dx%d.png" % [root.size.x, root.size.y])
					)
					_check(error == OK, label + " playable tray renderer capture")
				for id in range(6):
					game._tray()
					await physics_frame
					await physics_frame
					var point: Vector2 = game.camera.unproject_position(
						game.nodes[id].global_position + Vector3(0.11, 0.16, 0.07)
					)
					_check(
						root.get_visible_rect().has_point(point), label + " tray piece on screen"
					)
					game._pick(point, 0)
					if game.dragging != id:
						var ray_from: Vector3 = game.camera.project_ray_origin(point)
						var ray_to: Vector3 = ray_from + game.camera.project_ray_normal(point) * 100
						print(
							"[CreativeTouchLayout] pick ",
							id,
							" paused=",
							game.paused,
							" point=",
							point,
							" position=",
							game.nodes[id].global_position,
							" server=",
							PhysicsServer3D.body_get_state(
								game.nodes[id].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM
							),
							" ray=",
							game.get_world_3d().direct_space_state.intersect_ray(
								PhysicsRayQueryParameters3D.create(ray_from, ray_to)
							)
						)
					_check(
						game.dragging == id,
						label + " actual ray picks visible piece %d (got %d)" % [id, game.dragging]
					)
					var target: Vector2 = game.model.target(id)
					game._drag(game.camera.unproject_position(Vector3(target.x, 0.35, target.y)))
					game._drop()
				_check(
					game.model.complete(), label + " full puzzle playable after responsive layout"
				)
				game._continue()
			_measure(game, label, density)
			# Scroll all the way to the last toolbar action and check reachability.
			var scroll: ScrollContainer = game.find_child("PuzzleToolsScroll", true, false)
			if scroll != null:
				scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value)
				await _settle()
				var actions: Array[BaseButton] = []
				_buttons(scroll, actions)
				var last: Control = actions.back()
				_check(
					root.get_visible_rect().encloses(last.get_global_rect()),
					label + " final puzzle action reachable by horizontal scrolling"
				)
				scroll.scroll_horizontal = 0
			if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
				await _settle()
				await RenderingServer.frame_post_draw
				var error := root.get_texture().get_image().save_png(
					capture_dir.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
				)
				_check(error == OK, label + " renderer capture")
			game.queue_free()
			await _settle()
			host._options.erase("displayDensity")
	if failures.is_empty():
		print(
			(
				"[CreativeTouchLayout] PASS %d checks: transformed dp, portrait, Fold and density"
				% checks
			)
		)
		quit(0)
	else:
		print("[CreativeTouchLayout] FAIL ", failures)
		quit(1)
