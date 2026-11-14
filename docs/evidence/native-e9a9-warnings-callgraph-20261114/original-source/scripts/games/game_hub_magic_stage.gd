extends Node3D
## Purely decorative, budgeted real 3D meshes behind the original Lumo fox.
## Does not touch saved game state, gameplay physics or Android permissions.
var reduced_motion := false
var _clock := 0.0
var _arch_orbit: Node3D
var _firefly_orbit: Node3D
var _ground_disc: MeshInstance3D


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	set_process(not enabled)


func _ready() -> void:
	_build_portal()
	set_process(not reduced_motion)


func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.35
	result.metallic = 0.22
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result


func _ring(
	parent: Node3D, name_value: String, inner: float, outer: float,
	location: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 56
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.material_override = material
	node.position = location
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _build_portal() -> void:
	# A small landing platform supports Lumo's feet without hiding his model.
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 2.35
	platform_mesh.bottom_radius = 2.5
	platform_mesh.height = 0.12
	platform_mesh.radial_segments = 48
	_ground_disc = MeshInstance3D.new()
	_ground_disc.name = "LumoLandingIsland"
	_ground_disc.mesh = platform_mesh
	_ground_disc.position = Vector3(0, -0.39, -0.35)
	_ground_disc.material_override = _material(Color("224863"))
	add_child(_ground_disc)
	_ring(
		self, "LumoLandingGlow", 2.27, 2.34, Vector3(0, -0.32, -0.35),
		_material(Color("65e9f7"), 1.15)
	)
	_arch_orbit = Node3D.new()
	_arch_orbit.name = "DreamArchOrbit"
	_arch_orbit.position = Vector3(0, 1.32, -1.7)
	add_child(_arch_orbit)
	var arch := _ring(
		_arch_orbit, "LumoDreamPortalRing", 1.55, 1.66, Vector3.ZERO,
		_material(Color("70e8ff"), 1.5)
	)
	arch.rotation.x = PI * 0.5
	var second := _ring(
		_arch_orbit, "LumoGoldPortalRing", 1.83, 1.89, Vector3(0, 0, -0.1),
		_material(Color("ffcf78"), 1.25)
	)
	second.rotation.x = PI * 0.5
	_firefly_orbit = Node3D.new()
	_firefly_orbit.name = "DreamFireflyOrbit"
	_arch_orbit.add_child(_firefly_orbit)
	var glow_sphere := SphereMesh.new()
	glow_sphere.radius = 0.05
	glow_sphere.height = 0.1
	glow_sphere.radial_segments = 8
	glow_sphere.rings = 4
	var instancing := MultiMesh.new()
	instancing.transform_format = MultiMesh.TRANSFORM_3D
	instancing.mesh = glow_sphere
	instancing.instance_count = 28
	for index in range(instancing.instance_count):
		var angle := float(index) * TAU / float(instancing.instance_count)
		var radius := 1.78 + 0.13 * sin(float(index) * 2.17)
		var position := Vector3(
			cos(angle) * radius,
			sin(angle) * radius,
			-0.05 - float(index % 4) * 0.11
		)
		instancing.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))
	var fireflies := MultiMeshInstance3D.new()
	fireflies.name = "LumoDreamFireflies"
	fireflies.multimesh = instancing
	fireflies.material_override = _material(Color("ffe9a2"), 1.65)
	fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_firefly_orbit.add_child(fireflies)
	# Two short shoreline lanterns add real parallax without extra textures.
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.17
	lamp_mesh.height = 0.34
	lamp_mesh.radial_segments = 12
	lamp_mesh.rings = 6
	var lamp_material := _material(Color("8cf7ff"), 1.2)
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.name = "ShoreLantern" + str(int(side))
		lamp.mesh = lamp_mesh
		lamp.position = Vector3(side * 2.1, 0.17, -0.64)
		lamp.material_override = lamp_material
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)


func _process(delta: float) -> void:
	if reduced_motion or not is_visible_in_tree():
		return
	_clock += minf(delta, 0.05)
	_arch_orbit.rotation.y = 0.16 * sin(_clock * 0.38)
	_firefly_orbit.rotation.z = 0.11 * sin(_clock * 0.62)
	_ground_disc.position.y = -0.39 + 0.017 * sin(_clock * 0.6)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_process(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED and not reduced_motion:
		set_process(true)
