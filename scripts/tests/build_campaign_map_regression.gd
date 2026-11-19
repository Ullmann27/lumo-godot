extends SceneTree
## Bauwelt HUD and 3D campaign map: data-driven chapter states, read-only
## map (saves stay byte-identical), 48 px stations, chapter entry, map
## lifecycle and the free-build HUD chips plus tappable mini overview.
const MODEL = preload("res://scripts/creative/build_settlement_state.gd")
const CHILD := "campaign_map_regression"
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[CampaignMap] " + message)


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await process_frame


func _clear() -> void:
	DirAccess.remove_absolute("user://lumo_build_%s_1.json" % CHILD)
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	DirAccess.remove_absolute(world_script.project_path(CHILD, 1, "village"))


func _run() -> void:
	_data_checks()
	root.size = Vector2i(1280, 720)
	_clear()
	await _village_checks()
	await _build_hud_checks()
	_clear()
	if failures.is_empty():
		print("[CampaignMap] PASS checks=%d" % checks)
		quit(0)
	else:
		print("[CampaignMap] FAIL %d of %d" % [failures.size(), checks])
		quit(1)


func _data_checks() -> void:
	var city = MODEL.new("settlement", true)
	var chapters: Array = city.campaign_overview()
	check(chapters.size() == 12, "Overview lists all twelve chapters")
	check(str(chapters[0].state) == "current", "Fresh village starts at chapter one")
	var locked := 0
	for chapter in chapters:
		if str(chapter.state) == "locked":
			locked += 1
		check(not str(chapter.title).is_empty() and chapter.get("goals", []).size() > 0,
			"Chapter %d has a title and goals" % int(chapter.chapter))
	check(locked == 11, "Eleven chapters are locked at the start")
	check(str(chapters[0].title) == str(city.campaign_status().title), "Map and chapter dialog agree")
	var before: Dictionary = city.snapshot()
	city.campaign_overview()
	check(city.snapshot() == before, "Reading the overview changes nothing")
	city._player.campaign_chapter = 3
	var later: Array = city.campaign_overview()
	check(str(later[2].state) == "done" and str(later[3].state) == "current"
		and str(later[4].state) == "locked", "States follow the saved chapter index")
	city._player.campaign_chapter = 12
	var finished: Array = city.campaign_overview()
	var all_done := true
	for chapter in finished:
		all_done = all_done and str(chapter.state) == "done"
	check(all_done, "A finished campaign shows twelve golden stations")
	check(MODEL.new("settlement", false).campaign_overview().is_empty(), "Classic Siedlung has no map data")


func _village_checks() -> void:
	root.get_node("SceneRouter").launch_options = {
		"childKey": CHILD, "settlementMode": "settlement", "livingVillage": true, "buildSlot": 1
	}
	var village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	var map_button: Button = village.find_child("VillageCampaignMap", true, false)
	check(map_button != null and map_button.get_parent().name == "VillagePrimaryActions",
		"The map button is permanently visible next to Kapitel")
	check(map_button != null and map_button.size.y >= 48.0, "Map button is a 48 px touch target")
	village._save()
	var saved := FileAccess.get_file_as_string(village.save_path)
	var snapshot: Dictionary = village.model.snapshot()
	map_button.pressed.emit()
	await _frames(6)
	var map: Control = village.campaign_map
	check(is_instance_valid(map), "Tapping Karte opens the campaign map")
	check(root.disable_3d, "The village 3D view pauses behind the map")
	if is_instance_valid(map):
		check(map.badges.size() == 12, "Twelve stations are placed on the map")
		for badge in map.badges:
			check(badge.size.x >= 48.0 and badge.size.y >= 48.0, "Station %s is a 48 px target" % badge.text)
		var visible := 0
		for badge in map.badges:
			if Rect2(Vector2.ZERO, map.size).has_point(badge.position + badge.size * 0.5):
				visible += 1
		check(visible == 12, "All twelve stations are on screen in landscape")
		map.badges[5].pressed.emit()
		await _frames()
		check(map.selected == 5 and map.action_button.disabled, "A locked chapter cannot be entered")
		map.badges[0].pressed.emit()
		await _frames()
		check(map.selected == 0 and not map.action_button.disabled, "The open chapter can be entered")
		map.action_button.pressed.emit()
		await _frames(6)
		check(not is_instance_valid(village.campaign_map), "Entering a chapter closes the map")
		check(not root.disable_3d, "The village 3D view resumes")
		check(is_instance_valid(village.village_window), "Entering shows the chapter story")
		if is_instance_valid(village.village_window):
			village.village_window.queue_free()
			await _frames()
	check(village.model.snapshot().player.campaign_chapter == snapshot.player.campaign_chapter,
		"The map never changes the campaign")
	check(FileAccess.get_file_as_string(village.save_path) == saved, "The village save stays byte-identical")
	village.open_campaign_map()
	await _frames(3)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	village._unhandled_input(cancel)
	await _frames(3)
	check(not is_instance_valid(village.campaign_map) and not village.paused, "Back closes the map first")
	village.queue_free()
	await _frames(3)
	check(not root.disable_3d, "Leaving the village never leaves 3D disabled")


func _build_hud_checks() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": CHILD}
	var build = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(build)
	await _frames(10)
	check(build.hud_chips.size() == 5, "Free build shows five resource chips")
	var pieces_value: Label = build.hud_chips.pieces.get_meta("value")
	check(pieces_value.text == str(build.model.pieces.size()), "Part chip shows the real part count")
	check(is_instance_valid(build.minimap) and build.minimap.visible, "Mini overview is visible in landscape")
	check(build.minimap.size.x >= 48.0, "Mini overview is a usable touch target")
	build.minimap.picked.emit(Vector2(40.0, -30.0))
	await _frames()
	check(is_equal_approx(build.focus.x, 40.0) and is_equal_approx(build.focus.z, -30.0),
		"Tapping the overview moves the camera there")
	var selected: Button = build.part_buttons.get(build.chosen)
	check(selected != null and selected.get_theme_stylebox("normal").bg_color == build.HUD.face("primary"),
		"The chosen part is highlighted")
	var kampagne: Button = null
	for node in build.tool_actions.get_children():
		if node is Button and node.text == "Kampagne":
			kampagne = node
	check(kampagne != null, "Free build offers the campaign entry")
	build.queue_free()
	await _frames(3)
