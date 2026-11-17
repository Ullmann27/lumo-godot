extends RefCounted
## Original tactile cave dressing: seven actual material batches, no physics.
const KIT = preload("res://scripts/games/kart_cavern_mineral_kit.gd")
const CINEMA = preload("res://scripts/games/visual/kart_cinema_materials.gd")
const PLACEMENT_SEED: int = 261018
const GROUND_BATCHES: Array[String] = [
	"StratifiedBoulders", "MineralSplitLedges", "FactoryCrystalGardens",
	"CrystalSpireGardens", "CrystalRosetteGardens", "MineralWaterChannels",
]


static func build(parent: Node3D, world, from_m: float, to_m: float) -> void:
	var low: bool = world.low_detail
	var root := Node3D.new()
	root.name = "CavernGeology"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = PLACEMENT_SEED
	var count: int = 26 if low else 44
	var stone: ShaderMaterial = CINEMA.material(Color.WHITE, "stone", low, true, true)
	var crystal: ShaderMaterial = CINEMA.material(Color.WHITE, "crystal", low, true, true)
	var rocks := _batch(root, "StratifiedBoulders", KIT.mesh("strata_shelf", low), count * 2, stone)
	var ledges := _batch(root, "MineralSplitLedges", KIT.mesh("split_ledge", low), count / 2, stone)
	var roof := _batch(root, "StalactiteVault", KIT.mesh("hanging_canopy", low), count / 2, stone)
	var fans := _batch(root, "FactoryCrystalGardens", KIT.mesh("crystal_fan", low), count / 2, crystal)
	var spires := _batch(root, "CrystalSpireGardens", KIT.mesh("crystal_spire", low), count / 3, crystal)
	var rosettes := _batch(root, "CrystalRosetteGardens", KIT.mesh("crystal_rosette", low), count / 2, crystal)
	var pool := BoxMesh.new()
	pool.size = Vector3.ONE
	var pools := _batch(root, "MineralWaterChannels", pool, count,
		CINEMA.material(Color("74bdc8"), "water", low, true, true))
	for i in range(count):
		var fraction: float = (float(i) + 0.5) / float(count)
		var d: float = lerpf(from_m + 7.0, to_m - 7.0, fraction)
		for bank in range(2):
			var side: float = -1.0 if bank == 0 else 1.0
			var height: float = rng.randf_range(0.86, 1.43)
			var size := Vector3(rng.randf_range(0.85, 1.08), height, rng.randf_range(0.86, 1.28))
			_place(rocks, i * 2 + bank, world, d + rng.randf_range(-1.2, 1.2),
				side * rng.randf_range(7.65, 7.90), -0.07, size,
				rng.randf_range(-0.12, 0.12), Color("7c929e").lerp(Color("b0a9bb"), rng.randf()))
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_place(pools, i, world, d, -side * 6.95, 0.075,
			Vector3(1.6, 0.035, rng.randf_range(4.5, 6.1)), 0.0,
			Color("7ccad2").lerp(Color("b3deda"), rng.randf()))
	for i in range(ledges.multimesh.instance_count):
		var d: float = _distance(from_m, to_m, i, ledges.multimesh.instance_count, 0.65)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_place(ledges, i, world, d, side * 7.75, 1.45 + rng.randf_range(0.0, 0.55),
			Vector3(0.92, rng.randf_range(0.8, 1.18), rng.randf_range(0.9, 1.3)),
			rng.randf_range(-0.15, 0.15), Color("a5a5af").lerp(Color("748e9d"), rng.randf()))
	for i in range(roof.multimesh.instance_count):
		var d: float = _distance(from_m, to_m, i, roof.multimesh.instance_count, 0.40)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_place(roof, i, world, d, side * rng.randf_range(2.8, 4.2),
			rng.randf_range(6.35, 6.75), Vector3(1.0, 0.84, rng.randf_range(0.82, 1.25)),
			rng.randf_range(-0.30, 0.30), Color("8b9cae").lerp(Color("b3aaba"), rng.randf()))
	var gardens: Array[MultiMeshInstance3D] = [fans, spires, rosettes]
	for variant in range(gardens.size()):
		var garden: MultiMeshInstance3D = gardens[variant]
		for i in range(garden.multimesh.instance_count):
			var d: float = _distance(from_m, to_m, i, garden.multimesh.instance_count,
				0.17 + float(variant) * 0.28)
			var side: float = -1.0 if (i + variant) % 2 == 0 else 1.0
			var width: float = rng.randf_range(0.48, 0.64) if variant == 0 else rng.randf_range(0.62, 0.80)
			var size := Vector3(width, rng.randf_range(0.83, 1.23), width)
			var tint: Color = Color("98e1dc").lerp(Color("c6b2e3"), rng.randf())
			if (i + variant) % 7 == 0:
				tint = Color("e3c69a")
			_place(garden, i, world, d, side * rng.randf_range(7.08, 7.30), 0.19, size,
				rng.randf_range(-0.48, 0.48), tint)
	var minimum_shoulder: float = INF
	var triangle_instances: int = 0
	var draw_batches: int = 0
	for child in root.get_children():
		var node := child as MultiMeshInstance3D
		assert(node != null)
		draw_batches += node.multimesh.mesh.get_surface_count()
		triangle_instances += _triangles(node.multimesh.mesh) * node.multimesh.instance_count
		if GROUND_BATCHES.has(str(node.name)):
			minimum_shoulder = minf(minimum_shoulder, _actual_clearance(node, world, false))
	var roof_tip: float = _actual_clearance(roof, world, true)
	assert(minimum_shoulder >= 5.6, "Original mineral assets must preserve the racing shoulder")
	assert(roof_tip >= 5.8, "Hanging mineral canopies must preserve actual roof clearance")
	root.set_meta("production_metrics", {
		"draw_batches": draw_batches,
		"low_detail": low,
		"crystal_clusters": fans.multimesh.instance_count + spires.multimesh.instance_count + rosettes.multimesh.instance_count,
		"crystal_triangles": KIT.triangles("crystal_fan", low) + KIT.triangles("crystal_spire", low) + KIT.triangles("crystal_rosette", low),
		"rock_instances": rocks.multimesh.instance_count + ledges.multimesh.instance_count,
		"min_shoulder_lateral_m": minimum_shoulder,
		"minimum_stalactite_tip_m": roof_tip,
		"asset_origin": "Lumo original Blender-authored mineral kit; no external source",
		"asset_variants": 6,
		"instanced_triangles": triangle_instances,
		"placement_seed": PLACEMENT_SEED,
		"physical_device_fps_verified": false,
	})


