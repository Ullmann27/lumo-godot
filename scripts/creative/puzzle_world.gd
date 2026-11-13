extends Node3D
const STATE = preload("res://scripts/creative/puzzle_state.gd")
const PIECE = preload("res://scripts/creative/puzzle_piece.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const ART = preload("res://scripts/creative/puzzle_atelier_art.gd")
const ALIVE_SHADER = preload("res://assets/creative/puzzle/puzzle_alive.gdshader")
const TABLE_SHADER = preload("res://assets/creative/puzzle/puzzle_table.gdshader")
const MOTIFS = [
	preload("res://assets/creative/puzzle/moonlight.webp"),
	preload("res://assets/creative/puzzle/candy.webp"),
	preload("res://assets/creative/puzzle/volcano.webp"),
	preload("res://assets/creative/puzzle/hafen.webp"),
	preload("res://assets/creative/puzzle/bluetenwiese.webp")
]
const TITLES = [
	"Lumos Mondschloss",
	"Candy Cloud Circuit",
	"Volcano Night Run",
	"Leuchtturm-Bucht",
	"Blütenwiese"
]
var model = STATE.new()
var kit = KIT.new()
var previous: Dictionary
var camera: Camera3D
var safe_ui: Control
var hud_backdrop: ColorRect
var tool_scroll: ScrollContainer
var piece_root: Node3D
var nodes: Array[StaticBody3D] = []
var guide: MeshInstance3D
var board_frame: MeshInstance3D
var board_base: MeshInstance3D
var hint_marker: MeshInstance3D
var hover_marker: MeshInstance3D
var alive_picture: MeshInstance3D
var snap_burst: GPUParticles3D
var info: Label
var status: Label
var menu: PanelContainer
var menu_box: VBoxContainer
var menu_scroll: ScrollContainer
var progress: ProgressBar
var selected_count: int = 12
var selected_motif: int = 3
var selected_rotation: bool = false
var selected_piece: int = -1
var rotate_button: Button
var rotation_tweens: Dictionary = {}
var tray_page: int = 0
var edges_only: bool = false
var paused: bool = true
var dragging: int = -1
var finger: int = -1
var drag_offset := Vector2.ZERO
var save_path: String
var dirty: bool = false
var save_clock: float = 0
var hint_time: float = 0
var matching_hover: bool = false
var picture_alive: bool = false
var last_snap_fx: bool = false
var preview_tier: String = ""
var compact_tray: bool = false


func _ready() -> void:
	previous = RUNTIME.enter(self, true)
	SceneRouter.current_scene_id = "puzzle"
	var child := (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	save_path = "user://lumo_puzzle_" + child + ".json"
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_PUZZLE_ATELIER)
	# The tabletop is close to the camera: avoid self-shadow stripes on the
	# newly lit picture surface while retaining shadows beneath lifted pieces.
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_bias = 0.5
	var table: MeshInstance3D = kit.box(
		self, Vector3(0, -0.28, 0.2), Vector3(22, 0.48, 13.2), Color.WHITE
	)
	table.material_override = _table_wood(Color("ae8054"))
	board_frame = kit.box(self, Vector3(0, -0.012, 0), Vector3.ONE, Color("d7b056"))
	board_frame.material_override = _gold()
	board_base = kit.box(self, Vector3(0, 0.07, 0), Vector3.ONE, Color("1a2748"))
	var board_material := board_base.material_override as StandardMaterial3D
	board_material.roughness = 0.92
	board_material.metallic_specular = 0.12
	# Flat dyed felt avoids shadow-map acne on the shallow board in GLES.
	# Piece edges, the gold frame and the room retain their lit 3D materials.
	board_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var tray: MeshInstance3D = kit.box(
			self, Vector3(side * 7.35, -0.04, 0), Vector3(4.7, 0.18, 6.9), Color.WHITE
		)
		tray.material_override = _table_wood(Color("91603d"))
		var felt: MeshInstance3D = kit.box(
			self, Vector3(side * 7.35, 0.07, 0), Vector3(4.35, 0.04, 6.55), Color("1a2748")
		)
		felt.material_override = kit.material(Color("1a2748"))
		# Four border rails leave the blue felt exposed. A solid rim box at
		# this height covered the whole tray and hid its material.
		for edge in [-1.0, 1.0]:
			var long_rim: MeshInstance3D = kit.box(
				self,
				Vector3(side * 7.35 + edge * 2.37, 0.1, 0),
				Vector3(0.14, 0.05, 7.08),
				Color("d7b056")
			)
			long_rim.material_override = _gold()
			var short_rim: MeshInstance3D = kit.box(
				self,
				Vector3(side * 7.35, 0.1, edge * 3.47),
				Vector3(4.6, 0.05, 0.14),
				Color("d7b056")
			)
			short_rim.material_override = _gold()
	_atelier_backdrop()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40
	camera.position = Vector3(0, 13.8, 11.6)
	add_child(camera)
	camera.look_at(Vector3(0, 0.05, -0.35))
	camera.current = true
	piece_root = Node3D.new()
	add_child(piece_root)
	guide = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = model.board_size()
	guide.mesh = plane
	guide.position.y = 0.13
	guide.visible = false
	add_child(guide)
	hint_marker = kit.box(self, Vector3.ZERO, Vector3(1, 0.025, 1), Color("77e8ff"), true)
	hint_marker.hide()
	hover_marker = kit.box(self, Vector3.ZERO, Vector3(1, 0.02, 1), Color("7cf0ff"), true)
	hover_marker.hide()
	_make_alive_picture()
	_make_snap_burst()
	_ui()
	get_viewport().size_changed.connect(_resize_ui)
	RUNTIME.watch_safe_area(self, _resize_ui)
	_resize_ui()
	_show_selection()


func _exit_tree() -> void:
	RUNTIME.unwatch_safe_area(self)
	if get_viewport().size_changed.is_connected(_resize_ui):
		get_viewport().size_changed.disconnect(_resize_ui)
	RUNTIME.restore(self, previous)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	hud_backdrop = ColorRect.new()
	hud_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_backdrop.offset_bottom = 164
	hud_backdrop.color = Color(0.025, 0.055, 0.12, 0.90)
	hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_ui.add_child(hud_backdrop)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	var title := KIT.label("LUMOS PUZZLE-ATELIER", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	top.add_child(title)
	info = KIT.label("", 18)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.position = Vector2(16, 66)
	info.offset_right = -16
	safe_ui.add_child(info)
	top.add_child(KIT.button("Ⅱ", _pause_menu, 52))
	tool_scroll = ScrollContainer.new()
	tool_scroll.name = "PuzzleToolsScroll"
	tool_scroll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tool_scroll.offset_top = -78
	tool_scroll.offset_bottom = -12
	tool_scroll.offset_left = 14
	tool_scroll.offset_right = -14
	tool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe_ui.add_child(tool_scroll)
	var tools := HBoxContainer.new()
	tool_scroll.add_child(tools)
	rotate_button = KIT.button("↻ Drehen", _rotate_selected, 116)
	rotate_button.name = "RotatePuzzlePiece"
	rotate_button.tooltip_text = "Teil antippen, dann um eine Vierteldrehung drehen. Tastatur: R."
	tools.add_child(rotate_button)
	tools.add_child(KIT.button("‹ Teile", _page.bind(-1)))
	tools.add_child(KIT.button("Teile ›", _page.bind(1)))
	tools.add_child(KIT.button("Randteile", _edges))
	var show := KIT.button("Bild ansehen", func(): pass)
	show.button_down.connect(func(): guide.visible = true)
	show.button_up.connect(func(): guide.visible = picture_alive)
	tools.add_child(show)
	tools.add_child(KIT.button("Ein Tipp", _hint))
	tools.add_child(KIT.button("Speichern", _save))
	tools.add_child(KIT.button("Neues Puzzle", _show_selection))
	status = KIT.label("Ziehe ein Teil auf seinen Platz. Es rastet ein, wenn es passt.", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.position = Vector2(16, 92)
	status.offset_right = -16
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safe_ui.add_child(status)
	progress = ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress.position.y = 136
	progress.offset_left = 14
	progress.offset_right = -14
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	safe_ui.add_child(progress)
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", KIT.panel())
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-235, -180)
	menu.custom_minimum_size = Vector2(470, 0)
	safe_ui.add_child(menu)
	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "PuzzleMenuScroll"
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(menu_scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 12)
	menu_scroll.add_child(menu_box)


func _resize_ui() -> void:
	if not is_inside_tree():
		return
	RUNTIME.safe_area(self, safe_ui)
	if is_instance_valid(menu):
		for child in menu_box.get_children():
			if child is Label:
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif child is Button:
				child.clip_text = true
				child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var width := minf(470.0, maxf(180.0, safe_ui.size.x - 24.0))
		menu.custom_minimum_size.x = width
		call_deferred("_fit_menu")
	if is_instance_valid(camera) and camera.is_inside_tree():
		var view := get_viewport().get_visible_rect().size
		var aspect := view.x / maxf(view.y, 1.0)
		compact_tray = aspect < 1.15
		for prop_name in ["PuzzleCompass", "PuzzleDeskBooks", "PuzzlePots", "PuzzleHydrangeas"]:
			var prop := get_node_or_null(NodePath(prop_name)) as Node3D
			if prop != null:
				prop.visible = not compact_tray
		camera.position = Vector3(0, 13.8, 11.6) * maxf(1.0, 0.82 / aspect)
		camera.look_at(Vector3(0, 0.05, 0.8 if compact_tray else -0.35))
		if not nodes.is_empty() and dragging < 0:
			_tray()
		else:
			_fit_play_camera()


func _fit_menu() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(menu):
		return
	var height := minf(
		menu_box.get_combined_minimum_size().y + 24.0, maxf(96.0, safe_ui.size.y - 24.0)
	)
	menu_scroll.custom_minimum_size.y = maxf(48.0, height - 24.0)
	menu.size = Vector2(menu.custom_minimum_size.x, height)
	menu.position = (safe_ui.size - menu.size) * 0.5


func _play_area() -> Rect2:
	var safe := safe_ui.get_global_rect()
	var top := maxf(safe.position.y, hud_backdrop.get_global_rect().end.y)
	var bottom := minf(safe.end.y, tool_scroll.get_global_rect().position.y)
	return Rect2(
		Vector2(safe.position.x + 14.0, top + 10.0),
		Vector2(maxf(1.0, safe.size.x - 28.0), maxf(1.0, bottom - top - 20.0))
	)


func _camera_mesh_points(points: Array[Vector3], mesh: MeshInstance3D, lifted: bool) -> void:
	var bounds := mesh.get_aabb()
	for corner in range(8):
		var point: Vector3 = mesh.global_transform * bounds.get_endpoint(corner)
		points.append(point)
		if lifted:
			# A picked piece rises from 0.15 to 0.8 and grows slightly. Reserve
			# that actual interaction envelope before the finger begins moving.
			var center: Vector3 = mesh.global_position
			points.append(center + (point - center) * 1.08 + Vector3.UP * 0.65)


func _fit_play_camera() -> void:
	if nodes.is_empty() or not is_instance_valid(camera):
		return
	var area := _play_area()
	var points: Array[Vector3] = []
	_camera_mesh_points(points, board_frame, false)
	for node in nodes:
		if node.visible:
			_camera_mesh_points(points, node.get_node("Visual") as MeshInstance3D, true)
	var already_fits := true
	for point in points:
		if not area.has_point(camera.unproject_position(point)):
			already_fits = false
			break
	if already_fits:
		return
	# Fit the actual table geometry into the asymmetric usable screen rectangle.
	# The camera's orientation/FOV stay fixed. Perspective constraints determine
	# the distance and local offset, so short landscape cannot hide slots behind
	# the 164px header or the bottom touch toolbar.
	var view := get_viewport().get_visible_rect().size
	var basis := camera.global_basis.orthonormalized()
	var inverse := basis.inverse()
	var local_points: Array[Vector3] = []
	var low := inverse * points[0]
	var high := low
	for point in points:
		var local := inverse * point
		local_points.append(local)
		low = low.min(local)
		high = high.max(local)
	var anchor := (low + high) * 0.5
	var projection := camera.get_camera_projection()
	var focal := Vector2(projection.x.x * view.x, projection.y.y * view.y) * 0.5
	var center := area.get_center()
	var offset := Vector2(center.x - view.x * 0.5, view.y * 0.5 - center.y) / focal
	var half := area.size * 0.5 / focal
	var distance := camera.near + 1.0
	for point in local_points:
		var relative := point - anchor
		distance = maxf(distance, relative.z + camera.near + 0.05)
		distance = maxf(distance, relative.z + absf(relative.x + offset.x * relative.z) / half.x)
		distance = maxf(distance, relative.z + absf(relative.y + offset.y * relative.z) / half.y)
	camera.global_position = (
		basis * (anchor + Vector3(-offset.x * distance, -offset.y * distance, distance))
	)


func _clear_menu() -> void:
	paused = true
	_clear_selection()
	dragging = -1
	finger = -1
	for child in menu_box.get_children():
		# Button release still traverses its Control ancestry after pressed.
		# Hide obsolete actions now; keep them in-tree until queued deletion.
		if child is Control:
			child.hide()
		child.queue_free()
	menu_scroll.scroll_vertical = 0
	menu.show()
	call_deferred("_resize_ui")


func _show_selection() -> void:
	if not model.pieces.is_empty():
		_save()
	_hide_alive()
	_clear_menu()
	menu_box.add_child(KIT.label("Stück für Stück entsteht deine Welt", 23))
	menu_box.add_child(KIT.button("Bild: %s" % TITLES[selected_motif], _next_motif))
	menu_box.add_child(
		KIT.button(
			"%s · %d Teile" % [STATE.difficulty_name_for(selected_count), selected_count],
			_next_count
		)
	)
	menu_box.add_child(
		KIT.button(
			"Modus: Drehpuzzle" if selected_rotation else "Modus: Bilderpuzzle",
			_toggle_rotation_mode
		)
	)
	menu_box.add_child(KIT.button("Neues Puzzle beginnen", start))
	if FileAccess.file_exists(save_path):
		menu_box.add_child(KIT.button("Gespeichertes Puzzle fortsetzen", _resume))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _next_count() -> void:
	selected_count = STATE.COUNTS[(STATE.COUNTS.find(selected_count) + 1) % STATE.COUNTS.size()]
	_show_selection()


func _next_motif() -> void:
	selected_motif = (selected_motif + 1) % MOTIFS.size()
	_show_selection()


func _toggle_rotation_mode() -> void:
	selected_rotation = not selected_rotation
	_show_selection()


func start() -> void:
	_hide_alive()
	_clear_selection()
	model.setup(selected_count, selected_motif, selected_rotation)
	model.result_id = HostBridge.new_result_id()
	tray_page = 0
	edges_only = false
	_build_pieces()
	paused = false
	menu.hide()
	status.text = (
		"Tippe ein Teil an, drehe es mit ↻ und ziehe es auf seinen Platz."
		if model.rotation_enabled
		else "Ziehe ein Teil auf seinen Platz. Es rastet ein, wenn es passt."
	)
	_update_rotate_button()
	dirty = true
	_save()


func _resume() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not saved is Dictionary or not model.restore(saved):
		status.text = (
			"Dieser Spielstand konnte nicht geöffnet werden. "
			+ "Dein offenes Puzzle bleibt erhalten."
		)
		return
	selected_count = model.count
	selected_motif = model.motif
	selected_rotation = model.rotation_enabled
	_clear_selection()
	tray_page = 0
	_build_pieces()
	paused = false
	menu.hide()
	if model.complete():
		_win()


func _build_pieces() -> void:
	for tween in rotation_tweens.values():
		if tween is Tween and tween.is_valid():
			tween.kill()
	rotation_tweens.clear()
	var size: Vector2 = model.board_size()
	board_frame.scale = Vector3(size.x + 0.72, 0.1, size.y + 0.72)
	board_base.scale = Vector3(size.x + 0.1, 0.1, size.y + 0.1)
	guide.mesh.size = size
	for child in piece_root.get_children():
		piece_root.remove_child(child)
		child.queue_free()
	nodes.clear()
	for i in range(model.count):
		var node: StaticBody3D = PIECE.create(model, i, MOTIFS[model.motif])
		piece_root.add_child(node)
		nodes.append(node)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = MOTIFS[model.motif]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide.material_override = mat
	guide.hide()
	_tray()
	_labels()


func _tray() -> void:
	var pending: Array[int] = []
	for i in range(model.count):
		var node: StaticBody3D = nodes[i]
		if (
			not rotation_tweens.has(i)
			or not rotation_tweens[i].is_valid()
			or not rotation_tweens[i].is_running()
		):
			node.quaternion = Quaternion(Vector3.UP, int(model.pieces[i].get("turn", 0)) * PI * 0.5)
		if model.pieces[i].locked:
			node.show()
			node.position = Vector3(model.target(i).x, 0.14, model.target(i).y)
			node.scale = Vector3.ONE
		elif not bool(model.pieces[i].get("tray", true)):
			node.show()
			node.position = Vector3(model.pieces[i].x, 0.15, model.pieces[i].z)
		else:
			node.hide()
			if not edges_only or model.is_edge(i):
				pending.append(i)
	var per_side: int = STATE.tray_per_side(model.count)
	var page_size: int = 3 if compact_tray else per_side * 2
	var pages: int = maxi(1, ceili(float(pending.size()) / page_size))
	tray_page = posmod(tray_page, pages)
	for p in range(tray_page * page_size, mini((tray_page + 1) * page_size, pending.size())):
		var i: int = pending[p]
		var local: int = p % page_size
		var x: float = -7.0 if local < per_side else 7.0
		var z: float = -2.2 + (local % per_side) * (4.4 / maxi(1, per_side - 1))
		if compact_tray:
			x = float(local - 1) * 3.05
			z = model.board_size().y * 0.5 + model.cell_size().y * 0.5 + 0.55
			nodes[i].scale = Vector3.ONE * minf(1.8, 2.7 / model.cell_size().x)
		else:
			nodes[i].scale = Vector3.ONE
		model.pieces[i].x = x
		model.pieces[i].z = z
		nodes[i].position = Vector3(x, 0.15, z)
		nodes[i].show()
	_fit_play_camera()


func _page(direction: int) -> void:
	if paused:
		return
	_drop()
	_clear_selection()
	tray_page += direction
	_tray()


func _edges() -> void:
	if paused:
		return
	_drop()
	_clear_selection()
	edges_only = not edges_only
	tray_page = 0
	_tray()
	status.text = "Nur Randteile angezeigt." if edges_only else "Alle Teile angezeigt."


func _labels() -> void:
	info.text = (
		"%s%s · %d / %d Teile · %d Tipps"
		% [
			model.difficulty_name(),
			" · Drehpuzzle" if model.rotation_enabled else "",
			model.placed(),
			model.count,
			model.hints
		]
	)
	progress.value = float(model.placed()) / maxi(1, model.count) * 100
	_update_rotate_button()


func _update_rotate_button() -> void:
	if not is_instance_valid(rotate_button):
		return
	rotate_button.visible = model.rotation_enabled
	rotate_button.disabled = paused or selected_piece < 0 or selected_piece >= model.pieces.size()
	if not rotate_button.disabled:
		rotate_button.disabled = model.pieces[selected_piece].locked


func _clear_selection() -> void:
	if selected_piece >= 0 and selected_piece < nodes.size():
		_clear_overlay(selected_piece)
	selected_piece = -1
	_update_rotate_button()


func _rotate_selected() -> void:
	if paused or selected_piece < 0 or not model.rotate_piece(selected_piece):
		return
	var id := selected_piece
	if rotation_tweens.has(id) and rotation_tweens[id].is_valid():
		rotation_tweens[id].kill()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		nodes[id], "quaternion", Quaternion(Vector3.UP, int(model.pieces[id].turn) * PI * 0.5), 0.18
	)
	rotation_tweens[id] = tween
	dirty = true
	status.text = "Eine Vierteldrehung. Vergleiche Bild und Form."
	var at := Vector2(nodes[id].position.x, nodes[id].position.z)
	if dragging == id:
		_update_hover(at)
	elif model.is_near_target(id, at) and at.distance_to(model.target(id)) <= model.snap_limit():
		# Turning a piece already at its slot completes the same placement as
		# a drag. There is no extra hidden tap required to accept the right turn.
		_apply_drop(id, at)
	_labels()


func _plane(at: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(at)
	var direction := camera.project_ray_normal(at)
	var point := origin + direction * ((0.35 - origin.y) / direction.y)
	return Vector2(point.x, point.z)


func _visual(id: int) -> MeshInstance3D:
	if id < 0 or id >= nodes.size():
		return null
	return nodes[id].get_node_or_null("Visual") as MeshInstance3D


func _set_overlay(id: int, color: Color) -> void:
	var visual: MeshInstance3D = _visual(id)
	if visual == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = color
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.emission_enabled = true
	overlay.emission = Color(color.r, color.g, color.b)
	overlay.emission_energy_multiplier = 0.55
	visual.material_overlay = overlay


func _clear_overlay(id: int) -> void:
	var visual: MeshInstance3D = _visual(id)
	if visual != null:
		visual.material_overlay = null


func _pick(at: Vector2, index: int) -> void:
	if paused or dragging >= 0:
		return
	var origin := camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(at) * 100
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("piece"):
		return
	var id: int = int(hit.collider.get_meta("piece"))
	if model.pieces[id].locked:
		return
	_clear_selection()
	selected_piece = id
	dragging = id
	finger = index
	matching_hover = false
	drag_offset = Vector2(nodes[id].position.x, nodes[id].position.z) - _plane(at)
	nodes[id].position.y = 0.8
	nodes[id].scale = Vector3(1.08, 1.08, 1.08)
	_set_overlay(id, Color(1.0, 0.86, 0.35, 0.22))
	_update_rotate_button()


func _drag(at: Vector2) -> void:
	if dragging < 0:
		return
	var position_2d := _plane(at) + drag_offset
	nodes[dragging].position = Vector3(
		clampf(position_2d.x, -9, 9), 0.8, clampf(position_2d.y, -5, 5)
	)
	var at2 := Vector2(nodes[dragging].position.x, nodes[dragging].position.z)
	_update_hover(at2)


func _update_hover(at2: Vector2) -> void:
	if dragging < 0:
		return
	var near: bool = model.is_near_target(dragging, at2)
	matching_hover = near
	if near:
		_set_overlay(dragging, Color(0.45, 0.92, 1.0, 0.32))
		var slot := model.target(dragging)
		hover_marker.position = Vector3(slot.x, 0.195, slot.y)
		hover_marker.scale = Vector3(model.cell_size().x * 0.92, 1, model.cell_size().y * 0.92)
		hover_marker.show()
	else:
		_set_overlay(dragging, Color(1.0, 0.86, 0.35, 0.22))
		hover_marker.hide()
		if (
			at2.distance_to(model.target(dragging)) <= model.hover_limit()
			and not model.orientation_matches(dragging)
		):
			status.text = "Der Platz stimmt. Drehe das Teil noch mit ↻."


func _drop() -> void:
	if dragging < 0:
		return
	var id: int = dragging
	var at := Vector2(nodes[id].position.x, nodes[id].position.z)
	dragging = -1
	finger = -1
	matching_hover = false
	hover_marker.hide()
	_apply_drop(id, at)


func _apply_drop(id: int, at: Vector2) -> void:
	var snapped: bool = model.try_snap(id, at)
	if snapped:
		selected_piece = -1
		var target := model.target(id)
		create_tween().tween_property(
			nodes[id], "position", Vector3(target.x, 0.14, target.y), 0.18
		)
		_play_snap_fx(id)
		status.text = "Das passt! Dein Bild wächst."
	else:
		nodes[id].position.y = 0.15
		nodes[id].scale = Vector3.ONE
		if model.rotation_enabled:
			_set_overlay(id, Color(1.0, 0.86, 0.35, 0.15))
		else:
			_clear_overlay(id)
		status.text = (
			"Der Platz stimmt. Drehe das Teil noch mit ↻."
			if (
				not model.orientation_matches(id)
				and at.distance_to(model.target(id)) <= model.hover_limit()
			)
			else "Probiere einen anderen Platz. Schau auf Form und Bild."
		)
	dirty = true
	_labels()
	if model.complete():
		_win()


func _play_snap_fx(id: int) -> void:
	last_snap_fx = true
	nodes[id].scale = Vector3(1.14, 1.14, 1.14)
	_set_overlay(id, Color(1.0, 0.92, 0.45, 0.4))
	var tw := create_tween()
	tw.tween_property(nodes[id], "scale", Vector3.ONE, 0.2)
	tw.tween_callback(_clear_overlay.bind(id))
	if snap_burst != null:
		snap_burst.global_position = nodes[id].global_position + Vector3(0, 0.25, 0)
		snap_burst.restart()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_menu()
	if paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_rotate_selected()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pick(event.position, 0)
		elif finger == 0:
			_drop()
	elif event is InputEventMouseMotion and finger == 0:
		_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pick(event.position, event.index)
		elif finger == event.index:
			_drop()
	elif event is InputEventScreenDrag and finger == event.index:
		_drag(event.position)


func _input(event: InputEvent) -> void:
	# Releasing above a UI button must still release the captured puzzle piece.
	if event is InputEventScreenTouch and not event.pressed and finger == event.index:
		_drop()
	if event is InputEventMouseButton and not event.pressed and finger == 0:
		_drop()


func _hint() -> void:
	if paused:
		return
	_drop()
	for i in range(model.count):
		if not model.pieces[i].locked and nodes[i].visible:
			_clear_selection()
			selected_piece = i
			_set_overlay(i, Color(1.0, 0.86, 0.35, 0.18))
			nodes[i].position.y = 0.48
			model.hints += 1
			var at := model.target(i)
			hint_marker.position = Vector3(at.x, 0.20, at.y)
			hint_marker.scale = Vector3(model.cell_size().x * 0.9, 1, model.cell_size().y * 0.9)
			hint_marker.show()
			hint_time = 3
			var tw := create_tween()
			tw.tween_property(nodes[i], "position:y", 0.62, 0.14)
			tw.tween_property(nodes[i], "position:y", 0.48, 0.14)
			var turns := posmod(-int(model.pieces[i].get("turn", 0)), 4)
			status.text = (
				"Drehe das angehobene Teil noch %d-mal mit ↻, dann passt es zum Licht." % turns
				if turns > 0
				else "Das angehobene Teil passt auf den leuchtenden Platz."
			)
			_labels()
			dirty = true
			return


func _process(delta: float) -> void:
	if hint_time > 0:
		hint_time -= delta
		hint_marker.scale = Vector3(
			hint_marker.scale.x,
			1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.15,
			hint_marker.scale.z
		)
		if hint_time <= 0:
			hint_marker.hide()
	if paused:
		return
	model.elapsed += delta
	save_clock += delta
	if dirty and save_clock >= 2:
		save_clock = 0
		_save()


func _save() -> bool:
	if model.pieces.is_empty():
		return true
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(model.to_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		status.text = "Speichern fehlgeschlagen. Dein Puzzle bleibt geöffnet."
		return false
	dirty = false
	return true


func _pause_menu() -> void:
	if paused and not model.pieces.is_empty():
		paused = false
		menu.hide()
		return
	_drop()
	_save()
	_clear_menu()
	menu_box.add_child(KIT.label("Dein Puzzle wartet auf dich", 26))
	menu_box.add_child(KIT.button("Weiterpuzzeln", _continue))
	menu_box.add_child(KIT.button("Anderes Puzzle", _show_selection))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _continue() -> void:
	paused = false
	menu.hide()


func _win() -> void:
	if not _save():
		return
	_make_alive()
	var earned: int = 3 if model.hints <= 2 else 2
	HostBridge.reward(
		{
			"resultId": model.result_id,
			"game": "puzzle",
			"status": "completed",
			"stars": earned,
			"xp": 12 + model.count / 3
		}
	)
	_clear_menu()
	menu_box.add_child(KIT.label("Dein Bild ist fertig!", 28))
	menu_box.add_child(
		KIT.label("%d Teile · %d Sterne · %d Züge" % [model.count, earned, model.moves], 20)
	)
	menu_box.add_child(KIT.button("Bild bewundern", _continue))
	menu_box.add_child(KIT.button("Nächstes Puzzle", _show_selection))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _notification(what: int) -> void:
	if (
		what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]
		and is_instance_valid(menu)
	):
		_drop()
		_save()
		if not paused:
			_pause_menu()


func _leave() -> void:
	if _save():
		SceneRouter.goto("games")


func _gold() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d6b25a")
	mat.metallic = 0.82
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color("a67c28")
	mat.emission_energy_multiplier = 0.18
	return mat


func _table_wood(tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TABLE_SHADER
	mat.set_shader_parameter("grain_texture", KIT.WOOD)
	mat.set_shader_parameter("wood_color", tint)
	return mat


func _atelier_backdrop() -> void:
	ART.apply(self, kit, preview_tier)


func _make_alive_picture() -> void:
	alive_picture = MeshInstance3D.new()
	alive_picture.name = "AlivePicture"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	alive_picture.mesh = plane
	alive_picture.position.y = 0.32
	alive_picture.hide()
	add_child(alive_picture)


func _make_snap_burst() -> void:
	snap_burst = GPUParticles3D.new()
	snap_burst.name = "SnapBurst"
	snap_burst.amount = 18
	snap_burst.lifetime = 0.55
	snap_burst.one_shot = true
	snap_burst.explosiveness = 1.0
	snap_burst.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 55.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0, -2.5, 0)
	snap_burst.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.045
	draw.height = 0.09
	draw.radial_segments = 8
	draw.rings = 4
	var spark := StandardMaterial3D.new()
	spark.albedo_color = Color("ffe7a0")
	spark.emission_enabled = true
	spark.emission = Color("ffd36a")
	spark.emission_energy_multiplier = 0.8
	draw.material = spark
	snap_burst.draw_pass_1 = draw
	add_child(snap_burst)


func _make_alive() -> void:
	if model.pieces.is_empty():
		return
	picture_alive = true
	var shader := ShaderMaterial.new()
	shader.shader = ALIVE_SHADER
	shader.set_shader_parameter("picture", MOTIFS[model.motif])
	alive_picture.mesh.size = model.board_size()
	alive_picture.material_override = shader
	# Locked pieces end at y=0.30. The animated picture must sit above them.
	alive_picture.position.y = 0.32
	alive_picture.show()
	if snap_burst != null:
		snap_burst.global_position = Vector3(0, 0.4, 0)
		snap_burst.amount = 28
		snap_burst.restart()
	status.text = "Dein Bild ist lebendig geworden!"


func _hide_alive() -> void:
	picture_alive = false
	if alive_picture != null:
		alive_picture.hide()
	guide.hide()
