extends Node3D
## A playable extension of the Treasure Island: the same original Lumo,
## island art and light lead into two neighbourhoods, traffic and real lessons.

const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const ART = preload("res://scripts/creative/lumo_world_art.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const LUMO = preload("res://scripts/characters/lumo/lumo_world_avatar.gd")
const KART = preload("res://scripts/games/kart_vehicle.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")
const OWN_VILLAGE = preload("res://scripts/creative/lumo_world_village.gd")
const WORLD_MAP = preload("res://scripts/creative/lumo_world_map.gd")
const FRIEND_POST = preload("res://scripts/creative/lumo_world_errands_ui.gd")
const CAMERA_CLEARANCE = preload("res://scripts/creative/lumo_world_camera_clearance.gd")

const PERSON_ZOOM_MIN := 3.2
const PERSON_ZOOM_MAX := 13.0
const BUILD_ZOOM_MIN := 28.0
const BUILD_ZOOM_MAX := 155.0
const PERSON_PITCH_MIN := 0.16
const PERSON_PITCH_MAX := 1.02

var model = STATE.new()
var art = ART.new()
var kit = KIT.new()
var player: CharacterBody3D
var fox: Node3D
var camera: Camera3D
var kart_body: CharacterBody3D
var kart_visual: Node3D
var player_shape: CollisionShape3D
var joystick: Control
var safe_ui: Control
var mission_panel: PanelContainer
var mission_label: Label
var status_label: Label
var action_button: Button
var vehicle_button: Button
var run_button: Button
var map_button: Button
var build_button: Button
var exit_button: Button
var build_panel: PanelContainer
var build_box: VBoxContainer
var build_status: Label
var build_buttons: HBoxContainer
var build_marker: MeshInstance3D
var modal: PanelContainer
var modal_box: VBoxContainer
var modal_scroll: ScrollContainer
var marker: MeshInstance3D
var wonder: Node3D
var overview: Control
var previous: Dictionary = {}
var traffic: Array[Dictionary] = []
var signal_lights: Array[Dictionary] = []
var residents: Array[Node3D] = []
var grade := 1
var walking_fast := false
var driving := false
var paused := false
var time := 0.0
var save_clock := 0.0
var save_path := ""
var save_blocked := false
var last_safe := STATE.SPAWN
var last_saved := STATE.SPAWN
var drive_speed := 0.0
var signal_requested := false
var signal_green := false
var signal_clock := 0.0
var checkpoint_message := ""
var reduced_motion := false
var lesson_index := 0
var lesson_answers := 0
var own_village: Node3D
var portals: Array[Dictionary] = []
var friend_post: Node3D
var friend_post_original: Variant = {}
var save_pending := false
var camera_clearance = CAMERA_CLEARANCE.new()
var build_mode := false
var build_kind := "house"
var build_plot := -1
var build_focus := OWN_VILLAGE.ORIGIN + Vector3(-OWN_VILLAGE.REGION.TOWN_CENTER, 0, 0)
var camera_yaw := 0.0
var camera_pitch := 0.48
var person_zoom := 7.2
var build_zoom := 76.0
var camera_contacts: Dictionary = {}
var gesture_index := -1
var gesture_start := Vector2.ZERO
var gesture_moved := false
var airborne_time := 0.0


func _ready() -> void:
	previous = RUNTIME.enter(self, true)
	SceneRouter.current_scene_id = "world"
	grade = clampi(int(SceneRouter.launch_options.get("grade", 1)), 1, 4)
	reduced_motion = bool(SceneRouter.launch_options.get("reduceAnimations", false))
	var profile: String = str(SceneRouter.launch_options.get("childKey", "standalone"))
	save_path = "user://lumo_world_" + profile.sha256_text().substr(0, 32) + ".json"
	if FileAccess.file_exists(save_path):
		var saved_file := FileAccess.open(save_path, FileAccess.READ)
		if saved_file == null or saved_file.get_length() > 65536:
			save_blocked = true
		else:
			var text := saved_file.get_as_text()
			var read_error := saved_file.get_error()
			saved_file.close()
			var parser := JSON.new()
			save_blocked = read_error != OK or parser.parse(text) != OK or not parser.data is Dictionary
			if not save_blocked:
				friend_post_original = parser.data.get("friendPost", {})
				save_blocked = not model.restore(parser.data)
		if save_blocked:
			checkpoint_message = "Dein gespeicherter Weltstand konnte nicht geöffnet werden. Er bleibt unverändert. Bitte kehre zur Spielewelt zurück."
	if model.result_id.is_empty():
		model.result_id = HostBridge.new_result_id()
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_TREASURE_DAY)
	art.build(self)
	_create_owned_village(profile)
	_create_player()
	_create_kart()
	_create_residents()
	_create_traffic()
	_create_portals()
	friend_post = FRIEND_POST.new()
	add_child(friend_post)
	if not friend_post.setup(self, friend_post_original) and not save_blocked:
		checkpoint_message = "Deine Freundepost konnte nicht geladen werden. Der gespeicherte Nebenauftrag bleibt erhalten; du kannst deine Welt weiter erkunden."
	var vegetation_roots: Array[Node3D] = [art.zones.Gartenlandschaft, own_village.region]
	camera_clearance.attach(vegetation_roots)
	wonder = WISPS.new()
	wonder.name = "WorldGuidance"
	wonder.set_reduced_motion(reduced_motion)
	add_child(wonder)
	marker = kit.mesh(self, kit.SHAPES.star(), Vector3.ZERO, Color("baff8d"), true)
	marker.name = "WorldMissionMarker"
	marker.scale = Vector3.ONE * 0.65
	_build_ui()
	if not save_blocked and not model.pending_lesson.is_empty() and int(model.pending_lesson.get("grade", 0)) != grade:
		# A profile may move to the next school year while a lesson is open.
		# Rotate the request before consuming a returning receipt: an old-grade
		# completion cannot unlock the replacement mission, even after restart.
		model.begin_school_request(HostBridge.new_result_id(), grade, model.current().at)
		checkpoint_message = "Die Schulmission passt jetzt zu deiner Schulstufe. Deine Freunde warten auf dich."
		_save()
	var receipt = SceneRouter.launch_options.get("worldLearningReceipt", {})
	if not save_blocked and receipt is Dictionary and model.consume_learning_receipt(receipt):
		checkpoint_message = "Deine Lernrunde ist geschafft! Bruno wartet im Garten."
		_save()
	_update_mission()
	if not save_blocked and model.is_complete():
		_report_completed_reward()
	if not checkpoint_message.is_empty():
		status_label.text = checkpoint_message
	RUNTIME.watch_safe_area(self, _layout)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
	if save_blocked:
		_open_dialog("Deine gespeicherte Welt bleibt erhalten", checkpoint_message)
		modal_box.add_child(KIT.button("Zur Spielewelt", _leave, 180))


