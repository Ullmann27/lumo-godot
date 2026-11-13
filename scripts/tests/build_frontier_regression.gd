extends SceneTree
const STATE = preload("res://scripts/creative/build_state.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures.append(detail)
		push_error("[BuildFrontier] " + detail)


func _run() -> void:
	var state = STATE.new()
	for spot in [Vector3i(-120, 0, 115), Vector3i(124, 0, -121), Vector3i(7, 0, 5)]:
		_check(state.place("cottage", spot).is_empty(), "House is buildable at " + str(spot))
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(state.to_data()))
	var restored = STATE.new()
	_check(restored.restore(serialized), "Expanded world survives actual JSON roundtrip")
	_check(restored.pieces == state.pieces, "Distant and original house identities survive")
	_check(not state.place("cottage", Vector3i(127, 0, 0)).is_empty(),
		"Whole building footprint respects the enlarged boundary")
	_check(not state.place("sand", Vector3i(1, 0, 100)).is_empty(),
		"Distant river remains open and unsupported")
	var router = root.get_node("SceneRouter")
	router.launch_options = {"childKey": "frontier_regression_no_user_data"}
	var world = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(world)
	for _frame in range(10):
		await physics_frame
	var frontier: Node = world.get_node_or_null("BuildFrontier")
	_check(frontier != null, "Production world actually attaches outer terrain")
	if frontier != null:
		_check(int(frontier.get_meta("terrain_chunks", 0)) < 160,
			"Empty terrain stays chunked instead of creating tens of thousands of cells")
		var found_ground := false
		for child in frontier.get_children():
			if child is MeshInstance3D and child.name.begins_with("FrontierGround"):
				var bounds: AABB = child.get_aabb()
				var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z),
					Vector2(bounds.size.x, bounds.size.z))
				if footprint.has_point(Vector2(120, 120)) and absf(bounds.position.y - 0.015) < 0.001:
					found_ground = true
		_check(found_ground, "Distant legal plot is covered by real visible ground geometry")
	for point in [Vector3(-120, 10, 115), Vector3(120, 10, -120)]:
		var ray := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 20.0)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and absf(float(hit.position.y)) < 0.02,
			"Physical ground supports the far building area " + str(point))
	world.focus = Vector3(120, 0, -120)
	world.radius = 35.0
	world._camera_update()
	var spawn: Vector3 = world._find_explorer_spawn()
	_check(spawn.distance_to(Vector3(120.5, 0.08, -116.5)) < 3.0,
		"Walking starts near the distant camera instead of teleporting to the old island")
	_check(world.explorer.horizontal_limit.x > 128,
		"Walking bounds cover the same world as construction")
	world.free()
	for _frame in range(3):
		await process_frame
	print("[BuildFrontier] ", "PASS" if failures.is_empty() else "FAIL",
		" checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
