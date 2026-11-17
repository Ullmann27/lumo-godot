extends SceneTree
# gdlint: disable=function-name
# The fixture must expose the existing Android bridge's exact method names.
## Independent checks against the actual routed learning scene, not a demo scene.
## This matrix covers bounded native activity kinds, not every Flutter task route.
## SpeechHost is an explicit boundary fixture; it does not synthesize Android TTS.

const WORLD := "res://scenes/learning/learning_world.tscn"
const NEXT_WORLD := "res://scripts/lumo_next/learning_world_next.gd"
const NATIVE_CASES: Array[Dictionary] = [
	{"kind": "bridge_ten", "a": 8, "b": 5},
	{"kind": "addition", "a": 3, "b": 4},
	{"kind": "subtract_ten", "a": 13, "b": 5},
	{"kind": "equal_groups", "a": 3, "b": 4},
	{"kind": "equal_sharing", "a": 12, "b": 3},
	{"kind": "bridge_hundred", "a": 180, "b": 50},
	{"kind": "fraction_parts", "a": 2, "b": 5},
	{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]},
	{"kind": "plant_parts", "plantPart": "leaf"},
	{
		"kind": "english_objects",
		"word": "book",
		"meaning": "Buch",
		"objects": ["book", "pen", "ruler"]
	},
	{
		"kind": "pattern",
		"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck", "Kreis"],
		"choices": ["Stern", "Kreis", "Dreieck"],
		"period": 2
	},
	{
		"kind": "task_card",
		"subject": "Deutsch",
		"unit": "Wörter verstehen",
		"prompt": "Welches Wort bezeichnet ein Tier?",
		"answerChoices": ["Fuchs", "Tisch", "Stein"],
		"explanation": "Lies die Wörter und überlege, welches Tier du kennst."
	},
]
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(360, 800),
	Vector2i(412, 915),
	Vector2i(412, 960),
	Vector2i(750, 832),
	Vector2i(900, 1100),
	Vector2i(1280, 720),
	Vector2i(2400, 1080)
]
var checks := 0
var failures: Array[String] = []
var captured: Array[String] = []
var output_directory := ""
var selected_kinds := PackedStringArray()
var reviewed_kinds: Array[String] = []


class SpeechHost:
	extends RefCounted
	var request: Dictionary = {}
	var packet: Dictionary = {}
	var starts := 0
	var stops := 0

	func speakLearning(payload: String) -> int:
		request = JSON.parse_string(payload)
		packet = _scope_packet()
		packet.merge(
			{
				"id": request.id,
				"state": "preparing",
				"positionMs": 0,
				"durationMs": 3000,
				"audible": false,
				"envelopeAvailable": false,
				"envelope": 0.0
			},
			true
		)
		starts += 1
		return 1

	func getLearningSpeechStatus() -> String:
		return JSON.stringify(packet)

	func stopLearningSpeech() -> void:
		stops += 1

	func measured_playing() -> void:
		packet = _scope_packet()
		packet.merge(
			{
				"id": request.id,
				"state": "playing",
				"positionMs": 80,
				"durationMs": 3000,
				"audible": true,
				"envelopeAvailable": true,
				"envelope": 0.85
			},
			true
		)

	func _scope_packet() -> Dictionary:
		var result := {}
		for key: String in [
			"protocolVersion",
			"sessionId",
			"taskId",
			"revision",
			"cancelEpoch",
			"stepId",
			"turnId",
			"utteranceId",
			"contextRevision"
		]:
			if request.has(key):
				result[key] = request[key]
		return result


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-capture-dir="):
			output_directory = argument.trim_prefix("--review-capture-dir=")
		elif argument.begins_with("--review-kind="):
			selected_kinds = argument.trim_prefix("--review-kind=").split(",", false)
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[NextgenLearningReview] " + message)
	return condition


func _settle() -> void:
	for index in range(6):
		await process_frame


