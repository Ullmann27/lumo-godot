extends Node3D
## Nova und Milo fahren mit denselben Reifen, Schanzen, Checkpoints und Fußwegen wie Lumo.
const RUN = preload("res://scripts/games/parcours/parcours_run.gd")
const PILOT = preload("res://scripts/games/parcours/parcours_bot.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const DRIVERS := [
	{"name": "Nova", "animal": "rabbit", "kart": "gecko_velo", "color": Color("bd77fa"), "lane": -2.65},
	{"name": "Milo", "animal": "otter", "kart": "boru_rally", "color": Color("42c0ab"), "lane": 2.65},
]
var racers: Array[Dictionary] = []
var runs: Array = []
var player
var lift_state: Dictionary = {}
var lift_slab: int = -1
var lift_prefix: String = ""
var place: int = 1
var player_metres: float = 0.0


func setup(player_run, workshop, lightweight: bool, reduced: bool, saved: Array) -> void:
	player = player_run
	runs = [player]
	player.shared_lift = true
	var course = player.course
	for i in range(course.slabs.size()):
		var motion: Dictionary = course.slabs[i].get("motion", {})
		if str(motion.get("type", "")) == "lift_trigger":
			lift_slab = i
			lift_prefix = str(motion.id) + "_"
			break
	lift_state = player.state.duplicate()
	for i in range(DRIVERS.size()):
		var profile: Dictionary = DRIVERS[i]
		var run = RUN.new()
		run.setup(course, "rennen")
		run.shared_lift = true
		run.drive.difficulty = player.drive.difficulty
		run.drive.factors = workshop.multipliers(str(profile.kart))
		var pilot = PILOT.new(17 + i * 12, 0.25 + i * 0.06, 0.08)
		var line: Array = course.route.duplicate()
		if i == 0 and not course.race_branch.is_empty():
			var branch: Dictionary = course.race_branch
			line = line.slice(0, int(branch.entry) + 1) + branch.points + line.slice(int(branch.exit))
		pilot.racing_line = line
		var start: Vector3 = course.start.pos
		var grid := Basis(Vector3.UP, float(course.start.heading))
		var grid_position: Vector3 = start + grid * Vector3(float(profile.lane), 0, -1.5 if i == 0 else 2.5)
		run.drive.place(grid_position, float(course.start.heading))
		if i < saved.size():
			run.restore(saved[i])
			run.finished = bool(saved[i].get("finished", false))
			if run.finished:
				run.finish_order_ok = true
				var approach: Vector3 = course.finish.pos - line[-2].pos
				run.drive.place(course.finish.pos, atan2(-approach.x, -approach.z))
			pilot.target = _nearest(line, run.drive.position)
		var kart = VEHICLE.new()
		kart.set_look(workshop.look(str(profile.kart)))
		kart.configure(str(profile.animal), profile.color, str(profile.kart))
		kart.name = str(profile.name) + "Kart"
		kart.reduced_motion = reduced
		kart.set_graphics_quality("low" if lightweight else "high")
		add_child(kart)
		var tag := Label3D.new()
		tag.text = str(profile.name)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(profile.color).lightened(0.45)
		tag.outline_modulate = Color("19223a")
		tag.outline_size = 10
		tag.pixel_size = 0.012
		tag.visibility_range_end = 30.0
		tag.visibility_range_end_margin = 5.0
		add_child(tag)
		var racer := {
			"run": run, "pilot": pilot, "kart": kart, "tag": tag, "foot": null,
			"side": float(profile.lane), "animal": profile.animal, "rank_m": 0.0
		}
		runs.append(run)
		racers.append(racer)
		_draw_racer(racer, 0.0)
	update_place()


static func _nearest(line: Array, pos: Vector3) -> int:
	var best := INF
	var nearest := 0
	for i in range(line.size()):
		var d := pos.distance_squared_to(line[i].pos)
		if d < best:
			nearest = i
			best = d
	return nearest


## Ein Aufzug trägt das gesamte Feld. Wer zuerst den Hebel erreicht, öffnet allen die Brücke.
func sync_mechanisms(delta: float) -> void:
	var course = player.course
	if lift_slab >= 0:
		var along := -1.0
		for run in runs:
			if not run.on_foot and not run.drive.airborne and int(run.drive.hit.get("slab", -1)) == lift_slab:
				along = maxf(along, float(run.drive.hit.along))
		course.update_mechanics(lift_state, player.t + delta, lift_slab if along >= 0.0 else -1, along)
		for key in lift_state:
			if str(key).begins_with(lift_prefix):
				for run in runs:
					run.state[key] = lift_state[key]
	for key in course.mechanisms:
		if not lift_prefix.is_empty() and str(key).begins_with(lift_prefix):
			continue
		for source in runs:
			if not bool(source.state.get(key, false)):
				continue
			for run in runs:
				run.state[key] = true
				run.state[str(key) + "_at"] = source.state.get(str(key) + "_at", source.t)
			break
	for i in range(course.stations.size()):
		if bool(player.state.get(str(course.stations[i].mechanism), false)):
			for run in runs:
				run.station_done[i] = true


