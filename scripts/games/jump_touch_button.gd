extends Control
## A jump starts on press, not on release. One captured finger remains distinct
## from the movement stick even after crossing the button's rectangle.
signal hold_changed(value: bool)
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
var held: bool = false
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true
var caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(100, 100)
	tooltip_text = "Tippen: kurzer Sprung. Halten: hoher Sprung."
	caption = Label.new()
	caption.text = "SPRINGEN"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font", FONT)
	caption.add_theme_color_override("font_color", Color("172447"))
	add_child(caption)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if not is_instance_valid(caption):
		return
	caption.add_theme_font_size_override("font_size", maxi(12, int(size.x * 0.115)))
	caption.position = Vector2(0, size.y * 0.65)
	caption.size = Vector2(size.x, size.y * 0.20)
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
	var radius: float = minf(size.x, size.y) * 0.45
	var center: Vector2 = size * 0.5
	var color: Color = Color("f5cc53") if enabled else Color("a6adb6")
	draw_circle(center + Vector2(0, radius * 0.10), radius, Color("102744"))
	draw_circle(center, radius, color.darkened(0.12) if held else color)
	draw_arc(center, radius * 0.95, 0, TAU, 48, Color("fff6d5"), radius * 0.05, true)
	var top: Vector2 = center + Vector2(0, -radius * 0.60)
	var base: Vector2 = center + Vector2(0, radius * 0.08)
	draw_line(base, top, Color("172447"), radius * 0.14, true)
	draw_polyline(
		PackedVector2Array(
			[
				top + Vector2(-radius * 0.28, radius * 0.28),
				top,
				top + Vector2(radius * 0.28, radius * 0.28)
			]
		),
		Color("172447"),
		radius * 0.14,
		true
	)
