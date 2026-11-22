extends "res://scripts/learning/learning_wonder_world.gd"
## The existing routed lesson with authored objects and the original, extended
## LUMO rig. Task rules, rewards, host return and accessible inputs stay inherited.
const LEARNING_FOX = preload("res://scripts/lumo_next/learning_lumo_actor.gd")
const LEARNING_MESHES = preload("res://scripts/lumo_next/learning_asset_meshes.gd")
var _guide_token := -1
var _guide_slot := -1
var _guide_arrived := -1.0
var _landing_ring: MeshInstance3D

var _registered_nodes: Dictionary = {}
var _slot_nodes: Array[Node3D] = []
var _semantic_anchors: Dictionary = {}
var _banana: Node3D
var _word_caption: MeshInstance3D
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
	# Expose the face and mouth. Countable ten-frame rows need a slightly
	# steeper view so the real token silhouettes have a clear vertical gap.
	var height := (
		11.5
		if activity.kind in ["bridge_ten", "addition", "bridge_hundred", "subtract_ten"]
		else 9.5
	)
	camera.position = Vector3(0.0, height, 14.0)
	camera.look_at(Vector3(0.0, 0.7, 0.0))
	if fox.is_usable():
		fox.director.stop_playback_requested.connect(_director_stop_requested)
	else:
		push_error("[LumoLearningNext] The authored learning character is not usable")


func _soften_teacher_materials() -> void:
	# The Blender export already contains the intended per-part PBR finish.
	# A blanket roughness override would erase the controlled eye/nose gloss.
	return


func _box(
	parent: Node3D, at: Vector3, size: Vector3, material: Material, label: String = ""
) -> MeshInstance3D:
	var asset := ""
	var original_size := Vector3.ONE
	if label.begins_with("InitialCube") or label.begins_with("SubtractCube"):
		asset = "count_token_teal"
		original_size = Vector3(0.58, 0.36, 0.58)
	elif (
		label.begins_with("MovableCube")
		or label.begins_with("RemovedCube")
		or label.begins_with("GroupCube")
	):
		asset = "count_token_gold"
		original_size = Vector3(0.58, 0.36, 0.58)
	elif str(parent.name).begins_with("Syllable") and label.is_empty():
		asset = "syllable_tile"
		original_size = Vector3(1.45, 0.367, 0.95)
	elif size.is_equal_approx(Vector3(4.65, 0.18, 2.05)):
		asset = "ten_frame"
		original_size = size
	elif (
		label.begins_with("TenFrameSlot")
		or (
			activity.kind == "subtract_ten"
			and label.is_empty()
			and size.is_equal_approx(Vector3(0.68, 0.12, 0.68))
		)
	):
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
	_registered_nodes.clear()
	_slot_nodes.clear()
	_semantic_anchors.clear()
	_banana = null
	_word_caption = null
	super._rebuild_activity()
	if fox.is_usable():
		_sync_companion_context()
		_bind_targets()


func _build_syllables() -> void:
	super._build_syllables()
	for node: Node in content.get_children():
		if node is MeshInstance3D and node.mesh is TextMesh and node.mesh.text == activity.word:
			_word_caption = node
			_word_caption.name = "WordCaption"
			break
	for index in range(targets.size()):
		# The receiving pads are solid: cards rest above them, never inside.
		targets[index].y = 0.2 + 0.45 * 0.5 + 0.002
		token_sources[index].y = 0.45 * 0.5 + 0.012
		# Reserve a genuine clear word row between the teacher and the task.
		# Both destinations and sources move together; card identities stay fixed.
		targets[index].z += 1.0
		token_sources[index].z += 1.0
		tokens[index].position = token_sources[index]
		var pad := content.get_node_or_null("WordSlot%d" % index) as Node3D
		if is_instance_valid(pad):
			pad.position.z += 1.0
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


