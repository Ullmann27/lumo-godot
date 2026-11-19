extends CanvasLayer
## Oberfläche des Abenteuer-Parcours: Weltwahl, Fahranzeige, Lumos Sätze, Bedienung
## (Kart-Lenkstick, GAS, BREMSE, DRIFT, BOOST wie im Rennen, dazu die Kontexttaste
## AUSSTEIGEN / HEBEL / EINSTEIGEN und zu Fuß SPRINGEN), Pause und Ergebnis.
## Alle Tippziele sind mindestens 48 dp groß (Fold: 126 px), auch im schmalen Hochformat.

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const JOYSTICK = preload("res://scripts/games/kart_joystick.gd")
const TOUCH_ACTION = preload("res://scripts/games/kart_touch_action.gd")
const RUN_BUTTON = preload("res://scripts/games/run/run_touch_button.gd")
## 48 dp auf dem Zielgerät (Fold7, ~2,6 px je dp) in echten Bildpunkten.
const MIN_TOUCH_PX: float = 126.0

var game
var root: Control
var choice: Control
var play: Control
var modal_backdrop: ColorRect
var modal: PanelContainer
var modal_column: VBoxContainer
var top_bar: HBoxContainer
var pause_button: Button
var reset_button: Button
var info: Label
var stars_label: Label
var message: Label
var countdown_label: Label
var joystick: Control
var gas_button: Control
var brake_button: Control
var drift_button: Control
var boost_button: Control
var context_button: Control
var jump_button: Control
var message_age: float = 0.0
var _style: String = "zeitlauf"
var _choice_style: String = "zeitlauf"


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "ParcoursUi"
	root.theme = UI.create()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_play()
	_build_modal()
	get_viewport().size_changed.connect(layout)
	layout.call_deferred()


## Kleinstes Tippziel in Bildschirmeinheiten der Szene (Inhalt 1280×720, gestreckt).
func min_touch() -> float:
	var visible: Vector2 = root.get_viewport_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	if DisplayServer.get_name() == "headless" or window.x <= 0.0:
		return MIN_TOUCH_PX * visible.y / 720.0 * 0.5
	var scale_factor: float = window.y / maxf(visible.y, 1.0)
	return MIN_TOUCH_PX / maxf(scale_factor, 0.01)


func _button(text: String, callback: Callable, accent: Color = UI.CYAN, gold: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	UI.premium_button(button, accent, gold)
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(text: String, size: int, color: Color = UI.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.HEADING)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("061430"))
	label.add_theme_constant_override("outline_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_play() -> void:
	play = Control.new()
	play.name = "PlayLayer"
	play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play)
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.add_theme_constant_override("separation", 12)
	play.add_child(top_bar)
	pause_button = _button("Ⅱ  Pause", func(): game.pause_game())
	pause_button.name = "PauseButton"
	top_bar.add_child(pause_button)
	reset_button = _button("↺  Checkpoint", func(): game.manual_reset())
	reset_button.name = "ResetButton"
	top_bar.add_child(reset_button)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.premium_panel(UI.CYAN))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	info = _label("", 26)
	info.name = "Info"
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(info)
	stars_label = _label("", 26, UI.GOLD)
	stars_label.name = "Stars"
	stars_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(stars_label)
	message = _label("", 28)
	message.name = "LumoSays"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.02, 0.07, 0.17, 0.72)
	plate.set_corner_radius_all(22)
	plate.set_content_margin_all(14)
	plate.border_color = Color("ffc94a")
	plate.border_width_left = 6
	message.add_theme_stylebox_override("normal", plate)
	play.add_child(message)
	countdown_label = _label("", 150, UI.GOLD)
	countdown_label.name = "Countdown"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(countdown_label)
	joystick = JOYSTICK.new()
	joystick.name = "Steer"
	joystick.skin = "kart3d"
	joystick.axis_changed.connect(func(value: Vector2): game.steer = value)
	play.add_child(joystick)
	gas_button = _action("GAS", "gas", Color("7cf29c"))
	gas_button.button_down.connect(func(): game.gas_held = true)
	gas_button.button_up.connect(func(): game.gas_held = false)
	brake_button = _action("BREMSE", "brake", Color("ff8a7a"))
	brake_button.button_down.connect(func(): game.brake_held = 1.0)
	brake_button.button_up.connect(func(): game.brake_held = 0.0)
	drift_button = _action("DRIFT", "drift", Color("bc8eff"))
	drift_button.button_down.connect(func(): game.press_drift())
	drift_button.button_up.connect(func(): game.release_drift())
	boost_button = _action("BOOST", "boost", Color("66f7e8"))
	boost_button.pressed.connect(func(): game.use_boost())
	context_button = RUN_BUTTON.new()
	context_button.name = "ContextAction"
	context_button.configure("action", "AUSSTEIGEN", "Aussteigen, Hebel umlegen oder einsteigen")
	context_button.hold_changed.connect(func(on: bool): if on: game.context_action())
	play.add_child(context_button)
	jump_button = RUN_BUTTON.new()
	jump_button.name = "JumpAction"
	jump_button.configure("jump", "SPRINGEN", "Lumo springt")
	jump_button.hold_changed.connect(func(on: bool): game.jump_pressed(on))
	play.add_child(jump_button)
	play.visible = false


