extends SceneTree
## Bildfolgen der erweiterten Items aus dem echten Rennen (Rennkamera, fahrende Karts,
## gl_compatibility): Auslösen, Flug/Anflug, Einschlag, Reaktion, Abklingen. Kein Gate.
## Usage: LUMO_KART_ITEM_DIR=/abs/dir xvfb-run godot --path . --rendering-method gl_compatibility \
##   --script res://scripts/tests/kart_item_ext_capture.gd -- item=thunder_star track=sonnenhafen \
##   [size=1812x2176] [shield] [reduced] [low] [rival]
const STEP: float = 1.0 / 60.0
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
## Je Item: [Zeit nach dem Auslösen (s), Bildname].
const SHOTS: Dictionary = {
	"thunder_star":
	[
		[0.25, "1_laden"],
		[0.56, "2_weg"],
		[0.86, "3_warnung"],
		[1.0, "4_einschlag"],
		[1.35, "5_reaktion"],
		[1.75, "6_abklingen"]
	],
	"frost_crystal":
	[[0.12, "1_abwurf"], [0.42, "2_flug"], [0.0, "3_einschlag"], [0.9, "4_eis"], [1.8, "5_tauen"]],
	"fire_meteor":
	[
		[0.1, "1_abschuss"],
		[0.35, "2_flug"],
		[0.0, "3_einschlag"],
		[0.5, "4_russ"],
		[1.2, "5_abklingen"]
	],
	"star_fortress":
	[
		[0.15, "1_aufbau"],
		[0.6, "2_doppelkuppel"],
		[6.0, "3_halbzeit"],
		[11.2, "4_ende_naht"],
		[12.6, "5_abbau"]
	],
	"whirlwind":
	[
		[0.15, "1_start"],
		[0.55, "2_lauf"],
		[0.0, "3_erfasst"],
		[0.45, "4_versetzt"],
		[1.3, "5_abklingen"]
	],
}
var game
var destination: String = ""
var at: float = 0.0
var pace: float = 17.0
var offsets: Array = []
var saved: int = 0
var item: String = "thunder_star"


func _initialize() -> void:
	call_deferred("_run")


func _place() -> void:
	game.distance = at
	game.previous_road_distance = fposmod(at, game.track_length)
	game.player.transform = game.world.reset_transform(fposmod(at, game.track_length), game.lane)
	game.player_heading = game._heading(fposmod(at, game.track_length))
	game.speed = pace
	game.physical_velocity = game.world.forward(fposmod(at, game.track_length)) * pace
	for i in game.opponents.size():
		var entry: Array = offsets[i] if i < offsets.size() else [-60.0 - i * 5.0, 0.0]
		var d: float = at + float(entry[0])
		game.opponent_distances[i] = d
		var rival_lane: float = float(entry[1])
		game.opponents[i].transform = game.world.reset_transform(
			fposmod(d, game.track_length), rival_lane
		)
		game.opponent_lanes[i] = rival_lane
		game.opponent_headings[i] = game._heading(fposmod(d, game.track_length))


## Die Karts fahren weiter (gleiches Tempo); seitliche Versätze der Items bleiben erhalten.
func _tick(seconds: float) -> void:
	for _frame in range(maxi(1, int(round(seconds / STEP)))):
		at += pace * STEP
		var lanes: Array = game.opponent_lanes.duplicate()
		var player_lane: float = game.lane
		_place()
		for i in game.opponents.size():
			if absf(float(lanes[i]) - float(offsets[i][1])) > 0.01:
				offsets[i][1] = float(lanes[i])
				game.opponents[i].transform = game.world.reset_transform(
					fposmod(game.opponent_distances[i], game.track_length), float(lanes[i])
				)
				game.opponent_lanes[i] = float(lanes[i])
		if absf(player_lane - game.lane) > 0.01:
			game.lane = player_lane
			game.player.transform = game.world.reset_transform(
				fposmod(at, game.track_length), player_lane
			)
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
	var file := destination.path_join("%s_%s.png" % [item, name])
	if root.get_texture().get_image().save_png(file) != OK:
		printerr("[KartItemExtCapture] Cannot save " + file)
		return
	saved += 1
	print(
		(
			"[KartItemExtCapture] %s draw_calls=%d"
			% [
				file,
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			]
		)
	)


