extends SceneTree
## Bildfolge „LUMO Sternenkompass“ aus dem echten Rennen (Fahrerkamera, echte Physik):
## Prisma von weitem, Prisma nah, Einsammeln mit Energiebahn und Splittern, Kompass in drei
## Phasen (schnell, abbremsend, einrastend), Ergebnis. Kein Prüftest – schreibt PNGs.
## Aufruf (xvfb, gl_compatibility): LUMO_COMPASS_DIR=/abs/dir godot --path . \
##   --rendering-method gl_compatibility --script res://scripts/tests/kart_star_compass_capture.gd \
##   -- 2176x1812 [track] [low|medium|high]   (Kart läuft quer: Fold offen 2176×1812,
##   schmales Handy 2340×1080)
const COMPASS = preload("res://scripts/games/kart_items/kart_star_compass.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")

var game
var destination := ""
var label := ""
var saved := 0
var zone_distance := 0.0
var zone_lane := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _steer() -> void:
	var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, zone_lane)
	var direction: Vector3 = target - game.player.position
	game.steering = clampf(
		-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
	)


func _frame() -> void:
	_steer()
	await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := destination.path_join("%s_%s.png" % [label, name])
	if root.get_texture().get_image().save_png(file) == OK:
		saved += 1
		var phase: String = COMPASS.phase_of(game.item_hud.state.get("compass", {}))
		var compass: Dictionary = game.item_hud.state.get("compass", {})
		print("[KartCompassCapture]   compass keys=%s" % [compass.keys()])
		print(
			(
				"[KartCompassCapture] %s phase=%s item=%s left=%.2f"
				% [file, phase, game.item, game.item_roulette_time]
			)
		)


func _ahead() -> float:
	return fposmod(zone_distance - fposmod(game.distance, game.track_length), game.track_length)


func _run() -> void:
	destination = OS.get_environment("LUMO_COMPASS_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartCompassCapture] Needs LUMO_COMPASS_DIR and a rendering window")
		quit(1)
		return
	var window_size := Vector2i(2176, 1812)
	var track := "sonnenhafen"
	var profile := "medium"
	for argument in OS.get_cmdline_user_args():
		if (
			"x" in argument
			and argument.split("x").size() == 2
			and argument.split("x")[0].is_valid_int()
		):
			window_size = Vector2i(int(argument.split("x")[0]), int(argument.split("x")[1]))
		elif argument in ["low", "medium", "high"]:
			profile = argument
		else:
			track = argument
	label = "%s_%dx%d" % [track, window_size.x, window_size.y]
	DirAccess.make_dir_recursive_absolute(destination)
	DisplayServer.window_set_size(window_size)
	root.size = window_size
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = false
	game.graphics_profile = profile
	game.race_seed = 20261119
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "gemuetlich"
		}
	)
	game._end_preview()
	# Das Rennen stellt sein Fenster quer ein; danach die Zielgröße setzen.
	DisplayServer.window_set_size(window_size)
	root.size = window_size
	game._apply_safe_area(Rect2(), Vector2(root.size))
	for _k in range(4):
		await process_frame
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	# Zweite Sammelzone der Runde, mittleres Prisma; Start 150 m davor in voller Fahrt.
	var index := -1
	var seen := 0
	var last := -1000.0
	for i in range(game.catalog_boxes.size()):
		var d: float = game.catalog_box_distances[i]
		if absf(d - last) > 1.0:
			seen += 1
			last = d
		if seen == 2 and is_zero_approx(game.catalog_box_laterals[i]):
			index = i
			break
	zone_distance = game.catalog_box_distances[index]
	var start: float = zone_distance - 150.0
	game.distance = start
	game.previous_road_distance = start
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(start, 0.0)
	game.player_heading = game._heading(start)
	game.speed = 26.0
	game.physical_velocity = game.world.forward(start) * game.speed
	for i in range(game.opponents.size()):
		var d: float = start - 40.0 - float(i) * 6.0
		game.opponent_distances[i] = d
		game.opponents[i].transform = game.world.reset_transform(d, game.opponent_lanes[i])
	game.message.text = ""
	var far_done := false
	var near_done := false
	var guard := 0
	while str(game.item).is_empty() and guard < 3000:
		await _frame()
		guard += 1
		if not far_done and _ahead() < 55.0:
			far_done = true
			await _shot("01_prisma_von_weitem")
		elif not near_done and _ahead() < 22.0:
			near_done = true
			await _shot("02_prisma_nah")
	if str(game.item).is_empty():
		printerr("[KartCompassCapture] no pickup")
		quit(1)
		return
	var total: float = game.star_compass.total
	var marks: Array = [
		[0.16, "03_einsammeln_energiebahn"],
		[0.95, "04_kompass_schnell"],
		[2.3, "05_kompass_bremst"],
		[3.25, "06_kompass_rastet_ein"],
	]
	for mark in marks:
		while total - game.item_roulette_time < float(mark[0]) and game.item_roulette_time > 0.0:
			await _frame()
		await _shot(str(mark[1]))
	while game.item_roulette_time > 0.0:
		await _frame()
	for _k in range(2):
		await _frame()
	await _shot("07_ergebnis")
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartCompassCapture]")
	print("[KartCompassCapture] %s: %d Bilder" % ["PASS" if released else "FAIL", saved])
	quit(0 if released and saved >= 7 else 1)
