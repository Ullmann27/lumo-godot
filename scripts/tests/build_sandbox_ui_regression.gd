extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": "sandbox_ui_regression"}
	DirAccess.remove_absolute("user://lumo_build_sandbox_ui_regression_1.json")
	var game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	for _i in range(8):
		await process_frame

	for caption in ["Füllen", "Kopieren", "Spiegel X", "Spiegel Z"]:
		var button: Button = _button_with_text(game, caption)
		assert(button != null, "Sandbox button missing: " + caption)
		assert(
			button.custom_minimum_size.y >= 48.0,
			"Sandbox touch target must stay at least 48 dp: " + caption
		)

	var before: int = game.model.pieces.size()
	game._set_sandbox_mode("fill")
	assert(game.sandbox_mode == "fill")
	game._sandbox_tap(Vector3i(-22, 0, 14))
	assert(game.sandbox_points.size() == 1)
	game._sandbox_tap(Vector3i(-20, 0, 16))
	assert(game.sandbox_points.is_empty())
	assert(game.model.pieces.size() == before + 9)
	# Copy a known successful selection, then require one undo per whole action.
	game._set_sandbox_mode("copy")
	game._sandbox_tap(Vector3i(-22, 0, 14))
	game._sandbox_tap(Vector3i(-20, 0, 16))
	assert(game.sandbox_points.size() == 2)
	game._sandbox_tap(Vector3i(-22, 0, 20))
	assert(game.sandbox_points.is_empty())
	assert(game.model.pieces.size() == before + 18, "Copy creates every selected block")
	game._undo()
	assert(game.model.pieces.size() == before + 9, "One undo reverts the complete copy")

	for mode in ["mirror_x", "mirror_z"]:
		game._set_sandbox_mode(mode)
		game._sandbox_tap(Vector3i(-22, 0, 14))
		game._sandbox_tap(Vector3i(-20, 0, 16))
		game._sandbox_tap(Vector3i(-22, 0, 20))
		assert(game.model.pieces.size() == before + 18, "Mirror creates a complete selection")
		game._undo()
		assert(game.model.pieces.size() == before + 9, "Mirror is one atomic undo")

	game._undo()
	assert(game.model.pieces.size() == before, "One undo reverts the original fill")

	game._set_sandbox_mode("mirror_x")
	assert(game.sandbox_mode == "mirror_x")
	game._set_sandbox_mode("mirror_x")
	assert(game.sandbox_mode.is_empty(), "Pressing the active tool again must leave tool mode")

	assert(game.model.pieces.size() == before)
	print("[BauweltSandboxUI] PASS 48dp tools, point workflow and atomic undo")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_build_sandbox_ui_regression_1.json")
	quit(0)


func _button_with_text(node: Node, caption: String) -> Button:
	if node is Button and (node as Button).text == caption:
		return node as Button
	for child in node.get_children():
		var found: Button = _button_with_text(child, caption)
		if found != null:
			return found
	return null
