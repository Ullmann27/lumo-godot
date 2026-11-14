extends SceneTree
## Executes the production learning scene. JNI/audio and Android Insets are
## explicit test boundaries; this does not award mastery or claim device FPS.
const ACTIVITY = preload("res://scripts/learning/learning_activity.gd")
const VOCABULARY = preload("res://scripts/learning/english_vocabulary.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
const OWNED := [
	"scripts/learning/english_vocabulary.gd",
	"scripts/learning/english_object_gallery.gd",
	"scripts/learning/learning_activity.gd",
	"scripts/learning/learning_world.gd",
	"scripts/tests/learning_english_regression.gd",
]
var checks := 0
var failures: Array[String] = []
var input_events: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var hint_layouts: Array[Dictionary] = []
var output := ""
var capture := false
var fixture_path := ""
var fixture_kind := "native_catalogue_fixture"
var examples: Dictionary = {}
const OBSERVATION := "user://learning_layout_v1.json"


class TestHost:
	extends RefCounted
	var requests: Array[Dictionary] = []
	var returns: Array[Dictionary] = []
	var rewards: Array[Dictionary] = []
	var stops := 0
	var request: Dictionary = {}
	var speech_state := "idle"

	func speakLearning(raw: String) -> int:
		request = JSON.parse_string(raw)
		requests.append(request.duplicate(true))
		speech_state = "preparing"
		return 1

	func getLearningSpeechStatus() -> String:
		return JSON.stringify({
			"id": request.get("id", 0), "state": speech_state, "positionMs": 220,
			"durationMs": 1200, "audible": speech_state == "playing",
			"envelopeAvailable": false, "envelope": 0.0,
		})

	func stopLearningSpeech() -> void:
		stops += 1
		speech_state = "idle"

	func returnToApp(destination: String, raw: String) -> int:
		returns.append({"destination": destination, "payload": JSON.parse_string(raw)})
		return 1

	func reward(raw: String) -> int:
		rewards.append(JSON.parse_string(raw))
		return 1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture":
			capture = true
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--task-fixtures="):
			fixture_path = arg.trim_prefix("--task-fixtures=")
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("[LearningEnglish] " + description)


func _settle(count: int = 10) -> void:
	for frame in range(count):
		await process_frame
	await physics_frame


func _payload(word: String) -> Dictionary:
	if examples.has(word):
		return examples[word].activity.duplicate(true)
	var objects := {
		"ball": ["book", "ball", "car"],
		"book": ["ruler", "pen", "book"],
		"ruler": ["ruler", "apple", "sun"],
		"car": ["sun", "car", "ruler"],
		"pen": ["pen", "book", "apple"],
		"sun": ["apple", "sun", "pen"],
		"apple": ["ball", "ruler", "apple"],
		"bag": ["school bag", "bag", "pencil case"],
		"rubber": ["rubber", "paper", "book"],
		"school bag": ["bag", "pencil case", "school bag"],
		"desk": ["desk", "chair", "bag"],
		"chair": ["desk", "chair", "school bag"],
		"pencil case": ["pencil case", "rubber", "pen"],
		"paper": ["paper", "book", "rubber"],
	}
	return {
		"kind": "english_objects", "word": word,
		"meaning": VOCABULARY.ENTRIES[word].meanings[0],
		"objects": objects[word].duplicate(),
	}


func _load_actual_tasks() -> bool:
	if fixture_path.is_empty():
		return true
	if not FileAccess.file_exists(fixture_path):
		_check(false, "supplied actual Dart task file exists")
		return false
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not raw is Dictionary or raw.get("failures") != 0 or not raw.get("examples") is Dictionary:
		_check(false, "actual Dart producer report is complete and successful")
		return false
	var source: Dictionary = raw.examples
	_check(source.size() == VOCABULARY.ENTRIES.size(), "actual Dart producer supplies the complete fourteen-object catalogue")
	for word: String in VOCABULARY.ENTRIES:
		var entry: Variant = source.get(word)
		if not entry is Dictionary or not entry.get("activity") is Dictionary:
			_check(false, "actual task entry exists for " + word)
			return false
		var payload: Dictionary = entry.activity
		_check(not VOCABULARY.checked_payload(payload).is_empty(), "actual producer payload validates: " + word)
		_check(payload.get("word") == word and entry.get("answer") == payload.get("meaning"), "actual task answer and word remain bound: " + word)
		_check(entry.get("prompt") in ["Was bedeutet „%s“?" % word, "Was heißt %s auf Deutsch?" % word], "actual prompt belongs to the closed native contract")
		var options: Variant = entry.get("options")
		if not options is Array or options.count(entry.get("answer")) != 1:
			_check(false, "actual task retains one exact answer choice: " + word)
			return false
	examples = source.duplicate(true)
	fixture_kind = "actual_dart_producer_report"
	return failures.is_empty()


func _state_contracts() -> void:
	for word: String in VOCABULARY.ENTRIES:
		var payload := _payload(word)
		var model = ACTIVITY.new()
		_check(model.configure(payload), "valid English payload: " + word)
		_check(not model.is_complete(), "new object task starts uncompleted")
		var options_before := JSON.stringify(payload)
		var target: int = model.english_objects.find(word)
		var wrong: int = (target + 1) % 3
		_check(not model.choose_english(wrong), "wrong object does not complete task")
		_check(model.english_attempts == 1 and not model.is_complete(), "wrong selection remains a learning attempt")
		_check(model.english_hint(), "first targeted description is available")
		_check(model.explanation() == VOCABULARY.hint_for(word), "first hint is the exact reviewed German description")
		_check(model.english_hint(), "second hint is available")
		_check(not model.is_complete() and model.english_attempts == 1, "hints do not select or complete for the child")
		_check(not model.english_hint() and model.english_hint_level == 2, "hint budget is bounded to two")
		_check(not model.place(target, 0), "arithmetic move API cannot complete an English choice")
		_check(model.choose_english(target) and model.is_complete(), "actual correct object completes only this illustration")
		_check(model.explanation().contains(model.english_meaning), "completion explains the actual German meaning")
		_check(not model.choose_english(wrong) and model.english_attempts == 2, "completed task ignores extra selection")
		model.reset()
		_check(not model.is_complete() and model.english_attempts == 0 and model.english_hint_level == 0, "restart clears local illustration state")
		_check(JSON.stringify(payload) == options_before and model.word == word, "input descriptor is immutable across attempts and restart")
	var valid := _payload("book")
	var invalid: Array = [
		{}, {"kind": "english_objects"},
		{"kind": "english_objects", "word": "cat", "meaning": "Katze", "objects": ["cat", "book", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": "Auto", "objects": ["car", "book", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": "Buch", "objects": ["book", "book", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": "Buch", "objects": ["car", "sun", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": "Buch", "objects": ["book", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": "Buch", "objects": "book,car,ball"},
		{"kind": "english_objects", "word": "book", "meaning": "Buch", "objects": ["book", "res://secret.glb", "ball"]},
		{"kind": "english_objects", "word": 3, "meaning": "Buch", "objects": ["book", "car", "ball"]},
		{"kind": "english_objects", "word": "book", "meaning": 7, "objects": ["book", "car", "ball"]},
		{"kind": "english_objects", "word": "school  bag", "meaning": "Schultasche", "objects": ["school  bag", "bag", "book"]},
		{"kind": "english_objects", "word": "school bag", "meaning": "Tasche", "objects": ["school bag", "bag", "book"]},
		{"kind": "english_objects", "word": "homework", "meaning": "Hausübung", "objects": ["homework", "bag", "book"]},
	]
	for bad in invalid:
		var model = ACTIVITY.new()
		_check(not model.configure(bad), "malformed or unsupported object task fails closed")
	var model = ACTIVITY.new()
	_check(model.configure(valid), "fresh valid state after invalid inputs")
	_check(not model.choose_english(-1) and not model.choose_english(3) and model.english_attempts == 0, "out-of-range choices cannot mutate state")


func _rect_json(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _progress_snapshot() -> Dictionary:
	var progress := root.get_node("ProgressStore")
	return {
		"stars": progress.total_stars(), "lifetime": progress.lifetime_stars(),
		"best_streak": progress.best_streak(), "current_streak": progress.current_streak(),
		"letters": progress.learned_letters().duplicate(),
		"file_sha256": FileAccess.get_sha256("user://progress.cfg") if FileAccess.file_exists("user://progress.cfg") else null,
	}


func _exposed(button: Control) -> Rect2:
	var result := button.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	var node := button.get_parent()
	while node is Control:
		if node.clip_contents:
			result = result.intersection(node.get_global_rect())
		node = node.get_parent()
	return result


func _tap_point(point: Vector2, context: String) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = pressed
		input_events.append({"context": context, "position": [point.x, point.y], "pressed": pressed, "ticks_msec": Time.get_ticks_msec()})
		Input.parse_input_event(event)
		await process_frame
	await _settle(6)


func _tap(button: Button, context: String) -> void:
	var bounds := _exposed(button)
	var density: float = root.get_node("MobileRuntime").get_ui_density()
	_check(button.is_visible_in_tree() and not button.disabled, context + ": actual button is enabled and visible")
	_check(minf(bounds.size.x, bounds.size.y) / density >= 48.0, context + ": actual exposed hit surface is at least48dp")
	if not bounds.has_area() or button.disabled:
		return
	await _tap_point(bounds.get_center(), context)


func _button(game: Node3D, text: String) -> Button:
	for candidate: Button in game.actions.get_children():
		if candidate.text == text:
			return candidate
	return null


func _meshes(node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for item: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.mesh != null and mesh.is_visible_in_tree():
			result.append(mesh)
	return result


func _mesh_rect(mesh: MeshInstance3D, camera: Camera3D) -> Rect2:
	var box := mesh.get_aabb()
	var rect := Rect2(camera.unproject_position(mesh.to_global(box.get_endpoint(0))), Vector2.ZERO)
	for index in range(1, 8):
		rect = rect.expand(camera.unproject_position(mesh.to_global(box.get_endpoint(index))))
	return rect



func _geometry_depth(node: Node3D, camera: Camera3D) -> Vector2:
	var low := INF
	var high := -INF
	var inverse := camera.get_camera_transform().affine_inverse()
	for item: Node in node.find_children("*", "GeometryInstance3D", true, false):
		if not item.is_visible_in_tree():
			continue
		var box := AABB()
		if item is MeshInstance3D and item.mesh != null:
			box = item.get_aabb()
		elif item is MultiMeshInstance3D and item.multimesh != null:
			box = item.multimesh.get_aabb()
		else:
			continue
		for corner in range(8):
			var position: Vector3 = inverse * item.to_global(box.get_endpoint(corner))
			low = minf(low, -position.z)
			high = maxf(high, -position.z)
	return Vector2(low, high)

func _school_geometry(object: Node3D, name: String) -> void:
	var shape := object.get_node("RecognizableObject")
	var word := str(object.get_meta("word"))
	match word:
		"bag":
			var handles := shape.find_children("ToteHandle*", "MeshInstance3D", false, false)
			_check(handles.size() == 2, name + ": carrying bag has two actual handles")
			for handle: MeshInstance3D in handles:
				_check(handle.mesh is TorusMesh and handle.mesh.inner_radius > 0.0 and handle.position.y > 1.0, name + ": handle has a real open hole above the bag")
			_check(shape.get_node("ToteFront").position.z > 0.0 and shape.get_node("ToteBack").position.z < 0.0, name + ": bag is an open volume with separate front and back")
		"rubber":
			var rubber := shape.get_node("EraserBody") as MeshInstance3D
			var sleeve := shape.get_node("PaperSleeve") as MeshInstance3D
			_check((rubber.mesh as BoxMesh).size.x > (sleeve.mesh as BoxMesh).size.x * 1.5, name + ": eraser protrudes from both ends of its paper sleeve")
			_check(rubber.material_override.albedo_color != sleeve.material_override.albedo_color, name + ": actual eraser and wrapper have distinct materials")
		"school bag":
			_check(shape.find_children("ShoulderStrap*", "Node3D", false, false).size() == 2, name + ": school bag has two shoulder straps")
			_check(shape.get_node("FrontPocket").position.z > shape.get_node("BackpackBody").position.z, name + ": school bag has an actual protruding front pocket")
			_check(shape.get_node("CarryHandleTop").position.y > shape.get_node("BackpackBody").position.y, name + ": school bag retains a raised carrying handle")
		"desk":
			var legs := shape.find_children("DeskLeg*", "MeshInstance3D", false, false)
			_check(legs.size() == 4, name + ": writing desk has four separate legs")
			for leg: MeshInstance3D in legs:
				_check(leg.position.y < shape.get_node("WritingTop").position.y and absf(leg.position.x) > 0.3 and absf(leg.position.z) > 0.2, name + ": desk legs surround empty space beneath the writing top")
		"chair":
			_check(shape.find_children("ChairLeg*", "MeshInstance3D", false, false).size() == 4, name + ": chair has four separate legs")
			_check(shape.get_node("ChairBackrest").position.y > shape.get_node("ChairSeat").position.y, name + ": chair backrest rises above the seat")
		"pencil case":
			_check(shape.find_children("ZipperTooth*", "MeshInstance3D", false, false).size() >= 8, name + ": pencil case has a real detailed zipper")
			_check(shape.get_node("ZipperPull").position.y > shape.get_node("SoftCaseBody").position.y, name + ": zipper pull is exposed on the case")
		"paper":
			var sheet := shape.get_node("LooseSheet") as MeshInstance3D
			var size := (sheet.mesh as BoxMesh).size
			_check(size.y < minf(size.x, size.z) * 0.04, name + ": loose paper is a thin sheet, not a book block")
			_check(shape.find_children("WritingGuide*", "MeshInstance3D", false, false).size() >= 6, name + ": actual ruled lines remain distinct sheet geometry")


func _observe(game: Node3D, name: String) -> Dictionary:
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var body: Rect2 = game.english_stage_rect
	var density: float = root.get_node("MobileRuntime").get_ui_density()
	_check(game.ui.visible and game.fox.is_usable() and game.fox.is_visible_in_tree(), name + ": original usable Lumo remains visible")
	var objects_depth := _geometry_depth(game.content, game.camera)
	var fox_depth := _geometry_depth(game.fox, game.camera)
	var background_depth := _geometry_depth(game._atelier, game.camera)
	_check(background_depth.x > maxf(objects_depth.y, fox_depth.y), name + ": actual atelier meshes cannot occlude objects or Lumo along camera depth")
	_check(viewport.encloses(game.header.get_global_rect()) and viewport.encloses(game.footer.get_global_rect()), name + ": complete header and footer fit actual window")
	_check(body.has_area(), name + ": a nonempty unobscured scene remains")
	var geometries: Array[Dictionary] = []
	var aggregate: Array[Rect2] = []
	for index in range(game.english_models.size()):
		var object: Node3D = game.english_models[index]
		_school_geometry(object, name)
		var projected := Rect2()
		var first := true
		var triangle_count := 0
		for mesh in _meshes(object):
			var rect := _mesh_rect(mesh, game.camera)
			projected = rect if first else projected.merge(rect)
			first = false
			triangle_count += mesh.mesh.get_faces().size() / 3
			_check(body.grow(0.1).encloses(rect), name + ": actual object geometry stays outside HUD: " + str(mesh.name))
		_check(triangle_count >= 24, name + ": object has actual three-dimensional mesh triangles")
		_check(minf(projected.size.x, projected.size.y) / density >= 48.0, name + ": real object projection remains at least48dp across both axes")
		aggregate.append(projected)
		geometries.append({"word": object.get_meta("word"), "bounds_px": _rect_json(projected), "triangles": triangle_count, "spatial_48dp_target_px": _rect_json(game.english_pick_rect(index))})
	var fox_rect := Rect2()
	var first_fox := true
	for mesh in _meshes(game.fox):
		var bounds := _mesh_rect(mesh, game.camera)
		fox_rect = bounds if first_fox else fox_rect.merge(bounds)
		first_fox = false
		_check(body.grow(0.1).encloses(bounds), name + ": original Lumo mesh is outside HUD: " + str(mesh.name))
	_check(fox_rect.size.y / density >= 96.0, name + ": original Lumo stays at a readable projected height rather than a thumbnail")
	for index in range(aggregate.size()):
		_check(not aggregate[index].intersects(fox_rect), name + ": complete object is separate from Lumo")
		for other in range(index):
			_check(not aggregate[index].intersects(aggregate[other]), name + ": actual object projections are separate")
	var controls: Array[Dictionary] = []
	for button: Button in game.actions.get_children():
		var bounds := _exposed(button)
		_check(button.is_visible_in_tree() and minf(bounds.size.x, bounds.size.y) / density >= 48.0, name + ": every exposed action retains48dp: " + button.text)
		controls.append({"text": button.text, "enabled": not button.disabled, "rect_px": _rect_json(button.get_global_rect()), "exposed_px": _rect_json(bounds)})
	return {
		"name": name, "window_px": [root.size.x, root.size.y], "density": density,
		"observation_source": "platform_fixture", "stage_px": _rect_json(body),
		"header_px": _rect_json(game.header.get_global_rect()), "footer_px": _rect_json(game.footer.get_global_rect()),
		"lumo_px": _rect_json(fox_rect), "objects": geometries, "controls": controls,
		"background_depth": [background_depth.x, background_depth.y], "foreground_far_depth": maxf(objects_depth.y, fox_depth.y),
		"title": game.title.text, "explanation": game.explanation.text, "status": game.status.text,
		"word": game.activity.word, "objects_order": game.activity.english_objects.duplicate(),
		"hint_level": game.activity.english_hint_level, "attempts": game.activity.english_attempts,
		"complete": game.activity.is_complete(),
	}


func _capture(game: Node3D, name: String) -> void:
	await _settle()
	var actual := _observation_contract(game, name)
	var original := FileAccess.open(output.path_join(name + ".layout.json"), FileAccess.WRITE)
	_check(original != null and not actual.is_empty(), "preserve actual product observation: " + name)
	if original != null:
		original.store_string(FileAccess.get_file_as_string(OBSERVATION))
		original.close()
	var report := _observe(game, name)
	var sidecar := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
	_check(sidecar != null, "write original scene observation: " + name)
	if sidecar != null:
		sidecar.store_string(JSON.stringify(report, "\t") + "\n")
		sidecar.close()
	if capture:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(not image.is_empty(), "actual rendered image exists: " + name)
		_check(image.get_size() == root.size, "actual image matches configured window: " + name)
		var path := output.path_join(name + ".png")
		_check(image.save_png(path) == OK, "save actual renderer image: " + name)
		report["png"] = name + ".png"
		report["sha256"] = FileAccess.get_sha256(path)
	captures.append(report)


func _install_inset_fixture(dimensions: Vector2i, insets: Rect2) -> void:
	var mobile := root.get_node("MobileRuntime")
	mobile._android_safe_area_enabled = false
	mobile._safe_area_request_pending = false
	root.size = dimensions
	await _settle(3)
	mobile._safe_area_reader = func(completed: Callable) -> bool:
		completed.call_deferred({
			"view_size": Vector2(dimensions), "decor_size": Vector2(dimensions),
			"render_rect": Rect2(Vector2.ZERO, Vector2(dimensions)),
			"system_insets": insets, "insets": insets,
		})
		return true
	mobile._android_safe_area_enabled = true
	mobile._invalidate_safe_area()
	mobile.request_safe_area_refresh()
	await _settle(3)
	_check(mobile.safe_area_is_ready(), "real shared cache accepts explicit layout fixture")


func _exercise(word: String, dimensions: Vector2i, density: float, insets: Rect2) -> void:
	var bridge := root.get_node("HostBridge")
	var test_host := TestHost.new()
	var options := {
		"sessionId": "00000000-0000-4000-8000-%012d" % (VOCABULARY.ENTRIES.keys().find(word) + 1),
		"childKey": "p_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "scene": "learning", "grade": 1,
		"subject": "Englisch", "stars": 13, "displayDensity": density,
	}
	bridge._host = test_host
	bridge._options = options.duplicate(true)
	bridge._return_pending = false
	var profile_before := JSON.stringify(bridge._options)
	var progress_before := _progress_snapshot()
	await _install_inset_fixture(dimensions, insets)
	var game = load(WORLD).instantiate()
	game._speech_host = test_host
	game.capture_options = options.duplicate(true)
	game.capture_options.merge({"learning": _payload(word), "reduceAnimations": true,
		"learningVoiceEnabled": true, "localVoiceLicenseAccepted": true, "learningAutoRead": false,
		"childName": "This fixture field must never appear in the private observation"})
	var task_before := JSON.stringify(game.capture_options)
	root.add_child(game)
	await _settle(14)
	_check(game.activity.kind == "english_objects" and game.title.text.ends_with(word), "actual scene displays the exact current word")
	_check(game.english_models.size() == 3 and game.english_buttons.size() == 3, "three actual objects and equivalent buttons exist")
	var stem := "english-%s-%dx%d" % [word.replace(" ", "-"), dimensions.x, dimensions.y]
	await _capture(game, stem + "-start")
	var unchanged := FileAccess.get_sha256(OBSERVATION)
	await _settle(8)
	_check(FileAccess.get_sha256(OBSERVATION) == unchanged, "idle frames do not rewrite a settled observation")
	var target: int = game.activity.english_objects.find(word)
	var wrong: int = (target + 1) % 3
	await _tap(game.english_buttons[wrong], word + ": wrong visible object choice")
	_check(not game.activity.is_complete() and game.activity.english_attempts == 1, "actual wrong touch cannot complete or award")
	_observation_contract(game, word + "-wrong")
	await _tap(game.main_button, word + ": first targeted hint")
	_check(game.activity.english_hint_level == 1 and game.explanation.text == VOCABULARY.hint_for(word), "actual first hint shows the intended object clue")
	hint_layouts.append(_observe(game, word + ": first hint layout"))
	await _tap(game.main_button, word + ": bounded outline hint")
	_check(game.activity.english_hint_level == 2 and not game.activity.is_complete(), "actual second hint leaves selection to the child")
	_observation_contract(game, word + "-hint")
	_check(game.english_models[target].get_node("HintRing").visible, "correct object has real visible hint geometry")
	for index in range(3):
		if index != target:
			_check(not game.english_models[index].get_node("HintRing").visible, "distractor has no false correct outline")
	if word == "ball":
		await _capture(game, stem + "-hint")
		var pick: Rect2 = game.english_pick_rect(target)
		_check(pick.has_area(), "landscape offers a measured48dp actual spatial target")
		if pick.has_area():
			await _tap_point(pick.get_center(), "actual3D collision target for ball")
	else:
		await _tap(game.english_buttons[target], word + ": correct actual object")
	_check(game.activity.is_complete() and game.activity.english_attempts == 2, "actual child choice completes only the illustration")
	_check(game.status.text.contains(word) and game.status.text.contains(game.activity.english_meaning), "completion visibly binds exact word and meaning")
	if word in ["ball", "book"]:
		await _capture(game, stem + "-complete")
	var stops_before: int = test_host.stops
	await _tap(game.voice_button, word + ": existing local German readback")
	_check(test_host.requests.size() == 1 and test_host.requests[0].text.contains(game.activity.english_meaning), "existing local speech receives actual German explanation")
	test_host.speech_state = "playing"
	game._tick_speech(0.06)
	game._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check(not FileAccess.file_exists(OBSERVATION), "pause invalidates old settled file before any next frame")
	await _settle(5)
	var paused_observation := _observation_contract(game, word + "-paused")
	_check(paused_observation.get("suspended") == true, "published pause observation cannot claim active input")
	var attempts_before: int = game.activity.english_attempts
	game._choose_english(wrong)
	game._english_hint()
	_check(game.suspended and test_host.stops > stops_before and game.activity.english_attempts == attempts_before, "pause stops speech and rejects new learning input")
	game._notification(NOTIFICATION_APPLICATION_RESUMED)
	_check(not game.suspended and game.activity.is_complete(), "resume preserves this local illustration")
	_check(not FileAccess.file_exists(OBSERVATION), "resume invalidates the previous paused observation immediately")
	await _settle(5)
	_observation_contract(game, word + "-resumed")
	await _tap(_button(game, "Neu"), word + ": restart local illustration")
	_check(not game.activity.is_complete() and game.activity.english_hint_level == 0 and game.activity.english_attempts == 0, "actual restart resets only local interaction state")
	_check(JSON.stringify(game.capture_options) == task_before, "task launch descriptor remains byte-equivalent")
	await _tap(_button(game, "Zur Aufgabe"), word + ": return to actual host task")
	_check(test_host.returns.size() == 1, "actual return acknowledged exactly once")
	_check(not FileAccess.file_exists(OBSERVATION), "acknowledged return removes observation and prevents republishing")
	if test_host.returns.size() == 1:
		var result: Dictionary = test_host.returns[0]
		_check(result.destination == "learn" and result.payload.get("status") == "illustrated", "return remains bounded help result")
		_check(result.payload.get("sessionId") == options.sessionId and result.payload.get("game") == "learning", "return preserves the exact launch session")
		_check(not result.payload.has("answer") and not result.payload.has("stars") and not result.payload.has("xp"), "return does not submit answer or rewards")
	_check(test_host.rewards.is_empty() and _progress_snapshot() == progress_before, "no native reward, progress or persistence mutation")
	_check(JSON.stringify(bridge._options) == profile_before, "child/profile/actual launch fields remain unchanged")
	cases.append({"word": word, "dimensions": [dimensions.x, dimensions.y], "input_boundary": "actual Godot ScreenTouch", "host_boundary": "explicit JNI/audio test double", "return_count": test_host.returns.size(), "reward_count": test_host.rewards.size()})
	game.queue_free()
	await _settle(3)
	_check(not FileAccess.file_exists(OBSERVATION) and not FileAccess.file_exists(OBSERVATION + ".tmp"), "scene exit leaves no reusable observation or partial file")
	bridge._host = null
	bridge._options = {}
	bridge._return_pending = false


func _voice_permission_gate() -> void:
	var host := TestHost.new()
	var game = load(WORLD).instantiate()
	game._speech_host = host
	game.capture_options = {"learning": _payload("book"), "reduceAnimations": true,
		"learningVoiceEnabled": true, "localVoiceLicenseAccepted": false, "learningAutoRead": true}
	root.add_child(game)
	await _settle(12)
	game._speak("Diese deutsche Erklärung darf ohne Zustimmung nicht abgespielt werden.")
	game._tick_speech(1.0)
	_check(game.voice_button == null and host.requests.is_empty(), "existing parent/license guard rejects speech without consent")
	game.queue_free()
	await _settle(3)


func _run() -> void:
	if output.is_empty():
		push_error("--output=<directory> is required for source-bound evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if capture and DisplayServer.get_name() == "headless":
		push_error("English image capture requires an actual renderer")
		quit(2)
		return
	var sources: Dictionary = {}
	for path: String in OWNED:
		sources[path] = FileAccess.get_sha256("res://" + path)
	if not _load_actual_tasks():
		quit(1)
		return
	_state_contracts()
	var profiles := [
		["ball", Vector2i(960, 540), 1.0, Rect2()],
		["book", Vector2i(412, 915), 1.0, Rect2()],
		["ruler", Vector2i(640, 360), 1.0, Rect2()],
		["car", Vector2i(2400, 1080), 2.625, Rect2(136, 0, 0, 63)],
		["pen", Vector2i(1080, 2400), 2.625, Rect2(0, 136, 0, 63)],
		["sun", Vector2i(960, 540), 1.0, Rect2()],
		["apple", Vector2i(960, 540), 1.0, Rect2()],
		["bag", Vector2i(960, 540), 1.0, Rect2()],
		["rubber", Vector2i(640, 360), 1.0, Rect2()],
		["school bag", Vector2i(412, 915), 1.0, Rect2()],
		["desk", Vector2i(960, 540), 1.0, Rect2()],
		["chair", Vector2i(640, 360), 1.0, Rect2()],
		["pencil case", Vector2i(1080, 2400), 2.625, Rect2(0, 136, 0, 63)],
		["paper", Vector2i(2400, 1080), 2.625, Rect2(136, 0, 0, 63)],
	]
	for profile in profiles:
		await _exercise(profile[0], profile[1], profile[2], profile[3])
	await _voice_permission_gate()
	var mobile := root.get_node("MobileRuntime")
	mobile._android_safe_area_enabled = false
	mobile._safe_area_observation.clear()
	for path: String in OWNED:
		_check(FileAccess.get_sha256("res://" + path) == sources[path], "source stayed byte-identical during the actual run: " + path)
	var file := FileAccess.open(output.path_join("learning-english-report.json"), FileAccess.WRITE)
	_check(file != null, "final original report can be written")
	if file != null:
		file.store_string(JSON.stringify({
			"schema": 1, "scope": "actual production Godot scene; explicit platform/JNI/audio fixtures; no Android/FPS/mastery claim",
			"fixture_kind": fixture_kind, "task_fixture_sha256": FileAccess.get_sha256(fixture_path) if not fixture_path.is_empty() else null,
			"checks": checks, "failures": failures, "renderer": DisplayServer.get_name(),
			"source_sha256": sources, "cases": cases, "captures": captures, "hint_layouts": hint_layouts,
			"input_events": input_events, "audio_listened": false, "english_pronunciation_verified": false,
		}, "\t") + "\n")
		file.close()
	if failures.is_empty():
		print("LEARNING_ENGLISH_PASS checks=", checks, " captures=", captures.size(), " input_events=", input_events.size(), " fixture=", fixture_kind)
		quit(0)
	else:
		print("LEARNING_ENGLISH_FAIL checks=", checks, " failures=", failures.size())
		quit(1)


func _observation_contract(game: Node3D, label: String) -> Dictionary:
	_check(FileAccess.file_exists(OBSERVATION), label + ": production observation exists after settling")
	if not FileAccess.file_exists(OBSERVATION):
		return {}
	var text := FileAccess.get_file_as_string(OBSERVATION)
	var value: Variant = JSON.parse_string(text)
	_check(value is Dictionary, label + ": atomic original is complete JSON")
	if not value is Dictionary:
		return {}
	_check(value.schema == 1 and value.settled and value.ui_visible, label + ": complete settled schema")
	_check(value.observation_source == "platform_fixture", label + ": synthetic platform input is never marked Android")
	_check(int(value.pid) == OS.get_process_id() and int(value.layout_sequence) > 0, label + ": actual live process and sequence")
	_check(value.launch.sessionId == game.capture_options.sessionId and value.launch.childKey == game.capture_options.childKey, label + ": actual pseudonymous session is retained")
	_check(value.launch.learning == game.capture_options.learning, label + ": exact real task descriptor is retained")
	_check(not text.contains("childName") and not text.contains("This fixture field"), label + ": no child text escapes into the observation")
	_check(int(value.selection) == game.activity.english_choice and int(value.attempts) == game.activity.english_attempts, label + ": actual selection and attempt count")
	_check(int(value.hint_level) == game.activity.english_hint_level and value.complete == game.activity.is_complete(), label + ": actual hint and completion")
	_check(value.suspended == game.suspended and value.objects.size() == 3, label + ": current lifecycle and exactly three objects")
	_check(value.camera.projection_columns.size() == 4 and value.camera.view_basis_columns.size() == 3, label + ": actual complete camera projection")
	_check(value.controls.size() == game.actions.get_child_count(), label + ": every real control is observed")
	for item: Dictionary in value.objects:
		_check(item.word == game.activity.english_objects[int(item.index)] and not item.meshes.is_empty(), label + ": actual object order and meshes")
		_check(item.collision_world_corners.size() == 8 and item.collision_projected_corners_px.size() == 8, label + ": actual collision volume has eight independent corners")
		for mesh: Dictionary in item.meshes:
			_check(mesh.world_corners.size() == 8 and mesh.projected_corners_px.size() == 8, label + ": real mesh AABB has eight observed corners")
	return value
