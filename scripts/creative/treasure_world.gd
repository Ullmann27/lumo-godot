extends Node3D
const STATE = preload("res://scripts/creative/treasure_state.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const LUMO = preload("res://scripts/characters/lumo/lumo_world_avatar.gd")
const STICK = preload("res://scripts/games/kart_joystick.gd")
const ACTION = preload("res://scripts/games/kart_touch_action.gd")
const CHEST_MODEL = preload("res://assets/creative/models/lumo_treasure_chest.glb")
const ISLAND_ART = preload("res://scripts/creative/treasure_island_art.gd")
const WISPS = preload("res://scripts/creative/treasure_wisps.gd")
const NATURE = preload("res://scripts/creative/treasure_island_nature.gd")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")
const WILDLIFE = preload("res://scripts/creative/treasure_wildlife.gd")
const LANTERN_MODEL = preload("res://assets/creative/models/lumo_lantern.glb")
const CAMERA_OFFSET := Vector3(3.9, 4.4, 8.6)
const CAMERA_LOOK_OFFSET := Vector3(0.0, 1.7, -2.6)
const LUMO_HEIGHT := 3.0
var model = STATE.new()
var kit = KIT.new()
var previous: Dictionary
var safe_ui: Control
var top: HBoxContainer
var title_label: Label
var clue_panel: PanelContainer
var clue_button: Button
var jump_button: Button
var player: CharacterBody3D
var fox: Node3D
var camera: Camera3D
var marker: MeshInstance3D
var alternate_marker: MeshInstance3D
var wonder: Node3D
var available_goals: Array[Dictionary] = []
var gate: StaticBody3D
var joystick: Control
var action: Control
var inventory_label: Label
var clue_label: Label
var toast: Label
var modal: PanelContainer
var modal_scroll: ScrollContainer
var modal_box: VBoxContainer
var paused: bool = false
var jumping: bool = false
var time: float = 0
var save_clock: float = 0
var save_path: String
var last_saved: Vector3
var hunt_map: Control
var fanfare: GPUParticles3D
var discovery_beacons: Dictionary = {}
var wildlife: Node3D
var find_focus := 0.0
var find_beam: MeshInstance3D
var find_light: OmniLight3D


## Im Hochformat rückt die Kamera weiter zurück: sonst steht der nahe Lumo unten
## im Bild genau dort, wo die Meldungszeile liegt.
const PORTRAIT_CAMERA_SCALE := 1.45


## Im Hochformat zielt die Kamera näher auf Lumo; er rückt damit zur Bildmitte.
const PORTRAIT_LOOK_OFFSET := Vector3(0.0, 1.0, -1.2)


func _portrait() -> bool:
	var view := get_viewport().get_visible_rect().size
	return view.y > view.x


func _camera_offset() -> Vector3:
	return CAMERA_OFFSET * (PORTRAIT_CAMERA_SCALE if _portrait() else 1.0)


func _camera_look_offset() -> Vector3:
	return PORTRAIT_LOOK_OFFSET if _portrait() else CAMERA_LOOK_OFFSET


func _ready() -> void:
	previous = RUNTIME.enter(self, true)
	SceneRouter.current_scene_id = "treasure"
	var child: String = (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	save_path = "user://lumo_treasure_" + child + ".json"
	if FileAccess.file_exists(save_path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:
			model.restore(saved)
	if model.result_id.is_empty():
		model.result_id = HostBridge.new_result_id()
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_TREASURE_DAY)
	_landscape()
	player = CharacterBody3D.new()
	player.name = "LumoExplorer"
	add_child(player)
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	capsule.shape = shape
	capsule.position.y = 0.8
	player.add_child(capsule)
	# Der echte, geriggte Lumo; der Knoten "fox" bleibt nur Dreh-/Haltepunkt.
	fox = LUMO.new()
	fox.name = "Lumo"
	player.add_child(fox)
	fox.setup(LUMO_HEIGHT, bool(SceneRouter.launch_options.get("reduceAnimations", false)))
	player.position = model.position
	last_saved = model.position
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 55
	camera.current = true
	camera.position = player.position + _camera_offset()
	camera.look_at(player.position + _camera_look_offset(), Vector3.UP)
	marker = kit.mesh(self, kit.SHAPES.star(), Vector3.ZERO, Color("ffe7a1"), true)
	marker.scale = Vector3.ONE * 0.65
	alternate_marker = kit.mesh(self, kit.SHAPES.star(), Vector3.ZERO, Color("9de9ff"), true)
	alternate_marker.name = "AlternateExplorationGoal"
	alternate_marker.scale = Vector3.ONE * 0.65
	alternate_marker.hide()
	wonder = WISPS.new()
	wonder.name = "MagicalGuidance"
	wonder.set_reduced_motion(bool(SceneRouter.launch_options.get("reduceAnimations", false)))
	add_child(wonder)
	_ui()
	get_viewport().size_changed.connect(_layout)
	RUNTIME.watch_safe_area(self, _layout)
	_layout()
	_update()
	if model.completed:
		_win()


func _exit_tree() -> void:
	ADVENTURE.set_focus(Vector3(0, -1000, 0))
	RUNTIME.unwatch_safe_area(self)
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	RUNTIME.restore(self, previous)


func _landscape() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var terrain := MeshInstance3D.new()
	terrain.name = "TreasureTerrain"
	terrain.mesh = NATURE.terrain_mesh()
	terrain.material_override = NATURE.terrain_material()
	terrain.extra_cull_margin = 80.0
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ground.add_child(terrain)
	kit.collision(ground, Vector3(0, -0.65, -29), Vector3(74, 1.3, 88))
	# Der durchgehende Pfad liegt jetzt als Erdweg im Gelände (Shader-Mischung);
	# Laternen aus dem Blender-Modell begleiten ihn wie bisher alle 8 m.
	for i in range(0, 39, 4):
		var z: float = 8 - i * 2
		for x in [-3.5, 3.5]:
			var lamp: Node3D = LANTERN_MODEL.instantiate()
			lamp.position = Vector3(x, 0, z)
			lamp.rotation.y = 0.0 if x < 0 else PI
			add_child(lamp)
	gate = StaticBody3D.new()
	add_child(gate)
	var door: MeshInstance3D = kit.box(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28), Color.WHITE)
	door.material_override = ADVENTURE.material("wood")
	var plank: MeshInstance3D = kit.box(gate, Vector3(-1.15, 1.75, -30.84), Vector3(1.7, 2.15, 0.08), Color("b88850"))
	plank.material_override = ADVENTURE.material("wood_dark")
	plank = kit.box(gate, Vector3(1.15, 1.75, -30.84), Vector3(1.7, 2.15, 0.08), Color("b88850"))
	plank.material_override = ADVENTURE.material("wood_dark")
	var band: MeshInstance3D = kit.box(gate, Vector3(0, 3.05, -30.84), Vector3(4.4, 0.2, 0.08), Color("d6b25a"))
	band.material_override = ADVENTURE.material("brass")
	kit.collision(gate, Vector3(0, 1.6, -31), Vector3(5, 3.2, 0.28))
	for x in [-3.45, 3.45]:
		var pillar: MeshInstance3D = kit.cylinder(self, Vector3(x, 2.15, -31), 0.62, 4.3, Color.WHITE)
		pillar.material_override = ADVENTURE.material("stone_block")
		var cap: MeshInstance3D = kit.sphere(self, Vector3(x, 4.55, -31), Vector3.ONE * 0.85, Color.WHITE)
		cap.material_override = ADVENTURE.material("stone_block")
	ADVENTURE.place(self, "GateArch", "ruins", "arch_gate", Transform3D(Basis.IDENTITY, Vector3(0, 0, -31)))
	ADVENTURE.place(self, "WelcomeArch", "ruins", "arch_welcome", Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.35)))
	var crystal_base: Array[Transform3D] = []
	for i in range(4):
		var crystal := kit.mesh(
			self, kit.SHAPES.crystal(), Vector3(-17.5 + i * 1.65, 1.2, -40.2), Color("7ee7ff"), true
		)
		crystal.scale = Vector3(1, 2.4, 1)
		crystal_base.append(ADVENTURE.xf(Vector3(-17.5 + i * 1.65, -0.15, -40.2), float(i) * 1.3, 0.42))
	ADVENTURE.scatter(self, "CrystalPlinths", "ruins", "rock_a", crystal_base, true)
	var chest: Node3D = CHEST_MODEL.instantiate()
	chest.name = "OriginalBlenderTreasureChest"
	chest.position = Vector3(0, 0, -65)
	add_child(chest)
	NATURE.apply(self)
	ISLAND_ART.apply(self)
	wildlife = WILDLIFE.new()
	wildlife.name = "TreasureWildlife"
	wildlife.reduced_motion = bool(SceneRouter.launch_options.get("reduceAnimations", false))
	add_child(wildlife)
	_branch_trails()
	_place_discovery_beacons()
	_make_fanfare()