func _exit_tree() -> void:
	camera_clearance.detach()
	RUNTIME.restore(self, previous)


func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "LumoWorldExplorer"
	player.floor_snap_length = 0.3
	add_child(player)
	player_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.65
	player_shape.shape = shape
	player_shape.position.y = 0.825
	player.add_child(player_shape)
	fox = LUMO.new()
	player.add_child(fox)
	fox.setup(2.65, reduced_motion)
	player.position = model.position
	last_safe = model.position
	last_saved = model.position
	camera = Camera3D.new()
	camera.name = "WorldAdventureCamera"
	camera.fov = 55
	camera.far = 240
	camera.current = true
	add_child(camera)
	camera.position = player.position + Vector3(4.6, 5.0, 10.0)
	camera.look_at(player.position + Vector3(0, 1.4, -1.4))


func _create_kart() -> void:
	kart_body = CharacterBody3D.new()
	kart_body.name = "LumoWorldKart"
	kart_body.position = Vector3(77, 0.2, 18)
	kart_body.floor_snap_length = 0.3
	add_child(kart_body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.2, 2.7)
	shape_node.shape = shape
	shape_node.position.y = 0.72
	kart_body.add_child(shape_node)
	kart_visual = KART.new()
	kart_visual.name = "OriginalLumoKart"
	kart_body.add_child(kart_visual)
	kart_visual.configure("fox", Color("36a6cc"), "comet")
	kart_visual.set_animated_lumo_enabled(true)
	kart_visual.set_preview_detail(true)
	kart_visual.reduced_motion = reduced_motion
	_set_kart_driver(false)
	art._sign(self, "Dein Lumo Kart · Einsteigen", Vector3(77, 3.2, 18), Color("9aefff"))


func _set_kart_driver(visible_driver: bool) -> void:
	if is_instance_valid(kart_visual.lumo_animation):
		kart_visual.lumo_animation.visible = visible_driver
		kart_visual.lumo_animation.set_suspended(not visible_driver)
	if is_instance_valid(kart_visual.driver):
		kart_visual.driver.visible = visible_driver and not is_instance_valid(kart_visual.lumo_animation)


func _create_residents() -> void:
	var specs := [
		["nelli_rabbit", Vector3(90, 0, 20), "Nelli"],
		["bruno_beaver", Vector3(135, 0, -58), "Bruno"],
		["tilda_duck", Vector3(218, 0, -34), "Tilda"]
	]
	for spec in specs:
		var scene := load("res://assets/creative/village/" + str(spec[0]) + ".glb") as PackedScene
		if scene == null:
			continue
		var friend := scene.instantiate() as Node3D
		friend.name = str(spec[2])
		friend.position = spec[1]
		add_child(friend)
		var bounds := AABB()
		for node in friend.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box: AABB = friend.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		if bounds.size.y > 0.1:
			friend.scale = Vector3.ONE * (2.4 / bounds.size.y)
			friend.position.y -= bounds.position.y * friend.scale.y
		residents.append(friend)
		art._sign(self, str(spec[2]), spec[1] + Vector3.UP * 3.2, Color("fff1c8"))


func _create_traffic() -> void:
	for index in range(4):
		var direction := 1.0 if index < 2 else -1.0
		var id := "school_bus" if index == 1 else "city_car"
		var visual: Node3D = art._vehicle(self, id, Vector3(78 + index * 43, 0.03, 2.3 * direction), -PI * 0.5 * direction)
		if visual != null:
			visual.name = "WorldTraffic_" + str(index)
			traffic.append({"node": visual, "direction": direction, "speed": 0.0, "cruise": 5.4 if index == 1 else 6.4})
	for z in [-5.1, 5.1]:
		var x := 107.15 if z > 0 else 112.85
		kit.cylinder(self, Vector3(x, 1.55, z), 0.07, 3.1, Color("36566b"))
		kit.box(self, Vector3(x, 2.85, z), Vector3(0.54, 1.1, 0.36), Color("182936"))
		var red := kit.sphere(self, Vector3(x, 3.08, z + 0.2), Vector3.ONE * 0.27, Color("fa6b6a"), true)
		var green := kit.sphere(self, Vector3(x, 2.62, z + 0.2), Vector3.ONE * 0.27, Color("344d42"))
		signal_lights.append({"red": red, "green": green})


