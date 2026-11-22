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
	"star_magnet": [[0.12, "1_anlauf"], [0.41, "2_feld"], [0.68, "3_anziehung"]],
	"star_rocket": [[0.08, "1_flug"], [0.0, "2_treffer"], [0.15, "3_staubring"]],
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
	"gravity_wave":
	[
		[0.12, "1_ausloesen"],
		[0.45, "2_welle"],
		[0.0, "3_erfasst"],
		[0.42, "4_schweben"],
		[1.2, "5_landung"]
	],
	"star_decoy":
	[
		[0.2, "1_kopie"],
		[0.75, "2_raketen"],
		[0.0, "3_abgelenkt"],
		[0.3, "4_zerplatzt"],
		[1.0, "5_weiter"]
	],
	"turbo_xl":
	[[0.06, "1_zuendung"], [0.35, "2_schub"], [1.0, "3_energielinien"], [1.62, "4_abklingen"]],
	"arc_trap":
	[
		[0.15, "1_setzen"],
		[0.5, "2_bogen"],
		[0.0, "3_durchfahrt"],
		[0.35, "4_bremse"],
		[0.9, "5_zusammenbruch"]
	],
	"time_bloom":
	[
		[0.25, "1_wurf"],
		[0.8, "2_bluete"],
		[0.0, "3_im_feld"],
		[0.6, "4_zeitlupe"],
		[5.0, "5_schliessen"]
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
## Kompass-Modus: diese Items nacheinander über den echten Sternenkompass ziehen.
var compass_items: Array[String] = []


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
	# Zwischen den Belegbildern nicht rendern (Simulation läuft gleich weiter): spart bei
	# 1812x2176 auf der ausgelasteten Maschine den Großteil der Zeit.
	RenderingServer.render_loop_enabled = false
	for _frame in range(maxi(1, int(round(seconds / STEP)))):
		at += pace * STEP
		var lanes: Array = game.opponent_lanes.duplicate()
		var player_lane: float = game.lane
		_place()
		for i in game.opponents.size():
			# Nur seitliche Versätze der Items übernehmen (sonst bleibt die gewählte Spur).
			if game.item_ext.pushes.has(i) and absf(float(lanes[i]) - float(offsets[i][1])) > 0.01:
				offsets[i][1] = float(lanes[i])
				game.opponents[i].transform = game.world.reset_transform(
					fposmod(game.opponent_distances[i], game.track_length), float(lanes[i])
				)
				game.opponent_lanes[i] = float(lanes[i])
		if game.item_ext.pushes.has(-1) and absf(player_lane - game.lane) > 0.01:
			game.lane = player_lane
			game.player.transform = game.world.reset_transform(
				fposmod(at, game.track_length), player_lane
			)
		game.shield_time = maxf(0.0, game.shield_time - STEP)
		for i in game.opponent_shield_times.size():
			game.opponent_shield_times[i] = maxf(0.0, game.opponent_shield_times[i] - STEP)
		game._update_gameplay_layer(STEP)
		if item == "star_magnet" and game.magnet_time > 0:
			game._track_events()
		if not OS.get_environment("LUMO_KART_ITEM_DEBUG").is_empty():
			for behaviour in game.item_ext.effects:
				for entry in game.item_ext.effects[behaviour].active:
					var shown: Dictionary = entry.duplicate()
					shown.erase("rig")
					print(
						(
							"[dbg] at=%.2f rival=%.2f/%.2f %s"
							% [at, game.opponent_distances[0], game.opponent_lanes[0], shown]
						)
					)
		game._sync_rival_item_fx_all()
		game.shield_visual.advance(STEP, game.shield_time)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		# Anzeige-Anhebung (Schwerkraft-Welle) wie im Rennen über den Bild-Glätter.
		for kart in [game.player] + Array(game.opponents):
			var lift: Variant = game.item_ext.offset_for(kart)
			if lift is Transform3D:
				kart.global_position += (lift as Transform3D).origin
		game._update_hud()
		game._update_item_hud(STEP)
		for fx in game.opponent_item_fx:
			fx.advance(STEP, false, game.reduced_motion)
		await process_frame


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	await process_frame
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
	if item == "star_rocket":
		return int(game.fx.fired.get("rocket_hit", 0)) > 0
	var ext = game.item_ext
	for behaviour in ext.effects:
		for entry in ext.effects[behaviour].active:
			if (
				not str(entry.get("result", "")).is_empty()
				or str(entry.get("phase", "")) in ["done", "field"]
			):
				return true
			if entry.get("hits") is Dictionary and not (entry.hits as Dictionary).is_empty():
				return true
			if entry.get("affected") is Array and not (entry.affected as Array).is_empty():
				return true
			if float(entry.get("popped", -1.0)) >= 0.0:
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
		elif argument.begins_with("compass="):
			compass_items.assign(argument.trim_prefix("compass=").split(","))
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
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game._end_preview()
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	game.message.text = ""
	# Mitten im Rennen (nach dem 8-s-Startschutz der Raketen-Fairness).
	game.elapsed = 60.0
	# Die Rennszene setzt beim Start ihre eigene Fenstergröße: Zielgröße danach erneut setzen.
	DisplayServer.window_set_size(window_size)
	root.size = window_size
	await process_frame
	await process_frame
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
	if item == "star_magnet":
		# Approach a real collectible after the camera settles. The normal course pickup
		# code consumes it inside the magnet radius during the third exposure.
		for i in range(game.gem_distances.size()):
			var star_d: float = game.gem_distances[i]
			if star_d >= at and game.item_ext.safe_at(star_d):
				at = star_d - pace * 1.2 - 14.3
				break
	if rival_attacks:
		offsets = [[-13.0, -0.6], [-55.0, 2.0], [-62.0, -2.0], [-70.0, 1.0], [-78.0, -1.0]]
	else:
		offsets = [[11.5, 0.9], [-50.0, 2.0], [-58.0, -2.0], [-66.0, 1.0], [-74.0, -1.0]]
	if item == "whirlwind":
		offsets[0] = [16.0, 0.4]
	elif item == "gravity_wave":
		offsets[0] = [7.0, 1.2]
		offsets[1] = [5.0, -1.6]
	elif item == "star_decoy":
		offsets[0] = [-16.0, 0.3]
	elif item == "arc_trap":
		rival_attacks = true
		offsets[0] = [9.0, 0.0]
	await _tick(1.2)
	if not compass_items.is_empty():
		for id in compass_items:
			game._grant_item_with_roulette(id, game.player.global_position + Vector3.UP)
			await _tick(game.star_compass.total + 0.12)
			item = id
			await _shot("kompass_ergebnis")
			game.item = ""
			game.item_charges = 0
		var done: bool = await TEARDOWN.release_scene(self, game, "[KartItemExtCapture]")
		quit(0 if done and saved == compass_items.size() else 1)
		return
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
	if item == "star_rocket" and not rival_attacks:
		game.lock_target = 0
		game.lock_progress = 1.0
		game._fire_player_rockets()
	if item == "star_decoy":
		# Ein Rivale hinter dem Kind feuert ein Raketenpaar auf das Kind (echter Raketenflug).
		await _tick(0.3)
		game.item_runtime.fire_pair(
			"star_rocket", 0, game.opponent_distances[0], game.opponent_lanes[0], -1, [], pace
		)
		game.message.text = "Rivale feuert Sternraketen auf dich!"
	var elapsed: float = 0.3 if item == "star_decoy" else 0.0
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
