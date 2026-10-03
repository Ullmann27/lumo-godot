extends Node3D
# gdlint: disable=max-file-lines
## Guided arcade racing, original Lumo world and safe paused learning moments.

const QUESTIONS = preload("res://scripts/games/kart_questions.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const MINIMAP = preload("res://scripts/games/kart_minimap.gd")
const TOUCH_ACTION = preload("res://scripts/games/kart_touch_action.gd")
const JOYSTICK = preload("res://scripts/games/kart_joystick.gd")
const TOTAL_LAPS: int = 2
const ROAD_WIDTH: float = 10.8
const SESSION: String = "user://kart_sonnenhafen_session.cfg"
const PREFERENCES: String = "user://kart_preferences.cfg"
var curve: Curve3D
var world: LumoRaceWorld
var track_length: float
var distance: float = 0.0
var lane: float = 0.0
var lateral_velocity: float = 0.0
var steering: float = 0.0
var brake: float = 0.0
var speed: float = 0.0
var countdown: float = 3.5
var elapsed: float = 0.0
var boost_time: float = 0.0
var boosts: int = 1
var drift_charge: float = 0.0
var drifting: bool = false
var racing: bool = false
var finished: bool = false
var paused: bool = false
var abandoned: bool = false
var question_open: bool = false
var question_index: int = 0
var correct_count: int = 0
var wrong_count: int = 0
var grade: int = 1
var subject: String = "Mathematik"
var rng := RandomNumberGenerator.new()
var player: LumoRaceKart
var camera: Camera3D
var opponents: Array[LumoRaceKart] = []
var opponent_distances: Array[float] = [-4, -7, -10, -13, -16]
var opponent_lanes: Array[float] = [-3.2, -1.65, -0.1, 1.45, 3.0]
var rival_contact_timer: float = 0.0
var checkpoint_index: int = 0
var result_id: String = ""
var result_payload: Dictionary = {}
var gems: Array[Node3D] = []
var gem_distances: Array[float] = []
var collected: Dictionary = {}
var hud: Label
var message: Label
var boost_button: Control
var drift_button: Control
var joystick: Control
var modal: PanelContainer
var modal_column: VBoxContainer
var lesson: PanelContainer
var lesson_column: VBoxContainer
var lesson_hint: Label
var safe_ui: Control
var active_question: Dictionary = {}
var recent_questions: Array[String] = []
var muted: bool = true
var reduced_motion: bool = false
var lightweight: bool = false
var difficulty: String = "gemuetlich"
var save_timer: float = 0.0
var hit_timer: float = 0.0
var obstacle_distances: Array[float] = []
var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var materials: Dictionary = {}
var boxes: Dictionary = {}
var sphere_mesh: SphereMesh
var crystal_mesh: ArrayMesh
var previous_scale := Vector2i(720, 1280)
var previous_size := Vector2i(720, 1280)
var previous_orientation: int = DisplayServer.SCREEN_PORTRAIT
var previous_auto_accept_quit: bool = true


func _ready() -> void:
	set_physics_process(false)
	rng.randomize()
	grade = clampi(int(SceneRouter.launch_options.get("grade", 1)), 1, 4)
	subject = str(SceneRouter.launch_options.get("subject", "Mathematik"))
	if subject not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
		subject = "Mathematik"
	result_id = HostBridge.new_result_id()
	# Android Back is handled by the race; it must not kill an unsaved session.
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_load_preferences()
	previous_scale = get_window().content_scale_size
	previous_size = get_window().size
	previous_orientation = DisplayServer.screen_get_orientation()
	get_window().content_scale_size = Vector2i(1280, 720)
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		var viewport_ready: bool = await _wait_for_landscape()
		if not viewport_ready:
			push_error("Kart landscape surface did not resize before scene initialization")
			return
	elif DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		get_window().size = Vector2i(1280, 720)
	_build_world()
	_build_ui()
	_build_engine_sound()
	message.text = (
		"SONNENHAFEN-CUP · Automatisches Gas\n"
		+ "Stick zum Lenken · Nach unten: bremsen · Rechts: Drift und Boost"
	)
	if _restore_session():
		_pause()
		message.text = "Dein Rennen ist gespeichert. Fahre weiter, wenn du bereit bist."
	print("[Kart] ready: Sonnenhafen, length=%.1fm, six racers" % track_length)
	set_physics_process(true)


func _wait_for_landscape() -> bool:
	# Native rotation is asynchronous. Build the heavy scene after the surface resizes.
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var pixels: Vector2i = DisplayServer.window_get_size()
		if pixels.x > pixels.y and get_window().size.x > get_window().size.y:
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			print(
				(
					"[KartViewport] landscape surface=%s logical=%s"
					% [pixels, get_viewport().get_visible_rect().size]
				)
			)
			return true
		await get_tree().process_frame
	return false


func _build_world() -> void:
	world = WORLD.new()
	add_child(world)
	world.build(lightweight)
	curve = world.curve
	track_length = world.length
	crystal_mesh = _gem_mesh()
	for i in range(24 * TOTAL_LAPS):
		var d: float = (float(i) + 0.5) * track_length / 24
		var gem: MeshInstance3D = _mesh(
			self,
			crystal_mesh,
			_track_position(d, float(i % 3 - 1) * 2.3) + Vector3.UP * 0.9,
			Color("ffe7a0")
		)
		gems.append(gem)
		gem_distances.append(d)
	player = VEHICLE.new()
	player.configure("fox", Color("7760cf"))
	player.reduced_motion = reduced_motion
	add_child(player)
	var animals: Array[String] = ["otter", "rabbit", "badger", "cat", "fox"]
	var colors: Array[Color] = [
		Color("ed865e"), Color("51ac9b"), Color("eeb954"), Color("6ba8d0"), Color("dd92b7")
	]
	for i in range(animals.size()):
		var opponent: LumoRaceKart = VEHICLE.new()
		opponent.configure(animals[i], colors[i])
		opponent.reduced_motion = reduced_motion
		add_child(opponent)
		opponents.append(opponent)
	for fraction in [0.18, 0.34, 0.62, 0.85]:
		var d: float = fraction * track_length
		obstacle_distances.append(d)
		var marker := _box(
			self,
			_track_position(d, 2.8) + Vector3.UP * 0.45,
			Vector3(0.7, 0.9, 0.7),
			Color("ed9865")
		)
		marker.basis = world.frame(d)
		_box(marker, Vector3(0, 0.14, 0), Vector3(0.76, 0.16, 0.76), Color("fff0ca"))
	for fraction in [0.12, 0.42, 0.74]:
		var d: float = fraction * track_length
		for i in range(5):
			var strip := _box(
				self,
				_track_position(d + i * 0.55, 0) + world.frame(d).y * 0.04,
				Vector3(4.2, 0.025, 0.25),
				Color("6ce5da")
			)
			strip.basis = world.frame(d)
	camera = Camera3D.new()
	camera.fov = 68
	camera.current = true
	camera.far = 350
	add_child(camera)
	_update_vehicles(0)
	_update_camera(1.0, true)


func _forward(d: float) -> Vector3:
	return world.forward(d)


func _track_position(d: float, offset: float) -> Vector3:
	return world.position_at(d, offset)


func _heading(d: float) -> float:
	var ahead: Vector3 = _forward(d)
	return atan2(-ahead.x, -ahead.z)


func _style(color: Color, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0.07, 0.16, 0.24, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


func _label(text: String, size: int = 23) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("254052"))
	return label


func _button(text: String, callback: Callable, color: Color = Color("62559f")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 58)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.15)))
	button.add_theme_stylebox_override("disabled", _style(Color("708287")))
	button.pressed.connect(callback)
	return button


