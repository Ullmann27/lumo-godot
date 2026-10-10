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
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const CARD = preload("res://scripts/games/kart_vehicle_card.gd")
const BARS = preload("res://scripts/games/kart_stat_bars.gd")
const WORKSHOP = preload("res://scripts/games/kart_workshop.gd")
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
## Tuning-Werkstatt des Kindes (Stufen, Aussehen, Sterne); vom Spiel gesetzt.
var workshop
var workshop_view: Control
var preview_viewport: SubViewport
var kart_panel: VBoxContainer
var kart_bars
var workshop_button: Button
var kart_summary: Label
var has_saved_race: bool = false
var choices: VBoxContainer
var setup_row: GridContainer
var setup_left: VBoxContainer
var setup_right: VBoxContainer
var page_margin: MarginContainer
var brand_label: Label
var brand_kart: Label
var brand_motto: Label
var brand_stack: VBoxContainer
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
var preview_angle: float = -0.25
var preview_signature: String = ""
var preview_caption: Label
var reduced_motion: bool = false
var graphics_profile: String = "high"
var progress_label: Label
var progress_panel: PanelContainer
var body_column: VBoxContainer
var header_row: HBoxContainer
var kart_head_row: HBoxContainer
var preview_container: SubViewportContainer
var step_strip: HBoxContainer
var step_buttons: Array[Button] = []
var preview_world: Node3D
var preview_title: Label
var preview_camera: Camera3D
var view_choice: OptionButton
var inspection_view: int = 0
var quick_start_button: Button
var preview_idle_time: float = 0.0


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
	veil.color = Color(1, 1, 1, 1)
	var shade := Shader.new()
	shade.code = "shader_type canvas_item; void fragment() { float left = smoothstep(0.82, 0.0, UV.x); float top = 1.0 - smoothstep(0.0, 0.24, UV.y); COLOR = vec4(0.008, 0.020, 0.095, max(left * 0.27, top * 0.07)); }"
	var shade_material := ShaderMaterial.new()
	shade_material.shader = shade
	veil.material = shade_material
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
	body.add_theme_constant_override("separation", 10)
	page_margin.add_child(body)
	# Full-bleed fantasy-world landing page: the five real steps and live 3D kart remain intact.
	var header_shell := PanelContainer.new()
	header_shell.name = "LumoPremiumHeader"
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.018, 0.14, 0.33, 0.0)
	header_style.border_color = Color("53ddfd")
	header_style.set_border_width_all(0)
	header_style.set_corner_radius_all(16)
	header_style.set_content_margin_all(2)
	header_shell.add_theme_stylebox_override("panel", header_style)
	body.add_child(header_shell)
	var header := HBoxContainer.new()
	header_row = header
	header.custom_minimum_size.y = 104
	brand_stack = VBoxContainer.new()
	brand_stack.name = "LumoKartWordmark"
	brand_stack.add_theme_constant_override("separation", -12)
	header.add_child(brand_stack)
	brand_label = _label("Lumo ★", 52, Color("ffca40"))
	brand_label.add_theme_color_override("font_outline_color", Color("7134b4"))
	brand_label.add_theme_constant_override("outline_size", 5)
	brand_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.24, 0.76))
	brand_label.add_theme_constant_override("shadow_offset_x", 3)
	brand_label.add_theme_constant_override("shadow_offset_y", 5)
	brand_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_label.custom_minimum_size.x = 245
	brand_stack.add_child(brand_label)
	brand_kart = _label("KART 🏁", 39, Color("66f6ff"))
	brand_kart.add_theme_color_override("font_outline_color", Color("134fba"))
	brand_kart.add_theme_constant_override("outline_size", 5)
	brand_kart.add_theme_color_override("font_shadow_color", Color(0.01, 0.06, 0.22, 0.8))
	brand_kart.add_theme_constant_override("shadow_offset_y", 4)
	brand_kart.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_stack.add_child(brand_kart)
	brand_motto = _label("KLEINE SCHRITTE · GROSSE ZIELE ★", 11, Color("ecf6ff"))
	brand_motto.add_theme_color_override("font_outline_color", Color("1a325e"))
	brand_motto.add_theme_constant_override("outline_size", 3)
	brand_motto.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_stack.add_child(brand_motto)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	progress_panel = PanelContainer.new()
	progress_panel.name = "ActualLearningRewards"
	progress_panel.add_theme_stylebox_override("panel", _status_glass())
	header.add_child(progress_panel)
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 10)
	progress_panel.add_child(reward_row)
	var reward_icon := _label("★", 27, Color("ffe16b"))
	reward_row.add_child(reward_icon)
	progress_label = _label("", 17, Color("f6f9ff"))
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward_row.add_child(progress_label)
	learn_button = _button("Zum Lernen", func(): exit_requested.emit("learn"), false)
	learn_button.add_theme_stylebox_override("normal", _status_glass())
	reward_row.add_child(learn_button)
	header_shell.add_child(header)
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
			var tab_style := _step_glass(index == step)
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
	setup_left = left
	left.size_flags_horizontal = Control.SIZE_FILL
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
	setup_right = right
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_row.add_child(right)
	preview_title = _label("DEINE GARAGE", 16, Color("74e5f5"))
	right.add_child(preview_title)
	var viewport_panel := PanelContainer.new()
	viewport_panel.add_theme_stylebox_override("panel", _clear_panel())
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
	# Keep the real 3D face/kart preview crisp on the high-quality profile.
	viewport.msaa_3d = Viewport.MSAA_4X if graphics_profile == "high" else Viewport.MSAA_2X
	viewport_box.add_child(viewport)
	preview_viewport = viewport
	preview = Node3D.new()
	viewport.add_child(preview)
	# The reference floats the real kart on transparent neon rings, not an opaque studio slab.
	var built: Dictionary = STAGE.build(preview, Color("56e7ff"), false)
	_install_hologram_rings(preview)
	var hero_fill := OmniLight3D.new()
	hero_fill.name = "PremiumLumoSoftLight"
	hero_fill.position = Vector3(1.2, 2.7, -2.4)
	hero_fill.light_color = Color("fff6e7")
	hero_fill.light_energy = 1.45
	hero_fill.omni_range = 6.0
	hero_fill.shadow_enabled = false
	preview.add_child(hero_fill)
	preview_camera = built.camera
	preview_pivot = built.pivot
	preview_caption = _label("☞ Dein Fahrer · Dein Kart · Ziehen zum Drehen ↺", 14, Color("e2f6ff"))
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(preview_caption)
	quick_start_button = _button("Spielen", func(): start_requested.emit(setup.duplicate(true)), true)
	quick_start_button.name = "PlaySelectedRace"
	right.add_child(quick_start_button)
	kart_panel = VBoxContainer.new()
	kart_panel.add_theme_constant_override("separation", 6)
	kart_panel.visible = false
	right.add_child(kart_panel)
	var kart_head := HBoxContainer.new()
	kart_head_row = kart_head
	kart_head.add_theme_constant_override("separation", 10)
	kart_panel.add_child(kart_head)
	kart_summary = _label("", 16, Color("dceaff"))
	kart_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	kart_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	kart_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kart_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kart_head.add_child(kart_summary)
	workshop_button = _button("Werkstatt", _open_workshop, true)
	workshop_button.name = "WorkshopButton"
	workshop_button.custom_minimum_size = Vector2(190, 52)
	kart_head.add_child(workshop_button)
	kart_bars = BARS.new()
	kart_bars.name = "KartStats"
	kart_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kart_bars.reduced_motion = reduced_motion
	kart_panel.add_child(kart_bars)
	view_choice = OptionButton.new()
	view_choice.name = "KartInspectionView"
	view_choice.tooltip_text = "Dein Kart von allen Seiten ansehen"
	view_choice.custom_minimum_size.y = 44
	for title in ["Rundum ansehen", "Vorne", "Links", "Hinten", "Rechts", "Von oben", "Lumos Gesicht"]:
		view_choice.add_item(title)
	view_choice.item_selected.connect(_choose_preview_view)
	# Overlay the existing preview instead of adding height to the setup column.
	# A separate row would push the footer below short Android safe areas.
	var inspection_overlay := Control.new()
	inspection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_panel.add_child(inspection_overlay)
	# A default Control has zero size. Its TOP_RIGHT-anchored child then
	# escapes the entire panel at 800x480 once Android safe insets apply.
	# Fill the preview panel, but keep both the overlay and its child clickable.
	inspection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspection_overlay.add_child(view_choice)
	view_choice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
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
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		next_button.add_theme_stylebox_override(state, _gold_glass(state in ["hover", "pressed", "focus"]))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		next_button.add_theme_color_override(state, Color("2c2c51"))
	next_button.name = "PremiumNextStep"
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
	var panoramic: bool = window_size.x >= 1000 and window_size.x > window_size.y
	var welcome_in_header: bool = step == 0 and short_landscape and window_size.y < 440
	var margin: float = clampf(minf(window_size.x, window_size.y) * 0.024, 8.0, 24.0)
	# The reward pill was forcing a 76 px toolbar on a 360 px Fold surface:
	# its 10 px panel margins sat OUTSIDE the minimum height of the child.
	var reward_style: StyleBoxFlat = progress_panel.get_theme_stylebox("panel") as StyleBoxFlat
	reward_style.set_content_margin_all(2 if short_landscape else 10)
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
	# In portrait, the driver/kart preview must be a hero ABOVE the scrolling
	# fleet. Otherwise fourteen cards push the character below the fold.
	# Keep the original ordering for modes, tracks and landscape controls.
	var portrait: bool = window_size.x < window_size.y
	setup_row.columns = 1 if portrait else 2
	setup_left.custom_minimum_size.x = (398.0 if panoramic else (175.0 if short_landscape else 0.0)) * ui_scale
	setup_right.custom_minimum_size.x = (455.0 if panoramic else (255.0 if short_landscape else 0.0)) * ui_scale
	var driver_hero: bool = portrait and step in [0, 1, 2]
	var first: Control = setup_right if driver_hero else setup_left
	if setup_row.get_child(0) != first:
		setup_row.move_child(first, 0)
	setup_right.size_flags_vertical = (
		Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	)
	setup_row.add_theme_constant_override(
		"h_separation", roundi((14 if compact else 28) * ui_scale)
	)
	setup_row.add_theme_constant_override("v_separation", roundi((14 if compact else 0) * ui_scale))
	brand_label.custom_minimum_size.x = (120 if small or welcome_in_header else 245) * ui_scale
	_set_physical_font(brand_label, 21 if short_landscape else (25 if small else 47), ui_scale)
	_set_physical_font(brand_kart, 18 if short_landscape else (23 if small else 38), ui_scale)
	_set_physical_font(brand_motto, 8 if small or short_landscape else 11, ui_scale)
	brand_motto.visible = not small and not short_landscape
	brand_stack.add_theme_constant_override("separation", roundi((-5 if short_landscape or small else -12) * ui_scale))
	for index in range(step_buttons.size()):
		var tab: Button = step_buttons[index]
		tab.text = (
			str(index + 1)
			if small
			else "%d  %s" % [index + 1, ["Modus", "Fahrer", "Kart", "Welt", "Tempo"][index]]
		)
		_set_physical_minimum(tab, Vector2(0, 24 if short_landscape else 38), ui_scale)
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
	_set_physical_minimum(header_row, Vector2(0, (35 if window_size.y < 360 else 44) if short_landscape else (60 if small else 100)), ui_scale)
	_set_physical_minimum(
		preview_container,
		(
			Vector2(150, (50 if window_size.y < 360 else 64) if window_size.y < 440 else 96)
			if short_landscape
			else (Vector2(150, 112) if small else Vector2(250, 185))
		),
		ui_scale
	)
	body_column.add_theme_constant_override(
		"separation", roundi((3 if short_landscape else (8 if small else 12)) * ui_scale)
	)
	_set_physical_font(
		title_label,
		(18 if short_landscape else (28 if small or panoramic else 36)),
		ui_scale
	)
	# Compact Fold cover: never squeeze a long heading into a vertical letter column.
	if step == 0:
		title_label.text = "Dein Abenteuer" if short_landscape else "Dein nächstes Abenteuer"
		if panoramic:
			subtitle.text = "Wähle, wie du heute fahren möchtest."
	_set_physical_font(steps_label, 12 if short_landscape else 15, ui_scale)
	_set_physical_font(subtitle, 14 if small else 18, ui_scale)
	subtitle.visible = not short_landscape
	# The welcome's direct Play action adds a row. On an inset Android surface
	# reserve the existing footer before showing the extra mode description.
	# The selected mode title/tag and the five-step setup remain available.
	detail.visible = (
		not short_landscape
		and not small
		and step != 2
		and step != 0
	)
	# Kleine Querformate: Der Werkstatt-Knopf rückt in die Kopfzeile, damit die Kartseite samt
	# Vorschau und Weiter-Knopf auf eine Bildschirmhöhe passt.
	var workshop_in_header: bool = short_landscape and step == 2
	var workshop_parent: HBoxContainer = header_row if workshop_in_header else kart_head_row
	if workshop_button.get_parent() != workshop_parent:
		workshop_button.reparent(workshop_parent, false)
		if workshop_in_header:
			header_row.move_child(workshop_button, learn_button.get_index())
	workshop_button.visible = step == 2
	kart_panel.visible = step == 2 and not short_landscape
	kart_summary.visible = not short_landscape
	# Hochformat und Fold-Innendisplay: Die Karten brauchen den Platz, die Werte stehen schon auf ihnen.
	var stacked: bool = window_size.x < window_size.y
	kart_bars.visible = not short_landscape and not (stacked and step == 2)
	if panoramic and step == 0:
		# Fill the hero half while retaining both footer controls in the safe area.
		_set_physical_minimum(preview_container, Vector2(430, clampf(window_size.y * 0.47, 298.0, 420.0)), ui_scale)
	if stacked and step in [0, 1, 2]:
		# Bounded height: legible face on Cover/phone but the action footer
		# and at least one selectable card remain in the actual safe area.
		var hero_height: float = clampf(
			window_size.y * (0.235 if step == 2 else 0.20), 120.0, 215.0
		)
		_set_physical_minimum(preview_container, Vector2(150, hero_height), ui_scale)
		if step == 0:
			_set_physical_minimum(preview_container, Vector2(150, clampf(window_size.y * 0.175, 90, 160)), ui_scale)
	# Auf niedrigen Querformaten (z. B. 1280×720 mit Systemleisten) braucht die Kartseite den Platz
	# für Vorschau, Werte und Werkstatt-Knopf; Überschrift und Hinweis entfallen dort.
	var tight_kart_page: bool = step == 2 and window_size.x >= window_size.y and window_size.y < 800
	kart_bars.row_height = (16.0 if small or tight_kart_page else 21.0) * ui_scale
	kart_bars.font_scale = ui_scale
	_set_physical_minimum(workshop_button, Vector2(160 if short_landscape else (120 if small else 190), 44 if short_landscape else 52), ui_scale)
	_set_physical_font(workshop_button, 15 if short_landscape else 18, ui_scale)
	preview_caption.visible = (step == 0 and panoramic) or (step != 0 and not short_landscape and not small and not tight_kart_page)
	preview_title.visible = step != 0 and not short_landscape and not small and not tight_kart_page
	_set_physical_minimum(view_choice, Vector2(0, 44), ui_scale)
	_set_physical_font(view_choice, 14 if short_landscape else 16, ui_scale)
	view_choice.set_item_text(0, "Rundum" if short_landscape else "Rundum ansehen")
	view_choice.set_item_text(5, "Oben" if short_landscape else "Von oben")
	# Do not cover Lumos ears in a compact portrait preview.
	view_choice.set_item_text(6, "Gesicht" if small else "Lumos Gesicht")
	# Godot honours the left anchor first and expands the OptionButton to its
	# true text minimum width (182 px at 800x480). Reserve additional room
	# from the right edge rather than relying only on offset_right.
	view_choice.offset_left = -(124 if short_landscape else (96 if small else 176)) * ui_scale
	# Keep the real OptionButton minimum width inside Fold/Android safe-area.
	# At 800x480 its 182 logical pixels previously exceeded the safe right edge by 3.2.
	view_choice.offset_right = -20 * ui_scale
	view_choice.offset_top = 4 * ui_scale
	view_choice.offset_bottom = 48 * ui_scale
	view_choice.visible = step in [1, 2]
	# On very short Android surfaces the direct Play action shares the existing
	# header row, leaving the live preview and the full setup footer reachable.
	var quick_in_footer: bool = panoramic and step == 0
	var quick_parent: Control = (
		footer_spacer if quick_in_footer
		else (header_row if welcome_in_header else setup_right)
	)
	if quick_start_button.get_parent() != quick_parent:
		quick_start_button.reparent(quick_parent, false)
		if welcome_in_header:
			header_row.move_child(quick_start_button, learn_button.get_index())
		elif not quick_in_footer:
			setup_right.move_child(quick_start_button, preview_caption.get_index() + 1)
	quick_start_button.text = (
		"Spielen"
		if welcome_in_header
		else "Spielen · " + str(CATALOG.entry(CATALOG.MODES, str(setup.mode)).get("name", "Einzelrennen"))
	)
	# The reference has a single yellow Weiter action. Keep the shortcut
	# connected for future flows, but hide its competing cyan/full-screen bar.
	quick_start_button.visible = false
	if quick_in_footer:
		quick_start_button.size = Vector2(260, 44) * ui_scale
		quick_start_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		for state in ["normal", "hover", "pressed", "focus"]:
			quick_start_button.add_theme_stylebox_override(state, _text_only_glass(state != "normal"))
	else:
		for state in ["normal", "hover", "pressed", "focus"]:
			quick_start_button.add_theme_stylebox_override(state, _glass(state != "normal"))
	_set_physical_minimum(quick_start_button, Vector2(235 if quick_in_footer else (104 if welcome_in_header else 0), 44 if step == 0 or small or short_landscape else 56), ui_scale)
	_set_physical_font(quick_start_button, 17 if short_landscape or small else 20, ui_scale)
	if short_landscape and step == 0:
		# Larger real character; maintain enough distance to keep both ears visible.
		preview_camera.position = Vector3(2.85, 2.08, -4.36)
		preview_camera.fov = 43.0
		preview_camera.look_at(Vector3(0, 0.96, 0))
	if short_landscape:
		footer.columns = 3 if has_saved_race else 2
		footer_spacer.hide()
		_set_physical_minimum(learn_button, Vector2(100, 34), ui_scale)
		_set_physical_font(learn_button, 14, ui_scale)
		for button in [back_button, next_button]:
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
			child.columns = 1 if step == 0 or small else 2
		var cards: Array = child.get_children() if child is GridContainer else [child]
		for card in cards:
			if card is Button:
				var tiny: bool = window_size.y < 440
				var height: float = (
					(28 if window_size.y < 400 else (30 if window_size.y < 520 else 40)) if short_landscape and step == 0
					else (42 if window_size.y < 520 else 58) if short_landscape
					else ((50 if window_size.y < 800 else 76) if step == 0 else 74)
				)
				if step == 2:
					height = 74 if short_landscape else 118
				_set_physical_minimum(card, Vector2(0, height), ui_scale)
				_set_physical_font(card, (14 if tiny else 16) if short_landscape else 19, ui_scale)
				if card.has_method("apply_size"):
					if step == 0:
						card.apply_size(ui_scale, short_landscape, window_size.y < 800 and not short_landscape)
					else:
						card.apply_size(ui_scale, short_landscape)
	# A saved race adds a second footer row on a small portrait phone.
	# Reserve usable space for the scrolling mode choices, not just the hero.
	if portrait and window_size.y < 680 and step == 0:
		_set_physical_minimum(preview_container, Vector2(150, 80), ui_scale)
		_set_physical_minimum(header_row, Vector2(0, 44), ui_scale)
		_set_physical_font(title_label, 22, ui_scale)
		subtitle.hide()
		body_column.add_theme_constant_override("separation", roundi(6 * ui_scale))
		_set_physical_minimum(learn_button, Vector2(96, 44), ui_scale)
		_set_physical_font(learn_button, 16, ui_scale)
		for button in footer.get_children():
			if button is Button:
				_set_physical_minimum(button, Vector2(112, 44), ui_scale)
				_set_physical_font(button, 16, ui_scale)
	# Font/minimum-size changes above can temporarily force the margin wider
	# than the window. Reapply its safe-area edges after queued size updates.
	var inset_scale: Vector2 = viewport_size / physical_size
	page_margin.set_deferred("offset_left", safe_insets.position.x * inset_scale.x)
	page_margin.set_deferred("offset_top", safe_insets.position.y * inset_scale.y)
	page_margin.set_deferred("offset_right", -safe_insets.size.x * inset_scale.x)
	page_margin.set_deferred("offset_bottom", -safe_insets.size.y * inset_scale.y)
	page_margin.set_deferred("size", size - (safe_insets.position + safe_insets.size) * inset_scale)