func _register_target(
	id: String, node: Node3D, anchor: Vector3 = Vector3.ZERO, metadata: Dictionary = {}
) -> void:
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
	for anchor: Node3D in _semantic_anchors.values():
		if is_instance_valid(anchor):
			anchor.free()
	_semantic_anchors.clear()
	if not fox.is_usable():
		return
	fox.registry.clear_targets()
	for index in range(tokens.size()):
		var id := "token_%02d" % index
		if activity.kind in ["bridge_ten", "addition", "bridge_hundred"]:
			id = "addend_b_%02d" % index
		elif activity.kind == "syllables":
			id = "syllable_%d" % index
		_register_target(
			id, tokens[index], Vector3(0.0, 0.16, 0.0), {"role": "manipulable", "index": index}
		)
	for node: Node3D in content.get_children():
		var name_value := str(node.name)
		if name_value.begins_with("InitialCube"):
			_register_target(
				"addend_a_%02d" % int(name_value.trim_prefix("InitialCube")),
				node,
				Vector3(0, 0.18, 0),
				{"role": "initial_quantity"}
			)
	for index in range(targets.size()):
		var anchor := Node3D.new()
		anchor.name = "LearningDestination%d" % index
		content.add_child(anchor)
		anchor.position = targets[index]
		_slot_nodes.append(anchor)
		var id := "destination_%02d" % index
		if activity.kind in ["bridge_ten", "addition", "bridge_hundred"]:
			id = (
				("ten_frame_primary" if index < 10 else "ten_frame_secondary")
				+ "/slot_"
				+ str(index % 10)
			)
		elif activity.kind == "syllables":
			id = "syllable_destination_%d" % index
		_register_target(id, anchor, Vector3.ZERO, {"role": "destination", "index": index})
	for part: String in part_nodes:
		var plant_node: Node3D = part_nodes[part]
		_register_target(
			"plant_" + part,
			plant_node,
			plant_node.to_local(_part_position(part)),
			{"role": "plant_part", "part": part}
		)
	for index in range(english_models.size()):
		_register_target(
			"english_" + str(activity.english_objects[index]),
			english_models[index],
			Vector3.UP,
			{"role": "vocabulary"}
		)
	for index in range(pattern_nodes.size()):
		_register_target(
			"pattern_item_%02d" % index,
			pattern_nodes[index],
			Vector3.UP * 0.2,
			{"role": "pattern_element", "index": index}
		)
	if is_instance_valid(_banana):
		_register_target("science_banana", _banana, Vector3(0, 0.43, 0), {"role": "word_reference"})
	_sync_semantic_targets()
	_update_director_view()


func _sync_semantic_targets() -> void:
	# The same owner-approved IDs used by conversation replies resolve to the
	# actual current meshes or explicit world anchors, including task cards.
	if not is_instance_valid(content) or not content.is_inside_tree():
		return
	for identifier: String in companion_objects:
		var value: Variant = companion_objects[identifier]
		if value is Vector3:
			var anchor: Node3D = _semantic_anchors.get(identifier)
			if not is_instance_valid(anchor):
				anchor = Node3D.new()
				content.add_child(anchor)
				_semantic_anchors[identifier] = anchor
			anchor.global_position = value
			if not _registered_nodes.has(identifier):
				_register_target(identifier, anchor, Vector3.ZERO, {"role": "semantic_anchor"})
		elif value is Node3D and is_instance_valid(value) and not _registered_nodes.has(identifier):
			_register_target(identifier, value, Vector3.UP * 0.28, {"role": "semantic_object"})


func _arrange_activity(portrait: bool) -> void:
	super._arrange_activity(portrait)
	for index in range(mini(_slot_nodes.size(), targets.size())):
		if is_instance_valid(_slot_nodes[index]):
			_slot_nodes[index].position = targets[index]


func _layout() -> void:
	super._layout()
	if activity.kind in ["pattern", "task_card", "plant_parts"]:
		_fit_explanation_bounds()
	if activity.kind == "syllables":
		_layout_word_caption()
	elif activity.kind == "task_card":
		_separate_teacher_and_card()
	_update_director_view()


func _mesh_bounds_on_screen(node: Node3D) -> Rect2:
	var result := _english_projected_bounds(node)
	var found := result.has_area()
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		for corner in range(8):
			var point := camera.unproject_position(
				node.to_global(node.get_aabb().get_endpoint(corner))
			)
			result = result.expand(point) if found else Rect2(point, Vector2.ZERO)
			found = true
	return result


func _shift_on_screen(node: Node3D, pixels: Vector2) -> void:
	var units_per_pixel := camera.size / get_viewport().get_visible_rect().size.y
	node.global_position += (
		(camera.global_basis.x * pixels.x - camera.global_basis.y * pixels.y) * units_per_pixel
	)


func _layout_word_caption() -> void:
	if not is_instance_valid(_word_caption) or not is_inside_tree():
		return
	var slots := Rect2()
	var found := false
	for node: Node in content.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("WordSlot"):
			var bounds := _mesh_bounds_on_screen(node)
			slots = slots.merge(bounds) if found else bounds
			found = true
	if not found:
		return
	# The work-surface row above the receiving pads is clear of the teacher
	# and the flower row. Preserve the same readable extruded word geometry.
	var caption := _mesh_bounds_on_screen(_word_caption)
	var gap := 6.0 * ui.scale.x
	var center := Vector2(slots.get_center().x, slots.position.y - gap - caption.size.y * 0.5)
	_shift_on_screen(_word_caption, center - caption.get_center())