func _action(text: String, callback: Callable, color: Color, diameter: float) -> Control:
	var button: Control = TOUCH_ACTION.new()
	button.text = text
	button.accent = color
	button.custom_minimum_size = Vector2.ONE * diameter
	button.pressed.connect(callback)
	return button


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.name = "RaceSafeArea"
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 22)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(safe)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(_button("‹ Spiele", _pause))
	var hud_panel := PanelContainer.new()
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_stylebox_override("panel", _style(Color("fff4dd")))
	top.add_child(hud_panel)
	hud = _label("SONNENHAFEN", 23)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_panel.add_child(hud)
	top.add_child(_button("Ⅱ Pause", _pause))
	message = _label("", 21)
	message.add_theme_color_override("font_color", Color("fff6dd"))
	message.add_theme_color_override("font_shadow_color", Color("203f58"))
	message.add_theme_constant_override("shadow_offset_x", 1)
	message.add_theme_constant_override("shadow_offset_y", 2)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls.add_theme_constant_override("separation", 20)
	column.add_child(controls)
	joystick = JOYSTICK.new()
	joystick.custom_minimum_size = Vector2(188, 188)
	joystick.axis_changed.connect(
		func(value: Vector2):
			steering = value.x
			brake = maxf(0, value.y)
	)
	controls.add_child(joystick)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(gap)
	drift_button = _action("DRIFT\nHALTEN", func(): pass, Color("bc8eff"), 106)
	drift_button.size_flags_vertical = Control.SIZE_SHRINK_END
	drift_button.button_down.connect(func(): drifting = racing and not paused and not question_open)
	drift_button.button_up.connect(_release_drift)
	controls.add_child(drift_button)
	boost_button = _action("BOOST\n◆ 1", _boost, Color("66f7e8"), 138)
	boost_button.size_flags_vertical = Control.SIZE_SHRINK_END
	controls.add_child(boost_button)
	var map_panel := PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	map_panel.offset_left = -210
	map_panel.offset_right = -22
	map_panel.offset_top = -78
	map_panel.offset_bottom = 78
	map_panel.add_theme_stylebox_override("panel", _style(Color(1, 0.97, 0.88, 0.88)))
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(map_panel)
	var map: Control = MINIMAP.new()
	map.custom_minimum_size = Vector2(160, 128)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.configure(self)
	map_panel.add_child(map)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -310
	modal.offset_right = 310
	modal.offset_top = -260
	modal.offset_bottom = 260
	modal.add_theme_stylebox_override("panel", _style(Color("fff9ed"), 24))
	safe_ui.add_child(modal)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_column)
	modal.hide()
	lesson = PanelContainer.new()
	lesson.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lesson.offset_left = 200
	lesson.offset_right = -200
	lesson.offset_top = 108
	lesson.offset_bottom = 300
	lesson.add_theme_stylebox_override("panel", _style(Color("fff9ed"), 22))
	safe_ui.add_child(lesson)
	lesson_column = VBoxContainer.new()
	lesson_column.add_theme_constant_override("separation", 8)
	lesson.add_child(lesson_column)
	lesson.hide()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()


