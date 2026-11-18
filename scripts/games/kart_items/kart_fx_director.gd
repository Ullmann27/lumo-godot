extends Node3D
## One place for "drive-through" juice: particle bursts, screen flash, camera push
## and sound hooks. Pooled CPU particles keep it cheap on mid-range Android phones;
## reduced motion keeps colour feedback but drops shake, FOV punch and big flashes.

signal sound_hook(event_id: String, fallback_effect: String)

const POOL_SIZE: int = 6
## Event id -> [colour, particle amount, flash strength, camera kick, fallback sound].
const EVENTS: Dictionary = {
	"item_box": [Color("ffe680"), 26, 0.22, 0.35, "item"],
	"boost_ring": [Color("66f7e8"), 34, 0.32, 1.0, "boost"],
	"boost_pad": [Color("4fe6ff"), 18, 0.12, 0.55, "boost"],
	"drift_blue": [Color("4fb8ff"), 18, 0.10, 0.45, "drift"],
	"drift_orange": [Color("ff9a3c"), 24, 0.14, 0.65, "drift"],
	"drift_purple": [Color("c77dff"), 32, 0.20, 0.85, "drift"],
	"slipstream": [Color("d6f6ff"), 16, 0.10, 0.55, "boost"],
	"trick": [Color("ffd166"), 22, 0.12, 0.25, "drift"],
	"trick_landing": [Color("ffd166"), 30, 0.20, 0.8, "boost"],
	"rocket_launch": [Color("ff6b8b"), 14, 0.0, 0.2, "item"],
	"hit_spin": [Color("ffffff"), 30, 0.30, 0.9, "collision"],
	"blocked": [Color("66e8ff"), 26, 0.22, 0.3, "item"],
	"combo": [Color("ff7ad9"), 28, 0.18, 0.6, "boost"],
	"aurora": [Color("8affd8"), 36, 0.30, 0.8, "boost"],
	"magnet": [Color("ffe066"), 20, 0.12, 0.2, "item"],
	# Sternraketen: star/spark burst on a hit, cyan sparks on a shield bounce.
	"rocket_fire": [Color("ffb347"), 18, 0.10, 0.55, "rocket_launch"],
	"rocket_hit": [Color("ffd166"), 44, 0.26, 0.5, "rocket_hit"],
	"rocket_pop": [Color("ffe680"), 20, 0.0, 0.0, "rocket_hit"],
	"shield_deflect": [Color("8af4ff"), 30, 0.16, 0.25, "shield_ping"],
	"shield_up": [Color("66e8ff"), 24, 0.10, 0.2, "shield_up"],
	"rocket_fizzle": [Color("d8dcf0"), 12, 0.0, 0.0, ""],
	# Item-Rückmeldungen ohne Spielwirkung: Funkenkugel an der Bande, Blase legen/platzen,
	# Ende von Sternmagnet und Nordlicht.
	"spark_bounce": [Color("58f0a0"), 14, 0.0, 0.0, "rail_hit_soft"],
	"bubble_drop": [Color("7fd8ff"), 12, 0.0, 0.0, "whoosh"],
	"bubble_pop": [Color("bfefff"), 18, 0.0, 0.0, "shield_ping"],
	"item_end": [Color("e8f2ff"), 10, 0.0, 0.0, "whoosh"],
}
## Events that also throw big five-pointed stars (kids read: "Sterne, nicht Schaden").
const STAR_EVENTS: Dictionary = {"rocket_hit": 22, "hit_spin": 12, "rocket_pop": 8, "shield_deflect": 6}

var reduced_motion: bool = false
var particle_scale: float = 1.0
var flash_rect: ColorRect
var flash_alpha: float = 0.0
var flash_color: Color = Color.WHITE
var kick: float = 0.0
var shake: float = 0.0
var _pool: Array[CPUParticles3D] = []
var _star_pool: Array[CPUParticles3D] = []
## Big expanding star flash for rocket hits/bounces (one billboard each, pooled).
const FLASH_EVENTS: Dictionary = {"rocket_hit": [Color("ffd166"), 4.2], "shield_deflect": [Color("8af4ff"), 2.6], "hit_spin": [Color("ffffff"), 2.4]}
var _flash_pool: Array[MeshInstance3D] = []
var _flash_age: Array[float] = []
var _flash_size: Array[float] = []
var _flash_cursor: int = 0
var _star_cursor: int = 0
var _cursor: int = 0
var _time: float = 0.0
var fired: Dictionary = {}


