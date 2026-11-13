extends SceneTree
## Renderer-only acceptance. Never produces a success marker in headless mode.
var output := "res://exports/nextgen-learning"
var captures := 0
var failures := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _settle() -> void:
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("[LearningCapture] FAIL " + message)


func _tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _capture(game: Node3D, name_value: String, size_value: Vector2i) -> void:
	await _settle()
	var raster := root.get_texture().get_image()
	_check(raster != null and raster.get_size() == size_value, "raster dimensions " + name_value)
	if raster == null:
		return
	var orange := 0
	var lit := 0
	var begin: int = int(game.header.get_global_rect().end.y + 4)
	var end: int = int(game.footer.get_global_rect().position.y - 4)
	for y in range(begin, end, 3):
		for x in range(10, size_value.x - 10, 3):
			var pixel := raster.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.3:
				lit += 1
			if pixel.r > 0.3 and pixel.r > pixel.g * 1.18 and pixel.r > pixel.b * 1.3:
				orange += 1
	_check(lit > 100 and orange > 5, "actual lit 3D scene and orange original fox " + name_value)
	_check(game.header.get_global_rect().end.y < game.footer.get_global_rect().position.y,
		"controls do not overlap " + name_value)
	_check(game.footer.get_global_rect().end.y <= size_value.y + 1, "controls fit " + name_value)
	_check(raster.save_png(output.path_join(name_value + ".png")) == OK, "save screenshot " + name_value)
	captures += 1
	print("[LearningCapture] SCREENSHOT ", name_value, " lit=", lit, " orange=", orange)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LearningCapture] Real renderer required; headless rejected")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var world := load("res://scenes/learning/learning_world.tscn") as PackedScene
	var bridge = root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	for size_value in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]:
		root.size = size_value
		bridge._options["displayDensity"] = 2.625 if size_value.x == 2400 else 1.0
		var game = world.instantiate()
		game.capture_options = {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true}
		root.add_child(game)
		await _settle()
		await _capture(game, "math-start-%dx%d" % [size_value.x, size_value.y], size_value)
		for index in range(5):
			await _tap(game.camera.unproject_position(game.tokens[index].global_position))
			_check(game.activity.placed.size() == index + 1, "touch moves one current 3D cube")
			if index == 1:
				await _capture(game, "math-ten-%dx%d" % [size_value.x, size_value.y], size_value)
		await _capture(game, "math-complete-%dx%d" % [size_value.x, size_value.y], size_value)
		game.queue_free()
		await _settle()
	bridge._options = original_options
	root.size = Vector2i(1280, 720)
	for descriptor in [
		{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]},
		{"kind": "plant_parts", "plantPart": "leaf"},
		{"kind": "subtract_ten", "a": 13, "b": 5},
		{"kind": "equal_groups", "a": 3, "b": 4},
		{"kind": "bridge_hundred", "a": 180, "b": 50},
		{"kind": "fraction_parts", "a": 1, "b": 4, "extra": 2},
	]:
		var game = world.instantiate()
		game.capture_options = {"learning": descriptor, "reduceAnimations": true}
		root.add_child(game)
		await _settle()
		await _capture(game, str(descriptor.kind) + "-start", Vector2i(1280, 720))
		if descriptor.kind == "syllables":
			for index in range(3):
				await _tap(game.camera.unproject_position(game.tokens[index].global_position))
			_check(game.activity.is_complete(), "word completed through actual touch")
		elif descriptor.kind == "plant_parts":
			await _tap(game.water_button.get_global_rect().get_center())
			await _tap(game.sun_button.get_global_rect().get_center())
			for button in game.actions.get_children():
				if button.text in ["Wurzel", "Stängel", "Blatt", "Blüte"]:
					await _tap(button.get_global_rect().get_center())
			_check(game.activity.is_complete(), "plant discovered through actual controls")
		else:
			# Use the same accessible child-facing action as Android. Every
			# press still executes an actual mesh move in the current lesson.
			for index in range(game.activity.goal_count()):
				await _tap(game.main_button.get_global_rect().get_center())
			_check(game.activity.is_complete(), "expanded current lesson completed through actual controls")
		await _capture(game, str(descriptor.kind) + "-complete", Vector2i(1280, 720))
		game.queue_free()
		await _settle()
	if failures == 0 and captures == 21:
		print("[LearningCapture] PASS captures=%d" % captures)
	else:
		push_error("[LearningCapture] FAIL captures=%d failures=%d" % [captures, failures])
	quit(0 if failures == 0 and captures == 21 else 1)
