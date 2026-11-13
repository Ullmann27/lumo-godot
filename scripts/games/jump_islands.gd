extends Node3D

const QUESTIONS = preload("res://scripts/games/kart_questions.gd")
const LUMO = preload("res://scenes/characters/lumo/lumo_character.tscn")
const ORIGINAL_LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const JUMP_ACTION = preload("res://scripts/games/jump_touch_button.gd")
const RUN_SPEED: float = 5.5
const GROUND_ACCELERATION: float = 24.0
const GROUND_BRAKING: float = 32.0
const AIR_ACCELERATION: float = 16.0
const GRAVITY: float = 18.0
const JUMP_SPEED: float = 8.5
const SHORT_JUMP_SPEED: float = 4.8
const JUMP_BUFFER_SECONDS: float = 0.15
const COYOTE_SECONDS: float = 0.12
const ISLAND_COUNT: int = 12
const SESSION: String = "user://jump_session.cfg"
var actor: CharacterBody3D
var gait: LumoGait
var original_lumo
var camera: Camera3D
var islands: Array[Vector3] = []
var crystals: Array[Node3D] = []
var collected: Dictionary = {}
var checkpoint: int = 0
var falls: int = 0
var grade: int = 1
var subject: String = "Mathematik"
var touch_direction := Vector2.ZERO
var held_directions: Dictionary = {}
var jump_buffer: float = 0.0
var coyote_time: float = 0.0
var jump_held: bool = false
var jump_cut_pending: bool = false
var jump_active: bool = false
var movement_stick
var jump_action
var ui_safe: MarginContainer
var ui_column: VBoxContainer
var header_buttons: Array[Button] = []
var controls_row: HBoxContainer
var control_hints: Array[Label] = []
var camera_target: Vector3 = Vector3.ZERO
var paused: bool = false
var finished: bool = false
var question_open: bool = false
var completed_questions: Dictionary = {}
var active_question: Dictionary = {}
var recent_questions: Array[String] = []
var wrong_count: int = 0
var rng := RandomNumberGenerator.new()
var hud: Label
var message: Label
var modal: PanelContainer
var modal_column: VBoxContainer
var result_id: String = ""
var result_payload: Dictionary = {}
var abandoned: bool = false
var save_timer: float = 0.0
var previous_auto_accept_quit: bool = true
var previous_quit_on_go_back: bool = true
var art: JumpSkyIslandsArt
var bounce_pads: Array[Vector3] = []
var bounce_cooldown: float = 0.0
var movers: Array[Dictionary] = []
var bonus_stars: Array[Node3D] = []
var stars_gathered: Dictionary = {}
var extra_island: Vector3 = Vector3.ZERO
var checkpoint_flags: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	grade = clampi(int(SceneRouter.launch_options.get("grade", 1)), 1, 4)
	subject = str(SceneRouter.launch_options.get("subject", "Mathematik"))
	if subject not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
		subject = "Mathematik"
	result_id = HostBridge.new_result_id()
	previous_auto_accept_quit = get_tree().auto_accept_quit
	previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_build_world()
	_build_ui()
	message.text = "Lumos Wolkeninseln\nStick bewegen · Tippen: kurz · Halten: hoch springen"
	if _restore_session():
		_pause()
		message.text = "Dein Abenteuer wartet am letzten Kontrollpunkt."
	print("[Jump] ready: true 3D, grade=%d, subject=%s" % [grade, subject])


