extends SceneTree
## The production save model and atlas, without 3D assets or profile autoloads.
## The full scene re-entry regression remains in lumo_world_device_regression.gd.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const MAP = preload("res://scripts/creative/lumo_world_map.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[WorldKartPersistence] " + label)


func _run() -> void:
	var model = STATE.new()
	var legacy: Dictionary = model.to_data()
	legacy.erase("kart")
	legacy.position = [220, 0.2, 8]
	legacy.completed = ["meet_nelli"]
	_check(model.restore(legacy), "a pre-fix version-one save still opens")
	_check(model.position.is_equal_approx(Vector3(220, 0.2, 8)), "legacy player location is preserved")
	_check(model.completed == ["meet_nelli"], "legacy mission progress is preserved")
	_check(model.kart_position == STATE.KART_SPAWN and is_zero_approx(model.kart_yaw), "legacy kart defaults to its original parking place")
	var city_parking := Vector3(218, 0.2, 8)
	_check(model.remember_kart(city_parking, TAU - 1.1, true), "a grounded city parking pose is accepted")
	_check(is_equal_approx(model.kart_yaw, -1.1), "a repeated-turn heading is normalized")
	var path := "user://lumo_world_kart_persistence_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "isolated save file opens")
	if file == null:
		_finish()
		return
	file.store_string(JSON.stringify(model.to_data()))
	file.close()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var returned = STATE.new()
	_check(returned.restore(saved), "the saved world restores into a fresh state instance")
	_check(returned.kart_position.is_equal_approx(city_parking), "kart parking survives the real JSON file round trip")
	_check(is_equal_approx(returned.kart_yaw, -1.1), "kart heading survives the real JSON file round trip")
	_check(returned.position.distance_to(returned.kart_position) < 5.0, "the saved walking return remains within normal kart entry distance")
	var unchanged := JSON.stringify(returned.to_data())
	for at in [Vector3(NAN, 0, 0), Vector3(2000, 0, 0), Vector3(218, -5, 8), Vector3(218, 181, 8)]:
		_check(not returned.remember_kart(at, 0, true), "invalid kart positions are not persisted")
		_check(JSON.stringify(returned.to_data()) == unchanged, "invalid live pose retains the last usable parking place")
	_check(not returned.remember_kart(city_parking, INF, true), "non-finite live heading is rejected")
	_check(not returned.remember_kart(Vector3(0, 0.2, 70), 0, false), "early fall without floor contact is rejected even at a valid height")
	_check(JSON.stringify(returned.to_data()) == unchanged, "an early fall retains the last grounded parking pose")
	for invalid in [
		{}, null, {"position": [1, 2], "yaw": 0}, {"position": [218, "up", 8], "yaw": 0},
		{"position": [2000, 0, 0], "yaw": 0}, {"position": [218, -5, 8], "yaw": 0},
		{"position": [218, 0.2, 8], "yaw": "left"}, {"position": [218, 0.2, 8], "yaw": INF}
	]:
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.kart = invalid
		_check(not returned.restore(corrupt), "malformed optional kart data is rejected")
		_check(JSON.stringify(returned.to_data()) == unchanged, "a rejected restore cannot partly replace the world")
	DirAccess.remove_absolute(path)
	await _atlas(returned)
	_finish()


func _atlas(model) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scroll)
	var atlas = MAP.new()
	scroll.add_child(atlas)
	atlas.configure(STATE.BOUNDS, model.position, 0.0, {}, model.completed, STATE.MISSIONS, [], true)
	_check(atlas.focus_buttons.kart.disabled, "a map without a supplied kart has no stale location action")
	atlas.set_kart_position(model.kart_position)
	_check(not atlas.focus_buttons.kart.disabled, "actual parking data enables the kart action")
	var before := JSON.stringify(model.to_data())
	for dimensions in [Vector2i(280, 640), Vector2i(360, 800), Vector2i(720, 840), Vector2i(1384, 1400)]:
		root.size = dimensions
		await _frames(4)
		var button: Button = atlas.focus_buttons.kart
		scroll.ensure_control_visible(button)
		await _frames(3)
		_check(button.size.x >= 48 and button.size.y >= 48, "kart action keeps a 48-unit target at %s" % dimensions)
		_check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= dimensions.x + 0.1, "kart action fits the available width at %s" % dimensions)
		var center := button.get_global_rect().get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = center
			event.global_position = center
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
		_check(atlas.focus_id == "kart", "actual input opens the kart view at %s" % dimensions)
		_check(atlas.view_bounds.has_point(Vector2(model.kart_position.x, model.kart_position.z)), "kart view includes the restored parking place")
		_check(atlas.focus_label.text.contains("Sternenstadt"), "kart location uses the actual world place name")
		atlas.focus_player()
	_check(JSON.stringify(model.to_data()) == before, "map inspection leaves saved location and missions unchanged")
	atlas.set_kart_position(Vector3(INF, 0, 0))
	_check(atlas.focus_buttons.kart.disabled, "invalid map positions disable the kart action")
	var retained: Rect2 = atlas.view_bounds
	atlas.focus_kart()
	_check(atlas.view_bounds == retained, "invalid kart focus cannot move the map")
	scroll.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _finish() -> void:
	print("[WorldKartPersistence] %s %d checks engine=%s scope=state_and_atlas" % ["PASS" if failures.is_empty() else "FAIL", checks, Engine.get_version_info().string])
	quit(0 if failures.is_empty() else 1)
