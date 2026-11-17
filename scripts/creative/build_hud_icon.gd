extends Control
## Small vector glyphs for Bauwelt HUD chips. Drawn shapes (no emoji font
## dependency) keep the LUMO look identical on every Android device.

@export var kind: String = "block"
@export var tint: Color = Color("ffd25a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	draw_circle(c, r, tint.darkened(0.35))
	draw_circle(c - Vector2(0, 1), r - 2.0, tint)
	var ink := tint.darkened(0.62)
	var light := Color(1, 1, 1, 0.92)
	match kind:
		"block":
			var box := Rect2(c - Vector2(r * 0.48, r * 0.42), Vector2(r * 0.96, r * 0.84))
			draw_rect(box, light)
			draw_rect(box, ink, false, 2.0)
			draw_line(box.position + Vector2(0, box.size.y * 0.5), box.end - Vector2(0, box.size.y * 0.5), ink, 2.0)
		"layer":
			for i in range(3):
				var y := c.y + r * (0.36 - i * 0.34)
				draw_line(Vector2(c.x - r * 0.5, y), Vector2(c.x + r * 0.5, y), light, 4.0)
		"star", "badge":
			var points := PackedVector2Array()
			for i in range(10):
				var radius := r * (0.62 if i % 2 == 0 else 0.27)
				var angle := -PI * 0.5 + i * PI / 5.0
				points.append(c + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, light)
		"world", "map":
			draw_circle(c, r * 0.56, Color("4fb7e8"))
			draw_circle(c + Vector2(-r * 0.15, -r * 0.1), r * 0.24, Color("7ed957"))
			draw_circle(c + Vector2(r * 0.22, r * 0.2), r * 0.16, Color("7ed957"))
		"wood":
			draw_rect(Rect2(c - Vector2(r * 0.55, r * 0.22), Vector2(r * 1.1, r * 0.44)), Color("a0663a"))
			draw_circle(c + Vector2(r * 0.55, 0), r * 0.22, Color("e6b27a"))
		"stone":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.55, r * 0.3), c + Vector2(-r * 0.3, -r * 0.35),
				c + Vector2(r * 0.25, -r * 0.42), c + Vector2(r * 0.58, r * 0.12),
				c + Vector2(r * 0.3, r * 0.42)]), Color("dfe5ea"))
		"food":
			draw_circle(c + Vector2(0, r * 0.08), r * 0.42, Color("ff6b5a"))
			draw_line(c - Vector2(0, r * 0.3), c - Vector2(-r * 0.12, r * 0.6), Color("4f8a2a"), 3.0)
		"coin":
			draw_circle(c, r * 0.5, Color("ffe08a"))
			draw_arc(c, r * 0.36, 0, TAU, 20, Color("c8861d"), 2.0)
		"grain":
			for i in range(3):
				draw_circle(c + Vector2((i - 1) * r * 0.26, -r * 0.1 + abs(i - 1) * r * 0.12), r * 0.16, light)
			draw_line(c + Vector2(0, r * 0.05), c + Vector2(0, r * 0.6), light, 2.0)
		"people":
			draw_circle(c + Vector2(0, -r * 0.22), r * 0.22, light)
			draw_circle(c + Vector2(0, r * 0.5), r * 0.42, light)
		"water":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 0.6), c + Vector2(r * 0.38, r * 0.12),
				c + Vector2(0, r * 0.5), c + Vector2(-r * 0.38, r * 0.12)]), Color("dff6ff"))
		"heart":
			draw_circle(c + Vector2(-r * 0.2, -r * 0.08), r * 0.24, light)
			draw_circle(c + Vector2(r * 0.2, -r * 0.08), r * 0.24, light)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.42, 0), c + Vector2(r * 0.42, 0), c + Vector2(0, r * 0.5)]), light)
		"day":
			draw_circle(c, r * 0.3, light)
			for i in range(8):
				var dir := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + dir * r * 0.42, c + dir * r * 0.62, light, 2.0)
		"treasury":
			draw_rect(Rect2(c - Vector2(r * 0.5, r * 0.18), Vector2(r, r * 0.6)), Color("8a5a2b"))
			draw_rect(Rect2(c - Vector2(r * 0.5, r * 0.42), Vector2(r, r * 0.26)), Color("b57a3c"))
			draw_rect(Rect2(c - Vector2(r * 0.1, r * 0.2), Vector2(r * 0.2, r * 0.22)), Color("ffe08a"))
		"shield":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.45, -r * 0.45), c + Vector2(r * 0.45, -r * 0.45),
				c + Vector2(r * 0.4, r * 0.1), c + Vector2(0, r * 0.58), c + Vector2(-r * 0.4, r * 0.1)]), light)
		_:
			draw_circle(c, r * 0.3, light)
