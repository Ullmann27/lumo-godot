extends RefCounted
## Wolkenhafen as data: floating islands, the six post districts with three
## houses each, landmarks, updrafts, the ring course of the cloud race, star
## sparks and photo spots. Deterministic; the world builder only refines the
## ground height of placed objects (refine_heights). All flight rules (soft
## collisions, the cloud cushion, the wind wall) read their shapes from here.
## Coordinates: metres, Y up, the post office deck points along -Z.

## Island model radius (m) at scale 1 and depth below its top; see build_world.py.
const MODEL_RADIUS: float = 10.0
const MODEL_DEPTH: float = 14.9
const CLOUD_FLOOR: float = -30.0
const CLOUD_SEA_Y: float = -42.0
const CEILING: float = 95.0
const WIND_WALL: float = 235.0

## id, display name, model 1..3, top centre, scale, yaw.
const ISLANDS: Array[Dictionary] = [
	{
		"id": "hafen",
		"name": "Hafeninsel",
		"model": 1,
		"at": Vector3(0, 0, 0),
		"scale": 3.0,
		"yaw": 0.4
	},
	{
		"id": "muschel",
		"name": "Muschelbucht",
		"model": 2,
		"at": Vector3(72, -8, 24),
		"scale": 1.55,
		"yaw": 1.2
	},
	{
		"id": "garten",
		"name": "Gartenhof",
		"model": 3,
		"at": Vector3(-62, 6, 48),
		"scale": 1.6,
		"yaw": 2.1
	},
	{
		"id": "muehle",
		"name": "Windmühlenhügel",
		"model": 1,
		"at": Vector3(-112, 16, -36),
		"scale": 2.1,
		"yaw": 2.9
	},
	{
		"id": "leucht",
		"name": "Leuchtturmklippe",
		"model": 3,
		"at": Vector3(96, 20, -112),
		"scale": 2.1,
		"yaw": 0.9
	},
	{
		"id": "markt",
		"name": "Wolkenmarkt",
		"model": 2,
		"at": Vector3(-18, 28, -150),
		"scale": 1.7,
		"yaw": 4.0
	},
	{
		"id": "himmel",
		"name": "Himmelsdorf",
		"model": 1,
		"at": Vector3(36, 40, 104),
		"scale": 1.6,
		"yaw": 5.1
	},
	# Small islands without houses: trees, crystals, places to explore.
	{"id": "klein1", "name": "", "model": 2, "at": Vector3(40, 18, -52), "scale": .7, "yaw": .3},
	{"id": "klein2", "name": "", "model": 3, "at": Vector3(-46, 14, -62), "scale": .8, "yaw": 1.7},
	{"id": "klein3", "name": "", "model": 1, "at": Vector3(128, 4, -10), "scale": .75, "yaw": 2.6},
	{"id": "klein4", "name": "", "model": 2, "at": Vector3(-100, 30, 64), "scale": .9, "yaw": 3.3},
	{"id": "klein5", "name": "", "model": 3, "at": Vector3(-6, -14, 62), "scale": .6, "yaw": 4.4},
	{"id": "klein6", "name": "", "model": 1, "at": Vector3(70, 52, 40), "scale": .6, "yaw": 5.0},
	{"id": "klein7", "name": "", "model": 2, "at": Vector3(-150, 6, -90), "scale": .85, "yaw": .9},
	{"id": "klein8", "name": "", "model": 3, "at": Vector3(30, 36, -180), "scale": .7, "yaw": 2.2},
]

## Post districts in delivery order of the full tour (stage Abenteuer/Extrem).
## island: index into ISLANDS; facing: angle (rad) the house row looks to.
const DISTRICTS: Array[Dictionary] = [
	{"island": 1, "name": "Muschelbucht", "facing": 3.6, "houses": ["a", "b", "a"]},
	{"island": 4, "name": "Leuchtturmklippe", "facing": 3.9, "houses": ["b", "a", "a"]},
	{"island": 5, "name": "Wolkenmarkt", "facing": 0.4, "houses": ["a", "a", "b"]},
	{"island": 3, "name": "Windmühlenhügel", "facing": 0.9, "houses": ["a", "b", "a"]},
	{"island": 2, "name": "Gartenhof", "facing": 5.6, "houses": ["b", "a", "b"]},
	{"island": 6, "name": "Himmelsdorf", "facing": 2.6, "houses": ["a", "b", "a"]},
]

