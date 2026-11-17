extends Button
## Neon-Glas-Kachel für das Lumo-Kart-Hauptmenü: echter Button (Fokus, Touch, Tastatur),
## selbst gezeichnet mit Glow, Glanzkante, eigenem Vektor-Icon und Drück-Animation.
## Stile: "hero" (große Modus-Kachel), "feature" (Garage/Strecken/Belohnungen), "nav" (Leiste), "chip".
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const ICONS = preload("res://scripts/games/kart_neon_icons.gd")

var title := ""
var caption := ""
var icon_kind := ""
var accent := Color("21ccff")
var accent_dark := Color("0b2255")
var tile_style := "hero"
var art: Texture2D
var badge := false
var active := false
var ui_scale := 1.0
var compact := false
var reduced_motion := false
var _press_tween: Tween
var _glow_phase := 0.0


func _ready() -> void:
	text = ""
	clip_text = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tooltip_text = title if caption.is_empty() else title + " – " + caption
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_recentre)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(tile_style == "hero" and not reduced_motion)
	_recentre()


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func _recentre() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	_glow_phase = fposmod(_glow_phase + delta * 0.9, TAU)
	queue_redraw()


func _on_down() -> void:
	if reduced_motion:
		scale = Vector2.ONE * 0.97
		return
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * 0.93, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_up() -> void:
	if reduced_motion:
		scale = Vector2.ONE
		return
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _box(fill: Color, border: Color, radius: float, border_w: float, glow: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, roundi(border_w)))
	box.set_corner_radius_all(roundi(radius))
	box.anti_aliasing = true
	box.shadow_color = Color(accent.r, accent.g, accent.b, glow)
	box.shadow_size = roundi((14.0 if tile_style == "hero" else 7.0) * ui_scale * (1.0 if glow > 0.0 else 0.0))
	return box


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var k := ui_scale
	var rect := Rect2(Vector2.ZERO, size)
	var pulse := 0.5 + 0.5 * sin(_glow_phase)
	var lit := is_hovered() or has_focus() or active
	var radius := (18.0 if tile_style == "hero" else 14.0 if tile_style == "feature" else 12.0) * k
	if tile_style == "thumb":
		radius = 10.0 * k
	var glow := 0.0
	match tile_style:
		"hero":
			glow = 0.42 + 0.18 * pulse
		"feature":
			glow = 0.22
		_:
			glow = 0.35 if active else 0.0
	if lit:
		glow += 0.15
	var fill := accent_dark
	if tile_style == "hero":
		fill = accent.darkened(0.45)
		fill.a = 0.96
	elif tile_style == "nav" and active:
		fill = accent.darkened(0.25)
	if is_pressed():
		fill = fill.darkened(0.15)
	draw_style_box(_box(fill, accent.lightened(0.25 if lit else 0.0), radius, (3.0 if tile_style == "hero" else 2.0) * k, glow), rect)
	# Diagonale Lichtbahn (Tempo-Look) und Glas-Glanzkante oben.
	if tile_style in ["hero", "feature"]:
		var band := Color(1, 1, 1, 0.07)
		var x0 := size.x * 0.52
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 3 * k), Vector2(x0 + size.y * 0.55, 3 * k),
			Vector2(x0 + size.y * 0.15, size.y - 3 * k), Vector2(x0 - size.y * 0.4, size.y - 3 * k)]), band)
		var sheen := _box(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), radius * 0.8, 0.0, 0.0)
		sheen.set_border_width_all(0)
		draw_style_box(sheen, Rect2(Vector2(4, 3) * k, Vector2(size.x - 8 * k, size.y * 0.34)))
	if art != null and tile_style == "feature" and size.x >= 190.0 * k:
		var art_h := size.y * 0.62
		var art_w := minf(size.x * 0.5, art_h * 1.6)
		draw_texture_rect(art, Rect2(Vector2(size.x - art_w - 6 * k, size.y - art_h - 6 * k), Vector2(art_w, art_h)), false, Color(1, 1, 1, 0.9))
	var font: Font = UI.HEADING
	var body: Font = UI.BODY
	if tile_style == "thumb":
		_draw_thumb(font, k, radius)
		return
	match tile_style:
		"hero":
			_draw_hero(font, body, k, pulse)
		"feature":
			_draw_feature(font, body, k)
		"nav":
			_draw_nav(body, k)
		_:
			_draw_chip(font, k)
	if badge:
		var bc := Vector2(size.x - 12 * k, 12 * k)
		draw_circle(bc, 9 * k, Color("ffd23f"))
		draw_string(font, bc + Vector2(-3 * k, 6 * k), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * k), Color("3a2400"))
	if has_focus():
		var ring := _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85), radius, 2.0 * k, 0.0)
		draw_style_box(ring, rect.grow(-3 * k))