func _run() -> void:
	if not _check(ResourceLoader.exists(NEXT_WORLD), "producer routed adapter is available"):
		_finish()
		return
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	for payload: Dictionary in NATIVE_CASES:
		if not selected_kinds.is_empty() and not selected_kinds.has(str(payload.kind)):
			continue
		reviewed_kinds.append(str(payload.kind))
		root.size = Vector2i(1280, 720)
		bridge._options["displayDensity"] = 1.0
		var host := SpeechHost.new()
		var game = (load(WORLD) as PackedScene).instantiate()
		_check(
			game.get_script().resource_path == NEXT_WORLD,
			"actual scene route uses Chat3 adapter: " + str(payload.kind)
		)
		game.capture_options = {
			"learning": payload.duplicate(true),
			"reduceAnimations": true,
			"learningVoiceEnabled": true,
			"localVoiceLicenseAccepted": true,
			"learningAutoRead": false
		}
		game.capture_options.learning["allowedActions"] = [
			"explain",
			"repeat",
			"slower",
			"hint",
			"highlight",
			"point",
			"look",
			"stop",
			"proposeAnswer"
		]
		game._speech_host = host
		root.add_child(game)
		await _settle()
		game.set_process(false)
		_check(
			game.activity.kind == payload.kind,
			"actual lesson accepts bounded payload: " + str(payload.kind)
		)
		if not _check(
			game.fox.is_usable() and game.fox.get("director") != null,
			"new imported LUMO is actually used: " + str(payload.kind)
		):
			game.queue_free()
			await _settle()
			continue
		game.fox.director.set_process(false)
		_check(
			game.fox.model_load_kind == "imported_packed_scene",
			"scene uses imported GLB: " + str(payload.kind)
		)
		_check(
			not game.fox.registry.target_ids().is_empty(),
			"native kind registers actual objects: " + str(payload.kind)
		)
		if payload.kind in ["pattern", "task_card"] and not is_instance_valid(game.main_button):
			_check(
				false,
				(
					str(payload.kind)
					+ " needs actual scene controls; domain support alone is insufficient"
				)
			)
			game.queue_free()
			await _settle()
			continue
		await _test_layouts(game)
		match payload.kind:
			"bridge_ten":
				await _test_bridge_ten(game)
				await _test_scene_cancellation(game, host)
			"syllables":
				await _test_syllables(game)
				_test_segmented_syllables(game, host)
			"pattern":
				await _test_pattern(game)
			"task_card":
				await _test_task_card_target(game)
		game.queue_free()
		await _settle()
	bridge._options = original_options
	_check(
		not reviewed_kinds.is_empty(), "requested native activity selection was actually exercised"
	)
	_finish()


func _finish() -> void:
	var result := {
		"checks": checks,
		"failures": failures,
		"captures": captured,
		"native_activity_kinds": reviewed_kinds,
		"full_flutter_coverage": false,
		"physical_android_audio_verified": false
	}
	print(
		(
			"[NextgenLearningReview] %s %s"
			% ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(result)]
		)
	)
	quit(0 if failures.is_empty() else 1)


func _domain_snapshot(game: Node3D) -> String:
	return JSON.stringify(
		{
			"kind": game.activity.kind,
			"placed": game.activity.placed,
			"inspected": game.activity.inspected,
			"candidate": game.activity.pattern_candidate,
			"attempts": game.activity.pattern_attempts,
			"hints": game.activity.pattern_hint_level,
			"task_choice": game.activity.get("task_choice"),
			"complete": game.activity.is_complete()
		}
	)


func _test_layouts(game: Node3D) -> void:
	var original_state := _domain_snapshot(game)
	var bridge := root.get_node("HostBridge")
	for dimensions: Vector2i in VIEWPORTS:
		root.size = dimensions
		bridge._options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
		game._layout()
		await _settle()
		_check_layout(game, dimensions)
		if (
			str(game.activity.kind) in ["bridge_ten", "syllables", "pattern", "task_card"]
			and dimensions.x in [412, 750, 1280]
		):
			await _capture(game, "%s_%dx%d" % [game.activity.kind, dimensions.x, dimensions.y])
		_check(
			_domain_snapshot(game) == original_state,
			"resize preserves child answer/learning state: " + str(game.activity.kind)
		)
	root.size = Vector2i(412, 915)
	bridge._options["displayDensity"] = 1.0
	var original_fonts: Dictionary = {}
	for label: Label in [game.title, game.explanation, game.status]:
		original_fonts[label] = label.get_theme_font_size("font_size")
		label.add_theme_font_size_override("font_size", ceili(float(original_fonts[label]) * 1.5))
	game._layout()
	await _settle()
	_check_layout(game, root.size)
	_check(
		_domain_snapshot(game) == original_state,
		"larger native text preserves learning state: " + str(game.activity.kind)
	)
	for label: Label in original_fonts:
		label.add_theme_font_size_override("font_size", original_fonts[label])
	root.size = Vector2i(1280, 720)
	game._layout()
	await _settle()