func _set_physical_minimum(control: Control, physical: Vector2, ui_scale: float) -> void:
	control.set_meta("kart_base_minimum_size", physical)
	control.custom_minimum_size = physical * ui_scale


func _set_physical_font(control: Control, physical: int, ui_scale: float) -> void:
	control.set_meta("kart_base_font_size", physical)
	control.add_theme_font_size_override("font_size", roundi(physical * ui_scale))


func _apply_ui_scale(control: Node, ui_scale: float) -> void:
	# Wertebalken und Kartkarten skalieren sich selbst (row_height, apply_size); ein zweites
	# Skalieren hier würde kurz alte Mindestgrößen setzen und die Seite dauerhaft strecken.
	if control.has_meta("kart_self_sized"):
		return
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


func _install_hologram_rings(stage: Node3D) -> void:
	# All rings are actual lit 3D meshes. There is deliberately NO opaque podium.
	for radius in [1.80, 2.15, 2.54]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius
		torus.outer_radius = radius + 0.033
		torus.rings = 64
		ring.mesh = torus
		ring.position.y = -0.12
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("79fbff")
		material.emission_enabled = true
		material.emission = Color("39dfff")
		material.emission_energy_multiplier = 3.1
		ring.material_override = material
		stage.add_child(ring)


func _text_only_glass(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.1, 0.24, 0.38) if hovered else Color(0, 0, 0, 0)
	style.border_color = Color(0.16, 0.85, 1.0, 0.6) if hovered else Color(0, 0, 0, 0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(5)
	return style


func _clear_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_content_margin_all(0)
	return style


func _status_glass() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.11, 0.28, 0.89)
	style.border_color = Color(0.35, 0.83, 1.0, 0.66)
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(10)
	return style


