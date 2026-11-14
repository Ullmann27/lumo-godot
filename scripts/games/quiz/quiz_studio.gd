extends Node3D
## Native presentation of QuizTableSession. The Dart host exclusively owns the
## question bank, correct answers, jokers, persistence, profile and wallet.
## No QA oracle, saved round or reward API is read or written by this scene.
const LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const LAYOUT_OBSERVATION := "user://quiz_layout_v1.json"
const SUBJECTS := ["alle", "Deutsch", "Mathe", "Sachunterricht"]
const JOKERS := ["fiftyFifty", "audience", "callLumo"]
const LETTERS := ["A", "B", "C", "D"]
const STATE_KEYS := ["schema", "game", "token", "roundId", "owner", "revision", "ack", "rejected", "recordRevision",
	"paused", "exit", "reduceMotion", "subject", "grade", "number", "total", "questionSubject", "prompt", "options",
	"selected", "revealed", "gameOver", "won", "correctIndex", "explanation", "hidden", "usedJokers", "audience", "hint",
	"securedStars", "awardedStars", "rewarded", "error", "canSelect", "canReveal", "canNext"]
const INK := Color("172b45")
const CREAM := Color("fff5dc")
const GOLD := Color("ffc75d")
const CYAN := Color("6cd9e7")

var _host: Object
var _token := ""
var _state: Dictionary = {}
var _authority_ready := false
var _sequence := 0
var _pending := 0
var _exit_sequence := 0
var _closed := false
var _poll := 0.0
var _previous: Dictionary = {}
var _safe_rect := Rect2()
var _stage_rect := Rect2()
var _density := 1.0
var _layout_dirty := true
var _layout_frames := 3
var _layout_sequence := 0
var _layout_retry := 0
var _last_question := ""
var _last_feedback := ""
var _theme: Theme
var _lights: Array[MeshInstance3D] = []
var _dim_material: StandardMaterial3D
var _lit_material: StandardMaterial3D

var camera: Camera3D
var fox
var ui: Control
var safe: Control
var header: PanelContainer
var body: PanelContainer
var content_scroll: ScrollContainer
var content: VBoxContainer
var title: Label
var progress: Label
var prompt: Label
var answers: GridContainer
var feedback: Label
var hint: Label
var status: Label
var menu: VBoxContainer
var menu_heading: Label
var return_button: Button
var pause_button: Button
var reveal_button: Button
var next_button: Button
var resume_button: Button
var restart_button: Button
var answer_buttons: Array[Button] = []
var answer_labels: Array[Label] = []
var joker_buttons: Array[Button] = []
var subject_buttons: Array[Button] = []


func _ready() -> void:
	var window := get_window()
	_previous = {"scale": window.content_scale_size, "mode": window.content_scale_mode, "aspect": window.content_scale_aspect,
		"quit": get_tree().quit_on_go_back, "accept": get_tree().auto_accept_quit,
		"orientation": DisplayServer.screen_get_orientation()}
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# Integer logical dp sizes must expand to the whole physical surface. KEEP
	# can letterbox one pixel at fractional Android density (e.g. 2400/2.625).
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().quit_on_go_back = false
	get_tree().auto_accept_quit = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	if _host == null and Engine.has_singleton("LumoHost"):
		_host = Engine.get_singleton("LumoHost")
	_token = str(HostBridge.launch_options().get("tableToken", ""))
	_build_studio()
	_build_ui()
	window.size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	_layout()
	_poll_state()


func _exit_tree() -> void:
	_closed = true
	_remove_observation()
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)
	if get_window().size_changed.is_connected(_layout):
		get_window().size_changed.disconnect(_layout)
	if not _previous.is_empty():
		get_window().content_scale_size = _previous.scale
		get_window().content_scale_mode = _previous.mode
		get_window().content_scale_aspect = _previous.aspect
		get_tree().quit_on_go_back = _previous.quit
		get_tree().auto_accept_quit = _previous.accept
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(_previous.orientation)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_send("pause")


func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.08:
		_poll = 0.0
		_poll_state()
	_publish_layout_observation()


func _poll_state() -> void:
	if _closed:
		return
	if not is_instance_valid(_host) or not _host.has_method("getTableState"):
		_lose_authority()
		return
	var raw: Variant = JSON.parse_string(str(_host.call("getTableState")))
	if not raw is Dictionary or not apply_state(raw):
		_lose_authority()


