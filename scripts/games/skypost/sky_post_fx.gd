extends Node3D
## Effects that make speed and success readable: wind lines streaming past the
## glider, white trails from the wing tips in fast turns and dives, sparkle
## bursts (star sparks, rings, deliveries), cloud puffs (the cushion) and a
## confetti fountain at the finish. Every effect starts at a real position.

const SHADERS = preload("res://scripts/games/skypost/sky_post_shaders.gd")
const LINES := {"low": 0, "medium": 26, "high": 44}
const TRAIL_POINTS: int = 28

var profile: String = "medium"
var reduced_motion: bool = false
var wind: MultiMeshInstance3D
var wind_material: ShaderMaterial
var _wind_pos := PackedVector3Array()
var _trails: Array[ImmediateMesh] = []
var _trail_nodes: Array[MeshInstance3D] = []
var _trail_points: Array = [[], []]
var _trail_tick: float = 0.0
var _trail_strength: float = 0.0
var _pool: Array[CPUParticles3D] = []
var _star_texture: ImageTexture
var _dot_texture: ImageTexture
var _rng := RandomNumberGenerator.new()


func setup(world_profile: String, calm: bool) -> void:
	profile = world_profile
	reduced_motion = calm
	_rng.seed = 77
	_star_texture = _make_star(true)
	_dot_texture = _make_star(false)
	var count: int = 0 if calm else int(LINES.get(profile, 26))
	if count > 0:
		wind = MultiMeshInstance3D.new()
		wind.name = "WindLines"
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		multi.mesh = quad
		multi.instance_count = count
		wind.multimesh = multi
		wind_material = SHADERS.material("WIND", {"amount": 0.0})
		wind.material_override = wind_material
		wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wind.top_level = true
		add_child(wind)
		_wind_pos.resize(count)
		for index in range(count):
			multi.set_instance_custom_data(index, Color(_rng.randf_range(0.4, 1.0), 0, 0, 0))
	for side in range(2):
		var mesh := ImmediateMesh.new()
		var node := MeshInstance3D.new()
		node.name = "Trail_%d" % side
		node.mesh = mesh
		node.material_override = SHADERS.material("RIBBON")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		add_child(node)
		_trails.append(mesh)
		_trail_nodes.append(node)