func _step_glass(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.66, 0.82, 0.96) if active else Color(0.018, 0.11, 0.27, 0.82)
	style.border_color = Color("a4fcff") if active else Color(0.33, 0.75, 0.94, 0.40)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0.04, 0.85, 0.99, 0.24) if active else Color(0, 0, 0, 0.14)
	style.shadow_size = 7
	return style


func _mode_glass(mode_id: String, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base: Color = {
		"race": Color("117d9e"),
		"time_trial": Color("17499d"),
		"arena": Color("633096"),
		"cup": Color("12294f"),
		"training": Color("102846")
	}.get(mode_id, Color("183857"))
	style.bg_color = base.lightened(0.12) if selected else base
	style.bg_color.a = 0.94
	style.border_color = Color("8dfbff") if selected else base.lightened(0.32)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(23)
	# The card itself already has custom inner margins. An extra 8 px on ALL
	# edges increased five compact buttons by 12–16 px each and clipped #5.
	style.set_content_margin_all(2)
	style.shadow_color = Color(0.05, 0.85, 1.0, 0.42) if selected else Color(0, 0.02, 0.1, 0.48)
	style.shadow_size = 11 if selected else 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _gold_glass(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff072") if hovered else Color("ffd645")
	style.border_color = Color("fff8ba")
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	style.set_content_margin_all(10)
	style.shadow_color = Color(1.0, 0.65, 0.08, 0.55)
	style.shadow_size = 15 if hovered else 10
	style.shadow_offset = Vector2(0, 3)
	return style


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
			# Reference order: race, time, arena, cup, free play. Gameplay IDs stay untouched.
			return [CATALOG.MODES[0], CATALOG.MODES[2], CATALOG.MODES[4], CATALOG.MODES[1], CATALOG.MODES[3]]
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
		"Fahre direkt los oder stelle dein Rennen zusammen.",
		"Gemeinsam wird jede Fahrt besonders.",
		"Sterne aus dem Lernen öffnen neue Möglichkeiten.",
		"%d Welten voller kleiner Entdeckungen." % CATALOG.TRACKS.size(),
		"Du kannst das Tempo vor jedem Rennen ändern.",
	]
	title_label.text = titles[step]
	subtitle.text = descriptions[step]
	steps_label.text = "%d / 5     MODUS  ·  FAHRER  ·  KART  ·  WELT  ·  TEMPO" % (step + 1)
	progress_label.text = "%d Sterne" % stars
	for index in range(step_buttons.size()):
		var tab_style := _step_glass(index == step)
		tab_style.content_margin_top = 6
		tab_style.content_margin_bottom = 6
		step_buttons[index].add_theme_stylebox_override("normal", tab_style)
	preview_title.text = "DEINE STRECKE" if step == 3 else "DEINE GARAGE"
	if step == 0:
		preview_title.text = "LUMO IST STARTKLAR"
	preview_caption.text = (
		"Deine Rennwelt · ziehen zum Drehen" if step == 3
		else "☞ Dein Fahrer · Dein Kart · Ziehen zum Drehen ↺"
	)
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var key: String = keys[step]
	var card_parent: Container = choices
	if step == 0 or step == 2:
		var grid := GridContainer.new()
		grid.columns = 1 if step == 0 else 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 3)
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
			if step == 2:
				var kart_card := CARD.new()
				kart_card.item = item
				kart_card.locked = not unlocked
				kart_card.missing_stars = maxi(0, int(item.unlock) - stars)
				kart_card.stats = FLEET.base_stats(str(item.id))
				kart_card.bonus = _bonus_for(str(item.id))
				kart_card.tuning_level = workshop.total_level(str(item.id)) if workshop != null else 0
				kart_card.name = "KartCard_" + str(item.id)
				kart_card.add_theme_stylebox_override("normal", _glass(selected))
				kart_card.add_theme_stylebox_override("hover", _glass(true))
				kart_card.add_theme_stylebox_override("pressed", _glass(true))
				kart_card.add_theme_stylebox_override("focus", _glass(true))
				kart_card.add_theme_stylebox_override("disabled", _glass(false))
				kart_card.pressed.connect(func(): _select(key, str(item.id)))
				kart_card.custom_minimum_size = Vector2(0, 118)
				kart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				kart_card.disabled = not unlocked
				card_parent.add_child(kart_card)
				continue
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
			elif step == 2:
				# Portraits are rendered from these exact selectable game models.
				card.artwork = load("res://assets/kart/menu/fleet/" + str(item.id) + ".webp")
			card.add_theme_stylebox_override("normal", _mode_glass(str(item.id), selected) if step == 0 else _glass(selected))
			card.add_theme_stylebox_override("hover", _mode_glass(str(item.id), true) if step == 0 else _glass(true))
			card.add_theme_stylebox_override("pressed", _mode_glass(str(item.id), true) if step == 0 else _glass(true))
			card.add_theme_stylebox_override("focus", _mode_glass(str(item.id), true) if step == 0 else _glass(true))
			card.add_theme_stylebox_override("disabled", _mode_glass(str(item.id), false) if step == 0 else _glass(false))
			card.pressed.connect(func(): _select(key, str(item.id)))
			card.custom_minimum_size = Vector2(0, 80 if step == 0 else 74)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.disabled = not unlocked
			card_parent.add_child(card)
	var selected_entry: Dictionary = CATALOG.entry(_entries(), str(setup[key]))
	if step == 0:
		quick_start_button.text = "Spielen · " + str(selected_entry.get("name", "Einzelrennen"))
	detail.text = str(selected_entry.get("description", selected_entry.get("tag", "")))
	_refresh_kart_panel()
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
	# Gesperrtes (zu wenige Sterne) lässt sich nicht wählen, auch nicht per Tastatur oder Skript.
	var entry: Dictionary = CATALOG.entry(_entries(), value)
	if str(entry.get("id", "")) == value and not CATALOG.unlocked(entry, stars, unlocked_ids):
		return
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
	var context: String = "welcome" if step == 0 else ("world" if step == 3 else "garage")
	var signature: String = str(setup.driver) + str(setup.kart) + str(setup.track) + context + (str(workshop.look(str(setup.kart))) if workshop != null else "")
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
	if workshop != null:
		preview_kart.set_look(workshop.look(str(setup.kart)))
	preview_kart.configure(str(setup.driver), driver.color, str(setup.kart))
	preview_kart.reduced_motion = reduced_motion
	preview_kart.set_graphics_quality(graphics_profile)
	# Quality is applied only to the small independent 3D menu viewport, not to gameplay.
	preview_viewport.msaa_3d = (
		Viewport.MSAA_4X
		if graphics_profile == "high"
		else (Viewport.MSAA_2X if graphics_profile == "medium" else Viewport.MSAA_DISABLED)
	)
	preview_pivot.add_child(preview_kart)
	preview_kart.visible = step != 3
	preview_camera.position = Vector3(3.2, 3.2, -4.5) if step == 3 else Vector3(2.4, 2.05, -4.4)
	preview_camera.look_at(Vector3(0, 0.15 if step == 3 else 0.85, 0))
	view_choice.disabled = step == 3
	if step == 3:
		preview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if step != 3:
		if step == 0:
			preview_angle = -0.25
			preview_idle_time = 0.0
		_choose_preview_view(0 if step == 0 else inspection_view)
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
		if step == 0:
			preview_idle_time += delta
		else:
			preview_angle += delta * 0.14
	# The welcome camera breathes through a small arc instead of turning
	# Lumos back to the child. Dragging and garage inspection remain unrestricted.
	var idle_arc: float = sin(preview_idle_time * 0.35) * 0.085 if step == 0 and not reduced_motion and not rotate_drag else 0.0
	preview_pivot.rotation.y = preview_angle + idle_arc


