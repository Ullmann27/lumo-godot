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
const HUD = preload("res://scripts/creative/build_hud_style.gd")
const CAMPAIGN_MAP = preload("res://scripts/creative/build_campaign_map.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const ATMOSPHERE = preload("res://scripts/creative/build_village_atmosphere.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const LIFE = preload("res://scripts/creative/build_village_life.gd")
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const TUTORIAL = preload("res://scripts/creative/build_village_tutorial.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const NEIGHBORS_VIEW = preload("res://scripts/creative/build_village_neighbors_view.gd")
const RAIDS = preload("res://scripts/creative/build_village_raids.gd")
const RAIDS_VIEW = preload("res://scripts/creative/build_village_raids_view.gd")
const SPACING := 5.3
const MAX_DETAILED_FACILITIES := 96
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
var resource_chips: Dictionary = {}
var campaign_map: Control
var map_hidden_3d := false
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
var host_entry := false
var return_scene := "build"
var last_view_focus := Vector3.INF
var last_view_radius := -1.0
var overview_nodes: Array[MultiMeshInstance3D] = []
# Twelve real chapter milestones share one lightweight world landmark.
var beacon_progress: Array[MeshInstance3D] = []
var village_life: Node3D
var art_material: ShaderMaterial
var quality := "medium"
var time_of_day := 0.35
var day_cycle: Tween
var fresh_builds: Dictionary = {}
var spinning_parts: Array[Node3D] = []
var goal_card: PanelContainer
var progress_rows: Array[HBoxContainer] = []
var camera_cluster: VBoxContainer
var toast: PanelContainer
var dock_rows: Array[Control] = []
var actions_scroll_node: ScrollContainer
var primary_row: HBoxContainer
var evening_button: Button
var more_panel: PanelContainer
## Dorfwelt-Zusatzdaten im selben Speicher-Umschlag ("village_meta"): Tutorial,
## Nachbardörfer, Verteidigung, Kampagne. Alte Dateien ohne den Schlüssel laden
## mit Standardwerten; ältere Spielversionen ignorieren den Schlüssel.
var village_meta: Dictionary = {}
var tutorial: Control
var neighbors
var neighbors_view: Node3D
var more_button: Button
var raids
var raids_view: Node3D
var defense_button: Button
var raid_alert: Button
var raid_camera_return: Dictionary = {}


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
		if raw is Dictionary and raw.get("village_meta") is Dictionary:
			village_meta = raw.village_meta.duplicate(true)
		if restored != null and restored.living_village == village_requested:
			model = restored
		elif restored != null and village_requested and not restored.living_village:
			restored.enable_living_village()
			model = restored
		else:
			# Never silently open a version-two village as a classic game.
			save_blocked = true
	var host_launch: Dictionary = HostBridge.launch_options()
	host_entry = (
		HostBridge.is_embedded() and model.living_village
		and str(host_launch.get("scene", "")) == "settlement"
		and host_launch.get("livingVillage", false) == true
	)
	return_scene = "games" if host_entry else "build"
	kit.environment(self, "bauwelt_day")
	NEXTGEN_ENV.apply_day(self)
	quality = LumoQuality.tier()
	if model.living_village:
		# Strong reference: every village building shares this one material.
		art_material = ART.material()
		ATMOSPHERE.apply(self, quality)
		focus = _start_focus()
		orbit = START_VIEW.x
		tilt = START_VIEW.y
		radius = START_VIEW.z
	_build_landscape()
	camera = Camera3D.new()
	camera.fov = 51
	camera.far = {"low": 420.0, "medium": 620.0, "high": 900.0}.get(quality, 620.0) if model.living_village else 180.0
	add_child(camera)
	camera.current = true
	explorer = EXPLORER.new()
	explorer.horizontal_limit = Vector2(196, 95) if model.living_village else Vector2(31, 18)
	add_child(explorer)
	if model.living_village:
		_build_village_ui()
	else:
		_build_ui()
	_rebuild()
	_camera_update(true)
	if model.living_village:
		_start_village_systems()
	get_viewport().size_changed.connect(_layout)
	RUNTIME.watch_safe_area(self, _layout)
	_layout()
	print("[SettlementWorld] ready mode=", mode, " save=", save_path)
	if model.living_village and bool(SceneRouter.launch_options.get("openCampaignMap", false)):
		SceneRouter.launch_options.erase("openCampaignMap")
		open_campaign_map.call_deferred()
	if model.living_village and is_instance_valid(village_region) and is_instance_valid(village_residents):
		# Device acceptance consumes actual initialized state, after UI, plots
		# and residents exist. Requested launch options alone are not evidence.
		var town: Dictionary = model.player()
		print("[VillageHostReady] ", JSON.stringify({
			"scene": scene_file_path,
			"mode": mode,
			"living_village": model.living_village,
			"save_path": save_path,
			"slot": slot,
			"plots": int(town.plots),
			"population": int(town.population),
			"visible_residents": int(village_residents.get_meta("visible_residents", 0)),
			"initialized_plot_nodes": plot_nodes.size(),
			"save_blocked": save_blocked,
			"host_entry": host_entry,
			"return_scene": return_scene,
		}))


func _exit_tree() -> void:
	if map_hidden_3d:
		get_viewport().disable_3d = false
		map_hidden_3d = false
	RUNTIME.unwatch_safe_area(self)
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
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



# A tangible, low-poly chapter marker at the children's town entrance,
# outside all plots. It introduces no collider, commerce or gameplay shortcut.
func _build_village_story_beacon() -> void:
	var beacon := Node3D.new()
	beacon.name = "LumoVillageStoryBeacon"
	beacon.position = Vector3(-REGION.TOWN_CENTER, 0.03, -13.0)
	add_child(beacon)
	var base := kit.cylinder(beacon, Vector3(0, 0.22, 0), 2.6, 0.44, Color("29465f"))
	base.material_override = kit.material(Color("274b62"))
	kit.cylinder(beacon, Vector3(0, 0.49, 0), 2.24, 0.12, Color("f2cc71"))
	for side in [-1.95, 1.95]:
		var pillar := kit.cylinder(beacon, Vector3(side, 1.45, 0), 0.20, 2.7, Color("d1e8d7"))
		pillar.material_override = kit.material(Color("d1e8d7"))
		kit.sphere(beacon, Vector3(side, 2.91, 0), Vector3(0.63, 0.63, 0.63), Color("8df2e1"), true)
	kit.box(beacon, Vector3(0, 3.12, 0), Vector3(4.3, 0.28, 0.46), Color("a2dbe2"), true)
	kit.sphere(beacon, Vector3(0, 2.40, 0), Vector3(1.34, 1.54, 1.34), Color("fbd079"), true)
	var sign := Label3D.new()
	sign.name = "LumoStoryBeaconCaption"
	sign.text = "LUMOS DORFGESCHICHTE"
	sign.position = Vector3(0, 3.83, 0)
	sign.font_size = 42
	sign.pixel_size = 0.009
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff9e7")
	sign.outline_modulate = Color("16415b")
	beacon.add_child(sign)
	for number in range(12):
		var x := -2.15 + float(number) * 0.39
		var marker := kit.sphere(
			beacon, Vector3(x, 0.70, 1.49),
			Vector3(0.27, 0.27, 0.27), Color("5c8395")
		)
		marker.name = "ChapterMark_%02d" % (number + 1)
		beacon_progress.append(marker)
	_update_chapter_beacon()


func _update_chapter_beacon() -> void:
	if beacon_progress.is_empty() or not model.living_village:
		return
	var chapter: int = clampi(int(model.campaign_status().chapter), 1, 12)
	for number in range(beacon_progress.size()):
		if is_instance_valid(beacon_progress[number]):
			beacon_progress[number].material_override = kit.material(
				Color("ffdc83") if number < chapter else Color("537f94"), number < chapter
			)


func _build_landscape() -> void:
	if model.living_village:
		village_region = REGION.new()
		add_child(village_region)
		village_region.build_landscape(mode)
		_build_village_story_beacon()
		village_residents = RESIDENTS.new()
		add_child(village_residents)
		village_residents.configure()
		village_life = LIFE.new()
		add_child(village_life)
		village_life.configure(quality)
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
	top_backdrop.add_theme_stylebox_override("panel", _hud_panel())
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
	var back := _button("‹ Spiele" if host_entry else "‹ Bauwelt", _leave, 96)
	back.name = "SettlementReturn"
	heading.add_child(back)
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
	var chips_scroll := ScrollContainer.new()
	chips_scroll.name = "VillageResourceBar"
	chips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(chips_scroll)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips_scroll.add_child(chips)
	var chip_specs: Array = [
		["wood", "wood", Color("e6b27a")], ["stone", "stone", Color("b9c6cf")],
		["food", "food", Color("ff8f7a")], ["coins", "coin", Color("ffd25a")],
		["population", "people", Color("8fd3ff")], ["plots", "block", Color("b6ec8c")],
		["day", "day", Color("ffe08a")]
	]
	if model.living_village:
		chip_specs.append_array([
			["treasury", "treasury", Color("e0b070")], ["happiness", "heart", Color("ffb3c1")],
			["water", "water", Color("7fd6ff")]
		])
	for chip_spec in chip_specs:
		var chip := HUD.chip(chip_spec[1], chip_spec[2], "")
		chips.add_child(chip)
		resource_chips[chip_spec[0]] = chip
	goal_label = _label("", 15)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(goal_label)
	rival_label = _label("", 14)
	rival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(rival_label)
	for info_label in [title, goal_label, rival_label]:
		info_label.add_theme_color_override("font_color", Color("f6fcff"))
	bottom_backdrop = Panel.new()
	bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_backdrop.add_theme_stylebox_override("panel", _hud_panel())
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
	plot_label.add_theme_color_override("font_color", Color("f6fcff"))
	bottom.add_child(plot_label)
	# Child's two primary decisions stay visible above the horizontal catalog.
	# They must not be swallowed by a kinetic scroll gesture on phones.
	var primary := HBoxContainer.new()
	primary.name = "VillagePrimaryActions"
	primary.add_theme_constant_override("separation", 8)
	bottom.add_child(primary)
	if model.living_village:
		var chapter_action := _button("Kapitel", _chapter_dialog, 120)
		chapter_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chapter_action.mouse_filter = Control.MOUSE_FILTER_STOP
		primary.add_child(chapter_action)
		var map_action := _button("Karte", open_campaign_map, 110)
		map_action.name = "VillageCampaignMap"
		HUD.style_button(map_action, "teal", 15)
		map_action.mouse_filter = Control.MOUSE_FILTER_STOP
		primary.add_child(map_action)
	var find_action := _button("Freier Bauplatz", _focus_next_free_plot, 140)
	find_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	find_action.mouse_filter = Control.MOUSE_FILTER_STOP
	primary.add_child(find_action)
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
	# Put the children's next useful actions FIRST instead of hiding the
	# chapter behind trade and maintenance buttons in a long horizontal rail.
	var actions_data: Array = [
		["Rückgängig", _undo],
		["Wiederholen", _redo],
		["Handeln", _trade_dialog],
		["Nachbar ansehen" if mode == "rival" else "Überblick", _look_neighbor]
	]
	if model.living_village:
		actions_data.append_array([
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
	HUD.style_button(day_button, "primary", 15)
	row.add_child(day_button)
	feedback = _label(
		"Dein Plan zählt: Nahrung, Material und Wohnraum halten die Siedlung am Leben.", 14
	)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_color_override("font_color", Color("f6fcff"))
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
	pause_box.add_child(_button("Zur Spielewelt" if host_entry else "Zur Bauwelt", _leave))
	if host_entry:
		var build_return := _button("Zur Bauwelt", _leave.bind("build"))
		build_return.name = "SettlementBuildReturn"
		pause_box.add_child(build_return)
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
	return HUD.card()


# A calm, readable HUD over the actual 3D village; dialogs use the shared
# parchment card with the same touch geometry.
func _hud_panel() -> StyleBoxFlat:
	return HUD.bar()


func _button(text: String, action: Callable, width := 100) -> Button:
	var button := HUD.button(text, action, width)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _cost_text(cost: Dictionary) -> String:
	var labels := {"wood": "Holz", "stone": "Stein", "food": "Essen", "coins": "Münzen", "grain": "Korn"}
	var parts := PackedStringArray()
	for resource in ["wood", "stone", "food", "coins", "grain"]:
		if int(cost.get(resource, 0)) > 0:
			var label: String = labels[resource]
			if resource == "coins" and int(cost[resource]) == 1:
				label = "Münze"
			parts.append("%d %s" % [int(cost[resource]), label])
	return ", ".join(parts)


func _layout() -> void:
	if not is_inside_tree():
		return
	RUNTIME.safe_area(self, safe_ui)
	var size := safe_ui.size
	if model.living_village and is_instance_valid(goal_card):
		_layout_village_hud(size)
	bottom.offset_top = -maxf(0.0 if model.living_village else 176.0, bottom.get_combined_minimum_size().y + 10)
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
	if model.living_village and is_instance_valid(village_region):
		village_region.set_unlocked_plots(int(model.player().plots), false)
		if mode == "rival":
			village_region.set_unlocked_plots(int(model.rival().plots), true)
	_sync_visible_plots(true)
	if mode == "rival":
		var rival: Dictionary = model.rival()
		if rival.buildings.size() > rival_last_buildings:
			var latest: Dictionary = rival.buildings[-1]
			rival_destination = _plot_world(int(latest.plot), true) + Vector3(0, 0.08, 2.1)
			rival_last_buildings = rival.buildings.size()
	if not is_instance_valid(selection_marker):
		selection_marker = kit.box(self, Vector3.ZERO, Vector3(4.7, 0.04, 4.7), Color("e4cc62"))
		selection_marker.material_override = kit.material(Color("ffe18c"), true, true)
		selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection_marker.visible = selected_plot >= 0
	if selected_plot >= 0:
		selection_marker.position = _plot_world(selected_plot) + Vector3.UP * 0.12
	if is_instance_valid(village_residents):
		village_residents.sync(model.player())
		village_residents.set_focus(explorer.position if walking else focus)
	_refresh_labels()
	_update_chapter_beacon()


func _sync_visible_plots(force := false) -> void:
	var view_focus: Vector3 = explorer.position if walking else focus
	if (
		not force
		and view_focus.distance_squared_to(last_view_focus) < 64.0
		and absf(radius - last_view_radius) < 8.0
	):
		return
	last_view_focus = view_focus
	last_view_radius = radius
	var active_plots: Dictionary = {}
	for opponent in [false, true]:
		if opponent and mode != "rival":
			continue
		var town: Dictionary = model.rival() if opponent else model.player()
		for index in range(int(town.plots)):
			var where := _plot_world(index, opponent)
			# Only load touch colliders around the view; the 1089-plot model stays persistent.
			if model.living_village and where.distance_squared_to(view_focus) > 75.0 * 75.0:
				continue
			var key := "%s_%d" % ["r" if opponent else "p", index]
			if model.living_village and not model.plot_buildable(index, opponent):
				# Rock, slope or shore: no building site and nothing to tap.
				continue
			active_plots[key] = true
			if not plot_nodes.has(key):
				var body := StaticBody3D.new()
				body.name = "Plot_" + key
				body.position = where
				body.set_meta("plot", index)
				body.set_meta("opponent", opponent)
				add_child(body)
				if model.living_village:
					# The site is painted into the terrain; the collider reaches
					# above small bumps so a tap always lands on the plot.
					kit.collision(body, Vector3(0, -0.12, 0), Vector3(4.65, 0.5, 4.65))
				else:
					var plot_mesh := kit.box(
						body,
						Vector3(0, 0, 0),
						Vector3(4.65, 0.06, 4.65),
						Color("b6bc86") if opponent else Color("bad39c")
					)
					plot_mesh.material_override = NEXTGEN_ENV.plot_material(opponent)
					kit.collision(body, Vector3(0, -0.01, 0), Vector3(4.65, 0.08, 4.65))
				plot_nodes[key] = body
	for key in plot_nodes.keys():
		if not active_plots.has(key):
			plot_nodes[key].queue_free()
			plot_nodes.erase(key)
	_sync_facilities(view_focus)
	if is_instance_valid(village_region):
		village_region.update_focus(view_focus)
	if is_instance_valid(village_residents):
		village_residents.set_focus(view_focus)


func _sync_facilities(view_focus: Vector3) -> void:
	# Existing living-village batching: preserve every saved building while
	# loading detailed meshes and colliders only around the camera or explorer.
	var active: Dictionary = {}
	var silhouettes := {"homes": [], "fields": [], "services": [], "roofs": []}
	for opponent in [false, true]:
		if opponent and mode != "rival":
			continue
		var town: Dictionary = model.rival() if opponent else model.player()
		var ordered: Array = town.buildings.duplicate()
		if model.living_village:
			ordered.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return (
						_plot_world(int(a.plot), opponent).distance_squared_to(view_focus)
						< _plot_world(int(b.plot), opponent).distance_squared_to(view_focus)
					)
			)
		var detailed := 0
		for building: Dictionary in ordered:
			var at := _plot_world(int(building.plot), opponent)
			var key := "%s_%s" % ["r" if opponent else "p", str(building.id)]
			var near := at.distance_squared_to(view_focus) <= 55.0 * 55.0 or ordered.size() <= 25
			if not model.living_village or (detailed < MAX_DETAILED_FACILITIES and near):
				active[key] = true
				detailed += 1
				if not facility_nodes.has(key):
					var variant := posmod(int(building.plot) * 7 + (3 if opponent else 0), 3)
					var facility: StaticBody3D = VISUAL.create(str(building.kind), opponent, variant)
					facility.position = at + Vector3.UP * 0.06
					if model.living_village:
						# A slight, stable turn per plot keeps streets from looking stamped.
						facility.rotation.y = (float(posmod(int(building.plot) * 13, 5)) - 2.0) * 0.035
					facility.set_meta("plot", int(building.plot))
					facility.set_meta("opponent", opponent)
					add_child(facility)
					facility_nodes[key] = facility
					if fresh_builds.has(key):
						fresh_builds.erase(key)
						VISUAL.animate_construction(facility)
			else:
				var field := str(building.kind) in ["farm", "grain", "road"]
				var group := "fields" if field else ("homes" if str(building.kind) == "house" else "services")
				var height := 0.22 if field else 2.1
				silhouettes[group].append(
					Transform3D(
						Basis.from_scale(Vector3(3.35, height, 3.35)),
						at + Vector3.UP * (height * 0.5 + 0.06)
					)
				)
				if not field:
					silhouettes.roofs.append(
						Transform3D(
							Basis.from_scale(Vector3(3.8, 1.3 if model.living_village else 0.44, 3.8)),
							at + Vector3.UP * (height + (0.7 if model.living_village else 0.25))
						)
					)
	for key in facility_nodes.keys():
		if not active.has(key):
			facility_nodes[key].queue_free()
			facility_nodes.erase(key)
	_collect_living_details()
	for previous_node in overview_nodes:
		remove_child(previous_node)
		previous_node.queue_free()
	overview_nodes.clear()
	var colors := {
		"homes": Color("eed8a6"), "fields": Color("89ae63"),
		"services": Color("80b7b1"), "roofs": Color("b96c50")
	}
	if model.living_village:
		colors = {
			"homes": Color("e9dcc2"), "fields": Color("c7b06a"),
			"services": Color("d8cdb8"), "roofs": Color("b4573c")
		}
	for group: String in silhouettes:
		var transforms: Array = silhouettes[group]
		if transforms.is_empty():
			continue
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		var cube: PrimitiveMesh = BoxMesh.new()
		if group == "roofs" and model.living_village:
			cube = PrismMesh.new()
		cube.size = Vector3.ONE
		batch.mesh = cube
		batch.instance_count = transforms.size()
		for index in range(transforms.size()):
			batch.set_instance_transform(index, transforms[index])
		var proxy := MultiMeshInstance3D.new()
		proxy.name = "VillageMap_" + group
		proxy.multimesh = batch
		proxy.material_override = kit.material(colors[group])
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(proxy)
		overview_nodes.append(proxy)
	set_meta("detailed_facilities", facility_nodes.size())
	set_meta("map_batches", overview_nodes.size())


func _refresh_labels() -> void:
	var town: Dictionary = model.player()
	var resources: Dictionary = town.resources
	var summary: Dictionary = model.status()
	HUD.set_chip(resource_chips.wood, str(int(resources.wood)), "Holz")
	HUD.set_chip(resource_chips.stone, str(int(resources.stone)), "Stein")
	HUD.set_chip(resource_chips.food, str(int(resources.food)), "Essen")
	HUD.set_chip(resource_chips.coins, str(int(resources.coins)), "Münzen")
	HUD.set_chip(resource_chips.population, str(int(town.population)), "Bewohner")
	HUD.set_chip(resource_chips.plots, str(int(town.plots)), "Grundstücke")
	HUD.set_chip(resource_chips.day, "Tag %d" % int(model.day), "Dorftag")
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
		# The real story goal is always visible. Full story and hints remain
		# accessible through the FIRST action button, not a hidden submenu.
		var compact_hud := is_instance_valid(safe_ui) and safe_ui.size.y < 600.0
		goal_label.text = (
			"Kapitel %d/%d · %s\nLumos Auftrag: %s"
			% [int(chapter.chapter), int(chapter.total),
				str(chapter.title), str(chapter.task)]
		)
		if not compact_hud and progress_rows.is_empty():
			goal_label.text += "\nFortschritt: " + " · ".join(next_steps)
		for index in range(progress_rows.size()):
			var row: HBoxContainer = progress_rows[index]
			row.visible = index < chapter.goals.size()
			if row.visible:
				var goal: Dictionary = chapter.goals[index]
				VHUD.set_progress(row, str(goal.title), int(goal.current), int(goal.target))
		var economy: Dictionary = model.economy_status()
		HUD.set_chip(resource_chips.treasury, str(int(economy.treasury)), "Stadtkasse")
		HUD.set_chip(resource_chips.happiness, "%d%%" % int(economy.happiness), "Zufriedenheit")
		HUD.set_chip(
			resource_chips.water, str(int(economy.water_capacity)), "Wasser für so viele Bewohner"
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
		else "Tippe einen freien Bauplatz oder „Freier Bauplatz“. "
			+ "Dein Dorf hat %d Grundstücke – sechs sind nur die Speicherplätze." % int(town.plots)
	)
	if model.living_village and selected_plot < 0:
		plot_label.text = "Bauplatz antippen oder gleich ein Gebäude wählen."
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
		if model.living_village:
			# Cards stay lit while affordable; without a chosen site the next
			# free meadow plot is used (camera flies there, scaffold rises).
			purchase_buttons[kind].disabled = (
				blocked or occupied or not model._affords(town, model.building_cost(str(kind)))
			)
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
	if model.living_village and selected_plot < 0:
		var free := _next_free_plot()
		if free >= 0:
			selected_plot = free
			focus = _plot_world(free)
			_camera_update(true)
	selected_kind = kind
	if not model.try_build(kind, selected_plot):
		feedback.text = model.last_error
		return
	var built: Array = model.player().buildings
	if not built.is_empty():
		fresh_builds["p_" + str(built[-1].id)] = true
	selected_plot = -1
	_rebuild()
	feedback.text = (
		str(STATE.BUILDINGS[kind].title)
		+ " gebaut. Am nächsten Tag arbeitet deine Siedlung weiter."
	)
	_save()



# Keyboard/touch-accessible plot finding. This changes only camera and
# selection, never a save, a purchase, a day or a child's resources.
func _next_free_plot() -> int:
	var town: Dictionary = model.player()
	var used: Dictionary = {}
	for building in town.buildings:
		used[int(building.plot)] = true
	for candidate in range(int(town.plots)):
		if not used.has(candidate) and model.plot_buildable(candidate):
			return candidate
	return -1


func _focus_next_free_plot() -> void:
	if _transactions_blocked():
		return
	var town: Dictionary = model.player()
	var used: Dictionary = {}
	for building in town.buildings:
		used[int(building.plot)] = true
	var count: int = int(town.plots)
	for offset in range(count):
		var candidate: int = (selected_plot + 1 + offset) % count
		if used.has(candidate) or not model.plot_buildable(candidate):
			continue
		selected_plot = candidate
		focus = _plot_world(candidate)
		_rebuild()
		_camera_update(true)
		feedback.text = (
			"Freier Bauplatz %d von %d. Wähle unten ein Gebäude. "
			+ "Dein Dorf wird erst gebaut, wenn du es bestätigst."
		) % [candidate + 1, count]
		return
	feedback.text = (
		"Alle %d Bauplätze sind belegt. Erweitern zeigt dir den nächsten "
		+ "Schritt. Rückbauen verändert erst nach deiner Bestätigung etwas."
	) % count


func _next_day() -> void:
	if _transactions_blocked():
		return
	var report: Dictionary = model.next_day()
	var neighbor_note := ""
	if bool(report.get("advanced", false)) and neighbors != null:
		neighbor_note = _advance_neighbors()
	var raid_report: Dictionary = {}
	if bool(report.get("advanced", false)) and raids != null:
		raid_report = raids.advance_day(model, neighbors, int(model._player.get("campaign_chapter", 0)), not is_instance_valid(tutorial) or not tutorial.active())
	_rebuild()
	if bool(report.get("advanced", false)):
		_play_day_cycle()
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
		if not neighbor_note.is_empty():
			feedback.text += " · " + neighbor_note
		if not str(report.get("winner", "")).is_empty():
			feedback.text = _winner_text(str(report.winner))
		_handle_raid_report(raid_report)
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


## Opens the 3D chapter map over the village. The village's own 3D view is
## paused meanwhile so only the diorama is rendered.
func open_campaign_map() -> void:
	if not model.living_village or is_instance_valid(campaign_map) or _transactions_blocked():
		return
	if is_instance_valid(village_window) or is_instance_valid(trade_window):
		return
	campaign_map = CAMPAIGN_MAP.new()
	campaign_map.setup(model.campaign_overview(), LumoQuality.tier())
	campaign_map.enter_requested.connect(_enter_campaign_chapter)
	campaign_map.closed.connect(_campaign_map_closed)
	safe_ui.add_child(campaign_map)
	map_hidden_3d = not get_viewport().disable_3d
	get_viewport().disable_3d = true


func _campaign_map_closed() -> void:
	if map_hidden_3d and is_inside_tree():
		get_viewport().disable_3d = false
	map_hidden_3d = false


func _enter_campaign_chapter(_index: int) -> void:
	_focus_next_free_plot.call_deferred()
	_chapter_dialog.call_deferred()


func _tilda_dialog() -> void:
	_explain("tilda")
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
	_explain("stadtkasse")
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
	_explain("handel")
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
	if model.living_village and _village_release(event):
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


func _hud_rect(control: Control) -> Rect2:
	var xform := safe_ui.get_global_transform().affine_inverse() * control.get_global_transform()
	return Rect2(xform.origin, xform.basis_xform(control.size))


func _world_gesture_starts_on_ui(point: Vector2) -> bool:
	for control in [top, bottom, pause_panel, goal_card, camera_cluster, toast, more_panel]:
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
		if is_instance_valid(campaign_map):
			campaign_map.close_map()
			return
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
	if model.living_village and not walking:
		_village_gesture(event)
		return
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
	if not hit.is_empty() and model.living_village and not hit.collider.has_meta("plot"):
		# A tap on the slope or meadow between sites selects the cell under it.
		var side := 1.0 if float(hit.position.x) > 0.0 else -1.0
		var center := side * REGION.TOWN_CENTER
		var cell := Vector2i(
			roundi((float(hit.position.x) - center) / REGION.SPACING), roundi(float(hit.position.z) / REGION.SPACING)
		)
		var index := REGION.plot_index_at(cell)
		var opponent := side > 0.0
		var town: Dictionary = model.rival() if opponent else model.player()
		if index < 0 or index >= int(town.plots) or (opponent and mode != "rival"):
			return
		if not model.plot_buildable(index, opponent):
			feedback.text = "Hier ist Fels, Hang oder Ufer. Gebaut wird auf flacher Wiese."
			return
		hit = {"collider": plot_nodes.get("%s_%d" % ["r" if opponent else "p", index])}
		if hit.collider == null:
			return
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
	var look := focus
	if model.living_village:
		look.y = REGION.ground(focus.x, focus.z) + 0.6
	camera.position = (
		look + Vector3(sin(orbit) * cos(tilt), sin(tilt), cos(orbit) * cos(tilt)) * target_radius
	)
	if model.living_village:
		camera.position.y = maxf(camera.position.y, REGION.ground(camera.position.x, camera.position.z) + 3.0)
	camera.look_at(look)
	if is_instance_valid(village_region):
		village_region.update_focus(focus)
	if is_instance_valid(village_residents):
		village_residents.set_focus(focus)
	if model.living_village and is_instance_valid(safe_ui):
		_sync_visible_plots()
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
		if model.living_village:
			_sync_visible_plots()
	if is_instance_valid(village_residents):
		village_residents.advance(delta)
	if model.living_village:
		_advance_village_details(delta)
		if is_instance_valid(neighbors_view):
			neighbors_view.advance(minf(delta, 0.1), explorer.position if walking else focus)
		if is_instance_valid(raids_view):
			raids_view.advance(minf(delta, 0.1))
			if raids_view.playing():
				focus = focus.lerp(raids_view.focus_point(), 1.0 - exp(-2.0 * delta))
				_camera_update(true)
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
				"slot": slot,
				"village_meta": _village_meta_snapshot()
			}
			if model.living_village
			else {
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


func _leave(destination: String = "") -> void:
	if save_blocked or _save():
		SceneRouter.goto(return_scene if destination.is_empty() else destination)


# ----------------------------------------------------------------- Dorfwelt
# Kamera, Tageszeit und lebendige Details der großen Dorfkarte. Nichts davon
# verändert Spielstand, Rohstoffe, Zeitlauf oder Belohnungen.
const FOCUS_LIMIT := Vector2(205.0, 108.0)
## Startblick über das Tal: von Süden auf den Ort, Berge und Fluss dahinter.
const START_VIEW := Vector3(-0.38, 0.38, 64.0)
const RADIUS_RANGE := Vector2(14.0, 110.0)
const TILT_RANGE := Vector2(0.28, 1.25)
var touches: Dictionary = {}
var gesture_moved := false
var gesture_start := Vector2.ZERO
var pinch_distance := 0.0
var pinch_angle := 0.0
var pinch_center := Vector2.ZERO
var pan_velocity := Vector3.ZERO
var mouse_orbit := false


func _start_focus() -> Vector3:
	return Vector3(-REGION.TOWN_CENTER + 2.0, REGION.ground(-REGION.TOWN_CENTER, 0.0), 4.0)


## Für Darstellung und Bildprüfungen: dieselbe Regel wie im Spielmodell.
func plot_buildable(plot: int, opponent := false) -> bool:
	return model.plot_buildable(plot, opponent)


func set_time_of_day(value: float) -> void:
	time_of_day = clampf(value, 0.0, 1.0)
	if model.living_village:
		ATMOSPHERE.set_time(self, time_of_day)
		if is_instance_valid(village_life):
			village_life.set_night(float(get_meta("village_night", 0.0)))


func toggle_evening() -> void:
	if day_cycle != null and day_cycle.is_valid():
		day_cycle.kill()
	var target := 0.35 if time_of_day > 0.6 else 0.82
	day_cycle = create_tween()
	day_cycle.tween_method(set_time_of_day, time_of_day, target, 1.6).set_trans(Tween.TRANS_SINE)


## „Nächster Tag“: der Abend zieht über das Tal, Fenster gehen an, dann wird
## es wieder Morgen. Nur Bild – der Tag im Modell ist schon weitergezählt.
func _play_day_cycle() -> void:
	if not model.living_village or not is_inside_tree():
		return
	if day_cycle != null and day_cycle.is_valid():
		day_cycle.kill()
	day_cycle = create_tween()
	day_cycle.tween_method(set_time_of_day, time_of_day, 0.86, 1.1).set_trans(Tween.TRANS_SINE)
	day_cycle.tween_interval(0.5)
	day_cycle.tween_method(set_time_of_day, 0.86, 0.35, 1.3).set_trans(Tween.TRANS_SINE)


func _collect_living_details() -> void:
	if not model.living_village:
		return
	spinning_parts.clear()
	var chimneys: Array[Vector3] = []
	var built: Array = []
	for building in model.player().buildings:
		built.append(int(building.plot))
	for key in facility_nodes:
		var facility: Node3D = facility_nodes[key]
		for part in facility.get_meta("spin_parts", []):
			if is_instance_valid(part):
				spinning_parts.append(part)
		for local in facility.get_meta("chimneys", []):
			chimneys.append(facility.transform * (local as Vector3))
	if is_instance_valid(village_region):
		village_region.set_built_plots(built, false)
		if mode == "rival":
			var rival_built: Array = []
			for building in model.rival().buildings:
				rival_built.append(int(building.plot))
			village_region.set_built_plots(rival_built, true)
	if is_instance_valid(village_life):
		var view_focus: Vector3 = explorer.position if walking else focus
		chimneys.sort_custom(
			func(a: Vector3, b: Vector3) -> bool:
				return a.distance_squared_to(view_focus) < b.distance_squared_to(view_focus)
		)
		village_life.set_smoke_sources(chimneys)
		village_life.set_town(model.player(), view_focus)


func _advance_village_details(delta: float) -> void:
	var step := minf(delta, 0.1)
	for part in spinning_parts:
		if is_instance_valid(part):
			part.rotate_object_local(Vector3.RIGHT, step * (2.6 if str(part.name) == "Spin_Saw" else 0.7))
	if is_instance_valid(village_region):
		village_region.advance(step)
	if is_instance_valid(village_life):
		village_life.advance(step, camera.global_position if is_instance_valid(camera) else focus)
	if not walking and touches.is_empty() and pan_velocity.length_squared() > 0.0004:
		focus += pan_velocity * step
		pan_velocity *= exp(-4.5 * step)
		_clamp_focus()
		_camera_update()


func _clamp_focus() -> void:
	focus.x = clampf(focus.x, -FOCUS_LIMIT.x, FOCUS_LIMIT.x)
	focus.z = clampf(focus.z, -FOCUS_LIMIT.y, FOCUS_LIMIT.y)
	focus.y = REGION.ground(focus.x, focus.z)


func _pan_by(relative: Vector2) -> Vector3:
	var height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var scale := maxf(radius, 20.0) * 1.15 / height
	var right := Vector3(cos(orbit), 0.0, -sin(orbit))
	var forward := Vector3(-sin(orbit), 0.0, -cos(orbit))
	var move := -right * relative.x * scale + forward * relative.y * scale / maxf(0.35, sin(tilt))
	focus += move
	_clamp_focus()
	return move


## Ein Finger: verschieben. Zwei Finger: zoomen, drehen, neigen.
## Maus: linke Taste verschieben, rechte Taste drehen, Rad zoomen.
func _village_gesture(event: InputEvent) -> void:
	if paused or is_instance_valid(campaign_map):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			pan_velocity = Vector3.ZERO
			if touches.size() == 1:
				gesture_start = event.position
				gesture_moved = false
			elif touches.size() == 2:
				gesture_moved = true
				_reset_pinch()
		else:
			_village_release(event)
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = event.position
		if touches.size() == 1:
			gesture_moved = gesture_moved or event.position.distance_to(gesture_start) > 10.0
			if gesture_moved:
				var move := _pan_by(event.relative)
				pan_velocity = pan_velocity.lerp(move / maxf(get_physics_process_delta_time(), 0.008), 0.35)
				_camera_update()
		elif touches.size() >= 2:
			_pinch_update()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			radius = clampf(radius * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), RADIUS_RANGE.x, RADIUS_RANGE.y)
			_camera_update()
			_sync_visible_plots()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_orbit = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touches[-1] = event.position
				gesture_start = event.position
				gesture_moved = false
				pan_velocity = Vector3.ZERO
			else:
				_village_release(event)
	elif event is InputEventMouseMotion:
		if mouse_orbit:
			orbit -= event.relative.x * 0.006
			tilt = clampf(tilt + event.relative.y * 0.004, TILT_RANGE.x, TILT_RANGE.y)
			_camera_update()
		elif touches.has(-1):
			gesture_moved = gesture_moved or event.position.distance_to(gesture_start) > 10.0
			if gesture_moved:
				_pan_by(event.relative)
				_camera_update()


func _reset_pinch() -> void:
	var points: Array = touches.values()
	pinch_distance = (points[0] as Vector2).distance_to(points[1])
	pinch_angle = ((points[1] as Vector2) - (points[0] as Vector2)).angle()
	pinch_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _pinch_update() -> void:
	var points: Array = touches.values()
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	var distance := a.distance_to(b)
	var angle := (b - a).angle()
	var center := (a + b) * 0.5
	if pinch_distance > 8.0 and distance > 8.0:
		radius = clampf(radius * pinch_distance / distance, RADIUS_RANGE.x, RADIUS_RANGE.y)
	orbit += wrapf(angle - pinch_angle, -PI, PI)
	tilt = clampf(tilt + (center.y - pinch_center.y) * 0.004, TILT_RANGE.x, TILT_RANGE.y)
	pinch_distance = distance
	pinch_angle = angle
	pinch_center = center
	_camera_update()
	_sync_visible_plots()


## Owns every world-finger release, even above HUD controls, so no stale
## finger blocks the next plot selection. Returns true when consumed.
func _village_release(event: InputEvent) -> bool:
	var index := -2
	if event is InputEventScreenTouch and not event.pressed:
		index = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		index = -1
	if index == -2 or not touches.has(index):
		return false
	var was_single := touches.size() == 1
	touches.erase(index)
	var canceled: bool = event is InputEventScreenTouch and event.canceled
	if was_single and not gesture_moved and not canceled and not walking and not paused:
		_pick_plot(event.position)
	if touches.size() == 1:
		gesture_start = touches.values()[0]
		gesture_moved = true
	get_viewport().set_input_as_handled()
	return true


# ------------------------------------------------------------- Dorf-HUD
# Obere Leiste mit Rohstoffen, Kapitel-Tafel mit Fortschrittsbalken, Dock mit
# Hauptaktionen und Gebäudekarten, Kamera-Leiste. Alles ≥ 48 dp, Safe-Area.
func _build_village_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	top_backdrop = Panel.new()
	top_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_backdrop.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	safe_ui.add_child(top_backdrop)
	bottom_backdrop = Panel.new()
	bottom_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_backdrop.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	safe_ui.add_child(bottom_backdrop)
	# Top bar: back · resources · Lumo · pause
	top = VBoxContainer.new()
	top.name = "VillageTopBar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.minimum_size_changed.connect(func(): call_deferred("_layout"))
	safe_ui.add_child(top)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", VHUD.panel("glass", 6))
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(bar)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	bar.add_child(heading)
	var back := VHUD.button("‹ Spiele" if host_entry else "‹ Bauwelt", _leave, 96, "cream", 15)
	back.name = "SettlementReturn"
	heading.add_child(back)
	var chips_scroll := ScrollContainer.new()
	chips_scroll.name = "VillageResourceBar"
	chips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chips_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	heading.add_child(chips_scroll)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips_scroll.add_child(chips)
	for resource in ["wood", "stone", "food", "coins", "population", "plots", "day", "treasury", "happiness", "water"]:
		var chip := VHUD.chip(resource)
		chips.add_child(chip)
		resource_chips[resource] = chip
	walk_button = VHUD.button("Lumo", _toggle_walk, 70, "teal", 15)
	heading.add_child(walk_button)
	heading.add_child(VHUD.button("Ⅱ", _toggle_pause, 52, "cream", 18))
	# Chapter card with the real story goal and progress bars.
	goal_card = PanelContainer.new()
	goal_card.name = "VillageChapterCard"
	goal_card.add_theme_stylebox_override("panel", VHUD.panel("glass", 10))
	goal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(goal_card)
	var goal_box := VBoxContainer.new()
	goal_box.add_theme_constant_override("separation", 4)
	goal_card.add_child(goal_box)
	goal_label = VHUD.label("", 15)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_box.add_child(goal_label)
	for index in range(3):
		var row := VHUD.progress_row()
		goal_box.add_child(row)
		progress_rows.append(row)
	rival_label = VHUD.label("", 13)
	rival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_box.add_child(rival_label)
	# Camera cluster (right edge): zoom, home view, evening.
	camera_cluster = VBoxContainer.new()
	camera_cluster.name = "VillageCameraTools"
	camera_cluster.add_theme_constant_override("separation", 8)
	safe_ui.add_child(camera_cluster)
	camera_cluster.add_child(VHUD.round_button("+", _zoom_village.bind(-1), "Näher heran"))
	camera_cluster.add_child(VHUD.round_button("−", _zoom_village.bind(1), "Weiter weg"))
	camera_cluster.add_child(VHUD.round_button("⌂", _home_view, "Zurück zum Dorfplatz"))
	evening_button = VHUD.round_button("☾", toggle_evening, "Abendstimmung")
	camera_cluster.add_child(evening_button)
	# Feedback toast above the dock.
	toast = PanelContainer.new()
	toast.name = "VillageFeedback"
	toast.add_theme_stylebox_override("panel", VHUD.panel("glass", 6))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(toast)
	feedback = VHUD.label(
		"Dein Plan zählt: Nahrung, Material und Wohnraum halten die Siedlung am Leben.", 14
	)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(feedback)
	# Dock: plot hint · primary actions + toolbar + day · building cards.
	bottom = VBoxContainer.new()
	bottom.name = "VillageDock"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 6)
	bottom.minimum_size_changed.connect(func(): call_deferred("_layout"))
	safe_ui.add_child(bottom)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", VHUD.panel("glass", 8))
	dock.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom.add_child(dock)
	var dock_box := VBoxContainer.new()
	dock_box.add_theme_constant_override("separation", 6)
	dock.add_child(dock_box)
	plot_label = VHUD.label("Wähle ein freies Grundstück und ein Gebäude.", 14)
	plot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock_box.add_child(plot_label)
	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 8)
	dock_box.add_child(first_row)
	dock_rows.append(first_row)
	primary_row = HBoxContainer.new()
	primary_row.name = "VillagePrimaryActions"
	primary_row.add_theme_constant_override("separation", 8)
	first_row.add_child(primary_row)
	var chapter_action := VHUD.button("Kapitel", _chapter_dialog, 96, "primary", 15)
	chapter_action.mouse_filter = Control.MOUSE_FILTER_STOP
	primary_row.add_child(chapter_action)
	var map_action := VHUD.button("Karte", open_campaign_map, 84, "teal", 15)
	map_action.name = "VillageCampaignMap"
	map_action.mouse_filter = Control.MOUSE_FILTER_STOP
	primary_row.add_child(map_action)
	var find_action := VHUD.button("Freier Bauplatz", _focus_next_free_plot, 140, "leaf", 15)
	find_action.mouse_filter = Control.MOUSE_FILTER_STOP
	primary_row.add_child(find_action)
	actions_scroll_node = ScrollContainer.new()
	actions_scroll_node.name = "VillageActions"
	actions_scroll_node.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions_scroll_node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	actions_scroll_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_row.add_child(actions_scroll_node)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions_scroll_node.add_child(actions)
	# Frequent story actions stay in the toolbar; rarely used tools sit in
	# the "Mehr" panel (same buttons, same rules, same state handling).
	more_panel = PanelContainer.new()
	more_panel.name = "VillageMoreTools"
	more_panel.add_theme_stylebox_override("panel", VHUD.panel("glass", 10))
	more_panel.hide()
	safe_ui.add_child(more_panel)
	var more_box := VBoxContainer.new()
	more_box.add_theme_constant_override("separation", 8)
	more_panel.add_child(more_box)
	for spec in [
		["Rückgängig", _undo, more_box], ["Wiederholen", _redo, more_box], ["Handeln", _trade_dialog, actions],
		["Nachbar ansehen" if mode == "rival" else "Überblick", _look_neighbor, more_box],
		["Tilda · Lieferung", _tilda_dialog, actions], ["Stadtkasse", _public_project_dialog, actions]
	]:
		var action_button := VHUD.button(spec[0], _from_more.bind(spec[1]), 150 if spec[2] == more_box else 104, "cream", 15)
		action_button.mouse_filter = Control.MOUSE_FILTER_PASS
		transaction_buttons.append(action_button)
	for index in [4, 5, 2]:
		actions.add_child(transaction_buttons[index])
	var neighbor_button := VHUD.button("Nachbarn", _from_more.bind(_neighbors_dialog), 110, "teal", 15)
	neighbor_button.name = "VillageNeighbors"
	neighbor_button.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_child(neighbor_button)
	defense_button = VHUD.button("Schutz", _from_more.bind(_defense_dialog), 100, "rose", 15)
	defense_button.name = "VillageDefense"
	defense_button.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_child(defense_button)
	raid_alert = VHUD.button("", _defense_dialog, 300, "rose", 16)
	raid_alert.name = "VillageRaidAlert"
	raid_alert.mouse_filter = Control.MOUSE_FILTER_PASS
	raid_alert.hide()
	safe_ui.add_child(raid_alert)
	for index in [0, 1, 3]:
		more_box.add_child(transaction_buttons[index])
	demolish_button = VHUD.button("Rückbauen", _from_more.bind(_demolish), 150, "rose", 15)
	demolish_button.mouse_filter = Control.MOUSE_FILTER_PASS
	more_box.add_child(demolish_button)
	expand_button = VHUD.button("Erweitern", _from_more.bind(_expand), 150, "sky", 15)
	expand_button.mouse_filter = Control.MOUSE_FILTER_PASS
	more_box.add_child(expand_button)
	more_button = VHUD.button("Mehr ▴", _toggle_more, 96, "dark", 15)
	more_button.name = "VillageMore"
	more_button.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_child(more_button)
	day_button = VHUD.button("Nächster Tag ☀", _day_action, 156, "primary", 16)
	first_row.add_child(day_button)
	var second_row := HBoxContainer.new()
	second_row.name = "VillageSecondRow"
	second_row.add_theme_constant_override("separation", 8)
	second_row.hide()
	dock_box.add_child(second_row)
	var buildings_scroll := ScrollContainer.new()
	buildings_scroll.name = "VillageBuildCards"
	buildings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buildings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	dock_box.add_child(buildings_scroll)
	dock_rows.append(buildings_scroll)
	dock_rows.append(second_row)
	var buildings := HBoxContainer.new()
	buildings.add_theme_constant_override("separation", 8)
	buildings_scroll.add_child(buildings)
	for kind in STATE.BUILDINGS.keys():
		var spec: Dictionary = STATE.BUILDINGS[kind]
		var card := VHUD.building_card(
			kind, str(spec.title) + "\n" + _cost_text(model.building_cost(kind)), _buy.bind(kind)
		)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		buildings.add_child(card)
		purchase_buttons[kind] = card
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _panel())
	pause_panel.custom_minimum_size = Vector2(300, 0)
	pause_panel.hide()
	safe_ui.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pause_box)
	pause_box.add_child(_label("Deine Siedlung wartet", 22))
	pause_box.add_child(_button("Weiter", _toggle_pause))
	pause_box.add_child(_button("Speichern", _save_message))
	var replay := _button("Lumo zeigt es noch einmal", _tutorial_topics)
	replay.name = "VillageTutorialReplay"
	pause_box.add_child(replay)
	pause_box.add_child(_button("Zur Spielewelt" if host_entry else "Zur Bauwelt", _leave))
	if host_entry:
		var build_return := _button("Zur Bauwelt", _leave.bind("build"))
		build_return.name = "SettlementBuildReturn"
		pause_box.add_child(build_return)
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


