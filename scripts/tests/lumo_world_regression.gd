extends SceneTree
## Real state/scene regression: receipt integrity, original save projection,
## real touch controls, movement, traffic and native round trips.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const VILLAGE = preload("res://scripts/creative/lumo_world_village.gd")
const SETTLEMENT = preload("res://scripts/creative/build_settlement_state.gd")
const PROFILE := "lumo_world_regression_20261123"
var checks := 0
var failures: Array[String] = []
var scene_test_finished := false


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorld] " + label)


func _receipt(request: Dictionary) -> Dictionary:
	return {"version": 1, "requestId": request.requestId, "missionId": "school_numbers", "completed": true, "subject": "Mathematik", "grade": request.grade, "returnGame": "world"}


func _run() -> void:
	var model = STATE.new()
	_check(not model.meet_friend(Vector3.ZERO), "distant dialogue cannot complete a mission")
	_check(not model.consume_learning_receipt({"completed": true}), "unrequested lesson cannot unlock World")
	_check(model.meet_friend(Vector3(90, 0, 20)), "Nelli dialogue advances exactly once")
	_check(not model.meet_friend(Vector3(90, 0, 20)), "duplicate dialogue is harmless")
	_check(not model.observe_crossing(Vector3(110, 0, 7), false, true), "red does not begin crossing")
	_check(not model.observe_crossing(Vector3(110, 0, -6), true, true), "teleporting to far side cannot earn crossing")
	model.observe_crossing(Vector3(110, 0, 7), true, false)
	_check(not model.observe_crossing(Vector3(110, 0, -6), true, false), "driving cannot complete pedestrian task")
	model.observe_crossing(Vector3(110, 0, 7), true, true)
	_check(model.observe_crossing(Vector3(110, 0, -6), false, true), "crossing begun on green can be completed after phase changes")
	_check(model.begin_school_request("bad", 2, Vector3(110, 0, -24)).is_empty(), "host rejects unsupported request IDs before saving")
	var request: Dictionary = model.begin_school_request("world-request-20261123", 2, Vector3(110, 0, -24))
	_check(request.grade == 2 and request.id == "school_numbers", "school request is explicit and grade scoped")
	_check(model.begin_school_request("another-request", 2, Vector3(110, 0, -24)) == request, "same-grade retry preserves the durable request ID")
	var receipt := _receipt(request)
	var next_grade = STATE.new()
	next_grade.restore(model.to_data())
	_check(next_grade.begin_school_request("bad", 3, next_grade.current().at).is_empty(), "invalid replacement ID cannot rotate a pending lesson")
	_check(next_grade.pending_lesson == request, "failed grade rotation preserves the pending request")
	_check(next_grade.begin_school_request(request.requestId, 3, next_grade.current().at).is_empty(), "grade change must rotate the request ID")
	var changed_request: Dictionary = next_grade.begin_school_request("world-new-school-year", 3, next_grade.current().at)
	_check(changed_request.grade == 3 and changed_request.requestId != request.requestId, "school year change creates a fresh grade-scoped request")
	_check(not next_grade.consume_learning_receipt(receipt), "receipt from previous school year cannot unlock the new request")
	_check(next_grade.consume_learning_receipt(_receipt(changed_request)), "new school year can complete without losing earlier missions")
	for key in ["version", "requestId", "missionId", "subject", "grade", "returnGame", "completed"]:
		var bad: Dictionary = receipt.duplicate(true)
		bad.erase(key)
		_check(not model.consume_learning_receipt(bad), "missing receipt " + key + " cannot unlock school")
	var bad: Dictionary = receipt.duplicate(true)
	bad.completed = "true"
	_check(not model.consume_learning_receipt(bad), "string completion is not a true learning receipt")
	bad = receipt.duplicate(true)
	bad.requestId = "another-request"
	_check(not model.consume_learning_receipt(bad), "foreign request cannot claim a lesson")
	var restored = STATE.new()
	_check(restored.restore(JSON.parse_string(JSON.stringify(model.to_data()))), "pending mission survives actual JSON round trip")
	_check(restored.consume_learning_receipt(receipt), "matching completed learning unlocks garden")
	_check(not restored.consume_learning_receipt(receipt), "receipt replay cannot advance a second mission")
	for grade in range(1, 5):
		var branch = STATE.new()
		branch.restore(restored.to_data())
		for id in ["garden_delivery", "city_parcels", "friendship_picnic"]:
			var task: Dictionary = branch.task(grade)
			_check(not task.is_empty(), "grade %d has authored task %s" % [grade, id])
			_check(not branch.answer((int(task.correct) + 1) % task.choices.size(), grade, branch.current().at), "wrong answer never earns progress")
			_check(branch.answer(int(task.correct), grade, branch.current().at), "correct situated answer advances")
		_check(branch.is_complete(), "all six grade %d missions finish" % grade)
	var unchanged := JSON.stringify(restored.to_data())
	for corrupt in [
		{"version": 1, "completed": ["school_numbers"], "position": [0, 0, 0]},
		{"version": 1, "completed": [], "position": [0, "up", 0]},
		{"version": 1, "completed": [], "position": [10000, 0, 0]},
		{"version": 1, "completed": [], "position": [0, 0, 0], "pendingLesson": {"id": "school_numbers"}}
	]:
		_check(not restored.restore(corrupt), "malformed World save is rejected")
		_check(JSON.stringify(restored.to_data()) == unchanged, "rejected restore is atomic")
	var native = root.get_node("HostBridge")
	_check(native.validated_options({"game": "world", "grade": 4}).scene == "world", "native host accepts World")
	var router = root.get_node("SceneRouter")
	router.launch_options = {"worldPortalOrigin": "world", "childKey": PROFILE}
	for scene in ["kart", "cards", "settlement"]:
		router.current_scene_id = scene
		_check(router.should_return_to_world("games"), scene + " returns to World")
		_check(not router.should_return_to_world("learn"), scene + " retains real learning return")
	router.launch_options.erase("worldPortalOrigin")
	_check(not router.should_return_to_world("games"), "ordinary games retain their previous exit behavior")
	await _real_scene()
	_check(scene_test_finished, "the full scene and file-preservation regression completed")
	print("[LumoWorld] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _real_scene() -> void:
	var world_path := "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	var village_path: String = VILLAGE.save_path_for(PROFILE, 1)
	DirAccess.remove_absolute(world_path)
	var original = SETTLEMENT.new("settlement", true)
	for plot in range(9):
		original.try_build("house", plot)
		if original.player().buildings.size() >= 3:
			break
	_check(original.player().buildings.size() >= 2, "real village fixture has multiple independent building IDs")
	var envelope := {"version": 1, "child": PROFILE, "mode": "settlement", "slot": 1, "settlement": original.snapshot(), "village_meta": {}}
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(village_path, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()
	_check(VILLAGE.restore_existing(envelope, "another-child", 1) == null, "another child's village is never projected")
	_check(VILLAGE.restore_existing(envelope, PROFILE, 2) == null, "another build slot is never projected")
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	var scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	await _frames(8)
	_check(scene.fox.is_real(), "original rigged Lumo is loaded")
	# This scene intentionally runs with reduceAnimations=true. Essential
	# locomotion must still articulate arms and legs instead of sliding.
	var gait_start: Vector3 = scene.player.position
	scene.paused = false
	scene.joystick.target = Vector2(0, -1)
	for index in range(18):
		await physics_frame
	_check(scene.player.position.distance_to(gait_start) > 0.25, "reduced-motion World body actually translates")
	_check(scene.fox.current_behavior() in ["walk_loop", "run_loop"], "reduced-motion World keeps an articulated gait while moving")
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	_check(scene.has_node("OriginalTreasureIsland/OriginalTreasureChest"), "the real Treasure Island chest is retained")
	_check(scene.art.zones.has("OriginalTreasureIsland"), "original terrain and nature are the World foundation")
	_check(scene.own_village.source_status == "loaded", "the real existing village envelope is loaded")
	_check(scene.own_village.model.player().buildings == original.player().buildings, "saved village building identity and plots are identical")
	scene.own_village.update_focus(VILLAGE.ORIGIN + Vector3(-100, 0, 0), 0.0)
	for building in original.player().buildings:
		_check(scene.own_village.facilities.has(str(building.id)), "saved string building ID remains a separate walkable building: " + str(building.id))
	_check(FileAccess.get_file_as_string(village_path) == bytes, "opening World alone does not mutate the village economy save")
	_check(scene.portals.size() == 2, "Kart and Cards remain portals while village building is native to World")
	_check(scene.traffic.size() == 4, "Blender traffic vehicle models load")
	_check(scene.own_village.model != null, "authoritative living-village model is loaded inside World")
	var camera_before: Vector3 = scene.camera.position
	scene.camera_yaw += 0.72
	scene._update_camera(10.0)
	_check(scene.camera.position.distance_to(camera_before) > 0.5, "person camera orbits freely around Lumo")
	scene._toggle_build_mode()
	_check(scene.build_mode and scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "zoomed build view is part of the same World scene")
	_check(scene.build_panel.visible and not scene.joystick.visible, "build HUD replaces walking controls without launching another game")
	var build_plot: int = scene.own_village.next_free_plot()
	_check(build_plot >= 0, "existing village has a buildable free plot")
	var building_count: int = scene.own_village.model.player().buildings.size()
	var built_result: Dictionary = scene.own_village.try_build("well", build_plot)
	_check(bool(built_result.get("ok", false)), "explicit World build uses the existing village economy")
	_check(scene.own_village.model.player().buildings.size() == building_count + 1, "same authoritative village model gains the building")
	var village_after_build: String = FileAccess.get_file_as_string(village_path)
	_check(village_after_build != bytes, "explicit World build persists to the existing village save")
	var parsed_after_build: Dictionary = JSON.parse_string(village_after_build)
	var restored_after_build = VILLAGE.restore_existing(parsed_after_build, PROFILE, 1)
	_check(restored_after_build != null and restored_after_build.player().buildings.size() == building_count + 1, "saved building round-trips through the original village schema")
	scene._toggle_build_mode()
	_check(not scene.build_mode and scene.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "build view returns directly behind walking Lumo")
	await _visibility_and_school(scene)
	for dimensions in [Vector2i(360, 800), Vector2i(640, 360), Vector2i(720, 840), Vector2i(1280, 720)]:
		root.size = dimensions
		await _frames(3)
		scene._layout()
		for button in [scene.action_button, scene.vehicle_button, scene.run_button, scene.map_button, scene.exit_button]:
			_check(button.size.x >= 48 and button.size.y >= 48, "48dp control at %s" % dimensions)
			_check(Rect2(Vector2.ZERO, scene.safe_ui.size).encloses(button.get_rect()), "control stays inside safe area at %s" % dimensions)
	scene.player.position = Vector3(75, 0.1, 18)
	scene.player.velocity = Vector3.ZERO
	await _frames(4)
	scene._toggle_vehicle()
	_check(scene.driving and not scene.fox.visible, "existing Lumo Kart is enterable without duplicate fox")
	scene._drive_tick(Vector2(0, -1), 0.2)
	_check(scene.drive_speed > 0 and scene.kart_body.velocity.length() > 0, "kart has real controlled motion")
	scene.drive_speed = 0
	scene._toggle_vehicle()
	_check(not scene.driving and scene.fox.visible, "exiting kart restores walking Lumo")
	scene.player.position = Vector3(110, 0.2, 7)
	scene.signal_requested = true
	for index in range(1200):
		scene._traffic_tick(1.0 / 60.0)
		if scene.signal_green:
			break
	_check(scene.signal_green, "requested crossing eventually becomes green")
	for traffic_entry in scene.traffic:
		_check(absf(traffic_entry.node.position.x - 110.0) >= 7.5, "green starts only after traffic has cleared")
	_check(scene._save(), "World progress saves atomically")
	_check(FileAccess.get_file_as_string(village_path) == village_after_build, "walking driving traffic and World save do not change village economy after the explicit build")
	scene.model.completed.assign(["meet_nelli", "safe_crossing"])
	scene.player.position = Vector3(110, 0.2, -24)
	var old_request: Dictionary = scene.model.begin_school_request("persisted-grade-two-request", 2, scene.player.position)
	_check(scene._save(), "pending old-school-year mission is persisted")
	scene.queue_free()
	await _frames(3)
	root.get_node("SceneRouter").launch_options = {"childKey": PROFILE, "grade": 3, "reduceAnimations": true, "worldLearningReceipt": _receipt(old_request)}
	scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	await _frames(5)
	_check(scene.model.completed.size() == 2, "actual World restart refuses an old-school-year receipt")
	_check(scene.model.pending_lesson.grade == 3 and scene.model.pending_lesson.requestId != old_request.requestId, "actual World restart rotates the pending school request")
	var reloaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world_path))
	_check(reloaded.pendingLesson.grade == 3, "new-school-year request is durable before leaving World")
	scene.queue_free()
	await _frames(3)
	for broken in ["{invalid-json", "[]", JSON.stringify({"version": 1, "completed": ["school_numbers"], "position": [0, 0, 0]})]:
		file = FileAccess.open(world_path, FileAccess.WRITE)
		file.store_string(broken)
		file.close()
		scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
		root.add_child(scene)
		await _frames(4)
		_check(scene.save_blocked and scene.modal.visible, "invalid persisted World opens a safe return dialog")
		_check(not scene._save(), "invalid persisted World blocks autosave and explicit save")
		_check(not scene._report_completed_reward(), "invalid persisted World cannot report a completion reward")
		_check(scene.model.pending_lesson.is_empty(), "invalid persisted World does not consume or replace a school receipt")
		_check(FileAccess.get_file_as_string(world_path) == broken, "invalid persisted World bytes are preserved exactly")
		scene.queue_free()
		await _frames(3)
	DirAccess.remove_absolute(world_path)
	DirAccess.remove_absolute(village_path)
	scene_test_finished = true


