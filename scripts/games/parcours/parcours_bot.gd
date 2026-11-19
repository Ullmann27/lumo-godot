extends RefCounted
## Prüf-Fahrer wie ein Kind mit normaler Reaktion: sieht die Lage mit 250–400 ms
## Verzögerung, lenkt mit Rauschen und nutzt nur die echten Eingaben (Lenkachse,
## Bremse, Gas, Aussteigen, Hebel, Sprung). Er folgt der Fahrlinie der Welt.

var reaction: float = 0.32
var noise: float = 0.12
var rng := RandomNumberGenerator.new()
var target: int = 0
var foot_target: int = 0
var _history: Array[Dictionary] = []
var _noise_value: float = 0.0
var _noise_timer: float = 0.0
var max_route_distance: float = 0.0


func _init(seed_value: int = 7, reaction_seconds: float = 0.32, noise_amount: float = 0.12) -> void:
	rng.seed = seed_value
	reaction = reaction_seconds
	noise = noise_amount


## Liefert {axis, brake, gas} für das Kart.
func drive_input(run, delta: float) -> Dictionary:
	var drive = run.drive
	_history.append({"pos": drive.position, "heading": drive.heading, "t": run.t})
	while _history.size() > 2 and run.t - float(_history[1].t) >= reaction:
		_history.pop_front()
	var seen: Dictionary = _history[0]
	var route: Array = run.course.route
	var pos: Vector3 = seen.pos
	# Weiter, sobald der Punkt erreicht oder überholt ist.
	while target < route.size() - 1:
		var here: Vector3 = route[target].pos
		var next_point: Vector3 = route[target + 1].pos
		var to_here: Vector3 = here - pos
		var segment: Vector3 = next_point - here
		var passed: bool = to_here.dot(segment) < 0.0 and to_here.length() < 14.0
		if Vector2(to_here.x, to_here.z).length() < 4.5 and absf(to_here.y) < 3.5 or passed:
			target += 1
		else:
			break
	var aim: Vector3 = route[target].pos
	var to_aim: Vector3 = aim - pos
	var wanted: float = atan2(-to_aim.x, -to_aim.z)
	var error: float = angle_difference(float(seen.heading), wanted)
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = rng.randf_range(0.2, 0.5)
		_noise_value = rng.randf_range(-noise, noise)
	var axis: float = clampf(-error * 2.4 + _noise_value, -1.0, 1.0)
	var cap: float = float(route[target].get("cap", 0.0))
	var brake: float = 0.0
	if cap > 0.0 and drive.speed > cap + 1.5:
		brake = 0.6
	if absf(error) > 0.9 and drive.speed > 9.0:
		brake = 0.8
	return {"axis": axis, "brake": brake, "gas": true}


## Zu Fuß: Wegpunkte der Station ablaufen, springen, wo die Route es verlangt.
func foot_input(run) -> Dictionary:
	var s: Dictionary = run.course.stations[run.station]
	var points: Array = s.foot_route
	var done: bool = run.station_done.has(run.station)
	if done:
		# Zurück über dieselben Steine (jeder Sprung wieder nötig), dann zum Kart.
		var back: Array = []
		for k in range(points.size() - 2, -1, -1):
			back.append({"pos": points[k].pos, "jump": true})
		back.append({"pos": s.kart_pos})
		return _follow(run, back)
	if foot_target >= points.size():
		return {"move": Vector2.ZERO, "jump": false, "lever": true}
	return _follow(run, points)


func _follow(run, points: Array) -> Dictionary:
	if run.station_done.has(run.station) and foot_target < 100:
		foot_target = 100
	var index: int = foot_target - 100 if foot_target >= 100 else foot_target
	if index >= points.size():
		return {"move": Vector2.ZERO, "jump": false, "lever": not run.station_done.has(run.station)}
	var point: Dictionary = points[index]
	var p: Vector3 = point.pos
	var to: Vector3 = p - run.walker.position
	if Vector2(to.x, to.z).length() < 0.9 and absf(to.y) < 1.2 and run.walker.grounded:
		foot_target += 1
		return {"move": Vector2(to.x, to.z).normalized() * 0.3, "jump": false, "lever": false}
	var jump: bool = (
		bool(point.get("jump", false))
		and Vector2(to.x, to.z).length() < float(point.get("jump_at", 3.4))
		and run.walker.grounded
	)
	return {"move": Vector2(to.x, to.z).normalized(), "jump": jump, "lever": false}
