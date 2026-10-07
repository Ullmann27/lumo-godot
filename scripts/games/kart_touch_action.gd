extends Control
## Independent right-thumb action, including simultaneous multi-touch.

const ICONS: Dictionary = {
	"gas": preload("res://assets/kart/controls/gas.svg"),
	"boost": preload("res://assets/kart/controls/boost.svg"),
	"drift": preload("res://assets/kart/controls/drift.svg"),
	"brake": preload("res://assets/kart/controls/brake.svg"),
	"item": preload("res://assets/kart/controls/item.svg"),
}
var icon_id: String = "boost"
var press_depth: float = 0.0:
	set(value):
		press_depth = value
		queue_redraw()
var press_tween: Tween
var badge: Label

signal pressed
signal button_down
signal button_up
var text: String = "BOOST":
	set(value):
		if text == value:
			return
		text = value
		_sync_caption()
var disabled: bool = false:
	set(value):
		if disabled == value:
			return
		if value and not disabled:
			_release()
		disabled = value
		_sync_caption()
		queue_redraw()
var accent := Color("65f6e8")
var held: bool = false
var touch_id: int = -1
var label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color("06182d"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	badge = Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_sync_caption()
	_apply_label_size()


func _sync_caption() -> void:
	if not is_instance_valid(label):
		return
	var parts: PackedStringArray = text.split("\n")
	label.text = parts[0]
	# Keep the action name readable on a bright track even when no item is
	# available. The muted panel and artwork already communicate disabled state.
	label.add_theme_color_override("font_color", Color("dce8f8") if disabled else Color("f6fcff"))
	tooltip_text = {"gas": "Gas halten", "brake": "Bremsen / rückwärts fahren",
		"drift": "Drift halten", "boost": "Raketen-Boost", "item": "Item einsetzen"}.get(icon_id, text)
	badge.text = parts[1].replace("◆", "").strip_edges() if parts.size() > 1 and icon_id == "boost" else ""
	badge.visible = not badge.text.is_empty()
	_apply_label_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_label_size()
		queue_redraw()


func _apply_label_size() -> void:
	if not is_instance_valid(label):
		return
	var side: float = minf(size.x, size.y)
	label.position = Vector2(0, side * 0.66)
	label.size = Vector2(size.x, side * 0.25)
	# The label and artwork grow with the actual button, also on dense Fold screens.
	var ratio: float = 0.145 if label.text.length() > 5 else 0.175
	label.add_theme_font_size_override("font_size", maxi(10, roundi(side * ratio)))
	badge.position = Vector2(side * 0.74, side * 0.02)
	badge.size = Vector2.ONE * side * 0.25
	badge.add_theme_font_size_override("font_size", maxi(10, roundi(side * 0.18)))


func _animate_press(value: float) -> void:
	if is_instance_valid(press_tween):
		press_tween.kill()
	press_tween = create_tween()
	press_tween.tween_property(self, "press_depth", value, 0.09).set_trans(Tween.TRANS_QUAD)


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
	if held or disabled:
		return
	held = true
	_animate_press(1.0)
	button_down.emit()
	pressed.emit()
	queue_redraw()


func _release() -> void:
	if held:
		held = false
		if is_inside_tree():
			_animate_press(0.0)
		button_up.emit()
	touch_id = -1
	queue_redraw()


func _draw_panel(rectangle: Rect2, fill: Color, border: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(width)))
	style.set_corner_radius_all(roundi(rectangle.size.x * 0.30))
	draw_style_box(style, rectangle)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var inset: float = side * 0.045
	var shift: float = press_depth * side * 0.045
	var face := Rect2(Vector2(inset, inset + shift), Vector2.ONE * (side - inset * 2.0))
	var tint: Color = Color("67809b") if disabled else accent
	_draw_panel(face.grow(side * 0.035), Color(tint, 0.10), Color(tint, 0.15), side * 0.02)
	_draw_panel(Rect2(face.position + Vector2(0, side * 0.045 - shift), face.size), Color("061326"), Color("08152d"), 2)
	_draw_panel(face, Color("1a385b").lerp(tint, 0.34 if held else 0.15), tint, side * 0.027)
	var highlight := Rect2(face.position + Vector2(side * 0.06, side * 0.035), Vector2(side * 0.70, side * 0.22))
	_draw_panel(highlight, Color(tint, 0.10), Color(tint, 0.0), 0)
	var icon: Texture2D = ICONS.get(icon_id, ICONS["boost"])
	var artwork := Rect2(Vector2(side * 0.18, side * 0.04 + shift), Vector2.ONE * side * 0.64)
	draw_texture_rect(icon, artwork, false, Color(0.60, 0.67, 0.78, 0.82) if disabled else Color.WHITE)
	if is_instance_valid(badge) and badge.visible:
		draw_circle(Vector2(side * 0.865, side * 0.145), side * 0.125, Color("113657"))
		draw_arc(Vector2(side * 0.865, side * 0.145), side * 0.125, 0, TAU, 32, tint, side * 0.015, true)
