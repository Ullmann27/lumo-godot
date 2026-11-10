extends SceneTree
const STATE = preload("res://scripts/creative/build_state.gd")
const TOOLS = preload("res://scripts/creative/build_sandbox_tools.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(STATE.HALF == 24)
	assert(STATE.in_world(-24, 24))
	assert(not STATE.in_world(-25, 24))

	var state = STATE.new()
	var fill: Dictionary = TOOLS.fill_rect(
		state, "sand", Vector3i(-20, 0, 14), Vector3i(-18, 0, 16)
	)
	assert(fill.ok and int(fill.count) == 9)
	assert(state.pieces.size() == 9)
	assert(state.undo_stack.size() == 1, "One fill must be one undo step")
	assert(state.undo())
	assert(state.pieces.is_empty())
	assert(state.redo())
	assert(state.pieces.size() == 9)

	state.undo_stack.clear()
	state.redo_stack.clear()
	var copied: Dictionary = TOOLS.copy_region(
		state,
		Vector3i(-20, 0, 14),
		Vector3i(-18, 0, 16),
		Vector3i(6, 0, 0)
	)
	assert(copied.ok and int(copied.count) == 9)
	assert(state.pieces.size() == 18)
	assert(state.undo_stack.size() == 1, "One copy must be one undo step")
	assert(state.undo() and state.pieces.size() == 9)
	assert(state.redo() and state.pieces.size() == 18)

	var before: Array = state.pieces.duplicate(true)
	var next_before: int = state.next_id
	var failed: Dictionary = TOOLS.copy_region(
		state,
		Vector3i(-20, 0, 14),
		Vector3i(-18, 0, 16),
		Vector3i(21, 0, 0)
	)
	assert(not failed.ok)
	assert(state.pieces == before, "Failed batch must restore every piece")
	assert(state.next_id == next_before, "Failed batch must restore next_id")

	var mirror_source = STATE.new()
	assert(mirror_source.place("wall", Vector3i(-20, 0, 4), 0).is_empty())
	assert(mirror_source.place("door", Vector3i(-19, 0, 4), 1).is_empty())
	mirror_source.undo_stack.clear()
	mirror_source.redo_stack.clear()
	var mirrored: Dictionary = TOOLS.mirror_copy_region(
		mirror_source,
		Vector3i(-20, 0, 4),
		Vector3i(-18, 2, 5),
		"x",
		Vector3i(7, 0, 0)
	)
	assert(mirrored.ok and int(mirrored.count) == 2)
	assert(mirror_source.pieces.size() == 4)
	assert(mirror_source.undo_stack.size() == 1)
	assert(mirror_source.undo() and mirror_source.pieces.size() == 2)

	var saved := state.to_data()
	var restored = STATE.new()
	assert(restored.restore(saved))
	assert(restored.pieces == state.pieces)
	print("[BauweltSandboxTools] PASS larger world, atomic fill/copy/mirror, undo and save")
	quit(0)