func _bonus_for(kart_id: String) -> Dictionary:
	if workshop == null:
		return {}
	var extra: Dictionary = workshop.bonus(kart_id)
	var base: Dictionary = FLEET.base_stats(kart_id)
	for key in FLEET.STATS:
		extra[key] = minf(float(extra[key]), maxf(0.0, FLEET.MAX_STAT - float(base[key])))
	return extra


func _refresh_kart_panel() -> void:
	if step != 2:
		return
	var id: String = str(setup.kart)
	var item: Dictionary = FLEET.entry(id)
	var level: int = workshop.total_level(id) if workshop != null else 0
	kart_summary.text = "%s · %s%s" % [item.name, item.role, " · Tuning %d" % level if level > 0 else ""]
	kart_bars.set_values(FLEET.base_stats(id), _bonus_for(id))
	workshop_button.disabled = workshop == null or not CATALOG.unlocked(item, stars, unlocked_ids)
	workshop_button.text = "Werkstatt · ★ %d" % workshop.available() if workshop != null else "Werkstatt"


func _open_workshop() -> void:
	if workshop == null or is_instance_valid(workshop_view):
		return
	workshop_view = WORKSHOP.new()
	workshop_view.tuning = workshop
	workshop_view.kart_id = str(setup.kart)
	workshop_view.driver_id = str(setup.driver)
	workshop_view.reduced_motion = reduced_motion
	workshop_view.graphics_profile = graphics_profile
	workshop_view.name = "Workshop"
	workshop_view.closed.connect(_close_workshop)
	workshop_view.changed.connect(_on_workshop_changed)
	add_child(workshop_view)
	if is_instance_valid(preview_viewport):
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _close_workshop() -> void:
	if is_instance_valid(workshop_view):
		workshop_view.queue_free()
		workshop_view = null
	if is_instance_valid(preview_viewport):
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_signature = ""
	_refresh()


