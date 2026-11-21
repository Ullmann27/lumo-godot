extends Node3D
## The three rival pilots of the cloud race: the animal drivers of Lumo Kart in
## their own Sternsegler. They follow the smooth race line through all ring
## gates (they can never get stuck), keep their own lane, slow down in tight
## bends, sometimes take a ring boost and adapt their pace a little to Lumo so
## the race stays close but fair. Stages: Entdecken / Abenteuer / Extrem.

const GLIDER = preload("res://scripts/games/skypost/sky_post_glider.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const LANES: Array[float] = [-3.2, 3.2, 0.0]
const LAUNCH_SECONDS: float = 1.6

var layout
var stage: String = "entdecken"
var laps: int = 2
var line := PackedVector3Array()
var line_s := PackedFloat32Array()
var length: float = 0.0
var gate_s := PackedFloat32Array()
var rivals: Array[Dictionary] = []
var clock: float = 0.0
var running: bool = false
var reduced_motion: bool = false
var profile: String = "medium"


func setup(
	world_layout,
	stage_id: String,
	lap_count: int,
	calm: bool,
	world_profile: String,
	round_index: int
) -> void:
	layout = world_layout
	stage = stage_id
	laps = lap_count
	reduced_motion = calm
	profile = world_profile
	line = layout.race_line(2.0)
	line_s.resize(line.size() + 1)
	line_s[0] = 0.0
	for index in range(1, line.size() + 1):
		line_s[index] = line_s[index - 1] + line[index - 1].distance_to(line[index % line.size()])
	length = line_s[line.size()]
	gate_s.resize(layout.GATES.size())
	for gate in range(layout.GATES.size()):
		gate_s[gate] = line_s[layout.gate_sample(line, gate)]
	var roster: Array[Dictionary] = ROSTER.rotation("kart", round_index)
	var deck: Vector3 = layout.start_at
	for index in range(3):
		var entry: Dictionary = (
			roster[index % roster.size()]
			if not roster.is_empty()
			else {"id": "owl", "name": "Eule", "color": "#C7A585"}
		)
		var colour := Color(str(entry.get("color", "#9fb4d0")))
		var glider = GLIDER.new()
		glider.name = "Rival_" + str(entry.id)
		add_child(glider)
		glider.build(profile, colour.lightened(0.18), colour.darkened(0.42), calm)
		var seated: bool = glider.seat_pilot(str(entry.id))
		var label := Label3D.new()
		label.text = str(entry.name)
		label.font = FONT
		label.font_size = 64
		label.pixel_size = 0.012
		label.outline_size = 14
		label.modulate = colour.lightened(0.35)
		label.outline_modulate = Color("0b2247")
		label.position = Vector3(0, 2.9, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		glider.add_child(label)
		var start := (
			deck + Vector3(LANES[index] * 2.6, 3.0 + float(index) * 1.4, -6.0 - float(index) * 3.0)
		)
		var approach: float = start.distance_to(layout.GATES[0])
		(
			rivals
			. append(
				{
					"id": str(entry.id),
					"name": str(entry.name),
					"colour": colour,
					"glider": glider,
					"seated": seated,
					"start": start,
					"approach": approach,
					"d": -approach,
					"speed": 0.0,
					"pace":
					(
						float(TUNING.CRUISE.get(stage, 15.0))
						* float(TUNING.RIVAL_PACE.get(stage, 0.95))
						* TUNING.RIVAL_SPREAD[index]
					),
					"lane": LANES[index],
					"phase": float(index) * 2.1,
					"boost": 0.0,
					"finished": false,
					"finish_time": 0.0,
					"gates": 0,
					"next_gate": 0,
					"bank": 0.0,
					"stuck": 0.0,
				}
			)
		)
	place_all(0.0)


func start() -> void:
	running = true
	clock = 0.0


## Distance along the course of a point beyond the start (-approach .. laps * length).
func sample(d: float, rival: Dictionary) -> Vector3:
	if d < 0.0:
		var t: float = clampf(1.0 + d / float(rival.approach), 0.0, 1.0)
		return (rival.start as Vector3).lerp(layout.GATES[0], t)
	var s: float = fposmod(d, length)
	var index: int = _index_at(s)
	var a: float = line_s[index]
	var b: float = line_s[index + 1]
	var t: float = 0.0 if b - a < 0.001 else (s - a) / (b - a)
	return line[index].lerp(line[(index + 1) % line.size()], t)


func _index_at(s: float) -> int:
	var low: int = 0
	var high: int = line.size() - 1
	while low < high:
		var middle: int = (low + high + 1) / 2
		if line_s[middle] <= s:
			low = middle
		else:
			high = middle - 1
	return low


func tangent(d: float, rival: Dictionary) -> Vector3:
	var a: Vector3 = sample(d - 1.5, rival)
	var b: Vector3 = sample(d + 1.5, rival)
	return (b - a).normalized() if a.distance_squared_to(b) > 0.0001 else Vector3.FORWARD


## Advances the rivals; [param player_d] is Lumo's course distance (for fair pace).
func advance(delta: float, player_d: float, player_pos: Vector3) -> void:
	if not running:
		place_all(delta)
		return
	clock += delta
	for index in range(rivals.size()):
		var rival: Dictionary = rivals[index]
		var d: float = float(rival.d)
		var pace: float = float(rival.pace)
		var gap: float = d - player_d
		if not bool(rival.finished):
			# Fair, close races: a rival far ahead eases off, one far behind catches up a little.
			var ease: float = float(TUNING.RIVAL_EASE.get(stage, 0.86))
			pace *= lerpf(1.0, ease, clampf((gap - 15.0) / 45.0, 0.0, 1.0))
			pace *= lerpf(1.0, 1.08, clampf((-gap - 50.0) / 40.0, 0.0, 1.0))
		else:
			pace *= 0.75
		# Slow down in tight bends.
		var bend: float = tangent(d, rival).angle_to(tangent(d + 12.0, rival))
		pace *= 1.0 - clampf(bend * 0.35, 0.0, 0.16)
		var launch: float = clampf(clock / LAUNCH_SECONDS, 0.0, 1.0)
		if float(rival.boost) > 0.0:
			rival.boost = maxf(0.0, float(rival.boost) - delta)
			pace += 6.0
		rival.speed = lerpf(float(rival.speed), pace * launch, 1.0 - exp(-2.0 * delta))
		var before: float = d
		d += float(rival.speed) * delta
		rival.d = d
		rival.stuck = 0.0 if d > before + 0.01 else float(rival.stuck) + delta
		# Gates passed (course distance crossing a gate's distance).
		while not bool(rival.finished) and d >= gate_distance(int(rival.gates)):
			var gate: int = int(rival.gates) % layout.GATES.size()
			rival.gates = int(rival.gates) + 1
			if gate == 0 and int(rival.gates) > laps * layout.GATES.size():
				rival.finished = true
				rival.finish_time = clock
				rival.glider.celebrate()
			elif _boost_chance(index, int(rival.gates)):
				rival.boost = 0.9
		# Give Lumo room: rivals drift out of his way.
		var lane: float = float(rival.lane)
		var p: Vector3 = sample(d, rival)
		if p.distance_to(player_pos) < 4.0:
			lane += signf(lane + 0.01) * 2.0
		rival["current_lane"] = lerpf(
			float(rival.get("current_lane", lane)), lane, 1.0 - exp(-1.5 * delta)
		)
		_place(rival, delta)


## Course distance at which gate number [param passed] (0-based count) is reached.
func gate_distance(passed: int) -> float:
	var count: int = layout.GATES.size()
	return float(passed / count) * length + gate_s[passed % count]


func _boost_chance(index: int, gates: int) -> bool:
	var chance: float = {"entdecken": 0.15, "abenteuer": 0.35, "extrem": 0.55}.get(stage, 0.3)
	return fmod(float(gates * 7 + index * 3) * 0.6180339, 1.0) < chance


func place_all(delta: float) -> void:
	for rival in rivals:
		_place(rival, delta)


func _place(rival: Dictionary, delta: float) -> void:
	var d: float = float(rival.d)
	var p: Vector3 = sample(d, rival)
	var forward: Vector3 = tangent(d, rival)
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var weave: float = 0.0 if reduced_motion else sin(clock * 0.8 + float(rival.phase)) * 1.1
	var lane: float = float(rival.get("current_lane", rival.lane))
	var bob: float = sin(clock * 1.3 + float(rival.phase)) * 0.4
	if not running:
		bob = sin(Time.get_ticks_msec() * 0.002 + float(rival.phase)) * 0.25
	p += side * (lane + weave) + Vector3(0, bob, 0)
	var ahead: Vector3 = tangent(d + 8.0, rival)
	var turn: float = forward.cross(ahead).y
	var bank: float = clampf(-turn * 4.0, -0.55, 0.55)
	rival.bank = lerpf(float(rival.bank), bank, 1.0 - exp(-3.0 * maxf(delta, 0.016)))
	var basis := Basis.looking_at(forward, Vector3.UP) * Basis(Vector3.BACK, float(rival.bank))
	var glider: Node3D = rival.glider
	glider.global_transform = Transform3D(basis, p)
	var stick := Vector2(
		clampf(-float(rival.bank) / 0.55, -1.0, 1.0), clampf(forward.y * 2.0, -1.0, 1.0)
	)
	glider.animate(maxf(delta, 0.0), stick, float(rival.speed), float(rival.boost) > 0.0)


## Course distance ("d") of every rival plus finish data, for placings.
func standings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rival in rivals:
		result.append(
			{
				"name": rival.name,
				"d": rival.d,
				"finished": rival.finished,
				"finish_time": rival.finish_time
			}
		)
	return result


func finish_distance() -> float:
	return float(laps) * length


func set_suspended(value: bool) -> void:
	for rival in rivals:
		rival.glider.set_suspended(value)
