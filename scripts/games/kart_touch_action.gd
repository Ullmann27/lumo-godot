extends Control
## Independent right-thumb action, including simultaneous multi-touch.

## Heinz' Bedienelemente-Blatt: gemeinsamer Glasrahmen plus ein Symbol je Aktion. Drift, Schild,
## Impuls und Wind fehlen auf dem Blatt und sind im selben Stil gezeichnet (tools/art/make_hud_icons.py).
const FRAME: Texture2D = preload("res://assets/kart/hud/frame.png")
const ICONS: Dictionary = {
	"gas": preload("res://assets/kart/hud/icon_gas.png"),
	"boost": preload("res://assets/kart/hud/icon_boost.png"),
	"drift": preload("res://assets/kart/hud/icon_drift.png"),
	"brake": preload("res://assets/kart/hud/icon_brake.png"),
	"item": preload("res://assets/kart/hud/icon_item.png"),
	"shield": preload("res://assets/kart/hud/icon_shield.png"),
	"pulse": preload("res://assets/kart/hud/icon_pulse.png"),
	"wind": preload("res://assets/kart/hud/icon_wind.png"),
}
## Symbolmitte und -größe im Rahmen (Anteile der Rahmenbreite), aus dem Blatt vermessen.
const ICON_FIT: Dictionary = {
	"gas": [Vector2(0.489, 0.459), 0.711],
	"brake": [Vector2(0.492, 0.459), 0.720],
	"boost": [Vector2(0.468, 0.462), 0.668],
	"item": [Vector2(0.486, 0.459), 0.705],
	"drift": [Vector2(0.50, 0.46), 0.70],
	"shield": [Vector2(0.50, 0.46), 0.66],
	"pulse": [Vector2(0.50, 0.46), 0.70],
	"wind": [Vector2(0.50, 0.46), 0.68],
}
var icon_id: String = "boost":
	set(value):
		if icon_id == value:
			return
		icon_id = value
		queue_redraw()
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


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var shift: float = press_depth * side * 0.03
	var fade: float = 0.55 if disabled else 1.0
	var frame_height: float = side * float(FRAME.get_height()) / float(FRAME.get_width())
	var frame := Rect2(Vector2((size.x - side) * 0.5, (size.y - frame_height) * 0.5 + shift), Vector2(side, frame_height))
	var tint: Color = Color("67809b") if disabled else accent
	if held:
		draw_circle(frame.get_center(), side * 0.50, Color(tint, 0.20))
	var base := Color(0.62, 0.70, 0.82, fade) if disabled else Color.WHITE
	if held:
		base = Color(1.12, 1.12, 1.12)
	draw_texture_rect(FRAME, frame, false, base)
	var fit: Array = ICON_FIT.get(icon_id, ICON_FIT["boost"])
	var icon: Texture2D = ICONS.get(icon_id, ICONS["boost"])
	var extent: float = float(fit[1]) * side
	var middle: Vector2 = frame.position + Vector2(float(fit[0].x) * frame.size.x, float(fit[0].y) * frame.size.y)
	var icon_tint := Color(0.66, 0.72, 0.82, 0.72) if disabled else Color(1.08, 1.08, 1.08) if held else Color.WHITE
	draw_texture_rect(icon, Rect2(middle - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, icon_tint)
	if is_instance_valid(badge) and badge.visible:
		draw_circle(Vector2(side * 0.865, side * 0.145), side * 0.125, Color("113657"))
		draw_arc(Vector2(side * 0.865, side * 0.145), side * 0.125, 0, TAU, 32, tint, side * 0.015, true)