## x, z, radius, top of the column. The bottom lies in the cloud sea.
const UPDRAFTS: Array[Vector4] = [
	Vector4(84, -50, 7.5, 50),
	Vector4(-8, -102, 7.0, 52),
	Vector4(18, 62, 7.5, 62),
	Vector4(-92, 8, 7.0, 44),
	Vector4(42, -16, 6.5, 30),
	Vector4(-130, -86, 6.5, 40),
]

## Ring gates of the cloud race, a closed loop; gate 0 is start and finish.
const GATES: Array[Vector3] = [
	Vector3(0, 6, -44),
	Vector3(28, 12, -86),
	Vector3(68, 22, -94),
	Vector3(122, 30, -78),
	Vector3(118, 14, -24),
	Vector3(84, 6, 26),
	Vector3(40, 12, 66),
	Vector3(-4, 22, 92),
	Vector3(-52, 18, 82),
	Vector3(-98, 26, 22),
	# Back over the harbour island, so the finish line is flown straight on
	# (no hairpin at the start ring next to the post office deck).
	Vector3(-70, 22, -6),
	Vector3(-18, 16, 4),
]

## Photo spots of the free flight: frame position and what it looks at.
const PHOTOS: Array[Dictionary] = [
	{
		"name": "Leuchtturm im Morgenlicht",
		"at": Vector3(62, 36, -88),
		"look": Vector3(96, 34, -118)
	},
	{"name": "Windmühle im Wind", "at": Vector3(-84, 28, -10), "look": Vector3(-114, 26, -40)},
	{"name": "Zeppelin am Mast", "at": Vector3(42, 20, -6), "look": Vector3(18, 16, 6)},
	{"name": "Uhr am Postamt", "at": Vector3(-14, 16, -16), "look": Vector3(0, 13, 0)},
	{"name": "Unter den Inseln", "at": Vector3(10, -20, -8), "look": Vector3(0, -14, 0)},
	{"name": "Himmelsdorf von oben", "at": Vector3(24, 66, 86), "look": Vector3(36, 42, 104)},
]

## Hidden golden sparks of the free flight (special places).
const SECRETS: Array[Vector3] = [
	Vector3(96, 38, -108),
	Vector3(101, 37.5, -115),
	Vector3(91, 37.5, -116),
	Vector3(-112, 30, -50),
	Vector3(-100, 24, -30),
	Vector3(18, 19, 22),
	Vector3(22, 17, 0),
	Vector3(0, -10, 0),
	Vector3(-6, -18, 6),
	Vector3(5, -24, -4),
	Vector3(72, -14, 24),
	Vector3(-62, -2, 48),
	Vector3(-18, 20, -150),
	Vector3(36, 33, 104),
	Vector3(0, 22, 0),
	Vector3(0, 3, -26),
	Vector3(84, 48, -50),
	Vector3(-8, 50, -102),
	Vector3(18, 60, 62),
	Vector3(40, 15, -52),
	Vector3(-46, 10, -62),
	Vector3(-150, 2, -90),
	Vector3(70, 49, 40),
	Vector3(30, 33, -180),
]

const HOUSE_SPREAD: float = 0.62
const HOUSE_RING: float = 0.5

var islands: Array[Dictionary] = []
## One entry per house: district, slot (0..2), kind, pos, yaw, mailbox, board.
var houses: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
## Obstacles: Vector4(x, z, radius, top) vertical cylinders from their island down.
var pillars: Array[Dictionary] = []
var post_deck: Dictionary = {}
var start_at := Vector3.ZERO
var start_yaw: float = 0.0


static func build():
	var made = load("res://scripts/games/skypost/sky_post_layout.gd").new()
	made._make()
	return made


