# gdlint: disable=max-file-lines,max-public-methods,max-returns
extends Node3D
## Lumo-Nachhilfe in 3D. Lumo zeigt jeden Schritt am Material vor, das Kind
## macht ihn selbst: Perlen am Rechenrahmen schieben, auf dem Zahlenstrahl
## springen, die zweite Zahl zerlegen. Lumo geht dafür zum Rahmen oder zur
## Zahl, zeigt und tritt danach wieder aus der Mitte. Die Szene bewertet nur
## Handgriffe an Übungs- und Zwillingsaufgaben; die Originalaufgabe
## beantwortet das Kind danach in der App. Keine Sterne, kein Fortschritt,
## keine Speicherung: Zurück geht genau einmal eine kurze Zusammenfassung an
## die App, die nach ihren bestehenden Regeln bucht.

const PLAN = preload("res://scripts/learning/tutor/tutor_plan.gd")
const FRAME = preload("res://scripts/learning/tutor/tutor_bead_frame.gd")
const PATH = preload("res://scripts/learning/tutor/tutor_number_path.gd")
const SPLIT = preload("res://scripts/learning/tutor/tutor_split_blocks.gd")
const FOX = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const HOLO_ATRIUM = preload("res://scripts/learning/lumo_holo_atrium.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const COMPANION_SCOPE = preload("res://scripts/learning/learning_companion_scope.gd")
## Die Reihenfolge der Knöpfe zeigt die Stufe; kurze Titel passen auch im
## schmalen Hochformat in eine Zeile.
const STUFEN_TITEL := {
	"hinweis": "Tipp", "teilschritt": "Gemeinsam", "vorzeigen": "Lumo zeigt", "ueben": "Selbst üben"
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
## Lumos Platz neben dem Rahmen (aus der Mitte) und sein Zeigeplatz direkt am
## linken Rahmenende, wo die gezählten Perlen liegen. Beide verdecken keine Perle.
const FOX_HOME := Vector3(-6.75, 0, 0.45)
const FOX_SHOW := Vector3(-5.4, 0, 1.45)
const FOX_HOME_FACING := 0.55
const FOX_SHOW_FACING := 1.05
## Auf dem Zahlenstrahl tritt Lumo nach dem Springen hinter den Steinweg,
## damit die Zahl, auf der er gelandet ist, lesbar bleibt.
const PATH_STEP_BACK := 1.0
const WALK_SPEED := 2.4
const TURN_SPEED := 7.0
const SPLIT_ORIGIN := Vector3(-4.3, 0.0, 2.2)
const CAMERA_DIRECTION := Vector3(0, 0.62, 0.78)
## Am Rahmen blickt die Kamera flacher: die beiden Perlenreihen liegen auf dem
## Bildschirm weiter auseinander. Die Zahlen des Steinwegs liegen flach und
## brauchen den steileren Blick.
const FRAME_CAMERA_DIRECTION := Vector3(0, 0.48, 0.88)
## Mindesthöhe eines Fingerziels (48 dp).
const TOUCH_DP := 48.0

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
var task_label: Label
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
## Beobachtbarer Ablauf (für Tests und Bildbelege), keine Kinderdaten.
var events: Array[String] = []
## "home" | "show" | "behind" | "stone" | "walking"
var fox_spot := ""
var fox_point_target := Vector3.INF
var return_count := 0
var last_return: Dictionary = {}
## Höchste geöffnete Hilfestufe (0 Tipp … 3 Selbst üben).
var hint_level := 0
var _grade := 1
## Die Zwillingsaufgabe der Stufe „Selbst üben“ ganz ohne Vorzeigen gelöst.
var twin_solved := false
var twin_attempts := 0
var twin_prompt := ""
var twin_way := ""
## Freie Bildschirmfläche (Pixel) zwischen den Tafeln für die 3D-Bühne.
var free_rect := Rect2()
var _run_misses := 0
var _run_shown := false
var _fox_unit_height := 1.0
var _fox_low := 0.0
var _fox_base := Vector3.ZERO
var _fox_height := FOX_FRAME_HEIGHT
var _fox_turn_goal := 0.0
var _walk_time := -1.0
var _walk_duration := 0.0
var _walk_from := Vector3.ZERO
var _walk_goal := Vector3.ZERO
var _walk_spot := ""
var _walk_facing := 0.0
var _pending_reaction := ""
var _pending_target := Vector3.ZERO
var _hop_queue: Array[Vector2i] = []
var _hop_time := -1.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_reaction := ""
var _drag_row := 0
var _drag_index := -1
var _drag_finger := -1
var _drag_start := Vector2.ZERO
var _drag_moved := false
var _cam_goal_position := Vector3.ZERO
var _cam_goal_target := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _camera_placed := false
var _layout_frames := 0
var _original_auto_quit := true
var _original_back_quit := true
var _original_scale_mode: Window.ContentScaleMode
var _speech_host: Object
var _speech_enabled := false
var _auto_read := false
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
	_grade = clampi(int(options.get("grade", 1)), 1, 4)
	_speech_enabled = (
		options.get("learningVoiceEnabled", false) == true
		and options.get("localVoiceLicenseAccepted", false) == true
	)
	_auto_read = _speech_enabled and options.get("learningAutoRead", false) == true
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
	split_blocks.position = SPLIT_ORIGIN
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
	_fox_base = at
	_fox_height = height
	_fox_turn_goal = facing
	if not is_instance_valid(fox) or not fox.is_usable():
		return
	var fitted := height / _fox_unit_height
	fox.scale = Vector3.ONE * fitted
	fox.position = at + Vector3(0, -_fox_low * fitted + 0.02, 0)
	fox.rotation.y = facing


## Lumo reagiert (zeigen, nicken, jubeln). Läuft er gerade, folgt die Geste
## erst am Ziel – Gehen und Zeigen teilen sich das Skelett nicht.
func _teacher(reaction: String, target: Vector3) -> void:
	if _walk_time >= 0.0:
		_pending_reaction = reaction
		_pending_target = target
		return
	fox_point_target = target
	events.append("lumo:%s" % reaction)
	if is_instance_valid(fox) and fox.is_usable() and not suspended:
		fox.set_teaching_target(target)
		fox.teacher_react(reaction)


## Lumo geht an einen Platz (oder steht mit „Animationen reduzieren“ sofort
## dort). [reaction] folgt, sobald er angekommen ist.
func _walk_to(
	goal: Vector3, spot: String, facing: float, reaction: String, target: Vector3
) -> void:
	_pending_reaction = ""
	if _walk_time >= 0.0 and _walk_spot == spot:
		_pending_reaction = reaction
		_pending_target = target
		return
	if fox_spot == spot and _walk_time < 0.0 and _fox_base.distance_to(goal) < 0.05:
		_fox_turn_goal = facing
		if not reaction.is_empty():
			_teacher(reaction, target)
		return
	events.append("walk:" + spot)
	var usable: bool = is_instance_valid(fox) and fox.is_usable()
	if reduced_motion or not usable or _fox_base.distance_to(goal) < 0.05:
		_finish_walk_now(goal, spot, facing)
		if not reaction.is_empty():
			_teacher(reaction, target)
		return
	_walk_from = _fox_base
	_walk_goal = goal
	_walk_spot = spot
	_walk_facing = facing
	_walk_duration = _fox_base.distance_to(goal) / WALK_SPEED
	_walk_time = 0.0
	_pending_reaction = reaction
	_pending_target = target
	fox_spot = "walking"
	fox.set_locomotion_speed(WALK_SPEED / maxf(0.05, fox.scale.x))


func _finish_walk_now(goal: Vector3, spot: String, facing: float) -> void:
	_walk_time = -1.0
	_place_fox(goal, _fox_height, facing)
	fox_spot = spot


func _tick_walk(delta: float) -> void:
	if _walk_time < 0.0:
		if is_instance_valid(fox) and fox.is_usable() and _hop_queue.is_empty():
			fox.rotation.y = lerp_angle(
				fox.rotation.y,
				_fox_turn_goal,
				1.0 if reduced_motion else minf(1.0, delta * TURN_SPEED)
			)
		return
	_walk_time += delta
	var t := clampf(_walk_time / maxf(0.01, _walk_duration), 0.0, 1.0)
	var heading := atan2(_walk_goal.x - _walk_from.x, _walk_goal.z - _walk_from.z)
	var facing: float = lerp_angle(fox.rotation.y, heading, minf(1.0, delta * TURN_SPEED * 1.5))
	_place_fox(_walk_from.lerp(_walk_goal, t), _fox_height, facing)
	if t < 1.0:
		return
	_walk_time = -1.0
	fox.set_locomotion_speed(0.0)
	_fox_turn_goal = _walk_facing
	fox_spot = _walk_spot
	if not _pending_reaction.is_empty():
		var reaction := _pending_reaction
		_pending_reaction = ""
		_teacher(reaction, _pending_target)


## Am Rahmen: Lumo geht zum linken Rahmenende und zeigt auf [target].
func _show_at_frame(reaction: String, target: Vector3) -> void:
	_walk_to(FOX_SHOW, "show", FOX_SHOW_FACING, reaction, target)


## Am Rahmen: Lumo tritt aus der Mitte zurück an seinen Platz.
func _step_back(reaction: String, target: Vector3) -> void:
	if not _hop_queue.is_empty():
		# Lumo springt noch: nach dem letzten Sprung tritt er ohnehin zurück.
		_hop_reaction = reaction
		return
	if _material_kind == "huepfen":
		var behind: Vector3 = (
			path.stone_position(tutor.position) + Vector3(0, 0.06, -PATH_STEP_BACK)
		)
		_walk_to(behind, "behind", 0.0, reaction, target)
	else:
		_walk_to(FOX_HOME, "home", FOX_HOME_FACING, reaction, target)


# ---------------------------------------------------------------- Oberfläche


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	header = _panel(Color("0b1d32", 0.92))
	header.name = "NachhilfeKopf"
	ui.add_child(header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	header.add_child(top)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	top.add_child(title_row)
	zurueck_button = _button("‹ Zur Aufgabe", return_to_lesson, title_row)
	zurueck_button.name = "NachhilfeZurueck"
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	title_row.add_child(titles)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("fff6d8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title)
	task_label = Label.new()
	task_label.name = "Rechnung"
	task_label.add_theme_font_size_override("font_size", 18)
	task_label.add_theme_color_override("font_color", Color("9fe7f7"))
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(task_label)
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
	bubble_role.add_theme_font_size_override("font_size", 16)
	bubble_role.add_theme_color_override("font_color", Color("187cad"))
	bubble_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_row.add_child(bubble_role)
	voice_button = _button("Vorlesen", _voice_action, role_row)
	voice_button.name = "Vorlesen"
	voice_button.visible = _speech_enabled
	bubble_text = Label.new()
	bubble_text.name = "LumoText"
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.add_theme_font_size_override("font_size", 20)
	bubble_text.add_theme_color_override("font_color", Color("12366a"))
	bubble_box.add_child(bubble_text)
	footer = _panel(Color("0b1d32", 0.92))
	footer.name = "NachhilfeFuss"
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
		stufen_row.remove_child(child)
		child.queue_free()
	for child in wege_row.get_children():
		wege_row.remove_child(child)
		child.queue_free()
	stufe_buttons.clear()
	weg_buttons.clear()
	for stufe: String in PLAN.STUFEN:
		var button := _button(STUFEN_TITEL[stufe], select_stufe.bind(stufe), stufen_row)
		button.name = "Stufe_" + stufe
		button.add_theme_font_size_override("font_size", 16)
		_style_button(button, false, stufe == tutor.stufe)
		stufe_buttons[stufe] = button
	for weg: String in tutor.wege:
		var button := _button(WEGE_TITEL[weg], select_weg.bind(weg), wege_row)
		button.name = "Weg_" + weg
		button.add_theme_font_size_override("font_size", 16)
		_style_button(button, false, weg == tutor.weg)
		weg_buttons[weg] = button


func _show_unavailable() -> void:
	title.text = "Nachhilfe mit Lumo"
	task_label.text = ""
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
	_place_fox(FOX_HOME + Vector3(4.6, 0, 0.3), FOX_FRAME_HEIGHT, 0.3)
	fox_spot = "home"


# ---------------------------------------------------------------- Ablauf


func _restart() -> void:
	_hop_queue.clear()
	_hop_time = -1.0
	path.clear_hops()
	var plan: Dictionary = tutor.plan()
	hint_level = maxi(hint_level, PLAN.STUFEN.find(tutor.stufe))
	_run_misses = 0
	_run_shown = false
	events.append("plan:%s/%s" % [tutor.weg, tutor.stufe])
	title.text = "Nachhilfe · %s" % tutor.prompt
	task_label.text = (
		"Übungsaufgabe: %d + %d" % [plan.a, plan.b]
		if plan.zwilling
		else "Wir schauen uns %d + %d an." % [plan.a, plan.b]
	)
	_material_kind = ""
	split_blocks.visible = false
	for step: Dictionary in plan.schritte:
		if step.aktion.art == "zerlegen":
			split_blocks.visible = true
			split_blocks.show_whole(step.aktion.ganz)
	frame.set_counts(0, 0, false)
	_rebuild_selectors()
	_enter_step(true)


func _enter_step(first: bool = false, acknowledged: Vector3 = Vector3.INF) -> void:
	feedback.text = "" if not first else tutor.rueckmeldung
	_update_material()
	var step: Dictionary = tutor.current()
	_rebuild_choices()
	if step.is_empty():
		var plan: Dictionary = tutor.plan()
		bubble_role.text = "Geschafft!"
		bubble_text.text = "%s\n%s" % [plan.lob, plan.abschluss]
		_finish_run()
		_step_back("celebrate", camera.global_position)
		wonder.celebrate(_material_focus())
		_auto_speak(bubble_text.text)
		_update_actions()
		return
	var intro: String = tutor.plan().einleitung + "\n" if tutor.schritt == 0 else ""
	bubble_text.text = intro + str(step.text)
	if tutor.lumo_turn():
		bubble_role.text = "Lumo zeigt"
		_perform(tutor.demonstrate())
	else:
		bubble_role.text = "Du bist dran"
		if acknowledged.is_finite():
			_step_back("correct", acknowledged)
		else:
			_step_back("encourage", _material_focus())
	_auto_speak(bubble_text.text)
	_update_actions()


## Ende eines Ablaufs: Bei „Selbst üben“ zählt die Zwillingsaufgabe als allein
## gelöst, wenn Lumo keinen Schritt vorzeigen musste.
func _finish_run() -> void:
	var plan: Dictionary = tutor.plan()
	events.append("done:%s/%s" % [tutor.weg, tutor.stufe])
	if tutor.stufe != "ueben" or _run_shown or twin_solved:
		return
	twin_solved = true
	twin_attempts = 1 + _run_misses
	twin_prompt = "%d + %d = ?" % [plan.a, plan.b]
	twin_way = tutor.weg


func _perform(action: Dictionary) -> void:
	match str(action.get("art", "")):
		"perlen":
			frame.set_counts(tutor.reihe1, tutor.reihe2)
			var row := 1 if tutor.reihe2 > 0 else 0
			_show_at_frame("explain", frame.counted_anchor(row))
		"huepfen":
			_queue_hops(int(action.von), int(action.nach), "explain")
		"zerlegen":
			split_blocks.split(int(action.teil1))
			_show_at_frame("explain", split_blocks.first_part_position())
		"ergebnis":
			if _material_kind == "huepfen":
				_teacher("correct", path.stone_position(tutor.position))
			else:
				_show_at_frame("correct", _material_focus())
		"zeigen":
			if _material_kind == "huepfen":
				_teacher("explain", _material_focus())
			else:
				_show_at_frame("explain", _material_focus())
	_rebuild_choices()


func _update_material() -> void:
	var kind: String = tutor.material()
	if kind == _material_kind:
		return
	_material_kind = kind
	frame.visible = kind == "perlen"
	path.visible = kind == "huepfen"
	_walk_time = -1.0
	_pending_reaction = ""
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_locomotion_speed(0.0)
	if kind == "perlen":
		_place_fox(FOX_HOME, FOX_FRAME_HEIGHT, FOX_HOME_FACING)
		fox_spot = "home"
	else:
		_place_fox(
			path.stone_position(tutor.position) + Vector3(0, 0.06, -PATH_STEP_BACK),
			FOX_PATH_HEIGHT,
			0.0
		)
		fox_spot = "behind"
	_layout()


func _material_focus() -> Vector3:
	if _material_kind == "huepfen":
		return path.stone_position(tutor.position)
	return frame.counted_anchor(0)


func _rebuild_choices() -> void:
	for child in choice_bar.get_children():
		choice_bar.remove_child(child)
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
		mehr_button.text = "Mehr Hilfe: " + str(STUFEN_TITEL[next])
	anders_button.visible = tutor.wege.size() > 1
	zurueck_button.text = "‹ Zur Aufgabe"
	_style_button(zurueck_button, step.is_empty(), false)
	_layout()
	_layout_frames = 2


func _result(outcome: String, focus: Vector3, hint: String = "") -> void:
	if outcome in ["zu_viel", "falsch", "gezeigt"]:
		_run_misses += 1
		events.append("miss:" + outcome)
	match outcome:
		"ok":
			var observation := _observed_action(tutor.current().aktion)
			wonder.celebrate(focus)
			tutor.advance()
			_enter_step(false, focus)
			if feedback.text.is_empty():
				feedback.text = observation
		"gezeigt":
			_run_shown = true
			bubble_role.text = "Lumo zeigt"
			bubble_text.text = _observed_action(tutor.current().aktion)
			feedback.text = "Ich zeige es dir einmal. Mit „Weiter“ bist du wieder dran."
			_perform(tutor.current().aktion)
			_auto_speak(bubble_text.text + " " + feedback.text)
			_update_actions()
		"zu_viel", "falsch":
			feedback.text = hint
			_teacher("encourage", focus)
			_auto_speak(feedback.text)
		"noch":
			feedback.text = ""


## Read back the operation that was actually shown or completed, before the
## next step changes the bead counts or the number-line position.
func _observed_action(action: Dictionary) -> String:
	match str(action.art):
		"perlen":
			var upper := int(action.reihe1)
			var lower := int(action.reihe2)
			if upper == 10:
				return "Alle zehn Plätze oben sind voll. In der unteren Reihe siehst du %d Perlen." % lower if lower != 1 else "Oben sind zehn Perlen und unten eine."
			return "Ich zähle oben %d und unten %d Perlen." % [upper, lower]
		"huepfen":
			var hops := int(action.nach) - int(action.von)
			if hops == 1:
				return "Von %d bis %d ist es genau ein Schritt." % [action.von, action.nach]
			if _grade <= 2:
				return "Von %d bis %d sind es %d Schritte." % [action.von, action.nach, hops]
			return "Zur Startzahl kommt die Sprungweite. %d + %d = %d." % [action.von, hops, action.nach]
		"zerlegen":
			if _grade <= 2:
				return "%d hier, %d dort. Zusammen sind es wieder %d." % [action.teil1, action.teil2, action.ganz]
			return "Die beiden Teile ergeben wieder das Ganze. %d + %d = %d." % [action.teil1, action.teil2, action.ganz]
		"ergebnis":
			return "Das Material zeigt das Ergebnis %d." % int(action.richtig)
	return str(tutor.current().text)


## Konkrete, ruhige Hilfe zum ersten Fehlgriff – ohne das Ergebnis zu verraten.
func _hint_for(outcome: String, value: int, second: int = 0) -> String:
	var step: Dictionary = tutor.current()
	if step.is_empty():
		return ""
	var action: Dictionary = step.aktion
	match str(action.art):
		"perlen":
			var row := "oberen" if tutor.reihe1 > int(action.reihe1) else "unteren"
			return "In der %s Reihe sind es zu viele. Schieb eine Perle zurück." % row
		"huepfen":
			if value <= int(action.von):
				return "Lumo springt nach vorne, zu den größeren Zahlen."
			if value < int(action.nach):
				return (
					"Noch nicht ganz: Lumo muss weiter springen. Zähl die Sprünge ab %d."
					% int(action.von)
				)
			return "Zu weit. Zähl die Sprünge ab %d noch einmal." % int(action.von)
		"zerlegen":
			return (
				"%d und %d: Mit %d wird die %d nicht genau 10. Probier eine andere Zerlegung."
				% [value, second, value, int(tutor.plan().a)]
			)
		"ergebnis":
			if _material_kind == "huepfen":
				return "Schau, auf welcher Zahl Lumo gelandet ist."
			return "Schau aufs Material: die volle Zehnerreihe und die Einer dazu."
	return "Noch nicht ganz. Schau noch einmal genau hin." if outcome == "falsch" else ""


## Öffentliche Handgriffe (auch für Tests und Captures).
func tap_bead(row: int, index: int) -> String:
	var current: int = tutor.reihe1 if row == 1 else tutor.reihe2
	return set_bead_count(row, index if index < current else index + 1)


func set_bead_count(row: int, count: int) -> String:
	var outcome: String = tutor.try_beads(row, count)
	if outcome != "ignoriert":
		var hint := _hint_for(outcome, count)
		frame.set_counts(tutor.reihe1, tutor.reihe2)
		_result(outcome, frame.counted_anchor(row - 1), hint)
	return outcome


func tap_stone(number: int) -> String:
	var step: Dictionary = tutor.current()
	var from: int = tutor.position
	var hint := _hint_for("falsch", number)
	var outcome: String = tutor.try_stone(number)
	if outcome == "ok":
		_queue_hops(int(step.aktion.von) if not step.is_empty() else from, tutor.position, "")
	elif outcome == "falsch":
		path.highlight(number)
	if outcome != "ignoriert":
		_result(outcome, path.stone_position(number), hint)
	return outcome


func choose_split(first: int, second: int) -> String:
	var hint := _hint_for("falsch", first, second)
	var outcome: String = tutor.try_split(first, second)
	if outcome == "ok" or outcome == "gezeigt":
		split_blocks.split(tutor.zerlegung[0])
	if outcome != "ignoriert":
		_result(outcome, split_blocks.first_part_position(), hint)
	return outcome


func choose_result(value: int) -> String:
	var hint := _hint_for("falsch", value)
	var outcome: String = tutor.try_result(value)
	if outcome != "ignoriert":
		_result(outcome, _material_focus(), hint)
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


## Lumo springt Einerschritt für Einerschritt. Danach tritt er hinter den
## Steinweg, damit die Zielzahl frei liegt, und zeigt darauf ([reaction]).
func _queue_hops(from: int, to: int, reaction: String) -> void:
	_walk_time = -1.0
	_pending_reaction = ""
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_locomotion_speed(0.0)
	var resting: bool = _hop_queue.is_empty()
	if resting and _fox_base.distance_to(path.stone_position(from)) > PATH_STEP_BACK + 0.3:
		_place_fox(
			path.stone_position(from) + Vector3(0, 0.06, -PATH_STEP_BACK), FOX_PATH_HEIGHT, 0.0
		)
	for value in range(from, to):
		_hop_queue.append(Vector2i(value, value + 1))
	_hop_reaction = reaction
	fox_spot = "stone"
	events.append("hop:%d-%d" % [from, to])
	if reduced_motion:
		for hop in _hop_queue:
			path.add_hop(hop.x, hop.y)
		_hop_queue.clear()
		_place_fox(path.stone_position(to) + Vector3(0, 0.06, 0), FOX_PATH_HEIGHT, 0.0)
		_after_hops(to)
	_fit_camera()


func _after_hops(landed: int) -> void:
	var reaction := _hop_reaction if not _hop_reaction.is_empty() else "correct"
	_hop_reaction = ""
	var behind: Vector3 = path.stone_position(landed) + Vector3(0, 0.06, -PATH_STEP_BACK)
	_walk_to(behind, "behind", 0.0, reaction, path.stone_position(landed))


func _process(delta: float) -> void:
	if suspended:
		return
	_tick_hops(delta)
	_tick_walk(delta)
	_tick_speech(delta)
	if _layout_frames > 0:
		_layout_frames -= 1
		_layout()
	if is_instance_valid(camera) and _camera_placed:
		var weight := 1.0 if reduced_motion else minf(1.0, delta * 3.0)
		camera.global_position = camera.global_position.lerp(_cam_goal_position, weight)
		_cam_target = _cam_target.lerp(_cam_goal_target, weight)
		camera.look_at(_cam_target)


func _tick_hops(delta: float) -> void:
	if _hop_queue.is_empty():
		return
	if _hop_time < 0.0:
		var hop: Vector2i = _hop_queue[0]
		_hop_from = _fox_base
		_hop_to = path.stone_position(hop.y) + Vector3(0, 0.06, 0)
		_hop_time = 0.0
	_hop_time += delta
	var t := clampf(_hop_time / HOP_SECONDS, 0.0, 1.0)
	var point := _hop_from.lerp(_hop_to, t)
	point.y += sin(t * PI) * 0.9
	_place_fox(point, FOX_PATH_HEIGHT * (1.0 - 0.08 * sin(t * PI * 2.0)), 0.0)
	if t >= 1.0:
		var hop: Vector2i = _hop_queue.pop_front()
		_place_fox(_hop_to, FOX_PATH_HEIGHT, 0.0)
		path.add_hop(hop.x, hop.y)
		_hop_time = -1.0
		if _hop_queue.is_empty():
			_after_hops(hop.y)


## Fingerziel in Pixeln: 48 dp bei der Bildschirmdichte des Geräts.
func touch_band() -> float:
	return TOUCH_DP * maxf(1.0, MobileRuntime.get_ui_density())


func is_settled() -> bool:
	return _hop_queue.is_empty() and _walk_time < 0.0 and frame.is_settled()


# ---------------------------------------------------------------- Kamera & Layout


## Feste Breite zuerst: umbrechende Texte und Knopfzeilen berechnen ihre
## Höhe aus ihr. Die Container werden sofort sortiert, damit die Tafel schon
## im selben Bild die richtige Höhe hat.
func _fit(panel: PanelContainer, at: Vector2, width: float) -> void:
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size = Vector2(width, 0)
	for attempt in range(2):
		_sort_now(panel)
		panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	panel.position = at


func _sort_now(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		if child is Control and child.visible:
			_sort_now(child)


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(header):
		return
	var dimensions := get_viewport().get_visible_rect().size
	var density: float = MobileRuntime.get_ui_density()
	var scale_value := minf(density, maxf(1.0, minf(dimensions.x, dimensions.y) / 360.0))
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
	var wide := available.x > available.y * 1.1
	var column := minf(available.x * 0.44, 520.0) if wide else minf(available.x, 760.0)
	# Hochformat: Sprechblase mit fester Mindesthöhe, damit die Bühne nicht
	# bei jedem kürzeren Satz springt.
	var lines := 0.0 if wide else (4.0 if column < 500.0 else 3.0)
	bubble_text.custom_minimum_size.y = lines * bubble_text.get_line_height()
	var left := origin.x if wide else origin.x + (available.x - column) * 0.5
	_fit(header, Vector2(left, origin.y), column)
	_fit(bubble, Vector2(left, origin.y + header.size.y + 6), column)
	if wide:
		# Querformat: links Aufgabe und Lumos Text, rechts die Bühne über der
		# Knopfleiste.
		var right := left + column + 10
		var right_width := origin.x + available.x - right
		var footer_width := minf(right_width, 760.0)
		_fit(footer, Vector2(right + (right_width - footer_width) * 0.5, 0), footer_width)
		footer.position.y = origin.y + available.y - footer.size.y
		free_rect = Rect2(
			right * scale_value,
			origin.y * scale_value,
			right_width * scale_value,
			maxf(40.0, (footer.position.y - 6 - origin.y) * scale_value)
		)
	else:
		_fit(footer, Vector2(left, 0), column)
		footer.position.y = origin.y + available.y - footer.size.y
		var top := (bubble.position.y + bubble.size.y + 6) * scale_value
		var bottom := (footer.position.y - 6) * scale_value
		free_rect = Rect2(
			6 * scale_value, top, dimensions.x - 12 * scale_value, maxf(40.0, bottom - top)
		)
	_fit_camera()


## Inhalt der Bühne als Kästen: Rahmen samt Lumos Plätzen und Zahlenhaus,
## oder der Ausschnitt des Steinwegs, den der aktuelle Schritt braucht.
func _content_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	if not valid:
		boxes.append(AABB(Vector3(-3.5, 0, -0.5), Vector3(7, 3.2, 2.5)))
	elif _material_kind == "huepfen":
		var step: Dictionary = tutor.current()
		var low: int = tutor.position
		var high: int = tutor.position
		if not step.is_empty() and step.aktion.art == "huepfen":
			low = mini(low, int(step.aktion.von))
			high = maxi(high, int(step.aktion.nach))
		low = maxi(0, low - 1)
		high = mini(20, maxi(high + 1, low + 6))
		var first: Vector3 = path.stone_position(low)
		var last: Vector3 = path.stone_position(high)
		boxes.append(
			AABB(
				Vector3(first.x - 0.7, 0, first.z - PATH_STEP_BACK - 0.5),
				Vector3(last.x - first.x + 1.4, 2.7, PATH_STEP_BACK + 1.1)
			)
		)
	else:
		boxes.append(AABB(Vector3(-7.6, 0, -0.5), Vector3(13.8, 3.4, 2.5)))
		if split_blocks.visible:
			boxes.append(
				AABB(
					SPLIT_ORIGIN + Vector3(-0.1, 0, -0.3),
					Vector3(split_blocks.whole_width() + 0.2, 1.3, 0.6)
				)
			)
	return boxes


## Kamera so stellen, dass die Bühne genau in die freie Fläche zwischen den
## Tafeln passt (seitlich verschoben, gleiche Blickrichtung).
func _fit_camera() -> void:
	if not is_instance_valid(camera) or free_rect.size.x < 10 or free_rect.size.y < 10:
		return
	var parts := _content_boxes()
	var box: AABB = parts[0]
	for part in parts:
		box = box.merge(part)
	var target := box.get_center()
	var direction := (
		(CAMERA_DIRECTION if _material_kind == "huepfen" or not valid else FRAME_CAMERA_DIRECTION)
		. normalized()
	)
	var distance := 18.0
	var shift := Vector2.ZERO
	var view := get_viewport().get_visible_rect().size
	var probe := Camera3D.new()
	probe.fov = camera.fov
	add_child(probe)
	var goal := free_rect.grow(-maxf(10.0, free_rect.size.x * 0.02))
	for iteration in range(10):
		probe.global_transform = Transform3D(Basis.IDENTITY, target + direction * distance)
		probe.look_at(target)
		probe.global_position += probe.global_basis.x * shift.x + probe.global_basis.y * shift.y
		var rect := Rect2(probe.unproject_position(target), Vector2.ZERO)
		for part in parts:
			for corner in range(8):
				rect = rect.expand(probe.unproject_position(part.get_endpoint(corner)))
		var ratio := maxf(rect.size.x / goal.size.x, rect.size.y / goal.size.y)
		distance = clampf(distance * lerpf(1.0, ratio, 0.85), 5.0, 80.0)
		var world_per_px := 2.0 * distance * tan(deg_to_rad(probe.fov * 0.5)) / view.y
		var delta_px := rect.get_center() - goal.get_center()
		shift += Vector2(delta_px.x, -delta_px.y) * world_per_px * 0.9
	remove_child(probe)
	probe.free()
	var position_value := target + direction * distance
	var basis_value := Transform3D(Basis.IDENTITY, position_value).looking_at(target).basis
	_cam_goal_position = position_value + basis_value.x * shift.x + basis_value.y * shift.y
	_cam_goal_target = target + basis_value.x * shift.x + basis_value.y * shift.y
	if reduced_motion or not _camera_placed:
		_camera_placed = true
		camera.global_position = _cam_goal_position
		camera.look_at(_cam_goal_target)
		_cam_target = _cam_goal_target


# ---------------------------------------------------------------- Sprache


func _voice_action() -> void:
	if _speech_state in ["preparing", "playing"]:
		_stop_speech()
	else:
		_speak(bubble_text.text)


func _auto_speak(words: String) -> void:
	if _auto_read:
		_speak(words)


func _update_voice_button() -> void:
	if not is_instance_valid(voice_button):
		return
	voice_button.visible = _speech_enabled
	voice_button.text = "Stopp" if _speech_state in ["preparing", "playing"] else "Vorlesen"


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
	_update_voice_button()


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
	_update_voice_button()


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
	if _speech_segments.is_empty() and state == "completed":
		_speech_state = "idle"
	_update_voice_button()


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
			# Die Reihe ist ein Streifen von mindestens 48 dp; getippt wird
			# die nächste Perle in genau dieser Reihe.
			_drag_row = frame.row_at(camera, point, touch_band())
			var hit: Vector2i = frame.pick(camera, point, tolerance)
			if _drag_row > 0 and hit.x == _drag_row:
				_drag_index = hit.y
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


## Kurze Zusammenfassung für die App: Hilfestufe, Weg, Zwillingsaufgabe. Die
## Originalaufgabe wird hier nie beantwortet, daher kein Ergebnis und keine
## Sterne – die App bucht den Lernnachweis nach ihren eigenen Regeln.
func summary(result_id: String) -> Dictionary:
	return {
		"resultId": result_id,
		"taskId": companion_scope.task_id,
		"kind": "tutor",
		"mode": twin_way if twin_solved else tutor.weg,
		"originalAnswer": "",
		"originalCorrect": false,
		"originalAttempts": 0,
		"hintLevel": hint_level,
		"twinSolved": twin_solved,
		"twinAttempts": twin_attempts if twin_solved else 0,
		"twinPrompt": twin_prompt,
	}


## Genau eine Rückgabe je Besuch (auch über die Android-Zurück-Taste).
func return_to_lesson() -> void:
	_stop_speech()
	if return_count > 0:
		return
	var payload := {"status": "illustrated", "game": "learning"}
	if valid:
		payload["holo"] = summary(HostBridge.new_result_id())
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app("learn", payload):
			feedback.text = HostBridge.SAVE_FAILURE
			return
	return_count += 1
	last_return = payload
	events.append("return")
	if not HostBridge.is_embedded() and capture_options.is_empty():
		SceneRouter.goto("learn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		return_to_lesson()
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
