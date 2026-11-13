extends Node3D
## The production city-building variation of Bauwelt. Every purchase, day and
## opponent action is owned by the deterministic settlement model.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const RESIDENTS = preload("res://scripts/creative/build_settlement_residents.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const NEXTGEN_ENV = preload("res://scripts/creative/creative_nextgen_environment.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const EXPLORER = preload("res://scripts/creative/build_explorer.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const JUMP = preload("res://scripts/games/jump_touch_button.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const SPACING := 5.3
var model
var mode := "settlement"
var child_key := "standalone"
var slot := 1
var save_path := ""
var save_blocked := false
var kit := KIT.new()
var previous: Dictionary
var camera: Camera3D
var safe_ui: Control
var top: VBoxContainer
var bottom: VBoxContainer
var top_backdrop: Panel
var bottom_backdrop: Panel
var resource_label: Label
var goal_label: Label
var feedback: Label
var rival_label: Label
var day_button: Button
var expand_button: Button
var demolish_button: Button
var walk_button: Button
var trade_window: Window
var demolition_window: Window
var plot_label: Label
var purchase_buttons: Dictionary = {}
var transaction_buttons: Array[Button] = []
var plot_nodes: Dictionary = {}
var facility_nodes: Dictionary = {}
var selection_marker: MeshInstance3D
var selected_plot := -1
var selected_kind := "house"
var paused := false
var pause_panel: PanelContainer
var focus := Vector3(-16, 0, 0)
var orbit := 0.28
var tilt := 0.70
var radius := 34.0
var pointer := -1
var tap_origin := Vector2.ZERO
var dragged := false
var explorer: CharacterBody3D
var walking := false
var walk_controls: Control
var walk_stick: Control
var jump_button: Control
var stored_camera: Dictionary = {}
var rival_host: Node3D
var rival_destination := Vector3(16, 0.04, 10)
var rival_last_buildings := 0
var round_slots_full := false
var village_region: Node3D
var village_residents: Node3D
var village_window: Window


func _ready() -> void:
	previous = RUNTIME.enter(self, true)
	previous["embed_subwindows"] = get_viewport().gui_embed_subwindows
	get_viewport().gui_embed_subwindows = true
	SceneRouter.current_scene_id = "settlement"
	mode = (
		"rival"
		if str(SceneRouter.launch_options.get("settlementMode", "settlement")) == "rival"
		else "settlement"
	)
	child_key = str(
		SceneRouter.launch_options.get(
			"childKey", HostBridge.launch_options().get("childKey", "standalone")
		)
	)
	if child_key.is_empty():
		child_key = "standalone"
	slot = clampi(int(SceneRouter.launch_options.get("buildSlot", 1)), 1, 6)
	# An explicit opt-in keeps all existing classic Siedlung/Wettbau files intact.
	var village_requested: bool = (
		mode == "settlement"
		and bool(SceneRouter.launch_options.get(
			"livingVillage", HostBridge.launch_options().get("livingVillage", false)
		))
	)
	save_path = project_path(child_key, slot, "village" if village_requested else mode)
	model = STATE.new(mode, village_requested)
	if village_requested:
		focus = Vector3(-REGION.TOWN_CENTER, 0, 0)
		rival_destination.x = REGION.TOWN_CENTER
	if FileAccess.file_exists(save_path):
		var parser := JSON.new()
		var raw: Variant = null
		if parser.parse(FileAccess.get_file_as_string(save_path)) == OK:
			raw = parser.data
		var restored = restore_project(raw, child_key, slot, mode)
		if restored != null and restored.living_village == village_requested:
			model = restored
		elif restored != null and village_requested and not restored.living_village:
			restored.enable_living_village()
			model = restored
		else:
			# Never silently open a version-two village as a classic game.
			save_blocked = true
	kit.environment(self, "bauwelt_day")
	NEXTGEN_ENV.apply_day(self)
	_build_landscape()
	camera = Camera3D.new()
	camera.fov = 51
	camera.far = 180
	add_child(camera)
	camera.current = true
	explorer = EXPLORER.new()
	explorer.horizontal_limit = Vector2(196, 95) if model.living_village else Vector2(31, 18)
	add_child(explorer)
	_build_ui()
	_rebuild()
	_camera_update(true)
	get_viewport().size_changed.connect(_layout)
	_layout()
	print("[SettlementWorld] ready mode=", mode, " save=", save_path)


func _exit_tree() -> void:
	get_viewport().gui_embed_subwindows = bool(previous.get("embed_subwindows", false))
	RUNTIME.restore(self, previous)


static func restore_project(
	raw: Variant, expected_child: String, expected_slot: int, expected_mode: String
):
	if not raw is Dictionary or raw.get("version") != 1:
		return null
	if (
		raw.get("child") != expected_child
		or raw.get("mode") != expected_mode
		or raw.get("slot") != expected_slot
	):
		return null
	if not raw.get("settlement") is Dictionary:
		return null
	var restored = STATE.restore(raw.settlement)
	return restored if restored != null and restored.mode == expected_mode else null


static func project_path(owner: String, project_slot: int, variation: String) -> String:
	# Keep the exact owner in the envelope, hash only the filename. Replacing
	# punctuation or truncating identities can merge two different children.
	return "user://lumo_settlement_%s_%d_%s.json" % [owner.sha256_text(), project_slot, variation]