func _check_layout(game: Node3D, dimensions: Vector2i) -> void:
	var name_value := "%s %s" % [game.activity.kind, dimensions]
	var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
	var heading: Rect2 = game.header.get_global_rect()
	var footer: Rect2 = game.footer.get_global_rect()
	_check(
		viewport.encloses(heading) and viewport.encloses(footer),
		name_value + ": full text panels fit viewport"
	)
	_check(
		heading.end.y + 40 < footer.position.y,
		name_value + ": visible teaching area remains between panels"
	)
	var body := Rect2(
		Vector2(4, heading.end.y + 4),
		Vector2(dimensions.x - 8, maxf(0, footer.position.y - heading.end.y - 8))
	)
	var nodes: Array[Node3D] = [game.fox]
	for id: String in game.fox.registry.target_ids():
		var resolved: Dictionary = game.fox.registry.resolve_target(id)
		if not _check(
			not resolved.is_empty(), name_value + ": target resolves to a live node: " + id
		):
			continue
		# The repeating-group outline is intentionally concealed until a hint.
		# Hidden nodes must not be gaze targets; fit checks apply when visible.
		var object: Node3D = resolved.node
		if not object.is_visible_in_tree():
			_check(
				not game.fox.director.can_target(id),
				"hidden objects cannot attract a point gesture"
			)
			continue
		_check(
			bool(game.fox.registry.viewport_visibility(id, game.camera, body).visible),
			name_value + ": target anchor lies in usable 3D area: " + id
		)
		if not nodes.has(object):
			nodes.append(object)
	for node: Node3D in nodes:
		var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			meshes.append(node)
		for mesh: MeshInstance3D in meshes:
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var projected := _projected_bounds(mesh, game.camera)
			_check(
				body.encloses(projected),
				name_value + ": complete mesh fits clear teaching area: " + str(mesh.get_path())
			)
	var minimum: float = root.get_node("MobileRuntime").get_ui_density() * 48.0
	for button: Button in game.actions.get_children():
		if not button.is_visible_in_tree():
			continue
		var bounds := button.get_global_rect()
		_check(
			viewport.encloses(bounds) and bounds.size.x >= minimum and bounds.size.y >= minimum,
			name_value + ": actual action has 48dp touch target: " + button.text
		)
	_check_relative_layout(game, body, name_value)


func _check_relative_layout(game: Node3D, body: Rect2, label: String) -> void:
	if game.activity.kind not in ["syllables", "task_card"]:
		return
	var teacher := _group_bounds(game.fox, game.camera)
	if game.activity.kind == "task_card":
		var card := _group_bounds(game.get("_task_card"), game.camera)
		_check(
			teacher.end.x + 4.0 <= card.position.x,
			(
				label
				+ ": full teacher and task card have separate horizontal rooms: "
				+ str(teacher)
				+ " / "
				+ str(card)
			)
		)
		return
	var caption := game.content.get_node_or_null("WordCaption") as MeshInstance3D
	if caption == null:
		for node: Node in game.content.get_children():
			if (
				node is MeshInstance3D
				and node.mesh is TextMesh
				and node.mesh.text == game.activity.word
			):
				caption = node
				break
	if not _check(caption != null, label + ": the actual 3D word is available for overlap review"):
		return
	var word := _projected_bounds(caption, game.camera)
	_check(body.encloses(word), label + ": whole 3D word stays inside the teaching area")
	_check(
		not teacher.grow(3.0).intersects(word),
		label + ": word does not cover head, body or paws: " + str(teacher) + " / " + str(word)
	)
	for node: Node in game.content.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("WordSlot"):
			_check(
				not word.grow(3.0).intersects(_projected_bounds(node, game.camera)),
				label + ": word stays separate from actual receiving pads"
			)
	var banana: Node3D = game.get("_banana")
	if is_instance_valid(banana):
		_check(
			not word.grow(3.0).intersects(_group_bounds(banana, game.camera)),
			label + ": word leaves the actual 3D banana unobscured"
		)


