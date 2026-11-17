extends SceneTree
## Abenteuer-Strecken: Dramaturgie, faire Hindernisse, Bauteil-Platzhalter für Lumo · Design.
const WORLD = preload("res://scripts/games/kart_world.gd")
const DRAMA = preload("res://scripts/games/kart_adventure_drama.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const ROAD_HALF := 5.0
var checks := 0
var failures: Array[String] = []
var summary: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error(text)

func _obstacle_rows(world) -> Array:
	var rows: Array = []
	for at in world.action_obstacles:
		var road: Dictionary = world.sample_road(at)
		rows.append(Vector2(float(road.distance), float(road.lateral)))
	return rows

func _run() -> void:
	var ids: Array = DRAMA.TRACKS.keys()
	# Dschungelherz braucht kart_jungle_environment.gd, das auf der Basis 6a26a158 fehlt (offen, gemeldet).
	if not ResourceLoader.exists("res://scripts/games/kart_jungle_environment.gd"):
		ids.erase("jungle_emerald_3600")
		print("[AdventureDrama] SKIP jungle_emerald_3600: kart_jungle_environment.gd fehlt auf dieser Basis")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tracks="):
			ids = Array(arg.substr(9).split(","))
	for track_id in ids:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, track_id)
		var profile: Dictionary = DRAMA.profile(track_id)
		var report: Dictionary = world.get_meta("adventure_drama", {})
		var tag: String = track_id
		_check(not report.is_empty(), tag + ": Dramaturgie gebaut")
		_check(world.find_child("AbenteuerDramaturgie", false, false) != null, tag + ": Dramaturgie-Knoten")
		_check(int(report.get("curves", 0)) >= 1, tag + ": enge Kurven mit Chevron-Tafeln markiert")
		var length: float = world.length
		var mine: Array = _obstacle_rows(world)
		if track_id == "sonnenhafen":
			_check(world.action_obstacles.size() == 6, tag + ": Sonnenhafen behält genau seine 6 Hütchen")
		else:
			_check(int(report.obstacles) >= 4, tag + ": echte Hindernisse (%d)" % int(report.obstacles))
		# Fairness: an jeder Hindernis-Stelle bleibt eine freie Spur von mindestens 4 m.
		for row in mine:
			var lanes: Array = []
			for other in mine:
				if absf(other.x - row.x) < 4.0:
					lanes.append(other.y)
			lanes.sort()
			var best := 0.0
			var edge := -ROAD_HALF
			for lat in lanes:
				best = maxf(best, (lat - 0.9) - edge)
				edge = maxf(edge, lat + 0.9)
			best = maxf(best, ROAD_HALF - edge)
			_check(best >= 4.0, tag + ": freie Spur %.1f m bei %.0f m" % [best, row.x])
			_check(row.x > 35.0 and row.x < length - 30.0, tag + ": kein Hindernis an Start/Ziel (%.0f m)" % row.x)
			var loop: Dictionary = world.loop_layout
			if not loop.is_empty():
				_check(row.x < float(loop.start) - 10.0 or row.x > float(loop.start) + 70.0, tag + ": Loop-Zone frei")
			for fraction in DRAMA.turbo_fractions(track_id):
				var pad := float(fraction) * length + 1.1
				_check(absf(row.x - pad) > 6.0 or absf(row.y) > 2.6, tag + ": Turbo-Feld bleibt erreichbar")
			for item in DRAMA.item_layout(track_id):
				var d := float(item[0]) * length
				_check(absf(row.x - d) > 6.0 or absf(row.y - float(item[1])) > 2.0, tag + ": Item-Ring nicht hinter Hindernis")
		var markers: Node = world.find_child("AbenteuerBauteilPlatzhalter", true, false)
		_check(markers != null, tag + ": Platzhalter-Knoten")
		var wanted := 0
		for beat in profile.get("beats", []):
			if str(beat[1]) == "bauteil":
				wanted += 1
		for marker in markers.get_children():
			_check(marker is Marker3D and DRAMA.BAUTEILE.has(str(marker.get_meta("bauteil", ""))), tag + ": Marker benannt " + str(marker.name))
		_check(markers.get_child_count() + report.skipped.size() >= wanted, tag + ": alle Bauteile gesetzt oder begründet übersprungen")
		_check(markers.get_child_count() >= wanted - 1, tag + ": höchstens ein Bauteil übersprungen (%d/%d)" % [markers.get_child_count(), wanted])
		summary.append({"track": track_id, "length_m": snappedf(length, 1.0), "obstacles": report.obstacles,
			"markers": report.markers, "skipped": report.skipped, "curves": report.curves, "acts": report.acts})
		world.free()
	# Deterministisch: gleicher Aufbau ergibt gleiche Hindernisse.
	var a = WORLD.new()
	root.add_child(a)
	a.build(true, "volcano_night")
	var first: Array = a.action_obstacles.duplicate()
	a.build(true, "volcano_night")
	_check(first == a.action_obstacles, "deterministischer Aufbau")
	a.free()
	print("[AdventureDrama] ", JSON.stringify({"checks": checks, "failures": failures.slice(0, 30), "failure_count": failures.size(),
		"tracks": summary, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