func _branch_trails() -> void:
	# Both paths are part of the playable terrain and lead to independently
	# answerable locations after the bridge. Shared meshes keep their cost low.
	var paths := Node3D.new()
	paths.name = "TreasureBranchPaths"
	add_child(paths)
	var pavers := BoxMesh.new()
	pavers.size = Vector3.ONE
	for route in [
		{"index": 3, "start": Vector3(-2, 0, -33), "sign": Vector3(-6.0, 0, -34.0), "text": "← Kristallwächter", "color": Color("85dce5")},
		{"index": 4, "start": Vector3(2, 0, -33), "sign": Vector3(6.0, 0, -34.0), "text": "Mondgarten →", "color": Color("d7bc80")}
	]:
		var target: Vector3 = STATE.CLUES[int(route.index)].at
		var start: Vector3 = route.start
		var direction := (target - start).normalized()
		var distance := start.distance_to(target)
		var count := ceili(distance / 1.2)
		# Trittsteine auf dem Erdweg (flach gedrückte Blender-Felsen), Farbe der Route.
		var tiles: Array[Transform3D] = []
		var yaw := atan2(direction.x, direction.z)
		for i in range(count):
			var wobble := Vector3(sin(float(i) * 2.3) * 0.35, 0.0, 0.0).rotated(Vector3.UP, yaw)
			var basis := Basis(Vector3.UP, yaw + float(i) * 0.9) * Basis.from_scale(Vector3(0.62, 0.07, 0.5))
			tiles.append(Transform3D(basis, start.lerp(target, (i + 0.5) / count) + wobble + Vector3.UP * 0.02))
		var stones := ADVENTURE.scatter(paths, "Path_" + str(STATE.CLUES[int(route.index)].id), "ruins", "rock_b", tiles, false)
		if stones == null:
			BuildVoxelStyle.multimesh(paths, "Path_" + str(STATE.CLUES[int(route.index)].id), pavers, BuildVoxelStyle.material("paving", route.color), tiles)
		var sign_at: Vector3 = route.sign
		var post: MeshInstance3D = kit.box(paths, sign_at + Vector3.UP * 0.9, Vector3(0.18, 1.8, 0.18), Color("775d40"))
		post.material_override = ADVENTURE.material("wood")
		var board: MeshInstance3D = kit.box(paths, sign_at + Vector3.UP * 1.9, Vector3(4.6, 0.9, 0.16), Color("283b43"))
		board.material_override = ADVENTURE.material("wood_dark")
		var label := Label3D.new()
		label.name = "RouteSign_" + str(STATE.CLUES[int(route.index)].id)
		label.text = route.text
		label.font = preload("res://assets/fonts/Nunito-Black.ttf")
		label.font_size = 38
		label.pixel_size = 0.01
		label.modulate = route.color
		label.outline_size = 12
		label.outline_modulate = Color(0.08, 0.06, 0.04, 0.95)
		label.position = sign_at + Vector3(0, 1.9, 0.10)
		paths.add_child(label)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	top = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_top = 12
	top.offset_right = -14
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	title_label = KIT.label("LUMOS STERNENSCHATZ", 24)
	# Bright clouds can sit directly behind the white title after restoring a
	# saved position. Keep the original caption legible against every view.
	var title_backdrop := KIT.panel()
	title_backdrop.set_content_margin_all(4)
	title_label.add_theme_stylebox_override("normal", title_backdrop)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title_label)
	top.add_child(KIT.button("Rucksack", _inventory))
	top.add_child(KIT.button("Ⅱ", _pause_menu, 52))
	clue_panel = PanelContainer.new()
	clue_panel.add_theme_stylebox_override("panel", KIT.panel())
	safe_ui.add_child(clue_panel)
	clue_label = KIT.label("", 18)
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue_panel.add_child(clue_label)
	clue_button = KIT.button("Hinweis", _show_clue, 110)
	safe_ui.add_child(clue_button)
	toast = KIT.label("Erkunde die Insel. Folge dem goldenen Stern!", 17)
	var toast_backdrop := KIT.panel()
	toast_backdrop.set_content_margin_all(8)
	toast.add_theme_stylebox_override("normal", toast_backdrop)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	safe_ui.add_child(toast)
	toast.minimum_size_changed.connect(func(): _layout.call_deferred())
	hunt_map = Control.new()
	hunt_map.name = "TreasureHuntMap"
	hunt_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hunt_map.draw.connect(_draw_hunt_map)
	hunt_map.resized.connect(hunt_map.queue_redraw)
	safe_ui.add_child(hunt_map)
	joystick = STICK.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(20, -208)
	joystick.size = Vector2(188, 188)
	joystick.tooltip_text = "Bewegen: Stick, Pfeiltasten oder WASD."
	safe_ui.add_child(joystick)
	action = ACTION.new()
	action.text = "ANSEHEN"
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.position = Vector2(-180, -190)
	action.size = Vector2(152, 152)
	action.pressed.connect(_interact)
	safe_ui.add_child(action)
	jump_button = KIT.button("Springen", _jump, 110)
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	safe_ui.add_child(jump_button)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", KIT.panel())
	safe_ui.add_child(modal)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(modal_scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 12)
	modal_scroll.add_child(modal_box)
	modal_box.minimum_size_changed.connect(func(): _layout_modal.call_deferred())
	modal.hide()


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(modal):
		return
	RUNTIME.safe_area(self, safe_ui)
	var available := safe_ui.size
	if available.x <= 0 or available.y <= 0:
		return
	var short_landscape := available.y < 480 and available.x >= 600
	var stick_side := minf(188, minf(available.x * 0.38, available.y * 0.38))
	stick_side = maxf(120, stick_side)
	var action_side := minf(152, minf(available.x * 0.32, available.y * 0.30))
	action_side = maxf(96, action_side)
	joystick.custom_minimum_size = Vector2.ONE * stick_side
	joystick.size = Vector2.ONE * stick_side
	joystick.position = Vector2(16, available.y - 16 - stick_side)
	action.size = Vector2.ONE * action_side
	action.position = Vector2(available.x - 16 - action_side, available.y - 16 - action_side)
	jump_button.size = Vector2(110, 48)
	jump_button.position = Vector2(available.x - 126, available.y - 76 - action_side)
	var map_side := 168.0 if not short_landscape else 112.0
	map_side = minf(map_side, maxf(96.0, available.x * 0.28))
	if is_instance_valid(hunt_map):
		hunt_map.size = Vector2.ONE * map_side
		var map_top := 76.0 if not short_landscape else maxf(68.0, top.position.y + maxf(48.0, top.size.y) + 8.0)
		hunt_map.position = Vector2(available.x - 14.0 - map_side, map_top)
		hunt_map.queue_redraw()
	var clue_width := minf(380, available.x - 28)
	if is_instance_valid(hunt_map):
		clue_width = minf(clue_width, hunt_map.position.x - 26.0)
	if short_landscape:
		clue_width = minf(clue_width, available.x * 0.53)
	clue_panel.position = Vector2(14, 76)
	clue_panel.size = Vector2(maxf(160, clue_width), 0)
	# A full quest card covers the avatar in a short landscape view. Keep the
	# same complete text behind a real 48dp control instead of shrinking it.
	clue_panel.visible = not short_landscape
	clue_button.visible = short_landscape
	title_label.add_theme_font_size_override("font_size", 19 if available.x < 600 else 24)
	var toast_font_size := 15 if short_landscape else 17
	if toast.get_theme_font_size("font_size") != toast_font_size:
		toast.add_theme_font_size_override("font_size", toast_font_size)
	if short_landscape:
		var info_top := maxf(68, top.position.y + maxf(48, top.size.y) + 8)
		clue_button.position = Vector2(14, info_top)
		clue_button.size = Vector2(110, 48)
		toast.position = Vector2(136, info_top)
		toast.size = Vector2(available.x - 150, 48)
	else:
		var width := minf(560, available.x - 28)
		var gap_left := joystick.position.x + stick_side + 12
		var gap_right := action.position.x - 12
		if gap_right - gap_left >= 360:
			# Wide/tall views have room between the thumb controls. Keep the
			# message below the companion instead of across its lower body.
			width = minf(width, gap_right - gap_left)
			toast.size = Vector2(width, 48)
			toast.position = Vector2((gap_left + gap_right - width) * 0.5, available.y - 16 - toast.size.y)
		else:
			toast.size = Vector2(width, 0)
			var controls_top := minf(joystick.position.y, jump_button.position.y)
			var preferred_top := available.y - maxf(stick_side, action_side + 60) - 80
			toast.position = Vector2((available.x - width) * 0.5,
				minf(preferred_top, controls_top - toast.size.y - 12))
	_layout_modal()