func _lose_authority() -> void:
	if _authority_ready:
		_authority_ready = false
		_mark_layout_changed()
		_update_ui()


func _integer(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= lo and float(value) <= hi


func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _text(value: Variant, maximum: int, allow_empty: bool = false) -> bool:
	return value is String and value.length() <= maximum and (allow_empty or not value.strip_edges().is_empty())


func _valid_state(value: Dictionary) -> bool:
	if value.size() != STATE_KEYS.size():
		return false
	for key in STATE_KEYS:
		if not value.has(key):
			return false
	if value.get("schema") != 1 or value.get("game") != "quiz" or value.get("token") != _token or not _hex(_token, 32):
		return false
	if not _hex(value.get("roundId"), 32) or not _hex(value.get("owner"), 64):
		return false
	for key in ["revision", "recordRevision"]:
		if not _integer(value.get(key), 1, 1000000000):
			return false
	for key in ["ack", "rejected"]:
		if not _integer(value.get(key), 0, 1000000000):
			return false
	for key in ["paused", "exit", "reduceMotion", "revealed", "gameOver", "won", "rewarded", "canSelect", "canReveal", "canNext"]:
		if not value.get(key) is bool:
			return false
	if value.get("subject") not in SUBJECTS or not _integer(value.get("grade"), 1, 4):
		return false
	if not _integer(value.get("total"), 20, 20) or not _integer(value.get("number"), 1, 20):
		return false
	if not _text(value.get("questionSubject"), 100) or not _text(value.get("prompt"), 1500):
		return false
	if not value.get("options") is Array or value.options.size() != 4:
		return false
	for option in value.options:
		if not _text(option, 800):
			return false
	if value.get("selected") != null and not _integer(value.selected, 0, 3):
		return false
	if bool(value.revealed):
		if not _integer(value.get("correctIndex"), 0, 3) or (value.get("explanation") != null and not _text(value.explanation, 2000, true)):
			return false
	elif value.get("correctIndex") != null or value.get("explanation") != null:
		# A premature answer must never become visible even if a bridge is faulty.
		return false
	if not value.get("hidden") is Array or value.hidden.size() > 2:
		return false
	var hidden: Array = []
	for option in value.hidden:
		if not _integer(option, 0, 3) or int(option) in hidden:
			return false
		hidden.append(int(option))
	if not value.get("usedJokers") is Array or value.usedJokers.size() > 3:
		return false
	var used: Array = []
	for joker in value.usedJokers:
		if joker not in JOKERS or joker in used:
			return false
		used.append(joker)
	if value.get("audience") != null:
		if not value.audience is Array or value.audience.size() != 4:
			return false
		var total_votes := 0
		for votes in value.audience:
			if not _integer(votes, 0, 100):
				return false
			total_votes += int(votes)
		if total_votes != 100:
			return false
	for key in ["hint", "error"]:
		if value.get(key) != null and not _text(value[key], 2000, true):
			return false
	for key in ["securedStars", "awardedStars"]:
		if not _integer(value.get(key), 0, 5000):
			return false
	if (value.paused or value.exit or value.gameOver) and (value.canSelect or value.canReveal or value.canNext):
		return false
	if value.canReveal and (value.selected == null or value.revealed):
		return false
	if value.canNext and not value.revealed:
		return false
	if value.canSelect and value.revealed:
		return false
	return true


func apply_state(value: Dictionary) -> bool:
	if not _valid_state(value):
		return false
	if not _state.is_empty():
		if value.owner != _state.owner or int(value.revision) < int(_state.revision):
			return false
		if int(value.revision) == int(_state.revision) and value != _state:
			return false
		if int(value.ack) < int(_state.ack) or int(value.rejected) < int(_state.rejected):
			return false
		if value.roundId == _state.roundId and int(value.recordRevision) < int(_state.recordRevision):
			return false
	var changed := value != _state or not _authority_ready
	_state = value.duplicate(true)
	_authority_ready = true
	_sequence = maxi(_sequence, maxi(int(value.ack), int(value.rejected)))
	if _pending > 0 and _pending <= maxi(int(value.ack), int(value.rejected)):
		_pending = 0
	if changed:
		_mark_layout_changed()
		_sync_studio()
		_update_ui()
	if value.exit and _pending == 0 and _exit_sequence > 0 and int(value.ack) >= _exit_sequence:
		# returnToApp is requested only after this exact exit was durably ACKed.
		_closed = HostBridge.durable_ack(_host.call("returnToApp", "games", "")) if is_instance_valid(_host) else false
		if _closed:
			_remove_observation()
	return true


func _option_hidden(option: int) -> bool:
	# JSON numbers are floats in Godot. _valid_state already requires unique
	# whole indices; compare their validated integer values without changing
	# the authoritative state or its original numeric representation.
	for hidden in _state.hidden:
		if int(hidden) == option:
			return true
	return false


func _allowed(action: String, extras: Dictionary) -> bool:
	match action:
		"select":
			return bool(_state.canSelect) and extras.size() == 1 and _integer(extras.get("option"), 0, 3) and not _option_hidden(int(extras.option))
		"reveal":
			return bool(_state.canReveal) and extras.is_empty()
		"next":
			return bool(_state.canNext) and extras.is_empty()
		"joker":
			return bool(_state.canSelect) and extras.size() == 1 and extras.get("joker") in JOKERS and extras.joker not in _state.usedJokers
		"pause":
			return not bool(_state.paused) and extras.is_empty()
		"resume":
			return bool(_state.paused) and extras.is_empty()
		"exit":
			return extras.is_empty()
		"restart":
			return (bool(_state.paused) or bool(_state.gameOver)) and extras.is_empty()
		"subject":
			return (bool(_state.paused) or bool(_state.gameOver)) and extras.size() == 1 and extras.get("subject") in SUBJECTS
	return false


func _send(action: String, extras: Dictionary = {}) -> bool:
	if _closed or not _authority_ready or _pending > 0 or _sequence >= 1000000000 or _state.is_empty() or bool(_state.exit) or not is_instance_valid(_host) or not MobileRuntime.safe_area_is_ready():
		return false
	if not _allowed(action, extras) or not _host.has_method("submitTableAction"):
		return false
	_sequence += 1
	var request := {"token": _token, "roundId": _state.roundId, "revision": int(_state.revision), "sequence": _sequence, "action": action}
	request.merge(extras)
	if not HostBridge.durable_ack(_host.call("submitTableAction", JSON.stringify(request))):
		status.text = "Eingabe noch nicht angenommen. Bitte erneut versuchen."
		return false
	_pending = _sequence
	if action == "exit":
		_exit_sequence = _sequence
	_mark_layout_changed()
	_update_ui()
	return true


func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _mesh(mesh: Mesh, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _build_studio() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10283f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5dfec")
	environment.ambient_light_energy = 0.56
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, -26, 0)
	key.light_color = Color("fff0da")
	key.light_energy = 1.0
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 3, 3)
	rim.light_color = CYAN
	rim.light_energy = 0.4
	rim.omni_range = 9
	add_child(rim)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(40, 0.18, 20)
	_mesh(floor_mesh, Vector3(0, -0.25, -1), _material(Color("183d55")))
	var podium := CylinderMesh.new()
	podium.top_radius = 1.55
	podium.bottom_radius = 1.65
	podium.height = 0.28
	podium.radial_segments = 48
	var stage := _mesh(podium, Vector3(0, -0.02, 0), _material(Color("24637a")))
	stage.name = "StudioPodium"
	var ring := TorusMesh.new()
	ring.inner_radius = 2.12
	ring.outer_radius = 2.22
	ring.rings = 48
	ring.ring_segments = 8
	var arch := _mesh(ring, Vector3(0, 1.75, -0.45), _material(CYAN, 0.2))
	arch.rotation.x = PI / 2.0
	arch.name = "StudioArch"
	_dim_material = _material(Color("35556b"))
	_lit_material = _material(GOLD, 0.25)
	for i in range(20):
		var angle := PI * 0.13 + float(i) / 19.0 * PI * 0.74
		var light_mesh := SphereMesh.new()
		light_mesh.radius = 0.10
		light_mesh.height = 0.20
		light_mesh.radial_segments = 12
		light_mesh.rings = 6
		var light := _mesh(light_mesh, Vector3(-cos(angle) * 2.2, 1.65 + sin(angle) * 2.2, -0.28), _dim_material)
		light.name = "AcknowledgedQuestion%02d" % (i + 1)
		_lights.append(light)
	fox = LUMO.new()
	fox.name = "OriginalLumo"
	fox.scale = Vector3.ONE * 1.55
	fox.position = Vector3(0, 0.12, 0.12)
	fox.rotation.y = 0.08
	add_child(fox)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	add_child(camera)


