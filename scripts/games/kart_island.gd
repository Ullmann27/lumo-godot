extends Node3D

const QUESTIONS = preload("res://scripts/games/kart_questions.gd")
const DRIVER = preload("res://scenes/characters/lumo/lumo_character.tscn")
const ROAD_WIDTH: float = 8.0
const TOTAL_LAPS: int = 2
var curve := Curve3D.new()
var track_length: float
var distance: float = 0.0
var lane: float = 0.0
var steering: float = 0.0
var speed: float = 0.0
var countdown: float = 3.5
var elapsed: float = 0.0
var boost_time: float = 0.0
var boosts: int = 1
var drift_charge: float = 0.0
var drifting: bool = false
var racing: bool = false
var finished: bool = false
var question_open: bool = false
var question_index: int = 0
var correct_count: int = 0
var wrong_count: int = 0
var grade: int = 1
var subject: String = "Mathematik"
var rng := RandomNumberGenerator.new()
var player: Node3D
var camera: Camera3D
var opponents: Array[Node3D] = []
var opponent_distances: Array[float] = [-5.0, -9.0, -13.0]
var wheels: Array[MeshInstance3D] = []
var gems: Array[Node3D] = []
var gem_distances: Array[float] = []
var collected: Dictionary = {}
var hud: Label
var message: Label
var boost_button: Button
var modal: PanelContainer
var modal_column: VBoxContainer
var active_question: Dictionary = {}
var recent_questions: Array[String] = []
var muted: bool = true
var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var materials: Dictionary = {}
var boxes: Dictionary = {}
var sphere_mesh: SphereMesh
var crystal_mesh: ArrayMesh

func _ready() -> void:
	rng.randomize()
	grade = clampi(int(SceneRouter.launch_options.get("grade", 1)), 1, 4)
	subject = "Deutsch" if SceneRouter.launch_options.get("subject", "") == "Deutsch" else "Mathematik"
	_build_world()
	_build_ui()
	_build_engine_sound()
	message.text = "Lumos Insel-Cup\nAutomatisches Gas · lenke links und rechts!"
	print("[Kart] ready: true 3D, grade=%d, subject=%s" % [grade, subject])

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
	var points: Array[Vector3] = [Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), Vector3(0.35, 0, 0), Vector3(0, 0, 0.35), Vector3(-0.35, 0, 0), Vector3(0, 0, -0.35)]
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

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b9e5f3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6f0ff")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color("b9e5f3")
	env.fog_density = 0.002
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	_box(self, Vector3(0, -2.6, 0), Vector3(250, 0.5, 250), Color("46bed3"))
	_ball(self, Vector3(0, -4.5, 0), Vector3(46, 4, 38), Color("73c58f"))
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var pos := Vector3(cos(angle) * 31.0 + sin(angle * 3.0) * 3.0, 0.8 + sin(angle * 2.0) * 1.2, sin(angle) * 23.0)
		var tangent := Vector3(-sin(angle) * 31.0 + cos(angle * 3.0) * 9.0, cos(angle * 2.0) * 2.4, cos(angle) * 23.0).normalized() * 4.8
		curve.add_point(pos, -tangent, tangent)
	curve.add_point(curve.get_point_position(0), curve.get_point_in(0), curve.get_point_out(0))
	curve.bake_interval = 0.35
	track_length = curve.get_baked_length()
	_build_road()
	for i in range(95):
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(7, 46)
		var pos := Vector3(cos(angle) * radius, 0.1, sin(angle) * radius * 0.8)
		if _near_track(pos):
			continue
		pos.y = -4.5 + 4.0 * sqrt(maxf(0, 1.0 - pow(pos.x / 46.0, 2) - pow(pos.z / 38.0, 2)))
		_tree(pos, rng.randf_range(0.8, 1.7))
	for i in range(10):
		var angle: float = float(i) * TAU / 10.0
		_ball(self, Vector3(cos(angle) * 65, 15 + float(i % 3) * 4, sin(angle) * 60), Vector3(8, 2.5, 4), Color("ffffff"))
	crystal_mesh = _gem_mesh()
	for i in range(18 * TOTAL_LAPS):
		var d: float = float(i) * track_length / 18.0 + 5.0
		var gem := Node3D.new()
		add_child(gem)
		_mesh(gem, crystal_mesh, Vector3.ZERO, Color("ffc84c"))
		gem.position = _track_position(d, float(i % 3 - 1) * 2.0) + Vector3.UP * 1.0
		gems.append(gem)
		gem_distances.append(d)
	player = _make_kart(Color("7264e8"), true)
	for color in [Color("ff8193"), Color("55bca9"), Color("f4b64a")]:
		opponents.append(_make_kart(color, false))
	var start := _track_position(0, 0)
	var arch := Node3D.new()
	add_child(arch)
	arch.position = start
	arch.rotation.y = _heading(0)
	_box(arch, Vector3(-4.8, 2.4, 0), Vector3(0.45, 4.8, 0.45), Color("7264e8"))
	_box(arch, Vector3(4.8, 2.4, 0), Vector3(0.45, 4.8, 0.45), Color("7264e8"))
	_box(arch, Vector3(0, 4.8, 0), Vector3(10, 1.0, 0.5), Color("fff3d3"))
	var sign := Label3D.new()
	sign.text = "LUMO  ·  INSEL-CUP"
	sign.font_size = 54
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 4.8, 0.3)
	sign.modulate = Color("3b3661")
	arch.add_child(sign)
	camera = Camera3D.new()
	camera.fov = 65
	camera.current = true
	add_child(camera)
	player.position = _track_position(0, 0)
	player.rotation.y = _heading(0)
	camera.position = player.position - _forward(0) * 7 + Vector3.UP * 4
	camera.look_at(player.position + _forward(0) * 5 + Vector3.UP)

