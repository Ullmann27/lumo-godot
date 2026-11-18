extends SceneTree
## Rennkamera-Bilder plus Szenenkosten je Strecke und Grafikprofil (kein Gate).
## Aufruf (echter Renderer):
##   LUMO_KART_REVIEW_DIR=/abs/dir LUMO_KART_PROFILE=medium LUMO_KART_SIZE=1600x720 \
##   godot --path . --rendering-method gl_compatibility \
##     --script res://scripts/tests/kart_scenery_review_capture.gd -- [strecke ...]
## LUMO_KART_PROFILE: low | medium | high | ultra (ultra = HIGH + Ultra-Kulisse).
## Gibt je Bild eine Zeile "[KartSceneryReview] cost {json}" mit Zeichenaufrufen,
## Dreiecken und sichtbaren Objekten aus.
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const FRACTIONS: Array[float] = [0.06, 0.37, 0.68]
var game
var destination: String = ""
var saved: int = 0
var profile: String = "high"
var costs: Array[Dictionary] = []
var capture_size := Vector2i(1600, 720)


func _initialize() -> void:
	call_deferred("_run")


func _capture(track: String, index: int, at: float) -> void:
	root.size = capture_size
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
		var ahead: float = at + 7.0 + float(i) * 2.5
		game.opponents[i].transform = game.world.reset_transform(ahead, -2.8 + float(i) * 1.4)
		game.opponent_distances[i] = ahead
		game.opponents[i].set_motion(16.0 + i, 0.0, false, false)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	if is_instance_valid(game.world.production_tunnels):
		game.world.production_tunnels.update_light_focus(game.camera.position)
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	var cost := {
		"track": track,
		"view": index,
		"profile": profile,
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		"triangles":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		),
		"objects":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"lights": _count_lights(game.world),
	}
	costs.append(cost)
	print("[KartSceneryReview] cost " + JSON.stringify(cost))
	var file := destination.path_join("%s_%s_%d.png" % [track, profile, index])
	if root.get_texture().get_image().save_png(file) != OK:
		printerr("[KartSceneryReview] Cannot save " + file)
		quit(1)
		return
	saved += 1
	print("[KartSceneryReview] " + file)


func _count_lights(node: Node) -> int:
	var count := 0
	if node is Light3D and (node as Light3D).visible:
		count += 1
	for child in node.get_children():
		count += _count_lights(child)
	return count


func _apply_profile() -> void:
	var performance: Node = root.get_node_or_null("PerformanceManager")
	if performance != null:
		var index: int = {"low": 0, "medium": 1, "high": 2, "ultra": 2}.get(profile, 2)
		performance.call("set_profile", index, false)
		if performance.has_method("set_ultra"):
			performance.call("set_ultra", profile == "ultra")


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_REVIEW_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartSceneryReview] Needs LUMO_KART_REVIEW_DIR and a native rendering window")
		quit(1)
		return
	profile = OS.get_environment("LUMO_KART_PROFILE")
	if profile not in ["low", "medium", "high", "ultra"]:
		profile = "high"
	var size_text: String = OS.get_environment("LUMO_KART_SIZE")
	var size := Vector2i(1600, 720)
	if size_text.contains("x"):
		size = Vector2i(int(size_text.get_slice("x", 0)), int(size_text.get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(destination)
	capture_size = size
	root.size = size
	DisplayServer.window_set_size(size)
	_apply_profile()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = profile == "low"
	game.graphics_profile = "high" if profile == "ultra" else profile
	game.reduced_motion = false
	await process_frame
	await process_frame
	_apply_profile()
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS.IDS:
			selected.append(argument)
	if selected.is_empty():
		selected.assign(TRACKS.IDS)
	for track in selected:
		game.lightweight = profile == "low"
		game.graphics_profile = "high" if profile == "ultra" else profile
		game._start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": track,
				"difficulty": "flott"
			}
		)
		game._end_preview()
		await physics_frame
		await physics_frame
		game.countdown = 0.0
		game.racing = true
		for index in FRACTIONS.size():
			await _capture(track, index, game.world.length * FRACTIONS[index])
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartSceneryReview]")
	print("[KartSceneryReview] summary " + JSON.stringify(costs))
	print("[KartSceneryReview] %s: %d pictures" % ["PASS" if released else "FAIL", saved])
	quit(0 if released and saved == selected.size() * FRACTIONS.size() else 1)
