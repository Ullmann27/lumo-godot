extends RefCounted
## Lumos Riesengarten – Signatur-Strecke (Entwurf: Koordinator, 21.11.2026).
## Winzige Karts in einem riesigen Sommergarten. Diese Datei ist die Fahrautorität:
## Mittellinie, Höhen, Breiten, Querneigung, Rampen, Turbofelder und Kollision.
## Bauteile (Gießkanne, Seerosen, Schlauch, Topfturm, Gartenbahn, Kürbis, Pusteblumen,
## Gewächshaus) stehen in kart_garden_environment.gd und folgen genau diesen Zahlen.
##
## Mittellinie: Schildkrötenpfad aus Geraden und Kurven mit Klothoiden-Übergängen
## (Krümmung steigt linear an und ab) – dadurch rollt die Querneigung ohne Ruck ein.
## Die Schleife schließt exakt (Längen der zwei Geraden 13 und 16 per 2×2-Gleichung gelöst,
## Entwurfswerkzeug im Bericht). Positive Winkel = Linkskurve von oben gesehen.
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const ID: String = "riesengarten_2400"
## Gemessene Rundenlänge der fertigen Fahrbahn (Curve3D.get_baked_length, Test prüft ±0,5 m).
const LENGTH: float = 2411.2
const STEP: float = 0.5
const SAMPLE: float = 2.0
const SEGMENTS: Array = [
	["S", 120.0],
	["T", 75.0, 125.0, 30.0],
	["S", 10.0],
	["S", 235.0],
	["T", 75.0, 95.0, 30.0],
	["S", 20.0],
	["T", -40.0, 45.0, 20.0],
	["T", 70.0, 45.0, 20.0],
	["T", -40.0, 45.0, 20.0],
	["S", 20.0],
	["T", 30.0, 60.0, 20.0],
	["T", 360.0, 36.0, 25.0],
	["T", 10.0, 120.0, 20.0],
	["S", 239.45834702678397],
	["T", 90.0, 75.0, 25.0],
	["S", 40.0],
	["S", 245.93785184154564],
	["T", 60.0, 50.0, 20.0],
	["S", 10.0],
	["T", -45.0, 50.0, 20.0],
	["S", 10.0],
	["T", 60.0, 50.0, 20.0],
	["S", 10.0],
	["T", -45.0, 50.0, 20.0],
	["S", 10.0],
	["T", 60.0, 50.0, 20.0],
	["S", 90.0],
]
## Höhe der Fahrbahn über dem Gartenboden (planare Meter → Meter), linear, dann geglättet.
const HEIGHT_KEYS: Array = [
	[0.0, 2.0],
	[305.0, 2.0],
	[372.0, 9.0],
	[482.0, 9.0],
	[520.0, 1.2],
	[735.0, 1.2],
	[982.0, 26.0],
	[1233.0, 4.0],
	[1290.0, 3.0],
	[1942.0, 3.0],
	[1990.0, 2.0],
	[2409.0, 2.0],
]
const SMOOTH_RADIUS: int = 12
## Abschnitte (Meter auf der fertigen Fahrbahn, Messung kart_garden_regression).
const SECTIONS: Array[Dictionary] = [
	{"id": "start", "name": "Start an der Sonnenblume", "start": 0.0, "end": 150.0},
	{"id": "tau", "name": "Tautropfen-Allee", "start": 150.0, "end": 325.0},
	{"id": "kanne", "name": "Gießkannen-Schanze", "start": 325.0, "end": 548.0},
	{"id": "seerosen", "name": "Seerosen-Brücke", "start": 548.0, "end": 735.0},
	{"id": "schlauch", "name": "Gartenschlauch-Röhre", "start": 735.0, "end": 985.0},
	{"id": "topf", "name": "Blumentopf-Spirale", "start": 985.0, "end": 1238.0},
	{"id": "bahn", "name": "Gartenbahn-Kreuzung", "start": 1238.0, "end": 1516.0},
	{"id": "kuerbis", "name": "Kürbis-Abkürzung", "start": 1516.0, "end": 1700.0},
	{"id": "loewenzahn", "name": "Löwenzahn-Wiese", "start": 1700.0, "end": 1946.0},
	{"id": "glashaus", "name": "Gewächshaus-Finale", "start": 1946.0, "end": 2321.0},
	{"id": "ziel", "name": "Zieleinlauf", "start": 2321.0, "end": LENGTH},
]
## Gießkanne: Rumpf, Ausguss (Schanze im Rohr), Wasserrutsche unter dem Flug, Landeblätter.
const CAN_BODY: Vector2 = Vector2(399.0, 446.0)
const CAN_SPOUT: Vector2 = Vector2(447.0, 459.0)
const CAN_SLIDE_END: float = 521.0
const LANDING: Vector2 = Vector2(521.0, 604.0)
const HOSE: Vector2 = Vector2(735.0, 984.0)
const HOSE_APEXES: Array[float] = [759.0, 822.0, 886.0]
const SPIRAL: Vector2 = Vector2(984.0, 1236.0)
const RAILS: Vector2 = Vector2(1290.0, 1352.0)
## Kürbis: Trennwand (Schale) zwischen Innenweg (durch den Kürbis) und breiter Außenkurve.
const PUMPKIN: Vector2 = Vector2(1530.0, 1648.0)
const PUMPKIN_SIDE: float = -1.0
## Schale am Boden (Aufstandskreis des Tunnel-Kürbisses): Innenweg links davon 6,5 m breit.
const PUMPKIN_WALL_LATERAL: float = -4.5
const PUMPKIN_WALL_HALF: float = 0.55
const PUMPKIN_WEDGE: float = 7.0
const DANDELION_RAMP: Vector2 = Vector2(1752.0, 1764.0)
## Schirmchen-Ring: Innenradius (Durchflug zählt bis RING_RADIUS + 0,6 m um die Mitte).
const RING_RADIUS: float = 3.6
const GREENHOUSE: Vector2 = Vector2(1958.0, 2312.0)
## Röhre: Innenradius des Schlauchs über der Fahrbahnmitte (Kamera bleibt darin).
const HOSE_RADIUS: float = 7.6
const KART_RADIUS: float = 0.9
## Kinderkart-Breite: Wand 0,9 m innerhalb der Fahrbahnkante (wie Dschungelherz).
const WALL_INSET: float = 0.9


