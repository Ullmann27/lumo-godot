extends SceneTree
## Projects the actual production glyph and mission-marker vertices beside
## Nelli's house, where a wall pushes the walking camera towards the avatar.
const VILLAGE = preload("res://scripts/creative/lumo_world_village.gd")
const PROFILE := "lumo_world_camera_regression_2078"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorldCamera] " + label)


func _run() -> void:
	var world_path := "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	var village_path: String = VILLAGE.save_path_for(PROFILE, 1)
	DirAccess.remove_absolute(world_path)
	DirAccess.remove_absolute(village_path)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.get_node("SceneRouter").launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	var scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	for index in range(4):
		await physics_frame
		await process_frame
	var labels: Dictionary = {}
	for node in scene.find_children("*", "Label3D", true, false):
		labels[node.text] = node
	_check(labels.has("Nelli") and labels.has("Nellis Zuhause"), "original friend and house names exist")
	for config in [
		{"size": Vector2i(1280, 720), "density": 1.0},
		{"size": Vector2i(1384, 1400), "density": 2.0},
		{"size": Vector2i(720, 1280), "density": 2.0}
	]:
		root.size = config.size
		root.get_node("HostBridge")._options["displayDensity"] = config.density
		await process_frame
		_check(is_equal_approx(root.get_node("MobileRuntime").get_ui_density(), config.density), "real UI density boundary uses the requested density")
		scene.player.position = Vector3(91.0, 0.05, 20.0)
		scene.player.velocity = Vector3.ZERO
		scene.last_safe = scene.player.position
		scene.camera_yaw = 0.0
		scene.camera.position = scene.player.position + Vector3(4.6, 5, 10)
		for index in range(120):
			scene._update_camera(1.0 / 60.0)
		scene._physics_process(0.0)
		var view := root.get_visible_rect()
		var pixels_per_canvas := Vector2(root.size) / view.size
		var feet: Vector2 = scene.camera.unproject_position(scene.player.position)
		var head: Vector2 = scene.camera.unproject_position(scene.player.position + Vector3.UP * 2.65)
		var tag := "%sx%s density=%s" % [root.size.x, root.size.y, config.density]
		_check(view.grow(-8.0).has_point(feet) and view.grow(-8.0).has_point(head), "head and feet stay within the compressed camera: " + tag)
		_check(not scene.action_button.disabled and scene.action_button.text == "Ansprechen", "Nelli's interaction remains available: " + tag)
		for name in ["Nelli", "Nellis Zuhause"]:
			var label: Label3D = labels[name]
			var extent := _label_rect(scene.camera, label).size * pixels_per_canvas / float(config.density)
			_check(label.visible and label.text == name and not label.no_depth_test, "visible original depth-tested name: " + name + " " + tag)
			_check(extent.x <= 321.0 and extent.y <= 35.0 and extent.y > 8.0, "readable bounded glyph rectangle: " + name + " " + tag + " " + str(extent))
		var marker_rect := _mesh_rect(scene.camera, scene.marker)
		var marker_size := marker_rect.size * pixels_per_canvas / float(config.density)
		_check(scene.marker.visible and marker_size.x <= 49.0 and marker_size.y <= 49.0 and marker_size.length() > 5.0, "mission star stays visible without filling the foreground: " + tag + " " + str(marker_size))
		print("[LumoWorldCamera] view=", tag, " feet=", feet, " head=", head, " markerDp=", marker_size)
	_check(labels["Sonnendorf →"].scale.is_equal_approx(Vector3.ONE), "physical roadside direction sign keeps its authored dimensions")
	_check(not FileAccess.file_exists(village_path), "camera verification does not create a village save")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(world_path)
	DirAccess.remove_absolute(village_path)
	print("[LumoWorldCamera] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _label_rect(camera: Camera3D, label: Label3D) -> Rect2:
	var points := PackedVector2Array()
	for vertex in label.generate_triangle_mesh().get_faces():
		var at: Vector3 = label.global_position + camera.global_basis * (vertex * label.global_basis.get_scale())
		points.append(camera.unproject_position(at))
	return _bounds(points)


func _mesh_rect(camera: Camera3D, mesh: MeshInstance3D) -> Rect2:
	var points := PackedVector2Array()
	for vertex in mesh.mesh.get_faces():
		points.append(camera.unproject_position(mesh.global_transform * vertex))
	return _bounds(points)


func _bounds(points: PackedVector2Array) -> Rect2:
	var rectangle := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rectangle = rectangle.expand(point)
	return rectangle