func _layout_village_hud(size: Vector2) -> void:
	var portrait := size.y > size.x * 1.15
	var short := size.y < 430.0
	var gap := 8.0
	top.offset_left = gap
	top.offset_right = -gap
	top.offset_top = gap
	bottom.offset_left = gap
	bottom.offset_right = -gap
	bottom.offset_bottom = -gap
	for chip: PanelContainer in resource_chips.values():
		var value: Label = chip.get_meta("value")
		value.add_theme_font_size_override("font_size", 17 if short else 21)
		var icon: TextureRect = chip.get_meta("icon")
		icon.custom_minimum_size = Vector2.ONE * (28 if short else 36)
	# Portrait/narrow: toolbar and day button move to a second row.
	var narrow := size.x < 900.0
	var first_row: HBoxContainer = dock_rows[0]
	var second_row: HBoxContainer = dock_rows[2]
	if narrow and actions_scroll_node.get_parent() == first_row:
		first_row.remove_child(actions_scroll_node)
		first_row.remove_child(day_button)
		second_row.add_child(actions_scroll_node)
		second_row.add_child(day_button)
	elif not narrow and actions_scroll_node.get_parent() != first_row:
		second_row.remove_child(actions_scroll_node)
		second_row.remove_child(day_button)
		first_row.add_child(actions_scroll_node)
		first_row.add_child(day_button)
	second_row.visible = narrow
	if narrow:
		primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for child in primary_row.get_children():
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		primary_row.size_flags_horizontal = Control.SIZE_FILL
		for child in primary_row.get_children():
			child.size_flags_horizontal = Control.SIZE_FILL
	var top_end := top.position.y + top.size.y
	var card_width := clampf(size.x * (0.94 if portrait else 0.36), 260.0, 460.0)
	goal_card.custom_minimum_size = Vector2(card_width, 0)
	goal_card.size = Vector2(card_width, 0)
	goal_card.position = Vector2(gap if not portrait else (size.x - card_width) * 0.5, top_end + gap)
	goal_label.add_theme_font_size_override("font_size", 13 if short else 15)
	for row in progress_rows:
		row.visible = row.visible and not short
	goal_card.reset_size()
	if is_instance_valid(raid_alert):
		raid_alert.visible = raids != null and not raids.pending.is_empty() and not short
		raid_alert.reset_size()
		raid_alert.position = Vector2(goal_card.position.x, goal_card.position.y + goal_card.size.y + gap)
	var cluster_height := camera_cluster.get_combined_minimum_size().y
	var dock_top := size.y - bottom.get_combined_minimum_size().y - gap
	var cluster_y := clampf((top_end + dock_top - cluster_height) * 0.5, top_end + gap, maxf(top_end + gap, dock_top - cluster_height - gap))
	if portrait:
		cluster_y = maxf(goal_card.position.y + goal_card.size.y + gap, dock_top - cluster_height - gap - 60.0)
	camera_cluster.visible = dock_top - top_end > cluster_height * 0.6
	camera_cluster.position = Vector2(size.x - 52.0 - gap, cluster_y)
	camera_cluster.size = camera_cluster.get_combined_minimum_size()
	var toast_width := clampf(size.x * 0.6, 260.0, 720.0)
	toast.custom_minimum_size = Vector2(toast_width, 0)
	toast.size = Vector2(toast_width, 0)
	toast.reset_size()
	toast.position = Vector2((size.x - toast_width) * 0.5, dock_top - toast.size.y - gap)
	toast.visible = not short and toast.position.y > top_end + gap
	plot_label.visible = portrait and not short
	if more_panel.visible:
		more_panel.reset_size()
		var anchor := _hud_rect(more_button)
		more_panel.position = Vector2(
			clampf(anchor.end.x - more_panel.size.x, gap, size.x - more_panel.size.x - gap),
			maxf(top_end + gap, anchor.position.y - more_panel.size.y - gap)
		)
	if is_instance_valid(evening_button):
		evening_button.text = "☀" if time_of_day > 0.6 else "☾"