func _make() -> void:
	for entry in ISLANDS:
		var island: Dictionary = entry.duplicate()
		island["radius"] = MODEL_RADIUS * float(entry.scale)
		island["depth"] = MODEL_DEPTH * float(entry.scale) * 0.85
		islands.append(island)
	# Post office near the north edge of the harbour island, deck over the edge.
	var office := Vector3(0, ground_estimate(0, Vector2(0, -8)), -8)
	landmarks.append({"model": "postamt", "pos": office, "yaw": 0.0, "island": 0})
	post_deck = {"pos": office + Vector3(0, 0.95, -17.0), "yaw": 0.0}
	start_at = office + Vector3(0, 2.4, -14.0)
	start_yaw = 0.0
	pillars.append({"at": office + Vector3(0, 0, 0.5), "r": 6.6, "top": office.y + 10.0})
	pillars.append({"at": office + Vector3(0, 0, 1.2), "r": 2.6, "top": office.y + 21.0})
	var mast := Vector3(20, ground_estimate(0, Vector2(20, 8)), 8)
	landmarks.append({"model": "zeppelinmast", "pos": mast, "yaw": 1.9, "island": 0})
	pillars.append({"at": mast, "r": 2.2, "top": mast.y + 16.0})
	var mill := _on_island(3, 0.42, float(DISTRICTS[3].facing) + PI)
	landmarks.append(
		{
			"model": "windmuehle",
			"pos": mill,
			"yaw": float(DISTRICTS[3].facing) + PI * 0.15,
			"island": 3
		}
	)
	pillars.append({"at": mill, "r": 3.6, "top": mill.y + 11.5})
	var tower := _on_island(4, 0.4, float(DISTRICTS[1].facing) + PI)
	landmarks.append(
		{"model": "leuchtturm", "pos": tower, "yaw": float(DISTRICTS[1].facing), "island": 4}
	)
	pillars.append({"at": tower, "r": 3.4, "top": tower.y + 20.5})
	for index in range(DISTRICTS.size()):
		var district: Dictionary = DISTRICTS[index]
		var facing: float = float(district.facing)
		for slot in range(3):
			var angle: float = (
				facing
				+ (float(slot) - 1.0) * HOUSE_SPREAD * (1.25 if district.island in [3, 4] else 1.0)
			)
			var island_index: int = int(district.island)
			var pos: Vector3 = _on_island(island_index, HOUSE_RING, angle)
			var outward := Vector3(sin(angle), 0, cos(angle))
			var yaw: float = atan2(-outward.x, -outward.z)
			var front: Vector3 = pos + outward * 4.6
			var side := Vector3(outward.z, 0, -outward.x)
			var mailbox: Vector3 = front + side * 1.6
			mailbox.y = ground_estimate(island_index, Vector2(mailbox.x, mailbox.z))
			var board: Vector3 = front - side * 1.5
			board.y = ground_estimate(island_index, Vector2(board.x, board.z))
			(
				houses
				. append(
					{
						"district": index,
						"slot": slot,
						"kind": district.houses[slot],
						"pos": pos,
						"yaw": yaw,
						"mailbox": mailbox,
						"board": board,
						"outward": outward,
					}
				)
			)
			pillars.append({"at": pos, "r": 3.0, "top": pos.y + 7.6})


## A point on island [param index] at [param share] of its radius, direction [param angle].
func _on_island(index: int, share: float, angle: float) -> Vector3:
	var island: Dictionary = islands[index]
	var r: float = float(island.radius) * share
	var at: Vector3 = island.at
	var flat := Vector2(at.x + sin(angle) * r, at.z + cos(angle) * r)
	return Vector3(flat.x, ground_estimate(index, flat), flat.y)


## Height of the meadow of island [param index] at [param flat] (x, z), from the
## shape the Blender script builds (dome 0.55 m * scale at the centre).
func ground_estimate(index: int, flat: Vector2) -> float:
	var island: Dictionary = islands[index]
	var at: Vector3 = island.at
	var f: float = clampf(flat.distance_to(Vector2(at.x, at.z)) / float(island.radius), 0.0, 1.0)
	return at.y + 0.58 * float(island.scale) * (1.0 - f * f)