static func plot_coordinate(index: int) -> Vector2i:
	if index < 9:
		return Vector2i(index % 3 - 1, index / 3 - 1)
	if index < 13:
		return Vector2i(2, index - 10)
	if index < 16:
		return Vector2i(index - 14, 2)
	if index < 21:
		return Vector2i(-2, index - 18)
	return Vector2i(index - 22, -2)


static func plot_position(index: int, opponent := false) -> Vector3:
	var coord := plot_coordinate(index)
	return Vector3((16.0 if opponent else -16.0) + coord.x * SPACING, 0.03, coord.y * SPACING)


func _plot_world(index: int, opponent := false) -> Vector3:
	return (
		REGION.plot_position(index, opponent) if model.living_village else plot_position(index, opponent)
	)


func _build_landscape() -> void:
	if model.living_village:
		village_region = REGION.new()
		add_child(village_region)
		village_region.build_landscape(mode)
		village_residents = RESIDENTS.new()
		add_child(village_residents)
		village_residents.configure()
		return
	for x in [-16.0, 16.0]:
		var bank := StaticBody3D.new()
		add_child(bank)
		var bank_mesh := kit.box(bank, Vector3(x, -0.55, 0), Vector3(28, 1.1, 34), Color("92b96f"))
		bank_mesh.material_override = NEXTGEN_ENV.bank_material()
		var grass := kit.box(bank, Vector3(x, 0.008, 0), Vector3(28, 0.015, 34), Color("b4be8b"))
		grass.material_override = NEXTGEN_ENV.ground_material()
		kit.collision(bank, Vector3(x, -0.55, 0), Vector3(28, 1.1, 34))
		for z in [-17.2, 17.2]:
			kit.box(self, Vector3(x, -0.8, z), Vector3(29, 1.9, 0.8), Color("ba9b70"))
		for tree_index in range(8):
			var tree := Node3D.new()
			add_child(tree)
			tree.position = Vector3(
				x - 12 + (tree_index % 4) * 8, 0, -15.6 if tree_index < 4 else 15.6
			)
			BuildLandmarks.add_branched_tree(tree)
	var water := kit.box(self, Vector3(0, -0.32, 0), Vector3(4, 0.18, 40), Color("267fa9"))
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://assets/shaders/kart_water.gdshader")
	water.material_override = water_material
	var bridge := StaticBody3D.new()
	add_child(bridge)
	kit.box(bridge, Vector3(0, 0.12, 13.8), Vector3(5.5, 0.25, 2.0), Color("d6bb8a"))
	kit.collision(bridge, Vector3(0, 0.12, 13.8), Vector3(5.5, 0.25, 2.0))
	for z in [12.9, 14.7]:
		kit.box(bridge, Vector3(0, 0.75, z), Vector3(5.5, 0.12, 0.12), Color("9a6739"))
	var town_title := Label3D.new()
	town_title.text = "DEINE SIEDLUNG"
	town_title.position = Vector3(-16, 1.4, -15.4)
	town_title.font_size = 64
	town_title.pixel_size = 0.014
	town_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	town_title.modulate = Color("fff4d9")
	town_title.outline_modulate = Color("183f46")
	add_child(town_title)
	var rival_title := town_title.duplicate() as Label3D
	rival_title.position.x = 16
	rival_title.text = "NACHBARIN MIRA" if mode == "rival" else "DEINE NÄCHSTE IDEE"
	add_child(rival_title)
	if mode == "rival":
		rival_host = preload("res://scripts/games/kart_vehicle.gd").new()
		add_child(rival_host)
		rival_host.configure_companion("raccoon")
		rival_host.position = rival_destination
		rival_host.scale = Vector3.ONE * 1.1


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	top_backdrop = Panel.new()
	top_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_backdrop.add_theme_stylebox_override("panel", _panel())
	safe_ui.add_child(top_backdrop)
	top = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 10
	top.minimum_size_changed.connect(func(): call_deferred("_layout"))
	safe_ui.add_child(top)
	var heading := HBoxContainer.new()
	top.add_child(heading)
	heading.add_child(_button("‹ Bauwelt", _leave, 96))
	var title := _label(
		"LUMO WETTBAU" if mode == "rival" else ("LUMO DORFWELT" if model.living_village else "LUMO SIEDLUNG"), 22
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	heading.add_child(title)
	walk_button = _button("Lumo", _toggle_walk, 70)
	heading.add_child(walk_button)
	heading.add_child(_button("Ⅱ", _toggle_pause, 48))
	resource_label = _label("", 16)
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(resource_label)
	goal_label = _label("", 15)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(goal_label)
	rival_label = _label("", 14)
	rival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(rival_label)
	bottom_backdrop = Panel.new()
	bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_backdrop.add_theme_stylebox_override("panel", _panel())
	safe_ui.add_child(bottom_backdrop)
	bottom = VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.minimum_size_changed.connect(func(): call_deferred("_layout"))
	safe_ui.add_child(bottom)
	plot_label = _label("Wähle ein freies Grundstück und ein Gebäude.", 15)
	plot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(plot_label)
	var buildings_scroll := ScrollContainer.new()
	buildings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(buildings_scroll)
	var buildings := HBoxContainer.new()
	buildings_scroll.add_child(buildings)
	var kinds: Array = STATE.BUILDINGS.keys() if model.living_village else STATE.CLASSIC_KINDS
	for kind in kinds:
		var spec: Dictionary = STATE.BUILDINGS[kind]
		var button := _button(str(spec.title) + "\n" + _cost_text(model.building_cost(kind)), _buy.bind(kind), 168)
		button.custom_minimum_size.y = 66
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		buildings.add_child(button)
		purchase_buttons[kind] = button
	var row := HBoxContainer.new()
	bottom.add_child(row)
	var actions_scroll := ScrollContainer.new()
	actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(actions_scroll)
	var actions := HBoxContainer.new()
	actions_scroll.add_child(actions)
	var actions_data: Array = [
		["Rückgängig", _undo],
		["Wiederholen", _redo],
		["Handeln", _trade_dialog],
		["Nachbar ansehen" if mode == "rival" else "Überblick", _look_neighbor]
	]
	if model.living_village:
		actions_data.append_array([
			["Kapitel", _chapter_dialog],
			["Tilda · Lieferung", _tilda_dialog],
			["Stadtkasse", _public_project_dialog],
			["←", _pan_village.bind(-1, 0)],
			["→", _pan_village.bind(1, 0)],
			["↑", _pan_village.bind(0, -1)],
			["↓", _pan_village.bind(0, 1)],
			["Zoom +", _zoom_village.bind(-1)],
			["Zoom −", _zoom_village.bind(1)]
		])
	for spec in actions_data:
		var button := _button(spec[0], spec[1], 110)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		actions.add_child(button)
		transaction_buttons.append(button)
	demolish_button = _button("Rückbauen", _demolish, 112)
	demolish_button.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_child(demolish_button)
	expand_button = _button("Erweitern", _expand, 112)
	expand_button.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_child(expand_button)
	day_button = _button("Nächster Tag ☀", _day_action, 148)
	row.add_child(day_button)
	feedback = _label(
		"Dein Plan zählt: Nahrung, Material und Wohnraum halten die Siedlung am Leben.", 14
	)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(feedback)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _panel())
	pause_panel.custom_minimum_size = Vector2(300, 0)
	pause_panel.hide()
	safe_ui.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_panel.add_child(pause_box)
	pause_box.add_child(_label("Deine Siedlung wartet", 22))
	pause_box.add_child(_button("Weiter", _toggle_pause))
	pause_box.add_child(_button("Speichern", _save_message))
	pause_box.add_child(_button("Zur Bauwelt", _leave))
	walk_controls = Control.new()
	walk_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	walk_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	walk_controls.hide()
	safe_ui.add_child(walk_controls)
	walk_stick = STICK.new()
	walk_controls.add_child(walk_stick)
	jump_button = JUMP.new()
	jump_button.hold_changed.connect(func(held: bool): explorer.hold_jump(held))
	walk_controls.add_child(jump_button)


