extends SceneTree
## Bilder einer Signatur-Strecke mit echtem Renderer (Team B1): Fahrerblick an
## Streckenmetern und eine Überflugsicht. Misst auch die Bauzeit der Welt.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/kart_signature_capture.gd -- --track=<id> --out=<dir> \
##     [--at=100,350,920] [--size=1280x720] [--profile=low|medium|high] [--aerial] [--eruption=4]
const SIGNATURE = preload("res://scripts/games/kart_signature/kart_signature_tracks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var track: String = SIGNATURE.IDS[0]
	var out := ""
	var spots: Array[float] = [60.0, 300.0, 700.0, 920.0, 1200.0, 1460.0, 2000.0, 2236.0]
	var size := Vector2i(1280, 720)
	var profile := "medium"
	var aerial := false
	var eruption := -1.0
	var target := Vector3.INF
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--track="):
			track = text.trim_prefix("--track=")
		elif text.begins_with("--out="):
			out = text.trim_prefix("--out=")
		elif text.begins_with("--at="):
			spots.clear()
			for part in text.trim_prefix("--at=").split(","):
				spots.append(float(part))
		elif text.begins_with("--size="):
			var wh: PackedStringArray = text.trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif text.begins_with("--profile="):
			profile = text.trim_prefix("--profile=")
		elif text == "--aerial":
			aerial = true
		elif text.begins_with("--look="):
			var xyz: PackedStringArray = text.trim_prefix("--look=").split(",")
			target = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		elif text.begins_with("--eruption="):
			eruption = float(text.trim_prefix("--eruption="))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = size
	LumoQuality.set_tier(profile)
	var started := Time.get_ticks_msec()
	var world = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world.build(profile == "low", track, false)
	print(
		(
			"[SignatureCapture] %s gebaut in %d ms (%s)"
			% [track, Time.get_ticks_msec() - started, profile]
		)
	)
	var scenery = world.get_node_or_null("SignatureEnvironment")
	if scenery != null and eruption >= 0.0 and scenery.has_method("_show_eruption"):
		scenery.eruption_count = 1
		scenery._show_eruption(eruption)
	var camera := Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.1
	camera.far = float(LumoQuality.budget(profile).camera_far)
	world.add_child(camera)
	camera.current = true
	for _frame in range(4):
		await process_frame
	for d in spots:
		var basis: Basis = world.frame(d)
		var eye: Vector3 = world.position_at(d - 9.0) + basis.y * 3.6
		var look: Vector3 = world.position_at(d + 18.0) + world.frame(d + 18.0).y * 1.4
		if aerial:
			eye = world.position_at(d - 60.0, 40.0) + Vector3.UP * 70.0
			look = world.position_at(d + 40.0)
			camera.far = 1400.0
		if target != Vector3.INF:
			look = target
		camera.look_at_from_position(
			world.clip_tunnel_camera(world.position_at(d), eye), look, Vector3.UP
		)
		for _frame in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		var name := "%s_%s_%04d%s.jpg" % [track, profile, int(d), "_luft" if aerial else ""]
		image.save_jpg(out.path_join(name), 0.86)
		print("[SignatureCapture] ", name)
	var draws: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	print("[SignatureCapture] PASS Draw-Calls im letzten Bild: %d" % draws)
	quit(0)
