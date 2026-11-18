extends Control
## Independent right-thumb action, including simultaneous multi-touch.
##
## Two looks: the classic flat artwork (skin "") for older games, and the Blender-rendered
## glass buttons of Lumo Kart (skin "kart3d", tools/art/render_kart_controls.py) with live
## feedback: press spring + light ring, gas load ring, brake glow, drift tier ring, turbo
## stock and ready glow, calm item pulse. Nothing flashes faster than 1 Hz; with
## reduced_motion every cue is steady.

const ICONS: Dictionary = {
	"gas": preload("res://assets/kart/controls/gas.svg"),
	"boost": preload("res://assets/kart/controls/boost.svg"),
	"drift": preload("res://assets/kart/controls/drift.svg"),
	"brake": preload("res://assets/kart/controls/brake.svg"),
	"item": preload("res://assets/kart/controls/item.svg"),
}
var icon_id: String = "boost":
	set(value):
		icon_id = value
		_sync_caption()
		queue_redraw()
const ART: Dictionary = {
	"drift": [preload("res://assets/kart/controls/reference/drift_normal.png"), preload("res://assets/kart/controls/reference/drift_pressed.png"), preload("res://assets/kart/controls/reference/drift_disabled.png")],
	"gas": [preload("res://assets/kart/controls/reference/gas_normal.png"), preload("res://assets/kart/controls/reference/gas_pressed.png"), preload("res://assets/kart/controls/reference/gas_disabled.png")],
	"brake": [preload("res://assets/kart/controls/reference/bremse_normal.png"), preload("res://assets/kart/controls/reference/bremse_pressed.png"), preload("res://assets/kart/controls/reference/bremse_disabled.png")],
	"boost": [preload("res://assets/kart/controls/reference/speed_normal.png"), preload("res://assets/kart/controls/reference/speed_pressed.png"), preload("res://assets/kart/controls/reference/speed_disabled.png")],
	"item": [preload("res://assets/kart/controls/reference/item_normal.png"), preload("res://assets/kart/controls/reference/item_pressed.png"), preload("res://assets/kart/controls/reference/item_disabled.png")],
}
const RENDERED_DIR := "res://assets/kart/controls/rendered/"
## Every state image of the rendered buttons (see tools/art/render_kart_controls.py).
const RENDERED_STATES: Dictionary = {
	"gas": ["normal", "pressed", "disabled"],
	"brake": ["normal", "pressed", "disabled"],
	"drift": ["normal", "pressed", "disabled"],
	"boost": ["normal", "pressed", "disabled", "ready"],
	"item": ["normal", "pressed", "disabled", "ready", "armed", "armed_pressed", "shield"],
}
## Lead colour per rendered button (rings, glow, light ring).
const LEAD: Dictionary = {
	"gas": Color("1ff5c0"), "brake": Color("ff5a2a"), "drift": Color("2f8bff"),
	"boost": Color("ffb71a"), "item": Color("a161ff"),
}
## Drift charge ring: blue -> orange -> purple (the same tiers as the drift sparks).
const DRIFT_COLOURS: Array[Color] = [Color("3aa8ff"), Color("ff9a1f"), Color("c45cff")]
const LABEL_FONT = preload("res://assets/fonts/Nunito-Black.ttf")
## Was im Item-Knopf liegt, zeigt ein kleines Abzeichen (Schild, Impuls oder Wind).
const ITEM_BADGES: Dictionary = {
	"shield": preload("res://assets/kart/hud/icon_shield.png"),
	"pulse": preload("res://assets/kart/hud/icon_pulse.png"),
	"boost": preload("res://assets/kart/hud/icon_wind.png"),
}
static var _rendered_cache: Dictionary = {}

## "" = classic artwork, "kart3d" = rendered glass buttons with live rings.
var skin: String = "":
	set(value):
		skin = value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if value == "kart3d" else CanvasItem.TEXTURE_FILTER_PARENT_NODE
		set_process(value == "kart3d")
		_sync_caption()
		queue_redraw()
## Live value of the button, 0..1: gas = speed share, drift = charge share of the top tier,
## boost = active turbo time left. Fed every frame by the race HUD.
var meter: float = 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if absf(value - meter) < 0.004:
			return
		meter = value
		queue_redraw()
