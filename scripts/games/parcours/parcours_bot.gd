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
var _turn_sign: float = 0.0


func _init(seed_value: int = 7, reaction_seconds: float = 0.32, noise_amount: float = 0.12) -> void:
	rng.seed = seed_value
	reaction = reaction_seconds
	noise = noise_amount


## Liefert {axis, brake, gas} für das Kart.
func drive_input(run, delta: float) -> Dictionary:
	var drive = run.drive
	if not _history.is_empty() and (_history[-1].pos as Vector3).distance_to(drive.position) > 8.0:
		# Nach einer Rettung: Fahrlinie ab dem nächstgelegenen Punkt neu aufnehmen.
		_history.clear()
		var best: float = INF
		for i in range(run.course.route.size()):
			var d: float = (run.course.route[i].pos as Vector3).distance_to(drive.position)
			if d < best:
				best = d
				target = i
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
		var passed: bool = to_here.dot(segment) < 0.0 and to_here.length() < 14.0 and absf(to_here.y) < 3.0
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
	if absf(error) > 2.4:
		# Verkehrt herum: entschlossen in eine Richtung wenden, nicht hin und her zappeln.
		if _turn_sign == 0.0:
			_turn_sign = -signf(error) if error != 0.0 else 1.0
		axis = _turn_sign
	else:
		_turn_sign = 0.0
	var cap: float = float(route[target].get("cap", 0.0))
	var brake: float = 0.0
	if cap > 0.0 and drive.speed > cap + 1.5:
		brake = 0.6
	if absf(error) > 0.9 and drive.speed > 9.0:
		brake = 0.8
	if gate_brake(run, float(seen.t), pos, float(seen.heading), drive.speed):
		brake = 1.0
	return {"axis": axis, "brake": brake, "gas": true}


## Zu Fuß: Wegpunkte der Station ablaufen, springen, wo die Route es verlangt, Hebel an
## Punkten mit `press` umlegen (beim Rätsel in der Reihenfolge, die das Tor zeigt).
func foot_input(run) -> Dictionary:
	var s: Dictionary = run.course.stations[run.station]
	var points: Array = s.foot_route
	var done: bool = run.station_done.has(run.station)
	if done:
		if foot_target < 100:
			foot_target = 100
		var back: Array = []
		for k in range(points.size() - 1, -1, -1):
			if bool(points[k].get("press", false)) and k == points.size() - 1:
				continue
			back.append({"pos": points[k].pos, "jump": bool(s.get("jump_back", true))})
		back.append({"pos": s.kart_pos})
		var index: int = foot_target - 100
		if index >= back.size():
			return {"move": Vector2.ZERO, "jump": false, "lever": false}
		return _follow(run, back[index], true)
	if foot_target >= points.size():
		return {"move": Vector2.ZERO, "jump": false, "lever": true}
	return _follow(run, points[foot_target], false)


func _follow(run, point: Dictionary, returning: bool) -> Dictionary:
	var p: Vector3 = point.pos
	var to: Vector3 = p - run.walker.position
	var flat: float = Vector2(to.x, to.z).length()
	if flat < 0.9 and absf(to.y) < 1.2 and run.walker.grounded:
		foot_target += 1
		var press: bool = bool(point.get("press", false)) and not returning
		return {"move": Vector2.ZERO, "jump": false, "lever": press}
	var jump: bool = (
		bool(point.get("jump", false)) and flat < float(point.get("jump_at", 3.4))
		and run.walker.grounded
	)
	return {"move": Vector2(to.x, to.z).normalized(), "jump": jump, "lever": false}


## Zeitgesteuerte Tore vor dem Kart: bremsen, wenn das Tor bei Ankunft zu ist.
func gate_brake(run, seen_t: float, pos: Vector3, heading: float, speed: float) -> bool:
	var course = run.course
	var ahead := Vector3(-sin(heading), 0.0, -cos(heading))
	for index in range(course.blockers.size()):
		var blocker: Dictionary = course.blockers[index]
		if not bool(blocker.get("timed", false)):
			continue
		var at: Vector3 = (blocker.base as Transform3D).origin
		var to: Vector3 = at - pos
		var along: float = to.dot(ahead)
		if along < 1.5 or along > 16.0 or absf(to.y) > 4.0:
			continue
		var side: float = (to - ahead * along).length()
		if side > float((blocker.size as Vector3).x) * 0.5 + 2.0:
			continue
		var eta: float = along / maxf(absf(speed), 4.0)
		for extra in [0.0, 0.35, 0.7]:
			if not course.timed_gate_open(index, seen_t + eta + extra):
				return true
	return false
