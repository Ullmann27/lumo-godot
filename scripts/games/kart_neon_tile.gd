extends Button
## Kachel für das Lumo-Kart-Hauptmenü: echter Button (Fokus, Touch, Tastatur), gezeichnet mit
## den gerenderten Platten und Icons des 3D-UI-Kits (assets/kart/ui3d). Fehlt eine Textur,
## zeichnet die Kachel ihren flachen Vektor-Ersatz.
## Stile: "hero" (große Modus-Kachel), "feature" (Garage/Strecken/Belohnungen), "nav" (Leiste),
## "chip" (kleiner Knopf), "thumb" (Streckenbild).
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const ICONS = preload("res://scripts/games/kart_neon_icons.gd")
const KIT = preload("res://scripts/games/kart_ui3d.gd")
## Kleinste Schrift in dp; darunter wird gekürzt oder weggelassen statt verkleinert.
const MIN_TEXT := 11.0
const PRESSED_TINT := Color(0.74, 0.76, 0.86)
const LIT_TINT := Color(1.1, 1.1, 1.1)

var title := ""
## Kurzform für schmale Leisten-Kacheln, wenn `title` nicht in lesbarer Größe passt.
var short_title := ""
var caption := ""
## Ein-Wort-Untertitel für schmale Modus-Kacheln (Handy hoch), wenn `caption` nicht passt.
var short_caption := ""
## Streckenbild ohne Namen zeichnen (Layout entscheidet für die ganze Reihe).
var label_hidden := false
var icon_kind := ""
var accent := Color("21ccff")
var accent_dark := Color("0b2255")
var tile_style := "hero"
## Platte aus dem UI-Kit; leer = Regelplatte des Stils.
var plate := ""
var art: Texture2D
## Großes Kit-Icon als Motiv rechts, wenn kein Bild (`art`) da ist.
var art_icon := ""
var badge := false
var active := false
var ui_scale := 1.0
var compact := false
var reduced_motion := false
var _press_tween: Tween
var _glow_tween: Tween
var _geometry_key := Vector3.ZERO
var _geometry_plate := ""
var _outline := PackedVector2Array()
var _overlay_uvs := PackedVector2Array()
var _ring := PackedVector2Array()
var _shift := Vector2.ZERO


func _ready() -> void:
	text = ""
	clip_text = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if tooltip_text.is_empty():
		tooltip_text = title if caption.is_empty() else title + " – " + caption
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_recentre)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_recentre()
	_start_glow()


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func _recentre() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