func _toggle_more() -> void:
	more_panel.visible = not more_panel.visible
	_layout()


func _from_more(action: Callable) -> void:
	if is_instance_valid(more_panel):
		more_panel.hide()
	action.call()


func _home_view() -> void:
	if _transactions_blocked():
		return
	focus = _start_focus()
	orbit = START_VIEW.x
	tilt = START_VIEW.y
	radius = START_VIEW.z
	pan_velocity = Vector3.ZERO
	_rebuild()
	_camera_update(true)



# ------------------------------------------------------------- Tutorial
func _start_village_systems() -> void:
	tutorial = TUTORIAL.new()
	safe_ui.add_child(tutorial)
	tutorial.setup(self, village_meta.get("tutorial"))
	neighbors = NEIGHBORS.restore(village_meta.get("neighbors"))
	neighbors_view = NEIGHBORS_VIEW.new()
	add_child(neighbors_view)
	neighbors_view.setup(neighbors)
	raids = RAIDS.restore(village_meta.get("raids"), model)
	raids_view = RAIDS_VIEW.new()
	add_child(raids_view)
	raids_view.setup(model, raids, LumoQuality.tier())
	raids_view.scene_finished.connect(_raid_scene_finished)
	_refresh_raid_alert()
	_layout()


func _village_meta_snapshot() -> Dictionary:
	var data := village_meta.duplicate(true)
	data["meta_version"] = 1
	if is_instance_valid(tutorial):
		data["tutorial"] = tutorial.snapshot()
	if neighbors != null:
		data["neighbors"] = neighbors.snapshot()
	if raids != null:
		data["raids"] = raids.snapshot(model)
	return data


