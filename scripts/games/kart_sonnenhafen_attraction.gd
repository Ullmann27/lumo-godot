extends Node3D
## A real moving harbor wheel. Two MultiMeshes; cabins remain upright.
## The race controller supplies player position, pause and reduced-motion state.
const FACADES: Array[Color] = [
	Color("f4c7a8"),
	Color("f7ecd0"),
	Color("7fb8b0"),
	Color("e89b8c"),
	Color("f0d48a"),
	Color("d9c4e0"),
	Color("f2b7c4")
]
const ROOFS: Array[Color] = [Color("c14b32"), Color("b33b28"), Color("d4723c"), Color("a34a38")]
const ENTER_RADIUS := 56.0
const EXIT_RADIUS := 76.0
const ACTIVE_RADIUS := 230.0
const REACTION_SECONDS := 1.8
const ANGULAR_SPEED := 0.055
var phase: float = 0.12
var reaction_left: float = 0.0
var trigger_count: int = 0
var cabin_count: int = 0
var wheel_radius: float = 16.0
var wheel_basis := Basis.IDENTITY
var near_player: bool = false
var _accumulator: float = 0.0
var _interval: float = 1.0 / 30.0
var _pieces: MultiMesh
var _lamps: MultiMesh


func configure(world, centre: Vector3, basis: Basis, radius: float) -> void:
	name = "SonnenhafenHarborAttraction"
	position = centre
	wheel_basis = basis
	wheel_radius = radius
	cabin_count = 8 if world.low_detail else 12
	_interval = 1.0 / (20.0 if world.low_detail else 30.0)
	_pieces = _batch(world._shape("box"), cabin_count * 6, false, "UprightCabinsAndSpokes")
	_lamps = _batch(world._shape("ball"), cabin_count, true, "HarborWelcomeLights")
	_update_geometry()


func _batch(mesh: Mesh, count: int, glow: bool, node_name: String) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = instances
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.58
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color("ffe9a3")
		material.emission_energy_multiplier = 0.6
	node.material_override = material
	add_child(node)
	return instances


func advance(delta: float, racer_position: Vector3, active: bool, reduced_motion: bool) -> void:
	if not active or reduced_motion or delta <= 0.0 or not is_finite(delta):
		return
	var separation: float = (
		racer_position.distance_to(position) if racer_position.is_finite() else INF
	)
	if separation > EXIT_RADIUS:
		near_player = false
	if separation < ENTER_RADIUS and not near_player:
		near_player = true
		reaction_left = REACTION_SECONDS
		trigger_count += 1
	if separation > ACTIVE_RADIUS:
		return
	var step: float = minf(delta, 0.1)
	phase = fposmod(phase + step * ANGULAR_SPEED, TAU)
	reaction_left = maxf(0.0, reaction_left - step)
	_accumulator += step
	if _accumulator >= _interval:
		_accumulator = fmod(_accumulator, _interval)
		_update_geometry()


func _put(index: int, at: Vector3, size: Vector3, color: Color, basis: Basis) -> void:
	_pieces.set_instance_transform(index, Transform3D(basis.scaled_local(size), at))
	_pieces.set_instance_color(index, color)


func _update_geometry() -> void:
	for i in range(cabin_count):
		var angle: float = phase + TAU * float(i) / float(cabin_count)
		var point: Vector3 = (
			wheel_basis.x * (cos(angle) * wheel_radius) + Vector3.UP * (sin(angle) * wheel_radius)
		)
		var spoke_basis := Basis.looking_at(point.normalized(), wheel_basis.z)
		var first: int = i * 6
		_put(first, point * 0.5, Vector3(0.16, 0.16, wheel_radius), Color("f6edd8"), spoke_basis)
		_put(
			first + 1,
			point + Vector3.DOWN * 0.35,
			Vector3(0.09, 0.70, 0.09),
			Color("5d8796"),
			wheel_basis
		)
		_put(
			first + 2,
			point + Vector3.DOWN * 1.85,
			Vector3(2.35, 2.2, 1.85),
			FACADES[i % FACADES.size()],
			wheel_basis
		)
		_put(
			first + 3,
			point + Vector3.DOWN * 1.7 + wheel_basis.z * 0.94,
			Vector3(1.7, 1.25, 0.10),
			Color("5ec8d4"),
			wheel_basis
		)
		_put(
			first + 4,
			point + Vector3.DOWN * 2.95,
			Vector3(2.5, 0.20, 2.0),
			ROOFS[i % ROOFS.size()],
			wheel_basis
		)
		_put(
			first + 5,
			point + Vector3.DOWN * 0.72,
			Vector3(2.5, 0.14, 2.0),
			Color("f6edd8"),
			wheel_basis
		)
		var lamp: Vector3 = point * ((wheel_radius + 0.6) / wheel_radius)
		_lamps.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.55), lamp)
		)
		var welcome: float = 0.0
		if reaction_left > 0.0:
			var travel: float = (1.0 - reaction_left / REACTION_SECONDS) * float(cabin_count + 3)
			welcome = maxf(0.0, 1.0 - absf(float(i) - travel) / 2.5)
		_lamps.set_instance_color(i, Color("fff1a0").lerp(Color("57e2ed"), welcome))
