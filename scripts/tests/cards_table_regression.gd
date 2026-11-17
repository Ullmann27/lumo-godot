extends SceneTree
## Native input/render state contracts; authoritative rules are tested in Flutter.
const TABLE = "res://scenes/games/cards_table.tscn"
var checks := 0
var failures := 0
var requests: Array[Dictionary] = []


class HeaderReturnHost:
	extends RefCounted
	var destinations: Array[String] = []

	# gdlint: disable=function-name
	func returnToApp(destination: String, _payload: String) -> int:
		destinations.append(destination)
		return 1


static func fixture() -> Dictionary:
	return {
		"protocol": 1,
		"token": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"revision": 4,
		"ack": 0,
		"roundId": "cards-render-fixture",
		"phase": "playing",
		"paused": false,
		"reduceMotion": true,
		"viewer": 0,
		"current": 0,
		"players":
		[{"name": "Du", "count": 7, "stars": 0}, {"name": "Lumo", "count": 7, "stars": 0}],
		"hand":
		[
			{"id": "r1", "color": "orange", "type": "number", "number": 1, "playable": true},
			{"id": "b2", "color": "blue", "type": "number", "number": 2, "playable": false},
			{"id": "wild", "color": "green", "type": "colorMagic", "playable": true},
			{"id": "g4", "color": "green", "type": "number", "number": 4, "playable": false},
			{"id": "y5", "color": "purple", "type": "number", "number": 5, "playable": true},
			{"id": "r6", "color": "orange", "type": "number", "number": 6, "playable": true},
			{"id": "pause", "color": "blue", "type": "thinkPause", "playable": false}
		],
		"top": {"id": "r5", "color": "orange", "type": "number", "number": 5},
		"selectedColor": "orange",
		"drawCount": 97,
		"message": "Dein Zug · Goldene Karten passen.",
		"winner": null,
		"canDraw": true
	}


static func wire_fixture() -> Dictionary:
	# The Android mailbox crosses JSON; all its numbers arrive as floats.
	return JSON.parse_string(JSON.stringify(fixture()))