## Sanftes Atmen der großen Kacheln über die Helligkeit des Knotens: kein Neuzeichnen,
## keine Zuweisungen je Frame. Bei reduzierter Bewegung aus.
func _start_glow() -> void:
	if tile_style != "hero" or reduced_motion:
		return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_interval(fposmod(float(get_index()) * 0.37, 1.2))
	_glow_tween.tween_property(self, "self_modulate", Color(1.09, 1.09, 1.09), 1.1).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(self, "self_modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)


func _on_down() -> void:
	queue_redraw()
	if reduced_motion:
		scale = Vector2.ONE * 0.97
		return
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE * 0.93, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_up() -> void:
	queue_redraw()
	if reduced_motion:
		scale = Vector2.ONE
		return
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _plate_name() -> String:
	if not plate.is_empty():
		return plate
	match tile_style:
		"hero":
			return "plate_hero_teal"
		"feature":
			return "plate_feature_navy"
		"thumb":
			return "frame_neon_amber" if active else "frame_neon_cyan"
		"nav":
			return "plate_nav_active" if active else "plate_nav"
		_:
			return "plate_nav"


## Umriss des Glasfelds (für Lichtschicht und Fokusring) nur neu berechnen, wenn sich
## Größe, Maßstab oder Platte ändern.
func _update_geometry(name: String) -> void:
	var key := Vector3(size.x, size.y, ui_scale)
	if key == _geometry_key and name == _geometry_plate:
		return
	_geometry_key = key
	_geometry_plate = name
	var rect := _body_rect()
	_outline = KIT.face_outline(name, rect, ui_scale)
	var layer := _overlay_name()
	_overlay_uvs = KIT.overlay_uvs(layer, _outline) if not layer.is_empty() else PackedVector2Array()
	_ring = KIT.face_outline(name, rect, ui_scale, 1.5)
	_ring.append(_ring[0])


## Fester Körper der Platte. In der Leiste etwas kleiner als die Tippfläche, damit der
## Leuchtrand nicht am Rand des Scroll-Containers abgeschnitten wird.
func _body_rect() -> Rect2:
	var rect := Rect2(Vector2.ZERO, size)
	if tile_style == "nav":
		return rect.grow_individual(-1.5 * ui_scale, -4.0 * ui_scale, -1.5 * ui_scale, -4.0 * ui_scale)
	return rect


func _overlay_name() -> String:
	match tile_style:
		"hero":
			return "overlay_hero_streak"
		"feature":
			return "overlay_glass_grid"
	return ""


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


## Vektor-Ersatz, wenn die Platte des Kits fehlt.
func _draw_flat_plate(rect: Rect2, k: float, radius: float, lit: bool) -> void:
	var glow := 0.0
	match tile_style:
		"hero":
			glow = 0.5
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
	if tile_style in ["hero", "feature"]:
		var x0 := size.x * 0.52
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 3 * k), Vector2(x0 + size.y * 0.55, 3 * k),
			Vector2(x0 + size.y * 0.15, size.y - 3 * k), Vector2(x0 - size.y * 0.4, size.y - 3 * k)]), Color(1, 1, 1, 0.07))


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var k := ui_scale
	var rect := _body_rect()
	var down := is_pressed()
	var lit := is_hovered() or has_focus() or (active and tile_style != "nav")
	var radius := (18.0 if tile_style == "hero" else 14.0 if tile_style == "feature" else 12.0) * k
	var font: Font = UI.HEADING
	var body: Font = UI.BODY
	_shift = Vector2(0, 1.5 * k) if down else Vector2.ZERO
	if tile_style == "thumb":
		_draw_thumb(font, k, down)
		return
	var name := _plate_name()
	var tint := PRESSED_TINT if down else (LIT_TINT if lit else Color.WHITE)
	var kit := KIT.draw_plate(self, name, rect, k, tint)
	if kit:
		_update_geometry(name)
		if not _overlay_uvs.is_empty():
			KIT.draw_overlay(self, _overlay_name(), _outline, _overlay_uvs, Color(1, 1, 1, 0.75 if down else 1.0))
	else:
		_draw_flat_plate(rect, k, radius, lit)
	draw_set_transform(_shift)
	match tile_style:
		"hero":
			_draw_hero(font, body, k)
		"feature":
			_draw_feature(font, body, k)
		"nav":
			_draw_nav(body, k)
		_:
			_draw_chip(font, k)
	draw_set_transform(Vector2.ZERO)
	if badge:
		ICONS.draw3d(self, "alert", Vector2(size.x - 9 * k, 9 * k), 24 * k)
	if has_focus():
		if kit:
			draw_polyline(_ring, Color(0.02, 0.05, 0.16, 0.7), 4.5 * k, true)
			draw_polyline(_ring, Color.WHITE, 2.2 * k, true)
		else:
			draw_style_box(KIT.focus_ring(roundi(radius), roundi(2.0 * k)), rect.grow(-3 * k))


## Größte Schrift zwischen `min_px` und `max_px`, mit der `value` in `width` passt.
func _fit(font: Font, value: String, max_px: int, width: float, min_px: int = 0) -> int:
	var floor_px := maxi(min_px, 6)
	var px := maxi(max_px, floor_px)
	while px > floor_px and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	return px


func _fits(font: Font, value: String, px: int, width: float) -> bool:
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width


## Text mit weichem Schatten; `slant` neigt die Schrift wie im Zielbild.
func _label(font: Font, at: Vector2, value: String, px: int, color: Color, slant: float = 0.0, shadow: float = 0.5) -> void:
	if slant != 0.0:
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-slant, 1), at + _shift))
		at = Vector2.ZERO
	if shadow > 0.0:
		draw_string_outline(font, at + Vector2(0, px * 0.07), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, roundi(px * 0.16)), Color(0.02, 0.04, 0.16, shadow))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
	if slant != 0.0:
		draw_set_transform(_shift)


