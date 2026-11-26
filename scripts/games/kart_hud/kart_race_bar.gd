extends Control
## Upper race bar of Lumo Kart: lap with flag, place as a proud badge, speed as a tacho
## arc and collected stars. Drawn in one Control on top of the race HUD panel; it only
## shows the real values the race pushes in with show_values() - never sample numbers.
## The plain text label of the panel stays in place (tests and screen readers read it).

const KIT = preload("res://scripts/games/kart_ui3d.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const INK := Color("061430")
const CYAN := Color("6fe6ff")
const GOLD := Color("ffd23f")
const PLACE_TONES: Array[Color] = [Color("ffd23f"), Color("dfe8f8"), Color("ffad6a")]

## Values from the race: mode, lap, laps, place, field, speed (km/h), top (km/h),
## stars, time (s), score, title.
var values: Dictionary = {}
var reduced_motion: bool = false
## dp scale (pixels per dp), set by the layout.
var k: float = 1.0
var _shown_speed: float = 0.0
var _place_pop: float = 0.0
var _last_place: int = -1


func _init() -> void:
	name = "KartRaceBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func show_values(next: Dictionary, delta: float) -> void:
	var place: int = int(next.get("place", 0))
	if _last_place > 0 and place > 0 and place < _last_place and not reduced_motion:
		_place_pop = 1.0  # overtaken someone: the badge hops once
	_last_place = place
	_place_pop = maxf(0.0, _place_pop - delta / 0.45)
	var speed: float = float(next.get("speed", 0.0))
	_shown_speed = speed if reduced_motion or delta <= 0.0 else lerpf(_shown_speed, speed, minf(1.0, delta * 10.0))
	values = next
	queue_redraw()


func _text(text: String, at: Vector2, font_size: float, colour: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var px: int = maxi(8, roundi(font_size))
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		at.x -= _width(text, font_size) * 0.5
		align = HORIZONTAL_ALIGNMENT_LEFT
		width = -1.0
	var baseline: Vector2 = at + Vector2(0, (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5)
	draw_string_outline(FONT, baseline, text, align, width, px, maxi(2, roundi(px * 0.2)), Color(INK, 0.9))
	draw_string(FONT, baseline, text, align, width, px, colour)


func _width(text: String, font_size: float) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, roundi(font_size))).x


## Groups of the bar for the current mode: [kind, main text, small text].
func _groups() -> Array:
	var mode: String = str(values.get("mode", "race"))
	var lap: String = "%d/%d" % [int(values.get("lap", 1)), int(values.get("laps", 1))]
	var place: int = int(values.get("place", 0))
	var groups: Array = []
	match mode:
		"arena":
			var left: int = int(values.get("time", 0.0))
			groups = [["clock", "%d:%02d" % [left / 60, left % 60], ""], ["score", str(int(values.get("score", 0))), "TREFFER" if values.get("battle", false) else ""]]
			if place > 0:
				groups.append(["place", str(place), "/%d" % int(values.get("field", 6))])
		"training":
			groups = [["title", "TRAINING", ""], ["tacho", "", ""], ["stars", str(int(values.get("stars", 0))), ""]]
		"time_trial":
			groups = [["lap", lap, "RUNDE"], ["clock", "%.1f s" % float(values.get("time", 0.0)), ""], ["tacho", "", ""]]
		_:
			groups = [["lap", lap, "RUNDE"], ["place", str(place), "/%d" % int(values.get("field", 6))], ["tacho", "", ""], ["stars", str(int(values.get("stars", 0))), ""]]
	return groups


func _group_width(group: Array, h: float, words: bool) -> float:
	var main: float = h * 0.56
	match str(group[0]):
		"lap":
			return h * 0.78 + _width(str(group[1]), main) + (h * 0.12 + _width(str(group[2]), h * 0.3) if words else 0.0)
		"place":
			return h * 1.2 + _width(str(group[2]), h * 0.42)
		"tacho":
			return h * 1.5
		"stars", "score":
			return h * 0.82 + _width(str(group[1]), main)
		"clock":
			return h * 0.78 + _width(str(group[1]), main)
		_:
			return _width(str(group[1]), main * 0.9)


func _draw() -> void:
	if values.is_empty() or size.x < 40.0:
		return
	var h: float = size.y
	var groups: Array = _groups()
	var gap: float = h * 0.38
	var words: bool = true
	var total: float = 0.0
	for pass_index in range(2):
		total = gap * (groups.size() - 1)
		for group in groups:
			total += _group_width(group, h, words)
		if total <= size.x - h * 0.3:
			break
		words = false  # narrow bar: the flag alone says "lap"
	var shrink: float = minf(1.0, (size.x - h * 0.3) / maxf(total, 1.0))
	var unit: float = h * shrink
	var x: float = (size.x - total * shrink) * 0.5
	var mid: float = h * 0.5
	for group in groups:
		var w: float = _group_width(group, h, words) * shrink
		_draw_group(group, Rect2(x, 0, w, h), unit, mid, words)
		x += w + gap * shrink


func _draw_group(group: Array, area: Rect2, u: float, mid: float, words: bool) -> void:
	var main: float = u * 0.56
	var x: float = area.position.x
	match str(group[0]):
		"lap":
			if not KIT.draw_icon(self, "icon_flag", Vector2(x + u * 0.34, mid), u * 0.78):
				draw_rect(Rect2(x + u * 0.1, mid - u * 0.2, u * 0.4, u * 0.3), Color.WHITE)
			x += u * 0.74
			if words:
				_text(str(group[2]), Vector2(x, mid + u * 0.02), u * 0.3, Color("a9dcff"))
				x += _width(str(group[2]), u * 0.3) + u * 0.12
			_text(str(group[1]), Vector2(x, mid), main, Color.WHITE)
		"place":
			var place: int = int(group[1])
			var hop: float = sin(_place_pop * PI) * u * 0.12
			var badge_centre := Vector2(x + u * 0.56, mid - hop)
			var badge: String = "badge_place_%d" % place if place >= 1 and place <= 3 else "badge_place_other"
			# The badge stands a little taller than the bar: the place is the hero value.
			var drawn: bool = KIT.draw_icon(self, badge, badge_centre, u * 1.42)
			if not drawn or place > 3 or place < 1:
				if not drawn:
					draw_circle(badge_centre, u * 0.5, Color("17308a"))
				_text(str(place), badge_centre + Vector2(0, u * 0.02), u * 0.62, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
			var tone: Color = PLACE_TONES[place - 1] if place >= 1 and place <= 3 else Color("cfe6ff")
			_text(str(group[2]), Vector2(x + u * 1.16, mid + u * 0.06), u * 0.42, tone)
		"tacho":
			_draw_tacho(Vector2(x + area.size.x * 0.5, mid), u)
		"stars":
			if not KIT.draw_icon(self, "icon_star_gold", Vector2(x + u * 0.36, mid), u * 0.8):
				draw_circle(Vector2(x + u * 0.36, mid), u * 0.3, GOLD)
			_text(str(group[1]), Vector2(x + u * 0.8, mid), main, Color("fff3c4"))
		"score":
			if not KIT.draw_icon(self, "icon_star_crystal", Vector2(x + u * 0.36, mid), u * 0.8):
				draw_circle(Vector2(x + u * 0.36, mid), u * 0.3, CYAN)
			_text(str(group[1]), Vector2(x + u * 0.8, mid), main, Color("d8f8ff"))
		"clock":
			if not KIT.draw_icon(self, "icon_stopwatch", Vector2(x + u * 0.34, mid), u * 0.76):
				draw_arc(Vector2(x + u * 0.34, mid), u * 0.26, 0, TAU, 24, Color.WHITE, 3.0)
			_text(str(group[1]), Vector2(x + u * 0.74, mid), main, Color.WHITE)
		_:
			_text(str(group[1]), Vector2(x, mid), main * 0.9, Color.WHITE)


## Speed as a small tacho: a 240-degree arc that fills cyan -> gold toward top speed,
## needle and the real km/h value in the middle.
func _draw_tacho(centre: Vector2, u: float) -> void:
	var radius: float = u * 0.5
	var width: float = maxf(3.0, u * 0.12)
	var top: float = maxf(1.0, float(values.get("top", 1.0)))
	var ratio: float = clampf(_shown_speed / (top * 1.25), 0.0, 1.0)
	var start: float = PI * 0.83
	var sweep: float = PI * 1.34
	draw_circle(centre, radius + width * 0.75, Color(INK, 0.78))
	draw_arc(centre, radius, start, start + sweep, 40, Color("1b3358"), width, true)
	if ratio > 0.005:
		var segments: int = 12
		for i in range(segments):
			var a: float = float(i) / segments
			if a >= ratio:
				break
			var b: float = minf(ratio, float(i + 1) / segments)
			var colour: Color = CYAN.lerp(GOLD, clampf((a - 0.55) / 0.35, 0.0, 1.0))
			draw_arc(centre, radius, start + sweep * a, start + sweep * b + 0.01, 6, colour, width, true)
	var needle: Vector2 = Vector2.from_angle(start + sweep * ratio)
	draw_line(centre + needle * radius * 0.2, centre + needle * (radius + width * 0.2), Color("ff6a5a"), maxf(2.0, u * 0.05), true)
	_text(str(roundi(float(values.get("speed", 0.0)))), centre + Vector2(0, -u * 0.04), u * 0.36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
	_text("km/h", centre + Vector2(0, u * 0.3), u * 0.17, Color("a9dcff"), HORIZONTAL_ALIGNMENT_CENTER, 0.0)
	var gear_text: String = str(values.get("gear", ""))
	if not gear_text.is_empty():
		_text(gear_text, centre + Vector2(0, -u * 0.33), u * 0.20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
