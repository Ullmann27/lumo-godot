class_name LumoKartItemHud
extends Control
## Item layer of the race HUD, drawn in one Control (cheap on phones):
##  - fighter-jet style lock-on: a seeker sweeps out, brackets close around the nearest
##    rival ahead, "ZIEL ERFASST" + tone; without a target "Kein Ziel – geradeaus"
##  - rear warning band when a rival has locked onto the player
##  - shield time bar, item slot icon with state ring and the short roulette
##  - a first-time pictogram hint (tap 1x = arm, tap 2x = fire) that needs no reading
## Nothing here blinks faster than 2.5 Hz; reduced motion keeps every cue steady.

const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const ROCKET_RED := Color("ff4f6d")
const LOCK_GOLD := Color("ffd23f")
const LOCK_RED := Color("ff3b5c")
const SHIELD_CYAN := Color("66e8ff")
const INK := Color("071428")
const ICON_ORDER: Array[String] = ["star_rocket", "shield", "boost", "spark_ball", "bubble_trap", "pulse", "star_magnet", "aurora", "triple_boost"]

var reduced_motion: bool = false
## "screen": lock-on, warning, shield bar and hint over the whole race view.
## "slot": only the item icon/state ring, as an overlay child of the item button.
var mode: String = "screen"
var camera: Camera3D
## Fed by the race every frame (see kart_island.gd _update_item_hud).
var state: Dictionary = {}
var seeker := Vector2.ZERO
var seeker_ready: bool = false
var _time: float = 0.0
var _last_target: int = -99


func _init() -> void:
	name = "KartItemHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func push_state(next_state: Dictionary, delta: float) -> void:
	state = next_state
	_time += delta
	var centre: Vector2 = _aim_centre()
	if str(state.get("phase", "")) != "armed":
		seeker = centre
		seeker_ready = false
		_last_target = -99
	else:
		var goal: Vector2 = centre
		var target_screen: Variant = _target_screen()
		if target_screen != null:
			goal = target_screen
		else:
			# Searching: the seeker wanders in a slow figure eight ahead of the kart.
			var wander: float = 0.0 if reduced_motion else 1.0
			goal = centre + Vector2(sin(_time * 1.6) * 0.12, sin(_time * 3.2) * 0.04) * size.x * wander
		var target_key: int = int(state.get("target", -99))
		if target_key != _last_target and seeker_ready:
			# Target switch: the seeker visibly jumps toward the new rival.
			seeker = seeker.lerp(goal, 0.35)
		_last_target = target_key
		var follow: float = 1.0 if reduced_motion else minf(1.0, delta * 9.0)
		seeker = goal if not seeker_ready else seeker.lerp(goal, follow)
		seeker_ready = true
	queue_redraw()


func _ui_scale() -> float:
	return clampf(minf(size.x, size.y) / 720.0, 0.6, 2.2)


func _aim_centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.42)


func _target_screen() -> Variant:
	if not bool(state.get("has_target", false)) or not is_instance_valid(camera):
		return null
	var world: Vector3 = state.get("target_world", Vector3.ZERO)
	if camera.is_position_behind(world):
		return null
	var point: Vector2 = camera.unproject_position(world)
	# Viewport and HUD share the root size; clamp into the visible field.
	return point.clamp(Vector2(40, 40), size - Vector2(40, 40))


func _draw() -> void:
	if state.is_empty():
		return
	if mode == "slot":
		_draw_item_slot(clampf(size.x / 112.0, 0.5, 2.5))
		return
	var s: float = _ui_scale()
	if str(state.get("phase", "")) == "armed" and float(state.get("rearm", 0.0)) <= 0.0:
		_draw_lock_on(s)
	if float(state.get("warning", 0.0)) > 0.0:
		_draw_rear_warning(s)
	if float(state.get("shield_left", 0.0)) > 0.0:
		_draw_shield_bar(s)
	if not str(state.get("hint", "")).is_empty():
		_draw_hint(s)
	_draw_popups(s)