func _label(text: String, size := 17) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("173546"))
	label.add_theme_color_override("font_shadow_color", Color("fff9e9"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.85, 0.96)
	style.border_color = Color("438f96")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style


func _button(text: String, action: Callable, width := 100) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 48)
	button.add_theme_font_size_override("font_size", 15)
	for state in ["", "hover_", "pressed_", "hover_pressed_", "focus_"]:
		button.add_theme_color_override("font_" + state + "color", Color("183d4c"))
	button.add_theme_stylebox_override("normal", _panel())
	var pressed := _panel()
	pressed.bg_color = Color("bddfc7")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	var disabled := _panel()
	disabled.bg_color = Color("dce5dc")
	disabled.border_color = Color("9cab9f")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", Color("45616a"))
	button.pressed.connect(action)
	return button


func _cost_text(cost: Dictionary) -> String:
	var labels := {"wood": "Holz", "stone": "Stein", "food": "Essen", "coins": "Münzen", "grain": "Korn"}
	var parts := PackedStringArray()
	for resource in ["wood", "stone", "food", "coins", "grain"]:
		if int(cost.get(resource, 0)) > 0:
			parts.append("%d %s" % [int(cost[resource]), labels[resource]])
	return ", ".join(parts)


func _layout() -> void:
	if not is_inside_tree():
		return
	RUNTIME.safe_area(self, safe_ui)
	var size := safe_ui.size
	bottom.offset_top = -maxf(176, bottom.get_combined_minimum_size().y + 10)
	var short := size.y < 560
	rival_label.visible = mode == "rival" and not short
	var goal_size := 13 if short else 15
	if goal_label.get_theme_font_size("font_size") != goal_size:
		goal_label.add_theme_font_size_override("font_size", goal_size)
	top_backdrop.position = top.position - Vector2(8, 6)
	top_backdrop.size = top.size + Vector2(16, 12)
	bottom_backdrop.position = bottom.position - Vector2(8, 6)
	bottom_backdrop.size = bottom.size + Vector2(16, 12)
	bottom_backdrop.visible = bottom.visible
	pause_panel.position = (size - pause_panel.size) * 0.5
	var stick_size := clampf(minf(size.x * 0.29, size.y * 0.37), 112, 168)
	walk_stick.custom_minimum_size = Vector2.ONE * stick_size
	walk_stick.size = Vector2.ONE * stick_size
	walk_stick.position = Vector2(16, size.y - stick_size - 16)
	jump_button.size = Vector2.ONE * 112
	jump_button.position = Vector2(size.x - 128, size.y - 128)
	_layout_village_dialog()
	if not walking:
		_camera_update(true)


