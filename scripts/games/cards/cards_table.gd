extends Node3D
## Native spatial surface of the existing Dart Cards engine. No duplicate rules.
signal action_requested(request: Dictionary)

const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const COLORS := {"orange": Color("e64e48"), "purple": Color("efd34b"), "blue": Color("3297ed"), "green": Color("58b877")}
const COLOR_NAMES := {"orange": "Rot", "purple": "Gelb", "blue": "Blau", "green": "Grün"}
var camera: Camera3D
var actor: Node3D
var hand_root: Node3D
var opponent_root: Node3D
var discard_root: Node3D
var ui: Control
var heading: Label
var message: Label
var status: Label
var footer: VBoxContainer
var actions: HBoxContainer
var modal: PanelContainer
var modal_content: VBoxContainer
var page_label: Label
var play_button: Button
var draw_button: Button
var pause_button: Button
var call_button: Button
var _host: Object
var _token := ""
var _state: Dictionary = {}
var _cards: Dictionary = {}
var _selected := ""
var _sequence := 0
var _pending := 0
var _poll_time := 0.0
var _page := 0
var _page_size := 7
var _elapsed := 0.0
var _focus := 0.0
var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _closed := false
var _ui_scale := 1.0
var _hand_targets: Dictionary = {}

func _ready() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	if Engine.has_singleton("LumoHost"):
		_host = Engine.get_singleton("LumoHost")
	_token = str(HostBridge.launch_options().get("cardsToken", ""))
	_build_room()
	_build_interface()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_poll()

func _material(key: String, color: Color, roughness: float = 0.55, metal: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	_materials[key] = mat
	return mat

func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance

func _build_room() -> void:
	var wood := _material("wood", Color("382335"), 0.4)
	var gold := _material("gold", Color("d8aa5c"), 0.3, 0.72)
	var felt := _material("felt", Color("12415c"), 0.94)
	var wall := _material("wall", Color("17314e"), 0.9)
	var floor_mat := _material("floor", Color("28344a"), 0.6)
	_box(self, Vector3(0, -0.12, 0), Vector3(18, 0.2, 18), floor_mat)
	_box(self, Vector3(0, 3, -5.5), Vector3(16, 6, 0.24), wall)
	_box(self, Vector3(-7, 3, 0), Vector3(0.24, 6, 12), wall)
	_box(self, Vector3(7, 3, 0), Vector3(0.24, 6, 12), wall)
	for x in [-4.8, 4.8]:
		_box(self, Vector3(x, 2.6, -5.32), Vector3(2.1, 3.1, 0.22), wood)
		var window := _material("window", Color("447f9f"), 0.3)
		window.emission_enabled = true
		window.emission = Color("3c7493")
		window.emission_energy_multiplier = 0.45
		_box(self, Vector3(x, 2.6, -5.16), Vector3(1.87, 2.85, 0.08), window)
		_box(self, Vector3(x, 2.6, -5.05), Vector3(0.07, 2.9, 0.1), gold)
		_box(self, Vector3(x, 2.6, -5.05), Vector3(1.9, 0.07, 0.1), gold)
	for side in [-1, 1]:
		var x := float(side) * 3.55
		_box(self, Vector3(x, 1.65, -4.45), Vector3(1.6, 3.3, 0.6), wood)
		for shelf in range(3):
			_box(self, Vector3(x, 0.5 + shelf * 0.95, -4.06), Vector3(1.65, 0.08, 0.85), gold)
			for book in range(6):
				var color: Color = [Color("b96558"), Color("5485a2"), Color("dfbc6e"), Color("578c75")][(shelf + book) % 4]
				_box(self, Vector3(x - 0.65 + book * 0.25, 0.8 + shelf * 0.95, -4.15), Vector3(0.17, 0.53 + (book % 3) * 0.08, 0.4), _material("book%d" % ((shelf + book) % 4), color))
	_cylinder(self, Vector3(0, 0.91, 0), 3.72, 0.28, wood).scale.z = 1.07
	_cylinder(self, Vector3(0, 1.065, 0), 3.57, 0.045, gold).scale.z = 1.07
	_cylinder(self, Vector3(0, 1.095, 0), 3.48, 0.035, felt).scale.z = 1.07
	for x in [-2.3, 2.3]:
		for z in [-2.3, 2.3]:
			_cylinder(self, Vector3(x, 0.42, z), 0.16, 0.84, wood)
			_cylinder(self, Vector3(x, 0.1, z), 0.22, 0.12, gold)
	# A real chair and the unchanged original rig at the far side of the table.
	_box(self, Vector3(0, 0.7, -3.35), Vector3(1.35, 0.18, 1.2), wood)
	_box(self, Vector3(0, 1.5, -3.88), Vector3(1.4, 1.7, 0.18), wood)
	_box(self, Vector3(0, 1.5, -3.75), Vector3(1.1, 1.38, 0.12), felt)
	actor = ACTOR.new()
	actor.name = "OriginalLumo"
	actor.position = Vector3(0, 0.85, -3.15)
	actor.scale = Vector3.ONE * 1.25
	add_child(actor)
	actor.call("play_behavior", "kart_seated")
	var env := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("10233a")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("9dbedc")
	resource.ambient_light_energy = 0.65
	resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = resource
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 4, -3)
	rim.light_color = Color("82c9ee")
	rim.light_energy = 2.0
	rim.omni_range = 9
	add_child(rim)
	camera = Camera3D.new()
	camera.fov = 46
	camera.near = 0.1
	camera.far = 40
	camera.current = true
	add_child(camera)
	hand_root = Node3D.new()
	hand_root.name = "PlayerCards"
	add_child(hand_root)
	opponent_root = Node3D.new()
	opponent_root.name = "OpponentCards"
	add_child(opponent_root)
	discard_root = Node3D.new()
	discard_root.name = "Discard"
	add_child(discard_root)
	for i in range(6):
		_make_card(self, {}, Vector3(-0.8, 1.14 + i * 0.027, 0), false)

