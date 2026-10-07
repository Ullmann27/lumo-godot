extends Node3D
## Touch-first, actual 3D construction. No prerendered screenshot substitutes the world.
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const STATE = preload("res://scripts/creative/build_state.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
var model = STATE.new()
var kit = KIT.new()
var world: Node3D
var camera: Camera3D
var preview: MeshInstance3D
var guide: MeshInstance3D
var chosen: String = "sand"
var category: String = "Bauen"
var turn: int = 0
var layer: int = 0
var erase_mode: bool = false
var paused: bool = false
var orbit: float = 0.62
var tilt: float = 0.68
var radius: float = 29.0
var focus := Vector3(-2, 0, 0)
var tap_start := Vector2.ZERO
var pointer_id: int = -1
var dragged: bool = false
var status: Label
var goal_label: Label
var count_label: Label
var palette: HBoxContainer
var goal: String = "bridge"
var slot: int = 1
var child_key: String = "standalone"
var save_path: String
var pause_panel: PanelContainer
var guide_path: Array[Vector3i] = []
var guide_time: float = 0.0
var autosave: float = 0.0
var dirty: bool = false
var previous_runtime: Dictionary
var safe_ui: Control
var placed_nodes: Dictionary = {}
var touches: Dictionary = {}
var touch_gesture: bool = false


func _ready() -> void:
	previous_runtime = RUNTIME.enter(self)
	SceneRouter.current_scene_id = "build"
	child_key = (
		str(
			SceneRouter.launch_options.get(
				"childKey", HostBridge.launch_options().get("childKey", "standalone")
			)
		)
		. validate_filename()
		. substr(0, 80)
	)
	save_path = "user://lumo_build_" + child_key + "_1.json"
	kit.environment(self)
	_ground()
	world = Node3D.new()
	world.name = "Construction"
	add_child(world)
	camera = Camera3D.new()
	camera.fov = 52
	camera.far = 200
	add_child(camera)
	camera.current = true
	preview = kit.box(self, Vector3(-5, 0.5, 0), Vector3.ONE * 1.01, Color("67deff"))
	preview.material_override = kit.material(Color("67deff"), true, true)
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guide = kit.mesh(
		self,
		preload("res://scripts/games/kart_world_meshes.gd").star(),
		Vector3(-1, 2, 2.5),
		Color("ffe6a0"),
		true
	)
	guide.scale = Vector3.ONE * 0.3
	guide.visible = false
	_ui()
	if not load_world(false):
		model.template("castle")
		# Start with a usable scene and leave the first bridge task for the child.
		model.place("tree", Vector3i(-11, 0, 3))
		model.place("lantern", Vector3i(-4, 0, -4))
		model.place("flowers", Vector3i(-7, 0, 1))
	_rebuild()
	_camera_update()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_update_labels()
	print("[Bauwelt] ready: real geometry, ", CATALOG.PARTS.size(), " parts, save=", save_path)


func _ground() -> void:
	for side in [-1, 1]:
		var bank := StaticBody3D.new()
		bank.name = "RiverBank"
		add_child(bank)
		var center := Vector3(-8.5 if side == -1 else 10.0, -1.2, 0)
		var size := Vector3(17 if side == -1 else 13, 2.4, 33)
		var cliff := kit.box(bank, center, size, Color("546078"))
		cliff.material_override = kit.textured("stone", Color("8496b2"))
		var lawn := kit.box(
			bank, center + Vector3.UP * 1.15, Vector3(size.x, 0.15, 33), Color.WHITE
		)
		lawn.material_override = kit.textured("grass", Color("8ebfb4"))
		kit.collision(bank, center, size)
	# A real flowing river separates the two construction islands.
	var water := kit.box(self, Vector3(2, -0.38, 0), Vector3(4, 0.14, 33), Color("1b81bd"))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/kart_water.gdshader")
	water.material_override = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 93231
	for z in range(-16, 17, 2):
		for x in [-16.0, -12.0, -8.0, -4.0, 5.0, 9.0, 13.0]:
			kit.box(self, Vector3(x, 0.015, float(z)), Vector3(0.018, 0.025, 1.98), Color("6ab8ba"))
		for x in [-0.30, 4.32]:
			var rock := kit.mesh(self, kit.SHAPES.rock(), Vector3(x, -0.1, z), Color("74839e"))
			rock.scale = Vector3(0.5, 0.4, 0.7)
	for x in range(-16, 17, 2):
		if x in [0, 2]:
			continue
		kit.box(self, Vector3(float(x), 0.025, 0), Vector3(0.018, 0.012, 33), Color("609694"))
	for i in range(36):
		var at := Vector3(rng.randf_range(-16.5, 16.5), 0, -16.3 if i % 2 == 0 else 16.3)
		if at.x >= -0.5 and at.x < 4.5:
			continue
		var plant := kit.part_node(CATALOG.part("flowers" if i % 3 else "bush"))
		plant.position = at
		add_child(plant)
	for i in range(7):
		var at := Vector3(-35 + float(i) * 12, -7 + float(i % 3) * 3, -29 - float(i % 2) * 8)
		var rock := kit.mesh(self, preload("res://scripts/creative/floating_island.gd").create(), at, Color("68719d"))
		rock.material_override = kit.textured("stone", Color("7e8dac"))
		var lawn := kit.cylinder(self, at + Vector3.UP * 4.5, 5.1, 0.35, Color("65a99d"))
		lawn.material_override = kit.textured("grass", Color("80b8a9"))
		if i in [1, 3, 5]:
			kit.castle(self, at + Vector3.UP * 4.75, 0.7 if i != 3 else 1.0)
		else:
			var tree := kit.part_node(CATALOG.part("tree"))
			tree.position = at + Vector3(-1, 4.75, -1)
			add_child(tree)
		if i % 2 == 0:
			var fall := kit.part_node(CATALOG.part("waterfall"))
			fall.position = at + Vector3(3.6, -4, 0)
			fall.scale.y = 3
			add_child(fall)


func _resize() -> void:
	_camera_update()
	if is_instance_valid(safe_ui):
		RUNTIME.safe_area(self, safe_ui)


func _exit_tree() -> void:
	RUNTIME.restore(self, previous_runtime)


func _ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	safe_ui = root
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	root.add_child(margin)
	var hud := VBoxContainer.new()
	margin.add_child(hud)
	var top := HBoxContainer.new()
	hud.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	top.add_child(KIT.label("LUMO BAUWELT", 25))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	count_label = KIT.label("", 15)
	top.add_child(count_label)
	top.add_child(KIT.button("Ⅱ", func(): _pause(true), 52))
	var tools := HBoxContainer.new()
	hud.add_child(tools)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(scroll)
	var actions := HBoxContainer.new()
	scroll.add_child(actions)
	for spec in [
		["Drehen ↻", _rotate],
		["Entfernen", _toggle_erase],
		["Rückgängig", _undo],
		["Wiederholen", _redo],
		["Welten (6)", _slots],
		["Speichern", save_world],
		["Laden", load_world],
		["Vorlagen", _templates],
		["Bauziele", _goals]
	]:
		actions.add_child(KIT.button(spec[0], spec[1]))
	var layer_down: Button = KIT.button(
		"Ebene −",
		func():
			layer = maxi(0, layer - 1)
			_update_labels()
	)
	var layer_up: Button = KIT.button(
		"Ebene +",
		func():
			layer = mini(17, layer + 1)
			_update_labels()
	)
	actions.add_child(layer_down)
	actions.add_child(layer_up)
	var goal_panel := PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", KIT.panel())
	goal_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	goal_panel.position = Vector2(14, 126)
	goal_panel.custom_minimum_size = Vector2(282, 0)
	root.add_child(goal_panel)
	var goal_box := VBoxContainer.new()
	goal_panel.add_child(goal_box)
	goal_label = KIT.label("", 17)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size.x = 260
	goal_box.add_child(goal_label)
	goal_box.add_child(KIT.button("Mein Bauwerk testen", _test_challenge))
	var lower := VBoxContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_top = -162
	lower.offset_left = 12
	lower.offset_right = -12
	root.add_child(lower)
	status = KIT.label("Tippe zum Bauen. Ziehe zum Drehen der Kamera. Zwei Finger: zoomen.", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lower.add_child(status)
	var categories := HBoxContainer.new()
	lower.add_child(categories)
	for name in ["Bauen", "Dächer", "Wege", "Natur", "Deko"]:
		categories.add_child(
			KIT.button(
				name,
				func():
					category = name
					_palette(),
				64
			)
		)
	var parts_scroll := ScrollContainer.new()
	parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(parts_scroll)
	palette = HBoxContainer.new()
	parts_scroll.add_child(palette)
	_palette()
	var camera_tools := HBoxContainer.new()
	camera_tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	camera_tools.position = Vector2(-200, -228)
	root.add_child(camera_tools)
	camera_tools.add_child(
		KIT.button(
			"−",
			func():
				radius = clampf(radius + 3, 10, 55)
				_camera_update(),
			48
		)
	)
	camera_tools.add_child(
		KIT.button(
			"+",
			func():
				radius = clampf(radius - 3, 10, 55)
				_camera_update(),
			48
		)
	)
	camera_tools.add_child(
		KIT.button(
			"Mitte",
			func():
				focus = Vector3(-2, 0, 0)
				orbit = 0.62
				tilt = 0.68
				_camera_update(),
			48
		)
	)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", KIT.panel())
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-160, -140)
	pause_panel.custom_minimum_size = Vector2(320, 280)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	pause_box.add_child(KIT.label("Deine Welt wartet auf dich", 22))
	pause_box.add_child(KIT.button("Weiterbauen", func(): _pause(false)))
	pause_box.add_child(KIT.button("Speichern", save_world))
	pause_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _palette() -> void:
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	for item in CATALOG.PARTS:
		if item.category != category:
			continue
		var button: Button = KIT.button(
			str(item.name),
			func():
				chosen = item.id
				erase_mode = false
				_update_labels(),
			96
		)
		button.add_theme_color_override("font_color", item.color.lightened(0.25))
		button.tooltip_text = "%s · %d×%d×%d" % [item.name, item.size.x, item.size.y, item.size.z]
		palette.add_child(button)


func _rebuild() -> void:
	var active: Dictionary = {}
	for piece in model.pieces:
		var uid := int(piece.uid)
		active[uid] = true
		if placed_nodes.has(uid) and placed_nodes[uid].get_meta("piece") == piece:
			continue
		if placed_nodes.has(uid):
			world.remove_child(placed_nodes[uid])
			placed_nodes[uid].queue_free()
		var item: Dictionary = CATALOG.part(str(piece.part))
		var node: StaticBody3D = kit.part_node(item)
		var turns := int(piece.turn)
		var size: Vector3 = item.size
		var offset: Vector3 = [
			Vector3.ZERO, Vector3(0, 0, size.x), Vector3(size.x, 0, size.z), Vector3(size.z, 0, 0)
		][posmod(turns, 4)]
		node.position = Vector3(piece.x, piece.y, piece.z) + offset
		node.rotation.y = turns * PI * 0.5
		node.set_meta("uid", uid)
		node.set_meta("piece", piece.duplicate())
		world.add_child(node)
		placed_nodes[uid] = node
	for uid in placed_nodes.keys():
		if not active.has(uid):
			world.remove_child(placed_nodes[uid])
			placed_nodes[uid].queue_free()
			placed_nodes.erase(uid)
	_update_labels()


func _camera_update() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	camera.position = (
		focus + Vector3(sin(orbit) * cos(tilt), sin(tilt), cos(orbit) * cos(tilt)) * radius
	)
	camera.look_at(focus + Vector3.UP * 1.2)


func _ray(at: Vector2) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(at) * 150
	)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _preview_at(at: Vector2) -> Vector3i:
	var hit: Dictionary = _ray(at)
	var target: Vector3
	if not hit.is_empty():
		target = hit.position + hit.normal * 0.04
	else:
		var origin: Vector3 = camera.project_ray_origin(at)
		var direction: Vector3 = camera.project_ray_normal(at)
		if absf(direction.y) < 0.001:
			return Vector3i(50, 0, 50)
		target = origin + direction * ((float(layer) - origin.y) / direction.y)
	var cell := Vector3i(floori(target.x), layer, floori(target.z))
	var size: Vector3 = CATALOG.size_of(chosen, turn)
	preview.position = Vector3(cell) + size * 0.5
	preview.mesh.size = size * 1.02
	preview.material_override = kit.material(
		(
			Color("6fe3ff")
			if model.placement_error(chosen, cell, turn).is_empty()
			else Color("e8ab95")
		),
		true,
		true
	)
	return cell


