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


func _visible_object_bounds(game: Node3D, node: Node3D, body: Rect2, caption: String) -> void:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh_node: MeshInstance3D in meshes:
		if not mesh_node.is_visible_in_tree():
			continue
		var bounds := mesh_node.get_aabb()
		for corner in range(8):
			var point: Vector2 = game.camera.unproject_position(
				mesh_node.to_global(bounds.get_endpoint(corner))
			)
			_check(body.has_point(point), caption + " is completely outside the header and footer")


func _projected_bounds(game: Node3D, mesh: MeshInstance3D) -> Rect2:
	var bounds := mesh.get_aabb()
	var projected := Rect2(
		game.camera.unproject_position(mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO
	)
	for corner in range(1, 8):
		projected = projected.expand(
			game.camera.unproject_position(mesh.to_global(bounds.get_endpoint(corner)))
		)
	return projected


func _capture(game: Node3D, name_value: String, size_value: Vector2i) -> void:
	await _settle()
	var raster := root.get_texture().get_image()
	_check(raster != null and raster.get_size() == size_value, "raster dimensions " + name_value)
	if raster == null:
		return
	var orange := 0
	var lit := 0
	var clipped := 0
	var sampled := 0
	var begin: int = int(game.header.get_global_rect().end.y + 4)
	var end: int = int(game.footer.get_global_rect().position.y - 4)
	var body := Rect2(8, begin, size_value.x - 16, end - begin)
	for index in range(game.tokens.size()):
		_visible_object_bounds(game, game.tokens[index], body, name_value + " token " + str(index))
	if is_instance_valid(game._fraction_label):
		_visible_object_bounds(game, game._fraction_label, body, name_value + " current fraction")
		_check(
			(
				game._fraction_label.mesh.text
				== (
					"%d/%d"
					% [game.activity.initial_count() + game.activity.placed.size(), game.activity.b]
				)
			),
			"visible fraction agrees with actual highlighted pieces " + name_value
		)
	if is_instance_valid(game._hundred_stock):
		_visible_object_bounds(game, game._hundred_stock, body, name_value + " existing hundred")
		_visible_object_bounds(
			game, game._hundred_summary, body, name_value + " place-value decomposition"
		)
		var caption: MeshInstance3D = game._hundred_summary
		var plate: MeshInstance3D = caption.get_node("CaptionPlate")
		_check(
			_projected_bounds(game, plate).encloses(_projected_bounds(game, caption).grow(0.5)),
			"contrasting plate covers all projected glyphs " + name_value
		)
	for y in range(begin, end, 3):
		for x in range(10, size_value.x - 10, 3):
			var pixel := raster.get_pixel(x, y)
			sampled += 1
			if int(pixel.r > 0.97) + int(pixel.g > 0.97) + int(pixel.b > 0.97) >= 2:
				clipped += 1
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.3:
				lit += 1
			if pixel.r > 0.3 and pixel.r > pixel.g * 1.18 and pixel.r > pixel.b * 1.3:
				orange += 1
	_check(lit > 100 and orange > 5, "actual lit 3D scene and orange original fox " + name_value)
	_check(
		sampled > 0 and float(clipped) / maxf(1, sampled) < 0.18,
		"learning materials retain color instead of clipped cyan/white masses " + name_value
	)
	var skeleton: Skeleton3D = game.fox.skeleton
	var head_world: Vector3 = skeleton.to_global(
		skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	)
	var head_pixel: Vector2 = game.camera.unproject_position(head_world)
	var head_radius: float = (
		game.camera.unproject_position(head_world + Vector3.RIGHT * 0.7).distance_to(head_pixel)
	)
	var head_orange := 0
	for y in range(
		maxi(0, int(head_pixel.y - head_radius)),
		mini(size_value.y, int(head_pixel.y + head_radius)),
		2
	):
		for x in range(
			maxi(0, int(head_pixel.x - head_radius)),
			mini(size_value.x, int(head_pixel.x + head_radius)),
			2
		):
			var pixel := raster.get_pixel(x, y)
			if pixel.r > 0.3 and pixel.r > pixel.g * 1.22 and pixel.r > pixel.b * 1.8:
				head_orange += 1
	_check(
		head_orange > 8,
		(
			"original fox is actually visible at the projected head, not inferred from gold cubes "
			+ name_value
		)
	)
	_check(
		game.header.get_global_rect().end.y < game.footer.get_global_rect().position.y,
		"controls do not overlap " + name_value
	)
	_check(game.footer.get_global_rect().end.y <= size_value.y + 1, "controls fit " + name_value)
	_check(
		raster.save_png(output.path_join(name_value + ".png")) == OK,
		"save screenshot " + name_value
	)
	captures += 1
	print(
		"[LearningCapture] SCREENSHOT ",
		name_value,
		" lit=",
		lit,
		" orange=",
		orange,
		" fox_head_orange=",
		head_orange,
		" clipped_ratio=",
		float(clipped) / maxf(1, sampled)
	)


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
		game.capture_options = {
			"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true
		}
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
			_check(
				game.activity.is_complete(),
				"expanded current lesson completed through actual controls"
			)
		await _capture(game, str(descriptor.kind) + "-complete", Vector2i(1280, 720))
		game.queue_free()
		await _settle()
	# The renderer exposed a caption parallax defect. Cover the corrected
	# hundred transition on a portrait phone and the real Android density too.
	for size_value in [Vector2i(412, 915), Vector2i(2400, 1080)]:
		root.size = size_value
		bridge._options["displayDensity"] = 2.625 if size_value.x == 2400 else 1.0
		var game = world.instantiate()
		game.capture_options = {
			"learning": {"kind": "bridge_hundred", "a": 180, "b": 50}, "reduceAnimations": true
		}
		root.add_child(game)
		await _settle()
		await _capture(
			game, "bridge_hundred-start-%dx%d" % [size_value.x, size_value.y], size_value
		)
		for index in range(game.activity.goal_count()):
			await _tap(game.main_button.get_global_rect().get_center())
		_check(
			game.activity.is_complete(), "hundred transition completes at current display density"
		)
		await _capture(
			game, "bridge_hundred-complete-%dx%d" % [size_value.x, size_value.y], size_value
		)
		game.queue_free()
		await _settle()
	bridge._options = original_options
	if failures == 0 and captures == 25:
		print("[LearningCapture] PASS captures=%d" % captures)
	else:
		push_error("[LearningCapture] FAIL captures=%d failures=%d" % [captures, failures])
	quit(0 if failures == 0 and captures == 25 else 1)
