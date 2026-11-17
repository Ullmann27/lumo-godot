extends SceneTree
## Before/after evidence for the Lumo track kit: one real chase-camera frame per
## track (actual race state and HUD, no mock values) plus render metrics.
## Run with real GL under xvfb, e.g.:
##   xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
##     --script res://scripts/tests/kart_track_kit_capture.gd -- --out=res://exports/kit --tag=after
## Optional: --tracks=a,b  --size=1280x720  --views=chase|sonnenhafen|reference  --metrics=1
## Frame times measured here are xvfb/llvmpipe wall-clock numbers: relative only, not device FPS.

const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TUNNEL_FRACTION: float = 0.690
const LOOP_LEAD_M: float = 108.0
## Representative chase-camera position per track (fraction of the lap, lane).
## Chosen just before a boost pad / setpiece so each world's signature reads.
const CHASE_VIEWS: Dictionary = {
	"sonnenhafen": [0.385, 0.0],
	"zauberwald": [0.385, 0.0],
	"bergwelt": [0.385, 0.0],
	"holo_city": [0.385, 0.0],
	"crystal_canyon": [0.385, 0.0],
	"jungle_temple": [0.385, 0.0],
	"candy_cloud": [0.385, 0.0],
	"volcano_night": [0.385, 0.0],
	"winter_sprint": [0.385, 0.0],
	"galaxy_ringway": [0.385, 0.0],
	"desert_drift": [0.385, 0.0],
	"learning_lab": [0.385, 0.0],
}
## Additional Sonnenhafen views: start straight, coastal waterfall, viaduct.
const SONNENHAFEN_EXTRA: Array = [
	["start", 0.012, 0.0],
	["waterfall", 0.555, 0.0],
	["viaduct", 0.27, 0.0],
]

var game
var out_dir: String = "res://exports/track-kit"
var tag: String = "before"
var size := Vector2i(1280, 720)
var only_tracks: Array[String] = []
var views: String = "chase"
var collect_metrics: bool = true
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _args() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			out_dir = text.trim_prefix("--out=")
		elif text.begins_with("--tag="):
			tag = text.trim_prefix("--tag=")
		elif text.begins_with("--tracks="):
			for id in text.trim_prefix("--tracks=").split(",", false):
				only_tracks.append(str(id))
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--views="):
			views = text.trim_prefix("--views=")
		elif text.begins_with("--metrics="):
			collect_metrics = text.trim_prefix("--metrics=") != "0"


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _start(track: String) -> void:
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "gemuetlich"
		}
	)
	game._end_preview()
	game.set_physics_process(false)
	game.countdown = 0
	game.racing = true
	game.modal.hide()


func _place(fraction: float, lane: float, drive_steps: int) -> void:
	var length: float = game.track_length
	var d: float = fraction * length
	game.distance = d
	game.previous_road_distance = fposmod(d, length)
	game.lane = lane
	game.checkpoint_index = int(floor(d / (length / 8.0)))
	game.player.transform = game.world.reset_transform(d, lane)
	game.player_heading = game._heading(d)
	game.speed = 0.0
	game.gas_held = true
	game._update_camera(1.0, true)
	# Real game physics, stepped deterministically: speed/HUD values are actual state.
	for _i in range(drive_steps):
		game._physics_process(1.0 / 60.0)


func _save(name: String) -> String:
	await _frames(3)
	if DisplayServer.get_name() == "headless":
		return ""
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(tag + "-" + name + ".jpg")
	assert(image.save_jpg(path, 0.85) == OK)
	print("[TrackKitCapture] saved ", path)
	return path


