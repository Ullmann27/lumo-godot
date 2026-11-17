extends SceneTree
## Measures real face surfaces, anatomy, vehicle contacts and runtime batching.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var checks := 0
var failures: Array[String] = []


class AuthoredKart:
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
		push_error(label)


func _geometry_stats(node: Node, excluded: Node = null) -> Vector2i:
	var result := Vector2i.ZERO
	if node == excluded:
		return result
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.x += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			result.y += 1
	for child in node.get_children():
		result += _geometry_stats(child, excluded)
	return result


func _run() -> void:
	var tails: Dictionary = {}
	for kind in ["rabbit", "otter", "badger", "cat"]:
		var kart := AuthoredKart.new()
		kart.configure(kind, Color("7695ba"), "comet")
		root.add_child(kart)
		kart.set_process(false)
		_check(kart.eyes.size() == 2 and kart.ear_joints.size() == 2, kind + " retains blink and ear joints")
		for eye: Node3D in kart.eyes:
			var white: MeshInstance3D = eye.get_child(1)
			_check(white.scale.x < 0.090 and white.scale.z < 0.026, kind + " has small shallow eye shells")
			if kind == "rabbit":
				_check(white.scale.x <= 0.075 and white.scale.y <= 0.095 and white.scale.z <= 0.022, "Rabbit eye dimensions fit the narrower skull")
			for layer in [eye.get_child(2), eye.get_child(3)]:
				var follows_white := true
				for vertex: Vector3 in layer.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = layer.transform * vertex - white.position
					var radial: float = pow(p.x / white.scale.x, 2) + pow(p.y / white.scale.y, 2)
					var z: float = -white.scale.z * sqrt(maxf(0.0, 1.0 - radial))
					follows_white = follows_white and z - p.z > 0.0005 and z - p.z < 0.0035
				_check(follows_white, kind + " iris and pupil stay attached to the real eye surface")
		var head_coat: Node3D = kart.head.get_node("SculptedFur")
		var base: MeshInstance3D = head_coat.get_child(0)
		var colors: PackedColorArray = base.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		_check(not colors.is_empty() and base.material_override.roughness >= 0.8, kind + " has integrated matte coat pigmentation")
		var nose: MeshInstance3D = kart.head.get_node("SculptedNose")
		_check(nose.position.z - nose.scale.z > -0.40, kind + " compact muzzle replaces the projecting fox snout")
		var tail_coat: Node3D = kart.tail.get_child(0)
		var tail_mesh: MeshInstance3D = tail_coat.get_child(0)
		tails[kind] = tail_mesh.mesh.get_aabb().size
		_check(kart.get_node("AuroraCoachwork").get_meta("craftsmanship_revision", 0) == 1, "Craft finish is present on " + kind)
		var gloves: Array[Node] = kart.driver.find_children("GripGlove", "MeshInstance3D", true, false)
		var contacts: Array[Vector3] = []
		for glove: MeshInstance3D in gloves:
			contacts.append(kart.steering_wheel.to_local(glove.global_position))
		kart.set_motion(14.0, 0.8, false, false)
		for frame in range(6):
			kart._process(1.0 / 60.0)
		for index in range(gloves.size()):
			_check(gloves[index].global_position.distance_to(kart.steering_wheel.to_global(contacts[index])) < 0.0005, kind + " hand remains on moving wheel")
		kart.animation_time = 4.22
		kart._process(0.0)
		_check(kart.eyes[0].scale.y <= 0.08, kind + " smaller eyes still blink")
		kart.free()
		var runtime: LumoRaceKart = VEHICLE.new()
		runtime.configure(kind, Color("7695ba"), "comet")
		root.add_child(runtime)
		runtime.set_process(false)
		var stats: Vector2i = _geometry_stats(runtime, runtime.far_mesh)
		_check(stats.y <= 64, kind + " fits the existing mobile material surface budget")
		_check(runtime.far_mesh.mesh.get_surface_count() == 1, kind + " has one distant draw surface")
		print("[RivalFinish] ", kind, " near_triangles=", stats.x, " near_surfaces=", stats.y)
		runtime.free()
	_check(tails.rabbit.z < 0.35, "Rabbit retains a compact pompom tail")
	_check(tails.otter.z > 0.90 and tails.otter.y < 0.40, "Otter has a long low tapering tail")
	_check(tails.badger.z < 0.55, "Badger has a short brush tail")
	_check(tails.cat.y > 0.60 and tails.cat.x < 0.20, "Cat has a narrow raised curling tail")
	print("[RivalFinish] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("[RivalFinish] PASS: real eye attachment, species silhouettes, wheel contacts, mobile batches")
	quit(0 if failures.is_empty() else 1)