func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(52, 52)
	button.set_meta("base_width", 52.0)
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var top := VBoxContainer.new()
	top.name = "Top"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	ui.add_child(top)
	var nav := HBoxContainer.new()
	top.add_child(nav)
	var back := _button("Zurück", _leave)
	back.name = "Back"
	nav.add_child(back)
	heading = Label.new()
	heading.text = "Lumo Cards · 3D-Tisch"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(heading)
	pause_button = _button("Pause", func(): _send("resume" if bool(_state.get("paused", false)) else "pause"))
	nav.add_child(pause_button)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(status)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(message)
	footer = VBoxContainer.new()
	footer.name = "Footer"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 16
	footer.offset_right = -16
	footer.offset_top = -128
	footer.offset_bottom = -12
	ui.add_child(footer)
	var pages := HBoxContainer.new()
	pages.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(pages)
	pages.add_child(_button("‹", func(): _change_page(-1)))
	page_label = Label.new()
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.custom_minimum_size.x = 40
	pages.add_child(page_label)
	pages.add_child(_button("›", func(): _change_page(1)))
	actions = HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(actions)
	play_button = _button("Karte legen", func():
		if not _selected.is_empty():
			_send("play", {"cardId": _selected}))
	actions.add_child(play_button)
	draw_button = _button("Ziehen", func(): _send("draw"))
	actions.add_child(draw_button)
	call_button = _button("LUMO! +1", func(): _send("call"))
	call_button.hide()
	actions.add_child(call_button)
	modal = PanelContainer.new()
	modal.name = "Decision"
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 10)
	modal.add_child(modal_content)
	ui.add_child(modal)
	modal.hide()
	var theme := Theme.new()
	theme.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("123455")
	normal.border_color = Color("67bdcf")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("31647e")
	theme.set_stylebox("hover", "Button", focus)
	theme.set_stylebox("pressed", "Button", focus)
	theme.set_stylebox("focus", "Button", focus)
	var panel := normal.duplicate() as StyleBoxFlat
	panel.bg_color = Color("0d233e")
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	theme.set_stylebox("panel", "PanelContainer", panel)
	ui.theme = theme

