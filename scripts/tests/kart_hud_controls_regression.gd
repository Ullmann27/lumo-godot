extends SceneTree
## Lumo Kart controls and race HUD: rendered state images, real (multi-)touch, 48 dp
## targets inside the safe area on many screen shapes, and live displays that follow the
## real race values. Runs headless or with a renderer.

const ACTION = preload("res://scripts/games/kart_touch_action.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const SCREENS: Array[Vector2i] = [
	Vector2i(640, 320), Vector2i(800, 360), Vector2i(915, 412), Vector2i(1280, 720),
	Vector2i(412, 915), Vector2i(720, 1280), Vector2i(360, 640), Vector2i(2176, 1812),
	Vector2i(1812, 2176), Vector2i(2316, 904), Vector2i(904, 2316),
]
const INSETS: Array[Rect2] = [Rect2(12, 20, 16, 16), Rect2(48, 0, 48, 24)]
var game
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		printerr("FAIL: " + text)


func _settle(frames: int = 6) -> void:
	for frame in range(frames):
		await process_frame


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


## Size in window pixels = dp in these tests (density 1).
func _dp(control: Control) -> Vector2:
	return control.size * Vector2(root.size) / root.get_visible_rect().size


func _run() -> void:
	_check_assets()
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "candy_cloud", "difficulty": "gemuetlich"})
	game._end_preview()
	game.set_physics_process(false)
	game.auto_gas = false
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.boosts = 1
	game.modal.hide()
	game._update_hud()
	await _settle()
	var actions: Array = [game.gas_button, game.brake_button, game.drift_button, game.boost_button, game.item_button]
	for action in actions:
		_check(action.skin == "kart3d", "%s uses the rendered buttons" % action.name)
	_check(game.joystick.skin == "kart3d", "the stick uses the rendered stick")
	await _check_layouts(actions)
	await _check_touch()
	await _check_live_states()
	_check_bar()
	print("kart_hud_controls_regression: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("KART_HUD_CONTROLS_OK")
	quit(1 if not failures.is_empty() else 0)


func _check_assets() -> void:
	for id in ACTION.RENDERED_STATES:
		for state in ACTION.RENDERED_STATES[id]:
			var texture: Texture2D = ACTION.rendered_texture(id, state)
			_check(texture != null, "state image %s_%s exists" % [id, state])
			if texture != null:
				_check(texture.get_width() >= 256 and texture.get_width() == texture.get_height(), "%s_%s is a square image of at least 256 px" % [id, state])
	for path in [STICK.KART_BASE, STICK.KART_BASE_DISABLED, STICK.KART_KNOB, STICK.KART_KNOB_PRESSED]:
		_check(ResourceLoader.exists(path) and load(path) is Texture2D, "stick image %s exists" % path)


func _check_layouts(actions: Array) -> void:
	for pixels in SCREENS:
		for insets in INSETS:
			root.size = pixels
			await _settle(3)
			game._apply_safe_area(insets, Vector2(pixels))
			await _settle(3)
			game._apply_responsive_layout()
			await _settle(4)
			var label: String = "%dx%d %s" % [pixels.x, pixels.y, insets]
			var safe: Rect2 = game.safe_ui.get_global_rect()
			var rectangles: Array[Rect2] = [game.joystick.get_global_rect()]
			_check(safe.grow(0.5).encloses(game.joystick.get_global_rect()), "stick inside the safe area " + label)
			_check(_dp(game.joystick).x >= 48.0, "stick at least 48 dp " + label)
			for action in actions:
				if not action.is_visible_in_tree():
					continue
				var rect: Rect2 = action.get_global_rect()
				_check(safe.grow(0.5).encloses(rect), "%s inside the safe area %s" % [action.name, label])
				_check(_dp(action).x >= 47.5 and _dp(action).y >= 47.5, "%s at least 48 dp %s (%.1f)" % [action.name, label, _dp(action).x])
				for other in rectangles:
					_check(not rect.grow(-0.5).intersects(other), "%s does not overlap another control %s" % [action.name, label])
				rectangles.append(rect)
			# Thumbs stay off the middle of the road: no control covers the driver.
			var driver: Vector2 = game.camera.unproject_position(game.player.global_position + Vector3.UP * 0.8)
			for rect in rectangles:
				_check(not rect.has_point(driver), "controls leave the driver visible " + label)
			# The race bar sits inside the safe area and keeps the pause button free.
			var bar: Control = game.hud.get_parent().get_node("KartRaceBar")
			_check(safe.grow(0.5).encloses(bar.get_global_rect()), "race bar inside the safe area " + label)
			_check(not bar.get_global_rect().grow(-0.5).intersects(game.top_pause_button.get_global_rect()), "race bar leaves the pause button free " + label)
			for rect in rectangles:
				_check(not rect.intersects(game.top_pause_button.get_global_rect()), "pause button clear of the thumb controls " + label)


func _check_touch() -> void:
	root.size = Vector2i(1280, 720)
	await _settle(3)
	game._apply_safe_area(Rect2(12, 20, 16, 16), Vector2(root.size))
	game._apply_responsive_layout()
	await _settle(6)
	var stick_centre: Vector2 = game.joystick.get_global_rect().get_center()
	# Three fingers at once: steer right, hold gas, hold drift.
	await _touch(1, stick_centre, true)
	await _drag(1, stick_centre + Vector2(game.joystick.size.x * 0.3, 0))
	await _touch(2, game.gas_button.get_global_rect().get_center(), true)
	await _touch(3, game.drift_button.get_global_rect().get_center(), true)
	await _settle(2)
	_check(game.steering > 0.5, "stick steers right while other fingers hold buttons")
	_check(game.gas_held and game.gas_button.held, "gas held by its own finger")
	_check(game.drifting and game.drift_button.held, "drift held by a third finger")
	_check(game.joystick.is_held(), "stick shows its pressed knob")
	_check(game.gas_button.visual_state() == "pressed", "gas shows the pressed image")
	_check(game.gas_button.press_depth > 0.5, "gas button springs in")
	_check(game.gas_button.flash > 0.0, "a press starts the light ring")
	# Live drift ring follows the real charge.
	game.drift_charge = 1.9
	game._update_hud()
	_check(game.drift_button.tier == 1 and game.drift_button.meter > 0.6, "drift ring shows the orange tier from the real charge")
	game.drift_charge = 0.0
	await _touch(3, Vector2(640, 200), false)
	await _touch(2, Vector2(640, 200), false)
	await _touch(1, Vector2(640, 200), false)
	await _settle(2)
	_check(not game.gas_held and not game.drifting and game.steering == 0.0, "all fingers release, also outside the buttons")
	_check(not game.joystick.is_held(), "stick knob returns")
	# Brake glows while it is held.
	await _touch(4, game.brake_button.get_global_rect().get_center(), true)
	await _settle(20)
	_check(game.control_brake > 0.5 and game.brake_button.hold_glow > 0.5, "brake brakes and glows while held")
	await _touch(4, Vector2(640, 200), false)
	await _settle(2)
	_check(game.control_brake == 0.0, "brake releases")


func _check_live_states() -> void:
	# Gas load ring follows the real speed.
	game.speed = 0.0
	game._update_hud()
	_check(game.gas_button.meter < 0.01, "gas ring empty at standstill")
	var top: float = game.RACE_HUD.top_speed_kmh(game)
	game.speed = top / 3.6 * 0.5
	game._update_hud()
	_check(absf(game.gas_button.meter - 0.5) < 0.05, "gas ring half full at half top speed (%.2f)" % game.gas_button.meter)
	game.speed = 0.0
	# Turbo: stock and ready glow, then empty and disabled.
	game.boosts = 2
	game._update_hud()
	_check(game.boost_button.stock == 2 and game.boost_button.visual_state() == "ready", "turbo with stock glows ready")
	game.boosts = 0
	game.boost_time = 1.6
	game._update_hud()
	_check(game.boost_button.visual_state() == "disabled" and game.boost_button.meter > 0.4, "empty turbo is disabled and shows the running turbo time")
	game.boost_time = 0.0
	# Item: empty, ready, armed (rocket), shield.
	game.item = ""
	game.item_roulette_time = 0.0
	game._update_hud()
	game._update_item_hud(0.0)  # physics is paused in this test; the race calls it every tick
	await _settle(2)
	_check(game.item_button.visual_state() == "disabled", "empty item slot is disabled")
	game.item = "pulse"
	game._update_hud()
	game._update_item_hud(0.0)  # physics is paused in this test; the race calls it every tick
	await _settle(2)
	_check(game.item_button.visual_state() == "ready", "held item glows ready")
	game.item = "star_rocket"
	game.item_charges = 2
	game.rocket_phase = "armed"
	game._update_hud()
	game._update_item_hud(0.0)  # physics is paused in this test; the race calls it every tick
	await _settle(2)
	_check(game.item_button.visual_state() == "armed", "armed rockets show the armed image")
	game.rocket_phase = ""
	game.item = ""
	game.shield_time = 3.0
	game._update_hud()
	game._update_item_hud(0.0)  # physics is paused in this test; the race calls it every tick
	await _settle(2)
	_check(game.item_button.visual_state() == "shield", "active shield shows the shield image")
	game.shield_time = 0.0
	# Reduced motion: no light ring flight, no spring overshoot.
	game.reduced_motion = true
	game._apply_responsive_layout()
	await _settle(2)
	game.boosts = 1
	game._update_hud()
	await _touch(5, game.boost_button.get_global_rect().get_center(), true)
	await _settle(3)
	_check(game.boost_button.reduced_motion and game.boost_button.press_depth <= 1.0, "reduced motion: no spring overshoot")
	await _touch(5, Vector2(640, 200), false)
	game.reduced_motion = false
	game._apply_responsive_layout()


func _check_bar() -> void:
	game.speed = 20.0
	game._update_hud()
	var bar: Control = game.hud.get_parent().get_node("KartRaceBar")
	_check(int(bar.values.get("place", 0)) == game._place(), "bar shows the real place")
	_check(int(bar.values.get("speed", -1)) == int(game.speed * 3.6), "bar shows the real speed")
	_check(int(bar.values.get("stars", -1)) == game.collected.size(), "bar shows the real stars")
	_check("RUNDE" in game.hud.text and "PLATZ" in game.hud.text, "the text label keeps the race line for tests and readers")
	game.message.text = "Falsche Richtung! Dreh um."
	_check(game.message.get_node("MessagePlate").tone(game.message.text) == Color("ff7a6a"), "warnings get the coral plate")
