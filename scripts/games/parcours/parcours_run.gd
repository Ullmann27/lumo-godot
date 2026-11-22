extends RefCounted
## Ein Lauf durch eine Parcours-Welt, ohne Knoten und ohne Bild: Kurszeit, Kart, Fuß-
## abschnitte, Checkpoints, Rettung, Sterne, Geheimwege, Ansagen und Ziel. Die Szene
## (parcours_game.gd) zeichnet nur, was hier passiert; die Tests fahren denselben Lauf.

const DRIVE = preload("res://scripts/games/parcours/parcours_drive.gd")
const WALKER = preload("res://scripts/games/parcours/parcours_walker.gd")
const STAR_RADIUS: float = 1.9
const PLAY_STYLES: Array[String] = ["zeitlauf", "erkunden", "rennen"]

var course
var drive = DRIVE.new()
var walker = WALKER.new()
## Mechanik-Zustände (Aufzüge, Hebel, Tore). Wird gespeichert und wiederhergestellt.
var state: Dictionary = {}
var t: float = 0.0
var elapsed: float = 0.0
var play_style: String = "zeitlauf"
var checkpoint: int = 0
var reached: Dictionary = {}
var stars_taken: Dictionary = {}
var secrets_found: Dictionary = {}
var skills_seen: Dictionary = {}
var last_skill: int = -1
var resets: int = 0
var falls: int = 0
var finished: bool = false
var on_foot: bool = false
var station: int = -1
var station_done: Dictionary = {}
## Ereignisse dieses Schritts für Szene und Tests: [{kind, text, …}].
var events: Array[Dictionary] = []
var finish_order_ok: bool = false
var shared_lift: bool = false


func setup(target_course, style: String = "zeitlauf") -> void:
	course = target_course
	play_style = style if style in PLAY_STYLES else "zeitlauf"
	state = course.mechanisms.duplicate(true)
	drive.pace = float(course.pace)
	drive.place(course.start.pos, float(course.start.heading))
	drive.boosts = 1
	reached = {0: true}
	checkpoint = 0


## Ein Fahr- bzw. Lauf-Schritt. Eingaben wie im Kart: Lenkachse, Bremse, Gas.
func step(
	delta: float,
	axis: float,
	braking: float,
	manual_gas: bool,
	auto_gas: bool,
	move: Vector2 = Vector2.ZERO
) -> void:
	events.clear()
	if finished:
		return
	var t0: float = t
	t += delta
	elapsed += delta
	var slab: int = -1 if drive.airborne or drive.hit.is_empty() else int(drive.hit.slab)
	var along: float = 0.0 if slab < 0 else float(drive.hit.along)
	if on_foot:
		slab = -1
	if not shared_lift:
		course.update_mechanics(state, t, slab, along)
	if on_foot:
		walker.step(delta, move, course, t0, t, state)
		_foot_logic()
		if walker.fallen:
			_foot_reset()
		return
	var throttle: float = 1.0 if auto_gas or manual_gas else 0.0
	drive.step(delta, axis, braking, throttle, manual_gas, course, t0, t, state)
	for e in drive.events:
		events.append({"kind": e})
	if drive.fallen:
		falls += 1
		reset_to_checkpoint(true)
		return
	_progress(drive.position)
	var at_station: int = course.station_at(drive.position)
	if at_station != station:
		station = at_station
		if station >= 0 and not station_done.has(station):
			events.append({"kind": "station", "text": str(course.stations[station].intro)})


