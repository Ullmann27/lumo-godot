extends Node3D
## Purely decorative, budgeted real 3D meshes behind the original Lumo fox.
## Does not touch saved game state, gameplay physics or Android permissions.
var reduced_motion := false
var _clock := 0.0
var _arch_orbit: Node3D
var _firefly_orbit: Node3D
var _ground_disc: MeshInstance3D
var _flutter: MultiMeshInstance3D
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")


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
	_ground_disc.material_override = ADVENTURE.material("stone_block")
	add_child(_ground_disc)
	_build_garden()
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


## Kleine Gartenwelt um Lumos Plattform: Felsen, Farne, Gräser, Blumen und drei
## Spieltore (Stein = Schatzsuche, Holz = Bauwelt/Dorf, Ring = Rhythmus/Kart),
## dazu Schmetterlinge. Blender-Modelle aus AdventureKit, je Art ein MultiMesh.
func _build_garden() -> void:
	var tier := LumoQuality.tier()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var rocks: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var count := 10 if tier == "low" else 22
	for i in range(count):
		var a := float(i) / float(count) * TAU + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(2.3, 2.75)
		var at := Vector3(cos(a) * r, -0.42, -0.35 + sin(a) * r)
		if i % 3 == 0:
			rocks.append(ADVENTURE.xf(at, rng.randf() * TAU, rng.randf_range(0.14, 0.28)))
		elif i % 3 == 1:
			ferns.append(ADVENTURE.xf(at, rng.randf() * TAU, rng.randf_range(0.35, 0.55)))
		else:
			(flowers if i % 2 == 0 else grass).append(ADVENTURE.xf(at, rng.randf() * TAU, rng.randf_range(0.45, 0.7)))
	ADVENTURE.scatter(self, "HubRocks", "ruins", "rock_a", rocks, false)
	ADVENTURE.scatter(self, "HubFerns", "flora", "fern", ferns, false)
	ADVENTURE.scatter(self, "HubGrass", "flora", "grass_tuft", grass, false)
	ADVENTURE.scatter(self, "HubFlowers", "flora", "grass_flowers", flowers, false)
	var gates := [
		["HubGateTreasure", "gate_stone", Vector3(-3.1, -0.42, -1.9), 0.5, Color("ffd36a")],
		["HubGateBuild", "gate_wood", Vector3(3.1, -0.42, -1.9), -0.5, Color("8ff0a8")],
		["HubGateRhythm", "gate_ring", Vector3(0.0, -0.42, -3.6), 0.0, Color("c39cff")],
	]
	for g in gates:
		var gate := ADVENTURE.place(self, str(g[0]), "hub", str(g[1]), ADVENTURE.xf(g[2], float(g[3]), 0.42), false)
		if gate == null:
			continue
		var veil := MeshInstance3D.new()
		veil.name = "Veil"
		var quad := QuadMesh.new()
		quad.size = Vector2(3.4, 3.6)
		veil.mesh = quad
		veil.position = Vector3(0, 2.3, 0)
		var vm := StandardMaterial3D.new()
		vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		vm.albedo_texture = ADVENTURE.texture("soft_dot.png")
		vm.albedo_color = Color(g[4], 0.75)
		vm.cull_mode = BaseMaterial3D.CULL_DISABLED
		veil.material_override = vm
		gate.add_child(veil)
	if tier != "low":
		var spots: Array[Transform3D] = []
		for i in range(5):
			spots.append(ADVENTURE.xf(Vector3(rng.randf_range(-2.4, 2.4), rng.randf_range(0.6, 2.4), rng.randf_range(-1.6, 0.4)), rng.randf() * TAU, 0.55))
		_flutter = ADVENTURE.scatter(self, "HubButterflies", "fauna", "butterfly", spots, false, 0.0, true)


func _process(delta: float) -> void:
	if reduced_motion or not is_visible_in_tree():
		return
	_clock += minf(delta, 0.05)
	if _flutter != null:
		for i in range(_flutter.multimesh.instance_count):
			var ph := float(i) * 1.9
			var p := Vector3(sin(_clock * 0.5 + ph) * 2.2, 1.4 + sin(_clock * 0.9 + ph) * 0.6, -0.6 + cos(_clock * 0.4 + ph) * 1.1)
			var dir := Vector3(cos(_clock * 0.5 + ph), 0.0, -sin(_clock * 0.4 + ph) * 0.5).normalized()
			_flutter.multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(dir, Vector3.UP).scaled(Vector3.ONE * 0.5), p))
	_arch_orbit.rotation.y = 0.16 * sin(_clock * 0.38)
	_firefly_orbit.rotation.z = 0.11 * sin(_clock * 0.62)
	_ground_disc.position.y = -0.39 + 0.017 * sin(_clock * 0.6)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_process(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED and not reduced_motion:
		set_process(true)
