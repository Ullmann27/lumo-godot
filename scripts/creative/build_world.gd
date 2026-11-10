extends Node3D
## Touch-first, actual 3D construction. No prerendered screenshot substitutes the world.
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const STATE = preload("res://scripts/creative/build_state.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const SANDBOX = preload("res://scripts/creative/build_sandbox_tools.gd")
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
# Start overview: pulled back past the expanded rim and canyon so Werkstatt,
# Sternwarte, castle and waterfall still share one frame (Tafel 03 framing).
const START_ORBIT: float = 0.48
const START_TILT: float = 0.48
const START_RADIUS: float = 44.0
const START_FOCUS := Vector3(0.6, 0.8, 4.0)
const RADIUS_MIN: float = 10.0
const RADIUS_MAX: float = 72.0
const FOCUS_LIMIT: float = 32.0
var orbit: float = START_ORBIT
var tilt: float = START_TILT
var radius: float = START_RADIUS
var focus := START_FOCUS
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
var sandbox_mode: String = ""
var sandbox_points: Array[Vector3i] = []
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
	kit.environment(self, "bauwelt_day")
	_ground()
	world = Node3D.new()
	world.name = "Construction"
	add_child(world)
	camera = Camera3D.new()
	camera.fov = 54
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
		# Visible 2013 landmarks on the free right bank and river (off the castle).
		model.place("cottage", Vector3i(7, 0, 5))
		model.place("observatory", Vector3i(9, 0, -2))
		model.place("tree", Vector3i(11, 0, 4))
		model.place("tree", Vector3i(5, 0, 8))
		model.place("bridge", Vector3i(-1, 0, 6))
		model.place("bridge", Vector3i(2, 0, 6))
		model.place("magic", Vector3i(5, 0, 5))
		model.place("lantern", Vector3i(6, 0, 4))
		# Ready-to-use plots on the new land and river islands (kids can keep building).
		model.add_starter_plot("garden", false)
		model.add_starter_plot("harbor", false)
		model.add_starter_plot("island", false)
	_rebuild()
	_camera_update()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_update_labels()
	print("[Bauwelt] ready: real geometry, ", CATALOG.PARTS.size(), " parts, save=", save_path)


func _ground() -> void:
	# Collision stays a flat island so placed blocks do not float; visuals are dressed separately.
	# Footprint matches build_state.HALF (24): banks x=-24.5..0 and 4..24.5, z=-24.5..24.5.
	var half := float(STATE.HALF) + 0.5
	for side in [-1, 1]:
		var bank := StaticBody3D.new()
		bank.name = "RiverBank"
		add_child(bank)
		var width := half if side == -1 else half - 4.0
		var center := Vector3((-width * 0.5) if side == -1 else (4.0 + width * 0.5), -1.2, 0)
		var size := Vector3(width, 2.4, half * 2.0)
		kit.collision(bank, center, size)
	var water := kit.box(self, Vector3(2, -0.38, 0), Vector3(4, 0.14, half * 2.0), Color("1b81bd"))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/kart_water.gdshader")
	water.material_override = mat
	# Buildable river islands (tops at y=0, same support rule as the main banks).
	for island_z in [-12.5, 19.5]:
		var isle := StaticBody3D.new()
		isle.name = "RiverIsland"
		add_child(isle)
		kit.collision(isle, Vector3(2.0, -1.2, island_z), Vector3(4.0, 2.4, 4.0))
	BuildLandmarks.dress_world(self, kit)


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
	top.add_child(_day_button("‹ Spiele", _leave))
	top.add_child(_day_label("LUMO BAUWELT", 25))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	count_label = _day_label("", 15)
	top.add_child(count_label)
	top.add_child(_day_button("Ⅱ", func(): _pause(true), 52))
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
		["Füllen", _set_sandbox_mode.bind("fill")],
		["Kopieren", _set_sandbox_mode.bind("copy")],
		["Spiegel X", _set_sandbox_mode.bind("mirror_x")],
		["Spiegel Z", _set_sandbox_mode.bind("mirror_z")],
		["Welten (6)", _slots],
		["Speichern", save_world],
		["Laden", load_world],
		["Vorlagen", _templates],
		["Bauziele", _goals]
	]:
		actions.add_child(_day_button(spec[0], spec[1]))
	var layer_down: Button = _day_button(
		"Ebene −",
		func():
			layer = maxi(0, layer - 1)
			_update_labels()
	)
	var layer_up: Button = _day_button(
		"Ebene +",
		func():
			layer = mini(17, layer + 1)
			_update_labels()
	)
	actions.add_child(layer_down)
	actions.add_child(layer_up)
	var goal_panel := PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", _day_panel())
	goal_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	goal_panel.position = Vector2(14, 126)
	goal_panel.custom_minimum_size = Vector2(282, 0)
	root.add_child(goal_panel)
	var goal_box := VBoxContainer.new()
	goal_panel.add_child(goal_box)
	goal_label = _day_label("", 17)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size.x = 260
	goal_box.add_child(goal_label)
	goal_box.add_child(_day_button("Mein Bauwerk testen", _test_challenge))
	var lower := VBoxContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_top = -162
	lower.offset_left = 12
	lower.offset_right = -12
	root.add_child(lower)
	status = _day_label("Tippe zum Bauen. Ziehe zum Drehen der Kamera. Zwei Finger: zoomen.", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lower.add_child(status)
	var categories := HBoxContainer.new()
	lower.add_child(categories)
	for name in ["Bauen", "Dächer", "Wege", "Natur", "Deko"]:
		categories.add_child(
			_day_button(
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
		_day_button(
			"−",
			func():
				radius = clampf(radius + 3, RADIUS_MIN, RADIUS_MAX)
				_camera_update(),
			48
		)
	)
	camera_tools.add_child(
		_day_button(
			"+",
			func():
				radius = clampf(radius - 3, RADIUS_MIN, RADIUS_MAX)
				_camera_update(),
			48
		)
	)
	camera_tools.add_child(
		_day_button(
			"Mitte",
			func():
				focus = START_FOCUS
				orbit = START_ORBIT
				tilt = START_TILT
				radius = START_RADIUS
				_camera_update(),
			48
		)
	)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _day_panel())
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-160, -140)
	pause_panel.custom_minimum_size = Vector2(320, 280)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	pause_box.add_child(_day_label("Deine Welt wartet auf dich", 22))
	pause_box.add_child(_day_button("Weiterbauen", func(): _pause(false)))
	pause_box.add_child(_day_button("Speichern", save_world))
	pause_box.add_child(_day_button("Zur Spielewelt", _leave))