func _explain(topic: String) -> void:
	if is_instance_valid(tutorial):
		tutorial.explain_once(topic)


## Called by the tutorial; the state is written with the next regular save.
func tutorial_changed() -> void:
	if is_instance_valid(tutorial):
		village_meta["tutorial"] = tutorial.snapshot()


func tutorial_focus(target: String) -> void:
	if target == "lumo" and is_instance_valid(village_life) and village_life.lumo != null:
		pass


func tutorial_safe_band() -> Vector2:
	var top_end := top.position.y + top.size.y if is_instance_valid(top) else 0.0
	var dock_top := bottom.position.y if is_instance_valid(bottom) and bottom.visible else safe_ui.size.y
	if is_instance_valid(toast) and toast.visible:
		dock_top = minf(dock_top, toast.position.y)
	return Vector2(top_end, dock_top)


func _union(controls: Array) -> Rect2:
	var result := Rect2()
	for control: Control in controls:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var rect := _hud_rect(control)
		result = rect if result.size == Vector2.ZERO else result.merge(rect)
	return result


func _clip_to_scroll(control: Control) -> Rect2:
	var rect := _hud_rect(control)
	var parent := control.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		rect = rect.intersection(_hud_rect(parent))
	return rect


func tutorial_target_rect(target: String) -> Rect2:
	match target:
		"card_house", "card_farm":
			var kind := target.substr(5)
			return _clip_to_scroll(purchase_buttons[kind]) if purchase_buttons.has(kind) else Rect2()
		"day":
			return _hud_rect(day_button) if day_button.is_visible_in_tree() else Rect2()
		"chips":
			return _union([resource_chips.wood, resource_chips.stone, resource_chips.food])
		"people":
			return _union([resource_chips.population])
		"goal":
			return _union([goal_card])
		"world":
			var band := tutorial_safe_band()
			var center := Vector2(safe_ui.size.x * 0.5, (band.x + band.y) * 0.5)
			return Rect2(center - Vector2(110, 50), Vector2(220, 100))
		"plot", "lumo":
			var where := Vector3.INF
			if target == "plot":
				var free := _next_free_plot()
				if free >= 0:
					where = _plot_world(free) + Vector3.UP * 0.2
			elif is_instance_valid(village_life) and village_life.lumo != null:
				where = village_life.lumo.global_position + Vector3.UP * 0.8
			if where == Vector3.INF or camera.is_position_behind(where):
				return Rect2()
			var screen := camera.unproject_position(where)
			var local := safe_ui.get_global_transform_with_canvas().affine_inverse() * screen
			return Rect2(local - Vector2(36, 36), Vector2(72, 72))
	return Rect2()