## Zeichnet den Untertitel nur, wenn er vollständig in `max_lines` Zeilen passt
## (nie mitten im Satz abschneiden). Gibt die Zahl der gezeichneten Zeilen zurück.
func _caption(font: Font, at: Vector2, px: int, width: float, max_lines: int, color: Color) -> int:
	if caption.is_empty() or max_lines <= 0 or width <= 0.0:
		return 0
	var lines := _wrap(font, caption, px, width)
	if lines.size() > max_lines:
		return 0
	for line in lines:
		if not _fits(font, line, px, width):
			return 0
	var y := at.y
	for line in lines:
		_label(font, Vector2(at.x, y), line, px, color, 0.0, 0.35)
		y += px * 1.18
	return lines.size()


func _draw_hero(font: Font, body: Font, k: float) -> void:
	var pad := 9.0 * k
	var lip := 3.0 * k
	var min_px := roundi(13.0 * k)
	var chevron := 19.0 * k
	var stacked := size.x < 150.0 * k or (size.y >= 104.0 * k and size.x < size.y * 1.6)
	if stacked:
		# Großes Icon ragt über die obere linke Ecke, Titel darunter (Zielbild Hochformat).
		var icon_s := clampf(minf(size.x * 0.7, size.y * 0.48), 34.0 * k, 92.0 * k)
		var centre := Vector2(pad * 0.3 + icon_s * 0.5, icon_s * 0.27)
		ICONS.draw3d(self, icon_kind, centre, icon_s)
		var width := size.x - 2 * pad
		var tpx := _fit(font, title, roundi(minf(28.0 * k, size.y * 0.2)), width, min_px)
		var ty := centre.y + icon_s * 0.5 + tpx * 0.9
		_label(font, Vector2(pad, ty), title, tpx, Color.WHITE, 0.12)
		var bottom := size.y - lip - pad
		var cpx := roundi(12.5 * k)
		var room := floori((bottom - ty - cpx * 0.3) / (cpx * 1.18))
		if not compact:
			_caption(body, Vector2(pad, ty + cpx * 1.35), cpx, width - chevron - 2 * k, room, Color(1, 1, 1, 0.92))
		elif not short_caption.is_empty() and room >= 2:
			# Ein Wort, etwas näher am Rand, damit es auch auf 80 dp breiten Kacheln lesbar passt.
			var short_w := size.x - pad * 1.3
			var spx := _fit(body, short_caption, cpx, short_w, roundi(MIN_TEXT * k))
			if _fits(body, short_caption, spx, short_w):
				_label(body, Vector2(pad * 0.75, ty + spx * 1.4), short_caption, spx, Color(1, 1, 1, 0.92), 0.0, 0.35)
		if bottom - ty >= chevron * 0.9:
			ICONS.draw3d(self, "chevrons", Vector2(size.x - pad - chevron * 0.5, bottom - chevron * 0.42), chevron)
		return
	# Breite, flache Kachel: Icon links, Titel und Untertitel daneben, Pfeile rechts.
	var icon_h := clampf(size.y * 0.74, 30.0 * k, 100.0 * k)
	var mid := (size.y - lip) * 0.5
	var show_chevron := size.x >= 190.0 * k
	var right := size.x - pad - (chevron + 4 * k if show_chevron else 0.0)
	var left := pad * 0.5 + icon_h + 5 * k
	if not _fits(font, title, min_px, right - left):
		icon_h = minf(icon_h, 28.0 * k)
		left = pad * 0.5 + icon_h + 4 * k
	ICONS.draw3d(self, icon_kind, Vector2(pad * 0.5 + icon_h * 0.5, mid - icon_h * 0.06), icon_h)
	var title_px := _fit(font, title, roundi(minf(34.0 * k, size.y * 0.3)), right - left, min_px)
	var caption_px := roundi(minf(14.0 * k, maxf(12.0 * k, size.y * 0.11)))
	var lines := 0
	if not compact and size.y >= 64.0 * k and not caption.is_empty():
		lines = _wrap(body, caption, caption_px, right - left).size()
		if lines > (2 if size.y >= 96.0 * k else 1):
			lines = 0
	var base := mid + title_px * 0.34 - caption_px * 0.62 * lines
	_label(font, Vector2(left, base), title, title_px, Color.WHITE, 0.12)
	if lines > 0:
		_caption(body, Vector2(left, base + caption_px * 1.3), caption_px, right - left, lines, Color(1, 1, 1, 0.92))
	if show_chevron:
		ICONS.draw3d(self, "chevrons", Vector2(size.x - pad - chevron * 0.5, mid), chevron)


