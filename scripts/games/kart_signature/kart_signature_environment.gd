extends Node3D
## Gemeinsame Bühne der Signatur-Strecken: Licht, Himmel, Nebel, Blender-Module mit drei
## Detailstufen (GLB, Mesh-Namen enden auf 0/1/2), Rauch-/Funkenwolken (ein MultiMesh je
## Art, Bewegung im Shader), Bänder entlang der Fahrbahn, Klanginseln und Ansagen.
## Unterklassen bauen ihre Welt in _scene() und ihre Ereignisse in _race_tick().
## Profile: LOW = keine Schatten/Glow, weniger Wolken und Kleinteile, LOD ab Stufe 1;
## MEDIUM/HIGH voll (HIGH mit weiterer Sichtweite und mehr Partikeln).
const AUDIO = preload("res://scripts/games/kart_signature/kart_signature_audio.gd")
const PUFF_MIX = preload("res://assets/shaders/signature/signature_puff_mix.gdshader")
const PUFF_ADD = preload("res://assets/shaders/signature/signature_puff_add.gdshader")
const LOD_NEAR: float = 45.0
const LOD_MID: float = 120.0
const LOD_FAR: float = 520.0
## Teilchen je Profil (Anteil der Wunschzahl).
const PARTICLE_SHARE: Dictionary = {"low": 0.3, "medium": 0.7, "high": 1.0}
## Bis zu dieser Entfernung (m) beeinflusst die Fahrbahn das Gelände.
const ROAD_FIELD_REACH: float = 64.0
static var _modules: Dictionary = {}

var world: Node3D
var course
var tier: String = "medium"
var environment: Environment
var sun: DirectionalLight3D
var audio
var parts: Dictionary = {}
var announced: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _field_origin := Vector2.ZERO
var _field_cell: float = 1.0
var _field_side: int = 0
var _field_index := PackedInt32Array()
var _field_dist := PackedFloat32Array()


func build(race_world: Node3D, race_course) -> void:
	world = race_world
	course = race_course
	tier = "low" if bool(world.get("low_detail")) else LumoQuality.tier()
	_rng.seed = int(world.definition.get("seed", 1))
	_scene()
	audio = AUDIO.new()
	add_child(audio)
	audio.configure(world, course)
	world.set_meta("signature_quality", tier)


func low() -> bool:
	return tier == "low"


func _high() -> bool:
	return tier == "high"


## Teilchenzahl für das aktive Profil (mindestens eins).
func _share(count: int) -> int:
	return maxi(1, roundi(float(count) * float(PARTICLE_SHARE.get(tier, 0.7))))


# ------------------------------------------------------------------ Unterklassen


func _scene() -> void:
	pass


func _race_tick(_game: Node, _delta: float) -> void:
	pass


func celebrate_finish() -> void:
	pass


## Ein Takt im Rennen (aus kart_island._advance_signature_world).
func advance_race(game: Node, delta: float) -> void:
	var player: Node3D = game.get("player")
	if audio != null and is_instance_valid(player):
		audio.update(game, player.global_position, delta)
	if bool(game.get("paused")):
		return
	_race_tick(game, delta)


## Einmal je Runde und Schlüssel: Text in der Nachrichtenzeile, optional ein Klang.
func _announce(
	game: Node, key: String, text: String, cue: String = "", trim_db: float = 0.0
) -> bool:
	var lap: int = int(float(game.get("distance")) / maxf(float(game.get("track_length")), 1.0))
	var full_key: String = "%s:%d" % [key, lap]
	if announced.has(full_key):
		return false
	announced[full_key] = true
	var message = game.get("message")
	if message is Label and not text.is_empty():
		message.text = text
	if not cue.is_empty() and audio != null:
		audio.cue(cue, trim_db)
	return true


# ------------------------------------------------------------------ Licht