func _draw_popups(s: float) -> void:
	if not is_instance_valid(camera):
		return
	for popup in state.get("popups", []):
		var world: Vector3 = popup.world
		if camera.is_position_behind(world):
			continue
		var age: float = float(popup.age)
		var rise: float = 0.0 if reduced_motion else age * 60.0 * s
		var pop: float = 1.0 if reduced_motion else minf(1.0, 0.6 + age * 4.0)
		var at: Vector2 = camera.unproject_position(world) - Vector2(0, rise)
		at = at.clamp(Vector2(120, 60) * s, size - Vector2(120, 60) * s)
		var colour: Color = popup.color
		colour.a = clampf((1.1 - age) * 3.0, 0.0, 1.0)
		_badge(str(popup.text), at, 34.0 * s * pop, colour)
		for k in range(5):
			var direction := Vector2.RIGHT.rotated(k * TAU / 5.0 - PI * 0.5)
			_small_star(at + direction * (70.0 + age * 40.0) * s, 9.0 * s, Color(LOCK_GOLD, colour.a))


func _small_star(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var r: float = radius if i % 2 == 0 else radius * 0.45
		points.append(centre + Vector2.RIGHT.rotated(-PI * 0.5 + i * PI / 5.0) * r)
	draw_colored_polygon(points, colour)


# --- lock-on ---------------------------------------------------------------------------


func _draw_lock_on(s: float) -> void:
	var progress: float = clampf(float(state.get("lock", 0.0)), 0.0, 1.0)
	var locked: bool = progress >= 1.0
	var has_target: bool = bool(state.get("has_target", false)) and _target_screen() != null
	var centre: Vector2 = _aim_centre()
	# Gun-sight in the middle: always shows where "geradeaus" is.
	var sight: Color = Color(1, 1, 1, 0.55)
	draw_arc(centre, 26.0 * s, 0, TAU, 40, sight, 2.5 * s, true)
	for k in range(4):
		var direction := Vector2.RIGHT.rotated(k * PI * 0.5)
		draw_line(centre + direction * 32.0 * s, centre + direction * 46.0 * s, sight, 3.0 * s, true)
	if not has_target:
		var search := Color(1, 1, 1, 0.85)
		draw_arc(seeker, 34.0 * s, _time * 2.0, _time * 2.0 + PI * 1.4, 30, search, 3.0 * s, true)
		_label("Kein Ziel – geradeaus", centre + Vector2(0, 92.0 * s), 26.0 * s, Color.WHITE)
		_arrow(centre + Vector2(0, -70.0 * s), Vector2.UP, 22.0 * s, Color(1, 1, 1, 0.8))
		return
	var colour: Color = LOCK_RED if locked else LOCK_GOLD.lerp(Color("ff8a3c"), progress)
	# Line from the sight to the seeker: "the rockets will fly there".
	draw_dashed_line(centre, seeker, Color(colour, 0.55), 2.5 * s, 12.0 * s)
	# Brackets close from wide to tight while the lock builds.
	var half: float = lerpf(120.0, 52.0, smoothstep(0.0, 1.0, progress)) * s
	var turn: float = 0.0 if reduced_motion else (1.0 - progress) * 0.6
	var corner: float = half * 0.42
	var width: float = (5.0 if locked else 4.0) * s
	for k in range(4):
		var diagonal := Vector2(1, 1).rotated(k * PI * 0.5 + turn)
		var tip: Vector2 = seeker + diagonal * half
		var along_a: Vector2 = Vector2(-diagonal.x, 0).normalized() * corner
		var along_b: Vector2 = Vector2(0, -diagonal.y).normalized() * corner
		draw_polyline(PackedVector2Array([tip + along_a, tip, tip + along_b]), INK, width + 4.0 * s, true)
		draw_polyline(PackedVector2Array([tip + along_a, tip, tip + along_b]), colour, width, true)
	# Progress ring around the target.
	draw_arc(seeker, half * 0.62, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(colour, 0.9), 5.0 * s, true)
	if locked:
		var pulse: float = 1.0 if reduced_motion else 0.85 + 0.15 * sin(_time * TAU * 1.5)
		var diamond: float = 16.0 * s * pulse
		var points := PackedVector2Array([
			seeker + Vector2(0, -diamond), seeker + Vector2(diamond, 0), seeker + Vector2(0, diamond), seeker + Vector2(-diamond, 0),
		])
		draw_colored_polygon(points, Color(LOCK_RED, 0.85))
		draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.5 * s, true)
		_badge("ZIEL ERFASST!", seeker + Vector2(0, -half - 30.0 * s), 30.0 * s, LOCK_RED)
	else:
		_badge("ERFASSE …", seeker + Vector2(0, -half - 26.0 * s), 24.0 * s, Color("e09a1a"))
	var who: String = str(state.get("target_name", ""))
	if not who.is_empty():
		_label(who, seeker + Vector2(0, half + 30.0 * s), 24.0 * s, Color.WHITE)


