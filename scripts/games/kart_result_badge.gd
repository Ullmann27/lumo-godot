extends Control
## Platz-Abzeichen des Zieleinlaufs: große Zahl mit „PLATZ“, Lorbeer, Karoband
## und Krone (nur Platz 1). Gold, Silber, Bronze für 1–3, sonst Stahlblau.
## Alles skaliert mit der Größe des Knotens. Eine Textur „badge_<stufe>“ aus
## kart_result_kit.gd ersetzt Band, Lorbeer und Krone; Zahl und Wort bleiben Text.
const KIT = preload("res://scripts/games/kart_result_kit.gd")
const DESIGN := Vector2(520, 168)
var place: int = 1
var ranked: bool = true
## Ohne Rang (Training, Zeitfahren, Arena) steht hier die Überschrift.
var title: String = ""
var subline: String = ""
var reduced_motion: bool = false
var appear: float = 1.0:
	set(value):
		appear = value
		modulate.a = clampf(appear * 2.0, 0.0, 1.0)
		_refresh()
var _phase: float = 0.0
var _numeral_face: Control
var _word_face: Control
var _top: Control
var _appear_tween: Tween


## Lesbarer Inhalt des Abzeichens (für Tests und Vorlesehilfen).
var text: String:
	get:
		if not ranked:
			return title
		return "%d. PLATZ%s" % [place, (" " + subline) if subline != "" else ""]


func _init() -> void:
	name = "ResultTitle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 150)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_numeral_face = _layer(_draw_numeral_face)
	_word_face = _layer(_draw_word_face)
	_top = _layer(_draw_top)
	resized.connect(_refresh)


