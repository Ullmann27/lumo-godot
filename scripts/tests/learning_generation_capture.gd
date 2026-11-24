extends SceneTree
## Real desktop renderer captures, explicitly separate from Android evidence.
var output := "res://docs/evidence/learning-generation-20261115/renders"
var records: Array = []
var failures: Array[String] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _settle(frames: int = 15) -> void:
	for frame in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual renderer required; headless screenshots rejected")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scenarios := [
		{"name": "eight_plus_five", "payload": {"kind": "bridge_ten", "a": 8, "b": 5}},
		{"name": "banana", "payload": {"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]}},
		{"name": "pattern", "payload": {"kind": "pattern", "patternUnit": ["red_circle", "blue_triangle"], "patternSequence": ["red_circle", "blue_triangle", "red_circle", "blue_triangle"], "patternChoices": ["red_circle", "blue_triangle", "yellow_square"]}},
		{"name": "task_card", "payload": {"kind": "task_card", "prompt": "Welche Zahl liegt zwischen 20 und 22?", "subject": "Mathematik", "unit": "Zahlen entdecken", "explanation": "Suche den direkten Nachbarn von 20 und 22.", "answerChoices": ["19", "21", "23"]}},
	]
	for dimensions: Vector2i in [Vector2i(412, 915), Vector2i(384, 832), Vector2i(840, 720)]:
		root.size = dimensions
		for scenario: Dictionary in scenarios:
			var game := load("res://scenes/learning/learning_world.tscn").instantiate() as Node3D
			game.capture_options = {"learning": scenario.payload, "reduceAnimations": false, "learningVoiceEnabled": false}
			root.add_child(game)
			await _settle()
			if scenario.name == "eight_plus_five":
				game._request_conversation("Warum zuerst zwei?", "explain")
				await _settle(90)
			elif scenario.name == "pattern":
				game._pattern_hint()
			elif scenario.name == "banana":
				game._focus_object("syllable_0")
				game._teacher("explain", game.tokens[0].global_position)
			await _settle(20)
			var image := root.get_texture().get_image()
			var name := "%s_%dx%d" % [scenario.name, dimensions.x, dimensions.y]
			if image == null or image.get_size() != dimensions:
				failures.append("invalid raster " + name)
			else:
				if image.save_png(output.path_join(name + ".png")) != OK:
					failures.append("failed output " + name)
			var top: Rect2 = game.header.get_global_rect()
			var bottom: Rect2 = game.footer.get_global_rect()
			var controls: Array = []
			for button: Button in game.actions.get_children():
				controls.append({"text": button.text, "size_dp": [button.size.x, button.size.y]})
				if button.size.x < 48 or button.size.y < 48:
					failures.append("small control " + name + " " + button.text)
			if top.end.y >= bottom.position.y or bottom.end.y > dimensions.y + 1:
				failures.append("overlapping UI " + name)
			var record := {"name": name, "environment": "desktop-software-renderer", "android_device": false,
				"width": dimensions.x, "height": dimensions.y, "kind": game.activity.kind,
				"placed": game.activity.placed.size(), "pattern_hint": game.activity.pattern_hint_visible,
				"controls": controls, "speech": "native Android playback unavailable in desktop capture",
				"actor_bones": game.fox.skeleton.get_bone_count(), "actor_model": game.fox.model_load_kind,
				"object_ids": game.companion_scope.object_ids.duplicate()}
			if scenario.name == "eight_plus_five" and dimensions.x == 840:
				var samples: Array[float] = []
				for frame in range(120):
					var before := Time.get_ticks_usec()
					await process_frame
					await RenderingServer.frame_post_draw
					samples.append(float(Time.get_ticks_usec() - before) / 1000.0)
				samples.sort()
				var total := 0.0
				for sample in samples:
					total += sample
				record["desktop_frame_sample"] = {"frames": samples.size(), "mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)], "note": "software rasterizer, no native Android speech; not Fold7 evidence"}
			records.append(record)
			print("LEARNING_CAPTURE ", name, " placed=", game.activity.placed.size())
			game.queue_free()
			await _settle(4)
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema": 1, "renderer": RenderingServer.get_video_adapter_name(), "records": records, "failures": failures}, "  "))
	manifest.close()
	print("LEARNING_GENERATION_CAPTURE_", "PASS" if failures.is_empty() else "FAIL", " screenshots=", records.size(), " errors=", failures)
	quit(0 if failures.is_empty() else 1)