func _rebuild() -> void:
	var active_plots: Dictionary = {}
	var active_facilities: Dictionary = {}
	for opponent in [false, true]:
		if opponent and mode != "rival":
			continue
		var town: Dictionary = model.rival() if opponent else model.player()
		for index in range(int(town.plots)):
			var where := _plot_world(index, opponent)
			# Only load touch colliders around the view; the 1089-plot model stays persistent.
			if model.living_village and where.distance_squared_to(focus) > 75.0 * 75.0:
				continue
			var key := "%s_%d" % ["r" if opponent else "p", index]
			active_plots[key] = true
			if not plot_nodes.has(key):
				var body := StaticBody3D.new()
				body.name = "Plot_" + key
				body.position = where
				body.set_meta("plot", index)
				body.set_meta("opponent", opponent)
				add_child(body)
				var plot_mesh := kit.box(
					body,
					Vector3(0, 0, 0),
					Vector3(4.65, 0.06, 4.65),
					Color("b6bc86") if opponent else Color("bad39c")
				)
				plot_mesh.material_override = NEXTGEN_ENV.plot_material(opponent)
				kit.collision(body, Vector3(0, -0.01, 0), Vector3(4.65, 0.08, 4.65))
				plot_nodes[key] = body
		for building in town.buildings:
			var key := "%s_%s" % ["r" if opponent else "p", str(building.id)]
			active_facilities[key] = true
			if facility_nodes.has(key):
				continue
			var node: StaticBody3D = VISUAL.create(str(building.kind), opponent)
			node.position = _plot_world(int(building.plot), opponent) + Vector3.UP * 0.06
			node.set_meta("plot", int(building.plot))
			add_child(node)
			facility_nodes[key] = node
		if opponent and town.buildings.size() > rival_last_buildings:
			var latest: Dictionary = town.buildings[-1]
			rival_destination = _plot_world(int(latest.plot), true) + Vector3(0, 0.08, 2.1)
			rival_last_buildings = town.buildings.size()
	for key in plot_nodes.keys():
		if not active_plots.has(key):
			plot_nodes[key].queue_free()
			plot_nodes.erase(key)
	for key in facility_nodes.keys():
		if not active_facilities.has(key):
			facility_nodes[key].queue_free()
			facility_nodes.erase(key)
	if not is_instance_valid(selection_marker):
		selection_marker = kit.box(self, Vector3.ZERO, Vector3(4.7, 0.04, 4.7), Color("e4cc62"))
		selection_marker.material_override = kit.material(Color("ffe18c"), true, true)
		selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection_marker.visible = selected_plot >= 0
	if selected_plot >= 0:
		selection_marker.position = _plot_world(selected_plot) + Vector3.UP * 0.12
	if is_instance_valid(village_residents):
		village_residents.sync(model.player())
		village_residents.set_focus(focus)
	_refresh_labels()


func _refresh_labels() -> void:
	var town: Dictionary = model.player()
	var resources: Dictionary = town.resources
	var summary: Dictionary = model.status()
	resource_label.text = (
		"Holz %d · Stein %d · Essen %d · Münzen %d\nBewohner %d · Grundstücke %d · Tag %d"
		% [
			int(resources.wood),
			int(resources.stone),
			int(resources.food),
			int(resources.coins),
			int(town.population),
			int(town.plots),
			int(model.day)
		]
	)
	var goals := PackedStringArray()
	for objective in summary.get("goals", []):
		goals.append(
			"%s %d/%d" % [str(objective.title), int(objective.current), int(objective.target)]
		)
	goal_label.text = (
		"%s · Stufe %d: %s"
		% [str(summary.world), mini(3, int(summary.level) + 1), " · ".join(goals)]
	)
	if model.living_village:
		var chapter: Dictionary = model.campaign_status()
		var next_steps := PackedStringArray()
		for goal in chapter.goals:
			next_steps.append("%s %d/%d" % [str(goal.title), int(goal.current), int(goal.target)])
		goal_label.text = (
			"Kapitel %d/%d · %s\n%s"
			% [int(chapter.chapter), int(chapter.total), str(chapter.title), " · ".join(next_steps)]
		)
		var economy: Dictionary = model.economy_status()
		resource_label.text += (
			"\nStadtkasse %d · Zufriedenheit %d%% · Wasser für %d"
			% [int(economy.treasury), int(economy.happiness), int(economy.water_capacity)]
		)
	if mode == "rival":
		var rival: Dictionary = model.rival()
		rival_label.text = (
			"Mira: %d Bewohner · %d Gebäude. Gleiche Preise und Erträge für euch beide."
			% [int(rival.population), rival.buildings.size()]
		)
	plot_label.text = (
		"Grundstück %d gewählt · Gebäude antippen zum Bauen" % (selected_plot + 1)
		if selected_plot >= 0
		else "Wähle ein Grundstück in deiner Siedlung."
	)
	var occupied := false
	for building in town.buildings:
		if int(building.plot) == selected_plot:
			occupied = true
			plot_label.text = (
				"Grundstück %d · %s. Rückbauen gibt die Baukosten zurück."
				% [selected_plot + 1, str(STATE.BUILDINGS[str(building.kind)].title)]
			)
	var blocked := _transactions_blocked()
	for kind in purchase_buttons:
		purchase_buttons[kind].disabled = blocked or selected_plot < 0 or occupied
		purchase_buttons[kind].text = (
			str(STATE.BUILDINGS[str(kind)].title) + "\n" + _cost_text(model.building_cost(str(kind)))
		)
	var completed: bool = mode == "rival" and not model.winner.is_empty()
	day_button.text = (
		("Zur Bauwelt" if round_slots_full else "Neue Runde") if completed else "Nächster Tag ☀"
	)
	day_button.disabled = paused or walking or save_blocked
	demolish_button.disabled = blocked or not occupied
	expand_button.disabled = blocked or not bool(summary.can_expand)
	transaction_buttons[0].disabled = blocked or not bool(summary.can_undo)
	transaction_buttons[1].disabled = blocked or not bool(summary.can_redo)
	transaction_buttons[2].disabled = blocked
	if save_blocked:
		feedback.text = "Dieser Spielstand ist nicht lesbar. Er bleibt unverändert. Wähle in der Bauwelt ein anderes Projekt."
	var winner := str(summary.get("winner", ""))
	if not winner.is_empty():
		feedback.text = _winner_text(winner)
	call_deferred("_layout")