func _layer(callback: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(callback)
	add_child(layer)
	return layer


func _ready() -> void:
	tooltip_text = text
	set_process(not reduced_motion)
	_refresh()


func apply_result_scale(factor: float, _dp: float) -> void:
	custom_minimum_size.y = 150.0 * factor


func result_height(_width: float) -> float:
	return custom_minimum_size.y


## Kurzes Aufploppen beim Erscheinen; bei ruhiger Bewegung steht es sofort.
func play_in() -> void:
	if is_instance_valid(_appear_tween):
		_appear_tween.kill()
	if reduced_motion or not is_inside_tree():
		appear = 1.0
		return
	appear = 0.0
	_appear_tween = create_tween()
	_appear_tween.tween_property(self, "appear", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if reduced_motion:
		set_process(false)
		return
	_phase += delta
	_top.queue_redraw()


func _refresh() -> void:
	queue_redraw()
	for layer in [_numeral_face, _word_face, _top]:
		if is_instance_valid(layer):
			layer.queue_redraw()


func _colors() -> Dictionary:
	return KIT.tier(place, ranked)


func _factor() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y) * lerpf(0.7, 1.0, clampf(appear, 0.0, 1.2))


func _point(x: float, y: float) -> Vector2:
	var f: float = _factor()
	return size * 0.5 + (Vector2(x, y) - DESIGN * 0.5) * f


func _numeral_spec() -> Dictionary:
	var f: float = _factor()
	var font_size: int = maxi(8, roundi(158.0 * f))
	var font: Font = KIT.display_font()
	var value: String = str(place)
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return {
		"text": value, "size": font_size,
		"position": _point(128, 156) - Vector2(width * 0.5, 0),
		"top": _point(0, 42).y, "bottom": _point(0, 158).y
	}


## „PLATZ“ bzw. die Überschrift ohne Rang; lange Titel brechen einmal um.
func _word_spec() -> Dictionary:
	var f: float = _factor()
	var font: Font = KIT.display_font()
	var left: float = 226.0
	var room: float = (442.0 - left) * f
	var lines: PackedStringArray = ["PLATZ"]
	var font_size: int = maxi(6, roundi(66.0 * f))
	var baseline: float = 124.0 if subline != "" else 132.0
	if not ranked:
		lines = [title]
		room = (486.0 - left) * f
		if title.length() > 12 and title.contains(" "):
			var cut: int = title.find(" ", title.length() / 2 - 2)
			if cut < 0:
				cut = title.rfind(" ")
			lines = [title.substr(0, cut), title.substr(cut + 1)]
		font_size = maxi(6, roundi((56.0 if lines.size() == 1 else 40.0) * f))
		baseline = 124.0 if lines.size() == 1 else 100.0
	var widest: float = 1.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if widest > room:
		font_size = maxi(6, floori(font_size * room / widest))
	var line_height: float = font_size * 1.08
	return {
		"lines": lines, "size": font_size, "left": _point(left, 0).x,
		"baseline": _point(0, baseline).y, "line_height": line_height,
		"top": _point(0, baseline).y - font_size * 0.74,
		"bottom": _point(0, baseline).y + line_height * float(lines.size() - 1) + font_size * 0.04
	}


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var f: float = _factor()
	var colors: Dictionary = _colors()
	var plate: Texture2D = KIT.texture("badge_" + KIT.tier_name(place, ranked))
	if plate != null:
		draw_texture_rect(plate, Rect2(_point(0, 0), DESIGN * f), false)
	else:
		_draw_ribbon(f)
		_draw_laurel(f, colors)
	if ranked:
		var numeral: Dictionary = _numeral_spec()
		_draw_glow(_point(128, 100), 86.0 * f, colors.glow)
		_extrude(numeral.text, numeral.position, numeral.size, colors, 9.0 * f)
	else:
		_draw_glow(_point(128, 100), 80.0 * f, KIT.TIERS.gold.glow)
	var word: Dictionary = _word_spec()
	for index in range(word.lines.size()):
		_extrude(
			word.lines[index], Vector2(word.left, word.baseline + word.line_height * index),
			word.size, colors, 5.0 * f
		)
	if subline != "":
		var sub_size: int = maxi(6, roundi(23.0 * f))
		var at: Vector2 = _point(230, 149)
		draw_string_outline(KIT.UI.HEADING, at, subline, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, maxi(1, roundi(4.0 * f)), Color(0.0, 0.04, 0.14, 0.9))
		draw_string(KIT.UI.HEADING, at, subline, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color("d7f1ff"))
	_metal(_numeral_face, colors, _numeral_spec().top, _numeral_spec().bottom)
	_metal(_word_face, colors, word.top, word.bottom)


func _metal(layer: Control, colors: Dictionary, top: float, bottom: float) -> void:
	if layer.material == null:
		layer.material = KIT.metal_material(colors, top, bottom)
	layer.material.set_shader_parameter("y_top", top)
	layer.material.set_shader_parameter("y_bottom", bottom)


func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for step in range(6):
		var t: float = float(step) / 5.0
		draw_circle(center, radius * (1.0 - t * 0.55), Color(color.r, color.g, color.b, 0.035 + t * 0.03))


func _extrude(value: String, at: Vector2, font_size: int, colors: Dictionary, depth: float) -> void:
	var font: Font = KIT.display_font()
	var rim: int = maxi(1, roundi(font_size * 0.045))
	draw_string_outline(
		font, at + Vector2(depth * 0.5, depth * 1.9), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		rim * 3, Color(0.0, 0.015, 0.07, 0.42)
	)
	var steps: int = maxi(2, ceili(depth))
	for step in range(steps, 0, -1):
		var offset := Vector2(0.45, 1.0) * depth * float(step) / float(steps)
		var shade: Color = (colors.deep as Color).lerp(colors.dark, 1.0 - float(step) / float(steps))
		draw_string_outline(font, at + offset, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, rim, shade)
		draw_string(font, at + offset, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shade)
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, rim, colors.deep)


func _draw_numeral_face() -> void:
	if not ranked or size.x <= 1.0:
		return
	var numeral: Dictionary = _numeral_spec()
	_numeral_face.draw_string(
		KIT.display_font(), numeral.position, numeral.text, HORIZONTAL_ALIGNMENT_LEFT, -1, numeral.size
	)


