# gdlint: disable=max-file-lines,max-public-methods,max-returns
# Ein Lernraum mit zwei Fachräumen; Abläufe brechen bei jedem Wechsel sofort ab
# (viele Rücksprünge). Die öffentlichen Methoden sind die
# echten Kind-Eingaben, die auch die Regressionstests und Bildbelege nutzen.
extends Node3D
## Lumos Holo-Lernraum: Textaufgabe mit Zehnerübergang und Deutsch-Wortkarten.
## Ablauf wie in der Nachhilfe: zeigen/vorlesen → Zeit geben → bei Fehler
## konkret helfen → Lösungsweg in Schritten → ähnliche Aufgabe allein.
## Die Szene bewertet nur Eingaben am Material. Sterne und Lernprotokoll bucht
## die App einmal je Aufgabe aus der zurückgegebenen Zusammenfassung.

const PLAN = preload("res://scripts/learning/holo/holo_lesson_plan.gd")
const MATH = preload("res://scripts/learning/holo/holo_math_room.gd")
const WORDS = preload("res://scripts/learning/holo/holo_word_room.gd")
const SYLLABLES = preload("res://scripts/learning/holo/holo_syllable_room.gd")
const READING = preload("res://scripts/learning/holo/holo_reading_room.gd")
const CLAP = preload("res://scripts/characters/lumo/lumo_clap_motion.gd")
const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const FOX = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const HOLO_ATRIUM = preload("res://scripts/learning/lumo_holo_atrium.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const COMPANION_SCOPE = preload("res://scripts/learning/learning_companion_scope.gd")
## Lumo ist Lehrer am Material: deutlich größer als früher (3,15), dem Kind zugewandt.
const FOX_HEIGHT := 4.2
const FOX_HALF_WIDTH := 0.6
const WALK_SPEED := 2.4
const NOUN_HELP := {
	"verb": "„%s“ ist ein Tunwort.",
	"artikel": "„%s“ ist ein Begleiter.",
	"adjektiv": "„%s“ ist ein Wiewort.",
	"andere": "„%s“ ist kein Namenwort.",
}
const ADJECTIVE_HELP := {
	"verb": "„%s“ ist ein Tunwort. Es sagt, was jemand tut.",
	"nomen": "„%s“ ist ein Namenwort. Es sagt, wer oder was.",
	"artikel": "„%s“ ist ein Begleiter. Er steht vor dem Namenwort.",
	"andere": "„%s“ sagt nicht, wie jemand ist.",
}
const TIMES := ["", "einmal", "zweimal", "dreimal", "viermal", "fünfmal", "sechsmal"]
## Abstand der Klatscher, wenn Lumo Silben klatscht (Sekunden).
const CLAP_BEAT := 0.62
const TYPE_HELP := {
	"nomen": "„%s“ ist ein Namenwort. Es sagt, wer etwas tut – nicht, was jemand tut.",
	"artikel": "„%s“ ist ein Begleiter. Er steht vor dem Namenwort.",
	"adjektiv": "„%s“ ist ein Wiewort. Es sagt, wie jemand ist.",
	"andere": "„%s“ hilft im Satz mit. Es sagt aber nicht, was jemand tut.",
}

var capture_options: Dictionary = {}
var plan = PLAN.new()
var valid := false
var reduced_motion := false
## Ruhige Bewegung oder LOW-Profil: kein Glow, keine Partikel, keine Pulse.
var low_effects := false
var suspended := false
var busy := false
var return_count := 0
var last_return: Dictionary = {}
var events: Array[String] = []
var camera: Camera3D
var fox: Node3D
var math_room: Node3D
var word_room: Node3D
var syllable_room: Node3D
var reading_room: Node3D
## Lumos Klatschen (Armknochen des Originalmodells), nur wenn das Modell da ist.
var clap: Node
var clap_button: Button
var reset_button: Button
var wonder: Node3D
var ui: Control
var header: PanelContainer
var title: Label
var prompt_label: Label
var bubble: PanelContainer
var bubble_role: Label
var bubble_text: Label
var footer: PanelContainer
var footer_box: VBoxContainer
## Querformat: Rückmeldung als eigenes Feld in der linken Spalte, damit die
## 3D-Fläche rechts nie schrumpft.
var note_panel: PanelContainer
var wide_layout := false
var feedback: Label
var choice_bar: HFlowContainer
var actions: HFlowContainer
var choice_buttons: Array[Button] = []
var back_button: Button
var hint_button: Button
var twin_button: Button
var confirm_button: Button
var skip_button: Button
var voice_button: Button
var stop_button: Button
var companion_scope = COMPANION_SCOPE.new()
var free_rect := Rect2()
var _environment: Environment
var _key_light: DirectionalLight3D
var _fox_unit := 1.0
var _fox_low := 0.0
var _fox_home := Vector3(3.6, 0, -1.4)
var _seq := 0
var _skip := false
var _demo_sentence := false
var _cam_goal_position := Vector3(0, 8, 10)
var _cam_goal_target := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _drag_index := -1
var _drag_finger := -1
var _drag_start := Vector2.ZERO
var _drag_moved := false
var _types: Array[String] = []
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
var _auto_read := false
var _first_frame_usec := 0
var _layout_queued := false
var _ready_usec := 0


func _ready() -> void:
	_ready_usec = Time.get_ticks_usec()
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
	low_effects = (
		reduced_motion or PerformanceManager.current_profile == PerformanceManager.Profile.LOW
	)
	_speech_enabled = (
		options.get("learningVoiceEnabled", false) == true
		and options.get("localVoiceLicenseAccepted", false) == true
	)
	_auto_read = options.get("learningAutoRead", false) == true
	var rate: Variant = options.get("learningVoiceRate", 1.0)
	if (rate is float or rate is int) and is_finite(float(rate)):
		_speech_rate = clampf(float(rate), 0.70, 1.60)
	if Engine.has_singleton("LumoHost"):
		_speech_host = Engine.get_singleton("LumoHost")
	var raw: Variant = options.get("learning", {})
	if not raw is Dictionary:
		raw = {}
	valid = plan.configure(raw)
	if (
		valid
		and plan.kind == "holo_sentence"
		and plan.mode in ["verb", "order", "noun", "adjective"]
	):
		valid = _read_types(raw)
	var scoped: Dictionary = raw.duplicate(true)
	if scoped.get("scope") is Dictionary:
		scoped = scoped.scope.duplicate(true)
	scoped["allowedActions"] = ["stop"]
	var launch_session := str(options.get("sessionId", ""))
	if not launch_session.is_empty():
		scoped["sessionId"] = launch_session
	if not companion_scope.configure(scoped, "local-%d" % Time.get_ticks_usec(), "holo"):
		valid = false
	_build_stage()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	EventBus.quality_profile_changed.connect(_on_quality_profile_changed)
	for panel: Control in [header, bubble, footer, note_panel]:
		panel.minimum_size_changed.connect(_queue_layout)
	if valid:
		_start_phase()
	else:
		_show_unavailable()
	_layout()
	print("[HoloLesson] ready kind=%s mode=%s valid=%s" % [plan.kind, plan.mode, valid])


## Wortarten je Karte für konkrete Rückmeldungen (genau ein Tunwort).
func _read_types(raw: Dictionary) -> bool:
	_types.clear()
	for source: Variant in [raw, raw.get("twin", {})]:
		var list: Variant = source.get("types") if source is Dictionary else null
		if not list is Array:
			return false
		var checked: Array[String] = []
		for item: Variant in list:
			if str(item) not in ["artikel", "nomen", "adjektiv", "verb", "andere"]:
				return false
			checked.append(str(item))
		var task: Dictionary = plan.tasks[0 if source == raw else 1]
		if checked.size() != task.words.size() or checked.count("verb") != 1:
			return false
		if checked[task.verbIndex] != "verb":
			return false
		# Namenwort finden: genau ein Namenwort, und es ist das gesuchte Wort.
		if plan.mode == "noun":
			if checked.count("nomen") != 1 or checked[task.nounIndex] != "nomen":
				return false
		# Wiewort finden: genau ein Wiewort, und es ist das gesuchte Wort.
		if plan.mode == "adjective":
			if checked.count("adjektiv") != 1 or checked[task.adjIndex] != "adjektiv":
				return false
		if source == raw:
			_types = checked
		else:
			task["types"] = checked
	plan.tasks[0]["types"] = _types.duplicate()
	return true


# ---------------------------------------------------------------- Bühne


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("081a33")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9d6f5")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 6.0
	_environment = settings
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.06
	settings.glow_hdr_threshold = 1.1
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "HoloLicht"
	key.rotation_degrees = Vector3(-58, -24, 0)
	key.light_color = Color("fff1d6")
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_opacity = 0.72
	_key_light = key
	key.directional_shadow_max_distance = 30
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 165, 0)
	rim.light_color = Color("7fd4ff")
	rim.light_energy = 0.45
	add_child(rim)
	var atrium := HOLO_ATRIUM.new()
	atrium.reduced_motion = reduced_motion or low_effects
	add_child(atrium)
	var podium := MODELS.podium_node(6.0)
	podium.position = Vector3(0, 0, 0.2)
	add_child(podium)
	camera = Camera3D.new()
	# Schmaler Bildwinkel: wenig Verzerrung am Bildrand (Lumo im Querformat).
	camera.fov = 32
	camera.near = 0.1
	camera.far = 120
	camera.current = true
	camera.position = Vector3(0, 7.5, 9.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0.4))
	math_room = MATH.new()
	math_room.name = "Textaufgabe"
	math_room.reduced_motion = reduced_motion
	add_child(math_room)
	word_room = WORDS.new()
	word_room.name = "Wortkarten"
	word_room.reduced_motion = reduced_motion
	add_child(word_room)
	syllable_room = SYLLABLES.new()
	syllable_room.name = "Silben"
	syllable_room.reduced_motion = reduced_motion
	add_child(syllable_room)
	reading_room = READING.new()
	reading_room.name = "Lesen"
	reading_room.reduced_motion = reduced_motion
	add_child(reading_room)
	fox = FOX.new()
	fox.name = "HoloLumo"
	add_child(fox)
	if fox.is_usable():
		var skeleton: Skeleton3D = fox.skeleton
		var low := INF
		var high := -INF
		for bone in range(skeleton.get_bone_count()):
			var y: float = skeleton.get_bone_global_rest(bone).origin.y
			low = minf(low, y)
			high = maxf(high, y)
		_fox_unit = maxf(0.2, high - low)
		_fox_low = low
		fox.set_reduced_motion(reduced_motion)
		var motion: Node = CLAP.new()
		if motion.bind(skeleton):
			fox.add_child(motion)
			clap = motion
		else:
			motion.free()
	else:
		fox.hide()
	wonder = WISPS.new()
	wonder.name = "HoloFreude"
	wonder.celebration_only = true
	wonder.set_reduced_motion(reduced_motion)
	add_child(wonder)
	_apply_effects()


