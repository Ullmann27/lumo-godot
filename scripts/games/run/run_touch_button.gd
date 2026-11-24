extends Control
## Round action button for the right thumb. It reacts on press (not on release),
## owns one finger so the steering stick keeps the other, and can show a cooldown.

signal hold_changed(value: bool)

const FONT = preload("res://assets/fonts/Nunito-Black.ttf")

var kind: String = "jump"
var caption: String = "SPRINGEN"
var held: bool = false
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true
## 0 = ready, 1 = just used.
var cooldown: float = 0.0


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


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_id == -1 and not mouse_active:
			touch_id = event.index
			_set_held(true)
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
			_set_held(true)
		elif not event.pressed and mouse_active:
			reset()
		accept_event()


func _input(event: InputEvent) -> void:
	# A captured finger still releases the button after sliding off it.
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


func _set_held(value: bool) -> void:
	if held == value:
		return
	held = value
	hold_changed.emit(value)
	queue_redraw()


func reset() -> void:
	touch_id = -1
	mouse_active = false
	_set_held(false)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		reset()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.46
	var centre: Vector2 = size * 0.5
	var face: Color = Color("3fa9ff") if kind == "jump" else Color("ff9f2e")
	var rim: Color = Color("d6f1ff") if kind == "jump" else Color("ffe9b8")
	var ink: Color = Color("0b2247")
	if not enabled:
		face = Color("8d97a6")
		rim = Color("c4ccd6")
	draw_circle(centre + Vector2(0, radius * 0.10), radius, Color(0.03, 0.09, 0.2, 0.75))
	draw_circle(centre, radius, face.darkened(0.2) if held else face)
	draw_circle(centre - Vector2(0, radius * 0.16), radius * 0.78, Color(1, 1, 1, 0.12))
	draw_arc(centre, radius * 0.95, 0.0, TAU, 56, rim, radius * 0.07, true)
	var stroke: float = radius * 0.15
	if kind == "jump":
		var top: Vector2 = centre + Vector2(0, -radius * 0.52)
		draw_line(centre + Vector2(0, radius * 0.12), top, ink, stroke, true)
		draw_polyline(
			PackedVector2Array(
				[top + Vector2(-radius * 0.3, radius * 0.3), top, top + Vector2(radius * 0.3, radius * 0.3)]
			),
			ink, stroke, true
		)
	else:
		for shift in [-0.2, 0.2]:
			var tip: Vector2 = centre + Vector2(radius * (float(shift) + 0.22), -radius * 0.2)
			draw_polyline(
				PackedVector2Array(
					[tip + Vector2(-radius * 0.3, -radius * 0.3), tip, tip + Vector2(-radius * 0.3, radius * 0.3)]
				),
				ink, stroke, true
			)
	if cooldown > 0.0:
		draw_circle(centre, radius, Color(0.03, 0.07, 0.16, 0.5))
		draw_arc(
			centre, radius * 0.95, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cooldown), 56,
			Color("ffffff"), radius * 0.09, true
		)
	var font_size: int = maxi(11, int(radius * 0.27))
	var text_size: Vector2 = FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(
		FONT, Vector2(centre.x - text_size.x * 0.5, centre.y + radius * 0.62), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink
	)
