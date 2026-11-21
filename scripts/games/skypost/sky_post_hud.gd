extends Control
## What the child sees while flying: pause, star sparks, the time, the current
## task (letter card with the riddle address, race place and lap, free-flight
## album), an arrow to the goal, messages, and the touch controls: the stick on
## the left, SCHWUNG and ABWERFEN on the right.

signal pause_pressed
signal steer_changed(axis: Vector2)
signal boost_pressed
signal drop_pressed

const STICK = preload("res://scripts/games/kart_joystick.gd")
const BUTTON = preload("res://scripts/games/skypost/sky_post_button.gd")
const UI = preload("res://scripts/games/run/run_ui.gd")

var stick
var boost_button
var drop_button
var pause_button: Button
var top: Control
var card: Control
var pointer: Control
var toast: Label
var countdown: Label
var banner_label: Label
var mode: String = "delivery"
var sparks: int = 0
var spark_total: int = 0
var time_ms: int = 0
## Delivery card.
var card_item: String = "Brief"
var card_to: String = ""
var card_address: String = ""
var card_place: String = ""
var card_step: String = ""
## Race / free flight line.
var info_line: String = ""
var place: int = 0
## Goal arrow: screen position of the goal, on-screen flag and distance.
var goal_screen := Vector2.ZERO
var goal_visible: bool = false
var goal_on_screen: bool = false
var goal_distance: float = 0.0
var goal_colour := Color("ffd75e")
var _unit: float = 1.0
var _toast_left: float = 0.0
var _banner_left: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer = Control.new()
	pointer.name = "GoalPointer"
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.draw.connect(_draw_pointer)
	add_child(pointer)
	top = Control.new()
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.draw.connect(_draw_top)
	add_child(top)
	card = Control.new()
	card.name = "TaskCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(_draw_card)
	add_child(card)
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
	toast.hide()
	add_child(toast)
	countdown = UI.label("", 96.0, 1.0, UI.GOLD, true)
	countdown.name = "Countdown"
	countdown.add_theme_color_override("font_outline_color", UI.INK)
	countdown.hide()
	add_child(countdown)
	banner_label = UI.label("", 34.0, 1.0, UI.GOLD, true)
	banner_label.name = "Banner"
	banner_label.add_theme_color_override("font_outline_color", UI.INK)
	banner_label.hide()
	add_child(banner_label)
	stick = STICK.new()
	stick.name = "FlightStick"
	stick.skin = "kart3d"
	stick.tooltip_text = "Fliegen: Stick nach oben steigt, nach unten sinkt, zur Seite lenkt."
	stick.axis_changed.connect(func(axis: Vector2) -> void: steer_changed.emit(axis))
	add_child(stick)
	boost_button = BUTTON.new()
	boost_button.name = "BoostButton"
	boost_button.configure("boost", "SCHWUNG", "Schwung: kurz schneller fliegen.")
	boost_button.pressed_now.connect(func() -> void: boost_pressed.emit())
	add_child(boost_button)
	drop_button = BUTTON.new()
	drop_button.name = "DropButton"
	drop_button.configure(
		"drop", "ABWERFEN", "Abwerfen: Brief oder Paket fällt am Sternschirm hinunter."
	)
	drop_button.pressed_now.connect(func() -> void: drop_pressed.emit())
	add_child(drop_button)
	get_viewport().size_changed.connect(layout)
	MobileRuntime.safe_area_changed.connect(layout)
	layout()
	set_playing(false)


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(layout):
		get_viewport().size_changed.disconnect(layout)
	if MobileRuntime.safe_area_changed.is_connected(layout):
		MobileRuntime.safe_area_changed.disconnect(layout)


func set_mode(value: String) -> void:
	mode = value
	drop_button.visible = top.visible and mode == "delivery"
	card.queue_redraw()
	top.queue_redraw()


func set_playing(value: bool) -> void:
	for control in [stick, boost_button, pause_button, top, card, pointer]:
		control.visible = value
	drop_button.visible = value and mode == "delivery"
	stick.enabled = value
	boost_button.set_enabled(value)
	pause_button.disabled = not value
	if not value:
		release_controls()
		toast.hide()
		banner_label.hide()


