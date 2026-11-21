extends Node3D
## Lumo-Nachhilfe in 3D. Lumo zeigt jeden Schritt am Material vor, das Kind
## macht ihn selbst: Perlen am Rechenrahmen schieben, auf dem Zahlenstrahl
## springen, die zweite Zahl zerlegen. Die Szene bewertet nur Handgriffe an
## Übungs- und Zwillingsaufgaben; die Originalaufgabe beantwortet das Kind
## danach in der App. Keine Sterne, kein Fortschritt, keine Speicherung.

const PLAN = preload("res://scripts/learning/tutor/tutor_plan.gd")
const FRAME = preload("res://scripts/learning/tutor/tutor_bead_frame.gd")
const PATH = preload("res://scripts/learning/tutor/tutor_number_path.gd")
const SPLIT = preload("res://scripts/learning/tutor/tutor_split_blocks.gd")
const FOX = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const HOLO_ATRIUM = preload("res://scripts/learning/lumo_holo_atrium.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const COMPANION_SCOPE = preload("res://scripts/learning/learning_companion_scope.gd")
const STUFEN_TITEL := {
	"hinweis": "1 Tipp",
	"teilschritt": "2 Gemeinsam",
	"vorzeigen": "3 Lumo zeigt",
	"ueben": "4 Selbst üben"
}
const WEGE_TITEL := {
	"rechenrahmen": "Rechenrahmen",
	"zahlenstrahl": "Zahlenstrahl",
	"zerlegen": "Zerlegen",
	"verdoppeln": "Verdoppeln",
	"tauschen": "Tauschen"
}
const HOP_SECONDS := 0.42
const FOX_FRAME_HEIGHT := 3.0
const FOX_PATH_HEIGHT := 1.7

var capture_options: Dictionary = {}
var tutor = PLAN.new()
var valid := false
var reduced_motion := false
var suspended := false
var camera: Camera3D
var fox: Node3D
var frame: Node3D
var path: Node3D
var split_blocks: Node3D
var wonder: Node3D
var ui: Control
var header: PanelContainer
var title: Label
var stufen_row: HFlowContainer
var wege_row: HFlowContainer
var bubble: PanelContainer
var bubble_role: Label
var bubble_text: Label
var feedback: Label
var footer: PanelContainer
var choice_bar: HFlowContainer
var actions: HFlowContainer
var stufe_buttons: Dictionary = {}
var weg_buttons: Dictionary = {}
var weiter_button: Button
var mehr_button: Button
var anders_button: Button
var zurueck_button: Button
var voice_button: Button
var companion_scope = COMPANION_SCOPE.new()
var _fox_unit_height := 1.0
var _fox_low := 0.0
var _hop_queue: Array[Vector2i] = []
var _hop_time := -1.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _drag_row := 0
var _drag_index := -1
var _drag_finger := -1
var _drag_start := Vector2.ZERO
var _drag_moved := false
var _cam_goal := Vector3.ZERO
var _cam_distance := 14.0
var _original_auto_quit := true
var _original_back_quit := true
var _original_scale_mode: Window.ContentScaleMode
var _speech_host: Object
var _speech_enabled := false
var _speech_rate := 1.0
var _speech_id := 0
var _speech_state := "idle"
var _speech_segments: Array[String] = []
var _speech_poll := 0.0
var _audio_scope: Dictionary = {}
var _material_kind := ""


func _ready() -> void:
	_original_auto_quit = get_tree().auto_accept_quit
	_original_back_quit = get_tree().quit_on_go_back
	_original_scale_mode = get_window().content_scale_mode
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var options: Dictionary = (
		capture_options if not capture_options.is_empty() else SceneRouter.launch_options
	)
	reduced_motion = bool(options.get("reduceAnimations", false))
	_speech_enabled = (
		options.get("learningVoiceEnabled", false) == true
		and options.get("localVoiceLicenseAccepted", false) == true
	)
	var rate: Variant = options.get("learningVoiceRate", 1.0)
	if (rate is float or rate is int) and is_finite(float(rate)):
		_speech_rate = clampf(float(rate), 0.70, 1.60)
	if Engine.has_singleton("LumoHost"):
		_speech_host = Engine.get_singleton("LumoHost")
	var raw: Variant = options.get("learning", {})
	if not raw is Dictionary:
		raw = {}
	valid = tutor.configure(raw)
	var scoped: Dictionary = raw.duplicate(true)
	if scoped.get("scope") is Dictionary:
		scoped = scoped.scope.duplicate(true)
	scoped["allowedActions"] = ["stop"]
	var launch_session := str(options.get("sessionId", ""))
	if not launch_session.is_empty():
		scoped["sessionId"] = launch_session
	if not companion_scope.configure(scoped, "local-%d" % Time.get_ticks_usec(), "nachhilfe"):
		valid = false
	_build_stage()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	if valid:
		_restart()
	else:
		_show_unavailable()
	_layout()


# ---------------------------------------------------------------- Bühne


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b1d3a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c9dcf2")
	settings.ambient_light_energy = 0.45
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 6.0
	settings.glow_enabled = true
	settings.glow_intensity = 0.6
	settings.glow_bloom = 0.08
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "NachhilfeLicht"
	key.rotation_degrees = Vector3(-52, -28, 0)
	key.light_color = Color("fff1d6")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 40
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 160, 0)
	rim.light_color = Color("8fd8ff")
	rim.light_energy = 0.35
	add_child(rim)
	var atrium := HOLO_ATRIUM.new()
	atrium.reduced_motion = reduced_motion
	add_child(atrium)
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(26, 0.3, 7.5)
	table.mesh = table_mesh
	var table_material := StandardMaterial3D.new()
	table_material.albedo_color = Color("24486b")
	table_material.roughness = 0.5
	table_material.metallic = 0.15
	table.material_override = table_material
	table.position = Vector3(0, -0.15, 0.6)
	table.name = "Lerntisch"
	add_child(table)
	frame = FRAME.new()
	frame.reduced_motion = reduced_motion
	add_child(frame)
	path = PATH.new()
	add_child(path)
	path.position = Vector3(0, 0, 1.2)
	split_blocks = SPLIT.new()
	add_child(split_blocks)
	split_blocks.position = Vector3(1.0, 0.0, 2.2)
	fox = FOX.new()
	fox.name = "NachhilfeLumo"
	add_child(fox)
	if fox.is_usable():
		var skeleton: Skeleton3D = fox.skeleton
		var low := INF
		var high := -INF
		for bone in range(skeleton.get_bone_count()):
			var y: float = skeleton.get_bone_global_rest(bone).origin.y
			low = minf(low, y)
			high = maxf(high, y)
		_fox_unit_height = maxf(0.2, high - low)
		_fox_low = low
		fox.set_reduced_motion(reduced_motion)
	else:
		fox.hide()
	camera = Camera3D.new()
	camera.fov = 42
	camera.near = 0.1
	camera.far = 120
	camera.current = true
	add_child(camera)
	wonder = WISPS.new()
	wonder.name = "NachhilfeFreude"
	wonder.celebration_only = true
	wonder.set_reduced_motion(reduced_motion)
	add_child(wonder)