func _visibility_and_school(scene: Node3D) -> void:
	scene.paused = true
	var clearance = scene.camera_clearance
	_check(clearance.entries.size() > 0, "real World vegetation is indexed for camera clearance")
	var views := [
		{"at": Vector3(77, -0.1198708, -23.22345), "drive": true},
		{"at": scene.own_village.doorway(), "drive": false}
	]
	for view in views:
		scene.driving = view.drive
		if view.drive:
			scene.kart_body.position = view.at
		else:
			scene.player.position = view.at
		scene.own_village.update_focus(view.at, 0.0)
		scene._update_camera(10.0)
		_check(clearance.hidden.size() > 0, "actual recorded %s camera pose clears foreground foliage" % ("kart" if view.drive else "village"))
		var hidden_ids: Array = clearance.hidden.keys()
		for id in hidden_ids:
			var entry: Dictionary = clearance.entries[id]
			var owner: Dictionary = clearance.owners[entry.owner]
			var node = owner.node.get_ref()
			if node is MultiMeshInstance3D:
				_check(owner.source.get_meta("authored_transforms")[entry.index].is_equal_approx(entry.original), "source vegetation transforms remain unchanged")
				_check(node.visible and node.get_parent().visible, "clearance does not switch off a whole visible vegetation/LOD group")
				if DisplayServer.get_name() != "headless":
					_check(node.multimesh.get_instance_transform(entry.index).origin.y < -90000, "only the obstructing draw is parked outside the view")
		scene.camera.position = Vector3(-2000, 6, -2000)
		var away := Vector3(-2000, 1, -2010)
		scene.camera.look_at(away)
		clearance.update(scene.camera, away, 0, 1.0 / 60.0)
		_check(clearance.hidden.is_empty(), "turning the normal camera away restores all cleared vegetation")
		for id in hidden_ids:
			var entry: Dictionary = clearance.entries[id]
			var node = clearance.owners[entry.owner].node.get_ref()
			if node is MultiMeshInstance3D and DisplayServer.get_name() != "headless":
				_check(node.multimesh.get_instance_transform(entry.index).is_equal_approx(entry.original), "restored tree draw has its exact original transform")
	# A real tree at the near-plane edge must be cleared even though the
	# camera-to-Lumo centre segment does not touch its protected bounds.
	scene.camera.position = Vector3(3000, 3, 0)
	var focus := Vector3(3000, 2, -10)
	scene.camera.look_at(focus)
	clearance.update(scene.camera, focus, 1, 1.0 / 60.0)
	var base_count: int = clearance.entries.size()
	var tree_mesh: Mesh = VILLAGE.ART.main_mesh("tree_oak")
	var local_box := tree_mesh.get_aabb()
	var near_edge: float = clearance.last_near_volume.end.x - scene.camera.position.x
	var edge_x: float = (clearance.BODY_RADIUS + near_edge) * 0.5
	var real_tree := MultiMeshInstance3D.new()
	real_tree.name = "CameraRegressionTree"
	var source := MultiMesh.new()
	source.transform_format = MultiMesh.TRANSFORM_3D
	source.mesh = tree_mesh
	source.instance_count = 1
	var placed := Transform3D(Basis.IDENTITY, Vector3(3000 + edge_x - local_box.position.x, 0, -1.6 - local_box.position.z))
	source.set_instance_transform(0, placed)
	source.set_meta("authored_transforms", [placed])
	real_tree.multimesh = source
	var lod_group := Node3D.new()
	lod_group.name = "CameraRegressionLOD"
	scene.art.zones.Gartenlandschaft.add_child(lod_group)
	lod_group.add_child(real_tree)
	await _frames(3)
	clearance.update(scene.camera, focus, 1, 0.6)
	var actual_box: AABB = placed * local_box
	_check(actual_box.grow(clearance.BODY_RADIUS).intersects_segment(scene.camera.position, focus) == null, "near-plane fixture does not intersect the protected centre ray")
	_check(actual_box.intersects(clearance.last_near_volume), "actual tree canopy intersects the camera near volume")
	_check(clearance.hidden.size() == 1, "near-plane foliage is cleared without relying on a centre-ray hit")
	lod_group.hide()
	clearance.update(scene.camera, focus, 1, 1.0 / 60.0)
	_check(not lod_group.visible and real_tree.visible and clearance.hidden.is_empty(), "camera restoration preserves the LOD parent's hidden state")
	lod_group.show()
	clearance.update(scene.camera, focus, 2, 1.0 / 60.0)
	_check(clearance.hidden.size() == 1, "changing the follow target recomputes foreground visibility")
	var replacement: MultiMesh = clearance._copy_draw_buffer(source)
	real_tree.multimesh = replacement
	clearance.update(scene.camera, focus, 2, 0.6)
	_check(clearance.entries.size() == base_count + 1, "rebuilt vegetation buffer replaces its old registry entries")
	_check(clearance.owners[real_tree.get_instance_id()].source == replacement, "replacement MultiMesh keeps its own restoration source")
	lod_group.queue_free()
	await _frames(3)
	_check(clearance.entries.size() == base_count and clearance.hidden.is_empty(), "freed vegetation is removed without stale hidden instances")
	# The school uses its authored y=0 ground plane. Its original below-ground
	# stone skirt must not become a metre-high wall in front of the doorway.
	var village: Node3D = scene.art.zones.Sonnendorf
	var school: Node3D = village.get_node("school_110_-35")
	_check(is_zero_approx(school.get_child(0).position.y), "school keeps the original authored ground plane")
	_check(village.has_node("SchoolEntranceRamp") and village.has_node("SchoolEntranceLanding"), "school has a physical entrance ramp and landing")
	var entry: Vector3 = village.get_meta("school_entrance")
	scene.driving = false
	scene.player.position = Vector3(110, 0.2, -20)
	scene.player.velocity = Vector3.ZERO
	# Earlier in this regression we deliberately orbit the person camera.
	# Walking is camera-relative, so restore the authored forward direction
	# before probing the school ramp instead of drifting sideways past it.
	scene.camera_yaw = 0.0
	scene.kart_body.position = Vector3(77, 0.2, 18)
	scene.drive_speed = 0.0
	scene.paused = false
	scene.joystick.target = Vector2(0, -1)
	for index in range(240):
		await physics_frame
		if scene.player.position.z <= entry.z + 0.2:
			break
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	_check(scene.player.position.z <= entry.z + 0.3, "Lumo can actually walk from the unchanged school capture point to the entrance")
	_check(scene.player.position.y >= entry.y - 0.2, "Lumo reaches the raised doorway landing without jumping through a foundation")
	var direction: Label3D = scene.get_node("OriginalTreasureIsland/TreasureVillageWayfinder/Direction")
	_check(direction.text == "Sonnendorf →" and direction.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "treasure entry uses a physical directional sign")
	_check(direction.font_size <= 28 and direction.pixel_size <= 0.00601, "treasure direction no longer spans the avatar's central view")
	scene.player.position = Vector3(0, 0.1, 6)
	scene.player.velocity = Vector3.ZERO
	scene._update_camera(10.0)


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
