extends SceneTree
## Reusable track pieces in a real race (Zauberwald): markers are planned into
## free road, the gap ramp flies with the precision model and lands in its
## zone, too slow falls into the real gap, the bottleneck has physical walls,
## lava slows without stopping, ice keeps the kart sliding. Ramp feet are
## flush with the road. Optional LUMO_CAPTURE_DIR saves real renderer frames.
const PIECES = preload("res://scripts/games/track_pieces/kart_track_pieces.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const RAMP = preload("res://scripts/games/track_pieces/kart_ramp_piece.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
const TRACK: String = "zauberwald"
var game
var failures: int = 0
var output: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[TrackPieces] FAIL: ", message)


func _settle() -> void:
	await process_frame
	await process_frame


func _start(markers: Array) -> void:
	game._start_selected_race(
		{"mode": "training", "driver": "fox", "kart": "comet", "track": TRACK, "difficulty": "flott"}
	)
	game._end_preview()
	await _settle()
	if not markers.is_empty():
		# Same path a track author uses: markers on the world, then its build.
		game.world.set_meta(PIECES.META_KEY, markers)
		game.world.build(game.lightweight, TRACK)
		await _settle()
	game.countdown = 0
	game.racing = true
	game.auto_gas = false
	game.gas_held = false


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
	for key in [&"track_piece_velocity", &"track_piece_entry_speed", &"track_piece_lava_limit"]:
		if game.has_meta(key):
			game.remove_meta(key)


func _capture(name: String, from: Vector3, at: Vector3) -> void:
	if output.is_empty():
		return
	game.safe_ui.visible = false
	game.camera.position = from
	game.camera.look_at(at, Vector3.UP)
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
	game.safe_ui.visible = true
	print("[TrackPieces] saved ", output.path_join(name + ".png"))


func _steer_to(lateral: float) -> void:
	var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, lateral)
	var direction: Vector3 = target - game.player.position
	game.steering = clampf(
		-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
	)


func _piece(type: String) -> Dictionary:
	for piece in PIECES.pieces_of(game.world):
		if piece.type == type:
			return piece
	return {}


func _ramp_foot_gap(start: float) -> float:
	var node: MeshInstance3D = game.world.get_node_or_null("TrackRamp_%d" % int(start))
	if node == null:
		return INF
	var worst: float = 0.0
	var basis: Basis = game.world.frame(start)
	for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var road: Dictionary = game.world.sample_road(vertex, start)
		if absf(float(road.distance) - start) < 0.05 and (vertex - game.world.position_at(start, float(road.lateral))).dot(basis.y) > -0.02:
			worst = maxf(worst, absf((vertex - game.world.position_at(start, float(road.lateral))).dot(basis.y) - RAMP.DECK_LIFT))
	return worst


func _plan_markers() -> Array:
	await _start([])
	var world = game.world
	var length: float = float(world.length)
	var markers: Array = []
	var avoid: Array = []
	var spans: Dictionary = {"gap_ramp": 48.0, "narrow": 26.0, "lava": 36.0, "ice": 36.0}
	var wish: float = length * 0.08
	for key in ["gap_ramp", "narrow", "lava", "ice"]:
		var at: float = PIECES.free_distance(world, wish, spans[key], avoid)
		_check(at >= 0.0, "free road for %s" % key)
		avoid.append(Vector2(at - PIECES.WARNING_LEAD_M - 20.0, at + spans[key] + 20.0))
		wish = at + spans[key] + 60.0
		if key in ["lava", "ice"]:
			markers.append({"type": "hazard_zone", "distance": at, "lane": 2.6, "params": {"kind": key}})
		else:
			markers.append({"type": key, "distance": at})
	return markers