func _create_owned_village(profile: String) -> void:
	own_village = OWN_VILLAGE.new()
	own_village.name = "YourSavedVillage"
	add_child(own_village)
	own_village.setup(profile, clampi(int(SceneRouter.launch_options.get("buildSlot", 1)), 1, 6))
	# This short road joins the mainland to the actual heightmapped village.
	# From x=280 onward it follows the same original height samples.
	var previous_point := Vector3(271, 0.04, 6)
	for index in range(1, 30):
		var x: float = 271.0 + float(index) * 7.8
		var height: float = OWN_VILLAGE.TERRAIN.height(x - OWN_VILLAGE.ORIGIN.x, 6.0) if x >= 280 else 0.0
		var next := Vector3(x, maxf(0.04, height + 0.07), 6.0)
		var center := (previous_point + next) * 0.5
		var direction := next - previous_point
		var road := StaticBody3D.new()
		road.name = "VillageLink_%02d" % index
		road.position = center
		road.rotation.z = atan2(direction.y, direction.x)
		add_child(road)
		var length := direction.length() + 0.12
		kit.box(road, Vector3(0, -0.04, 0), Vector3(length, 0.08, 6.0), Color("c5b690"))
		kit.collision(road, Vector3(0, -0.04, 0), Vector3(length, 0.08, 6.0))
		previous_point = next
	art._sign(self, "DEIN EIGENES DORF", own_village.doorway() + Vector3.UP * 4, Color("b3f8a7"))


func _create_portals() -> void:
	# Dorfwirtschaft und Bauen sind Bestandteil dieser Welt, kein Portalspiel.
	portals = [
		{"game": "kart", "title": "Lumo Kart · Rennstrecken", "at": Vector3(77, 0, 11), "description": "Fahre auf deinen vorhandenen Lumo-Kart-Strecken. Danach kommst du hierher zurück."},
		{"game": "cards", "title": "Lumos Kartensalon", "at": Vector3(218, 0, -17), "description": "Hier wartet der vorhandene 3D-Kartentisch mit deinen gespeicherten Partien. Die bisherigen Spiele bleiben erhalten."}
	]
	for portal in portals:
		var ring := TorusMesh.new()
		ring.inner_radius = 1.6
		ring.outer_radius = 1.72
		ring.rings = 32
		ring.ring_segments = 8
		var visual := kit.mesh(self, ring, portal.at + Vector3.UP * 0.1, Color("84f3ce"), true)
		visual.name = "WorldPortal_" + str(portal.game)
		art._sign(self, str(portal.title), portal.at + Vector3.UP * 3.6, Color("b6ffdf"))


func _near_portal() -> Dictionary:
	for portal in portals:
		if player.position.distance_to(portal.at) < 4.5:
			return portal
	return {}


func _launch_portal(game: String) -> void:
	if game not in ["kart", "cards"] or not _save():
		return
	SceneRouter.launch_options["worldPortalOrigin"] = "world"
	SceneRouter.goto(game)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.name = "WorldSafeUI"
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	mission_panel = PanelContainer.new()
	mission_panel.add_theme_stylebox_override("panel", KIT.tinted_panel(Color("102c42"), Color("7bdfa7"), 18))
	safe_ui.add_child(mission_panel)
	mission_label = KIT.label("", 18)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_panel.add_child(mission_label)
	status_label = KIT.label("Folge dem Stern zu Nelli. Du kannst die ganze Welt in Ruhe erkunden.", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_shadow_color", Color("102438"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	safe_ui.add_child(status_label)
	joystick = STICK.new()
	joystick.skin = "kart3d"
	joystick.reduced_motion = reduced_motion
	joystick.tooltip_text = "Bewegen: Gehen und Lenken mit dem Stick"
	safe_ui.add_child(joystick)
	action_button = KIT.button("Ansprechen", _interact, 130, Color("1b7d63"))
	safe_ui.add_child(action_button)
	vehicle_button = KIT.button("Ins Kart", _toggle_vehicle, 112)
	safe_ui.add_child(vehicle_button)
	run_button = KIT.button("Gehen", _toggle_run, 112)
	safe_ui.add_child(run_button)
	map_button = KIT.button("Weltkarte", _map_dialog, 104)
	safe_ui.add_child(map_button)
	build_button = KIT.button("Bauen", _toggle_build_mode, 104, Color("6652b8"))
	safe_ui.add_child(build_button)
	exit_button = KIT.button("Pause", _pause_menu, 80)
	safe_ui.add_child(exit_button)
	modal = PanelContainer.new()
	modal.name = "WorldDialog"
	modal.add_theme_stylebox_override("panel", KIT.tinted_panel(Color("102c42"), Color("92ecba"), 20))
	safe_ui.add_child(modal)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(modal_scroll)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 12)
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_scroll.add_child(modal_box)
	modal.hide()
	_build_build_ui()
	# The interaction label changes while walking. Godot may grow a Button to
	# its text minimum after this frame; keep its right edge fixed and then
	# recalculate the whole column from the actual themed minimum sizes.
	for button in [action_button, vehicle_button, run_button, map_button, build_button, exit_button]:
		button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		button.minimum_size_changed.connect(func(): _layout.call_deferred())
	mission_panel.minimum_size_changed.connect(func(): _layout.call_deferred())


