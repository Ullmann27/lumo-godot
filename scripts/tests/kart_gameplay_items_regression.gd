extends SceneTree
## Lumo-Kart arcade layer: data-driven items, rockets/sparks/bubbles with friendly spins,
## shields, interception, rival item AI, slipstream, three drift tiers, air tricks,
## boost combos, catch-up help and the reusable item box / boost ring / boost pad scenes.
const STEP: float = 1.0 / 60.0
const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const RUNTIME = preload("res://scripts/games/kart_items/kart_item_runtime.gd")
const FX = preload("res://scripts/games/kart_items/kart_fx_director.gd")
var game
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[KartGameplay] FAIL: " + label)


func _start(mode: String, track: String) -> void:
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"}
	)
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame


func _test_catalog() -> void:
	var items: Array[Dictionary] = CATALOG.all()
	_check(items.size() == 9, "nine original items in the catalog (%d)" % items.size())
	for forbidden in ["shell", "banana", "panzer", "bob-omb", "blooper", "bullet"]:
		for row in items:
			_check(not forbidden in str(row.id).to_lower() and not forbidden in str(row.name).to_lower(), "no borrowed item name: " + forbidden)
	_check(not CATALOG.validate({"id": "x", "name": "x", "short": "x", "behaviour": "laser", "weights": [1, 1, 1, 1, 1, 1], "color": "#fff"}).is_empty(), "unknown behaviour rejected")
	_check(not CATALOG.validate({"id": "x", "name": "x", "short": "x", "behaviour": "boost", "weights": [1, 1], "color": "#fff"}).is_empty(), "weights per place enforced")
	for place in range(1, 7):
		var total: float = 0.0
		for value in CATALOG.odds(place).values():
			total += value
		_check(absf(total - 1.0) < 0.001, "odds at place %d sum to 1" % place)
	# Auftrag 19.11.2026: Platz 1 selten, aber nicht unmöglich; hinten deutlich häufiger.
	var leader_rockets: float = CATALOG.odds(1)["star_rocket"]
	_check(leader_rockets > 0.0 and leader_rockets < 0.08, "the leader rarely draws homing rockets")
	_check(CATALOG.odds(4)["star_rocket"] > leader_rockets * 3.0, "chasers draw rockets far more often")
	_check(CATALOG.odds(1)["aurora"] == 0.0 and CATALOG.odds(6)["aurora"] > 0.15, "Nordlicht is a comeback item")
	_check(CATALOG.odds(6)["shield"] < CATALOG.odds(1)["shield"], "leaders defend, chasers attack")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var counts := {}
	for i in range(3000):
		var id: String = CATALOG.roll(6, rng)
		counts[id] = int(counts.get(id, 0)) + 1
	_check(int(counts.get("aurora", 0)) > 450, "6th place often gets Nordlicht (%d of 3000)" % int(counts.get("aurora", 0)))
	var shifted := 0
	var plain := 0
	rng.seed = 7
	for i in range(2000):
		if CATALOG.roll(3, rng, 1.0) == "aurora":
			shifted += 1
		if CATALOG.roll(3, rng, 0.0) == "aurora":
			plain += 1
	_check(plain == 0 and shifted > 150, "far-behind catch-up shifts odds toward comeback items (%d vs %d)" % [shifted, plain])
	_check(CATALOG.label("star_rocket").begins_with("RAKETE"), "HUD label from data")


