extends Node3D
## The production Android route for the current Flutter lesson. Objects use
## real meshes and spatial picking; tap is the equivalent accessible action.

const ACTIVITY = preload("res://scripts/learning/learning_activity.gd")
const FOX = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const PART_LABELS := {"root": "Wurzel", "stem": "Stängel", "leaf": "Blatt", "flower": "Blüte"}
const PART_HELP := {
	"root": "Die Wurzel hält die Pflanze fest. Sie nimmt Wasser aus dem Boden auf.",
	"stem": "Der Stängel trägt die Blätter und die Blüte. Durch ihn gelangt Wasser nach oben.",
	"leaf": "Die Blätter nutzen Licht, Wasser und Luft, um Nahrung für die Pflanze herzustellen.",
	"flower": "Die Blüte ist für die Fortpflanzung wichtig. Aus vielen Blüten entstehen Früchte mit Samen.",
}

var activity = ACTIVITY.new()
var camera: Camera3D
var fox: Node3D
var tokens: Array[Node3D] = []
var targets: Array[Vector3] = []
var token_sources: Array[Vector3] = []
var content: Node3D
var plant: Node3D
var part_nodes: Dictionary = {}
var water_particles: Array[MeshInstance3D] = []
var sun: MeshInstance3D
var title: Label
var explanation: Label
var status: Label
var actions: HFlowContainer
var main_button: Button
var sun_button: Button
var water_button: Button
var header: PanelContainer
var footer: PanelContainer
var ui: Control
var capture_options: Dictionary = {}
var reduced_motion := false
var active_drag := -1
var drag_finger := -1
var drag_start := Vector2.ZERO
var drag_moved := false
var suspended := false
var _clock := 0.0
var _growth := 0.62
var _moving: Dictionary = {}
var _tweens: Array[Tween] = []
var _original_auto_quit := true
var _original_back_quit := true
var _original_scale_mode: Window.ContentScaleMode
var _materials: Dictionary = {}
var _layout_queued := false
var _speech_host: Object
var _speech_enabled := false
var _auto_read := false
var _speech_id := 0
var _speech_poll := 0.0
var _speech_wait := -1.0
var _speech_state := "idle"
var _speech_text := ""
var voice_button: Button


func _ready() -> void:
	_original_auto_quit = get_tree().auto_accept_quit
	_original_back_quit = get_tree().quit_on_go_back
	_original_scale_mode = get_window().content_scale_mode
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var options: Dictionary = capture_options if not capture_options.is_empty() else SceneRouter.launch_options
	reduced_motion = bool(options.get("reduceAnimations", false))
	_speech_enabled = options.get("learningVoiceEnabled", false) == true and options.get("localVoiceLicenseAccepted", false) == true
	_auto_read = options.get("learningAutoRead", false) == true
	if Engine.has_singleton("LumoHost"):
		_speech_host = Engine.get_singleton("LumoHost")
	var raw: Variant = options.get("learning", {})
	if not raw is Dictionary:
		raw = {}
	activity.configure(raw)
	_build_stage()
	_build_ui()
	_rebuild_activity()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()
	_teacher("welcome", Vector3(0, 1, 1.5))
	_queue_narration()


func _material(key: String, color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.38 if metallic > 0.0 else 0.66
	material.metallic = metallic
	_materials[key] = material
	return material


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material, label: String = "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	if not label.is_empty():
		node.name = label
	parent.add_child(node)
	return node


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, label: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material, label)


func _sphere(parent: Node3D, at: Vector3, scale_value: Vector3, material: Material, label: String = "") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := _mesh(parent, mesh, at, material, label)
	node.scale = scale_value
	return node


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, label: String = "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, mesh, at, material, label)