func _draw_word_face() -> void:
	if size.x <= 1.0:
		return
	var word: Dictionary = _word_spec()
	for index in range(word.lines.size()):
		_word_face.draw_string(
			KIT.display_font(), Vector2(word.left, word.baseline + word.line_height * index),
			word.lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, word.size
		)


## Schräges Rennband mit Karo-Enden, Verlauf, Glanzkante und Neonlinien.
func _draw_ribbon(f: float) -> void:
	var top: float = 60.0
	var bottom: float = 152.0
	var lean: float = 16.0
	var shape := PackedVector2Array([
		_point(4 + lean, top), _point(516 + lean, top), _point(516 - lean, bottom), _point(4 - lean, bottom)
	])
	var shadow := PackedVector2Array()
	for corner in shape:
		shadow.append(corner + Vector2(0, 9.0 * f))
	draw_colored_polygon(shadow, Color(0.0, 0.015, 0.07, 0.42))
	draw_polygon(shape, PackedColorArray([
		Color("1d55b0"), Color("163f8f"), Color("050f2c"), Color("081a44")
	]))
	var cell: float = (bottom - top) / 4.0
	for side in [-1.0, 1.0]:
		for column in range(4):
			for row in range(4):
				if (row + column) % 2 == 1:
					continue
				var fade: float = 1.0 - float(column) / 4.0
				var y0: float = top + row * cell
				var skew0: float = lean * (1.0 - 2.0 * (y0 - top) / (bottom - top))
				var skew1: float = lean * (1.0 - 2.0 * (y0 + cell - top) / (bottom - top))
				var x0: float = (4.0 + column * cell) if side < 0 else (516.0 - (column + 1) * cell)
				draw_colored_polygon(PackedVector2Array([
					_point(x0 + skew0, y0), _point(x0 + cell + skew0, y0),
					_point(x0 + cell + skew1, y0 + cell), _point(x0 + skew1, y0 + cell)
				]), Color(0.36, 0.72, 1.0, 0.78 * fade))
	draw_polygon(PackedVector2Array([
		shape[0], shape[1], _point(516 + lean * 0.55, top + 20), _point(4 + lean * 0.55, top + 20)
	]), PackedColorArray([
		Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)
	]))
	var edge: float = maxf(1.5, 3.0 * f)
	draw_line(shape[0], shape[1], Color("7fe6ff"), edge, true)
	draw_line(shape[3], shape[2], Color("2f8dff"), edge, true)
	draw_line(shape[0] + Vector2(0, edge * 1.4), shape[1] + Vector2(0, edge * 1.4), Color(0.5, 0.9, 1.0, 0.25), edge * 2.0, true)


func _leaf(base: Vector2, angle: float, length: float, width: float, colors: Dictionary) -> void:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var outline := PackedVector2Array()
	var upper := PackedVector2Array()
	var steps: int = 7
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		outline.append(base + along * length * t + across * sin(t * PI) * width * 0.5)
	upper = outline.duplicate()
	for step in range(steps, -1, -1):
		var t: float = float(step) / float(steps)
		outline.append(base + along * length * t - across * sin(t * PI) * width * 0.5)
		upper.append(base + along * length * t)
	var drop := PackedVector2Array()
	for corner in outline:
		drop.append(corner + Vector2(length * 0.04, length * 0.1))
	draw_colored_polygon(drop, Color(0.0, 0.02, 0.08, 0.38))
	draw_colored_polygon(outline, (colors.dark as Color).lerp(colors.mid, 0.25))
	draw_colored_polygon(upper, (colors.mid as Color).lerp(colors.light, 0.35))
	draw_line(base, base + along * length, colors.deep, maxf(1.0, width * 0.09), true)