func release_controls() -> void:
	stick._reset()
	boost_button.reset()
	drop_button.reset()


func set_stats(spark_count: int, total: int, elapsed_ms: int) -> void:
	if spark_count == sparks and total == spark_total and elapsed_ms / 1000 == time_ms / 1000:
		return
	sparks = spark_count
	spark_total = total
	time_ms = elapsed_ms
	top.queue_redraw()


func set_card(
	item: String, recipient: String, address: String, district: String, step: String
) -> void:
	card_item = item
	card_to = recipient
	card_address = address
	card_place = district
	card_step = step
	card.queue_redraw()


func set_info(text: String, current_place: int = 0) -> void:
	if text == info_line and current_place == place:
		return
	info_line = text
	place = current_place
	card.queue_redraw()


func set_goal(
	screen: Vector2,
	on_screen: bool,
	distance: float,
	visible_now: bool,
	colour: Color = Color("ffd75e")
) -> void:
	goal_screen = screen
	goal_on_screen = on_screen
	goal_distance = distance
	goal_visible = visible_now
	goal_colour = colour
	pointer.queue_redraw()


func say(text: String, seconds: float = 2.4) -> void:
	toast.text = text
	toast.visible = not text.is_empty() and top.visible
	_toast_left = seconds
	_place_toast()


func banner(text: String, seconds: float = 2.0) -> void:
	banner_label.text = text
	banner_label.visible = not text.is_empty()
	banner_label.modulate.a = 1.0
	_banner_left = seconds


func show_countdown(text: String) -> void:
	countdown.text = text
	countdown.visible = not text.is_empty()


func _process(delta: float) -> void:
	_pulse += delta
	if goal_visible:
		pointer.queue_redraw()
	if _banner_left > 0.0:
		_banner_left -= delta
		banner_label.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)
		if _banner_left <= 0.0:
			banner_label.hide()
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
	var row: float = 52.0 * u
	pause_button.position = Vector2(m.x, m.y)
	pause_button.size = Vector2(row, row)
	var plain := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_button.add_theme_stylebox_override(state, plain)
	top.position = Vector2(m.x + row + 8.0 * u, m.y)
	top.size = Vector2(view.x - m.x - m.z - row - 8.0 * u, row)
	var card_width: float = minf(view.x - m.x - m.z, 430.0 * u)
	card.size = Vector2(card_width, 92.0 * u)
	card.position = Vector2((view.x - card_width) * 0.5, m.y + row + 8.0 * u)
	pointer.position = Vector2.ZERO
	pointer.size = view
	var controls: float = minf(view.x, view.y) / u
	var stick_side: float = clampf(controls * 0.36, 132.0, 176.0) * u
	var boost_side: float = clampf(controls * 0.30, 112.0, 140.0) * u
	var drop_side: float = clampf(controls * 0.26, 100.0, 124.0) * u
	var bottom: float = view.y - m.w - 8.0 * u
	stick.custom_minimum_size = Vector2.ONE * stick_side
	stick.size = Vector2.ONE * stick_side
	stick.position = Vector2(m.x + 6.0 * u, bottom - stick_side)
	boost_button.size = Vector2.ONE * boost_side
	boost_button.position = Vector2(view.x - m.z - 6.0 * u - boost_side, bottom - boost_side)
	drop_button.size = Vector2.ONE * drop_side
	if view.x / u < 520.0:
		drop_button.position = Vector2(
			view.x - m.z - 6.0 * u - drop_side, boost_button.position.y - drop_side - 14.0 * u
		)
	else:
		drop_button.position = Vector2(
			boost_button.position.x - drop_side - 16.0 * u, bottom - drop_side - 30.0 * u
		)
	toast.add_theme_font_size_override("font_size", roundi(17.0 * u))
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.02, 0.09, 0.22, 0.84)
	pill.set_corner_radius_all(roundi(18.0 * u))
	pill.set_content_margin_all(8.0 * u)
	pill.content_margin_left = 16.0 * u
	pill.content_margin_right = 16.0 * u
	toast.add_theme_stylebox_override("normal", pill)
	_place_toast()
	countdown.add_theme_font_size_override("font_size", roundi(110.0 * u))
	countdown.add_theme_constant_override("outline_size", roundi(16.0 * u))
	countdown.position = Vector2(0, view.y * 0.26)
	countdown.size = Vector2(view.x, 150.0 * u)
	banner_label.add_theme_font_size_override("font_size", roundi(36.0 * u))
	banner_label.add_theme_constant_override("outline_size", roundi(10.0 * u))
	banner_label.position = Vector2(0, view.y * 0.36)
	banner_label.size = Vector2(view.x, 60.0 * u)
	for control in [top, card, pointer, pause_button, stick, boost_button, drop_button]:
		control.queue_redraw()


