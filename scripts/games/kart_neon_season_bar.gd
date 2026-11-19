extends Button
## Sternenpfad-Leiste: echter Fortschritt zur nächsten echten Freischaltung (Fahrer/Kart).
## Glasplatte, Kristallstern, Balken und Belohnungs-Zeichen stammen aus dem gerenderten UI-Kit.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const ICONS = preload("res://scripts/games/kart_neon_icons.gd")
const KIT = preload("res://scripts/games/kart_ui3d.gd")
const PLATE := "plate_feature_navy"
var stars := 0
var ui_scale := 1.0
var reduced_motion := false
var _press_tween: Tween
var _outline := PackedVector2Array()
var _overlay_uvs := PackedVector2Array()
var _geometry_key := Vector3.ZERO


func _ready() -> void:
	name = "Sternenpfad"
	text = ""
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tooltip_text = "Sternenpfad öffnen"
	resized.connect(func(): pivot_offset = size * 0.5; queue_redraw())
	button_down.connect(func(): _tween(0.96, 0.06))
	button_up.connect(func(): _tween(1.0, 0.25))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _tween(target: float, seconds: float) -> void:
	queue_redraw()
	if _press_tween:
		_press_tween.kill()
	if reduced_motion:
		scale = Vector2.ONE * (0.98 if target < 1.0 else 1.0)
		return
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * target, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func summary() -> String:
	var goal := PATH.next_milestone(stars)
	if goal.is_empty():
		return "Alle Fahrer und Karts freigeschaltet!"
	return "Nächste Belohnung: %s %s bei %d ★" % [goal.kind, goal.name, goal.stars]


func _flat_panel(k: float) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("100f45", 0.94)
	panel.border_color = Color("b06bff").lightened(0.15 if has_focus() or is_hovered() else 0.0)
	panel.set_border_width_all(maxi(1, roundi(2 * k)))
	panel.set_corner_radius_all(roundi(16 * k))
	draw_style_box(panel, Rect2(Vector2.ZERO, size))


func _draw() -> void:
	var k := ui_scale
	if size.x < 4 or size.y < 4:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var down := is_pressed()
	var tint := Color(0.74, 0.76, 0.86) if down else (Color(1.12, 1.12, 1.12) if has_focus() or is_hovered() else Color.WHITE)
	if KIT.draw_plate(self, PLATE, rect, k, tint):
		var key := Vector3(size.x, size.y, k)
		if key != _geometry_key:
			_geometry_key = key
			_outline = KIT.face_outline(PLATE, rect, k)
			_overlay_uvs = KIT.overlay_uvs("overlay_glass_grid", _outline)
		KIT.draw_overlay(self, "overlay_glass_grid", _outline, _overlay_uvs)
	else:
		_flat_panel(k)
	var head: Font = UI.HEADING
	var body: Font = UI.BODY
	var progress := PATH.path_progress(stars)
	var goal := PATH.next_milestone(stars)
	var tall := size.y >= 64 * k
	# Kristallstern ragt links leicht über den Rand (Zielbild).
	var icon_s := minf(size.y * 0.92, 68 * k)
	ICONS.draw3d(self, "star", Vector2(6 * k + icon_s * 0.5, size.y * 0.5), icon_s, Color("d9b8ff"))
	var left := 12 * k + icon_s
	# Rechts: Zeichen der nächsten echten Belohnung (Schloss) oder Krone, wenn alles frei ist.
	var slot := 0.0
	if size.x >= 300 * k:
		slot = minf(size.y * 0.74, 52 * k)
		var slot_rect := Rect2(Vector2(size.x - slot - 10 * k, (size.y - slot) * 0.5), Vector2(slot, slot))
		KIT.draw_plate(self, "plate_nav_active" if goal.is_empty() else "plate_nav", slot_rect, k)
		ICONS.draw3d(self, "crown" if goal.is_empty() else "lock", slot_rect.get_center(), slot * 0.7, Color("ffd568"))
		slot += 8 * k
	var avail := size.x - left - 14 * k - slot
	var title_px := roundi(minf(19 * k, size.y * 0.3))
	var title_y := size.y * (0.36 if tall else 0.42)
	draw_string_outline(head, Vector2(left, title_y + title_px * 0.07), "Sternenpfad", HORIZONTAL_ALIGNMENT_LEFT, avail, title_px, maxi(2, roundi(title_px * 0.16)), Color(0.02, 0.04, 0.16, 0.5))
	draw_string(head, Vector2(left, title_y), "Sternenpfad", HORIZONTAL_ALIGNMENT_LEFT, avail, title_px, Color.WHITE)
	var bar_h := (15.0 if tall else 14.0) * k
	var by := size.y - bar_h - (9 if tall else 7) * k
	if tall:
		var text := summary()
		var spx := roundi(12 * k)
		var title_w := head.get_string_size("Sternenpfad", HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
		var beside := avail - title_w - 12 * k
		if body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x <= beside:
			# Breite Leiste: Text neben dem Titel, damit der Balken Luft hat.
			draw_string(body, Vector2(left + title_w + 12 * k, title_y - 1 * k), text, HORIZONTAL_ALIGNMENT_LEFT, beside, spx, Color(1, 1, 1, 0.88))
		elif by - title_y >= spx * 1.25 and body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x <= avail:
			draw_string(body, Vector2(left, title_y + spx * 1.2), text, HORIZONTAL_ALIGNMENT_LEFT, avail, spx, Color(1, 1, 1, 0.88))
	var bar_w := avail
	var ratio := clampf(float(progress.x) / float(maxi(progress.y, 1)), 0.0, 1.0)
	var track_rect := Rect2(Vector2(left, by), Vector2(bar_w, bar_h))
	if not KIT.draw_bar(self, "bar_fill_gold", track_rect, ratio, k):
		draw_rect(track_rect, Color("060a26"))
		draw_rect(Rect2(track_rect.position, Vector2(bar_w * ratio, bar_h)), Color("ffc23d"))
	var label := "%d / %d" % [progress.x, progress.y]
	var lpx := roundi(11 * k)
	var lw := head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
	var on_gold := ratio >= 0.5 + lw / maxf(bar_w, 1.0) * 0.5
	var at := Vector2(left + (bar_w - lw) * 0.5, by + bar_h * 0.5 + lpx * 0.35)
	if on_gold:
		draw_string(head, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, Color("3a1c00"))
	else:
		draw_string_outline(head, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, maxi(2, roundi(2 * k)), Color(0.02, 0.04, 0.16, 0.8))
		draw_string(head, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, Color.WHITE)
	if has_focus():
		draw_style_box(KIT.focus_ring(roundi(8 * k), roundi(2.2 * k)), rect.grow(-3 * k))
