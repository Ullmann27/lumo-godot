extends SceneTree
## Faire Sternraketen (kart_rocket_fairness.gd) im echten Rennen: Startschutz,
## Rettungsschutz, Verfolger-Limit, nur ein Rivale erfasst das Kind, keine Treffer an
## Sturzstellen – auf jeder Strecke mit Gefahrenstelle.
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const STEP := 1.0 / 60.0

var game
var checks := 0
var failures: Array[String] = []
var course := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [course, label])
		print("[KartRocketFairness] FAIL %s: %s" % [course, label])
	return condition


func _calm_distance() -> float:
	# Erste Sammelzone: dort ist laut Vertrag keine Gefahrenstelle.
	return float(game.catalog_box_distances[0])


func _course(track: String) -> void:
	course = track
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	await process_frame
	game.racing = true
	game.countdown = 0
	var fair = game.rocket_fairness
	var calm: float = _calm_distance()
	game.distance = calm
	game.elapsed = 3.0
	_check(fair.child_block_reason(game, 0) == "start", "Startschutz in den ersten 8 s")
	game.elapsed = 40.0
	fair.observe(game.reset_count, game.elapsed)
	_check(fair.child_targetable(game, 0), "ruhige Stelle mitten im Rennen: erfassbar")
	game.reset_count += 1
	fair.observe(game.reset_count, game.elapsed)
	_check(fair.child_block_reason(game, 0) == "rescue", "Rettungsschutz nach Rücksetzer")
	game.elapsed = 45.0
	_check(fair.child_targetable(game, 0), "Rettungsschutz endet")
	game.opponent_lock_targets[2] = -1
	_check(fair.child_block_reason(game, 0) == "other_lock", "nur ein Rivale erfasst das Kind")
	game.opponent_lock_targets[2] = -99
	game.item_runtime.fire_pair("star_rocket", 3, game.distance - 30.0, 0.0, -1)
	_check(fair.child_block_reason(game, 0) == "chasers", "höchstens eine Salve gleichzeitig")
	game.item_runtime.clear()
	# Sturzstellen: jede Gefahrenstelle der Strecke blockt Treffer und Erfassung.
	var areas: Array = fair._areas(game.world)
	var tested := 0
	for area in areas:
		var middle: float = (float(area.start) + float(area.end)) * 0.5
		game.distance = fposmod(middle, game.track_length)
		_check(not fair.hit_allowed(game, -1), "kein Treffer an %s (%.0f m)" % [area.kind, middle])
		_check(not fair.child_targetable(game, 0), "keine Erfassung an %s" % area.kind)
		tested += 1
		if tested >= 4:
			break
	# Ein echter Treffer-Event an einer Sturzstelle dreht das Kind nicht.
	if not areas.is_empty():
		game.distance = fposmod(
			(float(areas[0].start) + float(areas[0].end)) * 0.5, game.track_length
		)
		game.player_grace_time = 0.0
		game.player_spin_time = 0.0
		game._apply_item_event(
			{"type": "hit", "target": -1, "source": 1, "item": "star_rocket", "spin": 1.2}
		)
		_check(game.player_spin_time <= 0.0, "Raketentreffer an Sturzstelle zerplatzt harmlos")
	game.distance = calm
	game.player_grace_time = 0.0
	game._apply_item_event(
		{"type": "hit", "target": -1, "source": 1, "item": "star_rocket", "spin": 1.2}
	)
	_check(
		game.player_spin_time > 0.0 and game.player_grace_time > 0.0,
		"ruhige Stelle: Treffer + Schonzeit"
	)
	var spin_before: float = game.player_spin_time
	game._apply_item_event(
		{"type": "hit", "target": -1, "source": 2, "item": "star_rocket", "spin": 1.2}
	)
	_check(
		is_equal_approx(game.player_spin_time, spin_before),
		"Schonzeit: kein zweiter Treffer (keine Kette)"
	)
	fair.observe(game.reset_count, game.elapsed, game.player_spin_time)
	game.player_grace_time = 0.0
	_check(
		fair.child_block_reason(game, 0) == "after_hit", "Trefferpause: 12 s keine neue Erfassung"
	)
	_check(not fair.hit_allowed(game, -1), "Trefferpause: auch Querschläger treffen nicht")
	game.elapsed += 12.5
	_check(fair.child_targetable(game, 0), "nach der Trefferpause wieder erfassbar")
	print("[KartRocketFairness] %s: %d Gefahrenstellen geprüft" % [track, tested])


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "rocket-fairness"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in TRACKS.IDS:
		await _course(track)
	game.abandoned = true
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[KartRocketFairness] PASS: %d checks on %d courses" % [checks, TRACKS.IDS.size()])
	else:
		print("[KartRocketFairness] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
