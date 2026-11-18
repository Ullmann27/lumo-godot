extends SceneTree
## Engine pictures of the Lumo Kart race HUD and controls (needs a renderer):
## races in landscape, portrait, small phone and Fold, plus a sheet of every button state.
## Output: $KART_HUD_OUT (default user://kart_hud_capture).

const ACTION = preload("res://scripts/games/kart_touch_action.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const ITEM_HUD = preload("res://scripts/games/kart_items/kart_item_hud.gd")
var game
var output: String = OS.get_environment("KART_HUD_OUT")


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for frame in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file: String) -> void:
	var path: String = output.path_join(file)
	var error: int = root.get_texture().get_image().save_png(path)
	print("capture %s %s" % [path, "ok" if error == OK else "FAILED"])


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	if output.is_empty():
		output = "user://kart_hud_capture"
	DirAccess.make_dir_recursive_absolute(output)
	var only: String = OS.get_environment("KART_HUD_ONLY")
	if only.is_empty() or only == "sheet":
		await _state_sheet()
	if only.is_empty() or only == "race":
		await _race_shots()
	quit()


func _race_shots() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "candy_cloud", "difficulty": "gemuetlich"})
	game._end_preview()
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.modal.hide()
	# Drive for real for a few seconds so the field spreads and the speed is genuine.
	for frame in range(150):
		await physics_frame
	game.item = "star_rocket"
	game.item_charges = 2
	game.boosts = 2
	game.item_hint = ""
	game.message.text = "Turbo-Feld!"
	var shots: Array = [
		["landscape_1280x720", Vector2i(1280, 720), Rect2(0, 0, 0, 0)],
		["portrait_720x1280", Vector2i(720, 1280), Rect2(0, 48, 0, 32)],
		["small_phone_640x320", Vector2i(640, 320), Rect2(24, 0, 24, 0)],
		["small_phone_portrait_320x640", Vector2i(320, 640), Rect2(0, 24, 0, 16)],
		["phone_915x412", Vector2i(915, 412), Rect2(32, 0, 32, 0)],
		["fold_inner_2176x1812", Vector2i(2176, 1812), Rect2(0, 40, 0, 24)],
		["fold_cover_2316x904", Vector2i(2316, 904), Rect2(48, 0, 48, 0)],
		["fold_cover_portrait_904x2316", Vector2i(904, 2316), Rect2(0, 48, 0, 32)],
	]
	for shot in shots:
		root.size = shot[1]
		await _settle(4)
		game._apply_safe_area(shot[2], Vector2(shot[1]))
		game._apply_responsive_layout()
		await _settle(10)
		_save("race_%s.png" % shot[0])
	# Live feedback in action: steer + gas + drift held, drift charged to orange.
	root.size = Vector2i(1280, 720)
	await _settle(4)
	game._apply_safe_area(Rect2(), Vector2(root.size))
	game._apply_responsive_layout()
	game.auto_gas = false
	game._update_hud()
	await _settle(6)
	var stick: Vector2 = game.joystick.get_global_rect().get_center()
	await _touch(1, stick, true)
	await _drag(1, stick + Vector2(game.joystick.size.x * 0.28, 0))
	await _touch(2, game.gas_button.get_global_rect().get_center(), true)
	await _touch(3, game.drift_button.get_global_rect().get_center(), true)
	for frame in range(70):
		await physics_frame
	game.message.text = "Oranger Drift-Turbo!"
	await _settle(2)
	_save("race_active_steer_gas_drift_1280x720.png")
	await _touch(3, Vector2(640, 200), false)
	await _touch(2, Vector2(640, 200), false)
	await _touch(1, Vector2(640, 200), false)
	game.rocket_phase = "armed"
	game.message.text = "Falsche Richtung! Dreh um."
	await _settle(12)
	_save("race_armed_warning_1280x720.png")
	game.queue_free()
	await _settle(2)


func _make(id: String, at: Vector2, side: float, parent: Control) -> Control:
	var action: Control = ACTION.new()
	action.icon_id = id
	parent.add_child(action)
	action.skin = "kart3d"
	action.text = {"gas": "GAS", "brake": "BREMSE", "drift": "DRIFT", "boost": "SPEED\n◆ 2", "item": "ITEM"}[id]
	action.size = Vector2.ONE * side
	action.position = at
	return action


func _caption(parent: Control, text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Black.ttf"))
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("e8f4ff"))
	label.position = at
	parent.add_child(label)