## Replaces estimated heights by the measured ones; [param probe] is a Callable
## (Vector3) -> float giving the real meadow height or NAN.
func refine_heights(probe: Callable) -> void:
	for house in houses:
		for key in ["pos", "mailbox", "board"]:
			var p: Vector3 = house[key]
			var y: float = probe.call(p)
			if not is_nan(y):
				p.y = y
				house[key] = p
	for landmark in landmarks:
		var p: Vector3 = landmark.pos
		var y: float = probe.call(p)
		if not is_nan(y):
			p.y = y
			landmark.pos = p


func district_count() -> int:
	return DISTRICTS.size()


func district_centre(index: int) -> Vector3:
	var island: Dictionary = islands[int(DISTRICTS[index].island)]
	return island.at


func district_houses(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for house in houses:
		if int(house.district) == index:
			result.append(house)
	return result


## Gate frame: origin at the gate, -Z the direction of flight through it.
func gate_frame(index: int) -> Transform3D:
	var count: int = GATES.size()
	var here: Vector3 = GATES[index]
	var ahead: Vector3 = GATES[(index + 1) % count]
	var behind: Vector3 = GATES[(index - 1 + count) % count]
	var direction: Vector3 = (
		((ahead - here).normalized() + (here - behind).normalized()).normalized()
	)
	direction.y = clampf(direction.y, -0.35, 0.35)
	return Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), here)


## Smooth race line through all gates (closed Catmull-Rom), sampled every [param step] m.
func race_line(step: float = 2.0) -> PackedVector3Array:
	var points := PackedVector3Array()
	var count: int = GATES.size()
	for index in range(count):
		var p0: Vector3 = GATES[(index - 1 + count) % count]
		var p1: Vector3 = GATES[index]
		var p2: Vector3 = GATES[(index + 1) % count]
		var p3: Vector3 = GATES[(index + 2) % count]
		var pieces: int = maxi(2, ceili(p1.distance_to(p2) / step))
		for piece in range(pieces):
			var t: float = float(piece) / float(pieces)
			var t2: float = t * t
			var t3: float = t2 * t
			points.append(
				(
					0.5
					* (
						(2.0 * p1)
						+ (-p0 + p2) * t
						+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
					)
				)
			)
	return points


## Index of the first race-line sample of gate [param gate].
func gate_sample(line: PackedVector3Array, gate: int) -> int:
	var best: int = 0
	var best_d: float = INF
	for index in range(line.size()):
		var d: float = line[index].distance_squared_to(GATES[gate])
		if d < best_d:
			best_d = d
			best = index
	return best


# ------------------------------------------------------------------ soft collisions