## Stunt sequence 108 m before the crystal tunnel (Position A). Works on the
## base too: there the same road positions simply have no loop yet.
func _stunt_views() -> void:
	var length: float = game.track_length
	var tunnel: float = length * TUNNEL_FRACTION
	var loop_start: float = tunnel - LOOP_LEAD_M
	var lane: float = 2.6
	_place_at(loop_start - 150.0, 0.0, 70)
	await _save("stunt-01-distant")
	_place_at(loop_start - 40.0, lane, 50)
	await _save("stunt-02-approach")
	# Drive for real from the pad into the loop and grab the riding frames.
	_place_at(loop_start - 30.0, lane, 0)
	game.speed = 18.0
	var shots: Array = [[0.12, "stunt-03-entry"], [0.5, "stunt-04-top"], [0.82, "stunt-05-descent"]]
	var shot: int = 0
	for _i in range(400):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, lane)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
		)
		game._physics_process(1.0 / 60.0)
		if not game.world.loop_layout.is_empty() and game.loop_state.active:
			game.steering = 0.0
			if shot < shots.size() and game.loop_state.progress >= float(shots[shot][0]):
				await _save(str(shots[shot][1]))
				shot += 1
		elif shot > 0:
			break
	for _i in range(20):
		game._physics_process(1.0 / 60.0)
	await _save("stunt-06-exit")
	# Onward over the Position B jump: grab the frame near the top of the arc.
	var air_frames: int = 0
	for _i in range(300):
		var ahead: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, 0.0)
		var heading: Vector3 = ahead - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-heading.x, -heading.z)) * 2.3, -1, 1
		)
		game._physics_process(1.0 / 60.0)
		if game.airborne:
			air_frames += 1
			if air_frames == 34:
				await _save("stunt-07-jump-flight")
		elif air_frames > 0:
			break
	_place_at(tunnel - 30.0, 0.0, 60)
	await _save("stunt-08-tunnel-mouth")


func _place_at(distance_m: float, lane: float, drive_steps: int) -> void:
	_place(distance_m / game.track_length, lane, drive_steps)


func _metrics(track: String) -> Dictionary:
	var meshes: int = 0
	var multimeshes: int = 0
	var instances: int = 0
	var stack: Array[Node] = [game.world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes += 1
		elif node is MultiMeshInstance3D:
			multimeshes += 1
			if node.multimesh != null:
				instances += node.multimesh.instance_count
		for child in node.get_children():
			stack.append(child)
	var result := {
		"track": track,
		"length_m": snappedf(float(game.track_length), 0.1),
		"mesh_instances": meshes,
		"multimesh_nodes": multimeshes,
		"multimesh_instances": instances,
		"decoration_count": int(game.world.decoration_count),
	}
	if DisplayServer.get_name() != "headless":
		var samples: Array[float] = []
		var last := Time.get_ticks_usec()
		for _i in range(12):
			game._physics_process(1.0 / 60.0)
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - last) / 1000.0)
			last = now
		samples.sort()
		result["xvfb_frame_ms_median"] = snappedf(samples[samples.size() / 2], 0.1)
		result["draw_calls"] = int(
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		)
		result["objects"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		result["primitives"] = int(
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		)
	return result


func _run() -> void:
	_args()
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = size
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _frames(4)
	root.size = size
	var ids: Array[String] = []
	for id in TRACKS.IDS:
		if only_tracks.is_empty() or id in only_tracks:
			ids.append(id)
	var metrics: Array = []
	for track in ids:
		var started := Time.get_ticks_msec()
		_start(track)
		var build_ms := Time.get_ticks_msec() - started
		await _frames(2)
		if views in ["chase", "all"]:
			var spec: Array = CHASE_VIEWS.get(track, [0.385, 0.0])
			_place(float(spec[0]), float(spec[1]), 75)
			await _save("%02d-%s" % [TRACKS.IDS.find(track) + 1, track])
		if track == "sonnenhafen" and views in ["sonnenhafen", "all"]:
			for extra in SONNENHAFEN_EXTRA:
				_place(float(extra[1]), float(extra[2]), 75)
				await _save("sonnenhafen-" + str(extra[0]))
		if track == "sonnenhafen" and views in ["stunt", "all"]:
			await _stunt_views()
		if track == "sonnenhafen" and views in ["reference", "all"]:
			_place(0.385, 0.0, 70)
			game._boost()
			for _i in range(20):
				game._physics_process(1.0 / 60.0)
			await _save("sonnenhafen-reference-match")
		if collect_metrics:
			var entry: Dictionary = await _metrics(track)
			entry["build_ms"] = build_ms
			metrics.append(entry)
			print("[TrackKitMetrics] ", JSON.stringify(entry))
	report = {
		"tag": tag,
		"size": [size.x, size.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"tracks": metrics
	}
	var file := FileAccess.open(out_dir.path_join(tag + "-metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("[TrackKitCapture] done tracks=", ids.size())
	quit(0)