static func definition() -> Dictionary:
	var names: Array[String] = []
	for section in SECTIONS:
		names.append(str(section.name))
	return {
		"id": ID,
		"name": "Riesengarten",
		"subtitle": "Lumos Sommergarten · 2,4 Kilometer",
		"accent": Color("ffcf3a"),
		"asphalt": Color("a07a52"),
		"sky": Color("78c4f0"),
		"horizon": Color("e9f4d8"),
		"fog": Color("cfe6c8"),
		"sun": Color("fff0c8"),
		"ground": Color("5fa046"),
		"seed": 24002111,
		"points": PackedVector3Array(),
		"length_m": 2400.0,
		"road_width_m": 13.0,
		"section_names": names,
	}


# ------------------------------------------------------------------ Mittellinie


static func _pieces() -> Array:
	var out: Array = []
	for segment in SEGMENTS:
		if str(segment[0]) == "S":
			out.append([float(segment[1]), 0.0, 0.0])
			continue
		var angle: float = deg_to_rad(float(segment[1]))
		var radius: float = float(segment[2])
		var ramp: float = float(segment[3])
		var k: float = signf(angle) / radius
		out.append([ramp, 0.0, k])
		out.append([radius * absf(angle) - ramp, k, k])
		out.append([ramp, k, 0.0])
	return out


## Planare Punkte alle STEP Meter: [s, x, z, Kurswinkel, Krümmung].
static func planar_samples() -> Array:
	var x: float = 0.0
	var z: float = 0.0
	var a: float = 0.0
	var s: float = 0.0
	var result: Array = [[0.0, 0.0, 0.0, 0.0, 0.0]]
	for piece in _pieces():
		var piece_length: float = float(piece[0])
		var k0: float = float(piece[1])
		var k1: float = float(piece[2])
		var n: int = maxi(1, roundi(piece_length / STEP))
		var h: float = piece_length / float(n)
		for i in range(n):
			var km: float = k0 + (k1 - k0) * (float(i) + 0.5) / float(n)
			var mid: float = a + km * h * 0.5
			x += cos(mid) * h
			z -= sin(mid) * h
			a += km * h
			s += h
			result.append([s, x, z, a, km])
	return result


static func planar_length() -> float:
	var total: float = 0.0
	for piece in _pieces():
		total += float(piece[0])
	return total


