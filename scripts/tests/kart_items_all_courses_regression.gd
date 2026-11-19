extends SceneTree
## Issue #205: items, rockets, shield, rival item use and driving effects on EVERY
## selectable course – not only on Sonnenhafen.
##
## Per course the real race is started with that course id and the test checks
##  - inventory: surprise boxes, skill rings, boost rings, item runtime, effects;
##  - fair placement: inside the walls, at kart height, away from ramps, loop and
##    obstacles;
##  - a physically driven pickup of a surprise box (real physics steps, no state
##    assignment of the collected flag);
##  - Sternraketen: arm, lock the rival ahead, fire a pair, the rival spins once;
##  - shield blocks a rival salvo; an unshielded hit starts the grace time and a
##    second salvo inside it does not hit again (no hit loop);
##  - rival AI warns, then fires;
##  - driving effects are bound to the course surface and react to a drift.
## `--tracks=a,b` limits the run, `--report=<file>` writes the table as JSON.
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const STYLES = preload("res://scripts/games/kart_fx/kart_fx_surface_styles.gd")
const STEP := 1.0 / 60.0
## Courses on loose or special ground must not drive with plain asphalt effects.
const EXPECTED_SURFACE := {
	"zauberwald": "forest", "jungle_emerald_3600": "forest", "desert_drift": "sand",
	"winter_sprint": "snow", "volcano_night": "lava", "galaxy_ringway": "starglass",
}

var game
var checks := 0
var failures: Array[String] = []
var table: Array[Dictionary] = []
var course := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [course, label])
		print("[KartItemsAllCourses] FAIL %s: %s" % [course, label])
	return condition


func _gap(a: float, b: float, length: float) -> float:
	var d := absf(fposmod(a, length) - fposmod(b, length))
	return minf(d, length - d)


func _place(distance: float, lane: float) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	game.player.transform = game.world.reset_transform(distance, lane)
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)
	game.speed = 0.0
	game.physical_velocity = Vector3.ZERO
	game.vertical_speed = 0.0
	game.airborne = false


func _place_racers() -> void:
	game.player.global_position = game._track_position(
		fposmod(game.distance, game.track_length), game.lane
	)
	game.player_heading = game._heading(fposmod(game.distance, game.track_length))
	for i in range(game.opponents.size()):
		game.opponents[i].global_position = game._track_position(
			fposmod(game.opponent_distances[i], game.track_length), game.opponent_lanes[i]
		)


func _clear_items() -> void:
	game.item_runtime.clear()
	game.item = ""
	game.item_charges = 0
	game.item_roulette_time = 0.0
	game._sync_player_rocket_phase()
	game.shield_time = 0.0
	game.player_grace_time = 0.0
	game.player_spin_time = 0.0
	for i in range(game.opponents.size()):
		game.opponent_spin_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
		game.opponent_shield_times[i] = 0.0
		game.opponent_items[i] = ""