func _build_world() -> void:
	LumoEnvironment.apply(self, "wolkeninseln")
	art = JumpSkyIslandsArt.new()
	for i in range(ISLAND_COUNT):
		var point := Vector3(
			sin(float(i) * 0.75) * 3.0, sin(float(i) * 0.55) * 0.9, -float(i) * 8.0
		)
		islands.append(point)
		var ground := StaticBody3D.new()
		ground.position = point
		add_child(ground)
		art.island(ground, i)
		var shape := BoxShape3D.new()
		shape.size = Vector3(7, 0.5, 6)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		ground.add_child(collision)
		var number := Label3D.new()
		number.text = "ZIEL" if i == ISLAND_COUNT - 1 else "INSEL %d" % (i + 1)
		number.position = Vector3(0, 0.4, -2.3)
		number.rotation_degrees.x = -90
		number.font_size = 40
		number.pixel_size = 0.02
		number.modulate = Color("fffdf2")
		number.outline_size = 10
		number.outline_modulate = Color("3d6b2a")
		ground.add_child(number)
		if i > 0:
			var crystal := Node3D.new()
			crystal.position = point + Vector3(0, 1.2, 0)
			add_child(crystal)
			art.gem(crystal)
			crystals.append(crystal)
		if i % 2 == 0:
			art.tree(ground, Vector3(-2.7, 0, -1.7))
		else:
			art.tree(ground, Vector3(2.4, 0, -1.8))
		if i == ISLAND_COUNT - 1:
			art.goal_flag(ground)
	var course_length: float = float(ISLAND_COUNT) * 8.0
	art.ground_cover(self, islands)
	art.props(self, islands)
	art.clouds(self, course_length)
	art.backdrop(self, course_length)
	art.near_course_scenery(self, islands)
	art.sparkles(self, course_length)
	_build_bounce_pads()
	_build_movers()
	_build_side_island()
	_build_bonus_stars()
	_build_checkpoint_flags()
	art.finish(self)
	actor = CharacterBody3D.new()
	actor.floor_snap_length = 0.3
	actor.floor_stop_on_slope = true
	actor.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	add_child(actor)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.3
	var collider := CollisionShape3D.new()
	collider.position.y = 0.7
	collider.shape = capsule
	actor.add_child(collider)
	var visual: Node3D = LUMO.instantiate()
	visual.scale = Vector3.ONE * 0.7
	visual.rotation.y = PI
	# Collider bottom sits 0.05 m above the actor origin; stand the feet on it
	# (previously the legs were buried and Lumo glided on its belly).
	visual.position.y = 0.05 + LumoGait.rest_foot_depth() * visual.scale.y
	actor.add_child(visual)
	gait = LumoGait.new()
	gait.name = "Gait"
	visual.add_child(gait)
	# Render the existing original 65-bone fox, never a different substitute,
	# when the imported GLB and all nine original animations are usable.
	# Procedural Lumo remains a safe visual fallback. His old gait still
	# receives events so pre-existing locomotion tests stay meaningful.
	var candidate = ORIGINAL_LUMO.new()
	candidate.name = "OriginalLumo"
	actor.add_child(candidate)
	if candidate.is_usable() and _fit_original_lumo(candidate):
		original_lumo = candidate
		visual.hide()
	else:
		candidate.queue_free()
	actor.position = islands[0] + Vector3(0, 0.4, 1.5)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62
	add_child(camera)
	camera.position = actor.position + Vector3(0, 5.5, 9)
	camera_target = actor.position + Vector3(0, 1, -3.2)
	camera.look_at(camera_target)


## Rescale the original rig from its actual imported skeleton: this preserves
## consistent screen size across Blender import settings and avoids guessing.
## Animation and physics stay separate; only visuals are positioned.
func _fit_original_lumo(candidate: Node3D) -> bool:
	var skeleton: Skeleton3D = candidate.skeleton
	if skeleton == null or skeleton.get_bone_count() != 65:
		return false
	var lowest: float = INF
	var highest: float = -INF
	for bone in range(skeleton.get_bone_count()):
		var rest: Vector3 = skeleton.get_bone_global_rest(bone).origin
		if not rest.is_finite():
			return false
		lowest = minf(lowest, rest.y)
		highest = maxf(highest, rest.y)
	var span: float = highest - lowest
	if span <= 0.2 or span > 15.0:
		return false
	var scaled: float = clampf(1.32 / span, 0.08, 3.0)
	candidate.scale = Vector3.ONE * scaled
	candidate.rotation.y = PI
	candidate.position.y = 0.05 - lowest * scaled
	return true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_safe = MarginContainer.new()
	var safe: MarginContainer = ui_safe
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 18)
	layer.add_child(safe)
	ui_column = VBoxContainer.new()
	var column: VBoxContainer = ui_column
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var back := _button("‹ Spiele", _pause)
	header_buttons.append(back)
	top.add_child(back)
	hud = _label("Insel 1/12", 21)
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hud)
	var pause_button := _button("Pause", _pause)
	header_buttons.append(pause_button)
	top.add_child(pause_button)
	message = _label("", 24)
	column.add_child(message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	controls_row = HBoxContainer.new()
	controls_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(controls_row)
	var left := VBoxContainer.new()
	controls_row.add_child(left)
	movement_stick = STICK.new()
	movement_stick.name = "MovementStick"
	movement_stick.tooltip_text = "Bewegen: Stick in die gewünschte Richtung ziehen."
	movement_stick.axis_changed.connect(_set_stick_axis)
	left.add_child(movement_stick)
	var move_hint := _label("BEWEGEN", 15)
	move_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(move_hint)
	control_hints.append(move_hint)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(gap)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	controls_row.add_child(right)
	jump_action = JUMP_ACTION.new()
	jump_action.name = "JumpAction"
	jump_action.hold_changed.connect(_set_jump_pressed)
	right.add_child(jump_action)
	var jump_hint := _label("HALTEN = HÖHER", 15)
	jump_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(jump_hint)
	control_hints.append(jump_hint)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -minf(300, get_viewport().get_visible_rect().size.x * 0.44)
	modal.offset_right = -modal.offset_left
	modal.offset_top = -245
	modal.offset_bottom = 245
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff9ed")
	style.set_corner_radius_all(22)
	style.set_content_margin_all(22)
	modal.add_theme_stylebox_override("panel", style)
	layer.add_child(modal)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_column)
	modal.hide()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()


