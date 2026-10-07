extends Control
## Analogue touch stick: owns one finger, leaving the other free for actions.

const FOX_EMBLEM = preload("res://assets/kart/controls/steering.svg")

signal axis_changed(value: Vector2)
var axis := Vector2.ZERO
var target := Vector2.ZERO
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(188, 188)
	tooltip_text = "Lenken: Stick nach links oder rechts ziehen."


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
	var next: Vector2 = axis.lerp(target, minf(1.0, delta * 18))
	if next.distance_squared_to(axis) > 0.000001:
		axis = next
		queue_redraw()
	elif axis != target:
		axis = target
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
	var knob_radius: float = radius * 0.40
	var knob: Vector2 = center + axis * radius * 0.56
	draw_line(center, knob, Color(cyan, 0.17), radius * 0.30, true)
	draw_circle(knob + Vector2(0, knob_radius * 0.12), knob_radius * 1.08, Color(0.005, 0.02, 0.07, 0.65))
	draw_circle(knob, knob_radius, Color("264b76"))
	draw_arc(knob, knob_radius, 0, TAU, 64, cyan, maxf(2.0, radius * 0.035), true)
	draw_arc(knob, knob_radius * 0.86, PI * 1.1, PI * 1.9, 30, violet, maxf(2.0, radius * 0.035), true)
	var emblem_size: float = knob_radius * 1.72
	draw_texture_rect(FOX_EMBLEM, Rect2(knob - Vector2.ONE * emblem_size * 0.5, Vector2.ONE * emblem_size), false)
