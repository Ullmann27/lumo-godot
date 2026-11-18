extends SceneTree
## Lumo-Kart driving effects (scripts/games/kart_fx/) inside the production race
## scene: every effect appears at its real event and only then.
##   rail contact -> sparks + scrape streak + sound requests (+ jolt, flinch)
##   braking -> marks + smoke + nose dive;  boost -> jets + speed lines
##   drift tiers, launch dust, landing ring, rival sparks, surface styles
##   reduced motion -> no camera jolt / FOV punch / speed lines
##   pause -> nothing is born, the clock stands still; budgets per profile hold.
## godot --headless --path . --script res://scripts/tests/kart_drive_fx_regression.gd

const STYLES = preload("res://scripts/games/kart_fx/kart_fx_surface_styles.gd")
const DRIVE_FX = preload("res://scripts/games/kart_fx/kart_drive_fx.gd")
const STEP := 1.0 / 60.0

var game
var fx
var checks: int = 0
var failures: Array[String] = []
var along: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[KartDriveFx] FAIL " + label)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "drive-fx-regression"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.graphics_profile = "high"
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"
	})
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.reduced_motion = false
	game.auto_gas = false
	fx = game.drive_fx
	_check(is_instance_valid(fx), "race builds the driving-effects node")
	_check(fx.get_parent() == game.race_root, "effects live in the race root (freed with the race)")
	_check(fx.get_child_count() == 4, "three particle/mark batches + one speed-line ring")
	_check(fx.profile == "high", "effects follow the race quality profile")
	_check(fx.owns_engine_sound(), "layered engine replaces the single sine")
	await _cruise_is_quiet()
	await _rail_contact()
	await _braking()
	await _boost_and_reduced_motion()
	await _drift_tiers()
	await _launch_and_landing()
	await _rivals()
	await _extras()
	await _pause_freezes()
	await _budgets()
	_surfaces()
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("[KartDriveFx] PASS %d checks: rail, brake, boost, drift, launch, landing, rivals, pause, budgets, surfaces" % checks)
		quit(0)
	else:
		print("[KartDriveFx] FAIL ", failures)
		quit(1)


func _place(distance: float, lane: float = 0.0) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	game.player.transform = game.world.reset_transform(distance, lane)
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)


func _tick(count: int, advance_metres: float = 0.4) -> void:
	for _i in range(count):
		along += advance_metres
		_place(along, game.lane)
		game._update_vehicles(STEP)


func _clean(speed: float = 20.0) -> void:
	fx.reset()
	fx.counts.clear()
	fx.sounds.clear()
	game.speed = speed
	game.boost_time = 0.0
	game.drifting = false
	game.drift_charge = 0.0
	game.brake_visual_amount = 0.0
	game.airborne = false
	game.steering = 0.0
	game.lane = 0.0
	game.reduced_motion = false
	game.paused = false
	fx._previous_speed = speed
	fx._accel = 0.0
	fx._previous_gas = false
	along = game.track_length * 0.1


func _cruise_is_quiet() -> void:
	_clean()
	_tick(90)
	var state: Dictionary = fx.visual_state()
	_check(state.counts.is_empty(), "steady straight cruise on asphalt emits nothing: " + str(state.counts))
	_check(state.sparks_live == 0 and state.soft_live == 0 and state.marks_live == 0, "no idle particles or marks")
	_check(not state.speed_lines, "no speed lines without turbo")
	_check(absf(state.pitch) < 0.01, "body is level at constant speed")