func _check_gap_ramp() -> void:
	var piece: Dictionary = _piece("gap_ramp")
	_check(not piece.is_empty(), "gap ramp planned")
	if piece.is_empty():
		return
	var kicker: Dictionary = piece.kicker
	_check(game.world.action.kickers.has(kicker), "gap ramp is a real race kicker")
	_check(game.world.in_gap(float(kicker.take_off) + float(kicker.landing_min) * 0.5), "gap is open road")
	var foot: float = _ramp_foot_gap(float(kicker.start))
	var precision_deck: Node = game.world.find_child("PrecisionRampDeck", true, false)
	_check(precision_deck != null, "ramp deck built")
	var good: float = float(kicker.rival_speed)
	_place(float(kicker.take_off) - 1.0, 0.0, good)
	var landed: String = ""
	var launched: bool = false
	for frame in range(300):
		game._physics_process(STEP)
		launched = launched or game.airborne
		if launched and not game.airborne:
			landed = game.last_precision_landing
			break
	_check(launched and landed == PRECISION.LANDING_ZONE, "reference speed lands in the zone (%s)" % landed)
	var falls_before: int = game.gap_falls
	_place(float(kicker.take_off) - 1.0, 0.0, good * 0.6)
	var slow_result: String = ""
	var slow_launched: bool = false
	for frame in range(600):
		game._physics_process(STEP)
		slow_launched = slow_launched or game.airborne
		if slow_launched and slow_result.is_empty() and not game.last_precision_landing.is_empty():
			slow_result = game.last_precision_landing
		if game.gap_falls > falls_before:
			break
	print("[TrackPieces] slow launch %s, landing '%s', falls %d" % [slow_launched, game.last_precision_landing, game.gap_falls - falls_before])
	_check(game.gap_falls > falls_before, "too slow falls into the real gap and is rescued")
	print("[TrackPieces] gap ramp: reference %.1f m/s -> %s, slow -> fell %d" % [good, landed, game.gap_falls - falls_before])
	var side: Vector3 = game.world.position_at(float(kicker.take_off) + 3.0, -14.0) + Vector3.UP * 6.0
	await _capture("pieces_gap_ramp_side", side, game.world.position_at(float(kicker.take_off) + 4.0))
	await _capture(
		"pieces_gap_ramp_foot",
		game.world.position_at(float(kicker.start) - 6.0, -3.5) + Vector3.UP * 1.5,
		game.world.position_at(float(kicker.start) + 2.0)
	)
	if foot != INF:
		print("[TrackPieces] smooth kicker foot gap %.4f m" % foot)


func _check_narrow() -> void:
	var piece: Dictionary = _piece("narrow")
	_check(not piece.is_empty(), "bottleneck planned")
	if piece.is_empty():
		return
	var middle: float = float(piece.start) + float(piece.params.length) * 0.5
	var wall: float = game.world.wall_lateral_at(middle)
	_check(is_equal_approx(wall, float(piece.params.open_width) * 0.5), "walls narrow to the open width (%.2f)" % wall)
	_check(is_equal_approx(game.world.wall_lateral_at(float(piece.start) - 5.0), float(game.world.WALL_LATERAL)), "full width before")
	_place(float(piece.start) - 25.0, 4.4, 18.0)
	var widest: float = 0.0
	var resets: int = game.reset_count
	game.gas_held = true
	for frame in range(240):
		game.steering = 0.0
		game._physics_process(STEP)
		var at: float = fposmod(game.previous_road_distance, game.track_length)
		if at > float(piece.start) + float(piece.params.taper) and at < float(piece.end) - float(piece.params.taper):
			widest = maxf(widest, absf(game.lane))
		if at > float(piece.end) + 2.0:
			break
	game.gas_held = false
	_check(widest <= float(piece.params.open_width) * 0.5 + 0.05, "kart stays inside the bottleneck (%.2f m)" % widest)
	_check(game.reset_count == resets, "bottleneck needs no rescue")
	print("[TrackPieces] narrow: open %.1f m, widest lane inside %.2f m" % [float(piece.params.open_width), widest])
	await _capture(
		"pieces_narrow",
		game.world.position_at(float(piece.start) - 22.0, 0.0) + Vector3.UP * 3.0,
		game.world.position_at(float(piece.start) + 8.0) + Vector3.UP * 0.6
	)


