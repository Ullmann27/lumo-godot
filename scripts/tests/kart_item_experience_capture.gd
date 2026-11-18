extends SceneTree
## Review pictures of the Sternraketen / Sternenschild experience from the real race
## camera: pods unfolded, armed with lock-on, launch, flight, hit, shield, bounce,
## warning and the item roulette with the first-time hint. Not a gate: it writes PNGs.
## Usage (native renderer): LUMO_KART_ITEM_DIR=/abs/dir godot --path . \
##   --script res://scripts/tests/kart_item_experience_capture.gd -- [landscape|portrait] [low|medium|high]
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
var game
var destination: String = ""
var orientation: String = "landscape"
var saved: int = 0
var draw_calls: Dictionary = {}
var at: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _place(rival_offsets: Array) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(at)
	game.player_heading = game._heading(at)
	game.speed = 18.0
	game.physical_velocity = game.world.forward(at) * game.speed
	for i in game.opponents.size():
		var entry: Array = rival_offsets[i] if i < rival_offsets.size() else [-40.0 - i * 3.0, 0.0]
		var d: float = at + float(entry[0])
		game.opponents[i].transform = game.world.reset_transform(d, float(entry[1]))
		game.opponent_distances[i] = d
		game.opponent_lanes[i] = float(entry[1])
		game.opponent_headings[i] = game._heading(d)


func _tick(seconds: float, rival_offsets: Array) -> void:
	for _frame in range(maxi(1, int(round(seconds / STEP)))):
		_place(rival_offsets)
		game.shield_time = maxf(0.0, game.shield_time - STEP)
		for i in game.opponent_shield_times.size():
			game.opponent_shield_times[i] = maxf(0.0, game.opponent_shield_times[i] - STEP)
		game._update_gameplay_layer(STEP)
		game._sync_rival_item_fx_all()
		game.shield_visual.advance(STEP, game.shield_time)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		game._update_hud()
		game._update_item_hud(STEP)
		for fx in game.opponent_item_fx:
			fx.advance(STEP, false, game.reduced_motion)
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := destination.path_join("%s_%s.png" % [orientation, name])
	if root.get_texture().get_image().save_png(file) != OK:
		printerr("[KartItemCapture] Cannot save " + file)
		return
	draw_calls[name] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	saved += 1
	print("[KartItemCapture] %s draw_calls=%d" % [file, draw_calls[name]])


## Same frame with and without the given effect nodes: their draw-call cost.
func _measure(label: String, nodes: Array) -> void:
	await RenderingServer.frame_post_draw
	var with_fx: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var shown: Array[bool] = []
	for node in nodes:
		shown.append(node.visible)
		node.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var without_fx: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	for i in nodes.size():
		nodes[i].visible = shown[i]
	draw_calls["cost_" + label] = [with_fx, without_fx, with_fx - without_fx]