func _show_clue() -> void:
	if paused:
		return
	_open_modal("Dein nächster Hinweis")
	var text := KIT.label(clue_label.text, 19)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(text)
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))


func _layout_modal() -> void:
	if not is_instance_valid(modal) or not modal.visible:
		return
	# The scroll viewport, not the content minimum, bounds every dialog.
	# Long inventories, questions and results retain full 48dp touch targets.
	for child in modal_box.get_children():
		if child is Label or child is Button:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.custom_minimum_size.x = 0 if child is Label else 48
			if child is Button:
				# A drag starting on an answer must reach the scroll container.
				child.mouse_filter = Control.MOUSE_FILTER_PASS
	var available := safe_ui.size
	var width := minf(560, available.x - 28)
	var height := minf(available.y - 28, maxf(120, modal_box.get_combined_minimum_size().y + 24))
	modal.size = Vector2(width, height)
	modal.position = (available - modal.size) * 0.5


func _physics_process(delta: float) -> void:
	if paused:
		return
	time += delta
	var axis: Vector2 = joystick.axis
	axis += Vector2(
		(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		),
		(
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		)
	)
	axis = axis.limit_length(1)
	player.velocity.x = move_toward(player.velocity.x, axis.x * 6, delta * 28)
	player.velocity.z = move_toward(player.velocity.z, axis.y * 6, delta * 28)
	if not player.is_on_floor():
		player.velocity.y -= delta * 22
	elif jumping:
		player.velocity.y = 8.5
		jumping = false
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -35, 35)
	player.position.z = clampf(player.position.z, -71, 13)
	if model.chapter < 3:
		player.position.z = maxf(player.position.z, -30)
	if axis.length() > 0.12:
		fox.rotation.y = lerp_angle(fox.rotation.y, atan2(-axis.x, -axis.y), delta * 10)
	fox.drive(player.velocity, player.is_on_floor(), delta, time)
	find_focus = move_toward(find_focus, 0.0, delta * 0.4)
	# Fundmoment: Kamera rückt kurz näher an den jubelnden Lumo.
	var focus := 1.0 - 0.16 * smoothstep(0.0, 0.35, find_focus)
	camera.position = camera.position.lerp(
		player.position + _camera_offset() * focus, minf(1, delta * 4)
	)
	camera.look_at(player.position + _camera_look_offset(), Vector3.UP)
	ADVENTURE.set_focus(player.position + Vector3.UP * 1.5)
	var found := model.try_discover(player.position)
	if not found.is_empty():
		toast.text = "Entdeckung: %s!" % found
		fox.gesture("greeting_wave")
		wonder.celebrate(player.position + Vector3.UP * 1.7)
		_update()
	if not available_goals.is_empty():
		marker.position = available_goals[0].at + Vector3.UP * (3.5 + sin(time * 2) * 0.2)
	marker.rotate_y(delta)
	if available_goals.size() > 1:
		alternate_marker.position = available_goals[1].at + Vector3.UP * (3.5 + sin(time * 2 + 1) * 0.2)
		alternate_marker.rotate_y(-delta)
	wonder.set_routes(player.position, available_goals)
	if is_instance_valid(hunt_map):
		hunt_map.queue_redraw()
	action.disabled = not model.can_interact(player.position)
	save_clock += delta
	if save_clock > 3:
		save_clock = 0
		if last_saved.distance_to(player.position) > 0.3:
			_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_menu()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_jump()
		if event.keycode == KEY_E:
			_interact()