func _transactions_blocked() -> bool:
	return paused or walking or save_blocked or (mode == "rival" and not model.winner.is_empty())


func _winner_text(winner: String) -> String:
	return (
		{
			"player": "Deine Stadt hat das Ziel zuerst erreicht!",
			"rival": "Mira hat das Ziel zuerst erreicht. Dein Bauplan ist erhalten.",
			"tie": "Ihr habt das Ziel gemeinsam erreicht!"
		}
		. get(winner, "Wettbau abgeschlossen.")
	)


func _buy(kind: String) -> void:
	if _transactions_blocked():
		return
	selected_kind = kind
	if not model.try_build(kind, selected_plot):
		feedback.text = model.last_error
		return
	selected_plot = -1
	_rebuild()
	feedback.text = (
		str(STATE.BUILDINGS[kind].title)
		+ " gebaut. Am nächsten Tag arbeitet deine Siedlung weiter."
	)
	_save()


func _next_day() -> void:
	if _transactions_blocked():
		return
	var report: Dictionary = model.next_day()
	_rebuild()
	if bool(report.get("advanced", false)):
		var own: Dictionary = report.player
		feedback.text = (
			"Tag %d: %s erhalten · %d Essen gebraucht%s"
			% [
				int(report.day),
				_cost_text(own.produced),
				int(own.food_needed),
				" · neue Bewohner!" if bool(own.grew) else ""
			]
		)
		if int(own.food_shortfall) > 0:
			feedback.text += " · Es fehlen %d Essen. Baue Bauernhöfe!" % int(own.food_shortfall)
		if not str(report.get("winner", "")).is_empty():
			feedback.text = _winner_text(str(report.winner))
	else:
		feedback.text = str(report.get("message", model.last_error))
	_save()


func _day_action() -> void:
	if mode == "rival" and not model.winner.is_empty():
		if round_slots_full:
			_leave()
		else:
			_new_round()
	else:
		_next_day()


func _new_round() -> void:
	if paused or walking or save_blocked or mode != "rival" or model.winner.is_empty():
		return
	if not _save():
		return
	# Project slots are the existing 1..6 slots. Preserve every previous round;
	# selecting a new one may never silently erase a completed town.
	for offset in range(6):
		var candidate := (slot + offset) % 6 + 1
		if FileAccess.file_exists(project_path(child_key, candidate, mode)):
			continue
		SceneRouter.launch_options["childKey"] = child_key
		SceneRouter.launch_options["buildSlot"] = candidate
		SceneRouter.launch_options["settlementMode"] = mode
		SceneRouter.goto("settlement")
		return
	round_slots_full = true
	day_button.text = "Zur Bauwelt"
	feedback.text = "Alle sechs Wettbau-Projekte sind belegt. Deine Runden bleiben erhalten. Zur Bauwelt → Welten (6) öffnet die Projektwahl."


func _undo() -> void:
	if _transactions_blocked():
		return
	if model.undo():
		_rebuild()
		_save()
		feedback.text = "Bau und Rohstoffe gemeinsam rückgängig gemacht."
	else:
		feedback.text = model.last_error


func _redo() -> void:
	if _transactions_blocked():
		return
	if model.redo():
		_rebuild()
		_save()
		feedback.text = "Bau und Rohstoffe gemeinsam wiederhergestellt."
	else:
		feedback.text = model.last_error


func _expand() -> void:
	if _transactions_blocked():
		return
	if model.expand():
		_rebuild()
		_save()
		feedback.text = "Deine Welt wächst: neue Grundstücke und neue Ziele warten auf dich."
	else:
		feedback.text = model.last_error


func _demolish() -> void:
	if _transactions_blocked() or is_instance_valid(demolition_window):
		return
	if model.try_demolish(selected_plot):
		_demolition_finished()
	else:
		feedback.text = model.last_error
		var quote: Dictionary = model.demolition_quote(selected_plot)
		if int(quote.get("affected_residents", 0)) > 0:
			_demolition_dialog(selected_plot, quote)


func _demolition_finished() -> void:
	_rebuild()
	_save()
	feedback.text = "Gebäude zurückgebaut. Die Baukosten sind wieder im Vorrat. Rückgängig stellt Gebäude und Bewohner wieder her."


