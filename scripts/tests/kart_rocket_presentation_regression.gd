extends SceneTree
## Sternraketen-Inszenierung im echten Rennen (headless):
##  - Flugdauer: Rivale 30 m voraus im selben Tempo wird frühestens nach 0,8 s getroffen
##    (Begründung: 0,8 s = 48 Bilder bei 60 Hz – lang genug, dass das Auge der Rakete
##    folgt; vorher flog sie langsamer als das Kart und erreichte das Ziel gar nicht)
##  - je gerendertem Bild stetige Bewegung (Bildtakt mit Zittern nachgestellt): kein Bild
##    ohne Bewegung, kein Sprung über 2,2 m (≈ 2 Takte bei Raketentempo)
##  - Spur-/Lichtknoten entstehen und verschwinden wieder (20 Salven, kein Leck)
##  - Treffer hebt den Rivalen in der Anzeige an, die echte (Spiel-)Lage bleibt auf der
##    Fahrbahn, er landet wieder; Runden-/Checkpointzählung unverändert
##  - Schonzeit nach Treffer und nach Rücksetzer
##  - „ruhige Bewegung“: kein Wirbel, kein Aufziehen, kein Trefferbild
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const FLIGHT = preload("res://scripts/games/kart_items/kart_rocket_flight.gd")
const RUNTIME = preload("res://scripts/games/kart_items/kart_item_runtime.gd")
const STEP: float = 1.0 / 60.0
var game
var smoother
var flight
var checks: int = 0
var failures: Array[String] = []
var ticks_done: int = 0
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[KartRocketPresentation] FAIL: " + label)


func _tick() -> void:
	smoother.begin_tick()
	game._physics_process(STEP)
	smoother.end_tick()
	ticks_done += 1


## Ein nachgestelltes Bild bei Zeit `at` (in Takten): fällige Takte, dann Anzeige.
func _frame(at: float) -> void:
	while ticks_done < int(floor(at)):
		_tick()
	smoother.manual_fraction = clampf(at - float(ticks_done), 0.0, 1.0)
	smoother._process(0.0)
	flight._process(STEP)


## Anzeige-Hebung über der geglätteten Spiel-Lage (nur der Wirbel-Versatz).
func _display_lift(node: Node3D) -> float:
	var entry: Dictionary = smoother._entries[node.get_instance_id()]
	var smooth: Transform3D = (entry.prev as Transform3D).interpolate_with(
		entry.curr, smoother.manual_fraction
	)
	return node.transform.origin.y - smooth.origin.y


func _rocket() -> Node3D:
	for entry in game.item_runtime.projectiles:
		if str(entry.kind) == "homing" and is_instance_valid(entry.node):
			return entry.node
	return null


func _test_tumble_shape() -> void:
	# Kart-Kasten (m): Breite ±0,8, Höhe 0..0,9, Länge ±1,2. Er darf nie unter die Fahrbahn.
	var lowest: float = INF
	var peak: float = 0.0
	var rolled_low: bool = false
	for i in range(101):
		var u: float = i / 100.0
		var offset: Transform3D = FLIGHT.tumble_offset(u, "rocket", false)
		for x in [-0.8, 0.8]:
			for y in [0.0, 0.9]:
				for z in [-1.2, 1.2]:
					lowest = minf(lowest, (offset * Vector3(x, y, z)).y)
		var centre: float = (offset * Vector3(0, FLIGHT.TUMBLE_PIVOT, 0)).y - FLIGHT.TUMBLE_PIVOT
		peak = maxf(peak, centre)
	for u in [0.0, 0.9, 0.95, 1.0]:
		var settle: Transform3D = FLIGHT.tumble_offset(u, "rocket", false)
		rolled_low = (
			rolled_low
			or settle.origin.length() > 0.001
			or not settle.basis.is_equal_approx(Basis.IDENTITY)
		)
	_check(
		lowest >= -0.03,
		"Wirbel: kein Teil des Karts unter der Fahrbahn (tiefster Punkt %.3f m)" % lowest
	)
	_check(peak >= 1.2 and peak <= 2.4, "Wirbel: Schwerpunkt steigt sichtbar hoch (%.2f m)" % peak)
	_check(not rolled_low, "Wirbel: nach dem Aufsetzer steht das Kart wieder gerade")
	var mild_peak: float = 0.0
	var mild_roll: bool = false
	for i in range(101):
		var mild: Transform3D = FLIGHT.tumble_offset(i / 100.0, "mild", false)
		mild_peak = maxf(mild_peak, mild.origin.y)
		mild_roll = mild_roll or absf(mild.basis.get_euler().z) > 0.01
	_check(
		mild_peak > 0.2 and mild_peak < 0.8 and not mild_roll,
		"Kind: milder Hüpfer ohne Rolle (%.2f m)" % mild_peak
	)
	var calm := true
	for i in range(101):
		calm = (
			calm
			and FLIGHT.tumble_offset(i / 100.0, "rocket", true).is_equal_approx(
				Transform3D.IDENTITY
			)
		)
	_check(calm, "ruhige Bewegung: kein Wirbel")