## Orbit view of the player's kart (kart space offset), for judging the props up close.
func _closeup(name: String, offset: Vector3) -> void:
	var kart: Node3D = game.player
	var eye: Vector3 = kart.global_transform * offset
	var saved: Transform3D = game.camera.global_transform
	game.camera.global_transform = Transform3D(Basis.looking_at(kart.global_position + Vector3.UP * 0.7 - eye, Vector3.UP), eye)
	await process_frame
	await _shot(name)
	game.camera.global_transform = saved


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_ITEM_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartItemCapture] Needs LUMO_KART_ITEM_DIR and a native rendering window")
		quit(1)
		return
	var profile: String = "high"
	var reduced: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument in ["landscape", "portrait"]:
			orientation = argument
		elif argument in ["low", "medium", "high"]:
			profile = argument
		elif argument == "reduced":
			reduced = true
	DirAccess.make_dir_recursive_absolute(destination)
	var window_size := Vector2i(1600, 720) if orientation == "landscape" else Vector2i(720, 1600)
	DisplayServer.window_set_size(window_size)
	root.size = window_size
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = profile
	game.reduced_motion = reduced
	await process_frame
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"})
	game._end_preview()
	await physics_frame
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	game.message.text = ""
	at = game.world.length * 0.2
	# Rival 1 straight ahead, rival 2 ahead-left holding armed rockets, the rest far behind.
	var ahead: Array = [[-45.0, 0.0], [26.0, 1.2], [14.0, -3.0], [-60.0, 2.0], [-70.0, -2.0]]
	await _tick(0.3, ahead)
	var base_calls: int = 0
	await RenderingServer.frame_post_draw
	base_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	draw_calls["baseline_no_items"] = base_calls
	# 1. Pickup roulette + first-time hint, then the pods unfold.
	game._grant_item_with_roulette("star_rocket")
	await _tick(0.45, ahead)
	await _shot("01_roulette")
	await _tick(0.75, ahead)
	await _shot("02_pods_unfolded_hint")
	await _closeup("02b_pods_closeup", Vector3(-2.6, 1.6, -2.4))
	# 2. Armed: flames at the nozzles, seeker, brackets close, ZIEL ERFASST.
	game.opponent_items[2] = "star_rocket"
	game.opponent_rocket_hold[2] = 0.0
	game._use_item()
	await _tick(0.18, ahead)
	await _shot("03_armed_locking")
	await _tick(0.6, ahead)
	await _shot("04_armed_locked")
	await _closeup("04b_armed_flames_closeup", Vector3(2.4, 1.3, 2.6))
	await _measure("pods_armed", [game.player_pods] + game.opponent_pods.filter(func(p): return is_instance_valid(p)))
	# 3. Fire: pair leaves the pods with flame and smoke, then flies.
	game._use_item()
	await _tick(0.07, ahead)
	await _shot("05_launch")
	await _tick(0.2, ahead)
	await _shot("06_flight")
	await _measure("rockets_in_flight", [game.item_runtime])
	var hit := false
	for _i in range(60):
		await _tick(STEP, ahead)
		if game.opponent_spin_times.max() > 0.0:
			hit = true
			break
	await _tick(0.08, ahead)
	await _shot("07_hit")
	await _tick(0.35, ahead)
	await _shot("07b_hit_spin_cheer")
	print("[KartItemCapture] hit=%s" % hit)
	game.item_runtime.clear()
	game.item = ""
	game.item_charges = 0
	game._sync_player_rocket_phase()
	game.opponent_items[2] = ""
	# 4. Warning: a rival behind locks onto the player.
	var behind: Array = [[-16.0, 0.4], [40.0, 2.0], [30.0, -3.0], [-60.0, 2.0], [-70.0, -2.0]]
	for i in game.opponent_spin_times.size():
		game.opponent_spin_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
	game.opponent_items[0] = "star_rocket"
	game.opponent_rocket_hold[0] = 99.0
	game.opponent_item_cooldowns[0] = 0.0
	game._grant_item("shield")
	game.item_hint = ""
	await _tick(0.9, behind)
	await _shot("08_warning_locked_on_you")
	# 5. Shield up: dome sweeps up around the kart.
	game._use_item()
	await _tick(0.25, behind)
	await _shot("09_shield_raising")
	await _tick(0.5, behind)
	await _shot("10_shield_active")
	await _measure("shield_dome", [game.shield_visual])
	# 6. The rival's pair arrives and bounces off the dome.
	var bounced := false
	for _i in range(150):
		await _tick(STEP, behind)
		if int(game.gameplay_stats.get("blocked", 0)) > 0:
			bounced = true
			break
	await _tick(0.06, behind)
	await _shot("11_bounce_off_shield")
	await _tick(0.25, behind)
	await _shot("12_bounce_after")
	print("[KartItemCapture] bounced=%s" % bounced)
	print("[KartItemCapture] draw_calls %s" % JSON.stringify(draw_calls))
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartItemCapture]")
	print("[KartItemCapture] %s: %d pictures" % ["PASS" if released else "FAIL", saved])
	quit(0 if released and saved >= 12 else 1)
