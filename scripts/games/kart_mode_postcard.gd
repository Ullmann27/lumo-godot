extends "res://scripts/games/kart_neon_tile.gd"
## Each race ticket frames an actual course photograph. Its large title and one-line
## goal stay over a dark ink gradient; the untouched right edge shows the scenery.
const DISPLAY = preload("res://assets/fonts/BarlowSemiCondensed-ExtraBoldItalic.ttf")


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var k := ui_scale
	var cut := minf(11.0 * k, size.y * 0.17)
	var face := PackedVector2Array([
		Vector2(cut, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y - cut),
		Vector2(size.x - cut, size.y - 1), Vector2(1, size.y - 1), Vector2(1, cut)
	])
	draw_colored_polygon(face, Color("18344b"))
	if art != null:
		var tex := art.get_size()
		var scale_factor := maxf(size.x / tex.x, size.y / tex.y)
		var crop := size / scale_factor
		var origin := (tex - crop) * Vector2(0.55, 0.48)
		var uv := PackedVector2Array()
		for point in face:
			uv.append((origin + point / scale_factor) / tex)
		draw_polygon(face, PackedColorArray([Color.WHITE]), uv, art)
	var ink := accent.darkened(0.83)
	ink.a = 0.99
	var far_ink := Color(0.02, 0.05, 0.09, 0.25)
	draw_polygon(face, PackedColorArray([ink, far_ink, far_ink, far_ink, ink, ink]))
	var edge := face.duplicate()
	edge.append(face[0])
	var edge_color := Color.WHITE if has_focus() or is_hovered() else accent.lightened(0.18)
	draw_polyline(edge, edge_color, maxf(1.0, 1.6 * k), true)
	draw_line(Vector2(2 * k, cut), Vector2(2 * k, size.y - k), accent, 3.5 * k, true)
	var pad := 12.0 * k
	var icon_size := clampf(size.y * 0.51, 20.0 * k, 50.0 * k)
	var right := size.x - pad
	var narrow := size.x < 145.0 * k
	if not narrow:
		ICONS.draw3d(self, icon_kind, Vector2(size.x - icon_size * 0.55 - 6.0 * k, icon_size * 0.5 + 4.0 * k), icon_size)
		right -= icon_size * 0.56
	var width := maxf(1.0, right - pad)
	var goal := short_caption if not short_caption.is_empty() else caption
	var goal_px := _fit(UI.BODY, goal, roundi(14.0 * k), size.x - 2.0 * pad, roundi(10.5 * k))
	var title_px := _fit(DISPLAY, title, roundi(minf(40.0 * k, size.y * 0.51)), width, roundi(17.0 * k))
	var title_base := size.y * 0.5 + title_px * 0.31 - goal_px * 0.48
	draw_string(DISPLAY, Vector2(pad, title_base), title, HORIZONTAL_ALIGNMENT_LEFT, width, title_px, Color.WHITE)
	if _fits(UI.BODY, goal, goal_px, size.x - pad * 2.0):
		draw_string(UI.BODY, Vector2(pad, title_base + goal_px * 1.32), goal, HORIZONTAL_ALIGNMENT_LEFT, size.x - pad * 2.0, goal_px, Color("f9f6de"))
	if is_pressed():
		draw_colored_polygon(face, Color(0.02, 0.08, 0.14, 0.24))
