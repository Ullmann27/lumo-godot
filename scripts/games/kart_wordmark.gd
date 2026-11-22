extends Control
## Two swept racing lines lead into the lettering. Drawn at native viewport resolution.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const DESIGN_SIZE := Vector2(328, 76)


func _ready() -> void:
	name = "LumoKartWordmark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Lumo Kart"
	resized.connect(queue_redraw)


func _draw() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if factor <= 0.0:
		return
	var origin := (size - DESIGN_SIZE * factor) * 0.5
	var basis := Transform2D(Vector2(factor, 0), Vector2(-0.13 * factor, factor), origin)
	draw_set_transform_matrix(basis)
	for i in 2:
		var start := Vector2(11 + i * 14, 51)
		draw_colored_polygon(PackedVector2Array([
			start, start + Vector2(8, 0), start + Vector2(25, -30), start + Vector2(15, -30)
		]), Color("57e1cb") if i == 0 else Color("ffbd54"))
	var pen := Vector2(53, 58)
	draw_string(UI.HEADING, pen, "LUMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color("fffaf0"))
	pen.x += UI.HEADING.get_string_size("LUMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x + 7
	draw_string(UI.HEADING, pen, "KART", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color("ffc15e"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
