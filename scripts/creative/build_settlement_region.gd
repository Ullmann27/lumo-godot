extends Node3D
## Bounded, spatially batched scenery for two 33 × 33 settlement districts.
## Plot identity is stable: the original first 25 cells keep their exact coordinates.
const KIT = preload("res://scripts/creative/creative_kit.gd")
const DAY = preload("res://scripts/creative/creative_nextgen_environment.gd")
const SPACING := 5.3
const TOWN_CENTER := 100.0
const MAX_PLOTS := 1089
const HALF_EXTENT := 94.0
const CHUNK_SIZE := 47.0
const DISTRICT_COLORS := [Color("9dbb75"), Color("abc080"), Color("a5ba75"), Color("b4c887")]
var _kit := KIT.new()
var _chunks: Array[Node3D] = []
var _built := false
var _last_focus := Vector3(INF, INF, INF)


static func plot_coordinate(index: int) -> Vector2i:
	if index < 0 or index >= MAX_PLOTS:
		return Vector2i(10000, 10000)
	if index < 9:
		return Vector2i(index % 3 - 1, index / 3 - 1)
	var ring := 2
	while index >= (ring * 2 + 1) * (ring * 2 + 1):
		ring += 1
	var offset := index - (ring * 2 - 1) * (ring * 2 - 1)
	if offset < ring * 2:
		return Vector2i(ring, offset - ring + 1)
	offset -= ring * 2
	if offset < ring * 2 - 1:
		return Vector2i(offset - ring + 1, ring)
	offset -= ring * 2 - 1
	if offset < ring * 2 + 1:
		return Vector2i(-ring, offset - ring)
	offset -= ring * 2 + 1
	return Vector2i(offset - ring + 1, -ring)


static func plot_position(index: int, opponent := false) -> Vector3:
	var coordinate := plot_coordinate(index)
	return Vector3((TOWN_CENTER if opponent else -TOWN_CENTER) + coordinate.x * SPACING, 0.03, coordinate.y * SPACING)


static func extent_for_plots(count: int) -> float:
	var bounded := clampi(count, 1, MAX_PLOTS)
	var furthest := 1
	for index in range(bounded):
		var coordinate := plot_coordinate(index)
		furthest = maxi(furthest, maxi(absi(coordinate.x), absi(coordinate.y)))
	return (float(furthest) + 0.8) * SPACING


func build_landscape(mode := "settlement") -> void:
	if _built:
		return
	_built = true
	name = "LivingVillageRegion"
	for side in [false, true]:
		_build_bank(side)
	_build_river()
	for z in [-58.3, 0.0, 58.3]:
		_build_bridge(z)
	_build_waterfront(false)
	_build_waterfront(true)
	_title("LUMOS WIESENSTADT", Vector3(-TOWN_CENTER, 3.3, -91.0), Color("fff3d2"))
	_title("MIRAS NACHBARDORF" if mode == "rival" else "DAS NACHBARDORF", Vector3(TOWN_CENTER, 3.3, -91.0), Color("ffd5af"))
	set_meta("max_plots_per_town", MAX_PLOTS)
	set_meta("land_dimensions", Vector2(HALF_EXTENT * 2.0, HALF_EXTENT * 2.0))
	set_meta("scenery_chunks", _chunks.size())
	update_focus(Vector3(-TOWN_CENTER, 0, 0))


