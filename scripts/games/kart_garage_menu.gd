extends Control
## Accessible five-step setup with a live, lit 3D driver and kart preview.
signal start_requested(setup: Dictionary)
signal resume_requested
signal exit_requested(destination: String)
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var setup: Dictionary = {"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"}
var step: int = 0
var stars: int = 0
var unlocked_ids: Array = []
var has_saved_race: bool = false
var choices: VBoxContainer
var title_label: Label
var subtitle: Label
var detail: Label
var steps_label: Label
var next_button: Button
var back_button: Button
var preview: Node3D
var preview_pivot: Node3D
var preview_kart: Node3D
var rotate_drag: bool = false
var preview_angle: float = 0.5
var preview_signature: String = ""
var preview_caption: Label
var reduced_motion: bool = false
var graphics_profile: String = "high"
var progress_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("071226")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color(0.035, 0.14, 0.25, 0.8)
	glow.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	glow.offset_left = -560
	add_child(glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	margin.add_child(body)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 60
	var brand := _label("LUMO  /  KART", 22, Color("f4f8ff"))
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.custom_minimum_size.x = 215
	header.add_child(brand)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	progress_label = _label("", 18, Color("83dfef"))
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.custom_minimum_size.x = 150
	header.add_child(progress_label)
	header.add_child(_button("Zum Lernen", func(): exit_requested.emit("learn"), false))
	body.add_child(header)
	steps_label = _label("", 15, Color("9cb3ce"))
	body.add_child(steps_label)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	title_label = _label("", 36, Color("f4f8ff"))
	left.add_child(title_label)
	subtitle = _label("", 18, Color("b5c9df"))
	left.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 9)
	scroll.add_child(choices)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	row.add_child(right)
	var viewport_panel := PanelContainer.new()
	viewport_panel.add_theme_stylebox_override("panel", _glass(false))
	viewport_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(viewport_panel)
	var viewport_box := SubViewportContainer.new()
	viewport_box.stretch = true
	viewport_box.custom_minimum_size = Vector2(250, 240)
	viewport_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_box.gui_input.connect(_preview_input)
	viewport_panel.add_child(viewport_box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 500)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport_box.add_child(viewport)
	preview = Node3D.new()
	viewport.add_child(preview)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("0c1d36")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("b0cfff")
	environment_resource.ambient_light_energy = 0.40
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = environment_resource
	preview.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_color = Color("e1f1ff")
	key.light_energy = 1.0
	key.shadow_enabled = true
	preview.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 2.6, 1)
	rim.light_color = Color("63dfff")
	rim.light_energy = 0.4
	rim.omni_range = 9
	preview.add_child(rim)
	var podium := MeshInstance3D.new()
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 2.0
	podium_mesh.bottom_radius = 2.05
	podium_mesh.height = 0.18
	podium_mesh.radial_segments = 64
	podium.mesh = podium_mesh
	podium.position.y = -0.13
	var podium_mat := StandardMaterial3D.new()
	podium_mat.albedo_color = Color("183654")
	podium_mat.metallic = 0.7
	podium_mat.roughness = 0.3
	podium.material_override = podium_mat
	preview.add_child(podium)
	var camera := Camera3D.new()
	camera.position = Vector3(3.2, 2.2, -4.5)
	camera.fov = 37
	preview.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	preview_pivot = Node3D.new()
	preview.add_child(preview_pivot)
	preview_caption = _label("Ziehen zum Drehen", 14, Color("8faac8"))
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_caption)
	detail = _label("", 20, Color("dceaff"))
	detail.custom_minimum_size.y = 74
	right.add_child(detail)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	body.add_child(footer)
	back_button = _button("Zurück", _back, false)
	footer.add_child(back_button)
	if has_saved_race:
		footer.add_child(_button("Gespeichertes Rennen", func(): resume_requested.emit(), false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	next_button = _button("Weiter →", _next, true)
	next_button.custom_minimum_size.x = 240
	footer.add_child(next_button)
	_refresh()

func _glass(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183d60") if selected else Color(0.055, 0.12, 0.21, 0.96)
	style.border_color = Color("80e7f6") if selected else Color(0.4, 0.7, 0.9, 0.26)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(15)
	style.shadow_color = Color(0, 0.02, 0.06, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(148, 72)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("f4f8ff"))
	button.add_theme_color_override("font_disabled_color", Color("8295ab"))
	button.add_theme_stylebox_override("normal", _glass(primary))
	button.add_theme_stylebox_override("hover", _glass(true))
	button.add_theme_stylebox_override("pressed", _glass(true))
	button.add_theme_stylebox_override("focus", _glass(true))
	button.add_theme_stylebox_override("disabled", _glass(false))
	button.pressed.connect(callback)
	return button

func _entries() -> Array[Dictionary]:
	match step:
		0: return CATALOG.MODES
		1: return CATALOG.DRIVERS
		2: return CATALOG.KARTS
		3: return CATALOG.TRACKS
	return CATALOG.DIFFICULTIES

func _refresh() -> void:
	var keys: Array[String] = ["mode", "driver", "kart", "track", "difficulty"]
	var titles: Array[String] = ["Dein nächstes Abenteuer", "Wer fährt mit?", "Dein Kart. Dein Stil.", "Wohin geht die Reise?", "Finde dein Tempo"]
	var descriptions: Array[String] = ["Wähle, wie du heute fahren möchtest.", "Gemeinsam wird jede Fahrt besonders.", "Sterne aus dem Lernen öffnen neue Möglichkeiten.", "Vier Welten voller kleiner Entdeckungen.", "Du kannst das Tempo vor jedem Rennen ändern."]
	title_label.text = titles[step]
	subtitle.text = descriptions[step]
	steps_label.text = "%d / 5     MODUS  ·  FAHRER  ·  KART  ·  WELT  ·  TEMPO" % (step + 1)
	progress_label.text = "★ %d Sterne" % stars
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var key: String = keys[step]
	var card_parent: Container = choices
	if step == 0:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		choices.add_child(grid)
		card_parent = grid
	if step == 3 and setup.mode in ["cup", "arena"]:
		var cup_text: String = "KRISTALL-ARENA\n90 Sekunden · Kristalle sammeln · Rivalen überholen" if setup.mode == "arena" else "DER STERNEN-CUP\nSonnenhafen → Zauberwald → Himmelsinseln → Holo City"
		var card := _button(cup_text, func(): pass, true)
		card.custom_minimum_size.y = 110
		choices.add_child(card)
	else:
		for item in _entries():
			var unlocked: bool = CATALOG.unlocked(item, stars, unlocked_ids)
			var selected: bool = setup[key] == item.id
			var value: String = ("●  " if selected else "○  ") + str(item.name) + "   ·   " + str(item.tag)
			if not unlocked:
				value += "  /  ab %d ★" % int(item.unlock)
			if step == 0:
				value = ("●  " if selected else "○  ") + str(item.name) + "\n" + str(item.tag)
			var card := _button(value, func(): _select(key, str(item.id)), selected)
			card.alignment = HORIZONTAL_ALIGNMENT_LEFT
			card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			card.custom_minimum_size = Vector2(0, 94 if step == 0 else 74)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.disabled = not unlocked
			card_parent.add_child(card)
	var selected_entry: Dictionary = CATALOG.entry(_entries(), str(setup[key]))
	detail.text = str(selected_entry.get("description", selected_entry.get("tag", "")))
	if step == 3 and setup.mode == "cup":
		detail.text = "Vier Rennen. Eine Gesamtwertung. Dein Sternenpokal wartet."
	elif step == 3 and setup.mode == "arena":
		detail.text = "Frei fahren und Kristalle sammeln. Nach 90 Sekunden gewinnt die höchste Punktzahl."
	back_button.text = "Spieleauswahl" if step == 0 else "← Zurück"
	next_button.text = "Rennen starten →" if step == 4 else "Weiter →"
	_refresh_preview()

func _select(key: String, value: String) -> void:
	setup[key] = value
	_refresh.call_deferred()

func _next() -> void:
	if step == 4:
		start_requested.emit(setup.duplicate(true))
	else:
		step += 1
		_refresh()

func _back() -> void:
	if step == 0:
		exit_requested.emit("games")
	else:
		step -= 1
		_refresh()

func _refresh_preview() -> void:
	var signature: String = str(setup.driver) + str(setup.kart)
	if signature == preview_signature:
		return
	preview_signature = signature
	if is_instance_valid(preview_kart):
		preview_pivot.remove_child(preview_kart)
		preview_kart.queue_free()
	preview_kart = VEHICLE.new()
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, str(setup.driver))
	preview_kart.configure(str(setup.driver), driver.color, str(setup.kart))
	preview_kart.reduced_motion = reduced_motion
	preview_kart.set_graphics_quality(graphics_profile)
	preview_pivot.add_child(preview_kart)

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		rotate_drag = event.pressed
	elif event is InputEventMouseMotion and rotate_drag:
		preview_angle += event.relative.x * 0.008
	elif event is InputEventScreenDrag:
		preview_angle += event.relative.x * 0.008

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(preview_pivot):
		return
	if not rotate_drag and not reduced_motion:
		preview_angle += delta * 0.14
	preview_pivot.rotation.y = preview_angle