func _test_rules() -> void:
	_check(RULES.drift_tier(0.5) == -1 and RULES.drift_tier(0.9) == 0 and RULES.drift_tier(2.0) == 1 and RULES.drift_tier(2.9) == 2, "three drift tiers")
	_check(RULES.drift_label(2.9) == "LILA!", "purple drift label")
	var forward := Vector3(0, 0, -1)
	_check(RULES.in_slipstream(Vector3.ZERO, forward, Vector3(0.4, 0, -5), 18.0), "wake directly behind a kart")
	_check(not RULES.in_slipstream(Vector3.ZERO, forward, Vector3(3.0, 0, -5), 18.0), "too far to the side")
	_check(not RULES.in_slipstream(Vector3.ZERO, forward, Vector3(0, 0, 5), 18.0), "kart behind gives no tow")
	_check(not RULES.in_slipstream(Vector3.ZERO, forward, Vector3(0, 0, -5), 5.0), "too slow for a tow")
	_check(is_equal_approx(RULES.player_catch_up(5.0, "gemuetlich"), 1.0), "no help in close racing")
	_check(RULES.player_catch_up(200.0, "gemuetlich") <= 1.1001 and RULES.player_catch_up(200.0, "gemuetlich") > 1.09, "bounded help far behind")
	_check(RULES.rival_rubber_band(120.0, "gemuetlich") < 0.9, "runaway rivals ease off")
	for level in ["gemuetlich", "flott", "pro"]:
		_check(is_equal_approx(RULES.rival_rubber_band(-120.0, level), 1.0), "overtaken rivals get no push (%s)" % level)
	_check(RULES.rival_rubber_band(120.0, "profi") > RULES.rival_rubber_band(120.0, "gemuetlich"), "less rubber band on harder settings")
	_check(RULES.next_combo(1, 1.0) == 2 and RULES.next_combo(4, 9.0) == 1, "combo chains within the window only")
	_check(RULES.rival_should_use("star_rocket", "homing_projectile", {"ahead_gap": 20.0}), "AI fires rocket at a racer ahead")
	_check(not RULES.rival_should_use("star_rocket", "homing_projectile", {"ahead_gap": INF}), "AI keeps rocket without target")
	_check(RULES.rival_should_use("bubble_trap", "dropped_trap", {"behind_gap": 6.0}), "AI drops a bubble for a chaser")
	_check(RULES.rival_should_use("shield", "shield", {"threatened": true}), "AI shields against an incoming rocket")


func _test_runtime_unit() -> void:
	var runtime = RUNTIME.new()
	root.add_child(runtime)
	runtime.setup(500.0, 4.6, func(d: float, l: float) -> Transform3D: return Transform3D(Basis(), Vector3(l, 0, -d)))
	runtime.fire_homing("star_rocket", -1, 10.0, 0.0, 0)
	var racers := [{"key": -1, "progress": 10.0, "lateral": 0.0}, {"key": 0, "progress": 40.0, "lateral": 2.5}]
	var hit: Dictionary = {}
	for frame in range(120):
		racers[1].progress += 10.0 * STEP
		for event in runtime.step(STEP, racers):
			hit = event
		if not hit.is_empty():
			break
	_check(str(hit.get("type", "")) == "hit" and int(hit.get("target", -9)) == 0, "homing rocket steers across lanes into its target")
	runtime.fire_homing("star_rocket", 0, 5.0, 0.0, -1)
	runtime.drop_trap("bubble_trap", -1, 14.0, 0.0)
	var intercepted := false
	for frame in range(60):
		for event in runtime.step(STEP, [{"key": -1, "progress": 14.0, "lateral": 0.0}, {"key": 0, "progress": 0.0, "lateral": 0.0}]):
			intercepted = intercepted or str(event.type) == "intercepted"
	_check(intercepted and runtime.active_count() == 0, "a bubble behind the player swallows the rocket")
	# A racer drives into a bubble: one clean hit event (found by the two-lap
	# race in CI: traps carried no pair field and the hit raised an error).
	runtime.clear()
	runtime.drop_trap("bubble_trap", 3, 30.0, 0.0)
	var trap_events: Array[Dictionary] = []
	for i in range(30):
		trap_events.append_array(runtime.step(STEP, [{"key": -1, "progress": 27.8, "lateral": 0.0}]))
	_check(trap_events.size() == 1 and str(trap_events[0].type) == "hit" and int(trap_events[0].target) == -1
		and int(trap_events[0].source) == 3 and int(trap_events[0].pair) == 0 and runtime.traps.is_empty(),
		"driving into a bubble gives exactly one hit event")
	runtime.clear()
	runtime.fire_bouncing("spark_ball", -1, 0.0, 4.0, 8.0)
	var widest := 0.0
	for frame in range(60):
		runtime.step(STEP, [])
		for entry in runtime.projectiles:
			widest = maxf(widest, absf(float(entry.lateral)))
	_check(widest <= 4.6 + 0.001, "spark ball bounces off the rails")
	runtime.fire_bouncing("spark_ball", -1, 0.0, 0.0, 0.0)
	var blocked := false
	for frame in range(60):
		for event in runtime.step(STEP, [{"key": 2, "progress": 20.0, "lateral": 0.0, "protected": true}]):
			blocked = blocked or str(event.type) == "blocked"
	_check(blocked, "a shielded kart blocks the spark ball")
	for i in range(30):
		runtime.fire_bouncing("spark_ball", -1, 0.0, 0.0, 0.0)
	_check(runtime.projectiles.size() <= runtime.MAX_PROJECTILES, "projectile budget for phones")
	runtime.queue_free()


