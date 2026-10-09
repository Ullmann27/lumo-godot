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
const ART: Dictionary = {
	"drift": [preload("res://assets/kart/controls/reference/drift_normal.png"), preload("res://assets/kart/controls/reference/drift_pressed.png"), preload("res://assets/kart/controls/reference/drift_disabled.png")],
	"gas": [preload("res://assets/kart/controls/reference/gas_normal.png"), preload("res://assets/kart/controls/reference/gas_pressed.png"), preload("res://assets/kart/controls/reference/gas_disabled.png")],
	"brake": [preload("res://assets/kart/controls/reference/bremse_normal.png"), preload("res://assets/kart/controls/reference/bremse_pressed.png"), preload("res://assets/kart/controls/reference/bremse_disabled.png")],
	"boost": [preload("res://assets/kart/controls/reference/speed_normal.png"), preload("res://assets/kart/controls/reference/speed_pressed.png"), preload("res://assets/kart/controls/reference/speed_disabled.png")],
	"item": [preload("res://assets/kart/controls/reference/item_normal.png"), preload("res://assets/kart/controls/reference/item_pressed.png"), preload("res://assets/kart/controls/reference/item_disabled.png")],
}
const LABEL_FONT = preload("res://assets/fonts/Nunito-Black.ttf")
## Was im Item-Knopf liegt, zeigt ein kleines Abzeichen (Schild, Impuls oder Wind).
const ITEM_BADGES: Dictionary = {
	"shield": preload("res://assets/kart/hud/icon_shield.png"),
	"pulse": preload("res://assets/kart/hud/icon_pulse.png"),
	"boost": preload("res://assets/kart/hud/icon_wind.png"),
}
var item_kind: String = "":
	set(value):
		if item_kind == value:
			return
		item_kind = value
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
	label.add_theme_font_override("font", LABEL_FONT)
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
	label.position = Vector2(0, side * 0.69)
	label.size = Vector2(size.x, side * 0.21)
	# The label and artwork grow with the actual button, also on dense Fold screens.
	var ratio: float = 0.125 if label.text.length() > 5 else 0.155
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
	if ART.has(icon_id):
		var state: int = 2 if disabled else (1 if held else 0)
		var texture: Texture2D = ART[icon_id][state]
		# Source face = 400/512 px; preserve the original generous visible button.
		var extent: float = side * 1.12
		draw_texture_rect(texture, Rect2((size - Vector2.ONE * extent) * 0.5, Vector2.ONE * extent), false)
		if is_instance_valid(badge) and badge.visible:
			draw_circle(Vector2(side * 0.865, side * 0.145), side * 0.125, Color("113657"))
			var tint: Color = Color("9bb6d6") if disabled else Color("72e6ff")
			draw_arc(Vector2(side * 0.865, side * 0.145), side * 0.125, 0, TAU, 32, tint, side * 0.015, true)
		if ITEM_BADGES.has(item_kind):
			var middle := Vector2(side * 0.84, side * 0.17)
			var radius: float = side * 0.17
			draw_circle(middle, radius, Color("0d2440"))
			draw_arc(middle, radius, 0, TAU, 40, Color("9bb6d6") if disabled else Color("72e6ff"), side * 0.018, true)
			draw_texture_rect(ITEM_BADGES[item_kind], Rect2(middle - Vector2.ONE * radius * 0.95, Vector2.ONE * radius * 1.9), false)
		return
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