func _zone(kind: String) -> Dictionary:
	for piece in PIECES.pieces_of(game.world):
		if piece.type == "hazard_zone" and str(piece.params.kind) == kind:
			return piece
	return {}


func _check_lava() -> void:
	var piece: Dictionary = _zone("lava")
	_check(not piece.is_empty(), "lava zone planned")
	if piece.is_empty():
		return
	_check(PIECES.zone_at(game.world, float(piece.start) + 5.0, -2.6).is_empty(), "safe lane beside the lava")
	_place(float(piece.start) - 6.0, float(piece.lane), 20.0)
	game.gas_held = true
	var slowest: float = INF
	var entry_speed: float = -1.0
	for frame in range(200):
		_steer_to(float(piece.lane))
		game._physics_process(STEP)
		var at: float = fposmod(game.previous_road_distance, game.track_length)
		if at >= float(piece.start) and entry_speed < 0.0:
			entry_speed = game.speed
		if at > float(piece.start) and at < float(piece.end):
			slowest = minf(slowest, game.speed)
		if at > float(piece.end):
			break
	game.gas_held = false
	_check(entry_speed > 0.0 and slowest < entry_speed * 0.8, "lava slows the kart (%.1f -> %.1f m/s)" % [entry_speed, slowest])
	_check(slowest >= entry_speed * PIECES.LAVA_SPEED_SHARE - 0.6, "lava never stops the kart (%.1f m/s)" % slowest)
	print("[TrackPieces] lava: entry %.1f m/s -> slowest %.1f m/s" % [entry_speed, slowest])
	await _capture(
		"pieces_lava",
		game.world.position_at(float(piece.start) - 14.0, -1.0) + Vector3.UP * 3.0,
		game.world.position_at(float(piece.start) + 10.0, float(piece.lane))
	)


func _check_ice() -> void:
	var piece: Dictionary = _zone("ice")
	_check(not piece.is_empty(), "ice zone planned")
	if piece.is_empty():
		return
	var turns: Dictionary = {}
	for on_ice in [false, true]:
		var lateral: float = float(piece.lane) if on_ice else -2.6
		_place(float(piece.start) + 4.0, lateral, 18.0)
		var heading_before: Vector3 = game.physical_velocity.normalized()
		for frame in range(30):
			game.steering = 1.0
			game._physics_process(STEP)
		turns[on_ice] = rad_to_deg(heading_before.angle_to(game.physical_velocity.normalized()))
	_check(turns[true] < turns[false] * 0.8, "ice keeps the kart sliding (%.1f vs %.1f deg)" % [turns[true], turns[false]])
	print("[TrackPieces] ice: velocity turned %.1f deg on ice vs %.1f deg on asphalt" % [turns[true], turns[false]])
	await _capture(
		"pieces_ice",
		game.world.position_at(float(piece.start) - 14.0, -1.0) + Vector3.UP * 3.0,
		game.world.position_at(float(piece.start) + 10.0, float(piece.lane))
	)


func _check_kicker_foot() -> void:
	for kicker in game.world.action.kickers:
		if bool(kicker.get("precision_jump", false)):
			continue
		var gap: float = _ramp_foot_gap(float(kicker.start))
		_check(gap <= 0.003, "smooth kicker foot flush with the road (%.4f m)" % gap)
		print("[TrackPieces] action kicker at %.0f m: foot gap %.4f m" % [float(kicker.start), gap])


func _run() -> void:
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	var markers: Array = await _plan_markers()
	await _start(markers)
	_check(PIECES.pieces_of(game.world).size() == markers.size(), "all %d markers planned" % markers.size())
	_check_kicker_foot()
	await _check_gap_ramp()
	await _check_narrow()
	await _check_lava()
	await _check_ice()
	game.abandoned = true
	_check(await TEARDOWN.release_scene(self, game, "[TrackPieces]"), "scene released")
	if failures > 0:
		printerr("[TrackPieces] %d failures" % failures)
		quit(1)
		return
	print("[TrackPieces] PASS: gap ramp, bottleneck, lava and ice behave and join the road")
	quit(0)
