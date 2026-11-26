extends SceneTree
## Fahrgefühl 2.0 inside the production race scene (scripts/games/kart_fx/):
##   four quality tiers (Leicht, Ausgewogen, Hoch, Sehr hoch) with live and
##   per-tick particle budgets that hold under a worst case;
##   ground under the tyres: kerb rumble (camera tremor, sound), puddle splash
##   with a wet tyre track afterwards, clods on the verge;
##   camera body language: surge on throttle and brake, a soft spring landing
##   (one rebound at most), lift in the air, zero with reduced motion;
##   kart-to-kart contact: velocity push without a jump, sparks only when
##   rubbing at speed, a bump sound; wind quieter in a slipstream;
##   the motor shifts through its gears under full throttle.
## godot --headless --path . --script res://scripts/tests/kart_fahrgefuehl_regression.gd

const DRIVE_FX = preload("res://scripts/games/kart_fx/kart_drive_fx.gd")
const GROUND = preload("res://scripts/games/kart_fx/kart_fx_ground.gd")
const MOTOR = preload("res://scripts/games/kart_fx/kart_motor_voice.gd")
const RACECRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
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
		push_warning("[KartFahrgefuehl] FAIL " + label)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "fahrgefuehl-regression"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.graphics_profile = "high"
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
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.reduced_motion = false
	game.auto_gas = false
	fx = game.drive_fx
	# The detail layer lays its puddles one frame after the world is built.
	await process_frame
	await process_frame
	_check(is_instance_valid(fx), "race builds the driving-effects node")
	_puddles_from_detail_layer()
	_tiers()
	_curb()
	_puddle()
	_verge()
	_camera_surge()
	_camera_landing()
	_camera_air_and_reduced_motion()
	_kart_contact()
	_wind()
	_motor_gears()
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print(
			(
				"[KartFahrgefuehl] PASS %d checks: tiers, kerb, puddle, verge, camera, contact, wind, gears"
				% checks
			)
		)
		quit(0)
	else:
		print("[KartFahrgefuehl] FAIL ", failures)
		quit(1)


func _place(distance: float, lane: float = 0.0) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	var placed: Transform3D = game.world.reset_transform(distance, 0.0)
	placed.origin += placed.basis.x.normalized() * lane
	game.player.transform = placed
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)


func _tick(count: int, advance_metres: float = 0.3) -> void:
	for _i in range(count):
		along += advance_metres
		_place(along, game.lane)
		game._update_vehicles(STEP)


func _clean(speed: float = 18.0, start: float = -1.0) -> void:
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
	game.slipstream_charge = 0.0
	fx._previous_speed = speed
	fx._accel = 0.0
	fx._previous_gas = false
	along = game.track_length * 0.1 if start < 0.0 else start


## Distance of a gentle, kerbed section on both sides, away from stunts.
func _quiet_kerb_section() -> float:
	var best: float = game.track_length * 0.1
	var at: float = game.track_length * 0.05
	while at < game.track_length * 0.9:
		var ok: bool = true
		for offset in range(0, 60, 4):
			var d: float = at + float(offset)
			if not GROUND.has_curb(game.world, d, 1.0) or not GROUND.has_curb(game.world, d, -1.0):
				ok = false
				break
			if game.world.ramp_height(d) > 0.0 or game.world.dive_factor(d) < 1.0:
				ok = false
				break
		if ok:
			return at
		at += 10.0
	return best


