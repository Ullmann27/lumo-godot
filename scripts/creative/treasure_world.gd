extends Node3D
const STATE = preload("res://scripts/creative/treasure_state.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const FOX = preload("res://scripts/games/kart_vehicle.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const ACTION = preload("res://scripts/games/kart_touch_action.gd")
var model = STATE.new()
var kit = KIT.new()
var previous: Dictionary
var safe_ui: Control
var player: CharacterBody3D
var fox: Node3D
var camera: Camera3D
var marker: MeshInstance3D
var gate: StaticBody3D
var joystick: Control
var action: Control
var inventory_label: Label
var clue_label: Label
var toast: Label
var modal: PanelContainer
var modal_box: VBoxContainer
var paused: bool = false
var jumping: bool = false
var time: float = 0
var save_clock: float = 0
var save_path: String
var last_saved: Vector3


func _ready() -> void:
	previous = RUNTIME.enter(self)
	SceneRouter.current_scene_id = "treasure"
	var child: String = (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	save_path = "user://lumo_treasure_" + child + ".json"
	if FileAccess.file_exists(save_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:
			model.restore(saved)
	if model.result_id.is_empty():
		model.result_id = HostBridge.new_result_id()
	kit.environment(self)
	_landscape()
	player = CharacterBody3D.new()
	player.name = "LumoExplorer"
	add_child(player)
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	capsule.shape = shape
	capsule.position.y = 0.8
	player.add_child(capsule)
	fox = FOX.new()
	player.add_child(fox)
	fox.configure_companion("fox")
	fox.scale = Vector3.ONE * 1.6
	player.position = model.position
	last_saved = model.position
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 55
	camera.current = true
	camera.position = player.position + Vector3(10, 14, 19)
	marker = kit.mesh(self, kit.SHAPES.star(), Vector3.ZERO, Color("ffe7a1"), true)
	marker.scale = Vector3.ONE * 0.65
	_ui()
	get_viewport().size_changed.connect(func(): RUNTIME.safe_area(self, safe_ui))
	RUNTIME.safe_area(self, safe_ui)
	_update()
	if model.completed:
		_win()


func _exit_tree() -> void:
	RUNTIME.restore(self, previous)


func _landscape() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var mesh := kit.box(ground, Vector3(0, -0.65, -29), Vector3(74, 1.3, 88), Color.WHITE)
	mesh.material_override = kit.textured("grass", Color("81b4ad"))
	kit.collision(ground, Vector3(0, -0.65, -29), Vector3(74, 1.3, 88))
	# A continuous promenade lets younger children return to any clue without getting lost.
	for i in range(39):
		var z: float = 8 - i * 2
		var path := kit.box(self, Vector3(0, 0.025, z), Vector3(4.5, 0.05, 1.94), Color.WHITE)
		path.material_override = kit.textured("stone", Color("89b0ce"))
		if i % 4 == 0:
			for x in [-3.5, 3.5]:
				var lamp := kit.part_node(CATALOG.part("lantern"))
				lamp.position = Vector3(x, 0, z)
				add_child(lamp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71882
	for i in range(55):
		var at := Vector3(rng.randf_range(-31, 31), 0, rng.randf_range(-71, 13))
		if absf(at.x) < 5:
			continue
		var near_clue := false
		for clue in STATE.CLUES:
			near_clue = near_clue or at.distance_to(clue.at) < 5
		if near_clue:
			continue
		var node := kit.part_node(CATALOG.part("tree" if i % 3 else "bush"))
		node.position = at
		if i % 3:
			node.scale = Vector3.ONE * rng.randf_range(1.1, 1.8)
		add_child(node)
	var tree := kit.part_node(CATALOG.part("tree"))
	tree.position = STATE.CLUES[0].at + Vector3(-1, 0, -1)
	tree.scale = Vector3.ONE * 2
	add_child(tree)
	for i in range(3):
		var rock := kit.mesh(self, kit.SHAPES.rock(), Vector3(13 + i * 3, 2, -22), Color("73869d"))
		rock.scale = Vector3(4, 5 + i, 3)
		var fall := kit.part_node(CATALOG.part("waterfall"))
		fall.position = Vector3(13 + i * 3, 0, -20.4)
		fall.scale.y = 2.3
		add_child(fall)
	gate = StaticBody3D.new()
	add_child(gate)
	kit.box(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28), Color("4f6896"))
	kit.collision(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28))
	for x in [-3.4, 3.4]:
		kit.cylinder(self, Vector3(x, 2.1, -31), 0.55, 4.2, Color("adb9d0"))
		kit.sphere(self, Vector3(x, 4.5, -31), Vector3.ONE * 0.8, Color("7fe8ce"), true)
	for i in range(4):
		var node := kit.mesh(
			self, kit.SHAPES.crystal(), Vector3(-17.5 + i * 1.65, 1.2, -40.2), Color("a9b7ff"), true
		)
		node.scale = Vector3(1, 2.4, 1)
	for i in range(12):
		var flowers := kit.part_node(CATALOG.part("flowers"))
		flowers.position = Vector3(13.0 + i % 4 * 1.4, 0, -50.5 + i / 4 * 1.3)
		add_child(flowers)
	kit.castle(self, Vector3(0, 0, -60), 1.7)
	var chest := kit.box(self, Vector3(0, 0.7, -65), Vector3(2.5, 1.4, 1.4), Color("775986"))
	chest.material_override = kit.textured("wood", Color("bab3d8"))
	for x in [-0.9, 0.9]:
		kit.box(self, Vector3(x, 0.76, -65), Vector3(0.16, 1.55, 1.5), Color("ffc985"), true)
	kit.box(self, Vector3(0, 0.75, -64.27), Vector3(0.45, 0.45, 0.1), Color("ffc985"), true)
	for i in range(7):
		var mountain := kit.mesh(
			self, kit.SHAPES.mountain(), Vector3(-48 + i * 16, 0, -91), Color("354d78")
		)
		mountain.scale = Vector3(18, 25 + (i % 3) * 8, 16)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	top.add_child(KIT.label("LUMOS STERNENSCHATZ", 24))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(KIT.button("Rucksack", _inventory))
	top.add_child(KIT.button("Ⅱ", _pause_menu, 52))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", KIT.panel())
	panel.position = Vector2(14, 82)
	panel.custom_minimum_size = Vector2(380, 0)
	safe_ui.add_child(panel)
	clue_label = KIT.label("", 18)
	clue_label.custom_minimum_size.x = 350
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(clue_label)
	toast = KIT.label("Erkunde die Insel. Folge dem goldenen Stern!", 17)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-280, -45)
	toast.custom_minimum_size.x = 560
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_ui.add_child(toast)
	joystick = STICK.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(20, -208)
	joystick.size = Vector2(188, 188)
	joystick.tooltip_text = "Bewegen: Stick, Pfeiltasten oder WASD."
	safe_ui.add_child(joystick)
	action = ACTION.new()
	action.text = "ANSEHEN"
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.position = Vector2(-180, -190)
	action.size = Vector2(152, 152)
	action.pressed.connect(_interact)
	safe_ui.add_child(action)
	var jump := KIT.button("Springen", _jump, 110)
	jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-165, -250)
	safe_ui.add_child(jump)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", KIT.panel())
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.position = Vector2(-260, -180)
	modal.custom_minimum_size = Vector2(520, 360)
	safe_ui.add_child(modal)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 12)
	modal.add_child(modal_box)
	modal.hide()


