extends Control
## Original track-striped wordmark. The athletic display face stays readable on the Fold cover.
const DISPLAY = preload("res://assets/fonts/BarlowSemiCondensed-ExtraBoldItalic.ttf")
const SIZE := Vector2(300, 73)


func _ready() -> void:
	name = "LumoKartWordmark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Lumo Kart"
	resized.connect(queue_redraw)


func _draw() -> void:
	var k := minf(size.x / SIZE.x, size.y / SIZE.y)
	if k <= 0.0:
		return
	draw_set_transform((size - SIZE * k) * 0.5, 0.0, Vector2.ONE * k)
	var pos := Vector2(4, 57)
	var px := 61
	draw_string(DISPLAY, pos, "LUMO", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("fff8e2"))
	pos.x += DISPLAY.get_string_size("LUMO", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 7
	draw_string(DISPLAY, pos, "KART", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("ffc657"))
	var end := pos.x + DISPLAY.get_string_size("KART", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_colored_polygon(PackedVector2Array([Vector2(4,64), Vector2(end-6,60), Vector2(end-10,65), Vector2(4,67)]), Color("4bdec3"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
