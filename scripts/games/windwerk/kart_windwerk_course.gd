extends RefCounted
## Three kilometres around a working wind railway. Survey points trace an outer
## downhill bend, the switchyard S, a high viaduct and a curling meadow return.
const ID := "windwerk_3000"
const LENGTH := 3000.0
const WIDTH := 15.0
const NAME := "Lumos Windwerk"
const OUTLINE := [
	Vector2(0, 210), Vector2(118, 210), Vector2(215, 182), Vector2(254, 113),
	Vector2(232, 51), Vector2(163, 24), Vector2(128, -24), Vector2(175, -76),
	Vector2(269, -86), Vector2(318, -142), Vector2(298, -213), Vector2(217, -251),
	Vector2(108, -236), Vector2(44, -187), Vector2(-29, -189), Vector2(-117, -250),
	Vector2(-209, -269), Vector2(-271, -219), Vector2(-263, -142), Vector2(-191, -96),
	Vector2(-140, -41), Vector2(-160, 13), Vector2(-243, 37), Vector2(-291, 86),
	Vector2(-274, 157), Vector2(-191, 200), Vector2(-103, 210)
]
# Distance anchors use the horizontal route before the final metre calibration.
const HEIGHT := [
	Vector2(0, 36), Vector2(40, 36), Vector2(350, 9), Vector2(570, 13),
	Vector2(905, 15), Vector2(1175, 38), Vector2(1450, 40), Vector2(1630, 24),
	Vector2(1830, 14), Vector2(2040, 22), Vector2(2420, 22), Vector2(2650, 36),
	Vector2(2810, 42), Vector2(2970, 36), Vector2(3000, 36)
]
# The whole approach belongs to the sign and trial. Keep item banks and
# unrelated slowing encounters away from the choice of line.
const TRIALS := [
	{"start": 600.0, "end": 960.0, "kind": "weichen"},
	{"start": 2090.0, "end": 2440.0, "kind": "signalwerk"}
]
const SECTION_NAMES := ["Mühlenbahnhof", "Turbinental", "Weichenwerk", "Himmelsviadukt",
	"Flügelwiesen", "Signalwerkstatt", "Heimkehr zur Mühle"]


static func definition() -> Dictionary:
	return {"id": ID, "name": NAME, "subtitle": "Mit der Windbahn über das Turbinental",
		"accent": Color("45d3bd"), "asphalt": Color("4d6271"), "sky": Color("5296ce"),
		"horizon": Color("ffdaa7"), "fog": Color("b7d9cf"), "sun": Color("fff0cb"),
		"ground": Color("73ae85"), "seed": 30002211, "length_m": LENGTH, "road_width_m": WIDTH,
		"section_names": SECTION_NAMES, "points": PackedVector3Array()}


static func _closed_curve(points: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = .22
	for i in range(points.size() + 1):
		var n := i % points.size()
		var tangent := (points[(n + 1) % points.size()] - points[posmod(n - 1, points.size())]) / 6.0
		curve.add_point(points[n], -tangent, tangent)
	return curve


static func elevation(metres: float) -> float:
	for i in range(1, HEIGHT.size()):
		var end: Vector2 = HEIGHT[i]
		if metres <= end.x:
			var begin: Vector2 = HEIGHT[i - 1]
			return lerpf(begin.y, end.y, smoothstep(begin.x, end.x, metres))
	return HEIGHT[0].y


static func make_curve() -> Curve3D:
	var flat := PackedVector3Array()
	for p: Vector2 in OUTLINE:
		flat.append(Vector3(p.x, 0, p.y))
	var plan := _closed_curve(flat)
	var scale := LENGTH / plan.get_baked_length()
	var points := PackedVector3Array()
	for i in range(375):
		var metres := i * 8.0
		var at := plan.sample_baked(metres / scale, true) * scale
		at.y = elevation(metres)
		points.append(at)
	var road := _closed_curve(points)
	for iteration in range(2):
		var ratio := LENGTH / road.get_baked_length()
		for i in range(road.point_count):
			road.set_point_position(i, road.get_point_position(i) * ratio)
			road.set_point_in(i, road.get_point_in(i) * ratio)
			road.set_point_out(i, road.get_point_out(i) * ratio)
	return road


static func action_plan() -> Dictionary:
	var plan := {"pads": [], "gates": [], "kickers": [], "dives": [], "edges": [], "trials": TRIALS}
	# Each optional sprint line re-enters the broad, continuous road.
	for point: Vector2 in [Vector2(70, -2.8), Vector2(132, 1.8), Vector2(335, 3.4),
			Vector2(483, -3.2), Vector2(1035, -2.5), Vector2(1190, 2.1), Vector2(1555, -2.5),
			Vector2(1710, 3.0), Vector2(1935, -2.7), Vector2(2510, 2.6), Vector2(2810, 0)]:
		plan.pads.append({"start": point.x, "end": point.x + 6.5, "lateral": point.y})
	for start: float in [390.0, 1458.0, 2668.0]:
		plan.kickers.append({"start": start, "take_off": start + 12, "length": 12.0,
			"height": 1.45, "angle": atan2(1.45, 12.0), "flight_gravity": 22.0,
			"lift_bonus": 2.2, "max_lift": 7.0, "landing_road_end": start + 95.0})
	return plan
