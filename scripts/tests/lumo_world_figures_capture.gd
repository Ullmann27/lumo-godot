extends SceneTree
## Bildfolgen der Welt-Figuren (NPCs) im echten Renderer: Stand, Gehen, Gesten,
## Gesicht/Textur aus der Nähe. Nur Sichtprüfung, keine Spielstände außer Testprofil.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##   --script res://scripts/tests/lumo_world_figures_capture.gd -- --out=<ordner> [--ids=lion,owl]

const PROFILE := "lumo_b2_world_figures_capture"
var out_dir := "user://world_figures"
var ids: Array[String] = ["lion", "owl", "turtle", "cat"]
var frames := 6
var cell := Vector2i(540, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--ids="):
			ids.assign(arg.trim_prefix("--ids=").split(",", false))
	_run.call_deferred()


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world_path := "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	root.size = cell
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": false}
	router.goto("world")
	await _frames(90)
	var scene: Node = current_scene
	if scene == null or not scene.has_method("_close_dialog"):
		push_error("World did not open")
		quit(1)
		return
	var layer: Node = scene.open_world
	for layer_node in scene.find_children("*", "CanvasLayer", true, false):
		(layer_node as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 34.0
	scene.add_child(camera)
	var report: Dictionary = {}
	for id in ids:
		if not layer.figures.has(id):
			continue
		var figure: Node3D = layer.figures[id]
		scene.player.position = figure.global_position + Vector3(0, 0.15, 3.2)
		scene.player.velocity = Vector3.ZERO
		scene.last_safe = scene.player.position
		await _frames(30)
		var sheet := Image.create(cell.x * frames, cell.y * 2, false, Image.FORMAT_RGB8)
		var path: Array[Vector3] = []
		for row in range(2):
			for column in range(frames):
				await _frames(14)
				var model := figure.get_node("OriginalRosterModel") as Node3D
				var height := 2.05
				var target := (
					figure.global_position + Vector3.UP * height * (0.5 if row == 0 else 0.8)
				)
				# Row 1: from the side, whole figure (feet on the ground); row 2: face.
				var away := figure.global_basis.z.normalized()
				var side := figure.global_basis.x.normalized()
				var eye := (
					target
					+ (side * 7.0 + Vector3.UP * 0.8 if row == 0 else away * 2.6 + Vector3.UP * 0.2)
				)
				camera.look_at_from_position(eye, target)
				camera.make_current()
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				image.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(
					image, Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, row * cell.y)
				)
				path.append(figure.global_position)
				if model == null:
					continue
		var player: AnimationPlayer = layer.figure_players.get(id)
		report[id] = {
			"clip": str(player.current_animation) if player != null else "",
			"speed_scale": player.speed_scale if player != null else 0.0,
			"moved_m": path[0].distance_to(path[path.size() - 1]),
			"walk_clip": str(layer.figure_walk_clips.get(id, ""))
		}
		sheet.save_jpg(out_dir.path_join(id + ".jpg"), 0.88)
	print("[WorldFigures] ", JSON.stringify(report))
	quit(0)