func _layout_ui() -> void:
	if not is_instance_valid(ui_safe) or not is_instance_valid(modal):
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var window_pixels: Vector2 = Vector2(get_window().size)
	var pixels_per_unit: float = maxf(0.1, minf(window_pixels.x / maxf(view.x, 1), window_pixels.y / maxf(view.y, 1)))
	var unit: float = MobileRuntime.get_ui_density() / pixels_per_unit
	var insets: Rect2 = MobileRuntime.get_safe_area_insets()
	ui_safe.add_theme_constant_override("margin_left", roundi(maxf(16.0 * unit, insets.position.x / pixels_per_unit)))
	ui_safe.add_theme_constant_override("margin_right", roundi(maxf(16.0 * unit, insets.size.x / pixels_per_unit)))
	ui_safe.add_theme_constant_override("margin_top", roundi(maxf(12.0 * unit, insets.position.y / pixels_per_unit)))
	ui_safe.add_theme_constant_override("margin_bottom", roundi(maxf(12.0 * unit, insets.size.y / pixels_per_unit)))
	var stick_side: float = clampf(view.x / unit * 0.32, 112, 152) * unit
	movement_stick.custom_minimum_size = Vector2.ONE * stick_side
	jump_action.custom_minimum_size = Vector2.ONE * clampf(view.x / unit * 0.29, 104, 136) * unit
	for button in header_buttons:
		button.custom_minimum_size = Vector2(76, 48) * unit
		button.add_theme_font_size_override("font_size", roundi(17 * unit))
	for hint in control_hints:
		hint.add_theme_font_size_override("font_size", roundi(12 * unit))
	hud.add_theme_font_size_override("font_size", roundi(16 * unit))
	message.add_theme_font_size_override("font_size", roundi(18 * unit))
	ui_column.add_theme_constant_override("separation", roundi(8 * unit))
	var half_width: float = minf(300 * unit, view.x * 0.44)
	var half_height: float = minf(245 * unit, view.y * 0.38)
	modal.offset_left = -half_width
	modal.offset_right = half_width
	modal.offset_top = -half_height
	modal.offset_bottom = half_height


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("343457"))
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 64)
	button.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7264e8")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", style)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = Color("9184f1")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.pressed.connect(callback)
	return button


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	if not paused and not finished and not question_open:
		for crystal in crystals:
			crystal.rotation.y += delta
		for star in bonus_stars:
			if is_instance_valid(star) and star.visible:
				star.rotation.y += delta * 1.35
		_step_movers(delta)
	if not paused and not finished and not question_open:
		var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction: Vector2 = (keyboard + touch_direction).limit_length()
		var horizontal := Vector2(actor.velocity.x, actor.velocity.z)
		var grounded: bool = actor.is_on_floor()
		var acceleration: float = AIR_ACCELERATION
		if grounded:
			acceleration = GROUND_BRAKING if direction.length_squared() < 0.001 else GROUND_ACCELERATION
		horizontal = horizontal.move_toward(direction * RUN_SPEED, acceleration * delta)
		actor.velocity.x = horizontal.x
		actor.velocity.z = horizontal.y
		coyote_time = COYOTE_SECONDS if grounded else maxf(0, coyote_time - delta)
		jump_buffer = maxf(0, jump_buffer - delta)
		if Input.is_action_just_pressed("ui_accept"):
			_set_jump_pressed(true)
		if Input.is_action_just_released("ui_accept"):
			_set_jump_pressed(false)
		if grounded:
			jump_active = false
		if jump_buffer > 0 and coyote_time > 0:
			actor.velocity.y = JUMP_SPEED
			jump_active = true
			jump_buffer = 0
			coyote_time = 0
		else:
			actor.velocity.y -= GRAVITY * delta
		if jump_cut_pending and jump_active:
			actor.velocity.y = minf(actor.velocity.y, SHORT_JUMP_SPEED)
			jump_cut_pending = false
		_try_bounce(delta)
		actor.move_and_slide()
		if direction.length() > 0.1:
			actor.rotation.y = lerp_angle(
				actor.rotation.y, atan2(-direction.x, -direction.y), minf(1, delta * 10)
			)
		if actor.position.y < -8:
			_respawn()
		if actor.is_on_floor():
			for i in range(islands.size()):
				var point: Vector3 = islands[i]
				if (
					absf(actor.position.x - point.x) < 3.5
					and absf(actor.position.z - point.z) < 3.0
					and absf(actor.position.y - point.y) < 0.7
				):
					var previous_checkpoint: int = checkpoint
					checkpoint = maxi(checkpoint, i)
					if checkpoint > previous_checkpoint:
						_refresh_flags()
						_save_session()
					if i in [3, 6, 9] and not completed_questions.has(i):
						_open_question()
					elif i == ISLAND_COUNT - 1:
						_finish()
					break
		for i in range(crystals.size()):
			if crystals[i].visible and actor.position.distance_to(crystals[i].position) < 1.4:
				crystals[i].hide()
				collected[i] = true
				_save_session()
		for i in range(bonus_stars.size()):
			if (
				bonus_stars[i].visible
				and actor.global_position.distance_to(bonus_stars[i].global_position) < 1.4
			):
				bonus_stars[i].hide()
				stars_gathered[i] = true
				_save_session()
		save_timer += delta
		if save_timer >= 5.0:
			save_timer = 0
			_save_session()
	gait.step(actor.is_on_floor(), delta)
	if is_instance_valid(original_lumo):
		original_lumo.set_suspended(paused or question_open or finished)
		if not paused and not question_open and not finished:
			var relative_velocity: Vector3 = actor.get_real_velocity()
			if actor.is_on_floor():
				relative_velocity -= actor.get_platform_velocity()
			original_lumo.set_platform_motion(relative_velocity, actor.is_on_floor(), delta)
	if not paused and not question_open:
		var look_ahead := Vector3(actor.velocity.x * 0.16, 0, clampf(actor.velocity.z * 0.13, -0.8, 0.4))
		var desired: Vector3 = actor.position + Vector3(0, 5.5, 9) + look_ahead * 0.5
		camera.position = camera.position.lerp(desired, 1.0 - exp(-6.5 * delta))
		camera_target = camera_target.lerp(actor.position + Vector3(0, 1, -3.2) + look_ahead, 1.0 - exp(-9.0 * delta))
		camera.look_at(camera_target)
	hud.text = (
		"Insel %d/%d\n%d Kristalle · %d Sterne · %d Lernstopps"
		% [
			checkpoint + 1,
			ISLAND_COUNT,
			collected.size(),
			stars_gathered.size(),
			completed_questions.size()
		]
	)