func _physics_process(delta: float) -> void:
	if paused:
		return
	time += delta
	var axis: Vector2 = joystick.axis
	axis += Vector2(
		(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		),
		(
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		)
	)
	axis = axis.limit_length(1)
	player.velocity.x = move_toward(player.velocity.x, axis.x * 6, delta * 28)
	player.velocity.z = move_toward(player.velocity.z, axis.y * 6, delta * 28)
	if not player.is_on_floor():
		player.velocity.y -= delta * 22
	elif jumping:
		player.velocity.y = 8.5
		jumping = false
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -35, 35)
	player.position.z = clampf(player.position.z, -71, 13)
	if model.chapter < 3:
		player.position.z = maxf(player.position.z, -30)
	if axis.length() > 0.12:
		fox.rotation.y = lerp_angle(fox.rotation.y, atan2(-axis.x, -axis.y), delta * 10)
	fox.set_companion_pose(time, "walk" if axis.length() > 0.12 else "idle")
	camera.position = camera.position.lerp(
		player.position + Vector3(10, 14, 19), minf(1, delta * 4)
	)
	camera.look_at(player.position + Vector3.UP)
	marker.position = model.current().at + Vector3.UP * (3.5 + sin(time * 2) * 0.2)
	marker.rotate_y(delta)
	action.disabled = not model.can_interact(player.position)
	save_clock += delta
	if save_clock > 3:
		save_clock = 0
		if last_saved.distance_to(player.position) > 0.3:
			_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_menu()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_jump()
		if event.keycode == KEY_E:
			_interact()


