extends SceneTree
## Uses actual cuff-ring vertices and the authored ellipsoid glove surface.
## The glove centre alone cannot prove sleeve/wrist continuity.

const CATALOG = preload("res://scripts/games/kart_catalog.gd")
var checks: int = 0
var smallest_contact_count: int = 20
var smallest_far_contact_count: int = 8


class AuthoredKart:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _check_arm(arm: Node3D) -> void:
	var sleeve: MeshInstance3D = arm.get_node("RacingSleeve")
	var glove: MeshInstance3D = arm.get_node("GripGlove")
	var arrays: Array = sleeve.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var start: int = sleeve.mesh.get_meta("cuff_vertex_start")
	var count: int = sleeve.mesh.get_meta("cuff_vertex_count")
	var inside_glove: int = 0
	for i in range(start, start + count):
		# SphereMesh radius is 1; the glove node's inverse transform removes
		# its authored ellipsoid scale as well as the arm pose/stretch.
		var glove_point: Vector3 = glove.to_local(sleeve.to_global(vertices[i]))
		if glove_point.length_squared() <= 1.0:
			inside_glove += 1
		assert(normals[i].is_finite() and normals[i].length() > 0.99)
	assert(inside_glove >= 5, "At least a quarter of the real cuff ring must overlap the palm")
	smallest_contact_count = mini(smallest_contact_count, inside_glove)
	checks += 1
	var far: Mesh = sleeve.mesh.get_meta("far_geometry")
	var far_vertices: PackedVector3Array = far.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(far_vertices.size() < vertices.size())
	assert(far.get_aabb().size.z > 0.30, "LOD sleeve follows the same connected wrist direction")
	var far_inside_glove: int = 0
	for i in range(far_vertices.size() - 8, far_vertices.size()):
		var glove_point: Vector3 = glove.to_local(sleeve.to_global(far_vertices[i]))
		if glove_point.length_squared() <= 1.0:
			far_inside_glove += 1
	assert(far_inside_glove >= 2, "Simplified sleeve also keeps physical palm contact")
	smallest_far_contact_count = mini(smallest_far_contact_count, far_inside_glove)


func _exercise(kind: String, style: String, reduced: bool) -> void:
	var kart := AuthoredKart.new()
	kart.configure(kind, Color("76d9ff"), style)
	kart.reduced_motion = reduced
	root.add_child(kart)
	kart.set_process(false)
	var arms: Array[Node] = kart.driver.find_children("Arm*", "Node3D", true, false)
	assert(arms.size() == 2)
	for state in [
		{"steer": 0.0, "place": 0},
		{"steer": -1.0, "place": 0},
		{"steer": 1.0, "place": 0},
		{"steer": 0.0, "place": 1 if kind == "fox" else 0},
		{"steer": 0.0, "place": 0},
	]:
		kart.set_motion(18.0, state.steer, false, absf(state.steer) > 0.5)
		kart.celebrate(state.place)
		for frame in range(24):
			kart._process(1.0 / 60.0)
			for arm: Node3D in arms:
				_check_arm(arm)
	kart.free()


func _run() -> void:
	for reduced in [false, true]:
		for entry in CATALOG.KARTS:
			_exercise("fox", str(entry.id), reduced)
		for kind in ["rabbit", "otter", "badger", "cat"]:
			_exercise(kind, "comet", reduced)
	print(
		(
			"[KartArmContact] checks=%d minimum_cuff_vertices_in_palm=%d/20 low=%d/8"
			% [checks, smallest_contact_count, smallest_far_contact_count]
		)
	)
	print(
		(
			"[KartArmContact] PASS: connected physical cuff/palm in steer/drift and victory, "
			+ "normal/low geometry, %d Lumo karts, five drivers and reduced motion" % CATALOG.KARTS.size()
		)
	)
	quit()
