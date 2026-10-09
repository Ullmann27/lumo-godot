extends SceneTree
## Reproducible Flutter pose atlas from the exact original Kart character mesh.
## 8 columns × 9 rows, 384px cells. Alpha is produced by the Godot viewport.

const CELL: int = 384
const COLUMNS: int = 8
const ROWS: int = 9
const RaceKart = preload("res://scripts/games/kart_vehicle.gd")

var companion: Node3D


func _initialize() -> void:
	call_deferred("_export_atlas")


func _export_atlas() -> void:
	root.size = Vector2i(CELL, CELL)
	root.transparent_bg = true
	root.msaa_3d = Viewport.MSAA_4X
	var studio := Node3D.new()
	root.add_child(studio)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c2dfff")
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	studio.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -35, 0)
	key.light_color = Color("fff0de")
	key.light_energy = 0.95
	studio.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_color = Color("76d9ff")
	fill.light_energy = 0.35
	studio.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.35
	camera.position = Vector3(2.4, 2.3, -6)
	studio.add_child(camera)
	camera.look_at(Vector3(0, 1.18, 0))
	companion = RaceKart.new()
	companion.configure_companion("fox")
	studio.add_child(companion)
	companion.set_process(false)
	var atlas := Image.create(CELL * COLUMNS, CELL * ROWS, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for warmup in range(8):
		await process_frame
	for frame in range(COLUMNS * ROWS):
		var mood: String = "idle"
		var time: float = float(frame) / 8.0
		var mouth: float = 0.0
		if frame >= 64:
			mood = "walk"
			time = float(frame - 64) / 8.0
		elif frame >= 56:
			mood = "help"
			time = float(frame - 56) / 8.0
		elif frame >= 48:
			mood = "think"
			time = float(frame - 48) / 8.0
		elif frame >= 40:
			mood = "cheer"
			time = float(frame - 40) / 8.0
		elif frame >= 32:
			mood = "speaking"
			time = float(frame - 32) / 8.0
			mouth = sin(float(frame - 32) / 7.0 * PI)
		companion.set_companion_pose(time, mood, mouth)
		await process_frame
		await RenderingServer.frame_post_draw
		var pose: Image = root.get_texture().get_image()
		pose.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(pose, Rect2i(0, 0, CELL, CELL), Vector2i((frame % COLUMNS) * CELL, (frame / COLUMNS) * CELL))
		if frame in [0, 40, 48, 56, 64]:
			DirAccess.make_dir_recursive_absolute("res://exports/companion")
			pose.save_png("res://exports/companion/pose_%02d.png" % frame)
	DirAccess.make_dir_recursive_absolute("res://exports/companion")
	var error := atlas.save_png("res://exports/companion/lumo_holographic_atlas.png")
	if error != OK:
		push_error("Could not write character atlas: %s" % error)
		quit(1)
		return
	# The Android launcher uses a second real render of this same character.
	root.size = Vector2i(512, 512)
	root.transparent_bg = false
	env.background_color = Color("071226")
	camera.size = 1.62
	camera.position = Vector3(0.9, 1.9, -6)
	camera.look_at(Vector3(0, 1.72, 0))
	companion.set_companion_pose(0, "idle", 0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://exports/companion/lumo_app_icon.png")
	print("[LumoAtlas] 72 real 3D poses exported at 384px; original shared Kart mesh; alpha retained")
	quit(0)
