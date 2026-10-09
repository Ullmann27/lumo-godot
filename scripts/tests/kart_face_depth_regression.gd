extends SceneTree
## Reference-derived depth envelope, evaluated on real unbatched mesh vertices.
## These tolerances prevent detached eye/mouth plates; visual review is still required.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var failures: Array[String] = []
var checks: int = 0


class AuthoredDriver:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[FaceDepth] FAIL: ", label)


func _bounds_in_head(node: MeshInstance3D, head: Node3D) -> AABB:
	var frame: Transform3D = head.global_transform.affine_inverse() * node.global_transform
	var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var box := AABB(frame * vertices[0], Vector3.ZERO)
	for point in vertices:
		box = box.expand(frame * point)
	return box


func _run() -> void:
	var fox := AuthoredDriver.new()
	fox.configure("fox", Color("1d4fa0"), "comet")
	root.add_child(fox)
	fox.set_process(false)
	for eye in fox.eyes:
		for part in eye.get_children():
			if part is MeshInstance3D:
				var bounds: AABB = _bounds_in_head(part, fox.head)
				_check(
					bounds.position.z >= -0.345,
					"eye surface remains seated within the face depth envelope"
				)
		var white: MeshInstance3D = eye.get_child(1)
		_check(white.scale.z <= 0.029, "white eye surface is a shallow shell")
		var iris: MeshInstance3D = eye.get_child(2)
		var iris_vertices: PackedVector3Array = iris.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var seated := true
		for vertex in iris_vertices:
			var point: Vector3 = iris.transform * vertex - white.position
			var radial: float = pow(point.x / white.scale.x, 2) + pow(point.y / white.scale.y, 2)
			var surface_z: float = -white.scale.z * sqrt(maxf(0.0, 1.0 - radial))
			var gap: float = surface_z - point.z
			seated = seated and gap >= 0.0005 and gap <= 0.003
		_check(seated, "every iris vertex follows the white eye with a small surface allowance")
	var smile: MeshInstance3D = fox.head.get_node("LumoSmileCavity")
	var mouth: AABB = _bounds_in_head(smile, fox.head)
	_check(
		mouth.position.z >= -0.400, "smile sits inside the cream muzzle rather than in front of it"
	)
	_check(mouth.size.x >= 0.30 and mouth.size.y >= 0.08, "smile remains readable at racing scale")
	_check(mouth.end.y > -0.19, "smile corners lift toward the cheeks")
	for name in ["LumoSmileTeeth", "LumoSmileTongue"]:
		var part: AABB = _bounds_in_head(fox.head.get_node(name), fox.head)
		_check(
			part.position.x > mouth.position.x and part.end.x < mouth.end.x,
			name + " stays between the smile corners"
		)
		_check(
			part.position.y >= mouth.position.y and part.end.y <= mouth.end.y,
			name + " stays inside the mouth opening"
		)
	fox.free()
	print("[FaceDepth] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("[FaceDepth] PASS: inset eyes and attached smiling muzzle")
	quit(0 if failures.is_empty() else 1)