func _fit(font: Font, value: String, max_px: int, width: float) -> int:
	var px := max_px
	while px > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	return px


func _draw_hero(font: Font, body: Font, k: float, pulse: float) -> void:
	var pad := 10.0 * k
	var icon_s := minf(size.y * 0.42, 46.0 * k)
	var tall := size.y >= 104.0 * k and size.x < size.y * 1.6
	if tall:
		ICONS.draw(self, icon_kind, Vector2(pad + icon_s * 0.55, pad + icon_s * 0.55), icon_s, Color.WHITE)
		var tpx := _fit(font, title, roundi(26 * k), size.x - 2 * pad)
		draw_string(font, Vector2(pad, pad + icon_s * 1.15 + tpx * 0.85), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Color.WHITE)
		if not compact and not caption.is_empty():
			var cpx := roundi(13 * k)
			var lines := _wrap(body, caption, cpx, size.x - 2 * pad - 22 * k)
			var y := pad + icon_s * 1.15 + tpx * 1.05 + cpx
			for line in lines.slice(0, 2):
				draw_string(body, Vector2(pad, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, cpx, Color(1, 1, 1, 0.86))
				y += cpx * 1.15
	else:
		ICONS.draw(self, icon_kind, Vector2(pad + icon_s * 0.55, size.y * 0.5), icon_s, Color.WHITE)
		var left := pad * 1.6 + icon_s
		var tpx := _fit(font, title, roundi(24 * k), size.x - left - pad - 20 * k)
		var has_caption := not compact and not caption.is_empty() and size.y >= 60.0 * k
		var ty := size.y * 0.5 + tpx * 0.35 - (8.0 * k if has_caption else 0.0)
		draw_string(font, Vector2(left, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Color.WHITE)
		if has_caption:
			var cpx := _fit(body, caption, roundi(13 * k), size.x - left - pad - 20 * k)
			draw_string(body, Vector2(left, ty + cpx * 1.3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cpx, Color(1, 1, 1, 0.86))
	# Tempo-Chevrons »» unten rechts, leicht pulsierend.
	var base := Vector2(size.x - 26 * k, size.y - 16 * k)
	for i in range(2):
		var x := base.x + i * 9 * k
		var a := 0.55 + 0.35 * pulse * (1.0 if i == 1 else 0.6)
		draw_polyline(PackedVector2Array([Vector2(x - 4 * k, base.y - 6 * k), Vector2(x + 1 * k, base.y), Vector2(x - 4 * k, base.y + 6 * k)]), Color(1, 1, 1, a), 2.6 * k, true)


func _draw_feature(font: Font, body: Font, k: float) -> void:
	var pad := 10.0 * k
	var icon_s := minf(size.y * 0.34, 30.0 * k)
	ICONS.draw(self, icon_kind, Vector2(pad + icon_s * 0.5, pad + icon_s * 0.5), icon_s, accent.lightened(0.35))
	var left := pad * 1.5 + icon_s
	var tpx := _fit(font, title, roundi(20 * k), size.x - left - pad)
	draw_string(font, Vector2(left, pad + icon_s * 0.5 + tpx * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Color.WHITE)
	if not compact and not caption.is_empty() and size.y >= 72.0 * k:
		var cpx := roundi(12 * k)
		var width := size.x - 2 * pad - (size.x * 0.5 if art != null and size.x >= 190.0 * k else 0.0)
		var y := pad + icon_s + cpx * 1.4
		for line in _wrap(body, caption, cpx, maxf(width, 60 * k)).slice(0, 2):
			draw_string(body, Vector2(pad, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, cpx, Color(1, 1, 1, 0.82))
			y += cpx * 1.15


func _draw_nav(body: Font, k: float) -> void:
	var icon_s := minf(size.y * 0.42, 26.0 * k)
	var show_label := size.y >= 52.0 * k
	var cy := size.y * (0.4 if show_label else 0.5)
	ICONS.draw(self, icon_kind, Vector2(size.x * 0.5, cy), icon_s, Color.WHITE if active else accent.lightened(0.45))
	if show_label:
		var px := _fit(body, title, roundi(12 * k), size.x - 6 * k)
		var w := body.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(body, Vector2((size.x - w) * 0.5, size.y - 8 * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)


func _draw_chip(font: Font, k: float) -> void:
	var icon_s := minf(size.y * 0.55, 26.0 * k)
	var has_text := not title.is_empty()
	var cx := size.x * 0.5 if not has_text else 10 * k + icon_s * 0.5
	if not icon_kind.is_empty():
		ICONS.draw(self, icon_kind, Vector2(cx, size.y * 0.5), icon_s, accent.lightened(0.4))
	if has_text:
		var left := (16 * k + icon_s) if not icon_kind.is_empty() else 10 * k
		var px := _fit(font, title, roundi(17 * k), size.x - left - 8 * k)
		draw_string(font, Vector2(left, size.y * 0.5 + px * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)


func _wrap(font: Font, value: String, px: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in value.split(" "):
		var candidate := word if current.is_empty() else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	return lines


func _draw_thumb(font: Font, k: float, radius: float) -> void:
	var inner := Rect2(Vector2(3, 3) * k, size - Vector2(6, 6) * k)
	if art != null:
		var tex := art.get_size()
		var factor := maxf(inner.size.x / tex.x, inner.size.y / tex.y)
		var src := inner.size / factor
		draw_texture_rect_region(art, inner, Rect2((tex - src) * 0.5, src))
	# Lesbarkeits-Verlauf unten, damit der Name auf jedem Bild klar bleibt.
	var shade_h := minf(inner.size.y * 0.5, 40.0 * k)
	var shade := PackedVector2Array([Vector2(inner.position.x, inner.end.y - shade_h), Vector2(inner.end.x, inner.end.y - shade_h),
		inner.end, Vector2(inner.position.x, inner.end.y)])
	draw_polygon(shade, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.03, 0.1, 0.85), Color(0.01, 0.03, 0.1, 0.85)]))
	var big := size.y >= 110.0 * k
	var px := _fit(font, title, roundi((24 if big else 14) * k), inner.size.x - (52 if big else 10) * k)
	draw_string(font, Vector2(inner.position.x + 8 * k, inner.end.y - (10 if big else 6) * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	if big:
		var c := Vector2(inner.end.x - 22 * k, inner.end.y - 20 * k)
		draw_circle(c, 15 * k, Color(0.02, 0.07, 0.2, 0.85))
		draw_arc(c, 15 * k, 0, TAU, 24, accent, 2 * k, true)
		ICONS.draw(self, "play", c + Vector2(2, 0) * k, 18 * k, Color.WHITE)
	var frame := _box(Color(0, 0, 0, 0), accent.lightened(0.2) if active else accent.darkened(0.2), radius, (3.0 if active else 1.5) * k, 0.35 if active else 0.0)
	frame.draw_center = false
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	if has_focus():
		var ring := _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85), radius, 2.0 * k, 0.0)
		ring.draw_center = false
		draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(-4 * k))
