extends SceneTree
## Real start, flight and pause controls at five living viewport shapes.
## Run with X11 or another windowed renderer. Optional LUMO_SKY_POST_BELEGE
## records the real framebuffer; --disable-render-loop saves device-independent work.

const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const SHAPES := [
	[Vector2i(640, 480), 1.0],
	[Vector2i(1080, 2340), 2.625],
	[Vector2i(2340, 1080), 2.625],
	[Vector2i(2176, 1812), 2.625],
	[Vector2i(2560, 1600), 2.0],
]

var game: Node
var ui: Script
var checks := 0
var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[SkyPostMenu] FAIL " + message)


func _frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame


func _safe_rect(minimum: float = 14.0) -> Rect2:
	var view := root.get_visible_rect()
	var margins: Vector4 = ui.margins(game.menus, minimum)
	return view.grow_individual(-margins.x, -margins.y, -margins.z, -margins.w)


func _button(id: String, from_hud: bool = false) -> Button:
	var place: Node = game.hud if from_hud else game.menus
	return place.find_child(id, true, false) as Button


func _press(id: String, from_hud: bool = false) -> void:
	var button := _button(id, from_hud)
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "%s %s exists" % [root.size, id])
	if not is_instance_valid(button):
		return
	var scroll := game.menus.find_child("SettingsScroll", true, false) as ScrollContainer
	if scroll != null and scroll.is_ancestor_of(button):
		scroll.ensure_control_visible(button)
		await _frames(4)
	var target := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(target), "%s %s touch lies in the window" % [root.size, id])
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = root.get_final_transform() * target
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _frames(5)


func _shot(name: String) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var output := capture_dir.path_join("%s_%dx%d.jpg" % [name, root.size.x, root.size.y])
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == root.size and image.save_jpg(output, 0.9) == OK,
		"real screenshot " + output)
	RenderingServer.render_loop_enabled = false


func _check_start() -> void:
	var panel := game.menus.get_node("StartPanel") as PanelContainer
	var scroll := game.menus.find_child("SettingsScroll", true, false) as ScrollContainer
	_check(is_instance_valid(panel) and is_instance_valid(scroll), "%s produced its start menu" % root.size)
	if panel == null or scroll == null:
		return
	var unit: float = ui.unit(game.menus)
	_check(_safe_rect().grow(1.0).encloses(panel.get_global_rect()), "%s panel fits the safe area" % root.size)
	_check(scroll.scroll_horizontal == 0 and not scroll.get_h_scroll_bar().visible,
		"%s has no horizontal scrolling" % root.size)
	var clip := scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		clip.size.x -= scroll.get_v_scroll_bar().size.x
	for button: Button in panel.find_children("*", "Button", true, false):
		var box := button.get_global_rect()
		_check(box.size.x / unit >= 47.99 and box.size.y / unit >= 47.99,
			"%s %s maintains a 48 dp target" % [root.size, button.name])
		if scroll.is_ancestor_of(button):
			_check(box.position.x >= clip.position.x - 1.0 and box.end.x <= clip.end.x + 1.0,
				"%s %s stays within the horizontal content bounds" % [root.size, button.name])
		else:
			_check(panel.get_global_rect().encloses(box) and box.position.y >= clip.end.y,
				"%s %s has an independently visible footer" % [root.size, button.name])
		if button.name == "ResumeFlight":
			var font := button.get_theme_font("font")
			var font_size := button.get_theme_font_size("font_size")
			var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var padding := button.get_theme_stylebox("normal").get_minimum_size().x
			_check(text_width + padding <= button.size.x, "the continue label fits without clipping")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[SkyPostMenu] Use a windowed renderer for real viewport dimensions.")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_SKY_POST_BELEGE")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var saved_emulation := Input.emulate_mouse_from_touch
	ui = load("res://scripts/games/run/run_ui.gd")
	Input.emulate_mouse_from_touch = true
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	var router := root.get_node("SceneRouter")
	router.launch_options = {
		"grade": 4, "subject": "Deutsch", "childKey": "skypost-layout-real-touch",
		"skypostProfile": "low", "reduceAnimations": true,
	}
	root.size = SHAPES[0][0]
	game = (load("res://scenes/games/sky_post.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	game.build_now()
	for shape in SHAPES:
		bridge._options["displayDensity"] = shape[1]
		root.size = shape[0]
		await _frames(10)
		game.menus.refresh()
		await _frames(8)
		_check(root.size == shape[0], "received viewport %s" % shape[0])
		_check_start()
		if shape[0] != SHAPES[-1][0]:
			await _shot("nachher")
	# Exercise the repaired options and persistent actions at the exact 640 px
	# geometry that used to cut off the right border and the start button.
	bridge._options["displayDensity"] = 1.0
	root.size = SHAPES[0][0]
	await _frames(9)
	game.menus.refresh()
	await _frames(8)
	await _press("HelpButton")
	_check(game.menus.screen == "help", "touch opens instructions")
	var close_help := _button("CloseHelp")
	if close_help != null:
		var help_scroll := close_help.get_parent().get_parent() as ScrollContainer
		help_scroll.ensure_control_visible(close_help)
	await _frames(5)
	await _press("CloseHelp")
	_check(game.menus.screen == "start", "touch returns from instructions")
	await _press("Mode_race")
	_check(game.mode == "race", "the cloud race is selectable")
	await _press("Mode_delivery")
	_check(game.mode == "delivery", "the delivery flight is selectable")
	await _press("Stage_extrem")
	_check(game.stage == "extrem", "the final difficulty is selectable")
	await _press("Colour_mintgruen")
	_check(game.colour == "mintgruen", "the final paint is selectable")
	await _press("Riddles")
	_check(not game.riddles, "the address setting is reachable")
	await _shot("optionen")
	await _press("StartFlight")
	_check(game.phase == game.Phase.FLYING and game.menus.screen.is_empty(), "footer opens the real flight")
	for _step in range(150):
		game.advance(1.0 / 60.0)
	var flight_result := str(game.result_id)
	await _press("Pause", true)
	_check(game.paused and game.menus.screen == "pause", "pause opens its real dialog")
	_check(_safe_rect(12.0).grow(1.0).encloses(game.menus.dialog_rect()), "pause remains inside its safe area")
	await _press("Menu")
	_check(game.menus.screen == "start", "back opens the same start screen")
	_check_start()
	await _shot("fortsetzen")
	await _press("ResumeFlight")
	_check(game.phase == game.Phase.FLYING and game.result_id == flight_result, "footer resumes the saved flight")
	game.abandoned = true
	_check(await TEARDOWN.release_scene(self, game, "[SkyPostMenu]"), "released the real production scene")
	game = null
	root.get_node("GameSoundscape").release_audio()
	bridge._options = original_options
	Input.emulate_mouse_from_touch = saved_emulation
	await _frames(5)
	print("[SkyPostMenu] %s %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