func _tap(at: Vector2) -> void:
	if paused:
		return
	if erase_mode:
		var hit: Dictionary = _ray(at)
		if not hit.is_empty() and hit.collider.has_meta("uid"):
			if model.remove(int(hit.collider.get_meta("uid"))):
				_rebuild()
				dirty = true
			else:
				status.text = "Entferne zuerst die Bauteile darüber, damit nichts schwebt."
		return
	var cell: Vector3i = _preview_at(at)
	var problem: String = model.place(chosen, cell, turn)
	status.text = (
		"%s platziert. Deine Welt wächst!" % CATALOG.part(chosen).name
		if problem.is_empty()
		else problem
	)
	if problem.is_empty():
		dirty = true
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause(not paused)
		return
	if paused:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			radius = clampf(
				radius + (-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2), 10, 55
			)
			_camera_update()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				tap_start = event.position
				dragged = false
				pointer_id = 0
				_preview_at(event.position)
			else:
				if pointer_id == 0 and not dragged:
					_tap(event.position)
				pointer_id = -1
	elif event is InputEventMouseMotion:
		if pointer_id == 0:
			dragged = dragged or event.position.distance_to(tap_start) > 10
			if dragged:
				if event.shift_pressed:
					focus += (
						camera.basis.x * (-event.relative.x * 0.035)
						+ (
							Vector3(camera.basis.z.x, 0, camera.basis.z.z)
							* (-event.relative.y * 0.035)
						)
					)
				else:
					orbit -= event.relative.x * 0.007
					tilt = clampf(tilt + event.relative.y * 0.005, 0.25, 1.2)
				_camera_update()
		else:
			_preview_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1 and not touch_gesture:
				pointer_id = event.index
				tap_start = event.position
				dragged = false
			else:
				touch_gesture = true
				dragged = true
		else:
			if pointer_id == event.index and not dragged and not touch_gesture:
				_tap(event.position)
			touches.erase(event.index)
			if touches.is_empty():
				touch_gesture = false
				pointer_id = -1
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() >= 2:
			var keys := touches.keys()
			var a: Vector2 = touches[keys[0]]
			var b: Vector2 = touches[keys[1]]
			var before := maxf(1, a.distance_to(b))
			var old_center := (a + b) * 0.5
			touches[event.index] = event.position
			a = touches[keys[0]]
			b = touches[keys[1]]
			radius = clampf(radius * before / maxf(1, a.distance_to(b)), 10, 55)
			var motion := (a + b) * 0.5 - old_center
			focus += (
				camera.basis.x * (-motion.x * radius / 650.0)
				+ Vector3(camera.basis.z.x, 0, camera.basis.z.z) * (-motion.y * radius / 650.0)
			)
		else:
			touches[event.index] = event.position
			dragged = dragged or event.position.distance_to(tap_start) > 10
			if dragged and not touch_gesture:
				orbit -= event.relative.x * 0.007
				tilt = clampf(tilt + event.relative.y * 0.005, 0.25, 1.2)
		focus.x = clampf(focus.x, -20, 20)
		focus.z = clampf(focus.z, -20, 20)
		_camera_update()
	elif event is InputEventMagnifyGesture:
		radius = clampf(radius / event.factor, 10, 55)
		_camera_update()
	elif event is InputEventPanGesture:
		focus += (
			camera.basis.x * event.delta.x * 0.1
			+ Vector3(camera.basis.z.x, 0, camera.basis.z.z) * event.delta.y * 0.1
		)
		_camera_update()