func _set_stick_axis(value: Vector2) -> void:
	if not paused and not finished and not question_open:
		touch_direction = value


func _set_jump_pressed(value: bool) -> void:
	if paused or finished or question_open:
		return
	if value and not jump_held:
		jump_buffer = JUMP_BUFFER_SECONDS
		jump_cut_pending = false
	elif not value and jump_held:
		jump_cut_pending = true
	jump_held = value


func _set_controls_enabled(value: bool) -> void:
	if is_instance_valid(movement_stick):
		movement_stick.set_enabled(value)
	if is_instance_valid(jump_action):
		jump_action.set_enabled(value)


func _set_direction(direction: Vector2, pressed: bool) -> void:
	if pressed:
		held_directions[direction] = true
	else:
		held_directions.erase(direction)
	touch_direction = Vector2.ZERO
	for held in held_directions:
		touch_direction += held


func _stop_input() -> void:
	held_directions.clear()
	touch_direction = Vector2.ZERO
	jump_buffer = 0
	jump_held = false
	jump_cut_pending = false
	jump_active = false
	coyote_time = 0
	if is_instance_valid(movement_stick):
		movement_stick._reset()
	if is_instance_valid(jump_action):
		jump_action.reset()


func _respawn() -> void:
	falls += 1
	actor.position = islands[checkpoint] + Vector3(0, 0.5, 1)
	actor.velocity = Vector3.ZERO
	_stop_input()
	message.text = "Wir versuchen es noch einmal. Dein Kontrollpunkt ist gespeichert."