func _palette() -> void:
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	for item in CATALOG.PARTS:
		if item.category != category:
			continue
		var button: Button = _day_button(
			str(item.name),
			func():
				chosen = item.id
				erase_mode = false
				_update_labels(),
			96
		)
		button.add_theme_color_override("font_color", item.color.darkened(0.35))
		button.tooltip_text = "%s · %d×%d×%d" % [item.name, item.size.x, item.size.y, item.size.z]
		palette.add_child(button)


func _rebuild() -> void:
	var active: Dictionary = {}
	var batches: Dictionary = {}
	for piece in model.pieces:
		var uid := int(piece.uid)
		active[uid] = true
		var item: Dictionary = CATALOG.part(str(piece.part))
		if BuildVoxelStyle.is_batchable(item):
			if placed_nodes.has(uid) and placed_nodes[uid].get_meta("piece") != piece:
				world.remove_child(placed_nodes[uid])
				placed_nodes[uid].queue_free()
				placed_nodes.erase(uid)
			if not placed_nodes.has(uid):
				var node: StaticBody3D = BuildVoxelStyle.collision_body(kit, item)
				var piece_xform: Transform3D = BuildVoxelStyle.piece_transform(piece, item)
				node.position = piece_xform.origin
				node.rotation.y = int(piece.turn) * PI * 0.5
				node.set_meta("uid", uid)
				node.set_meta("piece", piece.duplicate())
				world.add_child(node)
				placed_nodes[uid] = node
			if not batches.has(item.id):
				batches[item.id] = []
			batches[item.id].append({"piece": piece, "item": item})
			continue
		if placed_nodes.has(uid) and placed_nodes[uid].get_meta("piece") == piece:
			continue
		if placed_nodes.has(uid):
			world.remove_child(placed_nodes[uid])
			placed_nodes[uid].queue_free()
		var unique: StaticBody3D = kit.part_node(item)
		var turns := int(piece.turn)
		var size: Vector3 = item.size
		var offset: Vector3 = [
			Vector3.ZERO, Vector3(0, 0, size.x), Vector3(size.x, 0, size.z), Vector3(size.z, 0, 0)
		][posmod(turns, 4)]
		unique.position = Vector3(piece.x, piece.y, piece.z) + offset
		unique.rotation.y = turns * PI * 0.5
		unique.set_meta("uid", uid)
		unique.set_meta("piece", piece.duplicate())
		world.add_child(unique)
		placed_nodes[uid] = unique
	for uid in placed_nodes.keys():
		if not active.has(uid):
			world.remove_child(placed_nodes[uid])
			placed_nodes[uid].queue_free()
			placed_nodes.erase(uid)
	_sync_batched_visuals(batches)
	_update_labels()


