extends Button
## Spielerkarte: Lumo-Avatar, Fahrer-Stufe und Fortschritt. Alle Zahlen kommen aus
## echten gespeicherten Sternen (siehe kart_star_path.gd); Start ehrlich bei 0.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
var stars := 0
var ui_scale := 1.0
var driver_name := "Lumo"
var avatar: Texture2D


func _ready() -> void:
	name = "PlayerCard"
	text = ""
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Fahrer auswählen"
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var k := ui_scale
	if size.x < 4 or size.y < 4:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0a1d4d", 0.92)
	panel.border_color = Color("3fd2ff").lightened(0.3 if has_focus() or is_hovered() else 0.0)
	panel.set_border_width_all(maxi(1, roundi(2 * k)))
	panel.set_corner_radius_all(roundi(size.y * 0.5))
	panel.shadow_color = Color(0.25, 0.8, 1.0, 0.28)
	panel.shadow_size = roundi(6 * k)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var r := size.y * 0.5 - 4 * k
	var c := Vector2(size.y * 0.5, size.y * 0.5)
	draw_circle(c, r + 2 * k, Color("ffb52d"))
	if avatar != null:
		draw_texture_rect(avatar, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false)
	var left := size.y + 4 * k
	var width := size.x - left - 14 * k
	var head: Font = UI.HEADING
	var body: Font = UI.BODY
	var name_px := roundi(minf(18 * k, size.y * 0.3))
	draw_string(head, Vector2(left, size.y * 0.42), driver_name, HORIZONTAL_ALIGNMENT_LEFT, width, name_px, Color.WHITE)
	var level := PATH.level(stars)
	var progress := PATH.level_progress(stars)
	var pill_text := "Stufe %d" % level
	var pill_px := roundi(minf(12 * k, size.y * 0.22))
	var pill_w := body.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_px).x + 12 * k
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color("1f6fe0")
	pill.set_corner_radius_all(roundi(8 * k))
	var bar_y := size.y * 0.58
	draw_style_box(pill, Rect2(Vector2(left, bar_y), Vector2(pill_w, pill_px + 6 * k)))
	draw_string(body, Vector2(left + 6 * k, bar_y + pill_px + 1 * k), pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_px, Color.WHITE)
	var bar_x := left + pill_w + 6 * k
	var bar_w := maxf(10 * k, size.x - bar_x - 16 * k)
	var bar_h := 7.0 * k
	var by := bar_y + (pill_px + 6 * k - bar_h) * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("06112e")
	track.set_corner_radius_all(roundi(bar_h * 0.5))
	draw_style_box(track, Rect2(Vector2(bar_x, by), Vector2(bar_w, bar_h)))
	var fill := track.duplicate()
	fill.bg_color = Color("33d6ff")
	var ratio := float(progress.x) / float(maxi(progress.y, 1))
	if ratio > 0.0:
		draw_style_box(fill, Rect2(Vector2(bar_x, by), Vector2(maxf(bar_h, bar_w * ratio), bar_h)))
	if size.x >= 230 * k:
		var label := "%d / %d ★ bis Stufe %d" % [progress.x, progress.y, level + 1]
		var lpx := roundi(10 * k)
		draw_string(body, Vector2(bar_x, by - 3 * k), label, HORIZONTAL_ALIGNMENT_LEFT, bar_w, lpx, Color(1, 1, 1, 0.75))
