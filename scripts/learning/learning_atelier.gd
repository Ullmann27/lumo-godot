extends Node3D
## A real, bounded garden atelier around the manipulatives. Shared meshes and
## MultiMesh batches keep the architecture independent of the lesson state.
const BEVEL = preload("res://scripts/games/visual/kart_harbor_cinema.gd")
var _box_mesh: ArrayMesh
var _batches: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	name = "LearningGardenAtelier"
	_box_mesh = BEVEL._bevel_box(0.035)
	_floor()
	_backdrop()
	_furniture()
	_garden()
	_flush()
	_original_lantern(Vector3(4.85, 1.75, -4.45), 0.62)
	_original_lantern(Vector3(-4.85, 1.75, -4.45), 0.62)


func _material(key: String, color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_materials[key] = material
	return material


func _piece(mesh: Mesh, at: Vector3, size_value: Vector3, key: String, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var group := key + "_" + str(mesh.get_instance_id())
	if not _batches.has(group):
		_batches[group] = {"mesh": mesh, "material": _material(key, color), "transforms": []}
	var basis_value := Basis.from_euler(rotation_value).scaled(size_value)
	_batches[group].transforms.append(Transform3D(basis_value, at))


func _box(at: Vector3, size_value: Vector3, key: String, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> void:
	_piece(_box_mesh, at, size_value, key, color, rotation_value)


func _floor() -> void:
	_box(Vector3(0, -0.48, 0), Vector3(13.2, 0.6, 13.2), "sandstone", Color("8b8772"))
	_box(Vector3(0, -0.18, 0), Vector3(12.9, 0.12, 12.9), "floor_edge", Color("654a36"))
	for row in range(20):
		var color := Color("a88e68") if row % 3 != 0 else Color("b59c76")
		_box(Vector3(0, -0.1, -6.1 + float(row) * 0.64), Vector3(12.65, 0.12, 0.625),
			"oak_%d" % (row % 3), color)
	# A quiet inset teaching carpet anchors the foreground objects.
	_box(Vector3(0.3, -0.025, 0.7), Vector3(6.25, 0.035, 8.5), "rug_border", Color("1c414d"))
	_box(Vector3(0.3, -0.003, 0.7), Vector3(6.08, 0.018, 8.32), "rug", Color("385b60"))
	for side in [-1.0, 1.0]:
		for i in range(7):
			_box(Vector3(0.3 + side * 2.92, 0.011, -2.9 + i * 1.1), Vector3(0.05, 0.015, 0.32),
				"rug_stitch", Color("9da785"))


func _backdrop() -> void:
	var stone := Color("cbc3a8")
	var timber := Color("725035")
	# Open arches frame actual trees behind the teaching area.
	for x in [-4.4, 0.0, 4.4]:
		for side in [-1.0, 1.0]:
			_box(Vector3(x + side * 1.48, 1.34, -5.65), Vector3(0.3, 2.8, 0.42), "warm_columns", stone)
			_box(Vector3(x + side * 1.48, 0.16, -5.65), Vector3(0.5, 0.3, 0.65), "column_feet", stone)
		for segment in range(14):
			var angle := (float(segment) + 0.5) / 14.0 * PI
			_box(Vector3(x + cos(angle) * 1.48, 2.7 + sin(angle) * 1.48, -5.65),
				Vector3(0.37, 0.34, 0.44), "arch_stones", stone, Vector3(0, 0, angle + PI * 0.5))
		_box(Vector3(x, 0.55, -5.68), Vector3(2.65, 0.18, 0.42), "window_rail", timber)
	_box(Vector3(0, 4.65, -5.65), Vector3(13.0, 0.32, 0.48), "roof_timber", timber)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 6.15, 1.85, -2.1), Vector3(0.3, 3.85, 0.3), "roof_posts", timber)
		_box(Vector3(side * 6.15, 3.85, -3.9), Vector3(0.3, 0.23, 3.8), "roof_posts", timber)
		_box(Vector3(side * 6.15, 0.7, 0.25), Vector3(0.25, 0.18, 5.0), "terrace_rail", timber)
		for z in [-2.0, 0.0, 2.5]:
			_box(Vector3(side * 6.15, 0.32, z), Vector3(0.18, 0.7, 0.18), "terrace_rail", timber)


func _furniture() -> void:
	var wood := Color("644931")
	var books: Array[Color] = [Color("356975"), Color("b06942"), Color("4b7160"), Color("786283")]
	for side in [-1.0, 1.0]:
		var x: float = side * 4.85
		for shelf in range(3):
			_box(Vector3(x, 0.35 + shelf * 0.65, -4.6), Vector3(1.8, 0.12, 0.72), "shelves", wood)
		for edge in [-0.84, 0.84]:
			_box(Vector3(x + edge, 0.98, -4.6), Vector3(0.12, 1.85, 0.7), "shelves", wood)
		for index in range(11):
			var shelf := index / 6
			var local_x := float(index % 6) * 0.25 - 0.65
			var height_value := 0.37 + float(index % 3) * 0.06
			_box(Vector3(x + local_x, 0.43 + shelf * 0.65 + height_value * 0.5, -4.5),
				Vector3(0.19, height_value, 0.41), "book_%d" % (index % 4), books[index % 4])
			_box(Vector3(x + local_x, 0.48 + shelf * 0.65, -4.28), Vector3(0.13, 0.035, 0.02),
				"book_detail", Color("ceb785"))
	# A low side bench and an open book make the atelier inhabited without
	# placing clutter between the child and the manipulatives.
	_box(Vector3(4.8, 0.55, 2.0), Vector3(1.5, 0.16, 2.0), "bench", wood)
	for z in [1.3, 2.7]:
		_box(Vector3(4.8, 0.24, z), Vector3(1.3, 0.55, 0.14), "bench", wood)
	for side in [-1.0, 1.0]:
		_box(Vector3(4.8 + side * 0.22, 0.68, 1.8), Vector3(0.44, 0.06, 0.65),
			"book_pages", Color("dacdad"), Vector3(0, 0.18, -side * 0.10))


func _garden() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.36
	trunk.bottom_radius = 0.5
	trunk.height = 1.0
	trunk.radial_segments = 10
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 12
	crown.rings = 6
	for index in range(9):
		var x := -11.0 + float(index) * 2.75
		var z := -9.0 - float(index % 3) * 1.3
		var height_value := 4.0 + float(index % 3) * 0.6
		_piece(trunk, Vector3(x, height_value * 0.5 - 0.3, z), Vector3(0.55, height_value, 0.55), "trunks", Color("6b5139"))
		for level in range(3):
			var at := Vector3(x + sin(index + level) * 0.5, height_value + level * 0.65 - 0.5, z)
			_piece(crown, at, Vector3(3.4 - level * 0.65, 2.3, 2.8 - level * 0.4),
				"forest_%d" % (index % 3), [Color("3f6450"), Color("5a7657"), Color("71805a")][index % 3])
	for side in [-1.0, 1.0]:
		for z in [-2.3, 3.4]:
			var x: float = side * 5.6
			_box(Vector3(x, 0.2, z), Vector3(1.0, 0.5, 1.2), "planter", Color("9f6248"))
			_box(Vector3(x, 0.48, z), Vector3(0.9, 0.08, 1.1), "soil", Color("493e2e"))
			for i in range(4):
				_piece(crown, Vector3(x + sin(i * 2.2) * 0.25, 0.73 + i * 0.11, z + cos(i * 2.2) * 0.28),
					Vector3(0.58, 0.65, 0.55), "potted_green", Color("527348"))


func _flush() -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.transforms.size()
		for index in range(batch.transforms.size()):
			multimesh.set_instance_transform(index, batch.transforms[index])
		var node := MultiMeshInstance3D.new()
		node.name = str(key).get_slice("_", 0)
		node.multimesh = multimesh
		node.material_override = batch.material
		add_child(node)
	_batches.clear()


func _original_lantern(at: Vector3, height_value: float) -> void:
	var scene := load("res://assets/creative/models/lumo_lantern.glb") as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.name = "OriginalLumoLantern"
	add_child(model)
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if found and bounds.size.y > 0.001:
		var fitted := height_value / bounds.size.y
		model.scale = Vector3.ONE * fitted
		model.position = at - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * fitted