func _tiers() -> void:
	var perf: Node = root.get_node("PerformanceManager")
	var tiers := {"low": "Leicht", "medium": "Ausgewogen", "high": "Hoch", "ultra": "Sehr hoch"}
	var previous_capacity: int = 0
	for tier in ["low", "medium", "high", "ultra"]:
		game.graphics_profile = "high" if tier == "ultra" else tier
		perf.set_ultra(tier == "ultra")
		_clean(24.0)
		game._update_vehicles(STEP)
		var budget: Dictionary = DRIVE_FX.BUDGETS[tier]
		_check(fx.profile == tier, "%s: effects follow the tier (got %s)" % [tier, fx.profile])
		_check(fx.profile_name() == tiers[tier], "%s is called %s" % [tier, tiers[tier]])
		_check(fx.sparks.capacity == int(budget.sparks), "%s spark capacity" % tier)
		_check(fx.sparks.tick_cap == int(budget.tick_sparks), "%s spark tick cap" % tier)
		_check(fx.puffs.tick_cap == int(budget.tick_puffs), "%s soft tick cap" % tier)
		_check(fx.sparks.capacity > previous_capacity, "%s allows more than the tier below" % tier)
		previous_capacity = fx.sparks.capacity
		fx.sparks.tick_peak = 0
		fx.puffs.tick_peak = 0
		# Worst case: turbo, drift, full brake, rail scrape, a puddle and a landing at once.
		GROUND.clear_wet_spots(game.world)
		GROUND.add_wet_spot(game.world, along + 6.0, 0.0, 60.0, 9.0)
		game.boost_time = 5.0
		game.drifting = true
		game.steering = 0.9
		game.drift_charge = 3.0
		game.brake_visual_amount = 1.0
		for frame in range(150):
			fx.rail_contact(game.player, game.player.global_basis.x, 9.0, 24.0)
			fx.rail_contact(game.opponents[0], game.player.global_basis.x, 9.0, 24.0)
			if frame % 20 == 0:
				fx.landed(11.0, game.player.global_basis)
				fx.kart_contact(game.player, game.opponents[1], game.player.global_basis.x, 14.0)
			_tick(1)
		var state: Dictionary = fx.visual_state()
		_check(state.sparks_live <= state.spark_capacity, "%s live sparks within capacity" % tier)
		_check(
			state.soft_live <= state.soft_capacity, "%s live soft particles within capacity" % tier
		)
		_check(state.marks_live <= state.mark_capacity, "%s marks within capacity" % tier)
		_check(
			int(state.tick_sparks_peak) <= int(budget.tick_sparks),
			"%s sparks born per tick within cap" % tier
		)
		_check(
			int(state.tick_soft_peak) <= int(budget.tick_puffs),
			"%s soft births per tick within cap" % tier
		)
		_check(state.draw_batches <= 5, "%s at most five effect draw batches" % tier)
		_check(state.lights <= (2 if bool(budget.lights) else 0), "%s light budget" % tier)
		print(
			(
				(
					"[KartFahrgefuehl] %s (%s) worst case: %d/%d sparks, %d/%d soft, %d/%d marks,"
					+ " peak births/tick %d+%d (caps %d+%d), dropped %d"
				)
				% [
					tier,
					state.profile_name,
					state.sparks_live,
					state.spark_capacity,
					state.soft_live,
					state.soft_capacity,
					state.marks_live,
					state.mark_capacity,
					state.tick_sparks_peak,
					state.tick_soft_peak,
					state.tick_spark_cap,
					state.tick_soft_cap,
					state.dropped
				]
			)
		)
	perf.set_ultra(false)
	game.graphics_profile = "high"
	GROUND.clear_wet_spots(game.world)
	_clean()


func _puddles_from_detail_layer() -> void:
	var spots: Array = (
		game.world.get_meta(GROUND.WET_META) if game.world.has_meta(GROUND.WET_META) else []
	)
	var theme: Dictionary = preload("res://scripts/games/visual/kart_detail_themes.gd").theme(
		"sonnenhafen"
	)
	var has_puddles: bool = "puddle" in theme.get("road_wear", [])
	print(
		(
			"[KartFahrgefuehl] detail layer puddles on Sonnenhafen: %d (theme lists puddles: %s)"
			% [spots.size(), has_puddles]
		)
	)
	if has_puddles:
		_check(spots.size() > 0, "the detail layer reports its puddles to the driving effects")
	for spot in spots:
		var s: Vector4 = spot
		_check(s.z > 0.3 and s.z < 2.5, "puddle radius is plausible (%.2f m)" % s.z)
		break


