extends Control
## Small, calm speed hint shown on the run-up to the Sonnenhafen precision jump.
## Red = too slow ("Gib Gas!"), green = fits ("Tempo passt!"),
## orange = too fast ("Etwas bremsen!"). A needle shows where the kart would
## land at its current speed; the green band is the real landing zone.
## Pure display: it never changes speed or flight.

const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const BASE_SIZE := Vector2(330.0, 66.0)

var status: String = PRECISION.STATUS_GOOD
var predicted: float = 0.0
var zone_min: float = 1.0
var zone_max: float = 2.0
var text: String = ""


func _init() -> void:
	name = "JumpSpeedHint"
	custom_minimum_size = BASE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_for(speed: float, kicker: Dictionary) -> void:
	var result: Dictionary = PRECISION.prediction(speed, kicker)
	var changed: bool = not visible or str(result.status) != status or absf(float(result.predicted_distance) - predicted) > 0.05
	status = str(result.status)
	predicted = float(result.predicted_distance)
	zone_min = float(kicker.landing_min)
	zone_max = float(kicker.landing_max)
	text = str(PRECISION.hint(status).text)
	visible = true
	if changed:
		queue_redraw()


func hide_hint() -> void:
	visible = false


func _draw() -> void:
	var k: float = size.y / BASE_SIZE.y
	var rect := Rect2(Vector2.ZERO, size)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.085, 0.16, 0.74)
	panel.set_corner_radius_all(roundi(16.0 * k))
	var accent: Color = PRECISION.hint(status).color
	panel.border_color = Color(accent, 0.9)
	panel.set_border_width_all(maxi(1, roundi(2.0 * k)))
	draw_style_box(panel, rect)
	# Text left, meter right.
	var font: Font = get_theme_default_font()
	var font_size: int = roundi(22.0 * k)
	var dot_center := Vector2(22.0 * k, size.y * 0.5)
	draw_circle(dot_center, 8.0 * k, accent)
	draw_string(font, Vector2(38.0 * k, size.y * 0.5 + font_size * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, 170.0 * k, font_size, Color("f4f8ff"))
	var bar := Rect2(Vector2(196.0 * k, size.y * 0.5 - 7.0 * k), Vector2(118.0 * k, 14.0 * k))
	var scale_max: float = zone_max * 1.35
	var x_min: float = bar.position.x + bar.size.x * clampf(zone_min / scale_max, 0.0, 1.0)
	var x_max: float = bar.position.x + bar.size.x * clampf(zone_max / scale_max, 0.0, 1.0)
	var slow: Color = PRECISION.hint(PRECISION.STATUS_SLOW).color
	var good: Color = PRECISION.hint(PRECISION.STATUS_GOOD).color
	var fast: Color = PRECISION.hint(PRECISION.STATUS_FAST).color
	var dim: float = 0.55
	draw_rect(Rect2(bar.position, Vector2(x_min - bar.position.x, bar.size.y)),
		Color(slow, 1.0 if status == PRECISION.STATUS_SLOW else dim))
	draw_rect(Rect2(Vector2(x_min, bar.position.y), Vector2(x_max - x_min, bar.size.y)),
		Color(good, 1.0 if status == PRECISION.STATUS_GOOD else dim))
	draw_rect(Rect2(Vector2(x_max, bar.position.y), Vector2(bar.end.x - x_max, bar.size.y)),
		Color(fast, 1.0 if status == PRECISION.STATUS_FAST else dim))
	var needle_x: float = bar.position.x + bar.size.x * clampf(predicted / scale_max, 0.0, 1.0)
	var tip := Vector2(needle_x, bar.position.y - 2.0 * k)
	draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-7.0 * k, -11.0 * k), tip + Vector2(7.0 * k, -11.0 * k)
	]), Color("f4f8ff"))
	draw_line(Vector2(needle_x, bar.position.y), Vector2(needle_x, bar.end.y), Color("f4f8ff"), maxf(2.0, 3.0 * k))