func _place_rival(gap: float) -> void:
	var d: float = float(game.distance)
	for i in range(game.opponents.size()):
		var od: float = d + gap if i == 0 else d - 70.0 - i * 6.0
		var lane: float = float(game.lane) if i == 0 else 3.0
		game.opponents[i].transform = game.world.reset_transform(od, lane)
		game.opponent_distances[i] = od
		game.opponent_lanes[i] = lane
		game.opponent_headings[i] = game._heading(od)
		game.opponents[i].motion_speed = float(game.speed)
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 60.0
		game.opponent_shield_times[i] = 0.0
		game.opponent_aurora_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
		game.opponent_spin_times[i] = 0.0


func _fire_at_rival() -> void:
	game._grant_item("star_rocket")
	game.item_hint = ""
	game._use_item()
	var guard: int = 0
	while game.lock_progress < 0.6 and guard < 240:
		_tick()
		guard += 1
	# Auf langen Bögen kann ein weit hinten platzierter Rivale im Zielkegel liegen:
	# der Test zielt eindeutig auf Rivale 0.
	game.lock_target = 0
	game.lock_progress = 1.0
	game._use_item()


func _test_flight_and_hit() -> void:
	_place_rival(30.0)
	for _i in range(3):
		_tick()
	var checkpoint_before: int = int(game.checkpoint_index)
	_fire_at_rival()
	var gap0: float = float(game.opponent_distances[0]) - float(game.distance)
	var start: int = ticks_done
	var frame: int = 0
	var previous: Vector3 = Vector3.INF
	var steps: Array[float] = []
	var hit_tick: int = -1
	var trail_seen: bool = false
	var light_seen: bool = false
	var max_display: float = 0.0
	var true_lift: float = 0.0
	var assist_seen: float = 0.0
	var distances_rise: bool = true
	var last_rival_d: float = float(game.opponent_distances[0])
	var landed: bool = false
	while frame < 360:
		frame += 1
		# 60 Bilder/s mit ±3 ms Zittern: so springt die Rakete ohne Glättung 0 oder 2 Takte.
		_frame(float(start) + frame + rng.randf_range(-0.18, 0.18))
		var rocket: Node3D = _rocket()
		if hit_tick < 0 and rocket != null:
			var p: Vector3 = rocket.global_position
			if previous != Vector3.INF:
				steps.append(previous.distance_to(p))
			previous = p
			trail_seen = trail_seen or flight.trail_count() > 0
			light_seen = light_seen or rocket.get_node_or_null("RocketGlow") != null
			assist_seen = maxf(assist_seen, flight.assist)
		if hit_tick < 0 and game.opponent_spin_times[0] > 0.0:
			hit_tick = ticks_done
		if hit_tick >= 0:
			max_display = maxf(max_display, _display_lift(game.opponents[0]))
			# Die echte Lage (wie sie die Spiellogik sieht) bleibt auf der Fahrbahn.
			var road_y: float = (
				game
				. _track_position(float(game.opponent_distances[0]), float(game.opponent_lanes[0]))
				. y
			)
			true_lift = maxf(
				true_lift,
				(
					(
						(smoother._entries[game.opponents[0].get_instance_id()].curr as Transform3D)
						. origin
						. y
					)
					- road_y
				)
			)
			distances_rise = (
				distances_rise and float(game.opponent_distances[0]) >= last_rival_d - 0.001
			)
			last_rival_d = float(game.opponent_distances[0])
			if game.opponent_spin_times[0] <= 0.0 and not flight.tumbles.has(0):
				landed = true
				break
	var seconds: float = (hit_tick - start) * STEP if hit_tick >= 0 else INF
	_check(hit_tick >= 0, "eigene Rakete trifft den Rivalen %.1f m voraus" % gap0)
	_check(
		seconds >= 0.8 and seconds <= 3.0,
		"Flugdauer im Zielbereich 0,8–3,0 s (%.2f s bei %.1f m)" % [seconds, gap0]
	)
	print(
		(
			"[KartRocketPresentation] Flug %.2f s bei %.1f m, %d Bilder, größter Schritt %.2f m"
			% [seconds, gap0, steps.size(), steps.max() if not steps.is_empty() else -1.0]
		)
	)
	var zero: int = steps.filter(func(v): return v < 0.001).size()
	var biggest: float = steps.max() if not steps.is_empty() else 99.0
	_check(steps.size() >= 40, "Rakete über viele Bilder verfolgbar (%d Bilder)" % steps.size())
	_check(zero == 0, "kein Bild ohne Bewegung (%d)" % zero)
	_check(biggest <= 2.2, "kein Sprung über 2,2 m je Bild (%.2f m)" % biggest)
	_check(trail_seen and light_seen, "Rauchspur und Eigenlicht während des Flugs")
	_check(int(flight.stats.muzzles) >= 2, "Mündungsblitz an beiden Halterdüsen")
	_check(int(flight.stats.impacts) >= 1, "Einschlag mit Blitz, Rauchwolke und Funken")
	_check_mild_impact(flight)
	_check(
		game.kart_audio != null and game.kart_audio._loop_fed.has("rocket_fly"),
		"Fluggeräusch wird während des Flugs gespeist"
	)
	_check(assist_seen > 0.5, "Kamera zieht beim Zuschauen leicht auf (%.2f)" % assist_seen)
	_check(max_display >= 1.0, "Treffer hebt den Rivalen sichtbar an (%.2f m)" % max_display)
	_check(true_lift < 0.25, "Spiel-Lage des Rivalen bleibt auf der Fahrbahn (%.2f m)" % true_lift)
	_check(landed, "Rivale landet und fängt sich")
	var settled: float = _display_lift(game.opponents[0])
	_check(absf(settled) < 0.05, "nach der Landung keine Anzeige-Hebung mehr (%.3f m)" % settled)
	_check(distances_rise, "Rivale fährt während des Wirbels weiter (Fortschritt sinkt nie)")
	_check(
		int(game.checkpoint_index) >= checkpoint_before,
		"Checkpointzählung des Kindes läuft normal weiter"
	)
	_check(
		(
			int(game.item_runtime.stats.hits) >= 1
			and int(game.gameplay_stats.get("player_hits_scored", 0)) == 1
		),
		"genau ein Treffer gezählt"
	)


