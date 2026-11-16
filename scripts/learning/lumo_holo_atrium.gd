extends Node3D
## Mobile-budgeted futuristic learning atrium. The existing LUMO teacher,
## verified manipulatives and authoritative Flutter results remain unchanged.
## No colliders are installed, so the educational drag/touch layer owns input.
var reduced_motion := false
var _halo: Node3D
var _phase := 0.0


func _ready() -> void:
	name = "LumoLearningHoloAtrium"
	_build()
	set_process(not reduced_motion)


func _material(name_value: String, color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = 0.30 if glow > 0.0 else 0.64
	material.metallic = 0.25
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = glow
	return material


func _box(
	parent: Node3D, label: String, point: Vector3, size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = point
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _sphere(
	parent: Node3D, label: String, point: Vector3, radius: float, material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = point
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _cylinder(
	label: String, point: Vector3, radius: float, height: float, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 36
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = point
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _build() -> void:
	var midnight := _material("Lumo midnight ceramic", Color("0a1a31"))
	var slate := _material("Lumo stage graphite", Color("162d45"))
	var glass := _material("Lumo smoked glass", Color("1c4663", 0.82))
	var cyan := _material("Lumo cyan neon", Color("46d6ec"), 1.55)
	var warm := _material("Lumo warm sparkle", Color("ffcb70"), 1.25)
	var edges := _material("Lumo steel", Color("345979"))
	var purple := _material("Lumo lavender edge", Color("8994fa"), 0.8)
	# Bounded floor and teaching dais; enough contrast for colourful tokens.
	_box(self, "MidnightLearningFloor", Vector3(0, -0.82, -1),
		Vector3(32, 0.62, 27), midnight)
	_box(self, "FloatingTeachingStage", Vector3(0, -0.42, 0.25),
		Vector3(13.5, 0.24, 13.8), slate)
	_box(self, "StageEdgeNorth", Vector3(0, -0.27, -6.55),
		Vector3(13.6, 0.08, 0.09), cyan)
	_box(self, "StageEdgeSouth", Vector3(0, -0.27, 7.07),
		Vector3(13.6, 0.08, 0.09), cyan)
	for side in [-1.0, 1.0]:
		_box(self, "StageSideEdge", Vector3(side * 6.78, -0.27, 0.2),
			Vector3(0.07, 0.08, 13.7), cyan)
		# Each architectural rib has three truly separated depth planes.
		for depth in range(3):
			var z := -8.1 + float(depth) * 1.05
			var width_value := 6.95 - float(depth) * 0.55
			_box(self, "LearningRibL", Vector3(side * width_value, 2.35, z),
				Vector3(0.16, 5.45, 0.22), edges)
			_box(self, "LearningRibLight", Vector3(side * (width_value - 0.12), 2.32, z + 0.09),
				Vector3(0.042, 4.7, 0.12), purple)
		_box(self, "LearningPortalSide", Vector3(side * 5.75, 4.86, -7.8),
			Vector3(0.11, 0.38, 0.28), glass)
		# Lighting rails replace the old row of low-poly trees.
		for index in range(5):
			var z := -5.9 + float(index) * 2.4
			_box(self, "FootpathLight", Vector3(side * 6.14, -0.18, z),
				Vector3(0.10, 0.035, 0.88), warm if index % 2 == 0 else cyan)
			_sphere(self, "ScienceBeacon", Vector3(side * 6.45, 0.55, z),
				0.10, warm if index % 2 == 0 else purple)
	# Raised portal headers leave an open central view of the original fox.
	for depth in range(3):
		var z := -8.1 + float(depth) * 1.05
		_box(self, "HoloPortalBeam", Vector3(0, 5.02, z),
			Vector3(13.85 - float(depth) * 1.15, 0.14, 0.26), glass)
		_box(self, "HoloPortalLight", Vector3(0, 4.93, z + 0.15),
			Vector3(13.3 - float(depth) * 1.15, 0.055, 0.12), cyan)
	# Fine physical depth guides, not an intrusive full-screen grid.
	for index in range(10):
		var x := -5.4 + float(index) * 1.20
		_box(self, "HoloFloorTrace", Vector3(x, -0.287, 0.2),
			Vector3(0.013, 0.01, 12.2), edges)
	for index in range(9):
		var z := -5.8 + float(index) * 1.50
		_box(self, "HoloCrossTrace", Vector3(0, -0.286, z),
			Vector3(11.6, 0.01, 0.012), edges)
	# Soft central visual anchor remains behind the educational manipulatives.
	_halo = Node3D.new()
	_halo.name = "LearningEnergyHalo"
	_halo.position = Vector3(0.9, -0.29, 0.20)
	add_child(_halo)
	for index in range(3):
		var torus := TorusMesh.new()
		torus.inner_radius = 2.85 + float(index) * 0.33
		torus.outer_radius = 2.90 + float(index) * 0.33
		torus.rings = 36
		torus.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.name = "FloorEnergyRing%d" % index
		ring.mesh = torus
		ring.material_override = cyan if index % 2 == 0 else purple
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = float(index) * 0.01
		_halo.add_child(ring)
	# A small constellation of stable highlights without per-frame particle allocation.
	for index in range(16):
		var radians := TAU * float(index) / 16.0
		var radius := 5.4 + float(index % 3) * 0.24
		_sphere(self, "LearningOrb", Vector3(
			0.9 + sin(radians) * radius,
			0.10 + float(index % 4) * 0.28,
			0.2 + cos(radians) * radius
		), 0.045 + float(index % 2) * 0.015, warm if index % 4 == 0 else cyan)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU)
	if is_instance_valid(_halo):
		_halo.rotation.y = 0.025 * sin(_phase * 0.35)
