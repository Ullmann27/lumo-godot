extends SceneTree
## GPU framebuffer oracle for the real tunnel shell's interior face winding.
## Hiding the shell is a negative control; external cover cannot mask a culled vault.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
var output: String = "user://adventure-winding"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--output="):
			output = str(arg).trim_prefix("--output=")
	call_deferred("_run")


func _read_frame() -> Image:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _background_fraction(frame: Image) -> float:
	var clear_pixels: int = 0
	var checked: int = 0
	for y in range(8, frame.get_height() - 8, 2):
		for x in range(8, frame.get_width() - 8, 2):
			var color: Color = frame.get_pixel(x, y)
			if color.g > 0.85 and color.r < 0.08 and color.b < 0.08:
				clear_pixels += 1
			checked += 1
	return float(clear_pixels) / checked


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Face visibility requires a real rasterizer")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(400, 300)
	root.msaa_3d = Viewport.MSAA_DISABLED
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 1.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.85
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var camera := Camera3D.new()
	camera.fov = 55.0
	stage.add_child(camera)
	camera.make_current()
	for low in [true, false]:
		var world = WORLD.new()
		stage.add_child(world)
		world.low_detail = low
		world.track_id = "crystal_canyon"
		world.definition = TRACKS.definition(world.track_id)
		world._make_curve()
		TUNNELS.build(world)
		var passage: Node3D = world.get_node("AdventureTunnel")
		var shell: MeshInstance3D = passage.get_node("ContinuousInnerVault")
		for node: Node3D in passage.get_children():
			node.visible = node == shell
		var span: Dictionary = world.adventure_tunnel
		var label: String = "low" if low else "high"
		for sample in range(3):
			var distance: float = lerpf(float(span.start_m) + 55.0, float(span.end_m) - 55.0, float(sample) / 2.0)
			var eye: Vector3 = world.position_at(distance) + world.frame(distance).y * 3.0
			var aim: Vector3 = world.position_at(distance + 8.0) + world.frame(distance + 8.0).y * 8.0
			camera.look_at_from_position(eye, aim)
			shell.visible = true
			var frame: Image = await _read_frame()
			var clear_fraction: float = _background_fraction(frame)
			assert(frame.save_png(output.path_join("inside-%s-%d.png" % [label, sample])) == OK)
			assert(clear_fraction < 0.15, "Actual inner roof is backface-culled: %s/%d background=%.3f" % [label, sample, clear_fraction])
			shell.visible = false
			var negative: Image = await _read_frame()
			var negative_fraction: float = _background_fraction(negative)
			assert(negative_fraction > 0.98, "Negative control does not observe the background")
			print("[KartAdventureWinding] ", label, " sample=", sample, " interior_background=", snappedf(clear_fraction, 0.001), " hidden_background=", snappedf(negative_fraction, 0.001))
		world.free()
		await process_frame
	stage.free()
	await process_frame
	print("[KartAdventureWinding] PASS: six actual interior framebuffer views, active culling, six negative controls")
	quit(0)
