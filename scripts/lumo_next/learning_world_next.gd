extends "res://scripts/learning/learning_wonder_world.gd"
## The existing routed lesson with authored objects and the original, extended
## LUMO rig. Task rules, rewards, host return and accessible inputs stay inherited.
const LEARNING_FOX = preload("res://scripts/lumo_next/learning_lumo_actor.gd")
const LEARNING_MESHES = preload("res://scripts/lumo_next/learning_asset_meshes.gd")
var lesson_revision := 0
var _registered_nodes: Dictionary = {}
var _slot_nodes: Array[Node3D] = []
var _banana: Node3D
var _native_stop_guard := false


func _slot(index: int) -> Vector3:
	var position_value := super._slot(index)
	# Imported tray: centre .03, height .18, well floor .112 above its base.
	# Keep the .36-high token on that floor with a 2 mm drawing clearance.
	position_value.y = 0.03 - 0.18 * 0.5 + 0.112 + 0.36 * 0.5 + 0.002
	return position_value


func _create_fox() -> Node3D:
	return LEARNING_FOX.new()


func _build_stage() -> void:
	super._build_stage()
	# A lower, still readable teaching view exposes the original face and
	# mouth while keeping both rows of the ten-frame visibly separated.
	camera.position = Vector3(0.0, 9.5, 14.0)
	camera.look_at(Vector3(0.0, 0.7, 0.0))
	if fox.is_usable():
		fox.director.stop_playback_requested.connect(_director_stop_requested)
	else:
		push_error("[LumoLearningNext] The authored learning character is not usable")


func _soften_teacher_materials() -> void:
	# The Blender export already contains the intended per-part PBR finish.
	# A blanket roughness override would erase the controlled eye/nose gloss.
	return


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, label: String = "") -> MeshInstance3D:
	var asset := ""
	var original_size := Vector3.ONE
	if label.begins_with("InitialCube") or label.begins_with("SubtractCube"):
		asset = "count_token_teal"
		original_size = Vector3(0.58, 0.36, 0.58)
	elif label.begins_with("MovableCube") or label.begins_with("RemovedCube") or label.begins_with("GroupCube"):
		asset = "count_token_gold"
		original_size = Vector3(0.58, 0.36, 0.58)
	elif str(parent.name).begins_with("Syllable") and label.is_empty():
		asset = "syllable_tile"
		original_size = Vector3(1.45, 0.367, 0.95)
	elif size.is_equal_approx(Vector3(4.65, 0.18, 2.05)):
		asset = "ten_frame"
		original_size = size
	elif label.begins_with("TenFrameSlot") or (activity.kind == "subtract_ten" and label.is_empty() and size.is_equal_approx(Vector3(0.68, 0.12, 0.68))):
		# The imported frame already contains ten recessed wells. Retain the
		# named layout anchor without drawing a second coincident surface.
		var anchor := MeshInstance3D.new()
		anchor.name = label if not label.is_empty() else "SubtractionWellAnchor"
		anchor.position = at
		parent.add_child(anchor)
		return anchor
	if not asset.is_empty():
		var authored := LEARNING_MESHES.make(asset, size, original_size)
		if authored != null:
			var node := MeshInstance3D.new()
			node.mesh = authored
			node.position = at
			node.name = label if not label.is_empty() else asset
			node.set_meta("lumo_asset", asset)
			node.set_meta("countable", asset.begins_with("count_token"))
			parent.add_child(node)
			return node
	return super._box(parent, at, size, material, label)


func _rebuild_activity() -> void:
	lesson_revision += 1
	_registered_nodes.clear()
	_slot_nodes.clear()
	_banana = null
	super._rebuild_activity()
	if fox.is_usable():
		fox.begin_lesson("native-learning/" + activity.kind, lesson_revision)
		_bind_targets()


func _build_syllables() -> void:
	super._build_syllables()
	for index in range(targets.size()):
		# The receiving pads are solid: cards rest above them, never inside.
		targets[index].y = 0.2 + 0.45 * 0.5 + 0.002
		token_sources[index].y = 0.45 * 0.5 + 0.012
		tokens[index].position = token_sources[index]
	if activity.word.to_lower() == "banane":
		var path := "res://assets/lumo_next/learning/banana.glb"
		if ResourceLoader.exists(path, "PackedScene"):
			_banana = (load(path) as PackedScene).instantiate() as Node3D
			_banana.name = "WordObjectBanane"
			content.add_child(_banana)
			_banana.position = Vector3(2.5, 0.08, -1.9)
			_banana.scale = Vector3.ONE * 0.75
			_banana.set_meta("countable", false)
			_banana.set_meta("semantic_role", "word_reference")


