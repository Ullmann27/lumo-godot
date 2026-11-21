extends Control
## The screens around the run: course selection, loading, learning stop, pause
## and result. One screen is shown at a time and rebuilt when the window changes
## (portrait, landscape, folded), so every layout is a fresh, simple pass.

signal course_chosen(index: int, resume: bool)
signal answer_chosen(answer: String)
signal resume_pressed
signal restart_pressed
signal courses_pressed
signal again_pressed
signal leave_pressed(destination: String)

const UI = preload("res://scripts/games/run/run_ui.gd")

var screen: String = ""
var data: Dictionary = {}
## Screen rectangle left free for the live Lumo on the start screen.
var hero_rect := Rect2()
var _unit: float = 1.0
var _short: bool = false


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
	mouse_filter = Control.MOUSE_FILTER_IGNORE if screen.is_empty() else Control.MOUSE_FILTER_STOP
	match screen:
		"start":
			_build_start()
		"loading":
			_build_loading()
		"question":
			_build_question()
		"pause":
			_build_pause()
		"result":
			_build_result()


# ------------------------------------------------------------------ shared pieces

func _veil(alpha: float) -> void:
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.01, 0.05, 0.14, alpha)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)


## A glass panel with a scrolling column; returns the column. `dock` places it
## in the middle, at the bottom or on the right so the scene stays visible.
func _dialog(accent: Color, width_dp: float, dock: String = "center") -> VBoxContainer:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector4 = UI.margins(self, 12.0)
	var panel := PanelContainer.new()
	panel.name = "Dialog"
	panel.add_theme_stylebox_override("panel", UI.panel(accent, u))
	var width: float = minf(width_dp * u, view.x - m.x - m.z)
	var height: float = view.y - m.y - m.w
	panel.position = Vector2((view.x - width) * 0.5, m.y)
	panel.size = Vector2(width, height)
	# Wrapped labels only know their height after a layout pass: fit, then show.
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
	_fit_dialog(panel, column, dock)
	return column


func _fit_dialog(panel: PanelContainer, column: VBoxContainer, dock: String) -> void:
	for _pass in range(2):
		await get_tree().process_frame
		if not is_instance_valid(panel) or not is_instance_valid(column):
			return
		var view: Vector2 = get_viewport().get_visible_rect().size
		var m: Vector4 = UI.margins(self, 12.0)
		var limit: float = view.y - m.y - m.w
		var height: float = minf(column.get_combined_minimum_size().y + 36.0 * _unit, limit)
		panel.size = Vector2(panel.size.x, height)
		var x: float = (view.x - panel.size.x) * 0.5
		var y: float = maxf(m.y, (view.y - height) * 0.5)
		if dock == "bottom":
			y = view.y - m.w - height
		elif dock == "right":
			x = view.x - m.z - panel.size.x
		panel.position = Vector2(x, y)
	panel.modulate.a = 1.0


## Rectangle of the open dialog in viewport units (empty when none is open).
func dialog_rect() -> Rect2:
	var panel := get_node_or_null("Dialog") as Control
	return panel.get_global_rect() if panel != null else Rect2()


## The main action over the full width, the others below it (two per row when wide).
func _actions(column: Container, buttons: Array[Button], wide: bool) -> void:
	if buttons.is_empty():
		return
	column.add_child(buttons[0])
	var grid := GridContainer.new()
	grid.name = "Actions"
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", roundi(10.0 * _unit))
	grid.add_theme_constant_override("v_separation", roundi(10.0 * _unit))
	for index in range(1, buttons.size()):
		grid.add_child(buttons[index])
	column.add_child(grid)


func _button(text: String, node_name: String, action: Callable, primary: bool = false, accent: Color = UI.CYAN) -> Button:
	var button: Button = UI.button(text, _unit, accent, primary)
	button.name = node_name
	button.pressed.connect(action)
	return button


# ------------------------------------------------------------------ course selection

