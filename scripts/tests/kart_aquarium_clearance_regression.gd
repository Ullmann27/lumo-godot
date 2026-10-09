extends SceneTree
## Actual aquarium mesh bounds, animated schools, batching and unchanged race geometry.

const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const AQUARIUM = preload("res://scripts/games/kart_harbor_aquarium.gd")
const CLEAR_LATERAL: float = 6.35
const CLEAR_HEIGHT: float = 3.2
const MOTION_PADDING := Vector3(0.0, 0.18, 0.6)

var failures: Array[String] = []


class AquariumProbeWorld:
	extends "res://scripts/games/kart_world.gd"
	var uploaded: Dictionary = {}

	func _flush_instances() -> void:
		uploaded = groups.duplicate(true)
		super._flush_instances()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _corners(box: AABB) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				result.append(box.position + box.size * Vector3(x, y, z))
	return result


func _clear_point(world, point: Vector3) -> bool:
	var road: Dictionary = world.sample_road(point)
	var centre: Vector3 = world.position_at(float(road.distance))
	var road_frame: Basis = road.basis
	var local: Vector3 = road_frame.transposed() * (point - centre)
	return absf(local.x) >= CLEAR_LATERAL or local.y >= CLEAR_HEIGHT or local.y < -0.5


func _static_geometry(world, lightweight: bool) -> void:
	var reef_rocks: int = 0
	var clear: bool = true
	for key in world.uploaded:
		var group: Dictionary = world.uploaded[key]
		var node: MultiMeshInstance3D = world.get_node("Decor_" + str(key))
		_check(
			node.multimesh.instance_count == group.transforms.size(),
			"Every static aquarium detail must reach a GPU instance batch"
		)
		var mesh: Mesh = node.multimesh.mesh
		for index in range(group.transforms.size()):
			var transform: Transform3D = group.transforms[index]
			var road: Dictionary = world.sample_road(transform.origin)
			var tunnel_distance: float = float(road.distance) - world.length * AQUARIUM.START
			# The six original slalom cones precede the tunnel and intentionally touch a lane.
			if tunnel_distance < -3.0 or tunnel_distance > AQUARIUM.SPAN + 3.0:
				continue
			if group.kind == "rock":
				reef_rocks += 1
			if DisplayServer.get_name() != "headless":
				_check(
					node.multimesh.get_instance_transform(index).is_equal_approx(transform),
					"The rendered batch must contain the measured static transform"
				)
			for corner in _corners(mesh.get_aabb()):
				clear = _clear_point(world, transform * corner) and clear
	_check(
		reef_rocks >= (9 if lightweight else 12),
		"Both detail levels need substantial batched reefs"
	)
	_check(clear, "Static tunnel geometry must clear the road and its 30 cm rail margin")


func _schools(world, aquarium, lightweight: bool) -> int:
	var expected_leaders: int = 4 if lightweight else 8
	_check(
		aquarium.fish.size() == expected_leaders, "Preserve the four/eight animated leader budget"
	)
	var shared_mesh: Mesh
	var shared_material: Material
	var fish_count: int = 0
	var geometry_clear: bool = true
	var leaders: Array[Transform3D] = []
	for leader in aquarium.fish:
		var rest: Vector3 = leader.get_meta("rest")
		var rest_transform := Transform3D(leader.basis, rest)
		leaders.append(rest_transform)
		var batches: Array[Node] = leader.find_children("*", "MultiMeshInstance3D", true, false)
		_check(batches.size() == 1, "Each fish leader must render one instanced school")
		if batches.size() != 1:
			continue
		var school: MultiMeshInstance3D = batches[0] as MultiMeshInstance3D
		var instances: MultiMesh = school.multimesh
		_check(
			instances.instance_count >= (3 if lightweight else 5),
			"LOW/HIGH must show at least three/five fish in each school"
		)
		fish_count += instances.instance_count
		if shared_mesh == null:
			shared_mesh = instances.mesh
			shared_material = school.material_override
		_check(instances.mesh == shared_mesh, "All fish schools must share one authored mesh")
		_check(school.material_override == shared_material, "Fish schools must share one material")
		_check(instances.mesh.get_surface_count() == 1, "Each school uses one draw surface")
		var vertices: PackedVector3Array = instances.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(
			vertices.size() <= 2400,
			"The shared fish mesh must stay within its mobile vertex budget"
		)
		# The dummy renderer cannot read back MultiMesh transforms. The X11 run verifies them.
		if DisplayServer.get_name() == "headless":
			continue
		_check(
			instances.get_instance_transform(instances.instance_count - 1).origin.length() > 1.0,
			"The rendered school must contain separated fish, not overlapping instances"
		)
		for index in range(instances.instance_count):
			var formation: Transform3D = school.transform * instances.get_instance_transform(index)
			for corner in _corners(instances.mesh.get_aabb()):
				# Sweep the entire bounded motion, not only the frame captured on screen.
				for y_sign in [-1.0, 1.0]:
					for z_sign in [-1.0, 1.0]:
						var offset := MOTION_PADDING * Vector3(0.0, y_sign, z_sign)
						var point: Vector3 = rest_transform * (formation * corner + offset)
						geometry_clear = _clear_point(world, point) and geometry_clear
	_check(geometry_clear, "The complete fish-school sweep must stay outside the driving corridor")
	var stays_in_frame: bool = true
	var moves: bool = false
	# The two frequencies repeat together after 40 PI seconds.
	aquarium.age = 0.0
	for step in range(65):
		aquarium._process(0.0 if step == 0 else TAU / 0.05 / 64.0)
		for index in range(aquarium.fish.size()):
			var delta: Vector3 = (
				leaders[index].basis.transposed()
				* (aquarium.fish[index].position - leaders[index].origin)
			)
			stays_in_frame = (
				stays_in_frame
				and absf(delta.x) < 0.0001
				and absf(delta.y) <= MOTION_PADDING.y + 0.0001
				and absf(delta.z) <= MOTION_PADDING.z + 0.0001
			)
			moves = moves or delta.length() > 0.1
	_check(stays_in_frame, "Fish must swim within the local banked road frame for a full cycle")
	_check(moves, "The displayed fish schools must actually animate")
	return fish_count


