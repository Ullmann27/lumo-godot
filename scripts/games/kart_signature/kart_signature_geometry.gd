extends RefCounted
## Mittellinie, Höhen und Breiten der Signatur-Strecken (Vulkanexpress, Wolkensturm,
## Kristallflut). Jede Strecke beschreibt ihren Kurs als Schildkrötenpfad wie der
## Riesengarten: Geraden {"s": m} und Kurven {"turn": Grad, "r": Radius, "ramp": m} mit
## Klothoiden-Übergang (die Krümmung steigt linear an und ab, die Querneigung rollt ohne Ruck
## ein). Zwei Geraden {"free": true} schließen die Runde: ihre Längen löst close() exakt aus
## einer 2×2-Gleichung (Summe aller Wege = 0). Positive Winkel = Linkskurve von oben.
## "h" an einem Stück ist die Fahrbahnhöhe an seinem Ende (Meter über Normalnull der Welt);
## dazwischen linear, danach zweimal geglättet (Radius SMOOTH_RADIUS Meter).

const STEP: float = 0.5
const SAMPLE: float = 2.0
const SMOOTH_RADIUS: int = 14
const MIN_FREE: float = 8.0
static var _cache: Dictionary = {}


static func _turn_pieces(segment: Dictionary) -> Array:
	var angle: float = deg_to_rad(float(segment.turn))
	var radius: float = float(segment.r)
	var ramp: float = float(segment.get("ramp", 20.0))
	var k: float = signf(angle) / radius
	var arc: float = radius * absf(angle) - ramp
	assert(arc > 0.0, "Kurve zu kurz für ihren Übergang")
	return [[ramp, 0.0, k], [arc, k, k], [ramp, k, 0.0]]


## Stücke [Länge, Krümmung Anfang, Krümmung Ende, Segment-Index].
static func _raw_pieces(course) -> Array:
	var out: Array = []
	var segments: Array = course.SEGMENTS
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if segment.has("turn"):
			for piece in _turn_pieces(segment):
				out.append([float(piece[0]), float(piece[1]), float(piece[2]), index])
		elif segment.has("free"):
			out.append([-1.0, 0.0, 0.0, index])
		else:
			out.append([float(segment.s), 0.0, 0.0, index])
	return out


static func _integrate(pieces: Array, frees: Array) -> Dictionary:
	var x: float = 0.0
	var z: float = 0.0
	var a: float = 0.0
	var headings: Array[float] = []
	var free_index: int = 0
	for piece in pieces:
		var piece_length: float = float(piece[0])
		if piece_length < 0.0:
			headings.append(a)
			piece_length = float(frees[free_index]) if free_index < frees.size() else 0.0
			free_index += 1
			x += cos(a) * piece_length
			z -= sin(a) * piece_length
			continue
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
	return {"x": x, "z": z, "a": a, "headings": headings}


## Längen der zwei freien Geraden, die die Runde exakt schließen.
static func close(course) -> Vector2:
	var pieces: Array = _raw_pieces(course)
	var open: Dictionary = _integrate(pieces, [0.0, 0.0])
	# Eine Schleife (±360°) oder Schleife plus Turmspirale (±720°, eine Überführung).
	var turns: float = absf(float(open.a)) / TAU
	assert(
		turns > 0.5 and absf(turns - roundf(turns)) < 0.0001,
		"%s: Kurswinkel %.3f° ist kein Vielfaches von 360°" % [course.ID, rad_to_deg(float(open.a))]
	)
	var headings: Array = open.headings
	assert(headings.size() == 2, "%s: genau zwei freie Geraden" % course.ID)
	var u := Vector2(cos(float(headings[0])), -sin(float(headings[0])))
	var v := Vector2(cos(float(headings[1])), -sin(float(headings[1])))
	var target := Vector2(-float(open.x), -float(open.z))
	var det: float = u.x * v.y - u.y * v.x
	assert(absf(det) > 0.05, "%s: freie Geraden fast parallel" % course.ID)
	var l1: float = (target.x * v.y - target.y * v.x) / det
	var l2: float = (u.x * target.y - u.y * target.x) / det
	assert(
		l1 >= MIN_FREE and l2 >= MIN_FREE,
		"%s: freie Geraden %.1f / %.1f m – Kurs umplanen" % [course.ID, l1, l2]
	)
	return Vector2(l1, l2)


static func pieces(course) -> Array:
	var frees: Vector2 = close(course)
	var result: Array = []
	var free_index: int = 0
	for piece in _raw_pieces(course):
		var entry: Array = piece.duplicate()
		if float(entry[0]) < 0.0:
			entry[0] = frees.x if free_index == 0 else frees.y
			free_index += 1
		result.append(entry)
	return result


## Planare Punkte alle STEP Meter: [s, x, z, Kurswinkel, Segment-Index].
static func planar_samples(course) -> Array:
	var x: float = 0.0
	var z: float = 0.0
	var a: float = 0.0
	var s: float = 0.0
	var result: Array = [[0.0, 0.0, 0.0, 0.0, 0]]
	for piece in pieces(course):
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
			result.append([s, x, z, a, int(piece[3])])
	return result