## LOW-Profil oder ruhige Bewegung: kein Glow, keine Partikel, keine
## Echtzeitschatten, ruhige Hologramme – Aufgabe, Material und Hilfen bleiben
## gleich. Wechselt das Profil während des Raums, gilt es sofort.
func _apply_effects() -> void:
	_environment.glow_enabled = not low_effects
	_key_light.shadow_enabled = not low_effects
	wonder.visible = not low_effects
	word_room.calm_holograms = low_effects
	syllable_room.calm_holograms = low_effects
	reading_room.calm_holograms = low_effects


func _on_quality_profile_changed(_profile_name: String) -> void:
	low_effects = (
		reduced_motion or PerformanceManager.current_profile == PerformanceManager.Profile.LOW
	)
	_apply_effects()
	events.append("effects:%s" % ("low" if low_effects else "full"))


func _place_fox(at: Vector3, facing: float) -> void:
	if not is_instance_valid(fox) or not fox.is_usable():
		return
	var fitted := FOX_HEIGHT / _fox_unit
	fox.scale = Vector3.ONE * fitted
	fox.position = Vector3(at.x, -_fox_low * fitted + 0.02 + at.y, at.z)
	fox.rotation.y = facing


func _fox_ground() -> Vector3:
	var fitted := FOX_HEIGHT / _fox_unit
	return fox.position - Vector3(0, -_fox_low * fitted + 0.02, 0)


func _face_camera_angle(at: Vector3) -> float:
	var to_cam := camera.global_position - at
	return atan2(to_cam.x, to_cam.z)


# ---------------------------------------------------------------- Oberfläche


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	header = _panel(Color("0a1c33", 0.94))
	header.name = "Aufgabe"
	ui.add_child(header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	header.add_child(top)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	top.add_child(title_row)
	back_button = _button("‹ Zur Aufgabe", return_to_lesson, title_row)
	back_button.name = "ZurAufgabe"
	title = Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("8fe9ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 80
	title_row.add_child(title)
	prompt_label = Label.new()
	prompt_label.name = "Aufgabentext"
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color("fff8e6"))
	top.add_child(prompt_label)
	bubble = _panel(Color("eef9ff", 0.97), Color("73d4ed"))
	bubble.name = "LumoSprechblase"
	ui.add_child(bubble)
	var bubble_box := VBoxContainer.new()
	bubble_box.add_theme_constant_override("separation", 4)
	bubble.add_child(bubble_box)
	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	bubble_box.add_child(role_row)
	bubble_role = Label.new()
	bubble_role.text = "Lumo"
	bubble_role.add_theme_font_size_override("font_size", 15)
	bubble_role.add_theme_color_override("font_color", Color("187cad"))
	bubble_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_row.add_child(bubble_role)
	voice_button = _button("🔊 Hören", _voice_action, role_row)
	voice_button.name = "Vorlesen"
	stop_button = _button("■ Stopp", _stop_speech, role_row)
	stop_button.name = "SpracheStopp"
	bubble_text = Label.new()
	bubble_text.name = "LumoText"
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.add_theme_font_size_override("font_size", 18)
	bubble_text.custom_minimum_size.y = 72
	bubble_text.add_theme_color_override("font_color", Color("12366a"))
	bubble_box.add_child(bubble_text)
	footer = _panel(Color("0a1c33", 0.94))
	footer.name = "Antworten"
	ui.add_child(footer)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	footer.add_child(bottom)
	footer_box = bottom
	feedback = Label.new()
	feedback.name = "Rueckmeldung"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 18)
	# Feste Höhe für zwei Zeilen: Die 3D-Fläche springt bei Rückmeldungen nicht.
	feedback.custom_minimum_size.y = 50
	feedback.add_theme_color_override("font_color", Color("ffe08a"))
	bottom.add_child(feedback)
	note_panel = _panel(Color("0a1c33", 0.94))
	note_panel.name = "RueckmeldungQuer"
	note_panel.visible = false
	ui.add_child(note_panel)
	choice_bar = HFlowContainer.new()
	choice_bar.name = "Auswahl"
	choice_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	choice_bar.add_theme_constant_override("h_separation", 10)
	choice_bar.add_theme_constant_override("v_separation", 8)
	bottom.add_child(choice_bar)
	# Antworten und Hilfen teilen eine umbrechende Reihe: im schmalen
	# Hochformat zwei Zeilen, im Querformat eine.
	actions = choice_bar
	hint_button = _button("💡 Tipp", request_hint, actions)
	hint_button.name = "Tipp"
	confirm_button = _button("Prüfen ✓", confirm, actions, true)
	confirm_button.name = "Pruefen"
	twin_button = _button("Ähnliche Aufgabe ›", start_twin, actions, true)
	twin_button.name = "AehnlicheAufgabe"
	# „Überspringen“ steht während einer Vorführung dort, wo sonst „Tipp“
	# steht: Die Leiste behält ihre Höhe, die 3D-Fläche springt nicht.
	skip_button = _button("Überspringen ›", skip, actions)
	skip_button.name = "Ueberspringen"