## look: zenith, horizon, ground (Himmel), sun_color, sun_energy, sun_rotation (Grad),
## ambient, ambient_energy, fog, fog_density, exposure, glow, saturation.
func _lighting(look: Dictionary) -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = look.zenith
	material.sky_horizon_color = look.horizon
	material.ground_horizon_color = look.get("ground_horizon", look.horizon)
	material.ground_bottom_color = look.ground
	material.sky_curve = float(look.get("sky_curve", 0.18))
	material.sun_angle_max = 4.0
	material.sun_curve = 0.1
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = look.ambient
	environment.ambient_light_energy = float(look.ambient_energy) * (1.2 if low() else 1.0)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = float(look.get("exposure", 0.9))
	environment.tonemap_white = 4.5
	environment.glow_enabled = not low()
	environment.glow_intensity = float(look.get("glow", 0.6))
	environment.glow_bloom = float(look.get("bloom", 0.05))
	environment.glow_hdr_threshold = float(look.get("glow_threshold", 1.0))
	environment.adjustment_enabled = not low()
	environment.adjustment_saturation = float(look.get("saturation", 1.08))
	environment.adjustment_contrast = float(look.get("contrast", 1.04))
	environment.fog_enabled = true
	environment.fog_light_color = look.fog
	environment.fog_density = float(look.fog_density)
	environment.fog_light_energy = float(look.get("fog_energy", 0.7))
	environment.fog_aerial_perspective = float(look.get("aerial", 0.25))
	environment.fog_sky_affect = float(look.get("fog_sky", 0.25))
	var holder := WorldEnvironment.new()
	holder.name = "SignatureWorldEnvironment"
	holder.environment = environment
	add_child(holder)
	sun = DirectionalLight3D.new()
	sun.name = "SignatureSun"
	sun.rotation_degrees = look.sun_rotation
	sun.light_color = look.sun_color
	sun.light_energy = float(look.sun_energy)
	sun.shadow_enabled = not low()
	sun.directional_shadow_max_distance = 80.0 if _high() else 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.1
	add_child(sun)
	if look.has("fill_color"):
		var fill := DirectionalLight3D.new()
		fill.name = "SignatureFill"
		fill.rotation_degrees = look.get("fill_rotation", Vector3(-30, 150, 0))
		fill.light_color = look.fill_color
		fill.light_energy = float(look.get("fill_energy", 0.18))
		fill.shadow_enabled = false
		add_child(fill)


# ------------------------------------------------------------------ Bausteine