func _jump() -> void:
	if not paused and player.is_on_floor():
		jumping = true


func _update() -> void:
	gate.visible = model.chapter < 3
	gate.process_mode = Node.PROCESS_MODE_INHERIT if gate.visible else Node.PROCESS_MODE_DISABLED
	for child in gate.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not gate.visible)
	marker.visible = not model.completed
	clue_label.text = (
		"Hinweis %d / %d\n%s"
		% [mini(model.chapter + 1, STATE.CLUES.size()), STATE.CLUES.size(), model.current().lead]
	)


func _open_modal(title: String) -> void:
	paused = true
	joystick.set_enabled(false)
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()
	modal.show()
	modal_box.add_child(KIT.label(title, 25))


func _close_modal() -> void:
	paused = false
	modal.hide()
	joystick.set_enabled(true)


func _interact() -> void:
	if paused or not model.can_interact(player.position):
		return
	var clue: Dictionary = model.current()
	_open_modal(clue.name)
	var text := KIT.label(clue.question, 19)
	text.custom_minimum_size.x = 480
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(text)
	for i in range(clue.answers.size()):
		modal_box.add_child(KIT.button(clue.answers[i], _answer.bind(i)))
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))


func _answer(choice: int) -> void:
	if not model.answer(choice, player.position):
		toast.text = "Schau noch einmal genau hin. Du kannst es wieder versuchen."
		return
	if not _save():
		toast.text = "Dein Fund ist da. Speichern war nicht möglich; bitte erneut speichern."
		_update()
		_close_modal()
		return
	_update()
	_close_modal()
	toast.text = "Gefunden: " + model.inventory[-1] + "! Dein Rucksack wächst."
	if model.completed:
		_win()


func _save() -> bool:
	model.position = player.position
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(model.to_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		toast.text = "Speichern fehlgeschlagen. Dein Abenteuer bleibt geöffnet."
		return false
	last_saved = player.position
	return true


func _inventory() -> void:
	_open_modal("Dein Abenteuer-Rucksack")
	modal_box.add_child(
		KIT.label(
			(
				"Noch leer – dein erster Hinweis wartet!"
				if model.inventory.is_empty()
				else "\n".join(model.inventory)
			),
			19
		)
	)
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))


func _pause_menu() -> void:
	if paused:
		_close_modal()
		return
	_save()
	_open_modal("Dein Abenteuer wartet")
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))
	modal_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _win() -> void:
	if not _save():
		return
	HostBridge.reward(
		{
			"resultId": model.result_id,
			"game": "treasure",
			"status": "completed",
			"stars": 3,
			"xp": 40
		}
	)
	_open_modal("Der Sternenschatz gehört euch!")
	(
		modal_box
		. add_child(
			(
				KIT
				. label(
					"Sieben Hinweise gelöst und alle Schlüssel gefunden.\n3 Sterne und 40 Erfahrungspunkte!",
					19
				)
			)
		)
	)
	modal_box.add_child(KIT.button("Insel weiter erkunden", _close_modal))
	modal_box.add_child(KIT.button("Neues Abenteuer", _new_adventure))
	modal_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _new_adventure() -> void:
	model = STATE.new()
	model.result_id = HostBridge.new_result_id()
	player.position = model.position
	_save()
	_update()
	_close_modal()


func _notification(what: int) -> void:
	if (
		what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]
		and is_instance_valid(player)
	):
		_save()
		if not paused:
			_pause_menu()


func _leave() -> void:
	if _save():
		SceneRouter.goto("games")
