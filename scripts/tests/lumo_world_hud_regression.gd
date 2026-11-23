extends SceneTree
## Exercises real interaction-label changes after physics and layout frames.
## A manual _layout call would hide the delayed text-minimum regression.
const PROFILE := "lumo_world_hud_regression_20261123"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorldHUD] " + label)


func _run() -> void:
	var world_path := "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {
		"childKey": PROFILE,
		"grade": 2,
		"reduceAnimations": true,
	}
	var scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	_check(not scene.save_blocked, "isolated World fixture is playable")
	_check(scene.model.current().id == "meet_nelli", "fixture starts at the real conversation mission")
	_check(not scene.portals.is_empty(), "real World portals are present")
	if scene.portals.is_empty():
		scene.queue_free()
		await process_frame
		DirAccess.remove_absolute(world_path)
		_finish()
		return
	for dimensions in [Vector2i(344, 882), Vector2i(640, 360), Vector2i(720, 1280), Vector2i(1280, 720)]:
		root.size = dimensions
		# Real mission proximity updates the production label during physics.
		scene.player.position = scene.model.current().at + Vector3(2, 0.2, 0)
		scene.player.velocity = Vector3.ZERO
		await _settle()
		_assert_hud(scene, "Ansprechen", "%s conversation" % dimensions)
		scene.player.position = scene.portals[0].at + Vector3.UP * 0.2
		scene.player.velocity = Vector3.ZERO
		await _settle()
		_assert_hud(scene, "Ort öffnen", "%s portal" % dimensions)
		# Grow the label again without a resize or a direct layout invocation.
		scene.player.position = scene.model.current().at + Vector3(2, 0.2, 0)
		scene.player.velocity = Vector3.ZERO
		await _settle()
		_assert_hud(scene, "Ansprechen", "%s conversation again" % dimensions)
		# The reported portrait capture showed the same label disabled at school.
		scene.player.position = Vector3(110, 0.2, -24)
		scene.player.velocity = Vector3.ZERO
		await _settle()
		_assert_hud(scene, "Ansprechen", "%s distant interaction" % dimensions, false)
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(world_path)
	_finish()


func _assert_hud(scene, expected_text: String, context: String, expected_enabled: bool = true) -> void:
	_check(scene.action_button.text == expected_text, context + ": real interaction text is complete")
	_check(scene.action_button.disabled != expected_enabled, context + ": interaction availability matches real proximity")
	var area := Rect2(Vector2.ZERO, scene.safe_ui.size)
	var buttons: Array[Button] = [scene.action_button, scene.vehicle_button, scene.run_button, scene.map_button, scene.exit_button]
	for button in buttons:
		var label := context + ": " + button.text
		_check(button.size.x >= 48 and button.size.y >= 48, label + " retains a 48px touch target")
		_check(area.encloses(button.get_rect()), label + " stays fully inside the safe area")
		_check(button.get_rect().end.x <= area.end.x - 8, label + " keeps a visible right inset")
		_check(not button.clip_text, label + " preserves the full label without clipping")
		_check(not button.get_rect().intersects(scene.joystick.get_rect()), label + " does not cover the movement stick")
	_check(not scene.action_button.get_rect().intersects(scene.vehicle_button.get_rect()), context + ": action and vehicle controls do not overlap")
	_check(not scene.vehicle_button.get_rect().intersects(scene.run_button.get_rect()), context + ": vehicle and movement controls do not overlap")
	_check(not scene.map_button.get_rect().intersects(scene.exit_button.get_rect()), context + ": map and pause controls do not overlap")
	_check(not scene.mission_panel.get_rect().intersects(scene.map_button.get_rect()), context + ": mission text does not cover the map control")


func _settle() -> void:
	for index in range(3):
		await physics_frame
		await process_frame
	await process_frame
	await process_frame


func _finish() -> void:
	print("[LumoWorldHUD] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
