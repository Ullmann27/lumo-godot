extends SceneTree
## Existing park geometry, ordered walking checkpoints and a single real
## in-world purchase are checked through the native routed World and its controls.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const TEARDOWN = preload("res://scripts/tests/lumo_scene_teardown.gd")
const PROFILE := "sternenstadt-release-regression"
const LEARNED := ["meet_nelli"]
var world: Node3D
var city: Node3D
var failures := 0
var checks := 0
var path := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[SternenstadtRegression] " + label)


func _enter() -> void:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	router.goto("world")
	await _frames(85)
	world = current_scene
	city = world.sternenstadt if is_instance_valid(world) else null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	var old = STATE.new()
	old.position = Vector3(183, 0.1, -17)
	old.completed.assign(LEARNED)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old.to_data()))
	file.close()
	await _enter()
	_check(is_instance_valid(city) and city.unlocked(), "the original World entry opens the new city quests over an old profile")
	if not is_instance_valid(city) or not city.unlocked():
		await _finish()
		return
	_check(city.model.mission_ids().size() == 3 and city.figures.size() == 3, "three published tasks and their visible original figures")
	var main_missions: int = STATE.MISSIONS.size() + world.open_world.model.mission_ids().size() + world.sonnenhafen.model.mission_ids().size() + world.waldheim.model.mission_ids().size() + city.model.mission_ids().size()
	_check(main_missions == 30, "World offers thirty regular missions outside its delivery errands")
	_check(city.model.cards().is_empty() and city.purchase_receipt().is_empty(), "an older save receives no invented cards or receipt")
	var actual_benches := 0
	for node in world.art.zones.Sternenstadt.get_children():
		actual_benches += int(node.has_meta("park_picnic_bench") and node is MeshInstance3D and node.visible)
	_check(actual_benches == 2, "exactly two actual park-table benches are visible in the scene")
	world.map_button.pressed.emit()
	await _frames(2)
	_check(world.overview.world_figures.size() == 9 and world.overview.region_figures.size() == 14 and world.overview.supplemental_figures.size() == 8,
		"the atlas still shows every original figure and all eight new residents")
	var journal: Button = world.modal_box.get_node_or_null("WorldMapSternenstadtJournal")
	_check(journal != null, "the actual map includes the city journal action")
	if journal != null:
		journal.pressed.emit()
		await _frames(2)
		_check(world.modal_box.has_node("JournalMission_stadtroute"), "the journal lists the route")
	world._close_dialog()
	await _navigate()
	await _observe()
	await _trade()
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(city.model.cards().size() == 3, "each finished mission awards a different single card")
	await _enter()
	_check(city.model.state("parkblick") == "done" and city.model.state("stadtroute") == "done" and city.model.state("marktlicht") == "done", "all three achievements restore")
	_check(city.model.cards().size() == 3 and city.purchase_receipt() == {"item":"Kleine Laterne","paid":4,"remaining":2},
		"the one receipt and the same three unique cards restore")
	_check(world.model.completed == LEARNED, "original chapter progress still restores")
	_check(world._save(), "the resumed World also saves")
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for section in ["waldheim","sonnenhafen","openWorld","friendPost"]:
		_check(before[section] == after[section], "the city is isolated from " + section)
	await _finish()


func _talk(id: String, finish: bool) -> void:
	var step: Dictionary = city.model.current_step(id)
	await _go_to(city.model.step_target(step))
	_check(not world.action_button.disabled and world.action_button.text == "Ansprechen", "resident is reachable for " + id)
	world.action_button.pressed.emit()
	await _frames(3)
	var choice: Button = world.modal_box.get_node_or_null("DialogChoice_0")
	_check(choice != null, "visible resident dialogue for " + id)
	if choice != null:
		choice.pressed.emit()
		await _frames(3)
	_check(city.model.state(id) == ("done" if finish else "active"), "resident accepts/reports the correct task for " + id)
	if world.paused:
		world._close_dialog()