func _build_start() -> void:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector4 = UI.margins(self, 14.0)
	var wide: bool = view.x > view.y * 1.15
	var inner := Rect2(m.x, m.y, view.x - m.x - m.z, view.y - m.y - m.w)
	var back: Button = _button("‹ Spiele", "BackToGames", func() -> void: leave_pressed.emit("games"))
	back.custom_minimum_size = Vector2(118.0, 48.0) * u
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.position = inner.position
	back.size = Vector2(118.0, 48.0) * u
	add_child(back)
	var title: Label = UI.label("LUMO LAUF", 50.0 if wide else 44.0, u, UI.GOLD, true)
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", UI.INK)
	title.add_theme_constant_override("outline_size", roundi(10.0 * u))
	var subtitle: Label = UI.label("Lauf, spring und sammle Sterne!", 19.0, u, UI.WHITE)
	subtitle.name = "Subtitle"
	add_child(title)
	add_child(subtitle)
	var cards: Array = data.get("cards", [])
	var gap: float = 14.0 * u
	if wide:
		# Lumo on the left, the three courses side by side on the right.
		_short = inner.size.y / u < 430.0
		var hero_width: float = minf(inner.size.x * 0.24, inner.size.y * 0.62)
		var head: float = (50.0 if _short else 100.0) * u
		hero_rect = Rect2(inner.position.x, inner.position.y + 56.0 * u, hero_width, inner.size.y - 60.0 * u)
		var area := Rect2(
			inner.position.x + hero_width + gap, inner.position.y, inner.size.x - hero_width - gap, inner.size.y
		)
		if _short:
			title.add_theme_font_size_override("font_size", roundi(34.0 * u))
			subtitle.hide()
		title.position = area.position
		title.size = Vector2(area.size.x, (44.0 if _short else 62.0) * u)
		subtitle.position = area.position + Vector2(0, 62.0 * u)
		subtitle.size = Vector2(area.size.x, 28.0 * u)
		var top: float = area.position.y + head
		var card_width: float = (area.size.x - gap * float(cards.size() - 1)) / float(maxi(1, cards.size()))
		for index in range(cards.size()):
			_add_card(
				cards[index],
				Rect2(area.position.x + float(index) * (card_width + gap), top, card_width, area.end.y - top),
				true
			)
	else:
		var narrow: bool = inner.size.x / u < 520.0
		var title_size: float = 38.0 if narrow else 46.0
		title.add_theme_font_size_override("font_size", roundi(title_size * u))
		title.position = Vector2(inner.position.x, inner.position.y + (46.0 if narrow else 54.0) * u)
		title.size = Vector2(inner.size.x, (title_size + 10.0) * u)
		subtitle.position = title.position + Vector2(0, (title_size + 8.0) * u)
		subtitle.size = Vector2(inner.size.x, 26.0 * u)
		var top: float = subtitle.position.y + 32.0 * u
		var available: float = inner.end.y - top
		# Lumo gets the space that the three cards do not need.
		var count: float = float(maxi(1, cards.size()))
		var smallest: float = (172.0 if narrow else 132.0) * u
		var largest: float = (190.0 if narrow else 190.0) * u
		var card_height: float = clampf((available - gap * count) / (count + 1.15), smallest, largest)
		if (card_height + gap) * count > available:
			card_height = maxf(120.0 * u, available / count - gap)
		var hero_height: float = maxf(0.0, available - (card_height + gap) * count)
		hero_rect = Rect2(inner.position.x, top, inner.size.x, hero_height)
		if hero_height < 110.0 * u:
			hero_rect = Rect2()
		var y: float = top + hero_height
		for index in range(cards.size()):
			_add_card(cards[index], Rect2(inner.position.x, y, inner.size.x, card_height), false)
			y += card_height + gap