## Pushes [param p] (glider centre) out of islands, buildings, the cloud floor
## and the wind wall. Returns {pos, normal, kind} where kind is "" when nothing
## was touched, else "island", "building", "cushion", "ceiling" or "wall".
func resolve(p: Vector3, clearance: float = 1.6) -> Dictionary:
	var kind: String = ""
	var normal := Vector3.ZERO
	for island_index in range(islands.size()):
		var island: Dictionary = islands[island_index]
		var at: Vector3 = island.at
		var radius: float = float(island.radius)
		var flat := Vector2(p.x - at.x, p.z - at.z)
		var distance: float = flat.length()
		if distance > radius + clearance + 2.0:
			continue
		var top: float = (
			ground_estimate(island_index, Vector2(p.x, p.z)) + 0.35 * float(island.scale)
		)
		var depth: float = float(island.depth)
		var bottom: float = at.y - depth
		if p.y > top + clearance or p.y < bottom - clearance:
			continue
		# Radius of the rock body at this height (cone tapering to the tip).
		var below: float = clampf((at.y - p.y) / depth, 0.0, 1.0)
		var body: float = radius * (1.0 - pow(below, 1.15)) * 0.95 + clearance
		if distance >= body:
			continue
		var up_room: float = top + clearance - p.y
		var side_room: float = body - distance
		if up_room <= side_room or p.y > at.y - 1.0:
			p.y = top + clearance
			normal = Vector3.UP
		else:
			var away := Vector2(1, 0) if distance < 0.01 else flat / distance
			p.x = at.x + away.x * body
			p.z = at.z + away.y * body
			normal = Vector3(away.x, 0, away.y)
		kind = "island"
	for pillar in pillars:
		var at: Vector3 = pillar.at
		var r: float = float(pillar.r) + clearance * 0.6
		var flat := Vector2(p.x - at.x, p.z - at.z)
		var distance: float = flat.length()
		if distance >= r or p.y > float(pillar.top) + clearance or p.y < at.y - 2.0:
			continue
		if float(pillar.top) + clearance - p.y < r - distance:
			p.y = float(pillar.top) + clearance
			normal = Vector3.UP
		else:
			var away := Vector2(1, 0) if distance < 0.01 else flat / distance
			p.x = at.x + away.x * r
			p.z = at.z + away.y * r
			normal = Vector3(away.x, 0, away.y)
		kind = "building"
	if p.y < CLOUD_FLOOR:
		p.y = CLOUD_FLOOR
		normal = Vector3.UP
		kind = "cushion"
	elif p.y > CEILING:
		p.y = CEILING
		normal = Vector3.DOWN
		kind = "ceiling"
	var flat_len: float = Vector2(p.x, p.z).length()
	if flat_len > WIND_WALL:
		var inward := -Vector2(p.x, p.z) / flat_len
		p.x = -inward.x * WIND_WALL
		p.z = -inward.y * WIND_WALL
		normal = Vector3(inward.x, 0, inward.y)
		kind = "wall"
	return {"pos": p, "normal": normal, "kind": kind}


## True when [param p] is inside something solid (used by tests and spark placement).
func blocked(p: Vector3, clearance: float = 1.0) -> bool:
	return str(resolve(p, clearance).kind) in ["island", "building"]


func updraft_lift(p: Vector3) -> float:
	var lift: float = 0.0
	for column in UPDRAFTS:
		var d: float = Vector2(p.x - column.x, p.z - column.y).length()
		if d < column.z and p.y < column.w:
			var core: float = 1.0 - d / column.z
			lift = maxf(lift, smoothstep(0.0, 0.5, core) * clampf((column.w - p.y) / 6.0, 0.0, 1.0))
	return lift


# ------------------------------------------------------------------ sparks


## Star sparks along the race line (three per stretch between gates).
func race_sparks() -> PackedVector3Array:
	var result := PackedVector3Array()
	var count: int = GATES.size()
	for index in range(count):
		var a: Vector3 = GATES[index]
		var b: Vector3 = GATES[(index + 1) % count]
		for k in range(3):
			var p: Vector3 = (
				a.lerp(b, (float(k) + 1.0) / 4.0) + Vector3(0, sin(float(index + k)) * 1.2, 0)
			)
			if not blocked(p, 2.0):
				result.append(p)
	return result


## Star sparks along the delivery legs (start -> district -> ... -> post office).
func delivery_sparks(route: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	var stops: Array[Vector3] = [start_at + Vector3(0, 4, -20)]
	for district in route:
		stops.append(district_centre(int(district)) + Vector3(0, 12, 0))
	stops.append(start_at + Vector3(0, 6, -30))
	for index in range(stops.size() - 1):
		var a: Vector3 = stops[index]
		var b: Vector3 = stops[index + 1]
		var length: float = a.distance_to(b)
		var steps: int = clampi(int(length / 26.0), 2, 6)
		for k in range(1, steps):
			var t: float = float(k) / float(steps)
			var p: Vector3 = a.lerp(b, t) + Vector3(0, sin(t * PI) * 6.0, 0)
			if not blocked(p, 2.5):
				result.append(p)
	for column in UPDRAFTS:
		for k in range(3):
			var p := Vector3(column.x, column.w - 14.0 + float(k) * 6.0, column.y)
			if not blocked(p, 2.0):
				result.append(p)
	return result
