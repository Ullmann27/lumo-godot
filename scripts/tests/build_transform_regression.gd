extends SceneTree
const STATE = preload("res://scripts/creative/build_state.gd")
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("[BuildTransform] " + message)
		quit(1)
		assert(condition, message)


func _run() -> void:
	var state = STATE.new()
	_check(state.place("bridge", Vector3i(-6, 0, 6)).is_empty(), "Initial piece is grounded")
	var uid := int(state.pieces[0].uid)
	var identity: int = state.next_id
	var original: Array = state.pieces.duplicate(true)
	var history: int = state.undo_stack.size()
	_check(
		state.transform_piece(uid, Vector3i(-9, 0, 7), 1).is_empty(),
		"Existing bridge moves and rotates"
	)
	_check(state.pieces.size() == 1 and state.next_id == identity, "Move preserves UID and counter")
	_check(state.piece_by_id(uid).turn == 1, "Rotation is stored on selected piece")
	_check(state.undo_stack.size() == history + 1, "Whole transform is one history entry")
	var moved: Dictionary = state.to_data()
	_check(state.undo() and state.pieces == original, "Undo restores exact original transform")
	_check(state.redo() and state.to_data() == moved, "Redo restores exact moved transform")
	var restored = STATE.new()
	_check(restored.restore(moved), "Unchanged v1 save accepts transformed world")
	_check(restored.pieces == state.pieces, "Save reload preserves exact part identities/positions")
	history = state.undo_stack.size()
	_check(state.transform_piece(uid, Vector3i(-9, 0, 7), 1).is_empty(), "No-op transform succeeds")
	_check(state.undo_stack.size() == history, "No-op does not consume undo history")
	_check(
		not state.transform_piece(uid, Vector3i(24, 0, 7), 0).is_empty(),
		"Out-of-bounds rotated volume rejected"
	)
	_check(
		state.to_data() == moved and state.undo_stack.size() == history,
		"Rejected transform is atomic"
	)
	_check(not state.transform_piece(9999, Vector3i.ZERO, 0).is_empty(), "Unknown UID rejected")
	_check(
		not state.transform_piece(uid, Vector3i(0, 3, 0), 0).is_empty(),
		"Floating selected bridge rejected"
	)

	var stacked = STATE.new()
	_check(stacked.place("stone", Vector3i(-8, 0, 0)).is_empty(), "Support placed")
	_check(stacked.place("lantern", Vector3i(-8, 1, 0)).is_empty(), "Supported lantern placed")
	var base_id := int(stacked.pieces[0].uid)
	var top_id := int(stacked.pieces[1].uid)
	var before: Dictionary = stacked.to_data()
	_check(
		not stacked.transform_piece(base_id, Vector3i(-7, 0, 0), 0).is_empty(),
		"Cannot move load-bearing base away"
	)
	_check(stacked.to_data() == before, "Failed base movement preserves lantern and base")
	_check(
		stacked.transform_piece(top_id, Vector3i(-7, 0, 0), 1).is_empty(),
		"Top piece can move to ground"
	)
	_check(
		stacked.transform_piece(base_id, Vector3i(-9, 0, 0), 0).is_empty(),
		"Base can then move safely"
	)
	_check(
		not stacked.transform_piece(base_id, Vector3i(-7, 0, 0), 0).is_empty(),
		"Occupied target rejected"
	)

	var bridges = STATE.new()
	_check(bridges.place("bridge", Vector3i(-1, 0, 0)).is_empty(), "First bank-anchored bridge")
	_check(bridges.place("bridge", Vector3i(2, 0, 0)).is_empty(), "Opposite bank-anchored bridge")
	_check(bridges.challenge_passes("bridge"), "Original bridge objective remains achievable")
	_check(
		bridges.transform_piece(int(bridges.pieces[0].uid), Vector3i(-5, 0, 0), 1).is_empty(),
		"Independently supported opposite span remains valid"
	)
	_check(not bridges.challenge_passes("bridge"), "Moved gap no longer completes crossing")
	_check(
		bridges.undo() and bridges.challenge_passes("bridge"), "Undo restores functional crossing"
	)
	for template in ["house", "tower", "castle", "village", "bridge"]:
		var legacy = STATE.new()
		legacy.template(template)
		_check(
			STATE._unsupported_ids(legacy.pieces).is_empty(),
			"Existing template remains structurally grounded: " + template
		)
		var saved: Dictionary = legacy.to_data()
		var old = STATE.new()
		_check(
			old.restore(saved) and old.to_data() == saved, "v1 template save preserved: " + template
		)
	print(
		"[BuildTransform] PASS checks=",
		checks,
		": identity, rotation, support graph, atomic history and v1 saves"
	)
	quit(0)
