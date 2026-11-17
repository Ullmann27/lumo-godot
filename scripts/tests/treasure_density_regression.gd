extends SceneTree
## Real production input and transformed dp targets, including scrolled dialogs.
## --capture requires a real renderer and writes exactly 14 fresh PNGs.

const STATE = preload("res://scripts/creative/treasure_state.gd")
const PROFILES := [
	[Vector2i(412, 915), 1.0],
	[Vector2i(690, 829), 1.0],
	[Vector2i(2176, 1812), 2.25],
	[Vector2i(2400, 1080), 2.625],
	[Vector2i(1080, 2400), 2.625],
	[Vector2i(640, 320), 1.0],
]

var game
var density := 1.0
var checks := 0
var failures: Array[String] = []
var capture := false
var output := "user://treasure-density"
var images: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var rewards: Array[Dictionary] = []


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[TreasureDensity] " + label)


func _settle(frames: int = 5) -> void:
	for frame in range(frames):
		await process_frame


func _canvas_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var rectangle := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for point in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		rectangle = rectangle.expand(transform * point)
	return rectangle


func _physical_rect(control: Control) -> Rect2:
	var rectangle := _canvas_rect(control)
	var factor := Vector2(root.size) / root.get_visible_rect().size
	return Rect2(rectangle.position * factor, rectangle.size * factor)


func _target(control: Control, label: String, in_dialog := false) -> void:
	var rectangle := _physical_rect(control)
	var dp := rectangle.size / density
	_check(control.is_visible_in_tree(), label + " visible")
	_check(minf(dp.x, dp.y) >= 47.99, "%s measured %s dp at %s / %.3f" % [label, dp, root.size, density])
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(0.51).encloses(rectangle), label + " entirely inside the physical surface")
	_check(_physical_rect(game.safe_ui).grow(0.51).encloses(rectangle), label + " entirely inside the safe UI")
	if in_dialog:
		_check(_physical_rect(game.modal_scroll).grow(0.51).encloses(rectangle), label + " entirely exposed in the real scroll viewport")
	targets.append({"surface": [root.size.x, root.size.y], "density": density,
		"label": label, "physical_size": [rectangle.size.x, rectangle.size.y], "dp": [dp.x, dp.y]})


func _button(label: String, within: Node = null) -> Button:
	var source: Node = game if within == null else within
	for control in source.find_children("*", "Button", true, false):
		if control.text == label and control.is_visible_in_tree():
			return control
	return null


func _touch(point: Vector2, down: bool, index: int = 3) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _tap(control: Control, edge := true) -> void:
	_check(is_instance_valid(control), "Actual touch target exists")
	if not is_instance_valid(control):
		return
	if control is BaseButton:
		_check(not control.disabled, "Actual button is enabled: " + control.text)
	var point := _physical_rect(control).get_center()
	if edge:
		# The old 27dp-high targets cannot receive a touch 22dp from their centre.
		point.y += 22.0 * density
	await _touch(point, true)
	await _touch(point, false)
	await _settle(3)


func _reveal(control: Control, label: String) -> void:
	game.modal_scroll.ensure_control_visible(control)
	await _settle()
	# Scroll offsets are integral canvas units; reveal the last partial unit.
	var rectangle := _canvas_rect(control)
	var visible := _canvas_rect(game.modal_scroll)
	if rectangle.end.y > visible.end.y:
		game.modal_scroll.scroll_vertical += ceili(rectangle.end.y - visible.end.y)
	elif rectangle.position.y < visible.position.y:
		game.modal_scroll.scroll_vertical -= ceili(visible.position.y - rectangle.position.y)
	await _settle(2)
	_target(control, label, true)


func _dialog(label: String) -> void:
	_check(game.paused and game.modal.visible, label + " opens through actual UI")
	_check(_physical_rect(game.safe_ui).grow(0.51).encloses(_physical_rect(game.modal)), label + " frame fits the safe UI")
	var buttons := 0
	for control in game.modal_box.get_children():
		if control is Button:
			buttons += 1
			await _reveal(control, label + " / " + control.text)
		elif control is Label:
			_check(_physical_rect(control).size.x <= _physical_rect(game.modal_scroll).size.x + 0.51,
				label + " text wraps inside its dialog")
	_check(buttons > 0, label + " has reachable actions")