func _test_props() -> void:
	var pad: Node3D = load("res://scenes/games/props/kart_boost_pad.tscn").instantiate()
	root.add_child(pad)
	_check(pad.contains(Vector3(0, 0.3, 0)) and not pad.contains(Vector3(3.0, 0.3, 0)), "boost pad area")
	_check(pad.is_in_group("lumo_kart_triggers") and pad.trigger_kind == "boost_pad", "pad joins the trigger group")
	var ring: Node3D = load("res://scenes/games/props/kart_boost_ring.tscn").instantiate()
	root.add_child(ring)
	_check(ring.crossed(Vector3(0, 1, 1), Vector3(0, 1, -1)), "driving through the ring along -Z triggers")
	_check(not ring.crossed(Vector3(0, 1, -1), Vector3(0, 1, 1)), "driving backwards does not")
	_check(not ring.crossed(Vector3(4, 1, 1), Vector3(4, 1, -1)), "passing beside the ring does not")
	var box: Node3D = load("res://scenes/games/props/kart_item_box.tscn").instantiate()
	root.add_child(box)
	var layered: bool = (
		box.get_node_or_null("MysteryPrismCore") != null
		and box.get_node_or_null("SurpriseStar") is Label3D
		and box.get_node_or_null("MysteryPrismInner") != null
		and box.get_node_or_null("PrismRail1/Rail") != null
		and box.get_child_count() == 7
	)
	_check(layered, "item box: layered star prism (shells, edges, two light rails, beacon) + star core")
	_check(box.contains(Vector3(0, 0, 1.0)), "item box pickup radius")
	box.pop()
	_check(not box.contains(Vector3.ZERO), "popped box waits for respawn")
	for frame in range(int(box.respawn_seconds / STEP) + 2):
		box._process(STEP)
	_check(box.contains(Vector3.ZERO), "free-standing box respawns")
	for node in [pad, ring, box]:
		node.queue_free()


func _test_fx() -> void:
	var director = FX.new()
	root.add_child(director)
	var overlay := Control.new()
	root.add_child(overlay)
	director.setup(overlay, "medium", false)
	_check(director.trigger("boost_ring", Vector3.ZERO) and director.camera_fov_kick() > 0.0, "ring pushes the camera")
	_check(director.flash_alpha > 0.0, "screen flash")
	_check(not director.trigger("nope", Vector3.ZERO), "unknown fx ignored")
	director.reduced_motion = true
	director.kick = 0.0
	director.trigger("hit_spin", Vector3.ZERO)
	_check(director.camera_fov_kick() == 0.0 and director.camera_shake() == Vector3.ZERO, "reduced motion: no shake or FOV punch")
	director.queue_free()
	overlay.queue_free()


