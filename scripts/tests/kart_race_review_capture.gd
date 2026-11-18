extends SceneTree
## Review pictures from the real race camera of every course. Not a gate: it
## writes PNG files for a human look at road, light, roadside and effects.
## Usage (native renderer): LUMO_KART_REVIEW_DIR=/abs/dir godot --path . \
##   --script res://scripts/tests/kart_race_review_capture.gd -- [track ...]
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const FRACTIONS: Array[float] = [0.06, 0.37, 0.68]
var game
var destination: String = ""
var saved: int = 0


func _initialize() -> void:
	call_deferred("_run")


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
		var ahead: float = at + 7.0 + float(i) * 2.5
		game.opponents[i].transform = game.world.reset_transform(ahead, -2.8 + float(i) * 1.4)
		game.opponent_distances[i] = ahead
		game.opponents[i].set_motion(16.0 + i, 0.0, false, false)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	if is_instance_valid(game.world.production_tunnels):
		game.world.production_tunnels.update_light_focus(game.camera.position)
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var file := destination.path_join("%s_%d.png" % [track, index])
	if root.get_texture().get_image().save_png(file) != OK:
		printerr("[KartRaceReview] Cannot save " + file)
		quit(1)
		return
	saved += 1
	print("[KartRaceReview] " + file)


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_REVIEW_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartRaceReview] Needs LUMO_KART_REVIEW_DIR and a native rendering window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = "high"
	game.reduced_motion = false
	await process_frame
	await process_frame
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS.IDS:
			selected.append(argument)
	if selected.is_empty():
		selected.assign(TRACKS.IDS)
	for track in selected:
		game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
			"track": track, "difficulty": "flott"})
		game._end_preview()
		await physics_frame
		await physics_frame
		game.countdown = 0.0
		game.racing = true
		for index in FRACTIONS.size():
			await _capture(track, index, game.world.length * FRACTIONS[index])
	var released: bool = await TEARDOWN.release_scene(self, game, "[KartRaceReview]")
	print("[KartRaceReview] %s: %d pictures" % ["PASS" if released else "FAIL", saved])
	quit(0 if released and saved == selected.size() * FRACTIONS.size() else 1)