func advance(delta: float) -> void:
	for racer in racers:
		var run = racer.run
		if run.finished:
			continue
		var pilot = racer.pilot
		var axis := 0.0
		if run.on_foot:
			var action: Dictionary = pilot.foot_input(run)
			if action.jump:
				run.walker.press_jump()
			if action.lever:
				run.use_lever()
			if run.can_enter_kart() and run.enter_kart():
				pilot.foot_target = 0
			run.step(delta, 0.0, 0.0, false, false, action.move)
			if action.jump:
				run.walker.release_jump()
		else:
			if run.can_leave_kart():
				run.leave_kart()
			var input: Dictionary = pilot.drive_input(run, delta)
			axis = float(input.axis)
			if run.drive.boosts > 0 and absf(axis) < 0.2 and float(input.brake) < 0.1:
				var hit: Dictionary = run.drive.hit
				if not hit.is_empty():
					var slab: Dictionary = run.course.slabs[int(hit.slab)]
					var clear_metres := float(slab.get("length", 0.0)) * (1.0 - float(hit.along))
					if float(hit.width) >= 10.0 and clear_metres >= 35.0 and not slab.has("cap") and not slab.has("motion"):
						run.drive.use_boost()
			# Beim Aufschließen auf breiten Platten eine Seite zum Überholen suchen.
			if float(run.drive.hit.get("width", 0.0)) >= 9.0 and absf(axis) < 0.4:
				var ahead: Vector3 = -run.drive.basis.z
				for other in runs:
					if other == run or other.finished or other.on_foot:
						continue
					var gap: Vector3 = other.drive.position - run.drive.position
					if gap.dot(ahead) > 0.1 and gap.dot(ahead) < 9.0 and absf(gap.dot(run.drive.basis.x)) < 1.9 and absf(gap.y) < 1.2:
						axis += 0.32 * signf(float(racer.side))
						break
			run.step(delta, clampf(axis, -1.0, 1.0), float(input.brake), true, true)
		_draw_racer(racer, axis)
	update_place()


func _draw_racer(racer: Dictionary, axis: float) -> void:
	var run = racer.run
	var kart = racer.kart
	racer.tag.position = run.position() + Vector3.UP * 2.35
	kart.transform = Transform3D(run.drive.basis, run.drive.position)
	kart.set_motion(0.0 if run.finished or run.on_foot else run.drive.speed, axis, run.drive.boost_time > 0.0, false)
	kart.set_driver_runtime_state(run.drive.airborne, run.drive.bump_time > 0.0, run.finished)
	if run.on_foot and racer.foot == null:
		var foot = VEHICLE.new()
		foot.name = str(kart.name) + "ZuFuss"
		foot.configure_companion(str(racer.animal))
		add_child(foot)
		racer.foot = foot
	for rider in [kart.driver, kart.production_driver, kart.rival_visual]:
		if is_instance_valid(rider):
			rider.visible = not run.on_foot
	if racer.foot != null:
		racer.foot.visible = run.on_foot
		if run.on_foot:
			racer.foot.transform = Transform3D(Basis(Vector3.UP, run.walker.heading), run.walker.position)
			racer.foot.set_companion_pose(run.t, "walk")


static func distance_along(run, previous: float) -> float:
	var cp: Dictionary = run.course.checkpoints[run.checkpoint]
	var start: float = float(cp.route_at)
	var hit: Dictionary = run.drive.hit
	if hit.is_empty():
		return maxf(start, previous) if run.drive.airborne else start
	var slab: Dictionary = run.course.slabs[int(hit.slab)]
	var length: float
	if str(slab.kind) == "box":
		length = Vector2(float(slab.length), float(slab.rise)).length()
	else:
		length = Vector2(float(slab.radius) * absf(float(slab.a1) - float(slab.a0)), float(slab.y1) - float(slab.y0)).length()
	return maxf(start, float(slab.get("route_from", start)) + float(slab.get("race_distance_span", length)) * float(hit.along))


func update_place() -> void:
	place = 1
	player_metres = distance_along(player, player_metres)
	for racer in racers:
		var run = racer.run
		racer.rank_m = distance_along(run, float(racer.rank_m))
		if run.finished and (not player.finished or run.elapsed < player.elapsed):
			place += 1
		elif not player.finished and not run.finished:
			if run.checkpoint > player.checkpoint or (run.checkpoint == player.checkpoint and float(racer.rank_m) > player_metres + 0.05):
				place += 1


func snapshot() -> Array:
	var result := []
	for racer in racers:
		var data: Dictionary = racer.run.snapshot()
		data.finished = racer.run.finished
		result.append(data)
	return result
