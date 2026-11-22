extends RefCounted
## „LUMO Sternenkompass“ – Darstellung der Item-Ziehung aus einem Zufallsprisma.
##
## Ablauf (alle Zeiten in Rennzeit, Pause hält an):
##  1. Prisma eingesammelt: das Rennen zieht das Item SOFORT und genau einmal
##     (kart_island._roll_catalog_item mit den Gewichten aus kart_items.json).
##  2. Eine Energiebahn fliegt vom echten Einsammelpunkt (Weltposition → Bildschirm) zum
##     Kompass über dem Item-Feld (TRAIL_SECONDS).
##  3. Der Kompass dreht seinen Symbolring: Wechsel anfangs alle 0,06 s, dann geometrisch
##     langsamer, der letzte Wechsel dauert rund 0,5 s (klar erkennbares Abbremsen);
##     STANDARD_SECONDS gesamt. Die Folge der Symbole ist eine reine Funktion von
##     Ergebnis, Zeit und laufender Nummer der Ziehung – kein Spiel-Zufall, keine
##     Rückwirkung aufs Ergebnis.
##  4. Abschluss: Ring rastet ein, Name + Symbol + ein einzelner Lichtring; der Item-Knopf
##     ist sofort nutzbar. Reduzierte Bewegung: REDUCED_SECONDS, kein Drehen.
## Tipp auf das Item-Feld während der Ziehung zeigt das Ergebnis sofort (kein Benutzen).
## Kein periodisches Blinken; Lichtring und Ausbruch je nur einmal.

const STANDARD_SECONDS: float = 3.5
const REDUCED_SECONDS: float = 0.35
const MIN_SECONDS: float = 3.2
const MAX_SECONDS: float = 4.0
const FIRST_INTERVAL: float = 0.06
const LAST_INTERVAL: float = 0.6
const TICKS: int = 17
const TRAIL_SECONDS: float = 0.5
const PRESENT_SECONDS: float = 0.9
const VIOLET := Color("8a5cff")
const CYAN := Color("5ff2ff")
const GOLD := Color("ffd23f")
const INK := Color("071428")
const ITEM_CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const BADGE_FONT = preload("res://assets/fonts/Nunito-Black.ttf")

## Laufende Ziehung (vom Rennen geführt, nur Darstellung).
var result: String = ""
var total: float = 0.0
var reduced: bool = false
var draw_index: int = 0
var trail_from := Vector3.ZERO
var trail_age: float = 99.0
var present_left: float = 0.0
var skipped: bool = false


static func duration(reduced_motion: bool) -> float:
	return REDUCED_SECONDS if reduced_motion else STANDARD_SECONDS


## Zeitpunkte der Symbolwechsel (s ab Start), aufsteigend, letzter = Gesamtdauer.
## Geometrisch wachsende Abstände von FIRST_INTERVAL bis ~LAST_INTERVAL.
static func tick_times(seconds: float) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	if seconds <= REDUCED_SECONDS + 0.001:
		times.append(seconds)
		return times
	var ratio: float = pow(LAST_INTERVAL / FIRST_INTERVAL, 1.0 / float(TICKS - 1))
	var raw: Array[float] = []
	var sum: float = 0.0
	for k in range(TICKS):
		var interval: float = FIRST_INTERVAL * pow(ratio, float(k))
		raw.append(interval)
		sum += interval
	var at: float = 0.0
	for interval in raw:
		at += interval * seconds / sum
		times.append(at)
	times[times.size() - 1] = seconds
	return times


## Wie viele Wechsel bis zur Zeit t schon passiert sind (0..TICKS).
static func ticks_done(t: float, seconds: float) -> int:
	var done: int = 0
	for at in tick_times(seconds):
		if t + 0.0001 >= at:
			done += 1
	return done


## Stetige Ringstellung (in Symbolschritten), innerhalb eines Wechsels sanft eingeschwungen.
static func dial_steps(t: float, seconds: float) -> float:
	var times: PackedFloat32Array = tick_times(seconds)
	var previous: float = 0.0
	for k in range(times.size()):
		if t < times[k]:
			var u: float = clampf((t - previous) / maxf(0.001, times[k] - previous), 0.0, 1.0)
			return float(k) + smoothstep(0.0, 1.0, u)
		previous = times[k]
	return float(times.size())