func _typed_xforms(raw: Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for item in raw:
		result.append(item)
	return result


func _sync_batched_visuals(batches: Dictionary) -> void:
	var wall_xforms: Array = []
	var pane_xforms: Array = []
	var planter_xforms: Array = []
	var grass_body_xforms: Array = []
	var grass_cap_xforms: Array = []
	for ident in BuildVoxelStyle.BATCHABLE:
		var entries: Array = batches.get(ident, [])
		if ident == "wall":
			for entry in entries:
				var px: Transform3D = BuildVoxelStyle.piece_transform(entry.piece, entry.item)
				wall_xforms.append(px)
				pane_xforms.append(Transform3D(px.basis, px.origin + px.basis * Vector3(0.5, 1.18, 1.02)))
				planter_xforms.append(Transform3D(px.basis, px.origin + px.basis * Vector3(0.5, 0.82, 1.16)))
			continue
		if ident == "grass":
			for entry in entries:
				var px: Transform3D = BuildVoxelStyle.piece_transform(entry.piece, entry.item)
				grass_body_xforms.append(Transform3D(px.basis, px.origin + px.basis * Vector3(0.5, 0.4, 0.5)))
				grass_cap_xforms.append(Transform3D(px.basis, px.origin + px.basis * Vector3(0.5, 0.91, 0.5)))
			continue
		var xforms: Array = []
		var sample: Dictionary = CATALOG.part(ident)
		for entry in entries:
			xforms.append(
				BuildVoxelStyle.box_instance_transform(
					BuildVoxelStyle.piece_transform(entry.piece, entry.item), entry.item
				)
			)
		BuildVoxelStyle.multimesh(
			world,
			"Batch_%s" % ident,
			BuildVoxelStyle.unit_box(),
			BuildVoxelStyle.material(BuildVoxelStyle.kind_for(sample), BuildVoxelStyle.tint_for(sample)),
			_typed_xforms(xforms)
		)
	BuildVoxelStyle.multimesh(
		world,
		"Batch_wall",
		BuildVoxelStyle.wall_mesh(),
		BuildVoxelStyle.material("sand", Color("d9a86c")),
		_typed_xforms(wall_xforms)
	)
	BuildVoxelStyle.multimesh(
		world,
		"Batch_wall_glass",
		BuildVoxelStyle.window_pane(),
		BuildVoxelStyle.material("glass", Color("9ae8ff")),
		_typed_xforms(pane_xforms)
	)
	BuildVoxelStyle.multimesh(
		world,
		"Batch_wall_planters",
		BuildLandmarks.planter_mesh(),
		BuildVoxelStyle.material("leaves", Color("7ec85a")),
		_typed_xforms(planter_xforms)
	)
	BuildVoxelStyle.multimesh(
		world,
		"Batch_grass_body",
		BuildVoxelStyle.grass_body(),
		BuildVoxelStyle.material("dirt", Color("c4a078")),
		_typed_xforms(grass_body_xforms)
	)
	BuildVoxelStyle.multimesh(
		world,
		"Batch_grass_cap",
		BuildVoxelStyle.grass_cap(),
		BuildVoxelStyle.material("grass_top", Color.WHITE),
		_typed_xforms(grass_cap_xforms)
	)


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
	if not sandbox_mode.is_empty():
		_sandbox_tap(_preview_at(at))
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
		_place_feedback(cell)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause(not paused)
		return
	if paused:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			radius = clampf(
				radius + (-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2), RADIUS_MIN, RADIUS_MAX
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
				_clamp_focus()
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
			radius = clampf(radius * before / maxf(1, a.distance_to(b)), RADIUS_MIN, RADIUS_MAX)
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
		_clamp_focus()
		_camera_update()
	elif event is InputEventMagnifyGesture:
		radius = clampf(radius / event.factor, RADIUS_MIN, RADIUS_MAX)
		_camera_update()
	elif event is InputEventPanGesture:
		focus += (
			camera.basis.x * event.delta.x * 0.1
			+ Vector3(camera.basis.z.x, 0, camera.basis.z.z) * event.delta.y * 0.1
		)
		_clamp_focus()
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


func _set_sandbox_mode(mode: String) -> void:
	sandbox_mode = "" if sandbox_mode == mode else mode
	sandbox_points.clear()
	erase_mode = false
	if sandbox_mode.is_empty():
		status.text = "Werkzeug beendet. Tippe auf einen freien Platz zum Bauen."
	elif sandbox_mode == "fill":
		status.text = "Füllen: Tippe die erste und die gegenüberliegende Ecke."
	else:
		status.text = (
			"Kopieren: Wähle zwei Ecken und danach den Zielpunkt."
			if sandbox_mode == "copy"
			else "Spiegeln: Wähle zwei Ecken und danach den Zielpunkt."
		)


func _sandbox_tap(cell: Vector3i) -> void:
	if STATE.out_of_world(cell):
		status.text = "Dieser Punkt liegt außerhalb deiner Bauwelt."
		return
	sandbox_points.append(cell)
	if sandbox_mode == "fill" and sandbox_points.size() < 2:
		status.text = "Füllen: Jetzt die gegenüberliegende Ecke wählen."
		return
	if sandbox_mode != "fill" and sandbox_points.size() < 2:
		status.text = "Bereich gewählt: Jetzt die zweite Ecke wählen."
		return
	if sandbox_mode != "fill" and sandbox_points.size() < 3:
		status.text = "Bereich gewählt: Jetzt den Zielpunkt für die Kopie wählen."
		return

	var result: Dictionary
	if sandbox_mode == "fill":
		result = SANDBOX.fill_rect(model, chosen, sandbox_points[0], sandbox_points[1], turn)
	else:
		var source_low := Vector3i(
			mini(sandbox_points[0].x, sandbox_points[1].x),
			mini(sandbox_points[0].y, sandbox_points[1].y),
			mini(sandbox_points[0].z, sandbox_points[1].z)
		)
		var offset: Vector3i = sandbox_points[2] - source_low
		if sandbox_mode == "copy":
			result = SANDBOX.copy_region(
				model, sandbox_points[0], sandbox_points[1], offset
			)
		else:
			result = SANDBOX.mirror_copy_region(
				model,
				sandbox_points[0],
				sandbox_points[1],
				"x" if sandbox_mode == "mirror_x" else "z",
				offset
			)
	sandbox_points.clear()
	if bool(result.get("ok", false)):
		dirty = true
		_rebuild()
		_update_labels()
		status.text = "%d Teile mit %s erstellt. Rückgängig macht alles auf einmal." % [
			int(result.get("count", 0)),
			(
				"Füllen"
				if sandbox_mode == "fill"
				else ("Kopieren" if sandbox_mode == "copy" else "Spiegeln")
			),
		]
	else:
		status.text = str(result.get("error", "Die Werkzeugaktion konnte nicht ausgeführt werden."))


func _rotate() -> void:
	turn = posmod(turn + 1, 4)
	_update_labels()


func _toggle_erase() -> void:
	erase_mode = not erase_mode
	if erase_mode:
		sandbox_mode = ""
		sandbox_points.clear()
	status.text = (
		"Tippe auf das Bauteil, das du entfernen möchtest."
		if erase_mode
		else "Tippe auf einen freien Platz zum Bauen."
	)


func _undo() -> void:
	sandbox_points.clear()
	if model.undo():
		dirty = true
		_rebuild()


func _redo() -> void:
	sandbox_points.clear()
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
		radius = clampf(float(raw.camera.get("radius", 29)), RADIUS_MIN, RADIUS_MAX)
		var saved_focus = raw.camera.get("focus", [])
		if saved_focus is Array and saved_focus.size() == 3:
			focus = Vector3(
				clampf(float(saved_focus[0]), -FOCUS_LIMIT, FOCUS_LIMIT),
				clampf(float(saved_focus[1]), 0, 19),
				clampf(float(saved_focus[2]), -FOCUS_LIMIT, FOCUS_LIMIT)
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
	panel.add_theme_stylebox_override("panel", _day_panel())
	dialog.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_day_label(title, 23))
	for item in items:
		box.add_child(_day_button(item[1], _choose.bind(action, item[0], dialog)))
	box.add_child(_day_button("Abbrechen", dialog.queue_free))
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
		focus = START_FOCUS
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
			["plot_garden", "Garten-Parzelle"],
			["plot_harbor", "Hafen-Parzelle"],
			["plot_island", "Insel-Parzelle"],
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

func _day_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.84, 0.92)
	style.border_color = Color("2f8a96")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0.12, 0.18, 0.16, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 1)
	return style