static func _scaled_safe_insets(
	insets: Rect2, physical_size: Vector2, logical_size: Vector2
) -> Rect2:
	if physical_size.x <= 0 or physical_size.y <= 0:
		return Rect2()
	var scale: Vector2 = logical_size / physical_size
	return Rect2(
		Vector2(maxf(0, insets.position.x), maxf(0, insets.position.y)) * scale,
		Vector2(maxf(0, insets.size.x), maxf(0, insets.size.y)) * scale
	)


func _apply_safe_area(insets: Rect2, physical_size: Vector2) -> void:
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	var scaled: Rect2 = _scaled_safe_insets(insets, physical_size, logical_size)
	safe_ui.offset_left = scaled.position.x
	safe_ui.offset_top = scaled.position.y
	safe_ui.offset_right = -scaled.size.x
	safe_ui.offset_bottom = -scaled.size.y


func _update_safe_area() -> void:
	if not is_instance_valid(safe_ui):
		return
	var insets := Rect2()
	if OS.has_feature("android") or OS.has_feature("ios"):
		insets = MobileRuntime.get_safe_area_insets()
		# Usable screen bounds alone can omit camera cutouts in immersive mode.
		var screen: Vector2i = DisplayServer.screen_get_size()
		var unobscured: Rect2i = DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and unobscured.has_area():
			insets.position.x = maxf(insets.position.x, unobscured.position.x)
			insets.position.y = maxf(insets.position.y, unobscured.position.y)
			insets.size.x = maxf(insets.size.x, screen.x - unobscured.end.x)
			insets.size.y = maxf(insets.size.y, screen.y - unobscured.end.y)
	_apply_safe_area(insets, Vector2(get_window().size))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not paused and not finished and countdown > 0:
		countdown = maxf(0, countdown - delta)
		message.text = (
			str(ceili(countdown))
			if countdown > 0
			else "Los! Kristalle sammeln · Lernen lädt deinen Boost."
		)
		if countdown == 0:
			racing = true
	if racing and not paused and not finished and not question_open:
		elapsed += delta
		var axis: float = Input.get_axis("ui_left", "ui_right")
		if Input.is_physical_key_pressed(KEY_A):
			axis -= 1
		if Input.is_physical_key_pressed(KEY_D):
			axis += 1
		if absf(axis) < 0.01:
			axis = steering
		# A short acceleration/deceleration makes touch steering less abrupt.
		lateral_velocity = move_toward(lateral_velocity, axis * 5.2, delta * 24.0)
		lane = clampf(lane + lateral_velocity * delta, -4.7, 4.7)
		var target: float = 23.0 if boost_time > 0 else 16.0
		target *= 1.0 - (0.4 * brake if not question_open else 0)
		if absf(lane) > 4.25:
			target *= 0.72
		if hit_timer > 0:
			target *= 0.75
		if drifting and not question_open:
			target *= 0.93
			drift_charge += delta * absf(axis)
		speed = move_toward(speed, target, delta * 9)
		distance += speed * delta
		boost_time = maxf(0, boost_time - delta)
		hit_timer = maxf(0, hit_timer - delta)
		rival_contact_timer = maxf(0, rival_contact_timer - delta)
		for i in range(opponents.size()):
			var rival_speed: float = (
				14.2 + i * 0.25 if difficulty == "gemuetlich" else 16.3 + i * 0.2
			)
			# Rivals gently choose an open lane instead of stacking through Lumo.
			var desired_lane: float = -3.2 + float(i) * 1.55 + sin(elapsed * 0.45 + i) * 0.35
			var gap: float = opponent_distances[i] - distance
			if absf(gap) < 7.0 and absf(desired_lane - lane) < 1.3:
				desired_lane = clampf(lane + (1.0 if i % 2 == 0 else -1.0) * 1.65, -4.0, 4.0)
			opponent_lanes[i] = move_toward(opponent_lanes[i], desired_lane, delta * 1.5)
			if gap < 0 and gap > -3.0 and absf(opponent_lanes[i] - lane) < 1.2:
				rival_speed = minf(rival_speed, maxf(0, speed - 1.0))
			opponent_distances[i] += delta * (rival_speed + sin(elapsed * 0.7 + i) * 0.7)
		_track_events()
		_update_checkpoints()
		if (
			not question_open
			and question_index < 6
			and distance >= track_length * TOTAL_LAPS * float(question_index + 1) / 7
		):
			_open_question()
		if distance >= track_length * TOTAL_LAPS and checkpoint_index >= TOTAL_LAPS * 8:
			_finish()
		save_timer += delta
		if save_timer >= 5:
			save_timer = 0
			_save_session()
	for i in range(gems.size()):
		gems[i].visible = not collected.has(i) and absf(gem_distances[i] - distance) < 70
		if gems[i].visible and not paused and not reduced_motion:
			gems[i].rotation.y += delta * 1.7
	_update_vehicles(delta)
	_update_camera(delta)
	var place: int = 1
	for d in opponent_distances:
		if d > distance:
			place += 1
	hud.text = (
		"RUNDE %d / %d     ·     PLATZ %d / 6     ·     %d km/h     ·     ◆ %d"
		% [
			mini(TOTAL_LAPS, int(distance / track_length) + 1),
			TOTAL_LAPS,
			place,
			0 if question_open or paused or finished else int(speed * 3.6),
			collected.size()
		]
	)
	boost_button.text = "BOOST\n◆ %d" % boosts
	boost_button.disabled = boosts == 0 or paused or not racing or finished or question_open
	drift_button.disabled = paused or not racing or finished or question_open
	joystick.set_enabled(racing and not paused and not finished and not question_open)
	if (
		engine_playback
		and not muted
		and racing
		and not paused
		and not finished
		and not question_open
	):
		for i in range(engine_playback.get_frames_available()):
			var phase: float = (
				(float(Time.get_ticks_usec()) / 1000000.0 + float(i) / 22050) * (70 + speed * 5)
			)
			var sample: float = sin(phase * TAU) * 0.025
			engine_playback.push_frame(Vector2(sample, sample))


