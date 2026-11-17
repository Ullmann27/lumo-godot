extends SceneTree
## A direct Flutter "Dorf & Wirtschaft" request must survive Android -> HostBridge -> Boot.
const BRIDGE = preload("res://scripts/systems/host_bridge.gd")
# Native Java API method names intentionally match the actual bridge contract.
# gdlint: disable=function-name


class TestHost:
	extends Node
	var accept_return := false
	var returns: Array[Dictionary] = []

	func returnToApp(destination: String, payload: String) -> int:
		returns.append({"destination": destination, "payload": JSON.parse_string(payload)})
		return 1 if accept_return else 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var good := BRIDGE.validated_options({
		"game": "settlement",
		"livingVillage": true,
		"settlementMode": "settlement",
		"grade": 2,
		"subject": "Mathematik",
		"childKey": "child-test",
		"buildSlot": 3
	})
	if good.get("scene", "") != "settlement":
		errors.append("Economic village was silently rerouted away from settlement")
	if good.get("livingVillage", false) != true:
		errors.append("Validated launch lost explicit village request")
	if good.get("childKey") != "child-test" or good.get("grade") != 2:
		errors.append("Original child identity or grade was lost")
	# Boot references global EventBus; compiling it from a SceneTree test
	# fails before project autoloads exist. Source-gate its registered maps
	# while the project import independently compiles the production scene.
	var boot_text := FileAccess.get_file_as_string("res://scripts/app/app_boot.gd")
	var cover_section := boot_text.get_slice("const COVER_BY_SCENE: Dictionary = {", 1).get_slice("}", 0)
	var title_section := boot_text.get_slice("const TITLE_BY_SCENE: Dictionary = {", 1).get_slice("}", 0)
	if not title_section.contains('"settlement":'):
		errors.append("Android boot does not label this new village scene")
	if not cover_section.contains('"settlement":'):
		errors.append("Village opening lacks a real game cover")
	var boot_selector := boot_text.get_slice('var target: String = requested if requested in [', 1).get_slice(']', 0)
	if not boot_selector.contains('"settlement"'):
		errors.append("Native boot cannot load the settlement scene")
	if not root.get_node("SceneRouter").SCENES.has("settlement"):
		errors.append("SceneRouter lacks the real settlement scene")
	var forbidden := BRIDGE.validated_options({
		"game": "settlement", "livingVillage": false
	})
	if forbidden.get("scene") == "settlement":
		errors.append("Unsupported classic settlement should not be launched from the village portal")
	await _check_actual_return_context(errors, good)
	if not errors.is_empty():
		for item in errors:
			printerr("[VillageHost] FAIL " + item)
		quit(1)
		return
	print("[VillageHost] PASS Flutter village request, native boot scene and child context")
	quit(0)


func _check_actual_return_context(errors: Array[String], options: Dictionary) -> void:
	var bridge := root.get_node("HostBridge")
	var router := root.get_node("SceneRouter")
	var fake := TestHost.new()
	root.add_child(fake)
	bridge.set("_host", fake)
	var launch := options.duplicate(true)
	launch["sessionId"] = "village-direct-host-return"
	bridge.set("_options", launch.duplicate(true))
	router.set("launch_options", launch.duplicate(true))
	var packed := load("res://scenes/creative/build_settlement_world.tscn") as PackedScene
	var village: Node3D = packed.instantiate()
	root.add_child(village)
	await process_frame
	await process_frame
	var save_path: String = village.get("save_path")
	var back := village.find_child("SettlementReturn", true, false) as Button
	if (village.get("host_entry") != true or village.get("return_scene") != "games"
		or back == null or back.text != "‹ Spiele"):
		errors.append("Direct Flutter village entry lacks a visible return to host games")
	else:
		var build_return := village.find_child("SettlementBuildReturn", true, false) as Button
		if build_return == null or build_return.text != "Zur Bauwelt":
			errors.append("The existing Bauwelt route must remain available in the pause menu")
		village.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		if village.get("paused") != true or not fake.returns.is_empty():
			errors.append("Android Back must pause and save before a visible return action")
		village.call("_toggle_pause")
		var snapshot: Dictionary = village.get("model").snapshot()
		back.pressed.emit()
		if fake.returns.size() != 1 or bridge.get("_return_pending") != false:
			errors.append("A refused Android return must remain retryable")
		if not village.is_inside_tree() or router.get("current_scene_id") != "settlement":
			errors.append("A refused host return replaced the playable village")
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		var restored = village.restore_project(saved, options.childKey, options.buildSlot, "settlement")
		if restored == null or restored.snapshot() != snapshot:
			errors.append("Visible return must first save the actual child's unchanged village")
		village.set("save_path", "user://missing-village-test-directory/unsaved.json")
		back.pressed.emit()
		if fake.returns.size() != 1:
			errors.append("Failed village persistence must block the host return")
		village.set("save_path", save_path)
		fake.accept_return = true
		back.pressed.emit()
		if fake.returns.size() != 2 or bridge.get("_return_pending") != true:
			errors.append("The same visible return must accept a later genuine Android ACK")
		elif (fake.returns[1].destination != "games"
			or fake.returns[1].payload.get("sessionId") != launch.sessionId):
			errors.append("The direct village return lost its host destination or session")
		if village.get("model").snapshot() != snapshot:
			errors.append("Returning to Flutter changed village progress")
	village.queue_free()
	await process_frame
	await process_frame
	bridge.set("_return_pending", false)
	bridge.set("_options", BRIDGE.validated_options({"game": "games"}))
	router.set("launch_options", options.duplicate(true))
	village = packed.instantiate()
	root.add_child(village)
	await process_frame
	back = village.find_child("SettlementReturn", true, false) as Button
	if (village.get("host_entry") != false or village.get("return_scene") != "build"
		or back == null or back.text != "‹ Bauwelt"):
		errors.append("A native Hub/Bauwelt entry must retain its existing Bauwelt return")
	village.queue_free()
	await process_frame
	await process_frame
	bridge.set("_host", null)
	bridge.set("_options", {})
	fake.queue_free()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
