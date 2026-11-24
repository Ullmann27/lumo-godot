extends SceneTree
## First entry, kart guidance and re-entry through the real SceneRouter path.
## The world is opened with SceneRouter.goto("world") and physics running; the
## camera is never placed next to a model. Optional renderer captures:
##   godot --path . --rendering-driver opengl3 --script <this> -- --capture=<dir>
## Captures need a real display (e.g. Xvfb); headless runs perform all checks.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const PROFILE := "lumo_world_first_entry_regression_20261124"
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(884, 920), Vector2i(360, 800)]
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var world_path := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_dir = argument.trim_prefix("--capture=")
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorldFirstEntry] " + label)


func _run() -> void:
	world_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
	else:
		capture_dir = ""
	root.size = VIEWS[0]
	var scene = await _enter_world()
	_check(scene != null and not scene.save_blocked, "the real router opens a fresh World")
	if scene == null:
		_finish()
		return
	await _first_entry(scene)
	await _drive_park_and_reopen(scene)
	scene = current_scene
	await _guidance_and_residents(scene)
	await _legacy_save()
	DirAccess.remove_absolute(world_path)
	_finish()


func _enter_world() -> Node:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	router.goto("world")
	for index in range(90):
		await physics_frame
		await process_frame
	return current_scene if is_instance_valid(current_scene) and current_scene.name == "LumoWorld" else null


func _first_entry(scene: Node) -> void:
	_check(scene.player.position.distance_to(STATE.SPAWN) < 0.3, "the child starts at the original island spawn")
	var start_xz := Vector2(scene.kart_body.position.x - STATE.KART_START.x, scene.kart_body.position.z - STATE.KART_START.z)
	_check(start_xz.length() < 0.001 and is_equal_approx(scene.kart_body.rotation.y, STATE.KART_START_YAW), "a fresh World places the kart at its first-entry start")
	_check(scene.kart_in_reach(), "the first-entry kart is within normal entry reach")
	_check(not scene.vehicle_button.disabled and scene.vehicle_button.text == "Ins Kart", "the entry control is active at first entry")
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(scene.kart_body.global_position + Vector3.UP, scene.kart_body.global_position + Vector3.DOWN * 2.0, 0xFFFFFFFF, [scene.kart_body.get_rid()])
	var ground: Dictionary = space.intersect_ray(down)
	_check(not ground.is_empty() and absf(scene.kart_body.global_position.y - float(ground.position.y)) < 0.03, "the start stands on real island floor collision")
	var shape_node: CollisionShape3D = scene.kart_body.get_child(0)
	var overlap := PhysicsShapeQueryParameters3D.new()
	overlap.shape = shape_node.shape
	overlap.transform = shape_node.global_transform.translated(Vector3.UP * 0.05)
	overlap.exclude = [scene.kart_body.get_rid(), scene.player.get_rid()]
	_check(space.intersect_shape(overlap, 1).is_empty(), "the start does not intersect island scenery")
	for dimensions in VIEWS:
		root.size = dimensions
		scene.camera_yaw = 0.0
		for index in range(60):
			await physics_frame
			await process_frame
		var tag := "%sx%s" % [dimensions.x, dimensions.y]
		var view: Rect2 = root.get_visible_rect().grow(-4.0)
		var camera: Camera3D = scene.camera
		var kart_points := [scene.kart_body.global_position + Vector3.UP * 0.7, scene.kart_beacon.global_position]
		for point in kart_points:
			_check(not camera.is_position_behind(point) and view.has_point(camera.unproject_position(point)), "kart and its label are inside the follow view at " + tag)
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 0xFFFFFFFF, [scene.kart_body.get_rid(), scene.player.get_rid()])
			_check(space.intersect_ray(ray).is_empty(), "no collider hides the kart from the follow camera at " + tag)
		var lumo: Vector2 = camera.unproject_position(scene.player.global_position + Vector3.UP * 1.2)
		var kart: Vector2 = camera.unproject_position(scene.kart_body.global_position + Vector3.UP * 0.7)
		_check(view.has_point(lumo), "Lumo stays in view beside the kart at " + tag)
		_check(lumo.distance_to(kart) > 60.0, "kart and Lumo are separate on screen at " + tag)
		_check(scene.kart_beacon.visible and scene.kart_beacon.text == "Dein Kart", "the parked kart is labelled at " + tag)
		if dimensions == VIEWS[0]:
			await _capture("01_ersteintritt_kart_sichtbar_720x1280")
	root.size = VIEWS[1]
	await _frames(20)
	await _capture("02_ersteintritt_kart_sichtbar_1280x720")