func _test_grace() -> void:
	var spin_before: float = float(game.opponent_spin_times[0])
	game.opponent_grace_times[0] = 2.0
	var scored: int = int(game.gameplay_stats.get("player_hits_scored", 0))
	game._apply_item_event(
		{
			"type": "hit",
			"target": 0,
			"source": -1,
			"item": "star_rocket",
			"spin": 1.1,
			"position": game.opponents[0].global_position,
			"pair": 99
		}
	)
	_check(
		(
			int(game.gameplay_stats.get("player_hits_scored", 0)) == scored
			and float(game.opponent_spin_times[0]) <= spin_before + 0.001
		),
		"Schonzeit: kein zweiter Wirbel gleich nach einem Treffer"
	)
	game.player_grace_time = 0.0
	game._rescue_from_gap()
	_check(
		float(game.player_grace_time) > 0.0,
		"Schonzeit nach dem Rücksetzer (%.1f s)" % float(game.player_grace_time)
	)
	game.player_grace_time = 0.0


func _test_no_leak() -> void:
	var baseline_children: int = game.item_runtime.get_child_count()
	var fired: int = 0
	for salvo in range(20):
		_place_rival(14.0)
		game.opponent_grace_times[0] = 0.0
		var launches: Array = []
		if game.item_runtime.fire_pair(
			"star_rocket",
			-1,
			float(game.distance),
			float(game.lane),
			0 if salvo % 2 == 0 else -99,
			launches,
			float(game.speed)
		):
			fired += 1
		for i in range(40):
			_frame(float(ticks_done) + 1.0)
			if i % 20 == 0:
				await process_frame
		_check(
			flight.trail_count() <= FLIGHT.MAX_TRAILS,
			"Spurbudget gehalten (Salve %d: %d)" % [salvo, flight.trail_count()]
		)
	for i in range(420):
		_frame(float(ticks_done) + 1.0)
		if i % 30 == 0:
			await process_frame
	await process_frame
	await process_frame
	_check(fired == 20, "20 Salven abgefeuert (%d)" % fired)
	_check(game.item_runtime.projectiles.is_empty(), "alle Raketen beendet")
	_check(flight.trail_count() == 0, "alle Rauchspuren aufgelöst (%d)" % flight.trail_count())
	var leftovers: int = 0
	for node in game.race_root.find_children("Rocket*", "", true, false):
		if (
			node.name.begins_with("RocketSmokeTrail")
			or node.name.begins_with("RocketGlowCore")
			or node.name == "RocketGlow"
		):
			leftovers += 1
	_check(leftovers == 0, "keine Spur-/Lichtknoten übrig (%d)" % leftovers)
	_check(
		game.item_runtime.get_child_count() <= baseline_children,
		(
			"Item-Laufzeit ohne Restknoten (%d > %d)"
			% [game.item_runtime.get_child_count(), baseline_children]
		)
	)
	_check(
		int(flight.stats.max_trail_points) <= int(FLIGHT.TRAIL_POINTS[flight.quality]),
		"Punktbudget je Spur eingehalten (%d)" % int(flight.stats.max_trail_points)
	)