func _water_coordinates(aquarium) -> void:
	var water: MeshInstance3D
	var transparent_shells: int = 0
	for child in aquarium.get_children():
		if not child is MeshInstance3D:
			continue
		if child.material_override is ShaderMaterial:
			water = child
		elif child.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = child.material_override
			if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				transparent_shells += 1
	_check(transparent_shells == 1, "Keep one transparent glass shell to bound mobile overdraw")
	_check(water != null, "The aquarium must retain its opaque water backdrop")
	if water == null:
		return
	var arrays: Array = water.mesh.surface_get_arrays(0)
	if typeof(arrays[Mesh.ARRAY_TEX_UV]) != TYPE_PACKED_VECTOR2_ARRAY:
		_check(false, "Water depth and caustics require tunnel-local coordinates at every vertex")
		return
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_check(
		uv.size() == vertices.size(),
		"Water depth and caustics require tunnel-local coordinates at every vertex"
	)
	if uv.is_empty():
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in uv:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	_check(minimum.is_equal_approx(Vector2.ZERO), "Tunnel-local water coordinates start at zero")
	_check(
		maximum.is_equal_approx(Vector2(AQUARIUM.SPAN, 1.0)),
		"Water coordinates follow passage distance and arch position, independent of world height"
	)


func _run() -> void:
	var counts: Array[Vector2i] = []
	for lightweight in [true, false]:
		var world = AquariumProbeWorld.new()
		root.add_child(world)
		world.low_detail = lightweight
		world.definition = TRACKS.definition("sonnenhafen")
		world._make_curve()
		var original_curve: PackedVector3Array = world.curve.get_baked_points().duplicate()
		var original_gates: PackedVector3Array = world.checkpoint_positions.duplicate()
		var original_length: float = world.length
		var original_action: Dictionary = world.action.duplicate(true)
		var original_jump: Dictionary = world.jump.duplicate(true)
		AQUARIUM.build(world)
		var aquarium = world.get_node("HarborAquarium")
		aquarium.set_process(false)
		world._flush_instances()
		await process_frame
		_check(world.curve.get_baked_points() == original_curve, "Preserve every baked road point")
		_check(world.length == original_length, "Preserve the complete course length")
		_check(
			world.checkpoint_positions == original_gates and original_gates.size() == 8,
			"Preserve all eight ordered checkpoint positions"
		)
		_check(
			world.action == original_action and world.jump == original_jump,
			"Preserve action/ramp/gap layout"
		)
		_check(world.action_obstacles.size() == 6, "Preserve the six original slalom cones")
		for index in range(mini(world.action_obstacles.size(), 6)):
			var side: float = -1.0 if index % 2 == 0 else 1.0
			var expected: Vector3 = world.position_at(world.length * 0.30 + index * 4.5, side * 3.9)
			_check(
				world.action_obstacles[index].is_equal_approx(expected),
				"Preserve every slalom hit position"
			)
		for child in world.find_children("*", "", true, false):
			_check(
				not (child is PhysicsBody3D or child is Area3D or child is CollisionShape3D),
				"Aquarium scenery must add no physical bodies, triggers or collision shapes"
			)
		_static_geometry(world, lightweight)
		var fish_count: int = _schools(world, aquarium, lightweight)
		_water_coordinates(aquarium)
		_check(
			world.decoration_count <= (340 if lightweight else 400),
			"Static reef detail exceeds its mobile budget"
		)
		_check(
			(
				world.find_children("*", "GeometryInstance3D", true, false).size()
				<= (40 if lightweight else 48)
			),
			"Aquarium draw batches exceed their mobile budget"
		)
		counts.append(Vector2i(world.decoration_count, fish_count))
		print(
			(
				"[KartAquarium] %s: %d batched props, %d fish"
				% ["LOW" if lightweight else "HIGH", world.decoration_count, fish_count]
			)
		)
		world.queue_free()
		await process_frame
	_check(
		counts[0].x < counts[1].x and counts[0].y < counts[1].y,
		"LOW must reduce both static and animated work"
	)
	if not failures.is_empty():
		for failure in failures:
			push_error("[KartAquarium] " + failure)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[KartAquarium] Headless: GPU instance readback deferred to the rendered probe")
	else:
		print(
			"[KartAquarium] GPU instance clearance verified for the complete school motion envelope"
		)
	print(
		"[KartAquarium] PASS: schools, reefs, clearance, water UVs, budgets and preserved race geometry"
	)
	quit(0)