func _track_events() -> void:
	for i in range(opponents.size()):
		if (
			rival_contact_timer <= 0
			and absf(opponent_distances[i] - distance) < 1.7
			and absf(opponent_lanes[i] - lane) < 1.2
		):
			rival_contact_timer = 0.8
			hit_timer = maxf(hit_timer, 0.35)
			var away: float = 1.0 if lane >= opponent_lanes[i] else -1.0
			lane = clampf(lane + away * 0.22, -4.7, 4.7)
			message.text = "Sanfter Kart-Rempler – du bleibst auf der Strecke."
	for i in range(gems.size()):
		if (
			not collected.has(i)
			and absf(distance - gem_distances[i]) < 1.4
			and absf(lane - float(i % 3 - 1) * 2.3) < 1.35
		):
			collected[i] = true
			if collected.size() % 3 == 0:
				boosts = mini(3, boosts + 1)
	for d in obstacle_distances:
		if (
			absf(fposmod(distance, track_length) - d) < 1.0
			and lane > 2.2
			and lane < 3.45
			and hit_timer <= 0
		):
			hit_timer = 0.8
			message.text = "Kleiner Rempler – weiter geht's!"
	for fraction in [0.12, 0.42, 0.74]:
		if (
			absf(fposmod(distance, track_length) - fraction * track_length - 1.1) < 1.2
			and absf(lane) < 2.1
		):
			boost_time = maxf(boost_time, 1.0)


