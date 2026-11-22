extends Control
## Screens around the flights: start (mode, stage, glider colour, riddles),
## help, loading, pause and result. One screen at a time, rebuilt when the
## window changes (portrait, landscape, Fold open/closed). The live 3D stage
## (Lumo in his glider on the post-office deck) shows through hero_rect.

signal start_pressed(resume: bool)
signal mode_selected(mode: String)
signal stage_selected(stage: String)
signal colour_selected(colour: String)
signal riddles_toggled(value: bool)
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal again_pressed
signal help_pressed
signal help_closed
signal leave_pressed(destination: String)

const UI = preload("res://scripts/games/run/run_ui.gd")
const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")
const GLIDER = preload("res://scripts/games/skypost/sky_post_glider.gd")
const MODE_TEXT := {
	"delivery": "Bring Briefe zu den Häusern. Die Adresse ist ein Rätsel!",
	"race": "Flieg durch die Ringe – gegen drei Freunde.",
	"free": "Erkunde Wolkenhafen, finde geheime Sterne und Fotostellen.",
}
const MODE_ACCENT := {"delivery": Color("ffd75e"), "race": Color("53ddfd"), "free": Color("ff9fd2")}

var screen: String = ""
var data: Dictionary = {}
## Screen rectangle left free for the live 3D stage on the start screen.
var hero_rect := Rect2()
var _unit: float = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(refresh)
	MobileRuntime.safe_area_changed.connect(refresh)


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(refresh):
		get_viewport().size_changed.disconnect(refresh)
	if MobileRuntime.safe_area_changed.is_connected(refresh):
		MobileRuntime.safe_area_changed.disconnect(refresh)


func open(kind: String, content: Dictionary = {}) -> void:
	screen = kind
	data = content
	refresh()


func close() -> void:
	screen = ""
	data = {}
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_unit = UI.unit(self)
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if screen.is_empty() or screen == "start"
		else Control.MOUSE_FILTER_STOP
	)
	match screen:
		"start":
			_build_start()
		"help":
			_build_help()
		"loading":
			_build_loading()
		"pause":
			_build_pause()
		"result":
			_build_result()


# ------------------------------------------------------------------ shared pieces


func _veil(alpha: float) -> void:
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.01, 0.05, 0.14, alpha)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)


func _dialog(accent: Color, width_dp: float) -> VBoxContainer:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector4 = UI.margins(self, 12.0)
	var panel := PanelContainer.new()
	panel.name = "Dialog"
	panel.add_theme_stylebox_override("panel", UI.panel(accent, u))
	var width: float = minf(width_dp * u, view.x - m.x - m.z)
	panel.position = Vector2((view.x - width) * 0.5, m.y)
	panel.size = Vector2(width, view.y - m.y - m.w)
	panel.modulate.a = 0.0
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", roundi(10.0 * u))
	scroll.add_child(column)
	_fit_dialog.call_deferred(panel, column)
	return column


func _fit_dialog(panel: PanelContainer, column: VBoxContainer) -> void:
	for _pass in range(2):
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(panel) or not is_instance_valid(column):
			return
		var view: Vector2 = get_viewport().get_visible_rect().size
		var m: Vector4 = UI.margins(self, 12.0)
		var height: float = minf(
			column.get_combined_minimum_size().y + 36.0 * _unit, view.y - m.y - m.w
		)
		panel.size = Vector2(panel.size.x, height)
		panel.position = Vector2((view.x - panel.size.x) * 0.5, maxf(m.y, (view.y - height) * 0.5))
	panel.modulate.a = 1.0


func dialog_rect() -> Rect2:
	var panel := get_node_or_null("Dialog") as Control
	return panel.get_global_rect() if panel != null else Rect2()


func _button(
	text: String,
	node_name: String,
	action: Callable,
	primary: bool = false,
	accent: Color = UI.CYAN,
	height: float = 56.0
) -> Button:
	var button: Button = UI.button(text, _unit, accent, primary, height)
	button.name = node_name
	button.pressed.connect(action)
	return button


