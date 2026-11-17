extends SceneTree
## Actual Godot renderer evidence of the shipped Lumo Meshy GLB at Sonnenhafen's start.
## Five in-engine views, including both foot/ground contacts. No image compositing.
const WORLD = preload("res://scripts/games/kart_world.gd")
const OUTPUT_DIR := "res://artifacts/meshy-start-gate"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen", false)
	if not world.has_node("LumoKartMeshyStartFinishGate"):
		printerr("[MeshyGateRender] missing actual 3D GLB arch")
		quit(1)
		return
	var at: Vector3 = world.position_at(0.0)
	var basis: Basis = world.frame(0.0)
	var camera := Camera3D.new()
	camera.name = "LumoMeshyGateAuditCamera"
	camera.fov = 67.0
	camera.near = 0.08
	camera.far = 1200.0
	root.add_child(camera)
	camera.current = true
	var views := [
		{"id": "front", "eye": Vector3(0.0, 6.0, 23.0), "focus": Vector3(0.0, 5.7, 0.0)},
		{"id": "front_three_quarter", "eye": Vector3(11.0, 8.0, 22.0), "focus": Vector3(0.0, 5.7, 0.0)},
		{"id": "back", "eye": Vector3(0.0, 6.0, -20.0), "focus": Vector3(0.0, 5.5, 0.0)},
		{"id": "left_foot", "eye": Vector3(-19.0, 2.7, 10.0), "focus": Vector3(-11.0, 0.1, 0.0)},
		{"id": "right_foot", "eye": Vector3(19.0, 2.7, 10.0), "focus": Vector3(11.0, 0.1, 0.0)},
	]
	var output_directory: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_directory)
	for view in views:
		# Local -Z follows the race direction; local +Z sees the front of the arch.
		camera.global_position = at + basis * (view.eye as Vector3)
		camera.look_at(at + basis * (view.focus as Vector3))
		for frame in range(24):
			await process_frame
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty():
			printerr("[MeshyGateRender] empty framebuffer: ", view.id)
			quit(1)
			return
		if image.get_width() != 1280 or image.get_height() != 720:
			printerr("[MeshyGateRender] incorrect dimensions: ", view.id)
			quit(1)
			return
		var path: String = output_directory.path_join(str(view.id) + ".png")
		if image.save_png(path) != OK:
			printerr("[MeshyGateRender] unable to save: ", path)
			quit(1)
			return
		print("[MeshyGateRender] captured actual 1280x720 ", view.id, ": ", path)
	print("[MeshyGateRender] PASS: actual GLB rendered from 5 camera positions including grounded feet")
	quit(0)