static func _height_table(count: int) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in range(count):
		var s: float = float(i)
		var h: float = float(HEIGHT_KEYS[0][1])
		for k in range(HEIGHT_KEYS.size() - 1):
			var a: Array = HEIGHT_KEYS[k]
			var b: Array = HEIGHT_KEYS[k + 1]
			if s >= float(a[0]) and s <= float(b[0]):
				var u: float = (s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
				h = lerpf(float(a[1]), float(b[1]), u)
				break
		raw[i] = h
	for _pass in range(2):
		var blurred := PackedFloat32Array()
		blurred.resize(count)
		for i in range(count):
			var total: float = 0.0
			for j in range(-SMOOTH_RADIUS, SMOOTH_RADIUS + 1):
				total += raw[posmod(i + j, count)]
			blurred[i] = total / float(2 * SMOOTH_RADIUS + 1)
		raw = blurred
	return raw


static func height_at_planar(s: float, table: PackedFloat32Array) -> float:
	var count: int = table.size()
	var wrapped: float = fposmod(s, float(count))
	var i: int = floori(wrapped)
	return lerpf(table[i % count], table[(i + 1) % count], wrapped - float(i))


static func make_curve() -> Curve3D:
	var samples: Array = planar_samples()
	var total: float = planar_length()
	var table: PackedFloat32Array = _height_table(ceili(total) + 1)
	var points := PackedVector3Array()
	var stride: int = roundi(SAMPLE / STEP)
	for i in range(0, samples.size() - 1, stride):
		var sample: Array = samples[i]
		var s: float = float(sample[0])
		points.append(Vector3(float(sample[1]), height_at_planar(s, table), float(sample[2])))
	var curve := Curve3D.new()
	curve.bake_interval = 0.1
	for i in range(points.size() + 1):
		var n: int = i % points.size()
		var tangent: Vector3 = (
			(points[(n + 1) % points.size()] - points[posmod(n - 1, points.size())]) / 6.0
		)
		curve.add_point(points[n], -tangent, tangent)
	return curve


# ------------------------------------------------------------------ Breite, Wand, Neigung


static func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Weicher Übergang von a nach b zwischen from und to (Meter).
static func _blend(d: float, from: float, to: float) -> float:
	return _smooth((d - from) / maxf(to - from, 0.001))


static func width_at(distance: float) -> float:
	var d: float = fposmod(distance, LENGTH)
	var deck: float = PASSAGES.static_deck_half(ID, d)
	if deck > 0.0:
		return deck * 2.0
	var w: float = 13.0
	# Startgerade mit Startaufstellung (16 m), am Ziel wieder breit.
	w += 3.0 * (1.0 - _blend(d, 70.0, 120.0)) + 3.0 * _blend(d, 2340.0, 2390.0)
	# Gießkanne: Rumpf 11 m, Ausguss 8 m, Wasserrutsche 10 m, Landeblatt 18 m.
	w -= 2.0 * _blend(d, 380.0, 398.0) * (1.0 - _blend(d, 446.0, 447.0))
	if d >= 446.0 and d < 462.0:
		w = 8.0
	elif d >= 462.0 and d < LANDING.x:
		w = lerpf(8.0, 18.0, _blend(d, 462.0, 505.0))
	elif d >= LANDING.x and d < 640.0:
		w = lerpf(18.0, 14.0, _blend(d, 600.0, 640.0))
	elif d >= 640.0 and d < 730.0:
		w = 14.0
	# Schlauch 10 m, Topfspirale 11 m.
	w -= 3.0 * _blend(d, 718.0, 737.0) * (1.0 - _blend(d, 985.0, 1000.0))
	w -= 2.0 * _blend(d, 985.0, 1000.0) * (1.0 - _blend(d, 1236.0, 1256.0))
	# Kürbisbeet: Innenweg durch den Kürbis + breite Außenkurve (24 m).
	w += 11.0 * _blend(d, 1500.0, 1526.0) * (1.0 - _blend(d, 1652.0, 1680.0))
	# Gewächshaus: Gänge zwischen den Pflanztischen 11,5 m.
	w -= 1.5 * _blend(d, 1940.0, 1958.0) * (1.0 - _blend(d, 2312.0, 2330.0))
	return w


static func wall_at(distance: float) -> float:
	return width_at(distance) * 0.5 - WALL_INSET


## Kurvenneigung: Verstärkung und Grenze je Abschnitt (Röhre = Steilwand, Spirale mäßig).
static func bank_profile(distance: float) -> Vector2:
	var d: float = fposmod(distance, LENGTH)
	var hose: float = (
		_blend(d, HOSE.x - 10.0, HOSE.x + 14.0) * (1.0 - _blend(d, HOSE.y - 18.0, HOSE.y))
	)
	var spiral: float = (
		_blend(d, SPIRAL.x, SPIRAL.x + 20.0) * (1.0 - _blend(d, SPIRAL.y - 20.0, SPIRAL.y))
	)
	var gain: float = 0.68 + hose * (4.6 - 0.68) + spiral * (1.7 - 0.68)
	var limit: float = 0.14 + hose * (0.46 - 0.14) + spiral * (0.22 - 0.14)
	return Vector2(gain, limit)


static func frame(world: Node3D, distance: float) -> Basis:
	var ahead: Vector3 = world.forward(distance)
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(ahead).normalized()
	var bend: float = right.dot(world.forward(distance + 5.0) - ahead)
	var profile: Vector2 = bank_profile(distance)
	return Basis(right, up, -ahead).rotated(ahead, clampf(-bend * profile.x, -profile.y, profile.y))


static func section_at(distance: float) -> int:
	var d: float = fposmod(distance, LENGTH)
	for i in range(SECTIONS.size()):
		if d < float(SECTIONS[i].end):
			return i
	return SECTIONS.size() - 1


static func section_range(id: String) -> Vector2:
	for section in SECTIONS:
		if str(section.id) == id:
			return Vector2(float(section.start), float(section.end))
	return Vector2.ZERO


# ------------------------------------------------------------------ Rennelemente


## Turbofelder und Schanzen im selben Format wie kart_action_course (pads/kickers …).
static func action_plan(world: Node3D) -> Dictionary:
	var result: Dictionary = {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": []}
	# Tautropfen-Allee: links (innen) drei Tautropfen = Turbo, rechts bleibt frei.
	for start in [232.0, 262.0, 292.0]:
		result.pads.append({"start": start, "end": start + 6.0, "lateral": -3.4, "garden": "tau"})
	# Gartenschlauch: oben an der Außenwand der drei Steilkurven liegt ein Wandstreifen.
	for wall in hose_wall_pads(world):
		result.pads.append(wall)
	# Gießkanne: der Ausguss steigt an und wirft das Kart über den Seerosenteich.
	(
		result
		. kickers
		. append(
			{
				"start": CAN_SPOUT.x,
				"take_off": CAN_SPOUT.y,
				"length": CAN_SPOUT.y - CAN_SPOUT.x,
				"height": 2.2,
				"angle": atan2(2.2, CAN_SPOUT.y - CAN_SPOUT.x),
				"flight_gravity": 14.0,
				"lift_bonus": 5.0,
				"max_lift": 11.0,
				"hero_flight": true,
				"landing_road_end": LANDING.y,
				"garden": "kanne",
			}
		)
	)
	# Löwenzahn-Wiese: Aufwind – lange, weiche Flugphase mit Schirmchen-Ringen.
	(
		result
		. kickers
		. append(
			{
				"start": DANDELION_RAMP.x,
				"take_off": DANDELION_RAMP.y,
				"length": DANDELION_RAMP.y - DANDELION_RAMP.x,
				"height": 2.4,
				"angle": atan2(2.4, DANDELION_RAMP.y - DANDELION_RAMP.x),
				"flight_gravity": 10.0,
				"lift_bonus": 4.0,
				"max_lift": 10.0,
				"hero_flight": true,
				"landing_road_end": DANDELION_RAMP.y + 125.0,
				"garden": "loewenzahn",
			}
		)
	)
	return result


## Wandstreifen in den drei Schlauch-Steilkurven: außen, wo die Fahrbahn am höchsten liegt.
static func hose_wall_pads(world: Node3D) -> Array:
	var pads: Array = []
	for apex in HOSE_APEXES:
		var bend: float = world.frame(apex).x.dot(world.forward(apex + 5.0) - world.forward(apex))
		# Linkskurve (bend < 0): außen = rechts (+). Rechtskurve: außen = links.
		var outer: float = 1.0 if bend < 0.0 else -1.0
		(
			pads
			. append(
				{
					"start": apex - 9.0,
					"end": apex + 9.0,
					"lateral": outer * (wall_at(apex) - 0.9),
					"garden": "wand",
				}
			)
		)
	return pads


## Schirmchen-Ringe über der Löwenzahn-Wiese: Lage auf der Bahn, Höhe über der Fahrbahn.
static func dandelion_rings() -> Array:
	return [
		{"d": 1786.0, "lateral": 0.0, "height": 9.5},
		{"d": 1812.0, "lateral": -2.2, "height": 12.0},
		{"d": 1838.0, "lateral": 2.2, "height": 12.4},
		{"d": 1864.0, "lateral": 0.0, "height": 10.6},
	]


## Rasensprenger der zweiten Runde: Lage und neue Turbolinie durch die Wasserbögen.
static func sprinklers() -> Array:
	return [
		{"d": 196.0, "side": 1.0, "line": 1.6},
		{"d": 1716.0, "side": -1.0, "line": -1.6},
		{"d": 1900.0, "side": 1.0, "line": 1.8},
	]


## Sperrbereiche für die Sammelzonen (kart_item_zones.hazards): die Höhepunkte selbst.
static func item_hazards() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"start": CAN_BODY.x - 60.0, "end": LANDING.y + 10.0, "kind": "garden_kanne"},
		{"start": HOSE.x - 25.0, "end": HOSE.y + 8.0, "kind": "garden_schlauch"},
		{"start": SPIRAL.x, "end": SPIRAL.y + 12.0, "kind": "garden_topfspirale"},
	]
	for sprinkler in sprinklers():
		var at: float = float(sprinkler.d)
		result.append({"start": at - 34.0, "end": at + 26.0, "kind": "garden_sprenger"})
	return result