func _add_card(card: Dictionary, rect: Rect2, tall: bool) -> void:
	var u: float = _unit
	var accent: Color = card.accent
	var panel := PanelContainer.new()
	panel.name = "Course%d" % int(card.index)
	var style: StyleBoxFlat = UI.panel(accent, u, 0.9)
	style.set_content_margin_all(12.0 * u)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = rect.position
	panel.size = rect.size
	add_child(panel)
	var narrow: bool = not tall and rect.size.x / u < 520.0
	var emblem := Control.new()
	emblem.name = "Emblem"
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(_draw_emblem.bind(emblem, str(card.emblem), accent))
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if tall else HORIZONTAL_ALIGNMENT_LEFT
	var name_label: Label = UI.label(str(card.name), 23.0 if narrow else 25.0, u, UI.WHITE, true)
	var kicker_text: String = "%s · %s" % [str(card.length), str(card.kicker)]
	if tall and _short:
		kicker_text = str(card.length)
	var kicker: Label = UI.label(kicker_text, 14.0, u, accent.lightened(0.25))
	var description: Label = UI.label(str(card.description), 14.0 if narrow else 15.0, u, UI.MUTED)
	var best: Label = UI.label(str(card.best), 14.0, u, UI.GOLD)
	if tall and _short:
		name_label.add_theme_font_size_override("font_size", roundi(21.0 * u))
		description.add_theme_font_size_override("font_size", roundi(13.0 * u))
		# Low landscape screens: the buttons must stay inside the card, so the
		# text is shortened; a card with a saved run shows its two buttons instead.
		description.max_lines_visible = 2
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.visible = not bool(card.resume)
	for label in [name_label, kicker, description, best]:
		label.horizontal_alignment = align
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var buttons := BoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", roundi(8.0 * u))
	var resume: bool = bool(card.resume)
	if resume:
		buttons.add_child(
			_button(str(card.resume_text), "Resume", func() -> void: course_chosen.emit(int(card.index), true), true, accent)
		)
	buttons.add_child(
		_button(
			"Neu starten" if resume else "Los!", "Start",
			func() -> void: course_chosen.emit(int(card.index), false), not resume, accent
		)
	)
	for button in buttons.get_children():
		button.custom_minimum_size.y = (46.0 if tall and _short else 50.0) * u
	if tall:
		# Landscape: one column per course.
		emblem.custom_minimum_size = Vector2(0, (40.0 if _short else minf(96.0, rect.size.y / u * 0.22)) * u)
		emblem.visible = not (_short and resume)
		buttons.vertical = true
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", roundi(6.0 * u))
		for item in [emblem, name_label, kicker, description, best, buttons]:
			column.add_child(item)
		panel.add_child(column)
	elif narrow:
		# Phone portrait: emblem and name on top, text below, best result and buttons last.
		emblem.custom_minimum_size = Vector2(50.0, 50.0) * u
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", roundi(10.0 * u))
		var titles := VBoxContainer.new()
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.add_theme_constant_override("separation", 0)
		titles.add_child(name_label)
		titles.add_child(kicker)
		head.add_child(emblem)
		head.add_child(titles)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", roundi(8.0 * u))
		best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(best)
		buttons.custom_minimum_size.x = (rect.size.x / u - 24.0) * (0.66 if resume else 0.42) * u
		foot.add_child(buttons)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", roundi(4.0 * u))
		column.add_child(head)
		column.add_child(description)
		column.add_child(foot)
		panel.add_child(column)
	else:
		# Wide portrait (tablet, unfolded): emblem, text and buttons in one row.
		emblem.custom_minimum_size = Vector2(84.0, 84.0) * u
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", roundi(3.0 * u))
		for item in [name_label, kicker, description, best]:
			texts.add_child(item)
		buttons.vertical = true
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.custom_minimum_size.x = 150.0 * u
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", roundi(12.0 * u))
		for item in [emblem, texts, buttons]:
			row.add_child(item)
		panel.add_child(row)


## Small original pictograms: a leaf, a glowing tree, a sun over waves.
func _draw_emblem(canvas: Control, kind: String, accent: Color) -> void:
	var side: float = minf(canvas.size.x, canvas.size.y)
	var centre: Vector2 = canvas.size * 0.5
	var radius: float = side * 0.46
	canvas.draw_circle(centre, radius, Color(accent.r, accent.g, accent.b, 0.22))
	canvas.draw_arc(centre, radius, 0.0, TAU, 48, accent, maxf(2.0, side * 0.035), true)
	match kind:
		"leaf":
			var leaf := PackedVector2Array()
			for step in range(25):
				var t: float = float(step) / 24.0 * TAU
				var reach: float = radius * 0.72 * (0.55 + 0.45 * cos(t))
				leaf.append(centre + Vector2(sin(t) * reach * 0.62, -cos(t) * reach + radius * 0.14).rotated(0.6))
			canvas.draw_colored_polygon(leaf, Color("48d6a0"))
			canvas.draw_line(
				centre + Vector2(-radius * 0.36, radius * 0.42), centre + Vector2(radius * 0.34, -radius * 0.42),
				Color("e9f7d2"), maxf(2.0, side * 0.04), true
			)
		"tree":
			canvas.draw_rect(
				Rect2(centre + Vector2(-radius * 0.09, radius * 0.1), Vector2(radius * 0.18, radius * 0.5)), Color("6b4a8f")
			)
			for blob in [Vector2(0, -0.28), Vector2(-0.26, -0.02), Vector2(0.26, -0.02)]:
				canvas.draw_circle(centre + blob * radius, radius * 0.34, Color("7b6cf0"))
			for spark in [Vector2(-0.1, -0.4), Vector2(0.22, -0.16), Vector2(-0.3, 0.0), Vector2(0.06, 0.02)]:
				canvas.draw_circle(centre + spark * radius, radius * 0.07, Color("9df3ff"))
		_:
			canvas.draw_circle(centre + Vector2(0, -radius * 0.12), radius * 0.36, Color("ffd75e"))
			for ray in range(8):
				var direction := Vector2.UP.rotated(float(ray) * TAU / 8.0)
				canvas.draw_line(
					centre + Vector2(0, -radius * 0.12) + direction * radius * 0.46,
					centre + Vector2(0, -radius * 0.12) + direction * radius * 0.62,
					Color("ffd75e"), maxf(2.0, side * 0.04), true
				)
			var wave := PackedVector2Array()
			for step in range(13):
				var x: float = -0.7 + 1.4 * float(step) / 12.0
				wave.append(centre + Vector2(x * radius, radius * (0.5 + 0.07 * sin(x * 9.0))))
			canvas.draw_polyline(wave, Color("7fe3ff"), maxf(2.0, side * 0.05), true)