func setup(overlay_parent: Node, quality: String, reduced: bool) -> void:
	reduced_motion = reduced
	particle_scale = 1.0 if quality == "high" else (0.65 if quality == "medium" else 0.4)
	if is_instance_valid(overlay_parent) and not is_instance_valid(flash_rect):
		flash_rect = ColorRect.new()
		flash_rect.name = "KartScreenFlash"
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_rect.color = Color(1, 1, 1, 0)
		overlay_parent.add_child(flash_rect)
	if _pool.is_empty():
		var quad := QuadMesh.new()
		quad.size = Vector2(0.26, 0.26)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# Soft round glow instead of hard squares.
		var glow := Gradient.new()
		glow.set_color(0, Color(1, 1, 1, 1))
		glow.add_point(0.35, Color(1, 1, 1, 0.75))
		glow.set_color(glow.get_point_count() - 1, Color(1, 1, 1, 0))
		var dot := GradientTexture2D.new()
		dot.gradient = glow
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(0.5, 0.0)
		dot.width = 32
		dot.height = 32
		material.albedo_texture = dot
		quad.material = material
		for index in range(POOL_SIZE):
			var particles := CPUParticles3D.new()
			particles.name = "Burst%d" % index
			particles.emitting = false
			particles.one_shot = true
			particles.explosiveness = 0.92
			particles.lifetime = 0.7
			particles.mesh = quad
			particles.direction = Vector3.UP
			particles.spread = 75.0
			particles.initial_velocity_min = 3.5
			particles.initial_velocity_max = 8.0
			particles.gravity = Vector3(0, -9.0, 0)
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.4
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 1))
			ramp.set_color(1, Color(1, 1, 1, 0))
			particles.color_ramp = ramp
			particles.local_coords = false
			add_child(particles)
			_pool.append(particles)
		var star_mesh := _star_mesh()
		var flash_star := _star_mesh(true)
		for index in range(2):
			var sprite := MeshInstance3D.new()
			sprite.name = "HitStarFlash%d" % index
			sprite.mesh = flash_star
			var flash_material := StandardMaterial3D.new()
			flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			flash_material.billboard_keep_scale = true
			flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			flash_material.vertex_color_use_as_albedo = true
			sprite.material_override = flash_material
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.visible = false
			sprite.top_level = true
			add_child(sprite)
			_flash_pool.append(sprite)
			_flash_age.append(9.0)
			_flash_size.append(1.0)
		for index in range(3):
			var stars := CPUParticles3D.new()
			stars.name = "StarBurst%d" % index
			stars.emitting = false
			stars.one_shot = true
			stars.explosiveness = 0.95
			stars.lifetime = 0.95
			stars.mesh = star_mesh
			stars.direction = Vector3.UP
			stars.spread = 180.0
			stars.initial_velocity_min = 3.0
			stars.initial_velocity_max = 6.5
			stars.gravity = Vector3(0, -5.0, 0)
			stars.damping_min = 1.5
			stars.damping_max = 3.0
			stars.angular_velocity_min = -220.0
			stars.angular_velocity_max = 220.0
			stars.scale_amount_min = 0.7
			stars.scale_amount_max = 1.5
			var star_ramp := Gradient.new()
			star_ramp.set_color(0, Color(1, 1, 1, 1))
			star_ramp.add_point(0.7, Color(1, 1, 1, 0.9))
			star_ramp.set_color(star_ramp.get_point_count() - 1, Color(1, 1, 1, 0))
			stars.color_ramp = star_ramp
			var hue := Gradient.new()
			hue.set_color(0, Color("fff3a0"))
			hue.add_point(0.5, Color("ff8fb8"))
			hue.set_color(hue.get_point_count() - 1, Color("8af4ff"))
			stars.color_initial_ramp = hue
			stars.local_coords = false
			add_child(stars)
			_star_pool.append(stars)


