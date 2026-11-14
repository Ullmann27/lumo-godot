extends Node3D
## A real, bounded garden atelier around the manipulatives. Shared meshes and
## MultiMesh batches keep the architecture independent of the lesson state.
const BEVEL = preload("res://scripts/games/visual/kart_harbor_cinema.gd")
const STUDIO_PATH := "res://assets/learning/studio/learning_studio.glb"
const LEAF_SHADER = preload("res://assets/learning/studio/studio_leaf_motion.gdshader")
var _box_mesh: ArrayMesh
var _batches: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	name = "LearningGardenAtelier"
	_box_mesh = BEVEL._bevel_box(0.035)
	_floor()
	_studio_architecture()
	_garden()
	_flush()
	_original_lantern(Vector3(4.85, 1.75, -4.45), 0.62)
	_original_lantern(Vector3(-4.85, 1.75, -4.45), 0.62)


func _studio_architecture() -> void:
	var packed := load(STUDIO_PATH) as PackedScene
	if packed == null:
		push_error("Learning studio geometry is unavailable: " + STUDIO_PATH)
		return
	var studio := packed.instantiate() as Node3D
	studio.name = "BlenderLearningStudio"
	add_child(studio)
	var reduced := bool(get_parent().get("reduced_motion"))
	for node: MeshInstance3D in studio.find_children("*", "MeshInstance3D", true, false):
		for index in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(index) as StandardMaterial3D
			if source == null or not source.resource_name.begins_with("StudioLeaf"):
				continue
			var moving_leaf := ShaderMaterial.new()
			moving_leaf.shader = LEAF_SHADER
			moving_leaf.set_shader_parameter("base_color", source.albedo_color)
			moving_leaf.set_shader_parameter("motion_weight", 0.0 if reduced else 1.0)
			node.set_surface_override_material(index, moving_leaf)


func _material(key: String, color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.22
	_materials[key] = material
	return material


func _piece(
	mesh: Mesh,
	at: Vector3,
	size_value: Vector3,
	key: String,
	color: Color,
	rotation_value: Vector3 = Vector3.ZERO
) -> void:
	var group := key + "_" + str(mesh.get_instance_id())
	if not _batches.has(group):
		_batches[group] = {"mesh": mesh, "material": _material(key, color), "transforms": []}
	var basis_value := Basis.from_euler(rotation_value) * Basis.from_scale(size_value)
	_batches[group].transforms.append(Transform3D(basis_value, at))


func _box(
	at: Vector3,
	size_value: Vector3,
	key: String,
	color: Color,
	rotation_value: Vector3 = Vector3.ZERO
) -> void:
	_piece(_box_mesh, at, size_value, key, color, rotation_value)


func _floor() -> void:
	# The real garden continues beyond the veranda at Fold/ultrawide ratios.
	_box(Vector3(0, -0.9, -1), Vector3(48, 0.4, 42), "garden_ground", Color("53644a"))
	_box(Vector3(0, -0.48, 0), Vector3(13.2, 0.6, 13.2), "sandstone", Color("8b8772"))
	_box(Vector3(0, -0.18, 0), Vector3(12.9, 0.12, 12.9), "floor_edge", Color("654a36"))
	for row in range(20):
		var color := Color("8c7456") if row % 3 != 0 else Color("967e5e")
		_box(
			Vector3(0, -0.1, -6.1 + float(row) * 0.64),
			Vector3(12.65, 0.12, 0.625),
			"oak_%d" % (row % 3),
			color
		)
	# A quiet inset teaching carpet anchors the foreground objects.
	_box(Vector3(0.3, -0.025, 0.7), Vector3(6.25, 0.035, 8.5), "rug_border", Color("1c414d"))
	_box(Vector3(0.3, -0.003, 0.7), Vector3(6.08, 0.018, 8.32), "rug", Color("385b60"))
	for side in [-1.0, 1.0]:
		for i in range(7):
			_box(
				Vector3(0.3 + side * 2.92, 0.011, -2.9 + i * 1.1),
				Vector3(0.05, 0.015, 0.32),
				"rug_stitch",
				Color("9da785")
			)


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
	for side in [-1.0, 1.0]:
		# Low garden terraces and shrubs frame the real architecture without
		# covering either the teacher or an interactive learning object.
		for index in range(4):
			var x: float = side * (8.0 + float(index % 2) * 2.5)
			var z := -4.0 + float(index) * 3.4
			_piece(
				crown,
				Vector3(x, -0.35, z),
				Vector3(5.0, 1.0, 4.0),
				"garden_mounds",
				Color("667b51")
			)
			for leaf in range(3):
				_piece(
					crown,
					Vector3(x + sin(leaf * 2.4) * 0.5, 0.25 + leaf * 0.2, z),
					Vector3(1.2, 1.1, 1.05),
					"garden_shrubs",
					Color("4b694b")
				)
	for index in range(9):
		var x := -11.0 + float(index) * 2.75
		var z := -9.0 - float(index % 3) * 1.3
		var height_value := 4.0 + float(index % 3) * 0.6
		_piece(
			trunk,
			Vector3(x, height_value * 0.5 - 0.3, z),
			Vector3(0.55, height_value, 0.55),
			"trunks",
			Color("6b5139")
		)
		for level in range(3):
			var at := Vector3(x + sin(index + level) * 0.5, height_value + level * 0.65 - 0.5, z)
			_piece(
				crown,
				at,
				Vector3(3.4 - level * 0.65, 2.3, 2.8 - level * 0.4),
				"forest_%d" % (index % 3),
				[Color("3f6450"), Color("5a7657"), Color("71805a")][index % 3]
			)
	for side in [-1.0, 1.0]:
		for z in [-2.3, 3.4]:
			var x: float = side * 5.6
			_box(Vector3(x, 0.2, z), Vector3(1.0, 0.5, 1.2), "planter", Color("9f6248"))
			_box(Vector3(x, 0.48, z), Vector3(0.9, 0.08, 1.1), "soil", Color("493e2e"))
			for i in range(4):
				_piece(
					crown,
					Vector3(x + sin(i * 2.2) * 0.25, 0.73 + i * 0.11, z + cos(i * 2.2) * 0.28),
					Vector3(0.58, 0.65, 0.55),
					"potted_green",
					Color("527348")
				)


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
	model.name = "OriginalLumoLanternLeft" if at.x < 0 else "OriginalLumoLanternRight"
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
		model.position = (
			at - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * fitted
		)
	else:
		model.queue_free()
