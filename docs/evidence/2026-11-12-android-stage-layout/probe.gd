extends SceneTree
var game

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(12):
		await process_frame

func _print_control(label: String, node: Control) -> void:
	var pixel_scale := Vector2(root.size) / root.get_visible_rect().size
	var rect := node.get_global_rect()
	print(label, " size=", node.size, " min=", node.get_combined_minimum_size(), " px=", Rect2(rect.position * pixel_scale, rect.size * pixel_scale), " font=", node.get_theme_font_size("font_size"), " cached_min=", node.get_meta("kart_base_minimum_size", Vector2.ZERO))

func _rays(menu) -> void:
	var points: Array[Vector3] = []
	for mesh in menu.preview_kart.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.skin != null or mesh == menu.preview_kart.far_mesh:
			continue
		for corner in range(8):
			points.append(mesh.to_global(mesh.get_aabb().get_endpoint(corner)))
	var skeleton: Skeleton3D = menu.preview_kart.lumo_animation.actor.skeleton
	var head := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
	for offset in [Vector3.ZERO, Vector3.UP * 0.46, Vector3(0.66, 0.37, 0), Vector3(-0.66, 0.37, 0)]:
		points.append(head + offset)
	var origin: Vector3 = menu.preview_camera.get_camera_transform().origin
	var hits := []
	for mesh in menu.garage_interior.root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		for point in points:
			if bounds.intersects_segment(origin, point) != null:
				hits.append([str(mesh.name), point])
	print("PHYSICAL_RAYS landing=", menu._landing_active, " origin=", origin, " points=", points.size(), " hits=", hits)

func _run() -> void:
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	root.size = Vector2i(2400, 1080)
	await _settle()
	game._apply_safe_area(Rect2(0, 32, 0, 126), Vector2(root.size))
	game._show_reference_landing(true)
	await _settle()
	print("ROOT physical=", root.size, " logical=", root.get_visible_rect(), " density=", root.get_node("MobileRuntime").get_ui_density(), " content_scale=", root.content_scale_size)
	_print_control("safe", game.safe_ui)
	_print_control("landing", game.reference_landing)
	_print_control("landing header", game.reference_landing._header)
	_print_control("landing modes", game.reference_landing._modes)
	_print_control("landing navigation", game.reference_landing._navigation)
	_print_control("landing footer", game.reference_landing._footer)
	_rays(game.garage)
	game._reference_select_mode("garage")
	await _settle()
	var menu = game.garage
	for spec in [["header", menu._stage_header], ["header row", menu.header_row], ["logo", menu.brand_wordmark], ["reward", menu.progress_panel], ["star", menu.progress_icon], ["stars", menu.progress_label], ["games", menu.learn_button], ["tabs", menu.step_strip], ["selection", menu.setup_left], ["footer", menu.footer]]:
		_print_control(spec[0], spec[1])
	_rays(menu)
	game.abandoned = true
	game.queue_free()
	await _settle()
	quit()