static func order() -> Array[String]:
	return ITEM_CATALOG.ids()


## Symbol, das bei Ringstellung `step` oben unter der Nadel steht. Endstellung = Ergebnis.
## `draw` (laufende Nummer der Ziehung, kein Zufall) wählt nur die Reihenfolge, damit nicht
## jede Ziehung gleich aussieht; das Ergebnis bleibt unberührt.
static func symbol_for_step(result_id: String, step: int, steps_total: int, draw: int) -> String:
	var ids: Array[String] = order()
	if ids.is_empty():
		return result_id
	var landing: int = maxi(0, ids.find(result_id))
	# Schrittweite teilerfremd zur Symbolzahl: jede Ziehung läuft in anderer Reihenfolge
	# durch alle Symbole, endet aber immer auf dem Ergebnis.
	var strides: Array[int] = []
	for stride in range(1, maxi(2, ids.size())):
		var a: int = stride
		var b: int = ids.size()
		while b != 0:
			var r: int = a % b
			a = b
			b = r
		if a == 1:
			strides.append(stride)
	var stride_now: int = strides[posmod(draw, strides.size())] if not strides.is_empty() else 1
	return ids[posmod(landing - (steps_total - step) * stride_now, ids.size())]


func start(id: String, reduced_motion: bool, from_world: Vector3) -> float:
	result = id
	reduced = reduced_motion
	total = duration(reduced_motion)
	draw_index += 1
	trail_from = from_world
	trail_age = 0.0 if from_world != Vector3.ZERO else 99.0
	present_left = 0.0
	skipped = false
	return total


## Vom Rennen aufgerufen, wenn die Ziehung endet (regulär oder übersprungen).
func finish(was_skipped: bool) -> void:
	skipped = was_skipped
	present_left = 0.25 if reduced else PRESENT_SECONDS


func clear() -> void:
	result = ""
	total = 0.0
	present_left = 0.0
	trail_age = 99.0


## Fortschreiben der reinen Darstellung; `remaining` ist die Restzeit des Rennens.
## Gibt die Tonhöhe eines neuen Wechsels zurück (0 = kein neuer Wechsel).
func advance(delta: float, remaining_before: float, remaining_after: float) -> float:
	trail_age += delta
	if remaining_before <= 0.0:
		present_left = maxf(0.0, present_left - delta)
		return 0.0
	var before: int = ticks_done(total - remaining_before, total)
	var after: int = ticks_done(total - remaining_after, total)
	if after <= before or after >= TICKS:
		return 0.0
	# Musikalisch: die Wechsel laufen eine Dur-Pentatonik abwärts, je langsamer, desto tiefer.
	var scale: Array[float] = [1.5, 1.335, 1.189, 1.0, 0.891]
	return scale[after % scale.size()] * lerpf(1.08, 0.94, float(after) / float(TICKS))


## Zustand für die Zeichnung im HUD (kart_item_hud.gd ruft draw_on).
## `anchor` ist die aktuelle Lage des eigenen Karts: Liegt der Einsammelpunkt schon hinter
## der Kamera (bei vollem Tempo nach ~0,15 s), startet die Bahn sichtbar am Kart, das die
## Energie trägt.
func hud_state(remaining: float, camera: Camera3D, anchor: Vector3 = Vector3.INF) -> Dictionary:
	if result.is_empty() or (remaining <= 0.0 and present_left <= 0.0):
		return {}
	var state := {
		"result": result,
		"total": total,
		"t": clampf(total - remaining, 0.0, total),
		"spinning": remaining > 0.0,
		"present": present_left,
		"reduced": reduced,
		"draw": draw_index,
		"skipped": skipped,
		"trail_age": trail_age,
	}
	if trail_age < TRAIL_SECONDS and is_instance_valid(camera):
		if not camera.is_position_behind(trail_from):
			state["trail_screen"] = camera.unproject_position(trail_from)
		elif anchor != Vector3.INF and not camera.is_position_behind(anchor):
			state["trail_screen"] = camera.unproject_position(anchor)
	return state