func _progress(p: Vector3) -> void:
	var cp: int = course.checkpoint_at(p)
	if cp > checkpoint:
		checkpoint = cp
		reached[cp] = true
		if play_style == "rennen":
			drive.boosts = maxi(1, drive.boosts)
		events.append({"kind": "checkpoint", "id": str(course.checkpoints[cp].id)})
	for index in range(course.stars.size()):
		if stars_taken.has(index):
			continue
		if p.distance_to(course.stars[index].pos as Vector3) <= STAR_RADIUS:
			stars_taken[index] = true
			events.append({"kind": "star", "index": index})
	for index in range(course.secrets.size()):
		if secrets_found.has(index):
			continue
		var secret: Dictionary = course.secrets[index]
		if p.distance_to(secret.pos as Vector3) <= float(secret.radius):
			secrets_found[index] = true
			events.append({"kind": "secret", "text": "Geheimweg gefunden: %s!" % secret.name})
	for plate in course.plates:
		var key: String = str(plate.mechanism)
		if bool(state.get(key, false)):
			continue
		if p.distance_to(plate.pos as Vector3) <= float(plate.radius):
			state[key] = true
			state[key + "_at"] = t
			events.append({"kind": "plate", "text": str(plate.text)})
	var skill: int = course.skill_at(p)
	if skill >= 0 and not skills_seen.has(skill):
		skills_seen[skill] = true
		last_skill = skill
		events.append({"kind": "skill", "text": str(course.skills[skill].intro)})
	elif skill >= 0:
		last_skill = skill
	var goal: Dictionary = course.finish
	if p.distance_to(goal.pos as Vector3) <= float(goal.radius):
		# Ziel zählt nur, wenn alle Checkpoints der Reihe nach erreicht wurden.
		finish_order_ok = reached.size() >= course.checkpoints.size()
		if finish_order_ok:
			finished = true
			events.append({"kind": "finish"})


## Freundliche Rettung: zurück zum letzten Checkpoint, Sterne bleiben.
func reset_to_checkpoint(after_fall: bool = false) -> void:
	var c: Dictionary = course.checkpoints[checkpoint]
	drive.place(c.pos as Vector3, float(c.heading))
	resets += 1
	var text: String = "Die Lumo-Wolke hat dich aufgefangen. Weiter geht's!"
	if after_fall and last_skill >= 0:
		text = str(course.skills[last_skill].retry)
	events.append({"kind": "reset", "text": text, "fall": after_fall})


## Aussteigen an einer Station: Lumo läuft los, das Kart bleibt stehen.
func can_leave_kart() -> bool:
	return (
		not on_foot
		and station >= 0
		and not station_done.has(station)
		and not drive.airborne
		and absf(drive.speed) < 4.0
	)


func leave_kart() -> bool:
	if not can_leave_kart():
		return false
	var s: Dictionary = course.stations[station]
	on_foot = true
	drive.speed = 0.0
	drive.velocity = Vector3.ZERO
	walker.place(s.foot_start as Vector3, float(s.get("foot_heading", drive.heading)))
	events.append({"kind": "leave", "text": str(s.foot_intro)})
	return true


func can_enter_kart() -> bool:
	if not on_foot or station < 0:
		return false
	var s: Dictionary = course.stations[station]
	return (
		station_done.has(station)
		and walker.position.distance_to(s.kart_pos as Vector3) <= float(s.radius) + 2.0
	)


func enter_kart() -> bool:
	if not can_enter_kart():
		return false
	on_foot = false
	events.append({"kind": "enter", "text": "Einsteigen und weiter!"})
	return true


## Hebel einer Station: eine Liste (Rätsel, Reihenfolge in `order`) oder ein einzelner.
static func station_levers(s: Dictionary) -> Array:
	if s.has("levers"):
		return s.levers
	return [{"pos": s.lever}]


func nearest_lever(s: Dictionary) -> int:
	var levers: Array = station_levers(s)
	var best: int = -1
	var best_distance: float = 2.4
	for i in range(levers.size()):
		var d: float = walker.position.distance_to(levers[i].pos as Vector3)
		if d <= best_distance:
			best = i
			best_distance = d
	return best