func _row(buttons: Array, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", roundi(10.0 * _unit))
	grid.add_theme_constant_override("v_separation", roundi(10.0 * _unit))
	for button in buttons:
		grid.add_child(button)
	return grid


# ------------------------------------------------------------------ start


func _build_start() -> void:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector4 = UI.margins(self, 14.0)
	var wide: bool = view.x > view.y * 1.12
	var inner := Rect2(m.x, m.y, view.x - m.x - m.z, view.y - m.y - m.w)
	var back: Button = _button(
		"‹ Spiele", "BackToGames", func() -> void: leave_pressed.emit("games"), false, UI.CYAN, 48.0
	)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.position = inner.position
	back.size = Vector2(118.0, 48.0) * u
	back.custom_minimum_size = Vector2(118.0, 48.0) * u
	add_child(back)
	var help: Button = _button(
		"? So geht's", "HelpButton", func() -> void: help_pressed.emit(), false, UI.CYAN, 48.0
	)
	help.size = Vector2(130.0, 48.0) * u
	help.custom_minimum_size = Vector2(130.0, 48.0) * u
	help.position = Vector2(inner.end.x - help.size.x, inner.position.y)
	add_child(help)
	var panel_area: Rect2
	var title_area: Rect2
	if wide:
		var hero_width: float = inner.size.x * 0.44
		hero_rect = Rect2(
			inner.position.x, inner.position.y + 120.0 * u, hero_width, inner.size.y - 120.0 * u
		)
		title_area = Rect2(inner.position.x, inner.position.y + 52.0 * u, hero_width, 70.0 * u)
		panel_area = Rect2(
			inner.position.x + hero_width + 16.0 * u,
			inner.position.y + 56.0 * u,
			inner.size.x - hero_width - 16.0 * u,
			inner.size.y - 56.0 * u
		)
	else:
		title_area = Rect2(inner.position.x, inner.position.y + 52.0 * u, inner.size.x, 92.0 * u)
		var hero_height: float = clampf(inner.size.y * 0.3, 170.0 * u, 360.0 * u)
		hero_rect = Rect2(inner.position.x, title_area.end.y, inner.size.x, hero_height)
		panel_area = Rect2(
			inner.position.x,
			hero_rect.end.y + 6.0 * u,
			inner.size.x,
			inner.end.y - hero_rect.end.y - 6.0 * u
		)
	var title: Label = UI.label("LUMOS STERNENPOST", 40.0 if not wide else 38.0, u, UI.GOLD, true)
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", UI.INK)
	title.add_theme_constant_override("outline_size", roundi(10.0 * u))
	title.position = title_area.position
	title.size = Vector2(title_area.size.x, 54.0 * u)
	add_child(title)
	var subtitle: Label = UI.label("Wolkenhafen · Morgen", 18.0, u, UI.WHITE)
	subtitle.name = "Subtitle"
	subtitle.add_theme_color_override("font_outline_color", UI.INK)
	subtitle.add_theme_constant_override("outline_size", roundi(6.0 * u))
	subtitle.position = title_area.position + Vector2(0, 52.0 * u)
	subtitle.size = Vector2(title_area.size.x, 30.0 * u)
	add_child(subtitle)
	var panel := PanelContainer.new()
	panel.name = "StartPanel"
	panel.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, u, 0.9))
	panel.position = panel_area.position
	panel.size = panel_area.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", roundi(9.0 * u))
	scroll.add_child(column)
	var mode: String = str(data.get("mode", "delivery"))
	var stage: String = str(data.get("stage", "entdecken"))
	# Mode cards.
	var cards := GridContainer.new()
	cards.name = "Modes"
	cards.columns = 3
	cards.add_theme_constant_override("h_separation", roundi(8.0 * u))
	for id in TUNING.MODES:
		cards.add_child(_mode_card(id, id == mode, data.get("best", {}).get(id, "")))
	column.add_child(cards)
	var about: Label = UI.label(MODE_TEXT[mode], 16.0, u, UI.WHITE)
	about.name = "ModeText"
	column.add_child(about)
	# Stage.
	column.add_child(_caption("Stufe"))
	var stages: Array = []
	for id in TUNING.STAGES:
		var button: Button = _button(
			TUNING.STAGE_NAMES[id],
			"Stage_" + id,
			func() -> void: stage_selected.emit(id),
			id == stage,
			UI.CYAN,
			50.0
		)
		stages.append(button)
	column.add_child(_row(stages, 3))
	# Glider colour and riddles.
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", roundi(10.0 * u))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", roundi(6.0 * u))
	for id in GLIDER.COLOUR_ORDER:
		swatches.add_child(_swatch(id, id == str(data.get("colour", "sternblau"))))
	row.add_child(swatches)
	if mode == "delivery":
		var riddles: bool = bool(data.get("riddles", true))
		var toggle: Button = _button(
			"Rätsel: AN" if riddles else "Rätsel: AUS",
			"Riddles",
			func() -> void: riddles_toggled.emit(not riddles),
			false,
			UI.GOLD if riddles else UI.MUTED,
			50.0
		)
		toggle.tooltip_text = (
			"Adressen als Rechnung, Wortart oder Uhrzeit (%d. Klasse, %s)"
			% [int(data.get("grade", 1)), str(data.get("subject", "Mathematik"))]
		)
		row.add_child(toggle)
	column.add_child(
		_caption("Flieger-Farbe" + ("  ·  Adress-Rätsel" if mode == "delivery" else ""))
	)
	column.add_child(row)
	var save_text: String = str(data.get("save", ""))
	if save_text.is_empty():
		column.add_child(_button(
			"LOSFLIEGEN!", "StartFlight", func() -> void: start_pressed.emit(false), true, UI.GOLD, 62.0
		))
	else:
		var resume: Button = _button(
			"Weiterfliegen · %s" % save_text,
			"ResumeFlight",
			func() -> void: start_pressed.emit(true),
			true,
			UI.GOLD,
			62.0
		)
		var fresh: Button = _button(
			"Neu beginnen",
			"StartFlight",
			func() -> void: start_pressed.emit(false),
			false,
			UI.CYAN,
			62.0
		)
		column.add_child(
			_row([resume, fresh], 2 if not wide or panel_area.size.x / u > 420.0 else 1)
		)
	var line: String = str(data.get("best", {}).get("_line", ""))
	if not line.is_empty():
		column.add_child(UI.label(line, 14.0, u, UI.MUTED))