func _rail_contact() -> void:
	_clean(22.0)
	_tick(4)
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	var wall: float = game._wall_lateral_at(along)
	game.lane = wall + 0.4
	_place(along, game.lane)
	var road_basis: Basis = road.basis
	game.physical_velocity = -road_basis.z * 22.0 + road_basis.x * 9.0
	game.player.driver_hit_pending = false
	var contacts_before: int = game.wall_contacts
	game._collide_with_rail(road)
	_check(game.wall_contacts == contacts_before + 1, "the real rail rule registered the contact")
	game._update_vehicles(STEP)
	var state: Dictionary = fx.visual_state()
	_check(int(state.counts.get("rail_sparks", 0)) > 0, "rail contact sprays sparks")
	_check(int(state.counts.get("rail_burst", 0)) >= 20, "hard hit adds a spark burst")
	_check(int(state.sounds.get("rail_hit", 0)) == 1, "hard hit requests the metal impact sound")
	_check(int(game.kart_audio.fx_requests.get("rail_hit", 0)) >= 1, "the sound request reaches the race audio")
	_check(state.scrape_level > 0.3, "scrape loop is driven by the contact")
	_check(state.shake > 0.0 and fx.camera_shake() != Vector3.ZERO, "hard hit jolts the camera")
	_check(game.player.driver_hit_pending, "the real Lumo driver flinches on a hard hit")
	_check(absf(fx._roll_velocity) > 0.5, "kart body springs away from the rail")
	# Sustained scraping: sparks keep coming while (and only while) touching.
	for _i in range(30):
		game.lane = wall + 0.15
		along += 0.35
		_place(along, game.lane)
		road = game.world.sample_road(game.player.position, along)
		road_basis = road.basis
		game.physical_velocity = -road_basis.z * 20.0 + road_basis.x * 2.5
		game._collide_with_rail(road)
		game._update_vehicles(STEP)
	var scraping: Dictionary = fx.visual_state()
	_check(int(scraping.counts.get("rail_marks", 0)) > 3, "scraping leaves a streak on the rail")
	_check(int(scraping.counts.rail_sparks) > int(state.counts.rail_sparks) + 30, "sparks keep flowing while scraping")
	game.lane = 0.0
	var sparks_before: int = int(scraping.counts.rail_sparks)
	_tick(40)
	var after: Dictionary = fx.visual_state()
	_check(int(after.counts.rail_sparks) == sparks_before, "no rail sparks once the kart left the rail")
	_check(after.scrape_level < 0.01, "scrape sound fades out after the contact")
	_check(after.shake < 0.01, "camera jolt is short")


func _braking() -> void:
	_clean(22.0)
	_tick(4)
	game.brake_visual_amount = 1.0
	for _i in range(40):
		game.speed = maxf(4.5, game.speed - 0.45)
		_tick(1)
	var state: Dictionary = fx.visual_state()
	_check(int(state.counts.get("brake_marks", 0)) > 10, "braking lays down marks: %d" % int(state.counts.get("brake_marks", 0)))
	_check(int(state.counts.get("brake_smoke", 0)) > 0, "full brake at speed smokes the rear tyres")
	_check(state.marks_live > 10, "brake marks stay on the road")
	_check(fx.pitch < -0.01, "kart nose dives under braking (pitch %.3f)" % fx.pitch)
	_check(int(state.counts.get("brake_glow", 0)) > 30 and fx.sparks.live_count() > 0, "brake lamps glow (%s, live %d)" % [str(state.counts.get("brake_glow", 0)), fx.sparks.live_count()])
	game.brake_visual_amount = 0.0
	var marks_before: int = int(state.counts.brake_marks)
	game.speed = 15.0
	fx._previous_speed = 15.0
	_tick(30)
	var released: Dictionary = fx.visual_state()
	_check(int(released.counts.brake_marks) == marks_before, "no new marks after releasing the brake")
	_check(released.marks_live > 0, "marks remain for a few seconds")
	for _i in range(int(float(fx.budget.mark_life) * 60.0) + 30):
		game._update_vehicles(STEP)
	_check(fx.visual_state().marks_live == 0, "marks fade away after their lifetime")


func _boost_and_reduced_motion() -> void:
	_clean(22.0)
	game.boost_time = 2.0
	_tick(2)
	_check(fx.fov_punch > 0.0, "turbo start widens the view")
	_check(int(fx.sounds.get("whoosh", 0)) == 1, "turbo start whooshes once")
	_tick(20)
	var state: Dictionary = fx.visual_state()
	_check(int(state.counts.get("boost_jet", 0)) > 10, "turbo jets from the exhausts")
	_check(int(state.counts.get("heat", 0)) > 0, "heat wisps above the jets")
	_check(int(state.counts.get("swirl", 0)) > 0, "air swirls around the kart")
	_check(state.speed_lines and state.line_intensity > 0.5, "speed lines at the screen edge during turbo")
	game.boost_time = 0.0
	_tick(40)
	_check(not fx.visual_state().speed_lines, "speed lines leave after the turbo")
	# Reduced motion: same events, but no jolt, no FOV punch, no speed lines.
	_clean(22.0)
	game.reduced_motion = true
	game.boost_time = 2.0
	_tick(20)
	_check(not fx.visual_state().speed_lines, "reduced motion: no speed lines")
	_check(fx.camera_fov_kick() == 0.0, "reduced motion: no FOV punch")
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	game.lane = game._wall_lateral_at(along) + 0.4
	_place(along, game.lane)
	game.physical_velocity = -(road.basis as Basis).z * 22.0 + (road.basis as Basis).x * 10.0
	game._collide_with_rail(road)
	game._update_vehicles(STEP)
	_check(int(fx.counts.get("rail_sparks", 0)) > 0, "reduced motion still shows the sparks")
	_check(fx.shake == 0.0 and fx.camera_shake() == Vector3.ZERO, "reduced motion: no camera jolt")
	game.reduced_motion = false