func _build_loading() -> void:
	_veil(0.78)
	var column: VBoxContainer = _dialog(Color(data.get("accent", UI.CYAN)), 420.0)
	column.add_child(UI.label(str(data.get("name", "")), 30.0, _unit, UI.GOLD, true))
	column.add_child(UI.label("Die Strecke wird aufgebaut …", 19.0, _unit))


# ------------------------------------------------------------------ learning stop

func _build_question() -> void:
	var u: float = _unit
	_veil(0.45)
	# On the adventure path the panel sits low, so the puzzle gate stays in view.
	var column: VBoxContainer = _dialog(UI.CYAN, 600.0, str(data.get("dock", "center")))
	column.add_child(UI.label(str(data.header), 15.0, u, UI.CYAN, true))
	var prompt: Label = UI.label(str(data.prompt), 25.0, u, UI.WHITE, true)
	prompt.name = "Prompt"
	column.add_child(prompt)
	var options: Array = data.options
	var view: Vector2 = get_viewport().get_visible_rect().size
	var grid := GridContainer.new()
	grid.name = "Answers"
	grid.columns = options.size() if view.x > view.y and options.size() <= 3 else 1
	grid.add_theme_constant_override("h_separation", roundi(10.0 * u))
	grid.add_theme_constant_override("v_separation", roundi(10.0 * u))
	column.add_child(grid)
	var wrong: Array = data.get("wrong", [])
	var reveal: bool = bool(data.get("reveal", false))
	for index in range(options.size()):
		var option: String = str(options[index])
		var is_answer: bool = option == str(data.answer)
		var button: Button = UI.button(option, u, UI.CYAN, reveal and is_answer, 64.0)
		button.name = "Answer%d" % index
		button.add_theme_font_size_override("font_size", roundi(24.0 * u))
		button.disabled = wrong.has(option)
		button.pressed.connect(func() -> void: answer_chosen.emit(option))
		grid.add_child(button)
	var hint: Label = UI.label(str(data.message), 18.0, u, UI.GOLD if not wrong.is_empty() else UI.MUTED)
	hint.name = "Hint"
	column.add_child(hint)


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = view.x > view.y * 1.15
	_veil(0.55)
	var column: VBoxContainer = _dialog(UI.CYAN, 560.0 if wide else 440.0)
	column.add_child(UI.label("Kleine Pause", 28.0, u, UI.GOLD, true))
	column.add_child(UI.label(str(data.summary), 16.0, u, UI.MUTED))
	if data.has("notice"):
		var notice: Label = UI.label(str(data.notice), 16.0, u, Color("ffb3a1"))
		notice.name = "Notice"
		column.add_child(notice)
	var buttons: Array[Button] = [
		_button("Weiterlaufen", "Resume", func() -> void: resume_pressed.emit(), true),
		_button("Neu starten", "Restart", func() -> void: restart_pressed.emit()),
		_button("Andere Strecke", "Courses", func() -> void: courses_pressed.emit()),
		_button("Zur Spieleauswahl", "LeaveGames", func() -> void: leave_pressed.emit("games")),
		_button("Zum Lernen", "LeaveLearn", func() -> void: leave_pressed.emit("learn")),
	]
	_actions(column, buttons, wide)
	column.add_child(UI.label("Dein letzter Kontrollpunkt bleibt gespeichert.", 14.0, u, UI.MUTED))


# ------------------------------------------------------------------ result

