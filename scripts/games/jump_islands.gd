extends Node3D

const QUESTIONS = preload("res://scripts/games/kart_questions.gd")
const LUMO = preload("res://scenes/characters/lumo/lumo_character.tscn")
const ISLAND_COUNT: int = 12
const SESSION: String = "user://jump_session.cfg"
var actor: CharacterBody3D
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
var material_cache: Dictionary = {}
var result_id: String = ""
var result_payload: Dictionary = {}
var abandoned: bool = false
var save_timer: float = 0.0
var previous_auto_accept_quit: bool = true


func _ready() -> void:
	rng.randomize()
	grade = clampi(int(SceneRouter.launch_options.get("grade", 1)), 1, 4)
	subject = str(SceneRouter.launch_options.get("subject", "Mathematik"))
	if subject not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
		subject = "Mathematik"
	result_id = HostBridge.new_result_id()
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_world()
	_build_ui()
	message.text = "Lumos Wolkeninseln\nPfeile zum Laufen · Springen über die Lücken"
	if _restore_session():
		_pause()
		message.text = "Dein Abenteuer wartet am letzten Kontrollpunkt."
	print("[Jump] ready: true 3D, grade=%d, subject=%s" % [grade, subject])


func _material(color: Color) -> StandardMaterial3D:
	if material_cache.has(color):
		return material_cache[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	material_cache[color] = mat
	return mat


func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	parent.add_child(node)
	return node


func _sphere(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 20
	mesh.rings = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	node.scale = size
	node.position = position
	parent.add_child(node)
	return node


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7d7ee")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0e8ff")
	env.ambient_light_energy = 0.3
	env.tonemap_exposure = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color("b5c9ed")
	env.fog_density = 0.007
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	for i in range(ISLAND_COUNT):
		var point := Vector3(
			sin(float(i) * 0.75) * 3.0, sin(float(i) * 0.55) * 0.9, -float(i) * 8.0
		)
		islands.append(point)
		var ground := StaticBody3D.new()
		ground.position = point
		add_child(ground)
		_box(ground, Vector3.ZERO, Vector3(7, 0.5, 6), Color("64b58d"))
		var shape := BoxShape3D.new()
		shape.size = Vector3(7, 0.5, 6)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		ground.add_child(collision)
		_sphere(ground, Vector3(0, -1.2, 0), Vector3(3.6, 1.7, 3.1), Color("9e8bb1"))
		_sphere(ground, Vector3(0.7, -2.7, 0.5), Vector3(1.9, 1.5, 1.7), Color("7d6d99"))
		var number := Label3D.new()
		number.text = "ZIEL" if i == ISLAND_COUNT - 1 else "INSEL %d" % (i + 1)
		number.position = Vector3(0, 0.4, -2.3)
		number.rotation_degrees.x = -90
		number.font_size = 40
		number.pixel_size = 0.02
		ground.add_child(number)
		if i > 0:
			var crystal := Node3D.new()
			crystal.position = point + Vector3(0, 1.2, 0)
			add_child(crystal)
			var gem := _box(crystal, Vector3.ZERO, Vector3(0.55, 0.55, 0.55), Color("f7bf4f"))
			gem.rotation_degrees = Vector3(45, 0, 45)
			crystals.append(crystal)
		if i % 2 == 0:
			_box(ground, Vector3(-2.7, 1.1, -1.7), Vector3(0.3, 1.7, 0.3), Color("b18b68"))
			_sphere(ground, Vector3(-2.7, 2.2, -1.7), Vector3(0.9, 1.1, 0.9), Color("73c87f"))
	for i in range(14):
		_sphere(
			self,
			Vector3(-22 + float(i % 3) * 20, -4 - float(i % 2) * 2, -float(i) * 7),
			Vector3(8, 1.5, 4),
			Color("e8efff")
		)
	actor = CharacterBody3D.new()
	actor.floor_snap_length = 0.3
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
	actor.add_child(visual)
	actor.position = islands[0] + Vector3(0, 0.4, 1.5)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 62
	add_child(camera)
	camera.position = actor.position + Vector3(0, 5.5, 9)
	camera.look_at(actor.position + Vector3(0, 1, -4))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 18)
	layer.add_child(safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	safe.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	top.add_child(_button("‹ Spiele", _pause))
	hud = _label("Insel 1/12", 21)
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hud)
	top.add_child(_button("Pause", _pause))
	message = _label("", 24)
	column.add_child(message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	for direction in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		var labels: Dictionary = {
			Vector2.LEFT: "◀", Vector2.UP: "▲", Vector2.DOWN: "▼", Vector2.RIGHT: "▶"
		}
		var button := _button(labels[direction], func(): pass)
		button.custom_minimum_size = Vector2(76, 78)
		button.button_down.connect(func(): _set_direction(direction, true))
		button.button_up.connect(func(): _set_direction(direction, false))
		controls.add_child(button)
	var jump := _button("Springen", func(): jump_buffer = 0.15)
	jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(jump)
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
	if not paused and not finished and not question_open:
		var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction: Vector2 = (keyboard + touch_direction).limit_length()
		actor.velocity.x = move_toward(actor.velocity.x, direction.x * 5.5, delta * 18)
		actor.velocity.z = move_toward(actor.velocity.z, direction.y * 5.5, delta * 18)
		coyote_time = 0.12 if actor.is_on_floor() else maxf(0, coyote_time - delta)
		jump_buffer = maxf(0, jump_buffer - delta)
		if Input.is_action_just_pressed("ui_accept"):
			jump_buffer = 0.15
		if jump_buffer > 0 and coyote_time > 0:
			actor.velocity.y = 8.5
			jump_buffer = 0
			coyote_time = 0
		else:
			actor.velocity.y -= 18 * delta
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
		save_timer += delta
		if save_timer >= 5.0:
			save_timer = 0
			_save_session()
	var desired: Vector3 = actor.position + Vector3(0, 5.5, 9)
	camera.position = camera.position.lerp(desired, minf(1, delta * 5))
	camera.look_at(actor.position + Vector3(0, 1, -4))
	hud.text = (
		"Insel %d/%d\n%d Kristalle · %d Lernstopps"
		% [checkpoint + 1, ISLAND_COUNT, collected.size(), completed_questions.size()]
	)


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
	return true


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
