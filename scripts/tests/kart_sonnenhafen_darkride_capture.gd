extends SceneTree
## Three genuine Godot 4.6.3 GPU frame captures of the generated first dark ride.
const WORLD = preload("res://scripts/games/kart_world.gd")
const RIDE = preload("res://scripts/games/kart_sonnenhafen_darkride.gd")
const OUTPUT: String = "res://artifacts/sonnenhafen-darkride"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen", false)
	assert(world.has_node("SonnenhafenBioluminescentDarkride"))
	var cave: MeshInstance3D = world.get_node("SonnenhafenBioluminescentDarkride/DarkrideRockAndCanopy")
	var cave_material: ShaderMaterial = cave.material_override
	var info: Dictionary = world.get_meta("sonnenhafen_darkride")
	var start_m: float = float(info["start_m"])
	var end_m: float = float(info["end_m"])
	var camera := Camera3D.new()
	camera.fov = 73.0
	camera.near = 0.08
	camera.far = 450.0
	root.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var views: Array[Dictionary] = [
		{"name": "entrance", "distance": start_m - 23.0, "height": 3.2, "look": start_m + 27.0},
		{"name": "deep_neon", "distance": start_m + (end_m - start_m) * 0.42, "height": 2.2,
		 "look": start_m + (end_m - start_m) * 0.42 + 26.0},
		{"name": "exit", "distance": end_m - 35.0, "height": 2.9, "look": end_m + 12.0}
	]
	for view in views:
		var d: float = float(view["distance"])
		var ahead: float = float(view["look"])
		camera.global_position = world.position_at(d) + world.frame(d).y * float(view["height"])
		camera.look_at(world.position_at(ahead) + world.frame(ahead).y * 2.7)
		var flat_reference: Image = null
		if str(view.name) == "deep_neon":
			cave_material.set_shader_parameter("rock_detail_strength", 0.0)
			for _baseline_frame in range(26):
				await process_frame
			await RenderingServer.frame_post_draw
			flat_reference = root.get_texture().get_image()
			assert(flat_reference != null and not flat_reference.is_empty())
			var baseline_path: String = ProjectSettings.globalize_path(OUTPUT).path_join("deep_neon_flat_baseline.png")
			assert(flat_reference.save_png(baseline_path) == OK)
			cave_material.set_shader_parameter("rock_detail_strength", 1.0)
		for _frame in range(26):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img == null or img.is_empty() or img.get_width() != 1280 or img.get_height() != 720:
			printerr("[DarkrideRender] Invalid real GPU frame for ", view.name)
			quit(1)
			return
		var file: String = ProjectSettings.globalize_path(OUTPUT).path_join(str(view.name) + ".png")
		if img.save_png(file) != OK:
			printerr("[DarkrideRender] Could not save ", file)
			quit(1)
			return
		print("[DarkrideRender] real 1280x720: ", file)
		if flat_reference != null:
			var altered_pixels: int = 0
			for py in range(64, 400, 8):
				for px in range(64, 1216, 8):
					var before: Color = flat_reference.get_pixel(px, py)
					var after: Color = img.get_pixel(px, py)
					var difference: float = absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)
					if difference > 0.025:
						altered_pixels += 1
			assert(altered_pixels > 120, "Mineral strata must visibly affect the real cave camera")
			print("[DarkrideArtPass] PASS: same-camera real GPU baseline/detail pixels=", altered_pixels)
	print("[DarkrideRender] PASS: entrance, deep_neon, exit photographed in Godot")
	quit(0)
