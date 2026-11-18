class_name LumoKartItemHud
extends Control
## Item layer of the race HUD, drawn in one Control (cheap on phones). Die Teile sind in
## Blender gerendert (tools/art/render_kart_item_hud.py), passend zu den Renn-Knöpfen:
##  - Zielerfassung wie im Kampfjet: Suchring wandert, verengt sich auf den Rivalen, vier
##    Klammern rasten ein (einmaliger kurzer Lichtring + Ton aus kart_island), Entfernung als
##    Balken unter dem Ziel; ohne Ziel „Kein Ziel – geradeaus“
##  - Raketenhalter links/rechts mit je zwei Schächten (Füllstand = verbleibende Salven)
##  - Schild-Restzeit als Ring um das Schild-Symbol
##  - Warnung von hinten: roter Pfeil am unteren Rand
##  - Item-Symbol im Knopf, kurze Roulette, Piktogramm-Hinweis beim ersten Mal
## Nichts blinkt periodisch; ruhige Bewegung: kein Aufblitzen, kein Drehen, kein Atmen.

const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const ROCKET_RED := Color("ff4f6d")
const LOCK_GOLD := Color("ffd23f")
const LOCK_RED := Color("ff3b5c")
const SHIELD_CYAN := Color("66e8ff")
const INK := Color("071428")
const ITEM_ART := "res://assets/kart/hud/items/"
const FLASH_SECONDS: float = 0.32
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
## Restzeit des einmaligen Einrast-Lichtrings (startet, wenn der Lock 1.0 erreicht).
var _flash: float = 0.0
var _was_locked: bool = false
static var _textures: Dictionary = {}


func _init() -> void:
	name = "KartItemHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func push_state(next_state: Dictionary, delta: float) -> void:
	state = next_state
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	var locked_now: bool = lock_stage() == "locked"
	if locked_now and not _was_locked and not reduced_motion:
		_flash = FLASH_SECONDS
	_was_locked = locked_now
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
	_draw_rocket_pods(s)
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
# Gerenderte Teile (tools/art/render_kart_item_hud.py) in der Bildsprache der Renn-Knöpfe:
# Suchring -> verengt sich aufs Ziel -> Klammern rasten ein (kurzes Aufblitzen, nicht bei
# ruhiger Bewegung). Entfernung als Balken unter dem Ziel, ohne Zahlen.


static func _tex(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := ITEM_ART + id + ".webp"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]