func _update_checkpoints() -> void:
	# Eight ordered gates per lap make progress explicit and restorable.
	var spacing: float = track_length / 8.0
	while checkpoint_index < TOTAL_LAPS * 8 and distance >= (checkpoint_index + 1) * spacing:
		checkpoint_index += 1
		if checkpoint_index == 8:
			message.text = "Runde 1 geschafft! Noch eine Runde durch den Sonnenhafen."


func _update_vehicles(_delta: float) -> void:
	player.position = _track_position(distance, lane) + world.frame(distance).y * 0.035
	var drift_yaw: float = -steering * 0.22 if drifting else -steering * 0.08
	player.quaternion = Quaternion(world.frame(distance)) * Quaternion(Vector3.UP, drift_yaw)
	player.set_motion(
		speed if racing and not paused and not finished and not question_open else 0,
		steering,
		boost_time > 0 and not paused and not finished and not question_open,
		drifting and not paused
	)
	for i in range(opponents.size()):
		var kart: LumoRaceKart = opponents[i]
		var side: float = opponent_lanes[i]
		kart.position = (
			_track_position(opponent_distances[i], side)
			+ world.frame(opponent_distances[i]).y * 0.035
		)
		kart.quaternion = Quaternion(world.frame(opponent_distances[i]))
		kart.set_motion(
			15 if racing and not paused and not finished and not question_open else 0,
			sin(elapsed + i) * 0.12,
			false,
			false
		)


func _update_camera(delta: float, snap: bool = false) -> void:
	var ahead: Vector3 = _forward(distance)
	var desired: Vector3 = player.position - ahead * 5.5 + Vector3.UP * 3.15
	var target: Vector3 = _track_position(distance + 8, lane * 0.4) + Vector3.UP * 1.35
	camera.position = desired if snap else camera.position.lerp(desired, minf(1, delta * 8))
	camera.look_at(target)
	var fov: float = 68 if reduced_motion else (77 if boost_time > 0 and not paused else 68)
	camera.fov = lerpf(camera.fov, fov, minf(1, delta * 3))