func _drag_dialog(from_button: Button = null) -> void:
	game.modal_scroll.scroll_vertical = 0
	await _settle()
	var bar: VScrollBar = game.modal_scroll.get_v_scroll_bar()
	if bar.max_value <= bar.page + 1:
		return
	var before: String = JSON.stringify(game.model.to_data())
	var rectangle := _physical_rect(game.modal_scroll)
	# Begin on the title, then drag the actual content while keeping one finger.
	var point := Vector2(rectangle.get_center().x, rectangle.position.y + 30 * density)
	if is_instance_valid(from_button):
		await _reveal(from_button, "scroll gesture begins on a real answer button")
		point = _physical_rect(from_button).get_center()
	var original_scroll: int = game.modal_scroll.scroll_vertical
	await _touch(point, true, 7)
	for step in range(5):
		var next := point - Vector2(0, 20 * density)
		var event := InputEventScreenDrag.new()
		event.index = 7
		event.position = next
		event.relative = next - point
		Input.parse_input_event(event)
		point = next
		await process_frame
	await _touch(point, false, 7)
	await _settle()
	_check(game.modal_scroll.scroll_vertical > original_scroll, "Actual touch drag scrolls an overflowing dialog")
	_check(JSON.stringify(game.model.to_data()) == before, "Scrolling never answers a question or changes progress")


func _shot(stage: String) -> void:
	var full_case := is_equal_approx(density, 2.625) or root.size == Vector2i(640, 320)
	var fold_case := is_equal_approx(density, 2.25) and stage in ["play", "complete"]
	if not capture or not (full_case or fold_case):
		return
	await _settle()
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_check(picture != null and picture.get_size() == root.size, "Real renderer capture matches the current physical surface")
	if picture == null:
		return
	var name := "treasure-%dx%d-%s.png" % [root.size.x, root.size.y, stage]
	_check(picture.save_png(output.path_join(name)) == OK, "Fresh PNG written: " + name)
	images.append({"filename": name, "width": picture.get_width(), "height": picture.get_height(),
		"density": density, "renderer": RenderingServer.get_current_rendering_method()})


