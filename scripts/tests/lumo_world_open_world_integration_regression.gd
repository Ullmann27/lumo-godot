extends SceneTree
## Real World scene, original models, actual dialog buttons, mission observation,
## card journal and save/re-entry. Positions are fixtures between encounters;
## the separate first-entry/ground probes verify the real driven kart journey.
const PROFILE := "lumo_2081_open_world_integration"
const CHOICES := {
	"owl_bottle_start": ["Ja, ich gehe zum Hafen!"],
	"turtle_bottle_read": ["Nachricht lesen", "Zur Bücherei"],
	"owl_bottle_end": ["Ja, gern!"],
	"cat_show_card": ["Karte der Schildkröte zeigen", "Ich spreche mit Nova"],
	"rabbit_cheer": ["Verlieren gehört dazu. Spielst du noch eine Runde mit mir?", "Ich gehe zum Kartensalon"],
	"cat_report": ["Danke, Mika und Nova!"],
	"otter_courier_start": ["Ja, ich fahre hin!", "Verstanden, ich fahre vorsichtig"],
	"badger_baskets": ["Ja, ich zähle mit", "20"],
	"lion_market_start": ["Ja, ich helfe!"],
	"squirrel_count": ["Ich zähle mit dir", "23"],
	"lion_market_end": ["Danke, Löwe!"],
}
var checks := 0
var failures: Array[String] = []
var world_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[LumoOpenWorldIntegration] " + label)


func _run() -> void:
	world_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	root.size = Vector2i(720, 1280)
	var scene: Node = await _enter_world()
	_check(scene != null and not scene.save_blocked, "real router opens the integrated World")
	if scene == null:
		_finish()
		return
	var layer: Node = scene.open_world
	_check(layer.unlocked(), "the actual open-world layer is unlocked")
	_check(layer.figures.size() == 9, "all nine original figures are instantiated")
	_check(layer.model.content.places.size() == 7, "all seven places are present")
	for entry in layer.model.content.figures:
		var id := str(entry.id)
		_check(layer.figures.has(id), "original figure is loaded: " + id)
		if not layer.figures.has(id):
			continue
		var actor: Node = layer.figures[id]
		_check(actor.has_node("OriginalRosterModel"), "original roster model retained: " + id)
		_check(not actor.find_children("*", "MeshInstance3D", true, false).is_empty(), "figure has actual mesh geometry: " + id)
		_check(layer.get_node("FigureRole_" + id).text.begins_with("Computerfigur"), "honest role label: " + id)
		_check(layer.figure_players.has(id), "figure has original animation player: " + id)
		var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
		var at: Vector3 = entry.position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN))
		_check(not hit.is_empty(), "figure stands over real floor: " + id)
	_check(layer.model.cards().is_empty(), "new child receives no unearned cards")
	await _move_player(scene, layer.model.figure("cat").position)
	scene.action_button.pressed.emit()
	await _frames(2)
	var locked := _button(scene, "Karte der Schildkröte zeigen (Karte fehlt noch)")
	_check(locked != null and locked.disabled, "real dialog disables the unearned prerequisite card")
	scene._close_dialog()
	await _frames(2)
	await _journal(scene, 0)
	for mission_id in ["flaschenpost", "kartenclub", "kart_kurier", "markt_aepfel"]:
		var steps: Array = layer.model.mission(mission_id).steps
		for step in steps:
			var before := int(layer.model.progress[mission_id])
			if str(step.kind) in ["talk", "show_card"]:
				await _talk(scene, step, mission_id)
			elif str(step.kind) == "visit":
				await _move_player(scene, layer.model.place(str(step.place)).position)
				await _frames(24)
			else:
				await _drive_arrival(scene, layer.model.place(str(step.place)).position)
			_check(int(layer.model.progress[mission_id]) == before + 1, "real scene advances exactly one step: %s/%s" % [mission_id, step.id])
			if scene.paused:
				scene._close_dialog()
				await _frames(2)
		_check(layer.model.state(mission_id) == "done", "actual scene completes chain: " + mission_id)
	_check(layer.model.cards().size() == 9, "all nine cards earned through real scene/UI")
	_check(scene.model.completed.is_empty(), "independent school/story progress is not forged")
	await _journal(scene, 9)
	await _frames(24)
	var saved: Dictionary = layer.to_data().duplicate(true)
	_check(scene._save(), "actual World save writes the integrated mission state")
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world_path))
	var encoded_saved = JSON.parse_string(JSON.stringify(saved))
	_check(file.get("openWorld") == encoded_saved, "mission/card state is in the real World save")
	scene = await _enter_world()
	_check(scene != null and not scene.save_blocked, "saved integrated World reopens")
	if scene != null:
		_check(scene.open_world.to_data() == saved, "all progress/cards restored exactly after route re-entry")
		_check(scene.open_world.model.cards().size() == 9, "re-entry duplicates no cards")
		await _journal(scene, 9)
	DirAccess.remove_absolute(world_path)
	_finish()


