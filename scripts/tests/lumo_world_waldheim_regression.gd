extends SceneTree
## Calls normal World, map, journal and dialog controls. The long walking legs
## between individual stations use positions from the authored path. Entry,
## bridge traversal and the full delivery leg use the visible joystick.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const TEARDOWN = preload("res://scripts/tests/lumo_scene_teardown.gd")
const PROFILE := "waldheim-release-regression"
const OLD_SECTIONS := ["friendPost", "openWorld", "sonnenhafen"]
const FINALE := "waldtafel"
var checks := 0
var failures := 0
var world: Node3D
var region: Node3D
var save_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[WaldheimRegression] " + detail)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	save_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	var start = STATE.new()
	start.position = Vector3(172, 0.12, 63)
	start.kart_position = Vector3(172, 0.15, 60)
	start.kart_yaw = PI
	start.completed.assign(["meet_nelli", "safe_crossing"])
	var old_save: Dictionary = start.to_data()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	await _enter()
	_expect(is_instance_valid(region) and region.unlocked(), "the real World route opens Waldheim on an existing account")
	if not is_instance_valid(region) or not region.unlocked():
		await _finish()
		return
	_expect(region.model.mission_ids().size() == 12 and region.figures.size() == 5, "twelve actual authored quests and five visible original models")
	for entry in region.model.content.figures:
		_expect(not region.routines.activity(str(entry.id)).is_empty(), "resident has genuine local day phases " + str(entry.id))
	_expect(world.model.completed == ["meet_nelli", "safe_crossing"], "the old chapter is preserved")
	_expect(region.model.progress.values().all(func(step): return step == 0), "old saves acquire a fresh Waldheim")
	_check_floors()
	await _cross_bridge()
	world.map_button.pressed.emit()
	await _frames(3)
	_expect(world.overview.place_buttons.has("waldheim"), "Waldheim is a real map destination")
	if world.overview.place_buttons.has("waldheim"):
		world.overview.place_buttons.waldheim.pressed.emit()
		_expect(world.overview.focus_id == "waldheim", "Waldheim map button shows the playable region")
	var button: Button = world.modal_box.get_node_or_null("WorldJournalButton")
	_expect(button != null, "existing map opens the journal")
	if button != null:
		button.pressed.emit()
		await _frames(3)
		var forest: Button = world.modal_box.get_node_or_null("OpenWaldheimJournal")
		_expect(forest != null, "the main journal has an accessible Waldheim section")
		if forest != null:
			forest.pressed.emit()
			await _frames(3)
			_expect(world.modal_box.has_node("JournalMission_wegzeichen"), "the first Waldheim mission is listed")
	if world.paused:
		world._close_dialog()
	_expect(await _talk(FINALE, false), "accept the final project from Nuri using a real dialog")
	await _arrive(region.model.step_target(region.model.current_step(FINALE)))
	world.action_button.pressed.emit()
	await _frames(2)
	_expect(world.paused and not world.modal_box.has_node("WaldheimChoice_0"), "finishing early is locked without all eleven contributions")
	world._close_dialog()
	for id in region.model.mission_ids():
		if id == FINALE:
			continue
		await _play_mission(id)
	await _solve(FINALE, false)
	_expect(await _talk(FINALE, true), "return to the real resident after putting up the final sign")
	_expect(region.model.progress.values().all(func(step): return step == 3), "all twelve complete after all visible interactions")
	_expect(region.model.cards().size() == 5, "five figure cards derived once from their completed missions")
	var captured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var persisted := JSON.stringify(region.model.progress)
	_expect(captured.waldheim.progress == JSON.parse_string(persisted), "the completed region actually wrote the main World file")
	await _enter()
	_expect(region.model.progress.values().all(func(step): return step == 3), "all twelve complete again after normal scene restart")
	_expect(region.model.cards().size() == 5 and region.station_views[FINALE].solved, "album and completed 3D board restore")
	var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	for section in OLD_SECTIONS:
		_expect(captured[section] == restored[section], "%s remains intact on the same account" % section)
	_expect(world.model.completed == ["meet_nelli", "safe_crossing"], "the base World chapter also restores")
	# A future section stays verbatim instead of replacing its progress.
	captured.waldheim = {"version": 5, "keep": "future data"}
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(captured))
	file.close()
	await _enter()
	_expect(not region.save_valid and not world.save_blocked, "a future Waldheim file is isolated from the rest of World")
	_expect(world._save(), "the rest of World can still save")
	var future: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_expect(future.waldheim == JSON.parse_string(JSON.stringify(captured.waldheim)), "future Waldheim data stays verbatim")
	await _finish()


func _enter() -> void:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	router.goto("world")
	await _frames(100)
	world = current_scene
	region = world.waldheim if is_instance_valid(world) else null


func _check_floors() -> void:
	var space := world.get_world_3d().direct_space_state
	var excluded: Array[RID] = [world.kart_body.get_rid(), world.player.get_rid()]
	for z in range(65, 106):
		var at := Vector3(172, 0, z)
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN, 1, excluded)
		var hit := space.intersect_ray(query)
		_expect(not hit.is_empty() and absf(float(hit.get("position", Vector3.DOWN).y)) < 0.1,
			"seam-free real boardwalk ground at z=%d" % z)
	for entry in region.model.content.places:
		var at: Vector3 = entry.position
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN, 1, excluded)
		var hit := space.intersect_ray(query)
		_expect(not hit.is_empty() and absf(float(hit.get("position", Vector3.DOWN).y)) < 0.10, "reachable exhibit ground " + str(entry.id))


