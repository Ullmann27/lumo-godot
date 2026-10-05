extends SceneTree
## Zieleinlauf-Beleg: echtes Rennen (nur Lenkung automatisch), danach Bilder
## der Zielfahrt-Kamera und des Ergebnisses. Software-Rendering (xvfb), kein
## Android-FPS-Test. Bilder: res://exports/finish/<track>/.
const STEP: float = 1.0 / 60.0
var game
var track: String = "himmelsinseln"
var out_dir: String = ""
var shot: int = 0
var cine_frame: int = 0
var done_result: bool = false


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
	out_dir = "res://exports/finish/" + track
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_jpg("%s/%02d_%s.jpg" % [out_dir, shot, name], 0.86)
	shot += 1


func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or game.menu_active:
		return false
	if not game.finished:
		# Viele Physikschritte pro Bild: das Rennen läuft unverändert mit 60 Hz.
		for i in range(240):
			if game.finished:
				break
			var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
			var direction: Vector3 = target - game.player.position
			var heading: float = atan2(-direction.x, -direction.z)
			game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
			game._physics_process(STEP)
		return false
	if game.finish_cine_left > 0.0:
		if cine_frame in [1, 60, 120, 180]:
			_save("zielfahrt_%03d" % cine_frame)
		game._physics_process(STEP)
		cine_frame += 1
		return false
	if not done_result:
		done_result = true
		_save("ergebnis_platz_%d" % int(game.result_payload.get("place", 0)))
		var proof := {
			"capture": "actual Godot engine render, xvfb + gl_compatibility",
			"track": track,
			"place": game.result_payload.get("place", 0),
			"race_seconds": snappedf(game.elapsed, 0.01),
			"best_lap": game.result_payload.get("bestLapSeconds", 0),
			"finish_camera_frames": cine_frame,
			"android_performance_measurement": false,
		}
		var file := FileAccess.open(out_dir + "/finish.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(proof, "  "))
		file.close()
		# Layoutprobe der übrigen Plätze (gleiche Szene, nur Platz getauscht).
		for place in [1, 2, 3, 4]:
			if place == int(game.result_payload.get("place", 0)):
				continue
			game.result_payload["place"] = place
			game.player.celebrate(place)
			game._show_result()
			for i in range(3):
				await process_frame
			_save("layout_platz_%d" % place)
		quit()
	return false
