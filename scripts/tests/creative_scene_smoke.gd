extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in [
		"res://scripts/creative/build_world.gd",
		"res://scripts/creative/rhythm_world.gd",
		"res://scripts/creative/treasure_world.gd"
	]:
		var script = load(path)
		if script == null or not script.can_instantiate():
			push_error("[CreativeSmoke] Cannot instantiate " + path)
			quit(1)
			return
	for path in [
		"res://scenes/creative/build_world.tscn",
		"res://scenes/creative/rhythm_world.tscn",
		"res://scenes/creative/treasure_world.tscn"
	]:
		var game = load(path).instantiate()
		root.add_child(game)
		for _i in range(4):
			await process_frame
		game.queue_free()
		await process_frame
		print("[CreativeSmoke] PASS ", path)
	quit(0)