func _drive_park_and_reopen(scene: Node) -> void:
	scene.vehicle_button.pressed.emit()
	await _frames(4)
	_check(scene.driving and not scene.kart_beacon.visible and scene.vehicle_button.text == "Aussteigen", "the real entry control seats Lumo in the kart")
	# Steer like a child would: out of the start bay between the arch pillar and
	# the compass pedestal, then east towards the island bridge.
	var waypoints: Array[Vector2] = [Vector2(1.0, 2.85), Vector2(6.0, 2.85), Vector2(45.0, 6.0)]
	var reached := false
	var max_sink := 0.0
	for index in range(900):
		var at: Vector3 = scene.kart_body.position
		if waypoints.size() > 1 and Vector2(at.x, at.z).distance_to(waypoints[0]) < 1.2:
			waypoints.remove_at(0)
		var desired := atan2(-(waypoints[0].x - at.x), -(waypoints[0].y - at.z))
		var steer := clampf(wrapf(scene.kart_body.rotation.y - desired, -PI, PI) * 2.5, -1.0, 1.0)
		scene.joystick.target = Vector2(steer, -1.0)
		await physics_frame
		if scene.kart_body.is_on_floor():
			max_sink = maxf(max_sink, _wheel_sink(scene))
		if at.x > 40.0 and absf(at.z - 6.0) < 2.6:
			reached = true
			break
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	_check(reached, "driving from the start reaches the island bridge")
	_check(max_sink < 0.03, "no tyre sinks into the floor while driving to the bridge (deepest %.3f m)" % max_sink)
	scene.run_button.pressed.emit()
	for index in range(30):
		await physics_frame
	_check(absf(scene.drive_speed) < 0.75 and scene.kart_body.is_on_floor(), "the brake control stops the kart on the bridge deck")
	scene.vehicle_button.pressed.emit()
	await _frames(4)
	_check(not scene.driving and scene.kart_beacon.visible, "the real exit control parks the kart and shows its label")
	var parked: Vector3 = scene.kart_body.position
	var heading: float = scene.kart_body.rotation.y
	_check(scene.model.kart_position.is_equal_approx(parked), "the parked grounded pose is the saved kart pose")
	_check(scene._save(), "parking writes the World save")
	await _enter_world()
	var reopened: Node = current_scene
	_check(reopened != scene and reopened.kart_body.position.is_equal_approx(parked), "re-entry restores the kart at the bridge parking place")
	_check(is_equal_approx(reopened.kart_body.rotation.y, heading), "re-entry restores the kart heading")
	_check(reopened.kart_in_reach() and reopened.vehicle_button.text == "Ins Kart", "the reopened child can enter the parked kart directly")
	for dimensions in [VIEWS[1], VIEWS[0]]:
		root.size = dimensions
		await _frames(60)
		var camera: Camera3D = reopened.camera
		var view: Rect2 = root.get_visible_rect().grow(-4.0)
		var kart_point: Vector3 = reopened.kart_body.global_position + Vector3.UP * 0.7
		var tag := "%sx%s" % [dimensions.x, dimensions.y]
		_check(not camera.is_position_behind(kart_point) and view.has_point(camera.unproject_position(kart_point)), "the resumed follow view shows the parked kart at " + tag)
		_check(view.has_point(camera.unproject_position(reopened.player.global_position + Vector3.UP * 1.2)), "the resumed follow view keeps Lumo in view at " + tag)
		if dimensions == VIEWS[0]:
			await _capture("03b_wiedereintritt_kart_720x1280")
	root.size = VIEWS[1]
	await _frames(30)
	await _capture("03_wiedereintritt_kart_am_parkplatz")