func _tutorial_topics() -> void:
	if paused:
		_toggle_pause()
	var view: Dictionary = _village_dialog("Lumo zeigt es noch einmal")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var dialog: Window = view.dialog
	_village_caption(body, "Was soll ich dir noch einmal zeigen?")
	for topic in TUTORIAL.TOPICS:
		var button := _button(topic, _replay_topic.bind(topic, dialog), 220)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		body.add_child(button)


func _replay_topic(topic: String, dialog: Window) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	if is_instance_valid(tutorial):
		tutorial.replay(topic)



# ------------------------------------------------------------ Nachbarn
func _advance_neighbors() -> String:
	var result: Dictionary = neighbors.advance_day(model)
	if is_instance_valid(neighbors_view):
		neighbors_view.sync()
	var help: Dictionary = result.get("help", {})
	if not help.is_empty():
		var site: Vector3 = NEIGHBORS.plot_world(str(help.id), 4)
		neighbors_view.start_caravan(site, _plot_world(4), "Hilfe von %s" % str(NEIGHBORS.spec(str(help.id)).name))
		return "%s schickt dir %d Essen" % [str(NEIGHBORS.spec(str(help.id)).name), int(help.food)]
	var grew := 0
	for id in result.neighbors:
		grew += result.neighbors[id].built.size()
	return "Nachbarn bauen %d Gebäude" % grew if grew > 0 else ""