func _clear_modal() -> void:
	for child in modal_column.get_children():
		modal_column.remove_child(child)
		child.queue_free()


func _open_question() -> void:
	question_open = true
	_set_controls_enabled(false)
	actor.velocity = Vector3.ZERO
	_stop_input()
	wrong_count = 0
	for i in range(30):
		active_question = QUESTIONS.make(grade, subject, rng)
		if not recent_questions.has(active_question.prompt):
			break
	recent_questions.append(active_question.prompt)
	_save_session()
	_show_question()


func _show_question() -> void:
	_clear_modal()
	modal_column.add_child(_label("Lerninsel · %d. Klasse · %s" % [grade, subject], 19))
	modal_column.add_child(_label(active_question.prompt, 27))
	for answer in active_question.options:
		modal_column.add_child(_button(answer, func(): _answer(answer)))
	modal_column.add_child(_label("Lumo wartet auf dich. Du hast Zeit zum Nachdenken.", 18))
	modal.show()


func _answer(answer: String) -> void:
	if not question_open or paused or finished:
		return
	if answer == active_question.answer:
		completed_questions[checkpoint] = true
		question_open = false
		_set_controls_enabled(true)
		modal.hide()
		message.text = "Richtig! Weiter zur nächsten Wolkeninsel."
		_save_session()
	else:
		wrong_count += 1
		var hint: String = active_question.hint
		if wrong_count >= 3:
			hint += "\nDie Lösung ist %s. Tippe sie an und spring weiter." % active_question.answer
		modal_column.get_child(modal_column.get_child_count() - 1).text = (
			"Wir schauen gemeinsam hin: " + hint
		)


func _pause() -> void:
	if paused or finished:
		return
	paused = true
	_set_controls_enabled(false)
	_stop_input()
	actor.velocity = Vector3.ZERO
	_save_session()
	_clear_modal()
	modal_column.add_child(_label("Kleine Pause", 28))
	modal_column.add_child(_button("Weiterspielen", _resume))
	modal_column.add_child(
		_button("Zur Spieleauswahl · Abenteuer behalten", func(): _return_to_app("games"))
	)
	modal_column.add_child(
		_button("Zum Lernen · Abenteuer behalten", func(): _return_to_app("learn"))
	)
	modal_column.add_child(_button("Abenteuer neu beginnen", _restart))
	modal.show()


func _resume() -> void:
	paused = false
	_set_controls_enabled(not question_open and not finished)
	if question_open:
		_show_question()
	else:
		modal.hide()


func _restart() -> void:
	abandoned = true
	DirAccess.remove_absolute(SESSION)
	SceneRouter.goto("jump")


func _return_to_app(destination: String) -> void:
	_save_session()
	if finished:
		HostBridge.reward(result_payload)
		if HostBridge.reward_is_recoverable(result_id):
			DirAccess.remove_absolute(SESSION)
	var payload: Dictionary = (
		result_payload
		if finished
		else {
			"game": "jump",
			"resultId": result_id,
			"status": "paused",
			"stars": 0,
			"grade": grade,
			"subject": subject
		}
	)
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app(destination, payload):
			_show_host_save_failure()
		return
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _show_host_save_failure() -> void:
	message.text = HostBridge.SAVE_FAILURE
	if not modal_column.has_node("HostSaveFailure"):
		var label := _label(HostBridge.SAVE_FAILURE, 20)
		label.name = "HostSaveFailure"
		label.add_theme_color_override("font_color", Color("a14f3b"))
		modal_column.add_child(label)
		modal_column.move_child(label, 1)


