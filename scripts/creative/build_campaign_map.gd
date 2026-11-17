extends Control
## LUMO Kampagnenkarte: a stylised 3D diorama of the twelve village chapters.
## Data comes from the village model (`campaign_overview()`), so the map never
## stores anything itself and old saves keep working unchanged. Stations sit
## on a winding path through three regions; finished chapters carry a golden
## flag, the open chapter glows and bobs a star, locked ones stay grey.
## Repeated geometry is batched in MultiMeshes (one draw per mesh type).

signal enter_requested(chapter_index: int)
signal closed

const HUD = preload("res://scripts/creative/build_hud_style.gd")
const REGIONS := [
	{"name": "Wiesenwinkel", "ground": Color("63b843"), "accent": Color("e8553f")},
	{"name": "Handelstal", "ground": Color("d4a24c"), "accent": Color("3f7fd9")},
	{"name": "Lumo-Stadt", "ground": Color("4d9fcf"), "accent": Color("f2b33d")},
]
const STATE_COLORS := {
	"done": Color("ffc93c"), "current": Color("38e1ff"), "locked": Color("a3aaa8")
}
const PATH_STEPS := 7

var chapters: Array = []
var selected := 0
var viewport: SubViewport
var view_container: SubViewportContainer
var camera: Camera3D
var stations: Array[Vector3] = []
var badges: Array[Button] = []
var current_marker: Node3D
var current_ring: MeshInstance3D
var title_label: Label
var badge_chip: PanelContainer
var detail_title: Label
var detail_body: Label
var detail_goals: VBoxContainer
var detail_reward: Label
var action_button: Button
var detail_panel: PanelContainer
var pan := 0.0
var drag_from := Vector2.INF
var drag_moved := false
var elapsed := 0.0
var high_detail := true
var shadows := true


## chapter_data: Array of dictionaries from campaign_overview().
func setup(chapter_data: Array, quality_tier: String) -> void:
	chapters = chapter_data
	high_detail = quality_tier != "low"
	shadows = quality_tier == "high"
	selected = 0
	for index in range(chapters.size()):
		if str(chapters[index].state) == "current":
			selected = index


func _ready() -> void:
	name = "BuildCampaignMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.11, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	view_container = SubViewportContainer.new()
	view_container.stretch = true
	view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X if high_detail else Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view_container.add_child(viewport)
	_build_diorama()
	_build_overlay()
	_select(selected)
	resized.connect(_layout)
	_layout.call_deferred()


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.vertex_color_use_as_albedo = true
	# Instance colours are authored in sRGB like every other LUMO colour.
	material.vertex_color_is_srgb = true
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _mesh_instance(mesh: Mesh, color: Color, at: Vector3, emission := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, emission)
	node.material_override.vertex_color_use_as_albedo = false
	node.position = at
	viewport.add_child(node)
	return node


