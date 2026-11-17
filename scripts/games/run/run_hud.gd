extends Control
## What the child sees while running: pause, star count, progress along the
## course with its checkpoints, a short message line, and the touch controls –
## steering stick on the left, DASH and a big JUMP on the right.

signal pause_pressed
signal jump_changed(held: bool)
signal dash_pressed
signal steer_changed(axis: Vector2)

const STICK = preload("res://scripts/games/kart_joystick.gd")
const ACTION = preload("res://scripts/games/run/run_touch_button.gd")
const UI = preload("res://scripts/games/run/run_ui.gd")
const THEME = preload("res://scripts/games/kart_ui_theme.gd")

var stick
var jump_button
var dash_button
var pause_button: Button
var top: Control
var toast: Label
var countdown: Label
var stars: int = 0
var star_total: int = 0
var solved: int = 0
var question_total: int = 3
var progress: float = 0.0
var marks := PackedFloat32Array()
var mark_is_question := PackedByteArray()
var reached: int = -1
var _toast_left: float = 0.0
var _unit: float = 1.0
var _bar := Rect2()
var _two_rows: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top = Control.new()
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.draw.connect(_draw_top)
	add_child(top)
	pause_button = Button.new()
	pause_button.name = "Pause"
	pause_button.tooltip_text = "Pause"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	pause_button.draw.connect(_draw_pause)
	add_child(pause_button)
	toast = UI.label("", 18.0, 1.0, UI.WHITE, true)
	toast.name = "Toast"
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.clip_text = false
	toast.hide()
	add_child(toast)
	countdown = UI.label("", 96.0, 1.0, UI.GOLD, true)
	countdown.name = "Countdown"
	countdown.add_theme_color_override("font_outline_color", UI.INK)
	countdown.hide()
	add_child(countdown)
	stick = STICK.new()
	stick.name = "SteerStick"
	stick.tooltip_text = "Lenken: Stick nach links oder rechts ziehen."
	stick.axis_changed.connect(func(axis: Vector2) -> void: steer_changed.emit(axis))
	add_child(stick)
	dash_button = ACTION.new()
	dash_button.name = "DashButton"
	dash_button.configure("dash", "FLITZEN", "Flitzen: kurzer Sprint, zerbricht Kisten.")
	dash_button.hold_changed.connect(_on_dash)
	add_child(dash_button)
	jump_button = ACTION.new()
	jump_button.name = "JumpButton"
	jump_button.configure("jump", "SPRINGEN", "Tippen: kleiner Sprung. Halten: hoher, weiter Sprung.")
	jump_button.hold_changed.connect(func(value: bool) -> void: jump_changed.emit(value))
	add_child(jump_button)
	get_viewport().size_changed.connect(layout)
	MobileRuntime.safe_area_changed.connect(layout)
	layout()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(layout):
		get_viewport().size_changed.disconnect(layout)
	if MobileRuntime.safe_area_changed.is_connected(layout):
		MobileRuntime.safe_area_changed.disconnect(layout)


func _on_dash(value: bool) -> void:
	if value:
		dash_pressed.emit()


func set_course(shares: PackedFloat32Array, questions: PackedByteArray, total: int) -> void:
	marks = shares
	mark_is_question = questions
	star_total = total
	question_total = 0
	for flag in questions:
		question_total += int(flag)
	top.queue_redraw()


func set_state(star_count: int, share: float, solved_count: int, checkpoint: int) -> void:
	if star_count == stars and solved_count == solved and checkpoint == reached and absf(share - progress) < 0.002:
		return
	stars = star_count
	progress = clampf(share, 0.0, 1.0)
	solved = solved_count
	reached = checkpoint
	top.queue_redraw()


func set_dash_cooldown(value: float) -> void:
	dash_button.set_cooldown(value)


func say(text: String, seconds: float = 2.4) -> void:
	toast.text = text
	toast.visible = not text.is_empty()
	_toast_left = seconds
	_place_toast()


func show_countdown(text: String) -> void:
	countdown.text = text
	countdown.visible = not text.is_empty()


## Shows or hides the running controls; menus take over while they are hidden.
func set_playing(value: bool) -> void:
	for control in [stick, jump_button, dash_button]:
		control.visible = value
		control.set_enabled(value)
	pause_button.visible = value
	pause_button.disabled = not value
	top.visible = value
	if not value:
		toast.hide()


func release_controls() -> void:
	stick._reset()
	jump_button.reset()
	dash_button.reset()


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			toast.hide()