# ------------------------------------------------------------------ Kürbis-Schale


## Halbe Dicke der Kürbisschale zwischen Innenweg und Außenkurve (0 außerhalb).
static func pumpkin_wall_half(distance: float) -> float:
	var d: float = fposmod(distance, LENGTH)
	if d < PUMPKIN.x or d > PUMPKIN.y:
		return 0.0
	var grow: float = minf((d - PUMPKIN.x) / PUMPKIN_WEDGE, (PUMPKIN.y - d) / PUMPKIN_WEDGE)
	return PUMPKIN_WALL_HALF * clampf(grow, 0.0, 1.0)


## Schalenkante: Kartmitte darf nicht näher als wall_half + Kartradius an die Schale.
static func resolve_motion(world: Node3D, from: Vector3, desired: Vector3) -> Dictionary:
	var result: Dictionary = {"position": desired, "normal": Vector3.ZERO, "collided": false}
	var to_road: Dictionary = world.sample_road(desired)
	var d: float = float(to_road.distance)
	var half: float = pumpkin_wall_half(d)
	if half <= 0.0:
		return result
	var reach: float = half + KART_RADIUS
	var offset: float = float(to_road.lateral) - PUMPKIN_WALL_LATERAL
	if absf(offset) >= reach:
		return result
	# Bleib auf der Seite, von der das Kart kommt (vor der Spitze: die nähere Seite).
	var from_road: Dictionary = world.sample_road(from, d)
	var side: float = signf(float(from_road.lateral) - PUMPKIN_WALL_LATERAL)
	if side == 0.0:
		side = signf(offset) if offset != 0.0 else 1.0
	var basis: Basis = to_road.basis
	var push: float = side * reach - offset
	result.position = desired + basis.x * push
	result.normal = basis.x * side
	result.collided = true
	return result


