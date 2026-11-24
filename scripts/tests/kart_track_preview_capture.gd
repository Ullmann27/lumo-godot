extends SceneTree
## Renders the small course pictures of the Kart menu from the real courses.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/kart_track_preview_capture.gd -- --out=<dir> [--all | --track=<id>] [--spots=0.03,0.35]
##
## Writes <id>_<n>.png (640x360) per course and spot; the chosen picture is saved as
## assets/kart/neon_previews/<id>.webp. Without --all only courses without a picture.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := ""
	var all := false
	var track := ""
	var spots: Array[float] = [0.03, 0.35]
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--out="):
			out = text.trim_prefix("--out=")
		elif text.begins_with("--track="):
			track = text.trim_prefix("--track=")
		elif text == "--all":
			all = true
		elif text.begins_with("--spots="):
			spots.clear()
			for part in text.trim_prefix("--spots=").split(","):
				spots.append(float(part))
	if out.is_empty():
		push_error("[TrackPreview] --out=<dir> fehlt")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var done := 0
	for entry in CATALOG.TRACKS:
		var id := str(entry.id)
		if not track.is_empty() and track != id:
			continue
		if track.is_empty() and not all and ResourceLoader.exists("res://assets/kart/neon_previews/%s.webp" % id):
			continue
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, id, false)
		for _frame in range(4):
			await process_frame
		var camera := Camera3D.new()
		camera.fov = 62.0
		camera.far = 900.0
		world.add_child(camera)
		camera.current = true
		for index in range(spots.size()):
			var d: float = float(world.length) * spots[index]
			var eye: Vector3 = world.position_at(d - 8.0, 0.0) + Vector3.UP * 3.4
			var look: Vector3 = world.position_at(d + 22.0, 0.0) + Vector3.UP * 1.2
			camera.look_at_from_position(eye, look, Vector3.UP)
			for _frame in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			if image.save_png(out.path_join("%s_%d.png" % [id, index])) != OK:
				quit(1)
				return
		print("[TrackPreview] %s (%.0f m)" % [id, float(world.length)])
		done += 1
		root.remove_child(world)
		world.queue_free()
		await process_frame
		await process_frame
	if not track.is_empty() and done == 0:
		push_error("Unbekannte Strecke: " + track)
		quit(1)
		return
	print("[TrackPreview] PASS: %d Strecken" % done)
	quit(0)