func _drift_tiers() -> void:
	var previous := 0
	for tier in range(4):
		_clean(20.0)
		game.drifting = true
		game.steering = 0.8
		game.drift_charge = 0.0 if tier == 0 else game.DRIFT_TIERS[tier - 1] + 0.05
		_check(fx._drift_tier(game.drift_charge) == tier, "drift charge maps to tier %d" % tier)
		_tick(30)
		var sparks_now: int = int(fx.counts.get("drift_sparks", 0))
		_check(sparks_now > 0, "drift tier %d sprays sparks" % tier)
		_check(int(fx.counts.get("drift_smoke", 0)) > 0, "drift tier %d smokes" % tier)
		_check(int(fx.counts.get("drift_marks", 0)) > 5, "drift tier %d leaves marks" % tier)
		_check(sparks_now > previous, "higher tier, more sparks (%d > %d)" % [sparks_now, previous])
		previous = sparks_now
	game.drifting = false


func _launch_and_landing() -> void:
	_clean(0.0)
	game.auto_gas = true
	for _i in range(40):
		game.speed = minf(12.0, game.speed + 0.25)
		_tick(1, game.speed * STEP)
	_check(int(fx.counts.get("launch_dust", 0)) > 0, "launch from standstill throws dust")
	_check(int(fx.counts.get("launch_debris", 0)) == 0, "asphalt launch makes tyre smoke, no pebbles")
	# On sand the same launch throws grains and pebbles.
	_clean(0.0)
	fx.style = STYLES.for_track("desert_drift")
	for _i in range(40):
		game.speed = minf(12.0, game.speed + 0.25)
		_tick(1, game.speed * STEP)
	_check(int(fx.counts.get("launch_debris", 0)) > 0, "sand launch throws pebbles")
	fx.style = STYLES.for_track("sonnenhafen")
	game.auto_gas = false
	_clean(18.0)
	_tick(3)
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	fx.landed(1.5, road.basis)
	_check(int(fx.counts.get("landing_dust", 0)) == 0, "a soft touch-down makes no ring")
	fx.landed(9.0, road.basis)
	_check(int(fx.counts.get("landing_dust", 0)) > 10, "hard landing raises a dust ring")
	_check(int(fx.counts.get("landing_sparks", 0)) > 0, "very hard landing sparks under the chassis")
	_check(int(fx.sounds.get("land_thump", 0)) == 1, "landing thump requested")
	# The real landing path also reaches the effects.
	_clean(18.0)
	_tick(3)
	road = game.world.sample_road(game.player.position, along)
	game.player.position.y = float(road.height) + 0.035
	game.airborne = true
	game.vertical_speed = -9.0
	game.air_time = 0.5
	game.precision_kicker = {}
	game._move_vertically(road, float(road.distance), STEP)
	_check(int(fx.counts.get("landing_dust", 0)) > 10, "race landing triggers the dust ring")


func _rivals() -> void:
	_clean(20.0)
	_tick(2)
	var rival = game.opponents[0]
	rival.global_position = game.player.global_position + game.player.global_basis.x * 3.0
	rival.driver_hit_pending = false
	fx.rail_contact(rival, game.player.global_basis.x, 6.0, 20.0)
	game._update_vehicles(STEP)
	_check(int(fx.counts.get("rail_sparks", 0)) > 0, "a rival at the rail sprays sparks too")
	_check(int(fx.counts.get("rail_burst", 0)) > 0, "a rival hard hit bursts")
	_check(rival.driver_hit_pending, "the rival driver flinches")
	_check(fx.shake == 0.0, "a rival's hit does not jolt the player camera")


