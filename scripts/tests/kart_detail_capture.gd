extends SceneTree
## Vorher/Nachher-Aufnahmen und Messung der Kart-Detailschicht aus der echten
## Rennkamera. Pro Position wird dasselbe Bild einmal ohne und einmal mit
## Detailschicht gerendert; Draw-Calls und Dreiecke beider Bilder landen in
## <dir>/measure_<profil>.json. Kein Gate, braucht ein natives Fenster.
## LUMO_KART_REVIEW_DIR=/abs/dir [LUMO_KART_DETAIL_PROFILE=low|medium|high]
## [LUMO_KART_PORTRAIT=1] [LUMO_KART_SHOTS=before,after] godot --path . \
##   --script res://scripts/tests/kart_detail_capture.gd -- [track ...]
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const DETAIL = preload("res://scripts/games/visual/kart_detail_layer.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const FRACTIONS: Array[float] = [0.004, 0.13, 0.31, 0.52, 0.71, 0.9]
var game
var destination: String = ""
var profile: String = "high"
var shots: PackedStringArray = PackedStringArray(["before", "after"])
var results: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _frame() -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw


func _counts() -> Dictionary:
	return {
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}


func _capture(track: String, index: int, at: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at)
	game.player_heading = game._heading(at)
	game.speed = 18.0
	game.physical_velocity = game.world.forward(at) * game.speed
	game.airborne = false
	game.vertical_speed = 0.0
	game.steering = 0.0
	for i in game.opponents.size():
		var ahead: float = at + 9.0 + float(i) * 3.0
		game.opponents[i].transform = game.world.reset_transform(ahead, -2.8 + float(i) * 1.4)
		game.opponent_distances[i] = ahead
		game.opponents[i].set_motion(16.0 + i, 0.0, false, false)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	if is_instance_valid(game.world.production_tunnels):
		game.world.production_tunnels.update_light_focus(game.camera.position)
	var layer: Node3D = game.world.get_node_or_null(DETAIL.ROOT_NAME)
	var entry: Dictionary = {"track": track, "index": index, "distance": at}
	for shot in ["before", "after"]:
		if layer != null:
			layer.visible = shot == "after"
		await _frame()
		entry[shot] = _counts()
		if shot in shots:
			var image: Image = root.get_texture().get_image()
			var file := destination.path_join("%s_%d_%s.jpg" % [track, index, shot])
			image.save_jpg(file, 0.82)
			print("[KartDetailCapture] " + file)
	entry["delta_draw_calls"] = int(entry.after.draw_calls) - int(entry.before.draw_calls)
	entry["delta_primitives"] = int(entry.after.primitives) - int(entry.before.primitives)
	results.append(entry)
	print("[KartDetailCapture] %s #%d draw %+d prim %+d" % [track, index, entry.delta_draw_calls, entry.delta_primitives])


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_REVIEW_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartDetailCapture] Needs LUMO_KART_REVIEW_DIR and a native rendering window")
		quit(1)
		return
	var wanted: String = OS.get_environment("LUMO_KART_DETAIL_PROFILE")
	profile = wanted if wanted in ["low", "medium", "high"] else "high"
	if OS.get_environment("LUMO_KART_SHOTS") != "":
		shots = OS.get_environment("LUMO_KART_SHOTS").split(",")
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(720, 1600) if OS.get_environment("LUMO_KART_PORTRAIT") == "1" else Vector2i(1600, 720)
	LumoQuality.set_tier(profile)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = profile == "low"
	game.graphics_profile = profile
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = profile == "low"
	game.graphics_profile = profile
	game.reduced_motion = false
	await process_frame
	await process_frame
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS.IDS:
			selected.append(argument)
	if selected.is_empty():
		selected.assign(TRACKS.IDS)
	var fractions: Array[float] = FRACTIONS
	if OS.get_environment("LUMO_KART_FRACTIONS") != "":
		fractions = []
		for part in OS.get_environment("LUMO_KART_FRACTIONS").split(","):
			fractions.append(float(part))
	for track in selected:
		game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
			"track": track, "difficulty": "flott"})
		game._end_preview()
		await physics_frame
		await physics_frame
		# Das gewünschte Profil explizit bauen (ersetzt die automatisch gebaute Schicht).
		DETAIL.apply(game.world, track, profile)
		game.countdown = 0.0
		game.racing = true
		for index in fractions.size():
			await _capture(track, index, game.world.length * fractions[index])
		var info: Dictionary = game.world.get_meta(DETAIL.META, {})
		results.append({"track": track, "layer": {"stats": info.get("stats", {}), "build_ms": info.get("build_ms", 0.0), "meshes": info.get("meshes", 0)}})
	var file := FileAccess.open(destination.path_join("measure_%s.json" % profile), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartDetailCapture]")
	print("[KartDetailCapture] %s" % ("PASS" if released else "FAIL"))
	quit(0 if released else 1)