func _boost() -> void:
	if boosts > 0 and racing and not paused and not finished and not question_open:
		boosts -= 1
		boost_time = 3.2
		message.text = "Lumo-Boost!"


func _release_drift() -> void:
	drifting = false
	if racing and not paused and not finished and drift_charge >= 0.8:
		boost_time = maxf(boost_time, 1.6)
	drift_charge = 0


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SHIFT:
			if not event.pressed:
				_release_drift()
			else:
				drifting = racing and not paused and not question_open
		elif event.pressed and event.keycode == KEY_SPACE:
			_boost()
		elif event.pressed and event.keycode == KEY_ESCAPE:
			if finished:
				_return_to_world()
			elif paused:
				_resume()
			else:
				_pause()


func _clear_column(column: VBoxContainer) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()


func _open_question() -> void:
	if finished:
		return
	question_open = true
	steering = 0
	lateral_velocity = 0
	brake = 0
	drifting = false
	wrong_count = 0
	for i in range(30):
		active_question = QUESTIONS.make(grade, subject, rng)
		if not recent_questions.has(active_question.prompt):
			break
	recent_questions.append(active_question.prompt)
	_show_question()


func _show_question() -> void:
	_clear_column(lesson_column)
	var row := HBoxContainer.new()
	var title := _label("LERN-BOOST · %d. KLASSE · %s" % [grade, subject], 17)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	row.add_child(_button("Später ›", _skip_question, Color("2b6576")))
	lesson_column.add_child(row)
	lesson_column.add_child(_label(active_question.prompt, 25))
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 10)
	for answer in active_question.options:
		var button := _button(answer, func(): _answer(answer))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answers.add_child(button)
	lesson_column.add_child(answers)
	lesson_hint = _label("Alle Karts warten. Nimm dir Zeit – danach geht dein Rennen weiter.", 17)
	lesson_column.add_child(lesson_hint)
	lesson.visible = not paused


func _answer(answer: String) -> void:
	if not question_open or paused or finished:
		return
	if answer == active_question.answer:
		correct_count += 1
		boosts = mini(3, boosts + 1)
		question_index += 1
		question_open = false
		lesson.hide()
		message.text = "Richtig! " + active_question.hint + " · Boost geladen."
		_save_session()
	else:
		wrong_count += 1
		lesson_hint.text = active_question.hint
		if wrong_count >= 3:
			lesson_hint.text += " · Die Lösung ist %s. Probiere sie aus." % active_question.answer


func _skip_question() -> void:
	if not question_open or finished or paused:
		return
	question_open = false
	question_index += 1
	lesson.hide()
	message.text = "Weiter geht's. Die nächste Lernfrage kommt später."
	_save_session()


func _pause() -> void:
	if finished or paused:
		return
	paused = true
	steering = 0
	lateral_velocity = 0
	brake = 0
	drifting = false
	drift_charge = 0
	lesson.hide()
	_save_session()
	_clear_column(modal_column)
	modal_column.add_child(_label("Kleine Pause im Sonnenhafen", 28))
	modal_column.add_child(_label("Dein Rennen wartet. Du kannst später hier weiterfahren.", 19))
	modal_column.add_child(_button("Weiterfahren", _resume))
	var motion := _button(
		"Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus", func(): pass
	)
	motion.pressed.connect(
		func():
			reduced_motion = not reduced_motion
			player.reduced_motion = reduced_motion
			motion.text = "Ruhige Bewegung: an" if reduced_motion else "Ruhige Bewegung: aus"
			_save_preferences()
	)
	modal_column.add_child(motion)
	var sound := _button("Ton: aus" if muted else "Ton: an", func(): pass)
	sound.pressed.connect(
		func():
			muted = not muted
			sound.text = "Ton: aus" if muted else "Ton: an"
			_save_preferences()
	)
	modal_column.add_child(sound)
	var detail := _button(
		"Leichte Grafik: an" if lightweight else "Leichte Grafik: aus", func(): pass
	)
	detail.pressed.connect(
		func():
			lightweight = not lightweight
			_save_preferences()
			_save_session()
			SceneRouter.goto("kart")
	)
	modal_column.add_child(detail)
	var challenge := _button(
		"Tempo: gemütlich" if difficulty == "gemuetlich" else "Tempo: flott", func(): pass
	)
	challenge.pressed.connect(
		func():
			difficulty = "flott" if difficulty == "gemuetlich" else "gemuetlich"
			challenge.text = "Tempo: gemütlich" if difficulty == "gemuetlich" else "Tempo: flott"
			_save_preferences()
	)
	modal_column.add_child(challenge)
	modal_column.add_child(_button("Zur Spieleauswahl · Rennen behalten", _return_to_world))
	modal_column.add_child(_button("Zum Lernen · Rennen behalten", func(): _return_to_app("learn")))
	modal_column.add_child(_button("Rennen abbrechen", _abandon, Color("a14f3b")))
	modal.show()