func _group_bounds(node: Node3D, camera: Camera3D) -> Rect2:
	var result := Rect2()
	var found := false
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var bounds := _projected_bounds(mesh, camera)
		result = result.merge(bounds) if found else bounds
		found = true
	return result


func _test_task_card_target(game: Node3D) -> void:
	for dimensions: Vector2i in [Vector2i(412, 960), Vector2i(750, 832)]:
		root.size = dimensions
		game._layout()
		await _settle()
		game.fox.set_reduced_motion(false)
		_check(
			game._focus_object("task_prompt"),
			"separated task card remains an actual teacher target"
		)
		game.fox.teacher_react("explain")
		_advance_actor(game, 0.75)
		_check(
			(
				game.fox.director.target_id == "task_prompt"
				and game.fox.director.point_target_id == "task_prompt"
			),
			"gaze and pointing bind the actual current card after responsive placement"
		)
		var skeleton: Skeleton3D = game.fox.skeleton
		var target: Vector3 = game.fox.registry.world_target("task_prompt")
		var error := PI
		for side: String in [".L", ".R"]:
			var wrist := skeleton.to_global(
				skeleton.get_bone_global_pose(skeleton.find_bone("Wrist" + side)).origin
			)
			var hand := skeleton.to_global(
				skeleton.get_bone_global_pose(skeleton.find_bone("Hand" + side)).origin
			)
			error = minf(error, (hand - wrist).angle_to(target - wrist))
		_check(
			error < 0.13, "actual wrist/paw ray still reaches the moved card: radians=" + str(error)
		)
		await _capture(game, "task_card_point_%dx%d" % [dimensions.x, dimensions.y])
		game._explicit_stop()
		_check(
			game.fox.director.point_target_id.is_empty(),
			"common Stop clears the moved card gesture"
		)
		game.fox.set_reduced_motion(true)


func _projected_bounds(mesh: MeshInstance3D, camera: Camera3D) -> Rect2:
	var bounds := Rect2()
	for corner in range(8):
		var point := camera.unproject_position(mesh.to_global(mesh.get_aabb().get_endpoint(corner)))
		bounds = Rect2(point, Vector2.ZERO) if corner == 0 else bounds.expand(point)
	return bounds


func _tap(button: Button) -> void:
	if not _check(
		is_instance_valid(button) and not button.disabled, "actual child action is available"
	):
		return
	var position := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _test_bridge_ten(game: Node3D) -> void:
	var count := 0
	for node: Node in game.content.find_children("*", "MeshInstance3D", true, false):
		if node.get_meta("countable", false):
			count += 1
	_check(
		count == 13 and game.tokens.size() == 5,
		"8+5 uses exactly thirteen authored countable objects"
	)
	for index in range(8):
		_check(
			not game.fox.registry.resolve_target("addend_a_%02d" % index).is_empty(),
			"each of the original eight objects has its own target ID"
		)
	for index in range(5):
		_check(
			game.fox.registry.resolve_target("addend_b_%02d" % index).node == game.tokens[index],
			"each of the five movable objects retains its real identity"
		)
	await _tap(game.main_button)
	await _tap(game.main_button)
	_check(
		game.activity.placed.size() == 2 and not game.activity.is_complete(),
		"two actual child actions fill the ten and leave three"
	)
	_check(
		game.activity.explanation().contains("3"),
		"current explanation refers to the remaining three"
	)
	for index in range(2):
		_check(
			game.tokens[index].position.is_equal_approx(game.targets[8 + index]),
			"the same object occupies the correct tenth-frame slot"
		)
	await _capture(game, "bridge_ten_after_two")


func _test_syllables(game: Node3D) -> void:
	_check(game.tokens.size() == 3, "Banane has exactly three syllable cards")
	for index in range(3):
		var node: Node3D = game.tokens[index]
		_check(
			game.fox.registry.resolve_target("syllable_%d" % index).node == node,
			"syllable target is the actual interactive card"
		)
		_check(
			str(node.get_node("SyllableGlyphs").mesh.text) == ["Ba", "na", "ne"][index],
			"rendered card carries the correct syllable"
		)
		await _tap(game.main_button)
		_check(
			node.position.is_equal_approx(game.targets[index]),
			"actual syllable action places the same card in word order"
		)
	_check(game.activity.is_complete(), "Ba-na-ne completes only after three actual child actions")