func _guidance_and_residents(scene: Node) -> void:
	var parked: Vector3 = scene.kart_body.position
	scene.player.position = Vector3(218, 0.2, 8)
	scene.last_safe = scene.player.position
	await _frames(6)
	_check(not scene.kart_in_reach() and not scene.vehicle_button.disabled and scene.vehicle_button.text == "Kart suchen", "far from the kart the control offers guidance instead of a dead button")
	var before := JSON.stringify(scene.model.to_data())
	var save_before := FileAccess.get_file_as_string(world_path)
	scene.vehicle_button.pressed.emit()
	await _frames(6)
	_check(scene.kart_guidance and scene.vehicle_button.text == "Führung aus", "the guidance control starts kart guidance")
	_check(scene.status_label.text.contains("m entfernt") and scene.status_label.text.contains("Inselbrücke"), "guidance names distance and place of the kart")
	_check(scene.wonder.route_count() == 1, "guidance shows exactly one light route")
	var origin: Vector3 = scene.player.position
	var tip: Vector3 = scene.wonder.route_point(0, WISPS.WISPS_PER_ROUTE - 1)
	var to_kart := Vector2(parked.x - origin.x, parked.z - origin.z).normalized()
	var to_tip := Vector2(tip.x - origin.x, tip.z - origin.z).normalized()
	_check(to_tip.dot(to_kart) > 0.99, "the light route points to the parked kart")
	_check(not scene.driving and not scene.paused, "guidance neither seats the child nor pauses the world")
	_check(JSON.stringify(scene.model.to_data()) == before, "guidance changes no progress, mission or kart data")
	_check(FileAccess.get_file_as_string(world_path) == save_before, "guidance writes no save")
	scene.vehicle_button.pressed.emit()
	await _frames(3)
	_check(not scene.kart_guidance and scene.vehicle_button.text == "Kart suchen", "the same control ends guidance")
	scene.vehicle_button.pressed.emit()
	await _frames(3)
	scene.player.position = parked + Vector3(0, 0.2, 3.0)
	scene.last_safe = scene.player.position
	await _frames(4)
	_check(not scene.kart_guidance and scene.vehicle_button.text == "Ins Kart", "guidance ends by itself next to the kart")
	_check(JSON.stringify(scene.model.completed) == JSON.stringify(STATE.new().completed), "guidance completed no mission")
	_check(scene.residents.size() == 3, "all three local story residents are loaded")
	for friend in scene.residents:
		var role: Label3D = scene.get_node_or_null("ResidentRole_" + str(friend.name))
		_check(role != null and role.text == "Computerfigur", "resident %s is labelled as a computer figure" % friend.name)
	for label in scene.find_children("*", "Label3D", true, false):
		var text := str(label.text).to_lower()
		_check(not text.contains("online") and not text.contains("mitspieler"), "no world label claims online players")
	scene.player.position = Vector3(218, 0.2, 8)
	scene.last_safe = scene.player.position
	await _frames(3)
	scene._map_dialog()
	await _frames(6)
	var atlas: Node = scene.overview
	_check(atlas.friends.size() == 3, "the map receives the three local residents")
	_check(atlas.kart_at.is_equal_approx(parked), "the map receives the parked kart")
	var legend_texts: Array[String] = []
	for item in atlas.get_node("WorldMapLegend").get_children():
		legend_texts.append((item.get_child(1) as Label).text)
	_check(legend_texts.has("Computerfigur") and legend_texts.has("Dein Kart"), "the legend names kart and computer figures")
	atlas.focus_place("city")
	await _frames(2)
	var edge: Variant = atlas.kart_marker_point(atlas.canvas.size)
	var rect: Rect2 = atlas.atlas_rect(atlas.canvas.size)
	_check(edge != null and rect.has_point(edge) and not atlas.view_bounds.has_point(Vector2(parked.x, parked.z)), "a kart outside the focused view stays marked at the map edge")
	atlas.focus_kart()
	await _frames(4)
	_check(atlas.view_bounds.has_point(Vector2(parked.x, parked.z)), "Mein Kart zeigen reveals the parked kart")
	await _capture("04_weltkarte_kart_marker")
	scene._close_dialog()
	_check(JSON.stringify(scene.model.completed) == JSON.stringify(STATE.new().completed), "map inspection completed no mission")


func _legacy_save() -> void:
	var legacy = STATE.new()
	var data: Dictionary = legacy.to_data()
	data.erase("kart")
	data.position = [220.0, 0.2, 8.0]
	var file := FileAccess.open(world_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var scene = await _enter_world()
	_check(scene != null and not scene.save_blocked, "a version-one save without kart data still opens")
	if scene == null:
		return
	var legacy_xz := Vector2(scene.kart_body.position.x - STATE.KART_SPAWN.x, scene.kart_body.position.z - STATE.KART_SPAWN.z)
	_check(legacy_xz.length() < 0.001 and is_zero_approx(scene.kart_body.rotation.y), "legacy saves keep the original Sonnendorf parking place")
	_check(scene.vehicle_button.text == "Kart suchen" and not scene.vehicle_button.disabled, "legacy saves offer kart guidance")


## Deepest tyre penetration: visual wheel bottom below the floor under it.
func _wheel_sink(scene: Node) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var deepest := 0.0
	for pivot in scene.kart_visual.wheel_pivots:
		var bottom: Vector3 = pivot.global_position - scene.kart_visual.global_basis.y.normalized() * 0.35
		var ray := PhysicsRayQueryParameters3D.create(bottom + Vector3.UP, bottom + Vector3.DOWN * 1.0, 0xFFFFFFFF, [scene.kart_body.get_rid(), scene.player.get_rid()])
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty():
			deepest = maxf(deepest, float(hit.position.y) - bottom.y)
	return deepest


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	_check(image.save_png(path) == OK, "renderer capture saved: " + name)
	print("[LumoWorldFirstEntry] capture %s window=%s renderer=%s" % [path, root.size, RenderingServer.get_current_rendering_method()])


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	_check(await preload("res://scripts/tests/lumo_scene_teardown.gd").release(self, "[LumoWorldFirstEntry]"), "production scene and audio playbacks are released")
	print("[LumoWorldFirstEntry] %s %d checks engine=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, Engine.get_version_info().string])
	quit(0 if failures.is_empty() else 1)