# --- warning, shield, item slot ----------------------------------------------------------


func _draw_rear_warning(s: float) -> void:
	var level: float = clampf(float(state.get("warning", 0.0)), 0.0, 1.0)
	var incoming: bool = bool(state.get("incoming", false))
	# 2 Hz breathing (well below 3 Hz); steady in reduced motion.
	var wave: float = 1.0 if reduced_motion else 0.62 + 0.38 * (sin(_time * TAU * 2.0) * 0.5 + 0.5)
	var band_height: float = 26.0 * s
	var band := Rect2(Vector2(0, size.y - band_height), Vector2(size.x, band_height))
	draw_rect(band, Color(LOCK_RED, 0.55 * level * wave))
	# Glow along both lower corners: "danger from behind".
	for side in [-1.0, 1.0]:
		var x: float = size.x * 0.5 + side * size.x * 0.5
		draw_circle(Vector2(x, size.y), 140.0 * s, Color(LOCK_RED, 0.18 * level * wave))
	var centre := Vector2(size.x * 0.5, size.y * 0.29)
	var text: String = "RAKETE KOMMT!" if incoming else "ACHTUNG – DU BIST ERFASST!"
	_badge(text, centre, 30.0 * s, Color(LOCK_RED, 0.95))
	# Chevrons pointing up from the bottom edge = "it comes from behind you".
	for k in range(3):
		var y: float = size.y - band_height - 18.0 * s - k * 26.0 * s
		var alpha: float = level * (1.0 if reduced_motion else clampf(wave * 1.4 - k * 0.25, 0.25, 1.0))
		_arrow(Vector2(size.x * 0.5, y), Vector2.UP, 30.0 * s, Color(1, 0.35, 0.45, alpha))
	# Little rocket on the bottom edge: "es kommt von hinten".
	var marker := Vector2(size.x * 0.5, size.y - band_height * 0.5)
	draw_circle(marker, 22.0 * s, Color(INK, 0.85 * level))
	_rocket_icon(marker + Vector2(0, 2.0 * s), 34.0 * s, level)
	if bool(state.get("shield_ready", false)):
		var rect: Rect2 = state.get("item_rect", Rect2())
		if rect.size.x > 0.0:
			var tip: Vector2 = rect.get_center() + Vector2(0, -rect.size.y * 0.62)
			_badge("SCHILD!", tip + Vector2(0, -34.0 * s), 26.0 * s, Color("1aa3c4"))
			_arrow(tip, Vector2.DOWN, 18.0 * s, SHIELD_CYAN)


func _draw_shield_bar(s: float) -> void:
	var left: float = float(state.get("shield_left", 0.0))
	var total: float = maxf(0.1, float(state.get("shield_total", 6.0)))
	var width: float = 230.0 * s
	var origin := Vector2(size.x * 0.5 - width * 0.5, size.y * 0.17)
	var bar := Rect2(origin + Vector2(44.0 * s, 0), Vector2(width - 44.0 * s, 20.0 * s))
	draw_rect(bar.grow(3.0 * s), Color(INK, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(left / total, 0.0, 1.0), bar.size.y)), SHIELD_CYAN)
	_icon("shield", origin + Vector2(18.0 * s, 10.0 * s), 22.0 * s, 1.0)
	_label("%d" % ceili(left), bar.get_center() + Vector2(0, 1), 18.0 * s, INK)


