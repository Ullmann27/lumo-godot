extends SceneTree
## Native input/render state contracts; authoritative rules are tested in Flutter.
const TABLE = "res://scenes/games/cards_table.tscn"
var checks := 0
var failures := 0
var requests: Array[Dictionary] = []

static func fixture() -> Dictionary:
	return {"protocol": 1, "token": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "revision": 4, "ack": 0,
		"roundId": "cards-render-fixture", "phase": "playing", "paused": false, "reduceMotion": true,
		"viewer": 0, "current": 0, "players": [{"name": "Du", "count": 7, "stars": 0}, {"name": "Lumo", "count": 7, "stars": 0}],
		"hand": [{"id": "r1", "color": "orange", "type": "number", "number": 1, "playable": true},
		{"id": "b2", "color": "blue", "type": "number", "number": 2, "playable": false},
		{"id": "wild", "color": "green", "type": "colorMagic", "playable": true},
		{"id": "g4", "color": "green", "type": "number", "number": 4, "playable": false},
		{"id": "y5", "color": "purple", "type": "number", "number": 5, "playable": true},
		{"id": "r6", "color": "orange", "type": "number", "number": 6, "playable": true},
		{"id": "pause", "color": "blue", "type": "thinkPause", "playable": false}],
		"top": {"id": "r5", "color": "orange", "type": "number", "number": 5}, "selectedColor": "orange", "drawCount": 97,
		"message": "Dein Zug · Goldene Karten passen.", "winner": null, "canDraw": true}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Cards table: " + label)

func _run() -> void:
	var table = load(TABLE).instantiate()
	root.add_child(table)
	table.action_requested.connect(func(request: Dictionary): requests.append(request))
	for shape in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(2400, 1080)]:
		root.size = shape
		get_root().get_node("HostBridge")._options = {"displayDensity": 2.625 if shape.x == 2400 else 1.0}
		await process_frame
		table._resize()
		table.apply_state(fixture())
		await process_frame
		await process_frame
		check(table.actor.is_usable(), "original 65-bone actor loaded")
		check(table.hand_root.get_child_count() >= 3, "real hand geometry exists")
		var viewport := Rect2(Vector2.ZERO, Vector2(shape))
		for button in table.ui.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				check(button.size.y / table._ui_scale >= 48, "48dp action target")
				check(viewport.encloses(button.get_global_rect()), "action inside viewport: " + button.text)
		var legal = table._cards["r1"]
		var point: Vector2 = table.camera.unproject_position(legal.global_position)
		check(viewport.has_point(point), "card projects into viewport")
		var touch := InputEventScreenTouch.new()
		touch.index = 2
		touch.pressed = true
		touch.position = point
		table._unhandled_input(touch)
		check(table._selected == "r1", "native touch selects legal mesh")
		check(requests.is_empty(), "single tap does not accidentally play")
		touch.position = table.camera.unproject_position(legal.global_position)
		table._unhandled_input(touch)
		check(requests.size() == 1 and requests[0].action == "play" and requests[0].cardId == "r1", "second tap emits exact card action")
		check(requests[0].revision == 4, "command binds published revision")
		table._send("draw")
		check(requests.size() == 1, "pending action prevents second command")
		var acknowledged := fixture()
		acknowledged.ack = requests[0].sequence
		acknowledged.revision = 5
		table.apply_state(acknowledged)
		check(table._pending == 0, "only acknowledgement releases input")
		requests.clear()
		table._selected = ""
		var hidden := fixture()
		hidden.phase = "passDevice"
		hidden.hand = []
		table.apply_state(hidden)
		await process_frame
		check(table._cards.is_empty() and table.modal.visible, "handover hides hand")
		var question := fixture()
		question.phase = "learningQuestion"
		question.question = {"prompt": "Was ist 8 + 5?", "options": ["11", "13", "15"]}
		table.apply_state(question)
		await process_frame
		var answer_buttons: Array = table.modal_content.find_children("*", "Button", true, false)
		check(answer_buttons.size() == 3, "learning choices use authoritative question")
		answer_buttons[1].pressed.emit()
		check(requests.size() == 1 and requests[0].action == "answer" and requests[0].index == 1, "native choice emits answer index")
		requests.clear()
		table._pending = 0
		table._sequence = 0
		table._page = 0
	table.queue_free()
	await process_frame
	print("CARDS_TABLE_RUNTIME_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