func _jump() -> void:
	if not paused and player.is_on_floor():
		jumping = true


func _update() -> void:
	gate.visible = model.chapter < 3
	gate.process_mode = Node.PROCESS_MODE_INHERIT if gate.visible else Node.PROCESS_MODE_DISABLED
	for child in gate.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not gate.visible)
	marker.visible = not model.completed
	available_goals = model.available_clues()
	alternate_marker.visible = available_goals.size() > 1
	wonder.set_routes(player.position, available_goals)
	var lead: String = model.current().lead
	if available_goals.size() > 1:
		lead = "Wähle deinen Weg: Kristallwächter oder Mondgarten. Für das Schloss brauchst du beide Funde."
	clue_label.text = (
		"Hinweise gelöst: %d / %d · Entdeckungen %d / %d\n%s"
		% [
			model.found.size(),
			STATE.CLUES.size(),
			model.discoveries.size(),
			STATE.DISCOVERIES.size(),
			lead
		]
	)
	_refresh_discovery_beacons()
	if is_instance_valid(hunt_map):
		hunt_map.queue_redraw()
	_layout.call_deferred()


func _open_modal(title: String) -> void:
	paused = true
	wonder.set_paused(true)
	joystick.set_enabled(false)
	for child in modal_box.get_children():
		modal_box.remove_child(child)
		child.queue_free()
	modal.show()
	modal_box.add_child(KIT.label(title, 25))
	modal_scroll.scroll_vertical = 0
	_layout_modal.call_deferred()