func _test_reduced_motion() -> void:
	game.reduced_motion = true
	game.item_runtime.reduced_motion = true
	_place_rival(45.0)
	for _i in range(3):
		_tick()
	_fire_at_rival()
	var max_assist: float = 0.0
	var pip_seen: bool = false
	var max_display: float = 0.0
	for frame in range(240):
		_frame(float(ticks_done) + 1.0)
		max_assist = maxf(max_assist, flight.assist)
		pip_seen = pip_seen or flight.pip_visible()
		if game.opponent_spin_times[0] > 0.0:
			max_display = maxf(max_display, _display_lift(game.opponents[0]))
	_check(max_assist < 0.001, "ruhige Bewegung: Kamera zieht nicht auf")
	_check(not pip_seen, "ruhige Bewegung: kein Trefferbild")
	_check(max_display < 0.01, "ruhige Bewegung: Rivale wirbelt nicht hoch (%.3f m)" % max_display)
	game.reduced_motion = false
	game.item_runtime.reduced_motion = false


func _test_pip_far_target() -> void:
	# Rivalen weichen Raketen manchmal aus: bis zu drei Salven, eine muss sitzen.
	var pip_frames: int = 0
	var hit: bool = false
	for _attempt in range(3):
		_place_rival(48.0)
		for _i in range(3):
			_tick()
		_fire_at_rival()
		pip_frames = 0
		for frame in range(300):
			_frame(float(ticks_done) + 1.0)
			if flight.pip_visible():
				pip_frames += 1
			if game.opponent_spin_times[0] > 0.0:
				hit = true
			if hit and not flight.pip_visible() and flight.pip_time <= 0.0:
				break
			if not hit and game.item_runtime.projectiles.is_empty() and frame > 30:
				break
		if hit:
			break
	_check(hit, "ferner Rivale (48 m) wird getroffen")
	_check(pip_frames >= 40, "Trefferbild zeigt den fernen Einschlag (%d Bilder)" % pip_frames)


