extends SceneTree
## Actual production scene only; no synthetic illustrations.
var output := "res://exports/learning-wonder"
var label := "current"
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[WonderCapture] " + description)


func _settle() -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw


func _save(game: Node3D, name_value: String, size_value: Vector2i) -> void:
	await _settle()
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == size_value, "Actual raster dimensions: " + name_value)
	if image == null:
		return
	_check(image.save_png(output.path_join(name_value + ".png")) == OK, "Save actual raster")
	var garden: Node = game.get_node_or_null("LearningGardenAtelier/LearningWonderGarden")
	if garden != null and garden.visible:
		var body := Rect2(4, game.header.get_global_rect().end.y + 4, size_value.x - 8,
			game.footer.get_global_rect().position.y - game.header.get_global_rect().end.y - 8)
		for flower in range(5):
			var bounds: Rect2 = _flower_bounds(game, garden, flower)
			_check(body.encloses(bounds), "Actual flower geometry fits the unclipped area: " + name_value + str(bounds))
	var record: Dictionary = {
		"file": name_value + ".png", "size": [size_value.x, size_value.y],
		"kind": game.activity.kind, "placed": game.activity.placed.size(),
		"complete": game.activity.is_complete(),
		"actual_production_scene": "res://scenes/learning/learning_world.tscn",
		"garden": garden.call("render_state") if garden != null else null,
		"headless": false,
	}
	captures.append(record)
	print("[WonderCapture] saved ", name_value)


func _flower_bounds(game: Node3D, garden: Node3D, flower: int) -> Rect2:
	# Project actual mesh vertices and the shader's hinge transform, not a
	# cuboid containing impossible combinations of maximum X/Y/Z deflection.
	var found := false
	var covered := true
	var result := Rect2()
	var progress: float = garden._petal_material.get_shader_parameter("progress")
	for batch_index in range(garden._batches.size()):
		var batch: MultiMeshInstance3D = garden._batches[batch_index]
		var count := 7 if batch_index == 5 else (2 if batch_index == 4 else 1)
		var vertices: PackedVector3Array = batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for part in range(count):
			var index := flower * count + part
			var instance := batch.multimesh.get_instance_transform(index)
			var deformation := Basis.IDENTITY
			if batch_index == 5:
				var custom := batch.multimesh.get_instance_custom_data(index)
				var fraction := clampf(progress * 5.0 - custom.r, 0.0, 1.0)
				var opening := fraction * fraction * (3.0 - 2.0 * fraction)
				var hinge := lerpf(1.22, 0.12, opening)
				deformation = Basis(Vector3.UP, -custom.g * TAU) * Basis(Vector3.BACK, hinge)
			for vertex in vertices:
				var local: Vector3 = instance * (deformation * vertex)
				covered = covered and batch.multimesh.custom_aabb.has_point(local)
				var point: Vector2 = game.camera.unproject_position(batch.to_global(local))
				result = result.expand(point) if found else Rect2(point, Vector2.ZERO)
				found = true
	_check(covered, "Culling bounds enclose every actual deformed flower vertex")
	return result


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[WonderCapture] requires real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene := load("res://scenes/learning/learning_world.tscn") as PackedScene
	for size_value in [Vector2i(1280, 720), Vector2i(412, 915)]:
		root.size = size_value
		var game = scene.instantiate()
		game.capture_options = {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true}
		root.add_child(game)
		await _settle()
		await _save(game, label + "-numbers-start-%dx%d" % [size_value.x, size_value.y], size_value)
		for index in range(5):
			game._show_one()
			await _settle()
			if index == 0 and size_value.x == 1280:
				await _save(game, label + "-numbers-one-step-1280x720", size_value)
		_check(game.activity.is_complete(), "Original explanation really completed")
		await _save(game, label + "-numbers-complete-%dx%d" % [size_value.x, size_value.y], size_value)
		game.queue_free()
		await _settle()
	root.size = Vector2i(1280, 720)
	for descriptor in [
		{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]},
		{"kind": "plant_parts", "plantPart": "leaf"},
	]:
		var game = scene.instantiate()
		game.capture_options = {"learning": descriptor, "reduceAnimations": true}
		root.add_child(game)
		await _settle()
		await _save(game, label + "-" + descriptor.kind + "-start", Vector2i(1280, 720))
		if descriptor.kind == "plant_parts":
			for part in ["root", "stem", "leaf", "flower"]:
				game._inspect(part)
			game._give_water()
			game._give_sun()
		else:
			for index in range(game.activity.goal_count()):
				game._show_one()
				await _settle()
		_check(game.activity.is_complete(), "Actual language/nature activity completes")
		await _save(game, label + "-" + descriptor.kind + "-complete", Vector2i(1280, 720))
		game.queue_free()
		await _settle()
	root.size = Vector2i(412, 915)
	var hundred = scene.instantiate()
	hundred.capture_options = {"learning": {"kind": "bridge_hundred", "a": 180, "b": 50}, "reduceAnimations": true}
	root.add_child(hundred)
	await _settle()
	await _save(hundred, label + "-hundreds-phone-start", Vector2i(412, 915))
	for index in range(hundred.activity.goal_count()):
		hundred._show_one()
		await _settle()
	await _save(hundred, label + "-hundreds-phone-complete", Vector2i(412, 915))
	hundred.queue_free()
	await _settle()
	var file := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"captures": captures, "checks": checks, "failures": failures}, "  ") + "\n")
	file.close()
	print("[WonderCapture] checks=%d failures=%d captures=%d" % [checks, failures, captures.size()])
	quit(0 if failures == 0 and captures.size() == 11 else 1)