func _navigate() -> void:
	await _talk("stadtroute", false)
	await _go_to(city.model.place("park_eingang").position)
	_check(int(city.model.progress.stadtroute) == 1, "starting at the last landmark cannot skip the other route stops")
	await _go_to(Vector3(183, 0, -17))
	world.camera_yaw = 0.0
	await _walk_to(Vector3(193, 0, -16))
	await _frames(18)
	_check(int(city.model.progress.stadtroute) == 2, "the real clinic forecourt is first")
	await _walk_to(Vector3(234, 0, -16))
	await _frames(18)
	_check(int(city.model.progress.stadtroute) == 3, "physically walking from the clinic reaches the market")
	await _walk_to(Vector3(234, 0, -54))
	await _frames(18)
	_check(int(city.model.progress.stadtroute) == 4, "physically walking from the market reaches the park")
	await _talk("stadtroute", true)


func _observe() -> void:
	await _talk("parkblick", false)
	await _go_to(city.model.step_target(city.model.current_step("parkblick")))
	_check(world.action_button.text == "Bänke ansehen", "the real park has the observation button")
	world.action_button.pressed.emit()
	await _frames(3)
	_press("ParkBaenke_3")
	await _frames(3)
	_check(int(city.model.progress.parkblick) == 1 and world.paused, "a mistaken count remains retryable")
	_press("ParkBaenke_2")
	await _frames(5)
	_check(int(city.model.progress.parkblick) == 2 and not world.paused, "the exact two existing benches advance the task")
	await _talk("parkblick", true)


func _trade() -> void:
	await _talk("marktlicht", false)
	var at: Vector3 = city.model.step_target(city.model.current_step("marktlicht"))
	await _go_to(at)
	_check(world.action_button.text == "Marktstand öffnen", "the real stand exposes a purchase")
	world.action_button.pressed.emit()
	await _frames(3)
	_press("StadtWare_0")
	await _frames(3)
	_check(city.purchase_receipt().is_empty() and int(city.model.progress.marktlicht) == 1, "irrelevant goods do not deduct the child's task budget")
	_press("StadtWare_1")
	await _frames(6)
	var expected := {"item":"Kleine Laterne","paid":4,"remaining":2}
	_check(city.purchase_receipt() == expected and int(city.model.progress.marktlicht) == 2, "six local tokens buy a four-token lantern and leave two")
	var closed_offer: Button = world.modal_box.get_node_or_null("StadtWare_1")
	if closed_offer != null:
		closed_offer.pressed.emit()
	world.action_button.pressed.emit()
	await _frames(4)
	var offer_visible: bool = world.modal.visible and world.modal_box.has_node("StadtWare_1")
	_check(city.purchase_receipt() == expected and int(city.model.progress.marktlicht) == 2 and not offer_visible,
		"input on the closed offer or market stand cannot repeat the transaction")
	await _enter()
	_check(city.purchase_receipt() == expected and int(city.model.progress.marktlicht) == 2, "the transaction and active delivery survive a restart")
	await _talk("marktlicht", true)


func _press(id: String) -> void:
	var button: Button = world.modal_box.get_node_or_null(id)
	_check(button != null, "the actual dialog offers " + id)
	if button != null:
		button.pressed.emit()


func _go_to(at: Vector3) -> void:
	world.player.position = at + Vector3.UP * 0.08
	world.player.velocity = Vector3.ZERO
	await _frames(16)


func _walk_to(destination: Vector3) -> void:
	for index in range(900):
		var delta: Vector3 = destination - world.player.position
		var direction := Vector2(delta.x, delta.z)
		if direction.length() < 1.6:
			break
		world.joystick.target = direction.normalized()
		await physics_frame
	world.joystick.target = Vector2.ZERO
	world.joystick.axis = Vector2.ZERO
	_check(world.player.position.distance_to(destination) < 2.5 and world.player.is_on_floor(),
		"normal input reaches grounded city landmark at %.0f,%.0f (ended %.1f,%.1f)" %
		[destination.x, destination.z, world.player.position.x, world.player.position.z])


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	DirAccess.remove_absolute(path)
	_check(await TEARDOWN.release(self, "[SternenstadtRegression]"), "closes the real World and releases audio")
	print("[SternenstadtRegression] %s %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