func _process(delta: float) -> void:
	if paused:
		return
	autosave += delta
	if dirty and autosave >= 3:
		autosave = 0
		save_world(false)
	if not guide_path.is_empty():
		guide_time += delta * 1.3
		var index: int = mini(int(guide_time), guide_path.size() - 1)
		var next: int = mini(index + 1, guide_path.size() - 1)
		guide.position = (
			Vector3(guide_path[index]).lerp(Vector3(guide_path[next]), fmod(guide_time, 1.0))
			+ Vector3(0.5, 1.6, 0.5)
		)
		guide.rotate_y(delta)
		if guide_time > guide_path.size() + 1:
			guide.visible = false
			guide_path.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(status):
			save_world(false)
			_pause(true)


func _rotate() -> void:
	turn = posmod(turn + 1, 4)
	_update_labels()


func _toggle_erase() -> void:
	erase_mode = not erase_mode
	status.text = (
		"Tippe auf das Bauteil, das du entfernen möchtest."
		if erase_mode
		else "Tippe auf einen freien Platz zum Bauen."
	)


func _undo() -> void:
	if model.undo():
		dirty = true
		_rebuild()


func _redo() -> void:
	if model.redo():
		dirty = true
		_rebuild()


func _update_labels() -> void:
	if not is_instance_valid(count_label):
		return
	count_label.text = (
		"Welt %d · %d Teile · Ebene %d · %d°" % [slot, model.pieces.size(), layer, turn * 90]
	)
	var texts: Dictionary = {
		"bridge": "Verbinde die Inseln\nBaue einen durchgehenden Weg über den Fluss.",
		"house": "Ein Zuhause für Lumo\nBaue Wände, eine Haustür und ein getragenes Dach.",
		"tower": "Turm der Sterne\nEine Laterne auf einem tragenden Turm: mindestens 5 Ebenen.",
		"garden": "Ein Garten zum Verweilen\nBaum, Blumen, Bank und Laterne gehören zusammen.",
		"castle":
		"Das große Sternenschloss\nBaue vier Türme mit Dächern und ein bewohnbares Haus im Hof.",
		"village": "Ein Dorf für Freunde\nDrei Häuser, ein Garten und eine Brücke gehören zusammen."
	}
	goal_label.text = (
		str(texts[goal]) + ("\n✓ Schon geschafft" if model.completed.has(goal) else "")
	)