func _close_modal() -> void:
	paused = false
	wonder.set_paused(false)
	modal.hide()
	joystick.set_enabled(true)


func _interact() -> void:
	if paused or not model.can_interact(player.position):
		return
	var clue: Dictionary = model.clue_at(player.position)
	_open_modal(clue.name)
	var text := KIT.label(clue.question, 19)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(text)
	for i in range(clue.answers.size()):
		modal_box.add_child(KIT.button(clue.answers[i], _answer.bind(i)))
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))


func _answer(choice: int) -> void:
	if not model.answer(choice, player.position):
		toast.text = "Schau noch einmal genau hin. Du kannst es wieder versuchen."
		return
	if not _save():
		toast.text = "Dein Fund ist da. Speichern war nicht möglich; bitte erneut speichern."
		_update()
		_close_modal()
		return
	_update()
	_close_modal()
	fox.gesture("celebrate")
	wonder.celebrate(player.position + Vector3.UP * 1.7)
	_play_fanfare(player.position + Vector3.UP * 1.4, false)
	_stage_find(player.position)
	toast.text = "Gefunden: " + model.inventory[-1] + "! Dein Rucksack wächst."
	if model.last_cheer == 3:
		toast.text = "Gefunden: %s! Super-Serie: 3 Hinweise hintereinander!" % model.inventory[-1]
	elif model.last_cheer == 7:
		toast.text = "Gefunden: %s! 7er-Serie! Du bist ein Schatz-Profi!" % model.inventory[-1]
	model.last_cheer = 0
	if model.completed:
		# Rebuild the dialog after the answer button's input dispatch finishes.
		# The completed progress was already saved above; reward rules stay intact.
		_win.call_deferred()


