extends Control
## Analogue touch stick: owns one finger, leaving the other free for actions.

const BASE = preload("res://assets/kart/controls/reference/stick_basis.png")
const KNOB = preload("res://assets/kart/controls/reference/stick_knopf_normal.png")
const KNOB_PRESSED = preload("res://assets/kart/controls/reference/stick_knopf_pressed.png")
## Source: 1024 px base, 512 px knob; physical diameter ratio = 0.4.
const KNOB_CANVAS_RATIO: float = 0.5
const KNOB_TRAVEL_RATIO: float = 128.0 / 1024.0
## Lumo Kart look (skin "kart3d"): Blender-rendered base and knob, see
## tools/art/render_kart_controls.py. Base disc = 0.906 of the image, knob = 0.8.
const KART_BASE = "res://assets/kart/controls/rendered/stick_base.webp"
const KART_BASE_DISABLED = "res://assets/kart/controls/rendered/stick_base_disabled.webp"
const KART_KNOB = "res://assets/kart/controls/rendered/stick_knob_normal.webp"
const KART_KNOB_PRESSED = "res://assets/kart/controls/rendered/stick_knob_pressed.webp"
const KART_LEAD := Color("43d8ff")

signal axis_changed(value: Vector2)
var axis := Vector2.ZERO
var target := Vector2.ZERO
var touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true
## "" = classic artwork, "kart3d" = rendered Lumo Kart stick with moving light reflex.
var skin: String = "":
	set(value):
		skin = value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if value == "kart3d" else CanvasItem.TEXTURE_FILTER_PARENT_NODE
		queue_redraw()
var reduced_motion: bool = false
var _kart_textures: Array = []


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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and mouse_active:
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


func _kart_texture(index: int) -> Texture2D:
	if _kart_textures.is_empty():
		for path in [KART_BASE, KART_BASE_DISABLED, KART_KNOB, KART_KNOB_PRESSED]:
			_kart_textures.append(load(path) if ResourceLoader.exists(path) else null)
	return _kart_textures[index]


func is_held() -> bool:
	return touch_id >= 0 or mouse_active


func _draw_kart3d(center: Vector2, side: float) -> void:
	var base: Texture2D = _kart_texture(0 if enabled else 1)
	if base == null:
		return
	draw_texture_rect(base, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
	var held: bool = is_held()
	if enabled and absf(axis.x) > 0.05:
		# The steering side lights up: an arc on the rim in the direction of the turn.
		var side_angle: float = 0.0 if axis.x > 0.0 else PI
		var strength: float = clampf(absf(axis.x), 0.0, 1.0)
		draw_arc(center, side * 0.43, side_angle - 0.62, side_angle + 0.62, 24, Color(KART_LEAD.lightened(0.35), 0.35 + 0.55 * strength), maxf(3.0, side * 0.035), true)
	var knob_size: float = side * KNOB_CANVAS_RATIO * (0.97 if held else 1.0)
	var travel: float = side * 0.19
	var knob_center: Vector2 = center + axis * travel
	if enabled and held:
		draw_circle(knob_center, side * 0.23, Color(KART_LEAD, 0.16))
	var knob: Texture2D = _kart_texture(3 if held and enabled else 2)
	var tint: Color = Color.WHITE if enabled else Color(0.62, 0.68, 0.78, 0.9)
	if knob != null:
		draw_texture_rect(knob, Rect2(knob_center - Vector2.ONE * knob_size * 0.5, Vector2.ONE * knob_size), false, tint)
	if enabled:
		# Light reflex: the knob "tilts" with the thumb, so the highlight slides the other way.
		var reflex: Vector2 = knob_center + Vector2(-0.10, -0.12) * knob_size - axis * knob_size * 0.07
		var radius: float = knob_size * 0.085
		draw_circle(reflex, radius * 1.7, Color(1, 1, 1, 0.10))
		draw_circle(reflex, radius, Color(1, 1, 1, 0.42 if held else 0.3))


func _draw() -> void:
	var center: Vector2 = size * 0.5
	if skin == "kart3d":
		_draw_kart3d(center, minf(size.x, size.y))
		return
	var side: float = minf(size.x, size.y)
	var tint: Color = Color.WHITE if enabled else Color(0.68, 0.74, 0.84, 0.82)
	draw_texture_rect(BASE, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, tint)
	var knob_size: float = side * KNOB_CANVAS_RATIO
	var knob_center: Vector2 = center + axis * side * KNOB_TRAVEL_RATIO
	var texture: Texture2D = KNOB_PRESSED if touch_id >= 0 or mouse_active else KNOB
	draw_texture_rect(texture, Rect2(knob_center - Vector2.ONE * knob_size * 0.5, Vector2.ONE * knob_size), false, tint)
