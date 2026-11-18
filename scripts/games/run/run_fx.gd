extends Node3D
## Small pooled effects: dust puffs for landings and dashes, a sparkle for every
## star, a splash for the water channels. A fixed pool of one-shot emitters is
## reused in turn, sized by the quality profile; calm mode shows none.

const POOL: Dictionary = {"dust": 4, "sparkle": 6, "splash": 2, "burst": 2}

var reduced_motion: bool = false
var low: bool = false
var _pools: Dictionary = {}
var _next: Dictionary = {}
var _dot: Texture2D


func setup(lightweight: bool, calm: bool) -> void:
	low = lightweight
	reduced_motion = calm
	if calm:
		return
	for kind in POOL:
		var count: int = maxi(1, int(POOL[kind]) / 2) if low else int(POOL[kind])
		var emitters: Array[CPUParticles3D] = []
		for index in range(count):
			var emitter: CPUParticles3D = _emitter(str(kind))
			emitter.name = "%s%d" % [str(kind).capitalize(), index]
			add_child(emitter)
			emitters.append(emitter)
		_pools[kind] = emitters
		_next[kind] = 0


func play(kind: String, at: Vector3, colour: Color = Color.WHITE) -> void:
	if not _pools.has(kind):
		return
	var emitters: Array = _pools[kind]
	var emitter: CPUParticles3D = emitters[int(_next[kind]) % emitters.size()]
	_next[kind] = int(_next[kind]) + 1
	emitter.global_position = at
	if colour != Color.WHITE:
		emitter.color = colour
	emitter.restart()
	emitter.emitting = true


## One shared soft round sprite, made in code (no image file).
func _soft_dot() -> Texture2D:
	if _dot != null:
		return _dot
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.55, Color(1, 1, 1, 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_dot = texture
	return _dot


func _emitter(kind: String) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 0.92
	emitter.local_coords = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	quad.material = material
	emitter.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	emitter.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.25))
	emitter.scale_amount_curve = shrink
	var scale: int = 2 if low else 1
	match kind:
		"dust":
			quad.size = Vector2(0.7, 0.7)
			emitter.amount = 10 / scale
			emitter.lifetime = 0.5
			emitter.direction = Vector3.UP
			emitter.spread = 80.0
			emitter.gravity = Vector3(0, 1.2, 0)
			emitter.initial_velocity_min = 1.0
			emitter.initial_velocity_max = 2.6
			emitter.color = Color(0.93, 0.89, 0.8, 0.75)
		"sparkle":
			quad.size = Vector2(0.34, 0.34)
			emitter.amount = 8 / scale
			emitter.lifetime = 0.42
			emitter.direction = Vector3.UP
			emitter.spread = 180.0
			emitter.gravity = Vector3(0, -3.0, 0)
			emitter.initial_velocity_min = 2.0
			emitter.initial_velocity_max = 4.2
			emitter.color = Color("fff0a0")
		"splash":
			quad.size = Vector2(0.3, 0.3)
			emitter.amount = 22 / scale
			emitter.lifetime = 0.7
			emitter.direction = Vector3.UP
			emitter.spread = 38.0
			emitter.gravity = Vector3(0, -14.0, 0)
			emitter.initial_velocity_min = 4.0
			emitter.initial_velocity_max = 7.5
			emitter.color = Color("bff3ff")
		_:
			quad.size = Vector2(0.26, 0.26)
			emitter.amount = 40 / scale
			emitter.lifetime = 1.3
			emitter.direction = Vector3.UP
			emitter.spread = 75.0
			emitter.gravity = Vector3(0, -3.0, 0)
			emitter.initial_velocity_min = 3.0
			emitter.initial_velocity_max = 6.5
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			emitter.emission_sphere_radius = 0.6
			emitter.color = Color("ffe27a")
	return emitter
