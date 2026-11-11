extends SceneTree
## Real garage state, replacement selection, camera ownership and projected touch targets.
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[GaragePresentation] " + label)


func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var garage = load("res://scripts/games/kart_garage_menu.gd").new()
	garage.stars = 100
	root.add_child(garage)
	garage.step = 2
	garage._refresh()
	await _settle()
	var interior: Node3D = garage.garage_interior.root
	_check(interior.find_child("ServiceBayFrame", true, false) is MultiMeshInstance3D,
		"physical framed bay uses an instanced trim batch")
	_check(interior.find_child("FloorPanelSeams", true, false) is MultiMeshInstance3D,
		"repeated floor seams are one batch")
	var floor_mesh: MeshInstance3D = interior.get_node("GarageFloor")
	var floor_material: StandardMaterial3D = floor_mesh.material_override
	_check(floor_material.metallic < 0.25 and floor_material.roughness > 0.4,
		"garage floor retains a diffuse surface without a reflection probe")
	_check(interior.find_children("*", "CollisionObject3D", true, false).size() == 4,
		"scenery creates no new collision bodies beyond four existing actions")
	_check(garage.garage_interior.materials.size() == 10, "ten shared material families")
	var shadow_lights := 0
	for light in garage.preview.find_children("*", "Light3D", true, false):
		if light.shadow_enabled:
			shadow_lights += 1
	_check(shadow_lights == 1, "the original key owns the single preview shadow pass")
	var former: Node3D = garage.preview_kart
	garage._select("kart", "gecko_velo")
	garage._select("kart", "boru_rally")
	await _settle(2)
	_check(garage.preview_kart != former and garage.preview_kart.kart_style == "boru_rally",
		"rapid selections install the final real kart")
	var actor = garage.preview_kart.lumo_animation
	_check(is_instance_valid(actor) and actor._menu_gesture and actor.celebration_clip == "agree_nod",
		"selection nod belongs to the new seated driver")
	var instance: int = garage.preview_kart.get_instance_id()
	garage._select("kart", "boru_rally")
	await _settle(2)
	_check(garage.preview_kart.get_instance_id() == instance and not garage._selection_refresh_queued,
		"repeated same selection does not rebuild or restart animation")
	garage._choose_preview_view(1, false)
	var initial: Vector3 = garage.preview_camera.position
	garage._choose_preview_view(3)
	_check(garage.preview_camera.position.is_equal_approx(initial) and garage._camera_progress == 0.0,
		"camera change begins from the actual current frame")
	garage._advance_preview_camera(0.17)
	_check(garage.preview_camera.position.distance_to(Vector3(0, 1.0, 0)) > 5.0,
		"front-to-back transition orbits outside the car")
	garage._choose_preview_view(4)
	garage._advance_preview_camera(0.34)
	_check(garage.preview_camera.position.is_equal_approx(Vector3(5.6, 1.2, 0)),
		"latest camera request owns the final pose")
	garage.reduced_motion = true
	garage._choose_preview_view(5)
	_check(garage._camera_progress == 1.0 and garage.preview_camera.position.is_equal_approx(Vector3(0, 6, 0)),
		"reduced motion applies inspection immediately")
	garage.step = 0
	garage._refresh()
	for dimensions in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(412, 915), Vector2i(690, 829)]:
		root.size = dimensions
		garage._apply_responsive_layout()
		await _settle(4)
		garage._update_garage_action_targets()
		var scale: float = garage._preview_dp_scale()
		var targets: Dictionary = garage._garage_targets
		_check(targets.size() in [0, 4], "%s shows a complete usable action set or its 2D alternatives" % dimensions)
		for action in targets:
			var rect: Rect2 = targets[action]
			_check(rect.size.x / scale >= 47.99 and rect.size.y / scale >= 47.99,
				"%s %s projected hit area >=48dp" % [dimensions, action])
			_check(garage._pick_garage_action(rect.get_center()) == str(action),
				"%s %s real preview picker receives target center" % [dimensions, action])
		_check(garage.next_button.size.y / scale >= 47.99 and garage.back_button.size.y / scale >= 47.99,
			"%s persistent 2D navigation >=48dp" % dimensions)
		print("[GaragePresentation] ", dimensions, " projected_actions=", targets.size(),
			" preview=", garage.preview_viewport.size, " draw_calls=", garage.preview_draw_calls())
	garage.queue_free()
	await _settle(3)
	if failures.is_empty():
		print("[GaragePresentation] PASS ", checks, " checks")
		quit(0)
	else:
		print("[GaragePresentation] FAIL ", failures)
		quit(1)