## Aktionstaste zu Fuß: Hebel umlegen, wenn Lumo davor steht. Beim Rätsel zählt die
## Reihenfolge; ein falscher Hebel setzt freundlich zurück (Lumo gibt einen Tipp).
func use_lever() -> bool:
	if not on_foot or station < 0 or station_done.has(station):
		return false
	var s: Dictionary = course.stations[station]
	var lever: int = nearest_lever(s)
	if lever < 0:
		return false
	var sid: String = str(s.id)
	var order: Array = s.get("order", [0])
	var step: int = int(state.get(sid + "_step", 0))
	if lever != int(order[step]):
		state[sid + "_step"] = 0
		for i in range(station_levers(s).size()):
			state["%s_lever_%d" % [sid, i]] = false
		events.append(
			{"kind": "lever_wrong", "text": str(s.get("hint", "Probier einen anderen Hebel."))}
		)
		return true
	state["%s_lever_%d" % [sid, lever]] = true
	step += 1
	state[sid + "_step"] = step
	if step < order.size():
		events.append({"kind": "lever_ok", "text": "Richtig! Noch %d." % (order.size() - step)})
		return true
	station_done[station] = true
	var mechanism: String = str(s.mechanism)
	state[mechanism] = true
	state[mechanism + "_at"] = t
	events.append({"kind": "lever", "text": str(s.done_text)})
	return true


func _foot_logic() -> void:
	if station < 0:
		return
	var s: Dictionary = course.stations[station]
	if not station_done.has(station) and nearest_lever(s) >= 0:
		if not bool(state.get("near_lever", false)):
			events.append({"kind": "near_lever", "text": "Drück auf HEBEL!"})
		state["near_lever"] = true
	else:
		state["near_lever"] = false


func _foot_reset() -> void:
	var s: Dictionary = course.stations[station]
	walker.place(s.foot_start as Vector3, float(s.get("foot_heading", 0.0)))
	resets += 1
	falls += 1
	events.append({"kind": "reset", "text": str(s.foot_retry), "fall": true})


func position() -> Vector3:
	return walker.position if on_foot else drive.position


func secret_star_count() -> int:
	var count: int = 0
	for index in stars_taken:
		if bool(course.stars[index].secret):
			count += 1
	return count


## Spielstand zum Fortsetzen (Sterne, Checkpoint, Mechanik, Zeit). Fußabschnitte
## werden beim Fortsetzen am Kart der Station wieder aufgenommen.
func snapshot() -> Dictionary:
	return {
		"course": course.id,
		"style": play_style,
		"t": t,
		"elapsed": elapsed,
		"checkpoint": checkpoint,
		"reached": reached.keys(),
		"stars": stars_taken.keys(),
		"secrets": secrets_found.keys(),
		"skills": skills_seen.keys(),
		"resets": resets,
		"falls": falls,
		"state": state.duplicate(true),
		"stations": station_done.keys(),
		"boosts": drive.boosts
	}


func restore(data: Dictionary) -> void:
	t = float(data.get("t", 0.0))
	elapsed = float(data.get("elapsed", 0.0))
	checkpoint = clampi(int(data.get("checkpoint", 0)), 0, course.checkpoints.size() - 1)
	reached = {}
	for key in data.get("reached", [0]):
		reached[int(key)] = true
	for key in data.get("stars", []):
		stars_taken[int(key)] = true
	for key in data.get("secrets", []):
		secrets_found[int(key)] = true
	for key in data.get("skills", []):
		skills_seen[int(key)] = true
	for key in data.get("stations", []):
		station_done[int(key)] = true
	resets = int(data.get("resets", 0))
	falls = int(data.get("falls", 0))
	var saved: Variant = data.get("state", {})
	if saved is Dictionary:
		state = (saved as Dictionary).duplicate(true)
	# Aufzüge fahren beim Fortsetzen von unten los; nichts hängt in der Luft.
	for key in state.keys():
		if str(key).ends_with("_up_at") or str(key).ends_with("_down_at"):
			state[key] = -1.0
		if str(key).ends_with("_ready"):
			state[key] = true
	drive.boosts = int(data.get("boosts", 1))
	var c: Dictionary = course.checkpoints[checkpoint]
	drive.place(c.pos as Vector3, float(c.heading))
	on_foot = false
