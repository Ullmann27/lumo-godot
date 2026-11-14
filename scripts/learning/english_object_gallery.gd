extends RefCounted
## Bounded, real object meshes. No downloaded models, answer rules or saves.
## Each object has its own distinguishing geometry and a numbered plinth.
const VOCABULARY = preload("res://scripts/learning/english_vocabulary.gd")


static func _material(color: String, roughness: float = 0.58, unlit: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = roughness
	result.metallic_specular = 0.24
	if unlit:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


static func _mesh(parent: Node3D, label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


static func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, label, mesh, at, material)


static func _sphere(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := _mesh(parent, label, mesh, at, material)
	node.scale = size
	return node


static func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, label, mesh, at, material)


static func make(word: String, index: int) -> Node3D:
	if not VOCABULARY.ENTRIES.has(word) or index < 0 or index > 2:
		return null
	var object := Node3D.new()
	object.name = "EnglishObject%d" % index
	object.set_meta("word", word)
	object.set_meta("choice_index", index)
	var plinth_material := _material("e4d6b5")
	_cylinder(object, "NumberedPlinth", Vector3(0, 0.09, 0), 1.0, 0.18, plinth_material)
	_cylinder(object, "PlinthEdge", Vector3(0, 0.02, 0), 1.04, 0.06, _material("355968"))
	var shape := Node3D.new()
	shape.name = "RecognizableObject"
	shape.position.y = 0.22
	object.add_child(shape)
	match word:
		"book":
			var red := _material("a94238")
			var pages := _material("f6edcf")
			_box(shape, "LowerCover", Vector3(0, 0.03, 0), Vector3(1.28, 0.06, 1.58), red)
			_box(shape, "RealPages", Vector3(0.025, 0.15, 0), Vector3(1.15, 0.20, 1.45), pages)
			_box(shape, "UpperCover", Vector3(0, 0.29, 0), Vector3(1.28, 0.07, 1.58), red)
			_box(shape, "Spine", Vector3(-0.60, 0.16, 0), Vector3(0.10, 0.31, 1.58), red)
			for line in range(3):
				_box(shape, "PageEdge%d" % line, Vector3(0.03, 0.095 + line * 0.06, 0.735), Vector3(1.10, 0.012, 0.015), _material("c6b98e"))
			_box(shape, "CoverDecoration", Vector3(0.08, 0.335, -0.12), Vector3(0.60, 0.012, 0.72), _material("dbb658"))
			shape.rotation.y = -0.16
		"pen":
			var pen := Node3D.new()
			pen.name = "PenAxis"
			pen.position = Vector3(0, 0.92, 0)
			pen.rotation.z = -0.52
			shape.add_child(pen)
			_cylinder(pen, "BlueBarrel", Vector3(0, -0.02, 0), 0.12, 1.36, _material("2879b3", 0.35))
			_cylinder(pen, "MetalTip", Vector3(0, -0.82, 0), 0.025, 0.25, _material("d2d8d8", 0.30), 0.12)
			_cylinder(pen, "InkNib", Vector3(0, -0.98, 0), 0.022, 0.10, _material("1b293a"))
			_cylinder(pen, "Cap", Vector3(0, 0.71, 0), 0.15, 0.20, _material("173b66"))
			_box(pen, "PocketClip", Vector3(0.16, 0.51, 0), Vector3(0.05, 0.48, 0.07), _material("e1bd61"))
		"ruler":
			var plank := _box(shape, "MeasuringRuler", Vector3(0, 0.13, 0), Vector3(1.75, 0.12, 0.55), _material("e7c76d"))
			plank.set_meta("unit_marks", 16)
			for mark in range(17):
				var length := 0.26 if mark % 4 == 0 else 0.14
				_box(shape, "MeasureMark%02d" % mark, Vector3(-0.78 + mark * 0.0975, 0.195, -0.21 + length * 0.5), Vector3(0.018, 0.012, length), _material("293d4d"))
			shape.rotation.y = -0.12
		"ball":
			_sphere(shape, "RoundBall", Vector3(0, 0.63, 0), Vector3.ONE * 1.25, _material("3f91be", 0.38))
			for stripe in range(3):
				var ring_mesh := TorusMesh.new()
				ring_mesh.inner_radius = 0.610
				ring_mesh.outer_radius = 0.636
				ring_mesh.rings = 32
				ring_mesh.ring_segments = 8
				var stripe_node := _mesh(shape, "BallStripe%d" % stripe, ring_mesh, Vector3(0, 0.63, 0), _material("f0bd4f"))
				stripe_node.rotation = Vector3(PI * 0.5 if stripe != 0 else 0.0, 0, PI * 0.5 if stripe == 2 else 0.0)
		"car":
			_box(shape, "VehicleBody", Vector3(0, 0.43, 0), Vector3(1.65, 0.37, 0.84), _material("bd493f", 0.38))
			_box(shape, "Cabin", Vector3(-0.05, 0.78, 0), Vector3(0.88, 0.39, 0.73), _material("c54a3b", 0.38))
			_box(shape, "FrontWindow", Vector3(0.405, 0.79, 0), Vector3(0.014, 0.26, 0.59), _material("2b4c67", 0.28))
			for side in [-1.0, 1.0]:
				_box(shape, "SideWindow%d" % int(side), Vector3(-0.04, 0.79, side * 0.375), Vector3(0.68, 0.24, 0.016), _material("3d7592", 0.28))
				for axle in [-0.55, 0.55]:
					var wheel := _cylinder(shape, "Wheel_%s_%s" % [side, axle], Vector3(axle, 0.25, side * 0.47), 0.25, 0.16, _material("23313b"))
					wheel.rotation.x = PI * 0.5
					var hub := _cylinder(shape, "WheelHub_%s_%s" % [side, axle], Vector3(axle, 0.25, side * 0.565), 0.11, 0.02, _material("c4c8c8"))
					hub.rotation.x = PI * 0.5
			for side in [-0.24, 0.24]:
				_box(shape, "Headlight%s" % side, Vector3(0.84, 0.45, side), Vector3(0.03, 0.14, 0.18), _material("f7e8a0", 0.5, true))
		"sun":
			_cylinder(shape, "SunStand", Vector3(0, 0.50, 0), 0.055, 0.9, _material("b98a39"))
			var disk := _cylinder(shape, "SolarDisk", Vector3(0, 1.15, 0), 0.47, 0.18, _material("f3be45", 0.6, true))
			disk.rotation.x = PI * 0.5
			for ray in range(12):
				var angle := ray * TAU / 12.0
				var node := _cylinder(shape, "SunRay%02d" % ray, Vector3(sin(angle) * 0.68, 1.15 + cos(angle) * 0.68, 0), 0.095, 0.30, _material("f6d674", 0.6, true), 0.0)
				node.rotation.z = -angle
		"apple":
			var red := _material("ba4136", 0.42)
			_sphere(shape, "AppleLeft", Vector3(-0.19, 0.57, 0), Vector3(0.82, 1.08, 1.05), red)
			_sphere(shape, "AppleRight", Vector3(0.19, 0.57, 0), Vector3(0.82, 1.08, 1.05), red)
			var stem := _cylinder(shape, "AppleStem", Vector3(0, 1.17, 0), 0.055, 0.30, _material("765137"))
			stem.rotation.z = -0.16
			var leaf := _sphere(shape, "AppleLeaf", Vector3(0.22, 1.25, 0), Vector3(0.50, 0.09, 0.23), _material("5d8748"))
			leaf.rotation.z = 0.30
		"bag":
			var canvas := _material("d9aa50", 0.82)
			var inner := _material("84683e", 0.90)
			_box(shape, "ToteBottom", Vector3(0, 0.08, 0), Vector3(1.30, 0.12, 0.76), inner)
			_box(shape, "ToteFront", Vector3(0, 0.64, 0.36), Vector3(1.30, 1.10, 0.08), canvas)
			_box(shape, "ToteBack", Vector3(0, 0.64, -0.36), Vector3(1.30, 1.10, 0.08), canvas)
			for side in [-1.0, 1.0]:
				_box(shape, "ToteSide%s" % side, Vector3(side * 0.61, 0.64, 0), Vector3(0.08, 1.10, 0.66), canvas)
			for front in [-1.0, 1.0]:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.24
				ring.outer_radius = 0.30
				ring.rings = 24
				ring.ring_segments = 8
				var handle := _mesh(shape, "ToteHandle%s" % front, ring, Vector3(0, 1.41, front * 0.30), _material("896442", 0.84))
				handle.rotation.x = PI * 0.5
			_box(shape, "ToteStitch", Vector3(0, 1.10, 0.407), Vector3(1.16, 0.035, 0.012), _material("eed197", 0.9))
		"rubber":
			_box(shape, "EraserBody", Vector3(0, 0.22, 0), Vector3(1.48, 0.42, 0.66), _material("efdac6", 0.92))
			_box(shape, "PaperSleeve", Vector3(-0.03, 0.22, 0), Vector3(0.72, 0.445, 0.69), _material("387bac", 0.80))
			_box(shape, "SleeveBand", Vector3(-0.03, 0.448, 0), Vector3(0.46, 0.018, 0.57), _material("e4eef1", 0.90))
			shape.rotation.y = -0.14
		"school bag":
			var fabric := _material("357ba4", 0.82)
			var trim := _material("173f63", 0.85)
			_box(shape, "BackpackBody", Vector3(0, 0.69, 0), Vector3(1.18, 1.16, 0.65), fabric)
			_sphere(shape, "BackpackRoundTop", Vector3(0, 1.23, 0), Vector3(1.18, 0.43, 0.65), fabric)
			_box(shape, "BackpackBase", Vector3(0, 0.13, 0), Vector3(1.22, 0.17, 0.69), trim)
			_box(shape, "FrontPocket", Vector3(0, 0.51, 0.40), Vector3(0.86, 0.53, 0.19), _material("e0a652", 0.84))
			_box(shape, "PocketZip", Vector3(0, 0.71, 0.503), Vector3(0.75, 0.035, 0.025), trim)
			for side in [-1.0, 1.0]:
				var strap := Node3D.new()
				strap.name = "ShoulderStrap%s" % side
				shape.add_child(strap)
				_box(strap, "UpperAnchor", Vector3(side * 0.36, 1.18, -0.42), Vector3(0.16, 0.13, 0.28), trim)
				_box(strap, "LongStrap", Vector3(side * 0.36, 0.77, -0.57), Vector3(0.16, 0.87, 0.09), trim)
				_box(strap, "LowerAnchor", Vector3(side * 0.36, 0.36, -0.42), Vector3(0.16, 0.13, 0.28), trim)
			for side in [-1.0, 1.0]:
				_box(shape, "CarryHandlePost%s" % side, Vector3(side * 0.20, 1.48, 0), Vector3(0.07, 0.18, 0.08), trim)
			_box(shape, "CarryHandleTop", Vector3(0, 1.56, 0), Vector3(0.44, 0.07, 0.08), trim)
		"desk":
			var wood := _material("c99b62", 0.70)
			var metal := _material("476477", 0.46)
			_box(shape, "WritingTop", Vector3(0, 1.28, 0), Vector3(1.74, 0.15, 1.16), wood)
			_box(shape, "DeskApron", Vector3(0, 1.09, -0.42), Vector3(1.44, 0.22, 0.08), wood)
			for side in [-1.0, 1.0]:
				for front in [-1.0, 1.0]:
					var at := Vector3(side * 0.68, 0.64, front * 0.43)
					_box(shape, "DeskLeg%s_%s" % [side, front], at, Vector3(0.12, 1.22, 0.12), metal)
					_box(shape, "DeskFoot%s_%s" % [side, front], Vector3(at.x, 0.05, at.z), Vector3(0.17, 0.10, 0.17), _material("233442", 0.88))
		"chair":
			var seat := _material("57a09c", 0.72)
			var legs := _material("bd8c55", 0.77)
			_box(shape, "ChairSeat", Vector3(0, 0.73, 0), Vector3(1.02, 0.14, 0.96), seat)
			_box(shape, "ChairBackrest", Vector3(0, 1.24, -0.43), Vector3(1.02, 0.72, 0.12), seat)
			for side in [-1.0, 1.0]:
				_box(shape, "BackPost%s" % side, Vector3(side * 0.41, 1.08, -0.43), Vector3(0.11, 0.96, 0.12), legs)
				for front in [-1.0, 1.0]:
					_box(shape, "ChairLeg%s_%s" % [side, front], Vector3(side * 0.41, 0.36, front * 0.36), Vector3(0.11, 0.70, 0.11), legs)
			shape.rotation.y = -0.18
		"pencil case":
			_sphere(shape, "SoftCaseBody", Vector3(0, 0.32, 0), Vector3(1.72, 0.56, 0.76), _material("bf5540", 0.84))
			_box(shape, "ZipperTrack", Vector3(0, 0.59, 0), Vector3(1.24, 0.028, 0.075), _material("273a4b", 0.70))
			for tooth in range(15):
				_box(shape, "ZipperTooth%02d" % tooth, Vector3(-0.56 + tooth * 0.08, 0.61, 0), Vector3(0.033, 0.025, 0.082), _material("d3d8d7", 0.35))
			_box(shape, "ZipperPull", Vector3(0.52, 0.63, 0.13), Vector3(0.12, 0.045, 0.25), _material("dfb459", 0.40))
			shape.rotation.y = -0.12
		"paper":
			_box(shape, "LooseSheet", Vector3(0, 0.065, 0), Vector3(1.46, 0.035, 1.72), _material("f4f1df", 0.96))
			for line in range(8):
				_box(shape, "WritingGuide%02d" % line, Vector3(0.04, 0.085, -0.56 + line * 0.16), Vector3(1.18, 0.006, 0.014), _material("84afbc", 0.96))
			_box(shape, "PageMargin", Vector3(-0.51, 0.086, 0), Vector3(0.014, 0.006, 1.53), _material("c98f8c", 0.96))
			var corner := _box(shape, "LiftedCorner", Vector3(0.55, 0.13, -0.65), Vector3(0.30, 0.025, 0.31), _material("e3dcc6", 0.96))
			corner.rotation.z = 0.34
			shape.rotation.y = -0.14
	var label_mesh := TextMesh.new()
	label_mesh.font = ThemeDB.fallback_font
	label_mesh.font_size = 64
	label_mesh.pixel_size = 0.009
	label_mesh.text = str(index + 1)
	label_mesh.depth = 0.025
	var label := _mesh(object, "ChoiceNumber", label_mesh, Vector3(0, 0.13, 1.06), _material("15364d", 0.8, true))
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.035
	halo_mesh.outer_radius = 1.095
	halo_mesh.rings = 40
	halo_mesh.ring_segments = 8
	var halo := _mesh(object, "HintRing", halo_mesh, Vector3(0, 0.18, 0), _material("ffe18a", 0.8, true))
	halo.hide()
	var body := StaticBody3D.new()
	body.name = "ObjectTouchBody"
	body.collision_layer = 8
	body.collision_mask = 0
	body.set_meta("english_choice", index)
	object.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(2.14, 2.20, 2.10)
	collision.shape = box
	collision.position.y = 0.95
	body.add_child(collision)
	return object


static func observe_geometry(object: Node3D, camera: Camera3D, factor: Vector2) -> Dictionary:
	# Read the actual instantiated meshes after layout; no collision or model mutation.
	var meshes := []
	for node: Node in object.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var world := []
		var pixels := []
		var box := mesh.get_aabb()
		for corner in range(8):
			var point := mesh.to_global(box.get_endpoint(corner))
			var pixel := camera.unproject_position(point) * factor
			world.append([point.x, point.y, point.z])
			pixels.append([pixel.x, pixel.y])
		meshes.append({"path": str(object.get_path_to(mesh)), "world_corners": world, "projected_corners_px": pixels})
	var collision := object.get_node("ObjectTouchBody/CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	var collision_world := []
	var collision_pixels := []
	var box := AABB(-shape.size * 0.5, shape.size)
	for corner in range(8):
		var point := collision.to_global(box.get_endpoint(corner))
		var pixel := camera.unproject_position(point) * factor
		collision_world.append([point.x, point.y, point.z])
		collision_pixels.append([pixel.x, pixel.y])
	return {"index": int(object.get_meta("choice_index")), "word": str(object.get_meta("word")),
		"hint_visible": object.get_node("HintRing").is_visible_in_tree(), "meshes": meshes,
		"collision_world_corners": collision_world, "collision_projected_corners_px": collision_pixels}