func _draw_art(box: Rect2) -> float:
	if art != null:
		var tex := art.get_size()
		var factor := minf(box.size.x / tex.x, box.size.y / tex.y)
		var drawn := tex * factor
		draw_texture_rect(art, Rect2(box.end - drawn, drawn), false, Color(1, 1, 1, 0.96))
		return drawn.x
	if not art_icon.is_empty():
		var s := minf(box.size.x, box.size.y)
		ICONS.draw3d(self, art_icon, box.end - Vector2(s, s) * 0.5, s)
		return s
	return 0.0


func _draw_feature(font: Font, body: Font, k: float) -> void:
	var pad := 10.0 * k
	var min_px := roundi(12.0 * k)
	var badge_room: float = 16.0 * k if badge else 0.0
	var caption_px := roundi(12.0 * k)
	var tint := Color.WHITE
	if size.x >= 150.0 * k and size.y >= 60.0 * k:
		# Breite Kachel: Icon und Titel oben, Untertitel links, Motiv rechts unten.
		var icon_s := minf(size.y * 0.36, 30.0 * k)
		ICONS.draw3d(self, icon_kind, Vector2(pad + icon_s * 0.5, pad + icon_s * 0.5), icon_s, accent.lightened(0.35))
		var left := pad * 1.5 + icon_s
		var tpx := _fit(font, title, roundi(21 * k), size.x - left - pad - badge_room, min_px)
		_label(font, Vector2(left, pad + icon_s * 0.5 + tpx * 0.36), title, tpx, tint, 0.1)
		var top := pad + icon_s + 3 * k
		var art_box := Rect2(Vector2(size.x * 0.5, top - 6 * k), Vector2(size.x * 0.5 - pad * 0.7, size.y - top + 6 * k - pad * 0.7))
		var art_w := 0.0
		if size.y >= 72.0 * k:
			art_w = _draw_art(art_box)
		if not compact:
			var room := floori((size.y - pad - top) / (caption_px * 1.18))
			_caption(body, Vector2(pad, top + caption_px), caption_px, size.x - 2 * pad - art_w - 4 * k, room, Color(1, 1, 1, 0.88))
		return
	if size.y >= 78.0 * k:
		# Schmale, hohe Kachel (Handy hoch): Icon oben, Titel darunter in voller Breite.
		var icon_s := minf(size.y * 0.34, 30.0 * k)
		ICONS.draw3d(self, icon_kind, Vector2(pad * 0.7 + icon_s * 0.5, pad * 0.7 + icon_s * 0.5), icon_s, accent.lightened(0.35))
		var width := size.x - 2 * pad
		var tpx := _fit(font, title, roundi(18 * k), width, min_px)
		var ty := pad * 0.7 + icon_s + tpx * 0.98
		_label(font, Vector2(pad, ty), title, tpx, tint, 0.1)
		if not compact:
			var small := roundi(MIN_TEXT * k)
			var room := floori((size.y - pad - ty) / (small * 1.18))
			_caption(body, Vector2(pad, ty + small * 1.3), small, width, room, Color(1, 1, 1, 0.88))
		return
	# Flache Kachel (Handy quer): Icon und Titel in einer Zeile.
	var icon_s := minf(size.y * 0.5, 26.0 * k)
	var left := pad * 0.8 + icon_s + 5 * k
	if not _fits(font, title, min_px, size.x - left - pad - badge_room):
		icon_s = 0.0
		left = pad
	if icon_s > 0.0:
		ICONS.draw3d(self, icon_kind, Vector2(pad * 0.8 + icon_s * 0.5, size.y * 0.5), icon_s, accent.lightened(0.35))
	var tpx := _fit(font, title, roundi(19 * k), size.x - left - pad - badge_room, min_px)
	_label(font, Vector2(left, size.y * 0.5 + tpx * 0.36), title, tpx, tint, 0.1)