func _resize() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(ui):
		return
	var size := get_viewport().get_visible_rect().size
	_ui_scale = MobileRuntime.get_ui_density()
	# UI canvas pixels are native pixels; all touch targets retain at least 48 dp.
	for button in ui.find_children("*", "Button", true, false):
		button.custom_minimum_size = Vector2(float(button.get_meta("base_width", 52.0)), 52.0) * _ui_scale
		button.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	for label in [heading, status, message, page_label]:
		label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	var width_dp := size.x / _ui_scale
	_page_size = 7 if width_dp > 850 else (5 if width_dp > 550 else 3)
	footer.offset_top = -128 * _ui_scale
	footer.offset_bottom = -12 * _ui_scale
	modal.offset_left = -minf(size.x * 0.45, 280 * _ui_scale)
	modal.offset_right = minf(size.x * 0.45, 280 * _ui_scale)
	modal.offset_top = -minf(size.y * 0.28, 200 * _ui_scale)
	modal.offset_bottom = minf(size.y * 0.28, 200 * _ui_scale)
	_update_camera()
	if not _state.is_empty():
		_render_hand()

func _update_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(1, size.y)
	var distance_scale := maxf(1.0, 1.05 / aspect)
	camera.position = Vector3(_focus * 0.18, 7.3 * distance_scale, 8.2 * distance_scale)
	camera.look_at(Vector3(0, 1.05, 0))

func _process(delta: float) -> void:
	_elapsed += delta
	_poll_time += delta
	if _poll_time >= 0.20:
		_poll_time = 0
		_poll()
	_focus = move_toward(_focus, 0, delta * 0.9)
	_update_camera()

func _poll() -> void:
	if not is_instance_valid(_host) or _closed:
		return
	var raw = JSON.parse_string(str(_host.call("getCardsState")))
	if raw is Dictionary and raw.get("protocol") == 1 and str(raw.get("token", "")) == _token:
		if int(raw.get("revision", -1)) != int(_state.get("revision", -2)):
			apply_state(raw)
	elif is_instance_valid(message):
		# A closed/profile-invalidated authority never leaves a previous child's hand visible.
		_state.clear()
		_cards.clear()
		for container in [hand_root, opponent_root, discard_root]:
			for child in container.get_children():
				child.queue_free()
		play_button.disabled = true
		draw_button.disabled = true
		pause_button.disabled = true
		message.text = "Die Runde wartet auf die Lern-App. Mit Zurück bleibt dein Spielstand erhalten."

func apply_state(next: Dictionary) -> void:
	if int(next.get("protocol", 0)) != 1 or not next.get("hand", []) is Array:
		return
	var previous := _state
	_state = next.duplicate(true)
	_token = str(next.get("token", _token))
	_sequence = maxi(_sequence, int(next.get("ack", 0)))
	if int(next.get("ack", 0)) >= _pending:
		_pending = 0
	var top: Dictionary = next.get("top", {}) if next.get("top") is Dictionary else {}
	var previous_top: Dictionary = previous.get("top", {}) if previous.get("top") is Dictionary else {}
	var top_changed := not top.is_empty() and str(top.get("id", "")) != str(previous_top.get("id", ""))
	var departure := Vector3(0, 1.2, -2.0)
	if _cards.has(str(top.get("id", ""))):
		departure = _cards[str(top.get("id", ""))].position
	for child in discard_root.get_children():
		child.queue_free()
	if not top.is_empty():
		var node := _make_card(discard_root, top, Vector3(0.7, 1.17, 0), true)
		if top_changed and not previous.is_empty() and not bool(next.get("reduceMotion", false)):
			node.position = departure + Vector3(0, 0.35, 0)
			var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "position", Vector3(0.7, 1.17, 0), 0.4)
			_focus = 1.0
			actor.call("play_behavior", "agree_nod")
	_render_hand()
	_render_opponent()
	_update_interface()
	if str(next.get("phase", "")) == "gameOver" and str(previous.get("phase", "")) != "gameOver":
		actor.call("play_behavior", "celebrate")
	actor.call("set_suspended", bool(next.get("paused", false)))
	actor.call("set_reduced_motion", bool(next.get("reduceMotion", false)))

func _texture(card: Dictionary, face: bool) -> Texture2D:
	var path := "res://assets/cards_table/cards/back/card_back_default.png"
	if face:
		var folder: String = {"orange": "red", "purple": "yellow", "blue": "blue", "green": "green"}.get(str(card.get("color", "")), "red")
		var kind := str(card.get("type", "number"))
		if kind == "colorMagic":
			path = "res://assets/cards_table/cards/special/color_magic.png"
		elif kind == "superRain":
			path = "res://assets/cards_table/cards/special/wild_draw_four.png"
		else:
			var suffix := str(card.get("number", 1)) if kind == "number" else str({"lumoJump": "skip", "starRain": "draw_two", "whirlwind": "reverse", "thinkPause": "think_pause"}.get(kind, "1"))
			path = "res://assets/cards_table/cards/%s/%s_%s.png" % [folder, folder, suffix]
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

