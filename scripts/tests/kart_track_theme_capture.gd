extends SceneTree
## Developer-only static inspection of one production track and accepted detail site.
## No driving, visual approval, or Android performance result is implied.

const THEMES = preload("res://scripts/games/track_themes/track_theme_registry.gd")
const PROVENANCE = preload("res://tools/aaa_capture_metadata.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)
const CAPTURE_SEED := 1923
const CAPTURE_ROOT_PREFIX := "/tmp/lumo-theme-capture."

var game
var track_id := ""
var detail := ""
var out_dir := ""
var site_index := 0
var output_ready := false
var manifest: Dictionary = {}
var capture_root := ""


func _initialize() -> void:
	call_deferred("_run")


func _arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--track="):
			track_id = value.trim_prefix("--track=")
		elif value.begins_with("--detail="):
			detail = value.trim_prefix("--detail=")
		elif value.begins_with("--out="):
			out_dir = value.trim_prefix("--out=")
		elif value.begins_with("--site="):
			var index_text := value.trim_prefix("--site=")
			if not index_text.is_valid_int():
				return "--site must be a nonnegative integer"
			site_index = int(index_text)
		else:
			return "Unknown argument: " + value
	if not THEMES.supports(track_id):
		return "--track must select one of the eleven registered other-world tracks"
	if detail not in ["full", "low"]:
		return "--detail=full or --detail=low is required"
	if out_dir.is_empty() or site_index < 0:
		return "--out=<new directory> and a nonnegative --site are required"
	return ""


func _capture_environment() -> String:
	capture_root = OS.get_environment("LUMO_TRACK_THEME_CAPTURE_ROOT")
	if not capture_root.begins_with(CAPTURE_ROOT_PREFIX):
		return "Isolated capture marker missing: LUMO_TRACK_THEME_CAPTURE_ROOT must name a fresh /tmp/lumo-theme-capture.* directory"
	var suffix := capture_root.trim_prefix(CAPTURE_ROOT_PREFIX)
	if suffix.is_empty() or suffix.contains("/"):
		return "Capture root must be a direct /tmp/lumo-theme-capture.* directory"
	var expected_paths := {
		"XDG_DATA_HOME": capture_root.path_join("userdata"),
		"XDG_CONFIG_HOME": capture_root.path_join("config"),
		"XDG_CACHE_HOME": capture_root.path_join("cache"),
	}
	for key in expected_paths:
		if (
			OS.get_environment(key) != expected_paths[key]
			or not DirAccess.dir_exists_absolute(expected_paths[key])
		):
			return (
				"Set "
				+ str(key)
				+ " to the prepared isolated directory before starting Godot: "
				+ str(expected_paths[key])
			)
	var user_path := ProjectSettings.globalize_path("user://")
	if not user_path.begins_with(str(expected_paths["XDG_DATA_HOME"]) + "/"):
		return "Godot user:// is outside the isolated XDG_DATA_HOME: " + user_path
	var ready_path := capture_root.path_join("capture.ready")
	var expected_marker := "lumo-track-theme-capture-v1\n" + capture_root + "\n"
	if (
		not FileAccess.file_exists(ready_path)
		or FileAccess.get_file_as_string(ready_path) != expected_marker
	):
		return "Fresh capture.ready marker missing or invalid; prepare a new capture root before process startup"
	var started_path := capture_root.path_join("capture.started")
	if FileAccess.file_exists(started_path) or DirAccess.dir_exists_absolute(started_path):
		return "Capture root has already been used; prepare a new root"
	for state_path in [
		"user://kart_preferences.cfg",
		"user://kart_sonnenhafen_session.cfg",
		"user://kart_sonnenhafen_session.cfg.tmp"
	]:
		if FileAccess.file_exists(state_path):
			return (
				"Existing kart state found in test user data; prepare a new capture root: "
				+ state_path
			)
	var config_path: String = expected_paths["XDG_CONFIG_HOME"]
	if (
		not DirAccess.get_files_at(config_path).is_empty()
		or not DirAccess.get_directories_at(config_path).is_empty()
	):
		return "Isolated XDG_CONFIG_HOME must still be empty before loading the game scene"
	var started := FileAccess.open(started_path, FileAccess.WRITE)
	if started == null:
		return "Cannot mark isolated capture root as used"
	started.store_string(expected_marker)
	started.flush()
	var result := started.get_error()
	started.close()
	return "" if result == OK else "Cannot persist isolated capture start marker"


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _write_manifest() -> bool:
	var file := FileAccess.open(out_dir.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		push_error(
			"[TrackThemeCapture] Cannot write capture.json: " + str(FileAccess.get_open_error())
		)
		return false
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.flush()
	var result := file.get_error()
	file.close()
	return result == OK


func _finish(code: int, message: String = "") -> void:
	if not message.is_empty():
		manifest["status"] = "failed"
		manifest["error"] = message
		push_error("[TrackThemeCapture] " + message)
	if output_ready and not _write_manifest():
		code = 1
	if is_instance_valid(game):
		game.abandoned = true
		game.queue_free()
		await _frames(2)
	quit(code)


func _save_view(name: String, camera_source: String) -> String:
	await _frames(3)
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return "Empty viewport image for " + name
	var path := out_dir.path_join(name + ".png")
	var result := image.save_png(path)
	if result != OK:
		return "Cannot save " + path + ": " + str(result)
	var camera: Camera3D = game.camera
	var transform := camera.global_transform
	(
		manifest["views"]
		. append(
			{
				"name": name,
				"path": path,
				"camera_source": camera_source,
				"camera_position": _vector(transform.origin),
				"camera_basis_x": _vector(transform.basis.x),
				"camera_basis_y": _vector(transform.basis.y),
				"camera_basis_z": _vector(transform.basis.z),
				"fov_degrees": camera.fov,
				"near": camera.near,
				"far": camera.far,
				"player_position": _vector(game.player.global_position),
				"player_distance": game.distance,
				"image_size": [image.get_width(), image.get_height()],
			}
		)
	)
	print("[TrackThemeCapture] saved ", path)
	return ""


func _run() -> void:
	var problem := _arguments()
	if not problem.is_empty():
		await _finish(1, problem)
		return
	if DisplayServer.get_name() == "headless":
		await _finish(
			1,
			"A resource-approved graphical surface is required; this script does not create a display server"
		)
		return
	problem = _capture_environment()
	if not problem.is_empty():
		await _finish(1, problem)
		return
	out_dir = ProjectSettings.globalize_path(out_dir)
	if DirAccess.dir_exists_absolute(out_dir) or FileAccess.file_exists(out_dir):
		await _finish(1, "Output path already exists; choose a new directory: " + out_dir)
		return
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		await _finish(1, "Cannot create output directory: " + out_dir)
		return
	output_ready = true
	manifest = {
		"status": "initializing",
		"source": PROVENANCE.source(),
		"track_id": track_id,
		"requested_detail": detail,
		"selected_site_index": site_index,
		"seed": CAPTURE_SEED,
		"viewport": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"user_data_path": ProjectSettings.globalize_path("user://"),
		"capture_root": capture_root,
		"xdg_data_home": OS.get_environment("XDG_DATA_HOME"),
		"xdg_config_home": OS.get_environment("XDG_CONFIG_HOME"),
		"xdg_cache_home": OS.get_environment("XDG_CACHE_HOME"),
		"isolation_check":
		"single-use marker, exact XDG paths, user:// containment and no existing kart state checked before scene load",
		"capture_kind": "stationary production scene inspection; no driven race",
		"visual_review": "pending original-reference review",
		"views": [],
	}
	root.size = CAPTURE_SIZE
	root.content_scale_size = CAPTURE_SIZE
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	if scene == null:
		await _finish(1, "Production kart_island scene could not be loaded")
		return
	game = scene.instantiate()
	if not is_instance_valid(game):
		await _finish(1, "Production kart_island scene could not be instantiated")
		return
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = detail == "low"
	game.graphics_profile = "low" if game.lightweight else "high"
	game.reduced_motion = true
	game.auto_gas = false
	seed(CAPTURE_SEED)
	game.rng.seed = CAPTURE_SEED
	(
		game
		. _start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": track_id,
				"difficulty": "gemuetlich",
			}
		)
	)
	# _begin_race already writes preferences/session; pre-process XDG isolation is mandatory.
	game.abandoned = true
	if (
		not is_instance_valid(game.world)
		or not is_instance_valid(game.player)
		or not is_instance_valid(game.camera)
	):
		await _finish(
			1,
			"Production race did not create a world, player and camera; inspect scene startup or a pending session choice"
		)
		return
	game._end_preview()
	game.set_physics_process(false)
	game.countdown = 0
	game.racing = true
	game.gas_held = false
	game.speed = 0.0
	game.steering = 0.0
	game.modal.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(4)
	var sites: Array = game.world.get_meta("reference_detail_sites", [])
	var theme := str(game.world.get_meta("reference_detail_theme", ""))
	manifest["actual_detail"] = "low" if game.world.low_detail else "full"
	manifest["graphics_profile"] = game.graphics_profile
	manifest["actual_lightweight"] = game.lightweight
	manifest["reduced_motion"] = game.reduced_motion
	manifest["process_frozen"] = true
	manifest["reference_detail_theme"] = theme
	manifest["reference_detail_count"] = game.world.get_meta("reference_detail_count", 0)
	manifest["track_length"] = game.track_length
	manifest["accepted_sites"] = []
	var expected_low := detail == "low"
	var expected_profile := "low" if expected_low else "high"
	if (
		game.world.low_detail != expected_low
		or game.lightweight != expected_low
		or game.graphics_profile != expected_profile
	):
		await _finish(
			1,
			(
				"Production detail/profile mismatch: requested="
				+ detail
				+ " actual="
				+ str(manifest["actual_detail"])
				+ " profile="
				+ str(game.graphics_profile)
				+ " lightweight="
				+ str(game.lightweight)
			)
		)
		return
	for site in sites:
		(
			manifest["accepted_sites"]
			. append(
				{
					"position": _vector(site["position"]),
					"radius": site["radius"],
					"distance": site["distance"],
				}
			)
		)
	if sites.is_empty():
		await _finish(
			1, "No accepted reference_detail_sites for track=" + track_id + " detail=" + detail
		)
		return
	if (
		theme != track_id
		or game.track_length <= 0.0
		or int(manifest["reference_detail_count"]) <= 0
	):
		await _finish(1, "Production theme metadata or track length is invalid")
		return
	if site_index >= sites.size():
		await _finish(1, "--site is outside the accepted-site list; count=" + str(sites.size()))
		return
	var selected: Dictionary = sites[site_index]
	var at: Vector3 = selected["position"]
	var distance: float = selected["distance"]
	var radius: float = selected["radius"]
	var road: Vector3 = game.world.position_at(distance)
	var toward_road := Vector3(road.x - at.x, 0.0, road.z - at.z)
	if toward_road.length_squared() < 0.0001:
		await _finish(1, "Selected site has no usable road-facing direction")
		return
	var approach: float = fposmod(distance - 12.0, game.track_length)
	game.distance = approach
	game.previous_road_distance = approach
	game.lane = 0.0
	game.checkpoint_index = int(floor(approach / (game.track_length / 8.0)))
	game.player.transform = game.world.reset_transform(approach, 0.0)
	game.player_heading = game._heading(approach)
	game._update_camera(1.0, true)
	game._update_hud()
	problem = await _save_view(
		"01_chase", "production _update_camera; stationary player placed 12 m before accepted site"
	)
	if not problem.is_empty():
		await _finish(1, problem)
		return
	game.camera.position = game.world.position_at(distance - 8.0) + Vector3.UP * 5.0
	game.camera.look_at(at + Vector3.UP * 2.0)
	problem = await _save_view(
		"02_context", "manual road-context pose; production camera, world and lighting"
	)
	if not problem.is_empty():
		await _finish(1, problem)
		return
	game.camera.position = (
		at + toward_road.normalized() * maxf(6.0, radius * 2.5) + Vector3.UP * maxf(3.0, radius)
	)
	game.camera.look_at(at + Vector3.UP * 1.5)
	problem = await _save_view(
		"03_detail", "manual road-facing detail pose; production camera, world and lighting"
	)
	if not problem.is_empty():
		await _finish(1, problem)
		return
	manifest["status"] = "captured"
	await _finish(0)