func layout() -> void:
	if not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	_unit = UI.unit(self)
	var u: float = _unit
	var m: Vector4 = UI.margins(self)
	visible = MobileRuntime.safe_area_is_ready()
	var inner_width: float = view.x - m.x - m.z
	_two_rows = inner_width / u < 560.0
	var row: float = 52.0 * u
	pause_button.position = Vector2(m.x, m.y)
	pause_button.size = Vector2(row, row)
	var plain := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_button.add_theme_stylebox_override(state, plain)
	top.position = Vector2(m.x, m.y)
	top.size = Vector2(inner_width, row * (2.0 if _two_rows else 1.0) + (8.0 * u if _two_rows else 0.0))
	top.queue_redraw()
	pause_button.queue_redraw()
	var controls: float = minf(view.x, view.y) / u
	var stick_side: float = clampf(controls * 0.34, 124.0, 168.0) * u
	var jump_side: float = clampf(controls * 0.30, 112.0, 140.0) * u
	var dash_side: float = clampf(controls * 0.22, 84.0, 104.0) * u
	var bottom: float = view.y - m.w - 6.0 * u
	stick.custom_minimum_size = Vector2.ONE * stick_side
	stick.size = Vector2.ONE * stick_side
	stick.position = Vector2(m.x + 4.0 * u, bottom - stick_side)
	jump_button.size = Vector2.ONE * jump_side
	jump_button.position = Vector2(view.x - m.z - 4.0 * u - jump_side, bottom - jump_side)
	dash_button.size = Vector2.ONE * dash_side
	if view.x / u < 520.0:
		# Narrow phones: DASH sits above JUMP, the middle of the road stays free.
		dash_button.position = Vector2(
			view.x - m.z - 4.0 * u - dash_side, jump_button.position.y - dash_side - 10.0 * u
		)
	else:
		dash_button.position = Vector2(
			jump_button.position.x - dash_side - 10.0 * u, bottom - dash_side - 26.0 * u
		)
	toast.add_theme_font_size_override("font_size", roundi(16.0 * u))
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.02, 0.09, 0.22, 0.82)
	pill.set_corner_radius_all(roundi(18.0 * u))
	pill.set_content_margin_all(6.0 * u)
	pill.content_margin_left = 14.0 * u
	pill.content_margin_right = 14.0 * u
	toast.add_theme_stylebox_override("normal", pill)
	_place_toast()
	countdown.add_theme_font_size_override("font_size", roundi(110.0 * u))
	countdown.add_theme_constant_override("outline_size", roundi(16.0 * u))
	countdown.position = Vector2(0, view.y * 0.24)
	countdown.size = Vector2(view.x, 150.0 * u)