func _pause(value: bool) -> void:
	paused = value
	pause_panel.visible = value
	pointer_id = -1
	touches.clear()
	touch_gesture = false
	if value:
		save_world(false)


func save_world(show_message: bool = true) -> bool:
	var data: Dictionary = model.to_data()
	data["goal"] = goal
	data["camera"] = {
		"orbit": orbit, "tilt": tilt, "radius": radius, "focus": [focus.x, focus.y, focus.z]
	}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		status.text = "Deine Welt konnte noch nicht gespeichert werden. Versuche es bitte erneut."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		status.text = "Speichern fehlgeschlagen. Deine Welt bleibt geöffnet."
		return false
	dirty = false
	if show_message:
		status.text = "Deine Welt ist gespeichert – du kannst jederzeit weiterbauen."
	return true


func load_world(show_message: bool = true) -> bool:
	if not FileAccess.file_exists(save_path):
		if show_message:
			status.text = "In diesem Platz ist noch keine Welt gespeichert."
		return false
	var raw = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not raw is Dictionary or not model.restore(raw):
		if show_message:
			status.text = "Dieser Spielstand ist beschädigt. Deine offene Welt bleibt erhalten."
		return false
	goal = str(raw.get("goal", "bridge"))
	if goal not in ["house", "bridge", "tower", "garden", "castle", "village"]:
		goal = "bridge"
	if raw.get("camera") is Dictionary:
		orbit = float(raw.camera.get("orbit", 0.62))
		tilt = clampf(float(raw.camera.get("tilt", 0.68)), 0.25, 1.2)
		radius = clampf(float(raw.camera.get("radius", 29)), 10, 55)
		var saved_focus = raw.camera.get("focus", [])
		if saved_focus is Array and saved_focus.size() == 3:
			focus = Vector3(
				clampf(float(saved_focus[0]), -20, 20),
				clampf(float(saved_focus[1]), 0, 19),
				clampf(float(saved_focus[2]), -20, 20)
			)
	_rebuild()
	_camera_update()
	if show_message:
		status.text = "Willkommen zurück! Hier wartet dein Bauwerk."
	return true