func _day_button(text: String, callback: Callable, min_width: float = 82) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(min_width, 48)
	control.add_theme_stylebox_override("normal", _day_panel())
	var hover: StyleBoxFlat = _day_panel()
	hover.bg_color = Color("d7efe8")
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", hover)
	control.add_theme_font_size_override("font_size", 16)
	control.add_theme_color_override("font_color", Color("243038"))
	control.add_theme_color_override("font_hover_color", Color("1a3c42"))
	control.pressed.connect(callback)
	return control


func _day_label(text: String, size: int = 18) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", Color("243038"))
	control.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 1)
	return control


func _clamp_focus() -> void:
	focus.x = clampf(focus.x, -FOCUS_LIMIT, FOCUS_LIMIT)
	focus.z = clampf(focus.z, -FOCUS_LIMIT, FOCUS_LIMIT)


func _place_feedback(cell: Vector3i) -> void:
	## Small sparkle + chime after a successful place. Does not change save or grid logic.
	var item: Dictionary = CATALOG.part(chosen)
	var size: Vector3 = item.size if not item.is_empty() else Vector3.ONE
	var at := Vector3(cell) + Vector3(size.x, size.y, size.z) * Vector3(0.5, 0.55, 0.5)
	var spark := CPUParticles3D.new()
	spark.name = "PlaceSparkle"
	spark.one_shot = true
	spark.explosiveness = 0.9
	spark.lifetime = 0.45
	spark.amount = 8 if LumoQuality.tier() == "low" else 16
	spark.emitting = false
	spark.direction = Vector3.UP
	spark.spread = 70.0
	spark.initial_velocity_min = 1.2
	spark.initial_velocity_max = 3.0
	spark.gravity = Vector3(0, -5, 0)
	spark.scale_amount_min = 0.05
	spark.scale_amount_max = 0.12
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 6
	puff.rings = 3
	spark.mesh = puff
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("fff3a8")
	mat.emission_enabled = true
	mat.emission = Color("7ad8ff")
	mat.emission_energy_multiplier = 1.4
	spark.material_override = mat
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.position = at
	add_child(spark)
	spark.emitting = true
	var chime := AudioStreamPlayer.new()
	chime.stream = _place_tone()
	chime.volume_db = -10.0
	add_child(chime)
	chime.play()
	get_tree().create_timer(0.7).timeout.connect(
		func():
			if is_instance_valid(spark):
				spark.queue_free()
			if is_instance_valid(chime):
				chime.queue_free()
	)


func _place_tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var frames := 2205
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var tm := float(i) / 22050.0
		var env := 1.0 - tm / 0.1
		var sample := (sin(TAU * 880.0 * tm) * 0.22 + sin(TAU * 1320.0 * tm) * 0.10) * env
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 255
		data[i * 2 + 1] = (value >> 8) & 255
	stream.data = data
	return stream