func _text(parent: Node3D, words: String, at: Vector3, size_value: float, material: Material) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.font = ThemeDB.fallback_font
	mesh.text = words
	mesh.font_size = 80
	mesh.pixel_size = size_value / 80.0
	mesh.depth = 0.045
	return _mesh(parent, mesh, at, material)


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101e36")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b1d8ee")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -30, 0)
	key.light_color = Color("fff2d1")
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 5, 4)
	fill.omni_range = 14
	fill.light_color = Color("65b9f2")
	fill.light_energy = 2.1
	add_child(fill)
	_cylinder(self, Vector3(0, -0.4, 0), 7.8, 0.6,
		_material("stage", Color("1b4c65"), 0.22), "LearningPodium")
	_cylinder(self, Vector3(0, -0.13, 0), 7.6, 0.13,
		_material("stage_top", Color("3e7e88")), "PodiumSurface")
	for side in [-1, 1]:
		for i in range(3):
			var x := float(side) * (5.4 + float(i) * 0.45)
			_box(self, Vector3(x, 0.18, -3.0 + i * 0.35), Vector3(0.45, 0.4 + i * 0.28, 0.45),
				_material("edge_blocks", Color("43859a"), 0.1))
	fox = FOX.new()
	fox.name = "OriginalLearningLumo"
	add_child(fox)
	fox.position = Vector3(-4.6, 0.05, -0.4)
	if fox.is_usable():
		var skeleton: Skeleton3D = fox.skeleton
		var low := INF
		var high := -INF
		for bone in range(skeleton.get_bone_count()):
			var y: float = skeleton.get_bone_global_rest(bone).origin.y
			low = minf(low, y)
			high = maxf(high, y)
		var fitted := 2.55 / maxf(0.2, high - low)
		fox.scale = Vector3.ONE * fitted
		fox.position.y = -low * fitted + 0.03
		fox.rotation.y = 0.3
		fox.set_reduced_motion(reduced_motion)
	else:
		fox.hide()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.1
	camera.far = 60
	add_child(camera)
	camera.position = Vector3(0.0, 10.0, 13.0)
	camera.look_at(Vector3(0.0, 0.7, 0.0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	header = _panel()
	ui.add_child(header)
	header.resized.connect(_queue_layout)
	var heading := VBoxContainer.new()
	header.add_child(heading)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	heading.add_child(title)
	explanation = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 19)
	heading.add_child(explanation)
	footer = _panel()
	ui.add_child(footer)
	footer.resized.connect(_queue_layout)
	var controls := VBoxContainer.new()
	footer.add_child(controls)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 17)
	controls.add_child(status)
	actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	controls.add_child(actions)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("112e49")
	style.border_color = Color("70b6d2")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel


func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(64, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	actions.add_child(button)
	return button


func _rebuild_activity() -> void:
	_cancel_drag()
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_moving.clear()
	if content != null:
		content.free()
	content = Node3D.new()
	content.name = "InteractiveLearningObjects"
	add_child(content)
	tokens.clear()
	targets.clear()
	token_sources.clear()
	part_nodes.clear()
	water_particles.clear()
	plant = null
	for button in actions.get_children():
		button.free()
	main_button = null
	voice_button = null
	match activity.kind:
		"bridge_ten", "addition", "bridge_hundred":
			_build_ten_frame()
			main_button = _button("Ein Objekt zeigen", _show_one)
		"subtract_ten":
			_build_subtraction()
			main_button = _button("Einen Würfel wegnehmen", _show_one)
		"equal_groups":
			_build_groups()
			main_button = _button("Einen Würfel einordnen", _show_one)
		"fraction_parts":
			_build_fractions()
			main_button = _button("Ein Teil zeigen", _show_one)
		"syllables":
			_build_syllables()
			main_button = _button("Nächste Silbe zeigen", _show_one)
		"plant_parts":
			_build_plant()
			water_button = _button("Wasser geben", _give_water)
			sun_button = _button("Sonne öffnen", _give_sun)
			for part in PART_LABELS:
				_button(str(PART_LABELS[part]), _inspect.bind(str(part)))
	_button("Noch einmal", restart)
	if _speech_enabled and is_instance_valid(_speech_host) and _speech_host.has_method("speakLearning"):
		voice_button = _button("Schritt anhören", _voice_action)
	_button("Zur Aufgabe", _return_to_lesson)
	_layout.call_deferred()


func _slot(index: int) -> Vector3:
	var tray := index / 10
	var cell := index % 10
	return Vector3(-1.6 + float(cell % 5) * 0.78, 0.3,
		-1.9 + float(cell / 5) * 0.78 + float(tray) * 2.2)


func _build_ten_frame() -> void:
	title.text = "Zahlen zum Anfassen · %d + %d" % [activity.a, activity.b]
	var rim := _material("frame", Color("c8af70"), 0.35)
	var inset := _material("slot", Color("143b4d"))
	var first := _material("blue", Color("4ac4ea"), 0.12)
	var added := _material("gold", Color("ffc852"), 0.18)
	for tray in range(2):
		_box(content, Vector3(-0.04, 0.03, -1.5 + tray * 2.2), Vector3(4.35, 0.18, 1.85), rim)
		for i in range(10):
			var at := _slot(tray * 10 + i)
			targets.append(at)
			_box(content, Vector3(at.x, 0.14, at.z), Vector3(0.68, 0.12, 0.68), inset,
				"TenFrameSlot%d" % (tray * 10 + i))
	for i in range(activity.initial_count()):
		_box(content, _slot(i), Vector3(0.58, 0.5, 0.58), first, "InitialCube%d" % i)
	for i in range(activity.token_count()):
		var at := Vector3(3.05 + float(i % 2) * 0.78, 0.3, -1.8 + float(i / 2) * 0.78)
		var cube := _box(content, at, Vector3(0.58, 0.5, 0.58), added, "MovableCube%d" % i)
		tokens.append(cube)
		token_sources.append(at)
	_text(content, "100" if activity.kind == "bridge_hundred" else "10", Vector3(-2.6, 0.5, -1.4), 0.7, rim)
	_text(content, "+ %d" % activity.b, Vector3(3.4, 1.1, -2.6), 0.7, added)
	if activity.kind == "bridge_hundred":
		title.text = "Zehner bündeln · %d + %d" % [activity.a, activity.b]
		_text(content, "%d Hunderter bleiben" % (activity.a / 100), Vector3(0, 1.1, -3.2), 0.6, first)
		for i in range(activity.a / 100):
			_box(content, Vector3(-2.9, 0.3 + i * 0.2, 1.8), Vector3(0.8, 0.16, 0.8), first, "HundredBundle%d" % i)
		for cube in content.find_children("InitialCube*", "MeshInstance3D", true, false) + tokens:
			_text(cube, "10", Vector3(0, 0.32, 0.04), 0.24, inset).rotation.x = -PI / 3.0


func _build_subtraction() -> void:
	title.text = "Wegnehmen · %d − %d" % [activity.a, activity.b]
	var rim := _material("frame", Color("c8af70"), 0.35)
	var inset := _material("slot", Color("143b4d"))
	var cube_material := _material("blue", Color("4ac4ea"), 0.12)
	for tray in range(2):
		_box(content, Vector3(-0.04, 0.03, -1.5 + tray * 2.2), Vector3(4.35, 0.18, 1.85), rim)
		for i in range(10):
			var at := _slot(tray * 10 + i)
			_box(content, Vector3(at.x, 0.14, at.z), Vector3(0.68, 0.12, 0.68), inset)
	for index in range(activity.a):
		var source := _slot(activity.a - 1 - index)
		var token := _box(content, source, Vector3(0.58, 0.5, 0.58), cube_material, "SubtractCube%d" % index)
		tokens.append(token)
		token_sources.append(source)
	for index in range(activity.b):
		targets.append(Vector3(3.0 + float(index % 3) * 0.62, 0.3 + float(index / 9) * 0.5,
			-1.5 + float((index / 3) % 3) * 0.62))
	_box(content, Vector3(3.6, 0.02, -0.9), Vector3(2.3, 0.15, 2.3), inset)
	_text(content, "weg", Vector3(3.6, 1.0, -2.4), 0.65, rim)


func _build_groups() -> void:
	title.text = "Gleiche Gruppen · %d × %d" % [activity.a, activity.b]
	var plate := _material("group_plate", Color("b6ceb0"))
	var cube_material := _material("group_cube", Color("f8c25b"), 0.1)
	for group in range(activity.a):
		var center := Vector3(-1.8 + float(group % 3) * 1.8, 0.06, -1.6 + float(group / 3) * 2.15)
		_cylinder(content, center, 0.83, 0.15, plate, "GroupPlate%d" % group)
		for item in range(activity.b):
			var at := center + Vector3(-0.42 + float(item % 3) * 0.42, 0.28, -0.23 + float(item / 3) * 0.46)
			targets.append(at)
	for i in range(activity.token_count()):
		var source := Vector3(3.7 + float(i % 3) * 0.38, 0.28 + float(i / 9) * 0.38, -1.0 + float((i / 3) % 3) * 0.4)
		var token := _box(content, source, Vector3.ONE * 0.33, cube_material, "GroupCube%d" % i)
		tokens.append(token)
		token_sources.append(source)


func _build_fractions() -> void:
	title.text = "Gleiche Bruchteile · %d/%d" % [activity.a + activity.extra, activity.b]
	var base := _material("fraction_base", Color("153b59"))
	var filled := _material("fraction_filled", Color("57bcdd"), 0.1)
	var adding := _material("fraction_added", Color("ffd361"), 0.12)
	var width_value: float = 5.4 / activity.b
	_box(content, Vector3(0.5, 0.04, -0.4), Vector3(5.6, 0.16, 2.25), base, "FractionWhole")
	for index in range(activity.b):
		var at := Vector3(-2.2 + width_value * (float(index) + 0.5), 0.27, -0.4)
		targets.append(at)
		_box(content, Vector3(at.x, 0.16, at.z), Vector3(width_value - 0.035, 0.12, 2.05),
			_material("fraction_empty", Color("6b8791")), "EqualPart%d" % index)
		if index < activity.initial_count():
			_box(content, at, Vector3(width_value - 0.04, 0.3, 2.0), filled)
	for index in range(activity.token_count()):
		var source := Vector3(-2.2 + width_value * (float(index) + 0.5), 0.35, 2.05)
		var token := _box(content, source, Vector3(width_value - 0.04, 0.3, 2.0), adding,
			"FractionPiece%d" % index)
		tokens.append(token)
		token_sources.append(source)
	_text(content, "1/%d" % activity.b, Vector3(3.8, 1.1, -1.0), 0.7, adding)


func _build_syllables() -> void:
	title.text = "Wörter bauen · " + activity.word
	var paper := _material("word_paper", Color("f2e6bf"))
	var ink := _material("word_ink", Color("153d62"))
	var colors: Array[Color] = [Color("58bedb"), Color("ffbd55"), Color("ad91dc"), Color("83c995"), Color("ed9a9b")]
	var spacing := minf(1.72, 7.4 / float(activity.syllables.size()))
	var start := 0.75 - float(activity.syllables.size() - 1) * spacing * 0.5
	_text(content, activity.word, Vector3(0.65, 2.6, -1.3), 0.85, paper)
	for i in range(activity.syllables.size()):
		var target := Vector3(start + float(i) * spacing, 0.35, -0.8)
		targets.append(target)
		_box(content, Vector3(target.x, 0.1, target.z), Vector3(spacing * 0.91, 0.2, 1.2), ink,
			"WordSlot%d" % i)
		var piece := Node3D.new()
		piece.name = "Syllable%d" % i
		content.add_child(piece)
		var at := Vector3(start + float(activity.syllables.size() - 1 - i) * spacing, 0.35, 1.4)
		piece.position = at
		_box(piece, Vector3.ZERO, Vector3(spacing * 0.84, 0.45, 0.95),
			_material("syllable%d" % i, colors[i], 0.06))
		var letters := _text(piece, activity.syllables[i], Vector3(0, 0.28, 0.12),
			minf(0.66, spacing * 1.4 / float(activity.syllables[i].length())), ink)
		letters.rotation.x = -PI / 3.0
		tokens.append(piece)
		token_sources.append(at)


func _branch(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var branch := _cylinder(parent, (from + to) * 0.5, radius, from.distance_to(to), material)
	var direction := (to - from).normalized()
	branch.quaternion = Quaternion(Vector3.UP, direction)
	return branch


func _build_plant() -> void:
	title.text = "Pflanzen entdecken · " + str(PART_LABELS[activity.plant_part])
	_growth = 0.62
	var soil := _material("soil", Color("785c41"))
	var green := _material("stem", Color("4c8b48"))
	var leaves := _material("leaves", Color("78bd51"))
	var root_material := _material("roots", Color("e4bd88"))
	_cylinder(content, Vector3(0.8, 0.15, 0.15), 1.75, 0.3, soil)
	plant = Node3D.new()
	plant.name = "LivingPlant"
	plant.position = Vector3(0.8, 0.35, 0.15)
	content.add_child(plant)
	var roots := Node3D.new()
	roots.name = "Roots"
	content.add_child(roots)
	roots.position = Vector3(0.8, 0.32, 1.1)
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		var end := Vector3(cos(angle) * 1.3, 0.015, 0.65 + sin(angle) * 0.42)
		_branch(roots, Vector3(0, 0.05, -0.9), end, 0.055, root_material)
	part_nodes["root"] = roots
	part_nodes["stem"] = _cylinder(plant, Vector3(0, 1.3, 0), 0.12, 2.6, green, "Stem")
	var leaf_group := Node3D.new()
	leaf_group.name = "Leaves"
	plant.add_child(leaf_group)
	for side in [-1, 1]:
		for i in range(2):
			var at := Vector3(side * 0.55, 0.8 + i * 0.85, 0.04)
			var leaf := _sphere(leaf_group, at, Vector3(1.1, 0.1, 0.5), leaves)
			leaf.rotation.z = side * 0.35
	part_nodes["leaf"] = leaf_group
	var flower := Node3D.new()
	flower.name = "Flower"
	flower.position.y = 2.7
	plant.add_child(flower)
	var pink := _material("petals", Color("ee9cb9"))
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		_sphere(flower, Vector3(cos(angle) * 0.4, sin(angle) * 0.4, 0), Vector3(0.55, 0.55, 0.22), pink)
	_sphere(flower, Vector3(0, 0, 0.12), Vector3(0.47, 0.47, 0.24), _material("pollen", Color("ffd65d")))
	part_nodes["flower"] = flower
	sun = _sphere(content, Vector3(3.6, 3.7, -1.5), Vector3.ONE * 1.05,
		_material("sun_closed", Color("8993a2")), "Sun")
	for i in range(7):
		var drop := _sphere(content, Vector3.ZERO, Vector3.ONE * 0.12,
			_material("water", Color("5ac9ed"), 0.15), "WaterDrop%d" % i)
		drop.hide()
		water_particles.append(drop)
	plant.scale = Vector3.ONE * _growth


func _refresh() -> void:
	explanation.text = activity.explanation()
	if activity.kind == "invalid":
		title.text = "Lumo Lernwerkstatt"
		status.text = "Kehre zur Aufgabe zurück und öffne die Lernansicht erneut."
	elif activity.kind == "plant_parts":
		status.text = "%d von 4 Pflanzenteilen entdeckt" % activity.inspected.size()
		water_button.disabled = activity.watered
		sun_button.disabled = activity.sunlight
	else:
		status.text = "%d / %d bewegt · Ziehen oder antippen" % [activity.placed.size(), activity.goal_count()]
		main_button.disabled = activity.is_complete() or not _moving.is_empty()
	if activity.is_complete():
		status.text = "Geschafft! Zurück bei deiner Aufgabe kannst du es selbst versuchen."
	_layout.call_deferred()


func _queue_layout() -> void:
	if not _layout_queued:
		_layout_queued = true
		_layout.call_deferred()


func _layout() -> void:
	_layout_queued = false
	if not is_instance_valid(camera) or not is_instance_valid(header):
		return
	var dimensions := get_viewport().get_visible_rect().size
	# Godot receives Android pixels; use the same density hint as the native
	# Kart controls. This keeps every action at least 48 device-independent px.
	var density: float = MobileRuntime.get_ui_density()
	var scale_value := minf(density, maxf(1.0, dimensions.x / 360.0))
	ui.scale = Vector2.ONE * scale_value
	var logical := dimensions / scale_value
	header.position = Vector2(12, 12)
	header.size.x = maxf(100, logical.x - 24)
	header.size.y = header.get_combined_minimum_size().y
	footer.size.x = maxf(100, logical.x - 24)
	footer.size.y = footer.get_combined_minimum_size().y
	footer.position = Vector2(12, maxf(header.position.y + header.size.y + 20, logical.y - footer.size.y - 12))
	var free_height := maxf(80, (footer.position.y - header.position.y - header.size.y) * scale_value)
	var needed_height := 7.4 * dimensions.y / free_height
	camera.size = maxf(12.4 / maxf(0.2, dimensions.x / dimensions.y), needed_height)
	var content_mid := (header.position.y + header.size.y + footer.position.y) * 0.5 * scale_value
	camera.v_offset = (content_mid / dimensions.y - 0.5) * camera.size


func _input(event: InputEvent) -> void:
	# Continue an already-owned drag even when it crosses the HUD. New presses
	# are still picked only in unhandled input, so buttons retain priority.
	if active_drag < 0 or suspended:
		return
	if event is InputEventScreenDrag and event.index == drag_finger:
		_drag_to(event.position)
	elif event is InputEventScreenTouch and not event.pressed and event.index == drag_finger:
		_end_drag(event.position, event.canceled)
	elif event is InputEventMouse and event.device != -1 and drag_finger == -2:
		if event is InputEventMouseMotion:
			_drag_to(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.position, false)


func _unhandled_input(event: InputEvent) -> void:
	if suspended or activity.kind == "invalid":
		return
	# Godot can also synthesize a mouse event from each touch. The real finger
	# owns the drag; its emulated mouse must not claim or release it a second time.
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_drag < 0:
			_begin_drag(event.position, event.index)
		elif not event.pressed and event.index == drag_finger:
			_end_drag(event.position, event.canceled)
	elif event is InputEventScreenDrag and event.index == drag_finger:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_drag < 0:
			_begin_drag(event.position, -2)
		elif not event.pressed and drag_finger == -2:
			_end_drag(event.position, false)
	elif event is InputEventMouseMotion and drag_finger == -2:
		_drag_to(event.position)


func _begin_drag(point: Vector2, finger: int) -> void:
	if activity.kind == "plant_parts":
		var best := ""
		var distance := 60.0 * ui.scale.x
		for part in part_nodes:
			var at: Vector3 = _part_position(str(part))
			var projected := camera.unproject_position(at)
			var candidate := projected.distance_to(point)
			if candidate < distance:
				distance = candidate
				best = str(part)
		if not best.is_empty():
			_inspect(best)
		return
	var closest := 44.0 * ui.scale.x
	for i in range(tokens.size()):
		if activity.placed.has(i) or _moving.has(i):
			continue
		var distance := camera.unproject_position(tokens[i].global_position).distance_to(point)
		if distance < closest:
			closest = distance
			active_drag = i
	if active_drag < 0:
		return
	drag_finger = finger
	drag_start = point
	drag_moved = false
	_stop_speech()
	_teacher("explain", tokens[active_drag].global_position)
	get_viewport().set_input_as_handled()


func _drag_to(point: Vector2) -> void:
	if active_drag < 0:
		return
	drag_moved = drag_moved or point.distance_to(drag_start) > 10.0 * ui.scale.x
	var plane := Plane(Vector3.UP, 0.55)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit is Vector3:
		tokens[active_drag].position = Vector3(clampf(hit.x, -2.4, 5.0), 0.55, clampf(hit.z, -3.0, 3.7))
		if fox != null and fox.is_usable():
			fox.set_teaching_target(tokens[active_drag].global_position)
	get_viewport().set_input_as_handled()


func _end_drag(point: Vector2, canceled: bool) -> void:
	if active_drag < 0:
		return
	var selected := active_drag
	var target: int = activity.target_index()
	var within_target := not drag_moved
	if target < targets.size():
		within_target = within_target or camera.unproject_position(targets[target]).distance_to(point) <= 55.0 * ui.scale.x
	active_drag = -1
	drag_finger = -1
	if canceled or not within_target or not move_token(selected):
		_animate_token(selected, token_sources[selected])
		if not canceled:
			_teacher("encourage", token_sources[selected])
		if not canceled and activity.kind == "syllables":
			explanation.text = activity.explanation()
		_queue_narration()
	get_viewport().set_input_as_handled()


func move_token(index: int) -> bool:
	if suspended or not _moving.is_empty():
		return false
	var destination: int = activity.target_index()
	if not activity.place(index, destination):
		_teacher("encourage", Vector3(0, 1, 0))
		return false
	print("[LearningWorld] move kind=%s token=%d target=%d placed=%d complete=%s" % [
		activity.kind, index, destination, activity.placed.size(), activity.is_complete()])
	_animate_token(index, targets[destination])
	_teacher("celebrate" if activity.is_complete() else "correct", targets[destination])
	_refresh()
	_queue_narration()
	return true


func _animate_token(index: int, destination: Vector3) -> void:
	if index < 0 or index >= tokens.size():
		return
	if reduced_motion:
		tokens[index].position = destination
		return
	_moving[index] = true
	var tween := create_tween()
	_tweens.append(tween)
	var middle := (tokens[index].position + destination) * 0.5 + Vector3.UP * 0.5
	tween.tween_property(tokens[index], "position", middle, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tokens[index], "position", destination, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		_moving.erase(index)
		_tweens.erase(tween)
		_refresh())


func _show_one() -> void:
	if activity.is_complete():
		return
	for index in range(tokens.size()):
		if not activity.placed.has(index):
			move_token(index)
			return


func _part_position(part: String) -> Vector3:
	if part == "root":
		return Vector3(0.8, 0.35, 1.7)
	if part == "leaf":
		return plant.to_global(Vector3(0.7, 1.65, 0.0))
	return part_nodes[part].global_position


func _inspect(part: String) -> void:
	if suspended or not activity.inspect_part(part):
		return
	_refresh()
	explanation.text = str(PART_HELP[part])
	_teacher("explain", _part_position(part))
	_queue_narration()


func _give_water() -> void:
	if suspended or activity.kind != "plant_parts" or activity.watered:
		return
	activity.watered = true
	_refresh()
	explanation.text = "Wasser gelangt über die Wurzeln in den Stängel und zu den Blättern."
	_teacher("explain", _part_position("root"))
	_queue_narration()


func _give_sun() -> void:
	if suspended or activity.kind != "plant_parts" or activity.sunlight:
		return
	activity.sunlight = true
	sun.material_override = _material("sun_open", Color("ffcf65"), 0.06)
	_refresh()
	_teacher("explain", sun.global_position)
	_queue_narration()


func restart() -> void:
	if suspended:
		return
	_stop_speech()
	activity.reset()
	_rebuild_activity()
	_refresh()
	_teacher("explain", Vector3(0, 1, 0))
	_queue_narration()


func _process(delta: float) -> void:
	if suspended:
		return
	_clock += delta
	_tick_speech(delta)
	if plant != null:
		var desired := 1.0 if activity.watered and activity.sunlight else 0.62
		_growth = desired if reduced_motion else move_toward(_growth, desired, delta * 0.12)
		plant.scale = Vector3.ONE * _growth
		for i in range(water_particles.size()):
			var drop := water_particles[i]
			drop.visible = activity.watered
			if drop.visible:
				var phase := 0.5 if reduced_motion else fmod(_clock * 0.3 + float(i) / 7.0, 1.0)
				drop.position = Vector3(0.8, 0.4 + phase * 2.1 * _growth, 0.27)


func _cancel_drag() -> void:
	if active_drag >= 0 and active_drag < tokens.size() and is_instance_valid(tokens[active_drag]):
		tokens[active_drag].position = token_sources[active_drag]
	active_drag = -1
	drag_finger = -1


func _return_to_lesson() -> void:
	_stop_speech()
	_cancel_drag()
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app("learn", {"status": "illustrated", "game": "learning"}):
			explanation.text = HostBridge.SAVE_FAILURE
	else:
		SceneRouter.goto("learn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_return_to_lesson()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		suspended = true
		_stop_speech()
		_cancel_drag()
		for tween in _tweens:
			if tween.is_valid():
				tween.pause()
		if fox != null:
			fox.set_suspended(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		suspended = false
		for tween in _tweens:
			if tween.is_valid():
				tween.play()
		if fox != null:
			fox.set_suspended(false)


func _exit_tree() -> void:
	_stop_speech()
	get_tree().auto_accept_quit = _original_auto_quit
	get_tree().quit_on_go_back = _original_back_quit
	get_window().content_scale_mode = _original_scale_mode


func _teacher(reaction: String, at: Vector3) -> void:
	if fox != null and fox.is_usable():
		fox.set_teaching_target(at)
		fox.teacher_react(reaction)


func _queue_narration() -> void:
	_stop_speech()
	if _speech_enabled and _auto_read and not suspended:
		_speech_text = explanation.text
		_speech_wait = 0.55


func _voice_action() -> void:
	if suspended:
		return
	if _speech_state in ["preparing", "playing"] or _speech_wait >= 0:
		_stop_speech()
	else:
		_speak(explanation.text)


func _speak(words: String) -> void:
	if not _speech_enabled or suspended or not is_instance_valid(_speech_host):
		return
	_stop_speech()
	# Read the actual displayed quantities. No unrelated prerecorded answer.
	var spoken := words.replace(" + ", " plus ").replace(" = ", " ist ").replace("/", " von ").replace("×", "mal")
	if spoken.is_empty() or spoken.length() > 220:
		return
	_speech_id += 1
	var accepted: Variant = _speech_host.call("speakLearning", JSON.stringify({
		"id": _speech_id, "text": spoken,
		"style": "celebrate" if activity.is_complete() else "explain"}))
	_speech_state = "preparing" if HostBridge.durable_ack(accepted) else "unavailable"
	_update_voice_button()


func _stop_speech() -> void:
	_speech_wait = -1.0
	_speech_id += 1
	_speech_state = "idle"
	if is_instance_valid(_speech_host) and _speech_host.has_method("stopLearningSpeech"):
		_speech_host.call("stopLearningSpeech")
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_teacher_speaking(false)
	_update_voice_button()


func _tick_speech(delta: float) -> void:
	if _speech_wait >= 0:
		_speech_wait -= delta
		if _speech_wait <= 0:
			if not _moving.is_empty() or active_drag >= 0:
				_speech_wait = 0.1
			else:
				_speak(_speech_text)
	if not is_instance_valid(_speech_host) or not _speech_enabled:
		return
	_speech_poll += delta
	if _speech_poll < 0.15:
		return
	_speech_poll = 0.0
	if not _speech_host.has_method("getLearningSpeechStatus"):
		return
	var received: Variant = JSON.parse_string(str(_speech_host.call("getLearningSpeechStatus")))
	if not received is Dictionary or int(received.get("id", -1)) != _speech_id:
		return
	var received_state := str(received.get("state", "idle"))
	if received_state not in ["preparing", "playing", "completed", "unavailable", "idle"]:
		return
	_speech_state = received_state
	# Only a confirmed MediaPlayer start animates speech. Synthesis and a timer
	# cannot masquerade as audible playback. The original rig has no jaw morph.
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_teacher_speaking(_speech_state == "playing")
	_update_voice_button()


func _update_voice_button() -> void:
	if not is_instance_valid(voice_button):
		return
	voice_button.text = "Stimme stoppen" if _speech_state in ["preparing", "playing"] else "Schritt anhören"
	voice_button.tooltip_text = "Die lokale Stimme ist gerade nicht verfügbar. Der Lernschritt bleibt lesbar." if _speech_state == "unavailable" else ""