func _mood_text(id: String) -> String:
	var value := int(neighbors.reputation[id])
	return "Freundschaft %d/%d (%s)" % [maxi(0, value), NEIGHBORS.MAX_REPUTATION, neighbors.mood(id)]


func _neighbors_dialog() -> void:
	if neighbors == null:
		return
	_explain("nachbarn")
	var view: Dictionary = _village_dialog("Deine Nachbarn")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var dialog: Window = view.dialog
	for entry in NEIGHBORS.NEIGHBORS:
		var id: String = entry.id
		var info: Dictionary = neighbors.summary(id)
		_village_caption(body, "%s aus %s" % [str(entry.name), str(entry.town)], 19)
		_village_caption(body, str(entry.text))
		_village_caption(body, "%s · %d Bewohner · %d Gebäude" % [_mood_text(id), int(info.population), int(info.buildings)])
		var deal: Dictionary = neighbors.offer(id)
		if not deal.is_empty():
			var trade := _button("Tauschen: %s → %s" % [_cost_text(deal.give), _cost_text(deal.receive)], _neighbor_trade.bind(id, dialog), 300)
			trade.mouse_filter = Control.MOUSE_FILTER_PASS
			trade.disabled = not model._affords(model.player(), deal.give)
			body.add_child(trade)
		var present := _button("Geschenk: 4 Essen", _neighbor_gift.bind(id, dialog), 300)
		present.mouse_filter = Control.MOUSE_FILTER_PASS
		present.disabled = int(model.player().resources.food) < 4
		body.add_child(present)
	_village_caption(body, "Rohstoffquellen (+%d am Tag für den Besitzer)" % NEIGHBORS.SOURCE_YIELD, 18)
	for key in NEIGHBORS.SOURCES:
		var source: Dictionary = NEIGHBORS.SOURCES[key]
		var owner := str(neighbors.sources.get(key, ""))
		if owner.is_empty():
			var claim := _button("%s sichern: %s" % [str(source.title), _cost_text(source.cost)], _claim_source.bind(key, dialog), 300)
			claim.mouse_filter = Control.MOUSE_FILTER_PASS
			claim.disabled = not model._affords(model.player(), source.cost)
			body.add_child(claim)
		else:
			_village_caption(body, "%s: %s" % [str(source.title), "gehört dir" if owner == "player" else "gehört " + str(NEIGHBORS.spec(owner).name)])


