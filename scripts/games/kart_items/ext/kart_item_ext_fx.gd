extends RefCounted
## Gemeinsame Bausteine der neuen Item-Effekte (Welle 1 und später): Materialien,
## Partikel-Emitter, verästelte Blitzlinien und kameragerichtete Bänder.
## Alles gl_compatibility-tauglich: unshaded, additiv oder Alpha, keine Screen-/Depth-Textur.
## Teilchen nutzen das Vierfarb-Quad (particle_quad.gd): ein einfaches QuadMesh zeichnete im
## Kompatibilitäts-Renderer schwarze Scheiben.

const QUAD = preload("res://scripts/systems/particle_quad.gd")

static var _cache: Dictionary = {}


static func soft_dot() -> Texture2D:
	if _cache.has("soft_dot"):
		return _cache["soft_dot"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.4, Color(1, 1, 1, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	_cache["soft_dot"] = texture
	return texture


## Weicher Ring (Bodenmarke, Glutrand): hell am Rand, innen leer.
static func soft_ring() -> Texture2D:
	if _cache.has("soft_ring"):
		return _cache["soft_ring"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.62, Color(1, 1, 1, 0.0))
	gradient.add_point(0.82, Color(1, 1, 1, 1.0))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	_cache["soft_ring"] = texture
	return texture


## Unshaded, additiv: leuchtet, Schwarz bleibt unsichtbar.
static func glow(
	color: Color, billboard: bool = false, texture: Texture2D = null
) -> StandardMaterial3D:
	var key: String = (
		"glow/%s/%s/%d"
		% [color.to_html(), str(billboard), texture.get_instance_id() if texture else 0]
	)
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if texture != null:
		material.albedo_texture = texture
	_cache[key] = material
	return material


## Alpha-gemischt (nicht additiv): bleibt auf hellem Schnee/Himmel sichtbar.
static func soft(
	color: Color, billboard: bool = false, textured: bool = true
) -> StandardMaterial3D:
	var key: String = "soft/%s/%s/%s" % [color.to_html(), str(billboard), str(textured)]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if textured:
		material.albedo_texture = soft_dot()
	_cache[key] = material
	return material


## Eigene (nicht geteilte) Kopie, wenn ein Effekt die Farbe/Alpha pro Bild ändert.
static func glow_unique(
	color: Color, billboard: bool = false, texture: Texture2D = null
) -> StandardMaterial3D:
	return glow(color, billboard, texture).duplicate() as StandardMaterial3D


## Beleuchteter, halbdurchsichtiger Stoff (Eis, Rauchkugel): wirkt körperlich im Licht.
static func solid(
	color: Color,
	emission: Color = Color.BLACK,
	energy: float = 0.0,
	alpha: float = 1.0,
	rough: float = 0.25
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = rough
	material.metallic_specular = 0.8
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


static func quad_mesh(size: float, material: Material) -> ArrayMesh:
	var mesh: ArrayMesh = QUAD.make(Vector2(size, size))
	mesh.surface_set_material(0, material)
	return mesh


## Flache Bodenscheibe (liegt in der lokalen XZ-Ebene auf der Fahrbahn), mit Vertex-Farben.
static func ground_disc(radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key: String = "disc/%.2f" % radius
	if not _cache.has(key):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
			[
				Vector3(-radius, 0, -radius),
				Vector3(radius, 0, -radius),
				Vector3(radius, 0, radius),
				Vector3(-radius, 0, radius)
			]
		)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(
			[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
		)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(
			[Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
		)
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_cache[key] = mesh
	node.mesh = _cache[key]
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func sprite(size: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key: String = "sprite/%.2f" % size
	if not _cache.has(key):
		_cache[key] = QUAD.make(Vector2(size, size))
	node.mesh = _cache[key]
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Partikel-Emitter nach Rezept. Schlüssel (alle optional): amount, lifetime, size, one_shot,
## explosiveness, direction, spread, speed_min, speed_max, gravity, damping, scale_min,
## scale_max, grow (Endgröße relativ), colors (Array[Color] über die Lebenszeit), additive,
## box (Vector3 Emissionsbox), sphere (Radius), local (bool), preprocess (bool).
static func emitter(recipe: Dictionary) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = maxi(1, int(recipe.get("amount", 16)))
	particles.lifetime = float(recipe.get("lifetime", 0.8))
	particles.one_shot = bool(recipe.get("one_shot", false))
	particles.explosiveness = float(recipe.get("explosiveness", 0.0))
	particles.direction = recipe.get("direction", Vector3.UP)
	particles.spread = float(recipe.get("spread", 30.0))
	particles.initial_velocity_min = float(recipe.get("speed_min", 0.5))
	particles.initial_velocity_max = float(recipe.get("speed_max", 2.0))
	particles.gravity = recipe.get("gravity", Vector3.ZERO)
	particles.damping_min = float(recipe.get("damping", 0.0))
	particles.damping_max = float(recipe.get("damping", 0.0)) * 1.4
	particles.scale_amount_min = float(recipe.get("scale_min", 0.7))
	particles.scale_amount_max = float(recipe.get("scale_max", 1.3))
	particles.local_coords = bool(recipe.get("local", false))
	if recipe.has("box"):
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents = recipe.box
	elif recipe.has("sphere"):
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = float(recipe.sphere)
	var grow: float = float(recipe.get("grow", 1.0))
	if not is_equal_approx(grow, 1.0):
		var curve := Curve.new()
		curve.min_value = 0.0
		curve.max_value = maxf(1.0, grow)
		curve.add_point(Vector2(0.0, 1.0 if grow >= 1.0 else 1.0))
		curve.add_point(Vector2(1.0, grow))
		particles.scale_amount_curve = curve
	var colors: Array = recipe.get("colors", [Color.WHITE, Color(1, 1, 1, 0)])
	var ramp := Gradient.new()
	ramp.set_color(0, colors[0])
	ramp.set_color(1, colors[-1])
	for k in range(1, colors.size() - 1):
		ramp.add_point(float(k) / float(colors.size() - 1), colors[k])
	particles.color_ramp = ramp
	var material: StandardMaterial3D
	if bool(recipe.get("additive", true)):
		material = glow(Color.WHITE, false, soft_dot()).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = soft_dot()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particles.mesh = quad_mesh(float(recipe.get("size", 0.4)), material)
	if bool(recipe.get("preprocess", false)):
		particles.preprocess = particles.lifetime
	particles.emitting = bool(recipe.get("emitting", false))
	return particles


## Einen gepoolten Ausstoß an einer Stelle auslösen (one_shot-Emitter).
static func burst(
	particles: CPUParticles3D, at: Vector3, direction: Vector3 = Vector3.ZERO
) -> void:
	if not is_instance_valid(particles) or not particles.is_inside_tree():
		return
	particles.global_position = at
	if direction != Vector3.ZERO:
		particles.direction = direction.normalized()
	particles.restart()
	particles.emitting = true


## Verästelter Blitz von `from` nach `to`: Hauptast (Zickzack, zur Mitte hin am weitesten
## ausgelenkt) plus Seitenäste. Rückgabe: Liste von Linien (PackedVector3Array) mit Breite.
static func bolt(
	from: Vector3,
	to: Vector3,
	rng: RandomNumberGenerator,
	segments: int,
	jitter: float,
	branches: int
) -> Array:
	var lines: Array = []
	var main := PackedVector3Array()
	var axis: Vector3 = to - from
	var side_a: Vector3 = (
		axis
		. cross(
			Vector3.RIGHT if absf(axis.normalized().dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		)
		. normalized()
	)
	var side_b: Vector3 = axis.cross(side_a).normalized()
	for k in range(segments + 1):
		var t: float = float(k) / float(segments)
		var spread: float = sin(PI * t) * jitter
		var point: Vector3 = from + axis * t
		if k > 0 and k < segments:
			point += (
				side_a * rng.randf_range(-spread, spread)
				+ side_b * rng.randf_range(-spread, spread)
			)
		main.append(point)
	lines.append({"points": main, "width": 1.0})
	for _b in range(branches):
		var start_index: int = rng.randi_range(1, maxi(1, segments - 2))
		var start: Vector3 = main[start_index]
		var length: float = axis.length() * rng.randf_range(0.18, 0.34)
		var direction: Vector3 = (
			(
				axis.normalized() * 0.55
				+ (
					(side_a * rng.randf_range(-1, 1) + side_b * rng.randf_range(-1, 1)).normalized()
					* 0.85
				)
			)
			. normalized()
		)
		var branch := PackedVector3Array([start])
		var steps: int = 4
		for s in range(1, steps + 1):
			var p: Vector3 = start + direction * length * float(s) / float(steps)
			p += (side_a * rng.randf_range(-1, 1) + side_b * rng.randf_range(-1, 1)) * jitter * 0.25
			branch.append(p)
		lines.append({"points": branch, "width": 0.45})
	return lines


## Kameragerichtete Bänder in ein ImmediateMesh schreiben (ein Draw-Call für alle Linien).
## `lines`: [{points, width}], `width`: Grundbreite in Metern, Farbe als Vertex-Farbe.
static func ribbons(
	mesh: ImmediateMesh,
	lines: Array,
	eye: Vector3,
	width: float,
	color: Color,
	to_local: Transform3D
) -> void:
	mesh.clear_surfaces()
	var any: bool = false
	for line in lines:
		if (line.points as PackedVector3Array).size() >= 2:
			any = true
	if not any:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in lines:
		var points: PackedVector3Array = line.points
		var w: float = width * float(line.get("width", 1.0))
		var c: Color = line.get("color", color)
		for k in range(points.size() - 1):
			var a: Vector3 = points[k]
			var b: Vector3 = points[k + 1]
			var along: Vector3 = (b - a).normalized()
			var view: Vector3 = (eye - (a + b) * 0.5).normalized()
			var side: Vector3 = along.cross(view).normalized() * w * 0.5
			# Spitz zulaufende Enden: am letzten Punkt schmaler.
			var taper_b: float = 0.35 if k == points.size() - 2 else 1.0
			var la: Vector3 = to_local * (a - side)
			var ra: Vector3 = to_local * (a + side)
			var lb: Vector3 = to_local * (b - side * taper_b)
			var rb: Vector3 = to_local * (b + side * taper_b)
			for v in [la, ra, rb, la, rb, lb]:
				mesh.surface_set_color(c)
				mesh.surface_set_uv(Vector2.ZERO)
				mesh.surface_add_vertex(v)
	mesh.surface_end()


## Fünfzackiger flacher Stern (Mesh in der XY-Ebene), für Ladung und Donnerstern-Kern.
static func star_mesh(outer: float, inner: float) -> ArrayMesh:
	var key: String = "star/%.2f/%.2f" % [outer, inner]
	if _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for k in range(10):
		var r0: float = outer if k % 2 == 0 else inner
		var r1: float = inner if k % 2 == 0 else outer
		var a0: float = PI * 0.5 + k * PI / 5.0
		var a1: float = PI * 0.5 + (k + 1) * PI / 5.0
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
		vertices.append(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
		colors.append(Color.WHITE)
		colors.append(Color(1, 1, 1, 0.85))
		colors.append(Color(1, 1, 1, 0.85))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


## Kristallkörper (gestrecktes Oktaeder mit acht Facetten).
static func crystal_mesh(radius: float, height: float) -> ArrayMesh:
	var key: String = "crystal/%.2f/%.2f" % [radius, height]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, height * 0.5, 0)
	var bottom := Vector3(0, -height * 0.5, 0)
	var ring: Array[Vector3] = []
	for k in range(6):
		var a: float = TAU * k / 6.0
		ring.append(
			Vector3(cos(a) * radius, (0.12 if k % 2 == 0 else -0.08) * height, sin(a) * radius)
		)
	for k in range(6):
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 6]
		for tri in [[top, b, a], [bottom, a, b]]:
			var normal: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(normal)
				st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh
