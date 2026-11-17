extends SceneTree
## Requires a real rendering backend; headless mode never counts as a capture.
const WORLD := "res://scenes/learning/learning_world.tscn"
var output := "res://exports/studio-sharing"
var failures := 0
var captures: Array[Dictionary] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("[LearningSharingCapture] FAIL " + message)


func _settle() -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func _tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _capture(game: Node3D, caption: String) -> void:
	await _settle()
	var raster := root.get_texture().get_image()
	_check(raster != null and raster.get_size() == root.size, "actual renderer raster dimensions")
	if raster == null:
		return
	var begin: float = game.header.get_global_rect().end.y + 4
	var end: float = game.footer.get_global_rect().position.y - 4
	var body := Rect2(6, begin, root.size.x - 12, end - begin)
	var objects: Array[Node3D] = []
	objects.append_array(game.tokens)
	objects.append_array(game._group_labels)
	for node in objects:
		var bounds: AABB = node.get_aabb()
		for corner in range(8):
			var point: Vector2 = game.camera.unproject_position(
				node.to_global(bounds.get_endpoint(corner))
			)
			_check(body.has_point(point), caption + " shows complete object " + str(node.name))
	var counts: Array[int] = []
	for group in range(game.activity.b):
		counts.append(game.activity.count_in_group(group))
		_check(
			game._group_labels[group].mesh.text == str(counts[-1]),
			"3D number equals actual group population"
		)
	var filename := "%s-%dx%d.png" % [caption, root.size.x, root.size.y]
	_check(raster.save_png(output.path_join(filename)) == OK, "renderer screenshot saved")
	captures.append(
		{
			"file": filename,
			"width": root.size.x,
			"height": root.size.y,
			"placed": game.activity.placed.size(),
			"counts": counts,
			"complete": game.activity.is_complete()
		}
	)
	print("[LearningSharingCapture] SCREENSHOT " + filename)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LearningSharingCapture] Real renderer required; headless rejected")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for size_value in [Vector2i(1280, 720), Vector2i(412, 915)]:
		root.size = size_value
		var game = (load(WORLD) as PackedScene).instantiate()
		game.capture_options = {
			"learning": {"kind": "equal_sharing", "a": 12, "b": 3}, "reduceAnimations": true
		}
		root.add_child(game)
		await _settle()
		await _capture(game, "sharing-start")
		for step in range(12):
			await _tap(game.main_button.get_global_rect().get_center())
			_check(
				game.activity.placed.size() == step + 1, "real touch distributes exactly one cube"
			)
			if step == 2:
				await _capture(game, "sharing-first-round")
		await _capture(game, "sharing-complete")
		game.queue_free()
		await _settle()
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(
			JSON.stringify(
				{
					"display": DisplayServer.get_name(),
					"renderer": RenderingServer.get_current_rendering_method(),
					"activity": {"kind": "equal_sharing", "a": 12, "b": 3},
					"captures": captures,
					"failures": failures
				},
				"  "
			)
		)
		manifest.close()
	else:
		_check(false, "capture manifest saved")
	_check(captures.size() == 6, "all six before/during/after views captured")
	print(
		(
			"[LearningSharingCapture] %s captures=%d"
			% ["PASS" if failures == 0 else "FAIL", captures.size()]
		)
	)
	quit(0 if failures == 0 else 1)