func _build_result() -> void:
	var u: float = _unit
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = view.x > view.y * 1.15
	var accent: Color = data.get("accent", UI.GOLD)
	var short: bool = wide and view.y / u < 430.0
	var column: VBoxContainer = _dialog(
		accent, (560.0 if short else 470.0) if wide else 520.0, "right" if wide else "bottom"
	)
	column.add_theme_constant_override("separation", roundi((5.0 if short else 7.0) * u))
	var title: Label = UI.label("Geschafft! · %s" % str(data.course), 22.0 if short else 25.0, u, UI.GOLD, true)
	title.name = "Title"
	column.add_child(title)
	var rating := Control.new()
	rating.name = "Rating"
	rating.custom_minimum_size = Vector2(0, (46.0 if short else 62.0) * u)
	rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var medal_colour: Color = data.get("medal_colour", UI.GOLD)
	rating.draw.connect(_draw_rating.bind(rating, int(data.rating), medal_colour))
	column.add_child(rating)
	var facts := GridContainer.new()
	facts.name = "Facts"
	facts.columns = 4 if short else 2
	facts.add_theme_constant_override("h_separation", roundi((8.0 if short else 14.0) * u))
	facts.add_theme_constant_override("v_separation", roundi(2.0 * u))
	for fact in data.facts:
		var key: Label = UI.label(str(fact[0]), 15.0 if short else 17.0, u, UI.MUTED)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.size_flags_horizontal = Control.SIZE_FILL if short else Control.SIZE_EXPAND_FILL
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value: Label = UI.label(str(fact[1]), 16.0 if short else 19.0, u, UI.WHITE, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		facts.add_child(key)
		facts.add_child(value)
	column.add_child(facts)
	column.add_child(UI.label(str(data.thresholds), 12.0, u, UI.MUTED))
	if data.has("notice"):
		var notice: Label = UI.label(str(data.notice), 16.0, u, Color("ffb3a1"))
		notice.name = "Notice"
		column.add_child(notice)
	# A low landscape screen has room for one row of four: short words keep
	# every action visible without scrolling.
	var buttons: Array[Button] = [
		_button("Nochmal", "Again", func() -> void: again_pressed.emit(), true),
		_button("Strecken" if short else "Andere Strecke", "Courses", func() -> void: courses_pressed.emit()),
		_button("Spiele" if short else "Zur Spieleauswahl", "LeaveGames", func() -> void: leave_pressed.emit("games")),
		_button("Lernen" if short else "Zum Lernen", "LeaveLearn", func() -> void: leave_pressed.emit("learn")),
	]
	for button in buttons:
		button.custom_minimum_size = Vector2(60.0, 46.0 if short else 50.0) * u
		button.add_theme_font_size_override("font_size", roundi(16.0 * u))
	_actions(column, buttons, true)
	# Two rows of two: the main action sits beside "Andere Strecke".
	var grid := column.get_node("Actions") as GridContainer
	column.remove_child(buttons[0])
	grid.add_child(buttons[0])
	grid.move_child(buttons[0], 0)
	if short:
		grid.columns = 4
		for button in buttons:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw_rating(canvas: Control, rating: int, medal_colour: Color) -> void:
	var centre := canvas.size * 0.5
	var face: float = canvas.size.y * 0.36
	var medal_at := Vector2(centre.x - face * 3.1, centre.y - face * 0.13)
	for side in [-1.0, 1.0]:
		var ribbon := PackedVector2Array([
			medal_at + Vector2(side * 0.15, 0.4) * face,
			medal_at + Vector2(side * 0.68, 0.48) * face,
			medal_at + Vector2(side * 0.83, 1.45) * face,
			medal_at + Vector2(side * 0.27, 1.15) * face,
		])
		canvas.draw_colored_polygon(ribbon, medal_colour.darkened(0.38))
	canvas.draw_circle(medal_at, face, UI.INK)
	canvas.draw_circle(medal_at, face * 0.90, medal_colour)
	canvas.draw_circle(medal_at, face * 0.72, medal_colour.darkened(0.25))
	canvas.draw_colored_polygon(UI.star_points(medal_at, face * 0.55), medal_colour.lightened(0.35))
	var caption: String = str(data.get("medal", ""))
	var font: Font = get_theme_default_font()
	var text_size: int = roundi(16.0 * _unit)
	var text_width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	canvas.draw_string(font, centre + Vector2(face * 0.8 - text_width * 0.5, face * 1.2), caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, medal_colour)
	var radius: float = face * 0.63
	var step: float = radius * 2.5
	for index in range(3):
		var at := centre + Vector2(face * 0.8 + (float(index) - 1.0) * step, -face * 0.42)
		canvas.draw_colored_polygon(UI.star_points(at, radius * 1.12), UI.INK)
		canvas.draw_colored_polygon(
			UI.star_points(at, radius), medal_colour if index < rating else Color(0.3, 0.38, 0.5)
		)
