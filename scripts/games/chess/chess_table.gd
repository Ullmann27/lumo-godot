extends Control

const RULES = preload("res://scripts/games/chess/chess_position.gd")
const BOARD = preload("res://scripts/games/chess/chess_board.gd")
const DIFFICULTIES := ["Anfänger", "Fortgeschritten", "Meister", "Militärschachspieler"]
const PIECES := ["", "Bauer", "Springer", "Läufer", "Turm", "Dame", "König"]
const GUIDED := [Vector3i(52, 36, 0), Vector3i(61, 34, 0), Vector3i(59, 31, 0), Vector3i(31, 13, 0)]
const REPLIES := [Vector3i(12, 28, 0), Vector3i(1, 18, 0), Vector3i(6, 21, 0)]
const LESSON := [
	"Weiß beginnt. Tippe auf den Bauern vor deinem König (e2) und dann auf e4. Beim ersten Zug darf er zwei freie Felder geradeaus gehen.",
	"Jetzt der Läufer. Ziehe ihn von f1 nach c4. Läufer gehen diagonal, solange der Weg frei ist.",
	"Ziehe die Dame von d1 nach h5. Sie geht gerade oder diagonal. Schau, wie Dame und Läufer jetzt beide f7 angreifen.",
	"Ziehe die Dame von h5 nach f7 und schlage den Bauern. Der Läufer deckt die Dame. Schwarz kann seinen König nicht mehr retten.",
]
const NONE := Vector3i(-1, -1, 0)

var _position = RULES.new()
var _board: SubViewportContainer
var _heading: Label
var _message: Label
var _options: VBoxContainer
var _controls: HBoxContainer
var _settings: Button
var _inset: MarginContainer
var _body: BoxContainer
var _actions: VBoxContainer
var _selection := -1
var _last := NONE
var _available: Array[Vector3i] = []
var _promotion: Array[Vector3i] = []
var _occurrences: Dictionary = {}
var _level := 0
var _step := 0
var _lesson := false
var _active := false
var _thinking := false
var _round := 0
var _hint := false
var _worker: Thread
var _result_id := ""


func _ready() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("102035")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_inset = MarginContainer.new()
	_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_inset.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	_button(bar, "Zurück", _leave)
	_heading = Label.new()
	_heading.text = "Lumo Schach"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.clip_text = true
	_heading.add_theme_font_size_override("font_size", 21)
	bar.add_child(_heading)
	_settings = _button(bar, "Spielwahl", _show_menu)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 44
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color("f6ddad"))
	_message.add_theme_font_size_override("font_size", 17)
	column.add_child(_message)
	_body = BoxContainer.new()
	_body.vertical = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	column.add_child(_body)
	_board = BOARD.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size.y = 136
	_board.square_pressed.connect(_pick)
	_body.add_child(_board)
	_actions = VBoxContainer.new()
	_body.add_child(_actions)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	_actions.add_child(_options)
	_controls = HBoxContainer.new()
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.add_theme_constant_override("separation", 6)
	_actions.add_child(_controls)
	HostBridge.return_failed.connect(_on_return_failed)
	resized.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	_layout()
	_show_menu()


func _layout() -> void:
	var density := MobileRuntime.get_ui_density()
	if OS.has_feature("mobile"):
		get_window().content_scale_size = Vector2i(Vector2(get_window().size) / density)
	var safe := MobileRuntime.get_safe_area_insets() if OS.has_feature("mobile") else Rect2()
	_inset.add_theme_constant_override("margin_left", 12 + roundi(safe.position.x / density))
	_inset.add_theme_constant_override("margin_right", 12 + roundi(safe.size.x / density))
	_inset.add_theme_constant_override("margin_top", 8 + roundi(safe.position.y / density))
	_inset.add_theme_constant_override("margin_bottom", 8 + roundi(safe.size.y / density))
	_body.vertical = size.x < 580 or size.x < size.y * 1.2
	_actions.custom_minimum_size.x = 0 if _body.vertical or (_options.get_child_count() == 0 and _controls.get_child_count() == 0) else 245


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		_leave()


func _exit_tree() -> void:
	if _worker != null:
		_worker.wait_to_finish()


func _leave() -> void:
	SceneRouter.goto("games")


func _on_return_failed(message: String) -> void:
	_message.text = message