func _resume() -> void:
	paused = false
	modal.hide()
	if question_open:
		_show_question()


func _return_to_world() -> void:
	_return_to_app("games")


func _return_to_app(destination: String) -> void:
	_save_session()
	if finished:
		HostBridge.reward(result_payload)
	var payload: Dictionary = (
		result_payload
		if finished
		else {
			"game": "kart",
			"status": "abandoned" if abandoned else "paused",
			"resultId": result_id,
			"grade": grade,
			"subject": subject,
			"stars": 0
		}
	)
	if not HostBridge.return_to_app(destination, payload):
		SceneRouter.goto("learn" if destination == "learn" else "games")


func _abandon() -> void:
	abandoned = true
	DirAccess.remove_absolute(SESSION)
	_return_to_app("games")


func _finish() -> void:
	if finished:
		return
	finished = true
	racing = false
	question_open = false
	lesson.hide()
	DirAccess.remove_absolute(SESSION)
	var earned: int = 3 + correct_count * 2
	ProgressStore.add_stars(earned)
	var place: int = 1
	for rival_distance in opponent_distances:
		if rival_distance > distance:
			place += 1
	result_payload = {
		"game": "kart",
		"sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		"resultId": result_id,
		"status": "completed",
		"stars": earned,
		"solved": correct_count,
		"elapsedSeconds": snappedf(elapsed, 0.1),
		"place": place,
		"grade": grade,
		"subject": subject
	}
	# Save the host reward immediately; Back/process teardown must not lose it.
	HostBridge.reward(result_payload)
	var config := ConfigFile.new()
	config.load("user://kart_records.cfg")
	var key: String = "sonnenhafen_%s_%d_%s" % [subject, grade, difficulty]
	var best: float = float(config.get_value("times", key, 9999.0))
	if elapsed < best:
		config.set_value("times", key, elapsed)
		config.save("user://kart_records.cfg")
	_clear_column(modal_column)
	modal_column.add_child(_label("Sonnenhafen-Cup geschafft! ★", 30))
	modal_column.add_child(
		_label(
			(
				"Platz %d von 6 · %.1f Sekunden · %d Lernfragen gelöst\n+%d Sterne · %d Kristalle"
				% [place, elapsed, correct_count, earned, collected.size()]
			),
			23
		)
	)
	modal_column.add_child(
		_label("Neue Bestzeit!" if elapsed < best else "Bestzeit: %.1f Sekunden" % best, 20)
	)
	modal_column.add_child(_button("Noch ein Rennen", func(): SceneRouter.goto("kart")))
	modal_column.add_child(_button("Zur Spieleauswahl", _return_to_world))
	modal_column.add_child(_button("Zum Lernen", func(): _return_to_app("learn")))
	modal.show()
	print("[Kart] finished: stars=%d questions=%d" % [earned, correct_count])


func _load_preferences() -> void:
	var config := ConfigFile.new()
	config.load(PREFERENCES)
	reduced_motion = bool(config.get_value("race", "reduced_motion", false))
	lightweight = bool(
		config.get_value("race", "lightweight", SettingsStore.get_profile() == "low")
	)
	muted = bool(config.get_value("race", "muted", true))
	difficulty = str(config.get_value("race", "difficulty", "gemuetlich"))


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("race", "reduced_motion", reduced_motion)
	config.set_value("race", "lightweight", lightweight)
	config.set_value("race", "muted", muted)
	config.set_value("race", "difficulty", difficulty)
	config.save(PREFERENCES)
	_update_audio()
	for kart in opponents:
		kart.reduced_motion = reduced_motion