func _test_segmented_syllables(game: Node3D, host: SpeechHost) -> void:
	if not _check(
		game.has_method("_speak_syllables") and game.has_method("_explicit_stop"),
		"production union provides actual segmented syllable playback and common Stop"
	):
		return
	game._speak_syllables()
	var heard: Array[String] = []
	for segment in range(4):
		heard.append(str(host.request.get("text", "")))
		_check(
			heard[-1] == ["Banane", "Ba", "na", "ne"][segment],
			"current native audio request belongs to the actual word/syllable"
		)
		_check(
			_mouth_weight(game) < 0.0001,
			"each preparing syllable segment starts with a closed mouth"
		)
		host.measured_playing()
		game._tick_speech(0.06)
		_advance_actor(game, 0.08)
		_check(
			_mouth_weight(game) > 0.2, "every accepted segment has its own active avatar audio turn"
		)
		if segment > 0:
			_check(
				game.fox.director.point_target_id == "syllable_%d" % (segment - 1),
				"actual audible segment points at its own registered syllable card"
			)
		host.packet.state = "completed"
		host.packet.audible = false
		host.packet.envelope = 0.0
		var completed := host.packet.duplicate(true)
		game._tick_speech(0.06)
		_check(_mouth_weight(game) < 0.0001, "segment completion closes actual mouth geometry")
		var starts_after_completion := host.starts
		host.packet = completed
		game._tick_speech(0.06)
		_check(
			host.starts == starts_after_completion,
			"duplicate old completion cannot start another segment"
		)
	game._speak_syllables()
	host.measured_playing()
	game._tick_speech(0.06)
	_advance_actor(game, 0.08)
	var canceled := host.packet.duplicate(true)
	var starts_before_stop := host.starts
	var state_before_stop := _domain_snapshot(game)
	game._explicit_stop()
	_check(
		_mouth_weight(game) < 0.0001 and game.fox.director.point_target_id.is_empty(),
		"common Stop cancels the actual segmented mouth and gesture"
	)
	canceled.state = "completed"
	canceled.audible = false
	host.packet = canceled
	game._tick_speech(0.06)
	_check(
		host.starts == starts_before_stop and game.get("_speech_segments").is_empty(),
		"stopped word playback cannot advance to another syllable"
	)
	_check(
		_domain_snapshot(game) == state_before_stop,
		"stopping syllable playback does not change placed cards or score"
	)


func _test_pattern(game: Node3D) -> void:
	for index in range(game.activity.pattern_sequence.size()):
		_check(
			not game.fox.registry.resolve_target("pattern_item_%02d" % index).is_empty(),
			"each visible pattern element is a real registered object"
		)
	var hint: Button
	var candidate: Button
	for button: Button in game.actions.get_children():
		if button.text.contains("Hinweis") or button.text == "Gruppe entdecken":
			hint = button
		elif button.text.contains("Dreieck"):
			candidate = button
	if not _check(
		is_instance_valid(hint) and is_instance_valid(candidate),
		"pattern exposes a hint before an editable proposal"
	):
		return
	await _tap(hint)
	_check(
		(
			game.activity.pattern_hint_level == 1
			and game.activity.pattern_candidate == -1
			and game.activity.pattern_attempts == 0
		),
		"hint precedes the child's answer and creates no assessment"
	)
	await _capture(game, "pattern_after_hint")
	var context := {
		"protocolVersion": 1,
		"sessionId": "review-pattern",
		"taskId": "continue-pattern",
		"revision": 1,
		"cancelEpoch": 0,
		"stepId": "pattern-start",
		"allowedActions": ["hint", "point", "stop"]
	}
	_check(game.bind_interaction_context(context), "pattern binds the current interaction owner")
	await _tap(candidate)
	_check(
		(
			game.activity.pattern_candidate >= 0
			and game.activity.pattern_attempts == 0
			and not game.activity.is_complete()
		),
		"selecting an answer is still a reversible proposal"
	)
	var stop: Dictionary = game.companion_scope.envelope()
	stop["action"] = "stop"
	_check(
		game.apply_interaction_event(stop), "public scoped Stop is accepted for the pattern owner"
	)
	_check(
		game.activity.pattern_candidate == -1 and game.activity.pattern_attempts == 0,
		"stop discards the pending pattern proposal without assessment"
	)
	await _tap(candidate)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(
		game.activity.pattern_candidate == -1 and game.activity.pattern_attempts == 0,
		"background/resume discards a pending proposal without confirming it"
	)
	await _tap(candidate)
	_check(
		game.activity.pattern_attempts == 0 and not game.activity.is_complete(),
		"native illustration leaves final confirmation to the actual Flutter task"
	)