func _place_toast() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit
	var font: Font = THEME.HEADING
	var font_size: int = roundi(16.0 * u)
	var limit: float = minf(view.x - 28.0 * u, 460.0 * u)
	var inner: float = limit - 28.0 * u
	var text_width: float = font.get_string_size(toast.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lines: int = clampi(ceili(text_width / maxf(1.0, inner)), 1, 3)
	var width: float = minf(text_width / float(lines) + 44.0 * u, limit)
	var height: float = font.get_height(font_size) * float(lines) + 12.0 * u
	toast.custom_minimum_size = Vector2.ZERO
	toast.position = Vector2((view.x - width) * 0.5, top.position.y + top.size.y + 8.0 * u)
	toast.size = Vector2(width, height)


func _draw_pause() -> void:
	var u: float = _unit
	var side: float = pause_button.size.x
	var centre := Vector2(side, side) * 0.5
	pause_button.draw_circle(centre, side * 0.48, Color(0.02, 0.09, 0.22, 0.86))
	pause_button.draw_arc(centre, side * 0.46, 0.0, TAU, 40, UI.CYAN, 2.0 * u, true)
	for shift in [-1.0, 1.0]:
		pause_button.draw_rect(
			Rect2(centre + Vector2(shift * side * 0.13 - side * 0.055, -side * 0.17), Vector2(side * 0.11, side * 0.34)),
			UI.WHITE
		)


func _draw_top() -> void:
	var u: float = _unit
	var row: float = 52.0 * u
	var font: Font = THEME.HEADING
	var font_size: int = roundi(21.0 * u)
	var left: float = row + 8.0 * u
	# Stars collected.
	var count: String = str(stars)
	var count_width: float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var star_pill := Rect2(left, 6.0 * u, 54.0 * u + count_width, row - 12.0 * u)
	_pill(star_pill, UI.GOLD)
	top.draw_colored_polygon(
		UI.star_points(star_pill.position + Vector2(22.0 * u, star_pill.size.y * 0.5), 13.0 * u), UI.GOLD
	)
	top.draw_string(
		font, star_pill.position + Vector2(42.0 * u, star_pill.size.y * 0.5 + font_size * 0.36), count,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UI.WHITE
	)
	# Learning stops solved.
	var tasks: String = "%d/%d" % [solved, question_total]
	var tasks_width: float = font.get_string_size(tasks, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var task_pill := Rect2(top.size.x - 50.0 * u - tasks_width, 6.0 * u, 50.0 * u + tasks_width, row - 12.0 * u)
	_pill(task_pill, UI.CYAN)
	top.draw_circle(task_pill.position + Vector2(20.0 * u, task_pill.size.y * 0.5), 12.0 * u, UI.CYAN)
	top.draw_string(
		font, task_pill.position + Vector2(14.5 * u, task_pill.size.y * 0.5 + 7.0 * u), "?",
		HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(19.0 * u), UI.INK
	)
	top.draw_string(
		font, task_pill.position + Vector2(38.0 * u, task_pill.size.y * 0.5 + font_size * 0.36), tasks,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UI.WHITE
	)
	# Progress along the course.
	if _two_rows:
		_bar = Rect2(10.0 * u, row + 22.0 * u, top.size.x - 20.0 * u, 14.0 * u)
	else:
		var from: float = star_pill.end.x + 22.0 * u
		_bar = Rect2(from, row * 0.5 - 7.0 * u, task_pill.position.x - 22.0 * u - from, 14.0 * u)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.09, 0.22, 0.86)
	track.border_color = Color(1, 1, 1, 0.55)
	track.set_border_width_all(maxi(1, roundi(1.5 * u)))
	track.set_corner_radius_all(roundi(7.0 * u))
	top.draw_style_box(track, _bar)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.GOLD
	fill.set_corner_radius_all(roundi(5.0 * u))
	var filled: float = maxf(0.0, (_bar.size.x - 4.0 * u) * progress)
	if filled > 2.0:
		top.draw_style_box(fill, Rect2(_bar.position + Vector2(2.0 * u, 2.0 * u), Vector2(filled, _bar.size.y - 4.0 * u)))
	for index in range(marks.size()):
		var at := Vector2(_bar.position.x + _bar.size.x * marks[index], _bar.position.y + _bar.size.y * 0.5)
		var done: bool = index <= reached
		if mark_is_question[index] != 0:
			top.draw_circle(at, 9.0 * u, UI.INK)
			top.draw_circle(at, 7.5 * u, UI.CYAN if not done else UI.GOLD)
			top.draw_string(font, at + Vector2(-3.6 * u, 4.6 * u), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12.0 * u), UI.INK)
		else:
			top.draw_circle(at, 6.0 * u, UI.INK)
			top.draw_circle(at, 4.5 * u, UI.WHITE if not done else UI.GOLD)
	# Finish flag and Lumo's marker.
	var goal := Vector2(_bar.end.x, _bar.position.y + _bar.size.y * 0.5)
	top.draw_rect(Rect2(goal + Vector2(-2.0 * u, -15.0 * u), Vector2(3.0 * u, 24.0 * u)), UI.WHITE)
	top.draw_rect(Rect2(goal + Vector2(1.0 * u, -15.0 * u), Vector2(13.0 * u, 10.0 * u)), UI.GOLD)
	var marker := Vector2(_bar.position.x + _bar.size.x * progress, _bar.position.y + _bar.size.y * 0.5)
	top.draw_circle(marker, 11.0 * u, UI.WHITE)
	top.draw_circle(marker, 8.5 * u, Color("ff8a2a"))
	for side in [-1.0, 1.0]:
		top.draw_colored_polygon(
			PackedVector2Array(
				[
					marker + Vector2(side * 2.5 * u, -7.0 * u),
					marker + Vector2(side * 9.0 * u, -15.0 * u),
					marker + Vector2(side * 9.5 * u, -4.0 * u),
				]
			),
			Color("ff8a2a")
		)


func _pill(rect: Rect2, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.09, 0.22, 0.86)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	style.set_border_width_all(maxi(1, roundi(1.5 * _unit)))
	style.set_corner_radius_all(roundi(rect.size.y * 0.5))
	top.draw_style_box(style, rect)