static func _distance(from_m: float, to_m: float, i: int, count: int, offset: float) -> float:
	return lerpf(from_m + 9.0, to_m - 9.0, (float(i) + offset) / float(count))


static func _place(node: MultiMeshInstance3D, index: int, world, distance: float,
		lateral: float, height: float, size: Vector3, yaw: float, tint: Color) -> void:
	var frame: Basis = world.frame(distance)
	var transform := Transform3D((frame * Basis(Vector3.UP, yaw)).scaled_local(size),
		world.position_at(distance, lateral) + frame.y * height)
	node.multimesh.set_instance_transform(index, transform)
	node.multimesh.set_instance_color(index, tint)
	var transforms: Array[Transform3D] = node.get_meta("placement_transforms")
	transforms[index] = transform
	node.set_meta("placement_transforms", transforms)
	var distances: PackedFloat32Array = node.get_meta("placement_distances")
	distances[index] = distance
	node.set_meta("placement_distances", distances)


static func _batch(parent: Node3D, name: String, mesh: Mesh, count: int,
		material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var distances := PackedFloat32Array()
	distances.resize(count)
	node.set_meta("placement_distances", distances)
	var transforms: Array[Transform3D] = []
	transforms.resize(count)
	transforms.fill(Transform3D.IDENTITY)
	node.set_meta("placement_transforms", transforms)
	parent.add_child(node)
	return node


static func _triangles(mesh: Mesh) -> int:
	var total: int = 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return total


static func _actual_clearance(node: MultiMeshInstance3D, world, roof: bool) -> float:
	var minimum: float = INF
	var bounds: AABB = node.multimesh.mesh.get_aabb()
	var distances: PackedFloat32Array = node.get_meta("placement_distances")
	# Exact submitted transforms avoid synchronous renderer readbacks during build.
	# Godot's headless dummy backend discards MultiMesh buffers entirely. The
	# rendered regression independently verifies these against actual GPU uploads.
	var transforms: Array[Transform3D] = node.get_meta("placement_transforms")
	for i in range(node.multimesh.instance_count):
		var transform: Transform3D = transforms[i]
		var road: Dictionary = world.sample_road(transform.origin, float(distances[i]))
		var frame: Basis = world.frame(float(road.distance))
		var center: Vector3 = world.position_at(float(road.distance))
		for corner in range(8):
			var point: Vector3 = transform * bounds.get_endpoint(corner)
			var clearance: float = (point - center).dot(frame.y) if roof else absf((point - center).dot(frame.x))
			minimum = minf(minimum, clearance)
	return minimum
