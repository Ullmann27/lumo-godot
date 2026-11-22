extends RefCounted
## Prüfstand der Garage: kurze Fahrten mit denselben Formeln wie das Rennen
## (kart_powertrain.gd, aufgerufen aus kart_island._drive_player), fester 60-Hz-Takt,
## Rennttempo „Abenteuer“, ebener Asphalt, keine Items, keine Rivalen, keine Aufholhilfe.
## Gemessen wird, nicht geschätzt: jede Zahl ist das Ergebnis einer Schritt-für-Schritt-Fahrt.
##   top_kmh      Endtempo auf der Geraden
##   sprint_s     Zeit von 0 auf 100 km/h
##   brake_m      Bremsweg aus 72 km/h
##   radius_m     Kurvenradius bei voller Lenkung und Endtempo (nach 2 s Kreisfahrt)
##   slide_m      seitliches Rutschen in der ersten Sekunde eines vollen Einlenkens
##   drift_s      Zeit bis zum ersten Drift-Turbo bei voller Lenkung
##   boost_s      Dauer eines Drift-Turbos (erste Stufe)
##   boost_kmh    Höchsttempo während des Turbos
##   offroad_kmh  Endtempo neben der Fahrbahn (Sand, Gras)
##   air_deg      Richtungsänderung bei voller Lenkung in 0,8 s Flug
##   landing_s    Lenkberuhigung nach einer harten Landung (Aufprall 9 m/s)
##   bump_pct     Tempo, das nach einem Rempler bleibt
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const STEP: float = 1.0 / 60.0
const METRICS: Array[String] = [
	"top_kmh",
	"sprint_s",
	"brake_m",
	"radius_m",
	"slide_m",
	"drift_s",
	"boost_s",
	"boost_kmh",
	"offroad_kmh",
	"air_deg",
	"landing_s",
	"bump_pct",
]
## Kindgerechte Namen, Einheit und ob „mehr“ besser ist (für Pfeil und Farbe).
const LABELS: Dictionary = {
	"top_kmh": {"name": "Endtempo", "unit": "km/h", "digits": 0, "higher": true},
	"sprint_s": {"name": "0–100 km/h", "unit": "s", "digits": 2, "higher": false},
	"brake_m": {"name": "Bremsweg", "unit": "m", "digits": 1, "higher": false},
	"radius_m": {"name": "Kurvenradius", "unit": "m", "digits": 1, "higher": false},
	"slide_m": {"name": "Rutschen", "unit": "m", "digits": 2, "higher": false},
	"drift_s": {"name": "Drift-Turbo nach", "unit": "s", "digits": 2, "higher": false},
	"boost_s": {"name": "Turbo-Dauer", "unit": "s", "digits": 2, "higher": true},
	"boost_kmh": {"name": "Turbo-Tempo", "unit": "km/h", "digits": 0, "higher": true},
	"offroad_kmh": {"name": "Tempo im Gelände", "unit": "km/h", "digits": 0, "higher": true},
	"air_deg": {"name": "Lenken im Flug", "unit": "°", "digits": 0, "higher": true},
	"landing_s": {"name": "Wackeln nach Landung", "unit": "s", "digits": 2, "higher": false},
	"bump_pct": {"name": "Tempo nach Rempler", "unit": "%", "digits": 0, "higher": true},
}


static func race_top(factors: Dictionary) -> float:
	return POWERTRAIN.top_speed(factors, POWERTRAIN.race_pace())


## Fixed finish speed: a lower top speed alone cannot earn a quicker sprint.
static func sprint_seconds(factors: Dictionary) -> float:
	var top: float = race_top(factors)
	var speed: float = 0.0
	var time: float = 0.0
	while speed < 100.0 / 3.6 and time < 30.0:
		speed = move_toward(speed, top, STEP * POWERTRAIN.acceleration(factors, false))
		time += STEP
	return time


## Volle Lenkung bei Endtempo: Position wie im Rennen integrieren (Richtung + Haftung).
static func corner_run(factors: Dictionary, drifting: bool = false) -> Dictionary:
	var speed: float = race_top(factors)
	var heading: float = 0.0
	var velocity := Vector3(0, 0, -speed)
	var position := Vector3.ZERO
	var slide: float = 0.0
	var points: Array[Vector3] = []
	for frame in range(180):
		heading -= POWERTRAIN.turn_rate(factors, speed, drifting, false) * STEP
		var forward := Vector3(-sin(heading), 0, -cos(heading))
		velocity = velocity.lerp(
			forward * speed, minf(1, STEP * POWERTRAIN.grip_rate(factors, drifting))
		)
		position += velocity * STEP
		var side: Vector3 = velocity - forward * velocity.dot(forward)
		if frame < 60:
			slide += side.length() * STEP
		if frame >= 120:
			points.append(position)
	# Kreis durch drei Punkte der letzten Sekunde: der echte, gefahrene Radius.
	var radius: float = _circle_radius(points[0], points[points.size() / 2], points[-1])
	return {"radius_m": radius, "slide_m": slide}


