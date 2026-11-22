extends SceneTree
## Schnellansicht der Welt Wolkenhafen (ohne Spielregeln): baut die Welt, setzt
## Lumos Flieger an einen Ort und speichert ein Bild je Kamera.
## -- out=<ordner> size=WxH profile=medium views=deck,overview,district

var out_dir: String = "user://"
var size := Vector2i(906, 1088)
var profile: String = "medium"
var views: PackedStringArray = ["deck", "overview", "district"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"out":
				out_dir = pair[1]
			"size":
				var wh: PackedStringArray = pair[1].split("x")
				size = Vector2i(int(wh[0]), int(wh[1]))
			"profile":
				profile = pair[1]
			"views":
				views = pair[1].split(",")
	call_deferred("_run")


func _run() -> void:
	root.size = size
	DisplayServer.window_set_size(size)
	var started: int = Time.get_ticks_msec()
	var world = load("res://scripts/games/skypost/sky_post_world.gd").new()
	root.add_child(world)
	world.build_all(profile, false)
	print(
		(
			"[probe] world built in %d ms (steps %d ms)"
			% [Time.get_ticks_msec() - started, world.build_ms]
		)
	)
	var glider = load("res://scripts/games/skypost/sky_post_glider.gd").new()
	root.add_child(glider)
	glider.build("hero", Color("f3efe4"), Color("2c6fe0"), false)
	print("[probe] lumo seated: ", glider.seat_pilot("lumo"))
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 1500.0
	root.add_child(camera)
	camera.current = true
	var layout = world.layout
	for view in views:
		var deck: Vector3 = layout.post_deck.pos
		match view:
			"deck":
				glider.global_transform = Transform3D(Basis(), layout.start_at + Vector3(0, 0, 4))
				camera.look_at_from_position(
					glider.global_position + Vector3(-5.5, 2.6, -6.5),
					glider.global_position + Vector3(0, 1.0, 0)
				)
			"chase":
				glider.global_transform = Transform3D(
					Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, -0.25), Vector3(30, 22, -60)
				)
				var back: Vector3 = glider.global_transform.basis.z
				camera.look_at_from_position(
					glider.global_position + back * 9.0 + Vector3(0, 3.2, 0),
					glider.global_position + Vector3(0, 1, 0) - back * 6.0
				)
			"overview":
				glider.global_transform = Transform3D(Basis(), Vector3(0, 30, -50))
				camera.look_at_from_position(Vector3(150, 90, 160), Vector3(0, 0, -30))
			"district":
				var centre: Vector3 = layout.district_centre(0)
				glider.global_transform = Transform3D(
					Basis(Vector3.UP, 2.0), centre + Vector3(-20, 14, -10)
				)
				camera.look_at_from_position(
					centre + Vector3(-34, 20, -22), centre + Vector3(0, 2, 0)
				)
				for house in layout.district_houses(0):
					world.set_board(
						world.house_index(0, int(house.slot)), str(7 + int(house.slot)), true
					)
			"lighthouse":
				var centre: Vector3 = layout.district_centre(1)
				glider.global_transform = Transform3D(
					Basis(Vector3.UP, 2.4), centre + Vector3(-30, 20, 20)
				)
				camera.look_at_from_position(
					centre + Vector3(-48, 22, 36), centre + Vector3(0, 10, 0)
				)
				world.set_board(world.house_index(1, 0), "clock:2:30", true)
				world.set_board(world.house_index(1, 1), "laufen", true)
			"mill":
				var centre: Vector3 = layout.district_centre(3)
				glider.global_transform = Transform3D(
					Basis(Vector3.UP, -2.2), centre + Vector3(30, 18, 30)
				)
				camera.look_at_from_position(
					centre + Vector3(46, 24, 40), centre + Vector3(0, 8, 0)
				)
		for index in range(8):
			world.advance(1.0 / 30.0, camera.global_position)
			glider.animate(1.0 / 30.0, Vector2(0.3, 0.1), 14.0, false)
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image != null:
			var path: String = out_dir.path_join("probe_%s.png" % view)
			image.save_png(path)
			print("[probe] saved ", path)
	quit()