func material(
	color: Color, rough: float = 0.8, metal: float = 0.0, emission: float = 0.0
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = rough
	result.metallic = metal
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result


func shader_material(shader: Shader, parameters: Dictionary = {}) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	for key in parameters:
		result.set_shader_parameter(key, parameters[key])
	return result


func mesh_node(
	node_name: String, mesh: Mesh, surface: Material, far: float = 0.0, shadow: bool = true
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = surface
	if far > 0.0:
		node.visibility_range_end = far
	if not shadow or low():
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Blender-Modul mit drei Detailstufen (Mesh-Name endet auf 0, 1 oder 2).
func module(path: String, reach: float = 1.0) -> Node3D:
	if not _modules.has(path):
		_modules[path] = load(path)
	var packed := _modules[path] as PackedScene
	var part := packed.instantiate() as Node3D
	var scale_reach: float = reach * (0.6 if low() else 1.0)
	var near: float = LOD_NEAR * scale_reach
	var mid: float = LOD_MID * scale_reach
	var far: float = LOD_FAR * scale_reach
	for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var level: int = clampi(str(mesh.name).right(1).to_int(), 0, 2)
		mesh.visibility_range_begin = [0.0, near, mid][level]
		mesh.visibility_range_end = [near, mid, far][level]
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if level == 2 or low():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part


## Modul an einer Streckenstelle: Fußpunkt auf der Fahrbahn (oder auf ground_y), aufrecht,
## in Fahrtrichtung gedreht (+yaw Grad).
func place(
	path: String,
	metres: float,
	lateral: float,
	size: float = 1.0,
	yaw: float = 0.0,
	ground_y: float = NAN,
	reach: float = 1.0
) -> Node3D:
	var at: Vector3 = world.position_at(metres, lateral)
	var ahead: Vector3 = world.forward(metres)
	var heading: float = atan2(-ahead.x, -ahead.z)
	if not is_nan(ground_y):
		at.y = ground_y
	var part: Node3D = module(path, reach * maxf(size, 1.0))
	part.name = "%s_%d_%d" % [path.get_file().get_basename(), roundi(metres), roundi(lateral)]
	part.transform = Transform3D(
		Basis(Vector3.UP, heading + deg_to_rad(yaw)).scaled(Vector3.ONE * size), at
	)
	add_child(part)
	return part


## Band entlang der Fahrbahn (Lava, Wasser, Glühlinien): from–to Meter, Querlage a–b,
## Höhe dy über der Fahrbahn bzw. fester Höhe (absolute_y), UV = (quer m, entlang m).
func ribbon(
	from: float,
	to: float,
	a: float,
	b: float,
	dy: float,
	step: float = 3.0,
	absolute_y: float = NAN
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = maxi(1, ceili((to - from) / step))
	var half: float = (b - a) * 0.5
	for i in range(rows + 1):
		var d: float = lerpf(from, to, float(i) / float(rows))
		var basis: Basis = world.frame(d)
		for k in range(2):
			var lateral: float = a if k == 0 else b
			var p: Vector3 = world.position_at(d, lateral) + basis.y * dy
			if not is_nan(absolute_y):
				p.y = absolute_y
			surface.set_normal(Vector3.UP if not is_nan(absolute_y) else basis.y)
			surface.set_uv(Vector2((lateral - a) - half, d - from))
			surface.add_vertex(p)
		if i > 0:
			var n: int = i * 2
			for index in [n - 2, n, n - 1, n - 1, n, n + 1]:
				surface.add_index(index)
	return surface.commit()


## Rauch/Dampf (mix) oder Funken/Glut (add): eine MultiMesh-Wolke aus Quellpunkten.
## sources: Array von Vector4(x, y, z, Streuung). per_source Teilchen je Quelle.
func puffs(
	node_name: String,
	sources: Array,
	per_source: int,
	color: Color,
	size: float,
	rise: float,
	cycles: float,
	glow: bool = false,
	wind: Vector3 = Vector3(1.2, 0, 0.4),
	gravity: float = 0.0
) -> MultiMeshInstance3D:
	var count: int = _share(per_source)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = sources.size() * count
	var index: int = 0
	for source in sources:
		var at: Vector4 = source
		for k in range(count):
			var spread: float = maxf(at.w, 0.05)
			multimesh.set_instance_transform(
				index,
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * spread), Vector3(at.x, at.y, at.z))
			)
			var tint: Color = color.lightened(_rng.randf_range(-0.08, 0.1))
			tint.a = color.a
			multimesh.set_instance_color(index, tint)
			multimesh.set_instance_custom_data(
				index,
				Color(
					(float(k) + _rng.randf()) / float(count),
					cycles * _rng.randf_range(0.8, 1.2),
					size * _rng.randf_range(0.7, 1.3),
					rise * _rng.randf_range(0.75, 1.15)
				)
			)
			index += 1
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	var surface := ShaderMaterial.new()
	surface.shader = PUFF_ADD if glow else PUFF_MIX
	surface.set_shader_parameter("wind", wind)
	surface.set_shader_parameter("gravity", gravity)
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves every quad away from its source: keep the bounds generous.
	node.custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 900, 4000))
	add_child(node)
	return node