func _save_session() -> void:
	if finished or abandoned or not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("race", "version", 2)
	config.set_value("race", "grade", grade)
	config.set_value("race", "subject", subject)
	for key in [
		"distance",
		"result_id",
		"checkpoint_index",
		"lane",
		"speed",
		"countdown",
		"elapsed",
		"boost_time",
		"boosts",
		"question_index",
		"correct_count",
		"wrong_count",
		"opponent_distances",
		"opponent_lanes",
		"collected",
		"recent_questions",
		"active_question",
		"question_open",
		"difficulty"
	]:
		config.set_value("race", key, get(key))
	if config.save(SESSION + ".tmp") == OK:
		var error: Error = DirAccess.rename_absolute(SESSION + ".tmp", SESSION)
		if error != OK:
			push_warning("Race checkpoint could not be saved: %s" % error)


func _restore_session() -> bool:
	var config := ConfigFile.new()
	if config.load(SESSION) != OK or int(config.get_value("race", "version", 0)) not in [1, 2]:
		return false
	if (
		config.get_value("race", "grade", 0) != grade
		or config.get_value("race", "subject", "") != subject
	):
		return false
	var saved_distance: float = float(config.get_value("race", "distance", -1))
	if saved_distance < 0 or saved_distance >= track_length * TOTAL_LAPS:
		return false
	for key in [
		"distance",
		"result_id",
		"checkpoint_index",
		"lane",
		"speed",
		"countdown",
		"elapsed",
		"boost_time",
		"boosts",
		"question_index",
		"correct_count",
		"wrong_count",
		"collected",
		"active_question",
		"question_open",
		"difficulty"
	]:
		set(key, config.get_value("race", key, get(key)))
	opponent_distances.assign(config.get_value("race", "opponent_distances", opponent_distances))
	opponent_lanes.assign(config.get_value("race", "opponent_lanes", opponent_lanes))
	if config.get_value("race", "version", 0) == 1:
		checkpoint_index = clampi(int(distance / (track_length / 8.0)), 0, TOTAL_LAPS * 8)
	recent_questions.assign(config.get_value("race", "recent_questions", recent_questions))
	racing = countdown <= 0
	_update_vehicles(0)
	_update_camera(1, true)
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not is_instance_valid(modal):
			return
		if finished or paused:
			_return_to_world()
		else:
			_pause()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(modal) and not finished:
			_pause()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = previous_auto_accept_quit
	if is_instance_valid(engine_player):
		engine_player.stop()
		engine_playback = null
		engine_player.stream = null
	_save_session()
	get_window().content_scale_size = previous_scale
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(previous_orientation)
	elif DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		get_window().size = previous_size


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = color.to_html() + str(metallic)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = metallic
	materials[key] = mat
	return mat


func _gem_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [
		Vector3(0, 0.5, 0),
		Vector3(0, -0.5, 0),
		Vector3(0.35, 0, 0),
		Vector3(0, 0, 0.35),
		Vector3(-0.35, 0, 0),
		Vector3(0, 0, -0.35)
	]
	for ring in range(4):
		var a: int = 2 + ring
		var b: int = 2 + (ring + 1) % 4
		for index in [0, b, a, 1, a, b]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not boxes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		boxes[size] = mesh
	var box: BoxMesh = boxes[size]
	return _mesh(parent, box, position, color)


func _ball(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		sphere_mesh.radial_segments = 24
		sphere_mesh.rings = 12
	var node := _mesh(parent, sphere_mesh, position, color)
	node.scale = size
	return node


func _build_engine_sound() -> void:
	engine_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.1
	engine_player.stream = stream
	add_child(engine_player)
	_update_audio()


func _update_audio() -> void:
	if not is_instance_valid(engine_player):
		return
	if muted:
		engine_player.stop()
		engine_playback = null
	elif not engine_player.playing:
		engine_player.play()
		engine_playback = engine_player.get_stream_playback()