func _choice_dialog(title: String, items: Array, action: Callable) -> void:
	var dialog := Window.new()
	dialog.title = title
	dialog.size = Vector2i(390, 500)
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", KIT.panel())
	dialog.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(KIT.label(title, 23))
	for item in items:
		box.add_child(KIT.button(item[1], _choose.bind(action, item[0], dialog)))
	box.add_child(KIT.button("Abbrechen", dialog.queue_free))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()


func _slots() -> void:
	var items: Array = []
	for i in range(1, 7):
		var path := "user://lumo_build_" + child_key + "_" + str(i) + ".json"
		items.append(
			[
				i,
				(
					"Welt %d · %s"
					% [i, "weiterbauen" if FileAccess.file_exists(path) else "neue Insel"]
				)
			]
		)
	_choice_dialog("Deine sechs Welten", items, _open_slot)


func _choose(action: Callable, id: Variant, dialog: Window) -> void:
	action.call(id)
	dialog.queue_free()


func _open_slot(id: int) -> void:
	if not save_world(false):
		return
	slot = id
	save_path = "user://lumo_build_" + child_key + "_" + str(slot) + ".json"
	if not load_world(false):
		model = STATE.new()
		goal = "bridge"
		focus = Vector3(-2, 0, 0)
		dirty = true
		_rebuild()
		_camera_update()
	status.text = "Welt %d ist geöffnet. Hier kannst du deine eigene Idee bauen." % slot
	_update_labels()