func _enter_world() -> Node:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	router.goto("world")
	await _frames(90)
	return current_scene if is_instance_valid(current_scene) and current_scene.name == "LumoWorld" else null


func _move_player(scene: Node, at: Vector3) -> void:
	if scene.paused:
		scene._close_dialog()
	if scene.driving:
		scene.vehicle_button.pressed.emit()
		await _frames(4)
	_check(not scene.driving, "dialog/visit fixture remains on foot")
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	scene.player.position = at + Vector3(0, 0.15, 1.6)
	scene.player.velocity = Vector3.ZERO
	scene.last_safe = scene.player.position
	await _frames(3)


func _talk(scene: Node, step: Dictionary, mission_id: String) -> void:
	await _move_player(scene, scene.open_world.model.figure(str(step.figure)).position)
	scene.action_button.pressed.emit()
	await _frames(2)
	_check(scene.paused and scene.modal.has_meta("open_world_dialog"), "actual action button opens conversation: " + str(step.dialog))
	if not scene.modal.has_meta("open_world_dialog"):
		return
	var labels: Array = CHOICES[str(step.dialog)]
	for index in range(labels.size()):
		if str(step.dialog) == "squirrel_count" and index == 1:
			var before := int(scene.open_world.model.progress[mission_id])
			await _press(scene, "13")
			_check(int(scene.open_world.model.progress[mission_id]) == before, "wrong visible answer grants no progress/card")
			await _press(scene, "Noch einmal rechnen")
		await _press(scene, str(labels[index]))


func _drive_arrival(scene: Node, at: Vector3) -> void:
	if scene.paused:
		scene._close_dialog()
	if not scene.driving:
		scene.player.position = scene.kart_body.position + Vector3(0, 0.1, 2.5)
		scene.last_safe = scene.player.position
		await _frames(3)
		scene.vehicle_button.pressed.emit()
		await _frames(3)
	_check(scene.driving, "actual entry button enables the drive mission")
	scene.kart_body.position = at + Vector3(0, 0.2, 1)
	scene.kart_body.velocity = Vector3.ZERO
	scene.drive_speed = 0.0
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	await _frames(28)


func _button(scene: Node, label: String) -> Button:
	for node in scene.modal_box.find_children("*", "Button", true, false):
		if node.text == label and not node.is_queued_for_deletion():
			return node
	return null


func _press(scene: Node, label: String) -> void:
	var button := _button(scene, label)
	_check(button != null and not button.disabled, "enabled actual choice: " + label)
	if button == null or button.disabled:
		return
	_check(button.size.x >= 48.0 and button.size.y >= 48.0, "choice retains 48-dp target: " + label)
	button.pressed.emit()
	await _frames(2)


func _journal(scene: Node, owned: int) -> void:
	if scene.paused:
		scene._close_dialog()
	scene.map_button.pressed.emit()
	await _frames(3)
	_check(scene.overview.world_figures.size() == 9, "World map contains all nine added figures")
	await _press(scene, "Aufträge & Figurenkarten")
	_check(scene.modal.has_meta("open_world_journal"), "map opens actual mission/card journal")
	var album: Node = scene.modal_box.get_node_or_null("CardAlbum")
	_check(album != null and album.get_child_count() == 9, "visible journal contains nine card panels")
	_check(scene.open_world.model.cards().size() == owned, "journal opening leaves card ownership unchanged")
	for mission_id in ["flaschenpost", "kartenclub", "kart_kurier", "markt_aepfel"]:
		_check(scene.modal_box.has_node("JournalMission_" + mission_id), "journal includes chain: " + mission_id)
	scene._close_dialog()
	await _frames(2)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	_check(await preload("res://scripts/tests/lumo_scene_teardown.gd").release(self, "[LumoOpenWorldIntegration]"), "production scene and audio playbacks are released")
	print("[LumoOpenWorldIntegration] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