func _state_sheet() -> void:
	root.size = Vector2i(1500, 1180)
	await _settle(2)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var sheet := Control.new()
	sheet.size = Vector2(root.get_visible_rect().size)
	layer.add_child(sheet)
	var road := ColorRect.new()
	road.color = Color("5d6470")
	road.size = sheet.size
	sheet.add_child(road)
	var dark := ColorRect.new()
	dark.color = Color("0d1d38")
	dark.position = Vector2(0, sheet.size.y * 0.5)
	dark.size = Vector2(sheet.size.x, sheet.size.y * 0.5)
	sheet.add_child(dark)
	var scale: float = sheet.size.x / 1500.0
	var side: float = 120.0 * scale
	var step := Vector2(170, 175) * scale
	var columns: Array = ["normal", "pressed", "disabled", "ready / Last", "Stufe 2", "Stufe 3 / scharf", "Schild"]
	for c in range(columns.size()):
		_caption(sheet, columns[c], Vector2(150 + c * step.x / scale, 8) * scale)
	var ids: Array = ["gas", "brake", "drift", "boost", "item"]
	for r in range(ids.size()):
		var id: String = ids[r]
		_caption(sheet, id.to_upper(), Vector2(14, 92 + r * step.y / scale) * scale)
		for c in range(7):
			var at := Vector2(150 + c * step.x / scale, 40 + r * step.y / scale) * scale
			var action: Control = null
			match c:
				0:
					action = _make(id, at, side, sheet)
					if id == "boost":
						action.stock = 0
					if id == "item":
						action.item_kind = ""
				1:
					action = _make(id, at, side, sheet)
					action.held = true
					action.press_depth = 1.0
				2:
					action = _make(id, at, side, sheet)
					action.disabled = true
				3:
					action = _make(id, at, side, sheet)
					match id:
						"gas": action.meter = 0.7
						"brake":
							action.held = true
							action.press_depth = 1.0
							action.hold_glow = 1.0
						"drift":
							action.held = true
							action.tier = 0
							action.meter = 0.45
						"boost":
							action.stock = 2
							action.meter = 0.6
						"item": action.item_kind = "pulse"
				4:
					if id == "drift":
						action = _make(id, at, side, sheet)
						action.held = true
						action.tier = 1
						action.meter = 0.8
				5:
					if id == "drift":
						action = _make(id, at, side, sheet)
						action.held = true
						action.tier = 2
						action.meter = 1.0
					elif id == "item":
						action = _make(id, at, side, sheet)
						action.item_kind = "star_rocket"
						_slot(action, {"phase": "armed", "item": "star_rocket", "charges": 2, "item_color": "#ff4f6d", "lock": 0.6})
				6:
					if id == "item":
						action = _make(id, at, side, sheet)
						action.item_kind = "shield"
						_slot(action, {"phase": "", "item": "shield", "charges": 1, "item_color": "#66e8ff", "shield_left": 3.0})
			if action != null and action.held:
				action.set_process(false)
	# The stick: idle, steering left, steering right (knob with moving light reflex), disabled.
	var stick_y: float = (40 + 5 * step.y / scale) * scale
	_caption(sheet, "LENKEN", Vector2(14, stick_y / scale + 70) * scale)
	for c in range(4):
		var stick: Control = STICK.new()
		sheet.add_child(stick)
		stick.skin = "kart3d"
		stick.size = Vector2.ONE * 190.0 * scale
		stick.position = Vector2(150 + c * 230, stick_y / scale) * scale
		stick.set_process(false)
		match c:
			1:
				stick.axis = Vector2(-0.9, 0)
				stick.touch_id = 7
			2:
				stick.axis = Vector2(0.9, 0.1)
				stick.touch_id = 8
			3:
				stick.enabled = false
		stick.queue_redraw()
	# Small sizes: the smallest real target (48 dp) next to a large Fold size.
	var small_y: float = stick_y + 210.0 * scale
	_caption(sheet, "48 dp", Vector2(14, small_y / scale + 14) * scale)
	for i in range(5):
		_make(ids[i], Vector2(150 + i * 64, small_y / scale) * scale, 48.0 * scale, sheet)
	await _settle(12)
	_save("button_states_sheet.png")
	layer.queue_free()
	await _settle(2)


func _slot(action: Control, state: Dictionary) -> void:
	var slot: Control = ITEM_HUD.new()
	slot.name = "ItemSlotOverlay"
	slot.mode = "slot"
	action.add_child(slot)
	slot.push_state(state, 0.0)