func _on_workshop_changed() -> void:
	preview_signature = ""


## Android-Zurück schließt zuerst die Werkstatt; false = Garage kümmert sich nicht darum.
func handle_back() -> bool:
	if is_instance_valid(workshop_view):
		_close_workshop()
		return true
	return false


func _choose_preview_view(index: int) -> void:
	inspection_view = clampi(index, 0, 6)
	view_choice.select(inspection_view)
	if step == 3:
		return
	var views: Array[Vector3] = [
		Vector3(3.2, 2.2, -4.5), Vector3(0, 1.2, -5.6),
		Vector3(-5.6, 1.2, 0), Vector3(0, 1.2, 5.6),
		Vector3(5.6, 1.2, 0), Vector3(0, 6.0, 0),
		# Close-up: actual 3D face, never a 2D artwork in place of the racing driver.
		Vector3(0.0, 1.86, -2.35)
	]
	preview_camera.position = views[inspection_view]
	if step == 0 and inspection_view == 0:
		preview_camera.position = Vector3(2.37, 1.96, -3.80)
	preview_camera.projection = (
		Camera3D.PROJECTION_PERSPECTIVE
		if inspection_view in [0, 6]
		else Camera3D.PROJECTION_ORTHOGONAL
	)
	preview_camera.fov = 34.0 if inspection_view == 6 else 37.0
	if step == 0 and inspection_view == 0:
		preview_camera.fov = 38.0
	preview_camera.size = 3.9 if inspection_view == 5 else 2.8
	preview_camera.look_at(
		Vector3(0, 1.68, 0.07) if inspection_view == 6 else Vector3(0, 1.0, 0),
		Vector3.FORWARD if inspection_view == 5 else Vector3.UP
	)
	if inspection_view != 0:
		preview_angle = 0.0
		preview_pivot.rotation.y = 0.0