func _separate_teacher_and_card() -> void:
	if not is_instance_valid(_task_card) or not is_instance_valid(fox) or not is_inside_tree():
		return
	var dimensions := get_viewport().get_visible_rect().size
	var gap := 12.0 * ui.scale.x
	var available_width := dimensions.x - 24.0 * ui.scale.x
	var teacher := _mesh_bounds_on_screen(fox)
	var card := _mesh_bounds_on_screen(_task_card)
	if not teacher.has_area() or not card.has_area():
		return
	var required := teacher.size.x + card.size.x + gap
	if required > available_width:
		camera.size *= required / maxf(1.0, available_width)
		teacher = _mesh_bounds_on_screen(fox)
		card = _mesh_bounds_on_screen(_task_card)
		required = teacher.size.x + card.size.x + gap
	var left := (dimensions.x - required) * 0.5
	_shift_on_screen(fox, Vector2(left - teacher.position.x, 0.0))
	_shift_on_screen(
		_task_card,
		Vector2(
			left + teacher.size.x + gap - card.position.x,
			teacher.position.y + teacher.size.y * 0.20 - card.position.y
		)
	)
	_fit_explanation_bounds()


func _fit_explanation_bounds() -> void:
	if not is_inside_tree() or not is_instance_valid(content) or not is_instance_valid(fox):
		return
	var dimensions := get_viewport().get_visible_rect().size
	var top := header.get_global_rect().end.y + 8.0
	var bottom := footer.get_global_rect().position.y - 8.0
	var available := Rect2(8.0, top, dimensions.x - 16.0, maxf(1.0, bottom - top))
	var bounds := _english_projected_bounds(content).merge(_english_projected_bounds(fox))
	if not bounds.has_area() or available.encloses(bounds):
		return
	var fitting := minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y)
	camera.size /= minf(1.0, fitting * 0.96)
	bounds = _english_projected_bounds(content).merge(_english_projected_bounds(fox))
	var shift := available.get_center() - bounds.get_center()
	var pixels_per_unit := dimensions.y / camera.size
	camera.h_offset -= shift.x / pixels_per_unit
	camera.v_offset += shift.y / pixels_per_unit


func _update_focus() -> void:
	if _guide_token >= 0 and not suspended:
		_guide_demonstration()
		return
	if _focus_id.is_empty() or suspended or not is_instance_valid(_focus_ring):
		return
	var at: Variant = _object_position(_focus_id)
	if not at is Vector3:
		_focus_ring.hide()
		return
	_focus_ring.visible = _focus_id not in ["pattern_group", "task_prompt"]
	_focus_ring.global_position = at + Vector3.UP * 0.02
	if is_instance_valid(fox) and fox.is_usable():
		fox.set_teaching_target_id(_focus_id)


func _update_director_view() -> void:
	if (
		not is_instance_valid(fox)
		or not fox.is_usable()
		or not is_instance_valid(header)
		or not is_instance_valid(footer)
	):
		return
	var top := header.get_global_rect().end.y
	var bottom := footer.get_global_rect().position.y
	var dimensions := get_viewport().get_visible_rect().size
	fox.director.set_view(
		camera, Rect2(Vector2(0, top), Vector2(dimensions.x, maxf(0, bottom - top)))
	)


func _demonstrate_token(index: int) -> void:
	if not is_instance_valid(fox) or not fox.is_usable():
		return
	_guide_token = index
	_guide_slot = activity.target_for_step(activity.placed.size() - 1)
	_guide_arrived = -1.0
	if not is_instance_valid(_landing_ring):
		_landing_ring = _focus_ring.duplicate() as MeshInstance3D
		_landing_ring.name = "DemonstrationDestination"
		_landing_ring.material_override = _focus_ring.material_override.duplicate()
		_landing_ring.material_override.albedo_color = Color("69e8fa")
		content.add_child(_landing_ring)
	_landing_ring.position = targets[_guide_slot] + Vector3.UP * .035
	_landing_ring.visible = not reduced_motion
	fox.set_teaching_target_id(str(tokens[index].get_meta("lumo_object_id")))
	fox.teacher_react("demonstrate")
	_guide_demonstration()


