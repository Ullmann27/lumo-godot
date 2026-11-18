extends SceneTree
## Bildfolge „anhalten – hindurchfahren – weiterfahren“ an einer LUMO-Passage aus der
## echten Fahrerkamera. Das Kart fährt mit den Touch-Eingaben (Lenkstick-Achse, Bremsfeld,
## Auto-Gas) durch die echte Rennphysik; nichts wird teleportiert außer dem Startpunkt.
## Aufruf (mit Bild): -- <track_id> <passage_id> <out_dir> [width height] [difficulty]
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
var game
var output: String = ""
var frames: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame


func _shot(name: String) -> void:
	game._update_camera(STEP)
	for _i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	frames.append(path)
	print(
		"[PassageCapture] saved ",
		path,
		(
			" d=%.1f lane=%.2f speed=%.1f"
			% [fposmod(game.previous_road_distance, game.track_length), game.lane, game.speed]
		)
	)


func _steer_to(lateral: float) -> void:
	var target: Vector3 = game.world.position_at(game.previous_road_distance + 7.0, lateral)
	var direction: Vector3 = target - game.player.position
	game.steering = clampf(
		-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.2, -1, 1
	)


func _drive(seconds: float, target_lane: float, braking: float) -> void:
	for _i in range(roundi(seconds / STEP)):
		_steer_to(target_lane)
		game.brake = braking
		game._physics_process(STEP)


## Flowing passages (S-curve, view): a clean ride at race pace with four frames.
func _ride_through(entry: Dictionary) -> void:
	var start: float = float(entry.zone_start) - 110.0
	game.distance = start
	game.previous_road_distance = start
	game.checkpoint_index = int(start / (game.track_length / 8.0))
	game.player.transform = game.world.reset_transform(start, 0.0)
	game.player_heading = game._heading(start)
	game.speed = 30.0
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
	)
	game._update_camera(STEP, true)
	var marks: Array = [
		float(entry.zone_start) - 90.0,
		float(entry.zone_start),
		lerpf(float(entry.zone_start), float(entry.zone_end), 0.5),
		float(entry.zone_end)
	]
	var names: Array = ["01_3s_davor", "02_eingang", "03_mitte", "04_ausgang"]
	for k in range(marks.size()):
		while fposmod(game.previous_road_distance, game.track_length) < float(marks[k]):
			_steer_to(_racing_line(entry))
			game.brake = 0.0
			game._physics_process(STEP)
		await _shot(str(names[k]))
	print(
		(
			"[PassageCapture] ride resets=%d speed=%.1f lane=%.2f"
			% [game.reset_count, game.speed, game.lane]
		)
	)