func _place_toast() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit
	var width: float = minf(view.x - 40.0 * u, 460.0 * u)
	toast.size = Vector2(width, 0)
	toast.custom_minimum_size = Vector2(width, 0)
	toast.reset_size()
	var controls_top: float = minf(
		stick.position.y, drop_button.position.y if drop_button.visible else boost_button.position.y
	)
	toast.position = Vector2((view.x - width) * 0.5, controls_top - toast.size.y - 14.0 * u)


# ------------------------------------------------------------------ drawing


func _draw_pause() -> void:
	var s: Vector2 = pause_button.size
	var u: float = _unit
	var style := UI.panel(UI.CYAN, u, 0.86)
	pause_button.draw_style_box(style, Rect2(Vector2.ZERO, s))
	var bar := Vector2(7.0 * u, s.y * 0.38)
	pause_button.draw_rect(Rect2(s * 0.5 - Vector2(bar.x * 1.6, bar.y * 0.5), bar), UI.WHITE)
	pause_button.draw_rect(Rect2(s * 0.5 + Vector2(bar.x * 0.6, -bar.y * 0.5), bar), UI.WHITE)


func _draw_top() -> void:
	var u: float = _unit
	var s: Vector2 = top.size
	top.draw_style_box(UI.panel(UI.CYAN, u, 0.82), Rect2(Vector2.ZERO, s))
	var font: Font = UI.UI.HEADING
	var size: int = roundi(20.0 * u)
	var star_centre := Vector2(26.0 * u, s.y * 0.5)
	top.draw_colored_polygon(UI.star_points(star_centre, 13.0 * u), UI.GOLD)
	var counter: String = "%d / %d" % [sparks, spark_total] if spark_total > 0 else str(sparks)
	top.draw_string(
		font,
		Vector2(46.0 * u, s.y * 0.5 + size * 0.36),
		counter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		UI.WHITE
	)
	var clock: String = UI.clock(time_ms)
	var clock_width: float = font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	top.draw_string(
		font,
		Vector2(s.x - clock_width - 16.0 * u, s.y * 0.5 + size * 0.36),
		clock,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		UI.MUTED
	)


