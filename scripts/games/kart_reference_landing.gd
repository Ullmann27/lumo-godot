extends Control
## Reference-driven Lumo Kart front page. Original artwork is split into
## independently positioned layers; all actionable areas are real Godot Buttons.
## The existing, functional five-step garage remains the underlying menu.
signal mode_selected(mode_id: String)
signal quick_start
signal open_settings
signal return_to_games

const THEME = preload("res://scripts/games/kart_ui_theme.gd")
const ART = preload("res://scripts/games/kart_menu_art.gd")
const WORDMARK = preload("res://scripts/games/kart_wordmark.gd")
const ART_DIR := "res://assets/kart/landing/"
const NAVY := Color("04142f")
const CYAN := Color("37dfff")
const GOLD := Color("ffce4c")
var total_stars: int = 0
var current_mode: String = "cup"
var _menu_buttons: Dictionary = {}
var _layout_root: Control
var _hero: TextureRect
var _scroll: ScrollContainer
var _split: GridContainer
var _control_column: VBoxContainer
var _shell: VBoxContainer
var _action_bar: GridContainer

func _ready() -> void:
	name = "LumoKartReferenceLanding"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = THEME.create()
	_build()
	get_viewport().size_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_layout")


func _asset(filename: String) -> Texture2D:
	var location := ART_DIR + filename
	if ResourceLoader.exists(location):
		return load(location) as Texture2D
	return null


func _picture(name: String, fallback: Texture2D = null) -> Texture2D:
	var image := _asset(name)
	return image if image != null else fallback


func _build() -> void:
	var scene := TextureRect.new()
	scene.name = "ScenicBackdrop"
	scene.texture = _picture("sunset_world.webp", ART.world_texture())
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = MOUSE_FILTER_IGNORE
	scene.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scene)
	var shade := ColorRect.new()
	shade.name = "ReadabilityGradient"
	shade.color = Color(0.015, 0.052, 0.14, 0.55)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	_layout_root = Control.new()
	_layout_root.name = "ResponsiveLandingLayout"
	_layout_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_layout_root)
	_shell = VBoxContainer.new()
	_shell.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_shell.add_theme_constant_override("separation", 8)
	_layout_root.add_child(_shell)
	_scroll = ScrollContainer.new()
	_scroll.name = "ReachableReferenceButtons"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shell.add_child(_scroll)
	var content := VBoxContainer.new()
	content.name = "ReferenceContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)
	var header := HBoxContainer.new()
	header.name = "LogoAndLiveProgress"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var logo_art := _picture("kart_logo_art.webp")
	if logo_art != null:
		var logo := TextureRect.new()
		logo.name = "OriginalLumoKartLogoArt"
		logo.texture = logo_art
		logo.custom_minimum_size = Vector2(150, 72)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(logo)
	else:
		var logo_vector := WORDMARK.new()
		logo_vector.custom_minimum_size = Vector2(150, 72)
		header.add_child(logo_vector)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var stars := Label.new()
	stars.name = "ActualCollectedStars"
	stars.text = "★ %d" % total_stars
	stars.add_theme_color_override("font_color", GOLD)
	stars.add_theme_font_size_override("font_size", 27)
	stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stars.tooltip_text = "Echte gesammelte Sterne aus dem Lernfortschritt"
	header.add_child(stars)
	_split = GridContainer.new()
	_split.name = "AdaptiveReferenceSplit"
	_split.columns = 2
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("h_separation", 15)
	_split.add_theme_constant_override("v_separation", 10)
	content.add_child(_split)
	_control_column = VBoxContainer.new()
	_control_column.name = "FunctionalNativeControls"
	_control_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_control_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_control_column.add_theme_constant_override("separation", 10)
	_split.add_child(_control_column)
	_hero = TextureRect.new()
	_hero.name = "FoxAndKartReferenceLayer"
	_hero.texture = _picture("cinematic_hero.webp", ART.world_texture())
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.mouse_filter = MOUSE_FILTER_IGNORE
	_hero.custom_minimum_size = Vector2(120, 200)
	_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_hero)
	var eyebrow := _caption("DEIN SONNENHAFEN-RENNABENTEUER", 15, CYAN)
	eyebrow.name = "BrandEyebrow"
	_control_column.add_child(eyebrow)
	var title := _caption("Mit Lumo an den Start!", 29, Color.WHITE)
	title.name = "KartLandingHeading"
	_control_column.add_child(title)
	var primary := GridContainer.new()
	primary.name = "RealRaceModeChoices"
	primary.columns = 2
	primary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary.add_theme_constant_override("h_separation", 9)
	primary.add_theme_constant_override("v_separation", 9)
	_control_column.add_child(primary)
	_add_choice(primary, "cup", "Grand Prix", "Sternenpokal", "grand_prix_art.webp", GOLD)
	_add_choice(primary, "time_trial", "Zeitrennen", "Deine Bestzeit", "time_trial_art.webp", CYAN)
	var secondary := GridContainer.new()
	secondary.name = "RealGameOptions"
	secondary.columns = 3
	secondary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary.add_theme_constant_override("h_separation", 8)
	secondary.add_theme_constant_override("v_separation", 8)
	_control_column.add_child(secondary)
	_add_choice(secondary, "sonnenhafen", "Sonnenhafen", "Rennstrecke", "sonnenhafen_art.webp", CYAN)
	_add_choice(secondary, "garage", "Garage", "Dein Kart", "garage_art.webp", CYAN)
	_add_choice(secondary, "settings", "Einstellungen", "Spieloptionen", "settings_art.webp", CYAN)
	_action_bar = GridContainer.new()
	_action_bar.name = "PersistentStartAndReturn"
	_action_bar.add_theme_constant_override("h_separation", 8)
	_action_bar.add_theme_constant_override("v_separation", 8)
	_shell.add_child(_action_bar)
	var begin := Button.new()
	begin.name = "LiveQuickStart"
	begin.text = "▶  START"
	begin.tooltip_text = "Startet ein echtes Rennen mit deinem ausgewählten Kart"
	begin.custom_minimum_size.y = 78
	THEME.premium_button(begin, GOLD, true)
	begin.pressed.connect(func(): quick_start.emit())
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_bar.add_child(begin)
	var footer := Button.new()
	footer.name = "ReturnToGames"
	footer.text = "‹  Zurück zur Spielewelt"
	footer.custom_minimum_size.y = 54
	THEME.premium_button(footer, CYAN)
	footer.pressed.connect(func(): return_to_games.emit())
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_bar.add_child(footer)