func _demolition_dialog(plot: int, quote: Dictionary) -> void:
	var before: Dictionary = model.snapshot()
	var dialog := Window.new()
	demolition_window = dialog
	dialog.title = "Platz für Neues?"
	dialog.size = Vector2i(minf(420, safe_ui.size.x - 24), minf(390, safe_ui.size.y - 24))
	dialog.min_size = dialog.size
	dialog.borderless = true
	dialog.unresizable = true
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel())
	dialog.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_label("Platz für Neues?", 20))
	var explanation := _label("", 16)
	explanation.name = "RelocationExplanation"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var leaving := int(model.player().population) - int(quote.population_after)
	var residents := (
		(
			"%d Bewohner ziehen vorübergehend aus. %d bleiben in deiner Siedlung."
			% [leaving, int(quote.population_after)]
		)
		if leaving > 0
		else "Die zwei Gründer wohnen vorübergehend im Startlager."
	)
	if leaving == 1:
		residents = (
			"Ein Bewohner zieht vorübergehend aus. %d bleiben in deiner Siedlung."
			% int(quote.population_after)
		)
	explanation.text = (
		"Dieses Haus wird noch gebraucht.\n%s\n\nDu erhältst %s zurück. Neue Wohnhäuser lassen deine Siedlung wieder wachsen. Mit Rückgängig stellst du Haus und Bewohner wieder her."
		% [residents, _cost_text(quote.refund)]
	)
	box.add_child(explanation)
	box.add_child(_button("Haus behalten", dialog.queue_free))
	box.add_child(_button("Ja, umbauen", _confirm_demolition.bind(plot, before, dialog)))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()
	dialog.position = Vector2i(safe_ui.position + (safe_ui.size - Vector2(dialog.size)) * 0.5)


func _confirm_demolition(plot: int, before: Dictionary, dialog: Window) -> void:
	if _transactions_blocked() or dialog.is_queued_for_deletion():
		dialog.queue_free()
		return
	if model.snapshot() != before:
		feedback.text = "Dein Bauplan hat sich geändert. Wähle das Haus bitte erneut."
	elif model.try_demolish(plot, true):
		_demolition_finished()
	else:
		feedback.text = model.last_error
	dialog.queue_free()



func _village_dialog(title_text: String) -> Dictionary:
	if (
		_transactions_blocked()
		or not model.living_village
		or is_instance_valid(village_window)
		or is_instance_valid(trade_window)
		or is_instance_valid(demolition_window)
	):
		return {}
	var dialog := Window.new()
	village_window = dialog
	dialog.title = title_text
	dialog.borderless = true
	dialog.unresizable = true
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel())
	dialog.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_village_caption(body, title_text, 22)
	var close_button := _button("Schließen", dialog.queue_free)
	close_button.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(close_button)
	dialog.close_requested.connect(dialog.queue_free)
	_layout_village_dialog()
	dialog.popup_centered()
	_layout_village_dialog()
	return {"dialog": dialog, "body": body}


func _layout_village_dialog() -> void:
	if not is_instance_valid(village_window) or not is_instance_valid(safe_ui):
		return
	var available := safe_ui.size - Vector2(24, 24)
	var extent := Vector2i(maxi(1, mini(520, int(available.x))), maxi(1, mini(520, int(available.y))))
	# An open popup must be able to shrink when the host changes orientation
	# or display density. Keep its instance, contents and scroll state intact.
	village_window.min_size = Vector2i.ZERO
	village_window.size = extent
	village_window.min_size = extent
	village_window.position = Vector2i(safe_ui.position + (safe_ui.size - Vector2(extent)) * 0.5)


func _village_caption(body: VBoxContainer, caption: String, font_size := 16) -> void:
	var label := _label(caption, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)


func _chapter_dialog() -> void:
	var view: Dictionary = _village_dialog("Deine Dorfgeschichte")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var chapter: Dictionary = model.campaign_status()
	_village_caption(
		body, "Kapitel %d von %d: %s" % [int(chapter.chapter), int(chapter.total), str(chapter.title)], 19
	)
	_village_caption(body, "%s erzählt:" % str(chapter.friend))
	_village_caption(body, str(chapter.story))
	_village_caption(body, "Deine Aufgabe: " + str(chapter.task), 18)
	for goal in chapter.get("goals", []):
		_village_caption(
			body, "• %s: %d von %d" % [str(goal.title), int(goal.current), int(goal.target)]
		)
	_village_caption(body, "Lumos Tipp: " + str(chapter.hint))
	if bool(chapter.complete):
		_village_caption(body, "Du kannst dein Dorf weiterhin frei aufbauen.")


func _tilda_dialog() -> void:
	var view: Dictionary = _village_dialog("Tildas Lieferwagen")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var dialog: Window = view.dialog
	var trader: Dictionary = model.trader_offer()
	if not bool(trader.available):
		_village_caption(
			body, "Tilda kommt in %d Dorftagen wieder. Deine Vorräte bleiben erhalten."
			% int(trader.arrives_in)
		)
		return
	_village_caption(
		body, "Tilda ist da! Du kannst noch %d Lieferung(en) bestellen." % int(trader.orders_left)
	)
	for offer in trader.offers:
		var button := _button(
			"%s\n%s → %s"
			% [str(offer.title), _cost_text(offer.cost), _cost_text(offer.receive)],
			_order_village_delivery.bind(str(offer.id), dialog),
			260
		)
		button.custom_minimum_size.y = 68
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.disabled = int(trader.orders_left) <= 0
		body.add_child(button)


func _order_village_delivery(id: String, dialog: Window) -> void:
	if _transactions_blocked() or dialog.is_queued_for_deletion():
		return
	if model.order_delivery(id):
		_rebuild()
		_save()
		feedback.text = "Tilda bringt deine Lieferung am nächsten Dorftag. Die Münzen wurden abgezogen."
	else:
		feedback.text = model.last_error
	dialog.queue_free()