func _advance_actor(game: Node3D, seconds: float) -> void:
	for frame in range(ceili(seconds * 60.0)):
		game.fox.director.advance(1.0 / 60.0)


func _mouth_weight(game: Node3D) -> float:
	var result := 0.0
	for node: MeshInstance3D in game.fox.visual.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		for index in range(node.mesh.get_blend_shape_count()):
			if (
				str(node.mesh.get_blend_shape_name(index))
				in ["AA", "EE", "OH", "OU", "MBP", "FV", "L", "TH", "Neutral", "JawArticulation"]
			):
				result = maxf(result, absf(node.get_blend_shape_value(index)))
	return result


func _start_measured_speech(game: Node3D, host: SpeechHost) -> Dictionary:
	game._speak("Wir sehen noch drei Steine neben der Zehn.")
	_check(
		game._speech_state == "preparing" and _mouth_weight(game) < 0.0001,
		"actual scene adapter prepares speech with a closed mouth"
	)
	host.measured_playing()
	game._tick_speech(0.06)
	_advance_actor(game, 0.08)
	_check(
		_mouth_weight(game) > 0.2,
		"actual scene consumes native status into imported mouth geometry"
	)
	return host.packet.duplicate(true)


func _test_scene_cancellation(game: Node3D, host: SpeechHost) -> void:
	var previous_stops := host.stops
	var old := _start_measured_speech(game, host)
	game._stop_speech()
	_check(
		host.stops > previous_stops and _mouth_weight(game) < 0.0001,
		"scene Stop closes the native transport and actual mouth together"
	)
	_check(game.fox.director.point_target_id.is_empty(), "scene Stop drops the old gesture")
	host.packet = old
	game._tick_speech(0.06)
	_advance_actor(game, 0.08)
	_check(_mouth_weight(game) < 0.0001, "late stopped native status cannot reopen scene mouth")
	old = _start_measured_speech(game, host)
	var starts := host.starts
	var unchanged := _domain_snapshot(game)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(
		game.suspended and game.fox.suspended and _mouth_weight(game) < 0.0001,
		"native lifecycle suspends the actual scene and imported actor"
	)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	host.packet = old
	game._tick_speech(0.06)
	_advance_actor(game, 0.3)
	_check(
		(
			host.starts == starts
			and _mouth_weight(game) < 0.0001
			and game.fox.director.state == "listening"
		),
		"resume starts no old audio or gesture"
	)
	_check(
		_domain_snapshot(game) == unchanged,
		"pause/resume preserves already placed learning objects"
	)
	old = _start_measured_speech(game, host)
	var context := {
		"protocolVersion": 1,
		"sessionId": "review-owner",
		"taskId": "new-task",
		"revision": 2,
		"cancelEpoch": 1,
		"stepId": "owner-step"
	}
	_check(
		game.bind_interaction_context(context), "routed scene accepts the new exact owner binding"
	)
	_check(_mouth_weight(game) < 0.0001, "new task owner closes the old actual mouth")
	_advance_actor(game, 0.3)
	_check(
		game.fox.director.state == "listening",
		(
			"new owner returns to listening before a callback; actual state=%s clip=%s pending_interrupt=%s"
			% [
				game.fox.director.state,
				game.fox.director.current_clip,
				game.fox.director.get("_interrupt_left")
			]
		)
	)
	host.packet = old
	game._tick_speech(0.06)
	_advance_actor(game, 0.3)
	_check(
		_mouth_weight(game) < 0.0001 and game.fox.director.state == "listening",
		(
			"old native callback cannot revive speech or gesture under the new task owner; actual state="
			+ str(game.fox.director.state)
		)
	)


func _capture(game: Node3D, name_value: String) -> void:
	if output_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output_directory)
	await RenderingServer.frame_post_draw
	var path := output_directory.path_join(name_value + ".png")
	if _check(
		game.get_viewport().get_texture().get_image().save_png(path) == OK,
		"actual routed scene capture saved"
	):
		captured.append(path)
