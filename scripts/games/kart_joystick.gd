extends Control
## Analogue touch stick: owns one finger, leaving the other free for actions.

signal axis_changed(value: Vector2)
var axis := Vector2.ZERO
var target := Vector2.ZERO
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(188, 188)
	tooltip_text = "Lenken: Stick links oder rechts. Nach unten: langsamer fahren."


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_move(event.position)
		elif not event.pressed and event.index == touch_id:
			_reset()
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_active = event.pressed
		if event.pressed:
			_move(event.position)
		else:
			_reset()
		accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_move(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# A captured finger still releases the stick when it leaves its rectangle.
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		_reset()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_move(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventMouseButton and not event.pressed and mouse_active:
		_reset()


func _move(at: Vector2) -> void:
	var raw: Vector2 = (at - size * 0.5) / (size.x * 0.31)
	target = raw.limit_length(1.0)
	if target.length() < 0.08:
		target = Vector2.ZERO
	axis_changed.emit(target)


func _reset() -> void:
	touch_id = -1
	mouse_active = false
	target = Vector2.ZERO
	axis_changed.emit(target)


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_reset()


func _process(delta: float) -> void:
	axis = axis.lerp(target, minf(1.0, delta * 18))
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.43
	var cyan := Color("5ef8ed")
	var violet := Color("bb8bff")
	draw_circle(center + Vector2(0, 6), radius + 5, Color(0.015, 0.03, 0.07, 0.3))
	draw_circle(center, radius, Color(0.035, 0.08, 0.16, 0.88))
	for i in range(4):
		draw_arc(center, radius + i * 2, 0, TAU, 72, Color(cyan, 0.12 - i * 0.025), 3, true)
	draw_arc(center, radius, 0, TAU, 72, Color(cyan, 0.8), 2, true)
	draw_arc(center, radius - 12, PI * 1.08, PI * 1.92, 32, violet, 3, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var marker: Vector2 = center + direction * (radius - 10)
		draw_line(marker - direction * 5, marker + direction * 1, Color(cyan, 0.7), 3, true)
	var knob: Vector2 = center + axis * radius * 0.72
	draw_line(center, knob, Color(cyan, 0.15), 18, true)
	draw_circle(knob + Vector2(0, 5), 34, Color(0.005, 0.02, 0.07, 0.6))
	draw_circle(knob, 32, Color("263753"))
	draw_arc(knob, 32, 0, TAU, 64, cyan, 3, true)
	draw_arc(knob, 28, PI * 1.1, PI * 1.9, 30, violet, 4, true)
	draw_circle(knob - Vector2(5, 7), 19, Color(0.35, 0.52, 0.72, 0.22))
	draw_circle(knob, 5, Color("dcffff"))