func _guide_demonstration() -> void:
	if _guide_token >= tokens.size() or not is_instance_valid(_focus_ring):
		_guide_token = -1
		return
	var token: Node3D = tokens[_guide_token]
	_focus_ring.show()
	_focus_ring.global_position = token.global_position + Vector3.UP * .03
	if _moving.has(_guide_token):
		return
	if _guide_arrived < 0.0:
		_guide_arrived = _clock
		_landing_ring.hide()
		return
	if _clock - _guide_arrived < 1.15 or _speech_wait >= 0.0 or _speech_state in ["preparing", "playing"]:
		return
	_guide_token = -1
	_focus_ring.hide()
	if activity.is_complete():
		fox.teacher_react("celebrate")
		return
	# Give the child the next turn. The receiving slot stays available for
	# direct touch even while Lumo points; narration never gates input.
	var next: Node3D = _slot_nodes[activity.target_index()]
	fox.set_teaching_target_id(str(next.get_meta("lumo_object_id")))
	fox.teacher_react("point")
	_landing_ring.global_position = next.global_position + Vector3.UP * .035
	_landing_ring.show()
	_demo_line = TEACHER_LINES.child_turn(activity, _lesson_grade)
	explanation.text = _demo_line
	_queue_narration()


func _cancel_performance() -> void:
	_guide_token = -1
	if is_instance_valid(_landing_ring):
		_landing_ring.hide()
	super._cancel_performance()


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


func _start_audio_segment() -> void:
	if not is_instance_valid(fox) or not fox.is_usable():
		_stop_speech()
		return
	if not fox.can_begin_audio_turn(companion_scope.envelope(_turn_id)):
		_stop_speech()
		return
	# Retire the preceding transport before the host accepts a new segment.
	# The base owns the sole timer, queue, numeric ID and captured owner scope.
	fox.stop_audio_turn("segment_replaced")
	super._start_audio_segment()
	if _speech_state == "preparing":
		if not fox.begin_audio_turn(
			str(_speech_id), "native-utterance:%d" % _speech_id, [], "aligned_audio", _audio_scope
		):
			_stop_speech()


func _stop_speech() -> void:
	var previous_guard := _native_stop_guard
	_native_stop_guard = true
	super._stop_speech()
	if is_instance_valid(fox) and fox.is_usable():
		fox.stop_audio_turn("speech_stopped")
	_native_stop_guard = previous_guard


func _apply_speech_status(received: Dictionary) -> bool:
	# Validation precedes the base's UI, syllable cue and next-segment changes.
	return is_instance_valid(fox) and fox.is_usable() and fox.apply_playback_status(received)


func _director_stop_requested(_turn_id: String, reason: String) -> void:
	if _native_stop_guard:
		return
	_native_stop_guard = true
	if reason == "segment_replaced":
		if (
			is_instance_valid(_speech_host)
			and HostBridge.supports_method(_speech_host, "stopLearningSpeech")
		):
			_speech_host.call("stopLearningSpeech")
	else:
		_stop_speech()
	_native_stop_guard = false


func _sync_companion_context() -> void:
	if _observation_closed:
		return
	super._sync_companion_context()
	if not _scope_valid or not is_instance_valid(fox) or not fox.is_usable():
		return
	var context: Dictionary = companion_scope.envelope()
	context["allowedActions"] = companion_scope.allowed_actions.duplicate()
	if not fox.interaction_context_matches(context):
		if fox.bind_interaction_context(context):
			_bind_targets()
	else:
		_sync_semantic_targets()


func bind_interaction_context(context: Dictionary) -> bool:
	var next_scope = COMPANION_SCOPE.new()
	if not next_scope.configure(context, "", ""):
		return false
	if (
		not is_instance_valid(fox)
		or not fox.is_usable()
		or not fox.bind_interaction_context(context)
	):
		return false
	companion_scope = next_scope
	_scope_valid = true
	_context_signature = JSON.stringify(_parameters())
	_performance_serial += 1
	_turn_id = 0
	_handled_turn = 0
	_stop_speech()
	if (
		is_instance_valid(_speech_host)
		and HostBridge.supports_method(_speech_host, "stopLearningConversation")
	):
		_speech_host.call("stopLearningConversation")
	_focus_id = ""
	if is_instance_valid(_focus_ring):
		_focus_ring.hide()
	_clear_pending_proposal()
	_sync_companion_context()
	_bind_targets()
	return true


func apply_interaction_event(event: Dictionary) -> bool:
	if not is_instance_valid(fox) or not fox.is_usable():
		return false
	if not fox.apply_interaction_event(event):
		return false
	if event.get("action") == "stop":
		_explicit_stop()
	return true
