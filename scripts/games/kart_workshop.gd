extends Control
## Tuning-Werkstatt: Links die Bühne mit dem Kart und den Werten, rechts Teile verbessern und
## Aussehen wählen. Bezahlt wird mit Fortschrittssternen aus dem Lernen (siehe kart_tuning.gd).
## Alle Änderungen sieht man sofort am drehenden Kart; Rückgabe aller Sterne ist jederzeit möglich.
signal closed
signal changed
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const BARS = preload("res://scripts/games/kart_stat_bars.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const GOLD := Color("ffd06a")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")

## Wird vor dem Einhängen gesetzt.
var tuning
var kart_id: String = "comet"
var driver_id: String = "fox"
var reduced_motion: bool = false
var graphics_profile: String = "high"

var page_margin: MarginContainer
var title_label: Label
var budget_label: Label
var back_button: Button
var body: GridContainer
var left_column: VBoxContainer
var right_scroll: ScrollContainer
var preview_container: SubViewportContainer
var preview_pivot: Node3D
var preview_kart: Node3D
var preview_angle: float = 0.6
var rotate_drag: bool = false
var stats_panel: PanelContainer
var bars
var level_label: Label
var toast_label: Label
var toast_time: float = 0.0
var part_rows: Dictionary = {}
var swatch_rows: Dictionary = {}
var buy_buttons: Dictionary = {}
var pending_option: Dictionary = {}
var refund_button: Button
var refund_armed: float = 0.0
var layout_columns: int = 2
var compact: bool = false
var dyno_label: Label
var dyno_button: Button
var dyno_time: float = 0.0
var dyno_speed: float = 0.0


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
	veil.color = Color(0.012, 0.035, 0.10, 0.86)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	page_margin = MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, 24)
	add_child(page_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	page_margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	back_button = _button("← Zurück", func(): closed.emit())
	back_button.name = "WorkshopBack"
	header.add_child(back_button)
	title_label = _label("", 30, Color("f4f8ff"), true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)
	budget_label = _label("", 20, GOLD, true)
	budget_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	budget_label.name = "WorkshopBudget"
	budget_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(budget_label)
	body = GridContainer.new()
	body.columns = 2
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("h_separation", 20)
	body.add_theme_constant_override("v_separation", 12)
	column.add_child(body)
	_build_left()
	_build_right()
	get_viewport().size_changed.connect(_apply_layout)
	_refresh_all()
	_apply_layout.call_deferred()


func _label(value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", UI.HEADING if heading else UI.BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _glass(selected: bool = false, tint: Color = Color(0.025, 0.085, 0.18, 0.89)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.30, 0.42, 0.96) if selected else tint
	style.border_color = Color("65e7f0") if selected else Color(0.4, 0.7, 0.9, 0.26)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0.02, 0.06, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style


func _button(value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(120, 56)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_font_override("font", UI.HEADING if primary else UI.BODY)
	button.add_theme_color_override("font_color", Color("f4f8ff"))
	button.add_theme_color_override("font_disabled_color", Color("8295ab"))
	button.add_theme_stylebox_override("normal", _glass(primary))
	button.add_theme_stylebox_override("hover", _glass(true))
	button.add_theme_stylebox_override("pressed", _glass(true))
	button.add_theme_stylebox_override("focus", _glass(true))
	button.add_theme_stylebox_override("disabled", _glass(false, Color(0.04, 0.06, 0.11, 0.7)))
	button.pressed.connect(callback)
	return button


func _build_left() -> void:
	left_column = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	body.add_child(left_column)
	var stage_panel := PanelContainer.new()
	stage_panel.add_theme_stylebox_override("panel", _glass(false))
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(stage_panel)
	preview_container = SubViewportContainer.new()
	preview_container.stretch = true
	preview_container.custom_minimum_size = Vector2(240, 200)
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.gui_input.connect(_preview_input)
	stage_panel.add_child(preview_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	preview_container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var built: Dictionary = STAGE.build(stage)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("ceeaff")
	fill.light_energy = 0.65
	stage.add_child(fill)
	preview_pivot = built.pivot
	toast_label = _label("", 18, Color("9ff3ff"), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.name = "WorkshopToast"
	left_column.add_child(toast_label)
	stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _glass(false))
	left_column.add_child(stats_panel)
	var stats_column := VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_column)
	level_label = _label("", 15, Color("b5c9df"))
	stats_column.add_child(level_label)
	bars = BARS.new()
	bars.reduced_motion = reduced_motion
	bars.name = "WorkshopStats"
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_column.add_child(bars)


func _build_right() -> void:
	right_scroll = ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	right_scroll.add_child(column)
	column.add_child(_label("LEISTUNG", 14, Color("74e5f5"), true))
	var dyno_panel := PanelContainer.new()
	dyno_panel.add_theme_stylebox_override("panel", _glass(true))
	column.add_child(dyno_panel)
	var dyno_column := VBoxContainer.new()
	dyno_panel.add_child(dyno_column)
	dyno_column.add_child(_label("PRÜFSTAND · SERIE → DEIN KART", 16, Color("74e5f5"), true))
	dyno_label = _label("", 16, Color("f4f8ff"))
	dyno_label.name = "WorkshopDynoReport"
	dyno_column.add_child(dyno_label)
	dyno_column.add_child(_label("Simulation auf ebener Straße · Abenteuer · ohne Boost", 12, Color("b5c9df")))
	dyno_button = _button("Prüflauf starten", _start_dyno, true)
	dyno_button.name = "WorkshopDynoStart"
	dyno_column.add_child(dyno_button)
	for part in TUNING.PARTS:
		column.add_child(_build_part_row(part))
	column.add_child(_label("AUSSEHEN", 14, Color("74e5f5"), true))
	var kinds: Array = [["paint", "Lack"], ["rims", "Felgen"], ["neon", "Neon"]]
	for entry in kinds:
		column.add_child(_build_swatch_row(str(entry[0]), str(entry[1])))
	refund_button = _button("Alle Teile zurücksetzen und Sterne zurückholen", _on_refund)
	refund_button.name = "WorkshopRefund"
	refund_button.add_theme_font_size_override("font_size", 16)
	refund_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(refund_button)


func _build_part_row(part: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Part_" + str(part.id)
	panel.add_theme_stylebox_override("panel", _glass(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	row.add_child(texts)
	var title: Label = _label("%s" % part.name, 22, Color("f4f8ff"), true)
	title.name = "Title"
	texts.add_child(title)
	var hint: Label = _label(str(part.hint), 14, Color("b5c9df"))
	hint.name = "Hint"
	texts.add_child(hint)
	var effect: Label = _label(_effect_text(part), 13, Color("74e5f5"))
	effect.name = "Effect"
	texts.add_child(effect)
	var pips := Control.new()
	pips.name = "Pips"
	pips.custom_minimum_size = Vector2(112, 24)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.draw.connect(func(): _draw_pips(pips, str(part.id)))
	row.add_child(pips)
	var button := _button("", func(): _on_upgrade(str(part.id)), true)
	button.name = "Upgrade"
	button.custom_minimum_size = Vector2(150, 56)
	row.add_child(button)
	part_rows[str(part.id)] = {"panel": panel, "pips": pips, "button": button, "hint": hint, "title": title}
	return panel


func _effect_text(part: Dictionary) -> String:
	var pieces: PackedStringArray = []
	for stat in part.bonus:
		pieces.append("+%s %s" % [str(part.bonus[stat]).replace(".", ","), FLEET.STAT_NAMES[stat]])
	return "Je Stufe: " + ", ".join(pieces)


func _draw_pips(canvas: Control, part_id: String) -> void:
	var level: int = tuning.level(kart_id, part_id)
	var gap: float = 5.0
	var width: float = (canvas.size.x - gap * float(TUNING.MAX_LEVEL - 1)) / float(TUNING.MAX_LEVEL)
	var height: float = minf(canvas.size.y, 18.0)
	for index in range(TUNING.MAX_LEVEL):
		var rect := Rect2(float(index) * (width + gap), (canvas.size.y - height) * 0.5, width, height)
		var filled: bool = index < level
		canvas.draw_rect(rect, GOLD if filled else Color(0.07, 0.17, 0.30, 0.95), true)
		if filled:
			canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.4)), Color(1, 1, 1, 0.3), true)


func _build_swatch_row(kind: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Look_" + kind
	panel.add_theme_stylebox_override("panel", _glass(false))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var name_label: Label = _label(title, 20, Color("f4f8ff"), true)
	name_label.name = "Title"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var buy: Button = _button("", func(): _on_buy(kind), true)
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(150, 44)
	buy.add_theme_font_size_override("font_size", 15)
	buy.visible = false
	head.add_child(buy)
	buy_buttons[kind] = buy
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	column.add_child(flow)
	var buttons: Dictionary = {}
	for option in TUNING.options(kind):
		var swatch := Button.new()
		swatch.name = "Swatch_" + str(option.id)
		swatch.custom_minimum_size = Vector2(64, 60)
		swatch.tooltip_text = str(option.name)
		swatch.add_theme_font_size_override("font_size", 14)
		swatch.add_theme_font_override("font", UI.HEADING)
		swatch.add_theme_color_override("font_color", Color("ffffff"))
		swatch.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.06, 0.9))
		swatch.add_theme_constant_override("outline_size", 5)
		swatch.pressed.connect(func(): _on_swatch(kind, str(option.id)))
		flow.add_child(swatch)
		buttons[str(option.id)] = swatch
	var chosen_label: Label = _label("", 14, Color("b5c9df"))
	chosen_label.name = "Chosen"
	column.add_child(chosen_label)
	swatch_rows[kind] = {"panel": panel, "buttons": buttons, "chosen": chosen_label, "buy": buy}
	return panel


func _swatch_color(kind: String, option: Dictionary) -> Color:
	var base: Dictionary = FLEET.entry(kart_id).look
	match kind:
		"paint":
			return option.get("paint", base.paint)
		"rims":
			return option.get("color", Color("c9d6e6"))
		_:
			return option.get("color", base.neon)


# ------------------------------------------------------------------ Aktualisieren

func _refresh_all() -> void:
	var item: Dictionary = FLEET.entry(kart_id)
	title_label.text = "TUNING-WERKSTATT · %s" % str(item.name).to_upper()
	budget_label.text = "★ %d frei" % tuning.available()
	var stats: Dictionary = FLEET.base_stats(kart_id)
	var extra: Dictionary = tuning.bonus(kart_id)
	for key in FLEET.STATS:
		extra[key] = minf(float(extra[key]), maxf(0.0, FLEET.MAX_STAT - float(stats[key])))
	bars.set_values(stats, extra)
	level_label.text = "%s · %s · Tuning %d von %d" % [item.name, item.role, tuning.total_level(kart_id), TUNING.MAX_LEVEL * TUNING.PARTS.size()]
	for part in TUNING.PARTS:
		var id: String = str(part.id)
		var level: int = tuning.level(kart_id, id)
		var button: Button = part_rows[id].button
		var price: int = tuning.next_cost(kart_id, id)
		if price < 0:
			button.text = "Höchststufe"
			button.disabled = true
		elif tuning.can_upgrade(kart_id, id):
			button.text = "Stufe %d · ★ %d" % [level + 1, price]
			button.disabled = false
		else:
			button.text = "Noch %d ★" % (price - tuning.available())
			button.disabled = true
		part_rows[id].pips.queue_redraw()
	for kind in TUNING.KINDS:
		_refresh_swatches(kind)
	var any_levels: bool = tuning.total_level(kart_id) > 0
	refund_button.disabled = not any_levels
	refund_button.text = "Alle Teile zurücksetzen und ★ %d zurückholen" % _refund_value() if any_levels else "Noch nichts verbessert"
	_refresh_preview()
	_refresh_dyno()


func _refresh_dyno() -> void:
	var original: Dictionary = POWERTRAIN.report(FLEET.multipliers(FLEET.base_stats(kart_id)))
	var tuned: Dictionary = POWERTRAIN.report(tuning.multipliers(kart_id))
	dyno_label.text = (
		"Tempo  %.1f → %.1f km/h\n0–50  %.2f → %.2f s\n50–0  %.1f → %.1f m\nTurbo  %.2f → %.2f s"
		% [original.top_kmh, tuned.top_kmh, original.zero_fifty, tuned.zero_fifty,
		original.brake_metres, tuned.brake_metres, original.boost_seconds, tuned.boost_seconds]
	).replace(".", ",")
	# Upgrading or refunding invalidates a running simulation immediately.
	dyno_time = 0.0
	dyno_speed = 0.0
	dyno_button.text = "Prüflauf starten"


func _start_dyno() -> void:
	dyno_time = 0.001
	dyno_speed = 0.0
	preview_angle = 0.65


func _refund_value() -> int:
	var sum: int = 0
	for part in TUNING.PARTS:
		sum += TUNING.cost_to_reach(tuning.level(kart_id, str(part.id)))
	return sum


func _refresh_swatches(kind: String) -> void:
	var row: Dictionary = swatch_rows[kind]
	var chosen: String = tuning.chosen(kart_id, kind)
	var shown: String = str(pending_option.get(kind, chosen))
	for option in TUNING.options(kind):
		var id: String = str(option.id)
		var swatch: Button = row.buttons[id]
		var color: Color = _swatch_color(kind, option)
		var owned: bool = tuning.has_option(kind, id)
		var style := StyleBoxFlat.new()
		style.bg_color = color if owned else color.darkened(0.45)
		style.set_corner_radius_all(14)
		style.set_border_width_all(4 if id == shown else 1)
		style.border_color = Color("ffffff") if id == shown else Color(0.8, 0.9, 1.0, 0.45)
		style.set_content_margin_all(4)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.text = "" if owned else "★ %d" % int(option.cost)
		if kind == "rims" and id == "neon":
			swatch.text = "N" if owned else "★ %d" % int(option.cost)
	var option: Dictionary = TUNING.option(kind, shown)
	var buy: Button = buy_buttons[kind]
	var needs_purchase: bool = not tuning.has_option(kind, shown)
	buy.visible = needs_purchase
	if needs_purchase:
		var enough: bool = tuning.can_buy_option(kind, shown)
		buy.text = "Kaufen · ★ %d" % int(option.cost) if enough else "Noch %d ★" % (int(option.cost) - tuning.available())
		buy.disabled = not enough
	row.chosen.text = "%s%s" % [str(option.name), "" if not needs_purchase else " · noch nicht gekauft"]


func _refresh_preview() -> void:
	if not is_instance_valid(preview_pivot):
		return
	var look: Dictionary = tuning.look(kart_id)
	for kind in pending_option:
		var option: Dictionary = TUNING.option(kind, str(pending_option[kind]))
		match kind:
			"paint":
				look["paint"] = option.get("paint", look.paint)
				look["trim"] = option.get("trim", look.trim)
				look["accent"] = option.get("accent", look.accent)
			"rims":
				look["rim"] = option.get("color", look.rim)
				look["rim_neon"] = str(option.id) == "neon"
			"neon":
				look["neon"] = option.get("color", look.neon)
				look["neon_custom"] = str(option.id) != "werk"
				look["underglow"] = str(option.id) != "werk" or look.underglow
	if not is_instance_valid(preview_kart):
		preview_kart = VEHICLE.new()
		var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, driver_id)
		preview_kart.set_look(look)
		preview_kart.configure(driver_id, driver.color, kart_id)
		preview_kart.reduced_motion = reduced_motion
		preview_kart.set_graphics_quality(graphics_profile)
		preview_pivot.add_child(preview_kart)
	else:
		preview_kart.set_look(look)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_time = 2.4


# ------------------------------------------------------------------ Aktionen

func _on_upgrade(part_id: String) -> void:
	if tuning.upgrade(kart_id, part_id):
		var gain: Dictionary = tuning.performance(kart_id, true)
		_show_toast("%s auf Stufe %d! Tempo %d km/h · Bremsweg %.1f m" % [TUNING.part(part_id).name, tuning.level(kart_id, part_id), roundi(float(gain.top_kmh)), float(gain.brake_m)])
		_pop_preview()
		refund_armed = 0.0
		_refresh_all()
		changed.emit()


func _on_swatch(kind: String, id: String) -> void:
	if tuning.has_option(kind, id):
		pending_option.erase(kind)
		if tuning.choose(kart_id, kind, id):
			_show_toast("%s: %s" % [_kind_title(kind), TUNING.option(kind, id).name])
			changed.emit()
	else:
		# Erst ansehen, dann kaufen: Das Kart zeigt den Vorschlag, der Kauf braucht einen zweiten Tipp.
		pending_option[kind] = id
	_refresh_all()


func _kind_title(kind: String) -> String:
	return {"paint": "Lack", "rims": "Felgen", "neon": "Neon"}.get(kind, kind)


func _on_buy(kind: String) -> void:
	var id: String = str(pending_option.get(kind, ""))
	if id.is_empty():
		return
	if tuning.buy_option(kind, id):
		tuning.choose(kart_id, kind, id)
		pending_option.erase(kind)
		_show_toast("%s gekauft: %s" % [_kind_title(kind), TUNING.option(kind, id).name])
		_pop_preview()
		_refresh_all()
		changed.emit()


func _on_refund() -> void:
	# Doppelt tippen bestätigt: Es gehen alle Teile zurück auf Stufe 0.
	if refund_armed <= 0.0:
		refund_armed = 3.0
		refund_button.text = "Sicher? Nochmal tippen: ★ %d zurück" % _refund_value()
		return
	var back: int = tuning.refund(kart_id)
	refund_armed = 0.0
	_show_toast("★ %d zurück – das Aussehen bleibt." % back)
	_refresh_all()
	changed.emit()


func _pop_preview() -> void:
	if reduced_motion or not is_instance_valid(preview_kart):
		return
	var tween := create_tween()
	preview_kart.scale = Vector3.ONE * 1.06
	tween.tween_property(preview_kart, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Zurück-Taste: Die Werkstatt schließt sich selbst.
func handle_back() -> bool:
	closed.emit()
	return true


# ------------------------------------------------------------------ Eingabe und Layout

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		rotate_drag = event.pressed
	elif event is InputEventMouseMotion and rotate_drag:
		preview_angle += event.relative.x * 0.008
	elif event is InputEventScreenDrag:
		preview_angle += event.relative.x * 0.008


func _process(delta: float) -> void:
	if not visible:
		return
	if is_instance_valid(preview_pivot):
		if not rotate_drag and not reduced_motion and dyno_time <= 0.0:
			preview_angle += delta * 0.18
		preview_pivot.rotation.y = preview_angle
	if dyno_time > 0.0:
		dyno_time += delta
		var factors: Dictionary = tuning.multipliers(kart_id)
		var braking: bool = dyno_time > 3.5
		var target: float = 0.0 if braking else POWERTRAIN.top_speed(factors)
		dyno_speed = move_toward(dyno_speed, target, delta * POWERTRAIN.acceleration(factors, braking))
		dyno_button.text = "%s · %d km/h" % ["Bremsen" if braking else "Beschleunigen", roundi(dyno_speed * 3.6)]
		if braking and dyno_speed <= 0.0:
			dyno_time = 0.0
			dyno_button.text = "Prüflauf wiederholen"
	if is_instance_valid(preview_kart):
		preview_kart.set_motion(dyno_speed if not reduced_motion else 0.0, 0.0, false, false)
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_label.text = ""
	if refund_armed > 0.0:
		refund_armed -= delta
		if refund_armed <= 0.0:
			_refresh_all()


func _apply_layout() -> void:
	if not is_inside_tree() or not is_instance_valid(body):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(get_window().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	var ui_scale: float = maxf(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var portrait: bool = window_size.x < window_size.y
	var short_landscape: bool = not portrait and window_size.y < 600
	compact = window_size.x < 520 or short_landscape
	layout_columns = 1 if portrait else 2
	body.columns = layout_columns
	var margin: float = clampf(minf(window_size.x, window_size.y) * 0.03, 8.0, 24.0)
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, roundi(margin * ui_scale))
	# Sicherer Bereich (Kamera-Ausschnitt, Gesten-Leiste) wie in der Garage.
	if (OS.has_feature("android") or OS.has_feature("ios")) and not get_parent().get_meta("kart_safe_insets_applied", false):
		var insets: Rect2 = MobileRuntime.get_safe_area_insets()
		var scale: Vector2 = viewport_size / window_size
		page_margin.offset_left = insets.position.x * scale.x
		page_margin.offset_top = insets.position.y * scale.y
		page_margin.offset_right = -insets.size.x * scale.x
		page_margin.offset_bottom = -insets.size.y * scale.y
	var button_height: float = (44.0 if short_landscape else 56.0) * ui_scale
	back_button.custom_minimum_size = Vector2((96.0 if compact else 130.0) * ui_scale, button_height)
	back_button.add_theme_font_size_override("font_size", roundi((15 if compact else 18) * ui_scale))
	title_label.add_theme_font_size_override("font_size", roundi((18 if compact else 30) * ui_scale))
	budget_label.add_theme_font_size_override("font_size", roundi((15 if compact else 20) * ui_scale))
	preview_container.custom_minimum_size = Vector2(150, 70 if short_landscape else (150 if portrait else 200)) * ui_scale
	stats_panel.visible = not (short_landscape and window_size.y < 440)
	bars.row_height = (20.0 if compact else 30.0) * ui_scale
	bars.font_scale = ui_scale
	toast_label.add_theme_font_size_override("font_size", roundi((14 if compact else 18) * ui_scale))
	level_label.add_theme_font_size_override("font_size", roundi((12 if compact else 15) * ui_scale))
	for id in part_rows:
		var row: Dictionary = part_rows[id]
		row.title.add_theme_font_size_override("font_size", roundi((17 if compact else 22) * ui_scale))
		row.hint.add_theme_font_size_override("font_size", roundi((12 if compact else 14) * ui_scale))
		row.hint.visible = not short_landscape
		row.button.custom_minimum_size = Vector2((118 if compact else 150) * ui_scale, button_height)
		row.button.add_theme_font_size_override("font_size", roundi((14 if compact else 18) * ui_scale))
		row.pips.custom_minimum_size = Vector2((84 if compact else 112) * ui_scale, 22 * ui_scale)
	for kind in swatch_rows:
		var swatch_row: Dictionary = swatch_rows[kind]
		for id in swatch_row.buttons:
			swatch_row.buttons[id].custom_minimum_size = Vector2((52 if compact else 64) * ui_scale, (48 if compact else 60) * ui_scale)
		swatch_row.buy.custom_minimum_size = Vector2((120 if compact else 150) * ui_scale, 44 * ui_scale)
	refund_button.custom_minimum_size.y = button_height
	dyno_button.custom_minimum_size.y = button_height
