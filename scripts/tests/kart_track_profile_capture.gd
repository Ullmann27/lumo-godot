extends SceneTree
## Bildreihe zum Streckenprofil: je Strecke Bilder aus der echten Fahrerkamera an
## gleichmäßig verteilten Stellen (oder an angegebenen Distanzen). Das Kart wird 70 m vor
## der Stelle aufgesetzt und fährt mit Rennphysik (Mittellinien-Lenkung) hinein.
## Aufruf (mit Bild): -- <out_dir> <track_id[,track_id]> [width height] [count | d1:d2:...]
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame


func _drive_to(mark: float) -> void:
	var guard: int = 0
	while fposmod(game.previous_road_distance, game.track_length) < mark and guard < 900:
		var lane: float = THRILLS.bot_lane(game.world, game.previous_road_distance)
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, lane)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
		)
		game.brake = 0.0
		game._physics_process(STEP)
		guard += 1


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0]
	var tracks: PackedStringArray = args[1].split(",")
	var width: int = int(args[2]) if args.size() > 2 else 1280
	var height: int = int(args[3]) if args.size() > 3 else 576
	var spec: String = args[4] if args.size() > 4 else "6"
	root.size = Vector2i(width, height)
	for track in tracks:
		var folder: String = output.path_join(track)
		DirAccess.make_dir_recursive_absolute(folder)
		game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await _settle()
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
		await _settle()
		game.countdown = 0
		game.racing = true
		for i in range(game.opponents.size()):
			game.opponent_distances[i] = -400.0
			game.opponents[i].visible = false
		var marks: Array = []
		if spec.contains(":") or spec.contains("."):
			for part in spec.split(":"):
				marks.append(float(part))
		else:
			for k in range(int(spec)):
				marks.append(game.track_length * (float(k) + 0.5) / float(int(spec)))
		for k in range(marks.size()):
			var mark: float = float(marks[k])
			var start: float = maxf(2.0, mark - 70.0)
			game.distance = start
			game.previous_road_distance = start
			game.checkpoint_index = int(start / (game.track_length / 8.0))
			game.player.transform = game.world.reset_transform(start, 0.0)
			game.player_heading = game._heading(start)
			game.airborne = false
			game.vertical_speed = 0.0
			game.speed = 44.0
			game.physical_velocity = (
				Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
			)
			game._update_camera(STEP, true)
			_drive_to(mark)
			game._update_camera(STEP)
			for _i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = folder.path_join("%02d_d%04d.png" % [k + 1, int(mark)])
			root.get_texture().get_image().save_png(path)
			print(
				(
					"[ProfileCapture] %s d=%.0f y=%.1f air=%s speed=%.1f resets=%d"
					% [
						path,
						mark,
						game.player.position.y,
						game.airborne,
						game.speed,
						game.reset_count
					]
				)
			)
		game.abandoned = true
		await TEARDOWN.release_scene(self, game, "[ProfileCapture]")
		await _settle()
	print("[ProfileCapture] DONE")
	quit(0)