func _make_card(parent: Node3D, card: Dictionary, at: Vector3, face: bool) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	_box(node, Vector3.ZERO, Vector3(0.83, 0.032, 1.18), _material("card_edge", Color("e6e3d9"), 0.44))
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.83, 1.18)
	surface.mesh = plane
	surface.position.y = 0.017
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture(card, face)
	mat.roughness = 0.42
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	surface.material_override = mat
	node.add_child(surface)
	return node

func _render_hand() -> void:
	var old: Dictionary = {}
	for id in _cards:
		if is_instance_valid(_cards[id]):
			old[id] = _cards[id].position
	for child in hand_root.get_children():
		child.queue_free()
	_cards.clear()
	_hand_targets.clear()
	var hand: Array = _state.get("hand", [])
	var max_page := maxi(0, ceili(float(hand.size()) / float(_page_size)) - 1)
	_page = clampi(_page, 0, max_page)
	var visible: Array = hand.slice(_page * _page_size, mini(hand.size(), (_page + 1) * _page_size))
	var visible_ids: Array[String] = []
	for i in range(visible.size()):
		var card: Dictionary = visible[i]
		var id := str(card.get("id", ""))
		visible_ids.append(id)
		var offset := float(i) - float(visible.size() - 1) * 0.5
		var size := get_viewport().get_visible_rect().size
		var card_height := clampf(size.y * 0.28, 96 * _ui_scale, 180 * _ui_scale)
		var card_width := card_height * 0.83 / 1.18
		var spacing := minf(card_width * 1.08, (size.x - 32 * _ui_scale - card_width) / maxf(1, visible.size() - 1))
		var screen := Vector2(size.x * 0.5 + offset * spacing, size.y - 140 * _ui_scale - card_height * 0.5)
		var at := camera.project_position(screen, 4.0)
		var node := _make_card(hand_root, card, at, true)
		node.name = "HandCard%d" % i
		var scale_factor := (2 * 4.0 * tan(deg_to_rad(camera.fov * 0.5))) * card_height / size.y / 1.18
		node.basis = camera.global_basis * Basis(Vector3.RIGHT, PI * 0.5)
		node.scale = Vector3.ONE * scale_factor
		_hand_targets[id] = at
		_cards[id] = node
		if bool(card.get("playable", false)):
			_box(node, Vector3(0, -0.02, 0), Vector3(0.88, 0.02, 1.23), _material("legal_gold", Color("f5c259"), 0.32, 0.4))
		if old.has(id) and not bool(_state.get("reduceMotion", false)):
			node.position = old[id]
			create_tween().tween_property(node, "position", at, 0.22)
	if _selected not in visible_ids:
		_selected = ""
	_highlight_selection()
	if is_instance_valid(page_label):
		page_label.text = "%d/%d" % [_page + 1, max_page + 1]

func _render_opponent() -> void:
	for child in opponent_root.get_children():
		child.queue_free()
	var players: Array = _state.get("players", [])
	if players.size() != 2:
		return
	var count := int(players[1 - int(_state.get("viewer", 0))].get("count", 0))
	for i in range(mini(count, 12)):
		var offset := float(i) - float(mini(count, 12) - 1) * 0.5
		var node := _make_card(opponent_root, {}, Vector3(offset * 0.22, 1.17 + i * 0.002, -1.7), false)
		node.rotation.y = offset * 0.055 + PI

func _highlight_selection() -> void:
	for id in _cards:
		var card_node: Node3D = _cards[id]
		card_node.position = _hand_targets[id] + camera.global_basis.y * (0.08 if id == _selected else 0.0)
	if is_instance_valid(play_button):
		play_button.disabled = _selected.is_empty() or _pending > 0 or bool(_state.get("paused", false))

func _change_page(change: int) -> void:
	_page += change
	_selected = ""
	_render_hand()