## Gewölbe über der Fahrbahn (Tunnel, Höhle, Grotte): Wände ab der Fahrbahnkante, Bogen bis
## ceiling, rauhe Felsbeulen (rough); dazu ein Boden neben und unter der Fahrbahn.
func vault(
	from: float, to: float, ceiling: float, margin: float, rough: float, colour: Color
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = 12
	var rows: int = ceili((to - from) / 2.5)
	for i in range(rows + 1):
		var d: float = lerpf(from, to, float(i) / float(rows))
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5 + margin
		for c in range(columns + 1):
			var u: float = float(c) / float(columns)
			var angle: float = PI * u
			var lateral: float = -cos(angle) * half
			var height: float = -0.6 + (ceiling + 0.6) * pow(sin(angle), 0.6)
			var bump: float = (sin(d * 0.37 + float(c) * 1.7) + sin(d * 0.11 - float(c))) * rough
			if c == 0 or c == columns:
				bump = 0.0
			var p: Vector3 = (
				world.position_at(d, lateral * (1.0 + bump * 0.04)) + basis.y * (height + bump)
			)
			surface.set_normal((world.position_at(d) + basis.y * ceiling * 0.4 - p).normalized())
			surface.set_uv(Vector2(u * 8.0, d * 0.2))
			surface.add_vertex(p)
		if i > 0:
			for c in range(columns):
				var k: int = i * (columns + 1) + c
				var j: int = k - columns - 1
				for index in [j, k, j + 1, j + 1, k, k + 1]:
					surface.add_index(index)
	var stone: StandardMaterial3D = material(colour, 0.92)
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Boden neben und unter der Fahrbahn: der Blick fällt nie ins Leere.
	var half: float = world.road_width_at((from + to) * 0.5) * 0.5 + margin + 0.5
	mesh_node(
		"Hoehlenboden_%d" % roundi(from),
		ribbon(from, to, -half, half, -0.7, 3.0),
		material(colour.darkened(0.3), 0.95),
		0.0,
		false
	)
	return mesh_node("Gewoelbe_%d" % roundi(from), surface.commit(), stone, 0.0)


## Böschung unter den Fahrbahnkanten: die Straße steht nie in der Luft. open(d) -> bool:
## an dieser Stelle eine 7 m tiefe Böschung (sonst nur eine Kante, z. B. in Tunneln).
func skirts(colour: Color, open: Callable) -> void:
	for side in [-1.0, 1.0]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rows: int = 0
		var d: float = 0.0
		while d <= float(world.length):
			var basis: Basis = world.frame(d)
			var edge: Vector3 = world.position_at(d, side * world.road_width_at(d) * 0.5)
			var depth: float = 7.0 if bool(open.call(d)) else 0.05
			surface.set_normal(basis.x * side)
			surface.add_vertex(edge - basis.y * 0.04)
			surface.set_normal(basis.x * side)
			surface.add_vertex(edge - basis.y * depth + basis.x * side * depth * 0.35)
			if rows > 0:
				var n: int = rows * 2
				for index in [n - 2, n, n - 1, n - 1, n, n + 1]:
					surface.add_index(index)
			rows += 1
			d += 3.0
		var skirt: StandardMaterial3D = material(colour, 0.95)
		skirt.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node("Boeschung%s" % ("L" if side < 0.0 else "R"), surface.commit(), skirt, 0.0, false)


## Halbröhre über der Fahrbahn (Glastunnel, Unterwasserröhre), Innenseite sichtbar.
func tube(from: float, to: float, ceiling: float, margin: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = 14
	var rows: int = ceili((to - from) / 3.0)
	for i in range(rows + 1):
		var d: float = lerpf(from, to, float(i) / float(rows))
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5 + margin
		for c in range(columns + 1):
			var u: float = PI * float(c) / float(columns)
			var p: Vector3 = world.position_at(d, -cos(u) * half) + basis.y * (sin(u) * ceiling)
			surface.set_normal((world.position_at(d) + basis.y * ceiling * 0.3 - p).normalized())
			surface.add_vertex(p)
		if i > 0:
			for c in range(columns):
				var k: int = i * (columns + 1) + c
				var j: int = k - columns - 1
				for index in [j, k, j + 1, j + 1, k, k + 1]:
					surface.add_index(index)
	return surface.commit()


## Band entlang eines Weges [Vector3, …] (Flüsse, Lavaströme): UV = (quer m, Weg m).
func path_ribbon(path: Array, half_width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	var rows: int = 0
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var steps: int = maxi(1, ceili(Vector2(b.x - a.x, b.z - a.z).length() / 4.0))
		var ahead := Vector2(b.x - a.x, b.z - a.z).normalized()
		var side := Vector3(-ahead.y, 0.0, ahead.x)
		for k in range(steps + (1 if i == path.size() - 2 else 0)):
			var p: Vector3 = a.lerp(b, float(k) / float(steps))
			for s in [-1.0, 1.0]:
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(s * half_width, along))
				surface.add_vertex(p + side * s * half_width)
			if rows > 0:
				var n: int = rows * 2
				for index in [n - 2, n, n - 1, n - 1, n, n + 1]:
					surface.add_index(index)
			rows += 1
			along += Vector2(b.x - a.x, b.z - a.z).length() / float(steps)
	return surface.commit()


## Tunnel (Eintrag aus course.TUNNELS) an dieser Stelle, 6 m innerhalb der Portale; sonst null.
func _tunnel_at(d: float):
	for tunnel in course.TUNNELS:
		if d > float(tunnel.start) + 6.0 and d < float(tunnel.end) - 6.0:
			return tunnel
	return null


## Gelände aus einer Höhenfunktion (Callable(x, z) -> Höhe) mit Farben (Callable(x, z, h)).
## Die Höhen werden einmal je Gitterpunkt gerechnet, Normalen aus den Nachbarn.
func terrain(
	node_name: String, centre: Vector2, size: float, cells: int, height: Callable, tint: Callable
) -> MeshInstance3D:
	var side: int = cells + 1
	var cell: float = size / float(cells)
	_stamp_road_field(centre, size, cells, ROAD_FIELD_REACH)
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for iz in range(side):
		for ix in range(side):
			var x: float = centre.x - size * 0.5 + float(ix) * cell
			var z: float = centre.y - size * 0.5 + float(iz) * cell
			heights[iz * side + ix] = height.call(x, z)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(side):
		for ix in range(side):
			var x: float = centre.x - size * 0.5 + float(ix) * cell
			var z: float = centre.y - size * 0.5 + float(iz) * cell
			var h: float = heights[iz * side + ix]
			var left: float = heights[iz * side + maxi(ix - 1, 0)]
			var right: float = heights[iz * side + mini(ix + 1, cells)]
			var back: float = heights[maxi(iz - 1, 0) * side + ix]
			var front: float = heights[mini(iz + 1, cells) * side + ix]
			surface.set_color(tint.call(x, z, h))
			surface.set_normal(Vector3(left - right, 2.0 * cell, back - front).normalized())
			surface.add_vertex(Vector3(x, h, z))
			if iz > 0 and ix > 0:
				var k: int = iz * side + ix
				for n in [k - side - 1, k - side, k - 1, k - side, k, k - 1]:
					surface.add_index(n)
	var surface_material := StandardMaterial3D.new()
	surface_material.vertex_color_use_as_albedo = true
	surface_material.vertex_color_is_srgb = true
	surface_material.roughness = 0.95
	return mesh_node(node_name, surface.commit(), surface_material, 0.0, false)


## Abstandsfeld zur Fahrbahn auf dem Geländegitter: jede Stützstelle der Mittellinie (alle
## 5 m) stempelt ihre Umgebung (reach Meter); das ersetzt eine Nächster-Punkt-Suche je
## Gitterpunkt (vorher ~100 µs je Punkt, jetzt einmal für alle).
func _stamp_road_field(centre: Vector2, size: float, cells: int, reach: float) -> void:
	var side: int = cells + 1
	var cell: float = size / float(cells)
	var origin := Vector2(centre.x - size * 0.5, centre.y - size * 0.5)
	_field_origin = origin
	_field_cell = cell
	_field_side = side
	_field_index = PackedInt32Array()
	_field_index.resize(side * side)
	_field_index.fill(-1)
	_field_dist = PackedFloat32Array()
	_field_dist.resize(side * side)
	_field_dist.fill(INF)
	var samples: PackedVector3Array = world._road_samples
	var span: int = ceili(reach / cell)
	for i in range(samples.size()):
		var p: Vector3 = samples[i]
		var cx: int = roundi((p.x - origin.x) / cell)
		var cz: int = roundi((p.z - origin.y) / cell)
		for iz in range(maxi(0, cz - span), mini(side - 1, cz + span) + 1):
			var z: float = origin.y + float(iz) * cell
			for ix in range(maxi(0, cx - span), mini(side - 1, cx + span) + 1):
				var x: float = origin.x + float(ix) * cell
				var square: float = (x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)
				var k: int = iz * side + ix
				if square < _field_dist[k]:
					_field_dist[k] = square
					_field_index[k] = i


## Nächste Stützstelle der Mittellinie: Vector2(waagerechter Abstand, Index). Auf dem
## Geländegitter aus dem Feld, sonst über die k-d-Suche der Welt.
func road_hit(x: float, z: float) -> Vector2:
	if _field_side > 0:
		var fx: float = (x - _field_origin.x) / _field_cell
		var fz: float = (z - _field_origin.y) / _field_cell
		var ix: int = roundi(fx)
		var iz: int = roundi(fz)
		if (
			absf(fx - float(ix)) < 0.001
			and absf(fz - float(iz)) < 0.001
			and ix >= 0
			and iz >= 0
			and ix < _field_side
			and iz < _field_side
		):
			var k: int = iz * _field_side + ix
			if _field_index[k] < 0:
				return Vector2(INF, 0.0)
			return Vector2(sqrt(_field_dist[k]), float(_field_index[k]))
	return world._nearest_horizontal(Vector3(x, 0.0, z))