func _save() -> bool:
	model.position = player.position
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(model.to_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		toast.text = "Speichern fehlgeschlagen. Dein Abenteuer bleibt geöffnet."
		return false
	last_saved = player.position
	return true


func _inventory() -> void:
	_open_modal("Dein Abenteuer-Rucksack")
	modal_box.add_child(
		KIT.label(
			(
				"Noch leer – dein erster Hinweis wartet!"
				if model.inventory.is_empty()
				else "\n".join(model.inventory)
			),
			19
		)
	)
	if not model.discoveries.is_empty():
		var names: Array[String] = []
		for spot in STATE.DISCOVERIES:
			if str(spot.id) in model.discoveries:
				names.append(str(spot.name))
		modal_box.add_child(KIT.label("Entdeckungen: " + ", ".join(names), 17))
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))


func _pause_menu() -> void:
	if paused:
		_close_modal()
		return
	_save()
	_open_modal("Dein Abenteuer wartet")
	modal_box.add_child(KIT.button("Weiter erkunden", _close_modal))
	modal_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _win() -> void:
	if not _save():
		return
	var xp: int = model.reward_xp()
	HostBridge.reward(
		{
			"resultId": model.result_id,
			"game": "treasure",
			"status": "completed",
			"stars": 3,
			"xp": xp
		}
	)
	wonder.celebrate(Vector3(0, 2.2, -65))
	fox.gesture("celebrate")
	_play_fanfare(Vector3(0, 1.6, -65), true)
	_open_modal("Der Sternenschatz gehört euch!")
	var finds: int = model.discoveries.size()
	var summary := (
		"Sieben Hinweise gelöst und alle Schlüssel gefunden.\n3 Sterne und %d Erfahrungspunkte!"
		% xp
	)
	if finds > 0:
		summary += "\nZusätzlich %d Entdeckungen auf der Insel." % finds
	modal_box.add_child(KIT.label(summary, 19))
	modal_box.add_child(KIT.button("Insel weiter erkunden", _close_modal))
	modal_box.add_child(KIT.button("Neues Abenteuer", _new_adventure))
	modal_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _new_adventure() -> void:
	model = STATE.new()
	model.result_id = HostBridge.new_result_id()
	player.position = model.position
	_save()
	_update()
	_close_modal()