func _button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color("fff1d7"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263e54") if state == "normal" else Color("37616e")
		style.border_color = Color("b99965") if state in ["hover", "focus"] else Color("436479")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 9
		style.content_margin_right = 9
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _show_menu() -> void:
	if _thinking:
		return
	_round += 1
	_active = false
	_settings.hide()
	_heading.text = "Lumo Schach"
	_message.text = "Lerne die ersten Züge mit Lumo oder spiele gegen ihn."
	_clear(_options)
	_clear(_controls)
	_button(_options, "Schach lernen · geführtes Probespiel", _start.bind(true, 0))
	for first in [0, 2]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_options.add_child(row)
		for level in range(first, first + 2):
			var entry := _button(row, DIFFICULTIES[level], _start.bind(false, level))
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.clip_text = true
			if level == 3:
				entry.add_theme_font_size_override("font_size", 13)
	_position = RULES.new()
	_last = NONE
	_selection = -1
	_hint = false
	_layout()
	_redraw()


func _start(lesson: bool, level: int) -> void:
	_round += 1
	_active = true
	_lesson = lesson
	_level = level
	_step = 0
	_hint = false
	_selection = -1
	_last = NONE
	_promotion.clear()
	_position = RULES.new()
	_available = _position.legal_moves()
	_occurrences = {_position.repetition_key(): 1}
	_result_id = HostBridge.new_result_id() + "-chess"
	_heading.text = "Schach lernen" if lesson else "Lumo Schach"
	_settings.show()
	_clear(_options)
	_update_controls()
	_update_message()
	_redraw()


func _update_controls() -> void:
	_clear(_controls)
	if not _active:
		return
	if not _promotion.is_empty():
		for move in _promotion:
			_button(_controls, PIECES[move.z], _apply.bind(move))
	elif not _lesson:
		_button(_controls, "Hinweis", _show_hint)
	_layout()


func _show_hint() -> void:
	if not _active or _thinking:
		return
	_hint = true
	_selection = -1
	_message.text = "Tipp: Die markierte Figur hat einen möglichen Zug."
	_redraw()


func _update_message() -> void:
	if _thinking:
		_message.text = "Lumo überlegt …"
	elif not _promotion.is_empty():
		_message.text = "Dein Bauer erreicht das Ende. Wähle eine neue Figur."
	elif _lesson and _step < LESSON.size():
		_message.text = LESSON[_step]
	elif _position.in_check(1):
		_message.text = "Schach! Bringe deinen König in Sicherheit."
	else:
		_message.text = "Weiß ist am Zug. Wähle deine Figur und ihr Zielfeld."


func _pick(index: int) -> void:
	if not _active or _thinking or _position.side < 0 or not _promotion.is_empty():
		return
	if _lesson and index != GUIDED[_step].x and not (_selection == GUIDED[_step].x and index == GUIDED[_step].y):
		_message.text = "Probier zuerst die beiden leuchtenden Felder. " + LESSON[_step]
		return
	if index == _selection:
		_selection = -1
	elif _position.board[index] > 0:
		_selection = index
		_hint = false
		_message.text = "%s %s · Wähle ein markiertes Zielfeld." % [PIECES[_position.board[index]], RULES.square_name(index)]
	else:
		var choices: Array[Vector3i] = _available.filter(
			func(move: Vector3i) -> bool: return move.x == _selection and move.y == index
		)
		if choices.size() == 1:
			_apply(choices[0])
			return
		if choices.size() > 1:
			_promotion = choices
			_update_controls()
			_update_message()
			return
		_message.text = "Dieses Feld ist für die gewählte Figur nicht erreichbar."
	_redraw()


func _apply(move: Vector3i) -> void:
	var moved_by: int = _position.side
	_position = _position.after(move)
	_last = move
	_selection = -1
	_hint = false
	_promotion.clear()
	_available = _position.legal_moves()
	var key: String = _position.repetition_key()
	_occurrences[key] = int(_occurrences.get(key, 0)) + 1
	if _available.is_empty():
		_finish(moved_by if _position.in_check(_position.side) else 0, "Patt")
	elif _position.dead_position() or _position.quiet_plies >= 100 or _occurrences[key] >= 3:
		_finish(0, "Remis")
	elif moved_by == 1:
		_thinking = true
		_settings.disabled = true
		var serial := _round
		get_tree().create_timer(0.30).timeout.connect(
			func() -> void:
				if serial == _round and _active:
					_computer_reply()
		)
	else:
		_step += 1
	if _active:
		_update_message()
	_update_controls()
	_redraw()


func _computer_reply() -> void:
	if _lesson:
		_receive_reply(REPLIES[_step])
		return
	_worker = Thread.new()
	var error := _worker.start(_position.computer_move.bind(_level, _available))
	if error != OK:
		_worker = null
		_receive_reply(_available[0])


func _process(_delta: float) -> void:
	if _worker == null or _worker.is_alive():
		return
	var move: Vector3i = _worker.wait_to_finish()
	_worker = null
	_receive_reply(move)


func _receive_reply(move: Vector3i) -> void:
	_thinking = false
	_settings.disabled = false
	if _available.has(move):
		_apply(move)
	else:
		_apply(_available[0])


func _finish(winner: int, draw_reason: String) -> void:
	_active = false
	var stars := 0
	if winner == 1:
		_message.text = "Schachmatt! Du hast gewonnen."
		stars = 3 if _lesson else 3 + _level
	elif winner == -1:
		_message.text = "Schachmatt. Lumo hat gewonnen."
	else:
		_message.text = "Unentschieden · %s" % draw_reason
	if stars > 0:
		var id := _result_id
		if _lesson:
			var player := str(HostBridge.launch_options().get("childKey", "standalone"))
			id = "chess-tutorial-v1-" + player.sha256_text().left(20)
		var store := ConfigFile.new()
		const REWARDS := "user://chess-rewards.cfg"
		if not HostBridge.is_embedded():
			store.load(REWARDS)
		if not store.has_section_key("settled", id):
			var accepted := HostBridge.reward({
				"resultId": id, "game": "chess", "status": "completed",
				"stars": stars, "xp": stars * 5,
			})
			if accepted:
				if not HostBridge.is_embedded():
					if _lesson:
						store.set_value("settled", id, true)
						store.save(REWARDS)
					ProgressStore.add_stars(stars)
				_message.text += " +%d Sterne" % stars if not _lesson else " · Lernrunde geschafft"
			else:
				_message.text += " " + HostBridge.SAVE_FAILURE
	_button(_options, "Noch einmal", _start.bind(_lesson, _level))
	_layout()


func _redraw() -> void:
	var targets: Array[int] = []
	for move in _available:
		if move.x == _selection and not targets.has(move.y):
			targets.append(move.y)
	var guide := NONE
	if _active and _position.side == 1:
		if _lesson:
			guide = GUIDED[_step]
		elif _hint and not _available.is_empty():
			guide = _available[0]
	_board.display(_position, _selection, targets, _last, guide)