func _register_target(id: String, node: Node3D, anchor: Vector3 = Vector3.ZERO, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(node) or not fox.is_usable():
		return
	if fox.registry.register_target(id, node, anchor, metadata):
		_registered_nodes[id] = node
		node.set_meta("lumo_object_id", id)


func _bind_targets() -> void:
	_registered_nodes.clear()
	for anchor: Node3D in _slot_nodes:
		if is_instance_valid(anchor):
			anchor.free()
	_slot_nodes.clear()
	if not fox.is_usable():
		return
	fox.registry.clear_targets()
	for index in range(tokens.size()):
		var id := "token_%02d" % index
		if activity.kind in ["bridge_ten", "addition", "bridge_hundred"]:
			id = "addend_b_%02d" % index
		elif activity.kind == "syllables":
			id = "syllable_%d" % index
		_register_target(id, tokens[index], Vector3(0.0, 0.16, 0.0), {"role": "manipulable", "index": index})
	for node: Node3D in content.get_children():
		var name_value := str(node.name)
		if name_value.begins_with("InitialCube"):
			_register_target("addend_a_%02d" % int(name_value.trim_prefix("InitialCube")), node, Vector3(0, 0.18, 0), {"role": "initial_quantity"})
	for index in range(targets.size()):
		var anchor := Node3D.new()
		anchor.name = "LearningDestination%d" % index
		content.add_child(anchor)
		anchor.position = targets[index]
		_slot_nodes.append(anchor)
		var id := "destination_%02d" % index
		if activity.kind in ["bridge_ten", "addition", "bridge_hundred"]:
			id = ("ten_frame_primary" if index < 10 else "ten_frame_secondary") + "/slot_" + str(index % 10)
		elif activity.kind == "syllables":
			id = "syllable_destination_%d" % index
		_register_target(id, anchor, Vector3.ZERO, {"role": "destination", "index": index})
	for part: String in part_nodes:
		var plant_node: Node3D = part_nodes[part]
		_register_target("plant_" + part, plant_node, plant_node.to_local(_part_position(part)), {"role": "plant_part", "part": part})
	for index in range(english_models.size()):
		_register_target("english_" + str(activity.english_objects[index]), english_models[index], Vector3.UP, {"role": "vocabulary"})
	if is_instance_valid(_banana):
		_register_target("science_banana", _banana, Vector3(0, 0.43, 0), {"role": "word_reference"})
	_update_director_view()


func _arrange_activity(portrait: bool) -> void:
	super._arrange_activity(portrait)
	for index in range(mini(_slot_nodes.size(), targets.size())):
		if is_instance_valid(_slot_nodes[index]):
			_slot_nodes[index].position = targets[index]


func _layout() -> void:
	super._layout()
	_update_director_view()


func _update_director_view() -> void:
	if not is_instance_valid(fox) or not fox.is_usable() or not is_instance_valid(header) or not is_instance_valid(footer):
		return
	var top := header.get_global_rect().end.y
	var bottom := footer.get_global_rect().position.y
	var dimensions := get_viewport().get_visible_rect().size
	fox.director.set_view(camera, Rect2(Vector2(0, top), Vector2(dimensions.x, maxf(0, bottom - top))))


func _teacher(reaction: String, at: Vector3) -> void:
	if not is_instance_valid(fox) or not fox.is_usable():
		return
	if reaction not in ["welcome", "idle"]:
		fox.set_teaching_target(at)
	fox.teacher_react(reaction)


func _begin_drag(point: Vector2, finger: int) -> void:
	super._begin_drag(point, finger)
	if active_drag >= 0 and fox.is_usable():
		fox.set_focused_input(true)


func _end_drag(point: Vector2, canceled: bool) -> void:
	if fox.is_usable():
		fox.set_focused_input(false)
	super._end_drag(point, canceled)


func _cancel_drag() -> void:
	if is_instance_valid(fox) and fox.is_usable() and fox.has_method("set_focused_input"):
		fox.set_focused_input(false)
	super._cancel_drag()


func _speak(words: String) -> void:
	# Begin the avatar turn before native playback can start; the subsequent
	# status samples still come exclusively from the existing speech bridge.
	super._speak(words)
	if _speech_state == "preparing" and fox.is_usable():
		fox.begin_audio_turn(str(_speech_id), "native-utterance:" + str(_speech_id))


func _stop_speech() -> void:
	super._stop_speech()
	if is_instance_valid(fox) and fox.is_usable() and fox.has_method("interrupt"):
		fox.interrupt("speech_stopped")


func _tick_speech(delta: float) -> void:
	# Consume the complete existing native status. Audible speech and an
	# available envelope are separate facts; neither is inferred from the text.
	if _speech_wait >= 0:
		_speech_wait -= delta
		if _speech_wait <= 0:
			if not _moving.is_empty() or active_drag >= 0:
				_speech_wait = 0.1
			else:
				_speak(_speech_text)
	if not is_instance_valid(_speech_host) or not _speech_enabled:
		return
	_speech_poll += delta
	if _speech_poll < 0.05 or not _speech_host.has_method("getLearningSpeechStatus"):
		return
	_speech_poll = 0.0
	var received: Variant = JSON.parse_string(str(_speech_host.call("getLearningSpeechStatus")))
	if not received is Dictionary or int(received.get("id", -1)) != _speech_id:
		return
	var next_state := str(received.get("state", "idle"))
	if next_state not in ["preparing", "playing", "paused", "completed", "unavailable", "idle"]:
		return
	_speech_state = next_state
	if fox.is_usable():
		fox.set_teacher_speaking(next_state == "playing" and received.get("audible", false) == true)
		fox.apply_playback_status(received)
	_update_voice_button()


func _director_stop_requested(_turn_id: String, reason: String) -> void:
	# Starting a replacement avatar turn occurs after speakLearning() accepted
	# the matching utterance. It must not stop that newly accepted audio.
	if reason == "superseded" or _native_stop_guard:
		return
	_native_stop_guard = true
	if is_instance_valid(_speech_host) and _speech_host.has_method("stopLearningSpeech"):
		_speech_host.call("stopLearningSpeech")
	_native_stop_guard = false


func bind_interaction_context(context: Dictionary) -> bool:
	if not fox.is_usable() or not fox.bind_interaction_context(context):
		return false
	_bind_targets()
	return true


func apply_interaction_event(event: Dictionary) -> bool:
	if not fox.is_usable():
		return false
	if str(event.get("type", "")) in ["stop", "interrupt"]:
		var accepted: bool = fox.apply_interaction_event(event)
		if accepted:
			_stop_speech()
		return accepted
	return bool(fox.apply_interaction_event(event))