## Drift tier -1..2 (blue, orange, purple), set together with meter.
var tier: int = -1:
	set(value):
		if tier == value:
			return
		tier = value
		queue_redraw()
## Turbo stock (boost button) - shown as pips under the badge.
var stock: int = 0:
	set(value):
		if stock == value:
			return
		stock = value
		queue_redraw()
var reduced_motion: bool = false
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
## Expanding light ring after a press, 1 -> 0.
var flash: float = 0.0
## Smoothed hold glow (brake glows while held), 0..1.
var hold_glow: float = 0.0
var _clock: float = 0.0

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
	set_process(skin == "kart3d")
	_sync_caption()
	_apply_label_size()


static func rendered_texture(id: String, state: String) -> Texture2D:
	var key: String = id + "_" + state
	if not _rendered_cache.has(key):
		var path: String = RENDERED_DIR + key + ".webp"
		_rendered_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _rendered_cache[key]


func _sync_caption() -> void:
	if not is_instance_valid(label):
		return
	var parts: PackedStringArray = text.split("\n")
	label.text = parts[0]
	# Keep the action name readable on a bright track even when no item is
	# available. The muted panel and artwork already communicate disabled state.
	label.add_theme_color_override("font_color", Color("dce8f8") if disabled else Color("f6fcff"))
	if skin == "kart3d":
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12, 0.85))
	tooltip_text = {"gas": "Gas halten", "brake": "Bremsen / rückwärts fahren",
		"drift": "Drift halten", "boost": "Raketen-Boost", "item": "Item einsetzen"}.get(icon_id, text)
	badge.text = parts[1].replace("◆", "").strip_edges() if parts.size() > 1 and icon_id == "boost" else ""
	badge.visible = not badge.text.is_empty()
	if skin == "kart3d":
		badge.add_theme_font_override("font", LABEL_FONT)
		badge.add_theme_color_override("font_color", Color("fff6d6"))
	_apply_label_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_label_size()
		queue_redraw()


func _apply_label_size() -> void:
	if not is_instance_valid(label):
		return
	var side: float = minf(size.x, size.y)
	if skin == "kart3d":
		# The caption sits on the lower glass of the rendered face, under the symbol.
		label.position = Vector2(0, side * 0.735)
		label.size = Vector2(size.x, side * 0.15)
		var ratio_3d: float = 0.118 if label.text.length() > 5 else 0.142
		var font_size: int = maxi(10, roundi(side * ratio_3d))
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", maxi(2, roundi(font_size * 0.22)))
		# A tiny caption is noise: under ~62 px the symbol alone carries the meaning.
		label.visible = _side_dp(side) >= 60.0
		badge.position = Vector2(side * 0.765, -side * 0.035)
		badge.size = Vector2.ONE * side * 0.26
		badge.add_theme_font_size_override("font_size", maxi(10, roundi(side * 0.17)))
		return
	label.visible = true
	label.position = Vector2(0, side * 0.69)
	label.size = Vector2(size.x, side * 0.21)
	# The label and artwork grow with the actual button, also on dense Fold screens.
	var ratio: float = 0.125 if label.text.length() > 5 else 0.155
	label.add_theme_font_size_override("font_size", maxi(10, roundi(side * ratio)))
	badge.position = Vector2(side * 0.74, side * 0.02)
	badge.size = Vector2.ONE * side * 0.25
	badge.add_theme_font_size_override("font_size", maxi(10, roundi(side * 0.18)))


## Button side in device-independent points (the canvas may be stretched).
func _side_dp(side: float) -> float:
	if not is_inside_tree():
		return side
	var screen_scale: float = get_viewport().get_screen_transform().get_scale().x * get_global_transform().get_scale().x
	var density: float = 1.0
	var runtime: Node = get_tree().root.get_node_or_null("MobileRuntime")
	if runtime != null and runtime.has_method("get_ui_density"):
		density = maxf(0.5, float(runtime.get_ui_density()))
	return side * screen_scale / density