func _caption(text: String) -> Label:
	var label: Label = UI.label(text, 15.0, _unit, UI.MUTED, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _mode_card(id: String, selected: bool, best: String) -> Button:
	var u: float = _unit
	var accent: Color = MODE_ACCENT[id]
	var button := Button.new()
	button.name = "Mode_" + id
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(90.0, 92.0) * u
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = TUNING.MODE_NAMES[id] + ("\n" + best if not best.is_empty() else "")
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font", UI.UI.HEADING)
	button.add_theme_font_size_override("font_size", roundi(16.0 * u))
	var face := StyleBoxFlat.new()
	face.bg_color = accent.darkened(0.15) if selected else Color(0.05, 0.2, 0.38, 0.95)
	face.border_color = Color("fff5ba") if selected else accent
	face.set_border_width_all(maxi(1, roundi((3.0 if selected else 2.0) * u)))
	face.border_width_bottom = maxi(2, roundi(5.0 * u))
	face.set_corner_radius_all(roundi(16.0 * u))
	face.set_content_margin_all(6.0 * u)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, face)
	var ink: Color = UI.INK if selected else UI.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.pressed.connect(func() -> void: mode_selected.emit(id))
	return button


func _swatch(id: String, selected: bool) -> Button:
	var u: float = _unit
	var colours: Dictionary = GLIDER.COLOURS[id]
	var button := Button.new()
	button.name = "Colour_" + id
	button.tooltip_text = str(colours.name)
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(50.0, 50.0) * u
	var face := StyleBoxFlat.new()
	face.bg_color = colours.paint
	face.border_color = Color("fff5ba") if selected else colours.trim
	face.set_border_width_all(maxi(2, roundi((5.0 if selected else 4.0) * u)))
	face.set_corner_radius_all(roundi(25.0 * u))
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, face)
	button.pressed.connect(func() -> void: colour_selected.emit(id))
	return button


# ------------------------------------------------------------------ help, loading


