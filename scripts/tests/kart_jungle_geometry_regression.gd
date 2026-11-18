extends SceneTree
## Tests the exported 3D line, road mesh seams, collision decks and reset projection.
const WORLD = preload("res://scripts/games/kart_world.gd")
const COURSE = preload("res://scripts/games/kart_jungle_course.gd")
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, COURSE.ID, true)
	await physics_frame
	await physics_frame
	assert(world.track_id == COURSE.ID)
	assert(absf(world.length - 3600.0) <= 18.0)
	assert(world.checkpoint_positions.size() == 8)
	assert(world.get_meta("jungle_road_sections") == 12)
	assert(world.get_meta("jungle_road_collision_sections") == 12)
	assert(world.action.is_empty() and world.jump.is_empty())
	checks += 1
	var exported: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/kart/jungle_emerald_3600/geometry/centerline.json"))
	assert(exported is Dictionary)
	assert(exported.samples.size() == 3601)
	var maximum_grade: float = 0.0
	var maximum_export_error: float = 0.0
	var maximum_projection_error: float = 0.0
	var measured_length: float = 0.0
	var last: Vector3 = world.position_at(0)
	for row in exported.samples:
		var d: float = float(row.s)
		var p: Vector3 = world.position_at(d)
		var expected := Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2]))
		maximum_export_error = maxf(maximum_export_error, p.distance_to(expected))
		measured_length += last.distance_to(p)
		last = p
		var f: Vector3 = world.forward(d)
		maximum_grade = maxf(maximum_grade, absf(f.y) / maxf(Vector2(f.x, f.z).length(), 0.000001))
		if int(d) % 25 == 0:
			var sampled: Dictionary = world.sample_road(p, d)
			var delta: float = fposmod(float(sampled.distance) - d + world.length * 0.5, world.length) - world.length * 0.5
			maximum_projection_error = maxf(maximum_projection_error, absf(delta))
	assert(maximum_grade <= 0.08)
	assert(maximum_export_error <= 0.005, "Exported Blender line must be the actual runtime line")
	assert(absf(measured_length - 3600.0) <= 18.0)
	assert(maximum_projection_error < 0.06)
	assert(world.position_at(0.0).distance_to(world.position_at(world.length)) < 0.001)
	assert(world.frame(0.0).is_equal_approx(world.frame(world.length)))
	assert(is_equal_approx(world.road_width_at(0.0), 18.0))
	assert(is_equal_approx(world.road_width_at(1900.0), 14.0))
	checks += 1
	var mesh_seam_maximum: float = 0.0
	var road_root: Node3D = world.get_node("DschungelherzRoad")
	var triangles: int = 0
	for section in range(12):
		var mesh: ArrayMesh = road_root.get_node("RoadSection%02d" % section).mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var next_mesh: ArrayMesh = road_root.get_node("RoadSection%02d" % ((section + 1) % 12)).mesh
		var next_vertices: PackedVector3Array = next_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for column in range(5):
			mesh_seam_maximum = maxf(mesh_seam_maximum, vertices[vertices.size() - 5 + column].distance_to(next_vertices[column]))
	assert(mesh_seam_maximum < 0.001, "Adjacent road strips must close across all five columns")
	checks += 1
	var ray_tests: int = 0
	var max_collision_error: float = 0.0
	for i in range(145):
		var d: float = float(i) * world.length / 145.0
		for lateral in [-4.5, 0.0, 4.5]:
			var at: Vector3 = world.position_at(d, lateral)
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at - Vector3.UP * 2.0, 1)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty(), "Physical road deck missing at %.2f m, lane %.1f" % [d, lateral])
			max_collision_error = maxf(max_collision_error, at.distance_to(hit.position))
			ray_tests += 1
	assert(max_collision_error < 0.08, "Collision follows the banked, graded visual deck")
	checks += 1
	for gate in range(8):
		var floor_d: float = gate * world.length / 8.0
		var ceiling: float = (gate + 1) * world.length / 8.0 - 1.0
		var reset_d: float = world.safe_respawn_distance(floor_d + 20.0, floor_d, ceiling)
		var reset: Transform3D = world.reset_transform(reset_d)
		var sampled: Dictionary = world.sample_road(reset.origin, reset_d)
		assert(float(sampled.lateral) < 0.01 and float(sampled.lateral) > -0.01)
		assert(reset_d >= floor_d and reset_d <= ceiling)
		assert(reset.basis.y.dot(Vector3.UP) > 0.98)
	checks += 1
	for d in [970.0, 1100.0, 1250.0, 1450.0]:
		var anchor: Vector3 = world.position_at(d) + Vector3.UP
		var desired: Vector3 = world.position_at(d - 7.0, 12.0) + Vector3.UP * 12.0
		var clipped: Vector3 = world.clip_tunnel_camera(anchor, desired)
		var sampled: Dictionary = world.sample_road(clipped, d)
		assert(absf(float(sampled.lateral)) <= world.road_width_at(float(sampled.distance)) * 0.5)
		assert((clipped - world.position_at(float(sampled.distance))).dot(world.frame(float(sampled.distance)).y) <= 6.51)
	checks += 1
	var evidence: Dictionary = {
		"status": "passed", "godot_version": Engine.get_version_info().string,
		"checks_completed": checks, "curve_length_m": world.length, "exported_polyline_length_m": measured_length,
		"maximum_grade_fraction": maximum_grade, "export_max_error_m": maximum_export_error,
		"road_projection_max_error_m": maximum_projection_error, "mesh_seam_max_error_m": mesh_seam_maximum,
		"road_triangles": triangles, "collision_ray_tests": ray_tests, "collision_max_error_m": max_collision_error,
		"checkpoint_count": 8, "track_id": COURSE.ID, "device_performance": "not_measured"
	}
	DirAccess.make_dir_recursive_absolute("res://evidence/jungle_emerald_3600")
	var file := FileAccess.open("res://evidence/jungle_emerald_3600/geometry_regression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("[DschungelherzGeometry] PASS ", JSON.stringify(evidence))
	world.queue_free()
	await process_frame
	quit(0)