func _curb() -> void:
	var start: float = _quiet_kerb_section()
	_clean(18.0, start)
	game.lane = 4.75
	var low: float = INF
	var high: float = -INF
	for _i in range(40):
		_tick(1)
		var offset: Vector3 = fx.camera_body_offset()
		low = minf(low, offset.y)
		high = maxf(high, offset.y)
	var state: Dictionary = fx.visual_state()
	_check(state.ground == "curb", "outer tyres on the kerb are detected (got %s)" % state.ground)
	_check(float(state.rumble) > 0.3, "kerb rumble builds up (%.2f)" % state.rumble)
	_check(int(state.counts.get("curb_ticks", 0)) > 20, "kerb contact counted every tick")
	_check(high - low > 0.008, "the camera trembles over the kerb ridges (%.4f m)" % (high - low))
	_check(game.kart_audio._loop_fed.has("curb"), "the kerb rumble loop is driven")
	print(
		(
			"[KartFahrgefuehl] kerb at %.0f m: rumble %.2f, camera tremor %.4f m"
			% [start, state.rumble, high - low]
		)
	)
	game.lane = 0.0
	_tick(40)
	_check(float(fx.visual_state().rumble) < 0.05, "rumble fades on the asphalt")
	_check(
		GROUND.sample(game.world, along, 0.0, false).kind == "road",
		"the middle of the road is plain road"
	)
	_check(GROUND.sample(game.world, along, 4.75, true).kind == "road", "no kerb rumble in the air")


func _puddle() -> void:
	_clean(15.0, _quiet_kerb_section())
	GROUND.clear_wet_spots(game.world)
	GROUND.add_wet_spot(game.world, along + 6.0, 0.0, 3.5, 3.0)
	_tick(40)
	var state: Dictionary = fx.visual_state()
	_check(int(state.counts.get("splash", 0)) == 1, "one splash when the tyres hit the puddle")
	_check(int(state.counts.get("splash_drops", 0)) >= 10, "the splash throws a fan of drops")
	_check(int(state.counts.get("water_spray", 0)) > 0, "tyres spray water while in the puddle")
	_check(int(state.sounds.get("splash", 0)) == 1, "a splash sound is requested")
	_check(int(state.counts.get("wet_marks", 0)) > 3, "wet tyres print a track after the puddle")
	print(
		(
			"[KartFahrgefuehl] puddle: %d drops, %d spray, %d wet marks"
			% [
				state.counts.get("splash_drops", 0),
				state.counts.get("water_spray", 0),
				state.counts.get("wet_marks", 0)
			]
		)
	)
	_tick(150)
	var later: Dictionary = fx.visual_state()
	_check(float(later.wet_time) == 0.0, "the tyres dry again")
	var before: int = int(later.counts.get("wet_marks", 0))
	_tick(30)
	_check(int(fx.visual_state().counts.get("wet_marks", 0)) == before, "no wet track once dry")
	GROUND.clear_wet_spots(game.world)


func _verge() -> void:
	_clean(14.0, _quiet_kerb_section())
	game.lane = game._road_width_at(along) * 0.5 + 0.4
	_tick(30)
	var state: Dictionary = fx.visual_state()
	_check(state.ground == "verge", "beyond the asphalt is the verge (got %s)" % state.ground)
	_check(int(state.counts.get("verge_clods", 0)) > 5, "the verge throws clods and grass")
	_check(int(state.counts.get("verge_dust", 0)) > 0, "the verge raises dust")
	_check(game.kart_audio._loop_fed.has("gravel"), "rolling noise changes on the verge")
	game.lane = 0.0


