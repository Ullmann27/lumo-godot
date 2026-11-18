extends SceneTree
const WORLD = preload("res://scripts/games/kart_world.gd")
func _initialize() -> void:
	call_deferred("_run")
func _walk(node: Node, depth: int, out: Array) -> void:
	for c in node.get_children():
		if c is GeometryInstance3D:
			var aabb: AABB = c.get_aabb()
			var g: Transform3D = c.global_transform
			var box: AABB = g * aabb
			var mm := 0
			if c is MultiMeshInstance3D and c.multimesh: mm = c.multimesh.instance_count
			out.append("%s | %s | %s | size=%s mm=%d" % [c.get_path(), c.get_class(), box.get_center().snapped(Vector3.ONE), box.size.snapped(Vector3.ONE * 0.1), mm])
		if depth < 4:
			_walk(c, depth + 1, out)
func _run() -> void:
	for track in ["sonnenhafen", "holo_city", "winter_sprint"]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, track)
		await process_frame
		var out: Array = []
		_walk(world, 0, out)
		print("TRACK ", track, " ", out.size(), " length=", world.length, " road_y0=", world.position_at(0).y, " road_y_mid=", world.position_at(world.length*0.5).y)
		var names := {}
		for line in out:
			var key: String = line.get_slice(" | ", 0).get_file().left(22)
			names[key] = names.get(key, 0) + 1
		print(names)
		var start: Vector3 = world.position_at(20.0)
		for line in out:
			pass
		world.free()
	quit()
