extends "res://scripts/tests/memory_table_regression.gd"
## Proves two visible card touches at the compact native table without paging.
## Uses the production presenter and its normal public-state interface.

func _run() -> void:
	if output.is_empty():
		push_error("LUMO_MEMORY_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if on_demand: RenderingServer.render_loop_enabled = false
	original_touch = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	await _profile(Vector2i(640,320),1.0,Rect2())
	bridge = ObservedTransport.new()
	bridge.state = _state("profi")
	var scene: PackedScene = load(root.get_node("SceneRouter").SCENES.memory)
	table = scene.instantiate()
	table._host = bridge
	root.add_child(table)
	await _frames(8)
	_visible_targets()
	await _snap("Memory-640x320-Karten")
	print("MEMORY_COMPACT page_size=%d safe=%s" % [table._page_size,table._safe_rect.size])
	_check(table._page_size>=4,"compact table shows four cards on its first page")
	if table._page_size>=2:
		for index in [0,1]:
			var previous_count: int = bridge.requests.size()
			await _tap(table._cards[index].button,"compact table card %d" % index)
			_check(bridge.requests.size()==previous_count+1
				and bridge.requests.back().action=="flip"
				and int(bridge.requests.back().index)==index,
				"compact table card %d reaches the state owner" % index)
			var reply := _reply({})
			reply.cards[index] = {"index":index,"faceUp":true,"matched":false,"motif":"panda"}
			if index == 1:
				reply.cards[0].matched = true
				reply.cards[1].matched = true
				reply.kindPairs = 1
				reply.kindMoves = 1
				reply.line = "Paar gefunden! Du bist nochmal dran."
			await _apply(reply)
			await _frames(38)
		_check(table._page==0 and table._cards[0].matched.visible and table._cards[1].matched.visible,
			"both cards show their matching mark without a page change")
		await _snap("Memory-640x320-Paar")
	table.queue_free()
	await _frames(4)
	Input.emulate_touch_from_mouse = original_touch
	print("MEMORY_COMPACT_%s checks=%d failures=%d" %
		["PASS" if errors.is_empty() else "FAIL",checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
