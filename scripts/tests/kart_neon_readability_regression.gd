extends SceneTree
## Exercise real production controls; every requested window must change the canvas.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const SURFACES := [Vector2i(360, 800), Vector2i(412, 915), Vector2i(840, 960), Vector2i(960, 720), Vector2i(1280, 800), Vector2i(915, 412)]
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _button(button: Button, factor: float, tag: String) -> void:
	var font: Font = button.get_theme_font("font")
	var pixels: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var text_height: float = font.get_height(pixels)
	var style: StyleBox = button.get_theme_stylebox("normal")
	var inset: Vector2 = style.get_minimum_size()
	_check(not button.clip_text, tag + ": full label is not clipped")
	_check(button.size.x + 1.0 >= text_width + inset.x, tag + ": measured text fits its button")
	_check(button.size.y + 1.0 >= text_height + inset.y, tag + ": measured text height fits")
	_check(button.size.x / factor >= 47.5 and button.size.y / factor >= 47.5, tag + ": at least 48dp touch surface")

func _inside(control: Control, surface: Rect2, tag: String) -> void:
	var bounds: Rect2 = control.get_global_rect()
	_check(surface.grow(1.0).encloses(bounds), tag + ": control remains in the visible surface")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	var hub = HUB.new()
	hub.total_stars = 17
	hub.current_mode = "race"
	root.add_child(hub)
	for dimensions in SURFACES:
		root.size = dimensions
		for frame in range(3):
			await process_frame
		hub.size = hub.get_viewport_rect().size
		hub._layout()
		for frame in range(8):
			await process_frame
		var factor: float = hub._layout_scale
		var surface := Rect2(Vector2.ZERO, hub.size)
		var tag := "%dx%d" % [dimensions.x, dimensions.y]
		_check(hub.size.is_equal_approx(Vector2(dimensions)), tag + ": actual canvas matches requested dimensions")
		for group in [hub._features, hub._extra_modes, hub._navigation, hub._track_row]:
			for child in group.get_children():
				if child is Button and child.is_visible_in_tree():
					_button(child, factor, tag + "/" + str(child.name))
		for button in [hub._back, hub._start, hub._highlight_pick]:
			_button(button, factor, tag + "/" + str(button.name))
		for control in [hub._header, hub._footer, hub._dock, hub._modes, hub._extra_modes, hub._features, hub._highlight, hub._progress]:
			if control.is_visible_in_tree():
				_inside(control, surface, tag + "/" + str(control.name))
		for id in hub._mode_buttons:
			var card = hub._mode_buttons[id]
			var label: Label = card.title_label
			_check(label.text == card.title, tag + "/" + str(id) + ": complete mode name")
			_check(card.size.y / factor >= 47.5, tag + "/" + str(id) + ": 48dp mode card")
		var panels: Array[Control] = [hub._modes, hub._extra_modes, hub._features, hub._highlight, hub._progress, hub._footer, hub._dock]
		for first in range(panels.size()):
			for second in range(first + 1, panels.size()):
				if panels[first].is_visible_in_tree() and panels[second].is_visible_in_tree():
					_check(not panels[first].get_global_rect().grow(-1.0).intersects(panels[second].get_global_rect().grow(-1.0)), tag + ": distinct interaction panels " + str(panels[first].name) + "/" + str(panels[second].name))
		captures.append({"window": [dimensions.x, dimensions.y], "scale": factor, "canvas": [hub.size.x, hub.size.y]})
	_check(hub._navigation.get_child_count() == 9, "existing navigation endpoints preserved")
	_check(hub._progress_label.text.contains("17"), "only actual saved stars displayed")
	hub.free()
	var report := {"checks": checks, "failures": failures, "surfaces": captures, "status": "PASS" if failures.is_empty() else "FAIL", "scope": "Godot control layout; not Android installation, game completion or reference-art acceptance"}
	print("[NeonReadability] ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