func _finish() -> void:
	if finished:
		return
	finished = true
	_set_controls_enabled(false)
	_stop_input()
	var stars: int = 3 + completed_questions.size() * 2 + collected.size()
	ProgressStore.add_stars(stars)
	result_payload = {
		"game": "jump",
		"sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		"resultId": result_id,
		"status": "completed",
		"stars": stars,
		"solved": completed_questions.size(),
		"grade": grade,
		"subject": subject
	}
	var reward_accepted: bool = HostBridge.reward(result_payload)
	if HostBridge.reward_is_recoverable(result_id):
		DirAccess.remove_absolute(SESSION)
	_celebrate_goal()
	_clear_modal()
	modal_column.add_child(_label("Wolkeninseln geschafft! ★", 29))
	modal_column.add_child(
		_label(
			(
				"%d Lernstopps · %d Kristalle\n+%d Sterne"
				% [completed_questions.size(), collected.size(), stars]
			),
			23
		)
	)
	modal_column.add_child(_button("Noch ein Abenteuer", func(): SceneRouter.goto("jump")))
	modal_column.add_child(_button("Zur Spieleauswahl", func(): _return_to_app("games")))
	modal_column.add_child(_button("Zum Lernen", func(): _return_to_app("learn")))
	modal.show()
	if HostBridge.is_embedded() and not reward_accepted:
		_show_host_save_failure()
	print("[Jump] finished: stars=%d questions=%d" % [stars, completed_questions.size()])


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if finished:
			_return_to_app("games")
		elif paused:
			_resume()
		else:
			_pause()


func _save_session() -> void:
	if finished or abandoned or not is_instance_valid(actor):
		return
	var config := ConfigFile.new()
	config.set_value("jump", "version", 1)
	config.set_value("jump", "grade", grade)
	config.set_value("jump", "subject", subject)
	for key in [
		"result_id",
		"checkpoint",
		"falls",
		"collected",
		"stars_gathered",
		"completed_questions",
		"active_question",
		"recent_questions",
		"wrong_count",
		"question_open"
	]:
		config.set_value("jump", key, get(key))
	if config.save(SESSION + ".tmp") == OK:
		var error: Error = DirAccess.rename_absolute(SESSION + ".tmp", SESSION)
		if error != OK:
			push_warning("Jump checkpoint could not be saved: %s" % error)


func _restore_session() -> bool:
	var config := ConfigFile.new()
	if config.load(SESSION) != OK or config.get_value("jump", "version", 0) != 1:
		return false
	if (
		config.get_value("jump", "grade", 0) != grade
		or config.get_value("jump", "subject", "") != subject
	):
		return false
	for key in [
		"result_id",
		"checkpoint",
		"falls",
		"collected",
		"stars_gathered",
		"completed_questions",
		"active_question",
		"wrong_count",
		"question_open"
	]:
		set(key, config.get_value("jump", key, get(key)))
	recent_questions.assign(config.get_value("jump", "recent_questions", recent_questions))
	checkpoint = clampi(checkpoint, 0, ISLAND_COUNT - 2)
	actor.position = islands[checkpoint] + Vector3(0, 0.5, 1)
	actor.velocity = Vector3.ZERO
	for i in range(crystals.size()):
		crystals[i].visible = not collected.has(i)
	for i in range(bonus_stars.size()):
		bonus_stars[i].visible = not stars_gathered.has(i)
	_refresh_flags()
	return true



func _build_bounce_pads() -> void:
	# Side-back corners keep the main forward path (and the auto-traverser) clear.
	for i in [2, 5, 8]:
		if i >= islands.size():
			continue
		var world: Vector3 = islands[i] + Vector3(2.65, 0.15, 1.85)
		var node := Node3D.new()
		node.name = "BouncePad%d" % i
		node.position = world
		add_child(node)
		art.bounce_pad(node)
		bounce_pads.append(world)