func _inventory(row: Dictionary) -> void:
	var length: float = game.track_length
	row["laenge_m"] = roundi(length)
	row["ueberraschungsboxen"] = game.catalog_boxes.size()
	row["koennerringe"] = game.item_boxes.size()
	row["turboringe"] = game.track_triggers.size()
	_check(game.catalog_boxes.size() >= 6, "mindestens sechs Überraschungsboxen (%d)" % game.catalog_boxes.size())
	_check(not game.item_boxes.is_empty(), "Könner-Ringe vorhanden")
	_check(game.track_triggers.size() >= 2, "mindestens zwei Turbo-Ringe (%d)" % game.track_triggers.size())
	_check(is_instance_valid(game.item_runtime) and is_instance_valid(game.fx), "Item-Laufzeit und Effekt-Regie leben")
	var kickers: Array = []
	if game.world.action is Dictionary:
		kickers = game.world.action.get("kickers", [])
	var worst_wall := 99.0
	var worst_ramp := 9999.0
	for i in range(game.catalog_boxes.size()):
		var d: float = game.catalog_box_distances[i]
		var lateral: float = game.catalog_box_laterals[i]
		var wall: float = game._wall_lateral_at(d)
		worst_wall = minf(worst_wall, wall - absf(lateral))
		_check(absf(lateral) <= wall - 0.6, "Box %d innerhalb der Planken (%.1f von %.1f m)" % [i, absf(lateral), wall])
		var road_point: Vector3 = game._track_position(d, lateral)
		var lift: float = game.catalog_boxes[i].position.distance_to(road_point)
		_check(lift > 0.4 and lift < 2.2, "Box %d auf Kart-Höhe (%.2f m über der Fahrbahn)" % [i, lift])
		for kicker in kickers:
			var ramp_gap: float = _gap(d, float(kicker.get("take_off", 0.0)), length)
			worst_ramp = minf(worst_ramp, ramp_gap)
			_check(ramp_gap >= 18.0, "Box %d nicht an einer Rampe (%.0f m Abstand)" % [i, ramp_gap])
		if not game.world.loop_layout.is_empty():
			var loop_gap: float = _gap(d, float(game.world.loop_layout.start), length)
			_check(loop_gap >= 18.0, "Box %d nicht am Looping (%.0f m Abstand)" % [i, loop_gap])
		for obstacle in game.obstacle_distances:
			_check(
				_gap(d, float(obstacle), length) >= 6.0,
				"Box %d nicht hinter einem Hindernis (%.0f m)" % [i, _gap(d, float(obstacle), length)]
			)
	row["kleinster_plankenabstand_m"] = snappedf(worst_wall, 0.01)
	row["kleinster_rampenabstand_m"] = -1 if worst_ramp > 9000.0 else roundi(worst_ramp)


## Drive into the middle box of the first row with real physics steps.
func _driven_pickup(row: Dictionary) -> void:
	_clear_items()
	var index := -1
	for i in range(game.catalog_boxes.size()):
		if is_zero_approx(game.catalog_box_laterals[i]):
			index = i
			break
	if not _check(index >= 0, "eine Box liegt in der Fahrbahnmitte"):
		return
	var box_distance: float = game.catalog_box_distances[index]
	_place(box_distance - 24.0, 0.0)
	var resets_before: int = game.reset_count
	var frames := 0
	while frames < 600 and game.catalog_boxes[index].visible:
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, 0)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
		game._physics_process(STEP)
		frames += 1
	game.steering = 0.0
	row["box_einsammeln_frames"] = frames
	_check(not game.catalog_boxes[index].visible, "Box wird beim Durchfahren eingesammelt (%d Schritte)" % frames)
	_check(not str(game.item).is_empty(), "nach der Box hat der Spieler ein Item (%s)" % game.item)
	_check(game.reset_count == resets_before, "kein Rücksetzer auf dem Weg zur Box")
	row["item_aus_box"] = str(game.item)
	# Der Sternenkompass zeigt die Ziehung rund 3,5 s; danach ist das Item nutzbar.
	var roulette_frames := 0
	while roulette_frames < 300 and game.item_roulette_time > 0.0:
		game._physics_process(STEP)
		roulette_frames += 1
	_check(game.item_roulette_time <= 0.0, "Item-Rad kommt zur Ruhe (%d Schritte)" % roulette_frames)


func _rockets(row: Dictionary, base: float) -> void:
	_clear_items()
	game.distance = base
	game.lane = 0.0
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = base - 55.0 - i
	game.opponent_distances[1] = base + 25.0
	game.opponent_lanes[1] = 1.5
	_place_racers()
	game._grant_item("star_rocket")
	_check(game.rocket_phase == "ready" and game.item_charges == 2, "Raketen: zwei Salven nach dem Aufnehmen")
	_check(is_instance_valid(game.player_pods) and game.player_pods.pairs_left() == 2, "Halter links/rechts gefüllt")
	game._use_item()
	_check(game.rocket_phase == "armed" and game.item_runtime.projectiles.is_empty(), "erster Druck schärft, feuert nicht")
	for frame in range(90):
		game._update_item_experience(STEP)
	_check(game.lock_target == 1 and game.lock_progress >= 1.0, "Zielerfassung rastet auf den Rivalen voraus ein")
	game._use_item()
	_check(game.item_runtime.projectiles.size() == 2, "zweiter Druck feuert ein Raketenpaar")
	var hit_frames := 0
	for frame in range(240):
		game.opponent_distances[1] += 6.0 * STEP
		game._update_gameplay_layer(STEP)
		hit_frames += 1
		if game.opponent_spin_times[1] > 0.0:
			break
	_check(game.opponent_spin_times[1] > 0.0, "Rivale dreht sich nach dem Treffer")
	for frame in range(40):
		game._update_gameplay_layer(STEP)
	_check(game.opponent_grace_times[1] > 0.0, "Schonzeit für den getroffenen Rivalen")
	row["rakete_treffer_frames"] = hit_frames