func _build_bank(opponent: bool) -> void:
	var center := TOWN_CENTER if opponent else -TOWN_CENTER
	var bank := StaticBody3D.new()
	bank.name = "NeighborLand" if opponent else "PlayerLand"
	add_child(bank)
	var side := _kit.box(bank, Vector3(center, -1.4, 0), Vector3(HALF_EXTENT * 2.0, 2.8, HALF_EXTENT * 2.0), Color("c3ad80"))
	side.material_override = DAY.bank_material()
	_kit.collision(bank, Vector3(center, -1.4, 0), Vector3(HALF_EXTENT * 2.0, 2.8, HALF_EXTENT * 2.0))
	var road_shapes: Array[Transform3D] = []
	for grid in range(-17, 17):
		var lane := (float(grid) + 0.5) * SPACING
		road_shapes.append(Transform3D(Basis.from_scale(Vector3(0.73, 0.018, 181.0)), Vector3(center + lane, 0.024, 0)))
		road_shapes.append(Transform3D(Basis.from_scale(Vector3(181.0, 0.018, 0.73)), Vector3(center, 0.025, lane)))
	_batch(self, "VillageLanes", _box_mesh(), road_shapes, Color("c9c7a3"), 0)
	for z_index in range(4):
		for x_index in range(4):
			var chunk := Node3D.new()
			chunk.name = "District_%s_%d_%d" % ["neighbor" if opponent else "home", x_index, z_index]
			chunk.position = Vector3(center - HALF_EXTENT + CHUNK_SIZE * (x_index + 0.5), 0, -HALF_EXTENT + CHUNK_SIZE * (z_index + 0.5))
			add_child(chunk)
			_chunks.append(chunk)
			var grass := _kit.box(self, chunk.position + Vector3(0, 0.006, 0), Vector3(CHUNK_SIZE, 0.012, CHUNK_SIZE), DISTRICT_COLORS[(x_index + z_index) % 4])
			var material := DAY.ground_material().duplicate() as StandardMaterial3D
			material.albedo_color = DISTRICT_COLORS[(x_index + z_index) % 4]
			grass.material_override = material
			_decorate_chunk(chunk, x_index, z_index, opponent)
	# The entrance plaza lies outside every buildable cell, including the final ring.
	_kit.box(self, Vector3(center, 0.04, -90.3), Vector3(13.0, 0.05, 4.8), Color("dbcfad"))
	for x in [-5.0, 5.0]:
		_kit.cylinder(self, Vector3(center + x, 1.1, -90.3), 0.09, 2.2, Color("8c6140"))
		_kit.sphere(self, Vector3(center + x, 2.3, -90.3), Vector3.ONE * 0.42, Color("ffd68a"))


func _decorate_chunk(chunk: Node3D, xi: int, zi: int, opponent: bool) -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i in range(12):
		var local := Vector3(-21.5 + fmod(float(i * 13 + xi * 7), 43.0), 0, -21.5 + fmod(float(i * 19 + zi * 5), 43.0))
		var world := chunk.position + local
		var center := TOWN_CENTER if opponent else -TOWN_CENTER
		var edge := maxf(absf(world.x - center), absf(world.z))
		if edge < 88.7:
			continue
		var height := 2.6 + float(i % 3) * 0.6
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.32, height, 0.32)), local + Vector3.UP * (height * 0.5)))
		crowns.append(Transform3D(Basis.from_scale(Vector3(2.0, 2.3, 2.0)), local + Vector3.UP * (height + 0.3)))
		rocks.append(Transform3D(Basis.from_scale(Vector3(0.75, 0.35, 0.6)), local + Vector3(1.2, 0.20, 0.5)))
		for petal in range(3):
			flowers.append(Transform3D(Basis.from_scale(Vector3(0.18, 0.22, 0.18)), local + Vector3(0.5 + petal * 0.27, 0.18, -1.1)))
	_batch(chunk, "OrchardTrunks", _box_mesh(), trunks, Color("966338"))
	_batch(chunk, "OrchardCanopies", _sphere_mesh(), crowns, Color("5b974b"))
	_batch(chunk, "MeadowFlowers", _sphere_mesh(), flowers, Color("f4b957"))
	_batch(chunk, "RoundedRiverStones", _sphere_mesh(), rocks, Color("a8aaa1"))