func _build_movers() -> void:
	for spec in [
		{"index": 1, "side": 1.0, "seed": 21.0},
		{"index": 4, "side": -1.0, "seed": 33.0},
		{"index": 7, "side": 1.0, "seed": 47.0}
	]:
		var index: int = int(spec["index"])
		if index + 1 >= islands.size():
			continue
		var mid: Vector3 = (islands[index] + islands[index + 1]) * 0.5
		var origin: Vector3 = mid + Vector3(float(spec["side"]) * 5.8, 0.12, 0)
		var body := AnimatableBody3D.new()
		body.name = "MovingIsland%d" % index
		body.sync_to_physics = true
		add_child(body)
		body.position = origin
		art.mini_island(body, Vector2(3.15, 2.55), float(spec["seed"]))
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.15, 0.45, 2.55)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		movers.append(
			{
				"body": body,
				"origin": origin,
				"axis": Vector3(float(spec["side"]) * 1.75, 0.0, 0.0),
				"speed": 0.7,
				"clock": 0.0
			}
		)


func _build_side_island() -> void:
	if islands.size() < 5:
		return
	extra_island = islands[4] + Vector3(7.15, 0.55, -1.4)
	var ground := StaticBody3D.new()
	ground.name = "BonusIsland"
	ground.position = extra_island
	add_child(ground)
	art.mini_island(ground, Vector2(4.0, 3.35), 91.0)
	art.tree(ground, Vector3(-1.15, 0, -0.9))
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 0.5, 3.35)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)


func _build_bonus_stars() -> void:
	var spots: Array[Vector3] = []
	for pad in bounce_pads:
		spots.append(pad + Vector3(0, 2.15, 0))
	for mover in movers:
		var rider := Node3D.new()
		rider.name = "MoverStar"
		rider.position = Vector3(0, 1.55, 0)
		mover["body"].add_child(rider)
		art.gem(rider)
		bonus_stars.append(rider)
	if extra_island != Vector3.ZERO:
		spots.append(extra_island + Vector3(-0.8, 1.25, 0.4))
		spots.append(extra_island + Vector3(0.9, 1.25, -0.35))
	for i in range(spots.size()):
		var star := Node3D.new()
		star.name = "BonusStar%d" % i
		star.position = spots[i]
		add_child(star)
		art.gem(star)
		bonus_stars.append(star)


func _build_checkpoint_flags() -> void:
	for i in [0, 3, 6, 9]:
		if i >= islands.size():
			continue
		var holder := Node3D.new()
		holder.name = "CheckpointFlag%d" % i
		holder.position = islands[i] + Vector3(-2.45, 0, 1.85)
		add_child(holder)
		checkpoint_flags[i] = art.checkpoint_flag(holder)
	_refresh_flags()


func _refresh_flags() -> void:
	if art == null:
		return
	for i in checkpoint_flags:
		art.set_flag_active(checkpoint_flags[i], int(i) <= checkpoint)


func _step_movers(delta: float) -> void:
	for mover in movers:
		mover["clock"] = float(mover["clock"]) + delta * float(mover["speed"])
		var body: AnimatableBody3D = mover["body"]
		if is_instance_valid(body):
			body.position = Vector3(mover["origin"]) + Vector3(mover["axis"]) * sin(float(mover["clock"]))


func _try_bounce(delta: float) -> void:
	bounce_cooldown = maxf(0.0, bounce_cooldown - delta)
	if bounce_cooldown > 0.0 or not actor.is_on_floor():
		return
	for pad in bounce_pads:
		if actor.position.distance_to(pad) < 0.9:
			actor.velocity.y = 12.0
			bounce_cooldown = 0.28
			return


func _celebrate_goal() -> void:
	var burst := CPUParticles3D.new()
	burst.name = "GoalCelebration"
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 42
	burst.lifetime = 1.5
	burst.preprocess = 0.05
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.55
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.gravity = Vector3(0, -2.4, 0)
	burst.initial_velocity_min = 2.4
	burst.initial_velocity_max = 5.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color("ffe27a")
	mat.emission_enabled = true
	mat.emission = Color("ffd75e")
	mat.emission_energy_multiplier = 2.2
	quad.material = mat
	burst.mesh = quad
	burst.position = islands[ISLAND_COUNT - 1] + Vector3(0, 2.15, -1.6)
	add_child(burst)
	if is_instance_valid(original_lumo) and original_lumo.has_method("play_behavior"):
		original_lumo.play_behavior("celebrate")

func _notification(what: int) -> void:
	if not is_instance_valid(modal):
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if paused or finished:
			_return_to_app("games")
		else:
			_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause()


func _exit_tree() -> void:
	_save_session()
	get_tree().auto_accept_quit = previous_auto_accept_quit
	get_tree().quit_on_go_back = previous_quit_on_go_back
