extends RefCounted
## Action-Parcours je Runde: Turbo-Felder, Slalom-Tore, Sprungschanze, Unterwasser-Tunnel und
## offene Kanten, von denen man fallen kann (die Lumo-Wolke setzt das Kart fair zurück).
## Alle Elemente liegen in lokaler Rundendistanz (0 … Länge) und meiden Start/Ziel, Sprunglücke
## und Looping. Sonnenhafen bleibt vorerst unverändert: Er ist Referenz- und Prüfstrecke des
## vollständigen Android-Rennablaufs.

const PAD_LENGTH: float = 6.0
const PAD_HALF_WIDTH: float = 1.4
const PAD_BOOST_SECONDS: float = 1.0
const GATE_COUNT: int = 4
const GATE_SPACING: float = 16.0
const GATE_LANE: float = 1.8
const GATE_HALF_WIDTH: float = 2.0
const PYLON_RADIUS: float = 0.55
const SLALOM_BOOST_SECONDS: float = 1.3
const KICKER_LENGTH: float = 7.0
const KICKER_HEIGHT: float = 1.1
const DIVE_SPEED: float = 0.9
const EDGE_LENGTH: float = 30.0
## Abstand zu Start/Ziel, Sprung und Looping, damit sich Elemente nie überlagern.
const CLEARANCE: float = 14.0

## Lage der Elemente als Anteil der Runde. Die Fahrt prüft jede Lage noch gegen Sprung und Looping.
const COURSES: Dictionary = {
	"zauberwald": {"pads": [0.16, 0.66], "slalom": 0.28, "kicker": 0.84, "dive": [0.38, 0.46]},
	"bergwelt": {"pads": [0.21, 0.93], "slalom": 0.45},
	"holo_city": {"pads": [0.12, 0.57], "slalom": 0.31, "kicker": 0.80},
	"crystal_canyon": {"pads": [0.15, 0.62], "slalom": 0.27, "kicker": 0.84, "edges": [0.66]},
	"jungle_temple": {"pads": [0.14, 0.60], "slalom": 0.27, "kicker": 0.82, "dive": [0.40, 0.48]},
	"candy_cloud": {"pads": [0.14, 0.60], "slalom": 0.25, "kicker": 0.88, "edges": [0.31]},
	"volcano_night": {"pads": [0.14, 0.64], "slalom": 0.26, "kicker": 0.88, "edges": [0.33]},
	"winter_sprint": {"pads": [0.14, 0.62], "slalom": 0.26, "kicker": 0.84, "dive": [0.66, 0.74]},
	"galaxy_ringway": {"pads": [0.14, 0.64], "slalom": 0.24, "kicker": 0.88, "edges": [0.56]},
	"desert_drift": {"pads": [0.15, 0.62], "slalom": 0.30, "kicker": 0.82, "dive": [0.43, 0.51]},
	"learning_lab": {"pads": [0.15, 0.62], "slalom": 0.30, "kicker": 0.82},
}
const THEMES: Dictionary = {
	"zauberwald": {"water": Color("2fb7a0"), "name": "Feensee"},
	"jungle_temple": {"water": Color("2aa3a6"), "name": "Tempelfluss"},
	"winter_sprint": {"water": Color("5fb8ff"), "name": "Eissee"},
	"desert_drift": {"water": Color("2fc2d6"), "name": "Oase"},
}


