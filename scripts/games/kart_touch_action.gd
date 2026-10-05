extends Control
## Independent right-thumb action, including simultaneous multi-touch.

signal pressed
signal button_down
signal button_up
var text: String = "BOOST":
	set(value):
		text = value
		if is_instance_valid(label):
			label.text = text
var disabled: bool = false:
	set(value):
		if value and not disabled:
			_release()
		disabled = value
		queue_redraw()
var accent := Color("65f6e8")
var held: bool = false
var touch_id: int = -1
var label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", accent.lightened(0.35))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_press()
		elif not event.pressed and event.index == touch_id:
			_release()
		accept_event()
	elif event is InputEventMouseButton and event.device != -1:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press()
			else:
				_release()
			accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		_release()
	elif event is InputEventMouseButton and not event.pressed and event.device != -1:
		_release()


func _press() -> void:
	if held:
		return
	held = true
	button_down.emit()
	pressed.emit()
	queue_redraw()


func _release() -> void:
	if held:
		held = false
		button_up.emit()
	touch_id = -1
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 8
	var tint: Color = Color("657485") if disabled else accent
	draw_circle(center + Vector2(0, 4), radius + 3, Color(0.01, 0.04, 0.09, 0.35))
	draw_circle(center, radius, Color("294763") if held else Color("14283c"))
	for i in range(4):
		draw_arc(center, radius + i * 2, 0, TAU, 72, Color(tint, 0.12), 2, true)
	draw_arc(center, radius, 0, TAU, 72, tint, 3, true)
	draw_arc(center, radius - 6, PI * 1.1, PI * 1.9, 32, Color(tint, 0.5), 2, true)