func _animate_press(value: float) -> void:
	if is_instance_valid(press_tween):
		press_tween.kill()
	press_tween = create_tween()
	if skin == "kart3d" and value > 0.5 and not reduced_motion:
		# Short spring: dip a little deeper, then settle at the pressed depth.
		press_tween.tween_property(self, "press_depth", 1.18, 0.06).set_trans(Tween.TRANS_QUAD)
		press_tween.tween_property(self, "press_depth", 1.0, 0.09).set_trans(Tween.TRANS_SINE)
		return
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
	flash = 1.0
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


func _process(delta: float) -> void:
	if skin != "kart3d":
		return
	_clock += delta
	var changed: bool = false
	if flash > 0.0:
		flash = maxf(0.0, flash - delta / 0.38)
		changed = true
	var glow_goal: float = 1.0 if held and not disabled else 0.0
	if not is_equal_approx(hold_glow, glow_goal):
		hold_glow = move_toward(hold_glow, glow_goal, delta / (0.12 if glow_goal > hold_glow else 0.3))
		changed = true
	# Calm breathing for a ready item / turbo (0.6 Hz) and the drift ring; nothing else animates.
	if not reduced_motion and not disabled and (_ready_glow() or (icon_id == "drift" and tier >= 0)):
		changed = true
	if changed:
		queue_redraw()


## Item phase as published by the item slot overlay (kart_item_hud.gd, mode "slot").
func item_phase() -> String:
	var overlay: Node = get_node_or_null("ItemSlotOverlay")
	if overlay == null:
		return ""
	var state: Variant = overlay.get("state")
	if not state is Dictionary:
		return ""
	if float(state.get("shield_left", 0.0)) > 0.0:
		return "shield"
	if float(state.get("roulette", 0.0)) > 0.0:
		return "roulette"
	return str(state.get("phase", ""))


func _ready_glow() -> bool:
	if disabled:
		return false
	if icon_id == "boost":
		return stock > 0
	if icon_id == "item":
		return not item_kind.is_empty() and item_phase() != "roulette"
	return false


## Which rendered image is shown right now (also read by the regression test).
func visual_state() -> String:
	# An active shield shows on the item button even though the slot is empty again.
	if icon_id == "item" and item_phase() == "shield":
		return "shield"
	if disabled:
		return "disabled"
	if icon_id == "item":
		var phase: String = item_phase()
		if phase == "armed":
			return "armed_pressed" if held else "armed"
	if held:
		return "pressed"
	if _ready_glow():
		return "ready"
	return "normal"


func _breath() -> float:
	if reduced_motion:
		return 1.0
	return 0.5 + 0.5 * sin(_clock * TAU * 0.6)


func _draw_panel(rectangle: Rect2, fill: Color, border: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(width)))
	style.set_corner_radius_all(roundi(rectangle.size.x * 0.30))
	draw_style_box(style, rectangle)