func _extras() -> void:
	# Lift off the gas at speed: one overrun pop from the exhaust, then quiet.
	_clean(18.0)
	game.auto_gas = true
	_tick(3)
	game.auto_gas = false
	_tick(30)
	_check(int(fx.counts.get("backfire", 0)) == 1, "lifting off at speed pops once")
	_check(int(fx.sounds.get("backfire", 0)) == 1, "overrun pop sound once")
	# Slipstream charge from the race shows wind streaks; none without it.
	_clean(22.0)
	_tick(20)
	_check(int(fx.counts.get("slipstream", 0)) == 0, "no wind streaks without slipstream")
	game.slipstream_charge = 0.8
	_tick(20)
	_check(int(fx.counts.get("slipstream", 0)) > 0, "slipstream draws the sucking wind")
	game.slipstream_charge = 0.0
	# Taking the lead: confetti exactly once.
	_clean(22.0)
	var saved: Array = game.opponent_distances.duplicate()
	game.elapsed = 10.0
	for i in range(game.opponent_distances.size()):
		game.opponent_distances[i] = -1000.0
	game.opponent_distances[0] = game.distance + 50.0
	_tick(2)
	_check(int(fx.counts.get("confetti", 0)) == 0, "no confetti while second")
	game.opponent_distances[0] = -1000.0
	_tick(10)
	_check(int(fx.counts.get("confetti", 0)) > 10, "confetti when taking the lead")
	_check(int(fx.sounds.get("confetti", 0)) == 1, "one cheer sound")
	_tick(30)
	_check(int(fx.sounds.get("confetti", 0)) == 1, "staying first does not repeat it")
	for i in range(saved.size()):
		game.opponent_distances[i] = saved[i]


func _pause_freezes() -> void:
	_clean(22.0)
	game.boost_time = 2.0
	game.drifting = true
	game.steering = 0.8
	game.brake_visual_amount = 1.0
	_tick(10)
	var spawned: int = int(fx.visual_state().spawned)
	var clock: float = fx.sparks.fx_time
	var pitch: float = fx.pitch
	game.paused = true
	for _i in range(60):
		game._update_vehicles(STEP)
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	fx.landed(9.0, road.basis)
	fx.rail_contact(game.player, game.player.global_basis.x, 8.0, 20.0)
	game._update_vehicles(STEP)
	_check(int(fx.visual_state().spawned) == spawned, "paused: no new particles at all")
	_check(fx.sparks.fx_time == clock, "paused: the effect clock stands still")
	_check(fx.pitch == pitch, "paused: the body pose is frozen")
	game.paused = false


func _budgets() -> void:
	for profile in ["high", "medium", "low"]:
		game.graphics_profile = profile
		_clean(24.0)
		game._update_vehicles(STEP)
		var budget: Dictionary = DRIVE_FX.BUDGETS[profile]
		_check(fx.sparks.capacity == int(budget.sparks), "%s spark budget" % profile)
		_check(fx.puffs.capacity == int(budget.puffs), "%s soft budget" % profile)
		_check(fx.marks.capacity == int(budget.marks), "%s mark budget" % profile)
		# Worst case: everything at once for three seconds.
		game.boost_time = 5.0
		game.drifting = true
		game.steering = 0.9
		game.drift_charge = 3.0
		game.brake_visual_amount = 1.0
		for _i in range(180):
			fx.rail_contact(game.player, game.player.global_basis.x, 6.0, 24.0)
			fx.rail_contact(game.opponents[0], game.player.global_basis.x, 6.0, 24.0)
			_tick(1)
		var state: Dictionary = fx.visual_state()
		_check(state.sparks_live <= state.spark_capacity, "%s live sparks within budget" % profile)
		_check(state.soft_live <= state.soft_capacity, "%s live soft particles within budget" % profile)
		_check(state.marks_live <= state.mark_capacity, "%s marks within budget" % profile)
		_check(state.sparks_live > 40, "%s still clearly visible (%d sparks)" % [profile, state.sparks_live])
		print("[KartDriveFx] %s worst case: %d sparks, %d soft, %d marks, %d draw batches" % [
			profile, state.sparks_live, state.soft_live, state.marks_live, state.draw_batches
		])
		_check(state.draw_batches <= 4, "%s at most four effect draw batches" % profile)
	game.graphics_profile = "high"
	_clean()


func _surfaces() -> void:
	var expected := {
		"sonnenhafen": "asphalt", "desert_drift": "sand", "winter_sprint": "snow", "zauberwald": "forest",
		"volcano_night": "lava", "galaxy_ringway": "starglass", "bergwelt": "stone", "holo_city": "asphalt",
	}
	for track in expected:
		_check(STYLES.for_track(track).name == expected[track], "%s drives on %s" % [track, expected[track]])
	_check(STYLES.for_track("volcano_night").embers, "lava tyres throw embers")
	_check(STYLES.for_track("desert_drift").trail > 0.5, "sand leaves a dust plume")
	_check(STYLES.for_track("winter_sprint").loop == "snow", "snow crunches")