func _cross_bridge() -> void:
	world.camera_yaw = PI
	world.joystick.target = Vector2(0, -1)
	for frame in range(900):
		await physics_frame
		if world.player.position.z >= 99.0:
			break
	world.joystick.target = Vector2.ZERO
	world.joystick.axis = Vector2.ZERO
	_expect(world.player.position.z >= 98.0 and world.player.is_on_floor(),
		"real walking input reaches Waldheim across the bridge on stable ground (%.2f, %.2f)" %
		[world.player.position.x, world.player.position.z])


func _arrive(at: Vector3) -> void:
	world.player.position = at + Vector3.UP * 0.07
	world.player.velocity = Vector3.ZERO
	await _frames(16)


func _talk(id: String, completing: bool) -> bool:
	var step: Dictionary = region.model.current_step(id)
	var figure_at: Vector3 = region.model.step_target(step)
	await _arrive(figure_at)
	var open: bool = not world.action_button.disabled and world.action_button.text == "Ansprechen"
	_expect(open, "the visible action button reaches the resident for " + id)
	if not open:
		return false
	world.action_button.pressed.emit()
	await _frames(2)
	var button: Button = world.modal_box.get_node_or_null("DialogChoice_0")
	_expect(button != null, "the resident speaks through the shared real dialog for " + id)
	if button == null:
		return false
	button.pressed.emit()
	await _frames(4)
	var state_ok: bool = region.model.state(id) == ("done" if completing else "active")
	if world.paused:
		world._close_dialog()
	return state_ok


func _play_mission(id: String) -> void:
	# Selecting a mission from the journal is legitimate prioritisation when the
	# same resident can hand out several tasks.
	region._open_waldheim_journal()
	await _frames(2)
	var follow: Button = world.modal_box.get_node_or_null("JournalFollow_" + id)
	_expect(follow != null, "the journal can track " + id)
	if follow != null:
		follow.pressed.emit()
		await _frames(3)
	else:
		world._close_dialog()
	if not await _talk(id, false):
		_expect(false, "mission starts through the resident " + id)
		return
	if id == "waldpost":
		await _deliver_by_kart()
	else:
		await _solve(id, id == "brueckenholz")
	if id == "wegzeichen":
		await _enter()
		_expect(int(region.model.progress[id]) == 2 and region.station_views[id].solved,
			"normal restart resumes the mid-mission report and reconstructed marker")
	_expect(await _talk(id, true), "reporting back finishes the mission " + id)


func _solve(id: String, try_wrong: bool) -> void:
	var at: Vector3 = region.model.step_target(region.model.current_step(id))
	await _arrive(at)
	_expect(not world.action_button.disabled and world.action_button.text == "Untersuchen", "the physical station is usable for " + id)
	world.action_button.pressed.emit()
	await _frames(2)
	var answer := int(region.stations[id].answer)
	if try_wrong:
		var wrong: Button = world.modal_box.get_node_or_null("WaldheimChoice_%d" % ((answer + 1) % 3))
		if wrong != null:
			wrong.pressed.emit()
			await _frames(2)
		_expect(int(region.model.progress[id]) == 1 and world.paused,
			"a wrong answer gives a retry without saving a solved exhibit")
	var choice: Button = world.modal_box.get_node_or_null("WaldheimChoice_%d" % answer)
	_expect(choice != null, "a verified answer is available for " + id)
	if choice != null:
		choice.pressed.emit()
		await _frames(3)
	_expect(int(region.model.progress[id]) == 2 and region.station_views[id].solved, "the answer changes the physical exhibit for " + id)
	if world.paused:
		world._close_dialog()


func _deliver_by_kart() -> void:
	var destination: Vector3 = region.model.step_target(region.model.current_step("waldpost"))
	await _arrive(destination)
	_expect(int(region.model.progress.waldpost) == 1, "arriving on foot cannot complete the delivery")
	await _arrive(world.kart_body.position + Vector3(2.0, 0.0, 0.0))
	world.vehicle_button.pressed.emit()
	await _frames(5)
	_expect(world.driving, "the World vehicle button seats original Lumo in the kart")
	var waypoints: Array[Vector3] = [Vector3(172, 0, 154), Vector3(172, 0, 171), destination]
	for frame in range(2600):
		var at: Vector3 = world.kart_body.position
		if waypoints.size() > 1 and Vector2(at.x - waypoints[0].x, at.z - waypoints[0].z).length() < 4.0:
			waypoints.pop_front()
		var aim := waypoints[0] - at
		var desired := atan2(-aim.x, -aim.z)
		var turn := clampf(wrapf(world.kart_body.rotation.y - desired, -PI, PI) * 2.5, -1.0, 1.0)
		world.joystick.target = Vector2(turn, -0.65)
		await physics_frame
		if int(region.model.progress.waldpost) == 2:
			break
	world.joystick.target = Vector2.ZERO
	world.joystick.axis = Vector2.ZERO
	world.run_button.pressed.emit()
	await _frames(30)
	_expect(int(region.model.progress.waldpost) == 2 and world.kart_body.is_on_floor(),
		"the driven route reaches the forest delivery circle on the real ground (%.2f, %.2f)" %
		[world.kart_body.position.x, world.kart_body.position.z])
	world.vehicle_button.pressed.emit()
	await _frames(4)
	_expect(not world.driving, "the delivery allows a real grounded exit")


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	DirAccess.remove_absolute(save_path)
	_expect(await TEARDOWN.release(self, "[WaldheimRegression]"), "the scene and audio release")
	print("[WaldheimRegression] %s %d checks, %d errors" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
