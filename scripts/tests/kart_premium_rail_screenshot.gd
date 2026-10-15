extends SceneTree
## Actual Godot renderer screenshot of the first Sonnenhafen rail section.
## No synthetic UI overlays or AI-created screenshots.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world.build(false, "sonnenhafen", false)
	var distance: float = world.length * 0.09
	var road_basis: Basis = world.frame(distance)
	var camera := Camera3D.new()
	camera.name = "RailReviewCamera"
	camera.fov = 68.0
	camera.far = 2500.0
	root.add_child(camera)
	camera.global_position = world.position_at(distance) + road_basis.y * 4.0 + road_basis.z * 10.0
	camera.look_at(world.position_at(distance + 23.0) + Vector3.UP * 0.9)
	camera.current = true

	# Wait for scene tree to draw the real shading, light and geometry.
	for i in range(15):
		await process_frame
	var screenshot: Image = root.get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		printerr("[RailScreenshot] FAILED empty renderer frame")
		quit(1)
		return
	var output := ProjectSettings.globalize_path("res://artifacts/rail_sonnenhafen_actual.png")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result: Error = screenshot.save_png(output)
	if result != OK:
		printerr("[RailScreenshot] FAILED PNG save=", result)
		quit(1)
		return
	print("[RailScreenshot] PASS real Godot 4.6.3 1280x720 renderer output: ", output)
	quit(0)
