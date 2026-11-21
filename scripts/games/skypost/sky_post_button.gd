extends Control
## Round thumb button of the Sternenpost HUD (SCHWUNG, ABWERFEN). Reacts on
## press, owns one finger (the stick keeps the other) and shows a cooldown ring.

signal pressed_now

const FONT = preload("res://assets/fonts/Nunito-Black.ttf")

var kind: String = "boost"
var caption: String = "SCHWUNG"
var held: bool = false
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true
## 0 = ready, 1 = just used.
var cooldown: float = 0.0
## Soft pulse when the button is the thing to press now (drop near the mailbox).
var calling: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(96, 96)
	resized.connect(queue_redraw)


func configure(action: String, text: String, hint: String) -> void:
	kind = action
	caption = text
	tooltip_text = hint
	queue_redraw()


func set_cooldown(value: float) -> void:
	var next: float = clampf(value, 0.0, 1.0)
	if not is_equal_approx(next, cooldown):
		cooldown = next
		queue_redraw()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		reset()
	queue_redraw()


func set_calling(value: bool) -> void:
	if calling != value:
		calling = value
		queue_redraw()


func _process(delta: float) -> void:
	if calling and enabled:
		_pulse += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_id == -1 and not mouse_active:
			touch_id = event.index
			_press()
		elif event.index == touch_id and (not event.pressed or event.canceled):
			reset()
		accept_event()
	elif (
		event is InputEventMouseButton
		and event.device != -1
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		if event.pressed and touch_id == -1:
			mouse_active = true
			_press()
		elif not event.pressed and mouse_active:
			reset()
		accept_event()


func _input(event: InputEvent) -> void:
	if (
		event is InputEventScreenTouch
		and event.index == touch_id
		and (not event.pressed or event.canceled)
	):
		reset()
	elif (
		event is InputEventMouseButton and event.device != -1 and not event.pressed and mouse_active
	):
		reset()


func _press() -> void:
	held = true
	queue_redraw()
	pressed_now.emit()


func reset() -> void:
	touch_id = -1
	mouse_active = false
	if held:
		held = false
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.46
	var centre: Vector2 = size * 0.5
	var face: Color = Color("43c6ff") if kind == "boost" else Color("ffb43a")
	var rim: Color = Color("dff6ff") if kind == "boost" else Color("fff0c4")
	var ink := Color("0b2247")
	if not enabled:
		face = Color("8d97a6")
		rim = Color("c4ccd6")
	if calling and enabled:
		var wave: float = fmod(_pulse, 1.1) / 1.1
		draw_arc(
			centre,
			radius * (1.0 + wave * 0.35),
			0.0,
			TAU,
			56,
			Color(1, 0.9, 0.4, 0.8 * (1.0 - wave)),
			radius * 0.08,
			true
		)
	draw_circle(centre + Vector2(0, radius * 0.10), radius, Color(0.03, 0.09, 0.2, 0.75))
	draw_circle(centre, radius, face.darkened(0.2) if held else face)
	draw_circle(centre - Vector2(0, radius * 0.16), radius * 0.78, Color(1, 1, 1, 0.14))
	draw_arc(centre, radius * 0.95, 0.0, TAU, 56, rim, radius * 0.07, true)
	var stroke: float = radius * 0.12
	if kind == "boost":
		# Three swirling wind strokes.
		for k in range(3):
			var y: float = (float(k) - 1.0) * radius * 0.26 - radius * 0.12
			var points := PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				points.append(
					(
						centre
						+ Vector2(
							(t - 0.5) * radius * (1.1 - float(k) * 0.18),
							y + sin(t * PI * 1.6) * radius * 0.08
						)
					)
				)
			draw_polyline(points, ink, stroke * 0.8, true)
	else:
		# Envelope with an arrow down.
		var w: float = radius * 0.9
		var h: float = radius * 0.56
		var top_left: Vector2 = centre + Vector2(-w * 0.5, -h * 0.85)
		draw_rect(Rect2(top_left, Vector2(w, h)), Color("fffaf0"))
		draw_rect(Rect2(top_left, Vector2(w, h)), ink, false, stroke * 0.5)
		draw_polyline(
			PackedVector2Array(
				[top_left, top_left + Vector2(w * 0.5, h * 0.55), top_left + Vector2(w, 0)]
			),
			ink,
			stroke * 0.5,
			true
		)
		var tip: Vector2 = centre + Vector2(0, radius * 0.42)
		draw_line(centre + Vector2(0, -radius * 0.05), tip, ink, stroke, true)
		draw_polyline(
			PackedVector2Array(
				[
					tip + Vector2(-radius * 0.18, -radius * 0.18),
					tip,
					tip + Vector2(radius * 0.18, -radius * 0.18)
				]
			),
			ink,
			stroke,
			true
		)
	if cooldown > 0.0:
		draw_circle(centre, radius, Color(0.03, 0.07, 0.16, 0.5))
		draw_arc(
			centre,
			radius * 0.95,
			-PI * 0.5,
			-PI * 0.5 + TAU * (1.0 - cooldown),
			56,
			Color.WHITE,
			radius * 0.09,
			true
		)
	var font_size: int = maxi(11, int(radius * 0.25))
	var text_size: Vector2 = FONT.get_string_size(
		caption, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
	)
	draw_string(
		FONT,
		Vector2(centre.x - text_size.x * 0.5, centre.y + radius * 0.8),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ink
	)
