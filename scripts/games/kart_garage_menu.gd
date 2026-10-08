extends Control
## Accessible five-step setup with a live, lit 3D driver and kart preview.
signal start_requested(setup: Dictionary)
signal resume_requested
signal exit_requested(destination: String)
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const CHOICE = preload("res://scripts/games/kart_menu_choice.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var setup: Dictionary = {
	"mode": "race",
	"driver": "fox",
	"kart": "comet",
	"track": "sonnenhafen",
	"difficulty": "gemuetlich"
}
var step: int = 0
var stars: int = 0
var unlocked_ids: Array = []
var has_saved_race: bool = false
var choices: VBoxContainer
var setup_row: GridContainer
var page_margin: MarginContainer
var brand_label: Label
var learn_button: Button
var footer: GridContainer
var footer_spacer: Control
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
var body_column: VBoxContainer
var header_row: HBoxContainer
var preview_container: SubViewportContainer
var step_strip: HBoxContainer
var step_buttons: Array[Button] = []
var preview_world: Node3D
var preview_title: Label
var preview_camera: Camera3D
var view_choice: OptionButton
var inspection_view: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = UI.create()
	var background := TextureRect.new()
	background.texture = preload("res://assets/kart/menu/lumo-world.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.012, 0.035, 0.10, 0.79)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	page_margin = MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, 28)
	add_child(page_margin)
	var body := VBoxContainer.new()
	body_column = body
	body.add_theme_constant_override("separation", 16)
	page_margin.add_child(body)
	var header := HBoxContainer.new()
	header_row = header
	header.custom_minimum_size.y = 60
	brand_label = _label("LUMO KART", 36, Color("f4f8ff"))
	brand_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_label.custom_minimum_size.x = 260
	header.add_child(brand_label)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	progress_label = _label("", 18, Color("ffd06a"))
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.custom_minimum_size.x = 150
	header.add_child(progress_label)
	learn_button = _button("Zum Lernen", func(): exit_requested.emit("learn"), false)
	header.add_child(learn_button)
	body.add_child(header)
	steps_label = _label("", 15, Color("9cb3ce"))
	steps_label.hide()
	body.add_child(steps_label)
	step_strip = HBoxContainer.new()
	step_strip.add_theme_constant_override("separation", 8)
	body.add_child(step_strip)
	for index in range(5):
		var tab := _button(
			"",
			func():
				step = index
				_refresh(),
			false
		)
		tab.custom_minimum_size = Vector2(0, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var tab_style := _glass(index == step)
			tab_style.content_margin_top = 6
			tab_style.content_margin_bottom = 6
			tab.add_theme_stylebox_override(state, tab_style)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_strip.add_child(tab)
		step_buttons.append(tab)
	setup_row = GridContainer.new()
	setup_row.columns = 2
	setup_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_row.add_theme_constant_override("h_separation", 28)
	setup_row.add_theme_constant_override("v_separation", 14)
	body.add_child(setup_row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	setup_row.add_child(left)
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
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_row.add_child(right)
	preview_title = _label("DEINE GARAGE", 16, Color("74e5f5"))
	right.add_child(preview_title)
	var viewport_panel := PanelContainer.new()
	viewport_panel.add_theme_stylebox_override("panel", _glass(false))
	viewport_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(viewport_panel)
	var viewport_box := SubViewportContainer.new()
	preview_container = viewport_box
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
	environment_resource.background_mode = Environment.BG_CANVAS
	environment_resource.background_color = Color("0c1d36")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("b0cfff")
	environment_resource.ambient_light_energy = 0.40
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = environment_resource
	preview.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_color = Color("e1f1ff")
	key.light_energy = 0.8
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
	podium_mat.albedo_color = Color("12304c")
	podium_mat.metallic = 0.7
	podium_mat.roughness = 0.3
	podium.material_override = podium_mat
	preview.add_child(podium)
	for radius in [2.04, 2.30]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius
		torus.outer_radius = radius + 0.035
		torus.rings = 64
		ring.mesh = torus
		ring.position.y = -0.04
		var light_material := StandardMaterial3D.new()
		light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light_material.albedo_color = Color("45d9ef")
		ring.material_override = light_material
		preview.add_child(ring)
	for index in range(8):
		var star := MeshInstance3D.new()
		star.mesh = SHAPES.star()
		star.scale = Vector3.ONE * (0.035 + index % 3 * 0.015)
		star.position = Vector3(sin(index * 2.4) * 2.5, 0.7 + index % 4 * 0.5, cos(index * 2.4) * 2)
		var star_material := StandardMaterial3D.new()
		star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_material.albedo_color = Color("a8deee")
		star.material_override = star_material
		preview.add_child(star)
	var camera := Camera3D.new()
	preview_camera = camera
	camera.position = Vector3(3.2, 2.2, -4.5)
	camera.fov = 37
	preview.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	preview_pivot = Node3D.new()
	preview.add_child(preview_pivot)
	preview_caption = _label("Ziehen zum Drehen", 14, Color("8faac8"))
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_caption)
	view_choice = OptionButton.new()
	view_choice.name = "KartInspectionView"
	view_choice.tooltip_text = "Dein Kart von allen Seiten ansehen"
	view_choice.custom_minimum_size.y = 44
	for title in ["Rundum ansehen", "Vorne", "Links", "Hinten", "Rechts", "Von oben"]:
		view_choice.add_item(title)
	view_choice.item_selected.connect(_choose_preview_view)
	right.add_child(view_choice)
	detail = _label("", 20, Color("dceaff"))
	detail.custom_minimum_size.y = 74
	right.add_child(detail)
	footer = GridContainer.new()
	footer.columns = 4
	footer.add_theme_constant_override("h_separation", 14)
	footer.add_theme_constant_override("v_separation", 8)
	body.add_child(footer)
	back_button = _button("Zurück", _back, false)
	footer.add_child(back_button)
	if has_saved_race:
		var resume_button := _button("Gespeichertes Rennen", func(): resume_requested.emit(), false)
		resume_button.name = "ResumeRace"
		footer.add_child(resume_button)
	footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	next_button = _button("Weiter →", _next, true)
	next_button.custom_minimum_size.x = 240
	footer.add_child(next_button)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	_refresh()


func _apply_responsive_layout() -> void:
	if not is_inside_tree() or not is_instance_valid(setup_row):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(get_window().size)
	if (
		viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
		or window_size.x <= 0.0
		or window_size.y <= 0.0
	):
		return
	var ui_scale: float = maxf(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var compact: bool = window_size.x < 760 or window_size.x < window_size.y
	var small: bool = window_size.x < 520
	var short_landscape: bool = window_size.x >= window_size.y and window_size.y < 600
	var margin: float = clampf(minf(window_size.x, window_size.y) * 0.03, 10.0, 28.0)
	_apply_ui_scale(self, ui_scale)
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, roundi(margin * ui_scale))
	var safe_insets := Rect2()
	if (
		(OS.has_feature("android") or OS.has_feature("ios"))
		and not get_parent().get_meta("kart_safe_insets_applied", false)
	):
		safe_insets = MobileRuntime.get_safe_area_insets()
		var screen: Vector2i = DisplayServer.screen_get_size()
		var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe_rect.has_area():
			safe_insets.position.x = maxf(safe_insets.position.x, safe_rect.position.x)
			safe_insets.position.y = maxf(safe_insets.position.y, safe_rect.position.y)
			safe_insets.size.x = maxf(safe_insets.size.x, screen.x - safe_rect.end.x)
			safe_insets.size.y = maxf(safe_insets.size.y, screen.y - safe_rect.end.y)
	var physical_size: Vector2 = Vector2(get_window().size)
	if physical_size.x > 0.0 and physical_size.y > 0.0:
		var scale: Vector2 = viewport_size / physical_size
		page_margin.offset_left = safe_insets.position.x * scale.x
		page_margin.offset_top = safe_insets.position.y * scale.y
		page_margin.offset_right = -safe_insets.size.x * scale.x
		page_margin.offset_bottom = -safe_insets.size.y * scale.y
	# Short landscape screens retain two columns. Stacking the 3D preview below
	# the choices previously pushed the footer outside the Android surface.
	setup_row.columns = 1 if window_size.x < window_size.y else 2
	setup_row.get_child(1).size_flags_vertical = (
		Control.SIZE_FILL if small else Control.SIZE_EXPAND_FILL
	)
	setup_row.add_theme_constant_override(
		"h_separation", roundi((14 if compact else 28) * ui_scale)
	)
	setup_row.add_theme_constant_override("v_separation", roundi((14 if compact else 0) * ui_scale))
	brand_label.custom_minimum_size.x = (150 if small else 260) * ui_scale
	brand_label.add_theme_font_size_override(
		"font_size", roundi((22 if small or short_landscape else 36) * ui_scale)
	)
	for index in range(step_buttons.size()):
		var tab: Button = step_buttons[index]
		tab.text = (
			str(index + 1)
			if small
			else "%d  %s" % [index + 1, ["Modus", "Fahrer", "Kart", "Welt", "Tempo"][index]]
		)
		_set_physical_minimum(tab, Vector2(0, 28 if short_landscape else 38), ui_scale)
		_set_physical_font(tab, 12 if short_landscape else 15, ui_scale)
	progress_label.visible = not small and not short_landscape
	learn_button.text = "Lernen" if small else "Zum Lernen"
	back_button.text = ("Spiele" if small else "Spieleauswahl") if step == 0 else "← Zurück"
	next_button.text = ("Losfahren →" if small else "Rennen starten →") if step == 4 else "Weiter →"
	for child in footer.get_children():
		if child is Button and child.name == "ResumeRace":
			child.text = "Fortsetzen" if compact or short_landscape else "Gespeichertes Rennen"
	learn_button.custom_minimum_size = (
		Vector2(96 if small else 148, 56 if compact else 72) * ui_scale
	)
	footer.columns = 2 if compact else (4 if has_saved_race else 3)
	footer_spacer.visible = not compact
	back_button.custom_minimum_size = (
		Vector2(112 if small else 148, 56 if compact else 72) * ui_scale
	)
	next_button.custom_minimum_size = (
		Vector2(148 if small else 240, 56 if compact else 72) * ui_scale
	)
	for child in footer.get_children():
		if child is Button and child.name == "ResumeRace":
			child.custom_minimum_size = (
				Vector2(112 if small else 148, 56 if compact else 72) * ui_scale
			)
	_set_physical_minimum(header_row, Vector2(0, 36 if short_landscape else 60), ui_scale)
	_set_physical_minimum(
		preview_container,
		(
			Vector2(150, 64 if window_size.y < 440 else 96)
			if short_landscape
			else (Vector2(150, 112) if small else Vector2(250, 185))
		),
		ui_scale
	)
	body_column.add_theme_constant_override(
		"separation", roundi((6 if short_landscape else (8 if small else 16)) * ui_scale)
	)
	_set_physical_font(title_label, 22 if short_landscape else (28 if small else 36), ui_scale)
	_set_physical_font(steps_label, 12 if short_landscape else 15, ui_scale)
	_set_physical_font(subtitle, 14 if small else 18, ui_scale)
	subtitle.visible = not short_landscape
	detail.visible = not short_landscape and not small
	preview_caption.visible = not short_landscape and not small
	preview_title.visible = not short_landscape and not small
	_set_physical_minimum(view_choice, Vector2(0, 44), ui_scale)
	_set_physical_font(view_choice, 14 if short_landscape else 16, ui_scale)
	if short_landscape:
		footer.columns = 3 if has_saved_race else 2
		footer_spacer.hide()
		for button in [learn_button, back_button, next_button]:
			_set_physical_minimum(button, Vector2(148, 44), ui_scale)
			_set_physical_font(button, 16, ui_scale)
		for button in footer.get_children():
			if button is Button and button.name == "ResumeRace":
				_set_physical_minimum(button, Vector2(148, 44), ui_scale)
				_set_physical_font(button, 16, ui_scale)
	else:
		_set_physical_minimum(
			learn_button, Vector2(96 if small else 148, 56 if compact else 72), ui_scale
		)
		_set_physical_minimum(
			back_button, Vector2(112 if small else 148, 56 if compact else 72), ui_scale
		)
		_set_physical_minimum(
			next_button, Vector2(148 if small else 240, 56 if compact else 72), ui_scale
		)
		for button in [learn_button, back_button, next_button]:
			_set_physical_font(button, 19, ui_scale)
		for button in footer.get_children():
			if button is Button and button.name == "ResumeRace":
				_set_physical_minimum(
					button, Vector2(112 if small else 148, 56 if compact else 72), ui_scale
				)
				_set_physical_font(button, 19, ui_scale)
	# The choices are independently scrollable. Keep their first row and the
	# footer usable at320px, while all five modes fit the800x480 layout.
	for child in choices.get_children():
		if child is GridContainer:
			child.columns = 1 if small else 2
		var cards: Array = child.get_children() if child is GridContainer else [child]
		for card in cards:
			if card is Button:
				var tiny: bool = window_size.y < 440
				var height: float = (
					(44 if tiny else 60) if short_landscape else (80 if step == 0 else 74)
				)
				_set_physical_minimum(card, Vector2(0, height), ui_scale)
				_set_physical_font(card, (14 if tiny else 16) if short_landscape else 19, ui_scale)
				if card.has_method("apply_size"):
					card.apply_size(ui_scale, short_landscape)


func _set_physical_minimum(control: Control, physical: Vector2, ui_scale: float) -> void:
	control.set_meta("kart_base_minimum_size", physical)
	control.custom_minimum_size = physical * ui_scale


func _set_physical_font(control: Control, physical: int, ui_scale: float) -> void:
	control.set_meta("kart_base_font_size", physical)
	control.add_theme_font_size_override("font_size", roundi(physical * ui_scale))


func _apply_ui_scale(control: Node, ui_scale: float) -> void:
	if control is Control:
		var ui_control: Control = control
		if not ui_control.has_meta("kart_base_minimum_size"):
			ui_control.set_meta("kart_base_minimum_size", ui_control.custom_minimum_size)
		ui_control.custom_minimum_size = (ui_control.get_meta("kart_base_minimum_size") * ui_scale)
		if ui_control is Label or ui_control is Button:
			if not ui_control.has_meta("kart_base_font_size"):
				ui_control.set_meta(
					"kart_base_font_size", ui_control.get_theme_font_size("font_size")
				)
			ui_control.add_theme_font_size_override(
				"font_size", roundi(float(ui_control.get_meta("kart_base_font_size")) * ui_scale)
			)
	for child in control.get_children():
		_apply_ui_scale(child, ui_scale)


func _glass(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.30, 0.42, 0.96) if selected else Color(0.025, 0.085, 0.18, 0.89)
	style.border_color = Color("65e7f0") if selected else Color(0.4, 0.7, 0.9, 0.26)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(15)
	style.shadow_color = Color(0, 0.02, 0.06, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", UI.HEADING if font_size >= 22 else UI.BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(148, 72)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_font_override("font", UI.HEADING if primary else UI.BODY)
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
		0:
			return CATALOG.MODES
		1:
			return CATALOG.DRIVERS
		2:
			return CATALOG.KARTS
		3:
			return CATALOG.TRACKS
	return CATALOG.DIFFICULTIES


func _refresh() -> void:
	var keys: Array[String] = ["mode", "driver", "kart", "track", "difficulty"]
	var titles: Array[String] = [
		"Dein nächstes Abenteuer",
		"Wer fährt mit?",
		"Dein Kart. Dein Stil.",
		"Wohin geht die Reise?",
		"Finde dein Tempo"
	]
	var descriptions: Array[String] = [
		"Wähle, wie du heute fahren möchtest.",
		"Gemeinsam wird jede Fahrt besonders.",
		"Sterne aus dem Lernen öffnen neue Möglichkeiten.",
		"%d Welten voller kleiner Entdeckungen." % CATALOG.TRACKS.size(),
		"Du kannst das Tempo vor jedem Rennen ändern.",
	]
	title_label.text = titles[step]
	subtitle.text = descriptions[step]
	steps_label.text = "%d / 5     MODUS  ·  FAHRER  ·  KART  ·  WELT  ·  TEMPO" % (step + 1)
	progress_label.text = "★ %d Sterne" % stars
	for index in range(step_buttons.size()):
		var tab_style := _glass(index == step)
		tab_style.content_margin_top = 6
		tab_style.content_margin_bottom = 6
		step_buttons[index].add_theme_stylebox_override("normal", tab_style)
	preview_title.text = "DEINE STRECKE" if step == 3 else "DEINE GARAGE"
	preview_caption.text = (
		"Deine Rennwelt · ziehen zum Drehen"
		if step == 3
		else "Dein Fahrer. Dein Kart. · Ziehen zum Drehen"
	)
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
		var cup_text: String = (
			"KRISTALL-ARENA\n90 Sekunden · Kristalle sammeln · Rivalen überholen"
			if setup.mode == "arena"
			else (
				"DER STERNEN-CUP\n%d Rennen · %d Welten · ein Sternenpokal"
				% [CATALOG.TRACKS.size(), CATALOG.TRACKS.size()]
			)
		)
		var card := _button(cup_text, func(): pass, true)
		card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.custom_minimum_size.y = 110
		choices.add_child(card)
	else:
		for item in _entries():
			var unlocked: bool = CATALOG.unlocked(item, stars, unlocked_ids)
			var selected: bool = setup[key] == item.id
			var card := CHOICE.new()
			card.title = str(item.name)
			card.caption = (
				str(item.tag).to_lower().capitalize()
				if unlocked
				else "Ab %d Sternen" % int(item.unlock)
			)
			var icon_name: String = (
				{
					"race": "race",
					"cup": "cup",
					"time_trial": "clock",
					"training": "practice",
					"arena": "arena"
				}
				. get(str(item.id), "world" if step == 3 else "kart")
			)
			card.artwork = load("res://assets/kart/menu/" + icon_name + ".svg")
			if step == 1:
				card.artwork = preload("res://assets/kart/controls/steering.svg")
			card.add_theme_stylebox_override("normal", _glass(selected))
			card.add_theme_stylebox_override("hover", _glass(true))
			card.add_theme_stylebox_override("pressed", _glass(true))
			card.add_theme_stylebox_override("focus", _glass(true))
			card.add_theme_stylebox_override("disabled", _glass(false))
			card.pressed.connect(func(): _select(key, str(item.id)))
			card.custom_minimum_size = Vector2(0, 94 if step == 0 else 74)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.disabled = not unlocked
			card_parent.add_child(card)
	var selected_entry: Dictionary = CATALOG.entry(_entries(), str(setup[key]))
	detail.text = str(selected_entry.get("description", selected_entry.get("tag", "")))
	if step == 3 and setup.mode == "cup":
		detail.text = (
			"%d Rennen. Eine Gesamtwertung. Dein Sternenpokal wartet." % CATALOG.TRACKS.size()
		)
	elif step == 3 and setup.mode == "arena":
		detail.text = "Frei fahren und Kristalle sammeln. Nach 90 Sekunden gewinnt die höchste Punktzahl."
	back_button.text = "Spieleauswahl" if step == 0 else "← Zurück"
	next_button.text = "Rennen starten →" if step == 4 else "Weiter →"
	_refresh_preview()
	_apply_responsive_layout.call_deferred()


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
	var signature: String = str(setup.driver) + str(setup.kart) + str(setup.track) + str(step == 3)
	if signature == preview_signature:
		return
	preview_signature = signature
	if is_instance_valid(preview_world):
		preview_pivot.remove_child(preview_world)
		preview_world.queue_free()
		preview_world = null
	if is_instance_valid(preview_kart):
		preview_pivot.remove_child(preview_kart)
		preview_kart.queue_free()
	preview_kart = VEHICLE.new()
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, str(setup.driver))
	preview_kart.configure(str(setup.driver), driver.color, str(setup.kart))
	preview_kart.reduced_motion = reduced_motion
	preview_kart.set_graphics_quality(graphics_profile)
	preview_pivot.add_child(preview_kart)
	preview_kart.visible = step != 3
	preview_camera.position = Vector3(3.2, 3.2, -4.5) if step == 3 else Vector3(3.2, 2.2, -4.5)
	preview_camera.look_at(Vector3(0, 0.15 if step == 3 else 0.85, 0))
	view_choice.disabled = step == 3
	if step == 3:
		preview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if step != 3:
		_choose_preview_view(inspection_view)
	if step == 3:
		preview_world = WORLD.new()
		# The garage owns lighting. Never allocate and immediately discard a Sky
		# for a diorama: GLES3 can still have its radiance update queued.
		preview_world.build(true, str(setup.track), true)
		for child in preview_world.get_children():
			if (
				child is WorldEnvironment
				or child is Light3D
				or (child is MeshInstance3D and child.mesh is PlaneMesh)
			):
				preview_world.remove_child(child)
				child.queue_free()
		preview_world.scale = Vector3.ONE * 0.010
		preview_world.position.y = 0.12
		preview_pivot.add_child(preview_world)


func _preview_input(event: InputEvent) -> void:
	if inspection_view != 0 and event is InputEventScreenDrag:
		_choose_preview_view(0)
	elif inspection_view != 0 and event is InputEventMouseButton and event.pressed:
		_choose_preview_view(0)
	if event is InputEventMouseButton:
		rotate_drag = event.pressed
	elif event is InputEventMouseMotion and rotate_drag:
		preview_angle += event.relative.x * 0.008
	elif event is InputEventScreenDrag:
		preview_angle += event.relative.x * 0.008


func _process(delta: float) -> void:
	if not visible or not is_instance_valid(preview_pivot):
		return
	if not rotate_drag and not reduced_motion and inspection_view == 0:
		preview_angle += delta * 0.14
	preview_pivot.rotation.y = preview_angle


func _choose_preview_view(index: int) -> void:
	inspection_view = clampi(index, 0, 5)
	view_choice.select(inspection_view)
	if step == 3:
		return
	var views: Array[Vector3] = [
		Vector3(3.2, 2.2, -4.5), Vector3(0, 1.2, -5.6),
		Vector3(-5.6, 1.2, 0), Vector3(0, 1.2, 5.6),
		Vector3(5.6, 1.2, 0), Vector3(0, 6.0, 0)
	]
	preview_camera.position = views[inspection_view]
	preview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if inspection_view == 0 else Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = 3.9 if inspection_view == 5 else 3.5
	preview_camera.look_at(Vector3(0, 0.85, 0), Vector3.FORWARD if inspection_view == 5 else Vector3.UP)
	if inspection_view != 0:
		preview_angle = 0.0
		preview_pivot.rotation.y = 0.0

