extends SceneTree
## Action-Parcours: Planung auf allen Strecken (keine Überlagerung mit Start, Sprung, Looping) und
## echte Fahrphysik für Turbo-Feld, Slalom, Sprungschanze, Unterwasser-Tunnel und offene Kante
## mit fairer Rettung. Gefahren wird mit Gas und Lenkung über _physics_process, ohne Teleport im Flug.
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame


func _check_plans() -> void:
	for track in ACTION.COURSES:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, str(track), true)
		var course: Dictionary = world.action
		var config: Dictionary = ACTION.COURSES[track]
		assert(course.pads.size() == config.get("pads", []).size(), "%s: alle Turbo-Felder haben Platz" % track)
		assert(course.gates.size() == (ACTION.GATE_COUNT if config.has("slalom") else 0), "%s: Slalom-Tore" % track)
		assert(course.kickers.size() == (1 if config.has("kicker") else 0), "%s: Sprungschanze" % track)
		assert(course.dives.size() == (1 if config.has("dive") else 0), "%s: Tauchstrecke" % track)
		assert(course.edges.size() == config.get("edges", []).size(), "%s: offene Kanten" % track)
		var spans: Array = []
		for pad in course.pads:
			spans.append(Vector2(pad.start, pad.end))
		if not course.gates.is_empty():
			spans.append(Vector2(course.gates[0].distance - 6.0, course.gates[-1].distance + 6.0))
		for kicker in course.kickers:
			spans.append(Vector2(kicker.start, kicker.take_off + 10.0))
		for dive in course.dives:
			spans.append(Vector2(dive.start, dive.end))
		for edge in course.edges:
			spans.append(Vector2(edge.start, edge.end))
			assert(absf(float(edge.side)) == 1.0)
		for span in spans:
			assert(span.x >= 35.0 and span.y <= world.length - 30.0, "%s: Abstand zu Start/Ziel" % track)
			if not world.jump.is_empty():
				assert(span.y < float(world.jump.ramp_start) or span.x > float(world.jump.gap_end), "%s: nicht im Sprung" % track)
			if not world.loop_layout.is_empty():
				var loop_start: float = float(world.loop_layout.start)
				assert(span.y < loop_start or span.x > loop_start + 60.0, "%s: nicht im Looping" % track)
		for a in range(spans.size()):
			for b in range(a + 1, spans.size()):
				assert(spans[a].y <= spans[b].x or spans[b].y <= spans[a].x, "%s: Elemente überlappen nicht" % track)
		print("[KartActionCourse] %s: %d Felder, %d Tore, %d Schanze, %d Tauchstrecke, %d offene Kante" % [
			track, course.pads.size(), course.gates.size(), course.kickers.size(), course.dives.size(), course.edges.size()
		])
		world.free()
	var plain = WORLD.new()
	root.add_child(plain)
	plain.build(true, "sonnenhafen", true)
	assert(plain.action.pads.is_empty() and plain.action.gates.is_empty(), "Sonnenhafen bleibt als Prüfstrecke unverändert")
	plain.free()


func _start(track: String) -> void:
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"})
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true
	game.auto_gas = true


## Kart mit Tempo an eine Stelle setzen (vor der Prüfung, nie während der Fahrt).
func _place(at: float, lateral: float, speed: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, lateral)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = speed
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	game.airborne = false
	game.boost_time = 0.0
	game.steering = 0.0


## Fährt mit Gas und hält per Lenkung die gewünschte Querlage.
func _drive(frames: int, lateral: float) -> void:
	for frame in range(frames):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, lateral)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
		game._physics_process(STEP)
		if frame % 60 == 59:
			await process_frame


func _check_pad_and_slalom() -> void:
	await _start("zauberwald")
	var course: Dictionary = game.world.action
	var pad: Dictionary = course.pads[0]
	_place(float(pad.start) - 10.0, float(pad.lateral), 16.0)
	var boosted: bool = false
	for frame in range(90):
		game._physics_process(STEP)
		boosted = boosted or game.boost_time > 0.0
	assert(game.action_pads_triggered == 1 and boosted, "Turbo-Feld gibt beim Überfahren Turbo")
	_place(float(pad.start) - 10.0, float(pad.lateral), 16.0)
	for frame in range(90):
		game._physics_process(STEP)
	assert(game.action_pads_triggered == 1, "Dasselbe Feld wirkt in derselben Runde nur einmal")
	# Slalom: jedes Tor in seiner Gasse durchfahren.
	var gates: Array = course.gates
	_place(float(gates[0].distance) - 16.0, float(gates[0].lateral), 12.0)
	game.auto_gas = false
	game.gas_held = true
	for gate in gates:
		while game.previous_road_distance < float(gate.distance) + 1.0:
			var target: Vector3 = game.world.position_at(float(gate.distance), float(gate.lateral))
			var direction: Vector3 = target - game.player.position
			var heading: float = atan2(-direction.x, -direction.z)
			game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.6, -1, 1)
			game.speed = minf(game.speed, 12.0)
			game._physics_process(STEP)
	assert(game.action_slaloms_cleared == 1 and game.action_gates_hit == 0, "Alle vier Tore getroffen: Slalom-Turbo (%d Tore, %d Hütchen)" % [game.action_gates_passed, game.action_gates_hit])
	assert(game.boost_time > 0.0, "Slalom-Turbo läuft")
	# Mitten durch ein Hütchen: bremst und zählt nicht.
	var first: Dictionary = gates[0]
	var pylon: float = ACTION.pylon_laterals(first)[0]
	_place(float(first.distance) - 5.0, pylon, 12.0)
	game.gas_held = false
	var before: float = game.speed
	game.lane = pylon
	game._update_action_course({"distance": float(first.distance) + 0.2, "lateral": pylon})
	game.previous_road_distance = float(first.distance) + 0.2
	assert(game.action_gates_hit == 1 and game.speed < before, "Hütchen bremst")
	game.auto_gas = true