func _notification(what: int) -> void:
	if (
		what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]
		and is_instance_valid(player)
	):
		_save()
		if not paused:
			_pause_menu()


func _leave() -> void:
	if _save():
		SceneRouter.goto("games")


func _place_discovery_beacons() -> void:
	for spot in STATE.DISCOVERIES:
		var sid := str(spot.id)
		if sid in ["arch", "compass", "falls"]:
			# These landmarks are already part of the start vista.
			continue
		var glow: MeshInstance3D = kit.mesh(
			self, kit.SHAPES.star(), spot.at + Vector3(0, 1.55, 0), Color("ffe7a1"), true
		)
		glow.name = "DiscoveryBeacon_%s" % sid
		glow.scale = Vector3.ONE * 0.42
		glow.set_meta("discovery", sid)
		discovery_beacons[sid] = glow


func _refresh_discovery_beacons() -> void:
	for sid in discovery_beacons:
		var glow: MeshInstance3D = discovery_beacons[sid]
		if is_instance_valid(glow):
			glow.visible = sid not in model.discoveries


func _make_fanfare() -> void:
	fanfare = GPUParticles3D.new()
	fanfare.name = "TreasureFanfare"
	fanfare.emitting = false
	fanfare.one_shot = true
	fanfare.explosiveness = 0.92
	fanfare.lifetime = 1.15
	fanfare.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 14, 16))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.35
	process.direction = Vector3(0, 1, 0)
	process.spread = 70.0
	process.initial_velocity_min = 2.4
	process.initial_velocity_max = 5.8
	process.gravity = Vector3(0, -2.2, 0)
	process.scale_min = 0.08
	process.scale_max = 0.18
	process.color = Color("ffe08a")
	fanfare.process_material = process
	var star := SphereMesh.new()
	star.radius = 0.12
	star.height = 0.24
	star.radial_segments = 8
	star.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd56a")
	mat.emission_enabled = true
	mat.emission = Color("ffe08a")
	mat.emission_energy_multiplier = 2.2
	star.material = mat
	fanfare.draw_pass_1 = star
	add_child(fanfare)
	_tune_fanfare(false)


func _tune_fanfare(grand: bool) -> void:
	if not is_instance_valid(fanfare):
		return
	var budget: Dictionary = LumoQuality.budget()
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	var amount := 36 if grand else 18
	fanfare.amount = maxi(10, int(round(float(amount) * density)))


func _play_fanfare(at: Vector3, grand: bool) -> void:
	if not is_instance_valid(fanfare):
		return
	_tune_fanfare(grand)
	fanfare.global_position = at
	fanfare.restart()
	fanfare.emitting = true


func _world_to_map(at: Vector3, rect: Rect2) -> Vector2:
	var u := clampf(inverse_lerp(-35.0, 35.0, at.x), 0.0, 1.0)
	var v := clampf(inverse_lerp(-71.0, 13.0, at.z), 0.0, 1.0)
	return Vector2(rect.position.x + u * rect.size.x, rect.position.y + v * rect.size.y)