func _update_interface() -> void:
	heading.text = "Sternenpokal · Runde %d/%d" % [int(_state.get("round", 1)), int(_state.get("totalRounds", 1))] if int(_state.get("totalRounds", 1)) > 1 else "Lumo Cards · 3D-Tisch"
	var players: Array = _state.get("players", [])
	if players.size() == 2:
		status.text = "%s: %d Karten   ·   %s: %d Karten" % [players[0].get("name", "Du"), int(players[0].get("count", 0)), players[1].get("name", "Lumo"), int(players[1].get("count", 0))]
	message.text = str(_state.get("message", ""))
	draw_button.disabled = not bool(_state.get("canDraw", false)) or _pending > 0
	pause_button.text = "Weiter" if bool(_state.get("paused", false)) else "Pause"
	pause_button.disabled = _pending > 0
	call_button.visible = bool(_state.get("canCall", false))
	call_button.disabled = _pending > 0
	for child in modal_content.get_children():
		child.queue_free()
	var phase := str(_state.get("phase", "playing"))
	modal.visible = bool(_state.get("paused", false)) or phase in ["chooseColor", "learningQuestion", "passDevice", "gameOver"]
	if not modal.visible:
		return
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(22 * _ui_scale))
	modal_content.add_child(title)
	if bool(_state.get("paused", false)):
		title.text = "Dein Zug wartet auf dich."
		modal_content.add_child(_button("Weiterspielen", func(): _send("resume")))
	elif phase == "chooseColor":
		title.text = "Welche Farbe wählst du?"
		for color in ["orange", "purple", "blue", "green"]:
			var button := _button(COLOR_NAMES[color], func(): _send("color", {"color": color}))
			button.modulate = COLORS[color].lightened(0.35)
			modal_content.add_child(button)
	elif phase == "learningQuestion":
		var question: Dictionary = _state.get("question", {})
		title.text = str(question.get("prompt", "Lumo überlegt …"))
		var options: Array = question.get("options", [])
		for i in range(options.size()):
			modal_content.add_child(_button(str(options[i]), func(): _send("answer", {"index": i})))
	elif phase == "passDevice":
		title.text = "Gerät weitergeben. Deine Karten bleiben verdeckt."
		modal_content.add_child(_button("Ich bin bereit", func(): _send("handover")))
	elif phase == "gameOver":
		title.text = str(_state.get("message", "Die Runde ist beendet."))
		modal_content.add_child(_button("Ergebnis ansehen", _leave))
	for button in modal_content.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 52 * _ui_scale
		button.add_theme_font_size_override("font_size", int(18 * _ui_scale))
		button.disabled = _pending > 0

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	else:
		return
	if modal.visible or _pending > 0 or bool(_state.get("paused", false)):
		return
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var closest := INF
	var picked := ""
	for id in _cards:
		var card_node: Node3D = _cards[id]
		var local_origin := card_node.to_local(origin)
		var local_direction := card_node.global_basis.inverse() * direction
		if absf(local_direction.y) < 0.001:
			continue
		var distance := -local_origin.y / local_direction.y
		var hit := local_origin + local_direction * distance
		if distance > 0 and distance < closest and absf(hit.x) <= 0.48 and absf(hit.z) <= 0.65:
			closest = distance
			picked = id
	if picked.is_empty():
		return
	for card in _state.get("hand", []):
		if str(card.get("id", "")) == picked and not bool(card.get("playable", false)):
			message.text = "Diese Karte passt gerade nicht. Goldene Karten kannst du legen."
			return
	if picked == _selected:
		_send("play", {"cardId": picked})
	else:
		_selected = picked
		_highlight_selection()
	get_viewport().set_input_as_handled()

func _send(action: String, payload: Dictionary = {}) -> void:
	if _state.is_empty() or _pending > 0 or _closed:
		return
	_sequence += 1
	var request := payload.duplicate(true)
	request["token"] = _token
	request["revision"] = int(_state.get("revision", 0))
	request["sequence"] = _sequence
	request["action"] = action
	action_requested.emit(request)
	var accepted := true
	if is_instance_valid(_host):
		accepted = HostBridge.durable_ack(_host.call("submitCardsAction", JSON.stringify(request)))
	if accepted:
		_pending = _sequence
		message.text = "Dein Zug wird gespeichert …"
		play_button.disabled = true
		draw_button.disabled = true
		pause_button.disabled = true
	else:
		message.text = "Der Zug wurde aktualisiert. Bitte noch einmal wählen."

func _leave() -> void:
	if _closed:
		return
	if HostBridge.is_embedded():
		_closed = HostBridge.return_to_app("games")
	else:
		SceneRouter.goto("games")