func _panel(color: Color, border: Color = Color("4f9eb5", 0.85)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _button(caption: String, action: Callable, parent: Control, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	# 52 logische Punkte × Dichte ≥ 126 px auf dem Fold (48 dp).
	button.custom_minimum_size = Vector2(56, 52)
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button, primary)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style_button(button: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffc94a") if primary else Color("1d415b")
	style.border_color = Color("fff1b8") if primary else Color("5fb3d1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, style)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = style.bg_color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	var dim := style.duplicate() as StyleBoxFlat
	dim.bg_color = Color(style.bg_color, 0.45)
	dim.border_color = Color(style.border_color, 0.4)
	button.add_theme_stylebox_override("disabled", dim)
	var ink := Color("10243a") if primary else Color("e4f7ff")
	for state in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color"
	]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color(ink, 0.5))


func _show_unavailable() -> void:
	title.text = "Holo-Lernraum"
	prompt_label.text = "Diese Aufgabe gibt es noch nicht im Holo-Raum."
	bubble_text.text = "Du findest sie wie gewohnt in der App. Tippe auf „Zur Aufgabe“."
	for button in [
		hint_button, confirm_button, twin_button, skip_button, voice_button, stop_button
	]:
		button.hide()
	math_room.hide()
	word_room.hide()
	syllable_room.hide()
	reading_room.hide()
	_place_fox(Vector3(0, 0, -0.5), 0.0)


# ---------------------------------------------------------------- Ablauf


func _start_phase() -> void:
	_seq += 1
	_demo_sentence = false
	_skip = false
	busy = false
	var task: Dictionary = plan.current()
	feedback.text = ""
	_stop_clap()
	syllable_room.hide()
	reading_room.hide()
	# Deutsch: neben der Kartenleiste (Querformat) bzw. rechts dahinter mit
	# freien Füßen über den Karten (Hochformat) – nie vor den Karten.
	_fox_home = Vector3(2.6, 0, -2.7) if _portrait() else Vector3(5.6, 0, -0.5)
	if plan.kind == "holo_word_problem":
		title.text = (
			"Plus mit Zehnerübergang" if plan.phase == "original" else "Ähnliche Aufgabe · allein"
		)
		prompt_label.text = task.prompt
		word_room.hide()
		math_room.show()
		math_room.build(task)
		# Hochformat: in der Gasse zwischen Korb und Schale (Füße frei, nichts
		# verdeckt). Querformat: rechts neben dem Zwanzigerfeld. Immer dem Kind
		# zugewandt.
		_fox_home = Vector3(0.0, 0, -2.55) if _portrait() else Vector3(4.4, 0, 1.4)
		bubble_text.text = (
			(
				"Lies die Aufgabe mit mir. Tippe die Äpfel an und zähle mit. "
				+ "Du kannst sie auch ins Zehnerfeld ziehen."
			)
			if plan.phase == "original"
			else ("Neue Äpfel, gleiche Frage. Diesmal schaffst du es allein – ich schaue nur zu.")
		)
	elif plan.mode == "syllables":
		math_room.hide()
		word_room.hide()
		syllable_room.show()
		syllable_room.build(task, _card_basis())
		title.text = "Silben klatschen" if plan.phase == "original" else "Ähnliches Wort · allein"
		prompt_label.text = str(task.prompt)
		bubble_text.text = (
			(
				(
					"Tippe die Wortkarte an, dann lese ich dir das Wort vor. "
					if _speech_enabled
					else "Lies das Wort leise. "
				)
				+ "Sprich es langsam und tippe bei jeder Silbe einmal auf „Klatschen“."
			)
			if plan.phase == "original"
			else "Neues Wort. Diesmal klatschst du allein – ich schaue nur zu."
		)
		_fox_home = syllable_room.lumo_spot(FOX_HALF_WIDTH)
	elif plan.mode == "reading":
		math_room.hide()
		word_room.hide()
		reading_room.show()
		reading_room.build(task, task.scenes, _card_basis(), _narrow())
		title.text = (
			"Lesen: Welches Bild passt?" if plan.phase == "original" else "Neuer Satz · allein"
		)
		prompt_label.text = "„%s“\n%s" % [task.sentence, task.question]
		bubble_text.text = (
			"Lies den Satz genau. Tippe dann das Bild an, das zum Satz passt."
			if plan.phase == "original"
			else "Neuer Satz, neue Bilder. Diesmal findest du es allein."
		)
		_fox_home = reading_room.lumo_spot(FOX_HALF_WIDTH)
	else:
		math_room.hide()
		word_room.show()
		if plan.mode in ["verb", "noun", "adjective"]:
			var target: String = {"verb": "Tunwort", "noun": "Namenwort", "adjective": "Wiewort"}[
				plan.mode
			]
			title.text = (
				"%s finden" % target if plan.phase == "original" else "Ähnlicher Satz · allein"
			)
			prompt_label.text = (
				"„%s“\n%s" % [task.sentence, task.question]
				if plan.mode == "adjective"
				else "„%s“\nWelches Wort ist das %s?" % [task.sentence, target]
			)
			bubble_text.text = (
				"Lies den Satz. Tippe eine Karte an – sie hebt sich"
				+ (" und ich lese sie vor." if _speech_enabled else ".")
				+ " Dann wähle das %s." % target
			)
		else:
			title.text = ("Satz bauen" if plan.phase == "original" else "Neuer Satz · allein")
			prompt_label.text = "Bilde einen Satz aus den Wortkarten."
			bubble_text.text = (
				"Tippe die Karten der Reihe nach an. "
				+ "Tippst du eine gelegte Karte an, kommt sie zurück."
			)
		word_room.build(task, plan.mode, plan.shuffled, _card_basis(), _narrow())
		# Seitlich neben den Karten, Füße frei, dem Kind zugewandt.
		_fox_home = word_room.lumo_spot(FOX_HALF_WIDTH)
	_place_fox(_fox_home, _face_camera_angle(_fox_home))
	_rebuild_choices()
	_update_actions()
	_layout()
	_teacher("welcome", camera.global_position)
	events.append("phase:%s" % plan.phase)
	if _auto_read:
		_speak(prompt_label.text)
	if plan.kind == "holo_word_problem":
		_intro_drop(_seq)


## Lumo legt die zweite Gruppe sichtbar dazu – die Handlung aus der Aufgabe.
func _intro_drop(serial: int) -> void:
	var a := int(plan.current().a)
	var b := int(plan.current().b)
	if reduced_motion:
		return
	busy = true
	_update_actions()
	for j in range(b):
		var index := a + j
		var target: Vector3 = math_room.home[index]
		math_room.apples[index].position = target + Vector3(0.6, 2.2, -0.4)
	_teacher("explain", math_room.group_center(1))
	for j in range(b):
		if not await _wait(0.16, serial):
			return
		math_room.to_home(a + j, 0.42)
	await _wait(0.5, serial)
	if serial == _seq:
		busy = false
		_update_actions()


func _portrait() -> bool:
	var size_value := get_viewport().get_visible_rect().size
	return size_value.y >= size_value.x * 0.8


## Schmales Hochformat (Handy): Satz in zwei Zeilen. Fold offen ist fast
## quadratisch – dort bleibt der Satz in einer Zeile.
func _narrow() -> bool:
	var size_value := get_viewport().get_visible_rect().size
	return size_value.x < size_value.y * 0.7


func _card_basis() -> Basis:
	# Karten stehen leicht zur Kamera geneigt, damit sie von oben lesbar sind.
	return Basis(Vector3.RIGHT, deg_to_rad(-24))


func _rebuild_choices() -> void:
	for button in choice_buttons:
		choice_bar.remove_child(button)
		button.queue_free()
	choice_buttons.clear()
	clap_button = null
	reset_button = null
	if plan.mode == "syllables":
		# Großer Klatsch-Knopf (je Silbe einmal) und „Neu“ zum Wiederholen.
		clap_button = _button("👏 Klatschen", clap_syllable, choice_bar, true)
		clap_button.name = "Klatschen"
		clap_button.custom_minimum_size = Vector2(170, 64)
		clap_button.add_theme_font_size_override("font_size", 24)
		choice_bar.move_child(clap_button, 0)
		reset_button = _button("↺ Neu", clear_claps, choice_bar)
		reset_button.name = "NeuKlatschen"
		choice_bar.move_child(reset_button, 1)
		choice_buttons.append(clap_button)
		choice_buttons.append(reset_button)
		return
	if plan.kind != "holo_word_problem":
		return
	for value: int in plan.choices():
		var button := _button(str(value), choose.bind(str(value)), choice_bar)
		button.name = "Antwort_%d" % value
		button.custom_minimum_size = Vector2(76, 56)
		button.add_theme_font_size_override("font_size", 24)
		choice_bar.move_child(button, choice_buttons.size())
		choice_buttons.append(button)


func _update_actions() -> void:
	var done: bool = plan.phase == "done"
	var solved_original: bool = plan.phase == "original" and plan.original_correct
	hint_button.visible = (
		valid
		and not done
		and not solved_original
		and (plan.hint_level < PLAN.HINT_FULL if plan.phase == "original" else plan.hint_level >= 0)
	)
	hint_button.text = "💡 Tipp" if plan.hint_level == 0 or plan.phase == "twin" else "💡 Mehr Hilfe"
	hint_button.visible = hint_button.visible and not busy
	twin_button.visible = solved_original
	twin_button.disabled = busy
	confirm_button.visible = (
		plan.kind == "holo_sentence" and plan.mode != "reading" and not done and not solved_original
	)
	# Kurz, damit „Mehr Hilfe“/„Überspringen“ und „Prüfen“ in eine Zeile passen.
	confirm_button.text = "Satz prüfen ✓" if plan.mode == "order" else "Prüfen ✓"
	if plan.kind == "holo_sentence":
		if plan.mode == "syllables":
			confirm_button.disabled = busy or plan.claps == 0
		elif plan.mode == "order":
			confirm_button.disabled = busy or plan.placed.size() != plan.current().words.size()
		else:
			confirm_button.disabled = busy or word_room.selected < 0
	for button in choice_buttons:
		button.disabled = busy or done or solved_original
	if is_instance_valid(clap_button):
		clap_button.disabled = clap_button.disabled or plan.claps >= PLAN.MAX_CLAPS
	if is_instance_valid(reset_button):
		reset_button.disabled = reset_button.disabled or plan.claps == 0
	skip_button.visible = busy
	voice_button.visible = _speech_enabled
	stop_button.visible = _speech_enabled and _speech_state in ["preparing", "playing"]
	if done:
		back_button.text = "‹ Zurück zur Aufgabe"
		_style_button(back_button, true)


func _teacher(reaction: String, target: Vector3) -> void:
	if is_instance_valid(fox) and fox.is_usable() and not suspended:
		fox.set_teaching_target(target)
		fox.teacher_react(reaction)


## Die ruhige Rückmeldung zum Fehler wandert in Lumos erste Hilfe-Sprechblase;
## unten bleibt während der Hilfe keine alte Fehlermeldung stehen.
func _take_feedback() -> String:
	var note := feedback.text
	feedback.text = ""
	return "" if note.is_empty() else note + " "


func _say(words: String) -> void:
	bubble_text.text = words
	if _speech_enabled:
		_speak(words)
	_layout()


## Wartet echte Zeit; „Überspringen“ und ruhige Bewegung beenden sofort.
## Liefert false, wenn der Ablauf inzwischen ersetzt wurde.
func _wait(seconds: float, serial: int) -> bool:
	if reduced_motion or _skip:
		return serial == _seq
	var left := seconds
	while left > 0.0 and serial == _seq and not _skip and is_inside_tree():
		await get_tree().process_frame
		if not suspended:
			left -= get_process_delta_time()
	return serial == _seq


func skip() -> void:
	if not busy:
		return
	_skip = true
	_stop_speech()
	math_room.finish_motion()
	word_room.finish_motion()
	syllable_room.finish_motion()
	reading_room.finish_motion()
	events.append("skip")


## Lumo geht zum Material, zeigt darauf und bleibt dort, bis der Ablauf
## weitergeht. Bei ruhiger Bewegung steht er sofort dort.
func _walk_to(target: Vector3, look_at_point: Vector3, serial: int) -> bool:
	if not is_instance_valid(fox) or not fox.is_usable():
		return serial == _seq
	var start := _fox_ground()
	var goal := Vector3(target.x, 0, target.z)
	if reduced_motion or _skip:
		_place_fox(goal, _face_camera_angle(goal))
		_teacher("explain", look_at_point)
		return serial == _seq
	# Umwege: Lumo läuft nie durch Korb, Schale oder Zwanzigerfeld.
	var leg_start := start
	for leg in _route(start, goal):
		var distance := leg_start.distance_to(leg)
		var travelled := 0.0
		while travelled < distance and serial == _seq and not _skip and is_inside_tree():
			await get_tree().process_frame
			if suspended:
				continue
			var step := WALK_SPEED * get_process_delta_time()
			travelled = minf(distance, travelled + step)
			var point := leg_start.lerp(leg, travelled / maxf(0.001, distance))
			var direction := leg - leg_start
			_place_fox(point, atan2(direction.x, direction.z))
			fox.set_locomotion_speed(WALK_SPEED)
		leg_start = leg
	fox.set_locomotion_speed(0.0)
	_place_fox(goal, _face_camera_angle(goal))
	_teacher("explain", look_at_point)
	return serial == _seq


## Wegpunkte bis zum Ziel. Mathe: Kreuzt der direkte Weg Korb, Schale oder
## Zwanzigerfeld, führt er über den Gang zwischen Behältern und Feld.
func _route(start: Vector3, goal: Vector3) -> Array[Vector3]:
	var legs: Array[Vector3] = [goal]
	if plan.kind != "holo_word_problem" or _path_clear(start, goal):
		return legs
	# Gang knapp vor den Behältern: Lumos Füße bleiben im Bild über dem Feld.
	var lane: float = math_room.frame_box().position.z - 1.0
	return [Vector3(start.x, 0, lane), Vector3(goal.x, 0, lane), goal]


func _path_clear(start: Vector3, goal: Vector3) -> bool:
	var frame_area: AABB = math_room.frame_box().grow(FOX_HALF_WIDTH)
	for step in range(1, 20):
		var point := start.lerp(goal, step / 20.0)
		if frame_area.has_point(Vector3(point.x, 0.1, point.z)):
			return false
		for center in [MATH.BASKET_AT, MATH.PLATE_AT]:
			var reach: float = MATH.PLATE_RADIUS + FOX_HALF_WIDTH
			if Vector2(point.x - center.x, point.z - center.z).length() < reach:
				return false
	return true


func _step_aside(serial: int) -> void:
	await _walk_to(_fox_home, camera.global_position, serial)
	if serial == _seq and is_instance_valid(fox) and fox.is_usable():
		_place_fox(_fox_home, _face_camera_angle(_fox_home))
		fox.clear_teaching_target()


## Lumo springt einmal (Hilfe beim Tunwort „springt“).
func _jump(serial: int) -> bool:
	if not is_instance_valid(fox) or not fox.is_usable():
		return serial == _seq
	events.append("lumo_jump")
	if reduced_motion or _skip:
		return serial == _seq
	var ground := _fox_ground()
	var facing: float = fox.rotation.y
	var time := 0.0
	var duration := 0.8
	while time < duration and serial == _seq and not _skip and is_inside_tree():
		await get_tree().process_frame
		if suspended:
			continue
		var delta := get_process_delta_time()
		time += delta
		var t := clampf(time / duration, 0.0, 1.0)
		var height := sin(t * PI) * 1.0
		_place_fox(ground + Vector3(0, height, 0), facing)
		fox.set_platform_motion(Vector3(0, cos(t * PI) * 4.0, 0), t >= 1.0, delta)
	for frame in range(10):
		await get_tree().process_frame
		fox.set_platform_motion(Vector3.ZERO, true, get_process_delta_time())
	_place_fox(ground, facing)
	return serial == _seq


func _begin_sequence() -> int:
	_seq += 1
	_skip = false
	busy = true
	math_room.finish_motion()
	word_room.finish_motion()
	syllable_room.finish_motion()
	reading_room.finish_motion()
	_stop_clap()
	_update_actions()
	return _seq


func _end_sequence(serial: int) -> void:
	if serial != _seq:
		return
	_skip = false
	busy = false
	_update_actions()
	_layout()


# ---------------------------------------------------------------- Mathe


## Kind tippt einen Apfel an: Er zählt sich mit (Zahl am Apfel).
func tap_apple(index: int) -> int:
	if busy or plan.kind != "holo_word_problem" or index < 0 or index >= math_room.apples.size():
		return 0
	if plan.slot_of[index] >= 0:
		plan.toggle_frame(index)
		math_room.to_home(index)
		events.append("apple_back:%d" % index)
		_frame_state()
		return 0
	var number: int = plan.count_apple(index)
	math_room.show_count(index, number)
	var group := 0 if index < int(plan.current().a) else 1
	var total: int = plan.group_count(group)
	var size := int(plan.current().a) if group == 0 else int(plan.current().b)
	if total == size:
		math_room.show_badge(group, ("Im Korb: %d" if group == 0 else "Dazu: %d") % size)
	events.append("count:%d=%d" % [index, number])
	return number


## Kind schiebt einen Apfel ins Zehnerfeld (nächstes freies Feld).
func move_apple_to_frame(index: int) -> int:
	if busy or plan.kind != "holo_word_problem" or index < 0 or index >= math_room.apples.size():
		return -1
	if plan.slot_of[index] >= 0:
		return plan.slot_of[index]
	var slot: int = plan.toggle_frame(index)
	if slot >= 0:
		math_room.to_slot(index, slot)
		events.append("frame:%d->%d" % [index, slot])
		_frame_state()
	return slot


func _frame_state() -> void:
	var filled: int = plan.frame_filled()
	var first_full := true
	for slot in range(10):
		if not plan.slot_of.has(slot):
			first_full = false
	math_room.show_ten(first_full)
	if first_full and filled > 10:
		feedback.text = "Das Zehnerfeld ist voll: 10. Daneben liegen %d." % (filled - 10)
	elif first_full:
		feedback.text = "Das Zehnerfeld ist voll: 10."


func choose(value: String) -> String:
	if busy or not valid or plan.kind != "holo_word_problem":
		events.append("answer_ignored:%s:busy=%s" % [value, busy])
		return "ignored"
	var outcome: String = plan.answer(value)
	events.append("answer:%s=%s" % [value, outcome])
	if outcome == "wrong":
		_after_wrong(value)
	elif outcome == "correct":
		_after_correct()
	return outcome


func _after_wrong(value: String) -> void:
	_teacher("encourage", camera.global_position)
	for button in choice_buttons:
		if button.text == value:
			button.disabled = true
	if plan.kind == "holo_word_problem":
		feedback.text = ("%s stimmt noch nicht." % value)
	if plan.phase == "twin":
		feedback.text += (
			" Tipp: Fülle zuerst das Zehnerfeld bis 10." if plan.kind == "holo_word_problem" else ""
		)
		return
	# Erster Fehler → Blick auf die Mengen, zweiter → ausführliche Hilfe.
	if plan.wrong == 1 and plan.hint_level == 0:
		request_hint()
	elif plan.wrong >= 2 and plan.hint_level < PLAN.HINT_FULL:
		while plan.hint_level < PLAN.HINT_FULL - 1:
			plan.request_hint()
		request_hint()
	else:
		_update_actions()


func _after_correct() -> void:
	var serial := _begin_sequence()
	_stop_speech()
	math_room.clear_pulse()
	word_room.clear_highlights()
	var task: Dictionary = plan.current()
	var focus := Vector3(0, 0.6, 0.5)
	if plan.kind == "holo_word_problem":
		feedback.text = "Richtig! Es sind %d Äpfel." % task.sum
		focus = math_room.frame_center()
		_mark_choice(str(task.sum))
	elif plan.mode == "verb":
		var verb: String = task.words[task.verbIndex]
		feedback.text = "Richtig! „%s“ ist das Tunwort. Es sagt, was jemand tut." % verb
		focus = word_room.field_spot()
	elif plan.mode == "noun":
		var noun: String = task.words[task.nounIndex]
		var article := _article_index(task)
		var named := "%s %s" % [str(task.words[article]).to_lower(), noun] if article >= 0 else noun
		feedback.text = "Richtig! „%s“ ist ein Namenwort: %s." % [noun, named]
		focus = word_room.field_spot()
	elif plan.mode == "adjective":
		var adjective: String = task.words[task.adjIndex]
		feedback.text = (
			"Richtig! „%s“ ist das Wiewort. Es sagt, %s." % [adjective, _how_clause(task)]
		)
		focus = word_room.field_spot()
	elif plan.mode == "syllables":
		var count: int = task.syllables.size()
		feedback.text = (
			"Richtig! „%s“ hat %s."
			% ["-".join(task.syllables), "eine Silbe" if count == 1 else "%d Silben" % count]
		)
		focus = syllable_room.global_position + Vector3(0, 1.2, 0)
	elif plan.mode == "reading":
		feedback.text = "Richtig! %s" % task.sentence
		focus = reading_room.plates[task.scenes.find(task.answer)].global_position
	else:
		feedback.text = "Richtig! „%s“" % task.sentence
	_teacher("celebrate", focus)
	if not low_effects:
		wonder.celebrate(focus)
	events.append("celebrate:%s" % plan.phase)
	if plan.phase == "done":
		_say(
			(
				"Super, das hast du ganz allein geschafft! Tippe auf „Zurück zur Aufgabe“ – "
				+ "dort wird dein Fortschritt gespeichert."
			)
		)
	elif plan.hint_level == 0 and plan.attempts == 1:
		_say("Stark! Wie hast du das gesehen? Jetzt kommt eine ähnliche Aufgabe für dich allein.")
	else:
		_say("Genau so! Jetzt probierst du eine ähnliche Aufgabe ganz allein.")
	if plan.kind == "holo_word_problem":
		await _show_math_solution(serial)
	elif plan.mode == "noun":
		# Erst jetzt erscheint das Ding/Tier als Hologramm über der Karte.
		await _wait(0.35, serial)
		word_room.show_picture(str(task.picture))
		events.append("picture:%s" % task.picture)
	elif plan.mode == "adjective":
		await _wait(0.35, serial)
		word_room.show_picture(str(task.picture), str(task.look))
		events.append("picture:%s:%s" % [task.picture, task.look])
	elif plan.mode == "syllables":
		# Die Karte teilt sich, Lumo klatscht das Wort im Takt.
		syllable_room.clear_tokens()
		await _clap_word(serial)
	elif plan.mode == "reading":
		reading_room.mark_right(task.scenes.find(task.answer))
	await _wait(0.6, serial)
	_end_sequence(serial)


## Die richtige Zahl bleibt sichtbar markiert (grün), die anderen gedimmt.
func _mark_choice(value: String) -> void:
	for button in choice_buttons:
		if button.text == value:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("3fbf7f")
			style.border_color = Color("d9ffe9")
			style.set_border_width_all(3)
			style.set_corner_radius_all(14)
			style.set_content_margin_all(8)
			button.add_theme_stylebox_override("disabled", style)
			button.add_theme_color_override("font_disabled_color", Color("06261a"))
			button.name = "RichtigeAntwort_%s" % value


## Nach der richtigen Antwort zeigt das Zwanzigerfeld die Lösung als
## Struktur (ein voller Zehner + Rest), auch wenn das Kind ohne Hilfe löste.
func _show_math_solution(serial: int) -> void:
	var task: Dictionary = plan.current()
	if math_room.ten_outline.visible and plan.frame_filled() == int(task.sum):
		return
	math_room.clear_counts()
	var layout: Array[int] = plan.ten_bridge_layout()
	for index in range(layout.size()):
		plan.slot_of[index] = layout[index]
		math_room.to_slot(index, layout[index], 0.4)
		if not await _wait(0.07, serial):
			return
	await _wait(0.4, serial)
	math_room.show_ten(true)
	math_room.show_parts(0, 0, int(task.sum) - 10)
	_teacher("explain", math_room.slot_position(int(task.sum) - 1))
	events.append("solution_shown")


func start_twin() -> bool:
	if busy or not plan.start_twin():
		return false
	_stop_speech()
	_start_phase()
	return true


## Hilfestufen in fester Reihenfolge.
func request_hint() -> int:
	if busy or not valid or plan.phase == "done":
		return plan.hint_level
	if plan.phase == "original" and plan.original_correct:
		return plan.hint_level
	var level: int = plan.request_hint()
	events.append("hint:%d:%s" % [level, plan.phase])
	if plan.kind == "holo_word_problem":
		if plan.phase == "twin":
			_math_twin_tip()
		elif level == PLAN.HINT_FOCUS:
			_math_focus_hint()
		else:
			_math_full_help()
	else:
		if plan.phase == "twin":
			_word_twin_tip()
		elif plan.mode == "syllables":
			if level == PLAN.HINT_FOCUS:
				_syllable_focus_hint()
			else:
				_syllable_full_help()
		elif plan.mode == "reading":
			if level == PLAN.HINT_FOCUS:
				_reading_focus_hint()
			else:
				_reading_full_help()
		elif level == PLAN.HINT_FOCUS:
			_word_focus_hint()
		else:
			_word_full_help()
	return level


func _math_focus_hint() -> void:
	var serial := _begin_sequence()
	var task: Dictionary = plan.current()
	var note := _take_feedback()
	_say(
		(
			note
			+ (
				(
					"Schau auf beide Mengen: %d Äpfel im Korb, %d habe ich dazugelegt. "
					% [task.a, task.b]
				)
				+ "Wie viele sind es zusammen?"
			)
		)
	)
	# Hochformat: in der Gasse zwischen beiden Mengen; Querformat: rechts neben
	# der Schale (der Weg führt nicht durch Schale oder Feld).
	var between := (
		Vector3((MATH.BASKET_AT.x + MATH.PLATE_AT.x) * 0.5, 0, -2.55)
		if _portrait()
		else Vector3(MATH.PLATE_AT.x + MATH.PLATE_RADIUS + FOX_HALF_WIDTH + 0.1, 0, MATH.PLATE_AT.z)
	)
	if await _walk_to(between, math_room.group_center(0), serial):
		math_room.pulse_group(0)
		math_room.show_badge(0, "Im Korb: %d" % task.a)
	if not await _wait(1.4, serial):
		return
	if await _walk_to(between + Vector3(0.05, 0, 0), math_room.group_center(1), serial):
		math_room.pulse_group(1)
		math_room.show_badge(1, "Dazu: %d" % task.b)
	if not await _wait(1.4, serial):
		return
	await _step_aside(serial)
	_end_sequence(serial)


## Ausführliche Hilfe: Zehnerbildung animiert, 8 + 5 = 10 + 3.
func _math_full_help() -> void:
	var serial := _begin_sequence()
	var task: Dictionary = plan.current()
	var a := int(task.a)
	var parts: Vector2i = plan.bridge_parts()
	math_room.clear_pulse()
	for index in range(plan.slot_of.size()):
		if plan.slot_of[index] >= 0:
			plan.toggle_frame(index)
			math_room.to_home(index, 0.25)
	var note := _take_feedback()
	math_room.clear_counts()
	math_room.clear_parts()
	await _wait(0.3, serial)
	_say(note + "Wir füllen das Zehnerfeld. Zuerst kommen die %d Äpfel aus dem Korb hinein." % a)
	await _walk_to(_math_point_spot(), math_room.frame_center(), serial)
	for index in range(a):
		plan.toggle_frame(index)
		math_room.to_slot(index, plan.slot_of[index], 0.4)
		if not await _wait(0.22, serial):
			return
	math_room.show_parts(a, 0, 0)
	if not await _wait(0.9, serial):
		return
	_say("Bis 10 fehlen noch %d. Ich nehme %d von meinen %d Äpfeln." % [parts.x, parts.x, task.b])
	for j in range(parts.x):
		var index := a + j
		plan.toggle_frame(index)
		math_room.mark_borrowed(index, true)
		math_room.show_path(
			math_room.apples[index].position, math_room.slot_position(plan.slot_of[index])
		)
		math_room.to_slot(index, plan.slot_of[index], 0.75)
		if not await _wait(0.6, serial):
			return
	math_room.show_parts(a, parts.x, 0)
	events.append("borrowed:%d" % parts.x)
	if not await _wait(1.0, serial):
		return
	math_room.show_ten(true)
	events.append("ten_complete")
	if not await _wait(1.0, serial):
		return
	_say("Das Zehnerfeld ist voll: 10. Von meinen %d Äpfeln bleiben %d übrig." % [task.b, parts.y])
	for j in range(parts.y):
		var index := a + parts.x + j
		plan.toggle_frame(index)
		math_room.to_slot(index, plan.slot_of[index], 0.45)
		if not await _wait(0.3, serial):
			return
	math_room.show_parts(0, 0, parts.y)
	if not await _wait(0.9, serial):
		return
	_say(
		(
			"%d + %d = %d + %d + %d = 10 + %d.\nWie viel ist 10 + %d? Tippe die Lösung an."
			% [a, task.b, a, parts.x, parts.y, parts.y, parts.y]
		)
	)
	feedback.text = "%d + %d = 10 + %d" % [a, task.b, parts.y]
	await _step_aside(serial)
	_end_sequence(serial)


## Rechts neben dem Zwanzigerfeld: Lumo zeigt, ohne Feld oder Zähler zu verdecken.
func _math_point_spot() -> Vector3:
	return Vector3(MATH.CELL * 2.5 + 0.2 + FOX_HALF_WIDTH + 0.15, 0, math_room.frame_center().z)


func _math_twin_tip() -> void:
	var serial := _begin_sequence()
	_say("Tipp: Leg die Äpfel aus dem Korb ins Zehnerfeld. Wie viele fehlen bis 10?")
	math_room.pulse_group(0)
	await _wait(1.2, serial)
	_end_sequence(serial)


# ---------------------------------------------------------------- Deutsch


func tap_card(index: int) -> void:
	if busy or plan.kind != "holo_sentence" or index < 0 or index >= word_room.cards.size():
		return
	var word: String = plan.current().words[index]
	if plan.mode != "order":
		word_room.select(index)
		events.append("select:%s" % word)
	else:
		if _demo_sentence:
			_demo_sentence = false
			for other in range(word_room.cards.size()):
				word_room.to_home(other)
		if plan.placed.has(index):
			plan.take_back(index)
			word_room.to_home(index)
			events.append("take_back:%s" % word)
		else:
			plan.place_card(index)
			word_room.to_slot(index, plan.placed.size() - 1)
			events.append("place:%s" % word)
		_reflow_slots()
	if _speech_enabled:
		_speak(word)
	_update_actions()


func _reflow_slots() -> void:
	for position_index in range(plan.placed.size()):
		word_room.to_slot(plan.placed[position_index], position_index)


func confirm() -> String:
	if busy or not valid or plan.kind != "holo_sentence":
		return "ignored"
	var task: Dictionary = plan.current()
	var value := ""
	if plan.mode == "syllables":
		return _confirm_claps()
	if plan.mode == "reading":
		return "ignored"
	if plan.mode != "order":
		if word_room.selected < 0:
			return "ignored"
		value = task.words[word_room.selected]
	else:
		if plan.placed.size() != task.words.size():
			return "ignored"
		value = plan.built_sentence()
	var chosen: int = word_room.selected
	var outcome: String = plan.answer(value)
	events.append("answer:%s=%s" % [value, outcome])
	if outcome == "wrong":
		var touched: Vector3 = word_room.cards[chosen].global_position if chosen >= 0 else word_room.field_spot()
		_teacher("encourage", touched)
		if plan.mode != "order":
			var kind_of: String = task.get("types", _types)[chosen]
			var help_table: Dictionary = (
				NOUN_HELP
				if plan.mode == "noun"
				else (ADJECTIVE_HELP if plan.mode == "adjective" else TYPE_HELP)
			)
			feedback.text = help_table.get(kind_of, help_table.andere) % value
			word_room.deselect()
		else:
			feedback.text = "So stimmt der Satz noch nicht."
		if plan.phase == "original":
			if plan.wrong == 1 and plan.hint_level == 0:
				request_hint()
			elif plan.wrong >= 2 and plan.hint_level < PLAN.HINT_FULL:
				while plan.hint_level < PLAN.HINT_FULL - 1:
					plan.request_hint()
				request_hint()
		_update_actions()
	elif outcome == "correct":
		if plan.mode != "order":
			word_room.to_field(chosen)
		_after_correct()
	return outcome


## Kind zieht eine Karte ins Antwortfeld: gleichbedeutend mit Wählen + Prüfen.
func drop_card_on_field(index: int) -> String:
	if busy or plan.kind != "holo_sentence" or plan.mode == "order":
		return "ignored"
	word_room.select(index)
	return confirm()


func _question() -> String:
	return str(plan.current().question)


func _word_focus_hint() -> void:
	var serial := _begin_sequence()
	var note := _take_feedback()
	var task: Dictionary = plan.current()
	var demo := str(task.demo)
	if plan.mode == "order":
		# Satzbau: eigener Hinweis zum Satzbau, ohne die Lösung zu nennen.
		_teacher("explain", word_room.global_position + Vector3(0, 0.7, 1.2))
		_say(
			(
				note
				+ "Wer tut etwas? Damit fängt der Satz an. "
				+ "Achte auf den großen Anfangsbuchstaben und den Punkt."
			)
		)
		events.append("order_hint")
	elif plan.mode == "noun":
		# Namenwort: Lumo fragt „Wer oder was?“, der Begleiter leuchtet.
		var article := _article_index(task)
		if article >= 0:
			await _walk_to(
				word_room.point_spot(article, FOX_HALF_WIDTH),
				word_room.cards[article].global_position,
				serial
			)
			word_room.highlight(article, 0.8, WORDS.HALO_HINT)
			events.append("article_glow:%s" % task.words[article])
			_say(
				(
					note
					+ (
						"Frag: Wer oder was? %s Der Begleiter „%s“ leuchtet – "
						% [_question(), task.words[article]]
					)
					+ "er gehört zum Namenwort."
				)
			)
		else:
			_say(note + "Frag: Wer oder was? %s" % _question())
		events.append("noun_hint")
	elif plan.mode == "adjective":
		# Wiewort: zwei gleiche Figuren, die sich in Größe oder Farbe
		# unterscheiden – ohne Beschriftung, ohne Hinweis auf eine Karte.
		word_room.show_contrast(str(task.picture), str(task.contrast), str(task.look))
		events.append("contrast:%s:%s" % [task.picture, task.contrast])
		_say(
			(
				note
				+ "Schau dir die zwei Figuren an. Sie sehen nicht gleich aus. "
				+ "Ein Wiewort sagt, wie etwas ist. %s" % _question()
			)
		)
		_teacher("explain", word_room.answer_field.global_position + Vector3(0, 0.6, 0))
	elif demo == "jump":
		# Lumo springt frei an seinem Platz neben den Karten.
		_say(note + "Schau mir zu!")
		_teacher("welcome", camera.global_position)
		await _wait(0.5, serial)
		await _jump(serial)
		_say("Ich bin gesprungen. %s" % _question())
	elif demo in ["wave", "nod"]:
		_teacher("welcome" if demo == "wave" else "encourage", camera.global_position)
		_say(note + "Schau, was ich mache. %s" % _question())
	else:
		_say(note + "Frag dich: %s Das Wort, das es sagt, ist das Tunwort." % _question())
		_teacher("explain", word_room.global_position + Vector3(0, 0.7, -0.3))
	if not await _wait(1.6, serial):
		return
	await _step_aside(serial)
	_end_sequence(serial)


## Begleiter (Artikel) vor dem gesuchten Namenwort, sonst -1.
func _article_index(task: Dictionary) -> int:
	var types: Array = task.get("types", [])
	for index in range(int(task.get("nounIndex", 0)) - 1, -1, -1):
		if index < types.size() and types[index] == "artikel":
			return index
	return -1


func _word_full_help() -> void:
	var serial := _begin_sequence()
	var task: Dictionary = plan.current()
	if plan.mode != "order":
		var target := int(
			{"noun": task.get("nounIndex", 0), "adjective": task.get("adjIndex", 0)}.get(
				plan.mode, task.verbIndex
			)
		)
		var word: String = task.words[target]
		var card: Node3D = word_room.cards[target]
		word_room.clear_highlights()
		var note := _take_feedback()
		if plan.mode == "noun":
			_say(note + "Namenwörter sagen, wer oder was. %s" % _question())
		elif plan.mode == "adjective":
			word_room.clear_contrast(true)
			_say(note + "Wiewörter sagen, wie jemand oder etwas ist. %s" % _question())
		else:
			_say(note + "Das Tunwort sagt, was jemand tut. %s" % _question())
		# Lumo geht seitlich an die Zeile der Karte und zeigt darauf.
		await _walk_to(word_room.point_spot(target, FOX_HALF_WIDTH), card.global_position, serial)
		if not await _wait(1.0, serial):
			return
		word_room.highlight(target, 0.9)
		if plan.mode == "adjective":
			events.append("show_adjective:%s" % word)
			_say(
				(
					"„%s“ sagt, %s. Also ist „%s“ das Wiewort. Tippe es an."
					% [word, _how_clause(task), word]
				)
			)
		elif plan.mode == "noun":
			events.append("show_noun:%s" % word)
			_say(
				(
					"„%s“ sagt, wer oder was. Also ist „%s“ das Namenwort – " % [word, word]
					+ "Namenwörter schreibt man groß. Tippe es an."
				)
			)
		else:
			events.append("show_verb:%s" % word)
			_say("%s Also ist „%s“ das Tunwort. Tippe es an." % [task.sentence, word])
		if not await _wait(1.4, serial):
			return
	else:
		for index in plan.placed.duplicate():
			plan.take_back(index)
			word_room.to_home(index)
		var note_order := _take_feedback()
		_say(note_order + "Ich lege den Satz einmal vor. Zuerst kommt, wer etwas tut.")
		_teacher("explain", word_room.global_position + Vector3(0, 0.7, -0.3))
		for index in range(task.words.size()):
			word_room.to_slot(index, index)
			if not await _wait(0.5, serial):
				return
		_say(
			(
				"„%s“ – großer Anfang, Punkt am Ende. Jetzt du: Leg den Satz noch einmal."
				% task.sentence
			)
		)
		events.append("show_sentence")
		if reduced_motion:
			# Ruhige Bewegung: Der vorgelegte Satz bleibt stehen, bis das Kind
			# die erste Karte antippt (sonst wäre er nie zu sehen).
			_demo_sentence = true
		else:
			if not await _wait(2.2, serial):
				return
			for index in range(task.words.size()):
				word_room.to_home(index)
	await _step_aside(serial)
	_end_sequence(serial)


## Tipp in der Zwillingsaufgabe: passend zur Aufgabenart, ohne Lösung.
func _word_twin_tip() -> void:
	var serial := _begin_sequence()
	match plan.mode:
		"order":
			_say("Tipp: Wer tut etwas? Damit fängt der Satz an. Der Punkt kommt ans Ende.")
		"noun":
			_say("Tipp: Frag: Wer oder was? %s" % _question())
		"adjective":
			_say("Tipp: Frag dich: Wie ist es? %s" % _question())
		"syllables":
			_say("Tipp: Sprich das Wort langsam. Bei jeder Silbe geht dein Mund auf.")
		"reading":
			_say("Tipp: Such im Satz das Wort, das sagt, wo etwas ist.")
		_:
			_say("Tipp: %s" % _question())
	await _wait(1.0, serial)
	_end_sequence(serial)


## „wie der Fuchs ist“ aus der Frage „Welches Wort sagt, wie der Fuchs ist?“.
func _how_clause(task: Dictionary) -> String:
	return str(task.question).trim_prefix("Welches Wort sagt, ").trim_suffix("?")


# ---------------------------------------------------------------- Silben


## Kind tippt „Klatschen“: eine Klatschmarke mehr auf der Leiste.
func clap_syllable() -> int:
	if busy or not valid or plan.mode != "syllables" or plan.phase == "done":
		return plan.claps
	if plan.phase == "original" and plan.original_correct:
		return plan.claps
	var before: int = plan.claps
	var count: int = plan.clap()
	if count == before:
		return count
	syllable_room.add_token(count)
	feedback.text = "Du hast %s geklatscht." % TIMES[count]
	events.append("clap:%d" % count)
	_update_actions()
	return count


## „Neu“: Klatschmarken weg, noch einmal klatschen.
func clear_claps() -> void:
	if busy or plan.mode != "syllables":
		return
	plan.clear_claps()
	syllable_room.clear_tokens()
	feedback.text = ""
	events.append("claps_cleared")
	_update_actions()


## Wortkarte antippen: Lumo liest das Wort vor (wenn Ton an), die Karte leuchtet.
func hear_word() -> void:
	if busy or plan.mode != "syllables":
		return
	syllable_room.flash_word()
	events.append("hear:%s" % plan.current().word)
	if _speech_enabled:
		_speak(str(plan.current().word))
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(syllable_room) and not busy:
		syllable_room.clear_glow()


func _confirm_claps() -> String:
	var count: int = plan.claps
	if count <= 0:
		return "ignored"
	var outcome: String = plan.answer(str(count))
	events.append("answer:%d=%s" % [count, outcome])
	if outcome == "wrong":
		_teacher("encourage", camera.global_position)
		plan.clear_claps()
		syllable_room.clear_tokens()
		feedback.text = "Du hast %s geklatscht. Das passt noch nicht." % TIMES[count]
		if plan.phase == "original":
			if plan.wrong == 1 and plan.hint_level == 0:
				request_hint()
			elif plan.wrong >= 2 and plan.hint_level < PLAN.HINT_FULL:
				while plan.hint_level < PLAN.HINT_FULL - 1:
					plan.request_hint()
				request_hint()
		else:
			feedback.text += " Sprich es langsam."
		_update_actions()
	elif outcome == "correct":
		_after_correct()
	return outcome


func _syllable_focus_hint() -> void:
	var serial := _begin_sequence()
	var note := _take_feedback()
	_teacher("encourage", camera.global_position)
	_say(
		(
			note
			+ "Sprich das Wort langsam. Bei jeder Silbe geht dein Mund auf. "
			+ "Klatsch bei jeder Silbe einmal."
		)
	)
	events.append("syllable_hint")
	if _speech_enabled:
		_speak(str(plan.current().word))
	await _wait(1.4, serial)
	_end_sequence(serial)


## Ausführliche Hilfe: Lumo spricht und klatscht das Wort Silbe für Silbe,
## die Karte teilt sich. Danach klatscht das Kind selbst.
func _syllable_full_help() -> void:
	var serial := _begin_sequence()
	var note := _take_feedback()
	var parts: Array = plan.current().syllables
	_say(note + "Hör und schau: Ich klatsche das Wort.")
	if not await _wait(0.8, serial):
		return
	await _clap_word(serial)
	if serial != _seq:
		return
	_say("%s. Jetzt klatschst du – bei jeder Silbe einmal." % " – ".join(parts))
	events.append("show_syllables")
	await _wait(1.0, serial)
	_end_sequence(serial)


## Lumo klatscht das Wort: je Silbe ein Klatscher mit den echten Armen, die
## Silbenkarte leuchtet im selben Takt. Ruhige Bewegung: Hände ruhig
## zusammen, die Karte steht gleich geteilt da.
func _clap_word(serial: int) -> void:
	var parts: Array = plan.current().syllables
	events.append("lumo_clap:%d" % parts.size())
	syllable_room.split()
	_teacher("encourage", camera.global_position)
	if _speech_enabled:
		_speak(" – ".join(parts))
	if clap == null:
		for index in range(parts.size()):
			syllable_room.pulse_syllable(index)
			if not await _wait(CLAP_BEAT, serial):
				return
		return
	clap.start(parts.size(), CLAP_BEAT, reduced_motion)
	var shown := 0
	while shown < clap.fired:
		syllable_room.pulse_syllable(shown)
		shown += 1
	while clap.is_clapping() and not reduced_motion and serial == _seq and is_inside_tree():
		if _skip:
			_stop_clap()
			break
		await get_tree().process_frame
		while shown < clap.fired:
			syllable_room.pulse_syllable(shown)
			events.append("lumo_clap_beat:%d" % shown)
			shown += 1
	syllable_room.clear_glow()


func _stop_clap() -> void:
	if clap != null and (clap.is_clapping() or clap.hold):
		clap.stop()


# ---------------------------------------------------------------- Lesen


## Kind tippt eine Szene an: Sie ist die Antwort.
func choose_scene(index: int) -> String:
	if busy or not valid or plan.mode != "reading" or index < 0:
		return "ignored"
	if index >= reading_room.plates.size():
		return "ignored"
	var value: String = plan.current().scenes[index]
	var outcome: String = plan.answer(value)
	events.append("answer:%s=%s" % [value, outcome])
	if outcome == "wrong":
		_teacher("encourage", camera.global_position)
		reading_room.mark_wrong(index)
		feedback.text = "Dieses Bild passt noch nicht zum Satz."
		if plan.phase == "original":
			if plan.wrong == 1 and plan.hint_level == 0:
				request_hint()
			elif plan.wrong >= 2 and plan.hint_level < PLAN.HINT_FULL:
				while plan.hint_level < PLAN.HINT_FULL - 1:
					plan.request_hint()
				request_hint()
		else:
			feedback.text += " Lies den Satz noch einmal."
		_update_actions()
	elif outcome == "correct":
		_after_correct()
	return outcome


func _reading_focus_hint() -> void:
	var serial := _begin_sequence()
	var note := _take_feedback()
	_say(note + "Lies den Satz noch einmal langsam, Wort für Wort. %s" % _question())
	events.append("reading_hint")
	await _walk_to(
		reading_room.point_spot(FOX_HALF_WIDTH),
		reading_room.strip.global_position + Vector3(0, 0.7, reading_room.strip.row_z[-1]),
		serial
	)
	if not await _wait(1.4, serial):
		return
	await _step_aside(serial)
	_end_sequence(serial)


## Ausführliche Hilfe: Das entscheidende Wort wird vorgelesen und leuchtet –
## keine Szene wird markiert.
func _reading_full_help() -> void:
	var serial := _begin_sequence()
	var note := _take_feedback()
	var task: Dictionary = plan.current()
	var key := int(task.keyIndex)
	var word: String = task.words[key]
	reading_room.clear_marks()
	_say(note + "Ein Wort im Satz sagt, wo es ist. Hör genau hin.")
	var card: Node3D = reading_room.strip.cards[key]
	await _walk_to(reading_room.point_spot(FOX_HALF_WIDTH), card.global_position, serial)
	if not await _wait(0.6, serial):
		return
	reading_room.strip.highlight(key, 0.9)
	events.append("key_word:%s" % word)
	_say("Das wichtige Wort ist „%s“. Welches Bild zeigt „%s“? Tippe es an." % [word, word])
	if _speech_enabled:
		_speak(word)
	if not await _wait(1.4, serial):
		return
	await _step_aside(serial)
	_end_sequence(serial)


# ---------------------------------------------------------------- Kamera & Layout


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
	var wide := available.x > available.y * 1.25
	prompt_label.add_theme_font_size_override("font_size", 19 if wide else 21)
	bubble_text.add_theme_font_size_override("font_size", 16 if wide else 18)
	var column := minf(available.x * 0.38, 440.0) if wide else minf(available.x, 760.0)
	# Hochformat: Sprechblase mit fester Höhe (schmal vier, breit drei Zeilen),
	# damit die Bühne nicht springt, wenn Lumo kürzer oder länger spricht.
	var lines := 4.0 if column < 500.0 else 3.0
	bubble_text.custom_minimum_size.y = (
		0.0 if wide else lines * bubble_text.get_line_height() + 12.0
	)
	for button in choice_buttons:
		if button != clap_button and button != reset_button:
			button.custom_minimum_size.x = 64 if wide else 76
	# Feste Zeilenzahl der Antwortleiste: Mathe im schmalen Hochformat zwei
	# Zeilen (Zahlen + Hilfe), sonst passt alles in eine.
	var rows := (
		2
		if (
			not wide
			and (plan.kind == "holo_word_problem" or plan.mode == "syllables")
			and column < 520.0
		)
		else 1
	)
	choice_bar.custom_minimum_size.y = rows * 56.0 + (rows - 1) * 8.0
	var left := origin.x if wide else origin.x + (available.x - column) * 0.5
	_place_feedback(wide, column)
	_fit(header, Vector2(left, origin.y), column)
	var below := origin.y + header.size.y + 6
	_fit(bubble, Vector2(left, below), column)
	var factor := scale_value
	if wide:
		# Querformat: links Aufgabe, Lumo und Rückmeldung; rechts die 3D-Fläche
		# über einer einzeiligen Antwortleiste mit fester Höhe.
		_fit(note_panel, Vector2(left, bubble.position.y + bubble.size.y + 6), column)
		var right := left + column + 10
		var right_width := origin.x + available.x - right
		_fit(footer, Vector2(right, 0), right_width)
		footer.position.y = origin.y + available.y - footer.size.y
		free_rect = Rect2(
			right * factor,
			origin.y * factor,
			right_width * factor,
			maxf(40.0, (footer.position.y - 6 - origin.y) * factor)
		)
	else:
		_fit(footer, Vector2(left, 0), column)
		footer.position.y = origin.y + available.y - footer.size.y
		var y0 := (bubble.position.y + bubble.size.y + 4) * factor
		var y1 := (footer.position.y - 4) * factor
		free_rect = Rect2(10 * factor, y0, dimensions.x - 20 * factor, maxf(40.0, y1 - y0))
	_fit_camera(true)


## Rückmeldung: im Hochformat oben in der Antwortleiste (zwei Zeilen fest
## reserviert), im Querformat als eigenes Feld links unter Lumos Text.
func _place_feedback(wide: bool, column: float) -> void:
	wide_layout = wide
	var home: Control = note_panel if wide else footer_box
	if feedback.get_parent() != home:
		feedback.get_parent().remove_child(feedback)
		home.add_child(feedback)
		if not wide:
			footer_box.move_child(feedback, 0)
	feedback.custom_minimum_size.y = 0.0 if wide else 50.0
	# Feste Umbruchbreite im eigenen Feld, sonst misst das Feld die Höhe mit
	# einer zu schmalen Zeile.
	feedback.custom_minimum_size.x = column - 24.0 if wide else 0.0
	feedback.max_lines_visible = -1 if wide else 2
	_sync_note_panel()


func _sync_note_panel() -> void:
	if is_instance_valid(note_panel):
		note_panel.visible = wide_layout and not feedback.text.is_empty()


func _fit(panel: PanelContainer, at: Vector2, width: float) -> void:
	# Feste Breite zuerst: Umbrechende Texte berechnen ihre Höhe aus ihr.
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	panel.position = at


func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_run_queued_layout.call_deferred()


func _run_queued_layout() -> void:
	_layout_queued = false
	_layout()


## Einzelne Kästen statt eines großen: Lumos Höhe gilt nur dort, wo Lumo steht.
func _content_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	if not valid:
		boxes.append(AABB(Vector3(-2, 0, -2), Vector3(4, 2.5, 3)))
	elif plan.kind == "holo_word_problem":
		boxes.assign(math_room.content_boxes())
	elif plan.mode == "syllables":
		boxes.assign(syllable_room.content_boxes())
	elif plan.mode == "reading":
		boxes.assign(reading_room.content_boxes())
	else:
		boxes.assign(word_room.content_boxes())
	# Lumo darf am Rand stehen, wird aber mit eingerahmt (Deutsch: samt
	# Sprunghöhe, damit er beim Tunwort-Sprung im Bild bleibt).
	var reach := FOX_HEIGHT + (1.0 if plan.kind == "holo_sentence" else 0.0)
	boxes.append(
		AABB(
			_fox_home + Vector3(-FOX_HALF_WIDTH, 0, -0.5), Vector3(FOX_HALF_WIDTH * 2.0, reach, 1.0)
		)
	)
	return boxes


func _content_box() -> AABB:
	var boxes := _content_boxes()
	var box: AABB = boxes[0]
	for other in boxes:
		box = box.merge(other)
	return box


## Rahmt den Inhalt genau in die freie Fläche zwischen den Bedienfeldern.
func _fit_camera(snap: bool) -> void:
	if not is_instance_valid(camera) or free_rect.size.x < 10 or free_rect.size.y < 10:
		return
	var parts := _content_boxes()
	var box := _content_box()
	var target := box.get_center()
	var pitch := deg_to_rad(50.0 if plan.kind == "holo_word_problem" else 34.0)
	var direction := Vector3(0, sin(pitch), cos(pitch))
	var distance := 14.0
	var shift := Vector2.ZERO
	var view := get_viewport().get_visible_rect().size
	var probe := Camera3D.new()
	probe.fov = camera.fov
	add_child(probe)
	for iteration in range(8):
		var position_value := target + direction * distance
		probe.global_transform = Transform3D(Basis.IDENTITY, position_value)
		probe.look_at(target)
		probe.global_position += probe.global_basis.x * shift.x + probe.global_basis.y * shift.y
		var rect := Rect2(probe.unproject_position(box.get_center()), Vector2.ZERO)
		for part in parts:
			for corner in range(8):
				rect = rect.expand(probe.unproject_position(part.get_endpoint(corner)))
		var goal := free_rect.grow(-maxf(8.0, free_rect.size.x * 0.015))
		var ratio := maxf(rect.size.x / goal.size.x, rect.size.y / goal.size.y)
		distance = clampf(distance * lerpf(1.0, ratio, 0.85), 5.0, 60.0)
		var world_per_px := 2.0 * distance * tan(deg_to_rad(probe.fov * 0.5)) / view.y
		var delta_px := rect.get_center() - goal.get_center()
		if _portrait():
			# Hochformat: Bühne oben an Lumos Text anlegen, kein leeres Band.
			delta_px.y = rect.position.y - goal.position.y
		shift += Vector2(delta_px.x, -delta_px.y) * world_per_px * 0.9
	probe.queue_free()
	var final_position := target + direction * distance
	var basis_probe := Transform3D(Basis.IDENTITY, final_position).looking_at(target)
	_cam_goal_position = (
		final_position + basis_probe.basis.x * shift.x + basis_probe.basis.y * shift.y
	)
	_cam_goal_target = target + basis_probe.basis.x * shift.x + basis_probe.basis.y * shift.y
	if snap or reduced_motion:
		camera.global_position = _cam_goal_position
		_cam_target = _cam_goal_target
		camera.look_at(_cam_target)


func _process(delta: float) -> void:
	if _first_frame_usec == 0:
		_first_frame_usec = Time.get_ticks_usec()
		print("[HoloLesson] first_frame_ms=%.1f" % ((_first_frame_usec - _ready_usec) / 1000.0))
	_sync_note_panel()
	if suspended:
		return
	_tick_speech(delta)


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
	var minimum := 63.0 * maxf(1.0, MobileRuntime.get_ui_density()) / 2.625
	minimum = maxf(minimum, 34.0)
	if pressed:
		_drag_finger = finger
		_drag_start = point
		_drag_moved = false
		_drag_index = pick(point)
	elif (
		moved
		and finger == _drag_finger
		and _drag_index >= 0
		and not busy
		and plan.mode not in ["syllables", "reading"]
	):
		if point.distance_to(_drag_start) > 16.0 * maxf(1.0, MobileRuntime.get_ui_density()):
			_drag_moved = true
			_drag_preview(point)
	elif released and finger == _drag_finger:
		if _drag_index >= 0:
			if plan.mode == "syllables":
				hear_word()
			elif plan.mode == "reading":
				choose_scene(_drag_index)
			elif _drag_moved:
				_drop(point)
			elif plan.kind == "holo_word_problem":
				tap_apple(_drag_index)
			else:
				tap_card(_drag_index)
			get_viewport().set_input_as_handled()
		_drag_finger = -1
		_drag_index = -1


## Treffer am Material; großzügige Zielgröße (≥ 126 px bei Fold-Dichte).
func pick(point: Vector2) -> int:
	var minimum := 126.0 * MobileRuntime.get_ui_density() / 2.625
	if plan.kind == "holo_word_problem":
		return math_room.pick(camera, point, minimum * 0.5)
	if plan.mode == "syllables":
		return 0 if syllable_room.hits_word(camera, point) else -1
	if plan.mode == "reading":
		return reading_room.pick(camera, point)
	return word_room.pick(camera, point, minimum)


func _drag_preview(point: Vector2) -> void:
	if plan.kind == "holo_word_problem":
		var spot: Variant = math_room.floor_point(camera, point, 0.5)
		if spot != null:
			math_room.apples[_drag_index].position = spot
	else:
		var spot_card: Variant = word_room.floor_point(camera, point, 0.9)
		if spot_card != null:
			word_room.cards[_drag_index].position = spot_card


func _drop(point: Vector2) -> void:
	if plan.kind == "holo_word_problem":
		if math_room.frame_hit(camera, point):
			if plan.slot_of[_drag_index] >= 0:
				math_room.to_slot(_drag_index, plan.slot_of[_drag_index])
			else:
				move_apple_to_frame(_drag_index)
		else:
			if plan.slot_of[_drag_index] >= 0:
				plan.toggle_frame(_drag_index)
				_frame_state()
			math_room.to_home(_drag_index)
	elif plan.mode != "order":
		if word_room.field_hit(camera, point):
			drop_card_on_field(_drag_index)
		else:
			word_room.to_home(_drag_index)
	else:
		if not plan.placed.has(_drag_index):
			tap_card(_drag_index)
		else:
			_reflow_slots()


# ---------------------------------------------------------------- Sprache


func _voice_action() -> void:
	_speak(prompt_label.text + " " + bubble_text.text)


func _speak(words: String) -> void:
	if not _speech_enabled or suspended or not is_instance_valid(_speech_host):
		return
	if not HostBridge.supports_method(_speech_host, "speakLearning"):
		return
	_stop_speech()
	var spoken := (
		words
		. replace(" + ", " plus ")
		. replace(" = ", " ist ")
		. replace("\n", " ")
		. replace("„", "")
		. replace("“", "")
	)
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
	_audio_scope = companion_scope.envelope(0, "holo-%d" % _speech_id)
	var request := _audio_scope.duplicate(true)
	request.merge(
		{"id": _speech_id, "text": _speech_segments[0], "rate": _speech_rate, "style": "explain"}
	)
	var accepted: Variant = _speech_host.call("speakLearning", JSON.stringify(request))
	_speech_state = "preparing" if HostBridge.durable_ack(accepted) else "unavailable"
	_update_actions()


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
	if is_instance_valid(stop_button):
		stop_button.visible = false


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
	var audible: bool = state == "playing" and received.get("audible", false) == true
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_teacher_speaking(audible)
	if state == "completed":
		_speech_segments.pop_front()
		if not _speech_segments.is_empty():
			_start_segment()
	stop_button.visible = _speech_state in ["preparing", "playing"]


# ---------------------------------------------------------------- Rückkehr


## Genau eine Rückgabe je Raum: Zusammenfassung mit Ergebnis, Hilfegrad und
## ähnlicher Aufgabe. Die App bucht daraus einmal (Ergebnis-ID).
func return_to_lesson() -> void:
	_stop_speech()
	if return_count > 0:
		return
	var summary: Dictionary = plan.summary(HostBridge.new_result_id()) if valid else {}
	var payload := {"status": "illustrated", "game": "learning"}
	if valid:
		payload["holo"] = summary
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
		if clap != null:
			clap.suspended = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		suspended = false
		if is_instance_valid(wonder):
			wonder.set_paused(false)
		if is_instance_valid(fox):
			fox.set_suspended(false)
		if clap != null:
			clap.suspended = false


func _exit_tree() -> void:
	_seq += 1
	_stop_speech()
	if EventBus.quality_profile_changed.is_connected(_on_quality_profile_changed):
		EventBus.quality_profile_changed.disconnect(_on_quality_profile_changed)
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	get_tree().auto_accept_quit = _original_auto_quit
	get_tree().quit_on_go_back = _original_back_quit
	get_window().content_scale_mode = _original_scale_mode