func _near_track(pos: Vector3) -> bool:
	for i in range(40):
		if pos.distance_to(_track_position(float(i) * track_length / 40.0, 0)) < 7.0:
			return true
	return false

func _tree(pos: Vector3, scale_factor: float) -> void:
	var tree := Node3D.new()
	add_child(tree)
	tree.position = pos
	tree.scale = Vector3.ONE * scale_factor
	_box(tree, Vector3(0, 1.1, 0), Vector3(0.35, 2.2, 0.35), Color("af7b55"))
	_ball(tree, Vector3(-0.55, 2.6, 0), Vector3(1.1, 1.4, 1.1), Color("47a876"))
	_ball(tree, Vector3(0.5, 2.9, 0), Vector3(1.2, 1.5, 1.2), Color("82cc83"))
	_ball(tree, Vector3(0, 3.6, 0), Vector3(0.9, 1.2, 0.9), Color("a2df8b"))

func _build_road() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 160
	for i in range(count):
		var d: float = float(i) * track_length / float(count)
		var next: float = float(i + 1) * track_length / float(count)
		var vertices: Array[Vector3] = [_track_position(d, -4), _track_position(d, 4), _track_position(next, -4), _track_position(next, 4)]
		for index in [0, 2, 1, 1, 2, 3]:
			surface.add_vertex(vertices[index])
		for side in [-1.0, 1.0]:
			var edge := _box(self, _track_position(d, side * 4.35), Vector3(0.6, 0.2, track_length / float(count) + 0.12), Color("fff4df") if i % 2 == 0 else Color("e48e9c"))
			edge.rotation.y = _heading(d)
		if i % 5 == 0:
			var line := _box(self, _track_position(d, 0) + Vector3.UP * 0.025, Vector3(0.11, 0.035, 0.85), Color("fff1d6"))
			line.rotation.y = _heading(d)
	surface.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = surface.commit()
	road.material_override = _material(Color("a8a7bd"))
	add_child(road)

func _make_kart(color: Color, with_driver: bool) -> Node3D:
	var kart := Node3D.new()
	add_child(kart)
	_box(kart, Vector3(0, 0.55, 0), Vector3(1.25, 0.38, 1.8), color)
	_ball(kart, Vector3(0, 0.6, -0.7), Vector3(0.68, 0.25, 0.5), color.lightened(0.12))
	_box(kart, Vector3(0, 0.8, 0.48), Vector3(0.8, 0.55, 0.25), Color("34304e"))
	_box(kart, Vector3(0, 1.02, 0.95), Vector3(1.5, 0.12, 0.3), color)
	for x in [-0.7, 0.7]:
		for z in [-0.58, 0.58]:
			var tire := CylinderMesh.new()
			tire.top_radius = 0.32
			tire.bottom_radius = 0.32
			tire.height = 0.28
			tire.radial_segments = 16
			var wheel := _mesh(kart, tire, Vector3(x, 0.32, z), Color("34304e"))
			wheel.rotation.z = PI / 2
			if with_driver:
				wheels.append(wheel)
			_ball(kart, Vector3(x * 1.2, 0.32, z), Vector3(0.08, 0.15, 0.15), Color("ded9f4"))
	if with_driver:
		var driver: Node3D = DRIVER.instantiate()
		driver.scale = Vector3.ONE * 0.43
		driver.position = Vector3(0, 0.78, 0.15)
		driver.rotation.y = PI
		kart.add_child(driver)
	else:
		_ball(kart, Vector3(0, 1.3, 0.1), Vector3(0.35, 0.4, 0.35), Color("fff0d7"))
		_ball(kart, Vector3(0, 1.55, 0.1), Vector3(0.39, 0.18, 0.39), color)
	return kart