## Planare Länge am Ende jedes Segments (für Höhen und den Entwurfsbericht).
static func segment_ends(course) -> Array[float]:
	var ends: Array[float] = []
	var segments: Array = course.SEGMENTS
	ends.resize(segments.size())
	var s: float = 0.0
	for piece in pieces(course):
		s += float(piece[0])
		ends[int(piece[3])] = s
	return ends


static func _height_table(course, count: int) -> PackedFloat32Array:
	var keys: Array = [[0.0, float(course.START_HEIGHT)]]
	var ends: Array[float] = segment_ends(course)
	var segments: Array = course.SEGMENTS
	for index in range(segments.size()):
		if segments[index].has("h"):
			keys.append([ends[index], float(segments[index].h)])
	keys.append([ends[ends.size() - 1], float(course.START_HEIGHT)])
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in range(count):
		var s: float = float(i)
		var h: float = float(keys[keys.size() - 1][1])
		for k in range(keys.size() - 1):
			var a: Array = keys[k]
			var b: Array = keys[k + 1]
			if s >= float(a[0]) and s <= float(b[0]):
				var u: float = (s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
				h = lerpf(float(a[1]), float(b[1]), u)
				break
		raw[i] = h
	for _pass in range(2):
		var blurred := PackedFloat32Array()
		blurred.resize(count)
		var total: float = 0.0
		for j in range(-SMOOTH_RADIUS, SMOOTH_RADIUS + 1):
			total += raw[posmod(j, count)]
		for i in range(count):
			blurred[i] = total / float(2 * SMOOTH_RADIUS + 1)
			total += (
				raw[posmod(i + SMOOTH_RADIUS + 1, count)] - raw[posmod(i - SMOOTH_RADIUS, count)]
			)
		raw = blurred
	return raw


static func _height_at(s: float, table: PackedFloat32Array) -> float:
	var count: int = table.size()
	var wrapped: float = fposmod(s, float(count))
	var i: int = floori(wrapped)
	return lerpf(table[i % count], table[(i + 1) % count], wrapped - float(i))


## 3D-Stützpunkte alle SAMPLE Meter (planar) und ihre Meter auf der fertigen Fahrbahn.
static func polyline(course) -> Dictionary:
	var key: String = str(course.ID)
	if _cache.has(key):
		return _cache[key]
	var samples: Array = planar_samples(course)
	var total: float = float(samples[samples.size() - 1][0])
	var table: PackedFloat32Array = _height_table(course, ceili(total))
	var points := PackedVector3Array()
	var planar := PackedFloat32Array()
	var stride: int = roundi(SAMPLE / STEP)
	for i in range(0, samples.size() - 1, stride):
		var sample: Array = samples[i]
		var s: float = float(sample[0])
		points.append(Vector3(float(sample[1]), _height_at(s, table), float(sample[2])))
		planar.append(s)
	var result: Dictionary = {"points": points, "planar": planar, "planar_length": total}
	_cache[key] = result
	return result


static func make_curve(course) -> Curve3D:
	var points: PackedVector3Array = polyline(course).points
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	for i in range(points.size() + 1):
		var n: int = i % points.size()
		var tangent: Vector3 = (
			(points[(n + 1) % points.size()] - points[posmod(n - 1, points.size())]) / 6.0
		)
		curve.add_point(points[n], -tangent, tangent)
	return curve


## Ungefähre Fahrbahnmeter zu einem planaren Meter (Entwurfsbericht; ±0,3 m).
static func final_metres(course, planar_s: float) -> float:
	var line: Dictionary = polyline(course)
	var points: PackedVector3Array = line.points
	var planar: PackedFloat32Array = line.planar
	var travelled: float = 0.0
	for i in range(1, points.size()):
		if planar[i] >= planar_s:
			var u: float = (planar_s - planar[i - 1]) / maxf(planar[i] - planar[i - 1], 0.001)
			return travelled + points[i - 1].distance_to(points[i]) * u
		travelled += points[i - 1].distance_to(points[i])
	return travelled


# ------------------------------------------------------------------ Breite


static func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Breite je Fahrbahnmeter aus WIDTH_KEYS [[m, Breite], …] (weich dazwischen, umlaufend).
static func width_table(course) -> PackedFloat32Array:
	var key: String = str(course.ID) + "_width"
	if _cache.has(key):
		return _cache[key]
	var keys: Array = course.WIDTH_KEYS
	var count: int = ceili(float(course.LENGTH)) + 2
	var table := PackedFloat32Array()
	table.resize(count)
	for i in range(count):
		var d: float = float(i)
		var w: float = float(keys[keys.size() - 1][1])
		if d < float(keys[0][0]):
			w = float(keys[0][1])
		for k in range(keys.size() - 1):
			var a: Array = keys[k]
			var b: Array = keys[k + 1]
			if d >= float(a[0]) and d <= float(b[0]):
				w = lerpf(
					float(a[1]),
					float(b[1]),
					_smooth((d - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
				)
				break
		table[i] = w
	_cache[key] = table
	return table


static func width_at(course, distance: float) -> float:
	var table: PackedFloat32Array = width_table(course)
	var d: float = fposmod(distance, float(course.LENGTH))
	var i: int = mini(floori(d), table.size() - 2)
	return lerpf(table[i], table[i + 1], d - float(i))