func _sync_studio() -> void:
	for i in range(_lights.size()):
		_lights[i].material_override = _lit_material if i < int(_state.number) else _dim_material
	var question_key := str(_state.roundId) + ":" + str(_state.number)
	if question_key != _last_question:
		_last_question = question_key
		content_scroll.scroll_vertical = 0
		_last_feedback = ""
	if not is_instance_valid(fox):
		return
	fox.reduced_motion = bool(_state.reduceMotion)
	fox.suspended = bool(_state.paused) or not _authority_ready
	if bool(_state.revealed) and _last_feedback != question_key and fox.is_usable():
		_last_feedback = question_key
		fox.play_behavior("celebrate" if _state.selected == _state.correctIndex else "agree_nod")


func _panel(color: Color, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(caption: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(52, 52)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(callback)
	return button


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.name = "QuizStudioUI"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_theme = Theme.new()
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", CREAM)
	_theme.set_color("font_color", "Button", CREAM)
	_theme.set_color("font_disabled_color", "Button", Color("d5e1e7"))
	_theme.set_stylebox("normal", "Button", _panel(Color("28536c"), 12))
	_theme.set_stylebox("hover", "Button", _panel(Color("346b82"), 12))
	_theme.set_stylebox("pressed", "Button", _panel(Color("357d91"), 12))
	_theme.set_stylebox("disabled", "Button", _panel(Color("263c50"), 12))
	ui.theme = _theme
	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(safe)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel(Color("122c45f5")))
	safe.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	header.add_child(row)
	return_button = _button("Zurück", _send.bind("exit"))
	return_button.name = "BackToFlutter"
	row.add_child(return_button)
	title = _label("Lumos Quizshow", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	pause_button = _button("Pause", _send.bind("pause"))
	pause_button.name = "Pause"
	row.add_child(pause_button)
	body = PanelContainer.new()
	body.name = "QuestionPanel"
	body.add_theme_stylebox_override("panel", _panel(Color("122c45f8"), 20))
	safe.add_child(body)
	content_scroll = ScrollContainer.new()
	content_scroll.name = "QuizContentScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _mark_layout_changed())
	body.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	content_scroll.add_child(content)
	progress = _label("Deine Runde wird verbunden …", 16)
	progress.add_theme_color_override("font_color", CYAN)
	content.add_child(progress)
	prompt = _label("Gleich geht es los.", 23)
	content.add_child(prompt)
	answers = GridContainer.new()
	answers.columns = 1
	answers.add_theme_constant_override("h_separation", 8)
	answers.add_theme_constant_override("v_separation", 8)
	content.add_child(answers)
	for i in range(4):
		var button := _button("", _send.bind("select", {"option": i}))
		button.name = "Answer%d" % i
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(80, 64)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 12)
		button.add_child(margin)
		var label := _label(LETTERS[i], 19)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		margin.add_child(label)
		answers.add_child(button)
		answer_buttons.append(button)
		answer_labels.append(label)
	reveal_button = _button("Antwort aufdecken", _send.bind("reveal"))
	reveal_button.name = "RevealAnswer"
	content.add_child(reveal_button)
	next_button = _button("Nächste Frage", _send.bind("next"))
	next_button.name = "NextQuestion"
	content.add_child(next_button)
	feedback = _label("", 20)
	content.add_child(feedback)
	var joker_row := HFlowContainer.new()
	joker_row.add_theme_constant_override("h_separation", 6)
	joker_row.add_theme_constant_override("v_separation", 6)
	content.add_child(joker_row)
	var captions := ["50:50", "Publikum", "Lumos Tipp"]
	for i in range(3):
		var button := _button(captions[i], _send.bind("joker", {"joker": JOKERS[i]}))
		button.name = "Joker" + str(JOKERS[i])
		joker_row.add_child(button)
		joker_buttons.append(button)
	hint = _label("", 18)
	hint.add_theme_color_override("font_color", Color("e3eecb"))
	content.add_child(hint)
	status = _label("", 16)
	content.add_child(status)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	content.add_child(menu)
	menu_heading = _label("", 21)
	menu.add_child(menu_heading)
	resume_button = _button("Fortsetzen", _send.bind("resume"))
	resume_button.name = "ResumeQuiz"
	menu.add_child(resume_button)
	restart_button = _button("Neue Runde", _send.bind("restart"))
	restart_button.name = "RestartQuiz"
	menu.add_child(restart_button)
	menu.add_child(_label("Fach für eine neue Runde", 16))
	for subject in SUBJECTS:
		var button := _button("Alle Fächer" if subject == "alle" else str(subject), _send.bind("subject", {"subject": subject}))
		button.name = "Subject" + str(subject)
		menu.add_child(button)
		subject_buttons.append(button)
	_update_ui()


func _layout() -> void:
	if not is_instance_valid(ui) or not is_inside_tree():
		return
	_mark_layout_changed()
	_density = MobileRuntime.get_ui_density()
	get_window().content_scale_size = Vector2i(Vector2(get_window().size) / _density)
	var logical := Vector2(get_window().content_scale_size)
	var insets := Rect2()
	if OS.has_feature("mobile") or MobileRuntime.requires_safe_area_observation():
		insets = MobileRuntime.get_safe_area_insets()
	var factor := logical / Vector2(get_window().size)
	_safe_rect = Rect2(insets.position * factor, logical - (insets.position + insets.size) * factor)
	safe.position = _safe_rect.position
	safe.size = _safe_rect.size
	safe.visible = MobileRuntime.safe_area_is_ready()
	var width := safe.size.x
	var height := safe.size.y
	header.position = Vector2(8, 6)
	header.size = Vector2(maxf(1, width - 16), 72)
	title.add_theme_font_size_override("font_size", 17 if width < 400 else 21)
	var wide := width >= 640 and width > height * 1.15
	if wide:
		var stage_width := clampf(width * 0.35, 190, 380)
		_stage_rect = Rect2(safe.position + Vector2(8, 84), Vector2(stage_width - 16, maxf(1, height - 92)))
		body.position = Vector2(stage_width, 84)
		body.size = Vector2(maxf(1, width - stage_width - 8), maxf(1, height - 92))
	else:
		var stage_height := clampf(height * 0.25, 92, 190)
		_stage_rect = Rect2(safe.position + Vector2(8, 82), Vector2(width - 16, stage_height))
		body.position = Vector2(8, 88 + stage_height)
		body.size = Vector2(maxf(1, width - 16), maxf(1, height - 96 - stage_height))
	answers.columns = 2 if body.size.x >= 530 else 1
	var world_per_pixel := maxf(4.9 / maxf(1, _stage_rect.size.x), 4.5 / maxf(1, _stage_rect.size.y))
	camera.size = world_per_pixel * logical.y
	var shift := (_stage_rect.get_center() - logical * 0.5) * world_per_pixel
	var tilt := Vector3(-0.04, 0.0, 0)
	camera.rotation = tilt
	camera.position = Vector3(0, 1.9, 0) + Basis.from_euler(tilt) * Vector3(-shift.x, shift.y, 15)
	call_deferred("_fit_answer_heights")
	_update_ui()


func _fit_answer_heights() -> void:
	if not is_inside_tree() or not is_instance_valid(answers):
		return
	# Labels wrap inside real Button children. Their measured font height grows
	# the button instead of clipping a long answer or shrinking its touch area.
	var available := maxf(60, (body.size.x - 40.0 - (answers.columns - 1) * 8.0) / answers.columns - 24.0)
	for i in range(answer_buttons.size()):
		var font := answer_labels[i].get_theme_font("font")
		var font_size := answer_labels[i].get_theme_font_size("font_size")
		var text_size := font.get_multiline_string_size(answer_labels[i].text, HORIZONTAL_ALIGNMENT_LEFT, available, font_size)
		answer_buttons[i].custom_minimum_size.y = maxf(64, text_size.y + 24)
	_mark_layout_changed()


func _update_ui() -> void:
	if not is_instance_valid(status):
		return
	var ready := _authority_ready and not _state.is_empty() and not _closed
	var waiting := _pending > 0
	var paused := bool(_state.get("paused", true))
	var finished := bool(_state.get("gameOver", false))
	var revealed := bool(_state.get("revealed", false))
	return_button.disabled = not ready or waiting
	pause_button.disabled = not ready or waiting or paused
	for button in answer_buttons:
		button.disabled = true
	for button in joker_buttons:
		button.disabled = true
	reveal_button.disabled = true
	next_button.disabled = true
	resume_button.disabled = not ready or waiting
	restart_button.disabled = not ready or waiting or (finished and not bool(_state.get("rewarded", false)))
	for button in subject_buttons:
		button.disabled = restart_button.disabled
	menu.visible = ready and (paused or finished)
	answers.visible = ready and not paused
	prompt.visible = ready and not paused
	reveal_button.visible = ready and not paused and not revealed and not finished
	next_button.visible = ready and not paused and revealed and not finished
	feedback.visible = ready and revealed and not paused
	hint.visible = ready and not paused
	for button in joker_buttons:
		button.visible = ready and not paused and not finished and not revealed
	if is_instance_valid(fox):
		fox.suspended = paused or not ready
	if not ready:
		progress.text = "Die Spielverbindung wird geprüft …"
		status.text = "Bitte kurz warten. Deine Eingaben bleiben gesperrt, bis die gespeicherte Runde bestätigt ist."
		return
	progress.text = "Frage %d von %d · %s · Stufe %d" % [int(_state.number), int(_state.total), str(_state.questionSubject), int(_state.grade)]
	prompt.text = str(_state.prompt)
	for i in range(4):
		var option_hidden: bool = _option_hidden(i)
		var caption: String = LETTERS[i] + "  " + ("Ausgeblendet" if option_hidden else str(_state.options[i]))
		if _state.audience is Array and not option_hidden:
			caption += "  ·  Publikum: %d %%" % int(_state.audience[i])
		answer_labels[i].text = caption
		answer_buttons[i].tooltip_text = caption
		answer_buttons[i].disabled = waiting or not bool(_state.canSelect) or option_hidden
		var color := Color("294d66")
		if _state.selected != null and i == int(_state.selected):
			color = Color("7b591f")
		if revealed and i == int(_state.correctIndex):
			color = Color("245e4a")
		elif revealed and _state.selected != null and i == int(_state.selected):
			color = Color("794946")
		for variant in ["normal", "hover", "pressed", "disabled"]:
			answer_buttons[i].add_theme_stylebox_override(variant, _panel(color, 12))
	reveal_button.disabled = waiting or not bool(_state.canReveal)
	next_button.disabled = waiting or not bool(_state.canNext)
	for i in range(3):
		joker_buttons[i].disabled = waiting or not bool(_state.canSelect) or JOKERS[i] in _state.usedJokers
	feedback.text = ""
	if revealed:
		var verdict: String = "Richtig!" if _state.selected == _state.correctIndex else "Die richtige Antwort ist " + LETTERS[int(_state.correctIndex)] + "."
		var explanation: String = _state.explanation if _state.explanation is String else ""
		feedback.text = verdict + ("\n" + explanation if not explanation.is_empty() else "")
	hint.text = "Lumos Tipp: " + str(_state.hint) if _state.hint != null else ""
	hint.visible = hint.visible and not hint.text.is_empty()
	status.text = "Anfrage gesendet. Speichern wird bestätigt …" if waiting else "Gesichert: %d Sterne" % int(_state.securedStars)
	if _state.error != null:
		status.text = str(_state.error)
	elif finished:
		status.text = "%d Sterne %s" % [int(_state.awardedStars), "gutgeschrieben" if _state.rewarded else "– Gutschrift wird noch bestätigt"]
	menu_heading.text = "Runde beendet" if finished else "Spiel pausiert"
	if finished and bool(_state.won):
		menu_heading.text = "Alle 20 Fragen geschafft!"
	resume_button.visible = paused
	resume_button.text = "Speichern wiederholen" if finished and not bool(_state.rewarded) else "Antwort ansehen" if finished else "Fortsetzen"
	call_deferred("_fit_answer_heights")


func _remove_observation() -> void:
	DirAccess.remove_absolute(LAYOUT_OBSERVATION)
	DirAccess.remove_absolute(LAYOUT_OBSERVATION + ".tmp")


func _mark_layout_changed() -> void:
	DirAccess.remove_absolute(LAYOUT_OBSERVATION)
	_layout_dirty = true
	_layout_frames = 3


func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _control_pixels(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var factor := Vector2(get_window().size) / get_viewport().get_visible_rect().size
	return Rect2((transform * Vector2.ZERO) * factor, control.size * transform.get_scale() * factor)


func _button_observation(button: Button, id: String) -> Dictionary:
	var rect := _control_pixels(button)
	var hit := rect.intersection(Rect2(Vector2.ZERO, Vector2(get_window().size)))
	var parent := button.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			hit = hit.intersection(_control_pixels(parent))
		parent = parent.get_parent()
	return {"id": id, "text": button.tooltip_text if id.begins_with("answer_") else button.text,
		"rect_px": _rect_array(rect), "hit_rect_px": _rect_array(hit),
		"visible": button.is_visible_in_tree(), "enabled": not button.disabled,
		"clipped": not hit.grow(0.01).encloses(rect)}


func _publish_layout_observation() -> void:
	if not _layout_dirty or _closed or not _authority_ready or _state.is_empty() or _pending > 0 or not safe.is_visible_in_tree():
		return
	if _layout_frames > 0:
		_layout_frames -= 1
		return
	if Time.get_ticks_msec() < _layout_retry:
		return
	var buttons := [_button_observation(return_button, "back"), _button_observation(pause_button, "pause"),
		_button_observation(reveal_button, "reveal"), _button_observation(next_button, "next"),
		_button_observation(resume_button, "resume"), _button_observation(restart_button, "restart")]
	for i in range(4):
		buttons.append(_button_observation(answer_buttons[i], "answer_%d" % i))
		buttons.append(_button_observation(subject_buttons[i], "subject_" + str(SUBJECTS[i])))
	for i in range(3):
		buttons.append(_button_observation(joker_buttons[i], "joker_" + str(JOKERS[i])))
	var observed := MobileRuntime.get_safe_area_observation()
	var android := {}
	for key in ["view_size", "decor_size"]:
		if observed.has(key):
			android[key] = [observed[key].x, observed[key].y]
	for key in ["render_rect", "system_insets", "insets"]:
		if observed.has(key):
			android[key] = _rect_array(observed[key])
	_layout_sequence += 1
	var factor := Vector2(get_window().size) / get_viewport().get_visible_rect().size
	var snapshot := {"schema": 1, "game": "quiz", "layout_sequence": _layout_sequence,
		"ticks_msec": Time.get_ticks_msec(), "pid": OS.get_process_id(), "settled": true,
		"token": _token, "owner": _state.owner, "roundId": _state.roundId,
		"revision": int(_state.revision), "recordRevision": int(_state.recordRevision),
		"ack": int(_state.ack), "rejected": int(_state.rejected), "pending": _pending,
		"state": _state.duplicate(true), "ui_visible": safe.is_visible_in_tree(), "density": _density,
		"coordinate_space": "godot_window_px; map through android_observation.render_rect for decor screenshots",
		"window_px": [get_window().size.x, get_window().size.y],
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"content_scale_aspect": get_window().content_scale_aspect,
		"safe_rect": _rect_array(Rect2(_safe_rect.position * factor, _safe_rect.size * factor)),
		"stage_rect": _rect_array(Rect2(_stage_rect.position * factor, _stage_rect.size * factor)),
		"content_clip_px": _rect_array(_control_pixels(content_scroll)), "buttons": buttons,
		"android_observation": android,
		"observation_source": "android_window_insets" if OS.has_feature("android") and not observed.is_empty() else "platform_fixture" if MobileRuntime.requires_safe_area_observation() else "platform_safe_area",
		"geometry": {"question_lights": _lights.size(), "lit_questions": int(_state.number),
			"original_lumo_usable": fox.is_usable(), "model_load_kind": fox.model_load_kind,
			"bones": fox.skeleton.get_bone_count() if is_instance_valid(fox.skeleton) else 0,
			"clips": fox.CLIPS, "audio_driven_mouth": false}}
	var file := FileAccess.open(LAYOUT_OBSERVATION + ".tmp", FileAccess.WRITE)
	if file == null:
		_layout_retry = Time.get_ticks_msec() + 2000
		return
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(LAYOUT_OBSERVATION + ".tmp", LAYOUT_OBSERVATION)
	if error == OK:
		_layout_dirty = false
	else:
		_layout_retry = Time.get_ticks_msec() + 2000