func _forward(d: float) -> Vector3:
	var p: Vector3 = curve.sample_baked(fposmod(d, track_length), true)
	var q: Vector3 = curve.sample_baked(fposmod(d + 0.5, track_length), true)
	return (q - p).normalized()

func _track_position(d: float, offset: float) -> Vector3:
	var p: Vector3 = curve.sample_baked(fposmod(d, curve.get_baked_length()), true)
	var forward: Vector3 = _forward(d) if track_length > 0 else Vector3.FORWARD
	return p + forward.cross(Vector3.UP).normalized() * offset

func _heading(d: float) -> float:
	var forward: Vector3 = _forward(d)
	return atan2(-forward.x, -forward.z)

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
	var back := _button("‹ Welt", func(): SceneRouter.goto("home"))
	top.add_child(back)
	hud = Label.new()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 21)
	hud.add_theme_color_override("font_color", Color("3b3661"))
	top.add_child(hud)
	var pause_button := _button("Pause", _pause)
	top.add_child(pause_button)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 26)
	message.add_theme_color_override("font_color", Color("3b3661"))
	column.add_child(message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	for direction in [-1.0, 1.0]:
		var button := _button("◀" if direction < 0 else "▶", func(): pass)
		button.custom_minimum_size = Vector2(82, 78)
		button.button_down.connect(func(): steering = direction)
		button.button_up.connect(func(): steering = 0)
		controls.add_child(button)
	var drift := _button("Drift", func(): pass)
	drift.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drift.button_down.connect(func(): drifting = true)
	drift.button_up.connect(_release_drift)
	controls.add_child(drift)
	boost_button = _button("Boost ◆ 1", _boost)
	controls.add_child(boost_button)
	var sound := _button("Ton: aus", func(): pass)
	sound.pressed.connect(func(): muted = not muted; sound.text = "Ton: aus" if muted else "Ton: an")
	column.add_child(sound)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -minf(300, get_viewport().get_visible_rect().size.x * 0.44)
	modal.offset_right = -modal.offset_left
	modal.offset_top = -245
	modal.offset_bottom = 245
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("fff9ed")
	panel_style.set_corner_radius_all(22)
	panel_style.set_content_margin_all(22)
	modal.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(modal)
	modal_column = VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 14)
	modal.add_child(modal_column)
	modal.hide()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 58)
	button.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7264e8")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color("9184f1")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	return button

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for gem in gems:
		if gem.visible:
			gem.rotation.y += delta * 1.7
	for i in range(gems.size()):
		gems[i].visible = not collected.has(i) and gem_distances[i] >= distance - 3 and gem_distances[i] <= distance + 28
	if countdown > 0:
		countdown -= delta
		if countdown < 3:
			message.text = str(ceili(countdown)) if countdown > 0 else "Los geht's!"
		if countdown <= 0:
			racing = true
			message.text = "Sammle Kristalle. Löse Lernstopps für neue Boosts."
	if racing and not question_open and not finished:
		elapsed += delta
		var keyboard: float = Input.get_axis("ui_left", "ui_right")
		var axis: float = keyboard if absf(keyboard) > 0.01 else steering
		lane = clampf(lane + axis * delta * 4.4, -4.15, 4.15)
		var target_speed: float = 17.0 if boost_time > 0 else 11.0
		if absf(lane) > 3.45:
			target_speed *= 0.56
		if drifting:
			target_speed *= 0.85
			drift_charge += delta * absf(axis)
		speed = move_toward(speed, target_speed, delta * 7)
		distance += speed * delta
		boost_time = maxf(0, boost_time - delta)
		for i in range(opponents.size()):
			opponent_distances[i] += delta * (10.0 + float(i) * 0.27)
		if question_index < 6 and distance >= track_length * TOTAL_LAPS * float(question_index + 1) / 7.0:
			_open_question()
		if distance >= track_length * TOTAL_LAPS:
			_finish()
		for i in range(gems.size()):
			var gem: Node3D = gems[i]
			if gem.visible and distance > gem_distances[i] + 3:
				gem.hide()
			if gem.visible and player.position.distance_to(gem.position) < 1.7:
				gem.hide()
				collected[i] = true
				if collected.size() % 3 == 0:
					boosts = mini(3, boosts + 1)
	player.position = _track_position(distance, lane)
	player.rotation.y = lerp_angle(player.rotation.y, _heading(distance), minf(1, delta * 12))
	player.rotation.z = lerpf(player.rotation.z, -steering * 0.12, delta * 5)
	for i in range(opponents.size()):
		var kart: Node3D = opponents[i]
		kart.position = _track_position(opponent_distances[i], -2.0 + float(i) * 2.0)
		kart.rotation.y = _heading(opponent_distances[i])
	var desired: Vector3 = player.position - _forward(distance) * (7.2 + speed * 0.045) + Vector3.UP * 4.4
	camera.position = camera.position.lerp(desired, minf(1, delta * 5))
	camera.look_at(player.position + _forward(distance) * 5 + Vector3.UP * 1.0)
	camera.fov = lerpf(camera.fov, 73 if boost_time > 0 else 65, delta * 3)
	var place: int = 1
	for d in opponent_distances:
		if d > distance:
			place += 1
	hud.text = "Runde %d/%d · Platz %d\n%d km/h · %d Kristalle" % [mini(TOTAL_LAPS, int(distance / track_length) + 1), TOTAL_LAPS, place, int(speed * 4.2), collected.size()]
	boost_button.text = "Boost ◆ %d" % boosts
	boost_button.disabled = boosts == 0 or question_open
	if engine_playback and not muted and racing and not question_open and not finished:
		var available: int = engine_playback.get_frames_available()
		for i in range(available):
			var phase: float = (float(Time.get_ticks_usec()) / 1000000.0 + float(i) / 22050.0) * (70.0 + speed * 5.0)
			var sample: float = sin(phase * TAU) * 0.025
			engine_playback.push_frame(Vector2(sample, sample))