static func face_texture_errors(table: Node3D) -> Array[String]:
	var expected := {
		"r1": "red/red_1.png",
		"b2": "blue/blue_2.png",
		"wild": "special/color_magic.png",
		"g4": "green/green_4.png",
		"y5": "yellow/yellow_5.png",
		"r6": "red/red_6.png",
		"pause": "blue/blue_think_pause.png",
		"r5": "red/red_5.png"
	}
	var nodes: Dictionary = table._cards.duplicate()
	if table.discard_root.get_child_count() > 0:
		nodes["r5"] = table.discard_root.get_child(table.discard_root.get_child_count() - 1)
	var errors: Array[String] = []
	for id: String in nodes:
		var found := false
		for child in nodes[id].get_children():
			if child is MeshInstance3D and child.mesh is PlaneMesh:
				var material: StandardMaterial3D = child.material_override
				var texture: Texture2D = material.albedo_texture if material != null else null
				found = (
					texture != null
					and texture.resource_path == "res://assets/cards_table/cards/" + expected[id]
					and texture.get_width() > 0
					and texture.get_height() > 0
				)
		if not found:
			errors.append("missing/wrong actual face material: " + id)
	return errors


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
	var batched_instances := 0
	for batch: MultiMeshInstance3D in table.room_batches:
		batched_instances += batch.multimesh.instance_count
		check(
			batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
			"room batching preserves cast shadows"
		)
	check(
		batched_instances == table.room_source_boxes, "batching preserves every original room box"
	)
	check(
		table.room_batches.size() * 5 < batched_instances,
		"static room boxes use at least five times fewer instances"
	)
	for group in range(3):
		var floor_batch: MultiMeshInstance3D = table.get_node("RoomBatch_floor%d" % group)
		check(
			floor_batch.multimesh.instance_count == [7, 7, 6][group],
			"all twenty floor planks survive batching"
		)
		# The dummy headless renderer does not retain MultiMesh transforms.
		# The real-renderer capture checks all twenty uploaded transforms instead.
	for group in range(4):
		var book_batch: MultiMeshInstance3D = table.get_node("RoomBatch_cloth_book%d" % group)
		check(
			book_batch.multimesh.instance_count == [8, 8, 8, 6][group],
			"all thirty cloth-bound books remain actual geometry"
		)
	check(
		table.find_children("*", "OmniLight3D", false, false).size() == 3,
		"room light sources remain unchanged"
	)
	print(
		"CARDS_ROOM_BATCHES sources=%d batches=%d" % [batched_instances, table.room_batches.size()]
	)
	check(
		typeof(wire_fixture().top.number) == TYPE_FLOAT, "fixture exercises actual JSON number type"
	)
	var folders := {"orange": "red", "purple": "yellow", "blue": "blue", "green": "green"}
	for color: String in folders:
		for number in range(10):
			var card: Dictionary = JSON.parse_string(
				JSON.stringify({"color": color, "type": "number", "number": number})
			)
			var texture: Texture2D = table._texture(card, true)
			var expected := (
				"res://assets/cards_table/cards/%s/%s_%d.png"
				% [folders[color], folders[color], number]
			)
			check(
				texture != null and texture.resource_path == expected,
				"JSON card resolves original number face: %s %d" % [color, number]
			)
	for shape in [
		Vector2i(1280, 720),
		Vector2i(412, 915),
		Vector2i(690, 829),
		Vector2i(2400, 1080),
		Vector2i(1080, 2400)
	]:
		root.size = shape
		get_root().get_node("HostBridge")._options = {
			"displayDensity": 2.625 if shape.x == 2400 or shape.y == 2400 else 1.0
		}
		await process_frame
		table._resize()
		table.apply_state(wire_fixture())
		await process_frame
		await process_frame
		var face_errors := face_texture_errors(table)
		check(
			face_errors.is_empty(), "JSON hand and discard bind face textures: " + str(face_errors)
		)
		await _header_safe_area(table, shape)
		check(table.actor.is_usable(), "original 65-bone actor loaded")
		var hips: Vector3 = table.actor.skeleton.to_global(
			table.actor.skeleton.get_bone_global_pose(table.seated.pelvis).origin
		)
		check(
			hips.distance_to(table.seated.seat) < 0.015,
			"authored seated pelvis contacts actual chair"
		)
		check(table.seated.legs.size() == 10, "seated lower body preserved during reactions")
		check(table.hand_root.get_child_count() >= 3, "real hand geometry exists")
		var viewport := Rect2(Vector2.ZERO, Vector2(shape))
		for button in table.ui.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				check(button.size.y / table._ui_scale >= 48, "48dp action target")
				check(
					viewport.encloses(button.get_global_rect()),
					"action inside viewport: " + button.text
				)
		var discard_node: Node3D = table.discard_root.get_child(
			table.discard_root.get_child_count() - 1
		)
		var discard_bottom := 0.0
		for corner in [
			Vector3(-0.415, 0.02, -0.59),
			Vector3(0.415, 0.02, -0.59),
			Vector3(-0.415, 0.02, 0.59),
			Vector3(0.415, 0.02, 0.59)
		]:
			discard_bottom = maxf(
				discard_bottom, table.camera.unproject_position(discard_node.to_global(corner)).y
			)
		var first_hand: Node3D = table._cards["r1"]
		var hand_top := INF
		for corner in [
			Vector3(-0.415, 0.02, -0.59),
			Vector3(0.415, 0.02, -0.59),
			Vector3(-0.415, 0.02, 0.59),
			Vector3(0.415, 0.02, 0.59)
		]:
			hand_top = minf(
				hand_top, table.camera.unproject_position(first_hand.to_global(corner)).y
			)
		check(discard_bottom < hand_top, "hand never obscures current discard in any density")
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
		check(
			requests.size() == 1 and requests[0].action == "play" and requests[0].cardId == "r1",
			"second tap emits exact card action"
		)
		check(requests[0].revision == 4, "command binds published revision")
		table._send("draw")
		check(requests.size() == 1, "pending action prevents second command")
		var acknowledged := wire_fixture()
		acknowledged.ack = requests[0].sequence
		acknowledged.revision = 5
		table.apply_state(acknowledged)
		check(table._pending == 0, "only acknowledgement releases input")
		requests.clear()
		table._selected = ""
		var hidden := wire_fixture()
		hidden.phase = "passDevice"
		hidden.hand = []
		table.apply_state(hidden)
		await process_frame
		check(table._cards.is_empty() and table.modal.visible, "handover hides hand")
		var question := wire_fixture()
		question.phase = "learningQuestion"
		question.question = {"prompt": "Was ist 8 + 5?", "options": ["11", "13", "15"]}
		table.apply_state(question)
		await process_frame
		var answer_buttons: Array = table.modal_content.find_children("*", "Button", true, false)
		check(answer_buttons.size() == 3, "learning choices use authoritative question")
		answer_buttons[1].pressed.emit()
		check(
			requests.size() == 1 and requests[0].action == "answer" and requests[0].index == 1,
			"native choice emits answer index"
		)
		requests.clear()
		table._pending = 0
		var long_question := wire_fixture()
		long_question.phase = "learningQuestion"
		long_question.round = 2
		long_question.totalRounds = 3
		long_question.question = {
			"prompt":
			"Lumo hat acht Sterne und bekommt fünf dazu. Wie viele Sterne sind es zusammen?",
			"options": ["Zwölf Sterne", "Dreizehn Sterne", "Vierzehn Sterne", "Fünfzehn Sterne"]
		}
		table.apply_state(long_question)
		await process_frame
		await process_frame
		table._layout_modal()
		await process_frame
		check(
			table.heading.text == "Sternenpokal 2/3",
			"native table displays authoritative tournament leg"
		)
		check(
			viewport.encloses(table.modal.get_global_rect()),
			"four-option question panel remains inside viewport"
		)
		for button in table.modal_content.find_children("*", "Button", true, false):
			check(button.size.y / table._ui_scale >= 48, "question answer retains 48dp")
		table._clear_authority_view()
		check(
			table._cards.is_empty() and not table.modal.visible,
			"authority loss hides hand and previous child's learning question"
		)
		check(
			table.status.text.is_empty() and not table.call_button.visible,
			"authority loss hides counters and bonus actions"
		)
		requests.clear()
		table._pending = 0
		table._sequence = 0
		table._page = 0
	await _header_back_touch(table)
	table.queue_free()
	await process_frame
	print(
		(
			"CARDS_TABLE_RUNTIME_%s checks=%d failures=%d"
			% ["PASS" if failures == 0 else "FAIL", checks, failures]
		)
	)
	quit(0 if failures == 0 else 1)