func _impact_seen() -> bool:
	var ext = game.item_ext
	for behaviour in ext.effects:
		for entry in ext.effects[behaviour].active:
			if (
				not str(entry.get("result", "")).is_empty()
				or str(entry.get("phase", "")) in ["done", "field"]
			):
				return true
	return false


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_ITEM_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartItemExtCapture] Needs LUMO_KART_ITEM_DIR and a rendering window")
		quit(1)
		return
	var track: String = "sonnenhafen"
	var window_size := Vector2i(1812, 2176)
	var shield := false
	var reduced := false
	var profile := "high"
	var rival_attacks := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("item="):
			item = argument.trim_prefix("item=")
		elif argument.begins_with("track="):
			track = argument.trim_prefix("track=")
		elif argument.begins_with("size="):
			var parts: PackedStringArray = argument.trim_prefix("size=").split("x")
			window_size = Vector2i(int(parts[0]), int(parts[1]))
		elif argument == "shield":
			shield = true
		elif argument == "reduced":
			reduced = true
		elif argument in ["low", "medium", "high"]:
			profile = argument
		elif argument == "rival":
			rival_attacks = true
	DirAccess.make_dir_recursive_absolute(destination)
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
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "normal"}
	)
	game._end_preview()
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	game.message.text = ""
	if is_instance_valid(game.kart_audio):
		game.kart_audio.set_muted(true)
	# Sichere, gerade Stelle suchen (Ziel vorn ist im Rennbild).
	at = game.track_length * 0.18
	for _i in range(300):
		var ok: bool = true
		for gap in [-10.0, 0.0, 20.0, 40.0]:
			ok = ok and game.item_ext.safe_at(at + gap)
		if ok:
			break
		at += 7.0
	game.lane = 0.0
	if rival_attacks:
		offsets = [[-13.0, -0.6], [-55.0, 2.0], [-62.0, -2.0], [-70.0, 1.0], [-78.0, -1.0]]
	else:
		offsets = [[11.5, 0.9], [-50.0, 2.0], [-58.0, -2.0], [-66.0, 1.0], [-74.0, -1.0]]
	if item == "whirlwind":
		offsets[0] = [16.0, 0.4]
	await _tick(1.2)
	if shield:
		if rival_attacks:
			game.shield_time = 6.0
		else:
			game.opponent_shield_times[0] = 5.0
	if rival_attacks:
		game.opponent_items[0] = item
		game._rival_use_catalog_item(0, game.player.position - game.opponents[0].position)
	else:
		game._grant_item(item)
		game.item_roulette_time = 0.0
		game._use_item()
	var elapsed: float = 0.0
	var impact_at: float = -1.0
	var tag: String = (
		("_rival" if rival_attacks else "")
		+ ("_schild" if shield else "")
		+ ("_ruhig" if reduced else "")
		+ ("_" + profile if profile != "high" else "")
	)
	for shot in SHOTS.get(item, []):
		var when: float = float(shot[0])
		if when == 0.0:
			# Bild genau beim Einschlag (die Flugzeit hängt vom echten Abstand ab).
			for _f in range(240):
				if _impact_seen():
					break
				await _tick(STEP)
				elapsed += STEP
			await _tick(STEP * 2.0)
			elapsed += STEP * 2.0
			impact_at = elapsed
		else:
			var target_time: float = when + (impact_at if impact_at >= 0.0 else 0.0)
			if target_time > elapsed:
				await _tick(target_time - elapsed)
				elapsed = target_time
		await _shot(str(shot[1]) + tag)
	print(
		(
			"[KartItemExtCapture] stats %s"
			% JSON.stringify(
				game.item_ext.effects.values().map(func(e): return [e.behaviour, e.stats])
			)
		)
	)
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartItemExtCapture]")
	print("[KartItemExtCapture] %s: %d Bilder" % ["PASS" if released else "FAIL", saved])
	quit(0 if released and saved > 0 else 1)