func _draw_kart3d(side: float) -> void:
	var centre: Vector2 = size * 0.5
	var lead: Color = LEAD.get(icon_id, accent)
	var state: String = visual_state()
	var texture: Texture2D = rendered_texture(icon_id, state)
	if texture == null:
		texture = rendered_texture(icon_id, "pressed" if held else ("disabled" if disabled else "normal"))
	# Body = 392/512 of the image. The image is 1.12 x the hit square, so the solid
	# body is 0.86 x the touch target and the glow halo reaches just past it.
	var depth: float = clampf(press_depth, 0.0, 1.2)
	var squash: float = 1.0 - 0.07 * depth
	var extent: float = side * 1.12 * squash
	var face_radius: float = side * 0.43
	if not disabled:
		# Brake: a warm glow grows behind the button while it is held.
		var glow: float = hold_glow * (1.0 if icon_id == "brake" else 0.45)
		if icon_id == "gas":
			glow = maxf(glow, meter * 0.55)
		if _ready_glow():
			glow = maxf(glow, 0.22 + 0.22 * _breath())
		if glow > 0.01:
			for k in range(4):
				var grow: float = 1.0 + 0.07 * float(k + 1)
				draw_circle(centre, face_radius * grow, Color(lead, 0.10 * glow * (1.0 - k * 0.2)))
	if texture != null:
		draw_texture_rect(texture, Rect2(centre - Vector2.ONE * extent * 0.5 + Vector2(0, side * 0.02 * depth), Vector2.ONE * extent), false)
	if depth > 0.01 and not disabled:
		# Pressed: the glass lights up from inside.
		var face := StyleBoxFlat.new()
		face.bg_color = Color(lead.lightened(0.6), 0.16 * minf(depth, 1.0))
		face.set_corner_radius_all(roundi(side * 0.12 * squash))
		face.anti_aliasing = true
		var half: float = side * 0.40 * squash
		draw_style_box(face, Rect2(centre + Vector2(-half, -half + side * 0.02 * depth), Vector2.ONE * half * 2.0))
	var ring_radius: float = side * 0.5
	var ring_width: float = maxf(3.0, side * 0.05)
	var start: float = PI * 0.75
	var sweep: float = PI * 1.5
	if not disabled:
		match icon_id:
			"gas":
				# Load ring: how fast Lumo is going, from bottom-left round to bottom-right.
				if meter > 0.01:
					draw_arc(centre, ring_radius, start, start + sweep, 48, Color(0.02, 0.06, 0.12, 0.45), ring_width, true)
					draw_arc(centre, ring_radius, start, start + sweep * meter, 48, lead.lightened(0.25), ring_width * 0.72, true)
			"drift":
				if tier >= -1 and (held or meter > 0.01):
					var colour: Color = DRIFT_COLOURS[clampi(tier, 0, 2)] if tier >= 0 else Color("9fd8ff")
					draw_arc(centre, ring_radius, start, start + sweep, 48, Color(0.02, 0.06, 0.12, 0.55), ring_width, true)
					draw_arc(centre, ring_radius, start, start + sweep * meter, 48, colour, ring_width * 0.72, true)
					# Tier ticks: where blue, orange and purple begin.
					for index in range(3):
						var at: float = start + sweep * [0.296, 0.667, 1.0][index]
						var tick: Vector2 = centre + Vector2.from_angle(at) * ring_radius
						draw_circle(tick, ring_width * 0.62, DRIFT_COLOURS[index] if tier >= index else Color(0.2, 0.28, 0.4, 0.9))
					if tier >= 0 and not reduced_motion:
						draw_arc(centre, ring_radius + ring_width * 0.9, 0, TAU, 56, Color(colour, 0.25 + 0.25 * _breath()), ring_width * 0.45, true)
			"boost":
				if meter > 0.01:
					# Turbo running: the remaining time drains clockwise.
					draw_arc(centre, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * meter, 56, Color("ffe066"), ring_width * 0.72, true)
	if flash > 0.0 and not reduced_motion:
		var t: float = 1.0 - flash
		draw_arc(centre, side * (0.44 + 0.16 * t), 0, TAU, 56, Color(lead.lightened(0.45), flash * 0.85), maxf(2.0, side * 0.04 * flash), true)
	elif held and reduced_motion:
		draw_arc(centre, side * 0.5, 0, TAU, 56, Color(lead.lightened(0.45), 0.7), maxf(2.0, side * 0.025), true)
	if is_instance_valid(badge) and badge.visible:
		var at := Vector2(side * 0.895, side * 0.095)
		draw_circle(at, side * 0.13, Color("2a1400") if not disabled else Color("1a2434"))
		draw_circle(at, side * 0.112, Color("ffb71a") if not disabled else Color("5a6a80"))
		draw_circle(at, side * 0.088, Color("5c2c00") if not disabled else Color("2a3446"))
	if ITEM_BADGES.has(item_kind) and get_node_or_null("ItemSlotOverlay") == null:
		var middle := Vector2(side * 0.84, side * 0.17)
		var radius: float = side * 0.17
		draw_circle(middle, radius, Color("1a0b40"))
		draw_arc(middle, radius, 0, TAU, 40, lead.lightened(0.3), side * 0.018, true)
		draw_texture_rect(ITEM_BADGES[item_kind], Rect2(middle - Vector2.ONE * radius * 0.95, Vector2.ONE * radius * 1.9), false)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if skin == "kart3d" and RENDERED_STATES.has(icon_id):
		_draw_kart3d(side)
		return
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