func _place_fox(at: Vector3, height: float, facing: float) -> void:
	if not is_instance_valid(fox) or not fox.is_usable():
		return
	var fitted := height / _fox_unit_height
	fox.scale = Vector3.ONE * fitted
	fox.position = at + Vector3(0, -_fox_low * fitted + 0.02, 0)
	fox.rotation.y = facing


func _teacher(reaction: String, target: Vector3) -> void:
	if is_instance_valid(fox) and fox.is_usable() and not suspended:
		fox.set_teaching_target(target)
		fox.teacher_react(reaction)


# ---------------------------------------------------------------- Oberfläche


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	header = _panel(Color("0b1d32", 0.92))
	ui.add_child(header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	header.add_child(top)
	var title_row := HBoxContainer.new()
	top.add_child(title_row)
	zurueck_button = _button("‹ Zur Aufgabe", _return_to_lesson, title_row)
	zurueck_button.name = "NachhilfeZurueck"
	title = Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("fff6d8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	stufen_row = HFlowContainer.new()
	stufen_row.name = "Hilfestufen"
	stufen_row.add_theme_constant_override("h_separation", 6)
	stufen_row.add_theme_constant_override("v_separation", 6)
	top.add_child(stufen_row)
	wege_row = HFlowContainer.new()
	wege_row.name = "Loesungswege"
	wege_row.add_theme_constant_override("h_separation", 6)
	wege_row.add_theme_constant_override("v_separation", 6)
	top.add_child(wege_row)
	bubble = _panel(Color("f0f9ff", 0.97), Color("73d4ed"))
	bubble.name = "LumoSprechblase"
	ui.add_child(bubble)
	var bubble_box := VBoxContainer.new()
	bubble.add_child(bubble_box)
	var role_row := HBoxContainer.new()
	bubble_box.add_child(role_row)
	bubble_role = Label.new()
	bubble_role.add_theme_font_size_override("font_size", 15)
	bubble_role.add_theme_color_override("font_color", Color("187cad"))
	bubble_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_row.add_child(bubble_role)
	voice_button = _button("🔊 Vorlesen", _voice_action, role_row)
	voice_button.visible = _speech_enabled
	bubble_text = Label.new()
	bubble_text.name = "LumoText"
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.add_theme_font_size_override("font_size", 20)
	bubble_text.add_theme_color_override("font_color", Color("12366a"))
	bubble_box.add_child(bubble_text)
	footer = _panel(Color("0b1d32", 0.92))
	ui.add_child(footer)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	footer.add_child(bottom)
	feedback = Label.new()
	feedback.name = "Rueckmeldung"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 19)
	feedback.add_theme_color_override("font_color", Color("ffe08a"))
	bottom.add_child(feedback)
	choice_bar = HFlowContainer.new()
	choice_bar.name = "Auswahl"
	choice_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	choice_bar.add_theme_constant_override("h_separation", 10)
	choice_bar.add_theme_constant_override("v_separation", 8)
	bottom.add_child(choice_bar)
	actions = HFlowContainer.new()
	actions.name = "Aktionen"
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	bottom.add_child(actions)
	weiter_button = _button("Weiter ›", _next_step, actions, true)
	weiter_button.name = "Weiter"
	mehr_button = _button("Mehr Hilfe", _more_help, actions)
	mehr_button.name = "MehrHilfe"
	anders_button = _button("Anders zeigen", _other_way, actions)
	anders_button.name = "AndersZeigen"


func _panel(color: Color, border: Color = Color("4f9eb5", 0.83)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _button(caption: String, action: Callable, parent: Control, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(56, 52)
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button, primary, false)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style_button(button: Button, primary: bool, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color("ffc94a") if primary else (Color("73d4ed") if selected else Color("1d415b"))
	)
	style.border_color = Color("fff1b8") if primary or selected else Color("4f9bb8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, style)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = style.bg_color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	var ink := Color("10243a") if primary or selected else Color("e4f7ff")
	for state in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color"
	]:
		button.add_theme_color_override(state, ink)


func _rebuild_selectors() -> void:
	for child in stufen_row.get_children():
		child.queue_free()
	for child in wege_row.get_children():
		child.queue_free()
	stufe_buttons.clear()
	weg_buttons.clear()
	for stufe: String in PLAN.STUFEN:
		var button := _button(STUFEN_TITEL[stufe], select_stufe.bind(stufe), stufen_row)
		button.name = "Stufe_" + stufe
		_style_button(button, false, stufe == tutor.stufe)
		stufe_buttons[stufe] = button
	for weg: String in tutor.wege:
		var button := _button(WEGE_TITEL[weg], select_weg.bind(weg), wege_row)
		button.name = "Weg_" + weg
		_style_button(button, false, weg == tutor.weg)
		weg_buttons[weg] = button


func _show_unavailable() -> void:
	title.text = "Nachhilfe mit Lumo"
	bubble_role.text = "Lumo"
	bubble_text.text = (
		"Diese Nachhilfe ist gerade nicht verfügbar. "
		+ "Du findest sie auch direkt in der Aufgabe."
	)
	for button in [weiter_button, mehr_button, anders_button]:
		button.hide()
	frame.hide()
	path.hide()
	split_blocks.hide()
	_place_fox(Vector3(-2.0, 0, 0.8), FOX_FRAME_HEIGHT, 0.3)
	_frame_camera(Vector3(0, 1.4, 0), 12.0)


# ---------------------------------------------------------------- Ablauf


func _restart() -> void:
	_hop_queue.clear()
	_hop_time = -1.0
	path.clear_hops()
	var plan: Dictionary = tutor.plan()
	title.text = "Nachhilfe · %s" % tutor.prompt
	_material_kind = ""
	split_blocks.visible = false
	for step: Dictionary in plan.schritte:
		if step.aktion.art == "zerlegen":
			split_blocks.visible = true
			split_blocks.show_whole(step.aktion.ganz)
	frame.set_counts(0, 0, false)
	_rebuild_selectors()
	_enter_step(true)


func _enter_step(first: bool = false) -> void:
	feedback.text = "" if not first else tutor.rueckmeldung
	_update_material()
	var step: Dictionary = tutor.current()
	_rebuild_choices()
	if step.is_empty():
		var plan: Dictionary = tutor.plan()
		bubble_role.text = "Geschafft!"
		bubble_text.text = "%s\n%s" % [plan.lob, plan.abschluss]
		_teacher("celebrate", camera.global_position)
		wonder.celebrate(_material_focus())
		_speak(bubble_text.text)
		_update_actions()
		return
	var intro: String = tutor.plan().einleitung + "\n" if tutor.schritt == 0 else ""
	bubble_text.text = intro + str(step.text)
	if tutor.lumo_turn():
		bubble_role.text = "Lumo zeigt"
		_perform(tutor.demonstrate())
	else:
		bubble_role.text = "Du bist dran"
		_teacher("encourage", _material_focus())
	_speak(bubble_text.text)
	_update_actions()


func _perform(action: Dictionary) -> void:
	match str(action.get("art", "")):
		"perlen":
			frame.set_counts(tutor.reihe1, tutor.reihe2)
			_teacher("explain", frame.row_anchor(1 if tutor.reihe2 > 0 else 0))
		"huepfen":
			_queue_hops(int(action.von), int(action.nach))
			_teacher("explain", path.stone_position(int(action.nach)))
		"zerlegen":
			split_blocks.split(int(action.teil1))
			_teacher("explain", split_blocks.global_position)
		"ergebnis":
			_teacher("correct", _material_focus())
		"zeigen":
			_teacher("explain", _material_focus())
	_rebuild_choices()


func _update_material() -> void:
	var kind: String = tutor.material()
	if kind == _material_kind:
		return
	_material_kind = kind
	frame.visible = kind == "perlen"
	path.visible = kind == "huepfen"
	if kind == "perlen":
		_place_fox(Vector3(-6.2, 0, 1.2), FOX_FRAME_HEIGHT, 0.55)
	else:
		_place_fox(path.stone_position(tutor.position) + Vector3(0, 0.06, 0), FOX_PATH_HEIGHT, 0.0)
	_layout()


func _material_focus() -> Vector3:
	if _material_kind == "huepfen":
		return path.stone_position(tutor.position)
	return frame.row_anchor(0)


func _rebuild_choices() -> void:
	for child in choice_bar.get_children():
		child.queue_free()
	var step: Dictionary = tutor.current()
	if step.is_empty():
		return
	var action: Dictionary = step.aktion
	if action.art == "zerlegen":
		for pair: Array in action.zerlegungen:
			var selected: bool = (
				tutor.zerlegung.size() == 2
				and tutor.zerlegung[0] == pair[0]
				and tutor.zerlegung[1] == pair[1]
			)
			var button := _button(
				"%d und %d" % [pair[0], pair[1]],
				choose_split.bind(int(pair[0]), int(pair[1])),
				choice_bar
			)
			button.name = "Zerlegung_%d_%d" % [pair[0], pair[1]]
			button.custom_minimum_size = Vector2(120, 60)
			_style_button(button, false, selected)
	elif action.art == "ergebnis":
		for value: int in action.optionen:
			var button := _button(str(value), choose_result.bind(value), choice_bar)
			button.name = "Ergebnis_%d" % value
			button.custom_minimum_size = Vector2(84, 64)
			button.add_theme_font_size_override("font_size", 28)
			_style_button(button, false, tutor.gewaehlt == value)


func _update_actions() -> void:
	var step: Dictionary = tutor.current()
	weiter_button.visible = not step.is_empty() and (tutor.lumo_turn() or tutor.vorgezeigt)
	var next: String = tutor.next_stufe()
	mehr_button.visible = not next.is_empty()
	if not next.is_empty():
		mehr_button.text = "Mehr Hilfe: " + str(STUFEN_TITEL[next]).substr(2)
	anders_button.visible = tutor.wege.size() > 1
	zurueck_button.text = "‹ Zur Aufgabe"
	_style_button(zurueck_button, step.is_empty(), false)


func _result(outcome: String, focus: Vector3) -> void:
	match outcome:
		"ok":
			feedback.text = "Genau!"
			wonder.celebrate(focus)
			_teacher("correct", focus)
			tutor.advance()
			_enter_step()
			if feedback.text.is_empty():
				feedback.text = "Genau!"
		"gezeigt":
			feedback.text = "Ich zeige es dir einmal. Danach machst du weiter."
			_perform(tutor.current().aktion)
			_speak(feedback.text)
			_update_actions()
		"zu_viel":
			feedback.text = "Das sind zu viele. Schieb eine Perle zurück."
			_teacher("encourage", focus)
		"falsch":
			feedback.text = "Noch nicht ganz. Schau noch einmal genau hin."
			_teacher("encourage", focus)
		"noch":
			feedback.text = ""


## Öffentliche Handgriffe (auch für Tests und Captures).
func tap_bead(row: int, index: int) -> String:
	var current: int = tutor.reihe1 if row == 1 else tutor.reihe2
	return set_bead_count(row, index if index < current else index + 1)


func set_bead_count(row: int, count: int) -> String:
	var outcome: String = tutor.try_beads(row, count)
	if outcome != "ignoriert":
		frame.set_counts(tutor.reihe1, tutor.reihe2)
		_result(outcome, frame.row_anchor(row - 1))
	return outcome


func tap_stone(number: int) -> String:
	var step: Dictionary = tutor.current()
	var from: int = tutor.position
	var outcome: String = tutor.try_stone(number)
	if outcome == "ok":
		_queue_hops(int(step.aktion.von) if not step.is_empty() else from, tutor.position)
	elif outcome == "falsch":
		path.highlight(number)
	if outcome != "ignoriert":
		_result(outcome, path.stone_position(number))
	return outcome


func choose_split(first: int, second: int) -> String:
	var outcome: String = tutor.try_split(first, second)
	if outcome == "ok" or outcome == "gezeigt":
		split_blocks.split(tutor.zerlegung[0])
	if outcome != "ignoriert":
		_result(outcome, split_blocks.global_position)
	return outcome


func choose_result(value: int) -> String:
	var outcome: String = tutor.try_result(value)
	if outcome != "ignoriert":
		_result(outcome, _material_focus())
	return outcome


func select_stufe(stufe: String) -> void:
	if tutor.select(tutor.weg, stufe):
		_stop_speech()
		_restart()


func select_weg(weg: String) -> void:
	if tutor.select(weg, tutor.stufe):
		_stop_speech()
		_restart()


func _next_step() -> void:
	if tutor.current().is_empty():
		return
	_stop_speech()
	tutor.advance()
	_enter_step()


func _more_help() -> void:
	var next: String = tutor.next_stufe()
	if not next.is_empty():
		select_stufe(next)


func _other_way() -> void:
	select_weg(tutor.next_weg())


# ---------------------------------------------------------------- Lumo springt


func _queue_hops(from: int, to: int) -> void:
	_place_fox(path.stone_position(from) + Vector3(0, 0.06, 0), FOX_PATH_HEIGHT, 0.0)
	for value in range(from, to):
		_hop_queue.append(Vector2i(value, value + 1))
	if reduced_motion:
		for hop in _hop_queue:
			path.add_hop(hop.x, hop.y)
		_hop_queue.clear()
		_place_fox(path.stone_position(to) + Vector3(0, 0.06, 0), FOX_PATH_HEIGHT, 0.0)
	_frame_for_material()


func _process(delta: float) -> void:
	if suspended:
		return
	_tick_hops(delta)
	_tick_speech(delta)
	if is_instance_valid(camera):
		var goal := _cam_goal + Vector3(0, _cam_distance * 0.62, _cam_distance * 0.78)
		var weight := 1.0 if reduced_motion else minf(1.0, delta * 3.0)
		camera.position = camera.position.lerp(goal, weight)
		camera.look_at(_cam_goal)


func _tick_hops(delta: float) -> void:
	if _hop_queue.is_empty():
		return
	if _hop_time < 0.0:
		var hop: Vector2i = _hop_queue[0]
		_hop_from = path.stone_position(hop.x) + Vector3(0, 0.06, 0)
		_hop_to = path.stone_position(hop.y) + Vector3(0, 0.06, 0)
		_hop_time = 0.0
	_hop_time += delta
	var t := clampf(_hop_time / HOP_SECONDS, 0.0, 1.0)
	var point := _hop_from.lerp(_hop_to, t)
	point.y += sin(t * PI) * 0.9
	_place_fox(point, FOX_PATH_HEIGHT * (1.0 - 0.08 * sin(t * PI * 2.0)), 0.0)
	if t >= 1.0:
		var hop: Vector2i = _hop_queue.pop_front()
		path.add_hop(hop.x, hop.y)
		_hop_time = -1.0
		_cam_goal.x = lerpf(_cam_goal.x, path.stone_position(hop.y).x, 0.5)


# ---------------------------------------------------------------- Kamera & Layout


func _frame_camera(target: Vector3, width: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := maxf(0.3, size.x / maxf(1.0, size.y))
	var half_v := deg_to_rad(camera.fov * 0.5)
	var half_h := atan(tan(half_v) * aspect)
	_cam_goal = target
	_cam_distance = clampf((width * 0.5) / tan(half_h) * 0.9, 7.0, 46.0)
	if reduced_motion or camera.position == Vector3.ZERO:
		camera.position = target + Vector3(0, _cam_distance * 0.62, _cam_distance * 0.78)
		camera.look_at(target)


func _frame_for_material() -> void:
	if not valid:
		return
	if _material_kind == "huepfen":
		var step: Dictionary = tutor.current()
		var low: int = tutor.position
		var high: int = tutor.position
		if not step.is_empty() and step.aktion.art == "huepfen":
			low = mini(low, int(step.aktion.von))
			high = maxi(high, int(step.aktion.nach))
		low = maxi(0, low - 1)
		high = mini(20, maxi(high + 1, low + 6))
		var center: Vector3 = (path.stone_position(low) + path.stone_position(high)) * 0.5
		_frame_camera(center + Vector3(0, 0.5, 0.4), float(high - low) + 3.0)
	else:
		var width := 12.6 if split_blocks.visible else 11.8
		_frame_camera(Vector3(-0.6, 1.1, 0.9), width)


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(header):
		return
	var dimensions := get_viewport().get_visible_rect().size
	var density: float = MobileRuntime.get_ui_density()
	var scale_value := minf(density, maxf(1.0, dimensions.x / 360.0))
	ui.scale = Vector2.ONE * scale_value
	var logical := dimensions / scale_value
	ui.visible = MobileRuntime.safe_area_is_ready()
	var insets := (
		MobileRuntime.get_safe_area_insets()
		if OS.has_feature("android") or MobileRuntime.requires_safe_area_observation()
		else Rect2()
	)
	var origin := insets.position / scale_value + Vector2(10, 10)
	var available := logical - (insets.position + insets.size) / scale_value - Vector2(20, 20)
	var wide := available.x > available.y
	var panel_width := minf(available.x, 760.0) if not wide else minf(available.x * 0.46, 620.0)
	header.position = origin
	header.size = Vector2(panel_width, 0)
	header.reset_size()
	header.size.x = panel_width
	bubble.position = origin + Vector2(0, header.get_combined_minimum_size().y + 8)
	bubble.size = Vector2(panel_width, 0)
	bubble.reset_size()
	bubble.size.x = panel_width
	var footer_width := minf(available.x, 760.0)
	footer.size = Vector2(footer_width, 0)
	footer.reset_size()
	footer.size.x = footer_width
	var footer_height := footer.get_combined_minimum_size().y
	footer.position = Vector2(
		origin.x + (available.x - footer_width) * (1.0 if wide else 0.5),
		origin.y + available.y - footer_height
	)
	_frame_for_material()


# ---------------------------------------------------------------- Sprache


func _voice_action() -> void:
	if _speech_state in ["preparing", "playing"]:
		_stop_speech()
	else:
		_speak(bubble_text.text)


func _speak(words: String) -> void:
	if not _speech_enabled or suspended or not is_instance_valid(_speech_host):
		return
	if not HostBridge.supports_method(_speech_host, "speakLearning"):
		return
	_stop_speech()
	var spoken := words.replace(" + ", " plus ").replace(" = ", " ist ").replace("\n", " ")
	var remaining := spoken.strip_edges()
	while not remaining.is_empty():
		var amount := mini(220, remaining.length())
		if amount < remaining.length():
			var split := remaining.rfind(" ", amount)
			if split > 0:
				amount = split
		_speech_segments.append(remaining.left(amount).strip_edges())
		remaining = remaining.substr(amount).strip_edges()
	_start_segment()


func _start_segment() -> void:
	if _speech_segments.is_empty() or suspended:
		return
	_speech_id += 1
	_audio_scope = companion_scope.envelope(0, "nachhilfe-%d" % _speech_id)
	var request := _audio_scope.duplicate(true)
	(
		request
		. merge(
			{
				"id": _speech_id,
				"text": _speech_segments[0],
				"rate": _speech_rate,
				"style": "celebrate" if tutor.fertig else "explain",
			}
		)
	)
	var accepted: Variant = _speech_host.call("speakLearning", JSON.stringify(request))
	_speech_state = "preparing" if HostBridge.durable_ack(accepted) else "unavailable"


func _stop_speech() -> void:
	_speech_id += 1
	_speech_state = "idle"
	_speech_segments.clear()
	_audio_scope.clear()
	if (
		is_instance_valid(_speech_host)
		and HostBridge.supports_method(_speech_host, "stopLearningSpeech")
	):
		_speech_host.call("stopLearningSpeech")
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_teacher_speaking(false)
		fox.apply_speech_sample(0.0, 0.0, false)


func _tick_speech(delta: float) -> void:
	if not is_instance_valid(_speech_host) or not _speech_enabled or _speech_segments.is_empty():
		return
	_speech_poll += delta
	if _speech_poll < 0.05:
		return
	_speech_poll = 0.0
	if not HostBridge.supports_method(_speech_host, "getLearningSpeechStatus"):
		return
	var received: Variant = JSON.parse_string(str(_speech_host.call("getLearningSpeechStatus")))
	if (
		not received is Dictionary
		or not COMPANION_SCOPE._integer(received.get("id"), _speech_id, _speech_id)
	):
		return
	if received.has("protocolVersion") and not companion_scope.matches(received):
		return
	var state := str(received.get("state", "idle"))
	if state not in ["preparing", "playing", "paused", "completed", "unavailable", "idle"]:
		return
	_speech_state = state
	var position: Variant = received.get("positionMs", 0.0)
	var envelope: Variant = received.get("envelope", 0.0)
	var audible: bool = state == "playing" and received.get("audible", false) == true
	if (
		is_instance_valid(fox)
		and fox.is_usable()
		and typeof(position) in [TYPE_INT, TYPE_FLOAT]
		and typeof(envelope) in [TYPE_INT, TYPE_FLOAT]
	):
		fox.set_teacher_speaking(audible)
		fox.apply_speech_sample(
			float(position) / 1000.0, clampf(float(envelope), 0.0, 1.0), audible
		)
	if state == "completed":
		_speech_segments.pop_front()
		if not _speech_segments.is_empty():
			_start_segment()
		elif is_instance_valid(fox) and fox.is_usable():
			fox.set_teacher_speaking(false)
			fox.apply_speech_sample(0.0, 0.0, false)


# ---------------------------------------------------------------- Eingabe


func _unhandled_input(event: InputEvent) -> void:
	if not valid or suspended:
		return
	var pressed := false
	var released := false
	var moved := false
	var point := Vector2.ZERO
	var finger := 0
	if event is InputEventScreenTouch:
		finger = event.index
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		finger = event.index
		point = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		point = event.position
		moved = true
	else:
		return
	var tolerance := 34.0 * maxf(1.0, MobileRuntime.get_ui_density())
	if pressed:
		_drag_finger = finger
		_drag_start = point
		_drag_moved = false
		_drag_row = 0
		_drag_index = -1
		if _material_kind == "perlen" and frame.visible:
			var hit: Vector2i = frame.pick(camera, point, tolerance)
			if hit.x > 0:
				_drag_row = hit.x
				_drag_index = hit.y
			else:
				_drag_row = frame.row_at(camera, point, tolerance)
	elif moved and finger == _drag_finger and _drag_row > 0:
		if point.distance_to(_drag_start) > 14.0:
			_drag_moved = true
			var preview: int = frame.count_at(camera, _drag_row, point.x)
			frame.set_counts(
				preview if _drag_row == 1 else tutor.reihe1,
				preview if _drag_row == 2 else tutor.reihe2
			)
	elif released and finger == _drag_finger:
		if _material_kind == "perlen" and _drag_row > 0:
			if _drag_moved:
				set_bead_count(_drag_row, frame.count_at(camera, _drag_row, point.x))
			elif _drag_index >= 0:
				tap_bead(_drag_row, _drag_index)
		elif _material_kind == "huepfen" and not _drag_moved:
			var number: int = path.stone_at(camera, point, tolerance * 1.4)
			if number >= 0:
				tap_stone(number)
		_drag_finger = -1
		_drag_row = 0
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Rückkehr


func _return_to_lesson() -> void:
	_stop_speech()
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app("learn", {"status": "illustrated", "game": "learning"}):
			feedback.text = HostBridge.SAVE_FAILURE
	else:
		SceneRouter.goto("learn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_return_to_lesson()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		suspended = true
		_stop_speech()
		if is_instance_valid(wonder):
			wonder.set_paused(true)
		if is_instance_valid(fox):
			fox.set_suspended(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		suspended = false
		if is_instance_valid(wonder):
			wonder.set_paused(false)
		if is_instance_valid(fox):
			fox.set_suspended(false)


func _exit_tree() -> void:
	_stop_speech()
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	get_tree().auto_accept_quit = _original_auto_quit
	get_tree().quit_on_go_back = _original_back_quit
	get_window().content_scale_mode = _original_scale_mode
