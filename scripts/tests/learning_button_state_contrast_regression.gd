extends SceneTree
## Executes the production factory verbatim with Godot's real default theme and
## input dispatch. No 3D assets, speech transport, or Android device are simulated.
## Set LUMO_LEARNING_WORLD_SOURCE and LUMO_CONTRAST_OUTPUT for an isolated project.

const FONT_ITEMS := [
	"font_color",
	"font_hover_color",
	"font_focus_color",
	"font_pressed_color",
	"font_hover_pressed_color",
]
const STYLE_ITEMS := ["normal", "hover", "pressed", "focus"]
const MIN_CONTRAST := 4.5

var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var activations := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("[LearningButtonContrast] " + description)


func _frames() -> void:
	for index in range(3):
		await process_frame


func _activate() -> void:
	activations += 1


func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await _frames()


func _mouse(button: Button, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)
	await _frames()


func _space(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = down
	root.push_input(event, true)
	await _frames()


func _state(button: Button, name: String, mode: int, focused: bool, hovered: bool) -> void:
	var observation := {
		"caption": button.text,
		"state": name,
		"draw_mode": button.get_draw_mode(),
		"focused": button.has_focus(),
		"hovered": button.is_hovered(),
		"pressed": button.is_pressed(),
		"disabled": button.disabled,
	}
	observations.append(observation)
	_check(
		(
			observation.draw_mode == mode
			and observation.focused == focused
			and observation.hovered == hovered
			and observation.pressed == (mode == BaseButton.DRAW_PRESSED)
			and not observation.disabled
		),
		button.text + " receives actual input state " + name
	)


func _linear(component: float) -> float:
	return component / 12.92 if component <= 0.04045 else pow((component + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _palette(button: Button) -> Dictionary:
	var colors := {}
	var backgrounds := {}
	var ratios := {}
	var minimum := INF
	for item in FONT_ITEMS:
		colors[item] = button.get_theme_color(item).to_html()
	for style_name in STYLE_ITEMS:
		var style := button.get_theme_stylebox(style_name) as StyleBoxFlat
		_check(style != null and is_equal_approx(style.bg_color.a, 1.0),
			button.text + " has an observable opaque " + style_name + " background")
		if style == null:
			continue
		backgrounds[style_name] = style.bg_color.to_html()
		for item in FONT_ITEMS:
			var foreground := button.get_theme_color(item)
			var visible_ink := style.bg_color.blend(foreground)
			var ink := _luminance(visible_ink)
			var paper := _luminance(style.bg_color)
			var ratio := (maxf(ink, paper) + 0.05) / (minf(ink, paper) + 0.05)
			ratios[style_name + "/" + item] = ratio
			minimum = minf(minimum, ratio)
			# Check every real state-color/background pairing, including focus
			# overlays, without copying Button's internal state-precedence code.
			_check(ratio >= MIN_CONTRAST,
				"%s %s/%s contrast %.6f >= %.1f" % [
					button.text, style_name, item, ratio, MIN_CONTRAST])
	return {
		"caption": button.text,
		"colors": colors,
		"backgrounds": backgrounds,
		"contrast_ratios": ratios,
		"minimum_contrast": minimum,
		"disabled_font_observed_only": button.get_theme_color("font_disabled_color").to_html(),
	}


func _exercise(button: Button) -> void:
	var before := activations
	_check(not button.toggle_mode, button.text + " preserves its production non-toggle behavior")
	await _move(Vector2(700, 500))
	button.release_focus()
	await _frames()
	_state(button, "normal", BaseButton.DRAW_NORMAL, false, false)
	button.grab_focus()
	await _frames()
	_state(button, "focus", BaseButton.DRAW_NORMAL, true, false)
	button.release_focus()
	await _move(button.get_global_rect().get_center())
	_state(button, "hover", BaseButton.DRAW_HOVER, false, true)
	button.grab_focus()
	await _frames()
	_state(button, "hover+focus", BaseButton.DRAW_HOVER, true, true)
	await _mouse(button, true)
	_state(button, "mouse-held+hover+focus", BaseButton.DRAW_PRESSED, true, true)
	await _mouse(button, false)
	_check(activations == before + 1, button.text + " activates once on mouse release")
	await _space(true)
	_state(button, "key-held+hover+focus", BaseButton.DRAW_PRESSED, true, true)
	await _space(false)
	_check(activations == before + 2, button.text + " activates once on hovered keyboard release")
	await _move(Vector2(700, 500))
	await _space(true)
	_state(button, "key-held+focus", BaseButton.DRAW_PRESSED, true, false)
	await _space(false)
	_state(button, "released+focus", BaseButton.DRAW_NORMAL, true, false)
	_check(activations == before + 3, button.text + " activates once on keyboard release")
	button.release_focus()


func _run() -> void:
	var source_path := OS.get_environment("LUMO_LEARNING_WORLD_SOURCE")
	if source_path.is_empty():
		source_path = "res://scripts/learning/learning_world.gd"
	var source := FileAccess.get_file_as_string(source_path)
	var start := source.find("func _button(")
	var end := source.find("\nfunc ", start + 1)
	_check(start >= 0 and end > start, "Production button factory is available")
	if start < 0 or end <= start:
		quit(1)
		return
	var method := source.substr(start, end - start)
	var script := GDScript.new()
	script.source_code = "extends Node\nvar actions: HFlowContainer\n" + method
	var error := script.reload()
	_check(error == OK, "Verbatim production factory compiles in the actual engine")
	if error != OK:
		quit(1)
		return
	var factory = script.new()
	root.add_child(factory)
	root.size = Vector2i(720, 520)
	var actions := HFlowContainer.new()
	actions.position = Vector2(24, 80)
	actions.size = Vector2(650, 150)
	root.add_child(actions)
	factory.actions = actions
	var theme := ThemeDB.get_default_theme()
	for item in FONT_ITEMS:
		_check(item in theme.get_color_list("Button"), "Engine exposes actual Button theme item " + item)
	var palettes: Array[Dictionary] = []
	for caption in ["Stimme stoppen", "Ein Objekt zeigen"]:
		var button: Button = factory._button(caption, _activate)
		await _frames()
		palettes.append(_palette(button))
		await _exercise(button)
	var result := {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"engine": Engine.get_version_info(),
		"display_driver": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"production_source_sha256": source.sha256_text(),
		"production_factory_sha256": method.sha256_text(),
		"test_sha256": FileAccess.get_file_as_string(get_script().resource_path).sha256_text(),
		"checks": checks,
		"failures": failures,
		"minimum_required_contrast": MIN_CONTRAST,
		"palettes": palettes,
		"input_observations": observations,
		"callback_activations": activations,
		"limits": [
			"Exact production factory tested in isolation; no full learning scene or 3D assets",
			"Theme colors and actual input states; no framebuffer or Android pixel measurement",
			"Original Android draw mode unknown; this run does not identify it",
			"Non-toggle hover+press uses DRAW_PRESSED; hover_pressed font is palette-tested only",
			"Disabled palette reported only; disabled behavior and styles remain unchanged",
			"No speech, acoustic stop, mouth timing, or device touch claim",
		],
	}
	var output := OS.get_environment("LUMO_CONTRAST_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Cannot save contrast result")
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print("[LearningButtonContrast] %d/%d PASS; %d FAIL" % [checks - failures.size(), checks, failures.size()])
	factory.free()
	actions.free()
	quit(0 if failures.is_empty() else 1)