func _shield_and_grace(row: Dictionary, base: float) -> void:
	_clear_items()
	# Mitten im Rennen, ohne frühere Trefferpause (kart_rocket_fairness.gd).
	game.elapsed = 40.0
	game.rocket_fairness.reset()
	game.distance = base
	game.lane = 0.0
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = base - 30.0 - i * 3.0
	_place_racers()
	# Shield up: the salvo is blocked.
	game.shield_time = 3.0
	var blocked_before: int = int(game.gameplay_stats.blocked)
	var taken_before: int = int(game.gameplay_stats.player_hits_taken)
	game.item_runtime.fire_homing("star_rocket", 0, base - 12.0, 0.0, -1)
	for frame in range(180):
		game._update_gameplay_layer(STEP)
		if int(game.gameplay_stats.blocked) > blocked_before:
			break
	_check(int(game.gameplay_stats.blocked) > blocked_before, "Schild wehrt die Rakete ab")
	_check(int(game.gameplay_stats.player_hits_taken) == taken_before, "mit Schild kein Treffer")
	# No shield: one hit, then grace – a second salvo inside it must not hit again.
	game.item_runtime.clear()
	game.shield_time = 0.0
	game.aurora_time = 0.0
	game.player_grace_time = 0.0
	game.item_runtime.fire_homing("star_rocket", 0, base - 12.0, 0.0, -1)
	for frame in range(180):
		game._update_gameplay_layer(STEP)
		if int(game.gameplay_stats.player_hits_taken) > taken_before:
			break
	_check(int(game.gameplay_stats.player_hits_taken) == taken_before + 1, "ohne Schild genau ein Treffer")
	_check(game.player_grace_time > 0.0, "Schonzeit nach dem Treffer (%.1f s)" % game.player_grace_time)
	game.item_runtime.clear()
	game.item_runtime.fire_homing("star_rocket", 0, base - 12.0, 0.0, -1)
	for frame in range(100):
		game._update_gameplay_layer(STEP)
	_check(
		int(game.gameplay_stats.player_hits_taken) == taken_before + 1,
		"zweite Salve in der Schonzeit trifft nicht (keine Trefferschleife)"
	)
	row["schonzeit_s"] = snappedf(float(game._lock_rules().grace), 0.1)


func _rival_ai(row: Dictionary, base: float) -> void:
	_clear_items()
	game.distance = base
	game.lane = 0.0
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = base - 60.0 - i * 3.0
	game.opponent_distances[0] = base - 25.0
	game.opponent_lanes[0] = 0.0
	_place_racers()
	game.opponent_items[0] = "star_rocket"
	game.opponent_item_cooldowns[0] = 0.0
	game.opponent_rocket_hold[0] = 99.0
	# Mitten im Rennen: der Startschutz (kart_rocket_fairness.gd, erste 8 s) ist vorbei.
	game.elapsed = 80.0
	game.rocket_fairness.reset()
	var reason: String = game.rocket_fairness.child_block_reason(game, 0)
	_check(reason.is_empty(), "ruhige Teststelle: Kind darf erfasst werden (%s)" % reason)
	var warned := false
	var fired := false
	for frame in range(360):
		game._update_item_experience(STEP)
		warned = warned or game.player_warning > 0.0
		if not game.item_runtime.projectiles.is_empty():
			fired = true
			break
	_check(warned, "Warnung, bevor ein Rivale feuert")
	_check(fired, "Rivale nutzt seine Raketen")
	row["rivale_feuert"] = fired
	game.item_runtime.clear()


