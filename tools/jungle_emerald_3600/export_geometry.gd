extends SceneTree
const COURSE = preload("res://scripts/games/kart_jungle_course.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/kart/jungle_emerald_3600/geometry")
	DirAccess.make_dir_recursive_absolute("res://evidence/jungle_emerald_3600")
	var curve: Curve3D = COURSE.make_curve()
	var length: float = curve.get_baked_length()
	var samples: Array[Dictionary] = []
	var maximum_grade: float = 0.0
	var minimum_radius: float = INF
	var measured_length: float = 0.0
	var last: Vector3 = curve.sample_baked(0.0, true)
	for i in range(3601):
		var s: float = length * float(i) / 3600.0
		var p: Vector3 = curve.sample_baked(s, true)
		var basis: Basis = COURSE.frame(curve, s)
		var direction: Vector3 = -basis.z
		var ahead: Vector3 = COURSE.forward(curve, s + 1.0)
		var angle: float = direction.angle_to(ahead)
		maximum_grade = maxf(maximum_grade, absf(direction.y) / maxf(Vector2(direction.x, direction.z).length(), 0.0001))
		if angle > 0.000001:
			minimum_radius = minf(minimum_radius, 1.0 / angle)
		measured_length += p.distance_to(last)
		last = p
		samples.append({"s": s, "position": _v(p), "right": _v(basis.x), "up": _v(basis.y), "forward": _v(direction), "width": COURSE.width_at(s), "section": mini(11, floori(s / 300.0))})
	var control: Array[Dictionary] = []
	for i in range(curve.point_count):
		control.append({"position": _v(curve.get_point_position(i)), "handle_in": _v(curve.get_point_in(i)), "handle_out": _v(curve.get_point_out(i))})
	var sections: Array[Dictionary] = []
	for i in range(12):
		sections.append({"index": i, "name": COURSE.SECTION_NAMES[i], "start_m": i * 300, "end_m": (i + 1) * 300})
	var record: Dictionary = {
		"schema": "lumo_jungle_centerline_v1", "id": COURSE.ID, "units": "metres", "coordinate_system": "Godot right-handed Y-up; Blender mapping (x,-z,y)",
		"length_m": length, "sampled_length_m": measured_length, "sample_interval_m": length / 3600.0,
		"target_length_m": 3600.0, "max_grade_fraction": maximum_grade, "minimum_curvature_radius_m": minimum_radius,
		"closure_position_error_m": curve.get_point_position(0).distance_to(curve.get_point_position(curve.point_count - 1)),
		"closure_out_tangent_error": curve.get_point_out(0).distance_to(curve.get_point_out(curve.point_count - 1)),
		"curve_bake_interval_m": curve.bake_interval, "samples": samples, "control_points": control, "sections": sections
	}
	var file := FileAccess.open("res://assets/kart/jungle_emerald_3600/geometry/centerline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	var save_error: Error = ResourceSaver.save(curve, "res://assets/kart/jungle_emerald_3600/geometry/centerline.tres")
	assert(save_error == OK, "Could not save authoring Curve3D")
	assert(absf(length - 3600.0) <= 0.1, "Final 3D curve length outside production tolerance")
	assert(maximum_grade <= 0.08, "Course grade exceeds 8 percent")
	assert(float(record.closure_position_error_m) < 0.001, "Position seam is open")
	assert(float(record.closure_out_tangent_error) < 0.001, "Tangent seam is open")
	var evidence: Dictionary = record.duplicate()
	evidence.erase("samples")
	evidence.erase("control_points")
	var evidence_file := FileAccess.open("res://evidence/jungle_emerald_3600/geometry_metrics.json", FileAccess.WRITE)
	evidence_file.store_string(JSON.stringify(evidence, "\t"))
	evidence_file.close()
	print(JSON.stringify(evidence))
	quit(0)

func _v(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

