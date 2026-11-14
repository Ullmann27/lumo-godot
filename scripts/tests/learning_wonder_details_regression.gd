extends SceneTree
## Tests the existing production route and actual lesson model. No mocks.
var checks := 0
var failures := 0
var invalid_scene_checked := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningWonder] " + message)


func _frames(count := 3) -> void:
	for index in range(count):
		await process_frame


func _snapshot(game: Node3D) -> String:
	var a: RefCounted = game.get("activity")
	return JSON.stringify({
		"kind": a.kind, "a": a.a, "b": a.b, "extra": a.extra,
		"placed": a.placed, "water": a.watered, "sun": a.sunlight,
		"word": a.word, "syllables": a.syllables, "inspected": a.inspected,
	})


func _visual_only(node: Node) -> void:
	_check(not node is Control, "Decoration must not intercept HUD or touch")
	_check(not node is CollisionObject3D, "Decoration must not block spatial picking")
	_check(not node is Light3D, "Existing scene lighting remains authoritative")
	for child in node.get_children():
		_visual_only(child)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var packed := load("res://scenes/learning/learning_world.tscn") as PackedScene
	var game = packed.instantiate()
	game.capture_options = {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true}
	root.add_child(game)
	await _frames(8)
	var garden: Node = game.get_node_or_null("LearningGardenAtelier/LearningWonderGarden")
	_check(garden != null, "The existing learning route must contain the interactive wonder garden")
	if garden == null:
		game.queue_free()
		await _frames()
		_finish()
		return
	_check(garden.has_method("render_state"), "Garden exposes bounded rendering evidence")
	_visual_only(garden)
	var start: Dictionary = garden.call("render_state")
	_check(start.progress == 0.0, "Unattempted explanation starts with closed buds")
	_check(start.reduced_motion, "Actual host reduced-motion option reaches garden")
	_check(start.geometry_batches == 7 and start.flowers == 5 and start.petals == 35, "Fixed geometry budget")
	_check(start.ambience.batches == 2, "Reuse one existing ambience, no duplicate effect system")
	_check(garden.get_child_count() == 8, "Exactly seven geometry batches and one shared ambience")
	var before_state := _snapshot(game)
	await _frames(10)
	_check(_snapshot(game) == before_state, "Watching decoration never changes task state")
	_check(not game.move_token(999), "Invalid manipulation is rejected by original scene")
	await _frames()
	_check(garden.call("render_state").progress == 0.0, "Invalid action cannot open flowers")
	var flower_mesh: MultiMeshInstance3D = garden.get_node("OpeningPetals")
	if DisplayServer.get_name() != "headless":
		for flower in range(5):
			var frame: Transform3D = flower_mesh.multimesh.get_instance_transform(flower * 7)
			var at: Vector3 = flower_mesh.to_global(frame.origin + Vector3(0, 0.46, 0))
			var projected: Vector2 = game.camera.unproject_position(at)
			_check(projected.y > game.header.get_global_rect().end.y + 5, "The whole blossom is visible below the header")
	var before: int = game.activity.placed.size()
	game._show_one()
	await _frames(5)
	var moved: Dictionary = garden.call("render_state")
	_check(game.activity.placed.size() == before + 1, "Original learning manipulation remains authoritative")
	_check(is_equal_approx(float(moved.progress), 0.2), "Real action opens the corresponding amount of the garden")
	_check(is_equal_approx(float(moved.display_progress), 0.2), "Reduced motion reacts immediately without animation")
	_check(game.activity.a == 8 and game.activity.b == 5, "Decoration must not rewrite the task")
	for index in range(4):
		game._show_one()
		await _frames(3)
	_check(is_equal_approx(float(garden.call("render_state").progress), 1.0), "Garden reflects the completed real explanation")
	_check(game.activity.is_complete(), "The original completion rule still decides progress")
	game.restart()
	await _frames(5)
	_check(garden.call("render_state").progress == 0.0, "Restart resets decoration without an old celebration")
	var active_layout: int = garden.call("render_state").layout_changes
	var active_theme: int = garden.call("render_state").theme_changes
	await _frames(15)
	var steady: Dictionary = garden.call("render_state")
	_check(steady.layout_changes == active_layout and steady.theme_changes == active_theme, "Stable frames do not rebuild meshes or palettes")
	var clock: float = steady.ambience.animation_time
	await _frames(8)
	_check(garden.call("render_state").ambience.animation_time == clock, "Quiet mode freezes shader animation")
	game.reduced_motion = false
	await _frames(8)
	_check(garden.call("render_state").ambience.animation_time > clock, "Normal mode restores ambient animation")
	game.suspended = true
	await _frames(3)
	clock = garden.call("render_state").ambience.animation_time
	before_state = _snapshot(game)
	await _frames(8)
	_check(garden.call("render_state").ambience.animation_time == clock, "Application suspension freezes ambience")
	_check(_snapshot(game) == before_state, "Application suspension preserves original learning state")
	game.suspended = false
	await _frames(3)
	paused = true
	clock = garden.call("render_state").ambience.animation_time
	await create_timer(0.06, true).timeout
	_check(garden.call("render_state").ambience.animation_time == clock, "SceneTree pause freezes local shader clock")
	paused = false
	await _frames(3)
	game.reduced_motion = true
	game._show_one()
	await _frames(3)
	before_state = _snapshot(game)
	root.size = Vector2i(412, 915)
	await _frames(8)
	_check(_snapshot(game) == before_state, "Phone resize never resets the explanation")
	_check(garden.call("render_state").layout_changes > active_layout, "Flower arrangement responds to actual viewport size")
	game.queue_free()
	await _frames(4)
	root.size = Vector2i(1280, 720)

	var descriptors: Array[Dictionary] = [
		{"kind": "addition", "a": 0, "b": 3},
		{"kind": "subtract_ten", "a": 13, "b": 5},
		{"kind": "equal_groups", "a": 2, "b": 3},
		{"kind": "equal_sharing", "a": 12, "b": 3},
		{"kind": "bridge_hundred", "a": 180, "b": 50},
		{"kind": "fraction_parts", "a": 1, "b": 4, "extra": 2},
		{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]},
		{"kind": "plant_parts", "plantPart": "leaf"},
	]
	# Baseline 587f already emits two dummy-renderer material errors on invalid
	# scene disposal. Validate that actual production path in the mandatory
	# real-renderer run instead; do not filter or relabel that baseline defect.
	if DisplayServer.get_name() != "headless":
		descriptors.append({"kind": "invalid"})
	for descriptor in descriptors:
		game = packed.instantiate()
		game.capture_options = {"learning": descriptor, "reduceAnimations": true}
		root.add_child(game)
		await _frames(5)
		garden = game.get_node("LearningGardenAtelier/LearningWonderGarden")
		var current: Dictionary = garden.call("render_state")
		_check(current.progress == 0.0, "Fresh lesson does not inherit progress: " + str(descriptor.kind))
		before_state = _snapshot(game)
		await _frames(3)
		_check(_snapshot(game) == before_state, "Read-only task observer: " + str(descriptor.kind))
		if descriptor.kind == "invalid":
			invalid_scene_checked = true
			_check(not garden.visible, "Invalid tasks never receive a celebration or decoration")
		elif descriptor.kind == "plant_parts":
			_check(current.family == "nature", "Nature has its own visual palette")
			game._inspect("unsupported")
			await _frames(3)
			_check(garden.call("render_state").progress == 0.0, "Unknown plant part gives no false progress")
			for part in ["root", "stem", "leaf", "flower"]:
				game._inspect(part)
				await _frames(2)
			_check(is_equal_approx(float(garden.call("render_state").progress), 4.0 / 6.0), "All four parts still require water and light")
			game._give_water()
			game._give_sun()
			await _frames(3)
			_check(game.activity.is_complete() and garden.call("render_state").progress == 1.0, "Nature uses original six-part completion")
			game.restart()
			await _frames(3)
			_check(garden.call("render_state").progress == 0.0, "Plant restart resets garden")
		else:
			_check(current.family == ("language" if descriptor.kind == "syllables" else "numbers"), "Correct visual lesson family")
			var steps: int = game.activity.goal_count()
			for index in range(steps):
				game._show_one()
				await _frames(2)
			_check(game.activity.is_complete(), "Original activity completes: " + str(descriptor.kind))
			_check(garden.call("render_state").progress == 1.0, "Bloom follows actual complete state: " + str(descriptor.kind))
		game.queue_free()
		await _frames(3)
	_finish()


func _finish() -> void:
	print("[LearningWonder] checks=%d failures=%d renderer=%s invalid_scene_checked=%s" % [checks, failures, DisplayServer.get_name(), invalid_scene_checked])
	quit(0 if failures == 0 else 1)