func _make_star(star: bool) -> ImageTexture:
	var size: int = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(size) * 2.0 - Vector2.ONE
			var r: float = p.length()
			var value: float = exp(-r * r * 4.0)
			if star:
				var a: float = atan2(p.y, p.x)
				var edge: float = 0.38 + 0.2 * cos(a * 5.0 + PI * 0.5)
				value = maxf(value * 0.6, clampf((edge - r) * 12.0, 0.0, 1.0))
			image.set_pixel(x, y, Color(1, 1, 1, clampf(value, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Per frame: wind lines and wing-tip trails around the glider.
func follow(
	delta: float, flight, tips: Array[Vector3], camera: Camera3D, boosting: bool, cruise: float
) -> void:
	var fast: float = clampf((flight.speed - cruise + 1.0) / 8.0, 0.0, 1.0)
	if boosting:
		fast = 1.0
	if is_instance_valid(wind) and is_instance_valid(camera):
		_update_wind(delta, flight, fast, camera.global_position)
	var turning: float = clampf(absf(flight.bank) / 0.5, 0.0, 1.0)
	var want: float = maxf(fast, turning * 0.8) if not reduced_motion else 0.0
	_trail_strength = lerpf(_trail_strength, want, 1.0 - exp(-4.0 * delta))
	_trail_tick -= delta
	if _trail_tick <= 0.0:
		_trail_tick = 0.033
		for side in range(2):
			var points: Array = _trail_points[side]
			points.push_front([tips[side], _trail_strength])
			if points.size() > TRAIL_POINTS:
				points.pop_back()
	else:
		for side in range(2):
			if not _trail_points[side].is_empty():
				_trail_points[side][0] = [tips[side], _trail_strength]
	for side in range(2):
		_draw_trail(side, camera)


func _update_wind(delta: float, flight, fast: float, eye: Vector3) -> void:
	wind_material.set_shader_parameter("amount", fast)
	var multi: MultiMesh = wind.multimesh
	var heading: Vector3 = flight.forward()
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(heading).normalized()
	var length: float = 2.5 + flight.speed * 0.18
	for index in range(_wind_pos.size()):
		var p: Vector3 = _wind_pos[index]
		var local := Vector3((p - flight.pos).dot(right), (p - flight.pos).dot(up), (p - flight.pos).dot(heading))
		if p == Vector3.ZERO or local.z < -14.0 or absf(local.x) > 14.0 or absf(local.y) > 9.0:
			var around := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
			if around.length() < 0.35:
				around = around.normalized() * 0.35
			p = flight.pos + right * around.x * 12.0 + up * around.y * 7.0 + heading * _rng.randf_range(8.0, 34.0)
		p -= flight.velocity * delta * 0.35
		_wind_pos[index] = p
		var to_eye: Vector3 = (eye - p).normalized()
		var side: Vector3 = heading.cross(to_eye).normalized()
		multi.set_instance_transform(index, Transform3D(Basis(side * 0.07, heading * length, to_eye * 0.07), p))


func _draw_trail(side: int, camera: Camera3D) -> void:
	var mesh: ImmediateMesh = _trails[side]
	mesh.clear_surfaces()
	var points: Array = _trail_points[side]
	if points.size() < 3 or not is_instance_valid(camera) or _trail_strength < 0.02:
		return
	var eye: Vector3 = camera.global_position
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(points.size()):
		var p: Vector3 = points[index][0]
		var strength: float = float(points[index][1])
		var next: Vector3 = points[mini(index + 1, points.size() - 1)][0]
		var along: Vector3 = (p - next).normalized() if p.distance_squared_to(next) > 0.0001 else Vector3.FORWARD
		var across: Vector3 = along.cross((eye - p).normalized()).normalized()
		var fade: float = (1.0 - float(index) / float(points.size())) * strength * 0.55
		var width: float = 0.06 + 0.12 * float(index) / float(points.size())
		mesh.surface_set_color(Color(1, 1, 1, fade))
		mesh.surface_set_uv(Vector2(float(index), 0))
		mesh.surface_add_vertex(p + across * width)
		mesh.surface_set_color(Color(1, 1, 1, fade))
		mesh.surface_set_uv(Vector2(float(index), 1))
		mesh.surface_add_vertex(p - across * width)
	mesh.surface_end()


func clear_trails() -> void:
	_trail_points = [[], []]
	for mesh in _trails:
		mesh.clear_surfaces()


## kind: "sparkle" (spark collected), "ring", "delivery", "puff", "confetti", "miss".
func play(kind: String, at: Vector3, colour: Color = Color("ffe27a")) -> void:
	if profile == "low" and kind in ["sparkle"]:
		return
	var burst: CPUParticles3D = _take()
	burst.global_position = at
	burst.color = colour
	burst.amount = 18
	burst.lifetime = 0.8
	burst.spread = 180.0
	burst.direction = Vector3.UP
	burst.gravity = Vector3(0, -2.0, 0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.scale_amount_min = 0.35
	burst.scale_amount_max = 0.7
	var material := burst.material_override as StandardMaterial3D
	material.albedo_texture = _star_texture
	match kind:
		"ring":
			burst.amount = 28
			burst.initial_velocity_min = 4.0
			burst.initial_velocity_max = 8.0
			burst.scale_amount_max = 0.9
		"delivery", "confetti":
			burst.amount = 40 if kind == "confetti" else 30
			burst.lifetime = 1.4
			burst.gravity = Vector3(0, -6.0, 0)
			burst.initial_velocity_min = 5.0
			burst.initial_velocity_max = 10.0
			burst.spread = 50.0
			burst.color_ramp = _rainbow()
		"puff", "miss":
			material.albedo_texture = _dot_texture
			burst.amount = 14
			burst.lifetime = 1.1
			burst.gravity = Vector3(0, 0.5, 0)
			burst.initial_velocity_min = 1.0
			burst.initial_velocity_max = 3.0
			burst.scale_amount_min = 1.6
			burst.scale_amount_max = 3.0
	if reduced_motion:
		burst.amount = maxi(4, burst.amount / 3)
	burst.restart()
	burst.emitting = true


func _rainbow() -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(
		[Color("ffd75e"), Color("ff7eb6"), Color("6ee7ff"), Color("9dff8a"), Color("ffd75e")]
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	return gradient


func _take() -> CPUParticles3D:
	for burst in _pool:
		if not burst.emitting:
			burst.color_ramp = null
			return burst
	var made := CPUParticles3D.new()
	made.one_shot = true
	made.explosiveness = 0.92
	made.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	made.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	made.material_override = material
	made.top_level = true
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(made)
	_pool.append(made)
	return made
