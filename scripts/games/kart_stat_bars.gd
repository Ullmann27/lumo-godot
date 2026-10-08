extends Control
## Fünf Wertebalken (Tempo, Beschleunigung, Bremsen, Handling, Turbo) für Auswahl und Werkstatt.
## Grundwert in Türkis, Tuning-Anteil in Gold. Balken laufen sanft zum neuen Wert.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const BASE_COLOR := Color("5fe3ff")
const BONUS_COLOR := Color("ffc94a")
const TRACK_COLOR := Color(0.07, 0.17, 0.30, 0.95)
## Zielwerte: Grundwert und Tuning-Anteil je Wert (0–12).
var base: Dictionary = {}
var bonus: Dictionary = {}
var show_labels: bool = true
var show_numbers: bool = true
var reduced_motion: bool = false
## Zeilenhöhe in Pixeln (bei Skalierung bereits eingerechnet).
var row_height: float = 34.0:
	set(value):
		row_height = value
		_update_minimum()
		queue_redraw()
var font_scale: float = 1.0:
	set(value):
		font_scale = value
		queue_redraw()
var _shown_base: Dictionary = {}
var _shown_bonus: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_minimum()


func set_values(new_base: Dictionary, new_bonus: Dictionary = {}, instant: bool = false) -> void:
	base = new_base.duplicate()
	bonus = new_bonus.duplicate()
	if instant or reduced_motion or _shown_base.is_empty():
		_shown_base = base.duplicate()
		_shown_bonus = bonus.duplicate()
	set_process(true)
	queue_redraw()


func _update_minimum() -> void:
	custom_minimum_size.y = row_height * FLEET.STATS.size()


func _process(delta: float) -> void:
	var moving: bool = false
	for key in FLEET.STATS:
		var goal_base: float = float(base.get(key, 0.0))
		var goal_bonus: float = float(bonus.get(key, 0.0))
		var now_base: float = float(_shown_base.get(key, goal_base))
		var now_bonus: float = float(_shown_bonus.get(key, goal_bonus))
		if absf(now_base - goal_base) > 0.005 or absf(now_bonus - goal_bonus) > 0.005:
			moving = true
			now_base = move_toward(now_base, goal_base, delta * 14.0)
			now_bonus = move_toward(now_bonus, goal_bonus, delta * 14.0)
		else:
			now_base = goal_base
			now_bonus = goal_bonus
		_shown_base[key] = now_base
		_shown_bonus[key] = now_bonus
	queue_redraw()
	if not moving:
		set_process(false)


func _draw() -> void:
	var rows: int = FLEET.STATS.size()
	var row: float = size.y / float(rows) if size.y > 0.0 else row_height
	var label_width: float = minf(size.x * 0.40, 168.0 * font_scale) if show_labels else 0.0
	var number_width: float = 74.0 * font_scale if show_numbers else 0.0
	var bar_left: float = label_width + (8.0 if show_labels else 0.0)
	var bar_width: float = maxf(20.0, size.x - bar_left - number_width - 4.0)
	var bar_height: float = clampf(row * 0.34, 5.0, 14.0)
	var font_size: int = clampi(roundi(row * 0.46), 10, 22)
	for index in range(rows):
		var key: String = FLEET.STATS[index]
		var top: float = float(index) * row
		var middle: float = top + row * 0.5
		var value_base: float = float(_shown_base.get(key, base.get(key, 0.0)))
		var value_bonus: float = float(_shown_bonus.get(key, bonus.get(key, 0.0)))
		if show_labels:
			var label: String = str(FLEET.STAT_NAMES[key])
			draw_string(UI.BODY, Vector2(0, middle + font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, label_width, font_size, Color("c4d8ee"))
		var track := Rect2(bar_left, middle - bar_height * 0.5, bar_width, bar_height)
		draw_rect(track, TRACK_COLOR, true)
		var base_width: float = bar_width * FLEET.bar(value_base)
		var bonus_width: float = bar_width * (FLEET.bar(value_base + value_bonus) - FLEET.bar(value_base))
		if base_width > 0.5:
			draw_rect(Rect2(track.position, Vector2(base_width, bar_height)), BASE_COLOR, true)
			draw_rect(Rect2(track.position, Vector2(base_width, bar_height * 0.42)), Color(1, 1, 1, 0.22), true)
		if bonus_width > 0.5:
			draw_rect(Rect2(track.position + Vector2(base_width, 0), Vector2(bonus_width, bar_height)), BONUS_COLOR, true)
			draw_rect(Rect2(track.position + Vector2(base_width, 0), Vector2(bonus_width, bar_height * 0.42)), Color(1, 1, 1, 0.28), true)
		# Skalenstriche bei 3, 6 und 9 helfen beim Vergleichen.
		for tick in [3.0, 6.0, 9.0]:
			var x: float = track.position.x + bar_width * FLEET.bar(tick)
			draw_line(Vector2(x, track.position.y), Vector2(x, track.end.y), Color(0.02, 0.07, 0.14, 0.55), 1.0)
		if show_numbers:
			var total: float = value_base + value_bonus
			var text: String = "%.1f" % total if value_bonus > 0.04 else "%d" % roundi(total) if is_equal_approx(total, roundf(total)) else "%.1f" % total
			draw_string(UI.HEADING, Vector2(size.x - number_width, middle + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_RIGHT, number_width, font_size, BONUS_COLOR if value_bonus > 0.04 else Color("f7fbff"))