func _drive_effects(row: Dictionary, base: float) -> void:
	_clear_items()
	var fx = game.drive_fx
	if not _check(is_instance_valid(fx), "Fahr-Effekte hängen am Rennen"):
		return
	var expected: Dictionary = STYLES.for_track(course)
	row["belag"] = str(fx.style.get("name", "?"))
	_check(
		str(fx.style.get("name", "")) == str(expected.get("name", "")),
		"Effekte nutzen den Belag der Strecke (%s statt %s)" % [fx.style.get("name", "?"), expected.get("name", "?")]
	)
	if EXPECTED_SURFACE.has(course):
		_check(
			str(fx.style.get("name", "")) == str(EXPECTED_SURFACE[course]),
			"Belag-Effekte: %s erwartet, %s gebunden" % [EXPECTED_SURFACE[course], fx.style.get("name", "?")]
		)
	fx.reset()
	fx.counts.clear()
	game.reduced_motion = false
	game.boost_time = 0.0
	game.brake_visual_amount = 0.0
	game.drifting = true
	game.steering = 0.8
	game.drift_charge = 0.0
	var along := base
	for frame in range(40):
		along += 0.4
		_place(along, 0.0)
		game.speed = 20.0
		game._update_vehicles(STEP)
	_check(int(fx.counts.get("drift_sparks", 0)) > 0, "Drift sprüht Funken")
	_check(int(fx.counts.get("drift_marks", 0)) > 5, "Drift hinterlässt Spuren")
	row["drift_funken"] = int(fx.counts.get("drift_sparks", 0))
	game.drifting = false
	game.steering = 0.0
	fx.reset()


func _course_run(track: String) -> void:
	course = track
	var row := {"strecke": track}
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"}
	)
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.auto_gas = true
	var world_ok: bool = _check(
		str(game.track_id) == track and str(game.world.track_id) == track,
		"geladene Welt ist %s (Rennen %s, Welt %s)" % [track, game.track_id, game.world.track_id]
	)
	if world_ok:
		_inventory(row)
		# A calm stretch: the first surprise row is placed away from ramps and events.
		var base: float = maxf(40.0, float(game.catalog_box_distances[0]) - 60.0)
		# Ruhige Teststrecke: keine Sturzstelle (dort zerplatzen Geschosse absichtlich).
		for zone_distance in game.catalog_box_distances:
			var calm := true
			for step in range(-60, 50, 5):
				if not game.rocket_fairness.danger_at(game.world, float(zone_distance) + step).is_empty():
					calm = false
			if calm and float(zone_distance) > 100.0:
				base = float(zone_distance) - 60.0
				break
		_driven_pickup(row)
		_rockets(row, base)
		_shield_and_grace(row, base)
		_rival_ai(row, base)
		_drive_effects(row, base)
	row["fehler"] = failures.filter(func(text): return str(text).begins_with(track + ":")).size()
	table.append(row)
	print("[KartItemsAllCourses] ", JSON.stringify(row))


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "items-all-courses"}
	var selected: Array[String] = TRACKS.IDS.duplicate()
	var report := ""
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--tracks="):
			selected.clear()
			for id in str(argument).trim_prefix("--tracks=").split(","):
				selected.append(id)
		if str(argument).begins_with("--report="):
			report = str(argument).trim_prefix("--report=")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in selected:
		await _course_run(track)
	await process_frame
	game.abandoned = true
	game.queue_free()
	await process_frame
	if not report.is_empty():
		var file := FileAccess.open(report, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "courses": table}, "  "))
	if failures.is_empty():
		print(
			"[KartItemsAllCourses] PASS: %d checks on %d courses – boxes, driven pickup, rockets, shield, grace, rival AI, drive effects"
			% [checks, table.size()]
		)
	else:
		for text in failures:
			print("[KartItemsAllCourses]   - ", text)
		print("[KartItemsAllCourses] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