func _draw_tex_centered(id: String, centre: Vector2, edge: float, angle: float = 0.0, tint: Color = Color.WHITE) -> bool:
	var texture: Texture2D = _tex(id)
	if texture == null:
		return false
	draw_set_transform(centre, angle, Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-edge, -edge) * 0.5, Vector2(edge, edge)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _glass_plate(text: String, centre: Vector2, font_size: float, rim: Color, fill: Color = Color(0.02, 0.06, 0.15, 0.86)) -> void:
	var size_i: int = maxi(10, int(font_size))
	var extent: Vector2 = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i)
	var pad := Vector2(font_size * 0.7, font_size * 0.34)
	var rect := Rect2(centre - extent * 0.5 - pad - Vector2(0, font_size * 0.05), extent + pad * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(rim, 0.95)
	style.set_border_width_all(maxi(2, int(font_size * 0.1)))
	style.set_corner_radius_all(int(rect.size.y * 0.5))
	style.shadow_color = Color(rim, 0.28)
	style.shadow_size = maxi(2, int(font_size * 0.3))
	style.anti_aliasing = true
	draw_style_box(style, rect)
	draw_string(FONT, centre + Vector2(-extent.x * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_i, Color.WHITE)


## Laufende Werte, die Tests und Aufnahmen lesen: "search", "acquire", "locked".
func lock_stage() -> String:
	if str(state.get("phase", "")) != "armed":
		return ""
	if not bool(state.get("has_target", false)):
		return "search"
	return "locked" if float(state.get("lock", 0.0)) >= 1.0 else "acquire"


## 0 (Ziel am Rand der Reichweite) .. 1 (Ziel ganz nah); -1 ohne Ziel/Entfernung.
func range_fill() -> float:
	var distance: float = float(state.get("target_distance", -1.0))
	var reach: float = float(state.get("lock_range", 0.0))
	if distance < 0.0 or reach <= 0.0 or not bool(state.get("has_target", false)):
		return -1.0
	return clampf(1.0 - distance / reach, 0.0, 1.0)


func _draw_lock_on(s: float) -> void:
	var progress: float = clampf(float(state.get("lock", 0.0)), 0.0, 1.0)
	var locked: bool = progress >= 1.0
	var has_target: bool = bool(state.get("has_target", false)) and _target_screen() != null
	var centre: Vector2 = _aim_centre()
	# Visier in der Mitte: zeigt immer, wo „geradeaus“ ist.
	var sight: Color = Color(0.75, 0.95, 1.0, 0.6)
	draw_arc(centre, 22.0 * s, 0, TAU, 40, sight, 2.0 * s, true)
	for k in range(4):
		var direction := Vector2.RIGHT.rotated(k * PI * 0.5)
		draw_line(centre + direction * 28.0 * s, centre + direction * 40.0 * s, sight, 2.5 * s, true)
	var spin: float = 0.0 if reduced_motion else _time * 0.9
	if not has_target:
		if not _draw_tex_centered("seeker_ring", seeker, 150.0 * s, spin, Color(1, 1, 1, 0.92)):
			draw_arc(seeker, 60.0 * s, 0, TAU, 40, Color(0.5, 0.9, 1.0, 0.9), 4.0 * s, true)
		_glass_plate("Kein Ziel – geradeaus", centre + Vector2(0, 96.0 * s), 24.0 * s, Color("6fe6ff"))
		return
	var ease: float = smoothstep(0.0, 1.0, progress)
	# 1) Suchring verengt sich auf das Ziel und verblasst, während die Klammern greifen.
	var ring_edge: float = lerpf(210.0, 112.0, ease) * s
	if not locked:
		_draw_tex_centered("seeker_ring", seeker, ring_edge, spin * 0.5, Color(1, 1, 1, lerpf(0.95, 0.35, ease)))
	# Linie vom Visier zum Ziel: „dorthin fliegen die Raketen“.
	var line_colour: Color = LOCK_RED if locked else LOCK_GOLD
	draw_dashed_line(centre, seeker, Color(line_colour, 0.5), 2.5 * s, 12.0 * s)
	# 2) Vier gerenderte Klammer-Ecken schließen sich von weit nach eng.
	var half: float = lerpf(120.0, 54.0, ease) * s
	var corner_edge: float = 46.0 * s * (1.12 if locked else 1.0)
	var corner_id: String = "lock_corner_red" if locked else "lock_corner_gold"
	for k in range(4):
		# Ecke im Bild zeigt nach unten links; die Drehung legt sie an jede Ecke.
		var angle: float = -k * PI * 0.5
		var diagonal := Vector2(-1, 1).rotated(angle)
		var at: Vector2 = seeker + diagonal * half
		if not _draw_tex_centered(corner_id, at, corner_edge, angle):
			draw_arc(at, 10.0 * s, 0, TAU, 12, line_colour, 4.0 * s, true)
	# Fortschrittsring um das Ziel.
	draw_arc(seeker, half * 0.66, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(INK, 0.6), 8.0 * s, true)
	draw_arc(seeker, half * 0.66, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(line_colour, 0.95), 4.5 * s, true)
	if locked:
		_draw_tex_centered("lock_core", seeker, 46.0 * s)
		# 3) Einrasten: ein einziger kurzer Lichtring nach außen (kein Blinken, kein Loop).
		if _flash > 0.0 and not reduced_motion:
			var t: float = 1.0 - _flash / FLASH_SECONDS
			draw_arc(seeker, half * (0.9 + t * 0.9), 0, TAU, 48, Color(1, 1, 1, (1.0 - t) * 0.9), (7.0 - t * 5.0) * s, true)
			draw_circle(seeker, half * 0.5, Color(1, 1, 1, (1.0 - t) * 0.35))
		_glass_plate("ZIEL ERFASST!", seeker + Vector2(0, -half - 34.0 * s), 28.0 * s, LOCK_RED, Color(0.35, 0.0, 0.06, 0.9))
	else:
		_glass_plate("ERFASSE …", seeker + Vector2(0, -half - 30.0 * s), 22.0 * s, LOCK_GOLD)
	var fill: float = range_fill()
	var below: Vector2 = seeker + Vector2(0, half + 26.0 * s)
	if fill >= 0.0:
		_draw_range_bar(below, s, fill, line_colour)
		below += Vector2(0, 30.0 * s)
	var who: String = str(state.get("target_name", ""))
	if not who.is_empty():
		_label(who, below, 22.0 * s, Color.WHITE)


## Entfernungsbalken: voll = ganz nah, leer = Rand der Reichweite. Keine Zahlen.
func _draw_range_bar(centre: Vector2, s: float, fill: float, colour: Color) -> void:
	var width: float = 150.0 * s
	var height: float = 14.0 * s
	var rect := Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.02, 0.06, 0.15, 0.82)
	back.border_color = Color("6fe6ff", 0.8)
	back.set_border_width_all(maxi(1, int(2.0 * s)))
	back.set_corner_radius_all(int(height * 0.5))
	back.anti_aliasing = true
	draw_style_box(back, rect.grow(3.0 * s))
	var inner := Rect2(rect.position, Vector2(maxf(height, width * fill), height))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color("43d8ff").lerp(colour, fill)
	bar.set_corner_radius_all(int(height * 0.5))
	bar.anti_aliasing = true
	draw_style_box(bar, inner)
	# Glanzlinie oben und vier Teilstriche wie auf einer Skala.
	draw_line(inner.position + Vector2(height * 0.5, height * 0.28), inner.position + Vector2(inner.size.x - height * 0.5, height * 0.28), Color(1, 1, 1, 0.45), maxf(1.0, 2.0 * s), true)
	for k in range(1, 4):
		var x: float = rect.position.x + width * k / 4.0
		draw_line(Vector2(x, rect.position.y - 2.0 * s), Vector2(x, rect.end.y + 2.0 * s), Color(INK, 0.7), maxf(1.0, 2.0 * s))
	_rocket_icon(rect.position + Vector2(-16.0 * s, height * 0.5), 26.0 * s, 1.0)


# --- Raketenhalter links/rechts ----------------------------------------------------------


## Ein Halter je Seite mit zwei Schächten. Je Salve verlässt eine Rakete jeden Halter:
## jeder Halter zeigt also so viele Raketen, wie Salven übrig sind (0..2).
func pod_rockets_loaded() -> int:
	if str(state.get("item", "")) != "star_rocket" or float(state.get("roulette", 0.0)) > 0.0:
		return -1
	return clampi(int(state.get("charges", 0)), 0, 2)


func _draw_rocket_pods(s: float) -> void:
	var loaded: int = pod_rockets_loaded()
	if loaded < 0:
		return
	var armed: bool = str(state.get("phase", "")) == "armed"
	var centre: Vector2 = _aim_centre()
	var edge: float = 92.0 * s
	for side in [-1.0, 1.0]:
		var at: Vector2 = centre + Vector2(side * 168.0 * s, 132.0 * s)
		if not _draw_tex_centered("pod_armed" if armed else "pod", at, edge):
			draw_rect(Rect2(at - Vector2(edge, edge) * 0.4, Vector2(edge, edge) * 0.8), Color(INK, 0.8))
		for slot in range(2):
			# Schachtmitten liegen im Bild bei x = ±66 von 384 px.
			var slot_at: Vector2 = at + Vector2((slot * 2 - 1) * edge * 0.172, edge * 0.01)
			if slot < loaded:
				_draw_tex_centered("pod_rocket", slot_at, edge * 0.62)
			else:
				draw_circle(slot_at + Vector2(0, edge * 0.2), edge * 0.05, Color(1, 1, 1, 0.18))


# --- warning, shield, item slot ----------------------------------------------------------


func _draw_rear_warning(s: float) -> void:
	var level: float = clampf(float(state.get("warning", 0.0)), 0.0, 1.0)
	var incoming: bool = bool(state.get("incoming", false))
	# Sanftes Atmen (1.2 Hz); bei ruhiger Bewegung steht alles still.
	var wave: float = 1.0 if reduced_motion else 0.78 + 0.22 * (sin(_time * TAU * 1.2) * 0.5 + 0.5)
	# Weiches rotes Licht vom unteren Rand: „es kommt von hinten“.
	var glow_height: float = 90.0 * s
	for k in range(6):
		var t: float = k / 6.0
		draw_rect(Rect2(Vector2(0, size.y - glow_height * (1.0 - t)), Vector2(size.x, glow_height / 6.0)), Color(LOCK_RED, 0.07 * level * wave * (0.4 + t)))
	var arrow_edge: float = (104.0 if incoming else 88.0) * s
	var arrow_at := Vector2(size.x * 0.5, size.y - arrow_edge * 0.62)
	if not _draw_tex_centered("warn_arrow", arrow_at, arrow_edge, 0.0, Color(1, 1, 1, clampf(level * wave * 1.15, 0.0, 1.0))):
		_arrow(arrow_at + Vector2(0, -arrow_edge * 0.4), Vector2.UP, 30.0 * s, Color(1, 0.35, 0.45, level))
	var text: String = "RAKETE KOMMT!" if incoming else "DU BIST ERFASST!"
	_glass_plate(text, arrow_at + Vector2(0, -arrow_edge * 0.78), 24.0 * s, LOCK_RED, Color(0.35, 0.0, 0.06, 0.88 * level))
	if bool(state.get("shield_ready", false)):
		var rect: Rect2 = state.get("item_rect", Rect2())
		if rect.size.x > 0.0:
			var tip: Vector2 = rect.get_center() + Vector2(0, -rect.size.y * 0.62)
			_glass_plate("SCHILD!", tip + Vector2(0, -34.0 * s), 24.0 * s, SHIELD_CYAN, Color(0.0, 0.18, 0.3, 0.9))
			_arrow(tip, Vector2.DOWN, 18.0 * s, SHIELD_CYAN)


## Schild-Restzeit als Ring um das gerenderte Schild-Symbol (oben in der Mitte).
func shield_fraction() -> float:
	var total: float = maxf(0.1, float(state.get("shield_total", 6.0)))
	return clampf(float(state.get("shield_left", 0.0)) / total, 0.0, 1.0)


func _draw_shield_bar(s: float) -> void:
	var fraction: float = shield_fraction()
	var centre := Vector2(size.x * 0.5, size.y * 0.17)
	var radius: float = 40.0 * s
	draw_circle(centre, radius + 6.0 * s, Color(0.02, 0.06, 0.15, 0.8))
	draw_arc(centre, radius, 0, TAU, 56, Color(SHIELD_CYAN, 0.22), 8.0 * s, true)
	draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 56, SHIELD_CYAN, 7.0 * s, true)
	# Helles Ende des Rings zeigt, wo die Zeit gerade steht.
	var tip: Vector2 = centre + Vector2.RIGHT.rotated(-PI * 0.5 + TAU * fraction) * radius
	draw_circle(tip, 5.0 * s, Color.WHITE)
	if not _draw_tex_centered("shield_core", centre, radius * 1.55):
		_icon("shield", centre, radius * 0.6, 1.0)


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