func _draw_nav(body: Font, k: float) -> void:
	var show_label := size.y >= 52.0 * k
	var icon_s := minf(size.y * (0.5 if show_label else 0.66), 34.0 * k)
	var cy := size.y * (0.37 if show_label else 0.5)
	ICONS.draw3d(self, icon_kind, Vector2(size.x * 0.5, cy), icon_s, Color.WHITE if active else accent.lightened(0.45))
	if not show_label:
		return
	var min_px := roundi(MIN_TEXT * k)
	var width := size.x - 6 * k
	var shown := title
	if not short_title.is_empty() and not _fits(body, title, min_px, width):
		shown = short_title
	var px := _fit(body, shown, roundi(12.5 * k), width, min_px)
	var w := body.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_label(body, Vector2((size.x - w) * 0.5, size.y - 8 * k), shown, px, Color.WHITE, 0.0, 0.45)


func _draw_chip(font: Font, k: float) -> void:
	var has_text := not title.is_empty()
	var icon_s := minf(size.y * (0.56 if has_text else 0.62), 30.0 * k)
	var cx := size.x * 0.5 if not has_text else 9 * k + icon_s * 0.5
	if not icon_kind.is_empty():
		ICONS.draw3d(self, icon_kind, Vector2(cx, size.y * 0.5), icon_s, accent.lightened(0.4))
	if has_text:
		var left := (13 * k + icon_s) if not icon_kind.is_empty() else 10 * k
		var px := _fit(font, title, roundi(18 * k), size.x - left - 8 * k, roundi(12.0 * k))
		_label(font, Vector2(left, size.y * 0.5 + px * 0.36), title, px, Color.WHITE)


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


func _draw_thumb(font: Font, k: float, down: bool) -> void:
	var name := _plate_name()
	var framed := KIT.has(name)
	var inner := Rect2(Vector2(2, 2) * k, size - Vector2(4, 4) * k)
	var shade_tint := PRESSED_TINT if down else Color.WHITE
	if art != null:
		var tex := art.get_size()
		var factor := maxf(inner.size.x / tex.x, inner.size.y / tex.y)
		var src := inner.size / factor
		draw_texture_rect_region(art, inner, Rect2((tex - src) * 0.5, src), shade_tint)
	# Lesbarkeits-Verlauf unten, damit der Name auf jedem Bild klar bleibt.
	var big := size.y >= 110.0 * k
	var shade_h := minf(inner.size.y * 0.55, (56.0 if big else 34.0) * k)
	var shade := PackedVector2Array([Vector2(inner.position.x, inner.end.y - shade_h), Vector2(inner.end.x, inner.end.y - shade_h),
		inner.end, Vector2(inner.position.x, inner.end.y)])
	draw_polygon(shade, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.03, 0.1, 0.9), Color(0.01, 0.03, 0.1, 0.9)]))
	var play_s := 40.0 * k
	var min_px := roundi((13.0 if big else MIN_TEXT) * k)
	var label_w := inner.size.x - ((play_s + 14 * k) if big else 10 * k)
	var px := _fit(font, title, roundi((24 if big else 14) * k), label_w, min_px)
	if not label_hidden and _fits(font, title, px, label_w):
		_label(font, Vector2(inner.position.x + (8 if big else 5) * k, inner.end.y - (10 if big else 6) * k), title, px, Color.WHITE, 0.0, 0.7)
	if big:
		ICONS.draw3d(self, "play", Vector2(inner.end.x - play_s * 0.5 - 6 * k, inner.end.y - play_s * 0.5 - 6 * k), play_s)
	if framed:
		KIT.draw_plate(self, name, Rect2(Vector2.ZERO, size), k, shade_tint)
	else:
		var frame := _box(Color(0, 0, 0, 0), accent.lightened(0.2) if active else accent.darkened(0.2), 10.0 * k, (3.0 if active else 1.5) * k, 0.35 if active else 0.0)
		frame.draw_center = false
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
	if has_focus():
		draw_style_box(KIT.focus_ring(roundi(4.0 * k), roundi(2.0 * k)), Rect2(Vector2.ZERO, size).grow(-4 * k))