func _public_project_dialog() -> void:
	var view: Dictionary = _village_dialog("Unsere Stadtkasse")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var dialog: Window = view.dialog
	var treasury: int = int(model.economy_status().treasury)
	_village_caption(body, "In der gemeinsamen Stadtkasse: %d Münzen" % treasury, 19)
	_village_caption(body, "Von je zehn verdienten Münzen teilen die Familien zwei für das Dorf.")
	for project in model.public_projects():
		var name: String = str(project.title)
		var completed: bool = bool(project.completed)
		var button := _button(
			"%s · %s"
			% [name, "schon gebaut" if completed else "%d Münzen" % int(project.cost)],
			_fund_village_project.bind(str(project.id), dialog),
			265
		)
		button.custom_minimum_size.y = 52
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.disabled = completed or int(project.cost) > treasury
		body.add_child(button)
		_village_caption(body, str(project.description))


func _fund_village_project(id: String, dialog: Window) -> void:
	if _transactions_blocked() or dialog.is_queued_for_deletion():
		return
	if model.fund_project(id):
		_rebuild()
		_save()
		feedback.text = "Gemeinschaftsprojekt gebaut! Die Stadtkasse wurde richtig abgerechnet."
	else:
		feedback.text = model.last_error
	dialog.queue_free()


func _trade_dialog() -> void:
	if (
		_transactions_blocked()
		or is_instance_valid(trade_window)
		or is_instance_valid(demolition_window)
	):
		return
	var dialog := Window.new()
	trade_window = dialog
	dialog.title = "Handeln am Markt"
	dialog.size = Vector2i(minf(400, safe_ui.size.x - 24), minf(470, safe_ui.size.y - 24))
	dialog.min_size = dialog.size
	dialog.borderless = true
	dialog.unresizable = true
	dialog.transient = true
	dialog.exclusive = true
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel())
	dialog.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label("Rohstoffe sinnvoll tauschen", 18))
	for resource in ["wood", "stone", "food"]:
		for sell in [false, true]:
			var quote: Dictionary = STATE.trade_quote(resource, 5, sell)
			var caption := (
				_cost_text(quote.cost) + " → " + _cost_text({quote.resource: quote.amount})
			)
			box.add_child(_button(caption, _confirm_trade.bind(resource, sell, dialog)))
	box.add_child(_button("Zurück", dialog.queue_free))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()
	dialog.position = Vector2i(safe_ui.position + (safe_ui.size - Vector2(dialog.size)) * 0.5)


func _confirm_trade(resource: String, sell: bool, dialog: Window) -> void:
	if _transactions_blocked() or dialog.is_queued_for_deletion():
		dialog.queue_free()
		return
	if model.try_trade(resource, 5, sell):
		_rebuild()
		_save()
		feedback.text = "Handel abgeschlossen. Dein Vorrat wurde aktualisiert."
	else:
		feedback.text = model.last_error
	dialog.queue_free()


func _look_neighbor() -> void:
	if paused or walking or save_blocked:
		return
	var center := REGION.TOWN_CENTER if model.living_village else 16.0
	focus.x = center if focus.x < 0 else -center
	if model.living_village:
		_rebuild()
	_camera_update(true)


func _pan_village(dx: int, dz: int) -> void:
	if _transactions_blocked() or not model.living_village:
		return
	var side := 1.0 if focus.x >= 0 else -1.0
	var home := side * REGION.TOWN_CENTER
	focus.x = clampf(focus.x + float(dx) * REGION.SPACING * 4.0, home - 85.0, home + 85.0)
	focus.z = clampf(focus.z + float(dz) * REGION.SPACING * 4.0, -85.0, 85.0)
	selected_plot = -1
	_rebuild()
	_camera_update(true)


func _zoom_village(direction: int) -> void:
	if _transactions_blocked() or not model.living_village:
		return
	radius = clampf(radius + float(direction) * 8.0, 15.0, 94.0)
	_rebuild()
	_camera_update(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if pointer < 0:
		return
	var release: bool = (
		(event is InputEventScreenTouch and event.index == pointer and not event.pressed)
		or (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and pointer == 0
			and not event.pressed
		)
	)
	if not release:
		return
	# A world gesture owns its release even over HUD controls. Otherwise GUI
	# consumption leaves a stale finger ID and blocks the next plot selection.
	var canceled: bool = event is InputEventScreenTouch and event.canceled
	var pick: bool = (
		not paused
		and not walking
		and not dragged
		and not canceled
		and event.position.distance_to(tap_origin) <= 10
	)
	pointer = -1
	if pick:
		_pick_plot(event.position)
	get_viewport().set_input_as_handled()


func _world_gesture_starts_on_ui(point: Vector2) -> bool:
	for control in [top, bottom, pause_panel]:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, control.size).has_point(local):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if paused:
		return
	# Scroll children pass touch events to their container. A press on the HUD
	# must not also acquire a world gesture; existing world releases stay owned.
	if ((event is InputEventScreenTouch or event is InputEventMouseButton)
		and event.pressed and _world_gesture_starts_on_ui(event.position)):
		return
	if walking and event is InputEventKey and not event.echo and event.keycode == KEY_SPACE:
		explorer.hold_jump(event.pressed)
	if event is InputEventScreenTouch:
		if event.pressed and pointer < 0:
			pointer = event.index
			tap_origin = event.position
			dragged = false
		elif not event.pressed and pointer == event.index:
			if not dragged and not event.canceled and not walking:
				_pick_plot(event.position)
			pointer = -1
	elif event is InputEventScreenDrag and event.index == pointer:
		dragged = dragged or event.position.distance_to(tap_origin) > 10
		if dragged:
			orbit -= event.relative.x * 0.005
			tilt = clampf(tilt + event.relative.y * 0.004, 0.25, 1.1)
			_camera_update()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer = 0
			tap_origin = event.position
			dragged = false
		else:
			if pointer == 0 and not dragged and not walking:
				_pick_plot(event.position)
			pointer = -1
	elif event is InputEventMouseMotion and pointer == 0:
		dragged = dragged or event.position.distance_to(tap_origin) > 10
		if dragged:
			orbit -= event.relative.x * 0.005
			tilt = clampf(tilt + event.relative.y * 0.004, 0.25, 1.1)
			_camera_update()


