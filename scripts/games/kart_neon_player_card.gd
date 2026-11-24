extends Button
## Spielerkarte: Lumo-Avatar, Fahrer-Stufe und Fortschritt. Alle Zahlen kommen aus
## echten gespeicherten Sternen (siehe kart_star_path.gd); Start ehrlich bei 0.
## Glasplatte, Stufen-Schild und Balken stammen aus dem gerenderten UI-Kit.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const KIT = preload("res://scripts/games/kart_ui3d.gd")
var stars := 0
var ui_scale := 1.0
var driver_name := "Lumo"
var avatar: Texture2D
var _circle := PackedVector2Array()
var _circle_uvs := PackedVector2Array()
var _circle_key := Vector2.ZERO


func _ready() -> void:
	name = "PlayerCard"
	text = ""
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Fahrer auswählen"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


## Runder Ausschnitt des Avatars als Vieleck mit Bildkoordinaten (kein Shader, kein Clip).
func _update_circle(centre: Vector2, radius: float) -> void:
	var key := Vector2(centre.x, radius)
	if key == _circle_key and not _circle.is_empty():
		return
	_circle_key = key
	_circle.resize(28)
	_circle_uvs.resize(28)
	var tex := avatar.get_size()
	var side := minf(tex.x, tex.y)
	for index in 28:
		var direction := Vector2.from_angle(TAU * index / 28.0)
		_circle[index] = centre + direction * radius
		_circle_uvs[index] = (tex * 0.5 + direction * side * 0.5) / tex


func _flat_panel(k: float) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0a1d4d", 0.92)
	panel.border_color = Color("3fd2ff").lightened(0.3 if has_focus() or is_hovered() else 0.0)
	panel.set_border_width_all(maxi(1, roundi(2 * k)))
	panel.set_corner_radius_all(roundi(size.y * 0.5))
	draw_style_box(panel, Rect2(Vector2.ZERO, size))


func _draw() -> void:
	var k := ui_scale
	if size.x < 4 or size.y < 4:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var tint := Color(0.74, 0.76, 0.86) if is_pressed() else (Color(1.12, 1.12, 1.12) if has_focus() or is_hovered() else Color.WHITE)
	if not KIT.draw_plate(self, "plate_feature_navy", rect, k, tint):
		_flat_panel(k)
	var r := size.y * 0.5 - 6 * k
	var c := Vector2(size.y * 0.5 + 2 * k, size.y * 0.5)
	draw_circle(c, r + 2.5 * k, Color("7fe3ff"))
	draw_circle(c, r + 1.0 * k, Color("0a1d4d"))
	if avatar != null:
		_update_circle(c, r)
		draw_colored_polygon(_circle, Color.WHITE, _circle_uvs, avatar)
	var left := size.y + 6 * k
	var right := size.x - 12 * k
	var head: Font = UI.HEADING
	var body: Font = UI.BODY
	var name_px := roundi(minf(18 * k, size.y * 0.32))
	draw_string(head, Vector2(left, size.y * 0.44), driver_name, HORIZONTAL_ALIGNMENT_LEFT, right - left, name_px, Color.WHITE)
	var level := PATH.level(stars)
	var progress := PATH.level_progress(stars)
	var pill_text := "Stufe %d" % level
	var pill_px := roundi(minf(12 * k, size.y * 0.24))
	var pill_w := body.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_px).x + 14 * k
	var pill_h := pill_px + 7 * k
	var bar_y := size.y * 0.54
	var pill_rect := Rect2(Vector2(left, bar_y), Vector2(pill_w, pill_h))
	if not KIT.draw_plate(self, "button_secondary_blue", pill_rect.grow_individual(0, 0, 0, 2 * k), k, Color.WHITE, true):
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color("1f6fe0")
		pill.set_corner_radius_all(roundi(8 * k))
		draw_style_box(pill, pill_rect)
	draw_string(body, Vector2(left + 7 * k, bar_y + pill_px + 1.5 * k), pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_px, Color.WHITE)
	var bar_x := left + pill_w + 8 * k
	var bar_w := right - bar_x
	if bar_w >= 36 * k:
		var bar_h := 9.0 * k
		var by := bar_y + (pill_h - bar_h) * 0.5 + 1.5 * k
		var ratio := clampf(float(progress.x) / float(maxi(progress.y, 1)), 0.0, 1.0)
		var track_rect := Rect2(Vector2(bar_x, by), Vector2(bar_w, bar_h))
		if not KIT.draw_bar(self, "bar_fill_cyan", track_rect, ratio, k):
			draw_rect(track_rect, Color("06112e"))
			draw_rect(Rect2(track_rect.position, Vector2(bar_w * ratio, bar_h)), Color("33d6ff"))
		if size.x >= 230 * k:
			var label := "%d / %d ★ bis Stufe %d" % [progress.x, progress.y, level + 1]
			var lpx := roundi(11 * k)
			draw_string(body, Vector2(bar_x, by - 3.5 * k), label, HORIZONTAL_ALIGNMENT_LEFT, bar_w, lpx, Color(1, 1, 1, 0.85))
	if has_focus():
		draw_style_box(KIT.focus_ring(roundi(8 * k), roundi(2.2 * k)), rect.grow(-3 * k))