func _templates() -> void:
	_choice_dialog(
		"Neue Welt / Vorlage",
		[
			["castle", "Großes Sternenschloss"],
			["village", "Dorf für Freunde"],
			["house", "Starter-Haus"],
			["bridge", "Brücke"],
			["tower", "Sternenturm"],
			["garden", "Garten"],
			["empty", "Leere Insel"]
		],
		_select_template
	)


func _select_template(id: String) -> void:
	model.template(id)
	dirty = true
	_rebuild()
	status.text = "Vorlage geöffnet. Rückgängig bringt deine vorherige Welt zurück."


func _goals() -> void:
	_choice_dialog(
		"Dein nächstes Bauziel",
		[
			["house", "Ein Zuhause bauen"],
			["bridge", "Die Inseln verbinden"],
			["tower", "Turm der Sterne"],
			["garden", "Ein Garten zum Verweilen"],
			["castle", "Großes Sternenschloss"],
			["village", "Dorf für Freunde"]
		],
		_select_goal
	)


func _select_goal(id: String) -> void:
	goal = id
	dirty = true
	_update_labels()


func _test_challenge() -> void:
	if not model.challenge_passes(goal):
		status.text = "Noch fehlt etwas. Prüfe dein Bauziel – Lumo glaubt an deine Idee!"
		return
	if goal == "bridge":
		guide_path = model.bridge_path()
		guide_time = 0
		guide.visible = true
	if not model.completed.has(goal):
		model.completed.append(goal)
		if not save_world(false):
			model.completed.erase(goal)
			return
		if HostBridge.is_embedded():
			var result: Dictionary = {
				"resultId": "build-" + child_key + "-" + goal,
				"game": "build",
				"status": "completed",
				"stars": 3,
				"xp": 24,
				"solved": 1,
				"grade": int(SceneRouter.launch_options.get("grade", 1)),
				"subject": "Logik"
			}
			if not HostBridge.reward(result):
				status.text = "Bauziel geschafft! Deine Sterne warten noch auf die Speicherbestätigung."
				_update_labels()
				return
	status.text = "Bauziel geschafft! Dein Bauwerk funktioniert."
	_update_labels()


func _leave() -> void:
	if save_world(false):
		SceneRouter.goto("games")
