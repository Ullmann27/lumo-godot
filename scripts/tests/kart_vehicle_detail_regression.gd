extends SceneTree
## Checks authored mechanical contact and actual tyre topology, then the mobile batches.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")


class AuthoredKart:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _surfaces(node: Node3D, kart: LumoRaceKart) -> int:
	var count: int = 0
	for child in node.get_children():
		if child is MeshInstance3D:
			if child != kart.far_mesh and not kart.flames.has(child) and not kart.sparks.has(child):
				count += child.mesh.get_surface_count()
		elif child is Node3D:
			count += _surfaces(child, kart)
	return count


func _run() -> void:
	var authored := AuthoredKart.new()
	authored.configure("fox", Color("76d9ff"))
	root.add_child(authored)
	authored.set_process(false)
	var tyre: ArrayMesh = authored._make_tyre_geometry()
	var arrays: Array = tyre.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tread_low: float = 1.0
	var tread_high: float = 0.0
	for index in range(positions.size()):
		var vertex: Vector3 = positions[index]
		var radius: float = Vector2(vertex.x, vertex.z).length()
		assert(radius <= 0.3501, "Tread stays within the tyre radius; no protruding spikes")
		assert(absf(vertex.y) <= 0.1901)
		assert(normals[index].is_finite() and normals[index].length() > 0.99)
		if is_zero_approx(vertex.y):
			tread_low = minf(tread_low, radius)
			tread_high = maxf(tread_high, radius)
			assert(normals[index].dot(Vector3(vertex.x, 0, vertex.z).normalized()) > 0.70)
	assert(tread_high - tread_low >= 0.013, "Directional tread is sculpted into the actual surface")
	var far: Mesh = authored._far_geometry(tyre)
	assert(far.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < positions.size() * 0.15)
	var seat: MeshInstance3D = authored.get_node("AuroraCoachwork/ContouredSeatShell")
	assert(seat.mesh.get_aabb().size.y > 0.44, "Seat supports the back below the visible L badge")
	assert(seat.mesh.get_aabb().end.y < 1.12, "Chase camera can see Lumo's back emblem")
	assert(seat.mesh.get_aabb().position.y < 0.64, "Seat shell enters the chassis")
	var neck: MeshInstance3D = authored.driver.get_node("NeckBridge")
	var neck_bounds: AABB = neck.mesh.get_aabb()
	assert(
		neck_bounds.position.y < 1.32 and neck_bounds.end.y > 1.36, "Neck connects collar and head"
	)
	var wheel_inverse: Transform3D = authored.steering_wheel.global_transform.affine_inverse()
	var grips: Array[Node] = authored.driver.find_children(
		"GripGlove", "MeshInstance3D", true, false
	)
	assert(grips.size() == 2)
	for glove: MeshInstance3D in grips:
		var contact: Vector3 = wheel_inverse * glove.global_position
		assert(absf(contact.z) < 0.04, "Glove touches the wheel plane")
		var rim_radius: float = Vector2(contact.x, contact.y).length()
		assert(rim_radius >= 0.135 and rim_radius <= 0.175, "Both gloves meet the grip rim")
	for index in range(4):
		var pivot: Node3D = authored.wheel_pivots[index]
		var rotor: Node3D = authored.wheel_rotors[index]
		assert(
			rotor.get_node("DirectionalTyre").mesh == tyre,
			"Four wheels share the same tyre geometry"
		)
		assert(pivot.has_node("BrakeCaliper"), "Calipers follow steering, not wheel spin")
		assert(pivot.get_node("BrakeCaliper").get_parent() == pivot)
	var front_axle: MeshInstance3D = authored.get_node("FrontAxleShaft")
	var rear_axle: MeshInstance3D = authored.get_node("RearAxleShaft")
	assert(is_equal_approx(front_axle.mesh.height, 1.54))
	assert(is_equal_approx(rear_axle.mesh.height, 1.54))
	authored.free()
	for entry in CATALOG.KARTS:
		var kart: LumoRaceKart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), str(entry.id))
		root.add_child(kart)
		kart.set_process(false)
		var count: int = _surfaces(kart, kart)
		print("[KartDetails] measured ", entry.id, ": ", count, " surfaces")
		assert(count <= 64, "Detailed fleet retains the mobile surface budget")
		assert(kart.far_mesh.mesh.get_surface_count() == 1)
		var body: Node3D = kart.get_node("AuroraCoachwork")
		assert(body.get_meta("seat_design") == "contoured_bucket")
		assert(body.get_meta("body_detail_revision") == 2)
		kart.set_motion(14.0, 0.65, true, true)
		kart._process(0.04)
		assert(kart.flames[0].visible and kart.sparks[0].visible)
		assert(absf(kart.wheel_pivots[0].rotation.y) > 0.2)
		print(
			(
				"[KartDetails] %s: %d surfaces, sculpted tyre, connected cockpit, moving chassis"
				% [entry.id, count]
			)
		)
		kart.free()
	print("[KartDetails] PASS: tyre topology/normals/LOD, seat/head/grip contact, 9 mobile designs")
	quit()
