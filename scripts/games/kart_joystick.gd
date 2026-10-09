extends Control
## Analogue touch stick: owns one finger, leaving the other free for actions.

const BASE = preload("res://assets/kart/controls/reference/stick_basis.png")
const KNOB = preload("res://assets/kart/controls/reference/stick_knopf_normal.png")
const KNOB_PRESSED = preload("res://assets/kart/controls/reference/stick_knopf_pressed.png")
## Source: 1024 px base, 512 px knob; physical diameter ratio = 0.4.
const KNOB_CANVAS_RATIO: float = 0.5
const KNOB_TRAVEL_RATIO: float = 128.0 / 1024.0

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
	queue_redraw()


func _reset() -> void:
	touch_id = -1
	mouse_active = false
	target = Vector2.ZERO
	axis_changed.emit(target)
	queue_redraw()


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_reset()
	queue_redraw()


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
	var side: float = minf(size.x, size.y)
	var tint: Color = Color.WHITE if enabled else Color(0.68, 0.74, 0.84, 0.82)
	draw_texture_rect(BASE, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, tint)
	var knob_size: float = side * KNOB_CANVAS_RATIO
	var knob_center: Vector2 = center + axis * side * KNOB_TRAVEL_RATIO
	var texture: Texture2D = KNOB_PRESSED if touch_id >= 0 or mouse_active else KNOB
	draw_texture_rect(texture, Rect2(knob_center - Vector2.ONE * knob_size * 0.5, Vector2.ONE * knob_size), false, tint)
