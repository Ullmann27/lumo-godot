extends Control
## Resolution-independent wordmark, matched to the supplied 50665 reference.
## Reuses the project's Nunito face; no emoji flags or baked scene background.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const DESIGN_SIZE := Vector2(244, 140)


func _ready() -> void:
	name = "LumoKartWordmark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Lumo Kart. Kleine Schritte, große Ziele."
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if factor <= 0.0:
		return
	var origin := (size - DESIGN_SIZE * factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	# Dark extrusion, warm gold face and a cyan second line, like the original.
	_word("Lumo", 72, 61, Color("ffd449"), Color("bf661b"))
	_flag(Vector2(16, 80), -0.16)
	_flag(Vector2(199, 80), 0.16)
	_word("Kart", 59, 110, Color("64e9ff"), Color("127caf"))
	# The star belongs inside the final o, not beside the word.
	var word_width := UI.HEADING.get_string_size("Lumo", HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	var prefix_width := UI.HEADING.get_string_size("Lum", HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	var o_width := word_width - prefix_width
	_star(Vector2((244 - word_width) * 0.5 + prefix_width + o_width * 0.5, 42), 9.5, Color("123e69"))
	var motto := StyleBoxFlat.new()
	motto.bg_color = Color("103369")
	motto.border_color = Color("2dabcf")
	motto.set_border_width_all(1)
	motto.set_corner_radius_all(5)
	draw_style_box(motto, Rect2(49, 118, 147, 21))
	_small_text("KLEINE SCHRITTE", 126)
	_small_text("GROSSE ZIELE", 135)
	draw_set_transform(Vector2.ZERO)


func _word(value: String, font_size: int, baseline: float, face: Color, extrusion: Color) -> void:
	var width := UI.HEADING.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var position := Vector2((244 - width) * 0.5, baseline)
	draw_string_outline(UI.HEADING, position + Vector2(0, 5), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color("071d43"))
	for depth in range(5, 0, -1):
		draw_string_outline(UI.HEADING, position + Vector2(0, depth), value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, extrusion)
	draw_string_outline(UI.HEADING, position, value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, face.lightened(0.18))
	draw_string(UI.HEADING, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, face)


func _flag(origin: Vector2, tilt: float) -> void:
	var points := PackedVector2Array([
		origin + Vector2(-3, -3), origin + Vector2(36, -3),
		origin + Vector2(36 + tilt * 35, 38), origin + Vector2(tilt * 35 - 3, 38),
	])
	draw_colored_polygon(points, Color("136eab"))
	draw_polyline(points + PackedVector2Array([points[0]]), Color("56dfff"), 2, true)
	for row in range(3):
		for column in range(3):
			var top_left := origin + Vector2(column * 11 + tilt * row * 12, row * 12)
			var square := PackedVector2Array([
				top_left, top_left + Vector2(11, 0),
				top_left + Vector2(11 + tilt * 12, 12), top_left + Vector2(tilt * 12, 12),
			])
			draw_colored_polygon(square, Color("efffff") if (row + column) % 2 == 0 else Color("267ab7"))


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in range(10):
		var angle := -PI * 0.5 + PI * float(point) / 5.0
		var length := radius if point % 2 == 0 else radius * 0.47
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	draw_colored_polygon(points, color)


func _small_text(value: String, baseline: float) -> void:
	var width := UI.BODY.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(UI.BODY, Vector2((244 - width) * 0.5, baseline), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("eafaff"))