func _build_help() -> void:
	_veil(0.55)
	var column: VBoxContainer = _dialog(UI.GOLD, 470.0)
	var u: float = _unit
	var title: Label = UI.label("So fliegt die Sternenpost", 28.0, u, UI.GOLD, true)
	column.add_child(title)
	var lines: Array[String] = [
		"Stick nach oben: steigen. Nach unten: sinken. Zur Seite: lenken.",
		"SCHWUNG: kurz schneller fliegen. Danach lädt er sich wieder auf.",
		"Leuchtende Säulen sind Aufwinde: Sie tragen dich nach oben.",
		"Lieferflug: Lies die Adresse auf der Karte. Flieg zum richtigen Haus und tippe ABWERFEN.",
		"Der Brief schwebt am Sternschirm hinunter. Der blaue Kreis zeigt, wo er landet.",
		"Wolkenrennen: Flieg durch die Ringe. Mitten durch gibt Schwung!",
		"Freiflug: Finde geheime Sterne und flieg durch die FOTO-Rahmen.",
		"Keine Angst: Wolkenpolster fangen dich immer auf.",
	]
	for text in lines:
		var label: Label = UI.label("• " + text, 17.0, u, UI.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(label)
	column.add_child(
		_button("Alles klar!", "CloseHelp", func() -> void: help_closed.emit(), true, UI.GOLD)
	)


func _build_loading() -> void:
	_veil(0.35)
	var column: VBoxContainer = _dialog(UI.CYAN, 360.0)
	var u: float = _unit
	column.add_child(UI.label(str(data.get("title", "Wolkenhafen")), 28.0, u, UI.GOLD, true))
	column.add_child(
		UI.label(str(data.get("text", "Lumo macht den Sternsegler startklar …")), 17.0, u, UI.WHITE)
	)


# ------------------------------------------------------------------ pause and result


func _build_pause() -> void:
	_veil(0.6)
	var column: VBoxContainer = _dialog(UI.CYAN, 420.0)
	var u: float = _unit
	column.add_child(UI.label("Pause", 32.0, u, UI.GOLD, true))
	column.add_child(UI.label(str(data.get("summary", "")), 17.0, u, UI.WHITE))
	if not str(data.get("save_note", "")).is_empty():
		column.add_child(UI.label(str(data.get("save_note", "")), 14.0, u, UI.MUTED))
	column.add_child(
		_button("Weiterfliegen", "Resume", func() -> void: resume_pressed.emit(), true, UI.GOLD)
	)
	var others: Array = [
		_button("Neu starten", "Restart", func() -> void: restart_pressed.emit()),
		_button("Zum Menü", "Menu", func() -> void: menu_pressed.emit()),
	]
	if bool(data.get("free", false)):
		others.insert(
			0,
			_button(
				"Freiflug beenden", "EndFree", func() -> void: again_pressed.emit(), false, UI.GOLD
			)
		)
	column.add_child(_row(others, 2))
	column.add_child(
		_button(
			"Zur Spielewelt",
			"Leave",
			func() -> void: leave_pressed.emit("games"),
			false,
			UI.CYAN,
			50.0
		)
	)
	if not str(data.get("notice", "")).is_empty():
		column.add_child(UI.label(str(data.notice), 15.0, u, Color("ffb0a0")))


func _build_result() -> void:
	_veil(0.35)
	var accent: Color = data.get("medal_colour", UI.GOLD)
	var column: VBoxContainer = _dialog(accent, 440.0)
	var u: float = _unit
	column.add_child(UI.label(str(data.get("title", "Geschafft!")), 30.0, u, UI.GOLD, true))
	var stars := Control.new()
	stars.name = "Seal"
	stars.custom_minimum_size = Vector2(0, 64.0 * u)
	var rating: int = int(data.get("rating", 1))
	stars.draw.connect(
		func() -> void:
			var w: float = stars.size.x
			for index in range(3):
				var centre := Vector2(w * 0.5 + (float(index) - 1.0) * 62.0 * u, 32.0 * u)
				var lit: bool = index < rating
				stars.draw_colored_polygon(
					UI.star_points(centre, 27.0 * u), UI.GOLD if lit else Color(0.3, 0.38, 0.5, 0.8)
				)
	)
	column.add_child(stars)
	column.add_child(UI.label(str(data.get("medal", "")), 20.0, u, accent, true))
	var facts := GridContainer.new()
	facts.name = "Facts"
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", roundi(14.0 * u))
	facts.add_theme_constant_override("v_separation", roundi(4.0 * u))
	for fact in data.get("facts", []):
		var key: Label = UI.label(str(fact[0]), 17.0, u, UI.MUTED)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Label = UI.label(str(fact[1]), 17.0, u, UI.WHITE, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts.add_child(key)
		facts.add_child(value)
	column.add_child(facts)
	if not str(data.get("note", "")).is_empty():
		column.add_child(UI.label(str(data.note), 15.0, u, UI.WHITE))
	if not str(data.get("notice", "")).is_empty():
		column.add_child(UI.label(str(data.notice), 15.0, u, Color("ffb0a0")))
	var again: Button = _button(
		"Nochmal fliegen", "Again", func() -> void: again_pressed.emit(), true, UI.GOLD, 64.0
	)
	var menu: Button = _button(
		"Zum Menü", "Menu", func() -> void: menu_pressed.emit(), false, UI.CYAN, 64.0
	)
	column.add_child(_row([again, menu], 2))
	column.add_child(
		_button(
			"Zur Spielewelt",
			"Leave",
			func() -> void: leave_pressed.emit("games"),
			false,
			UI.CYAN,
			50.0
		)
	)