func _pick_plot(point: Vector2) -> void:
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(point) * 180, 1
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("plot"):
		return
	if bool(hit.collider.get_meta("opponent", false)):
		feedback.text = "Miras Grundstück: Sie baut mit denselben Rohstoffregeln wie du."
		return
	selected_plot = int(hit.collider.get_meta("plot"))
	_rebuild()


func _camera_update(immediate := false) -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or walking:
		return
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var target_radius := maxf(radius, 20.0 / maxf(0.35, aspect))
	camera.position = (
		focus + Vector3(sin(orbit) * cos(tilt), sin(tilt), cos(orbit) * cos(tilt)) * target_radius
	)
	camera.look_at(focus)
	if is_instance_valid(village_region):
		village_region.update_focus(focus)
	if is_instance_valid(village_residents):
		village_residents.set_focus(focus)
	if immediate:
		camera.reset_physics_interpolation()


func _toggle_walk() -> void:
	if paused:
		return
	walking = not walking
	if walking:
		stored_camera = {"focus": focus, "orbit": orbit, "tilt": tilt}
		explorer.start_at(Vector3(-REGION.TOWN_CENTER, 0.08, 13.8) if model.living_village else Vector3(-16, 0.08, 13.8))
		tilt = 0.34
	else:
		explorer.set_active(false)
		focus = stored_camera.get("focus", Vector3(-REGION.TOWN_CENTER, 0, 0) if model.living_village else Vector3(-16, 0, 0))
		orbit = float(stored_camera.get("orbit", 0.28))
		tilt = float(stored_camera.get("tilt", 0.70))
		_camera_update(true)
	bottom.visible = not walking
	walk_controls.visible = walking
	walk_button.text = "Planen" if walking else "Lumo"
	walk_stick.set_enabled(walking)
	jump_button.set_enabled(walking)
	_refresh_labels()


func _physics_process(delta: float) -> void:
	if paused:
		return
	if walking:
		explorer.move_axis = walk_stick.target
		explorer.camera_yaw = orbit
		explorer.advance_motion(delta)
		var at := explorer.position + Vector3.UP
		var target := at + Vector3(sin(orbit) * cos(tilt), sin(tilt), cos(orbit) * cos(tilt)) * 8.2
		var query := PhysicsRayQueryParameters3D.create(at, target, 1, [explorer.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			target = hit.position + hit.normal * 0.2
		camera.position = camera.position.lerp(target, 1.0 - exp(-10 * delta))
		if camera.position.distance_squared_to(at) > 0.02:
			camera.look_at(at)
	if is_instance_valid(village_residents):
		village_residents.advance(delta)
	if is_instance_valid(rival_host):
		rival_host.position = rival_host.position.move_toward(rival_destination, 1.5 * delta)
		rival_host.set_companion_pose(Time.get_ticks_msec() / 1000.0, "happy")


func _toggle_pause() -> void:
	paused = not paused
	if paused and is_instance_valid(trade_window):
		trade_window.hide()
		trade_window.queue_free()
	if paused and is_instance_valid(demolition_window):
		demolition_window.hide()
		demolition_window.queue_free()
	if paused and is_instance_valid(village_window):
		village_window.hide()
		village_window.queue_free()
	pause_panel.visible = paused
	pointer = -1
	walk_stick.set_enabled(walking and not paused)
	jump_button.set_enabled(walking and not paused)
	if walking:
		explorer.set_active(not paused)
		explorer.visible = true
	_refresh_labels()
	if paused:
		_save()
	_layout()


func _notification(what: int) -> void:
	if (
		what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]
		and is_instance_valid(safe_ui)
	):
		if not paused:
			_toggle_pause()


func _save() -> bool:
	if save_blocked:
		return false
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		feedback.text = "Deine Siedlung konnte noch nicht gespeichert werden. Bitte erneut versuchen."
		return false
	file.store_string(
		JSON.stringify(
			{
				"version": 1,
				"child": child_key,
				"settlement": model.snapshot(),
				"mode": mode,
				"slot": slot
			}
		)
	)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		feedback.text = "Speichern fehlgeschlagen. Deine Siedlung bleibt geöffnet."
		return false
	return true


func _save_message() -> void:
	if _save():
		feedback.text = "Deine Siedlung ist gespeichert. Es vergeht kein Tag, solange du nicht weiterspielst."


func _leave() -> void:
	if save_blocked or _save():
		SceneRouter.goto("build")