# ------------------------------------------------------------------ Kamera


## Kamera bleibt im Schlauch, im Kürbis-Innenweg und unter dem Gewächshausdach.
static func clip_camera(world: Node3D, anchor: Vector3, desired: Vector3) -> Vector3:
	var anchor_road: Dictionary = world.sample_road(anchor)
	var road: Dictionary = world.sample_road(desired, float(anchor_road.distance))
	var d: float = float(road.distance)
	var basis: Basis = road.basis
	var centre: Vector3 = world.position_at(d)
	var lateral: float = (desired - centre).dot(basis.x)
	var elevation: float = (desired - centre).dot(basis.y)
	if d >= HOSE.x - 2.0 and d <= HOSE.y + 2.0:
		var limit: float = HOSE_RADIUS - 1.1
		var offset := Vector2(lateral, elevation - 2.2)
		if offset.length() > limit:
			offset = offset.normalized() * limit
		return centre + basis.x * offset.x + basis.y * (offset.y + 2.2)
	var in_can: bool = d >= CAN_BODY.x - 2.0 and d <= CAN_SPOUT.y + 1.0
	var in_greenhouse: bool = d >= GREENHOUSE.x and d <= GREENHOUSE.y
	if not in_can and not in_greenhouse:
		return desired
	var half: float = width_at(d) * 0.5 - 0.5
	var ceiling: float = 4.4 if d >= CAN_SPOUT.x else (8.5 if in_can else 13.0)
	return (
		centre + basis.x * clampf(lateral, -half, half) + basis.y * clampf(elevation, 1.0, ceiling)
	)
