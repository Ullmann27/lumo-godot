extends Node3D
const STATE = preload("res://scripts/creative/puzzle_state.gd")
const PIECE = preload("res://scripts/creative/puzzle_piece.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const MOTIFS = [
	preload("res://assets/creative/puzzle/moonlight.webp"),
	preload("res://assets/creative/puzzle/candy.webp"),
	preload("res://assets/creative/puzzle/volcano.webp")
]
const TITLES = ["Lumos Mondschloss", "Candy Cloud Circuit", "Volcano Night Run"]
var model = STATE.new()
var kit = KIT.new()
var previous: Dictionary
var camera: Camera3D
var safe_ui: Control
var piece_root: Node3D
var nodes: Array[StaticBody3D] = []
var guide: MeshInstance3D
var board_frame: MeshInstance3D
var board_base: MeshInstance3D
var hint_marker: MeshInstance3D
var info: Label
var status: Label
var menu: PanelContainer
var menu_box: VBoxContainer
var progress: ProgressBar
var selected_count: int = 12
var selected_motif: int = 0
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


func _ready() -> void:
	previous = RUNTIME.enter(self)
	SceneRouter.current_scene_id = "puzzle"
	var child := (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	save_path = "user://lumo_puzzle_" + child + ".json"
	kit.environment(self)
	kit.box(self, Vector3(0, -0.28, 0), Vector3(22, 0.45, 11), Color("142e53"))
	board_frame = kit.box(self, Vector3(0, -0.015, 0), Vector3.ONE, Color("8ac9e8"), true)
	board_base = kit.box(self, Vector3(0, 0.07, 0), Vector3.ONE, Color("142942"))
	for side in [-1.0, 1.0]:
		kit.box(self, Vector3(side * 7.3, -0.02, 0), Vector3(4.6, 0.16, 6.8), Color("294369"))
		kit.castle(self, Vector3(side * 12, -0.5, -8), 0.8)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.position = Vector3(0, 17, 8)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
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
	_ui()
	get_viewport().size_changed.connect(func(): RUNTIME.safe_area(self, safe_ui))
	RUNTIME.safe_area(self, safe_ui)
	_show_selection()


func _exit_tree() -> void:
	RUNTIME.restore(self, previous)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	top.add_child(KIT.label("LUMOS PUZZLE-ATELIER", 24))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	info = KIT.label("", 18)
	top.add_child(info)
	top.add_child(KIT.button("Ⅱ", _pause_menu, 52))
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tools.offset_top = -68
	tools.offset_bottom = -12
	tools.offset_left = 14
	tools.offset_right = -14
	safe_ui.add_child(tools)
	tools.add_child(KIT.button("‹ Teile", _page.bind(-1)))
	tools.add_child(KIT.button("Teile ›", _page.bind(1)))
	tools.add_child(KIT.button("Randteile", _edges))
	var show := KIT.button("Bild ansehen", func(): pass)
	show.button_down.connect(func(): guide.visible = true)
	show.button_up.connect(func(): guide.visible = false)
	tools.add_child(show)
	tools.add_child(KIT.button("Ein Tipp", _hint))
	tools.add_child(KIT.button("Speichern", _save))
	tools.add_child(KIT.button("Neues Puzzle", _show_selection))
	status = KIT.label("Ziehe ein Teil auf seinen Platz. Es rastet ein, wenn es passt.", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.position = Vector2(16, 80)
	safe_ui.add_child(status)
	progress = ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress.position.y = 112
	progress.offset_left = 14
	progress.offset_right = -14
	progress.custom_minimum_size.y = 6
	progress.show_percentage = false
	safe_ui.add_child(progress)
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", KIT.panel())
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-235, -180)
	menu.custom_minimum_size = Vector2(470, 360)
	safe_ui.add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu.add_child(menu_box)


func _clear_menu() -> void:
	paused = true
	dragging = -1
	finger = -1
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	menu.show()


func _show_selection() -> void:
	if not model.pieces.is_empty():
		_save()
	_clear_menu()
	menu_box.add_child(KIT.label("Stück für Stück entsteht deine Welt", 23))
	menu_box.add_child(KIT.button(TITLES[selected_motif], _next_motif))
	menu_box.add_child(KIT.button("%d echte Puzzleteile" % selected_count, _next_count))
	menu_box.add_child(KIT.button("Neues Puzzle beginnen", start))
	if FileAccess.file_exists(save_path):
		menu_box.add_child(KIT.button("Gespeichertes Puzzle fortsetzen", _resume))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _next_count() -> void:
	selected_count = STATE.COUNTS[(STATE.COUNTS.find(selected_count) + 1) % 4]
	_show_selection()


func _next_motif() -> void:
	selected_motif = (selected_motif + 1) % 3
	_show_selection()


func start() -> void:
	model.setup(selected_count, selected_motif)
	model.result_id = HostBridge.new_result_id()
	tray_page = 0
	edges_only = false
	_build_pieces()
	paused = false
	menu.hide()
	dirty = true
	_save()


func _resume() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not saved is Dictionary or not model.restore(saved):
		status.text = "Dieser Spielstand konnte nicht geöffnet werden. Dein offenes Puzzle bleibt erhalten."
		return
	selected_count = model.count
	selected_motif = model.motif
	tray_page = 0
	_build_pieces()
	paused = false
	menu.hide()
	if model.complete():
		_win()


func _build_pieces() -> void:
	var size: Vector2 = model.board_size()
	board_frame.scale = Vector3(size.x + 0.4, 0.1, size.y + 0.4)
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
		if model.pieces[i].locked:
			node.show()
			node.position = Vector3(model.target(i).x, 0.14, model.target(i).y)
		elif not bool(model.pieces[i].get("tray", true)):
			node.show()
			node.position = Vector3(model.pieces[i].x, 0.15, model.pieces[i].z)
		else:
			node.hide()
			if not edges_only or model.is_edge(i):
				pending.append(i)
	var per_side: int = [3, 3, 4, 5][STATE.COUNTS.find(model.count)]
	var page_size: int = per_side * 2
	var pages: int = maxi(1, ceili(float(pending.size()) / page_size))
	tray_page = posmod(tray_page, pages)
	for p in range(tray_page * page_size, mini((tray_page + 1) * page_size, pending.size())):
		var i: int = pending[p]
		var local: int = p % page_size
		var x: float = -7.0 if local < per_side else 7.0
		var z: float = -2.2 + (local % per_side) * (4.4 / maxi(1, per_side - 1))
		model.pieces[i].x = x
		model.pieces[i].z = z
		nodes[i].position = Vector3(x, 0.15, z)
		nodes[i].show()


func _page(direction: int) -> void:
	if paused:
		return
	tray_page += direction
	_tray()


func _edges() -> void:
	if paused:
		return
	edges_only = not edges_only
	tray_page = 0
	_tray()
	status.text = "Nur Randteile angezeigt." if edges_only else "Alle Teile angezeigt."


func _labels() -> void:
	info.text = "%d / %d Teile · %d Tipps" % [model.placed(), model.count, model.hints]
	progress.value = float(model.placed()) / maxi(1, model.count) * 100


func _plane(at: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(at)
	var direction := camera.project_ray_normal(at)
	var point := origin + direction * ((0.35 - origin.y) / direction.y)
	return Vector2(point.x, point.z)


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
	dragging = id
	finger = index
	drag_offset = Vector2(nodes[id].position.x, nodes[id].position.z) - _plane(at)
	nodes[id].position.y = 0.8


func _drag(at: Vector2) -> void:
	if dragging < 0:
		return
	var position_2d := _plane(at) + drag_offset
	nodes[dragging].position = Vector3(
		clampf(position_2d.x, -9, 9), 0.8, clampf(position_2d.y, -5, 5)
	)


func _drop() -> void:
	if dragging < 0:
		return
	var id: int = dragging
	var at := Vector2(nodes[id].position.x, nodes[id].position.z)
	var snapped: bool = model.try_snap(id, at)
	dragging = -1
	finger = -1
	if snapped:
		var target := model.target(id)
		create_tween().tween_property(
			nodes[id], "position", Vector3(target.x, 0.14, target.y), 0.18
		)
		status.text = "Das passt! Dein Bild wächst."
	else:
		nodes[id].position.y = 0.15
		status.text = "Probiere einen anderen Platz. Schau auf Form und Bild."
	dirty = true
	_labels()
	if model.complete():
		_win()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_menu()
	if paused:
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
	for i in range(model.count):
		if not model.pieces[i].locked and nodes[i].visible:
			nodes[i].position.y = 0.48
			model.hints += 1
			var at := model.target(i)
			hint_marker.position = Vector3(at.x, 0.20, at.y)
			hint_marker.scale = Vector3(model.cell_size().x * 0.9, 1, model.cell_size().y * 0.9)
			hint_marker.show()
			hint_time = 3
			status.text = "Das angehobene Teil passt auf den leuchtenden Platz."
			_labels()
			dirty = true
			return


func _process(delta: float) -> void:
	if paused:
		return
	model.elapsed += delta
	save_clock += delta
	if dirty and save_clock >= 2:
		save_clock = 0
		_save()
	if hint_time > 0:
		hint_time -= delta
		if hint_time <= 0:
			hint_marker.hide()


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