func _multimesh(mesh: Mesh, transforms: Array, colors: Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = _material(Color.WHITE)
	viewport.add_child(node)
	return node


## Snake-shaped route: three rows of four stations, one row per region.
static func station_position(index: int) -> Vector3:
	var row := index / 4
	var column := index % 4
	if row % 2 == 1:
		column = 3 - column
	var x := -9.0 + column * 6.0
	var z := 6.5 - row * 6.5
	return Vector3(x, 0.6, z + (0.9 if column % 2 == 1 else -0.4))


func _build_diorama() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("163c55")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfe9ff")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = false
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = shadows
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 42
	viewport.add_child(camera)
	camera.current = true
	_update_camera()
	# Sea and the three region plateaus.
	var sea := PlaneMesh.new()
	sea.size = Vector2(80, 60)
	_mesh_instance(sea, Color("2a7fb2"), Vector3(0, -0.35, 0))
	# Region plateaus with darker cliff skirts, batched into one draw.
	var slab := BoxMesh.new()
	slab.size = Vector3.ONE
	var slab_xforms: Array = []
	var slab_colors: Array = []
	for row in range(3):
		var region: Dictionary = REGIONS[row]
		var z := 6.5 - row * 6.5
		slab_xforms.append(Transform3D(Basis().scaled(Vector3(26.0, 0.9, 6.4)), Vector3(0, 0.0, z)))
		slab_colors.append(region.ground)
		slab_xforms.append(Transform3D(Basis().scaled(Vector3(26.6, 0.7, 6.9)), Vector3(0, -0.45, z)))
		slab_colors.append(Color(region.ground).darkened(0.4))
	_multimesh(slab, slab_xforms, slab_colors)
	stations.clear()
	for index in range(12):
		stations.append(station_position(index))
	# Path stones between stations, gold where the route is already walked.
	var stone := CylinderMesh.new()
	stone.top_radius = 0.32
	stone.bottom_radius = 0.36
	stone.height = 0.12
	stone.radial_segments = 10
	var stone_xforms: Array = []
	var stone_colors: Array = []
	for index in range(stations.size() - 1):
		var walked: bool = index < chapters.size() and str(chapters[index].state) == "done"
		for step in range(1, PATH_STEPS):
			var t := float(step) / PATH_STEPS
			var at := stations[index].lerp(stations[index + 1], t)
			at.y = 0.5
			stone_xforms.append(Transform3D(Basis(), at))
			stone_colors.append(Color("ffd979") if walked else Color("efe3c4"))
	_multimesh(stone, stone_xforms, stone_colors)
	# Station pedestals, house bodies, roofs, flag poles and flags.
	var pedestal := CylinderMesh.new()
	pedestal.top_radius = 1.25
	pedestal.bottom_radius = 1.45
	pedestal.height = 0.4
	var body := BoxMesh.new()
	body.size = Vector3(1.3, 1.0, 1.1)
	var roof := PrismMesh.new()
	roof.size = Vector3(1.6, 0.8, 1.3)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 2.0
	pole.radial_segments = 6
	var flag := BoxMesh.new()
	flag.size = Vector3(0.7, 0.42, 0.05)
	var lists := {"pedestal": [[], []], "body": [[], []], "roof": [[], []], "pole": [[], []], "flag": [[], []]}
	for index in range(stations.size()):
		var state := str(chapters[index].state) if index < chapters.size() else "locked"
		var region: Dictionary = REGIONS[index / 4]
		var at := stations[index]
		var tint: Color = STATE_COLORS[state]
		lists.pedestal[0].append(Transform3D(Basis(), at + Vector3(0, 0.0, 0)))
		lists.pedestal[1].append(tint.darkened(0.15))
		var house_color: Color = Color("f1e2c2") if state != "locked" else Color("c9c2b4")
		lists.body[0].append(Transform3D(Basis(Vector3.UP, 0.4 * (index % 3 - 1)), at + Vector3(0, 0.7, 0)))
		lists.body[1].append(house_color)
		lists.roof[0].append(Transform3D(Basis(Vector3.UP, 0.4 * (index % 3 - 1)), at + Vector3(0, 1.6, 0)))
		lists.roof[1].append(Color(region.accent) if state != "locked" else Color(region.accent).lerp(Color("8d9593"), 0.65))
		lists.pole[0].append(Transform3D(Basis(), at + Vector3(0.95, 1.2, 0.55)))
		lists.pole[1].append(Color("6b4a2b"))
		lists.flag[0].append(Transform3D(Basis(), at + Vector3(1.32, 1.95, 0.55)))
		lists.flag[1].append(tint)
	_multimesh(pedestal, lists.pedestal[0], lists.pedestal[1])
	_multimesh(body, lists.body[0], lists.body[1])
	_multimesh(roof, lists.roof[0], lists.roof[1])
	_multimesh(pole, lists.pole[0], lists.pole[1])
	_multimesh(flag, lists.flag[0], lists.flag[1])
	_build_decor()
	# Glowing ring and bobbing star over the open chapter.
	var ring := TorusMesh.new()
	ring.inner_radius = 1.45
	ring.outer_radius = 1.7
	current_ring = _mesh_instance(ring, STATE_COLORS.current, Vector3.ZERO, 1.6)
	current_marker = Node3D.new()
	viewport.add_child(current_marker)
	var star := SphereMesh.new()
	star.radius = 0.32
	star.height = 0.64
	var orb := MeshInstance3D.new()
	orb.mesh = star
	orb.material_override = _material(Color("ffe27a"), 2.2)
	orb.material_override.vertex_color_use_as_albedo = false
	current_marker.add_child(orb)
	_place_current_marker()


func _build_decor() -> void:
	var count := 60 if high_detail else 26
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.12
	trunk.height = 0.5
	trunk.radial_segments = 6
	var crown := SphereMesh.new()
	crown.radius = 0.42
	crown.height = 0.8
	crown.radial_segments = 8
	crown.rings = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 2040
	var trunks: Array = []
	var trunk_colors: Array = []
	var crowns: Array = []
	var crown_colors: Array = []
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 20:
		guard += 1
		var at := Vector3(rng.randf_range(-12.5, 12.5), 0.7, rng.randf_range(-9.4, 9.4))
		var clear := true
		for station in stations:
			if Vector2(at.x - station.x, at.z - station.z).length() < 2.1:
				clear = false
				break
		if not clear:
			continue
		var scale := rng.randf_range(0.75, 1.3)
		var basis := Basis().scaled(Vector3.ONE * scale)
		trunks.append(Transform3D(basis, at))
		trunk_colors.append(Color("7a5230"))
		crowns.append(Transform3D(basis, at + Vector3(0, 0.55 * scale, 0)))
		crown_colors.append(Color("3f9b4a").lerp(Color("7cc95a"), rng.randf()))
		placed += 1
	_multimesh(trunk, trunks, trunk_colors)
	_multimesh(crown, crowns, crown_colors)
	# Distant mountains frame the board on the far side.
	var peak := CylinderMesh.new()
	peak.top_radius = 0.0
	peak.bottom_radius = 2.6
	peak.height = 3.6
	peak.radial_segments = 7
	var peaks: Array = []
	var peak_colors: Array = []
	for index in range(9):
		var x := -14.0 + index * 3.5
		peaks.append(Transform3D(Basis().scaled(Vector3.ONE * (0.8 + 0.3 * (index % 3))), Vector3(x, 1.2, -12.2)))
		peak_colors.append(Color("6d8597").lerp(Color("8ea4b5"), float(index % 2)))
	_multimesh(peak, peaks, peak_colors)


func _place_current_marker() -> void:
	var current := -1
	for index in range(chapters.size()):
		if str(chapters[index].state) == "current":
			current = index
	current_ring.visible = current >= 0
	current_marker.visible = current >= 0
	if current >= 0:
		current_ring.position = stations[current] + Vector3(0, 0.25, 0)
		current_marker.position = stations[current] + Vector3(0, 3.0, 0)


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var portrait := size.y > size.x
	# Frame the whole board; in landscape it sits left of the detail card,
	# in portrait above it.
	# Portrait keeps the board's width on screen instead of its height.
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.fov = 58.0 if portrait else 42.0
	var distance := 30.0 if portrait else 31.0
	var target := Vector3(pan + (0.0 if portrait else 4.2), 0.0, 6.5 if portrait else 0.8)
	camera.position = target + Vector3(0, distance * 0.8, distance * 0.6)
	camera.look_at(target)


func _build_overlay() -> void:
	var header := PanelContainer.new()
	header.name = "CampaignHeader"
	header.add_theme_stylebox_override("panel", HUD.bar())
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 12
	header.offset_right = -12
	header.offset_top = 10
	add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	var back := HUD.button("‹ Zum Dorf", close_map, 120, "dark")
	back.name = "CampaignClose"
	row.add_child(back)
	title_label = HUD.label("Kampagnenkarte", 22, HUD.INK_LIGHT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	var done := 0
	for chapter in chapters:
		if str(chapter.state) == "done":
			done += 1
	badge_chip = HUD.chip("badge", Color("ffc93c"), "%d/12" % done)
	badge_chip.tooltip_text = "Kapitel-Abzeichen"
	row.add_child(badge_chip)
	title_label.text = "Kampagnenkarte · %d von 12 geschafft" % done
	for index in range(12):
		var badge := Button.new()
		badge.name = "Station%02d" % (index + 1)
		badge.text = str(index + 1)
		badge.focus_mode = Control.FOCUS_NONE
		badge.custom_minimum_size = Vector2(48, 48)
		badge.size = Vector2(48, 48)
		var state := str(chapters[index].state) if index < chapters.size() else "locked"
		HUD.style_button(badge, {"done": "primary", "current": "teal", "locked": "cream"}[state], 18)
		if state == "locked":
			badge.modulate = Color(1, 1, 1, 0.78)
		badge.pressed.connect(_select.bind(index))
		add_child(badge)
		badges.append(badge)
	detail_panel = PanelContainer.new()
	detail_panel.name = "CampaignDetail"
	detail_panel.add_theme_stylebox_override("panel", HUD.card())
	add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	detail_panel.add_child(detail)
	detail_title = HUD.label("", 20)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_title)
	detail_body = HUD.label("", 15)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_body)
	detail_goals = VBoxContainer.new()
	detail_goals.add_theme_constant_override("separation", 4)
	detail.add_child(detail_goals)
	detail_reward = HUD.label("", 15, Color("8a5a00"))
	detail_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(detail_reward)
	action_button = HUD.button("Zum Kapitel", _enter_selected, 160, "primary")
	action_button.name = "CampaignEnter"
	detail.add_child(action_button)