## Phase für Tests und Aufnahmen: "flight", "fast", "slowing", "settle", "result", "".
static func phase_of(state: Dictionary) -> String:
	if state.is_empty():
		return ""
	if not bool(state.get("spinning", false)):
		return "result"
	var t: float = float(state.t)
	var seconds: float = float(state.total)
	if float(state.get("trail_age", 99.0)) < TRAIL_SECONDS and t < TRAIL_SECONDS:
		return "flight"
	if t >= seconds - LAST_INTERVAL:
		return "settle"
	return "fast" if t < seconds * 0.45 else "slowing"


## Mittelpunkt und Radius des Kompasses über dem Item-Feld.
static func layout(view: Vector2, item_rect: Rect2, s: float) -> Dictionary:
	# Rechts oben unter der Streckenkarte, über dem freien Himmel: verdeckt weder Kart,
	# Fahrbahn vor dem Kart noch einen Knopf. Die Energiebahn läuft vom Kart hierher, das
	# Ergebnis danach als kurze Lichtspur hinunter ins Item-Feld.
	var radius: float = 104.0 * s
	var centre := Vector2(view.x - radius - 30.0 * s, view.y * 0.47)
	if item_rect.size.x > 0.0:
		centre.y = minf(centre.y, item_rect.position.y - radius - 150.0 * s)
	centre.y = maxf(centre.y, radius + 150.0 * s)
	return {"centre": centre, "radius": radius}


## Zeichnet Energiebahn und Kompass auf das HUD (eine Zeichenfläche, billig fürs Handy).
static func draw_on(hud: Control, compass: Dictionary, item_rect: Rect2, s: float) -> void:
	if compass.is_empty():
		return
	var place: Dictionary = layout(hud.size, item_rect, s)
	var centre: Vector2 = place.centre
	var radius: float = place.radius
	var reduced_motion: bool = bool(compass.get("reduced", false))
	if compass.has("trail_screen") and not reduced_motion:
		_draw_trail(hud, compass.trail_screen, centre, float(compass.trail_age) / TRAIL_SECONDS, s)
	var t: float = float(compass.t)
	var seconds: float = maxf(0.01, float(compass.total))
	var appear: float = 1.0 if reduced_motion else smoothstep(0.0, 1.0, clampf(t / 0.3, 0.0, 1.0))
	if not bool(compass.spinning):
		var fade: float = clampf(float(compass.present) / 0.25, 0.0, 1.0)
		appear = fade
	radius *= lerpf(0.55, 1.0, appear)
	_draw_dial(item_rect, hud, compass, centre, radius, appear, s, t, seconds)


static func _draw_trail(
	hud: Control, from: Vector2, to: Vector2, progress: float, s: float
) -> void:
	# Quadratische Kurve, nach oben gewölbt; Kopf läuft beschleunigt zum Kompass.
	var lift: Vector2 = (
		(from + to) * 0.5 + Vector2(0, -minf(220.0 * s, from.distance_to(to) * 0.45))
	)
	var head: float = clampf(progress, 0.0, 1.0)
	head = head * head * (3.0 - 2.0 * head)
	var tail: float = maxf(0.0, head - 0.42)
	var points := PackedVector2Array()
	var steps: int = 18
	for k in range(steps + 1):
		var u: float = lerpf(tail, head, float(k) / float(steps))
		points.append(from.lerp(lift, u).lerp(lift.lerp(to, u), u))
	for k in range(points.size() - 1):
		var w: float = float(k + 1) / float(points.size())
		var colour: Color = VIOLET.lerp(CYAN, w).lerp(GOLD, w * w)
		hud.draw_line(points[k], points[k + 1], Color(colour, 0.25 * w), 22.0 * s * w, true)
		hud.draw_line(points[k], points[k + 1], Color(colour, 0.9 * w), 6.0 * s * w + 1.0, true)
	var tip: Vector2 = points[points.size() - 1]
	hud.draw_circle(tip, 14.0 * s, Color(GOLD, 0.55))
	hud.draw_circle(tip, 7.0 * s, Color(1, 1, 1, 0.95))
	# Lichtpartikel lösen sich entlang der Bahn (feste Lagen, kein Zufall).
	for k in range(7):
		var u: float = clampf(head - float(k) * 0.06, 0.0, 1.0)
		var p: Vector2 = from.lerp(lift, u).lerp(lift.lerp(to, u), u)
		var side := Vector2(sin(float(k) * 2.1), cos(float(k) * 1.7)) * (10.0 + float(k) * 3.0) * s
		hud.draw_circle(
			p + side,
			(5.0 - float(k) * 0.5) * s,
			Color(CYAN if k % 2 == 0 else GOLD, 0.8 - float(k) * 0.1)
		)