func _draw_laurel(f: float, colors: Dictionary) -> void:
	var center: Vector2 = _point(128, 98)
	var radius: float = 78.0 * f
	for side in [-1.0, 1.0]:
		var stem := PackedVector2Array()
		for index in range(9):
			var a: float = deg_to_rad(lerpf(14.0, 138.0, float(index) / 8.0))
			stem.append(center + Vector2(side * sin(a), cos(a)) * radius)
		draw_polyline(stem, colors.deep, maxf(1.5, 4.0 * f), true)
		draw_polyline(stem, colors.dark, maxf(1.0, 2.2 * f), true)
		for index in range(7):
			var a: float = deg_to_rad(lerpf(20.0, 132.0, float(index) / 6.0))
			var base: Vector2 = center + Vector2(side * sin(a), cos(a)) * radius
			var tangent: float = Vector2(side * cos(a), -sin(a)).angle()
			var size_scale: float = lerpf(1.0, 0.72, float(index) / 6.0)
			_leaf(base, tangent + side * 0.62, 27.0 * f * size_scale, 13.0 * f * size_scale, colors)
			_leaf(base, tangent - side * 0.5, 22.0 * f * size_scale, 11.0 * f * size_scale, colors)


func _draw_crown(f: float) -> void:
	var gold: Dictionary = KIT.TIERS.gold
	var c: Vector2 = _point(110, 26)
	var u: float = 30.0 * f
	var tilt: float = -0.14
	var body := PackedVector2Array()
	for corner in [
		Vector2(-1.0, 0.45), Vector2(-1.25, -0.5), Vector2(-0.55, 0.0), Vector2(0.0, -0.85),
		Vector2(0.55, 0.0), Vector2(1.25, -0.5), Vector2(1.0, 0.45)
	]:
		body.append(c + (corner * u).rotated(tilt))
	var drop := PackedVector2Array()
	for corner in body:
		drop.append(corner + Vector2(u * 0.08, u * 0.2))
	_top.draw_colored_polygon(drop, gold.deep)
	_top.draw_colored_polygon(body, gold.mid)
	_top.draw_colored_polygon(PackedVector2Array([body[0], body[1], body[2], c + (Vector2(-0.5, 0.45) * u).rotated(tilt)]), gold.light)
	_top.draw_polyline(body + PackedVector2Array([body[0]]), gold.deep, maxf(1.0, 1.6 * f), true)
	var band := PackedVector2Array()
	for corner in [Vector2(-1.0, 0.45), Vector2(1.0, 0.45), Vector2(0.96, 0.75), Vector2(-0.96, 0.75)]:
		band.append(c + (corner * u).rotated(tilt))
	_top.draw_colored_polygon(band, gold.dark)
	for tip in [Vector2(-1.25, -0.5), Vector2(0.0, -0.85), Vector2(1.25, -0.5)]:
		_top.draw_circle(c + (tip * u).rotated(tilt), u * 0.14, gold.light)
	for gem in [Vector2(-0.5, 0.6), Vector2(0.0, 0.6), Vector2(0.5, 0.6)]:
		_top.draw_circle(c + (gem * u).rotated(tilt), u * 0.1, Color("4fd8ff") if gem.x == 0.0 else Color("ff5d7a"))


func _sparkle(at: Vector2, radius: float, strength: float) -> void:
	var color := Color(1, 1, 1, clampf(strength, 0.0, 1.0))
	var thin: float = radius * 0.16
	_top.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -radius), at + Vector2(thin, -thin), at + Vector2(radius, 0), at + Vector2(thin, thin),
		at + Vector2(0, radius), at + Vector2(-thin, thin), at + Vector2(-radius, 0), at + Vector2(-thin, -thin)
	]), color)


func _draw_top() -> void:
	if size.x <= 1.0:
		return
	var f: float = _factor()
	if ranked and place == 1 and KIT.texture("badge_gold") == null:
		_draw_crown(f)
	if not ranked:
		KIT.draw_star(_top, _point(128, 100), 50.0 * f)
	var glints: Array = [Vector2(168, 52), Vector2(98, 138), Vector2(430, 78)]
	if not ranked or place > 3:
		glints = [Vector2(168, 52), Vector2(430, 78)]
	for index in range(glints.size()):
		var strength: float = 0.9 if reduced_motion else 0.62 + 0.38 * sin(_phase * 2.6 + float(index) * 2.1)
		_sparkle(_point(glints[index].x, glints[index].y), (9.0 + 3.0 * strength) * f, strength)
