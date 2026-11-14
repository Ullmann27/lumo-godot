extends SceneTree
## Capture real existing game scenes. These are renderer originals, not concept art.
const SCENES := {
	"hub": "res://scenes/games/game_hub.tscn",
	"treasure": "res://scenes/creative/treasure_world.tscn",
	"build": "res://scenes/creative/build_world.tscn",
	"puzzle": "res://scenes/creative/puzzle_world.tscn",
	"rhythm": "res://scenes/creative/rhythm_world.tscn",
	"jump": "res://scenes/games/jump_islands.tscn",
	"learning": "res://scenes/learning/learning_world.tscn",
}
var _scene_id: String = "treasure"
var _output: String = "user://dream_ambience_capture"


func _initialize() -> void:
	call_deferred("_run")


func _find_ambience(node: Node) -> Node:
	if node is LumoDreamAmbience:
		return node
	for child in node.get_children():
		var found: Node = _find_ambience(child)
		if found != null:
			return found
	return null


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			_scene_id = argument.trim_prefix("--world=")
		elif argument.begins_with("--capture-dir="):
			_output = argument.trim_prefix("--capture-dir=")
	if not SCENES.has(_scene_id) or DisplayServer.get_name() == "headless":
		push_error("[DreamAmbienceCapture] known world and a real display are required")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(_output)
	if DirAccess.make_dir_recursive_absolute(output_path) != OK:
		push_error("[DreamAmbienceCapture] cannot create output directory")
		quit(1)
		return
	await process_frame
	await process_frame
	root.get_node("SceneRouter").set("launch_options", {
		"childKey": "dream_ambience_capture", "grade": 1, "subject": "Mathematik",
		"reduceAnimations": false,
	})
	var packed := load(str(SCENES[_scene_id])) as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	current_scene = world
	root.get_node("PerformanceManager").call("set_profile", 2, false)
	await create_timer(0.6).timeout
	var ambience := _find_ambience(world) as LumoDreamAmbience
	if ambience == null:
		push_error("[DreamAmbienceCapture] production scene does not attach ambient geometry")
		world.queue_free()
		await process_frame
		quit(1)
		return
	var frames: Array[Dictionary] = []
	for index in range(2):
		await RenderingServer.frame_post_draw
		var rendered: Image = root.get_texture().get_image()
		var path := output_path.path_join("%s_%02d.png" % [_scene_id, index])
		if rendered == null or rendered.is_empty() or rendered.save_png(path) != OK:
			push_error("[DreamAmbienceCapture] renderer image could not be saved")
			world.queue_free()
			await process_frame
			quit(1)
			return
		frames.append({
			"path": path, "width": rendered.get_width(), "height": rendered.get_height(),
			"ambience": ambience.render_state(),
		})
		if index == 0:
			await create_timer(1.8).timeout
	var report := FileAccess.open(output_path.path_join(_scene_id + ".json"), FileAccess.WRITE)
	if report == null:
		push_error("[DreamAmbienceCapture] could not save capture report")
		world.queue_free()
		await process_frame
		quit(1)
		return
	report.store_string(JSON.stringify({
		"scene": SCENES[_scene_id],
		"display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"frames": frames,
		"device_fps_measured": false,
	}, "\t"))
	report.close()
	world.queue_free()
	await process_frame
	await process_frame
	print("[DreamAmbienceCapture] PASS " + _scene_id + " original frames in " + output_path)
	quit(0)