static func _star_points(
	centre: Vector2, outer: float, inner: float, tips: int, angle: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(tips * 2):
		var r: float = outer if i % 2 == 0 else inner
		points.append(
			centre + Vector2.RIGHT.rotated(angle - PI * 0.5 + float(i) * PI / float(tips)) * r
		)
	return points


static func _draw_dial(
	item_rect: Rect2,
	hud: Control,
	compass: Dictionary,
	centre: Vector2,
	radius: float,
	alpha: float,
	s: float,
	t: float,
	seconds: float
) -> void:
	var spinning: bool = bool(compass.spinning)
	var reduced_motion: bool = bool(compass.get("reduced", false))
	var result_id: String = str(compass.result)
	var ids: Array[String] = order()
	var count: int = maxi(1, ids.size())
	var steps_total: int = tick_times(seconds).size()
	var step: float = (
		float(steps_total) if (not spinning or reduced_motion) else dial_steps(t, seconds)
	)
	var draw: int = int(compass.get("draw", 0))
	# Grundplatte: dunkles Glas mit drei Ringen (Violett, Cyan, Gold).
	hud.draw_circle(centre, radius * 1.04, Color(INK, 0.55 * alpha))
	hud.draw_circle(centre, radius, Color(0.03, 0.07, 0.18, 0.9 * alpha))
	hud.draw_arc(centre, radius, 0, TAU, 64, Color(VIOLET, 0.95 * alpha), 6.0 * s, true)
	hud.draw_arc(centre, radius * 0.9, 0, TAU, 64, Color(CYAN, 0.7 * alpha), 2.5 * s, true)
	hud.draw_arc(centre, radius * 0.46, 0, TAU, 48, Color(GOLD, 0.55 * alpha), 2.0 * s, true)
	# Kompassrose in der Mitte: achtzackiger Stern, dreht sich mit dem Ring mit, langsamer.
	var rose_angle: float = 0.0 if reduced_motion else -step * TAU / float(count) * 0.25
	hud.draw_colored_polygon(
		_star_points(centre, radius * 0.4, radius * 0.12, 8, rose_angle),
		Color(VIOLET, 0.55 * alpha)
	)
	hud.draw_colored_polygon(
		_star_points(centre, radius * 0.3, radius * 0.1, 4, rose_angle), Color(GOLD, 0.85 * alpha)
	)
	hud.draw_circle(centre, radius * 0.08, Color(1, 1, 1, 0.9 * alpha))
	# Symbolring: das Symbol der aktuellen Stellung steht oben unter der Nadel.
	var current: int = int(floor(step))
	var fraction: float = step - float(current)
	var slots: int = mini(count, 8)
	for k in range(-slots / 2, slots / 2 + 1):
		var symbol: String = symbol_for_step(result_id, current + k, steps_total, draw)
		var angle: float = -PI * 0.5 + (float(k) - fraction) * TAU / float(maxi(slots, 6))
		var at: Vector2 = centre + Vector2.RIGHT.rotated(angle) * radius * 0.68
		var near_top: float = clampf(1.0 - absf(float(k) - fraction) * 0.9, 0.0, 1.0)
		var icon_alpha: float = alpha * lerpf(0.55, 1.0, near_top)
		var icon_radius: float = radius * lerpf(0.15, 0.24, near_top)
		# Heller Glasgrund, damit auch dunkle Symbole auf kleinen Displays lesbar bleiben.
		hud.draw_circle(at, icon_radius * 1.3, Color(0.16, 0.22, 0.42, 0.92 * icon_alpha))
		if near_top > 0.5:
			hud.draw_arc(
				at, icon_radius * 1.3, 0, TAU, 32, Color(GOLD, near_top * alpha), 3.0 * s, true
			)
		hud.call("_icon", symbol, at, icon_radius, icon_alpha)
	# Nadel oben (gold) zeigt auf das gewählte Symbol.
	var needle_tip: Vector2 = centre + Vector2(0, -radius * 0.98)
	var needle := PackedVector2Array(
		[
			needle_tip + Vector2(0, 14.0 * s),
			needle_tip + Vector2(-12.0 * s, -10.0 * s),
			needle_tip + Vector2(12.0 * s, -10.0 * s),
		]
	)
	hud.draw_colored_polygon(needle, Color(GOLD, alpha))
	hud.draw_polyline(needle + PackedVector2Array([needle[0]]), Color(INK, alpha), 2.0 * s, true)
	if spinning:
		# Kurzer Zeitring außen: so lange dauert die Ziehung noch (kein Blinken).
		var done: float = clampf(t / seconds, 0.0, 1.0)
		hud.draw_arc(
			centre,
			radius * 1.1,
			-PI * 0.5,
			-PI * 0.5 + TAU * done,
			64,
			Color(GOLD, 0.8 * alpha),
			4.0 * s,
			true
		)
		return
	# Ergebnis: großes Symbol in der Mitte, Name darunter, ein einzelner Lichtring.
	var present: float = float(compass.get("present", 0.0))
	var total_present: float = 0.25 if reduced_motion else PRESENT_SECONDS
	var age: float = clampf(1.0 - present / total_present, 0.0, 1.0)
	hud.draw_circle(centre, radius * 0.42, Color(INK, 0.85 * alpha))
	hud.call("_icon", result_id, centre, radius * 0.3, alpha)
	if not reduced_motion and age < 0.6:
		var ring: float = age / 0.6
		hud.draw_arc(
			centre,
			radius * (1.0 + ring * 0.5),
			0,
			TAU,
			64,
			Color(1, 1, 1, (1.0 - ring) * 0.8 * alpha),
			(6.0 - ring * 4.0) * s,
			true
		)
	if item_rect.size.x > 0.0 and not reduced_motion and age < 0.7:
		# Ergebnis wandert als Lichtspur ins Item-Feld (Knopf ist ab jetzt nutzbar).
		var slot: Vector2 = item_rect.get_center()
		var head: float = smoothstep(0.0, 1.0, clampf(age / 0.45, 0.0, 1.0))
		var tip: Vector2 = centre.lerp(slot, head)
		hud.draw_line(
			centre.lerp(slot, maxf(0.0, head - 0.35)),
			tip,
			Color(GOLD, 0.8 * (1.0 - age)),
			8.0 * s,
			true
		)
		hud.draw_circle(tip, 10.0 * s, Color(1, 1, 1, 0.9 * (1.0 - age)))
	var name: String = str(ITEM_CATALOG.entry(result_id).get("name", result_id))
	var colour: Color = ITEM_CATALOG.color(result_id)
	# Namensschild ganz im Bild halten.
	var font_size: float = 30.0 * s
	var half_width: float = (
		BADGE_FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x * 0.5
		+ font_size * 0.8
	)
	# Links neben dem Kompass, auf Höhe des Ergebnisses: nie unter einem Knopf.
	var badge_at: Vector2 = centre + Vector2(-radius - half_width - 14.0 * s, 0.0)
	badge_at.x = maxf(badge_at.x, half_width + 12.0 * s)
	hud.call("_badge", name, badge_at, font_size, Color(colour.darkened(0.45), alpha))