func _racing_line(entry: Dictionary) -> float:
	if not entry.has("apexes"):
		return 0.0
	var d: float = fposmod(game.previous_road_distance, game.track_length) + 12.0
	var lane_target: float = 0.0
	for apex in entry.apexes:
		var away: float = absf(d - float(apex[0]))
		if away < 40.0:
			lane_target = float(apex[1]) * 4.5 * (1.0 - away / 40.0)
	return lane_target


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var track: String = args[0] if args.size() > 0 else "winter_sprint"
	var passage_id: String = args[1] if args.size() > 1 else "eisbruecke"
	output = args[2] if args.size() > 2 else "user://passage_capture"
	var width: int = int(args[3]) if args.size() > 3 else 1600
	var height: int = int(args[4]) if args.size() > 4 else 720
	var difficulty: String = args[5] if args.size() > 5 else "gemuetlich"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(width, height)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": difficulty}
	)
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true
	var entry: Dictionary = {}
	for candidate in PASSAGES.of(game.world):
		if str(candidate.id) == passage_id:
			entry = candidate
	assert(not entry.is_empty(), "passage %s exists" % passage_id)
	# Rivals stay behind the start line so the frames show the child's own passage.
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = -400.0
		game.opponents[i].visible = false
	if str(entry.kind) in ["flow", "view"]:
		await _ride_through(entry)
		game.abandoned = true
		await TEARDOWN.release_scene(self, game, "[PassageCapture]")
		print("[PassageCapture] DONE ", frames.size(), " frames")
		quit(0)
		return
	var bridge: bool = str(entry.kind) == "bridge"
	# Gates: the child takes the short inner line and waits there (the outer lane stays open).
	var line: float = 0.0
	if str(entry.kind) == "gate":
		line = (float(entry.lat_min) + float(entry.lat_max)) * 0.5
	# Gates: stop a few metres earlier so the gated band is visible above the kart.
	var stop_at: float = (
		(float(entry.deck_start) - 7.0)
		if bridge
		else (float(entry.wait_line) - (7.0 if str(entry.kind) == "gate" else 2.5))
	)
	# 90 m run-up: long enough for the readability frame, short of Sonnenhafen's kicker landing.
	var start: float = maxf(2.0, stop_at - 90.0)
	game.distance = start
	game.previous_road_distance = start
	game.checkpoint_index = int(start / (game.track_length / 8.0))
	game.player.transform = game.world.reset_transform(start, 1.5)
	game.player_heading = game._heading(start)
	game.speed = 26.0
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
	)
	game._update_camera(STEP, true)
	# 1: three seconds before the passage at cruising speed (readability frame).
	while (
		fposmod(game.previous_road_distance, game.track_length) < maxf(start + 4.0, stop_at - 75.0)
	):
		_drive(STEP, 1.5, 0.0)
	await _shot("01_anfahrt_3s_davor")
	# 2: braking on the level plaza.
	while fposmod(game.previous_road_distance, game.track_length) < stop_at - 30.0:
		_drive(STEP, lerpf(0.6, line, 0.5), 0.0)
	while game.speed > 0.3:
		var left: float = stop_at - fposmod(game.previous_road_distance, game.track_length)
		_drive(STEP, line, 1.0 if left < game.speed * game.speed / 70.0 + 3.0 else 0.0)
	await _shot("02_bremsen")
	# 3: standing still, aligned (waiting for green at the swing).
	_drive(0.6, line, 1.0)
	if not bridge:
		var waited: float = 0.0
		while waited < 12.0:
			var state: Dictionary = PASSAGES.swing_state(entry, game.elapsed)
			if str(state.phase) == "swing" and float(state.progress) >= 0.42:
				break
			_drive(STEP, line, 1.0)
			waited += STEP
	await _shot("03_stillstand_ausgerichtet")
	if not bridge:
		while str(PASSAGES.swing_state(entry, game.elapsed).phase) == "swing":
			_drive(STEP, line, 1.0)
		await _shot("04_gruen_anfahren")
	else:
		# 4: rolling slowly onto the deck: brake feathered (touch brake pulses).
		var t: float = 0.0
		while (
			fposmod(game.previous_road_distance, game.track_length) < float(entry.deck_start) + 3.0
			and t < 8.0
		):
			_drive(STEP, line, 0.0)
			t += STEP
		await _shot("04_auf_die_bruecke")
	var middle: float = (
		(float(entry.deck_start) + float(entry.deck_end)) * 0.5 if bridge else float(entry.plane)
	)
	var t2: float = 0.0
	while fposmod(game.previous_road_distance, game.track_length) < middle and t2 < 10.0:
		_drive(STEP, line, 0.0)
		t2 += STEP
	await _shot("05_mitten_hindurch")
	var past: float = (
		(float(entry.deck_end) if bridge else float(entry.plane) + float(entry.band)) + 4.0
	)
	while fposmod(game.previous_road_distance, game.track_length) < past:
		_drive(STEP, line, 0.0)
	await _shot("06_geschafft")
	_drive(1.6, line * 0.5, 0.0)
	await _shot("07_beschleunigen")
	_drive(2.0, 0.0, 0.0)
	await _shot("08_wieder_im_rennen")
	print(
		(
			"[PassageCapture] resets=%d falls=%d hits=%d speed=%.1f"
			% [game.reset_count, game.passage_falls, game.passage_hits, game.speed]
		)
	)
	game.abandoned = true
	await TEARDOWN.release_scene(self, game, "[PassageCapture]")
	print("[PassageCapture] DONE ", frames.size(), " frames")
	quit(0)