func _build_build_ui() -> void:
	build_panel = PanelContainer.new()
	build_panel.name = "WorldBuildPanel"
	build_panel.add_theme_stylebox_override(
		"panel", KIT.tinted_panel(Color("132944"), Color("b692ff"), 18)
	)
	safe_ui.add_child(build_panel)
	build_box = VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 8)
	build_panel.add_child(build_box)
	build_status = KIT.label("", 16)
	build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_box.add_child(build_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 64
	build_box.add_child(scroll)
	build_buttons = HBoxContainer.new()
	build_buttons.add_theme_constant_override("separation", 8)
	scroll.add_child(build_buttons)
	for option in own_village.build_options():
		var kind := str(option.kind)
		var title := str(option.title)
		var button := KIT.button(title, _choose_build_kind.bind(kind), 138)
		button.custom_minimum_size.y = 54
		build_buttons.add_child(button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	build_box.add_child(actions)
	actions.add_child(KIT.button("Freier Platz", _next_build_plot, 132))
	actions.add_child(KIT.button("Nächster Tag", _village_next_day, 132))
	actions.add_child(KIT.button("Land erweitern", _village_expand, 142))
	build_marker = MeshInstance3D.new()
	build_marker.name = "WorldBuildMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 2.25
	marker_mesh.bottom_radius = 2.25
	marker_mesh.height = 0.08
	marker_mesh.radial_segments = 40
	build_marker.mesh = marker_mesh
	build_marker.material_override = kit.material(Color("b692ff"), true)
	add_child(build_marker)
	build_marker.hide()
	build_panel.hide()
	_refresh_build_ui()


func _refresh_build_ui(message := "") -> void:
	if not is_instance_valid(build_status):
		return
	var plot_text := "kein freier Platz"
	if build_plot >= 0:
		plot_text = "Bauplatz %d" % (build_plot + 1)
	var title := build_kind
	for option in own_village.build_options():
		if str(option.kind) == build_kind:
			title = str(option.title)
			break
	build_status.text = (
		own_village.resource_text()
		+ "\n"
		+ plot_text
		+ " · "
		+ title
		+ ("" if message.is_empty() else " · " + message)
	)
	if is_instance_valid(build_marker):
		build_marker.visible = build_mode and build_plot >= 0
		if build_plot >= 0:
			build_marker.position = own_village.plot_world(build_plot) + Vector3.UP * 0.12


func _toggle_build_mode() -> void:
	if paused or driving:
		return
	build_mode = not build_mode
	camera_contacts.clear()
	gesture_index = -1
	player.velocity = Vector3.ZERO
	if build_mode:
		if build_plot < 0:
			build_plot = own_village.next_free_plot()
		if build_plot >= 0:
			build_focus = own_village.plot_world(build_plot)
		else:
			build_focus = own_village.doorway()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		build_button.text = "Zu Lumo"
		build_panel.show()
		joystick.set_enabled(false)
		action_button.hide()
		vehicle_button.hide()
		run_button.hide()
		fox.think(2.8)
		camera_clearance.restore_all()
		_update_camera(10.0)
		_refresh_build_ui("Bauansicht")
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		build_button.text = "Bauen"
		build_panel.hide()
		build_marker.hide()
		joystick.set_enabled(true)
		action_button.show()
		vehicle_button.show()
		run_button.show()
		_update_camera(10.0)
	_layout.call_deferred()


func _choose_build_kind(kind: String) -> void:
	if not build_mode or not STATE.BOUNDS.has_point(Vector2(player.position.x, player.position.z)):
		return
	build_kind = kind
	if build_plot < 0:
		build_plot = own_village.next_free_plot()
	if build_plot < 0:
		_refresh_build_ui("Kein freier Bauplatz")
		return
	var result: Dictionary = own_village.try_build(build_kind, build_plot)
	if bool(result.get("ok", false)):
		build_focus = own_village.plot_world(build_plot)
		build_plot = own_village.next_free_plot(build_plot)
		_save()
	_refresh_build_ui(str(result.get("message", "")))


func _next_build_plot() -> void:
	if not build_mode:
		return
	build_plot = own_village.next_free_plot(build_plot)
	if build_plot >= 0:
		build_focus = own_village.plot_world(build_plot)
	_refresh_build_ui()


func _village_next_day() -> void:
	if not build_mode:
		return
	var report: Dictionary = own_village.advance_day()
	var message := str(report.get("message", ""))
	if bool(report.get("advanced", false)):
		message = "Dorftag %d" % int(report.get("day", own_village.model.day))
	_refresh_build_ui(message)


func _village_expand() -> void:
	if not build_mode:
		return
	var result: Dictionary = own_village.expand_town()
	_refresh_build_ui(str(result.get("message", "")))


func _layout() -> void:
	if not is_instance_valid(safe_ui):
		return
	RUNTIME.safe_area(self, safe_ui)
	var size: Vector2 = safe_ui.size
	var portrait := size.y > size.x
	var margin := 12.0
	exit_button.size = Vector2(maxf(80, exit_button.get_combined_minimum_size().x), maxf(50, exit_button.get_combined_minimum_size().y))
	map_button.size = Vector2(maxf(104, map_button.get_combined_minimum_size().x), maxf(50, map_button.get_combined_minimum_size().y))
	exit_button.position = Vector2(size.x - exit_button.size.x - margin, margin)
	map_button.position = Vector2(exit_button.position.x - map_button.size.x - margin, margin)
	var mission_width := maxf(48, size.x - margin * 2)
	if not portrait:
		mission_width = minf(610, maxf(48, map_button.position.x - margin * 2))
	mission_panel.position = Vector2(margin, margin)
	mission_panel.size = Vector2(mission_width, maxf(138 if portrait else 110, mission_panel.get_combined_minimum_size().y))
	if portrait:
		var top_actions_y := mission_panel.position.y + mission_panel.size.y + 6
		exit_button.position.y = top_actions_y
		map_button.position.y = top_actions_y
	var buttons: Array[Button] = [action_button, vehicle_button, run_button]
	var heights := [54.0, 50.0, 50.0]
	var button_width := 132.0
	for button in buttons:
		button_width = maxf(button_width, ceilf(button.get_combined_minimum_size().x))
	var stick_space := maxf(48, size.x - button_width - margin * 3)
	var stick_size := minf(clampf(minf(size.x * 0.39, size.y * 0.44), 120, 180), stick_space)
	# This shared Kart control starts with a 188px minimum. Adapt only this
	# World instance so its real touch rectangle fits beside the action column.
	joystick.custom_minimum_size = Vector2.ONE * 48
	joystick.size = Vector2.ONE * stick_size
	joystick.position = Vector2(margin, size.y - joystick.size.y - margin)
	var button_bottom := size.y - 14
	for index in range(buttons.size() - 1, -1, -1):
		var button: Button = buttons[index]
		button.size = Vector2(button_width, maxf(heights[index], button.get_combined_minimum_size().y))
		button.position = Vector2(size.x - button.size.x - margin, button_bottom - button.size.y)
		button_bottom = button.position.y - 6
	var status_y := map_button.position.y + maxf(map_button.size.y, exit_button.size.y) + 12 if portrait else mission_panel.position.y + mission_panel.size.y + 8
	status_label.position = Vector2(margin, status_y)
	status_label.size = Vector2(size.x - 24, 70)
	if size.y < 420:
		status_label.position = Vector2(stick_size + 24, size.y - 82)
		status_label.size = Vector2(maxf(120, size.x - stick_size - button_width - 60), 70)
		status_label.add_theme_font_size_override("font_size", 14)
	else:
		status_label.add_theme_font_size_override("font_size", 16)
	_layout_modal()


func _layout_modal() -> void:
	if not is_instance_valid(modal) or not modal.visible:
		return
	var area: Vector2 = safe_ui.size
	modal.size = Vector2(minf(580, area.x - 28), minf(580, area.y - 36))
	modal.position = (area - modal.size) * 0.5
	modal_box.custom_minimum_size.x = maxf(160, modal.size.x - 42)


func _physics_process(delta: float) -> void:
	if paused:
		return
	time += delta
	var axis: Vector2 = joystick.axis + Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	axis = axis.limit_length(1.0)
	_traffic_tick(delta)
	if driving:
		_drive_tick(axis, delta)
	else:
		_walk_tick(axis, delta)
	_update_camera(delta)
	var at := _active_position()
	ADVENTURE.set_focus(at + Vector3.UP * 1.5)
	var mission: Dictionary = model.current()
	if not mission.is_empty():
		marker.position = mission.at + Vector3.UP * (3.5 + (0.0 if reduced_motion else sin(time * 2.0) * 0.18))
		marker.rotate_y(0.0 if reduced_motion else delta)
		wonder.set_routes(at, [mission])
	var portal := _near_portal()
	var friend_available: bool = friend_post.available(at)
	var crossing_available := _near_crossing_button(at)
	action_button.disabled = driving or (not model.near_current(at) and portal.is_empty() and not friend_available and not crossing_available)
	if crossing_available or str(mission.get("id", "")) == "safe_crossing":
		action_button.text = "Ampelknopf"
	elif str(mission.get("id", "")) == "school_numbers":
		action_button.text = "Zur Schule"
	else:
		action_button.text = "Ansprechen"
	if not model.near_current(at) and not crossing_available:
		if friend_available:
			action_button.text = "Freundepost"
		elif not portal.is_empty():
			action_button.text = "Ort öffnen"
	vehicle_button.disabled = not driving and player.position.distance_to(kart_body.position) > 5.0
	if model.observe_crossing(player.position, signal_green, not driving):
		_completed_step("Du hast auf Grün und den Verkehr geachtet. Jetzt geht es zur Schule!")
	for friend in residents:
		if friend.position.distance_to(at) < 12.0:
			var toward := at - friend.position
			if Vector2(toward.x, toward.z).length() > 0.3:
				friend.rotation.y = lerp_angle(friend.rotation.y, atan2(toward.x, toward.z), 1.0 - exp(-3.0 * delta))
	own_village.update_focus(at, delta)
	save_clock += delta
	if save_clock > 4.0:
		save_clock = 0.0
		if save_pending or at.distance_to(last_saved) > 0.8:
			_save()


func _walk_tick(axis: Vector2, delta: float) -> void:
	var speed := 7.2 if walking_fast or Input.is_physical_key_pressed(KEY_SHIFT) else 4.2
	var target := Vector3(axis.x, 0, axis.y) * speed
	# Exponential turning and distinct acceleration/deceleration avoid abrupt
	# walk/run changes; the rig consumes actual post-collision velocity.
	var acceleration := 16.0 if target.length_squared() > 0.02 else 23.0
	player.velocity.x = move_toward(player.velocity.x, target.x, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, acceleration * delta)
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.5
	var old_position := player.position
	player.move_and_slide()
	var entering_from_south := old_position.z >= 4.6 and player.position.z < 4.6
	var entering_from_north := old_position.z <= -4.6 and player.position.z > -4.6
	if absf(player.position.x - 110.0) < 2.4 and (entering_from_south or entering_from_north) and not signal_green:
		player.position.z = 4.6 if entering_from_south else -4.6
		player.velocity.z = 0
		status_label.text = "Die Ampel ist rot. Bleib am Rand und drücke den Ampelknopf."
	if player.is_on_floor() and absf(player.position.z) > 6.0:
		last_safe = player.position
	if player.position.y < -6.0:
		player.position = last_safe + Vector3.UP * 0.2
		player.velocity = Vector3.ZERO
		status_label.text = "Hier ist Wasser. Über die Brücke kommst du sicher weiter."
	_clamp_body(player)
	var motion := Vector2(player.velocity.x, player.velocity.z)
	if motion.length() > 0.12:
		fox.rotation.y = lerp_angle(fox.rotation.y, atan2(-motion.x, -motion.y), 1.0 - exp(-10.0 * delta))
	# Match the proven Treasure-world locomotion feed: CharacterBody3D.velocity
	# remains stable across floor snap and collision correction, so the skeleton
	# cannot lose its walk cycle while the body still translates.
	fox.drive(player.velocity, player.is_on_floor(), delta, time)


func _drive_tick(axis: Vector2, delta: float) -> void:
	var throttle := -axis.y
	var target_speed := throttle * (10.0 if throttle >= 0.0 else 3.0)
	drive_speed = move_toward(drive_speed, target_speed, (8.0 if absf(target_speed) < absf(drive_speed) else 4.0) * delta)
	if absf(drive_speed) > 0.1:
		kart_body.rotation.y -= axis.x * clampf(drive_speed / 5.0, -1.0, 1.0) * 1.7 * delta
	var forward := -kart_body.global_basis.z
	kart_body.velocity.x = forward.x * drive_speed
	kart_body.velocity.z = forward.z * drive_speed
	kart_body.velocity.y = -0.5 if kart_body.is_on_floor() else kart_body.velocity.y - 22 * delta
	kart_body.move_and_slide()
	if kart_body.get_slide_collision_count() > 0:
		for index in range(kart_body.get_slide_collision_count()):
			if absf(kart_body.get_slide_collision(index).get_normal().y) < 0.5:
				drive_speed *= 0.2
	if kart_body.position.y < -6.0:
		kart_body.position = Vector3(77, 0.2, 18)
		drive_speed = 0.0
		status_label.text = "Zurück am sicheren Parkplatz. Bleib mit dem Kart auf den Wegen."
	_clamp_body(kart_body)
	kart_visual.set_motion(drive_speed, axis.x, false, false)


func _clamp_body(body: CharacterBody3D) -> void:
	body.position.x = clampf(body.position.x, STATE.BOUNDS.position.x + 0.6, STATE.BOUNDS.end.x - 0.6)
	body.position.z = clampf(body.position.z, STATE.BOUNDS.position.y + 0.6, STATE.BOUNDS.end.y - 0.6)


func _active_position() -> Vector3:
	return kart_body.position if driving else player.position


func _update_camera(delta: float) -> void:
	var at := _active_position()
	var portrait := get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x
	var scale_factor := 1.3 if portrait else 1.0
	var offset := Vector3(4.6, 5.0, 10.0) * scale_factor
	if driving:
		offset = kart_body.global_basis * Vector3(0, 5.0, 10.5) * scale_factor
	var focus := at + Vector3.UP * (1.3 if driving else 1.6)
	var desired := at + offset
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1, [player.get_rid(), kart_body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.35
	camera.position = camera.position.lerp(desired, 1.0 - exp(-5.2 * delta))
	if camera.position.distance_to(focus) > 0.2:
		camera.look_at(focus, Vector3.UP)
	camera_clearance.update(camera, focus, kart_body.get_instance_id() if driving else player.get_instance_id(), delta)


func _traffic_tick(delta: float) -> void:
	var crossing_clear := true
	for entry in traffic:
		if absf(entry.node.position.x - 110.0) < 7.5:
			crossing_clear = false
	if signal_requested and not signal_green and crossing_clear:
		signal_clock += delta
		if signal_clock >= 1.5:
			signal_green = true
			signal_clock = 12.0
			status_label.text = "Grün für dich. Schau auf den Verkehr und gehe über den Zebrastreifen."
	elif signal_green:
		signal_clock -= delta
		if signal_clock <= 0 and not (absf(player.position.x - 110) < 3.0 and absf(player.position.z) < 5.5):
			signal_green = false
			signal_requested = false
			signal_clock = 0.0
	for entry in traffic:
		var vehicle: Node3D = entry.node
		var direction: float = entry.direction
		var target: float = entry.cruise
		var stop_x := 99.0 if direction > 0 else 121.0
		var distance_to_stop := (stop_x - vehicle.position.x) * direction
		if signal_requested and distance_to_stop >= 0.0 and distance_to_stop < 24.0:
			target = minf(target, maxf(0.0, distance_to_stop - 0.5) * 1.2)
		var at := _active_position()
		var ahead := (at.x - vehicle.position.x) * direction
		if absf(at.z - vehicle.position.z) < 3.0 and ahead > -1.0 and ahead < 10.0:
			target = minf(target, maxf(0.0, ahead - 4.5))
		for other in traffic:
			if other == entry or other.direction != direction:
				continue
			var gap: float = (other.node.position.x - vehicle.position.x) * direction
			if gap > 0 and gap < 11.0:
				target = minf(target, maxf(0.0, gap - 7.5))
		entry.speed = move_toward(float(entry.speed), target, delta * 7.0)
		vehicle.position.x += direction * float(entry.speed) * delta
		if vehicle.position.x > 273:
			vehicle.position.x = 68
		elif vehicle.position.x < 68:
			vehicle.position.x = 273
	for lights in signal_lights:
		lights.red.material_override = kit.material(Color("3e3536") if signal_green else Color("fa6b6a"), not signal_green)
		lights.green.material_override = kit.material(Color("8cff8f") if signal_green else Color("344d42"), signal_green)


func _toggle_run() -> void:
	if driving:
		drive_speed = 0.0
		return
	walking_fast = not walking_fast
	run_button.text = "Rennen" if walking_fast else "Gehen"


func _toggle_vehicle() -> void:
	if paused:
		return
	if driving:
		if absf(drive_speed) > 0.75:
			status_label.text = "Halte zuerst an. Mit der Bremse kommst du ruhig zum Stehen."
			return
		var exit_at := kart_body.position + kart_body.global_basis.x * 2.2
		if absf(exit_at.z) < 7.0 and exit_at.x > 65.0:
			exit_at.z = 7.5 if exit_at.z >= 0 else -7.5
		player.position = exit_at + Vector3.UP * 0.2
		player_shape.set_deferred("disabled", false)
		fox.show()
		fox.set_suspended(false)
		driving = false
		drive_speed = 0.0
		_set_kart_driver(false)
		vehicle_button.text = "Ins Kart"
		run_button.text = "Rennen" if walking_fast else "Gehen"
		status_label.text = "Wieder zu Fuß. Mit Ansprechen redest du mit deinen Freunden."
	else:
		if player.position.distance_to(kart_body.position) > 5.0:
			return
		driving = true
		player.velocity = Vector3.ZERO
		player_shape.set_deferred("disabled", true)
		fox.hide()
		fox.set_suspended(true)
		_set_kart_driver(true)
		vehicle_button.text = "Aussteigen"
		run_button.text = "Bremse"
		status_label.text = "Dein Kart: Stick vor zum Fahren, seitlich zum Lenken. Langsam und rücksichtsvoll."
	_save()


func _open_dialog(title: String, body: String) -> void:
	paused = true
	joystick.set_enabled(false)
	wonder.set_paused(true)
	fox.set_suspended(true)
	kart_visual.set_driver_runtime_state(false, false, true)
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()
	var heading := KIT.label(title, 25)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(heading)
	var copy := KIT.label(body, 19)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(copy)
	modal.show()
	modal_scroll.scroll_vertical = 0
	_layout_modal.call_deferred()


func _close_dialog() -> void:
	paused = false
	modal.hide()
	joystick.set_enabled(true)
	wonder.set_paused(false)
	fox.set_suspended(driving)
	kart_visual.set_driver_runtime_state(false, false, not driving)


func _near_crossing_button(at: Vector3) -> bool:
	if not is_finite(at.x) or not is_finite(at.y) or not is_finite(at.z):
		return false
	return at.distance_to(Vector3(110, 0, 7)) <= 3.2 or at.distance_to(Vector3(110, 0, -7)) <= 3.2


func _request_crossing() -> void:
	if driving or save_blocked or not _near_crossing_button(player.position):
		return
	if not signal_requested and not signal_green:
		signal_clock = 0.0
	signal_requested = true
	status_label.text = "Grün für dich. Schau auf den Verkehr und gehe über den Zebrastreifen." if signal_green else "Die Ampel hat deinen Wunsch gespeichert. Warte am Rand, bis es Grün wird."


func _interact() -> void:
	if paused or driving or save_blocked:
		return
	if _near_crossing_button(player.position):
		_request_crossing()
		return
	if not model.near_current(player.position):
		if friend_post.interact(player.position):
			return
		var portal := _near_portal()
		if not portal.is_empty():
			_open_dialog(str(portal.title), str(portal.description))
			modal_box.add_child(KIT.button("Hineingehen", _launch_portal.bind(str(portal.game)), 160, Color("1b7d63")))
			modal_box.add_child(KIT.button("Weiter erkunden", _close_dialog, 160))
		return
	var mission: Dictionary = model.current()
	match str(mission.get("kind", "")):
		"talk":
			_open_dialog("Nelli · Willkommen im Sonnendorf", "Du bist von der Schatzinsel herübergekommen! Ich wohne im Haus mit dem warmen Dach. Heute planen wir einen Garten. Kommst du mit zur Schule?")
			modal_box.add_child(KIT.button("Ja, ich helfe mit", _meet_nelli, 180, Color("1b7d63")))
		"crossing":
			_request_crossing()
			return
		"lesson":
			_open_dialog("Lumo geht zur Schule", "Wir brauchen einen Plan für Brunos Garten. Eine Mathe-Lernrunde in deiner Schulstufe hilft euch dabei. Danach geht dein Abenteuer genau hier weiter.")
			modal_box.add_child(KIT.button("Lernrunde beginnen", _start_school, 180, Color("1b7d63")))
		_:
			var question: Dictionary = model.task(grade)
			if question.is_empty():
				return
			_open_dialog(str(mission.title), str(question.question))
			for index in range(question.choices.size()):
				modal_box.add_child(KIT.button(str(question.choices[index]), _answer.bind(index), 160))
	modal_box.add_child(KIT.button("Noch etwas erkunden", _close_dialog, 160))


func _meet_nelli() -> void:
	if model.meet_friend(player.position):
		_close_dialog()
		_completed_step("Nelli freut sich. Der Stern zeigt dir den sicheren Schulweg.")


func _start_school() -> void:
	var request: Dictionary = model.begin_school_request(HostBridge.new_result_id(), grade, player.position)
	if request.is_empty() or not _save():
		status_label.text = "Die Lernrunde konnte noch nicht gespeichert werden. Bitte versuche es erneut."
		return
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app("learn", {"worldMission": request}):
			status_label.text = "Die Schule ist bereit. Der Wechsel zur Lernrunde hat noch nicht geklappt."
		return
	lesson_index = 0
	lesson_answers = 0
	_show_standalone_lesson()


func _show_standalone_lesson() -> void:
	var sets := [
		[[3, 2], [4, 3], [5, 4]], [[12, 8], [27, 5], [36, 14]],
		[[124, 35], [278, 112], [416, 84]], [[1250, 750], [2480, 520], [3760, 1240]]
	]
	var terms: Array = sets[grade - 1][lesson_index]
	_open_dialog("Schule · Aufgabe %d von 3" % (lesson_index + 1), "Wie viel ist %d + %d?" % [terms[0], terms[1]])
	var answer: int = int(terms[0]) + int(terms[1])
	for value in [answer - 1, answer, answer + 1]:
		modal_box.add_child(KIT.button(str(value), _standalone_answer.bind(int(value), answer), 160))
	modal_box.add_child(KIT.button("Später weitermachen", _close_dialog, 160))


func _standalone_answer(value: int, expected: int) -> void:
	if value != expected:
		status_label.text = "Zerlege die Zahlen in passende Teile und rechne noch einmal in Ruhe."
		return
	lesson_answers += 1
	lesson_index += 1
	if lesson_index < 3:
		_show_standalone_lesson()
		return
	var receipt := {"version": 1, "requestId": str(model.pending_lesson.get("requestId", "")), "missionId": "school_numbers", "completed": lesson_answers == 3, "subject": "Mathematik", "grade": grade, "returnGame": "world"}
	if model.consume_learning_receipt(receipt):
		_close_dialog()
		_completed_step("Deine drei Aufgaben sind gelöst. Jetzt kannst du Bruno im Garten helfen.")


func _answer(choice: int) -> void:
	var question: Dictionary = model.task(grade)
	if not model.answer(choice, grade, player.position):
		status_label.text = "Schau noch einmal auf den Auftrag. Du kannst ohne Zeitdruck weiterdenken."
		return
	_close_dialog()
	_completed_step(str(question.explanation))


func _completed_step(message: String) -> void:
	var saved := _save()
	_update_mission()
	status_label.text = message if saved else "Auftrag geschafft. Speichern ist noch nicht möglich; bitte bleibe im Abenteuer."
	fox.gesture("celebrate")
	wonder.celebrate(player.position + Vector3.UP * 1.6)
	if model.is_complete() and saved:
		var accepted := _report_completed_reward()
		_open_dialog("Eine Welt voller Freunde", "Du hast Nelli kennengelernt, den Schulweg geübt, gelernt und deinen Freunden geholfen. Jetzt kannst du frei weiter erkunden. Nelli hat neue Freundepost für dich: Besuche sie vor ihrem Haus und entdecke drei Lieferaufträge. Deine Welt bleibt gespeichert.")
		if not accepted:
			status_label.text = "Dein Abenteuer ist geschafft. Die Belohnung wird beim nächsten Wechsel erneut gespeichert."
		modal_box.add_child(KIT.star_row(3))
		modal_box.add_child(KIT.button("Welt weiter erkunden", _close_dialog, 180, Color("1b7d63")))


func _report_completed_reward() -> bool:
	if save_blocked or not model.is_complete():
		return false
	return HostBridge.reward({"resultId": model.result_id, "game": "world", "status": "completed", "stars": 3, "xp": 42})


func _update_mission() -> void:
	var mission: Dictionary = model.current()
	marker.visible = not mission.is_empty()
	mission_label.text = "LUMO WORLD · %d / %d Aufträge\n%s\n%s" % [model.completed.size(), STATE.MISSIONS.size(), str(mission.get("title", "Deine Welt voller Freunde")), str(mission.get("lead", "Schatzinsel, Sonnendorf und Sternenstadt stehen dir offen."))]
	if mission.is_empty():
		wonder.set_routes(_active_position(), [])
		var post_briefing: String = friend_post.briefing()
		if not post_briefing.is_empty():
			mission_label.text = post_briefing


func _map_dialog() -> void:
	_open_dialog("Deine Lumo World", "Von der Schatzinsel führt die Brücke ins Sonnendorf, weiter nach Sternenstadt und zu deinem eigenen, bereits aufgebauten Dorf. Kart, Kartensalon und Dorfstrategie öffnen sich direkt an ihren Orten.")
	overview = WORLD_MAP.new()
	var map_mission: Dictionary = model.current()
	if map_mission.is_empty():
		# The delivery address is revealed only when the child requests help.
		map_mission = friend_post.guidance()
	overview.configure(STATE.BOUNDS, _active_position(), kart_body.rotation.y if driving else fox.rotation.y, map_mission, model.completed, STATE.MISSIONS, portals, reduced_motion)
	if friend_post.unlocked() and friend_post.model.carrying() and map_mission.is_empty():
		overview.set_objective_note("Freundepost: Lies deinen Hinweis und finde den richtigen Freund. Du kannst dir auch das Ziel zeigen lassen.")
	modal_box.add_child(overview)
	if friend_post.unlocked() and not friend_post.model.is_complete():
		var clue := KIT.label(friend_post.model.clue(grade) if friend_post.model.carrying() else friend_post.briefing(), 18)
		clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_box.add_child(clue)
		if friend_post.model.carrying() and map_mission.is_empty():
			modal_box.add_child(KIT.button("Ziel zeigen lassen", friend_post._show_destination, 180))
	modal_box.add_child(KIT.label("Gehen: Stick oder Pfeiltasten · Rennen: Umschalten\nKart: Zum Parkplatz gehen und einsteigen", 16))
	var village_summary := KIT.label(own_village.summary(), 16)
	village_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(village_summary)
	modal_box.add_child(KIT.button("Weiter erkunden", _close_dialog, 160))


func _pause_menu() -> void:
	if paused:
		_close_dialog()
		return
	_save()
	_open_dialog("Deine Welt wartet auf dich", "Deine Aufträge und dein Platz bleiben gespeichert. Du kannst in Ruhe weiter erkunden oder zur Spielewelt zurückgehen.")
	modal_box.add_child(KIT.button("Weiter erkunden", _close_dialog, 160, Color("1b7d63")))
	modal_box.add_child(KIT.button("Zur Spielewelt", _leave, 160))


func _save() -> bool:
	if save_blocked or not is_instance_valid(player):
		return false
	save_pending = true
	var at := player.position
	if driving:
		at = kart_body.position + Vector3(0, 0.1, 6)
		at.x = clampf(at.x, STATE.BOUNDS.position.x + 1, STATE.BOUNDS.end.x - 1)
		at.z = clampf(at.z, STATE.BOUNDS.position.y + 1, STATE.BOUNDS.end.y - 1)
	if at.y < -0.5 or at.y > 180:
		at = last_safe
	model.position = at
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	var data: Dictionary = model.to_data()
	# Keep unreadable or future sidequest data unchanged in the original profile save.
	data["friendPost"] = friend_post.to_data() if friend_post.save_valid else friend_post_original
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		if is_instance_valid(status_label):
			status_label.text = "Speichern hat noch nicht geklappt. Dein Abenteuer bleibt geöffnet."
		return false
	last_saved = _active_position()
	save_pending = false
	return true


func _leave() -> void:
	if save_blocked or _save():
		SceneRouter.goto("games")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST] and is_instance_valid(player):
		_save()
		if not paused:
			_pause_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_menu()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_F:
			_toggle_vehicle()
		elif event.keycode == KEY_M:
			_map_dialog()