func _caption(message: String, fontsize: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.add_theme_font_override("font", THEME.HEADING)
	label.add_theme_font_size_override("font_size", fontsize)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_outline_color", NAVY)
	label.add_theme_constant_override("outline_size", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_choice(container: GridContainer, id: String, heading: String,
		detail: String, filename: String, accent: Color) -> void:
	var tile := Button.new()
	tile.name = "Landing_" + id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size.y = 136
	tile.tooltip_text = heading + ". " + detail
	tile.clip_contents = true
	tile.focus_mode = FOCUS_ALL
	tile.add_theme_stylebox_override("normal", THEME.premium_panel(accent, id == current_mode))
	tile.add_theme_stylebox_override("hover", THEME.premium_panel(accent, true))
	tile.add_theme_stylebox_override("pressed", THEME.premium_panel(GOLD, true))
	tile.add_theme_stylebox_override("focus", THEME.premium_panel(accent, true))
	container.add_child(tile)
	_menu_buttons[id] = tile
	var art := TextureRect.new()
	art.name = "Illustration_" + id
	art.texture = _picture(filename)
	# Card artwork is now cut precisely above baked captions. Keep its full
	# scenic image; user-visible wording remains only in the native Labels.
	if art.texture == null:
		# Fallback is the authorized EXISTING illustration, never an empty card.
		art.texture = ART.world_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(1, 1, 1, 0.85)
	art.mouse_filter = MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tile.add_child(art)
	var dim := ColorRect.new()
	# Keep the actual source painting vivid: darken only the caption region,
	# rather than covering the user's beautiful illustrated cards with 63% navy.
	dim.color = Color.WHITE
	var readability_shader := Shader.new()
	readability_shader.code = "shader_type canvas_item; void fragment() { float bottom = smoothstep(0.26, 0.96, UV.y); COLOR = vec4(0.005, 0.025, 0.09, mix(0.10, 0.82, bottom)); }"
	var readability_material := ShaderMaterial.new()
	readability_material.shader = readability_shader
	dim.material = readability_material
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tile.add_child(dim)
	var label_group := VBoxContainer.new()
	label_group.name = "AccessibleRealLabels"
	label_group.mouse_filter = MOUSE_FILTER_IGNORE
	label_group.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	label_group.alignment = BoxContainer.ALIGNMENT_END
	label_group.add_theme_constant_override("separation", 2)
	tile.add_child(label_group)
	var head := _caption(heading, 16 if container.name == "RealGameOptions" else 21, Color.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_group.add_child(head)
	var sub := _caption(detail, 15, Color("d6efff"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_group.add_child(sub)
	tile.pressed.connect(func(): _choose(id))


func _choose(id: String) -> void:
	# Navigation and track cards must not overwrite the chosen race mode.
	if id in ["cup", "time_trial"]:
		current_mode = id
	for key in _menu_buttons.keys():
		var button := _menu_buttons[key] as Button
		button.add_theme_stylebox_override("normal",
			THEME.premium_panel(GOLD if key == current_mode else CYAN, key == current_mode))
	if id == "settings":
		open_settings.emit()
	else:
		mode_selected.emit(id)


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(_scroll):
		return
	var viewport_size := get_viewport_rect().size
	var window_dp: Vector2 = Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_dp.x <= 0 or window_dp.y <= 0 or size.x <= 0 or size.y <= 0:
		return
	# The real Kart host already scales safe_ui from dp into the Godot
	# stretched canvas. This landing is nested beneath that transformed node.
	# Scaling again by the full canvas/dp ratio breaks portrait/Fold layouts:
	# at 320x740 it produces buttons wider than the entire 1280px canvas.
	# Remove only the scale inherited from the parent, not the device density.
	var canvas_per_dp := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	var inherited := get_global_transform().get_scale()
	var parent_scale := maxf(absf(inherited.x), absf(inherited.y), 0.01)
	var ui_scale := canvas_per_dp / parent_scale
	var size_now: Vector2 = size / ui_scale
	# Lay out in device-dp, then transform the complete native subtree into
	# the project's stretched canvas. Fonts, corners and touch areas agree.
	_layout_root.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_layout_root.scale = Vector2.ONE * ui_scale
	_layout_root.size = size_now
	var landscape := size_now.x > size_now.y
	var phone := size_now.x < 730
	_shell.offset_left = 12
	_shell.offset_right = -12
	_shell.offset_top = 8
	_shell.offset_bottom = -8
	_action_bar.columns = 2 if landscape else 1
	_action_bar.get_node("LiveQuickStart").custom_minimum_size.y = 56 if landscape else 64
	var content := _scroll.get_child(0) as VBoxContainer
	var desired := minf(size_now.x - 24, 1240.0 if landscape else 580.0)
	content.custom_minimum_size.x = desired
	# Fill the actual physical viewport in landscape. The previous VBox
	# occupied only its intrinsic ~370px height on a 720px screen.
	content.custom_minimum_size.y = maxf(0.0, size_now.y - 16.0) if landscape else 0.0
	_split.columns = 2 if landscape else 1
	# A three-column card row has a native minimum width > portrait phones.
	# Its oversized minimum was centering the fox outside the visible viewport.
	var main_modes := _control_column.get_node("RealRaceModeChoices") as GridContainer
	var extra_modes := _control_column.get_node("RealGameOptions") as GridContainer
	main_modes.columns = 2 if landscape or size_now.x >= 480 else 1
	extra_modes.columns = 3 if landscape and size_now.x >= 900 else (2 if landscape or size_now.x >= 480 else 1)
	# Preserve a large cinematic fox on landscape, but avoid giant cropped
	# hero imagery and invisible controls on a portrait Android surface.
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL if landscape else Control.SIZE_FILL
	_control_column.size_flags_vertical = Control.SIZE_EXPAND_FILL if landscape else Control.SIZE_FILL
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL if landscape else Control.SIZE_FILL
	_split.move_child(_control_column if landscape else _hero, 0)
	_control_column.custom_minimum_size.x = clampf(size_now.x * 0.46, 240.0, 570.0) if landscape else 0.0
	_hero.custom_minimum_size.x = clampf(size_now.x * 0.42, 220.0, 585.0) if landscape else 0.0
	_hero.custom_minimum_size.y = (
		clampf(size_now.y * 0.76, 320, 620) if landscape
		else clampf(size_now.y * 0.34, 220, 390)
	)
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	for id in _menu_buttons.keys():
		var button := _menu_buttons[id] as Button
		button.custom_minimum_size.y = (76 if size_now.y < 520 else (96 if size_now.y < 800 else 132)) if landscape else (112 if phone else 132)
