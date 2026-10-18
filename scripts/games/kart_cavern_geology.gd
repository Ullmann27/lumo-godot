extends RefCounted
## Original Lumo cave set dressing. Five material batches, no physics nodes.
const HIGH = preload("res://assets/kart/cavern/sonnenhafen_biolum_cavern_crystals_high.glb")
const MOBILE = preload("res://assets/kart/cavern/sonnenhafen_biolum_cavern_crystals_mobile.glb")
const STONE = preload("res://assets/shaders/kart_cavern_stone.gdshader")
const WATER = preload("res://assets/shaders/kart_cavern_water.gdshader")
static var _rock_mesh: ArrayMesh


static func build(parent: Node3D, world, from_m: float, to_m: float) -> void:
	var low: bool = world.low_detail
	var root := Node3D.new()
	root.name = "CavernGeology"
	parent.add_child(root)
	var count: int = 26 if low else 44
	var stone := ShaderMaterial.new()
	stone.shader = STONE
	var rocks := _batch(root, "StratifiedBoulders", _rock(), count * 2, stone)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.7
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 6 if low else 9
	var roof := _batch(root, "StalactiteVault", cone, count, stone)
	var scene: Node = (MOBILE if low else HIGH).instantiate()
	var model: MeshInstance3D = scene.find_child("*", true, false) as MeshInstance3D
	if model == null:
		for child in scene.get_children():
			if child is MeshInstance3D:
				model = child
	assert(model != null, "Factory scene lost its mesh")
	var crystals := _batch(root, "FactoryCrystalGardens", model.mesh, count, null)
	scene.free()
	var pool := BoxMesh.new()
	pool.size = Vector3.ONE
	var water := ShaderMaterial.new()
	water.shader = WATER
	var pools := _batch(root, "MineralWaterChannels", pool, count, water)
	for i in range(count):
		var d: float = lerpf(from_m + 5.0, to_m - 5.0, float(i) / float(count - 1))
		var frame: Basis = world.frame(d)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		for bank in range(2):
			var sign_x: float = -1.0 if bank == 0 else 1.0
			var variation: float = 0.5 + 0.5 * sin(float(i) * 2.73 + float(bank))
			var size := Vector3(1.3, 1.5 + variation * 2.0, 2.7)
			var at: Vector3 = world.position_at(d, sign_x * 8.05) + frame.y * (size.y * 0.36)
			rocks.multimesh.set_instance_transform(
				i * 2 + bank,
				Transform3D((frame * Basis(Vector3.RIGHT, float(i) * 0.23)).scaled_local(size), at)
			)
			rocks.multimesh.set_instance_color(
				i * 2 + bank, Color("34445f").lerp(Color("48547d"), variation)
			)
		var ceiling: Vector3 = (
			world.position_at(d, side * (2.0 + sin(float(i)) * 1.7)) + frame.y * 8.1
		)
		roof.multimesh.set_instance_transform(
			i, Transform3D(frame.scaled_local(Vector3(0.8, 2.0, 0.8)), ceiling)
		)
		roof.multimesh.set_instance_color(i, Color("45526f"))
		var crystal_at: Vector3 = world.position_at(d, side * 7.5) + frame.y * 0.30
		crystals.multimesh.set_instance_transform(
			i,
			Transform3D(
				(frame * Basis(Vector3.UP, float(i) * 1.9)).scaled_local(
					Vector3(0.54, 0.7 + 0.14 * sin(float(i)), 0.54)
				),
				crystal_at
			)
		)
		var pool_at: Vector3 = world.position_at(d, -side * 6.95) + frame.y * 0.10
		pools.multimesh.set_instance_transform(
			i, Transform3D(frame.scaled_local(Vector3(1.6, 0.04, 5.8)), pool_at)
		)
	(
		root
		. set_meta(
			"production_metrics",
			{
				"draw_batches": 5,
				"low_detail": low,
				"crystal_clusters": count,
				"crystal_triangles": 144 if low else 324,
				"rock_instances": count * 2,
				"min_shoulder_lateral_m": 5.8,
				"minimum_stalactite_tip_m": 7.1,
				"asset_origin": "Lumo deterministic 3D factory; original geometry",
			}
		)
	)


static func _batch(
	parent: Node3D, name: String, mesh: Mesh, count: int, material: Material
) -> MultiMeshInstance3D:
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
	parent.add_child(node)
	return node


static func _rock() -> ArrayMesh:
	if _rock_mesh != null:
		return _rock_mesh
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 11
	sphere.rings = 6
	var faces: PackedVector3Array = sphere.get_faces()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var points: Array[Vector3] = []
		for j in range(3):
			var p: Vector3 = faces[i + j]
			p *= 1.0 + 0.13 * sin(p.x * 9.0 + p.y * 4.0) * cos(p.z * 8.0)
			points.append(p)
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		for p in points:
			surface.set_normal(normal)
			surface.add_vertex(p)
	_rock_mesh = surface.commit()
	return _rock_mesh