func _camera_surge() -> void:
	_clean(4.0)
	for _i in range(40):
		game.speed = minf(46.0, game.speed + 40.0 * STEP)
		_tick(1)
	var pulling: Vector3 = fx.camera_body_offset()
	_check(pulling.z > 0.15, "the camera sinks back while the kart pulls (%.3f m)" % pulling.z)
	_check(
		fx.camera_rig.fov > 1.0,
		"the view widens a little under hard acceleration (%.2f deg)" % fx.camera_rig.fov
	)
	_check(fx.camera_fov_kick() >= fx.camera_rig.fov, "the FOV kick reaches the race camera")
	for _i in range(30):
		game.speed = maxf(0.0, game.speed - 60.0 * STEP)
		game.brake_visual_amount = 1.0
		_tick(1)
	var braking: Vector3 = fx.camera_body_offset()
	_check(braking.z < -0.08, "the camera leans in on braking (%.3f m)" % braking.z)
	print(
		(
			"[KartFahrgefuehl] camera surge: +%.3f m pulling, %.3f m braking, FOV +%.2f"
			% [pulling.z, braking.z, fx.camera_rig.fov]
		)
	)


func _camera_landing() -> void:
	_clean(20.0)
	_tick(10)
	fx.landed(9.0, game.player.global_basis)
	var lowest: float = 0.0
	var crossings: int = 0
	var previous: float = 0.0
	var settled_after: float = -1.0
	for frame in range(120):
		_tick(1)
		var heave: float = fx.camera_body_offset().y
		lowest = minf(lowest, heave)
		if frame > 0 and signf(heave) != signf(previous) and absf(heave) > 0.004:
			crossings += 1
		if settled_after < 0.0 and frame > 10 and absf(heave) < 0.01:
			settled_after = float(frame) * STEP
		previous = heave
	_check(lowest < -0.08, "a hard landing dips the camera (%.3f m)" % lowest)
	_check(lowest > -DRIVE_FX.CAMERA_RIG.HEAVE_DOWN - 0.001, "the dip stays bounded")
	_check(crossings <= 2, "soft landing: at most one rebound (%d sign changes)" % crossings)
	_check(
		settled_after > 0.0 and settled_after < 1.2,
		"the camera settles within 1.2 s (%.2f s)" % settled_after
	)
	_check(fx.shake < 0.06, "a landing does not shake the picture hard (%.3f)" % fx.shake)
	print(
		(
			"[KartFahrgefuehl] landing: dip %.3f m, %d sign changes, settled after %.2f s"
			% [lowest, crossings, settled_after]
		)
	)


func _camera_air_and_reduced_motion() -> void:
	_clean(20.0)
	game.airborne = true
	_tick(30)
	_check(fx.camera_body_offset().y > 0.06, "the camera lifts a little while flying")
	game.airborne = false
	_clean(4.0)
	game.reduced_motion = true
	for _i in range(30):
		game.speed = minf(46.0, game.speed + 40.0 * STEP)
		_tick(1)
	fx.landed(9.0, game.player.global_basis)
	_tick(5)
	_check(fx.camera_body_offset() == Vector3.ZERO, "reduced motion: no camera body motion")
	_check(fx.camera_fov_kick() == 0.0, "reduced motion: no FOV kick")
	game.reduced_motion = false


