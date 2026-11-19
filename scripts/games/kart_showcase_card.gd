extends Button
## Große bebilderte Auswahlkarte im Stil des Neon-Hauptmenüs (Fahrer, Tempo & Gegner).
## Alles wird selbst gezeichnet: Glasfläche mit Akzentkante, Bild oben, Name und bis zu
## drei kurze Aussagen darunter. Auswahl = dicker Akzentrahmen plus Haken-Plakette
## (Formsignal, nicht nur Farbe). Gesperrte Karten nennen die fehlenden Sterne.
const UI = preload("res://scripts/games/kart_ui_theme.gd")

var title := ""
var lines: PackedStringArray = PackedStringArray()
var art: Texture2D
var accent := Color("53ddfd")
var selected := false
var locked_text := ""
## 0 = kein Zeichen; 1–3 = Stufen-Pfeile (Tempo & Gegner) statt eines Bildes.
var chevrons := 0
var ui_scale := 1.0
## Anteil der Kartenhöhe für Bild/Zeichen (0 = kein Bildbereich).
var art_share := 0.58
var _press := 0.0


func _init() -> void:
	# Wie alle Auswahlkarten: ein Wischen auf der Karte scrollt die Liste.
	mouse_filter = Control.MOUSE_FILTER_PASS
	text = ""
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _ready() -> void:
	tooltip_text = title + (". " + " · ".join(lines) if not lines.is_empty() else "")
	button_down.connect(
		func():
			_press = 1.0
			queue_redraw()
	)
	button_up.connect(
		func():
			_press = 0.0
			queue_redraw()
	)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


## Gleiche Schnittstelle wie die übrigen Auswahlkarten des Menüs.
func apply_size(scale_factor: float, _compact: bool = false, _tight: bool = false) -> void:
	ui_scale = scale_factor
	queue_redraw()


func _draw() -> void:
	var k := maxf(ui_scale, 0.25)
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 8 or rect.size.y < 8:
		return
	var radius := roundi(18 * k)
	var panel := StyleBoxFlat.new()
	panel.set_corner_radius_all(radius)
	panel.bg_color = (
		Color(0.03, 0.11, 0.27, 0.95) if not disabled else Color(0.05, 0.08, 0.15, 0.94)
	)
	if selected:
		panel.bg_color = accent.darkened(0.62)
		panel.bg_color.a = 0.97
	panel.border_color = accent if selected else Color(accent.r, accent.g, accent.b, 0.45)
	if disabled:
		panel.border_color = Color("51647f")
	panel.set_border_width_all(maxi(1, roundi((4.0 if selected else 1.5) * k)))
	panel.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 if selected else 0.0)
	panel.shadow_size = roundi(10 * k) if selected else 0
	draw_style_box(panel, rect.grow(-2.0 * k))
	var inner := rect.grow(-10.0 * k)
	var art_h := inner.size.y * art_share if art_share > 0.0 else 0.0
	var art_rect := Rect2(inner.position, Vector2(inner.size.x, art_h))
	if art_h > 0.0:
		_draw_art(art_rect, k)
	# Text: Name groß, darunter bis zu drei Aussagen; alles passt sich der Breite an.
	var font: Font = UI.HEADING
	var body: Font = UI.BODY
	var y := art_rect.end.y + 6.0 * k
	var width := inner.size.x
	if art_h <= 0.0 and (selected or disabled):
		# Ohne Bild steht der Name neben der Haken-/Schloss-Plakette, nicht darunter.
		width -= 76.0 * k
	var title_px := _fit(font, title, width, 24.0 * k, 13.0 * k)
	if art_h <= 0.0:
		# Flache Karte: Name (und erste Zeile) senkrecht mittig.
		var block := font.get_height(title_px)
		if not lines.is_empty() or not locked_text.is_empty():
			block += UI.BODY.get_height(roundi(15.0 * k)) + 3.0 * k
		y = inner.position.y + maxf(0.0, (inner.size.y - block) * 0.5)
	y += font.get_ascent(title_px)
	var title_x := (
		inner.position.x
		+ (width - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x) * 0.5
	)
	draw_string(
		font,
		Vector2(title_x, y),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		title_px,
		Color.WHITE if not disabled else Color("a9b9cf")
	)
	y += font.get_descent(title_px) + 3.0 * k
	var shown: PackedStringArray = (
		lines if locked_text.is_empty() else PackedStringArray([locked_text])
	)
	var line_px := 15.0 * k
	for line in shown:
		line_px = minf(line_px, _fit(body, line, width, 15.0 * k, 11.0 * k))
	var room := inner.end.y - y
	var line_h := body.get_height(line_px) + 2.0 * k
	for index in range(shown.size()):
		if line_h * (index + 1) > room + 1.0:
			break
		var line: String = shown[index]
		var line_w := body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_px).x
		var color := Color("e7f2ff") if locked_text.is_empty() else Color("ffd56a")
		draw_string(
			body,
			Vector2(inner.position.x + (width - line_w) * 0.5, y + body.get_ascent(line_px)),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			line_px,
			color
		)
		y += line_h
	if selected:
		_draw_selected_badge(rect, k)
	elif disabled:
		_draw_lock(Vector2(rect.end.x - 26.0 * k, rect.position.y + 26.0 * k), k)
	if is_hovered() and not disabled:
		draw_rect(rect.grow(-4.0 * k), Color(1, 1, 1, 0.05 + _press * 0.06))