func _build_river() -> void:
	var water := _kit.box(self, Vector3(0, -0.32, 0), Vector3(11.9, 0.10, 230), Color("489bb1"))
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/shaders/kart_water.gdshader")
	water.material_override = shader
	for x in [-6.2, 6.2]:
		var rocks: Array[Transform3D] = []
		for i in range(45):
			rocks.append(Transform3D(Basis.from_scale(Vector3(0.9, 0.65, 1.6)), Vector3(x, -0.18, -92.0 + i * 4.2)))
		_batch(self, "RiverbankStones", _sphere_mesh(), rocks, Color("b7b2a2"), 220)
	var hill_shapes: Array[Transform3D] = []
	for i in range(12):
		hill_shapes.append(Transform3D(Basis.from_scale(Vector3(30 + (i % 3) * 9, 10 + (i % 4) * 4, 24)), Vector3(-220 + i * 40, -7, -120 - (i % 2) * 10)))
	_batch(self, "DistantSoftHills", _sphere_mesh(), hill_shapes, Color("789d83"), 0)


func _build_bridge(z: float) -> void:
	var bridge := StaticBody3D.new()
	bridge.name = "VillageRiverBridge_%d" % int(z)
	add_child(bridge)
	_kit.box(bridge, Vector3(0, 0.06, z), Vector3(13.5, 0.16, 2.3), Color("d8b785"))
	_kit.collision(bridge, Vector3(0, -0.03, z), Vector3(13.5, 0.20, 2.3))
	var planks: Array[Transform3D] = []
	for i in range(19):
		planks.append(Transform3D(Basis.from_scale(Vector3(0.045, 0.02, 2.16)), Vector3(-6.3 + i * 0.7, 0.15, z)))
	_batch(bridge, "BridgePlankSeams", _box_mesh(), planks, Color("a78353"))
	for side in [-1.0, 1.0]:
		_kit.box(bridge, Vector3(0, 0.78, z + side * 1.12), Vector3(13.4, 0.12, 0.12), Color("a67d4a"))
		for x in [-6.3, -3.1, 0.0, 3.1, 6.3]:
			_kit.box(bridge, Vector3(x, 0.45, z + side * 1.12), Vector3(0.12, 0.9, 0.12), Color("a67d4a"))


func _build_waterfront(opponent: bool) -> void:
	var direction := 1.0 if opponent else -1.0
	var x := direction * 8.2
	_kit.box(self, Vector3(x, 0.05, 9), Vector3(3.2, 0.12, 7), Color("c9aa7b"))
	for i in range(3):
		_kit.box(self, Vector3(x, 0.32 + float(i % 2) * 0.15, 7 + i * 1.4), Vector3(0.80, 0.60, 0.80), Color("bb8954"))
	_title("LIEFERSTEG", Vector3(x, 2.0, 9), Color("f9e6be"))


func _title(caption: String, at: Vector3, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.position = at
	sign.font_size = 48
	sign.pixel_size = 0.014
	sign.modulate = color
	sign.outline_modulate = Color("264b49")
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.visibility_range_end = 95
	add_child(sign)


func update_focus(at: Vector3) -> void:
	if at.distance_squared_to(_last_focus) < 25.0:
		return
	_last_focus = at
	for chunk in _chunks:
		chunk.visible = Vector2(chunk.position.x - at.x, chunk.position.z - at.z).length_squared() < 145.0 * 145.0


static func _box_mesh() -> BoxMesh:
	var shape := BoxMesh.new()
	shape.size = Vector3.ONE
	return shape


static func _sphere_mesh() -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1
	shape.radial_segments = 10
	shape.rings = 5
	return shape


func _batch(parent: Node3D, label: String, shape: Mesh, transforms: Array[Transform3D], color: Color, range_end := 170.0) -> void:
	if transforms.is_empty():
		return
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = shape
	mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		mesh.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mesh
	node.material_override = _kit.material(color)
	node.visibility_range_end = range_end
	parent.add_child(node)
