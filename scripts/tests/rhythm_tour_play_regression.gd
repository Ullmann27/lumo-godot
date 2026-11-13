extends SceneTree
## Real production UI and pointer routing. Note time is deliberately controlled
## to test judgement boundaries reproducibly, not to claim device/audio latency.
const TOUR = preload("res://scripts/creative/rhythm_tour.gd")
var checks := 0
var failures: Array[String] = []
var game
var capture_dir := ""
const CHILD_A := "rhythm_tour_ui_A"
const CHILD_B := "rhythm_tour_ui_B"


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_warning("[RhythmTourPlay] " + message)


func _frames(count := 5) -> void:
	for _index in range(count):
		await process_frame


func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var result := _button(child, caption)
		if result != null:
			return result
	return null


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap(at: Vector2) -> void:
	await _touch(2, at, true)
	await _touch(2, at, false)
	await _frames(2)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _lane(index: int) -> Vector2:
	return game.lane_buttons[index].get_global_rect().get_center()


func _at(time: float) -> void:
	game.model.advance(maxf(0, time - game.model.time))
	game._draw_notes()


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == Vector2i(1280, 720), "Actual renderer image " + name)
	if image != null:
		_check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Image saved " + name)


func _load_game(child_key: String) -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": child_key}
	game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await _frames(8)


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
			push_error("[RhythmTourPlay] Capture requires a real renderer and LUMO_CAPTURE_DIR")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	var path_a := "user://lumo_rhythm_" + CHILD_A + ".cfg"
	var path_b := "user://lumo_rhythm_" + CHILD_B + ".cfg"
	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)
	var seed := ConfigFile.new()
	seed.set_value("sternentanz", "best", 4485)
	seed.set_value("legacy_setting", "retained", "yes")
	seed.save(path_a)
	seed = ConfigFile.new()
	seed.set_value("sternentanz", "best", 123)
	seed.save(path_b)
	var sibling_bytes := FileAccess.get_file_as_string(path_b)
	await _load_game(CHILD_A)
	_check(not game.tour_mode and game.tour.cleared == [0, 0, 0], "Existing players retain free selection and begin a new optional tour")
	await _tap(_button(game, "Modus: Freies Spielen").get_global_rect().get_center())
	_check(game.tour_mode and game.tour_stage == 0, "Actual mode button opens the reachable first stage")
	_check(game.tour_beacons.size() == 4, "Campaign progress is connected to four real stage landmarks")
	await _capture("01_rhythm_tour_map")
	game.menu_scroll.scroll_vertical = 10000
	await _frames()
	await _tap(_button(game, "Los geht’s!").get_global_rect().get_center())
	game.set_process(false)
	_check(game.running and game.round_stage == 0 and game.model.song.id == "sternentanz", "Actual start opens the selected campaign chart")
	_check(game.note_nodes.size() == 40, "Every judged note is represented in the live scene")

	var first: Dictionary = game.model.notes[0]
	_at(first.time)
	game.audio.play(float(first.time))
	await _touch(10, _lane(first.lane), true)
	_check(first.state == 2, "Real touch hits the correct note")
	await _touch(10, Vector2(4, 180), false)
	_check(game.touch_lanes.is_empty() and game.model.held.is_empty(), "Release outside a lane clears physical ownership")
	var second: Dictionary = game.model.notes[1]
	_at(second.time)
	await _tap(_lane((int(second.lane) + 1) % 4))
	_at(second.time + game.model.window + 0.01)
	_check(second.state == 3, "Wrong lane remains a miss")

	var hold: Dictionary = game.model.notes[4]
	_at(hold.time)
	await _touch(11, _lane(hold.lane), true)
	_check(hold.state == 1, "Actual held finger starts a hold")
	await _drag(11, _lane(hold.lane) + Vector2(1, 0))
	_at(hold.time + hold.length + 0.01)
	await _touch(11, Vector2(4, 180), false)
	_check(hold.state == 2 and game.model.held.is_empty(), "Held note completes once and does not leave sticky input")

	var slide: Dictionary = game.model.notes[7]
	_at(slide.time)
	await _touch(12, _lane(slide.lane), true)
	_check(slide.state == 4, "Actual touch starts the slide")
	_check(game.note_nodes[7].get_meta("slide_target_lane") == slide.target, "Rendered slide points to the actual rules target")
	await _capture("02_rhythm_slide")
	_at(slide.time + slide.length)
	await _drag(12, _lane(slide.target))
	_check(slide.state == 2, "Real drag completes the adjacent-lane slide")
	await _touch(12, Vector2(4, 180), false)
	_check(game.touch_lanes.is_empty() and game.model.held.is_empty(), "Slide releases both original and target lanes")
	await _touch(20, _lane(0), true)
	await _touch(21, _lane(3), true)
	_check(game.model.held.has(0) and game.model.held.has(3), "Two fingers own two lanes independently")
	await _touch(20, _lane(0), false)
	_check(not game.model.held.has(0) and game.model.held.has(3), "Releasing first finger preserves the second")
	await _touch(21, _lane(3), false)
	_check(game.model.held.is_empty(), "Second finger releases cleanly")

	var paused_hold: Dictionary = game.model.notes[14]
	_at(paused_hold.time)
	await _touch(25, _lane(paused_hold.lane), true)
	await _tap(_button(game, "Ⅱ").get_global_rect().get_center())
	var paused_time: float = game.model.time
	game._process(3)
	_check(game.paused and game.model.time == paused_time and game.model.held.is_empty(), "Pause freezes time and clears physical fingers")
	await _touch(25, _lane(paused_hold.lane), false)
	await _tap(_button(game, "Weiter im Takt").get_global_rect().get_center())
	_check(not game.paused and game.resume_countdown == 2.0 and game.audio.stream_paused, "Resume grants a count-in before audio and judgement advance")
	await _touch(26, _lane(paused_hold.lane), true)
	game._process(2.01)
	_check(game.model.time == paused_time and game.model.held.has(paused_hold.lane), "Child can reacquire a paused hold during count-in")
	_at(paused_hold.time + paused_hold.length + 0.01)
	await _touch(26, _lane(paused_hold.lane), false)
	_check(paused_hold.state == 2, "Reacquired held note completes fairly")

	# Continue through actual touch/drag routes with deliberately imprecise but
	# acceptable timing. Earlier skipped notes remain real misses.
	for index in range(15, 40):
		var note: Dictionary = game.model.notes[index]
		var error: float = game.model.window * 0.6
		_at(note.time + error)
		await _touch(30, _lane(note.lane), true)
		if note.kind == "hold":
			_at(note.time + note.length + 0.01)
		elif note.kind == "slide":
			_at(note.time + note.length + error)
			await _drag(30, _lane(note.target))
		await _touch(30, Vector2(4, 180), false)
	_at(game.model.duration)
	game._process(0)
	_check(game.finished and game.model.misses > 0 and game.model.accuracy() < 0.8, "Real played round ends with tolerated mistakes")
	_check(game.last_tour_result.get("passed", false) and game.tour.cleared == [1, 0, 0], "Passing goal opens exactly one stage on chosen difficulty")
	_check(game.tour_beacons[0].get_meta("tour_completed") and not game.tour_beacons[1].get_meta("tour_completed"), "Actual stage geometry reflects saved progress")
	await _capture("03_rhythm_tour_result")
	var saved := ConfigFile.new()
	_check(saved.load(path_a) == OK and saved.get_value("sternentanz", "best") == 4485 and saved.get_value("legacy_setting", "retained") == "yes", "New tour save preserves existing best and unknown data")
	_check(FileAccess.get_file_as_string(path_b) == sibling_bytes, "One child's tour never writes another child's file")
	game.menu_scroll.scroll_vertical = 10000
	await _frames()
	await _tap(_button(game, "Zur Tourkarte").get_global_rect().get_center())
	_check(game.tour_stage == 1, "Actual result action opens the newly available stage")
	for dimensions in [Vector2i(412, 915), Vector2i(690, 829), Vector2i(914, 411)]:
		root.size = dimensions
		await _frames(8)
		_check(root.get_visible_rect().encloses(game.menu.get_global_rect()), "Campaign menu fits " + str(dimensions))
		for button in game.lane_buttons:
			_check(root.get_visible_rect().encloses(button.get_global_rect()) and button.size.x >= 48 and button.size.y >= 48, "Lane touch target fits >=48dp " + str(dimensions))
		game.menu_scroll.scroll_vertical = 10000
		await _frames()
		_check(game.menu_scroll.get_global_rect().encloses(_button(game, "Los geht’s!").get_global_rect()), "Start remains reachable through the menu scroll " + str(dimensions))
	await _tap(_button(game, "Los geht’s!").get_global_rect().get_center())
	_check(game.running and game.round_stage == 1 and game.model.song.id == "wolkenwalzer", "Unlocked stage launches its own actual song")
	game.queue_free()
	await _frames(3)
	await _load_game(CHILD_B)
	_check(game.tour.cleared == [0, 0, 0] and game.progress_config.get_value("sternentanz", "best") == 123, "Second child's production scene has independent progress")
	game.queue_free()
	await _frames(3)
	await _load_game(CHILD_A)
	_check(game.tour.cleared == [1, 0, 0], "Actual scene reload restores only the saved completed stage")
	game.queue_free()
	await _frames(3)
	for path in [path_a, path_b]:
		DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("[RhythmTourPlay] PASS checks=", checks, ": actual tour controls, touch/hold/slide/multitouch/pause, progress, profiles and responsive layout")
		quit(0)
	else:
		print("[RhythmTourPlay] FAIL ", failures)
		quit(1)
