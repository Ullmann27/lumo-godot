extends Node3D
const STATE = preload("res://scripts/creative/treasure_state.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const FOX = preload("res://scripts/games/kart_vehicle.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const ACTION = preload("res://scripts/games/kart_touch_action.gd")
const CHEST_MODEL = preload("res://assets/creative/models/lumo_treasure_chest.glb")
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
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_TREASURE_DAY)
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
	var terrain := MeshInstance3D.new()
	terrain.name = "TreasureTerrain"
	terrain.mesh = _terrain_mesh()
	terrain.material_override = _terrain_material()
	ground.add_child(terrain)
	kit.collision(ground, Vector3(0, -0.65, -29), Vector3(74, 1.3, 88))
	# A continuous promenade lets younger children return to any clue without getting lost.
	var path_xforms: Array[Transform3D] = []
	for i in range(39):
		var z: float = 8 - i * 2
		path_xforms.append(
			Transform3D(Basis.from_scale(Vector3(4.5, 0.05, 1.94)), Vector3(0, 0.025, z))
		)
		if i % 4 == 0:
			for x in [-3.5, 3.5]:
				var lamp := kit.part_node(CATALOG.part("lantern"))
				lamp.position = Vector3(x, 0, z)
				add_child(lamp)
	var paver := BoxMesh.new()
	paver.size = Vector3.ONE
	BuildVoxelStyle.multimesh(
		self, "TreasurePath", paver, BuildVoxelStyle.material("paving", Color("d8d2c4")), path_xforms
	)
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
		var rock := kit.mesh(self, kit.SHAPES.rock(), Vector3(13 + i * 3, 2, -22), Color.WHITE)
		rock.material_override = BuildVoxelStyle.material("stone", Color("c4bba8"))
		rock.scale = Vector3(4, 5 + i, 3)
		var fall := kit.part_node(CATALOG.part("waterfall"))
		fall.position = Vector3(13 + i * 3, 0, -20.4)
		fall.scale.y = 2.3
		add_child(fall)
	gate = StaticBody3D.new()
	add_child(gate)
	var door: MeshInstance3D = kit.box(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28), Color.WHITE)
	door.material_override = BuildVoxelStyle.material("wood", Color("c99558"))
	kit.box(gate, Vector3(-1.15, 1.75, -30.84), Vector3(1.7, 2.15, 0.08), Color("b88850"))
	kit.box(gate, Vector3(1.15, 1.75, -30.84), Vector3(1.7, 2.15, 0.08), Color("b88850"))
	kit.box(gate, Vector3(0, 3.05, -30.84), Vector3(4.4, 0.2, 0.08), Color("d6b25a"))
	kit.collision(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28))
	for x in [-3.45, 3.45]:
		var pillar: MeshInstance3D = kit.cylinder(self, Vector3(x, 2.15, -31), 0.62, 4.3, Color.WHITE)
		pillar.material_override = BuildVoxelStyle.material("sand", Color("d9a86c"))
		var cap: MeshInstance3D = kit.sphere(self, Vector3(x, 4.55, -31), Vector3.ONE * 0.85, Color.WHITE)
		cap.material_override = BuildVoxelStyle.material("sand", Color("e2b878"))
	var lintel: MeshInstance3D = kit.box(self, Vector3(0, 4.5, -31), Vector3(8.2, 0.75, 1.15), Color.WHITE)
	lintel.material_override = BuildVoxelStyle.material("sand", Color("d9a86c"))
	var keystone: MeshInstance3D = kit.box(self, Vector3(0, 5.15, -31), Vector3(1.5, 0.7, 1.25), Color.WHITE)
	keystone.material_override = BuildVoxelStyle.material("sand", Color("e2b878"))
	for i in range(4):
		var crystal := kit.mesh(
			self, kit.SHAPES.crystal(), Vector3(-17.5 + i * 1.65, 1.2, -40.2), Color("7ee7ff"), true
		)
		crystal.scale = Vector3(1, 2.4, 1)
	for i in range(12):
		var flowers := kit.part_node(CATALOG.part("flowers"))
		flowers.position = Vector3(13.0 + i % 4 * 1.4, 0, -50.5 + i / 4 * 1.3)
		add_child(flowers)
	kit.castle(self, Vector3(0, 0, -60), 1.7)
	var chest: Node3D = CHEST_MODEL.instantiate()
	chest.name = "OriginalBlenderTreasureChest"
	chest.position = Vector3(0, 0, -65)
	add_child(chest)
	for i in range(7):
		var mountain := kit.mesh(
			self, kit.SHAPES.mountain(), Vector3(-48 + i * 16, 0, -91), Color.WHITE
		)
		mountain.material_override = BuildVoxelStyle.material("stone", Color("8fa07a"))
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


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = BuildVoxelStyle.material("grass_top").albedo_texture
	mat.normal_enabled = true
	mat.normal_texture = BuildVoxelStyle.material("grass_top").normal_texture
	mat.normal_scale = 0.55
	mat.albedo_color = Color("c4c2a4")
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3(0.055, 0.055, 0.055)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _terrain_mesh() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 71882
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var cols := 48
	var rows := 56
	var origin := Vector3(-40.0, 0.0, -75.0)
	var step := Vector2(80.0 / float(cols - 1), 94.0 / float(rows - 1))
	var verts: Array[Vector3] = []
	var colors: PackedColorArray = PackedColorArray()
	verts.resize(cols * rows)
	colors.resize(cols * rows)
	for row in range(rows):
		for col in range(cols):
			var x: float = origin.x + float(col) * step.x
			var z: float = origin.z + float(row) * step.y
			var nx: float = absf(x) / 37.0
			var nz: float = absf(z + 29.0) / 44.0
			var radial: float = pow(nx * nx * nx * nx + nz * nz * nz * nz, 0.25)
			var rim: float = clampf((radial - 0.78) / 0.28, 0.0, 1.0)
			var path: float = 1.0 - clampf((absf(x) - 2.15) / 1.7, 0.0, 1.0)
			var wave: float = noise.get_noise_2d(x, z) * 0.11 * (1.0 - path) * (1.0 - rim)
			var y: float = wave - rim * rim * 2.35
			var grass := Color("6d7d4c").lerp(Color("5a6d40"), 0.5 + 0.5 * noise.get_noise_2d(x + 40.0, z - 12.0))
			grass = grass.lerp(Color("7a7a48"), clampf(0.35 + noise.get_noise_2d(x - 18.0, z + 9.0), 0.0, 0.45))
			var dirt := Color("8a7a55")
			var sand := Color("c4b48a")
			var rock := Color("7a7468")
			var color: Color = grass.lerp(dirt, path)
			color = color.lerp(sand, clampf(rim * 1.4, 0.0, 1.0))
			if rim > 0.72:
				color = color.lerp(rock, (rim - 0.72) / 0.28)
			var idx: int = row * cols + col
			verts[idx] = Vector3(x, y, z)
			colors[idx] = color
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows - 1):
		for col in range(cols - 1):
			var a: int = row * cols + col
			var b: int = a + 1
			var c: int = a + cols
			var d: int = c + 1
			for idx in [a, c, b, b, c, d]:
				st.set_color(colors[idx])
				st.set_uv(Vector2(verts[idx].x * 0.08, verts[idx].z * 0.08))
				st.add_vertex(verts[idx])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