func _boost() -> void:
	if boosts > 0 and racing and not question_open and not finished:
		boosts -= 1
		boost_time = 3.2
		message.text = "Lumo-Boost!"

func _release_drift() -> void:
	drifting = false
	if drift_charge >= 0.8:
		boost_time = maxf(boost_time, 1.6)
	drift_charge = 0

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_boost()
		elif event.keycode == KEY_ESCAPE:
			_pause()

func _clear_modal() -> void:
	for child in modal_column.get_children():
		modal_column.remove_child(child)
		child.queue_free()

func _modal_label(text: String, size: int = 26) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("3b3661"))
	modal_column.add_child(label)
	return label

func _open_question() -> void:
	question_open = true
	steering = 0
	drifting = false
	wrong_count = 0
	for i in range(30):
		active_question = QUESTIONS.make(grade, subject, rng)
		if not recent_questions.has(active_question.prompt):
			break
	recent_questions.append(active_question.prompt)
	_clear_modal()
	_modal_label("Lernstopp · %d. Klasse · %s" % [grade, subject], 19)
	_modal_label(active_question.prompt, 27)
	for answer in active_question.options:
		var button := _button(answer, func(): _answer(answer))
		modal_column.add_child(button)
	_modal_label("Das Rennen wartet auf dich. Du hast Zeit zum Nachdenken.", 18)
	modal.show()

func _answer(answer: String) -> void:
	if answer == active_question.answer:
		correct_count += 1
		boosts = mini(3, boosts + 1)
		question_index += 1
		question_open = false
		modal.hide()
		message.text = "Richtig! Ein neuer Boost für Lumo."
	else:
		wrong_count += 1
		var hint: String = active_question.hint
		if wrong_count >= 3:
			hint += "\nDie Lösung ist %s. Tippe sie an und fahre weiter." % active_question.answer
		var label: Label = modal_column.get_child(modal_column.get_child_count() - 1)
		label.text = "Wir schauen gemeinsam hin: " + hint

func _pause() -> void:
	if question_open or finished or countdown > 0:
		return
	racing = false
	_clear_modal()
	_modal_label("Kleine Pause")
	modal_column.add_child(_button("Weiterfahren", func(): racing = true; modal.hide()))
	modal_column.add_child(_button("Zur 3D-Welt", func(): SceneRouter.goto("home")))
	modal.show()

func _finish() -> void:
	finished = true
	racing = false
	var earned: int = 3 + correct_count * 2
	ProgressStore.add_stars(earned)
	var config := ConfigFile.new()
	config.load("user://kart_records.cfg")
	var key: String = "%s_%d" % [subject, grade]
	var best: float = float(config.get_value("times", key, 9999.0))
	if elapsed < best:
		config.set_value("times", key, elapsed)
		config.save("user://kart_records.cfg")
	_clear_modal()
	_modal_label("Insel-Cup geschafft! ★", 30)
	_modal_label("%.1f Sekunden · %d Lernstopps\n+%d Sterne · %d Kristalle" % [elapsed, correct_count, earned, collected.size()], 23)
	_modal_label("Neue Bestzeit!" if elapsed < best else "Bestzeit: %.1f Sekunden" % best, 20)
	modal_column.add_child(_button("Noch ein Rennen", func(): SceneRouter.goto("kart")))
	modal_column.add_child(_button("Zur 3D-Welt", func(): SceneRouter.goto("home")))
	modal.show()
	print("[Kart] finished: stars=%d questions=%d" % [earned, correct_count])

func _build_engine_sound() -> void:
	engine_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.1
	engine_player.stream = stream
	add_child(engine_player)
	engine_player.play()
	engine_playback = engine_player.get_stream_playback()
