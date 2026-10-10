extends RefCounted
## Original Lumo action arches: quality-gated, cosmetic and collider-free.
## Arch segments share one MultiMesh draw call and one emission material.
const PULSE = preload("res://scripts/games/visual/kart_neon_gate_pulse.gd")
const SEGMENTS: int = 22
const POSITIONS = [0.18, 0.48, 0.77]
const RADIUS: float = 6.45
const HEIGHT: float = 0.55


static func decorate(world) -> int:
	if world.low_detail or world.length <= 0.0:
		return 0
	var valid: Array[float] = []
	for fraction in POSITIONS:
		var d: float = world.length * float(fraction)
		if world.in_gap(d) or world.ramp_height(d) > 0.2:
			continue
		valid.append(d)
	if valid.is_empty():
		return 0
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.085
	cylinder.bottom_radius = 0.085
	cylinder.height = 1.0
	cylinder.radial_segments = 7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("46dfff")
	mat.emission_enabled = true
	mat.emission = Color("27cbff")
	mat.emission_energy_multiplier = 2.4
	cylinder.material = mat
	var batches := MultiMesh.new()
	batches.transform_format = MultiMesh.TRANSFORM_3D
	batches.mesh = cylinder
	batches.instance_count = valid.size() * SEGMENTS
	var index: int = 0
	for dist in valid:
		var frame: Basis = world.frame(dist)
		var center: Vector3 = world.position_at(dist)
		for i in range(SEGMENTS):
			var a: float = PI - PI * float(i) / float(SEGMENTS)
			var b: float = PI - PI * float(i + 1) / float(SEGMENTS)
			var p0 := Vector3(cos(a) * RADIUS, sin(a) * RADIUS + HEIGHT, 0.0)
			var p1 := Vector3(cos(b) * RADIUS, sin(b) * RADIUS + HEIGHT, 0.0)
			var segment: Vector3 = p1 - p0
			var rot := Basis(Quaternion(Vector3.UP, segment.normalized()))
			var transform := Transform3D(
				frame * rot.scaled(Vector3(1, segment.length(), 1)),
				center + frame * (p0 + p1) * 0.5
			)
			batches.set_instance_transform(index, transform)
			index += 1
		# At most three quiet animated beacons. Never changes kart transforms.
		var path := Path3D.new()
		path.name = "LumoNeonArcPath"
		path.position = center
		path.transform.basis = frame
		var curve := Curve3D.new()
		for j in range(SEGMENTS + 1):
			var t: float = PI - PI * float(j) / float(SEGMENTS)
			curve.add_point(Vector3(cos(t) * RADIUS, sin(t) * RADIUS + HEIGHT, -0.15))
		path.curve = curve
		world.add_child(path)
		var pulse = PULSE.new()
		pulse.name = "MovingLumoBeacon"
		path.add_child(pulse)
		var orb := MeshInstance3D.new()
		orb.name = "LightPoint"
		var sphere := SphereMesh.new()
		sphere.radius = 0.19
		sphere.height = 0.38
		sphere.radial_segments = 8
		sphere.rings = 4
		orb.mesh = sphere
		orb.material_override = mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pulse.add_child(orb)
	var node := MultiMeshInstance3D.new()
	node.name = "LumoNextGenNeonGates"
	node.multimesh = batches
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
	world.set_meta("aaa_arch_count", valid.size())
	return valid.size()