func _neighbor_trade(id: String, dialog: Window) -> void:
	if _transactions_blocked():
		return
	if neighbors.trade(id, model):
		neighbors_view.start_caravan(_plot_world(4), NEIGHBORS.plot_world(id, 4), "Karawane zu " + str(NEIGHBORS.spec(id).name))
		_explain("karawane")
		_rebuild()
		_save()
		feedback.text = "Handel mit %s geschafft. Die Karawane ist unterwegs." % str(NEIGHBORS.spec(id).name)
	else:
		feedback.text = "Dieser Tausch klappt gerade nicht."
	if is_instance_valid(dialog):
		dialog.queue_free()


func _neighbor_gift(id: String, dialog: Window) -> void:
	if _transactions_blocked():
		return
	if neighbors.gift(id, model):
		neighbors_view.start_caravan(_plot_world(4), NEIGHBORS.plot_world(id, 4), "Geschenk für " + str(NEIGHBORS.spec(id).name))
		_rebuild()
		_save()
		feedback.text = "%s freut sich über dein Geschenk." % str(NEIGHBORS.spec(id).name)
	if is_instance_valid(dialog):
		dialog.queue_free()


func _claim_source(key: String, dialog: Window) -> void:
	if _transactions_blocked():
		return
	if neighbors.claim_source(key, model):
		neighbors_view.sync()
		_rebuild()
		_save()
		feedback.text = "Die %s gehört jetzt deinem Dorf." % str(NEIGHBORS.SOURCES[key].title)
	else:
		feedback.text = model.last_error if not model.last_error.is_empty() else "Das geht gerade nicht."
	if is_instance_valid(dialog):
		dialog.queue_free()


# ------------------------------------------------------------ Angriffe (Teil 3)
const RAID_OUTCOME_TITLES := {
	"abgewehrt": "Abgewehrt! Alle purzeln davon.", "knapp": "Knapp! Fast hättest du es geschafft.",
	"verloren": "Diesmal waren sie stärker.", "frieden": "Frieden geschlossen.",
}
const PART_ORDER := ["wall", "tower", "gate", "ditch", "trap"]


func _refresh_raid_alert() -> void:
	if not is_instance_valid(raid_alert) or raids == null:
		return
	if raids.pending.is_empty():
		raid_alert.hide()
	else:
		var days := maxi(0, int(raids.pending.arrive_day) - int(model.day))
		var view: Dictionary = raids.forecast()
		raid_alert.text = "⚠ %s · %s · %s" % [
			raids.threat_title(raids.pending), "heute Nacht" if days == 0 else ("in %d Tag%s" % [days, "" if days == 1 else "en"]),
			"Schutz reicht" if bool(view.ready) else "Schutz planen!"]
	_layout()


func _handle_raid_report(report: Dictionary) -> void:
	if report.is_empty():
		_refresh_raid_alert()
		return
	var expedition: Dictionary = report.get("expedition", {})
	if not expedition.is_empty():
		if str(expedition.kind) == "kundschafter":
			feedback.text = "Der Kundschafter ist zurück: " + " ".join(expedition.get("lines", []))
		else:
			feedback.text = "Deine Wachen sind zurück und bringen %s mit. Krummzahn ist davongelaufen!" % _cost_text(expedition.get("back", {}))
	if report.has("warning"):
		_explain("angriff")
		var warning: Dictionary = report.warning
		feedback.text = "Achtung: %s %s" % [str(warning.reason), str(RAIDS.THREATS[str(warning.threat)].advice)]
		_defense_dialog.call_deferred()
	if report.has("raid"):
		_start_raid_scene(report.raid)
	raids_view.sync()
	_refresh_raid_alert()


func _start_raid_scene(result: Dictionary) -> void:
	raid_camera_return = {"focus": focus, "radius": radius}
	radius = clampf(radius, RADIUS_RANGE.x, 46.0)
	raids_view.play(result)
	feedback.text = "%s kommt! Schau zum Tor." % raids.threat_title(result)