func _test_race_integration() -> void:
	await _start("race", "sonnenhafen")
	# HEAD keeps its skill resonance rings in item_boxes; the surprise boxes are an own row.
	_check(
		game.catalog_boxes.size() >= 15 and game.catalog_boxes[0] is LumoKartItemBox,
		"race uses the reusable item box scene (5–8 Sammelzonen × 2–3 Prismen)"
	)
	_check(not game.item_boxes.is_empty() and str(game.item_boxes[0].name).begins_with("SkillResonanceRing"), "skill resonance rings stay")
	_check(game.track_triggers.size() == 2, "two built-in boost rings")
	_check(is_instance_valid(game.item_runtime) and is_instance_valid(game.fx), "item runtime and fx director live")
	# Player rockets: pods unfold, first tap arms + locks the rival ahead, second tap fires a pair.
	game.distance = 60.0
	game.lane = 0.0
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = 5.0 + i
	game.opponent_distances[1] = 85.0
	game.opponent_lanes[1] = 1.5
	_place_racers()
	game._grant_item("star_rocket")
	_check(game.rocket_phase == "ready" and game.item_charges == 2, "rockets: two salvos ready after pickup")
	_check(is_instance_valid(game.player_pods) and game.player_pods.pairs_left() == 2, "rocket pods are filled (2 per side)")
	game._use_item()
	_check(game.rocket_phase == "armed" and game.item_runtime.projectiles.is_empty(), "first tap arms, nothing fired yet")
	for frame in range(60):
		game._update_item_experience(STEP)
	_check(game.lock_target == 1 and game.lock_progress >= 1.0, "lock-on picks the nearest rival ahead in the sight cone")
	game._use_item()
	_check(game.item == "star_rocket" and game.item_charges == 1 and game.item_runtime.projectiles.size() == 2, "second tap fires one pair, one salvo left")
	_check(int(game.item_runtime.projectiles[0].target) == 1 and int(game.item_runtime.projectiles[1].target) == 1, "both rockets chase the locked rival")
	_check(game.player_pods.pairs_left() == 1 and game.rocket_phase == "armed", "pods keep the second pair armed")
	for frame in range(120):
		game.opponent_distances[1] += 6.0 * STEP
		game._update_gameplay_layer(STEP)
		if game.opponent_spin_times[1] > 0.0:
			break
	_check(game.opponent_spin_times[1] > 0.0 and int(game.gameplay_stats.player_hits_scored) == 1, "rival spins after the hit")
	_check("dreht sich" in game.message.text or "wirbelt" in game.message.text, "friendly hit message")
	for frame in range(30):
		game._update_gameplay_layer(STEP)
	_check(int(game.gameplay_stats.player_hits_scored) == 1 and game.item_runtime.projectiles.is_empty(), "a pair counts as one hit")
	_check(game.opponent_grace_times[1] > 0.0, "Schonzeit after a hit")
	game.item_runtime.clear()
	game.item = ""
	game.item_charges = 0
	game._sync_player_rocket_phase()
	game.opponent_spin_times[1] = 0.0
	game.opponent_grace_times[1] = 0.0
	# Spin visual is applied on top of physics and never accumulates.
	var before: Basis = game.player.basis
	game._spin_player(1.0)
	game._update_gameplay_layer(0.3)
	_check(not game.player.basis.is_equal_approx(before), "player kart visibly spins")
	game.player_spin_time = 0.0
	game._update_gameplay_layer(STEP)
	_check(game.player.basis.is_equal_approx(before), "spin visual restores the physics pose")
	# Triple boost keeps charges.
	game._grant_item("triple_boost")
	game._use_item()
	_check(game.item == "triple_boost" and game.item_charges == 2 and game.boost_time > 0.0, "Kometen-Trio has three charges")
	game._use_item()
	game._use_item()
	_check(game.item.is_empty(), "all charges used")
	# Rival AI locks onto the player ahead (warning first), then fires; a shield blocks it.
	game.item_runtime.clear()
	# Mitten im Rennen an ruhiger Stelle (Startschutz/Sturzstellen: kart_rocket_fairness.gd).
	game.elapsed = maxf(game.elapsed, 40.0)
	game.distance = 200.0
	game.opponent_distances[0] = 175.0
	game.opponent_lanes[0] = game.lane
	game.opponent_items[0] = "star_rocket"
	game.opponent_item_cooldowns[0] = 0.0
	game.opponent_rocket_hold[0] = 99.0
	var warned := false
	for frame in range(240):
		game._update_item_experience(STEP)
		warned = warned or game.player_warning > 0.0
		if not game.item_runtime.projectiles.is_empty():
			break
	_check(warned, "player is warned while a rival locks on")
	_check(game.item_runtime.projectiles.size() == 2 and game.opponent_items[0] == "star_rocket", "rival AI fires a pair and keeps one salvo")
	_check("Sternraketen" in game.message.text, "player is warned about the rocket")
	game.shield_time = 3.0
	var hits_before: int = int(game.gameplay_stats.player_hits_taken)
	for frame in range(90):
		game._update_gameplay_layer(STEP)
	_check(int(game.gameplay_stats.blocked) >= 1 and int(game.gameplay_stats.player_hits_taken) == hits_before, "shield blocks the rival rocket")
	# Rival with a shield item raises it when a rocket is incoming.
	game.item_runtime.clear()
	game.opponent_items[2] = "shield"
	game.opponent_shield_times[2] = 0.0
	game.item_runtime.fire_homing("star_rocket", -1, game.opponent_distances[2] - 6.0, game.opponent_lanes[2], 2)
	game._update_rival_item_tactics(2, Vector3(0, 0, 40), STEP)
	_check(game.opponent_shield_times[2] > 0.0, "rival raises its shield against an incoming rocket")
	game.item_runtime.clear()
	# Slipstream: sit in a rival's wake to earn a tow boost.
	game.shield_time = 0.0
	var tow_before: int = int(game.gameplay_stats.slipstreams)
	game.speed = 20.0
	game.player_heading = 0.0
	game.player.global_position = Vector3(0, 0, 0)
	game.opponents[3].global_position = Vector3(0.3, 0, -5.0)
	for frame in range(80):
		game._update_slipstream(STEP)
	_check(int(game.gameplay_stats.slipstreams) == tow_before + 1 and game.boost_time > 0.0, "slipstream tow boost")
	# Air trick (HEAD system kart_air_trick.gd): hold DRIFT in the air, land for the extra turbo.
	game.airborne = true
	game.air_time = 0.2
	game.air_trick = {}
	game._press_drift()
	game._update_air_trick(STEP)
	_check(game.drifting and not game.air_trick.is_empty(), "air trick starts from DRIFT in the air")
	var tricks_before: int = int(game.gameplay_stats.tricks)
	game.air_trick = {"state": "done", "kind": "salto", "sign": 1.0, "spun": TAU, "duration": 0.9, "completed": true}
	game.airborne = true
	game.air_time = 0.9
	var landing_road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	game.player.position.y = float(landing_road.height) - 0.4
	game.vertical_speed = -6.0
	game._move_vertically(landing_road, float(landing_road.distance), STEP)
	_check(int(game.gameplay_stats.tricks) == tricks_before + 1 and game.air_trick.is_empty(), "landed trick counts and feeds the combo chain")
	game.airborne = false
	game.drifting = false
	# Driving through a boost ring: turbo, flash and camera push.
	var ring: Node3D = game.track_triggers[0]
	game.boost_time = 0.0
	game.elapsed += 5.0
	game.player_previous_position = ring.to_global(Vector3(0, 1.0, 1.0))
	game.player.global_position = ring.to_global(Vector3(0, 1.0, -1.0))
	game._update_track_triggers()
	_check(game.boost_time > 0.0 and int(game.gameplay_stats.rings) == 1, "boost ring gives a turbo")
	_check(int(game.fx.fired.get("boost_ring", 0)) == 1 and game.fx.flash_alpha > 0.0, "ring fires particles and flash")
	# Combo: two boost sources back to back.
	game._award_boost("boost_pad", 0.5, "")
	_check(game.combo >= 2 and "Turbo-Kette" in game.message.text, "boost chain combo")
	# Catch-up help and data-driven HUD.
	game.distance = 10.0
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = 150.0
	_check(game._gameplay_speed_factor() > 1.05, "far behind: catch-up help")
	game._grant_item("bubble_trap")
	game._update_hud()
	_check(game.item_button.text.begins_with("BLASE"), "item button shows the catalog label")
	# Nordlicht protects and spins rivals on contact.
	game._grant_item("aurora")
	game._use_item()
	_check(game.aurora_time > 0.0 and game.shield_time > 0.0, "Nordlicht-Lauf protects")
	game.opponent_spin_times[4] = 0.0
	game.opponent_shield_times[4] = 0.0
	game.opponents[4].global_position = game.player.global_position + Vector3(0.5, 0, 0)
	game._update_aurora_contacts()
	_check(game.opponent_spin_times[4] > 0.0, "Nordlicht bumps rivals into a spin")


