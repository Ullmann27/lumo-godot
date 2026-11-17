extends Button
## Sternenpfad-Leiste: echter Fortschritt zur nächsten echten Freischaltung (Fahrer/Kart).
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const ICONS = preload("res://scripts/games/kart_neon_icons.gd")
var stars := 0
var ui_scale := 1.0
var _press_tween: Tween


func _ready() -> void:
	name = "Sternenpfad"
	text = ""
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tooltip_text = "Sternenpfad öffnen"
	resized.connect(func(): pivot_offset = size * 0.5; queue_redraw())
	button_down.connect(func(): _tween(0.96, 0.06))
	button_up.connect(func(): _tween(1.0, 0.25))


func _tween(target: float, seconds: float) -> void:
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * target, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func summary() -> String:
	var goal := PATH.next_milestone(stars)
	if goal.is_empty():
		return "Alle Fahrer und Karts freigeschaltet!"
	return "Nächste Belohnung: %s %s bei %d ★" % [goal.kind, goal.name, goal.stars]


func _draw() -> void:
	var k := ui_scale
	if size.x < 4 or size.y < 4:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("100f45", 0.94)
	panel.border_color = Color("b06bff").lightened(0.15 if has_focus() or is_hovered() else 0.0)
	panel.set_border_width_all(maxi(1, roundi(2 * k)))
	panel.set_corner_radius_all(roundi(16 * k))
	panel.shadow_color = Color(0.6, 0.35, 1.0, 0.3)
	panel.shadow_size = roundi(8 * k)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var icon_s := minf(size.y * 0.7, 54 * k)
	ICONS.draw(self, "star", Vector2(10 * k + icon_s * 0.5, size.y * 0.5), icon_s, Color("d9b8ff"))
	var left := 18 * k + icon_s
	var right_w := 0.0
	var head: Font = UI.HEADING
	var body: Font = UI.BODY
	var title_px := roundi(minf(18 * k, size.y * 0.3))
	var avail := size.x - left - 14 * k
	draw_string(head, Vector2(left, size.y * 0.36), "Sternenpfad", HORIZONTAL_ALIGNMENT_LEFT, avail, title_px, Color.WHITE)
	var progress := PATH.path_progress(stars)
	var tall := size.y >= 64 * k
	if tall:
		draw_string(body, Vector2(left, size.y * 0.36 + title_px * 1.05), summary(), HORIZONTAL_ALIGNMENT_LEFT, avail, roundi(12 * k), Color(1, 1, 1, 0.8))
	var bar_h := 12.0 * k
	var by := size.y - bar_h - 9 * k
	var track := StyleBoxFlat.new()
	track.bg_color = Color("060a26")
	track.border_color = Color("6b4bd1")
	track.set_border_width_all(1)
	track.set_corner_radius_all(roundi(bar_h * 0.5))
	var bar_w := avail - right_w
	draw_style_box(track, Rect2(Vector2(left, by), Vector2(bar_w, bar_h)))
	var ratio := clampf(float(progress.x) / float(maxi(progress.y, 1)), 0.0, 1.0)
	if ratio > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ffc23d")
		fill.set_corner_radius_all(roundi(bar_h * 0.5))
		draw_style_box(fill, Rect2(Vector2(left, by), Vector2(maxf(bar_h, bar_w * ratio), bar_h)))
	var label := "%d / %d" % [progress.x, progress.y]
	var lpx := roundi(11 * k)
	var lw := head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
	draw_string(head, Vector2(left + (bar_w - lw) * 0.5, by + bar_h - 2 * k), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, Color.WHITE)
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = Color(1, 1, 1, 0.85)
		ring.set_border_width_all(maxi(1, roundi(2 * k)))
		ring.set_corner_radius_all(roundi(16 * k))
		draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(-3 * k))