func _exercise() -> void:
	for control in game.top.get_children():
		if control is Button:
			_target(control, "exploration header / " + control.text)
	_target(game.jump_button, "jump")
	_target(game.joystick, "movement stick")
	_target(game.action, "interaction action")
	_check(not _physical_rect(game.joystick).intersects(_physical_rect(game.action)), "Stick and interaction action have separate touch rectangles")
	_check(not _physical_rect(game.jump_button).intersects(_physical_rect(game.action)), "Jump and interaction action have separate touch rectangles")
	var original_size := _physical_rect(game.jump_button).size
	for repeat in range(3):
		game._layout()
		await _settle(2)
	_check(_physical_rect(game.jump_button).size.is_equal_approx(original_size), "Repeated layout never compounds density")
	await _shot("play")
	for frame in range(12):
		await physics_frame
	var original_y: float = game.player.position.y
	await _tap(game.jump_button)
	for frame in range(6):
		await physics_frame
	_check(game.player.position.y > original_y + 0.04, "Real edge touch makes the existing character jump")
	var stick_rect := _physical_rect(game.joystick)
	var point := stick_rect.get_center() + Vector2(stick_rect.size.x * 0.20, 0)
	await _touch(point, true, 8)
	_check(game.joystick.target.x > 0.4, "Real stick touch reaches the existing movement input")
	await _touch(point + Vector2(500, 0), false, 8)
	_check(game.joystick.target == Vector2.ZERO, "Stick releases even outside its rectangle")

	await _tap(_button("Ⅱ"))
	await _dialog("pause")
	var resume := _button("Weiter erkunden", game.modal_box)
	await _reveal(resume, "pause resume")
	await _tap(resume)
	_check(not game.paused and not game.modal.visible, "Real pause-resume edge touches return to exploration")
	game.player.position = STATE.CLUES[0].at + Vector3.UP * 0.05
	game.player.velocity = Vector3.ZERO
	for frame in range(4):
		await physics_frame
	await _tap(game.action)
	if not game.modal.visible:
		_check(false, "Actual interaction touch opens the first clue")
		return
	await _shot("question")
	await _dialog("first clue")
	await _drag_dialog(game.modal_box.get_child(2) as Button)
	var wrong: Button = _button(str(STATE.CLUES[0].answers[1]), game.modal_box)
	await _reveal(wrong, "wrong answer remains full size")
	await _tap(wrong)
	_check(game.model.wrong_attempts == 1 and game.model.found.is_empty() and game.paused, "Actual wrong-answer touch preserves retry and original learning rules")
	var correct: Button = _button(str(STATE.CLUES[0].answers[0]), game.modal_box)
	await _reveal(correct, "correct answer")
	await _tap(correct)
	_check(game.model.found == ["tree"] and not game.paused, "Actual correct-answer edge touch grants the first existing item")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	var restored = STATE.new()
	_check(saved is Dictionary and int(saved.get("version", 0)) == 1 and restored.restore(saved), "First actual answer preserves the existing version-1 save contract")
	_check(restored.found == ["tree"], "The existing save restores precisely the earned clue")

	# Populate the long-inventory fixture through the original model rules.
	# The first and final question above/below use real production touch input.
	for index in [1, 2, 4, 3, 5]:
		var clue: Dictionary = STATE.CLUES[index]
		_check(game.model.answer(int(clue.correct), clue.at), "Existing branching prerequisites accept the inventory fixture")
	for spot in STATE.DISCOVERIES:
		game.model.try_discover(spot.at)
	game._update()
	game.player.position = STATE.CLUES[6].at + Vector3.UP * 0.05
	game.player.velocity = Vector3.ZERO
	for frame in range(4):
		await physics_frame
	await _tap(game.action)
	var final_answer: Button = _button(str(STATE.CLUES[6].answers[int(STATE.CLUES[6].correct)]), game.modal_box)
	await _reveal(final_answer, "final clue")
	var reward_count := rewards.size()
	await _tap(final_answer)
	_check(game.model.completed and game.modal.visible, "Final real answer opens the completion dialog")
	_check(rewards.size() == reward_count + 1, "Completion still emits exactly one original reward event")
	if rewards.size() > reward_count:
		var reward: Dictionary = rewards.back()
		_check(reward.get("resultId") == game.model.result_id and int(reward.get("stars", 0)) == 3 and int(reward.get("xp", 0)) == game.model.reward_xp(), "Original reward identity, stars and XP remain exact")
	await _shot("complete")
	await _dialog("completion")
	var explore: Button = _button("Insel weiter erkunden", game.modal_box)
	await _reveal(explore, "continue exploring")
	await _tap(explore)
	_check(not game.paused and game.model.completed, "Completion action preserves the completed adventure")

	await _tap(_button("Rucksack"))
	await _shot("inventory")
	await _dialog("full seven-item inventory and three discoveries")
	await _drag_dialog()
	var before_rotation: String = JSON.stringify(game.model.to_data())
	var dimensions := root.size
	root.size = Vector2i(dimensions.y, dimensions.x)
	await _settle(12)
	await _dialog("inventory after rotation")
	_check(JSON.stringify(game.model.to_data()) == before_rotation, "Rotation preserves all collected progress")
	root.size = dimensions
	await _settle(12)
	var close: Button = _button("Weiter erkunden", game.modal_box)
	await _reveal(close, "inventory return")
	await _tap(close)
	_check(not game.paused and game.joystick.enabled, "Real inventory return re-enables exploration")
	_check(game._save(), "The original atomic save still succeeds after responsive dialogs")
	saved = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	_check(restored.restore(saved) and restored.completed and restored.inventory.size() == 7 and restored.discoveries.size() == 3, "Completed inventory survives original save/restore without migration")


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("[TreasureDensity] --capture requires a real renderer, never headless PNGs")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var host = root.get_node("HostBridge")
	var original_options: Dictionary = host._options.duplicate(true)
	var original_launch: Dictionary = root.get_node("SceneRouter").launch_options.duplicate(true)
	# Godot enables mobile ScrollContainer dragging on desktop only with its
	# documented touch emulation flag. The injected events remain real touches.
	var original_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var on_reward := func(payload: Dictionary): rewards.append(payload.duplicate(true))
	host.reward_reported.connect(on_reward)
	for index in range(PROFILES.size()):
		var profile: Array = PROFILES[index]
		density = float(profile[1])
		root.size = profile[0]
		var child := "treasure-density-regression-%d" % index
		var save_path := "user://lumo_treasure_" + child + ".json"
		DirAccess.remove_absolute(save_path)
		host._options = {"displayDensity": density, "soundEnabled": false, "reduceAnimations": true, "childKey": child}
		root.get_node("SceneRouter").launch_options = {"childKey": child}
		game = load("res://scenes/creative/treasure_world.tscn").instantiate()
		root.add_child(game)
		await _settle(12)
		await _exercise()
		game.queue_free()
		await _settle()
		DirAccess.remove_absolute(save_path)
		print("[TreasureDensity] checked ", profile[0], " density=", density)
	host.reward_reported.disconnect(on_reward)
	host._options = original_options
	root.get_node("SceneRouter").launch_options = original_launch
	Input.emulate_touch_from_mouse = original_emulation
	if capture:
		_check(images.size() == 14, "Exactly fourteen fresh renderer PNGs were written")
	var file := FileAccess.open(output.path_join("treasure-density-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "images": images, "targets": targets,
			"physical_android_measurement": false, "capture_requires_renderer": true}, "  "))
		file.close()
	if failures.is_empty():
		print("[TreasureDensity] PASS checks=%d captures=%d; actual dp, edge touches, scroll, rotation, unchanged quests/saves/rewards" % [checks, images.size()])
		quit(0)
	else:
		print("[TreasureDensity] FAIL ", failures)
		quit(1)