func _place_racers() -> void:
	game.player.global_position = game._track_position(fposmod(game.distance, game.track_length), game.lane)
	game.player_heading = game._heading(fposmod(game.distance, game.track_length))
	for i in range(game.opponents.size()):
		game.opponents[i].global_position = game._track_position(fposmod(game.opponent_distances[i], game.track_length), game.opponent_lanes[i])


func _test_session_validation() -> void:
	await _start("race", "sonnenhafen")
	var config := ConfigFile.new()
	config.set_value("race", "opponent_items", ["star_rocket", "fake_item", "bubble_trap", "", "aurora"])
	game.item = "hacked"
	game._restore_item_continuity(config)
	_check(game.opponent_items[0] == "star_rocket" and game.opponent_items[1] == "" and game.opponent_items[2] == "bubble_trap", "saved rival items validated by catalog")
	_check(game.item.is_empty(), "unknown saved player item dropped")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	_test_catalog()
	_test_rules()
	_test_runtime_unit()
	_test_props()
	_test_fx()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.auto_gas = true
	await process_frame
	await _test_race_integration()
	await _test_session_validation()
	game.abandoned = true
	if is_instance_valid(game.kart_audio):
		game.kart_audio.set_muted(true)
	game.queue_free()
	# Let the audio players release their streams before the engine shuts down.
	for _frame in range(4):
		await process_frame
	if failures.is_empty():
		print("[KartGameplay] PASS: %d checks – items, rockets, sparks, bubbles, shields, rival AI, slipstream, drift tiers, tricks, rings, combos, catch-up" % checks)
		quit(0)
	else:
		print("[KartGameplay] FAIL: %d of %d checks: %s" % [failures.size(), checks, failures])
		quit(1)