func _draw_card() -> void:
	var u: float = _unit
	var s: Vector2 = card.size
	var heading: Font = UI.UI.HEADING
	var body: Font = UI.UI.BODY
	if mode == "delivery":
		if card_address.is_empty():
			return
		card.draw_style_box(UI.panel(UI.GOLD, u, 0.9), Rect2(Vector2.ZERO, s))
		# Envelope or parcel icon.
		var icon := Rect2(Vector2(14.0 * u, 18.0 * u), Vector2(56.0, 40.0) * u)
		if card_item == "Paket":
			card.draw_rect(icon, Color("c89458"))
			card.draw_rect(
				Rect2(
					icon.position + Vector2(icon.size.x * 0.44, 0),
					Vector2(icon.size.x * 0.12, icon.size.y)
				),
				Color("d9443b")
			)
		else:
			card.draw_rect(icon, Color("fbf6e8"))
			card.draw_polyline(
				PackedVector2Array(
					[
						icon.position,
						icon.position + Vector2(icon.size.x * 0.5, icon.size.y * 0.55),
						icon.position + Vector2(icon.size.x, 0)
					]
				),
				Color("8a6a4a"),
				2.0 * u,
				true
			)
			card.draw_circle(
				icon.position + icon.size * Vector2(0.5, 0.62), 6.0 * u, Color("d9443b")
			)
		if not card_step.is_empty():
			card.draw_string(
				body,
				Vector2(14.0 * u, s.y - 12.0 * u),
				card_step,
				HORIZONTAL_ALIGNMENT_LEFT,
				64.0 * u,
				roundi(13.0 * u),
				UI.MUTED
			)
		var x: float = 84.0 * u
		var width: float = s.x - x - 12.0 * u
		card.draw_string(
			body,
			Vector2(x, 26.0 * u),
			"%s für %s" % [card_item, card_to],
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			roundi(15.0 * u),
			UI.MUTED
		)
		var size: int = roundi(26.0 * u)
		while (
			size > 14
			and heading.get_string_size(card_address, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width
		):
			size -= 1
		card.draw_string(
			heading,
			Vector2(x, 58.0 * u),
			card_address,
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			size,
			UI.GOLD
		)
		card.draw_string(
			body,
			Vector2(x, 82.0 * u),
			card_place,
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			roundi(15.0 * u),
			UI.WHITE
		)
	elif not info_line.is_empty():
		var h: float = 52.0 * u
		var rect := Rect2(Vector2(0, 0), Vector2(s.x, h))
		card.draw_style_box(UI.panel(UI.CYAN, u, 0.86), rect)
		var x: float = 16.0 * u
		if place > 0:
			var badge := Rect2(Vector2(8.0 * u, 6.0 * u), Vector2(h - 12.0 * u, h - 12.0 * u))
			var colours: Array[Color] = [
				Color("ffd75e"), Color("dfe8f2"), Color("e0a06a"), Color("8fa6c4")
			]
			card.draw_circle(
				badge.get_center(), badge.size.x * 0.5, colours[clampi(place - 1, 0, 3)]
			)
			var text: String = str(place)
			var size: int = roundi(24.0 * u)
			var w: float = heading.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			card.draw_string(
				heading,
				badge.get_center() + Vector2(-w * 0.5, size * 0.36),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				size,
				UI.INK
			)
			x = badge.end.x + 12.0 * u
		card.draw_string(
			heading,
			Vector2(x, h * 0.5 + 7.0 * u),
			info_line,
			HORIZONTAL_ALIGNMENT_LEFT,
			s.x - x - 12.0 * u,
			roundi(19.0 * u),
			UI.WHITE
		)


func _draw_pointer() -> void:
	if not goal_visible:
		return
	var u: float = _unit
	var view: Vector2 = pointer.size
	var heading: Font = UI.UI.HEADING
	var label: String = "%d m" % roundi(goal_distance)
	var size: int = roundi(16.0 * u)
	var pulse: float = 1.0 + 0.08 * sin(_pulse * 5.0)
	if goal_on_screen:
		var p: Vector2 = goal_screen
		var r: float = 22.0 * u * pulse
		pointer.draw_arc(p, r, 0.0, TAU, 40, goal_colour, 4.0 * u, true)
		pointer.draw_arc(p, r * 0.55, 0.0, TAU, 32, Color(goal_colour, 0.6), 3.0 * u, true)
		var w: float = heading.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pointer.draw_string(
			heading,
			p + Vector2(-w * 0.5, r + size * 1.2),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			size,
			UI.WHITE
		)
		return
	# Off screen: an arrow at the edge of a safe ellipse pointing to the goal.
	var centre: Vector2 = view * Vector2(0.5, 0.45)
	var direction: Vector2 = (goal_screen - centre).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var reach := Vector2(view.x * 0.38, view.y * 0.3)
	var p: Vector2 = centre + direction * reach
	var side := Vector2(-direction.y, direction.x)
	var length: float = 30.0 * u * pulse
	var tip: Vector2 = p + direction * length * 0.6
	var points := PackedVector2Array(
		[
			tip,
			p - direction * length * 0.4 + side * length * 0.55,
			p - direction * length * 0.15,
			p - direction * length * 0.4 - side * length * 0.55
		]
	)
	pointer.draw_colored_polygon(points, goal_colour)
	pointer.draw_polyline(points + PackedVector2Array([tip]), UI.INK, 2.5 * u, true)
	var w2: float = heading.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	pointer.draw_string(
		heading,
		p - direction * length * 1.1 + Vector2(-w2 * 0.5, size * 0.4),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		UI.WHITE
	)