static func _circle_radius(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab: float = a.distance_to(b)
	var bc: float = b.distance_to(c)
	var ca: float = c.distance_to(a)
	var area: float = absf((b - a).cross(c - a).length()) * 0.5
	return INF if area < 0.000001 else ab * bc * ca / (4.0 * area)


static func drift_seconds(factors: Dictionary) -> float:
	var charge: float = 0.0
	var time: float = 0.0
	while charge < RACE_RULES.DRIFT_TIERS[0] and time < 10.0:
		charge = minf(3, charge + STEP * POWERTRAIN.drift_charge_rate(factors, 1.0))
		time += STEP
	return time


## Ein Drift-Turbo der ersten Stufe: Dauer und Höchsttempo (Turbo-Rampe wie im Rennen).
static func boost_run(factors: Dictionary) -> Dictionary:
	var top: float = race_top(factors)
	var duration: float = (
		float(RACE_RULES.DRIFT_BOOST_SECONDS[0]) * float(factors.get("boost_time", 1.0))
	)
	var speed: float = top
	var peak: float = top
	var time: float = 0.0
	var boost_left: float = duration
	while boost_left > 0.0:
		var target: float = top * POWERTRAIN.boost_scale(factors)
		var accel: float = POWERTRAIN.acceleration(factors, false) * POWERTRAIN.BOOST_ACCELERATION
		speed = move_toward(speed, target, STEP * accel)
		peak = maxf(peak, speed)
		boost_left -= STEP
		time += STEP
	return {"boost_s": duration, "boost_kmh": peak * 3.6}


## Flug von 0,8 s bei voller Lenkung: gedrehter Winkel in Grad.
static func air_degrees(factors: Dictionary) -> float:
	var speed: float = race_top(factors)
	var heading: float = 0.0
	for _frame in range(48):
		heading += POWERTRAIN.turn_rate(factors, speed, false, true) * STEP
	return rad_to_deg(heading)


static func measure(factors: Dictionary) -> Dictionary:
	var corner: Dictionary = corner_run(factors)
	var boost: Dictionary = boost_run(factors)
	return {
		"top_kmh": race_top(factors) * 3.6,
		"sprint_s": sprint_seconds(factors),
		"brake_m": POWERTRAIN.stopping_distance(factors, 20.0),
		"radius_m": corner.radius_m,
		"slide_m": corner.slide_m,
		"drift_s": drift_seconds(factors),
		"boost_s": boost.boost_s,
		"boost_kmh": boost.boost_kmh,
		"offroad_kmh": race_top(factors) * float(factors.get("offroad", 0.54)) * 3.6,
		"air_deg": air_degrees(factors),
		"landing_s": POWERTRAIN.landing_settle(factors, 9.0),
		"bump_pct": _rival_contact_speed(factors),
	}


## A rival contact in _track_events limits the target for 0.25 seconds.
## Integrate those race ticks: the kart does not instantly reach that limit.
static func _rival_contact_speed(factors: Dictionary) -> float:
	var top := race_top(factors)
	var speed := top
	var target := top * float(factors.get("stability", 0.45))
	for tick in 15:
		speed = move_toward(speed, target, STEP * POWERTRAIN.contact_deceleration(factors))
	return 100.0 * speed / top


static func format_value(metric: String, value: float) -> String:
	var info: Dictionary = LABELS.get(metric, {})
	var digits: int = int(info.get("digits", 1))
	var text: String = (
		str(roundi(value))
		if digits == 0
		else (("%." + str(digits) + "f") % value).replace(".", ",")
	)
	return "%s %s" % [text, str(info.get("unit", ""))]


## -1 schlechter, 0 gleich, +1 besser (auf der angezeigten Genauigkeit).
static func verdict(metric: String, before: float, after: float) -> int:
	var info: Dictionary = LABELS.get(metric, {})
	var digits: int = int(info.get("digits", 1))
	var scale: float = pow(10.0, digits)
	var delta: float = roundf(after * scale) - roundf(before * scale)
	if absf(delta) < 0.5:
		return 0
	var better: bool = delta > 0.0 if bool(info.get("higher", true)) else delta < 0.0
	return 1 if better else -1


## Describe the physical direction; colour separately conveys the advantage/trade-off.
static func change_word(metric: String, before: float, after: float) -> String:
	if verdict(metric, before, after) == 0:
		return "gleich"
	var more := after > before
	match metric:
		"top_kmh", "boost_kmh", "offroad_kmh":
			return "schneller" if more else "langsamer"
		"sprint_s", "drift_s":
			return "später" if more else "früher"
		"brake_m", "boost_s", "landing_s":
			return "länger" if more else "kürzer"
		"radius_m":
			return "weiter" if more else "enger"
	return "mehr" if more else "weniger"


## Werte für die Anzeige eines Teilewechsels: zuerst die geänderten Werte des Steckplatzes,
## dann weitere geänderte Werte, höchstens limit. Gibt es einen gemessenen Vorteil und einen
## Nachteil, stehen beide in der Liste. Ohne Änderung: die Steckplatz-Werte.
static func display_metrics(
	defaults: Array, before: Dictionary, after: Dictionary, limit: int = 4
) -> Array[String]:
	var changed: Array[String] = []
	for metric in defaults + METRICS:
		var key: String = str(metric)
		if changed.has(key) or not before.has(key) or not after.has(key):
			continue
		if verdict(key, float(before[key]), float(after[key])) != 0:
			changed.append(key)
	var result: Array[String] = []
	for key in changed:
		if result.size() < limit:
			result.append(key)
	# Vorteil und Nachteil müssen beide sichtbar sein (kein Teil ist nur „besser“).
	for wanted in [1, -1]:
		var shown := false
		for key in result:
			shown = shown or verdict(key, float(before[key]), float(after[key])) == wanted
		if shown:
			continue
		for key in changed:
			if (
				not result.has(key)
				and verdict(key, float(before[key]), float(after[key])) == wanted
			):
				result[result.size() - 1] = key
				break
	for metric in defaults:
		if result.size() >= mini(limit, 2):
			break
		if not result.has(str(metric)):
			result.append(str(metric))
	return result
