extends SceneTree
## Real stationary production-scene captures, reusable unchanged on the old source.
## A staged view proves rendering, not driving, Android performance, or visual approval.

const PROVENANCE = preload("res://tools/aaa_capture_metadata.gd")
const SIZE := Vector2i(1280, 720)
var game
var folder := ""
var selected := "winter_sprint"
var low := false
var manifest: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			selected = argument.trim_prefix("--track=")
		elif argument == "--low":
			low = true
		else:
			return "Unknown argument: " + argument
	if selected not in ["winter_sprint", "crystal_canyon"]:
		return "Unsupported capture track: " + selected
	return ""


func _prepare_output() -> String:
	if DisplayServer.get_name() == "headless":
		return "Real rendering surface required; no headless image substitute"
	folder = OS.get_environment("LUMO_CAPTURE_DIR")
	if folder.is_empty() or FileAccess.file_exists(folder.path_join("capture.json")):
		return "LUMO_CAPTURE_DIR must name a fresh output directory"
	var isolated := OS.get_environment("XDG_DATA_HOME")
	var user_path := ProjectSettings.globalize_path("user://")
	if isolated.is_empty() or not user_path.begins_with(isolated.trim_suffix("/") + "/"):
		return "Set an isolated XDG_DATA_HOME before loading the production game"
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return "Could not create output directory"
	return ""


func _run() -> void:
	var problem := _arguments()
	if problem.is_empty():
		problem = _prepare_output()
	if not problem.is_empty():
		await _finish(2, problem)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	manifest = {
		"source": PROVENANCE.source(),
		"track": selected,
		"low": low,
		"capture_kind": "stationary production kart_island scene; staged player and cameras",
		"viewport": [SIZE.x, SIZE.y],
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"user_data_path": ProjectSettings.globalize_path("user://"),
		"views": []
	}
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	if scene == null:
		await _finish(1, "Production scene failed to load")
		return
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = low
	game.graphics_profile = "low" if low else "high"
	game.reduced_motion = true
	game.auto_gas = false
	game.rng.seed = 2019
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": selected,
			"difficulty": "gemuetlich"
		}
	)
	game.abandoned = true
	if not is_instance_valid(game.world) or not is_instance_valid(game.camera):
		await _finish(1, "Production race did not instantiate its world and camera")
		return
	game._end_preview()
	game.countdown = 0
	game.racing = true
	game.gas_held = false
	game.speed = 0.0
	game.modal.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(4)
	if not await _capture_views():
		return
	manifest["status"] = "captured"
	var file := FileAccess.open(folder.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		await _finish(1, "Could not write capture manifest")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	await _finish(0)


func _capture_views() -> bool:
	var center: float = game.world.length * (0.315 if selected == "winter_sprint" else 0.61)
	_place_player(center - 38.0)
	game._update_camera(1.0, true)
	if not await _capture("01_race_approach", "production chase camera"):
		return false
	if selected == "winter_sprint":
		var east := Vector3(-INF, 0, 0)
		for point: Vector3 in game.world.curve.get_baked_points():
			if point.x > east.x:
				east = point
		var station := Vector3(east.x + 26.0, -2.0, east.z + 9.0)
		# Stay beyond the complete road's east edge, above its existing deck.
		# This same layout calculation also works on the unexpanded baseline.
		game.camera.position = station + Vector3(-14, 25, 50)
		game.camera.look_at(station + Vector3(20, 22, -36))
	else:
		var road: Vector3 = game.world.position_at(center)
		game.camera.position = game.world.position_at(center - 36.0) + Vector3.UP * 5.5
		game.camera.look_at(road + Vector3.UP * 8.0)
	game.camera.fov = 61.0
	if not await _capture(
		"02_world_landmark", "manual context camera; unchanged production lighting"
	):
		return false
	_place_player(center + 8.0)
	game._update_camera(1.0, true)
	if not await _capture("03_route_reveal", "production chase camera within authored section"):
		return false
	return true


func _place_player(distance: float) -> void:
	var placed: float = fposmod(distance, game.track_length)
	game.distance = placed
	game.previous_road_distance = placed
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(placed, 0.0)
	game.player_heading = game._heading(placed)
	game._update_hud()


func _capture(name: String, camera_source: String) -> bool:
	await _frames(4)
	var snapshot: Image = root.get_texture().get_image()
	var path := folder.path_join(name + ".png")
	if snapshot == null or snapshot.get_size() != SIZE or snapshot.save_png(path) != OK:
		await _finish(1, "Could not capture real viewport: " + name)
		return false
	var camera: Camera3D = game.camera
	manifest.views.append(
		{
			"name": name,
			"path": path,
			"sha256": FileAccess.get_sha256(path),
			"camera_source": camera_source,
			"position": _vector(camera.global_position),
			"basis_x": _vector(camera.global_basis.x),
			"basis_y": _vector(camera.global_basis.y),
			"basis_z": _vector(camera.global_basis.z),
			"fov": camera.fov,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		}
	)
	return true


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _finish(code: int, problem: String = "") -> void:
	if not problem.is_empty():
		push_error("[KartWorldExpansionCapture] " + problem)
	if is_instance_valid(game):
		var playbacks: Array[WeakRef] = []
		for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
			if player.has_stream_playback():
				playbacks.append(weakref(player.get_stream_playback()))
		game.abandoned = true
		game.queue_free()
		await _frames(3)
		game = null
		if not await _release_audio(playbacks):
			push_error("[KartWorldExpansionCapture] Audio playback retained after scene teardown")
			code = 1
	if code == 0:
		print(
			"[KartWorldExpansionCapture] PASS track=%s views=%d" % [selected, manifest.views.size()]
		)
	quit(code)


func _release_audio(playbacks: Array[WeakRef]) -> bool:
	# stop() queues server-side fadeout; fixed-fps frames can outrun the audio
	# thread. Observe the actual playback lifetime without holding it alive.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		if pending == 0:
			print(
				(
					"[KartWorldExpansionCapture] audio_release tracked=%d elapsed_ms=%d"
					% [playbacks.size(), Time.get_ticks_msec() - started]
				)
			)
			return true
		if Time.get_ticks_msec() - started >= 2000:
			return false
		OS.delay_msec(2)
		await _frames(1)
	return false