## Übrige Items: je die ergänzte Rückmeldung (ohne Spielwirkung).
func _test_item_feedback() -> void:
	var fired: Dictionary = game.fx.fired
	var before: Dictionary = fired.duplicate()
	game.item = "boost"
	game.item_charges = 1
	game.item_roulette_time = 0.0
	game._use_item()
	_check(
		int(fired.get("boost_pad", 0)) > int(before.get("boost_pad", 0)),
		"Rückenwind: Schub-Funken und Turbo-Klang beim Auslösen"
	)
	game.item = "triple_boost"
	game.item_charges = 3
	game._use_item()
	_check("Noch 2×" in str(game.message.text), "Kometen-Trio: zeigt verbleibende Schübe")
	game.item = ""
	game.item_charges = 0
	game.item_runtime.fire_bouncing("spark_ball", -1, float(game.distance), 0.0, 40.0)
	for _i in range(30):
		_tick()
	_check(int(fired.get("spark_bounce", 0)) > 0, "Funkenkugel: Funken und Klang an der Bande")
	game.item_runtime.drop_trap("bubble_trap", 0, float(game.distance) - 40.0, 3.5)
	game.item_runtime.traps[-1].life = 0.05
	for _i in range(6):
		_tick()
	_check(
		int(fired.get("bubble_pop", 0)) > 0, "Blubberblase: sichtbares Platzen, wenn sie abläuft"
	)
	game.magnet_time = 1.5
	_tick()
	_check(game.item_status_fx.magnet_ring.visible, "Sternmagnet: Ring am Kart, solange er zieht")
	var ends: int = int(fired.get("item_end", 0))
	game.magnet_time = 0.0
	_tick()
	_check(
		not game.item_status_fx.magnet_ring.visible and int(fired.get("item_end", 0)) > ends,
		"Sternmagnet: Ende sichtbar"
	)
	game.aurora_time = 2.0
	_tick()
	_check(game.item_status_fx.aurora_ring.visible, "Nordlicht-Lauf: Lichtring am Kart")
	game.aurora_time = 0.0
	game.shield_time = 0.0
	_tick()


func _run() -> void:
	rng.seed = 7
	seed(7)
	_test_tumble_shape()
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	root.size = Vector2i(1600, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = true
	await process_frame
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game._end_preview()
	game.set_physics_process(false)
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	smoother = game.frame_smoother
	flight = game.rocket_flight
	_check(
		smoother != null and flight != null,
		"Bild-Glätter und Raketen-Inszenierung im Rennen vorhanden"
	)
	if smoother == null or flight == null:
		_finish()
		return
	smoother.manual = true
	for i in range(300):
		_tick()
		if i % 60 == 0:
			await process_frame
	_test_flight_and_hit()
	_test_grace()
	await _test_no_leak()
	_test_reduced_motion()
	_test_pip_far_target()
	_test_item_feedback()
	_finish()


func _finish() -> void:
	if is_instance_valid(game):
		await TEARDOWN.release_scene(self, game, "[KartRocketPresentation]")
	if failures.is_empty():
		print(
			(
				"[KartRocketPresentation] PASS: %d checks – %s"
				% [checks, "Flug, Spur, Einschlag, Wirbel, Schonzeit, ruhige Bewegung, Trefferbild"]
			)
		)
		quit(0)
	else:
		print(
			(
				"[KartRocketPresentation] FAIL: %d of %d checks: %s"
				% [failures.size(), checks, failures]
			)
		)
		quit(1)


## Milder Einschlag (Kind getroffen, Stärke 0,4): Rauch und Funken kleiner als beim
## vollen Treffer, danach wieder volle Größe.
func _check_mild_impact(flight: Node) -> void:
	var at := Vector3(0.0, 1.0, 0.0)
	flight.impact(at, 1.0)
	var full: CPUParticles3D = (
		flight
		. _impacts[(flight._impact_cursor + flight._impacts.size() - 1) % flight._impacts.size()]
		. smoke
	)
	var full_max := full.scale_amount_max
	flight.impact(at, 0.4)
	var mild: CPUParticles3D = (
		flight
		. _impacts[(flight._impact_cursor + flight._impacts.size() - 1) % flight._impacts.size()]
		. smoke
	)
	_check(
		mild.scale_amount_max < full_max * 0.6,
		"milder Einschlag: Rauch kleiner (%.2f statt %.2f)" % [mild.scale_amount_max, full_max]
	)
	flight.impact(at, 1.0)
	var again: CPUParticles3D = (
		flight
		. _impacts[(flight._impact_cursor + flight._impacts.size() - 1) % flight._impacts.size()]
		. smoke
	)
	_check(
		is_equal_approx(again.scale_amount_max, full_max),
		"voller Einschlag danach wieder volle Größe"
	)