## Fire a named event at a world position. Unknown ids are ignored (returns false).
func trigger(event_id: String, at: Vector3, strength: float = 1.0) -> bool:
	if not EVENTS.has(event_id):
		return false
	var spec: Array = EVENTS[event_id]
	fired[event_id] = int(fired.get(event_id, 0)) + 1
	if not _pool.is_empty():
		var particles: CPUParticles3D = _pool[_cursor]
		_cursor = (_cursor + 1) % _pool.size()
		particles.amount = maxi(4, int(float(spec[1]) * particle_scale * (0.5 if reduced_motion else 1.0)))
		particles.color = spec[0]
		particles.global_position = at
		particles.restart()
		particles.emitting = true
	if STAR_EVENTS.has(event_id) and not _star_pool.is_empty():
		var stars: CPUParticles3D = _star_pool[_star_cursor]
		_star_cursor = (_star_cursor + 1) % _star_pool.size()
		stars.amount = maxi(4, int(float(STAR_EVENTS[event_id]) * maxf(0.5, particle_scale)))
		stars.global_position = at
		stars.restart()
		stars.emitting = true
	if FLASH_EVENTS.has(event_id) and not _flash_pool.is_empty():
		var sprite: MeshInstance3D = _flash_pool[_flash_cursor]
		_flash_age[_flash_cursor] = 0.0
		_flash_size[_flash_cursor] = float(FLASH_EVENTS[event_id][1]) * strength
		(sprite.material_override as StandardMaterial3D).albedo_color = FLASH_EVENTS[event_id][0]
		sprite.global_position = at
		sprite.visible = true
		_flash_cursor = (_flash_cursor + 1) % _flash_pool.size()
	# Reduced motion: no screen flash at all (colour feedback stays in the world).
	var flash: float = 0.0 if reduced_motion else float(spec[2]) * strength
	if flash > flash_alpha:
		flash_alpha = flash
		flash_color = spec[0]
	if not reduced_motion:
		kick = maxf(kick, float(spec[3]) * strength)
		if event_id in ["hit_spin", "rocket_fire", "rocket_hit"]:
			shake = maxf(shake, 0.35 * strength)
	if not str(spec[4]).is_empty():
		sound_hook.emit(event_id, str(spec[4]))
	return true


func _process(delta: float) -> void:
	_time += delta
	for index in range(_flash_pool.size()):
		if _flash_age[index] > 0.6:
			_flash_pool[index].visible = false
			continue
		_flash_age[index] += delta
		var t: float = clampf(_flash_age[index] / 0.6, 0.0, 1.0)
		# Grows fast, turns a little, fades out: a big friendly "Stern!" pop.
		var grow: float = 1.0 if reduced_motion else (1.0 - pow(1.0 - t, 3.0))
		_flash_pool[index].scale = Vector3.ONE * maxf(0.05, _flash_size[index] * (0.35 + 0.65 * grow))
		var material := _flash_pool[index].material_override as StandardMaterial3D
		material.albedo_color.a = (1.0 - t) * 0.9
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.6)
	kick = move_toward(kick, 0.0, delta * 2.2)
	shake = move_toward(shake, 0.0, delta * 1.4)
	if is_instance_valid(flash_rect):
		flash_rect.color = Color(flash_color, flash_alpha)
		flash_rect.visible = flash_alpha > 0.005


## Camera push: extra FOV degrees and a small positional shake for this frame.
func camera_fov_kick() -> float:
	return 0.0 if reduced_motion else kick * 7.0


func camera_shake() -> Vector3:
	if reduced_motion or shake <= 0.0:
		return Vector3.ZERO
	return Vector3(sin(_time * 53.0), sin(_time * 41.0 + 1.3), 0.0) * shake * 0.18


func _exit_tree() -> void:
	if is_instance_valid(flash_rect):
		flash_rect.queue_free()


## Flat five-pointed star, vertex-coloured, billboarded: one surface for every star.
static func _star_mesh(soft_centre: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var points: Array[Vector3] = []
	for i in range(10):
		var radius: float = 0.20 if i % 2 == 0 else 0.085
		var angle: float = PI * 0.5 + i * PI / 5.0
		points.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
	for i in range(10):
		vertices.append(Vector3.ZERO)
		vertices.append(points[i])
		vertices.append(points[(i + 1) % 10])
		colors.append(Color.WHITE)
		# A flash star has a white-hot centre and tinted, fading tips.
		for _k in range(2):
			colors.append(Color(1, 1, 1, 0.25) if soft_centre else Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color("ffe9a0")
	material.emission_energy_multiplier = 0.6
	mesh.surface_set_material(0, material)
	return mesh