func _draw_item_slot(s: float) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size) if mode == "slot" else state.get("item_rect", Rect2())
	if rect.size.x <= 0.0:
		return
	var centre: Vector2 = rect.get_center()
	var radius: float = rect.size.x * 0.5
	var item_id: String = str(state.get("item", ""))
	var phase: String = str(state.get("phase", ""))
	var roulette: float = float(state.get("roulette", 0.0))
	if roulette > 0.0:
		# Short slot-machine wheel: icons tick past, slowing down, then the result pops.
		var ticks: float = pow(roulette, 1.6) * 14.0
		var index: int = int(ticks) % ICON_ORDER.size()
		draw_circle(centre, radius * 0.86, Color("0d2440"))
		draw_arc(centre, radius * 0.9, 0, TAU, 48, LOCK_GOLD, 5.0 * s, true)
		var offset: float = 0.0 if reduced_motion else fmod(ticks, 1.0) * radius * 0.6
		_icon(ICON_ORDER[index], centre + Vector2(0, offset - radius * 0.1), radius * 0.48, 1.0)
		_label("?", centre + Vector2(radius * 0.62, -radius * 0.62), 30.0 * s, LOCK_GOLD)
		return
	if item_id.is_empty():
		return
	var colour: Color = Color(str(state.get("item_color", "#ffffff")))
	var ring: Color = colour
	var caption: String = ""
	match phase:
		"armed":
			ring = LOCK_RED
			caption = "FEUER!"
		"ready":
			caption = "TIPPEN" if item_id == "star_rocket" else ""
	var breathe: float = 1.0 if reduced_motion else 0.8 + 0.2 * sin(_time * TAU * (1.4 if phase == "armed" else 0.8))
	draw_arc(centre, radius * 1.02, 0, TAU, 56, Color(ring, 0.95 * breathe), 7.0 * s, true)
	if phase == "armed":
		var lock: float = clampf(float(state.get("lock", 0.0)), 0.0, 1.0)
		draw_arc(centre, radius * 1.13, -PI * 0.5, -PI * 0.5 + TAU * lock, 56, LOCK_GOLD, 6.0 * s, true)
	draw_circle(centre + Vector2(0, -radius * 0.08), radius * 0.5, Color(INK, 0.82))
	_icon(item_id, centre + Vector2(0, -radius * 0.08), radius * 0.42, 1.0)
	var charges: int = int(state.get("charges", 0))
	if charges > 1 or item_id == "star_rocket":
		var badge_at: Vector2 = centre + Vector2(radius * 0.72, -radius * 0.72)
		draw_circle(badge_at, 17.0 * s, INK)
		draw_arc(badge_at, 17.0 * s, 0, TAU, 24, colour, 3.0 * s, true)
		_label("×%d" % maxi(charges, 1), badge_at + Vector2(0, 1), 18.0 * s, Color.WHITE)
	if not caption.is_empty():
		_badge(caption, centre + Vector2(0, -radius - 26.0 * s), 24.0 * s, LOCK_RED if phase == "armed" else Color("1d6fd1"))


# --- first-time hint ---------------------------------------------------------------------


func _draw_hint(s: float) -> void:
	var rect: Rect2 = state.get("item_rect", Rect2())
	if rect.size.x <= 0.0:
		return
	var hint: String = str(state.get("hint", ""))
	var steps: Array = [["1", "lock"], ["2", "fire"]] if hint == "star_rocket" else [["1", hint]]
	var cell: float = 92.0 * s
	var width: float = cell * (steps.size() * 2) + 24.0 * s
	# Centre of the road view, above the kart: never on top of a button.
	var origin := Vector2(size.x * 0.5 - width * 0.5, size.y * 0.30)
	var panel := Rect2(origin, Vector2(width, cell + 24.0 * s))
	draw_rect(panel, Color(INK, 0.82))
	draw_rect(panel, Color(LOCK_GOLD, 0.9), false, 3.0 * s)
	var tap: float = 0.0 if reduced_motion else absf(sin(_time * PI * 1.2))
	for i in range(steps.size()):
		var at: Vector2 = origin + Vector2(12.0 * s + cell * (i * 2 + 0.5), 12.0 * s + cell * 0.5)
		# A finger tapping the round item button, with the tap count.
		draw_circle(at, cell * 0.34, Color("1d3d66"))
		draw_arc(at, cell * 0.34 + tap * 6.0 * s, 0, TAU, 32, Color(1, 1, 1, 0.8 - tap * 0.4), 3.0 * s, true)
		_finger(at + Vector2(cell * 0.12, cell * 0.12 - tap * 8.0 * s), cell * 0.22)
		_label(str(steps[i][0]) + "×", at + Vector2(-cell * 0.30, -cell * 0.32), 24.0 * s, LOCK_GOLD)
		_arrow(at + Vector2(cell * 0.62, 0), Vector2.RIGHT, 14.0 * s, Color.WHITE)
		var result_at: Vector2 = at + Vector2(cell, 0)
		match str(steps[i][1]):
			"lock":
				draw_arc(result_at, cell * 0.28, 0, TAU, 32, LOCK_RED, 4.0 * s, true)
				for k in range(4):
					var direction := Vector2.RIGHT.rotated(k * PI * 0.5)
					draw_line(result_at + direction * cell * 0.14, result_at + direction * cell * 0.38, LOCK_RED, 4.0 * s, true)
			"fire":
				_icon("star_rocket", result_at, cell * 0.34, 1.0)
				draw_circle(result_at + Vector2(-cell * 0.30, cell * 0.24), cell * 0.08, Color("ffb347"))
			_:
				_icon(str(steps[i][1]), result_at, cell * 0.34, 1.0)