func _kart_contact() -> void:
	_clean(18.0)
	_tick(3)
	var rival = game.opponents[0]
	fx.kart_contact(game.player, rival, game.player.global_basis.x, 12.0)
	_check(int(fx.counts.get("contact_sparks", 0)) > 10, "karts rubbing at speed throw sparks")
	_check(int(fx.sounds.get("bump", 0)) == 1, "a contact makes a bump sound")
	var sparks_before: int = int(fx.counts.get("contact_sparks", 0))
	fx.kart_contact(game.player, rival, game.player.global_basis.x, 1.0)
	_check(
		int(fx.counts.get("contact_sparks", 0)) == sparks_before, "a gentle touch makes no sparks"
	)
	_check(int(fx.sounds.get("bump", 0)) == 2, "a gentle touch still bumps")
	# The race's own contact rule: velocity push, no positional jump.
	game.hit_timer = 0.0
	game.shield_time = 0.0
	game.rival_contact_timer = 0.0
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	game.physical_velocity = -(road.basis as Basis).z * 18.0
	rival.position = game.player.position + (road.basis as Basis).x * 1.0
	var before_position: Vector3 = game.player.position
	var before_velocity: Vector3 = game.physical_velocity
	var contacts: int = int(fx.counts.get("kart_contact", 0))
	game._track_events()
	_check(game.player.position == before_position, "contact does not teleport the child's kart")
	var change: Vector3 = game.physical_velocity - before_velocity
	_check(
		change.length() > 2.0 and change.dot((road.basis as Basis).x) < 0.0,
		"contact pushes the kart away through its velocity"
	)
	_check(rival.has_meta(&"contact_push"), "the rival is pushed the other way")
	_check(
		int(fx.counts.get("kart_contact", 0)) == contacts + 1,
		"the race reports the contact to the effects"
	)
	_check(game.hit_timer > 0.0, "the existing hit rule still applies")
	var start: Vector3 = rival.position
	var craft: GDScript = RACECRAFT
	var moved: float = 0.0
	for _i in range(40):
		var p0: Vector3 = rival.position
		craft.apply_contact_push(rival, STEP)
		moved = maxf(moved, p0.distance_to(rival.position))
	_check(moved < 0.1, "the rival's push is spread over frames (max %.3f m/frame)" % moved)
	_check(
		rival.position.distance_to(start) > 0.1 and not rival.has_meta(&"contact_push"),
		"the rival's push fades out"
	)


func _wind() -> void:
	_clean(40.0)
	var calm: float = fx.wind_gain(1.0, true, false)
	game.slipstream_charge = 1.0
	var towed: float = fx.wind_gain(1.0, true, false)
	game.slipstream_charge = 0.0
	var flying: float = fx.wind_gain(1.0, false, false)
	var turbo: float = fx.wind_gain(1.0, true, true)
	_check(towed < calm * 0.7, "wind is quieter in a slipstream (%.2f vs %.2f)" % [towed, calm])
	_check(flying > calm and turbo > calm, "wind grows in the air and on a turbo")
	_check(fx.wind_gain(0.3, true, false) < calm * 0.2, "wind grows with the square of the speed")


func _motor_gears() -> void:
	var holder := Node.new()
	root.add_child(holder)
	for style in ["comet", "zuri_volt"]:
		var voice = MOTOR.new(holder, false)
		voice.configure(style, {})
		var speed: float = 0.0
		var drops: int = 0
		var previous: float = 0.0
		var first: float = -1.0
		for _i in range(150):
			speed = minf(48.0, speed + 40.0 * STEP)
			voice.advance(STEP, speed, 1.0, 0.0, false, false, -60.0)
			if first < 0.0:
				first = voice.rpm
			if voice.rpm < previous - 0.004:
				drops += 1
			previous = voice.rpm
		voice.stop()
		if style == "comet":
			_check(
				voice.shifts == MOTOR.SHIFT_POINTS.size(),
				"full throttle runs through all gears (%d shifts)" % voice.shifts
			)
			_check(drops >= 2, "the motor note falls at the shifts (%d drops)" % drops)
			_check(voice.rpm > first + 0.5, "the motor still climbs with speed overall")
		else:
			_check(voice.shifts == 0, "an electric kart has one long gear")
		print(
			(
				"[KartFahrgefuehl] %s: %d shifts, %d falling ticks, rpm %.2f -> %.2f"
				% [style, voice.shifts, drops, first, voice.rpm]
			)
		)
	holder.queue_free()