func _tap_header(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 1
		touch.position = point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


func _header_safe_area(table: Node3D, shape: Vector2i) -> void:
	# Insets are a declared geometry fixture, not an Android measurement.
	# Two physical pixels per viewport pixel exercise the actual conversion.
	table.set_process(false)
	var original: Dictionary = table._state.duplicate(true)
	var card_position: Vector3 = table._cards["r1"].position
	var footer_rect: Rect2 = table.footer.get_global_rect()
	table._apply_header_safe_area(Rect2(32, 180, 56, 80), Vector2(shape) * 2)
	await process_frame
	await process_frame
	var safe := Rect2(16, 90, shape.x - 44, shape.y - 130)
	for button: Button in table.header.find_children("*", "Button", true, false):
		check(
			safe.encloses(button.get_global_rect()),
			"header avoids status bar/cutout: " + button.text
		)
		check(
			button.size.x / table._ui_scale >= 48 and button.size.y / table._ui_scale >= 48,
			"safe header retains full 48dp touch target: " + button.text
		)
	check(
		(
			table._state == original
			and table._cards["r1"].position == card_position
			and table.footer.get_global_rect() == footer_rect
		),
		"safe header preserves public state and the existing hand/footer projection"
	)
	await _tap_header(table.pause_button)
	check(
		requests.size() == 1 and requests[0].action == "pause" and requests[0].revision == 4,
		"real touch reaches inset Pause and retains the authoritative revision"
	)
	if requests.size() == 1:
		var paused := original.duplicate(true)
		paused.paused = true
		paused.canDraw = false
		paused.revision = 5
		paused.ack = requests[0].sequence
		table.apply_state(paused)
		await process_frame
		# A changed cutout/rotation must replace the former inset, not accumulate it.
		table._apply_header_safe_area(Rect2(108, 64, 28, 48), Vector2(shape) * 2)
		await process_frame
		safe = Rect2(54, 32, shape.x - 68, shape.y - 56)
		for button: Button in table.header.find_children("*", "Button", true, false):
			check(
				safe.encloses(button.get_global_rect()), "changed safe area keeps header reachable"
			)
		await _tap_header(table.pause_button)
		check(
			requests.size() == 2 and requests[1].action == "resume" and requests[1].revision == 5,
			"real inset Weiter touch requests resume of the same paused round"
		)
	table._pending = 0
	table._sequence = 0
	requests.clear()
	table.apply_state(original)
	# Resume re-reads platform bounds even when the viewport size did not change.
	table._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await process_frame
	var resumed_header: Rect2 = table.header.get_global_rect()
	table._resize()
	await process_frame
	check(
		resumed_header == table.header.get_global_rect() and table._state == original,
		"resume and resize agree on current platform bounds without changing the round"
	)
	table.set_process(true)


func _header_back_touch(table: Node3D) -> void:
	var bridge = root.get_node("HostBridge")
	var previous_host: Object = bridge._host
	var previous_pending: bool = bridge._return_pending
	var host := HeaderReturnHost.new()
	bridge._host = host
	bridge._return_pending = false
	var back: Button = table.header.get_node("Top").get_child(0).get_node("Back")
	await _tap_header(back)
	check(
		host.destinations == ["games"] and table._closed,
		"real Zurück touch keeps the existing acknowledged return to the host"
	)
	bridge._host = previous_host
	bridge._return_pending = previous_pending
