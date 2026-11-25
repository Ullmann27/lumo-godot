extends SceneTree
## Uses the production World, real model clips, dialog buttons, labels and
## collision space. Requires imported assets and Godot; not a device-FPS test.
const PROFILE := "lumo_2082_world_routines"
var checks := 0
var failures: Array[String] = []
var world_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[WorldRoutinesIntegration] " + label)


func _run() -> void:
	world_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	root.size = Vector2i(720, 1280)
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": false}
	router.goto("world")
	await _frames(90)
	var scene: Node = current_scene
	_check(is_instance_valid(scene) and scene.name == "LumoWorld", "production World opens")
	if not is_instance_valid(scene) or scene.name != "LumoWorld":
		await _finish()
		return
	var layer: Node = scene.open_world
	_check(layer.unlocked() and layer.figures.size() == 9, "all nine original NPCs are present")
	var start_positions: Dictionary = {}
	for id in layer.figures:
		start_positions[id] = layer.figures[id].position
		var player: AnimationPlayer = layer.figure_players[id]
		_check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "NPC animation obeys World pause: " + str(id))
		var role: Label3D = layer.get_node("FigureRole_" + str(id))
		_check(role.text.begins_with("Computerfigur") and role.text.contains("Morgen:"), "visible original role includes the current activity: " + str(id))
	await _frames(12)
	for id in layer.figures:
		if str(layer.figure_walk_clips.get(id, "")).is_empty():
			_check(layer.figures[id].position == start_positions[id], "seated rig remains stationary without an authored walk: " + str(id))

	scene._open_dialog("Pause", "Die Welt wartet.")
	var before_time: float = layer.routines.elapsed
	var before_animation: float = layer.figure_players["owl"].current_animation_position
	await _frames(8)
	_check(layer.routines.elapsed == before_time, "general pause freezes the day")
	_check(layer.figure_players["owl"].current_animation_position == before_animation, "general pause freezes NPC animation")
	scene._close_dialog()

	scene.player.position = layer.model.figure("owl").position + Vector3(0, 0.1, -1.5)
	scene.player.velocity = Vector3.ZERO
	scene.last_safe = scene.player.position
	scene.joystick.axis = Vector2.ZERO
	scene.joystick.target = Vector2.ZERO
	await _frames(6)
	scene.action_button.pressed.emit()
	await _frames(2)
	_check(scene.modal.has_meta("open_world_dialog"), "actual interaction opens the NPC dialog")
	var progress: Dictionary = layer.model.progress.duplicate(true)
	await _press(scene, "Über deinen Alltag sprechen")
	_check(str(layer.runner.view().get("id", "")) == "routine", "routine is accessible before completing the quest")
	await _press(scene, "Zum Auftrag")
	_check(layer.dialog_mission == "flaschenpost", "routine returns to the still-pending mission")
	await _press(scene, "Über deinen Alltag sprechen")
	var held_at: Vector3 = layer.figures["owl"].position
	var held_time: float = layer.routines.elapsed
	await _frames(12)
	_check(layer.figures["owl"].position == held_at and layer.routines.elapsed == held_time, "conversation keeps the NPC and day still")
	await _press(scene, "Was interessiert dich?")
	_check(str(layer.runner.view().get("text", "")).contains("Meer"), "owl explains its own interest")
	await _press(scene, "Was können wir gemeinsam lernen?")
	_check(str(layer.runner.view().get("text", "")).contains("Die Flaschenpost am Hafen"), "conversation points to a real learning mission")
	await _press(scene, "Lernauftrag auf der Karte verfolgen")
	_check(layer.model.tracked == "flaschenpost", "actual button follows that mission")
	_check(not scene.modal.has_meta("open_world_dialog") and not scene.paused, "following the task closes the conversation cleanly")
	_check(layer.model.progress == progress and layer.model.cards().is_empty(), "routine conversations do not forge achievements")
	var target: Dictionary = layer.tracked_route()
	_check(target.at == layer.figures["owl"].position, "mission marker uses the current NPC position")
	var entries: Array[Dictionary] = layer.map_figures()
	for entry in entries:
		if str(entry.name) == str(layer.model.figure("owl").name):
			_check(entry.at == layer.figures["owl"].position, "map uses the current NPC position")

	# A synthetic wall in real production physics verifies the local walking
	# gate independently of the current seated assets, which cannot walk.
	var origin: Vector3 = layer.figure_homes["owl"]
	var wall := StaticBody3D.new()
	wall.name = "RoutineMotionFixture"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.15, 2.0, 1.0)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = origin + Vector3(0.8, 1.0, 0)
	scene.add_child(wall)
	await _frames(3)
	_check(layer._safe_local_step(origin, origin + Vector3.RIGHT * 1.2) == origin, "local NPC travel cannot cross a real wall")
	wall.queue_free()
	await _frames(3)
	scene._open_dialog("Pause", "Die Welt wartet.")
	var paused_again: float = layer.figure_players["owl"].current_animation_position
	await _frames(5)
	_check(layer.figure_players["owl"].current_animation_position == paused_again, "closed NPC conversation cannot leak animation into another pause")
	await _finish()


func _button(scene: Node, label: String) -> Button:
	for node in scene.modal_box.find_children("*", "Button", true, false):
		if node.text == label and not node.is_queued_for_deletion():
			return node
	return null


func _press(scene: Node, label: String) -> void:
	var button := _button(scene, label)
	_check(button != null and not button.disabled, "actual dialog button is available: " + label)
	if button == null or button.disabled:
		return
	_check(button.size.x >= 48.0 and button.size.y >= 48.0, "dialog retains large touch targets: " + label)
	button.pressed.emit()
	await _frames(2)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	_check(await preload("res://scripts/tests/lumo_scene_teardown.gd").release(self, "[WorldRoutinesIntegration]"), "production scene/audio released")
	DirAccess.remove_absolute(world_path)
	print("[WorldRoutinesIntegration] %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