# --- drawing helpers ---------------------------------------------------------------------


func _label(text: String, centre: Vector2, font_size: float, colour: Color) -> void:
	var size_i: int = maxi(10, int(font_size))
	var extent: Vector2 = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i)
	var at: Vector2 = centre + Vector2(-extent.x * 0.5, font_size * 0.36)
	draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i, maxi(4, int(font_size * 0.22)), Color(INK, 0.9))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i, colour)


func _badge(text: String, centre: Vector2, font_size: float, colour: Color) -> void:
	var size_i: int = maxi(10, int(font_size))
	var extent: Vector2 = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i)
	var pad := Vector2(font_size * 0.6, font_size * 0.3)
	var rect := Rect2(centre - extent * 0.5 - pad - Vector2(0, font_size * 0.05), extent + pad * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Color.WHITE
	style.set_border_width_all(maxi(2, int(font_size * 0.09)))
	style.set_corner_radius_all(int(rect.size.y * 0.5))
	draw_style_box(style, rect)
	draw_string(FONT, centre + Vector2(-extent.x * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i, Color.WHITE)


func _arrow(tip: Vector2, direction: Vector2, length: float, colour: Color) -> void:
	var back: Vector2 = -direction.normalized() * length
	var side: Vector2 = Vector2(-direction.y, direction.x).normalized() * length * 0.75
	draw_colored_polygon(PackedVector2Array([tip, tip + back + side, tip + back * 0.55, tip + back - side]), colour)


func _finger(at: Vector2, length: float) -> void:
	# A pointing hand from below: palm, index finger up, small thumb; dark outline.
	var skin := Color("ffd9b3")
	var line := Color("5a3424")
	var palm := Rect2(at + Vector2(-length * 0.42, length * 0.05), Vector2(length * 0.84, length * 0.75))
	var finger := Rect2(at + Vector2(-length * 0.15, -length * 0.95), Vector2(length * 0.30, length * 1.05))
	for grow in [length * 0.07, 0.0]:
		var colour: Color = line if grow > 0.0 else skin
		draw_rect(palm.grow(grow), colour)
		draw_rect(finger.grow(grow), colour)
		draw_circle(finger.position + Vector2(finger.size.x * 0.5, 0), finger.size.x * 0.5 + grow, colour)
		draw_circle(palm.position + Vector2(0, palm.size.y * 0.35), length * 0.17 + grow, colour)


## Procedural item icons (no texture fetch): readable silhouettes at 30–80 px.
func _icon(id: String, centre: Vector2, radius: float, alpha: float) -> void:
	match id:
		"star_rocket":
			for side in [-1.0, 1.0]:
				_rocket_icon(centre + Vector2(side * radius * 0.42, radius * 0.08 * side), radius * 0.95, alpha)
		"shield":
			var hexagon := PackedVector2Array()
			for k in range(6):
				hexagon.append(centre + Vector2.RIGHT.rotated(PI / 6.0 + k * PI / 3.0) * radius)
			draw_colored_polygon(hexagon, Color(SHIELD_CYAN, 0.35 * alpha))
			draw_polyline(hexagon + PackedVector2Array([hexagon[0]]), Color(SHIELD_CYAN, alpha), radius * 0.16, true)
			draw_arc(centre, radius * 0.45, 0, TAU, 24, Color(1, 1, 1, alpha), radius * 0.1, true)
		"boost", "triple_boost":
			var count: int = 3 if id == "triple_boost" else 2
			for k in range(count):
				var x: float = centre.x + (k - (count - 1) * 0.5) * radius * 0.55
				_arrow(Vector2(x + radius * 0.35, centre.y), Vector2.RIGHT, radius * 0.7, Color("ffd166", alpha))
		"spark_ball":
			draw_circle(centre, radius * 0.62, Color("58f0a0", alpha))
			for k in range(8):
				var direction := Vector2.RIGHT.rotated(k * PI / 4.0)
				draw_line(centre + direction * radius * 0.72, centre + direction * radius * 1.0, Color("dfffe9", alpha), radius * 0.12, true)
		"bubble_trap":
			draw_circle(centre, radius * 0.9, Color("7fd8ff", 0.45 * alpha))
			draw_arc(centre, radius * 0.9, 0, TAU, 32, Color("dff6ff", alpha), radius * 0.12, true)
			draw_circle(centre + Vector2(-radius * 0.32, -radius * 0.32), radius * 0.18, Color(1, 1, 1, alpha))
		"pulse":
			for k in range(8):
				var direction := Vector2.RIGHT.rotated(k * PI / 4.0)
				var reach: float = radius * (1.0 if k % 2 == 0 else 0.6)
				draw_line(centre, centre + direction * reach, Color("c58cff", alpha), radius * 0.16, true)
			draw_circle(centre, radius * 0.3, Color(1, 1, 1, alpha))
		"star_magnet":
			draw_arc(centre + Vector2(0, -radius * 0.1), radius * 0.62, 0, PI, 24, Color("ffe066", alpha), radius * 0.32, false)
			draw_rect(Rect2(centre + Vector2(-radius * 0.78, -radius * 0.7), Vector2(radius * 0.32, radius * 0.5)), Color("ff6b8b", alpha))
			draw_rect(Rect2(centre + Vector2(radius * 0.46, -radius * 0.7), Vector2(radius * 0.32, radius * 0.5)), Color("ff6b8b", alpha))
		"aurora":
			for k in range(3):
				var band := PackedVector2Array()
				for j in range(9):
					var x: float = -1.0 + j * 0.25
					band.append(centre + Vector2(x * radius, (k - 1) * radius * 0.42 + sin(x * 3.0 + k) * radius * 0.18))
				draw_polyline(band, Color(["8affd8", "66e8ff", "c58cff"][k], alpha), radius * 0.18, true)
		_:
			draw_circle(centre, radius * 0.6, Color(1, 1, 1, alpha))


func _rocket_icon(centre: Vector2, length: float, alpha: float) -> void:
	# Pointing up-right: white body, coral nose, gold fins, flame.
	var axis := Vector2(0.45, -1.0).normalized()
	var side := Vector2(-axis.y, axis.x)
	var half: float = length * 0.5
	var width: float = length * 0.13
	var nose: Vector2 = centre + axis * half
	var tail: Vector2 = centre - axis * half * 0.75
	draw_colored_polygon(PackedVector2Array([tail - side * width * 2.0 - axis * width, tail, tail + side * width * 2.0 - axis * width]), Color("ffc22e", alpha))
	draw_colored_polygon(PackedVector2Array([tail - side * width, centre + axis * half * 0.45 - side * width, centre + axis * half * 0.45 + side * width, tail + side * width]), Color("f7f9ff", alpha))
	draw_colored_polygon(PackedVector2Array([centre + axis * half * 0.45 - side * width, nose, centre + axis * half * 0.45 + side * width]), Color(ROCKET_RED, alpha))
	draw_colored_polygon(PackedVector2Array([tail - side * width * 0.7, tail - axis * length * 0.32, tail + side * width * 0.7]), Color("ff9a3c", alpha))