## Plant die Elemente einer Welt; leer für Strecken ohne Parcours.
static func plan(world) -> Dictionary:
	var course: Dictionary = COURSES.get(str(world.track_id), {})
	var length: float = float(world.length)
	var result: Dictionary = {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": []}
	if course.is_empty() or length <= 0.0:
		return result
	var blocked: Array = _blocked_ranges(world, length)
	var taken: Array = []
	var pad_lane: float = -2.2
	for fraction in course.get("pads", []):
		var start: float = _free_start(float(fraction) * length, PAD_LENGTH, length, blocked, taken)
		if start >= 0.0:
			result.pads.append({"start": start, "end": start + PAD_LENGTH, "lateral": pad_lane})
			taken.append(Vector2(start, start + PAD_LENGTH))
			pad_lane = -pad_lane
	if course.has("slalom"):
		var span: float = GATE_SPACING * float(GATE_COUNT)
		var start: float = _free_start(float(course.slalom) * length, span, length, blocked, taken)
		if start >= 0.0:
			for index in range(GATE_COUNT):
				var lane: float = GATE_LANE if index % 2 == 0 else -GATE_LANE
				result.gates.append({
					"distance": start + GATE_SPACING * (float(index) + 0.5), "lateral": lane, "index": index
				})
			taken.append(Vector2(start, start + span))
	if course.has("kicker"):
		var start: float = _free_start(float(course.kicker) * length, KICKER_LENGTH + 10.0, length, blocked, taken)
		if start >= 0.0:
			result.kickers.append({
				"start": start, "take_off": start + KICKER_LENGTH, "height": KICKER_HEIGHT,
				"angle": atan2(KICKER_HEIGHT, KICKER_LENGTH)
			})
			taken.append(Vector2(start, start + KICKER_LENGTH + 10.0))
	if course.has("dive"):
		var range_fractions: Array = course.dive
		var dive_start: float = float(range_fractions[0]) * length
		var dive_length: float = (float(range_fractions[1]) - float(range_fractions[0])) * length
		var start: float = _free_start(dive_start, dive_length, length, blocked, taken)
		if start >= 0.0:
			result.dives.append({"start": start, "end": start + dive_length})
			taken.append(Vector2(start, start + dive_length))
	for fraction in course.get("edges", []):
		var start: float = _free_start(float(fraction) * length, EDGE_LENGTH, length, blocked, taken)
		if start >= 0.0:
			var middle: float = start + EDGE_LENGTH * 0.5
			var ahead: Vector3 = world.forward(middle)
			var right: Vector3 = ahead.cross(Vector3.UP).normalized()
			var bend: float = right.dot(world.forward(middle + 6.0) - ahead)
			# Die offene Seite liegt außen in der Kurve, wo man beim Rutschen hinausgetragen wird.
			var side: float = -1.0 if bend > 0.0 else 1.0
			result.edges.append({"start": start, "end": start + EDGE_LENGTH, "side": side})
			taken.append(Vector2(start, start + EDGE_LENGTH))
	return result


static func _blocked_ranges(world, length: float) -> Array:
	var blocked: Array = [Vector2(length - 30.0, length), Vector2(0.0, 35.0)]
	var jump: Dictionary = world.jump
	if not jump.is_empty():
		blocked.append(Vector2(float(jump.ramp_start) - CLEARANCE, float(jump.gap_end) + CLEARANCE))
	var loop: Dictionary = world.loop_layout
	if not loop.is_empty():
		blocked.append(Vector2(float(loop.start) - CLEARANCE, float(loop.start) + 70.0))
	return blocked


## Erste freie Lage ab der Wunschdistanz (in 4-m-Schritten, höchstens ±120 m); -1 ohne Platz.
static func _free_start(wish: float, span: float, length: float, blocked: Array, taken: Array) -> float:
	for step in range(61):
		var offset: float = floorf(float(step + 1) / 2.0) * 4.0 * (1.0 if step % 2 == 0 else -1.0)
		var start: float = wish + offset
		if start < 0.0 or start + span > length:
			continue
		var free: bool = true
		for zone in blocked + taken:
			var area: Vector2 = zone
			if start < area.y + CLEARANCE * 0.5 and start + span > area.x - CLEARANCE * 0.5:
				free = false
				break
		if free:
			return start
	return -1.0


# ------------------------------------------------------------------ Abfragen für die Fahrt

static func kicker_height(course: Dictionary, distance: float) -> float:
	for kicker in course.get("kickers", []):
		if distance >= float(kicker.start) and distance < float(kicker.take_off):
			return (distance - float(kicker.start)) / KICKER_LENGTH * float(kicker.height)
	return 0.0


static func kicker_pitch(course: Dictionary, distance: float) -> float:
	for kicker in course.get("kickers", []):
		if distance >= float(kicker.start) and distance < float(kicker.take_off):
			return float(kicker.angle)
	return 0.0


## Die Schanze, deren Absprungkante zwischen zwei Fahrschritten überquert wurde.
static func kicker_crossed(course: Dictionary, previous: float, current: float) -> Dictionary:
	for kicker in course.get("kickers", []):
		var edge: float = float(kicker.take_off)
		if previous >= float(kicker.start) and previous < edge and current >= edge and current < edge + 6.0:
			return kicker
	return {}


static func pad_at(course: Dictionary, distance: float, lateral: float) -> int:
	var pads: Array = course.get("pads", [])
	for index in range(pads.size()):
		var pad: Dictionary = pads[index]
		if distance >= float(pad.start) and distance < float(pad.end) and absf(lateral - float(pad.lateral)) <= PAD_HALF_WIDTH:
			return index
	return -1


## Tore, deren Linie zwischen zwei Fahrschritten vorwärts überquert wurde.
static func gates_crossed(course: Dictionary, previous: float, current: float) -> Array:
	var crossed: Array = []
	if current <= previous or current - previous > 6.0:
		return crossed
	for gate in course.get("gates", []):
		var line: float = float(gate.distance)
		if previous < line and current >= line:
			crossed.append(gate)
	return crossed


## Querlage der zwei Hütchen eines Tors.
static func pylon_laterals(gate: Dictionary) -> Array[float]:
	var lane: float = float(gate.lateral)
	return [lane - GATE_HALF_WIDTH, lane + GATE_HALF_WIDTH]


static func dive_at(course: Dictionary, distance: float) -> bool:
	for dive in course.get("dives", []):
		if distance >= float(dive.start) and distance < float(dive.end):
			return true
	return false


## +1/-1: Auf dieser Seite fehlt die Leitplanke; 0: überall Leitplanke.
static func open_side(course: Dictionary, distance: float) -> float:
	for edge in course.get("edges", []):
		if distance >= float(edge.start) and distance < float(edge.end):
			return float(edge.side)
	return 0.0


# ------------------------------------------------------------------ Darstellung

static func build(world) -> void:
	var course: Dictionary = world.action
	if course.is_empty():
		return
	var accent: Color = world.definition.accent
	for pad in course.pads:
		_build_pad(world, pad, accent)
	for gate in course.gates:
		_build_gate(world, gate, accent)
	for kicker in course.kickers:
		_build_kicker(world, kicker, accent)
	for dive in course.dives:
		_build_dive(world, dive)
	for edge in course.edges:
		_build_edge(world, edge)


static func _build_pad(world, pad: Dictionary, accent: Color) -> void:
	var middle: float = (float(pad.start) + float(pad.end)) * 0.5
	var basis: Basis = world.frame(middle)
	var base: Vector3 = world.position_at(middle, float(pad.lateral)) + basis.y * 0.03
	# Leuchtende Fläche mit hellem Rahmen, gut sichtbar schon von Weitem.
	world._prop("box", base, Vector3(PAD_HALF_WIDTH * 2.0, 0.03, PAD_LENGTH), Color("1fd8ff"), basis, true)
	for side in [-1.0, 1.0]:
		var rail: Vector3 = world.position_at(middle, float(pad.lateral) + side * (PAD_HALF_WIDTH + 0.08)) + basis.y * 0.05
		world._prop("box", rail, Vector3(0.16, 0.06, PAD_LENGTH), Color("fff6c2"), basis, true)
	# Vier große Pfeile zeigen in Fahrtrichtung.
	for arrow in range(4):
		var along: float = float(pad.start) + 0.9 + float(arrow) * 1.4
		var arrow_basis: Basis = world.frame(along)
		for side in [-1.0, 1.0]:
			var tilted: Basis = arrow_basis.rotated(arrow_basis.y, side * 0.70)
			var at: Vector3 = world.position_at(along, float(pad.lateral) + side * 0.48) + arrow_basis.y * 0.07
			world._prop("box", at, Vector3(0.30, 0.04, 1.35), Color("ffe45c").lerp(accent, 0.15), tilted, true)


static func _build_gate(world, gate: Dictionary, accent: Color) -> void:
	var distance: float = float(gate.distance)
	var basis: Basis = world.frame(distance)
	for lateral in pylon_laterals(gate):
		var foot: Vector3 = world.position_at(distance, lateral)
		# Großes Hütchen mit weißen Ringen und einem Leuchtfähnchen obendrauf.
		world._prop("cone", foot + basis.y * 0.62, Vector3(0.62, 1.24, 0.62), Color("ff7a1f"), basis)
		for ring in range(2):
			world._prop("cylinder", foot + basis.y * (0.42 + float(ring) * 0.34), Vector3(0.50 - float(ring) * 0.14, 0.11, 0.50 - float(ring) * 0.14), Color("fbfbf3"), basis)
		world._prop("box", foot + basis.y * 0.04, Vector3(0.95, 0.08, 0.95), Color("2b2f3a"), basis)
		world._prop("box", foot + basis.y * 1.42 + basis.x * 0.18, Vector3(0.36, 0.22, 0.03), accent, basis, true)
	# Leuchtband zeigt die Gasse, durch die man fahren soll.
	var band: Vector3 = world.position_at(distance, float(gate.lateral)) + basis.y * 0.03
	world._prop("box", band, Vector3(GATE_HALF_WIDTH * 2.0 - 1.0, 0.03, 0.45), Color("7dffb2"), basis, true)


static func _build_kicker(world, kicker: Dictionary, accent: Color) -> void:
	var steps: int = 7
	for step in range(steps):
		var along: float = float(kicker.start) + (float(step) + 0.5) * KICKER_LENGTH / float(steps)
		var basis: Basis = world.frame(along)
		var rise: float = (float(step) + 0.5) / float(steps) * float(kicker.height)
		var slab: Basis = basis.rotated(basis.x, float(kicker.angle))
		var at: Vector3 = world.position_at(along) + basis.y * (rise * 0.5)
		var color: Color = Color("f7c84a") if step % 2 == 0 else Color("23324a")
		world._prop("box", at, Vector3(9.2, maxf(0.08, rise), KICKER_LENGTH / float(steps) + 0.05), color, slab)
	var lip: float = float(kicker.take_off) - 0.2
	var lip_basis: Basis = world.frame(lip)
	world._prop("box", world.position_at(lip) + lip_basis.y * float(kicker.height), Vector3(9.4, 0.08, 0.3), accent, lip_basis, true)


static func _build_dive(world, dive: Dictionary) -> void:
	var theme: Dictionary = THEMES.get(str(world.track_id), {"water": Color("2fb7d6")})
	var water: Color = theme.water
	var start: float = float(dive.start)
	var end: float = float(dive.end)
	var along: float = start
	var ring: int = 0
	while along < end:
		var basis: Basis = world.frame(along)
		var centre: Vector3 = world.position_at(along)
		# Aquarium-Tunnel: leuchtende Wasserwände und Wasserdecke, helle Glasrippen.
		for side in [-1.0, 1.0]:
			var wall: Vector3 = world.position_at(along, side * 6.4) + basis.y * 2.1
			world._prop("box", wall, Vector3(0.18, 4.2, 4.05), water.darkened(0.25 if ring % 2 == 0 else 0.15), basis, true)
			world._prop("box", world.position_at(along, side * 6.25) + basis.y * 2.1, Vector3(0.12, 4.3, 0.18), Color("dff8ff"), basis, true)
		world._prop("box", centre + basis.y * 4.3, Vector3(13.0, 0.2, 4.05), water.darkened(0.35), basis, true)
		world._prop("box", centre + basis.y * 4.18, Vector3(12.8, 0.06, 0.2), Color("dff8ff"), basis, true)
		if ring % 2 == 0:
			# Fische und Luftblasen an den Wänden, nie in der Fahrspur.
			for side in [-1.0, 1.0]:
				var fish_at: Vector3 = world.position_at(along + 1.0, side * 6.05) + basis.y * (1.4 + float(ring % 3) * 0.7)
				world._prop("ball", fish_at, Vector3(0.18, 0.12, 0.34), Color("ffb02e") if ring % 4 == 0 else Color("ff6fb5"), basis, true)
				for bubble in range(3):
					var bubble_at: Vector3 = world.position_at(along + float(bubble) * 1.2, side * 5.8) + basis.y * (0.8 + float(bubble) * 0.9)
					world._prop("ball", bubble_at, Vector3.ONE * (0.07 + float(bubble) * 0.02), Color("f2fdff"), basis, true)
		along += 4.0
		ring += 1
	for side in [-1.0, 1.0]:
		var sign_basis: Basis = world.frame(start - 3.0)
		world._prop("ball", world.position_at(start - 3.0, side * 5.8) + sign_basis.y * 3.0, Vector3.ONE * 0.4, water.lightened(0.45), sign_basis, true)


static func _build_edge(world, edge: Dictionary) -> void:
	var side: float = float(edge.side)
	var along: float = float(edge.start)
	var index: int = 0
	while along < float(edge.end):
		var basis: Basis = world.frame(along)
		# Breite gelb-schwarze Warnstreifen und eine leuchtende Kante: hier fehlt die Leitplanke.
		var stripe: Color = Color("ffd23a") if index % 2 == 0 else Color("1b1d26")
		world._prop("box", world.position_at(along, side * 5.25) + basis.y * 0.035, Vector3(0.7, 0.07, 1.0), stripe, basis, index % 2 == 0)
		world._prop("box", world.position_at(along, side * 5.62) + basis.y * 0.02, Vector3(0.08, 0.05, 1.02), Color("ff4a3c"), basis, true)
		if index % 5 == 0:
			world._prop("cone", world.position_at(along, side * 4.85) + basis.y * 0.42, Vector3(0.4, 0.84, 0.4), Color("ff5a3c"), basis)
		along += 1.0
		index += 1
	# Warnschild vor der Kante.
	var sign_at: float = float(edge.start) - 6.0
	var sign_basis: Basis = world.frame(sign_at)
	var post: Vector3 = world.position_at(sign_at, side * 6.2)
	world._prop("box", post + sign_basis.y * 1.0, Vector3(0.14, 2.0, 0.14), Color("dfe6ee"), sign_basis)
	world._prop("box", post + sign_basis.y * 2.15, Vector3(1.2, 0.8, 0.06), Color("ffd23a"), sign_basis, true)
	world._prop("box", post + sign_basis.y * 2.15 + sign_basis.z * -0.04, Vector3(0.18, 0.5, 0.03), Color("1b1d26"), sign_basis)
