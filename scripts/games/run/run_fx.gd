extends Node3D
## Small pooled effects: dust puffs for landings and dashes, a sparkle for every
## star, a splash for the water channels. A fixed pool of one-shot emitters is
## reused in turn, sized by the quality profile; calm mode shows none.

const POOL: Dictionary = {"dust": 4, "sparkle": 6, "splash": 2, "burst": 3, "leaves": 3}

var reduced_motion: bool = false
var low: bool = false
var _pools: Dictionary = {}
var _next: Dictionary = {}
var _dot: Texture2D
## Speed lines rushing past the camera at high pace (not in calm or light mode).
var _streaks: CPUParticles3D


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
	if not low:
		_streaks = _make_streaks()
		add_child(_streaks)


## Thin bright lines in front of the lens that fly past: more the faster Lumo is.
func _make_streaks() -> CPUParticles3D:
	var lines := CPUParticles3D.new()
	lines.name = "SpeedLines"
	lines.amount = 28
	lines.lifetime = 0.32
	lines.local_coords = true
	lines.emitting = false
	# A ring around the view axis: the lines stream along the edges of the
	# picture and leave the middle (Lumo and the path) free.
	lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	lines.emission_ring_axis = Vector3(0, 0, 1)
	lines.emission_ring_height = 3.0
	lines.emission_ring_radius = 5.2
	lines.emission_ring_inner_radius = 3.6
	lines.direction = Vector3(0, 0, 1)
	lines.spread = 2.0
	lines.gravity = Vector3.ZERO
	lines.initial_velocity_min = 34.0
	lines.initial_velocity_max = 44.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, 1.1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.98, 0.9, 0.38)
	material.disable_receive_shadows = true
	mesh.material = material
	lines.mesh = mesh
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lines


## Called every frame with the camera and how far above his pace Lumo runs (0..1).
func set_speed(pace: float, eye: Transform3D) -> void:
	if _streaks == null:
		return
	_streaks.global_transform = eye.translated_local(Vector3(0.0, 0.0, -7.5))
	_streaks.emitting = pace > 0.35


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
	# The quad is built once its size is known (see the end of this function): it
	# carries vertex colours, because a plain QuadMesh drew single particles black.
	var quad_size := Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
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
			quad_size = Vector2(0.7, 0.7)
			emitter.amount = 10 / scale
			emitter.lifetime = 0.5
			emitter.direction = Vector3.UP
			emitter.spread = 80.0
			emitter.gravity = Vector3(0, 1.2, 0)
			emitter.initial_velocity_min = 1.0
			emitter.initial_velocity_max = 2.6
			emitter.color = Color(0.93, 0.89, 0.8, 0.75)
		"sparkle":
			quad_size = Vector2(0.34, 0.34)
			emitter.amount = 8 / scale
			emitter.lifetime = 0.42
			emitter.direction = Vector3.UP
			emitter.spread = 180.0
			emitter.gravity = Vector3(0, -3.0, 0)
			emitter.initial_velocity_min = 2.0
			emitter.initial_velocity_max = 4.2
			emitter.color = Color("fff0a0")
		"splash":
			quad_size = Vector2(0.3, 0.3)
			emitter.amount = 22 / scale
			emitter.lifetime = 0.7
			emitter.direction = Vector3.UP
			emitter.spread = 38.0
			emitter.gravity = Vector3(0, -14.0, 0)
			emitter.initial_velocity_min = 4.0
			emitter.initial_velocity_max = 7.5
			emitter.color = Color("bff3ff")
		"leaves":
			# A whirl of small leaves kicked up by a jump or a dash.
			quad_size = Vector2(0.22, 0.16)
			emitter.amount = 12 / scale
			emitter.lifetime = 0.9
			emitter.direction = Vector3.UP
			emitter.spread = 70.0
			emitter.gravity = Vector3(0, -2.5, 0)
			emitter.initial_velocity_min = 1.5
			emitter.initial_velocity_max = 3.5
			emitter.angular_velocity_min = -360.0
			emitter.angular_velocity_max = 360.0
			emitter.color = Color("7fc84a")
		_:
			quad_size = Vector2(0.26, 0.26)
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
	var quad: ArrayMesh = preload("res://scripts/systems/particle_quad.gd").make(quad_size)
	quad.surface_set_material(0, material)
	emitter.mesh = quad
	return emitter
