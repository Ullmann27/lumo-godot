extends Control
## Analogue touch stick: owns one finger, leaving the other free for actions.

## Heinz' Bedienelemente-Blatt: Lenkring mit Pfeilen und runder Lenkknopf. Kern = heller Teil ohne Leuchten.
const RING: Texture2D = preload("res://assets/kart/hud/joystick_ring.png")
const KNOB: Texture2D = preload("res://assets/kart/hud/joystick_knob.png")
const RING_CORE_RATIO: float = 0.8353
const KNOB_CORE_RATIO: float = 0.7381
## Knopf-Kern im Verhältnis zum Ring-Kern und wie weit der Knopf auslenkt (Anteil des Ring-Kernradius).
const KNOB_TO_RING: float = 0.5458
const KNOB_TRAVEL: float = 0.42

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
	var ring_core: float = minf(size.x, size.y) * 0.88
	var ring_extent: float = ring_core / RING_CORE_RATIO
	var fade: Color = Color(1, 1, 1, 1.0) if enabled else Color(0.62, 0.7, 0.82, 0.55)
	draw_texture_rect(RING, Rect2(center - Vector2.ONE * ring_extent * 0.5, Vector2.ONE * ring_extent), false, fade)
	var knob_core: float = ring_core * KNOB_TO_RING
	var knob_extent: float = knob_core / KNOB_CORE_RATIO
	var knob: Vector2 = center + axis * ring_core * 0.5 * KNOB_TRAVEL
	draw_circle(knob + Vector2(0, knob_core * 0.07), knob_core * 0.52, Color(0.0, 0.03, 0.09, 0.38 if enabled else 0.2))
	draw_texture_rect(KNOB, Rect2(knob - Vector2.ONE * knob_extent * 0.5, Vector2.ONE * knob_extent), false, fade)
