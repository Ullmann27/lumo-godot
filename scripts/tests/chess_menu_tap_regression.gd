extends SceneTree
## Lumo Schach: Ein echter Fingertipp auf einen Menüknopf, der das Menü
## wechselt („Schach lernen“, dann eine Lektion), lässt den getippten Knopf
## bis zu seiner Löschung im Baum. Vorher verschwand er mitten im Tipp aus dem
## Baum und der Viewport meldete „!is_inside_tree()“ (rote Zeilen in der CI).

const TABLE := "res://scenes/games/chess_table.tscn"
const CHILD := "chess-menu-tap-regression"
const SESSION = preload("res://scripts/games/chess/chess_session.gd")

var checks: int = 0
var failures: Array[String] = []
var table: Node
var in_tree_after_press: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[ChessMenuTap] FAIL " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _screen_center(control: Control) -> Vector2:
	var xform: Transform2D = root.get_final_transform() * control.get_global_transform_with_canvas()
	return (xform * Rect2(Vector2.ZERO, control.size)).get_center()


func _finger_tap(button: Button) -> void:
	var at: Vector2 = _screen_center(button)
	button.pressed.connect(func(): in_tree_after_press.append(button.is_inside_tree()))
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _frames(3)


func _run() -> void:
	var bridge: Node = root.get_node("HostBridge")
	bridge._options = {"displayDensity": 2.625, "childKey": CHILD, "soundEnabled": false}
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	var previous := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(1080, 2340)
	table = load(TABLE).instantiate()
	root.add_child(table)
	await _frames(8)
	var kids: Button = table.find_button("o_Kids")
	_check(kids != null and kids.is_visible_in_tree(), "Knopf „Schach lernen“ sichtbar")
	if kids != null:
		await _finger_tap(kids)
		_check(
			in_tree_after_press == [true],
			"getippter Knopf bleibt im Baum (%s)" % str(in_tree_after_press)
		)
		_check(not is_instance_valid(kids), "alter Knopf danach gelöscht")
	var lesson: Button = null
	for id in table.buttons.keys():
		var button: Button = table.buttons[id]
		if (
			str(id).begins_with("o_")
			and is_instance_valid(button)
			and button.is_visible_in_tree()
			and button.text.contains("Brett")
		):
			lesson = button
	_check(lesson != null, "Lektion „Das Brett“ nach dem Tipp sichtbar")
	if lesson != null:
		in_tree_after_press.clear()
		await _finger_tap(lesson)
		_check(in_tree_after_press == [true], "Lektionsknopf bleibt beim Tippen im Baum")
	var retired: Node = table.find_child("RetiredOverlay", true, false)
	_check(retired != null and retired.get_child_count() == 0, "keine alten Knöpfe bleiben liegen")
	Input.emulate_mouse_from_touch = previous
	table.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("[ChessMenuTap] PASS: %d checks" % checks)
	else:
		print("[ChessMenuTap] FAIL: %d of %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