func _draw_hunt_map() -> void:
	if not is_instance_valid(hunt_map) or hunt_map.size.x < 8.0:
		return
	var size: Vector2 = hunt_map.size
	var pad := 7.0
	var rect := Rect2(Vector2.ONE * pad, size - Vector2.ONE * pad * 2.0)
	# Glass plate
	hunt_map.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.14, 0.88), true)
	hunt_map.draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.72, 0.35, 0.95), false, 2.0)
	# Water
	hunt_map.draw_rect(rect, Color(0.28, 0.55, 0.72, 0.85), true)
	# Island body
	var island := rect.grow(-rect.size.x * 0.08)
	hunt_map.draw_rect(island, Color(0.42, 0.62, 0.34, 0.95), true)
	# Shore highlight
	hunt_map.draw_rect(island, Color(0.75, 0.82, 0.45, 0.55), false, 1.2)
	# Main path toward the castle
	var path := PackedVector2Array()
	for point in [
		Vector3(0, 0, 6),
		Vector3(0, 0, 1),
		Vector3(0, 0, -14),
		Vector3(0, 0, -28),
		Vector3(0, 0, -57),
		Vector3(0, 0, -65)
	]:
		path.append(_world_to_map(point, rect))
	if path.size() >= 2:
		hunt_map.draw_polyline(path, Color(0.86, 0.72, 0.32, 0.95), 2.2, true)
	# Discoveries
	for spot in STATE.DISCOVERIES:
		var mark := _world_to_map(spot.at, rect)
		var found: bool = str(spot.id) in model.discoveries
		var color := Color("ffe08a") if found else Color(0.95, 0.9, 0.7, 0.55)
		hunt_map.draw_circle(mark, 2.4 if found else 2.0, color)
	# Clues
	for clue in STATE.CLUES:
		var mark := _world_to_map(clue.at, rect)
		var solved: bool = str(clue.id) in model.found
		if solved:
			hunt_map.draw_circle(mark, 2.6, Color(0.55, 0.72, 0.42, 0.9))
		else:
			var active := false
			for goal in available_goals:
				if str(goal.get("id", "")) == str(clue.id):
					active = true
					break
			hunt_map.draw_circle(mark, 3.2 if active else 2.4, Color("ffd56a") if active else Color(1, 1, 1, 0.45))
	# Player
	if is_instance_valid(player):
		var here := _world_to_map(player.position, rect)
		var heading := fox.rotation.y if is_instance_valid(fox) else 0.0
		# Fox yaw 0 looks toward -Z, which is up on the map (smaller y).
		var tip := here + Vector2(sin(heading), -cos(heading)) * 7.0
		var left := here + Vector2(sin(heading + 2.5), -cos(heading + 2.5)) * 5.0
		var right := here + Vector2(sin(heading - 2.5), -cos(heading - 2.5)) * 5.0
		hunt_map.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color("ff9a3c"))
		hunt_map.draw_polyline(PackedVector2Array([tip, left, right, tip]), Color("fff4e0"), 1.1, true)
		# Compass needle from player to the next hint.
		if not available_goals.is_empty():
			var goal := _world_to_map(available_goals[0].at, rect)
			var reach: Vector2 = (goal - here).limit_length(rect.size.x * 0.28)
			if reach.length() > 4.0:
				hunt_map.draw_line(here, here + reach, Color("ffe08a"), 1.6, true)
	# North label (into the island)
	var font := ThemeDB.fallback_font
	if font:
		hunt_map.draw_string(
			font,
			Vector2(size.x * 0.5 - 5.0, 16.0),
			"N",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(0.95, 0.9, 0.7, 0.95)
		)
	hunt_map.draw_line(Vector2(size.x * 0.5, 18.0), Vector2(size.x * 0.5, 26.0), Color("ffe08a"), 1.4, true)


## Fundmoment als kleine Inszenierung: warmer Lichtkegel von oben, sanftes
## Aufleuchten, Funken (Fanfare) und Lumo jubelt; die Kamera rückt kurz näher.
## Keine Blitze: Licht blendet über 0,5 s ein und über 2 s aus.
func _stage_find(at: Vector3) -> void:
	find_focus = 1.0
	if not is_instance_valid(find_beam):
		find_beam = MeshInstance3D.new()
		find_beam.name = "TreasureFindBeam"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.6
		cone.bottom_radius = 2.2
		cone.height = 12.0
		cone.cap_top = false
		cone.cap_bottom = false
		cone.radial_segments = 20
		find_beam.mesh = cone
		var beam_mat := ShaderMaterial.new()
		beam_mat.shader = ADVENTURE.shader("light_beam")
		beam_mat.set_shader_parameter("beam_color", Color("ffe2a0"))
		beam_mat.set_shader_parameter("beam_length", 12.0)
		beam_mat.set_shader_parameter("invert", 1.0)
		find_beam.material_override = beam_mat
		find_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(find_beam)
		find_light = OmniLight3D.new()
		find_light.name = "TreasureFindLight"
		find_light.light_color = Color("ffd88a")
		find_light.omni_range = 7.0
		find_light.shadow_enabled = false
		add_child(find_light)
	find_beam.position = at + Vector3.UP * 6.0
	find_light.position = at + Vector3.UP * 2.6
	find_beam.visible = true
	var mat := find_beam.material_override as ShaderMaterial
	mat.set_shader_parameter("intensity", 0.0)
	find_light.light_energy = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.0, 0.55, 0.5)
	tw.tween_property(find_light, "light_energy", 2.4, 0.5)
	tw.chain().tween_interval(1.2)
	tw.chain().set_parallel(true)
	tw.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), 0.55, 0.0, 2.0)
	tw.tween_property(find_light, "light_energy", 0.0, 2.0)