func _action(text: String, icon: String, accent: Color) -> Control:
	var button: Control = TOUCH_ACTION.new()
	button.name = text.capitalize() + "Action"
	button.text = text
	button.icon_id = icon
	button.accent = accent
	button.skin = "kart3d"
	play.add_child(button)
	return button


func _build_modal() -> void:
	modal_backdrop = ColorRect.new()
	modal_backdrop.color = Color(0.01, 0.04, 0.1, 0.6)
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.visible = false
	root.add_child(modal_backdrop)
	modal = PanelContainer.new()
	modal.name = "Modal"
	modal.add_theme_stylebox_override("panel", UI.premium_panel(UI.GOLD, true))
	modal.visible = false
	root.add_child(modal)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_column = VBoxContainer.new()
	modal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_column.add_theme_constant_override("separation", 14)
	scroll.add_child(modal_column)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# --- Weltwahl -----------------------------------------------------------------------

func show_choice(entries: Array, progress, style: String, has_session: bool) -> void:
	_choice_style = style
	play.visible = false
	hide_modal()
	if is_instance_valid(choice):
		choice.queue_free()
	choice = Control.new()
	choice.name = "WorldChoice"
	choice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(choice)
	root.move_child(choice, 0)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("061a3d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(background)
	var glow := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.2)
	gradient.fill_to = Vector2(1.1, 1.0)
	var colors := Gradient.new()
	colors.set_color(0, Color("2f6fd0"))
	colors.set_color(1, Color("040f26"))
	gradient.gradient = colors
	glow.texture = gradient
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice.add_child(glow)
	var scroll := ScrollContainer.new()
	scroll.name = "ChoiceScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "ChoiceColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	var title := _label("LUMO Abenteuer-Parcours", 52, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := _label("Fahr mit deinem Kart durch Geschicklichkeitswelten. Manchmal steigt Lumo aus!", 26, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	var styles := HBoxContainer.new()
	styles.name = "Styles"
	styles.add_theme_constant_override("separation", 14)
	column.add_child(styles)
	for spec in [["zeitlauf", "⏱  Zeitlauf"], ["erkunden", "✿  Entspannt erkunden"]]:
		var id: String = spec[0]
		var button := _button(("✓ " if id == _choice_style else "") + str(spec[1]), func(): _pick_style(id, entries, progress, has_session), UI.CYAN, id == _choice_style)
		button.name = "Style_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		styles.add_child(button)
	var cards := GridContainer.new()
	cards.name = "WorldCards"
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	column.add_child(cards)
	for entry in entries:
		var id: String = str(entry.id)
		var stats: Dictionary = progress.world(id)
		var card := Button.new()
		card.name = "World_" + id
		card.focus_mode = Control.FOCUS_NONE
		UI.premium_button(card, Color(entry.color), false)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lines: PackedStringArray = ["Welt %s · %s" % [entry.letter, entry.name], str(entry.description)]
		if int(stats.completed) > 0:
			var best: String = "Bestzeit %s" % format_time(float(stats.best_time)) if float(stats.best_time) > 0.0 else "Geschafft"
			lines.append("%s · ★ %d · Geheimwege %d" % [best, int(stats.best_stars), (stats.secrets as Array).size()])
		else:
			lines.append("Noch nicht geschafft – los geht's!")
		card.text = "\n".join(lines)
		card.pressed.connect(func(): game.start_world(id, _choice_style))
		cards.add_child(card)
	var nav := HBoxContainer.new()
	nav.name = "ChoiceNav"
	nav.add_theme_constant_override("separation", 14)
	column.add_child(nav)
	if has_session:
		var resume := _button("▶  Weiterfahren", func(): game.continue_saved(), UI.GOLD, true)
		resume.name = "ResumeSaved"
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(resume)
	var back := _button("‹  Zum Kart-Menü", func(): game.leave_to_kart_menu())
	back.name = "BackToKartMenu"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back)
	layout()


func _pick_style(id: String, entries: Array, progress, has_session: bool) -> void:
	game.play_style = id
	show_choice(entries, progress, id, has_session)


# --- Fahren -------------------------------------------------------------------------

func show_play(course, style: String) -> void:
	_style = style
	if is_instance_valid(choice):
		choice.queue_free()
		choice = null
	hide_modal()
	play.visible = true
	refresh_context()
	layout()


func say(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()
	message_age = 0.0


func set_countdown(value: float) -> void:
	countdown_label.text = str(ceili(value)) if value > 0.0 else ""
	if value <= 0.0:
		say("LOS!")


func update_hud(run, style: String) -> void:
	var course = run.course
	if game.countdown <= 0.0 and not countdown_label.text.is_empty():
		countdown_label.text = ""
	if style == "zeitlauf":
		info.text = "%s · %s" % [course.title, format_time(run.elapsed)]
	else:
		info.text = "%s · Erkunden" % course.title
	stars_label.text = "★ %d/%d" % [run.stars_taken.size(), course.stars.size()]
	message_age += 1.0 / 60.0
	if message_age > 5.0:
		message.visible = false
	var on_foot: bool = run.on_foot
	for button in [gas_button, brake_button, drift_button, boost_button]:
		button.visible = not on_foot
	jump_button.visible = on_foot
	reset_button.disabled = on_foot
	boost_button.text = "BOOST %d" % run.drive.boosts
	boost_button.disabled = run.drive.boosts <= 0
	refresh_context()


func refresh_context() -> void:
	if game == null or not is_instance_valid(context_button):
		return
	var text: String = game.context_label()
	context_button.visible = not text.is_empty()
	if not text.is_empty() and text != context_button.caption:
		context_button.configure("action", text, text)


static func format_time(seconds: float) -> String:
	var total: int = floori(seconds)
	return "%d:%02d,%d" % [total / 60, total % 60, floori(fmod(seconds, 1.0) * 10.0)]


# --- Pause und Ergebnis -------------------------------------------------------------

func _open_modal(title: String) -> void:
	_clear(modal_column)
	var heading := _label(title, 44, UI.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_column.add_child(heading)
	modal_backdrop.visible = true
	modal.visible = true
	layout()


func _modal_button(text: String, callback: Callable, name_id: String, gold: bool = false) -> void:
	var button := _button(text, callback, UI.CYAN, gold)
	button.name = name_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_column.add_child(button)


func show_pause() -> void:
	_open_modal("Pause")
	modal_column.add_child(_label("Deine Sterne und dein Checkpoint bleiben gespeichert.", 26, UI.MUTED))
	_modal_button("▶  Weiterfahren", func(): game.resume_game(), "Resume", true)
	_modal_button("↻  Neu starten", func(): game.restart_world(), "Restart")
	_modal_button("‹  Andere Welt wählen", func(): game.leave_to_choice(), "ToChoice")
	_modal_button("‹  Zum Kart-Menü", func(): game.leave_to_kart_menu(), "ToKartMenu")
	layout()


func show_result(payload: Dictionary, stats: Dictionary, answer: Dictionary, saved: bool) -> void:
	_open_modal("Geschafft!")
	var lines: PackedStringArray = []
	if str(payload.style) == "zeitlauf":
		lines.append("Zeit: %s" % format_time(float(payload.elapsedSeconds)))
		if bool(answer.get("new_best", false)):
			lines.append("Neue Bestzeit!")
		elif float(stats.get("best_time", 0.0)) > 0.0:
			lines.append("Bestzeit: %s" % format_time(float(stats.best_time)))
	else:
		lines.append("Entspannt erkundet in %s" % format_time(float(payload.elapsedSeconds)))
	lines.append("Parcours-Sterne: %d von %d" % [int(payload.starTokens), int(payload.starTotal)])
	lines.append("Geheimwege: %d" % (payload.secrets as Array).size())
	lines.append("Belohnung: %d ★ für dein Sternekonto" % int(payload.stars))
	var body := _label("\n".join(lines), 26)
	body.name = "ResultLines"
	modal_column.add_child(body)
	if not saved:
		modal_column.add_child(_label("Speichern fehlgeschlagen. Bitte erneut versuchen.", 26, Color("ffb648")))
		_modal_button("Erneut speichern", func(): game.retry_reward(), "RetrySave", true)
	_modal_button("↻  Noch einmal", func(): game.restart_world(), "Again", saved)
	_modal_button("‹  Andere Welt wählen", func(): game.show_world_choice(), "ToChoice")
	_modal_button("‹  Zum Kart-Menü", func(): game.leave_to_kart_menu(), "ToKartMenu")
	layout()


func hide_modal() -> void:
	if is_instance_valid(modal):
		modal.visible = false
		modal_backdrop.visible = false


## Android-Zurück schließt zuerst ein offenes Fenster außer Pause/Ergebnis (die steuert das Spiel).
func close_overlay() -> bool:
	return false


# --- Anordnung ----------------------------------------------------------------------

func layout() -> void:
	if not is_instance_valid(root):
		return
	var area: Vector2 = root.get_viewport_rect().size
	var touch: float = maxf(min_touch(), 64.0)
	var margin: float = maxf(20.0, area.x * 0.018)
	var short_side: float = minf(area.x, area.y)
	var portrait: bool = area.y > area.x
	# Obere Leiste
	var bar_height: float = maxf(touch, 72.0)
	top_bar.position = Vector2(margin, margin)
	top_bar.size = Vector2(area.x - margin * 2.0, bar_height)
	for button in [pause_button, reset_button]:
		button.custom_minimum_size = Vector2(maxf(touch * 1.6, 180.0), bar_height)
		button.add_theme_font_size_override("font_size", roundi(clampf(bar_height * 0.34, 22, 44)))
	var font: int = roundi(clampf(bar_height * 0.36, 22, 46))
	info.add_theme_font_size_override("font_size", font)
	stars_label.add_theme_font_size_override("font_size", font)
	message.position = Vector2(area.x * 0.12, margin + bar_height + 14.0)
	message.size = Vector2(area.x * 0.76, 0)
	message.add_theme_font_size_override("font_size", roundi(clampf(short_side * 0.04, 24, 52)))
	countdown_label.position = Vector2(0, area.y * 0.3)
	countdown_label.size = Vector2(area.x, 200)
	# Lenkstick links unten, Tasten rechts unten (Hochformat: größer und höher)
	var stick: float = clampf(short_side * (0.42 if portrait else 0.36), touch * 2.0, 520.0)
	joystick.size = Vector2.ONE * stick
	joystick.custom_minimum_size = joystick.size
	joystick.position = Vector2(margin, area.y - margin - stick)
	var b: float = clampf(short_side * (0.17 if portrait else 0.15), touch, 280.0)
	var big: float = b * 1.3
	var right: float = area.x - margin
	var bottom: float = area.y - margin
	var spots := {
		gas_button: [Vector2(right - big * 0.5, bottom - big * 0.5), big],
		brake_button: [Vector2(right - big - b * 0.55 - 10.0, bottom - b * 0.5), b],
		drift_button: [Vector2(right - big - b * 0.55 - 10.0, bottom - b * 1.6 - 16.0), b],
		boost_button: [Vector2(right - big * 0.5, bottom - big - b * 0.5 - 16.0), b],
		context_button: [Vector2(right - big * 0.5, bottom - big - b * 1.6 - 34.0), b],
		jump_button: [Vector2(right - big * 0.5, bottom - big * 0.5), big],
	}
	for control in spots:
		var spec: Array = spots[control]
		var side: float = float(spec[1])
		control.custom_minimum_size = Vector2.ONE * side
		control.size = Vector2.ONE * side
		control.position = (spec[0] as Vector2) - Vector2.ONE * side * 0.5
	# Fenster mittig
	var width: float = clampf(area.x * (0.86 if portrait else 0.5), 420.0, 980.0)
	var height: float = clampf(area.y * (0.6 if portrait else 0.84), 360.0, area.y - margin * 2.0)
	modal.position = Vector2((area.x - width) * 0.5, (area.y - height) * 0.5)
	modal.size = Vector2(width, height)
	if is_instance_valid(modal_column):
		for child in modal_column.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(0, maxf(touch, 84.0))
				(child as Button).add_theme_font_size_override("font_size", roundi(clampf(touch * 0.32, 24, 44)))
	if is_instance_valid(choice):
		var scroll := choice.get_node_or_null("ChoiceScroll") as ScrollContainer
		if scroll != null:
			scroll.position = Vector2(margin, margin)
			scroll.size = area - Vector2.ONE * margin * 2.0
			var column := scroll.get_node("ChoiceColumn") as VBoxContainer
			column.custom_minimum_size.x = scroll.size.x - 8.0
			var cards := column.get_node("WorldCards") as GridContainer
			cards.columns = clampi(floori(scroll.size.x / 520.0), 1, 3)
			for card in cards.get_children():
				(card as Button).custom_minimum_size = Vector2(0, maxf(touch * 1.6, 200.0))
				(card as Button).add_theme_font_size_override("font_size", roundi(clampf(short_side * 0.032, 22, 40)))
			for row_name in ["Styles", "ChoiceNav"]:
				for button in column.get_node(row_name).get_children():
					(button as Button).custom_minimum_size = Vector2(0, maxf(touch, 84.0))
					(button as Button).add_theme_font_size_override("font_size", roundi(clampf(touch * 0.3, 22, 42)))