func _select(index: int) -> void:
	if chapters.is_empty():
		return
	selected = clampi(index, 0, chapters.size() - 1)
	var chapter: Dictionary = chapters[selected]
	var state := str(chapter.state)
	var region: Dictionary = REGIONS[selected / 4]
	detail_title.text = "Kapitel %d · %s" % [selected + 1, str(chapter.title)]
	var intro := "%s · %s erzählt: %s" % [region.name, str(chapter.friend), str(chapter.story)]
	detail_body.text = intro + "\nAufgabe: " + str(chapter.task)
	for child in detail_goals.get_children():
		detail_goals.remove_child(child)
		child.queue_free()
	for goal in chapter.get("goals", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var caption := HUD.label("%s %d/%d" % [str(goal.title), mini(int(goal.current), int(goal.target)), int(goal.target)], 14)
		caption.custom_minimum_size.x = 150
		line.add_child(caption)
		var bar := ProgressBar.new()
		bar.max_value = maxi(1, int(goal.target))
		bar.value = int(goal.target) if state == "done" else mini(int(goal.current), int(goal.target))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(90, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ffc93c") if state == "done" else Color("38c9e0")
		fill.set_corner_radius_all(7)
		var back := StyleBoxFlat.new()
		back.bg_color = Color("e4dccb")
		back.set_corner_radius_all(7)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		line.add_child(bar)
		detail_goals.add_child(line)
	match state:
		"done":
			detail_reward.text = "Belohnung: Kapitel-Abzeichen ✓ erhalten"
			action_button.text = "Geschafft"
			action_button.disabled = true
		"current":
			detail_reward.text = "Belohnung: Kapitel-Abzeichen und das nächste Kapitel"
			action_button.text = "Zum Kapitel"
			action_button.disabled = false
		_:
			detail_reward.text = "Gesperrt: Schaffe zuerst Kapitel %d." % _first_open_chapter()
			action_button.text = "Noch gesperrt"
			action_button.disabled = true
	for badge_index in range(badges.size()):
		badges[badge_index].scale = Vector2.ONE * (1.18 if badge_index == selected else 1.0)
	_layout.call_deferred()


func _first_open_chapter() -> int:
	for index in range(chapters.size()):
		if str(chapters[index].state) == "current":
			return index + 1
	return chapters.size()


func _enter_selected() -> void:
	if selected < chapters.size() and str(chapters[selected].state) == "current":
		enter_requested.emit(selected)
		close_map()


func close_map() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _layout() -> void:
	if not is_instance_valid(detail_panel):
		return
	_update_camera()
	var portrait := size.y > size.x
	var width := minf(size.x - 24.0, 380.0) if not portrait else size.x - 24.0
	detail_panel.custom_minimum_size = Vector2(width, 0)
	detail_panel.size = Vector2(width, 0)
	detail_panel.reset_size()
	if portrait:
		detail_panel.position = Vector2(12, size.y - detail_panel.size.y - 12)
	else:
		detail_panel.position = Vector2(size.x - width - 12, size.y - detail_panel.size.y - 12)
	_place_badges()


func _place_badges() -> void:
	if not is_instance_valid(camera) or stations.is_empty():
		return
	var scale_factor := Vector2.ONE
	if viewport.size.x > 0:
		scale_factor = view_container.size / Vector2(viewport.size)
	for index in range(badges.size()):
		var world := stations[index] + Vector3(0, 2.4, 0)
		var visible := not camera.is_position_behind(world)
		var at := camera.unproject_position(world) * scale_factor
		badges[index].visible = visible
		badges[index].pivot_offset = badges[index].size * 0.5
		badges[index].position = at - badges[index].size * 0.5


func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(current_marker) and current_marker.visible:
		current_marker.position.y = stations[_first_open_chapter() - 1].y + 3.0 + sin(elapsed * 2.4) * 0.25
		current_ring.scale = Vector3.ONE * (1.0 + sin(elapsed * 3.0) * 0.05)
	_place_badges()


func _gui_input(event: InputEvent) -> void:
	var position_now := Vector2.INF
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		position_now = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and drag_from != Vector2.INF:
		var dx: float = event.relative.x
		if absf(event.position.x - drag_from.x) > 12.0:
			drag_moved = true
		pan = clampf(pan - dx * 0.04, -8.0, 8.0)
		_update_camera()
		accept_event()
		return
	if pressed:
		drag_from = position_now
		drag_moved = false
	elif released:
		if not drag_moved and position_now != Vector2.INF:
			_select_nearest(position_now)
		drag_from = Vector2.INF
	accept_event()


func _select_nearest(at: Vector2) -> void:
	var best := -1
	var best_distance := 64.0
	for index in range(badges.size()):
		var center := badges[index].position + badges[index].size * 0.5
		var distance := center.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = index
	if best >= 0:
		_select(best)
