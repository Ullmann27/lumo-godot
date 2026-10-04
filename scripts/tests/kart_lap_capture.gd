extends SceneTree
## Full-race evidence: one real race (start lights, two laps, result) on a chosen course.
## The automated driver only steers; the unmodified game physics run at 60 Hz.
## Frames go to res://exports/lap/<track>/, telemetry to lap.json. Not an Android FPS test.
const STEP: float = 1.0 / 60.0
var game
var track: String = "bergwelt"
var frame: int = 0
var shot: int = 0
var every: int = 10
var substeps: int = 3
var out_dir: String = ""
var lap_times: Array[float] = []


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(960, 540)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		if arg.begins_with("--every="):
			every = maxi(1, int(arg.trim_prefix("--every=")))
		if arg.begins_with("--substeps="):
			substeps = clampi(int(arg.trim_prefix("--substeps=")), 1, 6)
	out_dir = "res://exports/lap/" + track
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)


func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or game.menu_active:
		return false
	# Several physics steps per rendered frame keep software rendering affordable;
	# the simulation itself still advances in exact 1/60 s steps.
	for substep in range(substeps):
		if game.finished:
			break
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
		var lap_before: int = int(game.checkpoint_index / 8)
		game._physics_process(STEP)
		if int(game.checkpoint_index / 8) > lap_before:
			lap_times.append(game.elapsed)
	frame += 1
	if frame % every == 0 or (game.finished and shot >= 0):
		var image: Image = root.get_texture().get_image()
		image.save_jpg(out_dir + "/frame_%04d.jpg" % shot, 0.82)
		shot += 1
	if game.finished:
		var proof := {
			"capture": "actual Godot engine render, xvfb + gl_compatibility",
			"track": track,
			"mode": "race",
			"physics_hz": 60,
			"driver": "automated steering towards the road 10 m ahead; no position changes",
			"race_seconds": snappedf(game.elapsed, 0.01),
			"lap_times": lap_times,
			"place": game.result_payload.get("place", 0),
			"stars": game.result_payload.get("stars", 0),
			"checkpoints": game.checkpoint_index,
			"resets": game.reset_count,
			"wall_contacts": game.wall_contacts,
			"tokens_collected": game.collected.size(),
			"frames": shot,
			"android_performance_measurement": false
		}
		var file := FileAccess.open(out_dir + "/lap.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(proof, "  "))
		file.close()
		print("[LapCapture] ", JSON.stringify(proof))
		game.abandoned = true
		game.queue_free()
		game = null
		call_deferred("_quit")
	return false


func _quit() -> void:
	await create_timer(0.5).timeout
	quit(0)