func _raid_scene_finished() -> void:
	if not raid_camera_return.is_empty():
		radius = float(raid_camera_return.radius)
		raid_camera_return = {}
	_rebuild()
	_raid_result_dialog(raids.last_result)


func _lumo_says(body: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var face := TextureRect.new()
	face.texture = VHUD.texture("lumo_portrait")
	face.custom_minimum_size = Vector2(76, 76)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(face)
	var line := _label(text, 17)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	body.add_child(row)


func _raid_button(body: VBoxContainer, text: String, action: Callable, enabled := true) -> Button:
	var button := _button(text, action, 300)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.disabled = not enabled
	body.add_child(button)
	return button


## The planning screen: who comes and why, Lumo's advice, a simple bar
## "dein Schutz gegen den Angriff", what can be built, guards, allies, deals,
## expeditions and repairs. Every button pays with real village stock.
func _defense_dialog() -> void:
	if raids == null:
		return
	_explain("verteidigung")
	var view: Dictionary = _village_dialog("Schutz für dein Dorf")
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	var dialog: Window = view.dialog
	dialog.name = "DefenseDialog"
	var pending: Dictionary = raids.pending
	if not pending.is_empty():
		var days := maxi(0, int(pending.arrive_day) - int(model.day))
		var forecast: Dictionary = raids.forecast()
		_village_caption(body, "%s kommt in %d Tag%s." % [raids.threat_title(pending), days, "" if days == 1 else "en"], 19)
		_lumo_says(body, "%s %s" % [str(pending.reason), str(forecast.advice)])
		var row := VHUD.progress_row()
		VHUD.set_progress(row, "Dein Schutz", roundi(float(forecast.have)), roundi(float(forecast.need) * 1.1))
		body.add_child(row)
		_village_caption(body, "Das reicht!" if bool(forecast.ready) else ("Es wird knapp. Noch etwas mehr Schutz!" if bool(forecast.close) else "Das reicht noch nicht. Baue mehr Schutz!"))
		if str(pending.threat) == "rivale":
			var cost: Dictionary = raids.negotiation_cost()
			_raid_button(body, "Verhandeln: %s schenken" % _cost_text(cost), _raid_action.bind("negotiate", "", dialog), model._affords(model._player, cost))
		if neighbors != null:
			for entry in NEIGHBORS.NEIGHBORS:
				var id: String = entry.id
				if neighbors.allied(id) and id != str(pending.get("by", "")):
					var asked := str(pending.get("ally", "")) == id
					_raid_button(body, "%s hilft schon mit!" % str(entry.name) if asked else "%s um Hilfe bitten" % str(entry.name), _raid_action.bind("ally", id, dialog), not asked)
	else:
		_lumo_says(body, "Gerade ist alles ruhig. Krummzahn mag volle Kornlager (ab %d Essen), Funkel glitzernde Münzen (ab %d)." % [RAIDS.ROBBER_FOOD, RAIDS.DRAGON_COINS])
	_village_caption(body, "Wappen: %d · abgewehrt: %d · Wachen: %d von %d" % [int(raids.fame), int(raids.defended), int(raids.guards), raids.max_guards(model)], 17)
	_village_caption(body, "Schutzbauten", 18)
	for kind in PART_ORDER:
		var stage := int(raids.parts[kind])
		var spec: Dictionary = RAIDS.PARTS[kind]
		if stage >= int(spec.max):
			_village_caption(body, "✓ %s (fertig)" % RAIDS.part_name(kind, stage))
			continue
		var error: String = raids.build_error(kind, model)
		var caption := "%s bauen: %s" % [RAIDS.part_name(kind, stage + 1), _cost_text(raids.next_cost(kind))]
		if int(spec.max) > 1 and kind in ["tower", "trap"]:
			caption = "%s %d/%d: %s" % [str(spec.title), stage + 1, int(spec.max), _cost_text(raids.next_cost(kind))]
		_raid_button(body, caption, _raid_action.bind("build", kind, dialog), error.is_empty())
		if error.begins_with("Dafür brauchst"):
			_village_caption(body, "  " + error)
	_raid_button(body, "Wache ausbilden: 1 Münze", _raid_action.bind("guard", "", dialog), raids.guards < raids.max_guards(model) and raids.expedition.is_empty())
	_village_caption(body, "Unternehmungen", 18)
	if not raids.expedition.is_empty():
		_village_caption(body, "Unterwegs: %s, zurück an Tag %d." % ["Kundschafter" if str(raids.expedition.kind) == "kundschafter" else "Wachen holen Vorräte", int(raids.expedition.return_day)])
	else:
		_raid_button(body, "Kundschafter losschicken: 2 Essen", _raid_action.bind("expedition", "kundschafter", dialog), raids.expedition_error("kundschafter", model).is_empty())
		if not raids.stash.is_empty():
			_raid_button(body, "Vorräte zurückholen (%s)" % _cost_text(raids.stash), _raid_action.bind("expedition", "zurueckholen", dialog), raids.expedition_error("zurueckholen", model).is_empty())
	if not model.damaged_plots.is_empty():
		_village_caption(body, "Reparieren", 18)
		for building in model._player.buildings:
			var plot := int(building.plot)
			if model.damaged_plots.has(plot):
				var cost: Dictionary = raids.repair_cost(model, plot)
				_raid_button(body, "%s reparieren: %s" % [str(STATE.BUILDINGS[str(building.kind)].title), _cost_text(cost)], _raid_action.bind("repair", str(plot), dialog), model._affords(model._player, cost))
	if not raids.chronicle.is_empty():
		_village_caption(body, "Chronik", 18)
		for line in raids.chronicle.slice(-4):
			_village_caption(body, str(line))


func _raid_action(action: String, argument: String, dialog: Window) -> void:
	if _transactions_blocked() or raids == null:
		return
	var error := ""
	match action:
		"build":
			error = raids.build(argument, model)
			if error.is_empty():
				feedback.text = "%s steht! Dein Dorf ist besser geschützt." % RAIDS.part_name(argument, int(raids.parts[argument]))
		"guard":
			error = raids.train_guard(model)
			if error.is_empty():
				feedback.text = "Eine neue Wache mit Helm und Schild."
		"ally":
			error = raids.call_ally(argument, neighbors)
			if error.is_empty():
				feedback.text = "%s kommt dir zu Hilfe!" % str(NEIGHBORS.spec(argument).name)
				neighbors_view.start_caravan(NEIGHBORS.plot_world(argument, 4), _plot_world(4), "Hilfe von " + str(NEIGHBORS.spec(argument).name))
		"negotiate":
			error = raids.negotiate(model, neighbors)
			if error.is_empty():
				feedback.text = "Frieden! Das Geschenk hat geholfen."
		"expedition":
			error = raids.start_expedition(argument, model)
			if error.is_empty():
				feedback.text = "Unterwegs! Mit „Nächster Tag“ kommen sie zurück."
		"repair":
			error = raids.repair(model, int(argument))
			if error.is_empty():
				feedback.text = "Repariert! Das Gebäude arbeitet wieder."
	if not error.is_empty():
		feedback.text = error
	raids_view.sync()
	_rebuild()
	_refresh_raid_alert()
	_save()
	if is_instance_valid(dialog):
		dialog.queue_free()
	if error.is_empty() and action != "negotiate":
		_reopen_defense.call_deferred()


func _reopen_defense() -> void:
	await get_tree().process_frame
	if not is_instance_valid(village_window):
		_defense_dialog()


## Short, readable evaluation after the scene: what happened and what now.
func _raid_result_dialog(result: Dictionary) -> void:
	if result.is_empty():
		return
	var outcome := str(result.get("outcome", ""))
	var view: Dictionary = _village_dialog(str(RAID_OUTCOME_TITLES.get(outcome, "Bericht")))
	if view.is_empty():
		return
	var body: VBoxContainer = view.body
	view.dialog.name = "RaidResult"
	_village_caption(body, "Grund: " + str(result.get("reason", "")))
	_village_caption(body, "Dein Schutz %d gegen den Angriff %d." % [roundi(float(result.get("have", 0))), roundi(float(result.get("need", 0)))], 17)
	if outcome == "abgewehrt":
		_lumo_says(body, "Super geplant! Niemand ist verletzt, alle sind davongepurzelt. Du bekommst ein Wappen und %s." % _cost_text(result.get("reward", {})))
	else:
		var names: Array[String] = []
		for entry in result.get("damaged", []):
			names.append(str(STATE.BUILDINGS[str(entry.kind)].title))
		var loss: Dictionary = result.get("loss", {})
		var lines := "Beschädigt: %s." % (", ".join(names) if not names.is_empty() else "nichts")
		if loss.has("source"):
			lines += " Die %s gehört wieder dem Nachbarn." % str(NEIGHBORS.SOURCES[str(loss.source)].title)
		elif not loss.is_empty():
			lines += " Mitgenommen: %s." % _cost_text(loss)
		_village_caption(body, lines)
		_lumo_says(body, "Kopf hoch! Niemand ist verletzt. Repariere die Gebäude, baue mehr Schutz – und mit zwei Wachen holst du Vorräte zurück.")
		_raid_button(body, "Zum Schutz-Plan", _open_defense_from.bind(view.dialog))


func _open_defense_from(dialog: Window) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	_reopen_defense.call_deferred()