func _check_kicker_and_dive() -> void:
	var course: Dictionary = game.world.action
	var kicker: Dictionary = course.kickers[0]
	_place(float(kicker.start) - 12.0, 0.0, 18.0)
	var landings: int = game.landing_count
	var flew: bool = false
	var peak: float = -INF
	for frame in range(150):
		game._physics_process(STEP)
		flew = flew or game.airborne
		if game.airborne:
			var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
			peak = maxf(peak, game.player.position.y - float(road.height))
	assert(game.action_kicker_jumps == 1 and flew, "Schanze lässt abheben")
	assert(peak > ACTION.KICKER_HEIGHT * 0.9, "Flug über Schanzenhöhe (%.2f m)" % peak)
	assert(not game.airborne and game.landing_count == landings + 1, "Landung nach der Schanze")
	var dive: Dictionary = course.dives[0]
	_place(float(dive.start) + 6.0, 0.0, 16.0)
	game._physics_process(STEP)
	assert(game.action_in_dive and is_instance_valid(game.dive_tint) and game.dive_tint.visible, "Unterwasser-Tunnel färbt das Bild")
	assert(is_equal_approx(game.world.dive_factor(game.previous_road_distance), ACTION.DIVE_SPEED))
	var top: float = 0.0
	for frame in range(180):
		game._physics_process(STEP)
		if game.action_in_dive:
			top = maxf(top, game.speed)
	assert(top <= 20.5 * ACTION.DIVE_SPEED + 0.6, "Unter Wasser fährt man langsamer (%.1f m/s)" % top)
	_place(float(dive.end) + 8.0, 0.0, 16.0)
	game._physics_process(STEP)
	assert(not game.action_in_dive and not game.dive_tint.visible, "Nach dem Tunnel wieder klare Sicht")


func _check_open_edge() -> void:
	await _start("candy_cloud")
	var edge: Dictionary = game.world.action.edges[0]
	var side: float = float(edge.side)
	var middle: float = (float(edge.start) + float(edge.end)) * 0.5
	# Geschlossene Seite: Leitplanke hält wie überall.
	_place(middle - 6.0, -side * 4.6, 14.0)
	await _drive(40, -side * 7.5)
	assert(absf(game.lane) <= 5.2 and game.reset_count == 0, "Die geschlossene Seite hat weiter eine Wand")
	# Offene Seite: hinausfahren, fallen, fair zurückgesetzt werden.
	_place(middle - 8.0, side * 4.0, 14.0)
	var fell: bool = false
	var frames: int = 0
	while game.reset_count == 0 and frames < 240:
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 6.0, side * 9.0)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1)
		game._physics_process(STEP)
		fell = fell or game.player.position.y < float(game.world.sample_road(game.player.position, game.previous_road_distance).height) - 0.5
		frames += 1
	assert(fell, "Hinter der offenen Kante fällt das Kart")
	assert(game.reset_count == 1 and game.action_edge_falls == 1, "Die Lumo-Wolke setzt das Kart zurück")
	assert(frames <= 120, "Der Sturz dauert höchstens zwei Sekunden (%d Frames)" % frames)
	assert(absf(game.lane) < 0.5 and is_equal_approx(game.speed, 6.0) and game.shield_time >= 1.9, "Rettung mittig, mit Schwung und kurzem Schutz")
	assert("Lumo-Wolke" in game.message.text)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	_check_plans()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _check_pad_and_slalom()
	await _check_kicker_and_dive()
	await _check_open_edge()
	game.abandoned = true
	game.queue_free()
	for frame in range(6):
		await process_frame
	await create_timer(1.3).timeout
	print("[KartActionCourse] PASS: 11 Strecken ohne Überlagerung, Turbo-Feld, Slalom mit Hütchen, Sprungschanze mit Landung, Unterwasser-Tunnel, offene Kante mit fairer Rettung")
	quit(0)