func _fit(font: Font, value: String, width: float, largest: float, smallest: float) -> int:
	var px := largest
	while (
		px > smallest
		and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x > width
	):
		px -= 1.0
	return roundi(px)


func _draw_art(area: Rect2, k: float) -> void:
	var plate := StyleBoxFlat.new()
	plate.set_corner_radius_all(roundi(12 * k))
	plate.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.45, 0.9)
	plate.bg_color = plate.bg_color.lerp(Color("071a45"), 0.4)
	draw_style_box(plate, area)
	if art != null:
		var tex := Vector2(art.get_size())
		var fit := minf(area.size.x / tex.x, area.size.y / tex.y)
		var drawn := tex * fit
		var at := area.position + (area.size - drawn) * Vector2(0.5, 1.0)
		var tint := Color.WHITE if not disabled else Color(0.45, 0.52, 0.62)
		draw_texture_rect(art, Rect2(at, drawn), false, tint)
	elif chevrons > 0:
		_draw_chevrons(area, k)


## Stufen-Zeichen: 1 bis 3 Pfeile in der Akzentfarbe, die übrigen blass.
func _draw_chevrons(area: Rect2, _k: float) -> void:
	var h := area.size.y * 0.56
	var w := h * 0.62
	var gap := w * 0.18
	var total := w * 3.0 + gap * 2.0
	var x0 := area.position.x + (area.size.x - total) * 0.5
	var cy := area.position.y + area.size.y * 0.5
	for index in range(3):
		var x := x0 + index * (w + gap)
		var lit := index < chevrons
		var color := accent.lightened(0.25) if lit else Color(1, 1, 1, 0.16)
		var t := w * 0.42
		var points := PackedVector2Array(
			[
				Vector2(x, cy - h * 0.5),
				Vector2(x + t, cy - h * 0.5),
				Vector2(x + w, cy),
				Vector2(x + t, cy + h * 0.5),
				Vector2(x, cy + h * 0.5),
				Vector2(x + w - t, cy),
			]
		)
		draw_colored_polygon(points, color)


func _draw_selected_badge(rect: Rect2, k: float) -> void:
	var r := 15.0 * k
	var c := Vector2(rect.end.x - r - 8.0 * k, rect.position.y + r + 8.0 * k)
	draw_circle(c, r + 2.0 * k, Color("0a1f3d"))
	draw_circle(c, r, accent.lightened(0.15))
	var tick := PackedVector2Array(
		[c + Vector2(-7, 0) * k, c + Vector2(-2, 5) * k, c + Vector2(7, -6) * k]
	)
	draw_polyline(tick, Color("06203a"), 3.4 * k, true)


func _draw_lock(c: Vector2, k: float) -> void:
	draw_circle(c, 16.0 * k, Color(0.02, 0.06, 0.14, 0.92))
	draw_rect(Rect2(c + Vector2(-7, -1) * k, Vector2(14, 10) * k), Color("ffd56a"))
	draw_arc(c + Vector2(0, -2) * k, 5.0 * k, PI, TAU, 12, Color("ffd56a"), 2.4 * k, true)
