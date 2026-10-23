extends Node3D
## Lumo Next Gen game hub: original 3D Lumo, branded scenic background,
## readable controls, existing grade/subject inputs and original SceneRouter.
## No new race modes or modified rewards / game-state persistence.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const MENU_ART = preload("res://scripts/games/kart_menu_art.gd")
const COMPANION = preload("res://scenes/characters/lumo/lumo_character.tscn")

var _safe: MarginContainer
var _button_row: VBoxContainer
var _hero_gap: Control
var _section_title: Label
var _subtitle: Label
var _grade: OptionButton
var _subject: OptionButton
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	_build_scenery()
	_build_live_lumo()
	_build_controls()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_scenery() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	# Canvas background remains behind the REAL animated model (no baked fox).
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9acbff")
	environment.ambient_light_energy = 0.75
	world.environment = environment
	add_child(world)
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	add_child(backdrop_layer)
	var artwork := TextureRect.new()
	artwork.name = "ExistingLumoWorldArt"
	artwork.texture = MENU_ART.world_texture()
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(artwork)
	var darkening := ColorRect.new()
	darkening.name = "ReadabilityVeil"
	darkening.color = Color("031939")
	darkening.color.a = 0.52
	darkening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(darkening)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.3, 2.1, 2.3)
	fill.light_color = Color("74dbff")
	fill.light_energy = 0.8
	fill.omni_range = 7
	fill.shadow_enabled = false
	add_child(fill)


func _build_live_lumo() -> void:
	var lumo := COMPANION.instantiate() as Node3D
	lumo.name = "OriginalAnimatedLumo"
	lumo.position = Vector3(0, -0.15, 0)
	add_child(lumo)
	var camera := Camera3D.new()
	camera.name = "LumoHeroCamera"
	camera.position = Vector3(0.1, 1.7, 4.7)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_safe = MarginContainer.new()
	_safe.name = "PremiumSafeArea"
	_safe.theme = UI.create()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_safe)
	var main := VBoxContainer.new()
	main.name = "ResponsivePremiumLayout"
	main.add_theme_constant_override("separation", 9)
	_safe.add_child(main)
	var top_row := HBoxContainer.new()
	top_row.name = "TopNavigation"
	top_row.add_theme_constant_override("separation", 12)
	main.add_child(top_row)
	var back := _action("‹  Zurück", Color("53ddfd"), func(): SceneRouter.goto("home"))
	back.name = "ReturnToHome"
	back.custom_minimum_size = Vector2(146, 56)
	top_row.add_child(back)
	var brand := _heading("LUMO  ·  SPIELEWELT", 30, UI.WHITE)
	brand.name = "LumoGamesBrand"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(brand)
	_hero_gap = Control.new()
	_hero_gap.name = "OriginalFox3DHeroSpace"
	_hero_gap.custom_minimum_size.y = 70
	_hero_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(_hero_gap)
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "ScrollableRealGameActions"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body_scroll)
	var bottom := VBoxContainer.new()
	bottom.name = "RealGameActions"
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 9)
	body_scroll.add_child(bottom)
	_section_title = _heading("Dein nächstes Abenteuer", 29, UI.WHITE)
	bottom.add_child(_section_title)
	_subtitle = _heading("Mit Lumo spielen, entdecken und Rennen fahren.", 18, UI.MUTED)
	bottom.add_child(_subtitle)
	var settings := PanelContainer.new()
	settings.name = "ExistingLearningOptions"
	settings.add_theme_stylebox_override("panel", UI.premium_panel(UI.CYAN))
	bottom.add_child(settings)
	var settings_column := VBoxContainer.new()
	settings_column.add_theme_constant_override("separation", 7)
	settings.add_child(settings_column)
	settings_column.add_child(_heading("Dein Lernprofil für das Spiel", 17, UI.WHITE))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 9)
	settings_column.add_child(options)
	_grade = OptionButton.new()
	_grade.name = "GradeChoice"
	_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade.custom_minimum_size.y = 54
	_grade.tooltip_text = "Klasse für die eingebetteten Lernspiele"
	for value in range(1, 5):
		_grade.add_item("%d. Klasse" % value, value)
	_grade.selected = clampi(int(SceneRouter.launch_options.get("grade", 1)) - 1, 0, 3)
	_grade.add_theme_stylebox_override("normal", UI.premium_panel(UI.CYAN))
	options.add_child(_grade)
	_subject = OptionButton.new()
	_subject.name = "SubjectChoice"
	_subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subject.custom_minimum_size.y = 54
	_subject.add_item("Mathematik")
	_subject.add_item("Deutsch")
	_subject.selected = 1 if SceneRouter.launch_options.get("subject", "") == "Deutsch" else 0
	_subject.add_theme_stylebox_override("normal", UI.premium_panel(UI.CYAN))
	options.add_child(_subject)
	_button_row = VBoxContainer.new()
	_button_row.name = "LiveGameRoutes"
	_button_row.add_theme_constant_override("separation", 9)
	bottom.add_child(_button_row)
	_make_route("LUMO KART  ·  Sonnenhafen-Cup", Color("ffc94a"), "kart", true)
	_make_route("Wolkeninseln  ·  Springen", Color("53ddfd"), "jump")
	_make_route("Sternenjagd  ·  3D-Welt", Color("b99bff"), "stars")


func _make_route(text: String, color: Color, destination: String, primary: bool = false) -> void:
	var button := _action(text, color, func(): _open_game(destination), primary)
	button.name = "GameRoute_" + destination
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 63
	_button_row.add_child(button)
	_choice_buttons.append(button)


func _open_game(destination: String) -> void:
	# Merge, do not destroy host-provided motion, identity, or launch options.
	var options: Dictionary = SceneRouter.launch_options.duplicate(true)
	options["grade"] = _grade.selected + 1
	options["subject"] = "Deutsch" if _subject.selected == 1 else "Mathematik"
	SceneRouter.launch_options = options
	SceneRouter.goto(destination)


func _heading(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI.HEADING if font_size >= 24 else UI.BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UI.NAVY)
	label.add_theme_constant_override("outline_size", 3)
	return label


func _action(value: String, accent: Color, callback: Callable, is_gold: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 20)
	UI.premium_button(button, accent, is_gold)
	button.pressed.connect(callback)
	return button


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(_safe):
		return
	var view := get_viewport().get_visible_rect().size
	var landscape := view.x > view.y
	var compact := view.y < 640
	for side in ["left", "right"]:
		_safe.add_theme_constant_override("margin_" + side, 16 if compact else 24)
	for side in ["top", "bottom"]:
		_safe.add_theme_constant_override("margin_" + side, 8 if compact else 20)
	_hero_gap.custom_minimum_size.y = 8 if compact else (44 if landscape else 90)
	_section_title.add_theme_font_size_override("font_size", 22 if compact else 29)
	_subtitle.visible = not compact
	for button in _choice_buttons:
		button.custom_minimum_size.y = 54 if compact else 66
		button.add_theme_font_size_override("font_size", 18 if compact else 22)
